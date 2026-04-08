/**
 * YouTube URL에서 video ID를 추출하는 함수
 * @param url YouTube URL
 * @returns video ID 또는 null
 */
export const extractYoutubeVideoId = (url: string): string | null => {
  // YouTube URL 패턴 검증
  const youtubeRegex = /^https:\/\/www\.youtube\.com\/watch\?v=([\w-]+)/;
  if (!youtubeRegex.test(url)) {
    return null;
  }

  // URL에서 video ID 추출
  const { searchParams } = new URL(url);
  return searchParams.get("v");
};
