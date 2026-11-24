import { Router } from "express";
import AuthController from "../controllers/AuthController";

const router = Router();

router.get("/open", (req, res) =>
    AuthController.open(req, res)
);
router.get("/save", (req, res) =>
    AuthController.saveSession(req, res)
);

export default router;