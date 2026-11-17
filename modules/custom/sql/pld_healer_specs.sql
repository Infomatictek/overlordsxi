-- OverlordsXI Paladin Crystal Spec (Templar - Healer)
-- Define custom PLD Templar Job Abilities (458-459; recastIds 82-83) with level = 255:
--   - Holy Radiance    (458, 20s CD, Self / Party 15y, recastId 82)
--   - Crusader's Aegis (459, 25s CD, Self / Party 15y, recastId 83)

DELETE FROM `abilities`
WHERE `abilityId` IN (458, 459)
   OR `name` IN ('holy_radiance', 'crusaders_aegis');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Holy Radiance (458): 20s CD, Self / Party 15y, recastId 82
    (458, 'holy_radiance',   7, 255, 1, 20, 82, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Crusader's Aegis (459): 25s CD, Self / Party 15y, recastId 83
    (459, 'crusaders_aegis', 7, 255, 1, 25, 83, 100, 0, 301, 1800, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
