const { chromium } = require("playwright");

async function capture() {
    try {
        const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
        const context = browser.contexts()[0];
        const page = await context.newPage();

        console.log("NAVIGATING_START");

        page.on("request", request => {
            const url = request.url();
            if (url.includes("cryptoquant.com") && (url.includes("chart") || url.includes("flow") || url.includes("json"))) {
                console.log(`REQ: ${url}`);
            }
        });

        await page.goto("https://cryptoquant.com/asset/btc/chart/exchange-flows/exchange-inflow-total", {
            waitUntil: "networkidle",
            timeout: 60000
        });

        console.log("PAGE_LOADED");
        await page.waitForTimeout(10000);

        await page.close();
        console.log("CAPTURE_DONE");
    } catch (e) {
        console.error("ERR: " + e.message);
    }
    process.exit(0);
}

capture();
