import React, { useState, useEffect } from 'react';
import styles from './DepositModal.module.css';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { QRCodeSVG } from 'qrcode.react';
import WebApp from '@twa-dev/sdk';

interface DepositModalProps {
    onClose: () => void;
}

const tokens = [
    { id: 'USDT', name: 'Tether (TRC20)', network: 'TRC20', color: '#26a17b' },
    { id: 'SOL', name: 'Solana', network: 'SOL', color: '#9945ff' },
    { id: 'ETH', name: 'Ethereum', network: 'ERC20', color: '#627eea' },
    { id: 'LTC', name: 'Litecoin', network: 'LTC', color: '#345d9d' },
];

const DepositModal: React.FC<DepositModalProps> = ({ onClose }) => {
    const { user } = useAuth();
    const [selectedToken, setSelectedToken] = useState<typeof tokens[0] | null>(null);
    const [address, setAddress] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const [simulatedPrice, setSimulatedPrice] = useState<string>('Loading...');

    // Mock Live Price Feed
    useEffect(() => {
        if (!selectedToken) return;
        setSimulatedPrice('Fetching...');
        const timer = setTimeout(() => {
            // Mock prices
            const prices: Record<string, string> = {
                'USDT': '1.00 USDT = $1.00',
                'SOL': '1.00 SOL = $145.20',
                'ETH': '1.00 ETH = $3200.50',
                'LTC': '1.00 LTC = $85.10'
            };
            setSimulatedPrice(prices[selectedToken.id]);
        }, 800);
        return () => clearTimeout(timer);
    }, [selectedToken]);

    const handleSelect = async (token: typeof tokens[0]) => {
        setSelectedToken(token);
        setLoading(true);
        // Fetch/Create Deposit Address
        try {
            const { data, error } = await supabase.rpc('create_deposit_intent', {
                p_user_id: user?.telegram_id,
                p_currency: token.id,
                p_network: token.network
            });

            if (error) throw error;
            setAddress(data.address);
            WebApp.HapticFeedback.impactOccurred('medium');
        } catch (err) {
            console.error(err);
            alert('Error creating deposit address');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className={styles.overlay}>
            <div className={styles.modal}>
                <button className={styles.close} onClick={onClose}>×</button>
                <h3>Deposit Crypto</h3>

                {!selectedToken ? (
                    <div className={styles.grid}>
                        {tokens.map(t => (
                            <button
                                key={t.id}
                                className={styles.tokenBtn}
                                style={{ borderColor: t.color }}
                                onClick={() => handleSelect(t)}
                            >
                                <span style={{ color: t.color }}>{t.id}</span>
                                <small>{t.network}</small>
                            </button>
                        ))}
                    </div>
                ) : (
                    <div className={styles.depositView}>
                        <button className={styles.backBtn} onClick={() => setSelectedToken(null)}>← Back</button>

                        <div className={styles.header}>
                            <h4 style={{ color: selectedToken.color }}>{selectedToken.name}</h4>
                            <span className={styles.price}>{simulatedPrice}</span>
                        </div>

                        {loading ? <div className={styles.loader}>Generating Address...</div> : (
                            <>
                                <div className={styles.qr}>
                                    {address && <QRCodeSVG value={address} size={180} fgColor={selectedToken.color} bgColor="#1a1a1a" />}
                                </div>

                                <div className={styles.addressBox}>
                                    <label>Deposit Address ({selectedToken.network})</label>
                                    <div className={styles.addressDisplay}>
                                        <input type="text" readOnly value={address || ''} />
                                        <button onClick={() => {
                                            if (address) navigator.clipboard.writeText(address);
                                            WebApp.HapticFeedback.impactOccurred('light');
                                        }}>📋</button>
                                    </div>
                                    <small className={styles.warning}>Only send {selectedToken.id} ({selectedToken.network}) to this address.</small>
                                </div>

                                <div className={styles.status}>
                                    <div className={styles.dot}></div>
                                    <span>Waiting for blockchain confirmation...</span>
                                </div>
                            </>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
};

export default DepositModal;
