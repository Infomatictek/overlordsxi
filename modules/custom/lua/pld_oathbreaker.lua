-----------------------------------
-- OverlordsXI PLD 3: Oathbreaker (Sequence D — Offensive Opening)
-- Pre-pull Vow commitment (Condemn vs Absolve) + Reckoning execution.
-- Additive to pld_specs.lua and pld_healer_specs.lua (preserves Defender & Templar).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_pld_oathbreaker')
local spec = xi.overlords.spec
local PLD = xi.job.PLD
local KEY = 'oathbreaker'

local VOW_NONE    = 0
local VOW_CONDEMN = 1
local VOW_ABSOLVE = 2

local VAR_VOW           = 'OX_OTB_VOW'
local VAR_VOW_CD        = 'OX_OTB_VOW_CD'
local VAR_RECKONING_CD  = 'OX_OTB_RECKONING_CD'
local VAR_RETAL_UNTIL   = 'OX_OTB_RETAL_UNTIL'
local VAR_RETAL_TARGET  = 'OX_OTB_RETAL_TARGET'

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isOathbreaker(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == PLD and player:getMainLvl() >= 10 and
        spec.is(player, PLD, KEY)
end

local function hasGreatSword(player)
    return player ~= nil and player.getWeaponSkillType and
        player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.GREAT_SWORD
end

local function getVow(player)
    if not isOathbreaker(player) then return nil end
    local v = player.getLocalVar and (player:getLocalVar(VAR_VOW) or VOW_NONE) or VOW_NONE
    if v == VOW_CONDEMN then return 'condemn' end
    if v == VOW_ABSOLVE then return 'absolve' end
    return nil
end

local function clearRetaliation(player)
    if player and player.setLocalVar then
        player:setLocalVar(VAR_RETAL_UNTIL, 0)
        player:setLocalVar(VAR_RETAL_TARGET, 0)
    end
end

local function clearState(player)
    if player and player.setLocalVar then
        player:setLocalVar(VAR_VOW, VOW_NONE)
        player:setLocalVar(VAR_VOW_CD, 0)
        player:setLocalVar(VAR_RECKONING_CD, 0)
    end
    clearRetaliation(player)
end

-- Vows can change ONLY while disengaged and absent from hostile hate lists (5s shared recast).
local function swearVow(player, vowName, opts)
    opts = opts or {}
    if not isOathbreaker(player) then return false, 'not_oathbreaker' end
    local code = (vowName == 'condemn' and VOW_CONDEMN) or (vowName == 'absolve' and VOW_ABSOLVE) or nil
    if not code then return false, 'invalid_vow' end
    if opts.engaged or opts.onHateList or (player.isEngaged and player:isEngaged()) then
        return false, 'in_combat_or_hate_list'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_VOW_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 5 then
        return false, 'on_recast'
    end

    if player.setLocalVar then
        player:setLocalVar(VAR_VOW, code)
        player:setLocalVar(VAR_VOW_CD, now)
    end
    clearRetaliation(player)
    return true, vowName
end

-- Flash is unavailable under Condemn.
local function isFlashAllowed(player)
    if not isOathbreaker(player) then return true end
    return getVow(player) ~= 'condemn'
end

-- Condemn: +10/13/16/18% regular Great Sword melee damage.
local function applyCondemnMelee(player, baseDamage, opts)
    opts = opts or {}
    if type(baseDamage) ~= 'number' or baseDamage <= 0 then return baseDamage end
    if not isOathbreaker(player) or getVow(player) ~= 'condemn' or not hasGreatSword(player) then
        return baseDamage
    end
    if opts.isWeaponSkill or opts.isAdditionalEffect then return baseDamage end
    local pct = scale(player:getMainLvl(), 10, 13, 16, 18)
    return math.floor(baseDamage * (100 + pct) / 100)
end

-- Absolve: 8/10/12/12% personal DT + arms retaliation when player personally loses >= 8% max HP from one enemy hit.
local function onPlayerDamaged(player, attacker, actualHpLost)
    if not isOathbreaker(player) or getVow(player) ~= 'absolve' then return false end
    if not attacker or not attacker.isMob or not attacker:isMob() or not attacker.getID then return false end
    local maxHP = player.getMaxHP and player:getMaxHP() or 0
    if maxHP <= 0 or type(actualHpLost) ~= 'number' or actualHpLost <= 0 then return false end
    if actualHpLost < (maxHP * 0.08) then return false end

    local now = xi.overlords.nowSec()
    local window = player:getMainLvl() >= 50 and 7 or 5
    if player.setLocalVar then
        player:setLocalVar(VAR_RETAL_UNTIL, now + window)
        player:setLocalVar(VAR_RETAL_TARGET, attacker:getID())
    end
    return true
end

local function getAbsolveDtPercent(player)
    if not isOathbreaker(player) or getVow(player) ~= 'absolve' then return 0 end
    return scale(player:getMainLvl(), 8, 10, 12, 12)
end

-- Reckoning: 4y, 18s CD, 1.5/1.7/1.7/2.0x normalized main-hand GS hit; doubled under armed Absolve retaliation.
-- Invalid target never spends cooldown or retaliation; clears retaliation on target death/change.
local function executeReckoning(player, target, normalizedHit)
    if not isOathbreaker(player) or not hasGreatSword(player) then return nil, 'invalid_state' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        clearRetaliation(player)
        return nil, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 4 then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_RECKONING_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 18 then
        return nil, 'on_recast'
    end

    local mult = scale(player:getMainLvl(), 1.5, 1.7, 1.7, 2.0)
    local retalUntil = player.getLocalVar and (player:getLocalVar(VAR_RETAL_UNTIL) or 0) or 0
    local retalTarget = player.getLocalVar and (player:getLocalVar(VAR_RETAL_TARGET) or 0) or 0
    local empowered = false
    if getVow(player) == 'absolve' and retalUntil >= now and retalTarget == target:getID() then
        mult = mult * 2.0
        empowered = true
        clearRetaliation(player)
    elseif retalTarget ~= 0 and retalTarget ~= target:getID() then
        clearRetaliation(player)
    end

    if player.setLocalVar then
        player:setLocalVar(VAR_RECKONING_CD, now)
    end
    local dmg = math.floor((normalizedHit or 0) * mult)
    return dmg, { empowered = empowered, multiplier = mult }
end

xi.overlords.oathbreaker =
{
    getVow              = getVow,
    swearVow            = swearVow,
    isFlashAllowed      = isFlashAllowed,
    applyCondemnMelee   = applyCondemnMelee,
    onPlayerDamaged     = onPlayerDamaged,
    getAbsolveDtPercent = getAbsolveDtPercent,
    executeReckoning    = executeReckoning,
    clearRetaliation    = clearRetaliation,
    clearState          = clearState,
}

if PLD ~= nil then
    spec.registerCrystal(xi.job.PLD,
    {
        id = 3,
        key = KEY,
        name = 'Oathbreaker',
        abr = 'OTB',
        role = 'Damage',
        icon = 'oathbreaker',
        reqLevel = 10,
        description = 'A Great Sword Paladin who commits pre-pull to either Condemn (sustained offense, no Flash) or Absolve (personal DT and doubled Reckoning riposte after taking >=8% max HP damage).',
        highlights =
        {
            'Out-of-combat Vow commitment: Condemn (+10/13/16/18% GS melee, disables Flash) vs Absolve (8/10/12% DT + retaliation).',
            'Reckoning (4y, 18s CD): 1.5/1.7/1.7/2.0x normalized GS hit, doubled once within 5/7s after a >=8% max HP enemy hit.',
            'Vow cannot swap while engaged or on hate lists; resets cleanly on Soul removal.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.GREAT_SWORD, scale(level, 12, 22, 34, 46) },
                { xi.mod.STR,         scale(level, 6, 12, 18, 25) },
                { xi.mod.ACC,         scale(level, 10, 18, 28, 38) },
                { xi.mod.ATT,         scale(level, 12, 22, 36, 50) },
            }
        end,
        onRemove = clearState,
    })
end

return m
