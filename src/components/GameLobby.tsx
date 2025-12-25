import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import confetti from 'canvas-confetti';
import styles from './GameLobby.module.css';

const GameLobby: React.FC = () => {
    const { matchId } = useParams<{ matchId: string }>();
    const { user } = useAuth();
    const navigate = useNavigate();

    const [match, setMatch] = useState<any>(null);
    const [players, setPlayers] = useState<any[]>([]);
    const [messages, setMessages] = useState<any[]>([]);
    const [newMessage, setNewMessage] = useState('');
    const [lobbyCode, setLobbyCode] = useState('');
    const [isCaptain, setIsCaptain] = useState(false);
    const [codeSubmitted, setCodeSubmitted] = useState(false);
    const [timeRemaining, setTimeRemaining] = useState(180); // 3 minutes in seconds

    const messagesEndRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (matchId && user) {
            fetchMatchDetails();
            fetchMessages();

            // Realtime subscription for messages
            const channel = supabase
                .channel(`match:${matchId}`)
                .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'match_messages', filter: `match_id=eq.${matchId}` }, (payload) => {
                    setMessages((prev: any[]) => [...prev, payload.new]);
                })
                .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'matches', filter: `id=eq.${matchId}` }, (payload) => {
                    setMatch((prev: any) => ({ ...prev, ...payload.new }));
                })
                .subscribe();

            return () => { supabase.removeChannel(channel); };
        }
    }, [matchId, user]);

    // Timer countdown
    useEffect(() => {
        if (!match?.lobby_code && isCaptain) {
            const timer = setInterval(() => {
                setTimeRemaining((prev) => {
                    if (prev <= 1) {
                        clearInterval(timer);
                        return 0;
                    }
                    return prev - 1;
                });
            }, 1000);

            return () => clearInterval(timer);
        }
    }, [match?.lobby_code, isCaptain]);

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };

    const fetchMatchDetails = async () => {
        // Fetch match data
        const { data: matchData } = await supabase.from('matches').select('*').eq('id', matchId).single();
        if (matchData) {
            setMatch(matchData);
            setIsCaptain(matchData.captain_id === user?.telegram_id);
            if (matchData.lobby_code) {
                setCodeSubmitted(true);
            }
        }

        // Fetch players
        const { data: playerData } = await supabase
            .from('match_players')
            .select('*, user:users(username, telegram_id)')
            .eq('match_id', matchId);

        if (playerData) {
            setPlayers(playerData);
        }
    };

    const fetchMessages = async () => {
        const { data } = await supabase
            .from('match_messages')
            .select('*')
            .eq('match_id', matchId)
            .order('created_at', { ascending: true });
        if (data) setMessages(data);
    };

    const sendMessage = async () => {
        if (!newMessage.trim() || !user) return;

        try {
            const { error } = await supabase.from('match_messages').insert({
                match_id: matchId,
                user_id: user.telegram_id,
                username: user.username,
                message: newMessage.trim()
            });

            if (error) {
                console.error('Error sending message:', error);
                alert('Failed to send message. Please try again.');
                return;
            }

            setNewMessage('');
        } catch (err) {
            console.error('Chat error:', err);
            alert('Failed to send message. Please try again.');
        }
    };

    const submitCode = async () => {
        if (!lobbyCode || lobbyCode.length !== 7) {
            alert('Code must be exactly 7 digits!');
            return;
        }

        const { data, error } = await supabase.rpc('submit_lobby_code', {
            p_match_id: matchId,
            p_user_id: user?.telegram_id,
            p_code: lobbyCode
        });

        if (error || !data.success) {
            alert('Error submitting code');
        } else {
            // DOPAMINE RELEASE! 🎉
            confetti({
                particleCount: 200,
                spread: 100,
                origin: { y: 0.5 },
                colors: ['#00ff9d', '#ffd700', '#ffffff', '#00cc7a']
            });
            setCodeSubmitted(true);
        }
    };

    const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    if (!match) return <div className="text-white">Loading Lobby...</div>;

    return (
        <div className={styles.container}>
            <div className={styles.header}>
                <h2>Match Lobby</h2>
                <div className={styles.matchInfo}>
                    <span className={styles.badge}>{match.game_type}</span>
                    <span className={styles.badge}>Tier: {match.bet_tier}</span>
                    <span className={`${styles.badge} ${match.status === 'active' ? styles.active : ''}`}>{match.status}</span>
                </div>
            </div>

            <div className={styles.teamsGrid}>
                <div className={styles.team}>
                    <h3>Team A</h3>
                    {players.filter(p => p.team === 'A').map(p => (
                        <div key={p.user_id} className={styles.playerCard}>
                            {p.user?.username || 'Player'} {p.user_id === user?.telegram_id && '(You)'}
                        </div>
                    ))}
                </div>
                <div className={styles.vs}>VS</div>
                <div className={styles.team}>
                    <h3>Team B</h3>
                    {players.filter(p => p.team === 'B').map(p => (
                        <div key={p.user_id} className={styles.playerCard}>
                            {p.user?.username || 'Bot'}
                        </div>
                    ))}
                </div>
            </div>

            <div className={styles.lobbyCodeSection}>
                {codeSubmitted || match.lobby_code ? (
                    <div className={styles.codeConfirmed}>
                        <div className={styles.checkmark}>✓</div>
                        <h3>Code Confirmed!</h3>
                        <div className={styles.codeDisplay}>
                            <span className={styles.code}>{match.lobby_code}</span>
                            <button onClick={() => navigator.clipboard.writeText(match.lobby_code)} className={styles.copyBtn}>📋 Copy</button>
                        </div>
                    </div>
                ) : (
                    <div className={styles.pendingCode}>
                        {isCaptain ? (
                            <div className={styles.captainControls}>
                                <h3>You are the Captain! 👑</h3>
                                {timeRemaining > 0 ? (
                                    <>
                                        <div className={styles.timer}>
                                            ⏰ Time Remaining: <span className={styles.timerValue}>{formatTime(timeRemaining)}</span>
                                        </div>
                                        <p>Create the lobby in-game and paste the 7-digit code:</p>
                                        <div className={styles.inputGroup}>
                                            <input
                                                type="text"
                                                placeholder="1234567"
                                                maxLength={7}
                                                value={lobbyCode}
                                                onChange={(e) => setLobbyCode(e.target.value.replace(/[^0-9]/g, ''))}
                                                className={styles.codeInput}
                                            />
                                            <button onClick={submitCode} className={styles.submitBtn}>Confirm</button>
                                        </div>
                                    </>
                                ) : (
                                    <div className={styles.timeout}>
                                        <p>⏰ Time Expired! Match cancelled.</p>
                                    </div>
                                )}
                            </div>
                        ) : (
                            <p className={styles.waiting}>Waiting for Captain to set Lobby Code...</p>
                        )}
                    </div>
                )}
            </div>

            <div className={styles.chatSection}>
                <h3 className={styles.chatHeader}>Match Chat</h3>
                <div className={styles.chatBox}>
                    {messages.map(msg => (
                        <div key={msg.id} className={`${styles.msg} ${msg.user_id === user?.telegram_id ? styles.me : msg.user_id === null ? styles.system : ''}`}>
                            <span className={styles.sender}>{msg.username || 'System'}: </span>
                            {msg.message}
                        </div>
                    ))}
                    <div ref={messagesEndRef} />
                </div>
                <div className={styles.chatInput}>
                    <input
                        type="text"
                        value={newMessage}
                        onChange={(e) => setNewMessage(e.target.value)}
                        onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
                        placeholder="Type a message..."
                    />
                    <button onClick={sendMessage}>Send</button>
                </div>
            </div>

            <button className={styles.backBtn} onClick={() => navigate('/')}>← Back to Dashboard</button>
        </div>
    );
};

export default GameLobby;
