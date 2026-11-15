-- OverlordsXI WAR Berserker Custom Job Abilities (400-401)
-- Level set to 255 so these abilities stay hidden unless dynamically unlocked
-- at Lv.10+ for WAR Berserker via patch 0007 (extraAbilities).
-- AnimationTime = 2000ms provides natural JA attack lockout.

DELETE FROM `abilities` WHERE `abilityId` IN (400, 401) OR `name` IN ('bloodlust_surge', 'savage_cleave');

-- Bloodlust Surge: 25s CD, Self, recastId 190
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (400, 'bloodlust_surge', 1, 255, 1, 25, 190, 100, 0, 244, 2000, 0, 6, 0.0, 0, 0, 1, 80, 0, 0, NULL);

-- Savage Cleave: 20s CD, Enemy Target (4y), recastId 191
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (401, 'savage_cleave', 1, 255, 4, 20, 191, 110, 0, 244, 2000, 0, 6, 4.0, 0, 0, 1, 220, 0, 0, NULL);
