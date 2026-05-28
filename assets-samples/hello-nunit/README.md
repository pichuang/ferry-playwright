# hello-nunit — Playwright + NUnit 離線範例

這是 `PlaywrightOffline-*.zip` 內附的離線範例專案。**完全不需連網**即可
restore / build / test，前提是這台機器已經跑過 `setup.ps1`
（或 `setup-devpack.ps1`）把 dev pack 安裝完畢。

## 你會學到什麼

- 怎麼建一個 .NET 10 + NUnit + `Microsoft.Playwright.NUnit` 的測試專案
- 怎麼用「專案層 `NuGet.config` + `<clear />`」鎖死成只用離線 feed
- 怎麼用 `.runsettings` 指定 Playwright 走系統 Microsoft Edge
  （channel = `msedge`），完全不下載 Chromium

## 怎麼跑

把整個 `hello-nunit` 資料夾 copy 出來（不要直接在 ZIP 內跑）：

```powershell
cd hello-nunit
dotnet test --settings .runsettings
```

預期輸出：1 passed。

## 結構

| 檔案 | 用途 |
|---|---|
| `NuGet.config` | `<clear />` + 只留 `PlaywrightOfflineFeed`，覆蓋所有繼承來源 |
| `hello-nunit.csproj` | TargetFramework `net10.0`，PackageReference 全部 pin 到 dev pack bundle 版本 |
| `HelloPlaywrightTests.cs` | 範例測試：載入 inline HTML，驗證標題 / 元素 |
| `.runsettings` | Playwright 走 Edge channel，headless |

## 我要建立新專案

```powershell
& "C:\Path\To\Extracted\new-playwright-project.ps1" -Name MyTests -Template nunit
```

或手動：把 `NuGet.config.template` 複製成新專案的 `NuGet.config`，然後
`dotnet new nunit --no-restore` 再 `dotnet add package ... --version ... --no-restore`。
