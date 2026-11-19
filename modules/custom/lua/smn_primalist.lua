-----------------------------------
-- OverlordsXI SMN 1: Primalist (Sequence D — Offensive Opening)
-- Challenge Aspect (20s CD, 12s/15s window) binds active avatar & target for next matching elemental Rage.
-- Additive to smn_specs.lua (must load after smn_specs.lua; preserves Celestial).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_smn_primalist')
local spec = xi.overlords.spec
local SMN = xi.job.SMN
local KEY = 'primalist'

local VAR_CHALLENGE_CD = 'OX_PRM_CHALLENGE_CD'
local promiseByChar = {}

local AVATAR_ELEMENTS =
{
    ifrit     = 'fire',
    shiva     = 'ice',
    garuda    = 'wind',
    titan     = 'earth',
    ramuh     = 'lightning',
    leviathan = 'water',
    carbuncle = 'light',
}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isPrimalist(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == SMN and player:getMainLvl() >= 10 and
        spec.is(player, SMN, KEY)
end

local function clearPromise(player)
    if player and player.getID then
        promiseByChar[player:getID()] = nil
    end
end

-- Starter/loaned avatar roster by level bracket (no permanent avatar flags).
local function getAvailableAvatars(level, chosenLv30)
    if level >= 50 then
        return { 'carbuncle', 'ifrit', 'shiva', 'garuda', 'titan', 'ramuh', 'leviathan' }
    elseif level >= 30 then
        local extras = chosenLv30 or { 'shiva', 'garuda' }
        return { 'carbuncle', 'ifrit', extras[1] or 'shiva', extras[2] or 'garuda' }
    end
    return { 'carbuncle', 'ifrit' }
end

-- Challenge Aspect (20s CD, 12s window at Lv10-69, 15s at Lv70-75).
local function challengeAspect(player, avatarKey, target)
    if not isPrimalist(player) then return nil, 'not_primalist' end
    local elem = AVATAR_ELEMENTS[avatarKey]
    if not elem then return nil, 'invalid_avatar' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_CHALLENGE_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 20 then
        return nil, 'on_recast'
    end
    if player.setLocalVar then
        player:setLocalVar(VAR_CHALLENGE_CD, now)
    end

    local window = player:getMainLvl() >= 70 and 15 or 12
    local rec = { avatarKey = avatarKey, element = elem, targetId = target:getID(), untilSec = now + window }
    promiseByChar[player:getID()] = rec
    return rec
end

-- Swapping avatar clears any active Challenge Aspect promise.
local function onAvatarChanged(player)
    clearPromise(player)
end

-- Resolve avatar's next single-target elemental Rage against bound target.
-- Gains +20/25/30/35% ONLY if avatar matches, target matches, pact is elemental, and element is among target's lowest resistances.
local function resolveAvatarRage(player, avatarKey, target, baseDamage, opts)
    opts = opts or {}
    if type(baseDamage) ~= 'number' or baseDamage <= 0 then
        return 0, { empowered = false }
    end
    if not isPrimalist(player) or opts.isPhysicalOnly then
        return baseDamage, { empowered = false }
    end

    local now = xi.overlords.nowSec()
    local rec = promiseByChar[player:getID()]
    if not rec or now > rec.untilSec then
        clearPromise(player)
        return baseDamage, { empowered = false }
    end
    if rec.avatarKey ~= avatarKey or not target or target:getID() ~= rec.targetId then
        return baseDamage, { empowered = false }
    end

    -- Consume the one-pact promise on matching avatar + target resolution.
    clearPromise(player)

    local resistances = opts.resistances or {}
    local minVal = nil
    for _, v in pairs(resistances) do
        if minVal == nil or v < minVal then minVal = v end
    end
    local elemVal = resistances[rec.element]
    local isLowest = (minVal == nil) or (elemVal ~= nil and elemVal <= minVal)
    if not isLowest then
        return baseDamage, { empowered = false, resistantElement = true }
    end

    local pct = scale(player:getMainLvl(), 20, 25, 30, 35)
    return math.floor(baseDamage * (100 + pct) / 100), { empowered = true, bonusPct = pct, element = rec.element }
end

xi.overlords.primalist =
{
    getAvailableAvatars = getAvailableAvatars,
    challengeAspect     = challengeAspect,
    onAvatarChanged     = onAvatarChanged,
    resolveAvatarRage   = resolveAvatarRage,
    clearPromise        = clearPromise,
}

if SMN ~= nil then
    spec.registerCrystal(xi.job.SMN,
    {
        id = 1,
        key = KEY,
        name = 'Primalist',
        abr = 'PRM',
        role = 'Damage',
        icon = 'primalist',
        reqLevel = 10,
        description = 'An elemental Summoner who loans prime avatars by tier and commits Challenge Aspect to empower an avatar\'s next resistance-matched elemental Blood Pact: Rage.',
        highlights =
        {
            'Starter Ifrit & Carbuncle at Lv10; +2 chosen prime avatars at Lv30; all 6 prime avatars at Lv50 (no permanent flags).',
            'Challenge Aspect (20s CD, 12/15s window): +20/25/30/35% to next matching elemental Rage if element is among target\'s lowest resistances.',
            'Changing avatar clears the promise; physical-only Rages and wrong targets receive ordinary damage.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.SUMMONING_MAGIC_SKILL, scale(level, 12, 22, 34, 46) },
                { xi.mod.MPP,                   scale(level, 6, 10, 14, 18) },
            }
        end,
        onRemove = clearPromise,
    })
end

return m
