// 範例 console 應用：在離線環境下啟動系統內建的 Microsoft Edge，
// 載入一段 inline HTML，印出標題然後關閉。
//
// 使用方式：
//   dotnet run                # 互動：按 ENTER 結束
//   dotnet run -- --ci        # CI / 離線驗證：跑完直接結束
//
// 環境變數 PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 / PLAYWRIGHT_BROWSERS_PATH=0
// 由 setup-devpack.ps1 設於 machine scope，所以不會嘗試下載 Chromium。

using Microsoft.Playwright;

bool ciMode =
    args.Contains("--ci") ||
    string.Equals(Environment.GetEnvironmentVariable("CI"), "true", StringComparison.OrdinalIgnoreCase) ||
    Environment.GetEnvironmentVariable("PLAYWRIGHT_CI") == "1";

Console.WriteLine($"hello-console (Playwright offline sample) — CI mode: {ciMode}");

using var playwright = await Playwright.CreateAsync();

await using var browser = await playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
{
    Channel = "msedge",
    Headless = ciMode,
});

var page = await browser.NewPageAsync();
await page.SetContentAsync("""
    <!doctype html>
    <html><head><title>Hello, Playwright!</title></head>
    <body><h1>offline-ok</h1></body></html>
    """);

Console.WriteLine($"Page title: {await page.TitleAsync()}");

if (!ciMode)
{
    Console.WriteLine("Press ENTER to close the browser...");
    Console.ReadLine();
}
