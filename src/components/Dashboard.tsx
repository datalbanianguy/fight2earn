import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import GameSelector from './GameSelector';
import Faucet from './Faucet';
import DepositModal from './DepositModal';
import LoadingScreen from './LoadingScreen';
import '../App.css'; // Verify path or move styles

const Dashboard: React.FC = () => {
    const { user, loading } = useAuth();
    const [showDeposit, setShowDeposit] = useState(false);

    if (loading) {
        return <LoadingScreen />;
    }

    return (
        <div className="app-container">
            <header className="app-header">
                <div className="header-left">
                    <div className="logo-container">
                        <img src="/fight-coin-logo.jpg" alt="Logo" className="dashboard-logo" />
                    </div>
                </div>

                <div className="user-info centered-title">
                    <h1 className="stacked-title">
                        <span>FIGHTCOIN</span>
                        <span className="arena-subtext">ARENA</span>
                    </h1>
                    <p>Welcome, <span className="username">{user?.username || 'Fighter'}</span></p>
                </div>

                <div className="balance-info">
                    <div className="balance-item">
                        <span className="label">USDT</span>
                        <span className="value text-green">${user?.balance_usdt?.toFixed(2) || '0.00'}</span>
                    </div>
                    <div className="balance-item">
                        <span className="label">FC</span>
                        <span className="value text-gold">{user?.balance_fc?.toFixed(4) || '0.0000'}</span>
                    </div>
                    <button className="deposit-btn" onClick={() => setShowDeposit(true)}>+ Deposit</button>
                </div>
            </header>

            <main>
                <Faucet />

                <div className="nav-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px', marginTop: '20px' }}>
                    <button className="nav-btn" onClick={() => window.location.href = '/profile'} style={{
                        background: '#333', border: '1px solid #444', padding: '15px', borderRadius: '12px', color: 'white', fontWeight: 'bold'
                    }}>
                        👤 Profile
                    </button>
                    <button className="nav-btn" onClick={() => window.location.href = '/friends'} style={{
                        background: '#333', border: '1px solid #444', padding: '15px', borderRadius: '12px', color: 'white', fontWeight: 'bold'
                    }}>
                        👥 Friends
                    </button>
                    <button className="nav-btn" onClick={() => window.location.href = '/support'} style={{
                        background: '#333', border: '1px solid #444', padding: '15px', borderRadius: '12px', color: 'white', fontWeight: 'bold'
                    }}>
                        📩 Support
                    </button>
                </div>

                <GameSelector />
            </main>

            {showDeposit && <DepositModal onClose={() => setShowDeposit(false)} />}

            <div style={{ textAlign: 'center', padding: '10px', fontSize: '0.8rem', color: '#666' }}>
                Site Version: v1.2 (Netlify Configured)
            </div>
        </div >
    );
};

export default Dashboard;
