-- OverlordsXI Blue Mage Crystal Spec (Azure Bastion)
-- Define Azure Bastion's custom Job Abilities with level = 255 so they stay hidden unless
-- dynamically unlocked via patch 0007:
--   - Behemoth Roar (445, 25s CD, Enemy 8y, recastId 220)
--   - Diamond Shell (446, 30s CD, Self 10s, recastId 221)

DELETE FROM `abilities`
WHERE `abilityId` IN (445, 446)
   OR `name` IN ('behemoth_roar', 'diamond_shell');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Behemoth Roar (445): 25s CD, Enemy (8y), recastId 220
    (445, 'behemoth_roar', 16, 255, 4, 25, 220, 110, 0, 201, 1500, 0, 6, 8.0, 0, 0, 300, 900, 0, 0, NULL),
    -- Diamond Shell (446): 30s CD, Self (10s), recastId 221
    (446, 'diamond_shell', 16, 255, 1, 30, 221, 100, 0, 301, 1800, 0, 6, 0.0, 0, 0, 120, 360, 0, 0, NULL);
