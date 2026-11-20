-- Skyborn (DRG) - hold the enemy while timing one guarded impact.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_drg_skyborn')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.DRG] then require('modules/custom/lua/drg_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local ACTIVE, CRY_CD, GUARD_CD = 'OX_SKY_ACTIVE', 'OX_SKY_CRY_CD', 'OX_SKY_GUARD_CD'
local GUARD_END, GUARD_ID, GUARD_SEQ = 'OX_SKY_GUARD_END', 'OX_SKY_GUARD_ID', 'OX_SKY_GUARD_SEQ'
local WARD_HP, WARD_END = 'OX_SKY_WARD_HP', 'OX_SKY_WARD_END'
local TARGET, ZONE = 'OX_SKY_TARGET', 'OX_SKY_ZONE'
local WRAP_MS = 4294967296
local cryHelp = 'Challenge one enemy from up to 15 yalms and build immediate enmity. 16s recast.'
local guardHelp = 'Brace for 1.5 seconds to soften one direct hit. Stay targetable and hold enmity. From Lv.30, intercepting a hit creates a short ward. 20s recast.'

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function second()
    return math.floor(xi.soulspire.nowSec())
end

local function nowMs()
    return math.floor(xi.soulspire.nowSec() * 1000) % WRAP_MS
end

local function deadline(ms)
    return (nowMs() + ms) % WRAP_MS
end

local function remaining(player, variable, maxMs)
    local ms = (player:getLocalVar(variable) - nowMs()) % WRAP_MS
    return ms <= maxMs and ms or 0
end

local function isSkyborn(player)
    return player and player:isPC() and player:getMainJob() == xi.job.DRG and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.DRG, 'skyborn')
end

local function hasPolearm(player)
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
end

local function isEnemy(target)
    return target and target:isMob() and target:isAlive()
end

local function clear(player)
    player:setLocalVar(GUARD_ID, 0)
    player:setLocalVar(WARD_HP, 0)
    player:setLocalVar(TARGET, 0)
end

local function finishGuard(player, guardId, intercepted)
    if guardId == 0 or player:getLocalVar(GUARD_ID) ~= guardId then return end
    player:setLocalVar(GUARD_ID, 0)
    local targetId = player:getLocalVar(TARGET)
    player:setLocalVar(TARGET, 0)
    if not isSkyborn(player) or not player:isAlive() or not hasPolearm(player) or
        player:getZoneID() ~= player:getLocalVar(ZONE)
    then
        return
    end
    if targetId ~= 0 then
        local target = player:getTarget()
        if not target or target:getID() ~= targetId then target = GetMobByID(targetId, player:getInstance()) end
        if isEnemy(target) and target:getZoneID() == player:getZoneID() and target:getBattleID() == player:getBattleID() then
            target:addEnmity(player, 100, 300)
        end
    end

    if intercepted and player:getMainLvl() >= 30 then
        local amount = math.floor(player:getMaxHP() * scale(player:getMainLvl(), 0, 5, 8, 10) / 100)
        player:setLocalVar(WARD_HP, amount)
        player:setLocalVar(WARD_END, deadline(5000))
    end
end

m:addOverride('xi.actions.abilities.jump.onAbilityCheck', function(player, target, ability)
    if not isSkyborn(player) then return super(player, target, ability) end
    if not hasPolearm(player) or not isEnemy(target) or player:checkDistance(target) > 15 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRange(15)
    ability:setRecast(16)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.jump.onUseAbility', function(player, target, ability, action)
    if not isSkyborn(player) then return super(player, target, ability, action) end
    player:setLocalVar(CRY_CD, second() + 16)
    target:addEnmity(player, 200, 700)
    if action then action:messageID(target:getID(), xi.msg.basic.NONE) end
    player:printToPlayer('Grounding Cry challenges ' .. target:getName() .. '.', xi.msg.channel.SYSTEM_3)
    return 0
end)

m:addOverride('xi.actions.abilities.ancient_circle.onAbilityCheck', function(player, target, ability)
    if not isSkyborn(player) then return super(player, target, ability) end
    if not hasPolearm(player) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(20)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.ancient_circle.onUseAbility', function(player, target, ability, action)
    if not isSkyborn(player) then return super(player, target, ability, action) end
    local enemy = player:getTarget()
    local nextGuard = player:getLocalVar(GUARD_SEQ) % 4294967295 + 1
    player:setLocalVar(GUARD_SEQ, nextGuard)
    player:setLocalVar(GUARD_ID, nextGuard)
    player:setLocalVar(TARGET, isEnemy(enemy) and enemy:getID() or 0)
    player:setLocalVar(ZONE, player:getZoneID())
    player:setLocalVar(GUARD_END, deadline(1500))
    player:setLocalVar(GUARD_CD, second() + 20)
    player:timer(1500, function(actor) finishGuard(actor, nextGuard, false) end)
    if action then action:messageID(player:getID(), xi.msg.basic.NONE) end
    player:printToPlayer('Skyward Guard is ready for the next hit.', xi.msg.channel.SYSTEM_3)
    return 0
end)

local function isDirectHit(attacker, attackType)
    if not isEnemy(attacker) then return false end
    if attackType == xi.attackType.PHYSICAL or attackType == xi.attackType.RANGED then return true end
    return attacker:getLocalVar('OX_SCR_ACTION') ~= 0 and
        (attackType == xi.attackType.MAGICAL or attackType == xi.attackType.BREATH)
end

local priorDamage = xi.soulspire.onPreTakeDamage
xi.soulspire.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if priorDamage then amount = priorDamage(defender, amount, attacker, attackType, damageType) end
    if type(amount) ~= 'number' or amount <= 0 or not isSkyborn(defender) or not hasPolearm(defender) or
        not isDirectHit(attacker, attackType) or defender:getZoneID() ~= attacker:getZoneID() or
        defender:getBattleID() ~= attacker:getBattleID()
    then
        return amount
    end

    local guardId = defender:getLocalVar(GUARD_ID)
    if guardId ~= 0 then
        local armed = defender:getZoneID() == defender:getLocalVar(ZONE) and remaining(defender, GUARD_END, 1500) > 0
        finishGuard(defender, guardId, armed)
        if armed then
            local pct = scale(defender:getMainLvl(), 35, 40, 45, 50)
            return amount - math.floor(amount * pct / 100)
        end
    end

    local ward = defender:getLocalVar(WARD_HP)
    if ward <= 0 then return amount end
    if defender:getZoneID() ~= defender:getLocalVar(ZONE) or remaining(defender, WARD_END, 5000) == 0 then
        defender:setLocalVar(WARD_HP, 0)
        return amount
    end
    local absorbed = math.min(ward, amount)
    defender:setLocalVar(WARD_HP, ward - absorbed)
    return amount - absorbed
end

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    if player:getPet() then player:despawnPet() end
    if player:getMainLvl() < 30 then player:setLocalVar(WARD_HP, 0) end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    clear(player)
    player:sendSoulSpellList()
end

actions.register('skyborn',
{
    ability =
    {
        [66] = { name = 'Grounding Cry', description = cryHelp, recastTime = 16 },
        [65] = { name = 'Skyward Guard', description = guardHelp, recastTime = 20 },
    },
})

spec.registerCrystal(xi.job.DRG,
{
    id = 2, key = 'skyborn', name = 'Skyborn', abr = 'SKY', role = 'Tank', icon = 'skyborn', reqLevel = 10,
    description = 'A polearm tank who opens with an enmity challenge and times a short guard without leaving melee.',
    highlights =
    {
        'Grounding Cry challenges one enemy from up to 15 yalms for 200 CE and 700 VE (16-second recast).',
        'Skyward Guard protects against one direct enemy hit during its 1.5-second window. Mitigation scales to 35/40/45/50%.',
        'Guard landing adds 100 CE and 300 VE to the original living target. A successful intercept grants a 5/8/10% max-HP ward from Lv.30.',
        'Guard and ward leave targetability and current hate intact. Scripted HP changes bypass both.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 66, 65 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.POLEARM, scale(level, 10, 20, 30, 42) },
            { xi.mod.HPP, scale(level, 10, 14, 18, 22) },
            { xi.mod.ENMITY, scale(level, 20, 30, 40, 50) },
            { xi.mod.DMG, -scale(level, 500, 700, 1000, 1200) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isSkyborn(player) then
            if event == 'onGameIn' then clear(player) end
            apply(player)
        end
    end)
end

m:addOverride('xi.player.onPlayerDeath', function(player, ...)
    if isSkyborn(player) then clear(player) end
    return super(player, ...)
end)

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('skyborn', function(player)
        local sameZone = player:getZoneID() == player:getLocalVar(ZONE)
        local guard = sameZone and player:getLocalVar(GUARD_ID) ~= 0 and remaining(player, GUARD_END, 1500) or 0
        local ward = sameZone and player:getLocalVar(WARD_HP) > 0 and remaining(player, WARD_END, 5000) or 0
        return
        {
            guard_ms = guard,
            ward_ms = ward,
            ward_hp = ward > 0 and player:getLocalVar(WARD_HP) or 0,
            cry_cd = math.max(0, player:getLocalVar(CRY_CD) - second()),
            guard_cd = math.max(0, player:getLocalVar(GUARD_CD) - second()),
        }
    end)
end

return m
