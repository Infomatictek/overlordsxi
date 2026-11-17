-- OverlordsXI Dancer Crystal Spec (Mirage Sentinel)
-- 1. Un-gate merit abilities Fan Dance (238) and No Foot Rise (239) so Mirage Sentinel
--    can unlock/use them without merit gating.
-- 2. Define Mirage Sentinel's custom Job Abilities (454-455; recastIds 152-153) with
--    level = 255 so they stay hidden unless dynamically unlocked via patch 0007:
--      - Pirouette Deflect (454, 20s CD, Self, recastId 152)
--      - Dazzling Cadence  (455, 25s CD, Enemy 8y, recastId 153)

UPDATE `abilities`
SET `addType` = 0, `meritModID` = 0, `content_tag` = NULL
WHERE `abilityId` IN (238, 239);

DELETE FROM `abilities`
WHERE `abilityId` IN (454, 455)
   OR `name` IN ('pirouette_deflect', 'dazzling_cadence');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Pirouette Deflect (454): 20s CD, Self (8s), recastId 152
    (454, 'pirouette_deflect', 19, 255, 1, 20, 152,   0, 0, 208, 1500, 0, 6, 0.0, 0, 0,  60,  180, 0, 0, NULL),
    -- Dazzling Cadence (455): 25s CD, Enemy (8y), recastId 153
    (455, 'dazzling_cadence',  19, 255, 4, 25, 153, 110, 0,  26, 1500, 0, 6, 8.0, 0, 0, 300, 1100, 0, 0, NULL);
