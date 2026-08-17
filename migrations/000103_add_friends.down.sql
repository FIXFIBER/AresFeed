DROP POLICY IF EXISTS friendships_select ON friendships;
DROP POLICY IF EXISTS friendships_insert ON friendships;
DROP POLICY IF EXISTS friendships_update ON friendships;
DROP POLICY IF EXISTS friendships_service ON friendships;
ALTER TABLE friendships DISABLE ROW LEVEL SECURITY;
DROP TABLE IF EXISTS friendships;

ALTER TABLE conversations DROP COLUMN IF EXISTS status;
DROP INDEX IF EXISTS idx_conversations_status;
