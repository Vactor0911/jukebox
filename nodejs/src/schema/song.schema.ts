import z from "zod";

/**
 * 노래 다운로드 스키마
 */
export const downloadSongSchema = z.object({
  url: z
    .string("URL은 문자열이어야 합니다.")
    .regex(
      /^https:\/\/www\.youtube\.com\/watch\?v=[\w-]+/,
      "유효한 YouTube URL이 아닙니다.",
    ),
});
