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
} from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import { styled } from '@mui/material/styles';
import TableCell, { tableCellClasses } from '@mui/material/TableCell';
import React from 'react';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import { formatDateTime } from '../../services/formatters';
import { getSubmissions } from '../../services/submissionService';
import { getTasks } from '../../services/taskService';

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

const Submissions = () => {
  const [submissions, setSubmissions] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');
  const navigate = useNavigate();

  React.useEffect(() => {
    const loadData = async () => {
      try {
        const [nextSubmissions, tasks] = await Promise.all([
          getSubmissions(),
          getTasks(),
        ]);

        const taskLookup = new Map(tasks.map((task) => [task.id, task]));

        setSubmissions(
          nextSubmissions.map((submission) => {
            const task = taskLookup.get(submission.taskId);

            return {
              ...submission,
              taskTitle: task?.title ?? `Task #${submission.taskId}`,
              taskSlug: task?.slug ?? null,
            };
          }),
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

  const openSubmission = (submission) => {
    navigate(`/submissions/${submission.id}`);
  };

  return (
    <div className="submissions">
      <Box className="task-page-header">
        <h1>Submissions</h1>
        <Box className="task-page-actions">
          <Button
            component={RouterLink}
            to="/submissions/new"
            variant="contained"
            startIcon={<AddIcon />}
            sx={actionButtonSx}
          >
            Create submission
          </Button>
        </Box>
      </Box>
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
                  <StyledTableCell>
                    <MuiLink
                      component={RouterLink}
                      to={`/students/${submission.userId}`}
                      onClick={(event) => event.stopPropagation()}
                    >
                      {submission.userId}
                    </MuiLink>
                  </StyledTableCell>
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
