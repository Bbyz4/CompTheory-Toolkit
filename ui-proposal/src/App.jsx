import { useState } from 'react'
import {
    BrowserRouter as Router,
    Routes,
    Route,
} from "react-router-dom";
import Topbar from './scenes/global/Topbar'
import Sidebar from './scenes/global/Sidebar'
import Submissions from './scenes/submissions/Submissions'
import Tasks from './scenes/tasks/Tasks'
import Dashboard from './scenes/dashboard/Dashboard'
import Students from './scenes/students/Students'
import Settings from './scenes/settings/Settings'
import './App.css'

function App() {
  // const [count, setCount] = useState(0)

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
            </Routes> 
          </div>
        </main>
      </div>
    </Router>
  )
}

export default App
