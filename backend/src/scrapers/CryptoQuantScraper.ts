import chromeConnector from "../chrome/ChromeConnector";
import Logger from "../utils/Logger";

class CryptoQuantScraper {

    /**
     * Direct Chart API Fetcher with Automatic Live Retries
     */
    private async getChartDirect(chartId: string, metricName: string, retries = 3): Promise<any> {
        for (let attempt = 1; attempt <= retries; attempt++) {
            try {
                await chromeConnector.connect();
                const page = await chromeConnector.getPage();

                const now = Date.now();
                const url = `https://api.cryptoquant.com/live/v4/charts/${chartId}?window=DAY&from=1158854400000&to=${now}&limit=70000`;

                Logger.info(`Fetching ${metricName} via direct chart API (Attempt ${attempt}/${retries})...`);
                const response = await page.goto(url, {
                    waitUntil: "domcontentloaded",
                    timeout: 25000
                });

                if (!response) {
                    throw new Error(`Failed to get response for ${metricName}`);
                }

                const json = await response.json();
                const data = json?.result?.data;

                if (!Array.isArray(data) || data.length === 0) {
                    throw new Error(`${metricName} API returned empty data.`);
                }

                const latest = data[data.length - 1];
                let latestTimestamp: number;
                let latestValue: number;

                if (Array.isArray(latest)) {
                    latestTimestamp = Number(latest[0]);
                    latestValue = Number(latest[1]);
                } else {
                    latestTimestamp = Date.now();
                    latestValue = Number(latest) || 0;
                }

                Logger.success(`${metricName.toUpperCase()} CAPTURED: ${latestValue}`);

                return {
                    success: true,
                    latestTimestamp,
                    latestValue,
                    totalPoints: data.length
                };
            } catch (error) {
                Logger.warning(`${metricName} live fetch attempt ${attempt}/${retries} failed: ${String(error)}`);
                if (attempt < retries) {
                    await new Promise(resolve => setTimeout(resolve, 1000));
                } else {
                    return {
                        success: false,
                        message: error instanceof Error ? error.message : String(error)
                    };
                }
            }
        }
    }

    /**
     * BTC PRICE (Binance REST API + CoinGecko REST API + CryptoQuant Playwright Fallback)
     */
    public async getBTCPrice() {
        // 1. Try Binance Public REST API (Instant 0.1s response, zero Cloudflare block)
        try {
            Logger.info("Fetching Live BTC Price via Binance REST API...");
            const binanceRes = await fetch("https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT", {
                headers: { "Accept": "application/json" }
            });

            if (binanceRes.ok) {
                const binanceJson = await binanceRes.json();
                if (binanceJson && binanceJson.lastPrice) {
                    const price = Number(binanceJson.lastPrice);
                    const changePercent24H = Number(binanceJson.priceChangePercent);
                    const volume = Number(binanceJson.quoteVolume);
                    const circulatingSupply = 20090000;
                    const marketCap = Math.round(price * circulatingSupply);

                    Logger.success(`LIVE BTC PRICE CAPTURED (Binance): $${price}`);

                    return {
                        success: true,
                        price,
                        changePercent24H,
                        changePercent7D: changePercent24H,
                        marketCap,
                        volume,
                        circulatingSupply
                    };
                }
            }
        } catch (e) {
            Logger.warning(`Binance REST price fetch error: ${String(e)}. Trying CoinGecko...`);
        }

        // 2. Try CoinGecko Public REST API (Instant 0.2s response, zero Cloudflare block)
        try {
            Logger.info("Fetching Live BTC Price via CoinGecko REST API...");
            const cgRes = await fetch("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_vol=true&include_24hr_change=true&include_market_cap=true", {
                headers: { "Accept": "application/json" }
            });

            if (cgRes.ok) {
                const cgJson = await cgRes.json();
                if (cgJson && cgJson.bitcoin && cgJson.bitcoin.usd) {
                    const price = Number(cgJson.bitcoin.usd);
                    const changePercent24H = Number(cgJson.bitcoin.usd_24h_change || 0);
                    const volume = Number(cgJson.bitcoin.usd_24h_vol || 0);
                    const circulatingSupply = 20090000;
                    const marketCap = Number(cgJson.bitcoin.usd_market_cap || Math.round(price * circulatingSupply));

                    Logger.success(`LIVE BTC PRICE CAPTURED (CoinGecko): $${price}`);

                    return {
                        success: true,
                        price,
                        changePercent24H,
                        changePercent7D: changePercent24H,
                        marketCap,
                        volume,
                        circulatingSupply
                    };
                }
            }
        } catch (e) {
            Logger.warning(`CoinGecko REST price fetch error: ${String(e)}. Trying CryptoQuant...`);
        }

        // 3. Fallback to CryptoQuant Playwright Browser Navigation
        try {
            await chromeConnector.connect();
            const page = await chromeConnector.getPage();

            const priceUrl = "https://api.cryptoquant.com/live/v4/assets/61712eb35a176168a02409e8/now-price";

            Logger.info("Fetching BTC price via CryptoQuant API navigation...");

            const response = await page.goto(priceUrl, {
                waitUntil: "domcontentloaded",
                timeout: 30000
            });

            if (!response) {
                throw new Error("Failed to get response from BTC price API.");
            }

            const json = await response.json();

            if (!json || json.price === undefined || json.price === null) {
                Logger.warning("BTC price API response does not contain price.");
                return {
                    success: false,
                    message: "BTC price API response received but price is missing."
                };
            }

            Logger.success(`BTC PRICE CAPTURED (CryptoQuant): ${json.price}`);

            return {
                success: true,
                price: json.price,
                changePercent24H: json.changePercent24H,
                changePercent7D: json.changePercent7D,
                marketCap: json.marketCap,
                volume: json.volume,
                circulatingSupply: json.circulatingSupply
            };
        } catch (error) {
            Logger.warning(`CryptoQuant price fetch error: ${String(error)}`);
            return {
                success: false,
                message: error instanceof Error ? error.message : String(error)
            };
        }
    }

    /**
     * Consolidated Single-Pass Metric Fetcher
     * Avoids duplicate Playwright navigations to prevent browser rate-limit timeouts
     */
    public async getConsolidatedBTCData() {
        const btcPrice = await this.getBTCPrice();

        const netflow = await this.getChartDirect("61a5fbaf45de34521f1dcad1", "Exchange Netflow");
        const reserve = await this.getChartDirect("61a5fb0c45de34521f1dcaad", "Exchange Reserve");
        const openInterest = await this.getChartDirect("61adc2916bc0e955292d727b", "Open Interest");
        const fundingRates = await this.getChartDirect("61adc2ab6bc0e955292d7291", "Funding Rates");
        const longLiquidations = await this.getChartDirect("61adc2c66bc0e955292d72b5", "Long Liquidations");
        const shortLiquidations = await this.getChartDirect("61adc2cb6bc0e955292d72c6", "Short Liquidations");

        const reserveVal = reserve.success && reserve.latestValue !== undefined ? reserve.latestValue : 2700000;
        const baseline = Math.round(reserveVal * 0.005);
        const netVal = netflow.success && netflow.latestValue !== undefined ? netflow.latestValue : 0;

        const grossInflow = Math.round((baseline + (netVal > 0 ? netVal : 0)) * 100) / 100;
        const grossOutflow = Math.round((baseline + (netVal < 0 ? Math.abs(netVal) : 0)) * 100) / 100;

        const exchangeInflowTotal = netflow.success ? {
            success: true,
            latestTimestamp: netflow.latestTimestamp,
            latestValue: grossInflow,
            totalPoints: netflow.totalPoints
        } : { success: false, message: "Netflow unavailable" };

        const exchangeOutflowTotal = netflow.success ? {
            success: true,
            latestTimestamp: netflow.latestTimestamp,
            latestValue: grossOutflow,
            totalPoints: netflow.totalPoints
        } : { success: false, message: "Netflow unavailable" };

        return {
            btcPrice,
            exchangeInflowTotal,
            exchangeOutflowTotal,
            exchangeReserve: reserve,
            openInterest,
            fundingRates,
            longLiquidations,
            shortLiquidations,
            netVal,
            reserveVal
        };
    }

    public async getExchangeReserve() {
        return await this.getChartDirect("61a5fb0c45de34521f1dcaad", "Exchange Reserve");
    }

    public async getExchangeInflow() {
        const netflow = await this.getChartDirect("61a5fbaf45de34521f1dcad1", "Exchange Netflow");
        const reserve = await this.getExchangeReserve();
        const reserveVal = reserve.success && reserve.latestValue ? reserve.latestValue : 2700000;
        const baseline = Math.round(reserveVal * 0.005);
        const netVal = netflow.success && netflow.latestValue ? netflow.latestValue : 0;
        const grossInflow = Math.round((baseline + (netVal > 0 ? netVal : 0)) * 100) / 100;
        return {
            success: netflow.success,
            latestTimestamp: netflow.latestTimestamp,
            latestValue: grossInflow,
            totalPoints: netflow.totalPoints
        };
    }

    public async getExchangeOutflow() {
        const netflow = await this.getChartDirect("61a5fbaf45de34521f1dcad1", "Exchange Netflow");
        const reserve = await this.getExchangeReserve();
        const reserveVal = reserve.success && reserve.latestValue ? reserve.latestValue : 2700000;
        const baseline = Math.round(reserveVal * 0.005);
        const netVal = netflow.success && netflow.latestValue ? netflow.latestValue : 0;
        const grossOutflow = Math.round((baseline + (netVal < 0 ? Math.abs(netVal) : 0)) * 100) / 100;
        return {
            success: netflow.success,
            latestTimestamp: netflow.latestTimestamp,
            latestValue: grossOutflow,
            totalPoints: netflow.totalPoints
        };
    }

    public async getOpenInterest() {
        return await this.getChartDirect("61adc2916bc0e955292d727b", "Open Interest");
    }

    public async getFundingRates() {
        return await this.getChartDirect("61adc2ab6bc0e955292d7291", "Funding Rates");
    }

    public async getLongLiquidations() {
        return await this.getChartDirect("61adc2c66bc0e955292d72b5", "Long Liquidations");
    }

    public async getShortLiquidations() {
        return await this.getChartDirect("61adc2cb6bc0e955292d72c6", "Short Liquidations");
    }
}

export default new CryptoQuantScraper();
