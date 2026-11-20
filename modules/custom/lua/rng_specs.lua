-----------------------------------
-- SoulspireXI Ranger Crystal Specs
-- Registers the Huntsman (Modal Pet-Tank & Saurian Pack Ranger) RNG soul crystal:
--   - Lv.10 QoL: Auto-provisions Light Crossbow + Bolts if Ranged/Ammo empty,
--     100% Ammo Recycle, and zero ranged distance penalty.
--   - 3 Custom Traits: Warden's Ration (181), Primeval Pack (182), Apex Bond (183).
--   - Glacial Tusker Mode (Wild Raaz Lv.10+ / Cehuetzi Lv.75):
--     Tier 6 -60% DMG Dealt (0.12x WS, 0.25x Pet Mobskill), +40..70% Pet HP,
--     -30% Pet DT, 100% Pet AoE/Conal Boss Immunity, +60..120 Pet Enmity,
--     100% Master->Pet Single-Target Enmity Transfer, 80% Cure (+100% Overheal) Forwarding.
--   - Volcanic Saurian Mode (Stalker Raptor Lv.10+ / Gabbrath Lv.75):
--     Tier 2 Hybrid -25% DMG Dealt (0.50x WS) + -25 Enmity, 15y Party Pack Aura
--     (+8/12/16/20 ACC/RACC & +8/10/12/15% ATK/RATK).
--   - 7 Custom JAs (480-486), 100% Single-Target Enemy only.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('modules/custom/lua/soulspire_shared_slots')
require('scripts/globals/pets')
require('scripts/globals/player')
require('scripts/combat/ranged_utilities')
require('scripts/combat/physical_utilities')
-----------------------------------
local m = Module:new('soulspire_rng_specs')

local spec  = xi.soulspire.spec
local slots = xi.soulspire.slots

local HUNTSMAN_KEY = 'huntsman'

-- Custom Job Abilities (480-486)
local ABIL_CALL_WILD_RAAZ      = 480
local ABIL_CALL_STALKER_RAPTOR = 481
local ABIL_RIMETUSK_GORE       = 482
local ABIL_SAURIAN_REND        = 483
local ABIL_PRIMEVAL_TAKEDOWN   = 484
local ABIL_CALL_CEHUETZI       = 485
local ABIL_CALL_GABBRATH       = 486

-- Custom Pet IDs (134-137) + pre-rebuild fallback jug pet IDs (90, 54, 91, 104)
local PET_WILD_RAAZ      = 134
local PET_STALKER_RAPTOR = 135
local PET_CEHUETZI       = 136
local PET_GABBRATH       = 137

local FALLBACK_PET_CONFIG =
{
    [PET_WILD_RAAZ]      = { fallbackId = 90,  key = 1, name = 'Wild Raaz',      modelId = 2600 },
    [PET_STALKER_RAPTOR] = { fallbackId = 54,  key = 2, name = 'Stalker Raptor', modelId = 316  },
    [PET_CEHUETZI]       = { fallbackId = 91,  key = 3, name = 'Cehuetzi',       modelId = 2601 },
    [PET_GABBRATH]       = { fallbackId = 104, key = 4, name = 'Gabbrath',       modelId = 317  },
}

-- Custom Trait IDs (181-183)
local TRAIT_WARDENS_RATION = 181
local TRAIT_PRIMEVAL_PACK  = 182
local TRAIT_APEX_BOND      = 183

-- Starter Crossbow & Bolts for Lv.10 QoL auto-provisioning
local STARTER_XBOW_ID = 17216 -- Light Crossbow (Lv.1, RNG)
local STARTER_BOLT_ID = 17336 -- Crossbow Bolt (Lv.1, All)

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.CALL_WILD_RAAZ      = ABIL_CALL_WILD_RAAZ
xi.jobAbility.CALL_STALKER_RAPTOR = ABIL_CALL_STALKER_RAPTOR
xi.jobAbility.RIMETUSK_GORE       = ABIL_RIMETUSK_GORE
xi.jobAbility.SAURIAN_REND        = ABIL_SAURIAN_REND
xi.jobAbility.PRIMEVAL_TAKEDOWN   = ABIL_PRIMEVAL_TAKEDOWN
xi.jobAbility.CALL_CEHUETZI       = ABIL_CALL_CEHUETZI
xi.jobAbility.CALL_GABBRATH       = ABIL_CALL_GABBRATH

xi.petId = xi.petId or {}
xi.petId.WILD_RAAZ      = PET_WILD_RAAZ
xi.petId.STALKER_RAPTOR = PET_STALKER_RAPTOR
xi.petId.CEHUETZI       = PET_CEHUETZI
xi.petId.GABBRATH       = PET_GABBRATH

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
for _, abilName in ipairs({
    'call_wild_raaz', 'call_stalker_raptor', 'rimetusk_gore',
    'saurian_rend', 'primeval_takedown', 'call_cehuetzi', 'call_gabbrath',
}) do
    xi.actions.abilities[abilName] = xi.actions.abilities[abilName] or {}
end

local function tell(player, message)
    if player ~= nil and player.printToPlayer then
        player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
    end
end

local function scaleTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 then
        return lv70
    elseif l >= 50 then
        return lv50
    elseif l >= 30 then
        return lv30
    end
    return lv10
end

local function isHuntsman(player)
    if player == nil or not player:isPC() or player:getMainJob() ~= xi.job.RNG then
        return false
    end
    spec.ensureUpToDate(player)
    return spec.is(player, xi.job.RNG, HUNTSMAN_KEY)
end

-- Returns pet, logicalPetId (134..137) if active
local function getHuntsmanPet(player)
    if player == nil or not player.hasPet or not player:hasPet() then
        return nil, nil
    end
    local pet = player:getPet()
    if pet == nil then
        return nil, nil
    end
    local pid = pet.getPetID and pet:getPetID() or 0
    if pid >= PET_WILD_RAAZ and pid <= PET_GABBRATH then
        return pet, pid
    end
    local hKey = pet.getLocalVar and pet:getLocalVar('OX_HUNTSMAN_PET_KEY') or 0
    if hKey == 1 then
        return pet, PET_WILD_RAAZ
    elseif hKey == 2 then
        return pet, PET_STALKER_RAPTOR
    elseif hKey == 3 then
        return pet, PET_CEHUETZI
    elseif hKey == 4 then
        return pet, PET_GABBRATH
    end
    return nil, nil
end

local function isTuskerPet(player, petArg)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or (petArg ~= nil and pet ~= petArg) then
        return false, nil
    end
    if pet.isAlive and not pet:isAlive() then
        return false, nil
    end
    if pid == PET_WILD_RAAZ or pid == PET_CEHUETZI then
        return true, pid
    end
    return false, pid
end

local function isSaurianPet(player, petArg)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or (petArg ~= nil and pet ~= petArg) then
        return false, nil
    end
    if pet.isAlive and not pet:isAlive() then
        return false, nil
    end
    if pid == PET_STALKER_RAPTOR or pid == PET_GABBRATH then
        return true, pid
    end
    return false, pid
end

local function scaleLevelGapDmg(attacker, defender, dmg)
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        return xi.customBossServer.scaleDamageByLevelGap(attacker, defender, dmg)
    end
    return dmg
end

local function getPartyInRange(player, anchor, maxDist)
    local result = {}
    local seen   = {}
    local ref    = anchor or player
    if player == nil or ref == nil then
        return result
    end
    local party = player.getParty and player:getParty() or nil
    if type(party) == 'table' then
        for _, member in ipairs(party) do
            if
                member ~= nil and
                member:isAlive() and
                member:getZoneID() == player:getZoneID() and
                ref:checkDistance(member) <= maxDist
            then
                seen[member:getID()] = true
                table.insert(result, member)
            end
        end
    end
    if not seen[player:getID()] and player:isAlive() then
        table.insert(result, player)
    end
    return result
end

local function isRangedWs(actor, skill)
    if skill ~= nil and skill.getSkillType then
        local st = skill:getSkillType()
        return st == xi.skill.ARCHERY or st == xi.skill.MARKSMANSHIP
    end
    if actor ~= nil and actor.getWeaponSkillType then
        local st = actor:getWeaponSkillType(xi.slot.RANGED)
        return st == xi.skill.ARCHERY or st == xi.skill.MARKSMANSHIP
    end
    return false
end

local function provisionStarterRanged(player)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return
    end
    if player.getEquippedItem and player:getEquippedItem(xi.slot.RANGED) == nil then
        if player.hasItem and not player:hasItem(STARTER_XBOW_ID) and player.addItem then
            player:addItem(STARTER_XBOW_ID, 1)
        end
        if player.equipItem then
            player:equipItem(STARTER_XBOW_ID, xi.slot.RANGED)
        end
    end
    if player.getEquippedItem and player:getEquippedItem(xi.slot.AMMO) == nil then
        if player.hasItem and not player:hasItem(STARTER_BOLT_ID) and player.addItem then
            player:addItem(STARTER_BOLT_ID, 99)
        end
        if player.equipItem then
            player:equipItem(STARTER_BOLT_ID, xi.slot.AMMO)
        end
    end
end

-----------------------------------
-- Companion Mod Sync & Enmity Transfer / Cure Forwarding
-----------------------------------
local companionModsByChar = {}
local lastRangedWsByChar  = {}

local function clearCompanionMasterMods(player)
    if player == nil or not player.getID then
        return false
    end
    local charId = player:getID()
    local prev   = companionModsByChar[charId]
    if prev == nil then
        return false
    end
    if player.delMod then
        for _, entry in ipairs(prev) do
            player:delMod(entry[1], entry[2])
        end
    end
    companionModsByChar[charId] = nil
    return true
end

local function syncCompanionMasterMods(player)
    if not isHuntsman(player) then
        return clearCompanionMasterMods(player)
    end

    local pet = getHuntsmanPet(player)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return clearCompanionMasterMods(player)
    end

    local lvl   = player:getMainLvl()
    local stp   = scaleTier(lvl, 8, 12, 16, 22)
    local charId = player:getID()
    local prev   = companionModsByChar[charId]
    if prev ~= nil and prev[1] ~= nil and prev[1][2] == stp then
        return false
    end

    clearCompanionMasterMods(player)
    if player.addMod then
        player:addMod(xi.mod.STORETP, stp)
    end
    companionModsByChar[charId] = { { xi.mod.STORETP, stp } }
    return true
end

local function applyPetRoleMods(player, pet, pid)
    if player == nil or pet == nil or not xi or not xi.mod then
        return
    end
    if pet.getLocalVar and pet:getLocalVar('OX_HUNTSMAN_PET_INIT') == 1 then
        spec.syncPetRoleMods(player, pet)
        return
    end
    if pet.setLocalVar then
        pet:setLocalVar('OX_HUNTSMAN_PET_INIT', 1)
    end

    local lvl = player:getMainLvl()
    if pid == PET_WILD_RAAZ or pid == PET_CEHUETZI then
        -- Glacial Tusker Mode: +40/50/60/70% Pet Max HP, -30% Pet DT, +60/80/100/120 Pet Enmity
        local hpPct  = scaleTier(lvl, 40, 50, 60, 70)
        local enmity = scaleTier(lvl, 60, 80, 100, 120)
        pet:addMod(xi.mod.HPP, hpPct)
        pet:addMod(xi.mod.DMG, -3000)
        pet:addMod(xi.mod.ENMITY, enmity)
        pet:addMod(xi.mod.DEFP, 25)
        if pet.updateHealth then
            pet:updateHealth()
        end
        pet:addHP(pet:getMaxHP())
    elseif pid == PET_STALKER_RAPTOR or pid == PET_GABBRATH then
        -- Volcanic Saurian Mode: Agile predator passives (+ACC/+ATTP, -25 Enmity)
        pet:addMod(xi.mod.ACC, scaleTier(lvl, 12, 20, 28, 38))
        pet:addMod(xi.mod.ATTP, 15)
        pet:addMod(xi.mod.ENMITY, -25)
    end
    spec.syncPetRoleMods(player, pet)
end

local function transferSingleTargetEnmityToPet(master, target)
    if not isHuntsman(master) then
        return
    end
    local isTank = isTuskerPet(master)
    if not isTank then
        return
    end
    local pet = getHuntsmanPet(master)
    if pet == nil or target == nil or not target.isMob or not target:isMob() or not target:isAlive() then
        return
    end
    if not target.getCE or not target.getVE or not target.setCE or not target.setVE or not target.addEnmity then
        return
    end
    local ce = target:getCE(master) or 0
    local ve = target:getVE(master) or 0
    if ce > 0 or ve > 0 then
        target:setCE(master, 0)
        target:setVE(master, 0)
        target:addEnmity(pet, ce, ve)
    end
end

local function forwardCureToTusker(master, actualHealed, rawEstimated)
    if not isHuntsman(master) or not isTuskerPet(master) then
        return
    end
    local pet = getHuntsmanPet(master)
    if pet == nil or not pet:isAlive() then
        return
    end
    local healed   = math.max(0, math.floor(actualHealed or 0))
    local overheal = math.max(0, math.floor((rawEstimated or healed) - healed))
    local petHeal  = math.floor(healed * 0.80) + overheal
    if petHeal > 0 and pet.addHP then
        pet:addHP(petHeal)
    end
end

local function applyPackAura(player, pet)
    if player == nil or pet == nil then
        return
    end
    local lvl    = player:getMainLvl()
    local acc    = scaleTier(lvl, 8, 12, 16, 20)
    local atkPct = scaleTier(lvl, 8, 10, 12, 15)
    local members = getPartyInRange(player, pet, 15.0)
    for _, member in ipairs(members) do
        slots.applySlot(member, slots.EFF_OX_SUP_OFFENSE, atkPct, 6, player, function(eff)
            eff:addMod(xi.mod.ACC, acc)
            eff:addMod(xi.mod.RACC, acc)
            eff:addMod(xi.mod.ATTP, atkPct)
            eff:addMod(xi.mod.RATTP, atkPct)
        end, slots.EFF_OX_SUP_OFFENSE)
    end
end

-----------------------------------
-- Listeners (Warden's Ration, Enmity Transfer, Pack Aura, Pet Auto-Engage)
-----------------------------------
local function detachHuntsmanListeners(player)
    if player == nil or not player:isPC() then
        return
    end
    player:removeListener('OX_HUNTSMAN_WS')
    player:removeListener('OX_HUNTSMAN_ENMITY_ATK')
    player:removeListener('OX_HUNTSMAN_ENMITY_RNG')
    player:removeListener('OX_HUNTSMAN_TICK')
    if clearCompanionMasterMods(player) and player.pushStatus then
        player:pushStatus()
    end
end

local function attachHuntsmanListeners(player)
    if player == nil or not player:isPC() then
        return
    end

    -- Warden's Ration: Ranged WSs (primaryMsg-gated) heal active beast 15/18/20/22% Max HP & grant +250 Pet TP
    player:removeListener('OX_HUNTSMAN_WS')
    player:addListener('WEAPONSKILL_USE', 'OX_HUNTSMAN_WS', function(actor, target, skill)
        if not isHuntsman(actor) or not isRangedWs(actor, skill) then
            return
        end

        local charId = actor.getID and actor:getID() or 0
        local now    = os.clock()
        if charId > 0 and (now - (lastRangedWsByChar[charId] or 0)) <= 0.1 then
            return
        end
        if charId > 0 then
            lastRangedWsByChar[charId] = now
        end

        local pet = getHuntsmanPet(actor)
        if pet ~= nil and pet:isAlive() then
            local lvl     = actor:getMainLvl()
            local healPct = scaleTier(lvl, 0.15, 0.18, 0.20, 0.22)
            local healAmt = math.max(1, math.floor((pet:getMaxHP() or 0) * healPct))
            local healed  = pet:addHP(healAmt)
            pet:addTP(250)
            if healed > 0 and actor.messagePublic and xi.msg and xi.msg.basic and xi.msg.basic.RECOVERS_HP then
                actor:messagePublic(xi.msg.basic.RECOVERS_HP, pet, 0, healed)
            end
        end

        transferSingleTargetEnmityToPet(actor, target)
    end)

    player:removeListener('OX_HUNTSMAN_ENMITY_ATK')
    player:addListener('ATTACK', 'OX_HUNTSMAN_ENMITY_ATK', function(actor, target)
        transferSingleTargetEnmityToPet(actor, target)
    end)

    player:removeListener('OX_HUNTSMAN_ENMITY_RNG')
    player:addListener('RANGE_END', 'OX_HUNTSMAN_ENMITY_RNG', function(actor, target)
        transferSingleTargetEnmityToPet(actor, target)
    end)

    player:removeListener('OX_HUNTSMAN_TICK')
    player:addListener('TICK', 'OX_HUNTSMAN_TICK', function(actor)
        if not isHuntsman(actor) then
            detachHuntsmanListeners(actor)
            return
        end

        spec.refreshPlayer(actor, { skipSync = true })
        syncCompanionMasterMods(actor)

        local pet, pid = getHuntsmanPet(actor)
        if pet ~= nil and pet:isAlive() then
            if pid == PET_WILD_RAAZ or pid == PET_CEHUETZI then
                transferSingleTargetEnmityToPet(actor, actor:getTarget())
            elseif pid == PET_STALKER_RAPTOR or pid == PET_GABBRATH then
                applyPackAura(actor, pet)
            end

            if
                not pet:isEngaged() and
                not pet:hasStatusEffect(xi.effect.HEALING) and
                actor:isEngaged()
            then
                local masterTarget = actor:getTarget()
                if masterTarget ~= nil and masterTarget:isAlive() and actor:checkDistance(pet) <= 25 then
                    actor:petAttack(masterTarget)
                end
            end
        end
    end)
end

-----------------------------------
-- Ranged Distance Penalty Removal
-----------------------------------
if xi.combat and xi.combat.ranged then
    if xi.combat.ranged.attackDistancePenalty then
        m:addOverride('xi.combat.ranged.attackDistancePenalty', function(attacker, defender)
            if isHuntsman(attacker) then
                return 0
            end
            return super(attacker, defender)
        end)
    end
    if xi.combat.ranged.accuracyDistancePenalty then
        m:addOverride('xi.combat.ranged.accuracyDistancePenalty', function(attacker, defender)
            if isHuntsman(attacker) then
                return 0
            end
            return super(attacker, defender)
        end)
    end
end

-----------------------------------
-- Glacial Tusker: 100% Pet AoE/Conal Immunity, 0.25x Mobskill Clamp & 80% Cure Forwarding
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

    if defender.isPet and defender:isPet() then
        local master = defender.getMaster and defender:getMaster() or nil
        if isHuntsman(master) and isTuskerPet(master, defender) then
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
    end

    return dmg
end

if xi.mobskills and xi.mobskills.processDamage then
    m:addOverride('xi.mobskills.processDamage', function(actor, target, skill, action, info)
        if
            actor ~= nil and
            actor.isPet and
            actor:isPet() and
            info ~= nil and
            (info.damage or 0) > 0
        then
            local master = actor.getMaster and actor:getMaster() or nil
            if isHuntsman(master) and isTuskerPet(master, actor) then
                info.damage = math.max(1, math.floor(info.damage * 0.25))
            end
        end

        return super(actor, target, skill, action, info)
    end)
end

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
        if target ~= nil and isHuntsman(target) and isTuskerPet(target) and target.getHP then
            local preHp  = target:getHP() or 0
            local maxHp  = target:getMaxHP() or 0
            local res    = super(caster, target, spell)
            local healed = math.max(0, (target:getHP() or 0) - preHp)
            local pot    = math.max(0, (caster and caster.getMod and caster:getMod(xi.mod.CURE_POTENCY) or 0))
            local est    = math.floor(rawBase * (1 + pot / 100))
            if (target:getHP() or 0) >= maxHp then
                forwardCureToTusker(target, healed, math.max(healed, est))
            else
                forwardCureToTusker(target, healed, healed)
            end
            return res
        end
        return super(caster, target, spell)
    end)
end

-----------------------------------
-- Login / Level Sync
-----------------------------------
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        if isHuntsman(player) then
            provisionStarterRanged(player)
            attachHuntsmanListeners(player)
            syncCompanionMasterMods(player)
        else
            detachHuntsmanListeners(player)
        end
    end
end)

m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        if isHuntsman(player) then
            provisionStarterRanged(player)
            attachHuntsmanListeners(player)
            syncCompanionMasterMods(player)
        else
            detachHuntsmanListeners(player)
        end
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        if isHuntsman(player) then
            attachHuntsmanListeners(player)
            syncCompanionMasterMods(player)
        else
            detachHuntsmanListeners(player)
        end
    end
end)

-----------------------------------
-- Ability Binding Helpers & Summon Logic
-----------------------------------
local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

local function checkSummon(player, minLevel, label)
    if not isHuntsman(player) then
        tell(player, label .. ' is only available to RNG Huntsman spec (Lv.10+).')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if player:getMainLvl() < minLevel then
        tell(player, string.format('%s requires RNG Lv.%d+.', label, minLevel))
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end
    return 0, 0
end

local function doSummon(player, petId, label)
    -- 1 Active Pet Max: despawn existing companion before summoning
    if player.hasPet and player:hasPet() and player.despawnPet then
        player:despawnPet()
    end

    xi.pet.spawnPet(player, petId)
    if not player:hasPet() then
        local fb = FALLBACK_PET_CONFIG[petId]
        if fb ~= nil then
            xi.pet.spawnPet(player, fb.fallbackId)
            if player:hasPet() then
                local pet = player:getPet()
                if pet ~= nil then
                    if pet.setLocalVar then
                        pet:setLocalVar('OX_HUNTSMAN_PET_KEY', fb.key)
                    end
                    if pet.setMobLevel then
                        pet:setMobLevel(player:getMainLvl(), true)
                    end
                    if pet.setModelId then
                        pet:setModelId(fb.modelId)
                    end
                    if pet.renameEntity then
                        pet:renameEntity(fb.name)
                    end
                end
            end
        end
    end

    spec.refreshPlayer(player, { skipSync = true, forceMods = true })
    syncCompanionMasterMods(player)

    if player:hasPet() then
        local pet = player:getPet()
        applyPetRoleMods(player, pet, petId)
        if player.recalculateAbilitiesTable then
            player:recalculateAbilitiesTable()
        end
        if player:isEngaged() then
            local masterTarget = player:getTarget()
            if masterTarget ~= nil and masterTarget:isAlive() then
                player:petAttack(masterTarget)
            end
        end
        local roleTag = (petId == PET_WILD_RAAZ or petId == PET_CEHUETZI)
            and 'Glacial Tusker Tank'
            or 'Volcanic Saurian Pack Predator'
        tell(player, string.format('%s [%s] answers your call!', label, roleTag))
    else
        tell(player, string.format('Failed to summon %s (ensure rng_specs.sql is imported).', label))
    end
    return 0
end

local function addPetEnmity(mob, pet, ce, ve)
    if mob == nil or pet == nil then
        return
    end
    if mob.updateClaim then
        local master = pet.getMaster and pet:getMaster() or nil
        if master == nil or not master.hasClaim or not master:hasClaim(mob) then
            mob:updateClaim(pet)
        end
    end
    if mob.addEnmity then
        mob:addEnmity(pet, ce, ve)
    elseif mob.updateEnmityFromDamage then
        mob:updateEnmityFromDamage(pet, ce + ve)
    end
end

local function checkEnemyTarget(player, target, range)
    if
        target == nil or
        not target:isMob() or
        not target:isAlive() or
        target:getAllegiance() == player:getAllegiance()
    then
        return xi.msg.basic.CANNOT_ATTACK_TARGET
    end
    if player:checkDistance(target) > (range or 20.0) then
        return xi.msg.basic.TOO_FAR_AWAY
    end
    return 0
end

-----------------------------------
-- 7 Custom Huntsman Job Abilities (480-486)
-----------------------------------

-- 480: Call Wild Raaz (60s CD, Self, Lv.10+)
bindAbility('call_wild_raaz', function(player, target, ability)
    return checkSummon(player, 10, 'Call Wild Raaz')
end, function(player, target, ability)
    return doSummon(player, PET_WILD_RAAZ, 'Wild Raaz')
end)

-- 481: Call Stalker Raptor (60s CD, Self, Lv.10+)
bindAbility('call_stalker_raptor', function(player, target, ability)
    return checkSummon(player, 10, 'Call Stalker Raptor')
end, function(player, target, ability)
    return doSummon(player, PET_STALKER_RAPTOR, 'Stalker Raptor')
end)

-- 485: Call Cehuetzi (60s CD, Self, Lv.75)
bindAbility('call_cehuetzi', function(player, target, ability)
    return checkSummon(player, 75, 'Call Cehuetzi')
end, function(player, target, ability)
    return doSummon(player, PET_CEHUETZI, 'Cehuetzi')
end)

-- 486: Call Gabbrath (60s CD, Self, Lv.75)
bindAbility('call_gabbrath', function(player, target, ability)
    return checkSummon(player, 75, 'Call Gabbrath')
end, function(player, target, ability)
    return doSummon(player, PET_GABBRATH, 'Gabbrath')
end)

-- 482: Rimetusk Gore (30s CD, Single-Target Enemy 20y, requires Raaz/Cehuetzi)
bindAbility('rimetusk_gore', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not isTuskerPet(player) then
        tell(player, 'Rimetusk Gore requires an active Wild Raaz or Cehuetzi.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local err = checkEnemyTarget(player, target, 20.0)
    if err ~= 0 then
        return err, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local isApex  = (pid == PET_CEHUETZI)
    local mult    = isApex and 1.25 or 1.0
    local baseDmg = math.max(20, math.floor(((lvl * 2.8) + player:getStat(xi.mod.VIT)) * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
    target:updateEnmityFromDamage(pet, dmg)
    addPetEnmity(target, pet, isApex and 1600 or 1200, isApex and 4800 or 3600)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    local healAmt = math.max(1, math.floor(pet:getMaxHP() * 0.20))
    pet:addHP(healAmt)
    pet:delStatusEffectSilent(xi.effect.DEFENSE_BOOST)
    pet:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = 20, duration = 10, origin = pet })
    local defEff = pet:getStatusEffect(xi.effect.DEFENSE_BOOST)
    if defEff ~= nil then
        defEff:addMod(xi.mod.DMG, -2000)
    end

    if isApex then
        slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, 15, 15, pet, function(eff)
            eff:addMod(xi.mod.ATTP, -15)
            eff:addMod(xi.mod.MATT, -15)
            eff:addMod(xi.mod.ACC, -20)
        end, slots.EFF_OX_DEB_CRIPPLE)
    end

    tell(player, string.format('%s gores %s for %d damage (+20%% Pet HP, -20%% Pet DT 10s%s)!',
        pet:getName(), target:getName(), dmg, isApex and ', Cripple 15s' or ''))
    return dmg
end)

-- 483: Saurian Rend (30s CD, Single-Target Enemy 20y, requires Raptor/Gabbrath)
bindAbility('saurian_rend', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not isSaurianPet(player) then
        tell(player, 'Saurian Rend requires an active Stalker Raptor or Gabbrath.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local err = checkEnemyTarget(player, target, 20.0)
    if err ~= 0 then
        return err, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local isApex  = (pid == PET_GABBRATH)
    local mult    = isApex and 1.30 or 1.0
    local baseDmg = math.max(25, math.floor(((lvl * 4.2) + player:getStat(xi.mod.AGI) * 1.4) * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    target:updateEnmityFromDamage(pet, dmg)
    addPetEnmity(target, pet, 150, 400)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    pet:addHP(math.max(1, math.floor(pet:getMaxHP() * 0.15)))

    local members = getPartyInRange(player, pet, 15.0)
    for _, member in ipairs(members) do
        member:addTP(150)
        slots.applySlot(member, slots.EFF_OX_SUP_OFFENSE, 15, 15, player, function(eff)
            eff:addMod(xi.mod.ATTP, 15)
            eff:addMod(xi.mod.RATTP, 15)
            eff:addMod(xi.mod.MATT, 15)
        end, slots.EFF_OX_SUP_OFFENSE)
    end

    if isApex then
        slots.applySlot(target, slots.EFF_OX_DEB_BREACH, 15, 15, pet, function(eff)
            eff:addMod(xi.mod.DEFP, -15)
            eff:addMod(xi.mod.MDEF, -15)
        end, slots.EFF_OX_DEB_BREACH)
    end

    tell(player, string.format('%s rends %s for %d damage (+15%% Pet HP, 15y +150 TP & Offense +15%%%s)!',
        pet:getName(), target:getName(), dmg, isApex and ', Breach 15s' or ''))
    return dmg
end)

-- 484: Primeval Takedown (45s CD, Single-Target Enemy 20y)
bindAbility('primeval_takedown', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet = getHuntsmanPet(player)
    if pet == nil or not pet:isAlive() then
        tell(player, 'Primeval Takedown requires an active beast companion.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local err = checkEnemyTarget(player, target, 20.0)
    if err ~= 0 then
        return err, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl    = pet:getMainLvl()
    local tusker = (pid == PET_WILD_RAAZ or pid == PET_CEHUETZI)
    local mult   = (pid == PET_CEHUETZI or pid == PET_GABBRATH) and 1.25 or 1.0

    local baseDmg = math.max(25, math.floor(((lvl * (tusker and 3.0 or 4.6)) + player:getStat(xi.mod.AGI) * 1.2) * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
    target:updateEnmityFromDamage(pet, dmg)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    if tusker then
        addPetEnmity(target, pet, 800, 2400)
        -- 2s NM-safe Stun
        if not target:hasStatusEffect(xi.effect.STUN) then
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = pet })
        end
        -- 25% Pet Max HP Permafrost Hide Stoneskin (12s)
        local shield = math.max(50, math.floor(pet:getMaxHP() * 0.25))
        pet:delStatusEffectSilent(xi.effect.STONESKIN)
        pet:addStatusEffect(xi.effect.STONESKIN, { power = shield, duration = 12, origin = pet, tier = 4 })
        tell(player, string.format('%s slams %s with Primeval Takedown for %d damage (2s Stun + %d Permafrost Hide)!',
            pet:getName(), target:getName(), dmg, shield))
    else
        player:addTP(300)
        tell(player, string.format('%s mauls %s with Primeval Takedown for %d damage (Huntsman +300 TP)!',
            pet:getName(), target:getName(), dmg))
    end
    return dmg
end)

-----------------------------------
-- Register RNG Huntsman Crystal
-----------------------------------
if xi.job and xi.job.RNG then
    spec.registerJob(xi.job.RNG, 'RNG',
    {
        {
            id          = 2,
            key         = HUNTSMAN_KEY,
            name        = 'Huntsman',
            role        = 'Modal Beastmaster Ranger',
            icon        = 'huntsman',
            reqLevel    = 10,
            description = 'Modal Pet-Tank & Pack Ranger who bonds with Glacial Tuskers (Wild Raaz / Cehuetzi) to anchor bosses or Volcanic Saurians (Stalker Raptor / Gabbrath) to empower party offense.',
            highlights  =
            {
                'Lv.10 QoL: Auto-equips Crossbow & Bolts if empty, 100% Ammo Recycle, zero ranged distance penalty; +12/16/20/25% HP, +15/25/35/50 Archery/Marksmanship, +12/20/28/38 RACC, +15/22/30/40% Snapshot/Rapid Shot, +8/12/16/22 Store TP with active pet.',
                'Warden\'s Ration: Ranged WSs heal your active beast for 15/18/20/22% Beast Max HP and grant +250 Pet TP.',
                'Glacial Tusker (Wild Raaz Lv.10+ / Cehuetzi Lv.75): Tier 6 -60% DMG Dealt (0.12x WS, 0.25x Pet Mobskill), +40..70% Pet HP, -30% Pet DT, 100% AoE/Conal immunity, +60..120 Pet Enmity, 100% Master->Pet enmity transfer & 80% Cure (+100% overheal) forwarding.',
                'Volcanic Saurian (Stalker Raptor Lv.10+ / Gabbrath Lv.75): Tier 2 Hybrid -25% DMG Dealt (0.50x WS) + -25 Enmity, 15y Party Pack Aura (+8..20 ACC/RACC & +8..15% ATK/RATK).',
                '100% Single-Target JAs: Rimetusk Gore, Saurian Rend, Primeval Takedown.',
            },
            extraAbilities = function(player)
                local lvl  = player ~= nil and player:getMainLvl() or 10
                local list =
                {
                    69, -- Fight
                    70, -- Heel
                    71, -- Leave
                    73, -- Stay
                    ABIL_CALL_WILD_RAAZ,
                    ABIL_CALL_STALKER_RAPTOR,
                    ABIL_RIMETUSK_GORE,
                    ABIL_SAURIAN_REND,
                    ABIL_PRIMEVAL_TAKEDOWN,
                }
                if lvl >= 75 then
                    table.insert(list, ABIL_CALL_CEHUETZI)
                    table.insert(list, ABIL_CALL_GABBRATH)
                end
                return list
            end,
            extraTraits = { TRAIT_WARDENS_RATION, TRAIT_PRIMEVAL_PACK, TRAIT_APEX_BOND },
            mods = function(player)
                local lvl = player ~= nil and player:getMainLvl() or 10
                local out =
                {
                    { xi.mod.HPP,          scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.ARCHERY,      scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.MARKSMANSHIP, scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.RACC,         scaleTier(lvl, 12, 20, 28, 38) },
                    { xi.mod.SNAP_SHOT,    scaleTier(lvl, 15, 22, 30, 40) },
                    { xi.mod.RAPID_SHOT,   scaleTier(lvl, 15, 22, 30, 40) },
                    { xi.mod.RECYCLE,      100 },
                }
                if not isTuskerPet(player) then
                    table.insert(out, { xi.mod.ENMITY, -25 })
                end
                return out
            end,
            onApply = function(player)
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                provisionStarterRanged(player)
                attachHuntsmanListeners(player)
                syncCompanionMasterMods(player)
            end,
            onRemove = function(player)
                detachHuntsmanListeners(player)
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                if player ~= nil and player.hasPet and player:hasPet() then
                    local pet = getHuntsmanPet(player)
                    if pet ~= nil and player.despawnPet then
                        player:despawnPet()
                    end
                end
            end,
        },
    })
end

return m
