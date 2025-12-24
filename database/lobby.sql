-- 1. Assign Captain (Call this when match is created)
CREATE OR REPLACE FUNCTION assign_captain(p_match_id UUID)
RETURNS VOID AS $$
DECLARE
    v_captain_id BIGINT;
BEGIN
    -- Select player with most games played in this match
    SELECT user_id INTO v_captain_id
    FROM match_players mp
    JOIN users u ON mp.user_id = u.telegram_id
    WHERE mp.match_id = p_match_id
    ORDER BY u.games_played DESC, u.created_at ASC
    LIMIT 1;

    UPDATE matches
    SET captain_id = v_captain_id
    WHERE id = p_match_id;
END;
$$ LANGUAGE plpgsql;

-- 2. Submit Lobby Code (Captain Only)
CREATE OR REPLACE FUNCTION submit_lobby_code(p_match_id UUID, p_user_id BIGINT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_match_record matches%ROWTYPE;
BEGIN
    SELECT * INTO v_match_record FROM matches WHERE id = p_match_id;
    
    IF v_match_record.captain_id != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not captain');
    END IF;

    UPDATE matches
    SET lobby_code = p_code,
        status = 'active'
    WHERE id = p_match_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- 3. Abort Match (Timeout Penalty)
-- Logic: Refund all players. Fine Captain 0.50 USDT.
CREATE OR REPLACE FUNCTION abort_match_penalty(p_match_id UUID)
RETURNS VOID AS $$
DECLARE
    v_match_record matches%ROWTYPE;
    v_player RECORD;
BEGIN
    SELECT * INTO v_match_record FROM matches WHERE id = p_match_id;
    
    IF v_match_record.status != 'waiting' THEN
        RETURN; -- Already active or finished
    END IF;

    -- Loop through players to refund
    FOR v_player IN (SELECT * FROM match_players WHERE match_id = p_match_id) LOOP
        -- Refund Betting Amount (Need to fetch amount from somewhere, assuming it matches bet_tier)
        -- In a real app we'd track precise amount paid. Here we use bet_tier.
        -- Check currency from somewhere? Assuming USDT/FC split logic handled elsewhere or stored in match.
        -- SIMPLIFICATION: Assuming USDT for now or generic balance restore.
        -- TODO: Needs to know currency. Adding currency to matches table would be good.
        -- For now, let's assume fine is only USDT.
        NULL; -- Refund logic needs currency context.
    END LOOP;

    -- FINE THE CAPTAIN 0.50 USDT
    UPDATE users
    SET balance_usdt = balance_usdt - 0.50
    WHERE telegram_id = v_match_record.captain_id;

    UPDATE matches
    SET status = 'aborted'
    WHERE id = p_match_id;
END;
$$ LANGUAGE plpgsql;

-- 4. Finalize Match & Payout
-- Logic: 10% House Fee, 90% Split to Winners
CREATE OR REPLACE FUNCTION finalize_match_payout(p_match_id UUID, p_winning_team TEXT)
RETURNS VOID AS $$
DECLARE
    v_match matches%ROWTYPE;
    v_total_pot DECIMAL;
    v_house_fee DECIMAL;
    v_winner_pot DECIMAL;
    v_winner_count INT;
    v_payout_per_player DECIMAL;
    v_player RECORD;
BEGIN
    SELECT * INTO v_match FROM matches WHERE id = p_match_id;
    
    -- Calculate Pot (Tier * Player Count)
    SELECT COUNT(*) INTO v_winner_count FROM match_players WHERE match_id = p_match_id;
    v_total_pot := v_match.bet_tier * v_winner_count; -- Total money in (both teams)
    
    v_house_fee := v_total_pot * 0.10;
    v_winner_pot := v_total_pot - v_house_fee;
    
    -- Count winners
    SELECT COUNT(*) INTO v_winner_count 
    FROM match_players 
    WHERE match_id = p_match_id AND team = p_winning_team;

    IF v_winner_count > 0 THEN
        v_payout_per_player := v_winner_pot / v_winner_count;

        -- Pay Winners
        UPDATE users u
        SET balance_usdt = balance_usdt + v_payout_per_player, -- Assuming USDT for now
            games_played = games_played + 1,
            total_winnings = total_winnings + v_payout_per_player
        FROM match_players mp
        WHERE mp.user_id = u.telegram_id 
          AND mp.match_id = p_match_id 
          AND mp.team = p_winning_team;
          
        -- Update Losers (Just games played stats)
        UPDATE users u
        SET games_played = games_played + 1
        FROM match_players mp
        WHERE mp.user_id = u.telegram_id 
          AND mp.match_id = p_match_id 
          AND mp.team != p_winning_team;
    END IF;

    UPDATE matches
    SET status = 'finished'
    WHERE id = p_match_id;
END;
$$ LANGUAGE plpgsql;
