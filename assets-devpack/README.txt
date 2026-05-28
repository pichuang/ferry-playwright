Playwright Offline Dev Pack (離線開發套件)
============================================

這個壓縮包是 **runtime ZIP 的姊妹品**。

* runtime ZIP（PlaywrightOffline-*.zip）：給「只要執行」的目標機器。
* 本 dev pack（PlaywrightDevPack-*.zip）：給「想離線寫測試 / 寫程式」的開發機器。

兩個 ZIP 可單獨使用、也可共存。本 dev pack 不需要先裝 runtime ZIP。


內容物
------
* nuget\                       一組離線 NuGet 套件（.nupkg）
    - microsoft.playwright.*.nupkg
    - microsoft.playwright.nunit.*.nupkg
    - microsoft.playwright.mstest.*.nupkg
    - microsoft.net.test.sdk.*.nupkg
    - nunit.*.nupkg + nunit3testadapter.*.nupkg
    - mstest.*.nupkg
    - 以及所有相依套件
* nuget\INDEX.txt              本次 dev pack 含的所有 .nupkg 檔名清單
* 點擊兩下-setup-devpack.cmd   雙擊安裝
* 點擊兩下-uninstall-devpack.cmd 雙擊解除
* setup-devpack.ps1            安裝腳本（PowerShell）
* uninstall-devpack.ps1        解除腳本（PowerShell）
* BUILD-INFO.txt               本次打包資訊


怎麼用
------

1. 把整個資料夾解壓到任何位置（路徑可以含中文）。
2. 在解壓出來的資料夾內 **雙擊** `點擊兩下-setup-devpack.cmd`。
3. 點 [是] 同意 UAC 權限提升。
4. 看到 "Dev pack installed" 即完成。

之後在這台機器上的 **任何專案**：

    mkdir hello-playwright
    cd hello-playwright
    dotnet new nunit
    dotnet add package Microsoft.Playwright.NUnit
    dotnet test

不需要網路也能跑。


做了什麼
--------

setup-devpack.ps1 會把以下三件事做完：

1. **複製 .nupkg 到 Microsoft 慣用的全機器離線 feed 資料夾**：
       %ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages
   這是 Visual Studio Installer 寫 Offline Packages 的同一個位置；
   裝有 Visual Studio 的機器原本就會自動把這個資料夾當作來源使用。

2. **在機器層 NuGet.Config 註冊一條來源**：
       %ProgramData%\NuGet\NuGet.Config
   key = "PlaywrightOfflineFeed"
   value = 上面的資料夾路徑
   讓純 .NET SDK / VS Code 場景也找得到這個來源。
   既有的 NuGet.Config 會先備份為 NuGet.Config.bak.YYYYMMDD-HHMMSS。
   **預設不停用 nuget.org**；機器之後若連得到網路也能繼續用，
   若想強制離線可加 -DisableNuGetOrg 旗標。

3. **設定機器層環境變數**（與 runtime ZIP 同）：
       PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = 1
       PLAYWRIGHT_BROWSERS_PATH         = 0
   確保 Playwright 不會嘗試下載 Chromium，並要求測試用 Channel="msedge"
   走系統 Edge。


寫測試時請注意
--------------

* Launch 瀏覽器時務必指定 `Channel = "msedge"`，例如：

      using var pw = await Playwright.CreateAsync();
      await using var browser = await pw.Chromium.LaunchAsync(new()
      {
          Channel = "msedge",
          Headless = true,
      });

* 不要呼叫 `playwright install` —— 本 dev pack 不含 Chromium 二進位，
  系統 Edge 已經夠用。

* 仍需安裝 **.NET 10 SDK**（不是 runtime）：本 ZIP 只含 NuGet 套件，
  不含 SDK。SDK 安裝檔可從另一台有網路的電腦下載後拷貝過來。


解除安裝
--------

雙擊 `點擊兩下-uninstall-devpack.cmd`，會：

* 從 NuGet.Config 移除 `PlaywrightOfflineFeed` 來源項目
* 刪除我們複製到 feed 資料夾的那些 .nupkg（依 INDEX.txt 清單，
  不會誤刪其他 Microsoft 既有的 offline 套件）

**刻意不做的事情**：
* 不清 %USERPROFILE%\.nuget\packages（其他專案可能正在用已 restore 的版本）
* 不清環境變數（runtime ZIP 可能還在用，雙方共用）


疑難排解
--------

* Q：執行 setup-devpack.cmd 沒有跳 UAC？
  A：直接右鍵 → 以系統管理員身分執行 PowerShell，再執行
     `powershell -ExecutionPolicy Bypass -File setup-devpack.ps1`。

* Q：`dotnet add package Microsoft.Playwright` 還是說連不到 nuget.org？
  A：表示 NuGet 還是先去打 nuget.org。重新開一個新的 cmd / PowerShell
     視窗讓環境變數重整；或在專案目錄 `dotnet restore --no-cache --source
     "PlaywrightOfflineFeed"` 強制只用本地來源。

* Q：能否在用 Visual Studio 開新專案時直接看到這些套件？
  A：可以。Visual Studio 安裝後預設就把
     %ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages 視為來源，
     所以在 [管理 NuGet 套件] → 來源選 "Microsoft Visual Studio Offline
     Packages" 即可看到 Microsoft.Playwright 等套件。

* Q：要重新安裝 / 升級到新版怎麼辦？
  A：直接再執行一次 setup-devpack.cmd 即可（idempotent，會覆蓋舊版）。
