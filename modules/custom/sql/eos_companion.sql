-- Eos Companion module data.
-- Apply with dbtool or import manually into xidb after copying this file into modules/custom/sql.

SET @FLAG_DISPELABLE = 1;
SET @FLAG_DEATH = 32;
SET @FLAG_NO_CANCEL = 8388608;
SET @FLAG_HIDE_TIMER = 134217728;

-- Server-side SCH job ability. Client display ID is 743 (abilityId + 512).
DELETE FROM `abilities` WHERE `abilityId` = 231 OR `name` = 'faerie_companion';
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (231, 'faerie_companion', 20, 1, 1, 300, 227, 0, 0, 171, 2000, 0, 6, 0, 0, 0, 1, 80, 0, 0, 'WOTG');

-- Eos pet and model. Pet ID 128 requires the tiny engine cap patch in patches/.
DELETE FROM `pet_list` WHERE `petid` = 128;
INSERT INTO `pet_list`
    (`petid`, `name`, `poolid`, `minLevel`, `maxLevel`, `time`, `element`, `damageType`)
VALUES
    (128, 'Eos', 6020, 1, 99, 86400, 7, 3);

DELETE FROM `mob_pools` WHERE `poolid` = 6020;
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
VALUES
    (6020, 'faerie_companion', 'Faerie', 274, 0x0000EE0700000000000000000000000000000000, 20, 15, 7, 240, 100,
     0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 566, 0, 0, 195, 195, 0, 6);

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

-- 789 is an existing spare effect ID. It uses the Regen effect script but has its own status ID, so it stacks.
DELETE FROM `status_effects` WHERE `id` IN (789, 814);
INSERT INTO `status_effects`
    (`id`, `name`, `flags`, `type`, `negative_id`, `overwrite`, `block_id`, `remove_id`, `element`, `min_duration`, `sort_key`, `wear_off_message_id`)
VALUES
    (789, 'regen', @FLAG_DISPELABLE | @FLAG_DEATH, 0, 0, 0, 0, 0, 7, 0, 700, NULL),
    (814, 'eos_refresh', @FLAG_DEATH | @FLAG_NO_CANCEL | @FLAG_HIDE_TIMER, 0, 0, 0, 0, 0, 7, 0, 0, NULL);

-- Orphic Egg: SCH-only ammo item that grants Eos level-scaling Refresh via numeric mod 1198.
UPDATE `item_equipment`
SET `level` = 1,
    `jobs` = 524288
WHERE `itemId` = 18256;

DELETE FROM `item_mods` WHERE `itemId` = 18256;
INSERT INTO `item_mods` (`itemId`, `modId`, `value`) VALUES (18256, 1198, 1);

DELETE FROM `item_latents` WHERE `itemId` = 18256;
