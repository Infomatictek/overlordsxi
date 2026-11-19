-----------------------------------
-- OverlordsXI WHM 2: Zealot (Sequence C — Isolated Caster)
-- Sustained staff-melee MP communion + single-target Divine Magic burst.
-- Additive to whm_specs.lua (must load after whm_specs.lua; preserves Bishop).
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

local m = Module:new('overlords_whm_zealot')
local spec = xi.overlords.spec
local WHM = xi.job.WHM
local KEY = 'zealot'

local SPELL_HOLY       = (xi.magic and xi.magic.spell and xi.magic.spell.HOLY) or 21
local SPELL_BANISH     = (xi.magic and xi.magic.spell and xi.magic.spell.BANISH) or 28
local SPELL_BANISH_II  = (xi.magic and xi.magic.spell and xi.magic.spell.BANISH_II) or 29
local SPELL_BANISH_III = (xi.magic and xi.magic.spell and xi.magic.spell.BANISH_III) or 30
local ABIL_DIVINE_SEAL = (xi.jobAbility and xi.jobAbility.DIVINE_SEAL) or 74

local ATTACK_LISTENER  = 'OX_WHM_ZEALOT_COMMUNION'
local VAR_COMMUNION_AT = 'OX_ZEL_LAST_COMMUNION'
local VAR_SEAL_UNTIL   = 'OX_ZEL_DIVINE_SEAL_UNTIL'
local VAR_SEAL_CD      = 'OX_ZEL_DIVINE_SEAL_CD'
local VAR_HOLY_CD      = 'OX_ZEL_HOLY_CD'

local DIVINE_SPELLS =
{
    [SPELL_BANISH]     = true,
    [SPELL_BANISH_II]  = true,
    [SPELL_BANISH_III] = true,
    [SPELL_HOLY]       = true,
}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isZealot(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == WHM and player:getMainLvl() >= 10 and
        spec.is(player, WHM, KEY)
end

local function hasStaffMain(player)
    if not player or not player.getWeaponSkillType then return false end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.STAFF
end

local function clearState(player)
    if not player then return end
    if player.removeListener then
        player:removeListener(ATTACK_LISTENER)
    end
    if player.setLocalVar then
        player:setLocalVar(VAR_SEAL_UNTIL, 0)
    end
end

-- Staff Communion: first landed regular main-hand staff hit per attack round (2.5s lock).
-- No refund on zero damage/immunity, WS, counters, additional effects, offhand, or non-Zealot Souls.
local function onStaffMeleeHit(player, target, damage, opts)
    opts = opts or {}
    if not isZealot(player) or not hasStaffMain(player) then
        return 0
    end
    if opts.isWeaponSkill or opts.isCounter or opts.isAdditionalEffect or opts.isOffhand then
        return 0
    end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return 0
    end
    if type(damage) ~= 'number' or damage <= 0 then
        return 0
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_COMMUNION_AT) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 2.5 then
        return 0
    end
    if player.setLocalVar then
        player:setLocalVar(VAR_COMMUNION_AT, now)
    end

    local maxMP = player.getMaxMP and player:getMaxMP() or 0
    local rate = scale(player:getMainLvl(), 0.035, 0.04, 0.04, 0.045)
    local restore = math.max(2, math.floor(maxMP * rate))
    if player.addMP then
        player:addMP(restore)
    end
    return restore
end

-- Zealot Divine Seal: 90s CD, arms 20s pending window; survives cast cancellation,
-- consumed only on a completed damaging divine spell (+20% bonus).
local function activateDivineSeal(player)
    if not isZealot(player) then return false end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_SEAL_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 90 then
        return false
    end
    if player.setLocalVar then
        player:setLocalVar(VAR_SEAL_CD, now)
        player:setLocalVar(VAR_SEAL_UNTIL, now + 20)
    end
    return true
end

-- Compute Zealot divine spell MP cost (percentage rounds up, min 1), cast/recast, and resolved damage.
local function getDivineProfile(player, spellId)
    if not isZealot(player) or not DIVINE_SPELLS[spellId] then return nil end
    local lvl = player:getMainLvl()
    local maxMP = player.getMaxMP and player:getMaxMP() or 100
    local function pctMp(p) return math.max(1, math.ceil(maxMP * p)) end

    if spellId == SPELL_BANISH then
        return { mpCost = pctMp(0.08), castTime = 2.0, recast = 6, mult = 1.5, name = 'Banish' }
    elseif spellId == SPELL_BANISH_II and lvl >= 30 then
        return { mpCost = pctMp(0.12), castTime = 2.5, recast = 8, mult = 1.6, name = 'Banish II' }
    elseif spellId == SPELL_BANISH_III and lvl >= 50 then
        return { mpCost = pctMp(0.12), castTime = 2.5, recast = 8, mult = 1.5, name = 'Banish III' }
    elseif spellId == SPELL_HOLY and lvl >= 70 then
        return { mpCost = pctMp(0.22), castTime = 3.5, recast = 14, mult = 2.0, name = 'Divine Benediction of Light' }
    elseif spellId == SPELL_HOLY and lvl >= 50 then
        return { mpCost = pctMp(0.20), castTime = 3.0, recast = 14, mult = 1.8, name = 'Holy' }
    end
    return nil
end

local function resolveDivineDamage(player, target, spellId, nativeBaseDamage, completed)
    if not isZealot(player) then
        return nativeBaseDamage, false
    end
    local profile = getDivineProfile(player, spellId)
    if not profile then
        return nativeBaseDamage, false
    end
    -- Cancelled cast leaves Divine Seal pending (within its 20s expiry).
    if not completed then
        return 0, false
    end
    if type(nativeBaseDamage) ~= 'number' or nativeBaseDamage <= 0 then
        return 0, false
    end

    local now = xi.overlords.nowSec()
    local sealUntil = player.getLocalVar and (player:getLocalVar(VAR_SEAL_UNTIL) or 0) or 0
    local sealUsed = false
    local dmg = math.floor(nativeBaseDamage * profile.mult)
    if sealUntil ~= 0 and now <= sealUntil then
        sealUsed = true
        if player.setLocalVar then
            player:setLocalVar(VAR_SEAL_UNTIL, 0)
        end
        dmg = math.floor(dmg * 1.20)
    elseif sealUntil ~= 0 and now > sealUntil and player.setLocalVar then
        player:setLocalVar(VAR_SEAL_UNTIL, 0)
    end

    if spellId == SPELL_HOLY and player.setLocalVar then
        player:setLocalVar(VAR_HOLY_CD, now)
    end
    return dmg, sealUsed
end

local function attach(player)
    if not isZealot(player) or not player.addListener then return end
    clearState(player)
    player:addListener('ATTACK', ATTACK_LISTENER, function(attacker, defender, action)
        if not isZealot(attacker) or not hasStaffMain(attacker) then return end
        local dmg = action and action.getParam and defender and defender.getID and action:getParam(defender:getID()) or 0
        onStaffMeleeHit(attacker, defender, dmg, {})
    end)
end

xi.overlords.zealot =
{
    onStaffMeleeHit    = onStaffMeleeHit,
    activateDivineSeal = activateDivineSeal,
    getDivineProfile   = getDivineProfile,
    resolveDivineDamage = resolveDivineDamage,
    attach             = attach,
    clearState         = clearState,
}

if soulActions and soulActions.register and soulActions.definitions and not soulActions.definitions[KEY] then
    soulActions.register(KEY, {
        spell = {
            [SPELL_BANISH]     = { name = 'Banish', description = 'Zealot single-target divine strike (8% max MP, 2s cast, 6s recast, 1.5x base).', castTime = 2, recastTime = 6 },
            [SPELL_BANISH_II]  = { name = 'Banish II', description = 'Zealot single-target divine strike (12% max MP, 2.5s cast, 8s recast, 1.6x base).', castTime = 2.5, recastTime = 8 },
            [SPELL_BANISH_III] = { name = 'Banish III', description = 'Zealot single-target divine strike sharing Banish II recast (1.5x base).', castTime = 2.5, recastTime = 8 },
            [SPELL_HOLY]       = { name = 'Divine Benediction of Light', description = 'Zealot heavy single-target Holy burst (1.8x at Lv50, 2.0x at Lv70, 14s recast).', castTime = 3.5, recastTime = 14 },
        },
        ability = {
            [ABIL_DIVINE_SEAL] = { name = 'Divine Seal', description = 'Empowers the next completed damaging divine spell by +20% (20s window, 90s recast).', recastTime = 90 },
        },
        weaponskill = {},
    })
end

if WHM ~= nil then
    spec.registerCrystal(xi.job.WHM,
    {
        id = 2,
        key = KEY,
        name = 'Zealot',
        abr = 'ZEL',
        role = 'Damage',
        icon = 'zealot',
        reqLevel = 10,
        description = 'A militant divine caster: earns MP through landed main-hand staff strikes and spends it on high-impact single-target Banish and Holy casts.',
        highlights =
        {
            'Staff Communion: first landed regular main-hand staff hit per round (2.5s lock) restores 3.5/4.0/4.0/4.5% max MP (min 2).',
            'Single-target Divine Magic scaling: Banish I–III and Holy / Divine Benediction of Light (Lv70, 2.0x base).',
            'Divine Seal empowers the next completed damaging divine spell by +20% and survives cast cancellation for up to 20s.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.STAFF,  scale(level, 12, 22, 34, 46) },
                { xi.mod.ACC,    scale(level, 10, 18, 28, 40) },
                { xi.mod.MND,    scale(level, 6, 12, 18, 25) },
                { xi.mod.MATT,   scale(level, 8, 14, 22, 30) },
                { xi.mod.MACC,   scale(level, 8, 14, 22, 30) },
            }
        end,
        onApply  = attach,
        onRemove = clearState,
    })
end

if xi.player and xi.player.onGameIn then
    m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
        super(player, firstLogin, zoning)
        if isZealot(player) then attach(player) end
    end)
end

if xi.overlords.hud and xi.overlords.hud.registerProvider then
    xi.overlords.hud.registerProvider(KEY, function(player)
        local now = xi.overlords.nowSec()
        local lastComm = player.getLocalVar and (player:getLocalVar(VAR_COMMUNION_AT) or 0) or 0
        local lastHoly = player.getLocalVar and (player:getLocalVar(VAR_HOLY_CD) or 0) or 0
        local sealUntil = player.getLocalVar and (player:getLocalVar(VAR_SEAL_UNTIL) or 0) or 0
        return {
            communion_cd = lastComm > 0 and math.max(0, math.ceil(2.5 - (now - lastComm))) or 0,
            holy_cd      = lastHoly > 0 and math.max(0, math.ceil(14 - (now - lastHoly))) or 0,
            seal_rem     = sealUntil > now and math.ceil(sealUntil - now) or 0,
        }
    end)
end

return m
