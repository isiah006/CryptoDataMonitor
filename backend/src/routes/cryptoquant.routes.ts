import { Router } from "express";
import CryptoQuantController from "../controllers/CryptoQuantController";

const router = Router();

router.get("/btc", (req, res, next) => {

    console.log("🔥🔥🔥 /cryptoquant/btc ROUTE HIT 🔥🔥🔥");

    return CryptoQuantController.getBTCData(req, res);
});

router.get(
    "/cached-btc",
    CryptoQuantController.getCachedBTCData
);

router.delete(
    "/clear-storage",
    CryptoQuantController.clearBTCData
);

router.get(
    "/exchange-inflow",
    CryptoQuantController.getExchangeInflow
);

router.get(
    "/exchange-outflow",
    CryptoQuantController.getExchangeOutflow
);

router.get(
    "/exchange-reserve",
    CryptoQuantController.getExchangeReserve
);

router.get(
    "/open-interest",
    CryptoQuantController.getOpenInterest
);

router.get(
    "/funding-rates",
    CryptoQuantController.getFundingRates
);

export default router;