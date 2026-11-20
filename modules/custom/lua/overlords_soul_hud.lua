-----------------------------------
-- OverlordsXI Universal Soul HUD Server Sync
--
-- Reusable, delta-throttled server->client state synchronization for the
-- Ashita v4 `overlords_soulhud` addon via binary 0x1FC ("OXHD") packets.
--
-- API for Soul modules:
--   xi.overlords.hud.registerProvider(soulKey, collectorFn)
--     collectorFn(player) -> table of scalar key/value pairs (numbers/booleans/strings)
--   xi.overlords.hud.sync(player, force)
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_soul_hud')

local spec = xi.overlords.spec

xi.overlords = xi.overlords or {}
xi.overlords.hud = xi.overlords.hud or {}
local hud = xi.overlords.hud

hud.PROTO_TAG = '[OXHUD]|'
hud.providers = hud.providers or {}
hud.lastSigByCharId = hud.lastSigByCharId or {}
hud.lastSentAtByCharId = hud.lastSentAtByCharId or {}

local function sanitize(v)
    if type(v) == 'boolean' then
        return v and '1' or '0'
    elseif type(v) == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then
            return '0'
        end
        if v % 1 == 0 then
            return tostring(v)
        end
        return string.format('%.1f', v)
    end
    return tostring(v or ''):gsub('[|\r\n;=]', '')
end

local function effectRemSec(entity, effectId)
    if entity == nil or not entity.getStatusEffect or not effectId then
        return 0, nil
    end
    local eff = entity:getStatusEffect(effectId)
    if eff == nil then
        return 0, nil
    end
    local rem = 0
    if eff.getTimeRemaining then
        rem = math.max(0, math.floor((eff:getTimeRemaining() or 0) / 1000))
    end
    return rem, eff
end

-- Shared helper: remaining seconds + power for a status effect.
local function customEff(entity, effectId)
    local rem, eff = effectRemSec(entity, effectId)
    if eff == nil then
        return 0, 0
    end
    return rem, (eff.getPower and eff:getPower() or 0)
end

-- Shared helper: expiring localVar resource -> (value clamped to [0, cap], seconds remaining).
local function timedVar(entity, var, expVar, cap)
    if entity == nil or not entity.getLocalVar then
        return 0, 0
    end
    local val = entity:getLocalVar(var) or 0
    local exp = entity:getLocalVar(expVar) or 0
    local now = os.time()
    if val <= 0 or (exp > 0 and now > exp) then
        return 0, 0
    end
    if cap ~= nil then
        val = math.min(cap, val)
    end
    return math.max(0, val), math.max(0, exp - now)
end

-- Shared helper: remaining seconds from an expiry timestamp stored in a localVar.
local function expRemSec(entity, expVar)
    if entity == nil or not entity.getLocalVar then
        return 0
    end
    local exp = entity:getLocalVar(expVar) or 0
    if exp <= 0 then
        return 0
    end
    return math.max(0, exp - os.time())
end

-- Shared helper: Finishing Moves 0..5 across FINISHING_MOVE_1..6.
local function getFinishingMoves(player)
    if player == nil or not player.hasStatusEffect then
        return 0
    end
    if player:hasStatusEffect(xi.effect.FINISHING_MOVE_1) then
        local fmEff = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
        return math.max(1, math.min(5, fmEff and fmEff:getPower() or 1))
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_2) then
        return 2
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_3) then
        return 3
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_4) then
        return 4
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_5) or player:hasStatusEffect(xi.effect.FINISHING_MOVE_6) then
        return 5
    end
    return 0
end

-- Shared helper: active Pet status (alive, hpp, mpp, petId).
local function getPetState(player)
    if player == nil or not player.getPet then
        return false, 0, 0, 0, nil
    end
    local pet = player:getPet()
    if pet == nil or (pet.isAlive and not pet:isAlive()) then
        return false, 0, 0, 0, nil
    end
    local hpp = pet.getHPP and (pet:getHPP() or 0) or 0
    local mpp = 0
    if pet.getMaxMP and pet.getMP then
        local maxMp = pet:getMaxMP() or 0
        if maxMp > 0 then
            mpp = math.floor(math.max(0, math.min(100, (pet:getMP() or 0) * 100 / maxMp)))
        end
    end
    local pid = pet.getPetID and (pet:getPetID() or 0) or 0
    return true, hpp, mpp, pid, pet
end

-- Shared helper: active RUN Rune count (0..3).
local function countActiveRunes(player)
    if player == nil then
        return 0
    end
    if player.getActiveRuneCount then
        return math.max(0, math.min(3, player:getActiveRuneCount() or 0))
    end
    local n = 0
    if player.getStatusEffects and xi.effect and xi.effect.IGNIS and xi.effect.TENEBRAE then
        for _, eff in pairs(player:getStatusEffects() or {}) do
            local id = eff and eff.getEffectType and eff:getEffectType() or 0
            if id >= xi.effect.IGNIS and id <= xi.effect.TENEBRAE then
                n = n + 1
            end
        end
    end
    return math.min(3, n)
end

-- Shared helper: active BRD buff song count (0..4).
local BUFF_SONG_EFFECTS =
{
    xi.effect and xi.effect.MINUET,
    xi.effect and xi.effect.MADRIGAL,
    xi.effect and xi.effect.MARCH,
    xi.effect and xi.effect.MINNE,
    xi.effect and xi.effect.PAEON,
    xi.effect and xi.effect.MAMBO,
    xi.effect and xi.effect.BALLAD,
    xi.effect and xi.effect.CAROL,
    xi.effect and xi.effect.ETUDE,
    xi.effect and xi.effect.SCHERZO,
    xi.effect and xi.effect.HYMNUS,
    xi.effect and xi.effect.PRELUDE,
    xi.effect and xi.effect.MAZURKA,
}

local function countActiveBuffSongs(player)
    if player == nil or not player.hasStatusEffect then
        return 0
    end
    local count = 0
    for _, effId in ipairs(BUFF_SONG_EFFECTS) do
        if effId and player:hasStatusEffect(effId) then
            count = count + 1
        end
    end
    return math.min(4, count)
end

function hud.registerProvider(soulKey, collectorFn)
    if type(soulKey) == 'string' and soulKey ~= '' and type(collectorFn) == 'function' then
        hud.providers[soulKey] = collectorFn
    end
end

local IDENTITY_LEGACY_KEYS =
{
    kurogane     = 'shinobi',
    alphawarden  = 'soulbeast',
    gladiator    = 'spartan',
    aegistemplar = 'defender',
    marionettist = 'vanguard',
    caller       = 'celestial',
}

-- Canonical client/crystaljobs branch indices where spec.JOB_SPECS ordering
-- differs from crystaljobs.dll (labels.h) and native_actions.lua.
local IDENTITY_BRANCH_OVERRIDES =
{
    pugilist       = 2, -- PUP: crystaljobs branch 2 (spec.JOB_SPECS index 3)
    animist        = 3, -- PUP: crystaljobs branch 3 (spec.JOB_SPECS index 2)
    miragesentinel = 1, -- DNC: crystaljobs branch 1 (spec.JOB_SPECS index 4)
}

-- Authoritative, minimal nearby-caster Soul identity for OXSI.
-- Unlike the local HUD packet, this intentionally excludes private meters,
-- status effects, equipment, and other Soul resource details.
function hud.buildIdentityData(player)
    if player == nil or not player:isPC() then
        return { jobId = 0, branch = 0, soulKey = '' }
    end

    local jobId = tonumber(player:getMainJob()) or 0
    if jobId < 1 or jobId > 22 then
        return { jobId = 0, branch = 0, soulKey = '' }
    end

    local active = spec.get(player, jobId)
    if not active or not spec.isLevelEligible(player, jobId, active) then
        return { jobId = jobId, branch = 0, soulKey = '' }
    end

    local rawKey = tostring(active.canonicalKey or active.key or ''):lower()
    local key = IDENTITY_LEGACY_KEYS[rawKey] or rawKey
    local branch = IDENTITY_BRANCH_OVERRIDES[key] or (tonumber(active.id) or 0)
    if branch < 1 or branch > 3 or #key < 2 or #key > 64 or not key:match('^[%w_%-]+$') then
        return { jobId = jobId, branch = 0, soulKey = '' }
    end

    return {
        jobId   = jobId,
        branch  = branch,
        soulKey = key,
    }
end

function hud.buildPacketData(player)
    if player == nil or not player:isPC() then
        return { jobId = 0, soulKey = '', unlocked = 0, kv = '' }
    end

    local jobId = player:getMainJob()
    local active = spec.get(player, jobId)
    local soulKey = active and active.key or ''
    local unlocked = (active ~= nil and spec.isLevelEligible(player, jobId, active)) and 1 or 0

    local kvParts = {}
    local provider = (soulKey ~= '' and unlocked == 1) and hud.providers[soulKey] or nil
    if provider then
        local ok, data = pcall(provider, player)
        if ok and type(data) == 'table' then
            local keys = {}
            for k, _ in pairs(data) do
                keys[#keys + 1] = tostring(k)
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local cleanKey = sanitize(k)
                if cleanKey ~= '' then
                    kvParts[#kvParts + 1] = cleanKey .. '=' .. sanitize(data[k])
                end
            end
        end
    end

    local baseKv = table.concat(kvParts, ';')
    local budget = math.max(0, 224 - #soulKey - #baseKv)
    local oxBuffs = hud.collectOxBuffs and hud.collectOxBuffs(player, budget) or ''
    if oxBuffs ~= '' then
        if baseKv ~= '' then
            baseKv = baseKv .. ';ox_buffs=' .. oxBuffs
        else
            baseKv = 'ox_buffs=' .. oxBuffs
        end
    end

    return {
        jobId    = jobId,
        soulKey  = sanitize(soulKey),
        unlocked = unlocked,
        kv       = baseKv,
    }
end

function hud.sync(_player, _force)
    -- Handled silently via 0x1FC binary packet in overlords_soulhud_sync.cpp
end

-----------------------------------
-- 1. WAR Souls: commander, berserker, spartan
-----------------------------------
local COMMANDER_STANCES =
{
    { id = xi.effect and xi.effect.BERSERK,     code = 1 },
    { id = xi.effect and xi.effect.DEFENDER,    code = 2 },
    { id = xi.effect and xi.effect.AGGRESSOR,   code = 3 },
    { id = xi.effect and xi.effect.RETALIATION, code = 4 },
    { id = xi.effect and xi.effect.RESTRAINT,   code = 5 },
}

hud.registerProvider('commander', function(player)
    local stanceCode, stanceRem = 0, 0
    for _, st in ipairs(COMMANDER_STANCES) do
        if st.id then
            local rem = effectRemSec(player, st.id)
            if rem > 0 or (player.hasStatusEffect and player:hasStatusEffect(st.id)) then
                stanceCode, stanceRem = st.code, rem
                break
            end
        end
    end
    local warcryRem  = effectRemSec(player, xi.effect.WARCRY)
    local bulwarkRem = effectRemSec(player, xi.effect.COMMANDER_BULWARK or 816)
    local cadenceRem = effectRemSec(player, xi.effect.COMMANDER_CADENCE or 817)
    local regroupRem = effectRemSec(player, xi.effect.COMMANDER_REGROUP or 818)
    local tgt        = player.getTarget and player:getTarget() or nil
    local breachRem, breachTier = customEff(tgt, xi.effect.COMMANDER_BREACH or 815)
    local bannerRem  = math.max(warcryRem, bulwarkRem, cadenceRem, regroupRem)
    local orders     = (stanceCode > 0 and 1 or 0)
        + (warcryRem > 0 and 1 or 0)
        + (math.max(bulwarkRem, cadenceRem, regroupRem) > 0 and 1 or 0)
        + (breachRem > 0 and 1 or 0)
    return {
        stance      = stanceCode,
        stance_rem  = stanceRem,
        warcry_rem  = warcryRem,
        bulwark_rem = bulwarkRem,
        cadence_rem = cadenceRem,
        regroup_rem = regroupRem,
        banner_rem  = bannerRem,
        breach_rem  = breachRem,
        breach_tier = breachTier,
        orders      = orders,
    }
end)

hud.registerProvider('berserker', function(player)
    local berserkRem = effectRemSec(player, xi.effect.BERSERK)
    local aggroRem   = effectRemSec(player, xi.effect.AGGRESSOR)
    local surgeRem, surgePow = customEff(player, xi.effect.BERSERKER_SURGE or 819)
    local brageRem   = effectRemSec(player, xi.effect.BLOOD_RAGE)
    local warcryRem  = effectRemSec(player, xi.effect.WARCRY)
    local retalRem   = effectRemSec(player, xi.effect.RETALIATION)
    local fury       = (berserkRem > 0 and 1 or 0)
        + (aggroRem > 0 and 1 or 0)
        + (surgeRem > 0 and 1 or 0)
        + (math.max(brageRem, warcryRem, retalRem) > 0 and 1 or 0)
    return {
        fury          = fury,
        berserk_rem   = berserkRem,
        aggressor_rem = aggroRem,
        surge_rem     = surgeRem,
        surge_pow     = surgePow,
        bloodrage_rem = brageRem,
        warcry_rem    = warcryRem,
        retal_rem     = retalRem,
    }
end)

local function spartanProvider(player)
    local rem, pow = customEff(player, xi.effect.SPARTAN_WARD or 820)
    return {
        grit     = math.min(5, math.max(0, player:getLocalVar('OX_SPT_GRIT') or 0)),
        ward_rem = rem,
        ward_pow = pow,
        brace    = player:getLocalVar('OX_SPT_BRACE') or 0,
    }
end
hud.registerProvider('spartan', spartanProvider)
hud.registerProvider('gladiator', spartanProvider)

-----------------------------------
-- 2. MNK Souls: sensei, blackbelt, chiweaver
-----------------------------------
hud.registerProvider('sensei', function(player)
    local hasStaff = (player.getWeaponSkillType and xi.slot and xi.skill and player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.STAFF) and 1 or 0
    local csRem    = effectRemSec(player, xi.effect.COUNTERSTANCE)
    local dodgeRem = effectRemSec(player, xi.effect.DODGE)
    local focusRem = effectRemSec(player, xi.effect.FOCUS)
    local pcRem    = effectRemSec(player, xi.effect.PERFECT_COUNTER)
    local innerRem = effectRemSec(player, xi.effect.INNER_STRENGTH)
    local stances  = (csRem > 0 and 1 or 0)
        + (dodgeRem > 0 and 1 or 0)
        + (focusRem > 0 and 1 or 0)
        + (math.max(pcRem, innerRem) > 0 and 1 or 0)
    return {
        staff        = hasStaff,
        stances      = stances,
        counter_rem  = csRem,
        dodge_rem    = dodgeRem,
        focus_rem    = focusRem,
        pcounter_rem = pcRem,
        inner_rem    = innerRem,
    }
end)

hud.registerProvider('blackbelt', function(player)
    local focusRem = effectRemSec(player, xi.effect.FOCUS)
    local footRem  = effectRemSec(player, xi.effect.FOOTWORK)
    local boostRem = effectRemSec(player, xi.effect.BOOST)
    local dodgeRem = effectRemSec(player, xi.effect.DODGE)
    local hfRem    = effectRemSec(player, xi.effect.HUNDRED_FISTS)
    local stances  = (focusRem > 0 and 1 or 0)
        + (footRem > 0 and 1 or 0)
        + (boostRem > 0 and 1 or 0)
        + (math.max(dodgeRem, hfRem) > 0 and 1 or 0)
    return {
        stances      = stances,
        focus_rem    = focusRem,
        footwork_rem = footRem,
        boost_rem    = boostRem,
        dodge_rem    = dodgeRem,
        hf_rem       = hfRem,
    }
end)

hud.registerProvider('chiweaver', function(player)
    local stacks = player:getLocalVar('OX_CHW_CHI_STACKS') or 0
    local boostRem, boostEff = effectRemSec(player, xi.effect.BOOST)
    if stacks <= 0 and boostEff ~= nil and boostEff.getSubPower and boostEff:getSubPower() == 2 then
        stacks = math.max(0, math.min(100, boostEff:getPower() or 0))
    end
    return {
        chi_stacks  = stacks,
        boost_rem   = boostRem,
        harmony_rem = effectRemSec(player, xi.effect.CHIWEAVER_HARMONY or 830),
        lotus_rem   = effectRemSec(player, xi.effect.CHIWEAVER_LOTUS or 829),
    }
end)

-----------------------------------
-- 3. WHM Soul: bishop
-----------------------------------
hud.registerProvider('bishop', function(player)
    local gRem, gPow = customEff(player, xi.effect.SACRED_GRACE or 861)
    local vRem       = effectRemSec(player, xi.effect.DIVINE_VEIL or 862)
    local wRem       = effectRemSec(player, xi.effect.SOLACE_WARD or 860)
    local dsealRem   = effectRemSec(player, xi.effect.DIVINE_SEAL)
    local solace     = (player:hasStatusEffect(xi.effect.AFFLATUS_SOLACE) and 1)
        or (player:hasStatusEffect(xi.effect.AFFLATUS_MISERY) and 2)
        or 0
    return {
        grace     = math.max(0, math.min(3, gPow)),
        grace_rem = gRem,
        veil_rem  = vRem,
        ward_rem  = wRem,
        dseal_rem = dsealRem,
        solace    = solace,
    }
end)

-----------------------------------
-- 4. BLM Soul: necromancer
-----------------------------------
hud.registerProvider('necromancer', function(player)
    local alive, hpp, _, pid = getPetState(player)
    local mode, role, thrallId = 'none', 'none', 0
    if alive then
        if pid == 130 then
            mode, role, thrallId = 'warrior', 'tank', 1
        elseif pid == 131 then
            mode, role, thrallId = 'mage', 'caster', 2
        elseif pid == 132 then
            mode, role, thrallId = 'corse', 'caster', 3
        elseif pid == 133 then
            mode, role, thrallId = 'dullahan', 'tank', 4
        end
    end
    local pact = (thrallId > 0 or (player:getLocalVar('OX_NECRO_PACT_DA') or 0) > 0) and 1 or 0
    return {
        thrall_id   = thrallId,
        thrall_mode = mode,
        thrall_role = role,
        thrall_hpp  = thrallId > 0 and hpp or 0,
        dark_pact   = pact,
    }
end)

-----------------------------------
-- 5. RDM Soul: crimsonduelist
-----------------------------------
local DUELIST_ENFEEBLES =
{
    xi.effect and xi.effect.DIA,
    xi.effect and xi.effect.BIO,
    xi.effect and xi.effect.SLOW,
    xi.effect and xi.effect.PARALYSIS,
    xi.effect and xi.effect.BLINDNESS,
    xi.effect and xi.effect.SILENCE,
    xi.effect and xi.effect.POISON,
    xi.effect and xi.effect.WEIGHT,
    xi.effect and xi.effect.BIND,
    xi.effect and xi.effect.ADDLE,
    xi.effect and xi.effect.EVASION_DOWN,
    xi.effect and xi.effect.MAGIC_EVASION_DOWN,
    xi.effect and xi.effect.ATTACK_DOWN,
    xi.effect and xi.effect.DEFENSE_DOWN,
    xi.effect and xi.effect.ACCURACY_DOWN,
    xi.effect and xi.effect.MAGIC_ATK_DOWN,
    xi.effect and xi.effect.MAGIC_DEF_DOWN,
}

hud.registerProvider('crimsonduelist', function(player)
    local fencer = 0
    if player.getEquipID and player.getWeaponSkillType and xi.slot and xi.skill then
        local mainId = player:getEquipID(xi.slot.MAIN) or 0
        local subId  = player:getEquipID(xi.slot.SUB) or 0
        if mainId > 0 and subId == 0 and player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.SWORD then
            fencer = 1
        end
    end
    local hexes = 0
    local tgt = player.getTarget and player:getTarget() or nil
    if tgt ~= nil and tgt ~= player and tgt.hasStatusEffect then
        for _, effId in ipairs(DUELIST_ENFEEBLES) do
            if effId and tgt:hasStatusEffect(effId) then
                hexes = hexes + 1
                if hexes >= 5 then
                    break
                end
            end
        end
    end
    local flowRem   = effectRemSec(player, xi.effect.CRIMSON_FLOW or 853)
    local flecheRem = effectRemSec(player, xi.effect.CRIMSON_FLECHE or 854)
    local compRem   = effectRemSec(player, xi.effect.COMPOSURE)
    local _, ssPow  = customEff(player, xi.effect.STONESKIN)
    return {
        fencer     = fencer,
        hexes      = hexes,
        flow_rem   = flowRem,
        fleche_rem = flecheRem,
        comp_rem   = compRem,
        stoneskin  = ssPow,
    }
end)

-----------------------------------
-- 6. PLD Souls: aegistemplar (defender), templar
-----------------------------------
local function aegisTemplarProvider(player)
    local zRem, zPow = customEff(player, xi.effect.AEGIS_ZEAL or 842)
    local cRem       = effectRemSec(player, xi.effect.AEGIS_CONSECRATION or 843)
    local rRem       = effectRemSec(player, xi.effect.HOLY_RETRIBUTION or 844)
    local sentRem    = effectRemSec(player, xi.effect.SENTINEL)
    return {
        zeal       = math.max(0, math.min(5, zPow)),
        zeal_rem   = zRem,
        consec_rem = cRem,
        retrib_rem = rRem,
        sent_rem   = sentRem,
    }
end
hud.registerProvider('aegistemplar', aegisTemplarProvider)
hud.registerProvider('defender', aegisTemplarProvider)

hud.registerProvider('templar', function(player)
    local aegisRem = effectRemSec(player, xi.effect.CRUSADERS_AEGIS or 864)
    local graceRem = effectRemSec(player, xi.effect.LIGHTS_GRACE or 863)
    local dsealRem = effectRemSec(player, xi.effect.DIVINE_SEAL)
    local shield   = (player.getShieldSize and (player:getShieldSize() or 0) > 0) and 1 or 0
    return {
        aegis_rem = aegisRem,
        grace_rem = graceRem,
        dseal_rem = dsealRem,
        shield    = shield,
    }
end)

-----------------------------------
-- 7. DRK Soul: dreadnought
-----------------------------------
hud.registerProvider('dreadnought', function(player)
    local cRem, cPow = customEff(player, xi.effect.BLOOD_CARAPACE or 855)
    local bRem, bPow = customEff(player, xi.effect.DREAD_BASTION or 856)
    local tithe, titheRem = timedVar(player, 'OX_DRK_TITHE', 'OX_DRK_TITHE_EXP', 3)
    local reapExp = player:getLocalVar('OX_DRK_BLOOD_REAP_EXP') or 0
    local _, spikesEff = effectRemSec(player, xi.effect.DREAD_SPIKES)
    local spikesHp = (spikesEff and spikesEff.getSubPower and spikesEff:getSubPower()) or 0
    return {
        tithe        = tithe,
        tithe_rem    = titheRem,
        reap_rem     = math.max(0, reapExp - os.time()),
        carapace_rem = cRem,
        carapace_pow = cPow,
        bastion_rem  = bRem,
        bastion_pow  = bPow,
        spikes_hp    = spikesHp,
    }
end)

-----------------------------------
-- 8. BST Soul: alphawarden
-----------------------------------
hud.registerProvider('alphawarden', function(player)
    local beastIdx = player:getLocalVar('OX_BST_WARDEN_PET') or 1
    if beastIdx < 1 or beastIdx > 4 then
        beastIdx = 1
    end
    local alive, hpp = getPetState(player)
    local isJug = (not player.hasJugPet) or player:hasJugPet()
    local petAlive = (alive and isJug) and 1 or 0
    local petHpp   = petAlive == 1 and hpp or 0
    local soullink = (petAlive == 1 and petHpp >= 15) and 1 or 0
    return {
        beast_idx  = beastIdx,
        pet_alive  = petAlive,
        pet_hpp    = petHpp,
        soullink   = soullink,
        bond_rem   = effectRemSec(player, xi.effect.ALPHA_SOUL_BOND or 849),
        fam_rem    = effectRemSec(player, xi.effect.ALPHA_FAMILIAR_BOND or 851),
        reward_rem = effectRemSec(player, xi.effect.ALPHA_REWARD_BOND or 852),
    }
end)

-----------------------------------
-- 9. BRD Souls: adventurer, musician, minstrel
-----------------------------------
hud.registerProvider('adventurer', function(player)
    local cRem, cPow = customEff(player, xi.effect.ADVENTURER_CADENCE or 832)
    local eRem       = effectRemSec(player, xi.effect.ADVENTURER_ENCORE or 833)
    return {
        cadence     = math.max(0, math.min(5, cPow)),
        cadence_rem = cRem,
        encore_rem  = eRem,
        songs       = countActiveBuffSongs(player),
    }
end)

hud.registerProvider('musician', function(player)
    local rRem, rPow = customEff(player, xi.effect.MUSICIAN_RESONANCE or 834)
    local oRem       = effectRemSec(player, xi.effect.MUSICIAN_OVERDRIVE or 835)
    return {
        resonance     = math.max(0, math.min(3, rPow)),
        resonance_rem = rRem,
        overdrive_rem = oRem,
        songs         = countActiveBuffSongs(player),
    }
end)

hud.registerProvider('minstrel', function(player)
    local minne   = (xi.effect.MINNE and player:hasStatusEffect(xi.effect.MINNE)) and 1 or 0
    local paeon   = (xi.effect.PAEON and player:hasStatusEffect(xi.effect.PAEON)) and 1 or 0
    local scherzo = (xi.effect.SCHERZO and player:hasStatusEffect(xi.effect.SCHERZO)) and 1 or 0
    local ariaRem = effectRemSec(player, xi.effect.MINSTREL_IRON_ARIA or 836)
    return {
        minne         = minne,
        paeon         = paeon,
        scherzo       = scherzo,
        hymns         = minne + paeon + scherzo,
        iron_aria_rem = ariaRem,
    }
end)

-----------------------------------
-- 10. RNG Soul: huntsman
-----------------------------------
hud.registerProvider('huntsman', function(player)
    local alive, hpp, _, pid, pet = getPetState(player)
    local petKey = 0
    if alive and pet then
        if pid >= 134 and pid <= 137 then
            petKey = pid - 133
        elseif pet.getLocalVar then
            petKey = pet:getLocalVar('OX_HUNTSMAN_PET_KEY') or 0
        end
    end
    local mode = 'none'
    if petKey == 1 or petKey == 3 then
        mode = 'tusker'
    elseif petKey == 2 or petKey == 4 then
        mode = 'saurian'
    end
    return {
        pet_id   = petKey,
        pet_mode = mode,
        pet_hpp  = petKey > 0 and hpp or 0,
    }
end)

-----------------------------------
-- 11. SAM Souls: ronin, imperialarcher, warlord
-----------------------------------
hud.registerProvider('ronin', function(player)
    return {
        stagger_pool  = player:getLocalVar('OX_RON_STAGGER_POOL') or 0,
        stagger_ticks = player:getLocalVar('OX_RON_STAGGER_TICKS') or 0,
        minds_eye     = player:getLocalVar('OX_RON_MINDS_EYE_CHARGES') or 0,
        seigan        = (xi.effect.SEIGAN and player:hasStatusEffect(xi.effect.SEIGAN)) and 1 or 0,
    }
end)

hud.registerProvider('imperialarcher', function(player)
    local oRem = effectRemSec(player, xi.effect.IMP_DRAWN_OISOYA or 838)
    local cRem = effectRemSec(player, xi.effect.IMP_COSMIC_BRAND or 839)
    local hRem = effectRemSec(player, xi.effect.HASSO)
    local seng = (xi.effect.SENGIKORI and player:hasStatusEffect(xi.effect.SENGIKORI)) and 1 or 0
    return {
        oisoya_rem = oRem,
        cosmic_rem = cRem,
        hasso_rem  = hRem,
        sengikori  = seng,
        primes     = (oRem > 0 and 1 or 0) + (cRem > 0 and 1 or 0),
    }
end)

hud.registerProvider('warlord', function(player)
    local aRem, aPow = customEff(player, xi.effect.WARLORD_ASHURA or 841)
    local nRem       = effectRemSec(player, xi.effect.WARLORD_NOTO or 840)
    local hRem       = effectRemSec(player, xi.effect.HASSO)
    return {
        ashura     = math.max(0, math.min(3, aPow)),
        ashura_rem = aRem,
        noto_rem   = nRem,
        hasso_rem  = hRem,
    }
end)

-----------------------------------
-- Shinobi NIN (internal key: kurogane): shadow-clone squad & command telemetry
-----------------------------------
hud.registerProvider('kurogane', function(player)
    local legionCd  = (player.getRecast and xi.recast and xi.recast.ABILITY) and (player:getRecast(xi.recast.ABILITY, 238) or 0) or 0
    local phantomCd = (player.getRecast and xi.recast and xi.recast.ABILITY) and (player:getRecast(xi.recast.ABILITY, 239) or 0) or 0
    local api = xi.overlords and xi.overlords.kurogane
    if api and api.getSnapshot then
        local snapshot = api.getSnapshot(player)
        return {
            clones      = snapshot.clones or 0,
            clone_exp   = snapshot.next_exp or 0,
            engaged     = snapshot.engaged or 0,
            phase       = snapshot.phase or 0,
            phase_rem   = snapshot.phase_rem or 0,
            feint_hits  = snapshot.feint_hits or 0,
            opening_rem = snapshot.opening_rem or 0,
            last_cmd    = snapshot.last_cmd or '',
            legion_cd   = math.max(0, math.ceil(legionCd)),
            phantom_cd  = math.max(0, math.ceil(phantomCd)),
            phantom_rem = snapshot.phantom_rem or 0,
            clone_err   = (snapshot.last_error ~= nil and snapshot.last_error ~= '') and 1 or 0,
            clone_test  = api.ENABLE_EXPERIMENTAL_CLONES and 1 or 0,
        }
    end
    return {
        clones      = 0,
        clone_exp   = 0,
        engaged     = 0,
        phase       = 0,
        phase_rem   = 0,
        feint_hits  = 0,
        opening_rem = 0,
        last_cmd    = '',
        legion_cd   = math.max(0, math.ceil(legionCd)),
        phantom_cd  = math.max(0, math.ceil(phantomCd)),
        phantom_rem = 0,
        clone_err   = 0,
        clone_test  = 0,
    }
end)

-----------------------------------
-- 12. NIN Soul: kagemusha
-----------------------------------
hud.registerProvider('kagemusha', function(player)
    local expires = player:getLocalVar('OX_NIN_ASH_EXP') or 0
    local stacks  = player:getLocalVar('OX_NIN_ASH') or 0
    if expires <= os.time() then
        stacks = 0
    end
    local shadows = math.max(0, math.min(5, (player.getMod and xi.mod and xi.mod.UTSUSEMI and player:getMod(xi.mod.UTSUSEMI)) or 0))
    return {
        ash          = math.max(0, math.min(4, stacks)),
        ash_rem      = math.max(0, expires - os.time()),
        shadows      = shadows,
        migawari_rem = expRemSec(player, 'OX_NIN_MIGAWARI_EXP'),
        bunshin_rem  = effectRemSec(player, xi.effect.KAGEMUSHA_BUNSHIN or 846),
        yonin        = (xi.effect.YONIN and player:hasStatusEffect(xi.effect.YONIN)) and 1 or 0,
    }
end)

-----------------------------------
-- 13. DRG Soul: wyvernheart
-----------------------------------
hud.registerProvider('wyvernheart', function(player)
    local sRem, sPow = customEff(player, xi.effect.DRAGONSCALE or 874)
    local nRem, nPow = customEff(player, xi.effect.DRAGONSCALE_SANCTUARY or 875)
    local scale, scaleRem = timedVar(player, 'OX_WYV_SCALE', 'OX_WYV_SCALE_EXP', 3)
    local alive, hpp = getPetState(player)
    return {
        wyrmscale     = scale,
        wyrmscale_rem = scaleRem,
        scale_rem     = sRem,
        scale_pow     = sPow,
        sanct_rem     = nRem,
        sanct_pow     = nPow,
        wyvern_hpp    = alive and hpp or 0,
    }
end)

-----------------------------------
-- 14. SMN Soul: celestial
-----------------------------------
hud.registerProvider('celestial', function(player)
    local alive, hpp = getPetState(player)
    return {
        avatar     = alive and 1 or 0,
        avatar_hpp = alive and hpp or 0,
        sanct_rem  = effectRemSec(player, xi.effect.CELESTIAL_SANCTUARY or 869),
        conv_rem   = effectRemSec(player, xi.effect.CELESTIAL_CONVERGENCE or 870),
        astral_rem = effectRemSec(player, xi.effect.ASTRAL_FLOW),
    }
end)

-----------------------------------
-- 15. BLU Souls: magus, azurebastion
-----------------------------------
hud.registerProvider('magus', function(player)
    local cRem, cPow = customEff(player, xi.effect.AZURE_CATALYST or 865)
    local oRem, oPow = customEff(player, xi.effect.OSMOTIC_CONDUIT or 866)
    return { catalyst = cPow, catalyst_stacks = cPow, catalyst_rem = cRem, conduit_rem = oRem, conduit_pow = oPow }
end)

hud.registerProvider('azurebastion', function(player)
    local cRem, cPow = customEff(player, xi.effect.CHITIN_CARAPACE or 857)
    local sRem       = customEff(player, xi.effect.AZURE_SURGE or 858)
    local dRem       = customEff(player, xi.effect.DIAMOND_SHELL or 859)
    return { carapace = cPow, chitin_stacks = cPow, chitin_rem = cRem, surge_rem = sRem, shell_rem = dRem }
end)

-----------------------------------
-- 16. COR Souls: flintlock, gambler, buccaneer
-----------------------------------
hud.registerProvider('flintlock', function(player)
    local chRem, chPow = customEff(player, xi.effect.CORSAIRS_ROLL)
    local hairRem      = math.max(expRemSec(player, 'OX_COR_HAIR_TRIGGER_EXP'), effectRemSec(player, xi.effect.TRIPLE_SHOT))
    local markRem      = 0
    local tgt          = player.getTarget and player:getTarget() or nil
    if tgt ~= nil and tgt.getLocalVar then
        local exp = tgt:getLocalVar('OX_COR_POWDER_MARK') or 0
        local by  = tgt:getLocalVar('OX_COR_POWDER_BY') or 0
        if exp > os.time() and (by == 0 or by == player:getID()) then
            markRem = exp - os.time()
        end
    end
    local primed = (chRem > 0 and 1 or 0) + (hairRem > 0 and 1 or 0) + (markRem > 0 and 1 or 0)
    return {
        powder      = primed,
        chamber_rem = chRem,
        chamber_wsd = chPow,
        hair_rem    = hairRem,
        mark_rem    = markRem,
    }
end)

hud.registerProvider('gambler', function(player)
    local activeRolls = 0
    if player.getStatusEffects then
        for _, eff in pairs(player:getStatusEffects() or {}) do
            if eff and eff.getSourceType and eff:getSourceType() == xi.effectSourceType.CORSAIR_ROLL then
                activeRolls = activeRolls + 1
            end
        end
    end

    local gmb = xi.overlords.cor and xi.overlords.cor.getGamblerHudState and xi.overlords.cor.getGamblerHudState(player) or {}
    local duRem, duEff = effectRemSec(player, xi.effect.DOUBLE_UP_CHANCE)
    local rollTotal = player:getLocalVar('corsairRollTotal') or 0
    local overdrive = player:getLocalVar('corsairRollBonus') == 1 and 1 or 0
    local debtRem = effectRemSec(player, xi.effect.HOUSE_DEBT or 882)
    local ccRem, ccEff = effectRemSec(player, xi.effect.CARD_COUNTING or 883)
    local snakeActive = player:hasStatusEffect(xi.effect.SNAKE_EYE) and 1 or 0

    local ccType = 0
    if ccEff ~= nil and ccEff.getSubPower then
        ccType = ccEff:getSubPower() or 0
    elseif ccEff ~= nil and ccEff.getPower then
        ccType = ccEff:getPower() or 0
    end

    return {
        rolls     = activeRolls,
        ante_n    = gmb.anteCount or 0,
        ante_hp   = gmb.anteHp or 0,
        ante_tp   = gmb.anteTp or 0,
        roll_tot  = duEff ~= nil and rollTotal or 0,
        du_rem    = duRem,
        roll_lock = gmb.rollLockRem or 0,
        overdrive = (duEff ~= nil and overdrive == 1) and 1 or 0,
        last_cdr  = gmb.lastCdr or 0,
        debt_rem  = debtRem,
        snake_act = snakeActive,
        cc_rem    = ccRem,
        cc_type   = ccType,
    }
end)

hud.registerProvider('buccaneer', function(player)
    local aRem, aPow = customEff(player, xi.effect.HOUSE_ADVANTAGE or 884)
    local cRem, cPow = customEff(player, xi.effect.CARD_COUNTING or 883)
    local dRem, dPow = customEff(player, xi.effect.HOUSE_DEBT or 882)
    local grape = timedVar(player, 'OX_COR_GRAPESHOT', 'OX_COR_GRAPESHOT_EXP', 3)
    local salt, saltRem = timedVar(player, 'OX_COR_SALTSPRAY', 'OX_COR_SALTSPRAY_EXP', nil)
    local galRem = effectRemSec(player, xi.effect.GALLANTS_ROLL)
    return {
        grapeshot     = grape,
        saltspray     = salt,
        saltspray_rem = saltRem,
        galleon_rem   = galRem,
        adv_rem       = aRem,
        adv_pow       = aPow,
        cc_rem        = cRem,
        cc_pow        = cPow,
        debt_rem      = dRem,
        debt_pow      = dPow,
    }
end)

-----------------------------------
-- 17. PUP Souls: vanguard, pugilist, animist
-----------------------------------
local MANEUVER_EFFECTS =
{
    xi.effect and xi.effect.FIRE_MANEUVER,
    xi.effect and xi.effect.ICE_MANEUVER,
    xi.effect and xi.effect.WIND_MANEUVER,
    xi.effect and xi.effect.EARTH_MANEUVER,
    xi.effect and xi.effect.THUNDER_MANEUVER,
    xi.effect and xi.effect.WATER_MANEUVER,
    xi.effect and xi.effect.LIGHT_MANEUVER,
    xi.effect and xi.effect.DARK_MANEUVER,
}

local function collectPupCommon(player)
    local alive, hpp, mpp, _, pet = getPetState(player)
    local isAuto = alive and pet ~= nil and (not pet.isAutomaton or pet:isAutomaton())
    local maneuvers = 0
    if player.countEffect then
        for _, mId in ipairs(MANEUVER_EFFECTS) do
            if mId then
                maneuvers = maneuvers + (player:countEffect(mId) or 0)
            end
        end
    elseif player.getStatusEffects then
        for _, eff in pairs(player:getStatusEffects() or {}) do
            local id = eff and eff.getEffectType and eff:getEffectType() or 0
            if xi.effect and xi.effect.FIRE_MANEUVER and xi.effect.DARK_MANEUVER and id >= xi.effect.FIRE_MANEUVER and id <= xi.effect.DARK_MANEUVER then
                maneuvers = maneuvers + 1
            end
        end
    end
    local head  = player.getAutomatonHead and (player:getAutomatonHead() or 0) or 0
    local frame = player.getAutomatonFrame and (player:getAutomatonFrame() or 0) or 0
    return {
        pet_alive     = isAuto and 1 or 0,
        pet_hpp       = isAuto and hpp or 0,
        pet_mpp       = isAuto and mpp or 0,
        head          = head,
        frame         = frame,
        maneuvers     = math.min(3, maneuvers),
        overdrive_rem = effectRemSec(player, xi.effect.OVERDRIVE),
    }
end

hud.registerProvider('vanguard', function(player)
    local out = collectPupCommon(player)
    out.bulwark_rem = expRemSec(player, 'OX_VNG_BULWARK_EXP')
    return out
end)

hud.registerProvider('pugilist', function(player)
    local out = collectPupCommon(player)
    local openRem = 0
    local tgt = player.getTarget and player:getTarget() or nil
    if tgt ~= nil and tgt.getLocalVar then
        local exp = tgt:getLocalVar('OX_PGL_OPENING_EXP') or 0
        if exp > os.time() then
            openRem = exp - os.time()
        end
    end
    out.opening_rem = openRem
    out.limiter_rem = effectRemSec(player, xi.effect.BERSERK)
    return out
end)

hud.registerProvider('animist', function(player)
    local out = collectPupCommon(player)
    local cells, cellsRem = timedVar(player, 'OX_ANM_CELLS', 'OX_ANM_CELL_EXP', 3)
    if out.overdrive_rem > 0 then
        cells = 3
    end
    out.soulspark     = cells
    out.soulspark_rem = cellsRem
    out.aegis_rem     = effectRemSec(player, xi.effect.CLOCKWORK_AEGIS or 871)
    return out
end)

-----------------------------------
-- 18. DNC Souls: bladewheel, vampire, miragesentinel
-----------------------------------
hud.registerProvider('bladewheel', function(player)
    local amRem = math.max(
        effectRemSec(player, xi.effect.AFTERMATH_LV1),
        expRemSec(player, 'OX_CHAKRAM_AM')
    )
    return {
        throw_stance = (player:getLocalVar('OX_THROW_STANCE') == 1) and 1 or 0,
        fm           = getFinishingMoves(player),
        am_rem       = amRem,
    }
end)

hud.registerProvider('vampire', function(player)
    local tranceRem = effectRemSec(player, xi.effect.TRANCE)
    local fm        = tranceRem > 0 and 5 or getFinishingMoves(player)
    return {
        fm           = fm,
        trance_rem   = tranceRem,
        contra_rem   = effectRemSec(player, xi.effect.CONTRADANCE),
        veil_rem     = effectRemSec(player, xi.effect.CRIMSON_VEIL or 867),
        sanguine_rem = effectRemSec(player, xi.effect.SANGUINE_WALTZ or 868),
    }
end)

hud.registerProvider('miragesentinel', function(player)
    local fm = getFinishingMoves(player)
    local fanRem, fanEff = effectRemSec(player, xi.effect.FAN_DANCE)
    local fanDt = 0
    if fanEff ~= nil then
        fanDt = math.max(10, math.min(45, fanEff:getPower() or 30))
    end

    local issekRem = effectRemSec(player, xi.effect.ISSEKIGAN)
    local aegisHp = player:getLocalVar('OX_DNC_AEGIS_WALTZ') or 0
    local aegisExp = player:getLocalVar('OX_DNC_AEGIS_WALTZ_EXP') or 0
    local aegisRem = (aegisHp > 0 and aegisExp > os.time()) and (aegisExp - os.time()) or 0
    if aegisRem <= 0 then
        aegisHp = 0
    end

    return {
        fm        = fm,
        fan_act   = fanEff ~= nil and 1 or 0,
        fan_dt    = fanDt,
        fan_rem   = fanRem,
        issek_rem = issekRem,
        parry_fm  = player:getLocalVar('OX_DNC_PARRY_FM') or 0,
        aegis_hp  = aegisHp,
        aegis_rem = aegisRem,
    }
end)

-----------------------------------
-- 19. SCH Souls: medic, sage
-----------------------------------
hud.registerProvider('medic', function(player)
    local alive, hpp, _, pid = getPetState(player)
    local eosAlive = (alive and pid == 128) and 1 or 0
    local arts = (player:hasStatusEffect(xi.effect.ADDENDUM_WHITE) and 2)
        or (player:hasStatusEffect(xi.effect.LIGHT_ARTS) and 1)
        or 0
    local sublState, sublMp = 0, 0
    if player:hasStatusEffect(xi.effect.SUBLIMATION_COMPLETE) then
        sublState = 2
        local eff = player:getStatusEffect(xi.effect.SUBLIMATION_COMPLETE)
        sublMp = eff and (eff:getPower() or 0) or 0
    elseif player:hasStatusEffect(xi.effect.SUBLIMATION_ACTIVATED) then
        sublState = 1
        local eff = player:getStatusEffect(xi.effect.SUBLIMATION_ACTIVATED)
        sublMp = eff and (eff:getPower() or 0) or 0
    end
    return {
        eos        = eosAlive,
        eos_hpp    = eosAlive == 1 and hpp or 0,
        arts       = arts,
        subl_state = sublState,
        subl_mp    = sublMp,
    }
end)

hud.registerProvider('sage', function(player)
    local alive, hpp, _, pid = getPetState(player)
    local titaniaAlive = (alive and pid == 129) and 1 or 0
    local arts = (player:hasStatusEffect(xi.effect.ADDENDUM_BLACK) and 2)
        or (player:hasStatusEffect(xi.effect.DARK_ARTS) and 1)
        or 0
    local ebul = player:hasStatusEffect(xi.effect.EBULLIENCE) and 1 or 0
    return {
        titania     = titaniaAlive,
        titania_hpp = titaniaAlive == 1 and hpp or 0,
        arts        = arts,
        ebullience  = ebul,
    }
end)

-----------------------------------
-- 20. GEO Soul: verdant
-----------------------------------
hud.registerProvider('verdant', function(player)
    local alive, hpp = getPetState(player)
    return {
        luopan       = alive and 1 or 0,
        luopan_hpp   = alive and hpp or 0,
        bolster_rem  = effectRemSec(player, xi.effect.BOLSTER),
        canopy_rem   = effectRemSec(player, xi.effect.CANOPY_OF_THE_ANCIENTS or 873),
        barkskin_rem = effectRemSec(player, xi.effect.BARKSKIN or 872),
    }
end)

-----------------------------------
-- 21. RUN Souls: inquisitor, spellblade, lifebinder
-----------------------------------
hud.registerProvider('inquisitor', function(player)
    local bRem = effectRemSec(player, xi.effect.INQUISITOR_BATTUTA or 821)
    local aRem = effectRemSec(player, xi.effect.INQUISITOR_AEGIS or 822)
    local cRem = effectRemSec(player, xi.effect.INQUISITOR_CONVERGE or 823)
    local stance = (cRem > 0 and 3) or (aRem > 0 and 2) or (bRem > 0 and 1) or 0
    return {
        runes        = countActiveRunes(player),
        stance       = stance,
        battuta_rem  = bRem,
        aegis_rem    = aRem,
        converge_rem = cRem,
    }
end)

hud.registerProvider('spellblade', function(player)
    local cond = math.max(
        player:getLocalVar('OX_RUN_CONDUCTION') or 0,
        player:getLocalVar('OX_RUN_PREP_STACKS') or 0
    )
    local eRem = effectRemSec(player, xi.effect.SPELLBLADE_EDGEFLARE or 824)
    local oRem = effectRemSec(player, xi.effect.SPELLBLADE_OVERCHARGE or 831)
    local aRem = effectRemSec(player, xi.effect.SPELLBLADE_ASCENDANCE or 828)
    return {
        prep_stacks    = math.max(0, math.min(3, cond)),
        runes          = countActiveRunes(player),
        edgeflare_rem  = eRem,
        overcharge_rem = oRem,
        ascend_rem     = aRem,
    }
end)

hud.registerProvider('lifebinder', function(player)
    local fRem = effectRemSec(player, xi.effect.LIFEBINDER_FONT or 825)
    local sRem = effectRemSec(player, xi.effect.LIFEBINDER_SANCTUARY or 826)
    local vRem = math.max(effectRemSec(player, xi.effect.VALIANCE), effectRemSec(player, xi.effect.VALLATION))
    return {
        runes        = countActiveRunes(player),
        font_rem     = fRem,
        sanct_rem    = sRem,
        valiance_rem = vRem,
    }
end)

-----------------------------------
-- Active custom player buffs/shields for the client icon strip:
--   ox_buffs=<iconId>:<power>:<remSec>,...
-----------------------------------
local MAX_OX_BUFFS = 14
function hud.collectOxBuffs(player, maxChars)
    local registry = xi.overlords.statusRegistry
    if registry == nil or not player.getStatusEffects then
        return ''
    end

    local items = {}
    for _, eff in pairs(player:getStatusEffects() or {}) do
        if eff ~= nil and eff.getEffectType then
            local effectId = eff:getEffectType()
            local reg = registry[effectId]
            -- Custom Overlords effects only (789 Eos Regen, 815..884); debuffs included so House Debt etc. show.
            if reg ~= nil and (effectId == 789 or (effectId >= 815 and effectId <= 884)) then
                local rem = eff.getTimeRemaining and math.max(0, math.floor((eff:getTimeRemaining() or 0) / 1000)) or 0
                items[#items + 1] =
                {
                    sort = effectId,
                    text = string.format('%d:%d:%d', xi.overlords.getStatusIcon(effectId, effectId), math.floor(eff:getPower() or 0), rem),
                }
            end
        end
    end
    table.sort(items, function(a, b) return a.sort < b.sort end)

    local limit = maxChars or 180
    local out = {}
    local used = 0
    for i = 1, math.min(#items, MAX_OX_BUFFS) do
        local t = items[i].text
        local addLen = (#out > 0 and 1 or 0) + #t
        if used + addLen > limit then
            break
        end
        out[#out + 1] = t
        used = used + addLen
    end
    return table.concat(out, ',')
end

-----------------------------------
-- Lifecycle & Event Hooks
-----------------------------------
local function attachHudListeners(player)
    if player == nil or not player:isPC() then
        return
    end

    local function onDirty(actor)
        if actor ~= nil and actor:isPC() then
            hud.sync(actor, false)
        end
    end

    -- Replacing by listener id is not guaranteed across all server cores;
    -- remove first so zoning/re-entry cannot stack duplicate callbacks.
    player:removeListener('OX_SOULHUD_ABILITY')
    player:removeListener('OX_SOULHUD_WS')
    player:removeListener('OX_SOULHUD_MAGIC')
    player:removeListener('OX_SOULHUD_EFF_GAIN')
    player:removeListener('OX_SOULHUD_EFF_LOSE')
    player:removeListener('OX_SOULHUD_EFF_TICK')
    player:removeListener('OX_SOULHUD_DMG')
    player:removeListener('OX_SOULHUD_DEATH')
    player:removeListener('OX_SOULHUD_RAISE')

    player:addListener('ABILITY_USE', 'OX_SOULHUD_ABILITY', onDirty)
    player:addListener('WEAPONSKILL_USE', 'OX_SOULHUD_WS', onDirty)
    player:addListener('MAGIC_USE', 'OX_SOULHUD_MAGIC', onDirty)
    player:addListener('EFFECT_GAIN', 'OX_SOULHUD_EFF_GAIN', onDirty)
    player:addListener('EFFECT_LOSE', 'OX_SOULHUD_EFF_LOSE', onDirty)
    player:addListener('EFFECTS_TICK', 'OX_SOULHUD_EFF_TICK', onDirty)
    player:addListener('TAKE_DAMAGE', 'OX_SOULHUD_DMG', onDirty)
    player:addListener('PLAYER_DEATH', 'OX_SOULHUD_DEATH', function(p)
        hud.sync(p, true)
    end)
    player:addListener('RAISE_RECEIVED', 'OX_SOULHUD_RAISE', function(p)
        hud.sync(p, true)
    end)
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        attachHudListeners(player)
        hud.sync(player, true)
    end
end)

if spec and spec.refreshPlayer then
    local prevRefresh = spec.refreshPlayer
    spec.refreshPlayer = function(player, ...)
        local res = prevRefresh(player, ...)
        if player ~= nil and player:isPC() then
            hud.sync(player, true)
        end
        return res
    end
end

return m
