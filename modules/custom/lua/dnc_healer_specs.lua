-----------------------------------
-- OverlordsXI Dancer Crystal Spec: Vampire (VMP | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set vampire)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/dnc_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/dancer')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_dnc_healer_specs')

local spec = xi.overlords.spec
local VAMPIRE_KEY = 'vampire'

-- Custom Trait ID (172; Crimson Waltz)
local TRAIT_CRIMSON_WALTZ = 172

-- Custom Ability IDs (462-463; recastIds 155-156)
local ABIL_SANGUINE_WALTZ = 462
local ABIL_NOCTURNE_FEAST = 463

-- Custom Status Effect IDs (867-868; registered in patch 0028)
local EFFECT_CRIMSON_VEIL   = 867
local EFFECT_SANGUINE_WALTZ = 868

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.SANGUINE_WALTZ = ABIL_SANGUINE_WALTZ
xi.jobAbility.NOCTURNE_FEAST = ABIL_NOCTURNE_FEAST

xi.effect = xi.effect or {}
xi.effect.CRIMSON_VEIL   = EFFECT_CRIMSON_VEIL
xi.effect.SANGUINE_WALTZ = EFFECT_SANGUINE_WALTZ

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.sanguine_waltz = xi.actions.abilities.sanguine_waltz or {}
xi.actions.abilities.nocturne_feast = xi.actions.abilities.nocturne_feast or {}

xi.effects = xi.effects or {}
xi.effects.crimson_veil   = xi.effects.crimson_veil or {}
xi.effects.sanguine_waltz = xi.effects.sanguine_waltz or {}

local function isVampire(entity)
    return H.isSpecActive(entity, xi.job.DNC, VAMPIRE_KEY)
end

local STEP_ABILITIES =
{
    [201] = true, -- Quickstep
    [202] = true, -- Box Step
    [203] = true, -- Stutter Step
    [312] = true, -- Feather Step
}

local WALTZ_ABILITIES =
{
    [190] = true, -- Curing Waltz
    [191] = true, -- Curing Waltz II
    [192] = true, -- Curing Waltz III
    [193] = true, -- Curing Waltz IV
    [311] = true, -- Curing Waltz V
    [195] = true, -- Divine Waltz
    [262] = true, -- Divine Waltz II
}

local function getFinishingMoves(player)
    for fm = 1, 5 do
        local eff = xi.effect['FINISHING_MOVE_' .. fm]
        if eff and player:hasStatusEffect(eff) then
            return fm
        end
    end
    return 0
end

local function setFinishingMoves(player, count)
    for fm = 1, 5 do
        local eff = xi.effect['FINISHING_MOVE_' .. fm]
        if eff then
            player:delStatusEffectSilent(eff)
        end
    end
    local clamped = math.max(0, math.min(5, math.floor(count or 0)))
    if clamped > 0 then
        local eff = xi.effect['FINISHING_MOVE_' .. clamped]
        if eff then
            player:addStatusEffect(eff, { power = clamped, duration = 7200, origin = player })
        end
    end
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.crimson_veil.onEffectGain', function(_target, _effect)
    -- Party -DT is routed through EFF_OX_SUP_WARD (capped at -15% DMG)
end)

m:addOverride('xi.effects.sanguine_waltz.onEffectGain', function(target, effect)
    local total = effect:getPower() or 25
    if xi.overlords and xi.overlords.regen and xi.overlords.regen.consumeEffectRegen then
        total = xi.overlords.regen.consumeEffectRegen(target, effect, 25, 350)
    end
    effect:addMod(xi.mod.REGEN, total)
end)

-----------------------------------
-- Listeners (Drain Samba, Steps, WS Sanguine Blossom)
-----------------------------------
local function attachVampireListeners(player)
    if player == nil or player:getLocalVar('OX_VMP_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_VMP_LISTENERS', 1)

    player:addListener('ATTACK', 'OX_VMP_ATTACK', function(attacker, _defender, action)
        if not isVampire(attacker) then
            return
        end
        local pct = H.scaleTier(attacker:getMainLvl(), 18, 24, 30, 36)
        if attacker:hasStatusEffect(xi.effect.TRANCE) then
            pct = pct * 2
        end
        local dmg = action and action:getParam() or math.floor(attacker:getMainLvl() * 3)
        local rawHeal = math.max(20, math.floor(dmg * (pct / 100)))
        H.forEachPartyMemberInRange(attacker, 15, false, function(member)
            local _, overheal = H.healEntity(attacker, member, rawHeal)
            if overheal > 0 then
                local cap = math.floor(member:getMaxHP() * 0.20)
                H.applyStoneskinBarrier(member, overheal, cap, 15, attacker)
            end
        end)
    end)

    player:addListener('ABILITY_USE', 'OX_VMP_ABIL', function(caster, _target, ability)
        if not isVampire(caster) or ability == nil then
            return
        end
        local abilId = ability:getID()
        if STEP_ABILITIES[abilId] then
            local fm = getFinishingMoves(caster)
            setFinishingMoves(caster, fm + 2)
            H.healPartyPct(caster, 10, 15, false, true)
        elseif WALTZ_ABILITIES[abilId] and caster:hasStatusEffect(xi.effect.CONTRADANCE) then
            H.forEachPartyMemberInRange(caster, 15, false, function(member)
                H.applyCustomTimedEffect(member, EFFECT_CRIMSON_VEIL, 15, 10, caster, 0, xi.effect.CONTRADANCE, 1)
                if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
                    xi.overlords.slots.applyPartyWard(caster, member, -1500, 0, 10, xi.effect.CONTRADANCE)
                end
            end)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_VMP_WS', function(caster, _target, ws)
        if not isVampire(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, nil, { [xi.skill.DAGGER] = true, [xi.skill.THROWING] = true }) then
            local fm = caster:hasStatusEffect(xi.effect.TRANCE) and 5 or getFinishingMoves(caster)
            if fm > 0 then
                if not caster:hasStatusEffect(xi.effect.TRANCE) then
                    setFinishingMoves(caster, 0)
                end
                H.healPartyPct(caster, fm * 6, 15, false, true)
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    H.cleanseDebuffs(member, 1)
                end)
            end
        end
    end)
end

local function detachVampireListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_VMP_LISTENERS', 0)
    player:removeListener('OX_VMP_ATTACK')
    player:removeListener('OX_VMP_ABIL')
    player:removeListener('OX_VMP_WS')
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.contradance.onUseAbility', function(player, target, ability)
    if isVampire(player) then
        ability:setRecast(15)
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (462-463)
-----------------------------------
m:addOverride('xi.actions.abilities.sanguine_waltz.onAbilityCheck', function(player, _target, _ability)
    if not isVampire(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not player:hasStatusEffect(xi.effect.TRANCE) and player:getTP() < 200 then
        return xi.msg.basic.NOT_ENOUGH_TP, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.sanguine_waltz.onUseAbility', function(player, _target, ability)
    if not player:hasStatusEffect(xi.effect.TRANCE) then
        player:delTP(200)
    end
    local total = H.healPartyPct(player, 30, 15, false, true)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.cleanseDebuffs(member, 2)
        if xi.overlords and xi.overlords.regen and xi.overlords.regen.stampRegenContext then
            xi.overlords.regen.stampRegenContext(player, member, 350)
        end
        H.applyCustomTimedEffect(member, EFFECT_SANGUINE_WALTZ, 25, 15, player, 0, xi.effect.REGEN, 1)
        if xi.overlords and xi.overlords.regen and xi.overlords.regen.clearRegenContext then
            xi.overlords.regen.clearRegenContext(member)
        end
    end)
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.nocturne_feast.onAbilityCheck', function(player, target, _ability)
    if not isVampire(player) or target == nil then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.nocturne_feast.onUseAbility', function(player, target, ability)
    local drain = math.min(math.floor(target:getHP() * 0.15), math.floor(player:getMaxHP() * 0.25))
    drain = math.max(50, drain)
    if target.takeDamage then
        target:takeDamage(drain, player, xi.attackType.SPECIAL, xi.damageType.NONE)
    end
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.healEntity(player, member, drain)
        if member.addTP then
            member:addTP(250)
        end
    end)
    setFinishingMoves(player, 5)
    ability:setMsg(xi.msg.basic.JA_DAMAGE)
    return drain
end)

-----------------------------------
-- Crystal Definition (DNC = 19)
-----------------------------------
if xi.job and xi.job.DNC then
    spec.registerCrystal(xi.job.DNC,
    {
        id          = 3,
        key         = VAMPIRE_KEY,
        name        = 'Vampire',
        abr         = 'VMP',
        role        = 'Healer',
        icon        = 'vampire',
        reqLevel    = 10,
        extraTraits = { TRAIT_CRIMSON_WALTZ },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { 184, 185, 186, ABIL_SANGUINE_WALTZ, ABIL_NOCTURNE_FEAST }
            end
            return {}
        end,
        description = 'Crimson Blood-Dancer, Lifesteal Waltz & Sanguine Step Healer (Lv10+, 0-MP TP/FM Engine): converts physical damage into party Drain Samba lifesteal & Crimson Veil barriers, and detonates Finishing Moves on Dagger/Throwing WSs.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% HP, +10/16/22/28 DEX/AGI/CHR, +20/30/40/50% Waltz Potency, +15/22/30/38% Subtle Blow, +10/15/20/25 Store TP, +12/18/24/30 TP/tick Regain, -25/35/45/60 Enmity.',
            'Crimson Drain Samba: Party (15y) heals for 18/24/30/36% of physical damage dealt; overhealing converts into Crimson Veil Stoneskin (up to 20% Max HP).',
            'Sanguine Flourish: Steps grant +2 FM & 10% party heal; Dagger/Throwing WSs consume up to 5 FM for 6%/FM AoE heal + party cleanse.',
            'JA Enhancements: Trance (0 TP Waltzes, infinite FMs, 2x Drain Samba) & Contradance (15s CD, +100% Waltz & -15% DT 10s).',
            'Sanguine Waltz (18s CD, 200 TP: 30% HP AoE heal + 2-debuff cleanse + 25 + 3.5% Max HP/t Regen) & Nocturne Feast (25s CD: drains 15% foe HP into party HP + 250 TP + 5 FMs).',
        },
        mods = function(_player, lvl)
            return
            {
                { xi.mod.HPP,           H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.DEX,           H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.AGI,           H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CHR,           H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.WALTZ_POTENCY, H.scaleTier(lvl, 20, 30, 40, 50) },
                { xi.mod.SUBTLE_BLOW,   H.scaleTier(lvl, 15, 22, 30, 38) },
                { xi.mod.STORETP,       H.scaleTier(lvl, 10, 15, 20, 25) },
                { xi.mod.REGAIN,        H.scaleTier(lvl, 12, 18, 24, 30) },
                { xi.mod.ENMITY,        -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.DAGGER,        H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.EVASION,       H.scaleTier(lvl, 15, 25, 35, 50) },
            }
        end,
        onApply = function(player)
            attachVampireListeners(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_CRIMSON_VEIL)
                player:delStatusEffectSilent(EFFECT_SANGUINE_WALTZ)
            end
            detachVampireListeners(player)
        end,
    })
end

return m
