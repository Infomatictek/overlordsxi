-----------------------------------
-- OverlordsXI Weaponskill Catalog
-- Original LandSandBoat WS definitions used to normalize base WSes
-- (fTP = 1.0, WSC = 0) and build tailored per-WS talent trees.
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.wsCatalog = xi.overlords.wsCatalog or {}

local catalog = xi.overlords.wsCatalog

catalog.skillOrder =
{
    { skill = xi.skill.HAND_TO_HAND, name = 'Hand-to-Hand' },
    { skill = xi.skill.DAGGER, name = 'Dagger' },
    { skill = xi.skill.SWORD, name = 'Sword' },
    { skill = xi.skill.GREAT_SWORD, name = 'Great Sword' },
    { skill = xi.skill.AXE, name = 'Axe' },
    { skill = xi.skill.GREAT_AXE, name = 'Great Axe' },
    { skill = xi.skill.SCYTHE, name = 'Scythe' },
    { skill = xi.skill.POLEARM, name = 'Polearm' },
    { skill = xi.skill.KATANA, name = 'Katana' },
    { skill = xi.skill.GREAT_KATANA, name = 'Great Katana' },
    { skill = xi.skill.CLUB, name = 'Club' },
    { skill = xi.skill.STAFF, name = 'Staff' },
    { skill = xi.skill.ARCHERY, name = 'Archery' },
    { skill = xi.skill.MARKSMANSHIP, name = 'Marksmanship' },
}

catalog.byId =
{
    [1] =
    {
        id = 1,
        key = 'combo',
        name = 'Combo',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.4, 3.4 },
            wsc = { str = 0.3, dex = 0.3 },
            numHits = 3,
            multiHitfTP = true,
            skillchain = { 'IMPACTION' },
        },
    },
    [2] =
    {
        id = 2,
        key = 'shoulder_tackle',
        name = 'Shoulder Tackle',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { vit = 1.0 },
            numHits = 2,
            multiHitfTP = true,
            skillchain = { 'REVERBERATION', 'IMPACTION' },
            debuff = { effect = 'STUN', label = 'Stun', binary = true },
        },
    },
    [3] =
    {
        id = 3,
        key = 'one_inch_punch',
        name = 'One Inch Punch',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { vit = 1.0 },
            numHits = 2,
            multiHitfTP = true,
            ignoredDefense = { 0.0, 0.375, 0.75 },
            skillchain = { 'COMPRESSION' },
        },
    },
    [4] =
    {
        id = 4,
        key = 'backhand_blow',
        name = 'Backhand Blow',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5, dex = 0.5 },
            numHits = 2,
            multiHitfTP = true,
            critVaries = { 0.3, 0.63, 0.96 },
            skillchain = { 'DETONATION' },
        },
    },
    [5] =
    {
        id = 5,
        key = 'raging_fists',
        name = 'Raging Fists',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.1875, 3.75 },
            wsc = { str = 0.3, dex = 0.3 },
            numHits = 5,
            multiHitfTP = true,
            skillchain = { 'IMPACTION' },
        },
    },
    [6] =
    {
        id = 6,
        key = 'spinning_attack',
        name = 'Spinning Attack',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 2,
            multiHitfTP = true,
            skillchain = { 'LIQUEFACTION', 'IMPACTION' },
            aoe = true,
        },
    },
    [7] =
    {
        id = 7,
        key = 'howling_fist',
        name = 'Howling Fist',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.05, 3.55, 5.75 },
            wsc = { str = 0.2, vit = 0.5 },
            numHits = 2,
            multiHitfTP = true,
            atkVaries = { 1.5, 1.5, 1.5 },
            skillchain = { 'TRANSFIXION', 'IMPACTION' },
        },
    },
    [8] =
    {
        id = 8,
        key = 'dragon_kick',
        name = 'Dragon Kick',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.7, 3.0, 5.0 },
            wsc = { str = 0.5, vit = 0.5 },
            numHits = 2,
            multiHitfTP = true,
            skillchain = { 'FRAGMENTATION' },
        },
    },
    [9] =
    {
        id = 9,
        key = 'asuran_fists',
        name = 'Asuran Fists',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.25, 1.25, 1.25 },
            wsc = { str = 0.15, vit = 0.15 },
            numHits = 8,
            multiHitfTP = true,
            accVaries = { 0.0, 33.0, 96.0 },
            skillchain = { 'GRAVITATION', 'LIQUEFACTION' },
        },
    },
    [10] =
    {
        id = 10,
        key = 'final_heaven',
        name = 'Final Heaven',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { vit = 0.8 },
            numHits = 2,
            skillchain = { 'LIGHT', 'FUSION' },
            aftermath = 'relic',
        },
    },
    [11] =
    {
        id = 11,
        key = 'ascetics_fury',
        name = 'Ascetics Fury',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5, vit = 0.5 },
            numHits = 2,
            multiHitfTP = true,
            critVaries = { 0.2, 0.4, 0.8 },
            atkVaries = { 2.5, 2.5, 2.5 },
            skillchain = { 'FUSION', 'TRANSFIXION' },
            aftermath = 'mythic',
        },
    },
    [12] =
    {
        id = 12,
        key = 'stringing_pummel',
        name = 'Stringing Pummel',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.32, vit = 0.32 },
            numHits = 6,
            critVaries = { 0.1, 0.22, 0.36 },
            skillchain = { 'GRAVITATION', 'LIQUEFACTION' },
            aftermath = 'mythic',
        },
    },
    [13] =
    {
        id = 13,
        key = 'tornado_kick',
        name = 'Tornado Kick',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.7, 2.8, 4.5 },
            wsc = { str = 0.4, vit = 0.4 },
            numHits = 3,
            multiHitfTP = true,
            skillchain = { 'INDURATION', 'IMPACTION', 'DETONATION' },
        },
    },
    [14] =
    {
        id = 14,
        key = 'victory_smite',
        name = 'Victory Smite',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 1.5, 1.5 },
            wsc = { str = 0.8 },
            numHits = 4,
            multiHitfTP = true,
            critVaries = { 0.1, 0.25, 0.45 },
            skillchain = { 'LIGHT', 'FRAGMENTATION' },
            aftermath = 'empyrean',
        },
    },
    [15] =
    {
        id = 15,
        key = 'shijin_spiral',
        name = 'Shijin Spiral',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 1.5, 1.5 },
            wsc = { dex = 0.7 },
            numHits = 5,
            multiHitfTP = true,
            atkVaries = { 1.05, 1.05, 1.05 },
            skillchain = { 'FUSION', 'REVERBERATION' },
            debuff = { effect = 'PLAGUE', label = 'Plague', binary = false },
        },
    },
    [16] =
    {
        id = 16,
        key = 'wasp_sting',
        name = 'Wasp Sting',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { dex = 1.0 },
            numHits = 1,
            skillchain = { 'SCISSION' },
            debuff = { effect = 'POISON', label = 'Poison', binary = false },
        },
    },
    [17] =
    {
        id = 17,
        key = 'viper_bite',
        name = 'Viper Bite',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { dex = 1.0 },
            numHits = 1,
            atkVaries = { 2.0, 2.0, 2.0 },
            skillchain = { 'SCISSION' },
            debuff = { effect = 'POISON', label = 'Poison', binary = false },
        },
    },
    [18] =
    {
        id = 18,
        key = 'shadowstitch',
        name = 'Shadowstitch',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { chr = 1.0 },
            numHits = 1,
            skillchain = { 'REVERBERATION' },
            debuff = { effect = 'BIND', label = 'Bind', binary = true },
        },
    },
    [19] =
    {
        id = 19,
        key = 'gust_slash',
        name = 'Gust Slash',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'magic',
        element = xi.element.WIND,
        elementName = 'Wind',
        orig =
        {
            ftp = { 1.0, 2.0, 3.0 },
            wsc = { dex = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'DETONATION' },
        },
    },
    [20] =
    {
        id = 20,
        key = 'cyclone',
        name = 'Cyclone',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'magic',
        element = xi.element.WIND,
        elementName = 'Wind',
        orig =
        {
            ftp = { 1.0, 2.375, 3.75 },
            wsc = { dex = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'DETONATION', 'IMPACTION' },
            aoe = true,
        },
    },
    [21] =
    {
        id = 21,
        key = 'energy_steal',
        name = 'Energy Steal',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'utility',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { mnd = 1.0 },
            numHits = 1,
            skillchain = {},
            drainMp = true,
        },
    },
    [22] =
    {
        id = 22,
        key = 'energy_drain',
        name = 'Energy Drain',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'utility',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { mnd = 1.0 },
            numHits = 1,
            skillchain = {},
            drainMp = true,
        },
    },
    [23] =
    {
        id = 23,
        key = 'dancing_edge',
        name = 'Dancing Edge',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.1875, 1.1875, 1.1875 },
            wsc = { dex = 0.4, chr = 0.4 },
            numHits = 5,
            multiHitfTP = true,
            accVaries = { 0.0, 40.0, 100.0 },
            skillchain = { 'SCISSION', 'DETONATION' },
        },
    },
    [24] =
    {
        id = 24,
        key = 'shark_bite',
        name = 'Shark Bite',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.5, 6.8, 8.5 },
            wsc = { dex = 0.4, agi = 0.4 },
            numHits = 2,
            skillchain = { 'FRAGMENTATION' },
        },
    },
    [25] =
    {
        id = 25,
        key = 'evisceration',
        name = 'Evisceration',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.25, 1.25, 1.25 },
            wsc = { dex = 0.5 },
            numHits = 5,
            multiHitfTP = true,
            critVaries = { 0.1, 0.24, 0.48 },
            skillchain = { 'GRAVITATION', 'TRANSFIXION' },
        },
    },
    [26] =
    {
        id = 26,
        key = 'mercy_stroke',
        name = 'Mercy Stroke',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { str = 0.8 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'GRAVITATION' },
            aftermath = 'relic',
        },
    },
    [27] =
    {
        id = 27,
        key = 'mandalic_stab',
        name = 'Mandalic Stab',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.0, 6.09, 8.5 },
            wsc = { dex = 0.6 },
            numHits = 1,
            atkVaries = { 1.75, 1.75, 1.75 },
            skillchain = { 'FUSION', 'COMPRESSION' },
            aftermath = 'mythic',
        },
    },
    [28] =
    {
        id = 28,
        key = 'mordant_rime',
        name = 'Mordant Rime',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { dex = 0.3, chr = 0.7 },
            numHits = 2,
            skillchain = { 'FRAGMENTATION', 'DISTORTION' },
            debuff = { effect = 'WEIGHT', label = 'Gravity', binary = false },
            aftermath = 'mythic',
        },
    },
    [29] =
    {
        id = 29,
        key = 'pyrrhic_kleos',
        name = 'Pyrrhic Kleos',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.75, 1.75, 1.75 },
            wsc = { str = 0.4, dex = 0.4 },
            numHits = 4,
            multiHitfTP = true,
            skillchain = { 'DISTORTION', 'SCISSION' },
            debuff = { effect = 'EVASION_DOWN', label = 'Evasion Down', binary = false },
            aftermath = 'mythic',
        },
    },
    [30] =
    {
        id = 30,
        key = 'aeolian_edge',
        name = 'Aeolian Edge',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'magic',
        element = xi.element.WIND,
        elementName = 'Wind',
        orig =
        {
            ftp = { 2.0, 3.0, 4.5 },
            wsc = { dex = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'SCISSION', 'DETONATION', 'IMPACTION' },
            aoe = true,
        },
    },
    [31] =
    {
        id = 31,
        key = 'rudras_storm',
        name = 'Rudra\'s Storm',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.0, 10.19, 13.0 },
            wsc = { dex = 0.8 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'DISTORTION' },
            debuff = { effect = 'WEIGHT', label = 'Gravity', binary = false },
            aftermath = 'empyrean',
        },
    },
    [32] =
    {
        id = 32,
        key = 'fast_blade',
        name = 'Fast Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.0, 5.0 },
            wsc = { str = 0.4, dex = 0.4 },
            numHits = 2,
            skillchain = { 'SCISSION' },
        },
    },
    [33] =
    {
        id = 33,
        key = 'burning_blade',
        name = 'Burning Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'magic',
        element = xi.element.FIRE,
        elementName = 'Fire',
        orig =
        {
            ftp = { 1.0, 2.1, 3.4 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION' },
        },
    },
    [34] =
    {
        id = 34,
        key = 'red_lotus_blade',
        name = 'Red Lotus Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'magic',
        element = xi.element.FIRE,
        elementName = 'Fire',
        orig =
        {
            ftp = { 1.0, 2.38, 3.75 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION', 'DETONATION' },
        },
    },
    [35] =
    {
        id = 35,
        key = 'flat_blade',
        name = 'Flat Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
            debuff = { effect = 'STUN', label = 'Stun', binary = true },
        },
    },
    [36] =
    {
        id = 36,
        key = 'shining_blade',
        name = 'Shining Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 1.125, 2.222, 3.523 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'SCISSION' },
        },
    },
    [37] =
    {
        id = 37,
        key = 'seraph_blade',
        name = 'Seraph Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 1.125, 2.625, 4.125 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'SCISSION' },
        },
    },
    [38] =
    {
        id = 38,
        key = 'circle_blade',
        name = 'Circle Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'REVERBERATION', 'IMPACTION' },
            aoe = true,
        },
    },
    [39] =
    {
        id = 39,
        key = 'spirits_within',
        name = 'Spirits Within',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'utility',
        orig =
        {
            ftp = { 0.125, 0.5, 1.0 },
            wsc = {},
            numHits = 1,
            skillchain = {},
        },
    },
    [40] =
    {
        id = 40,
        key = 'vorpal_blade',
        name = 'Vorpal Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.375, 1.375, 1.375 },
            wsc = { str = 0.6 },
            numHits = 4,
            multiHitfTP = true,
            critVaries = { 0.15, 0.3, 0.5 },
            skillchain = { 'SCISSION', 'IMPACTION' },
        },
    },
    [41] =
    {
        id = 41,
        key = 'swift_blade',
        name = 'Swift Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 1.5, 1.5 },
            wsc = { str = 0.5, mnd = 0.5 },
            numHits = 3,
            multiHitfTP = true,
            accVaries = { 0.0, 40.0, 120.0 },
            skillchain = { 'GRAVITATION' },
        },
    },
    [42] =
    {
        id = 42,
        key = 'savage_blade',
        name = 'Savage Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.0, 10.3, 13.6 },
            wsc = { str = 0.5, mnd = 0.5 },
            numHits = 2,
            skillchain = { 'FRAGMENTATION', 'SCISSION' },
        },
    },
    [43] =
    {
        id = 43,
        key = 'knights_of_round',
        name = 'Knights Of Round',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'LIGHT', 'FUSION' },
            aftermath = 'relic',
        },
    },
    [44] =
    {
        id = 44,
        key = 'death_blossom',
        name = 'Death Blossom',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.0, 4.0, 4.0 },
            wsc = { str = 0.3, mnd = 0.5 },
            numHits = 3,
            skillchain = { 'FRAGMENTATION', 'DISTORTION' },
            debuff = { effect = 'MAGIC_EVASION_DOWN', label = 'M.Eva Down', binary = false },
            aftermath = 'mythic',
        },
    },
    [45] =
    {
        id = 45,
        key = 'atonement',
        name = 'Atonement',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.5, 2.0 },
            wsc = { str = 0.4, vit = 0.5 },
            numHits = 2,
            skillchain = { 'FUSION', 'REVERBERATION' },
            enmity = 'high',
            aftermath = 'mythic',
        },
    },
    [46] =
    {
        id = 46,
        key = 'expiacion',
        name = 'Expiacion',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.7969, 9.3906, 12.1875 },
            wsc = { str = 0.3, dex = 0.2, int = 0.3 },
            numHits = 2,
            skillchain = { 'DISTORTION', 'SCISSION' },
            aftermath = 'mythic',
        },
    },
    [47] =
    {
        id = 47,
        key = 'sanguine_blade',
        name = 'Sanguine Blade',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'magic',
        orig =
        {
            ftp = { 2.75, 2.75, 2.75 },
            wsc = { str = 0.3, mnd = 0.5 },
            numHits = 1,
            skillchain = {},
            drainHp = true,
        },
    },
    [48] =
    {
        id = 48,
        key = 'hard_slash',
        name = 'Hard Slash',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 2.5, 3.5 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'SCISSION' },
        },
    },
    [49] =
    {
        id = 49,
        key = 'power_slash',
        name = 'Power Slash',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, vit = 0.6 },
            numHits = 1,
            critVaries = { 0.5, 0.75, 1.0 },
            skillchain = { 'TRANSFIXION' },
        },
    },
    [50] =
    {
        id = 50,
        key = 'frostbite',
        name = 'Frostbite',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'magic',
        element = xi.element.ICE,
        elementName = 'Ice',
        orig =
        {
            ftp = { 1.5, 3.25, 5.0 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'INDURATION' },
        },
    },
    [51] =
    {
        id = 51,
        key = 'freezebite',
        name = 'Freezebite',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'magic',
        element = xi.element.ICE,
        elementName = 'Ice',
        orig =
        {
            ftp = { 1.5, 3.5, 6.0 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'INDURATION', 'DETONATION' },
        },
    },
    [52] =
    {
        id = 52,
        key = 'shockwave',
        name = 'Shockwave',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.3, mnd = 0.3 },
            numHits = 1,
            skillchain = { 'REVERBERATION' },
            aoe = true,
            debuff = { effect = 'SLEEP_I', label = 'Sleep', binary = true },
        },
    },
    [53] =
    {
        id = 53,
        key = 'crescent_moon',
        name = 'Crescent Moon',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.25, 4.0 },
            wsc = { str = 0.8 },
            numHits = 1,
            skillchain = { 'SCISSION' },
        },
    },
    [54] =
    {
        id = 54,
        key = 'sickle_moon',
        name = 'Sickle Moon',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 3.5, 6.5 },
            wsc = { str = 0.4, agi = 0.4 },
            numHits = 2,
            skillchain = { 'SCISSION', 'IMPACTION' },
        },
    },
    [55] =
    {
        id = 55,
        key = 'spinning_slash',
        name = 'Spinning Slash',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.5, 5.0, 7.5 },
            wsc = { str = 0.3, int = 0.3 },
            numHits = 1,
            atkVaries = { 1.5, 1.5, 1.5 },
            skillchain = { 'FRAGMENTATION' },
        },
    },
    [56] =
    {
        id = 56,
        key = 'ground_strike',
        name = 'Ground Strike',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 3.0, 5.0 },
            wsc = { str = 0.5, int = 0.5 },
            numHits = 1,
            atkVaries = { 1.75, 1.75, 1.75 },
            skillchain = { 'FRAGMENTATION', 'DISTORTION' },
        },
    },
    [57] =
    {
        id = 57,
        key = 'scourge',
        name = 'Scourge',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { str = 0.4, vit = 0.4 },
            numHits = 1,
            skillchain = { 'LIGHT', 'FUSION' },
            aftermath = 'relic',
        },
    },
    [58] =
    {
        id = 58,
        key = 'herculean_slash',
        name = 'Herculean Slash',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'magic',
        orig =
        {
            ftp = { 3.5, 3.5, 3.5 },
            wsc = { vit = 0.8 },
            numHits = 1,
            skillchain = { 'INDURATION', 'DETONATION', 'IMPACTION' },
            debuff = { effect = 'PARALYSIS', label = 'Paralysis', binary = false },
        },
    },
    [59] =
    {
        id = 59,
        key = 'torcleaver',
        name = 'Torcleaver',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.75, 7.5, 9.75 },
            wsc = { vit = 0.8 },
            numHits = 1,
            skillchain = { 'LIGHT', 'DISTORTION' },
            aftermath = 'empyrean',
        },
    },
    [60] =
    {
        id = 60,
        key = 'resolution',
        name = 'Resolution',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 0.7188, 1.5, 2.25 },
            wsc = { str = 0.7 },
            numHits = 5,
            multiHitfTP = true,
            atkVaries = { 0.85, 0.85, 0.85 },
            skillchain = { 'FRAGMENTATION', 'SCISSION' },
        },
    },
    [61] =
    {
        id = 61,
        key = 'dimidiation',
        name = 'Dimidiation',
        skill = xi.skill.GREAT_SWORD,
        skillName = 'Great Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.25, 4.5, 6.75 },
            wsc = { dex = 0.8 },
            numHits = 2,
            atkVaries = { 1.25, 1.25, 1.25 },
            skillchain = { 'LIGHT', 'FRAGMENTATION' },
            aftermath = 'mythic',
        },
    },
    [64] =
    {
        id = 64,
        key = 'raging_axe',
        name = 'Raging Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.0, 6.0 },
            wsc = { str = 0.6 },
            numHits = 2,
            skillchain = { 'DETONATION', 'IMPACTION' },
        },
    },
    [65] =
    {
        id = 65,
        key = 'smash_axe',
        name = 'Smash Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'INDURATION', 'REVERBERATION' },
            debuff = { effect = 'STUN', label = 'Stun', binary = true },
        },
    },
    [66] =
    {
        id = 66,
        key = 'gale_axe',
        name = 'Gale Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'DETONATION' },
            debuff = { effect = 'CHOKE', label = 'Choke', binary = false },
        },
    },
    [67] =
    {
        id = 67,
        key = 'avalanche_axe',
        name = 'Avalanche Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 3.0, 5.5 },
            wsc = { str = 0.6 },
            numHits = 1,
            skillchain = { 'SCISSION', 'IMPACTION' },
        },
    },
    [68] =
    {
        id = 68,
        key = 'spinning_axe',
        name = 'Spinning Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.0, 4.0, 6.5 },
            wsc = { str = 0.6 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION', 'SCISSION', 'IMPACTION' },
        },
    },
    [69] =
    {
        id = 69,
        key = 'rampage',
        name = 'Rampage',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5 },
            numHits = 5,
            multiHitfTP = true,
            critVaries = { 0.1, 0.2, 0.4 },
            skillchain = { 'SCISSION' },
        },
    },
    [70] =
    {
        id = 70,
        key = 'calamity',
        name = 'Calamity',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.5625, 6.4688, 10.375 },
            wsc = { str = 0.5, vit = 0.5 },
            numHits = 1,
            skillchain = { 'SCISSION', 'IMPACTION' },
        },
    },
    [71] =
    {
        id = 71,
        key = 'mistral_axe',
        name = 'Mistral Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.0, 10.3, 13.6 },
            wsc = { str = 0.5 },
            numHits = 1,
            skillchain = { 'FUSION' },
        },
    },
    [72] =
    {
        id = 72,
        key = 'decimation',
        name = 'Decimation',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.75, 1.75, 1.75 },
            wsc = { str = 0.5 },
            numHits = 3,
            multiHitfTP = true,
            accVaries = { 35.0, 70.0, 120.0 },
            skillchain = { 'FUSION', 'REVERBERATION' },
        },
    },
    [73] =
    {
        id = 73,
        key = 'onslaught',
        name = 'Onslaught',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.75, 2.75, 2.75 },
            wsc = { dex = 0.8 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'GRAVITATION' },
            debuff = { effect = 'ACCURACY_DOWN', label = 'Accuracy Down', binary = false },
            aftermath = 'relic',
        },
    },
    [74] =
    {
        id = 74,
        key = 'primal_rend',
        name = 'Primal Rend',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 3.0625, 4.6875, 7.5625 },
            wsc = { dex = 0.3, chr = 0.6 },
            numHits = 1,
            skillchain = { 'GRAVITATION', 'REVERBERATION' },
            aftermath = 'mythic',
        },
    },
    [75] =
    {
        id = 75,
        key = 'bora_axe',
        name = 'Bora Axe',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.5, 4.5, 4.5 },
            wsc = { dex = 1.0 },
            numHits = 1,
            atkVaries = { 1.0, 1.0, 1.0 },
            skillchain = { 'SCISSION', 'DETONATION' },
            debuff = { effect = 'BIND', label = 'Bind', binary = true },
        },
    },
    [76] =
    {
        id = 76,
        key = 'cloudsplitter',
        name = 'Cloudsplitter',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'magic',
        element = xi.element.THUNDER,
        elementName = 'Thunder',
        orig =
        {
            ftp = { 3.75, 5.5, 8.5 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'FRAGMENTATION' },
            aftermath = 'empyrean',
        },
    },
    [77] =
    {
        id = 77,
        key = 'ruinator',
        name = 'Ruinator',
        skill = xi.skill.AXE,
        skillName = 'Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.08, 1.08, 1.08 },
            wsc = { str = 0.7 },
            numHits = 4,
            multiHitfTP = true,
            accVaries = { 20.0, 40.0, 70.0 },
            atkVaries = { 1.1, 1.1, 1.1 },
            skillchain = { 'DISTORTION', 'DETONATION' },
        },
    },
    [80] =
    {
        id = 80,
        key = 'shield_break',
        name = 'Shield Break',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, vit = 0.6 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
            debuff = { effect = 'EVASION_DOWN', label = 'Evasion Down', binary = false },
        },
    },
    [81] =
    {
        id = 81,
        key = 'iron_tempest',
        name = 'Iron Tempest',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6 },
            numHits = 1,
            atkVaries = { 1.0, 2.0, 3.5 },
            skillchain = { 'SCISSION' },
        },
    },
    [82] =
    {
        id = 82,
        key = 'sturmwind',
        name = 'Sturmwind',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6 },
            numHits = 2,
            atkVaries = { 1.0, 2.0, 3.5 },
            skillchain = { 'REVERBERATION', 'SCISSION' },
        },
    },
    [83] =
    {
        id = 83,
        key = 'armor_break',
        name = 'Armor Break',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, vit = 0.6 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
            debuff = { effect = 'DEFENSE_DOWN', label = 'Defense Down', binary = false },
        },
    },
    [84] =
    {
        id = 84,
        key = 'keen_edge',
        name = 'Keen Edge',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            critVaries = { 0.5, 0.75, 1.0 },
            skillchain = { 'COMPRESSION' },
        },
    },
    [85] =
    {
        id = 85,
        key = 'weapon_break',
        name = 'Weapon Break',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, vit = 0.6 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
            debuff = { effect = 'ATTACK_DOWN', label = 'Attack Down', binary = false },
        },
    },
    [86] =
    {
        id = 86,
        key = 'raging_rush',
        name = 'Raging Rush',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5 },
            numHits = 3,
            critVaries = { 0.15, 0.3, 0.5 },
            skillchain = { 'INDURATION', 'REVERBERATION' },
        },
    },
    [87] =
    {
        id = 87,
        key = 'full_break',
        name = 'Full Break',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5, vit = 0.5 },
            numHits = 1,
            skillchain = { 'DISTORTION' },
            debuff = { effect = 'FULL_BREAK', label = 'All Stats Break', binary = false },
        },
    },
    [88] =
    {
        id = 88,
        key = 'steel_cyclone',
        name = 'Steel Cyclone',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5, 2.5, 4.0 },
            wsc = { str = 0.6, vit = 0.6 },
            numHits = 1,
            atkVaries = { 1.5, 1.5, 1.5 },
            skillchain = { 'DISTORTION', 'DETONATION' },
        },
    },
    [89] =
    {
        id = 89,
        key = 'metatron_torment',
        name = 'Metatron Torment',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.75, 2.75, 2.75 },
            wsc = { str = 0.8 },
            numHits = 1,
            skillchain = { 'LIGHT', 'FUSION' },
            debuff = { effect = 'DEFENSE_DOWN', label = 'Defense Down', binary = false },
            aftermath = 'relic',
        },
    },
    [90] =
    {
        id = 90,
        key = 'kings_justice',
        name = 'Kings Justice',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.0, 5.0 },
            wsc = { str = 0.5 },
            numHits = 3,
            skillchain = { 'FRAGMENTATION', 'SCISSION' },
            aftermath = 'mythic',
        },
    },
    [91] =
    {
        id = 91,
        key = 'fell_cleave',
        name = 'Fell Cleave',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.75, 2.75, 2.75 },
            wsc = { str = 0.6 },
            numHits = 1,
            skillchain = { 'SCISSION', 'DETONATION', 'IMPACTION' },
            aoe = true,
        },
    },
    [92] =
    {
        id = 92,
        key = 'ukkos_fury',
        name = 'Ukko\'s Fury',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.0, 2.0, 2.0 },
            wsc = { str = 0.8 },
            numHits = 2,
            critVaries = { 0.2, 0.4, 0.7 },
            skillchain = { 'LIGHT', 'FRAGMENTATION' },
            debuff = { effect = 'SLOW', label = 'Slow', binary = false },
            aftermath = 'empyrean',
        },
    },
    [93] =
    {
        id = 93,
        key = 'upheaval',
        name = 'Upheaval',
        skill = xi.skill.GREAT_AXE,
        skillName = 'Great Axe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.5, 6.5 },
            wsc = { vit = 0.7 },
            numHits = 4,
            skillchain = { 'FUSION', 'COMPRESSION' },
        },
    },
    [96] =
    {
        id = 96,
        key = 'slice',
        name = 'Slice',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.5, 4.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'SCISSION' },
        },
    },
    [97] =
    {
        id = 97,
        key = 'dark_harvest',
        name = 'Dark Harvest',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 1.0, 3.54, 6.07 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'REVERBERATION' },
        },
    },
    [98] =
    {
        id = 98,
        key = 'shadow_of_death',
        name = 'Shadow of Death',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 1.0, 4.17, 8.6 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'INDURATION', 'REVERBERATION' },
        },
    },
    [99] =
    {
        id = 99,
        key = 'nightmare_scythe',
        name = 'Nightmare Scythe',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, mnd = 0.6 },
            numHits = 1,
            skillchain = { 'COMPRESSION', 'SCISSION' },
            debuff = { effect = 'BLINDNESS', label = 'Blind', binary = false },
        },
    },
    [100] =
    {
        id = 100,
        key = 'spinning_scythe',
        name = 'Spinning Scythe',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'REVERBERATION', 'SCISSION' },
            aoe = true,
        },
    },
    [101] =
    {
        id = 101,
        key = 'vorpal_scythe',
        name = 'Vorpal Scythe',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            critVaries = { 0.3, 0.63, 0.96 },
            skillchain = { 'TRANSFIXION', 'SCISSION' },
        },
    },
    [102] =
    {
        id = 102,
        key = 'guillotine',
        name = 'Guillotine',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 0.875, 0.875, 0.875 },
            wsc = { str = 0.3, mnd = 0.5 },
            numHits = 4,
            skillchain = { 'INDURATION' },
            debuff = { effect = 'SILENCE', label = 'Silence', binary = true },
        },
    },
    [103] =
    {
        id = 103,
        key = 'cross_reaper',
        name = 'Cross Reaper',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.0, 4.0, 7.0 },
            wsc = { str = 0.6, mnd = 0.6 },
            numHits = 2,
            skillchain = { 'DISTORTION' },
        },
    },
    [104] =
    {
        id = 104,
        key = 'spiral_hell',
        name = 'Spiral Hell',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.375, 2.75, 4.75 },
            wsc = { str = 0.5, int = 0.5 },
            numHits = 1,
            skillchain = { 'DISTORTION', 'SCISSION' },
        },
    },
    [105] =
    {
        id = 105,
        key = 'catastrophe',
        name = 'Catastrophe',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.75, 2.75, 2.75 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'GRAVITATION' },
            drainHp = true,
            aftermath = 'relic',
        },
    },
    [106] =
    {
        id = 106,
        key = 'insurgency',
        name = 'Insurgency',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 0.5, 3.25, 6.0 },
            wsc = { str = 0.2, int = 0.2 },
            numHits = 4,
            skillchain = { 'FUSION', 'COMPRESSION' },
            aftermath = 'mythic',
        },
    },
    [107] =
    {
        id = 107,
        key = 'infernal_scythe',
        name = 'Infernal Scythe',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 3.5, 3.5, 3.5 },
            wsc = { str = 0.3, int = 0.7 },
            numHits = 1,
            skillchain = { 'COMPRESSION', 'REVERBERATION' },
            debuff = { effect = 'ATTACK_DOWN', label = 'Attack Down', binary = false },
        },
    },
    [108] =
    {
        id = 108,
        key = 'quietus',
        name = 'Quietus',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { str = 0.6, mnd = 0.6 },
            numHits = 1,
            ignoredDefense = { 0.125, 0.375, 0.625 },
            skillchain = { 'DARKNESS', 'DISTORTION' },
            aftermath = 'empyrean',
        },
    },
    [109] =
    {
        id = 109,
        key = 'entropy',
        name = 'Entropy',
        skill = xi.skill.SCYTHE,
        skillName = 'Scythe',
        wsType = 'physical',
        orig =
        {
            ftp = { 0.75, 1.25, 2.0 },
            wsc = { int = 0.7 },
            numHits = 4,
            multiHitfTP = true,
            skillchain = { 'GRAVITATION', 'REVERBERATION' },
            drainMp = true,
        },
    },
    [112] =
    {
        id = 112,
        key = 'double_thrust',
        name = 'Double Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.5, 4.0 },
            wsc = { str = 0.3, dex = 0.3 },
            numHits = 2,
            skillchain = { 'TRANSFIXION' },
        },
    },
    [113] =
    {
        id = 113,
        key = 'thunder_thrust',
        name = 'Thunder Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'magic',
        element = xi.element.THUNDER,
        elementName = 'Thunder',
        orig =
        {
            ftp = { 1.5, 3.2773, 5.4297 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'TRANSFIXION', 'IMPACTION' },
        },
    },
    [114] =
    {
        id = 114,
        key = 'raiden_thrust',
        name = 'Raiden Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'magic',
        element = xi.element.THUNDER,
        elementName = 'Thunder',
        orig =
        {
            ftp = { 1.0, 3.9102, 7.9609 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'TRANSFIXION', 'IMPACTION' },
        },
    },
    [115] =
    {
        id = 115,
        key = 'leg_sweep',
        name = 'Leg Sweep',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
            debuff = { effect = 'STUN', label = 'Stun', binary = true },
        },
    },
    [116] =
    {
        id = 116,
        key = 'penta_thrust',
        name = 'Penta Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.2, dex = 0.2 },
            numHits = 5,
            accVaries = { 20.0, 40.0, 70.0 },
            atkVaries = { 0.875, 0.875, 0.875 },
            skillchain = { 'COMPRESSION' },
        },
    },
    [117] =
    {
        id = 117,
        key = 'vorpal_thrust',
        name = 'Vorpal Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5, agi = 0.5 },
            numHits = 1,
            critVaries = { 0.3, 0.63, 0.96 },
            skillchain = { 'REVERBERATION', 'TRANSFIXION' },
        },
    },
    [118] =
    {
        id = 118,
        key = 'skewer',
        name = 'Skewer',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5 },
            numHits = 3,
            critVaries = { 0.15, 0.3, 0.5 },
            skillchain = { 'TRANSFIXION', 'IMPACTION' },
        },
    },
    [119] =
    {
        id = 119,
        key = 'wheeling_thrust',
        name = 'Wheeling Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.75, 1.75, 1.75 },
            wsc = { str = 0.8 },
            numHits = 1,
            ignoredDefense = { 0.5, 0.625, 0.75 },
            skillchain = { 'FUSION' },
        },
    },
    [120] =
    {
        id = 120,
        key = 'impulse_drive',
        name = 'Impulse Drive',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.0977, 5.5 },
            wsc = { str = 1.0 },
            numHits = 2,
            skillchain = { 'GRAVITATION', 'INDURATION' },
        },
    },
    [121] =
    {
        id = 121,
        key = 'geirskogul',
        name = 'Geirskogul',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { dex = 0.8 },
            numHits = 1,
            skillchain = { 'LIGHT', 'DISTORTION' },
            aftermath = 'relic',
        },
    },
    [122] =
    {
        id = 122,
        key = 'drakesbane',
        name = 'Drakesbane',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5 },
            numHits = 4,
            critVaries = { 0.1, 0.2, 0.3 },
            atkVaries = { 0.8125, 0.8125, 0.8125 },
            skillchain = { 'FUSION', 'TRANSFIXION' },
            aftermath = 'mythic',
        },
    },
    [123] =
    {
        id = 123,
        key = 'sonic_thrust',
        name = 'Sonic Thrust',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.75, 4.5 },
            wsc = { str = 0.4, dex = 0.4 },
            numHits = 1,
            skillchain = { 'TRANSFIXION', 'SCISSION' },
            aoe = true,
        },
    },
    [124] =
    {
        id = 124,
        key = 'camlanns_torment',
        name = 'Camlann\'s Torment',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { str = 0.6, vit = 0.6 },
            numHits = 1,
            ignoredDefense = { 0.125, 0.375, 0.625 },
            skillchain = { 'LIGHT', 'FRAGMENTATION' },
            aftermath = 'empyrean',
        },
    },
    [125] =
    {
        id = 125,
        key = 'stardiver',
        name = 'Stardiver',
        skill = xi.skill.POLEARM,
        skillName = 'Polearm',
        wsType = 'physical',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 0.75, 1.25, 1.75 },
            wsc = { str = 0.7 },
            numHits = 4,
            multiHitfTP = true,
            skillchain = { 'GRAVITATION', 'TRANSFIXION' },
            debuff = { effect = 'CRIT_HIT_EVASION_DOWN', label = 'Crit Eva Down', binary = false },
        },
    },
    [128] =
    {
        id = 128,
        key = 'blade_rin',
        name = 'Blade: Rin',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, dex = 0.6 },
            numHits = 1,
            critVaries = { 0.3, 0.63, 0.96 },
            skillchain = { 'TRANSFIXION' },
        },
    },
    [129] =
    {
        id = 129,
        key = 'blade_retsu',
        name = 'Blade: Retsu',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.2, dex = 0.6 },
            numHits = 2,
            skillchain = { 'SCISSION' },
            debuff = { effect = 'PARALYSIS', label = 'Paralysis', binary = false },
        },
    },
    [130] =
    {
        id = 130,
        key = 'blade_teki',
        name = 'Blade: Teki',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'hybrid',
        element = xi.element.WATER,
        elementName = 'Water',
        orig =
        {
            ftp = { 0.5, 1.5, 2.25 },
            wsc = { str = 0.3, int = 0.3 },
            numHits = 1,
            skillchain = { 'REVERBERATION' },
        },
    },
    [131] =
    {
        id = 131,
        key = 'blade_to',
        name = 'Blade: To',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'hybrid',
        element = xi.element.ICE,
        elementName = 'Ice',
        orig =
        {
            ftp = { 0.5, 1.5, 2.5 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'INDURATION', 'DETONATION' },
        },
    },
    [132] =
    {
        id = 132,
        key = 'blade_chi',
        name = 'Blade: Chi',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'hybrid',
        element = xi.element.EARTH,
        elementName = 'Earth',
        orig =
        {
            ftp = { 0.5, 1.5, 2.25 },
            wsc = { str = 0.3, int = 0.3 },
            numHits = 2,
            skillchain = { 'TRANSFIXION', 'IMPACTION' },
        },
    },
    [133] =
    {
        id = 133,
        key = 'blade_ei',
        name = 'Blade: Ei',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 1.0, 3.0, 5.0 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'COMPRESSION' },
        },
    },
    [134] =
    {
        id = 134,
        key = 'blade_jin',
        name = 'Blade: Jin',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.375, 1.375, 1.375 },
            wsc = { str = 0.3, dex = 0.3 },
            numHits = 3,
            multiHitfTP = true,
            critVaries = { 0.1, 0.2, 0.4 },
            skillchain = { 'DETONATION', 'IMPACTION' },
        },
    },
    [135] =
    {
        id = 135,
        key = 'blade_ten',
        name = 'Blade: Ten',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.5, 11.5, 15.35 },
            wsc = { str = 0.3, dex = 0.3 },
            numHits = 1,
            skillchain = { 'GRAVITATION' },
        },
    },
    [136] =
    {
        id = 136,
        key = 'blade_ku',
        name = 'Blade: Ku',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.25, 1.25, 1.25 },
            wsc = { str = 0.3, dex = 0.3 },
            numHits = 5,
            multiHitfTP = true,
            accVaries = { 30.0, 60.0, 90.0 },
            skillchain = { 'GRAVITATION', 'TRANSFIXION' },
        },
    },
    [137] =
    {
        id = 137,
        key = 'blade_metsu',
        name = 'Blade: Metsu',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { dex = 0.8 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'FRAGMENTATION' },
            debuff = { effect = 'PARALYSIS', label = 'Paralysis', binary = false },
            aftermath = 'relic',
        },
    },
    [138] =
    {
        id = 138,
        key = 'blade_kamu',
        name = 'Blade: Kamu',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6, int = 0.6 },
            numHits = 1,
            atkVaries = { 2.25, 2.25, 2.25 },
            ignoredDefense = { 0.25, 0.25, 0.25 },
            skillchain = { 'FRAGMENTATION', 'COMPRESSION' },
            debuff = { effect = 'ACCURACY_DOWN', label = 'Accuracy Down', binary = false },
            aftermath = 'mythic',
        },
    },
    [139] =
    {
        id = 139,
        key = 'blade_yu',
        name = 'Blade: Yu',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'magic',
        element = xi.element.WATER,
        elementName = 'Water',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { dex = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'REVERBERATION', 'SCISSION' },
            debuff = { effect = 'POISON', label = 'Poison', binary = false },
        },
    },
    [140] =
    {
        id = 140,
        key = 'blade_hi',
        name = 'Blade: Hi',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { agi = 0.8 },
            numHits = 1,
            critVaries = { 0.15, 0.3, 0.6 },
            skillchain = { 'DARKNESS', 'GRAVITATION' },
            aftermath = 'empyrean',
        },
    },
    [141] =
    {
        id = 141,
        key = 'blade_shun',
        name = 'Blade: Shun',
        skill = xi.skill.KATANA,
        skillName = 'Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { dex = 0.7 },
            numHits = 5,
            multiHitfTP = true,
            atkVaries = { 1.0, 2.0, 3.0 },
            skillchain = { 'FUSION', 'IMPACTION' },
        },
    },
    [144] =
    {
        id = 144,
        key = 'tachi_enpi',
        name = 'Tachi: Enpi',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.0, 5.0 },
            wsc = { str = 0.6 },
            numHits = 2,
            skillchain = { 'TRANSFIXION', 'SCISSION' },
        },
    },
    [145] =
    {
        id = 145,
        key = 'tachi_hobaku',
        name = 'Tachi: Hobaku',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.6 },
            numHits = 1,
            skillchain = { 'INDURATION' },
            debuff = { effect = 'STUN', label = 'Stun', binary = true },
        },
    },
    [146] =
    {
        id = 146,
        key = 'tachi_goten',
        name = 'Tachi: Goten',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'hybrid',
        element = xi.element.THUNDER,
        elementName = 'Thunder',
        orig =
        {
            ftp = { 0.5, 1.4492, 2.5 },
            wsc = { str = 0.6 },
            numHits = 1,
            skillchain = { 'TRANSFIXION', 'IMPACTION' },
        },
    },
    [147] =
    {
        id = 147,
        key = 'tachi_kagero',
        name = 'Tachi: Kagero',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'hybrid',
        element = xi.element.FIRE,
        elementName = 'Fire',
        orig =
        {
            ftp = { 0.5, 1.4492, 2.5 },
            wsc = { str = 0.75 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION' },
        },
    },
    [148] =
    {
        id = 148,
        key = 'tachi_jinpu',
        name = 'Tachi: Jinpu',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'hybrid',
        element = xi.element.WIND,
        elementName = 'Wind',
        orig =
        {
            ftp = { 0.5, 1.4492, 2.5 },
            wsc = { str = 0.3 },
            numHits = 2,
            skillchain = { 'SCISSION', 'DETONATION' },
        },
    },
    [149] =
    {
        id = 149,
        key = 'tachi_koki',
        name = 'Tachi: Koki',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'hybrid',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 0.5, 1.4492, 2.5 },
            wsc = { str = 0.5, mnd = 0.3 },
            numHits = 1,
            skillchain = { 'REVERBERATION', 'IMPACTION' },
        },
    },
    [150] =
    {
        id = 150,
        key = 'tachi_yukikaze',
        name = 'Tachi: Yukikaze',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5625, 2.5625, 4.125 },
            wsc = { str = 0.75 },
            numHits = 1,
            atkVaries = { 1.5, 1.5, 1.5 },
            skillchain = { 'INDURATION', 'DETONATION' },
            debuff = { effect = 'BLINDNESS', label = 'Blind', binary = false },
        },
    },
    [151] =
    {
        id = 151,
        key = 'tachi_gekko',
        name = 'Tachi: Gekko',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5625, 2.5625, 4.125 },
            wsc = { str = 0.75 },
            numHits = 1,
            atkVaries = { 2.0, 2.0, 2.0 },
            skillchain = { 'DISTORTION', 'REVERBERATION' },
            debuff = { effect = 'SILENCE', label = 'Silence', binary = true },
        },
    },
    [152] =
    {
        id = 152,
        key = 'tachi_kasha',
        name = 'Tachi: Kasha',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.5625, 2.5625, 4.125 },
            wsc = { str = 0.75 },
            numHits = 1,
            atkVaries = { 1.65, 1.65, 1.65 },
            skillchain = { 'FUSION', 'COMPRESSION' },
            debuff = { effect = 'PARALYSIS', label = 'Paralysis', binary = false },
        },
    },
    [153] =
    {
        id = 153,
        key = 'tachi_kaiten',
        name = 'Tachi: Kaiten',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { str = 0.8 },
            numHits = 1,
            skillchain = { 'LIGHT', 'FRAGMENTATION' },
            aftermath = 'relic',
        },
    },
    [154] =
    {
        id = 154,
        key = 'tachi_rana',
        name = 'Tachi: Rana',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.5 },
            numHits = 3,
            accVaries = { 10.0, 25.0, 40.0 },
            skillchain = { 'GRAVITATION', 'INDURATION' },
            aftermath = 'mythic',
        },
    },
    [155] =
    {
        id = 155,
        key = 'tachi_ageha',
        name = 'Tachi: Ageha',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.625, 2.625, 2.625 },
            wsc = { str = 0.4, chr = 0.6 },
            numHits = 1,
            skillchain = { 'COMPRESSION', 'SCISSION' },
            debuff = { effect = 'DEFENSE_DOWN', label = 'Defense Down', binary = false },
        },
    },
    [156] =
    {
        id = 156,
        key = 'tachi_fudo',
        name = 'Tachi: Fudo',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.5, 5.75, 8.0 },
            wsc = { str = 0.8 },
            numHits = 1,
            atkVaries = { 1.0, 1.0, 1.0 },
            skillchain = { 'LIGHT', 'DISTORTION' },
            aftermath = 'empyrean',
        },
    },
    [157] =
    {
        id = 157,
        key = 'tachi_shoha',
        name = 'Tachi: Shoha',
        skill = xi.skill.GREAT_KATANA,
        skillName = 'Great Katana',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.375, 3.25, 4.625 },
            wsc = { str = 0.7 },
            numHits = 2,
            atkVaries = { 1.375, 1.375, 1.375 },
            skillchain = { 'FRAGMENTATION', 'COMPRESSION' },
        },
    },
    [160] =
    {
        id = 160,
        key = 'shining_strike',
        name = 'Shining Strike',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 1.625, 3.0, 4.625 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
        },
    },
    [161] =
    {
        id = 161,
        key = 'seraph_strike',
        name = 'Seraph Strike',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 2.125, 3.625, 6.125 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
        },
    },
    [162] =
    {
        id = 162,
        key = 'brainshaker',
        name = 'Brainshaker',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'REVERBERATION' },
            debuff = { effect = 'STUN', label = 'Stun', binary = true },
        },
    },
    [163] =
    {
        id = 163,
        key = 'starlight',
        name = 'Starlight',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'utility',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = {},
            numHits = 1,
            skillchain = {},
            restoreMp = true,
        },
    },
    [164] =
    {
        id = 164,
        key = 'moonlight',
        name = 'Moonlight',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'utility',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = {},
            numHits = 1,
            skillchain = {},
            aoe = true,
            restoreMp = true,
        },
    },
    [165] =
    {
        id = 165,
        key = 'skullbreaker',
        name = 'Skullbreaker',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'INDURATION', 'REVERBERATION' },
            debuff = { effect = 'INT_DOWN', label = 'INT Down', binary = false },
        },
    },
    [166] =
    {
        id = 166,
        key = 'true_strike',
        name = 'True Strike',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            critVaries = { 1.0, 1.0, 1.0 },
            accVaries = { -50.0, 10.0, 50.0 },
            atkVaries = { 2.0, 2.0, 2.0 },
            skillchain = { 'DETONATION', 'IMPACTION' },
        },
    },
    [167] =
    {
        id = 167,
        key = 'judgment',
        name = 'Judgment',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.5, 8.75, 11.75 },
            wsc = { str = 0.5, mnd = 0.5 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
        },
    },
    [168] =
    {
        id = 168,
        key = 'hexa_strike',
        name = 'Hexa Strike',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.125, 1.125, 1.125 },
            wsc = { str = 0.3, mnd = 0.3 },
            numHits = 6,
            multiHitfTP = true,
            critVaries = { 0.05, 0.1, 0.25 },
            skillchain = { 'FUSION' },
        },
    },
    [169] =
    {
        id = 169,
        key = 'black_halo',
        name = 'Black Halo',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 7.2, 9.6 },
            wsc = { str = 0.3, mnd = 0.7 },
            numHits = 2,
            skillchain = { 'FRAGMENTATION', 'COMPRESSION' },
        },
    },
    [170] =
    {
        id = 170,
        key = 'randgrith',
        name = 'Randgrith',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 4.25, 4.25, 4.25 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'LIGHT', 'FRAGMENTATION' },
            debuff = { effect = 'EVASION_DOWN', label = 'Evasion Down', binary = false },
            aftermath = 'relic',
        },
    },
    [171] =
    {
        id = 171,
        key = 'mystic_boon',
        name = 'Mystic Boon',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.5, 4.0, 7.0 },
            wsc = { str = 0.3, mnd = 0.7 },
            numHits = 1,
            skillchain = {},
            drainMp = true,
            aftermath = 'mythic',
        },
    },
    [172] =
    {
        id = 172,
        key = 'flash_nova',
        name = 'Flash Nova',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { str = 0.5, mnd = 0.5 },
            numHits = 1,
            skillchain = { 'INDURATION', 'REVERBERATION' },
        },
    },
    [173] =
    {
        id = 173,
        key = 'dagan',
        name = 'Dagan',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'utility',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = {},
            numHits = 1,
            skillchain = {},
            restoreMp = true,
            aftermath = 'empyrean',
        },
    },
    [174] =
    {
        id = 174,
        key = 'realmrazer',
        name = 'Realmrazer',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 0.9, 0.9, 0.9 },
            wsc = { mnd = 0.7 },
            numHits = 7,
            multiHitfTP = true,
            accVaries = { 20.0, 40.0, 70.0 },
            skillchain = { 'FUSION', 'IMPACTION' },
        },
    },
    [175] =
    {
        id = 175,
        key = 'exudation',
        name = 'Exudation',
        skill = xi.skill.CLUB,
        skillName = 'Club',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.8, 2.8, 2.8 },
            wsc = { int = 0.5, mnd = 0.5 },
            numHits = 1,
            atkVaries = { 1.5, 3.6, 4.7 },
            skillchain = { 'DARKNESS', 'FRAGMENTATION' },
        },
    },
    [176] =
    {
        id = 176,
        key = 'heavy_swing',
        name = 'Heavy Swing',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.0, 3.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
        },
    },
    [177] =
    {
        id = 177,
        key = 'rock_crusher',
        name = 'Rock Crusher',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        element = xi.element.EARTH,
        elementName = 'Earth',
        orig =
        {
            ftp = { 1.0, 3.2656, 5.5312 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'IMPACTION' },
        },
    },
    [178] =
    {
        id = 178,
        key = 'earth_crusher',
        name = 'Earth Crusher',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        element = xi.element.EARTH,
        elementName = 'Earth',
        orig =
        {
            ftp = { 1.0, 3.5781, 6.1562 },
            wsc = { str = 0.4, int = 0.4 },
            numHits = 1,
            skillchain = { 'DETONATION', 'IMPACTION' },
            aoe = true,
        },
    },
    [179] =
    {
        id = 179,
        key = 'starburst',
        name = 'Starburst',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 1.0, 3.2656, 5.5312 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'COMPRESSION', 'REVERBERATION' },
        },
    },
    [180] =
    {
        id = 180,
        key = 'sunburst',
        name = 'Sunburst',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        orig =
        {
            ftp = { 1.0, 3.5781, 6.1562 },
            wsc = { str = 0.4, mnd = 0.4 },
            numHits = 1,
            skillchain = { 'COMPRESSION', 'REVERBERATION' },
        },
    },
    [181] =
    {
        id = 181,
        key = 'shell_crusher',
        name = 'Shell Crusher',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 1.0 },
            numHits = 1,
            skillchain = { 'DETONATION' },
            debuff = { effect = 'DEFENSE_DOWN', label = 'Defense Down', binary = false },
        },
    },
    [182] =
    {
        id = 182,
        key = 'full_swing',
        name = 'Full Swing',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 3.0, 9.0 },
            wsc = { str = 0.5 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION', 'IMPACTION' },
        },
    },
    [183] =
    {
        id = 183,
        key = 'spirit_taker',
        name = 'Spirit Taker',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 2.0, 3.0 },
            wsc = { int = 0.5, mnd = 0.5 },
            numHits = 1,
            skillchain = {},
            drainMp = true,
        },
    },
    [184] =
    {
        id = 184,
        key = 'retribution',
        name = 'Retribution',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 2.0, 3.0, 5.0 },
            wsc = { str = 0.3, mnd = 0.5 },
            numHits = 1,
            atkVaries = { 1.5, 1.5, 1.5 },
            skillchain = { 'GRAVITATION', 'REVERBERATION' },
        },
    },
    [185] =
    {
        id = 185,
        key = 'gate_of_tartarus',
        name = 'Gate Of Tartarus',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { chr = 0.8 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'DISTORTION' },
            debuff = { effect = 'ATTACK_DOWN', label = 'Attack Down', binary = false },
            aftermath = 'relic',
        },
    },
    [186] =
    {
        id = 186,
        key = 'vidohunir',
        name = 'Vidohunir',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        orig =
        {
            ftp = { 1.75, 1.75, 1.75 },
            wsc = { int = 0.8 },
            numHits = 1,
            skillchain = { 'FRAGMENTATION', 'DISTORTION' },
            debuff = { effect = 'MAGIC_DEF_DOWN', label = 'M.Def Down', binary = false },
            aftermath = 'mythic',
        },
    },
    [187] =
    {
        id = 187,
        key = 'garland_of_bliss',
        name = 'Garland Of Bliss',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        orig =
        {
            ftp = { 2.25, 2.25, 2.25 },
            wsc = { str = 0.3, mnd = 0.7 },
            numHits = 1,
            skillchain = { 'FUSION', 'REVERBERATION' },
            debuff = { effect = 'DEFENSE_DOWN', label = 'Defense Down', binary = false },
            aftermath = 'mythic',
        },
    },
    [188] =
    {
        id = 188,
        key = 'omniscience',
        name = 'Omniscience',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        orig =
        {
            ftp = { 2.0, 2.0, 2.0 },
            wsc = { mnd = 0.8 },
            numHits = 1,
            skillchain = { 'GRAVITATION', 'TRANSFIXION' },
            debuff = { effect = 'MAGIC_ATK_DOWN', label = 'M.Atk Down', binary = false },
            aftermath = 'mythic',
        },
    },
    [189] =
    {
        id = 189,
        key = 'cataclysm',
        name = 'Cataclysm',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 1.75, 3.75, 6.5 },
            wsc = { str = 0.3, int = 0.3 },
            numHits = 1,
            skillchain = { 'COMPRESSION', 'REVERBERATION' },
            aoe = true,
        },
    },
    [190] =
    {
        id = 190,
        key = 'myrkr',
        name = 'Myrkr',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'utility',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = {},
            numHits = 1,
            skillchain = {},
            restoreMp = true,
            aftermath = 'empyrean',
        },
    },
    [191] =
    {
        id = 191,
        key = 'shattersoul',
        name = 'Shattersoul',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.375, 1.375, 1.375 },
            wsc = { int = 0.7 },
            numHits = 4,
            skillchain = { 'GRAVITATION', 'INDURATION' },
            debuff = { effect = 'MAGIC_DEF_DOWN', label = 'M.Def Down', binary = false },
        },
    },
    [192] =
    {
        id = 192,
        key = 'flaming_arrow',
        name = 'Flaming Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'hybrid',
        element = xi.element.FIRE,
        elementName = 'Fire',
        orig =
        {
            ftp = { 0.5, 1.55, 2.1 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION', 'TRANSFIXION' },
        },
    },
    [193] =
    {
        id = 193,
        key = 'piercing_arrow',
        name = 'Piercing Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            ignoredDefense = { 0.0, 0.375, 0.75 },
            skillchain = { 'REVERBERATION', 'TRANSFIXION' },
        },
    },
    [194] =
    {
        id = 194,
        key = 'dulling_arrow',
        name = 'Dulling Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            critVaries = { 0.2, 0.5, 1.0 },
            skillchain = { 'LIQUEFACTION', 'TRANSFIXION' },
        },
    },
    [196] =
    {
        id = 196,
        key = 'sidewinder',
        name = 'Sidewinder',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            accVaries = { -50.0, -10.0, 30.0 },
            skillchain = { 'REVERBERATION', 'TRANSFIXION', 'DETONATION' },
        },
    },
    [197] =
    {
        id = 197,
        key = 'blast_arrow',
        name = 'Blast Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 2.0, 2.0, 2.0 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            accVaries = { 0.0, 60.0, 100.0 },
            skillchain = { 'INDURATION', 'TRANSFIXION' },
        },
    },
    [198] =
    {
        id = 198,
        key = 'arching_arrow',
        name = 'Arching Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 3.5, 3.5, 3.5 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            critVaries = { 0.2, 0.5, 0.9 },
            skillchain = { 'FUSION' },
        },
    },
    [199] =
    {
        id = 199,
        key = 'empyreal_arrow',
        name = 'Empyreal Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.5, 2.5, 5.0 },
            wsc = { str = 0.2, agi = 0.5 },
            numHits = 1,
            atkVaries = { 2.0, 2.0, 2.0 },
            skillchain = { 'FUSION', 'TRANSFIXION' },
        },
    },
    [200] =
    {
        id = 200,
        key = 'namas_arrow',
        name = 'Namas Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 2.75, 2.75, 2.75 },
            wsc = { str = 0.4, agi = 0.4 },
            numHits = 1,
            skillchain = { 'LIGHT', 'DISTORTION' },
            enmity = 'low',
            aftermath = 'relic',
        },
    },
    [201] =
    {
        id = 201,
        key = 'refulgent_arrow',
        name = 'Refulgent Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 3.0, 4.25, 7.0 },
            wsc = { str = 0.6 },
            numHits = 1,
            skillchain = { 'REVERBERATION', 'TRANSFIXION' },
        },
    },
    [202] =
    {
        id = 202,
        key = 'jishnus_radiance',
        name = 'Jishnu\'s Radiance',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.75, 1.75, 1.75 },
            wsc = { dex = 0.8 },
            numHits = 3,
            multiHitfTP = true,
            critVaries = { 0.15, 0.3, 0.6 },
            skillchain = { 'LIGHT', 'FUSION' },
            aftermath = 'empyrean',
        },
    },
    [203] =
    {
        id = 203,
        key = 'apex_arrow',
        name = 'Apex Arrow',
        skill = xi.skill.ARCHERY,
        skillName = 'Archery',
        wsType = 'ranged',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { agi = 0.7 },
            numHits = 1,
            ignoredDefense = { 0.125, 0.1875, 0.25 },
            skillchain = { 'FRAGMENTATION', 'TRANSFIXION' },
        },
    },
    [208] =
    {
        id = 208,
        key = 'hot_shot',
        name = 'Hot Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'hybrid',
        element = xi.element.FIRE,
        elementName = 'Fire',
        orig =
        {
            ftp = { 0.5, 1.55, 2.1 },
            wsc = { agi = 0.7 },
            numHits = 1,
            skillchain = { 'LIQUEFACTION', 'TRANSFIXION' },
        },
    },
    [209] =
    {
        id = 209,
        key = 'split_shot',
        name = 'Split Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { agi = 0.7 },
            numHits = 1,
            ignoredDefense = { 0.0, 0.375, 0.75 },
            skillchain = { 'REVERBERATION', 'TRANSFIXION' },
        },
    },
    [210] =
    {
        id = 210,
        key = 'sniper_shot',
        name = 'Sniper Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { agi = 0.7 },
            numHits = 1,
            critVaries = { 0.2, 0.5, 1.0 },
            skillchain = { 'LIQUEFACTION', 'TRANSFIXION' },
            debuff = { effect = 'INT_DOWN', label = 'INT Down', binary = false },
        },
    },
    [212] =
    {
        id = 212,
        key = 'slug_shot',
        name = 'Slug Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 5.0, 5.0, 5.0 },
            wsc = { agi = 0.7 },
            numHits = 1,
            accVaries = { -50.0, -10.0, 30.0 },
            skillchain = { 'REVERBERATION', 'TRANSFIXION', 'DETONATION' },
        },
    },
    [213] =
    {
        id = 213,
        key = 'blast_shot',
        name = 'Blast Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 2.0, 2.0, 2.0 },
            wsc = { agi = 0.7 },
            numHits = 1,
            accVaries = { 0.0, 60.0, 100.0 },
            skillchain = { 'INDURATION', 'TRANSFIXION' },
        },
    },
    [214] =
    {
        id = 214,
        key = 'heavy_shot',
        name = 'Heavy Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 3.5, 3.5, 3.5 },
            wsc = { agi = 0.7 },
            numHits = 1,
            critVaries = { 0.2, 0.5, 0.9 },
            skillchain = { 'FUSION' },
        },
    },
    [215] =
    {
        id = 215,
        key = 'detonator',
        name = 'Detonator',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 1.5, 2.5, 5.0 },
            wsc = { agi = 0.7 },
            numHits = 1,
            atkVaries = { 2.0, 2.0, 2.0 },
            skillchain = { 'FUSION', 'TRANSFIXION' },
        },
    },
    [216] =
    {
        id = 216,
        key = 'coronach',
        name = 'Coronach',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { dex = 0.4, agi = 0.4 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'FRAGMENTATION' },
            enmity = 'low',
            aftermath = 'relic',
        },
    },
    [217] =
    {
        id = 217,
        key = 'trueflight',
        name = 'Trueflight',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'magic',
        element = xi.element.LIGHT,
        elementName = 'Light',
        orig =
        {
            ftp = { 3.8906, 6.4922, 9.6719 },
            wsc = { agi = 1.0 },
            numHits = 1,
            skillchain = { 'FRAGMENTATION', 'SCISSION' },
            aftermath = 'mythic',
        },
    },
    [218] =
    {
        id = 218,
        key = 'leaden_salute',
        name = 'Leaden Salute',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'magic',
        element = xi.element.DARK,
        elementName = 'Dark',
        orig =
        {
            ftp = { 4.0, 6.7, 10.0 },
            wsc = { agi = 1.0 },
            numHits = 1,
            skillchain = { 'GRAVITATION', 'TRANSFIXION' },
            aftermath = 'mythic',
        },
    },
    [219] =
    {
        id = 219,
        key = 'numbing_shot',
        name = 'Numbing Shot',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 3.0, 3.0, 3.0 },
            wsc = { agi = 0.8 },
            numHits = 1,
            skillchain = { 'INDURATION', 'DETONATION', 'IMPACTION' },
            debuff = { effect = 'PARALYSIS', label = 'Paralysis', binary = false },
        },
    },
    [220] =
    {
        id = 220,
        key = 'wildfire',
        name = 'Wildfire',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'magic',
        element = xi.element.FIRE,
        elementName = 'Fire',
        orig =
        {
            ftp = { 5.5, 5.5, 5.5 },
            wsc = { agi = 0.6 },
            numHits = 1,
            skillchain = { 'DARKNESS', 'GRAVITATION' },
            enmity = 'low',
            aftermath = 'empyrean',
        },
    },
    [221] =
    {
        id = 221,
        key = 'last_stand',
        name = 'Last Stand',
        skill = xi.skill.MARKSMANSHIP,
        skillName = 'Marksmanship',
        wsType = 'ranged',
        orig =
        {
            ftp = { 2.0, 3.0, 4.0 },
            wsc = { agi = 0.7 },
            numHits = 2,
            multiHitfTP = true,
            skillchain = { 'FUSION', 'REVERBERATION' },
        },
    },
    [224] =
    {
        id = 224,
        key = 'exenterator',
        name = 'Exenterator',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.1875, 1.1875, 1.1875 },
            wsc = { agi = 0.7 },
            numHits = 4,
            multiHitfTP = true,
            skillchain = { 'FRAGMENTATION', 'SCISSION' },
            debuff = { effect = 'ACCURACY_DOWN', label = 'Accuracy Down', binary = false },
        },
    },
    [225] =
    {
        id = 225,
        key = 'chant_du_cygne',
        name = 'Chant du Cygne',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.6328, 1.6328, 1.6328 },
            wsc = { dex = 0.8 },
            numHits = 3,
            multiHitfTP = true,
            critVaries = { 0.15, 0.3, 0.6 },
            skillchain = { 'LIGHT', 'DISTORTION' },
            aftermath = 'empyrean',
        },
    },
    [226] =
    {
        id = 226,
        key = 'requiescat',
        name = 'Requiescat',
        skill = xi.skill.SWORD,
        skillName = 'Sword',
        wsType = 'physical',
        orig =
        {
            ftp = { 1.0, 1.0, 1.0 },
            wsc = { mnd = 0.7 },
            numHits = 5,
            multiHitfTP = true,
            atkVaries = { 0.8, 0.9172, 1.05 },
            skillchain = { 'GRAVITATION', 'SCISSION' },
        },
    },
    [231] =
    {
        id = 231,
        key = 'maru_kala',
        name = 'Maru Kala',
        skill = xi.skill.HAND_TO_HAND,
        skillName = 'Hand-to-Hand',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.128, 7.273, 11.414 },
            wsc = { str = 0.4175, dex = 0.4175 },
            numHits = 2,
            skillchain = { 'DETONATION', 'COMPRESSION', 'DISTORTION' },
        },
    },
    [232] =
    {
        id = 232,
        key = 'ruthless_stroke',
        name = 'Ruthless Stroke',
        skill = xi.skill.DAGGER,
        skillName = 'Dagger',
        wsType = 'physical',
        orig =
        {
            ftp = { 5.7578, 14.5156, 23.2773 },
            wsc = { dex = 0.2, agi = 0.2 },
            numHits = 4,
            skillchain = { 'LIQUEFACTION', 'IMPACTION', 'FRAGMENTATION' },
        },
    },
    [235] =
    {
        id = 235,
        key = 'oshala',
        name = 'Oshala',
        skill = xi.skill.STAFF,
        skillName = 'Staff',
        wsType = 'physical',
        orig =
        {
            ftp = { 3.95, 7.89, 11.84 },
            wsc = { int = 0.45, mnd = 0.45 },
            numHits = 1,
            skillchain = { 'INDURATION', 'REVERBERATION', 'FUSION' },
        },
    },
}

catalog.byKey = {}
catalog.bySkill = {}
catalog.orderedIds = {}

for id, ws in pairs(catalog.byId) do
    catalog.byKey[ws.key] = ws
    catalog.byKey[string.lower(ws.name)] = ws
    catalog.bySkill[ws.skill] = catalog.bySkill[ws.skill] or {}
    table.insert(catalog.bySkill[ws.skill], ws)
    table.insert(catalog.orderedIds, id)
end

table.sort(catalog.orderedIds)
for _, list in pairs(catalog.bySkill) do
    table.sort(list, function(a, b) return a.id < b.id end)
end

function catalog.resolve(idOrName)
    if idOrName == nil then
        return nil
    end
    local num = tonumber(idOrName)
    if num ~= nil then
        return catalog.byId[num]
    end
    local norm = string.lower(tostring(idOrName))
    if catalog.byKey[norm] ~= nil then
        return catalog.byKey[norm]
    end
    local underscored = string.gsub(norm, '[%s:]+', '_')
    underscored = string.gsub(underscored, '__+', '_')
    return catalog.byKey[underscored]
end

return catalog
