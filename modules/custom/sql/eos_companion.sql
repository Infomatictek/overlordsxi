-- Eos & Titania Companion module data.
-- Apply with dbtool or import manually into xidb after copying this file into modules/custom/sql.
-- Note: Status effect definitions (789 & 814) are applied via patches/0006-eos-status-effect-params.patch.

-- Server-side SCH Medic job ability: Call Eos (client display ID 743 = 231 + 512).
-- Level is set to 255 so it remains hidden unless unlocked via SCH Medic soul (Lv.10+, patch 0007).
DELETE FROM `abilities` WHERE `abilityId` = 231 OR `name` = 'faerie_companion';
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (231, 'faerie_companion', 20, 255, 1, 300, 227, 0, 0, 171, 2000, 0, 6, 0, 0, 0, 1, 80, 0, 0, 'WOTG');

-- Server-side SCH Sage job ability: Call Titania (client display ID 801 = 289 + 512).
-- Level is set to 255 so it remains hidden unless unlocked via SCH Sage soul (Lv.10+, patch 0007).
DELETE FROM `abilities` WHERE `abilityId` = 289 OR `name` = 'faerie_titania';
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (289, 'faerie_titania', 20, 255, 1, 300, 200, 0, 0, 171, 2000, 0, 6, 0, 0, 0, 1, 80, 0, 0, 'WOTG');

-- Eos pet and model (Light Pixie 0x07EE). Pet ID 128 requires patch 0001.
DELETE FROM `pet_list` WHERE `petid` = 128;
INSERT INTO `pet_list`
    (`petid`, `name`, `poolid`, `minLevel`, `maxLevel`, `time`, `element`, `damageType`)
VALUES
    (128, 'Eos', 6020, 1, 99, 86400, 7, 3);

-- Titania pet and model (Dark Pixie 0x07F0). Pet ID 129 requires patch 0008.
DELETE FROM `pet_list` WHERE `petid` = 129;
INSERT INTO `pet_list`
    (`petid`, `name`, `poolid`, `minLevel`, `maxLevel`, `time`, `element`, `damageType`)
VALUES
    (129, 'Titania', 6021, 1, 99, 86400, 8, 3);

DELETE FROM `mob_pools` WHERE `poolid` = 6020;
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
VALUES
    (6020, 'faerie_companion', 'Faerie', 274, 0x0000EE0700000000000000000000000000000000, 20, 15, 7, 240, 100,
     0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 566, 0, 0, 195, 195, 0, 6);

DELETE FROM `mob_pools` WHERE `poolid` = 6021;
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
VALUES
    (6021, 'faerie_titania', 'Dark Faerie', 274, 0x0000F00700000000000000000000000000000000, 4, 5, 7, 240, 100,
     0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 600, 0, 0, 195, 195, 0, 6);

-- Eos starts with Regen at level 1, then upgrades Regen tiers as she levels.
DELETE FROM `mob_spell_lists` WHERE `spell_list_id` = 566;
INSERT INTO `mob_spell_lists` (`spell_list_name`, `spell_list_id`, `spell_id`, `min_level`, `max_level`) VALUES
    ('eos_companion', 566, 108, 1, 255), -- Regen
    ('eos_companion', 566, 110, 21, 255), -- Regen II
    ('eos_companion', 566, 111, 41, 255), -- Regen III
    ('eos_companion', 566, 477, 61, 255), -- Regen IV
    ('eos_companion', 566, 504, 81, 255), -- Regen V
    ('eos_companion', 566, 14,  1, 255), -- Poisona
    ('eos_companion', 566, 15,  1, 255), -- Paralyna
    ('eos_companion', 566, 16,  1, 255), -- Blindna
    ('eos_companion', 566, 17,  1, 255), -- Silena
    ('eos_companion', 566, 18,  1, 255), -- Stona
    ('eos_companion', 566, 19,  1, 255), -- Viruna
    ('eos_companion', 566, 20,  1, 255), -- Cursna
    ('eos_companion', 566, 143, 1, 255); -- Erase

-- Titania Dark Arts spell list (enfeebling, Drain/Aspir, and Tier I-V elemental nukes).
DELETE FROM `mob_spell_lists` WHERE `spell_list_id` = 600;
INSERT INTO `mob_spell_lists` (`spell_list_name`, `spell_list_id`, `spell_id`, `min_level`, `max_level`) VALUES
    ('titania_companion', 600, 230, 10, 255), -- Bio
    ('titania_companion', 600, 231, 35, 255), -- Bio II
    ('titania_companion', 600, 254, 4,  255), -- Blind
    ('titania_companion', 600, 220, 3,  255), -- Poison
    ('titania_companion', 600, 221, 46, 255), -- Poison II
    ('titania_companion', 600, 58,  4,  255), -- Paralyze (RDM sub)
    ('titania_companion', 600, 56,  13, 255), -- Slow (RDM sub)
    ('titania_companion', 600, 260, 32, 255), -- Dispel (RDM sub)
    ('titania_companion', 600, 286, 83, 255), -- Addle (RDM sub)
    ('titania_companion', 600, 245, 12, 255), -- Drain
    ('titania_companion', 600, 247, 25, 255), -- Aspir
    ('titania_companion', 600, 248, 78, 255), -- Aspir II
    ('titania_companion', 600, 159, 1,  255), -- Stone
    ('titania_companion', 600, 169, 5,  255), -- Water
    ('titania_companion', 600, 154, 9,  255), -- Aero
    ('titania_companion', 600, 144, 13, 255), -- Fire
    ('titania_companion', 600, 149, 17, 255), -- Blizzard
    ('titania_companion', 600, 164, 21, 255), -- Thunder
    ('titania_companion', 600, 160, 26, 255), -- Stone II
    ('titania_companion', 600, 170, 30, 255), -- Water II
    ('titania_companion', 600, 155, 34, 255), -- Aero II
    ('titania_companion', 600, 145, 38, 255), -- Fire II
    ('titania_companion', 600, 150, 42, 255), -- Blizzard II
    ('titania_companion', 600, 165, 46, 255), -- Thunder II
    ('titania_companion', 600, 161, 51, 255), -- Stone III
    ('titania_companion', 600, 171, 55, 255), -- Water III
    ('titania_companion', 600, 156, 59, 255), -- Aero III
    ('titania_companion', 600, 146, 63, 255), -- Fire III
    ('titania_companion', 600, 151, 67, 255), -- Blizzard III
    ('titania_companion', 600, 166, 71, 255), -- Thunder III
    ('titania_companion', 600, 162, 73, 255), -- Stone IV
    ('titania_companion', 600, 172, 74, 255), -- Water IV
    ('titania_companion', 600, 157, 75, 255), -- Aero IV
    ('titania_companion', 600, 147, 76, 255), -- Fire IV
    ('titania_companion', 600, 152, 77, 255), -- Blizzard IV
    ('titania_companion', 600, 167, 78, 255), -- Thunder IV
    ('titania_companion', 600, 163, 81, 255), -- Stone V
    ('titania_companion', 600, 173, 83, 255), -- Water V
    ('titania_companion', 600, 158, 85, 255), -- Aero V
    ('titania_companion', 600, 148, 87, 255), -- Fire V
    ('titania_companion', 600, 153, 89, 255), -- Blizzard V
    ('titania_companion', 600, 168, 91, 255); -- Thunder V

-- Orphic Egg: SCH-only ammo item that grants Eos & Titania level-scaling Refresh via numeric mod 1198.
UPDATE `item_equipment`
SET `level` = 1,
    `jobs` = 524288
WHERE `itemId` = 18256;

DELETE FROM `item_mods` WHERE `itemId` = 18256;
INSERT INTO `item_mods` (`itemId`, `modId`, `value`) VALUES (18256, 1198, 1);

DELETE FROM `item_latents` WHERE `itemId` = 18256;
