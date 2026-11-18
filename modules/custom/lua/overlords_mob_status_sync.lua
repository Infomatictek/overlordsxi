-----------------------------------
-- OverlordsXI Live Mob Buff/Debuff Stream
--
-- Streams the current enemy target's (or [CustomBoss]CombatMobId's) status
-- effects to the Ashita `debuffed` addon via silent [OXMOB]|... 0x017 packets.
--
-- Wire format (one or more messages, <= 135 chars each):
--   [OXMOB]|<mobServerId>|<part>/<parts>|<effectId>:<iconId>:<power>:<subPower>:<isDebuff>:<remSec>,...
-- A message with zero entries is `[OXMOB]|<mobId>|1/1|` (clears the mob).
-- `[OXMOB]|0|1/1|` means "no tracked mob".
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('overlords_mob_status_sync')

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.mobStatus = xi.overlords.mobStatus or {}
local ms = xi.overlords.mobStatus

ms.PROTO_TAG   = '[OXMOB]|'
ms.lastSig     = ms.lastSig or {}
ms.lastSentAt  = ms.lastSentAt or {}
ms.lastMobId   = ms.lastMobId or {}

local MAX_MSG        = 135
local MAX_EFFECTS    = 24
local HEARTBEAT_SEC  = 3
local FLAG_DISPELABLE = 0x00000001
local FLAG_ERASABLE   = 0x00000002

local function hasFlag(flags, mask)
    return (math.floor((flags or 0) / mask) % 2) == 1
end

local function now()
    return os.time()
end

local function charKey(player)
    return player.getID and player:getID() or 0
end

local function isLiveMob(entity)
    if entity == nil or not entity.isMob or not entity:isMob() then
        return false
    end
    if entity.isPet and entity:isPet() then
        return false
    end
    if entity.isAlive and not entity:isAlive() then
        return false
    end
    return true
end

local function resolveMob(player)
    local target = player.getTarget and player:getTarget() or nil
    if isLiveMob(target) then
        return target
    end

    local mobId = player.getLocalVar and player:getLocalVar('[CustomBoss]CombatMobId') or 0
    if mobId and mobId > 0 and GetMobByID then
        local mob = GetMobByID(mobId)
        if isLiveMob(mob) then
            return mob
        end
    end
    return nil
end

local function classify(effectId, eff)
    local reg = xi.overlords.statusRegistry and xi.overlords.statusRegistry[effectId] or nil
    if reg ~= nil then
        return reg.isDebuff and 1 or 0
    end
    local flags = eff.getEffectFlags and eff:getEffectFlags() or 0
    if hasFlag(flags, FLAG_ERASABLE) and not hasFlag(flags, FLAG_DISPELABLE) then
        return 1
    end
    return 0
end

local function collect(mob)
    local out = {}
    local effects = mob.getStatusEffects and mob:getStatusEffects() or {}
    for _, eff in pairs(effects) do
        if eff ~= nil then
            local effectId = eff.getEffectType and eff:getEffectType() or 0
            if effectId and effectId > 0 then
                local rawIcon = nil
                if eff.getIcon then
                    rawIcon = eff:getIcon()
                end
                local iconId = xi.overlords.getStatusIcon and xi.overlords.getStatusIcon(effectId, rawIcon or effectId) or effectId
                local remMs  = eff.getTimeRemaining and eff:getTimeRemaining() or 0
                out[#out + 1] =
                {
                    effectId = effectId,
                    iconId   = iconId,
                    power    = math.floor(eff.getPower and eff:getPower() or 0),
                    subPower = math.floor(eff.getSubPower and eff:getSubPower() or 0),
                    isDebuff = classify(effectId, eff),
                    rem      = math.max(0, math.floor((remMs or 0) / 1000)),
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.isDebuff ~= b.isDebuff then
            return a.isDebuff > b.isDebuff
        end
        return a.effectId < b.effectId
    end)
    while #out > MAX_EFFECTS do
        table.remove(out)
    end
    return out
end

local function signature(list)
    local parts = {}
    for _, e in ipairs(list) do
        parts[#parts + 1] = string.format('%d:%d:%d:%d', e.effectId, e.power, e.subPower, e.isDebuff)
    end
    return table.concat(parts, ',')
end

local function send(player, mobId, list)
    local entries = {}
    for _, e in ipairs(list) do
        entries[#entries + 1] = string.format('%d:%d:%d:%d:%d:%d', e.effectId, e.iconId, e.power, e.subPower, e.isDebuff, e.rem)
    end

    -- Pack entries into <= MAX_MSG chunks.
    local chunks, buf = {}, ''
    local headLen = #ms.PROTO_TAG + 12 + 8
    for _, item in ipairs(entries) do
        local add = (buf == '') and item or (',' .. item)
        if headLen + #buf + #add > MAX_MSG and buf ~= '' then
            chunks[#chunks + 1] = buf
            buf = item
        else
            buf = buf .. add
        end
    end
    chunks[#chunks + 1] = buf

    for i, body in ipairs(chunks) do
        player:printToPlayer(
            string.format('%s%d|%d/%d|%s', ms.PROTO_TAG, mobId, i, #chunks, body),
            xi.msg.channel.SYSTEM_3, '')
    end
end

function ms.sync(player, force)
    if player == nil or not player.isPC or not player:isPC() then
        return
    end

    local ck  = charKey(player)
    local mob = resolveMob(player)
    local t   = now()

    if mob == nil then
        if ms.lastMobId[ck] ~= nil and ms.lastMobId[ck] ~= 0 then
            ms.lastMobId[ck] = 0
            ms.lastSig[ck]   = nil
            player:printToPlayer(ms.PROTO_TAG .. '0|1/1|', xi.msg.channel.SYSTEM_3, '')
        end
        return
    end

    local mobId = mob:getID()
    local list  = collect(mob)
    local sig   = signature(list)

    local changed = (ms.lastMobId[ck] ~= mobId) or (ms.lastSig[ck] ~= sig)
    local due     = (t - (ms.lastSentAt[ck] or 0)) >= HEARTBEAT_SEC

    -- Heartbeat only matters while there is something to count down.
    if changed or force or (due and #list > 0) then
        ms.lastMobId[ck]  = mobId
        ms.lastSig[ck]    = sig
        ms.lastSentAt[ck] = t
        send(player, mobId, list)
    end
end

local function attachListeners(player)
    if player == nil or not player:isPC() then
        return
    end

    local ids =
    {
        'OX_MOBSTATUS_TICK', 'OX_MOBSTATUS_WS', 'OX_MOBSTATUS_ABILITY',
        'OX_MOBSTATUS_MAGIC', 'OX_MOBSTATUS_TARGET', 'OX_MOBSTATUS_ENGAGE',
    }
    for _, id in ipairs(ids) do
        player:removeListener(id)
    end

    local function onTick(actor)
        ms.sync(actor, false)
    end
    local function onAction(actor)
        ms.sync(actor, false)
    end

    player:addListener('EFFECTS_TICK',    'OX_MOBSTATUS_TICK',    onTick)
    player:addListener('WEAPONSKILL_USE', 'OX_MOBSTATUS_WS',      onAction)
    player:addListener('ABILITY_USE',     'OX_MOBSTATUS_ABILITY', onAction)
    player:addListener('MAGIC_USE',       'OX_MOBSTATUS_MAGIC',   onAction)
    -- Target change / engage (listeners are no-ops on cores that never fire them).
    player:addListener('TARGET_CHANGE',   'OX_MOBSTATUS_TARGET',  function(actor) ms.sync(actor, true) end)
    player:addListener('ENGAGE',          'OX_MOBSTATUS_ENGAGE',  function(actor) ms.sync(actor, true) end)
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        ms.lastSig[charKey(player)]    = nil
        ms.lastMobId[charKey(player)]  = nil
        attachListeners(player)
    end
end)

return m
