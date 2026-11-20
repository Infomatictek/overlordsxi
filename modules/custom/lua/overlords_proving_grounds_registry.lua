-----------------------------------
-- OverlordsXI Soul Proving Grounds — Shared Encounter Registry
--
-- Single source of truth shared by:
--   1. The in-game NPC Testing Arena (overlords_proving_grounds_lite.lua)
--   2. Server combat telemetry (overlords_proving_grounds_telemetry.lua)
--   3. Automated combat benchmarks (xi_test & Python Stage A/B/C runners)
--
-- Design guarantees:
--   - Zero duplicate encounter tables between manual and automated testing.
--   - Uses existing FFXI mob groups (HP=0 so level scaling is authentic),
--     existing models, and verified single-role ability/spell whitelists.
--   - Integrates directly with xi.customBossServer (boss_like_combat_and_exp)
--     without creating competing balance multipliers or double-scaling.
--   - Enforces defense-in-depth no-progression safeguards on every trial mob.
-----------------------------------
local hasServerRuntime = (Module ~= nil and Module.new ~= nil)
if hasServerRuntime then
    require('modules/module_utils')
    require('scripts/globals/experience_points')
    require('modules/custom/lua/boss_like_combat_and_exp')
end

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.provingGrounds = xi.overlords.provingGrounds or {}
xi.overlords.provingGrounds.registry = xi.overlords.provingGrounds.registry or {}

local R = xi.overlords.provingGrounds.registry

R.SCHEMA_VERSION       = '1.0.0'
R.RUNNER_CONTRACT      = 'overlordsxi-proving-grounds-v1'
R.ARENA_ZONE_ID        = (xi.zone and xi.zone.GM_HOME) or 210
R.NPC_POS              = { x = 5, y = 0, z = 5, rotation = 0 }
R.BOSS_POS             = { x = 5, y = 0, z = 25, rotation = 128 }
R.PLAYER_START_POS     = { x = 5, y = 0, z = 18, rotation = 0 }
R.DEFAULT_DURATION_SEC = 600
R.MIN_LEVEL            = 10
R.MAX_LEVEL            = 75

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
    boss_plus_3 =
    {
        id               = 'boss_plus_3',
        label            = 'Boss +3 Levels',
        levelDelta       = 3,
        standardBaseline = true,
        extremeChallenge = false,
    },
    boss_plus_8 =
    {
        id               = 'boss_plus_8',
        label            = 'Extreme Challenge (+8 Wall)',
        levelDelta       = 8,
        standardBaseline = false,
        extremeChallenge = true,
    },
}

R.DIFFICULTY_ORDER = { 'even_match', 'boss_plus_3', 'boss_plus_8' }

R.BOSS_PRESETS =
{
    normal =
    {
        id         = 'normal',
        label      = 'Standard Boss Scaling',
        isNM       = false,
        configPath = 'xi.customBossServer.config.normalMob',
    },
    nm =
    {
        id         = 'nm',
        label      = 'NM Boss Scaling',
        isNM       = true,
        configPath = 'xi.customBossServer.config.nm',
    },
}

-- Accessible, level-appropriate equipment profiles mapped to xi.overlords.testGear.
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
    trio_standard =
    {
        id          = 'trio_standard',
        label       = 'Standard Trio (Tank / Healer / DPS)',
        size        = 3,
        roles       = { 'tank', 'healer', 'dps' },
        stage       = 'C',
        implemented = false,
        gateReason  = 'Gated behind Milestone C single-actor Lv10 real combat proof.',
    },
}

-- Standardized encounter archetypes.
-- Every NPC-selectable archetype uses verified existing mob_groups (HP=0 so level
-- stats scale authentically) with strict behavior enforcement so a Physical Bruiser
-- never secretly casts spells or AoE moves.
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
        -- Orcish_Guard: WAR/WAR, mobType=0 (Normal), HP=0, spellList=0, delay=240, dmgMult=100
        groupId             = 3723,
        groupZoneId         = 86,
        -- NM variant uses verified mobType=2 physical melee pool (Undead_Leech / Ashu_Talif_Marine)
        -- restricted strictly to physical single-target skills via allowedSkills below.
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
            -- Verified single-target physical skills only:
            --   606 = shoulder_attack (1-hit physical slashing, single target)
            --   607 = slam_dunk (1-hit physical H2H, single target)
            -- Explicitly excludes battle_dance (AoE), howl (buff), aerial_wheel (ranged).
            allowedSkills   = { 606, 607 },
            nmAllowedSkills = { 246 }, -- shackled_fists (single-target physical)
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
        -- Orcish_Hexspinner: BLM/BLM, mobType=0, HP=0, spellList=21 (Beastmen_BLM: Lv10..75 spells)
        groupId             = 3724,
        groupZoneId         = 86,
        nmGroupId           = nil,
        nmGroupZoneId       = nil,
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
            summary         = 'BLM spell list (Beastmen_BLM, Lv10-75) with rapid cast cadence; mob TP abilities disabled.',
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
        -- Gigas_Flanker: WAR/WAR, mobType=0, HP=0, spellList=0
        groupId             = 16,
        groupZoneId         = 129,
        nmGroupId           = nil,
        nmGroupZoneId       = nil,
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            -- Verified AoE damage skills only (no instant-death/suicide/sleep-lock):
            --   665 = grand_slam (physical AoE around mob)
            --   664 = impact_roar (fan-shaped AoE physical blunt)
            allowedSkills   = { 665, 664 },
            magicCool       = nil,
            spellList       = 0,
            summary         = 'Physical autoattacks + strictly whitelisted AoE mobskills (Grand Slam / Impact Roar). No spells.',
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
        -- Orcish_Guard: standard WAR DEF/EVA/level scaling without offensive actions
        groupId             = 3723,
        groupZoneId         = 86,
        nmGroupId           = nil,
        nmGroupZoneId       = nil,
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
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            allowedSkills   = { 606, 607 },
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
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            allowedSkills   = { 606, 607 },
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
        behavior =
        {
            autoAttack      = true,
            magicCasting    = false,
            mobAbility      = true,
            noMove          = false,
            unkillable      = false,
            refillHpOnLow   = false,
            allowedSkills   = { 606, 607 },
            burstIntervalSec = 30,
            burstDurationSec = 10,
            spellList       = 0,
            summary         = 'Planned: short 90s encounter with periodic vulnerability/damage spikes.',
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
function R.buildEncounterConfig(opts)
    opts = opts or {}

    local bossType = tostring(opts.bossType or 'physical_bruiser')
    local archetype = R.ARCHETYPES[bossType]
    if not archetype then
        return nil, string.format('Unknown bossType: %s', bossType)
    end

    local difficultyKey = tostring(opts.difficulty or 'even_match')
    local difficulty = R.DIFFICULTIES[difficultyKey]
    if not difficulty then
        return nil, string.format('Unknown difficulty: %s', difficultyKey)
    end

    local bossPresetKey = tostring(opts.bossPreset or 'normal')
    local bossPreset = R.BOSS_PRESETS[bossPresetKey]
    if not bossPreset then
        return nil, string.format('Unknown bossPreset: %s', bossPresetKey)
    end

    if bossPreset.isNM and archetype.nmGroupId == nil then
        return nil, string.format('Archetype %s does not yet have a verified NM mob group.', bossType)
    end

    local playerLevel = math.floor(tonumber(opts.playerLevel) or tonumber(opts.bossLevel) or 10)
    playerLevel = math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, playerLevel))

    local bossLevel = opts.bossLevel ~= nil and math.floor(tonumber(opts.bossLevel) or 0) or (playerLevel + difficulty.levelDelta)
    if bossLevel < R.MIN_LEVEL or bossLevel > (R.MAX_LEVEL + 8) then
        return nil, string.format('Unsupported bossLevel: %s (expected %d..%d)', tostring(bossLevel), R.MIN_LEVEL, R.MAX_LEVEL + 8)
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
        encounterId       = encounterId,
        version           = R.SCHEMA_VERSION,
        bossType          = bossType,
        bossLabel         = archetype.label,
        bossLevel         = bossLevel,
        playerLevel       = playerLevel,
        levelGap          = levelGap,
        difficulty        = difficultyKey,
        difficultyMeta    = difficulty,
        bossPreset        = bossPresetKey,
        isNM              = bossPreset.isNM,
        behaviorProfile   = archetype.behavior,
        archetype         = archetype,
        durationSec       = durationSec,
        gearProfile       = gearProfile.id,
        gearProfileMeta   = gearProfile,
        partyComposition  = partyKey,
        partyMeta         = partyComp,
        seed              = seed,
        combatRules       = R.snapshotCombatRules(),
    }, nil
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
-- Guarantees:
--   1. Exact mob level is set via minLevel/maxLevel BEFORE spawn().
--   2. xi.customBossServer.applyMobScaling runs ONCE (never double-applied).
--   3. Behavior profile and no-progression flags are strictly enforced.
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
        packetName            = arch.packetName,
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
            -- Keep Training Dummy above 50% HP so unbounded DPS tests never sit at 1 HP.
            if behavior.refillHpOnLow and m:getHPP() < 50 then
                m:setHP(m:getMaxHP())
            end
            -- Re-assert CallForHelp so combat claim transitions never clear no-reward safety.
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
            return allowed[idx]
        end
    end

    local mob = zone:insertDynamicEntity(def)
    if not mob then
        return nil, 'Failed to allocate dynamic trial mob entity.'
    end

    R.applyNoProgressionMobFlags(mob)
    mob:setSpawn(pos.x, pos.y, pos.z, pos.rotation or 128)
    mob:spawn(lifetime)

    -- Verify exact boss level was materialized before confirming scaling.
    if mob.getMainLvl and mob:getMainLvl() ~= encounter.bossLevel and mob.setMobLevel then
        mob:setMobLevel(encounter.bossLevel)
    end

    -- Apply OverlordsXI live boss scaling ONCE.
    -- xi.mob.onMobSpawnEx already invokes applyMobScaling(mob) and sets [CustomBoss]Applied = 1;
    -- calling it here only catches cases where onMobSpawnEx did not run and never double-applies.
    if xi.customBossServer and xi.customBossServer.applyMobScaling then
        if mob:getLocalVar('[CustomBoss]Applied') ~= 1 then
            xi.customBossServer.applyMobScaling(mob)
        end
    end

    -- Re-apply strict behavior profile and no-progression flags AFTER spawn + boss scaling
    -- so boss_like_combat_and_exp's magicCoolMultiplier / listeners respect our locked profile.
    R.applyBehaviorProfile(mob, encounter)
    R.applyNoProgressionMobFlags(mob)

    -- Re-sync HP to full after all scaling/modifiers are finalized.
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
        local m = Module:new('overlords_proving_grounds_registry')

        -- Belt-and-suspenders EXP suppression: even if CallForHelp were somehow cleared,
        -- Proving Grounds mobs ALWAYS calculate 0 EXP and never extend EXP chains.
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
