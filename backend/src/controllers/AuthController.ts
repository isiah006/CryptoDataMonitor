import { Request, Response } from "express";
import chromeConnector from "../chrome/ChromeConnector";
import { CQ_SESSION } from "../constants/Paths";


class AuthController {


    public async open(req: Request, res: Response): Promise<void> {

        try {


            await chromeConnector.connect();


            const page =
                await chromeConnector.getPage();



            await page.goto(
                "https://cryptoquant.com",
                {
                    waitUntil: "domcontentloaded"
                }
            );



            res.json({

                success:true,

                message:"CryptoQuant opened."

            });



        } catch(error) {


            res.status(500).json({

                success:false,

                message:String(error)

            });


        }

    }




    public async saveSession(req: Request, res: Response): Promise<void> {

        try {


            await chromeConnector.connect();


            const page =
                await chromeConnector.getPage();



            console.log("");
            console.log("=======================================");
            console.log("Login using Google.");
            console.log("After login press ENTER here.");
            console.log("=======================================");



            process.stdin.resume();



            process.stdin.once(
                "data",
                async()=>{


                    await page
                        .context()
                        .storageState({
                            path:CQ_SESSION
                        });



                    res.json({

                        success:true,

                        message:"Session saved successfully."

                    });


                }
            );



        } catch(error){


            res.status(500).json({

                success:false,

                message:String(error)

            });


        }

    }


}


export default new AuthController();