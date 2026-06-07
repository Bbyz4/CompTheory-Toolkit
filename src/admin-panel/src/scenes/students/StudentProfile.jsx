import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Paper,
  Typography,
} from '@mui/material';
import React from 'react';
import { Link, useParams } from 'react-router-dom';
import StatusBadge from '../../components/StatusBadge';
import { formatDateTime } from '../../services/formatters';
import { getUser } from '../../services/userService';

const secondaryButtonSx = {
  color: 'var(--text-h)',
  borderColor: 'var(--border)',
};

const profileJson = (user) =>
  JSON.stringify(
    {
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      verified: user.verified,
      isBanned: user.isBanned,
      banReason: user.banReason,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    },
    null,
    2,
  );

const StudentProfile = () => {
  const { id } = useParams();
  const [user, setUser] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    const loadUser = async () => {
      try {
        const nextUser = await getUser(id);

        if (!nextUser) {
          setError('User not found.');
          return;
        }

        setUser(nextUser);
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadUser();
  }, [id]);

  return (
    <div className="students">
      <Box className="task-page-header">
        <h1>Student Profile</h1>
        <Box className="task-page-actions">
          <Button component={Link} to="/students" variant="outlined" sx={secondaryButtonSx}>
            Back to students
          </Button>
        </Box>
      </Box>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-creator task-details-shell" elevation={0}>
        {loading ? (
          <Box className="task-loading-state">
            <CircularProgress size={24} />
          </Box>
        ) : user ? (
          <React.Fragment>
            <Typography variant="h4" className="task-title">
              {user.username}
            </Typography>

            <Box className="task-detail-grid">
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  User ID
                </Typography>
                <Typography variant="body1">{user.id}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Email
                </Typography>
                <Typography variant="body1">{user.email}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Role
                </Typography>
                <StatusBadge value={user.role} />
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Verified
                </Typography>
                <StatusBadge value={user.verified ? 'Yes' : 'No'} />
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Status
                </Typography>
                <StatusBadge value={user.isBanned ? 'Banned' : 'Active'} />
                {user.isBanned && user.banReason ? (
                  <Typography variant="body2" className="task-muted-copy">
                    {user.banReason}
                  </Typography>
                ) : null}
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Created
                </Typography>
                <Typography variant="body1">
                  {formatDateTime(user.createdAt)}
                </Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Updated
                </Typography>
                <Typography variant="body1">
                  {formatDateTime(user.updatedAt)}
                </Typography>
              </div>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Profile JSON
              </Typography>
              <pre className="task-detail-config">{profileJson(user)}</pre>
            </Box>
          </React.Fragment>
        ) : null}
      </Paper>
    </div>
  );
};

export default StudentProfile;
