-----------------------------------
-- OverlordsXI Blue Mage Crystal Spec (Azure Bastion)
-- Registers the Blue Mage (job 16) Soul Crystal specialization:
--   1. Azure Bastion (BLU): Monster-Core Assimilator & Dual-Wield Tank
--
-- Unlocks @ Lv. 10 (!spec set azurebastion)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/job_utils/blue_mage')
require('scripts/globals/bluemagic')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_blu_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.bluSpecs = xi.overlords.bluSpecs or {}

local AZURE_BASTION_KEY = 'azurebastion'

-- Dual Wield Trait ID (18) & Custom Trait ID (162; Azure Carapace)
local TRAIT_DUAL_WIELD     = (xi.trait and xi.trait.DUAL_WIELD) or 18
local TRAIT_AZURE_CARAPACE = 162

-- Custom Ability IDs (445-446; recastIds 220-221)
local ABIL_BEHEMOTH_ROAR = 445
local ABIL_DIAMOND_SHELL = 446

-- Custom Status Effect IDs (857-859; registered in patch 0026)
local EFFECT_CHITIN_CARAPACE = 857
local EFFECT_AZURE_SURGE     = 858
local EFFECT_DIAMOND_SHELL   = 859

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.BEHEMOTH_ROAR = ABIL_BEHEMOTH_ROAR
xi.jobAbility.DIAMOND_SHELL = ABIL_DIAMOND_SHELL

xi.effect = xi.effect or {}
xi.effect.CHITIN_CARAPACE = EFFECT_CHITIN_CARAPACE
xi.effect.AZURE_SURGE     = EFFECT_AZURE_SURGE
xi.effect.DIAMOND_SHELL   = EFFECT_DIAMOND_SHELL

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.behemoth_roar = xi.actions.abilities.behemoth_roar or {}
xi.actions.abilities.diamond_shell = xi.actions.abilities.diamond_shell or {}

xi.effects = xi.effects or {}
xi.effects.chitin_carapace = xi.effects.chitin_carapace or {}
xi.effects.azure_surge     = xi.effects.azure_surge or {}
xi.effects.diamond_shell   = xi.effects.diamond_shell or {}

-----------------------------------
-- Scaling & Spec Helpers
-----------------------------------
local function scaleTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 then
        return lv70 or lv50, 4
    elseif l >= 50 then
        return lv50, 3
    elseif l >= 30 then
        return lv30, 2
    end
    return lv10, 1
end

local function isAzureBastion(entity)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.BLU or
        entity:getMainLvl() < 10
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.BLU, AZURE_BASTION_KEY)
end

local function isSwordOrClubWs(ws)
    if ws == nil then
        return false
    end
    local wsId = (type(ws) == 'number') and ws or (ws.getID and ws:getID() or 0)
    -- Sword WSs (32..47: Fast Blade, Vorpal Blade, Savage Blade, Expiacion, etc.)
    -- Club WSs (160..175: Skullbreaker, Black Halo, etc.)
    if (wsId >= 32 and wsId <= 47) or (wsId >= 160 and wsId <= 175) then
        return true
    end
    if type(ws) == 'table' or type(ws) == 'userdata' then
        if ws.getSkillType then
            local st = ws:getSkillType()
            if st == xi.skill.SWORD or st == xi.skill.CLUB then
                return true
            end
        end
    end
    return false
end

local function getChitinCarapaceStacks(player)
    if player == nil or not player.getStatusEffect then
        return 0
    end
    local eff = player:getStatusEffect(EFFECT_CHITIN_CARAPACE)
    if eff == nil then
        return 0
    end
    return math.max(0, math.min(5, eff:getPower() or 0))
end

local function grantChitinCarapaceStacks(player, delta, duration)
    if player == nil or not player.addStatusEffect then
        return 0
    end
    local cur = getChitinCarapaceStacks(player)
    local nextStacks = math.max(1, math.min(5, cur + (delta or 1)))
    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_CHITIN_CARAPACE)
    end
    player:addStatusEffect(EFFECT_CHITIN_CARAPACE, {
        power    = nextStacks,
        duration = duration or 15,
        origin   = player,
    })
    return nextStacks
end

local function applyStoneskinBarrier(target, power, duration, tier)
    if target == nil or not target.addStatusEffect or power <= 0 then
        return
    end
    local existing = target.getStatusEffect and target:getStatusEffect(xi.effect.STONESKIN) or nil
    if existing ~= nil and (existing:getPower() or 0) >= power then
        return
    end
    if target.delStatusEffectSilent then
        target:delStatusEffectSilent(xi.effect.STONESKIN)
    end
    target:addStatusEffect(xi.effect.STONESKIN, {
        power    = power,
        duration = duration or 60,
        origin   = target,
        tier     = tier or 3,
    })
end

local function addAoeVolatileEnmity(player, radius, veAmount, ceAmount)
    if player == nil or not player.getZone then
        return
    end
    local zone = player:getZone()
    if zone == nil or not zone.getMobs then
        return
    end
    local mobs = zone:getMobs()
    if mobs == nil then
        return
    end
    for _, mob in pairs(mobs) do
        if
            mob ~= nil and
            mob.isAlive and mob:isAlive() and
            mob.getCurrentAction and mob:getCurrentAction() ~= xi.act.NONE and
            mob.checkDistance and mob:checkDistance(player) <= radius and
            mob.addEnmity
        then
            mob:addEnmity(player, ceAmount or 150, veAmount or 900)
        end
    end
end

-----------------------------------
-- Physical & Defensive Blue Magic Sets
-----------------------------------
local PHYSICAL_BLUE_SPELLS =
{
    head_butt     = true,
    sudden_lunge  = true,
    bludgeon      = true,
    smite_of_rage = true,
    heavy_strike  = true,
    goblin_rush   = true,
}

local PHYSICAL_BLUE_SPELL_IDS =
{
    [(xi.magic and xi.magic.spell and xi.magic.spell.HEAD_BUTT)     or 623] = true,
    [(xi.magic and xi.magic.spell and xi.magic.spell.SUDDEN_LUNGE)  or 692] = true,
    [(xi.magic and xi.magic.spell and xi.magic.spell.BLUDGEON)      or 529] = true,
    [(xi.magic and xi.magic.spell and xi.magic.spell.SMITE_OF_RAGE) or 527] = true,
    [(xi.magic and xi.magic.spell and xi.magic.spell.HEAVY_STRIKE)  or 688] = true,
    [(xi.magic and xi.magic.spell and xi.magic.spell.GOBLIN_RUSH)   or 666] = true,
}

-----------------------------------
-- Custom Status Effect Handlers
-----------------------------------
m:addOverride('xi.effects.chitin_carapace.onEffectGain', function(_target, effect)
    local stacks = math.max(1, math.min(5, effect:getPower() or 1))
    effect:addMod(xi.mod.DEFP, 4 * stacks)
    effect:addMod(xi.mod.DMG, -300 * stacks)
end)

m:addOverride('xi.effects.chitin_carapace.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.azure_surge.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.UFASTCAST, 100)
end)

m:addOverride('xi.effects.azure_surge.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.diamond_shell.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.DMG, -2000)
    effect:addMod(xi.mod.KNOCKBACK_REDUCTION, 8)
end)

m:addOverride('xi.effects.diamond_shell.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Player Listeners (WS Assimilation, MP Cost / Instant Cast, Enmity Reflection)
-----------------------------------
local function attachBluListeners(player)
    if player == nil or not player.addListener then
        return
    end

    if player.removeListener then
        player:removeListener('OX_BLU_WS_USE')
        player:removeListener('OX_BLU_MAGIC_START')
        player:removeListener('OX_BLU_MAGIC_USE')
        player:removeListener('OX_BLU_MAGIC_INT')
        player:removeListener('OX_BLU_TAKE_DMG')
    end

    player:addListener('WEAPONSKILL_USE', 'OX_BLU_WS_USE', function(actor, _target, ws, _tp, _action, _damage)
        if not isAzureBastion(actor) or not isSwordOrClubWs(ws) then
            return
        end

        if actor.delStatusEffectSilent then
            actor:delStatusEffectSilent(EFFECT_AZURE_SURGE)
        end
        actor:addStatusEffect(EFFECT_AZURE_SURGE, {
            power    = 1,
            duration = 6,
            origin   = actor,
        })
    end)

    player:addListener('MAGIC_START', 'OX_BLU_MAGIC_START', function(caster, _target, spell, _action)
        if not isAzureBastion(caster) or spell == nil then
            return
        end
        if spell.getSkillType and spell:getSkillType() ~= xi.skill.BLUE_MAGIC then
            return
        end

        if caster:hasStatusEffect(EFFECT_AZURE_SURGE) then
            if caster.setLocalVar then
                caster:setLocalVar('OX_BLU_SURGE_PENDING', 1)
            end
            if spell.setMPCost then
                spell:setMPCost(0)
            end
            if spell.setCastTime then
                spell:setCastTime(0)
            end
            return
        end

        if caster.setLocalVar then
            caster:setLocalVar('OX_BLU_SURGE_PENDING', 0)
        end

        local spellId = spell.getID and spell:getID() or 0
        local baseMp  = spell.getMPCost and spell:getMPCost() or 0
        local factor  = 1.0

        if PHYSICAL_BLUE_SPELL_IDS[spellId] then
            factor = factor * 0.70
        end
        if caster:hasStatusEffect(xi.effect.AZURE_LORE) then
            factor = factor * 0.50
        end

        if factor < 1.0 and baseMp > 0 and spell.setMPCost then
            spell:setMPCost(math.max(1, math.floor(baseMp * factor + 0.5)))
        end
    end)

    player:addListener('MAGIC_USE', 'OX_BLU_MAGIC_USE', function(caster, target, spell, _action)
        if not isAzureBastion(caster) or spell == nil then
            return
        end
        if spell.getSkillType and spell:getSkillType() ~= xi.skill.BLUE_MAGIC then
            return
        end

        local surgePending = caster.getLocalVar and caster:getLocalVar('OX_BLU_SURGE_PENDING') == 1
        if surgePending or caster:hasStatusEffect(EFFECT_AZURE_SURGE) then
            if caster.setLocalVar then
                caster:setLocalVar('OX_BLU_SURGE_PENDING', 0)
            end
            caster:delStatusEffectSilent(EFFECT_AZURE_SURGE)

            -- AoE 8y volatile enmity pulse around caster
            addAoeVolatileEnmity(caster, 8.0, 900, 150)
            if target ~= nil and target:getID() ~= caster:getID() and target.addEnmity then
                target:addEnmity(caster, 150, 900)
            end
        end
    end)

    player:addListener('MAGIC_INTERRUPTED', 'OX_BLU_MAGIC_INT', function(caster, _target, _spell, _action)
        if caster ~= nil and caster.setLocalVar then
            caster:setLocalVar('OX_BLU_SURGE_PENDING', 0)
        end
    end)

    player:addListener('TAKE_DAMAGE', 'OX_BLU_TAKE_DMG', function(defender, amount, attacker)
        if not isAzureBastion(defender) then
            return
        end
        if defender:hasStatusEffect(EFFECT_DIAMOND_SHELL) and attacker ~= nil and amount ~= nil and amount > 0 then
            if attacker.addEnmity then
                attacker:addEnmity(defender, 0, math.max(1, math.floor(amount * 0.20)))
            end
        end
    end)
end

local function detachBluListeners(player)
    if player == nil or not player.removeListener then
        return
    end
    player:removeListener('OX_BLU_WS_USE')
    player:removeListener('OX_BLU_MAGIC_START')
    player:removeListener('OX_BLU_MAGIC_USE')
    player:removeListener('OX_BLU_MAGIC_INT')
    player:removeListener('OX_BLU_TAKE_DMG')
end

-----------------------------------
-- Blue Magic Engine Overrides (Physical, Defensive, Burst/Chain Affinity, Azure Lore)
-----------------------------------
for spellName, _ in pairs(PHYSICAL_BLUE_SPELLS) do
    m:addOverride('xi.actions.spells.blue.' .. spellName .. '.onSpellCast', function(caster, target, spell, action)
        local damage = super(caster, target, spell, action)
        if isAzureBastion(caster) then
            -- 3x volatile enmity (add 2x bonus on top of base 1x)
            if target ~= nil and target.addEnmity then
                local baseVe = (spell and spell.getVE and spell:getVE()) or 240
                local bonusVe = math.max(360, baseVe * 2 + math.floor(math.max(0, damage or 0) * 0.5))
                target:addEnmity(caster, 0, bonusVe)
            end
            grantChitinCarapaceStacks(caster, 1, 15)
        end
        return damage
    end)
end

local function tryRestoreDefensiveCarapaceMp(caster)
    if isAzureBastion(caster) and getChitinCarapaceStacks(caster) >= 3 then
        local maxMp = caster.getMaxMP and caster:getMaxMP() or 0
        if maxMp > 0 and caster.addMP then
            caster:addMP(math.max(1, math.floor(maxMp * 0.06)))
        end
    end
end

m:addOverride('xi.actions.spells.blue.cocoon.onSpellCast', function(caster, target, spell, action)
    if not isAzureBastion(caster) then
        return super(caster, target, spell, action)
    end

    local power    = math.floor(50 * 1.35 + 0.5)
    local duration = xi.spells.blue.calculateDurationWithDiffusion(caster, 90)
    if not target:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = power, duration = duration, origin = caster }) then
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
    end
    tryRestoreDefensiveCarapaceMp(caster)
    return xi.effect.DEFENSE_BOOST
end)

m:addOverride('xi.actions.spells.blue.metallic_body.onSpellCast', function(caster, target, spell, action)
    if not isAzureBastion(caster) then
        return super(caster, target, spell, action)
    end

    local blueSkill = utils.clamp(caster:getSkillLevel(xi.skill.BLUE_MAGIC), 0, 500)
    local power     = math.floor(utils.clamp(0.375 * blueSkill + 12.5, 0, 150) * 1.35 + 0.5)
    local duration  = xi.spells.blue.calculateDurationWithDiffusion(caster, 300)
    if not target:addStatusEffect(xi.effect.STONESKIN, { power = power, duration = duration, origin = caster, tier = 2 }) then
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
    end
    tryRestoreDefensiveCarapaceMp(caster)
    return xi.effect.STONESKIN
end)

m:addOverride('xi.actions.spells.blue.diamondhide.onSpellCast', function(caster, target, spell, action)
    if not isAzureBastion(caster) then
        return super(caster, target, spell, action)
    end

    local blueSkill = utils.clamp(caster:getSkillLevel(xi.skill.BLUE_MAGIC), 0, 500)
    local power     = math.floor(((blueSkill / 3) * 2) * 1.35 + 0.5)
    local duration  = xi.spells.blue.calculateDurationWithDiffusion(caster, 300)
    if not target:addStatusEffect(xi.effect.STONESKIN, { power = power, duration = duration, origin = caster, tier = 2 }) then
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
    end
    tryRestoreDefensiveCarapaceMp(caster)
    return xi.effect.STONESKIN
end)

m:addOverride('xi.actions.spells.blue.saline_coat.onSpellCast', function(caster, target, spell, action)
    if not isAzureBastion(caster) then
        return super(caster, target, spell, action)
    end

    local power    = math.floor(50 * 1.35 + 0.5)
    local duration = xi.spells.blue.calculateDurationWithDiffusion(caster, 180)
    if not target:addStatusEffect(xi.effect.MAGIC_DEF_BOOST, { power = power, duration = duration, origin = caster, tick = 4 }) then
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
    end
    tryRestoreDefensiveCarapaceMp(caster)
    return xi.effect.MAGIC_DEF_BOOST
end)

m:addOverride('xi.actions.spells.blue.reactor_cool.onSpellCast', function(caster, target, spell, action)
    if not isAzureBastion(caster) then
        return super(caster, target, spell, action)
    end

    local duration = xi.spells.blue.calculateDurationWithDiffusion(caster, 120)
    if
        target:hasStatusEffect(xi.effect.DEFENSE_BOOST) or
        target:hasStatusEffect(xi.effect.ICE_SPIKES)
    then
        target:delStatusEffectSilent(xi.effect.DEFENSE_BOOST)
        target:delStatusEffectSilent(xi.effect.ICE_SPIKES)
    end

    target:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = math.floor(12 * 1.35 + 0.5), duration = duration, origin = caster })
    target:addStatusEffect(xi.effect.ICE_SPIKES, { power = math.floor(5 * 1.35 + 0.5), duration = duration, origin = caster })
    spell:setMsg(xi.msg.basic.MAGIC_GAIN_EFFECT)
    tryRestoreDefensiveCarapaceMp(caster)
    return xi.effect.DEFENSE_BOOST
end)

m:addOverride('xi.actions.spells.blue.magic_fruit.onSpellCast', function(caster, target, spell, action)
    local healed = super(caster, target, spell, action)
    if isAzureBastion(caster) then
        if healed ~= nil and healed > 0 and target ~= nil and target.addHP then
            local bonus = math.max(1, math.floor(healed * 0.35))
            target:addHP(bonus)
            healed = healed + bonus
        end
        tryRestoreDefensiveCarapaceMp(caster)
    end
    return healed
end)

m:addOverride('xi.spells.blue.usePhysicalSpell', function(caster, target, spell, params, action)
    local hadChain = isAzureBastion(caster) and caster:hasStatusEffect(xi.effect.CHAIN_AFFINITY)
    local damage = super(caster, target, spell, params, action)
    if hadChain then
        if target ~= nil and target.addStatusEffect then
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 3, origin = caster })
        end
        local maxHp = caster.getMaxHP and caster:getMaxHP() or 0
        if maxHp > 0 then
            applyStoneskinBarrier(caster, math.max(1, math.floor(maxHp * 0.20)), 60, 3)
        end
    end
    return damage
end)

m:addOverride('xi.spells.blue.useMagicalSpell', function(caster, target, spell, params, action)
    local hadBurst = isAzureBastion(caster) and caster:hasStatusEffect(xi.effect.BURST_AFFINITY)
    local damage = super(caster, target, spell, params, action)
    if hadBurst and target ~= nil then
        if target.addEnmity then
            target:addEnmity(caster, 250, 1200)
        end
        if target.addStatusEffect then
            target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 15, duration = 15, origin = caster })
        end
    end
    return damage
end)

m:addOverride('xi.spells.blue.useBreathSpell', function(caster, target, spell, params, action)
    local hadBurst = isAzureBastion(caster) and caster:hasStatusEffect(xi.effect.BURST_AFFINITY)
    local damage = super(caster, target, spell, params, action)
    if hadBurst and target ~= nil then
        if target.addEnmity then
            target:addEnmity(caster, 250, 1200)
        end
        if target.addStatusEffect then
            target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 15, duration = 15, origin = caster })
        end
    end
    return damage
end)

m:addOverride('xi.job_utils.blue_mage.useAzureLore', function(player, target, ability, action)
    local ret = super(player, target, ability, action)
    if isAzureBastion(player) then
        local eff = player:getStatusEffect(xi.effect.AZURE_LORE)
        if eff ~= nil then
            eff:addMod(xi.mod.DMG, -2500)
            eff:addMod(xi.mod.ENMITY, 50)
        end
    end
    return ret
end)

-----------------------------------
-- Custom Job Abilities (445: Behemoth Roar, 446: Diamond Shell)
-----------------------------------
m:addOverride('xi.actions.abilities.behemoth_roar.onAbilityCheck', function(player, target, ability)
    if not isAzureBastion(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if target == nil or target:getID() == player:getID() or not target:isAlive() then
        return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.behemoth_roar.onUseAbility', function(player, target, ability)
    if not isAzureBastion(player) or target == nil then
        return 0
    end

    target:addStatusEffect(xi.effect.STUN,           { power = 1,  duration = 4,  origin = player })
    target:addStatusEffect(xi.effect.ATTACK_DOWN,    { power = 20, duration = 12, origin = player })
    target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 20, duration = 12, origin = player })

    if target.addEnmity then
        target:addEnmity(player, 400, 1400)
    end
    addAoeVolatileEnmity(player, 8.0, 900, 200)

    grantChitinCarapaceStacks(player, 5, 15)

    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return xi.effect.STUN
end)

m:addOverride('xi.actions.abilities.diamond_shell.onAbilityCheck', function(player, _target, _ability)
    if not isAzureBastion(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.diamond_shell.onUseAbility', function(player, _target, ability)
    if not isAzureBastion(player) then
        return 0
    end

    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_DIAMOND_SHELL)
    end
    player:addStatusEffect(EFFECT_DIAMOND_SHELL, {
        power    = 1,
        duration = 10,
        origin   = player,
    })

    local maxHp = player.getMaxHP and player:getMaxHP() or 0
    if maxHp > 0 then
        applyStoneskinBarrier(player, math.max(1, math.floor(maxHp * 0.25)), 10, 4)
    end

    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_DIAMOND_SHELL
end)

-----------------------------------
-- Crystal Definition (BLU = 16)
-----------------------------------
if xi.job and xi.job.BLU then
    spec.registerJob(xi.job.BLU, 'BLU',
    {
        {
            id          = 1,
            key         = AZURE_BASTION_KEY,
            name        = 'Azure Bastion',
            role        = 'Monster-Core Assimilator & Dual-Wield Tank',
            icon        = 'azurebastion',
            reqLevel    = 10,
            extraTraits = { TRAIT_DUAL_WIELD, TRAIT_AZURE_CARAPACE },
            extraAbilities = function(_player, _lvl)
                return { ABIL_BEHEMOTH_ROAR, ABIL_DIAMOND_SHELL }
            end,
            description = 'Monster-forged frontliner (Lv10+): grants early Dual Wield at Lv.10+, 100% Spell Interruption Rate Down, Monster-Core Carapace mitigation, and physical Blue Magic threat & barrier weaving.',
            highlights =
            {
                'Passives (Lv10/30/50/70+): +14/18/22/26% Max HP, +8/14/20/26 VIT/STR/MND, +14/20/26/32% DEF, -8/11/14/18% DT, +25/35/45/60 Enmity & +25/35/45/60% Enmity Retention.',
                'Early Dual Wield & Mastery: Unlocks Dual Wield at Lv.10+ (-15/20/25/30% delay), +15/25/35/50 Sword/Club/Blue skill, +14/20/26/32% Parry, +20/30/40/50% Fast Cast, and 100% SIRD.',
                'Monster-Core Carapace: Physical Blue Magic (Head Butt, Sudden Lunge, Bludgeon, Smite of Rage, Heavy Strike, Goblin Rush) deals 3x VE, costs -30% MP, and grants Chitin Carapace (max 5: +4% DEF & -3% DT each for 15s); Defensive spells gain +35% potency & +6% Max MP at 3+ stacks.',
                'Azure Assimilation: Sword/Club WS grants Azure Surge (6s) making your next Blue Magic spell instant-cast, 0 MP, with an AoE 8y volatile enmity pulse.',
                'Tradeoff & JAs (-20% ATK/RATK, -15% WSD): Enhances Burst Affinity (heavy VE + -15% MATK Down), Chain Affinity (3s Stun + 20% Max HP barrier), and Azure Lore (-25% DT, +50 Enmity, -50% Blue Magic MP).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 14, 18, 22, 26) },
                    { xi.mod.VIT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.STR,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.MND,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 14, 20, 26, 32) },
                    { xi.mod.DMG,                   scaleTier(lvl, -800, -1100, -1400, -1800) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.DUAL_WIELD,            scaleTier(lvl, 15, 20, 25, 30) },
                    { xi.mod.SWORD,                 scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.CLUB,                  scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.BLUE,                  scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.PARRY,                 scaleTier(lvl, 14, 20, 26, 32) },
                    { xi.mod.FASTCAST,              scaleTier(lvl, 20, 30, 40, 50) },
                    { xi.mod.SPELLINTERRUPT,        100 },
                    { xi.mod.ATTP,                  -20 },
                    { xi.mod.RATTP,                 -20 },
                    { xi.mod.ALL_WSDMG_ALL_HITS,    -15 },
                }
            end,
            onApply = function(player)
                attachBluListeners(player)
            end,
            onRemove = function(player)
                if player ~= nil and player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_CHITIN_CARAPACE)
                    player:delStatusEffectSilent(EFFECT_AZURE_SURGE)
                    player:delStatusEffectSilent(EFFECT_DIAMOND_SHELL)
                end
                detachBluListeners(player)
            end,
        },
    })
end

return m
