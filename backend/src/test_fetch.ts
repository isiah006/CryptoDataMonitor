import CryptoQuantScraper from "./scrapers/CryptoQuantScraper";

async function testFlows() {
    console.log("=== TESTING GROSS TURNOVER MODEL FLOWS ===");
    const inflow = await CryptoQuantScraper.getExchangeInflow();
    console.log("INFLOW RESULT:", JSON.stringify(inflow, null, 2));

    const outflow = await CryptoQuantScraper.getExchangeOutflow();
    console.log("OUTFLOW RESULT:", JSON.stringify(outflow, null, 2));

    process.exit(0);
}

testFlows();
