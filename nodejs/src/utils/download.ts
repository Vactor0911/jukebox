import { spawn } from "child_process";
import * as path from "path";
import * as fs from "fs";

/**
 * YouTube URL을 받아서 오디오 파일과 썸네일을 다운로드하는 함수
 * @param url 다운로드할 YouTube URL
 * @param fileName 다운로드된 파일의 이름 (UUID로 생성)
 * @param outputDir 다운로드한 파일을 저장할 디렉토리 (기본값: "./downloads")
 * @returns 다운로드된 오디오 파일의 경로
 */
export async function downloadAudio(
  url: string,
  fileName: string,
  outputDir: string = "./downloads",
): Promise<string> {
  // 출력 디렉토리가 없으면 생성
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // filename을 UUID로 생성
  const filename = `${fileName}.%(ext)s`;

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

/**
 * YouTube URL에서 오디오 메타데이터를 추출하는 함수
 * @param url YouTube URL
 * @returns 오디오 메타데이터 객체 (재생 시간, 파일 크기, 제목, 업로더)
 */
export async function getAudioMeta(url: string): Promise<{
  duration: number;
  filesize: number | null;
  title: string;
  uploader: string;
}> {
  return new Promise((resolve, reject) => {
    const proc = spawn("yt-dlp", [
      "--no-warnings",
      "--no-playlist",
      "-f",
      "bestaudio/best",
      "--print",
      "duration",
      "--print",
      "filesize_approx",
      "--print",
      "title",
      "--print",
      "uploader",
      url,
    ]);

    let output = "";
    proc.stdout.on("data", (data: Buffer) => {
      output += data.toString();
    });

    proc.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`yt-dlp 실패 (code ${code})`));
        return;
      }
      const [durationStr, filesizeStr, title, uploader] = output
        .trim()
        .split("\n");
      resolve({
        duration: parseFloat(durationStr),
        filesize: filesizeStr === "NA" ? null : parseInt(filesizeStr),
        title,
        uploader,
      });
    });

    proc.on("error", () => reject(new Error("yt-dlp를 찾을 수 없습니다.")));
  });
}
