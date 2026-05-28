Playwright 離線安裝包 — 使用說明
================================

這份壓縮檔解開後就可以在 **完全沒有網路** 的 Windows 機器上安裝並執行一個
以 Playwright + 系統 Microsoft Edge 驅動的範例自動化程式。


資料夾內容
----------
  app\                          自包含的 .NET 應用程式 + Playwright 驅動
  點擊兩下-install.cmd           **雙擊就會開始安裝**（推薦給一般使用者）
  install.ps1                   PowerShell 安裝腳本（被上面那支 .cmd 呼叫）
  點擊兩下-uninstall.cmd         **雙擊就會開始解除安裝**
  uninstall.ps1                 PowerShell 解除安裝腳本
  BUILD-INFO.txt                建置時間與設定資訊
  README.txt                    本檔


系統需求
--------
  * Windows 11，或 Windows Server 2022（含以上版本）
  * 已安裝 Microsoft Edge（Windows 11 / Server 2022 預設都有）
  * 系統管理員帳號（會彈 UAC 提權）
  * **不需要網際網路連線**


如何安裝
--------
  1. 在解壓出來的資料夾中，**雙擊「點擊兩下-install.cmd」**。
     （進階使用者：可改成「右鍵 install.ps1 → 以 PowerShell 執行」，
      或在系統管理員 PowerShell 中執行：
          powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1）
  2. UAC 提權視窗出現時按「是」。
  3. 安裝腳本會自動：
        - 確認 Windows 版本與 Microsoft Edge 是否存在
        - 把應用程式複製到「C:\Program Files\PlaywrightApp」
        - 設定環境變數，讓 Playwright 永遠不嘗試下載瀏覽器
        - 建立開始功能表與桌面捷徑


如何執行（驗證安裝是否成功）
---------------------------
  安裝完成後，**開一個全新的** PowerShell 或命令提示字元（要讀到新的環境變數），
  輸入：

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe"

  預期結果：
    - Microsoft Edge 會彈出一個內嵌的「Hello, Playwright!」頁面（不需要網路）
    - 終端機會印出三條 [OK] 斷言
    - 最後一行顯示：

          RESULT: PASS

  看到 PASS 就代表這台離線機器上 Playwright 完全可用。按 Enter 即可關閉瀏覽器。

  也可以直接點桌面或開始功能表的「PlaywrightApp」捷徑。

  想瀏覽特定網址（不跑斷言，只顯示 title）：

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" https://example.com

  想要全自動的 self-test（headless、不需要按 Enter，exit code 0=PASS / 1=FAIL）：

      & "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" --ci


如何解除安裝
------------
  在原解壓資料夾，**雙擊「點擊兩下-uninstall.cmd」**
  （或改用：右鍵 uninstall.ps1 → 以 PowerShell 執行）。
  腳本會移除程式檔案、清掉環境變數、刪除桌面與開始功能表捷徑。


疑難排解
--------
  * 「Microsoft Edge was not detected」
        - 請確認 Edge 是否真的有安裝，路徑通常為：
              C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
        - 若確定 Edge 存在但仍報錯，可加參數略過檢查：
              （右鍵 install.ps1 → 以 PowerShell 執行 → 加上 -SkipEdgeCheck）

  * 右鍵執行 .ps1 跳「Execution policy」錯誤
        - 改用系統管理員身份開 PowerShell，執行：
              powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

  * 雙擊 .exe 跳出 SmartScreen 警告
        - 本範例 binary 未經程式碼簽章。點「其他資訊」→「仍要執行」即可，
          或請貴公司用自有的程式碼簽章憑證簽過再分發。
