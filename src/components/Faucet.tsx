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

    // Captcha State
    const [captchaVerified, setCaptchaVerified] = useState(false);
    const [verifying, setVerifying] = useState(false); // For spinner effect
    const [showMathModal, setShowMathModal] = useState(false);
    const [mathProblem, setMathProblem] = useState({ a: 0, b: 0 });
    const [userAnswer, setUserAnswer] = useState('');

    // Time Sync State
    const [serverTimeOffset, setServerTimeOffset] = useState<number | null>(null);

    // Sync with Server Time on Mount
    useEffect(() => {
        const syncTime = async () => {
            const startFetch = performance.now();
            const { data, error } = await supabase.rpc('get_server_time');

            if (!error && data) {
                const endFetch = performance.now();
                // Estimate latency to adjust server time more accurately
                const latency = (endFetch - startFetch) / 2;
                const serverTime = new Date(data).getTime();

                // Offset = (ServerTime - LocalPerformanceTime)
                // We use performance.now() because it's monotonic and robust against system clock changes
                // The 'now' value we want is: serverTime + (performance.now() - endFetch) roughly
                // Actually: serverTime is time at server receipt.
                // client received at endFetch.
                // So at endFetch, true time is serverTime + latency.
                // So offset = (serverTime + latency) - endFetch
                setServerTimeOffset((serverTime + latency) - endFetch);
            } else {
                // Fallback to local time if sync fails (less secure but functional)
                // Offset = (LocalTime - performance.now())
                setServerTimeOffset(Date.now() - performance.now());
                console.error('Time Sync Error:', error);
            }
        };

        syncTime();
    }, []);

    const calculateTimeLeft = () => {
        if (!user || !user.last_faucet_claim || serverTimeOffset === null) return null;
        if (new Date(user.last_faucet_claim).getFullYear() === 2000) return null;

        const lastClaim = new Date(user.last_faucet_claim).getTime();

        // Secure Current Time: Offset + Monotonic Elapsed
        // CurrentTime = PerformanceNow + Offset
        const now = performance.now() + serverTimeOffset;

        const oneHour = 60 * 60 * 1000;
        const diff = now - lastClaim;

        if (diff < oneHour) {
            const remaining = oneHour - diff;
            const minutes = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));
            const seconds = Math.floor((remaining % (1000 * 60)) / 1000);
            return `${minutes}m ${seconds}s`;
        }
        return null; // Available!
    };

    useEffect(() => {
        const timer = setInterval(() => {
            const remaining = calculateTimeLeft();
            setTimeLeft(remaining);

            // If cooldown became active or inactive, we might want to reset captcha
            if (remaining) {
                setCaptchaVerified(false);
            }
        }, 1000);

        // Initial check if we have the offset
        if (serverTimeOffset !== null) {
            setTimeLeft(calculateTimeLeft());
        }

        return () => clearInterval(timer);
    }, [user, serverTimeOffset]);

    const handleCaptchaClick = () => {
        if (captchaVerified || verifying || timeLeft) return;

        setVerifying(true);
        // Simulate "Network Check" delay
        setTimeout(() => {
            setVerifying(false);
            // Generate Math Problem
            const a = Math.floor(Math.random() * 10) + 1;
            const b = Math.floor(Math.random() * 10) + 1;
            setMathProblem({ a, b });
            setShowMathModal(true);
        }, 800);
    };

    const verifyMath = () => {
        if (parseInt(userAnswer) === mathProblem.a + mathProblem.b) {
            setShowMathModal(false);
            setCaptchaVerified(true);
            setUserAnswer('');
        } else {
            alert('Incorrect. Try again.');
            // Generate new problem
            setMathProblem({
                a: Math.floor(Math.random() * 10) + 1,
                b: Math.floor(Math.random() * 10) + 1
            });
            setUserAnswer('');
        }
    };

    const handleClaim = async () => {
        // Strict check: Must not have time left.
        if (timeLeft) return;

        // Captcha check
        if (!captchaVerified) {
            alert('Please complete the captcha verification first.');
            return;
        }

        if (loading) return;

        setLoading(true);
        try {
            const { data, error } = await supabase.rpc('claim_faucet', {
                user_id: user?.telegram_id
            });

            if (error) throw error;

            if (data && data.success) {
                confetti({
                    particleCount: 150,
                    spread: 70,
                    origin: { y: 0.6 },
                    colors: ['#ffd700', '#00ff9d', '#ffffff']
                });

                await refreshUser();
                setCaptchaVerified(false); // Reset captcha
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
            {/* Show Captcha ONLY if Claim is available (no timer) */}
            {!timeLeft && !loading && (
                <div className={styles.captchaContainer} onClick={handleCaptchaClick}>
                    <div className={`${styles.checkbox} ${captchaVerified ? styles.verified : ''}`}>
                        {verifying && <div className={styles.spinner}></div>}
                        {captchaVerified && <span className={styles.checkMark}>✓</span>}
                    </div>
                    <span className={styles.captchaText}>I am not a robot</span>
                </div>
            )}

            <motion.button
                className={`${styles.button} ${(!captchaVerified && !timeLeft) ? styles.disabled : ''} ${timeLeft ? styles.disabled : ''}`}
                onClick={handleClaim}
                whileTap={(captchaVerified && !timeLeft) ? { scale: 0.9 } : {}}
                disabled={!!timeLeft || loading || (!captchaVerified)}
            >
                {loading ? 'Claiming...' : (timeLeft ? `Cooldown: ${timeLeft}` : '🎁 Claim 1.00 FC')}
            </motion.button>

            {/* Math Challenge Modal */}
            {showMathModal && (
                <div className={styles.mathChallengeModal}>
                    <div className={styles.mathBox}>
                        <h3>Security Check</h3>
                        <p>Solve: {mathProblem.a} + {mathProblem.b} = ?</p>
                        <input
                            type="number"
                            className={styles.mathInput}
                            value={userAnswer}
                            onChange={(e) => setUserAnswer(e.target.value)}
                            autoFocus
                            onKeyDown={(e) => e.key === 'Enter' && verifyMath()}
                        />
                        <br />
                        <button className={styles.verifyBtn} onClick={verifyMath}>Verify</button>
                    </div>
                </div>
            )}
        </div>
    );
};

export default Faucet;
