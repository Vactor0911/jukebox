import { BrowserRouter, Route, Routes } from "react-router";
import { Home } from "./pages";
import { CssBaseline, ThemeProvider } from "@mui/material";
import { theme } from "./utils/theme";
import Header from "./components/Header";

const App = () => {
  return (
    <ThemeProvider theme={theme}>
      <BrowserRouter basename="jukebox">
        <CssBaseline />
        <Header />
        
        <Routes>
          <Route path="/" element={<Home />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
};

export default App;
