import path from "path";

export const STORAGE_DIR = path.join(process.cwd(), "storage");

export const CQ_SESSION = path.join(
    STORAGE_DIR,
    "cryptoquant-session.json");