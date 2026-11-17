-----------------------------------
-- OverlordsXI Summoner Crystal Spec: Celestial (CEL | Tier-5 Pure Healer)
-- Unlocks @ Lv. 10 (!spec set celestial)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/summoner')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_smn_specs')

local spec = xi.overlords.spec
local CELESTIAL_KEY = 'celestial'

-- Custom Trait ID (173; Astral Sanctuary)
local TRAIT_ASTRAL_SANCTUARY = 173

-- Custom Ability IDs (464-465; recastIds 141, 145)
local ABIL_ASTRAL_BENEDICTION    = 464
local ABIL_CELESTIAL_CONVERGENCE = 465

-- Custom Status Effect IDs (869-870; registered in patch 0028)
local EFFECT_CELESTIAL_SANCTUARY   = 869
local EFFECT_CELESTIAL_CONVERGENCE = 870

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.ASTRAL_BENEDICTION    = ABIL_ASTRAL_BENEDICTION
xi.jobAbility.CELESTIAL_CONVERGENCE = ABIL_CELESTIAL_CONVERGENCE

xi.effect = xi.effect or {}
xi.effect.CELESTIAL_SANCTUARY   = EFFECT_CELESTIAL_SANCTUARY
xi.effect.CELESTIAL_CONVERGENCE = EFFECT_CELESTIAL_CONVERGENCE

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.astral_benediction    = xi.actions.abilities.astral_benediction or {}
xi.actions.abilities.celestial_convergence = xi.actions.abilities.celestial_convergence or {}

xi.effects = xi.effects or {}
xi.effects.celestial_sanctuary   = xi.effects.celestial_sanctuary or {}
xi.effects.celestial_convergence = xi.effects.celestial_convergence or {}

local function isCelestial(entity)
    return H.isSpecActive(entity, xi.job.SMN, CELESTIAL_KEY)
end

local CELESTIAL_WS_IDS =
{
    [183] = true, -- Spirit Taker
    [186] = true, -- Myrkr
    [185] = true, -- Garland of Bliss
    [163] = true, -- Starlight
    [164] = true, -- Moonlight
}

local function triggerStarlightMend(smn)
    if not isCelestial(smn) then
        return
    end
    local pet = smn.getPet and smn:getPet() or nil
    if pet ~= nil and pet:isAlive() then
        H.healEntity(smn, pet, math.floor(pet:getMaxHP() * 0.50))
    end
    H.healPartyPct(smn, 15, 15, true, true)
    if smn:hasStatusEffect(EFFECT_CELESTIAL_CONVERGENCE) then
        H.forEachPartyMemberInRange(smn, 15, false, function(member)
            H.restoreMpPct(member, 10)
        end)
    end
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.celestial_sanctuary.onEffectGain', function(target, effect)
    local lvl = effect:getSubPower() or 75
    effect:addMod(xi.mod.REGEN, H.scaleTier(lvl, 15, 22, 30, 38))
    effect:addMod(xi.mod.REFRESH, H.scaleTier(lvl, 4, 6, 8, 10))
    effect:addMod(xi.mod.DMG, -1000)
end)

m:addOverride('xi.effects.celestial_convergence.onEffectGain', function(target, effect)
    effect:addMod(xi.mod.DMG, -1800)
    effect:addMod(xi.mod.MEVA, 30)
end)

-----------------------------------
-- Listeners (Avatar Sanctuary Aura, Blood Pact: Ward, Staff/Club WS)
-----------------------------------
local function pulseSanctuaryAura(smn)
    if not isCelestial(smn) then
        return
    end
    local pet = smn.getPet and smn:getPet() or nil
    if pet == nil or not pet:isAlive() then
        return
    end
    local lvl = smn:getMainLvl()
    H.forEachPartyMemberInRange(smn, 15, false, function(member)
        if not member:hasStatusEffect(EFFECT_CELESTIAL_SANCTUARY) then
            H.applyCustomTimedEffect(member, EFFECT_CELESTIAL_SANCTUARY, 1, 6, smn, lvl, xi.effect.AVATARS_FAVOR, 1)
        end
    end)
end

local function attachCelestialListeners(player)
    if player == nil or player:getLocalVar('OX_CEL_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_CEL_LISTENERS', 1)

    player:addListener('COMBAT_TICK', 'OX_CEL_TICK', function(p)
        if isCelestial(p) then
            pulseSanctuaryAura(p)
        end
    end)

    player:addListener('PET_ABILITY', 'OX_CEL_WARD', function(pet, master)
        local smn = master or (pet and pet.getMaster and pet:getMaster())
        if isCelestial(smn) then
            triggerStarlightMend(smn)
            if smn:hasStatusEffect(xi.effect.ASTRAL_FLOW) then
                H.forEachPartyMemberInRange(smn, 15, false, function(member)
                    local skin = math.floor(member:getMaxHP() * 0.25)
                    H.applyStoneskinBarrier(member, skin, skin * 2, 15, smn)
                end)
            end
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_CEL_WS', function(caster, _target, ws)
        if isCelestial(caster) and H.isWeaponSkillInSet(ws, CELESTIAL_WS_IDS, { [xi.skill.STAFF] = true, [xi.skill.CLUB] = true }) then
            triggerStarlightMend(caster)
        end
    end)
end

local function detachCelestialListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_CEL_LISTENERS', 0)
    player:removeListener('OX_CEL_TICK')
    player:removeListener('OX_CEL_WARD')
    player:removeListener('OX_CEL_WS')
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.blood_pact_ward.onAbilityCheck', function(player, target, ability)
    local res, msg = super(player, target, ability)
    if res == 0 and isCelestial(player) then
        local cd = player:hasStatusEffect(xi.effect.ASTRAL_FLOW) and 5 or (player:hasStatusEffect(xi.effect.APOGEE) and 6 or 12)
        ability:setRecast(cd)
    end
    return res, msg
end)

m:addOverride('xi.actions.abilities.elemental_siphon.onUseAbility', function(player, target, ability)
    if isCelestial(player) then
        ability:setRecast(20)
        local mpAmt = H.restoreMpPct(player, 45)
        H.healPartyPct(player, 20, 15, true, true)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_MP)
        return mpAmt
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (464-465)
-----------------------------------
m:addOverride('xi.actions.abilities.astral_benediction.onAbilityCheck', function(player, _target, _ability)
    if not isCelestial(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.astral_benediction.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 32, 15, true, true)
    H.forEachPartyMemberInRange(player, 15, true, function(unit)
        H.cleanseDebuffs(unit, 3)
        if unit.isPC and unit:isPC() then
            unit:addStatusEffect(xi.effect.RERAISE, { power = 3, duration = 300, origin = player })
        end
    end)
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.celestial_convergence.onAbilityCheck', function(player, _target, _ability)
    if not isCelestial(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.celestial_convergence.onUseAbility', function(player, _target, ability)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyCustomTimedEffect(member, EFFECT_CELESTIAL_CONVERGENCE, 18, 12, player, 0, xi.effect.ASTRAL_FLOW, 1)
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_CELESTIAL_CONVERGENCE
end)

-----------------------------------
-- Crystal Definition (SMN = 15)
-----------------------------------
if xi.job and xi.job.SMN then
    spec.registerCrystal(xi.job.SMN,
    {
        id          = 2,
        key         = CELESTIAL_KEY,
        name        = 'Celestial',
        abr         = 'CEL',
        role        = 'Healer',
        icon        = 'celestial',
        reqLevel    = 10,
        extraTraits = { TRAIT_ASTRAL_SANCTUARY },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { ABIL_ASTRAL_BENEDICTION, ABIL_CELESTIAL_CONVERGENCE }
            end
            return {}
        end,
        description = 'Astral Avatar Conduit, Sanctuary & Ward-Reset Healer (Lv10+): projects a 15y Celestial Sanctuary aura from your Avatar, resets Blood Pact: Ward to 12s (6s in Apogee / 5s in Astral Flow), and pulses Starlight Mend on Wards and WSs.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% HP & MP, +12/18/24/32 MND & CHR, +18/26/34/42% Cure & Ward Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +5/8/11/15 MP/tick Refresh, -100% Avatar Perpetuation.',
            'Astral Avatar Resonance: Summoned Avatar projects Celestial Sanctuary (15y): +15/22/30/38 HP/t Regen, +4/6/8/10 MP/t Refresh, -10% DT.',
            'Ward-Loop & Starlight Mend: Blood Pact: Ward has a flat 12s recast (6s Apogee); Wards and Staff/Club WSs heal Avatar 50% HP and pulse 15% Max HP party heal.',
            'JA Enhancements: Elemental Siphon (20s CD, 45% MP without dismissing Avatar + 20% AoE heal) & Astral Flow (5s Ward CD, 25% Stoneskin).',
            'Astral Benediction (22s CD, 32% HP AoE heal + 3-debuff cleanse + Reraise III) & Celestial Convergence (25s CD, 12s -18% DT + +30 MEVA + 10% MP per Ward/WS).',
        },
        mods = function(_player, lvl)
            return
            {
                { xi.mod.HPP,               H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MPP,               H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MND,               H.scaleTier(lvl, 12, 18, 24, 32) },
                { xi.mod.CHR,               H.scaleTier(lvl, 12, 18, 24, 32) },
                { xi.mod.CURE_POTENCY,      H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.FASTCAST,          H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,            -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,           H.scaleTier(lvl, 5, 8, 11, 15) },
                { xi.mod.AVATAR_PERPETUATION, -100 },
                { xi.mod.SUMMONING,         H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.HEALING,           H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.STAFF,             H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.CLUB,              H.scaleTier(lvl, 15, 25, 35, 50) },
            }
        end,
        onApply = function(player)
            attachCelestialListeners(player)
            pulseSanctuaryAura(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_CELESTIAL_SANCTUARY)
                player:delStatusEffectSilent(EFFECT_CELESTIAL_CONVERGENCE)
            end
            detachCelestialListeners(player)
        end,
    })
end

return m
