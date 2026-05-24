import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Paper,
  Table,
  TableBody,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { styled } from '@mui/material/styles';
import TableCellBase, { tableCellClasses } from '@mui/material/TableCell';
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { formatDateTime } from '../../services/formatters';
import { getTasks } from '../../services/taskService';

const StyledTableCell = styled(TableCellBase)(() => ({
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

const Tasks = () => {
  const [tasks, setTasks] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');
  const navigate = useNavigate();

  React.useEffect(() => {
    const loadTasks = async () => {
      try {
        const nextTasks = await getTasks();
        setTasks(nextTasks);
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadTasks();
  }, []);

  const openTask = (task) => {
    if (!task.slug) {
      return;
    }

    navigate(`/tasks/${task.slug}`);
  };

  return (
    <div className="tasks">
      <h1>Tasks</h1>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-submissions task-list-shell" elevation={0}>
        <Box className="task-inline-actions">
          <Typography variant="h5" className="task-submissions-title">
            All Tasks
          </Typography>
          <Button
            component={Link}
            to="/tasks/new"
            variant="contained"
            sx={actionButtonSx}
          >
            Create task
          </Button>
        </Box>

        <TableContainer
          component={Paper}
          sx={{
            backgroundColor: 'var(--box)',
            boxShadow: 'none',
            border: '1px solid var(--border)',
            borderRadius: '8px',
            marginTop: 1,
          }}
        >
          <Table aria-label="tasks table" sx={{ minWidth: 760 }}>
            <TableHead>
              <TableRow>
                <StyledTableCell>Task Title</StyledTableCell>
                <StyledTableCell align="left">Slug</StyledTableCell>
                <StyledTableCell align="left">Type</StyledTableCell>
                <StyledTableCell align="left">Status</StyledTableCell>
                <StyledTableCell align="left">Visibility</StyledTableCell>
                <StyledTableCell align="left">Updated</StyledTableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {loading ? (
                <StyledTableRow>
                  <StyledTableCell colSpan={6}>
                    <CircularProgress size={22} />
                  </StyledTableCell>
                </StyledTableRow>
              ) : tasks.length === 0 ? (
                <StyledTableRow>
                  <StyledTableCell colSpan={6}>
                    No tasks created yet.
                  </StyledTableCell>
                </StyledTableRow>
              ) : (
                tasks.map((task) => (
                  <StyledTableRow
                    key={task.id}
                    hover={Boolean(task.slug)}
                    onClick={() => openTask(task)}
                    sx={{
                      cursor: task.slug ? 'pointer' : 'default',
                    }}
                  >
                    <StyledTableCell align="left">
                      <span className="task-row-link">{task.title}</span>
                    </StyledTableCell>
                    <StyledTableCell align="left">
                      {task.slug || 'No slug'}
                    </StyledTableCell>
                    <StyledTableCell align="left">{task.type}</StyledTableCell>
                    <StyledTableCell align="left">{task.status}</StyledTableCell>
                    <StyledTableCell align="left">{task.visibility}</StyledTableCell>
                    <StyledTableCell align="left">
                      {formatDateTime(task.updatedAt || task.createdAt)}
                    </StyledTableCell>
                  </StyledTableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
    </div>
  );
};

export default Tasks;
