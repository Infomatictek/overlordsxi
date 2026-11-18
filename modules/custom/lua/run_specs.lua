-----------------------------------
-- OverlordsXI Rune Fencer Crystal Specs
-- Registers Rune Fencer crystals (Inquisitor, Spellblade, Lifebinder) and
-- implements their scaling passive stats, custom Job Abilities (412-418),
-- and base RUN ability/spell transformations.
--
-- Spellblade implements the Greatsword + Active Casting Conduction loop:
--   Enchanted attacks (Rune Edge) -> Conduction (max 3) + delay-adjusted MP
--   -> Prepared offensive spell (Runic Bolt / Runic Sever) -> Edgeflare (+25%
--   Rune Edge for 12s) -> Stronger enchanted attacks.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/basic/damage_multipliers')
require('scripts/combat/basic/magic_aoe')
require('scripts/combat/basic/magic_burst')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/combat/physical_utilities')
require('scripts/combat/skillchain')
require('scripts/globals/job_utils/rune_fencer')
require('scripts/globals/spells/damage_spell')
-----------------------------------
local m = Module:new('overlords_run_specs')

local spec = xi.overlords.spec

local INQUISITOR_KEY = 'inquisitor'
local SPELLBLADE_KEY = 'spellblade'
local LIFEBINDER_KEY = 'lifebinder'

-- Custom Job Ability IDs (412-418)
local ABIL_IRON_BATTUTA      = 412
local ABIL_RUNIC_AEGIS       = 413
local ABIL_RUNIC_CONVERGENCE = 414
local ABIL_EFFUSION_SLASH    = 415
local ABIL_OVERCHARGE_RUNES  = 416
local ABIL_FONT_OF_LIFE      = 417
local ABIL_SANCTIFIED_WARD   = 418

-- Custom Status Effect IDs (821-828, 831, within MAX_EFFECTID = 832)
local EFFECT_IRON_BATTUTA      = 821
local EFFECT_RUNIC_AEGIS       = 822
local EFFECT_RUNIC_CONVERGENCE = 823
local EFFECT_EDGEFLARE         = 824
local EFFECT_FONT_OF_LIFE      = 825
local EFFECT_SANCTIFIED_WARD   = 826
local EFFECT_CONDUCTION        = 827
local EFFECT_RUNIC_ASCENDANCE  = 828
local EFFECT_OVERCHARGE_RUNES  = 831

-- Custom Job Trait IDs (150-152 -> menu_ids 1686-1688)
local TRAIT_INQUISITOR_WARD = 150
local TRAIT_RUNIC_BRAND     = 151
local TRAIT_SACRED_PULSE    = 152

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.IRON_BATTUTA      = ABIL_IRON_BATTUTA
xi.jobAbility.RUNIC_AEGIS       = ABIL_RUNIC_AEGIS
xi.jobAbility.RUNIC_CONVERGENCE = ABIL_RUNIC_CONVERGENCE
xi.jobAbility.EFFUSION_SLASH    = ABIL_EFFUSION_SLASH
xi.jobAbility.OVERCHARGE_RUNES  = ABIL_OVERCHARGE_RUNES
xi.jobAbility.FONT_OF_LIFE      = ABIL_FONT_OF_LIFE
xi.jobAbility.SANCTIFIED_WARD   = ABIL_SANCTIFIED_WARD

xi.effect = xi.effect or {}
xi.effect.INQUISITOR_BATTUTA    = EFFECT_IRON_BATTUTA
xi.effect.INQUISITOR_AEGIS      = EFFECT_RUNIC_AEGIS
xi.effect.INQUISITOR_CONVERGE   = EFFECT_RUNIC_CONVERGENCE
xi.effect.SPELLBLADE_EDGEFLARE  = EFFECT_EDGEFLARE
xi.effect.SPELLBLADE_OVERCHARGE = EFFECT_OVERCHARGE_RUNES
xi.effect.LIFEBINDER_FONT       = EFFECT_FONT_OF_LIFE
xi.effect.LIFEBINDER_SANCTUARY  = EFFECT_SANCTIFIED_WARD
xi.effect.SPELLBLADE_CONDUCTION = EFFECT_CONDUCTION
xi.effect.SPELLBLADE_ASCENDANCE = EFFECT_RUNIC_ASCENDANCE

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.iron_battuta      = xi.actions.abilities.iron_battuta or {}
xi.actions.abilities.runic_aegis       = xi.actions.abilities.runic_aegis or {}
xi.actions.abilities.runic_convergence = xi.actions.abilities.runic_convergence or {}
xi.actions.abilities.effusion_slash    = xi.actions.abilities.effusion_slash or {}
xi.actions.abilities.overcharge_runes  = xi.actions.abilities.overcharge_runes or {}
xi.actions.abilities.font_of_life      = xi.actions.abilities.font_of_life or {}
xi.actions.abilities.sanctified_ward   = xi.actions.abilities.sanctified_ward or {}

xi.effects = xi.effects or {}
xi.effects.inquisitor_battuta    = xi.effects.inquisitor_battuta or {}
xi.effects.inquisitor_aegis      = xi.effects.inquisitor_aegis or {}
xi.effects.inquisitor_converge   = xi.effects.inquisitor_converge or {}
xi.effects.spellblade_edgeflare  = xi.effects.spellblade_edgeflare or {}
xi.effects.spellblade_overcharge = xi.effects.spellblade_overcharge or {}
xi.effects.lifebinder_font       = xi.effects.lifebinder_font or {}
xi.effects.lifebinder_sanctuary  = xi.effects.lifebinder_sanctuary or {}
xi.effects.spellblade_conduction = xi.effects.spellblade_conduction or {}
xi.effects.spellblade_ascendance = xi.effects.spellblade_ascendance or {}

local RUNE_ELEMENT_MAP =
{
    [xi.effect.IGNIS   ] = xi.element.FIRE,
    [xi.effect.GELUS   ] = xi.element.ICE,
    [xi.effect.FLABRA  ] = xi.element.WIND,
    [xi.effect.TELLUS  ] = xi.element.EARTH,
    [xi.effect.SULPOR  ] = xi.element.THUNDER,
    [xi.effect.UNDA    ] = xi.element.WATER,
    [xi.effect.LUX     ] = xi.element.LIGHT,
    [xi.effect.TENEBRAE] = xi.element.DARK,
}

-- Opposing element damage reduction modifier for Vallation (Ignis=Fire protects vs Ice, etc.)
local RUNE_OPPOSING_SDT_MAP =
{
    [xi.effect.IGNIS   ] = xi.mod.ICE_SDT,
    [xi.effect.GELUS   ] = xi.mod.WIND_SDT,
    [xi.effect.FLABRA  ] = xi.mod.EARTH_SDT,
    [xi.effect.TELLUS  ] = xi.mod.THUNDER_SDT,
    [xi.effect.SULPOR  ] = xi.mod.WATER_SDT,
    [xi.effect.UNDA    ] = xi.mod.FIRE_SDT,
    [xi.effect.LUX     ] = xi.mod.DARK_SDT,
    [xi.effect.TENEBRAE] = xi.mod.LIGHT_SDT,
}

-- Additional effect visual proc IDs (ActionProcAddEffect::FireDamage..DarkDamage = 1..8)
local RUNE_SUBEFFECT_MAP =
{
    [xi.effect.IGNIS   ] = (xi.subEffect and xi.subEffect.FIRE_DAMAGE) or 1,
    [xi.effect.GELUS   ] = (xi.subEffect and xi.subEffect.ICE_DAMAGE) or 2,
    [xi.effect.FLABRA  ] = (xi.subEffect and xi.subEffect.WIND_DAMAGE) or 3,
    [xi.effect.TELLUS  ] = (xi.subEffect and xi.subEffect.EARTH_DAMAGE) or 4,
    [xi.effect.SULPOR  ] = (xi.subEffect and xi.subEffect.LIGHTNING_DAMAGE) or 5,
    [xi.effect.UNDA    ] = (xi.subEffect and xi.subEffect.WATER_DAMAGE) or 6,
    [xi.effect.LUX     ] = (xi.subEffect and xi.subEffect.LIGHT_DAMAGE) or 7,
    [xi.effect.TENEBRAE] = (xi.subEffect and xi.subEffect.DARKNESS_DAMAGE) or 8,
}

-- Effusion elemental animation info values (verified from scripts/globals/job_utils/rune_fencer.lua)
local RUNE_EFFUSION_INFO_MAP =
{
    [xi.effect.IGNIS   ] = 2,
    [xi.effect.GELUS   ] = 4,
    [xi.effect.FLABRA  ] = 6,
    [xi.effect.TELLUS  ] = 8,
    [xi.effect.SULPOR  ] = 10,
    [xi.effect.UNDA    ] = 12,
    [xi.effect.LUX     ] = 14,
    [xi.effect.TENEBRAE] = 16,
}

local REMOVABLE_DEBUFFS =
{
    xi.effect.POISON,
    xi.effect.PARALYSIS,
    xi.effect.BLINDNESS,
    xi.effect.SILENCE,
    xi.effect.SLOW,
    xi.effect.WEIGHT,
    xi.effect.BIND,
    xi.effect.PLAGUE,
    xi.effect.DISEASE,
    xi.effect.CURSE_I,
    xi.effect.CURSE_II,
    xi.effect.ADDLE,
    xi.effect.DEFENSE_DOWN,
    xi.effect.MAGIC_DEF_DOWN,
    xi.effect.ATTACK_DOWN,
    xi.effect.ACCURACY_DOWN,
}

local SPELLBLADE_GAMBIT_POWER = 110

local function tell(player, message)
    if player ~= nil and player.printToPlayer then
        player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
    end
end

local function scaleTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 then
        return lv70 or lv50, 4
    elseif l >= 50 then
        return lv50, 3
    elseif l >= 30 then
        return lv30, 2
    end
    return lv10, 1
end

-- Compute A-rank skill level at a given level (used to grant Spellblade RUN A-rank Elemental Magic skill)
local function getARankSkillForLevel(lvl)
    local l = math.max(1, lvl or 1)
    if l <= 50 then
        return 6 + (l - 1) * 3
    elseif l <= 60 then
        return 153 + (l - 50) * 5
    elseif l <= 70 then
        return 203 + math.floor((l - 60) * 4.1)
    elseif l <= 75 then
        return 244 + (l - 70) * 5
    else
        return 269 + (l - 75) * 5
    end
end

-- Bonus needed to raise RUN's native A- Greatsword skill (269 @ 75) to A+ (276 @ 75)
local function getGreatswordAPlusBonus(lvl)
    local l = math.max(1, lvl or 1)
    if l <= 50 then
        return 0
    elseif l <= 60 then
        return 0
    elseif l <= 70 then
        return math.max(1, math.floor((l - 60) * 0.7))
    else
        return 7
    end
end

-- Keep Enhancing Magic at full native rank on Spellblade (no Lv.70+ skill penalty)
local function getEnhancingBRankDelta(_lvl)
    return 0
end

local function isRunSpec(entity, specKey)
    if entity == nil or not entity.isPC or not entity:isPC() or entity:getMainJob() ~= xi.job.RUN then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.RUN, specKey)
end

local function isGreatSwordEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.GREAT_SWORD
end

local function getMainSubWeaponSignature(player)
    if player == nil then
        return 0
    end
    local mainId = 0
    local subId  = 0
    if player.getEquipID and xi.slot then
        mainId = player:getEquipID(xi.slot.MAIN) or 0
        subId  = player:getEquipID(xi.slot.SUB) or 0
    end
    return mainId * 65536 + subId
end

-- Base weapon delay before Haste / Dual Wield / Martial Arts (defaults to 480 for standard Greatswords)
local function getWeaponBaseDelay(player)
    if player == nil then
        return 480
    end
    if player.getBaseDelay then
        local d = player:getBaseDelay()
        if type(d) == 'number' and d > 0 then
            return d
        end
    end
    if player.getWeaponDelay then
        local d = player:getWeaponDelay(false)
        if type(d) == 'number' and d > 0 then
            -- CItemWeapon::getDelay() returns (delay * 1000) / 60 in LandSandBoat if > 1000, or raw delay
            if d > 1200 then
                return math.floor((d * 60) / 1000 + 0.5)
            end
            return d
        end
    end
    return 480
end

local function grantEnmity(mob, player, ce, ve)
    if mob == nil or player == nil or mob == player then
        return
    end

    if mob.addEnmity then
        mob:addEnmity(player, ce, ve)
    elseif mob.updateEnmityFromDamage then
        mob:updateEnmityFromDamage(player, math.floor((ce + ve) / 4))
    end
end

local function pulseNearbyEnmity(player, ce, ve, radius)
    if player == nil then
        return
    end

    local maxDist = radius or 12.0
    local mainTarget = player.getTarget and player:getTarget() or nil
    local mainTargetId = nil
    if mainTarget ~= nil and mainTarget.isMob and mainTarget:isMob() and mainTarget:isAlive() then
        mainTargetId = mainTarget:getID()
        grantEnmity(mainTarget, player, ce, ve)
    end

    local zone = player.getZone and player:getZone() or nil
    if zone ~= nil and zone.getMobs then
        for _, mob in ipairs(zone:getMobs()) do
            if
                mob ~= nil and
                mob:isMob() and
                mob:isAlive() and
                mob:getID() ~= mainTargetId and
                mob:checkDistance(player) <= maxDist and
                mob:isEngaged()
            then
                local mobTarget = mob.getTarget and mob:getTarget() or nil
                if mobTarget ~= nil and (mobTarget:getID() == player:getID() or (player.isInPartyWith and player:isInPartyWith(mobTarget))) then
                    grantEnmity(mob, player, ce, ve)
                end
            end
        end
    end
end

local function getActiveRunesList(player)
    if player == nil then
        return {}
    end

    if player.getAllRuneEffects then
        local list = player:getAllRuneEffects()
        if type(list) == 'table' then
            return list
        end
    end

    local out = {}
    if player.getStatusEffects then
        for _, eff in ipairs(player:getStatusEffects()) do
            local effId = eff:getEffectType()
            if effId >= xi.effect.IGNIS and effId <= xi.effect.TENEBRAE then
                table.insert(out, effId)
            end
        end
    end
    return out
end

local function snapshotRunes(player)
    local runes = getActiveRunesList(player)
    local copy  = {}
    for i, r in ipairs(runes) do
        copy[i] = r
    end
    return copy
end

local function getSpellbladeRuneSlotCap(lvl)
    local l = lvl or 1
    if l >= 65 then
        return 3
    elseif l >= 35 then
        return 2
    end
    return 1
end

local function getSpellbladeRuneResistancePower(lvl)
    local l = math.max(1, lvl or 1)
    -- 8 protective resistance per rune at Lv.75
    return math.max(1, math.floor((8 * l) / 75))
end

local function restoreRunes(player, savedRunes)
    if player == nil or type(savedRunes) ~= 'table' or #savedRunes == 0 then
        return
    end

    local runLevel = player.getMainLvl and player:getMainLvl() or 10
    local power
    if isRunSpec(player, SPELLBLADE_KEY) then
        power = getSpellbladeRuneResistancePower(runLevel)
    else
        local meritBonus    = player.getMerit and player:getMerit(xi.merit.RUNE_ENHANCE) or 0
        local jobPointBonus = player.getJobPointLevel and player:getJobPointLevel(xi.jp.RUNE_ENCHANTMENT_EFFECT) or 0
        power               = math.floor((49 * runLevel / 99) + 5.5) + meritBonus + jobPointBonus
    end

    if player.removeAllRunes then
        player:removeAllRunes()
    end

    for _, runeId in ipairs(savedRunes) do
        player:addStatusEffect(runeId, { power = power, duration = 300, origin = player })
    end
end

local function refreshActiveRuneDurations(player)
    local saved = snapshotRunes(player)
    if #saved > 0 then
        restoreRunes(player, saved)
    end
end

local function cleanseTargetDebuffs(target, maxCount)
    if target == nil or not target.hasStatusEffect or not target.delStatusEffect then
        return 0
    end

    local removed = 0
    local limit   = maxCount or 1
    for _, debuffId in ipairs(REMOVABLE_DEBUFFS) do
        if debuffId ~= nil and target:hasStatusEffect(debuffId) then
            target:delStatusEffect(debuffId)
            removed = removed + 1
            if removed >= limit then
                break
            end
        end
    end
    return removed
end

local function getPartyMembersInRange(player, radius)
    if player == nil then
        return {}
    end

    local maxDist  = radius or 12.0
    local out      = {}
    local seen     = {}
    local pZone    = player.getZoneID and player:getZoneID() or nil
    local playerId = player.getID and player:getID() or nil

    local function tryInsert(entity)
        if
            entity ~= nil and
            entity.getID and
            not seen[entity:getID()] and
            (not entity.isAlive or entity:isAlive()) and
            (pZone == nil or not entity.getZoneID or entity:getZoneID() == pZone) and
            ((playerId ~= nil and entity:getID() == playerId) or (player.checkDistance and player:checkDistance(entity) <= maxDist))
        then
            seen[entity:getID()] = true
            table.insert(out, entity)
        end
    end

    local rawList = nil
    if player.getPartyWithTrusts then
        rawList = player:getPartyWithTrusts()
    elseif player.getParty then
        rawList = player:getParty()
    end

    if type(rawList) == 'table' then
        for _, member in pairs(rawList) do
            tryInsert(member)
            if member ~= nil and member.hasPet and member:hasPet() then
                tryInsert(member:getPet())
            end
        end
    end

    tryInsert(player)
    if player.hasPet and player:hasPet() then
        tryInsert(player:getPet())
    end

    return out
end

local FALLBACK_EFFECT_MAP =
{
    [EFFECT_IRON_BATTUTA]      = 816, -- commander_bulwark
    [EFFECT_RUNIC_AEGIS]       = 820, -- gladiator_ward
    [EFFECT_RUNIC_CONVERGENCE] = 818, -- commander_regroup
    [EFFECT_EDGEFLARE]         = 819, -- berserker_surge
    [EFFECT_FONT_OF_LIFE]      = 817, -- commander_cadence
    [EFFECT_SANCTIFIED_WARD]   = 820, -- gladiator_ward
    [EFFECT_CONDUCTION]        = 815, -- commander_breach
    [EFFECT_RUNIC_ASCENDANCE]  = 818, -- commander_regroup
    [EFFECT_OVERCHARGE_RUNES]  = 817, -- commander_cadence
}

local pendingRunEffectMods = {}

local function applyPendingRunEffectMods(target, effect)
    if target == nil or effect == nil or not target.getID then
        return
    end

    local targetId = target:getID()
    local mods     = pendingRunEffectMods[targetId]
    if type(mods) == 'table' and effect.addMod then
        for _, pair in ipairs(mods) do
            if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                effect:addMod(pair[1], pair[2])
            end
        end
        pendingRunEffectMods[targetId] = nil
    end
end

for _, effKey in ipairs({
    'inquisitor_battuta',
    'inquisitor_aegis',
    'inquisitor_converge',
    'spellblade_edgeflare',
    'spellblade_overcharge',
    'lifebinder_font',
    'lifebinder_sanctuary',
    'spellblade_conduction',
    'spellblade_ascendance',
}) do
    xi.effects[effKey] = xi.effects[effKey] or {}
    xi.effects[effKey].onEffectGain = function(target, effect)
        applyPendingRunEffectMods(target, effect)
    end
    xi.effects[effKey].onEffectLose = function(_target, _effect)
    end
    m:addOverride('xi.effects.' .. effKey .. '.onEffectGain', function(target, effect)
        applyPendingRunEffectMods(target, effect)
    end)
    m:addOverride('xi.effects.' .. effKey .. '.onEffectLose', function(_target, _effect)
    end)
end

for _, fbKey in ipairs({
    'commander_breach',
    'commander_bulwark',
    'commander_cadence',
    'commander_regroup',
    'berserker_surge',
    'gladiator_ward',
}) do
    xi.effects[fbKey] = xi.effects[fbKey] or {}
    m:addOverride('xi.effects.' .. fbKey .. '.onEffectGain', function(target, effect)
        if super then
            super(target, effect)
        end
        applyPendingRunEffectMods(target, effect)
    end)
end

local function getRunCustomEffect(target, effectId)
    if target == nil or not target.getStatusEffect then
        return nil
    end
    local eff = target:getStatusEffect(effectId)
    if eff ~= nil then
        return eff
    end
    local fbId = FALLBACK_EFFECT_MAP[effectId]
    if fbId ~= nil then
        return target:getStatusEffect(fbId)
    end
    return nil
end

local function hasRunCustomEffect(target, effectId)
    return getRunCustomEffect(target, effectId) ~= nil
end

local function delRunCustomEffectSilent(target, effectId)
    if target == nil or not target.delStatusEffectSilent then
        return
    end
    if target.hasStatusEffect and target:hasStatusEffect(effectId) then
        target:delStatusEffectSilent(effectId)
    end
    local fbId = FALLBACK_EFFECT_MAP[effectId]
    if fbId ~= nil and target.hasStatusEffect and target:hasStatusEffect(fbId) then
        target:delStatusEffectSilent(fbId)
    end
end

local function applyTimedEffectWithMods(target, effectId, power, duration, origin, subPower, iconId, mods)
    if target == nil or not target.addStatusEffect then
        return false, effectId
    end

    delRunCustomEffectSilent(target, effectId)

    local targetId = target.getID and target:getID() or 0
    pendingRunEffectMods[targetId] = mods

    local params =
    {
        power    = power or 1,
        duration = duration or 15,
        origin   = origin or target,
        subPower = subPower or 0,
        icon     = (xi.overlords and xi.overlords.getStatusIcon and xi.overlords.getStatusIcon(effectId, iconId)) or iconId or effectId,
    }

    local actualId = effectId
    local ok       = target:addStatusEffect(effectId, params)
    if not ok or (target.hasStatusEffect and not target:hasStatusEffect(effectId)) then
        local fbId = FALLBACK_EFFECT_MAP[effectId]
        if fbId ~= nil then
            pendingRunEffectMods[targetId] = mods
            if target.hasStatusEffect and target:hasStatusEffect(fbId) then
                target:delStatusEffectSilent(fbId)
            end
            ok       = target:addStatusEffect(fbId, params)
            actualId = fbId
        end
    end

    -- Fallback if onEffectGain did not consume pendingRunEffectMods
    local leftover = pendingRunEffectMods[targetId]
    pendingRunEffectMods[targetId] = nil
    if ok and type(leftover) == 'table' then
        local eff = target.getStatusEffect and target:getStatusEffect(actualId) or nil
        if eff ~= nil and eff.addMod then
            for _, pair in ipairs(leftover) do
                if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                    eff:addMod(pair[1], pair[2])
                end
            end
        end
    end

    return ok, actualId
end

local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

-----------------------------------
-- Spellblade Conduction, Edgeflare, & Gambit Helpers
-----------------------------------
local function getConductionStacks(player)
    if player == nil or not player.getLocalVar then
        return 0
    end
    return utils.clamp(player:getLocalVar('OX_RUN_CONDUCTION') or 0, 0, 3)
end

local function syncConductionStatusEffect(player, stacks)
    if player == nil then
        return
    end
    if stacks <= 0 then
        delRunCustomEffectSilent(player, EFFECT_CONDUCTION)
        return
    end

    local iconId = (xi.effect and xi.effect.CHAINBOUND) or EFFECT_CONDUCTION
    applyTimedEffectWithMods(
        player,
        EFFECT_CONDUCTION,
        stacks,
        30,
        player,
        stacks,
        iconId,
        nil
    )
end

local function clearConduction(player, reasonMsg)
    if player == nil or not player.setLocalVar then
        return
    end
    local prev = getConductionStacks(player)
    player:setLocalVar('OX_RUN_CONDUCTION', 0)
    player:setLocalVar('OX_RUN_PREP_STACKS', 0)
    player:setLocalVar('OX_RUN_DISENGAGE_TS', 0)
    syncConductionStatusEffect(player, 0)
    if prev > 0 and reasonMsg ~= nil then
        tell(player, reasonMsg)
    end
end

local function setConductionStacks(player, newStacks, silent)
    if player == nil or not player.setLocalVar then
        return 0
    end
    local prev    = getConductionStacks(player)
    local clamped = utils.clamp(newStacks or 0, 0, 3)
    player:setLocalVar('OX_RUN_CONDUCTION', clamped)
    syncConductionStatusEffect(player, clamped)
    if not silent and clamped ~= prev and clamped > 0 then
        tell(player, string.format('[Spellblade] Conduction: %d/3', clamped))
    end
    return clamped
end

local function addConductionStacks(player, delta)
    if player == nil then
        return 0
    end
    local lvl = player.getMainLvl and player:getMainLvl() or 1
    if lvl < 10 or not isGreatSwordEquipped(player) then
        return getConductionStacks(player)
    end
    local cur = getConductionStacks(player)
    return setConductionStacks(player, math.min(3, cur + (delta or 1)), false)
end

xi.overlords = xi.overlords or {}
xi.overlords.runSpecs = xi.overlords.runSpecs or {}
xi.overlords.runSpecs.addConduction = addConductionStacks

local function hasEdgeflare(player, activeElement)
    local eff = getRunCustomEffect(player, EFFECT_EDGEFLARE)
    if eff == nil then
        return false
    end
    if activeElement ~= nil and eff.getSubPower and eff:getSubPower() ~= 0 and eff:getSubPower() ~= activeElement then
        return false
    end
    return true
end

local function grantOrRefreshEdgeflare(player, element)
    if player == nil then
        return
    end
    local lvl = player.getMainLvl and player:getMainLvl() or 1
    if lvl < 30 then
        return
    end
    local iconId = (xi.effect and xi.effect.EMBOLDEN) or EFFECT_EDGEFLARE
    applyTimedEffectWithMods(
        player,
        EFFECT_EDGEFLARE,
        25,
        12,
        player,
        element or 0,
        iconId,
        nil
    )
end

local function hasRunicAscendance(player)
    return hasRunCustomEffect(player, EFFECT_RUNIC_ASCENDANCE)
end

local function hasOverchargeRunes(player)
    return hasRunCustomEffect(player, EFFECT_OVERCHARGE_RUNES)
end

-- Check if target has Spellblade Gambit active for the given element (returns 1.10 or 1.0)
local function getSpellbladeGambitMultiplier(target, element)
    if target == nil or element == nil or not target.getStatusEffect then
        return 1.0
    end
    local eff = target:getStatusEffect(xi.effect.GAMBIT)
    if eff == nil then
        return 1.0
    end
    local power    = eff.getPower and eff:getPower() or 0
    local subPower = eff.getSubPower and eff:getSubPower() or 0
    if power == SPELLBLADE_GAMBIT_POWER and subPower == element then
        return 1.10
    end
    return 1.0
end

-- Apply era accumulative magic resistance ("Nuke Wall") identical to scripts/globals/spells/damage_spell.lua
local function applyAccumulativeMagicWall(target, spellElement, currentDamage)
    local nukeWallId = xi.effect and xi.effect.NUKE_WALL
    if
        nukeWallId == nil or
        target == nil or
        currentDamage <= 0 or
        not target.isNM or
        not target:isNM() or
        spellElement == nil or
        spellElement < xi.element.FIRE or
        spellElement > xi.element.DARK
    then
        return 1.0
    end

    local potency = 0
    local effect  = target.getStatusEffect and target:getStatusEffect(nukeWallId) or nil
    if effect ~= nil then
        potency = effect:getPower()
        if effect.getTimeRemaining and effect:getTimeRemaining() <= 4000 then
            potency = utils.clamp(potency - 2000, 0, 4000)
        end

        if xi.effect.RAYKE ~= nil and target.hasStatusEffect and target:hasStatusEffect(xi.effect.RAYKE) then
            local raykeEff = target:getStatusEffect(xi.effect.RAYKE)
            local raykeSub = raykeEff and raykeEff.getSubPower and raykeEff:getSubPower() or 0
            for i = 0, 16, 4 do
                if bit.band(bit.rshift(raykeSub, i), 0xF) == spellElement then
                    potency = math.floor(potency / 2)
                    break
                end
            end
        end

        if target.delStatusEffectSilent then
            target:delStatusEffectSilent(nukeWallId)
        end
    end

    local targetLvl    = math.max(1, target.getMainLvl and target:getMainLvl() or 1)
    local damageCap    = targetLvl * 21 + 500
    local finalPotency = utils.clamp(math.floor(4000 * currentDamage / damageCap) + potency, 0, 4000)

    if target.addStatusEffect then
        target:addStatusEffect(nukeWallId,
        {
            power    = finalPotency,
            duration = 5,
            origin   = target,
            icon     = 0,
            subPower = spellElement,
        })
    end

    return math.max(0, 1.0 - potency / 10000)
end

-----------------------------------
-- Spellblade Rune Edge & Conduction Combat Engine
-----------------------------------
local function evaluateRuneEdgeRound(actor, target, action)
    if
        actor == nil or
        target == nil or
        target == actor or
        not isRunSpec(actor, SPELLBLADE_KEY) or
        not isGreatSwordEquipped(actor)
    then
        return
    end

    -- 1. Conduction generation on any landed normal attack round (Lv.10+)
    local lvl = actor.getMainLvl and actor:getMainLvl() or 10
    if lvl >= 10 then
        local gain = hasRunicAscendance(actor) and 2 or 1
        addConductionStacks(actor, gain)
    end

    -- 2. Rune Edge additional effect on the first landed hit in the round
    if target.isAlive and not target:isAlive() then
        return
    end

    local runes     = getActiveRunesList(actor)
    local runeCount = #runes
    if runeCount <= 0 then
        return
    end

    local newestRune = (actor.getNewestRuneEffect and actor:getNewestRuneEffect()) or runes[#runes]
    local element    = RUNE_ELEMENT_MAP[newestRune] or xi.element.FIRE
    local subEffect  = RUNE_SUBEFFECT_MAP[newestRune] or 1
    local targetId   = target:getID()

    -- Nullification check
    if
        xi.spells and
        xi.spells.damage and
        xi.spells.damage.calculateNullification and
        xi.spells.damage.calculateNullification(target, element, false, true, false, false) == 0
    then
        if action ~= nil then
            if action.additionalEffect then
                action:additionalEffect(targetId, subEffect)
            end
            if action.addEffectParam then
                action:addEffectParam(targetId, 0)
            end
            if action.addEffectMessage and xi.msg and xi.msg.basic then
                action:addEffectMessage(targetId, xi.msg.basic.ADD_EFFECT_DMG or 163)
            end
        end
        return
    end

    local gsSkill   = actor.getSkillLevel and actor:getSkillLevel(xi.skill.GREAT_SWORD) or (lvl * 3)
    local enhSkill  = actor.getSkillLevel and actor:getSkillLevel(xi.skill.ENHANCING_MAGIC) or (lvl * 3)
    local baseDelay = getWeaponBaseDelay(actor)

    -- Exact Rune Edge base formula:
    -- floor((0.08 * Greatsword skill + 0.04 * Enhancing skill + 4 * active runes) * weapon base delay / 480)
    local baseDmg = math.floor(((0.08 * gsSkill) + (0.04 * enhSkill) + (4 * runeCount)) * baseDelay / 480)
    if baseDmg <= 0 then
        baseDmg = 1
    end

    -- Edgeflare (+25%) and Runic Ascendance (+50%) add together up to +75%; Overcharge Runes doubles Runic Brand damage
    local bonusMult = 1.0
    if hasEdgeflare(actor, element) then
        bonusMult = bonusMult + 0.25
    end
    if hasRunicAscendance(actor) then
        bonusMult = bonusMult + 0.50
    end
    local damage = math.floor(baseDmg * bonusMult)
    if hasOverchargeRunes(actor) then
        damage = damage * 2
    end

    local absorb = false
    if xi.spells and xi.spells.damage and xi.spells.damage.calculateAbsorption then
        absorb = xi.spells.damage.calculateAbsorption(target, element, false, true, false, false) < 0
    end

    local resistTier = 1.0
    if not absorb and xi.combat and xi.combat.magicHitRate and xi.combat.magicHitRate.calculateResistRate then
        resistTier = xi.combat.magicHitRate.calculateResistRate(actor, target,
        {
            magicBurstTier = 0,
            magicalElement = element,
            actorStat      = xi.mod.INT,
            skillType      = xi.skill.ENHANCING_MAGIC,
            spellGroup     = xi.magic.spellGroup.NONE,
            bonusMacc      = 0,
        }) or 1.0
    end

    local dayAndWeather = 1.0
    if xi.spells and xi.spells.damage and xi.spells.damage.calculateDayAndWeather then
        dayAndWeather = xi.spells.damage.calculateDayAndWeather(actor, element, false) or 1.0
    end

    local mdtAdjust = 1.0
    local sdtAdjust = 1.0
    if not absorb and xi.combat and xi.combat.damage then
        if xi.combat.damage.calculateDamageAdjustment then
            mdtAdjust = xi.combat.damage.calculateDamageAdjustment(target, false, true, false, false) or 1.0
        end
        if xi.combat.damage.magicalElementSDT then
            sdtAdjust = xi.combat.damage.magicalElementSDT(target, element) or 1.0
        end
    end

    damage = math.floor(damage * resistTier)
    damage = math.floor(damage * dayAndWeather)
    damage = math.floor(damage * mdtAdjust)
    damage = math.floor(damage * sdtAdjust)

    if absorb then
        local healed = target.addHP and target:addHP(damage) or damage
        if action ~= nil then
            if action.additionalEffect then
                action:additionalEffect(targetId, subEffect)
            end
            if action.addEffectParam then
                action:addEffectParam(targetId, healed)
            end
            if action.addEffectMessage and xi.msg and xi.msg.basic then
                action:addEffectMessage(targetId, xi.msg.basic.ADD_EFFECT_HEAL or 167)
            end
        end
        return
    end

    -- Apply Spellblade Gambit 1.10x positive damage multiplier if active for this element
    local gambitMult = getSpellbladeGambitMultiplier(target, element)
    if damage > 0 and gambitMult > 1.0 then
        damage = math.floor(damage * gambitMult)
    end

    if damage > 0 and xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        damage = xi.customBossServer.scaleDamageByLevelGap(actor, target, damage)
    end

    if damage > 0 then
        damage = utils.clamp(utils.handlePhalanx(target, damage), 0, 99999)
        damage = utils.clamp(utils.handleOneForAll(target, damage), 0, 99999)
        damage = utils.handleStoneskin(target, damage, xi.attackType.MAGICAL)
    end

    if damage > 0 and target.takeDamage then
        -- Rune Edge does not generate target/attacker TP or build the accumulative magic wall
        target:takeDamage(damage, actor, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
    end

    if action ~= nil then
        if action.additionalEffect then
            action:additionalEffect(targetId, subEffect)
        end
        if action.addEffectParam then
            action:addEffectParam(targetId, damage)
        end
        if action.addEffectMessage and xi.msg and xi.msg.basic then
            action:addEffectMessage(targetId, xi.msg.basic.ADD_EFFECT_DMG or 163)
        end
    end

    -- 3. Delay-adjusted fractional MP recovery on positive Rune Edge damage (Lv.10+)
    if damage > 0 and lvl >= 10 and actor.addMP and actor.getLocalVar and actor.setLocalVar then
        local baseMpGain = 1
        if lvl >= 65 then
            baseMpGain = 3
        elseif lvl >= 40 then
            baseMpGain = 2
        end

        -- Accumulate hundredths of MP so fractional recovery carries forward across rounds
        local gainHundredths = math.floor((baseMpGain * 100 * baseDelay) / 480 + 0.5)
        local accum          = (actor:getLocalVar('OX_RUN_MP_FRAC') or 0) + gainHundredths
        local wholeMp        = math.floor(accum / 100)
        local remainder      = accum - (wholeMp * 100)
        actor:setLocalVar('OX_RUN_MP_FRAC', remainder)
        if wholeMp > 0 then
            actor:addMP(wholeMp)
        end
    end
end

-----------------------------------
-- Lifebinder Runic Lifetap Helper
-----------------------------------
local function triggerLifebinderMend(actor, isWeaponskill)
    if actor == nil then
        return
    end

    local runes = getActiveRunesList(actor)
    if #runes <= 0 then
        return
    end

    local party = getPartyMembersInRange(actor, 12.0)
    local mostInjured = nil
    local lowestPct   = 101

    for _, member in ipairs(party) do
        local hp    = member.getHP and member:getHP() or 0
        local maxHp = member.getMaxHP and member:getMaxHP() or 1
        local pct   = (maxHp > 0) and math.floor(hp * 100 / maxHp) or 100
        if pct < 100 and pct < lowestPct then
            lowestPct   = pct
            mostInjured = member
        end
    end

    local mndStat = actor.getStat and actor:getStat(xi.mod.MND) or 15
    local curePot = 1.0 + ((actor.getMod and actor:getMod(xi.mod.CURE_POTENCY) or 0) / 100.0)
    local hpRatio = isWeaponskill and 0.05 or 0.025

    if mostInjured ~= nil and mostInjured.addHP then
        local targetMaxHp = mostInjured.getMaxHP and mostInjured:getMaxHP() or 100
        local healAmount  = math.max(6, math.floor((targetMaxHp * hpRatio + mndStat * 0.5 + #runes * 4) * curePot))
        local healed      = mostInjured:addHP(healAmount)
        if
            healed > 0 and
            actor.messagePublic and
            xi.msg and
            xi.msg.basic and
            xi.msg.basic.RECOVERS_HP
        then
            actor:messagePublic(xi.msg.basic.RECOVERS_HP, mostInjured, 0, healed)
        end
    end

    if actor.addMP and actor.getMaxMP then
        local mpPct  = isWeaponskill and 0.03 or 0.01
        local mpGain = math.max(2, math.floor(actor:getMaxMP() * mpPct))
        actor:addMP(mpGain)
    end
end

local function detachRunListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_RUN_MELEE')
        player:removeListener('OX_RUN_ATTACK_ROUND')
        player:removeListener('OX_RUN_WS')
        player:removeListener('OX_RUN_TICK')
        player:removeListener('OX_RUN_DEATH')
    end
end

local function attachRunListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachRunListeners(player)

    if player.setLocalVar then
        player:setLocalVar('OX_RUN_WPN_SIG', getMainSubWeaponSignature(player))
    end

    player:addListener('MELEE_SWING_HIT', 'OX_RUN_MELEE', function(actor, target)
        if actor == nil or target == nil or target == actor then
            return
        end

        if isRunSpec(actor, SPELLBLADE_KEY) then
            if actor.setLocalVar then
                actor:setLocalVar('OX_RUN_ROUND_LANDED', 1)
            end
        elseif isRunSpec(actor, LIFEBINDER_KEY) then
            triggerLifebinderMend(actor, false)
        end
    end)

    player:addListener('ATTACK', 'OX_RUN_ATTACK_ROUND', function(actor, target, action)
        if actor == nil or target == nil or target == actor then
            return
        end

        if isRunSpec(actor, SPELLBLADE_KEY) and actor.getLocalVar and actor:getLocalVar('OX_RUN_ROUND_LANDED') == 1 then
            actor:setLocalVar('OX_RUN_ROUND_LANDED', 0)
            evaluateRuneEdgeRound(actor, target, action)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_RUN_WS', function(actor, target, _ws, _tp, _action, dmg)
        if actor == nil or target == nil or target == actor or (dmg ~= nil and dmg <= 0) then
            return
        end

        if isRunSpec(actor, LIFEBINDER_KEY) then
            triggerLifebinderMend(actor, true)
        end
    end)

    -- Track weapon/grip changes and 30 continuous seconds disengaged to clear Conduction
    player:addListener('TICK', 'OX_RUN_TICK', function(actor)
        if actor == nil or not isRunSpec(actor, SPELLBLADE_KEY) or not actor.getLocalVar then
            return
        end

        local curSig  = getMainSubWeaponSignature(actor)
        local prevSig = actor:getLocalVar('OX_RUN_WPN_SIG')
        if prevSig ~= 0 and curSig ~= prevSig then
            actor:setLocalVar('OX_RUN_WPN_SIG', curSig)
            if getConductionStacks(actor) > 0 then
                clearConduction(actor, '[Spellblade] Conduction lost (weapon/grip changed).')
            end
        elseif prevSig == 0 then
            actor:setLocalVar('OX_RUN_WPN_SIG', curSig)
        end

        local stacks = getConductionStacks(actor)
        if stacks <= 0 then
            actor:setLocalVar('OX_RUN_DISENGAGE_TS', 0)
            return
        end

        local engaged = actor.isEngaged and actor:isEngaged() or false
        if engaged then
            actor:setLocalVar('OX_RUN_DISENGAGE_TS', 0)
            -- Keep Conduction status indicator refreshed while engaged
            if not hasRunCustomEffect(actor, EFFECT_CONDUCTION) then
                syncConductionStatusEffect(actor, stacks)
            end
        else
            local nowTs   = os.time()
            local startTs = actor:getLocalVar('OX_RUN_DISENGAGE_TS')
            if startTs == 0 then
                actor:setLocalVar('OX_RUN_DISENGAGE_TS', nowTs)
            elseif (nowTs - startTs) >= 30 then
                clearConduction(actor, nil)
            end
        end
    end)

    player:addListener('DEATH', 'OX_RUN_DEATH', function(actor)
        if actor ~= nil then
            clearConduction(actor, nil)
        end
    end)
end

-----------------------------------
-- Crystal Definitions (RUN)
-----------------------------------
local SPELL_RUNIC_BOLT         = 363
local SPELL_RUNIC_SEVER        = 364
local LEGACY_SPELL_RUNIC_BOLT  = 754
local LEGACY_SPELL_RUNIC_SEVER = 755

local RUN_NATIVE_SPELLS =
{
    43, 44, 45, 46,       -- Protect I-IV
    48, 49, 50, 51, 52,   -- Shell I-V
    53, 54, 55,           -- Blink, Stoneskin, Aquaveil
    60, 61, 62, 63, 64, 65, -- Barfire..Barwater
    72, 73, 74, 75, 76, 77, 78, 84, -- Barsleep..Baramnesia
    106, 108, 109, 110, 111, 112, -- Phalanx, Regen I, Refresh, Regen II, Regen III, Flash
    249, 250, 251,        -- Blaze/Ice/Shock Spikes
    477, 840,             -- Regen IV, Foil
}

local function ensureRunSpells(player, isSpellblade)
    if player == nil or not player.addSpell or not player.hasSpell then
        return
    end
    for _, spellId in ipairs(RUN_NATIVE_SPELLS) do
        if not player:hasSpell(spellId) then
            player:addSpell(spellId, { silentLog = true, saveToDB = true, sendUpdate = true })
        end
    end
    if player.delSpell then
        if player:hasSpell(LEGACY_SPELL_RUNIC_BOLT) then
            player:delSpell(LEGACY_SPELL_RUNIC_BOLT, { saveToDB = true, sendUpdate = true })
        end
        if player:hasSpell(LEGACY_SPELL_RUNIC_SEVER) then
            player:delSpell(LEGACY_SPELL_RUNIC_SEVER, { saveToDB = true, sendUpdate = true })
        end
    end
    if isSpellblade then
        if not player:hasSpell(SPELL_RUNIC_BOLT) then
            player:addSpell(SPELL_RUNIC_BOLT, { silentLog = true, saveToDB = true, sendUpdate = true })
        end
        if not player:hasSpell(SPELL_RUNIC_SEVER) then
            player:addSpell(SPELL_RUNIC_SEVER, { silentLog = true, saveToDB = true, sendUpdate = true })
        end
    elseif player.delSpell then
        if player:hasSpell(SPELL_RUNIC_BOLT) then
            player:delSpell(SPELL_RUNIC_BOLT, { saveToDB = true, sendUpdate = true })
        end
        if player:hasSpell(SPELL_RUNIC_SEVER) then
            player:delSpell(SPELL_RUNIC_SEVER, { saveToDB = true, sendUpdate = true })
        end
    end
end

if xi.job and xi.job.RUN then
    spec.registerJob(xi.job.RUN, 'RUN',
    {
        {
            id          = 1,
            key         = INQUISITOR_KEY,
            name        = 'Inquisitor',
            role        = 'Hybrid Stance-Swapping Ward Tank',
            icon        = 'inquisitor',
            reqLevel    = 10,
            extraAbilities =
            {
                (xi.jobAbility and xi.jobAbility.SWORDPLAY) or 367,
                (xi.jobAbility and xi.jobAbility.PFLUG) or 369,
                (xi.jobAbility and xi.jobAbility.LIEMENT) or 373,
                (xi.jobAbility and xi.jobAbility.BATTUTA) or 376,
                ABIL_IRON_BATTUTA,
                ABIL_RUNIC_AEGIS,
                ABIL_RUNIC_CONVERGENCE,
            },
            extraTraits = { TRAIT_INQUISITOR_WARD },
            description = 'Order of Conscience ward tank (Lv10+): harbors 3 Runes at Lv10+, never loses Runes on Swipe/Lunge/Gambit/Rayke, ripostes on Parry, and weaves short-CD Physical Parry & Elemental Aegis stances.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+): +8/14/20/24% Max HP, +6/12/20/25 VIT & AGI, -5/8/12/15% DT, +15/25/40/50 Enmity, -20/35/50/60% Enmity Loss.',
                'Parry & Runic Persistence: +12/24/40/50 Parry & Great Sword Skill, +6/10/15/18% Parry Rate (+10% w/ GS); 3 Runes at Lv10+; Swipe/Lunge/Gambit/Rayke preserve Runes & add Enmity.',
                'Runic Riposte: Parrying heals 1.5% Max HP, restores 1% Max MP, grants +50 TP & +Enmity, and deals an elemental counter-slash.',
                'Stance: Iron Battuta (Lv10, 15s CD): +15/22/30/40% Parry Rate, -8/12/16/20% PDT, +15/25/35/50% DEF; swap triggers Steel Flash (+Enmity & 4/6/8/10% HP Stoneskin).',
                'Stance: Runic Aegis (Lv10, 15s CD): -10/15/20/25% MDT/BDT, +20/35/50/70 MEVA, +15/25/35/50 MDEF, +10/15/20/25% Magic Absorb; swap triggers Odyllic Pulse (+Enmity, HP/MP & cleanse).',
                'Runic Convergence (Lv10, 30s CD, 10s): Fuses both stances (-12/16/20/25% DT, +20/30/40/50% Parry, +30/45/60/80 MEVA, +Enmity) and heals 3% HP per Rune.',
                'Tank Tradeoff & JAs: -20% Attack% & -15% WSD; enhances Vallation/Valiance (+10/15/20% DEF), Swordplay (starts at max stacks +15 Enmity), Pflug (-8% PDT), Battuta, and Liement.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 8, 14, 20, 24) },
                    { xi.mod.VIT,                   scaleTier(lvl, 6, 12, 20, 25) },
                    { xi.mod.AGI,                   scaleTier(lvl, 6, 12, 20, 25) },
                    { xi.mod.DMG,                   scaleTier(lvl, -500, -800, -1200, -1500) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 20, 35, 50, 60) },
                    { xi.mod.PARRY,                 scaleTier(lvl, 12, 24, 40, 50) },
                    { xi.mod.GSWORD,                scaleTier(lvl, 12, 24, 40, 50) },
                    { xi.mod.INQUARTATA,            scaleTier(lvl, 6, 10, 15, 18) },
                }
            end,
            onApply = function(player)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_RUN_SPELLBLADE', 0)
                end
                ensureRunSpells(player, false)
                clearConduction(player, nil)
                detachRunListeners(player)
            end,
            onRemove = function(player)
                if player ~= nil then
                    delRunCustomEffectSilent(player, EFFECT_IRON_BATTUTA)
                    delRunCustomEffectSilent(player, EFFECT_RUNIC_AEGIS)
                    delRunCustomEffectSilent(player, EFFECT_RUNIC_CONVERGENCE)
                end
            end,
        },
        {
            id          = 2,
            key         = SPELLBLADE_KEY,
            name        = 'Spellblade',
            role        = 'Greatsword & Conduction Spellweaver DPS',
            icon        = 'spellblade',
            reqLevel    = 10,
            extraAbilities = function(_player, lvl)
                local l   = lvl or 1
                local out = {}
                if l >= 10 then
                    table.insert(out, ABIL_EFFUSION_SLASH)
                    table.insert(out, ABIL_OVERCHARGE_RUNES)
                end
                if l >= 20 then
                    table.insert(out, (xi.jobAbility and xi.jobAbility.SWORDPLAY) or 367)
                end
                if l >= 40 then
                    table.insert(out, (xi.jobAbility and xi.jobAbility.VALLATION) or 366)
                    table.insert(out, (xi.jobAbility and xi.jobAbility.PFLUG) or 369)
                end
                if l >= 50 then
                    table.insert(out, (xi.jobAbility and xi.jobAbility.VALIANCE) or 371)
                end
                if l >= 70 then
                    table.insert(out, (xi.jobAbility and xi.jobAbility.GAMBIT) or 372)
                    table.insert(out, (xi.jobAbility and xi.jobAbility.RAYKE) or 375)
                    table.insert(out, (xi.jobAbility and xi.jobAbility.BATTUTA) or 376)
                    table.insert(out, (xi.jobAbility and xi.jobAbility.LIEMENT) or 373)
                end
                return out
            end,
            extraTraits = { TRAIT_RUNIC_BRAND },
            description = 'Elemental Greatsword spellweaver (Lv10+): Enchanted attacks (Rune Edge), Effusion Slash & Overcharge Runes -> Conduction (up to 3) & MP -> Prepared offensive magic (Runic Bolt / Runic Sever) -> Edgeflare (+25% Rune Edge).',
            highlights  =
            {
                'Skills & Passives: Greatsword A+, Elemental Magic A, Enhancing Magic B, +12/20/28/36 MAB, +8/14/20/28 MACC; one Rune Enchantment fills all unlocked slots (1/2/3 at Lv5/35/65).',
                'Rune Edge: First landed normal Greatsword hit per round deals floor((0.08*GS + 0.04*Enh + 4*Runes) * Delay/480) elemental damage (2x during Overcharge Runes) and builds Conduction (max 3) + MP.',
                'Effusion Slash (Lv10, 20s CD, Enemy 4y): Non-consuming Great Sword arcane strike (1.5x-2.8x +20%/Rune) aligned to newest Rune; can Magic Burst (+35% DMG) and grants +100/150/200/250 TP.',
                'Overcharge Runes (Lv10, 30s CD, Self): 12s overdrive granting +15/22/30/40 MAB, +10/14/18/24% Attack%, +15/20/25/30 MB Bonus, 2x Runic Brand damage, and refreshes active Rune durations.',
                'Magic Spell: Runic Bolt (Lv10, 2.0s cast, 8s CD, 8-24 MP, 10y): High-potency arcane bolt scaling with Elemental Skill, Weapon DMG, INT, STR, Runes (+5%/Rune), & Conduction (+10% DMG, -0.5s cast, -15% MP/stack).',
                'Magic Spell: Runic Sever (Lv55, 3.0s cast, 30s CD, 40 MP, 10y): Heavy arcane finisher scaling with Elemental Skill, Weapon DMG, INT, STR, Runes (+8%/Rune), & Conduction (+12% DMG, -0.5s cast, -15% MP/stack); Magic Bursts.',
                'Edgeflare & Kit: Positive damage from Bolt, Sever, or Effusion Slash grants +25% Rune Edge for 12s (Lv30+); Swordplay (+10 ACC/MACC), Vallation, Gambit (1.10x target element DMG), Runic Ascendance (2hr).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.GSWORD,  getGreatswordAPlusBonus(lvl) },
                    { xi.mod.ELEM,    getARankSkillForLevel(lvl) },
                    { xi.mod.ENHANCE, getEnhancingBRankDelta(lvl) },
                    { xi.mod.MATT,    scaleTier(lvl, 12, 20, 28, 36) },
                    { xi.mod.MACC,    scaleTier(lvl, 8, 14, 20, 28) },
                }
            end,
            onApply = function(player)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_RUN_SPELLBLADE', 1)
                    player:setLocalVar('OX_RUN_WPN_SIG', getMainSubWeaponSignature(player))
                end
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                ensureRunSpells(player, true)
                attachRunListeners(player)
            end,
            onRemove = function(player)
                if player ~= nil then
                    if player.setLocalVar then
                        player:setLocalVar('OX_RUN_SPELLBLADE', 0)
                        player:setLocalVar('OX_RUN_MP_FRAC', 0)
                    end
                    if player.recalculateSkillsTable then
                        player:recalculateSkillsTable()
                    end
                    ensureRunSpells(player, false)
                    clearConduction(player, nil)
                    delRunCustomEffectSilent(player, EFFECT_EDGEFLARE)
                    delRunCustomEffectSilent(player, EFFECT_OVERCHARGE_RUNES)
                    delRunCustomEffectSilent(player, EFFECT_RUNIC_ASCENDANCE)
                end
                detachRunListeners(player)
            end,
        },
        {
            id          = 3,
            key         = LIFEBINDER_KEY,
            name        = 'Lifebinder',
            role        = 'Vivacious Pulse & Runic Mending Healer',
            icon        = 'lifebinder',
            reqLevel    = 10,
            extraAbilities =
            {
                (xi.jobAbility and xi.jobAbility.VALIANCE) or 371,
                (xi.jobAbility and xi.jobAbility.ONE_FOR_ALL) or 374,
                (xi.jobAbility and xi.jobAbility.VIVACIOUS_PULSE) or 383,
                ABIL_FONT_OF_LIFE,
                ABIL_SANCTIFIED_WARD,
            },
            extraTraits = { TRAIT_SACRED_PULSE },
            description = 'Keeper of Sacred Yggdrasil Runes (Lv10+): turns Vivacious Pulse into a 15s CD party AoE heal + rune-driven Regen/Cleanse/Refresh/Stoneskin, and projects AoE Regen spells.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+): +10/18/28/35% Max MP, +2/4/7/10 Refresh, +8/16/25/32 MND & VIT, +12/20/30/35% Cure Potency, +15/25/40/50 Enhancing/Divine/Healing Skill, +10/18/25/30% Fast Cast, -15/25/35/40 Enmity.',
                'Sacred Pulse (Vivacious Pulse at Lv10, 15s CD, Party 12y AoE): Party heal + per-Rune boons (Lux: +25% heal & Regen; Unda: Party debuff cleanse; Tenebrae: Caster MP & Party Refresh; Elemental: 25% Stoneskin).',
                'Font of Life (Lv10, 20s CD, Ally 15y): Restores 22/30/38/48% Max HP, cleanses 2 status ailments, and grants -10/14/18/22% DT & +10/15/20/25% Cure Rcvd for 12s.',
                'Sanctified Ward (Lv10, 35s CD, 15s, Party 12y): Instant 10/14/18/22% Party HP heal + 15s Sanctuary (25 + 3.5% Max HP/tick Regen, -8/12/16/20% DT, +15/25/35/50 MEVA).',
                'Runic Lifetap: Melee hits & WSs while holding Runes mend the most injured party member (2.5-5% HP + 0.5*MND) and restore 1-3% Max MP.',
                'AoE Regen & Wards: Regen I-IV project as 10y Party AoE with +50% potency & +60s duration; One for All (60s CD) also heals the party for 18% of your Max HP; Valiance (60s CD) grants +15% Cure Rcvd & Fast Cast.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.MPP,              scaleTier(lvl, 10, 18, 28, 35) },
                    { xi.mod.REFRESH,          scaleTier(lvl, 2, 4, 7, 10) },
                    { xi.mod.MND,              scaleTier(lvl, 8, 16, 25, 32) },
                    { xi.mod.VIT,              scaleTier(lvl, 8, 16, 25, 32) },
                    { xi.mod.CURE_POTENCY,     scaleTier(lvl, 12, 20, 30, 35) },
                    { xi.mod.ENHANCE,          scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.DIVINE,           scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.HEALING,          scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.FASTCAST,         scaleTier(lvl, 10, 18, 25, 30) },
                    { xi.mod.REGEN_MULTIPLIER, 50 },
                    { xi.mod.REGEN_DURATION,   60 },
                    { xi.mod.ENMITY,           scaleTier(lvl, -15, -25, -35, -40) },
                }
            end,
            onApply = function(player)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_RUN_SPELLBLADE', 0)
                end
                ensureRunSpells(player, false)
                clearConduction(player, nil)
                attachRunListeners(player)
            end,
            onRemove = function(player)
                detachRunListeners(player)
            end,
        },
    })
end

-----------------------------------
-- Rune Enchantment Overrides:
-- - Spellblade: One activation fills every unlocked slot (1 @ Lv5, 2 @ Lv35, 3 @ Lv65)
--   with 8 resistance per rune at Lv75; changing element removes Edgeflare.
-- - Inquisitor & Lifebinder: 3-Rune Mastery at Lv10+.
-----------------------------------
m:addOverride('xi.job_utils.rune_fencer.useRuneEnchantment', function(player, target, ability, effect)
    if isRunSpec(player, SPELLBLADE_KEY) then
        local runLevel   = player.getMainLvl and player:getMainLvl() or 10
        local slotCap    = getSpellbladeRuneSlotCap(runLevel)
        local power      = getSpellbladeRuneResistancePower(runLevel)
        local prevNewest = target.getNewestRuneEffect and target:getNewestRuneEffect() or 0

        if prevNewest ~= 0 and prevNewest ~= effect then
            delRunCustomEffectSilent(target, EFFECT_EDGEFLARE)
        end

        if target.removeAllRunes then
            target:removeAllRunes()
        end

        for _ = 1, slotCap do
            target:addStatusEffect(effect, { power = power, duration = 300, origin = player })
        end
        return
    elseif isRunSpec(player, INQUISITOR_KEY) or isRunSpec(player, LIFEBINDER_KEY) then
        local activeRunes = target:getActiveRuneCount()
        if activeRunes >= 3 and target.removeOldestRune then
            target:removeOldestRune()
        end

        local runLevel      = player.getMainLvl and player:getMainLvl() or 10
        local meritBonus    = player.getMerit and player:getMerit(xi.merit.RUNE_ENHANCE) or 0
        local jobPointBonus = player.getJobPointLevel and player:getJobPointLevel(xi.jp.RUNE_ENCHANTMENT_EFFECT) or 0
        local power         = math.floor((49 * runLevel / 99) + 5.5) + meritBonus + jobPointBonus

        target:addStatusEffect(effect, { power = power, duration = 300, origin = player })
        return
    end

    super(player, target, ability, effect)
end)

-----------------------------------
-- Spellblade Gambit Alliance-Wide 1.10x Positive Elemental Damage Hook
-----------------------------------
m:addOverride('xi.spells.damage.calculateMagicBonusDiff', function(caster, target, spellId, skillType, spellElement, bonusMab)
    local diff = super(caster, target, spellId, skillType, spellElement, bonusMab)
    if target ~= nil and spellElement ~= nil then
        local absorb = false
        if xi.spells and xi.spells.damage and xi.spells.damage.calculateAbsorption then
            absorb = xi.spells.damage.calculateAbsorption(target, spellElement, false, true, false, false) < 0
        end
        if not absorb then
            local gambitMult = getSpellbladeGambitMultiplier(target, spellElement)
            if gambitMult > 1.0 then
                diff = diff * gambitMult
            end
        end
    end
    return diff
end)

m:addOverride('xi.combat.skillchain.calculateSkillchainDamage', function(actor, target, baseDamage)
    local dmg = super(actor, target, baseDamage)
    if (tonumber(dmg) or 0) > 0 and target ~= nil and target.getStatusEffect then
        local eff = target:getStatusEffect(xi.effect.GAMBIT)
        if eff ~= nil and eff.getPower and eff:getPower() == SPELLBLADE_GAMBIT_POWER then
            dmg = math.floor(dmg * 1.10)
        end
    end
    return dmg
end)

-----------------------------------
-- Inquisitor Parry Mastery & Runic Riposte
-----------------------------------
local function dealRunicRiposte(defender, attacker)
    if
        defender == nil or
        attacker == nil or
        attacker == defender or
        (attacker.isAlive and not attacker:isAlive())
    then
        return 0
    end

    local lvl       = defender.getMainLvl and defender:getMainLvl() or 10
    local weaponDmg = defender.getWeaponDmg and defender:getWeaponDmg() or 10
    local vitStat   = defender.getStat and defender:getStat(xi.mod.VIT) or lvl
    local runeCount = defender.getActiveRuneCount and defender:getActiveRuneCount() or 1
    local stanceMult = hasRunCustomEffect(defender, EFFECT_IRON_BATTUTA) and 1.35 or 1.0

    local rawDmg = math.max(5, math.floor((weaponDmg * 0.45 + vitStat * 0.25 + lvl * 0.30 + runeCount * 4) * stanceMult))
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        rawDmg = xi.customBossServer.scaleDamageByLevelGap(defender, attacker, rawDmg)
    end
    local newest = defender.getNewestRuneEffect and defender:getNewestRuneEffect() or xi.effect.IGNIS
    local elem   = RUNE_ELEMENT_MAP[newest] or xi.element.FIRE

    local dealt = utils.handleStoneskin(attacker, rawDmg, xi.attackType.MAGICAL)
    if dealt > 0 and attacker.takeDamage then
        local res = attacker:takeDamage(dealt, defender, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + elem)
        if type(res) == 'number' then
            dealt = res
        end
    end

    if dealt > 0 and defender.messagePublic then
        local hitMsg = (xi.msg and xi.msg.basic and xi.msg.basic.HIT_DMG) or 1
        defender:messagePublic(hitMsg, attacker, dealt, dealt)
    end

    return dealt
end

m:addOverride('xi.combat.physical.calculateParryRate', function(defender, attacker)
    local rate = super(defender, attacker)

    if isRunSpec(defender, INQUISITOR_KEY) then
        local bonus = isGreatSwordEquipped(defender) and 10 or 5
        rate = utils.clamp((tonumber(rate) or 0) + bonus, 5, 80)
    end

    return rate
end)

m:addOverride('xi.combat.physical.isParried', function(defender, attacker)
    local parried = super(defender, attacker)

    if parried and isRunSpec(defender, INQUISITOR_KEY) then
        local maxHp = defender.getMaxHP and defender:getMaxHP() or 0
        if maxHp > 0 and defender.addHP then
            defender:addHP(math.max(6, math.floor(maxHp * 0.015)))
        end

        local maxMp = defender.getMaxMP and defender:getMaxMP() or 0
        if maxMp > 0 and defender.addMP then
            defender:addMP(math.max(2, math.floor(maxMp * 0.01)))
        end

        if defender.addTP then
            defender:addTP(50)
        end

        grantEnmity(attacker, defender, 150, 350)
        dealRunicRiposte(defender, attacker)
    end

    return parried
end)

-----------------------------------
-- Base RUN Ability Recast & Effect Overrides
-----------------------------------
-- Swipe (344) & Lunge (368): Non-consuming on Spellblade & Inquisitor (+Enmity on Inquisitor, +Edgeflare/Conduction synergy on Spellblade)
m:addOverride('xi.job_utils.rune_fencer.useSwipeLunge', function(player, target, ability, action)
    if isRunSpec(player, SPELLBLADE_KEY) then
        local savedRunes = snapshotRunes(player)
        local dmg        = super(player, target, ability, action)
        restoreRunes(player, savedRunes)
        if dmg and dmg > 0 then
            local newestRune = (player.getNewestRuneEffect and player:getNewestRuneEffect()) or savedRunes[#savedRunes] or xi.effect.IGNIS
            local element    = RUNE_ELEMENT_MAP[newestRune] or xi.element.FIRE
            grantOrRefreshEdgeflare(player, element)
        end
        return dmg
    elseif isRunSpec(player, INQUISITOR_KEY) then
        local savedRunes = snapshotRunes(player)
        local dmg        = super(player, target, ability, action)
        restoreRunes(player, savedRunes)
        local runeCount = math.max(1, #savedRunes)
        grantEnmity(target, player, 180 * runeCount, 480 * runeCount)
        return dmg
    end

    return super(player, target, ability, action)
end)

-- Gambit (372):
-- - Spellblade (Lv.70+, 180s CD): Spend up to 3 Conduction to make target take 1.10x positive damage from selected element for 20s (still usable at 0 stacks).
-- - Inquisitor (60s CD): Non-consuming + bonus Enmity.
m:addOverride('xi.actions.abilities.gambit.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, SPELLBLADE_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(180)
            end
            return xi.job_utils.rune_fencer.checkHaveRunes(player)
        elseif isRunSpec(player, INQUISITOR_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(60)
            end
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useGambit', function(player, target, ability, action)
    if isRunSpec(player, SPELLBLADE_KEY) then
        local highestRune = player.getHighestRuneEffect and player:getHighestRuneEffect() or xi.effect.IGNIS
        local element     = RUNE_ELEMENT_MAP[highestRune] or xi.element.FIRE
        local infoVal     = RUNE_EFFUSION_INFO_MAP[highestRune] or 2
        local stacks      = math.max(1, getConductionStacks(player))

        setConductionStacks(player, 0, true)

        if action ~= nil then
            if action.info then
                action:info(target:getID(), infoVal)
            end
            if action.setAnimation then
                action:setAnimation(target:getID(), 20)
            end
        end

        if target ~= nil and target.addStatusEffect then
            -- Only one Gambit can exist on a target; another application refreshes or replaces it.
            target:delStatusEffectSilent(xi.effect.GAMBIT)
            target:addStatusEffect(xi.effect.GAMBIT,
            {
                power    = SPELLBLADE_GAMBIT_POWER,
                duration = 10 + (stacks * 4),
                origin   = player,
                subPower = element,
            })
        end

        return xi.effect.GAMBIT
    elseif isRunSpec(player, INQUISITOR_KEY) then
        local savedRunes = snapshotRunes(player)
        local res        = super(player, target, ability, action)
        restoreRunes(player, savedRunes)
        local runeCount = math.max(1, #savedRunes)
        grantEnmity(target, player, 220 * runeCount, 550 * runeCount)
        return res
    end

    return super(player, target, ability, action)
end)

-- Rayke (375): 60s non-consuming Enmity on Inquisitor; non-consuming on Spellblade
m:addOverride('xi.actions.abilities.rayke.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, INQUISITOR_KEY) and ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useRayke', function(player, target, ability, action)
    if isRunSpec(player, INQUISITOR_KEY) or isRunSpec(player, SPELLBLADE_KEY) then
        local savedRunes = snapshotRunes(player)
        local res        = super(player, target, ability, action)
        restoreRunes(player, savedRunes)
        if isRunSpec(player, INQUISITOR_KEY) then
            local runeCount = math.max(1, #savedRunes)
            grantEnmity(target, player, 220 * runeCount, 550 * runeCount)
        end
        return res
    end

    return super(player, target, ability, action)
end)

-- Vallation (366) & Valiance (371):
-- - Spellblade Vallation (Lv.40+, 120s CD, Self): Spend 1-3 Conduction (or baseline 1 stack at 0 Conduction) for 10% opposing-element DR per stack (max 30%) for 15s.
m:addOverride('xi.actions.abilities.vallation.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isRunSpec(player, SPELLBLADE_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(120)
        end
        return xi.job_utils.rune_fencer.checkHaveRunes(player)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.valiance.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if (isRunSpec(player, LIFEBINDER_KEY) or isRunSpec(player, INQUISITOR_KEY)) and ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useVallationValiance', function(player, target, ability, action)
    if isRunSpec(player, SPELLBLADE_KEY) and ability ~= nil and ability:getID() == ((xi.jobAbility and xi.jobAbility.VALLATION) or 366) then
        -- Self-only on Spellblade Vallation
        if target ~= nil and player ~= nil and target:getID() ~= player:getID() then
            return xi.effect.VALLATION
        end

        local stacks = math.max(1, getConductionStacks(player))
        setConductionStacks(player, 0, true)

        local highestRune = player.getHighestRuneEffect and player:getHighestRuneEffect() or xi.effect.IGNIS
        local sdtMod      = RUNE_OPPOSING_SDT_MAP[highestRune] or xi.mod.ICE_SDT
        local sdtReduction = -1000 * stacks -- 10% per Conduction stack (max 30%)

        player:delStatusEffectSilent(xi.effect.VALLATION)
        player:delStatusEffectSilent(xi.effect.VALIANCE)
        player:addStatusEffect(xi.effect.VALLATION,
        {
            power    = stacks * 10,
            duration = 15,
            origin   = player,
        })
        local eff = player:getStatusEffect(xi.effect.VALLATION)
        if eff ~= nil and eff.addMod then
            eff:addMod(sdtMod, sdtReduction)
        end
        return xi.effect.VALLATION
    end

    local res = super(player, target, ability, action)

    if player == nil or target == nil then
        return res
    end

    local lvl = player.getMainLvl and player:getMainLvl() or 10
    if isRunSpec(player, INQUISITOR_KEY) then
        local defBonus = scaleTier(lvl, 10, 15, 20, 25)
        local eff = target:getStatusEffect(xi.effect.VALLATION) or target:getStatusEffect(xi.effect.VALIANCE)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.DEFP, defBonus)
            if target:getID() == player:getID() then
                eff:addMod(xi.mod.ENMITY, 15)
            end
        end
    elseif isRunSpec(player, LIFEBINDER_KEY) then
        local party = getPartyMembersInRange(player, 14.0)
        for _, member in ipairs(party) do
            local eff = member:getStatusEffect(xi.effect.VALIANCE) or member:getStatusEffect(xi.effect.VALLATION)
            if eff ~= nil and eff.addMod then
                eff:addMod(xi.mod.CURE_POTENCY_RCVD, 15)
                eff:addMod(xi.mod.FASTCAST, 15)
            end
        end
    end

    return res
end)

-- Swordplay (367):
-- - Spellblade (Lv.20+, 180s CD): +10 Accuracy and +10 Magic Accuracy for 60s.
-- - Inquisitor (120s CD): Starts at max stacks + 15 Enmity.
m:addOverride('xi.actions.abilities.swordplay.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, SPELLBLADE_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(180)
            end
        elseif isRunSpec(player, INQUISITOR_KEY) and ability ~= nil and ability.setRecast then
            ability:setRecast(120)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useSwordplay', function(player, target, ability)
    if isRunSpec(player, SPELLBLADE_KEY) then
        player:delStatusEffectSilent(xi.effect.SWORDPLAY)
        player:addStatusEffect(xi.effect.SWORDPLAY, { power = 0, duration = 60, origin = player, tick = 0, subPower = 0 })
        local eff = player:getStatusEffect(xi.effect.SWORDPLAY)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.ACC, 10)
            eff:addMod(xi.mod.MACC, 10)
        end
        return xi.effect.SWORDPLAY
    elseif isRunSpec(player, INQUISITOR_KEY) then
        local jpBonus  = player.getJobPointLevel and player:getJobPointLevel(xi.jp.SWORDPLAY_EFFECT) or 0
        local maxPower = 60 + jpBonus
        local subPower = player.getMerit and player:getMerit(xi.merit.SLEIGHT_OF_SWORD) or 0

        player:addStatusEffect(xi.effect.SWORDPLAY, { power = maxPower, duration = 120, origin = player, tick = 3, subPower = subPower })
        local eff = player:getStatusEffect(xi.effect.SWORDPLAY)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.ENMITY, 15)
        end
        return xi.effect.SWORDPLAY
    end

    return super(player, target, ability)
end)

-- Pflug (369), Battuta (376), Liement (373), Embolden (370), One for All (374), Odyllic Subterfuge (378):
m:addOverride('xi.actions.abilities.pflug.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, INQUISITOR_KEY) and ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.usePflug', function(player, target, ability, action)
    local res = super(player, target, ability, action)

    if isRunSpec(player, INQUISITOR_KEY) and player ~= nil then
        local eff = player:getStatusEffect(xi.effect.PFLUG)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.DMGPHYS, -800)
            eff:addMod(xi.mod.STATUSRES, 15)
        end
    end

    return res
end)

m:addOverride('xi.actions.abilities.battuta.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, INQUISITOR_KEY) and ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useBattuta', function(player, target, ability, action)
    local res = super(player, target, ability, action)

    if isRunSpec(player, INQUISITOR_KEY) and target ~= nil then
        local eff = target:getStatusEffect(xi.effect.BATTUTA)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.DMGPHYS, -1000)
            eff:addMod(xi.mod.ENMITY, 20)
        end
    end

    return res
end)

m:addOverride('xi.actions.abilities.liement.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, INQUISITOR_KEY) and ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useLiement', function(player, target, ability, action)
    local res = super(player, target, ability, action)

    if isRunSpec(player, INQUISITOR_KEY) and target ~= nil then
        local eff = target:getStatusEffect(xi.effect.LIEMENT)
        if eff ~= nil and eff.setDuration then
            eff:setDuration(15000)
        end
        pulseNearbyEnmity(player, 200, 500, 12.0)
    end

    return res
end)

m:addOverride('xi.actions.abilities.one_for_all.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if (isRunSpec(player, LIFEBINDER_KEY) or isRunSpec(player, INQUISITOR_KEY)) and ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useOneForAll', function(player, target, ability, action)
    super(player, target, ability, action)

    if player == nil or target == nil or player:getID() ~= target:getID() then
        return
    end

    if isRunSpec(player, INQUISITOR_KEY) then
        refreshActiveRuneDurations(player)
        pulseNearbyEnmity(player, 250, 650, 12.0)
    elseif isRunSpec(player, LIFEBINDER_KEY) then
        local casterMaxHp = player.getMaxHP and player:getMaxHP() or 100
        local healAmount  = math.max(15, math.floor(casterMaxHp * 0.18))
        local party       = getPartyMembersInRange(player, 12.0)
        for _, member in ipairs(party) do
            if member.addHP then
                local healed = member:addHP(healAmount)
                if
                    (healed > 0 or member:getID() ~= player:getID()) and
                    player.messagePublic and
                    xi.msg and
                    xi.msg.basic and
                    xi.msg.basic.RECOVERS_HP
                then
                    player:messagePublic(xi.msg.basic.RECOVERS_HP, member, 0, healed)
                end
            end
        end
    end
end)

-- Elemental Sforzo (356):
-- - Spellblade: Transforms into Runic Ascendance (30s: +50% Rune Edge potency and 2 Conduction per qualifying round; no elemental immunity).
-- - Inquisitor: Refreshes runes, pulses Enmity, and adds +40 Enmity & -20% PDT.
m:addOverride('xi.actions.abilities.elemental_sforzo.onUseAbility', function(player, target, ability)
    if isRunSpec(player, SPELLBLADE_KEY) and player ~= nil then
        local iconId = (xi.effect and xi.effect.ELEMENTAL_SFORZO) or EFFECT_RUNIC_ASCENDANCE
        applyTimedEffectWithMods(
            player,
            EFFECT_RUNIC_ASCENDANCE,
            50,
            30,
            player,
            2,
            iconId,
            nil
        )
        return EFFECT_RUNIC_ASCENDANCE
    end

    local res = super(player, target, ability)

    if isRunSpec(player, INQUISITOR_KEY) and player ~= nil then
        refreshActiveRuneDurations(player)
        pulseNearbyEnmity(player, 400, 1000, 12.0)
        local eff = player:getStatusEffect(xi.effect.ELEMENTAL_SFORZO)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.ENMITY, 40)
            eff:addMod(xi.mod.DMGPHYS, -2000)
        end
    end

    return res
end)

-----------------------------------
-- Lifebinder Sacred Pulse (Vivacious Pulse Override & AoE Regen/Cure)
-----------------------------------
m:addOverride('xi.actions.abilities.vivacious_pulse.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        if isRunSpec(player, LIFEBINDER_KEY) and ability ~= nil and ability.setRecast then
            ability:setRecast(15)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useVivaciousPulse', function(player, target, ability, effect)
    if not isRunSpec(player, LIFEBINDER_KEY) then
        return super(player, target, ability, effect)
    end

    local lvl          = player.getMainLvl and player:getMainLvl() or 10
    local mndStat      = player.getStat and player:getStat(xi.mod.MND) or 15
    local divSkill     = player.getSkillLevel and player:getSkillLevel(xi.skill.DIVINE_MAGIC) or (lvl * 3)
    local enhSkill     = player.getSkillLevel and player:getSkillLevel(xi.skill.ENHANCING_MAGIC) or (lvl * 3)
    local curePot      = 1.0 + ((player.getMod and player:getMod(xi.mod.CURE_POTENCY) or 0) / 100.0)
    local runes        = getActiveRunesList(player)

    local luxCount      = 0
    local undaCount     = 0
    local tenebraeCount = 0
    local elemCount     = 0

    for _, r in ipairs(runes) do
        if r == xi.effect.LUX then
            luxCount = luxCount + 1
        elseif r == xi.effect.UNDA then
            undaCount = undaCount + 1
        elseif r == xi.effect.TENEBRAE then
            tenebraeCount = tenebraeCount + 1
        else
            elemCount = elemCount + 1
        end
    end

    local luxMult  = 1.0 + (luxCount * 0.25)
    local baseHeal = math.max(25, math.floor((20 + divSkill * 0.45 + enhSkill * 0.35 + mndStat * 1.4 + lvl * 1.8) * curePot * luxMult))

    if tenebraeCount > 0 and player.addMP and player.getMaxMP then
        local mpPct  = scaleTier(lvl, 6, 9, 12, 15) * tenebraeCount
        local mpHeal = math.max(8, math.floor(player:getMaxMP() * mpPct / 100))
        player:addMP(mpHeal)
    end

    local luxPct      = scaleTier(lvl, 1.0, 1.4, 1.8, 2.2)
    local luxMin      = scaleTier(lvl, 12, 22, 34, 48)
    local refreshTick = scaleTier(lvl, 2, 3, 5, 7)
    local party       = getPartyMembersInRange(player, 12.0)
    local casterHealed = baseHeal

    for _, member in ipairs(party) do
        local rcvdMult = 1.0 + ((member.getMod and member:getMod(xi.mod.CURE_POTENCY_RCVD) or 0) / 100.0)
        local memberHeal = math.floor(baseHeal * rcvdMult)
        local curHp = member.getHP and member:getHP() or 0
        local maxHp = member.getMaxHP and member:getMaxHP() or curHp
        local actualHeal = math.min(memberHeal, math.max(0, maxHp - curHp))

        if member.restoreHP then
            actualHeal = member:restoreHP(actualHeal)
        elseif member.addHP then
            actualHeal = member:addHP(actualHeal)
        end

        if member:getID() == player:getID() then
            casterHealed = actualHeal
        elseif
            player.messagePublic and
            xi.msg and
            xi.msg.basic and
            xi.msg.basic.RECOVERS_HP
        then
            player:messagePublic(xi.msg.basic.RECOVERS_HP, member, 0, actualHeal)
        end

        if undaCount > 0 then
            cleanseTargetDebuffs(member, undaCount)
        end

        if luxCount > 0 and member.addStatusEffect then
            if xi.overlords and xi.overlords.regen and xi.overlords.regen.applyHybridRegen then
                xi.overlords.regen.applyHybridRegen(player, member, xi.effect.REGEN, 12 * luxCount, 150 * luxCount, 30, 3, 1)
            else
                local memberRegen = math.max(luxMin, math.floor(maxHp * luxPct / 100)) * luxCount
                member:addStatusEffect(xi.effect.REGEN, { power = memberRegen, duration = 30, origin = player, tick = 3, tier = 1 })
            end
        end

        if tenebraeCount > 0 and member.addStatusEffect then
            member:addStatusEffect(xi.effect.REFRESH, { power = refreshTick * tenebraeCount, duration = 30, origin = player, tick = 3, tier = 1 })
        end

        if elemCount > 0 and member.addStatusEffect then
            local skinPower = math.max(15, math.floor(memberHeal * 0.25 * elemCount))
            if not member:hasStatusEffect(xi.effect.STONESKIN) then
                member:addStatusEffect(xi.effect.STONESKIN, { power = skinPower, duration = 60, origin = player })
            end
        end
    end

    return casterHealed
end)

m:addOverride('xi.combat.magicAoE.calculateTypeAndRadius', function(caster, spell)
    if
        isRunSpec(caster, LIFEBINDER_KEY) and
        spell ~= nil and
        spell.getAoE and
        spell:getAoE() == xi.magic.aoe.RADIAL_ACCE
    then
        local family = spell.getSpellFamily and spell:getSpellFamily() or nil
        if
            family == xi.magic.spellFamily.REGEN or
            family == xi.magic.spellFamily.CURE
        then
            return { xi.magic.aoe.RADIAL, 10 }
        end
    end

    return super(caster, spell)
end)

-----------------------------------
-- Custom Job Abilities (412-418)
-----------------------------------

-- 1) Inquisitor: Stance: Iron Battuta (412, 15s CD, Self)
bindAbility('iron_battuta', function(player, _target, _ability)
    if not isRunSpec(player, INQUISITOR_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, _target, _ability)
    local lvl = player.getMainLvl and player:getMainLvl() or 10
    local parryBonus, tier = scaleTier(lvl, 15, 22, 30, 40)
    local pdtBps    = scaleTier(lvl, -800, -1200, -1600, -2000)
    local defpBonus = scaleTier(lvl, 15, 25, 35, 50)
    local skinPct   = scaleTier(lvl, 4, 6, 8, 10)
    local iconId    = (xi.effect and xi.effect.BATTUTA) or EFFECT_IRON_BATTUTA

    refreshActiveRuneDurations(player)
    delRunCustomEffectSilent(player, EFFECT_RUNIC_AEGIS)

    local _, appliedId = applyTimedEffectWithMods(
        player,
        EFFECT_IRON_BATTUTA,
        parryBonus,
        300,
        player,
        tier,
        iconId,
        {
            { xi.mod.INQUARTATA, parryBonus },
            { xi.mod.DMGPHYS,    pdtBps },
            { xi.mod.DEFP,       defpBonus },
            { xi.mod.ENMITY,     15 },
        }
    )

    local maxHp = player.getMaxHP and player:getMaxHP() or 100
    local skinVal = math.max(15, math.floor(maxHp * skinPct / 100))
    if player.addStatusEffect and not player:hasStatusEffect(xi.effect.STONESKIN) then
        player:addStatusEffect(xi.effect.STONESKIN, { power = skinVal, duration = 60, origin = player })
    end

    pulseNearbyEnmity(player, 160, 420, 12.0)

    return appliedId or EFFECT_IRON_BATTUTA
end)

-- 2) Inquisitor: Stance: Runic Aegis (413, 15s CD, Self)
bindAbility('runic_aegis', function(player, _target, _ability)
    if not isRunSpec(player, INQUISITOR_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, _target, _ability)
    local lvl = player.getMainLvl and player:getMainLvl() or 10
    local mdtBps, tier = scaleTier(lvl, -1000, -1500, -2000, -2500)
    local mevaBonus = scaleTier(lvl, 20, 35, 50, 70)
    local mdefBonus = scaleTier(lvl, 15, 25, 35, 50)
    local absorbPct = scaleTier(lvl, 10, 15, 20, 25)
    local pulsePct  = scaleTier(lvl, 4, 6, 8, 10)
    local iconId    = (xi.effect and xi.effect.VALLATION) or EFFECT_RUNIC_AEGIS

    refreshActiveRuneDurations(player)
    delRunCustomEffectSilent(player, EFFECT_IRON_BATTUTA)

    local mods =
    {
        { xi.mod.DMGMAGIC,          mdtBps },
        { xi.mod.DMGBREATH,         mdtBps },
        { xi.mod.MEVA,              mevaBonus },
        { xi.mod.MDEF,              mdefBonus },
        { xi.mod.CURE_POTENCY_RCVD, absorbPct },
        { xi.mod.ENMITY,            15 },
    }
    if xi.mod.MAGIC_ABSORB then
        table.insert(mods, { xi.mod.MAGIC_ABSORB, absorbPct })
    end

    local _, appliedId = applyTimedEffectWithMods(
        player,
        EFFECT_RUNIC_AEGIS,
        mevaBonus,
        300,
        player,
        tier,
        iconId,
        mods
    )

    if player.addHP and player.getMaxHP then
        player:addHP(math.max(10, math.floor(player:getMaxHP() * pulsePct / 100)))
    end
    if player.addMP and player.getMaxMP then
        player:addMP(math.max(5, math.floor(player:getMaxMP() * pulsePct / 100)))
    end

    cleanseTargetDebuffs(player, tier >= 3 and 2 or 1)
    pulseNearbyEnmity(player, 160, 420, 12.0)

    return appliedId or EFFECT_RUNIC_AEGIS
end)

-- 3) Inquisitor: Runic Convergence (414, 30s CD, 10s Self)
bindAbility('runic_convergence', function(player, _target, _ability)
    if not isRunSpec(player, INQUISITOR_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return xi.job_utils.rune_fencer.checkHaveRunes(player)
end, function(player, _target, _ability)
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local runes     = getActiveRunesList(player)
    local runeCount = math.max(1, #runes)
    local dtBps, tier = scaleTier(lvl, -1200, -1600, -2000, -2500)
    local parryBonus = scaleTier(lvl, 20, 30, 40, 50)
    local mevaBonus  = scaleTier(lvl, 30, 45, 60, 80)
    local enmityVal  = scaleTier(lvl, 30, 40, 50, 60)
    local iconId     = (xi.effect and xi.effect.ELEMENTAL_SFORZO) or EFFECT_RUNIC_CONVERGENCE

    refreshActiveRuneDurations(player)

    local _, appliedId = applyTimedEffectWithMods(
        player,
        EFFECT_RUNIC_CONVERGENCE,
        parryBonus,
        10,
        player,
        tier,
        iconId,
        {
            { xi.mod.DMG,        dtBps },
            { xi.mod.INQUARTATA, parryBonus },
            { xi.mod.MEVA,       mevaBonus },
            { xi.mod.ENMITY,     enmityVal },
        }
    )

    if player.addHP and player.getMaxHP then
        player:addHP(math.max(12, math.floor(player:getMaxHP() * 0.03 * runeCount)))
    end

    pulseNearbyEnmity(player, 240, 680, 12.0)

    return appliedId or EFFECT_RUNIC_CONVERGENCE
end)

-----------------------------------
-- 4 & 5) Spellblade Offensive Spells: Runic Bolt (415) & Runic Sever (416)
-----------------------------------
local function getRunicSpellBaseMp(isSever, lvl)
    local l = utils.clamp(lvl or 75, 10, 75)
    if isSever then
        -- 40 MP at Lv.75 (scales from 32 at Lv.55 to 40 at Lv.75)
        if l <= 55 then
            return 32
        end
        return 32 + math.floor(((l - 55) * 8) / 20 + 0.5)
    else
        -- Scales linearly from 8 MP at Lv.10-15 to 24 MP at Lv.75
        if l <= 15 then
            return 8
        end
        return 8 + math.floor(((l - 15) * 16) / 60 + 0.5)
    end
end

local function calculateConductionAdjustedCostAndCast(player, isSever, stacks)
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local baseMp    = getRunicSpellBaseMp(isSever, lvl)
    local baseCastMs = isSever and 3000 or 2000

    -- Each Conduction spent reduces base casting time by 0.5s (500ms) and base MP cost by 15%
    -- At 3 stacks (Lv.75): Bolt = 0.5s / 13 MP; Sever = 1.5s / 22 MP
    local mpFactor  = 1.0 - (0.15 * stacks)
    local prepMp    = isSever and math.floor(baseMp * mpFactor) or math.floor(baseMp * mpFactor + 0.5)
    local prepCastMs = math.max(250, baseCastMs - (stacks * 500))

    -- Apply outside casting modifiers (Fast Cast & Hasso +50% penalty)
    local fcPct     = utils.clamp((player.getMod and player:getMod(xi.mod.FASTCAST) or 0), 0, 80)
    local hassoMult = (player.hasStatusEffect and player:hasStatusEffect(xi.effect.HASSO)) and 1.5 or 1.0
    local finalCastMs = math.max(250, math.floor(prepCastMs * (1.0 - (fcPct / 200.0)) * hassoMult))

    return math.max(1, prepMp), finalCastMs
end

local function executeRunicSpell(player, target, _ability, action, isSever, spellObj)
    -- Verify weapon/grip was not swapped during casting
    local prepWpn = player.getLocalVar and player:getLocalVar('OX_RUN_PREP_WPN') or 0
    local curWpn  = getMainSubWeaponSignature(player)
    if (prepWpn ~= 0 and prepWpn ~= curWpn) or not isGreatSwordEquipped(player) then
        clearConduction(player, '[Spellblade] Changing weapons during casting invalidates the prepared cast!')
        if spellObj ~= nil and spellObj.setMsg and xi.msg and xi.msg.basic then
            spellObj:setMsg(xi.msg.basic.MAGIC_FAIL or 114)
        end
        return 0
    end

    local stacks = getConductionStacks(player)
    if player.getLocalVar then
        local reserved = player:getLocalVar('OX_RUN_PREP_STACKS')
        if reserved > 0 and reserved <= stacks then
            stacks = reserved
        end
        player:setLocalVar('OX_RUN_PREP_STACKS', 0)
    end

    local mpCost, _ = calculateConductionAdjustedCostAndCast(player, isSever, stacks)
    if spellObj == nil then
        local curMp = player.getMP and player:getMP() or 0
        if curMp < mpCost then
            return 0
        end

        if player.delMP then
            player:delMP(mpCost)
        end
    end
    setConductionStacks(player, math.max(0, getConductionStacks(player) - stacks), true)

    local runes      = getActiveRunesList(player)
    local runeCount  = math.max(1, #runes)
    local newestRune = (player.getNewestRuneEffect and player:getNewestRuneEffect()) or runes[#runes] or xi.effect.IGNIS
    local element    = RUNE_ELEMENT_MAP[newestRune] or xi.element.FIRE
    local infoVal    = RUNE_EFFUSION_INFO_MAP[newestRune] or 2

    if spellObj == nil and action ~= nil then
        if action.info then
            action:info(target:getID(), infoVal)
        end
        if action.setAnimation then
            action:setAnimation(target:getID(), isSever and 30 or 10)
        end
    end

    -- Early return if element is nullified
    if
        xi.spells and
        xi.spells.damage and
        xi.spells.damage.calculateNullification and
        xi.spells.damage.calculateNullification(target, element, false, true, false, false) == 0
    then
        if spellObj ~= nil and spellObj.setMsg and xi.msg and xi.msg.basic then
            spellObj:setMsg(xi.msg.basic.MAGIC_RESIST or 85)
        end
        return 0
    end

    -- Spellblade hybrid arcane-blade formulas scaling with Elemental Skill, Weapon DMG, INT, STR, Runes, & Conduction:
    --   Runic Bolt  = floor((1.85 * Elem + 2.00 * WeaponDMG + 0.85 * INT + 0.65 * STR + mDMG) * (1 + 0.10 * Conduction) * (1 + 0.05 * Runes))
    --   Runic Sever = floor((2.85 * Elem + 3.25 * WeaponDMG + 1.35 * INT + 1.00 * STR + mDMG) * (1 + 0.12 * Conduction) * (1 + 0.08 * Runes))
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local elemSkill = math.max(getARankSkillForLevel(lvl), player.getSkillLevel and player:getSkillLevel(xi.skill.ELEMENTAL_MAGIC) or 0)
    local weaponDmg = math.max(10, player.getWeaponDmg and player:getWeaponDmg() or 18)
    local intStat   = player.getStat and player:getStat(xi.mod.INT) or 10
    local strStat   = player.getStat and player:getStat(xi.mod.STR) or 10
    local mDmgBonus = player.getMod and player:getMod(xi.mod.MAGIC_DAMAGE) or 0
    local baseDmg
    if isSever then
        baseDmg = math.floor(2.85 * elemSkill + 3.25 * weaponDmg + 1.35 * intStat + 1.00 * strStat) + mDmgBonus
        baseDmg = math.floor(baseDmg * (1.0 + 0.12 * stacks) * (1.0 + 0.08 * runeCount))
    else
        baseDmg = math.floor(1.85 * elemSkill + 2.00 * weaponDmg + 0.85 * intStat + 0.65 * strStat) + mDmgBonus
        baseDmg = math.floor(baseDmg * (1.0 + 0.10 * stacks) * (1.0 + 0.05 * runeCount))
    end

    -- dINT adjustment (+2.0 per positive dINT up to +60, -0.5 per negative dINT)
    local targetInt = target.getStat and target:getStat(xi.mod.INT) or intStat
    local dInt      = intStat - targetInt
    if dInt > 0 then
        baseDmg = baseDmg + math.min(60, dInt * 2)
    elseif dInt < 0 then
        baseDmg = math.max(1, baseDmg + math.floor(dInt * 0.5))
    end

    local absorb = false
    if xi.spells and xi.spells.damage and xi.spells.damage.calculateAbsorption then
        absorb = xi.spells.damage.calculateAbsorption(target, element, false, true, false, false) < 0
    end

    local magicBurstTier = 0
    if not absorb and xi.combat and xi.combat.magicBurst and xi.combat.magicBurst.getMagicBurstTier then
        magicBurstTier = xi.combat.magicBurst.getMagicBurstTier(target, element) or 0
    end
    local canMBurst = not absorb and magicBurstTier > 0

    local staffBonus    = 1.0
    local affinityBonus = 1.0
    local magicCritMult = 1.0
    if xi.spells and xi.spells.damage then
        if xi.spells.damage.calculateElementalStaffBonus then
            staffBonus = xi.spells.damage.calculateElementalStaffBonus(player, element) or 1.0
        end
        if xi.spells.damage.calculateElementalAffinityBonus then
            affinityBonus = xi.spells.damage.calculateElementalAffinityBonus(player, element) or 1.0
        end
        if xi.spells.damage.calculateMagicCriticalMultiplier then
            magicCritMult = xi.spells.damage.calculateMagicCriticalMultiplier(player) or 1.0
        end
    end

    local resistTier           = 1.0
    local additionalResistTier = 1.0
    if not absorb and xi.combat and xi.combat.magicHitRate and xi.combat.magicHitRate.calculateResistRate then
        resistTier = xi.combat.magicHitRate.calculateResistRate(player, target,
        {
            magicBurstTier = canMBurst and magicBurstTier or 0,
            magicalElement = element,
            actorStat      = xi.mod.INT,
            skillType      = xi.skill.ELEMENTAL_MAGIC,
            spellGroup     = xi.magic.spellGroup.BLACK,
            bonusMacc      = isSever and 40 or 25,
        }) or 1.0
    end
    if not absorb and xi.spells and xi.spells.damage and xi.spells.damage.calculateAdditionalResistTier then
        additionalResistTier = xi.spells.damage.calculateAdditionalResistTier(player, target, element) or 1.0
    end

    local magicBurst      = 1.0
    local magicBurstBonus = 1.0
    if canMBurst and xi.spells and xi.spells.damage then
        if xi.spells.damage.calculateIfMagicBurst then
            magicBurst = xi.spells.damage.calculateIfMagicBurst(player, target, element, magicBurstTier) or 1.35
        end
        if xi.spells.damage.calculateIfMagicBurstBonus then
            magicBurstBonus = xi.spells.damage.calculateIfMagicBurstBonus(player, target, 0, xi.skill.ELEMENTAL_MAGIC, element) or 1.0
        end
    end

    local dayAndWeather  = 1.0
    local magicBonusDiff = 1.0
    if xi.spells and xi.spells.damage then
        if xi.spells.damage.calculateDayAndWeather then
            dayAndWeather = xi.spells.damage.calculateDayAndWeather(player, element, false) or 1.0
        end
        if xi.spells.damage.calculateMagicBonusDiff then
            -- Note: calculateMagicBonusDiff also includes our Spellblade Gambit 1.10x override when not absorb!
            magicBonusDiff = xi.spells.damage.calculateMagicBonusDiff(player, target, 0, xi.skill.ELEMENTAL_MAGIC, element, 0) or 1.0
        end
    end

    local mdtAdjust = 1.0
    local sdtAdjust = 1.0
    if not absorb and xi.combat and xi.combat.damage then
        if xi.combat.damage.calculateDamageAdjustment then
            mdtAdjust = xi.combat.damage.calculateDamageAdjustment(target, false, true, false, false) or 1.0
        end
        if xi.combat.damage.magicalElementSDT then
            sdtAdjust = xi.combat.damage.magicalElementSDT(target, element) or 1.0
        end
    end

    local finalDamage = baseDmg
    finalDamage = math.floor(finalDamage * staffBonus)
    finalDamage = math.floor(finalDamage * affinityBonus)
    finalDamage = math.floor(finalDamage * resistTier)
    finalDamage = math.floor(finalDamage * additionalResistTier)
    finalDamage = math.floor(finalDamage * magicBurst)
    finalDamage = math.floor(finalDamage * magicBurstBonus)
    finalDamage = math.floor(finalDamage * dayAndWeather)
    finalDamage = math.floor(finalDamage * magicBonusDiff)
    finalDamage = math.floor(finalDamage * mdtAdjust)
    finalDamage = math.floor(finalDamage * sdtAdjust)
    finalDamage = math.floor(finalDamage * magicCritMult)

    -- Era accumulative magic resistance ("Nuke Wall")
    if not absorb then
        local wallFactor = applyAccumulativeMagicWall(target, element, finalDamage)
        finalDamage      = math.floor(finalDamage * wallFactor)
    end

    if absorb then
        local healed = target.addHP and target:addHP(finalDamage) or finalDamage
        if spellObj ~= nil and spellObj.setMsg and xi.msg and xi.msg.basic then
            spellObj:setMsg(xi.msg.basic.MAGIC_RECOVERS_HP or 7)
        end
        return healed
    end

    if finalDamage > 0 and xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        finalDamage = xi.customBossServer.scaleDamageByLevelGap(player, target, finalDamage)
    end

    finalDamage = utils.clamp(utils.handlePhalanx(target, finalDamage), 0, 99999)
    finalDamage = utils.clamp(utils.handleOneForAll(target, finalDamage), 0, 99999)
    finalDamage = utils.handleStoneskin(target, finalDamage, xi.attackType.MAGICAL)
    if target.checkDamageCap then
        finalDamage = target:checkDamageCap(finalDamage)
    end

    if finalDamage > 0 then
        if spellObj ~= nil and target.takeSpellDamage then
            target:takeSpellDamage(player, spellObj, finalDamage, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
        elseif target.takeDamage then
            target:takeDamage(finalDamage, player, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
        end
        if target.handleAfflatusMiseryDamage then
            target:handleAfflatusMiseryDamage(finalDamage)
        end
    end
    if target.updateEnmityFromDamage then
        target:updateEnmityFromDamage(player, finalDamage)
    end
    if spellObj ~= nil then
        if canMBurst and spellObj.setMsg and xi.msg and xi.msg.basic then
            spellObj:setMsg(xi.msg.basic.MAGIC_BURST_DAMAGE or 252)
        elseif spellObj.setMsg and xi.msg and xi.msg.basic then
            spellObj:setMsg(xi.msg.basic.MAGIC_DMG or 2)
        end
    else
        if action ~= nil and action.recordDamage then
            action:recordDamage(target, xi.attackType.MAGICAL, finalDamage)
        end
        if canMBurst and action ~= nil and action.modifier and xi.msg and xi.msg.actionModifier then
            action:modifier(target:getID(), xi.msg.actionModifier.MAGIC_BURST)
        end
    end

    -- Edgeflare (Lv.30+): A positively damaging Bolt or Sever increases Rune Edge damage by 25% for 12s
    if finalDamage > 0 then
        grantOrRefreshEdgeflare(player, element)
    end

    return finalDamage
end

-- Element-specific spell animations for Runic Bolt (Tier I nuke visuals) & Runic Sever (Tier III nuke visuals)
local RUNIC_BOLT_ANIM_MAP =
{
    [xi.effect.IGNIS]    = 144, -- Fire
    [xi.effect.GELUS]    = 149, -- Blizzard
    [xi.effect.FLABRA]   = 154, -- Aero
    [xi.effect.TELLUS]   = 159, -- Stone
    [xi.effect.SULPOR]   = 164, -- Thunder
    [xi.effect.UNDA]     = 169, -- Water
    [xi.effect.LUX]      = 29,  -- Banish II
    [xi.effect.TENEBRAE] = 219, -- Comet / Dark
}

local RUNIC_SEVER_ANIM_MAP =
{
    [xi.effect.IGNIS]    = 146, -- Fire III
    [xi.effect.GELUS]    = 151, -- Blizzard III
    [xi.effect.FLABRA]   = 156, -- Aero III
    [xi.effect.TELLUS]   = 161, -- Stone III
    [xi.effect.SULPOR]   = 166, -- Thunder III
    [xi.effect.UNDA]     = 171, -- Water III
    [xi.effect.LUX]      = 31,  -- Banish IV / Holy
    [xi.effect.TENEBRAE] = 245, -- Drain / Dark burst
}

local function checkRunicMagicSpell(caster, target, spell, isSever)
    if not isRunSpec(caster, SPELLBLADE_KEY) then
        tell(caster, '[Spellblade] Runic Bolt and Runic Sever require the Spellblade crystal.')
        return xi.msg.basic.MAGIC_CANNOT_CAST or 47
    end

    local lvl    = caster.getMainLvl and caster:getMainLvl() or 1
    local minLvl = isSever and 55 or 10
    if lvl < minLvl then
        return xi.msg.basic.MAGIC_CANNOT_CAST or 47
    end

    if not isGreatSwordEquipped(caster) then
        tell(caster, '[Spellblade] Runic spells require a Greatsword equipped.')
        return xi.msg.basic.MAGIC_CANNOT_CAST or 47
    end

    if target == nil or target:getID() == caster:getID() or (target.isAlive and not target:isAlive()) then
        return xi.msg.basic.CANNOT_ATTACK_TARGET or 44
    end

    local runeErr = xi.job_utils.rune_fencer.checkHaveRunes(caster)
    if runeErr ~= 0 then
        tell(caster, '[Spellblade] You must harbor at least 1 active Rune to cast Runic spells.')
        return xi.msg.basic.MAGIC_CANNOT_CAST or 47
    end

    local stacks   = getConductionStacks(caster)
    local baseMp   = getRunicSpellBaseMp(isSever, lvl)
    local mpFactor = 1.0 - (0.15 * stacks)
    local mpCost   = math.max(1, isSever and math.floor(baseMp * mpFactor) or math.floor(baseMp * mpFactor + 0.5))
    local curMp    = caster.getMP and caster:getMP() or 0
    if curMp < mpCost then
        return xi.msg.basic.NOT_ENOUGH_MP or 34
    end

    local baseCastMs = isSever and 3000 or 2000
    local prepCastMs = math.max(250, baseCastMs - (stacks * 500))

    if caster.setLocalVar then
        caster:setLocalVar('OX_RUN_PREP_STACKS', stacks)
        caster:setLocalVar('OX_RUN_PREP_WPN', getMainSubWeaponSignature(caster))
    end

    if spell ~= nil then
        if spell.setMPCost then
            spell:setMPCost(mpCost)
        end
        if spell.setCastTime then
            spell:setCastTime(prepCastMs)
        end
        if spell.setAnimation then
            local runes      = getActiveRunesList(caster)
            local newestRune = (caster.getNewestRuneEffect and caster:getNewestRuneEffect()) or runes[#runes] or xi.effect.IGNIS
            local animMap    = isSever and RUNIC_SEVER_ANIM_MAP or RUNIC_BOLT_ANIM_MAP
            spell:setAnimation(animMap[newestRune] or (isSever and 166 or 144))
        end
    end

    return 0
end

local function bindBlackSpell(name, checkFn, castFn)
    xi.actions = xi.actions or {}
    xi.actions.spells = xi.actions.spells or {}
    xi.actions.spells.black = xi.actions.spells.black or {}
    xi.actions.spells.black[name] = xi.actions.spells.black[name] or {}
    xi.actions.spells.black[name].onMagicCastingCheck = checkFn
    xi.actions.spells.black[name].onSpellCast         = castFn
    m:addOverride('xi.actions.spells.black.' .. name .. '.onMagicCastingCheck', checkFn)
    m:addOverride('xi.actions.spells.black.' .. name .. '.onSpellCast', castFn)
end

bindBlackSpell('runic_bolt', function(caster, target, spell)
    return checkRunicMagicSpell(caster, target, spell, false)
end, function(caster, target, spell, action)
    return executeRunicSpell(caster, target, nil, action, false, spell)
end)

bindBlackSpell('runic_sever', function(caster, target, spell)
    return checkRunicMagicSpell(caster, target, spell, true)
end, function(caster, target, spell, action)
    return executeRunicSpell(caster, target, nil, action, true, spell)
end)

-----------------------------------
-- 4) Spellblade: Effusion Slash (415, 20s CD, Enemy 4y)
-- Non-consuming Great Sword arcane strike (1.5x-2.8x +20%/Rune) aligned to newest Rune.
-- Can Magic Burst (+35% DMG) and grants +100/150/200/250 TP.
-----------------------------------
bindAbility('effusion_slash', function(player, target, _ability)
    if not isRunSpec(player, SPELLBLADE_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if not isGreatSwordEquipped(player) then
        tell(player, '[Spellblade] Effusion Slash requires a Greatsword equipped.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if target == nil or target:getID() == player:getID() or (target.isAlive and not target:isAlive()) then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end

    local runeErr, runeParam = xi.job_utils.rune_fencer.checkHaveRunes(player)
    if runeErr ~= 0 then
        return runeErr, runeParam
    end

    return 0, 0
end, function(player, target, ability, action)
    local runes      = getActiveRunesList(player)
    local runeCount  = math.max(1, #runes)
    local newestRune = (player.getNewestRuneEffect and player:getNewestRuneEffect()) or runes[#runes] or xi.effect.IGNIS
    local element    = RUNE_ELEMENT_MAP[newestRune] or xi.element.FIRE
    local infoVal    = RUNE_EFFUSION_INFO_MAP[newestRune] or 2
    local targetId   = target:getID()

    if action ~= nil and action.info then
        action:info(targetId, infoVal)
    end

    -- Check Utsusemi / Blink shadows (1 hit)
    if utils and utils.takeShadows then
        local hitsLanded = utils.takeShadows(target, 1, 1)
        if hitsLanded == 0 then
            if ability ~= nil and ability.setMsg and xi.msg and xi.msg.basic then
                ability:setMsg(xi.msg.basic.SHADOW_ABSORB or 31)
            end
            if action ~= nil and action.resolution and xi.action and xi.action.resolution then
                action:resolution(targetId, xi.action.resolution.MISS)
            end
            return 1
        end
    end

    if action ~= nil then
        if action.setAnimation then
            action:setAnimation(targetId, 10) -- Retail Greatsword Effusion strike
        end
        if action.resolution and xi.action and xi.action.resolution then
            action:resolution(targetId, xi.action.resolution.HIT)
        end
    end

    local lvl    = player.getMainLvl and player:getMainLvl() or 10
    local tpGain = scaleTier(lvl, 100, 150, 200, 250)
    if player.addTP then
        player:addTP(tpGain)
    end
    addConductionStacks(player, 1)

    -- Nullification check
    if
        xi.spells and
        xi.spells.damage and
        xi.spells.damage.calculateNullification and
        xi.spells.damage.calculateNullification(target, element, false, true, false, false) == 0
    then
        return 0
    end

    local tierMult   = scaleTier(lvl, 1.50, 1.90, 2.35, 2.80)
    local runeMult   = 1.0 + (0.20 * runeCount)
    local weaponDmg  = math.max(10, player.getWeaponDmg and player:getWeaponDmg() or 18)
    local gsSkill    = math.max(lvl * 3, player.getSkillLevel and player:getSkillLevel(xi.skill.GREAT_SWORD) or 0)
    local strStat    = player.getStat and player:getStat(xi.mod.STR) or 10
    local intStat    = player.getStat and player:getStat(xi.mod.INT) or 10
    local mDmgBonus  = player.getMod and player:getMod(xi.mod.MAGIC_DAMAGE) or 0
    local strikeBase = weaponDmg + math.floor(gsSkill * 0.70 + strStat * 0.55 + intStat * 0.55) + mDmgBonus
    local baseDmg    = math.floor(strikeBase * tierMult * runeMult)

    local absorb = false
    if xi.spells and xi.spells.damage and xi.spells.damage.calculateAbsorption then
        absorb = xi.spells.damage.calculateAbsorption(target, element, false, true, false, false) < 0
    end

    local magicBurstTier = 0
    if not absorb and xi.combat and xi.combat.magicBurst and xi.combat.magicBurst.getMagicBurstTier then
        magicBurstTier = xi.combat.magicBurst.getMagicBurstTier(target, element) or 0
    end
    local canMBurst = not absorb and magicBurstTier > 0

    local resistTier = 1.0
    if not absorb and xi.combat and xi.combat.magicHitRate and xi.combat.magicHitRate.calculateResistRate then
        resistTier = xi.combat.magicHitRate.calculateResistRate(player, target,
        {
            magicBurstTier = canMBurst and magicBurstTier or 0,
            magicalElement = element,
            actorStat      = xi.mod.INT,
            skillType      = xi.skill.GREAT_SWORD,
            spellGroup     = xi.magic.spellGroup.NONE,
            bonusMacc      = 30,
        }) or 1.0
    end

    local magicBurst      = 1.0
    local magicBurstBonus = 1.0
    if canMBurst then
        magicBurst = 1.35
        if xi.spells and xi.spells.damage then
            if xi.spells.damage.calculateIfMagicBurst then
                magicBurst = math.max(1.35, xi.spells.damage.calculateIfMagicBurst(player, target, element, magicBurstTier) or 1.35)
            end
            if xi.spells.damage.calculateIfMagicBurstBonus then
                magicBurstBonus = xi.spells.damage.calculateIfMagicBurstBonus(player, target, 0, xi.skill.ELEMENTAL_MAGIC, element) or 1.0
            end
        end
    end

    local dayAndWeather  = 1.0
    local magicBonusDiff = 1.0
    if xi.spells and xi.spells.damage then
        if xi.spells.damage.calculateDayAndWeather then
            dayAndWeather = xi.spells.damage.calculateDayAndWeather(player, element, false) or 1.0
        end
        if xi.spells.damage.calculateMagicBonusDiff then
            magicBonusDiff = xi.spells.damage.calculateMagicBonusDiff(player, target, 0, xi.skill.ELEMENTAL_MAGIC, element, 0) or 1.0
        end
    end

    local mdtAdjust = 1.0
    local sdtAdjust = 1.0
    if not absorb and xi.combat and xi.combat.damage then
        if xi.combat.damage.calculateDamageAdjustment then
            mdtAdjust = xi.combat.damage.calculateDamageAdjustment(target, false, true, false, false) or 1.0
        end
        if xi.combat.damage.magicalElementSDT then
            sdtAdjust = xi.combat.damage.magicalElementSDT(target, element) or 1.0
        end
    end

    local finalDamage = baseDmg
    finalDamage = math.floor(finalDamage * resistTier)
    finalDamage = math.floor(finalDamage * magicBurst)
    finalDamage = math.floor(finalDamage * magicBurstBonus)
    finalDamage = math.floor(finalDamage * dayAndWeather)
    finalDamage = math.floor(finalDamage * magicBonusDiff)
    finalDamage = math.floor(finalDamage * mdtAdjust)
    finalDamage = math.floor(finalDamage * sdtAdjust)

    if absorb then
        local healed = target.addHP and target:addHP(finalDamage) or finalDamage
        if ability ~= nil and ability.setMsg and xi.msg and xi.msg.basic then
            ability:setMsg(xi.msg.basic.JA_RECOVERS_HP or 102)
        end
        return healed
    end

    if finalDamage > 0 and xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        finalDamage = xi.customBossServer.scaleDamageByLevelGap(player, target, finalDamage)
    end

    finalDamage = utils.clamp(utils.handlePhalanx(target, finalDamage), 0, 99999)
    finalDamage = utils.clamp(utils.handleOneForAll(target, finalDamage), 0, 99999)
    finalDamage = utils.handleStoneskin(target, finalDamage, xi.attackType.MAGICAL)
    if target.checkDamageCap then
        finalDamage = target:checkDamageCap(finalDamage)
    end

    if finalDamage > 0 then
        if target.takeSwipeLungeDamage then
            target:takeSwipeLungeDamage(player, finalDamage, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
        elseif target.takeDamage then
            target:takeDamage(finalDamage, player, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
        end
        if target.handleAfflatusMiseryDamage then
            target:handleAfflatusMiseryDamage(finalDamage)
        end
    end
    if target.updateEnmityFromDamage then
        target:updateEnmityFromDamage(player, finalDamage)
    end

    if canMBurst and action ~= nil and action.modifier and xi.msg and xi.msg.actionModifier then
        action:modifier(targetId, xi.msg.actionModifier.MAGIC_BURST)
    end

    if finalDamage > 0 then
        grantOrRefreshEdgeflare(player, element)
    end

    return finalDamage
end)

-----------------------------------
-- 5) Spellblade: Overcharge Runes (416, 30s CD, Self)
-- 12s overdrive: +15/22/30/40 MAB, +10/14/18/24% Attack%, +15/20/25/30 MB Bonus,
-- 2x Runic Brand damage, and refreshes active Rune durations.
-----------------------------------
bindAbility('overcharge_runes', function(player, _target, _ability)
    if not isRunSpec(player, SPELLBLADE_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local runeErr, runeParam = xi.job_utils.rune_fencer.checkHaveRunes(player)
    if runeErr ~= 0 then
        return runeErr, runeParam
    end

    return 0, 0
end, function(player, _target, _ability)
    local lvl            = player.getMainLvl and player:getMainLvl() or 10
    local mabBonus, tier = scaleTier(lvl, 15, 22, 30, 40)
    local attPct         = scaleTier(lvl, 10, 14, 18, 24)
    local mbBonus        = scaleTier(lvl, 15, 20, 25, 30)
    local iconId         = (xi.effect and xi.effect.MAGIC_ATK_BOOST) or EFFECT_OVERCHARGE_RUNES

    refreshActiveRuneDurations(player)

    local _, appliedId = applyTimedEffectWithMods(
        player,
        EFFECT_OVERCHARGE_RUNES,
        mabBonus,
        12,
        player,
        tier,
        iconId,
        {
            { xi.mod.MATT,                       mabBonus },
            { xi.mod.ATTP,                       attPct },
            { xi.mod.MAGIC_BURST_BONUS_UNCAPPED, mbBonus },
        }
    )

    return appliedId or EFFECT_OVERCHARGE_RUNES
end)

-----------------------------------
-- 6) Lifebinder: Font of Life (417, 20s CD, Self/Party 15y)
-----------------------------------
bindAbility('font_of_life', function(player, target, _ability)
    if not isRunSpec(player, LIFEBINDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if target == nil or (target.isAlive and not target:isAlive()) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, target, _ability)
    local recipient = target or player
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local healPct, tier = scaleTier(lvl, 22, 30, 38, 48)
    local dtBps     = scaleTier(lvl, -1000, -1400, -1800, -2200)
    local cureRcvd  = scaleTier(lvl, 10, 15, 20, 25)
    local mndStat   = player.getStat and player:getStat(xi.mod.MND) or 15
    local curePot   = 1.0 + ((player.getMod and player:getMod(xi.mod.CURE_POTENCY) or 0) / 100.0)
    local iconId    = (xi.effect and xi.effect.PROWESS) or (xi.effect and xi.effect.REGEN) or EFFECT_FONT_OF_LIFE

    cleanseTargetDebuffs(recipient, 2)

    local maxHp = recipient.getMaxHP and recipient:getMaxHP() or 100
    local curHp = recipient.getHP and recipient:getHP() or 0
    local rawHeal = math.max(20, math.floor((maxHp * healPct / 100 + mndStat * 1.5) * curePot))
    local actualHeal = math.min(rawHeal, math.max(0, maxHp - curHp))

    if recipient.restoreHP then
        recipient:restoreHP(actualHeal)
    elseif recipient.addHP then
        recipient:addHP(actualHeal)
    end

    applyTimedEffectWithMods(
        recipient,
        EFFECT_FONT_OF_LIFE,
        cureRcvd,
        12,
        player,
        tier,
        iconId,
        {
            { xi.mod.DMG,               dtBps },
            { xi.mod.CURE_POTENCY_RCVD, cureRcvd },
        }
    )

    return actualHeal
end)

-----------------------------------
-- 7) Lifebinder: Sanctified Ward (418, 35s CD, 15s Party 12y AoE)
-----------------------------------
bindAbility('sanctified_ward', function(player, _target, _ability)
    if not isRunSpec(player, LIFEBINDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, target, _ability)
    local recipient = target or player
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local healPct, tier = scaleTier(lvl, 10, 14, 18, 22)
    local regenPct  = scaleTier(lvl, 1.5, 2.2, 3.0, 4.0)
    local regenMin  = scaleTier(lvl, 15, 28, 44, 64)
    local dtBps     = scaleTier(lvl, -800, -1200, -1600, -2000)
    local mevaBonus = scaleTier(lvl, 15, 25, 35, 50)
    local curePot   = 1.0 + ((player.getMod and player:getMod(xi.mod.CURE_POTENCY) or 0) / 100.0)
    local iconId    = (xi.effect and xi.effect.VALIANCE) or EFFECT_SANCTIFIED_WARD

    local maxHp     = recipient.getMaxHP and recipient:getMaxHP() or 100
    local regenTick = 25
    if xi.overlords and xi.overlords.regen and xi.overlords.regen.computeHybridTick then
        regenTick = xi.overlords.regen.computeHybridTick(player, recipient, 25, 350)
    else
        regenTick = math.max(regenMin, math.floor(maxHp * regenPct / 100))
    end
    local healAmount = math.max(15, math.floor(maxHp * (healPct / 100) * curePot))
    if recipient.addHP then
        local healed = recipient:addHP(healAmount)
        if
            (healed > 0 or recipient:getID() ~= player:getID()) and
            player.messagePublic and
            xi.msg and
            xi.msg.basic and
            xi.msg.basic.RECOVERS_HP
        then
            player:messagePublic(xi.msg.basic.RECOVERS_HP, recipient, 0, healed)
        end
    end

    applyTimedEffectWithMods(
        recipient,
        EFFECT_SANCTIFIED_WARD,
        regenTick,
        15,
        player,
        tier,
        iconId,
        {
            { xi.mod.REGEN, regenTick },
        }
    )

    if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
        xi.overlords.slots.applyPartyWard(player, recipient, dtBps, mevaBonus, 15, iconId)
    end

    return EFFECT_SANCTIFIED_WARD
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if player ~= nil and isRunSpec(player, SPELLBLADE_KEY) then
        if player.setLocalVar then
            player:setLocalVar('OX_RUN_SPELLBLADE', 1)
        end
        ensureRunSpells(player, true)
        -- Conduction clears on zoning
        clearConduction(player, nil)
        attachRunListeners(player)
    elseif player ~= nil and isRunSpec(player, LIFEBINDER_KEY) then
        ensureRunSpells(player, false)
        attachRunListeners(player)
    elseif player ~= nil and isRunSpec(player, INQUISITOR_KEY) then
        ensureRunSpells(player, false)
    end
end)

return m
