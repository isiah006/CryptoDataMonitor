async function testDirectFetch() {
    const headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/json"
    };

    console.log("Testing direct fetch for BTC price...");
    const priceRes = await fetch("https://api.cryptoquant.com/live/v4/assets/61712eb35a176168a02409e8/now-price", { headers });
    const priceJson = await priceRes.json();
    console.log("PRICE RESULT:", priceJson);

    console.log("Testing direct fetch for Exchange Reserve chart...");
    const chartRes = await fetch(`https://api.cryptoquant.com/live/v4/charts/61a5fb0c45de34521f1dcaad?window=DAY&from=1158854400000&to=${Date.now()}&limit=70000`, { headers });
    const chartJson = await chartRes.json();
    console.log("CHART RESULT DATA POINTS:", chartJson.result?.data?.length);
    if (chartJson.result?.data) {
        console.log("Latest chart point:", chartJson.result.data[chartJson.result.data.length - 1]);
    }
    process.exit(0);
}

testDirectFetch();
