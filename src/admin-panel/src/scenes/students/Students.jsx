import {
  Alert,
  Button,
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
import { banUser, getUsers, unbanUser } from '../../services/userService';

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

const Students = () => {
  const [users, setUsers] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [pendingUserId, setPendingUserId] = React.useState(null);
  const [error, setError] = React.useState('');

  const loadUsers = React.useCallback(async () => {
    setLoading(true);

    try {
      const nextUsers = await getUsers();
      setUsers(nextUsers);
      setError('');
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const handleBanToggle = async (user) => {
    setPendingUserId(user.id);

    try {
      if (user.isBanned) {
        await unbanUser(user.id);
      } else {
        await banUser(user.id);
      }

      await loadUsers();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setPendingUserId(null);
    }
  };

  return (
    <div className="students">
      <h1>Students</h1>
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
        <Table aria-label="users table">
          <TableHead>
            <TableRow>
              <StyledTableCell>Username</StyledTableCell>
              <StyledTableCell>Email</StyledTableCell>
              <StyledTableCell>Role</StyledTableCell>
              <StyledTableCell>Verified</StyledTableCell>
              <StyledTableCell>Status</StyledTableCell>
              <StyledTableCell>Created</StyledTableCell>
              <StyledTableCell align="right">Action</StyledTableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <StyledTableRow>
                <StyledTableCell colSpan={7}>
                  <CircularProgress size={22} />
                </StyledTableCell>
              </StyledTableRow>
            ) : users.length === 0 ? (
              <StyledTableRow>
                <StyledTableCell colSpan={7}>No users found.</StyledTableCell>
              </StyledTableRow>
            ) : (
              users.map((user) => (
                <StyledTableRow key={user.id}>
                  <StyledTableCell>{user.username}</StyledTableCell>
                  <StyledTableCell>{user.email}</StyledTableCell>
                  <StyledTableCell>{user.role}</StyledTableCell>
                  <StyledTableCell>{user.verified ? 'Yes' : 'No'}</StyledTableCell>
                  <StyledTableCell>
                    {user.isBanned ? user.banReason || 'Banned' : 'Active'}
                  </StyledTableCell>
                  <StyledTableCell>{formatDateTime(user.createdAt)}</StyledTableCell>
                  <StyledTableCell align="right">
                    <Button
                      variant="outlined"
                      color={user.isBanned ? 'success' : 'error'}
                      onClick={() => handleBanToggle(user)}
                      disabled={pendingUserId === user.id}
                    >
                      {pendingUserId === user.id ? (
                        <CircularProgress size={18} />
                      ) : user.isBanned ? (
                        'Unban'
                      ) : (
                        'Ban'
                      )}
                    </Button>
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

export default Students;
