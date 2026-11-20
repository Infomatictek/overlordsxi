-- Lancer (DRG) - turn a clear launch lane into a polearm follow-through.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/combat/physical_hit_rate')
require('scripts/combat/physical_utilities')
require('scripts/combat/basic/damage_multipliers')

local m = Module:new('soulspire_drg_lancer')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.DRG] then require('modules/custom/lua/drg_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local ACTIVE, VAULT_CD = 'OX_LNC_ACTIVE', 'OX_LNC_VAULT_CD'
local FOLLOW_TARGET, FOLLOW_END = 'OX_LNC_FOLLOW_TARGET', 'OX_LNC_FOLLOW_END'
local vaultHelp = 'Vault to an enemy 4 to 12 yalms away and strike with your polearm. A longer lane hits harder. Blocked terrain gives a three-second retry. 18s recast.'
local jumpHelp = 'Leap and strike with your polearm. From Lv.50, a landed long vault can strengthen this hit against the same enemy. 60s recast.'

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function isLancer(player)
    return player and player:isPC() and player:getMainJob() == xi.job.DRG and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.DRG, 'lancer')
end

local function hasPolearm(player)
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
end

local function clearFollowup(player)
    player:setLocalVar(FOLLOW_TARGET, 0)
    player:setLocalVar(FOLLOW_END, 0)
end

local function followupRemaining(player, target)
    if not target or not target:isMob() or not target:isAlive() or target:getID() ~= player:getLocalVar(FOLLOW_TARGET) then return 0 end
    return math.max(0, player:getLocalVar(FOLLOW_END) - now())
end

xi.soulspire.lancer =
{
    jumpBonus = function(player, target)
        if not isLancer(player) or not hasPolearm(player) or player:getMainLvl() < 50 or followupRemaining(player, target) == 0 then return 0 end
        return player:getMainLvl() >= 70 and 20 or 15
    end,
    finishJump = clearFollowup,
}

m:addOverride('xi.actions.abilities.high_jump.onAbilityCheck', function(player, target, ability)
    if not isLancer(player) then return super(player, target, ability) end
    if not hasPolearm(player) or not target or not target:isMob() or not target:isAlive() then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local lane = player:checkDistance(target)
    if lane < 4 or lane > 12 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRange(12)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.high_jump.onUseAbility', function(player, target, ability, action)
    if not isLancer(player) then return super(player, target, ability, action) end
    local lane = player:checkDistance(target)
    local landing = player:getLancerLanding(target)
    if not landing then
        ability:setRecast(3)
        ability:setMsg(xi.msg.basic.NONE)
        player:setLocalVar(VAULT_CD, now() + 3)
        player:printToPlayer('Vault blocked. You can retry in three seconds.', xi.msg.channel.SYSTEM_3)
        return 0
    end

    player:setPos(landing.x, landing.y, landing.z, landing.rotation)
    ability:setRecast(18)
    player:setLocalVar(VAULT_CD, now() + 18)
    local hitRate = xi.combat.physicalHitRate.getPhysicalHitRate(player, target, 0, xi.slot.MAIN, false)
    if math.random() >= hitRate then
        if action then action:messageID(target:getID(), xi.msg.basic.HIT_MISS) end
        return 0
    end

    local level = player:getMainLvl()
    local longLane = lane > 7
    local percent = longLane and scale(level, 220, 250, 250, 280) or 160
    local pdif = xi.combat.physical.calculateMeleePDIF(player, target, xi.skill.POLEARM, 1, false, true, false, 0, false, xi.slot.MAIN, false)
    local base = player:getWeaponDmg(xi.slot.MAIN) + math.floor(player:getStat(xi.mod.STR) / 4)
    local scalar = xi.combat.damage.physicalElementSDT(target, xi.damageType.PIERCING)
    local damage = math.max(0, math.floor(base * pdif * percent * scalar / 100))
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        damage = xi.customBossServer.scaleDamageByLevelGap(player, target, damage)
    end
    damage = target:physicalDmgTaken(damage, xi.damageType.PIERCING)
    if damage < 0 then
        if action then action:messageID(target:getID(), xi.msg.basic.JA_RECOVERS_HP) end
        return target:addHP(-damage)
    end
    damage = utils.clamp(utils.handlePhalanx(target, damage), 0, 99999)
    damage = utils.handleStoneskin(target, damage, xi.attackType.PHYSICAL)
    damage = target:checkDamageCap(damage)
    local hp = target:getHP()
    target:takeDamage(damage, player, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
    local landed = math.max(0, hp - target:getHP())
    if landed > 0 then
        target:updateEnmityFromDamage(player, landed)
        if longLane and level >= 50 and target:isAlive() then
            player:setLocalVar(FOLLOW_TARGET, target:getID())
            player:setLocalVar(FOLLOW_END, now() + 5)
        end
    end
    if action then action:messageID(target:getID(), xi.msg.basic.JA_DAMAGE) end
    return landed
end)

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    if player:getPet() then player:despawnPet() end
    if player:getMainLvl() < 50 then clearFollowup(player) end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    clearFollowup(player)
    player:sendSoulSpellList()
end

actions.register('lancer',
{
    ability =
    {
        [66] = { name = 'Piercing Jump', description = jumpHelp, recastTime = 60 },
        [67] = { name = 'Spineshatter Vault', description = vaultHelp, recastTime = 18 },
    },
})

spec.registerCrystal(xi.job.DRG,
{
    id = 1, key = 'lancer', name = 'Lancer', abr = 'LNC', role = 'Damage', icon = 'lancer', reqLevel = 10,
    description = 'A polearm specialist whose long, clear launch lanes give stronger vault strikes and a jump follow-through.',
    highlights =
    {
        'Spineshatter Vault works from Lv.10 between 4 and 12 yalms. Land at a safe spot near the target and strike once.',
        'Short lanes deal 1.6x normalized damage. Long lanes over 7 yalms deal 2.2/2.5/2.5/2.8x at Lv.10/30/50/70+.',
        'Blocked lanes spend three seconds of recast without moving or dealing damage.',
        'From Lv.50, a landed long vault powers the next Piercing Jump against the same enemy for five seconds.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 66, 67 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.POLEARM, scale(level, 12, 22, 34, 46) },
            { xi.mod.STR, scale(level, 6, 12, 18, 25) },
            { xi.mod.ACC, scale(level, 10, 18, 28, 40) },
            { xi.mod.ATT, scale(level, 12, 24, 38, 54) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isLancer(player) then
            if event == 'onGameIn' then clearFollowup(player) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('lancer', function(player)
        local target = player:getTarget()
        local lane = target and target:isMob() and target:isAlive() and player:checkDistance(target) or 0
        return
        {
            lane = lane > 12 and 3 or (lane > 7 and 2 or (lane >= 4 and 1 or 0)),
            vault_cd = math.max(0, player:getLocalVar(VAULT_CD) - now()),
            followup = followupRemaining(player, target),
        }
    end)
end

return m
