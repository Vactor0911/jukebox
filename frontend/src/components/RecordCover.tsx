import { Paper, Stack, type StackProps } from "@mui/material";
import Record from "./Record";

const RecordCover = (props: StackProps) => {
  const { width = 150, height = 150, ...others } = props;

  return (
    <Stack
      position="relative"
      sx={{
        cursor: "pointer",
        "&:hover .record-cover": {
          marginRight: `calc(${width}px * 0.5)`,
        },
        "&:hover .record": {
          transform: `translateX(50%) rotate(40deg)`,
        },
      }}
      {...others}
    >
      <Paper
        className="record-cover"
        elevation={3}
        square
        sx={{
          width,
          height,
          transition: "margin-right 0.25s ease-in-out",
        }}
      />
      <Stack
        className="record"
        justifyContent="center"
        alignItems="center"
        position="absolute"
        width={width}
        height={height}
        top={0}
        left={0}
        zIndex={-1}
        sx={{
          transition: "transform 0.25s ease-in-out",
        }}
      >
        <Record
          width={`calc(${width}px * 0.85)`}
          height={`calc(${height}px * 0.85)`}
          boxShadow={`0px 3px 3px -2px rgba(0, 0, 0, 0.2),
          0px 3px 4px 0px rgba(0, 0, 0, 0.14),
          0px 1px 8px 0px rgba(0, 0, 0, 0.12)`}
        />
      </Stack>
    </Stack>
  );
};

export default RecordCover;
