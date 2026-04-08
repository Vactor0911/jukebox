import { Pool, PoolConnection } from "mysql2/promise";

export class SongModel {
  uuid: string;
  title: string;
  uploader: string;
  videoId: string;
  last_played_at: Date | null;

  constructor(data: any) {
    this.uuid = data.uuid || "";
    this.title = data.title || "";
    this.uploader = data.uploader || "";
    this.videoId = data.videoId || "";
    this.last_played_at = data.last_played_at || new Date();
  }

  /**
   * 노래 데이터 생성
   * @param songUuid 노래 uuid
   * @param title 노래 제목
   * @param uploader 노래 업로더
   * @param videoId 노래의 YouTube video ID
   * @param connection 데이터베이스 연결 객체
   * @returns 생성된 노래 모델
   */
  static async createSong(
    songUuid: string,
    title: string,
    uploader: string,
    videoId: string,
    connection: PoolConnection | Pool,
  ) {
    await connection.execute(
      `
        INSERT INTO songs (song_uuid, title, uploader, video_id)
        VALUES (?, ?, ?, ?)
      `,
      [songUuid, title, uploader, videoId],
    );

    return this.formatSongData({
      song_uuid: songUuid,
      title,
      uploader,
      video_id: videoId,
      last_played_at: null,
    });
  }

  /**
   * 노래 uuid로 노래 데이터 조회
   * @param uuid 노래 uuid
   * @param connection 데이터베이스 연결 객체
   * @returns 조회된 노래 모델 배열
   */
  static async findSongByUuid(uuid: string, connection: PoolConnection | Pool) {
    const [songs] = await connection.execute(
      `
        SELECT song_uuid, title, uploader, video_id, last_played_at
        FROM songs
        WHERE song_uuid = ?
      `,
      [uuid],
    );

    if (!songs) {
      return [];
    }

    return (songs as any[]).map(this.formatSongData);
  }

  /**
   * YouTube video ID로 노래 데이터 조회
   * @param videoId YouTube video ID
   * @param connection 데이터베이스 연결 객체
   * @returns 조회된 노래 모델 배열
   */
  static async findSongByVideoId(
    videoId: string,
    connection: PoolConnection | Pool,
  ) {
    const [songs] = await connection.execute(
      `
        SELECT song_uuid, title, uploader, video_id, last_played_at
        FROM songs
        WHERE video_id = ?
      `,
      [videoId],
    );

    if (!songs) {
      return [];
    }

    return (songs as any[]).map(this.formatSongData);
  }

  /**
   * 노래의 마지막 재생 시간 업데이트
   * @param songUuid 노래 uuid
   * @param connection 데이터베이스 연결 객체
   */
  static async updateLastPlayedAt(
    songUuid: string,
    newDate: Date,
    connection: PoolConnection | Pool,
  ) {
    await connection.execute(
      `
        UPDATE songs
        SET last_played_at = ?
        WHERE song_uuid = ?
      `,
      [newDate, songUuid],
    );
  }

  /**
   * 노래 데이터 포맷팅
   * @param data 노래 데이터
   * @returns 노래 모델
   */
  private static formatSongData(data: any) {
    if (!data) {
      return null;
    }

    return new SongModel({
      uuid: data.song_uuid,
      title: data.title,
      uploader: data.uploader,
      videoId: data.video_id,
      last_played_at: data.last_played_at,
    });
  }
}
