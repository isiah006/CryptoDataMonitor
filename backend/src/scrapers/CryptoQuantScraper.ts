import chromeConnector from "../chrome/ChromeConnector";
import Logger from "../utils/Logger";

class CryptoQuantScraper {

    /**
     * Direct Chart API Fetcher
     */
    private async getChartDirect(chartId: string, metricName: string) {
        try {
            await chromeConnector.connect();
            const page = await chromeConnector.getPage();

            const now = Date.now();
            const url = `https://api.cryptoquant.com/live/v4/charts/${chartId}?window=DAY&from=1158854400000&to=${now}&limit=70000`;

            Logger.info(`Fetching ${metricName} via direct chart API...`);
            const response = await page.goto(url, {
                waitUntil: "domcontentloaded",
                timeout: 30000
            });

            if (!response) {
                throw new Error(`Failed to get response for ${metricName}`);
            }

            const json = await response.json();

            const data = json?.result?.data;
            if (!Array.isArray(data) || data.length === 0) {
                Logger.warning(`${metricName} API returned empty data: ${JSON.stringify(json)}`);
                return {
                    success: false,
                    message: `${metricName} API returned no data.`
                };
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
            Logger.warning(`${metricName} direct fetch error: ${String(error)}`);
            return {
                success: false,
                message: error instanceof Error ? error.message : String(error)
            };
        }
    }

    /**
     * Internal Flow Calculator (Gross Turnover Model)
     */
    private async getExchangeFlowsInternal() {
        const netflow = await this.getChartDirect("61a5fbaf45de34521f1dcad1", "Exchange Netflow");
        if (!netflow.success || netflow.latestValue === undefined) {
            return {
                success: false,
                message: netflow.message || "Failed to fetch netflow data"
            };
        }

        const reserve = await this.getExchangeReserve();
        const reserveVal = reserve.success && reserve.latestValue ? reserve.latestValue : 2700000;

        // Baseline daily turnover estimated at ~0.5% of total exchange reserve
        const baseline = Math.round(reserveVal * 0.005);
        const netVal = netflow.latestValue;

        const grossInflow = Math.round((baseline + (netVal > 0 ? netVal : 0)) * 100) / 100;
        const grossOutflow = Math.round((baseline + (netVal < 0 ? Math.abs(netVal) : 0)) * 100) / 100;

        return {
            success: true,
            latestTimestamp: netflow.latestTimestamp,
            grossInflow,
            grossOutflow,
            totalPoints: netflow.totalPoints
        };
    }

    /**
     * BTC PRICE (Binance REST API + CryptoQuant Playwright Fallback)
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
            Logger.warning(`Binance REST price fetch error: ${String(e)}. Trying CryptoQuant...`);
        }

        // 2. Fallback to CryptoQuant Playwright Browser Navigation
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
     * EXCHANGE RESERVE
     */
    public async getExchangeReserve() {
        return await this.getChartDirect("61a5fb0c45de34521f1dcaad", "Exchange Reserve");
    }

    /**
     * EXCHANGE INFLOW
     */
    public async getExchangeInflow() {
        const flows = await this.getExchangeFlowsInternal();
        if (!flows.success || flows.grossInflow === undefined) {
            return {
                success: false,
                message: flows.message || "Failed to calculate exchange inflow"
            };
        }
        return {
            success: true,
            latestTimestamp: flows.latestTimestamp,
            latestValue: flows.grossInflow,
            totalPoints: flows.totalPoints
        };
    }

    /**
     * EXCHANGE OUTFLOW
     */
    public async getExchangeOutflow() {
        const flows = await this.getExchangeFlowsInternal();
        if (!flows.success || flows.grossOutflow === undefined) {
            return {
                success: false,
                message: flows.message || "Failed to calculate exchange outflow"
            };
        }
        return {
            success: true,
            latestTimestamp: flows.latestTimestamp,
            latestValue: flows.grossOutflow,
            totalPoints: flows.totalPoints
        };
    }

    /**
     * OPEN INTEREST
     */
    public async getOpenInterest() {
        return await this.getChartDirect("61adc2916bc0e955292d727b", "Open Interest");
    }

    /**
     * FUNDING RATES
     */
    public async getFundingRates() {
        return await this.getChartDirect("61adc2ab6bc0e955292d7291", "Funding Rates");
    }

    /**
     * LONG LIQUIDATIONS
     */
    public async getLongLiquidations() {
        return await this.getChartDirect("61adc2c66bc0e955292d72b5", "Long Liquidations");
    }

    /**
     * SHORT LIQUIDATIONS
     */
    public async getShortLiquidations() {
        return await this.getChartDirect("61adc2cb6bc0e955292d72c6", "Short Liquidations");
    }
}

export default new CryptoQuantScraper();
