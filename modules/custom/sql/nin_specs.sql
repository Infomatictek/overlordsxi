-- SoulspireXI Ninja Crystal Specs (Shinobi & Kagemusha)
-- 1. Clear expansion content_tag gating on Yonin (248) and Futae (259), and backport Futae to Lv.75
--    so Kagemusha can unlock both at Lv.10+ via extraAbilities.
-- 2. Define Kagemusha's custom Job Abilities with level = 255 so they stay hidden unless
--    dynamically unlocked via patch 0007:
--      - Kage Bunshin    (443, 45s CD, Self,       recastId 218)
--      - Smoke Lotus     (444, 30s CD, Enemy 8y,   recastId 219)
-- 3. Define Shinobi's custom Job Abilities with level = 255 (unlocked at Lv.10+ via extraAbilities):
--      - Shadow Legion   (487, 90s CD, Enemy 12y,  recastId 238)
--      - Phantom Assault (488, 30s CD, Self,       recastId 239)

UPDATE `abilities`
SET `content_tag` = NULL
WHERE `abilityId` IN (248, 259);

UPDATE `abilities`
SET `level` = 75, `content_tag` = NULL
WHERE `abilityId` = 259 AND `level` > 75;

DELETE FROM `abilities`
WHERE `abilityId` IN (443, 444, 487, 488)
   OR `name` IN ('kage_bunshin', 'smoke_lotus', 'shadow_legion', 'phantom_assault');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (443, 'kage_bunshin',    13, 255, 1, 45, 218, 0,   0, 218, 1200, 0, 6,  0.0, 0, 0,  40, 120, 0, 0, NULL),
    (444, 'smoke_lotus',     13, 255, 4, 30, 219, 110, 0, 227, 1500, 0, 6,  8.0, 0, 0, 300, 900, 0, 0, NULL),
    (487, 'shadow_legion',   13, 255, 4, 90, 238, 0,   0, 227, 1200, 0, 6, 12.0, 0, 0,  80, 240, 0, 0, NULL),
    (488, 'phantom_assault', 13, 255, 1, 30, 239, 0,   0, 218, 1000, 0, 6,  0.0, 0, 0,  40, 120, 0, 0, NULL);
