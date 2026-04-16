import { Request, Response } from "express";
import SongService from "../services/song.service";
import { asyncHandler } from "../utils/asyncHandler";
import { APIResponse } from "../types";

class SongController {
  /**
   * Youtube URL로 오디오 및 썸네일 다운로드
   */
  static addSong = asyncHandler(
    async (req: Request, res: Response<APIResponse>) => {
      const { url } = req.body;

      // Youtube URL로 오디오 및 썸네일 다운로드
      const song = await SongService.addSong(url);

      // 다운로드 결과 반환
      res.json({
        success: true,
        message: "노래가 성공적으로 등록되었습니다.",
        data: { song },
      });
    },
  );
}

export default SongController;
