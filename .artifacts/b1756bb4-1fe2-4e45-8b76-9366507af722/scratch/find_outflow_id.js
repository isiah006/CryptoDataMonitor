const { chromium } = require("playwright");

async function capture() {
    try {
        const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
        const context = browser.contexts()[0];
        const page = await context.newPage();

        page.on("request", request => {
            const url = request.url();
            if (url.includes("/live/v4/ms/")) {
                console.log(`OUTFLOW_CANDIDATE: ${url}`);
            }
        });

        await page.goto("https://cryptoquant.com/asset/btc/chart/exchange-flows/exchange-outflow-total?exchange=all_exchange&window=DAY", {
            waitUntil: "networkidle",
            timeout: 60000
        });

        await page.waitForTimeout(5000);
        await page.close();
    } catch (e) {
        console.error("ERR: " + e.message);
    }
    process.exit(0);
}

capture();
