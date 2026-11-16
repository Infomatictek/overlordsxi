-- OverlordsXI Rune Fencer Crystal Specs (Inquisitor, Spellblade, Lifebinder)
-- 1. Backport post-75 RUN abilities (Liement, One for All, Odyllic Subterfuge) to Lv 75
--    and clear merit addType on Rayke (375) and Battuta (376) so crystal extraAbilities can unlock them.
-- 2. Backport RUN Regen IV (spell 477) from Lv 99 (0x63) to Lv 75 (0x4B).
-- 3. Define custom RUN Spellblade Magic Spells: Runic Bolt (spell 363, Lv 10) & Runic Sever (spell 364, Lv 55).
-- 4. Define custom RUN spec Job Abilities (412-418) with independent recast timers (198, 199, 201-205)
--    and level = 255 so they stay hidden unless dynamically unlocked via patch 0007.

-- Post-75 RUN abilities scaled to <= Lv 75 & un-gated from merit addType
UPDATE `abilities` SET `level` = 75 WHERE `abilityId` IN (373, 374, 378) AND `level` > 75;
UPDATE `abilities` SET `addType` = 0 WHERE `abilityId` IN (375, 376);
-- Hide empty Ward (379) and Effusion (380) category headers (RUN abilities are top-level in 114.DAT so 0x16/0x17 stay free for BLM Necromancer)
UPDATE `abilities` SET `level` = 255 WHERE `abilityId` IN (379, 380);

-- Allow RUN (job 22 = byte 22 of jobs blob) to learn Regen IV (spellId 477) at Lv 75 (0x4B)
UPDATE `spell_list`
SET `jobs` = CONCAT(SUBSTRING(`jobs`, 1, 21), CHAR(75))
WHERE `spellid` = 477 AND LENGTH(`jobs`) >= 22;

-- Custom RUN Spellblade Magic Spells (363 = runic_bolt at Lv 10, 364 = runic_sever at Lv 55)
DELETE FROM `spell_list` WHERE `spellid` IN (363, 364, 754, 755) OR `name` IN ('runic_bolt', 'runic_sever');
INSERT INTO `spell_list`
    (`spellid`, `name`, `jobs`, `group`, `family`, `element`, `zonemisc`, `validTargets`, `skill`,
     `mpCost`, `castTime`, `recastTime`, `message`, `magicBurstMessage`, `animation`, `animationTime`,
     `AOE`, `base`, `multiplier`, `CE`, `VE`, `requirements`, `spell_range`, `radius`, `content_tag`,
     `status_effect`, `status_effect_tier`)
VALUES
    -- Runic Bolt (363): Black Magic (2), Elemental Skill (36), Enemy (4), Lv 10 RUN (byte 22 = 0x0A), 8 MP, 2000ms cast, 8000ms recast, 10y range (100)
    (363, 'runic_bolt',  0x0000000000000000000000000000000000000000000A, 2, 0, 1, 0, 4, 36,  8, 2000,  8000, 2, 252, 144, 1500, 0, 35, 1.00, 1,  80, 0, 100, 0, NULL, NULL, 0),
    -- Runic Sever (364): Black Magic (2), Elemental Skill (36), Enemy (4), Lv 55 RUN (byte 22 = 0x37), 22 MP, 3000ms cast, 30000ms recast, 10y range (100)
    (364, 'runic_sever', 0x00000000000000000000000000000000000000000037, 2, 0, 5, 0, 4, 36, 22, 3000, 30000, 2, 252, 165, 1500, 0, 85, 1.50, 1, 120, 0, 100, 0, NULL, NULL, 0);

-- Custom RUN Spec Job Abilities (412-418)
DELETE FROM `abilities`
WHERE `abilityId` IN (412, 413, 414, 415, 416, 417, 418)
   OR `name` IN ('iron_battuta', 'runic_aegis', 'runic_convergence', 'effusion_slash', 'overcharge_runes', 'runic_bolt', 'runic_sever', 'font_of_life', 'sanctified_ward');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Inquisitor (Tank): Stance: Iron Battuta (412, 15s CD, Self, recastId 198)
    (412, 'iron_battuta',      22, 255, 1, 15, 198, 100, 0, 299, 2000,    0, 6,  0.0, 0,  0, 120, 360, 0, 0, NULL),
    -- Inquisitor (Tank): Stance: Runic Aegis (413, 15s CD, Self, recastId 199)
    (413, 'runic_aegis',       22, 255, 1, 15, 199, 100, 0, 301, 2000,    0, 6,  0.0, 0,  0, 120, 360, 0, 0, NULL),
    -- Inquisitor (Tank): Runic Convergence (414, 30s CD, Self, recastId 201)
    (414, 'runic_convergence', 22, 255, 1, 30, 201, 100, 0, 302, 2000,    0, 6,  0.0, 0,  0, 200, 600, 0, 0, NULL),
    -- Spellblade (DPS) Legacy JA Aliases (415 & 416, hidden unless called by macro)
    (415, 'runic_bolt',        22, 255,  4,  8, 202, 110, 0,  10, 1500, 2000, 6, 10.0, 0,  0,   1,  80, 0, 0, NULL),
    (416, 'runic_sever',       22, 255,  4, 30, 203, 110, 0,  20, 1500, 3000, 6, 10.0, 0,  0,   1, 120, 0, 0, NULL),
    -- Lifebinder (Healer): Font of Life (417, 20s CD, Self/Party 15y, recastId 204)
    (417, 'font_of_life',      22, 255, 3, 20, 204, 102, 0, 327, 2000,    0, 6, 15.0, 0,  0,   1, 120, 0, 0, NULL),
    -- Lifebinder (Healer): Sanctified Ward (418, 35s CD, Self/Party 12y AoE, recastId 205)
    (418, 'sanctified_ward',   22, 255, 1, 35, 205, 100, 0, 301, 2000,    0, 6,  0.0, 1, 12,  40, 180, 0, 0, NULL);
