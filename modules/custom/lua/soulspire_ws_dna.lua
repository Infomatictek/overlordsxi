-----------------------------------
-- SoulspireXI Per-WS Identity & DNA Registry (#1 - #235)
-- Provides curated lore motifs, secondary epithets, tactical roles,
-- elemental affinities, and derived weapon-group variant indices so
-- every WS has a distinct identity on every spec.
-----------------------------------
require('modules/custom/lua/soulspire_ws_catalog')

local catalog = xi.soulspire and xi.soulspire.wsCatalog

local DNA = {}

local SELF_TARGET_UTIL =
{
    [163] = true, -- Starlight
    [164] = true, -- Moonlight
    [173] = true, -- Dagan
    [190] = true, -- Myrkr
}

-- Curated per-WS DNA: { motif (<=11c), noun (<=11c), role, flavorEle }
-- Roles: opener, stun, breach, vital, flurry, lunge, aoe, wave, siphon, restore, crash, relic
local RAW =
{
    -- Hand-to-Hand (#1-#15, #231)
    [1]   = { 'Combo',     'Tempo',     'opener',  'WIND'    },
    [2]   = { 'Tackle',    'Concuss',   'stun',    'EARTH'   },
    [3]   = { 'One-Inch',  'Pulse',     'breach',  'LIGHT'   },
    [4]   = { 'Backhand',  'Slap',      'vital',   'WIND'    },
    [5]   = { 'Raging',    'Barrage',   'flurry',  'THUNDER' },
    [6]   = { 'Whirlwind', 'Vortex',    'aoe',     'FIRE'    },
    [7]   = { 'Howling',   'Thunder',   'crash',   'THUNDER' },
    [8]   = { 'Dragon',    'Fang',      'lunge',   'FIRE'    },
    [9]   = { 'Asura',     'Eightfold', 'flurry',  'FIRE'    },
    [10]  = { 'Heaven',    'Spharai',   'relic',   'LIGHT'   },
    [11]  = { 'Ascetic',   'Mantra',    'vital',   'LIGHT'   },
    [12]  = { 'Puppet',    'Thread',    'flurry',  'WIND'    },
    [13]  = { 'Tornado',   'Cyclone',   'lunge',   'WIND'    },
    [14]  = { 'Victory',   'Triumph',   'relic',   'LIGHT'   },
    [15]  = { 'Shijin',    'Meridian',  'siphon',  'LIGHT'   },
    [231] = { 'Maru',      'Mandala',   'crash',   'EARTH'   },

    -- Dagger (#16-#31, #224, #232)
    [16]  = { 'Hornet',    'Stinger',   'opener',  'EARTH'   },
    [17]  = { 'Viper',     'Venom',     'siphon',  'WATER'   },
    [18]  = { 'Shadow',    'Pin',       'stun',    'DARK'    },
    [19]  = { 'Gust',      'Zephyr',    'wave',    'WIND'    },
    [20]  = { 'Squall',    'Tempest',   'aoe',     'WIND'    },
    [21]  = { 'Siphon',    'Tap',       'restore', 'DARK'    },
    [22]  = { 'Void',      'Leech',     'restore', 'DARK'    },
    [23]  = { 'Waltzing',  'Sabre',     'flurry',  'WIND'    },
    [24]  = { 'Mako',      'Jaws',      'lunge',   'WATER'   },
    [25]  = { 'Ripper',    'Artery',    'vital',   'DARK'    },
    [26]  = { 'Mercy',     'Mandau',    'relic',   'DARK'    },
    [27]  = { 'Mandalic',  'Stiletto',  'vital',   'LIGHT'   },
    [28]  = { 'Mordant',   'Lyre',      'stun',    'WIND'    },
    [29]  = { 'Pyrrhic',   'Duet',      'flurry',  'ICE'     },
    [30]  = { 'Aeolian',   'Gale',      'aoe',     'WIND'    },
    [31]  = { 'Rudra',     'Maelstrom', 'relic',   'DARK'    },
    [224] = { 'Exenter',   'Tendon',    'breach',  'WIND'    },
    [232] = { 'Ruthless',  'Cutthroat', 'crash',   'DARK'    },

    -- Sword (#32-#47, #225, #226)
    [32]  = { 'Quicksilver','Riposte',  'opener',  'WIND'    },
    [33]  = { 'Cinder',    'Ember',     'wave',    'FIRE'    },
    [34]  = { 'Crimson',   'Lotus',     'wave',    'FIRE'    },
    [35]  = { 'Pommel',    'Hilt',      'stun',    'THUNDER' },
    [36]  = { 'Lustrous',  'Dawn',      'wave',    'LIGHT'   },
    [37]  = { 'Seraphic',  'Wing',      'wave',    'LIGHT'   },
    [38]  = { 'Orbit',     'Arc',       'aoe',     'WIND'    },
    [39]  = { 'Soul',      'Pneuma',    'restore', 'LIGHT'   },
    [40]  = { 'Vorpal',    'Keen',      'vital',   'THUNDER' },
    [41]  = { 'Swift',     'Triple',    'flurry',  'DARK'    },
    [42]  = { 'Savage',    'Rift',      'lunge',   'THUNDER' },
    [43]  = { 'Caliburn',  'Round',     'relic',   'LIGHT'   },
    [44]  = { 'Thorn',     'Blossom',   'breach',  'THUNDER' },
    [45]  = { 'Atoning',   'Burtgang',  'restore', 'LIGHT'   },
    [46]  = { 'Tizona',    'Expiate',   'crash',   'ICE'     },
    [47]  = { 'Sanguine',  'Blood',     'siphon',  'DARK'    },
    [225] = { 'Cygne',     'Swan',      'relic',   'LIGHT'   },
    [226] = { 'Requiem',   'Solace',    'flurry',  'DARK'    },

    -- Great Sword (#48-#61)
    [48]  = { 'Cleaver',   'Momentum',  'opener',  'EARTH'   },
    [49]  = { 'Colossus',  'Might',     'vital',   'THUNDER' },
    [50]  = { 'Hoarfrost', 'Rime',      'wave',    'ICE'     },
    [51]  = { 'Glacier',   'Tundra',    'wave',    'ICE'     },
    [52]  = { 'Tremor',    'Slumber',   'aoe',     'DARK'    },
    [53]  = { 'Crescent',  'Lunar',     'lunge',   'DARK'    },
    [54]  = { 'Sickle',    'Waning',    'breach',  'DARK'    },
    [55]  = { 'Greatswing','Gyrating',  'lunge',   'LIGHT'   },
    [56]  = { 'Tectonic',  'Quake',     'crash',   'EARTH'   },
    [57]  = { 'Scourge',   'Ragnarok',  'relic',   'LIGHT'   },
    [58]  = { 'Herculean', 'Titan',     'stun',    'ICE'     },
    [59]  = { 'Torcleaver','Caladbolg', 'relic',   'LIGHT'   },
    [60]  = { 'Resolve',   'Fivefold',  'flurry',  'THUNDER' },
    [61]  = { 'Dimidiate', 'Bifurcate', 'relic',   'WIND'    },

    -- Axe (#64-#77)
    [64]  = { 'Hatchet',   'Frenzy',    'opener',  'WIND'    },
    [65]  = { 'Skullcrack','Bludgeon',  'stun',    'THUNDER' },
    [66]  = { 'Chinook',   'Draft',     'siphon',  'WIND'    },
    [67]  = { 'Avalanche', 'Landslide', 'crash',   'EARTH'   },
    [68]  = { 'Tomahawk',  'Gyro',      'lunge',   'FIRE'    },
    [69]  = { 'Rampage',   'Fivecut',   'flurry',  'EARTH'   },
    [70]  = { 'Calamity',  'Ruin',      'crash',   'THUNDER' },
    [71]  = { 'Mistral',   'Hurl',      'lunge',   'LIGHT'   },
    [72]  = { 'Decimate',  'Trislash',  'flurry',  'FIRE'    },
    [73]  = { 'Onslaught', 'Guttler',   'relic',   'DARK'    },
    [74]  = { 'Primal',    'Feral',     'wave',    'LIGHT'   },
    [75]  = { 'Bora',      'Snare',     'stun',    'ICE'     },
    [76]  = { 'Cloudsplit','Bolt',      'wave',    'THUNDER' },
    [77]  = { 'Ruinator',  'Quadrend',  'breach',  'ICE'     },

    -- Great Axe (#80-#93)
    [80]  = { 'Buckler',   'Shatter',   'breach',  'ICE'     },
    [81]  = { 'Ironstorm', 'Galeaxe',   'opener',  'WIND'    },
    [82]  = { 'Sturmwind', 'Twinaxe',   'lunge',   'EARTH'   },
    [83]  = { 'Cuirass',   'Sunder',    'breach',  'ICE'     },
    [84]  = { 'Razor',     'Bevel',     'vital',   'DARK'    },
    [85]  = { 'Haft',      'Disarm',    'stun',    'WATER'   },
    [86]  = { 'Stampede',  'Charge',    'flurry',  'ICE'     },
    [87]  = { 'Grandbreak','Cripple',   'breach',  'ICE'     },
    [88]  = { 'Steelgust', 'Steel',     'crash',   'WIND'    },
    [89]  = { 'Metatron',  'Bravura',   'relic',   'LIGHT'   },
    [90]  = { 'Sovereign', 'Conqueror', 'relic',   'WIND'    },
    [91]  = { 'Fellcleave','Reaper',    'aoe',     'WIND'    },
    [92]  = { 'Ukko',      'Stormlord', 'vital',   'THUNDER' },
    [93]  = { 'Upheaval',  'Catapult',  'flurry',  'FIRE'    },

    -- Scythe (#96-#109)
    [96]  = { 'Sicklecut', 'Shear',     'opener',  'EARTH'   },
    [97]  = { 'Reaping',   'Blight',    'wave',    'DARK'    },
    [98]  = { 'Deathshade','Umbra',     'siphon',  'DARK'    },
    [99]  = { 'Nightmare', 'Dusk',      'stun',    'DARK'    },
    [100] = { 'Thresher',  'Whorl',     'aoe',     'EARTH'   },
    [101] = { 'Crescentscy','Decap',    'vital',   'THUNDER' },
    [102] = { 'Guillotine','Gag',       'stun',    'ICE'     },
    [103] = { 'Crossreap', 'Crux',      'lunge',   'ICE'     },
    [104] = { 'Abyssal',   'Spiral',    'crash',   'WATER'   },
    [105] = { 'Apocalypse','Dread',     'relic',   'DARK'    },
    [106] = { 'Insurgent', 'Revolt',    'flurry',  'FIRE'    },
    [107] = { 'Infernal',  'Nether',    'wave',    'DARK'    },
    [108] = { 'Quietus',   'Silence',   'breach',  'DARK'    },
    [109] = { 'Entropy',   'Null',      'siphon',  'DARK'    },

    -- Polearm (#112-#125)
    [112] = { 'Twinlance', 'Jab',       'opener',  'THUNDER' },
    [113] = { 'Spark',     'Volt',      'wave',    'THUNDER' },
    [114] = { 'Raiden',    'Fulmen',    'wave',    'THUNDER' },
    [115] = { 'Sweep',     'Trip',      'stun',    'THUNDER' },
    [116] = { 'Penta',     'Quintet',   'flurry',  'DARK'    },
    [117] = { 'Impale',    'Skewerpoint','vital',  'WATER'   },
    [118] = { 'Trident',   'Perforate', 'vital',   'THUNDER' },
    [119] = { 'Wheeling',  'Vault',     'breach',  'LIGHT'   },
    [120] = { 'Impulse',   'Joust',     'lunge',   'EARTH'   },
    [121] = { 'Geirskogul','Gungnir',   'relic',   'LIGHT'   },
    [122] = { 'Drakesbane','Wyrmslay',  'flurry',  'FIRE'    },
    [123] = { 'Sonic',     'Shockcone', 'aoe',     'WIND'    },
    [124] = { 'Camlann',   'Rhongomyn', 'relic',   'LIGHT'   },
    [125] = { 'Stardiver', 'Meteor',    'crash',   'DARK'    },

    -- Katana (#128-#141)
    [128] = { 'Rin',       'Edge',      'opener',  'LIGHT'   },
    [129] = { 'Retsu',     'Nerve',     'stun',    'EARTH'   },
    [130] = { 'Teki',      'Torrent',   'wave',    'WATER'   },
    [131] = { 'To',        'Frostedge', 'wave',    'ICE'     },
    [132] = { 'Chi',       'Loam',      'wave',    'EARTH'   },
    [133] = { 'Ei',        'Shade',     'siphon',  'DARK'    },
    [134] = { 'Jin',       'Galeblade', 'flurry',  'WIND'    },
    [135] = { 'Ten',       'Firmament', 'crash',   'DARK'    },
    [136] = { 'Ku',        'Voidcut',   'flurry',  'DARK'    },
    [137] = { 'Metsu',     'Kikoku',    'relic',   'DARK'    },
    [138] = { 'Kamu',      'Nagi',      'breach',  'THUNDER' },
    [139] = { 'Yu',        'Miasma',    'wave',    'WATER'   },
    [140] = { 'Hi',        'Kannagi',   'vital',   'DARK'    },
    [141] = { 'Shun',      'Flashstep', 'flurry',  'LIGHT'   },

    -- Great Katana (#144-#157)
    [144] = { 'Enpi',      'Swallow',   'opener',  'LIGHT'   },
    [145] = { 'Hobaku',    'Shackle',   'stun',    'THUNDER' },
    [146] = { 'Goten',     'Skybolt',   'wave',    'THUNDER' },
    [147] = { 'Kagero',    'Heatwave',  'wave',    'FIRE'    },
    [148] = { 'Jinpu',     'Tempestcut','wave',    'WIND'    },
    [149] = { 'Koki',      'Sunbeam',   'wave',    'LIGHT'   },
    [150] = { 'Yukikaze',  'Blizzard',  'stun',    'ICE'     },
    [151] = { 'Gekko',     'Moonlight', 'lunge',   'WATER'   },
    [152] = { 'Kasha',     'Firewheel', 'vital',   'FIRE'    },
    [153] = { 'Kaiten',    'Murakumo',  'relic',   'LIGHT'   },
    [154] = { 'Rana',      'Kogarasu',  'flurry',  'ICE'     },
    [155] = { 'Ageha',     'Swallowtail','breach', 'DARK'    },
    [156] = { 'Fudo',      'Masamune',  'relic',   'LIGHT'   },
    [157] = { 'Shoha',     'Splithelm', 'crash',   'WIND'    },

    -- Club (#160-#175)
    [160] = { 'Gleaming',  'Dawnmace',  'wave',    'LIGHT'   },
    [161] = { 'Cherub',    'Halo',      'wave',    'LIGHT'   },
    [162] = { 'Concussor', 'Rattle',    'stun',    'THUNDER' },
    [163] = { 'Starlight', 'Astral',    'restore', 'LIGHT'   },
    [164] = { 'Moonbeam',  'Selene',    'restore', 'LIGHT'   },
    [165] = { 'Cranium',   'Fracture',  'breach',  'FIRE'    },
    [166] = { 'Truestrike','Deadeye',   'vital',   'WIND'    },
    [167] = { 'Judgment',  'Gavel',     'crash',   'THUNDER' },
    [168] = { 'Hexa',      'Sixfold',   'flurry',  'LIGHT'   },
    [169] = { 'Blackhalo', 'Eclipse',   'lunge',   'DARK'    },
    [170] = { 'Randgrith', 'Mjollnir',  'relic',   'LIGHT'   },
    [171] = { 'Mystic',    'Yagrush',   'siphon',  'LIGHT'   },
    [172] = { 'Flashnova', 'Flare',     'wave',    'LIGHT'   },
    [173] = { 'Dagan',     'Gambantein','restore', 'LIGHT'   },
    [174] = { 'Realmrazer','Sevenfold', 'flurry',  'THUNDER' },
    [175] = { 'Exudation', 'Idris',     'breach',  'DARK'    },

    -- Staff (#176-#191, #235)
    [176] = { 'Quarter',   'Oak',       'opener',  'EARTH'   },
    [177] = { 'Boulder',   'Basalt',    'wave',    'EARTH'   },
    [178] = { 'Tremorstaf','Seismic',   'aoe',     'EARTH'   },
    [179] = { 'Starburst', 'Nebula',    'wave',    'DARK'    },
    [180] = { 'Sunburst',  'Corona',    'wave',    'LIGHT'   },
    [181] = { 'Carapace',  'Crack',     'breach',  'WIND'    },
    [182] = { 'Fullswing', 'Pendulum',  'lunge',   'FIRE'    },
    [183] = { 'Spirittake','Animus',    'siphon',  'DARK'    },
    [184] = { 'Retribute', 'Penance',   'crash',   'WATER'   },
    [185] = { 'Tartarus',  'Claustrum', 'relic',   'WATER'   },
    [186] = { 'Vidohunir', 'Laevateinn','wave',    'DARK'    },
    [187] = { 'Bliss',     'Nirvana',   'wave',    'LIGHT'   },
    [188] = { 'Omniscient','Tupsimati', 'siphon',  'DARK'    },
    [189] = { 'Cataclysm', 'Doomwave',  'aoe',     'DARK'    },
    [190] = { 'Myrkr',     'Hvergelmir','restore', 'ICE'     },
    [191] = { 'Soulbreak', 'Fourfold',  'flurry',  'DARK'    },
    [235] = { 'Oshala',    'Oracle',    'vital',   'LIGHT'   },

    -- Archery (#192-#203)
    [192] = { 'Firearrow', 'Kindle',    'wave',    'FIRE'    },
    [193] = { 'Bodkin',    'Armorbow',  'breach',  'LIGHT'   },
    [194] = { 'Dulling',   'Blunt',     'stun',    'FIRE'    },
    [196] = { 'Sidewind',  'Serpent',   'lunge',   'WATER'   },
    [197] = { 'Blastbow',  'Concussbow','opener',  'ICE'     },
    [198] = { 'Higharc',   'Volley',    'vital',   'LIGHT'   },
    [199] = { 'Empyreal',  'Skyshot',   'crash',   'LIGHT'   },
    [200] = { 'Namas',     'Yoichi',    'relic',   'LIGHT'   },
    [201] = { 'Refulgent', 'Sunshaft',  'lunge',   'LIGHT'   },
    [202] = { 'Jishnu',    'Gandiva',   'flurry',  'LIGHT'   },
    [203] = { 'Apex',      'Pinpoint',  'breach',  'THUNDER' },

    -- Marksmanship (#208-#221)
    [208] = { 'Hotshot',   'Incendiary','wave',    'FIRE'    },
    [209] = { 'Splitshot', 'Buckshot',  'breach',  'LIGHT'   },
    [210] = { 'Snipershot','Crosshair', 'vital',   'FIRE'    },
    [212] = { 'Slugshot',  'Caliber',   'crash',   'WATER'   },
    [213] = { 'Blastshot', 'Muzzle',    'opener',  'ICE'     },
    [214] = { 'Heavyshot', 'Cannon',    'vital',   'FIRE'    },
    [215] = { 'Detonator', 'Shell',     'crash',   'FIRE'    },
    [216] = { 'Coronach',  'Annihilate','relic',   'DARK'    },
    [217] = { 'Trueflight','Gastraphet','wave',    'LIGHT'   },
    [218] = { 'Leaden',    'Deathpen',  'siphon',  'DARK'    },
    [219] = { 'Numbing',   'Cryoshot',  'stun',    'ICE'     },
    [220] = { 'Wildfire',  'Armageddon','wave',    'FIRE'    },
    [221] = { 'Laststand', 'Doubletap', 'flurry',  'LIGHT'   },

    -- Throwing (#241-#252)
    [241] = { 'Pirouette', 'Gyre',      'opener',  'WIND'    },
    [242] = { 'Whirl',     'Ballroom',  'restore', 'LIGHT'   },
    [243] = { 'Ricochet',  'Tango',     'flurry',  'WIND'    },
    [244] = { 'Scarlet',   'Samba',     'siphon',  'DARK'    },
    [245] = { 'Stutter',   'Disc',      'breach',  'EARTH'   },
    [246] = { 'Feather',   'Plume',     'vital',   'WIND'    },
    [247] = { 'Bolero',    'Twister',   'wave',    'WIND'    },
    [248] = { 'Flamenco',  'Castanet',  'crash',   'FIRE'    },
    [249] = { 'Tarantel',  'Frenzystep','flurry',  'THUNDER' },
    [250] = { 'Grandjete', 'Etoile',    'relic',   'LIGHT'   },
    [251] = { 'Aurora',    'Fandango',  'flurry',  'LIGHT'   },
    [252] = { 'Terpsich',  'Muse',      'wave',    'LIGHT'   },
}

local ROLE_INDEX =
{
    opener  = 1,
    stun    = 2,
    breach  = 3,
    vital   = 4,
    flurry  = 5,
    lunge   = 6,
    aoe     = 7,
    wave    = 8,
    siphon  = 9,
    restore = 10,
    crash   = 11,
    relic   = 12,
}

-- Precompute deterministic 1-based ordinal per weapon so Col 2 & Col 3 rotate cleanly
local weaponOrdinal = {}
local roleSubIdx    = {}
do
    local skillCount = {}
    local skillRoleCount = {}
    if catalog and catalog.orderedIds then
        for _, id in ipairs(catalog.orderedIds) do
            local w = catalog.byId[id]
            if w and RAW[id] then
                local sk = w.skill or 0
                skillCount[sk] = (skillCount[sk] or 0) + 1
                weaponOrdinal[id] = skillCount[sk]
                local srKey = sk .. ':' .. RAW[id][3]
                skillRoleCount[srKey] = (skillRoleCount[srKey] or 0) + 1
                roleSubIdx[id] = skillRoleCount[srKey]
            end
        end
    end
end

local STAT_ORDER = { 'str', 'dex', 'vit', 'agi', 'int', 'mnd', 'chr' }

local function round2(v)
    return math.floor(v * 100 + 0.5) / 100
end

function DNA.get(wsId, archetype)
    local ws   = catalog and catalog.byId and catalog.byId[wsId]
    local orig = (ws and ws.orig) or {}
    local raw  = RAW[wsId] or { (ws and ws.name or 'Strike'):sub(1, 10), 'Edge', 'crash', 'LIGHT' }

    local wsType = (ws and ws.wsType) or 'physical'
    local isUtil = (wsType == 'utility')
    local isMag    = (wsType == 'magic')
    local isHybrid = (wsType == 'hybrid')
    local isRanged = (wsType == 'ranged') or (ws and (ws.skill == xi.skill.ARCHERY or ws.skill == xi.skill.MARKSMANSHIP or (ws.skill == xi.skill.THROWING and not isMag)))
    local isPhys   = not isMag and not isUtil

    local wscStats = {}
    if orig.wsc then
        for _, st in ipairs(STAT_ORDER) do
            local wt = orig.wsc[st]
            if wt and wt > 0 then
                table.insert(wscStats, { stat = st, weight = wt })
            end
        end
        table.sort(wscStats, function(a, b)
            if a.weight ~= b.weight then
                return a.weight > b.weight
            end
            return a.stat < b.stat
        end)
    end

    local f = orig.ftp or { 1.0, 1.5, 2.0 }
    local curve = { 1.0, 1.5, 2.0 }
    for i = 1, 3 do
        local ov = f[i] or 1.0
        if ov > 1.0 then
            curve[i] = round2(1.0 + (ov - 1.0) * 1.15)
        else
            curve[i] = round2(1.0 + (0.45 + (i - 1) * 0.35))
        end
    end
    if curve[2] <= curve[1] then
        curve[2] = round2(curve[1] + 0.35)
    end
    if curve[3] <= curve[2] then
        curve[3] = round2(curve[2] + 0.45)
    end

    local eleUpper = (ws and ws.elementName and string.upper(ws.elementName)) or raw[4] or 'LIGHT'
    local ord  = weaponOrdinal[wsId] or wsId
    local rIdx = ROLE_INDEX[raw[3]] or 1
    local v2   = ((ord - 1) % 4) + 1
    local v3   = (((ord * 3) + rIdx) % 4) + 1

    return
    {
        wsId       = wsId,
        ws         = ws,
        orig       = orig,
        motif      = raw[1],
        noun       = raw[2],
        role       = raw[3],
        roleIdx    = rIdx,
        subIdx     = roleSubIdx[wsId] or 1,
        ord        = ord,
        v2         = v2,
        v3         = v3,
        ele        = eleUpper,
        eleLabel   = eleUpper:sub(1, 1) .. eleUpper:sub(2):lower(),
        wsType     = wsType,
        isUtil     = isUtil,
        isSelfUtil = SELF_TARGET_UTIL[wsId] == true,
        isMag      = isMag,
        isHybrid   = isHybrid,
        isRanged   = isRanged,
        isPhys     = isPhys,
        numHits    = orig.numHits or 1,
        aoe        = orig.aoe == true,
        debuff     = orig.debuff,
        aftermath  = orig.aftermath,
        drainHp    = orig.drainHp == true,
        drainMp    = orig.drainMp == true,
        ftpCurve   = curve,
        stat1      = (wscStats[1] and wscStats[1].stat) or (isMag and 'int' or (isUtil and 'mnd' or 'str')),
        stat2      = (wscStats[2] and wscStats[2].stat) or nil,
    }
end

return DNA
