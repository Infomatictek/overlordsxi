-- SoulspireXI Corsair Crystal Specs (Flintlock, Buccaneer, Gambler)
-- 1. Un-gate merit abilities Snake Eye (177) and Fold (178) so Gambler can unlock/use them at Lv. 10+.
-- 2. Define custom COR Job Abilities (472-477; recastIds 168-173) with level = 255:
--      - House Advantage     (472, 30s CD, Self / Party 15y, recastId 168) [Gambler]
--      - Dead Man's Hand     (473, 35s CD, Single-Target Enemy 20y, recastId 169) [Gambler]
--      - Hair Trigger        (474, 30s CD, Self, recastId 170) [Flintlock]
--      - Broadside Salvo     (475, 22s CD, Single-Target Enemy 20y, recastId 171) [Flintlock]
--      - Grapeshot Broadside (476, 25s CD, Single-Target Enemy 12y, recastId 172) [Buccaneer]
--      - Iron Hull           (477, 45s CD, Self, recastId 173) [Buccaneer]

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` IN (177, 178);

DELETE FROM `abilities`
WHERE `abilityId` IN (472, 473, 474, 475, 476, 477)
   OR `name` IN (
        'house_advantage', 'ace_in_the_hole', 'dead_mans_hand',
        'hair_trigger', 'broadside_salvo',
        'grapeshot_broadside', 'iron_hull'
   );

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Gambler (472-473)
    (472, 'house_advantage',     17, 255, 1, 30, 168, 100, 0, 131, 1500, 0, 6,  0.0, 1, 15,   60,  180, 0, 0, NULL),
    (473, 'dead_mans_hand',      17, 255, 4, 35, 169,   0, 0, 131, 1500, 0, 6, 20.0, 0,  0,  120,  300, 0, 0, NULL),
    -- Flintlock (474-475)
    (474, 'hair_trigger',        17, 255, 1, 30, 170, 100, 0, 131, 1500, 0, 6,  0.0, 0,  0,   40,  100, 0, 0, NULL),
    (475, 'broadside_salvo',     17, 255, 4, 22, 171,   0, 0,  47, 1500, 0, 6, 20.0, 0,  0,  120,  320, 0, 0, NULL),
    -- Buccaneer (476-477)
    (476, 'grapeshot_broadside', 17, 255, 4, 25, 172, 110, 0,  47, 1500, 0, 6, 12.0, 0,  0,  400, 1400, 0, 0, NULL),
    (477, 'iron_hull',           17, 255, 1, 45, 173, 100, 0, 131, 1500, 0, 6,  0.0, 0,  0,   80,  220, 0, 0, NULL);
