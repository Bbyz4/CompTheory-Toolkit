import { Button, Typography } from '@mui/material';

const Topbar = ({ user, onLogout }) => {
  return (
    <div className="topbar">
      <div className="topbarWrapper">
        <div className="topLeft">
        </div>
        <div className="topRight">
          <Typography sx={{ color: 'var(--text)', mr: 2 }}>
            {user?.username}
          </Typography>
          <Button
            variant="outlined"
            onClick={onLogout}
            sx={{
              color: 'var(--text)',
              borderColor: 'var(--border)',
            }}
          >
            Logout
          </Button>
        </div>
      </div>
    </div>
  );
};

export default Topbar;
