-- Friendships: bidirectional friend relationships between participants.
-- A single row per (requester, addressee) pair.
--   status = 'pending'  -> request sent, awaiting addressee acceptance
--   status = 'accepted' -> friends
CREATE TABLE friendships (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    status       TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (requester_id, addressee_id)
);

CREATE INDEX idx_friendships_requester ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee ON friendships(addressee_id);

-- Add a status column to conversations so a DM between two non-friends can
-- start life as a "message request" and be upgraded to a normal chat once the
-- receiver accepts it (or the two become friends).
ALTER TABLE conversations ADD COLUMN status TEXT NOT NULL DEFAULT 'accepted'
    CHECK (status IN ('accepted', 'request'));
CREATE INDEX idx_conversations_status ON conversations(status);

-- RLS (defense-in-depth; the app connects as the table owner and bypasses
-- this, but mirror the rest of the schema so non-owner roles behave correctly).
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships FORCE ROW LEVEL SECURITY;

CREATE POLICY friendships_select ON friendships FOR SELECT USING (
    requester_id = current_setting('app.current_user_id', true)::uuid
    OR addressee_id = current_setting('app.current_user_id', true)::uuid
);
CREATE POLICY friendships_insert ON friendships FOR INSERT WITH CHECK (
    requester_id = current_setting('app.current_user_id', true)::uuid
);
CREATE POLICY friendships_update ON friendships FOR UPDATE USING (
    addressee_id = current_setting('app.current_user_id', true)::uuid
);
CREATE POLICY friendships_service ON friendships FOR ALL USING (
    current_setting('app.current_user_id', true) = ''
);
