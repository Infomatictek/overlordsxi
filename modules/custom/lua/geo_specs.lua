-----------------------------------
-- OverlordsXI Geomancer Crystal Spec: Verdant (VRD | Tier-5 Pure Healer)
-- Unlocks @ Lv. 10 (!spec set verdant)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/geomancer')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_geo_specs')

local spec = xi.overlords.spec
local VERDANT_KEY = 'verdant'

-- Custom Trait ID (175; Sylvan Bloom)
local TRAIT_SYLVAN_BLOOM = 175

-- Custom Ability IDs (468-469; recastIds 164-165)
local ABIL_VERDANT_RENEWAL        = 468
local ABIL_CANOPY_OF_THE_ANCIENTS = 469

-- Custom Status Effect IDs (872-873; registered in patch 0028)
local EFFECT_BARKSKIN               = 872
local EFFECT_CANOPY_OF_THE_ANCIENTS = 873

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.VERDANT_RENEWAL        = ABIL_VERDANT_RENEWAL
xi.jobAbility.CANOPY_OF_THE_ANCIENTS = ABIL_CANOPY_OF_THE_ANCIENTS

xi.effect = xi.effect or {}
xi.effect.BARKSKIN               = EFFECT_BARKSKIN
xi.effect.CANOPY_OF_THE_ANCIENTS = EFFECT_CANOPY_OF_THE_ANCIENTS

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.verdant_renewal        = xi.actions.abilities.verdant_renewal or {}
xi.actions.abilities.canopy_of_the_ancients = xi.actions.abilities.canopy_of_the_ancients or {}

xi.effects = xi.effects or {}
xi.effects.barkskin               = xi.effects.barkskin or {}
xi.effects.canopy_of_the_ancients = xi.effects.canopy_of_the_ancients or {}

local function isVerdant(entity)
    return H.isSpecActive(entity, xi.job.GEO, VERDANT_KEY)
end

local VERDANT_WS_IDS =
{
    [175] = true, -- Exudation
    [169] = true, -- Black Halo
    [164] = true, -- Moonlight
    [170] = true, -- Hexa Strike
    [190] = true, -- Shattersoul
}

local function triggerVerdantBloom(geo)
    if not isVerdant(geo) then
        return
    end
    local pet = geo.getPet and geo:getPet() or nil
    if pet == nil or not pet:isAlive() then
        return
    end
    local pct = H.scaleTier(geo:getMainLvl(), 6, 8, 10, 12)
    if geo:hasStatusEffect(xi.effect.BOLSTER) then
        pct = pct * 2
    end
    local healAmt = math.floor(geo:getMaxHP() * (pct / 100))
    H.forEachPartyMemberInRange(geo, 15, false, function(member)
        local _, overheal = H.healEntity(geo, member, healAmt)
        if member.addMP then
            member:addMP(15)
        end
        if overheal > 0 then
            local cap = math.floor(member:getMaxHP() * 0.25)
            H.applyStoneskinBarrier(member, overheal, cap, 15, geo)
        end
    end)
end

local function triggerNaturesSurge(geo)
    if not isVerdant(geo) then
        return
    end
    local pet = geo.getPet and geo:getPet() or nil
    if pet ~= nil and pet:isAlive() then
        pet:setHP(pet:getMaxHP())
    end
    H.healPartyPct(geo, 16, 15, false, false)
    H.forEachPartyMemberInRange(geo, 15, false, function(member)
        H.cleanseDebuffs(member, 1)
    end)
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.canopy_of_the_ancients.onEffectGain', function(target, effect)
    effect:addMod(xi.mod.DMG, -1800)
    effect:addMod(xi.mod.KNOCKBACK_IMMUNE, 1)
end)

-----------------------------------
-- Listeners (Verdant Bloom 3s Pulse, Sylvan Resonance)
-----------------------------------
local function attachVerdantListeners(player)
    if player == nil or player:getLocalVar('OX_VRD_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_VRD_LISTENERS', 1)

    player:addListener('COMBAT_TICK', 'OX_VRD_TICK', function(p)
        if not isVerdant(p) then
            return
        end
        local now = os.time()
        local last = p:getLocalVar('OX_VRD_BLOOM_TS')
        if now - last >= 3 then
            p:setLocalVar('OX_VRD_BLOOM_TS', now)
            triggerVerdantBloom(p)
        end
    end)

    player:addListener('MAGIC_USE', 'OX_VRD_MAGIC', function(caster, _target, spell)
        if not isVerdant(caster) or spell == nil then
            return
        end
        local sf = spell:getSpellFamily()
        if sf == xi.magic.spellFamily.CURE or sf == xi.magic.spellFamily.INDI or sf == xi.magic.spellFamily.GEO then
            triggerNaturesSurge(caster)
        end
        if caster:hasStatusEffect(EFFECT_CANOPY_OF_THE_ANCIENTS) then
            H.healPartyPct(caster, 10, 15, false, false)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_VRD_WS', function(caster, _target, ws)
        if not isVerdant(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, VERDANT_WS_IDS, { [xi.skill.CLUB] = true, [xi.skill.STAFF] = true }) then
            triggerNaturesSurge(caster)
            if caster:hasStatusEffect(EFFECT_CANOPY_OF_THE_ANCIENTS) then
                H.healPartyPct(caster, 10, 15, false, false)
            end
        end
    end)
end

local function detachVerdantListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_VRD_LISTENERS', 0)
    player:removeListener('OX_VRD_TICK')
    player:removeListener('OX_VRD_MAGIC')
    player:removeListener('OX_VRD_WS')
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.life_cycle.onUseAbility', function(player, target, ability)
    if isVerdant(player) then
        ability:setRecast(15)
        local pet = player:getPet()
        if pet ~= nil then
            pet:setHP(pet:getMaxHP())
        end
        local total = H.healPartyPct(player, 25, 15, false, false)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
        return total
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (468-469)
-----------------------------------
m:addOverride('xi.actions.abilities.verdant_renewal.onAbilityCheck', function(player, _target, _ability)
    if not isVerdant(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.verdant_renewal.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 30, 15, false, false)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.cleanseDebuffs(member, 3)
        if xi.overlords and xi.overlords.regen and xi.overlords.regen.applyHybridRegen then
            xi.overlords.regen.applyHybridRegen(player, member, xi.effect.REGEN, 25, 350, 15, 3, 3)
        else
            member:addStatusEffect(xi.effect.REGEN, { power = 25, duration = 15, origin = player, tier = 3 })
        end
        member:addStatusEffect(xi.effect.REFRESH, { power = 8,  duration = 15, origin = player, tier = 3 })
    end)
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.canopy_of_the_ancients.onAbilityCheck', function(player, _target, _ability)
    if not isVerdant(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.canopy_of_the_ancients.onUseAbility', function(player, _target, ability)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyCustomTimedEffect(member, EFFECT_CANOPY_OF_THE_ANCIENTS, 18, 12, player, 0, xi.effect.BOLSTER, 1)
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_CANOPY_OF_THE_ANCIENTS
end)

-----------------------------------
-- Crystal Definition (GEO = 21)
-----------------------------------
if xi.job and xi.job.GEO then
    spec.registerCrystal(xi.job.GEO,
    {
        id          = 2,
        key         = VERDANT_KEY,
        name        = 'Verdant',
        abr         = 'VRD',
        role        = 'Healer',
        icon        = 'verdant',
        reqLevel    = 10,
        extraTraits = { TRAIT_SYLVAN_BLOOM },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { ABIL_VERDANT_RENEWAL, ABIL_CANOPY_OF_THE_ANCIENTS }
            end
            return {}
        end,
        description = 'Sylvan Luopan Sanctuary, Living Earth-Pulse & Nature\'s Renewal Healer (Lv10+): pulses 3s Verdant Bloom heals + MP + Barkskin from your Luopan, and triggers Nature\'s Surge on Indicolure/Geocolure/Cure/Club/Staff WSs.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% HP & MP, +12/18/24/32 MND & VIT, +18/26/34/42% Cure & Geomancy Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +4/6/8/12 MP/tick Refresh, -50% Luopan Drain.',
            'Living Luopan Sanctuary: Luopan pulses Verdant Bloom every 3s (15y): 6/8/10/12% Max HP heal, +15 MP, and overheal Barkskin Stoneskin (cap 25% Max HP).',
            'Sylvan Resonance: Indi/Geo/Cure or Club/Staff WS heals Luopan to 100% HP and triggers Nature\'s Surge (16% Max HP party heal + 1-debuff cleanse).',
            'JA Enhancements: Life Cycle (15s CD, 0 self-HP loss + 25% party heal) & Bolster (doubles Verdant Bloom).',
            'Verdant Renewal (20s CD, 30% HP AoE heal + 3-debuff cleanse + 25 + 3.5% Max HP/t Regen + 8/t Refresh 15s) & Canopy of the Ancients (25s CD, 12s -18% DT + Knockback Immune + 10% AoE heal per spell/WS).',
        },
        mods = function(_player, lvl)
            return
            {
                { xi.mod.HPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MND,          H.scaleTier(lvl, 12, 18, 24, 32) },
                { xi.mod.VIT,          H.scaleTier(lvl, 12, 18, 24, 32) },
                { xi.mod.CURE_POTENCY, H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.FASTCAST,     H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,       -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,      H.scaleTier(lvl, 4, 6, 8, 12) },
                { xi.mod.GEOMANCY,     H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.HANDBELL,     H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.HEALING,      H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.CLUB,         H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.STAFF,        H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.REGEN,        H.scaleTier(lvl, 2, 4, 6, 8) },
            }
        end,
        onApply = function(player)
            attachVerdantListeners(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_BARKSKIN)
                player:delStatusEffectSilent(EFFECT_CANOPY_OF_THE_ANCIENTS)
            end
            detachVerdantListeners(player)
        end,
    })
end

return m
