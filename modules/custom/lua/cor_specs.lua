-----------------------------------
-- OverlordsXI Corsair Crystal Specs:
--   1. Flintlock (FLT | Tier 1 Pure Damage)
--   2. Gambler   (GMB | Tier 3 Pure Support)
--   3. Buccaneer (BUC | Tier 6 Pure Tank)
-- Unlocks @ Lv. 10
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/corsair')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_cor_specs')

local spec  = xi.overlords.spec
local slots = xi.overlords.slots

local FLINTLOCK_KEY = 'flintlock'
local GAMBLER_KEY   = 'gambler'
local BUCCANEER_KEY = 'buccaneer'

-- Custom Trait IDs (< MAX_TRAIT_ID = 256)
local TRAIT_HIGH_ROLLER_STAKES = 177
local TRAIT_FLINTLOCK_DEADEYE  = 178
local TRAIT_BUCCANEER_BULWARK  = 179

-- Starter Gun & Bullet for Lv.10+ COR auto-provision
local STARTER_GUN_ID    = 19221 -- Firefly (Lv.5 Gun)
local STARTER_BULLET_ID = 17343 -- Bronze Bullet (Lv.1 Ammo)

-- Native COR Ability IDs
local ABIL_WILD_CARD    = 96
local ABIL_PHANTOM_ROLL = 97
local ABIL_DOUBLE_UP    = 123
local ABIL_FIRE_SHOT    = 125
local ABIL_ICE_SHOT     = 126
local ABIL_WIND_SHOT    = 127
local ABIL_EARTH_SHOT   = 128
local ABIL_THUNDER_SHOT = 129
local ABIL_WATER_SHOT   = 130
local ABIL_LIGHT_SHOT   = 131
local ABIL_DARK_SHOT    = 132
local ABIL_RANDOM_DEAL  = 133
local ABIL_SNAKE_EYE    = 177
local ABIL_FOLD         = 178

-- Custom COR Ability IDs (472-477; recastIds 168-173)
local ABIL_HOUSE_ADVANTAGE     = 472
local ABIL_DEAD_MANS_HAND      = 473
local ABIL_HAIR_TRIGGER        = 474
local ABIL_BROADSIDE_SALVO     = 475
local ABIL_GRAPESHOT_BROADSIDE = 476
local ABIL_IRON_HULL           = 477

-- Custom Gambler Status Effect IDs (882-884; registered in patch 0032)
local EFFECT_HOUSE_DEBT      = 882
local EFFECT_CARD_COUNTING   = 883
local EFFECT_HOUSE_ADVANTAGE = 884

local CARD_COUNT_FIRE_LIGHT = 1 -- Next Double-Up: 3-6
local CARD_COUNT_ICE_WATER  = 2 -- Next Double-Up: 1-3

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.HOUSE_ADVANTAGE     = ABIL_HOUSE_ADVANTAGE
xi.jobAbility.DEAD_MANS_HAND      = ABIL_DEAD_MANS_HAND
xi.jobAbility.HAIR_TRIGGER        = ABIL_HAIR_TRIGGER
xi.jobAbility.BROADSIDE_SALVO     = ABIL_BROADSIDE_SALVO
xi.jobAbility.GRAPESHOT_BROADSIDE = ABIL_GRAPESHOT_BROADSIDE
xi.jobAbility.IRON_HULL           = ABIL_IRON_HULL

xi.effect = xi.effect or {}
xi.effect.HOUSE_DEBT      = EFFECT_HOUSE_DEBT
xi.effect.CARD_COUNTING   = EFFECT_CARD_COUNTING
xi.effect.HOUSE_ADVANTAGE = EFFECT_HOUSE_ADVANTAGE

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.house_advantage     = xi.actions.abilities.house_advantage or {}
xi.actions.abilities.dead_mans_hand      = xi.actions.abilities.dead_mans_hand or {}
xi.actions.abilities.hair_trigger        = xi.actions.abilities.hair_trigger or {}
xi.actions.abilities.broadside_salvo     = xi.actions.abilities.broadside_salvo or {}
xi.actions.abilities.grapeshot_broadside = xi.actions.abilities.grapeshot_broadside or {}
xi.actions.abilities.iron_hull           = xi.actions.abilities.iron_hull or {}

xi.effects = xi.effects or {}
xi.effects.house_debt      = xi.effects.house_debt or {}
xi.effects.card_counting   = xi.effects.card_counting or {}
xi.effects.house_advantage = xi.effects.house_advantage or {}

-- Retail Lucky numbers for all Phantom Rolls
local LUCKY_ROLL_BY_ABILITY =
{
    [xi.jobAbility.CORSAIRS_ROLL   or 98 ] = 5,
    [xi.jobAbility.NINJA_ROLL      or 99 ] = 4,
    [xi.jobAbility.HUNTERS_ROLL    or 100] = 4,
    [xi.jobAbility.CHAOS_ROLL      or 101] = 4,
    [xi.jobAbility.MAGUSS_ROLL     or 102] = 2,
    [xi.jobAbility.HEALERS_ROLL    or 103] = 3,
    [xi.jobAbility.DRACHEN_ROLL    or 104] = 4,
    [xi.jobAbility.CHORAL_ROLL     or 105] = 2,
    [xi.jobAbility.MONKS_ROLL      or 106] = 3,
    [xi.jobAbility.BEAST_ROLL      or 107] = 4,
    [xi.jobAbility.SAMURAI_ROLL    or 108] = 2,
    [xi.jobAbility.EVOKERS_ROLL    or 109] = 5,
    [xi.jobAbility.ROGUES_ROLL     or 110] = 5,
    [xi.jobAbility.WARLOCKS_ROLL   or 111] = 4,
    [xi.jobAbility.FIGHTERS_ROLL   or 112] = 5,
    [xi.jobAbility.PUPPET_ROLL     or 113] = 3,
    [xi.jobAbility.GALLANTS_ROLL   or 114] = 3,
    [xi.jobAbility.WIZARDS_ROLL    or 115] = 5,
    [xi.jobAbility.DANCERS_ROLL    or 116] = 3,
    [xi.jobAbility.SCHOLARS_ROLL   or 117] = 2,
    [xi.jobAbility.NATURALISTS_ROLL or 390] = 3,
    [xi.jobAbility.RUNEISTS_ROLL   or 391] = 4,
    [xi.jobAbility.BOLTERS_ROLL    or 293] = 3,
    [xi.jobAbility.CASTERS_ROLL    or 294] = 2,
    [xi.jobAbility.COURSERS_ROLL   or 295] = 3,
    [xi.jobAbility.BLITZERS_ROLL   or 296] = 4,
    [xi.jobAbility.TACTICIANS_ROLL or 297] = 5,
    [xi.jobAbility.ALLIES_ROLL     or 298] = 3,
    [xi.jobAbility.MISERS_ROLL     or 299] = 5,
    [xi.jobAbility.COMPANIONS_ROLL or 300] = 2,
    [xi.jobAbility.AVENGERS_ROLL   or 301] = 4,
}

-- Per-character Ante and post-bust Phantom Roll lock tracking
local anteByCharRoll    = {}
local rollLockUntilById = {}

local function getCorSpecKey(entity)
    if entity == nil or (entity.isPC and not entity:isPC()) then
        return nil
    end
    if entity.getMainJob and entity:getMainJob() ~= xi.job.COR then
        return nil
    end
    local active = spec.get(entity, xi.job.COR)
    if active == nil then
        return nil
    end
    if (entity.getMainLvl and entity:getMainLvl() or 1) < (active.reqLevel or 10) then
        return nil
    end
    return active.key
end

local function isGambler(entity)
    return getCorSpecKey(entity) == GAMBLER_KEY
end

local function isFlintlock(entity)
    return getCorSpecKey(entity) == FLINTLOCK_KEY
end

local function isBuccaneer(entity)
    return getCorSpecKey(entity) == BUCCANEER_KEY
end

local function isAnyCorSpec(entity)
    local key = getCorSpecKey(entity)
    return key == FLINTLOCK_KEY or key == GAMBLER_KEY or key == BUCCANEER_KEY
end

local function scaleTier(lvl, low, mid, high, cap75)
    local l = lvl or 1
    if l >= 70 then
        return cap75 or high
    elseif l >= 50 then
        return high
    elseif l >= 30 then
        return mid
    end
    return low
end

local function hasGunEquipped(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local ranged = player:getEquippedItem(xi.slot.RANGED)
    return ranged ~= nil and ranged.getSkillType and ranged:getSkillType() == xi.skill.MARKSMANSHIP
end

local function isBuccaneerLoadout(player)
    if not isBuccaneer(player) or not player.getEquippedItem then
        return false
    end
    local mainItem = player:getEquippedItem(xi.slot.MAIN)
    local ranged   = player:getEquippedItem(xi.slot.RANGED)
    local hasSword = mainItem ~= nil and mainItem.getSkillType and mainItem:getSkillType() == xi.skill.SWORD
    local hasGun   = ranged ~= nil and ranged.getSkillType and ranged:getSkillType() == xi.skill.MARKSMANSHIP
    return hasSword and hasGun
end

local function ensureCorStarterGear(player)
    if not isAnyCorSpec(player) or not player.getEquippedItem then
        return
    end
    if player:getEquippedItem(xi.slot.RANGED) == nil then
        if not player:hasItem(STARTER_GUN_ID) and player.addItem then
            player:addItem(STARTER_GUN_ID, 1)
        end
        if player.equipItem then
            player:equipItem(STARTER_GUN_ID, xi.slot.RANGED)
        end
    end
    if player:getEquippedItem(xi.slot.AMMO) == nil then
        if not player:hasItem(STARTER_BULLET_ID) and player.addItem then
            player:addItem(STARTER_BULLET_ID, 99)
        end
        if player.equipItem then
            player:equipItem(STARTER_BULLET_ID, xi.slot.AMMO)
        end
    end
end

local function getLuckyRoll(abilityId)
    if LUCKY_ROLL_BY_ABILITY[abilityId] ~= nil then
        return LUCKY_ROLL_BY_ABILITY[abilityId]
    end
    local rollInfo = xi.job_utils and xi.job_utils.corsair and xi.job_utils.corsair.rollData and xi.job_utils.corsair.rollData[abilityId]
    if rollInfo and rollInfo.powers then
        local bestIdx = 1
        local bestMag = math.abs(rollInfo.powers[1] or 0)
        for i = 2, 7 do
            local mag = math.abs(rollInfo.powers[i] or 0)
            if mag > bestMag then
                bestMag = mag
                bestIdx = i
            end
        end
        return bestIdx
    end
    return 5
end

local function isRollLocked(player)
    if player == nil or not player.getID then
        return false
    end
    local cid   = player:getID()
    local untilTs = rollLockUntilById[cid] or (player.getLocalVar and player:getLocalVar('OX_GMB_ROLL_LOCK') or 0)
    if untilTs > 0 and os.time() < untilTs then
        return true
    end
    rollLockUntilById[cid] = nil
    if player.setLocalVar then
        player:setLocalVar('OX_GMB_ROLL_LOCK', 0)
    end
    return false
end

local function setRollLock(player, seconds)
    if player == nil or not player.getID then
        return
    end
    local untilTs = os.time() + (seconds or 15)
    rollLockUntilById[player:getID()] = untilTs
    if player.setLocalVar then
        player:setLocalVar('OX_GMB_ROLL_LOCK', untilTs)
    end
end

local function clearRollLock(player)
    if player == nil or not player.getID then
        return
    end
    rollLockUntilById[player:getID()] = nil
    if player.setLocalVar then
        player:setLocalVar('OX_GMB_ROLL_LOCK', 0)
    end
end

local function clearRollAnte(player, abilityId)
    if player == nil or not player.getID then
        return
    end
    local cid = player:getID()
    if anteByCharRoll[cid] then
        anteByCharRoll[cid][abilityId] = nil
    end
end

local function addRollAnte(player, abilityId, hpCost, tpCost)
    if player == nil or not player.getID or not abilityId then
        return 0
    end
    local cid = player:getID()
    anteByCharRoll[cid] = anteByCharRoll[cid] or {}
    local entry = anteByCharRoll[cid][abilityId] or { count = 0, hp = 0, tp = 0 }
    entry.count = entry.count + 1
    entry.hp    = entry.hp + (hpCost or 0)
    entry.tp    = entry.tp + (tpCost or 0)
    anteByCharRoll[cid][abilityId] = entry
    return entry.count
end

local function consumeRollAnte(player, abilityId)
    if player == nil or not player.getID or not abilityId then
        return 0
    end
    local cid   = player:getID()
    local entry = anteByCharRoll[cid] and anteByCharRoll[cid][abilityId] or nil
    if anteByCharRoll[cid] then
        anteByCharRoll[cid][abilityId] = nil
    end
    return entry and entry.count or 0
end

local function triggerJackpotCashout(caster, abilityId)
    if caster == nil then
        return 0
    end
    local anteCount = consumeRollAnte(caster, abilityId)
    -- Jackpot cooldown reduction: 8s base, +2s per additional Ante, max 14s
    local cdr = math.min(14, 8 + 2 * math.max(0, anteCount - 1))
    if caster.setLocalVar then
        caster:setLocalVar('OX_GMB_LAST_CDR', cdr)
    end
    if caster.reduceAbilityRecasts then
        caster:reduceAbilityRecasts(cdr)
    end
    return cdr
end

xi.overlords = xi.overlords or {}
xi.overlords.cor = xi.overlords.cor or {}
function xi.overlords.cor.getGamblerHudState(player)
    if player == nil or not player.getID then
        return nil
    end
    local cid = player:getID()
    local activeRollId = player:getLocalVar('corsairActiveRoll') or 0
    local entry = anteByCharRoll[cid] and anteByCharRoll[cid][activeRollId] or nil
    if not entry and anteByCharRoll[cid] then
        for _, v in pairs(anteByCharRoll[cid]) do
            if v and (v.count or 0) > 0 then
                entry = v
                break
            end
        end
    end
    return {
        anteCount   = entry and entry.count or 0,
        anteHp      = entry and entry.hp or 0,
        anteTp      = entry and entry.tp or 0,
        rollLockRem = math.max(0, (rollLockUntilById[cid] or player:getLocalVar('OX_GMB_ROLL_LOCK') or 0) - os.time()),
        lastCdr     = player:getLocalVar('OX_GMB_LAST_CDR') or 0,
    }
end

local function forEachPartyMemberInRange(caster, range, fn)
    if caster == nil or type(fn) ~= 'function' then
        return
    end
    local seen = {}
    local function visit(member)
        if member == nil or not member.getID then
            return
        end
        local mid = member:getID()
        if seen[mid] then
            return
        end
        seen[mid] = true
        if member.isAlive and not member:isAlive() then
            return
        end
        if member:getID() == caster:getID() or (caster.checkDistance and caster:checkDistance(member) <= range) then
            fn(member)
        end
    end

    visit(caster)
    if caster.getPartyWithTrusts then
        for _, member in pairs(caster:getPartyWithTrusts() or {}) do
            visit(member)
        end
    elseif caster.getParty then
        for _, member in pairs(caster:getParty() or {}) do
            visit(member)
        end
    end
end

-----------------------------------
-- Custom Status Effect Hooks
-----------------------------------

m:addOverride('xi.effects.house_debt.onEffectGain', function(target, effect)
    effect:addMod(xi.mod.DEFP, -25)
    effect:addMod(xi.mod.REGAIN_DOWN, 9999)
    if target ~= nil and target.setLocalVar then
        target:setLocalVar('OX_GMB_NO_REGAIN', 1)
    end
end)

m:addOverride('xi.effects.house_debt.onEffectLose', function(target, _effect)
    if target ~= nil and target.setLocalVar then
        target:setLocalVar('OX_GMB_NO_REGAIN', 0)
    end
end)

m:addOverride('xi.effects.card_counting.onEffectGain', function(_target, _effect)
end)

m:addOverride('xi.effects.card_counting.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.house_advantage.onEffectGain', function(_target, _effect)
end)

m:addOverride('xi.effects.house_advantage.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Phantom Roll & Double-Up Overrides
-----------------------------------

m:addOverride('xi.job_utils.corsair.onRollAbilityCheck', function(player, target, ability)
    if isFlintlock(player) then
        ability:setRecast(15)
        return 0, 0
    end
    if isBuccaneer(player) then
        ability:setRecast(20)
        return 0, 0
    end
    if not isGambler(player) then
        return super(player, target, ability)
    end

    if player:hasStatusEffect(EFFECT_HOUSE_DEBT) or isRollLocked(player) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end

    local abilityId = ability:getID()
    local effectId  = xi.job_utils.corsair.rollData[abilityId].effect

    if player:hasStatusEffect(effectId) then
        return xi.msg.basic.ROLL_ALREADY_ACTIVE, 0
    elseif player:numBustEffects() >= 3 then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end

    return 0, 0
end)

m:addOverride('xi.job_utils.corsair.checkDoubleUp', function(player, target, ability)
    if not isGambler(player) then
        return super(player, target, ability)
    end

    if not player:hasStatusEffect(xi.effect.DOUBLE_UP_CHANCE) then
        return xi.msg.basic.NO_ELIGIBLE_ROLL, 0
    end

    if player:hasStatusEffect(EFFECT_HOUSE_DEBT) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end

    local hpCost = math.max(1, math.floor(player:getHP() * 0.10))
    if player:getHP() <= hpCost or player:getTP() < 150 then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end

    return 0, 0
end)

m:addOverride('xi.job_utils.corsair.onRollUseAbility', function(caster, target, ability, action)
    if isFlintlock(caster) then
        if action and action.setRecast then
            action:setRecast(15)
        end
        if caster:getID() == target:getID() then
            local roll = math.randomInt(1, 6)
            caster:setLocalVar('corsairRollTotal', roll)
            local wsBonus = scaleTier(caster:getMainLvl(), 15, 20, 25, 30)
            caster:delStatusEffectSilent(xi.effect.CORSAIRS_ROLL)
            caster:addStatusEffect(xi.effect.CORSAIRS_ROLL, {
                power    = wsBonus,
                duration = 30,
                origin   = caster,
            })
            caster:addMod(xi.mod.ALL_WSDMG_ALL_HITS, wsBonus)
            if xi.mod.RANGED_CRIT_DMG_INC then
                caster:addMod(xi.mod.RANGED_CRIT_DMG_INC, 15)
            end
            caster:timer(30000, function(mobArg)
                if mobArg and mobArg.delMod then
                    mobArg:delMod(xi.mod.ALL_WSDMG_ALL_HITS, wsBonus)
                    if xi.mod.RANGED_CRIT_DMG_INC then
                        mobArg:delMod(xi.mod.RANGED_CRIT_DMG_INC, 15)
                    end
                end
            end)
            ability:setMsg(xi.msg.basic.USES_JA)
            return roll
        end
        ability:setMsg(xi.msg.basic.NO_EFFECT)
        return 0
    end

    if isBuccaneer(caster) then
        if action and action.setRecast then
            action:setRecast(20)
        end
        if caster:getID() == target:getID() then
            caster:delStatusEffectSilent(xi.effect.GALLANTS_ROLL)
            caster:addStatusEffect(xi.effect.GALLANTS_ROLL, {
                power    = 12,
                duration = 60,
                origin   = caster,
            })
            caster:addMod(xi.mod.DMG, -1200)
            caster:addMod(xi.mod.DEFP, 20)
            caster:addMod(xi.mod.ENMITY, 25)
            caster:timer(60000, function(mobArg)
                if mobArg and mobArg.delMod then
                    mobArg:delMod(xi.mod.DMG, -1200)
                    mobArg:delMod(xi.mod.DEFP, 20)
                    mobArg:delMod(xi.mod.ENMITY, 25)
                end
            end)
            ability:setMsg(xi.msg.basic.USES_JA)
            return 1
        end
        ability:setMsg(xi.msg.basic.NO_EFFECT)
        return 0
    end

    if not isGambler(caster) then
        return super(caster, target, ability, action)
    end

    local abilityId = ability:getID()
    local rollInfo  = xi.job_utils.corsair.rollData[abilityId]
    local effectId  = rollInfo.effect
    local bonusJob  = rollInfo.bonusJob

    if caster:getID() == target:getID() then
        clearRollAnte(caster, abilityId)

        -- Run vanilla setup first, then enforce Gambler 12s CD & House Advantage
        local roll = math.randomInt(1, 6)
        local forcedEleven = caster:hasStatusEffect(EFFECT_HOUSE_ADVANTAGE)
        if forcedEleven then
            caster:delStatusEffectSilent(EFFECT_HOUSE_ADVANTAGE)
            roll = 11
        end

        caster:delStatusEffectSilent(xi.effect.DOUBLE_UP_CHANCE)
        if roll < 11 then
            caster:addStatusEffect(xi.effect.DOUBLE_UP_CHANCE, {
                power           = roll,
                duration        = 45,
                origin          = caster,
                subPower        = effectId,
                tier            = bonusJob,
                sourceType      = xi.effectSourceType.CORSAIR_ROLL,
                sourceTypeParam = abilityId,
                silent          = true,
            })
        end

        caster:setLocalVar('corsairRollTotal', roll)
        caster:setLocalVar('corsairDuEffect', effectId)
        action:info(caster:getID(), roll)
        action:setRecast(12)
        xi.job_utils.corsair.checkForJobBonus(caster, bonusJob)

        if roll == 11 then
            caster:resetRecast(xi.recast.ABILITY, xi.recastID.PHANTOM_ROLL)
            triggerJackpotCashout(caster, abilityId)
        elseif roll == getLuckyRoll(abilityId) then
            triggerJackpotCashout(caster, abilityId)
        end
    end

    return xi.job_utils.corsair.applyRoll(caster, target, ability, caster:getLocalVar('corsairRollTotal'), false, ability)
end)

m:addOverride('xi.job_utils.corsair.useDoubleUp', function(caster, target, ability, action)
    if not isGambler(caster) then
        return super(caster, target, ability, action)
    end

    if caster:getID() == target:getID() then
        local duEffect     = caster:getStatusEffect(xi.effect.DOUBLE_UP_CHANCE)
        local prevRoll     = caster:getStatusEffect(duEffect:getSubPower())
        local prevTotal    = prevRoll:getSubPower()
        local job          = duEffect:getTier()
        local activeRollId = duEffect:getSourceTypeParam()

        caster:setLocalVar('corsairActiveRoll', activeRollId)

        -- Every Double-Up wagers 10% of current HP and 150 TP (including forced XI)
        local hpCost = math.max(1, math.floor(caster:getHP() * 0.10))
        caster:delHP(hpCost)
        caster:delTP(150)
        addRollAnte(caster, activeRollId, hpCost, 150)

        local roll = prevTotal
        if caster:hasStatusEffect(EFFECT_HOUSE_ADVANTAGE) then
            caster:delStatusEffectSilent(EFFECT_HOUSE_ADVANTAGE)
            roll = 11
        else
            local cardCount = caster:getStatusEffect(EFFECT_CARD_COUNTING)
            local die
            if cardCount then
                local mode = cardCount:getPower()
                if mode == CARD_COUNT_FIRE_LIGHT then
                    die = math.randomInt(3, 6)
                elseif mode == CARD_COUNT_ICE_WATER then
                    die = math.randomInt(1, 3)
                else
                    die = math.randomInt(1, 6)
                end
                caster:delStatusEffectSilent(EFFECT_CARD_COUNTING)
            else
                die = math.randomInt(1, 6)
            end

            roll = prevTotal + die

            local snakeEye = caster:getStatusEffect(xi.effect.SNAKE_EYE)
            if snakeEye then
                caster:delStatusEffect(xi.effect.SNAKE_EYE)
                -- Snake Eye guarantees no bust, does not guarantee Lucky/XI
                roll = math.min(11, roll)
            end
        end

        if roll >= 12 then
            roll = 12
            caster:delStatusEffectSilent(xi.effect.DOUBLE_UP_CHANCE)

            -- Debt Collector: forfeit Ante, 25% Max HP nonlethal backlash, House Debt (12s), 15s roll lock
            clearRollAnte(caster, activeRollId)
            local backlash = math.floor(caster:getMaxHP() * 0.25)
            local actualDmg = math.min(backlash, math.max(0, caster:getHP() - 1))
            if actualDmg > 0 then
                caster:delHP(actualDmg)
            end

            caster:delStatusEffectSilent(EFFECT_HOUSE_DEBT)
            caster:addStatusEffect(EFFECT_HOUSE_DEBT, {
                power    = 25,
                duration = 12,
                origin   = caster,
                icon     = xi.effect.BUST,
            })
            setRollLock(caster, 15)
        elseif roll == 11 then
            caster:delStatusEffectSilent(xi.effect.DOUBLE_UP_CHANCE)
            caster:resetRecast(xi.recast.ABILITY, xi.recastID.PHANTOM_ROLL)
            triggerJackpotCashout(caster, activeRollId)
        elseif roll == getLuckyRoll(activeRollId) then
            triggerJackpotCashout(caster, activeRollId)
        end

        caster:setLocalVar('corsairRollTotal', roll)
        action:info(caster:getID(), roll - prevTotal)
        xi.job_utils.corsair.checkForJobBonus(caster, job)
    end

    local total       = caster:getLocalVar('corsairRollTotal')
    local activeRoll  = caster:getLocalVar('corsairActiveRoll')
    local prevAbility = GetAbility(activeRoll)

    if prevAbility then
        action:actionID(prevAbility:getID())
        total = xi.job_utils.corsair.applyRoll(caster, target, prevAbility, total, true, ability)

        if total > 11 then
            action:setAnimation(target:getID(), 98)
        else
            action:setAnimation(target:getID(), prevAbility:getAnimation())
        end

        return total
    end
end)

m:addOverride('xi.job_utils.corsair.applyRoll', function(caster, target, inAbility, total, isDoubleup, currentAbility)
    if not isGambler(caster) then
        return super(caster, target, inAbility, total, isDoubleup, currentAbility)
    end

    local abilityId = inAbility:getID()
    local rollInfo  = xi.job_utils.corsair.rollData[abilityId]
    if not rollInfo then
        return 0
    end

    local effectId = rollInfo.effect
    local effect   = target:getStatusEffect(effectId)

    if
        effect and
        caster:getID() ~= target:getID() and
        caster:getID() ~= effect:getSourceTypeParam()
    then
        currentAbility:setMsg(xi.msg.basic.NO_EFFECT)
        return 0
    end

    -- Busts never remove or weaken the existing baseline party buff for Gambler
    if total > 11 then
        if caster:getID() == target:getID() then
            currentAbility:setMsg(xi.msg.basic.DOUBLEUP_BUST)
        else
            currentAbility:setMsg(xi.msg.basic.DOUBLEUP_BUST_SUB)
        end
        return total
    end

    -- Safe Standing: guaranteed minimum party potency equivalent to conventional Roll 8-9
    local pTotal = rollInfo.powers[total] or 0
    local p8     = rollInfo.powers[8] or 0
    local p9     = rollInfo.powers[9] or 0
    local safePower = (math.abs(p8) >= math.abs(p9)) and p8 or p9
    local effectpower = pTotal
    if total <= 10 then
        effectpower = (math.abs(pTotal) >= math.abs(safePower)) and pTotal or safePower
    end

    -- Job bonus & Phantom Roll+ gear
    if caster:getLocalVar('corsairRollBonus') == 1 then
        effectpower = effectpower + rollInfo.bonus
    end

    local phantomMult = caster:getMaxGearMod(xi.mod.PHANTOM_ROLL)
    effectpower = effectpower + rollInfo.phantomBase * phantomMult

    local actorLevel  = utils.getActiveJobLevel(caster, xi.job.COR)
    local targetLevel = target:getMainLvl()
    if actorLevel < targetLevel then
        effectpower = math.ceil(effectpower * actorLevel / targetLevel)
    end

    -- Lucky and XI (11) trigger 150% Overdrive potency (upgrades in-place, never multiplicative)
    if abilityId ~= xi.jobAbility.COMPANIONS_ROLL then
        if total == getLuckyRoll(abilityId) or total == 11 then
            effectpower = math.floor(effectpower * 1.5)
        end
    end

    caster:setLocalVar('corsairApplyingRoll', 1)

    -- Apply or upgrade roll with 3-roll cap
    local sourceTypeParam = caster:getID()
    local numOfEffects    = 0
    local oldestRoll      = nil
    local oldestExpiry    = nil
    local upgradeEffect   = nil

    for _, eff in pairs(target:getStatusEffects()) do
        local selectedID   = eff:getEffectType()
        local isFromCaster = eff:getSourceTypeParam() == sourceTypeParam

        if isFromCaster and selectedID == effectId then
            upgradeEffect = eff
            break
        end

        if isFromCaster and eff:hasEffectFlag(xi.effectFlag.ROLL) then
            numOfEffects = numOfEffects + 1
            local effectExpiry = eff:getStartTime() + eff:getDuration() / 1000
            if not oldestRoll or effectExpiry < oldestExpiry then
                oldestRoll   = eff
                oldestExpiry = effectExpiry
            end
        end
    end

    local addDuration = 300 + caster:getMerit(xi.merit.WINNING_STREAK) + caster:getMod(xi.mod.PHANTOM_DURATION) + caster:getJobPointLevel(xi.jp.PHANTOM_ROLL_DURATION) * 2
    local addSlot     = nil
    local addSilent   = true

    if upgradeEffect then
        target:delStatusEffectSilent(effectId)
        addSlot = upgradeEffect:getEffectSlot()
    elseif numOfEffects < 3 then
        addSlot = utils.getLowestFreeSlot(target)
    elseif oldestRoll then
        target:delStatusEffect(oldestRoll:getEffectType())
        addSlot   = oldestRoll:getEffectSlot()
        addSilent = false
    else
        caster:setLocalVar('corsairApplyingRoll', 0)
        currentAbility:setMsg(xi.msg.basic.NO_EFFECT)
        return 0
    end

    local ok = target:addStatusEffect(effectId, {
        power           = effectpower,
        duration        = addDuration,
        subPower        = total,
        sourceType      = xi.effectSourceType.CORSAIR_ROLL,
        sourceTypeParam = sourceTypeParam,
        origin          = caster,
        silent          = addSilent,
        slot            = addSlot,
    })

    if not ok then
        currentAbility:setMsg(caster:getID() == target:getID() and xi.msg.basic.ROLL_MAIN_FAIL or xi.msg.basic.NO_EFFECT)
    else
        if caster:getID() == target:getID() then
            currentAbility:setMsg(isDoubleup and xi.msg.basic.DOUBLEUP or xi.msg.basic.ROLL_MAIN)
        else
            currentAbility:setMsg(xi.msg.basic.ROLL_SUB)
        end
    end

    caster:setLocalVar('corsairApplyingRoll', 0)
    return total
end)

-----------------------------------
-- Fold, Snake Eye, Quick Draw, Random Deal, Wild Card
-----------------------------------

m:addOverride('xi.job_utils.corsair.checkFold', function(player)
    if not isGambler(player) then
        return super(player)
    end

    if player:hasStatusEffect(EFFECT_HOUSE_DEBT) or isRollLocked(player) then
        return 0, 0
    end

    return super(player)
end)

m:addOverride('xi.job_utils.corsair.useFold', function(player, action)
    if not isGambler(player) then
        return super(player, action)
    end

    if action and action.setRecast then
        action:setRecast(20)
    end

    if player:hasStatusEffect(EFFECT_HOUSE_DEBT) or isRollLocked(player) then
        player:delStatusEffectSilent(EFFECT_HOUSE_DEBT)
        clearRollLock(player)
        return xi.msg.basic.NONE
    end

    return super(player, action)
end)

m:addOverride('xi.job_utils.corsair.useSnakeEye', function(player, action)
    if not isGambler(player) then
        return super(player, action)
    end

    if action and action.setRecast then
        action:setRecast(20)
    end

    player:addStatusEffect(xi.effect.SNAKE_EYE, { power = 100, duration = 60, origin = player })
    return xi.effect.SNAKE_EYE
end)

m:addOverride('xi.job_utils.corsair.checkQuickDraw', function(player, target, ability)
    if isAnyCorSpec(player) then
        if target == nil or not target.isAlive or not target:isAlive() then
            return xi.msg.basic.CANNOT_PERFORM, 0
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.corsair.useElementalShot', function(actor, target, ability, action)
    if not isAnyCorSpec(actor) then
        return super(actor, target, ability, action)
    end

    local abilityId = ability:getID()
    local data      = xi.job_utils.corsair.quickDrawDataTable[abilityId]

    -- Track card to enforce 100% Card recycle (and bypass missing Trump Cards)
    local consumedCardId = nil
    local addedTempCard  = false
    if data then
        if actor:hasItem(data.cardAmmo, xi.inventoryLocation.INVENTORY) then
            consumedCardId = data.cardAmmo
        elseif actor:hasItem(xi.item.TRUMP_CARD, xi.inventoryLocation.INVENTORY) then
            consumedCardId = xi.item.TRUMP_CARD
        elseif actor.addItem then
            actor:addItem(xi.item.TRUMP_CARD, 1)
            consumedCardId = xi.item.TRUMP_CARD
            addedTempCard  = true
        end
    end

    local result = super(actor, target, ability, action)

    -- Restore consumed card (100% Card recycle)
    if consumedCardId ~= nil and not addedTempCard then
        actor:addItem(consumedCardId, 1)
    end

    if isFlintlock(actor) then
        if action and action.setRecast then
            action:setRecast(10)
        end
        if target ~= nil and target.isAlive and target:isAlive() then
            target:setLocalVar('OX_COR_POWDER_MARK', os.time() + 10)
            target:setLocalVar('OX_COR_POWDER_BY', actor:getID())
            target:setLocalVar('OX_COR_POWDER_ELEM', data and data.element or xi.element.FIRE)
        end
        return result
    end

    if isBuccaneer(actor) then
        if action and action.setRecast then
            action:setRecast(12)
        end
        if target ~= nil and target.isAlive and target:isAlive() then
            if target.addEnmity then
                target:addEnmity(actor, 450, 1800)
            end
            local stacks = math.min(3, actor:getLocalVar('OX_COR_GRAPESHOT') or 0)
            if stacks > 0 and (actor:getLocalVar('OX_COR_GRAPESHOT_EXP') or 0) >= os.time() then
                actor:setLocalVar('OX_COR_GRAPESHOT', 0)
                local shield = math.max(1, math.floor((actor:getMaxHP() or 0) * 0.06 * stacks))
                actor:setLocalVar('OX_COR_SALTSPRAY', shield)
                actor:setLocalVar('OX_COR_SALTSPRAY_EXP', os.time() + 12)
            end
            if abilityId == ABIL_EARTH_SHOT or abilityId == ABIL_WATER_SHOT then
                slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, 15, 15, actor,
                {
                    { xi.mod.ATTP, -15 },
                    { xi.mod.MATT, -15 },
                    { xi.mod.ACC,  -20 },
                }, slots.EFF_OX_DEB_CRIPPLE)
            elseif abilityId == ABIL_ICE_SHOT then
                target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = actor })
            elseif abilityId == ABIL_LIGHT_SHOT or abilityId == ABIL_DARK_SHOT then
                if target.dispelStatusEffect then
                    target:dispelStatusEffect()
                end
            end
        end
        return result
    end

    -- Gambler: 12s charge recast, -3s Random Deal shave, Expose, Card Counting
    if action and action.setRecast then
        action:setRecast(12)
    end
    if actor.reduceAbilityRecasts then
        -- Shave Random Deal / standard JAs by 3s on Quick Draw
        local rdRecast = actor:getRecast(xi.recast.ABILITY, 193) or 0
        if rdRecast > 0 and actor.resetRecast then
            -- Fallback: reduceAbilityRecasts shaves standard JAs
            actor:reduceAbilityRecasts(3)
        end
    end

    -- Apply shared EFF_OX_DEB_EXPOSE (-15% Critical Hit Evasion, -30 MEVA, 15s)
    if target ~= nil and target.isAlive and target:isAlive() then
        slots.applySlot(target, slots.EFF_OX_DEB_EXPOSE, 30, 15, actor,
        {
            { xi.mod.CRITICAL_HIT_EVASION, -15 },
            { xi.mod.MEVA,                 -30 },
        }, slots.EFF_OX_DEB_EXPOSE)
    end

    -- Elemental deck manipulation (replaces previous, expires in 10s if unused)
    if abilityId == ABIL_FIRE_SHOT or abilityId == ABIL_LIGHT_SHOT then
        actor:delStatusEffectSilent(EFFECT_CARD_COUNTING)
        actor:addStatusEffect(EFFECT_CARD_COUNTING, {
            power    = CARD_COUNT_FIRE_LIGHT,
            duration = 10,
            origin   = actor,
            icon     = xi.effect.FIRE_SHOT or xi.effect.DOUBLE_UP_CHANCE,
        })
    elseif abilityId == ABIL_ICE_SHOT or abilityId == ABIL_WATER_SHOT then
        actor:delStatusEffectSilent(EFFECT_CARD_COUNTING)
        actor:addStatusEffect(EFFECT_CARD_COUNTING, {
            power    = CARD_COUNT_ICE_WATER,
            duration = 10,
            origin   = actor,
            icon     = xi.effect.ICE_SHOT or xi.effect.DOUBLE_UP_CHANCE,
        })
    end

    return result
end)

m:addOverride('xi.actions.abilities.random_deal.onAbilityCheck', function(player, target, ability)
    if isGambler(player) then
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.random_deal.onUseAbility', function(caster, target, ability, action)
    if not isGambler(caster) then
        return super(caster, target, ability, action)
    end

    if action and action.setRecast then
        action:setRecast(35)
    end

    if caster:getID() == target:getID() then
        forEachPartyMemberInRange(caster, 15, function(member)
            if member.reduceAbilityRecasts then
                member:reduceAbilityRecasts(12)
            end
        end)
    end

    ability:setMsg(xi.msg.basic.USES_JA)
    return 0
end)

m:addOverride('xi.job_utils.corsair.useWildCard', function(caster, target, ability, action)
    if isFlintlock(caster) then
        if action and action.setRecast then
            action:setRecast(180)
        end
        if caster:getID() == target:getID() then
            if caster.resetStandardAbilities then
                caster:resetStandardAbilities()
            end
            if caster.restoreAbilityCharge then
                caster:restoreAbilityCharge(xi.recast.ABILITY, xi.recast.Quickdraw or 195, 2)
            end
            if caster.addTP then
                caster:addTP(1000)
            end
        end
        ability:setMsg(xi.msg.basic.USES_JA)
        return 6
    end

    if not isGambler(caster) then
        return super(caster, target, ability, action)
    end

    if action and action.setRecast then
        action:setRecast(180)
    end

    if caster:getID() == target:getID() then
        local roll = math.randomInt(1, 6)
        caster:setLocalVar('corsairRollTotal', roll)
        action:info(caster:getID(), roll)

        forEachPartyMemberInRange(caster, 15, function(member)
            local mpGain = math.floor((member:getMaxMP() or 0) * 0.30)
            if mpGain > 0 and member.addMP then
                member:addMP(mpGain)
            end
            if member.addTP then
                member:addTP(400)
            end
            if member.resetStandardAbilities then
                member:resetStandardAbilities()
            end
            if roll >= 5 then
                slots.applySlot(member, slots.EFF_OX_SUP_CHAIN, 30, 20, caster,
                {
                    { xi.mod.SKILLCHAINDMG,              3000 },
                    { xi.mod.MAGIC_BURST_BONUS_UNCAPPED,   30 },
                }, slots.EFF_OX_SUP_CHAIN)
            end
        end)
    end

    local total = caster:getLocalVar('corsairRollTotal')
    ability:setMsg(xi.msg.basic.WILD_CARD_BASE + math.floor((total - 1) / 2) * 2)
    action:setAnimation(target:getID(), 132 + total - 1)
    return total
end)

-----------------------------------
-- Crystal Job Abilities
-----------------------------------

m:addOverride('xi.actions.abilities.house_advantage.onAbilityCheck', function(player, _target, _ability)
    if not isGambler(player) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.house_advantage.onUseAbility', function(caster, target, ability, action)
    if not isGambler(caster) then
        return 0
    end

    if action and action.setRecast then
        action:setRecast(30)
    end

    if caster:getID() == target:getID() then
        caster:delStatusEffectSilent(EFFECT_HOUSE_ADVANTAGE)
        caster:addStatusEffect(EFFECT_HOUSE_ADVANTAGE, {
            power    = 1,
            duration = 30,
            origin   = caster,
            icon     = xi.effect.SNAKE_EYE,
        })

        forEachPartyMemberInRange(caster, 15, function(member)
            slots.applySlot(member, slots.EFF_OX_SUP_OFFENSE, 18, 15, caster,
            {
                { xi.mod.ATTP,  18 },
                { xi.mod.RATTP, 18 },
                { xi.mod.MATT,  18 },
            }, slots.EFF_OX_SUP_OFFENSE)
        end)
    end

    ability:setMsg(xi.msg.basic.USES_JA)
    return 0
end)

m:addOverride('xi.actions.abilities.dead_mans_hand.onAbilityCheck', function(player, target, _ability)
    if not isGambler(player) or target == nil or not target.isAlive or not target:isAlive() then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    if player.checkDistance and player:checkDistance(target) > 20 then
        return xi.msg.basic.TOO_FAR_AWAY, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.dead_mans_hand.onUseAbility', function(caster, target, ability, action)
    if not isGambler(caster) then
        return 0
    end

    if action and action.setRecast then
        action:setRecast(35)
    end

    -- Strictly single-target enemy dispel + Breach
    if target ~= nil and target.isAlive and target:isAlive() then
        if target.dispelStatusEffect then
            target:dispelStatusEffect()
            target:dispelStatusEffect()
        end

        slots.applySlot(target, slots.EFF_OX_DEB_BREACH, 20, 15, caster,
        {
            { xi.mod.DEFP, -20 },
            { xi.mod.MDEF, -20 },
        }, slots.EFF_OX_DEB_BREACH)
    end

    local hasLuckyOrEleven = caster:getLocalVar('OX_GMB_LUCKY_ACTIVE') == 1
    forEachPartyMemberInRange(caster, 15, function(member)
        if member.reduceAbilityRecasts then
            member:reduceAbilityRecasts(10)
        end
        if hasLuckyOrEleven and member.addTP then
            member:addTP(200)
        end
    end)

    ability:setMsg(xi.msg.basic.USES_JA)
    return 0
end)

-- Flintlock Crystal JAs: Hair Trigger (474) & Broadside Salvo (475)
m:addOverride('xi.actions.abilities.hair_trigger.onAbilityCheck', function(player, _target, _ability)
    if not isFlintlock(player) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.hair_trigger.onUseAbility', function(caster, _target, ability, action)
    if not isFlintlock(caster) then
        return 0
    end
    if action and action.setRecast then
        action:setRecast(30)
    end
    caster:setLocalVar('OX_COR_HAIR_TRIGGER_EXP', os.time() + 10)
    caster:delStatusEffectSilent(xi.effect.TRIPLE_SHOT)
    caster:addStatusEffect(xi.effect.TRIPLE_SHOT, { power = 30, duration = 10, origin = caster })
    caster:addMod(xi.mod.SNAPSHOT, 30)
    caster:addMod(xi.mod.ALL_WSDMG_ALL_HITS, 25)
    caster:addMod(xi.mod.DEFP, -15)
    caster:timer(10000, function(mobArg)
        if mobArg and mobArg.delMod then
            mobArg:delMod(xi.mod.SNAPSHOT, 30)
            mobArg:delMod(xi.mod.ALL_WSDMG_ALL_HITS, 25)
            mobArg:delMod(xi.mod.DEFP, -15)
        end
    end)
    ability:setMsg(xi.msg.basic.USES_JA)
    return 0
end)

m:addOverride('xi.actions.abilities.broadside_salvo.onAbilityCheck', function(player, target, _ability)
    if not isFlintlock(player) or not hasGunEquipped(player) or target == nil or not target.isAlive or not target:isAlive() then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    if player.checkDistance and player:checkDistance(target) > 20 then
        return xi.msg.basic.TOO_FAR_AWAY, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.broadside_salvo.onUseAbility', function(caster, target, ability, action)
    if not isFlintlock(caster) or target == nil or not target:isAlive() then
        return 0
    end
    if action and action.setRecast then
        action:setRecast(22)
    end
    local gunDmg = math.max(10, caster:getRangedDmg())
    local agi    = caster:getStat(xi.mod.AGI)
    local mult   = 2.0 + math.min(1.2, (caster:getMainLvl() - 10) / 65 * 1.2)
    local dmg    = math.max(1, math.floor((gunDmg + agi) * mult))
    dmg = utils.handleStoneskin(target, dmg, xi.attackType.RANGED)
    target:takeDamage(dmg, caster, xi.attackType.RANGED, xi.damageType.PIERCING)
    target:updateEnmityFromDamage(caster, dmg)
    if caster.addTP then
        caster:addTP(250)
    end
    if caster.restoreAbilityCharge then
        caster:restoreAbilityCharge(xi.recast.ABILITY, xi.recast.Quickdraw or 195, 1)
    end
    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return dmg
end)

-- Buccaneer Crystal JAs: Grapeshot Broadside (476, Single-Target Enemy 12y) & Iron Hull (477, Self 12s)
m:addOverride('xi.actions.abilities.grapeshot_broadside.onAbilityCheck', function(player, target, _ability)
    if not isBuccaneerLoadout(player) or target == nil or not target.isAlive or not target:isAlive() then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    if player.checkDistance and player:checkDistance(target) > 12 then
        return xi.msg.basic.TOO_FAR_AWAY, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.grapeshot_broadside.onUseAbility', function(caster, target, ability, action)
    if not isBuccaneer(caster) or target == nil or not target:isAlive() then
        return 0
    end
    if action and action.setRecast then
        action:setRecast(25)
    end
    if target.addEnmity then
        target:addEnmity(caster, 450, 1600)
    end
    target:addStatusEffect(xi.effect.BLINDNESS, { power = 20, duration = 12, origin = caster })
    target:addStatusEffect(xi.effect.SLOW, { power = 2000, duration = 12, origin = caster })
    local stacks = math.min(3, (caster:getLocalVar('OX_COR_GRAPESHOT') or 0) + 2)
    caster:setLocalVar('OX_COR_GRAPESHOT', stacks)
    caster:setLocalVar('OX_COR_GRAPESHOT_EXP', os.time() + 30)
    ability:setMsg(xi.msg.basic.USES_JA)
    return 0
end)

m:addOverride('xi.actions.abilities.iron_hull.onAbilityCheck', function(player, _target, _ability)
    if not isBuccaneer(player) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.iron_hull.onUseAbility', function(caster, _target, ability, action)
    if not isBuccaneer(caster) then
        return 0
    end
    if action and action.setRecast then
        action:setRecast(45)
    end
    local maxHp = caster:getMaxHP() or 0
    local heal  = math.max(1, math.floor(maxHp * 0.20))
    local missing = math.max(0, maxHp - (caster:getHP() or 0))
    if missing > 0 then
        caster:restoreHP(math.min(heal, missing))
    end
    if caster.eraseStatusEffect then
        caster:eraseStatusEffect()
    end
    caster:addMod(xi.mod.DMG, -1800)
    caster:addMod(xi.mod.KNOCKBACK_REDUCTION, 100)
    caster:timer(12000, function(mobArg)
        if mobArg and mobArg.delMod then
            mobArg:delMod(xi.mod.DMG, -1800)
            mobArg:delMod(xi.mod.KNOCKBACK_REDUCTION, 100)
        end
    end)
    ability:setMsg(xi.msg.basic.USES_JA)
    return 0
end)

-----------------------------------
-- Global C++ Hook & WS Listeners (Flintlock Powder Mark & Buccaneer Point-Blank Pistol)
-----------------------------------
xi.overlords = xi.overlords or {}

local prevCorPreTakeDamage = xi.overlords.onPreTakeDamage
xi.overlords.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if prevCorPreTakeDamage then
        amount = prevCorPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    if defender == nil or amount <= 0 or not isBuccaneerLoadout(defender) then
        return amount
    end

    -- 12% virtual Pistol-Guard block fallback when SUB is empty
    if defender.getEquippedItem and defender:getEquippedItem(xi.slot.SUB) == nil then
        if attackType == xi.attackType.PHYSICAL and math.random(1, 100) <= 12 then
            amount = math.max(1, math.floor(amount * 0.65))
        end
    end

    -- Salt-Spray Stoneskin absorption
    if defender.getLocalVar then
        local shield = defender:getLocalVar('OX_COR_SALTSPRAY') or 0
        local exp    = defender:getLocalVar('OX_COR_SALTSPRAY_EXP') or 0
        if shield > 0 and exp >= os.time() then
            local absorbed = math.min(amount, shield)
            defender:setLocalVar('OX_COR_SALTSPRAY', shield - absorbed)
            amount = amount - absorbed
        elseif shield > 0 then
            defender:setLocalVar('OX_COR_SALTSPRAY', 0)
        end
    end

    return amount
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player == nil or not player:isPC() then
        return
    end

    ensureCorStarterGear(player)

    player:removeListener('OX_COR_WS')
    player:addListener('WEAPONSKILL_USE', 'OX_COR_WS', function(actor, target, wsId)
        if actor == nil or target == nil or not target.isAlive or not target:isAlive() then
            return
        end

        local wsEntry = xi.data and xi.data.weaponskill and xi.data.weaponskill[wsId]

        -- Flintlock: Marksmanship WS consumes Powder Mark for +20% elemental bonus dmg + 150 TP (single-target)
        if isFlintlock(actor) and hasGunEquipped(actor) then
            local isMarksmanshipWs = (wsEntry ~= nil and wsEntry.skill == xi.skill.MARKSMANSHIP) or (wsEntry == nil and wsId >= 208 and wsId <= 223)
            if isMarksmanshipWs then
                local exp = target:getLocalVar('OX_COR_POWDER_MARK') or 0
                local by  = target:getLocalVar('OX_COR_POWDER_BY') or 0
                if exp >= os.time() and by == actor:getID() then
                    target:setLocalVar('OX_COR_POWDER_MARK', 0)
                    local bonusDmg = math.max(1, math.floor((actor:getRangedDmg() + actor:getStat(xi.mod.AGI)) * 1.25))
                    target:takeDamage(bonusDmg, actor, xi.attackType.MAGICAL, xi.damageType.FIRE)
                    if actor.addTP then
                        actor:addTP(150)
                    end
                end
            end
            return
        end

        -- Buccaneer: 1H Sword WS fires strictly single-target Point-Blank Pistol blast + heal + Grapeshot
        if isBuccaneerLoadout(actor) then
            local isSwordWs = (wsEntry ~= nil and wsEntry.skill == xi.skill.SWORD) or (wsEntry == nil and wsId >= 32 and wsId <= 47)
            if isSwordWs then
                if target.addEnmity then
                    target:addEnmity(actor, 320, 1200)
                end
                local pct   = scaleTier(actor:getMainLvl(), 8, 10, 12, 14)
                local maxHp = actor:getMaxHP() or 0
                local heal  = math.max(1, math.floor(maxHp * pct / 100))
                local miss  = math.max(0, maxHp - (actor:getHP() or 0))
                if miss > 0 then
                    actor:restoreHP(math.min(heal, miss))
                end
                local stacks = math.min(3, (actor:getLocalVar('OX_COR_GRAPESHOT') or 0) + 1)
                actor:setLocalVar('OX_COR_GRAPESHOT', stacks)
                actor:setLocalVar('OX_COR_GRAPESHOT_EXP', os.time() + 30)
            end
        end
    end)
end)

-----------------------------------
-- Job Crystal Registration (COR - Flintlock, Gambler, Buccaneer)
-----------------------------------
if xi.job and xi.job.COR then
    spec.registerCrystal(xi.job.COR,
    {
        id             = 1,
        key            = FLINTLOCK_KEY,
        name           = 'Flintlock',
        abr            = 'FLT',
        role           = 'Damage',
        icon           = 'flintlock',
        reqLevel       = 10,
        extraTraits    = { TRAIT_FLINTLOCK_DEADEYE },
        extraAbilities =
        {
            ABIL_PHANTOM_ROLL,
            ABIL_FIRE_SHOT,
            ABIL_ICE_SHOT,
            ABIL_WIND_SHOT,
            ABIL_EARTH_SHOT,
            ABIL_THUNDER_SHOT,
            ABIL_WATER_SHOT,
            ABIL_LIGHT_SHOT,
            ABIL_DARK_SHOT,
            ABIL_HAIR_TRIGGER,
            ABIL_BROADSIDE_SALVO,
        },
        description    = 'Tier 1 Pure Damage Corsair spec (Lv10+): Deadeye Chamber, Powder Mark Quick Draw detonations, zero self-healing, and 100% Bullet/Card recycle.',
        highlights     =
        {
            'Passives (Lv10/30/50/70+, Gun): +15/22/30/40% R.Atk & M.Atk, +20/30/40/50% Snapshot & Rapid Shot, +10/14/18/22% Ranged Crit, +15/25/35/50 Marksmanship, -15/20/25/35 Enmity.',
            'Deadeye Chamber (Phantom Roll, 15s CD, self-only): +15/20/25/30% Ranged/Magic WS DMG & +15% Ranged Crit DMG for 30s.',
            'Powder Mark (Quick Draw, 10s charge, 2 charges): marks target for 10s; Marksmanship WS detonates +20% elemental dmg & refunds +150 TP.',
            'Crystal JAs: Hair Trigger (30s CD, +30% Snapshot & +25% WS DMG / -15% DEF), Broadside Salvo (22s CD, 20y single-target 2.0-3.2x shot, +250 TP, +1 QD charge).',
        },
        mods = function(player, lvl)
            local mods =
            {
                { xi.mod.RECYCLE, 100 },
                { xi.mod.ENMITY,  -scaleTier(lvl, 15, 20, 25, 35) },
            }
            if hasGunEquipped(player) then
                table.insert(mods, { xi.mod.RATTP,        scaleTier(lvl, 15, 22, 30, 40) })
                table.insert(mods, { xi.mod.MATT,         scaleTier(lvl, 15, 22, 30, 40) })
                table.insert(mods, { xi.mod.SNAPSHOT,     scaleTier(lvl, 20, 30, 40, 50) })
                table.insert(mods, { xi.mod.RAPID_SHOT,   scaleTier(lvl, 20, 30, 40, 50) })
                table.insert(mods, { xi.mod.CRITHITRATE,  scaleTier(lvl, 10, 14, 18, 22) })
                table.insert(mods, { xi.mod.MARKSMANSHIP, scaleTier(lvl, 15, 25, 35, 50) })
            end
            return mods
        end,
        onApply = function(player)
            ensureCorStarterGear(player)
        end,
    })

    spec.registerCrystal(xi.job.COR,
    {
        id             = 2,
        key            = GAMBLER_KEY,
        name           = 'Gambler',
        abr            = 'GMB',
        role           = 'Support',
        icon           = 'gambler',
        reqLevel       = 10,
        extraTraits    = { TRAIT_HIGH_ROLLER_STAKES },
        extraAbilities =
        {
            ABIL_FIRE_SHOT,
            ABIL_ICE_SHOT,
            ABIL_WIND_SHOT,
            ABIL_EARTH_SHOT,
            ABIL_THUNDER_SHOT,
            ABIL_WATER_SHOT,
            ABIL_LIGHT_SHOT,
            ABIL_DARK_SHOT,
            ABIL_RANDOM_DEAL,
            ABIL_SNAKE_EYE,
            ABIL_FOLD,
            ABIL_HOUSE_ADVANTAGE,
            ABIL_DEAD_MANS_HAND,
        },
        description    = 'Tier 3 Pure Support Corsair spec (Lv10+): High-Roller Stakes with Safe Standing (Roll 8-9 floor), 150% Overdrive on Lucky/XI, 3 active rolls, Card Counting Quick Draw, and 100% Bullet/Card recycle.',
        highlights     =
        {
            'Passives (Lv10/30/50/70+): +12/16/20/25% HP/MP, +12/18/24/32 AGI/CHR, +25/35/45/55% Roll Potency & +50% Duration, 3 active rolls, -20/25/30/40 Enmity.',
            'High-Roller Stakes: Rolls 1-10 have Roll 8-9 Safe Standing; Lucky & XI clear Bust and pulse +150 TP & +8% MP (15y).',
            'Random Deal (35s CD, 15y) shaves -12s off standard party JAs (excludes 1hrs/Wild Card/Random Deal/Dead Man\'s Hand); Quick Draw shaves -3s & applies Expose.',
            'Crystal JAs: House Advantage (30s CD, forced XI + 15y Offense), Dead Man\'s Hand (35s CD, single-target 2x Dispel + Breach, -10s party JAs, +200 TP on Lucky/XI).',
        },
        mods = function(_player, lvl)
            local stat = scaleTier(lvl, 12, 18, 24, 32)
            local hpMp = scaleTier(lvl, 12, 16, 20, 25)
            return
            {
                { xi.mod.RECYCLE,      100 },
                { xi.mod.HPP,          hpMp },
                { xi.mod.MPP,          hpMp },
                { xi.mod.AGI,          stat },
                { xi.mod.CHR,          stat },
                { xi.mod.ENMITY,       -scaleTier(lvl, 20, 25, 30, 40) },
                { xi.mod.MARKSMANSHIP, scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.DAGGER,       scaleTier(lvl, 15, 25, 35, 50) },
            }
        end,
        onApply = function(player)
            ensureCorStarterGear(player)
            if player ~= nil and player.setLocalVar then
                player:setLocalVar('OX_COR_GAMBLER', 1)
            end
        end,
        onRemove = function(player)
            if player ~= nil and player.getID then
                local cid = player:getID()
                anteByCharRoll[cid]    = nil
                rollLockUntilById[cid] = nil
            end
            if player ~= nil and player.setLocalVar then
                player:setLocalVar('OX_COR_GAMBLER', 0)
                player:setLocalVar('OX_GMB_NO_REGAIN', 0)
                player:setLocalVar('OX_GMB_ROLL_LOCK', 0)
            end
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_HOUSE_DEBT)
                player:delStatusEffectSilent(EFFECT_CARD_COUNTING)
                player:delStatusEffectSilent(EFFECT_HOUSE_ADVANTAGE)
            end
        end,
    })

    spec.registerCrystal(xi.job.COR,
    {
        id             = 3,
        key            = BUCCANEER_KEY,
        name           = 'Buccaneer',
        abr            = 'BUC',
        role           = 'Tank',
        icon           = 'buccaneer',
        reqLevel       = 10,
        extraTraits    = { TRAIT_BUCCANEER_BULWARK },
        extraAbilities =
        {
            ABIL_PHANTOM_ROLL,
            ABIL_FIRE_SHOT,
            ABIL_ICE_SHOT,
            ABIL_WIND_SHOT,
            ABIL_EARTH_SHOT,
            ABIL_THUNDER_SHOT,
            ABIL_WATER_SHOT,
            ABIL_LIGHT_SHOT,
            ABIL_DARK_SHOT,
            ABIL_GRAPESHOT_BROADSIDE,
            ABIL_IRON_HULL,
        },
        description    = 'Tier 6 Pure Tank Corsair spec (Lv10+): requires 1H Sword + Gun (optional Buckler or 12% Pistol-Guard block), single-target Point-Blank Pistol WSs, Salt-Spray Stoneskin, and 100% Bullet/Card recycle.',
        highlights     =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/26% Max HP, +8/14/20/26 VIT/AGI, +12/18/24/30% DEF, -8/11/14/18% DT, +12/16/20/24% Parry, +60/80/100/120 Enmity & +25..60% Retention.',
            'Galleon\'s Roll (20s CD, self-only): -12% DT, +20% DEF, +25 Enmity for 60s.',
            'Point-Blank Pistol (1H Sword WS): strictly single-target enmity blast, heals 8/10/12/14% Max HP, +1 Grapeshot (max 3); Quick Draw consumes Grapeshot for 6%/stack Stoneskin + utility.',
            'Crystal JAs: Grapeshot Broadside (25s CD, single-target 12y enmity + Blind + Slow + 2 Grapeshot), Iron Hull (45s CD, -18% DT, Knockback Immunity, 20% heal + cleanse).',
        },
        mods = function(player, lvl)
            local stat = scaleTier(lvl, 8, 14, 20, 26)
            local mods =
            {
                { xi.mod.RECYCLE,               100 },
                { xi.mod.HPP,                   scaleTier(lvl, 14, 18, 22, 26) },
                { xi.mod.VIT,                   stat },
                { xi.mod.AGI,                   stat },
                { xi.mod.DEFP,                  scaleTier(lvl, 12, 18, 24, 30) },
                { xi.mod.DMG,                   scaleTier(lvl, -800, -1100, -1400, -1800) },
                { xi.mod.INQUARTATA,            scaleTier(lvl, 12, 16, 20, 24) },
                { xi.mod.ENMITY,                scaleTier(lvl, 60, 80, 100, 120) },
                { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
            }
            if xi.mod.RANGED_DMG_DEALT then
                table.insert(mods, { xi.mod.RANGED_DMG_DEALT, -60 })
            end
            if isBuccaneerLoadout(player) then
                table.insert(mods, { xi.mod.SWORD,        scaleTier(lvl, 15, 25, 35, 50) })
                table.insert(mods, { xi.mod.MARKSMANSHIP, scaleTier(lvl, 15, 25, 35, 50) })
            end
            return mods
        end,
        onApply = function(player)
            ensureCorStarterGear(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.setLocalVar then
                player:setLocalVar('OX_COR_GRAPESHOT', 0)
                player:setLocalVar('OX_COR_GRAPESHOT_EXP', 0)
                player:setLocalVar('OX_COR_SALTSPRAY', 0)
                player:setLocalVar('OX_COR_SALTSPRAY_EXP', 0)
            end
        end,
    })
end

return m
