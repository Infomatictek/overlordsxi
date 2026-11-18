-- OverlordsXI Beastmaster Crystal Spec Data (Alpha Warden)
-- 1. Ensure core BST abilities (Familiar 77, Reward 78, Call Beast 85, Snarl 225,
--    Bestial Loyalty 387) are not gated behind expansion content tags.
-- 2. Define Alpha Warden's two crystal-unlocked Job Abilities (level = 255 so they
--    stay hidden unless dynamically unlocked via patch 0007):
--      - Soul Bond (441, recastId 216): 25s CD, Self & Pet (10s)
--      - Feral Roar (442, recastId 217): 20s CD, Enemy (8y)

UPDATE `abilities`
SET `content_tag` = NULL
WHERE `abilityId` IN (77, 78, 85, 225, 387);

DELETE FROM `abilities`
WHERE `abilityId` IN (441, 442)
   OR `name` IN ('soul_bond', 'feral_roar');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Soul Bond (441): 35s CD, Self & Pet, recastId 216
    (441, 'soul_bond',  9, 255, 1, 35, 216, 100, 0, 239, 1500, 0, 6, 0.0, 0, 0, 300,  900, 0, 0, NULL),
    -- Feral Roar (442): 25s CD, Enemy Target (8y), recastId 217
    (442, 'feral_roar', 9, 255, 4, 25, 217, 110, 0, 126, 1500, 0, 6, 8.0, 0, 0, 300, 1800, 0, 0, NULL);
