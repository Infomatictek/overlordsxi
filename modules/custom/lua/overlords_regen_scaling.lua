-----------------------------------
-- OverlordsXI Global Hybrid Regen Scaling (Static Flat + % Target Max HP)
-- Centralizes hybrid Regen scaling across spells, songs, Geomancy,
-- WS talent buffs, and Soul Crystal abilities/auras.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/spells/enhancing_spell')
require('scripts/globals/spells/enhancing_song')
require('scripts/effects/regen')
require('scripts/effects/paeon')
require('scripts/effects/geo_regen')
-----------------------------------
local m = Module:new('overlords_regen_scaling')

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.regen = xi.overlords.regen or {}

local R = xi.overlords.regen

R.TIER1_PURE_DPS_KEYS =
{
    berserker      = true,
    blackbelt      = true,
    zealot         = true,
    astromancer    = true,
    scarletweaver  = true,
    bandit         = true,
    oathbreaker    = true,
    reaper         = true,
    adventurer     = true,
    sniper         = true,
    imperialarcher = true,
    kurogane       = true,
    lancer         = true,
    warmage        = true,
    flintlock      = true,
    bladewheel     = true,
    sage           = true,
    untamed        = true,
    primalist      = true,
    pugilist       = true,
    spellblade     = true,
    terramancer    = true,
}

local REGEN_SPELL_TABLE =
{
    [xi.magic.spell.REGEN]     = { flat = 8,  pctBp = 120 }, -- 8 flat + 1.2% Max HP
    [xi.magic.spell.REGEN_II]  = { flat = 14, pctBp = 180 }, -- 14 flat + 1.8% Max HP
    [xi.magic.spell.REGEN_III] = { flat = 22, pctBp = 240 }, -- 22 flat + 2.4% Max HP
    [xi.magic.spell.REGEN_IV]  = { flat = 30, pctBp = 300 }, -- 30 flat + 3.0% Max HP
    [xi.magic.spell.REGEN_V]   = { flat = 40, pctBp = 360 }, -- 40 flat + 3.6% Max HP
}

local LIGHT_ARTS_BONUS_BP = 40 -- +0.4% Target Max HP

local PAEON_PCT_TABLE =
{
    [xi.magic.spell.ARMYS_PAEON]     = 40,  -- 0.4%
    [xi.magic.spell.ARMYS_PAEON_II]  = 60,  -- 0.6%
    [xi.magic.spell.ARMYS_PAEON_III] = 90,  -- 0.9%
    [xi.magic.spell.ARMYS_PAEON_IV]  = 120, -- 1.2%
    [xi.magic.spell.ARMYS_PAEON_V]   = 140, -- 1.4%
    [xi.magic.spell.ARMYS_PAEON_VI]  = 160, -- 1.6%
}

local PAEON_TIER_BP = { 40, 60, 90, 120, 140, 160 }

function R.isTier1PureDps(entity)
    if entity == nil or not entity.isPC or not entity:isPC() then
        return false
    end

    if xi.overlords and xi.overlords.spec and xi.overlords.spec.ensureUpToDate then
        local active = xi.overlords.spec.ensureUpToDate(entity)
        return active ~= nil and active.key ~= nil and R.TIER1_PURE_DPS_KEYS[active.key] == true
    end

    return false
end

function R.isSelfPureDpsCast(caster, target)
    if target == nil or not R.isTier1PureDps(target) then
        return false
    end

    if caster == nil or caster == target then
        return true
    end

    if caster.getID and target.getID and caster:getID() == target:getID() then
        return true
    end

    return false
end

function R.getCasterCurePotency(caster)
    if caster == nil or not caster.getMod then
        return 0
    end

    return math.max(0, caster:getMod(xi.mod.CURE_POTENCY) or 0)
end

function R.computePctBonus(target, maxHpPctBp, casterCurePotency, isSelfPureDps)
    if isSelfPureDps or target == nil or not target.getMaxHP then
        return 0
    end

    local bp = math.max(0, math.floor(maxHpPctBp or 0))
    if bp <= 0 then
        return 0
    end

    local maxHp = math.max(0, target:getMaxHP() or 0)
    if maxHp <= 0 then
        return 0
    end

    local curePot = math.max(0, tonumber(casterCurePotency) or 0)
    local cureMult = 1.0 + math.min(0.50, curePot / 100.0)
    return math.floor((maxHp * bp / 10000.0) * cureMult)
end

function R.computeHybridTick(caster, target, flatPower, maxHpPctBp)
    local flat = math.max(0, math.floor(flatPower or 0))
    local pctBonus = R.computePctBonus(
        target,
        maxHpPctBp,
        R.getCasterCurePotency(caster),
        R.isSelfPureDpsCast(caster, target)
    )
    return flat + pctBonus, flat, pctBonus
end

function R.stampRegenContext(caster, target, maxHpPctBp)
    if target == nil or not target.setLocalVar then
        return
    end

    local selfPure = R.isSelfPureDpsCast(caster, target) and 1 or 0
    local curePot  = R.getCasterCurePotency(caster)
    local bp       = math.max(0, math.floor(maxHpPctBp or 0))

    target:setLocalVar('[OX_Regen]PctBp', bp)
    target:setLocalVar('[OX_Regen]CurePot', curePot)
    target:setLocalVar('[OX_Regen]SelfPureDps', selfPure)
end

function R.clearRegenContext(target)
    if target == nil or not target.setLocalVar then
        return
    end

    target:setLocalVar('[OX_Regen]PctBp', 0)
    target:setLocalVar('[OX_Regen]CurePot', 0)
    target:setLocalVar('[OX_Regen]SelfPureDps', 0)
end

local function readAndClearContext(target)
    if target == nil or not target.getLocalVar then
        return 0, 0, false
    end

    local pctBp    = target:getLocalVar('[OX_Regen]PctBp') or 0
    local curePot  = target:getLocalVar('[OX_Regen]CurePot') or 0
    local selfPure = (target:getLocalVar('[OX_Regen]SelfPureDps') or 0) == 1
    R.clearRegenContext(target)
    return pctBp, curePot, selfPure
end

function R.consumeEffectRegen(target, effect, defaultFlat, defaultPctBp)
    local flat = (effect and effect.getPower and effect:getPower()) or 0
    if flat <= 0 then
        flat = math.max(0, math.floor(defaultFlat or 0))
    end

    local pctBp, curePot, selfPure = readAndClearContext(target)
    if pctBp <= 0 and (defaultPctBp or 0) > 0 then
        pctBp = defaultPctBp
        if not selfPure and target ~= nil and R.isTier1PureDps(target) then
            selfPure = true
        end
    end

    local pctBonus = R.computePctBonus(target, pctBp, curePot, selfPure)
    return flat + pctBonus, flat, pctBonus
end

function R.applyHybridRegen(caster, target, effectId, flatPower, maxHpPctBp, duration, tick, tier)
    if target == nil or not target.addStatusEffect then
        return false
    end

    local effId = effectId or xi.effect.REGEN
    R.stampRegenContext(caster, target, maxHpPctBp)
    local applied = target:addStatusEffect(effId,
    {
        power    = math.max(1, math.floor(flatPower or 1)),
        duration = duration or 60,
        origin   = caster or target,
        tick     = tick or 3,
        tier     = tier or 1,
    })
    R.clearRegenContext(target)
    return applied
end

-----------------------------------
-- 1. White Magic & Scholar Regen I-V
-----------------------------------
m:addOverride('xi.spells.enhancing.calculateEnhancingBasePower', function(caster, target, spell, spellId, spellEffect)
    if spellEffect == xi.effect.REGEN then
        local cfg = REGEN_SPELL_TABLE[spellId]
        if cfg ~= nil then
            return cfg.flat
        end
    end

    return super(caster, target, spell, spellId, spellEffect)
end)

m:addOverride('xi.spells.enhancing.useEnhancingSpell', function(caster, target, spell)
    local spellId = spell and spell.getID and spell:getID() or 0
    local cfg = REGEN_SPELL_TABLE[spellId]
    if cfg ~= nil and target ~= nil then
        local pctBp = cfg.pctBp
        if caster ~= nil and caster.hasStatusEffect then
            if caster:hasStatusEffect(xi.effect.LIGHT_ARTS) or caster:hasStatusEffect(xi.effect.ADDENDUM_WHITE) then
                pctBp = pctBp + LIGHT_ARTS_BONUS_BP
            end
        end

        R.stampRegenContext(caster, target, pctBp)
        local res = super(caster, target, spell)
        R.clearRegenContext(target)
        return res
    end

    return super(caster, target, spell)
end)

m:addOverride('xi.effects.regen.onEffectGain', function(target, effect)
    local flatPower = effect:getPower() or 0
    local pctBp, curePot, selfPure = readAndClearContext(target)

    local tier = effect:getTier() or 0
    local pctBonus = 0
    if pctBp > 0 then
        pctBonus = R.computePctBonus(target, pctBp, curePot, selfPure)
    elseif tier == 0 then
        -- Consumables (drinks/foods) with no stamped PctBp receive 0% Max HP bonus
        pctBonus = 0
    end

    effect:setSubPower(pctBonus)
    target:addMod(xi.mod.REGEN, flatPower + pctBonus)
end)

m:addOverride('xi.effects.regen.onEffectLose', function(target, effect)
    local flatPower = effect:getPower() or 0
    local pctBonus  = effect:getSubPower() or 0
    target:delMod(xi.mod.REGEN, flatPower + pctBonus)
end)

-----------------------------------
-- 2. Bard Army's Paeon I-VI
-----------------------------------
m:addOverride('xi.spells.enhancing.useEnhancingSong', function(caster, target, spell)
    local spellId = spell and spell.getID and spell:getID() or 0
    local pctBp   = PAEON_PCT_TABLE[spellId]
    if pctBp ~= nil and target ~= nil then
        R.stampRegenContext(caster, target, pctBp)
        local res = super(caster, target, spell)
        R.clearRegenContext(target)
        return res
    end

    return super(caster, target, spell)
end)

local function getPaeonVarKey(effect)
    return string.format('[OX_Regen]Paeon_%d_%d', effect:getTier() or 0, effect:getPower() or 0)
end

m:addOverride('xi.effects.paeon.onEffectGain', function(target, effect)
    local flatPower = effect:getPower() or 0
    local pctBp, curePot, selfPure = readAndClearContext(target)
    if pctBp <= 0 then
        local tier = effect:getTier() or 0
        pctBp = PAEON_TIER_BP[tier] or 0
    end

    local pctBonus = R.computePctBonus(target, pctBp, curePot, selfPure)
    if target.setLocalVar then
        target:setLocalVar(getPaeonVarKey(effect), pctBonus)
    end

    target:addMod(xi.mod.REGEN, flatPower + pctBonus)
    target:addMod(xi.mod.CHR, effect:getSubPower() or 0)
end)

m:addOverride('xi.effects.paeon.onEffectLose', function(target, effect)
    local flatPower = effect:getPower() or 0
    local varKey    = getPaeonVarKey(effect)
    local pctBonus  = (target.getLocalVar and target:getLocalVar(varKey)) or 0
    if target.setLocalVar then
        target:setLocalVar(varKey, 0)
    end

    target:delMod(xi.mod.REGEN, flatPower + pctBonus)
    target:delMod(xi.mod.CHR, effect:getSubPower() or 0)
end)

-----------------------------------
-- 3. Geomancer Indi-Regen & Geo-Regen
-----------------------------------
local function findGeoRegenSource(target)
    if target == nil then
        return nil, false
    end

    local owner = target
    if (not target.isPC or not target:isPC()) and target.getMaster then
        owner = target:getMaster() or target
    end

    local party = (owner.getPartyWithTrusts and owner:getPartyWithTrusts())
        or (owner.getParty and owner:getParty())
        or { owner }

    for _, member in ipairs(party) do
        if member ~= nil then
            local hasGeoRegenColure = false
            if member.hasStatusEffect and member:hasStatusEffect(xi.effect.COLURE_ACTIVE) then
                local colure = member:getStatusEffect(xi.effect.COLURE_ACTIVE)
                if colure ~= nil and colure:getSubType() == xi.effect.GEO_REGEN then
                    hasGeoRegenColure = true
                end
            end

            if not hasGeoRegenColure and member.getPet then
                local pet = member:getPet()
                if pet ~= nil and pet.hasStatusEffect and pet:hasStatusEffect(xi.effect.COLURE_ACTIVE) then
                    local colure = pet:getStatusEffect(xi.effect.COLURE_ACTIVE)
                    if colure ~= nil and colure:getSubType() == xi.effect.GEO_REGEN then
                        hasGeoRegenColure = true
                    end
                end
            end

            if hasGeoRegenColure then
                local isBolstered = member.hasStatusEffect and member:hasStatusEffect(xi.effect.BOLSTER) or false
                return member, isBolstered
            end
        end
    end

    return nil, false
end

m:addOverride('xi.effects.geo_regen.onEffectGain', function(target, effect)
    local flatPower = effect:getPower() or 0
    local geoCaster, isBolstered = findGeoRegenSource(target)
    local pctBp = isBolstered and 400 or 200 -- 2.0% normal, 4.0% during Bolster
    local pctBonus = R.computePctBonus(
        target,
        pctBp,
        R.getCasterCurePotency(geoCaster),
        R.isSelfPureDpsCast(geoCaster, target)
    )

    effect:setSubPower(pctBonus)
    target:addMod(xi.mod.REGEN, flatPower + pctBonus)
end)

m:addOverride('xi.effects.geo_regen.onEffectLose', function(target, effect)
    local flatPower = effect:getPower() or 0
    local pctBonus  = effect:getSubPower() or 0
    target:delMod(xi.mod.REGEN, flatPower + pctBonus)
end)

return m
