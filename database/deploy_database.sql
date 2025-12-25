-- ============================================
-- FIGHTCOIN ARENA - COMPLETE DATABASE DEPLOYMENT
-- ============================================
-- This script deploys all required tables and RPC functions
-- Execute this in Supabase Dashboard > SQL Editor

-- 1. MATCHMAKING SYSTEM (with region support)
\i matchmaking.sql

-- 2. FRIENDS & PARTIES
\i friends_setup.sql

-- 3. MATCH MESSAGES (Chat)
\i match_messages_setup.sql

-- 4. LOBBY SYSTEM
\i lobby.sql

-- 5. MATCH RESULTS (Screenshot verification)
\i match_results_setup.sql

-- 6. DEPOSITS & WITHDRAWALS
\i deposits_withdrawals_setup.sql

-- 7. TASKS/EARN SYSTEM
\i tasks_setup.sql

-- 8. SUPPORT/FEEDBACK
\i support_feedback_setup.sql

-- ============================================
-- DEPLOYMENT COMPLETE
-- ============================================
-- Verify deployment by checking:
-- 1. Tables exist: matchmaking_queue, match_messages, match_results, crypto_deposits, withdrawals, tasks, support_feedback
-- 2. RPC functions exist: join_queue, create_party, submit_match_result, record_deposit, request_withdrawal, complete_task, submit_feedback
