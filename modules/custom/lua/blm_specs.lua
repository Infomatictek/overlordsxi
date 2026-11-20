-----------------------------------
-- SoulspireXI Black Mage Crystal Specs
-- Registers the Necromancer (Scythe & Undead Summoner) BLM soul crystal,
-- passive stats (HP+10%, A+ Scythe Skill, Occult Acumen), Undead Summons,
-- Corpse Explosion, Harbinger's Drain, Dark Pact, and Pet Commands.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/pets')
require('scripts/globals/player')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/combat/physical_utilities')
-----------------------------------
local m = Module:new('soulspire_blm_specs')

local spec = xi.soulspire.spec

local NECRO_KEY = 'necromancer'

local ABIL_SUMMON_WARRIOR  = 405
local ABIL_SUMMON_MAGE     = 406
local ABIL_CORPSE_EXPLODE  = 407
local ABIL_GRIM_REAPING    = 408
local ABIL_GRIM_INCANT     = 409
local ABIL_SUMMON_CORSE    = 410
local ABIL_SUMMON_DULLAHAN = 411

-- Grim Reaping Sub-Menu (Tank Pet Commands: Undead Warrior / Dullahan)
local ABIL_GRAVE_PROVOKE   = 419
local ABIL_BLACK_CLOUD     = 420
local ABIL_BONE_AEGIS      = 421
local ABIL_BLOOD_SABER     = 422
local ABIL_AEGIS_SCHISM    = 423

-- Grim Incantations Sub-Menu (Party DPS & Caster Pet Commands: Undead Mage / Corse)
local ABIL_NECROTIC_BOLT   = 424
local ABIL_COVENANT_ASH    = 425
local ABIL_CURSE_FALLEN    = 426
local ABIL_SOUL_HARVEST    = 427
local ABIL_DANSE_MACABRE   = 428

local PET_UNDEAD_WARRIOR   = 130
local PET_UNDEAD_MAGE      = 131
local PET_UNDEAD_CORSE     = 132
local PET_UNDEAD_DULLAHAN  = 133

local TRAIT_HARBINGERS_DRAIN = 147
local TRAIT_DARK_PACT        = 148
local TRAIT_GRIM_CONVERSION  = 149

local UNDEAD_PETS =
{
    [PET_UNDEAD_WARRIOR]  = true,
    [PET_UNDEAD_MAGE]     = true,
    [PET_UNDEAD_CORSE]    = true,
    [PET_UNDEAD_DULLAHAN] = true,
}

local WARRIOR_PETS =
{
    [PET_UNDEAD_WARRIOR]  = true,
    [PET_UNDEAD_DULLAHAN] = true,
}

local MAGE_PETS =
{
    [PET_UNDEAD_MAGE]  = true,
    [PET_UNDEAD_CORSE] = true,
}

-- Vanilla All-Jobs / BLM-equippable scythes that remain usable without Necromancer
local VANILLA_BLM_SCYTHES =
{
    [16779] = true, -- Pitchfork
    [16780] = true, -- Pitchfork +1
    [16797] = true, -- Ark Scythe
}

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.SUMMON_UNDEAD_WARRIOR = ABIL_SUMMON_WARRIOR
xi.jobAbility.SUMMON_UNDEAD_MAGE    = ABIL_SUMMON_MAGE
xi.jobAbility.CORPSE_EXPLOSION      = ABIL_CORPSE_EXPLODE
xi.jobAbility.GRIM_REAPING          = ABIL_GRIM_REAPING
xi.jobAbility.GRIM_INCANTATIONS     = ABIL_GRIM_INCANT
xi.jobAbility.SUMMON_CORSE          = ABIL_SUMMON_CORSE
xi.jobAbility.SUMMON_DULLAHAN       = ABIL_SUMMON_DULLAHAN
xi.jobAbility.GRAVE_PROVOKE         = ABIL_GRAVE_PROVOKE
xi.jobAbility.BLACK_CLOUD           = ABIL_BLACK_CLOUD
xi.jobAbility.BONE_AEGIS            = ABIL_BONE_AEGIS
xi.jobAbility.BLOOD_SABER           = ABIL_BLOOD_SABER
xi.jobAbility.AEGIS_SCHISM          = ABIL_AEGIS_SCHISM
xi.jobAbility.NECROTIC_BOLT         = ABIL_NECROTIC_BOLT
xi.jobAbility.COVENANT_OF_ASH       = ABIL_COVENANT_ASH
xi.jobAbility.CURSE_OF_THE_FALLEN   = ABIL_CURSE_FALLEN
xi.jobAbility.SOUL_HARVEST          = ABIL_SOUL_HARVEST
xi.jobAbility.DANSE_MACABRE         = ABIL_DANSE_MACABRE

xi.petId = xi.petId or {}
xi.petId.UNDEAD_WARRIOR  = PET_UNDEAD_WARRIOR
xi.petId.UNDEAD_MAGE     = PET_UNDEAD_MAGE
xi.petId.UNDEAD_CORSE    = PET_UNDEAD_CORSE
xi.petId.UNDEAD_DULLAHAN = PET_UNDEAD_DULLAHAN

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
for _, abilName in ipairs({
    'summon_undead_warrior', 'summon_undead_mage', 'corpse_explosion',
    'grim_reaping', 'grim_incantations', 'summon_corse', 'summon_dullahan',
    'grave_provoke', 'black_cloud', 'bone_aegis', 'blood_saber', 'aegis_schism',
    'necrotic_bolt', 'covenant_of_ash', 'curse_of_the_fallen', 'soul_harvest', 'danse_macabre',
}) do
    xi.actions.abilities[abilName] = xi.actions.abilities[abilName] or {}
end

local function tell(player, message)
    if player ~= nil and player.printToPlayer then
        player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
    end
end

local function scaleTier(lvl, lv10, lv30, lv50, lv75)
    local l = lvl or 1
    if l >= 75 then
        return lv75
    elseif l >= 50 then
        return lv50
    elseif l >= 30 then
        return lv30
    end
    return lv10
end

local function isNecromancer(player)
    if player == nil or not player:isPC() or player:getMainJob() ~= xi.job.BLM then
        return false
    end
    spec.ensureUpToDate(player)
    return spec.is(player, xi.job.BLM, NECRO_KEY)
end

local function getUndeadPet(player)
    if player == nil or not player.hasPet or not player:hasPet() then
        return nil, nil
    end
    local pet = player:getPet()
    if pet == nil then
        return nil, nil
    end
    local petId = pet:getPetID()
    if UNDEAD_PETS[petId] then
        return pet, petId
    end
    return nil, nil
end

local function isTankThrallActive(player)
    local pet, petId = getUndeadPet(player)
    if pet ~= nil and (not pet.isAlive or pet:isAlive()) and WARRIOR_PETS[petId] then
        return pet, petId
    end
    return nil, nil
end

local lastScytheWsByChar = {}

local function isScytheWs(actor, skill)
    if skill ~= nil and skill.getSkillType then
        return skill:getSkillType() == xi.skill.SCYTHE
    end
    if actor ~= nil and actor.getWeaponSkillType then
        return actor:getWeaponSkillType(xi.slot.MAIN) == xi.skill.SCYTHE
    end
    return false
end

local function transferSingleTargetEnmityToPet(master, target)
    if not isNecromancer(master) then
        return
    end
    local pet = isTankThrallActive(master)
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

local function forwardCureToThrall(master, actualHealed, rawEstimated)
    if not isNecromancer(master) then
        return
    end
    local pet = isTankThrallActive(master)
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

local function getMasterMabMult(player)
    if player == nil then
        return 1.0
    end
    local matt = math.max(0, player:getMod(xi.mod.MATT)) + player:getLocalVar('OX_NECRO_CONV_MATT')
    return 1.0 + (matt / 100.0)
end

local function scaleLevelGapDmg(attacker, defender, dmg)
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        return xi.customBossServer.scaleDamageByLevelGap(attacker, defender, dmg)
    end
    return dmg
end

local function getPartyInRange(player, anchor, maxDist)
    local members = {}
    local seen    = {}
    local function tryInsert(entity)
        if
            entity ~= nil and
            entity.getID and
            not seen[entity:getID()] and
            entity:isAlive() and
            entity:getZoneID() == player:getZoneID() and
            anchor:checkDistance(entity) <= maxDist
        then
            seen[entity:getID()] = true
            table.insert(members, entity)
        end
    end

    local party = player.getParty and player:getParty() or nil
    if party ~= nil then
        for _, member in ipairs(party) do
            tryInsert(member)
            if member ~= nil and member.hasPet and member:hasPet() then
                tryInsert(member:getPet())
            end
        end
    end

    if player:isAlive() then
        tryInsert(player)
        if player.hasPet and player:hasPet() then
            tryInsert(player:getPet())
        end
    end

    return members
end

-----------------------------------
-- Dark Pact (DA, Store TP, Acc while Undead Summon is alive)
-----------------------------------
local function clearDarkPactMods(player)
    if player == nil then
        return false
    end
    local prevDa  = player:getLocalVar('OX_NECRO_PACT_DA')
    local prevStp = player:getLocalVar('OX_NECRO_PACT_STP')
    local prevAcc = player:getLocalVar('OX_NECRO_PACT_ACC')
    local changed = false
    if prevDa > 0 then
        player:delMod(xi.mod.DOUBLE_ATTACK, prevDa)
        player:setLocalVar('OX_NECRO_PACT_DA', 0)
        changed = true
    end
    if prevStp > 0 then
        player:delMod(xi.mod.STORETP, prevStp)
        player:setLocalVar('OX_NECRO_PACT_STP', 0)
        changed = true
    end
    if prevAcc > 0 then
        player:delMod(xi.mod.ACC, prevAcc)
        player:setLocalVar('OX_NECRO_PACT_ACC', 0)
        changed = true
    end
    return changed
end

local function syncDarkPactMods(player)
    if player == nil or not player:isPC() then
        return
    end
    if not isNecromancer(player) then
        if clearDarkPactMods(player) and player.pushStatus then
            player:pushStatus()
        end
        return
    end
    local pet = getUndeadPet(player)
    if pet == nil or not pet:isAlive() then
        if clearDarkPactMods(player) and player.pushStatus then
            player:pushStatus()
        end
        return
    end

    local lvl = player:getMainLvl()
    local da  = scaleTier(lvl, 8, 12, 16, 20)
    local stp = scaleTier(lvl, 10, 15, 20, 25)
    local acc = scaleTier(lvl, 10, 20, 35, 50)

    if
        player:getLocalVar('OX_NECRO_PACT_DA') == da and
        player:getLocalVar('OX_NECRO_PACT_STP') == stp and
        player:getLocalVar('OX_NECRO_PACT_ACC') == acc
    then
        return
    end

    clearDarkPactMods(player)
    player:addMod(xi.mod.DOUBLE_ATTACK, da)
    player:addMod(xi.mod.STORETP, stp)
    player:addMod(xi.mod.ACC, acc)
    player:setLocalVar('OX_NECRO_PACT_DA', da)
    player:setLocalVar('OX_NECRO_PACT_STP', stp)
    player:setLocalVar('OX_NECRO_PACT_ACC', acc)
    if player.pushStatus then
        player:pushStatus()
    end
end

-----------------------------------
-- Grim Conversion (Lv.10+: MACC->ACC, MATT->ATT, FASTCAST->Haste, MB Bonus->WSD)
-- Elemental Celerity (xi.mod.ELEMENTAL_CELERITY) is left untouched.
-----------------------------------
local function getMbBonusCappedMod()
    return xi.mod and (xi.mod.MAGIC_BURST_BONUS_CAPPED or xi.mod.MAG_BURST_BONUS) or nil
end

local function getMbBonusUncappedMod()
    return xi.mod and xi.mod.MAGIC_BURST_BONUS_UNCAPPED or nil
end

local function getUfastcastMod()
    return xi.mod and xi.mod.UFASTCAST or nil
end

local function clearConversionMods(player)
    if player == nil then
        return false
    end
    local modMbCapped   = getMbBonusCappedMod()
    local modMbUncapped = getMbBonusUncappedMod()
    local modUfastcast  = getUfastcastMod()

    local cMacc   = player:getLocalVar('OX_NECRO_CONV_MACC')
    local cMatt   = player:getLocalVar('OX_NECRO_CONV_MATT')
    local cFc     = player:getLocalVar('OX_NECRO_CONV_FC')
    local cUfc    = player:getLocalVar('OX_NECRO_CONV_UFC')
    local cHasteA = player:getLocalVar('OX_NECRO_CONV_HASTE_A')
    local cHasteG = player:getLocalVar('OX_NECRO_CONV_HASTE_G')
    local cHasteM = player:getLocalVar('OX_NECRO_CONV_HASTE_M')
    local cMbbC   = player:getLocalVar('OX_NECRO_CONV_MBB_C')
    local cMbbU   = player:getLocalVar('OX_NECRO_CONV_MBB_U')

    if cHasteA == 0 and cHasteG == 0 and cHasteM == 0 and cFc > 0 then
        cHasteA = cFc * 100
    end

    local changed = false
    if cMacc > 0 then
        player:delMod(xi.mod.ACC, cMacc)
        player:addMod(xi.mod.MACC, cMacc)
        player:setLocalVar('OX_NECRO_CONV_MACC', 0)
        changed = true
    end
    if cMatt > 0 then
        player:delMod(xi.mod.ATT, cMatt)
        player:addMod(xi.mod.MATT, cMatt)
        player:setLocalVar('OX_NECRO_CONV_MATT', 0)
        changed = true
    end
    if cFc > 0 then
        player:addMod(xi.mod.FASTCAST, cFc)
        player:setLocalVar('OX_NECRO_CONV_FC', 0)
        changed = true
    end
    if cUfc > 0 and modUfastcast ~= nil then
        player:addMod(modUfastcast, cUfc)
        player:setLocalVar('OX_NECRO_CONV_UFC', 0)
        changed = true
    end
    if cHasteA > 0 then
        player:delMod(xi.mod.HASTE_ABILITY, cHasteA)
        player:setLocalVar('OX_NECRO_CONV_HASTE_A', 0)
        changed = true
    end
    if cHasteG > 0 then
        player:delMod(xi.mod.HASTE_GEAR, cHasteG)
        player:setLocalVar('OX_NECRO_CONV_HASTE_G', 0)
        changed = true
    end
    if cHasteM > 0 then
        player:delMod(xi.mod.HASTE_MAGIC, cHasteM)
        player:setLocalVar('OX_NECRO_CONV_HASTE_M', 0)
        changed = true
    end
    if cMbbC > 0 and modMbCapped ~= nil then
        player:delMod(xi.mod.ALL_WSDMG_ALL_HITS, cMbbC)
        player:addMod(modMbCapped, cMbbC)
        player:setLocalVar('OX_NECRO_CONV_MBB_C', 0)
        changed = true
    end
    if cMbbU > 0 and modMbUncapped ~= nil then
        player:delMod(xi.mod.ALL_WSDMG_ALL_HITS, cMbbU)
        player:addMod(modMbUncapped, cMbbU)
        player:setLocalVar('OX_NECRO_CONV_MBB_U', 0)
        changed = true
    end
    return changed
end

local function syncConversionMods(player)
    if player == nil or not player:isPC() then
        return
    end
    if not isNecromancer(player) or player:getMainLvl() < 10 then
        if clearConversionMods(player) and player.pushStatus then
            player:pushStatus()
        end
        return
    end

    local modMbCapped   = getMbBonusCappedMod()
    local modMbUncapped = getMbBonusUncappedMod()
    local modUfastcast  = getUfastcastMod()

    local rawMacc = player:getMod(xi.mod.MACC)
    local rawMatt = player:getMod(xi.mod.MATT)
    local rawFc   = player:getMod(xi.mod.FASTCAST)
    local rawUfc  = modUfastcast ~= nil and player:getMod(modUfastcast) or 0
    local rawMbbC = modMbCapped ~= nil and player:getMod(modMbCapped) or 0
    local rawMbbU = modMbUncapped ~= nil and player:getMod(modMbUncapped) or 0

    if rawMacc == 0 and rawMatt == 0 and rawFc == 0 and rawUfc == 0 and rawMbbC == 0 and rawMbbU == 0 then
        return
    end

    local cleared = clearConversionMods(player)

    local macc = math.max(0, player:getMod(xi.mod.MACC))
    local matt = math.max(0, player:getMod(xi.mod.MATT))
    local fc   = math.max(0, player:getMod(xi.mod.FASTCAST))
    local ufc  = modUfastcast ~= nil and math.max(0, player:getMod(modUfastcast)) or 0
    local mbbC = modMbCapped ~= nil and math.max(0, player:getMod(modMbCapped)) or 0
    local mbbU = modMbUncapped ~= nil and math.max(0, player:getMod(modMbUncapped)) or 0

    local applied = false
    if macc > 0 then
        player:delMod(xi.mod.MACC, macc)
        player:addMod(xi.mod.ACC, macc)
        player:setLocalVar('OX_NECRO_CONV_MACC', macc)
        applied = true
    end
    if matt > 0 then
        player:delMod(xi.mod.MATT, matt)
        player:addMod(xi.mod.ATT, matt)
        player:setLocalVar('OX_NECRO_CONV_MATT', matt)
        applied = true
    end
    if fc > 0 then
        player:delMod(xi.mod.FASTCAST, fc)
        player:setLocalVar('OX_NECRO_CONV_FC', fc)
        applied = true
    end
    if ufc > 0 and modUfastcast ~= nil then
        player:delMod(modUfastcast, ufc)
        player:setLocalVar('OX_NECRO_CONV_UFC', ufc)
        applied = true
    end

    local totalHasteBps = (fc + ufc) * 100
    if totalHasteBps > 0 then
        local rem   = totalHasteBps
        local headA = math.max(0, 2500 - player:getMod(xi.mod.HASTE_ABILITY))
        local addA  = math.min(rem, headA)
        rem = rem - addA

        local headG = math.max(0, 2500 - player:getMod(xi.mod.HASTE_GEAR))
        local addG  = math.min(rem, headG)
        rem = rem - addG

        local headM = math.max(0, 4375 - player:getMod(xi.mod.HASTE_MAGIC))
        local addM  = math.min(rem, headM)

        if addA > 0 then
            player:addMod(xi.mod.HASTE_ABILITY, addA)
            player:setLocalVar('OX_NECRO_CONV_HASTE_A', addA)
        end
        if addG > 0 then
            player:addMod(xi.mod.HASTE_GEAR, addG)
            player:setLocalVar('OX_NECRO_CONV_HASTE_G', addG)
        end
        if addM > 0 then
            player:addMod(xi.mod.HASTE_MAGIC, addM)
            player:setLocalVar('OX_NECRO_CONV_HASTE_M', addM)
        end
        applied = true
    end

    if mbbC > 0 and modMbCapped ~= nil then
        player:delMod(modMbCapped, mbbC)
        player:addMod(xi.mod.ALL_WSDMG_ALL_HITS, mbbC)
        player:setLocalVar('OX_NECRO_CONV_MBB_C', mbbC)
        applied = true
    end
    if mbbU > 0 and modMbUncapped ~= nil then
        player:delMod(modMbUncapped, mbbU)
        player:addMod(xi.mod.ALL_WSDMG_ALL_HITS, mbbU)
        player:setLocalVar('OX_NECRO_CONV_MBB_U', mbbU)
        applied = true
    end

    if (cleared or applied) and player.pushStatus then
        player:pushStatus()
    end
end

local function detachNecroListeners(player)
    if player == nil or not player:isPC() then
        return
    end
    player:removeListener('OX_NECRO_WS_DRAIN')
    player:removeListener('OX_NECRO_ENMITY_ATK')
    player:removeListener('OX_NECRO_ENMITY_MAG')
    player:removeListener('OX_NECRO_PET_CHECK')
    player:removeListener('OX_NECRO_TICK')
    player:removeListener('OX_NECRO_EQUIP_SYNC')
    player:removeListener('OX_NECRO_EFFECT_GAIN')
    player:removeListener('OX_NECRO_EFFECT_LOSE')
    local cPact = clearDarkPactMods(player)
    local cConv = clearConversionMods(player)
    if (cPact or cConv) and player.pushStatus then
        player:pushStatus()
    end
end

-----------------------------------
-- Harbinger's Drain (WS heals active Undead Pet)
-----------------------------------
local function attachNecroListeners(player)
    if player == nil or not player:isPC() then
        return
    end

    player:removeListener('OX_NECRO_WS_DRAIN')
    player:addListener('WEAPONSKILL_USE', 'OX_NECRO_WS_DRAIN', function(actor, target, ws, tp, _action, dmg)
        if not isNecromancer(actor) then
            return
        end
        local pet, petId = getUndeadPet(actor)
        if pet == nil or not pet:isAlive() then
            return
        end

        local charId = actor.getID and actor:getID() or 0
        local now    = os.clock()
        if charId > 0 and (now - (lastScytheWsByChar[charId] or 0)) <= 0.1 then
            return
        end
        if charId > 0 then
            lastScytheWsByChar[charId] = now
        end

        local lvl = actor:getMainLvl()
        if WARRIOR_PETS[petId] and isScytheWs(actor, ws) then
            -- Clamp-proof Tank Thrall sustain: 16/18/20/22% of Thrall Max HP
            local pct     = scaleTier(lvl, 0.16, 0.18, 0.20, 0.22)
            local heal    = math.max(1, math.floor((pet:getMaxHP() or 0) * pct))
            local drained = pet:addHP(heal)
            if drained > 0 and actor.messagePublic and xi.msg and xi.msg.basic and xi.msg.basic.RECOVERS_HP then
                actor:messagePublic(xi.msg.basic.RECOVERS_HP, pet, 0, drained)
            end
            tell(actor, string.format("Harbinger's Drain restores %d HP to %s.", drained, pet:getName()))
            transferSingleTargetEnmityToPet(actor, target)
            return
        end

        if (dmg or 0) <= 0 then
            return
        end
        local pct     = lvl >= 75 and 0.50 or (lvl >= 50 and 0.35 or 0.25)
        local heal    = math.max(1, math.floor(dmg * pct))
        local missing = math.max(0, pet:getMaxHP() - pet:getHP())
        local actual  = math.min(heal, missing)
        if actual > 0 then
            local drained = pet:addHP(actual)
            if drained > 0 and actor.messagePublic and xi.msg and xi.msg.basic and xi.msg.basic.RECOVERS_HP then
                actor:messagePublic(xi.msg.basic.RECOVERS_HP, pet, 0, drained)
            end
            tell(actor, string.format("Harbinger's Drain restores %d HP to %s.", drained, pet:getName()))
        end
    end)

    player:removeListener('OX_NECRO_ENMITY_ATK')
    player:addListener('ATTACK', 'OX_NECRO_ENMITY_ATK', function(actor, target)
        transferSingleTargetEnmityToPet(actor, target)
    end)

    player:removeListener('OX_NECRO_ENMITY_MAG')
    player:addListener('MAGIC_USE', 'OX_NECRO_ENMITY_MAG', function(actor, target)
        transferSingleTargetEnmityToPet(actor, target)
    end)

    player:removeListener('OX_NECRO_PET_CHECK')
    player:removeListener('OX_NECRO_TICK')
    player:addListener('TICK', 'OX_NECRO_TICK', function(actor)
        if not isNecromancer(actor) then
            detachNecroListeners(actor)
            return
        end

        spec.refreshPlayer(actor, { skipSync = true })
        syncDarkPactMods(actor)
        syncConversionMods(actor)

        local pet, petId = getUndeadPet(actor)
        if pet ~= nil and pet:isAlive() then
            if WARRIOR_PETS[petId] then
                transferSingleTargetEnmityToPet(actor, actor:getTarget())
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

    player:removeListener('OX_NECRO_EQUIP_SYNC')
    player:removeListener('OX_NECRO_EFFECT_GAIN')
    player:addListener('EFFECT_GAIN', 'OX_NECRO_EFFECT_GAIN', function(actor)
        syncConversionMods(actor)
    end)

    player:removeListener('OX_NECRO_EFFECT_LOSE')
    player:addListener('EFFECT_LOSE', 'OX_NECRO_EFFECT_LOSE', function(actor)
        syncConversionMods(actor)
    end)
end

local function enforceNonNecroScytheGate(player)
    if
        player ~= nil and
        player:isPC() and
        player:getMainJob() == xi.job.BLM and
        not isNecromancer(player)
    then
        local item = player:getEquippedItem(xi.slot.MAIN)
        if
            item ~= nil and
            item.getSkillType and
            item:getSkillType() == xi.skill.SCYTHE and
            not VANILLA_BLM_SCYTHES[item:getID()]
        then
            player:unequipItem(xi.slot.MAIN)
            tell(player, 'Only a BLM with the Necromancer crystal can wield that Scythe.')
        end
    end
end

-- Restrict non-vanilla Scythes to BLM Necromancer spec only and keep Necro traits synced
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        player:removeListener('OX_BLM_SCYTHE_GATE')
        player:addListener('TICK', 'OX_BLM_SCYTHE_GATE', function(actor)
            enforceNonNecroScytheGate(actor)
        end)
        enforceNonNecroScytheGate(player)

        if isNecromancer(player) then
            attachNecroListeners(player)
            syncDarkPactMods(player)
            syncConversionMods(player)
        else
            detachNecroListeners(player)
        end
    end
end)

m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        if isNecromancer(player) then
            attachNecroListeners(player)
            syncDarkPactMods(player)
            syncConversionMods(player)
        else
            detachNecroListeners(player)
        end
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        if isNecromancer(player) then
            attachNecroListeners(player)
            syncDarkPactMods(player)
            syncConversionMods(player)
        else
            detachNecroListeners(player)
        end
    end
end)

-----------------------------------
-- Summon Abilities (405, 406, 410, 411)
-----------------------------------
local function checkSummon(player, minLevel, label)
    if not isNecromancer(player) then
        tell(player, label .. ' is only available to BLM Necromancer spec (Lv.10+).')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if player:getMainLvl() < minLevel then
        tell(player, string.format('%s requires BLM Lv.%d+.', label, minLevel))
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if player:hasPet() then
        return xi.msg.basic.ALREADY_HAS_A_PET, 0
    end
    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end
    return 0, 0
end

local function applyUndeadPetRoleMods(pet, petId)
    if pet == nil then
        return
    end
    if WARRIOR_PETS[petId] then
        -- Frontline Tank Passives: +35% HP, -25% Damage Taken, +60 Enmity, +25% DEF
        pet:addMod(xi.mod.HPP, 35)
        pet:addMod(xi.mod.DMG, -2500)
        pet:addMod(xi.mod.ENMITY, 60)
        pet:addMod(xi.mod.DEFP, 25)
        if pet.updateHealth then
            pet:updateHealth()
        end
        pet:addHP(pet:getMaxHP())
    elseif MAGE_PETS[petId] then
        -- Ranged Dark Caster & Party DPS Passives: +25 MAB, +30 MACC, +5/tick Refresh
        pet:addMod(xi.mod.MATT, 25)
        pet:addMod(xi.mod.MACC, 30)
        pet:addMod(xi.mod.REFRESH, 5)
    end
end

local function doSummon(player, petId, label)
    xi.pet.spawnPet(player, petId)
    spec.refreshPlayer(player, { skipSync = true, forceMods = true })
    syncDarkPactMods(player)
    if player:hasPet() then
        local pet = player:getPet()
        applyUndeadPetRoleMods(pet, petId)
        spec.syncPetRoleMods(player, pet)
        if player.recalculateAbilitiesTable then
            player:recalculateAbilitiesTable()
        end
        if player:isEngaged() then
            local masterTarget = player:getTarget()
            if masterTarget ~= nil and masterTarget:isAlive() then
                player:petAttack(masterTarget)
            end
        end
        local roleTag = WARRIOR_PETS[petId] and 'Tank (Grim Reaping)' or 'Ranged Caster / Party DPS (Grim Incantations)'
        tell(player, string.format('%s [%s] answers your call!', label, roleTag))
    else
        tell(player, string.format('Failed to summon %s (ensure blm_necro_spec.sql is imported and xi_map restarted).', label))
    end
    return 0
end

local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

bindAbility('summon_undead_warrior', function(player, target, ability)
    return checkSummon(player, 10, 'Summon Undead Warrior')
end, function(player, target, ability)
    return doSummon(player, PET_UNDEAD_WARRIOR, 'Undead Warrior')
end)

bindAbility('summon_undead_mage', function(player, target, ability)
    return checkSummon(player, 10, 'Summon Undead Mage')
end, function(player, target, ability)
    return doSummon(player, PET_UNDEAD_MAGE, 'Undead Mage')
end)

bindAbility('summon_corse', function(player, target, ability)
    return checkSummon(player, 75, 'Summon Corse')
end, function(player, target, ability)
    return doSummon(player, PET_UNDEAD_CORSE, 'Corse')
end)

bindAbility('summon_dullahan', function(player, target, ability)
    return checkSummon(player, 75, 'Summon Dullahan')
end, function(player, target, ability)
    return doSummon(player, PET_UNDEAD_DULLAHAN, 'Dullahan')
end)

-----------------------------------
-- Corpse Explosion (407): Implode Undead Pet onto Single Target for Concentrated Dark Damage
-----------------------------------
bindAbility('corpse_explosion', function(player, target, ability)
    if not isNecromancer(player) then
        tell(player, 'Corpse Explosion is only available to BLM Necromancer spec.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet = getUndeadPet(player)
    if pet == nil or not pet:isAlive() then
        tell(player, 'Corpse Explosion requires an active Undead Summon.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local mob = pet:getTarget() or player:getTarget()
    if mob == nil or not mob:isMob() or not mob:isAlive() or mob:getAllegiance() == player:getAllegiance() then
        tell(player, 'Corpse Explosion requires an engaged enemy target.')
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    if target ~= nil and target:getID() ~= player:getID() then
        return 0
    end
    local pet, petId = getUndeadPet(player)
    if pet == nil then
        return 0
    end
    local mob = pet:getTarget() or player:getTarget()
    if mob == nil or not mob:isMob() or not mob:isAlive() or mob:getAllegiance() == player:getAllegiance() then
        return 0
    end

    local petHp    = pet:getHP()
    local petMaxHp = math.max(1, pet:getMaxHP())
    local hpRatio  = math.min(1.0, math.max(0.25, petHp / petMaxHp))
    local lvl      = player:getMainLvl()
    local intStat  = player:getStat(xi.mod.INT)
    local mab      = getMasterMabMult(player)
    local tierMult = (petId == PET_UNDEAD_CORSE or petId == PET_UNDEAD_DULLAHAN) and 1.35 or 1.0

    local baseDmg = math.floor(((lvl * 7.5) + (intStat * 2.5) + (petHp * 0.40)) * hpRatio * mab * tierMult)
    baseDmg = math.max(25, baseDmg)

    local scaledBase = scaleLevelGapDmg(player, mob, baseDmg)
    local dmg = utils.handleStoneskin(mob, scaledBase, xi.attackType.MAGICAL)
    if mob.updateClaim and not player:hasClaim(mob) then
        mob:updateClaim(player)
    end
    mob:takeDamage(dmg, player, xi.attackType.MAGICAL, xi.damageType.DARK)
    if mob.updateEnmityFromDamage then
        mob:updateEnmityFromDamage(player, dmg)
    end
    if not mob:hasStatusEffect(xi.effect.BIO) then
        mob:addStatusEffect(xi.effect.BIO, { power = math.max(2, math.floor(lvl / 8)), tick = 3, duration = 30, origin = player })
    end
    if action and action.recordDamage then
        action:recordDamage(mob, xi.attackType.MAGICAL, dmg)
    end

    tell(player, string.format('Corpse Explosion implodes %s onto %s for %d Dark damage!',
        pet:getName(), mob:getName(), dmg))

    player:despawnPet()
    if player.recalculateAbilitiesTable then
        player:recalculateAbilitiesTable()
    end
    clearDarkPactMods(player)
    spec.refreshPlayer(player, { skipSync = true, forceMods = true })
    return dmg
end)

-----------------------------------
-- Helper Checkers for Grim Reaping (Tank) & Grim Incantations (Caster/Party DPS)
-----------------------------------
local function checkTankPetAbility(player, target, minLevel, label, needsEnemy)
    if not isNecromancer(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if player:getMainLvl() < minLevel then
        tell(player, string.format('%s requires BLM Lv.%d+.', label, minLevel))
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet, petId = getUndeadPet(player)
    if pet == nil or not pet:isAlive() or not WARRIOR_PETS[petId] then
        tell(player, label .. ' requires an active Undead Warrior or Dullahan.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if needsEnemy and (target == nil or not target:isMob() or not target:isAlive()) then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return 0, 0
end

local function checkCasterPetAbility(player, target, minLevel, label, needsEnemy)
    if not isNecromancer(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if player:getMainLvl() < minLevel then
        tell(player, string.format('%s requires BLM Lv.%d+.', label, minLevel))
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet, petId = getUndeadPet(player)
    if pet == nil or not pet:isAlive() or not MAGE_PETS[petId] then
        tell(player, label .. ' requires an active Undead Mage or Corse.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if needsEnemy and (target == nil or not target:isMob() or not target:isAlive()) then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return 0, 0
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

-----------------------------------
-- Grim Reaping Sub-Menu Skills (419-423: Tank Pet Commands)
-----------------------------------

-- 419: Grave Provoke (Lv.10+): High-enmity undead taunt + Attack Down
bindAbility('grave_provoke', function(player, target, ability)
    return checkTankPetAbility(player, target, 10, 'Grave Provoke', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local isDull = (petId == PET_UNDEAD_DULLAHAN)
    addPetEnmity(target, pet, isDull and 2400 or 1800, isDull and 7200 or 5400)
    target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = isDull and 20 or 15, duration = 45, origin = pet })
    if isDull then
        target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 20, duration = 45, origin = pet })
    end
    tell(player, string.format('%s uses Grave Provoke on %s (Massive Enmity + Attack Down)!', pet:getName(), target:getName()))
    return 0
end)

-- 420: Black Cloud (Lv.20+): Single-Target Dark burst + Blind + Enmity
bindAbility('black_cloud', function(player, target, ability)
    return checkTankPetAbility(player, target, 20, 'Black Cloud', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local isDull  = (petId == PET_UNDEAD_DULLAHAN)
    local mult    = isDull and 1.35 or 1.0
    local baseDmg = math.max(15, math.floor(((lvl * 2.8) + player:getStat(xi.mod.INT)) * mult))
    local scaled  = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, scaled, xi.attackType.MAGICAL)

    target:takeDamage(dmg, pet, xi.attackType.MAGICAL, xi.damageType.DARK)
    addPetEnmity(target, pet, 900, 2400)
    target:addStatusEffect(xi.effect.BLINDNESS, { power = isDull and 35 or 25, duration = 60, origin = pet })

    if dmg > 0 and action and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, dmg)
    end
    tell(player, string.format('%s shrouds %s in Black Cloud for %d Dark damage (Blind + Enmity)!',
        pet:getName(), target:getName(), dmg))
    return dmg
end)

-- 421: Bone Aegis (Lv.35+): Pet Stoneskin barrier + Defense Boost + Spikes
bindAbility('bone_aegis', function(player, target, ability)
    return checkTankPetAbility(player, target, 35, 'Bone Aegis', false)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil then
        return 0
    end
    local isDull = (petId == PET_UNDEAD_DULLAHAN)
    local shield = math.max(50, math.floor(pet:getMaxHP() * (isDull and 0.35 or 0.25)))
    pet:delStatusEffect(xi.effect.STONESKIN)
    pet:addStatusEffect(xi.effect.STONESKIN, { power = shield, duration = 180, origin = pet })
    pet:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = isDull and 35 or 25, duration = 60, origin = pet })
    if xi.effect.DREAD_SPIKES then
        pet:addStatusEffect(xi.effect.DREAD_SPIKES, { power = 0, duration = 60, subPower = math.floor(shield * 0.5), origin = pet })
    end
    local petTarget = pet:getTarget()
    if petTarget ~= nil and petTarget:isAlive() then
        addPetEnmity(petTarget, pet, 600, 1800)
    end
    tell(player, string.format('%s fortifies itself with Bone Aegis (%d HP barrier + Defense Boost)!', pet:getName(), shield))
    return shield
end)

-- 422: Blood Saber (Lv.50+): Vampiric slash draining 100% of damage as Pet HP + Enmity
bindAbility('blood_saber', function(player, target, ability)
    return checkTankPetAbility(player, target, 50, 'Blood Saber', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local scythe  = player:getSkillLevel(xi.skill.SCYTHE)
    local isDull  = (petId == PET_UNDEAD_DULLAHAN)
    local mult    = isDull and 1.40 or 1.0
    local baseDmg = math.max(30, math.floor(((lvl * 4.2) + (scythe * 0.85) + player:getStat(xi.mod.STR)) * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    target:updateEnmityFromDamage(pet, dmg)
    addPetEnmity(target, pet, 1100, 2800)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    local healed = pet:addHP(dmg)
    if healed > 0 and player.messagePublic and xi.msg and xi.msg.basic and xi.msg.basic.RECOVERS_HP then
        player:messagePublic(xi.msg.basic.RECOVERS_HP, pet, 0, healed)
    end
    tell(player, string.format('%s strikes %s with Blood Saber for %d damage (+%d Pet HP)!',
        pet:getName(), target:getName(), dmg, healed))
    return dmg
end)

-- 423: Aegis Schism (Lv.75+): Heavy armor-shattering cleave (-25% DEF & -25 MDB) + Massive Enmity
bindAbility('aegis_schism', function(player, target, ability)
    return checkTankPetAbility(player, target, 75, 'Aegis Schism', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local scythe  = player:getSkillLevel(xi.skill.SCYTHE)
    local isDull  = (petId == PET_UNDEAD_DULLAHAN)
    local mult    = isDull and 1.50 or 1.15
    local baseDmg = math.max(50, math.floor(((lvl * 5.2) + (scythe * 1.1) + player:getStat(xi.mod.STR) * 1.5) * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    target:updateEnmityFromDamage(pet, dmg)
    addPetEnmity(target, pet, 1800, 4800)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = 25, duration = 60, origin = pet })
    target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, { power = 25, duration = 60, origin = pet })
    tell(player, string.format('%s rends %s with Aegis Schism for %d damage (DEF -25%% & MDB -25)!',
        pet:getName(), target:getName(), dmg))
    return dmg
end)

-- Fallback if Grim Reaping (408) is invoked directly via macro
bindAbility('grim_reaping', function(player, target, ability)
    return checkTankPetAbility(player, target, 10, 'Grim Reaping', false)
end, function(player, target, ability, action)
    tell(player, 'Select a Tank command from the Grim Reaping sub-menu (Grave Provoke, Black Cloud, Bone Aegis, Blood Saber, Aegis Schism).')
    return 0
end)

-----------------------------------
-- Grim Incantations Sub-Menu Skills (424-428: Party DPS & Dark Caster Commands)
-----------------------------------

-- 424: Necrotic Bolt (Lv.10+): Unresistable Dark bolt + Necrotic Brand (-DEF / -MDB for party DPS)
bindAbility('necrotic_bolt', function(player, target, ability)
    return checkCasterPetAbility(player, target, 10, 'Necrotic Bolt', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local intStat = player:getStat(xi.mod.INT)
    local mab     = getMasterMabMult(player)
    local isCorse = (petId == PET_UNDEAD_CORSE)
    local mult    = isCorse and 1.40 or 1.0
    local baseDmg = math.max(25, math.floor(((lvl * 4.2) + (intStat * 1.85)) * mab * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.MAGICAL)

    target:takeDamage(dmg, pet, xi.attackType.MAGICAL, xi.damageType.DARK)
    addPetEnmity(target, pet, 80, 200)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, dmg)
    end

    local shred = isCorse and 20 or 15
    target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = shred, duration = 60, origin = pet })
    target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, { power = shred, duration = 60, origin = pet })
    tell(player, string.format('%s fires Necrotic Bolt at %s for %d Dark damage (DEF -%d%% & MDB -%d)!',
        pet:getName(), target:getName(), dmg, shred, shred))
    return dmg
end)

-- 425: Covenant of Ash (Lv.20+): Party-wide Attack Boost, Magic Atk. Boost, and Haste (90s)
bindAbility('covenant_of_ash', function(player, target, ability)
    return checkCasterPetAbility(player, target, 20, 'Covenant of Ash', false)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil then
        return 0
    end
    local isCorse = (petId == PET_UNDEAD_CORSE)
    local atkPow  = isCorse and 20 or 15
    local mabPow  = isCorse and 20 or 15
    local haste   = isCorse and 1500 or 1000
    local members = getPartyInRange(player, pet, 20.0)

    for _, member in ipairs(members) do
        member:addStatusEffect(xi.effect.ATTACK_BOOST, { power = atkPow, duration = 90, origin = player })
        member:addStatusEffect(xi.effect.MAGIC_ATK_BOOST, { power = mabPow, duration = 90, origin = player })
        member:addStatusEffect(xi.effect.HASTE, { power = haste, duration = 90, origin = player })
    end
    tell(player, string.format('%s invokes Covenant of Ash on %d party member%s (+%d%% ATK, +%d MAB, +%d%% Haste)!',
        pet:getName(), #members, #members == 1 and '' or 's', atkPow, mabPow, math.floor(haste / 100)))
    return #members
end)

-- 426: Curse of the Fallen (Lv.35+): Target Evasion/Magic Evasion Down & Slow + Party Accuracy Boost
bindAbility('curse_of_the_fallen', function(player, target, ability)
    return checkCasterPetAbility(player, target, 35, 'Curse of the Fallen', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    addPetEnmity(target, pet, 120, 300)
    local isCorse = (petId == PET_UNDEAD_CORSE)
    local evaDown = isCorse and 35 or 25
    target:addStatusEffect(xi.effect.EVASION_DOWN, { power = evaDown, duration = 60, origin = pet })
    if xi.effect.MAGIC_EVASION_DOWN then
        target:addStatusEffect(xi.effect.MAGIC_EVASION_DOWN, { power = evaDown, duration = 60, origin = pet })
    end
    target:addStatusEffect(xi.effect.SLOW, { power = 2000, duration = 60, origin = pet })

    local members = getPartyInRange(player, pet, 20.0)
    local accPow  = isCorse and 25 or 18
    for _, member in ipairs(members) do
        member:addStatusEffect(xi.effect.ACCURACY_BOOST, { power = accPow, duration = 60, origin = player })
    end
    tell(player, string.format('%s hexes %s with Curse of the Fallen (EVA/MEVA -%d, Slow + Party ACC +%d)!',
        pet:getName(), target:getName(), evaDown, accPow))
    return 0
end)

-- 427: Soul Harvest (Lv.50+): Dark burst that siphons HP, MP, and +150 TP to the entire party
bindAbility('soul_harvest', function(player, target, ability)
    return checkCasterPetAbility(player, target, 50, 'Soul Harvest', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local intStat = player:getStat(xi.mod.INT)
    local mab     = getMasterMabMult(player)
    local isCorse = (petId == PET_UNDEAD_CORSE)
    local mult    = isCorse and 1.45 or 1.10
    local baseDmg = math.max(40, math.floor(((lvl * 4.8) + (intStat * 2.1)) * mab * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.MAGICAL)

    target:takeDamage(dmg, pet, xi.attackType.MAGICAL, xi.damageType.DARK)
    addPetEnmity(target, pet, 150, 350)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, dmg)
    end

    local members = getPartyInRange(player, pet, 20.0)
    local pct     = isCorse and 0.20 or 0.15
    local tpGain  = isCorse and 200 or 150
    for _, member in ipairs(members) do
        local rawHeal = math.max(20, math.floor(member:getMaxHP() * pct))
        local healed  = member:addHP(rawHeal)
        if
            (healed > 0 or member:getID() ~= player:getID()) and
            player.messagePublic and
            xi.msg and
            xi.msg.basic and
            xi.msg.basic.RECOVERS_HP
        then
            player:messagePublic(xi.msg.basic.RECOVERS_HP, member, 0, healed)
        end
        if member.getMaxMP and member:getMaxMP() > 0 then
            member:addMP(math.max(15, math.floor(member:getMaxMP() * pct)))
        end
        member:addTP(tpGain)
    end
    tell(player, string.format('%s reaps %s with Soul Harvest for %d Dark damage (Party +%d%% HP/MP & +%d TP)!',
        pet:getName(), target:getName(), dmg, math.floor(pct * 100), tpGain))
    return dmg
end)

-- 428: Danse Macabre (Lv.75+): Heavy Dark burst + Party Crit Rate (+15%) & Regain (+25 TP/tick)
bindAbility('danse_macabre', function(player, target, ability)
    return checkCasterPetAbility(player, target, 75, 'Danse Macabre', true)
end, function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end
    local lvl     = pet:getMainLvl()
    local intStat = player:getStat(xi.mod.INT)
    local mab     = getMasterMabMult(player)
    local isCorse = (petId == PET_UNDEAD_CORSE)
    local mult    = isCorse and 1.55 or 1.25
    local baseDmg = math.max(60, math.floor(((lvl * 5.8) + (intStat * 2.4)) * mab * mult))
    baseDmg       = scaleLevelGapDmg(pet, target, baseDmg)
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.MAGICAL)

    target:takeDamage(dmg, pet, xi.attackType.MAGICAL, xi.damageType.DARK)
    addPetEnmity(target, pet, 200, 450)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, dmg)
    end

    local members = getPartyInRange(player, pet, 20.0)
    local critPow = isCorse and 18 or 15
    local regain  = isCorse and 30 or 25
    for _, member in ipairs(members) do
        if xi.effect.POTENCY then
            member:addStatusEffect(xi.effect.POTENCY, { power = critPow, duration = 60, origin = player })
        end
        if xi.effect.REGAIN then
            member:addStatusEffect(xi.effect.REGAIN, { power = regain, tick = 3, duration = 60, origin = player })
        end
    end
    tell(player, string.format('%s unleashes Danse Macabre on %s for %d Dark damage (Party +%d%% Crit & +%d Regain)!',
        pet:getName(), target:getName(), dmg, critPow, regain))
    return dmg
end)

-- Fallback if Grim Incantations (409) is invoked directly via macro
bindAbility('grim_incantations', function(player, target, ability)
    return checkCasterPetAbility(player, target, 10, 'Grim Incantations', false)
end, function(player, target, ability, action)
    tell(player, 'Select a Caster/Party DPS command from the Grim Incantations sub-menu (Necrotic Bolt, Covenant of Ash, Curse of the Fallen, Soul Harvest, Danse Macabre).')
    return 0
end)

-----------------------------------
-- Modal Tank Thrall: 100% AoE/Conal Boss Immunity & 80% Cure (+100% Overheal) Forwarding
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
        if isNecromancer(master) and WARRIOR_PETS[defender:getPetID()] then
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
        if target ~= nil and isNecromancer(target) and isTankThrallActive(target) ~= nil and target.getHP then
            local preHp  = target:getHP() or 0
            local maxHp  = target:getMaxHP() or 0
            local res    = super(caster, target, spell)
            local healed = math.max(0, (target:getHP() or 0) - preHp)
            local pot    = math.max(0, (caster and caster.getMod and caster:getMod(xi.mod.CURE_POTENCY) or 0))
            local est    = math.floor(rawBase * (1 + pot / 100))
            if (target:getHP() or 0) >= maxHp then
                forwardCureToThrall(target, healed, math.max(healed, est))
            else
                forwardCureToThrall(target, healed, healed)
            end
            return res
        end
        return super(caster, target, spell)
    end)
end

-----------------------------------
-- Register BLM Necromancer Crystal
-----------------------------------
if xi.job and xi.job.BLM then
    spec.registerJob(xi.job.BLM, 'BLM',
    {
        {
            id          = 1,
            key         = NECRO_KEY,
            name        = 'Necromancer',
            role        = 'Scythe & Undead Summoner',
            icon        = 'onyx_tome',
            reqLevel    = 10,
            description = 'Scythe-wielding Black Mage who commands undead tank and ranged dark caster summons, drains life through weaponskills, and detonates thralls with Corpse Explosion.',
            highlights  =
            {
                'HP +10%, Scythe Skill raised to A+, and enhanced Occult Acumen.',
                'Undead Warrior & Dullahan (Tank Mode): Tier 6 -60% DMG Dealt (0.12x WS), 100% Thrall AoE/Conal boss immunity, 100% Master-to-Thrall single-target enmity transfer, and 80% Cure (+100% overheal) forwarding.',
                'Undead Mage & Corse (Caster Mode / No Pet): Tier 2 Hybrid -25% DMG Dealt (0.50x WS) & -20 Enmity; ranged Dark casters that empower party DPS via Grim Incantations.',
                'Harbinger\'s Drain: Scythe WSs heal Tank Thralls for 16/18/20/22% Max HP (clamp-proof) or Caster Thralls for 25-50% of WS damage.',
                'Dark Pact: While an undead summon is alive, gain Double Attack, Store TP, and Accuracy.',
                'Corpse Explosion: Implodes your summon onto your single engaged target for concentrated Dark damage without pulling nearby mobs.',
                'Grim Conversion: Converts MACC->ACC, MATT->ATT, Fast Cast->Haste, and Magic Burst Bonus->WSD (Elemental Celerity unchanged).',
            },
            extraAbilities = function(player)
                local lvl  = player ~= nil and player:getMainLvl() or 10
                local list =
                {
                    69, -- Fight (Pet Command)
                    70, -- Heel (Pet Command)
                    71, -- Leave (Pet Command)
                    72, -- Sic (Pet Command)
                    73, -- Stay (Pet Command)
                    ABIL_SUMMON_WARRIOR,
                    ABIL_SUMMON_MAGE,
                    ABIL_CORPSE_EXPLODE,
                    ABIL_GRIM_REAPING,
                    ABIL_GRIM_INCANT,
                    ABIL_GRAVE_PROVOKE,
                    ABIL_NECROTIC_BOLT,
                }
                if lvl >= 20 then
                    table.insert(list, ABIL_BLACK_CLOUD)
                    table.insert(list, ABIL_COVENANT_ASH)
                end
                if lvl >= 35 then
                    table.insert(list, ABIL_BONE_AEGIS)
                    table.insert(list, ABIL_CURSE_FALLEN)
                end
                if lvl >= 50 then
                    table.insert(list, ABIL_BLOOD_SABER)
                    table.insert(list, ABIL_SOUL_HARVEST)
                end
                if lvl >= 75 then
                    table.insert(list, ABIL_SUMMON_CORSE)
                    table.insert(list, ABIL_SUMMON_DULLAHAN)
                    table.insert(list, ABIL_AEGIS_SCHISM)
                    table.insert(list, ABIL_DANSE_MACABRE)
                end
                return list
            end,
            extraTraits = { TRAIT_HARBINGERS_DRAIN, TRAIT_DARK_PACT, TRAIT_GRIM_CONVERSION },
            mods = function(player)
                local lvl = player ~= nil and player:getMainLvl() or 10
                local scytheAPlus = lvl <= 50 and (6 + (lvl - 1) * 3)
                    or (lvl <= 60 and (153 + (lvl - 50) * 5))
                    or (lvl <= 70 and math.floor(203 + (lvl - 60) * 4.85))
                    or (251 + (lvl - 70) * 5)
                local out =
                {
                    { xi.mod.HPP,           10 },
                    { xi.mod.SCYTHE,        math.max(10, scytheAPlus) },
                    { xi.mod.OCCULT_ACUMEN, scaleTier(lvl, 25, 40, 55, 75) },
                }
                if isTankThrallActive(player) == nil then
                    table.insert(out, { xi.mod.ENMITY, -20 })
                end
                return out
            end,
            onApply = function(player)
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                attachNecroListeners(player)
                syncDarkPactMods(player)
                syncConversionMods(player)
            end,
            onRemove = function(player)
                detachNecroListeners(player)
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                if player ~= nil and player.hasPet and player:hasPet() then
                    local pet = player:getPet()
                    if pet ~= nil and UNDEAD_PETS[pet:getPetID()] and player.despawnPet then
                        player:despawnPet()
                    end
                end
                if player ~= nil then
                    local mainItem = player:getEquippedItem(xi.slot.MAIN)
                    if
                        mainItem ~= nil and
                        mainItem.getSkillType and
                        mainItem:getSkillType() == xi.skill.SCYTHE and
                        not VANILLA_BLM_SCYTHES[mainItem:getID()]
                    then
                        player:unequipItem(xi.slot.MAIN)
                    end
                end
            end,
        },
    })
end

return m

