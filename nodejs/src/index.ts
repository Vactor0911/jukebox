import "dotenv/config";
import express, { Request, Response } from "express";

const app = express();

app.use(express.json());

// 헬스체크
app.get("/health", (req: Request, res: Response) => {
  res.status(200).json({
    message: "서버가 정상적으로 작동 중입니다.",
  });
});

// 서버 시작
const PORT = Number(process.env.PORT);
app.listen(PORT, () => {
  console.log(`서버가 ${PORT}번 포트에서 실행 중입니다.`);
});
