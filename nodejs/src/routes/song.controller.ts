import { Router } from "express";
import { validateBody } from "../middlewares/validation";
import { downloadSongSchema } from "../schema/song.schema";
import SongController from "../controllers/song.controller";

const SongRouter = Router();

SongRouter.post(
  "/add",
  validateBody(downloadSongSchema),
  SongController.addSong,
);

export default SongRouter;
