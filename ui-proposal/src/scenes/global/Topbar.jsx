import { Box, IconButton, useTheme } from "@mui/material"
import { useContext } from "react"

const Topbar = () => {
  return (
    <div className="topbar">
      <div className="topbarWrapper">
        <div className="topLeft">
          {/* <span className="logo">Admin Panel</span> */}
        </div>
        <div className="topRight">
          {/* User icon or info */}
        </div>
      </div>
    </div>
  );
};

export default Topbar;