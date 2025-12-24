import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import styles from './FriendsDashboard.module.css';

const FriendsDashboard: React.FC = () => {
    const { user } = useAuth();
    const [friendCode, setFriendCode] = useState('');
    const [friends, setFriends] = useState<any[]>([]);
    const [view, setView] = useState<'friends' | 'party'>('friends');
    const [party, setParty] = useState<any>(null);

    useEffect(() => {
        if (user) fetchFriends();
    }, [user]);

    const fetchFriends = async () => {
        if (!user) return;
        // Fetch accepted friends
        const { data, error } = await supabase
            .from('friends')
            .select('*')
            .or(`user_id_1.eq.${user.telegram_id},user_id_2.eq.${user.telegram_id}`)
            .eq('status', 'accepted'); // Show pending too? For now accepted.

        if (!error && data) {
            // Need to fetch user details for friend IDs
            // This requires a JOIN or separate fetch. keeping simple for mock.
            setFriends(data);
        }
    };

    const addFriend = async () => {
        if (!user) return;
        const { data, error } = await supabase.rpc('send_friend_request', {
            p_requester_id: user.telegram_id,
            p_target_code: friendCode
        });

        if (error || !data.success) {
            alert(data?.message || 'Error adding friend');
        } else {
            alert('Request sent!');
            setFriendCode('');
        }
    };

    const createParty = async () => {
        if (!user) return;
        const { data, error } = await supabase.rpc('create_party', {
            p_user_id: user.telegram_id
        });

        if (error || !data.success) {
            alert('Error creating party');
        } else {
            setParty(data);
            setView('party');
        }
    };

    const joinParty = async () => {
        const code = prompt('Enter Party Code:');
        if (!code) return;

        const { data } = await supabase.rpc('join_party', {
            p_user_id: user!.telegram_id,
            p_code: code
        });

        if (data?.success) {
            setParty(data); // In reality, fetch full party details
            setView('party');
        } else {
            alert(data?.message || 'Failed to join');
        }
    };

    return (
        <div className={styles.container}>
            <div className={styles.tabs}>
                <button
                    className={`${styles.tab} ${view === 'friends' ? styles.active : ''}`}
                    onClick={() => setView('friends')}
                >
                    Friends
                </button>
                <button
                    className={`${styles.tab} ${view === 'party' ? styles.active : ''}`}
                    onClick={() => setView('party')}
                >
                    Party
                </button>
            </div>

            {view === 'friends' && (
                <div className={styles.content}>
                    <div className={styles.addFriendBox}>
                        <input
                            type="text"
                            placeholder="Enter Friend ID/Code"
                            value={friendCode}
                            onChange={(e) => setFriendCode(e.target.value)}
                            className={styles.input}
                        />
                        <button onClick={addFriend} className={styles.actionBtn}>Add</button>
                    </div>

                    <div className={styles.list}>
                        {friends.length === 0 ? (
                            <p className={styles.empty}>No friends yet. Share your code!</p>
                        ) : (
                            friends.map(f => (
                                <div key={f.id} className={styles.listItem}>
                                    Friend #{f.user_id_1 === user?.telegram_id ? f.user_id_2 : f.user_id_1}
                                </div>
                            ))
                        )}
                    </div>
                </div>
            )}

            {view === 'party' && (
                <div className={styles.content}>
                    {!party ? (
                        <div className={styles.partyActions}>
                            <button onClick={createParty} className={styles.createBtn}>Create Party</button>
                            <button onClick={joinParty} className={styles.joinBtn}>Join Party</button>
                        </div>
                    ) : (
                        <div className={styles.partyLobby}>
                            <h3>Party Code: {party.code || '...'}</h3>
                            <p>Waiting for leader to queue...</p>
                            <button onClick={() => setParty(null)} className={styles.dangerBtn}>Leave Party</button>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

export default FriendsDashboard;
