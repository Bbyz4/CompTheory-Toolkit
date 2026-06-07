import {
  Alert,
  Button,
  CircularProgress,
  Table,
  TableBody,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import { styled } from '@mui/material/styles';
import TableCell, { tableCellClasses } from '@mui/material/TableCell';
import React from 'react';
import { useNavigate } from 'react-router-dom';
import StatusBadge from '../../components/StatusBadge';
import { formatDateTime } from '../../services/formatters';
import { banUser, getUsers, unbanUser } from '../../services/userService';

const StyledTableCell = styled(TableCell)(() => ({
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

const Students = () => {
  const [users, setUsers] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [pendingUserId, setPendingUserId] = React.useState(null);
  const [error, setError] = React.useState('');
  const navigate = useNavigate();

  const applyUsers = React.useCallback((nextUsers) => {
    setUsers(nextUsers);
    setError('');
  }, []);

  const reloadUsers = React.useCallback(async () => {
    setLoading(true);

    try {
      const nextUsers = await getUsers();
      applyUsers(nextUsers);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }, [applyUsers]);

  React.useEffect(() => {
    let isCurrent = true;

    getUsers()
      .then((nextUsers) => {
        if (isCurrent) {
          applyUsers(nextUsers);
        }
      })
      .catch((nextError) => {
        if (isCurrent) {
          setError(nextError.message);
        }
      })
      .finally(() => {
        if (isCurrent) {
          setLoading(false);
        }
      });

    return () => {
      isCurrent = false;
    };
  }, [applyUsers]);

  const handleBanToggle = async (user) => {
    setPendingUserId(user.id);

    try {
      if (user.isBanned) {
        await unbanUser(user.id);
      } else {
        await banUser(user.id);
      }

      await reloadUsers();
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

      <TableContainer className="admin-table-container">
        <Table aria-label="users table" className="admin-table">
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
                <StyledTableRow
                  key={user.id}
                  hover
                  onClick={() => navigate(`/students/${user.id}`)}
                  sx={{ cursor: 'pointer' }}
                >
                  <StyledTableCell>{user.username}</StyledTableCell>
                  <StyledTableCell>{user.email}</StyledTableCell>
                  <StyledTableCell>
                    <StatusBadge value={user.role} />
                  </StyledTableCell>
                  <StyledTableCell>
                    <StatusBadge value={user.verified ? 'Yes' : 'No'} />
                  </StyledTableCell>
                  <StyledTableCell>
                    <StatusBadge value={user.isBanned ? 'Banned' : 'Active'} />
                  </StyledTableCell>
                  <StyledTableCell>{formatDateTime(user.createdAt)}</StyledTableCell>
                  <StyledTableCell align="right">
                    <Button
                      variant="outlined"
                      color={user.isBanned ? 'success' : 'error'}
                      onClick={(event) => {
                        event.stopPropagation();
                        handleBanToggle(user);
                      }}
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
