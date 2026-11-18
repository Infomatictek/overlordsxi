-----------------------------------
-- OverlordsXI Puppetmaster Crystal Spec: Animist (ANM | Tier-4 Combat Healer)
-- Unlocks @ Lv. 10 (!spec set animist)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
require('modules/custom/lua/pup_specs')
local H = require('modules/custom/lua/overlords_healer_helpers')
require('scripts/globals/job_utils/puppetmaster')
require('scripts/globals/pets/automaton')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_pup_healer_specs')

local spec = xi.overlords.spec
local ANIMIST_KEY = 'animist'

-- Custom Trait ID (174; Clockwork Medic)
local TRAIT_CLOCKWORK_MEDIC = 174

-- Native PUP Ability IDs
local ABIL_ACTIVATE         = 136
local ABIL_REPAIR           = 137
local ABIL_DEPLOY           = 138
local ABIL_RETRIEVE         = 140
local ABIL_EARTH_MANEUVER   = 144
local ABIL_WATER_MANEUVER   = 146
local ABIL_LIGHT_MANEUVER   = 147
local ABIL_VENTRILOQUY      = 180
local ABIL_COOLDOWN         = 309
local ABIL_DEUS_EX_AUTOMATA = 310

-- Custom Ability IDs (466-467; recastIds 166-167)
local ABIL_AETHER_OVERHAUL = 466
local ABIL_CLOCKWORK_AEGIS = 467

-- Custom Status Effect ID (871; registered in patch 0028)
local EFFECT_CLOCKWORK_AEGIS = 871

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.AETHER_OVERHAUL = ABIL_AETHER_OVERHAUL
xi.jobAbility.CLOCKWORK_AEGIS = ABIL_CLOCKWORK_AEGIS

xi.effect = xi.effect or {}
xi.effect.CLOCKWORK_AEGIS = EFFECT_CLOCKWORK_AEGIS

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.aether_overhaul = xi.actions.abilities.aether_overhaul or {}
xi.actions.abilities.clockwork_aegis = xi.actions.abilities.clockwork_aegis or {}

xi.effects = xi.effects or {}
xi.effects.clockwork_aegis = xi.effects.clockwork_aegis or {}

local lastWsCastAtByChar = {}

local function isAnimist(entity)
    return H.isSpecActive(entity, xi.job.PUP, ANIMIST_KEY)
end

local function isBlockedFrame(frame)
    return frame == xi.automaton.frame.VALOREDGE or frame == xi.automaton.frame.SHARPSHOT
end

local function isBlockedPart(frame, head)
    return isBlockedFrame(frame) or
        head == xi.automaton.head.VALOREDGE or
        head == xi.automaton.head.SHARPSHOT or
        head == xi.automaton.head.SPIRITREAVER
end

local function applyAnimistBacklineMode(pet)
    if pet == nil or not pet.isAutomaton or not pet:isAutomaton() then
        return
    end
    if pet.setMobMod then
        pet:setMobMod(xi.mobMod.STANDBACK_RANGE, 12)
    end
    if pet.getBehavior and pet.setBehavior and xi.behavior and xi.behavior.STANDBACK then
        pet:setBehavior(bit.bor(pet:getBehavior(), xi.behavior.STANDBACK))
    end
    if pet.setAutoAttackEnabled then
        pet:setAutoAttackEnabled(false)
    end
end

local function getAetherCells(player)
    if player == nil or not player.getLocalVar then
        return 0
    end
    if player:hasStatusEffect(xi.effect.OVERDRIVE) then
        return 3
    end
    local exp = player:getLocalVar('OX_ANM_CELL_EXP') or 0
    if exp > 0 and os.time() > exp then
        player:setLocalVar('OX_ANM_CELLS', 0)
        player:setLocalVar('OX_ANM_CELL_EXP', 0)
        return 0
    end
    return math.min(3, math.max(0, player:getLocalVar('OX_ANM_CELLS') or 0))
end

local function addAetherCell(player, amount)
    if player == nil or not player.setLocalVar then
        return 0
    end
    local cur  = getAetherCells(player)
    local next = math.min(3, cur + (amount or 1))
    player:setLocalVar('OX_ANM_CELLS', next)
    player:setLocalVar('OX_ANM_CELL_EXP', os.time() + 30)
    return next
end

local function consumeAllAetherCells(player)
    local count = getAetherCells(player)
    if player ~= nil and player.setLocalVar and not player:hasStatusEffect(xi.effect.OVERDRIVE) then
        player:setLocalVar('OX_ANM_CELLS', 0)
        player:setLocalVar('OX_ANM_CELL_EXP', 0)
    end
    return count
end

local function getPartyMembersAround(anchor, range, includePets)
    local out = {}
    if anchor == nil then
        return out
    end
    H.forEachPartyMemberInRange(anchor, range or 15, includePets == true, function(unit)
        if unit ~= nil and unit.isAlive and unit:isAlive() then
            table.insert(out, unit)
        end
    end)
    return out
end

local function getLowestHpAlly(anchor, range)
    local members = getPartyMembersAround(anchor, range or 15, false)
    table.sort(members, function(a, b)
        local pa = (a:getHP() or 0) / math.max(1, a:getMaxHP() or 1)
        local pb = (b:getHP() or 0) / math.max(1, b:getMaxHP() or 1)
        return pa < pb
    end)
    return members[1]
end

local function healWithPotency(caster, target, baseAmount)
    if caster == nil or target == nil or not target.isAlive or not target:isAlive() then
        return 0, 0
    end
    local pot      = math.max(0, caster.getMod and caster:getMod(xi.mod.CURE_POTENCY) or 0)
    local total    = math.max(1, math.floor(baseAmount * (1 + pot / 100)))
    local missing  = math.max(0, (target:getMaxHP() or 0) - (target:getHP() or 0))
    local healed   = math.min(total, missing)
    local overheal = math.max(0, total - healed)
    if healed > 0 then
        H.healEntity(caster, target, healed)
    end
    return healed, overheal
end

local function applyWaterRegenMist(master, anchor, range)
    if master == nil or anchor == nil then
        return
    end
    local flat = H.scaleTier(master:getMainLvl(), 12, 16, 20, 24)
    for _, member in ipairs(getPartyMembersAround(anchor, range or 12, false)) do
        local pwr = flat + math.max(1, math.floor((member:getMaxHP() or 0) * 0.015))
        H.applyCustomTimedEffect(member, xi.effect.REGEN, pwr, 12, master, 0, xi.effect.REGEN, 3)
    end
end

local function imbueAutomatonWhiteMagic(pet, lvl)
    if pet == nil or not pet.addSpell then
        return
    end
    local l = lvl or 1
    local spells =
    {
        { id = 1,  minLvl = 10 }, -- Cure
        { id = 2,  minLvl = 14 }, -- Cure II
        { id = 3,  minLvl = 30 }, -- Cure III
        { id = 4,  minLvl = 48 }, -- Cure IV
        { id = 5,  minLvl = 65 }, -- Cure V
        { id = 14, minLvl = 10 }, -- Poisona
        { id = 15, minLvl = 10 }, -- Paralyna
        { id = 16, minLvl = 10 }, -- Blindna
        { id = 17, minLvl = 10 }, -- Silena
        { id = 18, minLvl = 10 }, -- Stona
        { id = 19, minLvl = 10 }, -- Viruna
        { id = 20, minLvl = 10 }, -- Cursna
        { id = 143, minLvl = 20 }, -- Erase
    }
    for _, sp in ipairs(spells) do
        if l >= sp.minLvl and (not pet.hasSpell or not pet:hasSpell(sp.id)) then
            pet:addSpell(sp.id)
        end
    end
end

local function syncAutomatonHealerMods(player)
    if not isAnimist(player) or not player.getPet then
        return
    end
    local pet = player:getPet()
    if pet == nil or not pet.isAutomaton or not pet:isAutomaton() then
        return
    end

    if spec.syncPetRoleMods then
        spec.syncPetRoleMods(player, pet)
    end
    if xi.overlords.pupSpecs and xi.overlords.pupSpecs.syncSpecPetDamageMods then
        xi.overlords.pupSpecs.syncSpecPetDamageMods(player, pet)
    end

    applyAnimistBacklineMode(pet)

    if pet.addListener and pet:getLocalVar('OX_ANM_AI_LISTENER') ~= 1 then
        pet:setLocalVar('OX_ANM_AI_LISTENER', 1)
        pet:removeListener('OX_ANM_AUTO_TICK')
        pet:addListener('AUTOMATON_AI_TICK', 'OX_ANM_AUTO_TICK', function(mobArg, targetArg)
            if mobArg == nil or not mobArg:isAlive() then
                return
            end
            local master = mobArg:getMaster()
            if not isAnimist(master) then
                return
            end
            if targetArg ~= nil and mobArg:checkDistance(targetArg) <= 15 then
                applyAnimistBacklineMode(mobArg)
            end
        end)
    end

    local lvl = player:getMainLvl() or 1
    imbueAutomatonWhiteMagic(pet, lvl)

    if pet:getLocalVar('OX_ANM_SYNCED') == 1 then
        return
    end
    pet:setLocalVar('OX_ANM_SYNCED', 1)

    -- Frame guardrail: neutralize Valoredge / Sharpshot offensive frame biases if socketed
    local frame = player.getAutomatonFrame and player:getAutomatonFrame() or nil
    if isBlockedFrame(frame) then
        pet:addMod(xi.mod.ATTP, -25)
        pet:addMod(xi.mod.RATTP, -25)
        if player.printToPlayer then
            player:printToPlayer('Animist Medical Frame Guardrail: Valoredge/Sharpshot offensive bonuses suppressed; Harlequin, Stormwaker, or Soulsoother recommended.', xi.msg.channel.SYSTEM_3)
        end
    end

    local hpMpPct = H.scaleTier(lvl, 40, 50, 60, 75)
    local fc      = H.scaleTier(lvl, 40, 50, 60, 70)
    local ref     = H.scaleTier(lvl, 6, 9, 12, 16)

    pet:addMod(xi.mod.HPP, hpMpPct)
    pet:addMod(xi.mod.MPP, hpMpPct)
    pet:addMod(xi.mod.DMG, -3500)
    pet:addMod(xi.mod.FASTCAST, fc)
    pet:addMod(xi.mod.REFRESH, ref)
    pet:addMod(xi.mod.ENMITY, -60)
    if xi.mod.DMGBREATH then
        pet:addMod(xi.mod.DMGBREATH, -10000)
    end
    if xi.mod.UDMBREATH then
        pet:addMod(xi.mod.UDMBREATH, -10000)
    end
    if xi.mod.DMGMAGIC then
        pet:addMod(xi.mod.DMGMAGIC, -10000)
    end
    if xi.mod.UDMMAGIC then
        pet:addMod(xi.mod.UDMMAGIC, -10000)
    end
    pet:updateHealth()
    pet:setHP(pet:getMaxHP())
    pet:setMP(pet:getMaxMP())
end

-----------------------------------
-- Status Effect Modifiers
-----------------------------------
m:addOverride('xi.effects.clockwork_aegis.onEffectGain', function(_target, _effect)
    -- Party -DT and MEVA are routed through EFF_OX_SUP_WARD
end)

-----------------------------------
-- Listeners (Maneuvers, H2H Synchronized Overclock, Pet White Magic & Water Mist)
-----------------------------------
local function attachAnimistListeners(player)
    if player == nil or player:getLocalVar('OX_ANM_LISTENERS') == 1 then
        return
    end
    player:setLocalVar('OX_ANM_LISTENERS', 1)

    player:addListener('TICK', 'OX_ANM_TICK', function(actor)
        syncAutomatonHealerMods(actor)
        if not isAnimist(actor) then
            return
        end
        local pet = actor.getPet and actor:getPet() or nil
        if pet ~= nil and pet:isAlive() and actor:countEffect(xi.effect.WATER_MANEUVER) >= 1 then
            local now = os.time()
            if now >= (actor:getLocalVar('OX_ANM_MIST_TICK') or 0) then
                actor:setLocalVar('OX_ANM_MIST_TICK', now + 3)
                applyWaterRegenMist(actor, pet, 12)
            end
        end
    end)

    player:addListener('ABILITY_USE', 'OX_ANM_ABIL', function(caster, _target, ability)
        if not isAnimist(caster) or ability == nil then
            return
        end
        local abilId = ability:getID()
        local pet    = caster.getPet and caster:getPet() or nil
        if abilId == ABIL_LIGHT_MANEUVER then
            ability:setRecast(10)
            local ally = getLowestHpAlly(caster, 15)
            if ally ~= nil then
                local pct      = H.scaleTier(caster:getMainLvl(), 16, 19, 22, 25)
                local baseHeal = math.max(1, math.floor((caster:getMaxHP() or 0) * pct / 100))
                healWithPotency(caster, ally, baseHeal)
            end
        elseif abilId == ABIL_WATER_MANEUVER then
            ability:setRecast(10)
            if pet ~= nil and pet:isAlive() then
                H.restoreMpPct(pet, 12)
                applyWaterRegenMist(caster, pet, 12)
            end
            for _, ally in ipairs(getPartyMembersAround(caster, 15, false)) do
                if H.cleanseDebuffs(ally, 1) > 0 then
                    break
                end
            end
        elseif abilId == ABIL_EARTH_MANEUVER then
            ability:setRecast(10)
            local ally = getLowestHpAlly(caster, 15)
            if ally ~= nil then
                local skin = math.max(1, math.floor((ally:getMaxHP() or 0) * 0.12))
                H.applyStoneskinBarrier(ally, skin, skin * 2, 12, caster)
            end
            if pet ~= nil and pet:isAlive() then
                local petSkin = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.12))
                H.applyStoneskinBarrier(pet, petSkin, petSkin * 2, 12, caster)
            end
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'OX_ANM_WS', function(caster, _target, ws)
        if not isAnimist(caster) then
            return
        end
        if not H.isWeaponSkillInSet(ws, nil, { [xi.skill.HAND_TO_HAND] = true }) then
            return
        end

        local charId    = caster.getID and caster:getID() or 0
        local now       = os.clock()
        local isPrimary = (charId == 0) or ((now - (lastWsCastAtByChar[charId] or 0)) > 0.05)
        if not isPrimary then
            return
        end
        if charId > 0 then
            lastWsCastAtByChar[charId] = now
        end

        addAetherCell(caster, 1)

        local pet    = caster.getPet and caster:getPet() or nil
        local anchor = (pet ~= nil and pet:isAlive()) and pet or caster
        if pet ~= nil and pet:isAlive() then
            H.restoreMpPct(pet, 10)
            if pet.reduceRecasts then
                pet:reduceRecasts(4)
            end
        end

        local overdrive = caster:hasStatusEffect(xi.effect.OVERDRIVE)
        local lightC    = caster:countEffect(xi.effect.LIGHT_MANEUVER)
        local waterC    = caster:countEffect(xi.effect.WATER_MANEUVER)
        local earthC    = caster:countEffect(xi.effect.EARTH_MANEUVER)

        if not overdrive and lightC == 0 and waterC == 0 and earthC == 0 then
            local ally = getLowestHpAlly(anchor, 15)
            if ally ~= nil then
                local baseHeal = math.max(1, math.floor((caster:getMaxHP() or 0) * 0.16))
                healWithPotency(caster, ally, baseHeal)
            end
            return
        end

        local doLight = overdrive or (lightC >= waterC and lightC >= earthC and lightC > 0)
        local doWater = overdrive or (not doLight and waterC >= earthC and waterC > 0)
        local doEarth = overdrive or (not doLight and not doWater and earthC > 0)

        if doLight then
            local pct      = H.scaleTier(caster:getMainLvl(), 14, 16, 18, 20)
            local baseHeal = math.max(1, math.floor((caster:getMaxHP() or 0) * pct / 100))
            for _, member in ipairs(getPartyMembersAround(anchor, 15, false)) do
                healWithPotency(caster, member, baseHeal)
            end
        end
        if doWater then
            for _, member in ipairs(getPartyMembersAround(anchor, 15, false)) do
                H.cleanseDebuffs(member, 1)
            end
            applyWaterRegenMist(caster, anchor, 12)
        end
        if doEarth then
            for _, member in ipairs(getPartyMembersAround(anchor, 15, false)) do
                local skin = math.max(1, math.floor((member:getMaxHP() or 0) * 0.10))
                H.applyStoneskinBarrier(member, skin, skin * 2, 10, caster)
            end
        end
    end)

    player:addListener('PET_MAGIC_USE', 'OX_ANM_PET_MAGIC', function(pet, target, spell, action)
        local master = pet and pet.getMaster and pet:getMaster()
        if not isAnimist(master) or spell == nil then
            return
        end
        if spell:getSpellFamily() == xi.magic.spellFamily.CURE then
            local healed       = (action and action:getParam()) or math.floor(master:getMaxHP() * 0.16)
            local lightStacks  = math.min(3, master:countEffect(xi.effect.LIGHT_MANEUVER))
            local earthStacks  = master:countEffect(xi.effect.EARTH_MANEUVER)
            local head         = pet.getAutomatonHead and pet:getAutomatonHead() or nil

            -- Soulsoother: convert overheal into up to 15% Max HP Stoneskin
            if head == xi.automaton.head.SOULSOOTHER and target ~= nil and target.isAlive and target:isAlive() then
                local spellId = spell.getID and spell:getID() or 0
                local baseByCureId =
                {
                    [1] = 65,
                    [2] = 145,
                    [3] = 300,
                    [4] = 550,
                    [5] = 850,
                    [6] = 1200,
                }
                local expectedBase = baseByCureId[spellId]
                if expectedBase ~= nil then
                    local pot      = math.max(0, (pet.getMod and pet:getMod(xi.mod.CURE_POTENCY) or 0))
                    local expected = math.floor(expectedBase * (1 + pot / 100))
                    local overheal = math.max(0, expected - healed)
                    if overheal > 0 then
                        local maxSkin = math.max(1, math.floor((target:getMaxHP() or 0) * 0.15))
                        local skinAmt = math.min(overheal, maxSkin)
                        H.applyStoneskinBarrier(target, skinAmt, maxSkin, 20, master)
                    end
                end
            end

            if lightStacks > 0 and healed > 0 then
                local splash = math.max(1, math.floor(healed * 0.15 * lightStacks))
                for _, member in ipairs(getPartyMembersAround(pet, 12, false)) do
                    if member ~= target then
                        H.healEntity(master, member, splash)
                    end
                end
            end

            if earthStacks > 0 and target ~= nil and target.isAlive and target:isAlive() then
                local cap = math.max(1, math.floor((target:getMaxHP() or 0) * 0.18))
                H.applyStoneskinBarrier(target, math.min(math.max(1, math.floor(healed * 0.35)), cap), cap, 12, master)
            end
        else
            -- Stormwaker: splash Haste, Phalanx, Protect, and Shell to party members within 12y
            local head = pet.getAutomatonHead and pet:getAutomatonHead() or nil
            if head == xi.automaton.head.STORMWAKER then
                local spellId = spell.getID and spell:getID() or 0
                local splashEffect = nil
                if spellId == 57 or spellId == 511 then -- Haste / Haste II
                    splashEffect = { eff = xi.effect.HASTE, power = (spellId == 511) and 3000 or 1500, dur = 180, tier = 1 }
                elseif spellId == 106 then -- Phalanx
                    splashEffect = { eff = xi.effect.PHALANX, power = 35, dur = 180, tier = 1 }
                elseif spellId >= 43 and spellId <= 47 then -- Protect I..V
                    local powers = { [43] = 15, [44] = 40, [45] = 75, [46] = 120, [47] = 175 }
                    splashEffect = { eff = xi.effect.PROTECT, power = powers[spellId] or 75, dur = 1800, tier = 1 }
                elseif spellId >= 48 and spellId <= 52 then -- Shell I..V
                    local powers = { [48] = 1055, [49] = 1641, [50] = 2188, [51] = 2617, [52] = 2930 }
                    splashEffect = { eff = xi.effect.SHELL, power = powers[spellId] or 2188, dur = 1800, tier = 1 }
                end

                if splashEffect ~= nil then
                    for _, member in ipairs(getPartyMembersAround(pet, 12, false)) do
                        if member ~= target then
                            H.applyCustomTimedEffect(member, splashEffect.eff, splashEffect.power, splashEffect.dur, pet, 0, splashEffect.eff, splashEffect.tier)
                        end
                    end
                end
            end
        end
    end)
end

local function detachAnimistListeners(player)
    if player == nil then
        return
    end
    player:setLocalVar('OX_ANM_LISTENERS', 0)
    player:removeListener('OX_ANM_TICK')
    player:removeListener('OX_ANM_ABIL')
    player:removeListener('OX_ANM_WS')
    player:removeListener('OX_ANM_PET_MAGIC')
end

-----------------------------------
-- Vanilla JA & Overdrive Enhancements
-----------------------------------
for _, summonName in ipairs({ 'activate', 'deus_ex_automata' }) do
    m:addOverride('xi.actions.abilities.' .. summonName .. '.onAbilityCheck', function(player, target, ability)
        if isAnimist(player) then
            if player.getPet and player:getPet() ~= nil then
                return xi.msg.basic.ALREADY_HAS_A_PET, 0
            end
            local frame = player.getAutomatonFrame and player:getAutomatonFrame() or nil
            local head  = player.getAutomatonHead and player:getAutomatonHead() or nil
            if isBlockedPart(frame, head) then
                return xi.msg.basic.UNABLE_TO_USE_JA, 0
            end
            return 0, 0
        end
        return super(player, target, ability)
    end)

    m:addOverride('xi.actions.abilities.' .. summonName .. '.onUseAbility', function(player, target, ability)
        if isAnimist(player) and ability ~= nil and ability.setRecast then
            ability:setRecast(15)
        end
        local res = super(player, target, ability)
        if isAnimist(player) then
            syncAutomatonHealerMods(player)
        end
        return res
    end)
end

m:addOverride('xi.job_utils.puppetmaster.onAbilityUseDeploy', function(player, target, ability)
    local res = super(player, target, ability)
    if isAnimist(player) and player.getPet then
        applyAnimistBacklineMode(player:getPet())
    end
    return res
end)

-- Suppress all Automaton TP weaponskills & ranged attacks on Animist
local ANIMIST_BLOCKED_AUTO_ABILITIES =
{
    'ranged_attack',
    'string_clipper',
    'chimera_ripper',
    'cannibal_blade',
    'bone_crusher',
    'string_shredder',
    'slapstick',
    'knockout',
    'magic_mortar',
    'arcuballista',
    'daze',
    'armor_piercer',
    'armor_shatterer',
}

for _, autoAbil in ipairs(ANIMIST_BLOCKED_AUTO_ABILITIES) do
    m:addOverride(string.format('xi.actions.abilities.pets.automaton.%s.onAutomatonAbilityCheck', autoAbil), function(target, automaton, skill)
        local master = automaton and automaton.getMaster and automaton:getMaster() or nil
        if isAnimist(master) then
            return -1
        end
        return super(target, automaton, skill)
    end)
end

-- Block offensive Elemental nukes & offensive DoTs on Animist's Automaton
local ANIMIST_BLOCKED_BLACK_SPELLS =
{
    'fire', 'fire_ii', 'fire_iii', 'fire_iv', 'fire_v',
    'blizzard', 'blizzard_ii', 'blizzard_iii', 'blizzard_iv', 'blizzard_v',
    'aero', 'aero_ii', 'aero_iii', 'aero_iv', 'aero_v',
    'stone', 'stone_ii', 'stone_iii', 'stone_iv', 'stone_v',
    'thunder', 'thunder_ii', 'thunder_iii', 'thunder_iv', 'thunder_v',
    'water', 'water_ii', 'water_iii', 'water_iv', 'water_v',
    'bio', 'bio_ii', 'poison', 'poison_ii',
}

for _, spellName in ipairs(ANIMIST_BLOCKED_BLACK_SPELLS) do
    m:addOverride(string.format('xi.actions.spells.black.%s.onMagicCastingCheck', spellName), function(caster, target, spell)
        if caster ~= nil and caster.isAutomaton and caster:isAutomaton() and isAnimist(caster:getMaster()) then
            return xi.msg.basic.CANNOT_CAST_SPELL
        end
        return super(caster, target, spell)
    end)
end

for _, spellName in ipairs({ 'dia', 'dia_ii' }) do
    m:addOverride(string.format('xi.actions.spells.white.%s.onMagicCastingCheck', spellName), function(caster, target, spell)
        if caster ~= nil and caster.isAutomaton and caster:isAutomaton() and isAnimist(caster:getMaster()) then
            return xi.msg.basic.CANNOT_CAST_SPELL
        end
        return super(caster, target, spell)
    end)
end

m:addOverride('xi.actions.abilities.repair.onAbilityCheck', function(player, target, ability)
    if isAnimist(player) then
        local pet = player:getPet()
        if pet == nil or not pet:isAlive() then
            return xi.msg.basic.NO_EFFECT_ON_PET, 0
        end
        return 0, 0
    end
    return super(player, target, ability)
end)

m:addOverride('xi.actions.abilities.repair.onUseAbility', function(player, target, ability)
    if isAnimist(player) then
        if ability ~= nil and ability.setRecast then
            ability:setRecast(30)
        end
        local pet    = player:getPet()
        local healed = 0
        if pet ~= nil and pet:isAlive() then
            healed = H.healEntity(player, pet, math.floor((pet:getMaxHP() or 0) * 0.50))
            H.restoreMpPct(pet, 50)
            H.cleanseDebuffs(pet, 5)
            for _, member in ipairs(getPartyMembersAround(pet, 15, false)) do
                local pwr = 25 + math.max(1, math.floor((member:getMaxHP() or 0) * 0.035))
                H.applyCustomTimedEffect(member, xi.effect.REGEN, pwr, 12, player, 0, xi.effect.REGEN, 3)
            end
        end
        ability:setMsg(xi.msg.basic.RECOVERS_HP)
        return healed
    end
    return super(player, target, ability)
end)

for _, hateName in ipairs({ 'ventriloquy', 'cooldown' }) do
    m:addOverride('xi.actions.abilities.' .. hateName .. '.onAbilityCheck', function(player, target, ability)
        if isAnimist(player) then
            local pet = player:getPet()
            if pet == nil or not pet:isAlive() then
                return xi.msg.basic.NO_EFFECT_ON_PET, 0
            end
            return 0, 0
        end
        return super(player, target, ability)
    end)

    m:addOverride('xi.actions.abilities.' .. hateName .. '.onUseAbility', function(player, target, ability)
        if isAnimist(player) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(30)
            end
            addAetherCell(player, 1)
            local pet = player:getPet()
            for _, mob in ipairs(xi.overlords.getNearbyMobs(player, 20, target)) do
                if mob.lowerEnmity then
                    mob:lowerEnmity(player, 40)
                    if pet ~= nil then
                        mob:lowerEnmity(pet, 40)
                    end
                end
            end
            return 0
        end
        return super(player, target, ability)
    end)
end

m:addOverride('xi.effects.overdrive.onEffectGain', function(target, effect)
    super(target, effect)
    if target ~= nil and target.getObjType and target:getObjType() == xi.objType.PET then
        local master = target:getMaster()
        if isAnimist(master) then
            effect:addMod(xi.mod.MP_COST_REDUCTION, 100)
            effect:addMod(xi.mod.FASTCAST, 100)
            if xi.mod.RECAST_REDUCTION then
                effect:addMod(xi.mod.RECAST_REDUCTION, 90)
            end
        end
    end
end)

-----------------------------------
-- Custom Job Abilities (466-467)
-----------------------------------
m:addOverride('xi.actions.abilities.aether_overhaul.onAbilityCheck', function(player, _target, _ability)
    if not isAnimist(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.aether_overhaul.onUseAbility', function(player, _target, ability)
    local cells    = consumeAllAetherCells(player)
    local pct      = 16 + (cells * 5)
    local cleanseN = (cells >= 3) and 3 or 2
    local baseHeal = math.max(1, math.floor((player:getMaxHP() or 0) * pct / 100))
    local total    = 0

    for _, unit in ipairs(getPartyMembersAround(player, 15, true)) do
        local healed = healWithPotency(player, unit, baseHeal)
        total = total + healed
        H.cleanseDebuffs(unit, cleanseN)
    end

    local pet = player.getPet and player:getPet() or nil
    if pet ~= nil and pet.resetRecasts then
        pet:resetRecasts()
    end

    ability:setMsg(xi.msg.basic.JA_RECOVERS_HP)
    return total
end)

m:addOverride('xi.actions.abilities.clockwork_aegis.onAbilityCheck', function(player, _target, _ability)
    if not isAnimist(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.clockwork_aegis.onUseAbility', function(player, _target, ability)
    for _, member in ipairs(getPartyMembersAround(player, 15, false)) do
        local skin = math.max(1, math.floor((member:getMaxHP() or 0) * 0.18))
        H.applyStoneskinBarrier(member, skin, skin * 2, 15, player)
        H.applyCustomTimedEffect(member, EFFECT_CLOCKWORK_AEGIS, 15, 15, player, 0, xi.effect.REPRISAL, 1)
        if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
            xi.overlords.slots.applyPartyWard(player, member, -1200, 30, 15, xi.effect.REPRISAL)
        end
    end
    ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
    return EFFECT_CLOCKWORK_AEGIS
end)

-----------------------------------
-- Crystal Definition (PUP = 18)
-----------------------------------
if xi.job and xi.job.PUP then
    spec.registerCrystal(xi.job.PUP,
    {
        id          = 2,
        key         = ANIMIST_KEY,
        name        = 'Animist',
        abr         = 'ANM',
        role        = 'Healer',
        icon        = 'animist',
        reqLevel    = 10,
        extraTraits = { TRAIT_CLOCKWORK_MEDIC },
        extraAbilities = function(_player, lvl)
            if (lvl or 1) >= 10 then
                return
                {
                    ABIL_ACTIVATE,
                    ABIL_DEUS_EX_AUTOMATA,
                    ABIL_DEPLOY,
                    ABIL_RETRIEVE,
                    ABIL_REPAIR,
                    ABIL_VENTRILOQUY,
                    ABIL_COOLDOWN,
                    ABIL_EARTH_MANEUVER,
                    ABIL_WATER_MANEUVER,
                    ABIL_LIGHT_MANEUVER,
                    ABIL_AETHER_OVERHAUL,
                    ABIL_CLOCKWORK_AEGIS,
                }
            end
            return {}
        end,
        description = 'Pure martial Automaton Medic & Tactical Maneuver Healer (Lv10+, Hand-to-Hand): unlocks Activate, Repair, Ventriloquy, Cooldown, and Light/Water/Earth Maneuvers @ Lv10+ with built-in Automaton White Magic, 0% Overload, and H2H Synchronized Overclock.',
        highlights  =
        {
            'Passives (Lv10/30/50/70+): +14/18/22/28% Max HP, +10/16/22/28 MND/VIT/DEX, +18/26/34/42% Cure & Repair Potency, +15/20/25/30% Subtle Blow, +10/14/18/22% Guard, +15/25/35/50 H2H & Auto Melee/Magic, -25/35/45/60 Enmity, 100% Overload Immunity.',
            'Automaton Medic (Harlequin/Stormwaker/Soulsoother): +40/50/60/75% HP/MP, -35% DT, +40/50/60/70% Fast Cast, +6/9/12/16 MP/t Refresh, -60 Enmity, 100% AoE/Breath resist, and built-in Cure I-V, Erase & -na White Magic @ Lv10+.',
            'Maneuver Directives (10s shared CD): Light (16/19/22/25% single-target mend + 15/30/45% Cure splash), Water (+12% Auto MP, 1 Erase + 12y Hybrid Regen mist), Earth (12% Stoneskin + Cure overheal -> 18% Stoneskin).',
            'H2H Synchronized Overclock: H2H WSs restore +10% Auto MP, shave -4s Auto recasts, grant +1 Aether Cell (max 3), and fire Light/Water/Earth pulses; Repair (30s CD, 0 oil, 50% Auto HP/MP + 12s Hybrid Regen); Ventriloquy/Cooldown (30s CD, -40% Enmity + 1 Cell).',
            'Aether Overhaul (45s CD, spends 0..3 Cells for 16/21/26/31% party+pet heal, 2-3 cleanse & Auto reset) & Clockwork Aegis (75s CD, 15s: 18% Stoneskin + shared Ward -12% DMG / +30 MEVA).',
        },
        mods = function(_player, lvl)
            return
            {
                { xi.mod.HPP,              H.scaleTier(lvl, 14, 18, 22, 28) },
                { xi.mod.MND,              H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.VIT,              H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.DEX,              H.scaleTier(lvl, 10, 16, 22, 28) },
                { xi.mod.CURE_POTENCY,     H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.REPAIR_EFFECT,    H.scaleTier(lvl, 18, 26, 34, 42) },
                { xi.mod.SUBTLE_BLOW,      H.scaleTier(lvl, 15, 20, 25, 30) },
                { xi.mod.ADDITIVE_GUARD,   H.scaleTier(lvl, 10, 14, 18, 22) },
                { xi.mod.ENMITY,           -H.scaleTier(lvl, 25, 35, 45, 60) },
                { xi.mod.HTH,              H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.AUTO_MELEE_SKILL, H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.AUTO_MAGIC_SKILL, H.scaleTier(lvl, 15, 25, 35, 50) },
                { xi.mod.OVERLOAD_THRESH,  500 },
                { xi.mod.PREVENT_OVERLOAD, 1 },
            }
        end,
        onApply = function(player)
            attachAnimistListeners(player)
            syncAutomatonHealerMods(player)
        end,
        onRemove = function(player)
            if player ~= nil and player.delStatusEffectSilent then
                player:delStatusEffectSilent(EFFECT_CLOCKWORK_AEGIS)
            end
            if player ~= nil and player.setLocalVar then
                player:setLocalVar('OX_ANM_CELLS', 0)
                player:setLocalVar('OX_ANM_CELL_EXP', 0)
            end
            detachAnimistListeners(player)
        end,
    })
end

return m
