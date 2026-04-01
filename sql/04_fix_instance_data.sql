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
