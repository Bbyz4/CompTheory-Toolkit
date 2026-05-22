import AttachFileIcon from '@mui/icons-material/AttachFile';
import CancelIcon from '@mui/icons-material/Cancel';
import CreateIcon from '@mui/icons-material/Create';
import DeleteIcon from '@mui/icons-material/Delete';
import DescriptionIcon from '@mui/icons-material/Description';
import DownloadIcon from '@mui/icons-material/Download';
import EditIcon from '@mui/icons-material/Edit';
import TaskIcon from '@mui/icons-material/Task';
import GradingIcon from '@mui/icons-material/Grading';
import AddCircleIcon from '@mui/icons-material/AddCircle';
import DoneIcon from '@mui/icons-material/Done';
import CheckCircleRoundedIcon from '@mui/icons-material/CheckCircleRounded';
import { Paper, Box, Typography, TextField } from '@mui/material';
import { styled } from '@mui/material/styles';
import TableCell, { tableCellClasses } from '@mui/material/TableCell';
import { 
  Table, TableBody, TableContainer, TableHead, TableRow, IconButton 
} from '@mui/material';
import { mockTasks } from '../../data/mockData';
import React from 'react';

const StyledTableCell = styled(TableCell)(({ theme }) => ({
  [`&.${tableCellClasses.head}`]: {
    backgroundColor: 'var(--accent-dark)',
    color: 'var(--text-h)',
    borderBottom: '1px solid var(--border)',
    fontWeight: 'bold',
  },
  [`&.${tableCellClasses.body}`]: {
    fontSize: 'h5',
    color: 'var(--text)',
    backgroundColor: 'var(--box)',
    borderBottom: '1px solid var(--border)',
  },
}));

const StyledTableRow = styled(TableRow)(({ theme }) => ({
  '&td': {
    backgroundColor: 'var(--box)',
  },
  '&:hover td': {
    backgroundColor: 'var(--box-light) !important', 
    transition: '0.2s',
    cursor: 'pointer',
  },
}));

function createData(title, description, date, files, actions) {
  return { title, description, date, files, actions };
}

const rows = [
  createData('Task 1', 'Description for Task 1', '2026-01-01', ['file1.zip'], ['action1']),
  createData('Task 2', 'Description for Task 2', '2026-01-02', ['file2.zip'], ['action2']),
  createData('Task 3', 'Description for Task 3', '2026-01-03', ['file3.zip'], ['action3']),
  createData('Task 4', 'Description for Task 4', '2026-01-04', ['file4.zip'], ['action4']),
  createData('Task 5', 'Description for Task 5', '2026-01-05', ['file5.zip'], ['action5']),
  createData('Task 6', 'Description for Task 6', '2026-01-06', ['file6.zip'], ['action6']),
  createData('Task 7', 'Description for Task 7', '2026-01-07', ['file7.zip'], ['action7']),
  createData('Task 8', 'Description for Task 8', '2026-01-08', ['file8.zip'], ['action8']),
  createData('Task 9', 'Description for Task 9', '2026-01-09', ['file9.zip'], ['action9']),
];

const Tasks = () => {
  const [title, setTitle] = React.useState("");
  const [description, setDescription] = React.useState("");
  
  return (
    <div className="tasks">
      <h1>Tasks</h1>

      <Box>
        <Paper className="task-creator" elevation={0}>
          <Typography variant="h5" className="task-title">
            Create or Edit Task
          </Typography>

          <TextField
            label="Task Title"
            variant="outlined"
            fullWidth
            margin="normal"
            className='custom-textfield'
            value = {title}
            onChange={(e) => {setTitle(e.target.value)}}
          />

          <TextField
            label="Task Description"
            variant="outlined"
            fullWidth
            margin="normal"
            multiline
            rows={8}
            className='custom-textfield'
            value = {description}
            onChange={(e) => {setDescription(e.target.value)}}
          />

          <Box display="flex" alignItems="center" mt={2}>
            <AttachFileIcon color="action" style={{ cursor: 'pointer' }} />
            <Typography variant="body" color="textSecondary" ml={1}>
              Attach files (optional)
            </Typography>
          </Box>

          <Box display="flex" mt={2} paddingTop={2}>
            <CancelIcon onClick={() => {
              setTitle('');
              setDescription('');
            }} color="error" style={{ cursor: 'pointer', marginRight: '13px', marginTop: '10px', marginLeft: '10px' }} />
            <CheckCircleRoundedIcon color="success" style={{ cursor: 'pointer' }} />
          </Box>

        </Paper>
      </Box>

      <Box>
        <Paper className="task-submissions" elevation={0}>
          <Typography variant="h5" className="task-submissions-title">
            Published Tasks
          </Typography>


          <TableContainer 
            component={Paper} 
            sx={{ 
              maxHeight: '35vh',
              backgroundColor: 'var(--box)', 
              boxShadow: 'none',
              border: '1px solid var(--border)',
              borderRadius: '8px',
              marginTop: 1,
            }}
          >
            <Table stickyHeader aria-label="customized table" sx={{ minWidth: 700 }}>
              <TableHead>
                <TableRow>
                  <StyledTableCell>Task Title</StyledTableCell>
                  <StyledTableCell align="left">Description</StyledTableCell>
                  <StyledTableCell align="left">Creation Date</StyledTableCell>
                  <StyledTableCell align="left">Test Files</StyledTableCell>
                  <StyledTableCell align="left">Actions</StyledTableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.map((row) => (
                  <StyledTableRow key={row.name}>
                    <StyledTableCell align="left">{row.title}</StyledTableCell>
                    <StyledTableCell align="left">{row.description}</StyledTableCell>
                    <StyledTableCell align="left">{row.date}</StyledTableCell>
                    <StyledTableCell align="left">{row.files}</StyledTableCell>
                    <StyledTableCell align="left">
                      <IconButton color="inherit" size="small">
                        <EditIcon 
                        onClick={() => {
                          setTitle(row.title);
                          setDescription(row.description);
                        }}
                        />
                      </IconButton>
                      <IconButton color="error" size="small">
                        <DeleteIcon />
                      </IconButton>
                    </StyledTableCell>
                  </StyledTableRow>
                ))} 
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      </Box>

    </div>
  );
};

export default Tasks;