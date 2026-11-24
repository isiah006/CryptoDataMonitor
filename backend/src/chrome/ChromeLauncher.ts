import { spawn } from "child_process";
import path from "path";
import Logger from "../utils/Logger";

class ChromeLauncher {

    public async launch(): Promise<void> {

        const chrome = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
        const profileDir = path.join(__dirname, "..", "..", "..", "ChromeProfile");

        spawn(
            chrome,
            [
                "--remote-debugging-port=9222",
                `--user-data-dir=${profileDir}`,
                "about:blank"
            ],
            {
                detached: true,
                stdio: "ignore"
            }
        ).unref();

        Logger.success("Chrome launched in Remote Debugging mode.");

    }

}

export default new ChromeLauncher();