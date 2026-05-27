# ferry-playwright — Offline Playwright Packager (Windows)

一鍵把 **Playwright for .NET** 應用打包為**完全離線**的 Windows 安裝包。
產出的 ZIP 解壓後，在 Windows 11 / Windows Server 2022 不需任何網路，
即可使用系統內建 Microsoft Edge 執行 Playwright 自動化。

## 為何能完全離線

| 元件                          | 處理方式                                                                 |
|-------------------------------|--------------------------------------------------------------------------|
| .NET Runtime                  | `dotnet publish --self-contained` 將 runtime 內嵌到應用                  |
| Playwright .NET 受管組件      | NuGet 的 `Microsoft.Playwright` 已隨 publish 一併輸出                    |
| Playwright Node 驅動 / node.exe | NuGet 內附，publish 時自動複製到 `.playwright/node/win32_x64/`           |
| 瀏覽器                        | 使用系統 Edge (`Channel="msedge"`)，**完全不下載** Chromium / Firefox    |
| 環境變數                      | install.ps1 設 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`、`PLAYWRIGHT_BROWSERS_PATH=0` |

## 專案結構

```
ferry-playwright/
├── src/
│   ├── PlaywrightSampleApp/         # 將被打包的範例應用（使用 msedge channel）
│   └── PlaywrightOfflinePackager/   # 打包工具
├── assets/
│   ├── install.ps1                  # 目標機一鍵安裝腳本
│   ├── uninstall.ps1                # 解除安裝腳本
│   └── README.txt                   # 給最終使用者
├── output/                          # 產出 ZIP 的位置
├── global.json
├── Directory.Build.props
└── ferry-playwright.sln(x)
```

## 必要環境（開發 / 打包機）

- .NET 10 SDK（macOS / Linux / Windows 皆可）
- 網路連線（首次打包需下載 NuGet）

## 打包流程

```bash
# 1) 進入專案目錄
cd ferry-playwright

# 2) 執行打包
dotnet run --project src/PlaywrightOfflinePackager

# 3) ZIP 會出現在
ls output/PlaywrightOffline-win-x64-*.zip
```

可選參數：

```bash
dotnet run --project src/PlaywrightOfflinePackager -- \
  --rid    win-x64        # 預設 win-x64
  --config Release        # 預設 Release
  --output output         # 預設 output（相對 repo 根目錄）
```

## 在目標機（離線）安裝

1. 把 `PlaywrightOffline-win-x64-*.zip` 用 USB / 內網拷貝過去。
2. 解壓縮。
3. 右鍵 `install.ps1` → 「以 PowerShell 執行」。
4. 接受 UAC 提權；腳本會：
   - 驗證 Windows 版本與 Edge。
   - 複製檔案到 `C:\Program Files\PlaywrightApp\`。
   - 設定 Playwright 離線環境變數。
   - 建立開始功能表 / 桌面捷徑。

安裝後執行：

```powershell
& "C:\Program Files\PlaywrightApp\PlaywrightSampleApp.exe" https://example.com
```

解除安裝：

```powershell
.\uninstall.ps1
```

## 自訂

要把 `PlaywrightSampleApp` 換成你自己的應用：

1. 修改 `src/PlaywrightSampleApp/Program.cs`，加入你的自動化邏輯。
2. 確保保留 `Channel = "msedge"`（或讓使用者透過參數選擇）。
3. 重新執行 packager。

也可以把整個專案資料夾換掉，再用 `--project` 指向新位置：

```bash
dotnet run --project src/PlaywrightOfflinePackager -- \
  --project path/to/YourApp/YourApp.csproj
```

## 限制與注意事項

- 開發機為 macOS / Linux 時，packager 仍可產出 win-x64 self-contained ZIP，
  但無法在當地測 `install.ps1`。請在 Windows 環境驗證最終結果。
- 產出 exe 未經程式碼簽章；SmartScreen 第一次執行可能顯示警示。
  企業可使用自家程式碼簽章憑證另行簽署。
- 此方案只支援使用 **系統 Edge**。若日後需內建 Chromium，需修改 packager 將
  Playwright 瀏覽器二進位（自 `PLAYWRIGHT_BROWSERS_PATH` 設置目錄）一併納入 ZIP。
