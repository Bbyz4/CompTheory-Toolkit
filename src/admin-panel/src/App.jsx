import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import { CircularProgress } from '@mui/material';
import React from 'react';
import Dashboard from './scenes/dashboard/Dashboard';
import Login from './scenes/auth/Login';
import Sidebar from './scenes/global/Sidebar';
import Topbar from './scenes/global/Topbar';
import Settings from './scenes/settings/Settings';
import Students from './scenes/students/Students';
import UserProfile from './scenes/students/UserProfile';
import Submissions from './scenes/submissions/Submissions';
import SubmissionDetails from './scenes/submissions/SubmissionDetails';
import SubmissionEditor from './scenes/submissions/SubmissionEditor';
import TaskDetails from './scenes/tasks/TaskDetails';
import TaskEditor from './scenes/tasks/TaskEditor';
import Tasks from './scenes/tasks/Tasks';
import Verify from './scenes/verify/Verify';
import { hasStoredSession, loadCurrentAdmin, logoutAdmin } from './services/authService';
import './App.css';

function App() {
  const [authState, setAuthState] = React.useState({
    status: hasStoredSession() ? 'loading' : 'unauthenticated',
    user: null,
  });

  React.useEffect(() => {
    if (!hasStoredSession()) {
      return;
    }

    const restoreSession = async () => {
      try {
        const user = await loadCurrentAdmin();
        setAuthState({
          status: 'authenticated',
          user,
        });
      } catch {
        setAuthState({
          status: 'unauthenticated',
          user: null,
        });
      }
    };

    restoreSession();
  }, []);

  const handleAuthenticated = (user) => {
    setAuthState({
      status: 'authenticated',
      user,
    });
  };

  const handleLogout = async () => {
    await logoutAdmin();
    setAuthState({
      status: 'unauthenticated',
      user: null,
    });
  };

  if (authState.status === 'loading') {
    return (
      <div className="login-screen">
        <CircularProgress size={28} />
      </div>
    );
  }

  if (authState.status !== 'authenticated') {
    return <Login onAuthenticated={handleAuthenticated} />;
  }

  return (
    <Router>
      <div className="app">
        <Sidebar />
        <main className="main-content">
          <Topbar user={authState.user} onLogout={handleLogout} />
          <div className="content">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/tasks" element={<Tasks />} />
              <Route path="/tasks/new" element={<TaskEditor />} />
              <Route path="/tasks/:slug/edit" element={<TaskEditor />} />
              <Route path="/tasks/:slug" element={<TaskDetails />} />
              <Route path="/submissions" element={<Submissions />} />
              <Route path="/submissions/new" element={<SubmissionEditor />} />
              <Route path="/submissions/:id" element={<SubmissionDetails />} />
              <Route path="/students" element={<Students />} />
              <Route path="/students/:id" element={<UserProfile />} />
              <Route path="/settings" element={<Settings />} />
              <Route path="/verify" element={<Verify />} />
              <Route path="*" element={<Dashboard />} />
            </Routes>
          </div>
        </main>
      </div>
    </Router>
  );
}

export default App;
