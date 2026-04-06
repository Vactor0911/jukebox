import { spawn } from "child_process";
import * as path from "path";
import * as fs from "fs";

export async function downloadAudio(
  url: string,
  outputDir: string = "./downloads",
): Promise<string> {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  return new Promise((resolve, reject) => {
    const args = [
      "--no-warnings",
      "--no-playlist",
      "-f",
      "bestaudio/best",
      "-x",
      "--audio-format",
      "mp3",
      "--audio-quality",
      "2",
      "--embed-thumbnail",
      "--convert-thumbnails",
      "jpg",
      "--write-thumbnail",
      "--embed-metadata",
      "--newline",
      "-o",
      path.join(outputDir, "%(title)s.%(ext)s"),
      url,
    ];

    const proc = spawn("yt-dlp", args);
    let resolvedPath = "";

    proc.stdout.on("data", (data: Buffer) => {
      const line = data.toString();

      // 진행률 출력
      const progressMatch = line.match(/\[download\]\s+([\d.]+)%/);
      if (progressMatch) {
        process.stdout.write(`\r다운로드 중... ${progressMatch[1]}%`);
      }

      // 최종 파일 경로 추출
      const destMatch =
        line.match(/\[ExtractAudio\] Destination:\s+(.+)/) ??
        line.match(/\[ffmpeg\] Destination:\s+(.+)/);
      if (destMatch) resolvedPath = destMatch[1].trim();
    });

    proc.on("close", (code) => {
      console.log(""); // 줄바꿈
      if (code !== 0) {
        reject(new Error(`yt-dlp 실패 (code ${code})`));
        return;
      }
      resolve(resolvedPath);
    });

    proc.on("error", () =>
      reject(new Error("yt-dlp를 찾을 수 없습니다. 설치 여부를 확인하세요.")),
    );
  });
}

// 실행
// const url = process.argv[2];
// if (!url) {
//   console.error("사용법: ts-node download.ts <YouTube URL>");
//   process.exit(1);
// }

// downloadAudio(url)
//   .then((filePath) => console.log(`✅ 완료: ${filePath}`))
//   .catch((err) => console.error(`❌ 오류: ${err.message}`));
