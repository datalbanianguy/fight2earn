import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import GameSelector from './GameSelector';
import Faucet from './Faucet';
import DepositModal from './DepositModal';
import '../App.css'; // Verify path or move styles

const Dashboard: React.FC = () => {
    const { user, loading } = useAuth();
    const [showDeposit, setShowDeposit] = useState(false);

    if (loading) {
        return (
            <div className="skeleton-loader">
                <div className="skeleton-header"></div>
                <div className="skeleton-grid"></div>
            </div>
        );
    }

    return (
        <div className="app-container">
            <header className="app-header">
                <div className="user-info">
                    <h1>FightCoin Arena</h1>
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

                <div className="nav-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '20px' }}>
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
                </div>

                <GameSelector />
            </main>

            {showDeposit && <DepositModal onClose={() => setShowDeposit(false)} />}
        </div>
    );
};

export default Dashboard;
