-----------------------------------
-- OverlordsXI Universal Soul HUD Server Sync
--
-- Reusable, delta-throttled server->client state synchronization for the
-- Ashita v4 `overlords_soulhud` addon via silent [OXHUD]|... SYSTEM_3 packets.
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

local MIN_AUTO_INTERVAL_SEC = 0.25

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

local function effectRemSec(player, effectId)
    if player == nil or not player.getStatusEffect or not effectId then
        return 0, nil
    end
    local eff = player:getStatusEffect(effectId)
    if eff == nil then
        return 0, nil
    end
    local rem = 0
    if eff.getTimeRemaining then
        rem = math.max(0, math.floor((eff:getTimeRemaining() or 0) / 1000))
    end
    return rem, eff
end

function hud.registerProvider(soulKey, collectorFn)
    if type(soulKey) == 'string' and soulKey ~= '' and type(collectorFn) == 'function' then
        hud.providers[soulKey] = collectorFn
    end
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

    local oxBuffs = hud.collectOxBuffs and hud.collectOxBuffs(player) or ''
    if oxBuffs ~= '' then
        kvParts[#kvParts + 1] = 'ox_buffs=' .. oxBuffs
    end

    return {
        jobId    = jobId,
        soulKey  = sanitize(soulKey),
        unlocked = unlocked,
        kv       = table.concat(kvParts, ';'),
    }
end

function hud.sync(_player, _force)
    -- Handled silently via 0x1FC binary packet in overlords_soulhud_sync.cpp
end

-----------------------------------
-- Built-in Soul Providers (Initial Examples)
-----------------------------------

-- COR Gambler
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

-- DNC Mirage Sentinel
hud.registerProvider('miragesentinel', function(player)
    local fm = 0
    if player:hasStatusEffect(xi.effect.FINISHING_MOVE_1) then
        local fmEff = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
        fm = fmEff and fmEff:getPower() or 1
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_2) then
        fm = 2
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_3) then
        fm = 3
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_4) then
        fm = 4
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_5) then
        fm = 5
    elseif player:hasStatusEffect(xi.effect.FINISHING_MOVE_6) then
        fm = 5
    end

    local fanRem, fanEff = effectRemSec(player, xi.effect.FAN_DANCE)
    local fanDt = 0
    if fanEff ~= nil then
        fanDt = math.max(15, math.min(45, fanEff:getPower() or 45))
    end

    local issekRem = effectRemSec(player, xi.effect.ISSEKIGAN)
    local aegisHp = player:getLocalVar('OX_DNC_AEGIS_WALTZ') or 0
    local aegisExp = player:getLocalVar('OX_DNC_AEGIS_WALTZ_EXP') or 0
    local aegisRem = (aegisHp > 0 and aegisExp > os.time()) and (aegisExp - os.time()) or 0
    if aegisRem <= 0 then
        aegisHp = 0
    end

    return {
        fm         = fm,
        fan_act    = fanEff ~= nil and 1 or 0,
        fan_dt     = fanDt,
        fan_rem    = fanRem,
        issek_rem  = issekRem,
        parry_fm   = player:getLocalVar('OX_DNC_PARRY_FM') or 0,
        aegis_hp   = aegisHp,
        aegis_rem  = aegisRem,
    }
end)


-- MNK Chi Weaver: persistent Chi stacks.
hud.registerProvider('chiweaver', function(player)
    return { chi_stacks = player:getLocalVar('OX_CHW_CHI_STACKS') or 0 }
end)

-- SAM Ronin: stored stagger damage, remaining ticks, and Mind's Eye charges.
hud.registerProvider('ronin', function(player)
    return {
        stagger_pool = player:getLocalVar('OX_RON_STAGGER_POOL') or 0,
        stagger_ticks = player:getLocalVar('OX_RON_STAGGER_TICKS') or 0,
        minds_eye = player:getLocalVar('OX_RON_MINDS_EYE_CHARGES') or 0,
    }
end)

-- NIN Kagemusha: expiring Kawarimi Ash resource.
hud.registerProvider('kagemusha', function(player)
    local expires = player:getLocalVar('OX_NIN_ASH_EXP') or 0
    local stacks = player:getLocalVar('OX_NIN_ASH') or 0
    if expires <= os.time() then stacks = 0 end
    return { ash = math.max(0, math.min(4, stacks)), ash_rem = math.max(0, expires - os.time()) }
end)

-- RUN Spellblade: stored conduction preparation for the next Runic spell.
hud.registerProvider('spellblade', function(player)
    return { prep_stacks = player:getLocalVar('OX_RUN_PREP_STACKS') or 0 }
end)

-- Shared helper: remaining seconds + power for a custom registry effect.
local function customEff(player, effectId)
    local rem, eff = effectRemSec(player, effectId)
    if eff == nil then
        return 0, 0
    end
    return rem, (eff.getPower and eff:getPower() or 0)
end

-- Shared helper: expiring localVar resource -> (value clamped to [0, cap], seconds remaining).
local function timedVar(player, var, expVar, cap)
    local val = player:getLocalVar(var) or 0
    local exp = player:getLocalVar(expVar) or 0
    local now = os.time()
    if val <= 0 or (exp > 0 and now > exp) then
        return 0, 0
    end
    if cap ~= nil then
        val = math.min(cap, val)
    end
    return math.max(0, val), math.max(0, exp - now)
end

-- WAR Spartan (Phalanx Ward 820; Spartan's Grit 0..5 from OX_SPT_GRIT).
hud.registerProvider('spartan', function(player)
    local rem, pow = customEff(player, xi.effect.SPARTAN_WARD or 820)
    return {
        grit     = math.min(5, math.max(0, player:getLocalVar('OX_SPT_GRIT') or 0)),
        ward_rem = rem,
        ward_pow = pow,
    }
end)

-- DRK Dreadnought (Blood Carapace 855, Dread Bastion 856; Blood Tithe 0..3, Blood Reap window).
hud.registerProvider('dreadnought', function(player)
    local cRem, cPow = customEff(player, xi.effect.BLOOD_CARAPACE or 855)
    local bRem, bPow = customEff(player, xi.effect.DREAD_BASTION or 856)
    local tithe, titheRem = timedVar(player, 'OX_DRK_TITHE', 'OX_DRK_TITHE_EXP', 3)
    local reapExp = player:getLocalVar('OX_DRK_BLOOD_REAP_EXP') or 0
    return {
        tithe        = tithe,
        tithe_rem    = titheRem,
        reap_rem     = math.max(0, reapExp - os.time()),
        carapace_rem = cRem,
        carapace_pow = cPow,
        bastion_rem  = bRem,
        bastion_pow  = bPow,
    }
end)

-- DRG Wyvernheart (Dragonscale 874, Dragonscale Sanctuary 875; Wyrmscale 0..3).
hud.registerProvider('wyvernheart', function(player)
    local sRem, sPow = customEff(player, xi.effect.DRAGONSCALE or 874)
    local nRem, nPow = customEff(player, xi.effect.DRAGONSCALE_SANCTUARY or 875)
    local scale, scaleRem = timedVar(player, 'OX_WYV_SCALE', 'OX_WYV_SCALE_EXP', 3)
    return {
        wyrmscale     = scale,
        wyrmscale_rem = scaleRem,
        scale_rem     = sRem,
        scale_pow     = sPow,
        sanct_rem     = nRem,
        sanct_pow     = nPow,
    }
end)

-- PUP Animist (Soulspark cells 0..3 from OX_ANM_CELLS).
hud.registerProvider('animist', function(player)
    local cells, cellsRem = timedVar(player, 'OX_ANM_CELLS', 'OX_ANM_CELL_EXP', 3)
    return { soulspark = cells, soulspark_rem = cellsRem }
end)

-- COR Buccaneer (House Advantage 884, Card Counting 883, House Debt 882; Grapeshot 0..3, Salt Spray shield).
hud.registerProvider('buccaneer', function(player)
    local aRem, aPow = customEff(player, xi.effect.HOUSE_ADVANTAGE or 884)
    local cRem, cPow = customEff(player, xi.effect.CARD_COUNTING or 883)
    local dRem, dPow = customEff(player, xi.effect.HOUSE_DEBT or 882)
    local grape = timedVar(player, 'OX_COR_GRAPESHOT', 'OX_COR_GRAPESHOT_EXP', 3)
    local salt, saltRem = timedVar(player, 'OX_COR_SALTSPRAY', 'OX_COR_SALTSPRAY_EXP', nil)
    return {
        grapeshot    = grape,
        saltspray    = salt,
        saltspray_rem = saltRem,
        adv_rem      = aRem,
        adv_pow      = aPow,
        cc_rem       = cRem,
        cc_pow       = cPow,
        debt_rem     = dRem,
        debt_pow     = dPow,
    }
end)

-- BLU Magus (Azure Catalyst 865 stacks, Osmotic Conduit 866).
hud.registerProvider('magus', function(player)
    local cRem, cPow = customEff(player, xi.effect.AZURE_CATALYST or 865)
    local oRem, oPow = customEff(player, xi.effect.OSMOTIC_CONDUIT or 866)
    return { catalyst = cPow, catalyst_stacks = cPow, catalyst_rem = cRem, conduit_rem = oRem, conduit_pow = oPow }
end)

-- BLU Azure Bastion (Chitin Carapace 857 stacks, Azure Surge 858, Diamond Shell 859).
hud.registerProvider('azurebastion', function(player)
    local cRem, cPow = customEff(player, xi.effect.CHITIN_CARAPACE or 857)
    local sRem = customEff(player, xi.effect.AZURE_SURGE or 858)
    local dRem = customEff(player, xi.effect.DIAMOND_SHELL or 859)
    return { carapace = cPow, chitin_stacks = cPow, chitin_rem = cRem, surge_rem = sRem, shell_rem = dRem }
end)

-- Active custom player buffs/shields for the client icon strip:
--   ox_buffs=<iconId>:<power>:<remSec>,...
local MAX_OX_BUFFS = 14
function hud.collectOxBuffs(player)
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

    local out = {}
    for i = 1, math.min(#items, MAX_OX_BUFFS) do
        out[#out + 1] = items[i].text
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
    player:removeListener('OX_SOULHUD_EFF_GAIN')
    player:removeListener('OX_SOULHUD_EFF_LOSE')
    player:removeListener('OX_SOULHUD_DMG')
    player:removeListener('OX_SOULHUD_DEATH')
    player:removeListener('OX_SOULHUD_RAISE')

    player:addListener('ABILITY_USE', 'OX_SOULHUD_ABILITY', onDirty)
    player:addListener('EFFECT_GAIN', 'OX_SOULHUD_EFF_GAIN', onDirty)
    player:addListener('EFFECT_LOSE', 'OX_SOULHUD_EFF_LOSE', onDirty)
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
