-----------------------------------
-- OverlordsXI BST 3: Beastspeaker (Sequence E — Targeted Defense/Support)
-- Read Quarry (family + weakest physical type, unknown fallback) & Expose Quarry (pet delivery).
-- Additive to bst_specs.lua (preserves Alpha Warden & Untamed).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_bst_beastspeaker')
local spec = xi.overlords.spec
local BST = xi.job.BST
local KEY = 'beastspeaker'

local VAR_READ_CD   = 'OX_BSP_READ_CD'
local VAR_EXPOSE_CD = 'OX_BSP_EXPOSE_CD'

local PHYS_ORDER = { 'blunt', 'slashing', 'piercing' } -- Tie priority: blunt -> slash -> pierce

local lastReadByChar = {}
local pendingExposeByChar = {}
local exposureByTarget = {} -- One exposure per enemy: { dmgType, pct, untilSec, claimsByActor }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isBeastspeaker(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == BST and player:getMainLvl() >= 10 and
        spec.is(player, BST, KEY)
end

local function clearState(player)
    if player and player.getID then
        lastReadByChar[player:getID()] = nil
        pendingExposeByChar[player:getID()] = nil
    end
end

-- Read Quarry (15y, 10s CD): identifies family & weakest physical type (blunt -> slash -> pierce).
-- Lv50+ permits manual override among blunt/slashing/piercing.
local function readQuarry(player, target, opts)
    opts = opts or {}
    if not isBeastspeaker(player) then return nil, 'not_beastspeaker' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 15 then return nil, 'out_of_range' end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_READ_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 10 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_READ_CD, now) end

    local knownFamily = opts.family ~= nil and opts.family ~= 'unknown'
    local bestType = 'blunt'
    if knownFamily and type(opts.resistances) == 'table' then
        local minVal = nil
        for _, dt in ipairs(PHYS_ORDER) do
            local v = opts.resistances[dt] or 0
            if minVal == nil or v < minVal then
                minVal = v
                bestType = dt
            end
        end
    end
    if player:getMainLvl() >= 50 and (opts.manualType == 'blunt' or opts.manualType == 'slashing' or opts.manualType == 'piercing') then
        bestType = opts.manualType
    end

    local readRec =
    {
        targetId    = target:getID(),
        knownFamily = knownFamily,
        family      = opts.family or 'unknown',
        dmgType     = bestType,
        lastAbility = player:getMainLvl() >= 30 and opts.lastAbility or nil,
    }
    lastReadByChar[player:getID()] = readRec
    return readRec
end

-- Expose Quarry (25s CD): requires engaged pet on SAME target; next landed pet melee hit within 6s applies exposure.
local function orderExpose(player, pet, target)
    if not isBeastspeaker(player) then return nil, 'not_beastspeaker' end
    if not pet or not pet.isAlive or not pet:isAlive() then return nil, 'no_pet' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    local petTgt = pet.getTarget and pet:getTarget() or nil
    if not petTgt or petTgt:getID() ~= target:getID() then
        return nil, 'pet_wrong_target'
    end
    local readRec = lastReadByChar[player:getID()]
    if not readRec or readRec.targetId ~= target:getID() then
        return nil, 'not_read'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_EXPOSE_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 25 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_EXPOSE_CD, now) end

    local pending =
    {
        targetId    = target:getID(),
        petId       = pet:getID(),
        dmgType     = readRec.dmgType,
        knownFamily = readRec.knownFamily,
        untilSec    = now + 6,
    }
    pendingExposeByChar[player:getID()] = pending
    return pending
end

local function onPetMeleeHit(player, pet, target, damage)
    if not player or not pet or not target or type(damage) ~= 'number' or damage <= 0 then return nil end
    local pending = pendingExposeByChar[player:getID()]
    if not pending then return nil end
    local now = xi.overlords.nowSec()
    if now > pending.untilSec or pet:getID() ~= pending.petId or target:getID() ~= pending.targetId then
        if now > pending.untilSec then pendingExposeByChar[player:getID()] = nil end
        return nil
    end
    pendingExposeByChar[player:getID()] = nil

    local lvl = player:getMainLvl()
    local pct = pending.knownFamily and scale(lvl, 8, 10, 10, 12) or (lvl >= 70 and 6 or 4)
    local dur = lvl >= 50 and 10 or 8

    -- One exposure per enemy (never compounds).
    local exp = { dmgType = pending.dmgType, pct = pct, untilSec = now + dur, claimsByActor = {}, lastRoundByActor = {} }
    exposureByTarget[target:getID()] = exp
    return exp
end

-- Apply +8/10/12% (or +4/6% unknown) to matching allied regular physical hits (up to 2 per actor; 1 per round).
-- Never applies to WS or skillchains.
local function applyExposure(actor, target, dmgType, damage, opts)
    opts = opts or {}
    if type(damage) ~= 'number' or damage <= 0 or opts.isWeaponSkill or opts.isSkillchain then
        return damage, false
    end
    local exp = target and target.getID and exposureByTarget[target:getID()] or nil
    if not exp then return damage, false end
    local now = xi.overlords.nowSec()
    if now > exp.untilSec then
        exposureByTarget[target:getID()] = nil
        return damage, false
    end
    if exp.dmgType ~= dmgType then return damage, false end

    local aid = actor and actor.getID and actor:getID() or 0
    local claims = exp.claimsByActor[aid] or 0
    if claims >= 2 then return damage, false end
    if opts.roundSeq ~= nil and exp.lastRoundByActor[aid] == opts.roundSeq then
        return damage, false -- Multiattack subhits in one round claim at most once
    end

    exp.claimsByActor[aid] = claims + 1
    exp.lastRoundByActor[aid] = opts.roundSeq
    return math.floor(damage * (100 + exp.pct) / 100), true
end

xi.overlords.beastspeaker =
{
    readQuarry    = readQuarry,
    orderExpose   = orderExpose,
    onPetMeleeHit = onPetMeleeHit,
    applyExposure = applyExposure,
    clearState    = clearState,
}

if BST ~= nil then
    spec.registerCrystal(xi.job.BST,
    {
        id = 3,
        key = KEY,
        name = 'Beastspeaker',
        abr = 'BSP',
        role = 'Support',
        icon = 'beastspeaker',
        reqLevel = 10,
        description = 'An ecological Beastmaster who reads enemy families and sends its beast to expose blunt, slashing, or piercing weaknesses for physical allies.',
        highlights =
        {
            'Read Quarry (15y, 10s CD) identifies weakest physical type (blunt->slash->pierce; manual override at Lv50+).',
            'Expose Quarry (25s CD): engaged pet on same target delivers 8/10s exposure (+8/10/12% known, +4/6% unknown, up to 2 hits/actor).',
            'One exposure per enemy; multiattack rounds claim at most once; WS and skillchains excluded.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.AXE, scale(level, 10, 18, 28, 38) },
                { xi.mod.ACC, scale(level, 10, 18, 28, 38) },
            }
        end,
        onRemove = clearState,
    })
end

return m
