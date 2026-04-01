-- ============================================================
-- Hotfixes DB column patches required by this AshamaneCore build
-- Applied to: hotfixes database
-- Safe to re-run (idempotent)
-- ============================================================

-- pvp_item: rename only if the old column name still exists
SET @stmt = IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pvp_item'
           AND COLUMN_NAME = 'ItemLevelBonus'),
  'ALTER TABLE pvp_item RENAME COLUMN ItemLevelBonus TO ItemLevelDelta',
  'SELECT 1 -- pvp_item already patched'
);
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- pvp_talent: rename only if the old column name still exists
SET @stmt2 = IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pvp_talent'
           AND COLUMN_NAME = 'ExtraSpellID'),
  'ALTER TABLE pvp_talent RENAME COLUMN ExtraSpellID TO ActionBarSpellID',
  'SELECT 1 -- pvp_talent already patched'
);
PREPARE s2 FROM @stmt2; EXECUTE s2; DEALLOCATE PREPARE s2;
