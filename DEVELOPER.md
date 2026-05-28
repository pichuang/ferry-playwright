# DEVELOPER.md — ferry-playwright

技術細節與貢獻指引。一般使用者請看 [README.md](README.md)。

---

## 為什麼能完全離線

| 元件 | 處理方式 |
| --- | --- |
| .NET Runtime | `dotnet publish --self-contained -r win-x64` 將 runtime 內嵌到應用 |
| Playwright .NET 受管組件 | `Microsoft.Playwright` NuGet 隨 publish 一併輸出 |
| Playwright Node 驅動 (`node.exe`) | NuGet 內附，publish 時自動複製到 `.playwright/node/win32_x64/` |
| 瀏覽器 | 使用系統 Edge (`Channel = "msedge"`)，**完全不下載** Chromium / Firefox |
| 環境變數 | `install.ps1` 設機器層級 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`、`PLAYWRIGHT_BROWSERS_PATH=0` |

只要這幾件事都成立，目標機上就完全沒有任何「需要連網才能完成」的步驟。

---

## 專案結構

```
ferry-playwright/
├── src/
│   ├── PlaywrightSampleApp/         # 被打包的範例應用（Channel="msedge"，支援 --ci）
│   └── PlaywrightOfflinePackager/   # 打包工具
├── assets/                          # runtime + 入口腳本（會包進 ZIP 根目錄）
│   ├── 點擊兩下-setup.cmd            # 一鍵入口（runtime + dev pack）
│   ├── setup.ps1                    # 呼叫 install.ps1 + setup-devpack.ps1
│   ├── 點擊兩下-install.cmd          # 進階：只裝 runtime
│   ├── install.ps1                  # runtime 一鍵安裝腳本
│   ├── 點擊兩下-uninstall.cmd        # 雙擊解除（dev pack + runtime）
│   ├── uninstall.ps1                # wrapper: uninstall-devpack → uninstall-runtime
│   ├── uninstall-runtime.ps1        # 只解除 runtime 的腳本
│   └── README.txt                   # 給最終使用者的合併版說明（繁體中文）
├── assets-devpack/                  # dev pack 專用 staging（會包進 ZIP 根目錄）
│   ├── setup-devpack.ps1            # 註冊離線 NuGet feed + 寫機器層 NuGet.Config
│   └── uninstall-devpack.ps1
├── .github/
│   ├── workflows/release.yml        # CI：打包 + 離線驗證 + GitHub Release
│   └── copilot-instructions.md      # 給 Copilot 的 repo 速覽
├── .vscode/
│   └── mcp.json                     # VS Code Copilot 的 Playwright MCP 設定
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
dotnet run --project src/PlaywrightSampleApp -- https://example.com

# 跑範例應用（CI 模式：headless、不等輸入、預設 about:blank）
CI=true dotnet run --project src/PlaywrightSampleApp -- --ci

# 產生離線 ZIP（預設 win-x64 / Release / 寫入 output/）
dotnet run --project src/PlaywrightOfflinePackager

# 自訂 packager 參數
dotnet run --project src/PlaywrightOfflinePackager -- \
  --rid     win-x64 \
  --config  Release \
  --output  output \
  --project src/PlaywrightSampleApp/PlaywrightSampleApp.csproj \
  --assets  assets
```

---

## Packager pipeline

`src/PlaywrightOfflinePackager/Program.cs` 是單檔頂層程式，產出**單一 ZIP**
（runtime + dev pack 全在裡面），步驟順序：

1. **Restore** — `dotnet restore <sample.csproj>`。
2. **Publish** — `dotnet publish -c Release -r win-x64 --self-contained true` 到暫存 `app/`。
3. **Verify Playwright driver present** — 強制檢查 `app/.playwright/node/win32_x64/node.exe`
   存在，否則整個打包失敗。**這是整個離線契約最重要的單一檢查點**。
4. **Restore dev pack (NuGet graph)** — 在暫存資料夾寫一個 minimal `shell.csproj`，
   參照 `Microsoft.Playwright`、`Microsoft.Playwright.NUnit`、`Microsoft.Playwright.MSTest`、
   `Microsoft.NET.Test.Sdk`、`NUnit` + adapter、`MSTest` + adapter，然後跑
   `dotnet restore --packages <tmp> --runtime win-x64 --no-cache`。
5. **Collect .nupkg files** — 遞迴搜出所有 `*.nupkg`，去重後 flatten 到 `<staging>/nuget/`，
   並寫 `nuget/INDEX.txt`（卸載腳本會用此清單）。
6. **Stage runtime assets** — 把 `assets/` 內容（入口 cmd + 入口 ps1 + runtime ps1 + README）
   複製到 ZIP 根目錄。
7. **Stage dev pack assets** — 把 `assets-devpack/` 內容（setup-devpack.ps1、uninstall-devpack.ps1）
   複製到 ZIP 根目錄（與步驟 6 同層）。
8. **Write build metadata** — 寫 `BUILD-INFO.txt`（RID、設定、時間）。
9. **Create ZIP** — 把整個 staging 目錄壓成 `output/PlaywrightOffline-win-x64-<timestamp>.zip`。

最終 ZIP 結構：

```
PlaywrightOffline-win-x64-YYYYMMDD-HHMMSS.zip   (runtime + dev pack, ~350 MB)
├── app/                              # self-contained publish 輸出
│   ├── PlaywrightSampleApp.exe
│   ├── *.dll                         # .NET runtime + Microsoft.Playwright
│   └── .playwright/node/win32_x64/node.exe
├── nuget/                            # 離線 NuGet feed（26 nupkgs）
│   ├── microsoft.playwright.1.60.0.nupkg
│   ├── microsoft.playwright.nunit.1.60.0.nupkg
│   ├── microsoft.playwright.mstest.1.60.0.nupkg
│   ├── microsoft.net.test.sdk.*.nupkg
│   ├── nunit.*.nupkg + nunit3testadapter.*.nupkg
│   ├── mstest.*.nupkg + mstest.testadapter.*.nupkg
│   ├── ... (26 unique nupkgs total)
│   └── INDEX.txt
├── 點擊兩下-setup.cmd                # 一鍵入口：runtime + dev pack
├── setup.ps1                         # 呼叫 install.ps1 + setup-devpack.ps1
├── 點擊兩下-install.cmd              # 進階：只裝 runtime
├── install.ps1
├── setup-devpack.ps1                 # 進階：只裝 dev pack
├── 點擊兩下-uninstall.cmd
├── uninstall.ps1                     # wrapper: uninstall-devpack → uninstall-runtime
├── uninstall-runtime.ps1
├── uninstall-devpack.ps1
├── README.txt
└── BUILD-INFO.txt
```

---

## 入口腳本設計（setup.ps1 / uninstall.ps1）

- **setup.ps1**：self-elevate → 呼叫同目錄的 `install.ps1`（runtime）→ 呼叫同目錄的
  `setup-devpack.ps1`（dev pack）。`$ErrorActionPreference = 'Stop'`，runtime 失敗就
  整個中斷，不會跑 dev pack。
- **uninstall.ps1**：self-elevate → 呼叫 `uninstall-devpack.ps1`（包 try/catch，**非致命**：
  失敗只發 warning）→ 呼叫 `uninstall-runtime.ps1`。順序選 dev pack 先是因為 NuGet feed
  設定不影響 runtime 砍檔，反過來 runtime 砍掉後 dev pack 還是要清；而且 dev pack 的
  uninstall 不會去動 `PLAYWRIGHT_*` 環境變數，是 `uninstall-runtime.ps1` 才會清。
- **點擊兩下-setup.cmd** 與其他 cmd 一樣模式：`chcp 65001` → `powershell -NoProfile
  -ExecutionPolicy Bypass -File %~dp0setup.ps1 %*` → `pause`。

---

## install.ps1 / uninstall-runtime.ps1 設計

- **雙擊體驗**：另附 `點擊兩下-install.cmd` / `點擊兩下-uninstall.cmd` 包裝，本質就是
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*` + `pause`。
  使用者雙擊即可，UAC 提權沿用下面 .ps1 的 `Invoke-SelfElevate`。
  （ZIP 用 `Encoding.UTF8` 打包，General-purpose bit 11 會自動設，Windows 內建
   檔案總管解壓中文檔名不會亂碼。）
- **自我提權**：偵測非 Administrator 時用 `Start-Process -Verb RunAs` 重啟自己。
- **Edge 檢查**：找 `Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
  或註冊機碼。可用 `-SkipEdgeCheck` 略過。
- **環境變數寫入 Machine scope**，而非 User scope，這樣任何使用者帳號都生效。
- **shortcuts**：使用 `WScript.Shell` COM 物件建立 `.lnk`。
- **錯誤處理**：`$ErrorActionPreference = 'Stop'`，遇到例外整個中止。
- **lint**：CI 沒有跑 PSScriptAnalyzer，但可以本機用 PowerShell Parser 檢查語法：

  ```powershell
  pwsh -NoProfile -Command @"
  \$errors = \$null
  [System.Management.Automation.Language.Parser]::ParseFile('assets/install.ps1', [ref]\$null, [ref]\$errors) | Out-Null
  if (\$errors) { \$errors | %{ \$_.Message } ; exit 1 }
  "@
  ```

---

## Dev Pack 設計

dev pack 現在**直接合併進單一 ZIP**（與 runtime 同處 ZIP 根目錄）。`assets-devpack/`
只剩兩支 ps1 腳本，沒有自己的入口 cmd 或 README——共用最外層的 `setup.ps1` /
`點擊兩下-setup.cmd` / `README.txt`。

- **shell.csproj（packager 內動態產生）**：故意拉一個完整的 NUnit + MSTest + Test SDK
  圖，包含 `Microsoft.Playwright(.NUnit/.MSTest)` 1.60.0。版本寫死，避免每次打包
  抓到不同版本造成「黑盒擴張」。
- **為什麼用 `dotnet restore --packages <tmp>` 而不是 `nuget install`**：純 .NET SDK
  即可，不需要額外裝 nuget.exe；CI 跑得起來。
- **flatten 策略**：`--packages` 解出的目錄結構是 `{id-lowercase}/{version}/...`，
  每個版本資料夾內有原本的 `.nupkg`。我們遞迴抓所有 `*.nupkg`、用檔名去重（同 id
  同 version 不會出現兩個 nupkg），複製到 ZIP 內的 `nuget/`。產出 26 個唯一檔案。
- **為什麼落點選 `%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages`**：這是
  Visual Studio Installer 寫 Offline Packages 的同一個資料夾，VS 安裝後預設
  package source `Microsoft Visual Studio Offline Packages` 就指向它。把我們的
  nupkg 放這裡，VS 使用者連 NuGet.Config 都不必改就看得到 Microsoft.Playwright。
- **為什麼還要另外寫 `%ProgramData%\NuGet\NuGet.Config`**：純 .NET SDK / VS Code
  場景沒有 VS 的 NuGet config，所以需要在機器層 NuGet.Config 顯式加 source。
  setup 用 `[xml]` 物件 idempotent 操作（重覆執行不會堆出重複條目），改前先
  `Copy-Item` 備份為 `.bak.YYYYMMDD-HHMMSS`。
- **預設不停用 nuget.org**：使用者若偶爾有網路通道，nuget.org 仍可走 fallback；
  想強制離線可帶 `-DisableNuGetOrg`（透過 `setup.ps1` forward 也可）。
- **冪等設環境變數**：與 `install.ps1` 同樣寫
  `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`、`PLAYWRIGHT_BROWSERS_PATH=0`（Machine
  scope），讓 dev pack 可單獨使用（直接執行 `setup-devpack.ps1`），不必先裝 runtime。
- **uninstall-devpack.ps1 的限制**：
  - 用 `nuget/INDEX.txt` 當 allow-list，**只**刪我們塞進去的 nupkg；不誤刪
    `Microsoft SDKs\NuGetPackages` 內 VS Installer 既有的套件。
  - 不清 `%USERPROFILE%\.nuget\packages`（其他專案可能在用已 restore 的版本）。
  - 不清 PLAYWRIGHT_* 環境變數（runtime 可能還在用）；那是 `uninstall-runtime.ps1`
    的工作。

---

## CI / Release workflow

檔案：`.github/workflows/release.yml`。觸發條件：push tag `v*`，或 `workflow_dispatch`。

三個 jobs：

### 1. `package` (ubuntu-latest)

- `actions/setup-dotnet@v4` + `dotnet-quality: preview`。
- 跑 `dotnet run --project src/PlaywrightOfflinePackager`。
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
4. **snapshot TCP 連線** → 跑 `install.ps1` → 跑 `PlaywrightSampleApp.exe --ci`。
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

## MCP（VS Code Copilot）

`.vscode/mcp.json` 註冊 **Playwright MCP server**：

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
- 這是 **開發者本機** 用的，第一次會從 npm 下載，不影響我們交付的離線 ZIP。
- 若哪天範例應用換瀏覽器 channel，記得這裡的 `--browser` 也要改。

---

## 客製化：換成自己的應用

最簡單的方式：直接在 `src/PlaywrightSampleApp/Program.cs` 加你的自動化邏輯，
保留 `Channel = "msedge"` 與 `--ci` 模式（CI 工作流程依賴後者做離線驗證）。

進一步：把整個 `src/PlaywrightSampleApp/` 換成你自己的 .NET 專案：

1. 你的專案需要：
   - 引用 `Microsoft.Playwright` NuGet。
   - 在啟動 Playwright 時使用 `Channel = "msedge"`。
   - 提供一個非互動的 CI mode（讓 GitHub Actions 跑得起來），預設 URL `about:blank` 即可。
2. 用 `--project` 指向新位置：

   ```bash
   dotnet run --project src/PlaywrightOfflinePackager -- \
     --project path/to/YourApp/YourApp.csproj
   ```

3. 如果你改了主執行檔名稱，記得同步更新 `assets/install.ps1` 與 `assets/uninstall.ps1`
   裡的 `$exeName = 'PlaywrightSampleApp.exe'`。

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

- **macOS / Linux 開發** 可產 win-x64 self-contained ZIP，但無法在本機跑 `install.ps1`；
  最終驗證仍需 Windows 環境（或直接相信 CI 的離線驗證閘門）。
- **未經程式碼簽章** 的 .exe，目標機 SmartScreen 首次執行會跳警告；企業要分發請另行簽章。
- 目前僅支援 **系統 Edge**。若需內建 Chromium / Firefox，要修改 packager
  把 `PLAYWRIGHT_BROWSERS_PATH` 對應的瀏覽器二進位也納入 ZIP，並調整 install 腳本指向。
