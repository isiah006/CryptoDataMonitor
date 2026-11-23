const { chromium } = require("playwright");

async function capture() {
    try {
        const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
        const context = browser.contexts()[0];
        const page = await context.newPage();

        page.on("response", async response => {
            const url = response.url();
            if (url.includes("/live/v4/ms/") && url.includes("charts")) {
                console.log(`FOUND_MS_URL: ${url}`);
                try {
                    const json = await response.json();
                    console.log("JSON_STRUCTURE:", JSON.stringify(json).substring(0, 500) + "...");
                    if (json.charts && json.charts[0] && json.charts[0].result) {
                        console.log("DATA_LATEST:", json.charts[0].result.data[json.charts[0].result.data.length - 1]);
                        console.log("PATH:", json.metricId); // Or somewhere else
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
