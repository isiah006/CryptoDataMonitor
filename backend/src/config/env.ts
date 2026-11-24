import dotenv from "dotenv";

dotenv.config();

export const ENV = {

    PORT: Number(process.env.PORT) || 3000,

    HEADLESS: process.env.HEADLESS === "true",

    TIMEOUT: Number(process.env.TIMEOUT) || 60000,

    APP_NAME: process.env.APP_NAME || "Crypto Data Monitor"

};