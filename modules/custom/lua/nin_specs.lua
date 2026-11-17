-----------------------------------
-- OverlordsXI Ninja Crystal Spec (Kagemusha)
-- Registers the Ninja (job 13) Soul Crystal specialization:
--   1. Kagemusha (KAG): Decoy-Detonating Shadow & Ninjutsu Tank (Dual Katanas)
--
-- Unlocks @ Lv. 10 (!spec set kagemusha)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/job_utils/ninja')
require('scripts/globals/spells/enhancing_ninjutsu')
require('scripts/globals/spells/damage_spell')
require('scripts/globals/spells/enfeebling_spell')
require('scripts/globals/mobskills')
require('scripts/globals/ability')
require('scripts/globals/canusespell_override')
require('scripts/utils/combat_utils')
-----------------------------------
local m = Module:new('overlords_nin_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.ninSpecs = xi.overlords.ninSpecs or {}

local KAGEMUSHA_KEY = 'kagemusha'

-- Custom Trait ID (161)
local TRAIT_KAGEMUSHA_PHANTOM = 161

-- Custom Ability IDs (443-444; recastIds 218-219)
local ABIL_KAGE_BUNSHIN = 443
local ABIL_SMOKE_LOTUS  = 444

-- Native NIN Ability IDs
local ABIL_MIJIN_GAKURE = 28
local ABIL_YONIN        = 248
local ABIL_FUTAE        = 259

-- Custom Status Effect IDs (845-846; registered in patch 0026)
local EFFECT_SHADOW_SMOKE = 845
local EFFECT_KAGE_BUNSHIN = 846

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.KAGE_BUNSHIN = ABIL_KAGE_BUNSHIN
xi.jobAbility.SMOKE_LOTUS  = ABIL_SMOKE_LOTUS

xi.effect = xi.effect or {}
xi.effect.KAGEMUSHA_SHADOW_SMOKE = EFFECT_SHADOW_SMOKE
xi.effect.KAGEMUSHA_BUNSHIN      = EFFECT_KAGE_BUNSHIN

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.kage_bunshin = xi.actions.abilities.kage_bunshin or {}
xi.actions.abilities.smoke_lotus  = xi.actions.abilities.smoke_lotus or {}

xi.effects = xi.effects or {}
xi.effects.kagemusha_shadow_smoke = xi.effects.kagemusha_shadow_smoke or {}
xi.effects.kagemusha_bunshin      = xi.effects.kagemusha_bunshin or {}

local weaponStateByChar = {}
local yoninNoShadowDtByChar = {}

-----------------------------------
-- Scaling & Equipment Helpers
-----------------------------------
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

local function isKagemusha(entity)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.NIN or
        entity:getMainLvl() < 10
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.NIN, KAGEMUSHA_KEY)
end

local function isKatanaItem(item)
    if item == nil or not item.getSkillType then
        return false
    end
    return item:getSkillType() == xi.skill.KATANA
end

local function isDualKatanasEquipped(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local mainItem = player:getEquippedItem(xi.slot.MAIN)
    local subItem  = player:getEquippedItem(xi.slot.SUB)
    return isKatanaItem(mainItem) and isKatanaItem(subItem)
end

local function isKagemushaDualKatanas(entity)
    return isKagemusha(entity) and isDualKatanasEquipped(entity)
end

local function syncKagemushaVarsAndSpells(player)
    if player == nil or not player:isPC() then
        return
    end

    if isKagemusha(player) then
        if player.hasSpell and player.addSpell and not player:hasSpell(xi.magic.spell.UTSUSEMI_NI) then
            player:addSpell(xi.magic.spell.UTSUSEMI_NI, { silentLog = true, saveToDB = true, sendUpdate = true })
        end

        if isDualKatanasEquipped(player) then
            local reduct = scaleTier(player:getMainLvl(), 15, 25, 35, 45)
            player:setLocalVar('OX_NIN_CAST_REDUCT', reduct)
            player:setLocalVar('OX_NIN_RECAST_REDUCT', reduct)
        else
            player:setLocalVar('OX_NIN_CAST_REDUCT', 0)
            player:setLocalVar('OX_NIN_RECAST_REDUCT', 0)
        end
    else
        player:setLocalVar('OX_NIN_CAST_REDUCT', 0)
        player:setLocalVar('OX_NIN_RECAST_REDUCT', 0)
    end
end

local function setUtsusemiShadows(player, shadows, tierPower)
    if player == nil then
        return
    end

    local clamped = math.max(1, math.min(5, math.floor(shadows)))
    local icon = xi.effect.COPY_IMAGE_4
    if clamped == 1 then
        icon = xi.effect.COPY_IMAGE
    elseif clamped == 2 then
        icon = xi.effect.COPY_IMAGE_2
    elseif clamped == 3 then
        icon = xi.effect.COPY_IMAGE_3
    end

    if player:hasStatusEffect(xi.effect.THIRD_EYE) then
        player:delStatusEffect(xi.effect.THIRD_EYE)
    end

    local curEffect = player:getStatusEffect(xi.effect.COPY_IMAGE)
    local pwr = tierPower or (curEffect and curEffect:getPower()) or 2
    player:delStatusEffect(xi.effect.COPY_IMAGE)
    player:addStatusEffect(xi.effect.COPY_IMAGE, {
        power    = pwr,
        duration = 900,
        origin   = player,
        tick     = 0,
        icon     = icon,
        subPower = clamped,
    })
    player:setMod(xi.mod.UTSUSEMI, clamped)
end

local function updateYoninShadowDt(player)
    if player == nil or not player.getID then
        return
    end

    local charId = player:getID()
    local shouldHaveDt = isKagemusha(player) and player:hasStatusEffect(xi.effect.YONIN) and player:getMod(xi.mod.UTSUSEMI) <= 0
    local currentlyHas = yoninNoShadowDtByChar[charId] == true

    if shouldHaveDt and not currentlyHas then
        player:addMod(xi.mod.DMG, -1500)
        yoninNoShadowDtByChar[charId] = true
    elseif not shouldHaveDt and currentlyHas then
        player:delMod(xi.mod.DMG, -1500)
        yoninNoShadowDtByChar[charId] = nil
    end
end

local function applyShadowSmoke(attacker, defender, stacksToAdd)
    if
        attacker == nil or
        defender == nil or
        not attacker.isAlive or
        not attacker:isAlive() or
        attacker:getID() == defender:getID()
    then
        return
    end

    local cur = attacker:getStatusEffect(EFFECT_SHADOW_SMOKE)
    local curStacks = cur and cur:getPower() or 0
    local newStacks = math.min(4, curStacks + (stacksToAdd or 1))
    if newStacks <= 0 then
        return
    end

    attacker:delStatusEffectSilent(EFFECT_SHADOW_SMOKE)
    attacker:addStatusEffect(EFFECT_SHADOW_SMOKE, {
        power    = newStacks,
        duration = 12,
        origin   = defender,
    })
end

local function triggerShadowDetonation(defender, attacker, shadowsBroken)
    if not isKagemushaDualKatanas(defender) then
        return
    end

    local count = math.max(1, math.floor(shadowsBroken or 1))
    defender:addTP(60 * count)

    if attacker ~= nil and attacker.isAlive and attacker:isAlive() and attacker:getID() ~= defender:getID() then
        if attacker.addEnmity then
            attacker:addEnmity(defender, 145 * count, 380 * count)
        end
        applyShadowSmoke(attacker, defender, count)
    end

    updateYoninShadowDt(defender)
end

-----------------------------------
-- Global C++ Hook Callbacks
-----------------------------------
xi.overlords = xi.overlords or {}

local prevOnUtsusemiShadowBroken = xi.overlords.onUtsusemiShadowBroken
xi.overlords.onUtsusemiShadowBroken = function(defender, attacker, shadowsBroken)
    if prevOnUtsusemiShadowBroken then
        prevOnUtsusemiShadowBroken(defender, attacker, shadowsBroken)
    end

    triggerShadowDetonation(defender, attacker, shadowsBroken)
end

local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage
xi.overlords.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    if defender == nil or amount <= 0 then
        return amount
    end

    -- AoE Shadow-Guard: 20% damage reduction against AoE/magical/breath/special hits while >= 1 shadow remains
    if
        isKagemushaDualKatanas(defender) and
        defender:getMod(xi.mod.UTSUSEMI) > 0 and
        (attackType == xi.attackType.MAGICAL or attackType == xi.attackType.BREATH or attackType == xi.attackType.SPECIAL)
    then
        amount = math.floor(amount * 0.80)
    end

    -- Mijin Gakure (Shadow Substitution) cheat-death: 60s CD, prevents fatal damage, +40% Max HP, 5 fresh shadows
    if
        isKagemusha(defender) and
        amount >= defender:getHP() and
        not defender:hasRecast(xi.recast.ABILITY, 0)
    then
        defender:addRecast(xi.recast.ABILITY, 0, 60)
        local heal = math.max(1, math.floor(defender:getMaxHP() * 0.40))
        defender:addHP(heal)
        setUtsusemiShadows(defender, 5, 2)
        updateYoninShadowDt(defender)
        if defender.printToPlayer then
            defender:printToPlayer(string.format('Shadow Substitution! Mijin Gakure prevented fatal damage, restored %d HP, and spawned 5 shadows.', heal), xi.msg.channel.SYSTEM_3)
        end
        return 0
    end

    return amount
end

-----------------------------------
-- Custom Status Effects (845-846)
-----------------------------------
m:addOverride('xi.effects.kagemusha_shadow_smoke.onEffectGain', function(target, effect)
    local stacks = math.max(1, math.min(4, effect:getPower()))
    effect:addMod(xi.mod.ATTP, -4 * stacks)
    effect:addMod(xi.mod.MATT, -4 * stacks)
    effect:addMod(xi.mod.ACC,  -6 * stacks)
end)

m:addOverride('xi.effects.kagemusha_shadow_smoke.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.kagemusha_bunshin.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.EVA_PERCENT,    25)
    effect:addMod(xi.mod.SPELLINTERRUPT, 100)
end)

m:addOverride('xi.effects.kagemusha_bunshin.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Utsusemi: Ni Unlock & Explosive Shadow Casting
-----------------------------------
m:addOverride('xi.spells.canUseSpellOverride', function(player, spell)
    if
        isKagemusha(player) and
        spell:getID() == xi.magic.spell.UTSUSEMI_NI
    then
        return true
    end

    return super(player, spell)
end)

m:addOverride('xi.spells.enhancing.useEnhancingNinjutsu', function(caster, target, spell)
    local spellId = spell:getID()
    if
        isKagemusha(caster) and
        (spellId == xi.magic.spell.UTSUSEMI_ICHI or spellId == xi.magic.spell.UTSUSEMI_NI)
    then
        local shadows   = (spellId == xi.magic.spell.UTSUSEMI_NI) and 5 or 4
        local tierPower = (spellId == xi.magic.spell.UTSUSEMI_NI) and 2 or 1
        local curEffect = target:getStatusEffect(xi.effect.COPY_IMAGE)

        if target:hasStatusEffect(xi.effect.THIRD_EYE) then
            target:delStatusEffect(xi.effect.THIRD_EYE)
        end

        -- Ni cleanly overwrites Ichi without lockout; Ichi refreshes if no Ni is active
        if
            curEffect == nil or
            curEffect:getPower() <= tierPower or
            spellId == xi.magic.spell.UTSUSEMI_NI
        then
            target:delStatusEffectSilent(xi.effect.COPY_IMAGE)
            target:addStatusEffect(xi.effect.COPY_IMAGE, {
                power    = tierPower,
                duration = 900,
                origin   = caster,
                tick     = 0,
                icon     = xi.effect.COPY_IMAGE_4,
                subPower = shadows,
            })
            target:setMod(xi.mod.UTSUSEMI, shadows)
            updateYoninShadowDt(target)
            spell:setMsg(xi.msg.basic.MAGIC_GAIN_EFFECT)
            return xi.effect.COPY_IMAGE
        else
            spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
            return xi.effect.COPY_IMAGE
        end
    end

    return super(caster, target, spell)
end)

-----------------------------------
-- AoE Shadow-Guard & Lua Shadow Break Hooks
-----------------------------------
m:addOverride('xi.mobskills.handleShadowConsumption', function(mob, target, skill, params, shadowsToRemove)
    if
        isKagemushaDualKatanas(target) and
        target:getMod(xi.mod.UTSUSEMI) > 0 and
        (skill:isAoE() or skill:isConal())
    then
        if shadowsToRemove == xi.mobskills.shadowBehavior.WIPE_SHADOWS or shadowsToRemove > 1 then
            shadowsToRemove = xi.mobskills.shadowBehavior.NUMSHADOWS_1
        end
    end

    local hitAbsorbed, shadowsConsumed = super(mob, target, skill, params, shadowsToRemove)
    if shadowsConsumed > 0 and isKagemushaDualKatanas(target) then
        triggerShadowDetonation(target, mob, shadowsConsumed)
    end

    return hitAbsorbed, shadowsConsumed
end)

m:addOverride('xi.ability.adjustDamage', function(dmg, attacker, skill, target, attackType, damageType, shadowbehav)
    if
        isKagemushaDualKatanas(target) and
        target:getMod(xi.mod.UTSUSEMI) > 0
    then
        if shadowbehav == xi.mobskills.shadowBehavior.WIPE_SHADOWS or (shadowbehav ~= xi.mobskills.shadowBehavior.IGNORE_SHADOWS and shadowbehav > 1) then
            shadowbehav = xi.mobskills.shadowBehavior.NUMSHADOWS_1
        end
    end

    local prevShadows = target:getMod(xi.mod.UTSUSEMI)
    local outDmg = super(dmg, attacker, skill, target, attackType, damageType, shadowbehav)
    local newShadows = target:getMod(xi.mod.UTSUSEMI)
    if prevShadows > newShadows and isKagemushaDualKatanas(target) then
        triggerShadowDetonation(target, attacker, prevShadows - newShadows)
    end

    return outDmg
end)

-----------------------------------
-- Yonin, Futae, Mijin Gakure Enhancements
-----------------------------------
m:addOverride('xi.job_utils.ninja.checkYonin', function(player, target, ability)
    if isKagemusha(player) then
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.ninja.useYonin', function(player, target, ability, action)
    local ret = super(player, target, ability, action)
    if isKagemusha(player) then
        updateYoninShadowDt(player)
    end
    return ret
end)

m:addOverride('xi.effects.yonin.onEffectGain', function(target, effect)
    if isKagemusha(target) then
        -- Zero accuracy penalty, +30 Enmity, +15% Ninja Tool/Ninjutsu potency
        effect:addMod(xi.mod.ENMITY, 30)
        effect:addMod(xi.mod.NINJA_TOOL, 15)
        effect:addMod(xi.mod.MATT, 15)
        local yoninMerits = target:getMerit(xi.merit.YONIN_EFFECT)
        if yoninMerits ~= 0 then
            effect:addMod(xi.mod.HP, yoninMerits)
        end
        updateYoninShadowDt(target)
        return
    end

    super(target, effect)
end)

m:addOverride('xi.effects.yonin.onEffectTick', function(target, effect)
    if isKagemusha(target) then
        updateYoninShadowDt(target)
        return
    end

    super(target, effect)
end)

m:addOverride('xi.effects.yonin.onEffectLose', function(target, effect)
    updateYoninShadowDt(target)
    super(target, effect)
end)

m:addOverride('xi.job_utils.ninja.checkMijinGakure', function(player, target, ability)
    if isKagemusha(player) then
        ability:setRecast(60)
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.ninja.useMijinGakure', function(player, target, ability, action)
    if isKagemusha(player) then
        local heal = math.max(1, math.floor(player:getMaxHP() * 0.40))
        player:addHP(heal)
        setUtsusemiShadows(player, 5, 2)
        updateYoninShadowDt(player)
        ability:setMsg(xi.msg.basic.RECOVERS_HP)
        return heal
    end

    return super(player, target, ability, action)
end)

-- Futae: next elemental/enfeebling ninjutsu generates 2x enmity and inflicts 5s Terror
local function handleKagemushaFutaeCast(caster, target, spell)
    if
        not isKagemusha(caster) or
        spell == nil or
        spell:getSpellGroup() ~= xi.magic.spellGroup.NINJUTSU or
        not caster:hasStatusEffect(xi.effect.FUTAE)
    then
        return
    end

    caster:delStatusEffectSilent(xi.effect.FUTAE)
    if target ~= nil and target.isAlive and target:isAlive() and target:getID() ~= caster:getID() then
        if target.addEnmity then
            target:addEnmity(caster, 200, 600)
        end
        target:addStatusEffect(xi.effect.TERROR, { power = 1, duration = 5, origin = caster })
    end
end

m:addOverride('xi.spells.damage.useDamageSpell', function(caster, target, spell)
    local hadFutae = isKagemusha(caster) and spell:getSpellGroup() == xi.magic.spellGroup.NINJUTSU and caster:hasStatusEffect(xi.effect.FUTAE)
    local dmg = super(caster, target, spell)
    if hadFutae then
        handleKagemushaFutaeCast(caster, target, spell)
    end
    return dmg
end)

m:addOverride('xi.spells.enfeebling.useEnfeeblingSpell', function(caster, target, spell)
    local hadFutae = isKagemusha(caster) and spell:getSpellGroup() == xi.magic.spellGroup.NINJUTSU and caster:hasStatusEffect(xi.effect.FUTAE)
    local ret = super(caster, target, spell)
    if hadFutae then
        handleKagemushaFutaeCast(caster, target, spell)
    end
    return ret
end)

-----------------------------------
-- Custom Active Job Abilities (443-444)
-----------------------------------
local DEBUFFS_TO_CLEANSE =
{
    xi.effect.PARALYSIS, xi.effect.BLINDNESS, xi.effect.SILENCE, xi.effect.SLOW,
    xi.effect.POISON, xi.effect.DISEASE, xi.effect.PLAGUE, xi.effect.CURSE_I,
    xi.effect.BIND, xi.effect.WEIGHT, xi.effect.FLASH, xi.effect.ACCURACY_DOWN,
    xi.effect.ATTACK_DOWN, xi.effect.DEFENSE_DOWN, xi.effect.EVASION_DOWN,
}

m:addOverride('xi.actions.abilities.kage_bunshin.onAbilityCheck', function(player, _target, _ability)
    if not isKagemusha(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.kage_bunshin.onUseAbility', function(player, _target, ability)
    local curShadows = player:getMod(xi.mod.UTSUSEMI)
    local newShadows = math.min(5, curShadows + 3)
    setUtsusemiShadows(player, newShadows, 2)
    updateYoninShadowDt(player)

    for _, effId in ipairs(DEBUFFS_TO_CLEANSE) do
        if player:hasStatusEffect(effId) then
            player:delStatusEffect(effId)
            break
        end
    end

    player:delStatusEffectSilent(EFFECT_KAGE_BUNSHIN)
    player:addStatusEffect(EFFECT_KAGE_BUNSHIN, { power = 1, duration = 6, origin = player })
    ability:setMsg(xi.msg.basic.GAINS_EFFECT_OF_STATUS)
    return EFFECT_KAGE_BUNSHIN
end)

m:addOverride('xi.actions.abilities.smoke_lotus.onAbilityCheck', function(player, _target, _ability)
    if not isKagemushaDualKatanas(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.smoke_lotus.onUseAbility', function(player, target, ability)
    if target == nil or not target:isAlive() then
        return 0
    end

    if target.addEnmity then
        target:addEnmity(player, 400, 1200)
    end

    applyShadowSmoke(target, player, 4)
    target:addStatusEffect(xi.effect.SLOW, { power = 2500, duration = 45, origin = player })
    target:addStatusEffect(xi.effect.BLINDNESS, { power = 25, duration = 45, origin = player })

    ability:setMsg(xi.msg.basic.USES_ABILITY_EFFECT)
    return EFFECT_SHADOW_SMOKE
end)

-----------------------------------
-- Listeners (Weapon Sync & Katana WS Shadow Engine)
-----------------------------------
local function onEquipmentChange(player)
    if player == nil or not player:isPC() then
        return
    end

    local charId = player:getID()
    local dual = isDualKatanasEquipped(player)
    local prev = weaponStateByChar[charId]
    weaponStateByChar[charId] = dual

    syncKagemushaVarsAndSpells(player)

    if prev ~= dual and isKagemusha(player) and spec.appliedByCharId and spec.appliedByCharId[charId] ~= nil then
        spec.appliedByCharId[charId].level = -1
        spec.refreshPlayer(player, { skipSync = true })
    end
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player == nil or not player:isPC() then
        return
    end

    syncKagemushaVarsAndSpells(player)

    player:removeListener('OX_NIN_EQUIP')
    player:addListener('EQUIP', 'OX_NIN_EQUIP', onEquipmentChange)
    player:addListener('UNEQUIP', 'OX_NIN_EQUIP', onEquipmentChange)

    player:removeListener('OX_NIN_WS_SHADOW')
    player:addListener('WEAPONSKILL_USE', 'OX_NIN_WS_SHADOW', function(actor, target, wsId, tp, action)
        if not isKagemusha(actor) then
            return
        end

        local wsEntry = xi.data and xi.data.weaponskill and xi.data.weaponskill[wsId]
        local isKatanaWs = (wsEntry ~= nil and wsEntry.skill == xi.skill.KATANA) or (wsEntry == nil and wsId >= 128 and wsId <= 143)
        if not isKatanaWs then
            return
        end

        -- Restore +1 Utsusemi shadow (up to cap of 5)
        local cur = actor:getMod(xi.mod.UTSUSEMI)
        if cur < 5 then
            setUtsusemiShadows(actor, math.min(5, cur + 1))
            updateYoninShadowDt(actor)
        end

        -- Refresh all Shadow Smoke stacks on target
        if target ~= nil and target.hasStatusEffect and target:hasStatusEffect(EFFECT_SHADOW_SMOKE) then
            local smoke = target:getStatusEffect(EFFECT_SHADOW_SMOKE)
            if smoke then
                smoke:setDuration(12000)
            end
        end
    end)
end)

-----------------------------------
-- Spec Registration
-----------------------------------
if xi.job and xi.job.NIN then
    spec.registerJob(xi.job.NIN, 'NIN',
    {
        {
            id             = 1,
            key            = KAGEMUSHA_KEY,
            name           = 'Kagemusha',
            role           = 'Shadow & Ninjutsu Tank',
            icon           = 'onyx_tome',
            extraTraits    = { TRAIT_KAGEMUSHA_PHANTOM },
            extraAbilities = { ABIL_YONIN, ABIL_FUTAE, ABIL_KAGE_BUNSHIN, ABIL_SMOKE_LOTUS },
            description    = 'Decoy-detonating shadow & ninjutsu tank requiring Dual Katanas for Explosive Utsusemi Decoys, AoE Shadow-Guard, and Ninjutsu Enfeeblement Mastery.',
            highlights     =
            {
                'Passives (Lv10/30/50/70+): +12/16/20/25% Max HP, +8/14/20/26 AGI & VIT, +10/16/22/28% DEF, -6/9/12/16% DT, +25/35/45/60 Enmity & Enmity Retention.',
                'Dual Katana Mastery: +15/25/35/50 Katana & Ninjutsu skill, +10/15/20/25 Subtle Blow, -15/25/35/45% Ninjutsu Cast/Recast, +10/14/18/22% Evasion.',
                'Explosive Utsusemi Decoys: Unlocks Ni @ Lv10, zero tool cost, 100% SIRD; broken shadows detonate for enmity, +60 TP, and Shadow Smoke (-4% ATK/MATK, -6 ACC, up to 4 stacks).',
                'AoE Shadow-Guard & Katana WS Engine: AoEs/conals consume at most 1 shadow and deal -20% DMG while shadows remain; Katana WSs restore +1 shadow & refresh Shadow Smoke.',
                'Tank JAs: Yonin (+30 Enmity, +15% potency, -15% DT w/o shadows, 0 ACC penalty), Futae (2x enmity + 5s Terror), Mijin Gakure (60s CD Shadow Substitution cheat-death).',
            },
            mods = function(player)
                local lvl = player:getMainLvl()
                syncKagemushaVarsAndSpells(player)

                local mods =
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.AGI,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.VIT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 10, 16, 22, 28) },
                    { xi.mod.DMG,                   scaleTier(lvl, -600, -900, -1200, -1600) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ALL_WSDMG_ALL_HITS,    -15 },
                }

                if isDualKatanasEquipped(player) then
                    table.insert(mods, { xi.mod.KATANA,      scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(mods, { xi.mod.NINJUTSU,    scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(mods, { xi.mod.SUBTLE_BLOW, scaleTier(lvl, 10, 15, 20, 25) })
                    table.insert(mods, { xi.mod.EVA_PERCENT, scaleTier(lvl, 10, 14, 18, 22) })
                end

                return mods
            end,
        },
    })
end

return m
