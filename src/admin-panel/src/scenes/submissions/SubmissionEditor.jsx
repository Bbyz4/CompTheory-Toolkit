import {
  Alert,
  Box,
  Button,
  CircularProgress,
  MenuItem,
  Paper,
  TextField,
  Typography,
} from '@mui/material';
import RestoreIcon from '@mui/icons-material/Restore';
import SendIcon from '@mui/icons-material/Send';
import React from 'react';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import { createSubmission } from '../../services/submissionService';
import { getTasks } from '../../services/taskService';
import { getUsers } from '../../services/userService';

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

const modelTypeForTask = (task) => task?.config?.requiredModelType ?? 'NFA';

const submissionExampleForTask = (task) => {
  const modelType = modelTypeForTask(task);

  if (modelType === 'CFG') {
    return {
      type: 'CFG',
      model: {
        nonTerminals: ['S', 'A'],
        terminals: ['a', 'b'],
        transitions: [
          { from: 'S', to: ['A', 'b'] },
          { from: 'A', to: ['a'] },
          { from: 'A', to: [] },
        ],
        startSymbol: 'S',
      },
    };
  }

  if (modelType === 'NFA') {
    return {
      type: 'NFA',
      model: {
        states: ['q0', 'q1'],
        inputAlphabet: ['a'],
        transitions: [
          { from: 'q0', to: 'q1', symbol: 'a' },
          { from: 'q1', to: 'q1', symbol: null },
        ],
        startStates: ['q0'],
        acceptStates: ['q1'],
      },
    };
  }

  return {
    type: modelType,
    model: {},
  };
};

const jsonForTask = (task) =>
  JSON.stringify(submissionExampleForTask(task), null, 2);

const taskLabel = (task) =>
  `${task.title} (#${task.id}${task.slug ? `, ${task.slug}` : ''})`;

const userLabel = (user) => `${user.username} (#${user.id})`;

const SubmissionEditor = () => {
  const [tasks, setTasks] = React.useState([]);
  const [users, setUsers] = React.useState([]);
  const [selectedTaskId, setSelectedTaskId] = React.useState('');
  const [selectedUserId, setSelectedUserId] = React.useState('');
  const [jsonText, setJsonText] = React.useState('');
  const [loading, setLoading] = React.useState(true);
  const [submitting, setSubmitting] = React.useState(false);
  const [error, setError] = React.useState('');
  const [formError, setFormError] = React.useState('');
  const navigate = useNavigate();

  React.useEffect(() => {
    const loadData = async () => {
      try {
        const [nextTasks, nextUsers] = await Promise.all([
          getTasks(),
          getUsers(),
        ]);

        setTasks(nextTasks);
        setUsers(nextUsers);

        if (nextTasks.length > 0) {
          setSelectedTaskId(String(nextTasks[0].id));
          setJsonText(jsonForTask(nextTasks[0]));
        }

        if (nextUsers.length > 0) {
          setSelectedUserId(String(nextUsers[0].id));
        }

        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  const selectedTask = tasks.find(
    (task) => String(task.id) === selectedTaskId,
  );

  const handleTaskChange = (event) => {
    const nextTaskId = event.target.value;
    const nextTask = tasks.find((task) => String(task.id) === nextTaskId);

    setSelectedTaskId(nextTaskId);
    setJsonText(jsonForTask(nextTask));
    setFormError('');
  };

  const handleLoadExample = () => {
    setJsonText(jsonForTask(selectedTask));
    setFormError('');
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setFormError('');

    let parsedData;

    try {
      parsedData = JSON.parse(jsonText);
    } catch (parseError) {
      setFormError(`Invalid JSON: ${parseError.message}`);
      return;
    }

    if (
      parsedData === null ||
      typeof parsedData !== 'object' ||
      Array.isArray(parsedData)
    ) {
      setFormError('Submission JSON must be an object.');
      return;
    }

    setSubmitting(true);

    try {
      const submission = await createSubmission({
        taskId: Number(selectedTaskId),
        userId: selectedUserId ? Number(selectedUserId) : undefined,
        data: parsedData,
      });

      navigate(`/submissions/${submission.id}`);
    } catch (nextError) {
      setFormError(nextError.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="submissions">
      <Box className="task-page-header">
        <h1>Create Submission</h1>
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
      {formError ? <Alert severity="error">{formError}</Alert> : null}

      <Paper
        component="form"
        className="task-creator admin-detail-shell submission-editor-shell"
        elevation={0}
        onSubmit={handleSubmit}
      >
        {loading ? (
          <Box className="task-loading-state">
            <CircularProgress size={24} />
          </Box>
        ) : (
          <React.Fragment>
            <Box className="submission-form-grid">
              <TextField
                select
                required
                fullWidth
                label="Task"
                value={selectedTaskId}
                onChange={handleTaskChange}
                className="custom-textfield"
                disabled={submitting || tasks.length === 0}
              >
                {tasks.map((task) => (
                  <MenuItem key={task.id} value={String(task.id)}>
                    {taskLabel(task)}
                  </MenuItem>
                ))}
              </TextField>

              <TextField
                select
                fullWidth
                label="User"
                value={selectedUserId}
                onChange={(event) => setSelectedUserId(event.target.value)}
                className="custom-textfield"
                disabled={submitting || users.length === 0}
              >
                {users.map((user) => (
                  <MenuItem key={user.id} value={String(user.id)}>
                    {userLabel(user)}
                  </MenuItem>
                ))}
              </TextField>
            </Box>

            <Box className="submission-json-header">
              <Typography variant="h6" className="task-section-title">
                Submission JSON
              </Typography>
              <Button
                type="button"
                variant="outlined"
                startIcon={<RestoreIcon />}
                sx={secondaryButtonSx}
                onClick={handleLoadExample}
                disabled={submitting || !selectedTask}
              >
                Load example
              </Button>
            </Box>

            <TextField
              fullWidth
              required
              multiline
              minRows={18}
              value={jsonText}
              onChange={(event) => setJsonText(event.target.value)}
              className="custom-textfield submission-json-field"
              disabled={submitting || tasks.length === 0}
              inputProps={{ spellCheck: 'false' }}
            />

            <Box className="task-form-actions">
              <Button
                type="submit"
                variant="contained"
                startIcon={<SendIcon />}
                sx={actionButtonSx}
                disabled={submitting || !selectedTaskId || tasks.length === 0}
              >
                {submitting ? 'Submitting...' : 'Create submission'}
              </Button>
            </Box>
          </React.Fragment>
        )}
      </Paper>
    </div>
  );
};

export default SubmissionEditor;
