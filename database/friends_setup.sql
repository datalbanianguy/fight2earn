-- 1. FRIENDS TABLE
CREATE TABLE IF NOT EXISTS friends (
    id SERIAL PRIMARY KEY,
    user_id_1 BIGINT REFERENCES users(telegram_id),
    user_id_2 BIGINT REFERENCES users(telegram_id),
    status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id_1, user_id_2) -- Prevent duplicate rows (always store smaller ID first or handle via logic)
);

-- 2. PARTIES TABLE
CREATE TABLE IF NOT EXISTS parties (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    leader_id BIGINT REFERENCES users(telegram_id),
    code TEXT UNIQUE, -- 6-digit join code
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 3. PARTY MEMBERS
CREATE TABLE IF NOT EXISTS party_members (
    party_id UUID REFERENCES parties(id),
    user_id BIGINT REFERENCES users(telegram_id),
    is_ready BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (party_id, user_id)
);

-- RPC: Send Friend Request (using invite code/telegram_id)
CREATE OR REPLACE FUNCTION send_friend_request(p_requester_id BIGINT, p_target_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_target_id BIGINT;
    v_exists BOOLEAN;
BEGIN
    -- Resolve code to ID (Assuming code IS logic for now, or username lookup)
    -- For simplicity, let's assume p_target_code IS the telegram_id string for now
    -- In real app, we'd have a 'invite_code' column in users. 
    -- Let's query users by username or ID matching string
    SELECT telegram_id INTO v_target_id FROM users WHERE CAST(telegram_id AS TEXT) = p_target_code OR username = p_target_code LIMIT 1;

    IF v_target_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'User not found');
    END IF;

    IF v_target_id = p_requester_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cannot add yourself');
    END IF;

    -- Check if exists
    SELECT EXISTS(SELECT 1 FROM friends WHERE (user_id_1 = p_requester_id AND user_id_2 = v_target_id) OR (user_id_1 = v_target_id AND user_id_2 = p_requester_id)) INTO v_exists;
    
    IF v_exists THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request already sent or friends');
    END IF;

    -- Insert (Order IDs to avoid duplicates?) -> Let's just insert as requester=1
    INSERT INTO friends (user_id_1, user_id_2, status) VALUES (p_requester_id, v_target_id, 'pending');

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- RPC: Create Party
CREATE OR REPLACE FUNCTION create_party(p_user_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    v_party_id UUID;
    v_code TEXT;
BEGIN
    -- Generate 6 char code
    v_code := substr(md5(random()::text), 1, 6);

    INSERT INTO parties (leader_id, code) VALUES (p_user_id, v_code) RETURNING id INTO v_party_id;
    
    INSERT INTO party_members (party_id, user_id, is_ready) VALUES (v_party_id, p_user_id, TRUE);

    RETURN jsonb_build_object('success', true, 'party_id', v_party_id, 'code', v_code);
END;
$$ LANGUAGE plpgsql;

-- RPC: Join Party
CREATE OR REPLACE FUNCTION join_party(p_user_id BIGINT, p_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_party_id UUID;
BEGIN
    SELECT id INTO v_party_id FROM parties WHERE code = p_code AND is_active = TRUE;
    
    IF v_party_id IS NULL THEN
         RETURN jsonb_build_object('success', false, 'message', 'Party not found');
    END IF;

    INSERT INTO party_members (party_id, user_id) VALUES (v_party_id, p_user_id)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object('success', true, 'party_id', v_party_id);
END;
$$ LANGUAGE plpgsql;
