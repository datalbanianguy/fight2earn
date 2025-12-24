import React from 'react';
import { useAuth } from '../context/AuthContext';
import styles from './Profile.module.css';

const Profile: React.FC = () => {
    const { user } = useAuth();

    if (!user) return <div className="text-white">Loading...</div>;


    return (
        <div className={styles.container}>
            <div className={styles.header}>
                <div className={styles.avatar}>{user.username?.charAt(0).toUpperCase()}</div>
                <h2>{user.username}</h2>
                <span className={styles.id}>ID: {user.telegram_id}</span>
            </div>

            <div className={styles.statsGrid}>
                <div className={styles.statCard}>
                    <span className={styles.label}>Games</span>
                    <span className={styles.value}>{user.games_played}</span>
                </div>
                <div className={styles.statCard}>
                    <span className={styles.label}>Winnings</span>
                    <span className={styles.value}>${user.total_winnings?.toFixed(2) || '0.00'}</span>
                </div>
                <div className={styles.statCard}>
                    <span className={styles.label}>Balance</span>
                    <span className={styles.value}>${user.balance_usdt.toFixed(2)}</span>
                </div>
            </div>

            <div className={styles.inviteSection}>
                <h3>Friend Invite Code</h3>
                <div className={styles.codeBox} onClick={() => {
                    navigator.clipboard.writeText(user.telegram_id.toString());
                    alert('Copied ID!');
                }}>
                    {user.telegram_id} <span className={styles.copyIcon}>📋</span>
                </div>
                <p className={styles.hint}>Share this code with friends to add them!</p>
            </div>
        </div>
    );
};

export default Profile;
