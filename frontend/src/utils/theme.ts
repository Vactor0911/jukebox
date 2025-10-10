import { createTheme, responsiveFontSizes } from "@mui/material";

// MUI 테마
export const theme = responsiveFontSizes(
  createTheme({
    palette: {
      primary: {
        main: "#273F4F",
        light: "#447D9B",
      },
      secondary: {
        main: "#FE7743",
      },
      text: {
        primary: "#404040",
        secondary: "#787878",
      },
      background: {
        default: "#F7F7F7",
      },
    },
    typography: {
      fontFamily: ["Noto Sans KR", "sans-serif"].join(","),
      h1: {
        fontWeight: 700,
      },
      h2: {
        fontWeight: 700,
      },
      h3: {
        fontWeight: 700,
      },
      h4: {
        fontWeight: 700,
      },
      h5: {
        fontWeight: 700,
      },
      h6: {
        fontWeight: 700,
      },
    },
  })
);
