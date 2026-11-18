-----------------------------------
-- OverlordsXI Blue Mage Crystal Spec: Magus (MAG | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set magus)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/blu_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/blue_mage')
require('scripts/globals/bluemagic')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_blu_healer_specs')

local spec = xi.overlords.spec
local MAGUS_KEY = 'magus'

-- Dual Wield (18) & Custom Trait ID (171; Azure Diffusion)
local TRAIT_DUAL_WIELD      = (xi.trait and xi.trait.DUAL_WIELD) or 18
local TRAIT_AZURE_DIFFUSION = 171

-- Custom Ability IDs (460-461; recastIds 111, 144)
local ABIL_WHITE_WIND_SURGE = 460
local ABIL_OSMOTIC_CONDUIT  = 461

-- Custom Status Effect IDs (865-866; registered in patch 0028)
local EFFECT_AZURE_CATALYST = 865
local EFFECT_OSMOTIC_CONDUIT  = 866

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.WHITE_WIND_SURGE = ABIL_WHITE_WIND_SURGE
xi.jobAbility.OSMOTIC_CONDUIT  = ABIL_OSMOTIC_CONDUIT

xi.effect = xi.effect or {}
xi.effect.AZURE_CATALYST = EFFECT_AZURE_CATALYST
xi.effect.OSMOTIC_CONDUIT  = EFFECT_OSMOTIC_CONDUIT

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.white_wind_surge = xi.actions.abilities.white_wind_surge or {}
xi.actions.abilities.osmotic_conduit  = xi.actions.abilities.osmotic_conduit or {}

xi.effects = xi.effects or {}
xi.effects.azure_catalyst = xi.effects.azure_catalyst or {}
xi.effects.osmotic_conduit  = xi.effects.osmotic_conduit or {}

local function isMagus(entity)
    return H.isSpecActive(entity, xi.job.BLU, MAGUS_KEY)
end

local BLU_HEAL_SPELLS =
{
    [xi.magic.spell.POLLEN]            = true,
    [xi.magic.spell.WILD_CARROT]       = true,
    [xi.magic.spell.HEALING_BREEZE]    = true,
    [xi.magic.spell.MAGIC_FRUIT]       = true,
    [xi.magic.spell.PLENILUNE_EMBRACE] = true,
    [xi.magic.spell.WHITE_WIND]        = true,
    [xi.magic.spell.RESTORAL]          = true,
}

local MAGUS_WS_IDS =
{
    [43]  = true, -- Sanguine Blade
    [44]  = true, -- Chant du Cygne
    [42]  = true, -- Expiacion
    [169] = true, -- Black Halo
    [172] = true, -- Mystic Boon
}

local function triggerAzureMendingWave(blu)
    if not isMagus(blu) then
        return
    end
    local pct = H.scaleTier(blu:getMainLvl(), 12, 16, 20, 24)
    if blu:hasStatusEffect(xi.effect.AZURE_LORE) then
        pct = pct * 2
    end
    H.healPartyPct(blu, pct, 15, false, false)
    H.restoreMpPct(blu, 6)
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.osmotic_conduit.onEffectGain', function(target, effect)
    effect:addMod(xi.mod.DMGMAGIC, -1000)
end)

-----------------------------------
-- Listeners & Gear Sync
-----------------------------------
local function syncMagusSird(player)
    if player == nil then
        return
    end
    local sird = 0
    if isMagus(player) and (player:hasStatusEffect(xi.effect.DIFFUSION) or player:hasStatusEffect(xi.effect.UNBRIDLED_LEARNING)) then
        sird = 100
    end
    local prev = player:getLocalVar('OX_MAG_SIRD_MOD')
    if prev ~= sird then
        if prev ~= 0 then
            player:delMod(xi.mod.SPELLINTERRUPT, prev)
        end
        if sird ~= 0 then
            player:addMod(xi.mod.SPELLINTERRUPT, sird)
        end
        player:setLocalVar('OX_MAG_SIRD_MOD', sird)
    end
end

local function attachMagusListeners(player)
    if player == nil or player:getLocalVar('OX_MAG_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_MAG_LISTENERS', 1)

    player:addListener('EFFECT_GAIN', 'OX_MAG_EFF_GAIN', function(p, eff)
        if eff and (eff:getEffectType() == xi.effect.DIFFUSION or eff:getEffectType() == xi.effect.UNBRIDLED_LEARNING) then
            syncMagusSird(p)
        end
    end)

    player:addListener('EFFECT_LOSE', 'OX_MAG_EFF_LOSE', function(p, eff)
        if eff and (eff:getEffectType() == xi.effect.DIFFUSION or eff:getEffectType() == xi.effect.UNBRIDLED_LEARNING) then
            syncMagusSird(p)
        end
    end)

    player:addListener('ATTACK', 'OX_MAG_ATTACK', function(attacker)
        if not isMagus(attacker) then
            return
        end
        -- Osmotic Conduit: every swing restores 3% Max HP and 2% Max MP to linked party
        if attacker:hasStatusEffect(EFFECT_OSMOTIC_CONDUIT) then
            H.forEachPartyMemberInRange(attacker, 15, false, function(member)
                H.healEntity(attacker, member, math.floor(member:getMaxHP() * 0.03))
                H.restoreMpPct(member, 2)
            end)
        end
        -- Sanguine Catalyst stacking
        local eff = attacker:getStatusEffect(EFFECT_AZURE_CATALYST)
        local cur = eff and (eff:getPower() or 0) or 0
        if cur + 1 >= 5 then
            attacker:delStatusEffectSilent(EFFECT_AZURE_CATALYST)
            triggerAzureMendingWave(attacker)
        else
            H.applyCustomTimedEffect(attacker, EFFECT_AZURE_CATALYST, cur + 1, 20, attacker, 0, xi.effect.CHAIN_AFFINITY, 1)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_MAG_WS', function(caster, _target, ws)
        if not isMagus(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, MAGUS_WS_IDS, { [xi.skill.SWORD] = true, [xi.skill.CLUB] = true }) then
            caster:delStatusEffectSilent(EFFECT_AZURE_CATALYST)
            triggerAzureMendingWave(caster)
        end
    end)

    player:addListener('MAGIC_USE', 'OX_MAG_MAGIC', function(caster, target, spell, action)
        if not isMagus(caster) or spell == nil then
            return
        end
        local spellId = spell:getID()
        if BLU_HEAL_SPELLS[spellId] then
            local healed = action and action:getParam() or math.floor(caster:getMaxHP() * 0.22)
            local splash = math.floor(healed * 0.85)
            H.forEachPartyMemberInRange(caster, 15, false, function(member)
                if member ~= target then
                    H.healEntity(caster, member, splash)
                end
            end)
        end
    end)
end

local function detachMagusListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_MAG_LISTENERS', 0)
    player:removeListener('OX_MAG_EFF_GAIN')
    player:removeListener('OX_MAG_EFF_LOSE')
    player:removeListener('OX_MAG_ATTACK')
    player:removeListener('OX_MAG_WS')
    player:removeListener('OX_MAG_MAGIC')
    local prev = player:getLocalVar('OX_MAG_SIRD_MOD')
    if prev ~= 0 then
        player:delMod(xi.mod.SPELLINTERRUPT, prev)
        player:setLocalVar('OX_MAG_SIRD_MOD', 0)
    end
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.diffusion.onUseAbility', function(player, target, ability)
    if isMagus(player) then
        ability:setRecast(20)
    end
    return super(player, target, ability)
end)

-----------------------------------
-- Custom Job Abilities (460-461)
-----------------------------------
m:addOverride('xi.actions.abilities.white_wind_surge.onAbilityCheck', function(player, _target, _ability)
    if not isMagus(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.white_wind_surge.onUseAbility', function(player, _target, ability)
    local total = H.healPartyPct(player, 28, 15, false, false)
    local skinAmt = math.floor(player:getMaxHP() * 0.15)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.cleanseDebuffs(member, 2)
        H.applyStoneskinBarrier(member, skinAmt, skinAmt * 2, 12, player)
    end)
    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.osmotic_conduit.onAbilityCheck', function(player, _target, _ability)
    if not isMagus(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.osmotic_conduit.onUseAbility', function(player, _target, ability)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyCustomTimedEffect(member, EFFECT_OSMOTIC_CONDUIT, 10, 12, player, 0, xi.effect.DIFFUSION, 1)
    end)
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_OSMOTIC_CONDUIT
end)

-----------------------------------
-- Crystal Definition (BLU = 16)
-----------------------------------
if xi.job and xi.job.BLU then
    spec.registerCrystal(xi.job.BLU,
    {
        id          = 2,
        key         = MAGUS_KEY,
        name        = 'Magus',
        abr         = 'MAG',
        role        = 'Healer',
        icon        = 'magus',
        reqLevel    = 10,
        extraTraits = { TRAIT_DUAL_WIELD, TRAIT_AZURE_DIFFUSION },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return { 176, ABIL_WHITE_WIND_SURGE, ABIL_OSMOTIC_CONDUIT }
            end
            return {}
        end,
        description = 'Azure Alchemist, Dual-Wielding Siphon-Healer & Blue Magic Mender (Lv10+): splashes Blue Magic heals across the party, builds Azure Catalyst on dual-wield hits/WSs, and links blades to allies via Osmotic Conduit.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): Dual Wield @ Lv10+ (+15/20/25/30% DW), +12/16/20/25% HP & MP, +10/16/22/28 MND & INT, +18/26/34/42% Cure Potency, +15/25/35/45% Fast Cast, -25/35/45/60 Enmity, +4/6/8/12 MP/tick Refresh, 100% SIRD in Diffusion/Unbridled.',
            'Azure Mending & AoE Diffusion: Healing Blue Magic splashes to all party members within 15y at 85% potency.',
            'Sanguine Catalyst: Dual-wield hits stack Azure Catalyst (max 5); at 5 stacks or on Sword/Club WS, unleashes Azure Mending Wave (12/16/20/24% Max HP AoE heal + 6% Max MP).',
            'JA Enhancements: Diffusion (20s CD) & Azure Lore (doubles Azure Mending Wave heals).',
            'White Wind Surge (20s CD, 28% HP AoE heal + 2-debuff cleanse + 15% Stoneskin) & Osmotic Conduit (25s CD, 12s -10% MDT + 3% HP / 2% MP party siphon per swing).',
        },
        mods = function(player, lvl)
            local isWiki = (player == nil) or (not player.getEquipID)
            local list =
            {
                { xi.mod.DUAL_WIELD,   H.scaleTier(lvl, 15, 20, 25, 30) },
                { xi.mod.HPP,          H.scaleTier(lvl, 12, 16, 20, 25) },
                { xi.mod.MPP,          H.scaleTier(lvl, 12, 16, 20, 25) },
                { xi.mod.MND,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.INT,          H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CURE_POTENCY, H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.FASTCAST,     H.scaleTier(lvl, 15, 25, 35, 45) },
                { xi.mod.ENMITY,       -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.REFRESH,      H.scaleTier(lvl, 4, 6, 8, 12) },
                { xi.mod.BLUE,         H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.HEALING,      H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.SWORD,        H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.CLUB,         H.scaleTier(lvl, 15, 25, 35, 50) },
            }
            if isWiki then
                table.insert(list, { xi.mod.SPELLINTERRUPT, 100 })
            end
            return list
        end,
        onApply = function(player)
            attachMagusListeners(player)
            syncMagusSird(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_AZURE_CATALYST)
                player:delStatusEffectSilent(EFFECT_OSMOTIC_CONDUIT)
            end
            detachMagusListeners(player)
        end,
    })
end

return m
