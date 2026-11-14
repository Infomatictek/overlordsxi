-----------------------------------
-- OverlordsXI Warrior Crystal Specs
-- Registers Warrior crystals (Commander, Berserker, Gladiator) and
-- implements their passive scaling stats and ability transformations.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
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
local pendingBloodRageMods = {}

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

local function hasShieldEquipped(player)
    if player == nil then
        return false
    end

    if player.getEquippedItem and xi.slot and xi.slot.SUB then
        local sub = player:getEquippedItem(xi.slot.SUB)
        if sub ~= nil and sub.isShield then
            return sub:isShield()
        end
    end

    if player.getShieldSize then
        return (player:getShieldSize() or 0) > 0
    end

    return false
end

local function isClubAndShield(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    if not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end

    if player:getWeaponSkillType(xi.slot.MAIN) ~= xi.skill.CLUB then
        return false
    end

    return hasShieldEquipped(player)
end

local function isBloodthirsty(player)
    if player == nil or not player.hasStatusEffect then
        return false
    end

    return player:hasStatusEffect(xi.effect.BLOOD_RAGE) or player:hasStatusEffect(xi.effect.MIGHTY_STRIKES)
end

local function healBloodthirsty(player, baseAmount)
    if
        player == nil or
        not isWarriorSpec(player, GLADIATOR_KEY) or
        not isClubAndShield(player)
    then
        return 0
    end

    local amount = math.max(0, math.floor(tonumber(baseAmount) or 0))
    if amount <= 0 then
        return 0
    end

    if isBloodthirsty(player) then
        amount = amount * 2
    end

    if player.addHP then
        player:addHP(amount)
    end

    return amount
end

local function applyGladiatorBloodRage(target, origin, duration)
    if target == nil then
        return
    end

    local lvl = origin and origin.getMainLvl and origin:getMainLvl() or (target.getMainLvl and target:getMainLvl() or 10)
    local targetId = target:getID()
    pendingBloodRageMods[targetId] =
    {
        { xi.mod.DMG,    -1000 },
        { xi.mod.ENMITY, 25 },
        { xi.mod.REGEN,  scaleTier(lvl, 8, 16, 28) },
    }
    target:addStatusEffect(xi.effect.BLOOD_RAGE, { power = 5, duration = duration, origin = origin or target, subPower = 1 })
    pendingBloodRageMods[targetId] = nil
end

local function detachGladiatorListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_GLAD_MELEE')
        player:removeListener('OX_GLAD_WS')
    end
end

local function attachGladiatorListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachGladiatorListeners(player)

    player:addListener('MELEE_SWING_HIT', 'OX_GLAD_MELEE', function(actor, target)
        if
            actor == nil or
            target == nil or
            target == actor or
            not isWarriorSpec(actor, GLADIATOR_KEY) or
            not isClubAndShield(actor)
        then
            return
        end

        local maxHp = actor.getMaxHP and actor:getMaxHP() or 0
        local lvl = actor.getMainLvl and actor:getMainLvl() or 10
        local baseHeal = math.max(4, math.floor(maxHp * 0.01) + math.floor(lvl * 0.2))
        healBloodthirsty(actor, baseHeal)
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_GLAD_WS', function(actor, target, _ws, tp, _action, dmg)
        if
            actor == nil or
            target == nil or
            target == actor or
            (dmg ~= nil and dmg <= 0) or
            not isWarriorSpec(actor, GLADIATOR_KEY) or
            not isClubAndShield(actor)
        then
            return
        end

        local maxHp = actor.getMaxHP and actor:getMaxHP() or 0
        local spentTp = tonumber(tp) or 1000
        local extraSteps = math.min(2, math.max(0, (spentTp - 1000) / 1000))
        local pct = 0.03 + (0.01 * extraSteps)
        local baseHeal = math.max(12, math.floor(maxHp * pct))
        healBloodthirsty(actor, baseHeal)
    end)
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
            extraAbilities = xi.jobAbility and xi.jobAbility.WARCRY and { xi.jobAbility.WARCRY } or nil,
            extraTraits    = { 140 },
            description = 'Inspiring tactician: unlocks at Lv10 with Warcry on a 60s cooldown and shares your active Warrior JA buff with the entire party. Only 1 WAR JA stance active at a time.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +5/8/12% Max HP, +8/16/28 Attack, +6/12/20 Acc, +4/8/12 Store TP.',
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
            extraTraits = { 141 },
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
            role        = 'Bloodthirsty Club & Shield Tank',
            icon        = 'amber_crescent',
            reqLevel    = 10,
            extraTraits = { 142 },
            description = 'Bloodthirsty Club & Shield tank (Lv10+): extreme sturdiness, Shield Mastery, high enmity, and Bloodthirsty self-healing at the cost of much lower damage output.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +10/15/22% Max HP, +6/12/20 VIT, +12/20/30% DEF, -6/10/15% Damage Taken, +15/25/40 Enmity, +10/15/20% Cure Rcvd.',
                'Club & Shield Mastery: +10/20/35 Club & Shield skill, +12/24/40 Shield DEF, +8/14/22% Block Rate, +15/25/40 Shield TP (+10% Block w/ Club+Shield).',
                'Lower Damage Output: -25% Attack%, -25% Ranged Attack%, and -20% Weaponskill Damage.',
                'Bloodthirsty Leech (Club+Shield): Club hits heal 1% Max HP + 0.2*Lv, Club WSs heal 3-5% Max HP, Shield Blocks heal 1.5% Max HP (2x under Blood Rage or Mighty Strikes).',
                'Tank JAs: Defender (+35% DEF, -10% PDT, +15% Block), Blood Rage (-10% DT, +25 Enmity, Regen, 2x Leech), Warcry (party -8% DT; self +12 Enmity & 15% HP heal), Mighty Strikes (-25% DT, +50 Enmity, 2x Leech).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,                  scaleTier(lvl, 10, 15, 22) },
                    { xi.mod.VIT,                  scaleTier(lvl, 6, 12, 20) },
                    { xi.mod.DEFP,                 scaleTier(lvl, 12, 20, 30) },
                    { xi.mod.DMG,                  scaleTier(lvl, -600, -1000, -1500) },
                    { xi.mod.ENMITY,               scaleTier(lvl, 15, 25, 40) },
                    { xi.mod.CURE_POTENCY_RCVD,    scaleTier(lvl, 10, 15, 20) },
                    { xi.mod.CLUB,                 scaleTier(lvl, 10, 20, 35) },
                    { xi.mod.SHIELD,               scaleTier(lvl, 10, 20, 35) },
                    { xi.mod.SHIELD_DEF_BONUS,     scaleTier(lvl, 12, 24, 40) },
                    { xi.mod.PALISADE_BLOCK_BONUS, scaleTier(lvl, 8, 14, 22) },
                    { xi.mod.SHIELD_MASTERY_TP,    scaleTier(lvl, 15, 25, 40) },
                    -- Substantially lower damage output tradeoff
                    { xi.mod.ATTP,                 -25 },
                    { xi.mod.RATTP,                -25 },
                    { xi.mod.ALL_WSDMG_ALL_HITS,   -20 },
                }
            end,
            onApply = function(player)
                attachGladiatorListeners(player)
            end,
            onRemove = function(player)
                detachGladiatorListeners(player)
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
    elseif isWarriorSpec(player, GLADIATOR_KEY) then
        local duration = 180 + player:getMod(xi.mod.DEFENDER_DURATION)
        player:addStatusEffect(xi.effect.DEFENDER, { power = 35, duration = duration, origin = player, subPower = 2 })
        return xi.effect.DEFENDER
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.defender.onEffectGain', function(target, effect)
    super(target, effect)

    if effect == nil then
        return
    end

    local tag = effect:getSubPower()
    if tag == 1 then
        -- Commander Defender: +15% DEFP with only -10% ATTP/RATTP penalty (vs retail -25%)
        effect:addMod(xi.mod.ATTP, 15)
        effect:addMod(xi.mod.RATTP, 15)
    elseif tag == 2 then
        -- Gladiator Defender (Iron Bastion): +35% DEFP, -10% PDT, +15% Block Rate, +20 Shield DEF
        effect:addMod(xi.mod.DMGPHYS, -1000)
        effect:addMod(xi.mod.PALISADE_BLOCK_BONUS, 15)
        effect:addMod(xi.mod.SHIELD_DEF_BONUS, 20)
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
        -- Gladiator Aggressor (Challenger's Stance): no EVA penalty, +20 Enmity, +10% Shield Block Rate
        effect:addMod(xi.mod.EVA, 25)
        effect:addMod(xi.mod.ENMITY, 20)
        effect:addMod(xi.mod.PALISADE_BLOCK_BONUS, 10)
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
    elseif isWarriorSpec(player, GLADIATOR_KEY) then
        player:addStatusEffect(xi.effect.RETALIATION, { power = 1, duration = 180, origin = player, subPower = 3 })
        return xi.effect.RETALIATION
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.retaliation.onEffectGain', function(target, effect)
    if effect ~= nil then
        local tag = effect:getSubPower()
        if tag == 2 then
            -- Commander Retaliation: no movement speed penalty + 8% Counter
            effect:addMod(xi.mod.COUNTER, 8)
            return
        elseif tag == 3 then
            -- Gladiator Retaliation: no movement speed penalty + 12% Counter + 15 Enmity
            effect:addMod(xi.mod.COUNTER, 12)
            effect:addMod(xi.mod.ENMITY, 15)
            return
        end
    end

    super(target, effect)
end)

m:addOverride('xi.effects.retaliation.onEffectLose', function(target, effect)
    if effect ~= nil and (effect:getSubPower() == 2 or effect:getSubPower() == 3) then
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
    if isWarriorSpec(player, GLADIATOR_KEY) then
        local duration = 45 + player:getMod(xi.mod.ENHANCES_BLOOD_RAGE)
        applyGladiatorBloodRage(target, player, duration)

        if player:getID() ~= target:getID() then
            ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
        end

        return xi.effect.BLOOD_RAGE
    elseif isWarriorSpec(player, BERSERKER_KEY) then
        local power    = 30 + player:getJobPointLevel(xi.jp.BLOOD_RAGE_EFFECT)
        local duration = 45 + player:getMod(xi.mod.ENHANCES_BLOOD_RAGE)

        target:addStatusEffect(xi.effect.BLOOD_RAGE, { power = power, duration = duration, origin = player })

        if player:getID() ~= target:getID() then
            ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
        end

        return xi.effect.BLOOD_RAGE
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.blood_rage.onEffectGain', function(target, effect)
    super(target, effect)

    if target == nil or effect == nil then
        return
    end

    if effect:getSubPower() == 1 then
        local extra = pendingBloodRageMods[target:getID()]
        if extra ~= nil then
            for _, pair in ipairs(extra) do
                effect:addMod(pair[1], pair[2])
            end
        end
    end
end)

m:addOverride('xi.job_utils.warrior.useWarcry', function(player, target, ability)
    local isCmd  = isWarriorSpec(player, COMMANDER_KEY)
    local isBrk  = isWarriorSpec(player, BERSERKER_KEY)
    local isGlad = isWarriorSpec(player, GLADIATOR_KEY)
    if not isCmd and not isBrk and not isGlad then
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

    if isGlad then
        local isSelf   = (player:getID() == target:getID())
        local merit    = player:getMerit(xi.merit.SAVAGERY)
        local duration = 30 + player:getMod(xi.mod.WARCRY_DURATION)

        if target:hasStatusEffect(xi.effect.WARCRY) then
            target:delStatusEffectSilent(xi.effect.WARCRY)
        end

        local targetId = target:getID()
        local mods =
        {
            { xi.mod.DMG, -800 },
        }
        if isSelf then
            table.insert(mods, { xi.mod.ENMITY, 12 })
        end
        pendingWarcryMods[targetId] = mods
        target:addStatusEffect(xi.effect.WARCRY, { power = 0, duration = duration, origin = player, subPower = merit })
        pendingWarcryMods[targetId] = nil

        if isSelf and player.addHP and player.getMaxHP then
            local selfHeal = math.max(15, math.floor(player:getMaxHP() * 0.15))
            player:addHP(selfHeal)
        else
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
    player:addStatusEffect(xi.effect.WARRIORS_CHARGE, { power = math.max(merits - 5, 5), duration = 60, origin = player })
    applyGladiatorBloodRage(player, player, 20)

    if player.addHP and player.getMaxHP then
        local selfHeal = math.max(10, math.floor(player:getMaxHP() * 0.10))
        player:addHP(selfHeal)
    end

    return xi.effect.WARRIORS_CHARGE
end)

m:addOverride('xi.job_utils.warrior.useMightyStrikes', function(player, target, ability)
    if not isWarriorSpec(player, GLADIATOR_KEY) then
        return super(player, target, ability)
    end

    player:addStatusEffect(xi.effect.MIGHTY_STRIKES, { power = 1, duration = 60, origin = player, subPower = 2 })

    return xi.effect.MIGHTY_STRIKES
end)

m:addOverride('xi.effects.mighty_strikes.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 2 then
        target:addMod(xi.mod.DMG, -2500)
        target:addMod(xi.mod.ENMITY, 50)
    end
end)

m:addOverride('xi.effects.mighty_strikes.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 2 then
        target:delMod(xi.mod.DMG, -2500)
        target:delMod(xi.mod.ENMITY, 50)
    end
end)

-----------------------------------
-- Gladiator Club & Shield Block Mastery + Bloodthirsty Sustain
-----------------------------------
m:addOverride('xi.combat.physical.calculateBlockRate', function(defender, attacker)
    local rate = super(defender, attacker)

    if isWarriorSpec(defender, GLADIATOR_KEY) and isClubAndShield(defender) then
        rate = utils.clamp((tonumber(rate) or 0) + 10, 5, 100)
    end

    return rate
end)

m:addOverride('xi.combat.physical.isBlocked', function(defender, attacker)
    local blocked = super(defender, attacker)

    if blocked and isWarriorSpec(defender, GLADIATOR_KEY) and isClubAndShield(defender) then
        local maxHp = defender.getMaxHP and defender:getMaxHP() or 0
        local baseHeal = math.max(6, math.floor(maxHp * 0.015))
        healBloodthirsty(defender, baseHeal)
    end

    return blocked
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if isWarriorSpec(player, GLADIATOR_KEY) then
        attachGladiatorListeners(player)
    end
end)

return m
