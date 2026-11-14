-----------------------------------
-- OverlordsXI Warrior Crystal Specs
-- Registers Warrior crystals (Commander, Berserker, Gladiator) and
-- implements their passive scaling stats and ability transformations.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/job_utils/warrior')
-----------------------------------
local m = Module:new('overlords_war_specs')

local spec = xi.overlords.spec

local COMMANDER_KEY = 'commander'
local BERSERKER_KEY = 'berserker'
local GLADIATOR_KEY = 'gladiator'

local COMMANDER_STANCES =
{
    xi.effect.BERSERK,
    xi.effect.DEFENDER,
    xi.effect.AGGRESSOR,
    xi.effect.RETALIATION,
    xi.effect.RESTRAINT,
}

local pendingWarcryMods = {}

local function scaleTier(lvl, low, mid, high)
    local l = lvl or 1
    if l >= 50 then
        return high
    elseif l >= 30 then
        return mid
    end
    return low
end

local function isWarriorSpec(entity, specKey)
    if entity == nil or not entity:isPC() or entity:getMainJob() ~= xi.job.WAR then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.WAR, specKey)
end

local function clearOtherCommanderStances(player, keepEffectId)
    if player == nil then
        return
    end

    for _, effId in ipairs(COMMANDER_STANCES) do
        if effId ~= keepEffectId and player:hasStatusEffect(effId) then
            player:delStatusEffectSilent(effId)
        end
    end
end

local function enforceSingleCommanderStance(player)
    if player == nil then
        return
    end

    local kept = nil
    for _, effId in ipairs(COMMANDER_STANCES) do
        if player:hasStatusEffect(effId) then
            if kept == nil then
                kept = effId
            else
                player:delStatusEffectSilent(effId)
            end
        end
    end
end

local function getCommanderActiveStance(player)
    if player == nil then
        return nil
    end

    for _, effId in ipairs(COMMANDER_STANCES) do
        if player:hasStatusEffect(effId) then
            return effId
        end
    end

    return nil
end

-----------------------------------
-- Crystal Definitions (WAR)
-----------------------------------
if xi.job and xi.job.WAR then
    spec.registerJob(xi.job.WAR, 'WAR',
    {
        {
            id          = 1,
            key         = COMMANDER_KEY,
            name        = 'Commander',
            role        = 'Support DPS / Party Tactician',
            icon        = 'blue_crystal',
            reqLevel    = 10,
            description = 'Inspiring tactician: unlocks at Lv10 with Warcry on a 60s cooldown and shares your active Warrior JA buff with the entire party. Only 1 WAR JA stance active at a time.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +5/8/12% Max HP, +8/16/28 Attack, +6/12/20 Acc, +4/8/12 Store TP, +5/8/12 Enmity.',
                'Early & Rapid Warcry: Unlocked at Lv10 with a 60s cooldown (45s duration); shares your active JA buff to all allies.',
                'Single-Stance Rule: Only 1 WAR JA buff (Berserk, Defender, Aggressor, Retaliation, Restraint) can be active at a time.',
                'Berserk -> Warcry: Self +10% Atk (-10% DEF); Warcry brings Commander & all allies to +15% Attack & +100 TP Bonus.',
                'Defender -> Warcry: Self +15% DEF (-10% Atk); Warcry grants party +20% DEF, -8% Damage Taken, & +8% Attack.',
                'Aggressor / Retaliation / Restraint -> Warcry: Shares +25 Acc & +8% DA, +12% Counter & +10 STP, or +12% WSD & +200 TP Bonus.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,     scaleTier(lvl, 5, 8, 12) },
                    { xi.mod.ATT,     scaleTier(lvl, 8, 16, 28) },
                    { xi.mod.ACC,     scaleTier(lvl, 6, 12, 20) },
                    { xi.mod.STORETP, scaleTier(lvl, 4, 8, 12) },
                    { xi.mod.ENMITY,  scaleTier(lvl, 5, 8, 12) },
                }
            end,
            onApply = function(player)
                enforceSingleCommanderStance(player)
            end,
        },
        {
            id          = 2,
            key         = BERSERKER_KEY,
            name        = 'Berserker',
            role        = 'Fury / Heavy Burst DPS',
            icon        = 'crimson_shard',
            reqLevel    = 10,
            description = 'Unrelenting fury (Lv10+): amplifies Berserk, Blood Rage, and Warcry with heavy Attack, Double Attack, and WSD.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +8/12/16% Attack, +6/10/14% Double Attack, +5/8/12% WS Damage, +5/10/15 Store TP.',
                'Berserk: +10% extra Attack%, +60s duration, and instantly grants +300 TP on activation.',
                'Aggressor: Removes -25 Evasion penalty and grants +5% Critical Hit Rate.',
                'Blood Rage: +10% extra Critical Hit Rate and +15s duration.',
                'Warcry: +8% extra Attack% potency.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.ATTP,               scaleTier(lvl, 8, 12, 16) },
                    { xi.mod.DOUBLE_ATTACK,      scaleTier(lvl, 6, 10, 14) },
                    { xi.mod.ALL_WSDMG_ALL_HITS, scaleTier(lvl, 5, 8, 12) },
                    { xi.mod.STORETP,            scaleTier(lvl, 5, 10, 15) },
                }
            end,
        },
        {
            id          = 3,
            key         = GLADIATOR_KEY,
            name        = 'Gladiator',
            role        = 'Arena Duelist / Crit & Combo',
            icon        = 'amber_crescent',
            reqLevel    = 10,
            description = 'Relentless duelist (Lv10+): focuses on Critical Hits, Counter, Skillchains, Dual Wield speed, and Fencer bursts.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +5/8/12% Crit Rate, +6/10/15% Crit Dmg, +6/10/14% Counter, +8/10/15% SC Bonus.',
                'Dual Wield & Fencer: -5/10/15% Dual Wield delay, +100/200/300 Fencer TP Bonus, +2/4/6% Fencer Crit.',
                'Aggressor: Grants +15 Accuracy, +10% Double Attack, and +5% Triple Attack.',
                "Warrior's Charge: Guarantees >=15% Triple Attack and triggers +15% Blood Rage Crit for 30s.",
                'Mighty Strikes: +15s duration (60s total) and +15% Critical Hit Damage.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.CRITHITRATE,        scaleTier(lvl, 5, 8, 12) },
                    { xi.mod.CRIT_DMG_INCREASE,  scaleTier(lvl, 6, 10, 15) },
                    { xi.mod.COUNTER,            scaleTier(lvl, 6, 10, 14) },
                    { xi.mod.DUAL_WIELD,         scaleTier(lvl, 5, 10, 15) },
                    { xi.mod.SKILLCHAINBONUS,    scaleTier(lvl, 8, 10, 15) },
                    { xi.mod.FENCER_TP_BONUS,    scaleTier(lvl, 100, 200, 300) },
                    { xi.mod.FENCER_CRITHITRATE, scaleTier(lvl, 2, 4, 6) },
                }
            end,
        },
    })
end

-----------------------------------
-- Commander Early & Short-CD Warcry Gate
-----------------------------------
m:addOverride('xi.actions.abilities.warcry.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        spec.ensureUpToDate(player)

        if isWarriorSpec(player, COMMANDER_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(60)
            end
        else
            local warLvl = 0
            if player:getMainJob() == xi.job.WAR then
                warLvl = player:getMainLvl()
            elseif player.getSubJob and player:getSubJob() == xi.job.WAR and player.getSubLvl then
                warLvl = player:getSubLvl()
            end

            if warLvl < 35 then
                return xi.msg.basic.UNABLE_TO_USE_JA, 0
            end
        end
    end

    return super(player, target, ability)
end)

-----------------------------------
-- Warrior Ability & Effect Overrides
-----------------------------------
m:addOverride('xi.job_utils.warrior.useBerserk', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.BERSERK)
        local duration = 180 + player:getMod(xi.mod.BERSERK_DURATION)
        player:addStatusEffect(xi.effect.BERSERK, { power = 10, duration = duration, origin = player, subPower = 10 })
        return xi.effect.BERSERK
    elseif isWarriorSpec(player, BERSERKER_KEY) then
        local warriorLevel = player:getMainLvl()
        local levelScale   = math.floor((warriorLevel - 40) / 10) * 2
        local power        = 35 + player:getMod(xi.mod.BERSERK_POTENCY) + utils.clamp(levelScale, 0, 10)
        local duration     = 240 + player:getMod(xi.mod.BERSERK_DURATION)

        player:addStatusEffect(xi.effect.BERSERK, { power = power, duration = duration, origin = player, subPower = 25 })
        if player.addTP then
            player:addTP(300)
        end

        return xi.effect.BERSERK
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.warrior.useDefender', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.DEFENDER)
        local duration = 180 + player:getMod(xi.mod.DEFENDER_DURATION)
        player:addStatusEffect(xi.effect.DEFENDER, { power = 15, duration = duration, origin = player, subPower = 1 })
        return xi.effect.DEFENDER
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.defender.onEffectGain', function(target, effect)
    super(target, effect)

    -- Commander Defender: +15% DEFP with only -10% ATTP/RATTP penalty (vs retail -25%)
    if effect ~= nil and effect:getSubPower() == 1 then
        effect:addMod(xi.mod.ATTP, 15)
        effect:addMod(xi.mod.RATTP, 15)
    end
end)

m:addOverride('xi.job_utils.warrior.useAggressor', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.AGGRESSOR)
        local merits = player:getMerit(xi.merit.AGGRESSIVE_AIM)
        player:addStatusEffect(xi.effect.AGGRESSOR, { power = merits, duration = 180 + player:getMod(xi.mod.AGGRESSOR_DURATION), origin = player, subPower = 3 })
        return xi.effect.AGGRESSOR
    elseif isWarriorSpec(player, BERSERKER_KEY) then
        local merits = player:getMerit(xi.merit.AGGRESSIVE_AIM)
        player:addStatusEffect(xi.effect.AGGRESSOR, { power = merits, duration = 180 + player:getMod(xi.mod.AGGRESSOR_DURATION), origin = player, subPower = 1 })
        return xi.effect.AGGRESSOR
    elseif isWarriorSpec(player, GLADIATOR_KEY) then
        local merits = player:getMerit(xi.merit.AGGRESSIVE_AIM)
        player:addStatusEffect(xi.effect.AGGRESSOR, { power = merits, duration = 180 + player:getMod(xi.mod.AGGRESSOR_DURATION), origin = player, subPower = 2 })
        return xi.effect.AGGRESSOR
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.aggressor.onEffectGain', function(target, effect)
    super(target, effect)

    if effect == nil then
        return
    end

    local tag = effect:getSubPower()
    if tag == 1 then
        -- Berserker Aggressor: no EVA penalty + 5% Crit
        effect:addMod(xi.mod.EVA, 25)
        effect:addMod(xi.mod.CRITHITRATE, 5)
    elseif tag == 2 then
        -- Gladiator Aggressor: +15 Acc, +10% DA, +5% TA
        effect:addMod(xi.mod.ACC, 15)
        effect:addMod(xi.mod.DOUBLE_ATTACK, 10)
        effect:addMod(xi.mod.TRIPLE_ATTACK, 5)
    elseif tag == 3 then
        -- Commander Aggressor: self +15 ACC/RACC and only -10 EVA (vs +25/-25)
        effect:addMod(xi.mod.ACC, -10)
        effect:addMod(xi.mod.RACC, 15)
        effect:addMod(xi.mod.EVA, 15)
    end
end)

m:addOverride('xi.job_utils.warrior.useRetaliation', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.RETALIATION)
        player:addStatusEffect(xi.effect.RETALIATION, { power = 1, duration = 180, origin = player, subPower = 2 })
        return xi.effect.RETALIATION
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.retaliation.onEffectGain', function(target, effect)
    if effect ~= nil and effect:getSubPower() == 2 then
        -- Commander Retaliation: no movement speed penalty + 8% Counter
        effect:addMod(xi.mod.COUNTER, 8)
        return
    end

    super(target, effect)
end)

m:addOverride('xi.effects.retaliation.onEffectLose', function(target, effect)
    if effect ~= nil and effect:getSubPower() == 2 then
        return
    end

    super(target, effect)
end)

m:addOverride('xi.job_utils.warrior.useRestraint', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.RESTRAINT)
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.warrior.useBloodRage', function(player, target, ability)
    if not isWarriorSpec(player, BERSERKER_KEY) then
        return super(player, target, ability)
    end

    local power    = 30 + player:getJobPointLevel(xi.jp.BLOOD_RAGE_EFFECT)
    local duration = 45 + player:getMod(xi.mod.ENHANCES_BLOOD_RAGE)

    target:addStatusEffect(xi.effect.BLOOD_RAGE, { power = power, duration = duration, origin = player })

    if player:getID() ~= target:getID() then
        ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    end

    return xi.effect.BLOOD_RAGE
end)

m:addOverride('xi.job_utils.warrior.useWarcry', function(player, target, ability)
    local isCmd = isWarriorSpec(player, COMMANDER_KEY)
    local isBrk = isWarriorSpec(player, BERSERKER_KEY)
    if not isCmd and not isBrk then
        return super(player, target, ability)
    end

    if isCmd then
        local isSelf    = (player:getID() == target:getID())
        local stance    = getCommanderActiveStance(player)
        local merit     = player:getMerit(xi.merit.SAVAGERY)
        local tpBonus   = merit + 100
        local warcryAtk = 8
        local duration  = 45 + player:getMod(xi.mod.WARCRY_DURATION)
        local extra     = nil

        if stance == xi.effect.BERSERK then
            -- Self Berserk grants +10% Atk; Warcry gives Commander +5% (15% total) and allies +15%
            warcryAtk = isSelf and 5 or 15
        elseif stance == xi.effect.DEFENDER then
            -- Self Defender grants +15% DEF; Warcry grants Commander +5% DEF (20% total) and allies +20% DEF, plus -8% DMG
            warcryAtk = 8
            extra =
            {
                { xi.mod.DEFP, isSelf and 5 or 20 },
                { xi.mod.DMG,  -800 },
            }
        elseif stance == xi.effect.AGGRESSOR then
            -- Self Aggressor grants +15 Acc/RAcc; Warcry brings everyone to +25 Acc/RAcc & +8% Double Attack
            warcryAtk = 8
            local accShare = isSelf and 10 or 25
            extra =
            {
                { xi.mod.ACC,           accShare },
                { xi.mod.RACC,          accShare },
                { xi.mod.DOUBLE_ATTACK, 8 },
            }
        elseif stance == xi.effect.RETALIATION then
            -- Self Retaliation grants +8% Counter; Warcry brings everyone to +12% Counter & +10 Store TP
            warcryAtk = 8
            extra =
            {
                { xi.mod.COUNTER, isSelf and 4 or 12 },
                { xi.mod.STORETP, 10 },
            }
        elseif stance == xi.effect.RESTRAINT then
            -- Restraint stance Warcry inspires party WS Burst: +12% WSD & +200 total TP Bonus
            warcryAtk = 8
            tpBonus = merit + 200
            extra =
            {
                { xi.mod.ALL_WSDMG_ALL_HITS, 12 },
            }
        end

        if target:hasStatusEffect(xi.effect.WARCRY) then
            target:delStatusEffectSilent(xi.effect.WARCRY)
        end

        local targetId = target:getID()
        pendingWarcryMods[targetId] = extra
        target:addStatusEffect(xi.effect.WARCRY, { power = warcryAtk, duration = duration, origin = player, subPower = tpBonus })
        pendingWarcryMods[targetId] = nil

        if not isSelf then
            ability:setMsg(xi.msg.basic.JA_ATK_ENHANCED)
        end

        return xi.effect.WARCRY
    end

    -- Berserker Warcry
    local merit    = player:getMerit(xi.merit.SAVAGERY)
    local warLevel = utils.getActiveJobLevel(player, xi.job.WAR)
    local power    = (math.floor((warLevel / 4) + 4.75) / 256) * 100 + 8
    local duration = 30 + player:getMod(xi.mod.WARCRY_DURATION)

    target:addStatusEffect(xi.effect.WARCRY, { power = power, duration = duration, origin = player, subPower = merit })

    if player:getID() ~= target:getID() then
        ability:setMsg(xi.msg.basic.JA_ATK_ENHANCED)
    end

    return xi.effect.WARCRY
end)

m:addOverride('xi.effects.warcry.onEffectGain', function(target, effect)
    super(target, effect)

    if target == nil or effect == nil then
        return
    end

    local extra = pendingWarcryMods[target:getID()]
    if extra ~= nil then
        for _, pair in ipairs(extra) do
            effect:addMod(pair[1], pair[2])
        end
    end
end)

m:addOverride('xi.job_utils.warrior.useWarriorsCharge', function(player, target, ability, action)
    if not isWarriorSpec(player, GLADIATOR_KEY) then
        return super(player, target, ability, action)
    end

    local merits = player:getMerit(xi.merit.WARRIORS_CHARGE)
    local power  = math.max(merits - 5, 15)

    player:addStatusEffect(xi.effect.WARRIORS_CHARGE, { power = power, duration = 60, origin = player })
    if not player:hasStatusEffect(xi.effect.BLOOD_RAGE) then
        player:addStatusEffect(xi.effect.BLOOD_RAGE, { power = 15, duration = 30, origin = player })
    end

    return xi.effect.WARRIORS_CHARGE
end)

m:addOverride('xi.job_utils.warrior.useMightyStrikes', function(player, target, ability)
    if not isWarriorSpec(player, GLADIATOR_KEY) then
        return super(player, target, ability)
    end

    player:addStatusEffect(xi.effect.MIGHTY_STRIKES, { power = 1, duration = 60, origin = player, subPower = 1 })

    return xi.effect.MIGHTY_STRIKES
end)

m:addOverride('xi.effects.mighty_strikes.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:addMod(xi.mod.CRIT_DMG_INCREASE, 15)
    end
end)

m:addOverride('xi.effects.mighty_strikes.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 1 then
        target:delMod(xi.mod.CRIT_DMG_INCREASE, 15)
    end
end)

return m
