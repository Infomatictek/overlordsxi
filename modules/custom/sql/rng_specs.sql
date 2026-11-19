-- OverlordsXI RNG Huntsman Spec Data
-- Custom Job Abilities (480-486, 489-490), Beast Companions (134-137), Mob Pools (6026-6029),
-- and 100% Single-Target Mob Skill Lists (6026-6027).
--
-- Note on recastIds:
--   Packet 0x119 (GP_SERV_COMMAND_ABIL_RECAST) transmits TimerId as uint8_t (1..254).
--   Huntsman uses recastIds 245-250 (vanilla GEO Lv.40-90 slots, unreachable as subjob at Lv.75 cap).
--
-- Note on client DATs:
--   New custom Job Abilities (489 predators_feint, 490 guardians_call) require client DAT string
--   entries in addition to this SQL import before the FFXI client displays their names natively.

-- ---------------------------------------------------------------------------
-- 1. Custom Job Abilities (Level 255 so they stay hidden unless unlocked by spec)
-- ---------------------------------------------------------------------------
DELETE FROM `abilities` WHERE `abilityId` IN (480, 481, 482, 483, 484, 485, 486, 489, 490)
    OR `name` IN (
        'call_wild_raaz', 'call_stalker_raptor', 'rimetusk_gore',
        'saurian_rend', 'primeval_takedown', 'call_cehuetzi', 'call_gabbrath',
        'predators_feint', 'guardians_call'
    );

INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    -- Call Wild Raaz (Lv.10+ Huntsman, 60s recast, shared summon recastId 245)
    (480, 'call_wild_raaz',      11, 255, 1, 60, 245, 0, 0, 171, 2000, 0, 6,  0.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Call Stalker Raptor (Lv.10+ Huntsman, 60s recast, shared summon recastId 245)
    (481, 'call_stalker_raptor', 11, 255, 1, 60, 245, 0, 0, 171, 2000, 0, 6,  0.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Rimetusk Gore (Lv.10+ Huntsman, 30s recast, Single-Target Enemy 20y, recastId 246; threat applied to pet in Lua)
    (482, 'rimetusk_gore',       11, 255, 4, 30, 246, 0, 0, 201, 1500, 0, 6, 20.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Saurian Rend (Lv.10+ Huntsman, 30s recast, Single-Target Enemy 20y, recastId 247; threat applied to pet in Lua)
    (483, 'saurian_rend',        11, 255, 4, 30, 247, 0, 0, 201, 1500, 0, 6, 20.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Primeval Takedown (Lv.10+ Huntsman, 45s recast, Single-Target Enemy 20y, recastId 248; threat applied to pet in Lua)
    (484, 'primeval_takedown',   11, 255, 4, 45, 248, 0, 0, 201, 1500, 0, 6, 20.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Call Cehuetzi (Lv.75+ Huntsman, 60s recast, shared summon recastId 245)
    (485, 'call_cehuetzi',       11, 255, 1, 60, 245, 0, 0, 171, 2000, 0, 6,  0.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Call Gabbrath (Lv.75+ Huntsman, 60s recast, shared summon recastId 245)
    (486, 'call_gabbrath',       11, 255, 1, 60, 245, 0, 0, 171, 2000, 0, 6,  0.0, 0, 0, 1,  1, 0, 0, NULL),
    -- Predator's Feint (Lv.10+ Huntsman, 45s recast, Self, recastId 249; 3s evasion + ST threat transfer to pet)
    (489, 'predators_feint',     11, 255, 1, 45, 249, 0, 0, 211, 1200, 0, 6,  0.0, 0, 0, 0,  0, 0, 0, NULL),
    -- Guardian's Call (Lv.10+ Huntsman, 60s recast, Self, recastId 250; arms 1-hit ST interception by pet)
    (490, 'guardians_call',      11, 255, 1, 60, 250, 0, 0, 207, 1500, 0, 6,  0.0, 0, 0, 1,  1, 0, 0, NULL);

-- ---------------------------------------------------------------------------
-- 2. Huntsman Beast Pets (Pet IDs 134-137 require patches/0035-rng-huntsman-pets.patch)
--    Compact field-sized Raaz (2600/2601) and Raptor (316/317) models.
-- ---------------------------------------------------------------------------
DELETE FROM `pet_list` WHERE `petid` IN (134, 135, 136, 137);
INSERT INTO `pet_list`
    (`petid`, `name`, `poolid`, `minLevel`, `maxLevel`, `time`, `element`, `damageType`)
VALUES
    (134, 'Wild Raaz',      6026, 1, 99, 86400, 2, 2),
    (135, 'Stalker Raptor', 6027, 1, 99, 86400, 1, 2),
    (136, 'Cehuetzi',       6028, 1, 99, 86400, 2, 2),
    (137, 'Gabbrath',       6029, 1, 99, 86400, 1, 2);

DELETE FROM `mob_pools` WHERE `poolid` IN (6026, 6027, 6028, 6029);
INSERT INTO `mob_pools`
    (`poolid`, `name`, `packet_name`, `speciesid`, `modelid`, `mJob`, `sJob`, `cmbSkill`, `cmbDelay`, `cmbDmgMult`,
     `behavior`, `aggro`, `true_detection`, `links`, `mobType`, `immunity`, `name_prefix`, `flag`, `entityFlags`,
     `animationsub`, `hasSpellScript`, `spellList`, `namevis`, `roamflag`, `skill_list_id`, `resist_id`,
     `modelSize`, `modelHitboxSize`)
VALUES
    (6026, 'wild_raaz',      'Wild Raaz',      102, 0x0000280A00000000000000000000000000000000, 1, 7, 1, 240, 100, 0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 0, 0, 0, 6026, 458, 0, 6),
    (6027, 'stalker_raptor', 'Stalker Raptor', 315, 0x00003C0100000000000000000000000000000000, 6, 1, 1, 210, 105, 0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 0, 0, 0, 6027, 210, 0, 6),
    (6028, 'cehuetzi_pet',   'Cehuetzi',       102, 0x0000290A00000000000000000000000000000000, 7, 1, 1, 240, 110, 0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 0, 0, 0, 6026, 458, 1, 6),
    (6029, 'gabbrath_pet',   'Gabbrath',       315, 0x00003D0100000000000000000000000000000000, 1, 6, 1, 210, 115, 0, 0, 0, 0, 0, 0, 32, 0, 3, 0, 0, 0, 0, 0, 6027, 210, 1, 6);

-- ---------------------------------------------------------------------------
-- 3. 100% Single-Target Mob Skill Lists (6026 Tusker / 6027 Saurian)
-- ---------------------------------------------------------------------------
DELETE FROM `mob_skill_lists` WHERE `skill_list_id` IN (6026, 6027);
INSERT INTO `mob_skill_lists` (`skill_list_name`, `skill_list_id`, `mob_skill_id`) VALUES
    ('huntsman_tusker_st',  6026, 266), -- Ram Charge (Single-Target)
    ('huntsman_tusker_st',  6026, 383), -- Tusk (Single-Target)
    ('huntsman_tusker_st',  6026, 494), -- Big Horn (Single-Target)
    ('huntsman_saurian_st', 6027, 374), -- Ripper Fang (Single-Target)
    ('huntsman_saurian_st', 6027, 379), -- Chomp Rush (Single-Target)
    ('huntsman_saurian_st', 6027, 380); -- Scythe Tail (Single-Target)
