-- Match Results Table for Screenshot Verification
CREATE TABLE IF NOT EXISTS match_results (
    id SERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id),
    uploaded_by BIGINT REFERENCES users(telegram_id),
    screenshot_url TEXT NOT NULL,
    winning_team TEXT CHECK (winning_team IN ('A', 'B')),
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- RPC: Submit Match Result
CREATE OR REPLACE FUNCTION submit_match_result(
    p_match_id UUID,
    p_user_id BIGINT,
    p_screenshot_url TEXT,
    p_winning_team TEXT
) RETURNS JSONB AS $$
DECLARE
    v_bet_amount DECIMAL;
    v_winner_count INT;
BEGIN
    -- Verify user is captain
    IF NOT EXISTS (SELECT 1 FROM matches WHERE id = p_match_id AND captain_id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only captain can submit results');
    END IF;
    
    -- Insert result
    INSERT INTO match_results (match_id, uploaded_by, screenshot_url, winning_team)
    VALUES (p_match_id, p_user_id, p_screenshot_url, p_winning_team);
    
    -- Get bet amount
    SELECT bet_tier INTO v_bet_amount FROM matches WHERE id = p_match_id;
    
    -- Count winners
    SELECT COUNT(*) INTO v_winner_count 
    FROM match_players 
    WHERE match_id = p_match_id AND team = p_winning_team;
    
    -- Distribute funds to winning team (each winner gets their bet back + share of losers' bets)
    UPDATE users u
    SET usdt_balance = usdt_balance + (v_bet_amount * 2 / v_winner_count)
    FROM match_players mp
    WHERE mp.match_id = p_match_id 
      AND mp.team = p_winning_team 
      AND mp.user_id = u.telegram_id;
    
    -- Update match status
    UPDATE matches SET status = 'completed' WHERE id = p_match_id;
    
    RETURN jsonb_build_object('success', true, 'message', 'Funds distributed to winning team');
END;
$$ LANGUAGE plpgsql;
