-----------------------------------
-- OverlordsXI Job Specs
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.spec = xi.overlords.spec or {}

local spec = xi.overlords.spec

spec.jobs = spec.jobs or {}
spec.jobKeys = spec.jobKeys or {}

local function normalizeKey(value)
    if value == nil then
        return nil
    end

    return string.lower(tostring(value))
end

function spec.registerJob(jobId, jobKey, specs)
    local job =
    {
        key = jobKey,
        byId = {},
        byKey = {},
        ordered = {},
    }

    for _, entry in ipairs(specs) do
        job.byId[entry.id] = entry
        job.byKey[normalizeKey(entry.key)] = entry
        table.insert(job.ordered, entry)
    end

    spec.jobs[jobId] = job
    spec.jobKeys[jobId] = jobKey
end

function spec.getVarName(jobId)
    local jobKey = spec.jobKeys[jobId]
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
        return job.byId[specKeyOrId]
    end

    local numericId = tonumber(specKeyOrId)
    if numericId ~= nil and job.byId[numericId] ~= nil then
        return job.byId[numericId]
    end

    return job.byKey[normalizeKey(specKeyOrId)]
end

function spec.get(player, jobId)
    local varName = spec.getVarName(jobId or player:getMainJob())
    if varName == nil then
        return nil
    end

    return spec.resolve(jobId or player:getMainJob(), player:getCharVar(varName))
end

function spec.is(player, jobId, specKey)
    local activeSpec = spec.get(player, jobId)
    return activeSpec ~= nil and normalizeKey(activeSpec.key) == normalizeKey(specKey)
end

function spec.set(player, jobId, specKeyOrId)
    local resolved = spec.resolve(jobId, specKeyOrId)
    local varName = spec.getVarName(jobId)
    if resolved == nil or varName == nil then
        return nil
    end

    player:setCharVar(varName, resolved.id)
    return resolved
end

function spec.clear(player, jobId)
    local varName = spec.getVarName(jobId)
    if varName == nil then
        return false
    end

    player:setCharVar(varName, 0)
    return true
end

function spec.list(jobId)
    local job = spec.jobs[jobId]
    if job == nil then
        return {}
    end

    return job.ordered
end

spec.registerJob(xi.job.SCH, 'SCH',
{
    {
        id = 1,
        key = 'medic',
        name = 'Medic',
        description = 'Light Arts spec: safer Sublimation and automatic Accession for Cure and Regen spells.',
    },
    {
        id = 2,
        key = 'sage',
        name = 'Sage',
        description = 'Dark Arts spec: permanent Ebullience, stronger Helix spells, and improved elemental casting.',
    },
})

return spec
