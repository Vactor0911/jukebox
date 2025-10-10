import {
  AppBar,
  Avatar,
  Box,
  ButtonBase,
  Toolbar,
  Typography,
} from "@mui/material";
import { useState } from "react";
import ProfileImage from "../assets/profileImage.png";

const Header = () => {
  const [profileImage] = useState<string | undefined>(ProfileImage);

  return (
    <AppBar
      position="static"
      color="primary"
      variant="outlined"
      enableColorOnDark
    >
      <Toolbar
        sx={{
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        {/* 로고 */}
        <Box>
          <Typography variant="h4">Jukebox</Typography>
        </Box>

        {/* 프로필 버튼 */}
        <ButtonBase
          sx={{
            borderRadius: "50%",
          }}
        >
          <Avatar src={profileImage} />
        </ButtonBase>
      </Toolbar>
    </AppBar>
  );
};

export default Header;
