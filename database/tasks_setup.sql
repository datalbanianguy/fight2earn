-- Tasks Table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    platform TEXT CHECK (platform IN ('telegram', 'instagram', 'facebook', 'youtube', 'twitter')),
    action_url TEXT,
    reward_fc DECIMAL(18, 8) DEFAULT 1.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- User Task Completions
CREATE TABLE IF NOT EXISTS user_task_completions (
    user_id BIGINT REFERENCES users(telegram_id),
    task_id INT REFERENCES tasks(id),
    completed_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, task_id)
);

-- RPC: Complete Task
CREATE OR REPLACE FUNCTION complete_task(
    p_user_id BIGINT,
    p_task_id INT
) RETURNS JSONB AS $$
DECLARE
    v_reward DECIMAL;
    v_already_completed BOOLEAN;
BEGIN
    -- Check if already completed
    SELECT EXISTS(SELECT 1 FROM user_task_completions WHERE user_id = p_user_id AND task_id = p_task_id) INTO v_already_completed;
    
    IF v_already_completed THEN
        RETURN jsonb_build_object('success', false, 'message', 'Task already completed');
    END IF;
    
    -- Get reward amount
    SELECT reward_fc INTO v_reward FROM tasks WHERE id = p_task_id AND is_active = TRUE;
    
    IF v_reward IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Task not found or inactive');
    END IF;
    
    -- Mark as completed
    INSERT INTO user_task_completions (user_id, task_id) VALUES (p_user_id, p_task_id);
    
    -- Award FC
    UPDATE users SET fc_balance = fc_balance + v_reward WHERE telegram_id = p_user_id;
    
    RETURN jsonb_build_object('success', true, 'reward', v_reward);
END;
$$ LANGUAGE plpgsql;

-- Insert sample tasks (URLs to be updated later)
INSERT INTO tasks (title, description, platform, action_url, reward_fc) VALUES
('Follow Telegram Channel', 'Join our official Telegram channel', 'telegram', 'https://t.me/placeholder', 1.00),
('Follow Instagram', 'Follow us on Instagram', 'instagram', 'https://instagram.com/placeholder', 1.00),
('Like Facebook Page', 'Like our Facebook page', 'facebook', 'https://facebook.com/placeholder', 1.00),
('Subscribe YouTube', 'Subscribe to our YouTube channel', 'youtube', 'https://youtube.com/placeholder', 1.00),
('Follow Twitter', 'Follow us on Twitter', 'twitter', 'https://twitter.com/placeholder', 1.00)
ON CONFLICT DO NOTHING;
