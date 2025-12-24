-- 1. Add Region to Matchmaking Queue
ALTER TABLE matchmaking_queue ADD COLUMN IF NOT EXISTS region TEXT DEFAULT 'Global';

-- 2. Update join_queue Function to support Region
CREATE OR REPLACE FUNCTION join_queue(
    p_user_id BIGINT,
    p_game_type TEXT,
    p_mode TEXT,
    p_currency TEXT,
    p_bet_amount DECIMAL,
    p_region TEXT DEFAULT 'Global'
)
RETURNS JSONB AS $$
DECLARE
    required_players INT;
    queue_count INT;
    new_match_id UUID;
    player_json JSON;
    players_list JSON[];
    i INT;
    target_team TEXT;
BEGIN
    -- Determine required players
    IF p_mode = '1v1' THEN required_players := 2;
    ELSIF p_mode = '5v5' THEN required_players := 10;
    ELSIF p_mode = '3v3' THEN required_players := 6;
    ELSE RETURN jsonb_build_object('success', false, 'message', 'Invalid mode');
    END IF;

    -- Upsert into Queue (with Region)
    INSERT INTO matchmaking_queue (user_id, game_type, mode, currency, bet_amount, region)
    VALUES (p_user_id, p_game_type, p_mode, p_currency, p_bet_amount, p_region)
    ON CONFLICT (user_id) DO UPDATE
    SET game_type = EXCLUDED.game_type,
        mode = EXCLUDED.mode,
        currency = EXCLUDED.currency,
        bet_amount = EXCLUDED.bet_amount,
        region = EXCLUDED.region,
        joined_at = NOW();

    -- Check Queue Size for this specific pool AND Region
    SELECT COUNT(*) INTO queue_count
    FROM matchmaking_queue
    WHERE game_type = p_game_type 
      AND mode = p_mode 
      AND currency = p_currency 
      AND bet_amount = p_bet_amount
      AND region = p_region; -- STRICT REGION MATCHING

    -- If we have enough players, MATCHMAKE!
    IF queue_count >= required_players THEN
        
        -- Create Match
        INSERT INTO matches (game_type, bet_tier, lobby_code, status)
        VALUES (p_game_type, p_bet_amount, NULL, 'active')
        RETURNING id INTO new_match_id;

        -- Select Players (Same filters including Region)
        SELECT ARRAY(
            SELECT row_to_json(mq)
            FROM (
                SELECT mq.user_id
                FROM matchmaking_queue mq
                JOIN users u ON mq.user_id = u.telegram_id
                WHERE mq.game_type = p_game_type 
                  AND mq.mode = p_mode 
                  AND mq.currency = p_currency 
                  AND mq.bet_amount = p_bet_amount
                  AND mq.region = p_region
                ORDER BY u.total_winnings DESC
                LIMIT required_players
            ) mq
        ) INTO players_list;

        -- Distribute Players
        FOR i IN 1..required_players LOOP
            player_json := players_list[i];
            
            IF (i - 1) % 4 = 0 OR (i - 1) % 4 = 3 THEN
                target_team := 'A';
            ELSE
                target_team := 'B';
            END IF;

            INSERT INTO match_players (match_id, user_id, team)
            VALUES (new_match_id, (player_json->>'user_id')::BIGINT, target_team);

            -- Remove from Queue
            DELETE FROM matchmaking_queue WHERE user_id = (player_json->>'user_id')::BIGINT;
        END LOOP;

        RETURN jsonb_build_object('success', true, 'status', 'match_found', 'match_id', new_match_id);

    ELSE
        RETURN jsonb_build_object('success', true, 'status', 'queued', 'message', 'Waiting for players in ' || p_region || '...');
    END IF;
END;
$$ LANGUAGE plpgsql;
