-- OverlordsXI BLM Necromancer Spec Data
-- Custom Job Abilities (405-411), Undead Pets (130-133), Spell Lists (601-602),
-- and Scythe equipment eligibility for BLM (job bit 8).

-- ---------------------------------------------------------------------------
-- 1. Custom Job Abilities (Level 255 so they stay hidden unless unlocked by spec)
-- ---------------------------------------------------------------------------
DELETE FROM `abilities` WHERE `abilityId` IN (405, 406, 407, 408, 409, 410, 411)
    OR `name` IN ('summon_undead_warrior', 'summon_undead_mage', 'corpse_explosion', 'grim_reaping', 'grim_incantations', 'summon_corse', 'summon_dullahan');

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Summon Undead Warrior (Lv.10+ Necromancer, 60s recast, shared summon recastId 194)
    (405, 'summon_undead_warrior', 4, 255, 1, 60, 194, 0, 0, 171, 2000, 0, 6, 0.0, 0, 0, 1, 80, 0, 0, NULL),
    -- Summon Undead Mage (Lv.10+ Necromancer, 60s recast, shared summon recastId 194)
    (406, 'summon_undead_mage',    4, 255, 1, 60, 194, 0, 0, 171, 2000, 0, 6, 0.0, 0, 0, 1, 80, 0, 0, NULL),
    -- Corpse Explosion (Lv.10+ Necromancer, 45s recast, recastId 195)
    (407, 'corpse_explosion',      4, 255, 1, 45, 195, 0, 0, 182, 2000, 0, 6, 0.0, 0, 0, 200, 600, 0, 0, NULL),
    -- Grim Reaping (Warrior / Dullahan command, 30s recast, recastId 196)
    (408, 'grim_reaping',          4, 255, 4, 30, 196, 0, 0, 171, 1500, 0, 6, 15.0, 0, 0, 120, 300, 0, 0, NULL),
    -- Grim Incantations (Mage / Corse command, 30s recast, recastId 197)
    (409, 'grim_incantations',     4, 255, 4, 30, 197, 0, 0, 171, 1500, 0, 6, 20.0, 0, 0, 100, 250, 0, 0, NULL),
    -- Summon Corse (Lv.75+ Necromancer, 60s recast, shared summon recastId 194)
    (410, 'summon_corse',          4, 255, 1, 60, 194, 0, 0, 171, 2000, 0, 6, 0.0, 0, 0, 1, 80, 0, 0, NULL),
    -- Summon Dullahan (Lv.75+ Necromancer, 60s recast, shared summon recastId 194)
    (411, 'summon_dullahan',       4, 255, 1, 60, 194, 0, 0, 171, 2000, 0, 6, 0.0, 0, 0, 1, 80, 0, 0, NULL);

-- Allow Sic (72) to work on Jug/Undead Pets (ADDTYPE_JUGPET | ADDTYPE_CHARMPET = 192)
UPDATE `abilities` SET `addType` = 192 WHERE `abilityId` = 72;

-- ---------------------------------------------------------------------------
-- 2. Undead Pets (Pet IDs 130-133 require patches/0016-blm-necromancer-pets.patch)
-- ---------------------------------------------------------------------------
DELETE FROM `pet_list` WHERE `petid` IN (130, 131, 132, 133);
INSERT INTO `pet_list`
    (`petid`, `name`, `poolid`, `minLevel`, `maxLevel`, `time`, `element`, `damageType`)
VALUES
    (130, 'Undead Warrior', 6022, 1, 99, 86400, 8, 2),
    (131, 'Undead Mage',    6023, 1, 99, 86400, 8, 1),
    (132, 'Corse',          6024, 1, 99, 86400, 8, 1),
    (133, 'Dullahan',       6025, 1, 99, 86400, 8, 2);

DELETE FROM `mob_pools` WHERE `poolid` IN (6022, 6023, 6024, 6025);

-- 6022: Undead Warrior (Skeleton Warrior model)
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
SELECT
    6022, 'undead_warrior', 'Undead Warrior', `speciesid`, `modelid`, 1, 8, 1, 240, 100,
    0, 0, 0, 0, 0, 0, 32, 0, 3,
    0, 0, 0, 0, 0, `skill_list_id`, `resist_id`,
    0, 6
FROM `mob_pools`
WHERE `name` IN ('Wight_war', 'Guard_Skeleton_war_SSR', 'Crossbones', 'Skeleton_Warrior', 'Ghoul')
   OR `poolid` IN (4337, 6556)
LIMIT 1;

-- 6023: Undead Mage (Skeleton Mage / Lich model)
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
SELECT
    6023, 'undead_mage', 'Undead Mage', `speciesid`, `modelid`, 4, 8, 1, 240, 90,
    0, 0, 0, 0, 0, 0, 32, 0, 3,
    0, 0, 601, 0, 0, `skill_list_id`, `resist_id`,
    0, 6
FROM `mob_pools`
WHERE `name` IN ('Doom_Mage_SSR', 'Guard_Skeleton_blm_SSR', 'Tomb_Mage', 'Lich', 'Fallen_Mage', 'Crossbones')
   OR `poolid` IN (6533, 6555)
LIMIT 1;

-- 6024: Corse (Corse model)
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
SELECT
    6024, 'undead_corse', 'Corse', `speciesid`, `modelid`, 4, 20, 1, 240, 100,
    0, 0, 0, 0, 0, 0, 32, 0, 3,
    0, 0, 602, 0, 0, `skill_list_id`, `resist_id`,
    0, 6
FROM `mob_pools`
WHERE `name` LIKE '%Corse%' OR `packet_name` LIKE '%Corse%'
LIMIT 1;

-- 6025: Dullahan (Dullahan model)
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
SELECT
    6025, 'undead_dullahan', 'Dullahan', `speciesid`, `modelid`, 8, 1, 7, 240, 115,
    0, 0, 0, 0, 0, 0, 32, 0, 3,
    0, 0, 0, 0, 0, `skill_list_id`, `resist_id`,
    0, 6
FROM `mob_pools`
WHERE `name` LIKE '%Dullahan%' OR `packet_name` LIKE '%Dullahan%'
LIMIT 1;

-- ---------------------------------------------------------------------------
-- 3. Undead Mage (601) & Corse (602) Spell Lists
-- ---------------------------------------------------------------------------
DELETE FROM `mob_spell_lists` WHERE `spell_list_id` IN (601, 602);
INSERT INTO `mob_spell_lists` (`spell_list_name`, `spell_list_id`, `spell_id`, `min_level`, `max_level`) VALUES
    ('undead_mage', 601, 230, 10, 255), -- Bio
    ('undead_mage', 601, 231, 35, 255), -- Bio II
    ('undead_mage', 601, 245, 12, 255), -- Drain
    ('undead_mage', 601, 247, 25, 255), -- Aspir
    ('undead_mage', 601, 254, 4,  255), -- Blind
    ('undead_mage', 601, 159, 1,  255), -- Stone
    ('undead_mage', 601, 149, 17, 255), -- Blizzard
    ('undead_mage', 601, 164, 21, 255), -- Thunder
    ('undead_mage', 601, 160, 26, 255), -- Stone II
    ('undead_mage', 601, 150, 42, 255), -- Blizzard II
    ('undead_mage', 601, 165, 46, 255), -- Thunder II
    ('undead_mage', 601, 151, 67, 255), -- Blizzard III
    ('undead_mage', 601, 166, 71, 255), -- Thunder III

    ('undead_corse', 602, 231, 10, 255), -- Bio II
    ('undead_corse', 602, 245, 10, 255), -- Drain
    ('undead_corse', 602, 246, 62, 255), -- Drain II
    ('undead_corse', 602, 247, 10, 255), -- Aspir
    ('undead_corse', 602, 248, 75, 255), -- Aspir II
    ('undead_corse', 602, 254, 10, 255), -- Blind
    ('undead_corse', 602, 58,  10, 255), -- Paralyze
    ('undead_corse', 602, 260, 32, 255), -- Dispel
    ('undead_corse', 602, 151, 67, 255), -- Blizzard III
    ('undead_corse', 602, 166, 71, 255), -- Thunder III
    ('undead_corse', 602, 152, 75, 255), -- Blizzard IV
    ('undead_corse', 602, 167, 75, 255), -- Thunder IV
    ('undead_corse', 602, 153, 89, 255), -- Blizzard V
    ('undead_corse', 602, 168, 91, 255); -- Thunder V

-- ---------------------------------------------------------------------------
-- 4. Allow BLM (job bit 8 = 1 << (4 - 1)) to equip Scythes (skill = 7)
-- ---------------------------------------------------------------------------
UPDATE `item_equipment` ie
INNER JOIN `item_weapon` iw ON ie.`itemId` = iw.`itemId`
SET ie.`jobs` = (ie.`jobs` | 8)
WHERE iw.`skill` = 7;
