import fs from "fs-extra";
import path from "path";
import Logger from "../utils/Logger";

const STORAGE_DIR = path.join(process.cwd(), "storage");
const CACHE_FILE = path.join(STORAGE_DIR, "last_successful_fetch.json");

class PersistenceService {
    constructor() {
        this.ensureStorageExists();
    }

    private async ensureStorageExists() {
        try {
            await fs.ensureDir(STORAGE_DIR);
        } catch (error) {
            Logger.error("Failed to create storage directory");
        }
    }

    public async saveCache(data: any): Promise<void> {
        try {
            await fs.writeJson(CACHE_FILE, {
                ...data,
                persistedAt: new Date().toISOString()
            }, { spaces: 2 });
            Logger.success("Market data saved to backend storage.");
        } catch (error) {
            Logger.error("Failed to save market data to storage.");
        }
    }

    public async loadCache(): Promise<any | null> {
        try {
            if (await fs.pathExists(CACHE_FILE)) {
                return await fs.readJson(CACHE_FILE);
            }
        } catch (error) {
            Logger.error("Failed to load market data from storage.");
        }
        return null;
    }

    public async clearCache(): Promise<void> {
        try {
            await fs.remove(CACHE_FILE);
            Logger.warning("Backend storage cleared.");
        } catch (error) {
            Logger.error("Failed to clear backend storage.");
        }
    }
}

export default new PersistenceService();
