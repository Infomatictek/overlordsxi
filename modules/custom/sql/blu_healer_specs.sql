-- OverlordsXI Blue Mage Crystal Spec (Magus - Healer)
-- 1. Un-gate merit ability Diffusion (176) so Magus can unlock/use it at Lv10+ via patch 0007.
-- 2. Define custom BLU Magus Job Abilities (460-461; recastIds 111, 144) with level = 255:
--      - White Wind Surge (460, 40s CD, Self / Party 15y, recastId 111)
--      - Osmotic Conduit  (461, 60s CD, Self / Party 15y, recastId 144)

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` = 176;

DELETE FROM `abilities`
WHERE `abilityId` IN (460, 461)
   OR `name` IN ('white_wind_surge', 'osmotic_conduit');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- White Wind Surge (460): 40s CD, Self / Party 15y, recastId 111
    (460, 'white_wind_surge', 16, 255, 1, 40, 111, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Osmotic Conduit (461): 60s CD, Self / Party 15y, recastId 144
    (461, 'osmotic_conduit',  16, 255, 1, 60, 144, 100, 0, 301, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
