import "dotenv/config";
import express, { Request, Response } from "express";
import cors from "cors";
import * as path from "path";
import * as fs from "fs";
import { downloadAudio } from "./download";

const app = express();

app.use(cors());
app.use(express.json());

// 헬스체크
app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ message: "서버가 정상적으로 작동 중입니다." });
});

// 음악 다운로드 (enqueue=true 시 큐에 자동 추가)
app.post("/download", async (req: Request, res: Response) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: "URL이 필요합니다." });

  try {
    const filePath = await downloadAudio(url, process.env.DOWNLOAD_DIR);
    const result: Record<string, unknown> = { message: "다운로드 성공", filePath };

    res.status(200).json(result);
  } catch (error) {
    console.error("다운로드 실패:", error);
    res.status(500).json({ error: "다운로드 실패" });
  }
});

// 정적 파일 서비스
const musicDir = process.env.DOWNLOAD_DIR || "../musics";
app.use("/musics", express.static(musicDir));

// 서버 시작
const PORT = Number(process.env.PORT);
app.listen(PORT, () => {
  console.log(`서버가 ${PORT}번 포트에서 실행 중입니다.`);
});
