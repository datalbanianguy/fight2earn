-- 1. Create Index for performance (Good practice)
CREATE INDEX IF NOT EXISTS idx_match_messages_match_id ON match_messages(match_id, created_at);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE match_messages ENABLE ROW LEVEL SECURITY;

-- 3. Policy: Allow ANYONE to select (read) messages
-- This ensures that even if you are not logged in (or anonymous), you can see the chat (or restrict to auth if preferred, but public is easier for debugging)
DROP POLICY IF EXISTS "Public read access" ON match_messages;
CREATE POLICY "Public read access" ON match_messages FOR SELECT USING (true);

-- 4. Policy: Allow authenticated users to INSERT messages
DROP POLICY IF EXISTS "Authenticated insert access" ON match_messages;
CREATE POLICY "Authenticated insert access" ON match_messages FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- 5. Enable Realtime for the table so the chat updates live
ALTER PUBLICATION supabase_realtime ADD TABLE match_messages;
