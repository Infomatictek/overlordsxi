-----------------------------------
-- SoulspireXI Samurai Crystal Specs
-- Registers the three Samurai (job 12) Soul Crystal specializations:
--   1. Ronin (RON)           : Mushin Seigan, Mind's Eye & Stagger Tank (Great Katana)
--   2. Imperial Archer (IMP) : Tenzen's "Oisoya!" Bow & Blade Skirmisher (Bow / Great Katana)
--   3. Warlord (WRL)         : Cursed Onimaru & Iaijutsu Tactical Support (Great Katana)
--
-- Weapon choice remains open (no forced unequipping), while spec passives,
-- procs, and ability enhancements dynamically require Great Katana and/or Bow.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/combat/physical_hit_rate')
require('scripts/combat/physical_utilities')
require('scripts/combat/ranged_utilities')
require('scripts/combat/skillchain')
require('scripts/globals/job_utils/samurai')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('soulspire_sam_specs')

local spec = xi.soulspire.spec

xi.soulspire          = xi.soulspire or {}
xi.soulspire.samSpecs = xi.soulspire.samSpecs or {}
local samSpecs        = xi.soulspire.samSpecs

local RONIN_KEY           = 'ronin'
local IMPERIAL_ARCHER_KEY = 'imperialarcher'
local WARLORD_KEY         = 'warlord'

-- Custom Trait IDs (158-160; client display IDs 1694-1696)
local TRAIT_RONIN_MUSHIN     = 158
local TRAIT_IMP_OISOYA       = 159
local TRAIT_WARLORD_IAIJUTSU = 160

-- Custom Ability IDs
--   438: Oisoya Shot (client display ID 950, recastId 215)
--   453: Onimaru Tithe (client display ID 965, recastId 151)
local ABIL_OISOYA_SHOT   = 438
local ABIL_ONIMARU_TITHE = 453

-- Native SAM Ability IDs
local ABIL_MEIKYO_SHISUI  = 27
local ABIL_THIRD_EYE      = 62
local ABIL_MEDITATE       = 63
local ABIL_WARDING_CIRCLE = 64
local ABIL_SHIKIKOYO      = 167
local ABIL_BLADE_BASH     = 168
local ABIL_HASSO          = 173
local ABIL_SEIGAN         = 174
local ABIL_SEKKANOKI      = 230
local ABIL_SENGIKORI      = 258
local ABIL_HAMANOHA       = 287
local ABIL_HAGAKURE       = 288
local ABIL_KONZEN_ITTAI   = 320

-- Custom Status Effect IDs (837-841; registered in patch 0024)
local EFFECT_RONIN_STAGGER    = 837
local EFFECT_IMP_DRAWN_OISOYA = 838
local EFFECT_IMP_COSMIC_BRAND = 839
local EFFECT_WARLORD_NOTO     = 840
local EFFECT_WARLORD_ASHURA   = 841

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.OISOYA_SHOT   = ABIL_OISOYA_SHOT
xi.jobAbility.ONIMARU_TITHE = ABIL_ONIMARU_TITHE

xi.effect = xi.effect or {}
xi.effect.RONIN_STAGGER    = EFFECT_RONIN_STAGGER
xi.effect.IMP_DRAWN_OISOYA = EFFECT_IMP_DRAWN_OISOYA
xi.effect.IMP_COSMIC_BRAND = EFFECT_IMP_COSMIC_BRAND
xi.effect.WARLORD_NOTO     = EFFECT_WARLORD_NOTO
xi.effect.WARLORD_ASHURA   = EFFECT_WARLORD_ASHURA

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.oisoya_shot   = xi.actions.abilities.oisoya_shot or {}
xi.actions.abilities.onimaru_tithe = xi.actions.abilities.onimaru_tithe or {}

xi.effects = xi.effects or {}
xi.effects.ronin_stagger    = xi.effects.ronin_stagger or {}
xi.effects.imp_drawn_oisoya = xi.effects.imp_drawn_oisoya or {}
xi.effects.imp_cosmic_brand = xi.effects.imp_cosmic_brand or {}
xi.effects.warlord_noto     = xi.effects.warlord_noto or {}
xi.effects.warlord_ashura   = xi.effects.warlord_ashura or {}

-- Fallback onto self-only RUN status slots (registered in patch 0011) if xi_map.exe
-- has not yet been rebuilt with patch 0024 (MAX_EFFECTID 848).
local FALLBACK_EFFECT_MAP =
{
    [EFFECT_RONIN_STAGGER]    = 821, -- inquisitor_battuta
    [EFFECT_IMP_DRAWN_OISOYA] = 824, -- spellblade_edgeflare
    [EFFECT_IMP_COSMIC_BRAND] = 827, -- spellblade_conduction
    [EFFECT_WARLORD_NOTO]     = 823, -- inquisitor_converge
    [EFFECT_WARLORD_ASHURA]   = 828, -- spellblade_ascendance
}

local weaponModStateByChar   = {}
local pendingEffectMods      = {}
local pendingWardMods        = {}
local wsConsumeCache         = {}
local wrlPartyBuffState      = {}
local wrlTitheLifestealExpiry = {}

local WARLORD_AURA_RADIUS = 15.0

local function getPartyMembersInRange(player, range)
    local out = {}
    if player == nil or not player.getPartyWithTrusts then
        if player ~= nil then
            table.insert(out, player)
        end
        return out
    end

    local zoneId  = player.getZoneID and player:getZoneID() or 0
    local members = player:getPartyWithTrusts()
    if type(members) ~= 'table' or #members == 0 then
        table.insert(out, player)
        return out
    end

    local maxRange = range or WARLORD_AURA_RADIUS
    for _, member in ipairs(members) do
        if member ~= nil and (not member.isAlive or member:isAlive()) then
            local sameZone = (not member.getZoneID) or member:getZoneID() == zoneId
            if sameZone and (member:getID() == player:getID() or player:checkDistance(member) <= maxRange) then
                table.insert(out, member)
            end
        end
    end
    return out
end

local function clearWrlPartyModSlot(memberId, slotKey)
    local bySlot = wrlPartyBuffState[memberId]
    if type(bySlot) ~= 'table' then
        return
    end
    local entry = bySlot[slotKey]
    if entry ~= nil then
        local ent = entry.entity
        if ent ~= nil and ent.delMod then
            for _, pair in ipairs(entry.mods or {}) do
                if pair[1] ~= nil and pair[2] ~= 0 then
                    pcall(function() ent:delMod(pair[1], pair[2]) end)
                end
            end
        end
        bySlot[slotKey] = nil
    end
    if next(bySlot) == nil then
        wrlPartyBuffState[memberId] = nil
    end
end

local function applyWrlPartyModSlot(member, slotKey, modPairs, durationSec, ownerId)
    if member == nil or not member.getID or not member.addMod then
        return
    end
    local memberId = member:getID()
    clearWrlPartyModSlot(memberId, slotKey)

    local applied = {}
    for _, pair in ipairs(modPairs or {}) do
        if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
            member:addMod(pair[1], pair[2])
            table.insert(applied, { pair[1], pair[2] })
        end
    end

    wrlPartyBuffState[memberId] = wrlPartyBuffState[memberId] or {}
    wrlPartyBuffState[memberId][slotKey] =
    {
        entity    = member,
        mods      = applied,
        expiresAt = (durationSec ~= nil and durationSec > 0) and (os.time() + durationSec) or nil,
        ownerId   = ownerId,
    }
end

local function clearAllWrlOwnerAuras(ownerId, slotFilter)
    if ownerId == nil then
        return
    end
    for memberId, bySlot in pairs(wrlPartyBuffState) do
        for slotKey, entry in pairs(bySlot) do
            if entry.ownerId == ownerId and (slotFilter == nil or slotKey == slotFilter) then
                clearWrlPartyModSlot(memberId, slotKey)
            end
        end
    end
end

local function expireWrlTimedPartySlots()
    local now = os.time()
    for memberId, bySlot in pairs(wrlPartyBuffState) do
        for slotKey, entry in pairs(bySlot) do
            if entry.expiresAt ~= nil and now >= entry.expiresAt then
                clearWrlPartyModSlot(memberId, slotKey)
            end
        end
    end
end

local function attachWarlordTitheLifesteal(member, durationSec)
    if member == nil or not member.getID or not member.addListener then
        return
    end
    local memberId = member:getID()
    wrlTitheLifestealExpiry[memberId] = os.time() + (durationSec or 12)

    local function onHit(actor, target, action)
        if actor == nil or target == nil or action == nil then
            return
        end
        local aid = actor.getID and actor:getID() or 0
        if os.time() > (wrlTitheLifestealExpiry[aid] or 0) then
            wrlTitheLifestealExpiry[aid] = nil
            if actor.removeListener then
                actor:removeListener('OX_WRL_TITHE_ATK')
                actor:removeListener('OX_WRL_TITHE_RNG')
            end
            return
        end
        if target.isUndead and target:isUndead() then
            return
        end
        local dmg = action.getParam and (action:getParam(target:getID()) or 0) or 0
        if dmg > 0 and actor.addHP then
            actor:addHP(math.max(1, math.floor(dmg * 0.15)))
        end
    end

    if member.removeListener then
        member:removeListener('OX_WRL_TITHE_ATK')
        member:removeListener('OX_WRL_TITHE_RNG')
    end
    member:addListener('ATTACK', 'OX_WRL_TITHE_ATK', onHit)
    member:addListener('RANGE_STATE_EXIT', 'OX_WRL_TITHE_RNG', onHit)
end

-----------------------------------
-- Scaling & Equipment Helpers
-----------------------------------
local function tellSam(player, message)
    if player ~= nil and player.printToPlayer and xi.msg and xi.msg.channel then
        player:printToPlayer(message, xi.msg.channel.SYSTEM_3)
    end
end

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

local function isSamSpec(entity, specKey)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.SAM
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.SAM, specKey)
end

local function getActiveSamSpecKey(player)
    if
        player == nil or
        not player.isPC or
        not player:isPC() or
        player:getMainJob() ~= xi.job.SAM
    then
        return nil
    end

    spec.ensureUpToDate(player)
    if spec.is(player, xi.job.SAM, RONIN_KEY) then
        return RONIN_KEY
    elseif spec.is(player, xi.job.SAM, IMPERIAL_ARCHER_KEY) then
        return IMPERIAL_ARCHER_KEY
    elseif spec.is(player, xi.job.SAM, WARLORD_KEY) then
        return WARLORD_KEY
    end
    return nil
end

local function isGreatKatanaEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.GREAT_KATANA
end

local function isBowEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.RANGED) == xi.skill.ARCHERY
end

local function hasArrowEquipped(player)
    if player == nil or not xi.slot then
        return false
    end
    if player.getEquippedItem then
        local ammo = player:getEquippedItem(xi.slot.AMMO)
        if ammo == nil then
            return false
        end
        if ammo.getSkillType and xi.skill then
            return ammo:getSkillType() == xi.skill.ARCHERY
        end
        return true
    end
    if player.getEquipID then
        return (player:getEquipID(xi.slot.AMMO) or 0) > 0
    end
    return false
end

local function isBowAndArrowEquipped(player)
    return isBowEquipped(player) and hasArrowEquipped(player)
end

-- Compute exact bonus needed to raise SAM's native C+ Archery skill (210 @ Lv.75)
-- to A+ rank (276 @ Lv.75), matching SAM's native A+ Great Katana rank.
local function getArcheryAPlusBonus(player, lvl)
    local l = math.max(1, lvl or 1)
    if player ~= nil and player.getMaxSkillLevel and xi.job and xi.skill then
        local okGk, gkCap     = pcall(function() return player:getMaxSkillLevel(l, xi.job.SAM, xi.skill.GREAT_KATANA) end)
        local okArch, archCap = pcall(function() return player:getMaxSkillLevel(l, xi.job.SAM, xi.skill.ARCHERY) end)
        if okGk and okArch and type(gkCap) == 'number' and type(archCap) == 'number' and gkCap > archCap then
            return gkCap - archCap
        end
    end

    local aPlus = (l <= 50 and (6 + (l - 1) * 3))
        or (l <= 60 and (153 + (l - 50) * 5))
        or (l <= 70 and math.floor(203 + (l - 60) * 4.85))
        or (l <= 75 and (251 + (l - 70) * 5))
        or (276 + (l - 75) * 5)

    local cPlus = (l <= 50 and math.floor(5 + (l - 1) * 2.5))
        or (l <= 60 and math.floor(128 + (l - 50) * 3.5))
        or (l <= 70 and math.floor(163 + (l - 60) * 2.7))
        or (l <= 75 and (190 + (l - 70) * 4))
        or (210 + (l - 75) * 4)

    return math.max(0, aPlus - cPlus)
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

local function pulseNearbyEnmity(player, ce, ve, radius)
    if player == nil then
        return
    end

    local maxDist = radius or 10.0
    local mainTarget = player.getTarget and player:getTarget() or nil
    local mainTargetId = nil
    if mainTarget ~= nil and mainTarget.isMob and mainTarget:isMob() and mainTarget:isAlive() then
        mainTargetId = mainTarget:getID()
        grantEnmity(mainTarget, player, ce, ve)
    end

    local zone = player.getZone and player:getZone() or nil
    if zone ~= nil and zone.getMobs then
        for _, mob in ipairs(zone:getMobs()) do
            if
                mob ~= nil and
                mob:isMob() and
                mob:isAlive() and
                mob:getID() ~= mainTargetId and
                mob:checkDistance(player) <= maxDist and
                mob:isEngaged()
            then
                local mobTarget = mob.getTarget and mob:getTarget() or nil
                if
                    mobTarget ~= nil and
                    (mobTarget:getID() == player:getID() or (player.isInPartyWith and player:isInPartyWith(mobTarget)))
                then
                    grantEnmity(mob, player, ce, ve)
                end
            end
        end
    end
end

local function getSamCustomEffect(target, effectId)
    if target == nil or not target.getStatusEffect then
        return nil
    end
    local eff = target:getStatusEffect(effectId)
    if eff ~= nil then
        return eff
    end
    local fbId = FALLBACK_EFFECT_MAP[effectId]
    if fbId ~= nil then
        return target:getStatusEffect(fbId)
    end
    return nil
end

local function hasSamCustomEffect(target, effectId)
    return getSamCustomEffect(target, effectId) ~= nil
end

local function delSamCustomEffectSilent(target, effectId)
    if target == nil or not target.delStatusEffectSilent then
        return
    end
    if target.hasStatusEffect and target:hasStatusEffect(effectId) then
        target:delStatusEffectSilent(effectId)
    end
    local fbId = FALLBACK_EFFECT_MAP[effectId]
    if fbId ~= nil and target.hasStatusEffect and target:hasStatusEffect(fbId) then
        target:delStatusEffectSilent(fbId)
    end
end

local function consumePendingEffectMods(target, effect)
    if target == nil or effect == nil or not target.getID then
        return
    end
    local targetId  = target:getID()
    local pairsList = pendingEffectMods[targetId]
    if type(pairsList) == 'table' and effect.addMod then
        for _, pair in ipairs(pairsList) do
            if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                effect:addMod(pair[1], pair[2])
            end
        end
        pendingEffectMods[targetId] = nil
    end
end

local function applyCustomTimedEffect(target, effectId, power, duration, origin, subPower, iconId, modPairs, tickSec)
    if target == nil or not target.addStatusEffect then
        return false, effectId
    end

    local targetId = target.getID and target:getID() or 0
    delSamCustomEffectSilent(target, effectId)
    pendingEffectMods[targetId] = modPairs

    local params =
    {
        power    = power or 1,
        duration = duration or 15,
        origin   = origin or target,
        subPower = subPower or 0,
        icon     = (xi.soulspire and xi.soulspire.getStatusIcon and xi.soulspire.getStatusIcon(effectId, iconId)) or iconId or effectId,
        tick     = tickSec or 0,
    }

    local actualId = effectId
    local ok       = target:addStatusEffect(effectId, params)
    if not ok or (target.hasStatusEffect and not target:hasStatusEffect(effectId)) then
        local fbId = FALLBACK_EFFECT_MAP[effectId]
        if fbId ~= nil then
            pendingEffectMods[targetId] = modPairs
            if target.hasStatusEffect and target:hasStatusEffect(fbId) then
                target:delStatusEffectSilent(fbId)
            end
            ok       = target:addStatusEffect(fbId, params)
            actualId = fbId
        end
    end

    -- Direct fallback if onEffectGain did not fire (e.g. FileWatcher reload or pre-0024 binary)
    local leftover = pendingEffectMods[targetId]
    pendingEffectMods[targetId] = nil
    if ok and type(leftover) == 'table' then
        local eff = target.getStatusEffect and target:getStatusEffect(actualId) or nil
        if eff ~= nil and eff.addMod then
            for _, pair in ipairs(leftover) do
                if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                    eff:addMod(pair[1], pair[2])
                end
            end
        end
    end

    return ok, actualId
end

-----------------------------------
-- Dynamic Weapon-Conditional Mod Sync
-----------------------------------
local function clearSamWeaponMods(player)
    if player == nil or not player.getID then
        return
    end
    weaponModStateByChar[player:getID()] = nil

    if player.setLocalVar and isSamSpec(player, IMPERIAL_ARCHER_KEY) then
        player:setLocalVar('OX_AUTO_RANGED', 0)
    end
end

local function syncSamWeaponMods(player, initOnly)
    if player == nil or not player.getID then
        return
    end

    local specKey = getActiveSamSpecKey(player)
    if specKey == nil then
        clearSamWeaponMods(player)
        return
    end

    local lvl      = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local hasGk    = isGreatKatanaEquipped(player)
    local hasBow   = isBowEquipped(player)
    local bowReady = isBowAndArrowEquipped(player)
    local charId   = player:getID()
    local prev     = weaponModStateByChar[charId]

    local weaponChanged = prev == nil or prev.specKey ~= specKey or prev.lvl ~= lvl or prev.hasGk ~= hasGk or prev.hasBow ~= hasBow
    local bowChanged    = (prev ~= nil and prev.hasBow ~= hasBow)

    weaponModStateByChar[charId] =
    {
        specKey = specKey,
        lvl     = lvl,
        hasGk   = hasGk,
        hasBow  = hasBow,
    }

    if not initOnly and weaponChanged and spec.appliedByCharId and spec.appliedByCharId[charId] ~= nil then
        spec.appliedByCharId[charId].level = -1
        spec.refreshPlayer(player, { skipSync = true })
    end

    if player.setLocalVar and specKey == IMPERIAL_ARCHER_KEY then
        player:setLocalVar('OX_AUTO_RANGED', (lvl >= 10 and bowReady) and 1 or 0)
        player:setLocalVar('OX_AUTO_RANGED_RANGE', 20)
    end

    if specKey == IMPERIAL_ARCHER_KEY and bowChanged then
        if player.recalculateSkillsTable then
            player:recalculateSkillsTable()
        end
        if player.recalculateAbilitiesTable then
            player:recalculateAbilitiesTable()
        end
    end
end

-----------------------------------
-- Ronin: Mushin Stagger & Mind's Eye Helpers
-----------------------------------
local function getRoninStaggerPool(player)
    if player == nil or not player.getLocalVar then
        return 0
    end
    return math.max(0, player:getLocalVar('OX_RON_STAGGER_POOL') or 0)
end

local function updateRoninStaggerEffect(player, newPool)
    if player == nil or not player.setLocalVar then
        return
    end

    local pool = math.max(0, math.floor(newPool or 0))
    player:setLocalVar('OX_RON_STAGGER_POOL', pool)

    if pool <= 0 then
        player:setLocalVar('OX_RON_STAGGER_TICKS', 0)
        delSamCustomEffectSilent(player, EFFECT_RONIN_STAGGER)
        return
    end

    player:setLocalVar('OX_RON_STAGGER_TICKS', 3)
    local iconId = (xi.effect and xi.effect.DEFENSE_BOOST) or EFFECT_RONIN_STAGGER
    local eff    = getSamCustomEffect(player, EFFECT_RONIN_STAGGER)
    if eff ~= nil then
        if eff.setPower then
            eff:setPower(pool)
        end
        if eff.setDuration then
            eff:setDuration(9000)
        end
        if eff.resetStartTime then
            eff:resetStartTime()
        end
        return
    end

    applyCustomTimedEffect(player, EFFECT_RONIN_STAGGER, pool, 9, player, 0, iconId, nil, 3)
end

local function purifyRoninStagger(player, fraction)
    local cur = getRoninStaggerPool(player)
    if cur <= 0 then
        return 0
    end

    local cleared = math.min(cur, math.ceil(cur * math.max(0, math.min(1.0, fraction or 1.0))))
    updateRoninStaggerEffect(player, cur - cleared)
    return cleared
end

local function dealRoninCounterSlash(defender, attacker)
    if
        defender == nil or
        attacker == nil or
        attacker == defender or
        (attacker.isAlive and not attacker:isAlive()) or
        (defender.checkDistance and defender:checkDistance(attacker) > 6.5)
    then
        return
    end

    local lvl     = defender.getMainLvl and (defender:getMainLvl() or 10) or 10
    local strStat = defender.getStat and (defender:getStat(xi.mod.STR) or 10) or 10
    local vitStat = defender.getStat and (defender:getStat(xi.mod.VIT) or 10) or 10
    local gkSkill = defender.getSkillLevel and (defender:getSkillLevel(xi.skill.GREAT_KATANA) or 0) or 0
    local rawDmg  = math.max(8, math.floor(lvl * 0.95 + strStat * 0.60 + vitStat * 0.45 + gkSkill * 0.18))

    if attacker.takeDamage and xi.attackType and xi.damageType then
        attacker:takeDamage(rawDmg, defender, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    end
    grantEnmity(attacker, defender, 180, 420)
end

-----------------------------------
-- Imperial Archer & Warlord Buff Helpers
-----------------------------------
local function grantDrawnOisoya(player, silent)
    if player == nil then
        return
    end
    local lvl     = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local _, t    = scaleTier(lvl, 1, 2, 3, 4)
    local raccVal = scaleTier(lvl, 15, 25, 35, 45)
    local ratkVal = scaleTier(lvl, 10, 14, 18, 22)
    local iconId  = (xi.effect and xi.effect.SHARPSHOT) or EFFECT_IMP_DRAWN_OISOYA
    local ok      = applyCustomTimedEffect(player, EFFECT_IMP_DRAWN_OISOYA, t, 15, player, 0, iconId,
    {
        { xi.mod.RACC,  raccVal },
        { xi.mod.RATTP, ratkVal },
    })
    if ok and not silent then
        tellSam(player, string.format('[Imperial Archer] Drawn Oisoya primed (15s: +%d R.Acc, +%d%% R.Atk) — next Archery WS empowered.', raccVal, ratkVal))
    end
end

local function grantCosmicBrand(player, silent)
    if player == nil then
        return
    end
    local lvl    = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local _, t   = scaleTier(lvl, 1, 2, 3, 4)
    local accVal = scaleTier(lvl, 15, 25, 35, 45)
    local atkVal = scaleTier(lvl, 10, 14, 18, 22)
    local iconId = (xi.effect and (xi.effect.POTENCY or xi.effect.SENGIKORI)) or EFFECT_IMP_COSMIC_BRAND
    local ok     = applyCustomTimedEffect(player, EFFECT_IMP_COSMIC_BRAND, t, 15, player, 0, iconId,
    {
        { xi.mod.ACC,  accVal },
        { xi.mod.ATTP, atkVal },
    })
    if ok and not silent then
        tellSam(player, string.format('[Imperial Archer] Cosmic Brand primed (15s: +%d Acc, +%d%% Atk) — next Tachi WS empowered.', accVal, atkVal))
    end
end

local function grantWarlordNoto(player, durationSec)
    if player == nil then
        return
    end
    local lvl    = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local _, t   = scaleTier(lvl, 1, 2, 3, 4)
    local saveTp = scaleTier(lvl, 200, 250, 300, 350)
    local iconId = (xi.effect and (xi.effect.BRAZEN_RUSH or xi.effect.POTENCY or xi.effect.HAGAKURE)) or EFFECT_WARLORD_NOTO
    applyCustomTimedEffect(player, EFFECT_WARLORD_NOTO, t, durationSec or 15, player, saveTp, iconId,
    {
        { xi.mod.SAVETP, saveTp },
    })
end

local ASHURA_SUBTLE_BY_STACK = { 10, 16, 24 }
local ASHURA_WSD_BY_STACK    = { 6, 10, 15 }
local ASHURA_ACC_BY_STACK    = { 8, 14, 20 }
local ASHURA_REGAIN_BY_STACK = { 8, 12, 16 }

local function syncWarlordPartyAuras(player)
    expireWrlTimedPartySlots()
    if player == nil or not player.getID then
        return
    end

    local ownerId = player:getID()
    if not isSamSpec(player, WARLORD_KEY) or not isGreatKatanaEquipped(player) then
        clearAllWrlOwnerAuras(ownerId, 'ashura')
        clearAllWrlOwnerAuras(ownerId, 'hasso')
        return
    end

    local members = getPartyMembersInRange(player, WARLORD_AURA_RADIUS)
    local inRange = {}
    for _, member in ipairs(members) do
        if member ~= nil and member.getID then
            inRange[member:getID()] = true
        end
    end

    -- 1) Ashura's Edge 15y Party Aura
    local ashuraEff = getSamCustomEffect(player, EFFECT_WARLORD_ASHURA)
    local stacks    = (ashuraEff ~= nil and ashuraEff.getPower) and (ashuraEff:getPower() or 0) or 0
    if stacks >= 1 then
        stacks = math.min(3, stacks)
        local auraMods =
        {
            { xi.mod.SUBTLE_BLOW,        ASHURA_SUBTLE_BY_STACK[stacks] },
            { xi.mod.ALL_WSDMG_ALL_HITS, ASHURA_WSD_BY_STACK[stacks] },
            { xi.mod.ACC,                ASHURA_ACC_BY_STACK[stacks] },
            { xi.mod.MACC,               ASHURA_ACC_BY_STACK[stacks] },
            { xi.mod.REGAIN,             ASHURA_REGAIN_BY_STACK[stacks] },
        }
        for _, member in ipairs(members) do
            applyWrlPartyModSlot(member, 'ashura', auraMods, 0, ownerId)
        end
        for memberId, bySlot in pairs(wrlPartyBuffState) do
            if bySlot.ashura ~= nil and bySlot.ashura.ownerId == ownerId and not inRange[memberId] then
                clearWrlPartyModSlot(memberId, 'ashura')
            end
        end
    else
        clearAllWrlOwnerAuras(ownerId, 'ashura')
    end

    -- 2) Hasso 50% STR/Accuracy/Haste share to party members within 15y
    local hassoEff = player.getStatusEffect and player:getStatusEffect(xi.effect.HASSO) or nil
    if hassoEff ~= nil then
        local strShare = math.max(1, math.floor((hassoEff:getPower() or 1) * 0.5))
        local hassoMods =
        {
            { xi.mod.STR,           strShare },
            { xi.mod.ACC,           5 },
            { xi.mod.HASTE_ABILITY, 500 },
        }
        for _, member in ipairs(members) do
            if member:getID() ~= ownerId then
                applyWrlPartyModSlot(member, 'hasso', hassoMods, 0, ownerId)
            end
        end
        for memberId, bySlot in pairs(wrlPartyBuffState) do
            if bySlot.hasso ~= nil and bySlot.hasso.ownerId == ownerId and (memberId == ownerId or not inRange[memberId]) then
                clearWrlPartyModSlot(memberId, 'hasso')
            end
        end
    else
        clearAllWrlOwnerAuras(ownerId, 'hasso')
    end
end

local function addWarlordAshuraStacks(player, addStacks)
    if player == nil then
        return
    end
    local curStacks = 0
    local eff       = getSamCustomEffect(player, EFFECT_WARLORD_ASHURA)
    if eff ~= nil and eff.getPower then
        curStacks = eff:getPower() or 0
    end

    local stacks = math.max(1, math.min(3, curStacks + (addStacks or 1)))
    local lvl    = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local iconId = (xi.effect and xi.effect.WARCRY) or EFFECT_WARLORD_ASHURA

    applyCustomTimedEffect(player, EFFECT_WARLORD_ASHURA, stacks, 20, player, lvl, iconId, {})
    syncWarlordPartyAuras(player)
end

-----------------------------------
-- Weaponskill Pre-Hit Modifier Hook (called from soulspire_ws_overrides.lua)
-----------------------------------
function samSpecs.consumeWsModifiers(attacker, target, ws, primaryMsg)
    if
        attacker == nil or
        ws == nil or
        not attacker.isPC or
        not attacker:isPC() or
        attacker:getMainJob() ~= xi.job.SAM
    then
        return nil
    end

    syncSamWeaponMods(attacker, false)
    local specKey = getActiveSamSpecKey(attacker)
    if specKey == nil then
        return nil
    end

    local actorId = attacker:getID()
    local now     = os.time()
    if primaryMsg == false and wsConsumeCache[actorId] ~= nil and (now - wsConsumeCache[actorId].at) <= 1 then
        return wsConsumeCache[actorId].mods
    end

    local lvl       = attacker.getMainLvl and (attacker:getMainLvl() or 10) or 10
    local hasMeikyo = attacker.hasStatusEffect and attacker:hasStatusEffect(xi.effect.MEIKYO_SHISUI)
    local hasSengi  = attacker.hasStatusEffect and attacker:hasStatusEffect(xi.effect.SENGIKORI)
    local isGkWs    = (ws.skill == xi.skill.GREAT_KATANA) and isGreatKatanaEquipped(attacker)
    local isArchWs  = (ws.skill == xi.skill.ARCHERY) and isBowEquipped(attacker)
    local mods      = nil

    if specKey == IMPERIAL_ARCHER_KEY then
        local hasOisoya = hasSamCustomEffect(attacker, EFFECT_IMP_DRAWN_OISOYA)
        local hasCosmic = hasSamCustomEffect(attacker, EFFECT_IMP_COSMIC_BRAND)
        if isArchWs and (hasMeikyo or hasOisoya) then
            local tpBon  = scaleTier(lvl, 150, 225, 300, 375)
            local wsdVal = scaleTier(lvl, 8, 11, 14, 18) + (hasSengi and 15 or 0)
            if not hasMeikyo then
                delSamCustomEffectSilent(attacker, EFFECT_IMP_DRAWN_OISOYA)
                if attacker.setLocalVar then
                    attacker:setLocalVar('OX_IMP_REFUND_TP', 125)
                end
                tellSam(attacker, string.format('[Imperial Archer] Drawn Oisoya unleashed (+%d TP Bonus, +%d%% WSD).', tpBon, wsdVal))
            end
            mods =
            {
                tpBonus = tpBon,
                atkPct  = scaleTier(lvl, 15, 20, 25, 30),
                accAdd  = scaleTier(lvl, 20, 30, 40, 50),
                wsd     = wsdVal,
                scBonus = (hasMeikyo and 25 or 0) + (hasSengi and 25 or 0),
            }
        elseif isGkWs and (hasMeikyo or hasCosmic) then
            local tpBon  = scaleTier(lvl, 150, 225, 300, 375)
            local wsdVal = scaleTier(lvl, 8, 11, 14, 18) + (hasSengi and 15 or 0)
            local scVal  = scaleTier(lvl, 18, 24, 32, 40) + (hasSengi and 25 or 0)
            if not hasMeikyo then
                delSamCustomEffectSilent(attacker, EFFECT_IMP_COSMIC_BRAND)
                if attacker.setLocalVar then
                    attacker:setLocalVar('OX_IMP_REFUND_TP', 125)
                end
                tellSam(attacker, string.format('[Imperial Archer] Cosmic Brand unleashed (+%d TP Bonus, +%d%% WSD, +%d%% SC Dmg).', tpBon, wsdVal, scVal))
            end
            mods =
            {
                tpBonus = tpBon,
                atkPct  = scaleTier(lvl, 15, 20, 25, 30),
                accAdd  = scaleTier(lvl, 20, 30, 40, 50),
                wsd     = wsdVal,
                scBonus = scVal,
            }
        elseif (isArchWs or isGkWs) and hasSengi then
            mods = { wsd = 15, scBonus = 25 }
        end
    elseif specKey == WARLORD_KEY and isGkWs then
        local hasNoto = hasSamCustomEffect(attacker, EFFECT_WARLORD_NOTO)
        if hasMeikyo or hasNoto then
            if hasNoto and not hasMeikyo then
                delSamCustomEffectSilent(attacker, EFFECT_WARLORD_NOTO)
                attacker:delStatusEffectSilent(xi.effect.HAGAKURE)
                if attacker.setLocalVar then
                    attacker:setLocalVar('OX_WRL_IAIJUTSU_USED', 1)
                end
            end
            if
                target ~= nil and
                target.hasStatusEffect and
                target.addStatusEffect and
                not target:hasStatusEffect(xi.effect.CHAINBOUND, 0) and
                not target:hasStatusEffect(xi.effect.SKILLCHAIN, 0)
            then
                target:addStatusEffect(xi.effect.CHAINBOUND, { power = 2, duration = 10, origin = attacker, icon = 0, subPower = 1 })
            end
            mods =
            {
                tpBonus = scaleTier(lvl, 250, 350, 450, 600),
                critAdd = scaleTier(lvl, 0.35, 0.50, 0.70, 1.00),
                wsd     = hasSengi and 15 or 0,
                scBonus = hasSengi and 25 or 0,
            }
        elseif hasSengi then
            mods = { wsd = 15, scBonus = 25 }
        end
    end

    if mods ~= nil then
        wsConsumeCache[actorId] = { at = now, mods = mods }
    else
        wsConsumeCache[actorId] = nil
    end

    return mods
end

-----------------------------------
-- Spec Combat & Equip Listeners
-----------------------------------
local function detachSamListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_SAM_EQUIP')
        player:removeListener('OX_SAM_TICK')
        player:removeListener('OX_SAM_TAKE_DMG')
        player:removeListener('OX_SAM_WS')
        player:removeListener('OX_SAM_MELEE')
    end
end

local function attachSamListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachSamListeners(player)

    player:addListener('ITEM_EQUIP', 'OX_SAM_EQUIP', function(actor)
        syncSamWeaponMods(actor, false)
        syncWarlordPartyAuras(actor)
    end)

    player:addListener('TICK', 'OX_SAM_TICK', function(actor)
        syncSamWeaponMods(actor, false)
        syncWarlordPartyAuras(actor)
    end)

    -- Ronin: Mushin Poise Stagger deferral on incoming damage
    player:addListener('TAKE_DAMAGE', 'OX_SAM_TAKE_DMG', function(defender, amount, attacker)
        local dmg = tonumber(amount) or 0
        if
            dmg < 8 or
            defender == nil or
            attacker == defender or
            (defender.isAlive and not defender:isAlive()) or
            not isSamSpec(defender, RONIN_KEY) or
            not isGreatKatanaEquipped(defender)
        then
            return
        end

        local curHp = defender.getHP and (defender:getHP() or 0) or 0
        local maxHp = defender.getMaxHP and (defender:getMaxHP() or 0) or 0
        if curHp <= 0 or maxHp <= 0 then
            return
        end

        local staggerPct = (defender.hasStatusEffect and defender:hasStatusEffect(xi.effect.SEIGAN)) and 0.30 or 0.25
        local curPool    = getRoninStaggerPool(defender)
        local poolCap    = math.max(50, math.floor(maxHp * 0.50))
        local room       = math.max(0, poolCap - curPool)
        local deferred   = math.min(room, math.floor(dmg * staggerPct))
        if deferred <= 0 then
            return
        end

        if defender.addHP then
            defender:addHP(deferred)
        end
        updateRoninStaggerEffect(defender, curPool + deferred)
    end)

    -- Warlord: At 3 Ashura's Edge stacks, melee swings restore +15 HP and +5 MP to party within 15y
    player:addListener('MELEE_SWING_HIT', 'OX_SAM_MELEE', function(actor, target)
        if
            actor == nil or
            target == nil or
            target == actor or
            not isSamSpec(actor, WARLORD_KEY) or
            not isGreatKatanaEquipped(actor)
        then
            return
        end

        local ashuraEff = getSamCustomEffect(actor, EFFECT_WARLORD_ASHURA)
        if ashuraEff ~= nil and (ashuraEff:getPower() or 0) >= 3 then
            for _, member in ipairs(getPartyMembersInRange(actor, WARLORD_AURA_RADIUS)) do
                if member.addHP then
                    member:addHP(15)
                end
                if member.addMP then
                    member:addMP(5)
                end
            end
        end
    end)

    -- Post-Weaponskill Spec Procs across Ronin, Imperial Archer, and Warlord
    player:addListener('WEAPONSKILL_USE', 'OX_SAM_WS', function(actor, _target, skill, tp, _action, dmg)
        if actor == nil or not actor.isPC or not actor:isPC() or actor:getMainJob() ~= xi.job.SAM then
            return
        end

        syncSamWeaponMods(actor, false)
        local specKey = getActiveSamSpecKey(actor)
        if specKey == nil then
            return
        end

        local wsId = 0
        if type(skill) == 'number' then
            wsId = skill
        elseif skill ~= nil and skill.getID then
            wsId = skill:getID() or 0
        end

        local catalog  = xi.soulspire and xi.soulspire.wsCatalog
        local wsEntry  = catalog and catalog.byId and catalog.byId[wsId] or nil
        local isGkWs   = (wsEntry ~= nil and wsEntry.skill == xi.skill.GREAT_KATANA) or (wsEntry == nil and wsId >= 144 and wsId <= 159)
        local isArchWs = (wsEntry ~= nil and wsEntry.skill == xi.skill.ARCHERY) or (wsEntry == nil and wsId >= 192 and wsId <= 203)

        local landed = (dmg == nil or dmg > 0)
        if actor.getLocalVar and actor.setLocalVar then
            local lastAt = actor:getLocalVar('OX_LAST_WS_AT') or 0
            if lastAt > 0 and math.abs(os.time() - lastAt) <= 2 then
                landed = (actor:getLocalVar('OX_LAST_WS_LANDED') or 0) > 0
                actor:setLocalVar('OX_LAST_WS_LANDED', 0)
                actor:setLocalVar('OX_LAST_WS_AT', 0)
            end
        end

        if not landed then
            if actor.setLocalVar then
                actor:setLocalVar('OX_IMP_REFUND_TP', 0)
                actor:setLocalVar('OX_WRL_IAIJUTSU_USED', 0)
            end
            return
        end

        local lvl = actor.getMainLvl and (actor:getMainLvl() or 10) or 10

        if specKey == RONIN_KEY and isGkWs and isGreatKatanaEquipped(actor) then
            purifyRoninStagger(actor, 0.50)
            local maxHp   = actor.getMaxHP and (actor:getMaxHP() or 0) or 0
            local healPct = scaleTier(lvl, 0.03, 0.035, 0.04, 0.05)
            if maxHp > 0 and actor.addHP then
                actor:addHP(math.max(10, math.floor(maxHp * healPct)))
            end
            pulseNearbyEnmity(actor, 120, 300, 10.0)
        elseif specKey == IMPERIAL_ARCHER_KEY then
            local refundTp = actor.getLocalVar and (actor:getLocalVar('OX_IMP_REFUND_TP') or 0) or 0
            if refundTp > 0 then
                actor:setLocalVar('OX_IMP_REFUND_TP', 0)
                if actor.addTP then
                    actor:addTP(refundTp)
                end
            end

            if isGkWs and isGreatKatanaEquipped(actor) then
                grantDrawnOisoya(actor)
            elseif isArchWs and isBowEquipped(actor) then
                grantCosmicBrand(actor)
            end
        elseif specKey == WARLORD_KEY and isGkWs and isGreatKatanaEquipped(actor) then
            local usedIai   = actor.getLocalVar and (actor:getLocalVar('OX_WRL_IAIJUTSU_USED') or 0) or 0
            local hasMeikyo = actor.hasStatusEffect and actor:hasStatusEffect(xi.effect.MEIKYO_SHISUI)
            if usedIai > 0 then
                actor:setLocalVar('OX_WRL_IAIJUTSU_USED', 0)
            end
            if (usedIai > 0 or hasMeikyo) and _target ~= nil and _target.addStatusEffect then
                _target:addStatusEffect(xi.effect.DEFENSE_DOWN,   { power = 15, duration = 15, origin = actor })
                _target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, { power = 10, duration = 15, origin = actor })
                _target:addStatusEffect(xi.effect.EVASION_DOWN,   { power = 25, duration = 15, origin = actor })
            end
            addWarlordAshuraStacks(actor, 1)
        end
    end)
end

-----------------------------------
-- Custom Status Effect Lifecycle Handlers (837-841 + pre-0024 fallbacks)
-----------------------------------
local function onRoninStaggerGain(target, effect)
    consumePendingEffectMods(target, effect)
end

local function onRoninStaggerTick(target, effect)
    if target == nil or (target.isAlive and not target:isAlive()) then
        return
    end
    local pool  = getRoninStaggerPool(target)
    local ticks = math.max(1, target.getLocalVar and (target:getLocalVar('OX_RON_STAGGER_TICKS') or 1) or 1)
    if pool <= 0 then
        delSamCustomEffectSilent(target, EFFECT_RONIN_STAGGER)
        return
    end

    local tickDmg  = math.ceil(pool / ticks)
    local nextPool = math.max(0, pool - tickDmg)
    target:setLocalVar('OX_RON_STAGGER_POOL', nextPool)
    target:setLocalVar('OX_RON_STAGGER_TICKS', math.max(0, ticks - 1))
    if effect ~= nil and effect.setPower then
        effect:setPower(nextPool)
    end

    -- Non-lethal Stagger bleed: smooths tank spike damage without self-KO at 1 HP
    local curHp    = target.getHP and (target:getHP() or 1) or 1
    local safeLoss = math.max(0, math.min(tickDmg, curHp - 1))
    if safeLoss > 0 and target.delHP then
        target:delHP(safeLoss)
    end

    if nextPool <= 0 then
        delSamCustomEffectSilent(target, EFFECT_RONIN_STAGGER)
    end
end

local function onRoninStaggerLose(target, _effect)
    if target ~= nil and target.setLocalVar then
        target:setLocalVar('OX_RON_STAGGER_POOL', 0)
        target:setLocalVar('OX_RON_STAGGER_TICKS', 0)
    end
end

xi.effects.ronin_stagger.onEffectGain = onRoninStaggerGain
xi.effects.ronin_stagger.onEffectTick = onRoninStaggerTick
xi.effects.ronin_stagger.onEffectLose = onRoninStaggerLose
m:addOverride('xi.effects.ronin_stagger.onEffectGain', onRoninStaggerGain)
m:addOverride('xi.effects.ronin_stagger.onEffectTick', onRoninStaggerTick)
m:addOverride('xi.effects.ronin_stagger.onEffectLose', onRoninStaggerLose)

for _, effName in ipairs({ 'imp_drawn_oisoya', 'imp_cosmic_brand', 'warlord_noto', 'warlord_ashura' }) do
    local gainFn = function(target, effect)
        consumePendingEffectMods(target, effect)
    end
    local loseFn = function(target, _effect)
        if effName == 'warlord_ashura' and target ~= nil and target.getID then
            clearAllWrlOwnerAuras(target:getID(), 'ashura')
        end
    end
    xi.effects[effName] = xi.effects[effName] or {}
    xi.effects[effName].onEffectGain = gainFn
    xi.effects[effName].onEffectLose = loseFn
    m:addOverride('xi.effects.' .. effName .. '.onEffectGain', gainFn)
    m:addOverride('xi.effects.' .. effName .. '.onEffectLose', loseFn)
end

for _, fbKey in ipairs({
    'inquisitor_battuta',
    'inquisitor_converge',
    'spellblade_edgeflare',
    'spellblade_conduction',
    'spellblade_ascendance',
}) do
    xi.effects[fbKey] = xi.effects[fbKey] or {}
    m:addOverride('xi.effects.' .. fbKey .. '.onEffectGain', function(target, effect)
        if super then
            super(target, effect)
        end
        if target ~= nil and target.getMainJob and target:getMainJob() == xi.job.SAM then
            consumePendingEffectMods(target, effect)
        end
    end)
end

m:addOverride('xi.effects.inquisitor_battuta.onEffectTick', function(target, effect)
    if super then
        super(target, effect)
    end
    if isSamSpec(target, RONIN_KEY) then
        onRoninStaggerTick(target, effect)
    end
end)

m:addOverride('xi.effects.inquisitor_battuta.onEffectLose', function(target, effect)
    if super then
        super(target, effect)
    end
    if target ~= nil and target.getMainJob and target:getMainJob() == xi.job.SAM then
        onRoninStaggerLose(target, effect)
    end
end)

-----------------------------------
-- Combat Hook Overrides (Anticipation, Ranged Sweet Spot, Skillchains)
-----------------------------------

-- Ronin: Multi-Charge Mind's Eye Anticipation + Mushin Counter-Slash
m:addOverride('xi.combat.physicalHitRate.checkAnticipated', function(attacker, defender)
    if
        defender ~= nil and
        defender.hasStatusEffect and
        defender:hasStatusEffect(xi.effect.THIRD_EYE) and
        isSamSpec(defender, RONIN_KEY) and
        isGreatKatanaEquipped(defender)
    then
        local charges = defender.getLocalVar and (defender:getLocalVar('OX_RON_MINDS_EYE_CHARGES') or 0) or 0
        if charges <= 0 then
            charges = 1
        end

        if defender.addTP then
            defender:addTP(60)
        end
        dealRoninCounterSlash(defender, attacker)

        local rem = charges - 1
        if defender.setLocalVar then
            defender:setLocalVar('OX_RON_MINDS_EYE_CHARGES', math.max(0, rem))
        end
        if rem <= 0 then
            defender:delStatusEffectSilent(xi.effect.THIRD_EYE)
        end
        return true
    end

    return super(attacker, defender)
end)

-- Imperial Archer: Point-Blank Bow Mastery ("Drawn Oisoya" eliminates inner sweet-spot penalties)
m:addOverride('xi.combat.ranged.attackDistancePenalty', function(attacker, defender)
    if
        attacker ~= nil and
        isSamSpec(attacker, IMPERIAL_ARCHER_KEY) and
        isBowEquipped(attacker)
    then
        if hasSamCustomEffect(attacker, EFFECT_IMP_DRAWN_OISOYA) or isGreatKatanaEquipped(attacker) then
            local dist = (defender ~= nil and attacker.checkDistance) and attacker:checkDistance(defender) or 0
            if dist <= 12.0 then
                return 0
            end
            return math.floor((super(attacker, defender) or 0) * 0.5)
        end
    end

    return super(attacker, defender)
end)

m:addOverride('xi.combat.ranged.accuracyDistancePenalty', function(attacker, defender)
    if
        attacker ~= nil and
        isSamSpec(attacker, IMPERIAL_ARCHER_KEY) and
        isBowEquipped(attacker)
    then
        if hasSamCustomEffect(attacker, EFFECT_IMP_DRAWN_OISOYA) or isGreatKatanaEquipped(attacker) then
            return 0
        end
    end

    return super(attacker, defender)
end)

-- Imperial Archer (Cosmic Elucidation) & Warlord (Onimaru Blood-Quench) Skillchain Closers
m:addOverride('xi.combat.skillchain.calculateSkillchainDamage', function(actor, target, baseDamage)
    if actor == nil or not actor.isPC or not actor:isPC() or actor:getMainJob() ~= xi.job.SAM then
        return super(actor, target, baseDamage)
    end

    local lvl     = actor.getMainLvl and (actor:getMainLvl() or 10) or 10
    local scBonus = 0
    local isImp   = isSamSpec(actor, IMPERIAL_ARCHER_KEY) and (isBowEquipped(actor) or isGreatKatanaEquipped(actor))
    local isWrl   = isSamSpec(actor, WARLORD_KEY) and isGreatKatanaEquipped(actor)

    if isImp then
        scBonus = scaleTier(lvl, 12, 18, 24, 30)
    elseif isWrl then
        scBonus = scaleTier(lvl, 20, 25, 30, 35)
    end

    if scBonus <= 0 then
        return super(actor, target, baseDamage)
    end

    actor:addMod(xi.mod.SKILLCHAINBONUS, scBonus)
    local ok, scDmg = pcall(super, actor, target, baseDamage)
    actor:delMod(xi.mod.SKILLCHAINBONUS, scBonus)
    if not ok then
        error(scDmg)
    end

    if (tonumber(scDmg) or 0) > 0 then
        if isImp and actor.addTP then
            actor:addTP(100)
        elseif isWrl then
            local mult = (actor.hasStatusEffect and actor:hasStatusEffect(xi.effect.MEIKYO_SHISUI)) and 2 or 1
            for _, member in ipairs(getPartyMembersInRange(actor, WARLORD_AURA_RADIUS)) do
                if member.addHP and member.getMaxHP then
                    local maxHp = member:getMaxHP() or 0
                    if maxHp > 0 then
                        member:addHP(math.max(15, math.floor(maxHp * 0.10 * mult)))
                    end
                end
                if member.addMP and member.getMaxMP then
                    local maxMp = member:getMaxMP() or 0
                    if maxMp > 0 then
                        member:addMP(math.max(5, math.floor(maxMp * 0.08 * mult)))
                    end
                end
                if member.addTP then
                    member:addTP(250 * mult)
                end
            end
            addWarlordAshuraStacks(actor, 1)
        end
    end

    return scDmg
end)

-----------------------------------
-- Lean Native SAM Ability Reworks
-----------------------------------

-- 1) Seigan: Ronin Great Katana Tank Stance
m:addOverride('xi.job_utils.samurai.checkSeigan', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) then
        if not isGreatKatanaEquipped(player) then
            return xi.msg.basic.NEEDS_2H_WEAPON, 0
        end
        if ability ~= nil and ability.setRecast then
            ability:setRecast(15)
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.effects.seigan.onEffectGain', function(target, effect)
    super(target, effect)
    if target ~= nil and effect ~= nil and isSamSpec(target, RONIN_KEY) and isGreatKatanaEquipped(target) then
        local lvl = target.getMainLvl and (target:getMainLvl() or 10) or 10
        effect:addMod(xi.mod.DMG,     scaleTier(lvl, -800, -1000, -1200, -1400))
        effect:addMod(xi.mod.DEFP,    scaleTier(lvl, 12, 15, 18, 20))
        effect:addMod(xi.mod.ENMITY,  scaleTier(lvl, 25, 30, 35, 40))
        effect:addMod(xi.mod.COUNTER, scaleTier(lvl, 12, 15, 18, 20))
    end
end)

-- 2) Third Eye: Ronin 15s Recast & 2-3 Mind's Eye Charges
m:addOverride('xi.job_utils.samurai.checkThirdEye', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast((player.hasStatusEffect and player:hasStatusEffect(xi.effect.SEIGAN)) and 15 or 25)
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useThirdEye', function(player, target, ability)
    local res = super(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        local lvl     = player.getMainLvl and (player:getMainLvl() or 10) or 10
        local charges = (lvl >= 50) and 3 or 2
        if player.setLocalVar and player.hasStatusEffect and player:hasStatusEffect(xi.effect.THIRD_EYE) then
            player:setLocalVar('OX_RON_MINDS_EYE_CHARGES', charges)
        end
    end
    return res
end)

-- 3) Hasso: Imperial Archer Bow Stance & Warlord Crit/Zanshin Edge
m:addOverride('xi.job_utils.samurai.checkHasso', function(player, target, ability)
    if isSamSpec(player, IMPERIAL_ARCHER_KEY) and (isBowEquipped(player) or player:isWeaponTwoHanded()) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(30)
        end
        return 0, 0
    elseif isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(30)
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useHasso', function(player, target, ability)
    if isSamSpec(player, IMPERIAL_ARCHER_KEY) and isBowEquipped(player) and not player:isWeaponTwoHanded() then
        local lvl      = target.getMainLvl and (target:getMainLvl() or 10) or 10
        local strboost = math.max(2, math.floor(lvl / 7))
        target:delStatusEffectSilent(xi.effect.HASSO)
        target:delStatusEffectSilent(xi.effect.SEIGAN)
        target:addStatusEffect(xi.effect.HASSO, { power = strboost, duration = 300, origin = player })
        return xi.effect.HASSO
    end
    return super(player, target, ability)
end)

m:addOverride('xi.effects.hasso.onEffectGain', function(target, effect)
    super(target, effect)
    if target == nil or effect == nil then
        return
    end
    local lvl = target.getMainLvl and (target:getMainLvl() or 10) or 10
    if isSamSpec(target, IMPERIAL_ARCHER_KEY) and (isBowEquipped(target) or isGreatKatanaEquipped(target)) then
        local snapMod = xi.mod.SNAPSHOT or xi.mod.SNAP_SHOT
        if snapMod ~= nil then
            effect:addMod(snapMod, scaleTier(lvl, 8, 10, 13, 15))
        end
        effect:addMod(xi.mod.RATTP, scaleTier(lvl, 10, 13, 15, 18))
        effect:addMod(xi.mod.RACC,  scaleTier(lvl, 15, 20, 25, 30))
        effect:addMod(xi.mod.AGI,   scaleTier(lvl, 4, 7, 10, 12))
        if not target:isWeaponTwoHanded() then
            effect:addMod(xi.mod.HASTE_ABILITY, 1000)
        end
    elseif isSamSpec(target, WARLORD_KEY) and isGreatKatanaEquipped(target) then
        syncWarlordPartyAuras(target)
    end
end)

m:addOverride('xi.effects.hasso.onEffectLose', function(target, effect)
    super(target, effect)
    if target ~= nil and target.getID then
        clearAllWrlOwnerAuras(target:getID(), 'hasso')
    end
end)

-- 4) Meditate: Ronin Still-Water Stagger Purify/Heal & Imperial Archer Oisoya Focus
m:addOverride('xi.actions.abilities.meditate.onAbilityCheck', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    elseif (isSamSpec(player, IMPERIAL_ARCHER_KEY) and (isBowEquipped(player) or isGreatKatanaEquipped(player))) or
           (isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player))
    then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useMeditate', function(player, target, ability)
    local res = super(player, target, ability)
    local lvl = player.getMainLvl and (player:getMainLvl() or 10) or 10
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        purifyRoninStagger(player, 1.0)
        local maxHp   = player.getMaxHP and (player:getMaxHP() or 0) or 0
        local healPct = scaleTier(lvl, 0.15, 0.18, 0.22, 0.25)
        if maxHp > 0 and player.addHP then
            player:addHP(math.max(20, math.floor(maxHp * healPct)))
        end
        pulseNearbyEnmity(player, 150, 380, 10.0)
    elseif isSamSpec(player, IMPERIAL_ARCHER_KEY) and isBowEquipped(player) then
        grantDrawnOisoya(player)
    elseif isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        if player.addTP then
            player:addTP(1500)
        end
        local ownerId = player.getID and player:getID() or 0
        for _, member in ipairs(getPartyMembersInRange(player, WARLORD_AURA_RADIUS)) do
            if member:getID() ~= ownerId and member.addTP then
                member:addTP(400)
            end
        end
    end
    return res
end)

-- 5) Blade Bash: Ronin High-Threat Purify Interrupt & Warlord Armor-Rending Pommel Strike
m:addOverride('xi.job_utils.samurai.checkBladeBash', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(30)
        end
        return 0, 0
    elseif isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(45)
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useBladeBash', function(player, target, ability, action)
    local res = super(player, target, ability, action)
    local lvl = player.getMainLvl and (player:getMainLvl() or 10) or 10
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        purifyRoninStagger(player, 1.0)
        if target ~= nil and target.addStatusEffect then
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 4, origin = player })
            target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = 15, duration = 30, origin = player })
        end
        grantEnmity(target, player, 260, 680)
    elseif isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        if target ~= nil and target.addStatusEffect then
            local defDown = scaleTier(lvl, 12, 15, 18, 20)
            target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = defDown, duration = 30, origin = player })
        end
    end
    return res
end)

-- 6) Hagakure: Warlord 20s Noto Iaijutsu Sheathe-and-Draw
m:addOverride('xi.actions.abilities.hagakure.onAbilityCheck', function(player, target, ability)
    if isSamSpec(player, WARLORD_KEY) then
        if not isGreatKatanaEquipped(player) then
            return xi.msg.basic.NEEDS_2H_WEAPON, 0
        end
        if ability ~= nil and ability.setRecast then
            local hasMeikyo = player.hasStatusEffect and player:hasStatusEffect(xi.effect.MEIKYO_SHISUI)
            ability:setRecast(hasMeikyo and 0 or 20)
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useHagakure', function(player, target, ability)
    if isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        local lvl    = player.getMainLvl and (player:getMainLvl() or 10) or 10
        local saveTp = scaleTier(lvl, 200, 250, 300, 350)
        local tpBon  = scaleTier(lvl, 250, 350, 450, 600)
        player:delStatusEffectSilent(xi.effect.HAGAKURE)
        player:addStatusEffect(xi.effect.HAGAKURE, { power = saveTp, duration = 15, origin = player, subPower = tpBon })
        grantWarlordNoto(player, 15)
        return xi.effect.HAGAKURE
    end
    return super(player, target, ability)
end)

-- 7) Sekkanoki, Sengikori, Konzen-ittai, Warding Circle, Hamanoha & Meikyo Shisui
m:addOverride('xi.actions.abilities.sekkanoki.onAbilityCheck', function(player, target, ability)
    if (isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player)) or
       (isSamSpec(player, IMPERIAL_ARCHER_KEY) and (isBowEquipped(player) or isGreatKatanaEquipped(player)))
    then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(120)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useSekkanoki', function(player, target, ability)
    local res = super(player, target, ability)
    if isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        local ownerId = player.getID and player:getID() or 0
        for _, member in ipairs(getPartyMembersInRange(player, WARLORD_AURA_RADIUS)) do
            applyWrlPartyModSlot(member, 'sekkanoki', { { xi.mod.CRITHITRATE, 15 } }, 12, ownerId)
        end
        tellSam(player, '[Warlord] Sekkanoki grants the party +15% Critical Hit Rate for 12s!')
    elseif isSamSpec(player, IMPERIAL_ARCHER_KEY) and (isBowEquipped(player) or isGreatKatanaEquipped(player)) then
        grantDrawnOisoya(player, true)
        grantCosmicBrand(player, true)
        tellSam(player, '[Imperial Archer] Sekkanoki primes Drawn Oisoya & Cosmic Brand (15s).')
    end
    return res
end)

m:addOverride('xi.actions.abilities.sengikori.onAbilityCheck', function(player, target, ability)
    if isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(60)
        end
    elseif isSamSpec(player, IMPERIAL_ARCHER_KEY) and (isBowEquipped(player) or isGreatKatanaEquipped(player)) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.checkKonzenIttai', function(player, target, ability)
    if isSamSpec(player, IMPERIAL_ARCHER_KEY) or isSamSpec(player, WARLORD_KEY) or isSamSpec(player, RONIN_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useKonzenIttai', function(player, target, ability, action)
    local res = super(player, target, ability, action)
    if isSamSpec(player, IMPERIAL_ARCHER_KEY) and isBowEquipped(player) then
        if player.addTP then
            player:addTP(150)
        end
        grantDrawnOisoya(player)
    elseif isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        grantEnmity(target, player, 220, 520)
    end
    return res
end)

m:addOverride('xi.actions.abilities.warding_circle.onAbilityCheck', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(120)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useWardingCircle', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) and target ~= nil then
        pendingWardMods[target:getID()] =
        {
            { xi.mod.DMG,  -800 },
            { xi.mod.MEVA, 15 },
        }
    end
    local res = super(player, target, ability)
    if target ~= nil then
        pendingWardMods[target:getID()] = nil
    end
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) and target == player then
        pulseNearbyEnmity(player, 180, 440, 12.0)
    end
    return res
end)

m:addOverride('xi.effects.warding_circle.onEffectGain', function(target, effect)
    super(target, effect)
    if target ~= nil and effect ~= nil then
        local extra = pendingWardMods[target:getID()]
        if type(extra) == 'table' then
            for _, pair in ipairs(extra) do
                effect:addMod(pair[1], pair[2])
            end
        end
    end
end)

m:addOverride('xi.actions.abilities.hamanoha.onAbilityCheck', function(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(90)
        end
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.samurai.useHamanoha', function(player, target, ability)
    local res = super(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) and target ~= nil then
        if target.addStatusEffect then
            target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = 15, duration = 60, origin = player })
            target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 25, duration = 60, origin = player })
        end
        grantEnmity(target, player, 240, 580)
    end
    return res
end)

m:addOverride('xi.job_utils.samurai.useMeikyoShisui', function(player, target, ability)
    local res = super(player, target, ability)
    if isSamSpec(player, RONIN_KEY) and isGreatKatanaEquipped(player) then
        purifyRoninStagger(player, 1.0)
        player:addStatusEffect(xi.effect.THIRD_EYE, { duration = 30, origin = player })
        if player.setLocalVar then
            player:setLocalVar('OX_RON_MINDS_EYE_CHARGES', 3)
        end
        local eff = player.getStatusEffect and player:getStatusEffect(xi.effect.MEIKYO_SHISUI) or nil
        if eff ~= nil and eff.addMod then
            eff:addMod(xi.mod.DMG, -2000)
            eff:addMod(xi.mod.ENMITY, 50)
        end
        pulseNearbyEnmity(player, 350, 900, 12.0)
    elseif isSamSpec(player, IMPERIAL_ARCHER_KEY) and (isBowEquipped(player) or isGreatKatanaEquipped(player)) then
        grantDrawnOisoya(player, true)
        grantCosmicBrand(player, true)
        tellSam(player, '[Imperial Archer] Meikyo Shisui primes Drawn Oisoya & Cosmic Brand.')
    elseif isSamSpec(player, WARLORD_KEY) and isGreatKatanaEquipped(player) then
        addWarlordAshuraStacks(player, 3)
        if player.resetRecast and xi.recast and xi.recast.ABILITY then
            pcall(function() player:resetRecast(xi.recast.ABILITY, 54) end)
        end
        tellSam(player, '[Warlord] Meikyo Shisui grants 3x Ashura\'s Edge, 0s Hagakure CD, and 2x Onimaru Blood-Quench!')
    end
    return res
end)

-----------------------------------
-- Custom Crystal JAs: Oisoya Shot (438) & Onimaru Tithe (453)
-----------------------------------
local function bindSamAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

bindSamAbility('oisoya_shot',
    function(player, target, _ability)
        if not isSamSpec(player, IMPERIAL_ARCHER_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        if not isBowEquipped(player) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        if target == nil or (target.isAlive and not target:isAlive()) then
            return xi.msg.basic.CANNOT_PERFORM_TARG, 0
        end
        return 0, 0
    end,
    function(player, target, ability, action)
        syncSamWeaponMods(player, false)

        local lvl       = player.getMainLvl and (player:getMainLvl() or 10) or 10
        local agiStat   = player.getStat and (player:getStat(xi.mod.AGI) or 10) or 10
        local strStat   = player.getStat and (player:getStat(xi.mod.STR) or 10) or 10
        local archSkill = player.getSkillLevel and (player:getSkillLevel(xi.skill.ARCHERY) or 0) or 0
        local wpnDmg    = (player.getRangedDmg and math.max(10, player:getRangedDmg() or 10)) or (8 + math.floor(lvl * 0.65))

        local baseDmg = wpnDmg + math.floor(agiStat * 0.65 + strStat * 0.45 + archSkill * 0.16)
        local pdif    = 1.35
        if xi.combat and xi.combat.physical and xi.combat.physical.calculateRangedPDIF then
            local ok, calcPdif = pcall(xi.combat.physical.calculateRangedPDIF, player, target, xi.skill.ARCHERY, 1.25, false, false, false, 0.0, false)
            if ok and type(calcPdif) == 'number' and calcPdif > 0 then
                pdif = calcPdif
            end
        end

        local dmg = math.max(12, math.floor(baseDmg * pdif))
        if utils and utils.handleStoneskin and xi.attackType then
            dmg = utils.handleStoneskin(target, dmg, xi.attackType.RANGED)
        end

        local dealt = dmg
        if target.takeDamage and xi.attackType and xi.damageType then
            local res = target:takeDamage(dmg, player, xi.attackType.RANGED, xi.damageType.PIERCING)
            if type(res) == 'number' then
                dealt = math.max(0, res)
            end
        end
        if target.updateEnmityFromDamage then
            target:updateEnmityFromDamage(player, dealt)
        end
        if action ~= nil and action.recordDamage and xi.attackType then
            pcall(function() action:recordDamage(target, xi.attackType.RANGED, dealt) end)
        end
        if ability ~= nil and ability.setMsg and xi.msg and xi.msg.basic and xi.msg.basic.JA_DAMAGE then
            ability:setMsg(xi.msg.basic.JA_DAMAGE)
        end

        -- Prime Chainbound (ranged Konzen-ittai) if target has no active resonance
        if
            target.hasStatusEffect and
            target.addStatusEffect and
            not target:hasStatusEffect(xi.effect.CHAINBOUND, 0) and
            not target:hasStatusEffect(xi.effect.SKILLCHAIN, 0)
        then
            target:addStatusEffect(xi.effect.CHAINBOUND, { power = 2, duration = 10, origin = player, icon = 0, subPower = 1 })
        end

        local tpGain = scaleTier(lvl, 200, 250, 300, 350)
        if player.addTP then
            player:addTP(tpGain)
        end

        grantDrawnOisoya(player, true)
        grantCosmicBrand(player, true)
        tellSam(player, string.format('[Imperial Archer] Oisoya Shot primes Drawn Oisoya & Cosmic Brand (+%d TP).', tpGain))

        return dealt
    end
)

bindSamAbility('onimaru_tithe',
    function(player, _target, ability)
        if not isSamSpec(player, WARLORD_KEY) or not isGreatKatanaEquipped(player) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        if ability ~= nil and ability.setRecast then
            ability:setRecast(25)
        end
        return 0, 0
    end,
    function(player, target, _ability)
        if player == nil or not isSamSpec(player, WARLORD_KEY) or not isGreatKatanaEquipped(player) then
            return 0
        end

        if target ~= nil and target.getID and player.getID and target:getID() ~= player:getID() then
            return 0
        end

        addWarlordAshuraStacks(player, 3)

        local ownerId = player.getID and player:getID() or 0
        for _, member in ipairs(getPartyMembersInRange(player, WARLORD_AURA_RADIUS)) do
            if member.addTP then
                member:addTP(350)
            end
            applyWrlPartyModSlot(member, 'tithe', { { xi.mod.ALL_WSDMG_ALL_HITS, 12 } }, 12, ownerId)
            attachWarlordTitheLifesteal(member, 12)
        end

        tellSam(player, '[Warlord] Onimaru Tithe surges the party (+350 TP, +12% WSD, +15% Lifesteal for 12s) and refreshes Ashura\'s Edge!')
        return 0
    end
)

-----------------------------------
-- Crystal Definitions (SAM = 12)
-----------------------------------
if xi.job and xi.job.SAM then
    spec.registerJob(xi.job.SAM, 'SAM',
    {
        {
            id          = 1,
            key         = RONIN_KEY,
            name        = 'Ronin',
            role        = 'Mushin Seigan & Stagger Tank',
            icon        = 'ronin',
            reqLevel    = 10,
            extraTraits = { TRAIT_RONIN_MUSHIN },
            extraAbilities = function(_player, lvl)
                local list = { ABIL_SEIGAN, ABIL_THIRD_EYE, ABIL_MEDITATE, ABIL_BLADE_BASH }
                if lvl >= 50 then
                    table.insert(list, ABIL_KONZEN_ITTAI)
                    table.insert(list, ABIL_HAMANOHA)
                end
                return list
            end,
            description = 'Masterless Mushin tank: requires a Great Katana to unlock Seigan mitigation, multi-charge Mind\'s Eye counter-anticipation, and Mushin Stagger damage deferral purified by Tachis, Meditate, and Blade Bash.',
            highlights =
            {
                'Open weapon choice; requires Great Katana for Ronin passives, Stagger, and JA upgrades.',
                'Unlocks Seigan, Third Eye (15s CD, 2-3 Mind\'s Eye charges), Meditate, and Blade Bash at Lv.10+.',
                'Mind\'s Eye anticipates melee swings and single-target mob TP moves, countering for +60 TP & high Enmity.',
                'Mushin Poise defers 25-30% of hit damage into a 9s Stagger pool, purified by Tachi WSs, Blade Bash, and Meditate.',
                'Warding Circle (120s CD) grants party -8% DT & +15 MEVA; Meikyo Shisui grants -20% DT & instant Mind\'s Eye.',
            },
            mods = function(player, lvl)
                local empty  = {}
                local isWiki = (player == nil) or (not player.getEquipID)
                if not isWiki and not isGreatKatanaEquipped(player) then
                    return empty
                end
                return
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 12, 16, 20, 24) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 14, 18, 22, 26) },
                    { xi.mod.DMG,                   scaleTier(lvl, -1200, -1500, -1800, -2200) },
                    { xi.mod.MEVA,                  scaleTier(lvl, 10, 18, 26, 36) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 15, 20, 25, 30) },
                    { xi.mod.PARRY,                 scaleTier(lvl, 10, 16, 22, 30) },
                }
            end,
            onApply = function(player)
                attachSamListeners(player)
                syncSamWeaponMods(player, true)
            end,
            onRemove = function(player)
                purifyRoninStagger(player, 1.0)
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_RON_MINDS_EYE_CHARGES', 0)
                end
                clearSamWeaponMods(player)
                detachSamListeners(player)
            end,
        },
        {
            id          = 2,
            key         = IMPERIAL_ARCHER_KEY,
            name        = 'Imperial Archer',
            role        = 'Oisoya Bow & Blade Skirmisher',
            icon        = 'imperialarcher',
            reqLevel    = 10,
            autoRanged  = { minLevel = 10, maxRange = 20, skills = { 'archery' } },
            extraTraits = { TRAIT_IMP_OISOYA },
            extraAbilities = function(_player, lvl)
                local list = { ABIL_OISOYA_SHOT, ABIL_HASSO, ABIL_MEDITATE }
                if lvl >= 30 then
                    table.insert(list, ABIL_SENGIKORI)
                end
                if lvl >= 50 then
                    table.insert(list, ABIL_KONZEN_ITTAI)
                    table.insert(list, ABIL_SHIKIKOYO)
                end
                return list
            end,
            description = 'Tenzen-inspired Bow & Great Katana skirmisher: raises Archery to A+ with 100% arrow preservation, auto-shoots up to 20y outside melee, and weaves Tachi <-> Archery WSs via Drawn Oisoya and Cosmic Brand.',
            highlights =
            {
                'Open weapon choice; equipping a Bow grants A+ Archery skill, 100% Recycle (0 arrows used), +R.Acc/R.Atk/Snapshot.',
                'Auto-attacks with Bow + Arrow up to 20y outside melee range and suffers zero point-blank Bow penalty.',
                'Oisoya Shot (25s CD, 20y): ranged piercing arrow that restores +200-350 TP, primes Chainbound, and grants Drawn Oisoya & Cosmic Brand.',
                'Tachi WS -> Drawn Oisoya (+TP Bonus, +WSD, +R.Atk%, +125 TP refund on next Archery WS); Archery WS -> Cosmic Brand (+TP Bonus, +WSD, +SC Dmg on next Tachi).',
                'Hasso works with Bow or Great Katana (+Snapshot, +R.Atk%, +R.Acc, +AGI); Sengikori & Meikyo empower Bow + Blade chains.',
            },
            mods = function(player, lvl)
                local empty   = {}
                local isWiki  = (player == nil) or (not player.getEquipID)
                local hasBow  = isWiki or isBowEquipped(player)
                local hasGk   = isWiki or isGreatKatanaEquipped(player)
                local snapMod = (xi.mod and (xi.mod.SNAPSHOT or xi.mod.SNAP_SHOT)) or xi.mod.SNAPSHOT
                if not hasBow and not hasGk then
                    return empty
                end
                if hasBow and hasGk then
                    return
                    {
                        { xi.mod.ARCHERY, getArcheryAPlusBonus(player, lvl) },
                        { xi.mod.RECYCLE, 100 },
                        { xi.mod.RACC,    scaleTier(lvl, 12, 22, 34, 46) },
                        { xi.mod.RATTP,   scaleTier(lvl, 8, 13, 18, 24) },
                        { snapMod,        scaleTier(lvl, 6, 10, 15, 20) },
                        { xi.mod.AGI,     scaleTier(lvl, 4, 7, 11, 15) },
                        { xi.mod.ACC,     scaleTier(lvl, 8, 15, 24, 32) },
                        { xi.mod.ATTP,    scaleTier(lvl, 6, 10, 14, 18) },
                        { xi.mod.STR,     scaleTier(lvl, 3, 6, 9, 12) },
                        { xi.mod.STORETP, scaleTier(lvl, 9, 14, 21, 28) },
                    }
                end
                local out = {}
                if hasBow then
                    table.insert(out, { xi.mod.ARCHERY, getArcheryAPlusBonus(player, lvl) })
                    table.insert(out, { xi.mod.RECYCLE, 100 })
                    table.insert(out, { xi.mod.RACC,    scaleTier(lvl, 12, 22, 34, 46) })
                    table.insert(out, { xi.mod.RATTP,   scaleTier(lvl, 8, 13, 18, 24) })
                    table.insert(out, { snapMod,        scaleTier(lvl, 6, 10, 15, 20) })
                    table.insert(out, { xi.mod.STORETP, scaleTier(lvl, 5, 8, 12, 16) })
                    table.insert(out, { xi.mod.AGI,     scaleTier(lvl, 4, 7, 11, 15) })
                end
                if hasGk then
                    table.insert(out, { xi.mod.ACC,     scaleTier(lvl, 8, 15, 24, 32) })
                    table.insert(out, { xi.mod.ATTP,    scaleTier(lvl, 6, 10, 14, 18) })
                    table.insert(out, { xi.mod.STORETP, scaleTier(lvl, 4, 6, 9, 12) })
                    table.insert(out, { xi.mod.STR,     scaleTier(lvl, 3, 6, 9, 12) })
                end
                return out
            end,
            onApply = function(player)
                attachSamListeners(player)
                syncSamWeaponMods(player, true)
            end,
            onRemove = function(player)
                if player ~= nil then
                    delSamCustomEffectSilent(player, EFFECT_IMP_DRAWN_OISOYA)
                    delSamCustomEffectSilent(player, EFFECT_IMP_COSMIC_BRAND)
                    if player.setLocalVar then
                        player:setLocalVar('OX_IMP_REFUND_TP', 0)
                        player:setLocalVar('OX_AUTO_RANGED', 0)
                    end
                end
                clearSamWeaponMods(player)
                detachSamListeners(player)
            end,
        },
        {
            id          = 3,
            key         = WARLORD_KEY,
            name        = 'Warlord',
            role        = 'Cursed Onimaru & Iaijutsu Tactical Support',
            icon        = 'warlord',
            reqLevel    = 10,
            extraTraits = { TRAIT_WARLORD_IAIJUTSU },
            extraAbilities = function(_player, lvl)
                local list = { ABIL_HASSO, ABIL_MEDITATE, ABIL_HAGAKURE, ABIL_ONIMARU_TITHE }
                if lvl >= 30 then
                    table.insert(list, ABIL_SENGIKORI)
                    table.insert(list, ABIL_BLADE_BASH)
                end
                if lvl >= 50 then
                    table.insert(list, ABIL_KONZEN_ITTAI)
                    table.insert(list, ABIL_SHIKIKOYO)
                end
                return list
            end,
            description = 'Cursed Onimaru & Iaijutsu battlefield support (Lv10+): keeps the aggressive Great Katana & 20s Hagakure Sheathe-and-Draw playstyle while channeling Ashura\'s Edge stacks and Onimaru Blood-Quench Skillchains into party-wide TP/HP/MP surges, enemy armor sundering, and party-wide Subtle Blow.',
            highlights =
            {
                'Open weapon choice; requires Great Katana for +Accuracy, +Store TP, +Zanshin, +Subtle Blow, and Iaijutsu support effects.',
                'Hagakure (20s CD): sheathes into Noto stance (15s), turning your next Tachi into an Iaijutsu Draw-Slash (+35..100% Crit, +250..600 TP Bonus, Save TP, Chainbound) inflicting Onimaru Sundering (-15% DEF, -10% MDEF, -25 EVA for 15s).',
                'Ashura\'s Edge (up to 3x, 20s): 15y party aura (+10/16/24% Subtle Blow, +6/10/15% WSD, +8/14/20 Acc/MAcc, +8/12/16 Regain); at 3 stacks melee swings restore +15 HP & +5 MP to party within 15y.',
                'Onimaru Blood-Quench: closing a Skillchain boosts SC damage by +20-35% and restores 10% Max HP, 8% Max MP, and +250 TP to party within 15y.',
                'Onimaru Tithe (25s CD, 15y, 12s): grants party +350 TP, +12% WSD, and +15% Lifesteal, and refreshes Ashura\'s Edge to 3 stacks.',
                'Support Tradeoff & JAs: -20% Atk% & -15% WSD; Hasso shares 50% STR/Acc/Haste (15y); Meditate grants +1,500 TP self / +400 TP party; Sekkanoki grants party +15% Crit (12s); Meikyo Shisui grants 3x Ashura, 0s Hagakure CD, and 2x Blood-Quench.',
            },
            mods = function(player, lvl)
                local list =
                {
                }
                local isWiki = (player == nil) or (not player.getEquipID)
                if not isWiki and not isGreatKatanaEquipped(player) then
                    return list
                end
                table.insert(list, { xi.mod.HPP,          scaleTier(lvl, 12, 16, 20, 25) })
                table.insert(list, { xi.mod.STR,          scaleTier(lvl, 10, 16, 22, 28) })
                table.insert(list, { xi.mod.DEX,          scaleTier(lvl, 10, 16, 22, 28) })
                table.insert(list, { xi.mod.VIT,          scaleTier(lvl, 10, 16, 22, 28) })
                table.insert(list, { xi.mod.ACC,          scaleTier(lvl, 12, 20, 28, 38) })
                table.insert(list, { xi.mod.ZANSHIN,      scaleTier(lvl, 12, 18, 24, 32) })
                table.insert(list, { xi.mod.STORETP,      scaleTier(lvl, 10, 15, 20, 25) })
                table.insert(list, { xi.mod.SUBTLE_BLOW,  scaleTier(lvl, 15, 22, 30, 38) })
                table.insert(list, { xi.mod.GKATANA, scaleTier(lvl, 15, 25, 35, 50) })
                table.insert(list, { xi.mod.PARRY,        scaleTier(lvl, 10, 14, 18, 22) })
                table.insert(list, { xi.mod.ENMITY,       scaleTier(lvl, -15, -20, -25, -30) })
                return list
            end,
            onApply = function(player)
                attachSamListeners(player)
                syncSamWeaponMods(player, true)
                syncWarlordPartyAuras(player)
            end,
            onRemove = function(player)
                if player ~= nil then
                    delSamCustomEffectSilent(player, EFFECT_WARLORD_NOTO)
                    delSamCustomEffectSilent(player, EFFECT_WARLORD_ASHURA)
                    if player.getID then
                        clearAllWrlOwnerAuras(player:getID(), nil)
                    end
                    if player.setLocalVar then
                        player:setLocalVar('OX_WRL_IAIJUTSU_USED', 0)
                    end
                end
                clearSamWeaponMods(player)
                detachSamListeners(player)
            end,
        },
    })
end

return m
