-----------------------------------
-- SoulspireXI Scholar Specs
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/combat/basic/magic_aoe')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/globals/spells/damage_spell')
require('scripts/globals/spells/enfeebling_spell')
-----------------------------------
local m = Module:new('soulspire_sch_specs')

local medicSpecKey = 'medic'
local sageSpecKey = 'sage'
local stanceDuration = 7200
local sageHelixDuration = 7200

local helixSpellIds =
{
    [xi.magic.spell.GEOHELIX] = true,
    [xi.magic.spell.HYDROHELIX] = true,
    [xi.magic.spell.ANEMOHELIX] = true,
    [xi.magic.spell.PYROHELIX] = true,
    [xi.magic.spell.CRYOHELIX] = true,
    [xi.magic.spell.IONOHELIX] = true,
    [xi.magic.spell.NOCTOHELIX] = true,
    [xi.magic.spell.LUMINOHELIX] = true,
    [xi.magic.spell.GEOHELIX_II] = true,
    [xi.magic.spell.HYDROHELIX_II] = true,
    [xi.magic.spell.ANEMOHELIX_II] = true,
    [xi.magic.spell.PYROHELIX_II] = true,
    [xi.magic.spell.CRYOHELIX_II] = true,
    [xi.magic.spell.IONOHELIX_II] = true,
    [xi.magic.spell.NOCTOHELIX_II] = true,
    [xi.magic.spell.LUMINOHELIX_II] = true,
}

local function isScholarSpec(entity, specKey)
    if entity == nil or not entity:isPC() or entity:getMainJob() ~= xi.job.SCH then
        return false
    end

    xi.soulspire.spec.ensureUpToDate(entity)
    return xi.soulspire.spec.is(entity, xi.job.SCH, specKey)
end

local schJob = xi.soulspire.spec.jobs[xi.job.SCH]
if schJob and schJob.byKey then
    if schJob.byKey[medicSpecKey] then
        schJob.byKey[medicSpecKey].onRemove = function(player)
            if player ~= nil and player.hasPet and player:hasPet() then
                local pet = player:getPet()
                if pet ~= nil and pet:getPetID() == 128 and player.despawnPet then
                    player:despawnPet()
                end
            end
        end
    end

    if schJob.byKey[sageSpecKey] then
        schJob.byKey[sageSpecKey].onRemove = function(player)
            if player ~= nil and player.hasPet and player:hasPet() then
                local pet = player:getPet()
                if pet ~= nil and pet:getPetID() == 129 and player.despawnPet then
                    player:despawnPet()
                end
            end
        end
    end
end

local function rememberTitaniaTarget(caster, target)
    if
        caster ~= nil and
        target ~= nil and
        caster.isPC and
        caster:isPC() and
        target.isMob and
        target:isMob() and
        target.getTargID and
        caster.setLocalVar
    then
        caster:setLocalVar('OX_TITANIA_TARGET', target:getTargID())
    end
end

local function isMedic(entity)
    return isScholarSpec(entity, medicSpecKey)
end

local function isSage(entity)
    return isScholarSpec(entity, sageSpecKey)
end

local function isCureOrRegenSpell(spell)
    local spellFamily = spell:getSpellFamily()
    return
        spellFamily == xi.magic.spellFamily.CURE or
        spellFamily == xi.magic.spellFamily.REGEN
end

local function extendEffectDuration(target, effectId, duration)
    local effect = target:getStatusEffect(effectId)
    if effect ~= nil then
        effect:setDuration(duration * 1000)
    end
end

local function ensureSageEbullience(caster)
    if not isSage(caster) then
        return
    end

    if not caster:hasStatusEffect(xi.effect.EBULLIENCE) then
        caster:addStatusEffect(xi.effect.EBULLIENCE, { power = 1, duration = stanceDuration, origin = caster, silent = true })
    else
        extendEffectDuration(caster, xi.effect.EBULLIENCE, stanceDuration)
    end
end

local function calculateSageMevaBypass(target, actionElement)
    if target == nil or actionElement == nil or actionElement <= xi.element.NONE then
        return 0
    end

    local targetMeva = target:getMod(xi.mod.MEVA) + target:getMod(xi.data.element.getElementalMEVAModifier(actionElement))
    return math.max(0, math.floor(targetMeva * 0.10))
end

m:addOverride('xi.actions.abilities.addendum_white.onUseAbility', function(player, target, ability)
    local result = super(player, target, ability)

    if isMedic(player) then
        extendEffectDuration(player, xi.effect.ADDENDUM_WHITE, stanceDuration)
    end

    return result
end)

m:addOverride('xi.actions.abilities.addendum_black.onUseAbility', function(player, target, ability)
    local result = super(player, target, ability)

    if isSage(player) then
        extendEffectDuration(player, xi.effect.ADDENDUM_BLACK, stanceDuration)
        ensureSageEbullience(player)
    end

    return result
end)

m:addOverride('xi.actions.abilities.ebullience.onAbilityCheck', function(player, target, ability)
    if isSage(player) then
        ensureSageEbullience(player)
        return xi.msg.basic.EFFECT_ALREADY_ACTIVE, 0
    end

    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.ebullience.onUseAbility', function(player, target, ability)
    if isSage(player) then
        ensureSageEbullience(player)
        return xi.effect.EBULLIENCE
    end

    return super(player, target, ability)
end)

m:addOverride('xi.combat.magicAoE.calculateTypeAndRadius', function(caster, spell)
    if
        isMedic(caster) and
        spell:getAoE() == xi.magic.aoe.RADIAL_ACCE and
        isCureOrRegenSpell(spell)
    then
        return { xi.magic.aoe.RADIAL, 10 }
    end

    return super(caster, spell)
end)

m:addOverride('xi.effects.sublimation_activated.onEffectTick', function(target, effect)
    if not isMedic(target) then
        return super(target, effect)
    end

    local level = target:getMainLvl()
    local baseMp = math.max(0, math.floor((level - 15) / 10))
    local bonus = target:getMod(xi.mod.SUBLIMATION_BONUS)
    local store = effect:getPower() + (baseMp + bonus) * 2
    local limit = math.floor((target:getBaseHP() + target:getMod(xi.mod.HP) + target:getMerit(xi.merit.MAX_HP)) / 2) +
        target:getMerit(xi.merit.MAX_SUBLIMATION) * 10 + target:getJobPointLevel(xi.jp.SUBLIMATION_EFFECT) * 3

    if store >= limit then
        target:delStatusEffectSilent(xi.effect.SUBLIMATION_ACTIVATED)
        target:addStatusEffect(xi.effect.SUBLIMATION_COMPLETE, { power = limit, duration = stanceDuration, origin = target })
    else
        effect:setPower(store)
    end
end)

m:addOverride('xi.spells.damage.calculateMagicBonusDiff', function(caster, target, spellId, skillType, spellElement, bonusMATT)
    local adjustedBonusMATT = bonusMATT or 0

    if isSage(caster) then
        rememberTitaniaTarget(caster, target)
        adjustedBonusMATT = adjustedBonusMATT + 30
    end

    return super(caster, target, spellId, skillType, spellElement, adjustedBonusMATT)
end)

m:addOverride('xi.spells.damage.calculateEbullienceMultiplier', function(caster, spellGroup)
    if isSage(caster) and spellGroup == xi.magic.spellGroup.BLACK then
        ensureSageEbullience(caster)
        return 1.2 + caster:getMod(xi.mod.EBULLIENCE_AMOUNT) / 100
    end

    return super(caster, spellGroup)
end)

m:addOverride('xi.spells.damage.calculateHelixMeritMultiplier', function(caster, spellId)
    local multiplier = super(caster, spellId)

    if isSage(caster) and helixSpellIds[spellId] then
        multiplier = multiplier * 1.5
    end

    return multiplier
end)

m:addOverride('xi.spells.enfeebling.calculateDuration', function(caster, target, spellId, spellEffect, skillType)
    local duration = super(caster, target, spellId, spellEffect, skillType)

    if isSage(caster) then
        rememberTitaniaTarget(caster, target)
        if spellEffect == xi.effect.HELIX and helixSpellIds[spellId] then
            return math.max(duration, sageHelixDuration)
        end
    end

    return duration
end)

m:addOverride('xi.combat.magicHitRate.calculateResistRate', function(actor, target, fedData)
    if type(fedData) == 'table' and isSage(actor) then
        rememberTitaniaTarget(actor, target)
        if fedData.skillType == xi.skill.ELEMENTAL_MAGIC then
            local bypass = calculateSageMevaBypass(target, fedData.magicalElement)
            if bypass > 0 then
                local adjustedFedData = {}
                for k, v in pairs(fedData) do
                    adjustedFedData[k] = v
                end
                adjustedFedData.bonusMacc = (adjustedFedData.bonusMacc or 0) + bypass
                return super(actor, target, adjustedFedData)
            end
        end
    end

    return super(actor, target, fedData)
end)

return m
