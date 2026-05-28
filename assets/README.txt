Playwright 離線安裝包 — 使用說明
================================

這份壓縮檔解開後就可以在 **完全沒有網路** 的 Windows 機器上完成：

  (A) 安裝一個以 Playwright + 系統 Microsoft Edge 驅動的範例自動化程式（runtime）
  (B) 設定一個離線 NuGet feed，讓你自己的新專案也能 `dotnet add package
      Microsoft.Playwright` 而不需要連網（dev pack）

兩者一鍵裝完，也可以單獨裝其中一邊。


資料夾內容
----------
  app\                          (A) 自包含的 .NET 應用程式 + Playwright 驅動
  nuget\                        (B) 一組離線 NuGet 套件（.nupkg）+ INDEX.txt
                                    含 Microsoft.Playwright(.NUnit/.MSTest)、
                                    Microsoft.NET.Test.Sdk、NUnit、MSTest、
                                    coverlet.collector、NUnit.Analyzers、
                                    MSTest.Analyzers 與所有相依套件

  點擊兩下-完整安裝(推薦).cmd            **雙擊就會同時安裝 A + B**（推薦給一般使用者）
  setup.ps1                     PowerShell 總入口腳本（被上面那支 .cmd 呼叫）

  點擊兩下-僅安裝Runtime.cmd          雙擊只裝 A（runtime）
  install.ps1                   只裝 A 的 PowerShell 腳本
  setup-devpack.ps1             只裝 B 的 PowerShell 腳本（dev pack）

  點擊兩下-解除安裝.cmd        **雙擊就會同時解除 A + B**
  uninstall.ps1                 PowerShell 總入口解除腳本
  uninstall-runtime.ps1         只解除 A 的腳本
  uninstall-devpack.ps1         只解除 B 的腳本

  new-playwright-project.ps1    新建離線專案 helper（v0.5.2 新增；強烈推薦）
  NuGet.config.template         專案層 NuGet 設定範本（手動 fallback 用）

  BUILD-INFO.txt                建置時間與設定資訊
  README.txt                    本檔


系統需求
--------
  * Windows 11，或 Windows Server 2022（含以上版本）
  * 已安裝 Microsoft Edge（Windows 11 / Server 2022 預設都有）
  * 系統管理員帳號（會彈 UAC 提權）
  * 想用 dev pack 寫測試的話，還需要另外裝 **.NET 10 SDK**（本 ZIP 不含）
  * **不需要網際網路連線**


如何安裝（一鍵）
----------------
  1. 在解壓出來的資料夾中，**雙擊「點擊兩下-完整安裝(推薦).cmd」**。
  2. UAC 提權視窗出現時按「是」。
  3. 腳本會依序：
        [1/2] 安裝 runtime：
              - 確認 Windows 版本與 Microsoft Edge 是否存在
              - 把應用程式複製到「C:\Program Files\PlaywrightApp」
              - 設定環境變數，讓 Playwright 永遠不嘗試下載瀏覽器
              - 建立開始功能表與桌面捷徑
        [2/2] 安裝 dev pack：
              - 把所有 .nupkg 複製到 Microsoft 標準離線 feed 資料夾
                (%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages)
              - 在機器層 NuGet.Config 加一條 PlaywrightOfflineFeed 來源
                （備份既有檔案為 .bak.YYYYMMDD-HHMMSS）


如何安裝（只裝其中一邊）
------------------------
  * 只裝 runtime：雙擊「點擊兩下-僅安裝Runtime.cmd」
  * 只裝 dev pack：以系統管理員身分開 PowerShell，執行：
        powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-devpack.ps1


如何驗證 runtime
----------------
  安裝完成後，**開一個全新的** PowerShell 或命令提示字元（要讀到新的環境變數），
  輸入：

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe"

  預期結果：
    - Microsoft Edge 會彈出一個內嵌的「Hello, Playwright!」頁面（不需要網路）
    - 終端機會印出三條 [OK] 斷言
    - 最後一行顯示：

          RESULT: PASS

  也可以直接點桌面或開始功能表的「PlaywrightApp」捷徑。

  想要全自動的 self-test（headless、不需要按 Enter，exit code 0=PASS / 1=FAIL）：

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" --ci


如何驗證 dev pack
-----------------
  安裝完成後，**開一個全新的** PowerShell，用我們的 helper 一行建立離線專案：

      & "$Env:ProgramFiles\PlaywrightApp\new-playwright-project.ps1" -Name hello-pw

  這支 helper 會：
    1) 建立資料夾 hello-pw
    2) 寫一份「專案層 NuGet.config」（含 <clear /> 只留 PlaywrightOfflineFeed）
    3) 跑 dotnet new nunit --no-restore
    4) 用**鎖定的**版本（Playwright 1.60.0、NUnit 4.2.2 等）跑 dotnet add package
    5) 最後 dotnet restore，整個過程完全離線

  如果整個跑完最後印出「Project created and restored 100% offline.」就成功。

  寫測試時記得：

  * Launch 瀏覽器時務必指定 `Channel = "msedge"`：

        using var pw = await Playwright.CreateAsync();
        await using var browser = await pw.Chromium.LaunchAsync(new()
        {
            Channel = "msedge",
            Headless = true,
        });

  * 不要呼叫 `playwright install` —— 本 dev pack 不含 Chromium 二進位。

  Helper 也支援 -Template mstest 與 -Template console：

      & "$Env:ProgramFiles\PlaywrightApp\new-playwright-project.ps1" -Name MyMstest -Template mstest
      & "$Env:ProgramFiles\PlaywrightApp\new-playwright-project.ps1" -Name MyScript -Template console


如何解除安裝
------------
  在原解壓資料夾，**雙擊「點擊兩下-解除安裝.cmd」**，會：

  [1/2] 移除 dev pack：
        - 從機器層 NuGet.Config 移除 PlaywrightOfflineFeed 來源
        - 依 INDEX.txt 清單刪掉我們塞進去的 .nupkg（不會誤刪其他 Microsoft
          既有的 offline 套件）
        - **不**清 %USERPROFILE%\.nuget\packages（其他專案可能仍在用）
        - **不**清環境變數（runtime 還會用到）
  [2/2] 移除 runtime：
        - 砍 C:\Program Files\PlaywrightApp
        - 清環境變數 PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD / PLAYWRIGHT_BROWSERS_PATH
        - 砍開始功能表與桌面捷徑


疑難排解
--------
  * 「Microsoft Edge was not detected」
        - 請確認 Edge 是否真的有安裝，路徑通常為：
              C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
        - 若確定 Edge 存在但仍報錯，可加參數略過檢查：
              .\setup.ps1 -SkipEdgeCheck

  * 右鍵執行 .ps1 跳「Execution policy」錯誤
        - 改用系統管理員身份開 PowerShell，執行：
              powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1

  * 雙擊 .exe 跳出 SmartScreen 警告
        - 本範例 binary 未經程式碼簽章。點「其他資訊」→「仍要執行」即可，
          或請貴公司用自有的程式碼簽章憑證簽過再分發。

  * `dotnet add package <id>` 出現「The SSL connection could not be established」
    或「received an unexpected EOF」
        - 你的個人 NuGet.Config (`%AppData%\Roaming\NuGet\NuGet.Config`) 或
          公司 group policy 加進了**其他 remote NuGet source**（例如內部
          Azure DevOps feed），dotnet 還是會把它們打一輪。
        - 用我們的 helper 建專案最穩：
              & "$Env:ProgramFiles\PlaywrightApp\new-playwright-project.ps1" -Name MyTests
          它會在新專案根目錄寫一份 NuGet.config，含 <clear /> 把所有繼承的
          source 都清掉，只留 PlaywrightOfflineFeed。
        - 已經建好的專案要修：複製
              %ProgramFiles%\PlaywrightApp\NuGet.config.template
          到專案根目錄改名 NuGet.config，再 dotnet restore 即可。

  * `dotnet add package Microsoft.Playwright` 還是說連不到 nuget.org
        - v0.5.1 起 setup-devpack.ps1 預設已停用 nuget.org，不應再看到此錯誤。
          如果仍看到：請重開一個新的 PowerShell 視窗讓環境變數重新讀入。
        - 若你**刻意**想保留 nuget.org（這台機器偶爾有網路），重跑：
              powershell -ExecutionPolicy Bypass -File .\setup.ps1 -KeepNuGetOrg
          之後就會回到離線 feed + nuget.org 混合模式。

  * 想在 Visual Studio 看到這些套件
        - VS 預設就把 %ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages 視為
          來源，[管理 NuGet 套件] → 來源選 "Microsoft Visual Studio Offline
          Packages" 即可。


重新安裝 / 升級
---------------
  直接再執行一次「點擊兩下-完整安裝(推薦).cmd」即可，**不需要**先解除安裝。

  - 安裝畫面會顯示「Upgrading PlaywrightApp: vOLD -> vNEW」之類訊息，
    來源是 C:\Program Files\PlaywrightApp\VERSION.txt 與 ZIP 內 VERSION.txt 的比對。
  - runtime：停掉執行中的 PlaywrightSampleApp.exe → 清空安裝資料夾 → 拷新檔。
  - dev pack：讀取上次留下的 sentinel（PlaywrightOfflineFeed.INDEX.txt），
    只刪掉「同 package id 但不同版本」的舊 .nupkg；其他 Microsoft offline
    套件一律不動。
  - 降版（vNEW 較舊）會印警告但仍會繼續，方便你用任一版本當 hotfix。
