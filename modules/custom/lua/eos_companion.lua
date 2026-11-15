-----------------------------------
-- Eos & Titania Faerie Companions
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/pets')
-----------------------------------
local m = Module:new('eos_companion')

local eosAbilityId      = 231
local eosPetId          = 128
local titaniaAbilityId  = 289
local titaniaPetId      = 129
local eosRegenEffectId  = 789
local eosRefreshModId   = 1198
local eosRequiredSpec   = 'medic'
local titaniaReqSpec    = 'sage'

local eosRegenSpells =
{
    [xi.magic.spell.REGEN] =
    {
        power = 5,
        duration = 75,
    },
    [xi.magic.spell.REGEN_II] =
    {
        power = 8,
        duration = 90,
    },
    [xi.magic.spell.REGEN_III] =
    {
        power = 12,
        duration = 105,
    },
    [xi.magic.spell.REGEN_IV] =
    {
        power = 16,
        duration = 120,
    },
    [xi.magic.spell.REGEN_V] =
    {
        power = 22,
        duration = 150,
    },
}

xi.jobAbility.FAERIE_COMPANION = eosAbilityId
xi.jobAbility.FAERIE_TITANIA   = titaniaAbilityId
xi.petId.FAERIE_COMPANION      = eosPetId
xi.petId.FAERIE_TITANIA        = titaniaPetId
xi.effect.EOS_REGEN            = eosRegenEffectId
xi.mod.EOS_REFRESH             = eosRefreshModId

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.faerie_companion = xi.actions.abilities.faerie_companion or {}
xi.actions.abilities.faerie_titania   = xi.actions.abilities.faerie_titania or {}

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function isScholarSpec(player, specKey)
    return
        player ~= nil and
        player:isPC() and
        player:getMainJob() == xi.job.SCH and
        xi.overlords.spec.is(player, xi.job.SCH, specKey)
end

m:addOverride('xi.actions.abilities.faerie_companion.onAbilityCheck', function(player, target, ability)
    if not isScholarSpec(player, eosRequiredSpec) then
        tell(player, 'Eos is only available to Scholar Medic spec (Lv.10+).')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if player:hasPet() then
        return xi.msg.basic.ALREADY_HAS_A_PET, 0
    end

    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.faerie_companion.onUseAbility', function(player, target, ability)
    xi.pet.spawnPet(player, eosPetId)

    return eosAbilityId
end)

m:addOverride('xi.actions.abilities.faerie_titania.onAbilityCheck', function(player, target, ability)
    if not isScholarSpec(player, titaniaReqSpec) then
        tell(player, 'Titania is only available to Scholar Sage spec (Lv.10+).')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if player:hasPet() then
        return xi.msg.basic.ALREADY_HAS_A_PET, 0
    end

    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.faerie_titania.onUseAbility', function(player, target, ability)
    xi.pet.spawnPet(player, titaniaPetId)

    return titaniaAbilityId
end)

local function handleEosRegenCast(caster, target, spell, superFn)
    if caster ~= nil and caster:isPet() and caster:getPetID() == eosPetId then
        local params = eosRegenSpells[spell:getID()] or eosRegenSpells[xi.magic.spell.REGEN]
        if target:addStatusEffect(eosRegenEffectId, { power = params.power, tick = 3, duration = params.duration, icon = xi.effect.REGEN, origin = caster }) then
            spell:setMsg(xi.msg.basic.MAGIC_GAIN_EFFECT)
            return xi.effect.REGEN
        end

        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
        return xi.effect.NONE
    end

    return superFn(caster, target, spell)
end

for _, regenKey in ipairs({ 'regen', 'regen_ii', 'regen_iii', 'regen_iv', 'regen_v' }) do
    m:addOverride('xi.actions.spells.white.' .. regenKey .. '.onSpellCast', function(caster, target, spell)
        return handleEosRegenCast(caster, target, spell, super)
    end)
end

return m
