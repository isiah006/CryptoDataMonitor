import fs from "fs-extra";
import path from "path";
import Logger from "../utils/Logger";

const STORAGE_DIR = path.join(process.cwd(), "storage");

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

    private getCachePath(deviceId?: string): string {
        const cleanId = (deviceId || "default_device").replace(/[^a-zA-Z0-9_-]/g, "_");
        return path.join(STORAGE_DIR, `cache_${cleanId}.json`);
    }

    public async saveCache(data: any, deviceId?: string): Promise<void> {
        try {
            const file = this.getCachePath(deviceId);
            await fs.writeJson(file, {
                ...data,
                persistedAt: new Date().toISOString()
            }, { spaces: 2 });
            Logger.success(`Market data saved for device: ${deviceId || "default"}`);
        } catch (error) {
            Logger.error(`Failed to save market data for device: ${deviceId || "default"}`);
        }
    }

    public async loadCache(deviceId?: string): Promise<any | null> {
        try {
            const file = this.getCachePath(deviceId);
            if (await fs.pathExists(file)) {
                return await fs.readJson(file);
            }
        } catch (error) {
            Logger.error(`Failed to load market data for device: ${deviceId || "default"}`);
        }
        return null;
    }

    public async clearCache(deviceId?: string): Promise<void> {
        try {
            const file = this.getCachePath(deviceId);
            await fs.remove(file);
            Logger.warning(`Backend storage cleared for device: ${deviceId || "default"}`);
        } catch (error) {
            Logger.error(`Failed to clear backend storage for device: ${deviceId || "default"}`);
        }
    }
}

export default new PersistenceService();
