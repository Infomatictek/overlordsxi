-----------------------------------
-- OverlordsXI Real-Lua Wiki Data Exporter
-- Executes the actual Lua modules in a lightweight LandSandBoat sandbox
-- and emits a single JSON document to stdout.
--
-- Compatible with Lua 5.1 / 5.2 / 5.3 / 5.4 / LuaJIT.
-----------------------------------

local ROOT_DIR = arg and arg[1] or '.'

-- Pure-Lua bitwise shim if global `bit` (LuaJIT) is unavailable
if _G.bit == nil then
    local bit = {}
    function bit.lshift(a, n)
        return math.floor(a * (2 ^ n))
    end
    function bit.rshift(a, n)
        return math.floor(a / (2 ^ n))
    end
    function bit.band(a, b)
        local res, p = 0, 1
        while a > 0 and b > 0 do
            local ra, rb = a % 2, b % 2
            if ra == 1 and rb == 1 then res = res + p end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            p = p * 2
        end
        return res
    end
    function bit.bor(a, b)
        local res, p = 0, 1
        while a > 0 or b > 0 do
            local ra, rb = a % 2, b % 2
            if ra == 1 or rb == 1 then res = res + p end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            p = p * 2
        end
        return res
    end
    _G.bit = bit
end

-- Minimal JSON encoder (zero external dependencies)
local function jsonEscape(str)
    str = tostring(str or '')
    str = str:gsub('\\', '\\\\')
             :gsub('"', '\\"')
             :gsub('\b', '\\b')
             :gsub('\f', '\\f')
             :gsub('\n', '\\n')
             :gsub('\r', '\\r')
             :gsub('\t', '\\t')
    return '"' .. str .. '"'
end

local function isArray(tbl)
    if type(tbl) ~= 'table' then return false end
    local count = 0
    local maxIdx = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= 'number' or k < 1 or math.floor(k) ~= k then
            return false
        end
        count = count + 1
        if k > maxIdx then maxIdx = k end
    end
    return count > 0 and maxIdx == count
end

local function encodeJson(val)
    local t = type(val)
    if val == nil then
        return 'null'
    elseif t == 'boolean' then
        return val and 'true' or 'false'
    elseif t == 'number' then
        if val ~= val or val == math.huge or val == -math.huge then
            return 'null'
        end
        if math.floor(val) == val and math.abs(val) < 1e15 then
            return string.format('%d', val)
        end
        return tostring(val)
    elseif t == 'string' then
        return jsonEscape(val)
    elseif t == 'table' then
        if val.__isEmptyArray then
            return '[]'
        end
        if isArray(val) then
            local parts = {}
            for i = 1, #val do
                parts[i] = encodeJson(val[i])
            end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            local keys = {}
            for k in pairs(val) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                table.insert(parts, jsonEscape(tostring(k)) .. ':' .. encodeJson(val[k]))
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    end
    return 'null'
end

local function emptyArray()
    return { __isEmptyArray = true }
end

-- Auto-vivifying enum builder with reverse lookup
local nextAutoId = 50000
local function makeEnumTable(preset, reverseMap)
    local tbl = {}
    if preset then
        for k, v in pairs(preset) do
            tbl[k] = v
            if reverseMap then reverseMap[v] = k end
        end
    end
    return setmetatable(tbl, {
        __index = function(self, key)
            nextAutoId = nextAutoId + 1
            local id = nextAutoId
            rawset(self, key, id)
            if reverseMap then reverseMap[id] = tostring(key) end
            return id
        end
    })
end

local function makeEnumNamespace()
    return setmetatable({}, {
        __index = function(self, key)
            local sub = makeEnumTable({})
            rawset(self, key, sub)
            return sub
        end,
    })
end

local function makeTableProxy()
    local mt
    mt = {
        __index = function(self, key)
            local sub = setmetatable({}, mt)
            rawset(self, key, sub)
            return sub
        end,
        __call = function() return 0 end,
    }
    return setmetatable({}, mt)
end

-- Global LandSandBoat sandbox stubs
_G.xi = {}
_G.utils = {
    clamp = function(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end,
}

local MOD_NAMES = {}
xi.mod = makeEnumTable({}, MOD_NAMES)

xi.job = makeEnumTable({
    NONE = 0, WAR = 1, MNK = 2, WHM = 3, BLM = 4, RDM = 5, THF = 6,
    PLD = 7, DRK = 8, BST = 9, BRD = 10, RNG = 11, SAM = 12, NIN = 13,
    DRG = 14, SMN = 15, BLU = 16, COR = 17, PUP = 18, DNC = 19, SCH = 20,
    GEO = 21, RUN = 22,
})

xi.skill = makeEnumTable({
    NONE = 0, HAND_TO_HAND = 1, DAGGER = 2, SWORD = 3, GREAT_SWORD = 4,
    AXE = 5, GREAT_AXE = 6, SCYTHE = 7, POLEARM = 8, KATANA = 9,
    GREAT_KATANA = 10, CLUB = 11, STAFF = 12, ARCHERY = 25,
    MARKSMANSHIP = 26, THROWING = 27,
})

local JOB_NAMES_FULL = {
    [1] = 'Warrior', [2] = 'Monk', [3] = 'White Mage', [4] = 'Black Mage',
    [5] = 'Red Mage', [6] = 'Thief', [7] = 'Paladin', [8] = 'Dark Knight',
    [9] = 'Beastmaster', [10] = 'Bard', [11] = 'Ranger', [12] = 'Samurai',
    [13] = 'Ninja', [14] = 'Dragoon', [15] = 'Summoner', [16] = 'Blue Mage',
    [17] = 'Corsair', [18] = 'Puppetmaster', [19] = 'Dancer', [20] = 'Scholar',
    [21] = 'Geomancer', [22] = 'Rune Fencer',
}

local JOB_COLORS = {
    WAR = '#ef4444', MNK = '#f97316', WHM = '#f8fafc', BLM = '#a855f7',
    RDM = '#ec4899', THF = '#eab308', PLD = '#fde047', DRK = '#dc2626',
    BST = '#84cc16', BRD = '#38bdf8', RNG = '#22c55e', SAM = '#fb923c',
    NIN = '#f43f5e', DRG = '#6366f1', SMN = '#10b981', BLU = '#3b82f6',
    COR = '#f59e0b', PUP = '#d946ef', DNC = '#f472b6', SCH = '#14b8a6',
    GEO = '#2dd4bf', RUN = '#06b6d4',
}

xi.effect       = makeEnumTable({})
xi.element      = makeEnumTable({ NONE = 0, FIRE = 1, ICE = 2, WIND = 3, EARTH = 4, THUNDER = 5, WATER = 6, LIGHT = 7, DARK = 8 })
xi.slot         = makeEnumTable({ MAIN = 0, SUB = 1, RANGED = 2, AMMO = 3, HEAD = 4, BODY = 5, HANDS = 6, LEGS = 7, FEET = 8, NECK = 9, WAIST = 10, EAR1 = 11, EAR2 = 12, RING1 = 13, RING2 = 14, BACK = 15 })
xi.inv          = makeEnumTable({ INVENTORY = 0, MOGSAFE = 1, STORAGE = 2, TEMPITEMS = 3, MOGLOCKER = 4, MOGSATCHEL = 5, MOGSACK = 6, MOGCASE = 7, WARDROBE = 8, MOGSAFE2 = 9, WARDROBE2 = 10, WARDROBE3 = 11, WARDROBE4 = 12, WARDROBE5 = 13, WARDROBE6 = 14, WARDROBE7 = 15, WARDROBE8 = 16 })
xi.jobAbility   = makeEnumTable({ WARCRY = 2, COUNTERSTANCE = 61, SWIPE = 344, SWORDPLAY = 367, LUNGE = 368, PFLUG = 369, VALIANCE = 371, GAMBIT = 372, LIEMENT = 373, ONE_FOR_ALL = 374, RAYKE = 375, BATTUTA = 376, VIVACIOUS_PULSE = 383 })
xi.weaponskill  = makeEnumTable({})
xi.item         = makeEnumTable({})
xi.keyItem      = makeEnumTable({})
xi.petId        = makeEnumTable({})
xi.trait        = makeEnumTable({ DUAL_WIELD = 18, DOUBLE_ATTACK = 19, TRIPLE_ATTACK = 20, SUBTLE_BLOW = 38, COUNTER = 39, KICK_ATTACKS = 40 })
xi.skillRank    = makeEnumTable({})
xi.attackType   = makeEnumTable({})
xi.damageType   = makeEnumTable({})
xi.mobMod       = makeEnumTable({})
xi.objType      = makeEnumTable({})
xi.subEffect    = makeEnumTable({})
xi.zoneMisc     = makeEnumTable({})
xi.aftermath    = makeEnumTable({})
xi.msg          = makeEnumNamespace()
xi.magic        = makeEnumNamespace()
xi.combat       = makeTableProxy()
xi.job_utils    = makeTableProxy()
xi.actions      = makeTableProxy()
xi.effects      = makeTableProxy()
xi.player       = makeTableProxy()
xi.mob          = makeTableProxy()
xi.mobskills    = makeTableProxy()
xi.pet          = makeTableProxy()
xi.shop         = makeTableProxy()
xi.experiencePoints = makeTableProxy()
xi.weaponskills = makeTableProxy()
xi.data         = makeTableProxy()
xi.settings     = makeTableProxy()
xi.zones        = makeTableProxy()
xi.jp           = makeEnumTable({})
xi.merit        = makeEnumTable({})
xi.server       = makeTableProxy()

_G.Module = {
    new = function(_, name)
        return {
            name = name,
            addOverride = function() end,
        }
    end,
}

_G.GetSystemTime = function() return 0 end
_G.GetMobByID = function() return nil end

-- Custom require interceptor: loads real modules/custom/* files, mocks upstream LSB files
local loadedModules = {}
local origRequire = _G.require
_G.require = function(modName)
    if loadedModules[modName] ~= nil then
        return loadedModules[modName]
    end
    if modName:match('^modules/custom/') then
        local filePath = ROOT_DIR .. '/' .. modName .. '.lua'
        local f = io.open(filePath, 'r')
        if f then
            f:close()
            local chunk, err = loadfile(filePath)
            if not chunk then
                io.stderr:write('ERROR loading ' .. filePath .. ': ' .. tostring(err) .. '\n')
                os.exit(1)
            end
            local res = chunk()
            if res == nil then res = true end
            loadedModules[modName] = res
            return res
        end
    end
    -- Mock upstream LandSandBoat scripts/* or modules/module_utils
    local stub = {}
    loadedModules[modName] = stub
    return stub
end

-- Discover files via command-line arguments:
-- arg[1] = ROOT_DIR
-- arg[2..] = list of *_specs.lua and overlords_ws_trees_*.lua files
local specFiles = {}
local treeFiles = {}
for i = 2, #(arg or {}) do
    local p = arg[i]
    if p:match('_specs$') or p:match('_specs%.lua$') then
        table.insert(specFiles, p)
    elseif p:match('overlords_ws_trees_') then
        table.insert(treeFiles, p)
    end
end

-- 1. Load Job Crystal / Spec Registry + ALL *_specs.lua
local spec = require('modules/custom/lua/overlords_job_specs')
for _, sf in ipairs(specFiles) do
    local ok, err = pcall(require, sf)
    if not ok then
        io.stderr:write('ERROR loading spec module ' .. tostring(sf) .. ': ' .. tostring(err) .. '\n')
        os.exit(1)
    end
end

-- 2. Load Weaponskill Catalog + Talent Engine + ALL tree files
local catalog = require('modules/custom/lua/overlords_ws_catalog')
local talents = require('modules/custom/lua/overlords_ws_talents')
for _, tf in ipairs(treeFiles) do
    local ok, err = pcall(require, tf)
    if not ok then
        io.stderr:write('ERROR loading tree module ' .. tostring(tf) .. ': ' .. tostring(err) .. '\n')
        os.exit(1)
    end
end

-- 3. Load Combat & EXP Rules module
pcall(require, 'modules/custom/lua/boss_like_combat_and_exp')

-- Fake player stub to evaluate crystal mods(player, lvl) & extraAbilities(player, lvl)
-- Intentionally omits getEquipID so `isWiki = (player == nil) or (not player.getEquipID)` evaluates true.
local function makeMockItem(skillType, isShieldFlag)
    return {
        getSkillType = function() return skillType or 0 end,
        isShield = function() return isShieldFlag == true end,
        getID = function() return 0 end,
    }
end

local function makeFakePlayer(jobId, lvl)
    return {
        getMainJob = function() return jobId end,
        getMainLvl = function() return lvl end,
        getJobLevel = function(_, j) return (j == jobId) and lvl or 1 end,
        getID = function() return 1 end,
        isPC = function() return true end,
        isUsingH2H = function() return jobId == xi.job.PUP or jobId == xi.job.MNK end,
        getMod = function() return 0 end,
        getStat = function() return 50 end,
        hasPet = function() return false end,
        getPet = function() return nil end,
        hasStatusEffect = function() return false end,
        getCharVar = function() return 0 end,
        getLocalVar = function() return 0 end,
        setLocalVar = function() end,
        getWeaponSkillType = function(_, slot)
            if slot == xi.slot.RANGED then
                if jobId == xi.job.COR then return xi.skill.MARKSMANSHIP end
                if jobId == xi.job.RNG then return xi.skill.ARCHERY end
                if jobId == xi.job.DNC then return xi.skill.THROWING end
            end
            if jobId == xi.job.PUP or jobId == xi.job.MNK then return xi.skill.HAND_TO_HAND end
            if jobId == xi.job.SAM then return xi.skill.GREAT_KATANA end
            if jobId == xi.job.DRK then return xi.skill.SCYTHE end
            if jobId == xi.job.DRG then return xi.skill.POLEARM end
            if jobId == xi.job.NIN then return xi.skill.KATANA end
            return xi.skill.SWORD
        end,
        getEquippedItem = function(_, slot)
            if slot == xi.slot.RANGED then
                if jobId == xi.job.COR then return makeMockItem(xi.skill.MARKSMANSHIP, false) end
                if jobId == xi.job.RNG or jobId == xi.job.SAM then return makeMockItem(xi.skill.ARCHERY, false) end
            elseif slot == xi.slot.SUB then
                if jobId == xi.job.PLD or jobId == xi.job.WAR then return makeMockItem(0, true) end
            elseif slot == xi.slot.MAIN then
                if jobId == xi.job.PUP then return makeMockItem(xi.skill.HAND_TO_HAND, false) end
                if jobId == xi.job.SAM then return makeMockItem(xi.skill.GREAT_KATANA, false) end
                if jobId == xi.job.COR then return makeMockItem(xi.skill.SWORD, false) end
            end
            return nil
        end,
        capSkill = function() end,
    }
end

-- Export Job Specs
local jobSpecsOut = {}
local sortedJobIds = {}
for jid, _ in pairs(spec.jobs or {}) do
    table.insert(sortedJobIds, jid)
end
table.sort(sortedJobIds)

for _, jid in ipairs(sortedJobIds) do
    local j = spec.jobs[jid]
    local jKey = j.jobKey or spec.getJobKey(jid)
    local crystalsOut = {}
    for _, entry in ipairs(j.ordered or {}) do
        -- Evaluate passive mods at Lv 10, 30, 50, 70
        local modsByModName = {}
        local modOrder = {}
        if type(entry.mods) == 'function' then
            local levels = { 10, 30, 50, 75 }
            for li, lvl in ipairs(levels) do
                local ok, list = pcall(entry.mods, makeFakePlayer(jid, lvl), lvl)
                if ok and type(list) == 'table' then
                    for _, pair in ipairs(list) do
                        local modId = pair[1]
                        local val = pair[2]
                        local mName = MOD_NAMES[modId] or ('MOD_' .. tostring(modId))
                        if modsByModName[mName] == nil then
                            modsByModName[mName] = {}
                            table.insert(modOrder, mName)
                        end
                        modsByModName[mName][li] = val
                    end
                end
            end
        end

        local evaluatedMods = {}
        for _, mName in ipairs(modOrder) do
            table.insert(evaluatedMods, {
                mod = mName,
                values = modsByModName[mName], -- [lv10, lv30, lv50, lv70]
            })
        end

        -- Evaluate extraAbilities (table or function(player, lvl))
        local extraAbils = {}
        local rawAbils = entry.extraAbilities
        if type(rawAbils) == 'function' then
            local ok, res = pcall(rawAbils, makeFakePlayer(jid, 75), 75)
            if ok and type(res) == 'table' then rawAbils = res else rawAbils = {} end
        end
        if type(rawAbils) == 'table' then
            for _, aid in ipairs(rawAbils) do
                if type(aid) == 'number' then
                    table.insert(extraAbils, aid)
                end
            end
        end

        local extraTraits = {}
        local rawTraits = entry.extraTraits
        if type(rawTraits) == 'function' then
            local ok, res = pcall(rawTraits, makeFakePlayer(jid, 75), 75)
            if ok and type(res) == 'table' then rawTraits = res else rawTraits = {} end
        end
        if type(rawTraits) == 'table' then
            for _, tid in ipairs(rawTraits) do
                if type(tid) == 'number' then
                    table.insert(extraTraits, tid)
                end
            end
        end

        local highlights = {}
        for _, h in ipairs(entry.highlights or {}) do
            table.insert(highlights, tostring(h))
        end

        table.insert(crystalsOut, {
            id = tonumber(entry.id) or 1,
            key = tostring(entry.key or ''),
            name = tostring(entry.name or ''),
            role = tostring(entry.role or ''),
            icon = tostring(entry.icon or ''),
            reqLevel = tonumber(entry.reqLevel) or spec.DEFAULT_REQ_LEVEL or 10,
            description = tostring(entry.description or ''),
            highlights = #highlights > 0 and highlights or emptyArray(),
            evaluatedMods = #evaluatedMods > 0 and evaluatedMods or emptyArray(),
            extraAbilities = #extraAbils > 0 and extraAbils or emptyArray(),
            extraTraits = #extraTraits > 0 and extraTraits or emptyArray(),
        })
    end

    table.insert(jobSpecsOut, {
        jobKey = jKey,
        jobId = jid,
        jobName = JOB_NAMES_FULL[jid] or jKey,
        color = JOB_COLORS[jKey] or '#60a5fa',
        crystals = #crystalsOut > 0 and crystalsOut or emptyArray(),
    })
end

-- Export Weaponskills & Weapon-Filtered Spec Trees directly via talents.getTreeForWS
local wsOut = {}

local function serializeTreeNodes(tree, ws)
    local out = {}
    for _, node in ipairs((tree and tree.nodes) or {}) do
        local desc0 = ''
        if type(node.describe) == 'function' then
            local ok, d = pcall(node.describe, 0, ws, nil, nil)
            if ok and d ~= nil then desc0 = tostring(d) end
        end
        table.insert(out, {
            tier = tonumber(node.tier) or 1,
            col = tonumber(node.col) or 1,
            key = tostring(node.key or ''),
            name = tostring(node.name or ''),
            maxRank = tonumber(node.maxRank) or 1,
            isSkillchain = (node.scTier and node.scTier > 0) and true or nil,
            desc = desc0,
        })
    end
    return out
end

for _, wsId in ipairs(catalog.orderedIds or {}) do
    local ws = catalog.byId[wsId]
    local orig = ws.orig or {}
    local wscMap = {}
    local hasWsc = false
    for stat, wt in pairs(orig.wsc or {}) do
        wscMap[string.upper(tostring(stat))] = math.floor(wt * 100 + 0.5)
        hasWsc = true
    end

    local isThrowing = (ws.skill == xi.skill.THROWING)
    local specTrees = {}
    local sampleTree = nil
    local allowedSpecs = (talents.getAllowedSpecsForWS and talents.getAllowedSpecsForWS(wsId)) or {}

    if isThrowing then
        local t = talents.getTreeForWS(wsId, nil, nil, 'bladewheel')
        specTrees.bladewheel = serializeTreeNodes(t, ws)
        sampleTree = t
    else
        for _, sc in ipairs(allowedSpecs) do
            local t = talents.getTreeForWS(wsId, nil, nil, sc)
            specTrees[sc] = serializeTreeNodes(t, ws)
            if sampleTree == nil or sc == 'berserker' then
                sampleTree = t
            end
        end
        local genTree = talents.getTreeForWS(wsId, nil, nil, 'generic')
        specTrees.generic = serializeTreeNodes(genTree, ws)
        if sampleTree == nil then
            sampleTree = genTree
        end
    end

    local maxPts = 0
    for _, n in ipairs((sampleTree and sampleTree.nodes) or {}) do
        maxPts = maxPts + (tonumber(n.maxRank) or 0)
    end

    local ftpOut = orig.ftp or { 1.0, 1.0, 1.0 }
    local scOut = orig.skillchain or {}

    table.insert(wsOut, {
        id = ws.id,
        key = tostring(ws.key or ''),
        name = tostring(ws.name or ''),
        skillId = tonumber(ws.skill) or 0,
        skillName = tostring(ws.skillName or ''),
        wsType = tostring(ws.wsType or 'physical'),
        elementName = ws.elementName,
        isCustomThrowing = (ws.id >= 241 and ws.id <= 252) and true or false,
        isSpecAdaptive = (not isThrowing) and (#allowedSpecs > 0),
        archetype = tostring((sampleTree and sampleTree.archetype) or ws.wsType or 'heavy'),
        maxPoints = maxPts,
        orig = {
            ftp = ftpOut,
            numHits = tonumber(orig.numHits) or 1,
            wsc = hasWsc and wscMap or {},
            skillchain = #scOut > 0 and scOut or emptyArray(),
            aftermath = orig.aftermath,
            debuff = orig.debuff and orig.debuff.label or nil,
        },
        specTrees = specTrees,
    })
end

-- Extract TIER_GATES & RANK_LEVEL_TABLES dynamically from talents
local tierGatesOut = {}
for t = 1, 4 do
    local g = (talents.TIER_GATES and talents.TIER_GATES[t]) or { reqWsPoints = 0, reqLevel = 1 }
    tierGatesOut[tostring(t)] = {
        reqWsPoints = g.reqWsPoints,
        reqLevel = g.reqLevel,
    }
end

local rankLevelTablesOut = { sc = {} }
if talents.getRankReqLevel then
    for scT = 1, 4 do
        local scNode = { scTier = scT, maxRank = 2 }
        rankLevelTablesOut.sc[tostring(scT)] = {
            talents.getRankReqLevel(scNode, 1),
            talents.getRankReqLevel(scNode, 2),
        }
    end
    local shapes = {
        [1] = { 6, 7 },
        [2] = { 5 },
        [3] = { 5 },
        [4] = { 3, 5 },
    }
    for tier, mrs in pairs(shapes) do
        local tKey = tostring(tier)
        rankLevelTablesOut[tKey] = {}
        for _, mr in ipairs(mrs) do
            local arr = {}
            local dummy = { tier = tier, maxRank = mr }
            for r = 1, mr do
                arr[r] = talents.getRankReqLevel(dummy, r)
            end
            rankLevelTablesOut[tKey][tostring(mr)] = arr
        end
    end
end

-- Extract boss_like_combat_and_exp config dynamically
local bossCfg = (xi.customBossServer and xi.customBossServer.config) or {}
local function extractModList(list)
    local out = {}
    for _, item in ipairs(list or {}) do
        table.insert(out, {
            mod = MOD_NAMES[item.mod] or tostring(item.mod),
            amount = item.amount,
        })
    end
    return #out > 0 and out or emptyArray()
end

local bossOut = {
    playerCombatPace = extractModList(bossCfg.playerCombatPace),
    petCombatPace = extractModList(bossCfg.petCombatPace),
    normalMob = bossCfg.normalMob or {},
    nm = bossCfg.nm or {},
    levelGap = bossCfg.levelGap or {},
    breath = bossCfg.breath or {},
}

local payload = {
    jobSpecs = #jobSpecsOut > 0 and jobSpecsOut or emptyArray(),
    weaponskills = #wsOut > 0 and wsOut or emptyArray(),
    tierGates = tierGatesOut,
    rankLevelTables = rankLevelTablesOut,
    maxWsPoints = talents.MAX_WS_POINTS or 56,
    bossConfig = bossOut,
}

io.write(encodeJson(payload))
