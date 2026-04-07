import "dotenv/config";
import express, { Request, Response } from "express";
import cors from "cors";
import * as path from "path";
import * as fs from "fs";
import { downloadAudio } from "./download";
import { RadioStream } from "./radio";

const app = express();
const radio = new RadioStream();

app.use(cors());
app.use(express.json());

// 헬스체크
app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ message: "서버가 정상적으로 작동 중입니다." });
});

// 음악 다운로드 (enqueue=true 시 큐에 자동 추가)
app.post("/download", async (req: Request, res: Response) => {
  const { url, title, enqueue } = req.body;
  if (!url) return res.status(400).json({ error: "URL이 필요합니다." });
  if (!title) return res.status(400).json({ error: "제목이 필요합니다." });

  try {
    const filePath = await downloadAudio(url, process.env.DOWNLOAD_DIR);
    const result: Record<string, unknown> = { message: "다운로드 성공", filePath };

    if (enqueue) {
      const item = radio.enqueue(filePath, title);
      result.queued = item;
    }

    res.status(200).json(result);
  } catch (error) {
    console.error("다운로드 실패:", error);
    res.status(500).json({ error: "다운로드 실패" });
  }
});

// 라디오 스트림 (bass.loadURL이 접속하는 엔드포인트)
app.get("/stream", (_req: Request, res: Response) => {
  radio.addClient(res);
});

// 큐에 이미 다운로드된 곡 추가
app.post("/queue/add", (req: Request, res: Response) => {
  const { filename, title } = req.body;
  if (!filename) return res.status(400).json({ error: "filename이 필요합니다." });
  if (!title) return res.status(400).json({ error: "title이 필요합니다." });

  const musicDir = process.env.DOWNLOAD_DIR || "../musics";
  const filePath = path.join(musicDir, filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: `파일을 찾을 수 없습니다: ${filename}` });
  }

  const item = radio.enqueue(filePath, title);
  res.status(200).json({ message: "큐에 추가되었습니다.", item });
});

// 현재 큐 상태 조회
app.get("/queue", (_req: Request, res: Response) => {
  res.status(200).json(radio.getStatus());
});

// 현재 곡 스킵
app.post("/queue/skip", (_req: Request, res: Response) => {
  const skipped = radio.skip();
  if (skipped) {
    res.status(200).json({ message: "스킵했습니다." });
  } else {
    res.status(400).json({ error: "재생 중인 곡이 없습니다." });
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
