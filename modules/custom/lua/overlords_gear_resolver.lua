-----------------------------------
-- OverlordsXI Soul-Driven Runtime Gear Resolver & Scoring Engine
--
-- Scores authoritative LandSandBoat equipment directly from live item stats,
-- modifiers, weapon DPS/subskill, shield properties, and acquisition sources
-- (NPC shops, crafting recipes, normal mob drops vs NM/BCNM/EX prestige),
-- weighted dynamically by the active Soul's actual combat mechanics.
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.gearResolver = xi.overlords.gearResolver or {}

local resolver = xi.overlords.gearResolver

-- Authoritative LandSandBoat modifier IDs (with xi.mod lookup first)
local function M(name, fallback)
    return (xi.mod and xi.mod[name]) or fallback
end

local MOD =
{
    DEF                = M('DEF', 1),
    HP                 = M('HP', 2),
    HPP                = M('HPP', 3),
    MP                 = M('MP', 5),
    MPP                = M('MPP', 6),
    STR                = M('STR', 8),
    DEX                = M('DEX', 9),
    VIT                = M('VIT', 10),
    AGI                = M('AGI', 11),
    INT                = M('INT', 12),
    MND                = M('MND', 13),
    CHR                = M('CHR', 14),
    ATT                = M('ATT', 23),
    RATT               = M('RATT', 24),
    ACC                = M('ACC', 25),
    RACC               = M('RACC', 26),
    ENMITY             = M('ENMITY', 27),
    MATT               = M('MATT', 28),
    MDEF               = M('MDEF', 29),
    MACC               = M('MACC', 30),
    MEVA               = M('MEVA', 31),
    ATTP               = M('ATTP', 62),
    DEFP               = M('DEFP', 63),
    RATTP              = M('RATTP', 66),
    EVA                = M('EVA', 68),
    STORETP            = M('STORETP', 73),
    HTH                = M('HTH', 80),
    DAGGER             = M('DAGGER', 81),
    SWORD              = M('SWORD', 82),
    GSWORD             = M('GSWORD', 83),
    AXE                = M('AXE', 84),
    GAXE               = M('GAXE', 85),
    SCYTHE             = M('SCYTHE', 86),
    POLEARM            = M('POLEARM', 87),
    KATANA             = M('KATANA', 88),
    GKATANA            = M('GKATANA', 89),
    CLUB               = M('CLUB', 90),
    STAFF              = M('STAFF', 91),
    ARCHERY            = M('ARCHERY', 104),
    MARKSMANSHIP       = M('MARKSMANSHIP', 105),
    THROW              = M('THROW', 106),
    SHIELD             = M('SHIELD', 109),
    PARRY              = M('PARRY', 110),
    HEALING            = M('HEALING', 112),
    ENHANCING          = M('ENHANCING', 113),
    ENFEEBLING         = M('ENFEEBLING', 114),
    ELEMENTAL          = M('ELEMENTAL', 115),
    DARK               = M('DARK', 116),
    SUMMONING          = M('SUMMONING', 117),
    NINJUTSU           = M('NINJUTSU', 118),
    SINGING            = M('SINGING', 119),
    STRING             = M('STRING', 120),
    WIND               = M('WIND', 121),
    BLUE               = M('BLUE', 122),
    DMG                = M('DMG', 160),
    DMGPHYS            = M('DMGPHYS', 161),
    DMGBREATH          = M('DMGBREATH', 162),
    DMGMAGIC           = M('DMGMAGIC', 163),
    CRITHITRATE        = M('CRITHITRATE', 165),
    SPELLINTERRUPT     = M('SPELLINTERRUPT', 168),
    FASTCAST           = M('FASTCAST', 170),
    DUAL_WIELD         = M('DUAL_WIELD', 259),
    DOUBLE_ATTACK      = M('DOUBLE_ATTACK', 288),
    SUBTLE_BLOW        = M('SUBTLE_BLOW', 289),
    COUNTER            = M('COUNTER', 291),
    TRIPLE_ATTACK      = M('TRIPLE_ATTACK', 302),
    MAGIC_DAMAGE       = M('MAGIC_DAMAGE', 311),
    RAPID_SHOT         = M('RAPID_SHOT', 359),
    SNAPSHOT           = M('SNAPSHOT', 365),
    REFRESH            = M('REFRESH', 369),
    REGEN              = M('REGEN', 370),
    CURE_POTENCY       = M('CURE_POTENCY', 374),
    HASTE_GEAR         = M('HASTE_GEAR', 384),
    CRIT_DMG_INCREASE  = M('CRIT_DMG_INCREASE', 421),
    QUAD_ATTACK        = M('QUAD_ATTACK', 430),
    ALL_WSDMG_ALL_HITS = M('ALL_WSDMG_ALL_HITS', 840),
    INQUARTATA         = M('INQUARTATA', 963),
}

resolver.MOD = MOD

-- Mods stored in basis points (100 = 1%)
local BASIS_POINT_MODS =
{
    [MOD.HASTE_GEAR] = true,
    [MOD.DMG]        = true,
    [MOD.DMGPHYS]    = true,
    [MOD.DMGMAGIC]   = true,
    [MOD.DMGBREATH]  = true,
}

-- Damage-taken mods are negative when beneficial (e.g. -500 = -5% DT)
local INVERTED_SIGN_MODS =
{
    [MOD.DMG]       = true,
    [MOD.DMGPHYS]   = true,
    [MOD.DMGMAGIC]  = true,
    [MOD.DMGBREATH] = true,
}

-- Jobs that naturally have no base MP pool
local ZERO_MP_JOBS =
{
    [1]  = true, -- WAR
    [2]  = true, -- MNK
    [6]  = true, -- THF
    [9]  = true, -- BST
    [10] = true, -- BRD
    [11] = true, -- RNG
    [12] = true, -- SAM
    [13] = true, -- NIN
    [14] = true, -- DRG
    [17] = true, -- COR
    [18] = true, -- PUP
    [19] = true, -- DNC
}

-- ItemFlag bitmask fallbacks (matches data/enums/item_flag.yaml)
local FLAG_GM_ONLY    = 0x00000002
local FLAG_NO_AUCTION = 0x00000040
local FLAG_EXCLUSIVE  = 0x00004000
local FLAG_RARE       = 0x00008000

-- Slot bitmask corresponding to BattleEntity SLOTTYPE
resolver.SLOT_BIT =
{
    [0]  = 1,     -- MAIN
    [1]  = 2,     -- SUB
    [2]  = 4,     -- RANGED
    [3]  = 8,     -- AMMO
    [4]  = 16,    -- HEAD
    [5]  = 32,    -- BODY
    [6]  = 64,    -- HANDS
    [7]  = 128,   -- LEGS
    [8]  = 256,   -- FEET
    [9]  = 512,   -- NECK
    [10] = 1024,  -- WAIST
    [11] = 2048,  -- EAR1
    [12] = 4096,  -- EAR2
    [13] = 8192,  -- RING1
    [14] = 16384, -- RING2
    [15] = 32768, -- BACK
}

-- Subskill constants (matches battle_entity.h SUBSKILLTYPE)
resolver.SUBSKILL =
{
    XBOW_SHORTBOW = 0,
    GUN           = 1,
    CANNON        = 2,
    SHURIKEN      = 3,
    LONGBOW       = 4,
    ANIMATOR      = 10,
    ANIMATOR_II   = 11,
}

-- Prestige name patterns used only as secondary signal when full catalog
-- acquisition tables are unavailable (fallback mode).
local PRESTIGE_NAME_WORDS =
{
    'relic', 'mythic', 'empyrean', 'aeonic', 'ambuscade',
    'abjuration', 'dynamis', 'salvage', 'nyzul',
    'kaja ', 'malignance', 'crepuscular', 'sakpata',
    'ridill', 'kraken club', 'defending ring', 'speed belt',
    'black belt', 'byakko', 'seiryu', 'suzaku', 'genbu',
    'kirin', 'homam', 'nashira', 'ares', 'skadi', 'usukane',
    'marduk', 'morrigan', 'valhalla', 'hauteclaire', 'algol',
    'valkyrie', 'dusk', 'hecatomb', 'adaman hauberk', 'armada',
}

local NOVELTY_NAME_WORDS =
{
    'moogle', 'chocobo shirt', 'destrier', 'nomad', 'dream ',
    'swimsuit', 'yukata', 'mandragora suit', 'crab ', 'pumpkin',
    'witch hat', 'coven hat', 'event', 'anniversary', 'tidal talisman',
    'decennial', 'novennial', 'kakai', 'shobuhouou', 'track shirt',
    'hearth', 'jingle', 'snowy', 'festive', 'carbuncle mitts',
}

local function containsAny(haystack, needles)
    local lower = string.lower(tostring(haystack or ''))
    for _, word in ipairs(needles) do
        if string.find(lower, word, 1, true) then
            return true
        end
    end
    return false
end

local function hasBit(mask, bitVal)
    if mask == nil or bitVal == nil or bitVal <= 0 then
        return false
    end
    return math.floor(mask / bitVal) % 2 == 1
end

local function addWeight(weights, modId, delta)
    if modId == nil or delta == nil or delta == 0 then
        return
    end
    weights[modId] = (weights[modId] or 0) + delta
end

local function setMinWeight(weights, modId, minVal)
    if modId == nil or minVal == nil then
        return
    end
    if (weights[modId] or 0) < minVal then
        weights[modId] = minVal
    end
end

-----------------------------------
-- Collect Soul Passive Mods Safely
-----------------------------------
local function collectSoulMods(player, specEntry, targetLevel)
    local merged = {}
    if specEntry == nil or type(specEntry.mods) ~= 'function' then
        return merged
    end

    local function absorb(list)
        if type(list) ~= 'table' then
            return
        end
        for _, pair in ipairs(list) do
            if type(pair) == 'table' and pair[1] ~= nil and pair[2] ~= nil then
                local id  = tonumber(pair[1])
                local val = tonumber(pair[2])
                if id ~= nil and val ~= nil then
                    if merged[id] == nil or math.abs(val) > math.abs(merged[id]) then
                        merged[id] = val
                    end
                end
            end
        end
    end

    -- Call with nil first (wiki/canonical mode exposes conditional weapon-gated mods)
    local okNil, nilMods = pcall(specEntry.mods, nil, targetLevel)
    if okNil then
        absorb(nilMods)
    end

    -- Also call with live player if available
    if player ~= nil then
        local okLive, liveMods = pcall(specEntry.mods, player, targetLevel)
        if okLive then
            absorb(liveMods)
        end
    end

    return merged
end

-----------------------------------
-- Base Role Weight Presets
-----------------------------------
local function buildBaseWeights(roleKey)
    local w = {}

    if roleKey == 'tank' then
        w[MOD.DEF]            = 1.6
        w[MOD.DEFP]           = 4.5
        w[MOD.HP]             = 0.75
        w[MOD.HPP]            = 5.0
        w[MOD.VIT]            = 3.2
        w[MOD.DMG]            = 18.0 -- inverted: -5% DT (-500) => +90
        w[MOD.DMGPHYS]        = 13.0
        w[MOD.DMGMAGIC]       = 11.0
        w[MOD.DMGBREATH]      = 4.0
        w[MOD.ENMITY]         = 5.5
        w[MOD.EVA]            = 1.8
        w[MOD.MEVA]           = 1.8
        w[MOD.MDEF]           = 3.0
        w[MOD.PARRY]          = 3.5
        w[MOD.SHIELD]         = 4.0
        w[MOD.COUNTER]        = 3.0
        w[MOD.INQUARTATA]     = 4.0
        w[MOD.SPELLINTERRUPT] = 1.2
        w[MOD.HASTE_GEAR]     = 4.5
        w[MOD.ACC]            = 1.2
        w[MOD.AGI]            = 1.6
        w[MOD.STR]            = 0.8
        w[MOD.DEX]            = 0.8
        w[MOD.REGEN]          = 6.0
        w.weaponDps           = 2.5
        w.weaponDmg           = 0.4
        w.shieldScore         = 6.0
    elseif roleKey == 'ws' then
        w[MOD.STR]                = 5.5
        w[MOD.DEX]                = 3.8
        w[MOD.ATT]                = 2.2
        w[MOD.ATTP]               = 6.0
        w[MOD.ACC]                = 2.0
        w[MOD.ALL_WSDMG_ALL_HITS] = 14.0
        w[MOD.CRITHITRATE]        = 6.5
        w[MOD.CRIT_DMG_INCREASE]  = 6.0
        w[MOD.DOUBLE_ATTACK]      = 7.0
        w[MOD.TRIPLE_ATTACK]      = 10.0
        w[MOD.QUAD_ATTACK]        = 13.0
        w[MOD.STORETP]            = 2.8
        w[MOD.HASTE_GEAR]         = 3.5
        w[MOD.DEF]                = 0.25
        w[MOD.HP]                 = 0.15
        w[MOD.ENMITY]             = -0.6
        w.weaponDps               = 8.0
        w.weaponDmg               = 1.8
        w.shieldScore             = 0.5
    elseif roleKey == 'ranged' then
        w[MOD.RACC]              = 3.8
        w[MOD.RATT]              = 3.2
        w[MOD.RATTP]             = 6.0
        w[MOD.AGI]               = 4.5
        w[MOD.STR]               = 3.0
        w[MOD.SNAPSHOT]          = 4.5
        w[MOD.RAPID_SHOT]        = 3.5
        w[MOD.STORETP]           = 5.5
        w[MOD.CRITHITRATE]       = 5.0
        w[MOD.CRIT_DMG_INCREASE] = 4.5
        w[MOD.ARCHERY]           = 3.5
        w[MOD.MARKSMANSHIP]      = 3.5
        w[MOD.THROW]             = 3.5
        w[MOD.ENMITY]            = -1.5
        w[MOD.DEF]               = 0.3
        w[MOD.HP]                = 0.2
        w.weaponDps              = 2.0
        w.rangedDps              = 18.0
        w.ammoDmg                = 2.8
        w.shieldScore            = 0.5
    elseif roleKey == 'caster' then
        w[MOD.INT]            = 4.5
        w[MOD.MND]            = 4.5
        w[MOD.MATT]           = 7.5
        w[MOD.MACC]           = 5.5
        w[MOD.MAGIC_DAMAGE]   = 2.2
        w[MOD.CURE_POTENCY]   = 7.5
        w[MOD.FASTCAST]       = 8.0
        w[MOD.REFRESH]        = 18.0
        w[MOD.MP]             = 0.65
        w[MOD.MPP]            = 4.0
        w[MOD.ENMITY]         = -2.2
        w[MOD.ELEMENTAL]      = 3.0
        w[MOD.HEALING]        = 3.0
        w[MOD.ENFEEBLING]     = 2.5
        w[MOD.ENHANCING]      = 2.0
        w[MOD.DARK]           = 2.5
        w[MOD.DEF]            = 0.35
        w[MOD.HP]             = 0.2
        w[MOD.VIT]            = 0.8
        w[MOD.DMG]            = 4.0
        w.weaponDps           = 0.4
        w.weaponDmg           = 0.05
        w.shieldScore         = 1.2
    else
        -- Default: TP / Melee DPS
        w[MOD.HASTE_GEAR]         = 11.0
        w[MOD.STORETP]            = 5.5
        w[MOD.DOUBLE_ATTACK]      = 9.5
        w[MOD.TRIPLE_ATTACK]      = 13.0
        w[MOD.QUAD_ATTACK]        = 16.0
        w[MOD.DUAL_WIELD]         = 8.5
        w[MOD.ACC]                = 3.4
        w[MOD.ATT]                = 2.4
        w[MOD.ATTP]               = 5.5
        w[MOD.STR]                = 3.8
        w[MOD.DEX]                = 3.4
        w[MOD.CRITHITRATE]        = 5.5
        w[MOD.CRIT_DMG_INCREASE]  = 4.5
        w[MOD.SUBTLE_BLOW]        = 2.0
        w[MOD.ALL_WSDMG_ALL_HITS] = 5.0
        w[MOD.DEF]                = 0.3
        w[MOD.HP]                 = 0.2
        w[MOD.ENMITY]             = -0.6
        w.weaponDps               = 9.0
        w.weaponDmg               = 1.0
        w.shieldScore             = 0.6
    end

    w.pet = {}
    return w
end

-----------------------------------
-- Derive Dynamic Soul Combat Weights
-----------------------------------
function resolver.deriveCombatWeights(player, jobId, targetLevel, profile, opts)
    opts = opts or {}
    local roleKey = (profile and profile.role) or 'tp'
    if roleKey == 'melee' then
        roleKey = 'tp'
    end

    local w = buildBaseWeights(roleKey)
    local specEntry = profile and profile.specEntry or nil
    local soulMods = collectSoulMods(player, specEntry, targetLevel)
    local roleText = string.lower(tostring(specEntry and specEntry.role or ''))
    local descText = string.lower(tostring(specEntry and specEntry.description or ''))

    local isHealer = string.find(roleText, 'healer', 1, true) ~= nil
        or string.find(roleText, 'healing', 1, true) ~= nil
        or (soulMods[MOD.CURE_POTENCY] or 0) > 0

    local isTank = roleKey == 'tank'
        or string.find(roleText, 'tank', 1, true) ~= nil
        or (soulMods[MOD.ENMITY] or 0) >= 20

    local isPetSoul = string.find(roleText, 'pet', 1, true) ~= nil
        or string.find(roleText, 'beast', 1, true) ~= nil
        or string.find(roleText, 'summon', 1, true) ~= nil
        or string.find(descText, 'pet', 1, true) ~= nil
        or string.find(descText, 'beast', 1, true) ~= nil
        or string.find(descText, 'wyvern', 1, true) ~= nil
        or string.find(descText, 'automaton', 1, true) ~= nil
        or jobId == 9 or jobId == 14 or jobId == 15 or jobId == 18

    local isUnarmed = (specEntry and specEntry.chiRanged ~= nil)
        or (profile and profile.weapon == 'none' and (profile.ranged == nil or profile.ranged == 'none'))

    -- Zero-MP detection (e.g., MNK Chi Weaver heals with Chi/MND/VIT/HP, zero MP/Refresh!)
    local usesMP = (not ZERO_MP_JOBS[jobId]) or ((soulMods[MOD.MPP] or 0) > 0) or ((soulMods[MOD.REFRESH] or 0) > 0)
    if specEntry and specEntry.key == 'chiweaver' then
        usesMP = false
    end

    -- 1. Amplify weights directly from the Soul's actual passive modifiers!
    if (soulMods[MOD.CURE_POTENCY] or 0) > 0 or isHealer then
        addWeight(w, MOD.CURE_POTENCY, 7.0)
        addWeight(w, MOD.MND, 4.5)
        addWeight(w, MOD.HEALING, 2.5)
        w[MOD.ENMITY] = math.min(w[MOD.ENMITY] or 0, -2.5)
        -- Pure healers prioritize MND/Cure Potency over nuking INT unless Soul also grants MATT/INT
        if (soulMods[MOD.MATT] or 0) <= 0 and (soulMods[MOD.INT] or 0) <= 0 then
            w[MOD.INT] = math.min(w[MOD.INT] or 0, 1.0)
            w[MOD.MATT] = math.min(w[MOD.MATT] or 0, 1.5)
        end
    end

    if (soulMods[MOD.MATT] or 0) > 0 or (soulMods[MOD.INT] or 0) > 0 then
        addWeight(w, MOD.MATT, 5.5)
        addWeight(w, MOD.MACC, 3.5)
        addWeight(w, MOD.MAGIC_DAMAGE, 1.8)
        if (soulMods[MOD.INT] or 0) > 0 then
            addWeight(w, MOD.INT, 3.5)
        end
    end

    if (soulMods[MOD.MACC] or 0) > 0 then
        addWeight(w, MOD.MACC, 3.5)
    end

    if (soulMods[MOD.FASTCAST] or 0) > 0 then
        addWeight(w, MOD.FASTCAST, 4.5)
    end

    if (soulMods[MOD.REFRESH] or 0) > 0 and usesMP then
        addWeight(w, MOD.REFRESH, 8.0)
    end

    if (soulMods[MOD.REGEN] or 0) > 0 then
        addWeight(w, MOD.REGEN, 6.0)
    end

    if (soulMods[MOD.RACC] or 0) > 0 or (soulMods[MOD.RATTP] or 0) > 0
        or (soulMods[MOD.SNAPSHOT] or 0) > 0 or (soulMods[MOD.RAPID_SHOT] or 0) > 0
        or (soulMods[MOD.ARCHERY] or 0) > 0 or (soulMods[MOD.MARKSMANSHIP] or 0) > 0
    then
        addWeight(w, MOD.RACC, 3.0)
        addWeight(w, MOD.RATT, 2.8)
        addWeight(w, MOD.RATTP, 4.0)
        addWeight(w, MOD.AGI, 3.2)
        addWeight(w, MOD.SNAPSHOT, 2.5)
        addWeight(w, MOD.RAPID_SHOT, 2.0)
        addWeight(w, MOD.STORETP, 3.0)
        w.rangedDps = math.max(w.rangedDps or 0, 18.0)
        w.ammoDmg   = math.max(w.ammoDmg or 0, 2.8)
    end

    if (soulMods[MOD.STR] or 0) > 0 then
        addWeight(w, MOD.STR, 2.5)
    end
    if (soulMods[MOD.DEX] or 0) > 0 then
        addWeight(w, MOD.DEX, 2.5)
    end
    if (soulMods[MOD.VIT] or 0) > 0 then
        addWeight(w, MOD.VIT, 2.5)
    end
    if (soulMods[MOD.AGI] or 0) > 0 then
        addWeight(w, MOD.AGI, 2.0)
    end
    if (soulMods[MOD.MND] or 0) > 0 then
        addWeight(w, MOD.MND, 2.8)
    end
    if (soulMods[MOD.CHR] or 0) > 0 then
        addWeight(w, MOD.CHR, 3.0)
    end

    if (soulMods[MOD.ATTP] or 0) > 0 then
        addWeight(w, MOD.ATT, 1.5)
        addWeight(w, MOD.ATTP, 3.5)
    end
    if (soulMods[MOD.DOUBLE_ATTACK] or 0) > 0 then
        addWeight(w, MOD.DOUBLE_ATTACK, 4.0)
        addWeight(w, MOD.TRIPLE_ATTACK, 5.0)
    end
    if (soulMods[MOD.STORETP] or 0) > 0 then
        addWeight(w, MOD.STORETP, 2.5)
    end
    if (soulMods[MOD.ALL_WSDMG_ALL_HITS] or 0) > 0 then
        addWeight(w, MOD.ALL_WSDMG_ALL_HITS, 5.0)
    end
    if (soulMods[MOD.CRITHITRATE] or 0) > 0 then
        addWeight(w, MOD.CRITHITRATE, 3.5)
        addWeight(w, MOD.CRIT_DMG_INCREASE, 3.0)
    end
    if (soulMods[MOD.SUBTLE_BLOW] or 0) > 0 then
        addWeight(w, MOD.SUBTLE_BLOW, 2.5)
    end

    if (soulMods[MOD.HPP] or 0) > 0 then
        addWeight(w, MOD.HP, 0.45)
        addWeight(w, MOD.HPP, 2.5)
    end
    if (soulMods[MOD.DEFP] or 0) > 0 or (soulMods[MOD.DMG] or 0) < 0 then
        addWeight(w, MOD.DEF, 0.8)
        addWeight(w, MOD.DMG, 6.0)
        addWeight(w, MOD.DMGPHYS, 4.0)
        addWeight(w, MOD.DMGMAGIC, 4.0)
    end
    if (soulMods[MOD.ENMITY] or 0) > 0 then
        w[MOD.ENMITY] = math.max(w[MOD.ENMITY] or 0, 5.5)
    elseif (soulMods[MOD.ENMITY] or 0) < 0 and not isTank then
        w[MOD.ENMITY] = math.min(w[MOD.ENMITY] or 0, -1.8)
    end
    if (soulMods[MOD.INQUARTATA] or 0) > 0 or (soulMods[MOD.PARRY] or 0) > 0 then
        addWeight(w, MOD.PARRY, 3.0)
        addWeight(w, MOD.EVA, 1.5)
    end
    if (soulMods[MOD.SHIELD] or 0) > 0 then
        addWeight(w, MOD.SHIELD, 4.0)
        w.shieldScore = math.max(w.shieldScore or 0, 6.5)
    end
    if (soulMods[MOD.MEVA] or 0) > 0 then
        addWeight(w, MOD.MEVA, 2.0)
    end

    -- Weapon skill affinity bonuses from Soul mods
    for _, skMod in ipairs({
        MOD.HTH, MOD.DAGGER, MOD.SWORD, MOD.GSWORD, MOD.AXE, MOD.GAXE,
        MOD.SCYTHE, MOD.POLEARM, MOD.KATANA, MOD.GKATANA, MOD.CLUB, MOD.STAFF,
        MOD.ARCHERY, MOD.MARKSMANSHIP, MOD.THROW, MOD.NINJUTSU, MOD.SINGING,
        MOD.WIND, MOD.STRING, MOD.BLUE, MOD.SUMMONING,
    }) do
        if (soulMods[skMod] or 0) > 0 then
            addWeight(w, skMod, 3.0)
        end
    end

    -- Zero-MP Souls (like Chi Weaver): strictly zero out MP/Refresh/FastCast waste
    if not usesMP then
        w[MOD.MP]       = 0
        w[MOD.MPP]      = 0
        w[MOD.REFRESH]  = 0
        w[MOD.FASTCAST] = 0
        if isHealer then
            -- Non-MP healers (Chi Weaver, DNC Vampire, etc.) scale off MND/VIT/HP/Haste/Cure Potency
            setMinWeight(w, MOD.MND, 6.5)
            setMinWeight(w, MOD.VIT, 3.5)
            setMinWeight(w, MOD.HP, 0.6)
            setMinWeight(w, MOD.HASTE_GEAR, 7.0)
            setMinWeight(w, MOD.CURE_POTENCY, 10.0)
            setMinWeight(w, MOD.REGEN, 7.0)
        end
    end

    -- Unarmed melee/chi Souls (Chi Weaver) benefit from Haste/H2H/MND/MACC/MATT
    if isUnarmed and (soulMods[MOD.HTH] or 0) > 0 then
        setMinWeight(w, MOD.HASTE_GEAR, 8.0)
        setMinWeight(w, MOD.HTH, 3.5)
    end

    -- Pet Souls: value pet modifiers on equipment!
    if isPetSoul then
        w.pet[MOD.ATT]      = 2.2
        w.pet[MOD.ACC]      = 2.5
        w.pet[MOD.DEF]      = 1.8
        w.pet[MOD.HP]       = 0.5
        w.pet[MOD.DMG]      = 12.0
        w.pet[MOD.DMGPHYS]  = 9.0
        w.pet[MOD.DMGMAGIC] = 9.0
        w.pet[MOD.MATT]     = 4.0
        w.pet[MOD.MACC]     = 3.5
        w.pet[MOD.HASTE_GEAR] = 6.0
        w.pet[MOD.DOUBLE_ATTACK] = 6.0
        w.pet[MOD.ENMITY]   = isTank and 4.0 or 0.5
    end

    -- Explicit role override tilts weights cleanly
    if opts.role == 'ws' then
        w[MOD.STR]                = math.max(w[MOD.STR] or 0, 6.0)
        w[MOD.ALL_WSDMG_ALL_HITS] = math.max(w[MOD.ALL_WSDMG_ALL_HITS] or 0, 14.0)
        w[MOD.ATT]                = math.max(w[MOD.ATT] or 0, 2.5)
    elseif opts.role == 'tp' then
        w[MOD.HASTE_GEAR]    = math.max(w[MOD.HASTE_GEAR] or 0, 11.0)
        w[MOD.STORETP]       = math.max(w[MOD.STORETP] or 0, 5.5)
        w[MOD.DOUBLE_ATTACK] = math.max(w[MOD.DOUBLE_ATTACK] or 0, 9.5)
    end

    return w, {
        isHealer  = isHealer,
        isTank    = isTank,
        isPetSoul = isPetSoul,
        isUnarmed = isUnarmed,
        usesMP    = usesMP,
        soulMods  = soulMods,
    }
end

-----------------------------------
-- Acquisition Classification & Item Scoring
-----------------------------------
local function isPrestigeCandidate(item)
    if item == nil then
        return true
    end
    if item.prestige ~= nil then
        return item.prestige == true
    end
    if item.practical ~= nil then
        return item.practical == false
    end
    local flags = tonumber(item.flags) or 0
    local ex = hasBit(flags, FLAG_EXCLUSIVE)
    local rare = hasBit(flags, FLAG_RARE)
    local noAh = hasBit(flags, FLAG_NO_AUCTION)
    if (ex and rare) or (ex and noAh) then
        return true
    end
    return containsAny(item.name, PRESTIGE_NAME_WORDS)
end

function resolver.scoreItem(item, slotId, weights, targetLevel, opts)
    if item == nil then
        return -math.huge
    end
    opts = opts or {}

    local lvl = tonumber(item.lvl) or 1
    if lvl > targetLevel or lvl > 75 then
        return -math.huge
    end
    if (tonumber(item.ilvl) or 0) > 0 or (tonumber(item.suLevel) or 0) > 0 then
        return -math.huge
    end
    if item.gmOnly or hasBit(tonumber(item.flags) or 0, FLAG_GM_ONLY) then
        return -math.huge
    end

    local score = 0.0

    -- 1. Weapon combat stats (MAIN / SUB / RANGED / AMMO)
    if slotId == 0 or slotId == 1 then
        if item.isWeapon then
            local dmg   = tonumber(item.dmg) or 0
            local delay = tonumber(item.delay) or 0
            local dps   = tonumber(item.dps) or 0
            if dps <= 0 and dmg > 0 and delay > 0 then
                dps = (dmg * 60.0) / delay
            end
            local hits = math.max(1, tonumber(item.hitCount) or 1)
            local wDps = weights.weaponDps or 8.0
            local wDmg = weights.weaponDmg or 1.0
            score = score + (dps * wDps) + (dmg * wDmg)
            if hits > 1 and wDps >= 2.0 then
                score = score + (hits - 1) * (wDps * 4.0)
            end
            -- Penalize 0-DMG joke weapons for physical builds
            if dmg == 0 and wDps >= 2.0 then
                score = score - 200.0
            end
        elseif item.isShield then
            local shSize   = tonumber(item.shieldSize) or 0
            local shAbsorb = tonumber(item.shieldAbsorb) or 0
            local shW      = weights.shieldScore or 2.0
            score = score + (shSize * 4.0 + shAbsorb * 0.4) * shW
        end
    elseif slotId == 2 then
        -- Ranged slot (Bow, Crossbow, Gun, Throwing, Instrument, Handbell, Animator)
        local dmg   = tonumber(item.dmg) or 0
        local delay = tonumber(item.delay) or 0
        local dps   = tonumber(item.dps) or 0
        if dps <= 0 and dmg > 0 and delay > 0 then
            dps = (dmg * 60.0) / delay
        end
        if dmg > 0 then
            local rDps = weights.rangedDps or 16.0
            score = score + (dps * rDps) + (dmg * 2.5)
            -- Penalize Lv.1 novelty/event ranged weapons with tiny base DMG at higher levels
            if targetLevel >= 15 and dmg <= 5 then
                score = score - 250.0
            end
        end
    elseif slotId == 3 then
        -- Ammo slot (Arrows, Bolts, Bullets, Shurikens, or Stat Ammo)
        local dmg = tonumber(item.dmg) or 0
        if dmg > 0 and opts.isProjectileAmmo then
            score = score + dmg * (weights.ammoDmg or 2.4)
        end
    end

    -- 2. Direct equipment modifiers
    local mods = item.mods
    if type(mods) == 'table' then
        for modId, rawVal in pairs(mods) do
            local w = weights[modId]
            if w ~= nil and w ~= 0 and rawVal ~= nil and rawVal ~= 0 then
                local val = tonumber(rawVal) or 0
                if BASIS_POINT_MODS[modId] then
                    val = val / 100.0
                end
                if INVERTED_SIGN_MODS[modId] then
                    val = -val
                end
                score = score + (val * w)
            end
        end
    end

    -- 3. Pet modifiers (for pet Souls like Huntsman, BST, SMN, PUP, DRG, Necro)
    local petMods = item.petMods
    local petW = weights.pet
    if type(petMods) == 'table' and type(petW) == 'table' then
        for modId, rawVal in pairs(petMods) do
            local w = petW[modId]
            if w ~= nil and w ~= 0 and rawVal ~= nil and rawVal ~= 0 then
                local val = tonumber(rawVal) or 0
                if BASIS_POINT_MODS[modId] then
                    val = val / 100.0
                end
                if INVERTED_SIGN_MODS[modId] then
                    val = -val
                end
                score = score + (val * w)
            end
        end
    end

    -- 4. Level-appropriateness tiebreaker (small, never overrides real combat stats)
    score = score + (lvl * 0.18)

    -- 5. Penalize novelty/costume items with negligible combat stats
    if containsAny(item.name, NOVELTY_NAME_WORDS) then
        score = score - 60.0
    end

    -- 6. Obtainability preference
    local prestige = isPrestigeCandidate(item)
    if opts.accessibility ~= 'best' then
        if prestige then
            score = score - 500.0
        else
            local src = item.sources
            if type(src) == 'table' then
                if src.shop then
                    score = score + 2.0
                elseif src.crafted and not src.craftedHQ then
                    score = score + 1.5
                elseif src.normalDrop then
                    score = score + 1.0
                end
            end
        end
    end

    return score
end

-----------------------------------
-- Fallback Enrichment via Stock GetItemByID()
-- Used only when C++ overlords_item_catalog is not loaded.
-----------------------------------
local PROBE_MODS =
{
    MOD.DEF, MOD.HP, MOD.HPP, MOD.MP, MOD.MPP,
    MOD.STR, MOD.DEX, MOD.VIT, MOD.AGI, MOD.INT, MOD.MND, MOD.CHR,
    MOD.ATT, MOD.ATTP, MOD.RATT, MOD.RATTP, MOD.ACC, MOD.RACC,
    MOD.EVA, MOD.MEVA, MOD.MATT, MOD.MACC, MOD.MDEF, MOD.MAGIC_DAMAGE,
    MOD.DMG, MOD.DMGPHYS, MOD.DMGMAGIC, MOD.ENMITY,
    MOD.HASTE_GEAR, MOD.STORETP, MOD.DOUBLE_ATTACK, MOD.TRIPLE_ATTACK,
    MOD.CRITHITRATE, MOD.CRIT_DMG_INCREASE, MOD.DUAL_WIELD, MOD.SUBTLE_BLOW,
    MOD.FASTCAST, MOD.CURE_POTENCY, MOD.REFRESH, MOD.REGEN,
    MOD.SNAPSHOT, MOD.RAPID_SHOT, MOD.ALL_WSDMG_ALL_HITS,
    MOD.SHIELD, MOD.PARRY, MOD.COUNTER, MOD.SPELLINTERRUPT,
}

local function enrichLegacyEntry(entry)
    if entry == nil or entry.id == nil then
        return nil
    end

    -- Prefer C++ catalog if loaded
    local catalog = xi.overlords and xi.overlords.itemCatalog
    if catalog and catalog.getItem then
        local catItem = catalog.getItem(entry.id)
        if catItem ~= nil then
            -- Preserve qty (e.g. 99 arrows/bolts/bullets) if specified on pool entry
            if entry.qty ~= nil then
                catItem.qty = entry.qty
            end
            return catItem
        end
    end

    -- Otherwise probe live CItem template via stock GetItemByID if available
    local enriched =
    {
        id   = entry.id,
        name = entry.name,
        lvl  = entry.lvl,
        jobs = entry.jobs,
        qty  = entry.qty,
        mods = {},
    }

    if type(GetItemByID) == 'function' then
        local ok, citem = pcall(GetItemByID, entry.id)
        if ok and citem ~= nil then
            if citem.getReqLvl then
                local r = citem:getReqLvl()
                if r and r > 0 then
                    enriched.lvl = r
                end
            end
            if citem.getILvl then
                enriched.ilvl = citem:getILvl()
            end
            if citem.getFlag then
                enriched.flags = citem:getFlag()
            end
            if citem.getAHCat then
                enriched.ahCat = citem:getAHCat()
            end
            if citem.getBasePrice then
                enriched.basePrice = citem:getBasePrice()
            end
            if citem.isShield then
                local okSh, sh = pcall(function() return citem:isShield() end)
                if okSh and sh then
                    enriched.isShield = true
                    if citem.getShieldSize then
                        enriched.shieldSize = citem:getShieldSize()
                    end
                    if citem.getShieldAbsorptionRate then
                        enriched.shieldAbsorb = citem:getShieldAbsorptionRate()
                    end
                end
            end
            if citem.getMod then
                for _, modId in ipairs(PROBE_MODS) do
                    local val = citem:getMod(modId)
                    if val ~= nil and val ~= 0 then
                        enriched.mods[modId] = val
                    end
                end
            end
        end
    end

    return enriched
end

-----------------------------------
-- Authoritative Slot Resolution
-----------------------------------
local function isRaceAndEquipAllowed(player, item, ignoreJobMask)
    if player == nil or item == nil then
        return true
    end
    if ignoreJobMask then
        return true
    end
    if player.canEquipItem then
        return player:canEquipItem(item.id, false)
    end
    return true
end

function resolver.pickBestForSlot(player, slotId, jobId, targetLevel, weights, queryOpts, fallbackPool)
    queryOpts = queryOpts or {}
    local includePrestige = (queryOpts.accessibility == 'best')
    local catalog = xi.overlords and xi.overlords.itemCatalog

    local candidates = nil
    if catalog and catalog.isAvailable and catalog.isAvailable() and catalog.querySlot then
        local slotBit = resolver.SLOT_BIT[slotId]
        if slotBit ~= nil then
            local qOpts =
            {
                minLevel        = queryOpts.minLevel or 1,
                skill           = queryOpts.skill,
                subskill        = queryOpts.subskill,
                excludeSubskill = queryOpts.excludeSubskill,
                isShield        = queryOpts.isShield,
                isWeapon        = queryOpts.isWeapon,
                allowRemoveSlot = queryOpts.allowRemoveSlot or false,
                includePrestige = includePrestige,
                ignoreJobMask   = queryOpts.ignoreJobMask or false,
                excludeId       = queryOpts.excludeId or 0,
            }
            candidates = catalog.querySlot(slotBit, jobId, targetLevel, qOpts)

            -- If default practical mode found zero items for this slot/level,
            -- retry with prestige allowed as a safe last-resort fallback.
            if (candidates == nil or #candidates == 0) and not includePrestige then
                qOpts.includePrestige = true
                candidates = catalog.querySlot(slotBit, jobId, targetLevel, qOpts)
            end
        end
    end

    local bestItem, bestScore = nil, -math.huge

    if candidates ~= nil and #candidates > 0 then
        for _, item in ipairs(candidates) do
            local okFilter = true
            if queryOpts.customFilter and not queryOpts.customFilter(item) then
                okFilter = false
            end
            if okFilter and isRaceAndEquipAllowed(player, item, queryOpts.ignoreJobMask) then
                local sc = resolver.scoreItem(item, slotId, weights, targetLevel, queryOpts)
                if sc > bestScore then
                    bestItem, bestScore = item, sc
                end
            end
        end
    elseif fallbackPool ~= nil then
        for _, rawEntry in ipairs(fallbackPool) do
            if rawEntry ~= nil and (rawEntry.lvl or 1) <= targetLevel and (rawEntry.lvl or 1) <= 75 then
                if queryOpts.excludeId == nil or rawEntry.id ~= queryOpts.excludeId then
                    local okJob = queryOpts.ignoreJobMask
                        or rawEntry.jobs == nil
                        or hasBit(rawEntry.jobs, 2 ^ (jobId - 1))
                    if okJob then
                        local item = enrichLegacyEntry(rawEntry)
                        if item ~= nil and isRaceAndEquipAllowed(player, item, queryOpts.ignoreJobMask) then
                            local sc = resolver.scoreItem(item, slotId, weights, targetLevel, queryOpts)
                            if sc > bestScore then
                                bestItem, bestScore = item, sc
                            end
                        end
                    end
                end
            end
        end
    end

    if bestItem ~= nil then
        -- Auto-stack consumable projectile ammo (arrows, bolts, bullets, shurikens)
        if slotId == 3 and queryOpts.defaultQty ~= nil and (bestItem.qty == nil or bestItem.qty < queryOpts.defaultQty) then
            local stackSize = tonumber(bestItem.stackSize) or queryOpts.defaultQty
            bestItem.qty = math.min(queryOpts.defaultQty, math.max(1, stackSize))
        end
    end

    return bestItem, bestScore
end

return resolver
