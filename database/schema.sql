-- 1. USERS (Allows Negative Balance for Debt)
CREATE TABLE users (
    telegram_id BIGINT PRIMARY KEY,
    username TEXT,
    balance_usdt DECIMAL(10, 2) DEFAULT 0.00, -- NO check constraint (can be negative)
    balance_fc DECIMAL(18, 8) DEFAULT 0.00000000,
    games_played INT DEFAULT 0,
    last_faucet_claim TIMESTAMP DEFAULT '2000-01-01',
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. CHARITY POOL (For AFK Penalties)
CREATE TABLE charity_pool (
    id SERIAL PRIMARY KEY,
    total_amount DECIMAL(10, 2) DEFAULT 0.00,
    last_updated TIMESTAMP DEFAULT NOW()
);

-- 3. MATCHES (Multi-Game Support)
CREATE TABLE matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_type TEXT, -- 'wild_rift', 'brawl_stars', 'cs2'
    bet_tier INT CHECK (bet_tier IN (1, 5, 50, 500)),
    captain_id BIGINT REFERENCES users(telegram_id),
    lobby_code TEXT, -- 7-digit for WR, Alphanumeric for Brawl Stars
    status TEXT DEFAULT 'waiting', -- 'waiting', 'active', 'finished'
    created_at TIMESTAMP DEFAULT NOW()
);

-- 4. WITHDRAWALS
CREATE TABLE withdrawals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id BIGINT REFERENCES users(telegram_id),
    amount DECIMAL(10, 2),
    wallet_address TEXT,
    status TEXT DEFAULT 'pending'
);

-- 5. FUNCTION: penalize_afk
-- Logic: Deduct amount from user, add to charity pool. Allow negative balance.
CREATE OR REPLACE FUNCTION penalize_afk(limit_user_id BIGINT, penalty_amount DECIMAL(10, 2))
RETURNS VOID AS $$
BEGIN
    -- Deduct from User
    UPDATE users
    SET balance_usdt = balance_usdt - penalty_amount
    WHERE telegram_id = limit_user_id;

    -- Add to Charity Pool (assuming single pool record with ID 1, or insert new)
    -- We'll try to update ID 1, or insert if not exists
    IF EXISTS (SELECT 1 FROM charity_pool WHERE id = 1) THEN
        UPDATE charity_pool
        SET total_amount = total_amount + penalty_amount,
            last_updated = NOW()
        WHERE id = 1;
    ELSE
        INSERT INTO charity_pool (id, total_amount) VALUES (1, penalty_amount);
    END IF;
END;
$$ LANGUAGE plpgsql;
