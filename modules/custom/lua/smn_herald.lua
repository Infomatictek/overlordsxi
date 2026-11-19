-----------------------------------
-- OverlordsXI SMN 3: Herald (Sequence E — Targeted Defense/Support)
-- Astral Accord: snapshots in-range party PCs for one matching elemental hit per actor (8/10/10/12%).
-- Additive to smn_specs.lua (preserves Celestial & Primalist).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_smn_herald')
local spec = xi.overlords.spec
local SMN = xi.job.SMN
local KEY = 'herald'

local VAR_ACCORD_CD = 'OX_HLD_ACCORD_CD'
local AVATAR_ELEMENTS =
{
    ifrit = 'fire', shiva = 'ice', garuda = 'wind',
    titan = 'earth', ramuh = 'lightning', leviathan = 'water', carbuncle = 'light',
}

local accordByHerald = {}
local accordByMember = {} -- memberId -> { heraldId, element, pct, untilSec, claimed, zoneId }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isHerald(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == SMN and player:getMainLvl() >= 10 and
        spec.is(player, SMN, KEY)
end

-- Dismissing/changing avatar or removing Soul ends the accord immediately.
local function endAccord(herald)
    if not herald or not herald.getID then return end
    local hid = herald:getID()
    local acc = accordByHerald[hid]
    if acc then
        for memberId, _ in pairs(acc.members) do
            if accordByMember[memberId] and accordByMember[memberId].heraldId == hid then
                accordByMember[memberId] = nil
            end
        end
    end
    accordByHerald[hid] = nil
end

-- Astral Accord (30s CD, 8s Lv10-69 / 10s Lv70-75, 15y snapshot, 8% max MP, requires living avatar).
-- Same-element refresh never restores an already-spent claim for an actor.
local function castAccord(herald, avatarKey, partyMembers)
    if not isHerald(herald) then return nil, 'not_herald' end
    local elem = AVATAR_ELEMENTS[avatarKey]
    if not elem then return nil, 'no_living_avatar' end

    local now = xi.overlords.nowSec()
    local last = herald.getLocalVar and (herald:getLocalVar(VAR_ACCORD_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 30 then return nil, 'on_recast' end
    if herald.setLocalVar then herald:setLocalVar(VAR_ACCORD_CD, now) end

    local lvl = herald:getMainLvl()
    local pct = scale(lvl, 8, 10, 10, 12)
    local dur = lvl >= 70 and 10 or 8
    local hZone = herald.getZoneID and herald:getZoneID() or 0

    local members = {}
    for _, member in ipairs(partyMembers or { herald }) do
        if member and member.isPC and member:isPC() and member.isAlive and member:isAlive() then
            local inRange = member:getID() == herald:getID() or not herald.checkDistance or herald:checkDistance(member) <= 15
            local sameZ = (member.getZoneID and member:getZoneID() or 0) == hZone
            if inRange and sameZ then
                local mid = member:getID()
                local prev = accordByMember[mid]
                -- One accord per actor; same-element refresh never restores a spent claim.
                local alreadyClaimed = (prev ~= nil and prev.untilSec > now and prev.element == elem and prev.claimed)
                if not (prev and prev.untilSec > now and prev.pct > pct) then
                    accordByMember[mid] =
                    {
                        heraldId = herald:getID(),
                        element  = elem,
                        pct      = pct,
                        untilSec = now + dur,
                        claimed  = alreadyClaimed,
                        zoneId   = hZone,
                    }
                    members[mid] = true
                end
            end
        end
    end

    local acc = { element = elem, pct = pct, untilSec = now + dur, members = members }
    accordByHerald[herald:getID()] = acc
    return acc
end

-- Claim Accord bonus (+8/10/10/12% ordinary damage) once per participating PC (pet + master share one claim).
-- Excludes extra Soul burst, recursive procs, and periodic ticks.
local function claimAccordBonus(ownerPC, element, ordinaryDamage, opts)
    opts = opts or {}
    if type(ordinaryDamage) ~= 'number' or ordinaryDamage <= 0 or opts.isPeriodicTick or opts.isExtraSoulBurst then
        return ordinaryDamage, false
    end
    if not ownerPC or not ownerPC.getID or not ownerPC.isAlive or not ownerPC:isAlive() then
        return ordinaryDamage, false
    end

    local entry = accordByMember[ownerPC:getID()]
    if not entry or entry.claimed then return ordinaryDamage, false end
    local now = xi.overlords.nowSec()
    if now > entry.untilSec or entry.element ~= element then return ordinaryDamage, false end
    if (ownerPC.getZoneID and ownerPC:getZoneID() or 0) ~= entry.zoneId then return ordinaryDamage, false end

    entry.claimed = true
    return math.floor(ordinaryDamage * (100 + entry.pct) / 100), true
end

xi.overlords.herald =
{
    castAccord       = castAccord,
    claimAccordBonus = claimAccordBonus,
    endAccord        = endAccord,
}

if SMN ~= nil then
    spec.registerCrystal(xi.job.SMN,
    {
        id = 3,
        key = KEY,
        name = 'Herald',
        abr = 'HLD',
        role = 'Support',
        icon = 'herald',
        reqLevel = 10,
        description = 'An elemental coordinator who invokes Astral Accord to empower each in-range party member\'s next matching elemental action.',
        highlights =
        {
            'Astral Accord (30s CD, 8/10s, 15y snapshot, 8% MP): +8/10/10/12% ordinary damage on each member\'s first matching elemental hit.',
            'Master and pet share one claim; same-element refresh never restores a spent claim; avatar swap ends Accord.',
            'Excludes periodic ticks and extra Soul burst; solo Herald follows through with its own avatar Rage.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.SUMMONING_MAGIC_SKILL, scale(level, 10, 18, 28, 38) },
                { xi.mod.MPP,                   scale(level, 6, 10, 14, 18) },
            }
        end,
        onRemove = endAccord,
    })
end

return m
