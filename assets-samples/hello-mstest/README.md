# hello-mstest — Playwright + MSTest 離線範例

`hello-nunit` 的 MSTest 版本，使用 `Microsoft.Playwright.MSTest`。

## 怎麼跑

```powershell
cd hello-mstest
dotnet test --settings .runsettings
```

預期：1 passed。

## 重點檔案

- `NuGet.config` — `<clear />` + offline feed
- `hello-mstest.csproj` — net10.0；MSTest 3.6.4、Playwright 1.60.0 等都 pin 到 bundle 版本
- `HelloPlaywrightTests.cs` — 用 inline HTML 驗證 Edge 啟動成功
- `.runsettings` — 走 Edge channel，headless
