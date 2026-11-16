-----------------------------------
-- OverlordsXI Rune Fencer Crystal Specs
-- Registers Rune Fencer crystals (Inquisitor, Spellblade, Lifebinder) and
-- implements their scaling passive stats, 3-rune Lv.10 mastery, custom Job
-- Abilities (412-418), and base RUN ability/spell transformations.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/basic/magic_aoe')
require('scripts/combat/magic_burst')
require('scripts/combat/physical_utilities')
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

-- Custom Status Effect IDs (821-826, within MAX_EFFECTID = 832)
local EFFECT_IRON_BATTUTA      = 821
local EFFECT_RUNIC_AEGIS       = 822
local EFFECT_RUNIC_CONVERGENCE = 823
local EFFECT_OVERCHARGE_RUNES  = 824
local EFFECT_FONT_OF_LIFE      = 825
local EFFECT_SANCTIFIED_WARD   = 826

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
xi.effect.SPELLBLADE_OVERCHARGE = EFFECT_OVERCHARGE_RUNES
xi.effect.LIFEBINDER_FONT       = EFFECT_FONT_OF_LIFE
xi.effect.LIFEBINDER_SANCTUARY  = EFFECT_SANCTIFIED_WARD

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
xi.effects.spellblade_overcharge = xi.effects.spellblade_overcharge or {}
xi.effects.lifebinder_font       = xi.effects.lifebinder_font or {}
xi.effects.lifebinder_sanctuary  = xi.effects.lifebinder_sanctuary or {}

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

local resonanceStateByCharId = {}

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

local function isRunSpec(entity, specKey)
    if entity == nil or not entity.isPC or not entity:isPC() or entity:getMainJob() ~= xi.job.RUN then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.RUN, specKey)
end

local function hasAnyRunSpec(entity)
    if entity == nil or not entity.isPC or not entity:isPC() or entity:getMainJob() ~= xi.job.RUN then
        return false
    end

    spec.ensureUpToDate(entity)
    return isRunSpec(entity, INQUISITOR_KEY) or isRunSpec(entity, SPELLBLADE_KEY) or isRunSpec(entity, LIFEBINDER_KEY)
end

local function isGreatSwordEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.GREAT_SWORD
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
    if mainTarget ~= nil and mainTarget.isMob and mainTarget:isMob() and mainTarget:isAlive() then
        grantEnmity(mainTarget, player, ce, ve)
    end

    local zone = player.getZone and player:getZone() or nil
    if zone ~= nil and zone.getMobs then
        for _, mob in ipairs(zone:getMobs()) do
            if
                mob ~= nil and
                mob:isMob() and
                mob:isAlive() and
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

local function restoreRunes(player, savedRunes)
    if player == nil or type(savedRunes) ~= 'table' or #savedRunes == 0 then
        return
    end

    local runLevel      = player.getMainLvl and player:getMainLvl() or 10
    local meritBonus    = player.getMerit and player:getMerit(xi.merit.RUNE_ENHANCE) or 0
    local jobPointBonus = player.getJobPointLevel and player:getJobPointLevel(xi.jp.RUNE_ENCHANTMENT_EFFECT) or 0
    local power         = math.floor((49 * runLevel / 99) + 5.5) + meritBonus + jobPointBonus

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

local function countDistinctAndIdenticalRunes(runes)
    local counts   = {}
    local distinct = 0
    local maxSame  = 0

    for _, runeId in ipairs(runes) do
        if counts[runeId] == nil then
            counts[runeId] = 1
            distinct = distinct + 1
        else
            counts[runeId] = counts[runeId] + 1
        end
        if counts[runeId] > maxSame then
            maxSame = counts[runeId]
        end
    end

    return #runes, distinct, maxSame
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

    local maxDist = radius or 12.0
    local rawList = nil
    if player.getPartyWithTrusts then
        rawList = player:getPartyWithTrusts()
    elseif player.getParty then
        rawList = player:getParty()
    end

    if type(rawList) ~= 'table' or #rawList == 0 then
        return { player }
    end

    local out  = {}
    local seen = {}
    for _, member in pairs(rawList) do
        if
            member ~= nil and
            member.getID and
            not seen[member:getID()] and
            (not member.isAlive or member:isAlive()) and
            (member:getID() == player:getID() or (player.checkDistance and player:checkDistance(member) <= maxDist))
        then
            seen[member:getID()] = true
            table.insert(out, member)
        end
    end

    if not seen[player:getID()] then
        table.insert(out, player)
    end

    return out
end

local function applyTimedEffectWithMods(target, effectId, power, duration, origin, subPower, iconId, mods)
    if target == nil or not target.addStatusEffect then
        return false
    end

    if target:hasStatusEffect(effectId) then
        target:delStatusEffectSilent(effectId)
    end

    local ok = target:addStatusEffect(effectId,
    {
        power    = power or 1,
        duration = duration or 15,
        origin   = origin or target,
        subPower = subPower or 0,
        icon     = iconId or effectId,
    })

    if ok then
        local eff = target:getStatusEffect(effectId)
        if eff ~= nil and eff.addMod and type(mods) == 'table' then
            for _, pair in ipairs(mods) do
                if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                    eff:addMod(pair[1], pair[2])
                end
            end
        end
    end

    return ok
end

local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

-----------------------------------
-- Spellblade Resonance Dynamic Mod Sync
-----------------------------------
local function clearSpellbladeResonance(player)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local prev   = resonanceStateByCharId[charId]
    if prev ~= nil then
        if player.delMod then
            for _, m in ipairs(prev) do
                player:delMod(m[1], m[2])
            end
        end
        resonanceStateByCharId[charId] = nil
    end
end

local function syncSpellbladeResonance(player)
    if player == nil or not player.getID then
        return
    end

    clearSpellbladeResonance(player)

    if not isRunSpec(player, SPELLBLADE_KEY) then
        return
    end

    local runes = getActiveRunesList(player)
    local total, distinct, maxSame = countDistinctAndIdenticalRunes(runes)
    if total < 3 then
        return
    end

    local modsToAdd = nil
    if maxSame >= 3 then
        -- Mono-Element Resonance (3 identical Runes): +20 MACC & +15 MAB
        modsToAdd =
        {
            { xi.mod.MACC, 20 },
            { xi.mod.MATT, 15 },
        }
    elseif distinct >= 3 then
        -- Tri-Element Resonance (3 distinct Runes): +12% Skillchain Bonus & +8% Triple Attack
        modsToAdd =
        {
            { xi.mod.SKILLCHAINBONUS, 12 },
            { xi.mod.TRIPLE_ATTACK,    8 },
        }
    end

    if modsToAdd ~= nil and player.addMod then
        for _, pair in ipairs(modsToAdd) do
            player:addMod(pair[1], pair[2])
        end
        resonanceStateByCharId[player:getID()] = modsToAdd
    end
end

-----------------------------------
-- Combat Listeners: Spellblade Runic Brand & Lifebinder Runic Lifetap
-----------------------------------
local function detachRunListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_RUN_MELEE')
        player:removeListener('OX_RUN_WS')
    end
end

local function triggerSpellbladeRunicBrand(actor, target, isWeaponskill)
    if
        actor == nil or
        target == nil or
        target == actor or
        (target.isAlive and not target:isAlive())
    then
        return
    end

    local runes = getActiveRunesList(actor)
    local runeCount, _, maxSame = countDistinctAndIdenticalRunes(runes)
    if runeCount <= 0 then
        return
    end

    local lvl       = actor.getMainLvl and actor:getMainLvl() or 10
    local gsSkill   = actor.getSkillLevel and actor:getSkillLevel(xi.skill.GREAT_SWORD) or (lvl * 3)
    local intStat   = actor.getStat and actor:getStat(xi.mod.INT) or lvl
    local mab       = 1.0 + ((actor.getMod and actor:getMod(xi.mod.MATT) or 0) / 100.0)
    local overMult  = (actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_OVERCHARGE_RUNES)) and 2.0 or 1.0
    local monoMult  = (maxSame >= 3) and 1.25 or 1.0
    local wsMult    = isWeaponskill and 2.2 or 1.0

    local perRune   = math.max(3, math.floor((4 + gsSkill * 0.06 + intStat * 0.22 + lvl * 0.25) * mab * overMult * monoMult * wsMult))
    local totalDmg  = perRune * runeCount
    local newest    = actor.getNewestRuneEffect and actor:getNewestRuneEffect() or runes[#runes]
    local element   = RUNE_ELEMENT_MAP[newest] or xi.element.FIRE

    totalDmg = utils.handleStoneskin(target, totalDmg, xi.attackType.MAGICAL)
    if totalDmg > 0 and target.takeDamage then
        target:takeDamage(totalDmg, actor, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
    end
end

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
        mostInjured:addHP(healAmount)
    end

    if actor.addMP and actor.getMaxMP then
        local mpPct = isWeaponskill and 0.03 or 0.01
        local mpGain = math.max(2, math.floor(actor:getMaxMP() * mpPct))
        actor:addMP(mpGain)
    end
end

local function attachRunListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachRunListeners(player)

    player:addListener('MELEE_SWING_HIT', 'OX_RUN_MELEE', function(actor, target)
        if actor == nil or target == nil or target == actor then
            return
        end

        if isRunSpec(actor, SPELLBLADE_KEY) then
            triggerSpellbladeRunicBrand(actor, target, false)
        elseif isRunSpec(actor, LIFEBINDER_KEY) then
            triggerLifebinderMend(actor, false)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_RUN_WS', function(actor, target, _ws, _tp, _action, dmg)
        if actor == nil or target == nil or target == actor or (dmg ~= nil and dmg <= 0) then
            return
        end

        if isRunSpec(actor, SPELLBLADE_KEY) then
            triggerSpellbladeRunicBrand(actor, target, true)
        elseif isRunSpec(actor, LIFEBINDER_KEY) then
            triggerLifebinderMend(actor, true)
        end
    end)
end

-----------------------------------
-- Crystal Definitions (RUN)
-----------------------------------
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
                    { xi.mod.GREAT_SWORD,           scaleTier(lvl, 12, 24, 40, 50) },
                    { xi.mod.INQUARTATA,            scaleTier(lvl, 6, 10, 15, 18) },
                    -- Tank damage tradeoff
                    { xi.mod.ATTP,                  -20 },
                    { xi.mod.ALL_WSDMG_ALL_HITS,    -15 },
                }
            end,
            onApply = function(player)
                clearSpellbladeResonance(player)
                detachRunListeners(player)
            end,
            onRemove = function(player)
                if player ~= nil and player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_IRON_BATTUTA)
                    player:delStatusEffectSilent(EFFECT_RUNIC_AEGIS)
                    player:delStatusEffectSilent(EFFECT_RUNIC_CONVERGENCE)
                end
            end,
        },
        {
            id          = 2,
            key         = SPELLBLADE_KEY,
            name        = 'Spellblade',
            role        = 'Elemental Effusion & Great Sword Burst DPS',
            icon        = 'spellblade',
            reqLevel    = 10,
            extraAbilities =
            {
                (xi.jobAbility and xi.jobAbility.SWIPE) or 344,
                (xi.jobAbility and xi.jobAbility.LUNGE) or 368,
                (xi.jobAbility and xi.jobAbility.GAMBIT) or 372,
                (xi.jobAbility and xi.jobAbility.RAYKE) or 375,
                ABIL_EFFUSION_SLASH,
                ABIL_OVERCHARGE_RUNES,
            },
            extraTraits = { TRAIT_RUNIC_BRAND },
            description = 'Ulbukan frontier vanguard (Lv10+): harbors 3 Runes at Lv10+, imbues every Great Sword swing and WS with multi-rune elemental discharges, and weaves rapid Effusion Magic Bursts.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+): +8/14/20/25% Attack%, +6/10/15/18% Double Attack, +6/10/15/18% WS Damage, +12/22/35/45 MAB, +10/20/35/45 MACC, +6/12/18/24 Store TP, -15/25/35/40 Enmity.',
                'Runic Brand (3 Runes at Lv10+): Every active Rune adds a scaling elemental strike to your melee swings and Weaponskills (2.2x on WSs).',
                'Elemental Resonance: 3 identical Runes grant +25% Runic Brand damage & +20 MACC; 3 distinct Runes grant +12% Skillchain Damage & +8% Triple Attack.',
                'Effusion Slash (Lv10, 20s CD, Enemy 4y): Non-consuming Great Sword arcane cleave (1.5x-2.8x +20%/Rune) that can Magic Burst (+35% DMG) and grants +100/150/200/250 TP.',
                'Overcharge Runes (Lv10, 30s CD, 12s, Self): +15/22/30/40 MAB, +10/14/18/24% Attack%, +15/20/25/30 MB Bonus, 2x Runic Brand damage, and non-consuming +50% DMG Swipe/Lunge.',
                'Effusion Mastery: Swipe (15s CD, keeps Runes, +150 TP), Lunge (30s CD, +25% DMG, refunds newest Rune), Gambit & Rayke (60s CD, keep Runes, inflict -10/15/20% DEF Down), Embolden (+20% WSD & +25 MAB).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.ATTP,               scaleTier(lvl, 8, 14, 20, 25) },
                    { xi.mod.DOUBLE_ATTACK,      scaleTier(lvl, 6, 10, 15, 18) },
                    { xi.mod.ALL_WSDMG_ALL_HITS, scaleTier(lvl, 6, 10, 15, 18) },
                    { xi.mod.MATT,               scaleTier(lvl, 12, 22, 35, 45) },
                    { xi.mod.MACC,               scaleTier(lvl, 10, 20, 35, 45) },
                    { xi.mod.STORETP,            scaleTier(lvl, 6, 12, 18, 24) },
                    { xi.mod.ENMITY,             scaleTier(lvl, -15, -25, -35, -40) },
                }
            end,
            onApply = function(player)
                attachRunListeners(player)
                syncSpellbladeResonance(player)
            end,
            onRemove = function(player)
                clearSpellbladeResonance(player)
                detachRunListeners(player)
                if player ~= nil and player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_OVERCHARGE_RUNES)
                end
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
                'Sanctified Ward (Lv10, 35s CD, 15s, Party 12y): Instant 10/14/18/22% Party HP heal + 15s Sanctuary (+10/18/28/40 Regen, -8/12/16/20% DT, +15/25/35/50 MEVA).',
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
                    { xi.mod.ENHANCING,        scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.DIVINE,           scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.HEALING,          scaleTier(lvl, 15, 25, 40, 50) },
                    { xi.mod.FASTCAST,         scaleTier(lvl, 10, 18, 25, 30) },
                    { xi.mod.REGEN_MULTIPLIER, 50 },
                    { xi.mod.REGEN_DURATION,   60 },
                    { xi.mod.ENMITY,           scaleTier(lvl, -15, -25, -35, -40) },
                }
            end,
            onApply = function(player)
                clearSpellbladeResonance(player)
                attachRunListeners(player)
            end,
            onRemove = function(player)
                detachRunListeners(player)
            end,
        },
    })
end

-----------------------------------
-- 3-Rune Mastery at Lv.10+ for All RUN Specs
-----------------------------------
m:addOverride('xi.job_utils.rune_fencer.useRuneEnchantment', function(player, target, ability, effect)
    if hasAnyRunSpec(player) then
        local activeRunes = target:getActiveRuneCount()
        if activeRunes >= 3 and target.removeOldestRune then
            target:removeOldestRune()
        end

        local runLevel      = player.getMainLvl and player:getMainLvl() or 10
        local meritBonus    = player.getMerit and player:getMerit(xi.merit.RUNE_ENHANCE) or 0
        local jobPointBonus = player.getJobPointLevel and player:getJobPointLevel(xi.jp.RUNE_ENCHANTMENT_EFFECT) or 0
        local power         = math.floor((49 * runLevel / 99) + 5.5) + meritBonus + jobPointBonus

        target:addStatusEffect(effect, { power = power, duration = 300, origin = player })
        syncSpellbladeResonance(player)
        return
    end

    super(player, target, ability, effect)
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
    local stanceMult = (defender.hasStatusEffect and defender:hasStatusEffect(EFFECT_IRON_BATTUTA)) and 1.35 or 1.0

    local rawDmg = math.max(5, math.floor((weaponDmg * 0.45 + vitStat * 0.25 + lvl * 0.30 + runeCount * 4) * stanceMult))
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
-- Swipe (344) & Lunge (368)
m:addOverride('xi.actions.abilities.swipe.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isRunSpec(player, SPELLBLADE_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(15)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.lunge.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isRunSpec(player, SPELLBLADE_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(30)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useSwipeLunge', function(player, target, ability, action)
    local isInq = isRunSpec(player, INQUISITOR_KEY)
    local isSpb = isRunSpec(player, SPELLBLADE_KEY)
    if not isInq and not isSpb then
        return super(player, target, ability, action)
    end

    local savedRunes = snapshotRunes(player)
    local abilityId  = ability and ability:getID() or 0
    local isSwipe    = (abilityId == (xi.jobAbility and xi.jobAbility.SWIPE or 344))
    local overcharged = player.hasStatusEffect and player:hasStatusEffect(EFFECT_OVERCHARGE_RUNES) or false

    local swipeModBoost = 0
    if isSpb then
        swipeModBoost = overcharged and 50 or 25
        if swipeModBoost > 0 and player.addMod then
            player:addMod(xi.mod.SWIPE, swipeModBoost)
        end
    end

    local ok, dmg = pcall(super, player, target, ability, action)

    if swipeModBoost > 0 and player.delMod then
        player:delMod(xi.mod.SWIPE, swipeModBoost)
    end

    if not ok then
        error(dmg)
    end

    if isInq then
        restoreRunes(player, savedRunes)
        local runeCount = math.max(1, #savedRunes)
        grantEnmity(target, player, 180 * runeCount, 480 * runeCount)
    elseif isSpb then
        if isSwipe or overcharged then
            restoreRunes(player, savedRunes)
        elseif #savedRunes > 0 then
            -- Lunge refunds the newest rune outside Overcharge Runes
            restoreRunes(player, { savedRunes[#savedRunes] })
        end

        if isSwipe and player.addTP then
            player:addTP(150)
        end
        syncSpellbladeResonance(player)
    end

    return dmg
end)

-- Gambit (372) & Rayke (375)
m:addOverride('xi.actions.abilities.gambit.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and (isRunSpec(player, SPELLBLADE_KEY) or isRunSpec(player, INQUISITOR_KEY)) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.rayke.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and (isRunSpec(player, SPELLBLADE_KEY) or isRunSpec(player, INQUISITOR_KEY)) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useGambit', function(player, target, ability, action)
    local isInq = isRunSpec(player, INQUISITOR_KEY)
    local isSpb = isRunSpec(player, SPELLBLADE_KEY)
    local savedRunes = (isInq or isSpb) and snapshotRunes(player) or nil

    local res = super(player, target, ability, action)

    if isInq or isSpb then
        restoreRunes(player, savedRunes)
        if isInq then
            local runeCount = math.max(1, #(savedRunes or {}))
            grantEnmity(target, player, 220 * runeCount, 550 * runeCount)
        elseif isSpb and target ~= nil and target.addStatusEffect then
            local lvl = player.getMainLvl and player:getMainLvl() or 10
            local defDown = scaleTier(lvl, 10, 15, 20, 20)
            target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = defDown, duration = 30, origin = player })
            syncSpellbladeResonance(player)
        end
    end

    return res
end)

m:addOverride('xi.job_utils.rune_fencer.useRayke', function(player, target, ability, action)
    local isInq = isRunSpec(player, INQUISITOR_KEY)
    local isSpb = isRunSpec(player, SPELLBLADE_KEY)
    local savedRunes = (isInq or isSpb) and snapshotRunes(player) or nil

    local res = super(player, target, ability, action)

    if isInq or isSpb then
        restoreRunes(player, savedRunes)
        if isInq then
            local runeCount = math.max(1, #(savedRunes or {}))
            grantEnmity(target, player, 220 * runeCount, 550 * runeCount)
        elseif isSpb and target ~= nil and target.addStatusEffect then
            local lvl = player.getMainLvl and player:getMainLvl() or 10
            local defDown = scaleTier(lvl, 10, 15, 20, 20)
            target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = defDown, duration = 30, origin = player })
            syncSpellbladeResonance(player)
        end
    end

    return res
end)

-- Vallation (366) & Valiance (371)
m:addOverride('xi.actions.abilities.valiance.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and (isRunSpec(player, LIFEBINDER_KEY) or isRunSpec(player, INQUISITOR_KEY)) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useVallationValiance', function(player, target, ability, action)
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

-- Swordplay (367), Pflug (369), Battuta (376), Liement (373), Embolden (370), One for All (374), Elemental Sforzo (356)
m:addOverride('xi.actions.abilities.swordplay.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isRunSpec(player, INQUISITOR_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(120)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.rune_fencer.useSwordplay', function(player, target, ability)
    if isRunSpec(player, INQUISITOR_KEY) then
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

m:addOverride('xi.actions.abilities.pflug.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isRunSpec(player, INQUISITOR_KEY) then
        if ability ~= nil and ability.setRecast then
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
    if player ~= nil and player:isPC() and isRunSpec(player, INQUISITOR_KEY) then
        if ability ~= nil and ability.setRecast then
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
    if player ~= nil and player:isPC() and isRunSpec(player, INQUISITOR_KEY) then
        if ability ~= nil and ability.setRecast then
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

m:addOverride('xi.actions.abilities.embolden.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isRunSpec(player, SPELLBLADE_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.embolden.onUseAbility', function(player, target, ability, action)
    local res = super(player, target, ability, action)

    if isRunSpec(player, SPELLBLADE_KEY) and target ~= nil then
        local eff = target:getStatusEffect(xi.effect.EMBOLDEN)
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.ALL_WSDMG_ALL_HITS, 20)
            eff:addMod(xi.mod.MATT, 25)
        end
    end

    return res
end)

m:addOverride('xi.actions.abilities.one_for_all.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and (isRunSpec(player, LIFEBINDER_KEY) or isRunSpec(player, INQUISITOR_KEY)) then
        if ability ~= nil and ability.setRecast then
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
                member:addHP(healAmount)
            end
        end
    end
end)

m:addOverride('xi.actions.abilities.elemental_sforzo.onUseAbility', function(player, target, ability)
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
    if player ~= nil and player:isPC() and isRunSpec(player, LIFEBINDER_KEY) then
        if ability ~= nil and ability.setRecast then
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

    -- Tenebrae restores MP to the Lifebinder
    if tenebraeCount > 0 and player.addMP and player.getMaxMP then
        local mpPct  = scaleTier(lvl, 6, 9, 12, 15) * tenebraeCount
        local mpHeal = math.max(8, math.floor(player:getMaxMP() * mpPct / 100))
        player:addMP(mpHeal)
    end

    local regenTick   = scaleTier(lvl, 8, 15, 24, 32)
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
            member:restoreHP(actualHeal)
        elseif member.addHP then
            member:addHP(actualHeal)
        end

        if member:getID() == player:getID() then
            casterHealed = actualHeal
        end

        if undaCount > 0 then
            cleanseTargetDebuffs(member, undaCount)
        end

        if luxCount > 0 and member.addStatusEffect then
            member:addStatusEffect(xi.effect.REGEN, { power = regenTick * luxCount, duration = 30, origin = player, tick = 3, tier = 1 })
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
        spell.isAoE and
        spell:isAoE() == xi.magic.aoe.RADIAL_ACCE
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

    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_RUNIC_AEGIS)
    end

    applyTimedEffectWithMods(
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

    -- Steel Flash Transition Pulse: Stoneskin + Rune Duration Refresh + AoE Enmity
    local maxHp = player.getMaxHP and player:getMaxHP() or 100
    local skinVal = math.max(15, math.floor(maxHp * skinPct / 100))
    if player.addStatusEffect and not player:hasStatusEffect(xi.effect.STONESKIN) then
        player:addStatusEffect(xi.effect.STONESKIN, { power = skinVal, duration = 60, origin = player })
    end

    refreshActiveRuneDurations(player)
    pulseNearbyEnmity(player, 160, 420, 12.0)

    return EFFECT_IRON_BATTUTA
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

    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_IRON_BATTUTA)
    end

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

    applyTimedEffectWithMods(
        player,
        EFFECT_RUNIC_AEGIS,
        mevaBonus,
        300,
        player,
        tier,
        iconId,
        mods
    )

    -- Odyllic Pulse Transition: HP/MP Restore + Debuff Cleanse + Rune Refresh + AoE Enmity
    if player.addHP and player.getMaxHP then
        player:addHP(math.max(10, math.floor(player:getMaxHP() * pulsePct / 100)))
    end
    if player.addMP and player.getMaxMP then
        player:addMP(math.max(5, math.floor(player:getMaxMP() * pulsePct / 100)))
    end

    cleanseTargetDebuffs(player, tier >= 3 and 2 or 1)
    refreshActiveRuneDurations(player)
    pulseNearbyEnmity(player, 160, 420, 12.0)

    return EFFECT_RUNIC_AEGIS
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

    applyTimedEffectWithMods(
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

    refreshActiveRuneDurations(player)
    pulseNearbyEnmity(player, 240, 680, 12.0)

    return EFFECT_RUNIC_CONVERGENCE
end)

-- 4) Spellblade: Effusion Slash (415, 20s CD, Enemy 4y)
bindAbility('effusion_slash', function(player, target, _ability)
    if not isRunSpec(player, SPELLBLADE_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if target == nil or target:getID() == player:getID() or (target.isAlive and not target:isAlive()) then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return xi.job_utils.rune_fencer.checkHaveRunes(player)
end, function(player, target, _ability, action)
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local mult, _   = scaleTier(lvl, 1.5, 1.9, 2.3, 2.8)
    local tpGrant   = scaleTier(lvl, 100, 150, 200, 250)
    local runes     = getActiveRunesList(player)
    local runeCount, _, maxSame = countDistinctAndIdenticalRunes(runes)
    runeCount = math.max(1, runeCount)

    local weaponDmg = player.getWeaponDmg and player:getWeaponDmg() or 12
    local gsSkill   = player.getSkillLevel and player:getSkillLevel(xi.skill.GREAT_SWORD) or (lvl * 3)
    local strStat   = player.getStat and player:getStat(xi.mod.STR) or lvl
    local intStat   = player.getStat and player:getStat(xi.mod.INT) or lvl
    local mab       = 1.0 + ((player.getMod and player:getMod(xi.mod.MATT) or 0) / 100.0)
    local runeMult  = 1.0 + (runeCount * 0.20) + ((maxSame >= 3) and 0.15 or 0.0)
    local overMult  = (player.hasStatusEffect and player:hasStatusEffect(EFFECT_OVERCHARGE_RUNES)) and 1.25 or 1.0

    local newest  = player.getNewestRuneEffect and player:getNewestRuneEffect() or runes[#runes] or xi.effect.IGNIS
    local element = RUNE_ELEMENT_MAP[newest] or xi.element.FIRE

    local mbTier = 0
    if xi.combat and xi.combat.magicBurst and xi.combat.magicBurst.getMagicBurstTier then
        mbTier = xi.combat.magicBurst.getMagicBurstTier(target, element) or 0
    end
    local mbMult = (mbTier > 0) and 1.35 or 1.0

    local rawDmg = math.max(20, math.floor((weaponDmg * mult + gsSkill * 0.35 + (strStat + intStat) * 0.55 + lvl * 1.6) * mab * runeMult * overMult * mbMult))
    local dmg    = utils.handleStoneskin(target, rawDmg, xi.attackType.MAGICAL)

    if target.takeDamage then
        target:takeDamage(dmg, player, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL + element)
    end
    if target.updateEnmityFromDamage then
        target:updateEnmityFromDamage(player, dmg)
    end
    if action ~= nil and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, dmg)
    end
    if mbTier > 0 and action ~= nil and action.modifier and xi.msg and xi.msg.actionModifier then
        action:modifier(target:getID(), xi.msg.actionModifier.MAGIC_BURST)
    end

    if player.addTP then
        player:addTP(tpGrant)
    end

    return dmg
end)

-- 5) Spellblade: Overcharge Runes (416, 30s CD, 12s Self)
bindAbility('overcharge_runes', function(player, _target, _ability)
    if not isRunSpec(player, SPELLBLADE_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return xi.job_utils.rune_fencer.checkHaveRunes(player)
end, function(player, _target, _ability)
    local lvl = player.getMainLvl and player:getMainLvl() or 10
    local mabBonus, tier = scaleTier(lvl, 15, 22, 30, 40)
    local attpBonus = scaleTier(lvl, 10, 14, 18, 24)
    local mbBonus   = scaleTier(lvl, 15, 20, 25, 30)
    local iconId    = (xi.effect and xi.effect.EMBOLDEN) or EFFECT_OVERCHARGE_RUNES

    local mods =
    {
        { xi.mod.MATT,              mabBonus },
        { xi.mod.ATTP,              attpBonus },
        { xi.mod.MAGIC_BURST_BONUS, mbBonus },
    }

    applyTimedEffectWithMods(
        player,
        EFFECT_OVERCHARGE_RUNES,
        mabBonus,
        12,
        player,
        tier,
        iconId,
        mods
    )

    refreshActiveRuneDurations(player)
    syncSpellbladeResonance(player)

    return EFFECT_OVERCHARGE_RUNES
end)

-- 6) Lifebinder: Font of Life (417, 20s CD, Self/Party 15y)
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

-- 7) Lifebinder: Sanctified Ward (418, 35s CD, 15s Party 12y AoE)
bindAbility('sanctified_ward', function(player, _target, _ability)
    if not isRunSpec(player, LIFEBINDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, target, _ability)
    local recipient = target or player
    local lvl       = player.getMainLvl and player:getMainLvl() or 10
    local healPct, tier = scaleTier(lvl, 10, 14, 18, 22)
    local regenTick = scaleTier(lvl, 10, 18, 28, 40)
    local dtBps     = scaleTier(lvl, -800, -1200, -1600, -2000)
    local mevaBonus = scaleTier(lvl, 15, 25, 35, 50)
    local curePot   = 1.0 + ((player.getMod and player:getMod(xi.mod.CURE_POTENCY) or 0) / 100.0)
    local iconId    = (xi.effect and xi.effect.VALIANCE) or EFFECT_SANCTIFIED_WARD

    local maxHp = recipient.getMaxHP and recipient:getMaxHP() or 100
    local healAmount = math.max(15, math.floor(maxHp * (healPct / 100) * curePot))
    if recipient.addHP then
        recipient:addHP(healAmount)
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
            { xi.mod.DMG,   dtBps },
            { xi.mod.MEVA,  mevaBonus },
        }
    )

    return EFFECT_SANCTIFIED_WARD
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if isRunSpec(player, SPELLBLADE_KEY) or isRunSpec(player, LIFEBINDER_KEY) then
        attachRunListeners(player)
    end
    if isRunSpec(player, SPELLBLADE_KEY) then
        syncSpellbladeResonance(player)
    end
end)

return m
