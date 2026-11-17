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

local function refreshBloodPoolDuration(player)
    if player == nil or not player.getStatusEffect then
        return
    end
    local existing = player:getStatusEffect(xi.effect.MAX_HP_BOOST)
    if existing ~= nil and (existing:getPower() or 0) == 0 and (existing:getSubPower() or 0) > 0 then
        local subP = existing:getSubPower()
        if player.delStatusEffectSilent then
            player:delStatusEffectSilent(xi.effect.MAX_HP_BOOST)
        end
        player:addStatusEffect(xi.effect.MAX_HP_BOOST,
        {
            power    = 0,
            duration = 30,
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
        table.insert(mods, { xi.mod.PARRY,           scaleTier(lvl, 14, 20, 26, 32) })
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

    -- Reflect 25% of absorbed physical damage as volatile enmity
    if attacker ~= nil and attacker.isMob and attacker:isMob() and attacker.addEnmity then
        local ve = math.max(1, math.floor(absorbed * 0.25))
        attacker:addEnmity(defender, 0, ve)
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

-- Drain II: 0 MP, 15s recast, +25% Max HP overcap for 30s
m:addOverride('xi.actions.spells.black.drain_ii.onMagicCastingCheck', function(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        if spell ~= nil and spell.setMPCost then
            spell:setMPCost(0)
        end
    end
    return super(caster, target, spell)
end)

m:addOverride('xi.actions.spells.black.drain_ii.onSpellCast', function(caster, target, spell)
    local dmg = super(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        if dmg > 0 then
            applyBloodPoolOvercap(caster, dmg)
        end
        if caster.timer then
            caster:timer(50, function(actor)
                if actor ~= nil and actor.addRecast then
                    actor:addRecast(xi.recast.MAGIC, SPELL_DRAIN_II, 15)
                end
            end)
        end
    end
    return dmg
end)

-- Drain III: also enforces Dreadnought Blood-Pool overcap if cast
m:addOverride('xi.actions.spells.black.drain_iii.onSpellCast', function(caster, target, spell)
    local dmg = super(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) and dmg > 0 then
        applyBloodPoolOvercap(caster, dmg)
    end
    return dmg
end)

-- Dread Spikes: instant-cast, 30s recast, 35% Max HP dark blood-shield
m:addOverride('xi.actions.spells.black.dread_spikes.onMagicCastingCheck', function(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        if spell ~= nil and spell.setCastTime then
            spell:setCastTime(0)
        end
    end
    return super(caster, target, spell)
end)

m:addOverride('xi.actions.spells.black.dread_spikes.onSpellCast', function(caster, target, spell)
    if isDrkSpec(caster, DREADNOUGHT_KEY) and isScytheEquipped(caster) then
        local maxHp  = caster:getMaxHP() or 0
        local shield = math.max(1, math.floor(maxHp * 0.35))
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
                    actor:addRecast(xi.recast.MAGIC, SPELL_DREAD_SPIKES, 30)
                end
            end)
        end
        return xi.effect.DREAD_SPIKES
    end
    return super(caster, target, spell)
end)

-- Absorb-VIT / Absorb-TP / Absorb-STR: instant-cast, 15s shared cycle, heavy VE, +8% Max MP
local ABSORB_TANK_SPELLS =
{
    { name = 'absorb-vit', id = SPELL_ABSORB_VIT },
    { name = 'absorb-tp',  id = SPELL_ABSORB_TP  },
    { name = 'absorb-str', id = SPELL_ABSORB_STR },
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
                target:addEnmity(caster, 0, 600)
            end

            local maxMp = caster:getMaxMP() or 0
            if maxMp > 0 and caster.addMP then
                caster:addMP(math.max(1, math.floor(maxMp * 0.08)))
            end

            if caster.timer then
                caster:timer(50, function(actor)
                    if actor ~= nil and actor.addRecast then
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_VIT, 15)
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_TP,  15)
                        actor:addRecast(xi.recast.MAGIC, SPELL_ABSORB_STR, 15)
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
    effect:addMod(xi.mod.DMG, -2000)
end)

m:addOverride('xi.effects.blood_carapace.onEffectLose', function(_target, _effect)
end)

m:addOverride('xi.effects.dread_bastion.onEffectGain', function(_target, effect)
    effect:addMod(xi.mod.DMG, -2000)
    effect:addMod(xi.mod.KNOCKBACK_REDUCTION, 10)
end)

m:addOverride('xi.effects.dread_bastion.onEffectTick', function(target, _effect)
    if target == nil or not isDrkSpec(target, DREADNOUGHT_KEY) then
        return
    end
    if target.getNearbyEntities then
        local nearby = target:getNearbyEntities(10)
        if type(nearby) == 'table' then
            for _, ent in ipairs(nearby) do
                if
                    ent ~= nil and
                    ent.isMob and ent:isMob() and
                    ent.isAlive and ent:isAlive() and
                    ent.isEngaged and ent:isEngaged() and
                    ent.addEnmity
                then
                    ent:addEnmity(target, 0, 220)
                end
            end
        end
    end
end)

m:addOverride('xi.effects.dread_bastion.onEffectLose', function(_target, _effect)
end)

-----------------------------------
-- Native DRK Job Ability Reworks
-----------------------------------
-- Souleater -> Blood Carapace (20s CD, 10s duration, no HP drain, -20% DT, 15% melee lifesteal)
m:addOverride('xi.actions.abilities.souleater.onAbilityCheck', function(player, target, ability)
    if isDrkSpec(player, DREADNOUGHT_KEY) and ability ~= nil and ability.setRecast then
        ability:setRecast(20)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.dark_knight.useSouleater', function(player, target, ability)
    if isDrkSpec(player, DREADNOUGHT_KEY) then
        local iconId = (xi.effect and xi.effect.SOULEATER) or EFFECT_BLOOD_CARAPACE
        if player.delStatusEffectSilent then
            player:delStatusEffectSilent(EFFECT_BLOOD_CARAPACE)
        end
        applyCustomTimedEffect(player, EFFECT_BLOOD_CARAPACE, 15, 10, player, 0, iconId, 0, 1)
        return EFFECT_BLOOD_CARAPACE
    end
    return super(player, target, ability)
end)

-- Arcane Circle -> Party -12% MDT & +20 MEVA
m:addOverride('xi.effects.arcane_circle.onEffectGain', function(target, effect)
    super(target, effect)
    local origin = effect.getOriginator and effect:getOriginator() or nil
    if isDrkSpec(origin or target, DREADNOUGHT_KEY) then
        effect:addMod(xi.mod.DMGMAGIC, -1200)
        effect:addMod(xi.mod.MEVA, 20)
    end
end)

-- Blood Weapon -> +50 Enmity, -20% DT, 50% physical lifesteal for 30s
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
        target:addEnmity(player, 200, 750)
    end

    -- Stun target
    if
        not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
        not xi.data.statusEffect.isTargetResistant(player, target, xi.effect.STUN) and
        not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
    then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 4, origin = player })
    end

    -- Inflict -20 Accuracy & -15% Defense Down for 12s
    target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = 20, duration = 12, origin = player })
    target:addStatusEffect(xi.effect.DEFENSE_DOWN,  { power = 15, duration = 12, origin = player })

    -- Restore 12% Max HP + 10% Max MP
    local maxHp = player:getMaxHP() or 0
    local maxMp = player:getMaxMP() or 0
    if maxHp > 0 and player.addHP then
        player:addHP(math.max(1, math.floor(maxHp * 0.12)))
    end
    if maxMp > 0 and player.addMP then
        player:addMP(math.max(1, math.floor(maxMp * 0.10)))
    end

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
    local maxHp  = player:getMaxHP() or 0
    local shield = math.max(1, math.floor(maxHp * 0.40))

    if player.delStatusEffectSilent then
        player:delStatusEffectSilent(xi.effect.DREAD_SPIKES)
        player:delStatusEffectSilent(EFFECT_DREAD_BASTION)
    end

    player:addStatusEffect(xi.effect.DREAD_SPIKES,
    {
        power    = 1,
        duration = 180,
        origin   = player,
        subPower = shield,
        tier     = 1,
    })

    local iconId = (xi.effect and xi.effect.DARK_SEAL) or EFFECT_DREAD_BASTION
    applyCustomTimedEffect(player, EFFECT_DREAD_BASTION, 1, 10, player, 0, iconId, 2, 1)
    return EFFECT_DREAD_BASTION
end)

-----------------------------------
-- Listeners (Equip, Tick, Melee Lifesteal, Scythe WS)
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

        if actor.hasStatusEffect and actor:hasStatusEffect(EFFECT_BLOOD_CARAPACE) then
            local dmg = action:getParam(target:getID()) or 0
            if dmg > 0 and actor.addHP then
                actor:addHP(math.max(1, math.floor(dmg * 0.15)))
            end
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_DRK_WS', function(actor, target, ws, _tp, _action, dmg)
        if not isDrkSpec(actor, DREADNOUGHT_KEY) then
            return
        end

        local d = tonumber(dmg) or 0
        if d > 0 and actor.hasStatusEffect and actor:hasStatusEffect(xi.effect.BLOOD_WEAPON) and actor.addHP then
            actor:addHP(math.max(1, math.floor(d * 0.50)))
        end

        if not isScytheEquipped(actor) then
            return
        end

        local wsId = (type(ws) == 'number') and ws or (ws ~= nil and ws.getID and ws:getID() or 0)
        if not VAMPIRIC_SCYTHE_WS[wsId] then
            return
        end

        local lvl     = actor:getMainLvl() or 1
        local maxHp   = actor:getMaxHP() or 0
        local healPct = scaleTier(lvl, 0.10, 0.13, 0.16, 0.20)
        if maxHp > 0 and actor.addHP then
            actor:addHP(math.max(1, math.floor(maxHp * healPct)))
        end

        refreshBloodPoolDuration(actor)

        if target ~= nil and target.isAlive and target:isAlive() and target.getID and target:getID() ~= actor:getID() then
            target:addStatusEffect(xi.effect.ATTACK_DOWN,    { power = 15, duration = 15, origin = actor })
            target:addStatusEffect(xi.effect.MAGIC_ATK_DOWN, { power = 15, duration = 15, origin = actor })
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
            description = 'Abyssal blood-knight tank (Lv10+): requires a Scythe to unlock Blood-Pool HP Overcap (Drain II/III inflating Max HP), instant Dread Spikes barriers, and vampiric Scythe WS sustain.',
            highlights =
            {
                'Passives (Lv10/30/50/70+): +15/20/25/32% Max HP, +8/14/20/26 VIT & INT, +12/18/24/30% DEF, -8/11/14/18% DT, +25/35/45/60 Enmity & +25/35/45/60% Enmity Retention.',
                'Scythe & Dark Magic Mastery: +15/25/35/50 Scythe & Dark Magic skill, +14/20/26/32% Parry Rate, +20/30/40/50% Fast Cast & 100% SIRD on Dark Magic casts.',
                'Blood-Pool & Dread Spikes: Unlocks Lv.10 Drain II (15s CD, 0 MP, +25% Max HP overcap 30s) & instant Dread Spikes (30s CD, 35% Max HP shield, 25% absorbed dmg as VE); Absorb-VIT/TP/STR instant on 15s shared CD (+8% Max MP & heavy VE).',
                'Vampiric Scythe WS Loop: Scythe WSs heal 10/13/16/20% Max HP, refresh Drain II overcap duration, and inflict Abyssal Rot (-15% ATK/MATK Down 15s).',
                'Tank Tradeoff & JAs: -20% Attack/Ranged Attack & -15% WSD; Souleater becomes Blood Carapace (20s CD, 10s: no HP drain, -20% DT, 15% melee lifesteal); enhances Arcane Circle (party -12% MDT & +20 MEVA) & Blood Weapon (50% lifesteal, +50 Enmity, -20% DT).',
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
                    { xi.mod.ENMITY,                scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ENMITY_LOSS_REDUCTION, scaleTier(lvl, 25, 35, 45, 60) },
                    { xi.mod.ALL_WSDMG_ALL_HITS,    -15 },
                }

                if isWiki then
                    table.insert(list, { xi.mod.SCYTHE,          scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(list, { xi.mod.DARK,            scaleTier(lvl, 15, 25, 35, 50) })
                    table.insert(list, { xi.mod.PARRY,           scaleTier(lvl, 14, 20, 26, 32) })
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
                clearDrkWeaponMods(player)
                detachDrkListeners(player)
            end,
        },
    })
end

return m
