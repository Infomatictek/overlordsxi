-----------------------------------
-- OverlordsXI White Mage Crystal Spec: Bishop (BSH | Tier-5 Pure Healer)
-- Unlocks @ Lv. 10 (!spec set bishop)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/white_mage')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_whm_specs')

local spec = xi.overlords.spec
local BISHOP_KEY = 'bishop'

-- Custom Trait ID (169; Solace Conduit)
local TRAIT_SOLACE_CONDUIT = 169

-- Custom Ability IDs (456-457; recastIds 55-56)
local ABIL_DIVINE_VEIL     = 456
local ABIL_SANCTUARY_PULSE = 457

-- Custom Status Effect IDs (860-862; registered in patch 0028)
local EFFECT_SOLACE_WARD  = 860
local EFFECT_SACRED_GRACE = 861
local EFFECT_DIVINE_VEIL  = 862

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.DIVINE_VEIL     = ABIL_DIVINE_VEIL
xi.jobAbility.SANCTUARY_PULSE = ABIL_SANCTUARY_PULSE

xi.effect = xi.effect or {}
xi.effect.SOLACE_WARD  = EFFECT_SOLACE_WARD
xi.effect.SACRED_GRACE = EFFECT_SACRED_GRACE
xi.effect.DIVINE_VEIL  = EFFECT_DIVINE_VEIL

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.divine_veil     = xi.actions.abilities.divine_veil or {}
xi.actions.abilities.sanctuary_pulse = xi.actions.abilities.sanctuary_pulse or {}

xi.effects = xi.effects or {}
xi.effects.solace_ward  = xi.effects.solace_ward or {}
xi.effects.sacred_grace = xi.effects.sacred_grace or {}
xi.effects.divine_veil  = xi.effects.divine_veil or {}

local function isBishop(entity)
    return H.isSpecActive(entity, xi.job.WHM, BISHOP_KEY)
end

local SINGLE_CURE_SPELLS =
{
    [xi.magic.spell.CURE]     = true,
    [xi.magic.spell.CURE_II]  = true,
    [xi.magic.spell.CURE_III] = true,
    [xi.magic.spell.CURE_IV]  = true,
    [xi.magic.spell.CURE_V]   = true,
    [xi.magic.spell.CURE_VI]  = true,
}

local AOE_CURE_SPELLS =
{
    [xi.magic.spell.CURAGA]     = true,
    [xi.magic.spell.CURAGA_II]  = true,
    [xi.magic.spell.CURAGA_III] = true,
    [xi.magic.spell.CURAGA_IV]  = true,
    [xi.magic.spell.ESUNA]      = true,
    [xi.magic.spell.AUSPICE]    = true,
}

local SMITE_SPELLS =
{
    [xi.magic.spell.BANISH]     = true,
    [xi.magic.spell.BANISH_II]  = true,
    [xi.magic.spell.BANISH_III] = true,
    [xi.magic.spell.HOLY]       = true,
}

local BISHOP_WS_IDS =
{
    [163] = true, -- Starlight
    [164] = true, -- Moonlight
    [172] = true, -- Mystic Boon
    [170] = true, -- Hexa Strike
    [183] = true, -- Spirit Taker
}

local function hasClubAndShield(player)
    if player == nil or not player.getEquippedItem then
        return false
    end
    local main = player:getEquippedItem(xi.slot.MAIN)
    local sub  = player:getEquippedItem(xi.slot.SUB)
    return main ~= nil and main.getSkillType and main:getSkillType() == xi.skill.CLUB and
           sub ~= nil and sub.isShield and sub:isShield()
end

local function grantSacredGrace(player, delta)
    if not isBishop(player) then
        return 0
    end
    local eff = player:getStatusEffect(EFFECT_SACRED_GRACE)
    local cur = eff and (eff:getPower() or 0) or 0
    local nxt = math.min(3, cur + (delta or 1))
    H.applyCustomTimedEffect(player, EFFECT_SACRED_GRACE, nxt, 30, player, 0, xi.effect.SACROSANCTITY, 1)
    return nxt
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.solace_ward.onEffectGain', function(target, effect)
    effect:addMod(xi.mod.DMG, -800)
end)

m:addOverride('xi.effects.divine_veil.onEffectGain', function(_target, _effect)
    -- Party -DT and MEVA are routed through EFF_OX_SUP_WARD (capped at -15% DMG / +35 MEVA)
end)

-----------------------------------
-- Listeners (Solace Ward, Sacred Grace, SIRD)
-----------------------------------
local function syncWhmGearMods(player)
    if player == nil then
        return
    end
    local lvl = player:getMainLvl()
    local block = 0
    if isBishop(player) and hasClubAndShield(player) then
        block = H.scaleTier(lvl, 10, 14, 18, 22)
    end
    local prev = player:getLocalVar('OX_BSH_SHIELD_MOD')
    if prev ~= block then
        if prev ~= 0 then
            player:delMod(xi.mod.SHIELDBLOCKRATE, prev)
        end
        if block ~= 0 then
            player:addMod(xi.mod.SHIELDBLOCKRATE, block)
        end
        player:setLocalVar('OX_BSH_SHIELD_MOD', block)
    end

    local sird = 0
    if isBishop(player) and (player:hasStatusEffect(xi.effect.AFFLATUS_SOLACE) or player:hasStatusEffect(xi.effect.AFFLATUS_MISERY)) then
        sird = 100
    end
    local prevSird = player:getLocalVar('OX_BSH_SIRD_MOD')
    if prevSird ~= sird then
        if prevSird ~= 0 then
            player:delMod(xi.mod.SPELLINTERRUPT, prevSird)
        end
        if sird ~= 0 then
            player:addMod(xi.mod.SPELLINTERRUPT, sird)
        end
        player:setLocalVar('OX_BSH_SIRD_MOD', sird)
    end
end

local function attachBishopListeners(player)
    if player == nil or player:getLocalVar('OX_BSH_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_BSH_LISTENERS', 1)

    player:addListener('EQUIP_CHANGE', 'OX_BSH_EQUIP', function(p)
        syncWhmGearMods(p)
    end)

    player:addListener('EFFECT_GAIN', 'OX_BSH_EFF_GAIN', function(p, eff)
        if eff and (eff:getEffectType() == xi.effect.AFFLATUS_SOLACE or eff:getEffectType() == xi.effect.AFFLATUS_MISERY) then
            syncWhmGearMods(p)
        end
    end)

    player:addListener('EFFECT_LOSE', 'OX_BSH_EFF_LOSE', function(p, eff)
        if eff and (eff:getEffectType() == xi.effect.AFFLATUS_SOLACE or eff:getEffectType() == xi.effect.AFFLATUS_MISERY) then
            syncWhmGearMods(p)
        end
    end)

    player:addListener('MAGIC_USE', 'OX_BSH_MAGIC_USE', function(caster, target, spell, action)
        if not isBishop(caster) or spell == nil then
            return
        end
        local spellId = spell:getID()
        local lvl = caster:getMainLvl()

        -- Sacred Grace Smite-Weaving
        if SMITE_SPELLS[spellId] then
            grantSacredGrace(caster, 1)
            H.restoreMpPct(caster, 6)
        end

        -- 3-stack Sacred Grace: AoE Cure / Esuna / Auspice Regen pulse & consume
        if AOE_CURE_SPELLS[spellId] then
            local grace = caster:getStatusEffect(EFFECT_SACRED_GRACE)
            if grace and (grace:getPower() or 0) >= 3 then
                caster:delStatusEffectSilent(EFFECT_SACRED_GRACE)
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    if xi.overlords and xi.overlords.regen and xi.overlords.regen.applyHybridRegen then
                        xi.overlords.regen.applyHybridRegen(caster, member, xi.effect.REGEN, 15, 220, 10, 3, 3)
                    else
                        member:addStatusEffect(xi.effect.REGEN, { power = 15, duration = 10, origin = caster, tier = 3 })
                    end
                end)
            end
        end

        -- Single-target Cure -> Solace Ward + Divine Seal bonus + Divine Veil splash
        if SINGLE_CURE_SPELLS[spellId] and target ~= nil then
            local ratio = H.scaleTier(lvl, 35, 40, 45, 50)
            local healed = action and action:getParam() or math.floor(target:getMaxHP() * 0.25)
            local barrier = math.floor(math.max(50, healed) * (ratio / 100))
            if caster:hasStatusEffect(xi.effect.DIVINE_SEAL) then
                barrier = barrier + math.floor(target:getMaxHP() * 0.15)
            end

            local applySolace = function(unit)
                local cap = math.floor(unit:getMaxHP() * 0.30)
                H.applyStoneskinBarrier(unit, barrier, cap, 8, caster)
                H.applyCustomTimedEffect(unit, EFFECT_SOLACE_WARD, 8, 8, caster, 0, xi.effect.AFFLATUS_SOLACE, 1)
            end

            if caster:hasStatusEffect(EFFECT_DIVINE_VEIL) then
                caster:delStatusEffectSilent(EFFECT_DIVINE_VEIL)
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    if member ~= target then
                        H.healEntity(caster, member, healed)
                    end
                    applySolace(member)
                end)
            else
                applySolace(target)
            end
        elseif (spellId == xi.magic.spell.ERASE or spellId == xi.magic.spell.ESUNA) and caster:hasStatusEffect(EFFECT_DIVINE_VEIL) then
            caster:delStatusEffectSilent(EFFECT_DIVINE_VEIL)
            H.forEachPartyMemberInRange(caster, 15, false, function(member)
                H.cleanseDebuffs(member, 2)
            end)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_BSH_WS_USE', function(caster, _target, ws)
        if not isBishop(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, BISHOP_WS_IDS, { [xi.skill.CLUB] = true, [xi.skill.STAFF] = true }) then
            grantSacredGrace(caster, 1)
            H.restoreMpPct(caster, 6)
        end
    end)
end

local function detachBishopListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_BSH_LISTENERS', 0)
    player:removeListener('OX_BSH_EQUIP')
    player:removeListener('OX_BSH_EFF_GAIN')
    player:removeListener('OX_BSH_EFF_LOSE')
    player:removeListener('OX_BSH_MAGIC_USE')
    player:removeListener('OX_BSH_WS_USE')
    local prev = player:getLocalVar('OX_BSH_SHIELD_MOD')
    if prev ~= 0 then
        player:delMod(xi.mod.SHIELDBLOCKRATE, prev)
        player:setLocalVar('OX_BSH_SHIELD_MOD', 0)
    end
    local prevSird = player:getLocalVar('OX_BSH_SIRD_MOD')
    if prevSird ~= 0 then
        player:delMod(xi.mod.SPELLINTERRUPT, prevSird)
        player:setLocalVar('OX_BSH_SIRD_MOD', 0)
    end
end

-----------------------------------
-- Vanilla JA Enhancements & Magic Cost/Cast Overrides
-----------------------------------
m:addOverride('xi.actions.abilities.afflatus_solace.onAbilityCheck', function(player, target, ability)
    if isBishop(player) then
        ability:setRecast(0)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.divine_seal.onUseAbility', function(player, target, ability)
    if isBishop(player) then
        ability:setRecast(20)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.martyr.onUseAbility', function(player, target, ability)
    if isBishop(player) and target ~= nil then
        ability:setRecast(15)
        local amt = math.floor(target:getMaxHP() * 0.25)
        H.healEntity(player, target, amt)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
        return amt
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.devotion.onUseAbility', function(player, target, ability)
    if isBishop(player) and target ~= nil then
        ability:setRecast(15)
        local amt = math.floor(target:getMaxMP() * 0.25)
        target:addMP(amt)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_MP)
        return amt
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.benediction.onUseAbility', function(player, target, ability)
    if isBishop(player) then
        H.forEachPartyMemberInRange(player, 15, false, function(member)
            member:setHP(member:getMaxHP())
            H.cleanseDebuffs(member, 10)
            H.restoreMpPct(member, 50)
            H.applyCustomTimedEffect(member, EFFECT_DIVINE_VEIL, 25, 15, player, 0, xi.effect.SACROSANCTITY, 2)
            if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
                xi.overlords.slots.applyPartyWard(player, member, -1200, 30, 15, xi.effect.SACROSANCTITY)
            end
        end)
        return 0
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (456-457)
-----------------------------------
m:addOverride('xi.actions.abilities.divine_veil.onAbilityCheck', function(player, _target, _ability)
    if not isBishop(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.divine_veil.onUseAbility', function(player, _target, ability)
    local skinAmt = math.floor(player:getMaxHP() * 0.22)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyStoneskinBarrier(member, skinAmt, skinAmt * 2, 10, player)
        H.applyCustomTimedEffect(member, EFFECT_DIVINE_VEIL, 12, 10, player, 0, xi.effect.SACROSANCTITY, 1)
        if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
            xi.overlords.slots.applyPartyWard(player, member, -1200, 30, 10, xi.effect.SACROSANCTITY)
        end
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_DIVINE_VEIL
end)

m:addOverride('xi.actions.abilities.sanctuary_pulse.onAbilityCheck', function(player, _target, _ability)
    if not isBishop(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.sanctuary_pulse.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 25, 15, false, false)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.cleanseDebuffs(member, 3)
    end)
    grantSacredGrace(player, 1)
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

-----------------------------------
-- Crystal Definition (WHM = 3)
-----------------------------------
if xi.job and xi.job.WHM then
    spec.registerCrystal(xi.job.WHM,
    {
        id          = 1,
        key         = BISHOP_KEY,
        name        = 'Bishop',
        abr         = 'BSH',
        role        = 'Healer',
        icon        = 'bishop',
        reqLevel    = 10,
        extraTraits = { TRAIT_SOLACE_CONDUIT },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { 245, 153, 154, ABIL_DIVINE_VEIL, ABIL_SANCTUARY_PULSE }
            end
            return {}
        end,
        description = 'Proactive Barrier-Cure & Afflatus Solace Conduit (Lv10+): converts Cure healing and overhealing into Solace Ward Stoneskin barriers, weaves Banish/Holy/Club WSs into instant 0-MP Curagas, and protects the party with Divine Veil.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% HP & MP, +12/18/24/32 MND & VIT, +18/26/34/42% Cure Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +4/6/8/12 MP/tick Refresh, +10/14/18/22% Shield Block (Club+Shield), 100% SIRD in Afflatus.',
            'Proactive Afflatus Solace: Unlocked @ Lv10+ (0s CD); Cure I-VI grant Solace Ward barrier (35-50% of heal, cap 30% Max HP) + -8% DT for 8s.',
            'Sacred Grace Smite-Weaving: Banish/Holy or Club/Staff WS grants +1 Sacred Grace (max 3) & +6% Max MP; at 3 stacks, Curaga/Esuna/Auspice triggers a 10s party Regen (15 + 2.2% Max HP/tick).',
            'JA Enhancements: Divine Seal (20s CD, +15% Max HP barrier), Martyr & Devotion (15s CD, 0 self-HP loss), Benediction (100% party heal/cleanse + 50% MP + -25% DT 15s).',
            'Divine Veil (25s CD, 22% HP barrier + -12% DT + +30 MEVA + splash next Cure/Erase/Esuna) & Sanctuary Pulse (20s CD, 25% HP AoE heal + 3-debuff cleanse + 1 Sacred Grace).',
        },
        mods = function(player, lvl)
            local isWiki = (player == nil) or (not player.getEquipID)
            local list =
            {
                { xi.mod.HPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MND,          H.scaleTier(lvl, 12, 18, 24, 32) },
                { xi.mod.VIT,          H.scaleTier(lvl, 12, 18, 24, 32) },
                { xi.mod.CURE_POTENCY, H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.FASTCAST,     H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,       -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,      H.scaleTier(lvl, 4, 6, 8, 12) },
                { xi.mod.HEALING,      H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.DIVINE,       H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.ENHANCING,    H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.CLUB,         H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.STAFF,        H.scaleTier(lvl, 15, 25, 35, 50) },
            }
            if isWiki then
                table.insert(list, { xi.mod.SHIELDBLOCKRATE, H.scaleTier(lvl, 10, 14, 18, 22) })
                table.insert(list, { xi.mod.SPELLINTERRUPT,  100 })
            end
            return list
        end,
        onApply = function(player)
            attachBishopListeners(player)
            syncWhmGearMods(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_SOLACE_WARD)
                player:delStatusEffectSilent(EFFECT_SACRED_GRACE)
                player:delStatusEffectSilent(EFFECT_DIVINE_VEIL)
            end
            detachBishopListeners(player)
        end,
    })
end

return m
