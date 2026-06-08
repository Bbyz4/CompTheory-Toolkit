import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Link as MuiLink,
  Paper,
  Table,
  TableBody,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { styled } from '@mui/material/styles';
import TableCell, { tableCellClasses } from '@mui/material/TableCell';
import React from 'react';
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom';
import { formatDateTime } from '../../services/formatters';
import { getSubmissions } from '../../services/submissionService';
import { getTasks } from '../../services/taskService';
import { banUser, getUser, unbanUser } from '../../services/userService';

const StyledTableCell = styled(TableCell)(() => ({
  [`&.${tableCellClasses.head}`]: {
    backgroundColor: 'var(--accent-dark)',
    color: 'var(--accent-contrast)',
    borderBottom: '1px solid var(--border)',
    fontWeight: 'bold',
  },
  [`&.${tableCellClasses.body}`]: {
    color: 'var(--text-h)',
    backgroundColor: 'var(--box)',
    borderBottom: '1px solid var(--border)',
  },
}));

const StyledTableRow = styled(TableRow)(() => ({
  '& td': {
    backgroundColor: 'var(--box)',
  },
  '&:hover td': {
    backgroundColor: 'var(--box-light) !important',
    transition: '0.2s',
  },
}));

const actionButtonSx = {
  backgroundColor: 'var(--accent-dark)',
  color: 'var(--accent-contrast)',
  border: '1px solid var(--border)',
  boxShadow: 'none',
  '&:hover': {
    backgroundColor: 'var(--accent)',
    boxShadow: 'none',
  },
};

const secondaryButtonSx = {
  color: 'var(--text-h)',
  borderColor: 'var(--border)',
};

const loadProfileData = async (userId) => {
  const [nextUser, allSubmissions, tasks] = await Promise.all([
    getUser(userId),
    getSubmissions(),
    getTasks(),
  ]);
  const taskLookup = new Map(tasks.map((task) => [task.id, task]));
  const nextSubmissions = allSubmissions
    .filter((submission) => submission.userId === nextUser.id)
    .map((submission) => {
      const task = taskLookup.get(submission.taskId);

      return {
        ...submission,
        taskTitle: task?.title ?? `Task #${submission.taskId}`,
        taskSlug: task?.slug ?? null,
      };
    });

  return { nextUser, nextSubmissions };
};

const UserProfile = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [user, setUser] = React.useState(null);
  const [submissions, setSubmissions] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [pendingAction, setPendingAction] = React.useState(false);
  const [error, setError] = React.useState('');

  const loadProfile = React.useCallback(async () => {
    try {
      const { nextUser, nextSubmissions } = await loadProfileData(id);
      setUser(nextUser);
      setSubmissions(nextSubmissions);
      setError('');
    } catch (nextError) {
      setError(nextError.message);
    }
  }, [id]);

  React.useEffect(() => {
    let active = true;

    const loadInitialProfile = async () => {
      setLoading(true);

      try {
        const { nextUser, nextSubmissions } = await loadProfileData(id);

        if (!active) {
          return;
        }

        setUser(nextUser);
        setSubmissions(nextSubmissions);
        setError('');
      } catch (nextError) {
        if (active) {
          setError(nextError.message);
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    loadInitialProfile();

    return () => {
      active = false;
    };
  }, [id]);

  const handleBanToggle = async () => {
    if (!user) {
      return;
    }

    setPendingAction(true);

    try {
      if (user.isBanned) {
        await unbanUser(user.id);
      } else {
        await banUser(user.id);
      }

      await loadProfile();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setPendingAction(false);
    }
  };

  const openSubmission = (submission) => {
    navigate(`/submissions/${submission.id}`);
  };

  return (
    <div className="students">
      <Box className="task-page-header">
        <h1>User Profile</h1>
        <Box className="task-page-actions">
          <Button
            component={RouterLink}
            to="/students"
            variant="outlined"
            sx={secondaryButtonSx}
          >
            Back to students
          </Button>
        </Box>
      </Box>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-creator admin-detail-shell" elevation={0}>
        {loading ? (
          <Box className="task-loading-state">
            <CircularProgress size={24} />
          </Box>
        ) : user ? (
          <React.Fragment>
            <Box className="task-inline-actions">
              <Typography variant="h4" className="profile-title">
                {user.username}
              </Typography>
              <Button
                variant={user.isBanned ? 'outlined' : 'contained'}
                color={user.isBanned ? 'success' : 'error'}
                onClick={handleBanToggle}
                disabled={pendingAction}
                sx={user.isBanned ? secondaryButtonSx : actionButtonSx}
              >
                {pendingAction ? (
                  <CircularProgress size={18} />
                ) : user.isBanned ? (
                  'Unban'
                ) : (
                  'Ban'
                )}
              </Button>
            </Box>

            <Box className="task-detail-grid">
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
                <Typography variant="body1">{user.role}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Verified
                </Typography>
                <Typography variant="body1">
                  {user.verified ? 'Yes' : 'No'}
                </Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Status
                </Typography>
                <Typography variant="body1">
                  {user.isBanned ? user.banReason || 'Banned' : 'Active'}
                </Typography>
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
          </React.Fragment>
        ) : null}
      </Paper>

      <Box className="task-detail-section">
        <Typography variant="h6" className="task-section-title">
          Recent Submissions
        </Typography>
        <TableContainer
          component={Paper}
          sx={{
            backgroundColor: 'var(--box)',
            boxShadow: 'none',
            border: '1px solid var(--border)',
            borderRadius: '8px',
          }}
        >
          <Table aria-label="user submissions table">
            <TableHead>
              <TableRow>
                <StyledTableCell>ID</StyledTableCell>
                <StyledTableCell>Task</StyledTableCell>
                <StyledTableCell>Verdict</StyledTableCell>
                <StyledTableCell>Created</StyledTableCell>
                <StyledTableCell>Judged</StyledTableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {loading ? (
                <StyledTableRow>
                  <StyledTableCell colSpan={5}>
                    <CircularProgress size={22} />
                  </StyledTableCell>
                </StyledTableRow>
              ) : submissions.length === 0 ? (
                <StyledTableRow>
                  <StyledTableCell colSpan={5}>
                    No submissions found.
                  </StyledTableCell>
                </StyledTableRow>
              ) : (
                submissions.map((submission) => (
                  <StyledTableRow
                    key={submission.id}
                    hover
                    onClick={() => openSubmission(submission)}
                    sx={{ cursor: 'pointer' }}
                  >
                    <StyledTableCell>{submission.id}</StyledTableCell>
                    <StyledTableCell>
                      {submission.taskSlug ? (
                        <MuiLink
                          component={RouterLink}
                          to={`/tasks/${submission.taskSlug}`}
                          onClick={(event) => event.stopPropagation()}
                        >
                          {submission.taskTitle}
                        </MuiLink>
                      ) : (
                        submission.taskTitle
                      )}
                    </StyledTableCell>
                    <StyledTableCell>{submission.verdict}</StyledTableCell>
                    <StyledTableCell>
                      {formatDateTime(submission.createdAt)}
                    </StyledTableCell>
                    <StyledTableCell>
                      {formatDateTime(submission.judgedAt)}
                    </StyledTableCell>
                  </StyledTableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Box>
    </div>
  );
};

export default UserProfile;
