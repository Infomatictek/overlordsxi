-- SoulspireXI White Mage Crystal Spec (Bishop)
-- 1. Un-gate merit abilities Martyr (153) & Devotion (154) and Afflatus Solace (245) is Lv40 (unlocked @ Lv10 via patch 0007).
-- 2. Define custom WHM Bishop Job Abilities (456-457; recastIds 55-56) with level = 255:
--      - Divine Veil     (456, 25s CD, Self / Party 15y, recastId 55)
--      - Sanctuary Pulse (457, 20s CD, Self / Party 15y, recastId 56)

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` IN (153, 154);

DELETE FROM `abilities`
WHERE `abilityId` IN (456, 457)
   OR `name` IN ('divine_veil', 'sanctuary_pulse');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Divine Veil (456): 25s CD, Self / Party 15y, recastId 55
    (456, 'divine_veil',     3, 255, 1, 25, 55, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Sanctuary Pulse (457): 20s CD, Self / Party 15y, recastId 56
    (457, 'sanctuary_pulse', 3, 255, 1, 20, 56, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
