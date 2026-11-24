import CryptoQuantScraper from "./scrapers/CryptoQuantScraper";
import ArkhamService from "./services/ArkhamService";
import CoinglassService from "./services/CoinglassService";

async function testFullFetch() {
    console.log("=== TESTING FULL BACKEND CONTROLLER FETCH ===");

    const btcPrice = await CryptoQuantScraper.getBTCPrice();
    console.log("1. BTC PRICE:", btcPrice);

    const exchangeInflow = await CryptoQuantScraper.getExchangeInflow();
    console.log("2. INFLOW:", exchangeInflow);

    const exchangeOutflow = await CryptoQuantScraper.getExchangeOutflow();
    console.log("3. OUTFLOW:", exchangeOutflow);

    const exchangeReserve = await CryptoQuantScraper.getExchangeReserve();
    console.log("4. RESERVE:", exchangeReserve);

    const openInterest = await CryptoQuantScraper.getOpenInterest();
    console.log("5. OPEN INTEREST:", openInterest);

    const fundingRates = await CryptoQuantScraper.getFundingRates();
    console.log("6. FUNDING RATES:", fundingRates);

    const longLiquidations = await CryptoQuantScraper.getLongLiquidations();
    console.log("7. LONG LIQUIDATIONS:", longLiquidations);

    const shortLiquidations = await CryptoQuantScraper.getShortLiquidations();
    console.log("8. SHORT LIQUIDATIONS:", shortLiquidations);

    const netVal = (exchangeInflow?.latestValue || 0) - (exchangeOutflow?.latestValue || 0);
    const reserveVal = exchangeReserve?.latestValue || 2700000;

    const arkhamData = await ArkhamService.getArkhamData(netVal, reserveVal);
    console.log("9. ARKHAM:", arkhamData);

    const coinglassData = await CoinglassService.getCoinglassFlowData(netVal);
    console.log("10. COINGLASS:", coinglassData);

    process.exit(0);
}

testFullFetch();
