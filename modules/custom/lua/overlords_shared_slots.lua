-----------------------------------
-- OverlordsXI Shared Party & Debuff Status Slots (876-881)
-- Enforces highest-potency overwrite and caps party JA mitigation
-- (EFF_OX_SUP_WARD) at -15% DMG / +35 MEVA so buffs cannot stack to 100%.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('overlords_shared_slots')

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.slots = xi.overlords.slots or {}

local S = xi.overlords.slots

S.EFF_OX_SUP_OFFENSE = 876
S.EFF_OX_SUP_CHAIN   = 877
S.EFF_OX_SUP_WARD    = 878
S.EFF_OX_DEB_BREACH  = 879
S.EFF_OX_DEB_CRIPPLE = 880
S.EFF_OX_DEB_EXPOSE  = 881

xi.effect = xi.effect or {}
xi.effect.EFF_OX_SUP_OFFENSE = S.EFF_OX_SUP_OFFENSE
xi.effect.EFF_OX_SUP_CHAIN   = S.EFF_OX_SUP_CHAIN
xi.effect.EFF_OX_SUP_WARD    = S.EFF_OX_SUP_WARD
xi.effect.EFF_OX_DEB_BREACH  = S.EFF_OX_DEB_BREACH
xi.effect.EFF_OX_DEB_CRIPPLE = S.EFF_OX_DEB_CRIPPLE
xi.effect.EFF_OX_DEB_EXPOSE  = S.EFF_OX_DEB_EXPOSE

local SLOT_EFFECT_NAMES =
{
    [S.EFF_OX_SUP_OFFENSE] = 'ox_sup_offense',
    [S.EFF_OX_SUP_CHAIN]   = 'ox_sup_chain',
    [S.EFF_OX_SUP_WARD]    = 'ox_sup_ward',
    [S.EFF_OX_DEB_BREACH]  = 'ox_deb_breach',
    [S.EFF_OX_DEB_CRIPPLE] = 'ox_deb_cripple',
    [S.EFF_OX_DEB_EXPOSE]  = 'ox_deb_expose',
}

local pendingSlotMods = {}

local function getPendingKey(target, effectId)
    local tid = (target and target.getID and target:getID()) or tostring(target)
    return tostring(tid) .. '_' .. tostring(effectId)
end

xi.effects = xi.effects or {}
for effId, effName in pairs(SLOT_EFFECT_NAMES) do
    xi.effects[effName] = xi.effects[effName] or {}

    m:addOverride('xi.effects.' .. effName .. '.onEffectGain', function(target, effect)
        local key  = getPendingKey(target, effId)
        local mods = pendingSlotMods[key]
        pendingSlotMods[key] = nil

        local function applyClampedMod(modId, val)
            if modId == nil or val == nil or val == 0 then
                return
            end
            if effId == S.EFF_OX_SUP_WARD then
                if modId == xi.mod.DMG then
                    val = math.max(-1500, math.min(0, val))
                elseif modId == xi.mod.MEVA then
                    val = math.min(35, math.max(0, val))
                end
            end
            if val ~= 0 then
                effect:addMod(modId, val)
            end
        end

        if type(mods) == 'table' then
            for _, pair in ipairs(mods) do
                applyClampedMod(pair[1], pair[2])
            end
        elseif type(mods) == 'function' then
            local proxy =
            {
                addMod = function(_self, modId, val)
                    applyClampedMod(modId, val)
                end,
            }
            setmetatable(proxy, { __index = effect })
            mods(proxy)
        end
    end)

    m:addOverride('xi.effects.' .. effName .. '.onEffectLose', function(_target, _effect)
    end)
end

function S.applySlot(target, effectId, power, duration, origin, modsTable, iconId)
    if target == nil or not target.addStatusEffect or not effectId then
        return false
    end

    local pwr = math.max(1, math.floor(power or 1))
    local dur = duration or 12
    local existing = target.getStatusEffect and target:getStatusEffect(effectId) or nil
    if existing ~= nil then
        local existingPow = existing:getPower() or 0
        if existingPow > pwr then
            return false
        end
        if existingPow == pwr and existing.getTimeRemaining then
            local remSec = (existing:getTimeRemaining() or 0) / 1000
            if remSec > dur then
                return false
            end
        end
    end

    if target.delStatusEffectSilent then
        target:delStatusEffectSilent(effectId)
    end

    local key = getPendingKey(target, effectId)
    pendingSlotMods[key] = modsTable or {}
    local resolvedIcon = (xi.overlords and xi.overlords.getStatusIcon and xi.overlords.getStatusIcon(effectId, iconId)) or iconId or effectId
    local ok = target:addStatusEffect(effectId,
    {
        power    = pwr,
        duration = dur,
        origin   = origin or target,
        icon     = resolvedIcon,
        tier     = 1,
    })
    pendingSlotMods[key] = nil
    return ok
end

function S.applyPartyWard(caster, target, dtBps, meva, duration, iconId)
    local clampedDt   = math.max(-1500, math.min(0, math.floor(dtBps or -1000)))
    local clampedMeva = math.min(35, math.max(0, math.floor(meva or 0)))
    local potency     = math.abs(clampedDt) + clampedMeva
    local mods        = {}
    if clampedDt ~= 0 then
        table.insert(mods, { xi.mod.DMG, clampedDt })
    end
    if clampedMeva ~= 0 then
        table.insert(mods, { xi.mod.MEVA, clampedMeva })
    end
    return S.applySlot(target, S.EFF_OX_SUP_WARD, potency, duration or 12, caster, mods, iconId)
end

return m
