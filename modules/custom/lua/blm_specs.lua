-----------------------------------
-- OverlordsXI Black Mage Crystal Specs
-- Registers the Necromancer (Scythe & Undead Summoner) BLM soul crystal,
-- passive stats (HP+10%, A+ Scythe Skill, Occult Acumen), Undead Summons,
-- Corpse Explosion, Harbinger's Drain, Dark Pact, and Pet Commands.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/pets')
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

xi.petId = xi.petId or {}
xi.petId.UNDEAD_WARRIOR  = PET_UNDEAD_WARRIOR
xi.petId.UNDEAD_MAGE     = PET_UNDEAD_MAGE
xi.petId.UNDEAD_CORSE    = PET_UNDEAD_CORSE
xi.petId.UNDEAD_DULLAHAN = PET_UNDEAD_DULLAHAN

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.summon_undead_warrior = xi.actions.abilities.summon_undead_warrior or {}
xi.actions.abilities.summon_undead_mage    = xi.actions.abilities.summon_undead_mage or {}
xi.actions.abilities.corpse_explosion      = xi.actions.abilities.corpse_explosion or {}
xi.actions.abilities.grim_reaping          = xi.actions.abilities.grim_reaping or {}
xi.actions.abilities.grim_incantations     = xi.actions.abilities.grim_incantations or {}
xi.actions.abilities.summon_corse          = xi.actions.abilities.summon_corse or {}
xi.actions.abilities.summon_dullahan       = xi.actions.abilities.summon_dullahan or {}

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
        if actor:getLocalVar('OX_NECRO_PACT_DA') > 0 then
            local pet = getUndeadPet(actor)
            if pet == nil or not pet:isAlive() then
                clearDarkPactMods(actor)
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
m:addOverride('xi.server.onPlayerLogin', function(player)
    super(player)
    if player ~= nil and player:isPC() then
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

local function doSummon(player, petId, abilityId)
    xi.pet.spawnPet(player, petId)
    syncDarkPactMods(player)
    return abilityId
end

m:addOverride('xi.actions.abilities.summon_undead_warrior.onAbilityCheck', function(player, target, ability)
    return checkSummon(player, 10, 'Summon Undead Warrior')
end)
m:addOverride('xi.actions.abilities.summon_undead_warrior.onUseAbility', function(player, target, ability)
    return doSummon(player, PET_UNDEAD_WARRIOR, ABIL_SUMMON_WARRIOR)
end)

m:addOverride('xi.actions.abilities.summon_undead_mage.onAbilityCheck', function(player, target, ability)
    return checkSummon(player, 10, 'Summon Undead Mage')
end)
m:addOverride('xi.actions.abilities.summon_undead_mage.onUseAbility', function(player, target, ability)
    return doSummon(player, PET_UNDEAD_MAGE, ABIL_SUMMON_MAGE)
end)

m:addOverride('xi.actions.abilities.summon_corse.onAbilityCheck', function(player, target, ability)
    return checkSummon(player, 75, 'Summon Corse')
end)
m:addOverride('xi.actions.abilities.summon_corse.onUseAbility', function(player, target, ability)
    return doSummon(player, PET_UNDEAD_CORSE, ABIL_SUMMON_CORSE)
end)

m:addOverride('xi.actions.abilities.summon_dullahan.onAbilityCheck', function(player, target, ability)
    return checkSummon(player, 75, 'Summon Dullahan')
end)
m:addOverride('xi.actions.abilities.summon_dullahan.onUseAbility', function(player, target, ability)
    return doSummon(player, PET_UNDEAD_DULLAHAN, ABIL_SUMMON_DULLAHAN)
end)

-----------------------------------
-- Corpse Explosion (407): Detonate Undead Pet for Dark AoE Damage
-----------------------------------
m:addOverride('xi.actions.abilities.corpse_explosion.onAbilityCheck', function(player, target, ability)
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
end)

m:addOverride('xi.actions.abilities.corpse_explosion.onUseAbility', function(player, target, ability)
    local pet, petId = getUndeadPet(player)
    if pet == nil then
        return 0
    end

    local petHp    = pet:getHP()
    local petMaxHp = math.max(1, pet:getMaxHP())
    local hpRatio  = math.clamp(petHp / petMaxHp, 0.25, 1.0)
    local lvl      = player:getMainLvl()
    local intStat  = player:getStat(xi.mod.INT)
    local mab      = 1.0 + (player:getMod(xi.mod.MATT) / 100.0)
    local tierMult = (petId == PET_UNDEAD_CORSE or petId == PET_UNDEAD_DULLAHAN) and 1.35 or 1.0

    local baseDmg = math.floor(((lvl * 6.5) + (intStat * 2.2) + (petHp * 0.35)) * hpRatio * mab * tierMult)
    baseDmg = math.max(25, baseDmg)

    local petPos = pet:getPos()
    local zone   = player:getZone()
    local hits   = 0

    if zone ~= nil then
        local nearby = pet:getEntitiesInRange(10.0)
        for _, mob in ipairs(nearby) do
            if
                mob ~= nil and
                mob:isMob() and
                mob:isAlive() and
                player:canAttack(mob)
            then
                local dmg = utils.handleStoneskin(mob, baseDmg, xi.attackType.MAGICAL)
                mob:takeDamage(dmg, player, xi.attackType.MAGICAL, xi.damageType.DARK)
                mob:updateEnmityFromDamage(player, dmg)
                if not mob:hasStatusEffect(xi.effect.BIO) then
                    mob:addStatusEffect(xi.effect.BIO, math.max(2, math.floor(lvl / 8)), 3, 30)
                end
                hits = hits + 1
            end
        end
    end

    tell(player, string.format('Corpse Explosion detonates %s for ~%d Dark damage (%d target%s)!',
        pet:getName(), baseDmg, hits, hits == 1 and '' or 's'))

    player:despawnPet()
    clearDarkPactMods(player)
    return ABIL_CORPSE_EXPLODE
end)

-----------------------------------
-- Grim Reaping (408): Warrior / Dullahan Physical Dark Cleave
-----------------------------------
m:addOverride('xi.actions.abilities.grim_reaping.onAbilityCheck', function(player, target, ability)
    if not isNecromancer(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet, petId = getUndeadPet(player)
    if pet == nil or not pet:isAlive() or not WARRIOR_PETS[petId] then
        tell(player, 'Grim Reaping requires an active Undead Warrior or Dullahan.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if target == nil or not target:isMob() or not target:isAlive() then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.grim_reaping.onUseAbility', function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end

    if not pet:isEngaged() and pet.engage then
        pet:engage(target:getTargID())
    end

    local lvl      = pet:getMainLvl()
    local scythe   = player:getSkillLevel(xi.skill.SCYTHE)
    local isDull   = (petId == PET_UNDEAD_DULLAHAN)
    local mult     = isDull and 1.45 or 1.0
    local baseDmg  = math.max(20, math.floor(((lvl * 4.5) + (scythe * 0.9) + player:getStat(xi.mod.STR)) * mult))
    local dmg      = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    target:updateEnmityFromDamage(pet, dmg)
    action:recordDamage(target, xi.attackType.PHYSICAL, dmg)

    if isDull then
        target:addStatusEffect(xi.effect.DEFENSE_DOWN, 15, 0, 30)
    end

    tell(player, string.format('%s unleashes Grim Reaping on %s for %d damage!', pet:getName(), target:getName(), dmg))
    return ABIL_GRIM_REAPING
end)

-----------------------------------
-- Grim Incantations (409): Mage / Corse Dark Nuke + Drain/Aspir
-----------------------------------
m:addOverride('xi.actions.abilities.grim_incantations.onAbilityCheck', function(player, target, ability)
    if not isNecromancer(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet, petId = getUndeadPet(player)
    if pet == nil or not pet:isAlive() or not MAGE_PETS[petId] then
        tell(player, 'Grim Incantations requires an active Undead Mage or Corse.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if target == nil or not target:isMob() or not target:isAlive() then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.grim_incantations.onUseAbility', function(player, target, ability, action)
    local pet, petId = getUndeadPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end

    if not pet:isEngaged() and pet.engage then
        pet:engage(target:getTargID())
    end

    local lvl     = pet:getMainLvl()
    local intStat = player:getStat(xi.mod.INT)
    local mab     = 1.0 + (player:getMod(xi.mod.MATT) / 100.0)
    local isCorse = (petId == PET_UNDEAD_CORSE)
    local mult    = isCorse and 1.40 or 1.0
    local baseDmg = math.max(20, math.floor(((lvl * 4.0) + (intStat * 1.8)) * mab * mult))
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.MAGICAL)

    target:takeDamage(dmg, pet, xi.attackType.MAGICAL, xi.damageType.DARK)
    target:updateEnmityFromDamage(pet, dmg)
    action:recordDamage(target, xi.attackType.MAGICAL, dmg)

    local mpDrain = math.max(5, math.floor(dmg * 0.12))
    player:addMP(mpDrain)
    pet:addHP(math.max(10, math.floor(dmg * 0.25)))

    if isCorse then
        target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, 15, 0, 30)
    end

    tell(player, string.format('%s casts Grim Incantations on %s for %d Dark damage (+%d MP)!',
        pet:getName(), target:getName(), dmg, mpDrain))
    return ABIL_GRIM_INCANT
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
            description = 'Scythe-wielding Black Mage who commands undead summons, drains life through weaponskills, and detonates fallen thralls with Corpse Explosion.',
            highlights  =
            {
                'HP +10%, Scythe Skill raised to A+, and enhanced Occult Acumen.',
                'Unlocks Summon Undead Warrior & Summon Undead Mage (Lv.10+), plus Corse & Dullahan (Lv.75+).',
                'Harbinger\'s Drain: Weaponskill damage heals your active undead summon.',
                'Dark Pact: While an undead summon is alive, gain Double Attack, Store TP, and Accuracy.',
                'Corpse Explosion: Detonate your summon for massive Dark AoE damage.',
                'Grim Reaping & Grim Incantations: Command Warrior/Dullahan cleaves or Mage/Corse dark bursts.',
                'Grim Conversion: Converts MACC->ACC, MATT->ATT, Fast Cast->Haste, and Magic Burst Bonus->WSD (Elemental Celerity unchanged).',
            },
            extraAbilities = function(player)
                local list =
                {
                    ABIL_SUMMON_WARRIOR,
                    ABIL_SUMMON_MAGE,
                    ABIL_CORPSE_EXPLODE,
                    ABIL_GRIM_REAPING,
                    ABIL_GRIM_INCANT,
                }
                if player ~= nil and player:getMainLvl() >= 75 then
                    table.insert(list, ABIL_SUMMON_CORSE)
                    table.insert(list, ABIL_SUMMON_DULLAHAN)
                end
                return list
            end,
            extraTraits = { TRAIT_HARBINGERS_DRAIN, TRAIT_DARK_PACT, TRAIT_GRIM_CONVERSION },
            mods = function(player)
                local lvl = player ~= nil and player:getMainLvl() or 10
                return
                {
                    { xi.mod.HPP,           10 },
                    { xi.mod.SCYTHE,        math.max(10, math.floor(lvl * 0.95)) },
                    { xi.mod.OCCULT_ACUMEN, scaleTier(lvl, 25, 40, 55, 75) },
                }
            end,
            onApply = function(player)
                attachNecroListeners(player)
                syncDarkPactMods(player)
                syncConversionMods(player)
            end,
            onRemove = function(player)
                detachNecroListeners(player)
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
