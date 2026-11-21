-- Phantom (THF) — open with a challenge and maintain threat through genuine evasion.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_thf_phantom')
local spec = xi.soulspire.spec
local actions = require('modules/custom/lua/soulspire_soul_actions')
local DARE = 41
local DARE_CD = 'OX_PHN_DARE_CD'
local GUARD_UNTIL = 'OX_PHN_GUARD_UNTIL'
local EVADE_CD = 'OX_PHN_EVADE_CD'
local EVADE_LISTENER = 'OX_PHN_EVADE'
local help = 'Challenge one enemy for threat and guard one magical or breath hit within 6s. 15y range. 18s recast.'

local function isPhantom(player)
    return player and player:isPC() and player:getMainJob() == xi.job.THF and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.THF, 'phantom')
end

local function hasWeapon(player)
    local skill = player:getWeaponSkillType(xi.slot.MAIN)
    return skill == xi.skill.DAGGER or skill == xi.skill.KATANA
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function remaining(player, var)
    return math.max(0, player:getLocalVar(var) - now())
end

local function attach(player)
    player:setLocalVar('OX_PHN_ACTIVE', 1)
    player:sendSoulSpellList()
    player:removeListener(EVADE_LISTENER)
    player:addListener('SOUL_MELEE_EVADE', EVADE_LISTENER, function(defender, attacker)
        if not isPhantom(defender) or not hasWeapon(defender) or not attacker or not attacker:isMob() or
            not attacker:isAlive() or remaining(defender, EVADE_CD) > 0
        then
            return
        end
        local level = defender:getMainLvl()
        attacker:addEnmity(defender, scale(level, 30, 40, 55, 70), scale(level, 85, 115, 150, 190))
        defender:setLocalVar(EVADE_CD, now() + 2)
    end)
end

local function detach(player)
    player:setLocalVar('OX_PHN_ACTIVE', 0)
    player:setLocalVar(GUARD_UNTIL, 0)
    player:removeListener(EVADE_LISTENER)
    player:sendSoulSpellList()
    local weapon = player:getEquippedItem(xi.slot.MAIN)
    if weapon and not player:canEquipItem(weapon:getID()) then player:unequipItem(xi.slot.MAIN) end
end

m:addOverride('xi.actions.abilities.steal.onAbilityCheck', function(player, target, ability)
    if not isPhantom(player) then return super(player, target, ability) end
    if not target or not target:isMob() or not target:isAlive() or player:checkDistance(target) > 15 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRecast(18)
    ability:setRange(15)
    ability:setCE(180)
    ability:setVE(650)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.steal.onUseAbility', function(player, target, ability, action)
    if not isPhantom(player) then return super(player, target, ability, action) end
    player:setLocalVar(DARE_CD, now() + 18)
    player:setLocalVar(GUARD_UNTIL, now() + 6)
    if action then action:messageID(target:getID(), xi.msg.basic.USES_JA) end
    return 0
end)

local previousDamage = xi.soulspire.onPreTakeDamage
xi.soulspire.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if previousDamage then amount = previousDamage(defender, amount, attacker, attackType, damageType) end
    if type(amount) ~= 'number' or amount <= 0 or not isPhantom(defender) or
        not attacker or not attacker:isMob() or remaining(defender, GUARD_UNTIL) == 0 or
        (attackType ~= xi.attackType.MAGICAL and attackType ~= xi.attackType.BREATH)
    then
        return amount
    end
    defender:setLocalVar(GUARD_UNTIL, 0)
    local percent = scale(defender:getMainLvl(), 8, 10, 12, 15)
    return math.max(1, math.floor(amount * (100 - percent) / 100))
end

actions.register('phantom',
{
    ability = { [DARE] = { name = "Phantom's Dare", description = help, recastTime = 18 } },
})

spec.registerCrystal(xi.job.THF,
{
    id = 3, key = 'phantom', name = 'Phantom', abr = 'PHN', role = 'Tank', icon = 'phantom', reqLevel = 10,
    description = 'A Dagger or Katana evasion tank that opens with direct threat and maintains it as enemy swings miss.',
    highlights =
    {
        "Phantom's Dare unlocks at Lv.10, adds base 180 CE / 650 VE, and arms a one-hit magic/breath guard for 6s.",
        'Guard mitigation scales from 8% to 10/12/15%. Ordinary hits never spend it.',
        'Genuine melee evades reinforce threat every 2s with a Dagger or Katana equipped.',
    },
    extraAbilities = function(_, level) return level >= 10 and { DARE } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.DAGGER, scale(level, 10, 20, 30, 42) },
            { xi.mod.EVA,    scale(level, 20, 35, 55, 75) },
            { xi.mod.AGI,    scale(level, 7, 12, 18, 25) },
            { xi.mod.HPP,    scale(level, 8, 12, 16, 20) },
            { xi.mod.DMG,   -scale(level, 500, 700, 1000, 1200) },
            { xi.mod.ENMITY, scale(level, 20, 30, 40, 50) },
        }
    end,
    onApply = attach,
    onRemove = detach,
})

m:addOverride('xi.player.onGameIn', function(player, ...)
    super(player, ...)
    if isPhantom(player) then
        player:setLocalVar(GUARD_UNTIL, 0)
        attach(player)
    end
end)

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('phantom', function(player)
        return
        {
            dare_cd = remaining(player, DARE_CD), guard_rem = remaining(player, GUARD_UNTIL),
            evade_cd = remaining(player, EVADE_CD), weapon = hasWeapon(player) and 1 or 0,
        }
    end)
end

return m
