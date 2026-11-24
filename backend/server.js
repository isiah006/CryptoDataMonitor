const express = require("express");
const cors = require("cors");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
    res.send("Crypto Data Monitor API Running!");
});

app.get("/health", (req, res) => {
    res.json({
        status: "OK",
        message: "Server is running"
    });
});

const PORT = 3000;

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});