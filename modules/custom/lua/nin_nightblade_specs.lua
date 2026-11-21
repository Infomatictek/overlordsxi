-- Nightblade (NIN) - read an enemy tell and answer that exact action.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/spells/damage_spell')
require('scripts/combat/basic/magic_hit_rate')

local m = Module:new('soulspire_nin_nightblade')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.NIN] then require('modules/custom/lua/nin_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local SPELL, TECHNIQUE = 1, 2
local ACTIVE, SEAL_CD, QUICK_END, QUICK_CD = 'OX_NGB_ACTIVE', 'OX_NGB_SEAL_CD', 'OX_NGB_QUICK_END', 'OX_NGB_QUICK_CD'
local TELL, SEQUENCE, EXPECTED = 'OX_NGB_TELL', 'OX_NGB_SEQUENCE', 'OX_NGB_EXPECTED_SEQ'
local SEALED, SEALED_END, OWNER = 'OX_NGB_SEALED_SEQ', 'OX_NGB_SEALED_END', 'OX_NGB_OWNER'
local SEAL_TARGET, SEAL_SEQUENCE = 'OX_NGB_SEAL_TARGET', 'OX_NGB_SEAL_SEQUENCE'
local SEVERING, BLUNTING = 341, 344
local quickHelp = 'Prepare for 8 seconds. Your next valid seal cast takes 0.25 seconds. 45s recast.'
local NIGHTBLADE_KIT_SPELLS =
{
    [SEVERING] =
    {
        script = 'jubaku_ichi', name = 'Severing Seal', unlockLvl = 10, castMs = 500, recastSec = 20, mpCost = 0,
        description = 'Seal a hostile spell within 15 yalms. An interruptible spell can be stopped. If it completes, its direct damage is reduced. Shared cooldown: 20 seconds, 18 from Lv.50.',
    },
    [BLUNTING] =
    {
        script = 'hojo_ichi', name = 'Blunting Seal', unlockLvl = 10, castMs = 500, recastSec = 20, mpCost = 0,
        description = 'Seal a readied enemy technique within 15 yalms. Physical damage from that move is reduced. Shared cooldown: 20 seconds, 18 from Lv.50.',
    },
    [320] =
    {
        script = 'katon_ichi', name = 'Signal Flare', unlockLvl = 10, castMs = 1000, recastSec = 10, mpCost = 0,
        description = 'Strike one enemy with fire. Uses no ninja tools. 10s recast.',
    },
}
xi.soulspire.ninNightbladeSpecs = { NIGHTBLADE_KIT_SPELLS = NIGHTBLADE_KIT_SPELLS }

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function isNightblade(player)
    return player and player:isPC() and player:getMainJob() == xi.job.NIN and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.NIN, 'nightblade')
end

local function isEnemy(target)
    return target and target:isMob() and target:isAlive()
end

local function notify(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3)
end

local function setRecast(player, seconds, finishingSpell)
    player:setLocalVar(SEAL_CD, now() + seconds)
    for _, id in ipairs({ SEVERING, BLUNTING }) do
        if finishingSpell == id then
            player:setLocalVar('OX_NGB_CAST_RECAST', seconds)
        else
            player:addRecast(xi.recast.MAGIC, id, seconds)
        end
    end
end

local function hasSeal(target, sequence)
    return sequence > 0 and target:getLocalVar(SEALED) == sequence and target:getLocalVar(SEALED_END) > now()
end

local function sealOwner(target, sequence)
    if not hasSeal(target, sequence) then return nil end
    local owner = GetPlayerByID(target:getLocalVar(OWNER))
    if isNightblade(owner) and owner:getZoneID() == target:getZoneID() and owner:getLocalVar(SEAL_TARGET) == target:getID() and
        owner:getLocalVar(SEAL_SEQUENCE) == sequence
    then
        return owner
    end
    target:setLocalVar(SEALED_END, 0)
    target:setLocalVar('OX_NGB_INTERRUPT_SEQ', 0)
    return nil
end

local function finishSeal(player, target, spell, kind)
    local seq = isEnemy(target) and target:getLocalVar(SEQUENCE) or 0
    if seq == 0 or target:getLocalVar(TELL) ~= kind or player:getLocalVar(EXPECTED) ~= seq then
        setRecast(player, 3, spell:getID())
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
        return 0
    end
    if target:getLocalVar(SEALED) == seq then
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
        return 0
    end

    local level = player:getMainLvl()
    setRecast(player, level >= 50 and 18 or 20, spell:getID())
    player:setLocalVar('OX_NGB_QUICK_SPENT_END', player:getLocalVar(QUICK_END))
    player:setLocalVar(QUICK_END, 0)
    player:setLocalVar(SEAL_TARGET, target:getID())
    player:setLocalVar(SEAL_SEQUENCE, seq)
    target:setLocalVar(OWNER, player:getID())
    target:setLocalVar(SEALED, seq)
    target:setLocalVar(SEALED_END, now() + 8)
    target:setLocalVar('OX_NGB_REDUCTION', kind == SPELL and scale(level, 8, 10, 10, 12) or scale(level, 10, 13, 13, 16))
    if kind == SPELL and target:getLocalVar('OX_NGB_INTERRUPTIBLE') == 1 then
        local params =
        {
            magicalElement = spell:getElement(), actorStat = xi.mod.INT,
            skillType = xi.skill.NINJUTSU, spellGroup = xi.magic.spellGroup.NINJUTSU,
        }
        if xi.combat.magicHitRate.calculateResistRate(player, target, params) >= 1 then
            target:setLocalVar('OX_NGB_INTERRUPT_SEQ', seq)
        end
    end

    spell:setMsg(xi.msg.basic.NONE)
    notify(player, kind == SPELL and 'Severing Seal set on the current spell.' or 'Blunting Seal set on the current technique.')
    return 0
end

for _, row in ipairs({ { SEVERING, SPELL }, { BLUNTING, TECHNIQUE } }) do
    local id, kind = row[1], row[2]
    local path = 'xi.actions.spells.ninjutsu.' .. NIGHTBLADE_KIT_SPELLS[id].script
    m:addOverride(path .. '.onMagicCastingCheck', function(player, target, spell)
        if not isNightblade(player) then return super(player, target, spell) end
        if not isEnemy(target) or player:checkDistance(target) > 15 or player:getLocalVar(SEAL_CD) > now() then
            return xi.msg.basic.MAGIC_UNABLE_TO_CAST
        end
        local seq = target:getLocalVar(SEQUENCE)
        if seq == 0 or target:getLocalVar(TELL) ~= kind then
            setRecast(player, 3)
            return xi.msg.basic.MAGIC_UNABLE_TO_CAST
        end
        if target:getLocalVar(SEALED) == seq then return xi.msg.basic.MAGIC_UNABLE_TO_CAST end
        player:setLocalVar(EXPECTED, seq)
        return 0
    end)
    m:addOverride(path .. '.onSpellCast', function(player, target, spell, action)
        if not isNightblade(player) then return super(player, target, spell, action) end
        return finishSeal(player, target, spell, kind)
    end)
end

m:addOverride('xi.actions.spells.ninjutsu.katon_ichi.onSpellCast', function(player, target, spell, action)
    if not isNightblade(player) then return super(player, target, spell, action) end
    return xi.spells.damage.useDamageSpell(player, target, spell)
end)

local priorDamage = xi.soulspire.onPreTakeDamage
xi.soulspire.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if priorDamage then amount = priorDamage(defender, amount, attacker, attackType, damageType) end
    if type(amount) ~= 'number' or amount <= 0 or not isEnemy(attacker) then return amount end
    local tell = attacker:getLocalVar(TELL)
    local category = attacker:getLocalVar('OX_SCR_ACTION')
    local spell = tell == SPELL and category == 2 and attackType == xi.attackType.MAGICAL
    local physical = tell == TECHNIQUE and category == 1 and (attackType == xi.attackType.PHYSICAL or attackType == xi.attackType.RANGED)
    if not spell and not physical then return amount end
    local seq = attacker:getLocalVar(SEQUENCE)
    if not sealOwner(attacker, seq) then return amount end
    if physical then attacker:setLocalVar('OX_NGB_PHYSICAL_SEQ', seq) end
    return amount - math.floor(amount * attacker:getLocalVar('OX_NGB_REDUCTION') / 100)
end

xi.soulspire.nightblade =
{
    onNonPhysicalTelegraph = function(target, sequence)
        local owner = sealOwner(target, sequence)
        if owner then
            setRecast(owner, 3)
            local quickEnd = owner:getLocalVar('OX_NGB_QUICK_SPENT_END')
            if quickEnd > now() and owner:getLocalVar(QUICK_END) <= now() then
                owner:setLocalVar(QUICK_END, quickEnd)
            end
            notify(owner, 'That technique was not physical. Blunting Seal can be retried in three seconds.')
        end
    end,
}

m:addOverride('xi.actions.abilities.innin.onAbilityCheck', function(player, target, ability)
    if not isNightblade(player) then return super(player, target, ability) end
    if player:getMainLvl() < 30 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(45)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.innin.onUseAbility', function(player, target, ability, action)
    if not isNightblade(player) then return super(player, target, ability, action) end
    player:setLocalVar(QUICK_END, now() + 8)
    player:setLocalVar(QUICK_CD, now() + 45)
    if action then action:messageID(player:getID(), xi.msg.basic.NONE) end
    notify(player, 'Quick Read is ready.')
    return 0
end)

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    if player:getMainLvl() < 30 then player:setLocalVar(QUICK_END, 0) end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    player:setLocalVar(QUICK_END, 0)
    player:setLocalVar(SEAL_SEQUENCE, 0)
    player:setLocalVar(SEAL_TARGET, 0)
    player:sendSoulSpellList()
end

actions.register('nightblade',
{
    spell = NIGHTBLADE_KIT_SPELLS,
    ability = { [249] = { name = 'Quick Read', description = quickHelp, recastTime = 45 } },
})

spec.registerCrystal(xi.job.NIN,
{
    id = 3, key = 'nightblade', name = 'Nightblade', abr = 'NGB', role = 'Support', icon = 'nightblade', reqLevel = 10,
    description = 'React to enemy telegraphs with a seal that disrupts one hostile spell or weakens one physical move.',
    highlights =
    {
        'Severing Seal can interrupt enemy spells with a full landing. If the spell completes, its direct damage is reduced by 8/10/10/12%.',
        'Blunting Seal reduces physical damage from one enemy technique by 10/13/13/16%.',
        'Both seals work from Lv.10, share a 20-second recast (18 at Lv.50+), and retry in 3 seconds on a mismatch.',
        'Quick Read unlocks at Lv.30 and shortens the next seal cast during its eight-second window.',
    },
    extraAbilities = function(_, level) return level >= 30 and { 249 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.NINJUTSU, scale(level, 12, 20, 30, 42) },
            { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isNightblade(player) then apply(player) end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('nightblade', function(player)
        local target = player:getTarget()
        local enemy = isEnemy(target)
        local tell = enemy and target:getLocalVar(TELL) or 0
        local sealed = tell > 0 and hasSeal(target, target:getLocalVar(SEQUENCE))
        return
        {
            tell = tell,
            sealed = sealed and 1 or 0,
            seal_cd = math.max(0, player:getLocalVar(SEAL_CD) - now()),
            quick_rem = math.max(0, player:getLocalVar(QUICK_END) - now()),
            quick_cd = math.max(0, player:getLocalVar(QUICK_CD) - now()),
        }
    end)
end

return m
