# ferry-playwright

> 一鍵把 Playwright for .NET 應用打包為**完全離線**的 Windows 安裝包。
> 在 **Windows 11 / Windows Server 2022** 上不需要任何網路，
> 就能用系統內建的 **Microsoft Edge** 跑 Playwright 自動化。

---

## 版本資訊

| 項目 | 版本 |
| --- | --- |
| ferry-playwright | **v0.7.0**（最新 release；可能含尚未發布的變更，見 [CHANGELOG.md](CHANGELOG.md)） |
| Microsoft.Playwright (.NET) | **1.60.0** |
| .NET runtime / SDK | **.NET 10**（SDK pin `10.0.100`，`allowPrerelease: true`） |
| 目標作業系統 | Windows 11 / Windows Server 2022（build ≥ 17763） |
| 瀏覽器 | 系統內建 Microsoft Edge（`Channel = "msedge"`，不下載 Chromium / Firefox） |
| 打包目標 RID | `win-x64` |

> 想知道某份 ZIP 是哪一次打包的？解壓後看根目錄 `BUILD-INFO.txt`，
> 內含 build 時間、RID 與 config。完整版本歷史請見 [CHANGELOG.md](CHANGELOG.md)。

---

## 它能幫你做什麼

如果你的場景符合以下任何一條，這個專案就是寫給你看的：

- 工廠 / 政府 / 內部網管環境：機器拿不到 internet，但仍要跑 Playwright 自動化。
- 你不想讓 Playwright 在每台機器上下載 ~500MB 的 Chromium / Firefox。
- 你要把 .NET 應用 + Playwright 環境用「一個 ZIP + 一鍵安裝」交付給客戶 / IT。

把產生的 ZIP 用 USB 拷貝過去 → 解壓 → 雙擊 `點擊兩下-完整安裝(推薦).cmd` → 結束。不需要 internet、不需要安裝 Edge（系統已內建）。**.NET 10 SDK** 需另行準備（離線安裝檔）才能 build/跑範例。

---

## 系統需求（目標機）

| 項目 | 需求 |
| --- | --- |
| 作業系統 | Windows 11 / Windows Server 2022 或更新 |
| 瀏覽器 | Microsoft Edge（兩種系統都預載） |
| 權限 | 安裝時需要本機 Administrator |
| 網路 | **不需要**（安裝、build sample、跑 Playwright 全程離線） |
| .NET | 需要 **.NET 10 SDK**（用來 build sample 或自己的測試；dev pack 只供 NuGet 套件） |

---

## 給「拿到 ZIP」的人：怎麼安裝

> 從 **v0.6.0** 起，ZIP 內容改為「離線 NuGet feed + 三個 sample 原始碼專案」，
> **不再包含** 預編譯的 `FerryPlaywright.SampleApp.exe`。如果你想看一個完整的
> Playwright + Edge 範例，請直接看解壓後的 `samples/hello-nunit`、
> `samples/hello-mstest` 或 `samples/hello-console`。

### 一鍵安裝（dev pack）

1. 把 `ferry-playwright-vX.Y.Z-win-x64-YYYYMMDD-HHMMSS.zip` 拷到目標機，解壓縮。
2. 進入解壓後的資料夾，**雙擊** `點擊兩下-完整安裝(推薦).cmd`。
3. 接受 UAC 提權對話框（只會問一次）。
4. 看到「Dev pack installed.」即完成。

腳本會：

- 把所有 `.nupkg` 複製到 `%USERPROFILE%\.nuget\packages`
  （NuGet 預設的使用者 package 位置）
- 在 `%ProgramData%\NuGet\NuGet.Config` 註冊一條 `ferry-playwright-feed` 來源
  （舊檔備份為 `.bak.YYYYMMDD-HHMMSS`），預設停用 `nuget.org`（嚴格離線）
- 設機器層環境變數 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` /
  `PLAYWRIGHT_BROWSERS_PATH=0`，讓 Playwright 永遠不嘗試下載 Chromium
- 若偵測到 v0.5.x 留下的 `C:\Program Files\PlaywrightApp\`，順手清掉

### 跑範例

```powershell
# 把 hello-nunit 複製到自己的工作目錄
Copy-Item -Recurse .\samples\hello-nunit C:\Work\
cd C:\Work\hello-nunit
dotnet test --settings .runsettings
```

> 進階：`setup.ps1 -KeepNuGetOrg` 可在保留 nuget.org 作為 fallback 的情況下安裝
> （適合有間歇性網路的機器）。

### 跑範例

> v0.6.0 起 ZIP 不再附 `FerryPlaywright.SampleApp.exe`。要看一個「會跑起來的範例」，
> 請直接用 `samples/hello-console`：

```powershell
Copy-Item -Recurse .\samples\hello-console C:\Work\
cd C:\Work\hello-console
dotnet run            # 互動：開啟 Edge、按 ENTER 結束
dotnet run -- --ci    # CI：headless，跑完直接結束
```

`samples/hello-nunit` / `samples/hello-mstest` 則用：

```powershell
dotnet test --settings .runsettings
```

### 安裝完怎麼用 dev pack 寫自己的測試

打開**新的** PowerShell，就能離線新增專案：

```powershell
mkdir hello-playwright; cd hello-playwright
dotnet new nunit
dotnet add package Microsoft.Playwright.NUnit
```

或直接用 ZIP 內附的 helper：

```powershell
& ".\new-playwright-project.ps1" -Name MyTests -Template nunit
```

### 升級到新版本

直接執行新版 ZIP 內的 `點擊兩下-完整安裝(推薦).cmd` 即可，**不需要**先解除安裝。腳本會自動：

- dev pack 部分會讀取上次留下的 sentinel `ferry-playwright-feed.INDEX.txt`，**只刪掉同 package id
  但不同版本或舊版佈局的 .nupkg**，再放入新版；其他 NuGet cache 內容一律不動。
- 若偵測到舊版（v0.5.x）的 `C:\Program Files\PlaywrightApp\`，會順手清掉。

### 解除安裝

在同一個解壓資料夾，**雙擊** `點擊兩下-解除安裝.cmd`。腳本會從機器層 NuGet.Config 移除來源、
依 INDEX.txt 刪掉我們塞進去的 .nupkg（不會誤刪其他 Microsoft 既有的 offline 套件），並一併
清掉 v0.5.x 留下的 `C:\Program Files\PlaywrightApp` 目錄與捷徑（若存在）。

---

## 給「想自己產生 ZIP」的人

只要一台**有網路**、安裝了 .NET 10 SDK 的開發機（macOS / Linux / Windows 都行）：

```bash
git clone https://github.com/pichuang/ferry-playwright.git
cd ferry-playwright
dotnet run --project src/FerryPlaywright.OfflinePackager
```

ZIP 會出現在 `output/ferry-playwright-vX.Y.Z-win-x64-*.zip`（dev pack + 三個 sample 原始碼，
約 280 MB；其中 Microsoft.Playwright 套件本身就佔大宗），把它拷給目標機就好。

> 進一步的打包選項、自訂應用、CI 自動發布、架構說明，請參考 **[DEVELOPER.md](DEVELOPER.md)**。

---

## 想在這台機器寫自己的 Playwright 測試？

這份 ZIP 提供的是「跑得起來」的最小環境。如果你想在同一台機器上
**自己寫新的 Playwright 測試案例**，下面說明怎麼用 VS Code / Visual Studio / PowerShell 上手。

### 前置作業（一次性）

1. **安裝 .NET 10 SDK**（這份 ZIP 不含 SDK）。
   - 官方下載：<https://dotnet.microsoft.com/download>
   - 若這台機器**完全沒有網路**，請從另一台有網路的機器下載 SDK 安裝檔，
     再 sneakernet 過來；或在貴公司內部 NuGet/檔案伺服器準備離線安裝檔。
2. **離線解決 NuGet 套件**：在離線機器執行
   `dotnet add package Microsoft.Playwright` 預設會打 `api.nuget.org` 而失敗。
   有兩種解法：

   - **（推薦）用本專案 ZIP 一鍵裝完** — 解壓後雙擊
     `點擊兩下-完整安裝(推薦).cmd`，會把 `Microsoft.Playwright`、
     `Microsoft.Playwright.NUnit`、`Microsoft.NET.Test.Sdk`、NUnit、MSTest
     等 .nupkg **複製到 NuGet 預設的使用者 package 資料夾**
      (`%USERPROFILE%\.nuget\packages`)，並在
     `%ProgramData%\NuGet\NuGet.Config` 註冊一條 `ferry-playwright-feed` source，
     **預設停用 `nuget.org`**（嚴格離線；確保 `dotnet add package` 不會偷打
     api.nuget.org 查 latest version）。之後任何新專案
     `dotnet add package Microsoft.Playwright` 都會走離線 feed。若想保留
     nuget.org 當 fallback，安裝時加 `-KeepNuGetOrg`。
   - 或自行帶整個 `~/.nuget/packages` 過來，或自建內網 NuGet 私服。
3. **確認環境變數已套用**（雙擊安裝後會設好）：
   ```powershell
   [Environment]::GetEnvironmentVariable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD','Machine')  # → 1
   [Environment]::GetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH','Machine')         # → 0
   ```
   有了這兩個，新專案執行時就**不會**嘗試下載 Chromium，會走系統 Edge。

> 後文範例假設你把 ZIP 解壓在 `C:\ferry-playwright\`；如果你解壓在別處，
> 請把 `C:\ferry-playwright\` 換成你的實際路徑。Helper script
> (`new-playwright-project.ps1`) 與 `NuGet.config.template` 直接放在解壓資料夾根目錄，
> 不會複製到 `%ProgramFiles%`。

### 核心模式：永遠用系統 Edge

不管選哪種專案類型，**Launch 時一定要指定 `Channel = "msedge"`**，
這是這個離線方案的關鍵：

```csharp
await using var browser = await pw.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
{
    Channel  = "msedge",   // ← 不下載 Chromium，直接用系統 Edge
    Headless = true,
});
```

### 在 VS Code

1. 安裝擴充套件：
   - **C# Dev Kit**（Microsoft 官方，含 IntelliSense + Test Explorer）
   - 選用：**Playwright Test for VSCode**（如果你之後想加 trace viewer 整合）
2. 用 ZIP 內附的 helper 建立離線 NUnit 測試專案（**強烈推薦**，避開所有 NuGet 雷區）：
   ```powershell
   & "C:\ferry-playwright\new-playwright-project.ps1" -Name MyPwTests
   cd MyPwTests
   code .
   ```
   > Helper 會在新專案根目錄寫一份 `NuGet.config`，內含 `<clear />` 把所有繼承
   > 的 NuGet source 都清掉，只留 ferry-playwright-feed；接著用**鎖定的版本**
   > 跑 `dotnet new nunit` + `dotnet add package`，所以無論你的個人 / 機器 / 公司
   > 層 NuGet 設定有多奇怪、`dotnet new nunit` 模板想抓哪個版本，全部都會走離線。
3. 若你**堅持手動**用 `dotnet new nunit; dotnet add package ...`，請先在新專案根
   目錄複製一份 `NuGet.config.template` 改名成 `NuGet.config`：
   ```powershell
   mkdir MyPwTests; cd MyPwTests
   Copy-Item "C:\ferry-playwright\NuGet.config.template" .\NuGet.config
   dotnet new nunit
   dotnet add package Microsoft.Playwright       --version 1.60.0
   dotnet add package Microsoft.Playwright.NUnit --version 1.60.0
   ```
   > **為什麼一定要這個 NuGet.config？**
   > 機器層 `disabledPackageSources` 只能擋 `nuget.org`，擋不掉使用者層
   > (`%AppData%\Roaming\NuGet\NuGet.Config`) 帶進來的其他 remote source
   > （公司 Azure DevOps feed / 內部 proxy 等）。NuGet 不指定版本時會把所有
   > enabled source 都打一輪查 latest，於是離線機就會丟出
   > `SSL connection could not be established` / `received an unexpected EOF`
   > 之類錯誤。專案層 `<clear />` 直接把所有繼承的 source 通通清空，最穩。
4. 把預設 `UnitTest1.cs` 內容換成：
   ```csharp
   using Microsoft.Playwright;
   using Microsoft.Playwright.NUnit;
   using NUnit.Framework;

   [Parallelizable(ParallelScope.Self)]
   public class HelloTests : PageTest
   {
       public override BrowserNewContextOptions ContextOptions() => new();

       [SetUpFixture]
       public class Setup
       {
           [OneTimeSetUp]
           public void Configure()
           {
               // 強制 Channel = msedge：覆寫 PageTest 預設的 Chromium download
               Environment.SetEnvironmentVariable("HEADED", "0");
           }
       }

       [Test]
       public async Task SystemEdge_LoadsEmbeddedPage()
       {
           // 直接呼叫 Playwright API，自訂 launch 參數
           using var pw = await Playwright.CreateAsync();
           await using var browser = await pw.Chromium.LaunchAsync(new()
           {
               Channel = "msedge",
               Headless = true,
           });
           var page = await browser.NewPageAsync();
           await page.GotoAsync("data:text/html,<h1 id='msg'>Hello, Edge!</h1>");
           Assert.That(await page.Locator("#msg").TextContentAsync(),
                       Is.EqualTo("Hello, Edge!"));
       }
   }
   ```
4. 開啟 `MyPwTests` 資料夾，VS Code 右側 **Test Explorer (Testing)** 面板會列出測試。
   按 ▶ 即可執行；或在終端機跑 `dotnet test`。

### 在 Visual Studio

1. 用 helper 先建專案再用 VS 開：
   ```powershell
   & "C:\ferry-playwright\new-playwright-project.ps1" -Name MyPwTests
   ```
   然後 VS：**File → Open → Project/Solution**，選 `MyPwTests\MyPwTests.csproj`。
   （這樣可以保證 project-local `NuGet.config` 已就位，VS 的 NuGet 還原也只會
   看到 ferry-playwright-feed。）
2. 如果你**從 VS New Project 對話框**建，記得：建完後**立刻**
   把 `C:\ferry-playwright\NuGet.config.template` 複製到專案根目錄
   改名 `NuGet.config`，再開始 Manage NuGet Packages，否則 VS 預設仍會嘗試
   `api.nuget.org`。
3. 把預設測試類別內容換成上面 VS Code 段落裡的 `HelloTests` 範例。
4. 開啟 **Test Explorer**（View → Test Explorer，或 `Ctrl+E, T`），按 **Run All** (`Ctrl+R, A`)。
5. 如果遇到「找不到瀏覽器」之類錯誤：請確認你**沒有**在專案任何地方呼叫
   `Microsoft.Playwright.Program.Main(new[] {"install"})`（那會嘗試下載 Chromium）。
   本機環境變數會擋掉下載，但要避免在 code 裡硬寫 `install`。

### 在 PowerShell（純命令列）

最快路徑是用 helper 跑 console 模板：

```powershell
& "C:\ferry-playwright\new-playwright-project.ps1" -Name MyPwScript -Template console
cd MyPwScript
# 把 Program.cs 換成下面內容，然後：
dotnet run
```

不用 helper 的話，記得先丟 NuGet.config 進去：

```powershell
mkdir MyPwScript; cd MyPwScript
Copy-Item "C:\ferry-playwright\NuGet.config.template" .\NuGet.config
dotnet new console
dotnet add package Microsoft.Playwright --version 1.60.0
```

最小 `Program.cs`：

```csharp
using Microsoft.Playwright;

using var pw = await Playwright.CreateAsync();
await using var browser = await pw.Chromium.LaunchAsync(new()
{
    Channel  = "msedge",
    Headless = true,
});
var page = await browser.NewPageAsync();
await page.GotoAsync("data:text/html,<h1 id='msg'>Hello from PowerShell!</h1>");

var text = await page.Locator("#msg").TextContentAsync();
Console.WriteLine($"result: {text}");
if (text != "Hello from PowerShell!") { Environment.Exit(1); }
```

執行時你應該會看到：

```
result: Hello from PowerShell!
```

> 想做成 self-contained `.exe`？參考本專案 packager 的做法：
> `dotnet publish -c Release -r win-x64 --self-contained true`，然後把
> `bin/Release/net*/win-x64/publish/.playwright/node/win32_x64/node.exe` 連同
> 整個 publish 資料夾搬到目標機。

> 想用 Playwright 官方的 NUnit / MSTest / xUnit fixture？可以，
> 但 fixture 預設會去呼叫 `playwright install`（下載 Chromium）。
> 解法：在 fixture 啟動前先 set `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`（已由我們的
> 安裝腳本機器層級設好），並覆寫 `BrowserNewContextOptions` 改用 `Channel = "msedge"`。

---

## 常見問題

**Q：跑 `dotnet new nunit` 或 `dotnet add package ...` 還是出現
`The SSL connection could not be established` / `received an unexpected EOF`？**
A：你的個人 NuGet 設定（`%AppData%\Roaming\NuGet\NuGet.Config`）或公司
group policy 帶進了**其他 remote NuGet source**（例如內部 Azure DevOps feed），
即便我們把 `nuget.org` 停用，dotnet 還是會把它們打一輪。
**解法**：直接用我們的 helper：
```powershell
& "C:\ferry-playwright\new-playwright-project.ps1" -Name MyTests
```
它會在新專案根目錄放一份 `NuGet.config`（`<clear />` + 只有 ferry-playwright-feed），
不管任何上層設定都會被蓋掉。或是手動把
`C:\ferry-playwright\NuGet.config.template` 複製到專案根目錄改名
`NuGet.config`，效果一樣。

**Q：第一次跑 sample 跳出 SmartScreen 警告？**
A：sample 跑起來會去 launch 系統 Edge；Edge 本身已經是受信任的 binary，多半不會觸發。
若是你自己 build 的 `.exe`（未經程式碼簽章），SmartScreen 首次執行會跳警告：
點「其他資訊」→「仍要執行」即可；企業環境請用 code-signing 憑證自行簽章。

**Q：怎麼確認真的沒上網？**
A：本專案的 GitHub Actions 在每次 release 前會把 Windows runner 的網路用
防火牆封鎖，然後跑一次完整安裝 + `dotnet build samples\hello-console`，並比對 TCP
連線快照確認沒有任何外連產生。詳見 [DEVELOPER.md](DEVELOPER.md#ci--release-workflow)。

**Q：我已經有 Playwright 自動化專案，可以換掉裡面的範例嗎？**
A：可以。見 [DEVELOPER.md → 客製化](DEVELOPER.md#客製化換成自己的應用)。

**Q：可以用這份安裝來「寫」新的測試嗎？**
A：可以。要寫新測試請先安裝 .NET 10 SDK（[官網下載](https://dotnet.microsoft.com/download)）；
   ZIP 內的 dev pack（雙擊 `點擊兩下-完整安裝(推薦).cmd`，或單獨執行
   `setup-devpack.ps1`）會把 .nupkg 放進機器層離線 NuGet feed，
   解決 NuGet 套件下載問題。詳細步驟見上面
「[想在這台機器寫自己的 Playwright 測試？](#想在這台機器寫自己的-playwright-測試)」章節。
我們安裝時設好的環境變數會自動套用到所有新專案，所以只要 launch 時用
`Channel = "msedge"` 就能離線跑。

**Q：ZIP 解壓後裡面有什麼？**
A：v0.6 起 ZIP 內容是純粹的「dev pack + sample 原始碼」，沒有預編譯 runtime：

- `nuget/` — 離線 NuGet feed（~30 個 .nupkg，含 Microsoft.Playwright 1.60.0、
  Microsoft.Playwright.NUnit/.MSTest、Microsoft.NET.Test.Sdk、NUnit、MSTest、
  以及它們的傳遞性相依），雙擊安裝會放進 `%USERPROFILE%\.nuget\packages` 並
  在 `%ProgramData%\NuGet\NuGet.Config` 註冊 `ferry-playwright-feed` source。
- `samples/{hello-nunit, hello-mstest, hello-console}/` — 三個可立即 build/test
  的範例專案（NUnit + Playwright fixture、MSTest + Playwright fixture、
  純 console 應用），各自含 `NuGet.config` 走 ferry-playwright-feed。
- 雙擊入口腳本：`點擊兩下-完整安裝(推薦).cmd` / `點擊兩下-解除安裝.cmd`。
- 進階 ps1：`setup.ps1` / `setup-devpack.ps1` / `uninstall.ps1` /
  `uninstall-devpack.ps1`。
- Helper：`new-playwright-project.ps1` + `NuGet.config.template`。
- 紀錄檔：`README.txt` / `VERSION.txt` / `BUILD-INFO.txt`。

---

## 授權

MIT。詳見 [LICENSE](LICENSE)（若尚未加入請聯絡維護者）。

## 版本紀錄

見 [CHANGELOG.md](CHANGELOG.md)。
