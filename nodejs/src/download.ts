import { spawn } from "child_process";
import * as path from "path";
import * as fs from "fs";
import { v4 as uuidv4 } from "uuid";

export async function downloadAudio(
  url: string,
  outputDir: string = "./downloads",
): Promise<string> {
  // 출력 디렉토리가 없으면 생성
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // filename을 UUID로 생성
  const filename = `${uuidv4()}.%(ext)s`;

  // yt-dlp 명령어 인자 설정
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
    // TODO: 제목을 UUID로 저장하도록 변경 (제목에 따라 파일명이 달라지는 문제 해결)
    path.join(outputDir, filename),
    url,
  ];

  // yt-dlp 프로세스 실행
  const proc = spawn("yt-dlp", args);
  let resolvedPath = "";

  // spawn 실패(ENOENT 등) 감지
  const spawnError = new Promise<never>((_, reject) => {
    proc.on("error", () =>
      reject(new Error("yt-dlp를 찾을 수 없습니다. 설치 여부를 확인하세요.")),
    );
  });

  // stdout을 async iterable로 처리
  const readStdout = async () => {
    for await (const chunk of proc.stdout as AsyncIterable<Buffer>) {
      const line = chunk.toString();

      // 최종 파일 경로 추출
      const destMatch =
        line.match(/\[ExtractAudio\] Destination:\s+(.+)/) ??
        line.match(/\[ffmpeg\] Destination:\s+(.+)/);
      if (destMatch) resolvedPath = destMatch[1].trim();
    }
  };

  // 음악 & 썸네일 다운로드 시작
  console.log("다운로드 시작...");
  await Promise.race([readStdout(), spawnError]);

  // 프로세스 종료 대기
  const code = await new Promise<number | null>((resolve) => {
    proc.on("close", resolve);
  });

  // yt-dlp 실패 감지
  if (code !== 0) {
    console.log("다운로드 실패");
    throw new Error(`yt-dlp 실패 (code ${code})`);
  }

  // 다운로드 완료
  console.log(`다운로드 완료: ${resolvedPath}`);
  return resolvedPath;
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
