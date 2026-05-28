using Microsoft.Playwright;
using Microsoft.Playwright.MSTest;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace HelloMSTest;

// 範例 MSTest：以系統 Microsoft Edge 開啟 inline HTML 並驗證內容，
// 不需要任何網路連線。
[TestClass]
public class HelloPlaywrightTests : PageTest
{
    public override BrowserNewContextOptions ContextOptions() => new()
    {
        IgnoreHTTPSErrors = true,
    };

    [TestMethod]
    public async Task Page_should_render_inline_html()
    {
        const string html = """
            <!doctype html>
            <html><head><title>Hello, Playwright!</title></head>
            <body><h1 id="msg">offline-ok</h1></body></html>
            """;

        await Page.SetContentAsync(html);

        Assert.AreEqual("Hello, Playwright!", await Page.TitleAsync());
        Assert.AreEqual("offline-ok", await Page.Locator("#msg").TextContentAsync());
    }
}
