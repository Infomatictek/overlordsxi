-- OverlordsXI Dancer Bladewheel Spec (Lv 75 Cap + Post-75 Backports)
-- 1. Lower post-75 DNC Step/Flourish abilities to Lv 75
-- 2. Scale chakram progression (Lv 10..75 + Lv 75 REMA equivalents), all MId 26/27/28 (zero boomerangs)

-- Post-75 DNC abilities scaled to <= Lv 75
UPDATE `abilities` SET `level` = 75 WHERE `abilityId` IN (264, 312, 313, 314) AND `level` > 75;

-- Lv 10 Starter Chakram: Rogetsurin (18246, MId = 28)
UPDATE `item_equipment` SET `level` = 10 WHERE `itemId` = 18246;
UPDATE `item_weapon` SET `dmg` = 8, `delay` = 280 WHERE `itemId` = 18246;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES (18246, 11, 2), (18246, 26, 4);

-- Lv 61 Bridge: Death Chakram (18231, MId = 27) - add DNC (bit 18 = 262144)
UPDATE `item_equipment` SET `jobs` = (`jobs` | 262144) WHERE `itemId` = 18231;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES (18231, 9, 3), (18231, 26, 6);

-- Lv 75 Backports: Jinx Discus (19261, MId = 28), Aliyat Chakram (19770, MId = 26), Halakaala (21340, MId = 26)
UPDATE `item_equipment` SET `level` = 75, `ilevel` = 0 WHERE `itemId` IN (19261, 19770, 21340);
UPDATE `item_weapon` SET `dmg` = 32, `delay` = 196 WHERE `itemId` = 19261;
UPDATE `item_weapon` SET `dmg` = 35, `delay` = 286 WHERE `itemId` = 19770;
UPDATE `item_weapon` SET `dmg` = 34, `delay` = 260, `ilvl_skill` = 0, `ilvl_parry` = 0, `ilvl_macc` = 0 WHERE `itemId` = 21340;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (21340, 24, 12), (21340, 26, 12), (21340, 365, 5);

-- Lv 75 Relic-Equivalent: Mamoolbane (18692, MId = 27)
UPDATE `item_equipment` SET `level` = 75, `jobs` = (`jobs` | 262144) WHERE `itemId` = 18692;
UPDATE `item_weapon` SET `dmg` = 40, `delay` = 280 WHERE `itemId` = 18692;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (18692, 24, 20), (18692, 26, 20), (18692, 840, 15);

-- Lv 75 Mythic-Equivalent: Lamiabane (18693, MId = 27)
UPDATE `item_equipment` SET `level` = 75, `jobs` = (`jobs` | 262144) WHERE `itemId` = 18693;
UPDATE `item_weapon` SET `dmg` = 38, `delay` = 240 WHERE `itemId` = 18693;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (18693, 26, 18), (18693, 14, 8), (18693, 365, 5);

-- Lv 75 Empyrean-Equivalent: Trollbane (18694, MId = 27)
UPDATE `item_equipment` SET `level` = 75, `jobs` = (`jobs` | 262144) WHERE `itemId` = 18694;
UPDATE `item_weapon` SET `dmg` = 39, `delay` = 255 WHERE `itemId` = 18694;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (18694, 9, 10), (18694, 14, 10), (18694, 421, 10);

-- Lv 75 Aeonic-Equivalent: Besta's Bane (21368, MId = 27)
UPDATE `item_equipment` SET `level` = 75, `ilevel` = 0, `jobs` = (`jobs` | 262144) WHERE `itemId` = 21368;
UPDATE `item_weapon` SET `dmg` = 42, `delay` = 265, `ilvl_skill` = 0, `ilvl_parry` = 0, `ilvl_macc` = 0 WHERE `itemId` = 21368;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (21368, 345, 500), (21368, 73, 10), (21368, 26, 15);
