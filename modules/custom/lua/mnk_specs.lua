-----------------------------------
-- OverlordsXI Monk Crystal Specs
-- Registers Monk crystals:
--   1) Sensei     (Staff Evasion & Counter Tank)
--   2) Black Belt (Hand-to-Hand Martial DPS)
--   3) Chi Weaver (Unarmed Ranged Chi & Pulse Healer)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/monk')
-----------------------------------
local m = Module:new('overlords_mnk_specs')

local spec = xi.overlords.spec

local SENSEI_KEY    = 'sensei'
local BLACKBELT_KEY = 'blackbelt'
local CHIWEAVER_KEY = 'chiweaver'

-- Custom Job Ability IDs (429-431)
local ABIL_RESONANT_CHI   = 429
local ABIL_TRANQUIL_LOTUS = 430
local ABIL_INNER_HARMONY  = 431

-- Custom Status Effect IDs (829-830, within MAX_EFFECTID = 832)
local EFFECT_TRANQUIL_LOTUS = 829
local EFFECT_INNER_HARMONY  = 830

-- Custom Job Trait IDs (143, 153, 154)
local TRAIT_SENSEI_FLOW        = 143
local TRAIT_BLACKBELT_MASTERY  = 153
local TRAIT_CHIWEAVER_PULSE    = 154
local CHIWEAVER_MAX_STACKS     = 100
local CHIWEAVER_BOOST_SUBPOWER = 2

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.RESONANT_CHI   = ABIL_RESONANT_CHI
xi.jobAbility.TRANQUIL_LOTUS = ABIL_TRANQUIL_LOTUS
xi.jobAbility.INNER_HARMONY  = ABIL_INNER_HARMONY

xi.effect = xi.effect or {}
xi.effect.CHIWEAVER_LOTUS   = EFFECT_TRANQUIL_LOTUS
xi.effect.CHIWEAVER_HARMONY = EFFECT_INNER_HARMONY

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.resonant_chi   = xi.actions.abilities.resonant_chi or {}
xi.actions.abilities.tranquil_lotus = xi.actions.abilities.tranquil_lotus or {}
xi.actions.abilities.inner_harmony  = xi.actions.abilities.inner_harmony or {}

xi.effects = xi.effects or {}
xi.effects.chiweaver_lotus   = xi.effects.chiweaver_lotus or {}
xi.effects.chiweaver_harmony = xi.effects.chiweaver_harmony or {}

xi.overlords = xi.overlords or {}
xi.overlords.mnk = xi.overlords.mnk or {}

local pendingMantraMods    = {}
local pendingChiEffectMods = {}

local REMOVABLE_DEBUFFS =
{
    xi.effect.POISON,
    xi.effect.PARALYSIS,
    xi.effect.BLINDNESS,
    xi.effect.SILENCE,
    xi.effect.SLOW,
    xi.effect.WEIGHT,
    xi.effect.BIND,
    xi.effect.PLAGUE,
    xi.effect.DISEASE,
    xi.effect.CURSE_I,
    xi.effect.CURSE_II,
    xi.effect.ADDLE,
    xi.effect.DEFENSE_DOWN,
    xi.effect.MAGIC_DEF_DOWN,
    xi.effect.ATTACK_DOWN,
    xi.effect.ACCURACY_DOWN,
}

local function scaleTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 and lv70 ~= nil then
        return lv70
    elseif l >= 50 then
        return lv50
    elseif l >= 30 then
        return lv30
    end
    return lv10
end

local function isMonkSpec(entity, specKey)
    if entity == nil or not entity:isPC() or entity:getMainJob() ~= xi.job.MNK then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.MNK, specKey)
end

local function tellRateLimited(player, message)
    if player == nil or not player.printToPlayer then
        return
    end
    local now = os.time()
    local last = player.getLocalVar and (player:getLocalVar('OX_MNK_GATE_MSG_TS') or 0) or 0
    if now - last >= 2 then
        if player.setLocalVar then
            player:setLocalVar('OX_MNK_GATE_MSG_TS', now)
        end
        player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
    end
end

local function isStaffEquipped(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    if not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end

    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.STAFF
end

local function isHandToHandOrUnarmed(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    local mainItem = player.getEquippedItem and player:getEquippedItem(xi.slot.MAIN) or nil
    if mainItem ~= nil and mainItem.getSkillType and mainItem:getSkillType() ~= xi.skill.HAND_TO_HAND then
        return false
    end

    local subItem = player.getEquippedItem and player:getEquippedItem(xi.slot.SUB) or nil
    if subItem ~= nil and subItem.getSkillType and subItem:getSkillType() ~= xi.skill.HAND_TO_HAND then
        return false
    end

    return true
end

local function isCompletelyUnarmed(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    local mainItem = player.getEquippedItem and player:getEquippedItem(xi.slot.MAIN) or nil
    local subItem  = player.getEquippedItem and player:getEquippedItem(xi.slot.SUB) or nil
    return mainItem == nil and subItem == nil
end

local function enforceMnkWeaponGate(player)
    if player == nil or not player:isPC() or player:getMainJob() ~= xi.job.MNK then
        return
    end

    if isMonkSpec(player, BLACKBELT_KEY) then
        local removed = false
        local mainItem = player:getEquippedItem(xi.slot.MAIN)
        if mainItem ~= nil and mainItem.getSkillType and mainItem:getSkillType() ~= xi.skill.HAND_TO_HAND then
            player:unequipItem(xi.slot.MAIN)
            removed = true
        end
        local subItem = player:getEquippedItem(xi.slot.SUB)
        if subItem ~= nil and subItem.getSkillType and subItem:getSkillType() ~= xi.skill.HAND_TO_HAND then
            player:unequipItem(xi.slot.SUB)
            removed = true
        end
        if removed then
            tellRateLimited(player, 'Black Belt can only fight with Hand-to-Hand weapons or bare fists (no Staff, Club, or non-H2H weapons).')
        end
    elseif isMonkSpec(player, CHIWEAVER_KEY) then
        local removed = false
        if player:getEquippedItem(xi.slot.MAIN) ~= nil then
            player:unequipItem(xi.slot.MAIN)
            removed = true
        end
        if player:getEquippedItem(xi.slot.SUB) ~= nil then
            player:unequipItem(xi.slot.SUB)
            removed = true
        end
        if removed then
            tellRateLimited(player, 'Chi Weaver channels bare-handed Chi and cannot equip anything in Main or Sub weapon slots.')
        end
    end
end

local function grantEnmity(mob, player, ce, ve)
    if mob == nil or player == nil or mob == player then
        return
    end

    if mob.addEnmity then
        mob:addEnmity(player, ce, ve)
    elseif mob.updateEnmityFromDamage then
        mob:updateEnmityFromDamage(player, math.floor((ce + ve) / 4))
    end
end

-----------------------------------
-- Custom Chi Weaver Effect Mod Helpers
-----------------------------------
local function applyPendingChiEffectMods(target, effect)
    if target == nil or effect == nil then
        return
    end

    local targetId = target.getID and target:getID() or nil
    if targetId == nil then
        return
    end

    local mods = pendingChiEffectMods[targetId]
    if mods == nil then
        return
    end

    pendingChiEffectMods[targetId] = nil
    for _, pair in ipairs(mods) do
        if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
            effect:addMod(pair[1], pair[2])
        end
    end
end

for _, effKey in ipairs({ 'chiweaver_lotus', 'chiweaver_harmony' }) do
    xi.effects[effKey] = xi.effects[effKey] or {}
    xi.effects[effKey].onEffectGain = function(target, effect)
        applyPendingChiEffectMods(target, effect)
    end
    xi.effects[effKey].onEffectLose = function(_target, _effect)
    end
    m:addOverride('xi.effects.' .. effKey .. '.onEffectGain', function(target, effect)
        applyPendingChiEffectMods(target, effect)
    end)
    m:addOverride('xi.effects.' .. effKey .. '.onEffectLose', function(_target, _effect)
    end)
end

local function applyTimedChiEffect(target, effectId, power, duration, origin, iconId, mods)
    if target == nil or not target.addStatusEffect then
        return false
    end

    if target.hasStatusEffect and target:hasStatusEffect(effectId) and target.delStatusEffectSilent then
        target:delStatusEffectSilent(effectId)
    end

    local targetId = target.getID and target:getID() or 0
    pendingChiEffectMods[targetId] = mods

    local ok = target:addStatusEffect(effectId,
    {
        power    = power or 1,
        duration = duration or 15,
        origin   = origin or target,
        icon     = iconId or effectId,
    })

    local leftover = pendingChiEffectMods[targetId]
    pendingChiEffectMods[targetId] = nil
    if ok and type(leftover) == 'table' then
        local eff = target.getStatusEffect and target:getStatusEffect(effectId) or nil
        if eff ~= nil and eff.addMod then
            for _, pair in ipairs(leftover) do
                if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                    eff:addMod(pair[1], pair[2])
                end
            end
        end
    end

    return ok
end

local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

-----------------------------------
-- Healing Pulse Helpers (Centered Around Target Mob / Origin)
-----------------------------------
local function cleanseDebuffs(entity, maxCount)
    if entity == nil or not entity.hasStatusEffect or not entity.delStatusEffect then
        return 0
    end

    local removed = 0
    for _, effId in ipairs(REMOVABLE_DEBUFFS) do
        if effId ~= nil and entity:hasStatusEffect(effId) then
            entity:delStatusEffect(effId)
            removed = removed + 1
            if removed >= (maxCount or 1) then
                break
            end
        end
    end
    return removed
end

local function getAlliedRecipientsNearCenter(caster, centerEntity, radius, secondaryCenter)
    local out  = {}
    local seen = {}
    if caster == nil or (centerEntity == nil and secondaryCenter == nil) then
        return out
    end

    local maxDist = radius or 12.0

    local function consider(ent)
        if ent == nil or not ent.isAlive or not ent:isAlive() then
            return
        end
        local id = ent.getID and ent:getID() or nil
        if id == nil or seen[id] then
            return
        end
        local inRange = false
        if centerEntity ~= nil and centerEntity.checkDistance and centerEntity:checkDistance(ent) <= maxDist then
            inRange = true
        elseif secondaryCenter ~= nil and secondaryCenter.checkDistance and secondaryCenter:checkDistance(ent) <= maxDist then
            inRange = true
        end
        if inRange then
            seen[id] = true
            table.insert(out, ent)
        end
    end

    local roster = {}
    if caster.getPartyWithTrusts then
        roster = caster:getPartyWithTrusts() or {}
    elseif caster.getParty then
        roster = caster:getParty() or {}
    else
        roster = { caster }
    end

    if #roster == 0 then
        roster = { caster }
    end

    for _, member in ipairs(roster) do
        consider(member)
        if member ~= nil and member.getPet then
            consider(member:getPet())
        end
    end

    consider(caster)
    if caster.getPet then
        consider(caster:getPet())
    end

    return out
end

local function pulseHealAroundCenter(caster, centerEntity, baseHeal, radius, cleanseCount, secondaryCenter)
    if caster == nil or (centerEntity == nil and secondaryCenter == nil) or baseHeal <= 0 then
        return 0, 0
    end

    local recipients = getAlliedRecipientsNearCenter(caster, centerEntity, radius or 12.0, secondaryCenter)
    local totalHealed = 0
    local countHealed = 0

    for _, recipient in ipairs(recipients) do
        if (cleanseCount or 0) > 0 then
            cleanseDebuffs(recipient, cleanseCount)
        end

        local curHp = recipient.getHP and recipient:getHP() or 0
        local maxHp = recipient.getMaxHP and recipient:getMaxHP() or 0
        if maxHp > 0 and curHp < maxHp then
            local rcvdMod = recipient.getMod and (recipient:getMod(xi.mod.CURE_POTENCY_RCVD) or 0) or 0
            local rcvdMult = math.max(0.5, 1.0 + (rcvdMod / 100.0))
            local desired = math.max(1, math.floor(baseHeal * rcvdMult))
            local healed = 0
            if recipient.addHP then
                healed = tonumber(recipient:addHP(desired)) or 0
            elseif recipient.restoreHP then
                healed = tonumber(recipient:restoreHP(desired)) or 0
            end

            if healed > 0 then
                totalHealed = totalHealed + healed
                countHealed = countHealed + 1
                if
                    caster.messagePublic and
                    xi.msg and
                    xi.msg.basic and
                    xi.msg.basic.RECOVERS_HP
                then
                    caster:messagePublic(xi.msg.basic.RECOVERS_HP, recipient, 0, healed)
                end
            end
        end
    end

    return totalHealed, countHealed
end

-----------------------------------
-- Chi Weaver Boost Stack Helpers (1..100 on xi.effect.BOOST)
-----------------------------------
local function getChiBoostStacks(player)
    if player == nil or not player.getStatusEffect or not xi.effect or not xi.effect.BOOST then
        return 0
    end

    local eff = player:getStatusEffect(xi.effect.BOOST)
    if eff ~= nil and eff.getSubPower and eff:getSubPower() == CHIWEAVER_BOOST_SUBPOWER then
        return utils.clamp(math.floor(eff:getPower() or 0), 0, CHIWEAVER_MAX_STACKS)
    end

    return 0
end

local function sendChiBoostSync(player, force)
    if player == nil or (player.isPC and not player:isPC()) or not player.printToPlayer then
        return
    end

    local active = isMonkSpec(player, CHIWEAVER_KEY) and 1 or 0
    local stacks = (active == 1) and getChiBoostStacks(player) or 0
    local remSec = 0

    if active == 1 and stacks > 0 and player.getStatusEffect and xi.effect and xi.effect.BOOST then
        local eff = player:getStatusEffect(xi.effect.BOOST)
        if eff ~= nil and eff.getSubPower and eff:getSubPower() == CHIWEAVER_BOOST_SUBPOWER and eff.getTimeRemaining then
            remSec = math.max(0, math.ceil((eff:getTimeRemaining() or 0) / 1000))
        end
    end

    local prevActive = player.getLocalVar and (player:getLocalVar('OX_CHW_SYNC_ACT') or -1) or -1
    local prevStacks = player.getLocalVar and (player:getLocalVar('OX_CHW_SYNC_STK') or -1) or -1
    if not force and prevActive == active and prevStacks == stacks then
        return
    end

    if player.setLocalVar then
        player:setLocalVar('OX_CHW_SYNC_ACT', active)
        player:setLocalVar('OX_CHW_SYNC_STK', stacks)
    end

    player:printToPlayer(
        string.format('[OXBST]|%u|%u|%u|%u', active, stacks, CHIWEAVER_MAX_STACKS, remSec),
        xi.msg.channel.SYSTEM_3,
        ''
    )
end

xi.overlords.mnk.sendChiBoostSync = sendChiBoostSync

local function setChiBoostStacks(player, newStacks, notifyMilestones)
    if player == nil then
        return 0
    end

    local prev    = getChiBoostStacks(player)
    local clamped = utils.clamp(math.floor(newStacks or 0), 0, CHIWEAVER_MAX_STACKS)

    if player.setLocalVar then
        player:setLocalVar('OX_CHW_CHI_STACKS', clamped)
    end

    if xi.effect and xi.effect.BOOST then
        if clamped <= 0 then
            if player.getStatusEffect and player.delStatusEffectSilent then
                local eff = player:getStatusEffect(xi.effect.BOOST)
                if eff ~= nil and eff.getSubPower and eff:getSubPower() == CHIWEAVER_BOOST_SUBPOWER then
                    player:delStatusEffectSilent(xi.effect.BOOST)
                end
            end
            if prev > 0 then
                sendChiBoostSync(player, true)
            else
                sendChiBoostSync(player, false)
            end
            return 0
        end

        if player.delStatusEffectSilent and player.addStatusEffect then
            player:delStatusEffectSilent(xi.effect.BOOST)
            player:addStatusEffect(xi.effect.BOOST,
            {
                power    = clamped,
                duration = 180,
                origin   = player,
                subPower = CHIWEAVER_BOOST_SUBPOWER,
            })
        end
    end

    if notifyMilestones and clamped > prev then
        if clamped == CHIWEAVER_MAX_STACKS and prev < CHIWEAVER_MAX_STACKS then
            tellRateLimited(player, string.format('Chi Weaver Boost: %d/%d (MAX) - Chi Blast ready!', clamped, CHIWEAVER_MAX_STACKS))
        elseif math.floor(prev / 25) < math.floor(clamped / 25) then
            tellRateLimited(player, string.format('Chi Weaver Boost: %d/%d stacks.', clamped, CHIWEAVER_MAX_STACKS))
        end
    end

    sendChiBoostSync(player, true)

    return clamped
end

local function addChiBoostStacks(player, delta, notifyMilestones)
    if player == nil then
        return 0
    end
    local cur = getChiBoostStacks(player)
    return setChiBoostStacks(player, cur + (delta or 1), notifyMilestones)
end

-----------------------------------
-- Sensei Staff Riposte Helpers
-----------------------------------
local function dealStaffRiposte(defender, attacker, isDodgeBonus)
    if
        defender == nil or
        attacker == nil or
        attacker == defender or
        (attacker.isAlive and not attacker:isAlive())
    then
        return 0
    end

    local weaponDmg = defender.getWeaponDmg and (defender:getWeaponDmg() or 0) or 0
    local strStat = defender.getStat and xi.mod and xi.mod.STR and (defender:getStat(xi.mod.STR) or 0) or 0
    local agiStat = defender.getStat and xi.mod and xi.mod.AGI and (defender:getStat(xi.mod.AGI) or 0) or 0
    local counterDmg = defender.getMod and xi.mod and xi.mod.COUNTER_DAMAGE and (defender:getMod(xi.mod.COUNTER_DAMAGE) or 0) or 0
    local lvl = defender.getMainLvl and (defender:getMainLvl() or 10) or 10

    local damage
    if isDodgeBonus then
        local raw = math.floor(weaponDmg * 0.25) + math.floor(agiStat * 0.10) + math.floor(lvl * 0.15) + math.floor(counterDmg * 0.30)
        local mult = (defender.hasStatusEffect and xi.effect and xi.effect.DODGE and defender:hasStatusEffect(xi.effect.DODGE)) and 1.25 or 1.0
        damage = math.max(2, math.floor(raw * mult))
    else
        local raw = math.floor(weaponDmg * 0.35) + math.floor(strStat * 0.12) + math.floor(lvl * 0.20) + math.floor(counterDmg * 0.40)
        damage = math.max(3, math.floor(raw * 1.1))
    end

    local dealt = damage
    if attacker.takeDamage and xi.attackType and xi.damageType then
        local res = attacker:takeDamage(damage, defender, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
        if type(res) == 'number' then
            dealt = res
        end
    end

    if dealt > 0 then
        local hitMsg = (xi.msg and xi.msg.basic and xi.msg.basic.HIT_DMG) or 1
        if defender.messagePublic then
            defender:messagePublic(hitMsg, attacker, dealt, dealt)
        end
    end

    return dealt
end

-----------------------------------
-- Spec Listener Lifecycle
-----------------------------------
local function detachSenseiListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_MNK_ATTACKED')
    end
end

local function attachSenseiListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachSenseiListeners(player)

    player:addListener('ATTACKED', 'OX_MNK_ATTACKED', function(defender, attacker, action)
        if
            defender == nil or
            attacker == nil or
            attacker == defender or
            not isMonkSpec(defender, SENSEI_KEY) or
            not isStaffEquipped(defender) or
            action == nil or
            not action.getMsg
        then
            return
        end

        local msg = action:getMsg(defender:getID())
        local missMsg = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if msg ~= missMsg then
            return
        end

        if defender.addTP then
            defender:addTP(50)
        end

        local maxHp = defender.getMaxHP and (defender:getMaxHP() or 0) or 0
        if maxHp > 0 and defender.addHP then
            local heal = math.max(6, math.floor(maxHp * 0.015))
            defender:addHP(heal)
        end

        grantEnmity(attacker, defender, 120, 280)
        dealStaffRiposte(defender, attacker, true)
    end)
end

local function detachBlackBeltListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_BLB_WS')
    end
end

local function attachBlackBeltListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachBlackBeltListeners(player)

    -- Martial Flow: Hand-to-Hand Weaponskills refund 75 TP to sustain relentless combo chains.
    player:addListener('WEAPONSKILL_USE', 'OX_BLB_WS', function(actor, _target, _skill, _tp, _action)
        if
            actor ~= nil and
            isMonkSpec(actor, BLACKBELT_KEY) and
            isHandToHandOrUnarmed(actor) and
            actor.addTP
        then
            actor:addTP(75)
        end
    end)
end

local function computeChiPulseBaseHeal(player, lvl, mndStat, mult)
    local curePot  = 1.0 + (math.max(0, (player.getMod and player:getMod(xi.mod.CURE_POTENCY)) or 0) / 100.0)
    local h2hSkill = player.getSkillLevel and (player:getSkillLevel(xi.skill.HAND_TO_HAND) or 0) or 0
    return math.max(10, math.floor((12 + (lvl * 1.4) + (mndStat * 1.05) + (h2hSkill * 0.12)) * curePot * (mult or 1.0)))
end

local function detachChiWeaverListeners(player, keepStacks)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_CHW_WS')
    end
    if not keepStacks then
        setChiBoostStacks(player, 0, false)
    end
end

local function attachChiWeaverListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachChiWeaverListeners(player, true)
    sendChiBoostSync(player, true)

    -- Flowing Chi: Landed bare-handed Hand-to-Hand Weaponskills work up to 20y, preserve & build Boost stacks, and emit a modest 12y healing pulse around the target.
    player:addListener('WEAPONSKILL_USE', 'OX_CHW_WS', function(actor, target, _ws, tp, _action, dmg)
        if actor == nil or not isMonkSpec(actor, CHIWEAVER_KEY) then
            return
        end

        -- Core LandSandBoat calculateRawWSDmg deletes xi.effect.BOOST during WS execution; restore Chi Weaver's stacked Boost buff.
        local savedStacks = actor.getLocalVar and (actor:getLocalVar('OX_CHW_CHI_STACKS') or 0) or 0
        if savedStacks > 0 and getChiBoostStacks(actor) == 0 then
            setChiBoostStacks(actor, savedStacks, false)
        end

        if
            target == nil or
            target == actor or
            (dmg ~= nil and dmg <= 0) or
            not isCompletelyUnarmed(actor)
        then
            return
        end

        local tpVal      = math.max(1000, tonumber(tp) or 1000)
        local wsStacks   = (tpVal >= 2000 and 5) or (tpVal >= 1500 and 4) or 3
        addChiBoostStacks(actor, wsStacks, true)

        local lvl        = actor.getMainLvl and (actor:getMainLvl() or 10) or 10
        local mndStat    = actor.getStat and (actor:getStat(xi.mod.MND) or 10) or 10
        local hasHarmony = actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_INNER_HARMONY)
        local pulseMult  = (0.40 + ((tpVal - 1000) / 2000.0) * 0.25) * (hasHarmony and 1.40 or 1.0)
        local baseHeal   = computeChiPulseBaseHeal(actor, lvl, mndStat, pulseMult)
        local cleanse    = (tpVal >= 2000) and 1 or 0
        pulseHealAroundCenter(actor, target, baseHeal, 12.0, cleanse)

        if
            actor.checkDistance and
            actor:checkDistance(target) > 12.0 and
            actor.getHP and
            actor.getMaxHP and
            actor.addHP and
            actor:getHP() < actor:getMaxHP()
        then
            actor:addHP(math.max(4, math.floor(baseHeal * 0.35)))
        end
    end)
end

-----------------------------------
-- Chi Weaver Ranged Chi Auto-Attack Entry Point (C++ Patch 0021)
-----------------------------------
function xi.overlords.mnk.executeChiRangedAttack(player, target, swingIndex)
    if
        player == nil or
        target == nil or
        not isMonkSpec(player, CHIWEAVER_KEY) or
        (player.isAlive and not player:isAlive()) or
        (target.isAlive and not target:isAlive())
    then
        return -2
    end

    if not isCompletelyUnarmed(player) then
        enforceMnkWeaponGate(player)
        if not isCompletelyUnarmed(player) then
            return -2
        end
    end

    local idx = tonumber(swingIndex)
    local isMultiRound = idx ~= nil
    local swingNum = idx or 1
    local hitScale = isMultiRound and 0.55 or 1.0
    local lvl = player.getMainLvl and (player:getMainLvl() or 10) or 10

    -- Compute unarmed Martial Arts + Haste delay once per attack round.
    if swingNum <= 1 then
        local maMod     = player.getMod and (player:getMod(xi.mod.MARTIAL_ARTS) or 0) or 0
        local baseDelay = math.max(210, 460 - math.floor(lvl * 1.8) - maMod)
        local hMagic    = utils.clamp((player:getMod(xi.mod.HASTE_MAGIC) or 0) / 10000.0, -1.0, 0.4375)
        local hAbil     = utils.clamp((player:getMod(xi.mod.HASTE_ABILITY) or 0) / 10000.0, -0.25, 0.25)
        local hGear     = math.min((player:getMod(xi.mod.HASTE_GEAR) or 0) / 10000.0, 0.25)
        local hasteMult = utils.clamp(1.0 - hMagic - hAbil - hGear, 0.20, 2.0)
        local delayMs   = math.floor((baseDelay * 6.0) * hasteMult)
        if player.hasStatusEffect and player:hasStatusEffect(xi.effect.HUNDRED_FISTS) then
            delayMs = math.floor(delayMs * 0.50)
        end
        delayMs = utils.clamp(delayMs, 600, 5000)
        if player.setLocalVar then
            player:setLocalVar('OX_CHI_NEXT_DELAY_MS', delayMs)
        end
    end

    -- Accuracy roll using MACC + partial ACC vs target EVA.
    local macc    = player.getMACC and (player:getMACC() or 0) or (player:getMod(xi.mod.MACC) or 0)
    local acc     = player.getACC and (player:getACC() or 0) or 0
    local tgtEva  = target.getEVA and (target:getEVA() or 0) or 0
    local hitRate = utils.clamp(math.floor(84 + ((macc * 0.6 + acc * 0.25 - tgtEva * 0.45) * 0.45)), 65, 99)
    if math.random(1, 100) > hitRate then
        return -1
    end

    local mndStat  = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
    local h2hSkill = player.getSkillLevel and (player:getSkillLevel(xi.skill.HAND_TO_HAND) or 0) or 0
    local mab      = player.getMod and (player:getMod(xi.mod.MATT) or 0) or 0
    local tgtMdef  = target.getMod and (target:getMod(xi.mod.MDEF) or 0) or 0
    local mabMult  = math.max(0.5, (100.0 + mab) / (100.0 + tgtMdef))

    if player.setLocalVar then
        player:setLocalVar('OX_CHW_BOOST_NEXT', 0)
    end

    local hasHarmony  = player.hasStatusEffect and player:hasStatusEffect(EFFECT_INNER_HARMONY)
    local hasFormless = player.hasStatusEffect and player:hasStatusEffect(xi.effect.FORMLESS_STRIKES)
    local hasHundred  = player.hasStatusEffect and player:hasStatusEffect(xi.effect.HUNDRED_FISTS)

    local dmgMult = (hasHarmony and 1.20 or 1.0) * (hasFormless and 1.15 or 1.0)
    local rawDmg  = ((lvl * 0.42) + 2 + (mndStat * 0.18) + (h2hSkill * 0.04)) * mabMult * dmgMult * hitScale
    local dmg     = math.max(2, math.floor(rawDmg))

    local dealt = dmg
    if target.takeDamage and xi.attackType and xi.damageType then
        local res = target:takeDamage(dmg, player, xi.attackType.MAGICAL, xi.damageType.LIGHT)
        if type(res) == 'number' then
            dealt = math.max(0, res)
        end
    end

    if player.trySkillUp and target.getMainLvl then
        player:trySkillUp(xi.skill.HAND_TO_HAND, target:getMainLvl())
    end

    -- Grant TP + subtle enmity per landed fist.
    local storeTp  = player.getMod and (player:getMod(xi.mod.STORETP) or 0) or 0
    local baseTp   = isMultiRound and 40 or 75
    local mobFeed  = isMultiRound and 20 or 40
    if player.addTP then
        player:addTP(math.floor(baseTp * (1.0 + (storeTp / 100.0))))
    end
    if target.addTP then
        target:addTP(mobFeed)
    end
    if target.updateEnmityFromDamage then
        target:updateEnmityFromDamage(player, math.max(1, math.floor(dealt * 0.35)))
    end

    -- Stack +1 Boost stack per landed fist (up to 100) and emit a gentle 12y Chi pulse heal.
    addChiBoostStacks(player, 1, true)

    local pulseMult = 0.18
        * (hasHarmony and 1.40 or 1.0)
        * (hasFormless and 1.20 or 1.0)
        * (hasHundred and 1.25 or 1.0)
    local baseHeal = math.max(4, computeChiPulseBaseHeal(player, lvl, mndStat, pulseMult))
    pulseHealAroundCenter(player, target, baseHeal, 12.0, 0)

    -- If firing from outside the 12y target pulse (12-20y), also channel a light Chi mend to the Monk.
    if
        player.checkDistance and
        player:checkDistance(target) > 12.0 and
        player.getHP and
        player.getMaxHP and
        player.addHP and
        player:getHP() < player:getMaxHP()
    then
        player:addHP(math.max(3, math.floor(baseHeal * 0.35)))
    end

    return math.max(0, math.floor(dealt))
end

-----------------------------------
-- Crystal Definitions (MNK)
-----------------------------------
if xi.job and xi.job.MNK then
    spec.registerJob(xi.job.MNK, 'MNK',
    {
        {
            id          = 1,
            key         = SENSEI_KEY,
            name        = 'Sensei',
            role        = 'Staff Evasion & Counter Tank',
            icon        = 'jade_orb',
            reqLevel    = 10,
            extraAbilities = xi.jobAbility and xi.jobAbility.COUNTERSTANCE and { xi.jobAbility.COUNTERSTANCE } or nil,
            extraTraits    = { TRAIT_SENSEI_FLOW },
            description = 'Agile staff master (Lv10+): evades and parries incoming blows with a Staff, ripostes missed or parried strikes, and anchors aggro through Counterstance.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +12/22/35 Staff, +8/15/25 Acc, +12/24/40 Evasion Skill, +10/22/38 EVA, +5/10/15% EVA, +6/12/20 AGI.',
                'Counter & Deflection: +15/30/50 Parry Skill, +5/10/15% Parry Rate, +12/22/30% Counter, +8/16/28 Counter DMG, +15/25/40 Enmity, -25/40/60% Enmity Loss, +6/10/15% HP, -5/8/12% DT.',
                'Staff Riposte (w/ Staff): +12% Parry Rate; Parrying heals 2% Max HP, grants +75 TP, +Enmity, and strikes back. Evading grants 1.5% Max HP, +50 TP, +Enmity, and deals an Evasive Counter.',
                'Iron Counterstance (Lv10, 120s CD): +30% Counter, +20 Counter DMG, -10% DT, +20 Enmity, with no DEF halving penalty.',
                'Tank JAs: Dodge (60s, +25 EVA, +15% EVA, +12% Parry, +15 Enmity, +25% Evasive Counter DMG), Focus (+15% Counter, +15 Parry, +10 Counter DMG), Boost (+15 Enmity, +50 TP), Chi Blast (heavy Enmity + Acc Down), Chakra (+50% heal, Regen, cleanses Slow/Silence), Perfect Counter (45s CD, +25 Counter DMG, +25 Enmity, 5% heal), Mantra (party -5% DT), Inner Strength (60s, -25% DT, +20% EVA%, +30 Counter DMG, +50 Enmity).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.STAFF,                 scaleTier(lvl, 12, 22, 35) },
                    { xi.mod.ACC,                   scaleTier(lvl, 8, 15, 25) },
                    { xi.mod.EVASION,               scaleTier(lvl, 12, 24, 40) },
                    { xi.mod.EVA,                   scaleTier(lvl, 10, 22, 38) },
                    { xi.mod.EVA_PERCENT,           scaleTier(lvl, 5, 10, 15) },
                    { xi.mod.AGI,                   scaleTier(lvl, 6, 12, 20) },
                    { xi.mod.PARRY,                 scaleTier(lvl, 15, 30, 50) },
                    { xi.mod.INQUARTATA,            scaleTier(lvl, 5, 10, 15) },
                    { xi.mod.COUNTER,               scaleTier(lvl, 12, 22, 30) },
                    { xi.mod.COUNTER_DAMAGE,        scaleTier(lvl, 8, 16, 28) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 15, 25, 40) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 40, 60) },
                    { xi.mod.HPP,                   scaleTier(lvl, 6, 10, 15) },
                    { xi.mod.DMG,                   scaleTier(lvl, -500, -800, -1200) },
                }
            end,
            onApply = function(player)
                attachSenseiListeners(player)
            end,
            onRemove = function(player)
                detachSenseiListeners(player)
            end,
        },
        {
            id          = 2,
            key         = BLACKBELT_KEY,
            name        = 'Black Belt',
            role        = 'Hand-to-Hand Martial DPS',
            icon        = 'blackbelt',
            reqLevel    = 10,
            extraTraits = { TRAIT_BLACKBELT_MASTERY },
            description = 'Pure Hand-to-Hand striker (Lv10+): restricted strictly to Hand-to-Hand weapons or bare fists, trading weapon variety for relentless Kick Attacks, Double Attack, Crit, WSD, and TP flow.',
            highlights  =
            {
                'H2H Oath: Restricted strictly to Hand-to-Hand weapons or bare fists (cannot equip Staves, Clubs, or non-H2H weapons in Main/Sub).',
                'Passives (Lv10/30/50/70+): +10/20/32/45 H2H Skill, +8/16/26/38 Acc, +12/24/40/60 Attack, +6/10/15/20% Attack%, +5/8/12/16% Double Attack, +5/10/16/24 STR & DEX.',
                'Martial Relentlessness: +6/10/15/20% Kick Rate, +8/15/24/35 Kick DMG, +3/5/8/12% Crit Rate, +5/9/14/20 Store TP, +5/10/15/20 Subtle Blow, +6/10/16/22% WSD.',
                'Combo Momentum: Every Hand-to-Hand Weaponskill refunds +75 TP to sustain rapid skillchain pressure.',
                'Aggressive JAs: Boost (+100 TP, +8% Crit & +15% next WSD), Focus (+10% Crit, +15% Crit DMG, +25 Acc), Dodge (+10% Abil Haste, +15 Subtle Blow), Chakra (+30% heal, +150 TP, cleanses Para/Blind/Weight), Chi Blast (+35% DMG, -15% DEF Down, +100 TP), Footwork (+15 Kick DMG, +10% Kick Rate, +10% Atk%), Hundred Fists (+25% Atk%, +15% Crit, +20% DA, +20 Store TP).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HANDTOHAND,         scaleTier(lvl, 10, 20, 32, 45) },
                    { xi.mod.ACC,                scaleTier(lvl, 8, 16, 26, 38) },
                    { xi.mod.ATT,                scaleTier(lvl, 12, 24, 40, 60) },
                    { xi.mod.ATTP,               scaleTier(lvl, 6, 10, 15, 20) },
                    { xi.mod.DOUBLE_ATTACK,      scaleTier(lvl, 5, 8, 12, 16) },
                    { xi.mod.KICK_ATTACK_RATE,   scaleTier(lvl, 6, 10, 15, 20) },
                    { xi.mod.KICK_DMG,           scaleTier(lvl, 8, 15, 24, 35) },
                    { xi.mod.CRITHITRATE,        scaleTier(lvl, 3, 5, 8, 12) },
                    { xi.mod.STORETP,            scaleTier(lvl, 5, 9, 14, 20) },
                    { xi.mod.SUBTLE_BLOW,        scaleTier(lvl, 5, 10, 15, 20) },
                    { xi.mod.ALL_WSDMG_ALL_HITS, scaleTier(lvl, 6, 10, 16, 22) },
                    { xi.mod.STR,                scaleTier(lvl, 5, 10, 16, 24) },
                    { xi.mod.DEX,                scaleTier(lvl, 5, 10, 16, 24) },
                }
            end,
            onApply = function(player)
                enforceMnkWeaponGate(player)
                attachBlackBeltListeners(player)
            end,
            onRemove = function(player)
                detachBlackBeltListeners(player)
            end,
        },
        {
            id             = 3,
            key            = CHIWEAVER_KEY,
            name           = 'Chi Weaver',
            role           = 'Unarmed Ranged Chi & Pulse Healer',
            icon           = 'chiweaver',
            reqLevel       = 10,
            chiRanged      = { minLevel = 10, maxRange = 20 },
            extraAbilities = { ABIL_RESONANT_CHI, ABIL_TRANQUIL_LOTUS, ABIL_INNER_HARMONY },
            extraTraits    = { TRAIT_CHIWEAVER_PULSE },
            description    = 'Bare-handed Chi channeler (Lv10+): cannot equip weapons in Main or Sub slots, firing dual 20y Light Chi bolts and ranged H2H Weaponskills that stack Boost up to 100 for massive 5s-CD Chi Blast 20y party heals.',
            highlights     =
            {
                'Empty-Handed Vow: Cannot equip ANY weapon or item in Main or Sub slots (bare fists only).',
                'Dual-Fist Chi & Boost Stacking (0-20y): Auto-attacks unleash main & off-hand Light Chi bolts (+Kick procs) and ranged H2H Weaponskills work up to 20y. Every landed bolt grants +1 Boost stack (WS +3/+4/+5, max 100, +1 Cure Pot/MACC/MAB per 5 stacks) plus light sustain pulses.',
                'Healer Offense Tradeoff: -20% Attack% & -58% Weaponskill DMG; Light Chi bolts deal light healer chip damage in exchange for party sustain.',
                'Passives (Lv10/30/50/70+): +8/12/16/20% Max HP, +8/16/26/38 Regen, +8/16/26/36 MND, +5/10/16/24 VIT, +12/20/28/35% Cure Potency, +8/15/24/35 H2H, +10/20/32/45 MACC, +8/15/24/34 MAB, -12/18/25/32 Enmity, -3/5/8/10% DT.',
                'Custom JAs (Lv10+): Resonant Chi (20s CD, 20y Light burst + 1.75x target AoE heal & Cleanse), Tranquil Lotus (30s CD, 12y Party/Pet heal + 15s Regen, +Cure Rcvd, & Enmity-), Inner Harmony (45s CD, 18s +Cure Potency, +MAB/MACC, +Ability Haste, +Regen, & +40% Chi Bolt/Pulse power).',
                'Healer MNK JAs: Chi Blast (5s CD, 0 damage, consumes all 0-100 Boost stacks for a massive 20y party AoE heal + up to 3 debuff cleanses), Boost (+5 Boost stacks, +50 TP & light engaged pulse), Focus (+25 MACC, +20 MAB, +15% Cure Pot), Dodge (+30 EVA, -10% DT, -25 Enmity), Chakra (projects 45% AoE heal + self cleanse), Mantra (party Regen + Cure Rcvd%), Formless Strikes (+15% Chi DMG/+20% Pulse), Hundred Fists (2x Chi Bolt speed & +25% Pulse).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,          scaleTier(lvl, 8, 12, 16, 20) },
                    { xi.mod.REGEN,        scaleTier(lvl, 8, 16, 26, 38) },
                    { xi.mod.MND,          scaleTier(lvl, 8, 16, 26, 36) },
                    { xi.mod.VIT,          scaleTier(lvl, 5, 10, 16, 24) },
                    { xi.mod.CURE_POTENCY, scaleTier(lvl, 12, 20, 28, 35) },
                    { xi.mod.HANDTOHAND,   scaleTier(lvl, 8, 15, 24, 35) },
                    { xi.mod.MACC,         scaleTier(lvl, 10, 20, 32, 45) },
                    { xi.mod.MATT,         scaleTier(lvl, 8, 15, 24, 34) },
                    { xi.mod.ENMITY,       scaleTier(lvl, -12, -18, -25, -32) },
                    { xi.mod.DMG,          scaleTier(lvl, -300, -500, -800, -1000) },
                    { xi.mod.ATTP,         -20 },
                }
            end,
            onApply = function(player)
                enforceMnkWeaponGate(player)
                attachChiWeaverListeners(player)
            end,
            onRemove = function(player)
                detachChiWeaverListeners(player)
            end,
        },
    })
end

-----------------------------------
-- Chi Weaver Healer Weaponskill Damage Tradeoff
-----------------------------------
m:addOverride('xi.weaponskills.takeWeaponskillDamage', function(defender, attacker, wsParams, primaryMsg, attack, wsResults, action)
    if
        attacker ~= nil and
        isMonkSpec(attacker, CHIWEAVER_KEY) and
        type(wsResults) == 'table' and
        type(wsResults.finalDmg) == 'number' and
        wsResults.finalDmg > 0
    then
        wsResults.finalDmg = math.max(1, math.floor(wsResults.finalDmg * 0.42))
    end

    return super(defender, attacker, wsParams, primaryMsg, attack, wsResults, action)
end)

-----------------------------------
-- Early & Rapid Iron Counterstance / Perfect Counter (Sensei)
-----------------------------------
m:addOverride('xi.actions.abilities.counterstance.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        spec.ensureUpToDate(player)

        if isMonkSpec(player, SENSEI_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(120)
            end
        else
            local mnkLvl = 0
            if player:getMainJob() == xi.job.MNK then
                mnkLvl = player:getMainLvl()
            elseif player.getSubJob and player:getSubJob() == xi.job.MNK and player.getSubLvl then
                mnkLvl = player:getSubLvl()
            end

            if mnkLvl < 45 then
                return xi.msg.basic.UNABLE_TO_USE_JA, 0
            end
        end
    end

    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.perfect_counter.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isMonkSpec(player, SENSEI_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(45)
        end
    end

    return super(player, target, ability)
end)

-----------------------------------
-- Staff Parry Mastery & Riposte Overrides (Sensei)
-----------------------------------
m:addOverride('xi.combat.physical.calculateParryRate', function(defender, attacker)
    local rate = super(defender, attacker)

    if isMonkSpec(defender, SENSEI_KEY) and isStaffEquipped(defender) then
        rate = (tonumber(rate) or 0) + 12
        if defender.hasStatusEffect and defender:hasStatusEffect(xi.effect.DODGE) then
            rate = rate + 8
        end
        rate = utils.clamp(rate, 5, 75)
    end

    return rate
end)

m:addOverride('xi.combat.physical.isParried', function(defender, attacker)
    local parried = super(defender, attacker)

    if parried and isMonkSpec(defender, SENSEI_KEY) and isStaffEquipped(defender) then
        local maxHp = defender.getMaxHP and (defender:getMaxHP() or 0) or 0
        if maxHp > 0 and defender.addHP then
            local heal = math.max(8, math.floor(maxHp * 0.02))
            defender:addHP(heal)
        end

        if defender.addTP then
            defender:addTP(75)
        end

        grantEnmity(attacker, defender, 150, 350)
        dealStaffRiposte(defender, attacker, false)
    end

    return parried
end)

-----------------------------------
-- Monk Ability & Effect Overrides (All Specs)
-----------------------------------
m:addOverride('xi.job_utils.monk.useCounterstance', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    target:delStatusEffect(xi.effect.COUNTERSTANCE)

    -- subType = 1 bypasses the C++ HasStatusEffect(Counterstance, 0) DEF-halving penalty
    -- while preserving effect presence for Job Point Counterstance Attack bonuses.
    local pTable =
    {
        power    = 30 + player:getMod(xi.mod.COUNTERSTANCE_EFFECT),
        duration = 300,
        origin   = player,
        subType  = 1,
        subPower = 1,
    }

    target:addStatusEffect(xi.effect.COUNTERSTANCE, pTable)

    return xi.effect.COUNTERSTANCE
end)

m:addOverride('xi.effects.counterstance.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        effect:addMod(xi.mod.DMG, -1000)
        effect:addMod(xi.mod.ENMITY, 20)
        effect:addMod(xi.mod.COUNTER_DAMAGE, 20)
    end
end)

m:addOverride('xi.job_utils.monk.useDodge', function(player, target, ability)
    local subPow = 0
    if isMonkSpec(player, SENSEI_KEY) then
        subPow = 1
    elseif isMonkSpec(player, BLACKBELT_KEY) then
        subPow = 2
    elseif isMonkSpec(player, CHIWEAVER_KEY) then
        subPow = 3
    end

    if subPow == 0 then
        return super(player, target, ability)
    end

    local dur = (subPow == 1) and 60 or 60
    local pTable =
    {
        power    = target:getMod(xi.mod.DODGE_EFFECT) + target:getJobPointLevel(xi.jp.DODGE_EFFECT),
        duration = dur,
        origin   = player,
        subPower = subPow,
    }

    player:addStatusEffect(xi.effect.DODGE, pTable)

    return xi.effect.DODGE
end)

m:addOverride('xi.effects.dodge.onEffectGain', function(target, effect)
    super(target, effect)

    if effect == nil then
        return
    end

    local subPow = effect:getSubPower()
    if subPow == 1 then
        effect:addMod(xi.mod.EVA, 25)
        effect:addMod(xi.mod.EVA_PERCENT, 15)
        effect:addMod(xi.mod.INQUARTATA, 12)
        effect:addMod(xi.mod.ENMITY, 15)
    elseif subPow == 2 then
        effect:addMod(xi.mod.HASTE_ABILITY, 1000)
        effect:addMod(xi.mod.SUBTLE_BLOW, 15)
    elseif subPow == 3 then
        effect:addMod(xi.mod.EVA, 30)
        effect:addMod(xi.mod.DMG, -1000)
        effect:addMod(xi.mod.ENMITY, -25)
    end
end)

m:addOverride('xi.job_utils.monk.useFocus', function(player, target, ability)
    local subPow = 0
    if isMonkSpec(player, SENSEI_KEY) then
        subPow = 1
    elseif isMonkSpec(player, BLACKBELT_KEY) then
        subPow = 2
    elseif isMonkSpec(player, CHIWEAVER_KEY) then
        subPow = 3
    end

    if subPow == 0 then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = target:getMod(xi.mod.FOCUS_EFFECT) + target:getJobPointLevel(xi.jp.FOCUS_EFFECT),
        duration = 60,
        origin   = player,
        subPower = subPow,
    }

    player:addStatusEffect(xi.effect.FOCUS, pTable)

    return xi.effect.FOCUS
end)

m:addOverride('xi.effects.focus.onEffectGain', function(target, effect)
    super(target, effect)

    if effect == nil then
        return
    end

    local subPow = effect:getSubPower()
    if subPow == 1 then
        effect:addMod(xi.mod.COUNTER, 15)
        effect:addMod(xi.mod.PARRY, 15)
        effect:addMod(xi.mod.COUNTER_DAMAGE, 10)
    elseif subPow == 2 then
        effect:addMod(xi.mod.CRITHITRATE, 10)
        effect:addMod(xi.mod.CRIT_DMG_INCREASE, 15)
        effect:addMod(xi.mod.ACC, 25)
    elseif subPow == 3 then
        effect:addMod(xi.mod.MACC, 25)
        effect:addMod(xi.mod.MATT, 20)
        effect:addMod(xi.mod.CURE_POTENCY, 15)
    end
end)

m:addOverride('xi.effects.boost.onEffectGain', function(target, effect)
    if effect ~= nil and effect.getSubPower and effect:getSubPower() == CHIWEAVER_BOOST_SUBPOWER then
        local stacks  = utils.clamp(math.floor(effect:getPower() or 0), 0, CHIWEAVER_MAX_STACKS)
        local perFive = math.floor(stacks / 5)
        if perFive > 0 then
            effect:addMod(xi.mod.CURE_POTENCY, perFive)
            effect:addMod(xi.mod.MACC, perFive)
            effect:addMod(xi.mod.MATT, perFive)
        end
        return
    end

    super(target, effect)
end)

m:addOverride('xi.job_utils.monk.useBoost', function(player, target, ability)
    if isMonkSpec(player, CHIWEAVER_KEY) then
        local newStacks = addChiBoostStacks(player, 5, true)
        if player.addTP then
            player:addTP(50)
        end

        local engagedTarget = player.getTarget and player:getTarget() or nil
        if
            engagedTarget ~= nil and
            engagedTarget.isAlive and
            engagedTarget:isAlive() and
            engagedTarget.isMob and
            engagedTarget:isMob() and
            player.checkDistance and
            player:checkDistance(engagedTarget) <= 22.0
        then
            local lvl      = player.getMainLvl and (player:getMainLvl() or 10) or 10
            local mndStat  = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
            local baseHeal = computeChiPulseBaseHeal(player, lvl, mndStat, 0.40)
            pulseHealAroundCenter(player, engagedTarget, baseHeal, 12.0, 0)
        end

        if player.printToPlayer then
            player:printToPlayer(
                string.format('Boost (+5): %d/%d Chi Weaver stacks.', newStacks, CHIWEAVER_MAX_STACKS),
                xi.msg.channel.SYSTEM_3,
                ''
            )
        end

        return xi.effect.BOOST
    end

    super(player, target, ability)

    if isMonkSpec(player, SENSEI_KEY) and isStaffEquipped(player) then
        if player.addTP then
            player:addTP(50)
        end

        local engagedTarget = player.getTarget and player:getTarget() or nil
        if engagedTarget ~= nil then
            grantEnmity(engagedTarget, player, 100, 220)
        end
    elseif isMonkSpec(player, BLACKBELT_KEY) and isHandToHandOrUnarmed(player) then
        if player.addTP then
            player:addTP(100)
        end

        local boostEff = player.getStatusEffect and player:getStatusEffect(xi.effect.BOOST) or nil
        if boostEff ~= nil and boostEff.addMod then
            boostEff:addMod(xi.mod.CRITHITRATE, 8)
            boostEff:addMod(xi.mod.ALL_WSDMG_ALL_HITS, 15)
        end
    end
end)

m:addOverride('xi.actions.abilities.chi_blast.onAbilityCheck', function(player, target, ability)
    local rc, p = super(player, target, ability)

    if player ~= nil and player:isPC() and isMonkSpec(player, CHIWEAVER_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(5)
        end
    end

    return rc, p
end)

m:addOverride('xi.job_utils.monk.useChiBlast', function(player, target, ability)
    if isMonkSpec(player, CHIWEAVER_KEY) then
        if player.setLocalVar then
            player:setLocalVar('OX_CHIBLAST_PCT', 0)
        end

        local stacks     = getChiBoostStacks(player)
        local lvl        = player.getMainLvl and (player:getMainLvl() or 10) or 10
        local mndStat    = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
        local hasHarmony = player.hasStatusEffect and player:hasStatusEffect(EFFECT_INNER_HARMONY)
        local stackMult  = (0.50 + (stacks * 0.045) + ((stacks * stacks) / 10000.0) * 1.55)
            * (hasHarmony and 1.25 or 1.0)
        local baseHeal   = computeChiPulseBaseHeal(player, lvl, mndStat, stackMult)
        local cleanse    = (stacks >= 80 and 3) or (stacks >= 50 and 2) or (stacks >= 25 and 1) or 0

        setChiBoostStacks(player, 0, false)

        local center = target or player
        local _totalHealed, countHealed = pulseHealAroundCenter(player, center, baseHeal, 20.0, cleanse, player)

        if ability ~= nil and ability.setMsg and xi.msg and xi.msg.basic then
            ability:setMsg(xi.msg.basic.USES_JA or 100)
        end

        if stacks > 0 and player.printToPlayer then
            player:printToPlayer(
                string.format('Chi Blast consumes %d Boost stacks (%d allies healed within 20y)!', stacks, countHealed),
                xi.msg.channel.SYSTEM_3,
                ''
            )
        end

        return 0
    end

    local dmg = super(player, target, ability)

    if isMonkSpec(player, SENSEI_KEY) and target ~= nil and target ~= player then
        grantEnmity(target, player, 450, 1200)
        if target.addStatusEffect and xi.effect.ACCURACY_DOWN then
            target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 20, duration = 30, origin = player })
        end
    elseif isMonkSpec(player, BLACKBELT_KEY) and target ~= nil and target ~= player then
        if (tonumber(dmg) or 0) > 0 and target.isAlive and target:isAlive() then
            local bonus = math.max(1, math.floor(dmg * 0.35))
            target:takeDamage(bonus, player, xi.attackType.BREATH, xi.damageType.ELEMENTAL)
            dmg = dmg + bonus
        end
        if target.addStatusEffect and xi.effect.DEFENSE_DOWN and target:isAlive() then
            target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = 15, duration = 20, origin = player })
        end
        if player.addTP then
            player:addTP(100)
        end
    end

    return dmg
end)

m:addOverride('xi.job_utils.monk.useChakra', function(player, target, ability)
    if isMonkSpec(player, SENSEI_KEY) then
        local wasCleansedSlow = player:hasStatusEffect(xi.effect.SLOW)
        local wasCleansedSilence = player:hasStatusEffect(xi.effect.SILENCE)

        player:addMod(xi.mod.CHAKRA_MULT, 50)
        local recoveryAmount = super(player, target, ability)
        player:delMod(xi.mod.CHAKRA_MULT, 50)

        if wasCleansedSlow then
            player:delStatusEffect(xi.effect.SLOW)
        end
        if wasCleansedSilence then
            player:delStatusEffect(xi.effect.SILENCE)
        end

        local lvl        = player.getMainLvl and player:getMainLvl() or 10
        local regenPct   = scaleTier(lvl, 1.5, 2.5, 3.5)
        local minRegen   = scaleTier(lvl, 14, 28, 45)
        local maxHp      = player.getMaxHP and math.max(0, player:getMaxHP() or 0) or 0
        local regenPower = math.max(minRegen, math.floor(maxHp * regenPct / 100))
        if player:hasStatusEffect(xi.effect.REGEN) then
            player:delStatusEffect(xi.effect.REGEN)
        end
        player:addStatusEffect(xi.effect.REGEN, { power = regenPower, duration = 30, origin = player, tier = 1 })

        local engagedTarget = player.getTarget and player:getTarget() or nil
        if engagedTarget ~= nil then
            grantEnmity(engagedTarget, player, 150, 400)
        end

        return recoveryAmount
    elseif isMonkSpec(player, BLACKBELT_KEY) then
        local hadPara   = player:hasStatusEffect(xi.effect.PARALYSIS)
        local hadBlind  = player:hasStatusEffect(xi.effect.BLINDNESS)
        local hadWeight = player:hasStatusEffect(xi.effect.WEIGHT)

        player:addMod(xi.mod.CHAKRA_MULT, 30)
        local recoveryAmount = super(player, target, ability)
        player:delMod(xi.mod.CHAKRA_MULT, 30)

        if hadPara then
            player:delStatusEffect(xi.effect.PARALYSIS)
        end
        if hadBlind then
            player:delStatusEffect(xi.effect.BLINDNESS)
        end
        if hadWeight then
            player:delStatusEffect(xi.effect.WEIGHT)
        end

        if player.addTP then
            player:addTP(150)
        end

        return recoveryAmount
    elseif isMonkSpec(player, CHIWEAVER_KEY) then
        local hadPoison  = player:hasStatusEffect(xi.effect.POISON)
        local hadPara    = player:hasStatusEffect(xi.effect.PARALYSIS)
        local hadBlind   = player:hasStatusEffect(xi.effect.BLINDNESS)
        local hadSilence = player:hasStatusEffect(xi.effect.SILENCE)

        local recoveryAmount = super(player, target, ability)

        if hadPoison then
            player:delStatusEffect(xi.effect.POISON)
        end
        if hadPara then
            player:delStatusEffect(xi.effect.PARALYSIS)
        end
        if hadBlind then
            player:delStatusEffect(xi.effect.BLINDNESS)
        end
        if hadSilence then
            player:delStatusEffect(xi.effect.SILENCE)
        end

        local lvl      = player.getMainLvl and player:getMainLvl() or 10
        local mndStat  = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
        local baseHeal = math.max(math.floor((tonumber(recoveryAmount) or 0) * 0.45), computeChiPulseBaseHeal(player, lvl, mndStat, 1.25))
        pulseHealAroundCenter(player, player, baseHeal, 12.0, 0)

        return recoveryAmount
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.monk.usePerfectCounter', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = 2,
        duration = 30,
        origin   = player,
        subPower = 1,
    }

    player:addStatusEffect(xi.effect.PERFECT_COUNTER, pTable)

    if player.addHP and player.getMaxHP then
        local heal = math.max(10, math.floor(player:getMaxHP() * 0.05))
        player:addHP(heal)
    end

    return xi.effect.PERFECT_COUNTER
end)

m:addOverride('xi.effects.perfect_counter.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:addMod(xi.mod.COUNTER_DAMAGE, 25)
        target:addMod(xi.mod.ENMITY, 25)
    end
end)

m:addOverride('xi.effects.perfect_counter.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:delMod(xi.mod.COUNTER_DAMAGE, 25)
        target:delMod(xi.mod.ENMITY, 25)
    end
end)

m:addOverride('xi.job_utils.monk.useMantra', function(player, target, ability)
    if isMonkSpec(player, SENSEI_KEY) then
        target:delStatusEffect(xi.effect.MAX_HP_BOOST)

        local pTable =
        {
            power    = player:getMerit(xi.merit.MANTRA),
            duration = 180,
            origin   = player,
        }

        local targetId = target:getID()
        pendingMantraMods[targetId] =
        {
            { xi.mod.DMG, -500 },
        }
        target:addStatusEffect(xi.effect.MAX_HP_BOOST, pTable)
        pendingMantraMods[targetId] = nil

        return xi.effect.MAX_HP_BOOST
    elseif isMonkSpec(player, CHIWEAVER_KEY) then
        target:delStatusEffect(xi.effect.MAX_HP_BOOST)

        local lvl      = player.getMainLvl and player:getMainLvl() or 10
        local regenVal = scaleTier(lvl, 12, 20, 30, 42)
        local pTable =
        {
            power    = player:getMerit(xi.merit.MANTRA),
            duration = 180,
            origin   = player,
        }

        local targetId = target:getID()
        pendingMantraMods[targetId] =
        {
            { xi.mod.CURE_POTENCY_RCVD, 12 },
            { xi.mod.REGEN,             regenVal },
        }
        target:addStatusEffect(xi.effect.MAX_HP_BOOST, pTable)
        pendingMantraMods[targetId] = nil

        return xi.effect.MAX_HP_BOOST
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.max_hp_boost.onEffectGain', function(target, effect)
    super(target, effect)

    if target == nil or effect == nil then
        return
    end

    local extra = pendingMantraMods[target:getID()]
    if extra ~= nil then
        for _, pair in ipairs(extra) do
            effect:addMod(pair[1], pair[2])
        end
    end
end)

m:addOverride('xi.job_utils.monk.useInnerStrength', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = 2,
        duration = 60,
        origin   = player,
        subPower = 1,
    }

    player:addStatusEffect(xi.effect.INNER_STRENGTH, pTable)

    return xi.effect.INNER_STRENGTH
end)

m:addOverride('xi.effects.inner_strength.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:addMod(xi.mod.DMG, -2500)
        target:addMod(xi.mod.EVA_PERCENT, 20)
        target:addMod(xi.mod.COUNTER_DAMAGE, 30)
        target:addMod(xi.mod.ENMITY, 50)
    end
end)

m:addOverride('xi.effects.inner_strength.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:delMod(xi.mod.DMG, -2500)
        target:delMod(xi.mod.EVA_PERCENT, 20)
        target:delMod(xi.mod.COUNTER_DAMAGE, 30)
        target:delMod(xi.mod.ENMITY, 50)
    end
end)

m:addOverride('xi.actions.abilities.footwork.onUseAbility', function(player, target, ability)
    local res = super(player, target, ability)

    if isMonkSpec(player, BLACKBELT_KEY) and isHandToHandOrUnarmed(player) then
        local eff = player.getStatusEffect and player:getStatusEffect(xi.effect.FOOTWORK) or nil
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.KICK_DMG, 15)
            eff:addMod(xi.mod.KICK_ATTACK_RATE, 10)
            eff:addMod(xi.mod.ATTP, 10)
        end
    end

    return res
end)

m:addOverride('xi.actions.abilities.hundred_fists.onUseAbility', function(player, target, ability)
    local res = super(player, target, ability)

    if isMonkSpec(player, BLACKBELT_KEY) and isHandToHandOrUnarmed(player) then
        local eff = player.getStatusEffect and player:getStatusEffect(xi.effect.HUNDRED_FISTS) or nil
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.ATTP, 25)
            eff:addMod(xi.mod.CRITHITRATE, 15)
            eff:addMod(xi.mod.DOUBLE_ATTACK, 20)
            eff:addMod(xi.mod.STORETP, 20)
        end
    end

    return res
end)

-----------------------------------
-- Custom Chi Weaver Job Abilities (429-431)
-----------------------------------

-- 1) Resonant Chi (429, 20s CD, 20y Enemy): heavy Light Chi bolt + 1.75x AoE heal & Cleanse around target mob
bindAbility('resonant_chi', function(player, target, _ability)
    if not isMonkSpec(player, CHIWEAVER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    enforceMnkWeaponGate(player)
    if not isCompletelyUnarmed(player) or target == nil or (target.isAlive and not target:isAlive()) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, target, _ability)
    local lvl      = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local mndStat  = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
    local h2hSkill = player.getSkillLevel and (player:getSkillLevel(xi.skill.HAND_TO_HAND) or 0) or 0
    local mab      = player.getMod and (player:getMod(xi.mod.MATT) or 0) or 0
    local tgtMdef  = target.getMod and (target:getMod(xi.mod.MDEF) or 0) or 0
    local mabMult  = math.max(0.5, (100.0 + mab) / (100.0 + tgtMdef))

    local hasHarmony = player.hasStatusEffect and player:hasStatusEffect(EFFECT_INNER_HARMONY)
    local dmgMult    = hasHarmony and 1.20 or 1.0
    local rawDmg     = ((lvl * 1.15) + 10 + (mndStat * 0.55) + (h2hSkill * 0.08)) * mabMult * dmgMult
    local dmg        = math.max(8, math.floor(rawDmg))

    local dealt = dmg
    if target.takeDamage and xi.attackType and xi.damageType then
        local res = target:takeDamage(dmg, player, xi.attackType.MAGICAL, xi.damageType.LIGHT)
        if type(res) == 'number' then
            dealt = math.max(0, res)
        end
    end

    if player.addTP then
        player:addTP(125)
    end
    if target.updateEnmityFromDamage then
        target:updateEnmityFromDamage(player, math.max(1, math.floor(dealt * 0.30)))
    end

    local pulseMult = 1.75 * (hasHarmony and 1.40 or 1.0)
    local baseHeal  = computeChiPulseBaseHeal(player, lvl, mndStat, pulseMult)
    pulseHealAroundCenter(player, target, baseHeal, 12.0, 1)

    return dealt
end)

-- 2) Tranquil Lotus (430, 30s CD, 12y Party & Pet AoE Heal + 15s Regen/CureRcvd/Enmity- Sanctuary)
bindAbility('tranquil_lotus', function(player, _target, _ability)
    if not isMonkSpec(player, CHIWEAVER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    enforceMnkWeaponGate(player)
    if not isCompletelyUnarmed(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, target, _ability)
    local recipient = target or player
    local lvl       = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local healPct   = scaleTier(lvl, 12, 16, 20, 24)
    local regenVal  = scaleTier(lvl, 12, 20, 30, 42)
    local cureRcvd  = scaleTier(lvl, 10, 15, 20, 25)
    local enmityRed = scaleTier(lvl, -10, -14, -18, -22)
    local mndStat   = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
    local curePot   = 1.0 + (math.max(0, (player.getMod and player:getMod(xi.mod.CURE_POTENCY)) or 0) / 100.0)
    local iconId    = (xi.effect and xi.effect.REGEN) or EFFECT_TRANQUIL_LOTUS

    local maxHp      = recipient.getMaxHP and (recipient:getMaxHP() or 100) or 100
    local rcvdMod    = recipient.getMod and (recipient:getMod(xi.mod.CURE_POTENCY_RCVD) or 0) or 0
    local rcvdMult   = math.max(0.5, 1.0 + (rcvdMod / 100.0))
    local healAmount = math.max(15, math.floor(((maxHp * healPct / 100.0) + (mndStat * 0.9)) * curePot * rcvdMult))

    if recipient.addHP then
        local healed = tonumber(recipient:addHP(healAmount)) or 0
        if
            healed > 0 and
            player.messagePublic and
            xi.msg and
            xi.msg.basic and
            xi.msg.basic.RECOVERS_HP
        then
            player:messagePublic(xi.msg.basic.RECOVERS_HP, recipient, 0, healed)
        end
    end

    applyTimedChiEffect(
        recipient,
        EFFECT_TRANQUIL_LOTUS,
        regenVal,
        15,
        player,
        iconId,
        {
            { xi.mod.REGEN,             regenVal },
            { xi.mod.CURE_POTENCY_RCVD, cureRcvd },
            { xi.mod.ENMITY,            enmityRed },
        }
    )

    return EFFECT_TRANQUIL_LOTUS
end)

-- 3) Inner Harmony (431, 45s CD, Self 18s: Cure Potency, MAB/MACC, Ability Haste, Regen, +40% Chi Bolt & Pulse power)
bindAbility('inner_harmony', function(player, _target, _ability)
    if not isMonkSpec(player, CHIWEAVER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    enforceMnkWeaponGate(player)
    if not isCompletelyUnarmed(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end, function(player, _target, _ability)
    local lvl       = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local curePot   = scaleTier(lvl, 15, 22, 30, 40)
    local magBonus  = scaleTier(lvl, 20, 30, 45, 60)
    local abilHaste = scaleTier(lvl, 500, 800, 1100, 1500)
    local regenVal  = scaleTier(lvl, 10, 18, 28, 40)
    local iconId    = (xi.effect and xi.effect.AFFLATUS_SOLACE) or (xi.effect and xi.effect.ENLIGHT) or EFFECT_INNER_HARMONY

    applyTimedChiEffect(
        player,
        EFFECT_INNER_HARMONY,
        curePot,
        18,
        player,
        iconId,
        {
            { xi.mod.CURE_POTENCY,  curePot },
            { xi.mod.MATT,          magBonus },
            { xi.mod.MACC,          magBonus },
            { xi.mod.HASTE_ABILITY, abilHaste },
            { xi.mod.REGEN,         regenVal },
        }
    )

    return EFFECT_INNER_HARMONY
end)

-----------------------------------
-- Login & Level Lifecycle Hooks
-----------------------------------
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if player ~= nil and player:isPC() then
        player:removeListener('OX_MNK_WEAPON_GATE')
        player:addListener('TICK', 'OX_MNK_WEAPON_GATE', function(actor)
            enforceMnkWeaponGate(actor)
            if isMonkSpec(actor, CHIWEAVER_KEY) and actor.getLocalVar and actor.setLocalVar then
                local effStacks = getChiBoostStacks(actor)
                local varStacks = actor:getLocalVar('OX_CHW_CHI_STACKS') or 0
                if effStacks == 0 and varStacks > 0 then
                    actor:setLocalVar('OX_CHW_CHI_STACKS', 0)
                elseif effStacks > 0 and varStacks ~= effStacks then
                    actor:setLocalVar('OX_CHW_CHI_STACKS', effStacks)
                end
            end
            sendChiBoostSync(actor, false)
        end)
        enforceMnkWeaponGate(player)
        if isMonkSpec(player, CHIWEAVER_KEY) and player.setLocalVar then
            local effStacks = getChiBoostStacks(player)
            if effStacks > 0 then
                player:setLocalVar('OX_CHW_CHI_STACKS', effStacks)
            end
        end

        if isMonkSpec(player, SENSEI_KEY) then
            attachSenseiListeners(player)
        else
            detachSenseiListeners(player)
        end

        if isMonkSpec(player, BLACKBELT_KEY) then
            attachBlackBeltListeners(player)
        else
            detachBlackBeltListeners(player)
        end

        if isMonkSpec(player, CHIWEAVER_KEY) then
            attachChiWeaverListeners(player)
        else
            detachChiWeaverListeners(player)
        end

        sendChiBoostSync(player, true)
        if player.timer then
            player:timer(1500, function(playerArg)
                if playerArg ~= nil then
                    sendChiBoostSync(playerArg, true)
                end
            end)
        end
    end
end)

return m
