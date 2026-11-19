-----------------------------------
-- OverlordsXI RDM 2: Royal Tactician (Sequence E — Targeted Defense/Support)
-- Converts landed/refreshed enfeebles into Advance (Slow/Paralyze) or Recompose (Blind/Silence).
-- Additive to rdm_specs.lua (preserves Crimson Duelist & Scarlet Weaver).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_rdm_royal_tactician')
local spec = xi.overlords.spec
local RDM = xi.job.RDM
local KEY = 'royaltactician'

local VAR_ORDER_CD   = 'OX_RYT_ORDER_CD'
local VAR_RESIST_CD  = 'OX_RYT_RESIST_FALLBACK_CD'

local pendingOrderByChar = {}
local lastIssuedByChar = {}
local activeOrderByRecipient = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isRoyalTactician(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == RDM and player:getMainLvl() >= 10 and
        spec.is(player, RDM, KEY)
end

local function clearState(player)
    if player and player.getID then
        pendingOrderByChar[player:getID()] = nil
        lastIssuedByChar[player:getID()] = nil
    end
end

-- Enfeebling resolution opens Advance (slow/paralyze), Recompose (blind/silence), or Dispel (last issued; default advance).
-- At Lv50+, full resist opens half-potency fallback on a 24s lockout.
local function onEnfeebleResolved(player, spellKind, opts)
    opts = opts or {}
    if not isRoyalTactician(player) then return nil end

    local orderType
    if spellKind == 'slow' or spellKind == 'paralyze' then
        orderType = 'advance'
    elseif spellKind == 'blind' or spellKind == 'silence' then
        orderType = 'recompose'
    elseif spellKind == 'dispel' and player:getMainLvl() >= 30 then
        orderType = lastIssuedByChar[player:getID()] or 'advance'
    else
        return nil
    end

    local now = xi.overlords.nowSec()
    local halfPotency = false
    if opts.fullResist then
        if player:getMainLvl() < 50 then return nil end
        local lastRes = player.getLocalVar and (player:getLocalVar(VAR_RESIST_CD) or 0) or 0
        if lastRes > now then lastRes = 0 end
        if lastRes ~= 0 and (now - lastRes) < 24 then return nil end
        if player.setLocalVar then player:setLocalVar(VAR_RESIST_CD, now) end
        halfPotency = true
    end

    -- Only latest order is available (overwrites prior pending order).
    local pending = { orderType = orderType, halfPotency = halfPotency, untilSec = now + 6 }
    pendingOrderByChar[player:getID()] = pending
    return pending
end

-- Issue Order (15y, 18s CD): grants Advance (+10/10/10/15% ACC + 0/5/5/8 STP for 8s)
-- or Recompose (-15/20/20/25% MP cost on next completed cost-bearing non-instant spell within 8s).
local function issueOrder(player, ally)
    if not isRoyalTactician(player) then return nil, 'not_royal_tactician' end
    if not ally or not ally.isPC or not ally:isPC() or not ally.isAlive or not ally:isAlive() then
        return nil, 'invalid_ally'
    end
    if ally:getID() ~= player:getID() and player.checkDistance and player:checkDistance(ally) > 15 then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_ORDER_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 18 then return nil, 'on_recast' end

    local pending = pendingOrderByChar[player:getID()]
    if not pending or now > pending.untilSec then
        pendingOrderByChar[player:getID()] = nil
        return nil, 'no_open_order'
    end

    pendingOrderByChar[player:getID()] = nil
    lastIssuedByChar[player:getID()] = pending.orderType
    if player.setLocalVar then player:setLocalVar(VAR_ORDER_CD, now) end

    local lvl = player:getMainLvl()
    local div = pending.halfPotency and 2 or 1
    local order
    if pending.orderType == 'advance' then
        order =
        {
            orderType = 'advance',
            accPct    = math.floor(scale(lvl, 10, 10, 10, 15) / div),
            storeTp   = math.floor(scale(lvl, 0, 5, 5, 8) / div),
            untilSec  = now + 8,
        }
    else
        order =
        {
            orderType  = 'recompose',
            mpDiscount = math.floor(scale(lvl, 15, 20, 20, 25) / div),
            untilSec   = now + 8,
            consumed   = false,
        }
    end

    -- Strongest order per recipient
    local cur = activeOrderByRecipient[ally:getID()]
    if cur and cur.untilSec > now and cur.orderType == order.orderType then
        local curScore = cur.accPct or cur.mpDiscount or 0
        local newScore = order.accPct or order.mpDiscount or 0
        if curScore >= newScore then
            return cur
        end
    end
    activeOrderByRecipient[ally:getID()] = order
    return order
end

-- Recompose consumes only on next completed cost-bearing non-instant spell; never refunds over paid MP.
local function consumeRecompose(ally, mpPaid, opts)
    opts = opts or {}
    local order = ally and ally.getID and activeOrderByRecipient[ally:getID()] or nil
    if not order or order.orderType ~= 'recompose' or order.consumed then return 0 end
    local now = xi.overlords.nowSec()
    if now > order.untilSec then
        activeOrderByRecipient[ally:getID()] = nil
        return 0
    end
    if not opts.completed or opts.isInstant or type(mpPaid) ~= 'number' or mpPaid <= 0 then
        return 0
    end
    order.consumed = true
    activeOrderByRecipient[ally:getID()] = nil
    local refund = math.floor(mpPaid * order.mpDiscount / 100)
    return math.min(mpPaid, refund)
end

xi.overlords.royalTactician =
{
    onEnfeebleResolved = onEnfeebleResolved,
    issueOrder         = issueOrder,
    consumeRecompose   = consumeRecompose,
    clearState         = clearState,
}

if RDM ~= nil then
    spec.registerCrystal(xi.job.RDM,
    {
        id = 2,
        key = KEY,
        name = 'Royal Tactician',
        abr = 'RYT',
        role = 'Support',
        icon = 'royaltactician',
        reqLevel = 10,
        description = 'A tactical Red Mage who converts Slow/Paralyze into Advance orders and Blind/Silence into Recompose orders for targeted allies.',
        highlights =
        {
            'Slow/Paralyze open Advance (+10/15% ACC, +5/8 STP); Blind/Silence open Recompose (-15/20/25% next spell MP).',
            'Dispel (Lv30+) repeats last issued order (default Advance); Lv50+ full resist grants half-potency order (24s ICD).',
            'Latest order overwrites prior pending order; strongest order wins per recipient.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
                { xi.mod.MPP,  scale(level, 6, 10, 14, 18) },
            }
        end,
        onRemove = clearState,
    })
end

return m
