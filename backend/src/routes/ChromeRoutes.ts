import { Router } from "express";
import ChromeController from "../controllers/ChromeController";

const router = Router();

router.get("/connect", (req, res) =>
    ChromeController.connect(req, res)
);

export default router;