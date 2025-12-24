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
