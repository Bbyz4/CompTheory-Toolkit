import { Link } from "react-router-dom";
import AddIcon from '@mui/icons-material/Add';
import AddCircleIcon from '@mui/icons-material/AddCircle';
import DashboardIcon from '@mui/icons-material/Dashboard';
import FeedIcon from '@mui/icons-material/Feed';
import HomeIcon from '@mui/icons-material/Home';
import ModeIcon from '@mui/icons-material/Mode';
import PeopleIcon from '@mui/icons-material/People';
import SettingsIcon from '@mui/icons-material/Settings';
import TaskIcon from '@mui/icons-material/Task';

const Sidebar = () => {
  return (
    <div className="sidebar">
      <h1>MODDELLE</h1>
      <ul>
        <li>
          <Link to="/dashboard"><DashboardIcon/> Dashboard</Link>
        </li>
        <li>
          <Link to="/tasks"><TaskIcon/> Tasks</Link>
        </li>
        <li>
          <Link to="/submissions"><FeedIcon/> Submissions</Link>
        </li>
        <li>
          <Link to="/students"><PeopleIcon/> Students</Link>
        </li>
        <li>
          <Link to="/settings"><SettingsIcon/> Settings</Link>
        </li>
      </ul>
    </div>
  );
};

export default Sidebar;