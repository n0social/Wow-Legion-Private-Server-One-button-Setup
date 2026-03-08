-- ============================================================
-- Custom Ambient NPC Companions (entries 9500080-9500094)
-- Applied to: world database
-- ============================================================

-- Base template for all custom ambient / companion NPCs
INSERT INTO `creature_template`
  (`entry`, `name`, `subname`, `faction`, `minlevel`, `maxlevel`,
   `BaseAttackTime`, `RangeAttackTime`, `HealthScalingExpansion`,
   `npcflag`, `unit_flags`,
   `modelid1`, `modelid2`, `modelid3`, `modelid4`)
VALUES
  (9500080, 'Aedric',    'Warrior',      35, 1, 1, 2000, 2000, -1, 1, 512, 18457, 21272, 21271, 21273),
  (9500081, 'Lysveth',   'Paladin',      35, 1, 1, 2000, 2000, -1, 1, 512, 25998, 33024, 37882, 21270),
  (9500082, 'Bryndal',   'Mage',         35, 1, 1, 2000, 2000, -1, 1, 512,  3167,  5446, 17389,  3258),
  (9500083, 'Cyraen',    'Hunter',       35, 1, 1, 2000, 2000, -1, 1, 512, 16229, 21273, 33024, 33025),
  (9500084, 'Therowyn',  'Rogue',        35, 1, 1, 2000, 2000, -1, 1, 512, 17389, 18457, 28780, 16229),
  (9500085, 'Grukash',   'Warrior',      35, 1, 1, 2000, 2000, -1, 1, 512,  4573,  4573,  4551,  4259),
  (9500086, 'Zikava',    'Shaman',       35, 1, 1, 2000, 2000, -1, 1, 512,  4573,  6090,  4573,  5088),
  (9500087, 'Thunka',    'Hunter',       35, 1, 1, 2000, 2000, -1, 1, 512, 47072, 11545,  6822,  6822),
  (9500088, 'Selvaine',  'Mage',         35, 1, 1, 2000, 2000, -1, 1, 512, 24864, 47055, 24864, 24865),
  (9500089, 'Krix',      'Rogue',        35, 1, 1, 2000, 2000, -1, 1, 512, 37882, 25587, 30176, 30176),
  (9500090, 'Aelindra',  'Death Knight', 35, 1, 1, 2000, 2000, -1, 1, 512, 47072, 68486, 47072, 47072),
  (9500091, 'Xarven',    'Demon Hunter', 35, 1, 1, 2000, 2000, -1, 1, 512, 61909, 60087, 61909, 60087),
  (9500092, 'Morthalun', 'Druid',        35, 1, 1, 2000, 2000, -1, 1, 512, 30859, 25998, 30859, 25998),
  (9500093, 'Yunlan',    'Monk',         35, 1, 1, 2000, 2000, -1, 1, 512, 33025, 33025, 33025, 33025),
  (9500094, 'Drevok',    'Priest',       35, 1, 1, 2000, 2000, -1, 1, 512, 33022, 33023, 33024, 33025)
ON DUPLICATE KEY UPDATE
  faction=VALUES(faction),
  BaseAttackTime=VALUES(BaseAttackTime),
  RangeAttackTime=VALUES(RangeAttackTime),
  HealthScalingExpansion=VALUES(HealthScalingExpansion),
  npcflag=VALUES(npcflag),
  unit_flags=VALUES(unit_flags),
  modelid1=VALUES(modelid1), modelid2=VALUES(modelid2),
  modelid3=VALUES(modelid3), modelid4=VALUES(modelid4);

-- Adding the `isActive` column to gameobject table (required by this build)
ALTER TABLE gameobject 
  ADD COLUMN IF NOT EXISTS isActive TINYINT(1) NOT NULL DEFAULT 0 AFTER state;
