import React, { useEffect, useState } from 'react';
import { supabase } from '../supabaseClient';
import styles from './Admin.module.css';

const Admin: React.FC = () => {
    const [matches, setMatches] = useState<any[]>([]);
    const [deposits, setDeposits] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        const { data: mData } = await supabase.from('matches').select('*').order('created_at', { ascending: false }).limit(10);
        const { data: dData } = await supabase.from('deposits').select('*').order('created_at', { ascending: false }).limit(10);

        if (mData) setMatches(mData);
        if (dData) setDeposits(dData);
        setLoading(false);
    };

    const verifyDeposit = async (id: string) => {
        await supabase.from('deposits').update({ status: 'completed', confirmations: 3 }).eq('id', id);
        fetchData(); // Refresh
    };

    if (loading) {
        return <div className={styles.container}>Loading Admin Data...</div>;
    }

    return (
        <div className={styles.container}>
            <h2>Admin Dashboard</h2>

            <div className={styles.section}>
                <h3>Recent Matches</h3>
                <div className={styles.list}>
                    {matches.map(m => (
                        <div key={m.id} className={styles.item}>
                            <span>{m.game_type} ({m.bet_tier})</span>
                            <span className={m.status === 'active' ? styles.active : styles.finished}>{m.status}</span>
                        </div>
                    ))}
                </div>
            </div>

            <div className={styles.section}>
                <h3>Recent Deposits</h3>
                <div className={styles.list}>
                    {deposits.map(d => (
                        <div key={d.id} className={styles.item}>
                            <span>{d.amount} {d.currency}</span>
                            <span className={styles.status}>{d.status}</span>
                            {d.status === 'pending' && (
                                <button onClick={() => verifyDeposit(d.id)}>Verify</button>
                            )}
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default Admin;
