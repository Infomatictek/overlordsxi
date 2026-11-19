-----------------------------------
-- OverlordsXI GEO 1: Diviner (Sequence E — Targeted Defense/Support)
-- Geometric Axis corridor from stationary anchor to mobile caster (length 3-15y, width 2/2.5y, |dy| <= 3y).
-- Additive to geo_specs.lua (preserves Verdant & Terramancer).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_geo_diviner')
local spec = xi.overlords.spec
local GEO = xi.job.GEO
local KEY = 'diviner'

local VAR_LAY_CD   = 'OX_DIV_LAY_CD'
local VAR_SHIFT_CD = 'OX_DIV_SHIFT_CD'

local meridiansByDiviner = {} -- divinerId -> { anchor = {x,y,z}, zoneId, untilSec, width, bonus }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isDiviner(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == GEO and player:getMainLvl() >= 10 and
        spec.is(player, GEO, KEY)
end

-- Recall Meridian (free) / cleanup on death, zone, or Soul change.
local function recallMeridian(player)
    if player and player.getID then
        meridiansByDiviner[player:getID()] = nil
    end
end

-- Lay Meridian (18s CD, 30s Lv10-69 / 40s Lv70-75): places stationary anchor at caster's current position.
local function layMeridian(player, pos)
    if not isDiviner(player) then return nil, 'not_diviner' end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_LAY_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 18 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_LAY_CD, now) end

    local lvl = player:getMainLvl()
    local rec =
    {
        anchor   = { x = pos.x or 0, y = pos.y or 0, z = pos.z or 0 },
        zoneId   = player.getZoneID and player:getZoneID() or 0,
        untilSec = now + (lvl >= 70 and 40 or 30),
        width    = lvl >= 50 and 2.5 or 2.0,
        bonus    = scale(lvl, 12, 20, 28, 35),
    }
    meridiansByDiviner[player:getID()] = rec
    return rec
end

-- Meridian Shift (Lv30+, 20s CD): moves anchor to caster's current position WITHOUT refreshing lifetime.
-- Segment is temporarily inactive until caster moves at least 3y away.
local function shiftMeridian(player, pos)
    if not isDiviner(player) or player:getMainLvl() < 30 then return nil, 'invalid_state' end
    local rec = meridiansByDiviner[player:getID()]
    local now = xi.overlords.nowSec()
    if not rec or now >= rec.untilSec then return nil, 'no_meridian' end

    local last = player.getLocalVar and (player:getLocalVar(VAR_SHIFT_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 20 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_SHIFT_CD, now) end

    rec.anchor = { x = pos.x or 0, y = pos.y or 0, z = pos.z or 0 }
    return rec
end

-- Pure 2D segment projection clamped to endpoints [0, 1] + length [3..15y] + vertical <=3y + zone check.
local function isInsideMeridian(rec, casterPos, allyPos, allyZoneId)
    if not rec or xi.overlords.nowSec() >= rec.untilSec then return false end
    if (allyZoneId or 0) ~= rec.zoneId then return false end

    local ax, ay, az = rec.anchor.x, rec.anchor.y, rec.anchor.z
    local bx, by, bz = casterPos.x or 0, casterPos.y or 0, casterPos.z or 0
    local vx, vz = bx - ax, bz - az
    local lenSq = vx * vx + vz * vz
    local len = math.sqrt(lenSq)

    -- Segment active ONLY at length 3..15y and same floor (|dy| <= 3y).
    if len < 3.0 or len > 15.0 or math.abs(by - ay) > 3.0 then
        return false
    end

    local px, py, pz = allyPos.x or 0, allyPos.y or 0, allyPos.z or 0
    local t = ((px - ax) * vx + (pz - az) * vz) / lenSq
    if t < 0 then t = 0 elseif t > 1 then t = 1 end

    -- Must not exceed endpoints (clamped projection + explicit segment-end rejection beyond width)
    local cx = ax + t * vx
    local cz = az + t * vz
    local cy = ay + t * (by - ay)

    local dx, dz = px - cx, pz - cz
    local dist2d = math.sqrt(dx * dx + dz * dz)
    if dist2d > rec.width then return false end
    if math.abs(py - cy) > 3.0 then return false end
    return true
end

-- Sample strongest active meridian covering ally (multiple Diviners grant strongest only; leaving stronger restores weaker).
local function sampleAllyBonus(allyPos, allyZoneId, casterPosByDivinerId)
    local best = 0
    local now = xi.overlords.nowSec()
    for did, rec in pairs(meridiansByDiviner) do
        if now >= rec.untilSec then
            meridiansByDiviner[did] = nil
        else
            local cpos = casterPosByDivinerId and casterPosByDivinerId[did]
            if cpos and isInsideMeridian(rec, cpos, allyPos, allyZoneId) then
                if rec.bonus > best then best = rec.bonus end
            end
        end
    end
    return best
end

xi.overlords.diviner =
{
    layMeridian      = layMeridian,
    shiftMeridian    = shiftMeridian,
    recallMeridian   = recallMeridian,
    isInsideMeridian = isInsideMeridian,
    sampleAllyBonus  = sampleAllyBonus,
}

if GEO ~= nil then
    spec.registerCrystal(xi.job.GEO,
    {
        id = 1,
        key = KEY,
        name = 'Diviner',
        abr = 'DIV',
        role = 'Support',
        icon = 'diviner',
        reqLevel = 10,
        description = 'A geometric Geomancer who anchors a Meridian corridor between a ground point and themselves, granting ACC and MACC to allies inside the lane.',
        highlights =
        {
            'Lay Meridian (18s CD, 30/40s): active corridor 3–15y long, 2.0/2.5y wide, |dy| <= 3y granting +12/20/28/35 ACC & MACC.',
            'Meridian Shift (Lv30+, 20s CD) reanchors at caster without refreshing lifetime; Recall is free.',
            'Multiple Diviners grant only the strongest active segment; leaving the stronger restores the weaker on next sample.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.GEOMANCY, scale(level, 10, 18, 28, 38) },
                { xi.mod.HPP,      scale(level, 4, 6, 8, 10) },
            }
        end,
        onRemove = recallMeridian,
    })
end

return m
