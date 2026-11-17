-- OverlordsXI Dark Knight Crystal Specs (Dreadnought)
-- Define custom DRK spec Job Abilities (443-444) with independent recast timers (218-219)
-- and level = 255 so they stay hidden unless dynamically unlocked via patch 0007.

DELETE FROM `abilities`
WHERE `abilityId` IN (443, 444)
   OR `name` IN ('abyssal_cleave', 'dread_bastion');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Abyssal Cleave (443): 20s CD, Enemy (8y), recastId 218
    (443, 'abyssal_cleave', 8, 255, 4, 20, 218, 110, 0, 201, 1500, 0, 6, 8.0, 0, 0, 200, 750, 0, 0, NULL),
    -- Dread Bastion (444): 35s CD, Self (10s), recastId 219
    (444, 'dread_bastion',  8, 255, 1, 35, 219, 100, 0, 301, 1800, 0, 6, 0.0, 0, 0, 120, 360, 0, 0, NULL);
