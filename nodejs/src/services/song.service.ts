import { mariaDB } from "../config/mariadb";
import { BadRequestError, InternalServerError } from "../errors/CustomErrors";
import { SongModel } from "../models/song.model";
import { extractYoutubeVideoId } from "../utils";
import { downloadAudio, getAudioMeta } from "../utils/download";
import TransactionHandler from "../utils/transactionHandler";
import { v4 as uuidv4 } from "uuid";

class SongService {
  /**
   * Youtube URL을 받아서 오디오 파일과 썸네일을 다운로드하는 함수
   * @param url 다운로드할 Youtube URL
   */
  static async addSong(url: string) {
    const song = await TransactionHandler.executeInTransaction(
      mariaDB,
      async (connection) => {
        // URL 검증
        if (!url) {
          throw new BadRequestError("URL이 필요합니다.");
        }

        // URL에서 video ID 추출
        const videoId = extractYoutubeVideoId(url);
        console.log("추출된 video ID:", videoId);
        if (!videoId) {
          throw new BadRequestError("유효한 YouTube URL이 아닙니다.");
        }

        // 데이터베이스에서 노래가 이미 존재하는지 조회
        const song = await SongModel.findSongByVideoId(videoId, connection);

        // 이미 존재하는 노래인 경우 기존 데이터 반환
        if (song && song.videoId === videoId) {
          // 기존 노래 재생 일자 업데이트
          const newDate = new Date();
          await SongModel.updateLastPlayedAt(song.uuid, newDate, connection);
          song.last_played_at = newDate;

          return song;
        }

        // 오디오 메타데이터 추출
        let metadata;
        try {
          metadata = await getAudioMeta(url);
        } catch (error) {
          console.error("메타데이터 추출 실패:", error);
          throw new InternalServerError(
            "오디오 메타데이터 추출 중 오류가 발생했습니다.",
          );
        }
        console.log("메타데이터:", metadata);

        // 길이 제한
        if (metadata.duration > Number(process.env.MAX_LENGTH)) {
          throw new BadRequestError(
            "재생 시간이 너무 깁니다. 최대 길이는 5분입니다.",
          );
        }

        // 파일 크기 제한
        if (
          metadata.filesize !== null &&
          metadata.filesize > Number(process.env.MAX_FILE_SIZE)
        ) {
          throw new BadRequestError(
            "파일 크기가 너무 큽니다. 최대 크기는 10MB입니다.",
          );
        }

        // Youtube URL로 오디오 및 썸네일 다운로드
        let filePath;
        const fileName = uuidv4();
        try {
          filePath = await downloadAudio(
            url,
            fileName,
            process.env.DOWNLOAD_DIR,
          );
        } catch (error) {
          console.error("다운로드 실패:", error);
          throw new InternalServerError(
            "다운로드 중 오류가 발생했습니다. 다시 시도해주세요.",
          );
        }

        // 다운로드된 파일 경로 로그
        const newSong = await SongModel.createSong(
          fileName,
          metadata.title,
          metadata.uploader,
          videoId,
          connection,
        );
        console.log("생성된 노래 데이터:", newSong);

        // 노래 겍체 반환
        return newSong;
      },
    );

    // 노래 겍체 반환
    return song;
  }
}

export default SongService;
