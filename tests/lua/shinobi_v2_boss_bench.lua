-----------------------------------
-- OverlordsXI Shinobi 2.0 — Real-Engine Boss Archetype & Tier-1 Balance Benchmark
-- Runs inside xi_test.exe against live LandSandBoat combat formulas, dynamic clones,
-- C++ battleutils patch 0045, and boss_like_combat_and_exp.lua.
--
-- Note: Automated engine combat trials complement, and do NOT replace, live
-- in-game boss playtesting with a real client and party.
-----------------------------------
local spec = xi.overlords.spec
local K    = xi.overlords.kurogane

local simClock = 200000

local function advanceSim(seconds, player, target)
    local steps = math.max(1, math.floor(seconds or 1))
    for _ = 1, steps do
        simClock = simClock + 1
        xi.test.world:skipTime(1)
        if player then
            xi.test.world:tickEntity(player)
            local st = K._owners[player:getID()]
            if st and st.clones then
                for _, rec in ipairs(st.clones) do
                    if rec.mob then
                        xi.test.world:tickEntity(rec.mob)
                    end
                end
            end
        end
        if target then
            xi.test.world:tickEntity(target)
        end
    end
end

-- Representative accessible Katana gear (standard vendor/leveling/entry-75 gear, no relics)
local TIER_GEAR =
{
    [10] = { main = 16900, sub = 16900, ws = xi.weaponskill.BLADE_RIN,   name = 'Lv10 Wakizashi x2' },
    [30] = { main = 16907, sub = 16907, ws = xi.weaponskill.BLADE_RETSU, name = 'Lv30 Busuto x2' },
    [50] = { main = 16908, sub = 16908, ws = xi.weaponskill.BLADE_TEN,   name = 'Lv50 Yoto x2' },
    [75] = { main = 16904, sub = 16910, ws = xi.weaponskill.BLADE_JIN,   name = 'Lv75 Fudo + Mamushito' },
}

local function equipAccessibleTier(player, level)
    -- Give representative accessible dual katanas
    local g = TIER_GEAR[level]
    if g then
        pcall(function()
            player:addItem(g.main)
            player:addItem(g.sub)
            player:equipItem(g.main, nil, xi.slot.MAIN)
            player:equipItem(g.sub, nil, xi.slot.SUB)
        end)
    end
    -- Representative accessible combat skill + modest leveling gear stats (ACC/ATT/Haste)
    local katanaCap = math.floor(level * 3.6 + 10)
    pcall(function() player:setSkillLevel(xi.skill.KATANA, katanaCap * 10) end)
    pcall(function() player:setSkillLevel(xi.skill.NINJUTSU, katanaCap * 10) end)
    local gearAcc = math.floor(level * 0.6)
    local gearAtt = math.floor(level * 0.8)
    player:addMod(xi.mod.ACC, gearAcc)
    player:addMod(xi.mod.ATT, gearAtt)
    player:addMod(xi.mod.HASTE_GEAR, math.min(2000, math.floor(level * 25)))
    player:addMod(xi.mod.SPELLINTERRUPT, 100)
end

local function spawnBenchmarkPair(level, mobDelta, extraDef)
    local player = xi.test.world:spawnPlayer({
        zone  = xi.zone.WEST_RONFAURE,
        job   = xi.job.NIN,
        level = level,
    })
    spec.set(player, xi.job.NIN, 'kurogane')
    spec.refreshPlayer(player)
    equipAccessibleTier(player, level)

    local target = player.entities:get('Wild_Rabbit')
    target:respawn()
    local bossLvl = math.max(1, level + (mobDelta or 0))
    target:setMobLevel(bossLvl)
    if extraDef and extraDef > 0 then
        target:addMod(xi.mod.DEF, extraDef)
    end
    target:setUnkillable(true)
    target:setMaxHP(100000)
    target:setHP(100000)
    target:setPos(player:getXPos() + 1.5, player:getYPos(), player:getZPos(), 0)
    player:setPos(player:getXPos(), player:getYPos(), player:getZPos(), 0)
    if player.lookAt then
        pcall(function() player:lookAt(target:getPos()) end)
    end
    xi.test.world:tickEntity(target)
    player.actions:engage(target)
    xi.test.world:tickEntity(player)
    assert(player:isEngaged(), 'benchmark player failed to engage')
    return player, target, bossLvl
end

local function tryCast(player, target, spellId)
    if not player:hasSpell(spellId) or player:hasRecast(xi.recast.MAGIC, spellId) then
        return false
    end
    player.actions:useSpell(target, spellId)
    xi.test.world:tickEntity(player)
    return true
end

local function runSustainedTrial(level, mobDelta, durationSec, opts)
    opts = opts or {}
    local player, target, bossLvl = spawnBenchmarkPair(level, mobDelta, opts.extraDef or 0)
    local totalDmg = 0
    local prevHp = target:getHP()
    local cloneDmgStart = 0
    local cloneHitsStart = 0
    local cloneAliveSec = 0
    local cloneCountSum = 0
    local cyclesCompleted = 0
    local commandsExecuted = 0
    local cloneDeaths = 0
    local maxCloneThreat = 0
    local castLockUntil = 0

    -- Track direct command damage vs clone melee damage via snapshot attribution
    local trackedCloneDmg = 0
    local seenMobDmg = {}

    local function harvestCloneAttribution()
        local st = K._owners[player:getID()]
        if not st or not st.clones then
            return
        end
        for _, rec in ipairs(st.clones) do
            local prev = seenMobDmg[rec.mobId] or 0
            local cur = rec.attributedDamage or 0
            if cur > prev then
                trackedCloneDmg = trackedCloneDmg + (cur - prev)
                seenMobDmg[rec.mobId] = cur
            end
        end
    end

    -- Keep player alive during boss damage tests so sustained DPS can be measured cleanly
    player:setUnkillable(true)

    local t0 = os.clock()
    for sec = 1, durationSec do
        local snap = K.getSnapshot(player)
        if snap.clones > 0 then
            cloneAliveSec = cloneAliveSec + 1
            cloneCountSum = cloneCountSum + snap.clones
        end

        -- Boss archetype mechanics
        if opts.aoeInterval and sec % opts.aoeInterval == 0 then
            local st = K._owners[player:getID()]
            if st and st.clones then
                local heavy = opts.heavyAoeInterval and (sec % opts.heavyAoeInterval == 0)
                local rawDmg = heavy and math.floor(level * 4.5 + 40) or math.floor(level * 1.5 + 22)
                for _, rec in ipairs(st.clones) do
                    if rec.mob and rec.mob:isAlive() then
                        rec.mob:takeDamage(rawDmg, target, xi.attackType.MAGICAL, xi.damageType.FIRE)
                        if not rec.mob:isAlive() or rec.mob:getHP() <= 0 then
                            cloneDeaths = cloneDeaths + 1
                        end
                    end
                end
            end
        end

        if opts.magicSpikeInterval and sec % opts.magicSpikeInterval == 0 then
            local st = K._owners[player:getID()]
            if st and st.clones and st.clones[1] and st.clones[1].mob and st.clones[1].mob:isAlive() then
                -- Minor spike vs lethal nuke alternating
                local spikeDmg = (sec % (opts.magicSpikeInterval * 2) == 0)
                    and math.floor(level * 4.2 + 50)
                    or math.floor(level * 1.3 + 18)
                st.clones[1].mob:takeDamage(spikeDmg, target, xi.attackType.MAGICAL, xi.damageType.THUNDER)
                if not st.clones[1].mob:isAlive() or st.clones[1].mob:getHP() <= 0 then
                    cloneDeaths = cloneDeaths + 1
                end
            end
        end

        if opts.mobileInterval and sec % opts.mobileInterval == 0 then
            local dir = ((sec / opts.mobileInterval) % 2 == 0) and 1 or -1
            target:setPos(target:getXPos() + dir * 6.0, target:getYPos(), target:getZPos(), 0)
            player:setPos(target:getXPos() - 1.5, target:getYPos(), target:getZPos(), 0)
        end

        -- Rotation AI: prioritize keeping clones active, fire Katana WS at 1000+ TP when squad is up,
        -- then weave varied commands through Feint -> Switch -> Cascade
        if sec >= castLockUntil then
            local targetCap = (level >= 37) and 5 or 2
            local needRefresh = (snap.clones < targetCap) or (snap.clones > 0 and (snap.next_expiry_s or 99) <= 6)
            local acted = false
            if needRefresh then
                if level >= 37 and tryCast(player, player, xi.magic.spell.UTSUSEMI_NI) then
                    acted = true
                    castLockUntil = sec + 5
                elseif tryCast(player, player, xi.magic.spell.UTSUSEMI_ICHI) then
                    acted = true
                    castLockUntil = sec + 5
                end
            end

            if not acted and player:getTP() >= 1000 and TIER_GEAR[level] and TIER_GEAR[level].ws then
                pcall(function() player.actions:useWeaponskill(target, TIER_GEAR[level].ws) end)
                acted = true
                castLockUntil = sec + 2
            end

            if not acted and snap.clones > 0 then
                local last = snap.last_cmd or ''
                local phase = snap.phase or 0
                -- Pick highest-value non-repeating squad command available
                local order
                if phase == K.PHASE_CASCADE then
                    order = { 335, 332, 326, 323, 320, 329 }
                elseif phase == K.PHASE_SWITCH then
                    order = { 323, 329, 332, 326, 320 }
                else
                    order = { 320, 329, 323, 326, 332 }
                end
                local tagById = { [320]='FA', [323]='MS', [326]='CC', [329]='SP', [332]='TR', [335]='FM' }
                for _, sid in ipairs(order) do
                    if tagById[sid] ~= last and tryCast(player, target, sid) then
                        acted = true
                        commandsExecuted = commandsExecuted + 1
                        if phase == K.PHASE_CASCADE then
                            cyclesCompleted = cyclesCompleted + 1
                        end
                        castLockUntil = sec + 6
                        break
                    end
                end
            end
        end

        -- Use Phantom Assault / Shadow Legion when clones are up at Lv10+
        if sec == 12 and snap.clones > 0 then
            K.executePhantomAssault(player)
        elseif sec == 20 and snap.clones > 0 then
            K.executeShadowLegion(player, target)
        end

        advanceSim(1, player, target)
        harvestCloneAttribution()

        -- Measure total real damage dealt to target and reset target HP pool if low
        local curHp = target:getHP()
        if curHp < prevHp then
            totalDmg = totalDmg + (prevHp - curHp)
        end
        if curHp < 20000 then
            target:setHP(100000)
            prevHp = 100000
        else
            prevHp = curHp
        end

        -- Verify clones hold 0 threat (enmity cleanliness)
        local st = K._owners[player:getID()]
        if st and st.clones then
            for _, rec in ipairs(st.clones) do
                if rec.mob and rec.mob:isAlive() and target.getCE then
                    local ce = target:getCE(rec.mob) or 0
                    local ve = target:getVE(rec.mob) or 0
                    if (ce + ve) > maxCloneThreat then
                        maxCloneThreat = ce + ve
                    end
                end
            end
        end
    end
    local wallMs = math.floor((os.clock() - t0) * 1000)
    harvestCloneAttribution()

    local result = {
        level = level,
        bossLvl = bossLvl,
        delta = mobDelta,
        duration = durationSec,
        totalDmg = totalDmg,
        totalDps = totalDmg / durationSec,
        cloneTotalDmg = trackedCloneDmg,
        cloneDps = trackedCloneDmg / durationSec,
        cloneSharePct = (totalDmg > 0) and (trackedCloneDmg * 100.0 / totalDmg) or 0,
        uptimePct = cloneAliveSec * 100.0 / durationSec,
        avgClones = cloneCountSum / durationSec,
        commands = commandsExecuted,
        cycles = cyclesCompleted,
        cloneDeaths = cloneDeaths,
        maxCloneThreat = maxCloneThreat,
        wallMs = wallMs,
    }

    K.dismissAll(player)
    player:setUnkillable(false)
    target:setUnkillable(false)
    return result
end

describe('Shinobi 2.0 Boss Archetype & Balance Benchmark', function()
    local origNowSec

    before_each(function()
        origNowSec = xi.overlords.nowSec
        simClock = 200000
        xi.overlords.nowSec = function()
            return simClock
        end
        K.ENABLE_EXPERIMENTAL_CLONES = true
        K.ENABLE_EXPERIMENTAL_COMBAT = true
    end)

    after_each(function()
        if origNowSec then
            xi.overlords.nowSec = origNowSec
        end
    end)

    local function logBenchLine(line)
        local path = os.getenv('SHINOBI_BENCH_OUT')
        if path and path ~= '' then
            local f = io.open(path, 'a')
            if f then
                f:write(line .. '\n')
                f:close()
            end
        end
    end

    it('benchmarks endurance & scaling across Lv10, Lv30, Lv50, Lv75 (EM +0 and +3 bosses, plus +8 extreme)', function()
        local tiers = {
            { lvl = 10, delta = 0 },
            { lvl = 10, delta = 3 },
            { lvl = 30, delta = 0 },
            { lvl = 30, delta = 3 },
            { lvl = 50, delta = 0 },
            { lvl = 50, delta = 3 },
            { lvl = 75, delta = 0 },
            { lvl = 75, delta = 3 },
            { lvl = 75, delta = 8 }, -- Extreme challenge tested separately
        }
        for _, tc in ipairs(tiers) do
            local r = runSustainedTrial(tc.lvl, tc.delta, 45)
            logBenchLine(string.format(
                'TIER | Lv%02d vs +%d (Lv%02d) | TotalDPS=%.1f | Clone+CmdDPS=%.1f (%.1f pct) | Uptime=%.0f pct | AvgClones=%.2f | Cmds=%d | Cycles=%d | MaxCloneThreat=%d | Wall=%dms',
                r.level, r.delta, r.bossLvl, r.totalDps, r.cloneDps, r.cloneSharePct,
                r.uptimePct, r.avgClones, r.commands, r.cycles, r.maxCloneThreat, r.wallMs))
            assert(r.totalDmg > 0, string.format('Lv%d +%d dealt zero total damage', tc.lvl, tc.delta))
            assert(r.cloneTotalDmg > 0, string.format('Lv%d +%d clones dealt zero attributed damage', tc.lvl, tc.delta))
            -- Wild_Rabbit uses real physical AoE (Whirl Claws) that legitimately kills glass-cannon clones;
            -- verify clones maintain meaningful active uptime while still suffering real AoE attrition.
            local minUptime = (tc.lvl >= 50) and 40 or 25
            assert(r.uptimePct >= minUptime, string.format('Lv%d +%d clone uptime too low: %.1f%%', tc.lvl, tc.delta, r.uptimePct))
            assert(r.maxCloneThreat == 0, string.format('Lv%d +%d clone held non-zero threat: %d', tc.lvl, tc.delta, r.maxCloneThreat))
        end
    end)

    it('benchmarks all 6 boss encounter archetypes at Lv75 (+3 boss)', function()
        local archetypes = {
            { name = 'PhysicalBruiser', opts = { extraDef = 90 } },
            { name = 'MagicCaster',     opts = { magicSpikeInterval = 10 } },
            { name = 'AoEBoss',         opts = { aoeInterval = 14, heavyAoeInterval = 28 } },
            { name = 'MobileBoss',      opts = { mobileInterval = 15 } },
            { name = 'Endurance60s',    opts = {}, dur = 60 },
            { name = 'BurstWindow15s',  opts = {}, dur = 18 },
        }
        for _, arch in ipairs(archetypes) do
            local r = runSustainedTrial(75, 3, arch.dur or 45, arch.opts)
            logBenchLine(string.format(
                'ARCH | %-15s | Lv75+3 | TotalDPS=%.1f | Clone+CmdDPS=%.1f (%.1f pct) | Uptime=%.0f pct | AvgClones=%.2f | Deaths=%d | Cmds=%d | Cycles=%d | MaxThreat=%d | Wall=%dms',
                arch.name, r.totalDps, r.cloneDps, r.cloneSharePct,
                r.uptimePct, r.avgClones, r.cloneDeaths, r.commands, r.cycles, r.maxCloneThreat, r.wallMs))
            assert(r.totalDmg > 0, arch.name .. ' dealt zero damage')
            assert(r.maxCloneThreat == 0, arch.name .. ' leaked clone threat: ' .. tostring(r.maxCloneThreat))
            if arch.name == 'AoEBoss' then
                -- Clones must suffer real attrition on heavy AoE (never immortal tanks) yet maintain meaningful uptime via recovery
                assert(r.cloneDeaths > 0, 'AoEBoss heavy AoE should kill clones (clones must not be immortal)')
                assert(r.uptimePct >= 50, 'AoEBoss uptime collapsed below 50%: ' .. tostring(r.uptimePct))
            end
        end
    end)
end)
