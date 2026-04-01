-- npc_ambient_world custom tables
-- Idempotent: safe to run on every startup

-- Companion storage (full table, only created if missing)
CREATE TABLE IF NOT EXISTS `character_companion` (
  `player_guid` int unsigned NOT NULL,
  `entry`        int unsigned NOT NULL DEFAULT '0',
  `level`        tinyint unsigned NOT NULL DEFAULT '1',
  `xp`           int unsigned NOT NULL DEFAULT '0',
  `name`         varchar(64) NOT NULL DEFAULT '',
  `display_id`   int unsigned NOT NULL DEFAULT '0',
  `kill_count`   int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`player_guid`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add kill_count if table was created before this column existed
SET @have_col = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'characters'
    AND TABLE_NAME   = 'character_companion'
    AND COLUMN_NAME  = 'kill_count');
SET @sql = IF(@have_col = 0,
  'ALTER TABLE character_companion ADD COLUMN kill_count INT UNSIGNED NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Raid roster storage
CREATE TABLE IF NOT EXISTS `character_raid_roster` (
  `player_guid` int unsigned NOT NULL,
  `name`        varchar(64) NOT NULL,
  `role`        tinyint unsigned NOT NULL DEFAULT '0',
  `level`       tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`player_guid`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
