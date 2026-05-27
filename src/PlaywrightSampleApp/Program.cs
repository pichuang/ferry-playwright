using Microsoft.Playwright;

// PlaywrightSampleApp
// 用系統內建 Microsoft Edge（channel="msedge"）執行最小自動化任務。
// 此程式被「PlaywrightOfflinePackager」打包後，可於離線 Windows 11 / Server 2022 直接執行。

Console.WriteLine("PlaywrightSampleApp — offline Edge smoke test");
Console.WriteLine("---------------------------------------------");

var targetUrl = args.Length > 0 ? args[0] : "about:blank";

try
{
    using var playwright = await Playwright.CreateAsync();

    var launchOptions = new BrowserTypeLaunchOptions
    {
        Channel = "msedge",
        Headless = false,
    };

    await using var browser = await playwright.Chromium.LaunchAsync(launchOptions);
    var context = await browser.NewContextAsync();
    var page = await context.NewPageAsync();

    Console.WriteLine($"Navigating to: {targetUrl}");
    await page.GotoAsync(targetUrl);

    var title = await page.TitleAsync();
    Console.WriteLine($"Page title: '{title}'");

    Console.WriteLine("Press ENTER to close the browser...");
    Console.ReadLine();

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
