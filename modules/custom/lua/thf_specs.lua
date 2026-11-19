-----------------------------------
-- OverlordsXI THF Soul foundations (additive, no custom DAT/SQL IDs)
-- Trickster: tactical debuff and enmity manipulation (support).
-- Bandit: exploit existing weaknesses, timing-based damage (DPS).
-- Phantom: avoidance-based enmity retention (tank).
--
-- This first pass deliberately avoids new action IDs and resource meters.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_thf_specs')
local spec = xi.overlords.spec
local THF = xi.job.THF

local KEYS = { 'trickster', 'bandit', 'phantom' }
local LISTENER_IDS =
{
    trickster = 'OX_THF_TRICKSTER_WS',
    bandit    = 'OX_THF_BANDIT_WS',
    phantom   = 'OX_THF_PHANTOM_EVADE',
}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isActive(player, key)
    if player == nil or not player.isPC or not player:isPC() or
       player:getMainJob() ~= THF or player:getMainLvl() < 10 then
        return false
    end
    return spec.is(player, THF, key)
end

local function isWeapon(player, allowed)
    if player == nil or not player.getWeaponSkillType then
        return false
    end
    local kind = player:getWeaponSkillType(xi.slot.MAIN)
    return kind ~= nil and allowed[kind] == true
end

local DAGGER_OR_SWORD = { [xi.skill.DAGGER] = true, [xi.skill.SWORD] = true }
local DAGGER_OR_KATANA = { [xi.skill.DAGGER] = true, [xi.skill.KATANA] = true }

local function ready(player, key, cooldown)
    if not player.getLocalVar or not player.setLocalVar then
        return false
    end
    local now = xi.overlords.nowSec()
    local last = player:getLocalVar(key) or 0
    if now < last then
        last = 0  -- monotonic epoch changed, e.g. server restart
    end
    if last ~= 0 and now - last < cooldown then
        return false
    end
    player:setLocalVar(key, now)
    return true
end

local function attachTrickster(player)
    if not player or not player.addListener then return end
    player:removeListener(LISTENER_IDS.trickster)
    player:addListener('WEAPONSKILL_USE', LISTENER_IDS.trickster,
    function(actor, target)
        if not isActive(actor, 'trickster') or
           not isWeapon(actor, DAGGER_OR_SWORD) or
           not target or not target.isMob or not target:isMob() or
           not target.isAlive or not target:isAlive() or
           not target.addStatusEffect then
            return
        end

        -- No custom status slot or indefinite stack: a small enemy offense
        -- disruption window after a successful tactical WS use.
        if target.hasStatusEffect and target:hasStatusEffect(xi.effect.ATTACK_DOWN) then
            return
        end
        if not ready(actor, 'OX_TRK_LAST_WEAKEN', 20) then return end
        local amount = scale(actor:getMainLvl(), 5, 7, 9, 12)
        target:addStatusEffect(xi.effect.ATTACK_DOWN,
        {
            power    = amount,
            duration = 16,
            origin   = actor,
        })
    end)
end

local function attachBandit(player)
    if not player or not player.addListener then return end
    player:removeListener(LISTENER_IDS.bandit)
    player:addListener('WEAPONSKILL_USE', LISTENER_IDS.bandit,
    function(actor, target)
        if not isActive(actor, 'bandit') or
           not isWeapon(actor, DAGGER_OR_SWORD) or
           not target or not target.hasStatusEffect or not actor.addTP then
            return
        end

        -- Opportunism, not a new builder/spender bar: take advantage of
        -- an existing defense opening. Never creates that opening itself.
        if target:hasStatusEffect(xi.effect.DEFENSE_DOWN) and
           ready(actor, 'OX_BND_LAST_EXPLOIT', 12) then
            actor:addTP(scale(actor:getMainLvl(), 75, 100, 125, 150))
        end
    end)
end

local function attachPhantom(player)
    if not player or not player.addListener then return end
    player:removeListener(LISTENER_IDS.phantom)
    player:addListener('ATTACKED', LISTENER_IDS.phantom,
    function(defender, attacker, action)
        if not isActive(defender, 'phantom') or
           not isWeapon(defender, DAGGER_OR_KATANA) or
           not attacker or not attacker.isMob or not attacker:isMob() or
           not action or not action.getMsg then
            return
        end
        local miss = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if action:getMsg(defender:getID()) ~= miss then return end
        if not ready(defender, 'OX_PHN_LAST_EVADE', 2) then return end

        -- The mob fixates on the elusive phantom. Does not strike back
        -- (Sensei owns counter/riposte tanking) or generate healing.
        if attacker.addEnmity then
            local lvl = defender:getMainLvl()
            attacker:addEnmity(defender,
                scale(lvl, 30, 40, 55, 70),
                scale(lvl, 85, 115, 150, 190))
        end
    end)
end

local function removeListeners(player)
    if not player or not player.removeListener then return end
    for _, key in ipairs(KEYS) do
        player:removeListener(LISTENER_IDS[key])
    end
end

local function attachFor(key, player)
    removeListeners(player)
    if key == 'trickster' then
        attachTrickster(player)
    elseif key == 'bandit' then
        attachBandit(player)
    elseif key == 'phantom' then
        attachPhantom(player)
    end
end

if THF ~= nil then
    local specs =
    {
        {
            id = 1, key = 'trickster', name = 'Trickster', abr = 'TRK',
            role = 'Support', icon = 'trickster', reqLevel = 10,
            description = 'A covert tactician: uses native Thief enmity positioning and carefully timed weapon skills to suppress a target, rather than competing with dedicated damage dealers.',
            highlights =
            {
                'Primary decisions: choose which boss mechanic needs a tactical offense-disruption window, and coordinate Sneak/Trick Attack positioning.',
                'Every 20s, a Dagger/Sword weaponskill can apply a short Attack Down if the enemy is not already affected. No bespoke resource.',
                'Weakness: limited self-sustain and offensive throughput. It is not a substitute for a raid healer or frontline tank.',
            },
            mods = function(_player, level)
                return
                {
                    {xi.mod.DAGGER,       scale(level, 12, 20, 30, 42)},
                    {xi.mod.ACC,          scale(level, 10, 16, 24, 32)},
                    {xi.mod.DEX,          scale(level, 6, 10, 15, 20)},
                    {xi.mod.SUBTLE_BLOW,  scale(level, 5, 8, 12, 16)},
                    {xi.mod.ENMITY,      -scale(level, 8, 12, 16, 20)},
                }
            end,
            onApply = function(player) attachFor('trickster', player) end,
            onRemove = removeListeners,
        },
        {
            id = 2, key = 'bandit', name = 'Bandit', abr = 'BND',
            role = 'Damage', icon = 'bandit', reqLevel = 10,
            description = 'An opportunistic cutpurse: strikes hard when allies or weapon effects expose a target. Rewards reading vulnerabilities instead of building a personal stack bar.',
            highlights =
            {
                'Dagger/Sword weaponskills exploit Defense Down for a limited TP return (once per 12s). Bandit cannot apply that condition itself.',
                'Strong close-range physical pressure and precise burst timing. Vulnerable to mechanics that deny melee access.',
                'No permanent raid utility and no dedicated defensive sustain.',
            },
            mods = function(_player, level)
                return
                {
                    {xi.mod.DAGGER,       scale(level, 12, 22, 34, 48)},
                    {xi.mod.ACC,          scale(level, 10, 20, 30, 42)},
                    {xi.mod.ATT,          scale(level, 12, 24, 38, 55)},
                    {xi.mod.DEX,          scale(level, 6, 12, 18, 24)},
                    {xi.mod.CRITHITRATE,  scale(level, 3, 5, 7, 9)},
                    {xi.mod.STORETP,      scale(level, 3, 5, 7, 10)},
                }
            end,
            onApply = function(player) attachFor('bandit', player) end,
            onRemove = removeListeners,
        },
        {
            id = 3, key = 'phantom', name = 'Phantom', abr = 'PHN',
            role = 'Tank', icon = 'phantom', reqLevel = 10,
            description = 'An elusive trick-fighter: maintains enemy attention by frustrating attacks through movement and avoidance; no shadow clones or martial counterattack loop.',
            highlights =
            {
                'Evaded melee attacks reinforce enmity every 2s with Dagger/Katana equipped; no reactive damage or self-healing.',
                'Strong avoidance and enmity control during repeated physical attacks.',
                'Weakness: unavoidable attacks and anti-evasion boss mechanics. Defensive gear and party support remain essential.',
            },
            mods = function(_player, level)
                return
                {
                    {xi.mod.DAGGER,       scale(level, 10, 20, 30, 42)},
                    {xi.mod.EVA,          scale(level, 20, 35, 55, 75)},
                    {xi.mod.AGI,         scale(level, 7, 12, 18, 25)},
                    {xi.mod.HPP,          scale(level, 8, 12, 16, 20)},
                    {xi.mod.DMG,         -scale(level, 500, 700, 1000, 1200)},
                    {xi.mod.ENMITY,       scale(level, 20, 30, 40, 50)},
                }
            end,
            onApply = function(player) attachFor('phantom', player) end,
            onRemove = removeListeners,
        },
    }

    for _, entry in ipairs(specs) do
        local existing = spec.jobs[THF]
        local byKey = existing and existing.byKey
        if not byKey or not byKey[entry.key] then
            spec.registerCrystal(THF, entry)
        end
    end
end

return m
