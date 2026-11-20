-- Trickster (THF) — route threat by position and suppress enemy attacks with a landed WS.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_thf_trickster')
local spec = xi.soulspire.spec
local actions = require('modules/custom/lua/soulspire_soul_actions')
local PASS_BLAME = 76
local WS_LISTENER = 'OX_TRK_SUPPRESS_WS'
local SUPPRESS_CD = 'OX_TRK_SUPPRESS_CD'
local BLAME_CD = 'OX_TRK_BLAME_CD'
local help = 'Route your next qualifying hit or weapon skill threat to the party member between you and your enemy. Lasts up to 20s. 35s recast.'

local function isTrickster(player)
    return player and player:isPC() and player:getMainJob() == xi.job.THF and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.THF, 'trickster')
end

local function hasWeapon(player)
    local skill = player:getWeaponSkillType(xi.slot.MAIN)
    return skill == xi.skill.DAGGER or skill == xi.skill.SWORD
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

local function remaining(player, localVar)
    return math.max(0, player:getLocalVar(localVar) - now())
end

local function attach(player)
    player:setLocalVar('OX_TRK_ACTIVE', 1)
    player:sendSoulSpellList()
    player:removeListener(WS_LISTENER)
    player:addListener('WEAPONSKILL_USE', WS_LISTENER, function(actor, target, _, _, _, damage)
        if not isTrickster(actor) or not hasWeapon(actor) or not target or not target:isMob() or not target:isAlive() or
            type(damage) ~= 'number' or damage <= 0 or remaining(actor, SUPPRESS_CD) > 0 or target:hasStatusEffect(xi.effect.ATTACK_DOWN)
        then
            return
        end
        if target:addStatusEffect(xi.effect.ATTACK_DOWN, {
            power = scale(actor:getMainLvl(), 5, 7, 9, 12), duration = 16, origin = actor,
        }) then
            actor:setLocalVar(SUPPRESS_CD, now() + 20)
        end
    end)
end

local function detach(player)
    player:setLocalVar('OX_TRK_ACTIVE', 0)
    player:removeListener(WS_LISTENER)
    player:delStatusEffectSilent(xi.effect.TRICK_ATTACK)
    player:sendSoulSpellList()
end

m:addOverride('xi.actions.abilities.trick_attack.onAbilityCheck', function(player, target, ability)
    if not isTrickster(player) then return super(player, target, ability) end
    if not hasWeapon(player) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(35)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.trick_attack.onUseAbility', function(player, target, ability, action)
    if not isTrickster(player) then return super(player, target, ability, action) end
    player:addStatusEffect(xi.effect.TRICK_ATTACK, { power = 1, duration = 20, origin = player })
    player:setLocalVar(BLAME_CD, now() + 35)
    return xi.effect.TRICK_ATTACK
end)

actions.register('trickster',
{
    ability = { [PASS_BLAME] = { name = 'Pass the Blame', description = help, recastTime = 35 } },
})

spec.registerCrystal(xi.job.THF,
{
    id = 1, key = 'trickster', name = 'Trickster', abr = 'TRK', role = 'Support', icon = 'trickster', reqLevel = 10,
    description = 'Position behind the party member who should take threat, and weaken the enemy with well-timed weapon skills.',
    highlights =
    {
        'Pass the Blame unlocks at Lv.10. Position an ally between yourself and the enemy to route threat.',
        'A damaging Dagger or Sword WS applies 5/7/9/12% Attack Down for 16s, once every 20s.',
        'A missed WS, an immunity or existing Attack Down keeps the cooldown available. Suppression works solo.',
    },
    extraAbilities = function(_, level) return level >= 10 and { PASS_BLAME } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.DAGGER,      scale(level, 12, 20, 30, 42) },
            { xi.mod.ACC,         scale(level, 10, 16, 24, 32) },
            { xi.mod.DEX,         scale(level, 6, 10, 15, 20) },
            { xi.mod.SUBTLE_BLOW, scale(level, 5, 8, 12, 16) },
            { xi.mod.ENMITY,     -scale(level, 8, 12, 16, 20) },
        }
    end,
    onApply = attach,
    onRemove = detach,
})

m:addOverride('xi.player.onGameIn', function(player, ...)
    super(player, ...)
    if isTrickster(player) then attach(player) end
end)

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('trickster', function(player)
        local target = player:getTarget()
        return
        {
            suppress_cd = remaining(player, SUPPRESS_CD), blame_cd = remaining(player, BLAME_CD),
            blame_ready = player:hasStatusEffect(xi.effect.TRICK_ATTACK) and 1 or 0,
            target_down = target and target:isMob() and target:hasStatusEffect(xi.effect.ATTACK_DOWN) and 1 or 0,
        }
    end)
end

return m
