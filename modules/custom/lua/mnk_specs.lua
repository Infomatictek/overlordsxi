-----------------------------------
-- OverlordsXI Monk Crystal Specs
-- Registers Monk crystals (Sensei) and implements their
-- passive scaling stats, Staff Evasion/Parry/Counter engine, and
-- ability transformations.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/monk')
-----------------------------------
local m = Module:new('overlords_mnk_specs')

local spec = xi.overlords.spec

local SENSEI_KEY = 'sensei'

local pendingMantraMods = {}

local function scaleTier(lvl, low, mid, high)
    local l = lvl or 1
    if l >= 50 then
        return high
    elseif l >= 30 then
        return mid
    end
    return low
end

local function isMonkSpec(entity, specKey)
    if entity == nil or not entity:isPC() or entity:getMainJob() ~= xi.job.MNK then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.MNK, specKey)
end

local function isStaffEquipped(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    if not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end

    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.STAFF
end

local function grantEnmity(mob, player, ce, ve)
    if mob == nil or player == nil or mob == player then
        return
    end

    if mob.addEnmity then
        mob:addEnmity(player, ce, ve)
    elseif mob.updateEnmityFromDamage then
        mob:updateEnmityFromDamage(player, math.floor((ce + ve) / 4))
    end
end

local function dealStaffRiposte(defender, attacker, isDodgeBonus)
    if
        defender == nil or
        attacker == nil or
        attacker == defender or
        (attacker.isAlive and not attacker:isAlive())
    then
        return 0
    end

    local weaponDmg = defender.getWeaponDmg and (defender:getWeaponDmg() or 0) or 0
    local strStat = defender.getStat and xi.mod and xi.mod.STR and (defender:getStat(xi.mod.STR) or 0) or 0
    local agiStat = defender.getStat and xi.mod and xi.mod.AGI and (defender:getStat(xi.mod.AGI) or 0) or 0
    local counterDmg = defender.getMod and xi.mod and xi.mod.COUNTER_DAMAGE and (defender:getMod(xi.mod.COUNTER_DAMAGE) or 0) or 0
    local lvl = defender.getMainLvl and (defender:getMainLvl() or 10) or 10

    local statContribution = isDodgeBonus and math.floor(agiStat * 0.4) or math.floor(strStat * 0.45)
    local raw = math.max(10, weaponDmg + statContribution + math.floor(lvl * 0.4) + counterDmg)
    local mult = (isDodgeBonus and defender.hasStatusEffect and xi.effect and xi.effect.DODGE and defender:hasStatusEffect(xi.effect.DODGE)) and 1.35 or 1.15
    local damage = math.max(10, math.floor(raw * mult))

    if attacker.takeDamage and xi.attackType and xi.damageType then
        attacker:takeDamage(damage, defender, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
    end

    return damage
end

local function detachSenseiListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_MNK_ATTACKED')
    end
end

local function attachSenseiListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachSenseiListeners(player)

    -- Evasive Riposte: whenever an incoming attack misses the Sensei while
    -- wielding a Staff, flow into TP, HP recovery, Enmity, and an evasive counter.
    player:addListener('ATTACKED', 'OX_MNK_ATTACKED', function(defender, attacker, action)
        if
            defender == nil or
            attacker == nil or
            attacker == defender or
            not isMonkSpec(defender, SENSEI_KEY) or
            not isStaffEquipped(defender) or
            action == nil or
            not action.getMsg
        then
            return
        end

        local msg = action:getMsg(defender:getID())
        local missMsg = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if msg ~= missMsg then
            return
        end

        if defender.addTP then
            defender:addTP(50)
        end

        local maxHp = defender.getMaxHP and (defender:getMaxHP() or 0) or 0
        if maxHp > 0 and defender.addHP then
            local heal = math.max(6, math.floor(maxHp * 0.015))
            defender:addHP(heal)
        end

        grantEnmity(attacker, defender, 120, 280)
        dealStaffRiposte(defender, attacker, true)
    end)
end

-----------------------------------
-- Crystal Definitions (MNK)
-----------------------------------
if xi.job and xi.job.MNK then
    spec.registerJob(xi.job.MNK, 'MNK',
    {
        {
            id          = 1,
            key         = SENSEI_KEY,
            name        = 'Sensei',
            role        = 'Staff Evasion & Counter Tank',
            icon        = 'jade_orb',
            reqLevel    = 10,
            extraAbilities = xi.jobAbility and xi.jobAbility.COUNTERSTANCE and { xi.jobAbility.COUNTERSTANCE } or nil,
            extraTraits    = { 143 },
            description = 'Agile staff master (Lv10+): evades and parries incoming blows with a Staff, ripostes missed or parried strikes, and anchors aggro through Counterstance.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +12/22/35 Staff, +8/15/25 Acc, +12/24/40 Evasion Skill, +10/22/38 EVA, +5/10/15% EVA, +6/12/20 AGI.',
                'Counter & Deflection: +15/30/50 Parry Skill, +5/10/15% Parry Rate, +12/22/30% Counter, +8/16/28 Counter DMG, +15/25/40 Enmity, -25/40/60% Enmity Loss, +6/10/15% HP, -5/8/12% DT.',
                'Staff Riposte (w/ Staff): +12% Parry Rate; Parrying heals 2% Max HP, grants +75 TP, +Enmity, and strikes back. Evading grants 1.5% Max HP, +50 TP, +Enmity, and deals an Evasive Counter.',
                'Iron Counterstance (Lv10, 120s CD): +30% Counter, +20 Counter DMG, -10% DT, +20 Enmity, with no DEF halving penalty.',
                'Tank JAs: Dodge (60s, +25 EVA, +15% EVA, +12% Parry, +15 Enmity, +35% Evasive Counter DMG), Focus (+15% Counter, +15 Parry, +10 Counter DMG), Boost (+15 Enmity, +50 TP), Chi Blast (heavy Enmity + Acc Down), Chakra (+50% heal, Regen, cleanses Slow/Silence), Perfect Counter (45s CD, +25 Counter DMG, +25 Enmity, 5% heal), Mantra (party -5% DT), Inner Strength (60s, -25% DT, +20% EVA%, +30 Counter DMG, +50 Enmity).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.STAFF,                 scaleTier(lvl, 12, 22, 35) },
                    { xi.mod.ACC,                   scaleTier(lvl, 8, 15, 25) },
                    { xi.mod.EVASION,               scaleTier(lvl, 12, 24, 40) },
                    { xi.mod.EVA,                   scaleTier(lvl, 10, 22, 38) },
                    { xi.mod.EVA_PERCENT,           scaleTier(lvl, 5, 10, 15) },
                    { xi.mod.AGI,                   scaleTier(lvl, 6, 12, 20) },
                    { xi.mod.PARRY,                 scaleTier(lvl, 15, 30, 50) },
                    { xi.mod.INQUARTATA,            scaleTier(lvl, 5, 10, 15) },
                    { xi.mod.COUNTER,               scaleTier(lvl, 12, 22, 30) },
                    { xi.mod.COUNTER_DAMAGE,        scaleTier(lvl, 8, 16, 28) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 15, 25, 40) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 40, 60) },
                    { xi.mod.HPP,                   scaleTier(lvl, 6, 10, 15) },
                    { xi.mod.DMG,                   scaleTier(lvl, -500, -800, -1200) },
                }
            end,
            onApply = function(player)
                attachSenseiListeners(player)
            end,
            onRemove = function(player)
                detachSenseiListeners(player)
            end,
        },
    })
end

-----------------------------------
-- Early & Rapid Iron Counterstance Gate (Lv10+, 120s CD)
-----------------------------------
m:addOverride('xi.actions.abilities.counterstance.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        spec.ensureUpToDate(player)

        if isMonkSpec(player, SENSEI_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(120)
            end
        else
            local mnkLvl = 0
            if player:getMainJob() == xi.job.MNK then
                mnkLvl = player:getMainLvl()
            elseif player.getSubJob and player:getSubJob() == xi.job.MNK and player.getSubLvl then
                mnkLvl = player:getSubLvl()
            end

            if mnkLvl < 45 then
                return xi.msg.basic.UNABLE_TO_USE_JA, 0
            end
        end
    end

    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.perfect_counter.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() and isMonkSpec(player, SENSEI_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(45)
        end
    end

    return super(player, target, ability)
end)

-----------------------------------
-- Staff Parry Mastery & Riposte Overrides
-----------------------------------
m:addOverride('xi.combat.physical.calculateParryRate', function(defender, attacker)
    local rate = super(defender, attacker)

    if isMonkSpec(defender, SENSEI_KEY) and isStaffEquipped(defender) then
        rate = (tonumber(rate) or 0) + 12
        if defender.hasStatusEffect and defender:hasStatusEffect(xi.effect.DODGE) then
            rate = rate + 8
        end
        rate = utils.clamp(rate, 5, 75)
    end

    return rate
end)

m:addOverride('xi.combat.physical.isParried', function(defender, attacker)
    local parried = super(defender, attacker)

    if parried and isMonkSpec(defender, SENSEI_KEY) and isStaffEquipped(defender) then
        local maxHp = defender.getMaxHP and (defender:getMaxHP() or 0) or 0
        if maxHp > 0 and defender.addHP then
            local heal = math.max(8, math.floor(maxHp * 0.02))
            defender:addHP(heal)
        end

        if defender.addTP then
            defender:addTP(75)
        end

        grantEnmity(attacker, defender, 150, 350)
        dealStaffRiposte(defender, attacker, false)
    end

    return parried
end)

-----------------------------------
-- Monk Ability & Effect Overrides
-----------------------------------
m:addOverride('xi.job_utils.monk.useCounterstance', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    target:delStatusEffect(xi.effect.COUNTERSTANCE)

    -- subType = 1 bypasses the C++ HasStatusEffect(Counterstance, 0) DEF-halving penalty
    -- while preserving effect presence for Job Point Counterstance Attack bonuses.
    local pTable =
    {
        power    = 30 + player:getMod(xi.mod.COUNTERSTANCE_EFFECT),
        duration = 300,
        origin   = player,
        subType  = 1,
        subPower = 1,
    }

    target:addStatusEffect(xi.effect.COUNTERSTANCE, pTable)

    return xi.effect.COUNTERSTANCE
end)

m:addOverride('xi.effects.counterstance.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        effect:addMod(xi.mod.DMG, -1000)
        effect:addMod(xi.mod.ENMITY, 20)
        effect:addMod(xi.mod.COUNTER_DAMAGE, 20)
    end
end)

m:addOverride('xi.job_utils.monk.useDodge', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = target:getMod(xi.mod.DODGE_EFFECT) + target:getJobPointLevel(xi.jp.DODGE_EFFECT),
        duration = 60,
        origin   = player,
        subPower = 1,
    }

    player:addStatusEffect(xi.effect.DODGE, pTable)

    return xi.effect.DODGE
end)

m:addOverride('xi.effects.dodge.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        effect:addMod(xi.mod.EVA, 25)
        effect:addMod(xi.mod.EVA_PERCENT, 15)
        effect:addMod(xi.mod.INQUARTATA, 12)
        effect:addMod(xi.mod.ENMITY, 15)
    end
end)

m:addOverride('xi.job_utils.monk.useFocus', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = target:getMod(xi.mod.FOCUS_EFFECT) + target:getJobPointLevel(xi.jp.FOCUS_EFFECT),
        duration = 60,
        origin   = player,
        subPower = 1,
    }

    player:addStatusEffect(xi.effect.FOCUS, pTable)

    return xi.effect.FOCUS
end)

m:addOverride('xi.effects.focus.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        effect:addMod(xi.mod.COUNTER, 15)
        effect:addMod(xi.mod.PARRY, 15)
        effect:addMod(xi.mod.COUNTER_DAMAGE, 10)
    end
end)

m:addOverride('xi.job_utils.monk.useBoost', function(player, target, ability)
    super(player, target, ability)

    if isMonkSpec(player, SENSEI_KEY) and isStaffEquipped(player) then
        if player.addTP then
            player:addTP(50)
        end

        local engagedTarget = player.getTarget and player:getTarget() or nil
        if engagedTarget ~= nil then
            grantEnmity(engagedTarget, player, 100, 220)
        end
    end
end)

m:addOverride('xi.job_utils.monk.useChiBlast', function(player, target, ability)
    local dmg = super(player, target, ability)

    if isMonkSpec(player, SENSEI_KEY) and target ~= nil and target ~= player then
        grantEnmity(target, player, 450, 1200)
        if target.addStatusEffect and xi.effect.ACCURACY_DOWN then
            target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 20, duration = 30, origin = player })
        end
    end

    return dmg
end)

m:addOverride('xi.job_utils.monk.useChakra', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local wasCleansedSlow = player:hasStatusEffect(xi.effect.SLOW)
    local wasCleansedSilence = player:hasStatusEffect(xi.effect.SILENCE)

    player:addMod(xi.mod.CHAKRA_MULT, 50)
    local recoveryAmount = super(player, target, ability)
    player:delMod(xi.mod.CHAKRA_MULT, 50)

    if wasCleansedSlow then
        player:delStatusEffect(xi.effect.SLOW)
    end
    if wasCleansedSilence then
        player:delStatusEffect(xi.effect.SILENCE)
    end

    local lvl = player.getMainLvl and player:getMainLvl() or 10
    local regenPower = scaleTier(lvl, 8, 16, 26)
    if player:hasStatusEffect(xi.effect.REGEN) then
        player:delStatusEffect(xi.effect.REGEN)
    end
    player:addStatusEffect(xi.effect.REGEN, { power = regenPower, duration = 30, origin = player, tier = 1 })

    local engagedTarget = player.getTarget and player:getTarget() or nil
    if engagedTarget ~= nil then
        grantEnmity(engagedTarget, player, 150, 400)
    end

    return recoveryAmount
end)

m:addOverride('xi.job_utils.monk.usePerfectCounter', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = 2,
        duration = 30,
        origin   = player,
        subPower = 1,
    }

    player:addStatusEffect(xi.effect.PERFECT_COUNTER, pTable)

    if player.addHP and player.getMaxHP then
        local heal = math.max(10, math.floor(player:getMaxHP() * 0.05))
        player:addHP(heal)
    end

    return xi.effect.PERFECT_COUNTER
end)

m:addOverride('xi.effects.perfect_counter.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:addMod(xi.mod.COUNTER_DAMAGE, 25)
        target:addMod(xi.mod.ENMITY, 25)
    end
end)

m:addOverride('xi.effects.perfect_counter.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:delMod(xi.mod.COUNTER_DAMAGE, 25)
        target:delMod(xi.mod.ENMITY, 25)
    end
end)

m:addOverride('xi.job_utils.monk.useMantra', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    target:delStatusEffect(xi.effect.MAX_HP_BOOST)

    local pTable =
    {
        power    = player:getMerit(xi.merit.MANTRA),
        duration = 180,
        origin   = player,
    }

    local targetId = target:getID()
    pendingMantraMods[targetId] =
    {
        { xi.mod.DMG, -500 },
    }
    target:addStatusEffect(xi.effect.MAX_HP_BOOST, pTable)
    pendingMantraMods[targetId] = nil

    return xi.effect.MAX_HP_BOOST
end)

m:addOverride('xi.effects.max_hp_boost.onEffectGain', function(target, effect)
    super(target, effect)

    if target == nil or effect == nil then
        return
    end

    local extra = pendingMantraMods[target:getID()]
    if extra ~= nil then
        for _, pair in ipairs(extra) do
            effect:addMod(pair[1], pair[2])
        end
    end
end)

m:addOverride('xi.job_utils.monk.useInnerStrength', function(player, target, ability)
    if not isMonkSpec(player, SENSEI_KEY) then
        return super(player, target, ability)
    end

    local pTable =
    {
        power    = 2,
        duration = 60,
        origin   = player,
        subPower = 1,
    }

    player:addStatusEffect(xi.effect.INNER_STRENGTH, pTable)

    return xi.effect.INNER_STRENGTH
end)

m:addOverride('xi.effects.inner_strength.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:addMod(xi.mod.DMG, -2500)
        target:addMod(xi.mod.EVA_PERCENT, 20)
        target:addMod(xi.mod.COUNTER_DAMAGE, 30)
        target:addMod(xi.mod.ENMITY, 50)
    end
end)

m:addOverride('xi.effects.inner_strength.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:delMod(xi.mod.DMG, -2500)
        target:delMod(xi.mod.EVA_PERCENT, 20)
        target:delMod(xi.mod.COUNTER_DAMAGE, 30)
        target:delMod(xi.mod.ENMITY, 50)
    end
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if isMonkSpec(player, SENSEI_KEY) then
        attachSenseiListeners(player)
    end
end)

return m
