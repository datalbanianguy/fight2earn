-- RUN THIS IN SUPABASE SQL EDITOR TO FIX THE BOT MATCH

-- 1. CHAT MESSAGES TABLE (if not exists)
CREATE TABLE IF NOT EXISTS match_messages (
    id SERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id),
    user_id BIGINT REFERENCES users(telegram_id),
    username TEXT,
    message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. ADD MISSING COLUMNS TO MATCHES TABLE
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='matches' AND column_name='captain_id') THEN
        ALTER TABLE matches ADD COLUMN captain_id BIGINT REFERENCES users(telegram_id);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='matches' AND column_name='lobby_code') THEN
        ALTER TABLE matches ADD COLUMN lobby_code TEXT;
    END IF;
END $$;

-- 3. CREATE BOT MATCH RPC (UPDATED - USES 1.0 FOR BET_TIER)
CREATE OR REPLACE FUNCTION create_bot_match(
    p_user_id BIGINT,
    p_game_type TEXT,
    p_mode TEXT,
    p_currency TEXT,
    p_bet_amount DECIMAL
)
RETURNS JSONB AS $$
DECLARE
    v_match_id UUID;
    v_bot_id BIGINT;
BEGIN
    -- Use 1.0 as default bet_tier if p_bet_amount is too small
    -- This ensures the check constraint is satisfied
    INSERT INTO matches (game_type, bet_tier, status, captain_id)
    VALUES (p_game_type, GREATEST(p_bet_amount, 1.0), 'active', p_user_id)
    RETURNING id INTO v_match_id;

    INSERT INTO match_players (match_id, user_id, team)
    VALUES (v_match_id, p_user_id, 'A');

    v_bot_id := 9990001;
    
    INSERT INTO users (telegram_id, username, balance_usdt)
    VALUES (v_bot_id, 'AI_Bot_Easy', 1000)
    ON CONFLICT (telegram_id) DO NOTHING;

    INSERT INTO match_players (match_id, user_id, team)
    VALUES (v_match_id, v_bot_id, 'B');

    INSERT INTO match_messages (match_id, user_id, username, message)
    VALUES (v_match_id, NULL, 'System', 'Match Found! Lobby Created.');

    RETURN jsonb_build_object('success', true, 'match_id', v_match_id);
END;
$$ LANGUAGE plpgsql;

-- 4. SUBMIT LOBBY CODE RPC
CREATE OR REPLACE FUNCTION submit_lobby_code(
    p_match_id UUID,
    p_user_id BIGINT,
    p_code TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_captain_id BIGINT;
BEGIN
    SELECT captain_id INTO v_captain_id FROM matches WHERE id = p_match_id;
    
    IF v_captain_id != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only captain can submit code');
    END IF;

    UPDATE matches SET lobby_code = p_code WHERE id = p_match_id;

    INSERT INTO match_messages (match_id, user_id, username, message)
    VALUES (p_match_id, NULL, 'System', CONCAT('Lobby Code Set: ', p_code));

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;
