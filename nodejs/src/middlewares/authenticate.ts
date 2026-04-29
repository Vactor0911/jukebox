import { NextFunction, Request, Response } from "express";
import { ApiKeyModel } from "../models/apikey.model";
import { mariaDB } from "../config/mariadb";

/**
 * API 키 인증 미들웨어
 * @param req Express 요청 객체
 * @param res Express 응답 객체
 * @param next 다음 미들웨어로 넘어가는 함수
 * @returns 인증 결과에 따라 401 또는 403 응답, 인증 성공 시 다음 미들웨어로 진행
 */
export const authenticate = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const authHeader = req.headers.authorization; // Authorization 헤더 확인
  if (!authHeader) {
    res.status(403).json({
      success: false,
      message: "API 키가 올바르지 않습니다.",
    });
    return;
  }

  const auth = authHeader.split(" ")[1]; // "Bearer <API_KEY>" 형식에서 API 키 추출
  if (!auth || auth.slice(0, 6) !== "sk-jk-") {
    res.status(403).json({
      success: false,
      message: "API 키가 올바르지 않습니다.",
    });
    return;
  }

  const isKeyValid = ApiKeyModel.findByUuid(auth.slice(6), mariaDB); // API 키 조회
  if (!isKeyValid) {
    console.log("유효하지 않은 API키:", authHeader);
    res.status(403).json({
      success: false,
      message: "API 키가 올바르지 않습니다.",
    });
    return;
  }

  // API 키가 유효한 경우, 요청 처리 계속 진행
  next();
};
