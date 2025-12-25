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
-- Index for faster message retrieval
CREATE INDEX IF NOT EXISTS idx_match_messages_match_id ON match_messages(match_id, created_at);

-- Enable RLS
ALTER TABLE match_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read messages for a match they are in (simplification: anyone can read for now to fix access)
CREATE POLICY "Public read access" ON match_messages FOR SELECT USING (true);

-- Policy: Authenticated users can insert messages
CREATE POLICY "Authenticated insert access" ON match_messages FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Enable Realtime for this table
alter publication supabase_realtime add table match_messages;
