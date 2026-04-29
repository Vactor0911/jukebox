import { Router } from "express";
import { validateBody } from "../middlewares/validation";
import { downloadSongSchema } from "../schema/song.schema";
import SongController from "../controllers/song.controller";
import { authenticate } from "../middlewares/authenticate";

const SongRouter = Router();

SongRouter.post(
  "/add",
  authenticate,
  validateBody(downloadSongSchema),
  SongController.addSong,
);

export default SongRouter;
