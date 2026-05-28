Playwright 離線安裝包 — 使用說明
================================

這份壓縮檔解開後就可以在 **完全沒有網路** 的 Windows 機器上：

  (1) 安裝一個離線 NuGet feed（dev pack），讓本機 `dotnet add package
      Microsoft.Playwright` / `Microsoft.Playwright.NUnit` 等指令完全離線運作。
  (2) 拿到三個現成的 sample 原始碼專案，直接 `dotnet build` / `dotnet test`
      就能跑起來，作為你寫離線 Playwright 測試的起點範本。

>> 從 v0.6.0 起 ZIP **不再附** 預先編譯好的 PlaywrightSampleApp.exe，
   也不再建立 Start Menu / 桌面捷徑；改成提供你看得到、改得動的原始碼。


資料夾內容
----------
  nuget\                        離線 NuGet 套件（.nupkg） + INDEX.txt
                                含 Microsoft.Playwright(.NUnit/.MSTest)、
                                Microsoft.NET.Test.Sdk、NUnit、MSTest、
                                coverlet.collector、NUnit.Analyzers、
                                MSTest.Analyzers 與所有相依套件

  samples\hello-nunit\          NUnit  + Microsoft.Playwright.NUnit 範本
  samples\hello-mstest\         MSTest + Microsoft.Playwright.MSTest 範本
  samples\hello-console\        最小 Console App（互動或 --ci 自我測試）

  點擊兩下-完整安裝(推薦).cmd            **雙擊就會安裝 dev pack**
  setup.ps1                     PowerShell 入口腳本（被上面那支 .cmd 呼叫）
  setup-devpack.ps1             dev pack 核心安裝腳本（被 setup.ps1 呼叫）

  點擊兩下-解除安裝.cmd        **雙擊就會解除 dev pack**
  uninstall.ps1                 PowerShell 入口解除腳本
  uninstall-devpack.ps1         dev pack 核心解除腳本

  new-playwright-project.ps1    新建離線專案 helper（v0.5.2 起；強烈推薦）
  NuGet.config.template         專案層 NuGet 設定範本（手動 fallback 用）

  BUILD-INFO.txt                建置時間與設定資訊
  VERSION.txt                   ferry-playwright 版本字串
  README.txt                    本檔


系統需求
--------
  * Windows 11，或 Windows Server 2022（含以上版本）
  * 已安裝 Microsoft Edge（Windows 11 / Server 2022 預設都有）
  * 已安裝 .NET 10 SDK（本 ZIP 不含；samples 與 dev pack 都需要）
  * 系統管理員帳號（會彈 UAC 提權）
  * **不需要網際網路連線**


如何安裝（一鍵）
----------------
  1. 在解壓出來的資料夾中，**雙擊「點擊兩下-完整安裝(推薦).cmd」**。
  2. UAC 提權視窗出現時按「是」。
  3. 腳本會：
        - 把所有 .nupkg 複製到 Microsoft 標準離線 feed 資料夾
          (%ProgramFiles(x86)%\Microsoft SDKs\NuGetPackages)
        - 在機器層 NuGet.Config 加一條 PlaywrightOfflineFeed 來源
          （備份既有檔案為 .bak.YYYYMMDD-HHMMSS），預設停用 nuget.org
        - 設機器層環境變數
              PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
              PLAYWRIGHT_BROWSERS_PATH=0
          讓 Playwright 永遠不嘗試下載 Chromium / Firefox。
        - 若偵測到 v0.5.x 留下的 C:\Program Files\PlaywrightApp\，順手清掉
          （含環境變數、Start Menu / 桌面捷徑）。


如何驗證（跑 sample）
---------------------
  安裝完成後，**開一個全新的** PowerShell（要讀到新的環境變數）：

      Copy-Item -Recurse .\samples\hello-console C:\Work\
      cd C:\Work\hello-console
      dotnet run -- --ci

  預期結果：
    - 終端會印出三條 [OK] 斷言
    - 最後一行顯示：

          RESULT: PASS

    - exit code = 0

  NUnit / MSTest 範本：

      Copy-Item -Recurse .\samples\hello-nunit C:\Work\
      cd C:\Work\hello-nunit
      dotnet test --settings .runsettings


如何用 dev pack 寫自己的測試
----------------------------
  方法 A — 直接 copy sample 改：

      Copy-Item -Recurse .\samples\hello-nunit C:\Work\MyTests
      cd C:\Work\MyTests
      # 編輯 HelloPlaywrightTests.cs，然後：
      dotnet test --settings .runsettings

  方法 B — 用 helper 從空專案開始：

      & ".\new-playwright-project.ps1" -Name MyTests -Template nunit
      cd MyTests
      dotnet test --settings .runsettings

  寫測試時務必：
    * Launch 瀏覽器時指定 Channel = "msedge"
    * 不要呼叫 `playwright install` —— 本 dev pack 不含 Chromium 二進位
    * NUnit / MSTest 專案直接用 `.runsettings`（已包含 msedge + headless 設定）


如何解除安裝
------------
  在原解壓資料夾，**雙擊「點擊兩下-解除安裝.cmd」**，會：

    - 從機器層 NuGet.Config 移除 PlaywrightOfflineFeed 來源
    - 依 INDEX.txt 清單刪掉我們塞進去的 .nupkg（不會誤刪其他 Microsoft
      既有的 offline 套件）
    - **不**清 %USERPROFILE%\.nuget\packages（其他專案可能仍在用）
    - 清環境變數 PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD / PLAYWRIGHT_BROWSERS_PATH
    - 順手清掉 v0.5.x 留下的 C:\Program Files\PlaywrightApp 與其捷徑


疑難排解
--------
  * 右鍵執行 .ps1 跳「Execution policy」錯誤
        - 改用系統管理員身份開 PowerShell，執行：
              powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1

  * `dotnet add package <id>` 出現「The SSL connection could not be established」
    或「received an unexpected EOF」
        - 你的個人 NuGet.Config (`%AppData%\Roaming\NuGet\NuGet.Config`) 或
          公司 group policy 加進了**其他 remote NuGet source**（例如內部
          Azure DevOps feed），dotnet 還是會把它們打一輪。
        - 用我們的 helper 建專案最穩：
              & ".\new-playwright-project.ps1" -Name MyTests
          它會在新專案根目錄寫一份 NuGet.config，含 <clear /> 把所有繼承的
          source 都清掉，只留 PlaywrightOfflineFeed。
        - 已經建好的專案要修：複製本 ZIP 內 NuGet.config.template
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

  - 讀取上次留下的 sentinel（PlaywrightOfflineFeed.INDEX.txt），
    只刪掉「同 package id 但不同版本」的舊 .nupkg；其他 Microsoft offline
    套件一律不動。
  - 若偵測到舊版 v0.5.x 的 C:\Program Files\PlaywrightApp\，會一併清掉。
