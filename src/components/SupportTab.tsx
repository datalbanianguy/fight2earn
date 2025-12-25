import React, { useState } from 'react';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import styles from './SupportTab.module.css';
import WebApp from '@twa-dev/sdk';

const SupportTab: React.FC = () => {
    const { user } = useAuth();
    const [feedbackType, setFeedbackType] = useState<'bug' | 'feature_request' | 'other'>('bug');
    const [message, setMessage] = useState('');
    const [submitted, setSubmitted] = useState(false);
    const [loading, setLoading] = useState(false);

    const handleSubmit = async () => {
        if (!message.trim() || !user) {
            alert('Please enter a message');
            return;
        }

        setLoading(true);

        try {
            const { error } = await supabase.rpc('submit_feedback', {
                p_user_id: user.telegram_id,
                p_username: user.username,
                p_feedback_type: feedbackType,
                p_message: message.trim()
            });

            if (error) throw error;

            WebApp.HapticFeedback.notificationOccurred('success');
            setSubmitted(true);
            setMessage('');

            setTimeout(() => setSubmitted(false), 3000);
        } catch (err) {
            console.error('Feedback error:', err);
            alert('Failed to submit feedback. Please try again.');
            WebApp.HapticFeedback.notificationOccurred('error');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className={styles.container}>
            <div className={styles.header}>
                <h2>📩 Support & Feedback</h2>
                <p>Report bugs, request features, or share your thoughts</p>
            </div>

            {submitted ? (
                <div className={styles.successMessage}>
                    <div className={styles.checkmark}>✓</div>
                    <h3>Thank you!</h3>
                    <p>Your feedback has been submitted successfully.</p>
                </div>
            ) : (
                <div className={styles.form}>
                    <div className={styles.typeSelector}>
                        <button
                            className={feedbackType === 'bug' ? styles.active : ''}
                            onClick={() => setFeedbackType('bug')}
                        >
                            🐛 Bug Report
                        </button>
                        <button
                            className={feedbackType === 'feature_request' ? styles.active : ''}
                            onClick={() => setFeedbackType('feature_request')}
                        >
                            💡 Feature Request
                        </button>
                        <button
                            className={feedbackType === 'other' ? styles.active : ''}
                            onClick={() => setFeedbackType('other')}
                        >
                            💬 Other
                        </button>
                    </div>

                    <textarea
                        className={styles.textarea}
                        placeholder={
                            feedbackType === 'bug'
                                ? 'Describe the bug you encountered...'
                                : feedbackType === 'feature_request'
                                    ? 'Describe the feature you\'d like to see...'
                                    : 'Share your feedback...'
                        }
                        value={message}
                        onChange={(e) => setMessage(e.target.value)}
                        rows={8}
                    />

                    <button
                        className={styles.submitBtn}
                        onClick={handleSubmit}
                        disabled={loading || !message.trim()}
                    >
                        {loading ? 'Submitting...' : 'Submit Feedback'}
                    </button>
                </div>
            )}

            <div className={styles.info}>
                <p><strong>Note:</strong> We review all feedback and will address issues as quickly as possible.</p>
            </div>
        </div>
    );
};

export default SupportTab;
