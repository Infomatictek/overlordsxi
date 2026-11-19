-- OverlordsXI Soul Action Registry (foundation, opt-in)
-- Pure data/validation module. Does not alter live casting or client packets.
-- Source action IDs remain internal; presentation names are Soul-specific.
local M = { VERSION = 1, definitions = {} }
local validKinds = { spell = true, ability = true, weaponskill = true }
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
-- Registration is deliberately fail-closed: no implicit base-job permissions.
-- Enforcement hooks will only be enabled after all existing Souls are audited.
function M.register(soulKey, actions)
    checkText(soulKey, 'soulKey')
    assert(M.definitions[soulKey] == nil, 'duplicate Soul action registration: ' .. soulKey)
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
    M.definitions[soulKey] = copy
end
function M.resolve(soulKey, kind, id)
    local soul = M.definitions[soulKey]
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
return M
