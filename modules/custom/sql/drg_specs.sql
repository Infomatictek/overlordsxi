-- OverlordsXI Dragoon Crystal Spec (Wyvernheart - Healer)
-- 1. Un-gate merit ability Spirit Link (80) so Wyvernheart can use it without merit gating.
-- 2. Define custom DRG Wyvernheart Job Abilities (470-471; recastIds 148, 185) with level = 255:
--      - Wyrmblood Pulse       (470, 20s CD, Self / Party 15y, recastId 148)
--      - Dragonscale Sanctuary (471, 25s CD, Self / Party 15y, recastId 185)

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` = 80;

DELETE FROM `abilities`
WHERE `abilityId` IN (470, 471)
   OR `name` IN ('wyrmblood_pulse', 'dragonscale_sanctuary');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Wyrmblood Pulse (470): 20s CD, Self / Party 15y, recastId 148
    (470, 'wyrmblood_pulse',       14, 255, 1, 20, 148, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Dragonscale Sanctuary (471): 25s CD, Self / Party 15y, recastId 185
    (471, 'dragonscale_sanctuary', 14, 255, 1, 25, 185, 100, 0, 301, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
