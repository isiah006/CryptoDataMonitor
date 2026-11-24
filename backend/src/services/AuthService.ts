import fs from "fs-extra";
import { CQ_SESSION, STORAGE_DIR } from "../constants/Paths";

class AuthService {

    async initialize() {

        await fs.ensureDir(STORAGE_DIR);

    }

    async hasSession(): Promise<boolean> {

        return await fs.pathExists(CQ_SESSION);

    }

    getSessionPath(): string {

        return CQ_SESSION;

    }

}

export default new AuthService();