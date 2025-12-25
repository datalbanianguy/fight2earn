-- Crypto Deposits Table
CREATE TABLE IF NOT EXISTS crypto_deposits (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(telegram_id),
    blockchain TEXT CHECK (blockchain IN ('SOL', 'ETH', 'ETH_USDT', 'SOL_USDT')),
    tx_hash TEXT UNIQUE NOT NULL,
    amount DECIMAL(18, 8),
    confirmations INT DEFAULT 0,
    status TEXT CHECK (status IN ('pending', 'confirmed', 'credited')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

-- RPC: Record Deposit
CREATE OR REPLACE FUNCTION record_deposit(
    p_user_id BIGINT,
    p_blockchain TEXT,
    p_tx_hash TEXT
) RETURNS JSONB AS $$
BEGIN
    -- Check if tx_hash already exists
    IF EXISTS (SELECT 1 FROM crypto_deposits WHERE tx_hash = p_tx_hash) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transaction already recorded');
    END IF;
    
    INSERT INTO crypto_deposits (user_id, blockchain, tx_hash)
    VALUES (p_user_id, p_blockchain, p_tx_hash);
    
    RETURN jsonb_build_object('success', true, 'message', 'Deposit recorded. Awaiting confirmations...');
END;
$$ LANGUAGE plpgsql;

-- Withdrawals Table
CREATE TABLE IF NOT EXISTS withdrawals (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(telegram_id),
    amount DECIMAL(18, 8),
    currency TEXT CHECK (currency IN ('USDT', 'FC')),
    wallet_address TEXT NOT NULL,
    status TEXT CHECK (status IN ('pending', 'processing', 'completed', 'failed')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

-- RPC: Request Withdrawal
CREATE OR REPLACE FUNCTION request_withdrawal(
    p_user_id BIGINT,
    p_amount DECIMAL,
    p_currency TEXT,
    p_wallet_address TEXT
) RETURNS JSONB AS $$
DECLARE
    v_balance DECIMAL;
    v_usdt_amount DECIMAL;
BEGIN
    -- Check balance
    IF p_currency = 'FC' THEN
        SELECT fc_balance INTO v_balance FROM users WHERE telegram_id = p_user_id;
        
        -- Minimum 100 FC
        IF p_amount < 100 THEN
            RETURN jsonb_build_object('success', false, 'message', 'Minimum withdrawal: 100 FC');
        END IF;
        
        -- Convert FC to USDT (100 FC = 10 USDT)
        v_usdt_amount := p_amount * 0.1;
    ELSE
        SELECT usdt_balance INTO v_balance FROM users WHERE telegram_id = p_user_id;
        v_usdt_amount := p_amount;
    END IF;
    
    IF v_balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'message', 'Insufficient balance');
    END IF;
    
    -- Deduct balance
    IF p_currency = 'FC' THEN
        UPDATE users SET fc_balance = fc_balance - p_amount WHERE telegram_id = p_user_id;
    ELSE
        UPDATE users SET usdt_balance = usdt_balance - p_amount WHERE telegram_id = p_user_id;
    END IF;
    
    -- Create withdrawal request
    INSERT INTO withdrawals (user_id, amount, currency, wallet_address)
    VALUES (p_user_id, v_usdt_amount, 'USDT', p_wallet_address);
    
    RETURN jsonb_build_object('success', true, 'message', 'Withdrawal request submitted');
END;
$$ LANGUAGE plpgsql;
