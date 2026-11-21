-- Sniper (RNG) - take a deliberate single shot with a gun or crossbow.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_rng_sniper')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.RNG] then require('modules/custom/lua/rng_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local ACTIVE, DEEP, AIM = 'OX_SNP_ACTIVE', 'OX_SNP_DEEP', 'OX_SNP_AIM_UNTIL'
local SIGHTLINE_CD = 'OX_SNP_RECAST_UNTIL'
local sightlineHelp = 'Aim for 3 seconds, then fire one powerful gun or crossbow shot within 20 yalms. Movement can cancel aim. 12s recast.'
local deepHelp = 'Toggle a 4-second aim for greater Sightline Shot damage. 5s recast.'

local function isSniper(player)
    return player and player:isPC() and player:getMainJob() == xi.job.RNG and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.RNG, 'sniper')
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    if player:getMainLvl() < 50 then player:setLocalVar(DEEP, 0) end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    player:setLocalVar(DEEP, 0)
    player:setLocalVar(AIM, 0)
    player:sendSoulSpellList()
end

m:addOverride('xi.actions.abilities.sharpshot.onAbilityCheck', function(player, target, ability)
    if not isSniper(player) then return super(player, target, ability) end
    if player:getMainLvl() < 50 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(5)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.sharpshot.onUseAbility', function(player, target, ability, action)
    if not isSniper(player) then return super(player, target, ability, action) end
    local enabled = player:getLocalVar(DEEP) == 0
    player:setLocalVar(DEEP, enabled and 1 or 0)
    if action then action:messageID(player:getID(), xi.msg.basic.NONE) end
    player:printToPlayer(enabled and 'Deep Sight selected: four-second aim.' or 'Steady Sight selected: three-second aim.', xi.msg.channel.SYSTEM_3)
    return 0
end)

actions.register('sniper',
{
    ability =
    {
        [57] = { name = 'Sightline Shot', description = sightlineHelp, recastTime = 12 },
        [59] = { name = 'Deep Sight', description = deepHelp, recastTime = 5 },
    },
})

spec.registerCrystal(xi.job.RNG,
{
    id = 1, key = 'sniper', name = 'Sniper', abr = 'SNP', role = 'Damage', icon = 'sniper', reqLevel = 10,
    description = 'A deliberate marksman who commits to one high-precision shot with a gun or crossbow.',
    highlights =
    {
        'Sightline Shot fires one projectile after three seconds of aim (20y, 12-second recast). It works from Lv.10.',
        'Sightline Shot gains +10/20/20/30 Ranged Accuracy at Lv.10/30/50/70+ and deals 2.0x at Lv.10 or 2.3x from Lv.30.',
        'Deep Sight (Lv.50+) trades four seconds of aim for 2.8x damage, increasing to 3.2x at Lv.70.',
        'Moving beyond one yalm, losing your firing lane, changing engaged target, or being incapacitated cancels aim. Cancellations spend no ammo and have a three-second retry.',
    },
    extraAbilities = function(_, level)
        if level >= 50 then return { 57, 59 } end
        return level >= 10 and { 57 } or {}
    end,
    mods = function(_, level)
        return
        {
            { xi.mod.MARKSMANSHIP, scale(level, 12, 22, 34, 46) },
            { xi.mod.RACC, scale(level, 12, 22, 34, 46) },
            { xi.mod.RATT, scale(level, 12, 24, 38, 54) },
            { xi.mod.AGI, scale(level, 6, 12, 18, 25) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isSniper(player) then
            if event == 'onGameIn' then player:setLocalVar(AIM, 0) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('sniper', function(player)
        local now = math.floor(xi.soulspire.nowSec())
        return
        {
            aim_rem = math.max(0, player:getLocalVar(AIM) - now),
            shot_cd = math.max(0, player:getLocalVar(SIGHTLINE_CD) - now),
            deep = player:getLocalVar(DEEP),
        }
    end)
end

return m
