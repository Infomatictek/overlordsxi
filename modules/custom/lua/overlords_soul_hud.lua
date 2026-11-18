-----------------------------------
-- OverlordsXI Universal Soul HUD Server Sync
--
-- Reusable, delta-throttled server->client state synchronization for the
-- Ashita v4 `overlords_soulhud` addon via silent [OXHUD]|... SYSTEM_3 packets.
--
-- API for Soul modules:
--   xi.overlords.hud.registerProvider(soulKey, collectorFn)
--     collectorFn(player) -> table of scalar key/value pairs (numbers/booleans/strings)
--   xi.overlords.hud.sync(player, force)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_soul_hud')

local spec = xi.overlords.spec

xi.overlords = xi.overlords or {}
xi.overlords.hud = xi.overlords.hud or {}
local hud = xi.overlords.hud

hud.PROTO_TAG = '[OXHUD]|'
hud.providers = hud.providers or {}
hud.lastSigByCharId = hud.lastSigByCharId or {}
hud.lastSentAtByCharId = hud.lastSentAtByCharId or {}

local MIN_AUTO_INTERVAL_SEC = 0.25

local function sanitize(v)
    if type(v) == 'boolean' then
        return v and '1' or '0'
    elseif type(v) == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then
            return '0'
        end
        if v % 1 == 0 then
            return tostring(v)
        end
        return string.format('%.1f', v)
    end
    return tostring(v or ''):gsub('[|\r\n;=]', '')
end

local function effectRemSec(player, effectId)
    if player == nil or not player.getStatusEffect or not effectId then
        return 0, nil
    end
    local eff = player:getStatusEffect(effectId)
    if eff == nil then
        return 0, nil
    end
    local rem = 0
    if eff.getTimeRemaining then
        rem = math.max(0, math.floor((eff:getTimeRemaining() or 0) / 1000))
    end
    return rem, eff
end

function hud.registerProvider(soulKey, collectorFn)
    if type(soulKey) == 'string' and soulKey ~= '' and type(collectorFn) == 'function' then
        hud.providers[soulKey] = collectorFn
    end
end

function hud.sync(player, force)
    if player == nil or not player:isPC() then
        return
    end

    local cid = player:getID()
    local now = os.clock()
    local lastAt = hud.lastSentAtByCharId[cid] or 0
    if not force and (now - lastAt) < MIN_AUTO_INTERVAL_SEC then
        return
    end

    local jobId = player:getMainJob()
    local active = spec.get(player, jobId)
    local soulKey = active and active.key or ''
    local unlocked = (active ~= nil and spec.isLevelEligible(player, jobId, active)) and 1 or 0

    local kvParts = {}
    local provider = (soulKey ~= '' and unlocked == 1) and hud.providers[soulKey] or nil
    if provider then
        local ok, data = pcall(provider, player)
        if ok and type(data) == 'table' then
            local keys = {}
            for k, _ in pairs(data) do
                keys[#keys + 1] = tostring(k)
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local cleanKey = sanitize(k)
                if cleanKey ~= '' then
                    kvParts[#kvParts + 1] = cleanKey .. '=' .. sanitize(data[k])
                end
            end
        end
    end

    local kvStr = table.concat(kvParts, ';')
    local payload = string.format('%u|%s|%u|%s', jobId, sanitize(soulKey), unlocked, kvStr)

    if not force and hud.lastSigByCharId[cid] == payload then
        return
    end

    hud.lastSigByCharId[cid] = payload
    hud.lastSentAtByCharId[cid] = now
    player:printToPlayer(hud.PROTO_TAG .. payload, xi.msg.channel.SYSTEM_3, '')
end

-----------------------------------
-- Built-in Soul Providers (Initial Examples)
-----------------------------------

-- COR Gambler
hud.registerProvider('gambler', function(player)
    local activeRolls = 0
    if player.getStatusEffects then
        for _, eff in pairs(player:getStatusEffects() or {}) do
            if eff and eff.getSourceType and eff:getSourceType() == xi.effectSourceType.CORSAIR_ROLL then
                activeRolls = activeRolls + 1
            end
        end
    end

    local gmb = xi.overlords.cor and xi.overlords.cor.getGamblerHudState and xi.overlords.cor.getGamblerHudState(player) or {}
    local duRem, duEff = effectRemSec(player, xi.effect.DOUBLE_UP_CHANCE)
    local rollTotal = player:getLocalVar('corsairRollTotal') or 0
    local overdrive = player:getLocalVar('corsairRollBonus') == 1 and 1 or 0
    local debtRem = effectRemSec(player, xi.effect.HOUSE_DEBT or 882)
    local ccRem, ccEff = effectRemSec(player, xi.effect.CARD_COUNTING or 883)
    local snakeActive = player:hasStatusEffect(xi.effect.SNAKE_EYE) and 1 or 0

    local ccType = 0
    if ccEff ~= nil and ccEff.getSubPower then
        ccType = ccEff:getSubPower() or 0
    elseif ccEff ~= nil and ccEff.getPower then
        ccType = ccEff:getPower() or 0
    end

    return {
        rolls     = activeRolls,
        ante_n    = gmb.anteCount or 0,
        ante_hp   = gmb.anteHp or 0,
        ante_tp   = gmb.anteTp or 0,
        roll_tot  = duEff ~= nil and rollTotal or 0,
        du_rem    = duRem,
        roll_lock = gmb.rollLockRem or 0,
        overdrive = (duEff ~= nil and overdrive == 1) and 1 or 0,
        last_cdr  = gmb.lastCdr or 0,
        debt_rem  = debtRem,
        snake_act = snakeActive,
        cc_rem    = ccRem,
        cc_type   = ccType,
    }
end)

-- DNC Mirage Sentinel
hud.registerProvider('mirage_sentinel', function(player)
    local fm = 0
    if player:hasStatusEffect(xi.effect.FINISHING_MOVE_1) then
        local fmEff = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
        fm = fmEff and fmEff:getPower() or 1
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_2) then
        fm = 2
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_3) then
        fm = 3
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_4) then
        fm = 4
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_5) then
        fm = 5
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_6) then
        fm = 5
    end

    local fanRem, fanEff = effectRemSec(player, xi.effect.FAN_DANCE)
    local fanDt = 0
    if fanEff ~= nil then
        fanDt = math.max(15, math.min(45, fanEff:getPower() or 45))
    end

    local issekRem = effectRemSec(player, xi.effect.ISSEKIGAN)
    local aegisHp = player:getLocalVar('OX_DNC_AEGIS_WALTZ') or 0
    local aegisExp = player:getLocalVar('OX_DNC_AEGIS_WALTZ_EXP') or 0
    local aegisRem = (aegisHp > 0 and aegisExp > os.time()) and (aegisExp - os.time()) or 0
    if aegisRem <= 0 then
        aegisHp = 0
    end

    return {
        fm         = fm,
        fan_act    = fanEff ~= nil and 1 or 0,
        fan_dt     = fanDt,
        fan_rem    = fanRem,
        issek_rem  = issekRem,
        parry_fm   = player:getLocalVar('OX_DNC_PARRY_FM') or 0,
        aegis_hp   = aegisHp,
        aegis_rem  = aegisRem,
    }
end)

-- COR Flintlock (reads standard localVars if/when server gameplay is implemented; fails gracefully)
hud.registerProvider('flintlock', function(player)
    local markRem = math.max(0, (player:getLocalVar('OX_FLT_MARK_EXP') or 0) - os.time())
    return {
        powder   = player:getLocalVar('OX_FLT_BLACK_POWDER') or 0,
        mark_rem = markRem,
    }
end)

-----------------------------------
-- Lifecycle & Event Hooks
-----------------------------------
local function attachHudListeners(player)
    if player == nil or not player:isPC() then
        return
    end

    local function onDirty(actor)
        if actor ~= nil and actor:isPC() then
            hud.sync(actor, false)
        end
    end

    player:addListener('ABILITY_USE', 'OX_SOULHUD_ABILITY', onDirty)
    player:addListener('EFFECT_GAIN', 'OX_SOULHUD_EFF_GAIN', onDirty)
    player:addListener('EFFECT_LOSE', 'OX_SOULHUD_EFF_LOSE', onDirty)
    player:addListener('TAKE_DAMAGE', 'OX_SOULHUD_DMG', onDirty)
    player:addListener('PLAYER_DEATH', 'OX_SOULHUD_DEATH', function(p)
        hud.sync(p, true)
    end)
    player:addListener('RAISE_RECEIVED', 'OX_SOULHUD_RAISE', function(p)
        hud.sync(p, true)
    end)
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        attachHudListeners(player)
        hud.sync(player, true)
    end
end)

if spec and spec.refreshPlayer then
    local prevRefresh = spec.refreshPlayer
    spec.refreshPlayer = function(player, ...)
        local res = prevRefresh(player, ...)
        if player ~= nil and player:isPC() then
            hud.sync(player, true)
        end
        return res
    end
end

return m
