-----------------------------------
-- SoulspireXI Soul Proving Grounds — Shared Encounter Registry & Level Sync
--
-- Single source of truth shared by:
--   1. The in-game NPC Testing Arena (soulspire_proving_grounds_lite.lua)
--   2. Server combat telemetry (soulspire_proving_grounds_telemetry.lua)
--   3. Automated combat benchmarks (xi_test & Python Stage A/B/C runners)
--
-- Design guarantees:
--   - Zero duplicate encounter tables between manual and automated testing.
--   - Native non-destructive level synchronization via xi.effect.LEVEL_RESTRICTION
--     (which invokes C++ CLuaBaseEntity::levelRestriction, never mutating DB job
--     levels or permanent genkai caps).
--   - Immediate SoulspireXI rescaling after level sync / restoration:
--     Soul crystal mods/abilities/traits, player combat pace BASE_HP, pets, and
--     Shinobi clone dismissal so clones inherit the effective combat level.
--   - Supports all 4 difficulties (+0 EM, +3 VT, +5 IT, +8 Extreme non-baseline)
--     and Normal / NM classifications, including boss levels above 75 (up to 83).
--   - Defense-in-depth no-progression safeguards on every trial mob.
-----------------------------------
local hasServerRuntime = (Module ~= nil and Module.new ~= nil)
if hasServerRuntime then
    require('modules/module_utils')
    require('scripts/globals/experience_points')
    require('modules/custom/lua/boss_like_combat_and_exp')
end

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.provingGrounds = xi.soulspire.provingGrounds or {}
xi.soulspire.provingGrounds.registry = xi.soulspire.provingGrounds.registry or {}

local R = xi.soulspire.provingGrounds.registry

R.SCHEMA_VERSION       = '2.0.0'
R.RUNNER_CONTRACT      = 'overlordsxi-proving-grounds-v2'
R.ARENA_ZONE_ID        = (xi.zone and xi.zone.GM_HOME) or 210
-- Positioned at (-5, 0, 5) to remain 10 yalms clear of GM Home's Menu Example NPC at (5, 0, 5).
R.NPC_POS              = { x = -5, y = 0, z = 5, rotation = 0 }
R.BOSS_POS             = { x = 5, y = 0, z = 25, rotation = 128 }
R.PLAYER_START_POS     = { x = 5, y = 0, z = 18, rotation = 192 }
R.DEFAULT_DURATION_SEC = 600
R.MIN_LEVEL            = 10
R.MAX_LEVEL            = 75
R.MAX_BOSS_LEVEL       = 83 -- Lv75 effective player + 8 Extreme Challenge

R.LEVELS = { 10, 30, 50, 75 }

R.DIFFICULTIES =
{
    even_match =
    {
        id               = 'even_match',
        label            = 'Even Match (+0)',
        levelDelta       = 0,
        standardBaseline = true,
        extremeChallenge = false,
    },
    very_tough =
    {
        id               = 'very_tough',
        label            = 'Very Tough (+3)',
        levelDelta       = 3,
        standardBaseline = true,
        extremeChallenge = false,
    },
    incredibly_tough =
    {
        id               = 'incredibly_tough',
        label            = 'Incredibly Tough (+5)',
        levelDelta       = 5,
        standardBaseline = true,
        extremeChallenge = false,
    },
    extreme =
    {
        id               = 'extreme',
        label            = 'Extreme (+8) [Non-Baseline]',
        levelDelta       = 8,
        standardBaseline = false,
        extremeChallenge = true,
    },
}

-- Canonical aliases for backward compatibility with Stage A/B configs.
R.DIFFICULTY_ALIASES =
{
    even_match       = 'even_match',
    em               = 'even_match',
    very_tough       = 'very_tough',
    vt               = 'very_tough',
    boss_plus_3      = 'very_tough',
    incredibly_tough = 'incredibly_tough',
    it               = 'incredibly_tough',
    boss_plus_5      = 'incredibly_tough',
    extreme          = 'extreme',
    boss_plus_8      = 'extreme',
    extreme_plus_8   = 'extreme',
}

R.DIFFICULTY_ORDER = { 'even_match', 'very_tough', 'incredibly_tough', 'extreme' }

function R.resolveDifficulty(key)
    local norm = string.lower(tostring(key or 'even_match'))
    local canonical = R.DIFFICULTY_ALIASES[norm]
    if canonical and R.DIFFICULTIES[canonical] then
        return R.DIFFICULTIES[canonical], canonical
    end
    return nil, nil
end

R.BOSS_PRESETS =
{
    normal =
    {
        id         = 'normal',
        label      = 'Normal',
        isNM       = false,
        configPath = 'xi.customBossServer.config.normalMob',
    },
    nm =
    {
        id         = 'nm',
        label      = 'NM (Notorious Monster)',
        isNM       = true,
        configPath = 'xi.customBossServer.config.nm',
    },
}

R.BOSS_PRESET_ORDER = { 'normal', 'nm' }

-- Accessible, level-appropriate equipment profiles mapped to xi.soulspire.testGear.
-- Never uses Lv75 best-in-slot gear to evaluate lower-level brackets.
R.GEAR_PROFILES =
{
    accessible_lv10 =
    {
        id          = 'accessible_lv10',
        label       = 'Accessible Level 10 Gear',
        levelCap    = 10,
        tier        = 'accessible',
        testGearKey = 'tp',
    },
    accessible_lv30 =
    {
        id          = 'accessible_lv30',
        label       = 'Accessible Level 30 Gear',
        levelCap    = 30,
        tier        = 'accessible',
        testGearKey = 'tp',
    },
    accessible_lv50 =
    {
        id          = 'accessible_lv50',
        label       = 'Accessible Level 50 Gear',
        levelCap    = 50,
        tier        = 'accessible',
        testGearKey = 'tp',
    },
    accessible_lv75 =
    {
        id          = 'accessible_lv75',
        label       = 'Accessible Level 75 Gear',
        levelCap    = 75,
        tier        = 'accessible',
        testGearKey = 'tp',
    },
}

R.PARTY_COMPOSITIONS =
{
    solo =
    {
        id          = 'solo',
        label       = 'Solo Controlled Actor',
        size        = 1,
        roles       = { 'subject' },
        stage       = 'B',
        implemented = true,
    },
    party =
    {
        id          = 'party',
        label       = 'Manual Party Session',
        size        = 6,
        roles       = { 'party' },
        stage       = 'manual',
        implemented = true,
    },
    trio_standard =
    {
        id          = 'trio_standard',
        label       = 'Standard Trio (Tank / Healer / DPS)',
        size        = 3,
        roles       = { 'tank', 'healer', 'dps' },
        stage       = 'C',
        implemented = false,
        gateReason  = 'Stage C automated party suite pending Milestone C review.',
    },
}

-- Standardized encounter archetypes.
-- Every NPC-selectable archetype uses verified existing mob_groups (HP=0 so level
-- stats scale authentically) for BOTH Normal (mobType=0) and NM (mobType=2) presets.
R.ARCHETYPES =
{
    physical_bruiser =
    {
        id                  = 'physical_bruiser',
        label               = 'Physical Bruiser',
        packetName          = 'Crucible Bruiser',
        entityName          = 'Crucible_Bruiser',
        primaryTest         = 'Tank mitigation and sustained healing',
        npcAvailable        = true,
        automatedAvailable  = true,
        defaultDurationSec  = 180,
        -- Normal: Orcish_Guard (WAR/WAR, mobType=0, HP=0, spellList=0, delay=240, dmgMult=100)
        groupId             = 3723,
        groupZoneId         = 86,
        -- NM: Ashu_Talif_Marine (WAR, mobType=2, HP=0, spellList=0)
        nmGroupId           = 2017,
        nmGroupZoneId       = 60,
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            -- Single-target physical skills only (no AoE, no spells):
            allowedSkills   = { 606, 607 }, -- shoulder_attack, slam_dunk
            nmAllowedSkills = { 246 },      -- shackled_fists
            magicCool       = nil,
            spellList       = 0,
            summary         = 'Pure physical autoattacks + single-target physical TP moves only. No spells, no AoE.',
        },
    },

    magic_caster =
    {
        id                  = 'magic_caster',
        label               = 'Magic-heavy Caster',
        packetName          = 'Crucible Caster',
        entityName          = 'Crucible_Caster',
        primaryTest         = 'Resistance, interruption and MP',
        npcAvailable        = true,
        automatedAvailable  = true,
        defaultDurationSec  = 180,
        -- Normal: Orcish_Hexspinner (BLM/BLM, mobType=0, HP=0, spellList=21 Beastmen_BLM)
        groupId             = 3724,
        groupZoneId         = 86,
        -- NM: Living_Staves (BLM, mobType=2, HP=0, spellList=21 Beastmen_BLM)
        nmGroupId           = 30,
        nmGroupZoneId       = 56,
        behavior =
        {
            autoAttack      = true,
            magicCasting    = true,
            mobAbility      = false,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            allowedSkills   = {},
            magicCool       = 10,
            spellList       = 21,
            summary         = 'BLM spell list (Beastmen_BLM, Lv10-75+) with rapid cast cadence; mob TP abilities disabled.',
        },
    },

    aoe_boss =
    {
        id                  = 'aoe_boss',
        label               = 'AoE Boss',
        packetName          = 'Crucible Ravager',
        entityName          = 'Crucible_Ravager',
        primaryTest         = 'Pet survival and group healing',
        npcAvailable        = true,
        automatedAvailable  = true,
        defaultDurationSec  = 180,
        -- Normal: Gigas_Flanker (WAR/WAR, mobType=0, HP=0, spellList=0)
        groupId             = 16,
        groupZoneId         = 129,
        -- NM: Kraken_assault (WAR, mobType=2, HP=0, spellList=0)
        nmGroupId           = 32,
        nmGroupZoneId       = 55,
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            -- Verified AoE damage skills only (no suicide/instant-death/sleep-lock):
            allowedSkills   = { 665, 664 }, -- grand_slam, impact_roar
            nmAllowedSkills = { 462, 463 }, -- maelstrom, whirlwind
            magicCool       = nil,
            spellList       = 0,
            summary         = 'Physical autoattacks + strictly whitelisted AoE mobskills. No spells.',
        },
    },

    training_dummy =
    {
        id                  = 'training_dummy',
        label               = 'Training Dummy',
        packetName          = 'Crucible Dummy',
        entityName          = 'Crucible_Dummy',
        primaryTest         = 'Sustained DPS, TP generation, haste and rotation baseline',
        npcAvailable        = true,
        automatedAvailable  = true,
        defaultDurationSec  = 180,
        groupId             = 3723,
        groupZoneId         = 86,
        nmGroupId           = 2017,
        nmGroupZoneId       = 60,
        behavior =
        {
            autoAttack      = false,
            magicCasting    = false,
            mobAbility      = false,
            noMove          = true,
            unkillable      = true,
            refillHpOnLow   = true,
            allowedSkills   = {},
            magicCool       = nil,
            spellList       = 0,
            summary         = 'Stationary unkillable target with live DEF/EVA scaling; no autoattacks, spells, or TP moves.',
        },
    },

    mobile_boss =
    {
        id                  = 'mobile_boss',
        label               = 'Mobile Boss',
        packetName          = 'Crucible Skirmisher',
        entityName          = 'Crucible_Skirmisher',
        primaryTest         = 'Positional mechanics and melee uptime',
        npcAvailable        = false,
        unavailableReason   = 'GM Home navmesh patrol waypoints are not yet client-verified.',
        automatedAvailable  = false,
        defaultDurationSec  = 180,
        groupId             = 3723,
        groupZoneId         = 86,
        nmGroupId           = 2017,
        nmGroupZoneId       = 60,
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            allowedSkills   = { 606, 607 },
            nmAllowedSkills = { 246 },
            moveIntervalSec = 15,
            moveRadius      = 10,
            spellList       = 0,
            summary         = 'Planned: periodic repositioning boss to test melee uptime and positional abilities.',
        },
    },

    endurance_boss =
    {
        id                  = 'endurance_boss',
        label               = 'Endurance Boss',
        packetName          = 'Crucible Titan',
        entityName          = 'Crucible_Titan',
        primaryTest         = 'Resource depletion and cooldown cycles',
        npcAvailable        = false,
        unavailableReason   = 'Reserved for Stage C multi-minute party endurance benchmarks.',
        automatedAvailable  = false,
        defaultDurationSec  = 300,
        groupId             = 3723,
        groupZoneId         = 86,
        nmGroupId           = 2017,
        nmGroupZoneId       = 60,
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            allowedSkills   = { 606, 607 },
            nmAllowedSkills = { 246 },
            extraHppPct     = 100,
            spellList       = 0,
            summary         = 'Planned: extended 300s encounter testing MP/TP sustainability and cooldown cycling.',
        },
    },

    burst_boss =
    {
        id                  = 'burst_boss',
        label               = 'Burst Boss',
        packetName          = 'Crucible Berserker',
        entityName          = 'Crucible_Berserker',
        primaryTest         = 'Burst damage versus sustained damage',
        npcAvailable        = false,
        unavailableReason   = 'Reserved for Stage C timed burst-window benchmarks.',
        automatedAvailable  = false,
        defaultDurationSec  = 90,
        groupId             = 3723,
        groupZoneId         = 86,
        nmGroupId           = 2017,
        nmGroupZoneId       = 60,
        behavior =
        {
            autoAttack       = true,
            magicCasting     = false,
            mobAbility       = true,
            noMove           = false,
            unkillable       = false,
            refillHpOnLow    = false,
            allowedSkills    = { 606, 607 },
            nmAllowedSkills  = { 246 },
            burstIntervalSec = 30,
            burstDurationSec = 10,
            spellList        = 0,
            summary          = 'Planned: short 90s encounter with periodic vulnerability/damage spikes.',
        },
    },
}

R.NPC_ARCHETYPE_ORDER =
{
    'physical_bruiser',
    'magic_caster',
    'aoe_boss',
    'training_dummy',
}

R.MATRIX_ARCHETYPE_ORDER =
{
    'physical_bruiser',
    'magic_caster',
    'aoe_boss',
    'mobile_boss',
    'endurance_boss',
    'burst_boss',
}

function R.resolveGearProfileForLevel(level)
    local lvl = math.max(1, math.floor(tonumber(level) or 10))
    if lvl <= 20 then
        return R.GEAR_PROFILES.accessible_lv10
    elseif lvl <= 40 then
        return R.GEAR_PROFILES.accessible_lv30
    elseif lvl <= 60 then
        return R.GEAR_PROFILES.accessible_lv50
    end
    return R.GEAR_PROFILES.accessible_lv75
end

function R.snapshotCombatRules()
    local bossCfg = xi and xi.customBossServer and xi.customBossServer.config or nil
    return
    {
        bossScalingModule  = 'boss_like_combat_and_exp',
        bossScalingLoaded  = bossCfg ~= nil,
        levelCap           = R.MAX_LEVEL,
        maxBossLevel       = R.MAX_BOSS_LEVEL,
        normalMobBaseMult  = bossCfg and bossCfg.levelGap and bossCfg.levelGap.normalMobBaseDmgMult or 1.65,
        nmBaseMult         = bossCfg and bossCfg.levelGap and bossCfg.levelGap.nmBaseDmgMult or 1.85,
        wallStartDiff      = bossCfg and bossCfg.levelGap and bossCfg.levelGap.wallStartDiff or 8,
        playerBaseHpp      = bossCfg and bossCfg.playerBaseHpp or 100,
        playerHpPerLevel   = bossCfg and bossCfg.playerHpPerLevel or 12,
        normalPdifFloor    = bossCfg and bossCfg.tankPressure and bossCfg.tankPressure.normalMobPdifFloor or 0.65,
        nmPdifFloor        = bossCfg and bossCfg.tankPressure and bossCfg.tankPressure.nmPdifFloor or 0.75,
        noProgression      = true,
    }
end

-- Builds and validates a canonical encounter config shared by NPC & automated tests.
-- Boss level is ALWAYS derived from effective playerLevel + difficulty.levelDelta
-- (never against an unsynced higher player level).
function R.buildEncounterConfig(opts)
    opts = opts or {}

    local bossType = tostring(opts.bossType or 'physical_bruiser')
    local archetype = R.ARCHETYPES[bossType]
    if not archetype then
        return nil, string.format('Unknown bossType: %s', bossType)
    end

    local difficulty, difficultyKey = R.resolveDifficulty(opts.difficulty or 'even_match')
    if not difficulty then
        return nil, string.format('Unknown difficulty: %s', tostring(opts.difficulty))
    end

    local bossPresetKey = string.lower(tostring(opts.bossPreset or 'normal'))
    local bossPreset = R.BOSS_PRESETS[bossPresetKey]
    if not bossPreset then
        return nil, string.format('Unknown bossPreset: %s', bossPresetKey)
    end

    if bossPreset.isNM and archetype.nmGroupId == nil then
        return nil, string.format('Archetype %s does not yet have a verified NM mob group.', bossType)
    end

    local rawPlayerLvl = math.floor(tonumber(opts.playerLevel) or tonumber(opts.effectivePlayerLevel) or tonumber(opts.bossLevel) or 10)
    if rawPlayerLvl < R.MIN_LEVEL or rawPlayerLvl > R.MAX_LEVEL then
        return nil, string.format('Unsupported playerLevel: %s (expected %d..%d)', tostring(rawPlayerLvl), R.MIN_LEVEL, R.MAX_LEVEL)
    end
    local playerLevel = rawPlayerLvl

    local bossLevel = opts.bossLevel ~= nil
        and math.floor(tonumber(opts.bossLevel) or 0)
        or (playerLevel + difficulty.levelDelta)

    if bossLevel < R.MIN_LEVEL or bossLevel > R.MAX_BOSS_LEVEL then
        return nil, string.format('Unsupported bossLevel: %s (expected %d..%d)', tostring(bossLevel), R.MIN_LEVEL, R.MAX_BOSS_LEVEL)
    end

    local partyKey = tostring(opts.partyComposition or 'solo')
    local partyComp = R.PARTY_COMPOSITIONS[partyKey]
    if not partyComp then
        return nil, string.format('Unknown partyComposition: %s', partyKey)
    end

    local gearProfile = opts.gearProfile and R.GEAR_PROFILES[opts.gearProfile] or R.resolveGearProfileForLevel(playerLevel)
    local durationSec = math.max(10, math.floor(tonumber(opts.durationSec) or archetype.defaultDurationSec or R.DEFAULT_DURATION_SEC))
    local levelGap    = bossLevel - playerLevel
    local seed        = opts.seed ~= nil and math.floor(tonumber(opts.seed) or 0) or nil

    local encounterId = string.format(
        'pg_%s_%s_p%d_b%d_%s_%s',
        bossType,
        bossPresetKey,
        playerLevel,
        bossLevel,
        difficultyKey,
        partyKey
    )

    return
    {
        encounterId          = encounterId,
        version              = R.SCHEMA_VERSION,
        bossType             = bossType,
        bossLabel            = archetype.label,
        bossLevel            = bossLevel,
        playerLevel          = playerLevel,
        effectivePlayerLevel = playerLevel,
        levelGap             = levelGap,
        difficulty           = difficultyKey,
        difficultyLabel      = difficulty.label,
        difficultyMeta       = difficulty,
        standardBaseline     = difficulty.standardBaseline == true,
        extremeChallenge     = difficulty.extremeChallenge == true,
        bossPreset           = bossPresetKey,
        bossPresetLabel      = bossPreset.label,
        isNM                 = bossPreset.isNM,
        behaviorProfile      = archetype.behavior,
        archetype            = archetype,
        durationSec          = durationSec,
        gearProfile          = gearProfile.id,
        gearProfileMeta      = gearProfile,
        partyComposition     = partyKey,
        partyMeta            = partyComp,
        seed                 = seed,
        combatRules          = R.snapshotCombatRules(),
    }, nil
end

-----------------------------------
-- Native Level Synchronization (xi.effect.LEVEL_RESTRICTION)
-----------------------------------

local function dismissActorClones(player)
    if xi and xi.soulspire and xi.soulspire.kurogane and xi.soulspire.kurogane.dismissAll then
        pcall(function()
            xi.soulspire.kurogane.dismissAll(player)
        end)
    end
end

local function resyncActorOverlordsSystems(player, refillResources)
    if player == nil then
        return
    end

    -- Refresh Soul Crystal mods, extra abilities, extra traits, and pet role mods for effective level.
    if xi and xi.soulspire and xi.soulspire.spec and xi.soulspire.spec.refreshPlayer then
        pcall(function()
            xi.soulspire.spec.refreshPlayer(player)
        end)
    end

    -- Recalculate SoulspireXI BASE_HP & combat pace from the current effective level's Base HP.
    if xi and xi.customBossServer and xi.customBossServer.applyPlayerCombatPace then
        pcall(function()
            xi.customBossServer.applyPlayerCombatPace(player, true)
        end)
    end

    if player.updateHealth then
        pcall(function()
            player:updateHealth()
        end)
    end

    -- Resync active pet/companion so pet pace & Soul pet mods match the effective level
    -- (C++ levelRestriction calls PPet->restoreModifiers(), so clear PetPaceApplied cleanly).
    if player.hasPet and player:hasPet() and player.getPet then
        local pet = player:getPet()
        if pet ~= nil then
            pcall(function()
                if pet.setLocalVar then
                    pet:setLocalVar('[CustomBoss]PetPaceApplied', 0)
                end
                if xi and xi.soulspire and xi.soulspire.spec and xi.soulspire.spec.syncPetRoleMods then
                    xi.soulspire.spec.syncPetRoleMods(player, pet)
                end
                if pet.updateHealth then
                    pet:updateHealth()
                end
                if refillResources and pet.setHP and pet.getMaxHP then
                    pet:setHP(pet:getMaxHP())
                end
            end)
        end
    end

    if refillResources then
        pcall(function()
            if player.setHP and player.getMaxHP then
                player:setHP(player:getMaxHP())
            end
            if player.setMP and player.getMaxMP then
                player:setMP(player:getMaxMP())
            end
        end)
    end
end

-- Returns a player's true unsynced main job level (accounting for any existing Proving Grounds sync).
function R.getUnsyncedLevel(player)
    if player == nil then
        return 0
    end
    local saved = player.getLocalVar and player:getLocalVar('[ProvingGrounds]OrigLvl') or 0
    if saved > 0 then
        return saved
    end
    if player.getMainLvl then
        return player:getMainLvl() or 0
    end
    return 0
end

-- Verifies that a player (and their subjob & active pet) genuinely obey targetLevel.
function R.verifyLevelSync(player, targetLevel)
    local result =
    {
        valid              = false,
        original_level     = 0,
        expected_level     = math.floor(tonumber(targetLevel) or 0),
        effective_level    = 0,
        sub_job            = 0,
        sub_level          = 0,
        max_allowed_sub    = 0,
        restriction_active = false,
        restriction_power  = 0,
        pet_level          = nil,
        warnings           = {},
    }

    if player == nil or not player.getMainLvl then
        result.warnings[#result.warnings + 1] = 'invalid_player_entity'
        return result
    end

    local expected = result.expected_level
    local origLvl  = R.getUnsyncedLevel(player)
    local effLvl   = player:getMainLvl() or 0
    local sJob     = player.getSubJob and player:getSubJob() or 0
    local sLvl     = player.getSubLvl and player:getSubLvl() or 0
    local maxSub   = math.floor(expected / 2)
    local restPow  = (player.levelRestriction and player:levelRestriction()) or 0

    result.original_level     = origLvl
    result.effective_level    = effLvl
    result.sub_job            = sJob
    result.sub_level          = sLvl
    result.max_allowed_sub    = maxSub
    result.restriction_power  = restPow
    result.restriction_active = (restPow > 0) or (player.hasStatusEffect and xi.effect and xi.effect.LEVEL_RESTRICTION and player:hasStatusEffect(xi.effect.LEVEL_RESTRICTION) or false)

    if effLvl ~= expected then
        result.warnings[#result.warnings + 1] = string.format('effective_level_mismatch:expected=%d,actual=%d', expected, effLvl)
    end
    if origLvl > expected and not result.restriction_active then
        result.warnings[#result.warnings + 1] = string.format('missing_level_restriction:orig=%d,expected=%d', origLvl, expected)
    end
    if sJob > 0 and sLvl > maxSub then
        result.warnings[#result.warnings + 1] = string.format('subjob_exceeds_cap:sub=%d,max=%d', sLvl, maxSub)
    end

    if player.hasPet and player:hasPet() and player.getPet then
        local pet = player:getPet()
        if pet ~= nil and (not pet.isAlive or pet:isAlive()) and pet.getMainLvl then
            local pLvl = pet:getMainLvl() or 0
            result.pet_level = pLvl
            if pLvl > expected then
                result.warnings[#result.warnings + 1] = string.format('pet_exceeds_effective_level:pet=%d,expected=%d', pLvl, expected)
            end
        end
    end

    result.valid = (#result.warnings == 0)
    return result
end

-- Applies native non-destructive level sync via xi.effect.LEVEL_RESTRICTION.
-- Never modifies database job levels or genkai caps; rejects upward sync cleanly.
function R.applyLevelSync(player, targetLevel)
    if player == nil or not player.isPC or not player:isPC() then
        return false, 'invalid_player', nil
    end

    local expected = math.floor(tonumber(targetLevel) or 0)
    if expected < R.MIN_LEVEL or expected > R.MAX_LEVEL then
        return false, string.format('Unsupported effective level: %d (expected %d-%d).', expected, R.MIN_LEVEL, R.MAX_LEVEL), nil
    end

    -- If already carrying an older Proving Grounds sync, restore cleanly first to read true level.
    if player:getLocalVar('[ProvingGrounds]SyncApplied') == 1 then
        R.restoreLevelSync(player)
    end

    -- Clear any pre-existing party LEVEL_SYNC so it cannot conflict with our benchmark sync.
    if player.hasStatusEffect and xi.effect and xi.effect.LEVEL_SYNC and player:hasStatusEffect(xi.effect.LEVEL_SYNC) then
        player:delStatusEffectSilent(xi.effect.LEVEL_SYNC)
        if player.disableLevelSync then
            pcall(function()
                player:disableLevelSync()
            end)
        end
    end

    local origLvl = player:getMainLvl() or 0
    if origLvl < expected then
        return false, string.format(
            '%s is Lv.%d and cannot level-sync upward to Lv.%d. Select Match Current Level or <= Lv.%d.',
            player.getName and player:getName() or 'Player',
            origLvl,
            expected,
            origLvl
        ), nil
    end

    -- Dismiss any pre-existing Shinobi clones before level change so high-level clones cannot leak in.
    dismissActorClones(player)

    player:setLocalVar('[ProvingGrounds]OrigLvl', origLvl)
    player:setLocalVar('[ProvingGrounds]SyncTargetLvl', expected)
    player:setLocalVar('[ProvingGrounds]SyncApplied', 1)
    if player.setCharVar then
        player:setCharVar('[ProvingGrounds]SyncActive', 1)
    end

    if origLvl > expected then
        if player.delStatusEffectSilent and xi.effect and xi.effect.LEVEL_RESTRICTION then
            player:delStatusEffectSilent(xi.effect.LEVEL_RESTRICTION)
        end
        if player.addStatusEffect and xi.effect and xi.effect.LEVEL_RESTRICTION then
            player:addStatusEffect(xi.effect.LEVEL_RESTRICTION, {
                power    = expected,
                duration = 0,
                origin   = player,
            })
        elseif player.levelRestriction then
            player:levelRestriction(expected)
        end
    end

    -- Resync SoulspireXI Soul scaling, combat pace BASE_HP, and active pets to effective level.
    resyncActorOverlordsSystems(player, true)

    local verification = R.verifyLevelSync(player, expected)
    if not verification.valid then
        -- Never silently allow an invalid level-sync benchmark: roll back cleanly.
        R.restoreLevelSync(player)
        return false, 'Level sync verification failed: ' .. table.concat(verification.warnings, '; '), verification
    end

    return true, nil, verification
end

-- Restores a player's original unsynced state cleanly without leaving any lingering restriction.
function R.restoreLevelSync(player)
    if player == nil or not player.isPC or not player:isPC() then
        return false
    end

    local wasApplied = (player.getLocalVar and player:getLocalVar('[ProvingGrounds]SyncApplied') == 1)
    local charActive = (player.getCharVar and player:getCharVar('[ProvingGrounds]SyncActive') == 1)
    local hasEffect  = (player.hasStatusEffect and xi.effect and xi.effect.LEVEL_RESTRICTION and player:hasStatusEffect(xi.effect.LEVEL_RESTRICTION))
    local curRestr   = (player.levelRestriction and player:levelRestriction()) or 0

    if not wasApplied and not charActive and not hasEffect and curRestr == 0 then
        return false
    end

    -- Dismiss clones summoned at synced level before restoring original level.
    dismissActorClones(player)

    if player.delStatusEffectSilent and xi.effect and xi.effect.LEVEL_RESTRICTION then
        player:delStatusEffectSilent(xi.effect.LEVEL_RESTRICTION)
    end
    if player.levelRestriction and player:levelRestriction() ~= 0 then
        player:levelRestriction(0)
    end

    if player.setLocalVar then
        player:setLocalVar('[ProvingGrounds]SyncApplied', 0)
        player:setLocalVar('[ProvingGrounds]OrigLvl', 0)
        player:setLocalVar('[ProvingGrounds]SyncTargetLvl', 0)
    end
    if player.setCharVar then
        player:setCharVar('[ProvingGrounds]SyncActive', 0)
    end

    resyncActorOverlordsSystems(player, true)
    return true
end

-- Applies or removes -100% combat & magic skill-up rate cleanly without stacking.
function R.applySkillupLock(player, enable)
    if player == nil or not player.getLocalVar or not player.addMod or not player.delMod then
        return
    end

    local locked = player:getLocalVar('[ProvingGrounds]SkillupLocked') == 1
    if enable and not locked then
        if xi.mod and xi.mod.COMBAT_SKILLUP_RATE then
            player:addMod(xi.mod.COMBAT_SKILLUP_RATE, -100)
        end
        if xi.mod and xi.mod.MAGIC_SKILLUP_RATE then
            player:addMod(xi.mod.MAGIC_SKILLUP_RATE, -100)
        end
        player:setLocalVar('[ProvingGrounds]SkillupLocked', 1)
    elseif not enable and locked then
        if xi.mod and xi.mod.COMBAT_SKILLUP_RATE then
            player:delMod(xi.mod.COMBAT_SKILLUP_RATE, -100)
        end
        if xi.mod and xi.mod.MAGIC_SKILLUP_RATE then
            player:delMod(xi.mod.MAGIC_SKILLUP_RATE, -100)
        end
        player:setLocalVar('[ProvingGrounds]SkillupLocked', 0)
    end
end

-- Defense-in-depth zero-progression flags applied to every Proving Grounds mob.
function R.applyNoProgressionMobFlags(mob)
    if mob == nil then
        return
    end

    if mob.setLocalVar then
        mob:setLocalVar('[ProvingGrounds]TrialMob', 1)
    end
    if mob.setDropID then
        mob:setDropID(0)
    end
    if mob.setMobMod and xi.mobMod then
        if xi.mobMod.NO_DROPS then
            mob:setMobMod(xi.mobMod.NO_DROPS, 1)
        end
        if xi.mobMod.GIL_MAX then
            mob:setMobMod(xi.mobMod.GIL_MAX, -1)
        end
        if xi.mobMod.EXP_BONUS then
            mob:setMobMod(xi.mobMod.EXP_BONUS, -100)
        end
    end
    -- Setting CallForHelp skips EXP, Capacity Points, Gil, Item Drops, RoE mob-kill
    -- credit, and BLU spell learning in CMobEntity::DistributeRewards() without
    -- altering combat damage, enmity, TP, or scaling formulas.
    if mob.setCallForHelpFlag then
        mob:setCallForHelpFlag(true)
    end
end

-- Applies strict behavior profile flags after mob:spawn() so AI behaves exactly as labeled.
function R.applyBehaviorProfile(mob, encounter)
    if mob == nil or encounter == nil or encounter.behaviorProfile == nil then
        return
    end

    local b = encounter.behaviorProfile
    if mob.setAutoAttackEnabled then
        mob:setAutoAttackEnabled(b.autoAttack == true)
    end
    if mob.setMagicCastingEnabled then
        mob:setMagicCastingEnabled(b.magicCasting == true)
    end
    if mob.setMobAbilityEnabled then
        mob:setMobAbilityEnabled(b.mobAbility == true)
    end
    if mob.setMobMod and xi.mobMod then
        if b.noMove and xi.mobMod.NO_MOVE then
            mob:setMobMod(xi.mobMod.NO_MOVE, 1)
        end
        if b.magicCool ~= nil and xi.mobMod.MAGIC_COOL then
            local cool = b.magicCool
            local preset = encounter.isNM
                and (xi.customBossServer and xi.customBossServer.config and xi.customBossServer.config.nm)
                or (xi.customBossServer and xi.customBossServer.config and xi.customBossServer.config.normalMob)
            if preset and preset.magicCoolMultiplier then
                cool = math.max(8, math.floor(cool * preset.magicCoolMultiplier))
            end
            mob:setMobMod(xi.mobMod.MAGIC_COOL, cool)
        end
    end
    if b.spellList ~= nil and mob.setSpellList then
        mob:setSpellList(b.spellList)
    end
    if b.unkillable and mob.setUnkillable then
        mob:setUnkillable(true)
    end
end

-- Shared spawner used by BOTH the in-game Arbiter NPC and automated tests.
function R.spawnTrialMob(zone, encounter, callbacks)
    if zone == nil then
        return nil, 'Arena zone is unavailable.'
    end
    if encounter == nil or encounter.archetype == nil then
        return nil, 'Invalid encounter configuration.'
    end

    callbacks = callbacks or {}
    local arch     = encounter.archetype
    local behavior = encounter.behaviorProfile or {}
    local pos      = callbacks.pos or R.BOSS_POS
    local groupId  = encounter.isNM and arch.nmGroupId or arch.groupId
    local groupZn  = encounter.isNM and arch.nmGroupZoneId or arch.groupZoneId
    local allowed  = encounter.isNM and (behavior.nmAllowedSkills or behavior.allowedSkills) or behavior.allowedSkills
    local lifetime = tonumber(callbacks.spawnLifetimeSec) or encounter.durationSec or R.DEFAULT_DURATION_SEC

    local def =
    {
        objtype               = xi.objType.MOB,
        name                  = arch.entityName,
        packetName            = encounter.isNM and (arch.packetName .. ' (NM)') or arch.packetName,
        groupId               = groupId,
        groupZoneId           = groupZn,
        minLevel              = encounter.bossLevel,
        maxLevel              = encounter.bossLevel,
        x                     = pos.x,
        y                     = pos.y,
        z                     = pos.z,
        rotation              = pos.rotation or 128,
        respawn               = 0,
        releaseIdOnDisappear  = true,
        specialSpawnAnimation = false,
        onMobSpawn = function(m)
            R.applyNoProgressionMobFlags(m)
            R.applyBehaviorProfile(m, encounter)
            if callbacks.onMobSpawn then
                callbacks.onMobSpawn(m)
            end
        end,
        onMobFight = function(m, target)
            if behavior.refillHpOnLow and m:getHPP() < 50 then
                m:setHP(m:getMaxHP())
            end
            if m.setCallForHelpFlag and m.getCallForHelpFlag and not m:getCallForHelpFlag() then
                m:setCallForHelpFlag(true)
            end
            if callbacks.onMobFight then
                callbacks.onMobFight(m, target)
            end
        end,
        onMobDeath = function(deadMob, killer, optParams)
            if callbacks.onMobDeath then
                callbacks.onMobDeath(deadMob, killer, optParams)
            end
        end,
        onMobDespawn = function(despawnedMob)
            if callbacks.onMobDespawn then
                callbacks.onMobDespawn(despawnedMob)
            end
        end,
    }

    if behavior.spellList and behavior.spellList > 0 then
        def.spellList = behavior.spellList
    end

    if type(allowed) == 'table' and #allowed > 0 then
        def.onMobMobskillChoose = function(m, target, skillId)
            local idx = (m:getLocalVar('[ProvingGrounds]SkillIdx') % #allowed) + 1
            m:setLocalVar('[ProvingGrounds]SkillIdx', idx)
            local chosen = allowed[idx]
            if callbacks.onMobSkillChosen then
                pcall(callbacks.onMobSkillChosen, m, target, chosen)
            end
            return chosen
        end
    end

    local mob = zone:insertDynamicEntity(def)
    if not mob then
        return nil, 'Failed to allocate dynamic trial mob entity.'
    end

    R.applyNoProgressionMobFlags(mob)
    mob:setSpawn(pos.x, pos.y, pos.z, pos.rotation or 128)
    mob:spawn(lifetime)

    if mob.getMainLvl and mob:getMainLvl() ~= encounter.bossLevel and mob.setMobLevel then
        mob:setMobLevel(encounter.bossLevel)
    end

    -- Apply SoulspireXI live boss scaling ONCE (never double-apply).
    if xi.customBossServer and xi.customBossServer.applyMobScaling then
        if mob:getLocalVar('[CustomBoss]Applied') ~= 1 then
            xi.customBossServer.applyMobScaling(mob)
        end
    end

    R.applyBehaviorProfile(mob, encounter)
    R.applyNoProgressionMobFlags(mob)

    if mob.updateHealth then
        mob:updateHealth()
    end
    if mob.setHP and mob.getMaxHP then
        mob:setHP(mob:getMaxHP())
    end

    mob:setLocalVar('[ProvingGrounds]EncounterLevel', encounter.bossLevel)
    mob:setLocalVar('[ProvingGrounds]BossPresetNM', encounter.isNM and 1 or 0)

    return mob, nil
end

if hasServerRuntime then
    if not R._moduleRegistered then
        R._moduleRegistered = true
        local m = Module:new('soulspire_proving_grounds_registry')

        -- Belt-and-suspenders EXP suppression: Proving Grounds mobs ALWAYS yield 0 EXP.
        m:addOverride('xi.experiencePoints.calculate', function(member, mob, data)
            if mob ~= nil and mob.getLocalVar and mob:getLocalVar('[ProvingGrounds]TrialMob') == 1 then
                return { exp = 0, chainActive = false, chainWindow = 0 }
            end
            return super(member, mob, data)
        end)

        R._module = m
    end
    return R._module
end

return R
