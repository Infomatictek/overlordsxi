-----------------------------------
-- OverlordsXI Ranger Crystal Specs
-- Registers the Huntsman (Melee Beast-Tank Warden) RNG soul crystal:
--   - Central identity: The Beast Warden — the Ranger fights alongside a beast
--     companion with a 1H Axe (and optional offhand Dagger via Soul Dual Wield),
--     while the pet serves as the actual main tank.
--   - 4 Beast Companions (100% single-target):
--       * Glacial Tusker (Guardian): Wild Raaz (Lv.10+) / Cehuetzi (Lv.75)
--       * Volcanic Saurian (Predator): Stalker Raptor (Lv.10+) / Gabbrath (Lv.75)
--   - Passive AoE Survival: Beastguard (25/28/32/35% AoE/conal reduction within 8y
--     when companion holds the attacker's attention).
--   - Emergency Evasion: Predator's Feint (489, 45s CD; 3s evasion + ST threat transfer).
--   - Warhorn Interception: Guardian's Call (490, 60s CD; pet intercepts 1 ST hit).
--   - Pet Death Recovery: Last Whistle (passive, 180s CD; 4s escape window + 50% HP
--     emergency resummon opportunity).
--   - Melee Sustain: Warden's Ration (1H Axe WSs heal pet 10/12/14/16% HP, +200 Pet TP,
--     and shave 3s off active Huntsman command recasts; 6s ICD).
--   - Warhorn Architecture: clean equipment registry (xi.overlords.huntsman.registerWarhorn)
--     ready for future custom warhorns without blocking Soul functionality.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('modules/custom/lua/overlords_shared_slots')
require('scripts/globals/pets')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_rng_specs')

local spec  = xi.overlords.spec
local slots = xi.overlords.slots

xi.overlords          = xi.overlords or {}
xi.overlords.huntsman = xi.overlords.huntsman or {}
local huntsman        = xi.overlords.huntsman

local HUNTSMAN_KEY = 'huntsman'

-- Custom Job Abilities (480-486, 489-490)
local ABIL_CALL_WILD_RAAZ      = 480
local ABIL_CALL_STALKER_RAPTOR = 481
local ABIL_RIMETUSK_GORE       = 482
local ABIL_SAURIAN_REND        = 483
local ABIL_PRIMEVAL_TAKEDOWN   = 484
local ABIL_CALL_CEHUETZI       = 485
local ABIL_CALL_GABBRATH       = 486
local ABIL_PREDATORS_FEINT     = 489
local ABIL_GUARDIANS_CALL      = 490

-- Safe uint8_t Recast IDs (245-250; vanilla GEO Lv.40-90 slots, unreachable as subjob at Lv.75)
local RECAST_SUMMON            = 245
local RECAST_RIMETUSK_GORE     = 246
local RECAST_SAURIAN_REND      = 247
local RECAST_PRIMEVAL_TAKEDOWN = 248
local RECAST_PREDATORS_FEINT   = 249
local RECAST_GUARDIANS_CALL    = 250

-- Custom Pet IDs (134-137) + pre-rebuild fallback jug pet IDs (90, 54, 91, 104)
local PET_WILD_RAAZ      = 134
local PET_STALKER_RAPTOR = 135
local PET_CEHUETZI       = 136
local PET_GABBRATH       = 137

local FALLBACK_PET_CONFIG =
{
    [PET_WILD_RAAZ]      = { fallbackId = 90,  key = 1, name = 'Wild Raaz',      modelId = 2600 },
    [PET_STALKER_RAPTOR] = { fallbackId = 54,  key = 2, name = 'Stalker Raptor', modelId = 316  },
    [PET_CEHUETZI]       = { fallbackId = 91,  key = 3, name = 'Cehuetzi',       modelId = 2601 },
    [PET_GABBRATH]       = { fallbackId = 104, key = 4, name = 'Gabbrath',       modelId = 317  },
}

-- Custom Trait IDs (181-183)
local TRAIT_WARDENS_RATION = 181
local TRAIT_PRIMEVAL_PACK  = 182
local TRAIT_APEX_BOND      = 183

-- 1H Axe Weaponskill IDs (64-77)
local AXE_WS_IDS =
{
    [64] = true, [65] = true, [66] = true, [67] = true, [68] = true,
    [69] = true, [70] = true, [71] = true, [72] = true, [73] = true,
    [74] = true, [75] = true, [76] = true, [77] = true,
}

-- Tuning constants (exported for tests/HUD)
huntsman.BEASTGUARD_RANGE          = 8.0
huntsman.GUARDIANS_CALL_RANGE      = 12.0
huntsman.GUARDIANS_CALL_WINDOW_SEC = 10
huntsman.FEINT_DURATION_SEC        = 3
huntsman.FEINT_COOLDOWN_SEC        = 45
huntsman.FEINT_DAGGER_CD_BONUS_SEC = 5
huntsman.LAST_WHISTLE_COOLDOWN_SEC = 180
huntsman.LAST_WHISTLE_ESCAPE_SEC   = 4
huntsman.LAST_WHISTLE_RESUMMON_SEC = 15
huntsman.LAST_WHISTLE_PET_HP_PCT   = 0.50
huntsman.WARDENS_RATION_ICD_SEC    = 6

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.CALL_WILD_RAAZ      = ABIL_CALL_WILD_RAAZ
xi.jobAbility.CALL_STALKER_RAPTOR = ABIL_CALL_STALKER_RAPTOR
xi.jobAbility.RIMETUSK_GORE       = ABIL_RIMETUSK_GORE
xi.jobAbility.SAURIAN_REND        = ABIL_SAURIAN_REND
xi.jobAbility.PRIMEVAL_TAKEDOWN   = ABIL_PRIMEVAL_TAKEDOWN
xi.jobAbility.CALL_CEHUETZI       = ABIL_CALL_CEHUETZI
xi.jobAbility.CALL_GABBRATH       = ABIL_CALL_GABBRATH
xi.jobAbility.PREDATORS_FEINT     = ABIL_PREDATORS_FEINT
xi.jobAbility.GUARDIANS_CALL      = ABIL_GUARDIANS_CALL

xi.petId = xi.petId or {}
xi.petId.WILD_RAAZ      = PET_WILD_RAAZ
xi.petId.STALKER_RAPTOR = PET_STALKER_RAPTOR
xi.petId.CEHUETZI       = PET_CEHUETZI
xi.petId.GABBRATH       = PET_GABBRATH

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
for _, abilName in ipairs({
    'call_wild_raaz', 'call_stalker_raptor', 'rimetusk_gore',
    'saurian_rend', 'primeval_takedown', 'call_cehuetzi', 'call_gabbrath',
    'predators_feint', 'guardians_call',
}) do
    xi.actions.abilities[abilName] = xi.actions.abilities[abilName] or {}
end

-----------------------------------
-- Warhorn Equipment Registration Point (Future Custom Warhorns)
-----------------------------------
-- Custom warhorn item IDs are NOT invented here. When custom warhorn assets/IDs
-- are added later, register them via xi.overlords.huntsman.registerWarhorn(itemId, cfg).
-- Supported config keys:
--   name                    (string)
--   tier                    (number)
--   guardiansCallRangeBonus (number, extra yalms)
--   feintEvaBonus           (number, extra EVA during Predator's Feint)
--   rationHealBonusPct      (number, e.g. 0.02 for +2% Max HP)
--   petEnmityBonusPct       (number, e.g. 0.10 for +10% command enmity)
huntsman.WARHORN_ITEMS = huntsman.WARHORN_ITEMS or {}

function huntsman.registerWarhorn(itemId, cfg)
    if type(itemId) ~= 'number' or itemId <= 0 or type(cfg) ~= 'table' then
        return false
    end
    huntsman.WARHORN_ITEMS[itemId] = cfg
    return true
end

function huntsman.getEquippedWarhorn(player)
    if player == nil or not player.getEquipID or not xi.slot then
        return nil
    end
    local rangedId = player:getEquipID(xi.slot.RANGED) or 0
    if rangedId > 0 and huntsman.WARHORN_ITEMS[rangedId] ~= nil then
        return huntsman.WARHORN_ITEMS[rangedId]
    end
    local ammoId = player:getEquipID(xi.slot.AMMO) or 0
    if ammoId > 0 and huntsman.WARHORN_ITEMS[ammoId] ~= nil then
        return huntsman.WARHORN_ITEMS[ammoId]
    end
    return nil
end

-----------------------------------
-- Internal State Tables (Per-Character / Per-Pet)
-----------------------------------
local stanceModsByChar        = {}
local lastRationByChar        = {}
local lastGateMsgByChar       = {}
local feintStateByChar        = {} -- { evaMod = n, expiresAt = t, lastUsedAt = t }
local guardiansCallByChar     = {} -- { armed = bool, expiresAt = t, petEntityId = id }
local interceptInProgress     = {} -- recursion guard by charId
local lastWhistleByChar       = {} -- { cdUntil = t, escapeActive = bool, escapeExpiresAt = t, escapeMods = {}, resummonUntil = t }
local activeAoEContextByChar  = {} -- transient AoE classification context during mobskill/spell resolution
local lastCureRawByTarget     = {} -- real pre-cap cure value captured from getCureFinal

local function nowSec()
    if xi.overlords and xi.overlords.nowSec then
        return xi.overlords.nowSec()
    end
    return os.time()
end

local function tell(player, message)
    if player ~= nil and player.printToPlayer then
        player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
    end
end

local function tellRateLimited(player, message, intervalSec)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local now    = nowSec()
    if (now - (lastGateMsgByChar[charId] or 0)) < (intervalSec or 4) then
        return
    end
    lastGateMsgByChar[charId] = now
    tell(player, message)
end

local function scaleTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 then
        return lv70
    elseif l >= 50 then
        return lv50
    elseif l >= 30 then
        return lv30
    end
    return lv10
end

local function isHuntsman(player)
    if player == nil or not player.isPC or not player:isPC() or player:getMainJob() ~= xi.job.RNG then
        return false
    end
    spec.ensureUpToDate(player)
    return spec.is(player, xi.job.RNG, HUNTSMAN_KEY)
end

-- Returns pet, logicalPetId (134..137) if active
local function getHuntsmanPet(player)
    if player == nil or not player.hasPet or not player:hasPet() then
        return nil, nil
    end
    local pet = player:getPet()
    if pet == nil then
        return nil, nil
    end
    local pid = pet.getPetID and pet:getPetID() or 0
    if pid >= PET_WILD_RAAZ and pid <= PET_GABBRATH then
        return pet, pid
    end
    local hKey = pet.getLocalVar and pet:getLocalVar('OX_HUNTSMAN_PET_KEY') or 0
    if hKey == 1 then
        return pet, PET_WILD_RAAZ
    elseif hKey == 2 then
        return pet, PET_STALKER_RAPTOR
    elseif hKey == 3 then
        return pet, PET_CEHUETZI
    elseif hKey == 4 then
        return pet, PET_GABBRATH
    end
    return nil, nil
end

local function isTuskerPet(player, petArg)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or (petArg ~= nil and pet ~= petArg) then
        return false, nil
    end
    if pet.isAlive and not pet:isAlive() then
        return false, nil
    end
    if pid == PET_WILD_RAAZ or pid == PET_CEHUETZI then
        return true, pid
    end
    return false, pid
end

local function isSaurianPet(player, petArg)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or (petArg ~= nil and pet ~= petArg) then
        return false, nil
    end
    if pet.isAlive and not pet:isAlive() then
        return false, nil
    end
    if pid == PET_STALKER_RAPTOR or pid == PET_GABBRATH then
        return true, pid
    end
    return false, pid
end

local function isAxeEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.AXE
end

local function isOffhandDaggerEquipped(player)
    if player == nil or not player.getWeaponSkillType or not xi.slot or not xi.skill then
        return false
    end
    local subItem = player.getEquippedItem and player:getEquippedItem(xi.slot.SUB) or nil
    if subItem ~= nil and subItem.getSkillType then
        return subItem:getSkillType() == xi.skill.DAGGER
    end
    local subId = player.getEquipID and player:getEquipID(xi.slot.SUB) or 0
    return subId > 0 and player:getWeaponSkillType(xi.slot.SUB) == xi.skill.DAGGER
end

local function isAxeWs(skill)
    if skill == nil then
        return false
    end
    if type(skill) == 'number' then
        return AXE_WS_IDS[skill] == true
    end
    if skill.getSkillType and xi.skill and skill:getSkillType() == xi.skill.AXE then
        return true
    end
    if skill.getID then
        return AXE_WS_IDS[skill:getID() or 0] == true
    end
    return false
end

local function scaleLevelGapDmg(attacker, defender, dmg)
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        return xi.customBossServer.scaleDamageByLevelGap(attacker, defender, dmg)
    end
    return dmg
end

local function scaleTankCommandDmg(player, rawDmg)
    -- Tank-role command scaling: respects Tank -60% damage dealt baseline (0.40x)
    -- so pet commands remain threat/utility tools rather than bypassing Tank scaling.
    local tierCfg = spec.getTierConfig and spec.getTierConfig(player) or nil
    local dealtMod = (tierCfg and tierCfg.physDmgDealt) or -60
    local factor = math.max(0.12, math.min(1.0, (100 + dealtMod) / 100))
    return math.max(10, math.floor((rawDmg or 0) * factor))
end

-----------------------------------
-- Weapon Whitelist Enforcement & Stance Mods (1H Axe + Optional Offhand Dagger)
-----------------------------------
local function enforceHuntsmanWeaponWhitelist(player)
    if not isHuntsman(player) or not xi.slot or not xi.skill then
        return false
    end

    local removed = false
    if player.getEquippedItem and player.unequipItem then
        local mainItem = player:getEquippedItem(xi.slot.MAIN)
        if mainItem ~= nil and mainItem.getSkillType and mainItem:getSkillType() ~= xi.skill.AXE then
            player:unequipItem(xi.slot.MAIN)
            removed = true
        end

        local subItem = player:getEquippedItem(xi.slot.SUB)
        if subItem ~= nil then
            local subSkill = subItem.getSkillType and subItem:getSkillType() or nil
            if subSkill ~= xi.skill.DAGGER then
                player:unequipItem(xi.slot.SUB)
                removed = true
            end
        end
    end

    if removed then
        tellRateLimited(player, 'Huntsman fights with a 1H Axe (and optional offhand Dagger). Incompatible melee equipment was unequipped.')
    end
    return removed
end

local function clearStanceMasterMods(player)
    if player == nil or not player.getID then
        return false
    end
    local charId = player:getID()
    local prev   = stanceModsByChar[charId]
    if prev == nil then
        return false
    end
    if player.delMod then
        for _, entry in ipairs(prev) do
            player:delMod(entry[1], entry[2])
        end
    end
    stanceModsByChar[charId] = nil
    return true
end

local function syncStanceMasterMods(player)
    if not isHuntsman(player) then
        return clearStanceMasterMods(player)
    end

    local lvl       = player:getMainLvl()
    local hasAxe    = isAxeEquipped(player)
    local hasDagger = hasAxe and isOffhandDaggerEquipped(player)
    local pet       = getHuntsmanPet(player)
    local petAlive  = (pet ~= nil and (not pet.isAlive or pet:isAlive()))

    local desired = {}
    if hasAxe then
        if hasDagger then
            -- Axe + Offhand Dagger: nimble skirmisher tempo & evasion
            table.insert(desired, { xi.mod.ACC,     scaleTier(lvl, 8, 12, 16, 20) })
            table.insert(desired, { xi.mod.STORETP, scaleTier(lvl, 6, 10, 14, 18) })
            table.insert(desired, { xi.mod.EVA,     scaleTier(lvl, 6, 10, 14, 18) })
        else
            -- Single-Axe: reliable accuracy & TP generation so single-axe remains fully viable
            table.insert(desired, { xi.mod.ACC,     scaleTier(lvl, 10, 14, 18, 22) })
            table.insert(desired, { xi.mod.STORETP, scaleTier(lvl, 10, 14, 18, 22) })
        end
    end

    if petAlive then
        -- Companion Bond tempo bonus
        table.insert(desired, { xi.mod.STORETP, scaleTier(lvl, 4, 6, 8, 10) })
    end

    local charId  = player:getID()
    local prev    = stanceModsByChar[charId]
    local changed = (prev == nil) or (#prev ~= #desired)
    if not changed then
        for i = 1, #desired do
            if prev[i][1] ~= desired[i][1] or prev[i][2] ~= desired[i][2] then
                changed = true
                break
            end
        end
    end

    if not changed then
        return false
    end

    clearStanceMasterMods(player)
    if #desired > 0 and player.addMod then
        for _, entry in ipairs(desired) do
            player:addMod(entry[1], entry[2])
        end
        stanceModsByChar[charId] = desired
    end
    return true
end

-----------------------------------
-- Transient Defensive Windows: Predator's Feint, Guardian's Call, Last Whistle
-----------------------------------
local function clearFeintState(player, silent)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local st = feintStateByChar[charId]
    if st == nil then
        return
    end
    if st.active and st.evaMod and st.evaMod > 0 and player.delMod then
        player:delMod(xi.mod.EVA, st.evaMod)
    end
    st.active = false
    st.evaMod = 0
    st.expiresAt = 0
    if not silent then
        tell(player, 'Predator\'s Feint evasion window has worn off.')
    end
end

local function clearGuardiansCall(player, reasonMsg)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local st = guardiansCallByChar[charId]
    if st ~= nil and st.armed then
        guardiansCallByChar[charId] = nil
        if reasonMsg then
            tell(player, reasonMsg)
        end
    else
        guardiansCallByChar[charId] = nil
    end
end

local function clearLastWhistleEscape(player, silent)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local st = lastWhistleByChar[charId]
    if st == nil or not st.escapeActive then
        return
    end
    if player.delMod then
        for _, entry in ipairs(st.escapeMods or {}) do
            player:delMod(entry[1], entry[2])
        end
    end
    st.escapeActive    = false
    st.escapeExpiresAt = 0
    st.escapeMods      = {}
    if not silent then
        tell(player, 'Last Whistle escape window has ended.')
    end
end

local function tickTransientStates(player)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    local now    = nowSec()

    local feint = feintStateByChar[charId]
    if feint ~= nil and feint.active and now >= (feint.expiresAt or 0) then
        clearFeintState(player, true)
    end

    local gc = guardiansCallByChar[charId]
    if gc ~= nil and gc.armed then
        local pet = getHuntsmanPet(player)
        local petOk = pet ~= nil and (not pet.isAlive or pet:isAlive()) and (not pet.getID or pet:getID() == gc.petEntityId)
        if not petOk then
            clearGuardiansCall(player, 'Guardian\'s Call ended because your companion is no longer able to intercept.')
        elseif now >= (gc.expiresAt or 0) then
            clearGuardiansCall(player, nil)
        end
    end

    local lw = lastWhistleByChar[charId]
    if lw ~= nil then
        if lw.escapeActive and now >= (lw.escapeExpiresAt or 0) then
            clearLastWhistleEscape(player, false)
        end
        if (lw.resummonUntil or 0) > 0 and now >= lw.resummonUntil then
            lw.resummonUntil = 0
        end
    end
end

local function clearAllTransientCharState(player, clearCooldowns)
    if player == nil or not player.getID then
        return
    end
    local charId = player:getID()
    clearFeintState(player, true)
    clearGuardiansCall(player, nil)
    clearLastWhistleEscape(player, true)
    activeAoEContextByChar[charId] = nil
    interceptInProgress[charId]    = nil
    lastCureRawByTarget[charId]    = nil
    if clearCooldowns then
        feintStateByChar[charId]  = nil
        lastWhistleByChar[charId] = nil
        lastRationByChar[charId]  = nil
        lastGateMsgByChar[charId] = nil
    end
end

-----------------------------------
-- Beastguard: Passive AoE / Conal Survival
-----------------------------------
function huntsman.getBeastguardReduction(lvl)
    return scaleTier(lvl, 0.25, 0.28, 0.32, 0.35)
end

function huntsman.isBeastguardActive(player, attacker)
    if not isHuntsman(player) then
        return false, 0
    end
    local pet = getHuntsmanPet(player)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return false, 0
    end
    if player.checkDistance and player:checkDistance(pet) > huntsman.BEASTGUARD_RANGE then
        return false, 0
    end
    if attacker ~= nil then
        local attTarget = attacker.getTarget and attacker:getTarget() or nil
        if attTarget ~= pet then
            return false, 0
        end
    else
        -- HUD status query without a specific attacker: check if pet is engaged with a mob targeting pet
        local petTarget = pet.getTarget and pet:getTarget() or nil
        if petTarget == nil or not petTarget.getTarget or petTarget:getTarget() ~= pet then
            return false, 0
        end
    end
    return true, huntsman.getBeastguardReduction(player:getMainLvl())
end

local function applyBeastguardToDamage(defender, attacker, dmg, isEligibleAoE)
    if not isEligibleAoE or dmg == nil or dmg <= 0 or defender == nil then
        return dmg
    end
    local active, reduction = huntsman.isBeastguardActive(defender, attacker)
    if not active or reduction <= 0 then
        return dmg
    end
    return math.max(1, math.floor(dmg * (1.0 - reduction)))
end

-----------------------------------
-- Last Whistle: Pet Death Recovery
-----------------------------------
local function triggerLastWhistle(master)
    if not isHuntsman(master) or not master.getID then
        return false
    end
    if master.isAlive and not master:isAlive() then
        return false
    end

    local charId = master:getID()
    local now    = nowSec()
    local lw     = lastWhistleByChar[charId] or {}
    if now < (lw.cdUntil or 0) then
        local rem = math.max(1, math.ceil(lw.cdUntil - now))
        tell(master, string.format('Your companion has fallen! (Last Whistle on cooldown: %ds remaining)', rem))
        return false
    end

    -- Clear any previous escape mods safely before applying
    clearLastWhistleEscape(master, true)

    local escapeMods =
    {
        { xi.mod.EVA, 80 },
    }
    if xi.mod.MOVE_SPEED_STACKABLE then
        table.insert(escapeMods, { xi.mod.MOVE_SPEED_STACKABLE, 25 })
    end
    if master.addMod then
        for _, entry in ipairs(escapeMods) do
            master:addMod(entry[1], entry[2])
        end
    end

    -- Reset shared summon recast so an emergency 50%-HP resummon is available
    if master.resetRecast and xi.recast and xi.recast.ABILITY then
        master:resetRecast(xi.recast.ABILITY, RECAST_SUMMON)
    end

    lw.cdUntil         = now + huntsman.LAST_WHISTLE_COOLDOWN_SEC
    lw.escapeActive    = true
    lw.escapeExpiresAt = now + huntsman.LAST_WHISTLE_ESCAPE_SEC
    lw.escapeMods      = escapeMods
    lw.resummonUntil   = now + huntsman.LAST_WHISTLE_RESUMMON_SEC
    lastWhistleByChar[charId] = lw

    tell(master, string.format(
        'Last Whistle! %ds escape window (+25%% speed, +80 EVA) and emergency 50%%-HP companion resummon ready (%ds CD).',
        huntsman.LAST_WHISTLE_ESCAPE_SEC,
        huntsman.LAST_WHISTLE_COOLDOWN_SEC
    ))
    return true
end

local function attachPetListeners(master, pet)
    if pet == nil or not pet.addListener then
        return
    end
    if pet.removeListener then
        pet:removeListener('OX_HUNTSMAN_PET_DEATH')
        pet:removeListener('OX_HUNTSMAN_PET_DESPAWN')
    end

    pet:addListener('DEATH', 'OX_HUNTSMAN_PET_DEATH', function(deadPet)
        local owner = (deadPet and deadPet.getMaster and deadPet:getMaster()) or master
        if owner == nil then
            return
        end
        clearGuardiansCall(owner, 'Guardian\'s Call ended as your companion fell.')
        syncStanceMasterMods(owner)

        local intentional = deadPet and deadPet.getLocalVar and deadPet:getLocalVar('OX_HUNTSMAN_INTENTIONAL_DESPAWN') == 1
        if not intentional then
            triggerLastWhistle(owner)
        end
    end)

    pet:addListener('DESPAWN', 'OX_HUNTSMAN_PET_DESPAWN', function(gonePet)
        local owner = (gonePet and gonePet.getMaster and gonePet:getMaster()) or master
        if owner == nil then
            return
        end
        clearGuardiansCall(owner, nil)
        syncStanceMasterMods(owner)
    end)
end

-----------------------------------
-- Companion Role Mods (Balanced Mitigation, No 100% Blanket Immunity)
-----------------------------------
local function applyPetRoleMods(player, pet, pid)
    if player == nil or pet == nil or not xi or not xi.mod then
        return
    end
    attachPetListeners(player, pet)

    if pet.getLocalVar and pet:getLocalVar('OX_HUNTSMAN_PET_INIT') == 1 then
        spec.syncPetRoleMods(player, pet)
        return
    end
    if pet.setLocalVar then
        pet:setLocalVar('OX_HUNTSMAN_PET_INIT', 1)
    end

    local lvl = player:getMainLvl()
    if pid == PET_WILD_RAAZ or pid == PET_CEHUETZI then
        -- Glacial Tusker (Guardian): sustained durability & reliable boss threat
        pet:addMod(xi.mod.HPP,       scaleTier(lvl, 40, 50, 60, 70))
        pet:addMod(xi.mod.DMG,       -2800)
        pet:addMod(xi.mod.DEFP,      25)
        pet:addMod(xi.mod.ENMITY,    scaleTier(lvl, 70, 90, 110, 130))
        if xi.mod.DMGMAGIC then
            pet:addMod(xi.mod.DMGMAGIC, -1200)
        end
        if xi.mod.DMGBREATH then
            pet:addMod(xi.mod.DMGBREATH, -1200)
        end
        if xi.mod.MEVA then
            pet:addMod(xi.mod.MEVA, scaleTier(lvl, 15, 25, 35, 45))
        end
    elseif pid == PET_STALKER_RAPTOR or pid == PET_GABBRATH then
        -- Volcanic Saurian (Predator): active agile tanking & rapid threat establishment
        pet:addMod(xi.mod.HPP,    scaleTier(lvl, 25, 32, 40, 48))
        pet:addMod(xi.mod.DMG,    -1800)
        pet:addMod(xi.mod.ACC,    scaleTier(lvl, 12, 20, 28, 38))
        pet:addMod(xi.mod.EVA,    scaleTier(lvl, 15, 25, 35, 45))
        pet:addMod(xi.mod.ENMITY, scaleTier(lvl, 80, 100, 125, 150))
        if xi.mod.DMGMAGIC then
            pet:addMod(xi.mod.DMGMAGIC, -800)
        end
        if xi.mod.MEVA then
            pet:addMod(xi.mod.MEVA, scaleTier(lvl, 10, 18, 26, 35))
        end
    end

    if pet.updateHealth then
        pet:updateHealth()
    end
    spec.syncPetRoleMods(player, pet)
end

-----------------------------------
-- Threat Architecture: Master -> Pet Single-Target Enmity Transfer
-----------------------------------
local function transferSingleTargetEnmityToPet(master, target)
    if not isHuntsman(master) then
        return false
    end
    local pet = getHuntsmanPet(master)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return false
    end
    if target == nil or not target.isMob or not target:isMob() or not target:isAlive() then
        return false
    end
    if not target.getCE or not target.getVE or not target.setCE or not target.setVE or not target.addEnmity then
        return false
    end

    local ce = target:getCE(master) or 0
    local ve = target:getVE(master) or 0
    if ce > 0 or ve > 0 then
        -- Atomic zero-then-add prevents duplication across multiple listeners
        target:setCE(master, 0)
        target:setVE(master, 0)
        target:addEnmity(pet, ce, ve)
        return true
    end
    return false
end

local function addPetEnmity(mob, pet, ce, ve, master)
    if mob == nil or pet == nil then
        return
    end
    local wh = master and huntsman.getEquippedWarhorn(master) or nil
    local mult = 1.0 + ((wh and wh.petEnmityBonusPct) or 0)
    local finalCe = math.floor((ce or 0) * mult)
    local finalVe = math.floor((ve or 0) * mult)

    if mob.updateClaim then
        local owner = master or (pet.getMaster and pet:getMaster()) or nil
        if owner == nil or not owner.hasClaim or not owner:hasClaim(mob) then
            mob:updateClaim(pet)
        end
    end
    if mob.addEnmity then
        mob:addEnmity(pet, finalCe, finalVe)
    elseif mob.updateEnmityFromDamage then
        mob:updateEnmityFromDamage(pet, finalCe + finalVe)
    end
end

-----------------------------------
-- Cure Forwarding (Real Pre-Cap Value via getCureFinal, Zero Hardcoded Estimates)
-----------------------------------
local function forwardCureToCompanion(master, actualHealed, rawFinal)
    if not isHuntsman(master) then
        return 0
    end
    local pet, pid = getHuntsmanPet(master)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return 0
    end

    local healed   = math.max(0, math.floor(actualHealed or 0))
    local raw      = math.max(healed, math.floor(rawFinal or healed))
    local overheal = math.max(0, raw - healed)

    local rate = (pid == PET_WILD_RAAZ or pid == PET_CEHUETZI) and 0.70 or 0.55
    local petHeal = math.floor(raw * rate + 1e-9)
    if petHeal > 0 and pet.addHP then
        pet:addHP(petHeal)
    end
    return petHeal
end

-- Wrap global getCureFinal to capture the true pre-HP-cap cure value
if type(getCureFinal) == 'function' then
    local origGetCureFinal = getCureFinal
    getCureFinal = function(caster, spell, basecure, minCure, isBlueMagic)
        local final = origGetCureFinal(caster, spell, basecure, minCure, isBlueMagic)
        if caster ~= nil and caster.getID then
            lastCureRawByTarget[caster:getID()] = final
        end
        return final
    end
end

for _, spellName in ipairs({
    'cure', 'cure_ii', 'cure_iii', 'cure_iv', 'cure_v', 'cure_vi',
    'curaga', 'curaga_ii', 'curaga_iii', 'curaga_iv', 'curaga_v',
}) do
    m:addOverride(string.format('xi.actions.spells.white.%s.onSpellCast', spellName), function(caster, target, spell)
        if target ~= nil and isHuntsman(target) and getHuntsmanPet(target) ~= nil and target.getHP then
            local casterId = (caster and caster.getID) and caster:getID() or nil
            if casterId ~= nil then
                lastCureRawByTarget[casterId] = nil
            end
            local preHp  = target:getHP() or 0
            local res    = super(caster, target, spell)
            local healed = math.max(0, (target:getHP() or 0) - preHp)

            -- Compute true pre-cap cure amount (accounting for CURE_POTENCY_RCVD & server CURE_POWER)
            local rawFinal = healed
            if casterId ~= nil and lastCureRawByTarget[casterId] ~= nil then
                local captured = lastCureRawByTarget[casterId]
                lastCureRawByTarget[casterId] = nil
                local rcvd = (target.getMod and xi.mod.CURE_POTENCY_RCVD) and (target:getMod(xi.mod.CURE_POTENCY_RCVD) or 0) or 0
                local serverMult = (xi.settings and xi.settings.main and xi.settings.main.CURE_POWER) or 1.0
                rawFinal = math.floor((captured + captured * (rcvd / 100)) * serverMult)
            elseif type(res) == 'number' and res > healed then
                rawFinal = res
            end

            forwardCureToCompanion(target, healed, math.max(healed, rawFinal))
            return res
        end
        return super(caster, target, spell)
    end)
end

-----------------------------------
-- Warden's Ration Command Readiness Helper
-----------------------------------
local COMMAND_RECAST_IDS =
{
    RECAST_RIMETUSK_GORE,
    RECAST_SAURIAN_REND,
    RECAST_PRIMEVAL_TAKEDOWN,
    RECAST_GUARDIANS_CALL,
}

local function reduceHuntsmanCommandRecasts(player, seconds)
    if player == nil or seconds == nil or seconds <= 0 then
        return
    end
    if not xi.recast or not xi.recast.ABILITY then
        return
    end
    if player.getRecast and player.addRecast then
        for _, rid in ipairs(COMMAND_RECAST_IDS) do
            local rem = player:getRecast(xi.recast.ABILITY, rid) or 0
            if rem > 0 then
                local nextRem = math.max(0, rem - seconds)
                if nextRem == 0 and player.resetRecast then
                    player:resetRecast(xi.recast.ABILITY, rid)
                else
                    player:addRecast(xi.recast.ABILITY, rid, nextRem)
                end
            end
        end
    end
end

-----------------------------------
-- Listeners (Warden's Ration, Enmity Transfer, Weapon Gate, Tick)
-----------------------------------
local function detachHuntsmanListeners(player)
    if player == nil or not player.isPC or not player:isPC() then
        return
    end
    if player.removeListener then
        player:removeListener('OX_HUNTSMAN_WS')
        player:removeListener('OX_HUNTSMAN_ENMITY_ATK')
        player:removeListener('OX_HUNTSMAN_EQUIP')
        player:removeListener('OX_HUNTSMAN_TICK')
        player:removeListener('OX_HUNTSMAN_DEATH')
    end
    clearAllTransientCharState(player, false)
    if clearStanceMasterMods(player) and player.pushStatus then
        player:pushStatus()
    end
end

local function attachHuntsmanListeners(player)
    if player == nil or not player.isPC or not player:isPC() then
        return
    end

    -- Weapon whitelist & stance sync on equip changes
    player:removeListener('OX_HUNTSMAN_EQUIP')
    player:addListener('ITEM_EQUIP', 'OX_HUNTSMAN_EQUIP', function(actor)
        if not isHuntsman(actor) then
            return
        end
        enforceHuntsmanWeaponWhitelist(actor)
        syncStanceMasterMods(actor)
    end)

    -- Warden's Ration: 1H Axe WSs heal active companion 10/12/14/16% Max HP,
    -- grant +200 Pet TP, and shave 3s off active Huntsman command recasts (6s ICD).
    player:removeListener('OX_HUNTSMAN_WS')
    player:addListener('WEAPONSKILL_USE', 'OX_HUNTSMAN_WS', function(actor, target, skill)
        if not isHuntsman(actor) then
            return
        end

        transferSingleTargetEnmityToPet(actor, target)

        if not isAxeWs(skill) then
            return
        end

        local charId = actor.getID and actor:getID() or 0
        local now    = nowSec()
        if charId > 0 and (now - (lastRationByChar[charId] or 0)) < huntsman.WARDENS_RATION_ICD_SEC then
            return
        end

        local pet = getHuntsmanPet(actor)
        if pet ~= nil and (not pet.isAlive or pet:isAlive()) then
            if charId > 0 then
                lastRationByChar[charId] = now
            end
            local lvl     = actor:getMainLvl()
            local wh      = huntsman.getEquippedWarhorn(actor)
            local healPct = scaleTier(lvl, 0.10, 0.12, 0.14, 0.16) + ((wh and wh.rationHealBonusPct) or 0)
            local healAmt = math.max(1, math.floor((pet:getMaxHP() or 0) * healPct))
            local healed  = pet:addHP(healAmt)
            if pet.addTP then
                pet:addTP(200)
            end
            reduceHuntsmanCommandRecasts(actor, 3)
            if healed > 0 and actor.messagePublic and xi.msg and xi.msg.basic and xi.msg.basic.RECOVERS_HP then
                actor:messagePublic(xi.msg.basic.RECOVERS_HP, pet, 0, healed)
            end
        end
    end)

    player:removeListener('OX_HUNTSMAN_ENMITY_ATK')
    player:addListener('ATTACK', 'OX_HUNTSMAN_ENMITY_ATK', function(actor, target)
        transferSingleTargetEnmityToPet(actor, target)
    end)

    player:removeListener('OX_HUNTSMAN_DEATH')
    player:addListener('DEATH', 'OX_HUNTSMAN_DEATH', function(actor)
        clearAllTransientCharState(actor, false)
    end)

    player:removeListener('OX_HUNTSMAN_TICK')
    player:addListener('TICK', 'OX_HUNTSMAN_TICK', function(actor)
        if not isHuntsman(actor) then
            detachHuntsmanListeners(actor)
            return
        end

        tickTransientStates(actor)
        syncStanceMasterMods(actor)

        local pet, pid = getHuntsmanPet(actor)
        if pet ~= nil and (not pet.isAlive or pet:isAlive()) then
            applyPetRoleMods(actor, pet, pid)
            transferSingleTargetEnmityToPet(actor, actor:getTarget())

            if
                not pet:isEngaged() and
                (not pet.hasStatusEffect or not pet:hasStatusEffect(xi.effect.HEALING)) and
                actor:isEngaged()
            then
                local masterTarget = actor:getTarget()
                if masterTarget ~= nil and masterTarget:isAlive() and actor:checkDistance(pet) <= 25 then
                    actor:petAttack(masterTarget)
                end
            end
        end
    end)
end

-----------------------------------
-- Combat Hooks: Beastguard (Accurate AoE/Conal Classification) & Guardian's Call (ST Interception)
-----------------------------------
local function isSkillAoEOrConal(skill)
    if skill == nil then
        return false
    end
    local aoe = skill.isAoE and skill:isAoE()
    if aoe == true or (type(aoe) == 'number' and aoe ~= 0) then
        return true
    end
    local conal = skill.isConal and skill:isConal()
    if conal == true or (type(conal) == 'number' and conal ~= 0) then
        return true
    end
    return false
end

local function isSpellAoE(spell)
    if spell == nil then
        return false
    end
    if spell.isAoE then
        local a = spell:isAoE()
        if a == true or (type(a) == 'number' and a ~= 0) then
            return true
        end
    end
    if spell.getAOE then
        local a = spell:getAOE()
        if type(a) == 'number' and a ~= 0 then
            return true
        end
    end
    if spell.getTotalTargets and (spell:getTotalTargets() or 1) > 1 then
        return true
    end
    return false
end

-- Wrap mobskill damage calculators so we have authoritative skill:isAoE() / skill:isConal()
if xi.mobskills then
    for _, fnName in ipairs({ 'mobPhysicalMove', 'mobMagicalMove', 'mobBreathMove', 'mobRangedMove' }) do
        if xi.mobskills[fnName] then
            m:addOverride('xi.mobskills.' .. fnName, function(mob, target, skill, action, ...)
                local isAoE = isSkillAoEOrConal(skill)
                local tid = (target ~= nil and target.getID) and target:getID() or nil
                if tid ~= nil and isAoE then
                    activeAoEContextByChar[tid] = { attacker = mob, isAoE = true, expiresAt = nowSec() + 1 }
                end

                local info = super(mob, target, skill, action, ...)

                if isAoE and type(info) == 'table' and (info.damage or 0) > 0 then
                    info.damage = applyBeastguardToDamage(target, mob, info.damage, true)
                end
                return info
            end)
        end
    end

    -- Tank-role pet mobskill damage scaling for both Tusker (0.25x) and Saurian (0.35x)
    if xi.mobskills.processDamage then
        m:addOverride('xi.mobskills.processDamage', function(actor, target, skill, action, info)
            if
                actor ~= nil and
                actor.isPet and
                actor:isPet() and
                info ~= nil and
                (info.damage or 0) > 0
            then
                local master = actor.getMaster and actor:getMaster() or nil
                if isHuntsman(master) then
                    if isTuskerPet(master, actor) then
                        info.damage = math.max(1, math.floor(info.damage * 0.25))
                    elseif isSaurianPet(master, actor) then
                        info.damage = math.max(1, math.floor(info.damage * 0.35))
                    end
                end
            end

            return super(actor, target, skill, action, info)
        end)
    end
end

-- Wrap damage spell execution to capture caster + authoritative AoE flag for Beastguard & Guardian's Call
if xi.spells and xi.spells.damage then
    if xi.spells.damage.useDamageSpell then
        m:addOverride('xi.spells.damage.useDamageSpell', function(caster, target, spell)
            local aoe = isSpellAoE(spell)
            local tid = (target ~= nil and target.getID) and target:getID() or nil
            if tid ~= nil and aoe then
                activeAoEContextByChar[tid] = { attacker = caster, isAoE = true, expiresAt = nowSec() + 1 }
            end
            local res = super(caster, target, spell)
            if tid ~= nil then
                activeAoEContextByChar[tid] = nil
            end
            return res
        end)
    end

    if xi.spells.damage.calculateAreaOfEffectResistance then
        m:addOverride('xi.spells.damage.calculateAreaOfEffectResistance', function(target, spell)
            local mult = super(target, spell)
            if target ~= nil and isSpellAoE(spell) then
                local tid = target.getID and target:getID() or nil
                local ctx = tid and activeAoEContextByChar[tid] or nil
                local attacker = ctx and ctx.attacker or nil
                local active, reduction = huntsman.isBeastguardActive(target, attacker)
                if active and reduction > 0 then
                    mult = mult * (1.0 - reduction)
                end
            end
            return mult
        end)
    end
end

-- Guardian's Call: single-target attack interception via xi.overlords.onPreTakeDamage
local function computePetMitigatedDamage(pet, rawDmg, attackType)
    if pet == nil or rawDmg <= 0 then
        return 0
    end
    local dtBps = (pet.getMod and xi.mod.DMG) and (pet:getMod(xi.mod.DMG) or 0) or 0
    if attackType == xi.attackType.PHYSICAL and xi.mod.DMGPHYS and pet.getMod then
        dtBps = dtBps + (pet:getMod(xi.mod.DMGPHYS) or 0)
    elseif attackType == xi.attackType.MAGICAL and xi.mod.DMGMAGIC and pet.getMod then
        dtBps = dtBps + (pet:getMod(xi.mod.DMGMAGIC) or 0)
    elseif attackType == xi.attackType.BREATH and xi.mod.DMGBREATH and pet.getMod then
        dtBps = dtBps + (pet:getMod(xi.mod.DMGBREATH) or 0)
    end
    -- Respect global -50% (-5000 bps) DT cap
    dtBps = math.max(-5000, math.min(5000, dtBps))
    return math.max(1, math.floor(rawDmg * (10000 + dtBps) / 10000))
end

local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage

function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end

    local dmg = tonumber(amount) or 0
    if dmg <= 0 or defender == nil then
        return dmg
    end

    if not defender.isPC or not defender:isPC() or not isHuntsman(defender) then
        return dmg
    end

    local charId = defender.getID and defender:getID() or 0
    if charId <= 0 or interceptInProgress[charId] then
        return dmg
    end

    -- Check Guardian's Call single-target interception
    local gc = guardiansCallByChar[charId]
    if gc == nil or not gc.armed then
        return dmg
    end

    local now = nowSec()
    if now >= (gc.expiresAt or 0) then
        guardiansCallByChar[charId] = nil
        return dmg
    end

    -- Never intercept AoE / conal attacks
    local aoeCtx = activeAoEContextByChar[charId]
    if aoeCtx ~= nil and aoeCtx.isAoE and now <= (aoeCtx.expiresAt or 0) then
        return dmg
    end

    -- Never intercept unavoidable / typeless encounter mechanics
    local eligibleType =
        attackType == xi.attackType.PHYSICAL or
        attackType == xi.attackType.RANGED or
        attackType == xi.attackType.MAGICAL
    if not eligibleType or attacker == nil then
        return dmg
    end

    local pet = getHuntsmanPet(defender)
    local wh  = huntsman.getEquippedWarhorn(defender)
    local maxRange = huntsman.GUARDIANS_CALL_RANGE + ((wh and wh.guardiansCallRangeBonus) or 0)
    if
        pet == nil or
        (pet.isAlive and not pet:isAlive()) or
        (pet.getID and pet:getID() ~= gc.petEntityId) or
        (defender.checkDistance and defender:checkDistance(pet) > maxRange)
    then
        if pet == nil or (pet.isAlive and not pet:isAlive()) then
            clearGuardiansCall(defender, 'Guardian\'s Call failed because your companion has fallen.')
        end
        return dmg
    end

    -- Disarm BEFORE redirecting so multi-hit sequences only intercept ONE hit and never recurse
    guardiansCallByChar[charId] = nil
    interceptInProgress[charId] = true

    local petDmg = computePetMitigatedDamage(pet, dmg, attackType)
    if pet.takeDamage then
        pet:takeDamage(petDmg, attacker, attackType, damageType)
    end
    if attacker.isMob and attacker:isMob() and attacker.isAlive and attacker:isAlive() then
        addPetEnmity(attacker, pet, 300, 900, defender)
    end

    interceptInProgress[charId] = nil
    tell(defender, string.format('%s intercepts the blow for %d damage!', pet:getName(), petDmg))
    return 0
end

-----------------------------------
-- Login / Zoning / Level Sync
-----------------------------------
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        clearAllTransientCharState(player, false)
        if isHuntsman(player) then
            enforceHuntsmanWeaponWhitelist(player)
            attachHuntsmanListeners(player)
            syncStanceMasterMods(player)
            local pet, pid = getHuntsmanPet(player)
            if pet ~= nil then
                applyPetRoleMods(player, pet, pid)
            end
        else
            detachHuntsmanListeners(player)
        end
    end
end)

if xi.player and xi.player.onZoneOut then
    m:addOverride('xi.player.onZoneOut', function(player)
        if player ~= nil and player:isPC() then
            clearAllTransientCharState(player, false)
        end
        return super(player)
    end)
end

m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        if isHuntsman(player) then
            attachHuntsmanListeners(player)
            syncStanceMasterMods(player)
        else
            detachHuntsmanListeners(player)
        end
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        if isHuntsman(player) then
            attachHuntsmanListeners(player)
            syncStanceMasterMods(player)
        else
            detachHuntsmanListeners(player)
        end
    end
end)

-----------------------------------
-- Ability Binding Helpers & Summon Logic
-----------------------------------
local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

local function checkSummon(player, minLevel, label)
    if not isHuntsman(player) then
        tell(player, label .. ' is only available to RNG Huntsman spec (Lv.10+).')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if player:getMainLvl() < minLevel then
        tell(player, string.format('%s requires RNG Lv.%d+.', label, minLevel))
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not player:canUseMisc(xi.zoneMisc.PET) then
        return xi.msg.basic.CANT_BE_USED_IN_AREA, 0
    end
    return 0, 0
end

local function safeDespawnHuntsmanPet(player)
    if player == nil or not player.hasPet or not player:hasPet() then
        return
    end
    local existingPet = player:getPet()
    if existingPet ~= nil and existingPet.setLocalVar then
        existingPet:setLocalVar('OX_HUNTSMAN_INTENTIONAL_DESPAWN', 1)
    end
    clearGuardiansCall(player, nil)
    if player.despawnPet then
        player:despawnPet()
    end
end

local function doSummon(player, petId, label)
    -- 1 Active Pet Max: mark intentional despawn so Last Whistle never triggers on swaps
    safeDespawnHuntsmanPet(player)

    local charId = player.getID and player:getID() or 0
    local now    = nowSec()
    local lw     = charId > 0 and lastWhistleByChar[charId] or nil
    local isEmergencyResummon = (lw ~= nil and (lw.resummonUntil or 0) > now)

    xi.pet.spawnPet(player, petId)
    if not player:hasPet() then
        local fb = FALLBACK_PET_CONFIG[petId]
        if fb ~= nil then
            xi.pet.spawnPet(player, fb.fallbackId)
            if player:hasPet() then
                local pet = player:getPet()
                if pet ~= nil then
                    if pet.setLocalVar then
                        pet:setLocalVar('OX_HUNTSMAN_PET_KEY', fb.key)
                    end
                    if pet.setMobLevel then
                        pet:setMobLevel(player:getMainLvl(), true)
                    end
                    if pet.setModelId then
                        pet:setModelId(fb.modelId)
                    end
                    if pet.renameEntity then
                        pet:renameEntity(fb.name)
                    end
                end
            end
        end
    end

    spec.refreshPlayer(player, { skipSync = true, forceMods = true })
    syncStanceMasterMods(player)

    if player:hasPet() then
        local pet = player:getPet()
        applyPetRoleMods(player, pet, petId)

        if isEmergencyResummon then
            lw.resummonUntil = 0
            local halfHp = math.max(1, math.floor((pet:getMaxHP() or 1) * huntsman.LAST_WHISTLE_PET_HP_PCT))
            if pet.setHP then
                pet:setHP(halfHp)
            end
            if pet.setTP then
                pet:setTP(0)
            end
        else
            if pet.setHP and pet.getMaxHP then
                pet:setHP(pet:getMaxHP())
            elseif pet.addHP and pet.getMaxHP then
                pet:addHP(pet:getMaxHP())
            end
        end

        if player.recalculateAbilitiesTable then
            player:recalculateAbilitiesTable()
        end
        if player:isEngaged() then
            local masterTarget = player:getTarget()
            if masterTarget ~= nil and masterTarget:isAlive() then
                player:petAttack(masterTarget)
            end
        end

        local roleTag = (petId == PET_WILD_RAAZ or petId == PET_CEHUETZI)
            and 'Glacial Tusker Guardian'
            or 'Volcanic Saurian Predator'
        if isEmergencyResummon then
            tell(player, string.format('%s [%s] rushes to your whistle at 50%% HP!', label, roleTag))
        else
            tell(player, string.format('%s [%s] answers your call!', label, roleTag))
        end
    else
        tell(player, string.format('Failed to summon %s (ensure rng_specs.sql is imported).', label))
    end
    return 0
end

local function checkEnemyTarget(player, target, range)
    if
        target == nil or
        not target:isMob() or
        not target:isAlive() or
        target:getAllegiance() == player:getAllegiance()
    then
        return xi.msg.basic.CANNOT_ATTACK_TARGET
    end
    if player:checkDistance(target) > (range or 20.0) then
        return xi.msg.basic.TOO_FAR_AWAY
    end
    return 0
end

local function findRelevantEnemy(player)
    if player == nil then
        return nil
    end
    local tgt = player.getTarget and player:getTarget() or nil
    if tgt ~= nil and tgt.isMob and tgt:isMob() and tgt:isAlive() and tgt:getAllegiance() ~= player:getAllegiance() then
        return tgt
    end
    if xi.overlords.getNearbyMobs then
        local nearby = xi.overlords.getNearbyMobs(player, 20.0)
        for _, mob in ipairs(nearby) do
            if mob.getTarget and mob:getTarget() == player then
                return mob
            end
        end
    end
    return nil
end

-----------------------------------
-- 9 Custom Huntsman Job Abilities (480-486, 489-490)
-----------------------------------

-- 480: Call Wild Raaz (60s CD, Self, Lv.10+)
bindAbility('call_wild_raaz', function(player, target, ability)
    return checkSummon(player, 10, 'Call Wild Raaz')
end, function(player, target, ability)
    return doSummon(player, PET_WILD_RAAZ, 'Wild Raaz')
end)

-- 481: Call Stalker Raptor (60s CD, Self, Lv.10+)
bindAbility('call_stalker_raptor', function(player, target, ability)
    return checkSummon(player, 10, 'Call Stalker Raptor')
end, function(player, target, ability)
    return doSummon(player, PET_STALKER_RAPTOR, 'Stalker Raptor')
end)

-- 485: Call Cehuetzi (60s CD, Self, Lv.75)
bindAbility('call_cehuetzi', function(player, target, ability)
    return checkSummon(player, 75, 'Call Cehuetzi')
end, function(player, target, ability)
    return doSummon(player, PET_CEHUETZI, 'Cehuetzi')
end)

-- 486: Call Gabbrath (60s CD, Self, Lv.75)
bindAbility('call_gabbrath', function(player, target, ability)
    return checkSummon(player, 75, 'Call Gabbrath')
end, function(player, target, ability)
    return doSummon(player, PET_GABBRATH, 'Gabbrath')
end)

-- 482: Rimetusk Gore (30s CD, Single-Target Enemy 20y, requires Raaz/Cehuetzi)
bindAbility('rimetusk_gore', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not isTuskerPet(player) then
        tell(player, 'Rimetusk Gore requires an active Wild Raaz or Cehuetzi.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local err = checkEnemyTarget(player, target, 20.0)
    if err ~= 0 then
        return err, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end

    local lvl     = pet:getMainLvl()
    local isApex  = (pid == PET_CEHUETZI)
    local mult    = isApex and 1.20 or 1.0
    local rawDmg  = math.max(20, math.floor(((lvl * 2.8) + player:getStat(xi.mod.VIT)) * mult))
    local baseDmg = scaleLevelGapDmg(pet, target, scaleTankCommandDmg(player, rawDmg))
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
    target:updateEnmityFromDamage(pet, dmg)
    addPetEnmity(target, pet, isApex and 1600 or 1200, isApex and 4800 or 3600, player)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    local healAmt = math.max(1, math.floor((pet:getMaxHP() or 0) * 0.15))
    pet:addHP(healAmt)
    pet:delStatusEffectSilent(xi.effect.DEFENSE_BOOST)
    pet:addStatusEffect(xi.effect.DEFENSE_BOOST, { power = 15, duration = 10, origin = pet })
    local defEff = pet:getStatusEffect(xi.effect.DEFENSE_BOOST)
    if defEff ~= nil then
        defEff:addMod(xi.mod.DMG, -1500)
    end

    if isApex then
        slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, 15, 15, pet,
        {
            { xi.mod.ATTP, -15 },
            { xi.mod.MATT, -15 },
            { xi.mod.ACC,  -20 },
        }, xi.effect.ATTACK_DOWN)
    end

    tell(player, string.format('%s gores %s for %d damage (+15%% Pet HP, -15%% Pet DT 10s%s)!',
        pet:getName(), target:getName(), dmg, isApex and ', Cripple 15s' or ''))
    return dmg
end)

-- 483: Saurian Rend (30s CD, Single-Target Enemy 20y, requires Raptor/Gabbrath)
bindAbility('saurian_rend', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if not isSaurianPet(player) then
        tell(player, 'Saurian Rend requires an active Stalker Raptor or Gabbrath.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local err = checkEnemyTarget(player, target, 20.0)
    if err ~= 0 then
        return err, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end

    local lvl     = pet:getMainLvl()
    local isApex  = (pid == PET_GABBRATH)
    local mult    = isApex and 1.25 or 1.0
    local rawDmg  = math.max(25, math.floor(((lvl * 3.2) + player:getStat(xi.mod.DEX)) * mult))
    local baseDmg = scaleLevelGapDmg(pet, target, scaleTankCommandDmg(player, rawDmg))
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    target:updateEnmityFromDamage(pet, dmg)
    addPetEnmity(target, pet, isApex and 1350 or 1000, isApex and 4400 or 3400, player)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    pet:addHP(math.max(1, math.floor((pet:getMaxHP() or 0) * 0.12)))

    -- Agile predator self-response: +25 EVA & +15% Haste for 10s
    pet:delStatusEffectSilent(xi.effect.EVASION_BOOST)
    pet:addStatusEffect(xi.effect.EVASION_BOOST, { power = 25, duration = 10, origin = pet })
    local evaEff = pet:getStatusEffect(xi.effect.EVASION_BOOST)
    if evaEff ~= nil then
        evaEff:addMod(xi.mod.EVA, 25)
        if xi.mod.HASTE_ABILITY then
            evaEff:addMod(xi.mod.HASTE_ABILITY, 1500)
        end
    end

    slots.applySlot(target, slots.EFF_OX_DEB_EXPOSE, 20, 15, pet,
    {
        { xi.mod.EVA,  -20 },
        { xi.mod.MEVA, -20 },
    }, xi.effect.EVASION_DOWN)

    if isApex then
        slots.applySlot(target, slots.EFF_OX_DEB_BREACH, 15, 15, pet,
        {
            { xi.mod.DEFP, -15 },
            { xi.mod.MDEF, -15 },
        }, xi.effect.DEFENSE_DOWN)
    end

    tell(player, string.format('%s rends %s for %d damage (+12%% Pet HP, +25 Pet EVA/Haste 10s, Expose 15s%s)!',
        pet:getName(), target:getName(), dmg, isApex and ', Breach 15s' or ''))
    return dmg
end)

-- 484: Primeval Takedown (45s CD, Single-Target Enemy 20y)
bindAbility('primeval_takedown', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet = getHuntsmanPet(player)
    if pet == nil or not pet:isAlive() then
        tell(player, 'Primeval Takedown requires an active beast companion.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local err = checkEnemyTarget(player, target, 20.0)
    if err ~= 0 then
        return err, 0
    end
    return 0, 0
end, function(player, target, ability, action)
    local pet, pid = getHuntsmanPet(player)
    if pet == nil or target == nil or not target:isAlive() then
        return 0
    end
    if not pet:isEngaged() then
        player:petAttack(target)
    end

    local lvl    = pet:getMainLvl()
    local tusker = (pid == PET_WILD_RAAZ or pid == PET_CEHUETZI)
    local mult   = (pid == PET_CEHUETZI or pid == PET_GABBRATH) and 1.20 or 1.0

    local rawDmg  = math.max(25, math.floor(((lvl * (tusker and 3.0 or 3.6)) + player:getStat(xi.mod.STR)) * mult))
    local baseDmg = scaleLevelGapDmg(pet, target, scaleTankCommandDmg(player, rawDmg))
    local dmg     = utils.handleStoneskin(target, baseDmg, xi.attackType.PHYSICAL)

    target:takeDamage(dmg, pet, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
    target:updateEnmityFromDamage(pet, dmg)
    if action and action.recordDamage then
        action:recordDamage(target, xi.attackType.PHYSICAL, dmg)
    end

    -- 2s controlled interrupt Stun for both families
    if not target:hasStatusEffect(xi.effect.STUN) then
        target:addStatusEffect(xi.effect.STUN, { power = 1, duration = 2, origin = pet })
    end

    if tusker then
        addPetEnmity(target, pet, 800, 2400, player)
        local shield = math.max(50, math.floor((pet:getMaxHP() or 0) * 0.20))
        pet:delStatusEffectSilent(xi.effect.STONESKIN)
        pet:addStatusEffect(xi.effect.STONESKIN, { power = shield, duration = 12, origin = pet, tier = 4 })
        tell(player, string.format('%s slams %s with Primeval Takedown for %d damage (2s Stun + %d Permafrost Hide)!',
            pet:getName(), target:getName(), dmg, shield))
    else
        addPetEnmity(target, pet, 700, 2600, player)
        pet:addHP(math.max(1, math.floor((pet:getMaxHP() or 0) * 0.10)))
        if pet.addTP then
            pet:addTP(200)
        end
        if player.addTP then
            player:addTP(150)
        end
        tell(player, string.format('%s interrupts %s with Primeval Takedown for %d damage (2s Stun, +10%% Pet HP, +200 Pet TP, +150 TP)!',
            pet:getName(), target:getName(), dmg))
    end
    return dmg
end)

-- 489: Predator's Feint (45s CD, Self, Lv.10+, requires living companion)
bindAbility('predators_feint', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet = getHuntsmanPet(player)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        tell(player, 'Predator\'s Feint requires a living beast companion.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    if ability ~= nil and ability.setRecast then
        local cd = huntsman.FEINT_COOLDOWN_SEC
        if isOffhandDaggerEquipped(player) then
            cd = cd - huntsman.FEINT_DAGGER_CD_BONUS_SEC
        end
        ability:setRecast(cd)
    end
    return 0, 0
end, function(player, target, ability)
    local pet = getHuntsmanPet(player)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return 0
    end

    local charId = player.getID and player:getID() or 0
    local now    = nowSec()
    local prev   = charId > 0 and feintStateByChar[charId] or nil

    -- Anti-exploit guard: prevent stacking/duplicate threat transfers inside active 3s window
    if prev ~= nil and (now - (prev.lastUsedAt or 0)) < huntsman.FEINT_DURATION_SEC then
        tell(player, 'Predator\'s Feint is already active.')
        return 0
    end

    clearFeintState(player, true)

    local lvl       = player:getMainLvl()
    local hasDagger = isOffhandDaggerEquipped(player)
    local wh        = huntsman.getEquippedWarhorn(player)
    local evaBonus  = scaleTier(lvl, 120, 130, 140, 150)
        + (hasDagger and 15 or 0)
        + ((wh and wh.feintEvaBonus) or 0)

    if player.addMod then
        player:addMod(xi.mod.EVA, evaBonus)
    end
    if charId > 0 then
        feintStateByChar[charId] =
        {
            active     = true,
            evaMod     = evaBonus,
            expiresAt  = now + huntsman.FEINT_DURATION_SEC,
            lastUsedAt = now,
        }
    end

    -- Transfer Ranger's threat on relevant single target to companion and re-engage immediately
    local mob = findRelevantEnemy(player)
    local transferred = false
    if mob ~= nil then
        transferred = transferSingleTargetEnmityToPet(player, mob)
        addPetEnmity(mob, pet, 250, 900, player)
        if player.petAttack then
            player:petAttack(mob)
        end
    end

    tell(player, string.format('Predator\'s Feint! +%d EVA for %ds%s%s.',
        evaBonus,
        huntsman.FEINT_DURATION_SEC,
        transferred and (' — threat shed to ' .. pet:getName()) or (' — ' .. pet:getName() .. ' re-engages'),
        hasDagger and ' [Dagger: -5s CD]' or ''
    ))
    return 0
end)

-- 490: Guardian's Call (60s CD, Self, Lv.10+, requires living companion within range)
bindAbility('guardians_call', function(player, target, ability)
    if not isHuntsman(player) or player:getMainLvl() < 10 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local pet = getHuntsmanPet(player)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        tell(player, 'Guardian\'s Call requires a living beast companion.')
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    local wh = huntsman.getEquippedWarhorn(player)
    local maxRange = huntsman.GUARDIANS_CALL_RANGE + ((wh and wh.guardiansCallRangeBonus) or 0)
    if player.checkDistance and player:checkDistance(pet) > maxRange then
        tell(player, string.format('Your companion must be within %d yalms to answer Guardian\'s Call.', math.floor(maxRange)))
        return xi.msg.basic.TOO_FAR_AWAY, 0
    end
    return 0, 0
end, function(player, target, ability)
    local pet = getHuntsmanPet(player)
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return 0
    end

    local charId = player.getID and player:getID() or 0
    if charId > 0 then
        guardiansCallByChar[charId] =
        {
            armed       = true,
            expiresAt   = nowSec() + huntsman.GUARDIANS_CALL_WINDOW_SEC,
            petEntityId = pet.getID and pet:getID() or 0,
        }
    end

    tell(player, string.format('Guardian\'s Call! %s stands ready to intercept the next direct attack (%ds).',
        pet:getName(), huntsman.GUARDIANS_CALL_WINDOW_SEC))
    return 0
end)

-----------------------------------
-- HUD & Test Inspection Helpers
-----------------------------------
function huntsman.getHudState(player)
    if player == nil or not player.getID then
        return {}
    end
    local charId = player:getID()
    local now    = nowSec()
    tickTransientStates(player)

    local feint = feintStateByChar[charId]
    local feintRem = (feint and feint.active) and math.max(0, math.ceil((feint.expiresAt or 0) - now)) or 0

    local gc = guardiansCallByChar[charId]
    local gcRem = (gc and gc.armed) and math.max(0, math.ceil((gc.expiresAt or 0) - now)) or 0

    local lw = lastWhistleByChar[charId]
    local lwCd = lw and math.max(0, math.ceil((lw.cdUntil or 0) - now)) or 0
    local lwResummon = (lw and (lw.resummonUntil or 0) > now) and 1 or 0
    local bgActive = huntsman.isBeastguardActive(player, nil) and 1 or 0
    local wh = huntsman.getEquippedWarhorn(player)

    return
    {
        beastguard    = bgActive,
        feint_rem     = feintRem,
        guard_call    = gcRem,
        whistle_cd    = lwCd,
        whistle_ready = lwResummon,
        warhorn       = wh ~= nil and 1 or 0,
    }
end

-----------------------------------
-- Register RNG Huntsman Crystal
-----------------------------------
if xi.job and xi.job.RNG then
    spec.registerJob(xi.job.RNG, 'RNG',
    {
        {
            id            = 2,
            key           = HUNTSMAN_KEY,
            name          = 'Huntsman',
            role          = 'Melee Beast-Tank Warden',
            icon          = 'huntsman',
            reqLevel      = 10,
            petTankEnmity = true,
            description   = 'Melee Beast-Tank Warden wielding a 1H Axe (and optional offhand Dagger) alongside a Glacial Tusker (Wild Raaz / Cehuetzi) or Volcanic Saurian (Stalker Raptor / Gabbrath). Your companion is the true tank while you funnel threat, sustain it with Axe WSs, and survive via Beastguard, Predator\'s Feint, Guardian\'s Call, and Last Whistle.',
            highlights    =
            {
                'Melee Beast Warden (Lv.10+): 1H Axe primary with Soul Dual Wield for optional offhand Dagger; +10/12/15/18% HP, +15/25/35/50 Axe, +10/18/26/36 Dagger, -20 Master Enmity; 100% single-target Master->Pet threat transfer.',
                'Glacial Tusker (Wild Raaz Lv.10+ / Cehuetzi Lv.75): Sustained boss-anchor tank (+40..70% Pet HP, -28% DT, -12% extra MDT/BDT, +25% DEF, +70..130 Pet Enmity); Rimetusk Gore heals + fortifies.',
                'Volcanic Saurian (Stalker Raptor Lv.10+ / Gabbrath Lv.75): Agile, aggressive tank (+25..48% Pet HP, -18% DT, +15..45 EVA, +80..150 Pet Enmity); Saurian Rend grants snap threat, evasion/haste & Expose.',
                'Warden\'s Ration: 1H Axe WSs heal your companion 10/12/14/16% Max HP, grant +200 Pet TP, and reduce active Huntsman command recasts by 3s (6s ICD).',
                'Beastguard (25/28/32/35% AoE/conal reduction within 8y of tanking pet), Predator\'s Feint (45s CD: 3s evasion + ST threat transfer), Guardian\'s Call (60s CD: pet intercepts 1 ST blow), Last Whistle (180s CD: 4s escape + 50% HP emergency resummon on pet death).',
            },
            extraAbilities = function(player)
                local lvl  = player ~= nil and player:getMainLvl() or 10
                local list =
                {
                    69, -- Fight
                    70, -- Heel
                    71, -- Leave
                    73, -- Stay
                    ABIL_CALL_WILD_RAAZ,
                    ABIL_CALL_STALKER_RAPTOR,
                    ABIL_RIMETUSK_GORE,
                    ABIL_SAURIAN_REND,
                    ABIL_PRIMEVAL_TAKEDOWN,
                    ABIL_PREDATORS_FEINT,
                    ABIL_GUARDIANS_CALL,
                }
                if lvl >= 75 then
                    table.insert(list, ABIL_CALL_CEHUETZI)
                    table.insert(list, ABIL_CALL_GABBRATH)
                end
                return list
            end,
            extraTraits = { TRAIT_WARDENS_RATION, TRAIT_PRIMEVAL_PACK, TRAIT_APEX_BOND },
            mods = function(player)
                local lvl = player ~= nil and player:getMainLvl() or 10
                return
                {
                    { xi.mod.HPP,    scaleTier(lvl, 10, 12, 15, 18) },
                    { xi.mod.AXE,    scaleTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.DAGGER, scaleTier(lvl, 10, 18, 26, 36) },
                    { xi.mod.ENMITY, -20 },
                }
            end,
            onApply = function(player)
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                enforceHuntsmanWeaponWhitelist(player)
                attachHuntsmanListeners(player)
                syncStanceMasterMods(player)
                local pet, pid = getHuntsmanPet(player)
                if pet ~= nil then
                    applyPetRoleMods(player, pet, pid)
                end
            end,
            onRemove = function(player)
                detachHuntsmanListeners(player)
                clearAllTransientCharState(player, true)
                if player ~= nil and player.recalculateSkillsTable then
                    player:recalculateSkillsTable()
                end
                if player ~= nil and player.hasPet and player:hasPet() then
                    local pet = getHuntsmanPet(player)
                    if pet ~= nil then
                        safeDespawnHuntsmanPet(player)
                    end
                end
            end,
        },
    })
end

return m
