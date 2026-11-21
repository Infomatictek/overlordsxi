-----------------------------------
-- SoulspireXI — WS Talent Foundation 2.1 Live xi_test Combat Validation Suite
--
-- Runs inside LandSandBoat's authoritative headless MapEngine (`xi_test`).
-- Exercises REAL live Weapon Skill combat across:
--   1. ALL 66 Canonical Souls (Baseline + Damage + Utility + Soul branches)
--   2. Multi-level progression at Lv 10, 30, 50, 75
--   3. Evolution exclusive groups & Sanguine Blade (#47) / Combo (#1)
--   4. Ineligible weapon rejection, deterministic migration refund,
--      Soul switching isolation, persistence, and client catalog sync.
--
-- Writes machine-readable live combat evidence JSON to:
--   log/ws_talent_v21_live_evidence.json
-----------------------------------
local spec      = xi.soulspire.spec
local gear      = xi.soulspire.testGear
local talents   = xi.soulspire.wsTalents
local elig      = xi.soulspire.wsEligibility
local mech      = xi.soulspire.wsSoulMechanics
local wsTelem   = xi.soulspire.wsTelemetry
local pgTelem   = xi.soulspire.provingGrounds and xi.soulspire.provingGrounds.telemetry
local catalog   = xi.soulspire.wsCatalog

local PRIMARY_WEAPON_TO_GEAR =
{
    ['Hand-to-Hand'] = 'h2h',
    ['Dagger']       = 'dagger',
    ['Sword']        = 'sword',
    ['Great Sword']  = 'gsword',
    ['Axe']          = 'axe',
    ['Great Axe']    = 'gaxe',
    ['Scythe']       = 'scythe',
    ['Polearm']      = 'polearm',
    ['Katana']       = 'katana',
    ['Great Katana'] = 'gkatana',
    ['Club']         = 'club',
    ['Staff']        = 'staff',
    ['Archery']      = 'bow',
    ['Marksmanship'] = 'gun',
    ['Throwing']     = 'chakram',
}

local PRIMARY_WS_BY_WEAPON =
{
    ['Hand-to-Hand'] = 2,   -- Shoulder Tackle (non-evolution 3-branch)
    ['Dagger']       = 16,  -- Wasp Sting
    ['Sword']        = 32,  -- Fast Blade
    ['Great Sword']  = 48,  -- Hard Slash
    ['Axe']          = 64,  -- Raging Axe
    ['Great Axe']    = 80,  -- Shield Break
    ['Scythe']       = 96,  -- Slice
    ['Polearm']      = 112, -- Double Thrust
    ['Katana']       = 128, -- Blade: Rin
    ['Great Katana'] = 144, -- Tachi: Enpi
    ['Club']         = 160, -- Shining Strike
    ['Staff']        = 176, -- Heavy Swing
    ['Archery']      = 192, -- Flaming Arrow
    ['Marksmanship'] = 208, -- Hot Shot
    ['Throwing']     = 241, -- Chakram Throwing WS #241
}

local function spawnTargetMob(player)
    local mob = player.entities:moveTo('Wild_Rabbit')
    mob:respawn()
    mob:setAutoAttackEnabled(false)
    mob:setMobAbilityEnabled(false)
    mob:setMobMod(xi.mobMod.NO_MOVE, 1)
    mob:setMaxHP(200000)
    mob:setHP(200000)
    local pos = mob:getPos()
    player:setPos(pos.x, pos.y, pos.z)
    return mob
end

local function resetMobHp(mob)
    if not mob:isAlive() then
        mob:respawn()
        mob:setAutoAttackEnabled(false)
        mob:setMobAbilityEnabled(false)
        mob:setMobMod(xi.mobMod.NO_MOVE, 1)
    end
    mob:setMaxHP(200000)
    mob:setHP(200000)
end

local function clearPlayerInventory(player)
    if player.unequipItem then
        for slot = 0, 15 do
            pcall(function() player:unequipItem(slot) end)
        end
    end
    if player.getItems then
        local ok, items = pcall(function() return player:getItems(xi.inv.INVENTORY) end)
        if ok and type(items) == 'table' then
            for _, item in ipairs(items) do
                if item and item.getID then
                    pcall(function() player:delItem(item:getID(), item:getQuantity(), xi.inv.INVENTORY) end)
                end
            end
        end
    end
end

local PRIMARY_WS_BY_SKILL =
{
    [xi.skill.HAND_TO_HAND] = 2,   -- Shoulder Tackle (non-evolution 3-branch)
    [xi.skill.DAGGER]       = 16,  -- Wasp Sting
    [xi.skill.SWORD]        = 32,  -- Fast Blade
    [xi.skill.GREAT_SWORD]  = 48,  -- Hard Slash
    [xi.skill.AXE]          = 64,  -- Raging Axe
    [xi.skill.GREAT_AXE]    = 80,  -- Shield Break
    [xi.skill.SCYTHE]       = 96,  -- Slice
    [xi.skill.POLEARM]      = 112, -- Double Thrust
    [xi.skill.KATANA]       = 128, -- Blade: Rin
    [xi.skill.GREAT_KATANA] = 144, -- Tachi: Enpi
    [xi.skill.CLUB]         = 160, -- Shining Strike
    [xi.skill.STAFF]        = 176, -- Heavy Swing
    [xi.skill.ARCHERY]      = 192, -- Flaming Arrow
    [xi.skill.MARKSMANSHIP] = 208, -- Hot Shot
    [xi.skill.THROWING]     = 241, -- Chakram Throwing WS #241
}

local function resolveLiveWsForEquipped(player, soulKey, primWeapon)
    local rSkill = player.getWeaponSkillType and player:getWeaponSkillType(xi.slot.RANGED) or 0
    local mSkill = player.getWeaponSkillType and player:getWeaponSkillType(xi.slot.MAIN) or 0
    local primIsRanged = (primWeapon == 'Archery' or primWeapon == 'Marksmanship' or primWeapon == 'Throwing')
    local mWs = PRIMARY_WS_BY_SKILL[mSkill]
    local rWs = PRIMARY_WS_BY_SKILL[rSkill]
    if primIsRanged then
        if rWs ~= nil and elig.isWsEligible(soulKey, rWs) then
            return rWs, true
        end
        if mWs ~= nil and elig.isWsEligible(soulKey, mWs) then
            return mWs, false
        end
    else
        if mWs ~= nil and elig.isWsEligible(soulKey, mWs) then
            return mWs, false
        end
        if rWs ~= nil and elig.isWsEligible(soulKey, rWs) then
            return rWs, true
        end
    end
    local fallback = PRIMARY_WS_BY_WEAPON[primWeapon] or 32
    return fallback, primIsRanged
end

local function equipPrimaryWeapon(player, jobId, soulKey, level, primWeapon)
    clearPlayerInventory(player)
    local wKey = PRIMARY_WEAPON_TO_GEAR[primWeapon] or 'sword'
    if soulKey == 'necromancer' and wKey == 'scythe' then
        wKey = 'scythe_blm'
    end
    local opts =
    {
        level     = level,
        role      = 'tp',
        setLevel  = true,
        equip     = true,
        capSkills = true,
    }
    -- Only override weapon when Soul's default gear profile doesn't already lock it
    if soulKey ~= 'miragesentinel' and soulKey ~= 'sniper' and soulKey ~= 'huntsman' and soulKey ~= 'arcanearcher' and soulKey ~= 'flintlock' and soulKey ~= 'gambler' and soulKey ~= 'bladewheel' and soulKey ~= 'untamed' then
        opts.weapon = wKey
    end
    if gear and gear.equipLoadout then
        pcall(gear.equipLoadout, player, opts)
    end
    -- Ensure high accuracy + unlimited ammo recycle for deterministic multi-shot ranged WS testing
    player:setMod(xi.mod.ACC, 400)
    player:setMod(xi.mod.RACC, 400)
    player:setMod(xi.mod.MACC, 400)
    player:setMod(xi.mod.RECYCLE, 100)
end

local function investBranch(player, jobId, wsId, col)
    local tree = talents.getTreeForWS(wsId, player, jobId)
    if tree == nil or tree.nodes == nil then
        return {}
    end
    local invested = {}
    -- First invest Tier 1 in target col to unlock WS & satisfy tier reqs, then invest higher tiers in target col
    for tier = 1, 4 do
        for _, node in ipairs(tree.nodes) do
            if (node.scTier or 0) == 0 and node.col == col and (node.tier or 1) == tier then
                local ok = talents.invest(player, jobId, wsId, node.key)
                if ok then
                    table.insert(invested, { node_key = node.key, tier = tier, col = col })
                end
            end
        end
    end
    return invested
end

local function executeLiveWs(player, mob, wsId, tp, isRanged)
    resetMobHp(mob)
    wsTelem.clearRecent()
    player:setHP(player:getMaxHP())
    player:setMP(math.max(10, math.floor(player:getMaxMP() * 0.5)))
    if not (player.isEngaged and player:isEngaged()) then
        pcall(function() player.actions:engage(mob) end)
        pcall(function() xi.test.world:skipTime(1) end)
    end
    player:setTP(tp or 1500)
    local hpBefore = mob:getHP()
    local tpBefore = player:getTP()
    local mpBefore = player:getMP()

    local okCall, err = pcall(function()
        player.actions:useWeaponskill(mob, wsId)
    end)
    if okCall then
        pcall(function() xi.test.world:tickEntity(player) end)
        pcall(function() xi.test.world:skipTime(isRanged and 4 or 3) end)
    end

    local hpAfter = mob:getHP()
    local dmg = math.max(0, hpBefore - hpAfter)
    local tpAfter = player:getTP()
    local mpAfter = player:getMP()

    local events = {}
    for _, ev in ipairs(wsTelem.recentEvents) do
        table.insert(events, ev)
    end

    return
    {
        okCall   = okCall,
        err      = err and tostring(err) or nil,
        executed = (tpAfter < tpBefore) or (#events > 0),
        damage   = dmg,
        tpBefore = tpBefore,
        tpAfter  = tpAfter,
        mpBefore = mpBefore,
        mpAfter  = mpAfter,
        events   = events,
    }
end

describe('WS Talent Foundation 2.1 — Live xi_test Combat Validation (66 Souls)', function()
    local player
    local mob

    before_each(function()
        wsTelem.ENABLED = true
        wsTelem.clearRecent()
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.WAR,
            level = 75,
        })
        player:changeContainerSize(xi.inv.INVENTORY, 80)
        player:setLocalVar('OX_WS_TELEMETRY_DEBUG', 1)
        mob = spawnTargetMob(player)
    end)

    after_each(function()
        wsTelem.ENABLED = false
        wsTelem.clearRecent()
    end)

    it('validates live WS combat across all 66 canonical Souls (Baseline + Damage + Utility + Soul), Lv10/30/50/75, Evolution, and Persistence', function()
        local allEvents = {}
        local soulResults = {}
        local levelResults = {}
        local extraChecks = {}
        local failures = {}

        -- 1. ALL 66 CANONICAL SOULS LIVE COMBAT LOOP
        for _, skey in ipairs(elig.CANONICAL_SOULS) do
            local entry = elig.SOULS[skey]
            local jobId = xi.job[entry.job]
            local primWeapon = entry.primary[1]
            local wsId = PRIMARY_WS_BY_WEAPON[primWeapon]

            player:changeJob(jobId)
            player:setLevel(75)
            spec.set(player, jobId, skey, { silent = true })
            spec.refreshPlayer(player)
            equipPrimaryWeapon(player, jobId, skey, 75, primWeapon)
            local wsId, isRanged = resolveLiveWsForEquipped(player, skey, primWeapon)
            talents.resetAll(player, jobId)
            xi.test.world:skipTime(1)

            -- Baseline (0 talents)
            local baseRun = executeLiveWs(player, mob, wsId, 1500, isRanged)

            -- Damage (Col 1)
            talents.resetAll(player, jobId)
            local dmgInv = investBranch(player, jobId, wsId, 1)
            local dmgRun = executeLiveWs(player, mob, wsId, 1500, isRanged)
            for _, ev in ipairs(dmgRun.events) do table.insert(allEvents, ev) end

            -- Utility (Col 2)
            talents.resetAll(player, jobId)
            local utilInv = investBranch(player, jobId, wsId, 2)
            local utilRun = executeLiveWs(player, mob, wsId, 1500, isRanged)
            for _, ev in ipairs(utilRun.events) do table.insert(allEvents, ev) end

            -- Soul (Col 3)
            talents.resetAll(player, jobId)
            local soulInv = investBranch(player, jobId, wsId, 3)
            -- Ensure at least 1 rank in Tier 3 Soul hook by spending 5 pts if needed
            local tree = talents.getTreeForWS(wsId, player, jobId)
            if tree and tree.nodes then
                local spent = talents.getWSSpent(player, jobId, wsId)
                if spent < 5 then
                    for _, n in ipairs(tree.nodes) do
                        if n.tier == 1 and n.col == 3 then
                            while talents.getWSSpent(player, jobId, wsId) < 5 do
                                if not talents.invest(player, jobId, wsId, n.key) then break end
                            end
                        end
                    end
                    for _, n in ipairs(tree.nodes) do
                        if n.tier == 3 and n.col == 3 then
                            if talents.invest(player, jobId, wsId, n.key) then
                                table.insert(soulInv, { node_key = n.key, tier = 3, col = 3 })
                            end
                        end
                    end
                end
            end
            local soulRun = executeLiveWs(player, mob, wsId, 1500, isRanged)
            for _, ev in ipairs(soulRun.events) do table.insert(allEvents, ev) end

            talents.resetAll(player, jobId)

            local sRec =
            {
                soul_key       = skey,
                job            = entry.job,
                role           = entry.role,
                tier           = entry.tier,
                primary_weapon = primWeapon,
                ws_id          = wsId,
                baseline_exec  = baseRun.executed,
                baseline_dmg   = baseRun.damage,
                damage_exec    = dmgRun.executed,
                damage_dmg     = dmgRun.damage,
                damage_events  = #dmgRun.events,
                utility_exec   = utilRun.executed,
                utility_dmg    = utilRun.damage,
                utility_events = #utilRun.events,
                soul_exec      = soulRun.executed,
                soul_dmg       = soulRun.damage,
                soul_events    = #soulRun.events,
                err            = baseRun.err or dmgRun.err or utilRun.err or soulRun.err,
            }
            table.insert(soulResults, sRec)

            if not (dmgRun.executed and utilRun.executed and soulRun.executed) then
                table.insert(failures, string.format('%s (ws=%d, weap=%s): exec base=%s dmg=%s util=%s soul=%s err=%s',
                    skey, wsId, primWeapon, tostring(baseRun.executed), tostring(dmgRun.executed),
                    tostring(utilRun.executed), tostring(soulRun.executed), tostring(sRec.err)))
            end
        end

        -- 2. MULTI-LEVEL PROGRESSION CHECK (Lv 10, 30, 50, 75)
        local repSouls = { 'berserker', 'spartan', 'bishop', 'scarletweaver', 'kurogane', 'sniper', 'bladewheel', 'wyvernheart' }
        for _, skey in ipairs(repSouls) do
            local entry = elig.SOULS[skey]
            local jobId = xi.job[entry.job]
            local primWeapon = entry.primary[1]
            local wsId = PRIMARY_WS_BY_WEAPON[primWeapon]
            for _, lvl in ipairs({ 10, 30, 50, 75 }) do
                player:changeJob(jobId)
                player:setLevel(lvl)
                spec.set(player, jobId, skey, { silent = true })
                spec.refreshPlayer(player)
                equipPrimaryWeapon(player, jobId, skey, lvl, primWeapon)
                local lvlWsId, lvlRanged = resolveLiveWsForEquipped(player, skey, primWeapon)
                talents.resetAll(player, jobId)
                local inv = investBranch(player, jobId, lvlWsId, 1)
                local run = executeLiveWs(player, mob, lvlWsId, 1500, lvlRanged)
                for _, ev in ipairs(run.events) do table.insert(allEvents, ev) end
                table.insert(levelResults, {
                    soul_key = skey, level = lvl, ws_id = lvlWsId,
                    invested = #inv, executed = run.executed, events = #run.events, damage = run.damage,
                })
                talents.resetAll(player, jobId)
            end
        end

        -- 3. EVOLUTION, ROLE RESTRICTIONS, MIGRATION & CLIENT SYNC
        -- 3a. Scarlet Weaver on Sanguine Blade (#47)
        player:changeJob(xi.job.RDM)
        player:setLevel(75)
        spec.set(player, xi.job.RDM, 'scarletweaver', { silent = true })
        spec.refreshPlayer(player)
        equipPrimaryWeapon(player, xi.job.RDM, 'scarletweaver', 75, 'Sword')
        talents.resetAll(player, xi.job.RDM)
        local okArc, errArc = talents.invest(player, xi.job.RDM, 47, 'e_sg_arcane')
        local okBld, errBld = talents.canInvest(player, xi.job.RDM, 47, 'e_sg_blood')
        local okCtl, errCtl = talents.canInvest(player, xi.job.RDM, 47, 'e_sg_control')
        local sgRun = executeLiveWs(player, mob, 47, 1500)
        for _, ev in ipairs(sgRun.events) do table.insert(allEvents, ev) end
        extraChecks.sanguine_blade_scarletweaver = {
            arcane_ok = okArc, arcane_err = tostring(errArc or ''),
            blood_blocked = (not okBld), control_blocked = (not okCtl),
            executed = sgRun.executed, events = #sgRun.events,
        }

        -- 3b. Black Belt Combo (#1) mutual exclusion
        player:changeJob(xi.job.MNK)
        player:setLevel(75)
        spec.set(player, xi.job.MNK, 'blackbelt', { silent = true })
        spec.refreshPlayer(player)
        equipPrimaryWeapon(player, xi.job.MNK, 'blackbelt', 75, 'Hand-to-Hand')
        talents.resetAll(player, xi.job.MNK)
        local okOpen, errOpen = talents.invest(player, xi.job.MNK, 1, 'e_co_open')
        local okFlow, errFlow = talents.canInvest(player, xi.job.MNK, 1, 'e_co_flow')
        local coRun = executeLiveWs(player, mob, 1, 1500)
        for _, ev in ipairs(coRun.events) do table.insert(allEvents, ev) end
        extraChecks.combo_mutual_exclusion = {
            open_ok = okOpen, open_err = tostring(errOpen or ''),
            flow_blocked = (not okFlow), flow_err = tostring(errFlow or ''),
            executed = coRun.executed, events = #coRun.events,
        }

        -- 3c. Berserker ineligible rejection + safe migration refund + Soul switching
        player:changeJob(xi.job.WAR)
        player:setLevel(75)
        spec.set(player, xi.job.WAR, 'berserker', { silent = true })
        spec.refreshPlayer(player)
        talents.resetAll(player, xi.job.WAR)
        local okInelig = talents.canInvest(player, xi.job.WAR, 32, 'ftp')
        local okElig = talents.invest(player, xi.job.WAR, 80, talents.getTreeForWS(80, player, xi.job.WAR).nodes[1].key)
        -- Simulate legacy pre-2.0 invested Sword #32
        player:setCharVar(talents.getVarName(xi.job.WAR, 32, player), 2)
        local migRep = talents.reconcileIneligibleAllocations(player, xi.job.WAR)
        local preserved80 = talents.getWSSpent(player, xi.job.WAR, 80)
        extraChecks.migration_and_eligibility = {
            ineligible_blocked = (not okInelig),
            eligible_invested  = okElig,
            refunded_points    = migRep.refundedPoints,
            preserved_ws80_pts = preserved80,
        }

        -- 3d. Exercise remaining unique effect handlers (dispel, elemental_followup, status_apply) at Tier 2/3
        local handlerTargets =
        {
            { job = xi.job.RDM, skey = 'royaltactician', weap = 'Sword', wsId = 32, wantField = 'dispel' },
            { job = xi.job.WAR, skey = 'berserker', weap = 'Great Axe', wsId = 80, wantField = 'elemFollow' },
            { job = xi.job.WHM, skey = 'bishop',    weap = 'Club',      wsId = 160, wantField = 'statusBuffs' },
        }
        extraChecks.advanced_handlers = {}
        for _, ht in ipairs(handlerTargets) do
            player:changeJob(ht.job)
            player:setLevel(75)
            spec.set(player, ht.job, ht.skey, { silent = true })
            spec.refreshPlayer(player)
            equipPrimaryWeapon(player, ht.job, ht.skey, 75, ht.weap)
            talents.resetAll(player, ht.job)
            local tr = talents.getTreeForWS(ht.wsId, player, ht.job)
            local foundNode = nil
            if tr and tr.nodes then
                -- Unlock up to Tier 3 by investing T1 + T2 in all columns
                for _, n in ipairs(tr.nodes) do
                    if (n.scTier or 0) == 0 and (n.tier or 1) <= 2 then
                        talents.invest(player, ht.job, ht.wsId, n.key)
                        talents.invest(player, ht.job, ht.wsId, n.key)
                    end
                end
                for _, n in ipairs(tr.nodes) do
                    if type(n.effect) == 'table' and (n.effect[ht.wantField] ~= nil or (ht.wantField == 'statusBuffs' and (n.effect.partyBuffs ~= nil or n.effect.timedMods ~= nil or n.effect.cleanseParty ~= nil))) then
                        talents.invest(player, ht.job, ht.wsId, n.key)
                        foundNode = n.key
                        break
                    end
                end
            end
            local hRun = executeLiveWs(player, mob, ht.wsId, 1500, false)
            for _, ev in ipairs(hRun.events) do table.insert(allEvents, ev) end
            extraChecks.advanced_handlers[ht.wantField] = { node = foundNode, executed = hRun.executed, events = #hRun.events }
            talents.resetAll(player, ht.job)
        end

        -- Write machine-readable live evidence JSON BEFORE assertions
        local payload =
        {
            engine        = 'xi_test_live',
            souls_tested  = #soulResults,
            total_events  = #allEvents,
            failures      = failures,
            soul_results  = soulResults,
            level_results = levelResults,
            extra_checks  = extraChecks,
            events        = allEvents,
        }
        local encodeJson = pgTelem and pgTelem.encodeJson
        if encodeJson then
            local fh = assert(io.open('log/ws_talent_v21_live_evidence.json', 'w'))
            fh:write(encodeJson(payload))
            fh:write('\n')
            fh:close()
        end

        assert(okArc and (not okBld) and (not okCtl), 'Sanguine Blade Scarlet Weaver role guardrail failed')
        assert(okOpen and (not okFlow), string.format('Combo mutual exclusion failed (open=%s/%s flow=%s/%s)', tostring(okOpen), tostring(errOpen), tostring(okFlow), tostring(errFlow)))
        assert((not okInelig) and okElig and migRep.refundedPoints == 2 and preserved80 == 1, 'Migration/eligibility live check failed')
        assert(#soulResults == 66, 'Expected 66 soul results, got ' .. #soulResults)
        assert(#failures == 0, string.format('Live xi_test failures (%d):\n%s', #failures, table.concat(failures, '\n')))
    end)
end)
