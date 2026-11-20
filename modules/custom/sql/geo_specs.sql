-- SoulspireXI Geomancer Crystal Spec (Verdant - Healer)
-- 1. Un-gate merit ability Life Cycle (349) so Verdant can use it without merit gating.
-- 2. Define custom GEO Verdant Job Abilities (468-469; recastIds 164-165) with level = 255:
--      - Verdant Renewal       (468, 20s CD, Self / Party 15y, recastId 164)
--      - Canopy of the Ancients (469, 25s CD, Self / Party 15y, recastId 165)

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` = 349;

DELETE FROM `abilities`
WHERE `abilityId` IN (468, 469)
   OR `name` IN ('verdant_renewal', 'canopy_of_the_ancients');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Verdant Renewal (468): 20s CD, Self / Party 15y, recastId 164
    (468, 'verdant_renewal',        21, 255, 1, 20, 164, 100, 0, 207, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL),
    -- Canopy of the Ancients (469): 25s CD, Self / Party 15y, recastId 165
    (469, 'canopy_of_the_ancients', 21, 255, 1, 25, 165, 100, 0, 301, 1500, 0, 6, 0.0, 1, 15, 60, 180, 0, 0, NULL);
