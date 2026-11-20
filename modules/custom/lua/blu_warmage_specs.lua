-- Warmage (BLU) - examine enemy defenses and answer with the right monster spell.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/bluemagic')
require('scripts/combat/basic/damage_multipliers')

local m = Module:new('soulspire_blu_warmage')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.BLU] then require('modules/custom/lua/blu_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local TARGET, MASK, WINDOW, ASSESS_CD = 'OX_WMG_TARGET', 'OX_WMG_MASK', 'OX_WMG_WINDOW', 'OX_WMG_ASSESS_CD'
local BLUNT, SLASH, PIERCE, ELEMENT = 1, 2, 3, 4
local categoryNames = { 'Blunt', 'Slashing', 'Piercing', 'Elemental' }
local assessHelp = 'Assess your engaged enemy. For eight seconds, matching Blue Magic gains damage against its least-resistant available categories. 12s recast.'
local WARMAGE_KIT_SPELLS =
{
    [597] = { script = 'sprout_smack', name = 'Briar Hammer', unlockLvl = 10, castMs = 500, recastSec = 7, mpCost = 6,
        category = BLUNT, hits = 1, cap = 13, power = 1.50, description = 'Crush one enemy with a blunt Blue Magic strike. Costs 6 MP. 7s recast.' },
    [551] = { script = 'power_attack', name = 'Needle Lunge', unlockLvl = 10, castMs = 500, recastSec = 7, mpCost = 5,
        category = PIERCE, hits = 1, cap = 13, power = 1.45, description = 'Pierce one enemy with a quick Blue Magic thrust. Costs 5 MP. 7s recast.' },
    [577] = { script = 'foot_kick', name = 'Razor Heel', unlockLvl = 10, castMs = 500, recastSec = 7, mpCost = 5,
        category = SLASH, hits = 1, cap = 13, power = 1.45, description = 'Slash one enemy with a cutting kick. Costs 5 MP. 7s recast.' },
    [529] = { script = 'bludgeon', name = 'Skullbreaker Volley', unlockLvl = 30, castMs = 500, recastSec = 12, mpCost = 16,
        category = BLUNT, hits = 3, cap = 25, power = 1.25, description = 'Strike one enemy three times with blunt force. Costs 16 MP. 12s recast.' },
    [527] = { script = 'smite_of_rage', name = 'Iron Cleave', unlockLvl = 30, castMs = 500, recastSec = 13, mpCost = 24,
        category = SLASH, hits = 1, cap = 36, power = 2.15, description = 'Cut one enemy with a heavy slashing strike. Costs 24 MP. 13s recast.' },
    [569] = { script = 'jet_stream', name = 'Gale Knuckle', unlockLvl = 50, castMs = 500, recastSec = 16, mpCost = 28,
        category = BLUNT, hits = 3, cap = 42, power = 1.40, description = 'Land three blunt strikes on one enemy from up to eight yalms. Costs 28 MP. 16s recast.' },
    [543] = { script = 'mandibular_bite', name = 'Serrated Bite', unlockLvl = 50, castMs = 500, recastSec = 17, mpCost = 25,
        category = SLASH, hits = 1, cap = 50, power = 2.35, description = 'Deliver a deep slashing bite to one enemy. Costs 25 MP. 17s recast.' },
    [626] = { script = 'bomb_toss', name = 'Ember Charge', unlockLvl = 50, castMs = 1500, recastSec = 16, mpCost = 26,
        category = ELEMENT, cap = 70, power = 2.05, description = 'Hurl a concentrated fire charge at one enemy. Costs 26 MP. 16s recast.' },
    [554] = { script = 'death_scissors', name = 'Guillotine Shears', unlockLvl = 70, castMs = 500, recastSec = 20, mpCost = 32,
        category = SLASH, hits = 1, cap = 74, power = 2.60, description = 'Shear one enemy with a heavy slashing finisher. Costs 32 MP. 20s recast.' },
    [591] = { script = 'heat_breath', name = 'Furnace Breath', unlockLvl = 70, castMs = 1800, recastSec = 20, mpCost = 36,
        category = ELEMENT, cap = 95, power = 2.45, description = 'Focus fire on one enemy within ten yalms. Costs 36 MP. 20s recast.' },
    [644] = { script = 'mind_blast', name = 'Storm Gaze', unlockLvl = 70, castMs = 1400, recastSec = 18, mpCost = 30,
        category = ELEMENT, cap = 90, power = 2.30, description = 'Strike one enemy with lightning. Costs 30 MP. 18s recast.' },
}
xi.soulspire.bluWarmageSpecs = { WARMAGE_KIT_SPELLS = WARMAGE_KIT_SPELLS }

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function isWarmage(player)
    return player and player:isPC() and player:getMainJob() == xi.job.BLU and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.BLU, 'warmage')
end

local function isEnemy(target)
    return target and target:isMob() and target:isAlive()
end

local function categoryBit(category)
    return 2 ^ (category - 1)
end

local function hasCategory(mask, category)
    return math.floor(mask / categoryBit(category)) % 2 == 1
end

local function activeMask(player, target)
    if not isEnemy(target) or player:getLocalVar(TARGET) ~= target:getID() or player:getLocalVar(WINDOW) <= now() then return 0 end
    return player:getLocalVar(MASK)
end

local function elementalFactor(target, element)
    local rank = target:getMod(xi.data.element.getElementalResistanceRankModifier(element))
    return xi.combat.damage.magicalElementSDT(target, element) * math.max(0.05, 1 - rank * 0.07)
end

local function assess(player, target)
    local damage = xi.combat.damage
    local physical = damage.calculateDamageAdjustment(target, true, false, false, false)
    local scores =
    {
        physical * damage.physicalElementSDT(target, xi.damageType.BLUNT),
        physical * damage.physicalElementSDT(target, xi.damageType.SLASHING),
        physical * damage.physicalElementSDT(target, xi.damageType.PIERCING),
    }
    local level = player:getMainLvl()
    if level >= 50 then
        local element = elementalFactor(target, xi.element.FIRE)
        if level >= 70 then element = math.max(element, elementalFactor(target, xi.element.THUNDER)) end
        scores[ELEMENT] = element * damage.calculateDamageAdjustment(target, false, true, false, false)
    end

    local highest = math.max(table.unpack(scores))
    local mask, names = 0, {}
    for category, score in ipairs(scores) do
        if math.abs(score - highest) < 0.0001 then
            mask = mask + categoryBit(category)
            names[#names + 1] = categoryNames[category]
        end
    end
    player:setLocalVar(TARGET, target:getID())
    player:setLocalVar(MASK, mask)
    player:setLocalVar(WINDOW, now() + 8)
    return table.concat(names, ', ')
end

xi.soulspire.warmage =
{
    damage = function(caster, target, spell, amount)
        if amount <= 0 or not isWarmage(caster) then return amount end
        local definition = WARMAGE_KIT_SPELLS[spell:getID()]
        if not definition or caster:getMainLvl() < definition.unlockLvl or
            not hasCategory(activeMask(caster, target), definition.category)
        then
            return amount
        end
        return math.floor(amount * (100 + scale(caster:getMainLvl(), 12, 15, 18, 20)) / 100)
    end,
}

m:addOverride('xi.actions.abilities.chain_affinity.onAbilityCheck', function(player, target, ability)
    if not isWarmage(player) then return super(player, target, ability) end
    local enemy = player:getTarget()
    if not isEnemy(enemy) or player:checkDistance(enemy) > 15 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(12)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.chain_affinity.onUseAbility', function(player, target, ability, action)
    if not isWarmage(player) then return super(player, target, ability, action) end
    local enemy = player:getTarget()
    if not isEnemy(enemy) then return 0 end
    player:setLocalVar(ASSESS_CD, now() + 12)
    if action then action:messageID(player:getID(), xi.msg.basic.NONE) end
    player:printToPlayer('Assess Prey: ' .. assess(player, enemy), xi.msg.channel.SYSTEM_3)
    return 0
end)

for _, entry in pairs(WARMAGE_KIT_SPELLS) do
    local spellDefinition = entry
    m:addOverride('xi.actions.spells.blue.' .. spellDefinition.script .. '.onSpellCast', function(caster, target, spell, action)
        if not isWarmage(caster) then return super(caster, target, spell, action) end

        local blue = xi.spells.blue
        local params = blue.getDefaultParams(caster)
        params.baseDamageCap = spellDefinition.cap
        params.ftp0 = spellDefinition.power
        params.ftp1500 = spellDefinition.power
        params.ftp3000 = spellDefinition.power
        params.ftpAzure = spellDefinition.power
        params.hasChainAffinity = false
        params.hasBurstAffinity = false
        params.hasAzureLore = false
        params.hasEfflux = false
        params.hasConvergence = false
        if spellDefinition.category == ELEMENT then
            params.attackType = xi.attackType.MAGICAL
            params.damageType = xi.damageType.ELEMENTAL + spell:getElement()
            params.int_wsc = 0.30
            return blue.useMagicalSpell(caster, target, spell, params, action)
        end

        local physicalTypes = { xi.damageType.BLUNT, xi.damageType.SLASHING, xi.damageType.PIERCING }
        params.attackType = xi.attackType.PHYSICAL
        params.damageType = physicalTypes[spellDefinition.category]
        params.numHits = spellDefinition.hits
        params.str_wsc = 0.25
        return blue.usePhysicalSpell(caster, target, spell, params, action)
    end)
end

local function clear(player)
    player:setLocalVar(TARGET, 0)
    player:setLocalVar(MASK, 0)
    player:setLocalVar(WINDOW, 0)
end

local function apply(player)
    player:setWarmageKit(true)
    for _, effect in ipairs({ xi.effect.CHAIN_AFFINITY, xi.effect.BURST_AFFINITY, xi.effect.AZURE_LORE, xi.effect.EFFLUX, xi.effect.CONVERGENCE }) do
        if player:hasStatusEffect(effect) then player:delStatusEffect(effect) end
    end
    player:sendSoulSpellList()
end

local function remove(player)
    clear(player)
    player:setWarmageKit(false)
    player:sendSoulSpellList()
end

actions.register('warmage',
{
    spell = WARMAGE_KIT_SPELLS,
    ability = { [94] = { name = 'Assess Prey', description = assessHelp, recastTime = 12 } },
})

spec.registerCrystal(xi.job.BLU,
{
    id = 1, key = 'warmage', name = 'Warmage', abr = 'WMG', role = 'Damage', icon = 'warmage', reqLevel = 10,
    description = 'Read one enemy and select the monster technique that best answers its defenses.',
    highlights =
    {
        'Assess Prey identifies all tied least-resistant categories available at your level for eight seconds.',
        'Matching direct Blue spells gain 12/15/18/20% damage after resistance at Lv.10/30/50/70+.',
        'Three physical categories unlock at Lv.10. The elemental category unlocks at Lv.50.',
        'Soul magic is single-target and automatically available. The saved Blue Magic set is restored on leaving Warmage.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 94 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.ACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.MATT, scale(level, 8, 14, 22, 30) },
            { xi.mod.INT, scale(level, 6, 12, 18, 24) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isWarmage(player) then
            if event == 'onGameIn' then clear(player) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('warmage', function(player)
        local mask = activeMask(player, player:getTarget())
        return
        {
            match = mask,
            window = mask > 0 and math.max(0, player:getLocalVar(WINDOW) - now()) or 0,
            assess_cd = math.max(0, player:getLocalVar(ASSESS_CD) - now()),
        }
    end)
end

return m
