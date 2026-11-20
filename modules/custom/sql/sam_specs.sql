-- SoulspireXI Samurai Crystal Specs (Ronin, Imperial Archer, Warlord)
-- 1. Un-gate merit abilities Shikikoyo (167) and Blade Bash (168) so SAM learns them
--    naturally at Lv.75 and crystal specs can unlock them early via extraAbilities.
-- 2. Backport post-75 SAM abilities Sengikori (258), Hamanoha (287), and Hagakure (288)
--    to Lv.75 and clear expansion content_tag gating so they function under the Lv.75 cap.
-- 3. Define Imperial Archer's 20y ranged signature Job Ability Oisoya Shot (438, recastId 215)
--    and Warlord's party surge Job Ability Onimaru Tithe (453, recastId 151)
--    with level = 255 so they stay hidden unless dynamically unlocked via patch 0007.

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` IN (167, 168);

UPDATE `abilities`
SET `level` = 75, `content_tag` = NULL
WHERE `abilityId` IN (258, 287, 288) AND `level` > 75;

UPDATE `abilities`
SET `content_tag` = NULL
WHERE `abilityId` IN (258, 287, 288, 320);

DELETE FROM `abilities`
WHERE `abilityId` IN (438, 453)
   OR `name` IN ('oisoya_shot', 'onimaru_tithe');

-- Oisoya Shot (438): 25s CD, Enemy Target (20y), recastId 215
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (438, 'oisoya_shot', 12, 255, 4, 25, 215, 110, 0, 186, 1500, 0, 6, 20.0, 0, 0, 20, 120, 0, 0, NULL);

-- Onimaru Tithe (453): 25s CD, Party (15y, 12s), recastId 151
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (453, 'onimaru_tithe', 12, 255, 1, 25, 151, 100, 0, 301, 1800, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
