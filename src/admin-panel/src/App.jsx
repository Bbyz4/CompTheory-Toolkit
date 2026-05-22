import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import Dashboard from './scenes/dashboard/Dashboard'
import Sidebar from './scenes/global/Sidebar'
import Topbar from './scenes/global/Topbar'
import Settings from './scenes/settings/Settings'
import Students from './scenes/students/Students'
import Submissions from './scenes/submissions/Submissions'
import Tasks from './scenes/tasks/Tasks'
import Verify from './scenes/verify/Verify'
import './App.css'

function App() {
  return (
    <Router>
      <div className="app">
        <Sidebar />
        <main className="main-content">
          <Topbar />
          <div className="content">
            <Routes> 
              <Route path="/" element={<Dashboard />} />
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/tasks" element={<Tasks />} />
              <Route path="/submissions" element={<Submissions />} />
              <Route path="/students" element={<Students />} />
              <Route path="/settings" element={<Settings />} />
              <Route path="/verify" element={<Verify />} />
              <Route path="*" element={<Dashboard />} />
            </Routes> 
          </div>
        </main>
      </div>
    </Router>
  )
}

export default App
