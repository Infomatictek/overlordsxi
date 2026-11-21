-----------------------------------
-- SoulspireXI Beastmaster Crystal Spec
-- Registers the Beastmaster (job 9) Soul Crystal specialization:
--   1. Alpha Warden (ALW) : Symbiotic Soul-Link & Pack-Mitigation Tank (1H Axe + Tank Jug Pet)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('modules/custom/lua/soulspire_shared_slots')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/beastmaster')
require('scripts/globals/pets')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('soulspire_bst_specs')

local spec  = xi.soulspire.spec
local slots = xi.soulspire.slots

xi.soulspire          = xi.soulspire or {}
xi.soulspire.bstSpecs = xi.soulspire.bstSpecs or {}

local ALPHA_WARDEN_KEY = 'alphawarden'

-- Custom Trait ID (166: Alpha's Soul-Link)
local TRAIT_ALPHA_SOUL_LINK = 166

-- Custom Ability IDs (441-442; recastIds 216-217)
local ABIL_SOUL_BOND  = 441
local ABIL_FERAL_ROAR = 442

-- Native BST Ability IDs unlocked @ Lv. 10+
local ABIL_FIGHT           = 69
local ABIL_HEEL            = 70
local ABIL_SIC             = 72
local ABIL_STAY            = 73
local ABIL_REWARD          = 78
local ABIL_CALL_BEAST      = 85
local ABIL_SNARL           = 225
local ABIL_READY           = 251
local ABIL_BESTIAL_LOYALTY = 387

-- Custom Status Effect IDs (847-852; registered in patch 0025)
local EFFECT_ALPHA_PACK_INSTINCT = 847
local EFFECT_ALPHA_RENDING_BITE  = 848
local EFFECT_ALPHA_SOUL_BOND     = 849
local EFFECT_ALPHA_FERAL_ROAR    = 850
local EFFECT_ALPHA_FAMILIAR_BOND = 851
local EFFECT_ALPHA_REWARD_BOND   = 852

-- 4 Whitelisted Tank Guardian Beasts (from sql/pet_list.sql)
local GUARDIAN_BEASTS =
{
    { id = 24, name = 'CourierCarrie',  label = 'Armored Crab (CourierCarrie)' },
    { id = 45, name = 'PanzerGalahad',  label = 'Rhinoceros Beetle (PanzerGalahad)' },
    { id = 65, name = 'CrudeRaphie',    label = 'Plated Tortoise (CrudeRaphie)' },
    { id = 39, name = 'SaberSiravarde', label = 'Sabertooth Tiger (SaberSiravarde)' },
}

local WHITELISTED_PET_IDS = {}
for idx, entry in ipairs(GUARDIAN_BEASTS) do
    WHITELISTED_PET_IDS[entry.id] = idx
end

-- 1H Axe Weaponskill IDs
local AXE_WS_IDS =
{
    [64] = true, [65] = true, [66] = true, [67] = true, [68] = true,
    [69] = true, [70] = true, [71] = true, [72] = true, [73] = true,
    [74] = true, [75] = true, [76] = true, [77] = true,
}

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.SOUL_BOND  = ABIL_SOUL_BOND
xi.jobAbility.FERAL_ROAR = ABIL_FERAL_ROAR

xi.effect = xi.effect or {}
xi.effect.ALPHA_PACK_INSTINCT = EFFECT_ALPHA_PACK_INSTINCT
xi.effect.ALPHA_RENDING_BITE  = EFFECT_ALPHA_RENDING_BITE
xi.effect.ALPHA_SOUL_BOND     = EFFECT_ALPHA_SOUL_BOND
xi.effect.ALPHA_FERAL_ROAR    = EFFECT_ALPHA_FERAL_ROAR
xi.effect.ALPHA_FAMILIAR_BOND = EFFECT_ALPHA_FAMILIAR_BOND
xi.effect.ALPHA_REWARD_BOND   = EFFECT_ALPHA_REWARD_BOND

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.soul_bond  = xi.actions.abilities.soul_bond or {}
xi.actions.abilities.feral_roar = xi.actions.abilities.feral_roar or {}

xi.effects = xi.effects or {}
xi.effects.alpha_pack_instinct = xi.effects.alpha_pack_instinct or {}
xi.effects.alpha_rending_bite  = xi.effects.alpha_rending_bite or {}
xi.effects.alpha_soul_bond     = xi.effects.alpha_soul_bond or {}
xi.effects.alpha_feral_roar    = xi.effects.alpha_feral_roar or {}
xi.effects.alpha_familiar_bond = xi.effects.alpha_familiar_bond or {}
xi.effects.alpha_reward_bond   = xi.effects.alpha_reward_bond or {}

local weaponModStateByChar = {}
local petModStateById      = {}
local lastAxeWsByChar      = {}

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

local function isAlphaWarden(entity)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.BST
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.BST, ALPHA_WARDEN_KEY)
end

local function isSingleAxeEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    local subId = player.getEquipID and player:getEquipID(xi.slot.SUB) or 0
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.AXE and subId == 0
end

local function isAxeWs(skill)
    if skill == nil then
        return false
    end
    if type(skill) == 'number' then
        return AXE_WS_IDS[skill] == true
    end
    if skill.getSkillType and skill:getSkillType() == xi.skill.AXE then
        return true
    end
    if skill.getID then
        return AXE_WS_IDS[skill:getID() or 0] == true
    end
    return false
end

local function getSelectedGuardianBeast(player)
    local idx = (player ~= nil and player.getLocalVar) and (player:getLocalVar('OX_BST_WARDEN_PET') or 1) or 1
    if idx < 1 or idx > #GUARDIAN_BEASTS then
        idx = 1
    end
    return GUARDIAN_BEASTS[idx], idx
end

local function applyCripple(target, origin, power, duration)
    if target == nil or not target.isAlive or not target:isAlive() then
        return
    end
    local pwr = power or 15
    slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, pwr, duration or 15, origin,
    {
        { xi.mod.ATTP, -pwr },
        { xi.mod.MATT, -pwr },
        { xi.mod.ACC,  -20 },
    }, xi.effect.ATTACK_DOWN)
end

local function applyBreach(target, origin, power, duration)
    if target == nil or not target.isAlive or not target:isAlive() then
        return
    end
    local pwr = power or 15
    slots.applySlot(target, slots.EFF_OX_DEB_BREACH, pwr, duration or 15, origin,
    {
        { xi.mod.DEFP, -pwr },
        { xi.mod.MDEF, -pwr },
    }, xi.effect.DEFENSE_DOWN)
end

local function applyExpose(target, origin, power, duration)
    if target == nil or not target.isAlive or not target:isAlive() then
        return
    end
    local pwr = power or 25
    slots.applySlot(target, slots.EFF_OX_DEB_EXPOSE, pwr, duration or 15, origin,
    {
        { xi.mod.EVA,  -pwr },
        { xi.mod.MEVA, -pwr },
    }, xi.effect.EVASION_DOWN)
end

local function applyStoneskin(target, amount, duration, origin)
    if target == nil or not target.isAlive or not target:isAlive() then
        return
    end
    local amt = math.max(1, math.floor(amount or 1))
    if target.delStatusEffectSilent then
        target:delStatusEffectSilent(xi.effect.STONESKIN)
    end
    if target.addStatusEffect then
        target:addStatusEffect(xi.effect.STONESKIN, { power = amt, duration = duration or 15, origin = origin or target, tier = 4 })
    end
end

local function funnelPetEnmityToMaster(master, pet, mob)
    if master == nil or pet == nil or mob == nil or not mob.isMob or not mob:isMob() then
        return
    end
    if not mob.getCE or not mob.getVE or not mob.setCE or not mob.setVE or not mob.addEnmity then
        return
    end
    local ce = mob:getCE(pet) or 0
    local ve = mob:getVE(pet) or 0
    if ce > 0 or ve > 0 then
        mob:setCE(pet, 0)
        mob:setVE(pet, 0)
        mob:addEnmity(master, ce, ve)
    end
end

local function mirrorHealToPet(master, actualHealed, rawEstimated)
    if not isAlphaWarden(master) or not master.getPet then
        return
    end
    if master.hasJugPet and not master:hasJugPet() then
        return
    end
    local pet = master:getPet()
    if pet == nil or not pet:isAlive() then
        return
    end
    local healed   = math.max(0, math.floor(actualHealed or 0))
    local overheal = math.max(0, math.floor((rawEstimated or healed) - healed))
    local petHeal  = math.floor(healed * 0.60) + overheal
    if petHeal > 0 and pet.addHP then
        pet:addHP(petHeal)
    end
end

-----------------------------------
-- Weapon & Pet Mod Sync
-----------------------------------
local function clearBstWeaponMods(player)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local prev   = weaponModStateByChar[charId]
    if prev ~= nil and player.delMod then
        for _, entry in ipairs(prev) do
            player:delMod(entry[1], entry[2])
        end
    end
    weaponModStateByChar[charId] = nil
end

local function syncBstWeaponMods(player)
    if player == nil or not player.getID then
        return
    end

    if not isAlphaWarden(player) then
        clearBstWeaponMods(player)
        return
    end

    local charId  = player:getID()
    local lvl     = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local hasAxe  = isSingleAxeEquipped(player)
    local desired = {}

    if hasAxe then
        local gpRate = scaleTier(lvl, 10, 14, 18, 22)
        table.insert(desired, { xi.mod.INQUARTATA, gpRate })
        table.insert(desired, { xi.mod.ADDITIVE_GUARD, gpRate })
    end

    local prev    = weaponModStateByChar[charId]
    local changed = (prev == nil) or (#prev ~= #desired)
    if not changed then
        for i = 1, #desired do
            if prev[i][1] ~= desired[i][1] or prev[i][2] ~= desired[i][2] then
                changed = true
                break
            end
        end
    end

    if not changed then
        return
    end

    clearBstWeaponMods(player)
    if #desired > 0 and player.addMod then
        for _, entry in ipairs(desired) do
            player:addMod(entry[1], entry[2])
        end
        weaponModStateByChar[charId] = desired
    end
end

local function clearAlphaWardenPetMods(pet)
    if pet == nil or not pet.getID then
        return
    end
    local petId = pet:getID()
    local prev  = petModStateById[petId]
    if prev ~= nil and pet.delMod then
        for _, entry in ipairs(prev) do
            pet:delMod(entry[1], entry[2])
        end
        if pet.updateHealth then
            pet:updateHealth()
        end
    end
    petModStateById[petId] = nil
end

local function onPetReadySkillExit(pet, _skillId, isCompleted)
    if not isCompleted or pet == nil then
        return
    end

    local master = pet.getMaster and pet:getMaster() or nil
    if master == nil or not isAlphaWarden(master) then
        return
    end

    if master.hasJugPet and not master:hasJugPet() then
        return
    end

    local mobTarget = (pet.getTarget and pet:getTarget()) or (master.getTarget and master:getTarget())
    if mobTarget ~= nil and mobTarget.isMob and mobTarget:isMob() then
        funnelPetEnmityToMaster(master, pet, mobTarget)
        if mobTarget.addEnmity then
            mobTarget:addEnmity(master, 200, 1400)
        end
    end

    if master.addTP then
        master:addTP(100)
    end
end

local function syncAlphaWardenPet(player, pet, justSpawned)
    if pet == nil or not pet.getID then
        return
    end

    if not isAlphaWarden(player) or (player.hasJugPet and not player:hasJugPet()) then
        clearAlphaWardenPetMods(pet)
        if pet.removeListener then
            pet:removeListener('OX_BST_ALPHA_READY')
        end
        return
    end

    -- Force 100% of player:getMainLvl() on spawn (0 level variance, uncapped to Lv.75)
    local lvl = player.getMainLvl and (player:getMainLvl() or 10) or 10
    if justSpawned and pet.setMobLevel then
        pet:setMobLevel(lvl, true)
    end

    local hpp     = scaleTier(lvl, 14, 18, 22, 26)
    local desired =
    {
        { xi.mod.HPP, hpp },
        { xi.mod.DMG, -3000 },
    }
    if xi.mod.PHYS_DMG_DEALT then
        table.insert(desired, { xi.mod.PHYS_DMG_DEALT, -60 })
    else
        if xi.mod.ATTP then
            table.insert(desired, { xi.mod.ATTP, -60 })
        end
        if xi.mod.ALL_WSDMG_ALL_HITS then
            table.insert(desired, { xi.mod.ALL_WSDMG_ALL_HITS, -60 })
        end
    end
    if xi.mod.RANGED_DMG_DEALT then
        table.insert(desired, { xi.mod.RANGED_DMG_DEALT, -60 })
    elseif xi.mod.RATTP then
        table.insert(desired, { xi.mod.RATTP, -60 })
    end
    if xi.mod.MAG_DMG_DEALT then
        table.insert(desired, { xi.mod.MAG_DMG_DEALT, -60 })
    elseif xi.mod.MATT then
        table.insert(desired, { xi.mod.MATT, -60 })
    end
    if xi.mod.DMGBREATH then
        table.insert(desired, { xi.mod.DMGBREATH, -10000 })
    end
    if xi.mod.UDMBREATH then
        table.insert(desired, { xi.mod.UDMBREATH, -10000 })
    end
    if xi.mod.DMGMAGIC then
        table.insert(desired, { xi.mod.DMGMAGIC, -10000 })
    end
    if xi.mod.UDMMAGIC then
        table.insert(desired, { xi.mod.UDMMAGIC, -10000 })
    end

    local petId   = pet:getID()
    local prev    = petModStateById[petId]
    local changed = (prev == nil) or (#prev ~= #desired)
    if not changed then
        for i = 1, #desired do
            if prev[i][1] ~= desired[i][1] or prev[i][2] ~= desired[i][2] then
                changed = true
                break
            end
        end
    end

    if changed then
        clearAlphaWardenPetMods(pet)
        for _, entry in ipairs(desired) do
            pet:addMod(entry[1], entry[2])
        end
        petModStateById[petId] = desired
        if pet.updateHealth then
            pet:updateHealth()
        end
        if justSpawned and pet.setHP and pet.getMaxHP then
            pet:setHP(pet:getMaxHP())
        end
    end

    if pet.removeListener and pet.addListener then
        pet:removeListener('OX_BST_ALPHA_READY')
        pet:addListener('WEAPONSKILL_STATE_EXIT', 'OX_BST_ALPHA_READY', onPetReadySkillExit)
    end
end

-----------------------------------
-- Player Listeners
-----------------------------------
local function detachBstListeners(player)
    if player == nil or not player.removeListener then
        return
    end
    player:removeListener('OX_BST_EQUIP')
    player:removeListener('OX_BST_TICK')
    player:removeListener('OX_BST_WS')
end

local function attachBstListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachBstListeners(player)

    player:addListener('ITEM_EQUIP', 'OX_BST_EQUIP', function(actor)
        syncBstWeaponMods(actor)
    end)

    player:addListener('TICK', 'OX_BST_TICK', function(actor)
        syncBstWeaponMods(actor)
        if not isAlphaWarden(actor) then
            return
        end

        local pet = actor.getPet and actor:getPet() or nil
        if pet ~= nil then
            syncAlphaWardenPet(actor, pet, false)
            if pet:isAlive() then
                -- Funnel 100% of Pet melee enmity onto Master
                local mobTarget = (pet.getTarget and pet:getTarget()) or (actor.getTarget and actor:getTarget())
                if mobTarget ~= nil then
                    funnelPetEnmityToMaster(actor, pet, mobTarget)
                end

                -- Mirror Regen ticks on Master to Pet (60%)
                local regenEff = actor.getStatusEffect and actor:getStatusEffect(xi.effect.REGEN) or nil
                if regenEff ~= nil and (regenEff:getPower() or 0) > 0 then
                    mirrorHealToPet(actor, regenEff:getPower(), regenEff:getPower())
                end
            end
        end
    end)

    -- 1H Axe WSs (primaryMsg-gated): heal Pet 15/18/21/25%, flat volatile enmity on Master, EFF_OX_DEB_CRIPPLE
    player:addListener('WEAPONSKILL_USE', 'OX_BST_WS', function(actor, target, skill)
        if not isAlphaWarden(actor) or not isSingleAxeEquipped(actor) or not isAxeWs(skill) then
            return
        end

        local charId = actor.getID and actor:getID() or 0
        local now    = xi.soulspire.nowSec()
        if charId > 0 and (now - (lastAxeWsByChar[charId] or 0)) <= 0.1 then
            return
        end
        if charId > 0 then
            lastAxeWsByChar[charId] = now
        end

        local lvl = actor.getMainLvl and (actor:getMainLvl() or 10) or 10
        local pet = actor.getPet and actor:getPet() or nil
        if pet ~= nil and pet:isAlive() and actor.hasJugPet and actor:hasJugPet() then
            local healPct = scaleTier(lvl, 15, 18, 21, 25)
            local healAmt = math.max(1, math.floor((pet:getMaxHP() or 0) * healPct / 100))
            pet:addHP(healAmt)
        end

        if target ~= nil and target.isAlive and target:isAlive() then
            if target.addEnmity then
                target:addEnmity(actor, 200, 1400)
            end
            applyCripple(target, actor, 15, 15)
        end
    end)
end

-----------------------------------
-- Guard with 1H Axe Override
-----------------------------------
if xi.combat and xi.combat.physical and xi.combat.physical.canGuard then
    m:addOverride('xi.combat.physical.canGuard', function(defender, attacker)
        if
            isAlphaWarden(defender) and
            isSingleAxeEquipped(defender) and
            defender.isFacing and defender:isFacing(attacker) and
            defender.isEngaged and defender:isEngaged()
        then
            return true
        end

        return super(defender, attacker)
    end)
end

-----------------------------------
-- Symbiotic Soul-Link (50% Split) & 100% Pet AoE/Conal Immunity
-----------------------------------
local prevOnPreTakeDamage = xi.soulspire.onPreTakeDamage

function xi.soulspire.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    local dmg = tonumber(amount) or 0
    if dmg <= 0 or defender == nil then
        return dmg
    end

    -- 100% Pet AoE / Conal Mob Damage Immunity (never double-hit alongside Soul-Link)
    if defender.isPet and defender:isPet() then
        local master = defender.getMaster and defender:getMaster() or nil
        if isAlphaWarden(master) and master.hasJugPet and master:hasJugPet() then
            if defender.getLocalVar and defender:getLocalVar('OX_BST_SOUL_LINK_HIT') == 1 then
                defender:setLocalVar('OX_BST_SOUL_LINK_HIT', 0)
                return dmg
            end
            if attacker ~= nil and attacker.isMob and attacker:isMob() then
                local mobTarget = attacker.getTarget and attacker:getTarget() or nil
                if
                    attackType == xi.attackType.BREATH or
                    attackType == xi.attackType.MAGICAL or
                    mobTarget ~= defender
                then
                    return 0
                end
            end
        end
        return dmg
    end

    if
        not isAlphaWarden(defender) or
        not defender.hasJugPet or
        not defender:hasJugPet()
    then
        return dmg
    end

    local isValidType =
        attackType == xi.attackType.PHYSICAL or
        attackType == xi.attackType.RANGED or
        attackType == xi.attackType.MAGICAL or
        attackType == xi.attackType.BREATH

    if not isValidType then
        return dmg
    end

    local pet = defender.getPet and defender:getPet() or nil
    if pet == nil or not pet:isAlive() or pet:getHPP() < 15 then
        return dmg
    end

    -- Always-on 50% Symbiotic Soul-Link damage split (mitigated by Pet's -30% DT)
    local redirectRaw = math.floor(dmg * 0.50)
    if redirectRaw <= 0 then
        return dmg
    end

    local petDmg = math.max(1, math.floor(redirectRaw * 0.70))
    if pet.setLocalVar then
        pet:setLocalVar('OX_BST_SOUL_LINK_HIT', 1)
    end
    pet:takeDamage(petDmg, attacker, attackType, damageType)
    if pet.setLocalVar then
        pet:setLocalVar('OX_BST_SOUL_LINK_HIT', 0)
    end

    return math.max(0, dmg - redirectRaw)
end

-----------------------------------
-- Cure & Waltz Mirroring (60% Healed + 100% Overheal)
-----------------------------------
local CURE_RAW_ESTIMATE =
{
    cure       = 65,
    cure_ii    = 145,
    cure_iii   = 300,
    cure_iv    = 550,
    cure_v     = 850,
    cure_vi    = 1200,
    curaga     = 90,
    curaga_ii  = 180,
    curaga_iii = 360,
    curaga_iv  = 650,
    curaga_v   = 950,
}

for spellName, rawBase in pairs(CURE_RAW_ESTIMATE) do
    m:addOverride(string.format('xi.actions.spells.white.%s.onSpellCast', spellName), function(caster, target, spell)
        if target ~= nil and isAlphaWarden(target) and target.getHP then
            local preHp  = target:getHP() or 0
            local maxHp  = target:getMaxHP() or 0
            local res    = super(caster, target, spell)
            local healed = math.max(0, (target:getHP() or 0) - preHp)
            local pot    = math.max(0, (caster and caster.getMod and caster:getMod(xi.mod.CURE_POTENCY) or 0))
            local est    = math.floor(rawBase * (1 + pot / 100))
            if (target:getHP() or 0) >= maxHp then
                mirrorHealToPet(target, healed, math.max(healed, est))
            else
                mirrorHealToPet(target, healed, healed)
            end
            return res
        end
        return super(caster, target, spell)
    end)
end

for _, waltzName in ipairs({ 'curing_waltz', 'curing_waltz_ii', 'curing_waltz_iii', 'curing_waltz_iv', 'curing_waltz_v', 'divine_waltz', 'divine_waltz_ii' }) do
    m:addOverride(string.format('xi.actions.abilities.%s.onUseAbility', waltzName), function(player, target, ability, action)
        if target ~= nil and isAlphaWarden(target) and target.getHP then
            local preHp  = target:getHP() or 0
            local res    = super(player, target, ability, action)
            local healed = math.max(0, (target:getHP() or 0) - preHp)
            local rawAmt = tonumber(res) or healed
            mirrorHealToPet(target, healed, math.max(healed, rawAmt))
            return res
        end
        return super(player, target, ability, action)
    end)
end

-----------------------------------
-- Pet Spawn & Ready 0.25x Damage Clamp
-----------------------------------
m:addOverride('xi.pet.spawnPet', function(caster, petID, state, target)
    super(caster, petID, state, target)

    if caster ~= nil and caster:isPC() then
        local pet = caster.getPet and caster:getPet() or nil
        if pet ~= nil then
            syncAlphaWardenPet(caster, pet, true)
        end
    end
end)

m:addOverride('xi.mobskills.processDamage', function(actor, target, skill, action, info)
    if
        actor ~= nil and
        actor.isPet and
        actor:isPet() and
        info ~= nil and
        (info.damage or 0) > 0
    then
        local master = actor.getMaster and actor:getMaster() or nil
        if isAlphaWarden(master) and master.hasJugPet and master:hasJugPet() then
            info.damage = math.max(1, math.floor(info.damage * 0.25))
        end
    end

    return super(actor, target, skill, action, info)
end)

-----------------------------------
-- Native BST Job Ability Overrides
-----------------------------------
m:addOverride('xi.job_utils.beastmaster.checkCallBeast', function(player, target, ability)
    if not isAlphaWarden(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(300)
        end
        return super(player, target, ability)
    end

    if ability ~= nil and ability.setRecast then
        ability:setRecast(15)
    end
    if player:getPet() ~= nil then
        return xi.msg.basic.ALREADY_HAS_A_PET, 0
    end
    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end

    local ammoEquip = player:getEquippedItem(xi.slot.AMMO)
    local ammoPetId = ammoEquip and player:getWeaponSubSkillType(xi.slot.AMMO) or 0
    if ammoEquip ~= nil and ammoPetId >= xi.petId.SHEEP_FAMILIAR and WHITELISTED_PET_IDS[ammoPetId] == nil then
        if player.printToPlayer then
            player:printToPlayer('Alpha Warden: Only Tank Guardian Beasts (Crab, Beetle, Tortoise, Tiger) may be summoned.', xi.msg.channel.SYSTEM_3)
        end
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.job_utils.beastmaster.useCallBeast', function(player, target, ability)
    if not isAlphaWarden(player) then
        return super(player, target, ability)
    end

    local ammoEquip = player:getEquippedItem(xi.slot.AMMO)
    local ammoPetId = ammoEquip and player:getWeaponSubSkillType(xi.slot.AMMO) or 0
    local petId     = nil
    if ammoEquip ~= nil and WHITELISTED_PET_IDS[ammoPetId] ~= nil then
        petId = ammoPetId
    else
        local chosen = getSelectedGuardianBeast(player)
        petId = chosen.id
    end

    xi.pet.spawnPet(player, petId)
    player:addRecast(xi.recast.ABILITY, 102, 1)
end)

m:addOverride('xi.job_utils.beastmaster.checkBestialLoyalty', function(player, target, ability)
    if not isAlphaWarden(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(1200)
        end
        return super(player, target, ability)
    end

    if ability ~= nil and ability.setRecast then
        ability:setRecast(5)
    end
    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end
    return 0, 0
end)

m:addOverride('xi.job_utils.beastmaster.useBestialLoyalty', function(player, target, ability)
    if not isAlphaWarden(player) then
        return super(player, target, ability)
    end

    local _, curIdx = getSelectedGuardianBeast(player)
    local nextIdx   = (curIdx % #GUARDIAN_BEASTS) + 1
    if player.setLocalVar then
        player:setLocalVar('OX_BST_WARDEN_PET', nextIdx)
    end
    local chosen = GUARDIAN_BEASTS[nextIdx]

    if player.printToPlayer then
        player:printToPlayer(string.format('Guardian Beast selected: %s [%d/%d]', chosen.label, nextIdx, #GUARDIAN_BEASTS), xi.msg.channel.SYSTEM_3)
    end

    local pet = player:getPet()
    if pet ~= nil then
        local petEngaged = pet.isEngaged and pet:isEngaged() or false
        local plrEngaged = player.isEngaged and player:isEngaged() or false
        if not petEngaged and not plrEngaged then
            if player.despawnPet then
                player:despawnPet()
            end
            xi.pet.spawnPet(player, chosen.id)
            player:addRecast(xi.recast.ABILITY, 102, 1)
        end
    end
end)

m:addOverride('xi.job_utils.beastmaster.checkReward', function(player, target, ability)
    if not isAlphaWarden(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
        return super(player, target, ability)
    end

    if ability ~= nil and ability.setRecast then
        ability:setRecast(25)
    end
    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end
    return 0, 0
end)

m:addOverride('xi.job_utils.beastmaster.useReward', function(player, target, ability, action)
    if not isAlphaWarden(player) then
        return super(player, target, ability, action)
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return 0
    end

    action:ID(player:getID(), pet:getID())

    local petHealAmt    = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.20))
    local masterHealAmt = math.max(1, math.floor((player:getMaxHP() or 0) * 0.20))
    local petDiff       = math.max(0, (pet:getMaxHP() or 0) - (pet:getHP() or 0))
    local petActual     = math.min(petDiff, petHealAmt)

    pet:addHP(petHealAmt)
    pet:wakeUp()
    player:addHP(masterHealAmt)

    for _ = 1, 2 do
        pet:eraseStatusEffect()
        player:eraseStatusEffect()
    end

    -- Hybrid Regen (18 flat + 2.5% Target Max HP/tick for 12s) on both Master & Pet
    local petRegen    = 18 + math.max(1, math.floor((pet:getMaxHP() or 0) * 0.025))
    local masterRegen = 18 + math.max(1, math.floor((player:getMaxHP() or 0) * 0.025))

    pet:delStatusEffectSilent(EFFECT_ALPHA_REWARD_BOND)
    pet:addStatusEffect(EFFECT_ALPHA_REWARD_BOND, { power = petRegen, duration = 12, origin = player, tick = 3, icon = xi.soulspire.getStatusIcon(EFFECT_ALPHA_REWARD_BOND) })

    player:delStatusEffectSilent(EFFECT_ALPHA_REWARD_BOND)
    player:addStatusEffect(EFFECT_ALPHA_REWARD_BOND, { power = masterRegen, duration = 12, origin = player, tick = 3, icon = xi.soulspire.getStatusIcon(EFFECT_ALPHA_REWARD_BOND) })

    return petActual
end)

m:addOverride('xi.job_utils.beastmaster.checkSnarl', function(player, target, ability)
    if ability ~= nil and ability.setRecast then
        ability:setRecast(isAlphaWarden(player) and 15 or 30)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.beastmaster.useSnarl', function(player, target, ability)
    super(player, target, ability)

    if not isAlphaWarden(player) then
        return
    end

    local pet       = player:getPet()
    local mobTarget = (pet and pet:getTarget()) or player:getTarget()
    if mobTarget ~= nil and mobTarget.isMob and mobTarget:isMob() and mobTarget.addEnmity then
        mobTarget:addEnmity(player, 250, 2400)
    end
end)

m:addOverride('xi.job_utils.beastmaster.useFamiliar', function(player, target, ability, action)
    local result = super(player, target, ability, action)

    if isAlphaWarden(player) then
        local pet = player:getPet()
        player:delStatusEffectSilent(EFFECT_ALPHA_FAMILIAR_BOND)
        player:addStatusEffect(EFFECT_ALPHA_FAMILIAR_BOND, { power = 25, duration = 30, origin = player, icon = xi.soulspire.getStatusIcon(EFFECT_ALPHA_FAMILIAR_BOND) })
        if player.updateHealth then
            player:updateHealth()
        end

        if pet ~= nil then
            pet:delStatusEffectSilent(EFFECT_ALPHA_FAMILIAR_BOND)
            pet:addStatusEffect(EFFECT_ALPHA_FAMILIAR_BOND, { power = 25, duration = 30, origin = player, icon = xi.soulspire.getStatusIcon(EFFECT_ALPHA_FAMILIAR_BOND) })
            if pet.updateHealth then
                pet:updateHealth()
            end
        end

        if player.restoreAbilityCharge then
            player:restoreAbilityCharge(102, 3)
        end
    end

    return result
end)

-----------------------------------
-- Tank-Reworked Vanilla Ready Skills (Crab, Beetle, Tortoise/Lizard, Tiger)
-----------------------------------
local function aoeThreat(master, anchor, ce, ve, perMobFn)
    if anchor == nil or not anchor.getNearbyEntities then
        return
    end
    local nearby = anchor:getNearbyEntities(8)
    if type(nearby) ~= 'table' then
        return
    end
    for _, ent in ipairs(nearby) do
        if ent ~= nil and ent.isMob and ent:isMob() and ent.isAlive and ent:isAlive() then
            if ent.addEnmity then
                ent:addEnmity(master, ce or 250, ve or 1600)
            end
            if perMobFn ~= nil then
                perMobFn(ent)
            end
        end
    end
end

local function applyBuffToMasterAndPet(master, pet, effId, power, duration, mods, iconId)
    slots.applySlot(master, effId, power, duration, master, mods, iconId)
    if pet ~= nil and pet:isAlive() then
        slots.applySlot(pet, effId, power, duration, master, mods, iconId)
    end
end

local READY_SKILL_REWORKS =
{
    -- Crab
    scissor_guard = function(target, pet, master)
        applyBuffToMasterAndPet(master, pet, slots.EFF_OX_SUP_WARD, 3000, 15,
        {
            { xi.mod.DEFP,    30 },
            { xi.mod.DMGPHYS, -1200 },
        }, xi.effect.DEFENSE_BOOST)
    end,
    bubble_curtain = function(target, pet, master)
        applyBuffToMasterAndPet(master, pet, slots.EFF_OX_SUP_WARD, 1500, 15,
        {
            { xi.mod.DMGMAGIC,  -1500 },
            { xi.mod.DMGBREATH, -1500 },
        }, xi.effect.SHELL)
        if master.eraseStatusEffect then
            master:eraseStatusEffect()
        end
        if pet.eraseStatusEffect then
            pet:eraseStatusEffect()
        end
    end,
    metallic_body = function(target, pet, master)
        applyStoneskin(master, (master:getMaxHP() or 0) * 0.20, 15, master)
        applyStoneskin(pet,    (pet:getMaxHP() or 0) * 0.20,    15, master)
    end,
    bubble_shower = function(target, pet, master)
        aoeThreat(master, pet, 300, 1800, function(mob)
            applyCripple(mob, master, 15, 15)
        end)
    end,
    big_scissors = function(target, pet, master)
        if target ~= nil and target.isMob and target:isMob() then
            if target.addEnmity then
                target:addEnmity(master, 400, 2400)
            end
            applyBreach(target, master, 15, 15)
        end
    end,

    -- Beetle
    rhino_guard = function(target, pet, master)
        applyBuffToMasterAndPet(master, pet, slots.EFF_OX_SUP_WARD, 1800, 15,
        {
            { xi.mod.INQUARTATA,     18 },
            { xi.mod.ADDITIVE_GUARD, 18 },
            { xi.mod.MEVA,           30 },
        }, xi.effect.COUNTERSTANCE)
    end,
    rhino_attack = function(target, pet, master)
        if target ~= nil and target.isMob and target:isMob() then
            if target.addEnmity then
                target:addEnmity(master, 350, 2200)
            end
            local dur = (target.isNM and target:isNM()) and 1 or 2
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = dur, origin = master })
        end
    end,
    power_attack = function(target, pet, master)
        if target ~= nil and target.isMob and target:isMob() then
            if target.addEnmity then
                target:addEnmity(master, 350, 2200)
            end
            local dur = (target.isNM and target:isNM()) and 1 or 2
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = dur, origin = master })
        end
    end,
    ['hi-freq_field'] = function(target, pet, master)
        aoeThreat(master, pet, 300, 1800, function(mob)
            mob:addStatusEffect(xi.effect.SLOW, { power = 2000, duration = 15, origin = master })
            applyExpose(mob, master, 25, 15)
        end)
    end,
    spoil = function(target, pet, master)
        if target ~= nil and target.isMob and target:isMob() then
            applyCripple(target, master, 20, 15)
        end
        if pet ~= nil and pet:isAlive() then
            pet:addHP(math.max(1, math.floor((pet:getMaxHP() or 0) * 0.15)))
        end
    end,

    -- Tortoise (and Lizard fallbacks)
    harden_shell = function(target, pet, master)
        applyBuffToMasterAndPet(master, pet, slots.EFF_OX_SUP_WARD, 1500, 12,
        {
            { xi.mod.DMG,                 -1500 },
            { xi.mod.KNOCKBACK_REDUCTION, 100 },
        }, xi.effect.DEFENSE_BOOST)
    end,
    tortoise_stomp = function(target, pet, master)
        if target ~= nil and target.isMob and target:isMob() then
            local dur = (target.isNM and target:isNM()) and 1 or 2
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = dur, origin = master })
            applyBreach(target, master, 15, 15)
        end
    end,
    aqua_breath = function(target, pet, master)
        aoeThreat(master, pet, 300, 1800, function(mob)
            mob:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 20, duration = 15, origin = master })
        end)
    end,

    -- Tiger
    roar = function(target, pet, master)
        aoeThreat(master, pet, 300, 1800, function(mob)
            mob:addStatusEffect(xi.effect.PARALYSIS, { power = 20, duration = 15, origin = master })
            applyCripple(mob, master, 15, 15)
        end)
    end,
    claw_cyclone = function(target, pet, master)
        aoeThreat(master, pet, 350, 2000)
        if master.addTP then
            master:addTP(150)
        end
    end,
    razor_fang = function(target, pet, master)
        if target ~= nil and target.isMob and target:isMob() then
            if target.addEnmity then
                target:addEnmity(master, 350, 2200)
            end
            applyBreach(target, master, 15, 15)
        end
        master:addHP(math.max(1, math.floor((master:getMaxHP() or 0) * 0.08)))
        if pet ~= nil and pet:isAlive() then
            pet:addHP(math.max(1, math.floor((pet:getMaxHP() or 0) * 0.08)))
        end
    end,
}

READY_SKILL_REWORKS.secretion   = READY_SKILL_REWORKS.harden_shell
READY_SKILL_REWORKS.brain_crush = READY_SKILL_REWORKS.tortoise_stomp
READY_SKILL_REWORKS.infrasonics = READY_SKILL_REWORKS.aqua_breath

for skillKey, reworkFn in pairs(READY_SKILL_REWORKS) do
    m:addOverride(string.format('xi.actions.abilities.pets.%s.onPetAbility', skillKey), function(target, pet, petskill, owner, action)
        local res    = super(target, pet, petskill, owner, action)
        local master = owner or (pet and pet.getMaster and pet:getMaster()) or nil
        if isAlphaWarden(master) then
            reworkFn(target, pet, master)
        end
        return res
    end)
end

-----------------------------------
-- Crystal-Unlocked Active Job Abilities (#441 & #442)
-----------------------------------
xi.actions.abilities.soul_bond.onAbilityCheck = function(player, target, ability)
    if not isAlphaWarden(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAlive() or (player.hasJugPet and not player:hasJugPet()) then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    return 0, 0
end

xi.actions.abilities.soul_bond.onUseAbility = function(player, target, ability)
    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return 0
    end

    -- Symbiotic Equalization: set both Master & Pet HP% to max(masterHpPct, petHpPct)
    local mMax = math.max(1, player:getMaxHP() or 1)
    local pMax = math.max(1, pet:getMaxHP() or 1)
    local mPct = (player:getHP() or 0) / mMax
    local pPct = (pet:getHP() or 0) / pMax
    local hi   = math.max(mPct, pPct)

    if math.abs(mPct - pPct) <= 0.10 then
        player:addHP(math.max(1, math.floor(mMax * 0.15)))
        pet:addHP(math.max(1, math.floor(pMax * 0.15)))
    else
        player:setHP(math.max(1, math.floor(mMax * hi)))
        pet:setHP(math.max(1, math.floor(pMax * hi)))
    end

    applyStoneskin(player, mMax * 0.15, 12, player)
    applyStoneskin(pet,    pMax * 0.15, 12, player)

    player:delStatusEffectSilent(EFFECT_ALPHA_SOUL_BOND)
    player:addStatusEffect(EFFECT_ALPHA_SOUL_BOND, { power = 1, duration = 12, origin = player, icon = xi.soulspire.getStatusIcon(EFFECT_ALPHA_SOUL_BOND) })

    return EFFECT_ALPHA_SOUL_BOND
end

xi.actions.abilities.feral_roar.onAbilityCheck = function(player, target, ability)
    if not isAlphaWarden(player) or not isSingleAxeEquipped(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    return 0, 0
end

xi.actions.abilities.feral_roar.onUseAbility = function(player, target, ability)
    aoeThreat(player, player, 400, 2600, function(mob)
        local dur = (mob.isNM and mob:isNM()) and 1 or 2
        mob:addStatusEffect(xi.effect.STUN, { power = 1, duration = dur, origin = player })
        mob:delStatusEffectSilent(EFFECT_ALPHA_FERAL_ROAR)
        mob:addStatusEffect(EFFECT_ALPHA_FERAL_ROAR, { power = 20, duration = 12, origin = player, icon = xi.soulspire.getStatusIcon(EFFECT_ALPHA_FERAL_ROAR) })
    end)

    if player.restoreAbilityCharge then
        player:restoreAbilityCharge(102, 1)
    end

    return EFFECT_ALPHA_FERAL_ROAR
end

-----------------------------------
-- Custom Status Effect Hooks
-----------------------------------
xi.effects.alpha_pack_instinct.onEffectGain = function(target, effect) end
xi.effects.alpha_pack_instinct.onEffectTick = function(target, effect) end
xi.effects.alpha_pack_instinct.onEffectLose = function(target, effect) end

xi.effects.alpha_rending_bite.onEffectGain = function(target, effect)
    local pwr = effect:getPower() or 15
    effect:addMod(xi.mod.ATTP, -pwr)
    effect:addMod(xi.mod.MATT, -pwr)
end
xi.effects.alpha_rending_bite.onEffectTick = function(target, effect) end
xi.effects.alpha_rending_bite.onEffectLose = function(target, effect) end

xi.effects.alpha_soul_bond.onEffectGain = function(target, effect) end
xi.effects.alpha_soul_bond.onEffectTick = function(target, effect) end
xi.effects.alpha_soul_bond.onEffectLose = function(target, effect) end

xi.effects.alpha_feral_roar.onEffectGain = function(target, effect)
    local pwr = effect:getPower() or 20
    effect:addMod(xi.mod.DELAYP, pwr)
end
xi.effects.alpha_feral_roar.onEffectTick = function(target, effect) end
xi.effects.alpha_feral_roar.onEffectLose = function(target, effect) end

xi.effects.alpha_familiar_bond.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.DMG, -2500)
    effect:addMod(xi.mod.HPP, 25)
end
xi.effects.alpha_familiar_bond.onEffectTick = function(target, effect) end
xi.effects.alpha_familiar_bond.onEffectLose = function(target, effect)
    if target.updateHealth then
        target:updateHealth()
    end
end

xi.effects.alpha_reward_bond.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.REGEN, effect:getPower() or 18)
end
xi.effects.alpha_reward_bond.onEffectTick = function(target, effect) end
xi.effects.alpha_reward_bond.onEffectLose = function(target, effect) end

-----------------------------------
-- Job Crystal Registration
-----------------------------------
if xi.job and xi.job.BST then
    spec.registerJob(xi.job.BST, 'BST',
    {
        {
            id          = 1,
            key         = ALPHA_WARDEN_KEY,
            name        = 'Alpha Warden',
            abr         = 'ALW',
            role        = 'Tank',
            icon        = 'alphawarden',
            reqLevel    = 10,
            extraTraits = { TRAIT_ALPHA_SOUL_LINK },
            extraAbilities = function(_player, lvl)
                if (lvl or 1) >= 10 then
                    return
                    {
                        ABIL_FIGHT,
                        ABIL_HEEL,
                        ABIL_SIC,
                        ABIL_STAY,
                        ABIL_REWARD,
                        ABIL_CALL_BEAST,
                        ABIL_SNARL,
                        ABIL_READY,
                        ABIL_BESTIAL_LOYALTY,
                        ABIL_SOUL_BOND,
                        ABIL_FERAL_ROAR,
                    }
                end
                return {}
            end,
            description = 'Symbiotic 1H Axe & Guardian Beast tank (Lv10+): always-on 50% Soul-Link damage split, 4 whitelisted Tank Guardian Beasts (Crab, Beetle, Tortoise, Tiger) @ 100% Master level with 0 jug/biscuit cost, Cure/Overheal mirroring, and tank-reworked Ready skills.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+): +14/18/22/26% Max HP (Master & Pet), +8/14/20/26 VIT/CHR, +14/20/26/32% DEF, -12/15/18/22% Master DT (-30% Pet DT + 100% AoE/Conal immunity), +60/80/100/120 Enmity & +25-60% Retention, +15-50 Axe, +10-22% Guard/Parry, 15s Ready CD.',
                'Tank Beast Roster (0 Jugs): Bestial Loyalty (5s CD) cycles Crab / Beetle / Tortoise / Tiger; Call Beast (15s CD, usable in combat) summons @ 100% Master level; Zero-Biscuit Reward (25s CD) heals both 20% + 2 cleanse + 12s Hybrid Regen.',
                'Always-On 50% Soul-Link & Cure Mirroring: splits 50% Master damage to Pet (pauses <15% HP), funnels 100% Pet melee & Ready enmity to Master, mirrors 60% Cure/Waltz/Regen + 100% overheal to Pet; 1H Axe WSs heal Pet 15-25% + Cripple.',
                'Tank-Reworked Ready Skills: grant Master +100 TP, heavy enmity, and spec utility (Crab DEF/MDT/Stoneskin/Cripple/Breach; Beetle Guard/Stun/Slow+Expose/Spoil; Tortoise DT+KB-Immune/Stun+Breach/AccDown; Tiger Para+Cripple/PackTP/Heal).',
                'Soul Bond (35s CD): equalizes Master & Pet HP% (min +15% if within 10%) + 15% Stoneskin; Feral Roar (25s CD): 8y AoE Stun + Slow + threat +1 Ready charge; Familiar: -25% DT, +25% HP & full Ready charges (30s).',
            },
            mods = function(player, lvl)
                local gpRate = scaleTier(lvl, 10, 14, 18, 22)
                local out =
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 14, 18, 22, 26) },
                    { xi.mod.VIT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.CHR,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 14, 20, 26, 32) },
                    { xi.mod.DMG,                   scaleTier(lvl, -1200, -1500, -1800, -2200) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 60, 80, 100, 120) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.AXE,                   scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.SIC_READY_RECAST,      15 },
                }
                if xi.mod.PHYS_DMG_DEALT then
                    table.insert(out, { xi.mod.PHYS_DMG_DEALT, -60 })
                elseif xi.mod.ATTP then
                    table.insert(out, { xi.mod.ATTP, -60 })
                end
                if xi.mod.RANGED_DMG_DEALT then
                    table.insert(out, { xi.mod.RANGED_DMG_DEALT, -60 })
                elseif xi.mod.RATTP then
                    table.insert(out, { xi.mod.RATTP, -60 })
                end
                if xi.mod.MAG_DMG_DEALT then
                    table.insert(out, { xi.mod.MAG_DMG_DEALT, -60 })
                elseif xi.mod.MATT then
                    table.insert(out, { xi.mod.MATT, -60 })
                end

                local isWiki = (player == nil) or (not player.getEquipID)
                if isWiki then
                    table.insert(out, { xi.mod.INQUARTATA, gpRate })
                    table.insert(out, { xi.mod.ADDITIVE_GUARD, gpRate })
                end

                return out
            end,
            onApply = function(player)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_BST_SOULLINK', 1)
                end
                attachBstListeners(player)
                syncBstWeaponMods(player)

                local pet = player ~= nil and player.getPet and player:getPet() or nil
                if pet ~= nil then
                    syncAlphaWardenPet(player, pet, false)
                elseif
                    player ~= nil and
                    player.isPC and player:isPC() and
                    (not player.isEngaged or not player:isEngaged()) and
                    player.canUseMisc and player:canUseMisc(xi.zoneMisc.PET)
                then
                    local chosen = getSelectedGuardianBeast(player)
                    xi.pet.spawnPet(player, chosen.id)
                    player:addRecast(xi.recast.ABILITY, 102, 1)
                end
            end,
            onRemove = function(player)
                if player ~= nil then
                    if player.setLocalVar then
                        player:setLocalVar('OX_BST_SOULLINK', 0)
                    end
                    player:delStatusEffectSilent(EFFECT_ALPHA_PACK_INSTINCT)
                    player:delStatusEffectSilent(EFFECT_ALPHA_SOUL_BOND)
                    player:delStatusEffectSilent(EFFECT_ALPHA_FAMILIAR_BOND)
                    player:delStatusEffectSilent(EFFECT_ALPHA_REWARD_BOND)
                    local pet = player.getPet and player:getPet() or nil
                    if pet ~= nil then
                        clearAlphaWardenPetMods(pet)
                        if pet.removeListener then
                            pet:removeListener('OX_BST_ALPHA_READY')
                        end
                    end
                end
                clearBstWeaponMods(player)
                detachBstListeners(player)
            end,
        },
    })
end

return m
