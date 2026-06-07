import { Alert, CircularProgress, Paper, Typography } from '@mui/material';
import React from 'react';
import { useLocation } from 'react-router-dom';

const Verify = () => {
  const location = useLocation();
  const [state, setState] = React.useState({
    status: 'loading',
    message: 'Verifying your email address...',
  });

  React.useEffect(() => {
    const params = new URLSearchParams(location.search);
    const token = params.get('token');

    if (!token) {
      setState({
        status: 'error',
        message: 'Verification token is missing.',
      });
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
  }, [location.search]);

  return (
    <div className="verify">
      <h1>Verify your email</h1>
      <Paper elevation={0} className="verify-panel">
        {state.status === 'loading' ? <CircularProgress size={24} /> : null}
        {state.status === 'success' ? (
          <Alert severity="success">{state.message}</Alert>
        ) : null}
        {state.status === 'error' ? (
          <Alert severity="error">{state.message}</Alert>
        ) : null}
        <Typography sx={{ mt: 2, color: 'var(--text)' }}>
          You can return to the dashboard after the verification request completes.
        </Typography>
      </Paper>
    </div>
  );
};

export default Verify;
