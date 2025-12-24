-- 1. Update Users Table
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_winnings DECIMAL(18, 8) DEFAULT 0.00;

-- 2. Matchmaking Queue
CREATE TABLE IF NOT EXISTS matchmaking_queue (
    user_id BIGINT REFERENCES users(telegram_id),
    game_type TEXT,
    mode TEXT, -- '1v1', '5v5'
    currency TEXT, -- 'USDT', 'FC'
    bet_amount DECIMAL(18, 8),
    joined_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id)
);

-- 3. Match Players (To track teams)
CREATE TABLE IF NOT EXISTS match_players (
    match_id UUID REFERENCES matches(id),
    user_id BIGINT REFERENCES users(telegram_id),
    team TEXT, -- 'A', 'B'
    PRIMARY KEY (match_id, user_id)
);

-- 4. RPC: Join Queue and Matchmake
CREATE OR REPLACE FUNCTION join_queue(
    p_user_id BIGINT,
    p_game_type TEXT,
    p_mode TEXT,
    p_currency TEXT,
    p_bet_amount DECIMAL
)
RETURNS JSONB AS $$
DECLARE
    required_players INT;
    queue_count INT;
    new_match_id UUID;
    player_json JSON;
    players_list JSON[];
    i INT;
    team_a_count INT := 0;
    team_b_count INT := 0;
    target_team TEXT;
BEGIN
    -- Determine required players
    IF p_mode = '1v1' THEN required_players := 2;
    ELSIF p_mode = '5v5' THEN required_players := 10;
    ELSIF p_mode = '3v3' THEN required_players := 6; -- Brawl Stars
    ELSE RETURN jsonb_build_object('success', false, 'message', 'Invalid mode');
    END IF;

    -- Upsert into Queue
    INSERT INTO matchmaking_queue (user_id, game_type, mode, currency, bet_amount)
    VALUES (p_user_id, p_game_type, p_mode, p_currency, p_bet_amount)
    ON CONFLICT (user_id) DO UPDATE
    SET game_type = EXCLUDED.game_type,
        mode = EXCLUDED.mode,
        currency = EXCLUDED.currency,
        bet_amount = EXCLUDED.bet_amount,
        joined_at = NOW();

    -- Check Queue Size for this specific pool
    SELECT COUNT(*) INTO queue_count
    FROM matchmaking_queue
    WHERE game_type = p_game_type 
      AND mode = p_mode 
      AND currency = p_currency 
      AND bet_amount = p_bet_amount;

    -- If we have enough players, MATCHMAKE!
    IF queue_count >= required_players THEN
        
        -- Create Match
        INSERT INTO matches (game_type, bet_tier, lobby_code, status)
        VALUES (p_game_type, p_bet_amount, NULL, 'active') -- Lobby code set later by captain
        RETURNING id INTO new_match_id;

        -- Select Players ordered by Total Winnings (High to Low) for balancing
        -- We use ARRAY_AGG to handle them in a loop
        SELECT ARRAY(
            SELECT row_to_json(mq)
            FROM (
                SELECT mq.user_id, u.total_winnings
                FROM matchmaking_queue mq
                JOIN users u ON mq.user_id = u.telegram_id
                WHERE mq.game_type = p_game_type 
                  AND mq.mode = p_mode 
                  AND mq.currency = p_currency 
                  AND mq.bet_amount = p_bet_amount
                ORDER BY u.total_winnings DESC
                LIMIT required_players
            ) mq
        ) INTO players_list;

        -- Distribute Players (Snake Draft Logic for Fair Teams)
        -- A, B, B, A, A, B...
        FOR i IN 1..required_players LOOP
            player_json := players_list[i];
            
            -- Snake Distribution
            -- 1: A, 2: B, 3: B, 4: A, 5: A, 6: B...
            -- Pattern: A (0), B (1), B (2), A (3) ... mod 4?
            -- i-1 sequence: 0, 1, 2, 3
            -- 0 -> A, 1 -> B, 2 -> B, 3 -> A
            
            IF (i - 1) % 4 = 0 OR (i - 1) % 4 = 3 THEN
                target_team := 'A';
            ELSE
                target_team := 'B';
            END IF;

            -- In 1v1, it's just A then B. (i=1 -> 0%4=0 -> A. i=2 -> 1%4=1 -> B). Works.
            
            INSERT INTO match_players (match_id, user_id, team)
            VALUES (new_match_id, (player_json->>'user_id')::BIGINT, target_team);

            -- Remove from Queue
            DELETE FROM matchmaking_queue WHERE user_id = (player_json->>'user_id')::BIGINT;
        END LOOP;

        RETURN jsonb_build_object('success', true, 'status', 'match_found', 'match_id', new_match_id);

    ELSE
        RETURN jsonb_build_object('success', true, 'status', 'queued', 'message', 'Waiting for players...');
    END IF;
END;
$$ LANGUAGE plpgsql;
