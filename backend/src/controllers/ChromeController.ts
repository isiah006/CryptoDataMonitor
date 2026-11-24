import { Request, Response } from "express";
import ChromeConnector from "../chrome/ChromeConnector";

class ChromeController {

    public async connect(req: Request, res: Response): Promise<void> {

        try {

            await ChromeConnector.connect();

            res.json({
                success: true,
                message: "Connected to Chrome."
            });

        } catch (error) {

            res.status(500).json({
                success: false,
                message: String(error)
            });

        }

    }

}

export default new ChromeController();