-- OverlordsXI Puppetmaster Crystal Spec (Vanguard)
-- Define Vanguard's custom Job Abilities with level = 255 so they stay hidden unless
-- dynamically unlocked via patch 0007:
--   - Aegis Protocol (445, 25s CD, Self / Automaton, recastId 168)
--   - Gyro Slam      (446, 20s CD, Enemy 8y,         recastId 169)

DELETE FROM `abilities`
WHERE `abilityId` IN (445, 446)
   OR `name` IN ('aegis_protocol', 'gyro_slam');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (445, 'aegis_protocol', 18, 255, 1, 25, 168, 100, 0, 207, 1500, 0, 6, 0.0, 0, 0, 100, 300, 0, 0, NULL),
    (446, 'gyro_slam',      18, 255, 4, 20, 169, 110, 0, 201, 1500, 0, 6, 8.0, 0, 0, 300, 900, 0, 0, NULL);
