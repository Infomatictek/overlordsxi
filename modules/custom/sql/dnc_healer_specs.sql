-- OverlordsXI Dancer Crystal Spec (Vampire - Healer)
-- Define custom DNC Vampire Job Abilities (462-463; recastIds 155-156) with level = 255:
--   - Sanguine Waltz (462, 18s CD, Self / Party 15y, recastId 155)
--   - Nocturne Feast (463, 25s CD, Enemy 8y / Party 15y, recastId 156)

DELETE FROM `abilities`
WHERE `abilityId` IN (462, 463)
   OR `name` IN ('sanguine_waltz', 'nocturne_feast');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Sanguine Waltz (462): 18s CD, Self / Party 15y, recastId 155
    (462, 'sanguine_waltz', 19, 255, 1, 18, 155, 100, 0, 208, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Nocturne Feast (463): 25s CD, Enemy 8y, recastId 156
    (463, 'nocturne_feast', 19, 255, 4, 25, 156, 110, 0,  26, 1500, 0, 6, 8.0, 0,  0, 80, 240, 0, 0, NULL);
