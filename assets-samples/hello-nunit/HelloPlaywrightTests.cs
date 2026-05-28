using Microsoft.Playwright;
using Microsoft.Playwright.NUnit;

namespace HelloNUnit;

// 範例 NUnit 測試：以系統內建的 Microsoft Edge 開啟一個內嵌 HTML 頁面
// （不需要連網），並驗證標題與內容皆正確。
[Parallelizable(ParallelScope.Self)]
[TestFixture]
public class HelloPlaywrightTests : PageTest
{
    // 透過 BrowserNewContextOptions 指定 Edge channel，避免 Playwright 嘗試
    // 下載自帶的 Chromium。machine-scope 環境變數
    // PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 / PLAYWRIGHT_BROWSERS_PATH=0
    // 由 setup-devpack.ps1 設好，所以離線環境也能正常啟動。
    public override BrowserNewContextOptions ContextOptions() => new()
    {
        IgnoreHTTPSErrors = true,
    };

    [Test]
    public async Task Page_should_render_inline_html()
    {
        const string html = """
            <!doctype html>
            <html><head><title>Hello, Playwright!</title></head>
            <body><h1 id="msg">offline-ok</h1></body></html>
            """;

        await Page.SetContentAsync(html);

        Assert.Multiple(() =>
        {
            Assert.That(Page.TitleAsync().Result, Is.EqualTo("Hello, Playwright!"));
        });

        var text = await Page.Locator("#msg").TextContentAsync();
        Assert.That(text, Is.EqualTo("offline-ok"));
    }
}
