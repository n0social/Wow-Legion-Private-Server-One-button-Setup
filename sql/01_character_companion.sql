-- ============================================================
-- Custom table: NPC Companion persistence
-- Applied to: characters database
-- ============================================================

CREATE TABLE IF NOT EXISTS `character_companion` (
  `player_guid` int unsigned NOT NULL,
  `entry`       int unsigned NOT NULL DEFAULT '0',
  `level`       tinyint unsigned NOT NULL DEFAULT '1',
  `xp`          int unsigned NOT NULL DEFAULT '0',
  `name`        varchar(64) NOT NULL DEFAULT '',
  `display_id`  int unsigned NOT NULL DEFAULT '0',
  `kill_count`  int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`player_guid`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Migration: add kill_count to existing installs
ALTER TABLE `character_companion`
  ADD COLUMN IF NOT EXISTS `kill_count` int unsigned NOT NULL DEFAULT '0';
