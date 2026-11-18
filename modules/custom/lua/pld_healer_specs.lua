-----------------------------------
-- OverlordsXI Paladin Crystal Spec: Templar (TMP | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set templar)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/pld_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/paladin')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_pld_healer_specs')

local spec = xi.overlords.spec
local TEMPLAR_KEY = 'templar'

-- Custom Trait ID (170; Perpetual Majesty)
local TRAIT_PERPETUAL_MAJESTY = 170

-- Custom Ability IDs (458-459; recastIds 82-83)
local ABIL_HOLY_RADIANCE    = 458
local ABIL_CRUSADERS_AEGIS  = 459

-- Custom Status Effect IDs (863-864; registered in patch 0028)
local EFFECT_LIGHTS_GRACE    = 863
local EFFECT_CRUSADERS_AEGIS = 864

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.HOLY_RADIANCE   = ABIL_HOLY_RADIANCE
xi.jobAbility.CRUSADERS_AEGIS = ABIL_CRUSADERS_AEGIS

xi.effect = xi.effect or {}
xi.effect.LIGHTS_GRACE    = EFFECT_LIGHTS_GRACE
xi.effect.CRUSADERS_AEGIS = EFFECT_CRUSADERS_AEGIS

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.holy_radiance   = xi.actions.abilities.holy_radiance or {}
xi.actions.abilities.crusaders_aegis = xi.actions.abilities.crusaders_aegis or {}

xi.effects = xi.effects or {}
xi.effects.lights_grace    = xi.effects.lights_grace or {}
xi.effects.crusaders_aegis = xi.effects.crusaders_aegis or {}

local function isTemplar(entity)
    return H.isSpecActive(entity, xi.job.PLD, TEMPLAR_KEY)
end

local function hasClubAndShield(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local main = player:getEquippedItem(xi.slot.MAIN)
    local sub  = player:getEquippedItem(xi.slot.SUB)
    return main ~= nil and main.getSkillType and main:getSkillType() == xi.skill.CLUB and
           sub ~= nil and sub.isShield and sub:isShield()
end

local function hasShield(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local sub = player:getEquippedItem(xi.slot.SUB)
    return sub ~= nil and sub.isShield and sub:isShield()
end

local MAJESTY_CURE_SPELLS =
{
    [xi.magic.spell.CURE]     = true,
    [xi.magic.spell.CURE_II]  = true,
    [xi.magic.spell.CURE_III] = true,
    [xi.magic.spell.CURE_IV]  = true,
    [xi.magic.spell.CURE_V]   = true,
    [xi.magic.spell.CURE_VI]  = true,
}

local BEACON_WS_IDS =
{
    [163] = true, -- Starlight
    [164] = true, -- Moonlight
    [165] = true, -- True Strike
    [166] = true, -- Judgment
    [169] = true, -- Black Halo
}

local function triggerBeaconPulse(pld, mult)
    if not isTemplar(pld) then
        return
    end
    local pct = H.scaleTier(pld:getMainLvl(), 8, 11, 14, 18) * (mult or 1)
    local healAmt = math.floor(pld:getMaxHP() * (pct / 100))
    local lowestMember = pld
    local lowestRatio = pld:getHP() / math.max(1, pld:getMaxHP())
    H.forEachPartyMemberInRange(pld, 12, false, function(member)
        local r = member:getHP() / math.max(1, member:getMaxHP())
        if r < lowestRatio then
            lowestRatio = r
            lowestMember = member
        end
    end)
    H.healEntity(pld, lowestMember, healAmt)
    H.restoreMpPct(pld, 5)
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.lights_grace.onEffectGain', function(target, effect)
    local total = effect:getPower() or 15
    if xi.overlords and xi.overlords.regen and xi.overlords.regen.consumeEffectRegen then
        total = xi.overlords.regen.consumeEffectRegen(target, effect, 15, 220)
    end
    effect:addMod(xi.mod.REGEN, total)
end)

m:addOverride('xi.effects.crusaders_aegis.onEffectGain', function(target, effect)
    effect:addMod(xi.mod.DMG, -1500)
    effect:addMod(xi.mod.KNOCKBACK_IMMUNE, 1)
end)

-----------------------------------
-- Listeners & Gear Mods
-----------------------------------
local function syncTemplarMods(player)
    if player == nil then
        return
    end
    local sird = (isTemplar(player) and hasShield(player)) and 100 or 0
    local prev = player:getLocalVar('OX_TMP_SIRD_MOD')
    if prev ~= sird then
        if prev ~= 0 then
            player:delMod(xi.mod.SPELLINTERRUPT, prev)
        end
        if sird ~= 0 then
            player:addMod(xi.mod.SPELLINTERRUPT, sird)
        end
        player:setLocalVar('OX_TMP_SIRD_MOD', sird)
    end
end

local function attachTemplarListeners(player)
    if player == nil or player:getLocalVar('OX_TMP_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_TMP_LISTENERS', 1)

    player:addListener('EQUIP_CHANGE', 'OX_TMP_EQUIP', function(p)
        syncTemplarMods(p)
    end)

    player:addListener('ATTACK', 'OX_TMP_ATTACK', function(attacker)
        if isTemplar(attacker) then
            local mult = attacker:hasStatusEffect(EFFECT_CRUSADERS_AEGIS) and 2 or 1
            triggerBeaconPulse(attacker, mult)
        end
    end)

    player:addListener('SHIELD_BLOCK', 'OX_TMP_BLOCK', function(defender)
        if isTemplar(defender) and defender:hasStatusEffect(EFFECT_CRUSADERS_AEGIS) then
            triggerBeaconPulse(defender, 2)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_TMP_WS', function(caster, _target, ws)
        if not isTemplar(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, BEACON_WS_IDS, { [xi.skill.CLUB] = true }) then
            local mult = caster:hasStatusEffect(EFFECT_CRUSADERS_AEGIS) and 2 or 1
            triggerBeaconPulse(caster, mult)
        end
    end)

    player:addListener('MAGIC_USE', 'OX_TMP_MAGIC', function(caster, target, spell, action)
        if not isTemplar(caster) or spell == nil then
            return
        end
        local spellId = spell:getID()
        if MAJESTY_CURE_SPELLS[spellId] then
            local healAmt = action and action:getParam() or math.floor(caster:getMaxHP() * 0.22)
            local cleanseDiv = caster:hasStatusEffect(xi.effect.DIVINE_SEAL)
            H.forEachPartyMemberInRange(caster, 15, false, function(member)
                if member ~= target then
                    local _, overheal = H.healEntity(caster, member, healAmt)
                    if overheal > 0 then
                        if xi.overlords and xi.overlords.regen and xi.overlords.regen.stampRegenContext then
                            xi.overlords.regen.stampRegenContext(caster, member, 220)
                        end
                        H.applyCustomTimedEffect(member, EFFECT_LIGHTS_GRACE, 15, 10, caster, 0, xi.effect.REGEN, 1)
                        if xi.overlords and xi.overlords.regen and xi.overlords.regen.clearRegenContext then
                            xi.overlords.regen.clearRegenContext(member)
                        end
                    end
                elseif target ~= nil and target:getHP() >= target:getMaxHP() then
                    if xi.overlords and xi.overlords.regen and xi.overlords.regen.stampRegenContext then
                        xi.overlords.regen.stampRegenContext(caster, target, 220)
                    end
                    H.applyCustomTimedEffect(target, EFFECT_LIGHTS_GRACE, 15, 10, caster, 0, xi.effect.REGEN, 1)
                    if xi.overlords and xi.overlords.regen and xi.overlords.regen.clearRegenContext then
                        xi.overlords.regen.clearRegenContext(target)
                    end
                end
                if cleanseDiv then
                    H.cleanseDebuffs(member, 2)
                end
            end)
        end
    end)
end

local function detachTemplarListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_TMP_LISTENERS', 0)
    player:removeListener('OX_TMP_EQUIP')
    player:removeListener('OX_TMP_ATTACK')
    player:removeListener('OX_TMP_BLOCK')
    player:removeListener('OX_TMP_WS')
    player:removeListener('OX_TMP_MAGIC')
    local prev = player:getLocalVar('OX_TMP_SIRD_MOD')
    if prev ~= 0 then
        player:delMod(xi.mod.SPELLINTERRUPT, prev)
        player:setLocalVar('OX_TMP_SIRD_MOD', 0)
    end
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.majesty.onAbilityCheck', function(player, target, ability)
    if isTemplar(player) then
        ability:setRecast(0)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.divine_seal.onUseAbility', function(player, target, ability)
    if isTemplar(player) then
        ability:setRecast(20)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.chivalry.onUseAbility', function(player, target, ability)
    if isTemplar(player) then
        ability:setRecast(15)
        local mpAmt = H.restoreMpPct(player, 40)
        H.healPartyPct(player, 15, 15, false, false)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_MP)
        return mpAmt
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.rampart.onUseAbility', function(player, target, ability)
    local res = super(player, target, ability)
    if isTemplar(player) then
        H.forEachPartyMemberInRange(player, 15, false, function(member)
            H.applyCustomTimedEffect(member, EFFECT_CRUSADERS_AEGIS, 15, 15, player, 0, xi.effect.RAMPART, 1)
        end)
    end
    return res
end)

m:addOverride('xi.actions.abilities.invincible.onUseAbility', function(player, target, ability)
    if isTemplar(player) then
        H.forEachPartyMemberInRange(player, 15, false, function(member)
            member:setHP(member:getMaxHP())
            H.cleanseDebuffs(member, 10)
            H.applyCustomTimedEffect(member, EFFECT_CRUSADERS_AEGIS, 20, 15, player, 0, xi.effect.INVINCIBLE, 2)
        end)
        return 0
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (458-459)
-----------------------------------
m:addOverride('xi.actions.abilities.holy_radiance.onAbilityCheck', function(player, _target, _ability)
    if not isTemplar(player) or not hasClubAndShield(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.holy_radiance.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 25, 15, false, false)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.cleanseDebuffs(member, 2)
    end)
    H.restoreMpPct(player, 10)
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.crusaders_aegis.onAbilityCheck', function(player, _target, _ability)
    if not isTemplar(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.crusaders_aegis.onUseAbility', function(player, _target, ability)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyCustomTimedEffect(member, EFFECT_CRUSADERS_AEGIS, 15, 10, player, 0, xi.effect.PALISADE, 1)
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_CRUSADERS_AEGIS
end)

-----------------------------------
-- Crystal Definition (PLD = 7)
-----------------------------------
if xi.job and xi.job.PLD then
    spec.registerCrystal(xi.job.PLD,
    {
        id          = 2,
        key         = TEMPLAR_KEY,
        name        = 'Templar',
        abr         = 'TMP',
        role        = 'Healer',
        icon        = 'templar',
        reqLevel    = 10,
        extraTraits = { TRAIT_PERPETUAL_MAJESTY },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { 394, 158, ABIL_HOLY_RADIANCE, ABIL_CRUSADERS_AEGIS }
            end
            return {}
        end,
        description = 'Frontline Holy Light & Perpetual Majesty AoE Cure Crusader (Lv10+, Club+Shield): splashes single-target Cures party-wide with Light\'s Grace HoTs, pulses Beacon of Light on melee/WS, and protects allies with Crusader\'s Aegis.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/26% HP & MP, +10/16/22/28 MND & VIT, +18/26/34/42% Cure Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +4/6/8/12 MP/tick Refresh, +10/14/18/22% Block, 100% SIRD w/ Shield.',
            'Perpetual Majesty: Always active @ Lv10+ (0s lockout); single-target Cures splash to party (15y) at 100% potency; overhealing grants Light\'s Grace (15 + 2.2% Max HP/tick HoT, 10s).',
            'Beacon of Light: Melee hits and Club WSs heal the lowest-HP ally (12y) for 8/11/14/18% PLD Max HP and restore +5% Max MP.',
            'JA Enhancements: Divine Seal (20s CD, 2-debuff party cleanse), Chivalry (15s CD, 40% MP + 15% AoE heal), Rampart (-15% DT aura), Sanctuary Benediction (replaces Invincible: 100% party heal/cleanse + -20% DT).',
            'Holy Radiance (20s CD, Club+Shield: 25% HP AoE heal + 2-debuff cleanse + 10% MP) & Crusader\'s Aegis (25s CD, 10s -15% DT + Knockback Immune + 2x Beacon).',
        },
        mods = function(player, lvl)
            local isWiki = (player == nil) or (not player.getEquipID)
            local list =
            {
                { xi.mod.HPP,             H.scaleTier(lvl, 14, 18, 22, 26) },
                { xi.mod.MPP,             H.scaleTier(lvl, 14, 18, 22, 26) },
                { xi.mod.MND,             H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.VIT,             H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CURE_POTENCY,    H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.FASTCAST,        H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,          -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,         H.scaleTier(lvl, 4, 6, 8, 12) },
                { xi.mod.HEALING,         H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.DIVINE,          H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.ENHANCING,       H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.CLUB,            H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.SHIELD,          H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.SHIELDBLOCKRATE, H.scaleTier(lvl, 10, 14, 18, 22) },
            }
            if isWiki then
                table.insert(list, { xi.mod.SPELLINTERRUPT, 100 })
            end
            return list
        end,
        onApply = function(player)
            attachTemplarListeners(player)
            syncTemplarMods(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_LIGHTS_GRACE)
                player:delStatusEffectSilent(EFFECT_CRUSADERS_AEGIS)
            end
            detachTemplarListeners(player)
        end,
    })
end

return m
