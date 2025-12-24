import React, { useEffect, useState } from 'react';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import styles from './Lobby.module.css';
import WebApp from '@twa-dev/sdk';
import ReportModal from './ReportModal';

interface LobbyProps {
    matchId: string;
    isCaptain: boolean;
}

const Lobby: React.FC<LobbyProps> = ({ matchId, isCaptain }) => {
    const { user } = useAuth();
    const [lobbyCode, setLobbyCode] = useState<string | null>(null);
    const [timeLeft, setTimeLeft] = useState(180); // 3 minutes
    const [status, setStatus] = useState('waiting');

    // New States for Features
    const [showReport, setShowReport] = useState(false);
    const [editingCode, setEditingCode] = useState(false);

    useEffect(() => {
        // Realtime Subscription
        const channel = supabase
            .channel(`match_${matchId}`)
            .on('postgres_changes', {
                event: 'UPDATE',
                schema: 'public',
                table: 'matches',
                filter: `id=eq.${matchId}`
            }, (payload) => {
                const newData = payload.new as any;
                if (newData.lobby_code) setLobbyCode(newData.lobby_code);
                if (newData.status) setStatus(newData.status);
            })
            .subscribe();

        return () => { supabase.removeChannel(channel); };
    }, [matchId]);

    useEffect(() => {
        if (timeLeft <= 0) return;
        const timer = setInterval(() => {
            setTimeLeft(t => {
                if (t <= 1) {
                    // Handle timeout (logic migrated previously)
                    return 0;
                }
                return t - 1;
            });
        }, 1000);
        return () => clearInterval(timer);
    }, [timeLeft]);

    const handleSubmitCode = async (code: string) => {
        if (code.length !== 7) return;

        await supabase.rpc('submit_lobby_code', {
            p_match_id: matchId,
            p_user_id: user?.telegram_id,
            p_code: code
        });
        setEditingCode(false);
        WebApp.HapticFeedback.notificationOccurred('success');
    };

    const formatTime = (seconds: number) => {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${m}:${s < 10 ? '0' : ''}${s}`;
    };

    if (status === 'aborted') {
        return (
            <div className={styles.container}>
                <h2 style={{ color: 'red' }}>MATCH ABORTED</h2>
                <p>Captain failed to create lobby.</p>
                <p>Your bet has been refunded.</p>
            </div>
        );
    }

    return (
        <div className={styles.container}>
            <h2>Lobby Room</h2>
            <button className={styles.reportBtn} onClick={() => setShowReport(true)}>⚠️ Report Issue</button>

            <div className={styles.timer}>
                Time Remaining: <span style={{ color: timeLeft < 60 ? 'red' : 'white' }}>{formatTime(timeLeft)}</span>
            </div>

            {isCaptain ? (
                <div className={styles.captainZone}>
                    <h3>👑 YOU ARE CAPTAIN</h3>
                    <p>Create the Tournament Lobby and enter the 7-digit code below.</p>

                    {(!lobbyCode || editingCode) ? (
                        <div className={styles.editContainer}>
                            <input
                                type="text"
                                placeholder="1234567"
                                maxLength={7}
                                className={styles.input}
                                defaultValue={lobbyCode || ''}
                                onChange={(e) => {
                                    if (e.target.value.length === 7) handleSubmitCode(e.target.value);
                                }}
                            />
                            {editingCode && <button onClick={() => setEditingCode(false)}>Cancel</button>}
                        </div>
                    ) : (
                        <div className={styles.success}>
                            Code Submitted: <strong>{lobbyCode}</strong>
                            <button className={styles.editBtn} onClick={() => setEditingCode(true)}>✏️ Edit</button>
                        </div>
                    )}
                    <p className={styles.warning}>Failure to submit in time results in a 0.50 USDT fine.</p>
                </div>
            ) : (
                <div className={styles.playerZone}>
                    <h3>Waiting for Captain...</h3>
                    {lobbyCode ? (
                        <div className={styles.codeDisplay}>
                            CODE: <span>{lobbyCode}</span>
                            <button onClick={() => {
                                navigator.clipboard.writeText(lobbyCode);
                                WebApp.HapticFeedback.impactOccurred('light');
                            }}>Copy</button>
                        </div>
                    ) : (
                        <div className={styles.skeleton}>Thinking...</div>
                    )}
                </div>
            )}

            {status === 'active' && (
                <div className={styles.uploadZone}>
                    <h4>Match in Progress</h4>
                    <p>Upon completion, upload screenshot to claim victory.</p>
                    <input type="file" disabled className={styles.fileInput} />
                </div>
            )}

            {showReport && (
                <ReportModal
                    matchId={matchId}
                    targetId={0} // TODO: select player logic 
                    targetName="Specific Player"
                    onClose={() => setShowReport(false)}
                />
            )}
        </div>
    );
};

export default Lobby;
