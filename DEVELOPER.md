# DEVELOPER.md — ferry-playwright

技術細節與貢獻指引。一般使用者請看 [README.md](README.md)。

---

## 為什麼能完全離線

| 元件 | 處理方式 |
| --- | --- |
| Playwright .NET 受管組件 | 預先 restore 並打包成離線 NuGet feed (`nuget/*.nupkg`)，setup-devpack 安裝後 `dotnet add package` 走離線解析 |
| 測試框架相依 | NUnit / MSTest / Microsoft.NET.Test.Sdk / coverlet / analyzers 等同樣 ship 在 `nuget/` feed |
| 瀏覽器 | 使用系統 Edge (`Channel = "msedge"`)，**完全不下載** Chromium / Firefox |
| Playwright Node 驅動 (`node.exe`) | 由 `Microsoft.Playwright` NuGet 套件自帶；當目標機 build sample 時 restore 才會 deploy 到 `bin/` 下 |
| 環境變數 | `setup-devpack.ps1` 設機器層 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`、`PLAYWRIGHT_BROWSERS_PATH=0` |
| .NET SDK | **不** 由本 ZIP 提供；目標機需另行安裝 .NET 10 SDK（IT 預部署或一同 sneakernet） |

只要目標機已備好 .NET 10 SDK，這幾件事都成立，就完全沒有任何「需要連網才能完成」的步驟。

---

## 專案結構

```
ferry-playwright/
├── src/
│   ├── FerryPlaywright.SampleApp/         # 本機開發用範例（Channel="msedge"，支援 --ci）
│   └── FerryPlaywright.OfflinePackager/   # 打包工具
├── assets/                          # 入口腳本（會包進 ZIP 根目錄）
│   ├── 點擊兩下-完整安裝(推薦).cmd            # 一鍵入口：呼叫 setup.ps1
│   ├── setup.ps1                    # self-elevate → 呼叫 setup-devpack.ps1
│   ├── 點擊兩下-解除安裝.cmd                  # 雙擊解除
│   ├── uninstall.ps1                # self-elevate → 呼叫 uninstall-devpack.ps1
│   ├── new-playwright-project.ps1   # helper：建立離線 NuGet.config + dotnet new + dotnet add
│   ├── NuGet.config.template        # `<clear/>` + ferry-playwright-feed
│   └── README.txt                   # 給最終使用者的繁中說明
├── assets-devpack/                  # dev pack 專用 staging（會包進 ZIP 根目錄）
│   ├── setup-devpack.ps1            # 把 nupkg 放進 ~/.nuget/packages，註冊機器層 NuGet source
│   └── uninstall-devpack.ps1        # 依 INDEX.txt 移除已部署 nupkg + 移除 source
├── assets-samples/                  # 三個 sample 原始碼專案（會包進 ZIP samples/）
│   ├── hello-nunit/                 # NUnit + Playwright fixture
│   ├── hello-mstest/                # MSTest + Playwright fixture
│   └── hello-console/               # 純 console 應用（CI 離線驗證即 build 此專案）
├── .github/
│   ├── workflows/release.yml        # CI：打包 + 離線驗證 + GitHub Release
│   └── copilot-instructions.md      # 給 Copilot 的 repo 速覽
├── .mcp.json                        # Copilot CLI / VS Code Copilot 的 Playwright MCP 設定
├── output/                          # 產出 ZIP 位置（git-ignored）
├── global.json                      # 鎖 .NET 10 SDK
├── Directory.Build.props            # 共用 MSBuild 設定（Nullable、ImplicitUsings 等）
├── ferry-playwright.slnx            # 新版 SLNX solution
├── CHANGELOG.md
├── DEVELOPER.md                     # 本檔
└── README.md                        # 使用者導向說明
```

---

## 開發環境需求

- **.NET 10 SDK** — `global.json` 鎖定 `10.0.100`，`rollForward: latestFeature`，
  `allowPrerelease: true`。本機開發只要任何 `10.0.x` 系列 SDK 都能跑。
- **OS** — macOS / Linux / Windows 任一皆可（cross-publish 到 `win-x64`）。
- **網路** — 第一次 restore 需要連到 nuget.org。

CI 用 `actions/setup-dotnet@v4` + `global-json-file: global.json` +
`dotnet-quality: preview`，會自動帶到對應 preview SDK。

---

## 常用指令

```bash
# 建置整個 solution
dotnet build

# 跑範例應用（互動模式，會開 Edge 並等 Enter）
dotnet run --project src/FerryPlaywright.SampleApp -- https://example.com

# 跑範例應用（CI 模式：headless、不等輸入、預設 about:blank）
CI=true dotnet run --project src/FerryPlaywright.SampleApp -- --ci

# 產生離線 ZIP（預設 win-x64 / Release / 寫入 output/）
dotnet run --project src/FerryPlaywright.OfflinePackager

# 自訂 packager 參數
dotnet run --project src/FerryPlaywright.OfflinePackager -- \
  --rid             win-x64 \
  --config          Release \
  --output          output \
  --assets          assets \
  --assets-devpack  assets-devpack \
  --assets-samples  assets-samples \
  --version         0.7.0
```

> packager **不**接受 `--project` 參數；它不再 publish runtime（v0.6+），所以只用上面這幾個與 staging 來源相關的 flag。

---

## Packager pipeline

`src/FerryPlaywright.OfflinePackager/Program.cs` 是單檔頂層程式，產出**單一 ZIP**
（離線 NuGet feed + 三個 sample 原始碼，沒有預編譯 runtime），步驟順序：

1. **Restore dev pack (NuGet graph)** — 在暫存資料夾寫一個 minimal `shell.csproj`，
   參照 `Microsoft.Playwright(.NUnit/.MSTest)` 1.60.0、`Microsoft.NET.Test.Sdk` 17.11.1、
   `NUnit` + adapter、`MSTest` + adapter、`coverlet.collector`、`NUnit.Analyzers`、
   `MSTest.Analyzers`，然後跑 `dotnet restore --packages <tmp> --runtime win-x64 --no-cache`。
2. **Collect .nupkg files** — 遞迴搜出所有 `*.nupkg`，去重後 flatten 到 `<staging>/nuget/`，
   並寫 `nuget/INDEX.txt`（卸載腳本會用此清單）。
3. **Stage sample projects** — 把 `assets-samples/` 內三個專案目錄複製到 `<staging>/samples/`。
4. **Stage runtime assets** — 把 `assets/` 內容（入口 cmd + setup.ps1 / uninstall.ps1 +
   helper script + NuGet.config.template + README.txt）複製到 ZIP 根目錄。
5. **Stage dev pack assets** — 把 `assets-devpack/` 內容（setup-devpack.ps1、
   uninstall-devpack.ps1）複製到 ZIP 根目錄（與步驟 4 同層）。
6. **Write build metadata** — 寫 `BUILD-INFO.txt`（版本、RID、設定、時間）與 `VERSION.txt`。
7. **Create ZIP** — 把整個 staging 目錄壓成
   `output/ferry-playwright-v<version>-win-x64-<timestamp>.zip`（約 320 MB；
   主要由 Microsoft.Playwright 套件貢獻）。

> v0.5.x 還有的 `Publish` 與 `Verify Playwright driver present` 兩步在 v0.6 移除了
> （因為 ZIP 已不再包含 self-contained runtime）。

最終 ZIP 結構：

```
ferry-playwright-v<version>-win-x64-YYYYMMDD-HHMMSS.zip   (~320 MB)
├── nuget/                            # 離線 NuGet feed（約 30 個 nupkg）
│   ├── microsoft.playwright.1.60.0.nupkg
│   ├── microsoft.playwright.nunit.1.60.0.nupkg
│   ├── microsoft.playwright.mstest.1.60.0.nupkg
│   ├── microsoft.net.test.sdk.*.nupkg
│   ├── nunit.*.nupkg + nunit3testadapter.*.nupkg
│   ├── mstest.*.nupkg + mstest.testadapter.*.nupkg
│   ├── coverlet.collector.*.nupkg
│   ├── nunit.analyzers.*.nupkg + mstest.analyzers.*.nupkg
│   ├── ... (傳遞性相依)
│   └── INDEX.txt
├── samples/                          # 三個 sample 原始碼專案
│   ├── hello-nunit/                  # NUnit + Playwright fixture
│   ├── hello-mstest/                 # MSTest + Playwright fixture
│   └── hello-console/                # 純 console；CI verify-offline 就 build 這個
├── 點擊兩下-完整安裝(推薦).cmd                # 一鍵入口
├── setup.ps1                         # self-elevate → 呼叫 setup-devpack.ps1
├── setup-devpack.ps1                 # 真正幹活：放 nupkg + 註冊 source + 設環境變數
├── 點擊兩下-解除安裝.cmd
├── uninstall.ps1                     # self-elevate → 呼叫 uninstall-devpack.ps1
├── uninstall-devpack.ps1
├── new-playwright-project.ps1        # helper（在新專案放 NuGet.config 後跑 dotnet new + add）
├── NuGet.config.template             # `<clear/>` + ferry-playwright-feed
├── README.txt                        # 給最終使用者的繁中說明
├── VERSION.txt                       # 純文字版本號（給工具讀）
└── BUILD-INFO.txt                    # 給人讀的 build 摘要
```

---

## 入口腳本設計（setup.ps1 / uninstall.ps1）

v0.6 起 ZIP 只剩 dev pack，沒有 runtime，所以 wrapper 已大幅簡化：

- **setup.ps1**：self-elevate（用 `Start-Process -Verb RunAs` 重啟自己）→ 呼叫同目錄
  `setup-devpack.ps1`。`$ErrorActionPreference = 'Stop'`，任何錯誤直接整個失敗。
  進階使用者也可以直接 `powershell -ExecutionPolicy Bypass -File .\setup-devpack.ps1` 跳過 wrapper。
- **uninstall.ps1**：self-elevate → 呼叫 `uninstall-devpack.ps1`，
  並 best-effort 清理 v0.5.x 留下的 `%ProgramFiles%\PlaywrightApp\` 目錄（若存在）。
- **點擊兩下-完整安裝(推薦).cmd / 點擊兩下-解除安裝.cmd**：`chcp 65001` →
  `powershell -NoProfile -ExecutionPolicy Bypass -File %~dp0setup.ps1 %*` → `pause`。
  ZIP 用 `Encoding.UTF8` 打包（General-purpose bit 11 自動設），Windows 內建檔案總管
  解壓中文檔名不會亂碼。
- **lint**：CI 沒有跑 PSScriptAnalyzer，但可以本機用 PowerShell Parser 檢查語法：

  ```powershell
  pwsh -NoProfile -Command @"
  \$errors = \$null
  [System.Management.Automation.Language.Parser]::ParseFile('assets/setup.ps1', [ref]\$null, [ref]\$errors) | Out-Null
  if (\$errors) { \$errors | %{ \$_.Message } ; exit 1 }
  "@
  ```

---

## Dev Pack 設計

dev pack 現在**直接合併進單一 ZIP**（與入口腳本同處 ZIP 根目錄）。`assets-devpack/`
只剩兩支 ps1 腳本，沒有自己的入口 cmd 或 README——共用最外層的 `setup.ps1` /
`點擊兩下-完整安裝(推薦).cmd` / `README.txt`。

- **shell.csproj（packager 內動態產生）**：故意拉一個完整的 NUnit + MSTest + Test SDK
  圖，包含 `Microsoft.Playwright(.NUnit/.MSTest)` 1.60.0。版本寫死，避免每次打包
  抓到不同版本造成「黑盒擴張」。
- **為什麼用 `dotnet restore --packages <tmp>` 而不是 `nuget install`**：純 .NET SDK
  即可，不需要額外裝 nuget.exe；CI 跑得起來。
- **flatten 策略**：`--packages` 解出的目錄結構是 `{id-lowercase}/{version}/...`，
  每個版本資料夾內有原本的 `.nupkg`。我們遞迴抓所有 `*.nupkg`、用檔名去重（同 id
  同 version 不會出現兩個 nupkg），複製到 ZIP 內的 `nuget/`。產出約 30 個唯一檔案。
- **為什麼落點選 `%USERPROFILE%\.nuget\packages`**：這是 NuGet 預設的使用者
  global package 位置，符合 `dotnet restore` / `dotnet add package` 的常見預設。
  setup 會把 nupkg 依 package id / version 放入這個資料夾，並另外註冊
  `ferry-playwright-feed` 指向同一路徑，讓嚴格離線的 `dotnet add package` 仍能解析。
- **為什麼還要另外寫 `%ProgramData%\NuGet\NuGet.Config`**：純 .NET SDK / VS Code
  場景沒有 VS 的 NuGet config，所以需要在機器層 NuGet.Config 顯式加 source。
  setup 用 `[xml]` 物件 idempotent 操作（重覆執行不會堆出重複條目），改前先
  `Copy-Item` 備份為 `.bak.YYYYMMDD-HHMMSS`。
- **預設停用 nuget.org（v0.5.1 起）+ 專案層 `<clear />`（v0.5.2 起）**：
  - 機器層 disable nuget.org 解決了「dotnet add package 沒指定版本時偷打
    api.nuget.org 找 latest」。但 v0.5.1 之後使用者回報「還是 SSL 錯」——
    根因是 NuGet config 是**層疊式**：使用者層 (`%AppData%\Roaming\NuGet\NuGet.Config`)、
    solution-level、project-local 都會 merge 進來。如果使用者層宣告了其他
    remote source（例如公司 Azure DevOps feed），即便我們 disable 了
    nuget.org，dotnet 還是會把那些 source 打一輪 → SSL 錯。
  - 解法是「**專案層**寫一份只含 `<clear />` + ferry-playwright-feed 的
    NuGet.config」。`<clear />` 在 NuGet 規格裡是「丟掉所有繼承的 sources」，
    所以無論上層怎麼髒，restore 都只看得到 ferry-playwright-feed。
  - 我們 ship 兩個東西，**直接放在 ZIP 根目錄**（不複製到 `%ProgramFiles%`）：
    - `NuGet.config.template`：給「手動派」直接 copy 用。
    - `new-playwright-project.ps1`：helper script。`dotnet new <tpl> --no-restore`
      之前先把 template copy 進新專案，然後用**鎖定版本**（與 packager
      bundle 一致：Playwright 1.60.0、NUnit 4.2.2、MSTest 3.6.4、Test.Sdk
      17.11.1，以及 `dotnet new nunit`/`mstest` 模板隱含相依的
      `coverlet.collector` 6.0.2、`NUnit.Analyzers` 4.4.0、`MSTest.Analyzers`
      3.6.4 — 全部 v0.5.3 起 bundle）跑 `dotnet add package`，最後一次 restore。
  - 機器層 disable 仍保留（屬於 defense-in-depth），`-KeepNuGetOrg` 可關掉。
  - 使用者直接從解壓資料夾呼叫 helper / template：
    `& "C:\ferry-playwright\new-playwright-project.ps1" -Name MyTests` 或
    `Copy-Item "C:\ferry-playwright\NuGet.config.template" .\NuGet.config`。
- **冪等設環境變數**：`setup-devpack.ps1` 寫
  `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`、`PLAYWRIGHT_BROWSERS_PATH=0`（Machine
  scope），讓 sample / 使用者自己的測試專案執行 Playwright 時不會嘗試下載 Chromium。
- **無縫升級用的 sentinel**：每次 setup-devpack 跑完，會在 `<FeedDir>` 寫一份
  `ferry-playwright-feed.INDEX.txt` 列出本次部署的 nupkg 檔名（含 PackageVersion
  與時間戳註解）。下次新版 setup-devpack 跑：
  - 讀 sentinel 拿到「上次裝過的檔名集合」。
  - 解析每個檔名 → `(id, version)`（regex `^(?<id>.+?)\.(?<ver>\d[\w\.\-\+]*)$`）。
  - 對於 sentinel 中的舊檔，若新 bundle 也有同 id 但版本不同 → 刪掉 FeedDir 內的舊檔。
  - 拷新檔、覆寫 sentinel。
  - 結果：FeedDir 內**永遠只剩最新一組**我們的 nupkg；其他 NuGet cache
    內容一律不動，因為它們不在 sentinel 裡。
  - 升級時也會清掉 v0.6.x 留下的舊 sentinel `PlaywrightOfflineFeed.INDEX.txt`
    與舊 source name `PlaywrightOfflineFeed`。
- **uninstall-devpack.ps1 的限制**：
  - 優先用 `<FeedDir>\ferry-playwright-feed.INDEX.txt`（涵蓋升級累積的所有檔），
    找不到才退回 bundled `nuget/INDEX.txt`。**只**刪這份清單裡的檔，不誤刪
    其他 NuGet cache 內容。完成後也會把 sentinel 一併刪掉。
  - 不掃整個 `%USERPROFILE%\.nuget\packages`（其他專案可能在用已 restore 的版本）。
  - 環境變數 `PLAYWRIGHT_*` **不會**被 uninstall 流程清理（避免影響仍在使用的測試專案）。
    如要徹底重置，手動 `[Environment]::SetEnvironmentVariable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', $null, 'Machine')` 即可。

---

## 版號（VERSION.txt）來源

打包時 packager 依序嘗試以下來源，取第一個非空者，並去掉 leading `v`：

1. `--version <semver>` 命令列旗標
2. `PACKAGE_VERSION` 環境變數（CI 從 tag 帶入）
3. `git describe --tags --always --dirty`（無 tag 時會退而給 short SHA）
4. fallback：`0.0.0-dev`

寫入位置：

- ZIP 根目錄的 `VERSION.txt`（純文字一行）— 給工具讀；歷史用途是 wrapper 比對升級。
- `BUILD-INFO.txt` 內的 `Version: ...` 一行 — 給人讀。
- `nuget/INDEX.txt` 標頭的 `# PackageVersion: ...` — 給人讀 / debug。
- ZIP 檔名 `ferry-playwright-v<version>-<rid>-<timestamp>.zip` — 一眼可辨。

---

## CI / Release workflow

檔案：`.github/workflows/release.yml`。觸發條件：push tag `v*`，或 `workflow_dispatch`。

三個 jobs：

### 1. `package` (ubuntu-latest)

- `actions/setup-dotnet@v4` + `dotnet-quality: preview`。
- 跑 `dotnet run --project src/FerryPlaywright.OfflinePackager`。
- 計算 SHA256，產生 `release-notes.md`（Summary + Self-test results + Changes since previous tag，
  後者用 `git log` + `git diff --stat`）。
- 上傳 `offline-package` artifact（ZIP + 釋出說明）。

### 2. `verify-offline` (windows-2022) — 嚴格離線驗證閘門

順序很重要，下面的步驟少一步就會誤判：

1. **Baseline-check 有網路** — 若 runner 本來就拿不到 internet，直接 fail
   （避免「假離線通過」的偽陽性）。
2. **封鎖 outbound** — `Set-NetFirewallProfile -DefaultOutboundAction Block`
   加 loopback 允許規則。
3. **再驗證 block** — 若 `Test-NetConnection www.microsoft.com 443` 仍成功 → fail。
4. **snapshot TCP 連線** → 跑 `setup.ps1`（安裝 dev pack）→ 在解壓出的
   `samples\hello-console` 跑 `dotnet build -c Release --no-restore`（驗證 bundled
   NuGet feed 真的足以離線解析 + build）。
5. **TCP audit** — 比對 after 快照與 before 快照的差集；任何**非** loopback / link-local 的
   新 TCP tuple 都會讓 job 失敗。
6. **`always()` cleanup** — 在 audit-artifact upload **之前** 還原防火牆
   （upload artifact 需要 internet）。

### 3. `release` (ubuntu-latest, 僅在 tag `v*` 時)

- `softprops/action-gh-release@v2`：`body_path: release-notes.md`、
  `generate_release_notes: true`、把 ZIP 作為附件。

### 工作流程的歷史地雷（已修，仍要小心）

- `actions/download-artifact@v4` 會保留目錄層次：找 ZIP 要用 `Get-ChildItem -Recurse`，
  不能用單純的 glob。
- Windows runner 啟動時本就有許多預先存在的 GitHub / Azure TCP 連線，
  TCP audit 必須是「事前 vs 事後 diff」，不是「事後不能有任何已建立連線」。
- artifact upload 要 internet → cleanup 防火牆步驟必須先跑。

---

## MCP（Copilot CLI / VS Code Copilot）

`.mcp.json`（位於 repo 根目錄）註冊 **Playwright MCP server**：

```json
{
  "servers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest", "--browser", "msedge"]
    }
  }
}
```

- 用 `npx -y` 啟動，免全域安裝。
- 寫死 `--browser msedge` 對齊本專案 runtime 契約。
- 從根目錄讀取（Copilot CLI 已移除 `.vscode/mcp.json` 支援，新格式統一放在 `.mcp.json`）。
- 這是 **開發者本機** 用的，第一次會從 npm 下載，不影響我們交付的離線 ZIP。
- 若哪天範例應用換瀏覽器 channel，記得這裡的 `--browser` 也要改。

---

## 客製化：換成自己的應用

v0.6 起 ZIP **不再**包含預編譯 runtime——範例都是 sample 原始碼，所以「換成自己的應用」
有兩種主要做法：

**做法 1：在 `assets-samples/` 加一個新 sample 子資料夾**

`assets-samples/` 內任何子資料夾都會被 packager 在 STEP 3 整個複製到 ZIP 內的
`samples/`，使用者解壓後即可 `cd samples\<你的專案>; dotnet test`（或 `dotnet run`）。

1. 新增 `assets-samples/my-sample/` 並放入：
   - 你的 `.csproj`（引用 `Microsoft.Playwright(.NUnit/.MSTest)` 或純 console）。
   - 一份 `NuGet.config`（`<clear/>` + ferry-playwright-feed，可參考其他 sample）。
   - 程式碼裡 launch 時用 `Channel = "msedge"`，這是離線契約的關鍵。
2. 確認你引用的所有 NuGet 套件都已在 packager 的 `shell.csproj` 列表內，
   否則 setup-devpack 安裝出來的 feed 會缺檔。需要新套件時，編輯
   `src/FerryPlaywright.OfflinePackager/Program.cs` 加 `PackageReference`。
3. 跑 `dotnet run --project src/FerryPlaywright.OfflinePackager` 重新打包，
   確認 ZIP 內出現 `samples/my-sample/`。

**做法 2：本機開發時用 `FerryPlaywright.SampleApp`**

`src/FerryPlaywright.SampleApp/Program.cs` 仍保留，用來本機快速驗證 Playwright +
Edge 是否正常（不會被打包進 ZIP）。可以在這裡加你的自動化邏輯做煙霧測試，
但保留 `Channel = "msedge"` 與 `--ci` 模式（部分本機 / CI 工具仍會用 `--ci` 跑 headless）。

---

## 發布新版本

1. 在 `CHANGELOG.md` 把 `[Unreleased]` 改成新版本號（Keep a Changelog 風格）。
2. commit。
3. 打 tag 並推：

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

4. GitHub Actions 自動跑 `package` → `verify-offline` → `release`。
   `verify-offline` 任何失敗都會阻擋 release job 執行。
5. release 頁面會附 ZIP 與自動生成的 diff 紀錄。

---

## 限制與注意事項

- **macOS / Linux 開發** 可產 win-x64 ZIP（NuGet restore 跨平台），但無法在本機跑
  `setup.ps1`；最終驗證仍需 Windows 環境（或直接相信 CI 的離線驗證閘門）。
- **目標機需要 .NET 10 SDK** — ZIP 不再內含 self-contained runtime（v0.6 起的設計
  決策：避免 ~350 MB ZIP，且讓使用者用自己的工具鏈 build/test）。請另行交付 SDK
  離線安裝檔。
- **未經程式碼簽章** 的 `.exe`（若你自行 build），目標機 SmartScreen 首次執行會跳警告；
  企業要分發請另行簽章。
- 目前僅支援 **系統 Edge**。若需內建 Chromium / Firefox，要修改 packager 與 setup
  腳本把 `PLAYWRIGHT_BROWSERS_PATH` 對應的瀏覽器二進位也納入 ZIP。
