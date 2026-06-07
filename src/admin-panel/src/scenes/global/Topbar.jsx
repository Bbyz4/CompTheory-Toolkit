import { Button, Typography } from '@mui/material';
import { useLocation } from 'react-router-dom';

const pageTitleFromPath = (pathname) => {
  if (pathname.startsWith('/tasks/new')) {
    return 'Create Task';
  }

  if (pathname.startsWith('/tasks/') && pathname.endsWith('/edit')) {
    return 'Edit Task';
  }

  if (pathname.startsWith('/tasks/')) {
    return 'Task Details';
  }

  if (pathname.startsWith('/submissions/')) {
    return 'Submission Details';
  }

  if (pathname.startsWith('/students/')) {
    return 'Student Profile';
  }

  if (pathname.startsWith('/tasks')) {
    return 'Tasks';
  }

  if (pathname.startsWith('/submissions')) {
    return 'Submissions';
  }

  if (pathname.startsWith('/students')) {
    return 'Students';
  }

  if (pathname.startsWith('/settings')) {
    return 'Settings';
  }

  return 'Dashboard';
};

const Topbar = ({ user, onLogout }) => {
  const location = useLocation();
  const pageTitle = pageTitleFromPath(location.pathname);

  return (
    <div className="topbar">
      <div className="topbarWrapper">
        <div className="topLeft">
          <p className="topbar-kicker">Admin panel</p>
          <h2 className="topbar-title">{pageTitle}</h2>
        </div>
        <div className="topRight">
          <Typography className="topbar-user">
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
