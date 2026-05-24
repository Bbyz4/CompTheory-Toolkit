import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Paper,
  TextField,
  Typography,
} from '@mui/material';
import React from 'react';
import { loginAdmin } from '../../services/authService';

const Login = ({ onAuthenticated }) => {
  const [username, setUsername] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [submitting, setSubmitting] = React.useState(false);
  const [error, setError] = React.useState('');

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!username.trim() || !password) {
      setError('Username and password are required.');
      return;
    }

    setSubmitting(true);

    try {
      const user = await loginAdmin({
        username: username.trim(),
        password,
      });
      setError('');
      onAuthenticated(user);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="login-screen">
      <Paper className="login-card" elevation={0}>
        <Typography variant="h5" className="task-title">
          Admin Login
        </Typography>

        {error ? <Alert severity="error">{error}</Alert> : null}

        <Box component="form" onSubmit={handleSubmit} className="login-form">
          <TextField
            label="Username"
            variant="outlined"
            fullWidth
            margin="normal"
            className="custom-textfield"
            value={username}
            onChange={(event) => setUsername(event.target.value)}
          />

          <TextField
            label="Password"
            type="password"
            variant="outlined"
            fullWidth
            margin="normal"
            className="custom-textfield"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />

          <Box className="login-actions">
            <Button
              type="submit"
              variant="contained"
              disabled={submitting}
              sx={{
                backgroundColor: 'var(--accent)',
                color: 'var(--text-h)',
                boxShadow: 'none',
              }}
            >
              {submitting ? <CircularProgress size={18} color="inherit" /> : 'Login'}
            </Button>
          </Box>
        </Box>
      </Paper>
    </div>
  );
};

export default Login;

