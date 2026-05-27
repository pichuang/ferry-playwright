# ferry-playwright

> 一鍵把 Playwright for .NET 應用打包為**完全離線**的 Windows 安裝包。
> 在 **Windows 11 / Windows Server 2022** 上不需要任何網路，
> 就能用系統內建的 **Microsoft Edge** 跑 Playwright 自動化。

---

## 版本資訊

| 項目 | 版本 |
| --- | --- |
| ferry-playwright | **v0.1.0**（最新 release；可能含尚未發布的變更，見 [CHANGELOG.md](CHANGELOG.md)） |
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

1. 把 `PlaywrightOffline-win-x64-YYYYMMDD-HHMMSS.zip` 拷到目標機，解壓縮。
2. 進入解壓後的資料夾，**雙擊** `install.cmd`。
3. 接受 UAC 提權對話框。
4. 等畫面跳出「Installation complete」即完成。

> 進階：也可以「右鍵 `install.ps1` → 以 PowerShell 執行」傳入額外參數
> （例如 `install.cmd -SkipNuGetFeed`）。

安裝腳本會自動：

- 確認 Windows 版本與 Microsoft Edge 是否存在。
- 把應用程式複製到 `C:\Program Files\PlaywrightApp\`。
- 設定 Playwright 不要嘗試下載瀏覽器（機器層級環境變數）。
- 建立開始功能表與桌面捷徑。
- 註冊離線 NuGet 來源（讓需要時可以直接在這台機器 build 同一專案）。

### 安裝完怎麼執行

打開**新的** PowerShell / Command Prompt（要重新讀環境變數），執行：

```powershell
& "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" https://example.com
```

或直接點桌面 / 開始功能表的「PlaywrightApp」捷徑。

### 解除安裝

在同一個解壓資料夾，**雙擊** `uninstall.cmd`（或右鍵 `uninstall.ps1` → 以 PowerShell 執行）。
腳本會移除程式檔案、清掉環境變數、刪除捷徑、撤銷離線 NuGet 來源。

---

## 給「想自己產生 ZIP」的人

只要一台**有網路**、安裝了 .NET 10 SDK 的開發機（macOS / Linux / Windows 都行）：

```bash
git clone https://github.com/pichuang/ferry-playwright.git
cd ferry-playwright
dotnet run --project src/PlaywrightOfflinePackager
```

ZIP 會出現在 `output/PlaywrightOffline-win-x64-*.zip`，把它拷給目標機就好。

> 進一步的打包選項、自訂應用、CI 自動發布、架構說明，請參考 **[DEVELOPER.md](DEVELOPER.md)**。

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

**Q：ZIP 為什麼這麼大（~320MB）？**
A：~195MB 是 `microsoft.playwright.1.60.0.nupkg`（給離線 NuGet 來源用），
其餘是 .NET runtime + 應用本身 + Playwright Node 驅動。
若你完全不需要在目標機上重新 build，可以在安裝時加 `-SkipNuGetFeed`，
ZIP 本身仍能執行；想完全不打包 nupkg 可改 packager（見 DEVELOPER.md）。

---

## 授權

MIT。詳見 [LICENSE](LICENSE)（若尚未加入請聯絡維護者）。

## 版本紀錄

見 [CHANGELOG.md](CHANGELOG.md)。
