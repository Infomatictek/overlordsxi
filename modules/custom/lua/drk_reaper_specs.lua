-- Reaper (DRK) - time Scythe strikes against a monster's recovery.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/spells/damage_spell')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/combat/physical_hit_rate')
require('scripts/combat/physical_utilities')
require('scripts/combat/basic/damage_multipliers')

local m = Module:new('soulspire_drk_reaper')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.DRK] then require('modules/custom/lua/drk_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local OPEN, SPENT, CD = 'OX_RPR_OPEN_UNTIL', 'OX_RPR_SPENT', 'OX_RPR_CD'
local finalityHelp = 'Strike with your Scythe. Land during enemy recovery for greater damage, with a finishing bonus from Lv.50. 16s recast.'
local REAPER_KIT_SPELLS =
{
    [245] =
    {
        script = 'drain', name = 'Grave Toll', unlockLvl = 10, castMs = 1500, recastSec = 12, mpCost = 12,
        description = 'Strike one enemy with darkness from range. Enemy recovery increases the damage. Costs 12 MP. 12s recast.',
    },
}
xi.soulspire.drkReaperSpecs = { REAPER_KIT_SPELLS = REAPER_KIT_SPELLS }

local function isReaper(player)
    return player and player:isPC() and player:getMainJob() == xi.job.DRK and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.DRK, 'reaper')
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

local function recovery(target)
    if not target or not target:isMob() or not target:isAlive() then return 0 end
    return math.max(0, target:getLocalVar(OPEN) - now())
end

local function canFinish(player, target)
    return recovery(target) > 0 and
        (player:getLocalVar('OX_RPR_SPENT_TARGET') ~= target:getID() or player:getLocalVar(SPENT) ~= target:getLocalVar(OPEN))
end

local function apply(player)
    player:setLocalVar('OX_RPR_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar('OX_RPR_ACTIVE', 0)
    player:setLocalVar(SPENT, 0)
    player:setLocalVar('OX_RPR_SPENT_TARGET', 0)
    player:sendSoulSpellList()
end

m:addOverride('xi.actions.abilities.weapon_bash.onAbilityCheck', function(player, target, ability)
    if not isReaper(player) then return super(player, target, ability) end
    if player:getWeaponSkillType(xi.slot.MAIN) ~= xi.skill.SCYTHE or not target or not target:isMob() or
        not target:isAlive() or player:checkDistance(target) > 4
    then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRange(4)
    ability:setRecast(16)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.weapon_bash.onUseAbility', function(player, target, ability, action)
    if not isReaper(player) then return super(player, target, ability, action) end
    player:setLocalVar(CD, now() + 16)
    local hitRate = xi.combat.physicalHitRate.getPhysicalHitRate(player, target, 0, xi.slot.MAIN, false)
    if math.random() >= hitRate then
        if action then action:messageID(target:getID(), xi.msg.basic.HIT_MISS) end
        return 0
    end

    local level = player:getMainLvl()
    local armed = canFinish(player, target)
    local multiplier = armed and scale(level, 2.3, 2.6, 2.6, 3.0) or 1.3
    local pdif = xi.combat.physical.calculateMeleePDIF(player, target, xi.skill.SCYTHE, 1, false, true, false, 0, false, xi.slot.MAIN, false)
    local base = player:getWeaponDmg(xi.slot.MAIN) + math.floor(player:getStat(xi.mod.STR) / 4)
    local scalar = xi.combat.damage.calculateDamageAdjustment(target, true, false, false, false) *
        xi.combat.damage.physicalElementSDT(target, xi.damageType.SLASHING)
    local damage = math.max(0, math.floor(base * pdif * multiplier * scalar))
    if armed and level >= 50 and target:getHPP() < 25 then
        damage = math.floor(damage * (level >= 70 and 120 or 115) / 100)
    end
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        damage = xi.customBossServer.scaleDamageByLevelGap(player, target, damage)
    end
    damage = utils.clamp(utils.handlePhalanx(target, damage), 0, 99999)
    damage = utils.handleStoneskin(target, damage, xi.attackType.PHYSICAL)
    damage = target:checkDamageCap(damage)
    local hp = target:getHP()
    target:takeDamage(damage, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    local landed = math.max(0, hp - target:getHP())
    if landed > 0 then
        target:updateEnmityFromDamage(player, landed)
        if armed then
            player:setLocalVar(SPENT, target:getLocalVar(OPEN))
            player:setLocalVar('OX_RPR_SPENT_TARGET', target:getID())
        end
    end
    if action then action:messageID(target:getID(), xi.msg.basic.JA_DAMAGE) end
    return landed
end)

m:addOverride('xi.actions.spells.black.drain.onSpellCast', function(player, target, spell, action)
    if not isReaper(player) then return super(player, target, spell, action) end
    local element = xi.element.DARK
    local magic = xi.spells.damage
    if magic.calculateNullification(target, element, false, true, false, false) == 0 or
        magic.calculateAbsorption(target, element, false, true, false, false) < 0
    then
        spell:setMsg(xi.msg.basic.MAGIC_RESIST)
        return 0
    end

    local level = player:getMainLvl()
    local amount = scale(level, 12, 26, 48, 73) + math.floor(player:getSkillLevel(xi.skill.DARK_MAGIC) / 4)
    local params = { magicalElement = element, actorStat = xi.mod.INT, skillType = xi.skill.DARK_MAGIC, spellGroup = xi.magic.spellGroup.BLACK }
    local resist = xi.combat.magicHitRate.calculateResistRate(player, target, params) *
        magic.calculateAdditionalResistTier(player, target, element)
    if recovery(target) > 0 then amount = amount * 1.5 end
    amount = math.floor(amount * resist * xi.combat.damage.magicalElementSDT(target, element) *
        xi.combat.damage.calculateDamageAdjustment(target, false, true, false, false))
    amount = utils.clamp(utils.handlePhalanx(target, amount), 0, 99999)
    amount = utils.handleOneForAll(target, amount)
    amount = utils.handleStoneskin(target, amount, xi.attackType.MAGICAL)
    amount = target:checkDamageCap(amount)
    local hp = target:getHP()
    target:takeSpellDamage(player, spell, amount, xi.attackType.MAGICAL, xi.damageType.DARK)
    local landed = math.max(0, hp - target:getHP())
    target:handleAfflatusMiseryDamage(landed)
    if landed > 0 then target:updateEnmityFromDamage(player, landed) end
    spell:setMsg(xi.msg.basic.MAGIC_DMG)
    return landed
end)

actions.register('reaper',
{
    spell = REAPER_KIT_SPELLS,
    ability = { [77] = { name = 'Finality', description = finalityHelp, recastTime = 16 } },
})

spec.registerCrystal(xi.job.DRK,
{
    id = 1, key = 'reaper', name = 'Reaper', abr = 'RPR', role = 'Damage', icon = 'reaper', reqLevel = 10,
    description = 'A Scythe executioner who times powerful single-target strikes as enemies recover from their own attacks.',
    highlights =
    {
        'Damaging enemy spells and TP moves or every sixth completed enemy melee round open five seconds of recovery.',
        'Finality (4y) deals 1.3x normalized Scythe damage, increasing to 2.3/2.6/2.6/3.0x during recovery.',
        'Below 25% target HP, a recovery Finality gains a further 15% at Lv.50 and 20% at Lv.70.',
        'Grave Toll deals single-target dark damage, gaining 50% during recovery without spending Finality.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 77 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.SCYTHE, scale(level, 12, 22, 34, 46) },
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
        if isReaper(player) then apply(player) end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('reaper', function(player)
        local target = player:getTarget()
        return
        {
            recovery = canFinish(player, target) and recovery(target) or 0,
            enemy_rounds = target and target:isMob() and target:getLocalVar('OX_RPR_ROUNDS') or 0,
            finality_cd = math.max(0, player:getLocalVar(CD) - now()),
        }
    end)
end

return m
