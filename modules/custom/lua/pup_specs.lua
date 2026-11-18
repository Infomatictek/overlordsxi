-----------------------------------
-- OverlordsXI Puppetmaster Crystal Specs
-- Registers Puppetmaster (job 18) Soul Crystal specializations:
--   1. Vanguard (VNG | Tier 6 Pure Tank): Valoredge Proxy-Tank & Tactical Link
--   3. Pugilist (PGL | Tier 1 Pure DPS): Tandem Combo Striker (Valoredge/Sharpshot)
-- (Animist [ANM | Tier 4 Healer] is registered in pup_healer_specs.lua)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
require('scripts/globals/job_utils/puppetmaster')
require('scripts/globals/pets/automaton')
require('scripts/globals/automaton')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_pup_specs')

local spec  = xi.overlords.spec
local slots = xi.overlords.slots

xi.overlords          = xi.overlords or {}
xi.overlords.pupSpecs = xi.overlords.pupSpecs or {}
local pupSpecs        = xi.overlords.pupSpecs

local VANGUARD_KEY = 'vanguard'
local PUGILIST_KEY = 'pugilist'
local ANIMIST_KEY  = 'animist'

-- Custom Trait IDs (164 reused for Vanguard; 180 allocated for Pugilist)
local TRAIT_VANGUARDS_CORE   = 164
local TRAIT_PUGILISTS_RHYTHM = 180

-- Native PUP Ability IDs
local ABIL_ACTIVATE         = 136
local ABIL_REPAIR           = 137
local ABIL_DEPLOY           = 138
local ABIL_RETRIEVE         = 140
local ABIL_FIRE_MANEUVER    = 141
local ABIL_ICE_MANEUVER     = 142
local ABIL_WIND_MANEUVER    = 143
local ABIL_EARTH_MANEUVER   = 144
local ABIL_THUNDER_MANEUVER = 145
local ABIL_WATER_MANEUVER   = 146
local ABIL_LIGHT_MANEUVER   = 147
local ABIL_DARK_MANEUVER    = 148
local ABIL_VENTRILOQUY      = 180
local ABIL_COOLDOWN         = 309
local ABIL_DEUS_EX_AUTOMATA = 310

-- Custom Ability IDs
-- Vanguard (451-452; recastIds 168-169, reused in-place)
local ABIL_AEGIS_PROTOCOL  = 451 -- Display: Clockwork Bulwark
local ABIL_GYRO_SLAM       = 452 -- Display: Hydraulic Slam
-- Pugilist (478-479; recastIds 174-175, newly allocated)
local ABIL_TANDEM_BARRAGE  = 478
local ABIL_LIMITER_RELEASE = 479

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.AEGIS_PROTOCOL  = ABIL_AEGIS_PROTOCOL
xi.jobAbility.GYRO_SLAM       = ABIL_GYRO_SLAM
xi.jobAbility.TANDEM_BARRAGE  = ABIL_TANDEM_BARRAGE
xi.jobAbility.LIMITER_RELEASE = ABIL_LIMITER_RELEASE

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.aegis_protocol  = xi.actions.abilities.aegis_protocol or {}
xi.actions.abilities.gyro_slam       = xi.actions.abilities.gyro_slam or {}
xi.actions.abilities.tandem_barrage  = xi.actions.abilities.tandem_barrage or {}
xi.actions.abilities.limiter_release = xi.actions.abilities.limiter_release or {}

local SHARED_PUP_ABILITIES =
{
    ABIL_ACTIVATE,
    ABIL_DEUS_EX_AUTOMATA,
    ABIL_DEPLOY,
    ABIL_RETRIEVE,
    ABIL_REPAIR,
    ABIL_COOLDOWN,
    ABIL_VENTRILOQUY,
    ABIL_FIRE_MANEUVER,
    ABIL_ICE_MANEUVER,
    ABIL_WIND_MANEUVER,
    ABIL_EARTH_MANEUVER,
    ABIL_THUNDER_MANEUVER,
    ABIL_WATER_MANEUVER,
    ABIL_LIGHT_MANEUVER,
    ABIL_DARK_MANEUVER,
}

local automatonModStateByPetId = {}
local lastWsCastAtByChar       = {}
local bulwarkSplitGuard        = false

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

local function getActivePupKey(entity)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.PUP
    then
        return nil
    end

    spec.ensureUpToDate(entity)
    local active = spec.get(entity, xi.job.PUP)
    if active == nil or not spec.isLevelEligible(entity, xi.job.PUP, active) then
        return nil
    end
    return active.key
end

local function isVanguard(entity)
    return getActivePupKey(entity) == VANGUARD_KEY
end

local function isPugilist(entity)
    return getActivePupKey(entity) == PUGILIST_KEY
end

local function isAnimist(entity)
    return getActivePupKey(entity) == ANIMIST_KEY
end

local function isAnyPupSpec(entity)
    local k = getActivePupKey(entity)
    return k == VANGUARD_KEY or k == PUGILIST_KEY or k == ANIMIST_KEY
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

local function unlockAndSetFrameHead(player, frameEnum, headEnum)
    if player == nil then
        return
    end
    if player.unlockAttachment then
        if frameEnum ~= nil then
            player:unlockAttachment(0x2000 + frameEnum)
        end
        if headEnum ~= nil then
            player:unlockAttachment(0x2000 + headEnum)
        end
    end
    if frameEnum ~= nil and player.setAutomatonFrame and player.getAutomatonFrame then
        if player:getAutomatonFrame() ~= frameEnum then
            player:setAutomatonFrame(frameEnum)
        end
    end
    if headEnum ~= nil and player.setAutomatonHead and player.getAutomatonHead then
        if player:getAutomatonHead() ~= headEnum then
            player:setAutomatonHead(headEnum)
        end
    end
end

local function enforcePupFrameHead(player)
    local key = getActivePupKey(player)
    if key == nil or (player.getMainLvl and (player:getMainLvl() or 1) < 10) then
        return
    end

    local curFrame = player.getAutomatonFrame and player:getAutomatonFrame() or nil
    local curHead  = player.getAutomatonHead and player:getAutomatonHead() or nil

    if key == VANGUARD_KEY then
        unlockAndSetFrameHead(player, xi.automaton.frame.VALOREDGE, xi.automaton.head.VALOREDGE)
    elseif key == PUGILIST_KEY then
        local validFrame = (curFrame == xi.automaton.frame.VALOREDGE or curFrame == xi.automaton.frame.SHARPSHOT)
        local validHead  = (curHead == xi.automaton.head.VALOREDGE or curHead == xi.automaton.head.SHARPSHOT)
        if not validFrame or not validHead then
            local targetFrame = validFrame and curFrame or xi.automaton.frame.VALOREDGE
            local targetHead  = validHead and curHead or (targetFrame == xi.automaton.frame.SHARPSHOT and xi.automaton.head.SHARPSHOT or xi.automaton.head.VALOREDGE)
            unlockAndSetFrameHead(player, targetFrame, targetHead)
        end
    elseif key == ANIMIST_KEY then
        local lvl        = player.getMainLvl and (player:getMainLvl() or 1) or 1
        local hqAllowed  = (lvl < 30)
        local validFrame = (curFrame == xi.automaton.frame.STORMWAKER) or (hqAllowed and curFrame == xi.automaton.frame.HARLEQUIN)
        local validHead  = (curHead == xi.automaton.head.SOULSOOTHER or curHead == xi.automaton.head.STORMWAKER) or (hqAllowed and curHead == xi.automaton.head.HARLEQUIN)
        if not validFrame or not validHead then
            local targetFrame = validFrame and curFrame or xi.automaton.frame.STORMWAKER
            local targetHead  = validHead and curHead or xi.automaton.head.SOULSOOTHER
            unlockAndSetFrameHead(player, targetFrame, targetHead)
        end
    end
end

local function cleanseDebuffs(entity, count)
    if entity == nil then
        return 0
    end
    local removed = 0
    local maxCleanse = count or 1
    if entity.eraseStatusEffect then
        for _ = 1, maxCleanse do
            if entity:eraseStatusEffect() == xi.effect.NONE then
                break
            end
            removed = removed + 1
        end
    end
    local extraEffects =
    {
        xi.effect.POISON,
        xi.effect.PARALYSIS,
        xi.effect.BLINDNESS,
        xi.effect.SILENCE,
        xi.effect.SLOW,
        xi.effect.WEIGHT,
        xi.effect.BIND,
        xi.effect.PLAGUE,
        xi.effect.CURSE_I,
        xi.effect.SLEEP_I,
        xi.effect.SLEEP_II,
    }
    if removed < maxCleanse and entity.delStatusEffect then
        for _, eff in ipairs(extraEffects) do
            if entity:hasStatusEffect(eff) then
                entity:delStatusEffect(eff)
                removed = removed + 1
                if removed >= maxCleanse then
                    break
                end
            end
        end
    end
    return removed
end

-----------------------------------
-- Automaton Passive Mod & Clamp Sync
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

function pupSpecs.syncSpecPetDamageMods(player, pet)
    if player == nil or pet == nil then
        return
    end
    if spec.syncPetRoleMods then
        spec.syncPetRoleMods(player, pet)
    end
end

local function syncAutomatonMods(player, force)
    if player == nil or not player.getPet then
        return
    end

    enforcePupFrameHead(player)

    local pet = player:getPet()
    if pet == nil or not pet.isAutomaton or not pet:isAutomaton() then
        return
    end

    pupSpecs.syncSpecPetDamageMods(player, pet)

    local key = getActivePupKey(player)
    if key ~= VANGUARD_KEY and key ~= PUGILIST_KEY then
        clearAutomatonMods(pet)
        return
    end

    local petId    = pet:getID()
    local lvl      = player:getMainLvl() or 1
    local h2h      = isH2HEquipped(player) and 1 or 0
    local stateKey = string.format('%s:%u:%u', key, lvl, h2h)

    local prev = automatonModStateByPetId[petId]
    if not force and prev ~= nil and prev.key == stateKey then
        return
    end

    local prevBlockMod = prev and prev.prevBlockMod
    if prevBlockMod == nil and pet.getMobMod and key == VANGUARD_KEY then
        prevBlockMod = pet:getMobMod(xi.mobMod.CAN_SHIELD_BLOCK) or 0
    end

    clearAutomatonMods(pet)

    local mods = {}
    if key == VANGUARD_KEY then
        if h2h == 1 then
            mods =
            {
                { xi.mod.HPP,             scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.DEFP,            scaleTier(lvl, 14, 20, 26, 32) },
                { xi.mod.DMG,             -3500 },
                { xi.mod.ENMITY,          scaleTier(lvl, 60, 80, 100, 120) },
                { xi.mod.SHIELDBLOCKRATE, scaleTier(lvl, 15, 20, 25, 30) },
            }
        else
            mods =
            {
                { xi.mod.DMG,             -3500 },
                { xi.mod.ENMITY,          scaleTier(lvl, 60, 80, 100, 120) },
            }
        end
        if xi.mod.DMGBREATH then
            table.insert(mods, { xi.mod.DMGBREATH, -10000 })
        end
        if xi.mod.UDMBREATH then
            table.insert(mods, { xi.mod.UDMBREATH, -10000 })
        end
        if xi.mod.DMGMAGIC then
            table.insert(mods, { xi.mod.DMGMAGIC, -10000 })
        end
        if xi.mod.UDMMAGIC then
            table.insert(mods, { xi.mod.UDMMAGIC, -10000 })
        end
        if pet.setMobMod then
            pet:setMobMod(xi.mobMod.CAN_SHIELD_BLOCK, 1)
        end
    elseif key == PUGILIST_KEY then
        if h2h == 1 then
            mods =
            {
                { xi.mod.ATTP,          scaleTier(lvl, 15, 22, 30, 38) },
                { xi.mod.RATTP,         scaleTier(lvl, 15, 22, 30, 38) },
                { xi.mod.HASTE_ABILITY, scaleTier(lvl, 1000, 1500, 2000, 2500) },
                { xi.mod.DOUBLE_ATTACK, scaleTier(lvl, 10, 15, 20, 25) },
                { xi.mod.CRITHITRATE,   scaleTier(lvl, 8, 12, 16, 20) },
                { xi.mod.ENMITY,        -scaleTier(lvl, 15, 20, 25, 35) },
            }
        else
            mods =
            {
                { xi.mod.ENMITY,        -scaleTier(lvl, 15, 20, 25, 35) },
            }
        end
    end

    if pet.addMod then
        for _, entry in ipairs(mods) do
            pet:addMod(entry[1], entry[2])
        end
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

function pupSpecs.syncAll(player)
    if player == nil then
        return
    end
    enforcePupFrameHead(player)
    syncAutomatonMods(player, true)
end

-----------------------------------
-- Automaton Spawn & AI Tick
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

        if xi.combat and xi.combat.behavior and xi.combat.behavior.isEntityBusy(mobArg) then
            return
        end

        local target = mobArg:getTarget()
        if target == nil or not target:isAlive() then
            return
        end

        -- Overdrive rapid single-target Provoke / Shield Bash loop
        if mobArg:hasStatusEffect(xi.effect.OVERDRIVE) then
            local now  = os.time()
            local next = mobArg:getLocalVar('OX_OD_SPAM_AT') or 0
            if now >= next then
                local step = mobArg:getLocalVar('OX_OD_SPAM_STEP') or 0
                mobArg:setLocalVar('OX_OD_SPAM_AT', now + 3)
                mobArg:setLocalVar('OX_OD_SPAM_STEP', (step + 1) % 2)
                if step % 2 == 0 then
                    mobArg:useMobAbility(xi.mobSkill.SHIELD_BASH_AUTOMATON)
                else
                    mobArg:useMobAbility(xi.mobSkill.PROVOKE_AUTOMATON)
                end
            end
        end
    end)
end

m:addOverride('xi.pets.automaton.onMobSpawn', function(mob)
    super(mob)

    if mob == nil then
        return
    end

    local master = mob:getMaster()
    if not isAnyPupSpec(master) then
        return
    end

    syncAutomatonMods(master, true)

    if isVanguard(master) then
        attachAutomatonListeners(mob)
        -- Initial spawn recasts for Strobe (12s) and Shield Bash (18s)
        if mob.addRecast then
            mob:addRecast(xi.recast.ABILITY, xi.mobSkill.PROVOKE_AUTOMATON,     12)
            mob:addRecast(xi.recast.ABILITY, xi.mobSkill.SHIELD_BASH_AUTOMATON, 18)
        end
    end
end)

m:addOverride('xi.pets.automaton.onMobDeath', function(mob)
    if mob ~= nil and mob.getID then
        automatonModStateByPetId[mob:getID()] = nil
    end
    super(mob)
end)

-----------------------------------
-- Valoredge Tank AI Overrides (Single-Target Only)
-----------------------------------
m:addOverride('xi.actions.abilities.pets.automaton.provoke.onAutomatonAbility', function(target, automaton, skill, master, action)
    if isVanguard(master) then
        automaton:addRecast(xi.recast.ABILITY, skill:getID(), 12)
        if target ~= nil and target.isAlive and target:isAlive() then
            if target.addEnmity then
                target:addEnmity(automaton, 300, 2400)
            end
            if target.addStatusEffect then
                target:addStatusEffect(xi.effect.BLINDNESS, { power = 20, duration = 12, origin = automaton })
            end
        end
        skill:setMsg(xi.msg.basic.PROVOKE_SWITCH)
        return 0
    end

    return super(target, automaton, skill, master, action)
end)

m:addOverride('xi.actions.abilities.pets.automaton.shield_bash.onAutomatonAbility', function(target, automaton, skill, master, action)
    if isVanguard(master) then
        automaton:addRecast(xi.recast.ABILITY, skill:getID(), 18)
        if target ~= nil and target.isAlive and target:isAlive() then
            if
                not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
                not xi.data.statusEffect.isTargetResistant(automaton, target, xi.effect.STUN) and
                not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
            then
                target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = automaton })
            end
            if target.addEnmity then
                target:addEnmity(automaton, 250, 1200)
            end
        end
        skill:setMsg(xi.msg.basic.USES_ABILITY_RECOVER_TP or xi.msg.basic.JA_DAMAGE)
        return 0
    end

    return super(target, automaton, skill, master, action)
end)

m:addOverride('xi.actions.abilities.pets.automaton.cannibal_blade.onAutomatonAbility', function(target, automaton, skill, master, action)
    if isVanguard(master) then
        local heal = math.max(1, math.floor((automaton:getMaxHP() or 0) * 0.20))
        local healed = automaton:addHP(heal)
        if target ~= nil and target.isAlive and target:isAlive() and target.addEnmity then
            target:addEnmity(automaton, 300, 1200)
        end
        automaton:setTP(0)
        skill:setMsg(xi.msg.basic.SKILL_RECOVERS_HP)
        return healed
    end

    return super(target, automaton, skill, master, action)
end)

-----------------------------------
-- Automaton Mobskill Damage Clamps & Pugilist Tandem Opening
-----------------------------------
local TANDEM_OPENING_SKILLS =
{
    [xi.mobSkill.STRING_SHREDDER or 1941]  = true,
    [xi.mobSkill.ARMOR_SHATTERER or 2744]  = true,
    [xi.mobSkill.ARCUBALLISTA or 1943]     = true,
    [xi.mobSkill.BONE_CRUSHER or 1942]     = true,
}

local TANDEM_OPENING_NAMES =
{
    ['string_shredder'] = true,
    ['armor_shatterer'] = true,
    ['arcuballista']    = true,
    ['bone_crusher']    = true,
}

m:addOverride('xi.mobskills.processDamage', function(actor, target, skill, action, info)
    if
        actor ~= nil and
        actor.isAutomaton and
        actor:isAutomaton() and
        info ~= nil and
        (info.damage or 0) > 0
    then
        local master = actor.getMaster and actor:getMaster() or nil
        if isVanguard(master) then
            info.damage = math.max(1, math.floor(info.damage * 0.25))
        elseif isAnimist(master) then
            info.damage = math.max(1, math.floor(info.damage * 0.20))
        elseif isPugilist(master) and target ~= nil then
            local exp = target:getLocalVar('OX_PGL_OPENING_EXP') or 0
            local by  = target:getLocalVar('OX_PGL_OPENING_BY') or 0
            local sid = skill and skill.getID and skill:getID() or 0
            local sname = skill and skill.getName and string.lower(tostring(skill:getName())) or ''
            if exp >= os.time() and by == (master:getID() or 0) and (TANDEM_OPENING_SKILLS[sid] or TANDEM_OPENING_NAMES[sname]) then
                target:setLocalVar('OX_PGL_OPENING_EXP', 0)
                target:setLocalVar('OX_PGL_OPENING_BY', 0)
                info.damage = math.max(1, math.floor(info.damage * 1.25))
                if target.getStatusEffect then
                    local sc = target:getStatusEffect(xi.effect.SKILLCHAIN)
                    if sc ~= nil and sc.getDuration and sc.setDuration then
                        sc:setDuration(sc:getDuration() + 3000)
                    end
                end
            end
        end
    end

    return super(actor, target, skill, action, info)
end)

-- Block Soulsoother Cure spells on Pugilist
for _, spellName in ipairs({ 'cure', 'cure_ii', 'cure_iii', 'cure_iv', 'cure_v', 'cure_vi' }) do
    m:addOverride(string.format('xi.actions.spells.white.%s.onMagicCastingCheck', spellName), function(caster, target, spell)
        if caster ~= nil and caster.isAutomaton and caster:isAutomaton() and isPugilist(caster:getMaster()) then
            return xi.msg.basic.CANNOT_CAST_SPELL
        end
        return super(caster, target, spell)
    end)
end

-----------------------------------
-- Vanguard Pet AoE/Conal Immunity & Clockwork Bulwark 50% Split
-----------------------------------
local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage

function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    if defender == nil or amount == nil or amount <= 0 then
        return amount or 0
    end

    -- 1. Vanguard Valoredge 100% AoE/Conal Mob Damage Immunity
    if defender.isAutomaton and defender:isAutomaton() then
        local master = defender:getMaster()
        if isVanguard(master) then
            if attackType == xi.attackType.MAGICAL or attackType == xi.attackType.BREATH then
                return 0
            end
            if attacker ~= nil and attacker.isMob and attacker:isMob() and attacker.getTarget then
                local mobTarget = attacker:getTarget()
                if mobTarget ~= nil and mobTarget:getID() ~= defender:getID() then
                    return 0
                end
            end
        end
    end

    -- 2. Clockwork Bulwark (50% split reduced by 25% between Master and Valoredge)
    if bulwarkSplitGuard then
        return amount
    end

    local master, partner = nil, nil
    if defender.isAutomaton and defender:isAutomaton() then
        master  = defender:getMaster()
        partner = master
    elseif defender.isPC and defender:isPC() then
        master  = defender
        partner = defender.getPet and defender:getPet() or nil
    end

    if
        master ~= nil and
        isVanguard(master) and
        partner ~= nil and
        partner.isAlive and partner:isAlive() and
        (master:getLocalVar('OX_VNG_BULWARK_EXP') or 0) >= os.time() and
        (not master.getZoneID or not partner.getZoneID or master:getZoneID() == partner:getZoneID())
    then
        local partnerShare = math.floor(amount * 0.50 * 0.75)
        local selfShare    = math.max(0, math.floor(amount * 0.50))
        if partnerShare > 0 and partner:getHP() > partnerShare then
            bulwarkSplitGuard = true
            pcall(function()
                partner:takeDamage(partnerShare, attacker, attackType, damageType)
            end)
            bulwarkSplitGuard = false
            return selfShare
        end
    end

    return amount
end

-----------------------------------
-- Master WS Listeners (Vanguard & Pugilist)
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

    player:addListener('WEAPONSKILL_USE', 'OX_PUP_WS', function(actor, target, ws)
        local key = getActivePupKey(actor)
        if (key ~= VANGUARD_KEY and key ~= PUGILIST_KEY) or target == nil or not isHandToHandWs(ws) then
            return
        end

        local charId = actor.getID and actor:getID() or 0
        local now    = xi.overlords.nowSec()
        if charId > 0 and (now - (lastWsCastAtByChar[charId] or 0)) <= 0.1 then
            return
        end
        if charId > 0 then
            lastWsCastAtByChar[charId] = now
        end

        local pet = actor.getPet and actor:getPet() or nil

        if key == PUGILIST_KEY then
            if pet ~= nil and pet:isAutomaton() and pet:isAlive() and pet.addTP then
                pet:addTP(350)
            end
            if target.isAlive and target:isAlive() then
                target:setLocalVar('OX_PGL_OPENING_EXP', os.time() + 8)
                target:setLocalVar('OX_PGL_OPENING_BY', charId)
            end
        elseif key == VANGUARD_KEY then
            -- Heal Valoredge 18% Max HP
            if pet ~= nil and pet:isAutomaton() and pet:isAlive() then
                local heal = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.18))
                pet:addHP(heal)
            end

            -- Grant Master 10% Max HP Alloy Plating Stoneskin (12s)
            local barrier = math.max(1, math.floor((actor:getMaxHP() or 0) * 0.10))
            if actor.delStatusEffectSilent then
                actor:delStatusEffectSilent(xi.effect.STONESKIN)
            end
            if actor.addStatusEffect then
                actor:addStatusEffect(xi.effect.STONESKIN, { power = barrier, duration = 12, origin = actor, tier = 4 })
            end

            -- Apply single-target EFF_OX_DEB_CRIPPLE (-15% ATTP/MATT & -20 ACC, 15s)
            if target.isAlive and target:isAlive() and slots and slots.applySlot then
                slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, 15, 15, actor,
                {
                    { xi.mod.ATTP, -15 },
                    { xi.mod.MATT, -15 },
                    { xi.mod.ACC,  -20 },
                }, slots.EFF_OX_DEB_CRIPPLE)
            end
        end
    end)
end

-----------------------------------
-- Shared PUP Lv.10+ Abilities (Activate, Deus Ex Automata, Cooldown, Maneuvers, Repair, Ventriloquy, Overdrive)
-----------------------------------
for _, summonName in ipairs({ 'activate', 'deus_ex_automata' }) do
    m:addOverride('xi.actions.abilities.' .. summonName .. '.onAbilityCheck', function(player, target, ability)
        if isAnyPupSpec(player) then
            if player.getPet and player:getPet() ~= nil then
                return xi.msg.basic.ALREADY_HAS_A_PET, 0
            end
            if player.canUseMisc and not player:canUseMisc(xi.zoneMisc.PET) then
                return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
            end
            enforcePupFrameHead(player)
            return 0, 0
        end
        return super(player, target, ability)
    end)

    m:addOverride('xi.actions.abilities.' .. summonName .. '.onUseAbility', function(player, target, ability)
        if isAnyPupSpec(player) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(15)
            end
            enforcePupFrameHead(player)
            xi.pet.spawnPet(player, xi.petId.AUTOMATON)
            local pet = player:getPet()
            if pet ~= nil then
                syncAutomatonMods(player, true)
                if pet.updateHealth then
                    pet:updateHealth()
                end
                pet:setHP(pet:getMaxHP())
                pet:setMP(pet:getMaxMP())
            end
            return 0
        end
        return super(player, target, ability)
    end)
end

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseCooldown', function(player, target, ability)
    if isAnyPupSpec(player) and ability ~= nil and ability.setRecast then
        ability:setRecast(30)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.automaton.onUseManeuver', function(player, target, ability, action)
    if isAnyPupSpec(player) then
        if ability ~= nil and ability.setRecast then
            if isPugilist(player) and player:hasStatusEffect(xi.effect.OVERDRIVE) then
                ability:setRecast(0)
            else
                ability:setRecast(10)
            end
        end
        -- Guarantee 100% Overload Immunity regardless of Water Maneuver
        if player.reduceBurden then
            player:reduceBurden(100, 100)
        end
        local res = super(player, target, ability, action)
        if player:hasStatusEffect(xi.effect.OVERLOAD) then
            player:delStatusEffectSilent(xi.effect.OVERLOAD)
        end
        local pet = player:getPet()
        if pet ~= nil and pet:hasStatusEffect(xi.effect.OVERLOAD) then
            pet:delStatusEffectSilent(xi.effect.OVERLOAD)
        end
        return res
    end
    return super(player, target, ability, action)
end)

m:addOverride('xi.job_utils.puppetmaster.onAbilityCheckRepair', function(player, target, ability)
    if isVanguard(player) or isPugilist(player) then
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
    local key = getActivePupKey(player)
    if key ~= VANGUARD_KEY and key ~= PUGILIST_KEY then
        return super(player, target, ability, action)
    end

    local pet = player:getPet()
    if not pet then
        return 0
    end

    action:ID(player:getID(), pet:getID())
    pet:wakeUp()

    if key == PUGILIST_KEY then
        if ability and ability.setRecast then
            ability:setRecast(30)
        end
        local heal = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.45))
        return pet:addHP(heal)
    end

    -- Vanguard: 25s CD, 0 oil, heals Valoredge 50% HP and Master 18% HP + 1-debuff cleanse
    if ability and ability.setRecast then
        ability:setRecast(25)
    end
    local petHeal    = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.50))
    local masterHeal = math.max(1, math.floor((player:getMaxHP() or 0) * 0.18))
    local totalHealing = pet:addHP(petHeal)
    player:addHP(masterHeal)
    cleanseDebuffs(pet, 1)
    cleanseDebuffs(player, 1)
    return totalHealing
end)

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseVentriloquy', function(player, target, ability)
    local key = getActivePupKey(player)
    if key == PUGILIST_KEY then
        if ability and ability.setRecast then
            ability:setRecast(25)
        end
        return super(player, target, ability)
    elseif key ~= VANGUARD_KEY then
        return super(player, target, ability)
    end

    if ability and ability.setRecast then
        ability:setRecast(20)
    end

    local pet = player:getPet()
    if pet and target and target.isMob and target:isMob() then
        local playerCE = target:getCE(player) or 0
        local playerVE = target:getVE(player) or 0
        local petCE    = target:getCE(pet) or 0
        local petVE    = target:getVE(pet) or 0

        local masterLeading = (playerCE + playerVE) >= (petCE + petVE)
        local newLeader     = masterLeading and pet or player
        local bonusVE       = math.max(400, math.floor(math.max(playerVE, petVE) * 0.25))

        target:setCE(player, petCE)
        target:setVE(player, petVE)
        target:setCE(pet, playerCE)
        target:setVE(pet, playerVE)
        target:addEnmity(newLeader, 0, bonusVE)

        if target.updateEnmity then
            target:updateEnmity(newLeader)
        end

        newLeader:delStatusEffectSilent(xi.effect.SENTINEL)
        newLeader:addStatusEffect(xi.effect.SENTINEL, { power = 1800, duration = 8, origin = player })
    end
end)

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseOverdrive', function(player, target, ability, action)
    if not isVanguard(player) and not isPugilist(player) then
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
            effect:addMod(xi.mod.DMG,          -3500)
            effect:addMod(xi.mod.HASTE_ABILITY, 2500)
            effect:addMod(xi.mod.HASTE_MAGIC,   2500)
        elseif isPugilist(master) then
            effect:addMod(xi.mod.STORETP,       50)
        end
    end
end)

-----------------------------------
-- Vanguard Custom JAs (451-452: Clockwork Bulwark & Hydraulic Slam)
-----------------------------------
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

    if ability and ability.setRecast then
        ability:setRecast(35)
    end

    action:ID(player:getID(), pet:getID())
    player:setLocalVar('OX_VNG_BULWARK_EXP', os.time() + 12)

    for _, unit in ipairs({ player, pet }) do
        if slots and slots.applySlot then
            slots.applySlot(unit, slots.EFF_OX_SUP_WARD, 1500, 12, player,
            {
                { xi.mod.DMG,                 -1500 },
                { xi.mod.KNOCKBACK_REDUCTION,   100 },
            }, xi.effect.PALISADE)
        else
            unit:delStatusEffectSilent(xi.effect.PALISADE)
            unit:addStatusEffect(xi.effect.PALISADE, { power = 35, duration = 12, origin = player })
        end
    end

    ability:setMsg(xi.msg.basic.NONE)
    return 0
end)

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

    if ability and ability.setRecast then
        ability:setRecast(22)
    end

    local lvl = player:getMainLvl() or 1
    local vit = player:getStat(xi.mod.VIT)
    local dex = player:getStat(xi.mod.DEX)
    local dmg = math.max(30, math.floor((vit + dex) * 1.5 + lvl * 2.0))

    dmg = utils.handleStoneskin(target, dmg, xi.attackType.PHYSICAL)
    target:takeDamage(dmg, player, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
    target:updateEnmityFromDamage(pet, dmg)

    if target.addEnmity then
        target:addEnmity(pet, 400, 1800)
    end

    -- 2s NM-safe Stun
    if
        not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
        not xi.data.statusEffect.isTargetResistant(player, target, xi.effect.STUN) and
        not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
    then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = player })
    end

    -- EFF_OX_DEB_BREACH (-15% DEF/MDEF, 12s)
    if slots and slots.applySlot then
        slots.applySlot(target, slots.EFF_OX_DEB_BREACH, 15, 12, player,
        {
            { xi.mod.DEFP, -15 },
            { xi.mod.MDEF, -15 },
        }, slots.EFF_OX_DEB_BREACH)
    end

    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return dmg
end)

-----------------------------------
-- Pugilist Custom JAs (478-479: Tandem Barrage & Limiter Release)
-----------------------------------
m:addOverride('xi.actions.abilities.tandem_barrage.onAbilityCheck', function(player, _target, _ability)
    if not isPugilist(player) then
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

m:addOverride('xi.actions.abilities.tandem_barrage.onUseAbility', function(player, target, ability, _action)
    if target == nil or not target.isAlive or not target:isAlive() then
        return 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() or not pet:isAlive() then
        return 0
    end

    if ability and ability.setRecast then
        ability:setRecast(25)
    end

    local lvl = player:getMainLvl() or 1
    local str = player:getStat(xi.mod.STR)
    local dex = player:getStat(xi.mod.DEX)
    local dmg = math.max(40, math.floor((str + dex) * 2.2 + lvl * 3.0))

    dmg = utils.handleStoneskin(target, dmg, xi.attackType.PHYSICAL)
    target:takeDamage(dmg, player, xi.attackType.PHYSICAL, xi.damageType.BLUNT)

    if player.addTP then
        player:addTP(300)
    end
    if pet.addTP then
        pet:addTP(300)
    end

    if slots and slots.applySlot then
        slots.applySlot(target, slots.EFF_OX_DEB_BREACH, 15, 10, player,
        {
            { xi.mod.DEFP, -15 },
        }, slots.EFF_OX_DEB_BREACH)
    end

    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return dmg
end)

m:addOverride('xi.actions.abilities.limiter_release.onAbilityCheck', function(player, _target, _ability)
    if not isPugilist(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() or not pet:isAlive() then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.limiter_release.onUseAbility', function(player, _target, ability, action)
    local pet = player:getPet()
    if pet == nil or not pet:isAutomaton() then
        return 0
    end

    if ability and ability.setRecast then
        ability:setRecast(35)
    end

    action:ID(player:getID(), pet:getID())

    for _, unit in ipairs({ player, pet }) do
        if slots and slots.applySlot then
            slots.applySlot(unit, slots.EFF_OX_SUP_OFFENSE, 22, 12, player,
            {
                { xi.mod.ATTP,          22 },
                { xi.mod.RATTP,         22 },
                { xi.mod.DOUBLE_ATTACK, 15 },
                { xi.mod.RAPID_SHOT,    15 },
                { xi.mod.DEFP,         -15 },
            }, xi.effect.BERSERK)
        else
            unit:delStatusEffectSilent(xi.effect.BERSERK)
            unit:addStatusEffect(xi.effect.BERSERK, { power = 22, duration = 12, origin = player })
        end
    end

    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return xi.effect.BERSERK
end)

-----------------------------------
-- Level-Up Sync for Active Automaton
-----------------------------------
m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    if isAnyPupSpec(player) then
        syncAutomatonMods(player, true)
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    if isAnyPupSpec(player) then
        syncAutomatonMods(player, true)
    end
end)

-----------------------------------
-- Crystal Definitions (PUP = 18)
-----------------------------------
if xi.job and xi.job.PUP then
    spec.registerCrystal(xi.job.PUP,
    {
        id          = 1,
            key         = VANGUARD_KEY,
            name        = 'Vanguard',
            abr         = 'VNG',
            role        = 'Tank',
            icon        = 'vanguard',
            reqLevel    = 10,
            extraTraits = { TRAIT_VANGUARDS_CORE },
            extraAbilities = function(_player, lvl)
                if (lvl or 1) >= 10 then
                    local out = {}
                    for _, id in ipairs(SHARED_PUP_ABILITIES) do
                        table.insert(out, id)
                    end
                    table.insert(out, ABIL_AEGIS_PROTOCOL)
                    table.insert(out, ABIL_GYRO_SLAM)
                    return out
                end
                return {}
            end,
            description = 'Pure Valoredge Automaton Tank (Lv10+, H2H): forces Valoredge Head+Frame, 100% Overload Immunity, single-target Strobe/Shield Bash/Cannibal Blade tanking, Ventriloquy hate swap, Clockwork Bulwark 50% split, and Hydraulic Slam.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+, H2H): +14/18/22/28% Master & Pet HP, +8/14/20/26 VIT/DEX, +14/20/26/32% DEF, -10/13/16/20% Master DT, -35% Pet DT + 100% AoE/Conal Immunity, +60/80/100/120 Enmity, +12/16/20/24% Guard, +15/25/35/50 H2H & Auto Melee.',
                'Single-Target Valoredge AI: Strobe (12s CD Provoke + -20 ACC Blind), Shield Bash (18s CD 2s NM-safe Stun), Cannibal Blade (20% Auto Max HP heal + VE), Ventriloquy (20s CD swap + 25% VE + -18% DT 8s).',
                'H2H WS & Repair: H2H WSs heal Valoredge 18% HP, grant Master 10% Alloy Plating Stoneskin (12s) & inflict EFF_OX_DEB_CRIPPLE; Repair (25s CD, 0 oil) heals Valoredge 50% + Master 18% + 1-debuff cleanse.',
                'Custom JAs: Clockwork Bulwark (35s CD, 12s 50% hit split reduced by 25%, -15% DT & Knockback Immunity) & Hydraulic Slam (22s CD, ST 6y strike + 2s Stun + EFF_OX_DEB_BREACH).',
            },
            mods = function(player, lvl)
                local base =
                {
                    { xi.mod.OVERLOAD_THRESH,  500 },
                    { xi.mod.PREVENT_OVERLOAD, 1 },
                }
                if not isH2HEquipped(player) then
                    return base
                end
                return
                {
                    { xi.mod.HPP,              scaleTier(lvl, 14, 18, 22, 28) },
                    { xi.mod.VIT,              scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEX,              scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,             scaleTier(lvl, 14, 20, 26, 32) },
                    { xi.mod.DMG,              -scaleTier(lvl, 1000, 1300, 1600, 2000) },
                    { xi.mod.ENMITY,           scaleTier(lvl, 60, 80, 100, 120) },
                    { xi.mod.ADDITIVE_GUARD,   scaleTier(lvl, 12, 16, 20, 24) },
                    { xi.mod.HTH,              scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.AUTO_MELEE_SKILL, scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.OVERLOAD_THRESH,  500 },
                    { xi.mod.PREVENT_OVERLOAD, 1 },
                }
            end,
            onApply = function(player)
                enforcePupFrameHead(player)
                attachPupListeners(player)
                syncAutomatonMods(player, true)
                local pet = player ~= nil and player.getPet and player:getPet() or nil
                if pet ~= nil and pet.isAutomaton and pet:isAutomaton() then
                    attachAutomatonListeners(pet)
                end
            end,
            onRemove = function(player)
                detachPupListeners(player)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_VNG_BULWARK_EXP', 0)
                end
                if player ~= nil and player.getPet then
                    local pet = player:getPet()
                    if pet ~= nil and pet.isAutomaton and pet:isAutomaton() then
                        pet:removeListener('OX_VANGUARD_AUTO_TICK')
                        clearAutomatonMods(pet)
                        if pet.delStatusEffectSilent then
                            pet:delStatusEffectSilent(xi.effect.PALISADE)
                            pet:delStatusEffectSilent(xi.effect.SENTINEL)
                        end
                    end
                end
            end,
        })
    spec.registerCrystal(xi.job.PUP,
    {
        id          = 3,
            key         = PUGILIST_KEY,
            name        = 'Pugilist',
            abr         = 'PGL',
            role        = 'Damage',
            icon        = 'pugilist',
            reqLevel    = 10,
            extraTraits = { TRAIT_PUGILISTS_RHYTHM },
            extraAbilities = function(_player, lvl)
                if (lvl or 1) >= 10 then
                    local out = {}
                    for _, id in ipairs(SHARED_PUP_ABILITIES) do
                        table.insert(out, id)
                    end
                    table.insert(out, ABIL_TANDEM_BARRAGE)
                    table.insert(out, ABIL_LIMITER_RELEASE)
                    return out
                end
                return {}
            end,
            description = 'Pure Tandem DPS (Lv10+, H2H): Valoredge/Sharpshot Automaton with 0% post-damage penalty, +350 Pet TP & Tandem Opening on H2H WSs, Tandem Barrage, and Limiter Release.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+, H2H): +15/22/30/38% Master & Pet ATK/RATK, +10/15/20/25% Martial Arts/DA & Pet Haste, +8/12/16/20% Crit Rate, +15/25/35/50 H2H & Auto Melee/Ranged, -15/20/25/35 Enmity, 100% Overload Immunity.',
                'Tandem Combo Loop: H2H WSs grant +350 Pet TP & 8s single-target Tandem Opening (+25% damage on String Shredder/Armor Shatterer/Arcuballista/Bone Crusher & +3s Skillchain window).',
                'Custom JAs: Tandem Barrage (25s CD, ST 6y strike, +300 TP both, -15% DEF 10s) & Limiter Release (35s CD, 12s +22% ATK/RATK, +15% DA/Rapid Shot, -15% DEF); Overdrive grants +50 Store TP & 0s Maneuver CDs.',
            },
            mods = function(player, lvl)
                local base =
                {
                    { xi.mod.OVERLOAD_THRESH,  500 },
                    { xi.mod.PREVENT_OVERLOAD, 1 },
                }
                if not isH2HEquipped(player) then
                    return base
                end
                return
                {
                    { xi.mod.ATTP,              scaleTier(lvl, 15, 22, 30, 38) },
                    { xi.mod.RATTP,             scaleTier(lvl, 15, 22, 30, 38) },
                    { xi.mod.MARTIAL_ARTS,      scaleTier(lvl, 10, 15, 20, 25) },
                    { xi.mod.DOUBLE_ATTACK,     scaleTier(lvl, 10, 15, 20, 25) },
                    { xi.mod.CRITHITRATE,       scaleTier(lvl, 8, 12, 16, 20) },
                    { xi.mod.ENMITY,            -scaleTier(lvl, 15, 20, 25, 35) },
                    { xi.mod.HTH,               scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.AUTO_MELEE_SKILL,  scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.AUTO_RANGED_SKILL, scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.OVERLOAD_THRESH,   500 },
                    { xi.mod.PREVENT_OVERLOAD,  1 },
                }
            end,
            onApply = function(player)
                enforcePupFrameHead(player)
                attachPupListeners(player)
                syncAutomatonMods(player, true)
            end,
            onRemove = function(player)
                detachPupListeners(player)
                if player ~= nil and player.getPet then
                    local pet = player:getPet()
                    if pet ~= nil and pet.isAutomaton and pet:isAutomaton() then
                        clearAutomatonMods(pet)
                    end
                end
            end,
        })
end

return m
