-----------------------------------
-- OverlordsXI Beastmaster Crystal Spec
-- Registers the Beastmaster (job 9) Soul Crystal specialization:
--   1. Alpha Warden (AWD) : Symbiotic Soul-Link & Pack-Mitigation Tank (1H Axe + Jug Pet)
--
-- Weapon choice remains open (no forced unequipping), while Guard/Parry bonuses,
-- Axe WS sustain, and Feral Roar dynamically require a 1H Axe.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/beastmaster')
require('scripts/globals/pets')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_bst_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.bstSpecs = xi.overlords.bstSpecs or {}
local bstSpecs        = xi.overlords.bstSpecs

local ALPHA_WARDEN_KEY = 'alphawarden'

-- Custom Trait ID (166: Alpha's Soul-Link)
local TRAIT_ALPHA_SOUL_LINK = 166

-- Custom Ability IDs (441-442; recastIds 216-217)
local ABIL_SOUL_BOND  = 441
local ABIL_FERAL_ROAR = 442

-- Custom Status Effect IDs (847-852; registered in patch 0025)
local EFFECT_ALPHA_PACK_INSTINCT = 847
local EFFECT_ALPHA_RENDING_BITE  = 848
local EFFECT_ALPHA_SOUL_BOND     = 849
local EFFECT_ALPHA_FERAL_ROAR    = 850
local EFFECT_ALPHA_FAMILIAR_BOND = 851
local EFFECT_ALPHA_REWARD_BOND   = 852

-- 1H Axe Weaponskill IDs (Raging Axe through Onslaught/Primal Rend/Cloudsplitter/etc.)
local AXE_WS_IDS =
{
    [64] = true, -- Raging Axe
    [65] = true, -- Smash Axe
    [66] = true, -- Gale Axe
    [67] = true, -- Avalanche Axe
    [68] = true, -- Spinning Axe
    [69] = true, -- Rampage
    [70] = true, -- Calamity
    [71] = true, -- Mistral Axe
    [72] = true, -- Decimation
    [73] = true, -- Onslaught
    [74] = true, -- Primal Rend
    [75] = true, -- Bora Axe
    [76] = true, -- Cloudsplitter
    [77] = true, -- Ruinator
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

local function isAxeEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.AXE
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
        local wsId = skill:getID() or 0
        return AXE_WS_IDS[wsId] == true
    end

    return false
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

    local charId     = player:getID()
    local lvl        = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local hasAxe     = isAxeEquipped(player)
    local desired    = {}

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

    -- Heavy volatile enmity on the pet's target (or master's target)
    local mobTarget = (pet.getTarget and pet:getTarget()) or (master.getTarget and master:getTarget())
    if mobTarget ~= nil and mobTarget.isMob and mobTarget:isMob() and mobTarget.addEnmity then
        mobTarget:addEnmity(master, 150, 1200)
    end

    -- +100 TP to Master
    if master.addTP then
        master:addTP(100)
    end

    -- 10s Pack Instinct (-10% DT & +15% Cure/Reward Potency Received)
    if master.addStatusEffect then
        master:addStatusEffect(EFFECT_ALPHA_PACK_INSTINCT, { power = 1, duration = 10, origin = master })
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

    local lvl     = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local hpp     = scaleTier(lvl, 12, 16, 20, 25)
    local petDt   = scaleTier(lvl, -1500, -2000, -2500, -3000)
    local desired =
    {
        { xi.mod.HPP, hpp },
        { xi.mod.DMG, petDt },
    }

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
        local pet = actor.getPet and actor:getPet() or nil
        if pet ~= nil then
            syncAlphaWardenPet(actor, pet, false)
        end
    end)

    -- Primal Pack Loop: Executing a 1H Axe WS heals Jug Pet, restores +350 Pet TP,
    -- and inflicts Rending Bite (-15% Attack & -15% Magic Attack for 15s).
    player:addListener('WEAPONSKILL_USE', 'OX_BST_WS', function(actor, target, skill)
        if not isAlphaWarden(actor) or not isAxeEquipped(actor) or not isAxeWs(skill) then
            return
        end

        local lvl = actor.getMainLvl and (actor:getMainLvl() or 10) or 10
        local pet = actor.getPet and actor:getPet() or nil
        if pet ~= nil and pet:isAlive() and actor.hasJugPet and actor:hasJugPet() then
            local healPct = scaleTier(lvl, 12, 15, 18, 22)
            local maxHp   = pet:getMaxHP() or 0
            local healAmt = math.max(1, math.floor(maxHp * healPct / 100))
            pet:addHP(healAmt)
            pet:addTP(350)
        end

        if target ~= nil and target.isAlive and target:isAlive() and target.addStatusEffect then
            target:addStatusEffect(EFFECT_ALPHA_RENDING_BITE, { power = 15, duration = 15, origin = actor })
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
            isAxeEquipped(defender) and
            defender.isFacing and defender:isFacing(attacker) and
            defender.isEngaged and defender:isEngaged()
        then
            return true
        end

        return super(defender, attacker)
    end)
end

-----------------------------------
-- Symbiotic Soul-Link Damage Split
-----------------------------------
local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage

function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    local dmg = tonumber(amount) or 0
    if
        dmg <= 0 or
        defender == nil or
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
    if pet == nil or not pet:isAlive() or pet:getHPP() < 20 then
        return dmg
    end

    local lvl         = defender.getMainLvl and (defender:getMainLvl() or 10) or 10
    local transferPct = (defender.hasStatusEffect and defender:hasStatusEffect(EFFECT_ALPHA_SOUL_BOND))
        and 60
        or scaleTier(lvl, 30, 35, 40, 45)

    local redirectRaw = math.floor(dmg * transferPct / 100)
    if redirectRaw <= 0 then
        return dmg
    end

    -- Reduced by 30% before hitting the Pet
    local petDmg = math.max(1, math.floor(redirectRaw * 0.70))
    pet:takeDamage(petDmg, attacker, attackType, damageType)

    return math.max(0, dmg - redirectRaw)
end

-----------------------------------
-- Pet Spawn Override
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

-----------------------------------
-- Native BST Job Ability Overrides
-----------------------------------
m:addOverride('xi.job_utils.beastmaster.checkCallBeast', function(player, target, ability)
    if ability ~= nil and ability.setRecast then
        ability:setRecast(isAlphaWarden(player) and 45 or 300)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.beastmaster.useCallBeast', function(player, target, ability)
    if not isAlphaWarden(player) then
        return super(player, target, ability)
    end

    -- Zero jug item consumption for Alpha Warden
    local ammoEquip = player:getEquippedItem(xi.slot.AMMO)
    local petId     = player:getWeaponSubSkillType(xi.slot.AMMO)
    if not ammoEquip or not petId or petId < xi.petId.SHEEP_FAMILIAR then
        return
    end

    xi.pet.spawnPet(player, petId)
    player:addRecast(xi.recast.ABILITY, 102, 1)
end)

m:addOverride('xi.job_utils.beastmaster.checkBestialLoyalty', function(player, target, ability)
    if ability ~= nil and ability.setRecast then
        ability:setRecast(isAlphaWarden(player) and 45 or 1200)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.beastmaster.checkReward', function(player, target, ability)
    if ability ~= nil and ability.setRecast then
        ability:setRecast(isAlphaWarden(player) and 25 or 90)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.beastmaster.useReward', function(player, target, ability, action)
    if not isAlphaWarden(player) then
        return super(player, target, ability, action)
    end

    local rangeObj         = xi.equipment.getUsableEquipID(player, xi.slot.AMMO)
    local playerMnd        = player:getStat(xi.mod.MND)
    local rewardHealingMod = player:getMod(xi.mod.REWARD_HP_BONUS)
    local regenAmount      = 1
    local baseHealing      = 0
    local pet              = player:getPet()

    action:ID(player:getID(), pet:getID())

    local foodData = xi.job_utils.beastmaster.petFoodData[rangeObj]
    if foodData then
        regenAmount = foodData.regen
        baseHealing = math.floor(foodData.minHealing + foodData.mndMult * (playerMnd - foodData.mndThreshold))
    end

    if rewardHealingMod ~= nil and rewardHealingMod > 0 then
        baseHealing = baseHealing + math.floor(baseHealing * rewardHealingMod / 100)
    end

    baseHealing = math.max(1, baseHealing)

    -- Heal Pet
    local petDiff = math.max(0, pet:getMaxHP() - pet:getHP())
    local petHeal = math.min(petDiff, baseHealing)
    pet:addHP(petHeal)
    pet:wakeUp()

    -- Heal Master for equal amount (+15% if Pack Instinct is active)
    local masterHeal = baseHealing
    if player:hasStatusEffect(EFFECT_ALPHA_PACK_INSTINCT) then
        masterHeal = math.floor(masterHeal * 1.15)
    end
    player:addHP(masterHeal)

    -- Remove up to 2 debuffs from both Master and Pet
    for _ = 1, 2 do
        pet:eraseStatusEffect()
        player:eraseStatusEffect()
    end

    -- 10s Regen + -10% DT bond on both Master and Pet
    local flatBond = math.max(15, regenAmount)
    local petBondRegen = flatBond
    local masterBondRegen = flatBond
    if xi.overlords and xi.overlords.regen and xi.overlords.regen.computeHybridTick then
        petBondRegen = xi.overlords.regen.computeHybridTick(player, pet, flatBond, 220)
        masterBondRegen = xi.overlords.regen.computeHybridTick(player, player, flatBond, 220)
    end
    pet:delStatusEffectSilent(EFFECT_ALPHA_REWARD_BOND)
    pet:addStatusEffect(EFFECT_ALPHA_REWARD_BOND, { power = petBondRegen, duration = 10, origin = player, tick = 3 })

    player:delStatusEffectSilent(EFFECT_ALPHA_REWARD_BOND)
    player:addStatusEffect(EFFECT_ALPHA_REWARD_BOND, { power = masterBondRegen, duration = 10, origin = player, tick = 3 })

    player:removeAmmo(1)

    return petHeal
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
        player:addStatusEffect(EFFECT_ALPHA_FAMILIAR_BOND, { power = 25, duration = 30, origin = player })
        if player.updateHealth then
            player:updateHealth()
        end

        if pet ~= nil then
            pet:delStatusEffectSilent(EFFECT_ALPHA_FAMILIAR_BOND)
            pet:addStatusEffect(EFFECT_ALPHA_FAMILIAR_BOND, { power = 25, duration = 30, origin = player })
            if pet.updateHealth then
                pet:updateHealth()
            end
        end
    end

    return result
end)

-----------------------------------
-- Crystal-Unlocked Active Job Abilities
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

    player:delStatusEffectSilent(EFFECT_ALPHA_SOUL_BOND)
    player:addStatusEffect(EFFECT_ALPHA_SOUL_BOND, { power = 1, duration = 10, origin = player })

    if pet ~= nil and pet:isAlive() then
        pet:delStatusEffectSilent(EFFECT_ALPHA_SOUL_BOND)
        pet:addStatusEffect(EFFECT_ALPHA_SOUL_BOND, { power = 1, duration = 10, origin = player })
    end

    local mobTarget = (player.getTarget and player:getTarget()) or (pet and pet:getTarget())
    if mobTarget ~= nil and mobTarget.isMob and mobTarget:isMob() then
        if pet ~= nil and player.transferEnmity then
            player:transferEnmity(pet, 100, 15.0)
        end
        if mobTarget.addEnmity then
            mobTarget:addEnmity(player, 1200, 3600)
        end
    end

    return EFFECT_ALPHA_SOUL_BOND
end

xi.actions.abilities.feral_roar.onAbilityCheck = function(player, target, ability)
    if not isAlphaWarden(player) or not isAxeEquipped(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    return 0, 0
end

xi.actions.abilities.feral_roar.onUseAbility = function(player, target, ability)
    if target ~= nil and target:isAlive() then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 4, origin = player })
        target:delStatusEffectSilent(EFFECT_ALPHA_FERAL_ROAR)
        target:addStatusEffect(EFFECT_ALPHA_FERAL_ROAR, { power = 20, duration = 12, origin = player })

        if target.addEnmity then
            target:addEnmity(player, 300, 2200)
        end
    end

    if player.restoreAbilityCharge then
        player:restoreAbilityCharge(102, 1)
    end

    return EFFECT_ALPHA_FERAL_ROAR
end

-----------------------------------
-- Custom Status Effect Hooks
-----------------------------------
xi.effects.alpha_pack_instinct.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.DMG, -1000)
    effect:addMod(xi.mod.CURE_POTENCY_RCVD, 15)
end
xi.effects.alpha_pack_instinct.onEffectTick = function(target, effect) end
xi.effects.alpha_pack_instinct.onEffectLose = function(target, effect) end

xi.effects.alpha_rending_bite.onEffectGain = function(target, effect)
    local pwr = effect:getPower() or 15
    effect:addMod(xi.mod.ATTP, -pwr)
    effect:addMod(xi.mod.MATT, -pwr)
end
xi.effects.alpha_rending_bite.onEffectTick = function(target, effect) end
xi.effects.alpha_rending_bite.onEffectLose = function(target, effect) end

xi.effects.alpha_soul_bond.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.DMG, -1500)
end
xi.effects.alpha_soul_bond.onEffectTick = function(target, effect) end
xi.effects.alpha_soul_bond.onEffectLose = function(target, effect) end

xi.effects.alpha_feral_roar.onEffectGain = function(target, effect)
    local pwr = effect:getPower() or 20
    effect:addMod(xi.mod.ACC, -pwr)
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
    effect:addMod(xi.mod.DMG, -1000)
    effect:addMod(xi.mod.REGEN, effect:getPower() or 10)
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
            id             = 1,
            key            = ALPHA_WARDEN_KEY,
            name           = 'Alpha Warden',
            role           = 'Symbiotic Soul-Link & Pack-Mitigation Tank',
            icon           = 'alphawarden',
            reqLevel       = 10,
            extraTraits    = { TRAIT_ALPHA_SOUL_LINK },
            extraAbilities = { ABIL_SOUL_BOND, ABIL_FERAL_ROAR },
            description    = 'Pack-alpha frontliner (Lv10+): requires a 1H Axe + active Jug Pet to unlock Symbiotic Soul-Link (splitting incoming damage with your pet and funneling 100% of pet enmity onto you), Pack Reward dual-healing, and defensive Ready synergies.',
            highlights     =
            {
                'Passives (Lv10/30/50/70+): +12-25% Max HP (Master & Pet), +8-26 VIT/CHR, +12-30% DEF, -8-18% DT (-15-30% Pet DT), +25-60 Enmity & Enmity Retention.',
                'Pack Alpha & Axe Mastery: +15-50 Axe skill, +10-22% Guard/Parry rate with 1H Axe, -35% Sic/Ready charge timer, 45s free Call Beast / Bestial Loyalty.',
                'Symbiotic Soul-Link: redirects 30-45% of damage to Jug Pet (reduced by 30%, suspends <20% Pet HP) & funnels 100% of Pet enmity to Master.',
                'Primal Pack Loop: Ready skills grant volatile enmity, +100 TP, and Pack Instinct (-10% DT & +15% Cure/Reward received); 1H Axe WS heals Pet (12-22%), +350 Pet TP, and inflicts Rending Bite.',
                'Soul Bond (25s CD): 60% Soul-Link transfer, -15% DT to Master & Pet, and exclusive enmity focus; Feral Roar (20s CD): Stun, -20 Acc, +20% Slow, +1 Ready charge.',
            },
            mods = function(player, lvl)
                local gpRate = scaleTier(lvl, 10, 14, 18, 22)
                local out =
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.VIT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.CHR,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.DMG,                   scaleTier(lvl, -800, -1100, -1400, -1800) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.AXE,                   scaleTier(lvl, 15, 25, 35, 50) },
                }

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
