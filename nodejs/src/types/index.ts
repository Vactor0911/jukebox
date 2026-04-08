/**
 * API 응답 인터페이스
 */
export interface APIResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
}
