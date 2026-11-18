-----------------------------------
-- OverlordsXI Puppetmaster Crystal Spec
-- Registers the Puppetmaster (job 18) Soul Crystal specialization:
--   1. Vanguard (PUP): Automaton Proxy-Tank & Tactical Link
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/job_utils/puppetmaster')
require('scripts/globals/pets/automaton')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_pup_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.pupSpecs = xi.overlords.pupSpecs or {}
local pupSpecs        = xi.overlords.pupSpecs

local VANGUARD_KEY = 'vanguard'

-- Custom Trait ID (164; Vanguard's Core)
local TRAIT_VANGUARDS_CORE = 164

-- Custom Ability IDs (451-452; recastIds 168-169)
local ABIL_AEGIS_PROTOCOL = 451
local ABIL_GYRO_SLAM      = 452

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.AEGIS_PROTOCOL = ABIL_AEGIS_PROTOCOL
xi.jobAbility.GYRO_SLAM      = ABIL_GYRO_SLAM

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.aegis_protocol = xi.actions.abilities.aegis_protocol or {}
xi.actions.abilities.gyro_slam      = xi.actions.abilities.gyro_slam or {}

local automatonModStateByPetId = {}

-----------------------------------
-- Scaling & Helpers
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

local function isVanguard(entity)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.PUP
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.PUP, VANGUARD_KEY)
end

local function isH2HEquipped(player)
    if player == nil then
        return false
    end
    if player.isUsingH2H and player:isUsingH2H() then
        return true
    end
    if player.getEquippedItem then
        local mainItem = player:getEquippedItem(xi.slot.MAIN)
        if mainItem ~= nil and mainItem.getSkillType then
            return mainItem:getSkillType() == xi.skill.HAND_TO_HAND
        end
    end
    return false
end

local function isHandToHandWs(ws)
    if ws == nil then
        return false
    end
    local wsId = (type(ws) == 'number') and ws or (ws.getID and ws:getID() or 0)
    if wsId >= 1 and wsId <= 15 then
        return true
    end
    if (type(ws) == 'table' or type(ws) == 'userdata') and ws.getSkillType then
        return ws:getSkillType() == xi.skill.HAND_TO_HAND
    end
    return false
end

-----------------------------------
-- Automaton Passive Mod Sync
-----------------------------------
local function clearAutomatonMods(pet)
    if pet == nil or not pet.getID then
        return
    end

    local petId = pet:getID()
    local prev  = automatonModStateByPetId[petId]
    if prev ~= nil then
        if pet.delMod then
            for _, entry in ipairs(prev.mods or {}) do
                pet:delMod(entry[1], entry[2])
            end
        end
        if prev.prevBlockMod ~= nil and pet.setMobMod then
            pet:setMobMod(xi.mobMod.CAN_SHIELD_BLOCK, prev.prevBlockMod)
        end
        if pet.updateHealth then
            pet:updateHealth()
        end
    end
    automatonModStateByPetId[petId] = nil
end

local function syncAutomatonMods(player, force)
    if player == nil or not player.getPet then
        return
    end

    local pet = player:getPet()
    if pet == nil or not pet.isAutomaton or not pet:isAutomaton() then
        return
    end

    if not isVanguard(player) then
        clearAutomatonMods(pet)
        return
    end

    local petId    = pet:getID()
    local lvl      = player:getMainLvl() or 1
    local stateKey = string.format('%s:%u', VANGUARD_KEY, lvl)

    local prev = automatonModStateByPetId[petId]
    if not force and prev ~= nil and prev.key == stateKey then
        return
    end

    local prevBlockMod = prev and prev.prevBlockMod
    if prevBlockMod == nil and pet.getMobMod then
        prevBlockMod = pet:getMobMod(xi.mobMod.CAN_SHIELD_BLOCK) or 0
    end

    clearAutomatonMods(pet)

    local mods =
    {
        { xi.mod.HPP,             scaleTier(lvl, 25, 35, 45, 60) },
        { xi.mod.DEFP,            scaleTier(lvl, 20, 30, 40, 50) },
        { xi.mod.DMG,             scaleTier(lvl, -1500, -2000, -2500, -3000) },
        { xi.mod.ENMITY,          scaleTier(lvl, 25, 35, 45, 60) },
        { xi.mod.SHIELDBLOCKRATE, scaleTier(lvl, 15, 20, 25, 30) },
    }

    if pet.addMod then
        for _, entry in ipairs(mods) do
            pet:addMod(entry[1], entry[2])
        end
    end

    if pet.setMobMod then
        pet:setMobMod(xi.mobMod.CAN_SHIELD_BLOCK, 1)
    end

    if pet.updateHealth then
        pet:updateHealth()
    end

    automatonModStateByPetId[petId] =
    {
        key          = stateKey,
        mods         = mods,
        prevBlockMod = prevBlockMod,
    }
end

function pupSpecs.syncAutomaton(player)
    syncAutomatonMods(player, false)
end

-----------------------------------
-- Automaton Spawn & Overdrive Spam
-----------------------------------
local function attachAutomatonListeners(automaton)
    if automaton == nil or not automaton.addListener then
        return
    end

    automaton:removeListener('OX_VANGUARD_AUTO_TICK')
    automaton:addListener('AUTOMATON_AI_TICK', 'OX_VANGUARD_AUTO_TICK', function(mobArg)
        if mobArg == nil or not mobArg:isAlive() then
            return
        end

        local master = mobArg:getMaster()
        if not isVanguard(master) then
            return
        end

        if not mobArg:hasStatusEffect(xi.effect.OVERDRIVE) then
            return
        end

        if xi.combat and xi.combat.behavior and xi.combat.behavior.isEntityBusy(mobArg) then
            return
        end

        local target = mobArg:getTarget()
        if target == nil or not target:isAlive() then
            return
        end

        local now  = os.time()
        local next = mobArg:getLocalVar('OX_OD_SPAM_AT') or 0
        if now < next then
            return
        end

        local step = mobArg:getLocalVar('OX_OD_SPAM_STEP') or 0
        mobArg:setLocalVar('OX_OD_SPAM_AT', now + 3)
        mobArg:setLocalVar('OX_OD_SPAM_STEP', (step + 1) % 2)

        if step % 2 == 0 then
            mobArg:useMobAbility(xi.mobSkill.SHIELD_BASH_AUTOMATON)
        else
            mobArg:useMobAbility(xi.mobSkill.PROVOKE_AUTOMATON)
        end
    end)
end

m:addOverride('xi.pets.automaton.onMobSpawn', function(mob)
    super(mob)

    if mob == nil then
        return
    end

    local master = mob:getMaster()
    if not isVanguard(master) then
        return
    end

    syncAutomatonMods(master, true)
    attachAutomatonListeners(mob)

    -- Cut initial spawn recasts for Strobe and Flashbulb by 50%
    if mob.addRecast then
        mob:addRecast(xi.recast.ABILITY, xi.mobSkill.PROVOKE_AUTOMATON,   15)
        mob:addRecast(xi.recast.ABILITY, xi.mobSkill.FLASHBULB_AUTOMATON, 22)
    end
end)

m:addOverride('xi.pets.automaton.onMobDeath', function(mob)
    if mob ~= nil and mob.getID then
        automatonModStateByPetId[mob:getID()] = nil
    end
    super(mob)
end)

-----------------------------------
-- Strobe & Flashbulb (50% CD, 2x VE)
-----------------------------------
m:addOverride('xi.actions.abilities.pets.automaton.provoke.onAutomatonAbility', function(target, automaton, skill, master, action)
    if isVanguard(master) then
        automaton:addRecast(xi.recast.ABILITY, skill:getID(), 15)
        if target ~= nil and target.addEnmity then
            target:addEnmity(automaton, 1, 3600)
        end
        skill:setMsg(xi.msg.basic.PROVOKE_SWITCH)
        return 0
    end

    return super(target, automaton, skill, master, action)
end)

m:addOverride('xi.actions.abilities.pets.automaton.flashbulb.onAutomatonAbility', function(target, automaton, skill, master, action)
    local res = super(target, automaton, skill, master, action)

    if isVanguard(master) then
        automaton:addRecast(xi.recast.ABILITY, skill:getID(), 22)
        if target ~= nil and target.addEnmity then
            target:addEnmity(automaton, 0, 1280)
        end
    end

    return res
end)

-----------------------------------
-- Emergency Chassis Link (<25% -> >35% HP)
-----------------------------------
local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage

function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    if defender == nil or amount == nil or amount <= 0 then
        return amount or 0
    end

    if not defender.isAutomaton or not defender:isAutomaton() then
        return amount
    end

    local master = defender:getMaster()
    if not isVanguard(master) or not master:isAlive() then
        return amount
    end

    if master.getZoneID and defender.getZoneID and master:getZoneID() ~= defender:getZoneID() then
        return amount
    end

    local hpp = defender:getHPP()
    if hpp > 35 then
        defender:setLocalVar('OX_CHASSIS_LINK', 0)
        return amount
    elseif hpp < 25 then
        defender:setLocalVar('OX_CHASSIS_LINK', 1)
    end

    if defender:getLocalVar('OX_CHASSIS_LINK') == 1 and master:getHP() > 1 then
        local redirect = math.floor(amount * 0.35)
        if redirect > 0 then
            master:takeDamage(redirect, attacker, attackType, damageType)
            return math.max(0, amount - redirect)
        end
    end

    return amount
end

-----------------------------------
-- Master WS Enmity Funnel & Concussive Blow
-----------------------------------
local function detachPupListeners(player)
    if player == nil or not player.removeListener then
        return
    end
    player:removeListener('OX_PUP_WS')
end

local function attachPupListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachPupListeners(player)

    player:addListener('WEAPONSKILL_USE', 'OX_PUP_WS', function(actor, target, ws, _tp, _action, _dmg)
        if not isVanguard(actor) or target == nil or not isHandToHandWs(ws) then
            return
        end

        -- Inflict Concussive Blow: -15% Attack Down & -20 Accuracy for 15s
        if target.addStatusEffect then
            target:addStatusEffect(xi.effect.ATTACK_DOWN,   { power = 15, duration = 15, origin = actor })
            target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 20, duration = 15, origin = actor })
        end

        local pet = actor:getPet()
        if pet == nil or not pet:isAutomaton() or not pet:isAlive() then
            return
        end

        -- Transfer 100% of Master's volatile enmity (including WS VE) onto Automaton
        if target.getVE and target.setVE and target.addEnmity then
            local actorVE = target:getVE(actor) or 0
            if actorVE > 0 then
                target:setVE(actor, 0)
                target:addEnmity(pet, 0, actorVE)
            end
        end

        -- Grant Automaton +400 TP and 12% Max HP barrier
        if pet.addTP then
            pet:addTP(400)
        end

        local barrier = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.12))
        if pet.delStatusEffectSilent then
            pet:delStatusEffectSilent(xi.effect.STONESKIN)
        end
        if pet.addStatusEffect then
            pet:addStatusEffect(xi.effect.STONESKIN, { power = barrier, duration = 30, origin = actor, tier = 4 })
        end
    end)
end

-----------------------------------
-- Enhanced PUP Job Abilities (Repair, Ventriloquy, Overdrive)
-----------------------------------
local function cleanseAllDebuffs(pet)
    if pet == nil then
        return
    end

    if pet.eraseStatusEffect then
        for _ = 1, 32 do
            if pet:eraseStatusEffect() == xi.effect.NONE then
                break
            end
        end
    end

    local extraEffects =
    {
        xi.effect.SLEEP_I,
        xi.effect.SLEEP_II,
        xi.effect.LULLABY,
        xi.effect.PETRIFICATION,
        xi.effect.STUN,
        xi.effect.TERROR,
        xi.effect.SILENCE,
        xi.effect.AMNESIA,
        xi.effect.DOOM,
        xi.effect.GRADUAL_PETRIFICATION,
        xi.effect.CURSE_I,
        xi.effect.CURSE_II,
        xi.effect.POISON,
        xi.effect.PARALYSIS,
        xi.effect.BLINDNESS,
        xi.effect.SLOW,
        xi.effect.BIND,
        xi.effect.WEIGHT,
        xi.effect.PLAGUE,
    }
    if pet.delStatusEffect then
        for _, eff in ipairs(extraEffects) do
            pet:delStatusEffect(eff)
        end
    end
end

m:addOverride('xi.job_utils.puppetmaster.onAbilityCheckRepair', function(player, target, ability)
    if isVanguard(player) then
        local pet = player:getPet()
        if not pet then
            return xi.msg.basic.REQUIRES_A_PET, 0
        elseif not pet:isAutomaton() then
            return xi.msg.basic.NO_EFFECT_ON_PET, 0
        elseif pet:checkDistance(player) > 20.0 + player:getHitboxSize() + pet:getHitboxSize() then
            return xi.msg.basic.TOO_FAR_AWAY_2, 0
        end
        return 0, 0
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseRepair', function(player, target, ability, action)
    if not isVanguard(player) then
        return super(player, target, ability, action)
    end

    if ability and ability.setRecast then
        ability:setRecast(20)
    end

    local pet = player:getPet()
    if not pet then
        return 0
    end

    action:ID(player:getID(), pet:getID())

    local heal         = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.45))
    local totalHealing = pet:addHP(heal)

    pet:wakeUp()
    cleanseAllDebuffs(pet)

    -- -20% DT for 6s
    pet:delStatusEffectSilent(xi.effect.RAMPART)
    pet:addStatusEffect(xi.effect.RAMPART, { power = 2000, duration = 6, origin = player })

    return totalHealing
end)

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseVentriloquy', function(player, target, ability)
    if not isVanguard(player) then
        return super(player, target, ability)
    end

    if ability and ability.setRecast then
        ability:setRecast(15)
    end

    local pet = player:getPet()
    if pet and target and target.isMob and target:isMob() then
        local playerCE = target:getCE(player) or 0
        local playerVE = target:getVE(player) or 0
        local petCE    = target:getCE(pet) or 0
        local petVE    = target:getVE(pet) or 0

        target:setCE(player, 0)
        target:setVE(player, 0)
        target:setCE(pet, math.max(petCE, playerCE) + 400)
        target:setVE(pet, math.max(petVE, playerVE) + 1200)
        if target.updateEnmity then
            target:updateEnmity(pet)
        end
    end

    -- Grant both Master and Automaton +25 Enmity for 15s
    player:delStatusEffectSilent(xi.effect.ENMITY_BOOST)
    player:addStatusEffect(xi.effect.ENMITY_BOOST, { power = 25, duration = 15, origin = player })

    if pet then
        pet:delStatusEffectSilent(xi.effect.ENMITY_BOOST)
        pet:addStatusEffect(xi.effect.ENMITY_BOOST, { power = 25, duration = 15, origin = player })
    end
end)

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseOverdrive', function(player, target, ability, action)
    if not isVanguard(player) then
        return super(player, target, ability, action)
    end

    local pet = player:getPet()
    player:addStatusEffect(xi.effect.OVERDRIVE, { duration = 30, origin = player })

    if pet then
        pet:addStatusEffect(xi.effect.OVERDRIVE, { duration = 30, origin = pet })
        action:ID(player:getID(), pet:getID())
    end

    return xi.effect.OVERDRIVE
end)

m:addOverride('xi.effects.overdrive.onEffectGain', function(target, effect)
    super(target, effect)

    if target ~= nil and target:getObjType() == xi.objType.PET then
        local master = target:getMaster()
        if isVanguard(master) then
            effect:addMod(xi.mod.DMG,           -3500)
            effect:addMod(xi.mod.HASTE_ABILITY,  2500)
            effect:addMod(xi.mod.HASTE_MAGIC,    2500)
        end
    end
end)

-----------------------------------
-- Vanguard Maneuver Duration (2 hours)
-----------------------------------
local MANEUVER_EFFECT_NAMES =
{
    'fire_maneuver',
    'ice_maneuver',
    'wind_maneuver',
    'earth_maneuver',
    'thunder_maneuver',
    'water_maneuver',
    'light_maneuver',
    'dark_maneuver',
}

local VANGUARD_MANEUVER_DURATION_MS = 7200 * 1000 -- 2 hours

for _, maneuverName in ipairs(MANEUVER_EFFECT_NAMES) do
    m:addOverride(string.format('xi.effects.%s.onEffectGain', maneuverName), function(target, effect)
        super(target, effect)

        if target ~= nil and isVanguard(target) and effect ~= nil then
            effect:setDuration(VANGUARD_MANEUVER_DURATION_MS)
        end
    end)
end

-----------------------------------
-- Aegis Protocol (443) & Palisade Fortress Mode
-----------------------------------
m:addOverride('xi.effects.palisade.onEffectGain', function(target, effect)
    super(target, effect)

    if target ~= nil and target.isAutomaton and target:isAutomaton() and target:getLocalVar('OX_VANGUARD_AEGIS') == 1 then
        effect:addMod(xi.mod.DMG,                 -3000)
        effect:addMod(xi.mod.SHIELDBLOCKRATE,        35)
        effect:addMod(xi.mod.KNOCKBACK_REDUCTION,    10)
    end
end)

m:addOverride('xi.effects.palisade.onEffectTick', function(target, effect)
    super(target, effect)

    if target == nil or not target.isAutomaton or not target:isAutomaton() then
        return
    end
    if target:getLocalVar('OX_VANGUARD_AEGIS') ~= 1 then
        return
    end

    for _, ent in ipairs(xi.overlords.getNearbyMobs(target, 8)) do
        if ent.isEngaged and ent:isEngaged() and ent.addEnmity then
            ent:addEnmity(target, 250, 900)
        end
    end
end)

m:addOverride('xi.effects.palisade.onEffectLose', function(target, effect)
    super(target, effect)

    if target ~= nil and target.setLocalVar then
        target:setLocalVar('OX_VANGUARD_AEGIS', 0)
    end
end)

m:addOverride('xi.actions.abilities.aegis_protocol.onAbilityCheck', function(player, _target, _ability)
    if not isVanguard(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() or not pet:isAlive() then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.aegis_protocol.onUseAbility', function(player, _target, ability, action)
    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() then
        return 0
    end

    action:ID(player:getID(), pet:getID())

    pet:delStatusEffectSilent(xi.effect.PALISADE)
    pet:setLocalVar('OX_VANGUARD_AEGIS', 1)
    pet:addStatusEffect(xi.effect.PALISADE, { power = 35, duration = 10, origin = player, tick = 2 })

    -- Immediate initial magnetic threat pulse on activation
    for _, ent in ipairs(xi.overlords.getNearbyMobs(pet, 8)) do
        if ent.isEngaged and ent:isEngaged() and ent.addEnmity then
            ent:addEnmity(pet, 250, 900)
        end
    end

    ability:setMsg(xi.msg.basic.NONE)
    return 0
end)

-----------------------------------
-- Gyro Slam (444)
-----------------------------------
m:addOverride('xi.actions.abilities.gyro_slam.onAbilityCheck', function(player, _target, _ability)
    if not isVanguard(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() or not pet:isAlive() then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    if not isH2HEquipped(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.gyro_slam.onUseAbility', function(player, target, ability, _action)
    if target == nil or not target.isAlive or not target:isAlive() then
        return 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() or not pet:isAlive() then
        return 0
    end

    local lvl = player:getMainLvl() or 1
    local vit = player:getStat(xi.mod.VIT)
    local dex = player:getStat(xi.mod.DEX)
    local dmg = math.max(30, math.floor((vit + dex) * 2.0 + lvl * 2.5))

    dmg = utils.handleStoneskin(target, dmg, xi.attackType.PHYSICAL)
    target:takeDamage(dmg, player, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
    target:updateEnmityFromDamage(pet, dmg)

    if target.addEnmity then
        target:addEnmity(pet, 400, 1800)
    end

    -- Stun target
    if
        not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
        not xi.data.statusEffect.isTargetResistant(player, target, xi.effect.STUN) and
        not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
    then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 4, origin = player })
    end

    -- +20% Attack Delay (Slow) for 12s
    target:addStatusEffect(xi.effect.SLOW, { power = 2000, duration = 12, origin = player })

    -- Restore 15% HP to both Master and Automaton
    player:addHP(math.max(1, math.floor((player:getMaxHP() or 0) * 0.15)))
    pet:addHP(math.max(1, math.floor((pet:getMaxHP() or 0) * 0.15)))

    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return dmg
end)

-----------------------------------
-- Level-Up Sync for Active Automaton
-----------------------------------
m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    if isVanguard(player) then
        syncAutomatonMods(player, true)
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    if isVanguard(player) then
        syncAutomatonMods(player, true)
    end
end)

-----------------------------------
-- Crystal Definition (PUP = 18)
-----------------------------------
if xi.job and xi.job.PUP then
    spec.registerJob(xi.job.PUP, 'PUP',
    {
        {
            id          = 1,
            key         = VANGUARD_KEY,
            name        = 'Vanguard',
            role        = 'Automaton Proxy-Tank & Tactical Link',
            icon        = 'vanguard',
            reqLevel    = 10,
            extraTraits = { TRAIT_VANGUARDS_CORE },
            extraAbilities = function(_player, _lvl)
                return { ABIL_AEGIS_PROTOCOL, ABIL_GYRO_SLAM }
            end,
            description = 'Clockwork vanguard tank (Lv10+): pairs Hand-to-Hand combat with an armored Automaton proxy-tank—eliminating Maneuver Overload, funneling Master WS enmity/TP into the Automaton, and sharing damage safely across a clockwork tether.',
            highlights =
            {
                'Passives (Lv10/30/50/70+): +12/16/20/25% Max HP (Master) & +25/35/45/60% (Automaton), +8/14/20/26 VIT & DEX, +12/18/24/30% DEF (Master) & +20/30/40/50% (Automaton), -8/11/14/18% DT (Master) & -15/20/25/30% (Automaton), +25/35/45/60 Enmity (both).',
                'Hand-to-Hand & Automaton Mastery: +15/25/35/50 H2H & Automaton Melee/Ranged/Magic skill, +12/18/24/30% Guard/Counter Rate (Master), +15/20/25/30% Shield Block Rate (Automaton), 100% Overload Immunity, and 2-hour Maneuver duration.',
                'Clockwork Proxy Tether & Enmity Funnel: Strobe (15s) & Flashbulb (22s) recasts cut by 50% with 2x VE; H2H WSs transfer 100% VE to Automaton, grant +400 TP & 12% Max HP barrier, and inflict Concussive Blow (-15% ATK, -20 Acc, 15s).',
                'Emergency Chassis Link: Below 25% Automaton HP, 35% of subsequent Automaton damage redirects to Master until Automaton recovers above 35% HP.',
                'Tank Tradeoff & JAs: -20% ATK/RATK & -15% WSD (Master); Repair (20s CD, 0 oil, 45% HP heal, full cleanse, -20% DT 6s), Ventriloquy (15s CD, locks hate & +25 Enmity), Overdrive (30s, -35% DT, +50% Haste, Shield Bash/Strobe spam).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,                scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.VIT,                scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEX,                scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,               scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.DMG,                scaleTier(lvl, -800, -1100, -1400, -1800) },
                    { xi.mod.ENMITY,             scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.HTH,                scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.AUTO_MELEE_SKILL,   scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.AUTO_RANGED_SKILL,  scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.AUTO_MAGIC_SKILL,   scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.ADDITIVE_GUARD,     scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.COUNTER,            scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.OVERLOAD_THRESH,    500 },
                    { xi.mod.PREVENT_OVERLOAD,   1 },
                }
            end,
            onApply = function(player)
                attachPupListeners(player)
                syncAutomatonMods(player, true)
                local pet = player ~= nil and player.getPet and player:getPet() or nil
                if pet ~= nil and pet.isAutomaton and pet:isAutomaton() then
                    attachAutomatonListeners(pet)
                end
            end,
            onRemove = function(player)
                detachPupListeners(player)
                if player ~= nil and player.getPet then
                    local pet = player:getPet()
                    if pet ~= nil and pet.isAutomaton and pet:isAutomaton() then
                        pet:removeListener('OX_VANGUARD_AUTO_TICK')
                        clearAutomatonMods(pet)
                        if pet.delStatusEffectSilent then
                            pet:delStatusEffectSilent(xi.effect.PALISADE)
                            pet:delStatusEffectSilent(xi.effect.RAMPART)
                        end
                    end
                end
            end,
        },
    })
end

return m
