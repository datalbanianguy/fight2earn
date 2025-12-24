-- 1. Deposits Table
CREATE TABLE IF NOT EXISTS deposits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id BIGINT REFERENCES users(telegram_id),
    currency TEXT CHECK (currency IN ('USDT', 'SOL', 'ETH', 'LTC')),
    amount DECIMAL(18, 8),
    network TEXT, -- e.g., 'TRC20', 'SOL', 'ERC20'
    wallet_address TEXT, -- System wallet provided to user
    tx_hash TEXT UNIQUE,
    status TEXT DEFAULT 'pending', -- 'pending', 'confirming', 'completed'
    confirmations INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. Index for fast lookups
CREATE INDEX idx_deposits_user ON deposits(user_id);
CREATE INDEX idx_deposits_status ON deposits(status);

-- 3. RPC: Create Deposit Intent
-- Generates a specific wallet address for the user (Mock logic: returns a static system wallet for now)
CREATE OR REPLACE FUNCTION create_deposit_intent(
    p_user_id BIGINT,
    p_currency TEXT,
    p_network TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_wallet TEXT;
    v_deposit_id UUID;
BEGIN
    -- MOCK: Static wallets for demo. Real app would generate via Tatum/BitGo API.
    IF p_currency = 'USDT' THEN v_wallet := 'TVxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; -- TRC20
    ELSIF p_currency = 'SOL' THEN v_wallet := 'Solxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    ELSIF p_currency = 'ETH' THEN v_wallet := '0x..............................';
    ELSE v_wallet := 'Ltcxxxxxxxxxxxxxxxx';
    END IF;

    INSERT INTO deposits (user_id, currency, network, wallet_address)
    VALUES (p_user_id, p_currency, p_network, v_wallet)
    RETURNING id INTO v_deposit_id;

    RETURN jsonb_build_object('success', true, 'deposit_id', v_deposit_id, 'address', v_wallet);
END;
$$ LANGUAGE plpgsql;
