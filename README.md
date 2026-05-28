# ferry-playwright

> 一鍵把 Playwright for .NET 應用打包為**完全離線**的 Windows 安裝包。
> 在 **Windows 11 / Windows Server 2022** 上不需要任何網路，
> 就能用系統內建的 **Microsoft Edge** 跑 Playwright 自動化。

---

## 版本資訊

| 項目 | 版本 |
| --- | --- |
| ferry-playwright | **v0.4.0**（最新 release；可能含尚未發布的變更，見 [CHANGELOG.md](CHANGELOG.md)） |
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

把產生的 ZIP 用 USB 拷貝過去 → 解壓 → 右鍵 install.ps1 → 結束。不需要 internet、不需要 .NET SDK、不需要安裝 Edge（系統已內建）。

---

## 系統需求（目標機）

| 項目 | 需求 |
| --- | --- |
| 作業系統 | Windows 11 / Windows Server 2022 或更新 |
| 瀏覽器 | Microsoft Edge（兩種系統都預載） |
| 權限 | 安裝時需要本機 Administrator |
| 網路 | **不需要** |
| .NET | **不需要**（已嵌在安裝包） |

---

## 給「拿到 ZIP」的人：怎麼安裝

> 從 v0.4.0（即將發布）起，**每個 release 會附兩個 ZIP**：
> - `PlaywrightOffline-win-x64-*.zip`（**runtime**）— 給「只要執行」的目標機器，**必裝**。
> - `PlaywrightDevPack-win-x64-*.zip`（**dev pack**）— 給「想離線寫測試」的開發機器，**選裝**。
>
> 兩者完全獨立，可單獨使用、也可共存。先裝哪個都行。

### 安裝 runtime ZIP（目標機）

1. 把 `PlaywrightOffline-win-x64-YYYYMMDD-HHMMSS.zip` 拷到目標機，解壓縮。
2. 進入解壓後的資料夾，**雙擊** `點擊兩下-install.cmd`。
3. 接受 UAC 提權對話框。
4. 等畫面跳出「Installation complete」即完成。

> 進階：也可以「右鍵 `install.ps1` → 以 PowerShell 執行」傳入額外參數
> （例如 `-SkipEdgeCheck`、`-NoShortcuts`、`-InstallDir "D:\Apps\Playwright"`）。

安裝腳本會自動：

- 確認 Windows 版本與 Microsoft Edge 是否存在。
- 把應用程式複製到 `C:\Program Files\PlaywrightApp\`。
- 設定 Playwright 不要嘗試下載瀏覽器（機器層級環境變數）。
- 建立開始功能表與桌面捷徑。

### 安裝完怎麼執行

打開**新的** PowerShell / Command Prompt（要重新讀環境變數），執行：

```powershell
& "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe"
```

或直接點桌面 / 開始功能表的「PlaywrightApp」捷徑。

執行後 Edge 會彈出一個 **「Hello, Playwright!」** 內嵌頁面，
終端會印出三項斷言並以 `RESULT: PASS` 結尾 — 看到 PASS 就代表離線環境完全可用。
按 Enter 即可關閉瀏覽器。

> 想自己指定網址？在後面加 URL：
> `& "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" https://example.com`

> 純自我測試 (Headless、不等 Enter、直接 PASS/FAIL 退出)：
> `& "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" --ci`

### 解除安裝

在同一個解壓資料夾，**雙擊** `點擊兩下-uninstall.cmd`（或右鍵 `uninstall.ps1` → 以 PowerShell 執行）。
腳本會移除程式檔案、清掉環境變數、刪除捷徑。

### 安裝 dev pack ZIP（開發機，選裝）

只有當你要在這台機器**寫**新的 Playwright 測試時才需要。

1. 把 `PlaywrightDevPack-win-x64-YYYYMMDD-HHMMSS.zip` 解壓縮。
2. **雙擊** `點擊兩下-setup-devpack.cmd`，接受 UAC。
3. 看到 "Dev pack installed" 即完成。
4. 之後任何專案 `dotnet new nunit && dotnet add package Microsoft.Playwright.NUnit`
   都可以離線完成。詳見下方
   「[想在這台機器寫自己的 Playwright 測試？](#想在這台機器寫自己的-playwright-測試)」章節。

解除安裝：雙擊 `點擊兩下-uninstall-devpack.cmd`。

---

## 給「想自己產生 ZIP」的人

只要一台**有網路**、安裝了 .NET 10 SDK 的開發機（macOS / Linux / Windows 都行）：

```bash
git clone https://github.com/pichuang/ferry-playwright.git
cd ferry-playwright
dotnet run --project src/PlaywrightOfflinePackager
```

ZIP 會出現在 `output/PlaywrightOffline-win-x64-*.zip`，把它拷給目標機就好。

想同時產出 dev pack ZIP（給離線開發機 `dotnet add package` 用）：

```bash
dotnet run --project src/PlaywrightOfflinePackager -- --devpack
# → 多一個 output/PlaywrightDevPack-win-x64-*.zip
```

> 進一步的打包選項、自訂應用、CI 自動發布、架構說明，請參考 **[DEVELOPER.md](DEVELOPER.md)**。

---

## 想在這台機器寫自己的 Playwright 測試？

這份 ZIP 提供的是「跑得起來」的最小環境。如果你想在同一台機器上
**自己寫新的 Playwright 測試案例**，下面說明怎麼用 VS Code / Visual Studio / PowerShell 上手。

### 前置作業（一次性）

1. **安裝 .NET 10 SDK**（這份 ZIP 只內含執行用 runtime，沒有 SDK）。
   - 官方下載：<https://dotnet.microsoft.com/download>
   - 若這台機器**完全沒有網路**，請從另一台有網路的機器下載 SDK 安裝檔，
     再 sneakernet 過來；或在貴公司內部 NuGet/檔案伺服器準備離線安裝檔。
2. **離線解決 NuGet 套件**：在離線機器執行
   `dotnet add package Microsoft.Playwright` 預設會打 `api.nuget.org` 而失敗。
   有兩種解法：

   - **（推薦）裝我們的 Dev Pack ZIP** — 同一個 release 附上的
     `PlaywrightDevPack-win-x64-*.zip`。解壓後雙擊
     `點擊兩下-setup-devpack.cmd`，會把 `Microsoft.Playwright`、
     `Microsoft.Playwright.NUnit`、`Microsoft.NET.Test.Sdk`、NUnit、MSTest
     等 .nupkg **複製到 Microsoft 既有的全機器離線 feed 資料夾**
     (`%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages`)，並在
     `%ProgramData%\NuGet\NuGet.Config` 註冊一條 source。之後任何新專案
     `dotnet add package Microsoft.Playwright` 都跟有 nuget.org 一樣會成功。
   - 或自行帶整個 `~/.nuget/packages` 過來，或自建內網 NuGet 私服。
3. **確認環境變數已套用**（runtime ZIP 或 Dev Pack 任一個安裝都會設好）：
   ```powershell
   [Environment]::GetEnvironmentVariable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD','Machine')  # → 1
   [Environment]::GetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH','Machine')         # → 0
   ```
   有了這兩個，新專案執行時就**不會**嘗試下載 Chromium，會走系統 Edge。

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
2. 建立 NUnit 測試專案：
   ```powershell
   mkdir MyPwTests; cd MyPwTests
   dotnet new nunit
   dotnet add package Microsoft.Playwright.NUnit
   ```
3. 把預設 `UnitTest1.cs` 內容換成：
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

1. **File → New → Project** 選擇 **NUnit Test Project (.NET)**。
2. 在 Solution Explorer 對專案右鍵 → **Manage NuGet Packages**，搜尋並安裝
   `Microsoft.Playwright.NUnit`（會自動帶入 `Microsoft.Playwright`）。
3. 同樣把預設測試類別內容換成上面 VS Code 段落裡的 `HelloTests` 範例。
4. 開啟 **Test Explorer**（View → Test Explorer，或 `Ctrl+E, T`），按 **Run All** (`Ctrl+R, A`)。
5. 如果遇到「找不到瀏覽器」之類錯誤：請確認你**沒有**在專案任何地方呼叫
   `Microsoft.Playwright.Program.Main(new[] {"install"})`（那會嘗試下載 Chromium）。
   本機環境變數會擋掉下載，但要避免在 code 裡硬寫 `install`。

### 在 PowerShell（純命令列）

若不需要 IDE，最快的方式是直接 console app：

```powershell
mkdir MyPwScript; cd MyPwScript
dotnet new console
dotnet add package Microsoft.Playwright

# 用記事本或 vim 把 Program.cs 換成下面內容，然後：
dotnet run
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

**Q：安裝時跳出「Microsoft Edge was not detected」怎麼辦？**
A：Windows 11 / Server 2022 預設都有 Edge；若被特殊映像移除，可重新安裝 Edge，
或在很確定 Edge 存在時用 `install.ps1 -SkipEdgeCheck` 略過檢查。

**Q：第一次執行 .exe 跳出 SmartScreen 警告？**
A：這個範例 binary 沒有經過程式碼簽章。點「其他資訊」→「仍要執行」即可；
若是企業環境，請用你們的 code-signing 憑證對 ZIP 內的 .exe 簽章後再分發。

**Q：怎麼確認真的沒上網？**
A：本專案的 GitHub Actions 在每次 release 前會把 Windows runner 的網路用
防火牆封鎖，然後跑一次完整安裝 + 啟動，並比對 TCP 連線快照確認沒有任何
外連產生。詳見 [DEVELOPER.md](DEVELOPER.md#ci--release-workflow)。

**Q：我已經有 Playwright 自動化專案，可以換掉裡面的範例嗎？**
A：可以。見 [DEVELOPER.md → 客製化](DEVELOPER.md#客製化換成自己的應用)。

**Q：可以用這份安裝來「寫」新的測試嗎？**
A：可以。要寫新測試請先安裝 .NET 10 SDK（[官網下載](https://dotnet.microsoft.com/download)）；
   若機器完全離線，再安裝同 release 的 `PlaywrightDevPack-win-x64-*.zip`
   解決 NuGet 套件下載問題。詳細步驟見上面
「[想在這台機器寫自己的 Playwright 測試？](#想在這台機器寫自己的-playwright-測試)」章節。
我們安裝時設好的環境變數會自動套用到所有新專案，所以只要 launch 時用
`Channel = "msedge"` 就能離線跑。

**Q：Dev Pack ZIP 跟 runtime ZIP 有什麼不同？**
A：runtime ZIP（`PlaywrightOffline-*.zip`）是給「只要執行」的目標機；
Dev Pack ZIP（`PlaywrightDevPack-*.zip`）是給「想寫新測試」的開發機，
裡面是一組 .nupkg 加上 `setup-devpack.ps1`，安裝後會把 Microsoft.Playwright
等套件放進 Microsoft 既有的全機器離線 NuGet feed
(`%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages`) 並註冊機器層 NuGet source。
之後任何專案 `dotnet add package Microsoft.Playwright` 都不需要網路。兩個 ZIP
可以單獨使用，也可以共存。

---

## 授權

MIT。詳見 [LICENSE](LICENSE)（若尚未加入請聯絡維護者）。

## 版本紀錄

見 [CHANGELOG.md](CHANGELOG.md)。
