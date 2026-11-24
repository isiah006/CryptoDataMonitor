class Logger {

    info(message: string) {

        console.log(`ℹ️ ${message}`);

    }

    success(message: string) {

        console.log(`✅ ${message}`);

    }

    warning(message: string) {

        console.log(`⚠️ ${message}`);

    }

    error(message: string) {

        console.error(`❌ ${message}`);

    }

}

export default new Logger();