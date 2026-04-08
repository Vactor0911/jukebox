import "dotenv/config";
import express, { Request, Response } from "express";
import cors from "cors";
import SongRouter from "./routes/song.controller";
import { errorHandler } from "./middlewares/errorHandler";

const app = express();

app.use(cors());
app.use(express.json());

// 헬스체크
app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ message: "서버가 정상적으로 작동 중입니다." });
});

// 라우트 정의
app.use("/song", SongRouter);

// 전역 오류 처리 미들웨어 등록
app.use(errorHandler);

// 정적 파일 서비스
const musicDir = process.env.DOWNLOAD_DIR || "../musics";
app.use("/musics", express.static(musicDir));

// 서버 시작
const PORT = Number(process.env.PORT);
app.listen(PORT, () => {
  console.log(`서버가 ${PORT}번 포트에서 실행 중입니다.`);
});
