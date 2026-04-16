import { Pool, PoolConnection } from "mysql2/promise";

export class ApiKeyModel {
  uuid: string;
  owner_name: string;
  owner_steamid64: string;
  created_at: Date;
  status: "active" | "disabled";

  constructor(data: any) {
    this.uuid = data.uuid || "";
    this.owner_name = data.owner_name || "";
    this.owner_steamid64 = data.owner_steamid64 || "";
    this.created_at = data.created_at || new Date();
    this.status = data.status || "active";
  }

  /**
   * API 키 uuid로 API 키 데이터 조회
   * @param uuid API 키 uuid
   * @param connection 데이터베이스 연결 객체
   * @returns 조회된 API 키 모델 객체
   */
  static async findByUuid(uuid: string, connection: PoolConnection | Pool) {
    const [key] = await connection.execute(
      `
        SELECT key_uuid, owner_name, owner_steamid64, created_at, status
        FROM api_keys
        WHERE key_uuid = ?
      `,
      [uuid],
    );

    if (!(key as any[])[0]) {
      return null;
    }

    const formattedKey = this.formatApiKeyData((key as any[])[0]);
    return formattedKey;
  }

  /**
   * API 키 데이터 포맷팅
   * @param data API 키 데이터 객체
   * @returns 포맷팅된 API 키 모델 객체
   */
  private static formatApiKeyData(data: any) {
    return new ApiKeyModel({
      uuid: data.key_uuid,
      owner_name: data.owner_name,
      owner_steamid64: data.owner_steamid64,
      created_at: data.created_at,
      status: data.status,
    });
  }
}
