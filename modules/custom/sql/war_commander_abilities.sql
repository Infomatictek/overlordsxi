-- OverlordsXI WAR Commander Custom Job Abilities (396-399)
-- Level set to 255 so these abilities stay hidden unless dynamically unlocked
-- at Lv.10+ for WAR Commander via patch 0007 (extraAbilities).
-- AnimationTime = 2000ms provides natural JA attack lockout to balance frequent active weaving.

DELETE FROM `abilities` WHERE `abilityId` IN (396, 397, 398, 399) OR `name` IN ('tactical_breach', 'formation_bulwark', 'battle_cadence', 'rallying_horn');

-- Tactical Breach: 20s CD, Enemy Target (15y), recastId 186
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (396, 'tactical_breach', 1, 255, 4, 20, 186, 119, 0, 244, 2000, 0, 6, 15.0, 0, 0, 1, 180, 0, 0, NULL);

-- Formation: Bulwark: 25s CD, Self/Party 10y AoE, recastId 187
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (397, 'formation_bulwark', 1, 255, 1, 25, 187, 100, 0, 28, 2000, 0, 6, 0.0, 1, 10, 1, 120, 0, 0, NULL);

-- Battle Cadence: 20s CD, Self/Party 10y AoE, recastId 188
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (398, 'battle_cadence', 1, 255, 1, 20, 188, 100, 0, 239, 2000, 0, 6, 0.0, 1, 10, 1, 80, 0, 0, NULL);

-- Rallying Horn: 45s CD, Self/Party 12y AoE, recastId 189
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (399, 'rallying_horn', 1, 255, 1, 45, 189, 100, 0, 28, 2000, 0, 6, 0.0, 1, 12, 1, 120, 0, 0, NULL);
