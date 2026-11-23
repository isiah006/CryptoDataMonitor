import { chromium } from "playwright";

async function inspect() {
    const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
    const context = browser.contexts()[0];
    const page = await context.newPage();

    console.log("Monitoring network for Inflow/Outflow...");

    page.on("response", async (response) => {
        const url = response.url();
        if (url.includes("cryptoquant.com") && url.includes("json")) {
            console.log(`[JSON URL]: ${url}`);
            try {
                const json = await response.json();
                if (JSON.stringify(json).toLowerCase().includes("inflow") ||
                    JSON.stringify(json).toLowerCase().includes("outflow")) {
                    console.log(`🎯 FOUND POTENTIAL API: ${url}`);
                    console.log("Metric Path:", json?.metric?.path);
                }
            } catch (e) {}
        }
    });

    try {
        console.log("Navigating to Inflow Total chart...");
        await page.goto("https://cryptoquant.com/asset/btc/chart/exchange-flows/exchange-inflow-total?exchange=all_exchange&window=DAY", {
            waitUntil: "networkidle",
            timeout: 60000
        });

        await page.waitForTimeout(10000);

        console.log("Navigating to Outflow Total chart...");
        await page.goto("https://cryptoquant.com/asset/btc/chart/exchange-flows/exchange-outflow-total?exchange=all_exchange&window=DAY", {
            waitUntil: "networkidle",
            timeout: 60000
        });

        await page.waitForTimeout(10000);
    } catch (error) {
        console.error("Navigation error:", error);
    }

    await page.close();
    console.log("Inspection complete.");
}

inspect();
