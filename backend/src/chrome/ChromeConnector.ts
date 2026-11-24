import {
    Browser,
    BrowserContext,
    chromium,
    Page,
} from "playwright";

import Logger from "../utils/Logger";

const CDP_URL = "http://127.0.0.1:9222";

class ChromeConnector {

    private browser: Browser | null = null;
    private context: BrowserContext | null = null;
    private scraperPage: Page | null = null;

    // ============================================================
    // CHROME AVAILABILITY
    // ============================================================

    private async isChromeDebuggingAvailable(): Promise<boolean> {
        try {
            const response = await fetch(`${CDP_URL}/json/version`);
            return response.ok;
        } catch {
            return false;
        }
    }

    // ============================================================
    // PAGE HELPERS
    // ============================================================

    private isClosedPage(page: Page): boolean {
        try {
            return page.isClosed();
        } catch {
            return true;
        }
    }

    private getPageUrl(page: Page): string | null {
        try {
            return page.url();
        } catch {
            return null;
        }
    }

    private isInternalChromePage(url: string): boolean {
        if (url.startsWith("chrome://")) {
            return !this.isBlankOrNewTabPage(url);
        }
        return url.startsWith("chrome-extension://");
    }

    private isBlankOrNewTabPage(url: string): boolean {
        return (
            url === "about:blank" ||
            url.startsWith("chrome://newtab") ||
            url.startsWith("chrome://new-tab-page") ||
            url === "chrome://welcome/"
        );
    }

    private findExistingPage(pages: Page[]): Page | null {
        for (const page of pages) {
            if (this.isClosedPage(page)) continue;
            const url = this.getPageUrl(page);
            if (url?.includes("cryptoquant.com")) {
                Logger.info("Using existing CryptoQuant page.");
                return page;
            }
        }

        for (const page of pages) {
            if (this.isClosedPage(page)) continue;
            const url = this.getPageUrl(page);
            if (!url || this.isInternalChromePage(url)) continue;
            Logger.info("Using existing Chrome page.");
            return page;
        }

        for (const page of pages) {
            if (this.isClosedPage(page)) continue;
            const url = this.getPageUrl(page);
            if (url && this.isBlankOrNewTabPage(url)) {
                Logger.info("Using blank/new-tab Chrome page.");
                return page;
            }
        }

        return null;
    }

    private async createPage(context: BrowserContext): Promise<Page> {
        Logger.info("Creating a new Chromium tab...");
        const page = await context.newPage();
        Logger.success("Created new Chromium tab for scraping.");
        return page;
    }

    // ============================================================
    // CONNECT (CDP or Headless Standalone Fallback)
    // ============================================================

    public async connect(): Promise<void> {
        if (this.browser && this.context) {
            try {
                const contexts = this.browser.contexts();
                if (contexts.length > 0) {
                    this.context = contexts[0];
                    return;
                }
            } catch {
                this.browser = null;
                this.context = null;
                this.scraperPage = null;
            }
        }

        // 1. Try local Chrome CDP debugging if available (Local Laptop Mode)
        if (await this.isChromeDebuggingAvailable()) {
            try {
                Logger.info("Connecting to local Chrome via CDP...");
                this.browser = await chromium.connectOverCDP(CDP_URL);
                const contexts = this.browser.contexts();
                if (contexts.length > 0) {
                    this.context = contexts[0];
                    Logger.success("Connected to local Chrome via CDP.");
                    return;
                }
            } catch {
                Logger.warning("CDP connection failed. Fallback to standalone Chromium.");
            }
        }

        // 2. Launch standalone Chromium instance (24/7 Cloud Mode / Headless)
        try {
            Logger.info("Launching standalone Chromium instance for Cloud Environment...");
            this.browser = await chromium.launch({
                headless: process.env.HEADLESS !== "false",
                args: [
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-gpu"
                ]
            });
            this.context = await this.browser.newContext({
                userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            });
            Logger.success("Launched standalone Cloud Chromium instance.");
            return;
        } catch (error) {
            Logger.error(`Failed to launch Chromium: ${String(error)}`);
            throw error;
        }
    }

    // ============================================================
    // GET PAGE
    // ============================================================

    public async getPage(): Promise<Page> {
        await this.connect();

        if (this.scraperPage && !this.isClosedPage(this.scraperPage)) {
            return this.scraperPage;
        }

        if (!this.browser) {
            throw new Error("Chromium browser is unavailable.");
        }

        const contexts = this.browser.contexts();
        if (contexts.length === 0) {
            throw new Error("Chromium browser context is unavailable.");
        }

        const context = contexts[0];
        this.context = context;

        let page: Page | null = null;
        const pages = context.pages();

        if (pages.length > 0) {
            page = this.findExistingPage(pages);
        }

        if (!page) {
            page = await this.createPage(context);
        }

        this.scraperPage = page;
        return page;
    }

    // ============================================================
    // DISCONNECT
    // ============================================================

    public async disconnect(): Promise<void> {
        if (this.browser) {
            try {
                await this.browser.close();
            } catch {}
        }
        this.browser = null;
        this.context = null;
        this.scraperPage = null;

        Logger.warning("Disconnected from Chromium browser.");
    }

    // ============================================================
    // STATUS
    // ============================================================

    public isConnected(): boolean {
        if (!this.browser || !this.context) return false;
        try {
            return this.browser.contexts().length > 0;
        } catch {
            return false;
        }
    }
}

export default new ChromeConnector();
