-----------------------------------
-- OverlordsXI Paladin Crystal Specs
-- Registers the Paladin (job 7) Soul Crystal specialization:
--   1. Aegis Templar (PLD): Party-Intercepting Holy Bastion (Club + Shield)
--
-- Weapon choice remains open (no forced unequipping), while Club & Shield
-- Mastery, Divine Intercept, Zeal / Holy Retribution, and Judgment Gavel
-- dynamically require Club + Shield (and 100% SIRD requires Shield).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/job_utils/paladin')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_pld_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.pldSpecs = xi.overlords.pldSpecs or {}
local pldSpecs        = xi.overlords.pldSpecs

local AEGIS_TEMPLAR_KEY = 'aegistemplar'

-- Custom Trait ID (165; Aegis Devotion)
local TRAIT_AEGIS_DEVOTION = 165

-- Custom Ability IDs (439-440; recastIds 177-178)
local ABIL_AEGIS_CONSECRATION = 439
local ABIL_JUDGMENT_GAVEL     = 440

-- Native PLD Ability IDs
local ABIL_INVINCIBLE  = 22
local ABIL_SHIELD_BASH = 46
local ABIL_SENTINEL    = 48
local ABIL_RAMPART     = 92
local ABIL_CHIVALRY    = 158

-- Native Spell ID
local SPELL_FLASH = (xi.magic and xi.magic.spell and xi.magic.spell.FLASH) or 112

-- Custom Status Effect IDs (842-844; registered in patch 0025)
local EFFECT_AEGIS_ZEAL         = 842
local EFFECT_AEGIS_CONSECRATION = 843
local EFFECT_HOLY_RETRIBUTION   = 844

-- Club Weaponskill IDs
local WS_BRAINSHAKER  = 162
local WS_STARLIGHT    = 163
local WS_MOONLIGHT    = 164
local WS_SKULLBREAKER = 165

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.AEGIS_CONSECRATION = ABIL_AEGIS_CONSECRATION
xi.jobAbility.JUDGMENT_GAVEL     = ABIL_JUDGMENT_GAVEL

xi.effect = xi.effect or {}
xi.effect.AEGIS_ZEAL         = EFFECT_AEGIS_ZEAL
xi.effect.AEGIS_CONSECRATION = EFFECT_AEGIS_CONSECRATION
xi.effect.HOLY_RETRIBUTION   = EFFECT_HOLY_RETRIBUTION

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.aegis_consecration = xi.actions.abilities.aegis_consecration or {}
xi.actions.abilities.judgment_gavel     = xi.actions.abilities.judgment_gavel or {}

xi.effects = xi.effects or {}
xi.effects.aegis_zeal         = xi.effects.aegis_zeal or {}
xi.effects.aegis_consecration = xi.effects.aegis_consecration or {}
xi.effects.holy_retribution   = xi.effects.holy_retribution or {}

local weaponModStateByChar  = {}
local interceptWindowByChar = {}

-----------------------------------
-- Scaling & Equipment Helpers
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

local function isPldSpec(entity, specKey)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.PLD
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.PLD, specKey)
end

local function isClubEquipped(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local mainItem = player:getEquippedItem(xi.slot.MAIN)
    if mainItem == nil or not mainItem.getSkillType then
        return false
    end
    return mainItem:getSkillType() == xi.skill.CLUB
end

local function isShieldEquipped(player)
    if player == nil then
        return false
    end
    if player.getShieldSize then
        return (player:getShieldSize() or 0) > 0
    end
    return false
end

local function isClubAndShieldEquipped(player)
    return isClubEquipped(player) and isShieldEquipped(player)
end

local function isClubWs(ws)
    if ws == nil then
        return false
    end
    local wsId = (type(ws) == 'number') and ws or (ws.getID and ws:getID() or 0)
    if wsId >= 160 and wsId <= 175 then
        return true
    end
    if type(ws) == 'table' or type(ws) == 'userdata' then
        if ws.getSkillType and ws:getSkillType() == xi.skill.CLUB then
            return true
        end
    end
    return false
end

local function getPartyMembersInRange(player, range)
    local out = {}
    if player == nil or not player.getPartyWithTrusts then
        if player ~= nil then
            table.insert(out, player)
        end
        return out
    end

    local zoneId = player.getZoneID and player:getZoneID() or 0
    local members = player:getPartyWithTrusts()
    if type(members) ~= 'table' or #members == 0 then
        table.insert(out, player)
        return out
    end

    for _, member in ipairs(members) do
        if member ~= nil and (not member.isAlive or member:isAlive()) then
            local sameZone = (not member.getZoneID) or member:getZoneID() == zoneId
            if sameZone and (member:getID() == player:getID() or player:checkDistance(member) <= range) then
                table.insert(out, member)
            end
        end
    end
    return out
end

local function applyCustomTimedEffect(target, effectId, power, durationSec, origin, subPower, iconId, tickSec, tier)
    if target == nil or not target.addStatusEffect then
        return
    end

    target:addStatusEffect(effectId,
    {
        power    = power or 1,
        duration = durationSec or 10,
        origin   = origin or target,
        subPower = subPower or 0,
        icon     = iconId or effectId,
        tick     = tickSec or 0,
        tier     = tier or 0,
    })
end

-----------------------------------
-- Dynamic Equipment-Gated Mod Sync
-----------------------------------
local function clearPldWeaponMods(player)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local prev   = weaponModStateByChar[charId]
    if prev ~= nil and player.delMod then
        for _, entry in ipairs(prev.mods or {}) do
            player:delMod(entry[1], entry[2])
        end
    end
    weaponModStateByChar[charId] = nil
end

local function syncPldWeaponMods(player, force)
    if player == nil or not player.getID then
        return
    end

    if not isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        clearPldWeaponMods(player)
        return
    end

    local charId    = player:getID()
    local lvl       = player:getMainLvl() or 1
    local hasClub   = isClubEquipped(player)
    local hasShield = isShieldEquipped(player)
    local stateKey  = string.format('%s:%u:%s:%s', AEGIS_TEMPLAR_KEY, lvl, tostring(hasClub), tostring(hasShield))

    local prev = weaponModStateByChar[charId]
    if not force and prev ~= nil and prev.key == stateKey then
        return
    end

    clearPldWeaponMods(player)

    local mods = {}
    if hasClub then
        table.insert(mods, { xi.mod.CLUB, scaleTier(lvl, 15, 25, 35, 50) })
    end
    if hasShield then
        local blockRate = scaleTier(lvl, 12, 18, 24, 30)
        if hasClub then
            blockRate = blockRate + 10
        end
        table.insert(mods, { xi.mod.SHIELD,            scaleTier(lvl, 15, 25, 35, 50) })
        table.insert(mods, { xi.mod.SHIELD_DEF_BONUS,  scaleTier(lvl, 3, 5, 7, 9) })
        table.insert(mods, { xi.mod.SHIELDBLOCKRATE,   blockRate })
        table.insert(mods, { xi.mod.SHIELD_MASTERY_TP, scaleTier(lvl, 20, 30, 40, 50) })
        table.insert(mods, { xi.mod.SPELLINTERRUPT,    100 })
    end

    if player.addMod then
        for _, entry in ipairs(mods) do
            player:addMod(entry[1], entry[2])
        end
    end

    weaponModStateByChar[charId] = { key = stateKey, mods = mods }
end

-----------------------------------
-- Zeal Stacks & Holy Retribution
-----------------------------------
local function getZealStacks(player)
    if player == nil or not player.getStatusEffect then
        return 0
    end
    local eff = player:getStatusEffect(EFFECT_AEGIS_ZEAL)
    if eff == nil then
        return 0
    end
    return math.max(0, math.min(5, eff:getPower() or 0))
end

local function grantZealStack(player, delta)
    if player == nil or not isPldSpec(player, AEGIS_TEMPLAR_KEY) or not isClubAndShieldEquipped(player) then
        return 0
    end

    local cur  = getZealStacks(player)
    local next = math.max(0, math.min(5, cur + (delta or 1)))
    if next <= 0 then
        return 0
    end

    local iconId = (xi.effect and xi.effect.REPRISAL) or EFFECT_AEGIS_ZEAL
    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_AEGIS_ZEAL)
    end
    applyCustomTimedEffect(player, EFFECT_AEGIS_ZEAL, next, 30, player, 0, iconId, 0, 1)
    return next
end

local function grantHolyRetributionAura(player, dtBps, durationSec)
    local iconId = (xi.effect and xi.effect.SHELL) or EFFECT_HOLY_RETRIBUTION
    local members = getPartyMembersInRange(player, 10.0)
    for _, member in ipairs(members) do
        local existing = member.getStatusEffect and member:getStatusEffect(EFFECT_HOLY_RETRIBUTION) or nil
        local existingPower = existing and (existing:getPower() or 0) or 0
        if existingPower <= dtBps then
            if member.delStatusEffectSilent then
                member:delStatusEffectSilent(EFFECT_HOLY_RETRIBUTION)
            end
            applyCustomTimedEffect(member, EFFECT_HOLY_RETRIBUTION, dtBps, durationSec, player, 0, iconId, 0, 1)
        end
    end
end

local function detonateHolyNova(player, primaryTarget)
    if player == nil or not isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        return false
    end

    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_AEGIS_ZEAL)
    end

    local lvl  = player:getMainLvl() or 1
    local vit  = player:getStat(xi.mod.VIT)
    local mnd  = player:getStat(xi.mod.MND)
    local dmg  = math.max(25, math.floor((vit + mnd) * 2.0 + lvl * 3.0))

    local primaryId = (primaryTarget ~= nil and primaryTarget.getID) and primaryTarget:getID() or 0
    if
        primaryTarget ~= nil and
        primaryTarget.isAlive and primaryTarget:isAlive() and
        primaryTarget.getID and primaryTarget:getID() ~= player:getID() and
        (not primaryTarget.isPC or not primaryTarget:isPC())
    then
        primaryTarget:takeDamage(dmg, player, xi.attackType.MAGICAL, xi.damageType.LIGHT)
        if primaryTarget.addEnmity then
            primaryTarget:addEnmity(player, 300, 900)
        end
    end

    -- Heavy AoE enmity & light splash to nearby engaged mobs within 10y
    for _, ent in ipairs(xi.overlords.getNearbyMobs(player, 10, primaryTarget)) do
        if
            ent.isEngaged and ent:isEngaged() and
            ent:getID() ~= primaryId
        then
            local aoeDmg = math.max(15, math.floor(dmg * 0.65))
            ent:takeDamage(aoeDmg, player, xi.attackType.MAGICAL, xi.damageType.LIGHT)
            if ent.addEnmity then
                ent:addEnmity(player, 150, 450)
            end
        end
    end

    -- Restore 8% Max MP
    local maxMp = player:getMaxMP() or 0
    if maxMp > 0 then
        player:addMP(math.max(1, math.floor(maxMp * 0.08)))
    end

    -- Grant party members within 10y a -10% Damage Taken aura for 8s
    grantHolyRetributionAura(player, 1000, 8)
    return true
end

-----------------------------------
-- Divine Intercept (Pre-Take-Damage Hook)
-----------------------------------
local function findInterceptingAegisPaladin(defender)
    if defender == nil or defender.getID == nil then
        return nil
    end

    local zoneId = defender.getZoneID and defender:getZoneID() or 0
    local candidates = nil
    if defender.getPartyWithTrusts then
        candidates = defender:getPartyWithTrusts()
    elseif defender.getMaster then
        local master = defender:getMaster()
        if master ~= nil and master.getPartyWithTrusts then
            candidates = master:getPartyWithTrusts()
        elseif master ~= nil then
            candidates = { master }
        end
    end

    if type(candidates) ~= 'table' then
        return nil
    end

    for _, member in ipairs(candidates) do
        if
            member ~= nil and
            member:getID() ~= defender:getID() and
            isPldSpec(member, AEGIS_TEMPLAR_KEY) and
            isClubAndShieldEquipped(member) and
            (not member.isAlive or member:isAlive()) and
            ((not member.getZoneID) or member:getZoneID() == zoneId) and
            member:checkDistance(defender) <= 10.0
        then
            local hp    = member:getHP() or 0
            local maxHp = member:getMaxHP() or 0
            if maxHp > 0 and hp > math.floor(maxHp * 0.35) then
                return member
            end
        end
    end

    return nil
end

xi.overlords = xi.overlords or {}
local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage

function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    if defender == nil or amount == nil or amount <= 0 then
        return amount or 0
    end

    local pld = findInterceptingAegisPaladin(defender)
    if pld == nil then
        return amount
    end

    local pldMaxHp    = pld:getMaxHP() or 0
    local consecrated = pld.hasStatusEffect and pld:hasStatusEffect(EFFECT_AEGIS_CONSECRATION) or false
    local redirectPct = consecrated and 0.40 or 0.25
    local perHitCap   = math.max(1, math.floor(pldMaxHp * (consecrated and 0.18 or 0.12)))
    local windowCap   = math.max(1, math.floor(pldMaxHp * (consecrated and 0.40 or 0.30)))

    local charId = pld:getID()
    local now    = xi.overlords.nowSec()
    local win    = interceptWindowByChar[charId]
    if win == nil or (now - win.start) >= 1.5 then
        win = { start = now, used = 0 }
        interceptWindowByChar[charId] = win
    end

    local availWindow = math.max(0, windowCap - win.used)
    if availWindow <= 0 then
        return amount
    end

    local rawIntercept = math.floor(amount * redirectPct)
    if rawIntercept <= 0 then
        return amount
    end

    local pldDamage = math.floor(rawIntercept * 0.80)
    pldDamage = math.min(pldDamage, perHitCap, availWindow)
    if pldDamage <= 0 then
        return amount
    end

    win.used = win.used + pldDamage
    local allyPrevented = math.min(amount, rawIntercept, math.ceil(pldDamage / 0.80))

    pld:takeDamage(pldDamage, attacker, attackType, damageType)

    if attacker ~= nil and attacker.isMob and attacker:isMob() and attacker.addEnmity then
        attacker:addEnmity(pld, 1, 180)
    end

    grantZealStack(pld, 1)

    return math.max(0, amount - allyPrevented)
end

-----------------------------------
-- Custom Status Effect Callbacks
-----------------------------------
m:addOverride('xi.effects.aegis_zeal.onEffectGain', function(_target, _effect)
end)

m:addOverride('xi.effects.aegis_zeal.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.aegis_consecration.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.SHIELDBLOCKRATE, 20)
end)

m:addOverride('xi.effects.aegis_consecration.onEffectTick', function(target, _effect)
    if target == nil or not isPldSpec(target, AEGIS_TEMPLAR_KEY) then
        return
    end
    for _, ent in ipairs(xi.overlords.getNearbyMobs(target, 10)) do
        if ent.isEngaged and ent:isEngaged() and ent.addEnmity then
            ent:addEnmity(target, 1, 200)
        end
    end
end)

m:addOverride('xi.effects.aegis_consecration.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.holy_retribution.onEffectGain', function(_target, effect)
    local power = effect:getPower() or 1000
    effect:addMod(xi.mod.DMG, -power)
end)

m:addOverride('xi.effects.holy_retribution.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Listeners (Block, Flash, Club WS, Equip)
-----------------------------------
local function detachPldListeners(player)
    if player == nil or not player.removeListener then
        return
    end
    player:removeListener('OX_PLD_EQUIP')
    player:removeListener('OX_PLD_TICK')
    player:removeListener('OX_PLD_BLOCK')
    player:removeListener('OX_PLD_MAGIC')
    player:removeListener('OX_PLD_WS')
end

local function attachPldListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachPldListeners(player)

    player:addListener('ITEM_EQUIP', 'OX_PLD_EQUIP', function(actor)
        syncPldWeaponMods(actor, false)
    end)

    player:addListener('TICK', 'OX_PLD_TICK', function(actor)
        syncPldWeaponMods(actor, false)
    end)

    player:addListener('SHIELD_BLOCK', 'OX_PLD_BLOCK', function(defender, _attacker, _damageTaken, blockedAmt)
        if not isPldSpec(defender, AEGIS_TEMPLAR_KEY) or not isClubAndShieldEquipped(defender) then
            return
        end

        grantZealStack(defender, 1)

        if defender.hasStatusEffect and defender:hasStatusEffect(EFFECT_AEGIS_CONSECRATION) then
            local heal = math.max(1, math.floor((tonumber(blockedAmt) or 0) * 0.25))
            defender:addHP(heal)
        end
    end)

    player:addListener('MAGIC_USE', 'OX_PLD_MAGIC', function(caster, target, spell, _action)
        if not isPldSpec(caster, AEGIS_TEMPLAR_KEY) or not isClubAndShieldEquipped(caster) then
            return
        end
        if spell ~= nil and spell:getID() == SPELL_FLASH and getZealStacks(caster) >= 5 then
            detonateHolyNova(caster, target)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_PLD_WS', function(actor, target, ws, tp, _action, dmg)
        if not isPldSpec(actor, AEGIS_TEMPLAR_KEY) or not isClubAndShieldEquipped(actor) then
            return
        end
        if not isClubWs(ws) then
            return
        end

        local wsId = (type(ws) == 'number') and ws or (ws.getID and ws:getID() or 0)
        local vit  = actor:getStat(xi.mod.VIT)
        local mnd  = actor:getStat(xi.mod.MND)
        local d    = tonumber(dmg) or 0

        -- Club WSs scale off VIT + MND
        if
            d > 0 and
            target ~= nil and
            target.isAlive and target:isAlive() and
            target.getID and target:getID() ~= actor:getID()
        then
            local bonus = math.max(1, math.floor((vit + mnd) * (0.40 + (tonumber(tp) or 1000) / 3000)))
            target:takeDamage(bonus, actor, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
        end

        -- Skullbreaker / Brainshaker: -15% Attack Down & -15% Magic Attack Down
        if (wsId == WS_SKULLBREAKER or wsId == WS_BRAINSHAKER) and target ~= nil and target.isAlive and target:isAlive() then
            target:addStatusEffect(xi.effect.ATTACK_DOWN,    { power = 15, duration = 60, origin = actor })
            target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 15, duration = 60, origin = actor })
        end

        -- Party HP / MP restoration on Club WSs
        local members = getPartyMembersInRange(actor, 10.0)
        if wsId == WS_STARLIGHT or wsId == WS_MOONLIGHT then
            local mult  = (wsId == WS_MOONLIGHT) and 0.85 or 0.65
            local mpAmt = math.max(15, math.floor((d > 0 and d or 45) * mult))
            local hpAmt = math.max(20, math.floor((vit + mnd) * (wsId == WS_MOONLIGHT and 1.1 or 0.8)))
            for _, member in ipairs(members) do
                if member.addMP then
                    member:addMP(mpAmt)
                end
                if member.addHP then
                    member:addHP(hpAmt)
                end
            end
        else
            local hpAmt = math.max(15, math.floor((vit + mnd) * 0.6))
            local mpAmt = math.max(6, math.floor(mnd * 0.12))
            for _, member in ipairs(members) do
                if member.addHP then
                    member:addHP(hpAmt)
                end
                if member.addMP then
                    member:addMP(mpAmt)
                end
            end
        end

        -- Detonate Holy Nova at 5 Zeal stacks
        if getZealStacks(actor) >= 5 then
            detonateHolyNova(actor, target)
        end
    end)
end

-----------------------------------
-- Native PLD Job Ability Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.sentinel.onAbilityCheck', function(player, target, ability)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        ability:setRecast(20)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.paladin.useSentinel', function(player, target, ability)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        local guardian = player:getMerit(xi.merit.GUARDIAN)
        local jpValue  = player:getJobPointLevel(xi.jp.SENTINEL_EFFECT)
        player:addStatusEffect(xi.effect.SENTINEL, { power = 3500, duration = 8, origin = player, tick = 3, subPower = guardian + jpValue })
        return xi.effect.SENTINEL
    end
    return super(player, target, ability)
end)

m:addOverride('xi.effects.sentinel.onEffectGain', function(target, effect)
    super(target, effect)
    if isPldSpec(target, AEGIS_TEMPLAR_KEY) then
        effect:addMod(xi.mod.SHIELDBLOCKRATE, 30)
    end
end)

m:addOverride('xi.job_utils.paladin.useRampart', function(player, target, ability)
    local res = super(player, target, ability)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) and target ~= nil then
        local ssPower = math.max(50, math.floor((player:getMaxHP() or 0) * 0.15))
        target:addStatusEffect(xi.effect.STONESKIN, { power = ssPower, duration = 30, origin = player, tier = 4 })
    end
    return res
end)

m:addOverride('xi.effects.rampart.onEffectGain', function(target, effect)
    super(target, effect)
    local origin = effect.getOriginator and effect:getOriginator() or nil
    if isPldSpec(origin or target, AEGIS_TEMPLAR_KEY) then
        effect:addMod(xi.mod.MDEF, 20)
    end
end)

m:addOverride('xi.actions.abilities.chivalry.onAbilityCheck', function(player, target, ability)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        ability:setRecast(15)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.paladin.useChivalry', function(player, target, ability, action)
    local amount = super(player, target, ability, action)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) and target ~= nil and target.eraseStatusEffect then
        target:eraseStatusEffect()
        target:eraseStatusEffect()
    end
    return amount
end)

m:addOverride('xi.job_utils.paladin.useInvincible', function(player, target, ability)
    local res = super(player, target, ability)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        grantHolyRetributionAura(player, 2500, 15)
    end
    return res
end)

m:addOverride('xi.job_utils.paladin.useShieldBash', function(player, target, ability)
    local dmg = super(player, target, ability)
    if isPldSpec(player, AEGIS_TEMPLAR_KEY) and isClubAndShieldEquipped(player) and getZealStacks(player) >= 5 then
        detonateHolyNova(player, target)
    end
    return dmg
end)

-----------------------------------
-- Crystal-Unlocked Active Job Abilities
-----------------------------------
m:addOverride('xi.actions.abilities.aegis_consecration.onAbilityCheck', function(player, _target, _ability)
    if not isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    if not isShieldEquipped(player) then
        return xi.msg.basic.REQUIRES_SHIELD, 0
    end
    if not isClubEquipped(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.aegis_consecration.onUseAbility', function(player, _target, _ability, _action)
    local iconId = (xi.effect and xi.effect.FEALTY) or EFFECT_AEGIS_CONSECRATION
    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_AEGIS_CONSECRATION)
    end
    applyCustomTimedEffect(player, EFFECT_AEGIS_CONSECRATION, 1, 10, player, 0, iconId, 2, 1)
    return EFFECT_AEGIS_CONSECRATION
end)

m:addOverride('xi.actions.abilities.judgment_gavel.onAbilityCheck', function(player, _target, _ability)
    if not isPldSpec(player, AEGIS_TEMPLAR_KEY) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    if not isShieldEquipped(player) then
        return xi.msg.basic.REQUIRES_SHIELD, 0
    end
    if not isClubEquipped(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.judgment_gavel.onUseAbility', function(player, target, ability, _action)
    if target == nil or not target.isAlive or not target:isAlive() then
        return 0
    end

    local lvl = player:getMainLvl() or 1
    local vit = player:getStat(xi.mod.VIT)
    local mnd = player:getStat(xi.mod.MND)
    local dmg = math.max(30, math.floor((vit + mnd) * 2.2 + lvl * 2.5))

    dmg = utils.handleStoneskin(target, dmg, xi.attackType.PHYSICAL)
    target:takeDamage(dmg, player, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
    target:updateEnmityFromDamage(player, dmg)
    if target.addEnmity then
        target:addEnmity(player, 150, 450)
    end

    -- Stun target
    if
        not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
        not xi.data.statusEffect.isTargetResistant(player, target, xi.effect.STUN) and
        not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
    then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 4, origin = player })
    end

    -- Inflict -20% Attack Down & -20% Magic Attack Down for 12s
    target:addStatusEffect(xi.effect.ATTACK_DOWN,    { power = 20, duration = 12, origin = player })
    target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 20, duration = 12, origin = player })

    -- Grant +3 Zeal stacks (or trigger Holy Nova at 5 stacks)
    local stacks = grantZealStack(player, 3)
    if stacks >= 5 then
        detonateHolyNova(player, target)
    end

    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return dmg
end)

-----------------------------------
-- Crystal Definition (PLD = 7)
-----------------------------------
if xi.job and xi.job.PLD then
    spec.registerJob(xi.job.PLD, 'PLD',
    {
        {
            id          = 1,
            key         = AEGIS_TEMPLAR_KEY,
            name        = 'Aegis Templar',
            role        = 'Party-Intercepting Holy Bastion',
            icon        = 'aegistemplar',
            reqLevel    = 10,
            extraTraits = { TRAIT_AEGIS_DEVOTION },
            extraAbilities = function(_player, _lvl)
                return { ABIL_AEGIS_CONSECRATION, ABIL_JUDGMENT_GAVEL }
            end,
            description = 'Order of the Silver Aegis tank (Lv10+): requires a Club + Shield to unlock Divine Intercept (absorbing 25% of damage taken by nearby party members), Zeal stack generation on block/intercept, and Holy Retribution party auras.',
            highlights =
            {
                'Passives (Lv10/30/50/70+): +14/18/22/26% Max HP, +8/14/20/26 VIT & MND, +14/20/26/32% DEF, -8/12/16/20% DT, +25/35/45/60 Enmity & +25/35/45/60% Enmity Retention, +15/20/25/30% Cure Potency Received.',
                'Club & Shield Mastery: +15/25/35/50 Club & Shield skill, +3/5/7/9 Shield DEF Bonus, +12/18/24/30% Block (+10% w/ Club+Shield), +20/30/40/50 Shield Mastery TP, 100% SIRD w/ Shield.',
                'Divine Intercept: While Shield+Club equipped & >35% HP, redirects 25% of party damage within 10y (40% in Consecration) onto PLD (-20% dmg, capped at 12%/18% Max HP per hit and 30%/40% per 1.5s AoE window).',
                'Zeal & Holy Retribution (Max 5): Blocking or intercepting grants +1 Zeal; at 5 Zeal, Flash / Shield Bash / Club WS detonates Holy Nova (+8% Max MP, party -10% DT for 8s, heavy enmity).',
                'Club WS Engine & JAs: Club WSs scale off VIT+MND, inflict -15% ATK/MATK Down (Skullbreaker/Brainshaker), and restore party HP/MP; enhances Sentinel, Rampart, Chivalry, and Invincible.',
            },
            mods = function(player, lvl)
                local isWiki = (player == nil) or (not player.getEquipID)
                local list =
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 14, 18, 22, 26) },
                    { xi.mod.VIT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.MND,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 14, 20, 26, 32) },
                    { xi.mod.DMG,                   scaleTier(lvl, -800, -1200, -1600, -2000) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.CURE_POTENCY_RCVD,     scaleTier(lvl, 15, 20, 25, 30) },
                }

                if isWiki then
                    table.insert(list, { xi.mod.CLUB,              scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(list, { xi.mod.SHIELD,            scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(list, { xi.mod.SHIELD_DEF_BONUS,  scaleTier(lvl, 3, 5, 7, 9) })
                    table.insert(list, { xi.mod.SHIELDBLOCKRATE,   scaleTier(lvl, 12, 18, 24, 30) })
                    table.insert(list, { xi.mod.SHIELD_MASTERY_TP, scaleTier(lvl, 20, 30, 40, 50) })
                    table.insert(list, { xi.mod.SPELLINTERRUPT,    100 })
                end

                return list
            end,
            onApply = function(player)
                attachPldListeners(player)
                syncPldWeaponMods(player, true)
            end,
            onRemove = function(player)
                if player ~= nil and player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_AEGIS_ZEAL)
                    player:delStatusEffectSilent(EFFECT_AEGIS_CONSECRATION)
                end
                if player ~= nil and player.getID then
                    interceptWindowByChar[player:getID()] = nil
                end
                clearPldWeaponMods(player)
                detachPldListeners(player)
            end,
        },
    })
end

return m
