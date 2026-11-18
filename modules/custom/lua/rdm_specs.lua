-----------------------------------
-- OverlordsXI Red Mage Crystal Specs
-- Registers the Red Mage (job 5) Soul Crystal specialization:
--   1. Crimson Duelist (CRM) : Hex-Crippling Fencer & Barrier Weaver (1H Sword + Empty Sub)
--
-- Weapon choice remains open (no forced unequipping), while Crimson Fencer Mastery,
-- Hex-Mitigation, Crimson Riposte, and Hex Volley dynamically require a 1H Sword
-- in the main hand with an empty off-hand.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/red_mage')
require('scripts/globals/spells/enhancing_spell')
require('scripts/globals/spells/enfeebling_spell')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_rdm_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.rdmSpecs = xi.overlords.rdmSpecs or {}

local CRIMSON_DUELIST_KEY = 'crimsonduelist'

-- Custom Trait ID (163; client display ID 1699)
local TRAIT_CRIMSON_RIPOSTE = 163

-- Custom Ability IDs (447-448; client display IDs 959-960, recastIds 179-180)
local ABIL_HEX_VOLLEY     = 447
local ABIL_CRIMSON_FLECHE = 448

-- Custom Status Effect IDs (853-854; registered in patch 0026)
local EFFECT_CRIMSON_FLOW   = 853
local EFFECT_CRIMSON_FLECHE = 854

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.HEX_VOLLEY     = ABIL_HEX_VOLLEY
xi.jobAbility.CRIMSON_FLECHE = ABIL_CRIMSON_FLECHE

xi.effect = xi.effect or {}
xi.effect.CRIMSON_FLOW   = EFFECT_CRIMSON_FLOW
xi.effect.CRIMSON_FLECHE = EFFECT_CRIMSON_FLECHE

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.hex_volley     = xi.actions.abilities.hex_volley or {}
xi.actions.abilities.crimson_fleche = xi.actions.abilities.crimson_fleche or {}

xi.effects = xi.effects or {}
xi.effects.crimson_flow   = xi.effects.crimson_flow or {}
xi.effects.crimson_fleche = xi.effects.crimson_fleche or {}

local SWORD_FLOW_WS_IDS =
{
    [35] = true, -- Flat Blade
    [40] = true, -- Vorpal Blade
    [41] = true, -- Swift Blade
    [42] = true, -- Savage Blade
    [47] = true, -- Sanguine Blade
}

local ENFEEBLE_EFFECTS =
{
    xi.effect.DIA,
    xi.effect.BIO,
    xi.effect.SLOW,
    xi.effect.PARALYSIS,
    xi.effect.BLINDNESS,
    xi.effect.SILENCE,
    xi.effect.POISON,
    xi.effect.WEIGHT,
    xi.effect.BIND,
    xi.effect.SLEEP_I,
    xi.effect.SLEEP_II,
    xi.effect.LULLABY,
    xi.effect.ADDLE,
    xi.effect.EVASION_DOWN,
    xi.effect.MAGIC_EVASION_DOWN,
    xi.effect.PETRIFICATION,
    xi.effect.PLAGUE,
    xi.effect.FLASH,
    xi.effect.ELEGY,
    xi.effect.REQUIEM,
    xi.effect.BURN,
    xi.effect.FROST,
    xi.effect.CHOKE,
    xi.effect.RASP,
    xi.effect.SHOCK,
    xi.effect.DROWN,
    xi.effect.ATTACK_DOWN,
    xi.effect.DEFENSE_DOWN,
    xi.effect.ACCURACY_DOWN,
    xi.effect.MAGIC_ATK_DOWN,
    xi.effect.MAGIC_DEF_DOWN,
    xi.effect.INHIBIT_TP,
    xi.effect.HELIX,
}

local weaponModStateByChar = {}

-----------------------------------
-- Scaling, Equipment & Enfeeble Helpers
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

local function isRdmSpec(entity, specKey)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.RDM
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.RDM, specKey)
end

local function isSwordAndEmptySub(player)
    if player == nil or not player.getEquipID or not player.getWeaponSkillType then
        return false
    end

    local mainId = player:getEquipID(xi.slot.MAIN) or 0
    local subId  = player:getEquipID(xi.slot.SUB) or 0
    if mainId == 0 or subId ~= 0 then
        return false
    end

    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.SWORD
end

local function countActiveEnfeebles(target)
    if target == nil or not target.hasStatusEffect then
        return 0
    end

    local count = 0
    for _, effId in ipairs(ENFEEBLE_EFFECTS) do
        if effId ~= nil and target:hasStatusEffect(effId) then
            count = count + 1
            if count >= 5 then
                return 5
            end
        end
    end

    return count
end

local function grantEnmity(target, player, ce, ve)
    if
        target ~= nil and
        player ~= nil and
        target ~= player and
        target.isMob and
        target:isMob() and
        target.addEnmity
    then
        target:addEnmity(player, ce or 0, ve or 0)
    end
end

local function applyFullStoneskin(player)
    if player == nil or not player.getMaxHP then
        return 0
    end

    local maxHp   = player:getMaxHP() or 0
    local ssPower = math.max(1, math.floor(maxHp * 0.25))
    if player.delStatusEffect then
        player:delStatusEffect(xi.effect.STONESKIN)
    end
    if player.addStatusEffect then
        player:addStatusEffect(xi.effect.STONESKIN, { power = ssPower, duration = 300, origin = player, tier = 4 })
    end

    return ssPower
end

local function isCrimsonFlowSpell(spell)
    if spell == nil then
        return false
    end

    local spellId = spell.getID and spell:getID() or 0
    if spellId == xi.magic.spell.STONESKIN or spellId == xi.magic.spell.PHALANX then
        return true
    end

    local skillType = spell.getSkillType and spell:getSkillType() or 0
    return skillType == xi.skill.ENFEEBLING_MAGIC
end

-----------------------------------
-- Weapon-Gated Crimson Fencer Mastery Mods
-----------------------------------
local function clearRdmWeaponMods(player)
    if player == nil or not player.getID then
        return
    end

    local charId = player:getID()
    local state  = weaponModStateByChar[charId]
    if state ~= nil and player.delMod then
        for _, entry in ipairs(state.mods) do
            player:delMod(entry[1], entry[2])
        end
    end
    weaponModStateByChar[charId] = nil
end

local function computeFencerMasteryMods(player)
    if not isRdmSpec(player, CRIMSON_DUELIST_KEY) or not isSwordAndEmptySub(player) then
        return {}
    end

    local lvl      = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local skillAmt = scaleTier(lvl, 15, 25, 35, 50)
    local fcAmt    = scaleTier(lvl, 15, 25, 35, 45)

    return
    {
        { xi.mod.SWORD,          skillAmt },
        { xi.mod.ENFEEBLE,       skillAmt },
        { xi.mod.ENHANCE,        skillAmt },
        { xi.mod.FASTCAST,       fcAmt },
        { xi.mod.SPELLINTERRUPT, 100 },
    }
end

local function syncRdmWeaponMods(player, force)
    if player == nil or not player.getID then
        return
    end

    local charId  = player:getID()
    local desired = computeFencerMasteryMods(player)
    local current = weaponModStateByChar[charId]

    if not force and current ~= nil and #current.mods == #desired then
        local same = true
        for i = 1, #desired do
            if current.mods[i][1] ~= desired[i][1] or current.mods[i][2] ~= desired[i][2] then
                same = false
                break
            end
        end
        if same then
            return
        end
    end

    clearRdmWeaponMods(player)
    if #desired > 0 and player.addMod then
        for _, entry in ipairs(desired) do
            player:addMod(entry[1], entry[2])
        end
        weaponModStateByChar[charId] = { mods = desired }
    end
end

-----------------------------------
-- Custom Status Effects (853-854)
-----------------------------------
xi.effects.crimson_flow.onEffectGain = function(_target, _effect)
end

xi.effects.crimson_flow.onEffectTick = function(_target, _effect)
end

xi.effects.crimson_flow.onEffectLose = function(_target, _effect)
end

xi.effects.crimson_fleche.onEffectGain = function(_target, effect)
    effect:addMod(xi.mod.KNOCKBACK_REDUCTION, 100)
end

xi.effects.crimson_fleche.onEffectTick = function(_target, _effect)
end

xi.effects.crimson_fleche.onEffectLose = function(_target, _effect)
end

-----------------------------------
-- Custom Active Job Abilities (441-442)
-----------------------------------
xi.actions.abilities.hex_volley.onAbilityCheck = function(player, target, _ability)
    if
        not isRdmSpec(player, CRIMSON_DUELIST_KEY) or
        not isSwordAndEmptySub(player) or
        target == nil or
        target == player
    then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end

    return 0, 0
end

xi.actions.abilities.hex_volley.onUseAbility = function(player, target, ability, _action)
    if
        player == nil or
        target == nil or
        not isRdmSpec(player, CRIMSON_DUELIST_KEY) or
        not isSwordAndEmptySub(player)
    then
        return 0
    end

    local lvl       = player.getMainLvl and (player:getMainLvl() or 10) or 10
    local weaponDmg = player.getWeaponDmg and (player:getWeaponDmg(xi.slot.MAIN) or 10) or 10
    local intStat   = player.getStat and (player:getStat(xi.mod.INT) or 10) or 10
    local mndStat   = player.getStat and (player:getStat(xi.mod.MND) or 10) or 10
    local rawDmg    = math.max(20, math.floor(weaponDmg * 1.45 + (intStat + mndStat) * 0.40 + lvl * 0.85))

    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        rawDmg = xi.customBossServer.scaleDamageByLevelGap(player, target, rawDmg)
    end

    local dealt = utils.handleStoneskin(target, rawDmg, xi.attackType.PHYSICAL)
    if dealt > 0 and target.takeDamage then
        local res = target:takeDamage(dealt, player, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
        if type(res) == 'number' then
            dealt = res
        end
    end

    if target.addStatusEffect then
        local diaDot = math.max(2, math.floor(lvl / 20) + 1)
        target:addStatusEffect(xi.effect.DIA,       { power = diaDot, duration = 120, origin = player, tick = 3, subPower = 15, tier = 2 })
        target:addStatusEffect(xi.effect.SLOW,      { power = 2500,   duration = 120, origin = player, tier = 2 })
        target:addStatusEffect(xi.effect.PARALYSIS, { power = 25,     duration = 120, origin = player, tier = 2 })
    end

    grantEnmity(target, player, 220, 750)

    if ability and ability.setMsg and xi.msg and xi.msg.basic and xi.msg.basic.USES_JA_TAKE_DAMAGE then
        ability:setMsg(xi.msg.basic.USES_JA_TAKE_DAMAGE)
    end

    return dealt
end

xi.actions.abilities.crimson_fleche.onAbilityCheck = function(player, _target, _ability)
    if not isRdmSpec(player, CRIMSON_DUELIST_KEY) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end

    return 0, 0
end

xi.actions.abilities.crimson_fleche.onUseAbility = function(player, _target, _ability, _action)
    if player == nil or not isRdmSpec(player, CRIMSON_DUELIST_KEY) then
        return 0
    end

    player:delStatusEffect(EFFECT_CRIMSON_FLECHE)
    player:addStatusEffect(EFFECT_CRIMSON_FLECHE, { power = 1, duration = 6, origin = player })
    return EFFECT_CRIMSON_FLECHE
end

-----------------------------------
-- Parry Rate, Crimson Riposte & Hex-Mitigation
-----------------------------------
m:addOverride('xi.combat.physical.calculateParryRate', function(defender, attacker)
    local rate = super(defender, attacker)

    if isRdmSpec(defender, CRIMSON_DUELIST_KEY) then
        local bonus = 0
        if isSwordAndEmptySub(defender) then
            local lvl = defender.getMainLvl and (defender:getMainLvl() or 10) or 10
            bonus = bonus + scaleTier(lvl, 14, 20, 26, 32)
            bonus = bonus + (countActiveEnfeebles(attacker) * 3)
        end

        if defender.hasStatusEffect and defender:hasStatusEffect(EFFECT_CRIMSON_FLECHE) then
            bonus = bonus + 35
        end

        if bonus > 0 then
            rate = utils.clamp((tonumber(rate) or 0) + bonus, 5, 85)
        end
    end

    return rate
end)

m:addOverride('xi.combat.physical.isParried', function(defender, attacker)
    local parried = super(defender, attacker)

    if
        parried and
        isRdmSpec(defender, CRIMSON_DUELIST_KEY) and
        isSwordAndEmptySub(defender) and
        attacker ~= nil and
        attacker ~= defender
    then
        local lvl       = defender.getMainLvl and (defender:getMainLvl() or 10) or 10
        local weaponDmg = defender.getWeaponDmg and (defender:getWeaponDmg(xi.slot.MAIN) or 8) or 8
        local intStat   = defender.getStat and (defender:getStat(xi.mod.INT) or 10) or 10
        local mndStat   = defender.getStat and (defender:getStat(xi.mod.MND) or 10) or 10
        local rawDmg    = math.max(12, math.floor(weaponDmg * 0.65 + (intStat + mndStat) * 0.35 + lvl * 0.50))

        if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
            rawDmg = xi.customBossServer.scaleDamageByLevelGap(defender, attacker, rawDmg)
        end

        local dmgType = (os.time() % 2 == 0) and xi.damageType.LIGHT or xi.damageType.ICE
        local dealt   = utils.handleStoneskin(attacker, rawDmg, xi.attackType.MAGICAL)
        if dealt > 0 and attacker.takeDamage then
            local res = attacker:takeDamage(dealt, defender, xi.attackType.MAGICAL, dmgType)
            if type(res) == 'number' then
                dealt = res
            end
        end

        if dealt > 0 and defender.messagePublic then
            local hitMsg = (xi.msg and xi.msg.basic and xi.msg.basic.HIT_DMG) or 1
            defender:messagePublic(hitMsg, attacker, dealt, dealt)
        end

        local maxMp = defender.getMaxMP and (defender:getMaxMP() or 0) or 0
        if maxMp > 0 and defender.addMP then
            defender:addMP(math.max(2, math.floor(maxMp * 0.04)))
        end

        grantEnmity(attacker, defender, 120, 450)
    end

    return parried
end)

xi.overlords.onPreTakeDamage = xi.overlords.onPreTakeDamage or function(_defender, amount, _attacker, _attackType, _damageType)
    return amount or 0
end

m:addOverride('xi.overlords.onPreTakeDamage', function(defender, amount, attacker, attackType, damageType)
    amount = super(defender, amount, attacker, attackType, damageType)

    if
        defender == nil or
        amount == nil or
        amount <= 0 or
        attacker == nil or
        attacker == defender
    then
        return amount or 0
    end

    if isRdmSpec(defender, CRIMSON_DUELIST_KEY) and isSwordAndEmptySub(defender) then
        local stacks = countActiveEnfeebles(attacker)
        if stacks > 0 then
            local mult = math.max(0.75, 1.0 - (0.05 * stacks))
            amount = math.max(1, math.floor(amount * mult))
        end
    end

    return amount
end)

-----------------------------------
-- Stoneskin, Phalanx & Composure Overrides
-----------------------------------
m:addOverride('xi.spells.enhancing.calculateEnhancingBasePower', function(caster, target, spell, spellId, spellEffect)
    local basePower = super(caster, target, spell, spellId, spellEffect)

    if isRdmSpec(caster, CRIMSON_DUELIST_KEY) then
        local skillLevel = caster:getSkillLevel(xi.skill.ENHANCING_MAGIC)
        local mndStat    = caster:getStat(xi.mod.MND)

        if spellEffect == xi.effect.PHALANX then
            local scaledPhalanx = math.floor(skillLevel / 8 + mndStat / 4)
            return math.max(basePower, scaledPhalanx)
        elseif spellEffect == xi.effect.STONESKIN and caster == target then
            local maxHp = caster:getMaxHP() or 0
            local capHp = math.floor(maxHp * 0.25)
            local scaledSkin = math.min(capHp, math.floor(skillLevel * 1.3 + mndStat * 3.0))
            return math.max(basePower, scaledSkin)
        end
    end

    return basePower
end)

m:addOverride('xi.actions.spells.white.stoneskin.onSpellCast', function(caster, target, spell)
    local ret = super(caster, target, spell)

    if isRdmSpec(caster, CRIMSON_DUELIST_KEY) and caster == target and caster.hasStatusEffect then
        local eff = caster:getStatusEffect(xi.effect.STONESKIN)
        if eff ~= nil then
            local skillLevel = caster:getSkillLevel(xi.skill.ENHANCING_MAGIC)
            local mndStat    = caster:getStat(xi.mod.MND)
            local maxHp      = caster:getMaxHP() or 0
            local capHp      = math.floor(maxHp * 0.25)
            local desired    = math.min(capHp, math.floor(skillLevel * 1.3 + mndStat * 3.0))
            if desired > (eff:getPower() or 0) then
                eff:setPower(desired)
            end
        end
    end

    return ret
end)

m:addOverride('xi.spells.enfeebling.calculateDuration', function(caster, target, spellId, spellEffect, skillType)
    local duration = super(caster, target, spellId, spellEffect, skillType)

    if isRdmSpec(caster, CRIMSON_DUELIST_KEY) and caster.hasStatusEffect and caster:hasStatusEffect(xi.effect.COMPOSURE) then
        duration = math.floor(duration * 1.5)
    end

    return duration
end)

-----------------------------------
-- RDM Job Ability Overrides (Convert, Composure, Chainspell)
-----------------------------------
m:addOverride('xi.actions.abilities.convert.onAbilityCheck', function(player, target, ability)
    if isRdmSpec(player, CRIMSON_DUELIST_KEY) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(30)
        end
        return 0, 0
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.red_mage.useConvert', function(player, target, ability)
    if isRdmSpec(player, CRIMSON_DUELIST_KEY) then
        local playerMP    = player:getMP()
        local playerHP    = player:getHP()
        local playerMaxHP = player:getMaxHP()
        local playerMaxMP = player:getMaxMP()

        local jpExtraHP       = math.floor(playerMaxHP * player:getJobPointLevel(xi.jp.CONVERT_EFFECT) / 100)
        local murgleisExtraHP = 0
        if player:getMod(xi.mod.AUGMENTS_CONVERT) > 0 then
            murgleisExtraHP = math.floor(playerMaxHP * player:getMod(xi.mod.AUGMENTS_CONVERT) / 100)
        end

        local floorHP = math.floor(playerMaxHP * 0.50)
        local newHP   = math.min(playerMaxHP, math.max(floorHP, playerMP + jpExtraHP + murgleisExtraHP))
        local newMP   = math.min(playerMaxMP, playerHP)

        player:setHP(newHP)
        player:setMP(newMP)
        applyFullStoneskin(player)
        return
    end

    super(player, target, ability)
end)

m:addOverride('xi.effects.composure.onEffectGain', function(target, effect)
    super(target, effect)

    if isRdmSpec(target, CRIMSON_DUELIST_KEY) and effect ~= nil and effect.addMod then
        effect:addMod(xi.mod.ACC, 30)
        effect:addMod(xi.mod.MACC, 30)
    end
end)

m:addOverride('xi.job_utils.red_mage.useChainspell', function(player, target, ability)
    if isRdmSpec(player, CRIMSON_DUELIST_KEY) then
        player:addStatusEffect(xi.effect.CHAINSPELL, { power = 1, duration = 30, origin = player })
        return xi.effect.CHAINSPELL
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.chainspell.onEffectGain', function(target, effect)
    super(target, effect)

    if isRdmSpec(target, CRIMSON_DUELIST_KEY) and effect ~= nil and effect.addMod then
        effect:addMod(xi.mod.DMG, -2500)
    end
end)

-----------------------------------
-- Player Listeners (Equip Sync, WS Flow, Fleche & Chainspell)
-----------------------------------
local function detachRdmListeners(player)
    if player == nil or not player.removeListener then
        return
    end

    player:removeListener('OX_RDM_EQUIP')
    player:removeListener('OX_RDM_TICK')
    player:removeListener('OX_RDM_WS')
    player:removeListener('OX_RDM_MAGIC')
end

local function attachRdmListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachRdmListeners(player)

    player:addListener('ITEM_EQUIP', 'OX_RDM_EQUIP', function(actor)
        syncRdmWeaponMods(actor, false)
    end)

    player:addListener('TICK', 'OX_RDM_TICK', function(actor)
        syncRdmWeaponMods(actor, false)
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_RDM_WS', function(actor, target, skill)
        if not isRdmSpec(actor, CRIMSON_DUELIST_KEY) then
            return
        end

        local wsId = skill and skill.getID and skill:getID() or 0
        if not SWORD_FLOW_WS_IDS[wsId] then
            return
        end

        if isSwordAndEmptySub(actor) and actor.addStatusEffect then
            actor:delStatusEffect(EFFECT_CRIMSON_FLOW)
            actor:addStatusEffect(EFFECT_CRIMSON_FLOW, { power = 1, duration = 6, origin = actor })
        end

        if actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_CRIMSON_FLECHE) then
            actor:delStatusEffect(EFFECT_CRIMSON_FLECHE)
            applyFullStoneskin(actor)
            grantEnmity(target, actor, 180, 650)
        end
    end)

    player:addListener('MAGIC_USE', 'OX_RDM_MAGIC', function(caster, target, spell)
        if not isRdmSpec(caster, CRIMSON_DUELIST_KEY) or spell == nil then
            return
        end

        local lvl = caster.getMainLvl and (caster:getMainLvl() or 10) or 10

        -- Crimson Flow consumption (+50% volatile enmity on Enfeebling, Stoneskin, or Phalanx)
        if
            caster.hasStatusEffect and
            caster:hasStatusEffect(EFFECT_CRIMSON_FLOW) and
            isCrimsonFlowSpell(spell)
        then
            caster:delStatusEffect(EFFECT_CRIMSON_FLOW)
            local bonusVe = math.max(250, math.floor(lvl * 12))
            if target ~= nil and target ~= caster then
                grantEnmity(target, caster, 0, bonusVe)
            end
        end

        -- Crimson Fleche proc on Enfeebling spell
        if
            caster.hasStatusEffect and
            caster:hasStatusEffect(EFFECT_CRIMSON_FLECHE) and
            spell.getSkillType and
            spell:getSkillType() == xi.skill.ENFEEBLING_MAGIC
        then
            caster:delStatusEffect(EFFECT_CRIMSON_FLECHE)
            applyFullStoneskin(caster)
            grantEnmity(target, caster, 180, 650)
        end

        -- Chainspell high-enmity pulse on every spell cast
        if caster.hasStatusEffect and caster:hasStatusEffect(xi.effect.CHAINSPELL) then
            if target ~= nil and target ~= caster and target.isMob and target:isMob() then
                grantEnmity(target, caster, 200, 700)
            elseif caster.getTarget then
                local curTarget = caster:getTarget()
                grantEnmity(curTarget, caster, 200, 700)
            end
        end
    end)
end

-----------------------------------
-- Crystal Definition (RDM = 5)
-----------------------------------
if xi.job and xi.job.RDM then
    spec.registerJob(xi.job.RDM, 'RDM',
    {
        {
            id             = 1,
            key            = CRIMSON_DUELIST_KEY,
            name           = 'Crimson Duelist',
            role           = 'Hex-Crippling Fencer & Barrier Weaver',
            icon           = 'crimsonduelist',
            reqLevel       = 10,
            extraTraits    = { TRAIT_CRIMSON_RIPOSTE },
            extraAbilities = { ABIL_HEX_VOLLEY, ABIL_CRIMSON_FLECHE },
            description    = 'Frontline duelist tank (Lv10+): requires a 1H Sword with an empty off-hand to unlock Fencer Parry/Riposte mastery, Hex-Mitigation (cutting enemy damage per active enfeeble), and instant-cast Stoneskin/Phalanx barrier weaving.',
            highlights     =
            {
                'Crimson Fencer Mastery (1H Sword + Empty Sub): +15/25/35/50 Sword & Enfeebling/Enhancing skill, +14/20/26/32% Parry Rate, +15/25/35/45% Fast Cast, and 100% Spell Interruption Rate Down.',
                'Hex-Mitigation: reduces target physical & magical damage dealt by 5% per active enfeeble (up to -25%) and grants +3% Parry Rate per enfeeble (+15% max).',
                'Crimson Riposte: parrying triggers light/ice counter-damage, heavy volatile enmity, and restores +4% Max MP.',
                'Barrier & WS Weaving: enhances Stoneskin (25% Max HP, 15s recast) & Phalanx (30s recast); Sword WSs grant Crimson Flow (next Enfeeble/Stoneskin/Phalanx instant, 0 MP, +50% VE).',
                'Enhances Convert (30s CD, 50% HP floor + full Stoneskin), Composure (+30 ACC/MACC, +50% Enfeebling duration), and Chainspell (30s, -25% DT, enmity pulse).',
            },
            mods = function(_player, lvl)
                local tankStat = scaleTier(lvl, 8, 14, 20, 26)
                return
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.VIT,                   tankStat },
                    { xi.mod.INT,                   tankStat },
                    { xi.mod.MND,                   tankStat },
                    { xi.mod.DEFP,                  scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.DMG,                   scaleTier(lvl, -600, -900, -1200, -1500) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.SPELLINTERRUPT,        100 },
                }
            end,
            onApply = function(player)
                attachRdmListeners(player)
                syncRdmWeaponMods(player, true)
            end,
            onRemove = function(player)
                clearRdmWeaponMods(player)
                detachRdmListeners(player)
            end,
        },
    })
end

return m
