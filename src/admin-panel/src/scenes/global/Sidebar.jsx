import { NavLink } from 'react-router-dom';
import DashboardIcon from '@mui/icons-material/Dashboard';
import FeedIcon from '@mui/icons-material/Feed';
import PeopleIcon from '@mui/icons-material/People';
import SettingsIcon from '@mui/icons-material/Settings';
import TaskIcon from '@mui/icons-material/Task';

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: <DashboardIcon /> },
  { to: '/tasks', label: 'Tasks', icon: <TaskIcon /> },
  { to: '/submissions', label: 'Submissions', icon: <FeedIcon /> },
  { to: '/students', label: 'Students', icon: <PeopleIcon /> },
  { to: '/settings', label: 'Settings', icon: <SettingsIcon /> },
];

const Sidebar = () => {
  return (
    <div className="sidebar">
      <div className="sidebar-brand">
        <h1>Recognita</h1>
        <span className="sidebar-brand-subtitle">Admin workspace</span>
      </div>
      <ul>
        {navItems.map((item) => (
          <li key={item.to}>
            <NavLink
              to={item.to}
              className={({ isActive }) => (isActive ? 'active' : undefined)}
            >
              {item.icon}
              {item.label}
            </NavLink>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default Sidebar;
