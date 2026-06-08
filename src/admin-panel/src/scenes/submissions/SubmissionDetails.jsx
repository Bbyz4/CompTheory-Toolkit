import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Link as MuiLink,
  Paper,
  Typography,
} from '@mui/material';
import React from 'react';
import { Link as RouterLink, useParams } from 'react-router-dom';
import { formatDateTime } from '../../services/formatters';
import { getSubmission } from '../../services/submissionService';
import { getTasks } from '../../services/taskService';
import { getUser } from '../../services/userService';

const secondaryButtonSx = {
  color: 'var(--text-h)',
  borderColor: 'var(--border)',
};

const jsonText = (value) => {
  if (value === null || value === undefined) {
    return 'N/A';
  }

  return JSON.stringify(value, null, 2);
};

const SubmissionDetails = () => {
  const { id } = useParams();
  const [submission, setSubmission] = React.useState(null);
  const [task, setTask] = React.useState(null);
  const [user, setUser] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    const loadSubmission = async () => {
      setLoading(true);

      try {
        const nextSubmission = await getSubmission(id);
        const [tasks, nextUser] = await Promise.all([
          getTasks(),
          getUser(nextSubmission.userId).catch(() => null),
        ]);

        setSubmission(nextSubmission);
        setTask(
          tasks.find((currentTask) => currentTask.id === nextSubmission.taskId) ??
            null,
        );
        setUser(nextUser);
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadSubmission();
  }, [id]);

  return (
    <div className="submissions">
      <Box className="task-page-header">
        <h1>Submission Details</h1>
        <Box className="task-page-actions">
          <Button
            component={RouterLink}
            to="/submissions"
            variant="outlined"
            sx={secondaryButtonSx}
          >
            Back to submissions
          </Button>
        </Box>
      </Box>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-creator admin-detail-shell" elevation={0}>
        {loading ? (
          <Box className="task-loading-state">
            <CircularProgress size={24} />
          </Box>
        ) : submission ? (
          <React.Fragment>
            <Typography variant="h4" className="task-title">
              Submission #{submission.id}
            </Typography>

            <Box className="task-detail-grid">
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Task
                </Typography>
                <Typography variant="body1">
                  {task?.slug ? (
                    <MuiLink component={RouterLink} to={`/tasks/${task.slug}`}>
                      {task.title}
                    </MuiLink>
                  ) : (
                    task?.title ?? `Task #${submission.taskId}`
                  )}
                </Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  User
                </Typography>
                <Typography variant="body1">
                  <MuiLink
                    component={RouterLink}
                    to={`/students/${submission.userId}`}
                  >
                    {user?.username ?? `User #${submission.userId}`}
                  </MuiLink>
                </Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Verdict
                </Typography>
                <Typography variant="body1">{submission.verdict}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Created
                </Typography>
                <Typography variant="body1">
                  {formatDateTime(submission.createdAt)}
                </Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Judged
                </Typography>
                <Typography variant="body1">
                  {formatDateTime(submission.judgedAt)}
                </Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Submission ID
                </Typography>
                <Typography variant="body1">{submission.id}</Typography>
              </div>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Submitted Data
              </Typography>
              <pre className="task-detail-config admin-json-panel">
                {jsonText(submission.data)}
              </pre>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Run Data
              </Typography>
              <pre className="task-detail-config admin-json-panel">
                {jsonText(submission.runData)}
              </pre>
            </Box>
          </React.Fragment>
        ) : null}
      </Paper>
    </div>
  );
};

export default SubmissionDetails;
