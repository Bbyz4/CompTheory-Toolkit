import {
  Alert,
  Box,
  Button,
  CircularProgress,
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
import StatusBadge from '../../components/StatusBadge';
import { formatDateTime } from '../../services/formatters';
import { getTasks } from '../../services/taskService';

const StyledTableCell = styled(TableCellBase)(() => ({
  [`&.${tableCellClasses.head}`]: {
    backgroundColor: 'var(--box-light)',
    color: 'var(--text-secondary)',
    borderBottom: '1px solid var(--border)',
    fontSize: '12px',
    fontWeight: 800,
    textTransform: 'uppercase',
  },
  [`&.${tableCellClasses.body}`]: {
    color: 'var(--text-h)',
    backgroundColor: 'var(--box)',
    borderBottom: '1px solid var(--border)',
    verticalAlign: 'top',
    fontSize: '14px',
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

      <Box className="task-inline-actions">
        <Typography variant="h5" className="section-title">
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

      <TableContainer className="admin-table-container">
        <Table aria-label="tasks table" className="admin-table">
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
                  <StyledTableCell align="left">
                    <StatusBadge value={task.type} />
                  </StyledTableCell>
                  <StyledTableCell align="left">
                    <StatusBadge value={task.status} />
                  </StyledTableCell>
                  <StyledTableCell align="left">
                    <StatusBadge value={task.visibility} />
                  </StyledTableCell>
                  <StyledTableCell align="left">
                    {formatDateTime(task.updatedAt || task.createdAt)}
                  </StyledTableCell>
                </StyledTableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </div>
  );
};

export default Tasks;
