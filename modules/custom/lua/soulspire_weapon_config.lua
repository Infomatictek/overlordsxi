-----------------------------------
-- SoulspireXI — Reusable Soul Weapon Configuration System
--
-- Authoritative, data-driven per-Soul main-hand / offhand equipment rules.
-- Supports:
--   1. Dual one-handed      (mode = 'dual_1h')        [Phase 4: BRD Adventurer]
--   2. Two-handed + shield  (mode = 'twohand_shield') [Phase 5: opt-in per Soul]
--   3. Dual two-handed      (mode = 'dual_2h')        [Phase 5: opt-in per Soul]
--   4. Vanilla behavior     (Souls with no weaponConfig override)
--
-- C++ hooks (patch 0073-soul-weapon-config.patch) query:
--   xi.overlords.weaponConfig.evaluatePair(player, mainItem, subItem)
-- Return codes:
--   0  (VANILLA)          -> No Soul override applies; execute stock LSB rules.
--   1  (ALLOW_DUAL_WIELD) -> Soul permits (main, sub) as Dual Wield (m_dualWield = true).
--   2  (ALLOW_SUB_NON_DW) -> Soul permits (main, sub) as non-DW offhand (m_dualWield = false).
--  -1  (DENY)             -> Soul weapon config explicitly rejects (main, sub).
-----------------------------------
require('modules/custom/lua/soulspire_job_specs')
-----------------------------------
xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.overlords = xi.soulspire
xi.soulspire.weaponConfig = xi.soulspire.weaponConfig or {}

local WC = xi.soulspire.weaponConfig

WC.RESULT =
{
    DENY             = -1,
    VANILLA          = 0,
    ALLOW_DUAL_WIELD = 1,
    ALLOW_SUB_NON_DW = 2,
}

WC.MODE =
{
    VANILLA        = 'vanilla',
    DUAL_1H        = 'dual_1h',
    TWOHAND_SHIELD = 'twohand_shield',
    DUAL_2H        = 'dual_2h',
}

-- Registry keyed by [jobId][normalizedSpecKey] = configTable
WC.registry = WC.registry or {}

-- Reusable client/server visual override profiles (retail 1H model IDs so dual 2H
-- plays smooth 1H dual-wield animations while mechanically remaining 2H weapons).
WC.VISUAL_PROFILES =
{
    compact_dual_axe =
    {
        mainModel = 84, -- Retail 1H Axe model (Viking Axe / Darksteel Axe)
        subModel  = 84,
    },
}

local SKILL_TO_CATEGORY = {}
local ONE_HANDED_CATEGORIES =
{
    dagger = true,
    sword  = true,
    axe    = true,
    katana = true,
    club   = true,
}

local TWO_HANDED_CATEGORIES =
{
    great_sword  = true,
    great_axe    = true,
    scythe       = true,
    polearm      = true,
    great_katana = true,
    staff        = true,
}

local function initSkillMap()
    local sk = xi.skill or {}
    local map =
    {
        { sk.HAND_TO_HAND or 1,  'h2h' },
        { sk.DAGGER or 2,        'dagger' },
        { sk.SWORD or 3,         'sword' },
        { sk.GREAT_SWORD or 4,   'great_sword' },
        { sk.AXE or 5,           'axe' },
        { sk.GREAT_AXE or 6,     'great_axe' },
        { sk.SCYTHE or 7,        'scythe' },
        { sk.POLEARM or 8,       'polearm' },
        { sk.KATANA or 9,        'katana' },
        { sk.GREAT_KATANA or 10, 'great_katana' },
        { sk.CLUB or 11,         'club' },
        { sk.STAFF or 12,        'staff' },
    }
    for _, pair in ipairs(map) do
        SKILL_TO_CATEGORY[pair[1]] = pair[2]
    end
end

initSkillMap()

local function normalizeKey(v)
    if v == nil then
        return nil
    end
    return string.lower(tostring(v))
end

local function normalizeSet(listOrVal)
    if listOrVal == nil then
        return nil
    end
    local set = {}
    if type(listOrVal) == 'table' then
        for k, v in pairs(listOrVal) do
            if type(k) == 'number' then
                local nv = normalizeKey(v)
                if nv ~= nil then
                    set[nv] = true
                end
            elseif v then
                local nk = normalizeKey(k)
                if nk ~= nil then
                    set[nk] = true
                end
            end
        end
    else
        local nv = normalizeKey(listOrVal)
        if nv ~= nil then
            set[nv] = true
        end
    end
    return set
end

local function normalizeIdSet(listOrVal)
    if listOrVal == nil then
        return nil
    end
    local set = {}
    if type(listOrVal) == 'table' then
        for k, v in pairs(listOrVal) do
            if type(k) == 'number' and type(v) == 'number' then
                set[v] = true
            elseif type(k) == 'number' and v == true then
                set[k] = true
            end
        end
    elseif type(listOrVal) == 'number' then
        set[listOrVal] = true
    end
    return set
end

function WC.isOneHandedCategory(cat)
    return cat ~= nil and ONE_HANDED_CATEGORIES[cat] == true
end

function WC.isTwoHandedCategory(cat)
    return cat ~= nil and TWO_HANDED_CATEGORIES[cat] == true
end

-- Classifies a CLuaItem into { kind, category, itemId, skillType, isTwoHanded, isShield, shieldSize }.
function WC.classifyItem(item)
    if item == nil then
        return { kind = 'none', category = 'none', itemId = 0, isTwoHanded = false, isShield = false, shieldSize = 0 }
    end

    local itemId = (item.getID and item:getID()) or 0

    if item.isShield and item:isShield() then
        local sz = (item.getShieldSize and item:getShieldSize()) or 0
        return
        {
            kind        = 'shield',
            category    = 'shield',
            itemId      = itemId,
            skillType   = 0,
            isTwoHanded = false,
            isShield    = true,
            shieldSize  = sz,
        }
    end

    local weaponType = (xi.itemType and xi.itemType.WEAPON) or 0x10
    local isWeapon = item.isType and item:isType(weaponType) or false
    if isWeapon then
        local skillType = (item.getSkillType and item:getSkillType()) or 0
        local noneSkill = (xi.skill and xi.skill.NONE) or 0
        if skillType == noneSkill then
            return
            {
                kind        = 'grip',
                category    = 'grip',
                itemId      = itemId,
                skillType   = skillType,
                isTwoHanded = false,
                isShield    = false,
                shieldSize  = 0,
            }
        end

        local cat = SKILL_TO_CATEGORY[skillType] or 'other_weapon'
        local is2H = (item.isTwoHanded and item:isTwoHanded()) or TWO_HANDED_CATEGORIES[cat] == true
        return
        {
            kind        = 'weapon',
            category    = cat,
            itemId      = itemId,
            skillType   = skillType,
            isTwoHanded = is2H,
            isShield    = false,
            shieldSize  = 0,
        }
    end

    return
    {
        kind        = 'other',
        category    = 'other',
        itemId      = itemId,
        skillType   = 0,
        isTwoHanded = false,
        isShield    = false,
        shieldSize  = 0,
    }
end

local function compilePairing(raw)
    if type(raw) ~= 'table' then
        return nil
    end

    local mode = normalizeKey(raw.mode) or WC.MODE.DUAL_1H
    return
    {
        main          = normalizeSet(raw.main),
        sub           = normalizeSet(raw.sub),
        mode          = mode,
        minLevel      = tonumber(raw.minLevel) or nil,
        subShieldSize = raw.subShieldSize,
        mainItemIds   = normalizeIdSet(raw.mainItemIds),
        subItemIds    = normalizeIdSet(raw.subItemIds),
        enabled       = raw.enabled,
        visualProfile = normalizeKey(raw.visualProfile),
    }
end

local function compileConfig(raw)
    if type(raw) ~= 'table' then
        return nil
    end

    local topMode = normalizeKey(raw.mode)
    local pairings = {}
    for _, p in ipairs(raw.pairings or {}) do
        local cp = compilePairing(p)
        if cp ~= nil then
            if cp.visualProfile == nil then
                cp.visualProfile = normalizeKey(raw.visualProfile)
            end
            table.insert(pairings, cp)
        end
    end

    -- Allow declarative top-level mode + mainWhitelist/subWhitelist without duplicating pairings.
    if #pairings == 0 and topMode ~= nil and topMode ~= WC.MODE.VANILLA and raw.mainWhitelist ~= nil and raw.subWhitelist ~= nil then
        local synthesized = compilePairing(
        {
            main          = raw.mainWhitelist,
            sub           = raw.subWhitelist,
            mode          = topMode,
            minLevel      = raw.minLevel,
            subShieldSize = raw.subShieldSize,
            enabled       = raw.enabled ~= false,
            visualProfile = raw.visualProfile,
        })
        if synthesized ~= nil then
            table.insert(pairings, synthesized)
        end
    end

    return
    {
        mode                            = topMode or WC.MODE.VANILLA,
        minLevel                        = tonumber(raw.minLevel) or nil,
        mainWhitelist                   = normalizeSet(raw.mainWhitelist),
        subWhitelist                    = normalizeSet(raw.subWhitelist),
        subShieldSize                   = raw.subShieldSize,
        pairings                        = pairings,
        restrictSoulDualWieldToPairings = raw.restrictSoulDualWieldToPairings ~= false,
        allowVanillaShield              = raw.allowVanillaShield ~= false,
        allowAdvancedModes              = raw.allowAdvancedModes == true,
        visualProfile                   = normalizeKey(raw.visualProfile),
        combat                          = type(raw.combat) == 'table' and raw.combat or {},
    }
end

function WC.register(jobId, specKey, config)
    if jobId == nil or specKey == nil or type(config) ~= 'table' then
        return nil
    end

    local key = normalizeKey(specKey)
    if key == nil then
        return nil
    end

    WC.registry[jobId] = WC.registry[jobId] or {}
    local compiled = compileConfig(config)
    WC.registry[jobId][key] = compiled
    return compiled
end

function WC.getConfigForSpec(jobId, specEntry)
    if jobId == nil or specEntry == nil then
        return nil
    end

    local key = normalizeKey(specEntry.key)
    if key ~= nil and WC.registry[jobId] ~= nil and WC.registry[jobId][key] ~= nil then
        return WC.registry[jobId][key]
    end

    if type(specEntry.weaponConfig) == 'table' then
        if specEntry._compiledWeaponConfig == nil then
            specEntry._compiledWeaponConfig = compileConfig(specEntry.weaponConfig)
        end
        return specEntry._compiledWeaponConfig
    end

    return nil
end

function WC.getActiveConfig(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return nil, nil, 0
    end

    local spec = xi.soulspire and xi.soulspire.spec
    if spec == nil or spec.get == nil then
        return nil, nil, 0
    end

    local jobId = player.getMainJob and player:getMainJob() or 0
    local lvl   = player.getMainLvl and player:getMainLvl() or 1
    if jobId <= 0 then
        return nil, nil, lvl
    end

    local active = spec.get(player, jobId)
    if active == nil then
        return nil, nil, lvl
    end

    if spec.isLevelEligible and not spec.isLevelEligible(player, jobId, active) then
        return nil, nil, lvl
    end

    local cfg = WC.getConfigForSpec(jobId, active)
    if cfg == nil then
        return nil, active, lvl
    end

    local reqLvl = cfg.minLevel or (spec.getRequiredLevel and spec.getRequiredLevel(active)) or 10
    if lvl < reqLvl then
        return nil, active, lvl
    end

    return cfg, active, lvl
end

-- Returns true if the character has vanilla/native Dual Wield from their main
-- job or subjob independent of Soul-granted Dual Wield.
function WC.hasNativeDualWield(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    local job = xi.job or {}
    local mjob = player.getMainJob and player:getMainJob() or 0
    local mlvl = player.getMainLvl and player:getMainLvl() or 0
    local sjob = player.getSubJob and player:getSubJob() or 0
    local slvl = player.getSubLvl and player:getSubLvl() or 0

    local NIN = job.NIN or 13
    local DNC = job.DNC or 19
    local THF = job.THF or 6

    if (mjob == NIN and mlvl >= 10) or (sjob == NIN and slvl >= 10) then
        return true
    end
    if (mjob == DNC and mlvl >= 20) or (sjob == DNC and slvl >= 20) then
        return true
    end
    if mjob == THF and mlvl >= 83 then
        return true
    end

    return false
end

local function matchesCategory(info, catSet, shieldSizeRule)
    if catSet == nil then
        return false
    end

    if info.isShield then
        if catSet.buckler and info.shieldSize == 1 then
            return true
        end
        if catSet.shield then
            if type(shieldSizeRule) == 'table' then
                if shieldSizeRule.exact ~= nil and info.shieldSize ~= shieldSizeRule.exact then
                    return false
                end
                if shieldSizeRule.max ~= nil and info.shieldSize > shieldSizeRule.max then
                    return false
                end
                if shieldSizeRule.min ~= nil and info.shieldSize < shieldSizeRule.min then
                    return false
                end
            end
            return true
        end
        return false
    end

    return catSet[info.category] == true
end

local function pairingMatches(pairing, cfg, lvl, mainInfo, subInfo)
    local reqLvl = pairing.minLevel or cfg.minLevel or 10
    if lvl < reqLvl then
        return false
    end

    -- Phase 5 advanced modes stay inert unless explicitly enabled on the rule/config.
    if pairing.mode == WC.MODE.DUAL_2H or pairing.mode == WC.MODE.TWOHAND_SHIELD then
        if pairing.enabled ~= true and cfg.allowAdvancedModes ~= true then
            return false
        end
    end

    if pairing.mainItemIds ~= nil and not pairing.mainItemIds[mainInfo.itemId] then
        return false
    end
    if pairing.subItemIds ~= nil and not pairing.subItemIds[subInfo.itemId] then
        return false
    end

    if not matchesCategory(mainInfo, pairing.main, nil) then
        return false
    end
    if not matchesCategory(subInfo, pairing.sub, pairing.subShieldSize) then
        return false
    end

    if pairing.mode == WC.MODE.DUAL_1H then
        return mainInfo.kind == 'weapon' and not mainInfo.isTwoHanded and
            subInfo.kind == 'weapon' and not subInfo.isTwoHanded
    elseif pairing.mode == WC.MODE.TWOHAND_SHIELD then
        return mainInfo.kind == 'weapon' and mainInfo.isTwoHanded and subInfo.isShield
    elseif pairing.mode == WC.MODE.DUAL_2H then
        return mainInfo.kind == 'weapon' and mainInfo.isTwoHanded and
            subInfo.kind == 'weapon' and subInfo.isTwoHanded
    end

    return true
end

-- Core authoritative evaluator queried by C++ (EquipItem, EquipArmor, CheckValidEquipment).
-- Returns:
--   WC.RESULT.VANILLA          (0)
--   WC.RESULT.ALLOW_DUAL_WIELD (1)
--   WC.RESULT.ALLOW_SUB_NON_DW (2)
--   WC.RESULT.DENY            (-1)
function WC.evaluatePair(player, mainItem, subItem)
    local cfg, _active, lvl = WC.getActiveConfig(player)
    if cfg == nil then
        return WC.RESULT.VANILLA
    end

    local mainInfo = WC.classifyItem(mainItem)
    local subInfo  = WC.classifyItem(subItem)

    -- Empty sub slot is always fine; defer to vanilla.
    if subInfo.kind == 'none' then
        return WC.RESULT.VANILLA
    end

    -- Optional explicit main/sub whitelists.
    if cfg.mainWhitelist ~= nil and mainInfo.kind == 'weapon' and not matchesCategory(mainInfo, cfg.mainWhitelist, nil) then
        if subInfo.kind == 'weapon' and not WC.hasNativeDualWield(player) then
            return WC.RESULT.DENY
        end
    end

    if cfg.subWhitelist ~= nil and not matchesCategory(subInfo, cfg.subWhitelist, nil) then
        if subInfo.kind == 'weapon' and not WC.hasNativeDualWield(player) then
            return WC.RESULT.DENY
        end
    end

    -- Check explicit Soul weapon pairings first.
    for _, pairing in ipairs(cfg.pairings) do
        if pairingMatches(pairing, cfg, lvl, mainInfo, subInfo) then
            if pairing.mode == WC.MODE.DUAL_1H or pairing.mode == WC.MODE.DUAL_2H then
                return WC.RESULT.ALLOW_DUAL_WIELD
            elseif pairing.mode == WC.MODE.TWOHAND_SHIELD then
                return WC.RESULT.ALLOW_SUB_NON_DW
            else
                return WC.RESULT.VANILLA
            end
        end
    end

    -- Vanilla grips with 2H weapons and vanilla shields with 1H/unarmed remain allowed unless disallowed.
    if subInfo.kind == 'grip' then
        return WC.RESULT.VANILLA
    end
    if subInfo.isShield then
        if cfg.allowVanillaShield and not mainInfo.isTwoHanded then
            return WC.RESULT.VANILLA
        end
        return WC.RESULT.VANILLA
    end

    -- Offhand weapon did NOT match any configured Soul pairing.
    if subInfo.kind == 'weapon' then
        if cfg.restrictSoulDualWieldToPairings and not WC.hasNativeDualWield(player) then
            return WC.RESULT.DENY
        end
    end

    return WC.RESULT.VANILLA
end

-- Returns (pairing, cfg, lvl) when (mainItem, subItem) matches an active Soul weapon pairing.
function WC.getActivePairing(player, mainItem, subItem)
    local cfg, _active, lvl = WC.getActiveConfig(player)
    if cfg == nil then
        return nil, nil, lvl
    end

    if mainItem == nil and player.getEquippedItem then
        mainItem = player:getEquippedItem(xi.slot.MAIN)
    end
    if subItem == nil and player.getEquippedItem then
        subItem = player:getEquippedItem(xi.slot.SUB)
    end

    local mainInfo = WC.classifyItem(mainItem)
    local subInfo  = WC.classifyItem(subItem)
    if subInfo.kind == 'none' then
        return nil, cfg, lvl
    end

    for _, pairing in ipairs(cfg.pairings) do
        if pairingMatches(pairing, cfg, lvl, mainInfo, subInfo) then
            return pairing, cfg, lvl
        end
    end

    return nil, cfg, lvl
end

-- Syncs a lightweight local var flag so C++ combat hotpaths skip Lua when no Soul
-- weapon combat scaling profile is active.
function WC.syncCombatFlag(player)
    if player == nil or (player.isPC and not player:isPC()) or not player.setLocalVar then
        return false
    end

    local cfg = WC.getActiveConfig(player)
    local hasCombatScaling = false
    if cfg ~= nil and type(cfg.combat) == 'table' then
        local c = cfg.combat
        if (c.mainDamageScale ~= nil and c.mainDamageScale ~= 1.0) or
            (c.subDamageScale ~= nil and c.subDamageScale ~= 1.0) or
            (c.delayScale ~= nil and c.delayScale ~= 1.0) or
            (c.tpScale ~= nil and c.tpScale ~= 1.0) or
            c.multiAttackPolicy == 'main_only' or
            (c.twoHandedStatScale ~= nil and c.twoHandedStatScale ~= 1.0) or
            (c.shieldBlockScale ~= nil and c.shieldBlockScale ~= 1.0) then
            hasCombatScaling = true
        end
    end

    player:setLocalVar('OX_WEAPON_CFG_ACTIVE', hasCombatScaling and 1 or 0)
    return hasCombatScaling
end

-- Returns combat scaling parameters for C++ hooks (CAttack, CAttackRound, GetWeaponDelay, CalculateBaseTP)
-- ONLY when an active Soul pairing with combat modifiers is currently equipped.
function WC.getCombatProfile(player)
    local pairing, cfg = WC.getActivePairing(player)
    if pairing == nil or cfg == nil or type(cfg.combat) ~= 'table' then
        return nil
    end

    local c = cfg.combat
    if pairing.mode == WC.MODE.DUAL_2H then
        return
        {
            active            = true,
            mode              = pairing.mode,
            mainDamageScale   = tonumber(c.mainDamageScale) or 1.0,
            subDamageScale    = tonumber(c.subDamageScale) or 1.0,
            delayScale        = tonumber(c.delayScale) or 1.0,
            tpScale           = tonumber(c.tpScale) or 1.0,
            subMultiAttackOff = (c.multiAttackPolicy == 'main_only'),
            wsUsesMainOnly    = (c.wsUsesMainOnly ~= false),
        }
    elseif pairing.mode == WC.MODE.TWOHAND_SHIELD then
        local statScale = tonumber(c.twoHandedStatScale) or 1.0
        local blockScale = tonumber(c.shieldBlockScale) or 1.0
        if statScale == 1.0 and blockScale == 1.0 then
            return nil
        end
        return
        {
            active            = true,
            mode              = pairing.mode,
            mainDamageScale   = statScale,
            subDamageScale    = 1.0,
            delayScale        = 1.0,
            tpScale           = 1.0,
            subMultiAttackOff = false,
            wsUsesMainOnly    = true,
            shieldBlockScale  = blockScale,
        }
    end

    return nil
end

-- Returns (mainModel, subModel) override when the active Soul pairing specifies a visualProfile.
-- Returns (0, 0) when standard retail item models should be used.
function WC.getVisualModels(player)
    local pairing, cfg = WC.getActivePairing(player)
    if pairing == nil or cfg == nil then
        return 0, 0
    end

    local profileName = pairing.visualProfile or cfg.visualProfile
    if profileName == nil then
        return 0, 0
    end

    local profile = WC.VISUAL_PROFILES[profileName]
    if profile == nil then
        return 0, 0
    end

    return tonumber(profile.mainModel) or 0, tonumber(profile.subModel) or 0
end

-- Reconciles currently equipped items against active Soul weapon rules and traits.
-- Safely unequips invalid offhand gear without deleting or modifying inventory.
function WC.reconcileEquipment(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return false
    end

    WC.syncCombatFlag(player)

    local subBefore = player.getEquippedItem and player:getEquippedItem(xi.slot.SUB) or nil

    -- Prefer C++ CheckValidEquipment when patch 0073 is compiled in.
    if player.checkValidEquipment then
        player:checkValidEquipment()
    end

    -- Safe Lua fallback / double-check (handles unpatched map binaries and Soul-swap timing).
    local mainItem = player.getEquippedItem and player:getEquippedItem(xi.slot.MAIN) or nil
    local subItem  = player.getEquippedItem and player:getEquippedItem(xi.slot.SUB) or nil
    if subItem ~= nil then
        local subInfo  = WC.classifyItem(subItem)
        local mainInfo = WC.classifyItem(mainItem)
        if subInfo.kind == 'weapon' then
            local decision = WC.evaluatePair(player, mainItem, subItem)
            local dwTrait  = (xi.trait and xi.trait.DUAL_WIELD) or 18
            local hasDW    = player.hasTrait and player:hasTrait(dwTrait) or false

            local invalid = false
            if decision == WC.RESULT.DENY then
                invalid = true
            elseif decision == WC.RESULT.VANILLA then
                if mainItem == nil or mainInfo.isTwoHanded or subInfo.isTwoHanded or not hasDW then
                    invalid = true
                end
            end

            if invalid and player.unequipItem then
                player:unequipItem(xi.slot.SUB)
            end
        elseif subInfo.isShield and mainInfo.isTwoHanded then
            local decision = WC.evaluatePair(player, mainItem, subItem)
            if decision ~= WC.RESULT.ALLOW_SUB_NON_DW then
                local legacyPolearmBuckler = player.getMainJob and player:getMainJob() == (xi.job and xi.job.WAR or 1) and
                    player.getLocalVar and player:getLocalVar('OX_POLEARM_BUCKLER') == 1 and
                    mainInfo.category == 'polearm' and subInfo.shieldSize == 1
                if not legacyPolearmBuckler and player.unequipItem then
                    player:unequipItem(xi.slot.SUB)
                end
            end
        end
    end

    local subAfter = player.getEquippedItem and player:getEquippedItem(xi.slot.SUB) or nil
    return (subBefore ~= nil and subAfter == nil)
end

-----------------------------------
-- Template 1 Reference (dual_1h): BRD Adventurer (Dagger / Sword Dual Wield)
-----------------------------------
if xi.job and xi.job.BRD then
    WC.register(xi.job.BRD, 'adventurer',
    {
        mode     = WC.MODE.DUAL_1H,
        minLevel = 10,
        pairings =
        {
            {
                main = { 'dagger', 'sword' },
                sub  = { 'dagger', 'sword' },
                mode = WC.MODE.DUAL_1H,
            },
        },
        restrictSoulDualWieldToPairings = true,
        allowVanillaShield              = true,
    })
end

-----------------------------------
-- Template 2 Prototype (dual_2h): WAR Berserker (Twin Executioner Axes)
-----------------------------------
if xi.job and xi.job.WAR then
    WC.register(xi.job.WAR, 'berserker',
    {
        mode               = WC.MODE.DUAL_2H,
        minLevel           = 10,
        allowAdvancedModes = true,
        mainWhitelist      = { 'great_axe' },
        subWhitelist       = { 'great_axe' },
        pairings           =
        {
            {
                main          = { 'great_axe' },
                sub           = { 'great_axe' },
                mode          = WC.MODE.DUAL_2H,
                enabled       = true,
                visualProfile = 'compact_dual_axe',
            },
        },
        restrictSoulDualWieldToPairings = true,
        allowVanillaShield              = true,
        visualProfile                   = 'compact_dual_axe',
        combat                          =
        {
            mainDamageScale   = 0.72,
            subDamageScale    = 0.52,
            delayScale        = 0.58,
            tpScale           = 0.85,
            multiAttackPolicy = 'main_only',
            wsUsesMainOnly    = true,
        },
    })
end

return WC
