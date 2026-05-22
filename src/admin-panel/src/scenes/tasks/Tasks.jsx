import AttachFileIcon from '@mui/icons-material/AttachFile';
import CancelIcon from '@mui/icons-material/Cancel';
import CheckCircleRoundedIcon from '@mui/icons-material/CheckCircleRounded';
import {
  Alert,
  Box,
  CircularProgress,
  Paper,
  Table,
  TableBody,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { styled } from '@mui/material/styles';
import TableCellBase, { tableCellClasses } from '@mui/material/TableCell';
import React from 'react';
import { createTask, getTasks } from '../../services/taskService';
import { formatDateTime } from '../../services/formatters';

const StyledTableCell = styled(TableCellBase)(() => ({
  [`&.${tableCellClasses.head}`]: {
    backgroundColor: 'var(--accent-dark)',
    color: 'var(--text-h)',
    borderBottom: '1px solid var(--border)',
    fontWeight: 'bold',
  },
  [`&.${tableCellClasses.body}`]: {
    color: 'var(--text)',
    backgroundColor: 'var(--box)',
    borderBottom: '1px solid var(--border)',
    verticalAlign: 'top',
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

const Tasks = () => {
  const [title, setTitle] = React.useState('');
  const [description, setDescription] = React.useState('');
  const [tasks, setTasks] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [submitting, setSubmitting] = React.useState(false);
  const [error, setError] = React.useState('');
  const [successMessage, setSuccessMessage] = React.useState('');

  const loadTasks = React.useCallback(async () => {
    setLoading(true);

    try {
      const nextTasks = await getTasks();
      setTasks(nextTasks);
      setError('');
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  const resetForm = () => {
    setTitle('');
    setDescription('');
    setSuccessMessage('');
  };

  const handleSubmit = async () => {
    if (!title.trim() || !description.trim()) {
      setError('Task title and description are required.');
      return;
    }

    setSubmitting(true);
    setSuccessMessage('');

    try {
      await createTask({
        title: title.trim(),
        description: description.trim(),
      });
      resetForm();
      setError('');
      setSuccessMessage('Task published successfully.');
      await loadTasks();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="tasks">
      <h1>Tasks</h1>

      {error ? <Alert severity="error">{error}</Alert> : null}
      {successMessage ? <Alert severity="success">{successMessage}</Alert> : null}

      <Box>
        <Paper className="task-creator" elevation={0}>
          <Typography variant="h5" className="task-title">
            Create Task
          </Typography>

          <TextField
            label="Task Title"
            variant="outlined"
            fullWidth
            margin="normal"
            className="custom-textfield"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
          />

          <TextField
            label="Task Description"
            variant="outlined"
            fullWidth
            margin="normal"
            multiline
            rows={8}
            className="custom-textfield"
            value={description}
            onChange={(event) => setDescription(event.target.value)}
          />

          <Box display="flex" alignItems="center" mt={2}>
            <AttachFileIcon color="disabled" />
            <Typography variant="body2" sx={{ color: 'var(--text)', ml: 1 }}>
              Attachment support is not wired yet in the backend API.
            </Typography>
          </Box>

          <Box display="flex" mt={2} paddingTop={2}>
            <CancelIcon
              onClick={resetForm}
              color="error"
              style={{
                cursor: submitting ? 'default' : 'pointer',
                marginRight: '13px',
                marginTop: '10px',
                marginLeft: '10px',
                opacity: submitting ? 0.5 : 1,
              }}
            />
            <CheckCircleRoundedIcon
              color={submitting ? 'disabled' : 'success'}
              onClick={submitting ? undefined : handleSubmit}
              style={{ cursor: submitting ? 'default' : 'pointer' }}
            />
            {submitting ? <CircularProgress size={22} sx={{ ml: 2, mt: 0.5 }} /> : null}
          </Box>
        </Paper>
      </Box>

      <Box>
        <Paper className="task-submissions" elevation={0}>
          <Typography variant="h5" className="task-submissions-title">
            Published Tasks
          </Typography>

          <TableContainer
            component={Paper}
            sx={{
              maxHeight: '35vh',
              backgroundColor: 'var(--box)',
              boxShadow: 'none',
              border: '1px solid var(--border)',
              borderRadius: '8px',
              marginTop: 1,
            }}
          >
            <Table stickyHeader aria-label="tasks table" sx={{ minWidth: 700 }}>
              <TableHead>
                <TableRow>
                  <StyledTableCell>Task Title</StyledTableCell>
                  <StyledTableCell align="left">Description</StyledTableCell>
                  <StyledTableCell align="left">Created</StyledTableCell>
                  <StyledTableCell align="left">Status</StyledTableCell>
                  <StyledTableCell align="left">Visibility</StyledTableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {loading ? (
                  <StyledTableRow>
                    <StyledTableCell colSpan={5}>
                      <CircularProgress size={22} />
                    </StyledTableCell>
                  </StyledTableRow>
                ) : tasks.length === 0 ? (
                  <StyledTableRow>
                    <StyledTableCell colSpan={5}>
                      No published tasks yet.
                    </StyledTableCell>
                  </StyledTableRow>
                ) : (
                  tasks.map((task) => (
                    <StyledTableRow key={task.id}>
                      <StyledTableCell align="left">{task.title}</StyledTableCell>
                      <StyledTableCell align="left">
                        {task.shortDescription || task.description}
                      </StyledTableCell>
                      <StyledTableCell align="left">
                        {formatDateTime(task.createdAt)}
                      </StyledTableCell>
                      <StyledTableCell align="left">{task.status}</StyledTableCell>
                      <StyledTableCell align="left">{task.visibility}</StyledTableCell>
                    </StyledTableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      </Box>
    </div>
  );
};

export default Tasks;
