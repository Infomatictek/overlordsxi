-----------------------------------
-- OverlordsXI RDM 3: Scarlet Weaver (Sequence C — Isolated Caster)
-- Mutually exclusive Yin (elemental spells) / Yang (main-hand sword melee) aspects.
-- Strictly scoped to Scarlet Weaver; never globalized to other RDM Souls or jobs.
-- Additive to rdm_specs.lua (must load after rdm_specs.lua; preserves Crimson Duelist).
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

local m = Module:new('overlords_rdm_scarlet_weaver')
local spec = xi.overlords.spec
local RDM = xi.job.RDM
local KEY = 'scarletweaver'

local ASPECT_NONE = 0
local ASPECT_YIN  = 1
local ASPECT_YANG = 2

local VAR_ASPECT         = 'OX_SCW_ASPECT'
local VAR_SWITCH_CD      = 'OX_SCW_SWITCH_CD'
local VAR_RECOVERY_UNTIL = 'OX_SCW_RECOVERY_UNTIL'

-- Six single-target Tier I-III elemental spell IDs (Fire..Water I/II/III).
local ELIGIBLE_ELEMENTAL_SPELLS =
{
    [144] = true, [145] = true, [146] = true, -- Fire I-III
    [149] = true, [150] = true, [151] = true, -- Blizzard I-III
    [154] = true, [155] = true, [156] = true, -- Aero I-III
    [159] = true, [160] = true, [161] = true, -- Stone I-III
    [164] = true, [165] = true, [166] = true, -- Thunder I-III
    [169] = true, [170] = true, [171] = true, -- Water I-III
}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isScarletWeaver(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == RDM and player:getMainLvl() >= 10 and
        spec.is(player, RDM, KEY)
end

local function hasSwordMain(player)
    if not player or not player.getWeaponSkillType then return false end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.SWORD
end

local function getAspect(player)
    if not isScarletWeaver(player) then return nil end
    local val = player.getLocalVar and (player:getLocalVar(VAR_ASPECT) or ASPECT_NONE) or ASPECT_NONE
    if val == ASPECT_YIN then return 'yin' end
    if val == ASPECT_YANG then return 'yang' end
    return nil
end

local function clearAspectState(player)
    if player and player.setLocalVar then
        player:setLocalVar(VAR_ASPECT, ASPECT_NONE)
        player:setLocalVar(VAR_SWITCH_CD, 0)
        player:setLocalVar(VAR_RECOVERY_UNTIL, 0)
    end
end

local function onApply(player)
    if not isScarletWeaver(player) then return end
    if player.getLocalVar and (player:getLocalVar(VAR_ASPECT) or ASPECT_NONE) == ASPECT_NONE then
        -- Default to Yang on first activation at Lv10.
        player:setLocalVar(VAR_ASPECT, ASPECT_YANG)
    end
end

-- Switch to 'yin' or 'yang'. Free out of combat; 12s shared recast + 2s recovery in combat.
-- Switching into the already-active aspect is a no-op; disallowed during cast/JA lock.
local function setAspect(player, targetAspect, opts)
    opts = opts or {}
    if not isScarletWeaver(player) then
        return false, 'not_scarlet_weaver'
    end
    local code = (targetAspect == 'yin' and ASPECT_YIN) or (targetAspect == 'yang' and ASPECT_YANG) or nil
    if code == nil then
        return false, 'invalid_aspect'
    end
    if opts.inActionLock then
        return false, 'action_locked'
    end

    local current = player.getLocalVar and (player:getLocalVar(VAR_ASPECT) or ASPECT_NONE) or ASPECT_NONE
    if current == code then
        return true, 'noop'
    end

    local now = xi.overlords.nowSec()
    local inCombat = opts.inCombat == true or (player.isEngaged and player:isEngaged())
    if inCombat then
        local lastSwitch = player.getLocalVar and (player:getLocalVar(VAR_SWITCH_CD) or 0) or 0
        if lastSwitch > now then lastSwitch = 0 end
        if lastSwitch ~= 0 and (now - lastSwitch) < 12 then
            return false, 'on_recast'
        end
        if player.setLocalVar then
            player:setLocalVar(VAR_SWITCH_CD, now)
            player:setLocalVar(VAR_RECOVERY_UNTIL, now + 2)
        end
    end

    if player.setLocalVar then
        player:setLocalVar(VAR_ASPECT, code)
    end
    return true, 'switched'
end

local function bonusPercent(player)
    return scale(player:getMainLvl(), 15, 18, 22, 25)
end

-- Evaluate Yin elemental spell multiplier at actual resolution.
-- Never applies to Enspell, WS, skillchain, non-eligible spells, or non-Scarlet-Weaver Souls.
local function applyYinSpellDamage(player, spellId, baseDamage, opts)
    opts = opts or {}
    if type(baseDamage) ~= 'number' or baseDamage <= 0 then return baseDamage end
    if not isScarletWeaver(player) or getAspect(player) ~= 'yin' then
        return baseDamage
    end
    if opts.isEnspell or opts.isWeaponSkill or opts.isSkillchain or not ELIGIBLE_ELEMENTAL_SPELLS[spellId] then
        return baseDamage
    end
    local pct = bonusPercent(player)
    return math.floor(baseDamage * (100 + pct) / 100)
end

-- Evaluate Yang regular main-hand sword melee multiplier at actual resolution.
-- Never applies to Enspell, WS, skillchain, additional attacks, offhand, non-sword, or other Souls.
local function applyYangMeleeDamage(player, baseDamage, opts)
    opts = opts or {}
    if type(baseDamage) ~= 'number' or baseDamage <= 0 then return baseDamage end
    if not isScarletWeaver(player) or getAspect(player) ~= 'yang' or not hasSwordMain(player) then
        return baseDamage
    end
    if opts.isEnspell or opts.isWeaponSkill or opts.isSkillchain or opts.isAdditionalAttack or opts.isOffhand then
        return baseDamage
    end
    local pct = bonusPercent(player)
    return math.floor(baseDamage * (100 + pct) / 100)
end

xi.overlords.scarletWeaver =
{
    getAspect            = getAspect,
    setAspect            = setAspect,
    applyYinSpellDamage  = applyYinSpellDamage,
    applyYangMeleeDamage = applyYangMeleeDamage,
    clearAspectState     = clearAspectState,
    onApply              = onApply,
}

if soulActions and soulActions.register and soulActions.definitions and not soulActions.definitions[KEY] then
    soulActions.register(KEY, {
        spell = {
            [144] = { name = 'Fire', description = 'Elemental spell boosted by Yin Aspect.', castTime = 1.5 },
            [149] = { name = 'Blizzard', description = 'Elemental spell boosted by Yin Aspect.', castTime = 1.5 },
            [154] = { name = 'Aero', description = 'Elemental spell boosted by Yin Aspect.', castTime = 1.5 },
            [159] = { name = 'Stone', description = 'Elemental spell boosted by Yin Aspect.', castTime = 1.5 },
            [164] = { name = 'Thunder', description = 'Elemental spell boosted by Yin Aspect.', castTime = 1.5 },
            [169] = { name = 'Water', description = 'Elemental spell boosted by Yin Aspect.', castTime = 1.5 },
        },
        ability = {},
        weaponskill = {},
    })
end

if RDM ~= nil then
    -- Additive registration: never replace Crimson Duelist in rdm_specs.lua.
    spec.registerCrystal(xi.job.RDM,
    {
        id = 3,
        key = KEY,
        name = 'Scarlet Weaver',
        abr = 'SCW',
        role = 'Damage',
        icon = 'scarletweaver',
        reqLevel = 10,
        description = 'A dual-aspect Red Mage who commits to either Yin (elemental magic) or Yang (main-hand sword melee) as encounter resistances shift.',
        highlights =
        {
            'Mutually exclusive Yin (+15/18/22/25% Tier I–III elemental spells) and Yang (+15/18/22/25% main-hand sword melee).',
            'Defaults to Yang on activation; free switch out of combat, 12s shared recast and 2s recovery in combat.',
            'Enspells, weapon skills, skillchains, and other Souls never receive Yin/Yang multipliers.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.SWORD, scale(level, 10, 18, 28, 40) },
                { xi.mod.ACC,   scale(level, 10, 18, 28, 38) },
                { xi.mod.DEX,   scale(level, 6, 10, 15, 20) },
                { xi.mod.INT,   scale(level, 6, 12, 18, 25) },
                { xi.mod.MATT,  scale(level, 8, 14, 22, 30) },
            }
        end,
        onApply  = onApply,
        onRemove = clearAspectState,
    })
end

if xi.overlords.hud and xi.overlords.hud.registerProvider then
    xi.overlords.hud.registerProvider(KEY, function(player)
        local now = xi.overlords.nowSec()
        local lastSwitch = player.getLocalVar and (player:getLocalVar(VAR_SWITCH_CD) or 0) or 0
        local recUntil = player.getLocalVar and (player:getLocalVar(VAR_RECOVERY_UNTIL) or 0) or 0
        return {
            aspect       = getAspect(player) or 'none',
            switch_cd    = lastSwitch > 0 and math.max(0, math.ceil(12 - (now - lastSwitch))) or 0,
            recovery_rem = recUntil > now and math.ceil(recUntil - now) or 0,
        }
    end)
end

return m
