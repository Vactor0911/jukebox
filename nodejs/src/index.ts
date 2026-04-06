import "dotenv/config";
import express, { Request, Response } from "express";
import cors from "cors";
import { downloadAudio } from "./download";

const app = express();

app.use(cors());
app.use(express.json());

// 헬스체크
app.get("/health", (req: Request, res: Response) => {
  res.status(200).json({
    message: "서버가 정상적으로 작동 중입니다.",
  });
});

app.post("/download", async (req: Request, res: Response) => {
  const { url, title } = req.body;
  if (!url) {
    return res.status(400).json({ error: "URL이 필요합니다." });
  }
  else if (!title) {
    return res.status(400).json({ error: "제목이 필요합니다." });
  }

  try {
    const filePath = await downloadAudio(url, process.env.DOWNLOAD_DIR);
    res.status(200).json({ message: "다운로드 성공", filePath });
  } catch (error) {
    console.error("다운로드 실패:", error);
    res.status(500).json({ error: "다운로드 실패" });
  }
});

// 정적 파일 서비스 설정
const path = process.env.DOWNLOAD_DIR || "../musics";
app.use("/musics", express.static(path));

// 서버 시작
const PORT = Number(process.env.PORT);
app.listen(PORT, () => {
  console.log(`서버가 ${PORT}번 포트에서 실행 중입니다.`);
});
