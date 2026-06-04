-----------------------------------
-- Eos Companion
-----------------------------------
require('modules/module_utils')
require('scripts/globals/pets')
-----------------------------------
local m = Module:new('eos_companion')

local eosAbilityId      = 231
local eosPetId          = 128
local eosRegenEffectId  = 789
local eosRefreshModId   = 1198

xi.jobAbility.FAERIE_COMPANION = eosAbilityId
xi.petId.FAERIE_COMPANION = eosPetId
xi.effect.EOS_REGEN = eosRegenEffectId
xi.mod.EOS_REFRESH = eosRefreshModId

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.faerie_companion = xi.actions.abilities.faerie_companion or {}

m:addOverride('xi.actions.abilities.faerie_companion.onAbilityCheck', function(player, target, ability)
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
        target:addStatusEffect(eosRegenEffectId, { power = 5, tick = 3, duration = 75, icon = xi.effect.REGEN, origin = caster })
        return xi.effect.REGEN
    end

    return super(caster, target, spell)
end)

return m
