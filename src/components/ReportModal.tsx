import React, { useState } from 'react';
import styles from './ReportModal.module.css';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import WebApp from '@twa-dev/sdk';

interface ReportModalProps {
    matchId: string;
    targetId: number; // In real app, we'd list all players to pick from. For now, assuming direct or list.
    targetName: string;
    onClose: () => void;
}

const ReportModal: React.FC<ReportModalProps> = ({ matchId, targetId, targetName, onClose }) => {
    const { user } = useAuth();
    const [reason, setReason] = useState<string>('');
    const [comment, setComment] = useState('');
    const [submitting, setSubmitting] = useState(false);

    const handleSubmit = async () => {
        if (!reason || !user) return;
        setSubmitting(true);

        try {
            const { error } = await supabase.rpc('report_player', {
                p_match_id: matchId,
                p_reporter_id: user.telegram_id,
                p_target_id: targetId,
                p_reason: reason,
                p_comment: comment
            });

            if (error) throw error;

            WebApp.HapticFeedback.notificationOccurred('success');
            onClose(); // Close modal
            alert('Report submitted. Thank you for keeping the arena fair.');
        } catch (err) {
            console.error(err);
            WebApp.HapticFeedback.notificationOccurred('error');
            alert('Failed to submit report.');
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <div className={styles.overlay}>
            <div className={styles.modal}>
                <button className={styles.close} onClick={onClose}>×</button>
                <h3>Report {targetName}</h3>

                <div className={styles.reasons}>
                    {['Cheater', 'Bluestacks', 'AFK', 'Other'].map(r => (
                        <label key={r} className={styles.radio}>
                            <input
                                type="radio"
                                name="reason"
                                value={r}
                                checked={reason === r}
                                onChange={(e) => setReason(e.target.value)}
                            />
                            {r}
                        </label>
                    ))}
                </div>

                <textarea
                    placeholder="Additional details (optional)..."
                    className={styles.textarea}
                    value={comment}
                    onChange={(e) => setComment(e.target.value)}
                />

                <button
                    className={styles.submitBtn}
                    disabled={!reason || submitting}
                    onClick={handleSubmit}
                >
                    {submitting ? 'Sending...' : 'Submit Report'}
                </button>
            </div>
        </div>
    );
};

export default ReportModal;
