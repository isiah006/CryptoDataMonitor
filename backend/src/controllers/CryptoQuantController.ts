import { Request, Response } from "express";
import CryptoQuantScraper from "../scrapers/CryptoQuantScraper";
import ArkhamService from "../services/ArkhamService";
import CoinglassService from "../services/CoinglassService";
import Logger from "../utils/Logger";
import PersistenceService from "../services/PersistenceService";

// console.log("🔥🔥🔥 CryptoQuantController.ts LOADED 🔥🔥🔥");

class CryptoQuantController {

    private handleError(
        res: Response,
        error: unknown,
        context: string
    ): void {

        console.error(`${context}:`, error);

        res.status(500).json({

            success: false,

            message:
                error instanceof Error
                    ? error.message
                    : String(error)

        });
    }

    public async getExchangeInflow(
        req: Request,
        res: Response
    ): Promise<void> {

        try {

            const result =
                await CryptoQuantScraper.getExchangeInflow();

            res.json(result);

        } catch (error) {

            this.handleError(
                res,
                error,
                "Exchange inflow fetch error"
            );
        }
    }

    public async getExchangeOutflow(
        req: Request,
        res: Response
    ): Promise<void> {

        try {

            const result =
                await CryptoQuantScraper.getExchangeOutflow();

            res.json(result);

        } catch (error) {

            this.handleError(
                res,
                error,
                "Exchange outflow fetch error"
            );
        }
    }

    public async getExchangeReserve(
        req: Request,
        res: Response
    ): Promise<void> {

        try {

            const result =
                await CryptoQuantScraper.getExchangeReserve();

            res.json(result);

        } catch (error) {

            this.handleError(
                res,
                error,
                "Exchange reserve fetch error"
            );
        }
    }

    public async getOpenInterest(
        req: Request,
        res: Response
    ): Promise<void> {

        try {

            const result =
                await CryptoQuantScraper.getOpenInterest();

            res.json(result);

        } catch (error) {

            this.handleError(
                res,
                error,
                "Open interest fetch error"
            );
        }
    }

    public async getFundingRates(
        req: Request,
        res: Response
    ): Promise<void> {

        try {

            const result =
                await CryptoQuantScraper.getFundingRates();

            res.json(result);

        } catch (error) {

            this.handleError(
                res,
                error,
                "Funding rates fetch error"
            );
        }
    }

    /**
     * Get the last successful fetch from disk
     */
    public async getCachedBTCData(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const cachedData = await PersistenceService.loadCache();
            if (cachedData) {
                res.json(cachedData);
            } else {
                res.status(404).json({
                    success: false,
                    message: "No cached data found."
                });
            }
        } catch (error) {
            this.handleError(res, error, "Cache retrieval error");
        }
    }

    public async getBTCData(
        req: Request,
        res: Response
    ): Promise<void> {

        console.log("🔥🔥🔥  getBTCData CONTROLLER HIT 🔥🔥🔥");

        try {

            const btcPrice =
                await CryptoQuantScraper.getBTCPrice();

            console.log("🔥 BTC PRICE RESULT:");
            console.log(btcPrice);

            const exchangeInflow =
                await CryptoQuantScraper.getExchangeInflow();

            const exchangeOutflow =
                await CryptoQuantScraper.getExchangeOutflow();

            const exchangeReserve =
                await CryptoQuantScraper.getExchangeReserve();

            const openInterest =
                await CryptoQuantScraper.getOpenInterest();

            const fundingRates =
                await CryptoQuantScraper.getFundingRates();

            const longLiquidations =
                await CryptoQuantScraper.getLongLiquidations();

            const shortLiquidations =
                await CryptoQuantScraper.getShortLiquidations();

            // Calculate Netflow for Arkham & Coinglass Flow Analysis
            const netVal = (exchangeInflow?.latestValue || 0) - (exchangeOutflow?.latestValue || 0);
            const reserveVal = exchangeReserve?.latestValue || 2700000;

            const arkhamData = await ArkhamService.getArkhamData(netVal, reserveVal);
            const coinglassData = await CoinglassService.getCoinglassFlowData(netVal);

            const responseData = {
                success: true,
                asset: "BTC",
                VERSION: "V3_GOTO_API_METHOD",
                timestamp: new Date().toISOString(),
                data: {
                    btcPrice: btcPrice || { success: false, message: "btcPrice was undefined" },
                    exchangeInflowTotal: exchangeInflow,
                    exchangeOutflowTotal: exchangeOutflow,
                    exchangeReserve: exchangeReserve,
                    openInterest: openInterest,
                    fundingRates: fundingRates,
                    longLiquidations: longLiquidations,
                    shortLiquidations: shortLiquidations,
                    arkhamIntelligence: arkhamData,
                    coinglassFlows: coinglassData
                }
            };

            // PERSIST SUCCESSFUL FETCH
            await PersistenceService.saveCache(responseData);

            Logger.info(`BTC Data Fetch Successful for ${responseData.asset}`);
            res.json(responseData);

        } catch (error) {

            Logger.warning(`Live fetch degraded: ${String(error)}. Serving cached fallback...`);

            const cachedData = await PersistenceService.loadCache();
            if (cachedData) {
                res.json({
                    ...cachedData,
                    cachedFallback: true,
                    message: "Live fetch degraded. Serving cached market snapshot."
                });
                return;
            }

            this.handleError(
                res,
                error,
                "CryptoQuant BTC fetch error"
            );
        }
    }

    /**
     * Wipe storage
     */
    public async clearBTCData(
        req: Request,
        res: Response
    ): Promise<void> {
        await PersistenceService.clearCache();
        res.json({ success: true, message: "Storage wiped." });
    }

}

export default new CryptoQuantController();
