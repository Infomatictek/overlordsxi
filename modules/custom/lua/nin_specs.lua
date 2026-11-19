-----------------------------------
-- OverlordsXI Ninja Crystal Spec (Kagemusha)
-- Registers the Ninja (job 13) Soul Crystal specialization:
--   1. Kagemusha (KGM): Decoy-Detonating Shadow & Ninjutsu Tank (Dual Katanas)
--
-- Unlocks @ Lv. 10 (!spec set kagemusha)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
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
local KUROGANE_KEY  = 'kurogane'

-- Custom Trait ID (161)
local TRAIT_KAGEMUSHA_PHANTOM = 161

-- Custom Ability IDs
-- Kagemusha (443-444; recastIds 218-219)
local ABIL_KAGE_BUNSHIN    = 443
local ABIL_SMOKE_LOTUS     = 444
-- Shinobi (487-488; recastIds 238-239)
local ABIL_SHADOW_LEGION   = 487
local ABIL_PHANTOM_ASSAULT = 488

-- Native NIN Ability IDs
local ABIL_MIJIN_GAKURE = 28
local ABIL_YONIN        = 248
local ABIL_FUTAE        = 259

-- Custom Status Effect IDs (845-846; registered in patch 0026)
local EFFECT_SHADOW_SMOKE = 845
local EFFECT_KAGE_BUNSHIN = 846

-- Lv.10+ Unlocked Ninjutsu Spells
local KAGEMUSHA_SPELLS =
{
    320, -- Katon: Ichi
    323, -- Hyoton: Ichi
    326, -- Huton: Ichi
    329, -- Doton: Ichi
    332, -- Raiton: Ichi
    335, -- Suiton: Ichi
    338, -- Utsusemi: Ichi
    339, -- Utsusemi: Ni
    344, -- Hojo: Ichi
    347, -- Kurayami: Ichi
}

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.KAGE_BUNSHIN    = ABIL_KAGE_BUNSHIN
xi.jobAbility.SMOKE_LOTUS     = ABIL_SMOKE_LOTUS
xi.jobAbility.SHADOW_LEGION   = ABIL_SHADOW_LEGION
xi.jobAbility.PHANTOM_ASSAULT = ABIL_PHANTOM_ASSAULT

xi.effect = xi.effect or {}
xi.effect.KAGEMUSHA_SHADOW_SMOKE = EFFECT_SHADOW_SMOKE
xi.effect.KAGEMUSHA_BUNSHIN      = EFFECT_KAGE_BUNSHIN

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.kage_bunshin    = xi.actions.abilities.kage_bunshin or {}
xi.actions.abilities.smoke_lotus     = xi.actions.abilities.smoke_lotus or {}
xi.actions.abilities.shadow_legion   = xi.actions.abilities.shadow_legion or {}
xi.actions.abilities.phantom_assault = xi.actions.abilities.phantom_assault or {}

xi.effects = xi.effects or {}
xi.effects.kagemusha_shadow_smoke = xi.effects.kagemusha_shadow_smoke or {}
xi.effects.kagemusha_bunshin      = xi.effects.kagemusha_bunshin or {}

local weaponStateByChar    = {}
local yoninNoShadowDtByChar = {}
local lastWsCastAtByChar   = {}

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

local function isShinobi(entity)
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
    return spec.is(entity, xi.job.NIN, KUROGANE_KEY)
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

local function getKawarimiAsh(player)
    if player == nil or not player.getLocalVar then
        return 0
    end
    local exp = player:getLocalVar('OX_NIN_ASH_EXP') or 0
    if exp > 0 and os.time() > exp then
        player:setLocalVar('OX_NIN_ASH', 0)
        player:setLocalVar('OX_NIN_ASH_EXP', 0)
        return 0
    end
    return math.min(4, math.max(0, player:getLocalVar('OX_NIN_ASH') or 0))
end

local function addKawarimiAsh(player, amount)
    if player == nil or not player.setLocalVar then
        return 0
    end
    local cur  = getKawarimiAsh(player)
    local next = math.min(4, cur + (amount or 1))
    player:setLocalVar('OX_NIN_ASH', next)
    player:setLocalVar('OX_NIN_ASH_EXP', os.time() + 30)
    return next
end

local function consumeKawarimiAsh(player, amount)
    local cur = getKawarimiAsh(player)
    if cur < amount then
        return false
    end
    if player ~= nil and player.setLocalVar then
        player:setLocalVar('OX_NIN_ASH', cur - amount)
        if cur - amount <= 0 then
            player:setLocalVar('OX_NIN_ASH_EXP', 0)
        end
    end
    return true
end

local function syncKagemushaVarsAndSpells(player, fromMods)
    if player == nil or not player:isPC() then
        return
    end

    local active = false
    if fromMods then
        active = player:getMainJob() == xi.job.NIN and player:getMainLvl() >= 10
    else
        active = isKagemusha(player)
    end

    if active then
        if player.hasSpell and player.addSpell then
            for _, spellId in ipairs(KAGEMUSHA_SPELLS) do
                if not player:hasSpell(spellId) then
                    player:addSpell(spellId, { silentLog = true, saveToDB = true, sendUpdate = true })
                end
            end
        end

        if isDualKatanasEquipped(player) then
            local reduct = scaleTier(player:getMainLvl(), 20, 30, 40, 50)
            player:setLocalVar('OX_NIN_CAST_REDUCT', reduct)
        else
            player:setLocalVar('OX_NIN_CAST_REDUCT', 0)
        end
    else
        player:setLocalVar('OX_NIN_CAST_REDUCT', 0)
    end
    -- Never reduce Utsusemi spell recast below fixed timers
    player:setLocalVar('OX_NIN_RECAST_REDUCT', 0)
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
    player:delStatusEffectSilent(xi.effect.COPY_IMAGE)
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
        player:addMod(xi.mod.DMG, -1800)
        player:addMod(xi.mod.INQUARTATA, 15)
        yoninNoShadowDtByChar[charId] = true
    elseif not shouldHaveDt and currentlyHas then
        player:delMod(xi.mod.DMG, -1800)
        player:delMod(xi.mod.INQUARTATA, 15)
        yoninNoShadowDtByChar[charId] = nil
    end
end

local function applySharedCripple(target, origin, stacks, durationSec)
    if target == nil or not target.isAlive or not target:isAlive() then
        return
    end
    local s     = math.max(1, math.min(4, math.floor(stacks or 1)))
    local dur   = durationSec or 15
    local effId = (xi.effect and xi.effect.EFF_OX_DEB_CRIPPLE) or 880
    local slots = xi.overlords and xi.overlords.slots
    local mods  =
    {
        { xi.mod.ATTP, -4 * s },
        { xi.mod.MATT, -4 * s },
        { xi.mod.ACC,  -6 * s },
    }
    if slots and slots.applySlot then
        slots.applySlot(target, effId, 4 * s, dur, origin, mods, effId)
    else
        target:addStatusEffect(xi.effect.ATTACK_DOWN,    { power = 4 * s, duration = dur, origin = origin })
        target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 4 * s, duration = dur, origin = origin })
        target:addStatusEffect(xi.effect.ACCURACY_DOWN,  { power = 6 * s, duration = dur, origin = origin })
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
        duration = 15,
        origin   = defender,
        icon     = xi.overlords.getStatusIcon(EFFECT_SHADOW_SMOKE),
    })
    applySharedCripple(attacker, defender, newStacks, 15)
end

local function triggerShadowDetonation(defender, attacker, shadowsBroken)
    if not isKagemushaDualKatanas(defender) then
        return
    end

    local count = math.max(1, math.floor(shadowsBroken or 1))
    defender:addTP(35 * count)
    addKawarimiAsh(defender, count)

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

    -- AoE Shadow-Guard: 50% bleedthrough damage while >= 1 shadow remains
    if
        isKagemushaDualKatanas(defender) and
        defender:getMod(xi.mod.UTSUSEMI) > 0 and
        (attackType == xi.attackType.MAGICAL or attackType == xi.attackType.BREATH or attackType == xi.attackType.SPECIAL)
    then
        amount = math.floor(amount * 0.50)
    end

    -- Migawari Tankbuster Intercept (Mijin Gakure active 12s ward):
    -- negates any single attack/AoE >30% Max HP (or fatal), heals 25% Max HP, spawns 4 shadows
    if isKagemusha(defender) and defender.getLocalVar then
        local wardExp = defender:getLocalVar('OX_NIN_MIGAWARI_EXP') or 0
        if wardExp > 0 and os.time() <= wardExp then
            local maxHp = defender:getMaxHP() or 1
            local curHp = defender:getHP() or 0
            if amount > math.floor(maxHp * 0.30) or amount >= curHp then
                defender:setLocalVar('OX_NIN_MIGAWARI_EXP', 0)
                local heal = math.max(1, math.floor(maxHp * 0.25))
                defender:addHP(heal)
                setUtsusemiShadows(defender, 4, 2)
                updateYoninShadowDt(defender)
                if defender.printToPlayer then
                    defender:printToPlayer(string.format('Migawari Intercept! Negated tankbuster, restored %d HP, and spawned 4 shadows.', heal), xi.msg.channel.SYSTEM_3)
                end
                return 0
            end
        elseif wardExp > 0 then
            defender:setLocalVar('OX_NIN_MIGAWARI_EXP', 0)
        end
    end

    return amount
end

-----------------------------------
-- Custom Status Effects (845-846)
-----------------------------------
m:addOverride('xi.effects.kagemusha_shadow_smoke.onEffectGain', function(_target, _effect)
    -- Attack/MATT/ACC penalties are routed through shared EFF_OX_DEB_CRIPPLE
end)

m:addOverride('xi.effects.kagemusha_shadow_smoke.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.kagemusha_bunshin.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.DMGMAGIC, -1500)
end)

m:addOverride('xi.effects.kagemusha_bunshin.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Universal Zero-Tool Ninjutsu & Fixed Utsusemi Timers
-----------------------------------
m:addOverride('xi.spells.canUseSpellOverride', function(player, spell)
    if
        isKagemusha(player) and
        spell ~= nil and
        spell:getSpellGroup() == xi.magic.spellGroup.NINJUTSU
    then
        return true
    end

    return super(player, spell)
end)

for _, utsuName in ipairs({ 'utsusemi_ichi', 'utsusemi_ni' }) do
    m:addOverride('xi.actions.spells.ninjutsu.' .. utsuName .. '.onMagicCastingCheck', function(caster, target, spell)
        if isKagemusha(caster) and spell ~= nil and spell.setCastTime then
            local castMs = (utsuName == 'utsusemi_ni') and 1200 or 1500
            spell:setCastTime(castMs)
        elseif isShinobi(caster) then
            local api = xi.overlords and xi.overlords.kurogane
            if not api or not api.canSpawn then
                return xi.msg.basic.CANNOT_CAST_SPELL
            end
            local okSpawn, _err = api.canSpawn(caster)
            if not okSpawn then
                return xi.msg.basic.CANNOT_CAST_SPELL
            end
        end
        return super(caster, target, spell)
    end)
end

m:addOverride('xi.spells.enhancing.useEnhancingNinjutsu', function(caster, target, spell)
    local spellId = spell:getID()
    if
        isShinobi(caster) and
        (spellId == xi.magic.spell.UTSUSEMI_ICHI or spellId == xi.magic.spell.UTSUSEMI_NI)
    then
        -- Shinobi Offensive Utsusemi: summons independent offensive shadows
        -- (Ichi = 2, Ni = 3, max 5) instead of defensive COPY_IMAGE shadows.
        local count = (spellId == xi.magic.spell.UTSUSEMI_NI) and 3 or 2
        local api   = xi.overlords and xi.overlords.kurogane
        if api and api.spawn then
            local ok, result = api.spawn(caster, count)
            if ok then
                spell:setMsg(xi.msg.basic.NONE)
                if caster.printToPlayer then
                    local snap = api.getSnapshot and api.getSnapshot(caster) or nil
                    local total = snap and snap.clones or result
                    caster:printToPlayer(
                        string.format('[Shinobi] Summoned %d offensive %s (%d/5 active).',
                            result, result == 1 and 'shadow' or 'shadows', total),
                        xi.msg.channel.SYSTEM_3)
                end
            else
                spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
            end
        else
            spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
        end
        return 0
    end

    if
        isKagemusha(caster) and
        (spellId == xi.magic.spell.UTSUSEMI_ICHI or spellId == xi.magic.spell.UTSUSEMI_NI)
    then
        local isNi      = (spellId == xi.magic.spell.UTSUSEMI_NI)
        local shadows   = isNi and 4 or 3
        local tierPower = isNi and 2 or 1
        local recastSec = isNi and 28 or 18

        if target:hasStatusEffect(xi.effect.THIRD_EYE) then
            target:delStatusEffect(xi.effect.THIRD_EYE)
        end

        -- Ichi and Ni overwrite cleanly without "more powerful effect" blocks
        target:delStatusEffectSilent(xi.effect.COPY_IMAGE)
        target:addStatusEffect(xi.effect.COPY_IMAGE, {
            power    = tierPower,
            duration = 900,
            origin   = caster,
            tick     = 0,
            icon     = isNi and xi.effect.COPY_IMAGE_4 or xi.effect.COPY_IMAGE_3,
            subPower = shadows,
        })
        target:setMod(xi.mod.UTSUSEMI, shadows)
        updateYoninShadowDt(target)
        spell:setMsg(xi.msg.basic.MAGIC_GAIN_EFFECT)

        if caster.timer then
            caster:timer(50, function(actor)
                if actor ~= nil and actor.addRecast then
                    actor:addRecast(xi.recast.MAGIC, spellId, recastSec)
                end
            end)
        end
        return xi.effect.COPY_IMAGE
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
        if shadowsToRemove == xi.mobskills.shadowBehavior.WIPE_SHADOWS or shadowsToRemove > 2 then
            shadowsToRemove = xi.mobskills.shadowBehavior.NUMSHADOWS_2
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
        if shadowbehav == xi.mobskills.shadowBehavior.WIPE_SHADOWS or (shadowbehav ~= xi.mobskills.shadowBehavior.IGNORE_SHADOWS and shadowbehav > 2) then
            shadowbehav = xi.mobskills.shadowBehavior.NUMSHADOWS_2
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
        if ability ~= nil and ability.setRecast then
            ability:setRecast(15)
        end
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
        -- Zero accuracy penalty, +30 Enmity, +25 Ninjutsu MACC
        effect:addMod(xi.mod.ENMITY, 30)
        effect:addMod(xi.mod.MACC, 25)
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
        if ability ~= nil and ability.setRecast then
            ability:setRecast(120)
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.ninja.useMijinGakure', function(player, target, ability, action)
    if isKagemusha(player) then
        if player.setLocalVar then
            player:setLocalVar('OX_NIN_MIGAWARI_EXP', os.time() + 12)
        end
        ability:setMsg(xi.msg.basic.GAINS_EFFECT_OF_STATUS)
        return xi.effect.MIGAWARI
    end

    return super(player, target, ability, action)
end)

-- Futae (45s CD): instant-cast Ninjutsu, 2.5x volatile enmity, 2s Stun (isNM() safe), EFF_OX_DEB_EXPOSE (-25 MEVA, 15s)
m:addOverride('xi.job_utils.ninja.checkFutae', function(player, target, ability)
    if isKagemusha(player) and ability ~= nil and ability.setRecast then
        ability:setRecast(45)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.effects.futae.onEffectGain', function(target, effect)
    super(target, effect)
    if isKagemusha(target) and effect ~= nil and effect.addMod then
        effect:addMod(xi.mod.UFASTCAST, 100)
    end
end)

local function handleKagemushaNinjutsuCast(caster, target, spell, hadFutae)
    if
        not isKagemusha(caster) or
        spell == nil or
        spell:getSpellGroup() ~= xi.magic.spellGroup.NINJUTSU
    then
        return
    end

    addKawarimiAsh(caster, 1)

    if not hadFutae then
        return
    end

    caster:delStatusEffectSilent(xi.effect.FUTAE)
    if target ~= nil and target.isAlive and target:isAlive() and target:getID() ~= caster:getID() then
        if target.addEnmity then
            target:addEnmity(caster, 250, 1500)
        end
        local isNm = target.isNM and target:isNM()
        if not isNm then
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = caster })
        end
        local exposeId = (xi.effect and xi.effect.EFF_OX_DEB_EXPOSE) or 881
        local slots    = xi.overlords and xi.overlords.slots
        if slots and slots.applySlot then
            slots.applySlot(target, exposeId, 25, 15, caster, { { xi.mod.MEVA, -25 } }, exposeId)
        else
            target:addStatusEffect(xi.effect.MAGIC_EVASION_DOWN, { power = 25, duration = 15, origin = caster })
        end
    end
end

m:addOverride('xi.spells.damage.useDamageSpell', function(caster, target, spell)
    local hadFutae = isKagemusha(caster) and spell:getSpellGroup() == xi.magic.spellGroup.NINJUTSU and caster:hasStatusEffect(xi.effect.FUTAE)
    local dmg = super(caster, target, spell)
    handleKagemushaNinjutsuCast(caster, target, spell, hadFutae)
    return dmg
end)

m:addOverride('xi.spells.enfeebling.useEnfeeblingSpell', function(caster, target, spell)
    local hadFutae = isKagemusha(caster) and spell:getSpellGroup() == xi.magic.spellGroup.NINJUTSU and caster:hasStatusEffect(xi.effect.FUTAE)
    local ret = super(caster, target, spell)
    handleKagemushaNinjutsuCast(caster, target, spell, hadFutae)
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
    player:addStatusEffect(EFFECT_KAGE_BUNSHIN, { power = 1, duration = 6, origin = player, icon = xi.overlords.getStatusIcon(EFFECT_KAGE_BUNSHIN) })
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
    target:addStatusEffect(xi.effect.SLOW, { power = 2000, duration = 30, origin = player })
    addKawarimiAsh(player, 2)

    ability:setMsg(xi.msg.basic.USES_ABILITY_EFFECT)
    return EFFECT_SHADOW_SMOKE
end)

-----------------------------------
-- Shinobi Custom Active Job Abilities (487-488)
-----------------------------------
m:addOverride('xi.actions.abilities.shadow_legion.onAbilityCheck', function(player, target, _ability)
    if not isShinobi(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local api = xi.overlords and xi.overlords.kurogane
    if not api or not api.hasLivingClones then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local count, _living, activeTarget = api.hasLivingClones(player)
    if count <= 0 or activeTarget == nil then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if target ~= nil and target.getID and target:getID() ~= activeTarget:getID() then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.shadow_legion.onUseAbility', function(player, target, ability)
    local api = xi.overlords and xi.overlords.kurogane
    if not api or not api.executeShadowLegion then
        ability:setMsg(xi.msg.basic.JA_NO_EFFECT)
        return 0
    end

    local ok, count, estTotal = api.executeShadowLegion(player, target)
    if not ok then
        ability:setMsg(xi.msg.basic.JA_NO_EFFECT)
        return 0
    end

    ability:setMsg(xi.msg.basic.NONE)
    if player.printToPlayer then
        player:printToPlayer(
            string.format('[Shinobi] Shadow Legion! %d %s launched a coordinated strike (~%d dmg).',
                count, count == 1 and 'shadow' or 'shadows', estTotal or 0),
            xi.msg.channel.SYSTEM_3)
    end
    return estTotal or 0
end)

m:addOverride('xi.actions.abilities.phantom_assault.onAbilityCheck', function(player, _target, _ability)
    if not isShinobi(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local api = xi.overlords and xi.overlords.kurogane
    if not api or not api.hasLivingClones then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local count = api.hasLivingClones(player)
    if count <= 0 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.phantom_assault.onUseAbility', function(player, _target, ability)
    local api = xi.overlords and xi.overlords.kurogane
    if not api or not api.executePhantomAssault then
        ability:setMsg(xi.msg.basic.JA_NO_EFFECT)
        return 0
    end

    local ok, boosted, dur = api.executePhantomAssault(player)
    if not ok then
        ability:setMsg(xi.msg.basic.JA_NO_EFFECT)
        return 0
    end

    ability:setMsg(xi.msg.basic.NONE)
    if player.printToPlayer then
        player:printToPlayer(
            string.format('[Shinobi] Phantom Assault! %d living %s accelerated (-25%% attack interval) for %ds.',
                boosted, boosted == 1 and 'shadow' or 'shadows', dur or 8),
            xi.msg.channel.SYSTEM_3)
    end
    return 0
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
    player:addListener('WEAPONSKILL_USE', 'OX_NIN_WS_SHADOW', function(actor, target, wsId)
        if not isKagemusha(actor) then
            return
        end

        local wsNum   = (type(wsId) == 'number') and wsId or (wsId ~= nil and wsId.getID and wsId:getID() or 0)
        local wsEntry = xi.data and xi.data.weaponskill and xi.data.weaponskill[wsNum]
        local isKatanaWs = (wsEntry ~= nil and wsEntry.skill == xi.skill.KATANA) or (wsEntry == nil and wsNum >= 128 and wsNum <= 143)
        if not isKatanaWs then
            return
        end

        -- Refresh Shadow Smoke (and EFF_OX_DEB_CRIPPLE) on each target hit
        if target ~= nil and target.hasStatusEffect and target:hasStatusEffect(EFFECT_SHADOW_SMOKE) then
            local smoke = target:getStatusEffect(EFFECT_SHADOW_SMOKE)
            if smoke then
                local st = math.max(1, math.min(4, smoke:getPower() or 1))
                smoke:setDuration(15000)
                applySharedCripple(target, actor, st, 15)
            end
        end

        -- Primary-cast-gated Kawarimi Ash cashout (3 stacks -> +1 shadow & 8/10/12/14% Max HP heal)
        local charId = actor.getID and actor:getID() or 0
        local now    = xi.overlords.nowSec()
        local isPrimary = (charId == 0) or ((now - (lastWsCastAtByChar[charId] or 0)) > 0.05)
        if isPrimary and charId > 0 then
            lastWsCastAtByChar[charId] = now
            if consumeKawarimiAsh(actor, 3) then
                local cur = actor:getMod(xi.mod.UTSUSEMI)
                if cur < 5 then
                    setUtsusemiShadows(actor, math.min(5, cur + 1))
                    updateYoninShadowDt(actor)
                end
                local healPct = scaleTier(actor:getMainLvl(), 0.08, 0.10, 0.12, 0.14)
                local heal    = math.max(1, math.floor((actor:getMaxHP() or 0) * healPct))
                actor:addHP(heal)
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
            -- Canonical NIN branch 1 is Shinobi (legacy key kurogane); Kagemusha is branch 2.
            -- Keeping these IDs unique prevents the later Kurogane additive
            -- registration from leaving a stale kagemusha -> branch 1 key.
            id             = 2,
            key            = KAGEMUSHA_KEY,
            name           = 'Kagemusha',
            role           = 'Shadow & Ninjutsu Tank',
            icon           = 'onyx_tome',
            extraTraits    = { TRAIT_KAGEMUSHA_PHANTOM },
            extraAbilities = { ABIL_YONIN, ABIL_FUTAE, ABIL_KAGE_BUNSHIN, ABIL_SMOKE_LOTUS },
            description    = 'Decoy-detonating shadow & ninjutsu tank (Lv10+, Dual Katanas): unlocks zero-tool Ninjutsu & Utsusemi Ichi/Ni @ Lv10+, converts broken shadows into Kawarimi Ash & Shadow Smoke, and intercepts tankbusters with Migawari.',
            highlights     =
            {
                'Passives (Lv10/30/50/70+): +12/16/20/25% Max HP, +8/14/20/26 VIT & AGI, +10/16/22/28% DEF, -6/9/12/16% DT, +12/20/28/38 MEVA, +8/12/16/20% Parry (Inquartata), +60/80/100/120 Enmity & +25/35/45/60% Retention.',
                'Dual Katana & Ninjutsu Mastery: +15/25/35/50 Katana & Ninjutsu skill, +15/22/30/38 Subtle Blow, -20/30/40/50% Ninjutsu Cast Time, 100% SIRD, and 0 Ninja Tool consumption.',
                'Shadow Economy & Kawarimi Ash: Ichi (3 shadows, 1.5s/18s) & Ni (4 shadows, 1.2s/28s) overwrite cleanly; broken shadows grant +35 TP, VE, Shadow Smoke (-4% ATTP/MATT, -6 ACC/stack, max 4), and +1 Kawarimi Ash; AoEs consume max 2 shadows w/ 50% bleedthrough.',
                'Katana WS Sustain & Custom JAs: Katana WSs refresh Shadow Smoke & spend 3 Ash for +1 shadow + 8/10/12/14% HP; Kage Bunshin (45s CD: +3 shadows, 1 cleanse, -15% MDT 6s); Smoke Lotus (30s CD: 4x Shadow Smoke, 20% Slow, +2 Ash).',
                'Tank JAs: Yonin (15s CD: +30 Enmity, +25 MACC, -18% DT & +15% Parry at 0 shadows); Futae (45s CD: instant Ninjutsu, 2.5x VE, 2s Stun, Expose -25 MEVA); Mijin Gakure (120s CD: 12s Migawari intercept negating >30% HP hits, +25% HP, +4 shadows).',
            },
            mods = function(player, lvl)
                local isWiki = (player == nil) or (not player.getEquipID)
                local l = lvl or (player and player:getMainLvl()) or 1
                if not isWiki then
                    syncKagemushaVarsAndSpells(player, true)
                end

                local mods =
                {
                    { xi.mod.HPP,                   scaleTier(l, 12, 16, 20, 25) },
                    { xi.mod.VIT,                   scaleTier(l, 8, 14, 20, 26) },
                    { xi.mod.AGI,                   scaleTier(l, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(l, 10, 16, 22, 28) },
                    { xi.mod.DMG,                   scaleTier(l, -600, -900, -1200, -1600) },
                    { xi.mod.MEVA,                  scaleTier(l, 12, 20, 28, 38) },
                    { xi.mod.ENMITY,                scaleTier(l, 60, 80, 100, 120) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(l, 25, 35, 45, 60) },
                }

                if isWiki or isDualKatanasEquipped(player) then
                    table.insert(mods, { xi.mod.KATANA,         scaleTier(l, 15, 25, 35, 50) })
                    table.insert(mods, { xi.mod.NINJUTSU,       scaleTier(l, 15, 25, 35, 50) })
                    table.insert(mods, { xi.mod.SUBTLE_BLOW,    scaleTier(l, 15, 22, 30, 38) })
                    table.insert(mods, { xi.mod.INQUARTATA,     scaleTier(l, 8, 12, 16, 20) })
                    table.insert(mods, { xi.mod.SPELLINTERRUPT, 100 })
                    table.insert(mods, { xi.mod.NINJA_TOOL,     100 })
                end

                return mods
            end,
            onRemove = function(player)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_NIN_CAST_REDUCT', 0)
                    player:setLocalVar('OX_NIN_RECAST_REDUCT', 0)
                    player:setLocalVar('OX_NIN_ASH', 0)
                    player:setLocalVar('OX_NIN_ASH_EXP', 0)
                    player:setLocalVar('OX_NIN_MIGAWARI_EXP', 0)
                end
                updateYoninShadowDt(player)
            end,
        },
    })
    -- Additive registration avoids replacing the existing Kagemusha tank entry.
    spec.registerCrystal(xi.job.NIN, {
            id             = 1,
            key            = KUROGANE_KEY,
            name           = 'Shinobi',
            role           = 'Damage',
            icon           = 'kurogane',
            reqLevel       = 10,
            extraAbilities = { ABIL_SHADOW_LEGION, ABIL_PHANTOM_ASSAULT },
            description    = 'Tier 1 Pure Physical DPS Ninja (Lv10+, Katana): shadow-clone commander that converts Utsusemi Ichi/Ni into up to 5 independent offensive shadow clones, commanding them with Shadow Legion and Phantom Assault.',
            highlights     =
            {
                'Tier 1 Damage: PHYS_DMG_DEALT, MAG_DMG_DEALT, and RANGED_DMG_DEALT remain at 0 (full DPS scaling).',
                'Passives (Lv10/30/50/70+): +10/16/22/28 STR & DEX, +15/25/35/50 Katana skill, +8/12/16/20% Attack, +5/8/12/16% WS damage, +5/8/11/14 Double Attack, +5/10/15/20 Store TP, and -20/-25/-30/-40 Enmity.',
                'Offensive Utsusemi (Shadow Squadron): Utsusemi: Ichi summons 2 offensive clones and Utsusemi: Ni summons 3 (max 5 active, 25-30s lifetime, up to 170 HP at Lv75); clones copy your look and attack your engaged target independently.',
                'Shadow Legion (90s CD): Every surviving shadow launches a staggered single-target coordinated strike at your engaged enemy.',
                'Phantom Assault (30s CD, 8s): Reduces the native autoattack interval of all currently living shadows by 25% (~33.3% faster attacks) for 8 seconds.',
            },
            mods = function(_player, lvl)
                local l = lvl or 10
                return
                {
                    { xi.mod.STR, scaleTier(l, 10, 16, 22, 28) },
                    { xi.mod.DEX, scaleTier(l, 10, 16, 22, 28) },
                    { xi.mod.KATANA, scaleTier(l, 15, 25, 35, 50) },
                    { xi.mod.ATTP, scaleTier(l, 8, 12, 16, 20) },
                    { xi.mod.ALL_WSDMG_ALL_HITS, scaleTier(l, 5, 8, 12, 16) },
                    { xi.mod.DOUBLE_ATTACK, scaleTier(l, 5, 8, 11, 14) },
                    { xi.mod.STORETP, scaleTier(l, 5, 10, 15, 20) },
                    { xi.mod.ENMITY, scaleTier(l, -20, -25, -30, -40) },
                }
            end,
            onApply = function(player)
                -- Entity backend will bind live clone lifecycle to this Soul activation.
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_KRG_CLONE_COUNT', 0)
                end
            end,
            onRemove = function(player)
                -- Backend shutdown hook must destroy owned NPCs before clearing telemetry.
                if xi.overlords.kurogane and xi.overlords.kurogane.dismissAll then
                    xi.overlords.kurogane.dismissAll(player)
                end
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_KRG_CLONE_COUNT', 0)
                end
            end,
        })
end

return m
