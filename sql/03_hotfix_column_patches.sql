-- ============================================================
-- Hotfixes DB column patches required by this AshamaneCore build
-- Applied to: hotfixes database
-- ============================================================

-- pvp_item: column was renamed in a later update
ALTER TABLE pvp_item 
  RENAME COLUMN ItemLevelBonus TO ItemLevelDelta;

-- pvp_talent: column was renamed in a later update  
ALTER TABLE pvp_talent 
  RENAME COLUMN ExtraSpellID TO ActionBarSpellID;
