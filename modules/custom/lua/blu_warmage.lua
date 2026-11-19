-----------------------------------
-- OverlordsXI BLU 1: Warmage (Sequence D — Offensive Opening)
-- Assess Prey (12s CD, 8s window) + matching Blue Magic category bonus (+12/15/18/20%).
-- Starter pair explicitly maps Sprout Smack -> blunt and Power Attack -> piercing.
-- Additive to blu_specs.lua and blu_healer_specs.lua (preserves Azure Bastion & Magus).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_blu_warmage')
local spec = xi.overlords.spec
local BLU = xi.job.BLU
local KEY = 'warmage'

local VAR_ASSESS_CD = 'OX_WMG_ASSESS_CD'
local assessByChar = {}

-- Explicit Warmage spell category mapping (starter pair: Sprout Smack = blunt, Power Attack = piercing).
local SPELL_CATEGORIES =
{
    sprout_smack    = { category = 'blunt',    singleTarget = true, minLvl = 10 },
    power_attack    = { category = 'piercing', singleTarget = true, minLvl = 10 },
    foot_kick       = { category = 'slashing', singleTarget = true, minLvl = 10 },
    bludgeon        = { category = 'blunt',    singleTarget = true, minLvl = 30 },
    smite_of_rage   = { category = 'slashing', singleTarget = true, minLvl = 30 },
    jet_stream      = { category = 'blunt',    singleTarget = true, minLvl = 50 },
    mandibular_bite = { category = 'slashing', singleTarget = true, minLvl = 50 },
    bomb_toss       = { category = 'element',  singleTarget = true, minLvl = 50, convertedSingleTarget = true },
    death_scissors  = { category = 'slashing', singleTarget = true, minLvl = 70 },
    heat_breath     = { category = 'element',  singleTarget = true, minLvl = 70, convertedSingleTarget = true },
    mind_blast      = { category = 'element',  singleTarget = true, minLvl = 70 },
}

local CATEGORIES = { 'blunt', 'slashing', 'piercing', 'element' }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isWarmage(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == BLU and player:getMainLvl() >= 10 and
        spec.is(player, BLU, KEY)
end

local function clearState(player)
    if player and player.getID then
        assessByChar[player:getID()] = nil
    end
end

-- Assess Prey (12s CD): reveals all tied least-resistant categories for 8s on one selected target.
local function assessPrey(player, target, resistances)
    if not isWarmage(player) then return nil, 'not_warmage' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_ASSESS_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 12 then
        return nil, 'on_recast'
    end
    if player.setLocalVar then
        player:setLocalVar(VAR_ASSESS_CD, now)
    end

    local minVal = nil
    local matched = {}
    for _, cat in ipairs(CATEGORIES) do
        local val = (resistances and resistances[cat]) or 0
        if minVal == nil or val < minVal then
            minVal = val
            matched = { [cat] = true }
        elseif val == minVal then
            matched[cat] = true
        end
    end

    local rec = { targetId = target:getID(), categories = matched, untilSec = now + 8 }
    assessByChar[player:getID()] = rec
    return rec
end

-- Apply Warmage matching Blue spell bonus (+12/15/18/20% after resistance).
-- Never applies to sword hits, WS, self-buffs, missed spells, or non-assessed targets.
local function resolveBlueSpell(player, target, spellKey, postResistDamage, opts)
    opts = opts or {}
    if type(postResistDamage) ~= 'number' or postResistDamage <= 0 then
        return 0, { matched = false }
    end
    if not isWarmage(player) or opts.isMelee or opts.isWeaponSkill or opts.isSelfBuff or opts.missed then
        return postResistDamage, { matched = false }
    end
    local meta = SPELL_CATEGORIES[spellKey]
    if not meta or player:getMainLvl() < meta.minLvl then
        return postResistDamage, { matched = false }
    end

    local now = xi.overlords.nowSec()
    local rec = assessByChar[player:getID()]
    if not rec or now > rec.untilSec or not target or target:getID() ~= rec.targetId then
        return postResistDamage, { matched = false, singleTargetOnly = meta.singleTarget }
    end

    if rec.categories[meta.category] then
        local pct = scale(player:getMainLvl(), 12, 15, 18, 20)
        return math.floor(postResistDamage * (100 + pct) / 100), {
            matched = true,
            category = meta.category,
            singleTargetOnly = meta.singleTarget,
        }
    end
    return postResistDamage, { matched = false, singleTargetOnly = meta.singleTarget }
end

xi.overlords.warmage =
{
    assessPrey       = assessPrey,
    resolveBlueSpell = resolveBlueSpell,
    clearState       = clearState,
    SPELL_CATEGORIES = SPELL_CATEGORIES,
}

if BLU ~= nil then
    spec.registerCrystal(xi.job.BLU,
    {
        id = 1,
        key = KEY,
        name = 'Warmage',
        abr = 'WMG',
        role = 'Damage',
        icon = 'warmage',
        reqLevel = 10,
        description = 'A tactical Blue Mage who uses Assess Prey to expose a target\'s least-resistant categories and answers with matched single-target Blue Magic.',
        highlights =
        {
            'Assess Prey (12s CD, 8s window): identifies all tied least-resistant categories (blunt/slashing/piercing/element).',
            'Matching direct offensive Blue spells gain +12/15/18/20% post-resist damage; starter Sprout Smack (blunt) & Power Attack (piercing).',
            'Soul-converted area spells (e.g. Bomb Toss) target one enemy only; no WS refund or Azure Surge.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.ACC,  scale(level, 10, 18, 28, 38) },
                { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
                { xi.mod.MATT, scale(level, 8, 14, 22, 30) },
                { xi.mod.INT,  scale(level, 6, 12, 18, 24) },
            }
        end,
        onRemove = clearState,
    })
end

return m
