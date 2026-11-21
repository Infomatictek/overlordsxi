-----------------------------------
-- SoulspireXI — WS Talent Foundation Pass 2.0 LuaJIT Runtime Test Suite
--
-- Exercises the REAL Lua runtime modules:
--   - soulspire_ws_eligibility.lua
--   - soulspire_ws_soul_mechanics.lua
--   - soulspire_ws_talent_contracts.lua
--   - soulspire_ws_telemetry.lua
--   - soulspire_ws_talents.lua
--   - soulspire_ws_spec_profiles.lua
--   - soulspire_ws_trees_*.lua + soulspire_ws_evolution.lua
-----------------------------------
xi =
{
    job = { WAR=1,MNK=2,WHM=3,BLM=4,RDM=5,THF=6,PLD=7,DRK=8,BST=9,BRD=10,RNG=11,SAM=12,NIN=13,DRG=14,SMN=15,BLU=16,COR=17,PUP=18,DNC=19,SCH=20,GEO=21,RUN=22 },
    skill = { HAND_TO_HAND=1,DAGGER=2,SWORD=3,GREAT_SWORD=4,AXE=5,GREAT_AXE=6,SCYTHE=7,POLEARM=8,KATANA=9,GREAT_KATANA=10,CLUB=11,STAFF=12,ARCHERY=25,MARKSMANSHIP=26,THROWING=27 },
    element = setmetatable({}, { __index = function(_, k) return 1 end }),
    effect = { STONESKIN=37, REGEN=42, REFRESH=43, DEFENSE_BOOST=93, PHALANX=116 },
    mod = setmetatable({}, { __index = function(_, k) return 1 end }),
    slot = { MAIN=0, SUB=1, RANGED=2, AMMO=3 },
    msg = { channel = { SYSTEM_3 = 1 } },
}
setmetatable(xi.effect, { __index = function(_, k) return 100 end })

require('modules/custom/lua/soulspire_ws_talents')
local E = require('modules/custom/lua/soulspire_ws_eligibility')
local M = require('modules/custom/lua/soulspire_ws_soul_mechanics')
local C = require('modules/custom/lua/soulspire_ws_talent_contracts')
local W = require('modules/custom/lua/soulspire_ws_telemetry')
local P = require('modules/custom/lua/soulspire_ws_spec_profiles')
local cat = xi.soulspire.wsCatalog
local t   = xi.soulspire.wsTalents

local treeFiles = { 'axe','club','dagger','gaxe','gkatana','gs','katana','polearm','ranged','scythe','staff','sword','throwing' }
for _, tf in ipairs(treeFiles) do
    require('modules/custom/lua/soulspire_ws_trees_' .. tf)
end
require('modules/custom/lua/soulspire_ws_evolution')

-- Mock spec provider + mock player
local activeSpecs = {}
xi.soulspire.spec =
{
    get = function(player, jid) return activeSpecs[player._id] end,
    isLevelEligible = function() return true end,
}

local function makePlayer(id, jobId, level, specId, specKey)
    local p =
    {
        _id = id,
        _job = jobId,
        _lvl = level,
        _tp = 1000,
        _mp = 100,
        _charVars = {},
        _localVars = {},
        _packets = {},
    }
    activeSpecs[id] = { id = specId, key = specKey, name = specKey, role = 'Damage' }
    function p:getID() return self._id end
    function p:getMainJob() return self._job end
    function p:getJobLevel() return self._lvl end
    function p:getTP() return self._tp end
    function p:addTP(v) self._tp = math.max(0, math.min(3000, self._tp + v)) end
    function p:getMP() return self._mp end
    function p:addMP(v) self._mp = math.max(0, self._mp + v) end
    function p:getCharVar(k) return self._charVars[k] or 0 end
    function p:setCharVar(k, v) self._charVars[k] = v end
    function p:getCharVarsWithPrefix(pfx)
        local out = {}
        for k, v in pairs(self._charVars) do
            if string.sub(k, 1, #pfx) == pfx then out[k] = v end
        end
        return out
    end
    function p:getLocalVar(k) return self._localVars[k] or 0 end
    function p:setLocalVar(k, v) self._localVars[k] = v end
    function p:getWeaponSkillType() return 0 end
    function p:sendTalentPacket(payload) table.insert(self._packets, payload) end
    function p:printToPlayer(msg) table.insert(self._packets, msg) end
    return p
end

local passed = 0
local function check(name, fn)
    fn()
    passed = passed + 1
    print('[PASS] ' .. name)
end

-- 1. All 66 Souls present and have real Soul mechanics profiles
check('all_66_canonical_souls_have_profiles_and_eligibility', function()
    assert(#E.CANONICAL_SOULS == 66, 'Expected 66 canonical souls')
    for _, skey in ipairs(E.CANONICAL_SOULS) do
        assert(E.SOULS[skey] ~= nil, 'Missing E.SOULS for ' .. skey)
        assert(M.getProfile(skey) ~= nil, 'Missing M.PROFILES for ' .. skey)
        assert(M.getProfile(skey).soulHook ~= nil, 'Missing soulHook for ' .. skey)
        local elig = E.getEligibleWsIds(skey)
        assert(#elig > 0, 'Soul has 0 eligible WSs: ' .. skey)
    end
end)

-- 2. Strict weapon eligibility: Berserker allows Great Axe (#80) & Axe (#64), rejects Sword (#32) & Staff (#176)
check('strict_eligibility_berserker_and_spartan_and_bladewheel', function()
    local zrk = makePlayer(1, xi.job.WAR, 75, 2, 'berserker')
    assert(t.isWSEligibleForPlayer(zrk, 80, xi.job.WAR) == true, 'Berserker must allow Great Axe #80')
    assert(t.isWSEligibleForPlayer(zrk, 64, xi.job.WAR) == true, 'Berserker must allow Axe #64')
    assert(t.isWSEligibleForPlayer(zrk, 32, xi.job.WAR) == false, 'Berserker must reject Sword #32')
    assert(t.isWSEligibleForPlayer(zrk, 176, xi.job.WAR) == false, 'Berserker must reject Staff #176')
    assert(t.getTreeForWS(32, zrk, xi.job.WAR) == nil, 'Ineligible WS must return nil tree')

    local ok, err = t.canInvest(zrk, xi.job.WAR, 32, 'ftp')
    assert(ok == false and string.find(err, 'not eligible'), 'canInvest must reject ineligible WS')

    -- Spartan allows Polearm (#112), rejects Great Axe (#80)
    local spt = makePlayer(2, xi.job.WAR, 75, 3, 'spartan')
    assert(t.isWSEligibleForPlayer(spt, 112, xi.job.WAR) == true)
    assert(t.isWSEligibleForPlayer(spt, 80, xi.job.WAR) == false)

    -- Bladewheel allows Throwing (#241) and Dagger (#16), rejects Sword (#32)
    local blw = makePlayer(3, xi.job.DNC, 75, 3, 'bladewheel')
    assert(t.isWSEligibleForPlayer(blw, 241, xi.job.DNC) == true)
    assert(t.isWSEligibleForPlayer(blw, 16, xi.job.DNC) == true)
    assert(t.isWSEligibleForPlayer(blw, 32, xi.job.DNC) == false)
end)

-- 3. UI catalog sync sends ONLY eligible WSs
check('ui_catalog_sync_filters_by_soul_eligibility', function()
    local zrk = makePlayer(4, xi.job.WAR, 75, 2, 'berserker')
    t.sendCatalogSync(zrk)
    local catPayload = ''
    for _, pkt in ipairs(zrk._packets) do
        if string.sub(pkt, 1, 4) == 'CAT|' then
            catPayload = catPayload .. ',' .. string.sub(pkt, 5)
        end
    end
    assert(string.find(catPayload, '80:6:Shield Break', 1, true) ~= nil, 'Expected Shield Break in Berserker CAT')
    assert(string.find(catPayload, '32:3:Fast Blade', 1, true) == nil, 'Fast Blade must NOT appear in Berserker CAT')
end)

-- 4. Allocation, tier prerequisites, refund, reset, and persistence
check('allocation_prereqs_refund_and_persistence', function()
    local zrk = makePlayer(5, xi.job.WAR, 10, 2, 'berserker')
    local tree = t.getTreeForWS(80, zrk, xi.job.WAR)
    assert(tree ~= nil and #tree.nodes >= 12)
    local t1Node = tree.nodes[1]
    local t4Node = nil
    for _, n in ipairs(tree.nodes) do
        if n.tier == 4 and (n.scTier or 0) == 0 then t4Node = n; break end
    end
    assert(t4Node ~= nil)
    -- Tier 4 blocked at Lv 10 / 0 WS pts
    local ok4 = t.canInvest(zrk, xi.job.WAR, 80, t4Node.key)
    assert(ok4 == false, 'Tier 4 must be blocked at Lv 10 / 0 pts')

    -- Invest T1 rank 1
    local ok1, newRank = t.invest(zrk, xi.job.WAR, 80, t1Node.key)
    assert(ok1 == true and newRank == 1, 'T1 rank 1 invest failed')
    assert(t.getWSSpent(zrk, xi.job.WAR, 80) == 1)

    -- Refund T1 rank 1
    local okRef = t.refundNode(zrk, xi.job.WAR, 80, t1Node.key)
    assert(okRef == true)
    assert(t.getWSSpent(zrk, xi.job.WAR, 80) == 0)
end)

-- 5. Evolution mutual exclusion + PLD Sanguine Blade vs Scarlet Weaver RDM
check('evolution_mutual_exclusion_and_sanguine_blade_restrictions', function()
    local scw = makePlayer(6, xi.job.RDM, 75, 3, 'scarletweaver')
    -- Scarlet Weaver can learn Arcane Reaver, NOT Blood Discipline or Vital Control
    local okArc = t.invest(scw, xi.job.RDM, 47, 'e_sg_arcane')
    assert(okArc == true, 'Scarlet Weaver must be able to learn e_sg_arcane')
    local okBld = t.canInvest(scw, xi.job.RDM, 47, 'e_sg_blood')
    assert(okBld == false, 'Pure DPS Scarlet Weaver must NOT learn e_sg_blood')
    local okCtl = t.canInvest(scw, xi.job.RDM, 47, 'e_sg_control')
    assert(okCtl == false, 'Pure DPS Scarlet Weaver must NOT learn e_sg_control')

    -- Mutual exclusion on Combo (#1) for Black Belt
    local bbt = makePlayer(7, xi.job.MNK, 75, 3, 'blackbelt')
    assert(t.invest(bbt, xi.job.MNK, 1, 'e_co_open') == true)
    local okExcl, errExcl = t.canInvest(bbt, xi.job.MNK, 1, 'e_co_flow')
    assert(okExcl == false and string.find(errExcl, 'exclusive'), 'Exclusive stage choice must be blocked')
end)

-- 6. Safe deterministic migration/refund for legacy ineligible investments
check('safe_deterministic_migration_refund_preserves_eligible', function()
    local zrk = makePlayer(8, xi.job.WAR, 75, 2, 'berserker')
    -- Invest legitimately in Great Axe #80
    local tree80 = t.getTreeForWS(80, zrk, xi.job.WAR)
    assert(t.invest(zrk, xi.job.WAR, 80, tree80.nodes[1].key) == true)
    -- Simulate legacy pre-2.0 invested points in Sword #32 (now ineligible for Berserker)
    zrk:setCharVar(t.getVarName(xi.job.WAR, 32, zrk), 3) -- slot 1 = rank 3

    local rep = t.reconcileIneligibleAllocations(zrk, xi.job.WAR)
    assert(rep.refundedPoints == 3, 'Expected 3 refunded points, got ' .. tostring(rep.refundedPoints))
    assert(#rep.refundedWs == 1 and rep.refundedWs[1].wsId == 32)
    assert(t.getWSSpent(zrk, xi.job.WAR, 80) == 1, 'Eligible WS #80 must be preserved')
    assert(zrk:getCharVar(t.getVarName(xi.job.WAR, 32, zrk)) == 0, 'Ineligible WS #32 charVar must be cleared')
end)

-- 7. Soul switching isolation & distinct Soul-branch mechanics on shared WS
check('soul_switching_isolation_and_distinct_soul_hooks', function()
    local p = makePlayer(9, xi.job.WAR, 75, 2, 'berserker')
    local treeZrk = t.getTreeForWS(80, p, xi.job.WAR)
    local zrkC = C.compileNodeContract(treeZrk.ws, 'berserker', treeZrk.nodes[9], t.getRankReqLevel)
    assert(t.invest(p, xi.job.WAR, 80, treeZrk.nodes[1].key) == true)

    -- Switch Soul on same job to Commander (specId = 1)
    activeSpecs[9] = { id = 1, key = 'commander', name = 'Commander', role = 'Support' }
    assert(t.getWSSpent(p, xi.job.WAR, 80) == 0, 'Commander spec must have isolated talent storage')
    local treeCmd = t.getTreeForWS(80, p, xi.job.WAR)
    local cmdC = C.compileNodeContract(treeCmd.ws, 'commander', treeCmd.nodes[9], t.getRankReqLevel)
    assert(zrkC.talent_id ~= cmdC.talent_id, 'Berserker and Commander must have distinct Soul contracts on WS #80')
end)

-- 8. Live Combat Instrumentation & Soul-hook post-WS execution
check('live_telemetry_and_soul_hook_execution', function()
    W.ENABLED = true
    W.clearRecent()

    -- Kurogane clone_sync hook
    local krg = makePlayer(10, xi.job.NIN, 75, 1, 'kurogane')
    local krgProf = M.getProfile('kurogane')
    local krgTree = t.getTreeForWS(128, krg, xi.job.NIN) -- Blade: Rin
    local evKrg = W.applySoulHookPostWS(krg, nil, krgTree.ws, 'kurogane', krgTree.nodes[9], 3, krgProf.soulHook)
    assert(evKrg ~= nil and evKrg.status == W.STATUS.APPLIED)
    assert(krg:getLocalVar('OX_KRG_CLONE_SYNC') == 2, 'Expected OX_KRG_CLONE_SYNC == 2')
    assert(evKrg.applied_effects.soul_resource.hook_id == 'nin_kurogane_clone_sync')

    -- Bandit bounded TP refund
    local bnd = makePlayer(11, xi.job.THF, 75, 2, 'bandit')
    bnd._tp = 100
    local bndProf = M.getProfile('bandit')
    local bndTree = t.getTreeForWS(16, bnd, xi.job.THF) -- Wasp Sting
    local evBnd = W.applySoulHookPostWS(bnd, nil, bndTree.ws, 'bandit', bndTree.nodes[9], 5, bndProf.soulHook)
    assert(evBnd.status == W.STATUS.APPLIED and bnd:getTP() == 360 and evBnd.applied_effects.tp_refund == 260)

    -- Chi Weaver MP restriction produces blocked_by_restriction
    local chw = makePlayer(12, xi.job.MNK, 75, 2, 'chiweaver')
    local chwTree = t.getTreeForWS(2, chw, xi.job.MNK)
    local evChw = W.applySoulHookPostWS(chw, nil, chwTree.ws, 'chiweaver', chwTree.nodes[9], 1, { id = 'bad_mp', kind = 'mp_siphon', mpReturn = { 20 } })
    assert(evChw.status == W.STATUS.BLOCKED_BY_RESTRICTION and evChw.reason == 'no_mp_soul_restriction')

    W.ENABLED = false
end)

print(string.format('ALL %d LUAJIT RUNTIME TESTS PASSED!', passed))
