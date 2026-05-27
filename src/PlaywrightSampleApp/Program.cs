using Microsoft.Playwright;

// PlaywrightSampleApp
// 使用系統 Microsoft Edge (channel="msedge") 執行最小自動化任務。
// 模式：
//   * 互動模式 (預設)：開啟瀏覽器顯示頁面，等待 Enter 鍵後關閉。
//   * CI 模式      ：以 --ci 引數，或環境變數 CI=true / PLAYWRIGHT_CI=1 啟用。
//                    Headless、不等待輸入、預設 URL 為 about:blank、執行完立即退出。

Console.WriteLine("PlaywrightSampleApp — offline Edge smoke test");
Console.WriteLine("---------------------------------------------");

bool ciMode = args.Contains("--ci")
    || string.Equals(Environment.GetEnvironmentVariable("CI"), "true", StringComparison.OrdinalIgnoreCase)
    || Environment.GetEnvironmentVariable("PLAYWRIGHT_CI") == "1";

var positional = args.Where(a => !a.StartsWith("--", StringComparison.Ordinal)).ToArray();
string targetUrl = positional.Length > 0
    ? positional[0]
    : "about:blank";

Console.WriteLine($"Mode      : {(ciMode ? "CI (headless, non-interactive)" : "Interactive")}");
Console.WriteLine($"Target URL: {targetUrl}");

try
{
    using var playwright = await Playwright.CreateAsync();

    var launchOptions = new BrowserTypeLaunchOptions
    {
        Channel = "msedge",
        Headless = ciMode,
    };

    await using var browser = await playwright.Chromium.LaunchAsync(launchOptions);
    var context = await browser.NewContextAsync();
    var page = await context.NewPageAsync();

    Console.WriteLine($"Navigating to: {targetUrl}");
    await page.GotoAsync(targetUrl);

    var title = await page.TitleAsync();
    Console.WriteLine($"Page title: '{title}'");

    if (!ciMode)
    {
        Console.WriteLine("Press ENTER to close the browser...");
        Console.ReadLine();
    }

    await browser.CloseAsync();
    Console.WriteLine("Done.");
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: {ex.Message}");
    Console.Error.WriteLine(ex);
    return 1;
}
