-----------------------------------
-- SoulspireXI 16-Spec Bespoke Weaponskill Tree Synthesis Engine
-- Generates 12 unique, combat-backed non-SC talent nodes (3 cols x 4 tiers)
-- for every (WS, Spec) pair across all 16 concrete specs:
--   WAR: commander, berserker, spartan (formerly gladiator)
--   MNK: sensei, blackbelt, chiweaver (strictly 0 MP / 0 Refresh)
--   RUN: inquisitor, spellblade, lifebinder
--   SCH: medic, sage
--   BLM: necromancer
--   DNC: bladewheel
--   SAM: ronin, imperialarcher, warlord
-----------------------------------
local talents = xi.soulspire and xi.soulspire.wsTalents
local DNA     = require('modules/custom/lua/soulspire_ws_dna')

local P = {}

P.ALL_SPECS =
{
    'berserker',
    'commander',
    'spartan',
    'sensei',
    'blackbelt',
    'chiweaver',
    'inquisitor',
    'spellblade',
    'lifebinder',
    'medic',
    'sage',
    'necromancer',
    'bladewheel',
    'ronin',
    'imperialarcher',
    'warlord',
    'aegistemplar',
    'kagemusha',
    'kurogane',
    'bishop',
    'templar',
    'magus',
    'vampire',
    'celestial',
    'pugilist',
    'vanguard',
    'animist',
    'verdant',
    'wyvernheart',
    'miragesentinel',
    'flintlock',
    'buccaneer',
    'gambler',
    'huntsman',
}

local STAT_UP =
{
    str = 'STR', dex = 'DEX', vit = 'VIT', agi = 'AGI',
    int = 'INT', mnd = 'MND', chr = 'CHR',
}

local function round2(v)
    return math.floor(v * 100 + 0.5) / 100
end

local function pick(tbl, r)
    if type(tbl) == 'table' then
        return tbl[r] or tbl[#tbl]
    end
    return tbl
end

local function lin(step, n)
    local out = {}
    for i = 1, n do
        out[i] = round2(step * i)
    end
    return out
end

local function trimName(s)
    if #s <= 24 then
        return s
    end
    return s:sub(1, 24):gsub('%s+$', '')
end

local function mkNode(tier, col, key, name, maxRank, zeroDesc, rankDesc, eff)
    return talents.makeSpecNode(
    {
        tier     = tier,
        col      = col,
        key      = key,
        name     = trimName(name),
        maxRank  = maxRank,
        zeroDesc = zeroDesc,
        rankDesc = rankDesc,
        effect   = eff,
    })
end

local function mkFtpNode(name, curve, zeroSuffix, rankSuffixFn, eff)
    local fullEff = eff or {}
    fullEff.ftpCurve = curve
    return mkNode(1, 1, 'ftp', name, 6,
        string.format('fTP %.2f/%.2f/%.2f%s', curve[1], curve[2], curve[3], zeroSuffix or ''),
        function(r)
            local t = math.min(r, 6) / 6
            local a = round2(1.0 + (curve[1] - 1.0) * t)
            local b = round2(1.0 + (curve[2] - 1.0) * t)
            local c = round2(1.0 + (curve[3] - 1.0) * t)
            local sfx = rankSuffixFn and rankSuffixFn(r) or ''
            return string.format('fTP %.2f/%.2f/%.2f%s', a, b, c, sfx)
        end,
        fullEff)
end

-- Custom status effect IDs (numeric fallbacks since ws_talents loads before *_specs.lua)
local EFF_CMD_BREACH  = 815
local EFF_CMD_BULWARK = 816
local EFF_CMD_CADENCE = 817
local EFF_CMD_HORN    = 818
local EFF_ZRK_SURGE   = 819
local EFF_GLD_WARD    = 820
local EFF_INQ_BATTUTA = 821
local EFF_INQ_AEGIS   = 822
local EFF_INQ_CONV    = 823
local EFF_SPB_FLARE   = 824
local EFF_LFB_FONT    = 825
local EFF_LFB_WARD    = 826
local EFF_SPB_COND    = 827
local EFF_SPB_ASCEND  = 828
local EFF_CHW_LOTUS        = 829
local EFF_CHW_HARMONY      = 830
local EFF_RONIN_STAGGER    = 837
local EFF_IMP_DRAWN_OISOYA = 838
local EFF_IMP_COSMIC_BRAND = 839
local EFF_WARLORD_NOTO     = 840
local EFF_WARLORD_ASHURA   = 841
local EFF_AEGIS_ZEAL         = 842
local EFF_AEGIS_CONSECRATION = 843
local EFF_HOLY_RETRIBUTION   = 844

local STANCE_DEFS =
{
    commander = {
        label   = 'Command',
        jobSpec = 'commander',
        effects = { xi.effect.WARCRY, xi.effect.RESTRAINT, xi.effect.RETALIATION, EFF_CMD_BREACH, EFF_CMD_BULWARK, EFF_CMD_CADENCE, EFF_CMD_HORN },
    },
    berserker = {
        label   = 'Bloodlust',
        jobSpec = 'berserker',
        effects = { xi.effect.BERSERK, xi.effect.BLOOD_RAGE, xi.effect.AGGRESSOR, xi.effect.RESTRAINT, xi.effect.LAST_RESORT, xi.effect.SOULEATER, EFF_ZRK_SURGE },
    },
    spartan   = {
        label   = 'Vanguard',
        jobSpec = 'spartan',
        effects = { xi.effect.DEFENDER, xi.effect.BLOOD_RAGE, xi.effect.RETALIATION, xi.effect.SENTINEL, xi.effect.RAMPART, EFF_GLD_WARD },
    },
    sensei = {
        label   = 'Dojo Stance',
        jobSpec = 'sensei',
        effects = { xi.effect.COUNTERSTANCE, xi.effect.DODGE, xi.effect.FOCUS, xi.effect.PERFECT_COUNTER, xi.effect.INNER_STRENGTH },
    },
    blackbelt = {
        label   = 'Footwork/Imp',
        jobSpec = 'blackbelt',
        effects = { xi.effect.FOOTWORK, xi.effect.IMPETUS, xi.effect.FOCUS, xi.effect.HUNDRED_FISTS },
    },
    chiweaver = {
        label   = 'Lotus/Harm',
        jobSpec = 'chiweaver',
        effects = { EFF_CHW_LOTUS, EFF_CHW_HARMONY, xi.effect.FOCUS, xi.effect.DODGE, xi.effect.INNER_STRENGTH },
    },
    inquisitor = {
        label   = 'Battuta/Rune',
        jobSpec = 'inquisitor',
        effects = { xi.effect.SWORDPLAY, xi.effect.BATTUTA, xi.effect.PFLUG, xi.effect.LIEMENT, xi.effect.VALLATION, xi.effect.FOIL, EFF_INQ_BATTUTA, EFF_INQ_AEGIS, EFF_INQ_CONV },
    },
    spellblade = {
        label   = 'Edgeflare',
        jobSpec = 'spellblade',
        effects = { xi.effect.SWORDPLAY, xi.effect.IGNIS, xi.effect.GELUS, xi.effect.FLABRA, xi.effect.TELLUS, xi.effect.SULPOR, xi.effect.UNDA, xi.effect.LUX, xi.effect.TENEBRAE, EFF_SPB_FLARE, EFF_SPB_COND, EFF_SPB_ASCEND },
    },
    lifebinder = {
        label   = 'Font/Ward',
        jobSpec = 'lifebinder',
        effects = { xi.effect.VALIANCE, xi.effect.VALLATION, xi.effect.SWORDPLAY, xi.effect.LUX, xi.effect.UNDA, EFF_LFB_FONT, EFF_LFB_WARD },
    },
    medic = {
        label    = 'White/Eos',
        schSpec  = 'medic',
        petAlive = true,
        effects  = { xi.effect.LIGHT_ARTS, xi.effect.ADDENDUM_WHITE, xi.effect.SUBLIMATION_ACTIVATED, xi.effect.SUBLIMATION_COMPLETE, xi.effect.AFFLATUS_SOLACE },
    },
    sage = {
        label    = 'Black/Fae',
        schSpec  = 'sage',
        petAlive = true,
        effects  = { xi.effect.DARK_ARTS, xi.effect.ADDENDUM_BLACK, xi.effect.EBULLIENCE, xi.effect.IMMANENCE, xi.effect.ALACRITY },
    },
    necromancer = {
        label    = 'Dark Pact',
        jobSpec  = 'necromancer',
        petAlive = true,
        effects  = { xi.effect.MANA_WALL, xi.effect.ELEMENTAL_SEAL, xi.effect.DARK_ARTS, xi.effect.SOULEATER },
    },
    bladewheel = {
        label    = 'Bladewheel',
        jobSpec  = 'bladewheel',
        localVar = 'OX_THROW_STANCE',
        effects  = { xi.effect.SABER_DANCE, xi.effect.FAN_DANCE, xi.effect.HASTE_SAMBA, xi.effect.DRAIN_SAMBA, xi.effect.CLIMACTIC_FLOURISH, xi.effect.BUILDING_FLOURISH },
    },
    imperialarcher = {
        label   = 'Oisoya/Hasso',
        jobSpec = 'imperialarcher',
        effects = { xi.effect.HASSO, xi.effect.SENGIKORI, xi.effect.MEIKYO_SHISUI, xi.effect.SHARPSHOT, xi.effect.VELOCITY_SHOT, EFF_IMP_DRAWN_OISOYA, EFF_IMP_COSMIC_BRAND },
    },
    ronin = {
        label   = 'Seigan/Mushin',
        jobSpec = 'ronin',
        effects = { xi.effect.SEIGAN, xi.effect.THIRD_EYE, xi.effect.WARDING_CIRCLE, xi.effect.MEIKYO_SHISUI, EFF_RONIN_STAGGER },
    },
    warlord = {
        label   = 'Noto/Ashura',
        jobSpec = 'warlord',
        effects = { xi.effect.HASSO, xi.effect.HAGAKURE, xi.effect.SENGIKORI, xi.effect.SEKKANOKI, xi.effect.MEIKYO_SHISUI, EFF_WARLORD_NOTO, EFF_WARLORD_ASHURA },
    },
    aegistemplar = {
        label   = 'Aegis/Zeal',
        jobSpec = 'aegistemplar',
        effects = { xi.effect.SENTINEL, xi.effect.RAMPART, xi.effect.MAJESTY, xi.effect.PALISADE, EFF_AEGIS_ZEAL, EFF_AEGIS_CONSECRATION, EFF_HOLY_RETRIBUTION },
    },
    kurogane = {
        label   = 'Clone Assault',
        jobSpec = 'kurogane',
        effects = { xi.effect.INNIN, xi.effect.FUTAE, xi.effect.SANGE },
    },
    kagemusha = {
        label   = 'Yonin/Shadow',
        jobSpec = 'kagemusha',
        effects = { xi.effect.YONIN, xi.effect.FUTAE, xi.effect.COPY_IMAGE, xi.effect.ISSEKIGAN, 846 },
    },
    bishop = {
        label   = 'Solace/Veil',
        jobSpec = 'bishop',
        effects = { xi.effect.AFFLATUS_SOLACE, xi.effect.DIVINE_SEAL, 860, 861, 862 },
    },
    templar = {
        label   = 'Majesty/Aegis',
        jobSpec = 'templar',
        effects = { xi.effect.MAJESTY, xi.effect.DIVINE_SEAL, 863, 864 },
    },
    magus = {
        label   = 'Diffusion/Conduit',
        jobSpec = 'magus',
        effects = { xi.effect.DIFFUSION, xi.effect.AZURE_LORE, 865, 866 },
    },
    vampire = {
        label   = 'Samba/Trance',
        jobSpec = 'vampire',
        effects = { xi.effect.DRAIN_SAMBA, xi.effect.TRANCE, xi.effect.CONTRADANCE, 867, 868 },
    },
    celestial = {
        label    = 'Astral/Sanctuary',
        jobSpec  = 'celestial',
        petAlive = true,
        effects  = { xi.effect.ASTRAL_FLOW, xi.effect.AVATARS_FAVOR, 869, 870 },
    },
    pugilist = {
        label    = 'Tandem/Limiter',
        jobSpec  = 'pugilist',
        petAlive = true,
        effects  = { xi.effect.FIRE_MANEUVER, xi.effect.THUNDER_MANEUVER, xi.effect.WIND_MANEUVER, xi.effect.OVERDRIVE },
    },
    vanguard = {
        label    = 'Bulwark/Maneuver',
        jobSpec  = 'vanguard',
        petAlive = true,
        effects  = { xi.effect.EARTH_MANEUVER, xi.effect.LIGHT_MANEUVER, xi.effect.WATER_MANEUVER, xi.effect.OVERDRIVE },
    },
    animist = {
        label    = 'Maneuver/Aegis',
        jobSpec  = 'animist',
        petAlive = true,
        effects  = { xi.effect.LIGHT_MANEUVER, xi.effect.WATER_MANEUVER, xi.effect.WIND_MANEUVER, xi.effect.EARTH_MANEUVER, xi.effect.OVERDRIVE, 871 },
    },
    verdant = {
        label    = 'Luopan/Canopy',
        jobSpec  = 'verdant',
        petAlive = true,
        effects  = { xi.effect.BOLSTER, 872, 873 },
    },
    wyvernheart = {
        label    = 'Breath/Wyrm',
        jobSpec  = 'wyvernheart',
        petAlive = true,
        effects  = { xi.effect.SPIRIT_SURGE, xi.effect.FLY_HIGH, 874, 875 },
    },
    miragesentinel = {
        label    = 'Fan/Pirouette',
        jobSpec  = 'miragesentinel',
        effects  = { xi.effect.FAN_DANCE, xi.effect.ISSEKIGAN, xi.effect.TRANCE },
    },
    flintlock = {
        label    = 'Deadeye/Trigger',
        jobSpec  = 'flintlock',
        effects  = { xi.effect.CORSAIRS_ROLL, xi.effect.TRIPLE_SHOT },
    },
    buccaneer = {
        label    = 'Galleon/Hull',
        jobSpec  = 'buccaneer',
        effects  = { xi.effect.GALLANTS_ROLL },
    },
    gambler = {
        label    = 'Advantage/Roll',
        jobSpec  = 'gambler',
        effects  = { 884, xi.effect.CORSAIRS_ROLL, xi.effect.SAMURAI_ROLL, xi.effect.CHAOS_ROLL },
    },
    huntsman = {
        label    = 'Apex Bond',
        jobSpec  = 'huntsman',
        petAlive = true,
        effects  = { xi.effect.SHARPSHOT, xi.effect.BARRAGE, xi.effect.CAMOUFLAGE, xi.effect.UNLIMITED_SHOT },
    },
}

local SPEC_META =
{
    commander      = { pfx = 'cmd', pref = 'str', role = 'dps',    tag = 'Banner',   col2 = 'Rally',    t1c3 = 'Tactic',    rmea = 'Signet',      col1 = { 'Order',     'Salvo',     'Decree'    } },
    berserker      = { pfx = 'zrk', pref = 'str', role = 'dps',    tag = 'Fury',     col2 = 'Carnage',  t1c3 = 'Ruin',      rmea = 'Roar',        col1 = { 'Wrath',     'Bloodbath', 'Butchery'  } },
    spartan        = { pfx = 'gld', pref = 'vit', role = 'tank',   tag = 'Spear',    col2 = 'Impaling',  t1c3 = 'Challenge', rmea = 'Crest',       col1 = { 'Brace',     'Pitwall',   'Arena'     } },
    sensei         = { pfx = 'sen', pref = 'vit', role = 'tank',   tag = 'Kata',     col2 = 'Riposte',  t1c3 = 'Form',      rmea = 'Kamae',       col1 = { 'Stance',    'Kataform',  'Dojomaster'} },
    blackbelt      = { pfx = 'bbt', pref = 'dex', role = 'dps',    tag = 'Fist',     col2 = 'Meridian', t1c3 = 'Tempo',     rmea = 'Oath',        col1 = { 'Strike',    'Combo',     'Finisher'  } },
    chiweaver      = { pfx = 'chw', pref = 'mnd', role = 'healer', tag = 'Chi',      col2 = 'Lotus',    t1c3 = 'Chakra',    rmea = 'Mantra',      col1 = { 'Flow',      'Calm',      'Mandala'   }, noMp = true },
    inquisitor     = { pfx = 'inq', pref = 'vit', role = 'tank',   tag = 'Verdict',  col2 = 'Inquest',  t1c3 = 'Edict',     rmea = 'Seal',        col1 = { 'Warding',   'Indict',    'Tribunal'  } },
    spellblade     = { pfx = 'spb', pref = 'int', role = 'dps',    tag = 'Rune',     col2 = 'Sigil',    t1c3 = 'Glyph',     rmea = 'Brand',       col1 = { 'Etching',   'Runesurge', 'Arcflash'  } },
    lifebinder     = { pfx = 'lfb', pref = 'mnd', role = 'healer', tag = 'Pulse',    col2 = 'Sanctum',  t1c3 = 'Grace',     rmea = 'Relicvow',    col1 = { 'Bloom',     'Solace',    'Chalice'   } },
    medic          = { pfx = 'med', pref = 'mnd', role = 'healer', tag = 'Triage',   col2 = 'Eos',      t1c3 = 'Remedy',    rmea = 'Caduceus',    col1 = { 'Aid',       'Panacea',   'Miracle'   }, pet = true },
    sage           = { pfx = 'sag', pref = 'int', role = 'mage',   tag = 'Theorem',  col2 = 'Titania',  t1c3 = 'Axiom',     rmea = 'Codex',       col1 = { 'Formula',   'Proof',     'Cathedra'  }, pet = true },
    necromancer    = { pfx = 'nec', pref = 'int', role = 'mage',   tag = 'Grave',    col2 = 'Ossuary',  t1c3 = 'Curse',     rmea = 'Reliquary',   col1 = { 'Hex',       'Blight',    'Sepulcher' }, pet = true },
    bladewheel     = { pfx = 'blw', pref = 'dex', role = 'dps',    tag = 'Waltz',    col2 = 'Chakram',  t1c3 = 'Step',      rmea = 'Ovation',     col1 = { 'Twirl',     'Spin',      'Crescendo' } },
    ronin          = { pfx = 'ron', pref = 'vit', role = 'tank',   tag = 'Mushin',   col2 = 'Seigan',   t1c3 = 'Poise',     rmea = 'Stillness',   col1 = { 'Guard',     'Purify',    'Ward'      } },
    imperialarcher = { pfx = 'imp', pref = 'agi', role = 'dps',    tag = 'Oisoya',   col2 = 'Quiver',   t1c3 = 'Volley',    rmea = 'Elucidate',   col1 = { 'Draw',      'Salvo',     'Starfall'  } },
    warlord        = { pfx = 'wrl', pref = 'str', role = 'dps',    tag = 'Iaijutsu', col2 = 'Onimaru',  t1c3 = 'Rend',      rmea = 'Bloodquench', col1 = { 'Cut',       'Sever',     'Ashura'    } },
    aegistemplar   = { pfx = 'aeg', pref = 'vit', role = 'tank',   tag = 'Bastion',  col2 = 'Aegis',    t1c3 = 'Zeal',      rmea = 'Sanctum',     col1 = { 'Bulwark',   'Intercept', 'Judgment'  } },
    kurogane       = { pfx = 'krg', pref = 'dex', role = 'dps', tag = 'Clone', col2 = 'Shadow', t1c3 = 'Flurry', rmea = 'Legion', col1 = { 'Assault', 'Phantom', 'Afterimage' } },
    kagemusha      = { pfx = 'kag', pref = 'agi', role = 'tank',   tag = 'Phantom',  col2 = 'Decoy',    t1c3 = 'Smokescreen', rmea = 'Substitution', col1 = { 'Shadow',   'Veil',      'Shroud'    } },
    bishop         = { pfx = 'bsh', pref = 'mnd', role = 'healer', tag = 'Solace',   col2 = 'Veil',     t1c3 = 'Grace',       rmea = 'Benediction',  col1 = { 'Ward',     'Sanctum',   'Mercy'     } },
    templar        = { pfx = 'tmp', pref = 'mnd', role = 'healer', tag = 'Majesty',  col2 = 'Beacon',   t1c3 = 'Radiance',    rmea = 'Crusade',      col1 = { 'Light',    'Chivalry',  'Bastion'   } },
    magus          = { pfx = 'mag', pref = 'mnd', role = 'healer', tag = 'Catalyst', col2 = 'Osmosis',  t1c3 = 'Azure',       rmea = 'Diffusion',    col1 = { 'Siphon',   'Surge',     'Conduit'   } },
    vampire        = { pfx = 'vmp', pref = 'chr', role = 'healer', tag = 'Crimson',  col2 = 'Samba',    t1c3 = 'Waltz',       rmea = 'Nocturne',     col1 = { 'Drain',    'Blossom',   'Feast'     } },
    celestial      = { pfx = 'cel', pref = 'mnd', role = 'healer', tag = 'Astral',   col2 = 'Starlight',t1c3 = 'Ward',        rmea = 'Convergence',  col1 = { 'Avatar',   'Ruby',      'Siphon'    }, pet = true },
    pugilist       = { pfx = 'pgl', pref = 'str', role = 'dps',    tag = 'Tandem',   col2 = 'Barrage',  t1c3 = 'Limiter',     rmea = 'Overdrive',    col1 = { 'Piston',   'Sync',      'Combo'     }, pet = true, noMp = true },
    vanguard       = { pfx = 'vng', pref = 'vit', role = 'tank',   tag = 'Bulwark',  col2 = 'Alloy',    t1c3 = 'Hydraulic',   rmea = 'Ventriloquy',  col1 = { 'Chassis',  'Plating',   'Guard'     }, pet = true, noMp = true },
    animist        = { pfx = 'anm', pref = 'mnd', role = 'healer', tag = 'Aether',   col2 = 'Clockwork',t1c3 = 'Repair',      rmea = 'Overhaul',     col1 = { 'Fiber',    'Pulse',     'Chassis'   }, pet = true, noMp = true },
    verdant        = { pfx = 'vrd', pref = 'mnd', role = 'healer', tag = 'Sylvan',   col2 = 'Luopan',   t1c3 = 'Bloom',       rmea = 'Canopy',       col1 = { 'Barkskin', 'Renewal',   'Grove'     }, pet = true },
    wyvernheart    = { pfx = 'wyv', pref = 'mnd', role = 'healer', tag = 'Wyrm',     col2 = 'Breath',   t1c3 = 'Scale',       rmea = 'Wyrmblood',    col1 = { 'Link',     'Jump',      'Sanctuary' }, pet = true },
    miragesentinel = { pfx = 'mrs', pref = 'vit', role = 'tank',   tag = 'Mirage',   col2 = 'Waltz',    t1c3 = 'Cadence',     rmea = 'Pirouette',    col1 = { 'Step',     'Flourish',  'Aegis'     } },
    flintlock      = { pfx = 'flt', pref = 'agi', role = 'dps',    tag = 'Deadeye',  col2 = 'Powder',   t1c3 = 'Trigger',     rmea = 'Broadside',    col1 = { 'Chamber',  'Salvo',     'Detonate'  } },
    buccaneer      = { pfx = 'buc', pref = 'vit', role = 'tank',   tag = 'Galleon',  col2 = 'Pistol',   t1c3 = 'Grapeshot',   rmea = 'Ironhull',     col1 = { 'Board',    'Saltward',  'Broadside' } },
    gambler        = { pfx = 'gmb', pref = 'chr', role = 'support',tag = 'Fortune',  col2 = 'Ante',     t1c3 = 'Deal',        rmea = 'Jackpot',      col1 = { 'Wager',    'DoubleUp',  'Highroll'  } },
    huntsman       = { pfx = 'hnt', pref = 'agi', role = 'support',tag = 'Apex',     col2 = 'Primeval', t1c3 = 'Quiver',      rmea = 'Predator',     col1 = { 'Tusk',     'Talon',     'Pack'      }, pet = true },
    generic        = { pfx = 'gen', pref = nil,   role = 'dps',    tag = 'Edge',     col2 = 'Force',    t1c3 = 'Focus',     rmea = 'Echo',        col1 = { 'Surge',     'Strike',    'Apex'      } },
}

local function makeStanceTable(specKey, fields)
    local def = STANCE_DEFS[specKey] or STANCE_DEFS.berserker
    local st =
    {
        effects  = def.effects,
        jobSpec  = def.jobSpec,
        schSpec  = def.schSpec,
        petAlive = def.petAlive,
        localVar = def.localVar,
    }
    for k, v in pairs(fields or {}) do
        st[k] = v
    end
    return st, def.label
end

local function addAccOrRacc(eff, ctx, tbl)
    if ctx.isRanged then
        eff.racc = tbl
    else
        eff.acc = tbl
    end
    return ctx.isRanged and 'R.Acc' or 'Acc'
end

local function makeHitSequence(targetHits, maxRank)
    local th = math.max(2, math.min(7, targetHits))
    local out = {}
    for r = 1, maxRank do
        out[r] = math.min(th, 1 + math.max(1, math.ceil((th - 1) * (r / maxRank))))
    end
    return out, th
end

-----------------------------------
-- Tier 1 Bespoke Builders (T1C1 fTP + Rider, T1C2 WSC + Spec Core, T1C3 WS Trait)
-----------------------------------
local function buildT1C1(specKey, ctx)
    local meta = SPEC_META[specKey]
    local name = string.format('%s %s', ctx.motif, meta.tag)

    if ctx.isUtil then
        if ctx.wsId == 39 then -- Spirits Within (Breath HP scaling)
            local c = { 1.25, 1.85, 2.60 }
            if specKey == 'spartan' then
                return mkFtpNode(name, c, ' & +1..6% HP/+Enm',
                    function(r) return string.format(', +%d%% HP/+%d Enm', r, r * 6) end,
                    { selfMaxHpHealPct = lin(1, 6), enmity = lin(6, 6) })
            elseif specKey == 'sensei' or specKey == 'ronin' or specKey == 'kagemusha' then
                return mkFtpNode(name, c, ' & +5..30 Enm/+SB',
                    function(r) return string.format(', +%d Enm/+%d SB', r * 5, r * 3) end,
                    { enmity = lin(5, 6), subtleBlow = lin(3, 6) })
            elseif specKey == 'inquisitor' or specKey == 'aegistemplar' then
                return mkFtpNode(name, c, ' & +7..42 Enmity',
                    function(r) return string.format(', +%d Enm', r * 7) end,
                    { enmity = lin(7, 6) })
            elseif meta.role == 'healer' then
                return mkFtpNode(name, c, ' & +4..24 Subtle Blow',
                    function(r) return string.format(', +%d SB', r * 4) end,
                    { subtleBlow = lin(4, 6) })
            end
            return mkFtpNode(name, c, ' & +45..270 TP Bonus',
                function(r) return string.format(', +%d TP', r * 45) end,
                { tpBonus = lin(45, 6) })
        end

        -- Pure Utility WSs (Starlight, Moonlight, Dagan, Myrkr, Energy Steal/Drain)
        if specKey == 'chiweaver' then
            local h = { 2, 4, 6, 8, 10, 12 }
            local p = lin(20, 6)
            return mkNode(1, 1, 'ftp', name, 6,
                'Self Heal 2..12% Max HP & +20..120 Party TP',
                function(r) return string.format('Self +%d%% HP, +%d Party TP', h[r], p[r]) end,
                { selfMaxHpHealPct = h, partyTp = p })
        elseif specKey == 'spartan' then
            return mkNode(1, 1, 'ftp', name, 6,
                '+12..72% Potency & Self +1..6% Max HP',
                function(r) return string.format('+%d%% Potency, Self +%d%% HP', r * 12, r) end,
                { potencyPct = lin(12, 6), selfMaxHpHealPct = lin(1, 6), enmity = lin(5, 6) })
        elseif specKey == 'sensei' or specKey == 'ronin' or specKey == 'kagemusha' then
            return mkNode(1, 1, 'ftp', name, 6,
                '+12..72% Potency, +5..30 Enm & +3..18 SB',
                function(r) return string.format('+%d%% Pot, +%d Enm/+%d SB', r * 12, r * 5, r * 3) end,
                { potencyPct = lin(12, 6), enmity = lin(5, 6), subtleBlow = lin(3, 6) })
        elseif specKey == 'inquisitor' or specKey == 'aegistemplar' then
            return mkNode(1, 1, 'ftp', name, 6,
                '+12..72% Potency & +7..42 Enmity',
                function(r) return string.format('+%d%% Potency, +%d Enmity', r * 12, r * 7) end,
                { potencyPct = lin(12, 6), enmity = lin(7, 6) })
        elseif specKey == 'lifebinder' then
            return mkNode(1, 1, 'ftp', name, 6,
                '+14..84% Potency & Party +1..6% Max HP',
                function(r) return string.format('+%d%% Potency, Pty +%d%% HP', r * 14, r) end,
                { potencyPct = lin(14, 6), partyHealPct = lin(1, 6) })
        elseif specKey == 'medic' then
            return mkNode(1, 1, 'ftp', name, 6,
                '+14..84% Potency & Eos Heal 3..18%',
                function(r) return string.format('+%d%% Potency, Eos +%d%% HP', r * 14, r * 3) end,
                { potencyPct = lin(14, 6), eosHeal = lin(3, 6) })
        elseif specKey == 'commander' then
            return mkNode(1, 1, 'ftp', name, 6,
                '+14..84% Potency & +20..120 Party TP',
                function(r) return string.format('+%d%% Potency, +%d Party TP', r * 14, r * 20) end,
                { potencyPct = lin(14, 6), partyTp = lin(20, 6) })
        end
        return mkNode(1, 1, 'ftp', name, 6,
            '+15..90% Potency & +45..270 TP Bonus',
            function(r) return string.format('+%d%% Potency, +%d TP Bonus', r * 15, r * 45) end,
            { potencyPct = lin(15, 6), tpBonus = lin(45, 6) })
    end

    local c = ctx.ftpCurve
    if specKey == 'spartan' then
        return mkFtpNode(name, c, ' & +6..36 Enm/+HP',
            function(r) return string.format(', +%d Enm/+%d%% HP', r * 6, math.ceil(r / 2)) end,
            { enmity = lin(6, 6), selfMaxHpHealPct = { 1, 1, 2, 2, 3, 3 } })
    elseif specKey == 'inquisitor' then
        return mkFtpNode(name, c, ' & +7..42 Enm/+MACC',
            function(r) return string.format(', +%d Enm/+%d MACC', r * 7, r * 4) end,
            { enmity = lin(7, 6), macc = lin(4, 6) })
    elseif specKey == 'sensei' then
        return mkFtpNode(name, c, ' & +5..30 Enm/+SB',
            function(r) return string.format(', +%d Enm/+%d SB', r * 5, r * 3) end,
            { enmity = lin(5, 6), subtleBlow = lin(3, 6) })
    elseif specKey == 'chiweaver' then
        return mkFtpNode(name, c, ' & +4..24 SB/+PtyTP',
            function(r) return string.format(', +%d SB/+%d PtyTP', r * 4, r * 10) end,
            { subtleBlow = lin(4, 6), partyTp = lin(10, 6) })
    elseif specKey == 'lifebinder' then
        return mkFtpNode(name, c, ' & +4..24 SB/+MACC',
            function(r) return string.format(', +%d SB/+%d MACC', r * 4, r * 5) end,
            { subtleBlow = lin(4, 6), macc = lin(5, 6) })
    elseif specKey == 'medic' then
        return mkFtpNode(name, c, ' & -3..-18 Enm/+Eos',
            function(r) return string.format(', -%d Enm/Eos+%d%%', r * 3, r * 3) end,
            { enmity = lin(-3, 6), eosHeal = lin(3, 6) })
    elseif specKey == 'commander' then
        return mkFtpNode(name, c, ' & +15..90 Party TP',
            function(r) return string.format(', +%d PtyTP', r * 15) end,
            { partyTp = lin(15, 6) })
    elseif specKey == 'spellblade' then
        return mkFtpNode(name, c, ' & +5..30 MAB/+MACC',
            function(r) return string.format(', +%d MAB/+%d MACC', r * 5, r * 5) end,
            { matt = lin(5, 6), macc = lin(5, 6) })
    elseif specKey == 'sage' then
        return mkFtpNode(name, c, ' & +6..36 MAB/+FaeTP',
            function(r) return string.format(', +%d MAB/+%d FaeTP', r * 6, r * 15) end,
            { matt = lin(6, 6), petTp = lin(15, 6) })
    elseif specKey == 'necromancer' then
        return mkFtpNode(name, c, ' & +5..30 MAB/+Drain',
            function(r) return string.format(', +%d MAB/+%d%% Drn', r * 5, r * 2) end,
            { matt = lin(5, 6), hpDrain = lin(2, 6) })
    elseif specKey == 'blackbelt' then
        if ctx.isMag then
            return mkFtpNode(name, c, ' & +5..30 STP/+SB',
                function(r) return string.format(', +%d STP/+%d SB', r * 5, r * 3) end,
                { storeTp = lin(5, 6), subtleBlow = lin(3, 6) })
        end
        local eff = { storeTp = lin(4, 6), subtleBlow = lin(3, 6) }
        local lbl = addAccOrRacc(eff, ctx, lin(5, 6))
        return mkFtpNode(name, c, string.format(' & +5..30 %s/+STP', lbl),
            function(r) return string.format(', +%d %s/+%d STP', r * 5, lbl, r * 4) end,
            eff)
    elseif specKey == 'bladewheel' then
        if ctx.isMag then
            return mkFtpNode(name, c, ' & +5..30 STP/+MACC',
                function(r) return string.format(', +%d STP/+%d MACC', r * 5, r * 5) end,
                { storeTp = lin(5, 6), macc = lin(5, 6) })
        end
        local eff = { storeTp = lin(5, 6) }
        local lbl = addAccOrRacc(eff, ctx, lin(6, 6))
        return mkFtpNode(name, c, string.format(' & +6..36 %s/+STP', lbl),
            function(r) return string.format(', +%d %s/+%d STP', r * 6, lbl, r * 5) end,
            eff)
    elseif specKey == 'imperialarcher' then
        if ctx.isMag then
            return mkFtpNode(name, c, ' & +5..30 STP/+MACC',
                function(r) return string.format(', +%d STP/+%d MACC', r * 5, r * 5) end,
                { storeTp = lin(5, 6), macc = lin(5, 6) })
        elseif ctx.isRanged then
            return mkFtpNode(name, c, ' & +6..36 R.Acc/-Enm',
                function(r) return string.format(', +%d R.Acc/-%d Enm', r * 6, r * 4) end,
                { racc = lin(6, 6), enmity = lin(-4, 6) })
        end
        return mkFtpNode(name, c, ' & +6..36 Acc/+STP',
            function(r) return string.format(', +%d Acc/+%d STP', r * 6, r * 5) end,
            { acc = lin(6, 6), storeTp = lin(5, 6) })
    elseif specKey == 'ronin' or specKey == 'aegistemplar' or specKey == 'kagemusha' then
        return mkFtpNode(name, c, ' & +6..36 Enm/+HP',
            function(r) return string.format(', +%d Enm/+%d%% HP', r * 6, math.ceil(r / 2)) end,
            { enmity = lin(6, 6), selfMaxHpHealPct = { 1, 1, 2, 2, 3, 3 } })
    elseif specKey == 'warlord' then
        if ctx.isMag then
            return mkFtpNode(name, c, ' & +6..36 MAB/+WSD',
                function(r) return string.format(', +%d MAB/+%d%% WSD', r * 6, r * 2) end,
                { matt = lin(6, 6), wsd = lin(2, 6) })
        end
        return mkFtpNode(name, c, ' & +4..24% Atk/+CrDmg',
            function(r) return string.format(', +%d%% Atk/+%d%% CrDmg', r * 4, r * 3) end,
            { atkPct = lin(4, 6), critDmg = lin(3, 6) })
    end

    -- berserker
    if ctx.isMag then
        return mkFtpNode(name, c, ' & +6..36 MAB',
            function(r) return string.format(', +%d MAB', r * 6) end,
            { matt = lin(6, 6) })
    end
    return mkFtpNode(name, c, ' & +5..30% Atk',
        function(r) return string.format(', +%d%% Atk', r * 5) end,
        { atkPct = lin(5, 6) })
end

local function buildWscEffect(ctx, prefStat)
    local s1 = ctx.stat1 or prefStat or 'str'
    local s2 = prefStat or ctx.stat2
    if s2 == s1 then
        s2 = ctx.stat2
    end
    if ctx.isUtil then
        return { mnd = lin(0.10, 7) }, 'MND', nil
    end
    if s2 and s2 ~= s1 then
        return { [s1] = lin(0.09, 7), [s2] = lin(0.06, 7) }, STAT_UP[s1], STAT_UP[s2]
    end
    return { [s1] = lin(0.12, 7) }, STAT_UP[s1], nil
end

local function fmtWscShort(u1, u2, r)
    if u2 then
        return string.format('%s +%d%%/%s +%d%%', u1, r * 9, u2, r * 6)
    end
    return string.format('%s +%d%% WSC', u1, r * 12)
end

local function fmtWscZero(u1, u2)
    if u2 then
        return string.format('%s/%s WSC', u1, u2)
    end
    return string.format('%s +12..84%% WSC', u1)
end

local function buildT1C2(specKey, ctx)
    local meta = SPEC_META[specKey]
    local key  = meta.pfx .. '_t1c2'
    local name = string.format('%s %s', ctx.noun, meta.col2)
    local wsc, u1, u2 = buildWscEffect(ctx, meta.pref)
    local wz = fmtWscZero(u1, u2)

    if specKey == 'commander' then
        local p = lin(20, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +20..140 Party TP', wz),
            function(r) return string.format('%s, +%d PtyTP', fmtWscShort(u1, u2, r), p[r]) end,
            { wsc = wsc, partyTp = p })

    elseif specKey == 'spartan' then
        local h = { 2, 3, 5, 6, 8, 10, 12 }
        return mkNode(1, 2, key, name, 7,
            string.format('%s & Heal 2..12%% Max HP', wz),
            function(r) return string.format('%s, +%d%% MaxHP', fmtWscShort(u1, u2, r), h[r]) end,
            { wsc = wsc, selfMaxHpHealPct = h })

    elseif specKey == 'sensei' then
        local ctr = lin(2, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +2..14%% Counter (15s)', wz),
            function(r) return string.format('%s, +%d%% Counter', fmtWscShort(u1, u2, r), ctr[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 15, mods = {{ mod = xi.mod.COUNTER, val = ctr }} } })

    elseif specKey == 'blackbelt' then
        if ctx.isPhys and ctx.numHits >= 2 then
            local hSeq, th = makeHitSequence(ctx.numHits, 7)
            return mkNode(1, 2, key, name, 7,
                string.format('1->%d Hits & %s', th, wz),
                function(r) return string.format('1->%dh, %s', hSeq[r], fmtWscShort(u1, u2, r)) end,
                { hits = hSeq, wsc = wsc })
        end
        local kr = lin(3, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +3..21%% Kick Rate (12s)', wz),
            function(r) return string.format('%s, +%d%% Kick', fmtWscShort(u1, u2, r), kr[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.POTENCY, duration = 12, mods = {{ mod = xi.mod.KICK_ATTACK_RATE, val = kr }} } })

    elseif specKey == 'chiweaver' then
        local cb = lin(8, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & Chi Blast +8..56%% Dmg', wz),
            function(r) return string.format('%s, Chi +%d%%', fmtWscShort(u1, u2, r), cb[r]) end,
            { wsc = wsc, chiBlast = { pct = cb } })

    elseif specKey == 'inquisitor' then
        local pry = lin(2, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +2..14%% Parry (15s)', wz),
            function(r) return string.format('%s, +%d%% Parry', fmtWscShort(u1, u2, r), pry[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 15, mods = {{ mod = xi.mod.INQUARTATA, val = pry }} } })

    elseif specKey == 'spellblade' then
        local cond = { 1, 1, 1, 2, 2, 2, 3 }
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +1..3 Conduction', wz),
            function(r) return string.format('%s, +%d Conduct', fmtWscShort(u1, u2, r), cond[r]) end,
            { wsc = wsc, conductionAdd = cond })

    elseif specKey == 'lifebinder' then
        local ph = { 2, 3, 4, 6, 7, 9, 11 }
        return mkNode(1, 2, key, name, 7,
            string.format('%s & Party Heal 2..11%% HP', wz),
            function(r) return string.format('%s, Pty +%d%% HP', fmtWscShort(u1, u2, r), ph[r]) end,
            { wsc = wsc, partyHealPct = ph })

    elseif specKey == 'medic' then
        local eh = lin(4, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & Eos Heal 4..28%% HP/MP', wz),
            function(r) return string.format('%s, Eos +%d%%', fmtWscShort(u1, u2, r), eh[r]) end,
            { wsc = wsc, eosHeal = eh })

    elseif specKey == 'sage' then
        local ptp = lin(25, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +25..175 Titania TP', wz),
            function(r) return string.format('%s, Fae +%d TP', fmtWscShort(u1, u2, r), ptp[r]) end,
            { wsc = wsc, petTp = ptp, macc = lin(5, 7) })

    elseif specKey == 'necromancer' then
        local eh  = lin(4, 7)
        local ptp = lin(25, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & Undead +4..28%% HP/+TP', wz),
            function(r) return string.format('%s, Pet +%d%%HP', fmtWscShort(u1, u2, r), eh[r]) end,
            { wsc = wsc, eosHeal = eh, petTp = ptp })

    elseif specKey == 'bladewheel' then
        local eva = lin(5, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +5..35 EVA (15s)', wz),
            function(r) return string.format('%s, +%d EVA', fmtWscShort(u1, u2, r), eva[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.EVA, val = eva }} } })

    elseif specKey == 'imperialarcher' then
        if ctx.isRanged then
            local atk = lin(4, 7)
            local zan = lin(4, 7)
            local rName = string.format('%s Brand', ctx.noun)
            return mkNode(1, 2, key, rName, 7,
                string.format('%s & +4..28%% Atk/+Zan (15s)', wz),
                function(r) return string.format('%s, +%d%% Atk/+%d Zan', fmtWscShort(u1, u2, r), atk[r], zan[r]) end,
                { wsc = wsc, postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.ATTP, val = atk }, { mod = xi.mod.ZANSHIN, val = zan }} } })
        end
        local ratk = lin(4, 7)
        local snap = lin(2, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +4..28%% R.Atk/+Snap (15s)', wz),
            function(r) return string.format('%s, +%d%% R.Atk/+%d%% Snap', fmtWscShort(u1, u2, r), ratk[r], snap[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.RATTP, val = ratk }, { mod = xi.mod.SNAPSHOT, val = snap }} } })

    elseif specKey == 'ronin' or specKey == 'aegistemplar' or specKey == 'kagemusha' then
        local pry = lin(2, 7)
        local ctr = lin(2, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +2..14%% Parry/Counter (15s)', wz),
            function(r) return string.format('%s, +%d%% Pry/Ctr', fmtWscShort(u1, u2, r), pry[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 15, mods = {{ mod = xi.mod.PARRY, val = pry }, { mod = xi.mod.COUNTER, val = ctr }} } })

    elseif specKey == 'warlord' then
        local zan = lin(4, 7)
        local crt = lin(2, 7)
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +4..28 Zan/+2..14%% Crit (15s)', wz),
            function(r) return string.format('%s, +%d Zan/+%d%% Crit', fmtWscShort(u1, u2, r), zan[r], crt[r]) end,
            { wsc = wsc, postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.ZANSHIN, val = zan }, { mod = xi.mod.CRITHITRATE, val = crt }} } })
    end

    -- berserker (used on Club/Staff full builds)
    if ctx.isMag or ctx.isUtil then
        return mkNode(1, 2, key, name, 7,
            string.format('%s & +6..42 MAB', wz),
            function(r) return string.format('%s, +%d MAB', fmtWscShort(u1, u2, r), r * 6) end,
            { wsc = wsc, matt = lin(6, 7) })
    end
    return mkNode(1, 2, key, name, 7,
        string.format('%s & +6..42%% WS Atk', wz),
        function(r) return string.format('%s, +%d%% Atk', fmtWscShort(u1, u2, r), r * 6) end,
        { wsc = wsc, atkPct = lin(6, 7) })
end

local function buildT1C3(specKey, ctx)
    local meta = SPEC_META[specKey]
    local key  = meta.pfx .. '_t1c3'
    local name = string.format('%s %s', ctx.motif, meta.t1c3)

    -- 1. Multi-hit physical rebuild (except blackbelt which already placed hits in T1C2)
    if ctx.isPhys and ctx.numHits >= 2 and specKey ~= 'blackbelt' then
        local hSeq, th = makeHitSequence(ctx.numHits, 7)
        if specKey == 'spartan' then
            return mkNode(1, 3, key, name, 7,
                string.format('1->%d Hits, +5..35 Enm & +HP', th),
                function(r) return string.format('1->%dh, +%d Enm, +%d%% HP', hSeq[r], r * 5, math.ceil(r / 2)) end,
                { hits = hSeq, enmity = lin(5, 7), selfMaxHpHealPct = { 1, 1, 2, 2, 3, 3, 4 } })
        elseif specKey == 'sensei' or specKey == 'ronin' or specKey == 'kagemusha' then
            return mkNode(1, 3, key, name, 7,
                string.format('1->%d Hits, +4..28 Enm & +SB', th),
                function(r) return string.format('1->%dh, +%d Enm, +%d SB', hSeq[r], r * 4, r * 3) end,
                { hits = hSeq, enmity = lin(4, 7), subtleBlow = lin(3, 7) })
        elseif specKey == 'inquisitor' or specKey == 'aegistemplar' then
            return mkNode(1, 3, key, name, 7,
                string.format('1->%d Hits, +6..42 Enm & +MACC', th),
                function(r) return string.format('1->%dh, +%d Enm, +%d MACC', hSeq[r], r * 6, r * 4) end,
                { hits = hSeq, enmity = lin(6, 7), macc = lin(4, 7) })
        elseif specKey == 'chiweaver' then
            return mkNode(1, 3, key, name, 7,
                string.format('1->%d Hits, +4..28 SB & +PtyTP', th),
                function(r) return string.format('1->%dh, +%d SB, +%d PtyTP', hSeq[r], r * 4, r * 10) end,
                { hits = hSeq, subtleBlow = lin(4, 7), partyTp = lin(10, 7) })
        elseif specKey == 'lifebinder' then
            return mkNode(1, 3, key, name, 7,
                string.format('1->%d Hits, +3..21 SB & Pty HP', th),
                function(r) return string.format('1->%dh, +%d SB, Pty +%d%% HP', hSeq[r], r * 3, math.ceil(r / 2)) end,
                { hits = hSeq, subtleBlow = lin(3, 7), partyHealPct = { 1, 1, 2, 2, 3, 3, 4 } })
        elseif specKey == 'medic' then
            return mkNode(1, 3, key, name, 7,
                string.format('1->%d Hits, +3..21 SB & Eos HP', th),
                function(r) return string.format('1->%dh, +%d SB, Eos +%d%% HP', hSeq[r], r * 3, r * 3) end,
                { hits = hSeq, subtleBlow = lin(3, 7), eosHeal = lin(3, 7) })
        end
        local eff = { hits = hSeq }
        local lbl = addAccOrRacc(eff, ctx, lin(6, 7))
        return mkNode(1, 3, key, name, 7,
            string.format('1->%d Hits & +6..42 %s', th, lbl),
            function(r) return string.format('Hits: 1->%d, +%d %s', hSeq[r], r * 6, lbl) end,
            eff)
    end

    -- 2. Native WS debuff amplifier (on enemy-targeted WSs with native debuffs)
    if ctx.debuff ~= nil and not ctx.isSelfUtil then
        if meta.role == 'tank' then
            return mkNode(1, 3, key, name, 7,
                string.format('Boosts %s, +8..56 MACC & Enm', ctx.debuff.label),
                function(r) return string.format('%s R%d, +%d MACC/+%d Enm', ctx.debuff.label, r, r * 8, r * 5) end,
                { nativeDebuff = lin(1, 7), macc = lin(8, 7), enmity = lin(5, 7) })
        elseif meta.role == 'healer' then
            return mkNode(1, 3, key, name, 7,
                string.format('Boosts %s, +9..63 MACC & SB', ctx.debuff.label),
                function(r) return string.format('%s R%d, +%d MACC/+%d SB', ctx.debuff.label, r, r * 9, r * 3) end,
                { nativeDebuff = lin(1, 7), macc = lin(9, 7), subtleBlow = lin(3, 7) })
        end
        return mkNode(1, 3, key, name, 7,
            string.format('Boosts %s, +8..56 MACC & +3..21%% WSD', ctx.debuff.label),
            function(r) return string.format('%s R%d, +%d MACC, +%d%% WSD', ctx.debuff.label, r, r * 8, r * 3) end,
            { nativeDebuff = lin(1, 7), macc = lin(8, 7), wsd = lin(3, 7) })
    end

    -- 3. Self-targeted utility WSs (Starlight, Moonlight, Dagan, Myrkr)
    if ctx.isSelfUtil then
        if specKey == 'chiweaver' then
            local cb = lin(4, 7)
            return mkNode(1, 3, key, name, 7,
                'Chi Blast -4..28s CD & +50..350 TP Bonus',
                function(r) return string.format('-%ds Chi CD, +%d TP Bonus', cb[r], r * 50) end,
                { chiBlast = { cdTrim = cb }, tpBonus = lin(50, 7) })
        elseif meta.role == 'tank' then
            local ss = lin(55, 7)
            return mkNode(1, 3, key, name, 7,
                'Stoneskin 55..385 & +6..42 Enmity',
                function(r) return string.format('Stoneskin %d, +%d Enmity', ss[r], r * 6) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = ss, duration = 45, tier = 3 }}, enmity = lin(6, 7) })
        end
        return mkNode(1, 3, key, name, 7,
            'Next WS +4..28% WSD & +50..350 TP Bonus',
            function(r) return string.format('NextWS +%d%% WSD, +%d TP', r * 4, r * 50) end,
            { nextWs = { wsd = lin(4, 7), dur = 15 }, tpBonus = lin(50, 7) })
    end

    -- 4. Pack AoE WSs
    if ctx.aoe then
        if meta.role == 'tank' then
            return mkNode(1, 3, key, name, 7,
                '+7..49 Enmity/Extra Mob & +3..21% WSD',
                function(r) return string.format('+%d Enm/Mob, +%d%% WSD', r * 7, r * 3) end,
                { packEnmityPerMob = lin(7, 7), wsd = lin(3, 7) })
        elseif meta.role == 'healer' then
            local psh = { 1, 1, 2, 2, 3, 3, 4 }
            return mkNode(1, 3, key, name, 7,
                '+1..4% Self HP/Extra Mob & +4..28 SB',
                function(r) return string.format('+%d%% HP/Mob, +%d SB', psh[r], r * 4) end,
                { packSelfHealPerMob = psh, subtleBlow = lin(4, 7) })
        elseif specKey == 'commander' then
            return mkNode(1, 3, key, name, 7,
                '+15..105 Party TP/Mob & +4..28% WSD',
                function(r) return string.format('+%d PtyTP/Mob, +%d%% WSD', r * 15, r * 4) end,
                { packPartyTpPerMob = lin(15, 7), wsd = lin(4, 7) })
        end
        return mkNode(1, 3, key, name, 7,
            '+4..28% WSD per Extra Mob & +3..21% WSD',
            function(r) return string.format('+%d%% Pack WSD/Mob, +%d%% WSD', r * 4, r * 3) end,
            { packWsdPerMob = lin(4, 7), wsd = lin(3, 7) })
    end

    -- 5. Magic / Hybrid / Utility (enemy-targeted)
    if ctx.isMag or ctx.isUtil then
        if meta.role == 'tank' then
            return mkNode(1, 3, key, name, 7,
                '+7..49 MACC & Target -3..21% M.Atk',
                function(r) return string.format('+%d MACC, Foe -%d%% M.Atk', r * 7, r * 3) end,
                { macc = lin(7, 7), targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = lin(3, 7), duration = 45 }} })
        elseif meta.role == 'healer' then
            return mkNode(1, 3, key, name, 7,
                '+6..42 MAB, +7..49 MACC & +3..21 SB',
                function(r) return string.format('+%d MAB, +%d MACC, +%d SB', r * 6, r * 7, r * 3) end,
                { matt = lin(6, 7), macc = lin(7, 7), subtleBlow = lin(3, 7) })
        end
        return mkNode(1, 3, key, name, 7,
            '+7..49 MAB & +8..56 MACC on WS',
            function(r) return string.format('+%d MAB, +%d MACC', r * 7, r * 8) end,
            { matt = lin(7, 7), macc = lin(8, 7) })
    end

    -- 6. Physical / Ranged role-driven T1C3
    if meta.role == 'tank' then
        local eff = { enmity = lin(6, 7), targetDebuffs = {{ effect = xi.effect.ATTACK_DOWN, power = lin(3, 7), duration = 45 }} }
        local lbl = addAccOrRacc(eff, ctx, lin(6, 7))
        return mkNode(1, 3, key, name, 7,
            string.format('+6..42 %s, +Enm & Foe -3..21%% Atk', lbl),
            function(r) return string.format('+%d %s, +%d Enm, -%d%% Atk', r * 6, lbl, r * 6, r * 3) end,
            eff)
    elseif meta.role == 'healer' then
        local eff = { subtleBlow = lin(4, 7) }
        local lbl = addAccOrRacc(eff, ctx, lin(7, 7))
        return mkNode(1, 3, key, name, 7,
            string.format('+7..49 %s & +4..28 Subtle Blow', lbl),
            function(r) return string.format('+%d %s, +%d Subtle Blow', r * 7, lbl, r * 4) end,
            eff)
    elseif ctx.role == 'breach' or ctx.role == 'crash' or ctx.role == 'relic' then
        local eff = { defIgnore = lin(0.05, 7) }
        local lbl = addAccOrRacc(eff, ctx, lin(6, 7))
        return mkNode(1, 3, key, name, 7,
            string.format('Ignores 5..35%% DEF & +6..42 %s', lbl),
            function(r) return string.format('-%d%% DEF Ign, +%d %s', r * 5, r * 6, lbl) end,
            eff)
    end

    local eff = { atkPct = lin(5, 7) }
    local lbl = addAccOrRacc(eff, ctx, lin(7, 7))
    return mkNode(1, 3, key, name, 7,
        string.format('+5..35%% Atk & +7..49 %s', lbl),
        function(r) return string.format('+%d%% Atk, +%d %s', r * 5, r * 7, lbl) end,
        eff)
end

-----------------------------------
-- Column 1 (T2C1, T3C1, T4C1 Capstone) — WS Tactical Role x Spec Identity
-----------------------------------
local function buildCol1Nodes(specKey, ctx)
    local meta = SPEC_META[specKey]
    local pfx  = meta.pfx
    local m    = ctx.motif
    local n    = ctx.noun
    local role = ctx.role
    local ele  = ctx.ele
    local elLb = ctx.eleLabel

    local k2, k3, k4   = pfx .. '_t2c1', pfx .. '_t3c1', 'capstone'
    local c1_2, c1_3, c1_4 = m .. ' ' .. meta.col1[1], n .. ' ' .. meta.col1[2], m .. ' ' .. meta.col1[3]

    -- Helper for tank T2/T3/T4
    if meta.role == 'tank' then
        local t2, t3, t4
        if role == 'opener' or role == 'flurry' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Next WS +5..25% WSD & +8..40 Enmity',
                function(r) return string.format('NextWS +%d%% WSD, +%d Enm', r * 5, r * 8) end,
                { nextWs = { wsd = lin(5, 5), dur = 15 }, enmity = lin(8, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Stoneskin 80..400 & +5..25% WSD',
                function(r) return string.format('Stoneskin %d, +%d%% WSD', r * 80, r * 5) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 45, tier = 3 }}, wsd = lin(5, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Phalanx 16..32, +10..30% WSD & +15..45 Enm',
                function(r) return string.format('Phalanx %d, +%d%% WSD, +%d Enm', 8 + r * 8, r * 10, r * 15) end,
                { statusBuffs = {{ effect = xi.effect.PHALANX, power = { 16, 24, 32 }, duration = 45 }}, wsd = lin(10, 3), enmity = lin(15, 3) })

        elseif role == 'stun' or role == 'siphon' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Drains 70..350 Foe TP & +8..40 Enmity',
                function(r) return string.format('Drain %d TP, +%d Enmity', r * 70, r * 8) end,
                { tpDrain = lin(70, 5), enmity = lin(8, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Dispels 1..2 Buffs & Foe -4..20% Atk/M.Atk',
                function(r) return string.format('Dispel %d, Foe -%d%% Atk/MAtk', r >= 4 and 2 or 1, r * 4) end,
                { dispel = { 1, 1, 1, 2, 2 }, targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Foe Slow 15..25% & Heal 5..15% Max HP',
                function(r) return string.format('Foe Slow %d%%, Heal %d%% HP', 10 + r * 5, r * 5) end,
                { targetDebuffs = {{ effect = xi.effect.SLOW, power = { 1500, 2000, 2500 }, duration = 45 }}, selfMaxHpHealPct = { 5, 10, 15 } })

        elseif role == 'breach' or role == 'crash' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Target DEF/MDEF -4..20% & +7..35 Enmity',
                function(r) return string.format('Foe -%d%% DEF/MDEF, +%d Enm', r * 4, r * 7) end,
                { enmity = lin(7, 5), targetDebuffs = {
                    { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Phalanx 10..30 (30s) & +5..25% WSD',
                function(r) return string.format('Phalanx %d, +%d%% WSD', 5 + r * 5, r * 5) end,
                { statusBuffs = {{ effect = xi.effect.PHALANX, power = { 10, 15, 20, 25, 30 }, duration = 30 }}, wsd = lin(5, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Stoneskin 180..420 & +12..36% WSD',
                function(r) return string.format('Stoneskin %d, +%d%% WSD', 60 + r * 120, r * 12) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 180, 300, 420 }, duration = 60, tier = 3 }}, wsd = lin(12, 3) })

        elseif role == 'aoe' or role == 'wave' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Foe -7..35 Acc/MACC & +8..40 Enmity',
                function(r) return string.format('Foe -%d Acc/MACC, +%d Enm', r * 7, r * 8) end,
                { enmity = lin(8, 5), targetDebuffs = {
                    { effect = xi.effect.ACCURACY_DOWN, power = lin(7, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ACC_DOWN, power = lin(7, 5), duration = 45 },
                } })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                string.format('%s Follow-Up (5..25%%) & +2..10%% Self HP', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% MaxHP', elLb, r * 5, r * 2) end,
                { elemFollow = { ele = ele, pct = lin(5, 5), scaleWithPack = ctx.aoe }, selfMaxHpHealPct = lin(2, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Party Defender/Protect & +12..36% WSD',
                function(r) return string.format('Party Protect, +%d%% WSD', r * 12) end,
                { partyBuffs = {{ effect = xi.effect.PROTECT, power = { 45, 70, 95 }, duration = 60 }}, wsd = lin(12, 3) })

        else -- vital, lunge, restore, relic
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Self Heal 2..10% Max HP & +8..40 Enmity',
                function(r) return string.format('Self +%d%% MaxHP, +%d Enm', r * 2, r * 8) end,
                { selfMaxHpHealPct = lin(2, 5), enmity = lin(8, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Cleanse 1 Debuff, +5..25% WSD & +6..30 SB',
                function(r) return string.format('Cleanse 1, +%d%% WSD, +%d SB', r * 5, r * 6) end,
                { cleanseSelf = { 1, 1, 1, 1, 1 }, wsd = lin(5, 5), subtleBlow = lin(6, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Stoneskin 200..440, +10..30% SC & +12..36% WSD',
                function(r) return string.format('Skin %d, +%d%% SC/+%d%% WSD', 80 + r * 120, r * 10, r * 12) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 200, 320, 440 }, duration = 60, tier = 3 }}, scBonus = lin(10, 3), wsd = lin(12, 3) })
        end
        return t2, t3, t4
    end

    -- Healer specs (chiweaver, lifebinder, medic)
    if meta.role == 'healer' then
        local t2, t3, t4
        if role == 'opener' or role == 'flurry' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Party Heal 2..10% HP & +15..75 Party TP',
                function(r) return string.format('Party +%d%% HP, +%d PtyTP', r * 2, r * 15) end,
                { partyHealPct = lin(2, 5), partyTp = lin(15, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Party Regen 3..15/t (24s) & +4..20% WSD',
                function(r) return string.format('Party Regen %d/t, +%d%% WSD', r * 3, r * 4) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = lin(3, 5), duration = 24 }}, wsd = lin(4, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Cleanse Party, Party +4..12% HP & +10..30% WSD',
                function(r) return string.format('Cleanse Pty, +%d%% HP, +%d%% WSD', r * 4, r * 10) end,
                { cleanseParty = { 1, 1, 2 }, partyHealPct = { 4, 8, 12 }, wsd = lin(10, 3) })

        elseif role == 'stun' or role == 'breach' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Foe -4..20% Atk/M.Atk & +5..25 Subtle Blow',
                function(r) return string.format('Foe -%d%% Atk/MAtk, +%d SB', r * 4, r * 5) end,
                { subtleBlow = lin(5, 5), targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Dispels 1..2 Foe Buffs & Party +2..10% HP',
                function(r) return string.format('Dispel %d, Party +%d%% HP', r >= 4 and 2 or 1, r * 2) end,
                { dispel = { 1, 1, 1, 2, 2 }, partyHealPct = lin(2, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Drains 120..360 TP, Cleanse Pty & +10..30% WSD',
                function(r) return string.format('-%d Foe TP, Cleanse, +%d%% WSD', r * 120, r * 10) end,
                { tpDrain = lin(120, 3), cleanseParty = { 1, 1, 2 }, wsd = lin(10, 3) })

        elseif role == 'aoe' or role == 'wave' then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                string.format('%s Follow-Up (5..25%%) & Party +2..8%% HP', elLb),
                function(r) return string.format('%s +%d%%, Party +%d%% HP', elLb, r * 5, ({ 2, 3, 5, 6, 8 })[r]) end,
                { elemFollow = { ele = ele, pct = lin(5, 5), scaleWithPack = ctx.aoe }, partyHealPct = { 2, 3, 5, 6, 8 } })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Party Stoneskin 70..350 & +4..20% WSD',
                function(r) return string.format('Party Skin %d, +%d%% WSD', r * 70, r * 4) end,
                { partyBuffs = {{ effect = xi.effect.STONESKIN, power = lin(70, 5), duration = 45 }}, wsd = lin(4, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Party Regen 6..18/t (30s) & +12..36% WSD',
                function(r) return string.format('Party Regen %d/t, +%d%% WSD', r * 6, r * 12) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = { 6, 12, 18 }, duration = 30 }}, wsd = lin(12, 3) })

        else -- vital, lunge, siphon, restore, crash, relic
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Self Heal 3..15% Max HP & +5..25 Subtle Blow',
                function(r) return string.format('Self +%d%% HP, +%d Subtle Blow', r * 3, r * 5) end,
                { selfMaxHpHealPct = lin(3, 5), subtleBlow = lin(5, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Party Heal 2..10% HP & Next WS +5..25% WSD',
                function(r) return string.format('Party +%d%% HP, NextWS +%d%% WSD', r * 2, r * 5) end,
                { partyHealPct = lin(2, 5), nextWs = { wsd = lin(5, 5), dur = 15 } })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                'Party Heal 5..14% HP, +10..30% SC & +10..30% WSD',
                function(r) return string.format('Pty +%d%% HP, +%d%% SC/+%d%% WSD', ({ 5, 9, 14 })[r], r * 10, r * 10) end,
                { partyHealPct = { 5, 9, 14 }, scBonus = lin(10, 3), wsd = lin(10, 3) })
        end
        return t2, t3, t4
    end

    -- Mage / Hybrid DPS specs (spellblade, sage, necromancer) & Physical/Ranged DPS specs (commander, berserker, blackbelt, bladewheel)
    local isCasterSpec = (meta.role == 'mage' or specKey == 'spellblade')
    local t2, t3, t4

    if role == 'opener' then
        t2 = mkNode(2, 1, k2, c1_2, 5,
            'Next WS +6..30% WSD & +60..300 Next-WS TP',
            function(r) return string.format('NextWS +%d%% WSD, +%d TP', r * 6, r * 60) end,
            { nextWs = { wsd = lin(6, 5), tp = lin(60, 5), dur = 15 } })
        t3 = mkNode(3, 1, k3, c1_3, 5,
            'Vs >=70% HP Foe: +7..35% WSD & +5..25 STP',
            function(r) return string.format('Opener +%d%% WSD, +%d STP', r * 7, r * 5) end,
            { openerWsdHighHp = lin(7, 5), storeTp = lin(5, 5) })
        t4 = mkNode(4, 1, k4, c1_4, 3,
            '+12..36% WSD, Next WS +12..36% WSD & +10..30% SC',
            function(r) return string.format('+%d%% WSD, NextWS +%d%%, +%d%% SC', r * 12, r * 12, r * 10) end,
            { wsd = lin(12, 3), nextWs = { wsd = lin(12, 3), dur = 15 }, scBonus = lin(10, 3) })

    elseif role == 'stun' then
        t2 = mkNode(2, 1, k2, c1_2, 5,
            'Drains 80..400 Foe TP & Steals 20..60% as TP',
            function(r) return string.format('Drain %d TP (Steal %d%%)', r * 80, 10 + r * 10) end,
            { tpDrain = lin(80, 5), tpStealPct = { 20, 30, 40, 50, 60 } })
        t3 = mkNode(3, 1, k3, c1_3, 5,
            'Dispels 1..2 Foe Buffs & +5..25% WSD',
            function(r) return string.format('Dispel %d Buff(s), +%d%% WSD', r >= 4 and 2 or 1, r * 5) end,
            { dispel = { 1, 1, 1, 2, 2 }, wsd = lin(5, 5) })
        t4 = mkNode(4, 1, k4, c1_4, 3,
            'Inflicts Para/Slow (45s) & +12..36% WSD',
            function(r) return string.format('Para+Slow (45s), +%d%% WSD', r * 12) end,
            { wsd = lin(12, 3), targetDebuffs = {
                { effect = xi.effect.PARALYSIS, power = { 18, 24, 30 }, duration = 45 },
                { effect = xi.effect.SLOW, power = { 1500, 2000, 2500 }, duration = 45 },
            } })

    elseif role == 'breach' then
        if ctx.isMag or ctx.isUtil then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Target MDEF -4..20% & MEVA -8..40 (45s)',
                function(r) return string.format('Foe -%d%% MDEF, -%d MEVA', r * 4, r * 8) end,
                { targetDebuffs = {
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_EVASION_DOWN, power = lin(8, 5), duration = 45 },
                } })
        else
            t2 = mkNode(2, 1, k2, c1_2, 5,
                'Ignores 6..30% DEF & Target DEF -4..20%',
                function(r) return string.format('-%d%% DEF Ign, Foe -%d%% DEF', r * 6, r * 4) end,
                { defIgnore = lin(0.06, 5), targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 }} })
        end
        t3 = mkNode(3, 1, k3, c1_3, 5,
            'Target Crit Eva -3..15% & +5..25% WSD',
            function(r) return string.format('Foe -%d%% CritEva, +%d%% WSD', r * 3, r * 5) end,
            { wsd = lin(5, 5), targetDebuffs = {{ effect = xi.effect.CRIT_HIT_EVASION_DOWN, power = lin(3, 5), duration = 45 }} })
        t4 = mkNode(4, 1, k4, c1_4, 3,
            '+12..36% WSD & +12..36% Skillchain Damage',
            function(r) return string.format('+%d%% WSD, +%d%% SC Damage', r * 12, r * 12) end,
            { wsd = lin(12, 3), scBonus = lin(12, 3) })

    elseif role == 'vital' then
        if ctx.isMag or ctx.isUtil or isCasterSpec then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                '+8..40 MAB & +5..25% WSD on WS',
                function(r) return string.format('+%d MAB, +%d%% WSD', r * 8, r * 5) end,
                { matt = lin(8, 5), wsd = lin(5, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Vs <=35% HP Foe: +8..40% WSD & +8..40 MACC',
                function(r) return string.format('Execute +%d%% WSD, +%d MACC', r * 8, r * 8) end,
                { executeWsdLowHp = lin(8, 5), macc = lin(8, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                '+0.35..1.05 fTP & +12..36% WSD',
                function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.35, r * 12) end,
                { ftpAdd = lin(0.35, 3), wsd = lin(12, 3) })
        else
            t2 = mkNode(2, 1, k2, c1_2, 5,
                '+5..25% Crit Rate & +5..25% Crit Dmg',
                function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 5) end,
                { crit = lin(5, 5), critDmg = lin(5, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Vs <=35% HP Foe: +8..40% WSD & +4..20% Crit',
                function(r) return string.format('Execute +%d%% WSD, +%d%% Crit', r * 8, r * 4) end,
                { executeWsdLowHp = lin(8, 5), crit = lin(4, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                '+8..24% Crit Dmg, +0.3..0.9 fTP & +10..30% WSD',
                function(r) return string.format('+%d%% CrDmg, +%.1f fTP, +%d%% WSD', r * 8, r * 0.3, r * 10) end,
                { critDmg = lin(8, 3), ftpAdd = lin(0.30, 3), wsd = lin(10, 3) })
        end

    elseif role == 'flurry' then
        if ctx.isPhys then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                '+6..30% WS Atk & +5..25 Store TP',
                function(r) return string.format('+%d%% Atk, +%d Store TP', r * 6, r * 5) end,
                { atkPct = lin(6, 5), storeTp = lin(5, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'R1-4: +5..20% WSD | R5: fTP ALL Hits!',
                function(r) return r >= 5 and 'fTP ALL HITS + +20% WSD' or string.format('+%d%% WSD (R5:fTP all)', r * 5) end,
                { wsd = { 5, 10, 15, 20, 20 }, multiHitfTPAt = 5 })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                '+1 Bonus Hit, fTP ALL Hits & +9..27% WSD',
                function(r) return string.format('+1 Hit, fTP ALL, +%d%% WSD', r * 9) end,
                { bonusHits = { 1, 1, 1 }, multiHitfTPAt = 1, wsd = lin(9, 3) })
        else
            t2 = mkNode(2, 1, k2, c1_2, 5,
                '+7..35 MAB & +5..25 Store TP',
                function(r) return string.format('+%d MAB, +%d Store TP', r * 7, r * 5) end,
                { matt = lin(7, 5), storeTp = lin(5, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                string.format('%s Follow-Up (5..25%%) & +4..20%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 5, r * 4) end,
                { elemFollow = { ele = ele, pct = lin(5, 5) }, wsd = lin(4, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                '+0.35..1.05 fTP & +12..36% WSD',
                function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.35, r * 12) end,
                { ftpAdd = lin(0.35, 3), wsd = lin(12, 3) })
        end

    elseif role == 'aoe' then
        t2 = mkNode(2, 1, k2, c1_2, 5,
            '+5..25% Pack WSD/Mob & +4..20% WSD',
            function(r) return string.format('+%d%% WSD/Mob, +%d%% WSD', r * 5, r * 4) end,
            { packWsdPerMob = lin(5, 5), wsd = lin(4, 5) })
        t3 = mkNode(3, 1, k3, c1_3, 5,
            string.format('%s Follow-Up (5..25%% +pack) & -Eva', elLb),
            function(r) return string.format('%s +%d%% (+pack), Foe -%d Eva', elLb, r * 5, r * 6) end,
            { elemFollow = { ele = ele, pct = lin(5, 5), scaleWithPack = true },
              targetDebuffs = {{ effect = xi.effect.EVASION_DOWN, power = lin(6, 5), duration = 45 }} })
        t4 = mkNode(4, 1, k4, c1_4, 3,
            '+0.35..1.05 fTP, +10..30% WSD & +6..18% Pack WSD',
            function(r) return string.format('+%.2f fTP, +%d%% WSD, +%d%%/Mob', r * 0.35, r * 10, r * 6) end,
            { ftpAdd = lin(0.35, 3), wsd = lin(10, 3), packWsdPerMob = lin(6, 3) })

    elseif role == 'wave' then
        t2 = mkNode(2, 1, k2, c1_2, 5,
            '+9..45 MAB & +9..45 MACC on WS',
            function(r) return string.format('+%d MAB, +%d MACC', r * 9, r * 9) end,
            { matt = lin(9, 5), macc = lin(9, 5) })
        t3 = mkNode(3, 1, k3, c1_3, 5,
            string.format('%s Follow-Up (6..30%%) & Foe -4..20%% MDEF', elLb),
            function(r) return string.format('%s +%d%% Hit, Foe -%d%% MDEF', elLb, r * 6, r * 4) end,
            { elemFollow = { ele = ele, pct = lin(6, 5) },
              targetDebuffs = {{ effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 }} })
        t4 = mkNode(4, 1, k4, c1_4, 3,
            '+18..54 MAB, +12..36% WSD & +10..30% SC Dmg',
            function(r) return string.format('+%d MAB, +%d%% WSD, +%d%% SC', r * 18, r * 12, r * 10) end,
            { matt = lin(18, 3), wsd = lin(12, 3), scBonus = lin(10, 3) })

    elseif role == 'siphon' or role == 'restore' then
        t2 = mkNode(2, 1, k2, c1_2, 5,
            'Drains 5..25% HP & +5..25% WSD',
            function(r) return string.format('%d%% HP Drain, +%d%% WSD', r * 5, r * 5) end,
            { hpDrain = lin(5, 5), wsd = lin(5, 5) })
        if specKey == 'chiweaver' then
            t3 = mkNode(3, 1, k3, c1_3, 5,
                '+20..100 Party TP & +5..25% WSD',
                function(r) return string.format('+%d Party TP, +%d%% WSD', r * 20, r * 5) end,
                { partyTp = lin(20, 5), wsd = lin(5, 5) })
        else
            t3 = mkNode(3, 1, k3, c1_3, 5,
                'Restores 4..20% Dmg as MP & +5..25% WSD',
                function(r) return string.format('%d%% MP Drain, +%d%% WSD', r * 4, r * 5) end,
                { mpDrain = lin(4, 5), wsd = lin(5, 5) })
        end
        t4 = mkNode(4, 1, k4, c1_4, 3,
            '+12..36% WSD, +5..15% Max HP & +100..300 TP',
            function(r) return string.format('+%d%% WSD, +%d%% HP, +%d TP', r * 12, r * 5, r * 100) end,
            { wsd = lin(12, 3), selfMaxHpHealPct = lin(5, 3), tpBonus = lin(100, 3) })

    else -- lunge, crash, relic
        local tpStep = (role == 'relic') and 65 or 55
        if ctx.isMag or ctx.isUtil then
            t2 = mkNode(2, 1, k2, c1_2, 5,
                string.format('+5..25%% WSD & +%d..%d TP Bonus', tpStep, tpStep * 5),
                function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * 5, r * tpStep) end,
                { wsd = lin(5, 5), tpBonus = lin(tpStep, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                '+0.16..0.80 fTP & +8..40 MAB',
                function(r) return string.format('+%.2f fTP, +%d MAB', r * 0.16, r * 8) end,
                { ftpAdd = lin(0.16, 5), matt = lin(8, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                '+0.35..1.05 fTP, +12..36% WSD & +12..36% SC',
                function(r) return string.format('+%.2f fTP, +%d%% WSD, +%d%% SC', r * 0.35, r * 12, r * 12) end,
                { ftpAdd = lin(0.35, 3), wsd = lin(12, 3), scBonus = lin(12, 3) })
        else
            t2 = mkNode(2, 1, k2, c1_2, 5,
                string.format('+7..35%% Atk & +%d..%d TP Bonus', tpStep, tpStep * 5),
                function(r) return string.format('+%d%% Atk, +%d TP Bonus', r * 7, r * tpStep) end,
                { atkPct = lin(7, 5), tpBonus = lin(tpStep, 5) })
            t3 = mkNode(3, 1, k3, c1_3, 5,
                '+0.16..0.80 fTP & Ignores 5..25% DEF',
                function(r) return string.format('+%.2f fTP, -%d%% DEF Ign', r * 0.16, r * 5) end,
                { ftpAdd = lin(0.16, 5), defIgnore = lin(0.05, 5) })
            t4 = mkNode(4, 1, k4, c1_4, 3,
                '+0.35..1.05 fTP, +12..36% WSD & +12..36% SC',
                function(r) return string.format('+%.2f fTP, +%d%% WSD, +%d%% SC', r * 0.35, r * 12, r * 12) end,
                { ftpAdd = lin(0.35, 3), wsd = lin(12, 3), scBonus = lin(12, 3) })
        end
    end

    return t2, t3, t4
end

-----------------------------------
-- Column 2 (T2C2, T3C2, T4C2) — Spec Kit Mechanics x WS Ordinal Variant
-----------------------------------
local function buildCol2Nodes(specKey, ctx)
    local meta = SPEC_META[specKey]
    local pfx  = meta.pfx
    local m    = ctx.motif
    local n    = ctx.noun
    local v    = ctx.v2
    local ele  = ctx.ele
    local elLb = ctx.eleLabel
    local k2, k3, k4 = pfx .. '_t2c2', pfx .. '_t3c2', pfx .. '_t4c2'
    local t2, t3, t4

    if specKey == 'commander' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Breach', 5,
                'Target DEF/MDEF -4..20% & +15..75 Party TP',
                function(r) return string.format('Foe -%d%% DEF/MDEF, +%d PtyTP', r * 4, r * 15) end,
                { partyTp = lin(15, 5), targetDebuffs = {
                    { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t3 = mkNode(3, 2, k3, n .. ' Warcry', 5,
                'Party Warcry +5..25 (25s) & +5..25% WSD',
                function(r) return string.format('Party Warcry +%d, +%d%% WSD', r * 5, r * 5) end,
                { partyBuffs = {{ effect = xi.effect.WARCRY, power = lin(5, 5), duration = 25 }}, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Marshal', 5,
                '+30..150 Party TP, Party +2..9% HP & +5..25% WSD',
                function(r) return string.format('+%d PtyTP, Pty +%d%% HP, +%d%% WSD', r * 30, ({ 2, 3, 5, 7, 9 })[r], r * 5) end,
                { partyTp = lin(30, 5), partyHealPct = { 2, 3, 5, 7, 9 }, wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Cadence', 5,
                'Party Regain 3..15/t (18s) & +4..20% WSD',
                function(r) return string.format('Party Regain %d/t, +%d%% WSD', r * 3, r * 4) end,
                { partyBuffs = {{ effect = xi.effect.REGAIN, power = lin(3, 5), duration = 18 }}, wsd = lin(4, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Flanking', 5,
                'Target Crit Eva -2..10% & +20..100 Party TP',
                function(r) return string.format('Foe -%d%% CritEva, +%d PtyTP', r * 2, r * 20) end,
                { partyTp = lin(20, 5), targetDebuffs = {{ effect = xi.effect.CRIT_HIT_EVASION_DOWN, power = lin(2, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' General', 5,
                'Party Haste (25s), +6..30% WSD & +6..30% SC',
                function(r) return string.format('Party Haste, +%d%% WSD/+%d%% SC', r * 6, r * 6) end,
                { partyBuffs = {{ effect = xi.effect.HASTE, power = { 300, 600, 900, 1200, 1500 }, duration = 25 }}, wsd = lin(6, 5), scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Bulwark', 5,
                'Party Stoneskin 60..300 & +15..75 Party TP',
                function(r) return string.format('Party Skin %d, +%d PtyTP', r * 60, r * 15) end,
                { partyBuffs = {{ effect = xi.effect.STONESKIN, power = lin(60, 5), duration = 45 }}, partyTp = lin(15, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Volley', 5,
                'Next WS +6..30% WSD & +60..300 Next-WS TP',
                function(r) return string.format('NextWS +%d%% WSD, +%d TP', r * 6, r * 60) end,
                { nextWs = { wsd = lin(6, 5), tp = lin(60, 5), dur = 15 } })
            t4 = mkNode(4, 2, k4, m .. ' Warlord', 5,
                '+35..175 Party TP & +7..35% WSD',
                function(r) return string.format('+%d Party TP, +%d%% WSD', r * 35, r * 7) end,
                { partyTp = lin(35, 5), wsd = lin(7, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Regroup', 5,
                'Party Heal 2..9% HP & Foe -4..20% Atk',
                function(r) return string.format('Party +%d%% HP, Foe -%d%% Atk', ({ 2, 3, 5, 7, 9 })[r], r * 4) end,
                { partyHealPct = { 2, 3, 5, 7, 9 }, targetDebuffs = {{ effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 }} })
            t3 = mkNode(3, 2, k3, n .. ' Standard', 5,
                'Party Protect/Shell & +5..25% WSD',
                function(r) return string.format('Party Prot/Shell, +%d%% WSD', r * 5) end,
                { partyBuffs = {
                    { effect = xi.effect.PROTECT, power = lin(18, 5), duration = 45 },
                    { effect = xi.effect.SHELL, power = lin(5, 5), duration = 45 },
                }, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Imperator', 5,
                'Party Regain 4..20/t (21s) & +7..35% WSD',
                function(r) return string.format('Party Regain %d/t, +%d%% WSD', r * 4, r * 7) end,
                { partyBuffs = {{ effect = xi.effect.REGAIN, power = lin(4, 5), duration = 21 }}, wsd = lin(7, 5) })
        end

    elseif specKey == 'spartan' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Ward', 5,
                'Stoneskin 85..425 & +7..35 Enmity',
                function(r) return string.format('Stoneskin %d, +%d Enmity', r * 85, r * 7) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(85, 5), duration = 45, tier = 3 }}, enmity = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Siphon', 5,
                'Drains 5..25% HP & Foe -4..20% Atk',
                function(r) return string.format('%d%% HP Drain, Foe -%d%% Atk', r * 5, r * 4) end,
                { hpDrain = lin(5, 5), targetDebuffs = {{ effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Champion', 5,
                'Phalanx 12..32, Heal 2..10% HP & +5..25% WSD',
                function(r) return string.format('Phalanx %d, +%d%% HP, +%d%% WSD', 8 + r * 4, r * 2, r * 5) end,
                { statusBuffs = {{ effect = xi.effect.PHALANX, power = { 12, 17, 22, 27, 32 }, duration = 35 }}, selfMaxHpHealPct = lin(2, 5), wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Buckler', 5,
                '+3..15% Parry/Block (18s) & +7..35 Enmity',
                function(r) return string.format('+%d%% Parry, +%d Enmity', r * 3, r * 7) end,
                { enmity = lin(7, 5), postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {{ mod = xi.mod.INQUARTATA, val = lin(3, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Crush', 5,
                'Foe -4..20% DEF/MDEF & Self +2..10% Max HP',
                function(r) return string.format('Foe -%d%% DEF/MDEF, +%d%% HP', r * 4, r * 2) end,
                { selfMaxHpHealPct = lin(2, 5), targetDebuffs = {
                    { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Colossus', 5,
                'Stoneskin 90..450, +6..30% WSD & +8..40 Enm',
                function(r) return string.format('Skin %d, +%d%% WSD, +%d Enm', r * 90, r * 6, r * 8) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(90, 5), duration = 60, tier = 3 }}, wsd = lin(6, 5), enmity = lin(8, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Feast', 5,
                'Self Heal 3..15% Max HP & +6..30 Subtle Blow',
                function(r) return string.format('Self +%d%% MaxHP, +%d SB', r * 3, r * 6) end,
                { selfMaxHpHealPct = lin(3, 5), subtleBlow = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Spikes', 5,
                'Blaze Spikes 12..60 (30s) & +5..25% WSD',
                function(r) return string.format('Blaze Spikes %d, +%d%% WSD', r * 12, r * 5) end,
                { statusBuffs = {{ effect = xi.effect.BLAZE_SPIKES, power = lin(12, 5), duration = 30 }}, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Juggernaut', 5,
                'Drains 6..30% HP, Cleanse 1 & +6..30% WSD',
                function(r) return string.format('%d%% HP Drain, Cleanse, +%d%% WSD', r * 6, r * 6) end,
                { hpDrain = lin(6, 5), cleanseSelf = { 1, 1, 1, 1, 1 }, wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Retort', 5,
                '+3..15% Counter (18s) & +8..40 Enmity',
                function(r) return string.format('+%d%% Counter, +%d Enmity', r * 3, r * 8) end,
                { enmity = lin(8, 5), postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {{ mod = xi.mod.COUNTER, val = lin(3, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Intimidate', 5,
                'Drains 70..350 TP & Foe -8..40 Acc',
                function(r) return string.format('Drain %d TP, Foe -%d Acc', r * 70, r * 8) end,
                { tpDrain = lin(70, 5), targetDebuffs = {{ effect = xi.effect.ACCURACY_DOWN, power = lin(8, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Immortal', 5,
                'Regen 4..20/t (30s), +6..30% WSD & +8..40 Enm',
                function(r) return string.format('Regen %d/t, +%d%% WSD, +%d Enm', r * 4, r * 6, r * 8) end,
                { statusBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 30 }}, wsd = lin(6, 5), enmity = lin(8, 5) })
        end

    elseif specKey == 'sensei' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Deflect', 5,
                '+3..15% Parry & +8..40 EVA (18s)',
                function(r) return string.format('+%d%% Parry, +%d EVA (18s)', r * 3, r * 8) end,
                { postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {
                    { mod = xi.mod.INQUARTATA, val = lin(3, 5) },
                    { mod = xi.mod.EVA, val = lin(8, 5) },
                } } })
            t3 = mkNode(3, 2, k3, n .. ' Sweep', 5,
                'Foe -8..40 Acc/Eva & +5..25% WSD',
                function(r) return string.format('Foe -%d Acc/Eva, +%d%% WSD', r * 8, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {
                    { effect = xi.effect.ACCURACY_DOWN, power = lin(8, 5), duration = 45 },
                    { effect = xi.effect.EVASION_DOWN, power = lin(8, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Grandmaster', 5,
                '+4..20% Counter (20s), +2..10% HP & +5..25% WSD',
                function(r) return string.format('+%d%% Ctr, +%d%% HP, +%d%% WSD', r * 4, r * 2, r * 5) end,
                { selfMaxHpHealPct = lin(2, 5), wsd = lin(5, 5),
                  postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.COUNTER, val = lin(4, 5) }} } })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Poise', 5,
                'Self Heal 2..10% Max HP & +6..30 Subtle Blow',
                function(r) return string.format('Self +%d%% HP, +%d Subtle Blow', r * 2, r * 6) end,
                { selfMaxHpHealPct = lin(2, 5), subtleBlow = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Counter', 5,
                '+3..15% Counter (18s) & +7..35 Enmity',
                function(r) return string.format('+%d%% Counter, +%d Enmity', r * 3, r * 7) end,
                { enmity = lin(7, 5), postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {{ mod = xi.mod.COUNTER, val = lin(3, 5) }} } })
            t4 = mkNode(4, 2, k4, m .. ' Abbot', 5,
                'Stoneskin 85..425, Cleanse 1 & +6..30% WSD',
                function(r) return string.format('Skin %d, Cleanse, +%d%% WSD', r * 85, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(85, 5), duration = 45, tier = 3 }}, cleanseSelf = { 1, 1, 1, 1, 1 }, wsd = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Reed', 5,
                '+10..50 EVA (18s) & +6..30 Enmity',
                function(r) return string.format('+%d EVA (18s), +%d Enmity', r * 10, r * 6) end,
                { enmity = lin(6, 5), postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {{ mod = xi.mod.EVA, val = lin(10, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Nerve', 5,
                'Drains 75..375 TP & Foe -4..20% Atk',
                function(r) return string.format('Drain %d TP, Foe -%d%% Atk', r * 75, r * 4) end,
                { tpDrain = lin(75, 5), targetDebuffs = {{ effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Ironbody', 5,
                'Phalanx 10..30 (35s) & +6..30% WSD',
                function(r) return string.format('Phalanx %d (35s), +%d%% WSD', 5 + r * 5, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.PHALANX, power = { 10, 15, 20, 25, 30 }, duration = 35 }}, wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Breath', 5,
                'Chi Blast +8..40% Dmg & +6..30 Enmity',
                function(r) return string.format('Chi +%d%% Dmg, +%d Enmity', r * 8, r * 6) end,
                { chiBlast = { pct = lin(8, 5) }, enmity = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Ward', 5,
                'Party Regen 3..15/t (21s) & +4..20% WSD',
                function(r) return string.format('Party Regen %d/t, +%d%% WSD', r * 3, r * 4) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = lin(3, 5), duration = 21 }}, wsd = lin(4, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Rikishi', 5,
                '+4..20% Parry (20s), +6..30% WSD & +6..30% SC',
                function(r) return string.format('+%d%% Parry, +%d%% WSD/+%d%% SC', r * 4, r * 6, r * 6) end,
                { wsd = lin(6, 5), scBonus = lin(6, 5),
                  postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.INQUARTATA, val = lin(4, 5) }} } })
        end

    elseif specKey == 'blackbelt' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Kickflow', 5,
                '+4..20% Kick Rate (15s) & +5..25 Store TP',
                function(r) return string.format('+%d%% Kick (15s), +%d STP', r * 4, r * 5) end,
                { storeTp = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.KICK_ATTACK_RATE, val = lin(4, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Impetus', 5,
                'Post-WS +4..20% Crit Dmg (15s) & +5..25% WSD',
                function(r) return string.format('Post +%d%% CrDmg, +%d%% WSD', r * 4, r * 5) end,
                { wsd = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.CRIT_DMG_INCREASE, val = lin(4, 5) }} } })
            t4 = mkNode(4, 2, k4, m .. ' Shihan', 5,
                'Next WS +60..300 TP Bonus & +6..30% WSD',
                function(r) return string.format('NextWS +%d TP, +%d%% WSD', r * 60, r * 6) end,
                { nextWs = { tp = lin(60, 5), dur = 15 }, wsd = lin(6, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Doublefist', 5,
                'Post-WS +5..25% Double Attack (12s) & +5..25 SB',
                function(r) return string.format('Post +%d%% DA (12s), +%d SB', r * 5, r * 5) end,
                { subtleBlow = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 12, mods = {{ mod = xi.mod.DOUBLE_ATTACK, val = lin(5, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Chi-Burst', 5,
                string.format('%s Follow-Up (6..30%%) & +4..20%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 4) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, wsd = lin(4, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Kensei', 5,
                '+50..250 TP Bonus, +6..30% WSD & +6..30% SC',
                function(r) return string.format('+%d TP, +%d%% WSD, +%d%% SC', r * 50, r * 6, r * 6) end,
                { tpBonus = lin(50, 5), wsd = lin(6, 5), scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Blitz', 5,
                'Post-WS +3..15% JA Haste (15s) & +4..20% WSD',
                function(r) return string.format('+%d%% JA Haste (15s), +%d%% WSD', r * 3, r * 4) end,
                { wsd = lin(4, 5), postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {{ mod = xi.mod.HASTE_ABILITY, val = lin(300, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Pressure', 5,
                'Inflicts Plague (2..10 TP/t) & +5..25% WSD',
                function(r) return string.format('Plague -%d TP/t, +%d%% WSD', r * 2, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {{ effect = xi.effect.PLAGUE, power = lin(2, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Asura', 5,
                'Post-WS +3..15% Triple Attack (12s) & +6..30% WSD',
                function(r) return string.format('Post +%d%% TA (12s), +%d%% WSD', r * 3, r * 6) end,
                { wsd = lin(6, 5), postBuff = { effect = xi.effect.POTENCY, duration = 12, mods = {{ mod = xi.mod.TRIPLE_ATTACK, val = lin(3, 5) }} } })
        else
            t2 = mkNode(2, 2, k2, m .. ' Chakra', 5,
                'Chi Blast +10..50% Dmg & -4..20s CD',
                function(r) return string.format('Chi +%d%% Dmg, -%ds CD', r * 10, r * 4) end,
                { chiBlast = { pct = lin(10, 5), cdTrim = lin(4, 5) } })
            t3 = mkNode(3, 2, k3, n .. ' Sunder', 5,
                'Target DEF -4..20% (45s) & +5..25% WSD',
                function(r) return string.format('Foe -%d%% DEF, +%d%% WSD', r * 4, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Dragon', 5,
                'Next WS +8..40% WSD & +6..30 Store TP',
                function(r) return string.format('NextWS +%d%% WSD, +%d STP', r * 8, r * 6) end,
                { nextWs = { wsd = lin(8, 5), dur = 15 }, storeTp = lin(6, 5) })
        end

    elseif specKey == 'chiweaver' then
        -- STRICTLY ZERO MP AND ZERO REFRESH
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Pulse', 5,
                'Party Heal 2..10% HP & +5..25 Subtle Blow',
                function(r) return string.format('Party +%d%% HP, +%d Subtle Blow', r * 2, r * 5) end,
                { partyHealPct = lin(2, 5), subtleBlow = lin(5, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Blossom', 5,
                'Cleanse Party Debuff & Party Regen 3..15/t',
                function(r) return string.format('Cleanse Pty, Regen %d/t (24s)', r * 3) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, partyBuffs = {{ effect = xi.effect.REGEN, power = lin(3, 5), duration = 24 }} })
            t4 = mkNode(4, 2, k4, m .. ' Bodhisattva', 5,
                'Party Heal 3..14% HP, +25..125 Pty TP & +WSD',
                function(r) return string.format('Pty +%d%% HP, +%d TP, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 25, r * 5) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, partyTp = lin(25, 5), wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Bolt', 5,
                'Light Chi Hit (6..30%) & Self +2..10% Max HP',
                function(r) return string.format('Light +%d%% Hit, Self +%d%% HP', r * 6, r * 2) end,
                { elemFollow = { ele = 'LIGHT', pct = lin(6, 5) }, selfMaxHpHealPct = lin(2, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Resonance', 5,
                'Chi Blast -5..25s CD & +20..100 Party TP',
                function(r) return string.format('-%ds Chi CD, +%d Party TP', r * 5, r * 20) end,
                { chiBlast = { cdTrim = lin(5, 5) }, partyTp = lin(20, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Mandate', 5,
                'Party Stoneskin 80..400 & +6..30% WSD',
                function(r) return string.format('Party Skin %d, +%d%% WSD', r * 80, r * 6) end,
                { partyBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 45 }}, wsd = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Serenity', 5,
                'Foe -4..20% Atk/M.Atk & Party +2..8% HP',
                function(r) return string.format('Foe -%d%% Atk/MAtk, Pty +%d%% HP', r * 4, ({ 2, 3, 5, 6, 8 })[r]) end,
                { partyHealPct = { 2, 3, 5, 6, 8 }, targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t3 = mkNode(3, 2, k3, n .. ' Breath', 5,
                'Party Regain 3..15/t (18s) & +5..25% WSD',
                function(r) return string.format('Party Regain %d/t, +%d%% WSD', r * 3, r * 5) end,
                { partyBuffs = {{ effect = xi.effect.REGAIN, power = lin(3, 5), duration = 18 }}, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Nirvana', 5,
                'Chi Blast +12..60% Dmg & Party +3..13% HP',
                function(r) return string.format('Chi +%d%% Dmg, Party +%d%% HP', r * 12, ({ 3, 5, 8, 10, 13 })[r]) end,
                { chiBlast = { pct = lin(12, 5) }, partyHealPct = { 3, 5, 8, 10, 13 } })
        else
            t2 = mkNode(2, 2, k2, m .. 'Purify', 5,
                'Dispels 1..2 Foe Buffs & Self +3..15% HP',
                function(r) return string.format('Dispel %d, Self +%d%% Max HP', r >= 4 and 2 or 1, r * 3) end,
                { dispel = { 1, 1, 1, 2, 2 }, selfMaxHpHealPct = lin(3, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Mantle', 5,
                'Party Protect/Shell & +5..25% WSD',
                function(r) return string.format('Party Prot/Shell, +%d%% WSD', r * 5) end,
                { partyBuffs = {
                    { effect = xi.effect.PROTECT, power = lin(18, 5), duration = 45 },
                    { effect = xi.effect.SHELL, power = lin(5, 5), duration = 45 },
                }, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Enlighten', 5,
                'Cleanse Party, Party Regen 4..20/t & +5..25% WSD',
                function(r) return string.format('Cleanse, Regen %d/t, +%d%% WSD', r * 4, r * 5) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, partyBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, wsd = lin(5, 5) })
        end
    end

    if t2 ~= nil then
        return t2, t3, t4
    end

    if specKey == 'inquisitor' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Battuta', 5,
                '+3..15% Parry (18s), Ice Spikes & +8..40 Enm',
                function(r) return string.format('+%d%% Parry, Spikes, +%d Enm', r * 3, r * 8) end,
                { enmity = lin(8, 5), statusBuffs = {{ effect = xi.effect.ICE_SPIKES, power = lin(10, 5), duration = 30 }},
                  postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {{ mod = xi.mod.INQUARTATA, val = lin(3, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Verdict', 5,
                'Dispels 1..2 Foe Buffs & Foe -4..20% M.Atk',
                function(r) return string.format('Dispel %d, Foe -%d%% M.Atk', r >= 4 and 2 or 1, r * 4) end,
                { dispel = { 1, 1, 1, 2, 2 }, targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Judicator', 5,
                'Stoneskin 90..450, +6..30% WSD & +8..40 Enm',
                function(r) return string.format('Skin %d, +%d%% WSD, +%d Enm', r * 90, r * 6, r * 8) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(90, 5), duration = 60, tier = 3 }}, wsd = lin(6, 5), enmity = lin(8, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Aegis', 5,
                'Phalanx 10..30 (35s) & +8..40 Enmity',
                function(r) return string.format('Phalanx %d (35s), +%d Enmity', 5 + r * 5, r * 8) end,
                { statusBuffs = {{ effect = xi.effect.PHALANX, power = { 10, 15, 20, 25, 30 }, duration = 35 }}, enmity = lin(8, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Censure', 5,
                'Foe -4..20% DEF/MDEF & +5..25% WSD',
                function(r) return string.format('Foe -%d%% DEF/MDEF, +%d%% WSD', r * 4, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {
                    { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Convergence', 5,
                string.format('%s Follow-Up (6..30%%) & Self +2..10%% HP', elLb),
                function(r) return string.format('%s +%d%% Hit, Self +%d%% HP', elLb, r * 6, r * 2) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, selfMaxHpHealPct = lin(2, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Pflug', 5,
                'Stoneskin 80..400 & Cleanse 1 Self Debuff',
                function(r) return string.format('Stoneskin %d, Cleanse 1', r * 80) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 45, tier = 3 }}, cleanseSelf = { 1, 1, 1, 1, 1 } })
            t3 = mkNode(3, 2, k3, n .. ' Edict', 5,
                'Drains 75..375 Foe TP & +7..35 Enmity',
                function(r) return string.format('Drain %d TP, +%d Enmity', r * 75, r * 7) end,
                { tpDrain = lin(75, 5), enmity = lin(7, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Grand-Ward', 5,
                'Party Shell, +6..30% WSD & +6..30% SC Dmg',
                function(r) return string.format('Party Shell, +%d%% WSD/+%d%% SC', r * 6, r * 6) end,
                { partyBuffs = {{ effect = xi.effect.SHELL, power = lin(5, 5), duration = 60 }}, wsd = lin(6, 5), scBonus = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Liement', 5,
                'Self Heal 3..15% Max HP & +7..35 Enmity',
                function(r) return string.format('Self +%d%% MaxHP, +%d Enmity', r * 3, r * 7) end,
                { selfMaxHpHealPct = lin(3, 5), enmity = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Shackles', 5,
                'Foe -8..40 Acc/MACC (45s) & +5..25% WSD',
                function(r) return string.format('Foe -%d Acc/MACC, +%d%% WSD', r * 8, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {
                    { effect = xi.effect.ACCURACY_DOWN, power = lin(8, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ACC_DOWN, power = lin(8, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Bastion', 5,
                '+4..20% Parry (20s), Phalanx 20 & +6..30% WSD',
                function(r) return string.format('+%d%% Parry, Phalanx, +%d%% WSD', r * 4, r * 6) end,
                { wsd = lin(6, 5), statusBuffs = {{ effect = xi.effect.PHALANX, power = { 12, 16, 20, 24, 28 }, duration = 35 }},
                  postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.INQUARTATA, val = lin(4, 5) }} } })
        end

    elseif specKey == 'spellblade' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Conduction', 5,
                '+1..3 Conduction Stacks & +7..35 MAB',
                function(r) return string.format('+%d Conduction, +%d MAB', ({ 1, 1, 2, 2, 3 })[r], r * 7) end,
                { conductionAdd = { 1, 1, 2, 2, 3 }, matt = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Gambit', 5,
                'Target MDEF -4..20% & MEVA -8..40 (45s)',
                function(r) return string.format('Foe -%d%% MDEF, -%d MEVA', r * 4, r * 8) end,
                { targetDebuffs = {
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_EVASION_DOWN, power = lin(8, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Edgeflare', 5,
                string.format('%s Follow-Up (7..35%%) & +6..30%% SC', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% SC Dmg', elLb, r * 7, r * 6) end,
                { elemFollow = { ele = ele, pct = lin(7, 5) }, scBonus = lin(6, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Rayke', 5,
                '+8..40 MAB/MACC & +1..2 Conduction',
                function(r) return string.format('+%d MAB/MACC, +%d Conduct', r * 8, r >= 4 and 2 or 1) end,
                { matt = lin(8, 5), macc = lin(8, 5), conductionAdd = { 1, 1, 1, 2, 2 } })
            t3 = mkNode(3, 2, k3, n .. ' Effusion', 5,
                'Next WS +6..30% WSD & +10..50 Next-WS MACC',
                function(r) return string.format('NextWS +%d%% WSD, +%d MACC', r * 6, r * 10) end,
                { nextWs = { wsd = lin(6, 5), macc = lin(10, 5), dur = 15 } })
            t4 = mkNode(4, 2, k4, m .. ' Ascendance', 5,
                '+10..50 MAB, +6..30% WSD & +5..25% MP Drain',
                function(r) return string.format('+%d MAB, +%d%% WSD, %d%% MPDrn', r * 10, r * 6, r * 5) end,
                { matt = lin(10, 5), wsd = lin(6, 5), mpDrain = lin(5, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Runebolt', 5,
                string.format('%s Follow-Up (6..30%%) & +1..2 Conduct', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d Conduct', elLb, r * 6, r >= 4 and 2 or 1) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, conductionAdd = { 1, 1, 1, 2, 2 } })
            t3 = mkNode(3, 2, k3, n .. ' Brand', 5,
                '+6..30% Skillchain Dmg & +5..25% WSD',
                function(r) return string.format('+%d%% SC Dmg, +%d%% WSD', r * 6, r * 5) end,
                { scBonus = lin(6, 5), wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Overcharge', 5,
                '+2..3 Conduction, +7..35% WSD & +50..250 TP',
                function(r) return string.format('+%d Conduct, +%d%% WSD, +%d TP', r >= 3 and 3 or 2, r * 7, r * 50) end,
                { conductionAdd = { 2, 2, 3, 3, 3 }, wsd = lin(7, 5), tpBonus = lin(50, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Sever', 5,
                'Dispels 1..2 Foe Buffs & +8..40 MAB',
                function(r) return string.format('Dispel %d Buff(s), +%d MAB', r >= 4 and 2 or 1, r * 8) end,
                { dispel = { 1, 1, 1, 2, 2 }, matt = lin(8, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Arcana', 5,
                'Restores 4..20% Dmg as MP & +5..25% WSD',
                function(r) return string.format('%d%% MP Drain, +%d%% WSD', r * 4, r * 5) end,
                { mpDrain = lin(4, 5), wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Archon', 5,
                string.format('%s Follow-Up (7..35%%) & +7..35%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 7, r * 7) end,
                { elemFollow = { ele = ele, pct = lin(7, 5) }, wsd = lin(7, 5) })
        end

    elseif specKey == 'lifebinder' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Font', 5,
                'Party Regen 3..15/t (24s) & +5..25 Subtle Blow',
                function(r) return string.format('Party Regen %d/t, +%d SB', r * 3, r * 5) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = lin(3, 5), duration = 24 }}, subtleBlow = lin(5, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Lifetap', 5,
                'Drains 5..25% HP & Party Heal 2..10% HP',
                function(r) return string.format('%d%% HP Drain, Party +%d%% HP', r * 5, r * 2) end,
                { hpDrain = lin(5, 5), partyHealPct = lin(2, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Sanctuary', 5,
                'Party Stoneskin 80..400, Cleanse Pty & +WSD',
                function(r) return string.format('Pty Skin %d, Cleanse, +%d%% WSD', r * 80, r * 5) end,
                { partyBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 45 }}, cleanseParty = { 1, 1, 1, 2, 2 }, wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Unda-Refresh', 5,
                'Party Refresh 2..6/t (24s) & Party +2..8% HP',
                function(r) return string.format('Pty Refresh %d/t, +%d%% HP', ({ 2, 3, 4, 5, 6 })[r], ({ 2, 3, 5, 6, 8 })[r]) end,
                { partyBuffs = {{ effect = xi.effect.REFRESH, power = { 2, 3, 4, 5, 6 }, duration = 24 }}, partyHealPct = { 2, 3, 5, 6, 8 } })
            t3 = mkNode(3, 2, k3, n .. ' Lux-Pulse', 5,
                'Light Follow-Up (5..25%) & +5..25% WSD',
                function(r) return string.format('Light +%d%% Hit, +%d%% WSD', r * 5, r * 5) end,
                { elemFollow = { ele = 'LIGHT', pct = lin(5, 5) }, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Valiance', 5,
                'Party Heal 3..14% HP & +6..30% SC Dmg',
                function(r) return string.format('Party +%d%% HP, +%d%% SC Dmg', ({ 3, 5, 8, 11, 14 })[r], r * 6) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Tenebrae', 5,
                'Restores 4..20% Dmg as MP & +20..100 Pty TP',
                function(r) return string.format('%d%% MP Drain, +%d Party TP', r * 4, r * 20) end,
                { mpDrain = lin(4, 5), partyTp = lin(20, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Pacify', 5,
                'Foe -4..20% Atk/M.Atk & Party +2..10% HP',
                function(r) return string.format('Foe -%d%% Atk/MAtk, Pty +%d%% HP', r * 4, r * 2) end,
                { partyHealPct = lin(2, 5), targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Covenant', 5,
                'Party Regen 4..20/t (24s) & +6..30% WSD',
                function(r) return string.format('Party Regen %d/t, +%d%% WSD', r * 4, r * 6) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Vivify', 5,
                'Cleanse Party Debuff & Self +3..15% Max HP',
                function(r) return string.format('Cleanse Party, Self +%d%% HP', r * 3) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, selfMaxHpHealPct = lin(3, 5) })
            t3 = mkNode(3, 2, k3, n .. ' One-For-All', 5,
                'Party Shell/Protect & +5..25% WSD',
                function(r) return string.format('Party Prot/Shell, +%d%% WSD', r * 5) end,
                { partyBuffs = {
                    { effect = xi.effect.PROTECT, power = lin(18, 5), duration = 45 },
                    { effect = xi.effect.SHELL, power = lin(5, 5), duration = 45 },
                }, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. 'Hierophant', 5,
                'Party Heal 3..14% HP & +6..30% WSD',
                function(r) return string.format('Party +%d%% HP, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 6) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, wsd = lin(6, 5) })
        end

    elseif specKey == 'animist' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Mend', 5,
                'Party Heal 2..10% HP & Auto Heal 6..30%',
                function(r) return string.format('Party +%d%% HP, Auto +%d%%', r * 2, r * 6) end,
                { partyHealPct = lin(2, 5), eosHeal = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Mist', 5,
                'Party Regen 4..20/t (24s) & Cleanse Party',
                function(r) return string.format('Pty Regen %d/t, Cleanse Pty', r * 4) end,
                { statusBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, cleanseParty = { 1, 1, 1, 2, 2 } })
            t4 = mkNode(4, 2, k4, m .. ' Overhaul', 5,
                'Party Heal 3..14% HP, Auto +8..40% & +WSD',
                function(r) return string.format('Pty +%d%% HP, Auto +%d%%, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 8, r * 5) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, eosHeal = lin(8, 5), wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Plating', 5,
                'Party Stoneskin 80..400 & +5..25 Subtle Blow',
                function(r) return string.format('Pty Skin %d, +%d SB', r * 80, r * 5) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 30 }}, subtleBlow = lin(5, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Pulse', 5,
                'Cleanse Party & Self +3..15% Max HP',
                function(r) return string.format('Cleanse Pty, Self +%d%% HP', r * 3) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, selfMaxHpHealPct = lin(3, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Aegis', 5,
                'Party Heal 3..14% HP & +6..30% SC Dmg',
                function(r) return string.format('Party +%d%% HP, +%d%% SC Dmg', ({ 3, 5, 8, 11, 14 })[r], r * 6) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Dampen', 5,
                'Party Heal 2..10% HP & -4..-20 Enmity',
                function(r) return string.format('Party +%d%% HP, -%d Enmity', r * 2, r * 4) end,
                { partyHealPct = lin(2, 5), enmity = lin(-4, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Pacify', 5,
                'Foe -4..20% Atk/M.Atk & Party +2..10% HP',
                function(r) return string.format('Foe -%d%% Atk/MAtk, Pty +%d%% HP', r * 4, r * 2) end,
                { partyHealPct = lin(2, 5), targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Conduit', 5,
                'Party Regen 4..20/t, Cleanse & +6..30% WSD',
                function(r) return string.format('Pty Regen %d/t, Cleanse, +%d%% WSD', r * 4, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, cleanseParty = { 1, 1, 1, 2, 2 }, wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Barrier', 5,
                'Party Stoneskin 80..400 & Party +2..8% HP',
                function(r) return string.format('Pty Skin %d, +%d%% HP', r * 80, ({ 2, 3, 5, 6, 8 })[r]) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 30 }}, partyHealPct = { 2, 3, 5, 6, 8 } })
            t3 = mkNode(3, 2, k3, n .. ' Sync', 5,
                'Automaton Heal 6..30% & Cleanse Party',
                function(r) return string.format('Auto +%d%%, Cleanse Pty', r * 6) end,
                { eosHeal = lin(6, 5), cleanseParty = { 1, 1, 1, 2, 2 } })
            t4 = mkNode(4, 2, k4, m .. ' Sovereign', 5,
                'Party Heal 3..14% HP & +6..30% WSD',
                function(r) return string.format('Party +%d%% HP, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 6) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, wsd = lin(6, 5) })
        end

    elseif specKey == 'wyvernheart' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Breath', 5,
                'Party Heal 2..10% HP & Wyvern Heal 6..30%',
                function(r) return string.format('Party +%d%% HP, Wyvern +%d%%', r * 2, r * 6) end,
                { partyHealPct = lin(2, 5), eosHeal = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Mending Mist', 5,
                'Party Regen 4..20/t (24s) & Cleanse Party',
                function(r) return string.format('Pty Regen %d/t, Cleanse Pty', r * 4) end,
                { statusBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, cleanseParty = { 1, 1, 1, 2, 2 } })
            t4 = mkNode(4, 2, k4, m .. ' Dragonheart', 5,
                'Party Heal 3..14% HP, Wyvern +8..40% & +WSD',
                function(r) return string.format('Pty +%d%% HP, Wyvern +%d%%, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 8, r * 5) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, eosHeal = lin(8, 5), wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Dragonscale', 5,
                'Party Stoneskin 80..400 & +5..25 Subtle Blow',
                function(r) return string.format('Pty Skin %d, +%d SB', r * 80, r * 5) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 30 }}, subtleBlow = lin(5, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Bloodsurge', 5,
                'Cleanse Party & Self +3..15% Max HP',
                function(r) return string.format('Cleanse Pty, Self +%d%% HP', r * 3) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, selfMaxHpHealPct = lin(3, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Sanctuary', 5,
                'Party Heal 3..14% HP & +6..30% SC Dmg',
                function(r) return string.format('Party +%d%% HP, +%d%% SC Dmg', ({ 3, 5, 8, 11, 14 })[r], r * 6) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Crimson Aid', 5,
                'Party Heal 2..10% HP & -4..-20 Enmity',
                function(r) return string.format('Party +%d%% HP, -%d Enmity', r * 2, r * 4) end,
                { partyHealPct = lin(2, 5), enmity = lin(-4, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Pacify', 5,
                'Foe -4..20% Atk/M.Atk & Party +2..10% HP',
                function(r) return string.format('Foe -%d%% Atk/MAtk, Pty +%d%% HP', r * 4, r * 2) end,
                { partyHealPct = lin(2, 5), targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Skywarden', 5,
                'Party Regen 4..20/t, Cleanse & +6..30% WSD',
                function(r) return string.format('Pty Regen %d/t, Cleanse, +%d%% WSD', r * 4, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, cleanseParty = { 1, 1, 1, 2, 2 }, wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Wyrmgift', 5,
                'Party Stoneskin 80..400 & Party +2..8% HP',
                function(r) return string.format('Pty Skin %d, +%d%% HP', r * 80, ({ 2, 3, 5, 6, 8 })[r]) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 30 }}, partyHealPct = { 2, 3, 5, 6, 8 } })
            t3 = mkNode(3, 2, k3, n .. ' Wyrmbond', 5,
                'Wyvern Heal 6..30% & Cleanse Party',
                function(r) return string.format('Wyvern +%d%%, Cleanse Pty', r * 6) end,
                { eosHeal = lin(6, 5), cleanseParty = { 1, 1, 1, 2, 2 } })
            t4 = mkNode(4, 2, k4, m .. ' Wyrmblood', 5,
                'Party Heal 3..14% HP & +6..30% WSD',
                function(r) return string.format('Party +%d%% HP, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 6) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, wsd = lin(6, 5) })
        end

    elseif specKey == 'medic' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Whisper', 5,
                'Party Heal 2..10% HP & Eos Heal 6..30%',
                function(r) return string.format('Party +%d%% HP, Eos +%d%%', r * 2, r * 6) end,
                { partyHealPct = lin(2, 5), eosHeal = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. 'Accession', 5,
                'Party Regen 3..15/t (24s) & Cleanse Party',
                function(r) return string.format('Pty Regen %d/t, Cleanse Pty', r * 3) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = lin(3, 5), duration = 24 }}, cleanseParty = { 1, 1, 1, 2, 2 } })
            t4 = mkNode(4, 2, k4, m .. ' Seraphim', 5,
                'Party Heal 3..14% HP, Eos +8..40% & +WSD',
                function(r) return string.format('Pty +%d%% HP, Eos +%d%%, +%d%% WSD', ({ 3, 5, 8, 11, 14 })[r], r * 8, r * 5) end,
                { partyHealPct = { 3, 5, 8, 11, 14 }, eosHeal = lin(8, 5), wsd = lin(5, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Sublimate', 5,
                'Restores 4..20% Dmg as MP & -4..-20 Enmity',
                function(r) return string.format('%d%% MP Drain, -%d Enmity', r * 4, r * 4) end,
                { mpDrain = lin(4, 5), enmity = lin(-4, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Covenant', 5,
                'Party Stoneskin 75..375 & Eos +30..150 TP',
                function(r) return string.format('Party Skin %d, Eos +%d TP', r * 75, r * 30) end,
                { partyBuffs = {{ effect = xi.effect.STONESKIN, power = lin(75, 5), duration = 45 }}, petTp = lin(30, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Illumination', 5,
                'Party Refresh 2..6/t (24s) & +6..30% WSD',
                function(r) return string.format('Party Refresh %d/t, +%d%% WSD', ({ 2, 3, 4, 5, 6 })[r], r * 6) end,
                { partyBuffs = {{ effect = xi.effect.REFRESH, power = { 2, 3, 4, 5, 6 }, duration = 24 }}, wsd = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Solace', 5,
                'Self Heal 3..15% HP & Eos Heal 6..30%',
                function(r) return string.format('Self +%d%% HP, Eos +%d%%', r * 3, r * 6) end,
                { selfMaxHpHealPct = lin(3, 5), eosHeal = lin(6, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Tranquilize', 5,
                'Foe -4..20% Atk/M.Atk & +5..25 Subtle Blow',
                function(r) return string.format('Foe -%d%% Atk/MAtk, +%d SB', r * 4, r * 5) end,
                { subtleBlow = lin(5, 5), targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Panacea', 5,
                'Cleanse Party, Party +3..13% HP & +5..25% WSD',
                function(r) return string.format('Cleanse, Pty +%d%% HP, +%d%% WSD', ({ 3, 5, 8, 10, 13 })[r], r * 5) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, partyHealPct = { 3, 5, 8, 10, 13 }, wsd = lin(5, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Dawnlight', 5,
                'Light Follow-Up (5..25%) & Party +2..8% HP',
                function(r) return string.format('Light +%d%% Hit, Pty +%d%% HP', r * 5, ({ 2, 3, 5, 6, 8 })[r]) end,
                { elemFollow = { ele = 'LIGHT', pct = lin(5, 5) }, partyHealPct = { 2, 3, 5, 6, 8 } })
            t3 = mkNode(3, 2, k3, n .. ' Adloquium', 5,
                'Party Protect/Shell & Eos Heal 6..30%',
                function(r) return string.format('Party Prot/Shell, Eos +%d%%', r * 6) end,
                { partyBuffs = {
                    { effect = xi.effect.PROTECT, power = lin(18, 5), duration = 45 },
                    { effect = xi.effect.SHELL, power = lin(5, 5), duration = 45 },
                }, eosHeal = lin(6, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Archmedic', 5,
                'Party Regen 4..20/t (24s) & +6..30% SC Dmg',
                function(r) return string.format('Party Regen %d/t, +%d%% SC', r * 4, r * 6) end,
                { partyBuffs = {{ effect = xi.effect.REGEN, power = lin(4, 5), duration = 24 }}, scBonus = lin(6, 5) })
        end

    elseif specKey == 'sage' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Helix', 5,
                '+9..45 MAB & Target MDEF -4..20% (45s)',
                function(r) return string.format('+%d MAB, Foe -%d%% MDEF', r * 9, r * 4) end,
                { matt = lin(9, 5), targetDebuffs = {{ effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 }} })
            t3 = mkNode(3, 2, k3, n .. ' Oberon', 5,
                'Titania +35..175 TP, +6..30% Heal & +5..25% WSD',
                function(r) return string.format('Fae +%d TP/+%d%% HP, +%d%% WSD', r * 35, r * 6, r * 5) end,
                { petTp = lin(35, 5), eosHeal = lin(6, 5), wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Ebullience', 5,
                string.format('%s Follow-Up (7..35%%) & +7..35%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 7, r * 7) end,
                { elemFollow = { ele = ele, pct = lin(7, 5) }, wsd = lin(7, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Focalize', 5,
                '+10..50 MACC & Target MEVA -8..40 (45s)',
                function(r) return string.format('+%d MACC, Foe -%d MEVA', r * 10, r * 8) end,
                { macc = lin(10, 5), targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = lin(8, 5), duration = 45 }} })
            t3 = mkNode(3, 2, k3, n .. ' Immanence', 5,
                '+6..30% Skillchain Dmg & Next WS +6..30% WSD',
                function(r) return string.format('+%d%% SC Dmg, NextWS +%d%% WSD', r * 6, r * 6) end,
                { scBonus = lin(6, 5), nextWs = { wsd = lin(6, 5), dur = 15 } })
            t4 = mkNode(4, 2, k4, m .. ' Grimoire', 5,
                '+12..60 MAB, +5..25% MP Drain & +6..30% WSD',
                function(r) return string.format('+%d MAB, %d%% MPDrn, +%d%% WSD', r * 12, r * 5, r * 6) end,
                { matt = lin(12, 5), mpDrain = lin(5, 5), wsd = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Fae-Wind', 5,
                string.format('%s Follow-Up (6..30%%) & Fae +30..150 TP', elLb),
                function(r) return string.format('%s +%d%% Hit, Fae +%d TP', elLb, r * 6, r * 30) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, petTp = lin(30, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Kaustra', 5,
                'Inflicts Plague (2..10 TP/t) & +8..40 MAB',
                function(r) return string.format('Plague -%d TP/t, +%d MAB', r * 2, r * 8) end,
                { matt = lin(8, 5), targetDebuffs = {{ effect = xi.effect.PLAGUE, power = lin(2, 5), duration = 45 }} })
            t4 = mkNode(4, 2, k4, m .. ' Savant', 5,
                '+10..50 MAB/MACC & +7..35% WSD',
                function(r) return string.format('+%d MAB/MACC, +%d%% WSD', r * 10, r * 7) end,
                { matt = lin(10, 5), macc = lin(10, 5), wsd = lin(7, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. 'Unravel', 5,
                'Dispels 1..2 Foe Buffs & +8..40 MAB',
                function(r) return string.format('Dispel %d Buff(s), +%d MAB', r >= 4 and 2 or 1, r * 8) end,
                { dispel = { 1, 1, 1, 2, 2 }, matt = lin(8, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Parsimony', 5,
                'Restores 4..20% Dmg as MP & -4..-20 Enmity',
                function(r) return string.format('%d%% MP Drain, -%d Enmity', r * 4, r * 4) end,
                { mpDrain = lin(4, 5), enmity = lin(-4, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Grand-Sage', 5,
                'Titania +40..200 TP, +8..40% SC & +6..30% WSD',
                function(r) return string.format('Fae +%d TP, +%d%% SC, +%d%% WSD', r * 40, r * 8, r * 6) end,
                { petTp = lin(40, 5), scBonus = lin(8, 5), wsd = lin(6, 5) })
        end

    elseif specKey == 'necromancer' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Harbinger', 5,
                'Drains 5..25% HP & Heals Undead Pet 7..35%',
                function(r) return string.format('%d%% HP Drain, Pet +%d%% HP', r * 5, r * 7) end,
                { hpDrain = lin(5, 5), eosHeal = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Thrall', 5,
                'Undead Pet +35..175 TP & Foe -4..20% DEF/MDEF',
                function(r) return string.format('Pet +%d TP, Foe -%d%% DEF/MDEF', r * 35, r * 4) end,
                { petTp = lin(35, 5), targetDebuffs = {
                    { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Lichdom', 5,
                'Dark Follow-Up (7..35%), +5..25% MP & +WSD',
                function(r) return string.format('Dark +%d%%, %d%% MPDrn, +%d%% WSD', r * 7, r * 5, r * 6) end,
                { elemFollow = { ele = 'DARK', pct = lin(7, 5) }, mpDrain = lin(5, 5), wsd = lin(6, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Corpsefire', 5,
                'Dark Follow-Up (6..30% +pack) & +7..35 MAB',
                function(r) return string.format('Dark +%d%% (+pack), +%d MAB', r * 6, r * 7) end,
                { elemFollow = { ele = 'DARK', pct = lin(6, 5), scaleWithPack = true }, matt = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Soulreap', 5,
                'Drains 75..375 Foe TP & Steals 20..60% as TP',
                function(r) return string.format('Drain %d TP (Steal %d%%)', r * 75, 10 + r * 10) end,
                { tpDrain = lin(75, 5), tpStealPct = { 20, 30, 40, 50, 60 } })
            t4 = mkNode(4, 2, k4, m .. ' Revenant', 5,
                'Undead +8..40% HP, +40..200 Pet TP & +6..30% WSD',
                function(r) return string.format('Pet +%d%% HP/+%d TP, +%d%% WSD', r * 8, r * 40, r * 6) end,
                { eosHeal = lin(8, 5), petTp = lin(40, 5), wsd = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Blight', 5,
                'Inflicts Plague (2..10 TP/t) & Foe -4..20% Atk',
                function(r) return string.format('Plague -%d TP/t, Foe -%d%% Atk', r * 2, r * 4) end,
                { targetDebuffs = {
                    { effect = xi.effect.PLAGUE, power = lin(2, 5), duration = 45 },
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                } })
            t3 = mkNode(3, 2, k3, n .. ' Pact', 5,
                'Restores 4..20% Dmg as MP & +8..40 MAB',
                function(r) return string.format('%d%% MP Drain, +%d MAB', r * 4, r * 8) end,
                { mpDrain = lin(4, 5), matt = lin(8, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Necrolord', 5,
                'Drains 6..30% HP, +6..30% SC & +6..30% WSD',
                function(r) return string.format('%d%% HP Drain, +%d%% SC/+%d%% WSD', r * 6, r * 6, r * 6) end,
                { hpDrain = lin(6, 5), scBonus = lin(6, 5), wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Unhallow', 5,
                'Dispels 1..2 Foe Buffs & Pet +30..150 TP',
                function(r) return string.format('Dispel %d, Pet +%d TP', r >= 4 and 2 or 1, r * 30) end,
                { dispel = { 1, 1, 1, 2, 2 }, petTp = lin(30, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Boneward', 5,
                'Stoneskin 80..400 & Undead Heal 6..30%',
                function(r) return string.format('Stoneskin %d, Pet +%d%% HP', r * 80, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 45, tier = 3 }}, eosHeal = lin(6, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Catacomb', 5,
                'Vs <=35% HP Foe: +9..45% WSD & +10..50 MAB',
                function(r) return string.format('Execute +%d%% WSD, +%d MAB', r * 9, r * 10) end,
                { executeWsdLowHp = lin(9, 5), matt = lin(10, 5) })
        end

    elseif specKey == 'bladewheel' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Box-Step', 5,
                'Target DEF -4..20% & Eva -7..35 (45s)',
                function(r) return string.format('Foe -%d%% DEF, -%d Evasion', r * 4, r * 7) end,
                { targetDebuffs = {
                    { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.EVASION_DOWN, power = lin(7, 5), duration = 45 },
                } })
            t3 = mkNode(3, 2, k3, n .. ' Samba', 5,
                'Party Heal 2..9% HP & +20..100 Party TP',
                function(r) return string.format('Party +%d%% HP, +%d Party TP', ({ 2, 3, 5, 7, 9 })[r], r * 20) end,
                { partyHealPct = { 2, 3, 5, 7, 9 }, partyTp = lin(20, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Climactic', 5,
                '+6..30% WSD, +6..30% SC & Next WS +6..30% WSD',
                function(r) return string.format('+%d%% WSD/SC, NextWS +%d%% WSD', r * 6, r * 6) end,
                { wsd = lin(6, 5), scBonus = lin(6, 5), nextWs = { wsd = lin(6, 5), dur = 15 } })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Stutter', 5,
                'Target MEVA -8..40 & Crit Eva -2..10% (45s)',
                function(r) return string.format('Foe -%d MEVA, -%d%% CritEva', r * 8, r * 2) end,
                { targetDebuffs = {
                    { effect = xi.effect.MAGIC_EVASION_DOWN, power = lin(8, 5), duration = 45 },
                    { effect = xi.effect.CRIT_HIT_EVASION_DOWN, power = lin(2, 5), duration = 45 },
                } })
            t3 = mkNode(3, 2, k3, n .. ' Flourish', 5,
                'Next WS +65..325 TP Bonus & +5..25 Store TP',
                function(r) return string.format('NextWS +%d TP, +%d STP', r * 65, r * 5) end,
                { nextWs = { tp = lin(65, 5), dur = 15 }, storeTp = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. 'Fandango', 5,
                string.format('%s Follow-Up (6..30%%) & +6..30%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 6) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, wsd = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Minuet', 5,
                'Cleanse Party Debuff & Self +3..15% Max HP',
                function(r) return string.format('Cleanse Party, Self +%d%% HP', r * 3) end,
                { cleanseParty = { 1, 1, 1, 2, 2 }, selfMaxHpHealPct = lin(3, 5) })
            t3 = mkNode(3, 2, k3, n .. 'Haste-Step', 5,
                'Post-WS +3..15% JA Haste (18s) & +5..25% WSD',
                function(r) return string.format('+%d%% JA Haste (18s), +%d%% WSD', r * 3, r * 5) end,
                { wsd = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {{ mod = xi.mod.HASTE_ABILITY, val = lin(300, 5) }} } })
            t4 = mkNode(4, 2, k4, m .. ' Etoile', 5,
                '+55..275 TP Bonus & +7..35% WSD',
                function(r) return string.format('+%d TP Bonus, +%d%% WSD', r * 55, r * 7) end,
                { tpBonus = lin(55, 5), wsd = lin(7, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Feather', 5,
                '+5..25 Subtle Blow & +8..40 EVA (18s)',
                function(r) return string.format('+%d SB, +%d EVA (18s)', r * 5, r * 8) end,
                { subtleBlow = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {{ mod = xi.mod.EVA, val = lin(8, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Ricochet', 5,
                'Drains 75..375 Foe TP & Steals 20..60% as TP',
                function(r) return string.format('Drain %d TP (Steal %d%%)', r * 75, 10 + r * 10) end,
                { tpDrain = lin(75, 5), tpStealPct = { 20, 30, 40, 50, 60 } })
            t4 = mkNode(4, 2, k4, m .. ' Terpsichore', 5,
                'Party Regain 3..15/t (18s) & +6..30% WSD',
                function(r) return string.format('Party Regain %d/t, +%d%% WSD', r * 3, r * 6) end,
                { partyBuffs = {{ effect = xi.effect.REGAIN, power = lin(3, 5), duration = 18 }}, wsd = lin(6, 5) })
        end

    elseif specKey == 'imperialarcher' then
        if ctx.isRanged then
            if v == 1 then
                t2 = ctx.isPhys
                    and mkNode(2, 2, k2, m .. ' Bodkin', 5,
                        'Ignores 6..30% DEF & -5..25 Enmity',
                        function(r) return string.format('-%d%% DEF Ign, -%d Enmity', r * 6, r * 5) end,
                        { defIgnore = lin(0.06, 5), enmity = lin(-5, 5) })
                    or mkNode(2, 2, k2, m .. ' Bodkin', 5,
                        '+5..25% WSD & -5..25 Enmity',
                        function(r) return string.format('+%d%% WSD, -%d Enmity', r * 5, r * 5) end,
                        { wsd = lin(5, 5), enmity = lin(-5, 5) })
                t3 = ctx.isPhys
                    and mkNode(3, 2, k3, n .. ' Deadeye', 5,
                        '+4..20% R.Crit Rate & +6..30% R.Crit Dmg',
                        function(r) return string.format('+%d%% Crit, +%d%% R.CrDmg', r * 4, r * 6) end,
                        { crit = lin(4, 5), critDmg = lin(6, 5) })
                    or mkNode(3, 2, k3, n .. ' Deadeye', 5,
                        '+8..40 MAB & +8..40 MACC',
                        function(r) return string.format('+%d MAB, +%d MACC', r * 8, r * 8) end,
                        { matt = lin(8, 5), macc = lin(8, 5) })
                t4 = mkNode(4, 2, k4, m .. ' Brand', 5,
                    'Next WS +6..30% WSD & +7..35% SC Dmg',
                    function(r) return string.format('NextWS +%d%% WSD, +%d%% SC', r * 6, r * 7) end,
                    { nextWs = { wsd = lin(6, 5), dur = 15 }, scBonus = lin(7, 5) })
            elseif v == 2 then
                t2 = mkNode(2, 2, k2, m .. ' Skirmish', 5,
                    'Post-WS +5..25% Atk & +4..20% Double Atk (18s)',
                    function(r) return string.format('+%d%% Atk, +%d%% DA (18s)', r * 5, r * 4) end,
                    { postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {
                        { mod = xi.mod.ATTP, val = lin(5, 5) },
                        { mod = xi.mod.DOUBLE_ATTACK, val = lin(4, 5) },
                    } } })
                t3 = mkNode(3, 2, k3, n .. ' Siphon', 5,
                    'Drains 75..375 Foe TP & Steals 20..60% as TP',
                    function(r) return string.format('Drain %d TP (Steal %d%%)', r * 75, 10 + r * 10) end,
                    { tpDrain = lin(75, 5), tpStealPct = { 20, 30, 40, 50, 60 } })
                t4 = mkNode(4, 2, k4, m .. ' Horizon', 5,
                    string.format('%s Follow-Up (6..30%%) & +6..30%% WSD', elLb),
                    function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 6) end,
                    { elemFollow = { ele = ele, pct = lin(6, 5) }, wsd = lin(6, 5) })
            elseif v == 3 then
                t2 = mkNode(2, 2, k2, m .. ' Pinpoint', 5,
                    'Target MEVA -8..40 & Crit Eva -2..10% (45s)',
                    function(r) return string.format('Foe -%d MEVA, -%d%% CritEva', r * 8, r * 2) end,
                    { targetDebuffs = {
                        { effect = xi.effect.MAGIC_EVASION_DOWN, power = lin(8, 5), duration = 45 },
                        { effect = xi.effect.CRIT_HIT_EVASION_DOWN, power = lin(2, 5), duration = 45 },
                    } })
                t3 = mkNode(3, 2, k3, n .. ' Volley', 5,
                    'Next WS +65..325 TP Bonus & +5..25 Store TP',
                    function(r) return string.format('NextWS +%d TP, +%d STP', r * 65, r * 5) end,
                    { nextWs = { tp = lin(65, 5), dur = 15 }, storeTp = lin(5, 5) })
                t4 = ctx.isPhys
                    and mkNode(4, 2, k4, m .. ' Galebow', 5,
                        'Vs >=70% HP Foe: +8..40% WSD & +6..30% R.Atk',
                        function(r) return string.format('Opener +%d%% WSD, +%d%% R.Atk', r * 8, r * 6) end,
                        { openerWsdHighHp = lin(8, 5), atkPct = lin(6, 5) })
                    or mkNode(4, 2, k4, m .. ' Galebow', 5,
                        'Vs >=70% HP Foe: +8..40% WSD & +6..30% WSD',
                        function(r) return string.format('Opener +%d%% WSD, +%d%% WSD', r * 8, r * 6) end,
                        { openerWsdHighHp = lin(8, 5), wsd = lin(6, 5) })
            else
                t2 = mkNode(2, 2, k2, m .. ' Quietus', 5,
                    '-6..-30 Enmity & +5..25 Subtle Blow',
                    function(r) return string.format('-%d Enmity, +%d Subtle Blow', r * 6, r * 5) end,
                    { enmity = lin(-6, 5), subtleBlow = lin(5, 5) })
                t3 = mkNode(3, 2, k3, n .. ' Poise', 5,
                    'Post-WS +5..25 Zanshin & +5..25 Store TP (18s)',
                    function(r) return string.format('+%d Zanshin, +%d STP (18s)', r * 5, r * 5) end,
                    { postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {
                        { mod = xi.mod.ZANSHIN, val = lin(5, 5) },
                        { mod = xi.mod.STORETP, val = lin(5, 5) },
                    } } })
                t4 = ctx.isPhys
                    and mkNode(4, 2, k4, m .. ' Zenith', 5,
                        '+0.18..0.90 fTP & +7..35% R.Crit Dmg',
                        function(r) return string.format('+%.2f fTP, +%d%% R.CrDmg', r * 0.18, r * 7) end,
                        { ftpAdd = lin(0.18, 5), critDmg = lin(7, 5) })
                    or mkNode(4, 2, k4, m .. ' Zenith', 5,
                        '+0.18..0.90 fTP & +7..35% WSD',
                        function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.18, r * 7) end,
                        { ftpAdd = lin(0.18, 5), wsd = lin(7, 5) })
            end
        else
            if v == 1 then
                t2 = mkNode(2, 2, k2, m .. ' Sunder', 5,
                    'Target DEF -4..20% & Eva -7..35 (45s)',
                    function(r) return string.format('Foe -%d%% DEF, -%d Evasion', r * 4, r * 7) end,
                    { targetDebuffs = {
                        { effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 },
                        { effect = xi.effect.EVASION_DOWN, power = lin(7, 5), duration = 45 },
                    } })
                t3 = mkNode(3, 2, k3, n .. ' Primer', 5,
                    'Next WS +6..30% WSD & +65..325 TP Bonus',
                    function(r) return string.format('NextWS +%d%% WSD, +%d TP', r * 6, r * 65) end,
                    { nextWs = { wsd = lin(6, 5), tp = lin(65, 5), dur = 15 } })
                t4 = mkNode(4, 2, k4, m .. ' Cosmic', 5,
                    '+7..35% Skillchain Dmg & +6..30% WSD',
                    function(r) return string.format('+%d%% SC Dmg, +%d%% WSD', r * 7, r * 6) end,
                    { scBonus = lin(7, 5), wsd = lin(6, 5) })
            elseif v == 2 then
                t2 = mkNode(2, 2, k2, m .. ' Quickdraw', 5,
                    'Post-WS +3..15% Snapshot & +6..30 R.Acc (18s)',
                    function(r) return string.format('+%d%% Snap, +%d R.Acc (18s)', r * 3, r * 6) end,
                    { postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {
                        { mod = xi.mod.SNAPSHOT, val = lin(3, 5) },
                        { mod = xi.mod.RACC, val = lin(6, 5) },
                    } } })
                t3 = mkNode(3, 2, k3, n .. ' Cadence', 5,
                    '+5..25 Store TP & +55..275 TP Bonus',
                    function(r) return string.format('+%d STP, +%d TP Bonus', r * 5, r * 55) end,
                    { storeTp = lin(5, 5), tpBonus = lin(55, 5) })
                t4 = mkNode(4, 2, k4, m .. ' Tempest', 5,
                    string.format('%s Follow-Up (6..30%%) & +6..30%% WSD', elLb),
                    function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 6) end,
                    { elemFollow = { ele = ele, pct = lin(6, 5) }, wsd = lin(6, 5) })
            elseif v == 3 then
                t2 = mkNode(2, 2, k2, m .. ' Unbind', 5,
                    'Dispels 1..2 Foe Buffs & +5..25% WSD',
                    function(r) return string.format('Dispel %d Buff(s), +%d%% WSD', r >= 4 and 2 or 1, r * 5) end,
                    { dispel = { 1, 1, 1, 2, 2 }, wsd = lin(5, 5) })
                t3 = mkNode(3, 2, k3, n .. ' Reflex', 5,
                    'Post-WS +3..15% JA Haste & +4..20% Crit (18s)',
                    function(r) return string.format('+%d%% JA Haste, +%d%% Crit', r * 3, r * 4) end,
                    { postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {
                        { mod = xi.mod.HASTE_ABILITY, val = lin(300, 5) },
                        { mod = xi.mod.CRITHITRATE, val = lin(4, 5) },
                    } } })
                t4 = mkNode(4, 2, k4, m .. ' Severance', 5,
                    'Vs <=35% HP Foe: +9..45% WSD & +6..30% SC',
                    function(r) return string.format('Execute +%d%% WSD, +%d%% SC', r * 9, r * 6) end,
                    { executeWsdLowHp = lin(9, 5), scBonus = lin(6, 5) })
            else
                t2 = mkNode(2, 2, k2, m .. ' Sighting', 5,
                    'Next WS +8..40 Acc/R.Acc & +5..25 Subtle Blow',
                    function(r) return string.format('NextWS +%d Acc, +%d SB', r * 8, r * 5) end,
                    { nextWs = { acc = lin(8, 5), dur = 15 }, subtleBlow = lin(5, 5) })
                t3 = mkNode(3, 2, k3, n .. ' Nocking', 5,
                    'Post-WS +5..25 Zanshin & +6..30% R.Atk (18s)',
                    function(r) return string.format('+%d Zan, +%d%% R.Atk (18s)', r * 5, r * 6) end,
                    { postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {
                        { mod = xi.mod.ZANSHIN, val = lin(5, 5) },
                        { mod = xi.mod.RATTP, val = lin(6, 5) },
                    } } })
                t4 = mkNode(4, 2, k4, m .. ' Eclipse', 5,
                    '+0.18..0.90 fTP & +6..30% WSD',
                    function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.18, r * 6) end,
                    { ftpAdd = lin(0.18, 5), wsd = lin(6, 5) })
            end
        end

    elseif specKey == 'ronin' or specKey == 'aegistemplar' or specKey == 'kagemusha' then
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Stagger', 5,
                'Stoneskin 80..400 & +7..35 Enmity',
                function(r) return string.format('Stoneskin %d, +%d Enmity', r * 80, r * 7) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(80, 5), duration = 45, tier = 3 }}, enmity = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Stillwater', 5,
                'Self Heal 3..15% Max HP & +5..25 Subtle Blow',
                function(r) return string.format('Self +%d%% MaxHP, +%d SB', r * 3, r * 5) end,
                { selfMaxHpHealPct = lin(3, 5), subtleBlow = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Bastion', 5,
                'Phalanx 12..28 (35s) & +6..30% WSD',
                function(r) return string.format('Phalanx %d, +%d%% WSD', 8 + r * 4, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.PHALANX, power = { 12, 16, 20, 24, 28 }, duration = 35 }}, wsd = lin(6, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Counter', 5,
                'Post-WS +3..15% Counter & +4..20% DEF (18s)',
                function(r) return string.format('+%d%% Counter, +%d%% DEF (18s)', r * 3, r * 4) end,
                { postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {
                    { mod = xi.mod.COUNTER, val = lin(3, 5) },
                    { mod = xi.mod.DEFP, val = lin(4, 5) },
                } } })
            t3 = mkNode(3, 2, k3, n .. ' Hamanoha', 5,
                'Target -4..20% Atk & -8..40 Acc (45s)',
                function(r) return string.format('Foe -%d%% Atk, -%d Acc', r * 4, r * 8) end,
                { targetDebuffs = {
                    { effect = xi.effect.ATTACK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.ACCURACY_DOWN, power = lin(8, 5), duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Purity', 5,
                'Cleanse 1 Debuff, +6..30% WSD & +8..40 Enmity',
                function(r) return string.format('Cleanse 1, +%d%% WSD, +%d Enm', r * 6, r * 8) end,
                { cleanseSelf = { 1, 1, 1, 1, 1 }, wsd = lin(6, 5), enmity = lin(8, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Unsheathe', 5,
                'Dispels 1..2 Foe Buffs & +7..35 Enmity',
                function(r) return string.format('Dispel %d Buff(s), +%d Enm', r >= 4 and 2 or 1, r * 7) end,
                { dispel = { 1, 1, 1, 2, 2 }, enmity = lin(7, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Bind', 5,
                'Target -4..20% M.Atk & Slow 9..25% (45s)',
                function(r) return string.format('Foe -%d%% M.Atk, Slow %d%%', r * 4, 5 + r * 4) end,
                { targetDebuffs = {
                    { effect = xi.effect.MAGIC_ATK_DOWN, power = lin(4, 5), duration = 45 },
                    { effect = xi.effect.SLOW, power = { 900, 1300, 1700, 2100, 2500 }, duration = 45 },
                } })
            t4 = mkNode(4, 2, k4, m .. ' Clarity', 5,
                'Stoneskin 100..500, +6..30% WSD & +6..30% SC',
                function(r) return string.format('Skin %d, +%d%% WSD/+%d%% SC', r * 100, r * 6, r * 6) end,
                { statusBuffs = {{ effect = xi.effect.STONESKIN, power = lin(100, 5), duration = 60, tier = 3 }}, wsd = lin(6, 5), scBonus = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Mindseye', 5,
                'Post-WS +3..15% Parry & -2..-10% DT (18s)',
                function(r) return string.format('+%d%% Parry, -%d%% DT (18s)', r * 3, r * 2) end,
                { postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {
                    { mod = xi.mod.PARRY, val = lin(3, 5) },
                    { mod = xi.mod.DMG, val = lin(-200, 5) },
                } } })
            t3 = mkNode(3, 2, k3, n .. ' Quell', 5,
                'Drains 75..375 Foe TP & +7..35 Enmity',
                function(r) return string.format('Drain %d TP, +%d Enmity', r * 75, r * 7) end,
                { tpDrain = lin(75, 5), enmity = lin(7, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Circle', 5,
                'Party Protect/Shell, +6..30% WSD & +8..40 Enm',
                function(r) return string.format('Pty Prot/Shell, +%d%% WSD/+%d Enm', r * 6, r * 8) end,
                { partyBuffs = {
                    { effect = xi.effect.PROTECT, power = lin(20, 5), duration = 60 },
                    { effect = xi.effect.SHELL, power = lin(5, 5), duration = 60 },
                }, wsd = lin(6, 5), enmity = lin(8, 5) })
        end

    elseif specKey == 'warlord' then
        if v == 1 then
            t2 = ctx.isPhys
                and mkNode(2, 2, k2, m .. ' Noto', 5,
                    'Ignores 6..30% DEF & Foe -4..20% DEF (45s)',
                    function(r) return string.format('-%d%% DEF Ign, Foe -%d%% DEF', r * 6, r * 4) end,
                    { defIgnore = lin(0.06, 5), targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 }} })
                or mkNode(2, 2, k2, m .. ' Noto', 5,
                    '+8..40 MAB & Foe -4..20% MDEF (45s)',
                    function(r) return string.format('+%d MAB, Foe -%d%% MDEF', r * 8, r * 4) end,
                    { matt = lin(8, 5), targetDebuffs = {{ effect = xi.effect.MAGIC_DEF_DOWN, power = lin(4, 5), duration = 45 }} })
            t3 = ctx.isPhys
                and mkNode(3, 2, k3, n .. ' Drawcut', 5,
                    '+4..20% Crit Rate & +7..35% Crit Dmg',
                    function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 4, r * 7) end,
                    { crit = lin(4, 5), critDmg = lin(7, 5) })
                or mkNode(3, 2, k3, n .. ' Drawcut', 5,
                    '+8..40 MAB & +8..40 MACC',
                    function(r) return string.format('+%d MAB, +%d MACC', r * 8, r * 8) end,
                    { matt = lin(8, 5), macc = lin(8, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Hagakure', 5,
                '+55..275 TP Bonus & +7..35% WSD',
                function(r) return string.format('+%d TP Bonus, +%d%% WSD', r * 55, r * 7) end,
                { tpBonus = lin(55, 5), wsd = lin(7, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Draincut', 5,
                'Drains 5..25% HP & +5..25% WSD',
                function(r) return string.format('%d%% HP Drain, +%d%% WSD', r * 5, r * 5) end,
                { hpDrain = lin(5, 5), wsd = lin(5, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Demonblade', 5,
                'Post-WS +4..20% DA & +4..20 Zanshin (15s)',
                function(r) return string.format('+%d%% DA, +%d Zanshin (15s)', r * 4, r * 4) end,
                { postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {
                    { mod = xi.mod.DOUBLE_ATTACK, val = lin(4, 5) },
                    { mod = xi.mod.ZANSHIN, val = lin(4, 5) },
                } } })
            t4 = ctx.isPhys
                and mkNode(4, 2, k4, m .. ' Execution', 5,
                    'Vs <=35% HP Foe: +9..45% WSD & +7..35% CrDmg',
                    function(r) return string.format('Execute +%d%% WSD, +%d%% CrDmg', r * 9, r * 7) end,
                    { executeWsdLowHp = lin(9, 5), critDmg = lin(7, 5) })
                or mkNode(4, 2, k4, m .. ' Execution', 5,
                    'Vs <=35% HP Foe: +9..45% WSD & +6..30% SC',
                    function(r) return string.format('Execute +%d%% WSD, +%d%% SC', r * 9, r * 6) end,
                    { executeWsdLowHp = lin(9, 5), scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Trance', 5,
                'Post-WS +3..15% JA Haste & +5..25 STP (18s)',
                function(r) return string.format('+%d%% JA Haste, +%d STP (18s)', r * 3, r * 5) end,
                { storeTp = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 18, mods = {
                    { mod = xi.mod.HASTE_ABILITY, val = lin(300, 5) },
                } } })
            t3 = mkNode(3, 2, k3, n .. ' Sheathe', 5,
                'Next WS +7..35% WSD & +60..300 TP Bonus',
                function(r) return string.format('NextWS +%d%% WSD, +%d TP', r * 7, r * 60) end,
                { nextWs = { wsd = lin(7, 5), tp = lin(60, 5), dur = 15 } })
            t4 = mkNode(4, 2, k4, m .. ' Kensei', 5,
                '+7..35% Skillchain Dmg & +6..30% WSD',
                function(r) return string.format('+%d%% SC Dmg, +%d%% WSD', r * 7, r * 6) end,
                { scBonus = lin(7, 5), wsd = lin(6, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Rending', 5,
                'Target Crit Eva -2..10% & +5..25% WSD',
                function(r) return string.format('Foe -%d%% CritEva, +%d%% WSD', r * 2, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {{ effect = xi.effect.CRIT_HIT_EVASION_DOWN, power = lin(2, 5), duration = 45 }} })
            t3 = mkNode(3, 2, k3, n .. ' Flare', 5,
                string.format('%s Follow-Up (6..30%%) & +5..25%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 5) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Overlord', 5,
                '+0.20..1.00 fTP & +6..30% WSD',
                function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.20, r * 6) end,
                { ftpAdd = lin(0.20, 5), wsd = lin(6, 5) })
        end

    else -- berserker (used on Club/Staff full builds)
        if v == 1 then
            t2 = mkNode(2, 2, k2, m .. ' Savagery', 5,
                'Post-WS +5..25% Double Attack (12s) & +WSD',
                function(r) return string.format('Post +%d%% DA (12s), +%d%% WSD', r * 5, r * 4) end,
                { wsd = lin(4, 5), postBuff = { effect = xi.effect.POTENCY, duration = 12, mods = {{ mod = xi.mod.DOUBLE_ATTACK, val = lin(5, 5) }} } })
            t3 = mkNode(3, 2, k3, n .. ' Bloodthirst', 5,
                'Drains 5..25% HP & +5..25% WSD',
                function(r) return string.format('%d%% HP Drain, +%d%% WSD', r * 5, r * 5) end,
                { hpDrain = lin(5, 5), wsd = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Rampage', 5,
                '+55..275 TP Bonus & +7..35% WSD',
                function(r) return string.format('+%d TP Bonus, +%d%% WSD', r * 55, r * 7) end,
                { tpBonus = lin(55, 5), wsd = lin(7, 5) })
        elseif v == 2 then
            t2 = mkNode(2, 2, k2, m .. ' Cleave', 5,
                'Target DEF -4..20% (45s) & +5..25% WSD',
                function(r) return string.format('Foe -%d%% DEF, +%d%% WSD', r * 4, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = lin(4, 5), duration = 45 }} })
            t3 = mkNode(3, 2, k3, n .. ' Frenzy', 5,
                'At <=60% Self HP: +8..40% WSD & +5..25 STP',
                function(r) return string.format('LowHP +%d%% WSD, +%d STP', r * 8, r * 5) end,
                { lowSelfHpWsd = lin(8, 5), storeTp = lin(5, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Warbringer', 5,
                'Next WS +8..40% WSD & +6..30% SC Dmg',
                function(r) return string.format('NextWS +%d%% WSD, +%d%% SC', r * 8, r * 6) end,
                { nextWs = { wsd = lin(8, 5), dur = 15 }, scBonus = lin(6, 5) })
        elseif v == 3 then
            t2 = mkNode(2, 2, k2, m .. ' Gore', 5,
                'Target Crit Eva -2..10% & +5..25% WSD',
                function(r) return string.format('Foe -%d%% CritEva, +%d%% WSD', r * 2, r * 5) end,
                { wsd = lin(5, 5), targetDebuffs = {{ effect = xi.effect.CRIT_HIT_EVASION_DOWN, power = lin(2, 5), duration = 45 }} })
            t3 = mkNode(3, 2, k3, n .. ' Outburst', 5,
                string.format('%s Follow-Up (6..30%%) & +4..20%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 4) end,
                { elemFollow = { ele = ele, pct = lin(6, 5) }, wsd = lin(4, 5) })
            t4 = mkNode(4, 2, k4, m .. ' Executioner', 5,
                'Vs <=35% HP Foe: +9..45% WSD & +5..25% WSD',
                function(r) return string.format('Execute +%d%% WSD, +%d%% WSD', r * 9, r * 5) end,
                { executeWsdLowHp = lin(9, 5), wsd = lin(5, 5) })
        else
            t2 = mkNode(2, 2, k2, m .. ' Reckless', 5,
                'Next WS +65..325 TP Bonus & +5..25 STP',
                function(r) return string.format('NextWS +%d TP, +%d STP', r * 65, r * 5) end,
                { nextWs = { tp = lin(65, 5), dur = 15 }, storeTp = lin(5, 5) })
            t3 = mkNode(3, 2, k3, n .. ' Brutality', 5,
                'Post-WS +3..15% Triple Attack (12s) & +WSD',
                function(r) return string.format('Post +%d%% TA (12s), +%d%% WSD', r * 3, r * 5) end,
                { wsd = lin(5, 5), postBuff = { effect = xi.effect.POTENCY, duration = 12, mods = {{ mod = xi.mod.TRIPLE_ATTACK, val = lin(3, 5) }} } })
            t4 = mkNode(4, 2, k4, m .. ' Slaughter', 5,
                '+0.20..1.00 fTP & +6..30% WSD',
                function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.20, r * 6) end,
                { ftpAdd = lin(0.20, 5), wsd = lin(6, 5) })
        end
    end

    return t2, t3, t4
end

-----------------------------------
-- Column 3 (T2C3 Stance, T3C3 Tactical/Elemental/Echo, T4C3 Mastery)
-----------------------------------
local STANCE_TITLES =
{
    commander   = { 'Battlecry',  'Formation', 'Phalanx',   'Vanguard'  },
    berserker   = { 'Bloodlust',  'Berserk',   'Outrage',   'Rampancy'  },
    spartan     = { 'Defender',   'Hoplite',   'Spear-Wall', 'Phalanx' },
    sensei      = { 'Dojo',       'Kamae-St',  'Kata-St',   'Zazen'     },
    blackbelt   = { 'Footwork',   'Focus-St',  'Oath-St',   'Kensei'    },
    chiweaver   = { 'Lotus-St',   'Harmony',   'Prana',     'Zen'       },
    inquisitor  = { 'Battuta',    'Swordplay', 'Vallation', 'Inquisit'  },
    spellblade  = { 'Edgeflare',  'Ascend',    'Runebrand', 'Conduit'   },
    lifebinder  = { 'Valiance',   'Sanctuary', 'Font',      'Covenant'  },
    medic       = { 'White-Arts', 'Solace-St', 'Eos-Bond',  'Triage-St' },
    sage        = { 'Black-Arts', 'Ebullient', 'Fae-Pact',  'Grimoire'  },
    necromancer    = { 'Dark-Pact',  'Grim-Bond', 'Ossuary-St','Dullahan'  },
    bladewheel     = { 'Chakram-St', 'Saber',     'Fan-Dance', 'Cabriole'  },
    ronin          = { 'Seigan-St',  'Mushin-St', 'Third-Eye', 'Warding'   },
    imperialarcher = { 'Oisoya-St',  'Hasso-St',  'Sengikori', 'Cosmic-St' },
    warlord        = { 'Noto-St',    'Ashura-St', 'Hagakure',  'Iai-Edge'  },
    aegistemplar   = { 'Sentinel-St','Consecrate','Rampart-St','Invincible'},
    kagemusha      = { 'Yonin-St',   'Bunshin-St','Smoke-St',  'Shadow-St' },
    bishop         = { 'Solace-St',  'Veil-St',   'Grace-St',  'Mercy-St'  },
    templar        = { 'Majesty-St', 'Beacon-St', 'Aegis-St',  'Light-St'  },
    magus          = { 'Diffus-St',  'Osmotic-St','Azure-St',  'Lore-St'   },
    vampire        = { 'Samba-St',   'Trance-St', 'Waltz-St',  'Crimson-St'},
    celestial      = { 'Astral-St',  'Avatar-St', 'Ward-St',   'Star-St'   },
    pugilist       = { 'Tandem-St',  'Limiter-St','Barrage-St','Sync-St'   },
    vanguard       = { 'Bulwark-St', 'Alloy-St',  'Strobe-St', 'Chassis-St'},
    animist        = { 'Repair-St',  'Aether-St', 'Clock-St',  'Auto-St'   },
    verdant        = { 'Luopan-St',  'Bolster-St','Canopy-St', 'Sylvan-St' },
    wyvernheart    = { 'Breath-St',  'Wyrm-St',   'Scale-St',  'Spirit-St' },
    huntsman       = { 'Tusker-St',  'Saurian-St','Apex-St',   'Predator'  },
}

local T3C3_TITLES =
{
    commander      = { 'Barrage',   'Pincer',    'Horn',      'Legion'    },
    berserker      = { 'Ravage',    'Havoc',     'Decimate',  'Overkill'  },
    spartan        = { 'Bastion',   'Aspis',     'Ironclad',  'Gauntlet'  },
    sensei         = { 'Parry',     'Disarm',    'Meditation','Balance'   },
    blackbelt      = { 'Momentum',  'Flurry',    'Impact',    'Velocity'  },
    chiweaver      = { 'Radiance',  'Breeze',    'Stillness', 'Mercy'     },
    inquisitor     = { 'Decree-Inq','Bulwark',   'Sentence',  'Foil'      },
    spellblade     = { 'Discharge', 'Resonance', 'Overload',  'Fission'   },
    lifebinder     = { 'Boon',      'Benedict',  'Anoint',    'Vow'       },
    medic          = { 'Infusion',  'Antidote',  'Succor',    'Suture'    },
    sage           = { 'Scholar',   'Thesis',    'Lemma',     'Syllogism' },
    necromancer    = { 'Miasma',    'Reaping',   'Shroud',    'Dirge'     },
    bladewheel     = { 'Pirouette', 'Rhythm',    'Choreo',    'Encore'    },
    ronin          = { 'Riposte',   'Calm',      'Purify',    'Balance'   },
    imperialarcher = { 'Nocking',   'Drawcut',   'Wind-Bolt', 'Elucidate' },
    warlord        = { 'Bloodlust', 'Ravage',    'Quench',    'Cleave'    },
    aegistemplar   = { 'Intercept', 'Zeal',      'Absolve',   'Sanctify'  },
    kagemusha      = { 'Decoy',     'Smoke',     'Shroud',    'Mirage'    },
    bishop         = { 'Solace',    'Veil',      'Grace',     'Pulse'     },
    templar        = { 'Majesty',   'Beacon',    'Radiance',  'Aegis'     },
    magus          = { 'Catalyst',  'Diffusion', 'Osmosis',   'Surge'     },
    vampire        = { 'Crimson',   'Flourish',  'Waltz',     'Feast'     },
    celestial      = { 'Astral',    'Ruby',      'Siphon',    'Starlight' },
    pugilist       = { 'Tandem',    'Barrage',   'Limiter',   'Sync'      },
    vanguard       = { 'Bulwark',   'Hydraulic', 'Alloy',     'Ventriloq' },
    animist        = { 'Aether',    'Overhaul',  'Clockwork', 'Fiber'     },
    verdant        = { 'Sylvan',    'Bloom',     'Renewal',   'Canopy'    },
    wyvernheart    = { 'Wyrmblood', 'Breath',    'Scale',     'Sanctuary' },
    huntsman       = { 'Rimetusk',  'Saurian',   'Primeval',  'Apex-Pack' },
    generic        = { 'Precision', 'Impact',    'Momentum',  'Edge'      },
}

local T4C3_TITLES =
{
    commander      = { 'Sovereign', 'Imperator', 'Strategos', 'Warmaster' },
    berserker      = { 'Apex',      'Warlord-Z', 'Massacre',  'Cataclysm' },
    spartan        = { 'Immortal',  'Leonidas',  'Praetor',   'Titan'     },
    sensei         = { 'Mastery',   'Zenith',    'Grandkata', 'Shogun'    },
    blackbelt      = { 'Grandfist', 'Pinnacle',  'Godhand',   'Supremacy' },
    chiweaver      = { 'Avatar',    'Halo',      'Transcend', 'Solstice'  },
    inquisitor     = { 'Highjudge', 'Arbiter',   'Justiciar', 'Citadel'   },
    spellblade     = { 'Runelord',  'Archmage',  'Bladestar', 'Astral'    },
    lifebinder     = { 'Seraph',    'Hierarch',  'Wellspring','Archon'    },
    medic          = { 'Saint',     'Luminary',  'Archhealer','Paragon'   },
    sage           = { 'Archsage',  'Oracle',    'Grandfae',  'Logos'     },
    necromancer    = { 'Archlich',  'Overlord',  'Harbinger', 'Abaddon'   },
    bladewheel     = { 'Virtuoso',  'Prima',     'Maestro',   'Finale'    },
    ronin          = { 'Kensei',    'Grandmaster','Zanshin',  'Ronin'     },
    imperialarcher = { 'Bow-Saint', 'Tenzen',    'Kensei-Bow','Starfall'  },
    warlord        = { 'Asura',     'Muramasa',  'Shogun',    'Warfiend'  },
    aegistemplar   = { 'Templar',   'Bastion',   'Archon',    'Seraphim'  },
    kagemusha      = { 'Kagemusha', 'Shinobi',   'Phantom',   'Eclipse'   },
    bishop         = { 'Bishop',    'Seraph',    'Hierarch',  'Benedict'  },
    templar        = { 'Templar',   'Crusader',  'Paladin',   'Sanctum'   },
    magus          = { 'Magus',     'Alchemist', 'Azure',     'Conduit'   },
    vampire        = { 'Vampire',   'Nocturne',  'Crimson',   'Bloodmoon' },
    celestial      = { 'Celestial', 'Astral',    'Archon',    'Elysian'   },
    pugilist       = { 'Pugilist',  'Tandem',    'Overdrive', 'Striker'   },
    vanguard       = { 'Vanguard',  'Bastion',   'Valoredge', 'Sentinel'  },
    animist        = { 'Animist',   'Artificer', 'Clockwork', 'Sovereign' },
    verdant        = { 'Verdant',   'Dryad',     'Sylvan',    'Worldtree' },
    wyvernheart    = { 'Wyvern',    'Dragoon',   'Crimson',   'Skywarden' },
    huntsman       = { 'Cehuetzi',  'Gabbrath',  'Warden',    'Apex-Bond' },
    generic        = { 'Prowess',   'Zenith',    'Mastery',   'Triumph'   },
}

local function cleanWord(w)
    w = (w or 'Apex'):gsub('^%s+', '')
    return w:sub(1, 1):upper() .. w:sub(2)
end

local function buildCol3Nodes(specKey, ctx)
    local meta = SPEC_META[specKey]
    local pfx  = meta.pfx
    local m    = ctx.motif
    local n    = ctx.noun
    local v    = ctx.v3
    local ele  = ctx.ele
    local elLb = ctx.eleLabel
    local k2, k3, k4 = pfx .. '_t2c3', pfx .. '_t3c3', pfx .. '_t4c3'

    local stWord = cleanWord((STANCE_TITLES[specKey] or STANCE_TITLES.berserker)[v])
    local t3Word = cleanWord((T3C3_TITLES[specKey] or T3C3_TITLES.berserker)[v])
    local t4Word = cleanWord((T4C3_TITLES[specKey] or T4C3_TITLES.berserker)[v])

    -- 1. T2C3: Spec Stance / Active Aura Synergy Node (or Passive Focus for generic)
    local t2
    if specKey == 'generic' then
        if ctx.isMag or ctx.isUtil then
            t2 = mkNode(2, 3, k2, n .. ' Potency', 5,
                '+5..25% WSD & +8..40 MAB/MACC',
                function(r) return string.format('+%d%% WSD, +%d MAB/MACC', r * 5, r * 8) end,
                { wsd = lin(5, 5), matt = lin(8, 5), macc = lin(8, 5) })
        else
            local atkLbl = ctx.isRanged and 'R.Atk' or 'Atk'
            t2 = mkNode(2, 3, k2, n .. ' Might', 5,
                string.format('+5..25%% WSD, +6..30%% %s & +STP', atkLbl),
                function(r) return string.format('+%d%% WSD, +%d%% %s, +%d STP', r * 5, r * 6, atkLbl, r * 3) end,
                { wsd = lin(5, 5), atkPct = lin(6, 5), storeTp = lin(3, 5) })
        end
    elseif meta.role == 'tank' then
        local stFields = { wsd = lin(7, 5), enmity = lin(8, 5) }
        local stTbl, stLbl = makeStanceTable(specKey, stFields)
        t2 = mkNode(2, 3, k2, n .. ' ' .. stWord, 5,
            string.format('%s: +7..35%% WSD & +8..40 Enm', stLbl),
            function(r) return string.format('%s: +%d%% WSD, +%d Enm', stLbl, r * 7, r * 8) end,
            { stance = stTbl, subtleBlow = lin(3, 5) })
    elseif meta.role == 'healer' then
        local stFields = { wsd = lin(7, 5), subtleBlow = lin(5, 5), macc = lin(6, 5) }
        local stTbl, stLbl = makeStanceTable(specKey, stFields)
        t2 = mkNode(2, 3, k2, n .. ' ' .. stWord, 5,
            string.format('%s: +7..35%% WSD, +SB & +MACC', stLbl),
            function(r) return string.format('%s: +%d%% WSD, +%d SB', stLbl, r * 7, r * 5) end,
            { stance = stTbl, subtleBlow = lin(3, 5) })
    elseif ctx.isMag or ctx.isUtil or meta.role == 'mage' or specKey == 'spellblade' then
        local stFields = { wsd = lin(7, 5), matt = lin(8, 5), macc = lin(8, 5) }
        local stTbl, stLbl = makeStanceTable(specKey, stFields)
        t2 = mkNode(2, 3, k2, n .. ' ' .. stWord, 5,
            string.format('%s: +7..35%% WSD & +8..40 MAB', stLbl),
            function(r) return string.format('%s: +%d%% WSD, +%d MAB', stLbl, r * 7, r * 8) end,
            { stance = stTbl, macc = lin(4, 5) })
    else
        local stFields = { wsd = lin(7, 5), atkPct = lin(6, 5), tpBonus = lin(40, 5) }
        local stTbl, stLbl = makeStanceTable(specKey, stFields)
        local atkLbl = ctx.isRanged and 'R.Atk' or 'Atk'
        t2 = mkNode(2, 3, k2, n .. ' ' .. stWord, 5,
            string.format('%s: +7..35%% WSD & +6..30%% %s', stLbl, atkLbl),
            function(r) return string.format('%s: +%d%% WSD, +%d%% %s', stLbl, r * 7, r * 6, atkLbl) end,
            { stance = stTbl, storeTp = lin(3, 5) })
    end

    -- 2. T3C3: RMEA Aftermath Echo OR Spec Tactical/Elemental Amplifier
    local t3
    if ctx.aftermath ~= nil then
        local eName = string.format('%s %s', m, meta.rmea)
        if meta.role == 'tank' then
            t3 = mkNode(3, 3, k3, eName, 5,
                '+5..25% WSD, +60..300 TP & +6..30 Enm',
                function(r) return string.format('+%d%% WSD, +%d TP, +%d Enm', r * 5, r * 60, r * 6) end,
                { wsd = lin(5, 5), tpBonus = lin(60, 5), enmity = lin(6, 5) })
        elseif meta.role == 'healer' then
            t3 = mkNode(3, 3, k3, eName, 5,
                '+5..25% WSD, +60..300 TP & Party +2..8% HP',
                function(r) return string.format('+%d%% WSD, +%d TP, Pty +%d%% HP', r * 5, r * 60, ({ 2, 3, 5, 6, 8 })[r]) end,
                { wsd = lin(5, 5), tpBonus = lin(60, 5), partyHealPct = { 2, 3, 5, 6, 8 } })
        else
            t3 = mkNode(3, 3, k3, eName, 5,
                '+5..25% WSD, +60..300 TP & +5..25% SC',
                function(r) return string.format('+%d%% WSD, +%d TP, +%d%% SC', r * 5, r * 60, r * 5) end,
                { wsd = lin(5, 5), tpBonus = lin(60, 5), scBonus = lin(5, 5) })
        end
    elseif meta.role == 'tank' then
        if v % 2 == 1 then
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                string.format('%s Follow-Up (5..25%%) & +7..35 Enm', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d Enmity', elLb, r * 5, r * 7) end,
                { elemFollow = { ele = ele, pct = lin(5, 5), scaleWithPack = ctx.aoe }, enmity = lin(7, 5) })
        else
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                'Next WS +6..30% WSD & Self +2..10% Max HP',
                function(r) return string.format('NextWS +%d%% WSD, +%d%% HP', r * 6, r * 2) end,
                { nextWs = { wsd = lin(6, 5), dur = 15 }, selfMaxHpHealPct = lin(2, 5) })
        end
    elseif meta.role == 'healer' then
        if v % 2 == 1 then
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                string.format('%s Follow-Up (5..25%%) & +20..100 Pty TP', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d PtyTP', elLb, r * 5, r * 20) end,
                { elemFollow = { ele = ele, pct = lin(5, 5) }, partyTp = lin(20, 5) })
        else
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                'Next WS +6..30% WSD & +5..25 Subtle Blow',
                function(r) return string.format('NextWS +%d%% WSD, +%d SB', r * 6, r * 5) end,
                { nextWs = { wsd = lin(6, 5), dur = 15 }, subtleBlow = lin(5, 5) })
        end
    else
        if v == 1 then
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                string.format('%s Follow-Up (6..30%%) & +4..20%% WSD', elLb),
                function(r) return string.format('%s +%d%% Hit, +%d%% WSD', elLb, r * 6, r * 4) end,
                { elemFollow = { ele = ele, pct = lin(6, 5), scaleWithPack = ctx.aoe }, wsd = lin(4, 5) })
        elseif v == 2 then
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                'Vs <=35% HP Foe: +8..40% WSD & +5..25% SC',
                function(r) return string.format('Execute +%d%% WSD, +%d%% SC', r * 8, r * 5) end,
                { executeWsdLowHp = lin(8, 5), scBonus = lin(5, 5) })
        elseif v == 3 then
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                'Vs >=70% HP Foe: +8..40% WSD & +50..250 TP',
                function(r) return string.format('Opener +%d%% WSD, +%d TP', r * 8, r * 50) end,
                { openerWsdHighHp = lin(8, 5), tpBonus = lin(50, 5) })
        else
            t3 = mkNode(3, 3, k3, m .. ' ' .. t3Word, 5,
                '+6..30% Skillchain Dmg & +5..25% WSD',
                function(r) return string.format('+%d%% SC Dmg, +%d%% WSD', r * 6, r * 5) end,
                { scBonus = lin(6, 5), wsd = lin(5, 5) })
        end
    end

    -- 3. T4C3: Spec + WS Mastery (5 ranks)
    local t4
    if meta.role == 'tank' then
        t4 = mkNode(4, 3, k4, n .. ' ' .. t4Word, 5,
            '+6..30% WSD, +8..40 Enmity & +6..30% SC Dmg',
            function(r) return string.format('+%d%% WSD, +%d Enm, +%d%% SC', r * 6, r * 8, r * 6) end,
            { wsd = lin(6, 5), enmity = lin(8, 5), scBonus = lin(6, 5) })
    elseif meta.role == 'healer' then
        t4 = mkNode(4, 3, k4, n .. ' ' .. t4Word, 5,
            '+6..30% WSD, Party +2..9% HP & +6..30% SC',
            function(r) return string.format('+%d%% WSD, Pty +%d%% HP, +%d%% SC', r * 6, ({ 2, 3, 5, 7, 9 })[r], r * 6) end,
            { wsd = lin(6, 5), partyHealPct = { 2, 3, 5, 7, 9 }, scBonus = lin(6, 5) })
    elseif ctx.isMag or ctx.isUtil or meta.role == 'mage' or specKey == 'spellblade' then
        t4 = mkNode(4, 3, k4, n .. ' ' .. t4Word, 5,
            '+10..50 MAB, +6..30% WSD & +6..30% SC Dmg',
            function(r) return string.format('+%d MAB, +%d%% WSD, +%d%% SC', r * 10, r * 6, r * 6) end,
            { matt = lin(10, 5), wsd = lin(6, 5), scBonus = lin(6, 5) })
    else
        if v % 2 == 1 and ctx.isPhys then
            t4 = mkNode(4, 3, k4, n .. ' ' .. t4Word, 5,
                '+5..25% Crit, +6..30% Crit Dmg & +5..25% WSD',
                function(r) return string.format('+%d%% Crit, +%d%% CrDmg, +%d%% WSD', r * 5, r * 6, r * 5) end,
                { crit = lin(5, 5), critDmg = lin(6, 5), wsd = lin(5, 5) })
        else
            t4 = mkNode(4, 3, k4, n .. ' ' .. t4Word, 5,
                '+0.18..0.90 fTP, +6..30% WSD & +6..30% SC',
                function(r) return string.format('+%.2f fTP, +%d%% WSD, +%d%% SC', r * 0.18, r * 6, r * 6) end,
                { ftpAdd = lin(0.18, 5), wsd = lin(6, 5), scBonus = lin(6, 5) })
        end
    end

    return t2, t3, t4
end

-----------------------------------
-- Safety Sanitizer (Enforces Tank/Healer/ChiWeaver/NonPhys/Tooltip Invariants)
-----------------------------------
local NO_SPIKE_SPECS =
{
    spartan    = true,
    sensei     = true,
    inquisitor = true,
    ronin      = true,
    aegistemplar = true,
    dreadnought  = true,
    kagemusha  = true,
    alphawarden = true,
    chiweaver    = true,
    lifebinder   = true,
    medic        = true,
    bishop       = true,
    templar      = true,
    magus        = true,
    vampire      = true,
    celestial    = true,
    vanguard     = true,
    animist      = true,
    verdant        = true,
    wyvernheart    = true,
    miragesentinel = true,
    buccaneer      = true,
    gambler        = true,
    huntsman       = true,
    tank           = true,
    healer         = true,
}

local SINGLE_TARGET_ONLY_SPECS =
{
    necromancer    = true,
    huntsman       = true,
    miragesentinel = true,
    flintlock      = true,
    buccaneer      = true,
    gambler        = true,
    pugilist       = true,
    vanguard       = true,
    animist        = true,
}

local PET_SPECS =
{
    medic       = true,
    sage        = true,
    necromancer = true,
    berserker   = true, -- BST Axe pet hooks
    alphawarden = true,
    celestial   = true,
    pugilist    = true,
    vanguard    = true,
    animist     = true,
    verdant     = true,
    wyvernheart = true,
    huntsman    = true,
}

local function sanitizeSpecNode(node, specKey, ctx)
    if node == nil or type(node.effect) ~= 'table' then
        return node
    end
    local eff = node.effect

    -- 1. Strip high-damage spike fields on tanks & healers
    if NO_SPIKE_SPECS[specKey] then
        eff.bonusHits     = nil
        eff.multiHitfTPAt = nil
        eff.crit          = nil
        eff.critCurve     = nil
        eff.critDmg       = nil
        if type(eff.stance) == 'table' then
            eff.stance.crit    = nil
            eff.stance.critDmg = nil
        end
    end

    -- 2. Strip pet hooks on petless specs
    if not PET_SPECS[specKey] then
        eff.eosHeal = nil
        eff.petTp   = nil
    end

    -- 2b. Enforce 100% single-target rule (replace pack* / scaleWithPack hooks)
    if SINGLE_TARGET_ONLY_SPECS[specKey] then
        if eff.packWsdPerMob ~= nil then
            eff.wsd = eff.wsd or eff.packWsdPerMob
            eff.packWsdPerMob = nil
        end
        if eff.packEnmityPerMob ~= nil then
            eff.enmity = eff.enmity or eff.packEnmityPerMob
            eff.packEnmityPerMob = nil
        end
        if eff.packPartyTpPerMob ~= nil then
            eff.partyTp = eff.partyTp or eff.packPartyTpPerMob
            eff.packPartyTpPerMob = nil
        end
        if type(eff.elemFollow) == 'table' then
            eff.elemFollow.scaleWithPack = nil
        end
    end

    -- 3. Strip physical stats on magic/utility WSs
    if not ctx.isPhys then
        eff.atkPct        = nil
        eff.acc           = nil
        eff.racc          = nil
        eff.crit          = nil
        eff.critCurve     = nil
        eff.critDmg       = nil
        eff.defIgnore     = nil
        eff.hits          = nil
        eff.bonusHits     = nil
        eff.multiHitfTPAt = nil
        if type(eff.stance) == 'table' then
            eff.stance.atkPct    = nil
            eff.stance.acc       = nil
            eff.stance.racc      = nil
            eff.stance.crit      = nil
            eff.stance.critDmg   = nil
            eff.stance.defIgnore = nil
        end
    end

    -- 4. Strictly zero MP and zero Refresh on Chi Weaver
    if specKey == 'chiweaver' then
        eff.mpDrain   = nil
        eff.mpToHpPct = nil
        if type(eff.statusBuffs) == 'table' then
            for i = #eff.statusBuffs, 1, -1 do
                if eff.statusBuffs[i].effect == xi.effect.REFRESH then
                    table.remove(eff.statusBuffs, i)
                end
            end
        end
        if type(eff.partyBuffs) == 'table' then
            for i = #eff.partyBuffs, 1, -1 do
                if eff.partyBuffs[i].effect == xi.effect.REFRESH then
                    table.remove(eff.partyBuffs, i)
                end
            end
        end
    end

    return node
end

-----------------------------------
-- Public Tree Builders
-----------------------------------
local function cloneNode(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

function P.buildSpecTree(wsId, archetype, baseNodes, specKey, opts)
    opts = opts or {}
    local ctx = DNA.get(wsId, archetype)

    -- Preserve Dancer Bladewheel's bespoke 12-node Throwing trees (#241-#252)
    if opts.preserveBladewheel and specKey == 'bladewheel' and type(baseNodes) == 'table' and #baseNodes > 0 then
        local out = {}
        for _, n in ipairs(baseNodes) do
            table.insert(out, sanitizeSpecNode(cloneNode(n), 'bladewheel', ctx))
        end
        return out
    end

    -- Full 12-node bespoke synthesis for this (wsId, specKey)
    local t1c1 = buildT1C1(specKey, ctx)
    local t1c2 = buildT1C2(specKey, ctx)
    local t1c3 = buildT1C3(specKey, ctx)
    local t2c1, t3c1, t4c1 = buildCol1Nodes(specKey, ctx)
    local t2c2, t3c2, t4c2 = buildCol2Nodes(specKey, ctx)
    local t2c3, t3c3, t4c3 = buildCol3Nodes(specKey, ctx)

    local nodes = { t1c1, t1c2, t1c3, t2c1, t2c2, t2c3, t3c1, t3c2, t3c3, t4c1, t4c2, t4c3 }
    for i = 1, #nodes do
        nodes[i] = sanitizeSpecNode(nodes[i], specKey, ctx)
    end
    return nodes
end

local S = xi.skill or {}
local WAR_OPEN_SKILLS =
{
    [S.HAND_TO_HAND or 1]  = true,
    [S.DAGGER or 2]        = true,
    [S.SWORD or 3]         = true,
    [S.GREAT_SWORD or 4]   = true,
    [S.AXE or 5]           = true,
    [S.GREAT_AXE or 6]     = true,
    [S.SCYTHE or 7]        = true,
    [S.POLEARM or 8]       = true,
    [S.CLUB or 11]         = true,
    [S.STAFF or 12]        = true,
    [S.ARCHERY or 25]      = true,
    [S.MARKSMANSHIP or 26] = true,
}

local RUN_OPEN_SKILLS =
{
    [S.SWORD or 3]       = true,
    [S.GREAT_SWORD or 4] = true,
    [S.AXE or 5]         = true,
    [S.GREAT_AXE or 6]   = true,
    [S.CLUB or 11]       = true,
}

local SCH_OPEN_SKILLS =
{
    [S.DAGGER or 2] = true,
    [S.CLUB or 11]  = true,
    [S.STAFF or 12] = true,
}

P.ALLOWED_SKILLS_BY_SPEC =
{
    commander      = WAR_OPEN_SKILLS,
    berserker      = WAR_OPEN_SKILLS,
    spartan        = { [S.POLEARM or 8] = true },
    blackbelt      = { [S.HAND_TO_HAND or 1] = true },
    chiweaver      = { [S.HAND_TO_HAND or 1] = true },
    sensei         = { [S.STAFF or 12] = true },
    inquisitor     = RUN_OPEN_SKILLS,
    spellblade     = { [S.GREAT_SWORD or 4] = true },
    lifebinder     = RUN_OPEN_SKILLS,
    medic          = SCH_OPEN_SKILLS,
    sage           = { [S.DAGGER or 2] = true, [S.SWORD or 3] = true, [S.CLUB or 11] = true, [S.STAFF or 12] = true }, -- SCH + BRD Musician
    necromancer    = { [S.SCYTHE or 7] = true },
    astromancer    = { [S.STAFF or 12] = true },
    channeler      = { [S.STAFF or 12] = true },
    scarletweaver  = { [S.SWORD or 3] = true },
    royaltactician = { [S.SWORD or 3] = true },
    bladewheel     = { [S.THROWING or 27] = true, [S.DAGGER or 2] = true, [S.SWORD or 3] = true }, -- DNC Bladewheel + BRD Adventurer
    ronin          = { [S.GREAT_KATANA or 10] = true },
    warlord        = { [S.GREAT_KATANA or 10] = true },
    imperialarcher = { [S.GREAT_KATANA or 10] = true, [S.ARCHERY or 25] = true },
    aegistemplar   = { [S.CLUB or 11] = true },
    dreadnought    = { [S.SCYTHE or 7] = true },
    kagemusha      = { [S.KATANA or 9] = true },
    kurogane       = { [S.KATANA or 9] = true },
    bishop         = { [S.CLUB or 11] = true, [S.STAFF or 12] = true },
    zealot         = { [S.STAFF or 12] = true },
    valkyrie       = { [S.POLEARM or 8] = true },
    templar        = { [S.CLUB or 11] = true },
    magus          = { [S.SWORD or 3] = true, [S.CLUB or 11] = true },
    vampire        = { [S.DAGGER or 2] = true, [S.THROWING or 27] = true },
    celestial      = { [S.STAFF or 12] = true, [S.CLUB or 11] = true },
    pugilist       = { [S.HAND_TO_HAND or 1] = true },
    vanguard       = { [S.HAND_TO_HAND or 1] = true },
    animist        = { [S.HAND_TO_HAND or 1] = true },
    verdant        = { [S.CLUB or 11] = true, [S.STAFF or 12] = true },
    wyvernheart    = { [S.POLEARM or 8] = true },
    alphawarden    = { [S.AXE or 5] = true },
    miragesentinel = { [S.DAGGER or 2] = true },
    flintlock      = { [S.MARKSMANSHIP or 26] = true },
    buccaneer      = { [S.SWORD or 3] = true },
    gambler        = { [S.MARKSMANSHIP or 26] = true, [S.DAGGER or 2] = true },
    huntsman       = { [S.ARCHERY or 25] = true, [S.MARKSMANSHIP or 26] = true },
}

function P.isSpecAllowedForSkill(specKey, skillId)
    if specKey == 'generic' then
        return true
    end
    local map = P.ALLOWED_SKILLS_BY_SPEC[specKey]
    if map == nil then
        return true
    end
    return map[skillId] == true
end

function P.getAllowedSpecsForSkill(skillId)
    local out = {}
    for _, sk in ipairs(P.ALL_SPECS) do
        if P.isSpecAllowedForSkill(sk, skillId) then
            table.insert(out, sk)
        end
    end
    return out
end

function P.buildAllSpecTrees(wsId, archetype, baseNodes, opts)
    local ctx = DNA.get(wsId, archetype)
    local skillId = (ctx.ws and ctx.ws.skill) or 0
    local specNodes = {}
    for _, sk in ipairs(P.ALL_SPECS) do
        if skillId == 0 or P.isSpecAllowedForSkill(sk, skillId) then
            specNodes[sk] = P.buildSpecTree(wsId, archetype, baseNodes, sk, opts)
        end
    end
    return specNodes
end

return P
