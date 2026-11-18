-----------------------------------
-- OverlordsXI Dark Knight Crystal Specs
-- Registers the Dark Knight (job 8) Soul Crystal specialization:
--   1. Dreadnought (DRK): Blood-Pool & Dread Spikes Tank (Scythe)
--
-- Weapon choice remains open (no forced unequipping), while Scythe & Dark
-- Magic Mastery, Blood-Pool Overcap, instant Dread Spikes / Absorbs,
-- Vampiric Scythe WS sustain, and Abyssal Cleave dynamically require a Scythe.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
require('scripts/globals/job_utils/dark_knight')
require('scripts/globals/canusespell_override')
require('scripts/globals/spells/absorb_spell')
require('scripts/globals/spells/enhancing_spell')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_drk_specs')

local spec = xi.overlords.spec

xi.overlords          = xi.overlords or {}
xi.overlords.drkSpecs = xi.overlords.drkSpecs or {}
local drkSpecs        = xi.overlords.drkSpecs

local DREADNOUGHT_KEY = 'dreadnought'

-- Custom Trait ID (167; Dreadnought's Carapace)
local TRAIT_DREADNOUGHTS_CARAPACE = 167

-- Custom Ability IDs (449-450; recastIds 224-225)
local ABIL_ABYSSAL_CLEAVE = 449
local ABIL_DREAD_BASTION  = 450

-- Native Spell IDs
local SPELL_DRAIN_II     = (xi.magic and xi.magic.spell and xi.magic.spell.DRAIN_II)     or 246
local SPELL_DRAIN_III    = (xi.magic and xi.magic.spell and xi.magic.spell.DRAIN_III)    or 880
local SPELL_DREAD_SPIKES = (xi.magic and xi.magic.spell and xi.magic.spell.DREAD_SPIKES) or 277
local SPELL_ABSORB_STR   = (xi.magic and xi.magic.spell and xi.magic.spell.ABSORB_STR)   or 266
local SPELL_ABSORB_VIT   = (xi.magic and xi.magic.spell and xi.magic.spell.ABSORB_VIT)   or 268
local SPELL_ABSORB_TP    = (xi.magic and xi.magic.spell and xi.magic.spell.ABSORB_TP)    or 275
local SPELL_ABSORB_ACC   = (xi.magic and xi.magic.spell and xi.magic.spell.ABSORB_ACC)   or 242

-- Custom Status Effect IDs (855-856; registered in patch 0026)
local EFFECT_BLOOD_CARAPACE = 855
local EFFECT_DREAD_BASTION  = 856

-- Vampiric Scythe Weaponskill IDs
local VAMPIRIC_SCYTHE_WS =
{
    [98]  = true, -- Shadow of Death
    [99]  = true, -- Nightmare Scythe
    [101] = true, -- Vorpal Scythe
    [102] = true, -- Guillotine
    [105] = true, -- Catastrophe
    [106] = true, -- Insurgency
}

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.ABYSSAL_CLEAVE = ABIL_ABYSSAL_CLEAVE
xi.jobAbility.DREAD_BASTION  = ABIL_DREAD_BASTION

xi.effect = xi.effect or {}
xi.effect.BLOOD_CARAPACE = EFFECT_BLOOD_CARAPACE
xi.effect.DREAD_BASTION  = EFFECT_DREAD_BASTION

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.abyssal_cleave = xi.actions.abilities.abyssal_cleave or {}
xi.actions.abilities.dread_bastion  = xi.actions.abilities.dread_bastion  or {}

xi.effects = xi.effects or {}
xi.effects.blood_carapace = xi.effects.blood_carapace or {}
xi.effects.dread_bastion  = xi.effects.dread_bastion  or {}

local weaponModStateByChar = {}
local lastWsCastAtByChar   = {}

local function getBloodTithe(player)
    if player == nil or not player.getLocalVar then
        return 0
    end
    local exp = player:getLocalVar('OX_DRK_TITHE_EXP') or 0
    if exp > 0 and os.time() > exp then
        player:setLocalVar('OX_DRK_TITHE', 0)
        player:setLocalVar('OX_DRK_TITHE_EXP', 0)
        return 0
    end
    return math.min(3, math.max(0, player:getLocalVar('OX_DRK_TITHE') or 0))
end

local function addBloodTithe(player, amount)
    if player == nil or not player.setLocalVar then
        return 0
    end
    local cur  = getBloodTithe(player)
    local next = math.min(3, cur + (amount or 1))
    player:setLocalVar('OX_DRK_TITHE', next)
    player:setLocalVar('OX_DRK_TITHE_EXP', os.time() + 30)
    return next
end

local function consumeAllBloodTithe(player)
    local count = getBloodTithe(player)
    if player ~= nil and player.setLocalVar then
        player:setLocalVar('OX_DRK_TITHE', 0)
        player:setLocalVar('OX_DRK_TITHE_EXP', 0)
    end
    return count
end

local function primeBloodReap(player)
    if player ~= nil and player.setLocalVar then
        player:setLocalVar('OX_DRK_BLOOD_REAP_EXP', os.time() + 12)
    end
end

local function consumeBloodReap(player)
    if player == nil or not player.getLocalVar then
        return false
    end
    local exp = player:getLocalVar('OX_DRK_BLOOD_REAP_EXP') or 0
    player:setLocalVar('OX_DRK_BLOOD_REAP_EXP', 0)
    return exp > 0 and os.time() <= exp
end

local function applySharedSlot(target, effectId, power, duration, origin, modsTable)
    if target == nil or not target.isAlive or not target:isAlive() then
        return
    end
    local slots = xi.overlords and xi.overlords.slots
    if slots and slots.applySlot then
        slots.applySlot(target, effectId, power, duration, origin, modsTable, effectId)
        return
    end
    for _, pair in ipairs(modsTable or {}) do
        if pair[1] == xi.mod.ATTP then
            target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = math.abs(pair[2]), duration = duration, origin = origin })
        elseif pair[1] == xi.mod.MATT then
            target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = math.abs(pair[2]), duration = duration, origin = origin })
        elseif pair[1] == xi.mod.ACC then
            target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = math.abs(pair[2]), duration = duration, origin = origin })
        elseif pair[1] == xi.mod.DEFP then
            target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = math.abs(pair[2]), duration = duration, origin = origin })
        elseif pair[1] == xi.mod.MDEF then
            target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, { power = math.abs(pair[2]), duration = duration, origin = origin })
        end
    end
end

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

local function isDrkSpec(entity, specKey)
    if
        entity == nil or
        not entity.isPC or
        not entity:isPC() or
        entity:getMainJob() ~= xi.job.DRK
    then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.DRK, specKey)
end

local function isScytheEquipped(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local mainItem = player:getEquippedItem(xi.slot.MAIN)
    if mainItem == nil or not mainItem.getSkillType then
        return false
    end
    return mainItem:getSkillType() == xi.skill.SCYTHE
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

local function getBaseMaxHpWithoutOvercap(player)
    local curMax = player:getMaxHP() or 0
    local eff    = player.getStatusEffect and player:getStatusEffect(xi.effect.MAX_HP_BOOST) or nil
    if eff ~= nil and (eff:getPower() or 0) == 0 then
        local bonus = eff:getSubPower() or 0
        if bonus > 0 and curMax > bonus then
            return curMax - bonus
        end
    end
    return curMax
end

local function applyBloodPoolOvercap(player, gainedHp)
    if player == nil or not isDrkSpec(player, DREADNOUGHT_KEY) then
        return
    end

    local baseMaxHp = getBaseMaxHpWithoutOvercap(player)
    if baseMaxHp <= 0 then
        return
    end

    local cap25      = math.max(1, math.floor(baseMaxHp * 0.25))
    local existing   = player.getStatusEffect and player:getStatusEffect(xi.effect.MAX_HP_BOOST) or nil
    local curOvercap = 0

    if existing ~= nil then
        if (existing:getPower() or 0) ~= 0 then
            -- Do not overwrite percentage-based Max HP Boost (e.g. food/song)
            return
        end
        curOvercap = math.max(0, existing:getSubPower() or 0)
    end

    local overflow   = math.max(0, (player:getHP() or 0) + (gainedHp or 0) - baseMaxHp)
    local newOvercap = math.min(cap25, math.max(curOvercap, overflow))
    if newOvercap <= 0 then
        return
    end

    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(xi.effect.MAX_HP_BOOST)
    end
    player:addStatusEffect(xi.effect.MAX_HP_BOOST,
    {
        power    = 0,
        duration = 30,
        origin   = player,
        subPower = newOvercap,
    })
end

local function hasBloodPoolOvercap(player)
    if player == nil or not player.getStatusEffect then
        return false
    end
    local existing = player:getStatusEffect(xi.effect.MAX_HP_BOOST)
    return existing ~= nil and (existing:getPower() or 0) == 0 and (existing:getSubPower() or 0) > 0
end

local function extendBloodPoolDuration(player, extraSec)
    if player == nil or not player.getStatusEffect then
        return
    end
    local existing = player:getStatusEffect(xi.effect.MAX_HP_BOOST)
    if existing ~= nil and (existing:getPower() or 0) == 0 and (existing:getSubPower() or 0) > 0 then
        local subP      = existing:getSubPower()
        local remMs     = existing.getTimeRemaining and existing:getTimeRemaining() or 0
        local remSec    = math.max(1, math.ceil(remMs / 1000))
        local newDurSec = math.min(60, remSec + (extraSec or 6))
        if player.delStatusEffectSilent then
            player:delStatusEffectSilent(xi.effect.MAX_HP_BOOST)
        end
        player:addStatusEffect(xi.effect.MAX_HP_BOOST,
        {
            power    = 0,
            duration = newDurSec,
            origin   = player,
            subPower = subP,
        })
    end
end

local function grantDreadnoughtSpells(player)
    if player == nil or not player.addSpell or not player.hasSpell then
        return
    end
    if not player:hasSpell(SPELL_DRAIN_II) then
        player:addSpell(SPELL_DRAIN_II, { silentLog = true, saveToDB = true, sendUpdate = true })
    end
    if not player:hasSpell(SPELL_DREAD_SPIKES) then
        player:addSpell(SPELL_DREAD_SPIKES, { silentLog = true, saveToDB = true, sendUpdate = true })
    end
end

-----------------------------------
-- Dynamic Equipment-Gated Mod Sync
-----------------------------------
local function clearDrkWeaponMods(player)
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

local function syncDrkWeaponMods(player, force)
    if player == nil or not player.getID then
        return
    end

    if not isDrkSpec(player, DREADNOUGHT_KEY) then
        clearDrkWeaponMods(player)
        return
    end

    local charId    = player:getID()
    local lvl       = player:getMainLvl() or 1
    local hasScythe = isScytheEquipped(player)
    local stateKey  = string.format('%s:%u:%s', DREADNOUGHT_KEY, lvl, tostring(hasScythe))

    local prev = weaponModStateByChar[charId]
    if not force and prev ~= nil and prev.key == stateKey then
        return
    end

    clearDrkWeaponMods(player)

    local mods = {}
    if hasScythe then
        table.insert(mods, { xi.mod.SCYTHE,          scaleTier(lvl, 15, 25, 35, 50) })
        table.insert(mods, { xi.mod.DARK,            scaleTier(lvl, 15, 25, 35, 50) })
        table.insert(mods, { xi.mod.INQUARTATA,      scaleTier(lvl, 10, 14, 18, 22) })
        table.insert(mods, { xi.mod.DARK_MAGIC_CAST, -scaleTier(lvl, 20, 30, 40, 50) })
        table.insert(mods, { xi.mod.SPELLINTERRUPT,  100 })
    end

    if player.addMod then
        for _, entry in ipairs(mods) do
            player:addMod(entry[1], entry[2])
        end
    end

    weaponModStateByChar[charId] = { key = stateKey, mods = mods }
end

-----------------------------------
-- Dread Spikes Blood-Shield (Pre-Take-Damage Hook)
-----------------------------------
local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage

function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    local curAmount = amount or 0
    if prevOnPreTakeDamage ~= nil then
        curAmount = prevOnPreTakeDamage(defender, curAmount, attacker, attackType, damageType)
    end

    if
        defender == nil or
        curAmount <= 0 or
        attackType ~= xi.attackType.PHYSICAL or
        not isDrkSpec(defender, DREADNOUGHT_KEY)
    then
        return curAmount
    end

    local spikes = defender.getStatusEffect and defender:getStatusEffect(xi.effect.DREAD_SPIKES) or nil
    if spikes == nil then
        return curAmount
    end

    local remaining = spikes:getSubPower() or 0
    if remaining <= 0 then
        return curAmount
    end

    local absorbed = math.min(curAmount, remaining)
    if absorbed <= 0 then
        return curAmount
    end

    if remaining - absorbed <= 0 then
        if defender.delStatusEffectSilent then
            defender:delStatusEffectSilent(xi.effect.DREAD_SPIKES)
        end
    else
        spikes:setSubPower(remaining - absorbed)
    end

    -- Generate flat volatile enmity on each absorbed physical hit
    if attacker ~= nil and attacker.isMob and attacker:isMob() and attacker.addEnmity then
        attacker:addEnmity(defender, 0, 180)
    end

    return math.max(0, curAmount - absorbed)
end

-----------------------------------
-- Spell Unlocks & Dark Magic Overrides
-----------------------------------
local DREADNOUGHT_UNLOCKED_SPELLS =
{
    [SPELL_DRAIN_II]     = true,
    [SPELL_DREAD_SPIKES] = true,
}

m:addOverride('xi.spells.canUseSpellOverride', function(player, spell)
    if
        player ~= nil and
        spell ~= nil and
        isDrkSpec(player, DREADNOUGHT_KEY) and
        (player:getMainLvl() or 1) >= 10 and
        isScytheEquipped(player) and
        DREADNOUGHT_UNLOCKED_SPELLS[spell:getID()]
    then
        return true
    end
    return super(player, spell)
end)

-- Drain II: normal MP cost, 30s recast, Max-HP + VIT scaled drain bypassing -60% MAG_DMG_DEALT, +25% Max HP overcap for 30s
m:addOverride('xi.actions.spells.black.drain_ii.onSpellCast', function(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        local dmg = 0
        if target ~= nil and target.isAlive and target:isAlive() and not (target.isUndead and target:isUndead()) then
            local lvl       = caster:getMainLvl() or 1
            local baseMaxHp = getBaseMaxHpWithoutOvercap(caster)
            local vit       = caster:getStat(xi.mod.VIT) or 0
            local pct       = scaleTier(lvl, 0.12, 0.15, 0.18, 0.22)
            local rawDrain  = math.max(1, math.floor(baseMaxHp * pct + vit * 0.75))
            local targetHp  = target:getHP() or 0
            dmg             = math.min(rawDrain, targetHp)
            if dmg > 0 then
                if target.delHP then
                    target:delHP(dmg)
                else
                    target:takeDamage(dmg, caster, xi.attackType.MAGICAL, xi.damageType.DARK)
                end
                if target.updateEnmityFromDamage then
                    target:updateEnmityFromDamage(caster, dmg)
                end
                if target.addEnmity then
                    target:addEnmity(caster, 150, 450)
                end
                applyBloodPoolOvercap(caster, dmg)
                if caster.addHP then
                    caster:addHP(dmg)
                end
                if spell ~= nil and spell.setMsg then
                    spell:setMsg(xi.msg.basic.MAGIC_DRAIN_HP)
                end
            else
                if spell ~= nil and spell.setMsg then
                    spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
                end
            end
        else
            if spell ~= nil and spell.setMsg then
                spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
            end
        end

        if caster.timer then
            caster:timer(50, function(actor)
                if actor ~= nil and actor.addRecast then
                    actor:addRecast(xi.recast.MAGIC, SPELL_DRAIN_II, 30)
                end
            end)
        end
        return dmg
    end

    return super(caster, target, spell)
end)

-- Drain III: also enforces Dreadnought Blood-Pool overcap if cast
m:addOverride('xi.actions.spells.black.drain_iii.onSpellCast', function(caster, target, spell)
    local dmg = super(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) and dmg > 0 then
        applyBloodPoolOvercap(caster, dmg)
    end
    return dmg
end)

-- Dread Spikes: instant-cast, 45s recast, costs 10% Current HP (requires >15% HP),
-- consumes Blood Tithe (0..3) for 25% + 5%/stack Max HP shield (up to 40%)
m:addOverride('xi.actions.spells.black.dread_spikes.onMagicCastingCheck', function(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        if spell ~= nil and spell.setCastTime then
            spell:setCastTime(0)
        end
        local maxHp = caster:getMaxHP() or 1
        local curHp = caster:getHP() or 0
        if curHp <= math.floor(maxHp * 0.15) then
            return xi.msg.basic.CANNOT_PERFORM
        end
    end
    return super(caster, target, spell)
end)

m:addOverride('xi.actions.spells.black.dread_spikes.onSpellCast', function(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        local maxHp = caster:getMaxHP() or 0
        local curHp = caster:getHP() or 0
        local hpCost = math.floor(curHp * 0.10)
        if curHp - hpCost < 1 then
            hpCost = math.max(0, curHp - 1)
        end
        if hpCost > 0 and caster.delHP then
            caster:delHP(hpCost)
        end

        local tithe  = consumeAllBloodTithe(caster)
        local pct    = 0.25 + (tithe * 0.05)
        local shield = math.max(1, math.floor(maxHp * pct))
        if caster.delStatusEffectSilent then
            caster:delStatusEffectSilent(xi.effect.DREAD_SPIKES)
        end
        caster:addStatusEffect(xi.effect.DREAD_SPIKES,
        {
            power    = 1,
            duration = 180,
            origin   = caster,
            subPower = shield,
            tier     = 1,
        })
        if spell ~= nil and spell.setMsg then
            spell:setMsg(xi.msg.basic.MAGIC_GAIN_EFFECT)
        end
        if caster.timer then
            caster:timer(50, function(actor)
                if actor ~= nil and actor.addRecast then
                    actor:addRecast(xi.recast.MAGIC, SPELL_DREAD_SPIKES, 45)
                end
            end)
        end
        return xi.effect.DREAD_SPIKES
    end
    return super(caster, target, spell)
end)

-- Absorb-STR / VIT / TP / ACC: instant-cast, 18s shared cycle, heavy VE, +6% Max MP, +1 Blood Tithe (max 3, 30s)
local ABSORB_TANK_SPELLS =
{
    { name = 'absorb-str', id = SPELL_ABSORB_STR },
    { name = 'absorb-vit', id = SPELL_ABSORB_VIT },
    { name = 'absorb-tp',  id = SPELL_ABSORB_TP  },
    { name = 'absorb-acc', id = SPELL_ABSORB_ACC },
}

for _, entry in ipairs(ABSORB_TANK_SPELLS) do
    m:addOverride('xi.actions.spells.black.' .. entry.name .. '.onMagicCastingCheck', function(caster, target, spell)
        if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
            if spell ~= nil and spell.setCastTime then
                spell:setCastTime(0)
            end
        end
        return super(caster, target, spell)
    end)

    m:addOverride('xi.actions.spells.black.' .. entry.name .. '.onSpellCast', function(caster, target, spell)
        local res = super(caster, target, spell)
        if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
            if target ~= nil and target.isMob and target:isMob() and target.addEnmity then
                target:addEnmity(caster, 150, 750)
            end

            local maxMp = caster:getMaxMP() or 0
            if maxMp > 0 and caster.addMP then
                caster:addMP(math.max(1, math.floor(maxMp * 0.06)))
            end

            addBloodTithe(caster, 1)

            if caster.timer then
                caster:timer(50, function(actor)
                    if actor ~= nil and actor.addRecast then
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_STR, 18)
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_VIT, 18)
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_TP,  18)
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_ACC, 18)
                    end
                end)
            end
        end
        return res
    end)
end

-----------------------------------
-- Custom Status Effect Callbacks
-----------------------------------
m:addOverride('xi.effects.blood_carapace.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.DMG, -1200)
end)

m:addOverride('xi.effects.blood_carapace.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.dread_bastion.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.DMG, -1800)
    effect:addMod(xi.mod.KNOCKBACK_REDUCTION, 100)
    effect:addMod(xi.mod.ENMITY, 35)
end)

m:addOverride('xi.effects.dread_bastion.onEffectTick', function(target, _effect)
    if target == nil or not isDrkSpec(target, DREADNOUGHT_KEY) then
        return
    end
    for _, ent in ipairs(xi.overlords.getNearbyMobs(target, 8)) do
        if ent.isEngaged and ent:isEngaged() and ent.addEnmity then
            ent:addEnmity(target, 0, 260)
        end
    end
end)

m:addOverride('xi.effects.dread_bastion.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Native DRK Job Ability Reworks
-----------------------------------
-- Souleater -> Blood Carapace (45s CD, 12s duration: -12% DT; swings spend 2% HP above 20% HP for VE + Blood Tithe + Blood Reap)
m:addOverride('xi.actions.abilities.souleater.onAbilityCheck', function(player, target, ability)
    if isDrkSpec(player, DREADNOUGHT_KEY) and ability ~= nil and ability.setRecast then
        ability:setRecast(45)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.dark_knight.useSouleater', function(player, target, ability)
    if isDrkSpec(player, DREADNOUGHT_KEY) then
        local iconId = (xi.effect and xi.effect.SOULEATER) or EFFECT_BLOOD_CARAPACE
        if player.delStatusEffectSilent then
            player:delStatusEffectSilent(EFFECT_BLOOD_CARAPACE)
        end
        applyCustomTimedEffect(player, EFFECT_BLOOD_CARAPACE, 12, 12, player, 0, iconId, 0, 1)
        return EFFECT_BLOOD_CARAPACE
    end
    return super(player, target, ability)
end)

-- Arcane Circle -> Shared EFF_OX_SUP_WARD (-10% DMG / +25 MEVA, 15s)
m:addOverride('xi.effects.arcane_circle.onEffectGain', function(target, effect)
    super(target, effect)
    local origin = effect.getOriginator and effect:getOriginator() or nil
    if isDrkSpec(origin or target, DREADNOUGHT_KEY) then
        local slots = xi.overlords and xi.overlords.slots
        if slots and slots.applyPartyWard then
            slots.applyPartyWard(origin or target, target, -1000, 25, 15, xi.effect.ARCANE_CIRCLE)
        else
            effect:addMod(xi.mod.DMG, -1000)
            effect:addMod(xi.mod.MEVA, 25)
        end
    end
end)

-- Blood Weapon -> +50 Enmity, -20% DT, +4% Max HP heal per landed melee swing for 30s
m:addOverride('xi.effects.blood_weapon.onEffectGain', function(target, effect)
    super(target, effect)
    if isDrkSpec(target, DREADNOUGHT_KEY) then
        effect:addMod(xi.mod.ENMITY, 50)
        effect:addMod(xi.mod.DMG, -2000)
    end
end)

-----------------------------------
-- Crystal-Unlocked Active Job Abilities
-----------------------------------
m:addOverride('xi.actions.abilities.abyssal_cleave.onAbilityCheck', function(player, _target, _ability)
    if not isDrkSpec(player, DREADNOUGHT_KEY) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    if not isScytheEquipped(player) then
        return xi.msg.basic.NEEDS_2H_WEAPON, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.abyssal_cleave.onUseAbility', function(player, target, ability, _action)
    if target == nil or not target.isAlive or not target:isAlive() then
        return 0
    end

    local lvl = player:getMainLvl() or 1
    local str = player:getStat(xi.mod.STR)
    local vit = player:getStat(xi.mod.VIT)
    local int = player:getStat(xi.mod.INT)
    local dmg = math.max(30, math.floor((str + vit + int) * 1.6 + lvl * 2.5))

    dmg = utils.handleStoneskin(target, dmg, xi.attackType.PHYSICAL)
    target:takeDamage(dmg, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    target:updateEnmityFromDamage(player, dmg)
    if target.addEnmity then
        target:addEnmity(player, 200, 900)
    end

    -- 2s Stun (mob:isNM() safe)
    local isNm = target.isNM and target:isNM()
    if
        not isNm and
        not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
        not xi.data.statusEffect.isTargetResistant(player, target, xi.effect.STUN) and
        not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
    then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = player })
    end

    -- Apply EFF_OX_DEB_BREACH (-15% DEFP / -15 MDEF for 12s)
    local breachId = (xi.effect and xi.effect.EFF_OX_DEB_BREACH) or 879
    applySharedSlot(target, breachId, 15, 12, player,
    {
        { xi.mod.DEFP, -15 },
        { xi.mod.MDEF, -15 },
    })

    -- Restore +8% Max MP & grant +1 Blood Tithe (max 3, 30s)
    local maxMp = player:getMaxMP() or 0
    if maxMp > 0 and player.addMP then
        player:addMP(math.max(1, math.floor(maxMp * 0.08)))
    end
    addBloodTithe(player, 1)

    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return dmg
end)

m:addOverride('xi.actions.abilities.dread_bastion.onAbilityCheck', function(player, _target, _ability)
    if not isDrkSpec(player, DREADNOUGHT_KEY) then
        return xi.msg.basic.CANNOT_PERFORM, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.dread_bastion.onUseAbility', function(player, _target, _ability, _action)
    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(EFFECT_DREAD_BASTION)
    end

    local iconId = (xi.effect and xi.effect.DARK_SEAL) or EFFECT_DREAD_BASTION
    applyCustomTimedEffect(player, EFFECT_DREAD_BASTION, 1, 12, player, 0, iconId, 2, 1)
    return EFFECT_DREAD_BASTION
end)

-----------------------------------
-- Listeners (Equip, Tick, Melee Risk/Reward, Scythe WS)
-----------------------------------
local function detachDrkListeners(player)
    if player == nil or not player.removeListener then
        return
    end
    player:removeListener('OX_DRK_EQUIP')
    player:removeListener('OX_DRK_TICK')
    player:removeListener('OX_DRK_ATTACK')
    player:removeListener('OX_DRK_WS')
end

local function attachDrkListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachDrkListeners(player)

    player:addListener('ITEM_EQUIP', 'OX_DRK_EQUIP', function(actor)
        syncDrkWeaponMods(actor, false)
    end)

    player:addListener('TICK', 'OX_DRK_TICK', function(actor)
        syncDrkWeaponMods(actor, false)
    end)

    player:addListener('ATTACK', 'OX_DRK_ATTACK', function(actor, target, action)
        if
            actor == nil or
            target == nil or
            action == nil or
            not isDrkSpec(actor, DREADNOUGHT_KEY)
        then
            return
        end

        local dmg = action:getParam(target:getID()) or 0
        if dmg <= 0 then
            return
        end

        local maxHp = actor:getMaxHP() or 0
        local curHp = actor:getHP() or 0

        -- Souleater (Blood Carapace): spend 2% Current HP (above 20% HP) for heavy VE, +1 Blood Tithe, and prime Blood Reap
        if actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_BLOOD_CARAPACE) then
            if maxHp > 0 and curHp > math.floor(maxHp * 0.20) and actor.delHP then
                local cost = math.max(1, math.floor(curHp * 0.02))
                if curHp - cost >= 1 then
                    actor:delHP(cost)
                end
            end
            if target.isMob and target:isMob() and target.addEnmity then
                target:addEnmity(actor, 0, 260)
            end
            addBloodTithe(actor, 1)
            primeBloodReap(actor)
        end

        -- Blood Weapon: heal flat 4% Max HP per landed melee swing
        if actor.hasStatusEffect and actor:hasStatusEffect(xi.effect.BLOOD_WEAPON) and maxHp > 0 and actor.addHP then
            actor:addHP(math.max(1, math.floor(maxHp * 0.04)))
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_DRK_WS', function(actor, target, ws, _tp, _action, _dmg)
        if not isDrkSpec(actor, DREADNOUGHT_KEY) or not isScytheEquipped(actor) then
            return
        end

        local wsId = (type(ws) == 'number') and ws or (ws ~= nil and ws.getID and ws:getID() or 0)
        if not VAMPIRIC_SCYTHE_WS[wsId] then
            return
        end

        local charId = actor.getID and actor:getID() or 0
        local now    = xi.overlords.nowSec()
        local isPrimary = (charId == 0) or ((now - (lastWsCastAtByChar[charId] or 0)) > 0.05)
        if isPrimary and charId > 0 then
            lastWsCastAtByChar[charId] = now
        end

        if isPrimary then
            local lvl       = actor:getMainLvl() or 1
            local maxHp     = actor:getMaxHP() or 0
            local empowered = hasBloodPoolOvercap(actor) or (actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_BLOOD_CARAPACE))
            local healPct   = empowered and scaleTier(lvl, 0.10, 0.12, 0.14, 0.16) or scaleTier(lvl, 0.05, 0.06, 0.07, 0.08)
            if actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_DREAD_BASTION) then
                healPct = healPct * 2
            end
            if consumeBloodReap(actor) then
                healPct = healPct + 0.20
            end
            if maxHp > 0 and actor.addHP then
                actor:addHP(math.max(1, math.floor(maxHp * healPct)))
            end

            extendBloodPoolDuration(actor, 6)
        end

        if target ~= nil and target.isAlive and target:isAlive() and target.getID and target:getID() ~= actor:getID() then
            local crippleId = (xi.effect and xi.effect.EFF_OX_DEB_CRIPPLE) or 880
            applySharedSlot(target, crippleId, 15, 15, actor,
            {
                { xi.mod.ATTP, -15 },
                { xi.mod.MATT, -15 },
                { xi.mod.ACC,  -20 },
            })
        end
    end)
end

-----------------------------------
-- Crystal Definition (DRK = 8)
-----------------------------------
if xi.job and xi.job.DRK then
    spec.registerJob(xi.job.DRK, 'DRK',
    {
        {
            id          = 1,
            key         = DREADNOUGHT_KEY,
            name        = 'Dreadnought',
            role        = 'Blood-Pool & Dread Spikes Tank',
            icon        = 'dreadnought',
            reqLevel    = 10,
            extraTraits = { TRAIT_DREADNOUGHTS_CARAPACE },
            extraAbilities = function(_player, _lvl)
                return { ABIL_ABYSSAL_CLEAVE, ABIL_DREAD_BASTION }
            end,
            description = 'Abyssal blood-knight tank (Lv10+): requires a Scythe to unlock Max-HP scaled Drain II Blood-Pool overcap, Blood Tithe Absorb weaving, costed Dread Spikes barriers, and Scythe WS Blood Reap sustain.',
            highlights =
            {
                'Passives (Lv10/30/50/70+): +15/20/25/32% Max HP, +8/14/20/26 VIT & INT, +12/18/24/30% DEF, -8/11/14/18% DT, +60/80/100/120 Enmity & +25/35/45/60% Enmity Retention.',
                'Scythe & Dark Magic Mastery: +15/25/35/50 Scythe & Dark Magic skill, +10/14/18/22% Parry Rate (Inquartata), -20/30/40/50% Dark Magic Cast Time & 100% SIRD on Dark Magic.',
                'Blood-Pool, Blood Tithe & Dread Spikes: Drain II (30s CD) scales off 12/15/18/22% Max HP + VIT (+25% Max HP overcap 30s); Absorb-STR/VIT/TP/ACC (18s shared CD, instant) restore +6% Max MP & grant +1 Blood Tithe (max 3); Dread Spikes (45s CD, instant, 10% Current HP cost) builds 25% + 5%/Tithe Max HP shield (up to 40%).',
                'Scythe WS Reap & Souleater: Scythe WSs heal 5/6/7/8% Max HP (10/12/14/16% w/ Drain II or Souleater; 2x in Dread Bastion), extend Drain II +6s, and inflict Cripple (-15% ATTP / -15 MATT / -20 ACC, 15s); Souleater (45s CD, 12s, -12% DT) spends 2% HP/hit for VE + Blood Tithe + Blood Reap (+20% WS heal).',
                'JAs: Abyssal Cleave (25s CD, 2s Stun, heavy VE, Breach -15% DEF/-15 MDEF, +8% MP, +1 Blood Tithe); Dread Bastion (60s CD, 12s: -18% DT, Knockback Immune, +35 Enmity, 2s AoE VE pulses, 2x WS heal); Blood Weapon (+4% Max HP/swing, +50 Enmity, -20% DT); Arcane Circle (shared Ward -10% DMG/+25 MEVA).',
            },
            mods = function(player, lvl)
                local isWiki = (player == nil) or (not player.getEquipID)
                local list =
                {
                    { xi.mod.HPP,                   scaleTier(lvl, 15, 20, 25, 32) },
                    { xi.mod.VIT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.INT,                   scaleTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                  scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.DMG,                   scaleTier(lvl, -800, -1100, -1400, -1800) },
                    { xi.mod.ENMITY,                scaleTier(lvl, 60, 80, 100, 120) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                }

                if isWiki then
                    table.insert(list, { xi.mod.SCYTHE,          scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(list, { xi.mod.DARK,            scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(list, { xi.mod.INQUARTATA,      scaleTier(lvl, 10, 14, 18, 22) })
                    table.insert(list, { xi.mod.DARK_MAGIC_CAST, -scaleTier(lvl, 20, 30, 40, 50) })
                    table.insert(list, { xi.mod.SPELLINTERRUPT,  100 })
                end

                return list
            end,
            onApply = function(player)
                grantDreadnoughtSpells(player)
                attachDrkListeners(player)
                syncDrkWeaponMods(player, true)
            end,
            onRemove = function(player)
                if player ~= nil and player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_BLOOD_CARAPACE)
                    player:delStatusEffectSilent(EFFECT_DREAD_BASTION)
                end
                if player ~= nil and player.setLocalVar then
                    player:setLocalVar('OX_DRK_TITHE', 0)
                    player:setLocalVar('OX_DRK_TITHE_EXP', 0)
                    player:setLocalVar('OX_DRK_BLOOD_REAP_EXP', 0)
                end
                clearDrkWeaponMods(player)
                detachDrkListeners(player)
            end,
        },
    })
end

return m
