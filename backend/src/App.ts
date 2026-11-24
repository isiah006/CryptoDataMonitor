import express from "express";
import cors from "cors";

import cryptoquantRoutes from "./routes/cryptoquant.routes";
import chromeRoutes from "./routes/ChromeRoutes";
import authRoutes from "./routes/AuthRoutes";

const app = express();

console.log("🔥🔥🔥 APP.TS LOADED 🔥🔥🔥");

app.use(cors());
app.use(express.json());

console.log("🔥🔥🔥 REGISTERING CRYPTOQUANT ROUTES 🔥🔥🔥");

app.use("/cryptoquant", cryptoquantRoutes);
app.use("/chrome", chromeRoutes);
app.use("/auth", authRoutes);

app.get("/", (req, res) => {
    res.send("Crypto Data Monitor API is Running! (VERSION_V3_ACTIVE)");
});

app.get("/health", (req, res) => {
    res.status(200).json({
        success: true,
        message: "Server is healthy.",
        timestamp: new Date().toISOString()
    });
});

export default app;