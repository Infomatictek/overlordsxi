-----------------------------------
-- OverlordsXI DoT Attribution Helper (Mobs)
--
-- Passes the DoT origin entity to target:takeDamage() for Lua-ticked DoTs
-- (Helix and Nightmare Bio tier >= 11) when ticking on mobs so kill credit,
-- RoE triggers, and C++ DoT combat log attribution stay consistent.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('overlords_dot_damage_log')

local function resolveDotOrigin(target, effect)
    if target == nil or effect == nil or effect.getOriginID == nil then
        return nil
    end

    local originId = effect:getOriginID()
    if originId == nil or originId == 0 then
        return nil
    end

    local origin = nil
    if originId < 0x01000000 then
        if GetPlayerByID ~= nil then
            origin = GetPlayerByID(originId)
        end
    else
        local instance = target.getInstance ~= nil and target:getInstance() or nil
        if GetEntityByID ~= nil then
            origin = GetEntityByID(originId, instance, true)
        end
    end

    if origin == nil or origin == target then
        return nil
    end

    if origin.isPC ~= nil and origin:isPC() then
        return origin
    end

    if origin.isTrust ~= nil and origin:isTrust() then
        return origin
    end

    if origin.isPet ~= nil and origin:isPet() then
        local master = origin.getMaster ~= nil and origin:getMaster() or nil
        if master == nil or (master.isPC ~= nil and master:isPC()) then
            return origin
        end
    end

    return nil
end

m:addOverride('xi.effects.helix.onEffectTick', function(target, effect)
    if target == nil or target.isMob == nil or not target:isMob() then
        return super(target, effect)
    end

    local origin = resolveDotOrigin(target, effect)
    if origin == nil then
        return super(target, effect)
    end

    local dmg = utils.handleStoneskin(target, effect:getPower(), xi.attackType.NONE)
    if dmg > 0 then
        target:takeDamage(dmg, origin)
    end
end)

m:addOverride('xi.effects.bio.onEffectTick', function(target, effect)
    if target == nil or target.isMob == nil or not target:isMob() or effect == nil or effect:getTier() < 11 then
        return super(target, effect)
    end

    local origin = resolveDotOrigin(target, effect)
    if origin == nil then
        return super(target, effect)
    end

    local dmg = utils.handleStoneskin(target, effect:getPower(), xi.attackType.NONE)
    if dmg > 0 then
        target:takeDamage(dmg, origin, nil, nil, { wakeUp = false, breakBind = false })
    end
end)

return m
