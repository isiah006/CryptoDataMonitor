import { Request, Response } from "express";
import CryptoQuantScraper from "../scrapers/CryptoQuantScraper";
import ArkhamService from "../services/ArkhamService";
import CoinglassService from "../services/CoinglassService";
import Logger from "../utils/Logger";
import PersistenceService from "../services/PersistenceService";

class CryptoQuantController {

    private getDeviceId(req: Request): string {
        const headerId = req.headers["x-device-id"];
        if (typeof headerId === "string" && headerId.trim().length > 0) {
            return headerId.trim();
        }
        return "default_device";
    }

    private handleError(
        res: Response,
        error: unknown,
        context: string
    ): void {
        console.error(`${context}:`, error);
        res.status(500).json({
            success: false,
            message: error instanceof Error ? error.message : String(error)
        });
    }

    public async getExchangeInflow(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const result = await CryptoQuantScraper.getExchangeInflow();
            res.json(result);
        } catch (error) {
            this.handleError(res, error, "Exchange inflow fetch error");
        }
    }

    public async getExchangeOutflow(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const result = await CryptoQuantScraper.getExchangeOutflow();
            res.json(result);
        } catch (error) {
            this.handleError(res, error, "Exchange outflow fetch error");
        }
    }

    public async getExchangeReserve(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const result = await CryptoQuantScraper.getExchangeReserve();
            res.json(result);
        } catch (error) {
            this.handleError(res, error, "Exchange reserve fetch error");
        }
    }

    public async getOpenInterest(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const result = await CryptoQuantScraper.getOpenInterest();
            res.json(result);
        } catch (error) {
            this.handleError(res, error, "Open interest fetch error");
        }
    }

    public async getFundingRates(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const result = await CryptoQuantScraper.getFundingRates();
            res.json(result);
        } catch (error) {
            this.handleError(res, error, "Funding rates fetch error");
        }
    }

    /**
     * Get the last successful fetch for this specific device
     */
    public async getCachedBTCData(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const deviceId = this.getDeviceId(req);
            const cachedData = await PersistenceService.loadCache(deviceId);
            if (cachedData) {
                res.json(cachedData);
            } else {
                res.status(404).json({
                    success: false,
                    message: `No cached data found for device: ${deviceId}`
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
        const deviceId = this.getDeviceId(req);
        console.log(`🔥🔥🔥 getBTCData CONTROLLER HIT FOR DEVICE: ${deviceId} 🔥🔥🔥`);

        try {
            // Load last saved cache for per-metric restoration fallback
            const lastCache = await PersistenceService.loadCache(deviceId);
            const prevData = lastCache?.data || {};

            // 1. Consolidated single-pass fetch (reduces browser navigations from 11 to 6)
            const sc = await CryptoQuantScraper.getConsolidatedBTCData();

            // 2. Fetch Arkham & Coinglass flow analysis
            const arkhamData = await ArkhamService.getArkhamData(sc.netVal, sc.reserveVal);
            const coinglassData = await CoinglassService.getCoinglassFlowData(sc.netVal);

            // 3. Per-Metric Memory Restoration Helper
            const restoreMetric = (current: any, prevKey: string) => {
                if (current && current.success && current.latestValue !== undefined && current.latestValue !== null) {
                    return current;
                }
                const prevMetric = prevData[prevKey];
                if (prevMetric && prevMetric.success && prevMetric.latestValue !== undefined && prevMetric.latestValue !== null) {
                    Logger.warning(`Metric '${prevKey}' live fetch was null. Restored from device memory (${prevMetric.latestValue}).`);
                    return {
                        ...prevMetric,
                        restoredFromMemory: true
                    };
                }
                return current || { success: false, message: "Metric unavailable" };
            };

            const restorePrice = (current: any) => {
                if (current && current.success && current.price !== undefined && current.price !== null) {
                    return current;
                }
                const prevPrice = prevData["btcPrice"];
                if (prevPrice && prevPrice.success && prevPrice.price !== undefined && prevPrice.price !== null) {
                    Logger.warning(`BTC Price live fetch was null. Restored from device memory ($${prevPrice.price}).`);
                    return {
                        ...prevPrice,
                        restoredFromMemory: true
                    };
                }
                return current || { success: false, message: "Price unavailable" };
            };

            const responseData = {
                success: true,
                asset: "BTC",
                deviceId,
                VERSION: "V3_CONSOLIDATED_ZERO_NA",
                timestamp: new Date().toISOString(),
                data: {
                    btcPrice: restorePrice(sc.btcPrice),
                    exchangeInflowTotal: restoreMetric(sc.exchangeInflowTotal, "exchangeInflowTotal"),
                    exchangeOutflowTotal: restoreMetric(sc.exchangeOutflowTotal, "exchangeOutflowTotal"),
                    exchangeReserve: restoreMetric(sc.exchangeReserve, "exchangeReserve"),
                    openInterest: restoreMetric(sc.openInterest, "openInterest"),
                    fundingRates: restoreMetric(sc.fundingRates, "fundingRates"),
                    longLiquidations: restoreMetric(sc.longLiquidations, "longLiquidations"),
                    shortLiquidations: restoreMetric(sc.shortLiquidations, "shortLiquidations"),
                    arkhamIntelligence: arkhamData || prevData["arkhamIntelligence"],
                    coinglassFlows: coinglassData || prevData["coinglassFlows"]
                }
            };

            // PERSIST DEVICE-SPECIFIC FETCH
            await PersistenceService.saveCache(responseData, deviceId);

            Logger.info(`BTC Data Fetch Successful for ${responseData.asset} on Device ${deviceId}`);
            res.json(responseData);

        } catch (error) {
            Logger.warning(`Live fetch degraded for device ${deviceId}: ${String(error)}. Serving cached fallback...`);

            const cachedData = await PersistenceService.loadCache(deviceId);
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
     * Wipe storage for this specific device
     */
    public async clearBTCData(
        req: Request,
        res: Response
    ): Promise<void> {
        const deviceId = this.getDeviceId(req);
        await PersistenceService.clearCache(deviceId);
        res.json({ success: true, message: `Storage wiped for device: ${deviceId}` });
    }

}

export default new CryptoQuantController();
