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
-- 6. FUNCTION: claim_faucet
-- Logic: Claims 1.0 FC if last_claim >= 1 hour ago.
CREATE OR REPLACE FUNCTION claim_faucet(user_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    last_claim TIMESTAMP;
    new_balance DECIMAL(18, 8);
BEGIN
    -- Check last claim time
    SELECT last_faucet_claim INTO last_claim
    FROM users
    WHERE telegram_id = user_id;

    IF last_claim IS NOT NULL AND NOW() - last_claim < INTERVAL '1 hour' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cooldown active');
    END IF;

    -- Update user
    UPDATE users
    SET balance_fc = balance_fc + 1.00000000,
        last_faucet_claim = NOW()
    WHERE telegram_id = user_id
    RETURNING balance_fc INTO new_balance;

    RETURN jsonb_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql;
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
-- 1. Reports Table
CREATE TABLE IF NOT EXISTS player_reports (
    id SERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id),
    reporter_id BIGINT REFERENCES users(telegram_id),
    target_id BIGINT REFERENCES users(telegram_id),
    reason TEXT CHECK (reason IN ('Cheater', 'Bluestacks', 'AFK', 'Other')),
    comment TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(match_id, reporter_id, target_id) -- One report per player per match
);

-- 2. User Flag Column
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_flagged BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS flag_reason TEXT;

-- 3. RPC: Report Player
CREATE OR REPLACE FUNCTION report_player(
    p_match_id UUID,
    p_reporter_id BIGINT,
    p_target_id BIGINT,
    p_reason TEXT,
    p_comment TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
    v_report_count INT;
BEGIN
    -- Insert Report
    INSERT INTO player_reports (match_id, reporter_id, target_id, reason, comment)
    VALUES (p_match_id, p_reporter_id, p_target_id, p_reason, p_comment)
    ON CONFLICT (match_id, reporter_id, target_id) DO NOTHING;

    -- Check Total Reports for Target
    SELECT COUNT(*) INTO v_report_count
    FROM player_reports
    WHERE target_id = p_target_id;

    -- Flag User if > 10 reports
    IF v_report_count >= 10 THEN
        UPDATE users
        SET is_flagged = TRUE,
            flag_reason = 'Excessive Reports'
        WHERE telegram_id = p_target_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'total_reports', v_report_count);
END;
$$ LANGUAGE plpgsql;
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
