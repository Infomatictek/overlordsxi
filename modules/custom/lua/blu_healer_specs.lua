-----------------------------------
-- SoulspireXI Blue Mage Crystal Spec: Magus (MAG | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set magus)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
if not (xi.soulspire and xi.soulspire.spec and xi.soulspire.spec.jobs and xi.soulspire.spec.jobs[xi.job.BLU]) then
    require('modules/custom/lua/blu_specs')
end
local H = require('modules/custom/lua/soulspire_healer_helpers')
require('scripts/globals/job_utils/blue_mage')
require('scripts/globals/bluemagic')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('soulspire_blu_healer_specs')

local spec = xi.soulspire.spec
local MAGUS_KEY = 'magus'

xi.soulspire                = xi.soulspire or {}
xi.soulspire.bluHealerSpecs = xi.soulspire.bluHealerSpecs or {}

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
}

-- Curated 100% single-target-enemy-safe Magus baseline loadout (Priority 1 -> 3).
-- Skips post-75 DB-disabled spells (Erratic Flutter 710, Restoral 711).
local MAGUS_BASELINE_SPELLS =
{
    -- Priority 1: Core Heals & Cleanse
    { id = xi.magic.spell.MAGIC_FRUIT,        setPts = 3, reqLvl = 58, baseMp = 72  },
    { id = xi.magic.spell.WHITE_WIND,         setPts = 5, reqLvl = 94, baseMp = 145 },
    { id = xi.magic.spell.PLENILUNE_EMBRACE,  setPts = 4, reqLvl = 76, baseMp = 106 },
    { id = xi.magic.spell.HEALING_BREEZE,     setPts = 4, reqLvl = 16, baseMp = 55  },
    { id = xi.magic.spell.WILD_CARROT,        setPts = 3, reqLvl = 30, baseMp = 37  },
    { id = xi.magic.spell.WINDS_OF_PROMYVION, setPts = 5, reqLvl = 89, baseMp = 36  },
    { id = xi.magic.spell.POLLEN,             setPts = 1, reqLvl = 1,  baseMp = 8   },

    -- Priority 2: Diffusion Party Wards, Refresh & Haste
    { id = xi.magic.spell.BATTERY_CHARGE,     setPts = 3, reqLvl = 79, baseMp = 50  },
    { id = xi.magic.spell.DIAMONDHIDE,        setPts = 3, reqLvl = 67, baseMp = 99  },
    { id = xi.magic.spell.REFUELING,          setPts = 4, reqLvl = 48, baseMp = 29  },
    { id = xi.magic.spell.COCOON,             setPts = 1, reqLvl = 8,  baseMp = 10  },
    { id = xi.magic.spell.METALLIC_BODY,      setPts = 1, reqLvl = 8,  baseMp = 19  },
    { id = xi.magic.spell.ZEPHYR_MANTLE,      setPts = 2, reqLvl = 65, baseMp = 31  },

    -- Priority 3: Single-Target Scalpel Utility (zero enemy AoE/conal pulls)
    { id = xi.magic.spell.HEAD_BUTT,          setPts = 3, reqLvl = 12, baseMp = 12  },
    { id = xi.magic.spell.BLANK_GAZE,         setPts = 2, reqLvl = 38, baseMp = 25  },
    { id = xi.magic.spell.SUDDEN_LUNGE,       setPts = 4, reqLvl = 95, baseMp = 18  },
    { id = xi.magic.spell.DIGEST,             setPts = 2, reqLvl = 36, baseMp = 20  },
}

local MAGUS_SPELL_BY_ID = {}
for idx, entry in ipairs(MAGUS_BASELINE_SPELLS) do
    entry.bit = bit.lshift(1, idx - 1)
    MAGUS_SPELL_BY_ID[entry.id] = entry
end

local SOUL_TAG =
{
    magus        = 'MAG',
    azurebastion = 'AZB',
}

local function getBluMaxSlots(lvl)
    return math.max(6, math.min(20, math.floor((math.max(1, lvl or 1) - 1) / 10) * 2 + 6))
end

local function getBluMaxPoints(player, lvl)
    local l = math.max(1, lvl or 1)
    local pts = math.max(0, math.min(55, math.floor((l - 1) / 10) * 5 + 10))
    if l >= 75 and player.getMerit and xi.merit and xi.merit.ASSIMILATION then
        pts = pts + (player:getMerit(xi.merit.ASSIMILATION) or 0)
    end
    return pts
end

local function getScaledMagusMp(lvl, entry)
    if (lvl or 1) >= entry.reqLvl then
        return entry.baseMp
    end
    local ratio = math.min(1.0, math.max(0.20, (lvl or 1) / entry.reqLvl))
    return math.max(4, math.floor(entry.baseMp * ratio + 0.5))
end

local function getCurrentBluSlots(player)
    local slots = {}
    for i = 1, 20 do
        slots[i] = 0
    end
    if player == nil then
        return slots
    end
    if player.getBlueMagicSlots then
        local raw = player:getBlueMagicSlots()
        if type(raw) == 'table' then
            for i = 1, 20 do
                slots[i] = tonumber(raw[i]) or 0
            end
        end
        return slots
    end
    if player.getSetBlueSpells then
        local raw = player:getSetBlueSpells()
        if type(raw) == 'table' then
            for i = 1, math.min(20, #raw) do
                slots[i] = tonumber(raw[i]) or 0
            end
        end
    end
    return slots
end

local function learnMagusBaselineSpells(player)
    if player == nil or not player.hasSpell or not player.addSpell then
        return
    end

    local mask = player:getCharVar('OX_BLU_MAGUS_LEARNED') or 0
    local toGrant = {}
    for _, entry in ipairs(MAGUS_BASELINE_SPELLS) do
        if not player:hasSpell(entry.id) then
            table.insert(toGrant, entry)
        end
    end

    if #toGrant == 0 then
        return
    end

    for i, entry in ipairs(toGrant) do
        local isLast = (i == #toGrant)
        player:addSpell(entry.id, { silentLog = true, saveToDB = true, sendUpdate = isLast })
        mask = bit.bor(mask, entry.bit)
    end
    player:setCharVar('OX_BLU_MAGUS_LEARNED', mask)
end

local function saveSoulSpells(player, soulKey)
    local tag = SOUL_TAG[soulKey]
    if player == nil or tag == nil or not player.setCharVar then
        return
    end

    local slots = getCurrentBluSlots(player)
    for chunk = 0, 6 do
        local baseIdx = chunk * 3
        local b0 = (slots[baseIdx + 1] > 0) and (slots[baseIdx + 1] - 0x200) or 0
        local b1 = (baseIdx + 2 <= 20 and slots[baseIdx + 2] > 0) and (slots[baseIdx + 2] - 0x200) or 0
        local b2 = (baseIdx + 3 <= 20 and slots[baseIdx + 3] > 0) and (slots[baseIdx + 3] - 0x200) or 0
        local packed = b0 + b1 * 256 + b2 * 65536
        player:setCharVar(string.format('OX_BLU_SET_%s_%d', tag, chunk + 1), packed)
    end
    player:setCharVar(string.format('OX_BLU_SET_%s_SAVED', tag), 1)
end

local function syncMagusSpells(player, opts)
    opts = opts or {}
    if player == nil or not isMagus(player) then
        return
    end
    if player.getLocalVar and player:getLocalVar('OX_MAG_SYNCING_SPELLS') == 1 then
        return
    end

    if player.setLocalVar then
        player:setLocalVar('OX_MAG_SYNCING_SPELLS', 1)
    end

    learnMagusBaselineSpells(player)

    if player.setBlueMagicSpell then
        local lvl       = player:getMainLvl() or 1
        local maxSlots  = getBluMaxSlots(lvl)
        local maxPoints = getBluMaxPoints(player, lvl)

        local forceReset  = opts.forceReset == true
        local slots       = getCurrentBluSlots(player)
        local equippedSet = {}
        local equippedCnt = 0
        local usedPoints  = 0
        local emptySlots  = {}

        if forceReset then
            for i = 0, 19 do
                if slots[i + 1] ~= 0 then
                    player:setBlueMagicSpell(i, 0, false)
                end
            end
            for i = 0, maxSlots - 1 do
                table.insert(emptySlots, i)
            end
        else
            for i = 0, 19 do
                local sid = slots[i + 1]
                if sid > 0 then
                    equippedSet[sid] = true
                    equippedCnt = equippedCnt + 1
                    local entry = MAGUS_SPELL_BY_ID[sid]
                    if entry then
                        usedPoints = usedPoints + entry.setPts
                    end
                elseif i < maxSlots then
                    table.insert(emptySlots, i)
                end
            end
        end

        local isFirstSeed = (player:getCharVar('OX_BLU_MAGUS_SET_INIT') == 0) or (equippedCnt == 0)
        local shouldFill  = forceReset or isFirstSeed or (opts.isLevelUp == true)
        local changed     = false

        if shouldFill and #emptySlots > 0 then
            local emptyCursor = 1
            for _, entry in ipairs(MAGUS_BASELINE_SPELLS) do
                if emptyCursor > #emptySlots then
                    break
                end
                if
                    not equippedSet[entry.id] and
                    player:hasSpell(entry.id) and
                    lvl >= entry.reqLvl and
                    (usedPoints + entry.setPts) <= maxPoints
                then
                    local slotIdx = emptySlots[emptyCursor]
                    emptyCursor = emptyCursor + 1
                    player:setBlueMagicSpell(slotIdx, entry.id, false)
                    equippedSet[entry.id] = true
                    usedPoints = usedPoints + entry.setPts
                    changed = true
                end
            end
        end

        if isFirstSeed or forceReset then
            player:setCharVar('OX_BLU_MAGUS_SET_INIT', 1)
        end

        if changed or forceReset then
            if player.syncBlueMagicSpells then
                player:syncBlueMagicSpells()
            end
            saveSoulSpells(player, MAGUS_KEY)
        end
    end

    if player.setLocalVar then
        player:setLocalVar('OX_MAG_SYNCING_SPELLS', 0)
    end
end

local function restoreSoulSpells(player, soulKey)
    local tag = SOUL_TAG[soulKey]
    if player == nil or tag == nil then
        return
    end

    if player:getCharVar(string.format('OX_BLU_SET_%s_SAVED', tag)) ~= 1 then
        if soulKey == MAGUS_KEY then
            syncMagusSpells(player, { forceReset = false })
        end
        return
    end

    if not player.setBlueMagicSpell then
        return
    end
    if player.getLocalVar and player:getLocalVar('OX_MAG_SYNCING_SPELLS') == 1 then
        return
    end
    if player.setLocalVar then
        player:setLocalVar('OX_MAG_SYNCING_SPELLS', 1)
    end

    if soulKey == MAGUS_KEY then
        learnMagusBaselineSpells(player)
    end

    local lvl       = player:getMainLvl() or 1
    local maxSlots  = getBluMaxSlots(lvl)
    local maxPoints = getBluMaxPoints(player, lvl)
    local usedPts   = 0

    for i = 0, 19 do
        player:setBlueMagicSpell(i, 0, false)
    end

    for chunk = 0, 6 do
        local packed = player:getCharVar(string.format('OX_BLU_SET_%s_%d', tag, chunk + 1)) or 0
        local b0 = packed % 256
        local b1 = math.floor(packed / 256) % 256
        local b2 = math.floor(packed / 65536) % 256
        local bytes = { b0, b1, b2 }
        for k = 1, 3 do
            local slotIdx = chunk * 3 + (k - 1)
            if slotIdx < maxSlots and bytes[k] > 0 then
                local sid = bytes[k] + 0x200
                if player:hasSpell(sid) then
                    local entry = MAGUS_SPELL_BY_ID[sid]
                    local ptsOk = (entry == nil) or ((usedPts + entry.setPts) <= maxPoints)
                    local lvlOk = (entry == nil) or (lvl >= entry.reqLvl)
                    if ptsOk and lvlOk then
                        player:setBlueMagicSpell(slotIdx, sid, false)
                        if entry then
                            usedPts = usedPts + entry.setPts
                        end
                    end
                end
            end
        end
    end

    if player.syncBlueMagicSpells then
        player:syncBlueMagicSpells()
    end

    if player.setLocalVar then
        player:setLocalVar('OX_MAG_SYNCING_SPELLS', 0)
    end
end

xi.soulspire.bluHealerSpecs.syncMagusSpells   = syncMagusSpells
xi.soulspire.bluHealerSpecs.saveSoulSpells    = saveSoulSpells
xi.soulspire.bluHealerSpecs.restoreSoulSpells = restoreSoulSpells
xi.soulspire.bluHealerSpecs.resetMagusSpells  = function(player)
    syncMagusSpells(player, { forceReset = true })
end

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
            H.applyCustomTimedEffect(attacker, EFFECT_AZURE_CATALYST, cur + 1, 20, attacker, 0, xi.soulspire.getStatusIcon(EFFECT_AZURE_CATALYST), 1)
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

    player:addListener('MAGIC_START', 'OX_MAG_MAGIC_START', function(caster, _target, spell, _action)
        if not isMagus(caster) or spell == nil then
            return
        end
        local spellId = spell.getID and spell:getID() or 0
        local entry = MAGUS_SPELL_BY_ID[spellId]
        if entry ~= nil and spell.setMPCost then
            local lvl = caster:getMainLvl() or 1
            if lvl < entry.reqLvl then
                local scaled = getScaledMagusMp(lvl, entry)
                if (spell.getMPCost and spell:getMPCost() or entry.baseMp) > scaled then
                    spell:setMPCost(scaled)
                end
            end
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
    player:removeListener('OX_MAG_MAGIC_START')
    player:removeListener('OX_MAG_MAGIC')
    local prev = player:getLocalVar('OX_MAG_SIRD_MOD')
    if prev ~= 0 then
        player:delMod(xi.mod.SPELLINTERRUPT, prev)
        player:setLocalVar('OX_MAG_SIRD_MOD', 0)
    end
end

-----------------------------------
-- Magus Baseline Spell Override & Level-Scaled MP
-----------------------------------
m:addOverride('xi.spells.canUseSpellOverride', function(player, spell)
    if
        player ~= nil and
        spell ~= nil and
        isMagus(player) and
        (player:getMainLvl() or 1) >= 10
    then
        local spellId = spell:getID()
        local entry   = MAGUS_SPELL_BY_ID[spellId]
        if entry ~= nil and player:hasSpell(spellId) then
            local lvl = player:getMainLvl() or 1
            if lvl < entry.reqLvl and spell.setMPCost then
                local scaled = getScaledMagusMp(lvl, entry)
                if (spell.getMPCost and spell:getMPCost() or entry.baseMp) > scaled then
                    spell:setMPCost(scaled)
                end
            end
            return true
        end
    end

    return super(player, spell)
end)

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
        H.applyCustomTimedEffect(member, EFFECT_OSMOTIC_CONDUIT, 10, 12, player, 0, xi.soulspire.getStatusIcon(EFFECT_OSMOTIC_CONDUIT), 1)
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
            syncMagusSpells(player, { isLevelUp = false })
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
