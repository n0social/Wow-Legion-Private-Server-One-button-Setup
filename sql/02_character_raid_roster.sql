-- ============================================================
--  Raid Roster persistence table
--  Created: 2026-03-08  (Tier-2 Raid Roster system)
--
--  Stores manually-recruited NPC raid members per player.
--  Automatically populated via the "Sign up for my raid" gossip option.
--  Cleared via "Clear raid roster" gossip or when the player uses .resetroster.
--
--  PK = (player_guid, name) -- one row per named NPC per player
-- ============================================================

CREATE TABLE IF NOT EXISTS `character_raid_roster` (
    `player_guid`  INT UNSIGNED     NOT NULL,
    `name`         VARCHAR(64)      NOT NULL,
    `role`         TINYINT UNSIGNED NOT NULL DEFAULT 0
                       COMMENT '0=Warrior 1=Mage 2=Healer 3=Hunter 4=Rogue 5=Default 6=Tank',
    `level`        TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`player_guid`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Tier-2 raid roster: NPC names manually added by the player via gossip';

-- Migration: add extra tank override column (not needed yet, reserved for future per-instance saves)
-- ALTER TABLE character_raid_roster ADD COLUMN IF NOT EXISTS extra_tanks TINYINT UNSIGNED NOT NULL DEFAULT 0;
