# hello-console — Playwright 離線 Console 範例

最精簡的 Playwright 離線範例：純 console 應用，啟動系統 Edge、載入
inline HTML、印出標題後關閉。

## 怎麼跑

```powershell
cd hello-console

# 互動：開啟 Edge 視窗，按 ENTER 結束
dotnet run

# CI / 離線驗證：headless，跑完直接結束（exit 0）
dotnet run -- --ci
```

## 重點檔案

- `NuGet.config` — `<clear />` + offline feed
- `hello-console.csproj` — net10.0；只引用 `Microsoft.Playwright` 1.60.0
- `Program.cs` — top-level program；用 `Channel="msedge"` 走系統 Edge
