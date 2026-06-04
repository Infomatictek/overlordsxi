-----------------------------------
-- Eos Companion
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/pets')
-----------------------------------
local m = Module:new('eos_companion')

local eosAbilityId      = 231
local eosPetId          = 128
local eosRegenEffectId  = 789
local eosRefreshModId   = 1198
local eosRequiredSpec   = 'medic'

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
xi.petId.FAERIE_COMPANION = eosPetId
xi.effect.EOS_REGEN = eosRegenEffectId
xi.mod.EOS_REFRESH = eosRefreshModId

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.faerie_companion = xi.actions.abilities.faerie_companion or {}

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function isMedicScholar(player)
    return
        player ~= nil and
        player:isPC() and
        player:getMainJob() == xi.job.SCH and
        xi.overlords.spec.is(player, xi.job.SCH, eosRequiredSpec)
end

m:addOverride('xi.actions.abilities.faerie_companion.onAbilityCheck', function(player, target, ability)
    if not isMedicScholar(player) then
        tell(player, 'Eos is only available to Scholar Medic spec.')
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

m:addOverride('xi.actions.spells.white.regen.onSpellCast', function(caster, target, spell)
    if caster:getPetID() == eosPetId then
        local params = eosRegenSpells[spell:getID()] or eosRegenSpells[xi.magic.spell.REGEN]
        target:addStatusEffect(eosRegenEffectId, { power = params.power, tick = 3, duration = params.duration, icon = xi.effect.REGEN, origin = caster })
        return xi.effect.REGEN
    end

    return super(caster, target, spell)
end)

return m
