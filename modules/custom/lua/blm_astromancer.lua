-----------------------------------
-- OverlordsXI BLM 1: Astromancer (Sequence C — Isolated Caster)
-- Deliberate Ancient Magic commitment with atomic per-enemy Astral Saturation.
-- Additive to blm_specs.lua (must load after blm_specs.lua; preserves Necromancer).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local soulActions = nil
do
    local ok, mod = pcall(require, 'modules/custom/lua/overlords_soul_actions')
    if ok and type(mod) == 'table' then
        soulActions = mod
    end
end

local m = Module:new('overlords_blm_astromancer')
local spec = xi.overlords.spec
local BLM = xi.job.BLM
local KEY = 'astromancer'

local SPELL_FIRE     = (xi.magic and xi.magic.spell and xi.magic.spell.FIRE) or 144
local SPELL_BLIZZARD = (xi.magic and xi.magic.spell and xi.magic.spell.BLIZZARD) or 149
local SPELL_AERO     = (xi.magic and xi.magic.spell and xi.magic.spell.AERO) or 154
local SPELL_STONE    = (xi.magic and xi.magic.spell and xi.magic.spell.STONE) or 159
local SPELL_THUNDER  = (xi.magic and xi.magic.spell and xi.magic.spell.THUNDER) or 164
local SPELL_WATER    = (xi.magic and xi.magic.spell and xi.magic.spell.WATER) or 169

local SPELL_FLARE    = (xi.magic and xi.magic.spell and xi.magic.spell.FLARE) or 204
local SPELL_FREEZE   = (xi.magic and xi.magic.spell and xi.magic.spell.FREEZE) or 206
local SPELL_TORNADO  = (xi.magic and xi.magic.spell and xi.magic.spell.TORNADO) or 208
local SPELL_QUAKE    = (xi.magic and xi.magic.spell and xi.magic.spell.QUAKE) or 210
local SPELL_BURST    = (xi.magic and xi.magic.spell and xi.magic.spell.BURST) or 212
local SPELL_FLOOD    = (xi.magic and xi.magic.spell and xi.magic.spell.FLOOD) or 214

local PROBE_ELEMENTS =
{
    [SPELL_FIRE]     = 'fire',
    [SPELL_BLIZZARD] = 'ice',
    [SPELL_AERO]     = 'wind',
    [SPELL_STONE]    = 'earth',
    [SPELL_THUNDER]  = 'lightning',
    [SPELL_WATER]    = 'water',
}

local ANCIENT_SPELLS =
{
    [SPELL_FLARE]   = 'fire',
    [SPELL_FREEZE]  = 'ice',
    [SPELL_TORNADO] = 'wind',
    [SPELL_QUAKE]   = 'earth',
    [SPELL_BURST]   = 'lightning',
    [SPELL_FLOOD]   = 'water',
}

local SIX_ELEMENTS = { 'fire', 'ice', 'wind', 'earth', 'lightning', 'water' }

local VAR_PERSONAL_CD  = 'OX_AST_PERSONAL_CD'
local VAR_SURVEY_CD    = 'OX_AST_SURVEY_CD'
local VAR_LAST_ELEMENT = 'OX_AST_LAST_ELEMENT_IDX'

-- Target-owned atomic saturation table keyed by "zoneId:targetId:spawnGen".
local saturationByTarget = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isAstromancer(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == BLM and player:getMainLvl() >= 10 and
        spec.is(player, BLM, KEY)
end

local function targetKey(target, spawnGen)
    local zoneId = target and target.getZoneID and target:getZoneID() or 0
    local tid = target and target.getID and target:getID() or 0
    local gen = spawnGen or (target and target.getLocalVar and target:getLocalVar('OX_SPAWN_GEN')) or 0
    return string.format('%d:%d:%d', zoneId, tid, gen)
end

local function isTargetSaturated(target, spawnGen)
    if not target then return false, 0 end
    local rec = saturationByTarget[targetKey(target, spawnGen)]
    if not rec then return false, 0 end
    local now = xi.overlords.nowSec()
    if now >= rec.untilSec then
        saturationByTarget[targetKey(target, spawnGen)] = nil
        return false, 0
    end
    return true, rec.untilSec - now
end

local function clearTargetSaturation(target, spawnGen)
    if not target then return end
    saturationByTarget[targetKey(target, spawnGen)] = nil
end

local function recordProbeElement(player, spellId, completed)
    if not isAstromancer(player) or not completed then return nil end
    local elem = PROBE_ELEMENTS[spellId]
    if not elem then return nil end
    for idx, name in ipairs(SIX_ELEMENTS) do
        if name == elem and player.setLocalVar then
            player:setLocalVar(VAR_LAST_ELEMENT, idx)
            break
        end
    end
    return elem
end

local function getInvocationElement(player)
    local idx = player and player.getLocalVar and (player:getLocalVar(VAR_LAST_ELEMENT) or 0) or 0
    return SIX_ELEMENTS[idx] or 'earth'
end

-- Elemental Survey (Lv30+, 1s cast, 30s recast, 2% max MP): returns all tied least-resistant elements.
local function surveyTarget(player, target, resistances)
    if not isAstromancer(player) or player:getMainLvl() < 30 then return nil end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil
    end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_SURVEY_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 30 then
        return nil
    end
    if player.setLocalVar then
        player:setLocalVar(VAR_SURVEY_CD, now)
    end

    local minVal = nil
    local best = {}
    for _, elem in ipairs(SIX_ELEMENTS) do
        local val = (resistances and resistances[elem]) or 0
        if minVal == nil or val < minVal then
            minVal = val
            best = { elem }
        elseif val == minVal then
            best[#best + 1] = elem
        end
    end
    return { elements = best, resistance = minVal, duration = 12 }
end

-- Atomic Ancient impact resolution.
-- Non-Astromancers (e.g. Sage, Necromancer, Spellblade) pass through untouched.
local function resolveAncientImpact(player, target, baseDamage, opts)
    opts = opts or {}
    if not isAstromancer(player) then
        return baseDamage, { affected = false, saturated = false }
    end
    if not opts.completed then
        -- Interruption: native cancellation penalty only; do not claim saturation or start 18s personal recovery.
        return 0, { affected = true, saturated = false, interrupted = true }
    end

    local now = xi.overlords.nowSec()
    local lastPersonal = player.getLocalVar and (player:getLocalVar(VAR_PERSONAL_CD) or 0) or 0
    if lastPersonal > now then lastPersonal = 0 end
    if lastPersonal ~= 0 and (now - lastPersonal) < 18 then
        -- Still on 18s personal recovery: resolves as ordinary base damage, no empowered bonus or saturation claim.
        return math.max(0, math.floor(baseDamage or 0)), { affected = true, saturated = false, onPersonalCooldown = true }
    end

    -- Completed impact starts 18s personal recovery (including full resist to zero).
    if player.setLocalVar then
        player:setLocalVar(VAR_PERSONAL_CD, now)
    end

    if type(baseDamage) ~= 'number' or baseDamage <= 0 then
        -- Full resist to zero never claims shared saturation.
        return 0, { affected = true, saturated = false, fullResist = true }
    end

    local lvl = player:getMainLvl()
    local mult = (lvl >= 70 and 2.5) or (lvl >= 50 and 2.0) or 3.0
    local rawBonus = math.floor(baseDamage * (mult - 1.0))

    -- Lv70-75 boss cap: cap ONLY added Soul bonus at 3% of encounter-start max HP.
    local clampedBonus = rawBonus
    if lvl >= 70 and opts.isBoss and type(opts.encounterStartMaxHP) == 'number' and opts.encounterStartMaxHP > 0 then
        local bossCap = math.floor(opts.encounterStartMaxHP * 0.03)
        if clampedBonus > bossCap then
            clampedBonus = bossCap
        end
    end

    local key = targetKey(target, opts.spawnGen)
    local rec = saturationByTarget[key]
    local alreadySaturated = rec ~= nil and now < rec.untilSec

    local finalDamage
    if not alreadySaturated then
        -- Atomically claim 20s target saturation window.
        saturationByTarget[key] = { untilSec = now + 20, ownerId = player:getID() }
        finalDamage = math.floor(baseDamage) + clampedBonus
    else
        -- Saturated: 10% of clamped bonus, neither extends nor refreshes saturation window.
        finalDamage = math.floor(baseDamage) + math.floor(clampedBonus * 0.10)
    end

    return finalDamage, {
        affected = true,
        saturated = alreadySaturated,
        multiplier = mult,
        clampedBonus = clampedBonus,
    }
end

xi.overlords.astromancer =
{
    resolveAncientImpact  = resolveAncientImpact,
    isTargetSaturated     = isTargetSaturated,
    clearTargetSaturation = clearTargetSaturation,
    recordProbeElement    = recordProbeElement,
    getInvocationElement  = getInvocationElement,
    surveyTarget          = surveyTarget,
    ANCIENT_SPELLS        = ANCIENT_SPELLS,
    PROBE_ELEMENTS        = PROBE_ELEMENTS,
}

-- Register reviewed action manifest using verified Flood (214) -> Tsunami (never demo ID 1).
if soulActions and soulActions.register and soulActions.definitions and not soulActions.definitions[KEY] then
    soulActions.register(KEY, {
        spell = {
            [SPELL_STONE]    = { name = 'Stone', description = 'Earth elemental probe; sets Invocation element.', castTime = 1.5 },
            [SPELL_WATER]    = { name = 'Water', description = 'Water elemental probe; sets Invocation element.', castTime = 1.5 },
            [SPELL_AERO]     = { name = 'Aero', description = 'Wind elemental probe; sets Invocation element.', castTime = 1.5 },
            [SPELL_FIRE]     = { name = 'Fire', description = 'Fire elemental probe; sets Invocation element.', castTime = 1.5 },
            [SPELL_BLIZZARD] = { name = 'Blizzard', description = 'Ice elemental probe; sets Invocation element.', castTime = 1.5 },
            [SPELL_THUNDER]  = { name = 'Thunder', description = 'Lightning elemental probe; sets Invocation element.', castTime = 1.5 },
            [SPELL_FLARE]    = { name = 'Flare', description = 'Fire Ancient aspect; triggers 20s Astral Saturation and 18s personal recovery.', castTime = 7, recastTime = 18 },
            [SPELL_FREEZE]   = { name = 'Freeze', description = 'Ice Ancient aspect; triggers 20s Astral Saturation and 18s personal recovery.', castTime = 7, recastTime = 18 },
            [SPELL_TORNADO]  = { name = 'Tornado', description = 'Wind Ancient aspect; triggers 20s Astral Saturation and 18s personal recovery.', castTime = 7, recastTime = 18 },
            [SPELL_QUAKE]    = { name = 'Quake', description = 'Earth Ancient aspect; triggers 20s Astral Saturation and 18s personal recovery.', castTime = 7, recastTime = 18 },
            [SPELL_BURST]    = { name = 'Burst', description = 'Lightning Ancient aspect; triggers 20s Astral Saturation and 18s personal recovery.', castTime = 7, recastTime = 18 },
            [SPELL_FLOOD]    = { name = 'Tsunami', description = 'Water Ancient aspect; triggers 20s Astral Saturation and 18s personal recovery.', effectProfile = 'tsunami', castTime = 7, recastTime = 18 },
        },
        ability = {},
        weaponskill = {},
    })
end

if BLM ~= nil then
    -- Additive registration: never replace Necromancer in blm_specs.lua.
    spec.registerCrystal(xi.job.BLM,
    {
        id = 1,
        key = KEY,
        name = 'Astromancer',
        abr = 'AST',
        role = 'Damage',
        icon = 'astromancer',
        reqLevel = 10,
        description = 'A deliberate Ancient Magic specialist: probes target resistances and commits to massive single-target Ancient impacts governed by shared 20s per-enemy Astral Saturation.',
        highlights =
        {
            'Ancient Invocation (Lv10–49, 3.0x probe) and six named Ancient aspects (Lv50–69 2.0x, Lv70–75 2.5x; Water displays Tsunami).',
            'Atomic 20s per-enemy Astral Saturation reduces duplicate Astromancer bonuses to 10% without refreshing the window.',
            '18s personal recovery at completed resolution; Lv70+ boss bonus capped at 3% encounter-start max HP.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.INT,   scale(level, 8, 15, 22, 30) },
                { xi.mod.MATT,  scale(level, 10, 18, 28, 38) },
                { xi.mod.MACC,  scale(level, 8, 15, 24, 34) },
                { xi.mod.MPP,   scale(level, 6, 10, 14, 18) },
            }
        end,
    })
end

if xi.overlords.hud and xi.overlords.hud.registerProvider then
    xi.overlords.hud.registerProvider(KEY, function(player)
        local now = xi.overlords.nowSec()
        local lastPersonal = player.getLocalVar and (player:getLocalVar(VAR_PERSONAL_CD) or 0) or 0
        local tgt = player.getTarget and player:getTarget() or nil
        local sat, satRem = isTargetSaturated(tgt)
        return {
            recovery_cd = lastPersonal > 0 and math.max(0, math.ceil(18 - (now - lastPersonal))) or 0,
            target_sat  = sat and 1 or 0,
            sat_rem     = math.ceil(satRem),
            element     = getInvocationElement(player),
        }
    end)
end

return m
