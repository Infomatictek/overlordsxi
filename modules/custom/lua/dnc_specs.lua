-----------------------------------
-- OverlordsXI Dancer Crystal Specs
-- Registers Dancer (job 19) Soul Crystal specializations:
--   1. Bladewheel (Ranged Chakram Dancer)
--   2. Mirage Sentinel (Fan-Dance Rhythm & Waltz-Shield Tank, Lv.10+)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/dancer')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_dnc_specs')

local spec = xi.overlords.spec

local BLADEWHEEL_KEY = 'bladewheel'
local MIRAGE_KEY     = 'miragesentinel'

-- Custom Trait ID (162; Mirage Rhythm)
local TRAIT_MIRAGE_RHYTHM = 162

-- Custom Ability IDs (449-450; recastIds 227-228)
local ABIL_PIROUETTE_DEFLECT = 449
local ABIL_DAZZLING_CADENCE  = 450

-- Native DNC Ability IDs
local ABIL_TRANCE            = 181
local ABIL_CURING_WALTZ      = 190
local ABIL_CURING_WALTZ_II   = 191
local ABIL_CURING_WALTZ_III  = 192
local ABIL_CURING_WALTZ_IV   = 193
local ABIL_CURING_WALTZ_V    = 311
local ABIL_QUICKSTEP         = 201
local ABIL_BOX_STEP          = 202
local ABIL_STUTTER_STEP      = 203
local ABIL_ANIMATED_FLOURISH = 204
local ABIL_VIOLENT_FLOURISH  = 207
local ABIL_FAN_DANCE         = 238
local ABIL_NO_FOOT_RISE      = 239

local CURING_WALTZ_IDS =
{
    [ABIL_CURING_WALTZ]     = true,
    [ABIL_CURING_WALTZ_II]  = true,
    [ABIL_CURING_WALTZ_III] = true,
    [ABIL_CURING_WALTZ_IV]  = true,
    [ABIL_CURING_WALTZ_V]   = true,
}

local DEBUFF_STEP_IDS =
{
    [ABIL_QUICKSTEP]    = true,
    [ABIL_BOX_STEP]     = true,
    [ABIL_STUTTER_STEP] = true,
}

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.PIROUETTE_DEFLECT = ABIL_PIROUETTE_DEFLECT
xi.jobAbility.DAZZLING_CADENCE  = ABIL_DAZZLING_CADENCE

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.throwing_stance   = xi.actions.abilities.throwing_stance or {}
xi.actions.abilities.fan_dance         = xi.actions.abilities.fan_dance or {}
xi.actions.abilities.trance            = xi.actions.abilities.trance or {}
xi.actions.abilities.pirouette_deflect = xi.actions.abilities.pirouette_deflect or {}
xi.actions.abilities.dazzling_cadence  = xi.actions.abilities.dazzling_cadence or {}

xi.effects = xi.effects or {}
xi.effects.fan_dance = xi.effects.fan_dance or {}
xi.effects.trance    = xi.effects.trance or {}
xi.effects.issekigan = xi.effects.issekigan or {}

local weaponStateByChar = {}

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

local function isBladewheelDnc(player)
    if player == nil or not player:isPC() or player:getMainJob() ~= xi.job.DNC then
        return false
    end
    spec.ensureUpToDate(player)
    return spec.is(player, xi.job.DNC, BLADEWHEEL_KEY)
end

local function isMirageSentinel(entity)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.DNC or
        entity:getMainLvl() < 10
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.DNC, MIRAGE_KEY)
end

local function isDaggerItem(item)
    if item == nil or not item.getSkillType then
        return false
    end
    return item:getSkillType() == xi.skill.DAGGER
end

local function isDualDaggersEquipped(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local mainItem = player:getEquippedItem(xi.slot.MAIN)
    local subItem  = player:getEquippedItem(xi.slot.SUB)
    return isDaggerItem(mainItem) and isDaggerItem(subItem)
end

local function isMirageDualDaggers(entity)
    return isMirageSentinel(entity) and isDualDaggersEquipped(entity)
end

local function getFinishingMoves(player)
    local fmEffect = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    return fmEffect and fmEffect:getPower() or 0
end

local function getFinishingMoveIcon(numMoves)
    if numMoves < 1 then
        return nil
    elseif numMoves <= 5 then
        return xi.effect.FINISHING_MOVE_1 + numMoves - 1
    end
    return xi.effect.FINISHING_MOVE_6
end

local function setFinishingMoves(player, numMoves)
    local clamped = math.max(0, math.min(5, math.floor(numMoves or 0)))
    local fmEffect = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)

    if clamped <= 0 then
        if fmEffect then
            player:delStatusEffect(xi.effect.FINISHING_MOVE_1)
        end
        return
    end

    if fmEffect then
        fmEffect:setPower(clamped)
        fmEffect:setIcon(getFinishingMoveIcon(clamped))
        fmEffect:setDuration(7200 * 1000)
    else
        player:addStatusEffect(xi.effect.FINISHING_MOVE_1, {
            power    = clamped,
            duration = 7200,
            origin   = player,
            icon     = getFinishingMoveIcon(clamped),
        })
    end
end

local function addFinishingMoves(player, delta)
    setFinishingMoves(player, getFinishingMoves(player) + (delta or 0))
end

local function grantAegisWaltz(player, movesSpent)
    if player == nil or not isMirageDualDaggers(player) then
        return
    end

    local moves = math.max(1, math.min(5, math.floor(movesSpent or 1)))
    local maxHp = player.getMaxHP and (player:getMaxHP() or 0) or 0
    if maxHp > 0 then
        local barrier = math.max(1, math.floor(maxHp * 0.05 * moves))
        local current = player:getLocalVar('OX_DNC_AEGIS_WALTZ')
        local exp     = player:getLocalVar('OX_DNC_AEGIS_WALTZ_EXP')
        if exp < os.time() then
            current = 0
        end
        local nextBarrier = math.max(current, barrier)
        player:setLocalVar('OX_DNC_AEGIS_WALTZ', nextBarrier)
        player:setLocalVar('OX_DNC_AEGIS_WALTZ_EXP', os.time() + 30)
    end

    if player.eraseStatusEffect then
        player:eraseStatusEffect()
    end
end

local function runWithTranceFlourishMoves(player, spentCount, fn)
    local inTrance = player:hasStatusEffect(xi.effect.TRANCE)
    local prevMoves = getFinishingMoves(player)
    if inTrance and prevMoves < spentCount then
        setFinishingMoves(player, 5)
    end

    local res = { fn() }

    if inTrance then
        setFinishingMoves(player, math.max(prevMoves, 5))
    end
    return unpack(res)
end

local function pulseAoEThreat(player, primaryTarget, ce, ve, radius)
    if player == nil or not player.getZone then
        return
    end
    local zone = player:getZone()
    if zone == nil or not zone.getMobs then
        return
    end
    for _, mob in pairs(zone:getMobs()) do
        if
            mob ~= nil and
            mob ~= primaryTarget and
            mob:isAlive() and
            mob:isEngaged() and
            player:checkDistance(mob) <= (radius or 10)
        then
            mob:addEnmity(player, ce, ve)
        end
    end
end

local function triggerPirouetteCounter(defender, attacker)
    if
        defender == nil or
        attacker == nil or
        attacker == defender or
        not isMirageSentinel(defender) or
        not defender:hasStatusEffect(xi.effect.ISSEKIGAN) or
        not attacker.isAlive or
        not attacker:isAlive()
    then
        return
    end

    if attacker.addEnmity then
        attacker:addEnmity(defender, 100, 350)
    end

    addFinishingMoves(defender, 1)

    if defender:checkDistance(attacker) <= 5.0 and isDualDaggersEquipped(defender) then
        local weaponDamage = math.max(1, defender:getWeaponDmg())
        local baseDmg = weaponDamage + math.floor(defender:getStat(xi.mod.AGI) * 0.5)
        local pdif = xi.combat.physical.calculateMeleePDIF(defender, attacker, xi.skill.DAGGER, 1.0, false, false, false, 0.0, false, xi.slot.MAIN, false)
        local dmg = math.max(1, math.floor(baseDmg * pdif * 0.75))
        dmg = utils.handleStoneskin(attacker, dmg, xi.attackType.PHYSICAL)
        attacker:takeDamage(dmg, defender, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
        attacker:updateEnmityFromDamage(defender, dmg)
    end
end

-----------------------------------
-- Global C++ Hook Callbacks
-----------------------------------
xi.overlords = xi.overlords or {}

local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage
xi.overlords.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    if defender == nil or amount <= 0 then
        return amount
    end

    -- Step-crippling enfeeble (-5% Damage Dealt per Step level, up to -15% at Lv.3+)
    if attacker ~= nil and attacker.getLocalVar then
        local dmgDown = attacker:getLocalVar('OX_DNC_STEP_DMG_DOWN')
        local dmgExp  = attacker:getLocalVar('OX_DNC_STEP_DMG_EXP')
        if dmgDown > 0 and dmgExp >= os.time() then
            amount = math.max(1, math.floor(amount * (100 - dmgDown) / 100))
        end
    end

    -- Perpetual Fan Dance (-45% Physical & Magical DT, decaying by 5% per hit taken, floor -15%)
    if
        isMirageDualDaggers(defender) and
        defender:hasStatusEffect(xi.effect.FAN_DANCE) and
        (attackType == xi.attackType.PHYSICAL or attackType == xi.attackType.MAGICAL)
    then
        local fanEff = defender:getStatusEffect(xi.effect.FAN_DANCE)
        if fanEff then
            local fanDt = math.max(15, math.min(45, fanEff:getPower()))
            amount = math.max(1, math.floor(amount * (100 - fanDt) / 100))
            fanEff:setPower(math.max(15, fanDt - 5))
        end
    end

    -- Aegis Waltz HP barrier
    if isMirageDualDaggers(defender) and defender.getLocalVar then
        local barrier = defender:getLocalVar('OX_DNC_AEGIS_WALTZ')
        local exp     = defender:getLocalVar('OX_DNC_AEGIS_WALTZ_EXP')
        if barrier > 0 and exp >= os.time() then
            local absorbed = math.min(amount, barrier)
            defender:setLocalVar('OX_DNC_AEGIS_WALTZ', barrier - absorbed)
            amount = amount - absorbed
        elseif barrier > 0 then
            defender:setLocalVar('OX_DNC_AEGIS_WALTZ', 0)
        end
    end

    return amount
end

-----------------------------------
-- Parry Rate & Pirouette Parry Counter
-----------------------------------
m:addOverride('xi.combat.physical.calculateParryRate', function(defender, attacker)
    local rate = super(defender, attacker)
    if isMirageDualDaggers(defender) then
        local bonus = scaleTier(defender:getMainLvl(), 14, 20, 26, 32)
        rate = math.min(95, rate + bonus)
    end
    return rate
end)

m:addOverride('xi.combat.physical.isParried', function(defender, attacker)
    local parried = super(defender, attacker)
    if parried and isMirageSentinel(defender) and defender:hasStatusEffect(xi.effect.ISSEKIGAN) then
        triggerPirouetteCounter(defender, attacker)
    end
    return parried
end)

-----------------------------------
-- Bladewheel Overrides
-----------------------------------
-- Support ranged Violent Flourish when Bladewheel is active with a Throwing weapon
m:addOverride('xi.job_utils.dancer.useViolentFlourishAbility', function(player, target, ability, action)
    if isMirageDualDaggers(player) then
        ability:setRecast(15)
        local inTrance = player:hasStatusEffect(xi.effect.TRANCE)
        local waltzMoves = inTrance and 5 or 1
        local res = runWithTranceFlourishMoves(player, 1, function()
            return super(player, target, ability, action)
        end)
        grantAegisWaltz(player, waltzMoves)
        return res
    end

    if
        not isBladewheelDnc(player) or
        player:getLocalVar('OX_DNC_RANGED') ~= 1 or
        player:getWeaponSkillType(xi.slot.RANGED) ~= xi.skill.THROWING or
        player:checkDistance(target) <= 4.0
    then
        return super(player, target, ability, action)
    end

    local status = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    if status == nil then
        return
    end

    local numMoves = status:getPower()
    local fmEffect = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    if fmEffect ~= nil then
        if numMoves <= 1 then
            player:delStatusEffect(xi.effect.FINISHING_MOVE_1)
        else
            fmEffect:setPower(numMoves - 1)
        end
    end

    local racc = player:getRACC()
    local eva = target:getEVA()
    local hitRate = math.clamp(0.75 + (racc - eva) * 0.005, 0.20, 0.95)

    if math.random() <= hitRate then
        local weaponDamage = math.max(1, player:getRangedDmg())
        local baseDmg = weaponDamage + math.floor(player:getStat(xi.mod.AGI) * 0.5)
        local pdif = xi.combat.physical.calculateRangedPDIF(player, target, xi.skill.THROWING, 1.0, false, false, false, 0.0, false)
        local dmg = math.max(1, math.floor(baseDmg * pdif))

        dmg = utils.handleStoneskin(target, dmg, xi.attackType.RANGED)
        target:takeDamage(dmg, player, xi.attackType.RANGED, xi.damageType.PIERCING)
        target:updateEnmityFromDamage(player, dmg)
        action:recordDamage(target, xi.attackType.RANGED, dmg)

        local maccParams =
        {
            effectId       = xi.effect.STUN,
            magicalElement = xi.element.THUNDER,
            skillRank      = xi.skillRank.A_PLUS,
            actorStat      = xi.mod.INT,
            bonusMacc      = player:getMod(xi.mod.VFLOURISH_MACC),
        }
        local resistRate = xi.combat.magicHitRate.calculateResistRate(player, target, maccParams)
        if resistRate > 0.25 then
            target:addStatusEffect(xi.effect.STUN, 1, 0, 2)
        end
    else
        action:messageID(target:getID(), xi.msg.basic.USES_BUT_MISSES)
    end
end)

local THROWING_STANCE_ABIL_ID = 404

m:addOverride('xi.actions.abilities.throwing_stance.onAbilityCheck', function(player, target, ability)
    if not isBladewheelDnc(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.throwing_stance.onUseAbility', function(player, target, ability)
    local nextState = player:getLocalVar('OX_THROW_STANCE') == 1 and 0 or 1
    player:setLocalVar('OX_THROW_STANCE', nextState)
    if nextState == 1 then
        player:printToPlayer('Throwing Stance ON: auto-attacks throw your chakram at all ranges.', xi.msg.channel.SYSTEM_3)
    else
        player:printToPlayer('Throwing Stance OFF: melee at close range, throw chakram at range.', xi.msg.channel.SYSTEM_3)
    end
    return 0
end)

-----------------------------------
-- Mirage Sentinel DNC Ability & Effect Overrides
-----------------------------------
m:addOverride('xi.actions.abilities.fan_dance.onAbilityCheck', function(player, target, ability)
    if isMirageSentinel(player) then
        if not isDualDaggersEquipped(player) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        ability:setRecast(20)
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.fan_dance.onUseAbility', function(player, target, ability)
    if isMirageSentinel(player) then
        ability:setRecast(20)
        player:delStatusEffectSilent(xi.effect.FAN_DANCE)
        player:addStatusEffect(xi.effect.FAN_DANCE, { power = 45, duration = 300, origin = player })
        return xi.effect.FAN_DANCE
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.dancer.checkFlourishAbility', function(player, target, ability, combatOnly, minimumCost)
    if isMirageDualDaggers(player) and player:hasStatusEffect(xi.effect.TRANCE) then
        if combatOnly and player:getAnimation() ~= 1 then
            return xi.msg.basic.REQUIRES_COMBAT, 0
        end
        return 0, 0
    end
    return super(player, target, ability, combatOnly, minimumCost)
end)

m:addOverride('xi.job_utils.dancer.useAnimatedFlourishAbility', function(player, target, ability, action)
    if isMirageDualDaggers(player) then
        ability:setRecast(10)
        local inTrance = player:hasStatusEffect(xi.effect.TRANCE)
        local numMoves = getFinishingMoves(player)
        local spent = inTrance and 5 or (numMoves >= 2 and 2 or 1)
        runWithTranceFlourishMoves(player, 1, function()
            super(player, target, ability, action)
        end)
        if target ~= nil and target.addEnmity then
            target:addEnmity(player, 250, 1500)
        end
        pulseAoEThreat(player, target, 150, 600, 10)
        grantAegisWaltz(player, spent)
        return
    end
    return super(player, target, ability, action)
end)

m:addOverride('xi.job_utils.dancer.useBuildingFlourishAbility', function(player, target, ability)
    if isMirageDualDaggers(player) then
        local inTrance = player:hasStatusEffect(xi.effect.TRANCE)
        local numMoves = getFinishingMoves(player)
        local spent = inTrance and 5 or math.min(3, math.max(1, numMoves))
        runWithTranceFlourishMoves(player, 1, function()
            super(player, target, ability)
        end)
        grantAegisWaltz(player, spent)
        return
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.dancer.useWildFlourishAbility', function(player, target, ability, action)
    if isMirageDualDaggers(player) then
        local inTrance = player:hasStatusEffect(xi.effect.TRANCE)
        local spent = inTrance and 5 or 2
        local res = runWithTranceFlourishMoves(player, 2, function()
            return super(player, target, ability, action)
        end)
        grantAegisWaltz(player, spent)
        return res
    end
    return super(player, target, ability, action)
end)

m:addOverride('xi.job_utils.dancer.useStepAbility', function(player, target, ability, action, stepEffect)
    local res = super(player, target, ability, action, stepEffect)
    if isMirageDualDaggers(player) and target ~= nil and DEBUFF_STEP_IDS[ability:getID()] then
        local stepEff = target:getStatusEffect(stepEffect)
        if stepEff then
            local stepLvl = math.max(1, math.min(3, stepEff:getPower()))
            target:setLocalVar('OX_DNC_STEP_DMG_DOWN', stepLvl * 5)
            target:setLocalVar('OX_DNC_STEP_DMG_EXP', os.time() + 60)
            if target.addEnmity then
                target:addEnmity(player, 150, 750)
            end
        end
    end
    return res
end)

m:addOverride('xi.job_utils.dancer.useWaltzAbility', function(player, target, ability, action)
    local amtCured = super(player, target, ability, action)
    if isMirageSentinel(player) and CURING_WALTZ_IDS[ability:getID()] and type(amtCured) == 'number' and amtCured > 0 then
        local bonus = math.floor(amtCured * 0.30)
        local missing = math.max(0, target:getMaxHP() - target:getHP())
        local appliedBonus = math.min(bonus, missing)
        if appliedBonus > 0 then
            target:restoreHP(appliedBonus)
            amtCured = amtCured + appliedBonus
        end
        player:updateEnmityFromCure(target, bonus)
        pulseAoEThreat(player, nil, 0, 25, 20)
    end
    return amtCured
end)

m:addOverride('xi.job_utils.dancer.checkNoFootRiseAbility', function(player, target, ability)
    if isMirageSentinel(player) then
        ability:setRecast(15)
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.dancer.useNoFootRiseAbility', function(player, target, ability, action)
    if isMirageSentinel(player) then
        ability:setRecast(15)
        setFinishingMoves(player, 5)
        player:addTP(250)
        return 5
    end
    return super(player, target, ability, action)
end)

m:addOverride('xi.actions.abilities.trance.onUseAbility', function(player, target, ability)
    if isMirageSentinel(player) then
        player:addStatusEffect(xi.effect.TRANCE, { power = 1, duration = 30, origin = player })
        player:addTP(100 * player:getJobPointLevel(xi.jp.TRANCE_EFFECT))
        return xi.effect.TRANCE
    end
    return super(player, target, ability)
end)

m:addOverride('xi.effects.trance.onEffectGain', function(target, effect)
    super(target, effect)
    if isMirageSentinel(target) then
        effect:addMod(xi.mod.DMG, -2000)
    end
end)

m:addOverride('xi.effects.issekigan.onEffectGain', function(target, effect)
    super(target, effect)
    if isMirageSentinel(target) then
        effect:addMod(xi.mod.EVA_PERCENT, 30)
        effect:addMod(xi.mod.KNOCKBACK_REDUCTION, 10)
    end
end)

-----------------------------------
-- Mirage Sentinel Crystal-Unlocked Active Job Abilities
-----------------------------------
m:addOverride('xi.actions.abilities.pirouette_deflect.onAbilityCheck', function(player, _target, ability)
    if not isMirageSentinel(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRecast(20)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.pirouette_deflect.onUseAbility', function(player, _target, ability)
    ability:setRecast(20)

    local fanEff = player:getStatusEffect(xi.effect.FAN_DANCE)
    if fanEff then
        fanEff:setPower(45)
    end

    player:delStatusEffectSilent(xi.effect.ISSEKIGAN)
    player:addStatusEffect(xi.effect.ISSEKIGAN, { power = 1, duration = 8, origin = player })
    return xi.effect.ISSEKIGAN
end)

m:addOverride('xi.actions.abilities.dazzling_cadence.onAbilityCheck', function(player, _target, ability)
    if not isMirageDualDaggers(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRecast(25)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.dazzling_cadence.onUseAbility', function(player, target, ability)
    ability:setRecast(25)
    if target == nil or not target:isAlive() then
        return 0
    end

    if target.addEnmity then
        target:addEnmity(player, 300, 1100)
    end

    target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 4, origin = player })
    target:addStatusEffect(xi.effect.BLINDNESS, { power = 30, duration = 12, origin = player })
    target:addStatusEffect(xi.effect.SLOW, { power = 2000, duration = 12, origin = player })
    setFinishingMoves(player, 5)

    ability:setMsg(xi.msg.basic.USES_ABILITY_EFFECT)
    return xi.effect.BLINDNESS
end)

-----------------------------------
-- Listeners (Weapon Sync, Dagger WS Fan Dance Engine, Pirouette Evade Counter)
-----------------------------------
local function onMirageEquipmentChange(player)
    if player == nil or not player:isPC() then
        return
    end

    local charId = player:getID()
    local dual = isDualDaggersEquipped(player)
    local prev = weaponStateByChar[charId]
    weaponStateByChar[charId] = dual

    if prev ~= dual and isMirageSentinel(player) and spec.appliedByCharId and spec.appliedByCharId[charId] ~= nil then
        spec.appliedByCharId[charId].level = -1
        spec.refreshPlayer(player, { skipSync = true })
    end
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player == nil or not player:isPC() then
        return
    end

    player:removeListener('OX_DNC_MIRAGE_EQUIP')
    player:addListener('EQUIP', 'OX_DNC_MIRAGE_EQUIP', onMirageEquipmentChange)
    player:addListener('UNEQUIP', 'OX_DNC_MIRAGE_EQUIP', onMirageEquipmentChange)

    player:removeListener('OX_DNC_MIRAGE_WS')
    player:addListener('WEAPONSKILL_USE', 'OX_DNC_MIRAGE_WS', function(actor, target, wsId)
        if not isMirageDualDaggers(actor) then
            return
        end

        local wsEntry = xi.data and xi.data.weaponskill and xi.data.weaponskill[wsId]
        local isDaggerWs = (wsEntry ~= nil and wsEntry.skill == xi.skill.DAGGER) or (wsEntry == nil and wsId >= 16 and wsId <= 31)
        if not isDaggerWs then
            return
        end

        local fanEff = actor:getStatusEffect(xi.effect.FAN_DANCE)
        if fanEff then
            local curDt = math.max(15, math.min(45, fanEff:getPower()))
            fanEff:setPower(math.min(45, curDt + 20))
        end

        if target ~= nil and target.addEnmity then
            target:addEnmity(actor, 200, 900)
        end

        addFinishingMoves(actor, 2)
    end)

    player:removeListener('OX_DNC_MIRAGE_ATTACKED')
    player:addListener('ATTACKED', 'OX_DNC_MIRAGE_ATTACKED', function(defender, attacker, action)
        if
            defender == nil or
            attacker == nil or
            attacker == defender or
            not isMirageSentinel(defender) or
            not defender:hasStatusEffect(xi.effect.ISSEKIGAN) or
            action == nil or
            not action.getMsg
        then
            return
        end

        local msg = action:getMsg(defender:getID())
        local missMsg = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if msg == missMsg then
            triggerPirouetteCounter(defender, attacker)
        end
    end)
end)

-----------------------------------
-- Spec Registration
-----------------------------------
if xi.job and xi.job.DNC then
    spec.registerJob(xi.job.DNC, 'DNC',
    {
        {
            id             = 1,
            key            = BLADEWHEEL_KEY,
            name           = 'Bladewheel',
            role           = 'Ranged Chakram Dancer',
            icon           = 'chakram_crystal',
            throwWs        = true,
            autoRanged     = { minLevel = 10, maxRange = 20, skills = { 'throwing' } },
            rangedDances   = true,
            extraAbilities = { THROWING_STANCE_ABIL_ID },
            onRemove       = function(player)
                player:setLocalVar('OX_THROW_STANCE', 0)
            end,
            description    = 'Ranged chakram spec: auto-attacks with your chakram when out of melee range (or at all ranges with Throwing Stance), unlocks 12 Throwing weaponskills, and lets Steps, Flourishes, and Sambas work at range.',
            highlights     =
            {
                'Auto-attacks with equipped chakram when outside melee range.',
                'Throwing Stance (JA): overrides melee auto-attacks with chakram throws at all ranges.',
                'Unlocks 12 custom Dancer Throwing weaponskills (Lv 5-75).',
                'Steps and offensive Flourishes work up to 20 yalms.',
                'Drain, Aspir, and Haste Samba trigger on ranged chakram hits.',
                'Passive +R.Acc, +R.Atk, +Snapshot, +AGI, and +CHR.',
            },
            mods = function(_player, lvl)
                local racc = scaleTier(lvl, 10, 22, 36, 48)
                local ratt = scaleTier(lvl, 10, 24, 40, 54)
                local snap = scaleTier(lvl, 5, 10, 15, 20)
                local stat = scaleTier(lvl, 3, 6, 10, 14)
                return
                {
                    { xi.mod.RACC, racc },
                    { xi.mod.RATT, ratt },
                    { xi.mod.SNAPSHOT, snap },
                    { xi.mod.AGI, stat },
                    { xi.mod.CHR, stat },
                }
            end,
        },
        {
            id             = 2,
            key            = MIRAGE_KEY,
            name           = 'Mirage Sentinel',
            role           = 'Fan-Dance Rhythm & Waltz-Shield Tank',
            icon           = 'mirage_crystal',
            extraTraits    = { TRAIT_MIRAGE_RHYTHM },
            extraAbilities = function(_player, lvl)
                if (lvl or 1) >= 10 then
                    return
                    {
                        ABIL_FAN_DANCE,
                        ABIL_ANIMATED_FLOURISH,
                        ABIL_VIOLENT_FLOURISH,
                        ABIL_PIROUETTE_DEFLECT,
                        ABIL_DAZZLING_CADENCE,
                    }
                end
                return {}
            end,
            onRemove       = function(player)
                player:setLocalVar('OX_DNC_AEGIS_WALTZ', 0)
                player:setLocalVar('OX_DNC_AEGIS_WALTZ_EXP', 0)
                player:delStatusEffectSilent(xi.effect.FAN_DANCE)
                player:delStatusEffectSilent(xi.effect.ISSEKIGAN)
            end,
            description    = 'Acrobatic frontline dancer tank (Lv10+): requires Dual Daggers to unlock Perpetual Fan Dance (recharged by Dagger WSs and Flourishes), Finishing Move Waltz-Shields, and Step-crippling enfeebles.',
            highlights     =
            {
                'Passives (Lv10/30/50/70+): +12/16/20/25% Max HP, +8/14/20/26 AGI/DEX/CHR, +12/18/24/30% DEF, -8/11/14/18% DT, +25/35/45/60 Enmity & Retention, +15/20/25/30% Waltz Potency.',
                'Dual Dagger & Step Mastery: +15/25/35/50 Dagger, +14/20/26/32% Evasion & Parry Rate, +15/20/25/30% Subtle Blow; unlocks Fan Dance & Animated/Violent Flourish @ Lv10+.',
                'Perpetual Fan Dance: 20s CD, usable with Curing Waltz; -45% Phys/Mag DT (decays 5%/hit, floor -15%), recharged +20% by Dagger WSs (+enmity, +2 FMs).',
                'Aegis Waltz & Steps: Flourishes grant 5% Max HP barrier/FM (up to 25%) + 1 cleanse; Steps generate heavy enmity & inflict -5% Damage Dealt/lvl (up to -15%).',
                'Pirouette Deflect (20s CD) & Dazzling Cadence (25s CD): reset Fan Dance + evade/parry counter-strikes; Stun + Blind + Slow + 5 FMs.',
            },
            mods = function(player, lvl)
                local stat = scaleTier(lvl, 8, 14, 20, 26)
                local mods =
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.AGI,                   stat },
                    { xi.mod.DEX,                   stat },
                    { xi.mod.CHR,                   stat },
                    { xi.mod.DEFP,                  scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.DMG,                   scaleTier(lvl, -800, -1100, -1400, -1800) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.WALTZ_POTENCY,         scaleTier(lvl, 15, 20, 25, 30) },
                    { xi.mod.ALL_WSDMG_ALL_HITS,    -15 },
                }

                if isDualDaggersEquipped(player) then
                    table.insert(mods, { xi.mod.DAGGER,      scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(mods, { xi.mod.EVA_PERCENT, scaleTier(lvl, 14, 20, 26, 32) })
                    table.insert(mods, { xi.mod.SUBTLE_BLOW, scaleTier(lvl, 15, 20, 25, 30) })
                end

                return mods
            end,
        },
    })
end

return m
