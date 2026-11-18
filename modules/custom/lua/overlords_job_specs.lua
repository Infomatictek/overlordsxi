-----------------------------------
-- OverlordsXI Job Crystal / Spec System
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.spec = xi.overlords.spec or {}

-- Returns nearby alive mobs within `radius` yalms of `entity`, using the engine's
-- getEntitiesInRange API when a non-mob entity has a mob anchor, and falling back
-- to zone:getMobs() when no mob anchor is available (or when `entity` is a mob).
function xi.overlords.getNearbyMobs(entity, radius, preferredMob)
    local result = {}
    if entity == nil then
        return result
    end

    local maxDist = radius or 10
    local isMobEntity = entity.isMob and entity:isMob()
    local mobAnchor = nil
    if preferredMob ~= nil and preferredMob.isMob and preferredMob:isMob() then
        mobAnchor = preferredMob
    elseif not isMobEntity and entity.getTarget then
        local tgt = entity:getTarget()
        if tgt ~= nil and tgt.isMob and tgt:isMob() then
            mobAnchor = tgt
        end
    end

    if
        not isMobEntity and
        mobAnchor ~= nil and
        entity.getEntitiesInRange and
        xi.aoeType and xi.aoeRadius and xi.findFlag and xi.targetType
    then
        local nearby = entity:getEntitiesInRange(
            mobAnchor,
            xi.aoeType.ROUND,
            xi.aoeRadius.ATTACKER,
            maxDist,
            xi.findFlag.NONE,
            xi.targetType.ENEMY
        )
        if type(nearby) == 'table' then
            for _, ent in ipairs(nearby) do
                if ent ~= nil and ent.isMob and ent:isMob() and ent.isAlive and ent:isAlive() then
                    table.insert(result, ent)
                end
            end
        end
        return result
    end

    local zone = entity.getZone and entity:getZone() or nil
    if zone ~= nil and zone.getMobs then
        for _, mob in ipairs(zone:getMobs()) do
            if
                mob ~= nil and
                mob.isMob and mob:isMob() and
                mob.isAlive and mob:isAlive() and
                mob.checkDistance and mob:checkDistance(entity) <= maxDist
            then
                table.insert(result, mob)
            end
        end
    end
    return result
end

local spec = xi.overlords.spec

spec.jobs            = spec.jobs or {}
spec.jobKeys         = spec.jobKeys or {}
spec.itemIndex       = spec.itemIndex or {}
spec.appliedByCharId = spec.appliedByCharId or {}

-- Default minimum job level required to unlock / socket any soul crystal.
spec.DEFAULT_REQ_LEVEL = spec.DEFAULT_REQ_LEVEL or 10

-- Set to false to disallow swapping crystals while the player holds enmity.
spec.ALLOW_SWAP_IN_COMBAT = spec.ALLOW_SWAP_IN_COMBAT ~= false

spec.PROTO_TAG = '[OXSPEC]|'

local JOB_KEYS = {}
local JOB_NAMES = {}

local function initJobMaps()
    local jobEnum = xi.job or {}
    local defs =
    {
        { jobEnum.WAR, 'WAR', 'Warrior' },
        { jobEnum.MNK, 'MNK', 'Monk' },
        { jobEnum.WHM, 'WHM', 'White Mage' },
        { jobEnum.BLM, 'BLM', 'Black Mage' },
        { jobEnum.RDM, 'RDM', 'Red Mage' },
        { jobEnum.THF, 'THF', 'Thief' },
        { jobEnum.PLD, 'PLD', 'Paladin' },
        { jobEnum.DRK, 'DRK', 'Dark Knight' },
        { jobEnum.BST, 'BST', 'Beastmaster' },
        { jobEnum.BRD, 'BRD', 'Bard' },
        { jobEnum.RNG, 'RNG', 'Ranger' },
        { jobEnum.SAM, 'SAM', 'Samurai' },
        { jobEnum.NIN, 'NIN', 'Ninja' },
        { jobEnum.DRG, 'DRG', 'Dragoon' },
        { jobEnum.SMN, 'SMN', 'Summoner' },
        { jobEnum.BLU, 'BLU', 'Blue Mage' },
        { jobEnum.COR, 'COR', 'Corsair' },
        { jobEnum.PUP, 'PUP', 'Puppetmaster' },
        { jobEnum.DNC, 'DNC', 'Dancer' },
        { jobEnum.SCH, 'SCH', 'Scholar' },
        { jobEnum.GEO, 'GEO', 'Geomancer' },
        { jobEnum.RUN, 'RUN', 'Rune Fencer' },
    }

    for _, d in ipairs(defs) do
        if d[1] ~= nil then
            JOB_KEYS[d[1]] = d[2]
            JOB_NAMES[d[1]] = d[3]
        end
    end
end

initJobMaps()

local function normalizeKey(value)
    if value == nil then
        return nil
    end

    return string.lower(tostring(value))
end

local function sanitizeField(text)
    local s = tostring(text or '')
    s = string.gsub(s, '|', '/')
    s = string.gsub(s, '[\r\n]', ' ')
    return s
end

local function getCharKey(player)
    if player == nil then
        return nil
    end
    if player.getID then
        return player:getID()
    end
    return player
end

function spec.getJobKey(jobId)
    if spec.jobKeys[jobId] ~= nil then
        return spec.jobKeys[jobId]
    end
    if JOB_KEYS[jobId] ~= nil then
        return JOB_KEYS[jobId]
    end
    return string.format('J%u', tonumber(jobId) or 0)
end

function spec.getJobName(jobId)
    if JOB_NAMES[jobId] ~= nil then
        return JOB_NAMES[jobId]
    end
    if xi.jobName and xi.jobName[jobId] then
        return xi.jobName[jobId][2]
    end
    return spec.getJobKey(jobId)
end

-- Canonical OverlordsXI 22-job Soul Crystal Specialization catalog (branch IDs 1..3 per job).
spec.JOB_SPECS =
{
    WAR =
    {
        { id = 'commander', name = 'Commander', abr = 'CDR', role = 'Support' },
        { id = 'berserker', name = 'Berserker', abr = 'BRZ', role = 'Damage' },
        { id = 'spartan',   name = 'Spartan',   abr = 'SPT', role = 'Tank' },
    },
    MNK =
    {
        { id = 'sensei',    name = 'Sensei',     abr = 'SEN', role = 'Tank' },
        { id = 'chiweaver', name = 'Chi Weaver', abr = 'CWV', role = 'Healer' },
        { id = 'blackbelt', name = 'Black Belt', abr = 'BLK', role = 'Damage' },
    },
    WHM =
    {
        { id = 'bishop',   name = 'Bishop',   abr = 'BSH', role = 'Healer' },
        { id = 'zealot',   name = 'Zealot',   abr = 'ZEL', role = 'Damage' },
        { id = 'valkyrie', name = 'Valkyrie', abr = 'VLK', role = 'Support' },
    },
    BLM =
    {
        { id = 'astromancer', name = 'Astromancer', abr = 'AST', role = 'Damage' },
        { id = 'channeler',   name = 'Channeler',   abr = 'CHN', role = 'Support' },
        { id = 'necromancer', name = 'Necromancer', abr = 'NEC', role = 'Tank' },
    },
    RDM =
    {
        { id = 'crimsonduelist', name = 'Crimson Duelist', abr = 'DLS', role = 'Tank' },
        { id = 'royaltactician', name = 'Royal Tactician', abr = 'RYT', role = 'Support' },
        { id = 'scarletweaver',  name = 'Scarlet Weaver',  abr = 'SCW', role = 'Damage' },
    },
    THF =
    {
        { id = 'trickster', name = 'Trickster', abr = 'TRK', role = 'Support' },
        { id = 'bandit',    name = 'Bandit',    abr = 'BND', role = 'Damage' },
        { id = 'phantom',   name = 'Phantom',   abr = 'PHN', role = 'Tank' },
    },
    PLD =
    {
        { id = 'templar',     name = 'Templar',     abr = 'TMP', role = 'Healer' },
        { id = 'defender',    name = 'Defender',    abr = 'DFN', role = 'Tank' },
        { id = 'oathbreaker', name = 'Oathbreaker', abr = 'OTB', role = 'Damage' },
    },
    DRK =
    {
        { id = 'reaper',      name = 'Reaper',      abr = 'RPR', role = 'Damage' },
        { id = 'dreadnought', name = 'Dreadnought', abr = 'DRN', role = 'Tank' },
        { id = 'scourge',     name = 'Scourge',     abr = 'SCR', role = 'Support' },
    },
    BRD =
    {
        { id = 'adventurer', name = 'Adventurer', abr = 'ADV', role = 'Damage' },
        { id = 'musician',   name = 'Musician',   abr = 'MUS', role = 'Support' },
        { id = 'minstrel',   name = 'Minstrel',   abr = 'MIN', role = 'Tank' },
    },
    RNG =
    {
        { id = 'sniper',       name = 'Sniper',        abr = 'SNP', role = 'Damage' },
        { id = 'huntsman',     name = 'Huntsman',      abr = 'HNT', role = 'Tank' },
        { id = 'arcanearcher', name = 'Arcane Archer', abr = 'ACA', role = 'Support' },
    },
    SAM =
    {
        { id = 'ronin',          name = 'Ronin',           abr = 'RON', role = 'Tank' },
        { id = 'imperialarcher', name = 'Imperial Archer', abr = 'IMP', role = 'Support' },
        { id = 'warlord',        name = 'Warlord',         abr = 'WRL', role = 'Support' },
    },
    NIN =
    {
        { id = 'kurogane',   name = 'Kurogane',   abr = 'KRG', role = 'Damage' },
        { id = 'kagemusha',  name = 'Kagemusha',  abr = 'KGM', role = 'Tank' },
        { id = 'nightblade', name = 'Nightblade', abr = 'NGB', role = 'Support' },
    },
    DRG =
    {
        { id = 'lancer',      name = 'Lancer',      abr = 'LNC', role = 'Damage' },
        { id = 'skyborn',     name = 'Skyborn',     abr = 'SKY', role = 'Tank' },
        { id = 'wyvernheart', name = 'Wyvernheart', abr = 'WYV', role = 'Healer' },
    },
    BLU =
    {
        { id = 'warmage',      name = 'Warmage',       abr = 'WMG', role = 'Damage' },
        { id = 'magus',        name = 'Magus',         abr = 'MAG', role = 'Healer' },
        { id = 'azurebastion', name = 'Azure Bastion', abr = 'AZB', role = 'Tank' },
    },
    COR =
    {
        { id = 'flintlock', name = 'Flintlock', abr = 'FLT', role = 'Damage' },
        { id = 'gambler',   name = 'Gambler',   abr = 'GMB', role = 'Support' },
        { id = 'buccaneer', name = 'Buccaneer', abr = 'BUC', role = 'Tank' },
    },
    DNC =
    {
        { id = 'freelancer', name = 'Freelancer', abr = 'FRL', role = 'Support' },
        { id = 'vampire',    name = 'Vampire',    abr = 'VMP', role = 'Healer' },
        { id = 'bladewheel', name = 'Bladewheel', abr = 'BLW', role = 'Damage' },
    },
    SCH =
    {
        { id = 'medic',     name = 'Medic',     abr = 'MDC', role = 'Healer' },
        { id = 'sage',      name = 'Sage',      abr = 'SAG', role = 'Damage' },
        { id = 'archivist', name = 'Archivist', abr = 'ARC', role = 'Support' },
    },
    BST =
    {
        { id = 'untamed',      name = 'Untamed',      abr = 'UNT', role = 'Damage' },
        { id = 'alphawarden',  name = 'Alpha Warden', abr = 'ALW', role = 'Tank' },
        { id = 'beastspeaker', name = 'Beastspeaker', abr = 'BSP', role = 'Support' },
    },
    SMN =
    {
        { id = 'primalist', name = 'Primalist', abr = 'PRM', role = 'Damage' },
        { id = 'celestial', name = 'Celestial', abr = 'CEL', role = 'Healer' },
        { id = 'herald',    name = 'Herald',    abr = 'HLD', role = 'Support' },
    },
    PUP =
    {
        { id = 'marionettist', name = 'Marionettist', abr = 'MRN', role = 'Tank' },
        { id = 'pugilist',     name = 'Pugilist',     abr = 'PGL', role = 'Damage' },
        { id = 'animist',      name = 'Animist',      abr = 'ANM', role = 'Healer' },
    },
    RUN =
    {
        { id = 'spellblade', name = 'Spellblade', abr = 'SPB', role = 'Damage' },
        { id = 'lifebinder', name = 'Lifebinder', abr = 'LFB', role = 'Healer' },
        { id = 'inquisitor', name = 'Inquisitor', abr = 'INQ', role = 'Tank' },
    },
    GEO =
    {
        { id = 'diviner',     name = 'Diviner',     abr = 'DIV', role = 'Support' },
        { id = 'verdant',     name = 'Verdant',     abr = 'VRD', role = 'Healer' },
        { id = 'terramancer', name = 'Terramancer', abr = 'TRM', role = 'Damage' },
    },
}

local KEY_ALIASES =
{
    gladiator      = 'spartan',
    aegistemplar   = 'defender',
    alphawarden    = 'alphawarden',
    soulbeast      = 'alphawarden',
    marionettist   = 'vanguard',
    miragesentinel = 'freelancer',
    caller         = 'celestial',
}

spec.TIER_CONFIG =
{
    Damage        = { name = 'Damage',        offense = 1.00, physDmgDealt = 0,   magDmgDealt = 0 },
    HybridSupport = { name = 'HybridSupport', offense = 0.50, physDmgDealt = -25, magDmgDealt = -25 },
    Support       = { name = 'Support',       offense = 0.35, physDmgDealt = -40, magDmgDealt = -40 },
    CombatHealer  = { name = 'CombatHealer',  offense = 0.20, physDmgDealt = -50, magDmgDealt = -50 },
    Healer        = { name = 'Healer',        offense = 0.12, physDmgDealt = -60, magDmgDealt = -60 },
    Tank          = { name = 'Tank',          offense = 0.12, physDmgDealt = -60, magDmgDealt = -60 },
}

spec.SPEC_KEY_TIERS =
{
    warlord        = 'HybridSupport',
    musician       = 'HybridSupport',
    channeler      = 'HybridSupport',
    templar        = 'CombatHealer',
    aegistemplar   = 'Tank',
    magus          = 'CombatHealer',
    vampire        = 'CombatHealer',
    animist        = 'CombatHealer',
    wyvernheart    = 'CombatHealer',
    miragesentinel = 'Tank',
}

local CANONICAL_ROLE_BY_KEY = {}
for _, list in pairs(spec.JOB_SPECS) do
    for _, c in ipairs(list) do
        CANONICAL_ROLE_BY_KEY[c.id] = c.role
    end
end
for aliasKey, targetKey in pairs(KEY_ALIASES) do
    if CANONICAL_ROLE_BY_KEY[aliasKey] == nil and CANONICAL_ROLE_BY_KEY[targetKey] ~= nil then
        CANONICAL_ROLE_BY_KEY[aliasKey] = CANONICAL_ROLE_BY_KEY[targetKey]
    end
end

function spec.getSpecTier(entryOrKey)
    local key = nil
    local roleStr = nil
    if type(entryOrKey) == 'table' then
        key = normalizeKey(entryOrKey.key)
        roleStr = entryOrKey.role
    elseif entryOrKey ~= nil then
        key = normalizeKey(entryOrKey)
    end

    if key ~= nil then
        if spec.SPEC_KEY_TIERS[key] ~= nil then
            return spec.SPEC_KEY_TIERS[key]
        end
        local canonicalRole = CANONICAL_ROLE_BY_KEY[key]
        if canonicalRole ~= nil and spec.TIER_CONFIG[canonicalRole] ~= nil then
            return canonicalRole
        end
    end

    if type(roleStr) == 'string' then
        local lower = string.lower(roleStr)
        if string.find(lower, 'tank', 1, true) then
            return 'Tank'
        elseif string.find(lower, 'healer', 1, true) then
            return 'Healer'
        elseif string.find(lower, 'support', 1, true) then
            return 'Support'
        end
    end

    return 'Damage'
end

function spec.getTierConfig(player, jobId)
    if player == nil then
        return spec.TIER_CONFIG.Damage
    end
    local targetJob = jobId or (player.getMainJob and player:getMainJob() or nil)
    local active = spec.get(player, targetJob)
    if active == nil or not spec.isLevelEligible(player, targetJob, active) then
        return spec.TIER_CONFIG.Damage
    end
    return spec.TIER_CONFIG[spec.getSpecTier(active)] or spec.TIER_CONFIG.Damage
end

function spec.getOffenseScalar(player, jobId)
    return spec.getTierConfig(player, jobId).offense
end

local function buildEntry(jobKey, entry)
    local out = {}
    for k, v in pairs(entry or {}) do
        out[k] = v
    end
    out.id          = tonumber(out.id) or 0
    out.key         = normalizeKey(out.key)
    out.name        = out.name or out.key or 'Unknown'
    out.role        = out.role or 'Job Specialization'
    out.icon        = out.icon or (out.key and (out.key .. '_crystal') or 'crystal')
    out.itemId      = tonumber(out.itemId) or 0
    out.reqLevel    = tonumber(out.reqLevel) or spec.DEFAULT_REQ_LEVEL
    out.description = out.description or ''
    out.highlights  = out.highlights or {}

    local canonicalList = jobKey and spec.JOB_SPECS[jobKey] or nil
    if canonicalList and out.key then
        local targetKey = KEY_ALIASES[out.key] or out.key
        for branchIdx, c in ipairs(canonicalList) do
            if c.id == targetKey then
                out.id            = branchIdx
                out.abr           = c.abr
                out.canonicalKey  = c.id
                out.canonicalName = c.name
                break
            end
        end
    end
    return out
end

local function indexEntry(job, jobId, entry)
    job.byId[entry.id] = entry
    if entry.key ~= nil then
        job.byKey[entry.key] = entry
    end
    if entry.canonicalKey ~= nil then
        job.byKey[entry.canonicalKey] = entry
    end
    if entry.name ~= nil then
        job.byName[normalizeKey(entry.name)] = entry
    end
    if entry.canonicalName ~= nil then
        job.byName[normalizeKey(entry.canonicalName)] = entry
    end
    if entry.itemId ~= nil and entry.itemId > 0 then
        job.byItemId[entry.itemId] = entry
        spec.itemIndex[entry.itemId] = { jobId = jobId, entry = entry }
    end
end

function spec.registerJob(jobId, jobKey, specs)
    if jobId == nil then
        return
    end

    local normalizedJobKey = jobKey or spec.getJobKey(jobId)
    local job =
    {
        jobId    = jobId,
        key      = normalizedJobKey,
        byId     = {},
        byKey    = {},
        byName   = {},
        byItemId = {},
        ordered  = {},
    }

    -- Preserve any itemIndex cleanup if re-registering the same job
    local prevJob = spec.jobs[jobId]
    if prevJob ~= nil then
        for itemId, _ in pairs(prevJob.byItemId or {}) do
            spec.itemIndex[itemId] = nil
        end
    end

    for _, rawEntry in ipairs(specs or {}) do
        local entry = buildEntry(normalizedJobKey, rawEntry)
        indexEntry(job, jobId, entry)
        table.insert(job.ordered, entry)
    end
    table.sort(job.ordered, function(a, b) return a.id < b.id end)

    spec.jobs[jobId] = job
    spec.jobKeys[jobId] = normalizedJobKey
end

function spec.registerCrystal(jobId, rawEntry)
    if jobId == nil or rawEntry == nil then
        return nil
    end

    if spec.jobs[jobId] == nil then
        spec.registerJob(jobId, spec.getJobKey(jobId), {})
    end

    local job = spec.jobs[jobId]
    local entry = buildEntry(job.key, rawEntry)
    local replaced = false
    for idx, existing in ipairs(job.ordered) do
        if existing.id == entry.id or (entry.key ~= nil and existing.key == entry.key) then
            if existing.itemId and existing.itemId > 0 then
                job.byItemId[existing.itemId] = nil
                spec.itemIndex[existing.itemId] = nil
            end
            job.ordered[idx] = entry
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(job.ordered, entry)
    end
    table.sort(job.ordered, function(a, b) return a.id < b.id end)
    indexEntry(job, jobId, entry)
    return entry
end

function spec.getVarName(jobId)
    local jobKey = spec.jobKeys[jobId] or JOB_KEYS[jobId]
    if jobKey == nil then
        return nil
    end

    return string.format('OX_SPEC_%s', jobKey)
end

function spec.resolve(jobId, specKeyOrId)
    local job = spec.jobs[jobId]
    if job == nil or specKeyOrId == nil then
        return nil
    end

    if type(specKeyOrId) == 'number' then
        if specKeyOrId <= 0 then
            return nil
        end
        return job.byId[specKeyOrId] or job.byItemId[specKeyOrId]
    end

    local text = tostring(specKeyOrId)
    local itemStr = string.match(string.lower(text), '^item:(%d+)$')
    if itemStr ~= nil then
        return job.byItemId[tonumber(itemStr)]
    end

    local numericId = tonumber(text)
    if numericId ~= nil and numericId > 0 then
        return job.byId[numericId] or job.byItemId[numericId]
    end

    local norm = normalizeKey(text)
    return job.byKey[norm] or job.byName[norm]
end

function spec.resolveByItemId(jobId, itemId)
    local job = spec.jobs[jobId]
    if job == nil or itemId == nil or itemId <= 0 then
        return nil
    end
    return job.byItemId[tonumber(itemId)]
end

function spec.findByItemId(itemId)
    if itemId == nil or itemId <= 0 then
        return nil
    end
    return spec.itemIndex[tonumber(itemId)]
end

function spec.get(player, jobId)
    if player == nil then
        return nil
    end

    local targetJob = jobId or player:getMainJob()
    local varName = spec.getVarName(targetJob)
    if varName == nil then
        return nil
    end

    return spec.resolve(targetJob, player:getCharVar(varName))
end

function spec.getPlayerJobLevel(player, jobId)
    if player == nil then
        return 1
    end

    local targetJob = jobId or player:getMainJob()
    if player.getMainJob and targetJob == player:getMainJob() then
        return player.getMainLvl and player:getMainLvl() or 1
    end

    if player.getJobLevel then
        return player:getJobLevel(targetJob) or 1
    end

    return player.getMainLvl and player:getMainLvl() or 1
end

function spec.isLevelEligible(player, jobId, entry)
    local reqLvl = (entry and tonumber(entry.reqLevel)) or spec.DEFAULT_REQ_LEVEL
    local curLvl = spec.getPlayerJobLevel(player, jobId)
    return curLvl >= reqLvl, reqLvl, curLvl
end

function spec.is(player, jobId, specKey)
    local activeSpec = spec.get(player, jobId)
    if activeSpec == nil or normalizeKey(activeSpec.key) ~= normalizeKey(specKey) then
        return false
    end

    return spec.isLevelEligible(player, jobId or player:getMainJob(), activeSpec)
end

function spec.list(jobId)
    local job = spec.jobs[jobId]
    if job == nil then
        return {}
    end

    return job.ordered
end

function spec.listAllJobs()
    local out = {}
    for jobId, job in pairs(spec.jobs) do
        table.insert(out, { jobId = jobId, key = job.key, name = spec.getJobName(jobId), count = #job.ordered })
    end
    table.sort(out, function(a, b) return a.jobId < b.jobId end)
    return out
end

function spec.canSwap(player)
    if player == nil then
        return false, 'Invalid player.'
    end

    if not spec.ALLOW_SWAP_IN_COMBAT and player.hasEnmity and player:hasEnmity() then
        return false, 'Cannot swap job crystals while holding enmity.'
    end

    return true, nil
end

local function syncAbilitiesTable(player)
    if player == nil then
        return
    end
    if player.recalculateSkillsTable then
        player:recalculateSkillsTable()
    end
    if player.recalculateAbilitiesTable then
        player:recalculateAbilitiesTable()
    end
end

local function evalIdList(player, entry, fieldName)
    local out = {}
    if entry == nil or player == nil then
        return out
    end

    local raw = entry[fieldName]
    if type(raw) == 'function' then
        local lvl = player.getMainLvl and player:getMainLvl() or 1
        raw = raw(player, lvl)
    end

    if type(raw) ~= 'table' then
        return out
    end

    for _, entryId in ipairs(raw) do
        local num = tonumber(entryId)
        if num ~= nil and num > 0 then
            table.insert(out, num)
        end
    end

    return out
end

local function listsEqual(a, b)
    if a == b then
        return true
    end
    if type(a) ~= 'table' or type(b) ~= 'table' or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function getActiveEntryExtraIds(player, fieldName)
    if player == nil or (player.isPC and not player:isPC()) then
        return {}
    end

    local jobId = player.getMainJob and player:getMainJob() or nil
    if jobId == nil then
        return {}
    end

    local active = spec.get(player, jobId)
    if active == nil or not spec.isLevelEligible(player, jobId, active) then
        return {}
    end

    return evalIdList(player, active, fieldName)
end

function spec.getExtraAbilities(player)
    return getActiveEntryExtraIds(player, 'extraAbilities')
end

local DUAL_WIELD_SPEC_KEYS =
{
    magus        = true,
    azurebastion = true,
    adventurer   = true,
    nightblade   = true,
    freelancer   = true,
}

function spec.getExtraTraits(player)
    local ids = getActiveEntryExtraIds(player, 'extraTraits')
    if player ~= nil and (player.getMainLvl and player:getMainLvl() or 1) >= 10 then
        local active = spec.get(player, player.getMainJob and player:getMainJob() or nil)
        if active ~= nil and spec.isLevelEligible(player, player:getMainJob(), active) then
            local k = normalizeKey(active.key)
            if k ~= nil and DUAL_WIELD_SPEC_KEYS[k] then
                local dwTrait = (xi and xi.trait and xi.trait.DUAL_WIELD) or 18
                local found = false
                for _, id in ipairs(ids) do
                    if id == dwTrait then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(ids, 1, dwTrait)
                end
            end
        end
    end
    return ids
end

local function upsertMod(list, modId, val)
    if modId == nil or type(val) ~= 'number' then
        return
    end
    for _, item in ipairs(list) do
        if item.mod == modId then
            item.val = val
            return
        end
    end
    if val ~= 0 then
        table.insert(list, { mod = modId, val = val })
    end
end

function spec.evaluateMods(player, entry)
    if entry == nil then
        return {}
    end

    local lvl = (player ~= nil and player.getMainLvl) and player:getMainLvl() or 1
    local raw = entry.mods
    if type(raw) == 'function' then
        raw = raw(player, lvl)
    end

    local tierName = spec.getSpecTier(entry)
    local tierCfg  = spec.TIER_CONFIG[tierName] or spec.TIER_CONFIG.Damage
    local stripNegOffense = (tierName ~= 'Damage') and xi and xi.mod

    local out = {}
    if type(raw) == 'table' then
        for _, pair in ipairs(raw) do
            local modId = pair.mod or pair[1]
            local val = pair.val or pair[2]
            if modId ~= nil and type(val) == 'number' and val ~= 0 then
                local skip = false
                if stripNegOffense and val < 0 and (
                    modId == xi.mod.ATTP or
                    modId == xi.mod.RATTP or
                    modId == xi.mod.MATT or
                    modId == xi.mod.MACC or
                    modId == xi.mod.ALL_WSDMG_ALL_HITS
                ) then
                    skip = true
                end
                if not skip then
                    table.insert(out, { mod = modId, val = val })
                end
            end
        end
    end

    if xi and xi.mod then
        if tierCfg.physDmgDealt ~= 0 and xi.mod.PHYS_DMG_DEALT then
            upsertMod(out, xi.mod.PHYS_DMG_DEALT, tierCfg.physDmgDealt)
        end
        if tierCfg.magDmgDealt ~= 0 and xi.mod.MAG_DMG_DEALT then
            upsertMod(out, xi.mod.MAG_DMG_DEALT, tierCfg.magDmgDealt)
        end
        if tierName == 'Tank' and xi.mod.ENMITY then
            local tankEnmity = (lvl >= 70 and 120) or (lvl >= 50 and 100) or (lvl >= 30 and 80) or 60
            local found = false
            for _, item in ipairs(out) do
                if item.mod == xi.mod.ENMITY then
                    item.val = math.max(item.val, tankEnmity)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(out, { mod = xi.mod.ENMITY, val = tankEnmity })
            end
        end
    end

    return out
end

function spec.syncPetRoleMods(player, pet)
    if player == nil or pet == nil or not xi or not xi.mod then
        return
    end
    if pet.isAlive and not pet:isAlive() then
        return
    end

    local tierCfg  = spec.getTierConfig(player)
    local wantPhys = tierCfg and tierCfg.physDmgDealt or 0
    local wantMag  = tierCfg and tierCfg.magDmgDealt or 0

    if xi.mod.PHYS_DMG_DEALT and pet.getLocalVar and pet.setLocalVar and pet.addMod and pet.delMod then
        local prevPhys = pet:getLocalVar('OX_ROLE_PHYS_DEALT') or 0
        if prevPhys ~= wantPhys then
            if prevPhys ~= 0 then
                pet:delMod(xi.mod.PHYS_DMG_DEALT, prevPhys)
            end
            if wantPhys ~= 0 then
                pet:addMod(xi.mod.PHYS_DMG_DEALT, wantPhys)
            end
            pet:setLocalVar('OX_ROLE_PHYS_DEALT', wantPhys)
        end
    end

    if xi.mod.MAG_DMG_DEALT and pet.getLocalVar and pet.setLocalVar and pet.addMod and pet.delMod then
        local prevMag = pet:getLocalVar('OX_ROLE_MAG_DEALT') or 0
        if prevMag ~= wantMag then
            if prevMag ~= 0 then
                pet:delMod(xi.mod.MAG_DMG_DEALT, prevMag)
            end
            if wantMag ~= 0 then
                pet:addMod(xi.mod.MAG_DMG_DEALT, wantMag)
            end
            pet:setLocalVar('OX_ROLE_MAG_DEALT', wantMag)
        end
    end
end

function spec.removeAppliedMods(player, invokeOnRemove)
    local charKey = getCharKey(player)
    if charKey == nil then
        return
    end

    local state = spec.appliedByCharId[charKey]
    if state == nil then
        return
    end

    if player.delMod then
        for _, m in ipairs(state.mods or {}) do
            player:delMod(m.mod, m.val)
        end
    end

    if player.setLocalVar then
        player:setLocalVar('OX_THROW_WS', 0)
        player:setLocalVar('OX_AUTO_RANGED', 0)
        player:setLocalVar('OX_AUTO_RANGED_RANGE', 0)
        player:setLocalVar('OX_DNC_RANGED', 0)
        player:setLocalVar('OX_CHI_AUTO_RANGED', 0)
        player:setLocalVar('OX_CHI_RANGED_RANGE', 0)
        player:setLocalVar('OX_CHI_NEXT_DELAY_MS', 0)
    end

    spec.appliedByCharId[charKey] = nil

    if invokeOnRemove and state.jobId ~= nil and state.specId ~= nil then
        local prevEntry = spec.resolve(state.jobId, state.specId)
        if prevEntry ~= nil and type(prevEntry.onRemove) == 'function' then
            prevEntry.onRemove(player, prevEntry)
        end
    end
end

local function ensureSessionInitialized(player)
    if player == nil or not player.getLocalVar then
        return
    end

    if player:getLocalVar('OX_SPEC_SYNCED') == 0 then
        local charKey = getCharKey(player)
        if charKey ~= nil then
            spec.appliedByCharId[charKey] = nil
        end
        if player.setLocalVar then
            player:setLocalVar('OX_SPEC_SYNCED', 1)
        end
    end
end

function spec.refreshPlayer(player, opts)
    opts = opts or {}
    if player == nil or (player.isPC and not player:isPC()) then
        return nil
    end

    ensureSessionInitialized(player)

    local charKey = getCharKey(player)
    local jobId = player:getMainJob()
    local lvl = player.getMainLvl and player:getMainLvl() or 1
    local stored = spec.get(player, jobId)
    local eligible = (stored ~= nil) and spec.isLevelEligible(player, jobId, stored)
    local active = eligible and stored or nil
    local activeId = active and active.id or 0
    local prev = spec.appliedByCharId[charKey]
    local extraAbilities = active and evalIdList(player, active, 'extraAbilities') or {}
    local extraTraits = active and evalIdList(player, active, 'extraTraits') or {}

    if
        prev ~= nil and
        prev.jobId == jobId and
        prev.specId == activeId and
        prev.level == lvl and
        listsEqual(prev.extraAbilities or {}, extraAbilities) and
        listsEqual(prev.extraTraits or {}, extraTraits)
    then
        return active
    end

    local specChanged = (prev ~= nil) and (prev.jobId ~= jobId or prev.specId ~= activeId)
    local prevAbilities = prev and prev.extraAbilities or {}
    local prevTraits = prev and prev.extraTraits or {}
    local tablesChanged =
        (not listsEqual(prevAbilities, extraAbilities)) or
        (not listsEqual(prevTraits, extraTraits)) or
        (prev == nil and activeId > 0) or
        specChanged

    spec.removeAppliedMods(player, specChanged)

    if active == nil then
        if tablesChanged and not opts.skipSync then
            syncAbilitiesTable(player)
        end
        return nil
    end

    local mods = spec.evaluateMods(player, active)
    if player.addMod then
        for _, m in ipairs(mods) do
            player:addMod(m.mod, m.val)
        end
    end

    if player.getPet then
        local pet = player:getPet()
        if pet ~= nil then
            spec.syncPetRoleMods(player, pet)
        end
    end

    if player.setLocalVar then
        player:setLocalVar('OX_THROW_WS', active.throwWs and 1 or 0)
        if active.autoRanged then
            local arMinLvl = (type(active.autoRanged) == 'table' and active.autoRanged.minLevel) or 1
            local arRange = (type(active.autoRanged) == 'table' and active.autoRanged.maxRange) or 20
            player:setLocalVar('OX_AUTO_RANGED', (lvl >= arMinLvl) and 1 or 0)
            player:setLocalVar('OX_AUTO_RANGED_RANGE', arRange)
        else
            player:setLocalVar('OX_AUTO_RANGED', 0)
            player:setLocalVar('OX_AUTO_RANGED_RANGE', 0)
        end
        player:setLocalVar('OX_DNC_RANGED', active.rangedDances and 1 or 0)
        if active.chiRanged then
            local crMinLvl = (type(active.chiRanged) == 'table' and active.chiRanged.minLevel) or 1
            local crRange = (type(active.chiRanged) == 'table' and active.chiRanged.maxRange) or 20
            player:setLocalVar('OX_CHI_AUTO_RANGED', (lvl >= crMinLvl) and 1 or 0)
            player:setLocalVar('OX_CHI_RANGED_RANGE', crRange)
        else
            player:setLocalVar('OX_CHI_AUTO_RANGED', 0)
            player:setLocalVar('OX_CHI_RANGED_RANGE', 0)
        end
    end

    spec.appliedByCharId[charKey] =
    {
        jobId          = jobId,
        specId         = active.id,
        level          = lvl,
        mods           = mods,
        extraAbilities = extraAbilities,
        extraTraits    = extraTraits,
    }

    if (prev == nil or specChanged) and type(active.onApply) == 'function' then
        active.onApply(player, active)
    end

    if (tablesChanged or specChanged) and not opts.skipSync then
        syncAbilitiesTable(player)
        if xi.overlords.wsTalents and xi.overlords.wsTalents.sendMetaAndSpent then
            xi.overlords.wsTalents.sendMetaAndSpent(player)
        end
    end

    return active
end

-- WAR Spartan/Gladiator may wield a 2H Polearm together with a Size-1 Buckler.
-- C++ (charutils::CanEquipPolearmBuckler) reads the OX_POLEARM_BUCKLER local var.
function spec.syncPolearmBuckler(player, active)
    if player == nil or (player.isPC and not player:isPC()) then
        return
    end

    local enabled = 0
    if player:getMainJob() == xi.job.WAR and active ~= nil and active.key ~= nil then
        local key = string.lower(tostring(active.key))
        if key == 'spartan' or key == 'gladiator' then
            enabled = 1
        end
    end

    local prev = player:getLocalVar('OX_POLEARM_BUCKLER')
    player:setLocalVar('OX_POLEARM_BUCKLER', enabled)

    if enabled == 0 then
        local main = player:getEquippedItem(xi.slot.MAIN)
        local sub  = player:getEquippedItem(xi.slot.SUB)
        if
            main ~= nil and sub ~= nil and
            sub:isShield() and
            player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
        then
            player:unequipItem(xi.slot.SUB)
        end
    end

    return prev ~= enabled
end

function spec.onTraitsRebuild(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return nil
    end

    local charKey = getCharKey(player)
    local sessionReset = player.getLocalVar and player:getLocalVar('OX_SPEC_SYNCED') == 0
    local prev = spec.appliedByCharId[charKey]
    local prevJobId = prev and prev.jobId or nil
    local prevLvl = prev and prev.level or nil
    local prevSpecId = prev and prev.specId or nil

    local active = spec.refreshPlayer(player, { skipSync = true })
    spec.syncPolearmBuckler(player, active)
    local curJobId = player.getMainJob and player:getMainJob() or nil
    local curLvl = player.getMainLvl and player:getMainLvl() or 1
    local curSpecId = active and active.id or 0

    if
        sessionReset or
        prev == nil or
        prevJobId ~= curJobId or
        prevLvl ~= curLvl or
        prevSpecId ~= curSpecId
    then
        -- BuildingCharSkillsTable runs before BuildingCharTraitsTable in C++, so
        -- recalculate skills now that spec skill mods (e.g. Elemental/Scythe) are applied.
        if player.recalculateSkillsTable then
            player:recalculateSkillsTable()
        end
        if xi.overlords.wsTalents and xi.overlords.wsTalents.sendMetaAndSpent then
            xi.overlords.wsTalents.sendMetaAndSpent(player)
        end
    end

    return active
end

function spec.ensureUpToDate(player)
    if player == nil or (player.isPC and not player:isPC()) then
        return nil
    end

    ensureSessionInitialized(player)

    local charKey = getCharKey(player)
    local jobId = player:getMainJob()
    local lvl = player.getMainLvl and player:getMainLvl() or 1
    local stored = spec.get(player, jobId)
    local eligible = (stored ~= nil) and spec.isLevelEligible(player, jobId, stored)
    local active = eligible and stored or nil
    local activeId = active and active.id or 0
    local prev = spec.appliedByCharId[charKey]

    if
        prev == nil or
        prev.jobId ~= jobId or
        prev.specId ~= activeId or
        prev.level ~= lvl
    then
        return spec.refreshPlayer(player)
    end

    return active
end

function spec.set(player, jobId, specKeyOrId, opts)
    opts = opts or {}
    if player == nil then
        return nil, 'Invalid player.'
    end

    local targetJob = jobId or player:getMainJob()
    local resolved = spec.resolve(targetJob, specKeyOrId)
    local varName = spec.getVarName(targetJob)
    if resolved == nil or varName == nil then
        return nil, 'Unknown crystal or job.'
    end

    local eligible, reqLvl, curLvl = spec.isLevelEligible(player, targetJob, resolved)
    if not eligible then
        return nil, string.format('%s soul requires %s Lv.%d (currently Lv.%d).', resolved.name, spec.getJobName(targetJob), reqLvl, curLvl)
    end

    local okSwap, swapErr = spec.canSwap(player)
    if not okSwap then
        return nil, swapErr
    end

    local prevId = player:getCharVar(varName)
    if prevId ~= resolved.id then
        local prevEntry = spec.resolve(targetJob, prevId)
        if
            prevEntry ~= nil and
            type(prevEntry.onRemove) == 'function' and
            targetJob == player:getMainJob()
        then
            -- Remove old mods first so onRemove sees clean state; avoid double onRemove
            spec.removeAppliedMods(player, false)
            prevEntry.onRemove(player, prevEntry)
        end

        player:setCharVar(varName, resolved.id)
    end

    if targetJob == player:getMainJob() then
        spec.refreshPlayer(player)
    end

    if opts.protoSync then
        spec.sendState(player)
    end

    return resolved, nil
end

function spec.clear(player, jobId, opts)
    opts = opts or {}
    if player == nil then
        return false, 'Invalid player.'
    end

    local targetJob = jobId or player:getMainJob()
    local varName = spec.getVarName(targetJob)
    if varName == nil then
        return false, 'No crystals configured for this job.'
    end

    local okSwap, swapErr = spec.canSwap(player)
    if not okSwap then
        return false, swapErr
    end

    local prevId = player:getCharVar(varName)
    if prevId > 0 and targetJob == player:getMainJob() then
        local prevEntry = spec.resolve(targetJob, prevId)
        spec.removeAppliedMods(player, false)
        if prevEntry ~= nil and type(prevEntry.onRemove) == 'function' then
            prevEntry.onRemove(player, prevEntry)
        end
    end

    player:setCharVar(varName, 0)

    if targetJob == player:getMainJob() then
        spec.refreshPlayer(player)
        if prevId > 0 then
            syncAbilitiesTable(player)
        end
    end

    if opts.protoSync then
        spec.sendState(player)
    end

    return true, nil
end

-----------------------------------
-- Silent Ashita v4 UI Sync Protocol ([OXSPEC]|...)
-----------------------------------
local function sendProto(player, payload)
    if player == nil then
        return
    end

    player:printToPlayer(spec.PROTO_TAG .. payload, xi.msg.channel.SYSTEM_3, '')
end

function spec.sendError(player, message)
    sendProto(player, 'ERR|' .. sanitizeField(message or 'Unknown error'))
end

function spec.sendState(player, optJobId)
    if player == nil then
        return
    end

    local jobId = optJobId or player:getMainJob()
    local lvl = spec.getPlayerJobLevel(player, jobId)
    local active = spec.get(player, jobId)
    local activeId = active and active.id or 0
    local activeKey = active and active.key or ''
    local activeName = active and active.name or 'None'
    local activeIcon = active and active.icon or ''
    local activeUnlocked = (active ~= nil and spec.isLevelEligible(player, jobId, active)) and 1 or 0

    sendProto(player, string.format(
        'STATE|%u|%s|%s|%u|%u|%s|%s|%s|%u',
        jobId,
        sanitizeField(spec.getJobKey(jobId)),
        sanitizeField(spec.getJobName(jobId)),
        lvl,
        activeId,
        sanitizeField(activeKey),
        sanitizeField(activeName),
        sanitizeField(activeIcon),
        activeUnlocked
    ))
end

function spec.sendSync(player, optJobId)
    if player == nil then
        return
    end

    local jobId = optJobId or player:getMainJob()
    local lvl = spec.getPlayerJobLevel(player, jobId)
    local active = spec.get(player, jobId)
    local activeId = active and active.id or 0
    local crystals = spec.list(jobId)

    spec.sendState(player, jobId)
    sendProto(player, string.format('BEGIN|%u|%s|%u|%u',
        jobId,
        sanitizeField(spec.getJobName(jobId)),
        lvl,
        #crystals))

    for _, entry in ipairs(crystals) do
        local socketed = (entry.id == activeId) and 1 or 0
        local reqLvl = tonumber(entry.reqLevel) or spec.DEFAULT_REQ_LEVEL
        local unlocked = (lvl >= reqLvl) and 1 or 0
        sendProto(player, string.format(
            'CRYSTAL|%u|%u|%s|%s|%s|%s|%u|%u|%s|%u|%u',
            jobId,
            entry.id,
            sanitizeField(entry.key),
            sanitizeField(entry.name),
            sanitizeField(entry.role),
            sanitizeField(entry.icon),
            tonumber(entry.itemId) or 0,
            socketed,
            sanitizeField(entry.description),
            reqLvl,
            unlocked
        ))
        for idx, line in ipairs(entry.highlights or {}) do
            sendProto(player, string.format(
                'HIGHLIGHT|%u|%u|%u|%s',
                jobId,
                entry.id,
                idx,
                sanitizeField(line)
            ))
        end
    end

    sendProto(player, string.format('END|%u', jobId))
end

-----------------------------------
-- Crystal Socket Binary Protocol Helpers (0x11F / 0x1FF)
-----------------------------------
function spec.getCrystalSnapshot(player)
    if player == nil then
        return nil
    end

    spec.ensureUpToDate(player)

    local jobsOut = {}
    for jobId, job in pairs(spec.jobs) do
        local ownedMask = 0
        for _, entry in ipairs(job.ordered or {}) do
            if entry.id >= 1 and entry.id <= 7 and spec.isLevelEligible(player, jobId, entry) then
                ownedMask = bit.bor(ownedMask, bit.lshift(1, entry.id))
            end
        end

        local active = spec.get(player, jobId)
        local activeId = (active ~= nil and spec.isLevelEligible(player, jobId, active)) and tonumber(active.id) or 0
        jobsOut[jobId] =
        {
            ownedMask    = ownedMask,
            activeBranch = activeId,
        }
    end

    return
    {
        mainJob = player:getMainJob(),
        mainLvl = player:getMainLvl(),
        jobs    = jobsOut,
    }
end

function spec.getCrystalCatalog(player, optJobId)
    if player == nil then
        return nil
    end

    local jobId = tonumber(optJobId) or 0
    if jobId <= 0 then
        jobId = player:getMainJob()
    end

    local entriesOut = {}
    for _, entry in ipairs(spec.list(jobId)) do
        local highlights = {}
        for _, line in ipairs(entry.highlights or {}) do
            table.insert(highlights, tostring(line or ''))
        end

        table.insert(entriesOut,
        {
            id          = tonumber(entry.id) or 0,
            key         = tostring(entry.key or ''),
            name        = tostring(entry.name or ''),
            role        = tostring(entry.role or ''),
            icon        = tostring(entry.icon or ''),
            reqLevel    = tonumber(entry.reqLevel) or spec.DEFAULT_REQ_LEVEL,
            description = tostring(entry.description or ''),
            highlights  = highlights,
        })
    end

    return
    {
        jobId   = jobId,
        jobName = spec.getJobName(jobId),
        entries = entriesOut,
    }
end

function spec.handleCrystalSelect(player, jobId, branch, busy)
    if player == nil then
        return 4
    end

    if jobId ~= player:getMainJob() then
        return 2
    end

    local job = spec.jobs[jobId]
    if job == nil or branch == nil or branch < 0 or branch > 7 then
        return 4
    end

    if branch > 0 then
        local entry = spec.resolve(jobId, branch)
        if entry == nil then
            return 4
        end

        if busy then
            return 3
        end

        if not spec.isLevelEligible(player, jobId, entry) then
            return 1
        end

        local selected = spec.set(player, jobId, branch)
        return selected ~= nil and 0 or 3
    else
        if busy then
            return 3
        end

        local ok = spec.clear(player, jobId)
        return ok and 0 or 3
    end
end

-----------------------------------
-- Built-in Scholar Crystals
-----------------------------------
if xi.job and xi.job.SCH then
    spec.registerJob(xi.job.SCH, 'SCH',
    {
        {
            id             = 1,
            key            = 'medic',
            name           = 'Medic',
            role           = 'Light Arts / Eos Support',
            icon           = 'white_prism',
            extraAbilities = { 231 },
            extraTraits    = { 144 },
            description    = 'Light Arts spec: Call Eos faerie companion, safer Sublimation, and automatic Accession for Cure and Regen spells.',
            highlights     =
            {
                'Unlocks Call Eos faerie companion (auto -na/Erase & stackable Regen).',
                'Addendum: White lasts 2 hours.',
                'Sublimation charges 2x faster with no HP drain.',
                'Cure & Regen spells gain free 10y Accession AoE without Stratagem cost.',
            },
        },
        {
            id             = 2,
            key            = 'sage',
            name           = 'Sage',
            role           = 'Dark Arts / Titania & Helix',
            icon           = 'onyx_tome',
            extraAbilities = { 289 },
            extraTraits    = { 145 },
            description    = 'Dark Arts spec: Call Titania dark faerie companion, permanent Ebullience, stronger Helix spells, and improved elemental casting.',
            highlights     =
            {
                'Unlocks Call Titania dark faerie companion (enfeebling & elemental nuking).',
                'Addendum: Black lasts 2 hours.',
                'Permanent Ebullience active for black magic.',
                'Helix damage +50% and Helix duration extended to 2 hours.',
                'Magic Attack Bonus +30 and elemental spells bypass 10% target MEVA.',
            },
        },
    })
end

return spec
