import {
  Alert,
  CircularProgress,
  Paper,
  Table,
  TableBody,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import { styled } from '@mui/material/styles';
import TableCell, { tableCellClasses } from '@mui/material/TableCell';
import React from 'react';
import { formatDateTime } from '../../services/formatters';
import { getSubmissions } from '../../services/submissionService';
import { getTasks } from '../../services/taskService';

const StyledTableCell = styled(TableCell)(() => ({
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

const Submissions = () => {
  const [submissions, setSubmissions] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    const loadData = async () => {
      try {
        const [nextSubmissions, tasks] = await Promise.all([
          getSubmissions(),
          getTasks(),
        ]);

        const taskTitles = new Map(tasks.map((task) => [task.id, task.title]));

        setSubmissions(
          nextSubmissions.map((submission) => ({
            ...submission,
            taskTitle:
              taskTitles.get(submission.taskId) ?? `Task #${submission.taskId}`,
          })),
        );
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  return (
    <div className="submissions">
      <h1>Submissions</h1>
      {error ? <Alert severity="error">{error}</Alert> : null}

      <TableContainer
        component={Paper}
        sx={{
          backgroundColor: 'var(--box)',
          boxShadow: 'none',
          border: '1px solid var(--border)',
          borderRadius: '12px',
          marginTop: 2,
        }}
      >
        <Table aria-label="submissions table">
          <TableHead>
            <TableRow>
              <StyledTableCell>ID</StyledTableCell>
              <StyledTableCell>Task</StyledTableCell>
              <StyledTableCell>User ID</StyledTableCell>
              <StyledTableCell>Verdict</StyledTableCell>
              <StyledTableCell>Created</StyledTableCell>
              <StyledTableCell>Judged</StyledTableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <StyledTableRow>
                <StyledTableCell colSpan={6}>
                  <CircularProgress size={22} />
                </StyledTableCell>
              </StyledTableRow>
            ) : submissions.length === 0 ? (
              <StyledTableRow>
                <StyledTableCell colSpan={6}>No submissions found.</StyledTableCell>
              </StyledTableRow>
            ) : (
              submissions.map((submission) => (
                <StyledTableRow key={submission.id}>
                  <StyledTableCell>{submission.id}</StyledTableCell>
                  <StyledTableCell>{submission.taskTitle}</StyledTableCell>
                  <StyledTableCell>{submission.userId}</StyledTableCell>
                  <StyledTableCell>{submission.verdict}</StyledTableCell>
                  <StyledTableCell>
                    {formatDateTime(submission.createdAt)}
                  </StyledTableCell>
                  <StyledTableCell>{formatDateTime(submission.judgedAt)}</StyledTableCell>
                </StyledTableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </div>
  );
};

export default Submissions;
