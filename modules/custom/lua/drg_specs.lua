-----------------------------------
-- OverlordsXI Dragoon Crystal Spec: Wyvernheart (WYV | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set wyvernheart)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/dragoon')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_drg_specs')

local spec = xi.overlords.spec
local WYVERNHEART_KEY = 'wyvernheart'

-- Custom Trait ID (176; Wyrmblood Breath)
local TRAIT_WYRMBLOOD_BREATH = 176

-- Native DRG Ability IDs
local ABIL_CALL_WYVERN      = 61
local ABIL_JUMP             = 66
local ABIL_HIGH_JUMP        = 67
local ABIL_SUPER_JUMP       = 68
local ABIL_SPIRIT_LINK      = 80
local ABIL_RESTORING_BREATH = 319

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

local lastWsCastAtByChar = {}

local function isWyvernheart(entity)
    return H.isSpecActive(entity, xi.job.DRG, WYVERNHEART_KEY)
end

local function getWyrmscale(player)
    if player == nil or not player.getLocalVar then
        return 0
    end
    local exp = player:getLocalVar('OX_WYV_SCALE_EXP') or 0
    if exp > 0 and os.time() > exp then
        player:setLocalVar('OX_WYV_SCALE', 0)
        player:setLocalVar('OX_WYV_SCALE_EXP', 0)
        return 0
    end
    return math.min(3, math.max(0, player:getLocalVar('OX_WYV_SCALE') or 0))
end

local function addWyrmscale(player, amount)
    if player == nil or not player.setLocalVar then
        return 0
    end
    local cur  = getWyrmscale(player)
    local next = math.min(3, cur + (amount or 1))
    player:setLocalVar('OX_WYV_SCALE', next)
    player:setLocalVar('OX_WYV_SCALE_EXP', os.time() + 30)
    return next
end

local function consumeAllWyrmscale(player)
    local count = getWyrmscale(player)
    if player ~= nil and player.setLocalVar then
        player:setLocalVar('OX_WYV_SCALE', 0)
        player:setLocalVar('OX_WYV_SCALE_EXP', 0)
    end
    return count
end

local function getPartyMembersInRange(player, range)
    local out = {}
    H.forEachPartyMemberInRange(player, range or 15, false, function(member)
        if member ~= nil and member.isAlive and member:isAlive() then
            table.insert(out, member)
        end
    end)
    return out
end

local function getLowestHpAllies(player, range, count)
    local members = getPartyMembersInRange(player, range or 15)
    table.sort(members, function(a, b)
        local pa = (a:getHP() or 0) / math.max(1, a:getMaxHP() or 1)
        local pb = (b:getHP() or 0) / math.max(1, b:getMaxHP() or 1)
        return pa < pb
    end)
    local out = {}
    for i = 1, math.min(count or 1, #members) do
        table.insert(out, members[i])
    end
    return out
end

local function healWithPotency(caster, target, baseAmount)
    if caster == nil or target == nil or not target.isAlive or not target:isAlive() then
        return 0, 0
    end
    local pot     = math.max(0, caster.getMod and caster:getMod(xi.mod.CURE_POTENCY) or 0)
    local total   = math.max(1, math.floor(baseAmount * (1 + pot / 100)))
    local missing = math.max(0, (target:getMaxHP() or 0) - (target:getHP() or 0))
    local healed  = math.min(total, missing)
    local overheal = math.max(0, total - healed)
    if healed > 0 then
        H.healEntity(caster, target, healed)
    end
    return healed, overheal
end

local wyvernAppliedModsByPet = {}

local function unsyncWyvernHealerMods(player)
    if player == nil or not player.getPet then
        return
    end
    local pet = player:getPet()
    if pet == nil then
        return
    end
    local petId = pet:getID()
    local mods = wyvernAppliedModsByPet[petId]
    if mods ~= nil and pet.delMod then
        for _, pair in ipairs(mods) do
            pet:delMod(pair[1], pair[2])
        end
        wyvernAppliedModsByPet[petId] = nil
        pet:updateHealth()
    end
    if pet.setLocalVar then
        pet:setLocalVar('OX_WYV_SYNCED', 0)
    end
end

local function syncWyvernHealerMods(player)
    if not isWyvernheart(player) or not player.getPet then
        return
    end
    local pet = player:getPet()
    if pet == nil or not pet:isAlive() then
        return
    end
    if spec.syncPetRoleMods then
        spec.syncPetRoleMods(player, pet)
    end
    if pet:getLocalVar('OX_WYV_SYNCED') == 1 then
        return
    end
    pet:setLocalVar('OX_WYV_SYNCED', 1)

    local lvl   = player:getMainLvl() or 1
    local hpPct = H.scaleTier(lvl, 40, 50, 60, 75)
    local mods  =
    {
        { xi.mod.HPP, hpPct },
        { xi.mod.DMG, -4000 },
        { xi.mod.ENMITY, -60 },
    }
    if xi.mod.DMGBREATH then
        table.insert(mods, { xi.mod.DMGBREATH, -10000 })
    end
    if xi.mod.UDMBREATH then
        table.insert(mods, { xi.mod.UDMBREATH, -10000 })
    end
    if xi.mod.DMGMAGIC then
        table.insert(mods, { xi.mod.DMGMAGIC, -10000 })
    end
    if xi.mod.UDMMAGIC then
        table.insert(mods, { xi.mod.UDMMAGIC, -10000 })
    end
    for _, pair in ipairs(mods) do
        pet:addMod(pair[1], pair[2])
    end
    wyvernAppliedModsByPet[pet:getID()] = mods
    pet:updateHealth()
    pet:setHP(pet:getMaxHP())
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.dragonscale_sanctuary.onEffectGain', function(_target, effect)
    -- Party -DT and MEVA are routed through EFF_OX_SUP_WARD; Sanctuary grants Knockback Immunity
    if effect ~= nil and effect.addMod and xi.mod.KNOCKBACK_REDUCTION then
        effect:addMod(xi.mod.KNOCKBACK_REDUCTION, 100)
    end
end)

-----------------------------------
-- Listeners (Wyvern Sync & Polearm Crimson Triage)
-----------------------------------
local function attachWyvernheartListeners(player)
    if player == nil or player:getLocalVar('OX_WYV_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_WYV_LISTENERS', 1)

    player:addListener('TICK', 'OX_WYV_TICK', function(actor)
        syncWyvernHealerMods(actor)
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_WYV_WS', function(caster, _target, ws)
        if not isWyvernheart(caster) then
            return
        end
        if not H.isWeaponSkillInSet(ws, nil, { [xi.skill.POLEARM] = true }) then
            return
        end

        local charId    = caster.getID and caster:getID() or 0
        local now       = xi.overlords.nowSec()
        local isPrimary = (charId == 0) or ((now - (lastWsCastAtByChar[charId] or 0)) > 0.05)
        if not isPrimary then
            return
        end
        if charId > 0 then
            lastWsCastAtByChar[charId] = now
        end

        addWyrmscale(caster, 1)

        local pet = caster.getPet and caster:getPet() or nil
        if pet == nil or not pet:isAlive() then
            return
        end

        local allies = getLowestHpAllies(caster, 15, 1)
        local target = allies[1]
        if target ~= nil then
            local pct      = H.scaleTier(caster:getMainLvl(), 18, 21, 24, 28)
            local baseHeal = math.max(1, math.floor((caster:getMaxHP() or 0) * pct / 100))
            local _, overheal = healWithPotency(caster, target, baseHeal)
            if overheal > 0 then
                local cap = math.max(1, math.floor((target:getMaxHP() or 0) * 0.12))
                H.applyStoneskinBarrier(target, math.min(overheal, cap), cap, 12, caster)
            end
        end
    end)
end

local function detachWyvernheartListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_WYV_LISTENERS', 0)
    player:removeListener('OX_WYV_TICK')
    player:removeListener('OX_WYV_WS')
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.call_wyvern.onAbilityCheck', function(player, target, ability)
    if isWyvernheart(player) then
        if player.getPet and player:getPet() ~= nil then
            return xi.msg.basic.ALREADY_HAS_A_PET, 0
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.call_wyvern.onUseAbility', function(player, target, ability)
    if isWyvernheart(player) and ability ~= nil and ability.setRecast then
        ability:setRecast(15)
    end
    local res = super(player, target, ability)
    if isWyvernheart(player) then
        syncWyvernHealerMods(player)
    end
    return res
end)

m:addOverride('xi.actions.abilities.jump.onUseAbility', function(player, target, ability, action)
    local res = super(player, target, ability, action)
    if isWyvernheart(player) then
        local hasSurge = player:hasStatusEffect(xi.effect.SPIRIT_SURGE) or player:hasStatusEffect(xi.effect.FLY_HIGH)
        if ability ~= nil and ability.setRecast then
            ability:setRecast(hasSurge and 10 or 20)
        end
        if player.addTP then
            player:addTP(150)
        end
        addWyrmscale(player, hasSurge and 2 or 1)

        -- Mending Dive: mist 2 lowest-HP allies within 15y with Hybrid Regen (15 + 2.2% Max HP/t, 12s) + 1 Erase
        for _, ally in ipairs(getLowestHpAllies(player, 15, 2)) do
            local regenPwr = 15 + math.max(1, math.floor((ally:getMaxHP() or 0) * 0.022))
            H.applyCustomTimedEffect(ally, xi.effect.REGEN, regenPwr, 12, player, 0, xi.effect.REGEN, 3)
            H.cleanseDebuffs(ally, 1)
        end
    end
    return res
end)

m:addOverride('xi.actions.abilities.high_jump.onUseAbility', function(player, target, ability, action)
    local res = super(player, target, ability, action)
    if isWyvernheart(player) then
        local hasSurge = player:hasStatusEffect(xi.effect.SPIRIT_SURGE) or player:hasStatusEffect(xi.effect.FLY_HIGH)
        if ability ~= nil and ability.setRecast then
            ability:setRecast(hasSurge and 18 or 35)
        end
        addWyrmscale(player, hasSurge and 2 or 1)

        -- Gale Cleanse: 15y 2-debuff party cleanse + 10% Target Max HP Stoneskin (10s)
        H.forEachPartyMemberInRange(player, 15, false, function(member)
            H.cleanseDebuffs(member, 2)
            local skin = math.max(1, math.floor((member:getMaxHP() or 0) * 0.10))
            H.applyStoneskinBarrier(member, skin, skin * 2, 10, player)
        end)
    end
    return res
end)

m:addOverride('xi.actions.abilities.super_jump.onUseAbility', function(player, target, ability, action)
    local res = super(player, target, ability, action)
    if isWyvernheart(player) then
        local hasSurge = player:hasStatusEffect(xi.effect.SPIRIT_SURGE) or player:hasStatusEffect(xi.effect.FLY_HIGH)
        if ability ~= nil and ability.setRecast then
            ability:setRecast(hasSurge and 38 or 75)
        end
        addWyrmscale(player, 3)

        local pet = player:getPet()
        if pet ~= nil and pet:isAlive() then
            if pet.setUntargetable then
                pet:setUntargetable(true)
                player:timer(8000, function(actor)
                    local p = actor and actor.getPet and actor:getPet() or nil
                    if p ~= nil and p.setUntargetable then
                        p:setUntargetable(false)
                    end
                end)
            else
                H.applyCustomTimedEffect(pet, xi.effect.HIDE, 1, 8, player, 0, xi.effect.HIDE)
            end
        end
    end
    return res
end)

m:addOverride('xi.actions.abilities.spirit_link.onAbilityCheck', function(player, target, ability)
    if isWyvernheart(player) then
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.spirit_link.onUseAbility', function(player, target, ability)
    if isWyvernheart(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(15)
        end
        local pet = player:getPet()
        if pet ~= nil and pet:isAlive() then
            pet:addHP(math.max(1, math.floor((pet:getMaxHP() or 0) * 0.40)))
        end

        addWyrmscale(player, 1)

        local total = 0
        local ally  = getLowestHpAllies(player, 15, 1)[1]
        if ally ~= nil then
            local pct      = H.scaleTier(player:getMainLvl(), 22, 25, 28, 32)
            local baseHeal = math.max(1, math.floor((player:getMaxHP() or 0) * pct / 100))
            local healed   = healWithPotency(player, ally, baseHeal)
            H.cleanseDebuffs(ally, 2)
            total = healed
        end
        ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
        return total
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.restoring_breath.onAbilityCheck', function(player, target, ability)
    if isWyvernheart(player) then
        return xi.job_utils.dragoon.abilityCheckRequiresPet(player, target, ability, true)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.restoring_breath.onUseAbility', function(player, target, ability, action)
    if isWyvernheart(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(20)
        end
        local stacks   = consumeAllWyrmscale(player)
        local pct      = 14 + (stacks * 6)
        local baseHeal = math.max(1, math.floor((player:getMaxHP() or 0) * pct / 100))
        local total    = 0

        H.forEachPartyMemberInRange(player, 15, false, function(member)
            local healed = healWithPotency(player, member, baseHeal)
            total = total + healed
            if stacks >= 3 then
                local skin = math.max(1, math.floor((member:getMaxHP() or 0) * 0.15))
                H.applyStoneskinBarrier(member, skin, skin * 2, 12, player)
            end
        end)
        ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
        return total
    end
    return super(player, target, ability, action)
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
    local baseHeal = math.max(1, math.floor((player:getMaxHP() or 0) * 0.24))
    local total    = 0
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        local healed = healWithPotency(player, member, baseHeal)
        total = total + healed
        H.cleanseDebuffs(member, 2)
    end)
    if player.resetRecast and xi.recast and xi.recast.ABILITY then
        player:resetRecast(xi.recast.ABILITY, 158) -- Jump
        player:resetRecast(xi.recast.ABILITY, 159) -- High Jump
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
        local skin = math.max(1, math.floor((member:getMaxHP() or 0) * 0.15))
        H.applyStoneskinBarrier(member, skin, skin * 2, 15, player)
        H.applyCustomTimedEffect(member, EFFECT_DRAGONSCALE_SANCTUARY, 15, 15, player, 0, xi.effect.SPIRIT_SURGE, 1)
        if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
            xi.overlords.slots.applyPartyWard(player, member, -1200, 30, 15, xi.effect.SPIRIT_SURGE)
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
            local l = lvl or 1
            if l >= 50 then
                return { ABIL_CALL_WYVERN, ABIL_JUMP, ABIL_HIGH_JUMP, ABIL_SUPER_JUMP, ABIL_SPIRIT_LINK, ABIL_RESTORING_BREATH, ABIL_WYRMBLOOD_PULSE, ABIL_DRAGONSCALE_SANCTUARY }
            elseif l >= 10 then
                return { ABIL_CALL_WYVERN, ABIL_JUMP, ABIL_HIGH_JUMP, ABIL_SPIRIT_LINK, ABIL_RESTORING_BREATH, ABIL_WYRMBLOOD_PULSE, ABIL_DRAGONSCALE_SANCTUARY }
            end
            return {}
        end,
        description = 'Pure martial Dragon-Blood Lancer & Wyvern Triage Healer (Lv10+, Polearm): unlocks Call Wyvern, Jumps, Spirit Link, and Restoring Breath @ Lv10+, weaves Wyrmscale stacks into scaled AoE Healing Breaths, and commands Wyvern Crimson Triage on Polearm WSs.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% Max HP, +10/16/22/28 VIT/MND/STR, +20/28/36/45% Cure/Breath Potency, +15/20/25/30% Subtle Blow, +15/25/35/50 Polearm, +10/14/18/22% Parry (Inquartata), -25/35/45/60 Enmity; Wyvern +40/50/60/75% HP, -40% DT, -60 Enmity & 100% AoE Breath/Magic resist.',
            'Lv.10+ Kit & Polearm Triage: Unlocks Call Wyvern (15s CD, in-combat, 100% HP), Jump, High Jump, Spirit Link, and Restoring Breath @ Lv.10+ (Super Jump @ Lv.50+); Polearm WSs command Wyvern Crimson Triage (18/21/24/28% DRG Max HP on lowest-HP ally + overheal -> 12% Stoneskin) + 1 Wyrmscale (max 3).',
            'Distinct Jump Directives & Spirit Link: Jump (20s CD, +150 TP, +1 Wyrmscale, 2 lowest-HP allies Hybrid Regen 15 + 2.2% Max HP/t + 1 Erase); High Jump (35s CD, +1 Wyrmscale, 15y 2-debuff party cleanse + 10% Stoneskin); Spirit Link (15s CD, 0 HP cost, 22/25/28/32% single-target heal + 2 Erase + 40% Wyvern HP + 1 Wyrmscale).',
            'Restoring Breath & Super Jump: Restoring Breath (20s CD) spends 0..3 Wyrmscale for 14/20/26/32% DRG Max HP party heal (3 stacks -> 15% Dragonscale Stoneskin); Super Jump (75s CD) wipes enmity, hides Wyvern 8s, and grants 3 Wyrmscale (Spirit Surge halves Jump CDs & +2 Wyrmscale).',
            'Wyrmblood Pulse (45s CD, 24% DRG Max HP party heal + 2-debuff cleanse + resets Jump/High Jump) & Dragonscale Sanctuary (75s CD, 15s: 15% Max HP Stoneskin, Knockback Immune & shared Ward -12% DMG / +30 MEVA).',
        },
        mods = function(_player, lvl)
            local list =
            {
                { xi.mod.HPP,          H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.VIT,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.MND,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.STR,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CURE_POTENCY, H.scaleTier(lvl, 20, 28, 36, 45) },
                { xi.mod.SUBTLE_BLOW,  H.scaleTier(lvl, 15, 20, 25, 30) },
                { xi.mod.POLEARM,      H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.INQUARTATA,   H.scaleTier(lvl, 10, 14, 18, 22) },
                { xi.mod.ENMITY,       -H.scaleTier(lvl, 25, 35, 45, 60) },
            }
            if xi.mod.HEALING_BREATH then
                table.insert(list, { xi.mod.HEALING_BREATH, H.scaleTier(lvl, 20, 28, 36, 45) })
            end
            return list
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
            if player ~= nil and player.setLocalVar then
                player:setLocalVar('OX_WYV_SCALE', 0)
                player:setLocalVar('OX_WYV_SCALE_EXP', 0)
            end
            detachWyvernheartListeners(player)
            unsyncWyvernHealerMods(player)
        end,
    })
end

return m
