-- OverlordsXI Soul Action Registry & Opt-In Observation (Sequence A foundation)
-- Pure data/validation/observation module. Does not alter live casting or client packets.
-- Source action IDs remain internal; presentation names are Soul-specific.
local M = {
    VERSION = 1,
    definitions = {},
    observationMode = 'off', -- 'off' | 'warn' (no global strict switch)
    observations = {},
    maxObservations = 500,
    onWarning = nil,
}

local validKinds = { spell = true, ability = true, weaponskill = true }
local validModes = { off = true, warn = true }

-- Canonical 22 x 3 active Soul identity table indexed by [jobId][storedBranch].
-- Matches server OX_SPEC_<JOB> numeric branches (including DNC 2/3/4 and PUP 2/3).
M.ACTIVE_BY_JOB = {
    [1] = {
        [1] = { key = 'commander', storageKey = 'commander', name = 'Commander', abr = 'CDR' },
        [2] = { key = 'berserker', storageKey = 'berserker', name = 'Berserker', abr = 'BRZ' },
        [3] = { key = 'spartan', storageKey = 'spartan', name = 'Spartan', abr = 'SPT' },
    },
    [2] = {
        [1] = { key = 'sensei', storageKey = 'sensei', name = 'Sensei', abr = 'SEN' },
        [2] = { key = 'chiweaver', storageKey = 'chiweaver', name = 'Chi Weaver', abr = 'CWV' },
        [3] = { key = 'blackbelt', storageKey = 'blackbelt', name = 'Black Belt', abr = 'BLK' },
    },
    [3] = {
        [1] = { key = 'bishop', storageKey = 'bishop', name = 'Bishop', abr = 'BSH' },
        [2] = { key = 'zealot', storageKey = 'zealot', name = 'Zealot', abr = 'ZEL' },
        [3] = { key = 'valkyrie', storageKey = 'valkyrie', name = 'Valkyrie', abr = 'VLK' },
    },
    [4] = {
        [1] = { key = 'astromancer', storageKey = 'astromancer', name = 'Astromancer', abr = 'AST' },
        [2] = { key = 'channeler', storageKey = 'channeler', name = 'Channeler', abr = 'CHN' },
        [3] = { key = 'necromancer', storageKey = 'necromancer', name = 'Necromancer', abr = 'NEC' },
    },
    [5] = {
        [1] = { key = 'crimsonduelist', storageKey = 'crimsonduelist', name = 'Crimson Duelist', abr = 'DLS' },
        [2] = { key = 'royaltactician', storageKey = 'royaltactician', name = 'Royal Tactician', abr = 'RYT' },
        [3] = { key = 'scarletweaver', storageKey = 'scarletweaver', name = 'Scarlet Weaver', abr = 'SCW' },
    },
    [6] = {
        [1] = { key = 'trickster', storageKey = 'trickster', name = 'Trickster', abr = 'TRK' },
        [2] = { key = 'bandit', storageKey = 'bandit', name = 'Bandit', abr = 'BND' },
        [3] = { key = 'phantom', storageKey = 'phantom', name = 'Phantom', abr = 'PHN' },
    },
    [7] = {
        [1] = { key = 'templar', storageKey = 'templar', name = 'Templar', abr = 'TMP' },
        [2] = { key = 'defender', storageKey = 'defender', name = 'Defender', abr = 'DFN' },
        [3] = { key = 'oathbreaker', storageKey = 'oathbreaker', name = 'Oathbreaker', abr = 'OTB' },
    },
    [8] = {
        [1] = { key = 'reaper', storageKey = 'reaper', name = 'Reaper', abr = 'RPR' },
        [2] = { key = 'dreadnought', storageKey = 'dreadnought', name = 'Dreadnought', abr = 'DRN' },
        [3] = { key = 'scourge', storageKey = 'scourge', name = 'Scourge', abr = 'SCR' },
    },
    [9] = {
        [1] = { key = 'untamed', storageKey = 'untamed', name = 'Untamed', abr = 'UNT' },
        [2] = { key = 'alphawarden', storageKey = 'alphawarden', name = 'Alpha Warden', abr = 'ALW' },
        [3] = { key = 'beastspeaker', storageKey = 'beastspeaker', name = 'Beastspeaker', abr = 'BSP' },
    },
    [10] = {
        [1] = { key = 'adventurer', storageKey = 'adventurer', name = 'Adventurer', abr = 'ADV' },
        [2] = { key = 'musician', storageKey = 'musician', name = 'Musician', abr = 'MUS' },
        [3] = { key = 'minstrel', storageKey = 'minstrel', name = 'Minstrel', abr = 'MIN' },
    },
    [11] = {
        [1] = { key = 'sniper', storageKey = 'sniper', name = 'Sniper', abr = 'SNP' },
        [2] = { key = 'huntsman', storageKey = 'huntsman', name = 'Huntsman', abr = 'HNT' },
        [3] = { key = 'arcanearcher', storageKey = 'arcanearcher', name = 'Arcane Archer', abr = 'ACA' },
    },
    [12] = {
        [1] = { key = 'ronin', storageKey = 'ronin', name = 'Ronin', abr = 'RON' },
        [2] = { key = 'imperialarcher', storageKey = 'imperialarcher', name = 'Imperial Archer', abr = 'IMP' },
        [3] = { key = 'warlord', storageKey = 'warlord', name = 'Warlord', abr = 'WRL' },
    },
    [13] = {
        [1] = { key = 'shinobi', storageKey = 'kurogane', name = 'Shinobi', abr = 'KRG' },
        [2] = { key = 'kagemusha', storageKey = 'kagemusha', name = 'Kagemusha', abr = 'KGM' },
        [3] = { key = 'nightblade', storageKey = 'nightblade', name = 'Nightblade', abr = 'NGB' },
    },
    [14] = {
        [1] = { key = 'lancer', storageKey = 'lancer', name = 'Lancer', abr = 'LNC' },
        [2] = { key = 'skyborn', storageKey = 'skyborn', name = 'Skyborn', abr = 'SKY' },
        [3] = { key = 'wyvernheart', storageKey = 'wyvernheart', name = 'Wyvernheart', abr = 'WYV' },
    },
    [15] = {
        [1] = { key = 'primalist', storageKey = 'primalist', name = 'Primalist', abr = 'PRM' },
        [2] = { key = 'celestial', storageKey = 'celestial', name = 'Celestial', abr = 'CEL' },
        [3] = { key = 'herald', storageKey = 'herald', name = 'Herald', abr = 'HLD' },
    },
    [16] = {
        [1] = { key = 'warmage', storageKey = 'warmage', name = 'Warmage', abr = 'WMG' },
        [2] = { key = 'magus', storageKey = 'magus', name = 'Magus', abr = 'MAG' },
        [3] = { key = 'azurebastion', storageKey = 'azurebastion', name = 'Azure Bastion', abr = 'AZB' },
    },
    [17] = {
        [1] = { key = 'flintlock', storageKey = 'flintlock', name = 'Flintlock', abr = 'FLT' },
        [2] = { key = 'gambler', storageKey = 'gambler', name = 'Gambler', abr = 'GMB' },
        [3] = { key = 'buccaneer', storageKey = 'buccaneer', name = 'Buccaneer', abr = 'BUC' },
    },
    [18] = {
        [1] = { key = 'vanguard', storageKey = 'vanguard', name = 'Vanguard', abr = 'VNG' },
        [2] = { key = 'animist', storageKey = 'animist', name = 'Animist', abr = 'ANM' },
        [3] = { key = 'pugilist', storageKey = 'pugilist', name = 'Pugilist', abr = 'PGL' },
    },
    [19] = {
        -- Branch 1 is retired Freelancer; retained in persistence fixtures only.
        [2] = { key = 'vampire', storageKey = 'vampire', name = 'Vampire', abr = 'VMP' },
        [3] = { key = 'bladewheel', storageKey = 'bladewheel', name = 'Bladewheel', abr = 'BLW' },
        [4] = { key = 'miragesentinel', storageKey = 'miragesentinel', name = 'Mirage Sentinel', abr = 'MRS' },
    },
    [20] = {
        [1] = { key = 'medic', storageKey = 'medic', name = 'Medic', abr = 'MDC' },
        [2] = { key = 'sage', storageKey = 'sage', name = 'Sage', abr = 'SAG' },
        [3] = { key = 'archivist', storageKey = 'archivist', name = 'Archivist', abr = 'ARC' },
    },
    [21] = {
        [1] = { key = 'diviner', storageKey = 'diviner', name = 'Diviner', abr = 'DIV' },
        [2] = { key = 'verdant', storageKey = 'verdant', name = 'Verdant', abr = 'VRD' },
        [3] = { key = 'terramancer', storageKey = 'terramancer', name = 'Terramancer', abr = 'TRM' },
    },
    [22] = {
        [1] = { key = 'spellblade', storageKey = 'spellblade', name = 'Spellblade', abr = 'SPB' },
        [2] = { key = 'lifebinder', storageKey = 'lifebinder', name = 'Lifebinder', abr = 'LFB' },
        [3] = { key = 'inquisitor', storageKey = 'inquisitor', name = 'Inquisitor', abr = 'INQ' },
    },
}

M.RETIRED_SLOTS = {
    [19] = { [1] = 'freelancer' },
}

M.RETIRED_KEYS = {
    freelancer = { job = 19, branch = 1 },
}

-- Legacy/storage key -> canonical profile key aliases.
M.ALIASES = {
    kurogane = 'shinobi',
    aegistemplar = 'defender',
    soulbeast = 'alphawarden',
    gladiator = 'spartan',
    marionettist = 'vanguard',
    caller = 'celestial',
}

local entryByProfileKey = {}
for jobId, branches in pairs(M.ACTIVE_BY_JOB) do
    for branch, entry in pairs(branches) do
        entry.job = jobId
        entry.branch = branch
        entryByProfileKey[entry.key] = entry
    end
end

local function checkText(v, field)
    assert(type(v) == 'string' and v:match('%S'), field .. ' must be nonempty text')
end

local function checkId(id)
    assert(type(id) == 'number' and id >= 0 and id % 1 == 0, 'action ID must be a nonnegative integer')
end

local function validateAction(kind, id, action)
    assert(validKinds[kind], 'invalid action kind')
    checkId(id)
    assert(type(action) == 'table', 'action must be a table')
    checkText(action.name, 'name')
    checkText(action.description, 'description')
    if action.effectProfile ~= nil then checkText(action.effectProfile, 'effectProfile') end
    if action.gameplayProfile ~= nil then checkText(action.gameplayProfile, 'gameplayProfile') end
    for _, field in ipairs({ 'castTime', 'recastTime', 'mpCost', 'tpCost' }) do
        if action[field] ~= nil then
            assert(type(action[field]) == 'number' and action[field] >= 0, field .. ' must be nonnegative')
        end
    end
end

function M.normalizeProfileKey(key)
    if type(key) ~= 'string' then return nil end
    local lower = key:lower()
    if lower == '' then return nil end
    return M.ALIASES[lower] or lower
end

function M.isRetiredKey(key)
    return type(key) == 'string' and M.RETIRED_KEYS[key:lower()] ~= nil
end

function M.isRetiredBranch(jobId, branch)
    return M.RETIRED_SLOTS[jobId] ~= nil and M.RETIRED_SLOTS[jobId][branch] ~= nil
end

function M.resolveBranch(jobId, branch)
    if type(jobId) ~= 'number' or type(branch) ~= 'number' then return nil end
    if M.isRetiredBranch(jobId, branch) then return nil end
    local branches = M.ACTIVE_BY_JOB[jobId]
    return branches and branches[branch] or nil
end

function M.identityByKey(key)
    local norm = M.normalizeProfileKey(key)
    return norm and entryByProfileKey[norm] or nil
end

-- Registration is deliberately fail-closed: no implicit base-job permissions.
-- Enforcement hooks will only be enabled after all existing Souls are audited.
function M.register(soulKey, actions)
    checkText(soulKey, 'soulKey')
    local normalized = M.normalizeProfileKey(soulKey)
    assert(not M.isRetiredKey(normalized), 'cannot register retired Soul key: ' .. normalized)
    assert(M.definitions[normalized] == nil, 'duplicate Soul action registration: ' .. normalized)
    assert(type(actions) == 'table', 'actions must be a table')
    local copy = {}
    for _, kind in ipairs({ 'spell', 'ability', 'weaponskill' }) do
        copy[kind] = {}
        local source = actions[kind] or {}
        assert(type(source) == 'table', 'action category must be a table')
        for id, action in pairs(source) do
            validateAction(kind, id, action)
            local entry = {}
            for k, v in pairs(action) do entry[k] = v end
            copy[kind][id] = entry
        end
    end
    M.definitions[normalized] = copy
end

function M.resolve(soulKey, kind, id)
    local normalized = M.normalizeProfileKey(soulKey)
    local soul = normalized and M.definitions[normalized] or nil
    return soul and soul[kind] and soul[kind][id] or nil
end

function M.isAllowed(soulKey, kind, id)
    return M.resolve(soulKey, kind, id) ~= nil
end

-- Returns client-safe metadata; never transmit gameplay authority to the addon.
function M.presentation(soulKey, kind, id)
    local action = M.resolve(soulKey, kind, id)
    if not action then return nil end
    return {
        name = action.name,
        description = action.description,
        effectProfile = action.effectProfile,
        castTime = action.castTime,
        recastTime = action.recastTime,
        mpCost = action.mpCost,
        tpCost = action.tpCost,
    }
end

function M.setObservationMode(mode)
    assert(validModes[mode], 'invalid observation mode: ' .. tostring(mode))
    M.observationMode = mode
end

function M.clearObservations()
    M.observations = {}
end

function M.getObservations(filter)
    if type(filter) ~= 'table' then return M.observations end
    local out = {}
    for _, rec in ipairs(M.observations) do
        local match = true
        for k, v in pairs(filter) do
            if rec[k] ~= v then
                match = false
                break
            end
        end
        if match then out[#out + 1] = rec end
    end
    return out
end

-- Opt-in WARN-mode observation. Never blocks or alters live action outcomes.
function M.observe(ctx)
    if M.observationMode == 'off' then
        return { observed = false, allowed = true, outcomeChanged = false, status = 'observation_off' }
    end
    assert(type(ctx) == 'table', 'observation context must be a table')

    local jobId = ctx.jobId
    local branch = ctx.branch
    local identity = nil
    local profileKey = nil
    local storageKey = nil
    local retired = false

    if type(ctx.soulKey) == 'string' and ctx.soulKey ~= '' then
        if M.isRetiredKey(ctx.soulKey) then
            retired = true
            storageKey = ctx.soulKey:lower()
        else
            profileKey = M.normalizeProfileKey(ctx.soulKey)
            identity = entryByProfileKey[profileKey]
            storageKey = identity and identity.storageKey or ctx.soulKey:lower()
        end
    elseif type(jobId) == 'number' and type(branch) == 'number' then
        if M.isRetiredBranch(jobId, branch) then
            retired = true
            storageKey = M.RETIRED_SLOTS[jobId][branch]
        else
            identity = M.resolveBranch(jobId, branch)
            if identity then
                profileKey = identity.key
                storageKey = identity.storageKey
            end
        end
    end

    local status = 'unconfigured'
    local action = nil
    if retired then
        status = 'retired_slot'
    elseif profileKey == nil then
        status = 'no_active_soul'
    elseif type(ctx.effectiveLevel) == 'number' and ctx.effectiveLevel < 10 then
        status = 'below_unlock_level'
    elseif M.definitions[profileKey] == nil then
        -- Missing profile is a configuration notice, never an accidental lockout.
        status = 'unconfigured'
    else
        action = M.resolve(profileKey, ctx.kind, ctx.id)
        if action ~= nil then
            status = 'allowed'
        else
            status = 'warn_unlisted'
        end
    end

    local record = {
        observed = true,
        allowed = true,
        outcomeChanged = false,
        status = status,
        charId = ctx.charId,
        jobId = jobId or (identity and identity.job or nil),
        branch = branch or (identity and identity.branch or nil),
        profileKey = profileKey,
        storageKey = storageKey,
        effectiveLevel = ctx.effectiveLevel,
        kind = ctx.kind,
        id = ctx.id,
        sourceRoute = ctx.sourceRoute or 'normal',
        learned = ctx.learned,
        subjobOnly = ctx.subjobOnly == true,
        isPetCommand = ctx.isPetCommand == true,
        isItemRoute = ctx.isItemRoute == true,
        isMacro = ctx.isMacro == true,
        isQueued = ctx.isQueued == true,
        isDuplicateCallback = ctx.isDuplicateCallback == true,
        presentationName = action and action.name or nil,
    }

    if #M.observations >= M.maxObservations then
        table.remove(M.observations, 1)
    end
    M.observations[#M.observations + 1] = record

    if status == 'warn_unlisted' and type(M.onWarning) == 'function' then
        M.onWarning(record)
    end

    return record
end

-- Emits a structured compatibility snapshot for a Soul and effective-level band.
function M.buildSnapshot(jobId, branch, levelBand, extra)
    local retired = M.isRetiredBranch(jobId, branch)
    local identity = M.resolveBranch(jobId, branch)
    local profileKey = identity and identity.key or nil
    local def = profileKey and M.definitions[profileKey] or nil
    local actions = {}
    if def then
        for _, kind in ipairs({ 'spell', 'ability', 'weaponskill' }) do
            for id, entry in pairs(def[kind] or {}) do
                actions[#actions + 1] = {
                    kind = kind,
                    sourceId = id,
                    visibleName = entry.name,
                    description = entry.description,
                    gameplayProfile = entry.gameplayProfile,
                    effectProfile = entry.effectProfile,
                    castTime = entry.castTime,
                    recastTime = entry.recastTime,
                    mpCost = entry.mpCost,
                    tpCost = entry.tpCost,
                }
            end
        end
    end
    return {
        jobId = jobId,
        storedBranch = branch,
        retired = retired,
        storageKey = retired and M.RETIRED_SLOTS[jobId][branch] or (identity and identity.storageKey or nil),
        profileKey = profileKey,
        displayName = identity and identity.name or nil,
        levelBand = levelBand,
        crystalItemId = extra and extra.crystalItemId or 0,
        validationState = retired and 'retired_persistence_only'
            or (def and 'profile_registered' or 'unconfigured_compat_only'),
        actions = actions,
    }
end

return M
