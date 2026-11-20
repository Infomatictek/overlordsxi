-- SoulspireXI MNK Chi Weaver Custom Job Abilities (429-431)
-- Level set to 255 so these abilities stay hidden unless dynamically unlocked
-- at Lv.10+ for MNK Chi Weaver via patch 0007 (extraAbilities).
-- AnimationTime = 1500-2000ms provides natural JA timing.

DELETE FROM `abilities` WHERE `abilityId` IN (429, 430, 431) OR `name` IN ('resonant_chi', 'tranquil_lotus', 'inner_harmony');

-- Resonant Chi: 20s CD, Enemy Target (20y), recastId 206
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (429, 'resonant_chi', 2, 255, 4, 20, 206, 110, 0, 126, 1500, 0, 6, 20.0, 0, 0, 1, 60, 0, 0, NULL);

-- Tranquil Lotus: 30s CD, Self/Party 12y AoE, recastId 207
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (430, 'tranquil_lotus', 2, 255, 1, 30, 207, 100, 0, 301, 2000, 0, 6, 0.0, 1, 12, 20, 80, 0, 0, NULL);

-- Inner Harmony: 45s CD, Self, recastId 208
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (431, 'inner_harmony', 2, 255, 1, 45, 208, 100, 0, 239, 2000, 0, 6, 0.0, 0, 0, 10, 40, 0, 0, NULL);
