using System.Text;
using Microsoft.Playwright;

// PlaywrightSampleApp — Hello-World self-test for the offline Playwright package.
//
// 模式：
//   * 互動模式 (預設)         ：開啟 Edge 顯示內嵌的 Hello-World 頁面，跑斷言，等待 Enter 後關閉。
//   * CI / self-test 模式      ：以 --ci 引數，或環境變數 CI=true / PLAYWRIGHT_CI=1 啟用。
//                                Headless、不等待輸入、執行完立即退出 (0=PASS, 1=FAIL)。
//   * 使用者帶入 URL           ：第一個位置引數若是 URL，則改瀏覽該 URL（不跑斷言、只印 title）。

Console.WriteLine("PlaywrightSampleApp — Hello-World offline smoke test");
Console.WriteLine("----------------------------------------------------");

bool ciMode = args.Contains("--ci")
    || string.Equals(Environment.GetEnvironmentVariable("CI"), "true", StringComparison.OrdinalIgnoreCase)
    || Environment.GetEnvironmentVariable("PLAYWRIGHT_CI") == "1";

var positional = args.Where(a => !a.StartsWith("--", StringComparison.Ordinal)).ToArray();
string? userUrl = positional.Length > 0 ? positional[0] : null;

const string HelloHtml = """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Hello, Playwright!</title>
<style>
  body { font-family: -apple-system, Segoe UI, sans-serif; padding: 2rem; }
  h1 { color: #2d7d46; }
  .meta { color: #555; font-size: 0.9rem; }
</style>
</head>
<body>
<h1 id="msg">Hello, Playwright!</h1>
<p class="meta">Embedded self-test page — no network required.</p>
<script>window.__pwReady = true;</script>
</body>
</html>
""";

string helloDataUrl = "data:text/html;base64," + Convert.ToBase64String(Encoding.UTF8.GetBytes(HelloHtml));
string targetUrl = userUrl ?? helloDataUrl;
bool runAssertions = userUrl is null;

Console.WriteLine($"Mode      : {(ciMode ? "CI (headless, non-interactive)" : "Interactive")}");
Console.WriteLine($"Target    : {(runAssertions ? "embedded Hello-World page" : userUrl)}");

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

    Console.WriteLine("Navigating...");
    await page.GotoAsync(targetUrl);

    var title = await page.TitleAsync();
    Console.WriteLine($"Page title: '{title}'");

    int exitCode = 0;

    if (runAssertions)
    {
        Console.WriteLine();
        Console.WriteLine("Running assertions:");

        bool titleOk = title == "Hello, Playwright!";
        Report("title equals 'Hello, Playwright!'", titleOk);

        var msg = await page.Locator("#msg").TextContentAsync();
        bool msgOk = msg == "Hello, Playwright!";
        Report($"#msg text content equals 'Hello, Playwright!' (got '{msg}')", msgOk);

        bool jsOk = await page.EvaluateAsync<bool>("() => window.__pwReady === true");
        Report("window.__pwReady === true (JS evaluation)", jsOk);

        bool allOk = titleOk && msgOk && jsOk;
        Console.WriteLine();
        Console.WriteLine(allOk ? "RESULT: PASS" : "RESULT: FAIL");
        exitCode = allOk ? 0 : 1;
    }

    if (!ciMode)
    {
        Console.WriteLine();
        Console.WriteLine("Press ENTER to close the browser...");
        Console.ReadLine();
    }

    await browser.CloseAsync();
    Console.WriteLine("Done.");
    return exitCode;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: {ex.Message}");
    Console.Error.WriteLine(ex);
    return 1;
}

static void Report(string label, bool ok)
{
    Console.WriteLine($"  {(ok ? "[OK]  " : "[FAIL]")} {label}");
}
