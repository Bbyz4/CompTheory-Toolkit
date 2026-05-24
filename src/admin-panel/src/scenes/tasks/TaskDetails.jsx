import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Paper,
  Typography,
} from '@mui/material';
import React from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { formatDateTime } from '../../services/formatters';
import { getTasks } from '../../services/taskService';

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

const TaskDetails = () => {
  const { slug } = useParams();
  const location = useLocation();
  const [task, setTask] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    const loadTask = async () => {
      try {
        const tasks = await getTasks();
        const nextTask = tasks.find((currentTask) => currentTask.slug === slug);

        if (!nextTask) {
          setError('Task not found.');
          return;
        }

        setTask(nextTask);
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadTask();
  }, [slug]);

  return (
    <div className="tasks">
      <Box className="task-page-header">
        <h1>Task Details</h1>
        <Box className="task-page-actions">
          <Button component={Link} to="/tasks" variant="outlined" sx={secondaryButtonSx}>
            Back to tasks
          </Button>
        </Box>
      </Box>

      {location.state?.successMessage ? (
        <Alert severity="success">{location.state.successMessage}</Alert>
      ) : null}
      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-creator task-details-shell" elevation={0}>
        {loading ? (
          <Box className="task-loading-state">
            <CircularProgress size={24} />
          </Box>
        ) : task ? (
          <React.Fragment>
            <Typography variant="h4" className="task-title">
              {task.title}
            </Typography>

            {task.slug ? (
              <Box className="task-inline-actions">
                <Button
                  component={Link}
                  to={`/tasks/${task.slug}/edit`}
                  variant="contained"
                  sx={actionButtonSx}
                >
                  Edit task
                </Button>
              </Box>
            ) : null}

            <Box className="task-detail-grid">
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Slug
                </Typography>
                <Typography variant="body1">{task.slug || 'No slug'}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Type
                </Typography>
                <Typography variant="body1">{task.type}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Status
                </Typography>
                <Typography variant="body1">{task.status}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Visibility
                </Typography>
                <Typography variant="body1">{task.visibility}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Difficulty
                </Typography>
                <Typography variant="body1">{task.difficulty}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Updated
                </Typography>
                <Typography variant="body1">
                  {formatDateTime(task.updatedAt || task.createdAt)}
                </Typography>
              </div>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Description
              </Typography>
              <div className="task-detail-copy">{task.description}</div>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Config
              </Typography>
              <pre className="task-detail-config">
                {JSON.stringify(task.config ?? {}, null, 2)}
              </pre>
            </Box>
          </React.Fragment>
        ) : null}
      </Paper>
    </div>
  );
};

export default TaskDetails;
