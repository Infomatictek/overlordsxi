-- OverlordsXI Puppetmaster Crystal Specs (Vanguard & Pugilist)
-- 1. Un-gate merit/expansion abilities Ventriloquy (180), Cooldown (309), and Deus Ex Automata (310)
--    so all PUP specs can unlock them at Lv.10+ via patch 0007.
UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` IN (180, 309, 310);

-- 2. Define Vanguard (451-452; recastIds 168-169) and Pugilist (478-479; recastIds 174-175)
--    custom Job Abilities with level = 255 so they stay hidden unless dynamically unlocked:
--      - Clockwork Bulwark (451, 35s CD, Self / Automaton, recastId 168) [Vanguard]
--      - Hydraulic Slam    (452, 22s CD, Single-Target Enemy 6y, recastId 169) [Vanguard]
--      - Tandem Barrage    (478, 25s CD, Single-Target Enemy 6y, recastId 174) [Pugilist]
--      - Limiter Release   (479, 35s CD, Self / Automaton, recastId 175) [Pugilist]

DELETE FROM `abilities`
WHERE `abilityId` IN (451, 452, 478, 479)
   OR `name` IN ('aegis_protocol', 'gyro_slam', 'clockwork_bulwark', 'hydraulic_slam', 'tandem_barrage', 'limiter_release');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Vanguard (451-452; reuse existing IDs in-place)
    (451, 'aegis_protocol',  18, 255, 1, 35, 168, 100, 0, 207, 1500, 0, 6, 0.0, 0, 0, 100,  300, 0, 0, NULL),
    (452, 'gyro_slam',       18, 255, 4, 22, 169, 110, 0, 201, 1500, 0, 6, 6.0, 0, 0, 400, 1800, 0, 0, NULL),
    -- Pugilist (478-479; newly allocated contiguous IDs)
    (478, 'tandem_barrage',  18, 255, 4, 25, 174, 110, 0, 201, 1500, 0, 6, 6.0, 0, 0,  80,  240, 0, 0, NULL),
    (479, 'limiter_release', 18, 255, 1, 35, 175, 100, 0, 207, 1500, 0, 6, 0.0, 0, 0,  40,  120, 0, 0, NULL);
