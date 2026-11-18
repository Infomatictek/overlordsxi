-- OverlordsXI WAR Spartan Custom Job Abilities (402-403)
-- Reuses the former Gladiator ability IDs in place (402 crimson_crush -> impaling_thrust,
-- 403 vanguard_ward -> phalanx_ward). Level 255 keeps them hidden unless dynamically
-- unlocked at Lv.10+ for WAR Spartan via patch 0007 (extraAbilities).
-- AnimationTime = 2000ms provides natural JA attack lockout.

DELETE FROM `abilities` WHERE `abilityId` IN (402, 403) OR `name` IN ('crimson_crush', 'vanguard_ward', 'impaling_thrust', 'phalanx_ward');

-- Impaling Thrust: 20s CD, Enemy Target (8y), recastId 192
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (402, 'impaling_thrust', 1, 255, 4, 20, 192, 110, 0, 201, 2000, 0, 6, 8.0, 0, 0, 150, 450, 0, 0, NULL);

-- Phalanx Ward: 35s CD, Self, recastId 193 (status effect 820)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (403, 'phalanx_ward', 1, 255, 1, 35, 193, 100, 0, 28, 2000, 0, 6, 0.0, 0, 0, 80, 240, 0, 0, NULL);