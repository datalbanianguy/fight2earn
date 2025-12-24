import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import styles from './MatchmakingModal.module.css';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import WebApp from '@twa-dev/sdk';

interface MatchmakingModalProps {
    gameId: string | null;
    onClose: () => void;
    onMatchFound: (matchId: string) => void;
}

type Step = 'mode' | 'currency' | 'bet' | 'searching';

const MatchmakingModal: React.FC<MatchmakingModalProps> = ({ gameId, onClose, onMatchFound }) => {
    const { user } = useAuth();
    const [step, setStep] = useState<Step>('mode');
    const [mode, setMode] = useState<'1v1' | '5v5' | null>(null);
    const [currency, setCurrency] = useState<'USDT' | 'FC' | null>(null);
    const [bet, setBet] = useState<number | null>(null);
    const [status, setStatus] = useState('Finding match...');

    if (!gameId) return null;

    const handleNext = (nextStep: Step) => {
        WebApp.HapticFeedback.impactOccurred('light');
        setStep(nextStep);
    };

    const handleSimulateBotMatch = async () => {
        if (!user || !gameId) return;
        setStatus('Generating Bot Match...');
        handleNext('searching');

        const { data, error } = await supabase.rpc('create_bot_match', {
            p_user_id: user.telegram_id,
            p_game_type: gameId,
            p_mode: '1v1',
            p_currency: 'USDT',
            p_bet_amount: 0.01
        });

        if (error) {
            console.error(error);
            setStatus('Error creating match');
            return;
        }

        if (data && data.success) {
            WebApp.HapticFeedback.notificationOccurred('success');
            setTimeout(() => onMatchFound(data.match_id), 1000);
        }
    };

    const handleFindMatch = async (selectedBet: number) => {
        setBet(selectedBet);
        handleNext('searching');

        if (!user || !mode || !currency) return;

        // Simple Region Detection
        const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        let region = 'Global';
        if (timeZone.startsWith('Europe')) region = 'Europe';
        else if (timeZone.startsWith('America')) region = 'North America';
        else if (timeZone.startsWith('Asia')) region = 'Asia';
        else if (timeZone.startsWith('Africa')) region = 'Africa';

        try {
            const { data, error } = await supabase.rpc('join_queue', {
                p_user_id: user.telegram_id,
                p_game_type: gameId,
                p_mode: mode,
                p_currency: currency,
                p_bet_amount: selectedBet,
                p_region: region
            });

            if (error) throw error;

            console.log('Queue Result:', data);

            if (data && data.status === 'match_found') {
                setStatus('Match Found! Generating Lobby...');
                WebApp.HapticFeedback.notificationOccurred('success');
                setTimeout(() => onMatchFound(data.match_id), 1500);
            } else {
                setStatus('Queued. Waiting for players...');
            }

        } catch (err) {
            console.error(err);
            setStatus('Error joining queue.');
            WebApp.HapticFeedback.notificationOccurred('error');
        }
    };

    return (
        <div className={styles.overlay}>
            <motion.div
                className={styles.modal}
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
            >
                <button className={styles.close} onClick={onClose}>×</button>

                <AnimatePresence mode="wait">
                    {step === 'mode' && (
                        <motion.div key="mode" initial={{ x: 20, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -20, opacity: 0 }}>
                            <h3>Select Mode</h3>
                            <div className={styles.options}>
                                <button onClick={() => { setMode('1v1'); handleNext('currency'); }}>1 vs 1</button>
                                <button onClick={() => { setMode('5v5'); handleNext('currency'); }}>5 vs 5</button>
                            </div>
                            <div style={{ marginTop: '20px', borderTop: '1px solid #444', paddingTop: '15px' }}>
                                <button
                                    style={{ background: '#333', width: '100%', padding: '12px', borderRadius: '8px', border: '1px dashed #666', color: '#aaa' }}
                                    onClick={handleSimulateBotMatch}
                                >
                                    🤖 Quick Test vs Bot
                                </button>
                            </div>
                        </motion.div>
                    )}

                    {step === 'currency' && (
                        <motion.div key="currency" initial={{ x: 20, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -20, opacity: 0 }}>
                            <h3>Select Currency</h3>
                            <div className={styles.options}>
                                <button onClick={() => { setCurrency('USDT'); handleNext('bet'); }}>USDT</button>
                                <button onClick={() => { setCurrency('FC'); handleNext('bet'); }}>FightCoin</button>
                            </div>
                        </motion.div>
                    )}

                    {step === 'bet' && (
                        <motion.div key="bet" initial={{ x: 20, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -20, opacity: 0 }}>
                            <h3>Select Bet</h3>
                            <div className={styles.grid}>
                                {[1, 5, 50, 500].map(amount => (
                                    <button key={amount} onClick={() => handleFindMatch(amount)}>
                                        {amount} {currency}
                                    </button>
                                ))}
                            </div>
                        </motion.div>
                    )}

                    {step === 'searching' && (
                        <motion.div key="searching" initial={{ scale: 0.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className={styles.searching}>
                            <div className={styles.loader}></div>
                            <h3>{status}</h3>
                            <p>{mode} • {bet} {currency}</p>
                        </motion.div>
                    )}
                </AnimatePresence>
            </motion.div>
        </div>
    );
};

export default MatchmakingModal;
