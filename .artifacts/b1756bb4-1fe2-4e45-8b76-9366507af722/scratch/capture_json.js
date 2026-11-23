const { chromium } = require("playwright");

async function capture() {
    try {
        const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
        const context = browser.contexts()[0];
        const page = await context.newPage();

        page.on("response", async response => {
            const url = response.url();
            if (url.includes("/live/v4/")) {
                console.log(`URL: ${url}`);
                try {
                    const json = await response.json();
                    // Just print keys and first item of data to see structure
                    console.log("KEYS:", Object.keys(json));
                    if (json.result && json.result.data) {
                        console.log("DATA_SAMPLE:", json.result.data[json.result.data.length - 1]);
                    }
                    if (json.metric) {
                        console.log("METRIC_PATH:", json.metric.path);
                    }
                } catch (e) {
                    console.log("NOT_JSON");
                }
            }
        });

        await page.goto("https://cryptoquant.com/asset/btc/chart/exchange-flows/exchange-inflow-total?exchange=all_exchange&window=DAY", {
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
