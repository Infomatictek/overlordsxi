-----------------------------------
-- SoulspireXI Shared Healer Spec Helpers
-----------------------------------
xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.healerHelpers = xi.soulspire.healerHelpers or {}

local H = xi.soulspire.healerHelpers

H.PRIORITY_DEBUFFS =
{
    xi.effect.DOOM,
    xi.effect.PETRIFICATION,
    xi.effect.PARALYSIS,
    xi.effect.SILENCE,
    xi.effect.SLOW,
    xi.effect.CURSE_II,
    xi.effect.CURSE_I,
    xi.effect.PLAGUE,
    xi.effect.DISEASE,
    xi.effect.BLINDNESS,
    xi.effect.POISON,
    xi.effect.BIND,
    xi.effect.WEIGHT,
    xi.effect.ADDLE,
    xi.effect.DEFENSE_DOWN,
    xi.effect.MAGIC_DEF_DOWN,
    xi.effect.ATTACK_DOWN,
    xi.effect.MAGIC_ATK_DOWN,
    xi.effect.ACCURACY_DOWN,
    xi.effect.EVASION_DOWN,
}

function H.scaleTier(lvl, lv10, lv30, lv50, lv70)
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

function H.isSpecActive(entity, jobId, specKey)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= jobId or
        entity:getMainLvl() < 10
    then
        return false
    end

    if xi.soulspire and xi.soulspire.spec and xi.soulspire.spec.ensureUpToDate then
        xi.soulspire.spec.ensureUpToDate(entity)
        return xi.soulspire.spec.is(entity, jobId, specKey)
    end
    return false
end

function H.applyCustomTimedEffect(target, effectId, power, durationSec, origin, subPower, iconId, tier)
    if target == nil or not target.addStatusEffect or not effectId then
        return false
    end
    if target.delStatusEffectSilent then
        target:delStatusEffectSilent(effectId)
    end
    local resolvedIcon = (xi.soulspire and xi.soulspire.getStatusIcon and xi.soulspire.getStatusIcon(effectId, iconId)) or iconId or effectId
    return target:addStatusEffect(effectId,
    {
        power    = power or 1,
        duration = durationSec or 10,
        origin   = origin or target,
        subPower = subPower or 0,
        icon     = resolvedIcon,
        tier     = tier or 1,
    })
end

function H.forEachPartyMemberInRange(player, radius, includePets, fn)
    if player == nil or type(fn) ~= 'function' then
        return
    end

    local seen = {}
    local function visit(unit)
        if unit == nil or not unit.isAlive or not unit:isAlive() then
            return
        end
        local uid = unit.getID and unit:getID() or tostring(unit)
        if seen[uid] then
            return
        end
        if unit == player or (player.checkDistance and player:checkDistance(unit) <= (radius or 15)) then
            seen[uid] = true
            fn(unit)
        end
    end

    local party = player.getPartyWithTrusts and player:getPartyWithTrusts() or (player.getParty and player:getParty()) or { player }
    if #party == 0 then
        party = { player }
    end

    for _, member in ipairs(party) do
        visit(member)
        if includePets and member.hasPet and member:hasPet() then
            visit(member:getPet())
        end
    end
end

function H.healEntity(healer, target, rawAmount)
    if target == nil or not target.isAlive or not target:isAlive() then
        return 0, 0
    end
    local amount = math.max(0, math.floor(rawAmount or 0))
    if amount <= 0 then
        return 0, 0
    end

    local curHp = target:getHP()
    local maxHp = target:getMaxHP()
    local missing = math.max(0, maxHp - curHp)
    local actual = math.min(amount, missing)
    local overheal = math.max(0, amount - actual)

    if actual > 0 and target.addHP then
        target:addHP(actual)
        if target.updateEnmityFromCure and healer ~= nil and healer ~= target and target.isPC and target:isPC() then
            -- Keep healer threat low; actual cure enmity is naturally reduced by -Enmity passives
        end
    end

    return actual, overheal
end

function H.healPartyPct(healer, pctOfHealerMaxHp, radius, includePets, useTargetMaxHp)
    if healer == nil then
        return 0
    end
    local healerMax = math.max(1, healer:getMaxHP())
    local totalHealed = 0
    H.forEachPartyMemberInRange(healer, radius or 15, includePets, function(unit)
        local baseMax = useTargetMaxHp and math.max(1, unit:getMaxHP()) or healerMax
        local amt = math.floor(baseMax * (pctOfHealerMaxHp / 100))
        local actual = H.healEntity(healer, unit, amt)
        totalHealed = totalHealed + actual
    end)
    return totalHealed
end

function H.cleanseDebuffs(target, maxCount, customList)
    if target == nil or not target.hasStatusEffect or not target.delStatusEffect then
        return 0
    end
    local list = customList or H.PRIORITY_DEBUFFS
    local limit = maxCount or 1
    local removed = 0
    for _, effId in ipairs(list) do
        if effId ~= nil and target:hasStatusEffect(effId) then
            target:delStatusEffect(effId)
            removed = removed + 1
            if removed >= limit then
                break
            end
        end
    end
    return removed
end

function H.applyStoneskinBarrier(target, addPower, maxCap, durationSec, origin)
    if target == nil or not target.addStatusEffect then
        return 0
    end
    local addVal = math.max(0, math.floor(addPower or 0))
    if addVal <= 0 then
        return 0
    end

    local existing = target.getStatusEffect and target:getStatusEffect(xi.effect.STONESKIN) or nil
    local curPower = existing and (existing:getPower() or 0) or 0
    local nextPower = curPower + addVal
    if maxCap ~= nil and maxCap > 0 then
        nextPower = math.min(nextPower, math.floor(maxCap))
    end
    if nextPower <= curPower and existing ~= nil then
        return curPower
    end

    if target.delStatusEffectSilent then
        target:delStatusEffectSilent(xi.effect.STONESKIN)
    end
    target:addStatusEffect(xi.effect.STONESKIN,
    {
        power    = nextPower,
        duration = durationSec or 12,
        origin   = origin or target,
        tier     = 3,
    })
    return nextPower
end

function H.restoreMpPct(target, pct)
    if target == nil or not target.addMP or not target.getMaxMP then
        return 0
    end
    local amt = math.floor(target:getMaxMP() * (pct / 100))
    if amt > 0 then
        target:addMP(amt)
    end
    return amt
end

function H.isWeaponSkillInSet(ws, idSet, skillTypes)
    if ws == nil then
        return false
    end
    local wsId = (type(ws) == 'number') and ws or (ws.getID and ws:getID() or 0)
    if idSet ~= nil and idSet[wsId] then
        return true
    end
    if skillTypes ~= nil and (type(ws) == 'table' or type(ws) == 'userdata') and ws.getSkillType then
        local st = ws:getSkillType()
        if skillTypes[st] then
            return true
        end
    end
    return false
end

return H
