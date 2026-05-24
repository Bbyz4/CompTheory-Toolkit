import { Alert, Box, CircularProgress, Paper, Typography } from '@mui/material';
import React from 'react';
import { getSubmissions } from '../../services/submissionService';
import { getTasks } from '../../services/taskService';
import { getUsers } from '../../services/userService';

const StatCard = ({ label, value }) => (
  <Paper
    elevation={0}
    sx={{
      p: 3,
      borderRadius: '12px',
      border: '1px solid var(--border)',
      backgroundColor: 'var(--box)',
      minWidth: 220,
    }}
  >
    <Typography variant="overline" sx={{ color: 'var(--text)' }}>
      {label}
    </Typography>
    <Typography variant="h3" sx={{ color: 'var(--text-h)' }}>
      {value}
    </Typography>
  </Paper>
);

const Dashboard = () => {
  const [stats, setStats] = React.useState({
    tasks: 0,
    users: 0,
    submissions: 0,
    bannedUsers: 0,
  });
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    const loadDashboard = async () => {
      try {
        const [tasks, users, submissions] = await Promise.all([
          getTasks(),
          getUsers(),
          getSubmissions(),
        ]);

        setStats({
          tasks: tasks.length,
          users: users.length,
          submissions: submissions.length,
          bannedUsers: users.filter((user) => user.isBanned).length,
        });
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadDashboard();
  }, []);

  return (
    <div className="dashboard">
      <h1>Dashboard</h1>
      {error ? <Alert severity="error">{error}</Alert> : null}

      {loading ? (
        <CircularProgress size={28} />
      ) : (
        <Box display="flex" gap={2} flexWrap="wrap">
          <StatCard label="Tasks" value={stats.tasks} />
          <StatCard label="Users" value={stats.users} />
          <StatCard label="Submissions" value={stats.submissions} />
          <StatCard label="Banned users" value={stats.bannedUsers} />
        </Box>
      )}
    </div>
  );
};

export default Dashboard;
