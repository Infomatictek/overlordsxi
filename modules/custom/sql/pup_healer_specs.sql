-- OverlordsXI Puppetmaster Crystal Spec (Animist - Healer)
-- Define custom PUP Animist Job Abilities (466-467; recastIds 166-167) with level = 255:
--   - Aether Overhaul (466, 20s CD, Self / Party 15y, recastId 166)
--   - Clockwork Aegis (467, 25s CD, Self / Party 15y, recastId 167)

DELETE FROM `abilities`
WHERE `abilityId` IN (466, 467)
   OR `name` IN ('aether_overhaul', 'clockwork_aegis');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Aether Overhaul (466): 20s CD, Self / Party 15y, recastId 166
    (466, 'aether_overhaul', 18, 255, 1, 20, 166, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Clockwork Aegis (467): 25s CD, Self / Party 15y, recastId 167
    (467, 'clockwork_aegis', 18, 255, 1, 25, 167, 100, 0, 301, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
