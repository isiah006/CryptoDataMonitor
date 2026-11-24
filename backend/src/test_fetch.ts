async function testBinancePrice() {
    console.log("Testing Binance Public REST API for BTC Price...");
    try {
        const res = await fetch("https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT");
        const json = await res.json();
        console.log("BINANCE STATUS:", res.status);
        console.log("PRICE:", json.lastPrice);
        console.log("PRICE CHANGE PERCENT:", json.priceChangePercent);
        console.log("VOLUME:", json.volume);
        console.log("QUOTE VOLUME (USD):", json.quoteVolume);
    } catch (e) {
        console.error("Fetch error:", e);
    }
    process.exit(0);
}

testBinancePrice();
