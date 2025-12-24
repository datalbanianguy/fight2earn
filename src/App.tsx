import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import Dashboard from './components/Dashboard';
import Admin from './components/Admin';
import Profile from './components/Profile';
import FriendsDashboard from './components/FriendsDashboard';
import GameLobby from './components/GameLobby';
import WebApp from '@twa-dev/sdk';
import './App.css';

const App: React.FC = () => {
  useEffect(() => {
    WebApp.expand();
    WebApp.ready();
  }, []);

  return (
    <Router>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/admin" element={<Admin />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/friends" element={<FriendsDashboard />} />
          <Route path="/lobby/:matchId" element={<GameLobby />} />
        </Routes>
      </AuthProvider>
    </Router>
  );
};

export default App;
