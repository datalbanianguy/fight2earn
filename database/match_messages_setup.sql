-- Match Messages Table for Chat
CREATE TABLE IF NOT EXISTS match_messages (
    id SERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id),
    user_id BIGINT REFERENCES users(telegram_id),
    username TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for faster message retrieval
CREATE INDEX IF NOT EXISTS idx_match_messages_match_id ON match_messages(match_id, created_at);
