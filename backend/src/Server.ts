import app from "./App";
import Logger from "./utils/Logger";
import { ENV } from "./config/env";
import AuthService from "./services/AuthService";
import os from "os";

function getLocalIp() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]!) {
            if (iface.family === "IPv4" && !iface.internal) {
                return iface.address;
            }
        }
    }
    return "localhost";
}

async function startServer() {

    await AuthService.initialize();

    app.listen(ENV.PORT, "0.0.0.0", () => {
        const localIp = getLocalIp();
        Logger.success(`${ENV.APP_NAME} Started`);
        Logger.info(`Local:   http://localhost:${ENV.PORT}`);
        Logger.info(`Network: http://${localIp}:${ENV.PORT}`);
    });

}

startServer();
