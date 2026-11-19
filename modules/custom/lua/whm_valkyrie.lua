-----------------------------------
-- OverlordsXI WHM 3: Valkyrie (Sequence E — Targeted Defense/Support)
-- Wingmate ally selection + Valkyrie's Escort cast-interruption rescue.
-- Additive to whm_specs.lua (preserves Bishop & Zealot).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_whm_valkyrie')
local spec = xi.overlords.spec
local WHM = xi.job.WHM
local KEY = 'valkyrie'

local VAR_WINGMATE_CD = 'OX_VLK_WINGMATE_CD'
local VAR_ESCORT_CD   = 'OX_VLK_ESCORT_CD'

local wingmateByChar = {}
local interruptByCaster = {} -- Keyed by casterId: { spellId, seq, deadline, claimed }
local activeEscortByCaster = {} -- Keyed by casterId: { spellId, untilSec, refundPct, ownerId }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isValkyrie(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == WHM and player:getMainLvl() >= 10 and
        spec.is(player, WHM, KEY)
end

local function clearState(player)
    if player and player.getID then
        wingmateByChar[player:getID()] = nil
    end
end

-- Wingmate: select one party PC within 15y (or self for solo onboarding from Lv10), 5s recast.
local function selectWingmate(player, ally)
    if not isValkyrie(player) then return false, 'not_valkyrie' end
    if not ally or not ally.isPC or not ally:isPC() or not ally.isAlive or not ally:isAlive() then
        return false, 'invalid_ally'
    end
    if ally:getID() ~= player:getID() and player.checkDistance and player:checkDistance(ally) > 15 then
        return false, 'out_of_range'
    end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_WINGMATE_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 5 then return false, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_WINGMATE_CD, now) end
    wingmateByChar[player:getID()] = ally:getID()
    return true, ally:getID()
end

-- Record native cast interruption ONLY when caused by damage from an engaged hostile.
-- Never treat movement, manual cancel, Silence, death, finishing, insufficient MP, or target change as interrupts.
local function onCastInterrupted(caster, spellId, seq, opts)
    opts = opts or {}
    if not caster or not caster.isPC or not caster:isPC() or not opts.fromHostileDamage then
        return false
    end
    if opts.manualCancel or opts.movement or opts.silenced or opts.died or opts.insufficientMP then
        return false
    end
    local now = xi.overlords.nowSec()
    interruptByCaster[caster:getID()] =
    {
        spellId  = spellId,
        seq      = seq,
        deadline = now + 6,
        claimed  = false,
    }
    return true
end

-- Valkyrie's Escort (25s CD, 15y Lv10-49 / 20y Lv50+): atomically claims interruption for Wingmate,
-- granting one retry of the exact same spell within 6s with +100% spell interruption resistance
-- and 0/15/15/25% MP refund on completed retry (self-solo: 0% until Lv50, half refund from Lv50+).
local function executeEscort(player, ally)
    if not isValkyrie(player) then return nil, 'not_valkyrie' end
    if not ally or wingmateByChar[player:getID()] ~= ally:getID() then
        return nil, 'not_wingmate'
    end
    local maxRange = player:getMainLvl() >= 50 and 20 or 15
    if ally:getID() ~= player:getID() and player.checkDistance and player:checkDistance(ally) > maxRange then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_ESCORT_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 25 then return nil, 'on_recast' end

    local intr = interruptByCaster[ally:getID()]
    if not intr or intr.claimed or now > intr.deadline then
        return nil, 'no_claimable_interrupt'
    end

    -- First Escort atomically claims the interruption; a second Valkyrie cannot consume it.
    intr.claimed = true
    if player.setLocalVar then player:setLocalVar(VAR_ESCORT_CD, now) end

    local lvl = player:getMainLvl()
    local refundPct = scale(lvl, 0, 15, 15, 25)
    if ally:getID() == player:getID() then
        refundPct = lvl >= 50 and math.floor(refundPct / 2) or 0
    end

    local escort =
    {
        spellId   = intr.spellId,
        untilSec  = now + 6,
        refundPct = refundPct,
        sirdBonus = 100,
        ownerId   = player:getID(),
    }
    activeEscortByCaster[ally:getID()] = escort
    return escort
end

local function resolveEscortedRetry(caster, spellId, actualMpSpent, completed)
    local escort = caster and caster.getID and activeEscortByCaster[caster:getID()] or nil
    if not escort then return 0, false end
    local now = xi.overlords.nowSec()
    if now > escort.untilSec or escort.spellId ~= spellId then
        if now > escort.untilSec then activeEscortByCaster[caster:getID()] = nil end
        return 0, false
    end
    activeEscortByCaster[caster:getID()] = nil
    if not completed or type(actualMpSpent) ~= 'number' or actualMpSpent <= 0 then
        return 0, true
    end
    local refund = math.floor(actualMpSpent * escort.refundPct / 100)
    if refund > actualMpSpent then refund = actualMpSpent end
    return refund, true
end

xi.overlords.valkyrie =
{
    selectWingmate       = selectWingmate,
    onCastInterrupted    = onCastInterrupted,
    executeEscort        = executeEscort,
    resolveEscortedRetry = resolveEscortedRetry,
    clearState           = clearState,
}

if WHM ~= nil then
    spec.registerCrystal(xi.job.WHM,
    {
        id = 3,
        key = KEY,
        name = 'Valkyrie',
        abr = 'VLK',
        role = 'Support',
        icon = 'valkyrie',
        reqLevel = 10,
        description = 'A polearm interventionist who designates a Wingmate and escorts retries of enemy-damage-interrupted spells with +100% interruption resistance.',
        highlights =
        {
            'Wingmate (15y, 5s CD) designates a party PC (or self solo); enemy-damage interruption arms Escort for 6s.',
            'Valkyrie\'s Escort (25s CD): atomically claims interruption for one +100% SIRD retry of the same spell + 0/15/15/25% MP refund.',
            'Manual cancel, movement, Silence, and death never arm Escort; a second Valkyrie cannot claim the same interruption.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.POLEARM, scale(level, 10, 18, 28, 38) },
                { xi.mod.HPP,     scale(level, 6, 10, 14, 18) },
                { xi.mod.MEVA,    scale(level, 8, 14, 22, 30) },
            }
        end,
        onRemove = clearState,
    })
end

return m
