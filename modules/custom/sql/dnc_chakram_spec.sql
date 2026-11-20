-- SoulspireXI Dancer Bladewheel Spec (Lv 75 Cap + Post-75 Backports)
-- 1. Lower post-75 DNC Step/Flourish abilities to Lv 75
-- 2. Make all chakrams DNC-only (jobs = 262144) with competitive damage (no ammo slot)

-- Post-75 DNC abilities scaled to <= Lv 75
UPDATE `abilities` SET `level` = 75 WHERE `abilityId` IN (264, 312, 313, 314) AND `level` > 75;

-- Make all chakrams DNC-only (bit 18 = 262144)
UPDATE `item_equipment` SET `jobs` = 262144 WHERE `itemId` IN (
  18246, 18171, 17284, 17289, 19203, 17283, 18134, 18135,
  17285, 17279, 18231, 17286, 17295, 18245, 19261, 19770,
  21340, 18692, 18693, 18694, 21368
);

-- Lv 10 Starter Chakram: Rogetsurin (18246, MId = 28)
UPDATE `item_equipment` SET `level` = 10 WHERE `itemId` = 18246;
UPDATE `item_weapon` SET `dmg` = 16, `delay` = 260 WHERE `itemId` = 18246;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES (18246, 11, 2), (18246, 26, 4);

-- Lv 20..57 Leveling Chakrams (scaled to match bow+arrow total DMG)
UPDATE `item_weapon` SET `dmg` = 22, `delay` = 260 WHERE `itemId` = 18171; -- Platoon Disc (Lv 20)
UPDATE `item_weapon` SET `dmg` = 28, `delay` = 260 WHERE `itemId` = 17284; -- Chakram (Lv 28)
UPDATE `item_weapon` SET `dmg` = 30, `delay` = 255 WHERE `itemId` = 17289; -- Chakram +1 (Lv 28)
UPDATE `item_weapon` SET `dmg` = 36, `delay` = 260 WHERE `itemId` = 19203; -- War Hoop (Lv 40)
UPDATE `item_weapon` SET `dmg` = 38, `delay` = 260 WHERE `itemId` = 17283; -- Jr.Msk. Chakram (Lv 40)
UPDATE `item_weapon` SET `dmg` = 40, `delay` = 255 WHERE `itemId` = 18134; -- Jr.Msk. Chakram +1 (Lv 43)
UPDATE `item_weapon` SET `dmg` = 42, `delay` = 250 WHERE `itemId` = 18135; -- Jr.Msk. Chakram +2 (Lv 43)
UPDATE `item_weapon` SET `dmg` = 48, `delay` = 255 WHERE `itemId` = 17285; -- Moonring Blade (Lv 57)
UPDATE `item_weapon` SET `dmg` = 50, `delay` = 250 WHERE `itemId` = 17279; -- Moonring Blade +1 (Lv 57)

-- Lv 61 Bridge: Death Chakram (18231, MId = 27)
UPDATE `item_weapon` SET `dmg` = 53, `delay` = 250 WHERE `itemId` = 18231;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES (18231, 9, 3), (18231, 26, 6);

-- Lv 68: Rising Sun / +1
UPDATE `item_weapon` SET `dmg` = 58, `delay` = 250 WHERE `itemId` = 17286;
UPDATE `item_weapon` SET `dmg` = 60, `delay` = 245 WHERE `itemId` = 17295;

-- Lv 75 Endgame & Backports: Aureole (18245), Jinx Discus (19261), Halakaala (21340), Aliyat Chakram (19770)
UPDATE `item_equipment` SET `level` = 75, `ilevel` = 0 WHERE `itemId` IN (18245, 19261, 19770, 21340);
UPDATE `item_weapon` SET `dmg` = 56, `delay` = 192 WHERE `itemId` = 18245; -- Aureole (fast)
UPDATE `item_weapon` SET `dmg` = 58, `delay` = 196 WHERE `itemId` = 19261; -- Jinx Discus (fast)
UPDATE `item_weapon` SET `dmg` = 66, `delay` = 250, `ilvl_skill` = 0, `ilvl_parry` = 0, `ilvl_macc` = 0 WHERE `itemId` = 21340; -- Halakaala
UPDATE `item_weapon` SET `dmg` = 68, `delay` = 255 WHERE `itemId` = 19770; -- Aliyat Chakram
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (21340, 24, 15), (21340, 26, 15), (21340, 365, 5);

-- Lv 75 Relic-Equivalent: Mamoolbane (18692, MId = 27)
UPDATE `item_equipment` SET `level` = 75 WHERE `itemId` = 18692;
UPDATE `item_weapon` SET `dmg` = 82, `delay` = 270 WHERE `itemId` = 18692;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (18692, 24, 25), (18692, 26, 25), (18692, 840, 15);

-- Lv 75 Mythic-Equivalent: Lamiabane (18693, MId = 27)
UPDATE `item_equipment` SET `level` = 75 WHERE `itemId` = 18693;
UPDATE `item_weapon` SET `dmg` = 76, `delay` = 230 WHERE `itemId` = 18693;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (18693, 26, 22), (18693, 14, 10), (18693, 365, 8);

-- Lv 75 Empyrean-Equivalent: Trollbane (18694, MId = 27)
UPDATE `item_equipment` SET `level` = 75 WHERE `itemId` = 18694;
UPDATE `item_weapon` SET `dmg` = 80, `delay` = 250 WHERE `itemId` = 18694;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (18694, 9, 12), (18694, 14, 12), (18694, 421, 12);

-- Lv 75 Aeonic-Equivalent: Besta's Bane (21368, MId = 27)
UPDATE `item_equipment` SET `level` = 75, `ilevel` = 0 WHERE `itemId` = 21368;
UPDATE `item_weapon` SET `dmg` = 85, `delay` = 260, `ilvl_skill` = 0, `ilvl_parry` = 0, `ilvl_macc` = 0 WHERE `itemId` = 21368;
REPLACE INTO `item_mods` (`itemId`, `modId`, `value`) VALUES
  (21368, 345, 500), (21368, 73, 10), (21368, 26, 20);

-- Custom Job Ability: Throwing Stance (404) unlocked dynamically by Bladewheel Lv 10+
DELETE FROM `abilities` WHERE `abilityId` = 404 OR `name` = 'throwing_stance';
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (404, 'throwing_stance', 19, 255, 1, 5, 154, 0, 0, 28, 1000, 0, 6, 0.0, 0, 0, 1, 1, 0, 0, NULL);
