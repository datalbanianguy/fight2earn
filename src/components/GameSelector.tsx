import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import WebApp from '@twa-dev/sdk';
import styles from './GameSelector.module.css';
import MatchmakingModal from './MatchmakingModal';

const games = [
    { id: 'wild_rift', name: 'Wild Rift', players: '5v5', icon: '⚔️', image: '/wild-rift-logo.png', color: 'linear-gradient(135deg, #1fa2ff, #12d8fa, #a6ffcb)' },
    { id: 'brawl_stars', name: 'Brawl Stars', players: '3v3', icon: '⭐', image: null, color: 'linear-gradient(135deg, #ff0844, #ffb199)' },
    { id: 'cs2', name: 'CS2', players: '5v5', icon: '🔫', image: null, color: 'linear-gradient(135deg, #f6d365, #fda085)' },
];

const GameSelector: React.FC = () => {
    const [selectedGame, setSelectedGame] = useState<string | null>(null);
    const navigate = useNavigate();

    const handleGameClick = (gameId: string) => {
        // Haptic Feedback
        if (WebApp.initDataUnsafe?.user) {
            WebApp.HapticFeedback.impactOccurred('medium');
        }
        setSelectedGame(gameId);
    };

    return (
        <>
            <div className={styles.container}>
                <h2 className={styles.title}>Choose Your Arena</h2>
                <div className={styles.grid}>
                    {games.map((game) => (
                        <motion.div
                            key={game.id}
                            className={styles.card}
                            style={{ background: game.color }}
                            whileTap={{ scale: 0.95 }}
                            onClick={() => handleGameClick(game.id)}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ type: 'spring', stiffness: 300 }}
                        >
                            {game.image ? (
                                <img src={game.image} alt={game.name} className={styles.gameLogo} />
                            ) : (
                                <div className={styles.icon}>{game.icon}</div>
                            )}
                            <div className={styles.info}>
                                <h3>{game.name}</h3>
                                <p>{game.players}</p>
                            </div>
                        </motion.div>
                    ))}
                </div>
            </div>
            {selectedGame && (
                <MatchmakingModal
                    gameId={selectedGame}
                    onClose={() => setSelectedGame(null)}
                    onMatchFound={(matchId) => {
                        setSelectedGame(null);
                        navigate(`/lobby/${matchId}`);
                    }}
                />
            )}
        </>
    );
};

export default GameSelector;
