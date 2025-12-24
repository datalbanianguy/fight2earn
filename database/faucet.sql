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
