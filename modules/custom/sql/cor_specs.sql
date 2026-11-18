-- OverlordsXI Corsair Crystal Spec (Gambler - Support)
-- 1. Un-gate merit abilities Snake Eye (177) and Fold (178) so Gambler can unlock/use them at Lv. 10+.
-- 2. Define custom COR Gambler Job Abilities (472-473; recastIds 168-169) with level = 255:
--      - House Advantage (472, 30s CD, Self / Party 15y, recastId 168)
--      - Ace in the Hole (473, 25s CD, Enemy 20y / Party 15y, recastId 169)

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` IN (177, 178);

DELETE FROM `abilities`
WHERE `abilityId` IN (472, 473)
   OR `name` IN ('house_advantage', 'ace_in_the_hole');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- House Advantage (472): 30s CD, Self / Party 15y, recastId 168
    (472, 'house_advantage', 17, 255, 1, 30, 168, 100, 0, 131, 1500, 0, 6,  0.0, 1, 15,  60, 180, 0, 0, NULL),
    -- Ace in the Hole (473): 25s CD, Enemy 20y / Party 15y, recastId 169
    (473, 'ace_in_the_hole', 17, 255, 4, 25, 169,   0, 0, 131, 1500, 0, 6, 20.0, 0,  0, 120, 300, 0, 0, NULL);
