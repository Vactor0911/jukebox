import { Box, type BoxProps } from "@mui/material";
import RecordImage from "../assets/record.png";

interface RecordProps extends BoxProps {
  imageSrc?: string;
  bgcolor?: string;
}

const Record = (props: RecordProps) => {
  const {
    width = 120,
    height = 120,
    imageSrc,
    bgcolor = "red",
    ...others
  } = props;

  return (
    <Box
      width={width}
      height={height}
      position="relative"
      borderRadius="50%"
      {...others}
    >
      <Box
        component="img"
        src={RecordImage}
        width="100%"
        height="100%"
        position="relative"
        zIndex={2}
      />
      <Box
        position="absolute"
        top="50%"
        left="50%"
        width="35%"
        height="35%"
        bgcolor={bgcolor}
        borderRadius="50%"
        sx={{
          transform: "translate(-50%, -50%)",
          WebkitMask:
            "radial-gradient(circle at 50% 50%, transparent 10%, black 10%)",
          mask: "radial-gradient(circle at 50% 50%, transparent 10%, black 10%)",
          backgroundImage: imageSrc ? `url(${imageSrc})` : undefined,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />
      <Box
        position="absolute"
        top="50%"
        left="50%"
        width="15%"
        height="15%"
        border="2px solid rgba(0, 0, 0, 0.25)"
        borderRadius="50%"
        sx={{
          transform: "translate(-50%, -50%)",
        }}
      />
    </Box>
  );
};

export default Record;
