-----------------------------------
-- SoulspireXI — Real Engine 66-Soul Staging Smoke Suite
-- Runs inside authoritative headless xi_test against isolated staging DB.
-----------------------------------
local spec = xi.soulspire.spec
local hud  = xi.soulspire.hud

describe('66-Soul Real Engine Staging Smoke Suite', function()
    local player

    before_each(function()
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 10,
        })
    end)

    it('loads and activates all 66 canonical Souls cleanly across Lv10, Lv30, Lv50, and Lv75', function()
        assert(spec and spec.jobs, 'xi.soulspire.spec.jobs missing')

        local total = 0
        local failures = {}
        local levels = { 10, 30, 50, 75 }

        local perJobIssues = {}
        for jobId = 1, 22 do
            local jobDef = spec.jobs[jobId]
            local jobKeys = {}
            if jobDef and jobDef.ordered then
                for _, entry in ipairs(jobDef.ordered) do
                    local key = entry.key
                    if key and key ~= 'freelancer' then
                        table.insert(jobKeys, key)
                        total = total + 1
                        for _, lvl in ipairs(levels) do
                            local ok, err = pcall(function()
                                player:changeJob(jobId)
                                player:setLevel(lvl)
                                spec.set(player, jobId, key, { silent = true })
                                spec.refreshPlayer(player)
                                assert(spec.is(player, jobId, key), string.format('spec.is failed for job=%d key=%s lvl=%d', jobId, key, lvl))
                                assert(player:getMaxHP() > 0, string.format('MaxHP <= 0 for job=%d key=%s lvl=%d', jobId, key, lvl))
                                if hud and hud.buildPayload then
                                    local payload = hud.buildPayload(player)
                                    assert(payload == nil or type(payload) == 'table', 'Invalid HUD payload type')
                                end
                            end)
                            if not ok then
                                table.insert(failures, string.format('job=%d key=%s lvl=%d: %s', jobId, key, lvl, tostring(err)))
                            end
                        end
                    end
                end
            end
            if #jobKeys ~= 3 then
                table.insert(perJobIssues, string.format('job=%d count=%d keys=[%s]', jobId, #jobKeys, table.concat(jobKeys, ',')))
            end
        end

        assert(total == 66, string.format('Expected exactly 66 loaded Souls in xi.soulspire.spec.jobs, got %d; issues: %s', total, table.concat(perJobIssues, '; ')))
        assert(#failures == 0, string.format('66-Soul engine smoke failures (%d):\n%s', #failures, table.concat(failures, '\n')))
    end)
end)
