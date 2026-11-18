-----------------------------------
-- OverlordsXI Blue Mage Crystal Spec: Magus (MAG | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set magus)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/blu_specs')
require('modules/custom/lua/overlords_shared_slots')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/blue_mage')
require('scripts/globals/bluemagic')
require('scripts/globals/magic')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_blu_healer_specs')

local spec      = xi.overlords.spec
local slots     = xi.overlords.slots
local MAGUS_KEY = 'magus'

-- Dual Wield (18) & Existing Magus Trait ID (171)
local TRAIT_DUAL_WIELD      = (xi.trait and xi.trait.DUAL_WIELD) or 18
local TRAIT_AZURE_DIFFUSION = 171

-- Ability IDs: Diffusion (176), Burst Affinity (95), Custom JAs (460-461; recastIds 111, 144)
local ABIL_BURST_AFFINITY   = 95
local ABIL_DIFFUSION        = 176
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

xi.actions.spells = xi.actions.spells or {}
xi.actions.spells.blue = xi.actions.spells.blue or {}
xi.actions.spells.blue.winds_of_promy = xi.actions.spells.blue.winds_of_promy or {}

xi.effects = xi.effects or {}
xi.effects.azure_catalyst = xi.effects.azure_catalyst or {}
xi.effects.osmotic_conduit  = xi.effects.osmotic_conduit or {}

local function isMagus(entity)
    return H.isSpecActive(entity, xi.job.BLU, MAGUS_KEY)
end

local function hasSwordMain(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.SWORD
end

-- Lv.10+ Zero-Scroll Monster Medic Kit (canUseSpellOverride; no learning or set points required while Magus)
local MAGUS_UNLOCKED_SPELLS =
{
    [xi.magic.spell.COCOON]             = true, -- 547
    [xi.magic.spell.WILD_CARROT]        = true, -- 578
    [xi.magic.spell.HEALING_BREEZE]     = true, -- 581
    [xi.magic.spell.BLANK_GAZE]         = true, -- 592
    [xi.magic.spell.MAGIC_FRUIT]        = true, -- 593
    [xi.magic.spell.DIAMONDHIDE]        = true, -- 632
    [xi.magic.spell.PLENILUNE_EMBRACE]  = true, -- 658
    [xi.magic.spell.BATTERY_CHARGE]     = true, -- 662
    [xi.magic.spell.WINDS_OF_PROMYVION] = true, -- 681
    [xi.magic.spell.WHITE_WIND]         = true, -- 690
    [xi.magic.spell.SUDDEN_LUNGE]       = true, -- 692
}

-- High-level backported spells whose MP cost scales proportionally below Lv.65
local LEVEL_SCALED_MP_SPELLS =
{
    [xi.magic.spell.MAGIC_FRUIT]        = true,
    [xi.magic.spell.PLENILUNE_EMBRACE]  = true,
    [xi.magic.spell.WHITE_WIND]         = true,
    [xi.magic.spell.WINDS_OF_PROMYVION] = true,
    [xi.magic.spell.DIAMONDHIDE]        = true,
    [xi.magic.spell.BATTERY_CHARGE]     = true,
}

-- Tactical Monster Casts that grant +1 Azure Catalyst
local TACTICAL_CATALYST_SPELLS =
{
    [xi.magic.spell.BLANK_GAZE]   = true,
    [xi.magic.spell.SUDDEN_LUNGE] = true,
    [xi.magic.spell.COCOON]       = true,
    [xi.magic.spell.GEIST_WALL]   = true,
}

-- Azure Convergence eligible spells (instant-cast, -50% MP, 65% 15y party splash)
local CONVERGENCE_SPELLS =
{
    [xi.magic.spell.WILD_CARROT]        = true,
    [xi.magic.spell.MAGIC_FRUIT]        = true,
    [xi.magic.spell.PLENILUNE_EMBRACE]  = true,
    [xi.magic.spell.WINDS_OF_PROMYVION] = true,
    [xi.magic.spell.DIAMONDHIDE]        = true,
}

-- Diffusion eligible Blue Magic buffs (15y party splash)
local DIFFUSION_BUFF_SPELLS =
{
    [xi.magic.spell.DIAMONDHIDE]     = true,
    [xi.magic.spell.BATTERY_CHARGE]  = true,
    [xi.magic.spell.COCOON]          = true,
    [xi.magic.spell.ERRATIC_FLUTTER] = true,
    [xi.magic.spell.MIGHTY_GUARD]    = true,
}

-- All healing/support Blue Magic (0 MP & instant-cast during Azure Lore)
local MAGUS_HEAL_SUPPORT_SPELLS =
{
    [xi.magic.spell.POLLEN]             = true,
    [xi.magic.spell.WILD_CARROT]        = true,
    [xi.magic.spell.HEALING_BREEZE]     = true,
    [xi.magic.spell.MAGIC_FRUIT]        = true,
    [xi.magic.spell.PLENILUNE_EMBRACE]  = true,
    [xi.magic.spell.WHITE_WIND]         = true,
    [xi.magic.spell.WINDS_OF_PROMYVION] = true,
    [xi.magic.spell.EXUVIATION]         = true,
    [xi.magic.spell.RESTORAL]           = true,
    [xi.magic.spell.DIAMONDHIDE]        = true,
    [xi.magic.spell.BATTERY_CHARGE]     = true,
    [xi.magic.spell.COCOON]             = true,
    [xi.magic.spell.METALLIC_BODY]      = true,
    [xi.magic.spell.SALINE_COAT]        = true,
    [xi.magic.spell.REACTOR_COOL]       = true,
    [xi.magic.spell.ERRATIC_FLUTTER]    = true,
    [xi.magic.spell.MIGHTY_GUARD]       = true,
}

local MAGUS_SWORD_WS_IDS =
{
    [32] = true, -- Fast Blade
    [33] = true, -- Burning Blade
    [34] = true, -- Red Lotus Blade
    [35] = true, -- Flat Blade
    [36] = true, -- Shining Blade
    [37] = true, -- Seraph Blade
    [38] = true, -- Circle Blade
    [39] = true, -- Spirits Within
    [40] = true, -- Vorpal Blade
    [41] = true, -- Swift Blade
    [42] = true, -- Savage Blade
    [43] = true, -- Knights of Round
    [44] = true, -- Death Blossom
    [45] = true, -- Atonement
    [46] = true, -- Expiacion
    [47] = true, -- Chant du Cygne
    [48] = true, -- Requiescat
}

local function findLowestHpPartyMembers(caster, radius, count)
    local candidates = {}
    H.forEachPartyMemberInRange(caster, radius or 15, false, function(member)
        local maxHp = math.max(1, member:getMaxHP())
        local curHp = member:getHP()
        local ratio = curHp / maxHp
        table.insert(candidates, { unit = member, ratio = ratio, missing = maxHp - curHp })
    end)

    table.sort(candidates, function(a, b)
        if a.ratio ~= b.ratio then
            return a.ratio < b.ratio
        end
        return a.missing > b.missing
    end)

    local out = {}
    local limit = math.min(count or 1, #candidates)
    for i = 1, limit do
        table.insert(out, candidates[i].unit)
    end
    return out
end

local function hasAzureConvergence(player)
    if player == nil then
        return false
    end
    if player:hasStatusEffect(xi.effect.AZURE_LORE) then
        return true
    end
    local eff = player:getStatusEffect(EFFECT_AZURE_CATALYST)
    return eff ~= nil and (eff:getSubPower() or 0) == 1
end

local function grantAzureConvergence(player, duration)
    if player == nil then
        return
    end
    H.applyCustomTimedEffect(player, EFFECT_AZURE_CATALYST, 3, duration or 12, player, 1, xi.effect.DIVINE_SEAL, 2)
end

local function grantAzureCatalyst(player, stacks)
    if not isMagus(player) then
        return
    end
    if hasAzureConvergence(player) then
        return
    end
    local eff = player:getStatusEffect(EFFECT_AZURE_CATALYST)
    local cur = (eff and (eff:getSubPower() or 0) == 0) and (eff:getPower() or 0) or 0
    local nextStacks = cur + (stacks or 1)
    if nextStacks >= 3 then
        grantAzureConvergence(player, 12)
    else
        H.applyCustomTimedEffect(player, EFFECT_AZURE_CATALYST, nextStacks, 30, player, 0, xi.effect.CHAIN_AFFINITY, 1)
    end
end

local function computeMagusPassives(lvl)
    return
    {
        { mod = xi.mod.DUAL_WIELD,   val = H.scaleTier(lvl, 15, 20, 25, 30), key = 'DW'   },
        { mod = xi.mod.HPP,          val = H.scaleTier(lvl, 12, 16, 20, 25), key = 'HPP'  },
        { mod = xi.mod.MPP,          val = H.scaleTier(lvl, 12, 16, 20, 25), key = 'MPP'  },
        { mod = xi.mod.MND,          val = H.scaleTier(lvl, 10, 16, 22, 28), key = 'MND'  },
        { mod = xi.mod.VIT,          val = H.scaleTier(lvl, 10, 16, 22, 28), key = 'VIT'  },
        { mod = xi.mod.INT,          val = H.scaleTier(lvl, 10, 16, 22, 28), key = 'INT'  },
        { mod = xi.mod.CURE_POTENCY, val = H.scaleTier(lvl, 16, 24, 32, 40), key = 'CURE' },
        { mod = xi.mod.FASTCAST,     val = H.scaleTier(lvl, 15, 25, 35, 45), key = 'FC'   },
        { mod = xi.mod.SUBTLE_BLOW,  val = H.scaleTier(lvl, 15, 20, 25, 30), key = 'SB'   },
        { mod = xi.mod.REFRESH,      val = H.scaleTier(lvl, 3, 5, 7, 10),    key = 'REF'  },
        { mod = xi.mod.SWORD,        val = H.scaleTier(lvl, 15, 25, 35, 50), key = 'SWD'  },
        { mod = xi.mod.BLUE,         val = H.scaleTier(lvl, 15, 25, 35, 50), key = 'BLU'  },
        { mod = xi.mod.ENMITY,       val = -H.scaleTier(lvl, 25, 35, 45, 60), key = 'ENM' },
        { mod = xi.mod.SPELLINTERRUPT, val = 100,                            key = 'SIRD' },
    }
end

local function syncMagusSwordMods(player)
    if player == nil or not player.getLocalVar or not player.addMod or not player.delMod then
        return
    end
    local active = isMagus(player) and hasSwordMain(player)
    local lvl    = player.getMainLvl and player:getMainLvl() or 1
    local defs   = computeMagusPassives(lvl)

    for _, d in ipairs(defs) do
        local varName = 'OX_MAG_MOD_' .. d.key
        local want    = active and d.val or 0
        local prev    = player:getLocalVar(varName) or 0
        if prev ~= want then
            if prev ~= 0 then
                player:delMod(d.mod, prev)
            end
            if want ~= 0 then
                player:addMod(d.mod, want)
            end
            player:setLocalVar(varName, want)
        end
    end
end

local function clearMagusSwordMods(player)
    if player == nil or not player.getLocalVar or not player.delMod then
        return
    end
    local defs = computeMagusPassives(75)
    for _, d in ipairs(defs) do
        local varName = 'OX_MAG_MOD_' .. d.key
        local prev    = player:getLocalVar(varName) or 0
        if prev ~= 0 then
            player:delMod(d.mod, prev)
            player:setLocalVar(varName, 0)
        end
    end
end

local function applyDiffusedBuffToParty(caster, target, spellId)
    local blueSkill = utils.clamp(caster:getSkillLevel(xi.skill.BLUE_MAGIC), 0, 500)
    H.forEachPartyMemberInRange(caster, 15, false, function(member)
        if member ~= target then
            if spellId == xi.magic.spell.DIAMONDHIDE then
                local power = math.floor((blueSkill / 3) * 2)
                member:addStatusEffect(xi.effect.STONESKIN, { power = power, duration = 300, origin = caster, tier = 2 })
            elseif spellId == xi.magic.spell.BATTERY_CHARGE then
                local power = 3 + caster:getMod(xi.mod.ENHANCES_REFRESH)
                member:addStatusEffect(xi.effect.REFRESH, { power = power, duration = 300, origin = caster })
            elseif spellId == xi.magic.spell.COCOON then
                member:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = 50, duration = 90, origin = caster })
            elseif spellId == xi.magic.spell.ERRATIC_FLUTTER then
                member:addStatusEffect(xi.effect.HASTE, { power = 3000, duration = 300, origin = caster })
            elseif spellId == xi.magic.spell.MIGHTY_GUARD then
                member:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = 25, duration = 180, origin = caster })
                member:addStatusEffect(xi.effect.REGEN, { power = 30, duration = 180, origin = caster })
                member:addStatusEffect(xi.effect.HASTE, { power = 1500, duration = 180, origin = caster })
                slots.applyPartyWard(caster, member, -1500, 35, 180, xi.effect.MIGHTY_GUARD)
            end
        elseif spellId == xi.magic.spell.MIGHTY_GUARD then
            slots.applyPartyWard(caster, member, -1500, 35, 180, xi.effect.MIGHTY_GUARD)
        end
    end)
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.osmotic_conduit.onEffectGain', function(_target, _effect)
    -- Party -12% DMG / +25 MEVA is routed through shared EFF_OX_SUP_WARD
end)

-----------------------------------
-- Spell Access & Blue Magic Overrides
-----------------------------------
m:addOverride('xi.spells.canUseSpellOverride', function(player, spell)
    if
        player ~= nil and
        spell ~= nil and
        isMagus(player) and
        (player:getMainLvl() or 1) >= 10 and
        MAGUS_UNLOCKED_SPELLS[spell:getID()]
    then
        return true
    end
    return super(player, spell)
end)

m:addOverride('xi.actions.spells.blue.white_wind.onSpellCast', function(caster, target, spell, action)
    if not isMagus(caster) then
        return super(caster, target, spell, action)
    end

    local pct        = H.scaleTier(caster:getMainLvl(), 20, 23, 26, 30)
    local mnd        = caster:getStat(xi.mod.MND) or 0
    local rawHeal    = math.floor(caster:getMaxHP() * (pct / 100)) + mnd
    local curePot    = math.min(50, caster:getMod(xi.mod.CURE_POTENCY)) + caster:getMod(xi.mod.CURE_POTENCY_II)
    local rcvdPot    = target:getMod(xi.mod.CURE_POTENCY_RCVD)
    local final      = math.floor(rawHeal * (1 + curePot / 100) * (1 + rcvdPot / 100))
    final            = utils.clamp(final, 0, math.max(0, target:getMaxHP() - target:getHP()))

    if final > 0 then
        target:addHP(final)
    end
    target:wakeUp()
    caster:updateEnmityFromCure(target, final)

    if target:getID() == spell:getPrimaryTargetID() then
        spell:setMsg(xi.msg.basic.MAGIC_RECOVERS_HP)
        caster:timer(0, function(actor)
            if actor ~= nil and actor.addRecast then
                actor:addRecast(xi.recast.MAGIC, xi.magic.spell.WHITE_WIND, 18)
            end
        end)
    else
        spell:setMsg(xi.msg.basic.SELF_HEAL_SECONDARY)
    end

    return final
end)

m:addOverride('xi.actions.spells.blue.winds_of_promy.onMagicCastingCheck', function(_caster, _target, _spell)
    return 0
end)

m:addOverride('xi.actions.spells.blue.winds_of_promy.onSpellCast', function(caster, target, spell, _action)
    local count = (isMagus(caster) and hasAzureConvergence(caster)) and 2 or 1
    local removed = H.cleanseDebuffs(target, count)
    if removed == 0 and target.eraseStatusEffect then
        local erased = target:eraseStatusEffect()
        if erased ~= xi.effect.NONE then
            removed = 1
        end
    end
    if removed > 0 then
        spell:setMsg(xi.msg.basic.MAGIC_ERASE)
    else
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
    end
    return removed
end)

m:addOverride('xi.actions.spells.blue.sudden_lunge.onSpellCast', function(caster, target, spell, action)
    if not isMagus(caster) then
        return super(caster, target, spell, action)
    end

    local params          = xi.spells.blue.getDefaultParams(caster)
    params.ecosystem      = xi.ecosystem.VERMIN
    params.tpModifier     = xi.spells.blue.tpMod.DAMAGE
    params.attackType     = xi.attackType.PHYSICAL
    params.damageType     = xi.damageType.SLASHING
    params.skillchainType = xi.skillchainType.DETONATION
    params.dStat          = xi.mod.INT
    params.numHits        = 1
    params.ftp0           = 1.5
    params.ftp1500        = 2.5
    params.ftp3000        = 3
    params.ftpAzure       = 3.5
    params.baseDamageCap  = 100
    params.agi_wsc        = 0.4

    local damage = xi.spells.blue.usePhysicalSpell(caster, target, spell, params, action)

    caster:timer(0, function(actor)
        if actor ~= nil and actor.addRecast then
            actor:addRecast(xi.recast.MAGIC, xi.magic.spell.SUDDEN_LUNGE, 20)
        end
    end)

    if params.hitsLanded > 0 and target ~= nil and target:isAlive() then
        if
            not xi.data.statusEffect.isTargetImmune(target, xi.effect.STUN, xi.element.THUNDER) and
            not xi.data.statusEffect.isTargetResistant(caster, target, xi.effect.STUN) and
            not xi.data.statusEffect.isEffectNullified(target, xi.effect.STUN, 0)
        then
            target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = caster })
        end
    end

    return damage
end)

m:addOverride('xi.spells.blue.useMagicalSpell', function(caster, target, spell, params, action)
    local hadBurst = isMagus(caster) and caster:hasStatusEffect(xi.effect.BURST_AFFINITY)
    local damage   = super(caster, target, spell, params, action)
    if hadBurst then
        local healAmt = math.floor(caster:getMaxHP() * 0.18)
        for _, ally in ipairs(findLowestHpPartyMembers(caster, 15, 2)) do
            H.healEntity(caster, ally, healAmt)
        end
        grantAzureCatalyst(caster, 1)
    end
    return damage
end)

-----------------------------------
-- Listeners & Gear Sync
-----------------------------------
local function attachMagusListeners(player)
    if player == nil or player:getLocalVar('OX_MAG_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_MAG_LISTENERS', 1)

    player:addListener('ITEM_EQUIP', 'OX_MAG_EQUIP', function(p)
        syncMagusSwordMods(p)
    end)

    player:addListener('ITEM_UNEQUIP', 'OX_MAG_UNEQUIP', function(p)
        syncMagusSwordMods(p)
    end)

    player:addListener('TICK', 'OX_MAG_TICK', function(p)
        syncMagusSwordMods(p)
    end)

    player:addListener('ATTACK', 'OX_MAG_ATTACK', function(attacker)
        if not isMagus(attacker) or not hasSwordMain(attacker) then
            return
        end
        if attacker:hasStatusEffect(EFFECT_OSMOTIC_CONDUIT) then
            local now  = os.time()
            local last = attacker:getLocalVar('OX_MAG_OSMOTIC_ICD') or 0
            if now > last then
                attacker:setLocalVar('OX_MAG_OSMOTIC_ICD', now)
                local healAmt = math.floor(attacker:getMaxHP() * 0.03)
                for _, ally in ipairs(findLowestHpPartyMembers(attacker, 15, 1)) do
                    H.healEntity(attacker, ally, healAmt)
                end
            end
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_MAG_WS', function(caster, _target, ws)
        if not isMagus(caster) or not hasSwordMain(caster) then
            return
        end
        if H.isWeaponSkillInSet(ws, MAGUS_SWORD_WS_IDS, { [xi.skill.SWORD] = true }) then
            local pct     = H.scaleTier(caster:getMainLvl(), 14, 17, 20, 24)
            local healAmt = math.floor(caster:getMaxHP() * (pct / 100))
            for _, ally in ipairs(findLowestHpPartyMembers(caster, 15, 1)) do
                H.healEntity(caster, ally, healAmt)
            end
            H.restoreMpPct(caster, 6)
            grantAzureCatalyst(caster, 2)
        end
    end)

    player:addListener('MAGIC_START', 'OX_MAG_MAGIC_START', function(caster, _target, spell, _action)
        if not isMagus(caster) or spell == nil then
            return
        end
        if spell.getSkillType and spell:getSkillType() ~= xi.skill.BLUE_MAGIC then
            return
        end

        local spellId = spell.getID and spell:getID() or 0
        local baseMp  = spell.getMPCost and spell:getMPCost() or 0
        local mpCost  = baseMp
        local lvl     = caster.getMainLvl and caster:getMainLvl() or 1

        if LEVEL_SCALED_MP_SPELLS[spellId] and lvl < 65 and baseMp > 0 then
            mpCost = math.max(1, math.floor(baseMp * (lvl / 65) + 0.5))
        end

        local hasLore = caster:hasStatusEffect(xi.effect.AZURE_LORE)
        local hasConv = hasAzureConvergence(caster)

        if hasLore and MAGUS_HEAL_SUPPORT_SPELLS[spellId] then
            mpCost = 0
            if spell.setCastTime then
                spell:setCastTime(0)
            end
        elseif hasConv and CONVERGENCE_SPELLS[spellId] then
            if spell.setCastTime then
                spell:setCastTime(0)
            end
            if mpCost > 0 then
                mpCost = math.max(1, math.floor(mpCost * 0.5))
            end
        end

        if mpCost ~= baseMp and spell.setMPCost then
            spell:setMPCost(mpCost)
        end

        caster:setLocalVar('OX_MAG_CONVERGENCE_PENDING', (hasConv and CONVERGENCE_SPELLS[spellId]) and 1 or 0)
        caster:setLocalVar('OX_MAG_DIFFUSION_PENDING', (caster:hasStatusEffect(xi.effect.DIFFUSION) and DIFFUSION_BUFF_SPELLS[spellId]) and 1 or 0)
    end)

    player:addListener('MAGIC_USE', 'OX_MAG_MAGIC', function(caster, target, spell, action)
        if not isMagus(caster) or spell == nil then
            return
        end
        if spell.getSkillType and spell:getSkillType() ~= xi.skill.BLUE_MAGIC then
            return
        end

        local spellId = spell.getID and spell:getID() or 0

        if TACTICAL_CATALYST_SPELLS[spellId] then
            grantAzureCatalyst(caster, 1)
        end

        local convPending = caster:getLocalVar('OX_MAG_CONVERGENCE_PENDING') == 1
        caster:setLocalVar('OX_MAG_CONVERGENCE_PENDING', 0)
        if convPending and CONVERGENCE_SPELLS[spellId] then
            if not caster:hasStatusEffect(xi.effect.AZURE_LORE) then
                local eff = caster:getStatusEffect(EFFECT_AZURE_CATALYST)
                if eff ~= nil and (eff:getSubPower() or 0) == 1 then
                    caster:delStatusEffectSilent(EFFECT_AZURE_CATALYST)
                end
            end

            if spellId == xi.magic.spell.WINDS_OF_PROMYVION then
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    if member ~= target then
                        H.cleanseDebuffs(member, 2)
                    end
                end)
            elseif spellId == xi.magic.spell.DIAMONDHIDE then
                local blueSkill = utils.clamp(caster:getSkillLevel(xi.skill.BLUE_MAGIC), 0, 500)
                local power     = math.floor((blueSkill / 3) * 2)
                local splash    = math.max(1, math.floor(power * 0.65))
                H.forEachPartyMemberInRange(caster, 15, false, function(member)
                    if member ~= target then
                        H.applyStoneskinBarrier(member, splash, math.floor(power * 1.65), 300, caster)
                    end
                end)
            else
                local healed = action and action:getParam() or math.floor(caster:getMaxHP() * 0.22)
                local splash = math.floor(healed * 0.65)
                if splash > 0 then
                    H.forEachPartyMemberInRange(caster, 15, false, function(member)
                        if member ~= target then
                            H.healEntity(caster, member, splash)
                        end
                    end)
                end
            end
        end

        local diffPending = caster:getLocalVar('OX_MAG_DIFFUSION_PENDING') == 1
        caster:setLocalVar('OX_MAG_DIFFUSION_PENDING', 0)
        if diffPending and DIFFUSION_BUFF_SPELLS[spellId] then
            if caster:hasStatusEffect(xi.effect.DIFFUSION) then
                caster:delStatusEffectSilent(xi.effect.DIFFUSION)
            end
            applyDiffusedBuffToParty(caster, target, spellId)
        end
    end)

    player:addListener('MAGIC_INTERRUPTED', 'OX_MAG_MAGIC_INT', function(caster, _target, _spell, _action)
        if caster ~= nil and caster.setLocalVar then
            caster:setLocalVar('OX_MAG_CONVERGENCE_PENDING', 0)
            caster:setLocalVar('OX_MAG_DIFFUSION_PENDING', 0)
        end
    end)
end

local function detachMagusListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_MAG_LISTENERS', 0)
    player:setLocalVar('OX_MAG_CONVERGENCE_PENDING', 0)
    player:setLocalVar('OX_MAG_DIFFUSION_PENDING', 0)
    player:removeListener('OX_MAG_EQUIP')
    player:removeListener('OX_MAG_UNEQUIP')
    player:removeListener('OX_MAG_TICK')
    player:removeListener('OX_MAG_ATTACK')
    player:removeListener('OX_MAG_WS')
    player:removeListener('OX_MAG_MAGIC_START')
    player:removeListener('OX_MAG_MAGIC')
    player:removeListener('OX_MAG_MAGIC_INT')
    clearMagusSwordMods(player)
end

-----------------------------------
-- Vanilla JA Enhancements
-----------------------------------
m:addOverride('xi.actions.abilities.diffusion.onUseAbility', function(player, target, ability)
    if isMagus(player) then
        ability:setRecast(35)
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.burst_affinity.onUseAbility', function(player, target, ability)
    if isMagus(player) then
        ability:setRecast(30)
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
    ability:setRecast(40)
    local total = H.healPartyPct(player, 24, 15, false, false)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.cleanseDebuffs(member, 2)
    end)
    grantAzureConvergence(player, 12)
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
    ability:setRecast(60)
    local skinAmt = math.floor(player:getMaxHP() * 0.15)
    H.forEachPartyMemberInRange(player, 15, false, function(member)
        H.applyStoneskinBarrier(member, skinAmt, skinAmt * 2, 12, player)
        slots.applyPartyWard(player, member, -1200, 25, 12, xi.effect.RAMPART)
    end)
    H.applyCustomTimedEffect(player, EFFECT_OSMOTIC_CONDUIT, 1, 12, player, 0, xi.effect.DIFFUSION, 1)
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
                return { ABIL_DIFFUSION, ABIL_BURST_AFFINITY, ABIL_WHITE_WIND_SURGE, ABIL_OSMOTIC_CONDUIT }
            end
            return {}
        end,
        description = 'Dual-Sword Combat Healer (Lv10+): zero-scroll Monster Medic kit with level-scaled MP, Sword WS smart-heals building Azure Catalyst into instant AoE-splash Azure Convergence, and disciplined party wards.',
        highlights  =
        {
            'Passives (Sword in MAIN, Lv10/30/50/70+): Dual Wield (-15/20/25/30% delay), +12/16/20/25% HP & MP, +10/16/22/28 MND/VIT/INT, +16/24/32/40% Cure Potency, +15/25/35/45% Fast Cast, +15/20/25/30% Subtle Blow, +3/5/7/10 Refresh, +15/25/35/50 Sword/Blue, -25/35/45/60 Enmity, 100% SIRD.',
            'Lv10+ Monster Medic Kit: Auto-grants Wild Carrot, Healing Breeze, Magic Fruit, White Wind (18s CD, 20/23/26/30% Max HP + MND), Plenilune Embrace, Winds of Promyvion, Diamondhide, Battery Charge, Cocoon, Blank Gaze & Sudden Lunge (20s CD, 2s Stun) with Lv<65 MP scaling.',
            'Azure Catalyst -> Azure Convergence: Sword WSs smart-heal lowest-HP ally (14/17/20/24% Max HP) + 6% MP + 2 Catalyst; Tactical casts grant +1 Catalyst. At 3 stacks, Azure Convergence (12s) makes your next heal/cleanse/barrier instant, -50% MP, and 65% 15y party splash.',
            'JAs: Diffusion (35s CD) & Burst Affinity (30s CD, heals 2 lowest-HP allies 18% + 1 Catalyst); White Wind Surge (40s CD, 24% party heal + 2-debuff cleanse + Convergence); Osmotic Conduit (60s CD, 15% party Stoneskin + shared ward -12% DMG/+25 MEVA + 3% Dual-Sword siphon 1s ICD); Azure Lore (0 MP, instant, permanent Convergence).',
        },
        mods = function(player, lvl)
            local isWiki = (player == nil) or (not player.getEquipID)
            if not isWiki then
                return {}
            end
            local list = {}
            for _, d in ipairs(computeMagusPassives(lvl)) do
                table.insert(list, { d.mod, d.val })
            end
            return list
        end,
        onApply = function(player)
            attachMagusListeners(player)
            syncMagusSwordMods(player)
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
