import { Pool, PoolConnection } from "mysql2/promise";

export class LogModel {
  uuid: string;
  detail: string;
  apikey_id: string;
  created_at: Date;

  constructor(data: any) {
    this.uuid = data.uuid || "";
    this.detail = data.detail || "";
    this.apikey_id = data.apikey_id || "";
    this.created_at = data.created_at || new Date();
  }

  /**
   * 로그 데이터 생성
   * @param logUuid 로그 uuid
   * @param detail 로그 상세 내용
   * @param apikeyId 로그와 연관된 API 키 ID
   * @param connection 데이터베이스 연결 객체
   * @returns 생성된 로그 모델 객체
   */
  static async create(
    logUuid: string,
    detail: string,
    apikeyId: string,
    connection: PoolConnection | Pool,
  ) {
    const date = new Date();
    await connection.execute(
      `
        INSERT INTO logs (log_uuid, detail, apikey_id, created_at)
        VALUES (?, ?, ?, ?)
      `,
      [logUuid, detail, apikeyId, date],
    );

    return this.formatLogData({
      log_uuid: logUuid,
      detail: detail,
      apikey_id: apikeyId,
      created_at: date,
    });
  }

  /**
   * 로그 데이터 포맷팅
   * @param data 로그 데이터 객체
   * @returns 포맷팅된 로그 모델 객체
   */
  private static formatLogData(data: any) {
    return new LogModel({
      uuid: data.log_uuid,
      detail: data.detail,
      apikey_id: data.apikey_id,
      created_at: data.created_at,
    });
  }
}
