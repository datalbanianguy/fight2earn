import React, { useState, useEffect } from 'react';
import confetti from 'canvas-confetti';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import styles from './Faucet.module.css';
import { motion } from 'framer-motion';

const Faucet: React.FC = () => {
    const { user, refreshUser } = useAuth();
    const [loading, setLoading] = useState(false);
    const [timeLeft, setTimeLeft] = useState<string | null>(null);

    // Modal & Captcha State
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [verifying, setVerifying] = useState(false);
    const [captchaVerified, setCaptchaVerified] = useState(false);

    // Time Sync State
    const [serverTimeOffset, setServerTimeOffset] = useState<number | null>(null);

    // Sync with Server Time on Mount
    useEffect(() => {
        const syncTime = async () => {
            const startFetch = performance.now();
            const { data, error } = await supabase.rpc('get_server_time');

            if (!error && data) {
                const endFetch = performance.now();
                const latency = (endFetch - startFetch) / 2;
                const serverTime = new Date(data).getTime();
                setServerTimeOffset((serverTime + latency) - endFetch);
            } else {
                setServerTimeOffset(Date.now() - performance.now());
            }
        };
        syncTime();
    }, []);

    const calculateTimeLeft = () => {
        if (!user || !user.last_faucet_claim || serverTimeOffset === null) return null;
        // Check for null/epoch
        if (new Date(user.last_faucet_claim).getFullYear() === 2000) return null;

        const lastClaim = new Date(user.last_faucet_claim).getTime();
        const now = performance.now() + serverTimeOffset;
        const oneHour = 60 * 60 * 1000;
        const diff = now - lastClaim;

        if (diff < oneHour) {
            const remaining = oneHour - diff;
            const minutes = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));
            const seconds = Math.floor((remaining % (1000 * 60)) / 1000);
            // Format as MM:SS
            const paddedMinutes = minutes.toString().padStart(2, '0');
            const paddedSeconds = seconds.toString().padStart(2, '0');
            return `${paddedMinutes}:${paddedSeconds}`;
        }
        return null;
    };

    useEffect(() => {
        const timer = setInterval(() => {
            const remaining = calculateTimeLeft();
            setTimeLeft(remaining);
        }, 1000);

        if (serverTimeOffset !== null) {
            setTimeLeft(calculateTimeLeft());
        }

        return () => clearInterval(timer);
    }, [user, serverTimeOffset]);

    // 1. Initial Click on Main Button
    const handleInitialClaimClick = () => {
        if (timeLeft || loading) return;
        setIsModalOpen(true);
        setCaptchaVerified(false); // Reset state
    };

    // 2. Clicking the Checkbox
    const handleCaptchaClick = () => {
        if (captchaVerified || verifying) return;
        setVerifying(true);

        // Simulate Network Verify
        setTimeout(() => {
            setVerifying(false);
            setCaptchaVerified(true);
        }, 1500);
    };

    // 3. Final Verify & Claim
    const handleVerifyAndClaim = async () => {
        if (!captchaVerified) return;

        setLoading(true);
        try {
            const { data, error } = await supabase.rpc('claim_faucet', {
                user_id: user?.telegram_id
            });

            if (error) throw error;

            if (data && data.success) {
                // Success!
                setIsModalOpen(false); // Close modal
                confetti({
                    particleCount: 150,
                    spread: 70,
                    origin: { y: 0.6 },
                    colors: ['#ffd700', '#00ff9d', '#ffffff']
                });

                await refreshUser();
            } else {
                alert('Failed to claim: ' + (data?.message || 'Unknown error'));
            }
        } catch (error) {
            console.error('Faucet Error:', error);
            alert('Error claiming faucet');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className={styles.faucetWrapper}>
            {/* Main Claim Button */}
            <motion.button
                className={`${styles.button} ${timeLeft ? styles.disabled : ''}`}
                onClick={handleInitialClaimClick}
                disabled={!!timeLeft || loading}
                whileTap={!timeLeft ? { scale: 0.95 } : {}}
            >
                {loading ? 'Processing...' : (timeLeft ? `Claimed (${timeLeft} left to claim)` : '🎁 Claim 1.00 FC')}
            </motion.button>

            {/* Captcha Verify Modal */}
            {isModalOpen && (
                <div className={styles.captchaModal}>
                    <div className={styles.captchaBox}>
                        <button className={styles.closeModal} onClick={() => setIsModalOpen(false)}>×</button>
                        <h3>Security Check</h3>
                        <p style={{ marginBottom: '20px', color: '#ccc' }}>Please verify you are human to claim.</p>

                        {/* Fake reCAPTCHA Box */}
                        <div className={styles.recaptchaRow}>
                            <div className={styles.recaptchaLeft}>
                                <div
                                    className={`${styles.checkbox} ${captchaVerified ? styles.verified : ''}`}
                                    onClick={handleCaptchaClick}
                                >
                                    {verifying && <div className={styles.spinner}></div>}
                                    {captchaVerified && <span className={styles.checkMark}>✓</span>}
                                </div>
                                <span className={styles.captchaLabel}>I am not a robot</span>
                            </div>
                            <div className={styles.recaptchaLogo}>
                                <img src="https://www.gstatic.com/recaptcha/api2/logo_48.png" alt="" className={styles.rcLogoImg} />
                                <span className={styles.rcText}>reCAPTCHA</span>
                            </div>
                        </div>

                        <button
                            className={styles.verifyBtn}
                            onClick={handleVerifyAndClaim}
                            disabled={!captchaVerified || loading}
                        >
                            {loading ? 'Claiming...' : 'Verify & Claim'}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};

export default Faucet;
