-- Bandit (THF) — exploit exposed targets for weapon-skill momentum.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_thf_bandit')
local spec = xi.soulspire.spec
local actions = require('modules/custom/lua/soulspire_soul_actions')
local BACK_ALLEY_STRIKE, FIND_GAP = 44, 45
local GAP_TARGET, GAP_UNTIL = 'OX_BND_GAP_TARGET', 'OX_BND_GAP_UNTIL'
local PREPARED_WS, EXPLOIT_UNTIL = 'OX_BND_PREPARED_WS', 'OX_BND_EXPLOIT_UNTIL'
local GAP_COOLDOWN, STRIKE_COOLDOWN = 'OX_BND_GAP_COOLDOWN', 'OX_BND_STRIKE_COOLDOWN'
local gapHelp = 'Read one enemy for a personal opening that qualifies your next landed weapon skill for Opportunism. Lasts 15s. 24s recast.'
local strikeHelp = 'Prepare a critical strike from behind. Lasts up to 20s. 45s recast.'

local function isBandit(player)
    return player and player:isPC() and player:getMainJob() == xi.job.THF and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.THF, 'bandit')
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

local function remaining(player, variable)
    return math.max(0, player:getLocalVar(variable) - now())
end

local function hasGap(player, target)
    return target and target:isMob() and target:getID() == player:getLocalVar(GAP_TARGET) and remaining(player, GAP_UNTIL) > 0
end

local function clearGap(player)
    player:setLocalVar(GAP_TARGET, 0)
    player:setLocalVar(GAP_UNTIL, 0)
end

local function attach(player)
    player:setLocalVar('OX_BND_ACTIVE', 1)
    player:sendSoulSpellList()
    player:removeListener('OX_BND_WS_START')
    player:removeListener('OX_BND_WS_USE')
    player:removeListener('OX_BND_WS_EXIT')

    player:addListener('SOUL_WS_START', 'OX_BND_WS_START', function(actor, target)
        actor:setLocalVar(PREPARED_WS, 0)
        if isBandit(actor) and hasWeapon(actor) and target and target:isMob() and
            (hasGap(actor, target) or target:hasStatusEffect(xi.effect.DEFENSE_DOWN))
        then
            actor:setLocalVar(PREPARED_WS, target:getID())
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_BND_WS_USE', function(actor, target, _, _, _, damage)
        local prepared = actor:getLocalVar(PREPARED_WS)
        actor:setLocalVar(PREPARED_WS, 0)
        if prepared == 0 or not isBandit(actor) or not hasWeapon(actor) or not target or
            target:getID() ~= prepared or type(damage) ~= 'number' or damage <= 0 or remaining(actor, EXPLOIT_UNTIL) > 0
        then
            return
        end
        actor:addTP(scale(actor:getMainLvl(), 75, 100, 125, 150))
        actor:setLocalVar(EXPLOIT_UNTIL, now() + 12)
        if target:getID() == actor:getLocalVar(GAP_TARGET) then clearGap(actor) end
    end)

    player:addListener('WEAPONSKILL_STATE_EXIT', 'OX_BND_WS_EXIT', function(actor)
        actor:setLocalVar(PREPARED_WS, 0)
    end)
end

local function detach(player)
    player:setLocalVar('OX_BND_ACTIVE', 0)
    player:setLocalVar(PREPARED_WS, 0)
    clearGap(player)
    player:removeListener('OX_BND_WS_START')
    player:removeListener('OX_BND_WS_USE')
    player:removeListener('OX_BND_WS_EXIT')
    player:delStatusEffectSilent(xi.effect.SNEAK_ATTACK)
    player:sendSoulSpellList()
end

m:addOverride('xi.actions.abilities.mug.onAbilityCheck', function(player, target, ability)
    if not isBandit(player) then return super(player, target, ability) end
    if not target or not target:isMob() or not target:isAlive() or not hasWeapon(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRecast(24)
    ability:setRange(5)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.mug.onUseAbility', function(player, target, ability, action)
    if not isBandit(player) then return super(player, target, ability, action) end
    player:setLocalVar(GAP_TARGET, target:getID())
    player:setLocalVar(GAP_UNTIL, now() + 15)
    player:setLocalVar(GAP_COOLDOWN, now() + 24)
    if action then action:messageID(target:getID(), xi.msg.basic.USES_JA) end
    return 0
end)

m:addOverride('xi.actions.abilities.sneak_attack.onAbilityCheck', function(player, target, ability)
    if not isBandit(player) then return super(player, target, ability) end
    if not hasWeapon(player) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(45)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.sneak_attack.onUseAbility', function(player, target, ability, action)
    if not isBandit(player) then return super(player, target, ability, action) end
    player:addStatusEffect(xi.effect.SNEAK_ATTACK, { power = 1, duration = 20, origin = player })
    player:setLocalVar(STRIKE_COOLDOWN, now() + 45)
    return xi.effect.SNEAK_ATTACK
end)

actions.register('bandit',
{
    ability =
    {
        [BACK_ALLEY_STRIKE] = { name = 'Back Alley Strike', description = strikeHelp, recastTime = 45 },
        [FIND_GAP] = { name = 'Find the Gap', description = gapHelp, recastTime = 24 },
    },
})

spec.registerCrystal(xi.job.THF,
{
    id = 2, key = 'bandit', name = 'Bandit', abr = 'BND', role = 'Damage', icon = 'bandit', reqLevel = 10,
    description = 'Time a landed Dagger or Sword weapon skill to exploit a weakness and reclaim TP.',
    highlights =
    {
        'Find the Gap creates a personal opening. Existing enemy Defense Down also qualifies.',
        'Opportunism refunds 75/100/125/150 TP on a qualified damaging weapon skill. 12s personal lockout.',
        'Back Alley Strike prepares a positional critical attack. Both actions unlock at Lv.10.',
    },
    extraAbilities = function(_, level) return level >= 10 and { BACK_ALLEY_STRIKE, FIND_GAP } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.DAGGER,      scale(level, 12, 22, 34, 48) },
            { xi.mod.ACC,         scale(level, 10, 20, 30, 42) },
            { xi.mod.ATT,         scale(level, 12, 24, 38, 55) },
            { xi.mod.DEX,         scale(level, 6, 12, 18, 24) },
            { xi.mod.CRITHITRATE, scale(level, 3, 5, 7, 9) },
            { xi.mod.STORETP,     scale(level, 3, 5, 7, 10) },
        }
    end,
    onApply = attach,
    onRemove = detach,
})

m:addOverride('xi.player.onGameIn', function(player, ...)
    super(player, ...)
    if isBandit(player) then
        clearGap(player)
        attach(player)
    end
end)

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('bandit', function(player)
        local target = player:getTarget()
        return
        {
            gap_rem = hasGap(player, target) and remaining(player, GAP_UNTIL) or 0,
            exposed = target and target:isMob() and target:hasStatusEffect(xi.effect.DEFENSE_DOWN) and 1 or 0,
            exploit_cd = remaining(player, EXPLOIT_UNTIL),
            gap_cd = remaining(player, GAP_COOLDOWN),
            strike_cd = remaining(player, STRIKE_COOLDOWN),
        }
    end)
end

return m
