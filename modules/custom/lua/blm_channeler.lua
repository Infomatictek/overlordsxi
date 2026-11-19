-----------------------------------
-- OverlordsXI BLM 2: Channeler (Sequence E — Targeted Defense/Support)
-- Conduit Link: lends one caster cast-time & MP reduction while holding stance.
-- No conduit onto another Channeler; never accelerates Ancient Magic/instant/item casts.
-- Additive to blm_specs.lua (preserves Necromancer & Astromancer).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_blm_channeler')
local spec = xi.overlords.spec
local BLM = xi.job.BLM
local KEY = 'channeler'

local VAR_LINK_CD = 'OX_CHN_LINK_CD'
local activeLinkByChanneler = {}
local activeLinkByRecipient = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isChanneler(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == BLM and player:getMainLvl() >= 10 and
        spec.is(player, BLM, KEY)
end

local function breakLink(channeler)
    if not channeler or not channeler.getID then return false end
    local link = activeLinkByChanneler[channeler:getID()]
    if not link then return false end
    activeLinkByChanneler[channeler:getID()] = nil
    if activeLinkByRecipient[link.recipientId] == link then
        activeLinkByRecipient[link.recipientId] = nil
    end
    return true
end

-- Start Conduit Link (24s recast, 8s duration, 15y Lv10-49 / 20y Lv50+, 8% max MP).
-- Rejects linking another Channeler already maintaining a channel.
-- Solo self-link exits holding stance immediately and grants MP discount only for 8s.
local function startConduitLink(channeler, recipient)
    if not isChanneler(channeler) then return nil, 'not_channeler' end
    if not recipient or not recipient.isPC or not recipient:isPC() or not recipient.isAlive or not recipient:isAlive() then
        return nil, 'invalid_recipient'
    end
    local isSelf = recipient:getID() == channeler:getID()
    if not isSelf and activeLinkByChanneler[recipient:getID()] ~= nil then
        return nil, 'recipient_is_channeling'
    end
    local maxRange = channeler:getMainLvl() >= 50 and 20 or 15
    if not isSelf and channeler.checkDistance and channeler:checkDistance(recipient) > maxRange then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = channeler.getLocalVar and (channeler:getLocalVar(VAR_LINK_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 24 then return nil, 'on_recast' end
    if channeler.setLocalVar then channeler:setLocalVar(VAR_LINK_CD, now) end

    breakLink(channeler)
    local lvl = channeler:getMainLvl()
    local castSaving = isSelf and 0 or scale(lvl, 20, 25, 25, 30)
    local mpSaving = scale(lvl, 15, 15, 25, 25)
    local relayPct = (not isSelf and lvl >= 30) and 5 or 0

    -- Strongest single link per ally
    local existing = activeLinkByRecipient[recipient:getID()]
    if existing and existing.untilSec > now and (existing.castSaving + existing.mpSaving) >= (castSaving + mpSaving) then
        return nil, 'stronger_link_active'
    end

    local link =
    {
        channelerId = channeler:getID(),
        recipientId = recipient:getID(),
        isSelf      = isSelf,
        holding     = not isSelf,
        castSaving  = castSaving,
        mpSaving    = mpSaving,
        relayPct    = relayPct,
        untilSec    = now + 8,
        reserved    = false,
    }
    activeLinkByChanneler[channeler:getID()] = link
    activeLinkByRecipient[recipient:getID()] = link
    return link
end

-- Reserve single spell benefit at ally cast start.
-- Never accelerates Ancient Magic, Soul emergency casts, instant actions, or item casts.
local function onRecipientCastStart(recipient, nativeCastTime, nativeMpCost, opts)
    opts = opts or {}
    local link = recipient and recipient.getID and activeLinkByRecipient[recipient:getID()] or nil
    if not link then return nativeCastTime, nativeMpCost, false end
    local now = xi.overlords.nowSec()
    if now > link.untilSec or link.reserved then
        return nativeCastTime, nativeMpCost, false
    end
    if opts.isAncientMagic or opts.isSoulEmergency or opts.isInstant or opts.isItemCast then
        return nativeCastTime, nativeMpCost, false
    end
    link.reserved = true
    local newCast = nativeCastTime * (100 - link.castSaving) / 100
    local newMp = math.max(1, math.floor(nativeMpCost * (100 - link.mpSaving) / 100))
    return newCast, newMp, true
end

-- On ally cast completion/cancellation: release link; relay 5% actual MP spent ONLY on completion (Lv30+).
local function onRecipientCastEnd(recipient, actualMpSpent, completed)
    local link = recipient and recipient.getID and activeLinkByRecipient[recipient:getID()] or nil
    if not link or not link.reserved then return 0 end
    activeLinkByChanneler[link.channelerId] = nil
    activeLinkByRecipient[link.recipientId] = nil
    if not completed or link.relayPct <= 0 or type(actualMpSpent) ~= 'number' or actualMpSpent <= 0 then
        return 0
    end
    return math.floor(actualMpSpent * link.relayPct / 100)
end

xi.overlords.channeler =
{
    startConduitLink     = startConduitLink,
    breakLink            = breakLink,
    onRecipientCastStart = onRecipientCastStart,
    onRecipientCastEnd   = onRecipientCastEnd,
}

if BLM ~= nil then
    spec.registerCrystal(xi.job.BLM,
    {
        id = 2,
        key = KEY,
        name = 'Channeler',
        abr = 'CHN',
        role = 'Support',
        icon = 'channeler',
        reqLevel = 10,
        description = 'A conduit caster who sacrifices its own action window to accelerate and discount one ally\'s next eligible spell.',
        highlights =
        {
            'Conduit Link (24s CD, 8s, 15/20y): -20/25/25/30% cast time and -15/15/25/25% MP cost for one ally spell.',
            'At Lv30+, relays 5% of ally\'s actual MP expenditure back to Channeler on completion (0 on cancel).',
            'Never accelerates Ancient Magic, instant actions, or item casts; cannot link another active Channeler.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.MPP,  scale(level, 8, 12, 16, 20) },
                { xi.mod.MACC, scale(level, 8, 14, 22, 30) },
                { xi.mod.HPP,  scale(level, 4, 6, 8, 10) },
            }
        end,
        onRemove = breakLink,
    })
end

return m
