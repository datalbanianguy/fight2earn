-- 1. CHAT MESSAGES
CREATE TABLE IF NOT EXISTS match_messages (
    id SERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id),
    user_id BIGINT REFERENCES users(telegram_id), -- or null for system messages
    username TEXT, -- Cache username to avoid joins on rapid reads
    message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. CREATE BOT MATCH RPC
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
    -- 1. Create Match (Active immediately)
    INSERT INTO matches (game_type, bet_tier, status, captain_id)
    VALUES (p_game_type, p_bet_amount, 'active', p_user_id) -- User is Captain
    RETURNING id INTO v_match_id;

    -- 2. Add User (Team A)
    INSERT INTO match_players (match_id, user_id, team)
    VALUES (v_match_id, p_user_id, 'A');

    -- 3. Add Bot (Team B) - Mocking a bot user
    -- Ensure a bot user exists or use a negative ID
    v_bot_id := 9990001; -- Dedicated Bot ID range
    
    -- Upsert Bot User just in case
    INSERT INTO users (telegram_id, username, balance_usdt)
    VALUES (v_bot_id, 'AI_Bot_Easy', 1000)
    ON CONFLICT (telegram_id) DO NOTHING;

    INSERT INTO match_players (match_id, user_id, team)
    VALUES (v_match_id, v_bot_id, 'B');

    -- If 5v5, add more bots... (Keeping it simple 1v1 for now as per request "match found with bots")
    
    -- 4. Send Welcome Message
    INSERT INTO match_messages (match_id, user_id, username, message)
    VALUES (v_match_id, NULL, 'System', 'Match Found! Lobby Created.');

    RETURN jsonb_build_object('success', true, 'match_id', v_match_id);
END;
$$ LANGUAGE plpgsql;

-- 3. SUBMIT LOBBY CODE RPC
CREATE OR REPLACE FUNCTION submit_lobby_code(
    p_match_id UUID,
    p_user_id BIGINT,
    p_code TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_captain_id BIGINT;
BEGIN
    -- Verify user is captain
    SELECT captain_id INTO v_captain_id FROM matches WHERE id = p_match_id;
    
    IF v_captain_id != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only captain can submit code');
    END IF;

    -- Update match with lobby code
    UPDATE matches SET lobby_code = p_code WHERE id = p_match_id;

    -- Send system message
    INSERT INTO match_messages (match_id, user_id, username, message)
    VALUES (p_match_id, NULL, 'System', CONCAT('Lobby Code Set: ', p_code));

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;
