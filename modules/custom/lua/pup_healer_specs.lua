-----------------------------------
-- OverlordsXI Puppetmaster Crystal Spec: Animist (ANM | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set animist)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/pup_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/puppetmaster')
require('scripts/globals/pets/automaton')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_pup_healer_specs')

local spec = xi.overlords.spec
local ANIMIST_KEY = 'animist'

-- Custom Trait ID (174; Clockwork Medic)
local TRAIT_CLOCKWORK_MEDIC = 174

-- Custom Ability IDs (466-467; recastIds 166-167)
local ABIL_AETHER_OVERHAUL = 466
local ABIL_CLOCKWORK_AEGIS = 467

-- Custom Status Effect ID (871; registered in patch 0028)
local EFFECT_CLOCKWORK_AEGIS = 871

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.AETHER_OVERHAUL = ABIL_AETHER_OVERHAUL
xi.jobAbility.CLOCKWORK_AEGIS = ABIL_CLOCKWORK_AEGIS

xi.effect = xi.effect or {}
xi.effect.CLOCKWORK_AEGIS = EFFECT_CLOCKWORK_AEGIS

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.aether_overhaul = xi.actions.abilities.aether_overhaul or {}
xi.actions.abilities.clockwork_aegis = xi.actions.abilities.clockwork_aegis or {}

xi.effects = xi.effects or {}
xi.effects.clockwork_aegis = xi.effects.clockwork_aegis or {}

local function isAnimist(entity)
    return H.isSpecActive(entity, xi.job.PUP, ANIMIST_KEY)
end

local ANIMIST_WS_IDS =
{
    [13]  = true, -- Stringing Pummel
    [6]   = true, -- Howling Fist
    [9]   = true, -- Asuran Fists
    [169] = true, -- Black Halo
    [174] = true, -- Realmrazer
}

local function syncAutomatonHealerMods(player)
    if not isAnimist(player) or not player.getPet then
        return
    end
    local pet = player:getPet()
    if pet == nil or not pet.isAutomaton or not pet:isAutomaton() then
        return
    end
    if pet:getLocalVar('OX_ANM_SYNCED') == 1 then
        return
    end
    pet:setLocalVar('OX_ANM_SYNCED', 1)
    pet:addMod(xi.mod.HPP, 50)
    pet:addMod(xi.mod.MPP, 50)
    pet:addMod(xi.mod.DMG, -3500)
    pet:addMod(xi.mod.FASTCAST, 100)
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.clockwork_aegis.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.REGAIN, 20)
end)

-----------------------------------
-- Listeners (Maneuver Aether Pulse, H2H/Club WS Curaga Burst)
-----------------------------------
local function attachAnimistListeners(player)
    if player == nil or player:getLocalVar('OX_ANM_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_ANM_LISTENERS', 1)

    player:addListener('ABILITY_USE', 'OX_ANM_ABIL', function(caster, _target, ability)
        if not isAnimist(caster) or ability == nil then
            return
        end
        local abilId = ability:getID()
        -- Maneuvers (141..148)
        if abilId >= 141 and abilId <= 148 then
            H.healPartyPct(caster, 8, 15, true, true)
            if caster:hasStatusEffect(xi.effect.OVERDRIVE) then
                H.forEachPartyMemberInRange(caster, 15, true, function(unit)
                    H.cleanseDebuffs(unit, 3)
                end)
            end
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_ANM_WS', function(caster, _target, ws)
        if not isAnimist(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, ANIMIST_WS_IDS, { [xi.skill.HAND_TO_HAND] = true, [xi.skill.CLUB] = true }) then
            H.healPartyPct(caster, 18, 15, true, false)
            local skinAmt = math.floor(caster:getMaxHP() * 0.15)
            H.forEachPartyMemberInRange(caster, 15, true, function(unit)
                H.applyStoneskinBarrier(unit, skinAmt, skinAmt * 2, 12, caster)
            end)
        end
    end)

    player:addListener('PET_MAGIC_USE', 'OX_ANM_PET_MAGIC', function(pet, target, spell, action)
        local master = pet and pet.getMaster and pet:getMaster()
        if not isAnimist(master) or spell == nil then
            return
        end
        local sf = spell:getSpellFamily()
        if sf == xi.magic.spellFamily.CURE or sf == xi.magic.spellFamily.REGEN then
            local healed = action and action:getParam() or math.floor(master:getMaxHP() * 0.20)
            H.forEachPartyMemberInRange(master, 15, false, function(member)
                if member ~= target then
                    H.healEntity(master, member, healed)
                end
            end)
            H.restoreMpPct(master, 5)
        end
    end)
end

local function detachAnimistListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_ANM_LISTENERS', 0)
    player:removeListener('OX_ANM_ABIL')
    player:removeListener('OX_ANM_WS')
    player:removeListener('OX_ANM_PET_MAGIC')
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.repair.onAbilityCheck', function(player, target, ability)
    if isAnimist(player) then
        local pet = player:getPet()
        if pet == nil or not pet:isAlive() then
            return xi.msg.basic.NO_EFFECT_ON_PET, 0
        end
        return 0, 0 -- Requires no oil
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.repair.onUseAbility', function(player, target, ability)
    if isAnimist(player) then
        ability:setRecast(15)
        local pet = player:getPet()
        local healed = 0
        if pet ~= nil then
            healed = H.healEntity(player, pet, math.floor(pet:getMaxHP() * 0.50))
            H.restoreMpPct(pet, 50)
        end
        H.healPartyPct(player, 25, 15, false, false)
        ability:setMsg(xi.msg.basic.RECOVERS_HP)
        return healed
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (466-467)
-----------------------------------
m:addOverride('xi.actions.abilities.aether_overhaul.onAbilityCheck', function(player, _target, _ability)
    if not isAnimist(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.aether_overhaul.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 30, 15, true, true)
    H.forEachPartyMemberInRange(player, 15, true, function(unit)
        H.cleanseDebuffs(unit, 3)
    end)
    local pet = player.getPet and player:getPet() or nil
    if pet ~= nil and pet.resetRecasts then
        pet:resetRecasts()
    end
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.clockwork_aegis.onAbilityCheck', function(player, _target, _ability)
    if not isAnimist(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.clockwork_aegis.onUseAbility', function(player, _target, ability)
    local skinAmt = math.floor(player:getMaxHP() * 0.22)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyStoneskinBarrier(member, skinAmt, skinAmt * 2, 12, player)
        H.applyCustomTimedEffect(member, EFFECT_CLOCKWORK_AEGIS, 15, 12, player, 0, xi.effect.REPRISAL, 1)
        if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
            xi.overlords.slots.applyPartyWard(player, member, -1500, 0, 12, xi.effect.REPRISAL)
        end
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_CLOCKWORK_AEGIS
end)

-----------------------------------
-- Crystal Definition (PUP = 18)
-----------------------------------
if xi.job and xi.job.PUP then
    spec.registerCrystal(xi.job.PUP,
    {
        id          = 2,
        key         = ANIMIST_KEY,
        name        = 'Animist',
        abr         = 'ANM',
        role        = 'Healer',
        icon        = 'animist',
        reqLevel    = 10,
        extraTraits = { TRAIT_CLOCKWORK_MEDIC },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { ABIL_AETHER_OVERHAUL, ABIL_CLOCKWORK_AEGIS }
            end
            return {}
        end,
        description = 'Soul-forged Automaton Medic, Repair-Pulse & Overclock Shield Healer (Lv10+, H2H/Club): empowers Automaton White Magic to splash party-wide, eliminates Overload risk, and triggers Curaga + Stoneskin bursts on WSs.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% HP & MP, +10/16/22/28 MND/VIT/CHR, +18/26/34/42% Cure & Repair Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +4/6/8/12 MP/tick Refresh.',
            'Soul-Link Automaton Medic: Automaton gains +50% HP/MP, -35% DT, 100% Fast Cast; Automaton Cures/Regens splash party-wide (15y) and restore +5% MP to PUP.',
            'Clockwork Overdrive: 0% Overload risk; Maneuvers pulse 8% HP party heal; H2H/Club WSs fire an 18% HP AoE heal + 15% Max HP Stoneskin.',
            'JA Enhancements: Repair (15s CD, 0 oil: 50% Automaton HP/MP + 25% party HP) & Overdrive (Maneuvers trigger full party cleanse).',
            'Aether Overhaul (20s CD, 30% HP AoE heal + 3-debuff cleanse + Automaton reset) & Clockwork Aegis (25s CD, 12s 22% Stoneskin + -15% DT + +20 TP/t Regain).',
        },
        mods = function(_player, lvl)
            return
            {
                { xi.mod.HPP,              H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MPP,              H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MND,              H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.VIT,              H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CHR,              H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CURE_POTENCY,     H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.REPAIR_EFFECT,    H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.FASTCAST,         H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,           -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,          H.scaleTier(lvl, 4, 6, 8, 12) },
                { xi.mod.HTH,              H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.CLUB,             H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.AUTO_MELEE_SKILL, H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.AUTO_MAGIC_SKILL, H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.OVERLOAD_THRESH,  500 },
                { xi.mod.PREVENT_OVERLOAD, 1 },
            }
        end,
        onApply = function(player)
            attachAnimistListeners(player)
            syncAutomatonHealerMods(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_CLOCKWORK_AEGIS)
            end
            detachAnimistListeners(player)
        end,
    })
end

return m
