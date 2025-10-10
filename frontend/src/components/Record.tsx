import { Box } from "@mui/material";
import RecordImage from "../assets/record.png";

interface RecordProps {
  width?: string | number;
  height?: string | number;
  imageSrc?: string;
}

const Record = (props: RecordProps) => {
  const { width = 120, height = 120, imageSrc } = props;

  return (
    <Box width={width} height={height} position="relative">
      <Box component="img" src={RecordImage} width="100%" height="100%" />
      <Box
        position="absolute"
        top="50%"
        left="50%"
        width="34%"
        height="34%"
        bgcolor="red"
        borderRadius="50%"
        zIndex={-1}
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
