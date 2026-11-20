-- Oathbreaker (PLD) — pre-pull commitment to sustained offense or retaliation.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/combat/physical_hit_rate')
require('scripts/combat/physical_utilities')
require('scripts/combat/basic/damage_multipliers')

local m = Module:new('soulspire_pld_oathbreaker')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.PLD] then
    require('modules/custom/lua/pld_specs')
end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local CONDEMN, ABSOLVE = 1, 2
local VOW, VOW_CD, BONUS = 'OX_OTB_VOW', 'OX_OTB_VOW_CD', 'OX_OTB_BONUS'
local RETAL_TARGET, RETAL_UNTIL = 'OX_OTB_RETAL_TARGET', 'OX_OTB_RETAL_UNTIL'
local RECKON_CD, HIT_LISTENER = 'OX_OTB_RECKON_CD', 'OX_OTB_TAKE_HP'
local condemnHelp = 'Commit before combat to stronger Great Sword swings and 10% more damage taken from enemies. Vows share a 5s recast.'
local absolveHelp = 'Commit before combat to retaliation. Losing at least 8% max HP to one enemy hit opens an empowered Reckoning. Vows share a 5s recast.'
local reckoningHelp = 'Strike with your Great Sword. An armed retaliation doubles damage against the enemy that hit you. 18s recast.'
local OATHBREAKER_KIT_SPELLS =
{
    [28] =
    {
        script = 'banish', name = 'Ashen Judgment', unlockLvl = 10, castMs = 2000, recastSec = 15, mpCost = 15,
        description = 'Strike one enemy with light from range. Costs 15 MP. 15s recast.',
    },
}
xi.soulspire.pldOathbreakerSpecs = { OATHBREAKER_KIT_SPELLS = OATHBREAKER_KIT_SPELLS }

local function isOathbreaker(player)
    return player and player:isPC() and player:getMainJob() == xi.job.PLD and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.PLD, 'oathbreaker')
end

local function hasGreatSword(player)
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.GREAT_SWORD
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

local function clearRetaliation(player)
    player:setLocalVar(RETAL_TARGET, 0)
    player:setLocalVar(RETAL_UNTIL, 0)
end

local function apply(player)
    player:setLocalVar('OX_OTB_ACTIVE', 1)
    player:setLocalVar(BONUS, scale(player:getMainLvl(), 10, 13, 16, 18))
    if player:getLocalVar(VOW) == 0 then player:setLocalVar(VOW, CONDEMN) end
    player:sendSoulSpellList()
    player:removeListener(HIT_LISTENER)
    player:addListener('SOUL_DIRECT_HP_LOSS', HIT_LISTENER, function(defender, attacker, damage)
        if not isOathbreaker(defender) or defender:getLocalVar(VOW) ~= ABSOLVE or not hasGreatSword(defender) or
            not attacker or not attacker:isMob() or not attacker:isAlive() or damage < defender:getMaxHP() * 0.08
        then
            return
        end
        defender:setLocalVar(RETAL_TARGET, attacker:getID())
        defender:setLocalVar(RETAL_UNTIL, now() + (defender:getMainLvl() >= 50 and 7 or 5))
    end)
end

local function remove(player)
    player:setLocalVar('OX_OTB_ACTIVE', 0)
    player:setLocalVar(VOW, 0)
    player:setLocalVar(BONUS, 0)
    clearRetaliation(player)
    player:removeListener(HIT_LISTENER)
    player:sendSoulSpellList()
end

for _, action in ipairs({ { 'sentinel', CONDEMN }, { 'divine_emblem', ABSOLVE } }) do
    local path = 'xi.actions.abilities.' .. action[1]
    local vow = action[2]
    m:addOverride(path .. '.onAbilityCheck', function(player, target, ability)
        if not isOathbreaker(player) then return super(player, target, ability) end
        if player:isEngaged() or player:hasEnmity() or remaining(player, VOW_CD) > 0 or player:getLocalVar(VOW) == vow then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        ability:setRecast(5)
        ability:setCE(0)
        ability:setVE(0)
        return 0, 0
    end)

    m:addOverride(path .. '.onUseAbility', function(player, target, ability, actionPacket)
        if not isOathbreaker(player) then return super(player, target, ability, actionPacket) end
        clearRetaliation(player)
        player:setLocalVar(VOW, vow)
        player:setLocalVar(VOW_CD, now() + 5)
        return 0
    end)
end

m:addOverride('xi.actions.abilities.shield_bash.onAbilityCheck', function(player, target, ability)
    if not isOathbreaker(player) then return super(player, target, ability) end
    if not hasGreatSword(player) or not target or not target:isMob() or not target:isAlive() or player:checkDistance(target) > 4 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRange(4)
    ability:setRecast(18)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.shield_bash.onUseAbility', function(player, target, ability, action)
    if not isOathbreaker(player) then return super(player, target, ability, action) end
    player:setLocalVar(RECKON_CD, now() + 18)
    local hitRate = xi.combat.physicalHitRate.getPhysicalHitRate(player, target, 0, xi.slot.MAIN, false)
    if math.random() >= hitRate then
        if action then action:messageID(target:getID(), xi.msg.basic.HIT_MISS) end
        return 0
    end

    local level = player:getMainLvl()
    local multiplier = scale(level, 1.5, 1.7, 1.7, 2)
    local armed = player:getLocalVar(VOW) == ABSOLVE and player:getLocalVar(RETAL_TARGET) == target:getID() and
        remaining(player, RETAL_UNTIL) > 0
    if armed then multiplier = multiplier * 2 end
    local pdif = xi.combat.physical.calculateMeleePDIF(player, target, xi.skill.GREAT_SWORD, 1, false, true, false, 0, false, xi.slot.MAIN, false)
    local base = player:getWeaponDmg(xi.slot.MAIN) + math.floor(player:getStat(xi.mod.STR) / 4)
    local scalar = xi.combat.damage.calculateDamageAdjustment(target, true, false, false, false) *
        xi.combat.damage.physicalElementSDT(target, xi.damageType.SLASHING)
    local damage = math.max(0, math.floor(base * pdif * multiplier * scalar))
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
        if armed then clearRetaliation(player) end
    end
    if action then action:messageID(target:getID(), xi.msg.basic.JA_DAMAGE) end
    return landed
end)

local priorDamage = xi.soulspire.onPreTakeDamage
xi.soulspire.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if priorDamage then amount = priorDamage(defender, amount, attacker, attackType, damageType) end
    if type(amount) == 'number' and amount > 0 and attacker and attacker:isMob() and isOathbreaker(defender) and
        defender:getLocalVar(VOW) == CONDEMN
    then
        return math.floor(amount * 1.10)
    end
    return amount
end

actions.register('oathbreaker',
{
    spell = OATHBREAKER_KIT_SPELLS,
    ability =
    {
        [48] = { name = 'Vow of Condemnation', description = condemnHelp, recastTime = 5 },
        [255] = { name = 'Vow of Absolution', description = absolveHelp, recastTime = 5 },
        [46] = { name = 'Reckoning', description = reckoningHelp, recastTime = 18 },
    },
})

spec.registerCrystal(xi.job.PLD,
{
    id = 3, key = 'oathbreaker', name = 'Oathbreaker', abr = 'OTB', role = 'Damage', icon = 'oathbreaker', reqLevel = 10,
    description = 'Commit before combat to vulnerable Great Sword pressure or a reactive retaliation vow.',
    highlights =
    {
        'Condemn increases regular Great Sword damage by 10/13/16/18% and enemy damage received by 10%.',
        'Absolve opens retaliation after a single enemy hit costs at least 8% max HP. It provides no mitigation.',
        'Reckoning doubles against the enemy that opened retaliation. Vows can only change outside combat.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 48, 255, 46 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.GREAT_SWORD, scale(level, 12, 22, 34, 46) },
            { xi.mod.STR, scale(level, 6, 12, 18, 25) },
            { xi.mod.ACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.ATT, scale(level, 12, 22, 36, 50) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isOathbreaker(player) then
            if event == 'onGameIn' then clearRetaliation(player) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('oathbreaker', function(player)
        local target = player:getTarget()
        return
        {
            vow = player:getLocalVar(VOW), vow_cd = remaining(player, VOW_CD), reckoning_cd = remaining(player, RECKON_CD),
            retaliate_rem = target and target:getID() == player:getLocalVar(RETAL_TARGET) and remaining(player, RETAL_UNTIL) or 0,
        }
    end)
end

return m
