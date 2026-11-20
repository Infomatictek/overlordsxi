-- SoulspireXI Summoner Crystal Spec (Celestial - Healer)
-- Define custom SMN Celestial Job Abilities (464-465; recastIds 141, 145) with level = 255:
--   - Astral Benediction    (464, 22s CD, Self / Party 15y, recastId 141)
--   - Celestial Convergence (465, 25s CD, Self / Party 15y, recastId 145)

DELETE FROM `abilities`
WHERE `abilityId` IN (464, 465)
   OR `name` IN ('astral_benediction', 'celestial_convergence');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Astral Benediction (464): 22s CD, Self / Party 15y, recastId 141
    (464, 'astral_benediction',    15, 255, 1, 22, 141, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Celestial Convergence (465): 25s CD, Self / Party 15y, recastId 145
    (465, 'celestial_convergence', 15, 255, 1, 25, 145, 100, 0, 301, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
