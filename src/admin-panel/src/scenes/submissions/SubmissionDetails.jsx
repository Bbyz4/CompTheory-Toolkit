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
import { getSubmission } from '../../services/submissionService';

const secondaryButtonSx = {
  color: 'var(--text-h)',
  borderColor: 'var(--border)',
};

const jsonString = (value) => JSON.stringify(value ?? {}, null, 2);

const SubmissionDetails = () => {
  const { id } = useParams();
  const [submission, setSubmission] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    const loadSubmission = async () => {
      try {
        const nextSubmission = await getSubmission(id);
        setSubmission(nextSubmission);
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
          <Button component={Link} to="/submissions" variant="outlined" sx={secondaryButtonSx}>
            Back to submissions
          </Button>
        </Box>
      </Box>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-creator task-details-shell" elevation={0}>
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
                  Task ID
                </Typography>
                <Typography variant="body1">{submission.taskId}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  User ID
                </Typography>
                <Typography variant="body1">{submission.userId}</Typography>
              </div>
              <div className="task-detail-card">
                <Typography variant="overline" className="task-muted-copy">
                  Verdict
                </Typography>
                <StatusBadge value={submission.verdict} />
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
                  Created
                </Typography>
                <Typography variant="body1">
                  {formatDateTime(submission.createdAt)}
                </Typography>
              </div>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Details JSON
              </Typography>
              <pre className="task-detail-config">
                {jsonString(submission.runData)}
              </pre>
            </Box>

            <Box className="task-detail-section">
              <Typography variant="h6" className="task-section-title">
                Submission JSON
              </Typography>
              <pre className="task-detail-config">
                {jsonString(submission.data)}
              </pre>
            </Box>
          </React.Fragment>
        ) : null}
      </Paper>
    </div>
  );
};

export default SubmissionDetails;
