-----------------------------------
-- Export compiled WS talent contracts (JSON) and run 66-Soul static invariants.
-- Usage: luajit tools/export_ws_talent_contracts.lua
-----------------------------------
xi =
{
    job = { WAR=1,MNK=2,WHM=3,BLM=4,RDM=5,THF=6,PLD=7,DRK=8,BST=9,BRD=10,RNG=11,SAM=12,NIN=13,DRG=14,SMN=15,BLU=16,COR=17,PUP=18,DNC=19,SCH=20,GEO=21,RUN=22 },
    skill = { HAND_TO_HAND=1,DAGGER=2,SWORD=3,GREAT_SWORD=4,AXE=5,GREAT_AXE=6,SCYTHE=7,POLEARM=8,KATANA=9,GREAT_KATANA=10,CLUB=11,STAFF=12,ARCHERY=25,MARKSMANSHIP=26,THROWING=27 },
    element = setmetatable({}, { __index = function(_, k) return 1 end }),
    effect = {
        STONESKIN=37, REGEN=42, REFRESH=43, DEFENSE_BOOST=93, PHALANX=116,
    },
    mod = setmetatable({}, { __index = function(_, k) return 1 end }),
    slot = { MAIN=0, SUB=1, RANGED=2, AMMO=3 },
    msg = { channel = { SYSTEM_3 = 1 } },
}
setmetatable(xi.effect, { __index = function(_, k) return 100 end })

require('modules/custom/lua/soulspire_ws_talents')
local E = require('modules/custom/lua/soulspire_ws_eligibility')
local M = require('modules/custom/lua/soulspire_ws_soul_mechanics')
local C = require('modules/custom/lua/soulspire_ws_talent_contracts')
local cat = xi.soulspire.wsCatalog
local t   = xi.soulspire.wsTalents

local treeFiles = { 'axe','club','dagger','gaxe','gkatana','gs','katana','polearm','ranged','scythe','staff','sword','throwing' }
for _, tf in ipairs(treeFiles) do
    require('modules/custom/lua/soulspire_ws_trees_' .. tf)
end
require('modules/custom/lua/soulspire_ws_evolution')

local function esc(s)
    s = tostring(s or '')
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local function isArray(tbl)
    local n = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= 'number' or k < 1 or math.floor(k) ~= k then
            return false
        end
        n = n + 1
    end
    return n > 0 and n == #tbl
end

local function encode(val)
    local tv = type(val)
    if val == nil then return 'null'
    elseif tv == 'boolean' then return val and 'true' or 'false'
    elseif tv == 'number' then
        if val ~= val or val == math.huge or val == -math.huge then return '0' end
        return tostring(val)
    elseif tv == 'string' then return esc(val)
    elseif tv == 'table' then
        if next(val) == nil then return '[]' end
        if isArray(val) then
            local parts = {}
            for i = 1, #val do parts[i] = encode(val[i]) end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local keys = {}
            for k in pairs(val) do table.insert(keys, tostring(k)) end
            table.sort(keys)
            local parts = {}
            for _, k in ipairs(keys) do
                local v = val[k]
                if v ~= nil then
                    table.insert(parts, esc(k) .. ':' .. encode(v))
                end
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    end
    return 'null'
end

local contracts = {}
local bySoulSummary = {}
local branchCounts = { damage = 0, utility = 0, soul = 0, skillchain = 0, evolution = 0 }
local effectTypeCounts = {}
local totalApprovedTrees = 0

for _, skey in ipairs(E.CANONICAL_SOULS) do
    local eligWs = E.getEligibleWsIds(skey)
    local soulContracts = 0
    local soulNonSc = 0
    local soulBranches = { damage = 0, utility = 0, soul = 0, skillchain = 0, evolution = 0 }
    local prof = M.getProfile(skey)
    assert(prof ~= nil, 'Missing soul mechanics profile for ' .. skey)

    for _, wsId in ipairs(eligWs) do
        local tree = t.getTreeForWS(wsId, nil, nil, skey)
        assert(tree ~= nil, 'Expected non-nil tree for eligible ' .. skey .. ' ws=' .. wsId)
        totalApprovedTrees = totalApprovedTrees + 1

        for _, node in ipairs(tree.nodes) do
            -- Respect explicit per-node allowedSpecs / allowedJobs (e.g., Sanguine Blade evolution)
            local nodeAllowed = true
            if node.allowedSpecs or node.allowedJobs then
                local jid = xi.job[E.SOULS[skey].job]
                nodeAllowed = (node.allowedJobs and jid and node.allowedJobs[jid]) or
                    (node.allowedSpecs and node.allowedSpecs[skey]) or false
            end
            if nodeAllowed then
            -- Role guardrail invariant assertions
            if prof.tier == 'Damage' and type(node.effect) == 'table' then
                assert(node.effect.selfHeal == nil, 'Pure DPS selfHeal violation: ' .. skey .. ' ws=' .. wsId)
                assert(node.effect.selfMaxHpHealPct == nil, 'Pure DPS selfMaxHpHealPct violation: ' .. skey .. ' ws=' .. wsId)
                assert(node.effect.partyHealPct == nil, 'Pure DPS partyHealPct violation: ' .. skey .. ' ws=' .. wsId)
                assert(node.effect.hpDrain == nil, 'Pure DPS hpDrain violation: ' .. skey .. ' ws=' .. wsId)
            end
            if prof.noMp and type(node.effect) == 'table' then
                assert(node.effect.mpDrain == nil and node.effect.mpReturn == nil, 'No-MP violation: ' .. skey .. ' ws=' .. wsId)
            end
            if not prof.pet and type(node.effect) == 'table' then
                assert(node.effect.eosHeal == nil and node.effect.petTp == nil, 'Petless hook violation: ' .. skey .. ' ws=' .. wsId)
            end

            local contract = C.compileNodeContract(tree.ws, skey, node, t.getRankReqLevel)
            -- Compact wire form: taxonomy metadata lives once in effect_taxonomy[et]
            local slimEffects = {}
            for _, ef in ipairs(contract.effects) do
                table.insert(slimEffects, { t = ef.effect_type, tgt = ef.target })
            end
            table.insert(contracts, {
                id = contract.talent_id,
                soul = contract.soul_key,
                ws = contract.ws_id,
                node = contract.node_key,
                br = contract.branch,
                tier = contract.tier,
                col = contract.col,
                mr = contract.max_rank,
                rlvl = contract.prerequisites.req_level_rank1,
                rpts = contract.prerequisites.req_ws_points,
                req = contract.prerequisites.requires_node,
                exg = contract.exclusive_group,
                trig = contract.trigger_event,
                cond = contract.activation_conditions,
                eff = slimEffects,
                lvls = contract.supported_levels,
                tid = contract.test_id,
            })
            soulContracts = soulContracts + 1
            if contract.branch ~= 'skillchain' then
                soulNonSc = soulNonSc + 1
            end
            branchCounts[contract.branch] = (branchCounts[contract.branch] or 0) + 1
            soulBranches[contract.branch] = (soulBranches[contract.branch] or 0) + 1
            for _, ef in ipairs(contract.effects) do
                effectTypeCounts[ef.effect_type] = (effectTypeCounts[ef.effect_type] or 0) + 1
            end
            end
        end
    end

    bySoulSummary[skey] = {
        soul_key          = skey,
        job               = E.SOULS[skey].job,
        role              = E.SOULS[skey].role,
        tier              = E.SOULS[skey].tier,
        eligible_ws_count = #eligWs,
        total_contracts   = soulContracts,
        non_sc_contracts  = soulNonSc,
        branches          = soulBranches,
        soul_hook_id      = prof.soulHook and prof.soulHook.id or '',
        soul_hook_kind    = prof.soulHook and prof.soulHook.kind or '',
    }
end

local outObj = {
    schema_version  = C.CONTRACT_SCHEMA_VERSION,
    canonical_souls = #E.CANONICAL_SOULS,
    summary = {
        approved_soul_ws_trees = totalApprovedTrees,
        total_contracts        = #contracts,
        branch_counts          = branchCounts,
        effect_type_counts     = effectTypeCounts,
        taxonomy_effect_types  = 0,
    },
    effect_taxonomy = C.EFFECT_TAXONOMY,
    by_soul_summary = bySoulSummary,
    contracts       = contracts,
}
for _ in pairs(C.EFFECT_TAXONOMY) do
    outObj.summary.taxonomy_effect_types = outObj.summary.taxonomy_effect_types + 1
end

local outPath = 'modules/custom/data/ws_talent_contracts.json'
local f = assert(io.open(outPath, 'w'))
f:write(encode(outObj))
f:write('\n')
f:close()

print(string.format(
    'Exported %s: souls=%d approvedTrees=%d totalContracts=%d taxonomyTypes=%d',
    outPath, outObj.canonical_souls, totalApprovedTrees, #contracts, outObj.summary.taxonomy_effect_types
))
