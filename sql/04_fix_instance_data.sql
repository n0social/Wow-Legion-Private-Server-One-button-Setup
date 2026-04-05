-- ============================================================
-- Fix: Stale/corrupt instance data cleanup
-- Applied to: characters database
-- Safe to re-run (idempotent)
-- ============================================================
-- Truncates the instance reset timer table.
-- The worldserver repopulates it automatically on startup from
-- the world DB, so truncating it is always safe.
TRUNCATE TABLE instance_reset;

-- Remove character instance saves that reference non-existent instances.
-- These are leftover entries from legacy content (TBC/Wrath map IDs) that
-- don't exist in the Legion world DB and cause MySQL errno 1292/1366 errors.
DELETE ci FROM character_instance ci
  LEFT JOIN instance i ON ci.instance = i.id
  WHERE i.id IS NULL;

-- Same cleanup for group instance saves.
DELETE gi FROM group_instance gi
  LEFT JOIN instance i ON gi.instance = i.id
  WHERE i.id IS NULL;

-- Dismiss all in-game tutorial popups for every account.
-- Legion shows a "Controls Tutorial" bar over the hotbar until all tutorial
-- bits are flagged as seen. Setting tut0-tut7 to max (all bits = seen)
-- suppresses every tutorial UI element permanently.
INSERT INTO account_tutorial (accountId, tut0, tut1, tut2, tut3, tut4, tut5, tut6, tut7)
  SELECT id,
    4294967295, 4294967295, 4294967295, 4294967295,
    4294967295, 4294967295, 4294967295, 4294967295
  FROM auth.account
  ON DUPLICATE KEY UPDATE
    tut0=4294967295, tut1=4294967295, tut2=4294967295, tut3=4294967295,
    tut4=4294967295, tut5=4294967295, tut6=4294967295, tut7=4294967295;
