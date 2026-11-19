-----------------------------------
-- OverlordsXI RNG 3: Arcane Archer (Sequence E — Targeted Defense/Support)
-- Six elemental Attunement Arrow marks (16s shared recast, 20y, one mark per target & per archer).
-- Additive to rng_specs.lua (preserves Huntsman & Sniper).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_rng_arcane_archer')
local spec = xi.overlords.spec
local RNG = xi.job.RNG
local KEY = 'arcanearcher'

local VAR_ARROW_CD = 'OX_ACA_ARROW_CD'
local VALID_ELEMENTS = { fire = true, ice = true, wind = true, earth = true, lightning = true, water = true }

local markByTarget = {} -- Keyed by targetId -> { archerId, partyId, element, pct, untilSec }
local markByArcher = {} -- Keyed by archerId -> targetId

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isArcaneArcher(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == RNG and player:getMainLvl() >= 10 and
        spec.is(player, RNG, KEY)
end

local function clearArcherMark(player)
    if not player or not player.getID then return end
    local oldTarget = markByArcher[player:getID()]
    if oldTarget and markByTarget[oldTarget] and markByTarget[oldTarget].archerId == player:getID() then
        markByTarget[oldTarget] = nil
    end
    markByArcher[player:getID()] = nil
end

-- Fire Attunement Arrow (20y, 16s shared recast, 10/12/12/14s mark, +12/15/18/20%).
-- Miss spends ammo and recast but sets no mark (and does not remove existing mark).
-- Landed arrow replaces this archer's prior mark on another target and any older mark on this target.
local function fireAttunementArrow(player, target, element, opts)
    opts = opts or {}
    if not isArcaneArcher(player) then return nil, 'not_arcane_archer' end
    if not VALID_ELEMENTS[element] then return nil, 'invalid_element' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 20 then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_ARROW_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 16 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_ARROW_CD, now) end

    if opts.missed then
        return nil, 'missed'
    end

    clearArcherMark(player)
    local lvl = player:getMainLvl()
    local dur = (lvl >= 70 and 14) or (lvl >= 30 and 12) or 10
    local pct = scale(lvl, 12, 15, 18, 20)
    local mark =
    {
        archerId = player:getID(),
        partyId  = opts.partyId or 0,
        element  = element,
        pct      = pct,
        untilSec = now + dur,
    }
    markByTarget[target:getID()] = mark
    markByArcher[player:getID()] = target:getID()
    return mark, 'marked'
end

-- Atomically consume mark on first matching direct elemental spell or elemental skillchain from same-party PC
-- (or solo own elemental bow WS at half bonus). Excludes DoTs, wrong elements, unrelated parties, and Astro bonus component.
local function consumeMark(actor, target, element, ordinaryDamage, opts)
    opts = opts or {}
    if type(ordinaryDamage) ~= 'number' or ordinaryDamage <= 0 then return ordinaryDamage, false end
    if opts.isDoT or not target or not actor or not actor.getID then return ordinaryDamage, false end

    local mark = markByTarget[target:getID()]
    if not mark then return ordinaryDamage, false end
    local now = xi.overlords.nowSec()
    if now > mark.untilSec then
        markByTarget[target:getID()] = nil
        return ordinaryDamage, false
    end
    if mark.element ~= element then return ordinaryDamage, false end

    local isSelf = actor:getID() == mark.archerId
    if not isSelf and (opts.partyId or 0) ~= mark.partyId then
        return ordinaryDamage, false
    end
    if isSelf and not opts.isOwnElementalBowWS then
        return ordinaryDamage, false
    end
    if not isSelf and not (opts.isDirectElementalSpell or opts.isElementalSkillchain or opts.isAlliedPetAction) then
        return ordinaryDamage, false
    end

    -- Atomic single consumption
    markByTarget[target:getID()] = nil
    if markByArcher[mark.archerId] == target:getID() then
        markByArcher[mark.archerId] = nil
    end

    local effectivePct = isSelf and math.floor(mark.pct / 2) or mark.pct
    return math.floor(ordinaryDamage * (100 + effectivePct) / 100), true
end

xi.overlords.arcaneArcher =
{
    fireAttunementArrow = fireAttunementArrow,
    consumeMark         = consumeMark,
    clearArcherMark     = clearArcherMark,
}

if RNG ~= nil then
    spec.registerCrystal(xi.job.RNG,
    {
        id = 3,
        key = KEY,
        name = 'Arcane Archer',
        abr = 'ACA',
        role = 'Support',
        icon = 'arcanearcher',
        reqLevel = 10,
        description = 'A bow support who lands one of six elemental Attunement Arrows to amplify a party member\'s next matching elemental spell or skillchain.',
        highlights =
        {
            'Attunement Arrow (20y, 16s shared recast): marks enemy for 10/12/12/14s (+12/15/18/20% on first matching party elemental hit).',
            'Solo onboarding: archer can consume its own mark with an elemental bow WS at half bonus.',
            'One mark per target and per archer; misses spend ammo/recast without overwriting marks; DoTs/wrong elements never claim.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.ARCHERY, scale(level, 12, 20, 30, 42) },
                { xi.mod.RACC,    scale(level, 10, 18, 28, 38) },
                { xi.mod.MACC,    scale(level, 8, 14, 22, 30) },
            }
        end,
        onRemove = clearArcherMark,
    })
end

return m
