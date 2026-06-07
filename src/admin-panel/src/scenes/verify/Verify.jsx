import { Alert, CircularProgress, Paper, Typography } from '@mui/material';
import React from 'react';
import { useLocation } from 'react-router-dom';

const Verify = () => {
  const location = useLocation();
  const token = React.useMemo(() => {
    const params = new URLSearchParams(location.search);
    return params.get('token');
  }, [location.search]);
  const [state, setState] = React.useState({
    status: 'loading',
    message: 'Verifying your email address...',
  });

  React.useEffect(() => {
    if (!token) {
      return;
    }

    const verify = async () => {
      try {
        const response = await fetch('/proxy/auth/verify-email', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ token }),
        });
        const payload = await response.json();

        if (!response.ok) {
          throw new Error(
            payload?.error?.message ?? 'Verification failed.',
          );
        }

        setState({
          status: 'success',
          message: 'Email verified successfully.',
        });
      } catch (error) {
        setState({
          status: 'error',
          message: error.message,
        });
      }
    };

    verify();
  }, [token]);

  const displayState = token
    ? state
    : {
        status: 'error',
        message: 'Verification token is missing.',
      };

  return (
    <div className="verify">
      <h1>Verify your email</h1>
      <Paper elevation={0} className="verify-panel">
        {displayState.status === 'loading' ? <CircularProgress size={24} /> : null}
        {displayState.status === 'success' ? (
          <Alert severity="success">{displayState.message}</Alert>
        ) : null}
        {displayState.status === 'error' ? (
          <Alert severity="error">{displayState.message}</Alert>
        ) : null}
        <Typography sx={{ mt: 2, color: 'var(--text)' }}>
          You can return to the dashboard after the verification request completes.
        </Typography>
      </Paper>
    </div>
  );
};

export default Verify;
