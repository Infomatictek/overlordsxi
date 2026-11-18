-----------------------------------
-- OverlordsXI Dragoon Crystal Spec: Wyvernheart (WYV | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set wyvernheart)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/dragoon')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_drg_specs')

local spec = xi.overlords.spec
local WYVERNHEART_KEY = 'wyvernheart'

-- Custom Trait ID (176; Wyrmblood Breath)
local TRAIT_WYRMBLOOD_BREATH = 176

-- Custom Ability IDs (470-471; recastIds 148, 185)
local ABIL_WYRMBLOOD_PULSE       = 470
local ABIL_DRAGONSCALE_SANCTUARY = 471

-- Custom Status Effect IDs (874-875; registered in patch 0028)
local EFFECT_DRAGONSCALE           = 874
local EFFECT_DRAGONSCALE_SANCTUARY = 875

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.WYRMBLOOD_PULSE       = ABIL_WYRMBLOOD_PULSE
xi.jobAbility.DRAGONSCALE_SANCTUARY = ABIL_DRAGONSCALE_SANCTUARY

xi.effect = xi.effect or {}
xi.effect.DRAGONSCALE           = EFFECT_DRAGONSCALE
xi.effect.DRAGONSCALE_SANCTUARY = EFFECT_DRAGONSCALE_SANCTUARY

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.wyrmblood_pulse       = xi.actions.abilities.wyrmblood_pulse or {}
xi.actions.abilities.dragonscale_sanctuary = xi.actions.abilities.dragonscale_sanctuary or {}

xi.effects = xi.effects or {}
xi.effects.dragonscale           = xi.effects.dragonscale or {}
xi.effects.dragonscale_sanctuary = xi.effects.dragonscale_sanctuary or {}

local function isWyvernheart(entity)
    return H.isSpecActive(entity, xi.job.DRG, WYVERNHEART_KEY)
end

local JUMP_ABILITIES =
{
    [66]  = true, -- Jump
    [67]  = true, -- High Jump
    [68]  = true, -- Super Jump
    [260] = true, -- Spirit Jump
    [293] = true, -- Soul Jump
}

local WYVERNHEART_WS_IDS =
{
    [112] = true, -- Double Thrust
    [115] = true, -- Penta Thrust
    [120] = true, -- Impulse Drive
    [123] = true, -- Drakesbane
    [125] = true, -- Camlann's Torment
    [126] = true, -- Stardiver
}

local function syncWyvernHealerMods(player)
    if not isWyvernheart(player) or not player.getPet then
        return
    end
    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return
    end
    if pet:getLocalVar('OX_WYV_SYNCED') == 1 then
        return
    end
    pet:setLocalVar('OX_WYV_SYNCED', 1)
    pet:addMod(xi.mod.HPP, 60)
    pet:addMod(xi.mod.DMG, -4000)
end

local function triggerCrimsonBreath(drg, basePct)
    if not isWyvernheart(drg) then
        return
    end
    local pct = basePct or H.scaleTier(drg:getMainLvl(), 16, 20, 24, 28)
    if drg:hasStatusEffect(xi.effect.SPIRIT_SURGE) or drg:hasStatusEffect(xi.effect.FLY_HIGH) then
        pct = pct * 2
    end
    H.healPartyPct(drg, pct, 15, true, false)
    local skinAmt = math.floor(drg:getMaxHP() * 0.15)
    H.forEachPartyMemberInRange(drg, 15, false, function(member)
        H.cleanseDebuffs(member, 1)
        H.applyStoneskinBarrier(member, skinAmt, skinAmt * 2, 15, drg)
    end)
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.dragonscale_sanctuary.onEffectGain', function(_target, _effect)
    -- Party -DT and MEVA are routed through EFF_OX_SUP_WARD (capped at -15% DMG / +35 MEVA)
end)

-----------------------------------
-- Listeners (Jump & Polearm WS Breath Conduit)
-----------------------------------
local function attachWyvernheartListeners(player)
    if player == nil or player:getLocalVar('OX_WYV_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_WYV_LISTENERS', 1)

    player:addListener('ABILITY_USE', 'OX_WYV_ABIL', function(caster, _target, ability)
        if not isWyvernheart(caster) or ability == nil then
            return
        end
        local abilId = ability:getID()
        if JUMP_ABILITIES[abilId] then
            if caster:hasStatusEffect(xi.effect.SPIRIT_SURGE) or caster:hasStatusEffect(xi.effect.FLY_HIGH) then
                ability:setRecast(5)
            end
            triggerCrimsonBreath(caster)
            H.restoreMpPct(caster, 8)
            if caster:hasStatusEffect(EFFECT_DRAGONSCALE_SANCTUARY) then
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    if member.addTP then
                        member:addTP(200)
                    end
                    H.healEntity(caster, member, math.floor(member:getMaxHP() * 0.08))
                end)
            end
        elseif abilId == 319 then -- Restoring Breath
            ability:setRecast(12)
            triggerCrimsonBreath(caster)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_WYV_WS', function(caster, _target, ws)
        if not isWyvernheart(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, WYVERNHEART_WS_IDS, { [xi.skill.POLEARM] = true }) then
            triggerCrimsonBreath(caster)
            H.restoreMpPct(caster, 8)
            if caster:hasStatusEffect(EFFECT_DRAGONSCALE_SANCTUARY) then
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    if member.addTP then
                        member:addTP(200)
                    end
                    H.healEntity(caster, member, math.floor(member:getMaxHP() * 0.08))
                end)
            end
        end
    end)
end

local function detachWyvernheartListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_WYV_LISTENERS', 0)
    player:removeListener('OX_WYV_ABIL')
    player:removeListener('OX_WYV_WS')
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.spirit_link.onUseAbility', function(player, target, ability)
    if isWyvernheart(player) then
        ability:setRecast(15)
        local pet = player:getPet()
        if pet ~= nil then
            pet:setHP(pet:getMaxHP())
        end
        H.forEachPartyMemberInRange(player, 15, false, function(member)
            H.cleanseDebuffs(member, 5)
        end)
        local total = H.healPartyPct(player, 20, 15, false, false)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
        return total
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (470-471)
-----------------------------------
m:addOverride('xi.actions.abilities.wyrmblood_pulse.onAbilityCheck', function(player, _target, _ability)
    if not isWyvernheart(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.wyrmblood_pulse.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 30, 15, true, false)
    H.forEachPartyMemberInRange(player, 15, true, function(unit)
        H.cleanseDebuffs(unit, 3)
    end)
    for jumpId, _ in pairs(JUMP_ABILITIES) do
        if player.resetAbilityRecast then
            player:resetAbilityRecast(jumpId)
        end
    end
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.dragonscale_sanctuary.onAbilityCheck', function(player, _target, _ability)
    if not isWyvernheart(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.dragonscale_sanctuary.onUseAbility', function(player, _target, ability)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyCustomTimedEffect(member, EFFECT_DRAGONSCALE_SANCTUARY, 15, 12, player, 0, xi.effect.SPIRIT_SURGE, 1)
        if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
            xi.overlords.slots.applyPartyWard(player, member, -1500, 30, 12, xi.effect.SPIRIT_SURGE)
        end
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_DRAGONSCALE_SANCTUARY
end)

-----------------------------------
-- Crystal Definition (DRG = 14)
-----------------------------------
if xi.job and xi.job.DRG then
    spec.registerCrystal(xi.job.DRG,
    {
        id          = 3,
        key         = WYVERNHEART_KEY,
        name        = 'Wyvernheart',
        abr         = 'WYV',
        role        = 'Healer',
        icon        = 'wyvernheart',
        reqLevel    = 10,
        extraTraits = { TRAIT_WYRMBLOOD_BREATH },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { 319, ABIL_WYRMBLOOD_PULSE, ABIL_DRAGONSCALE_SANCTUARY }
            end
            return {}
        end,
        description = 'Crimson Dragon-Blood Lancer, AoE Healing Breath & Spirit-Link Mender (Lv10+, Polearm): unlocks Restoring Breath (12s CD) @ Lv10+, splashes Healing Breaths party-wide with Dragonscale Stoneskin, and triggers Breaths on Jumps and Polearm WSs.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% HP & MP, +10/16/22/28 MND/VIT/CHR, +20/30/40/50% Cure/Breath Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +4/6/8/12 MP/tick Refresh; Wyvern +60% HP & -40% DT.',
            'AoE Crimson Healing Breath: Restoring Breath @ Lv10+ (12s CD, 0 HP threshold); Healing Breaths splash party-wide (15y), cleanse 1 debuff, and grant 15% Max HP Dragonscale Stoneskin.',
            'Dragon-Blood Conduit: Jumps and Polearm WSs trigger a free AoE Healing Breath (16/20/24/28% DRG Max HP) and restore +8% Max MP.',
            'JA Enhancements: Spirit Link (15s CD, 0 self-HP loss, 100% Wyvern HP + party cleanse + 20% AoE heal) & Spirit Surge / Fly High (5s Jump CD, 2x Breath).',
            'Wyrmblood Pulse (20s CD, 30% HP AoE heal + 3-debuff cleanse + Jump reset) & Dragonscale Sanctuary (25s CD, 12s -15% DT + +30 MEVA + +200 TP / +8% HP on Jump/WS).',
        },
        mods = function(_player, lvl)
            return
            {
                { xi.mod.HPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MND,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.VIT,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CHR,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CURE_POTENCY, H.scaleTier(lvl, 20, 30, 40, 50) },
                { xi.mod.FASTCAST,     H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,       -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,      H.scaleTier(lvl, 4, 6, 8, 12) },
                { xi.mod.POLEARM,      H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.HEALING,      H.scaleTier(lvl, 15, 25, 35, 50) },
            }
        end,
        onApply = function(player)
            attachWyvernheartListeners(player)
            syncWyvernHealerMods(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_DRAGONSCALE)
                player:delStatusEffectSilent(EFFECT_DRAGONSCALE_SANCTUARY)
            end
            detachWyvernheartListeners(player)
        end,
    })
end

return m
