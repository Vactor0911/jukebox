import { spawn, ChildProcess } from "child_process";
import { Response } from "express";

export interface QueueItem {
  filePath: string;
  title: string;
}

export class RadioStream {
  private queue: QueueItem[] = [];
  private clients: Set<Response> = new Set();
  private currentProcess: ChildProcess | null = null;
  private currentSong: QueueItem | null = null;

  addClient(res: Response): void {
    res.setHeader("Content-Type", "audio/mpeg");
    res.setHeader("Cache-Control", "no-cache, no-store");
    res.setHeader("Connection", "keep-alive");
    res.flushHeaders();

    this.clients.add(res);
    console.log(`[Radio] 클라이언트 접속 (총 ${this.clients.size}명)`);

    res.on("close", () => {
      this.clients.delete(res);
      console.log(`[Radio] 클라이언트 종료 (총 ${this.clients.size}명)`);
    });
  }

  enqueue(filePath: string, title: string): QueueItem {
    const item: QueueItem = { filePath, title };
    this.queue.push(item);
    console.log(`[Radio] 큐 추가: ${title} (대기 ${this.queue.length}곡)`);

    if (!this.currentProcess) {
      this.playNext();
    }

    return item;
  }

  skip(): boolean {
    if (!this.currentProcess) return false;
    this.currentProcess.kill("SIGKILL");
    return true;
  }

  getStatus() {
    return {
      currentSong: this.currentSong,
      queue: [...this.queue],
      clientCount: this.clients.size,
      isPlaying: this.currentProcess !== null,
    };
  }

  private playNext(): void {
    if (this.queue.length === 0) {
      this.currentSong = null;
      this.currentProcess = null;
      console.log("[Radio] 큐가 비었습니다. 대기 중...");
      return;
    }

    const item = this.queue.shift()!;
    this.currentSong = item;
    console.log(`[Radio] 재생 시작: ${item.title}`);

    const proc = spawn("ffmpeg", [
      "-re", // 실시간 속도로 읽기 (라디오 핵심)
      "-i",
      item.filePath, // 입력 파일
      "-vn", // 비디오 스트림 제거
      "-acodec",
      "libmp3lame", // MP3 인코딩
      "-ab",
      "128k", // 비트레이트
      "-f",
      "mp3", // 출력 포맷
      "pipe:1", // stdout으로 출력
    ]);

    this.currentProcess = proc;

    proc.stdout.on("data", (chunk: Buffer) => {
      for (const client of this.clients) {
        try {
          client.write(chunk);
        } catch {
          this.clients.delete(client);
        }
      }
    });

    proc.on("close", (code) => {
      console.log(`[Radio] 재생 완료: ${item.title} (exit ${code})`);
      this.currentProcess = null;
      this.playNext();
    });

    proc.on("error", (err) => {
      console.error(`[Radio] ffmpeg 오류: ${err.message}`);
      this.currentProcess = null;
      this.playNext();
    });
  }
}
