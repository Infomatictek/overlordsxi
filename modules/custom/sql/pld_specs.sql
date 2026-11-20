-- SoulspireXI Paladin Crystal Specs (Aegis Templar)
-- 1. Un-gate merit ability Chivalry (158) so PLD can use it without merit gating.
-- 2. Define custom PLD spec Job Abilities (439-440) with independent recast timers (177-178)
--    and level = 255 so they stay hidden unless dynamically unlocked via patch 0007.

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` = 158;

DELETE FROM `abilities`
WHERE `abilityId` IN (439, 440)
   OR `name` IN ('aegis_consecration', 'judgment_gavel');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Aegis Consecration (439): 25s CD, Self (10y Aura, 10s), recastId 177
    (439, 'aegis_consecration', 7, 255, 1, 25, 177, 100, 0, 301, 2000, 0, 6, 0.0, 1, 10, 120, 360, 0, 0, NULL),
    -- Judgment Gavel (440): 20s CD, Enemy (4y), recastId 178
    (440, 'judgment_gavel',     7, 255, 4, 20, 178, 110, 0, 201, 1500, 0, 6, 4.0, 0,  0, 150, 450, 0, 0, NULL);
