-- OverlordsXI Red Mage Crystal Specs (Crimson Duelist)
-- Define custom RDM spec Job Abilities (447-448) with independent recast timers (179-180)
-- and level = 255 so they stay hidden unless dynamically unlocked via patch 0007.

DELETE FROM `abilities`
WHERE `abilityId` IN (447, 448)
   OR `name` IN ('hex_volley', 'crimson_fleche');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Hex Volley (447): 25s CD, Enemy (8y), recastId 179
    (447, 'hex_volley',     5, 255, 4, 25, 179, 110, 0, 201, 1500, 0, 6, 8.0, 0, 0, 200, 600, 0, 0, NULL),
    -- Crimson Fleche (448): 20s CD, Self (6s), recastId 180
    (448, 'crimson_fleche', 5, 255, 1, 20, 180, 100, 0, 301, 1500, 0, 6, 0.0, 0, 0, 120, 360, 0, 0, NULL);
