-----------------------------------
-- OverlordsXI Black Mage Crystal Specs
-- Registers the Necromancer (Scythe & Undead Summoner) BLM soul crystal,
-- passive stats (HP+10%, A+ Scythe Skill, Occult Acumen), Undead Summons,
-- Corpse Explosion, Harbinger's Drain, Dark Pact, and Pet Commands.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/pets')
require('scripts/globals/player')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/combat/physical_utilities')
-----------------------------------
local m = Module:new('overlords_blm_specs')

local spec = xi.overlords.spec

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
    local party   = player.getParty and player:getParty() or nil
    if party ~= nil then
        for _, member in ipairs(party) do
            if
                member ~= nil and
                member:isAlive() and
                member:getZoneID() == player:getZoneID() and
                anchor:checkDistance(member) <= maxDist
            then
                seen[member:getID()] = true
                table.insert(members, member)
            end
        end
    end
    if not seen[player:getID()] and player:isAlive() then
        table.insert(members, player)
    end
    return members
end

-----------------------------------
-- Dark Pact (DA, Store TP, Acc while Undead Summon is alive)
-----------------------------------
local function clearDarkPactMods(player)
    if player == nil then
        return
    end
    local prevDa  = player:getLocalVar('OX_NECRO_PACT_DA')
    local prevStp = player:getLocalVar('OX_NECRO_PACT_STP')
    local prevAcc = player:getLocalVar('OX_NECRO_PACT_ACC')
    if prevDa > 0 then
        player:delMod(xi.mod.DOUBLE_ATTACK, prevDa)
        player:setLocalVar('OX_NECRO_PACT_DA', 0)
    end
    if prevStp > 0 then
        player:delMod(xi.mod.STORETP, prevStp)
        player:setLocalVar('OX_NECRO_PACT_STP', 0)
    end
    if prevAcc > 0 then
        player:delMod(xi.mod.ACC, prevAcc)
        player:setLocalVar('OX_NECRO_PACT_ACC', 0)
    end
end

local function syncDarkPactMods(player)
    if player == nil or not player:isPC() then
        return
    end
    clearDarkPactMods(player)
    if not isNecromancer(player) then
        return
    end
    local pet = getUndeadPet(player)
    if pet == nil or not pet:isAlive() then
        return
    end

    local lvl = player:getMainLvl()
    local da  = scaleTier(lvl, 8, 12, 16, 20)
    local stp = scaleTier(lvl, 10, 15, 20, 25)
    local acc = scaleTier(lvl, 10, 20, 35, 50)

    player:addMod(xi.mod.DOUBLE_ATTACK, da)
    player:addMod(xi.mod.STORETP, stp)
    player:addMod(xi.mod.ACC, acc)
    player:setLocalVar('OX_NECRO_PACT_DA', da)
    player:setLocalVar('OX_NECRO_PACT_STP', stp)
    player:setLocalVar('OX_NECRO_PACT_ACC', acc)
end

-----------------------------------
-- Grim Conversion (Lv.10+: MACC->ACC, MATT->ATT, FASTCAST->Haste, MB Bonus->WSD)
-- Elemental Celerity (xi.mod.ELEMENTAL_CELERITY) is left untouched.
-----------------------------------
local MOD_MB_BONUS = xi.mod and (xi.mod.MAG_BURST_BONUS or xi.mod.MAGIC_BURST_BONUS) or nil

local function clearConversionMods(player)
    if player == nil then
        return
    end
    local cMacc = player:getLocalVar('OX_NECRO_CONV_MACC')
    local cMatt = player:getLocalVar('OX_NECRO_CONV_MATT')
    local cFc   = player:getLocalVar('OX_NECRO_CONV_FC')
    local cMbb  = player:getLocalVar('OX_NECRO_CONV_MBB')

    if cMacc > 0 then
        player:delMod(xi.mod.ACC, cMacc)
        player:addMod(xi.mod.MACC, cMacc)
        player:setLocalVar('OX_NECRO_CONV_MACC', 0)
    end
    if cMatt > 0 then
        player:delMod(xi.mod.ATT, cMatt)
        player:addMod(xi.mod.MATT, cMatt)
        player:setLocalVar('OX_NECRO_CONV_MATT', 0)
    end
    if cFc > 0 then
        player:delMod(xi.mod.HASTE_ABILITY, cFc * 100)
        player:addMod(xi.mod.FASTCAST, cFc)
        player:setLocalVar('OX_NECRO_CONV_FC', 0)
    end
    if cMbb > 0 and MOD_MB_BONUS ~= nil then
        player:delMod(xi.mod.ALL_WSDMG_ALL_HITS, cMbb)
        player:addMod(MOD_MB_BONUS, cMbb)
        player:setLocalVar('OX_NECRO_CONV_MBB', 0)
    end
end

local function syncConversionMods(player)
    if player == nil or not player:isPC() then
        return
    end
    clearConversionMods(player)
    if not isNecromancer(player) or player:getMainLvl() < 10 then
        return
    end

    local macc = math.max(0, player:getMod(xi.mod.MACC))
    local matt = math.max(0, player:getMod(xi.mod.MATT))
    local fc   = math.max(0, player:getMod(xi.mod.FASTCAST))
    local mbb  = MOD_MB_BONUS ~= nil and math.max(0, player:getMod(MOD_MB_BONUS)) or 0

    if macc > 0 then
        player:delMod(xi.mod.MACC, macc)
        player:addMod(xi.mod.ACC, macc)
        player:setLocalVar('OX_NECRO_CONV_MACC', macc)
    end
    if matt > 0 then
        player:delMod(xi.mod.MATT, matt)
        player:addMod(xi.mod.ATT, matt)
        player:setLocalVar('OX_NECRO_CONV_MATT', matt)
    end
    if fc > 0 then
        player:delMod(xi.mod.FASTCAST, fc)
        player:addMod(xi.mod.HASTE_ABILITY, fc * 100)
        player:setLocalVar('OX_NECRO_CONV_FC', fc)
    end
    if mbb > 0 and MOD_MB_BONUS ~= nil then
        player:delMod(MOD_MB_BONUS, mbb)
        player:addMod(xi.mod.ALL_WSDMG_ALL_HITS, mbb)
        player:setLocalVar('OX_NECRO_CONV_MBB', mbb)
    end
end

-----------------------------------
-- Harbinger's Drain (WS Damage heals active Undead Pet)
-----------------------------------
local function attachNecroListeners(player)
    if player == nil or not player:isPC() then
        return
    end

    player:removeListener('OX_NECRO_WS_DRAIN')
    player:addListener('WEAPONSKILL_USE', 'OX_NECRO_WS_DRAIN', function(actor, target, _ws, tp, _action, dmg)
        if not isNecromancer(actor) or (dmg or 0) <= 0 then
            return
        end
        local pet = getUndeadPet(actor)
        if pet == nil or not pet:isAlive() then
            return
        end
        local lvl = actor:getMainLvl()
        local pct = lvl >= 75 and 0.50 or (lvl >= 50 and 0.35 or 0.25)
        local heal = math.max(1, math.floor(dmg * pct))
        local missing = math.max(0, pet:getMaxHP() - pet:getHP())
        local actual = math.min(heal, missing)
        if actual > 0 then
            pet:addHP(actual)
            tell(actor, string.format("Harbinger's Drain restores %d HP to %s.", actual, pet:getName()))
        end
    end)

    player:removeListener('OX_NECRO_PET_CHECK')
    player:addListener('COMBAT_TICK', 'OX_NECRO_PET_CHECK', function(actor)
        local pet = getUndeadPet(actor)
        if pet == nil or not pet:isAlive() then
            if actor:getLocalVar('OX_NECRO_PACT_DA') > 0 then
                clearDarkPactMods(actor)
            end
        else
            -- Auto-assist master's battle target when not already engaged or in Stay
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
        syncConversionMods(actor)
    end)

    player:removeListener('OX_NECRO_EQUIP_SYNC')
    player:addListener('ITEM_EQUIP', 'OX_NECRO_EQUIP_SYNC', function(actor)
        syncConversionMods(actor)
    end)
end

local function detachNecroListeners(player)
    if player == nil or not player:isPC() then
        return
    end
    player:removeListener('OX_NECRO_WS_DRAIN')
    player:removeListener('OX_NECRO_PET_CHECK')
    player:removeListener('OX_NECRO_EQUIP_SYNC')
    clearDarkPactMods(player)
    clearConversionMods(player)
end

-- Restrict non-vanilla Scythes to BLM Necromancer spec only
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        player:removeListener('OX_BLM_SCYTHE_GATE')
        player:addListener('ITEM_EQUIP', 'OX_BLM_SCYTHE_GATE', function(actor, item, slot)
            if
                slot == xi.slot.MAIN and
                actor:getMainJob() == xi.job.BLM and
                item ~= nil and
                item.getSkillType and
                item:getSkillType() == xi.skill.SCYTHE and
                not VANILLA_BLM_SCYTHES[item:getID()] and
                not isNecromancer(actor)
            then
                actor:unequipItem(xi.slot.MAIN)
                tell(actor, 'Only a BLM with the Necromancer crystal can wield that Scythe.')
            end
        end)
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
    syncDarkPactMods(player)
    if player:hasPet() then
        local pet = player:getPet()
        applyUndeadPetRoleMods(pet, petId)
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
-- Corpse Explosion (407): Detonate Undead Pet for Dark AoE Damage
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
    return 0, 0
end, function(player, target, ability)
    if target ~= nil and target:getID() ~= player:getID() then
        return 0
    end
    local pet, petId = getUndeadPet(player)
    if pet == nil then
        return 0
    end

    local petHp    = pet:getHP()
    local petMaxHp = math.max(1, pet:getMaxHP())
    local hpRatio  = math.min(1.0, math.max(0.25, petHp / petMaxHp))
    local lvl      = player:getMainLvl()
    local intStat  = player:getStat(xi.mod.INT)
    local mab      = getMasterMabMult(player)
    local tierMult = (petId == PET_UNDEAD_CORSE or petId == PET_UNDEAD_DULLAHAN) and 1.35 or 1.0

    local baseDmg = math.floor(((lvl * 6.5) + (intStat * 2.2) + (petHp * 0.35)) * hpRatio * mab * tierMult)
    baseDmg = math.max(25, baseDmg)

    local zone = player:getZone()
    local hits = 0

    if zone ~= nil and zone.getMobs then
        for _, mob in ipairs(zone:getMobs()) do
            if
                mob ~= nil and
                mob:isMob() and
                mob:isAlive() and
                mob:getID() ~= pet:getID() and
                mob:getMaster() == nil and
                mob:getAllegiance() ~= player:getAllegiance() and
                not mob:getUntargetable() and
                pet:checkDistance(mob) <= 10.0
            then
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
                hits = hits + 1
            end
        end
    end

    tell(player, string.format('Corpse Explosion detonates %s for ~%d Dark damage (%d target%s)!',
        pet:getName(), baseDmg, hits, hits == 1 and '' or 's'))

    player:despawnPet()
    if player.recalculateAbilitiesTable then
        player:recalculateAbilitiesTable()
    end
    clearDarkPactMods(player)
    return baseDmg
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

-- 420: Black Cloud (Lv.20+): 10y Dark AoE around pet + Blind + AoE Enmity
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
    local zone    = player:getZone()
    local hits    = 0
    local mainDmg = 0

    if zone ~= nil and zone.getMobs then
        for _, mob in ipairs(zone:getMobs()) do
            if
                mob ~= nil and
                mob:isMob() and
                mob:isAlive() and
                mob:getID() ~= pet:getID() and
                mob:getMaster() == nil and
                mob:getAllegiance() ~= player:getAllegiance() and
                not mob:getUntargetable() and
                pet:checkDistance(mob) <= 10.0
            then
                local scaled = scaleLevelGapDmg(pet, mob, baseDmg)
                local dmg    = utils.handleStoneskin(mob, scaled, xi.attackType.MAGICAL)
                mob:takeDamage(dmg, pet, xi.attackType.MAGICAL, xi.damageType.DARK)
                addPetEnmity(mob, pet, 900, 2400)
                mob:addStatusEffect(xi.effect.BLINDNESS, { power = isDull and 35 or 25, duration = 60, origin = pet })
                if mob:getID() == target:getID() then
                    mainDmg = dmg
                end
                hits = hits + 1
            end
        end
    end

    if mainDmg > 0 and action and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, mainDmg)
    end
    tell(player, string.format('%s engulfs %d foe%s in Black Cloud (~%d Dark damage + Blind + AoE Enmity)!',
        pet:getName(), hits, hits == 1 and '' or 's', baseDmg))
    return mainDmg
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

    local healed = math.min(dmg, math.max(0, pet:getMaxHP() - pet:getHP()))
    if healed > 0 then
        pet:addHP(healed)
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
    target:updateEnmityFromDamage(pet, dmg)
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
    target:updateEnmityFromDamage(pet, dmg)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.MAGICAL, dmg)
    end

    local members = getPartyInRange(player, pet, 20.0)
    local pct     = isCorse and 0.20 or 0.15
    local tpGain  = isCorse and 200 or 150
    for _, member in ipairs(members) do
        member:addHP(math.max(20, math.floor(member:getMaxHP() * pct)))
        member:addMP(math.max(15, math.floor(member:getMaxMP() * pct)))
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
    target:updateEnmityFromDamage(pet, dmg)
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
                'Undead Warrior & Dullahan: Frontline Tank summons with Grim Reaping sub-menu (Grave Provoke, Black Cloud, Bone Aegis, Blood Saber, Aegis Schism).',
                'Undead Mage & Corse: Ranged never-missing Dark casters that stand back from the mob and empower party DPS via Grim Incantations.',
                'Harbinger\'s Drain: Weaponskill damage heals your active undead summon.',
                'Dark Pact: While an undead summon is alive, gain Double Attack, Store TP, and Accuracy.',
                'Corpse Explosion: Detonate your summon for massive Dark AoE damage.',
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
                return
                {
                    { xi.mod.HPP,           10 },
                    { xi.mod.SCYTHE,        math.max(10, scytheAPlus) },
                    { xi.mod.OCCULT_ACUMEN, scaleTier(lvl, 25, 40, 55, 75) },
                }
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

