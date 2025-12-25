-- Support/Feedback Table
CREATE TABLE IF NOT EXISTS support_feedback (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(telegram_id),
    username TEXT,
    feedback_type TEXT CHECK (feedback_type IN ('bug', 'feature_request', 'other')),
    message TEXT NOT NULL,
    status TEXT CHECK (status IN ('open', 'in_progress', 'resolved')) DEFAULT 'open',
    created_at TIMESTAMP DEFAULT NOW()
);

-- RPC: Submit Feedback
CREATE OR REPLACE FUNCTION submit_feedback(
    p_user_id BIGINT,
    p_username TEXT,
    p_feedback_type TEXT,
    p_message TEXT
) RETURNS JSONB AS $$
BEGIN
    INSERT INTO support_feedback (user_id, username, feedback_type, message)
    VALUES (p_user_id, p_username, p_feedback_type, p_message);
    
    RETURN jsonb_build_object('success', true, 'message', 'Feedback submitted. Thank you!');
END;
$$ LANGUAGE plpgsql;

-- Index for admin dashboard
CREATE INDEX IF NOT EXISTS idx_support_feedback_status ON support_feedback(status, created_at DESC);
