-----------------------------------
-- OverlordsXI THF Souls (Sequence B — Trickster, Bandit, Phantom)
-- Additive registration; no new SQL/DAT ability IDs required.
--   Trickster (Support): positional threat routing + landed WS Attack Down (20s ICD).
--   Bandit    (Damage) : landed WS TP refund against existing Defense Down (12s ICD).
--   Phantom   (Tank)   : miss-triggered evasion enmity (2s ICD) + Phantom's Dare
--                        cold-start opener (180 CE / 650 VE + 6s one-hit unavoidable guard).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local soulActions = nil
do
    local ok, mod = pcall(require, 'modules/custom/lua/overlords_soul_actions')
    if ok and type(mod) == 'table' then
        soulActions = mod
    end
end

local m = Module:new('overlords_thf_specs')
local spec = xi.overlords.spec
local THF = xi.job.THF

local ABIL_STEAL        = (xi.jobAbility and xi.jobAbility.STEAL) or 41
local ABIL_SNEAK_ATTACK = (xi.jobAbility and xi.jobAbility.SNEAK_ATTACK) or 44
local ABIL_TRICK_ATTACK = (xi.jobAbility and xi.jobAbility.TRICK_ATTACK) or 76

local KEYS = { 'trickster', 'bandit', 'phantom' }
local LISTENER_IDS =
{
    trickster = 'OX_THF_TRICKSTER_WS',
    bandit    = 'OX_THF_BANDIT_WS',
    phantom   = 'OX_THF_PHANTOM_EVADE',
}

local VAR_TRK_WEAKEN   = 'OX_TRK_LAST_WEAKEN'
local VAR_BND_EXPLOIT  = 'OX_BND_LAST_EXPLOIT'
local VAR_PHN_EVADE    = 'OX_PHN_LAST_EVADE'
local VAR_PHN_DARE_CD  = 'OX_PHN_LAST_DARE'
local VAR_PHN_DARE_END = 'OX_PHN_DARE_GUARD_UNTIL'
local VAR_PHN_DARE_PCT = 'OX_PHN_DARE_GUARD_PCT'

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

local function cooldownRemaining(player, key, cooldown)
    if not player or not player.getLocalVar then return 0 end
    local now = xi.overlords.nowSec()
    local last = player:getLocalVar(key) or 0
    if last == 0 or now < last then return 0 end
    local rem = cooldown - (now - last)
    return rem > 0 and rem or 0
end

local function isReady(player, key, cooldown)
    if not player or not player.getLocalVar then return false end
    local now = xi.overlords.nowSec()
    local last = player:getLocalVar(key) or 0
    if now < last then
        last = 0
    end
    return last == 0 or (now - last) >= cooldown
end

local function stampCooldown(player, key)
    if player and player.setLocalVar then
        player:setLocalVar(key, xi.overlords.nowSec())
    end
end

-- Gate WS triggers on a resolved landed hit (positive damage, not a miss/zero-damage).
local function didWeaponSkillLand(target, action, damage)
    if type(damage) == 'number' then
        return damage > 0
    end
    if action and action.getMsg and target and target.getID then
        local msg = action:getMsg(target:getID())
        local skillMiss = xi.msg and xi.msg.basic and xi.msg.basic.SKILL_MISS or 188
        local hitMiss = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if msg == skillMiss or msg == hitMiss or msg == 0 then
            return false
        end
        return true
    end
    return false
end

local function clearPhantomGuard(player)
    if player and player.setLocalVar then
        player:setLocalVar(VAR_PHN_DARE_END, 0)
        player:setLocalVar(VAR_PHN_DARE_PCT, 0)
    end
end

local function attachTrickster(player)
    if not player or not player.addListener then return end
    player:removeListener(LISTENER_IDS.trickster)
    player:addListener('WEAPONSKILL_USE', LISTENER_IDS.trickster,
    function(actor, target, _wsId, _tp, action, damage)
        if not isActive(actor, 'trickster') or
           not isWeapon(actor, DAGGER_OR_SWORD) or
           not target or not target.isMob or not target:isMob() or
           not target.isAlive or not target:isAlive() or
           not target.addStatusEffect then
            return
        end

        if not didWeaponSkillLand(target, action, damage) then
            return
        end

        -- Do not overwrite existing Attack Down or consume Trickster's ICD on it.
        if target.hasStatusEffect and target:hasStatusEffect(xi.effect.ATTACK_DOWN) then
            return
        end
        if not isReady(actor, VAR_TRK_WEAKEN, 20) then return end
        stampCooldown(actor, VAR_TRK_WEAKEN)

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
    function(actor, target, _wsId, _tp, action, damage)
        if not isActive(actor, 'bandit') or
           not isWeapon(actor, DAGGER_OR_SWORD) or
           not target or not target.isMob or not target:isMob() or
           not target.hasStatusEffect or not actor.addTP then
            return
        end

        -- Require a resolved landed hit; a miss gives zero refund and leaves ICD ready.
        if not didWeaponSkillLand(target, action, damage) then
            return
        end

        -- Opportunism: requires existing Defense Down; Bandit never creates the opening itself.
        if target:hasStatusEffect(xi.effect.DEFENSE_DOWN) and
           isReady(actor, VAR_BND_EXPLOIT, 12) then
            stampCooldown(actor, VAR_BND_EXPLOIT)
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

        -- Only regular enemy melee misses qualify (excludes parry, block, shadows, nullifies).
        local miss = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if action:getMsg(defender:getID()) ~= miss then return end
        if not isReady(defender, VAR_PHN_EVADE, 2) then return end
        stampCooldown(defender, VAR_PHN_EVADE)

        if attacker.addEnmity then
            local lvl = defender:getMainLvl()
            attacker:addEnmity(
                defender,
                scale(lvl, 30, 40, 55, 70),
                scale(lvl, 85, 115, 150, 190)
            )
        end
    end)
end

local function removeListeners(player)
    if not player then return end
    if player.removeListener then
        for _, key in ipairs(KEYS) do
            player:removeListener(LISTENER_IDS[key])
        end
    end
    clearPhantomGuard(player)
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

-- Phantom's Dare: cold-start threat opener (15y, 18s CD, 180 CE / 650 VE, 0 TP, no /WAR)
-- plus a 6s one-hit mitigation guard against the next unavoidable (magical/breath) hit.
local function executePhantomsDare(player, target, ability)
    if not isActive(player, 'phantom') then
        return false
    end
    if not target or not target.isMob or not target:isMob() or
       not target.isAlive or not target:isAlive() then
        return false
    end
    if player.checkDistance and player:checkDistance(target) > 15 then
        return false
    end
    if not isReady(player, VAR_PHN_DARE_CD, 18) then
        return false
    end

    stampCooldown(player, VAR_PHN_DARE_CD)
    if ability and ability.setRecast then
        ability:setRecast(18)
    end
    if target.addEnmity then
        target:addEnmity(player, 180, 650)
    end

    local now = xi.overlords.nowSec()
    local pct = scale(player:getMainLvl(), 8, 10, 12, 15)
    if player.setLocalVar then
        player:setLocalVar(VAR_PHN_DARE_END, now + 6)
        player:setLocalVar(VAR_PHN_DARE_PCT, pct)
    end
    return true
end

-- Chain into xi.overlords.onPreTakeDamage for Phantom's Dare one-hit unavoidable guard.
-- Only applies to landed hostile MAGICAL or BREATH damage; never consumed by normal melee.
local prevOnPreTakeDamage = xi.overlords.onPreTakeDamage
function xi.overlords.onPreTakeDamage(defender, amount, attacker, attackType, damageType)
    if prevOnPreTakeDamage ~= nil then
        amount = prevOnPreTakeDamage(defender, amount, attacker, attackType, damageType)
    end
    if type(amount) ~= 'number' or amount <= 0 then
        return amount
    end
    if not isActive(defender, 'phantom') or not attacker or not attacker.isMob or not attacker:isMob() then
        return amount
    end

    local magical = xi.attackType and xi.attackType.MAGICAL or 2
    local breath  = xi.attackType and xi.attackType.BREATH or 4
    if attackType ~= magical and attackType ~= breath then
        return amount
    end

    local now = xi.overlords.nowSec()
    local guardUntil = defender.getLocalVar and (defender:getLocalVar(VAR_PHN_DARE_END) or 0) or 0
    local guardPct   = defender.getLocalVar and (defender:getLocalVar(VAR_PHN_DARE_PCT) or 0) or 0
    if guardUntil == 0 or guardPct <= 0 or now > guardUntil then
        if guardUntil ~= 0 and now > guardUntil then
            clearPhantomGuard(defender)
        end
        return amount
    end

    clearPhantomGuard(defender)
    local reduced = math.floor(amount * guardPct / 100)
    if reduced < 1 then reduced = 1 end
    return math.max(0, amount - reduced)
end

-- Hook native Steal (ID 41, available from Lv5) as Phantom's Dare only while Phantom is active.
if xi.actions and xi.actions.abilities and xi.actions.abilities.steal then
    m:addOverride('xi.actions.abilities.steal.onAbilityCheck', function(player, target, ability)
        if isActive(player, 'phantom') then
            if not target or not target.isMob or not target:isMob() or not target:isAlive() then
                return xi.msg.basic.CANNOT_ON_THAT_TARG, 0
            end
            if player.checkDistance and player:checkDistance(target) > 15 then
                return xi.msg.basic.TOO_FAR_AWAY, 0
            end
            return 0, 0
        end
        return super(player, target, ability)
    end)

    m:addOverride('xi.actions.abilities.steal.onUseAbility', function(player, target, ability)
        if isActive(player, 'phantom') then
            executePhantomsDare(player, target, ability)
            return 0
        end
        return super(player, target, ability)
    end)
end

-- Expose pure helpers for unit/regression testing.
xi.overlords.thf =
{
    executePhantomsDare = executePhantomsDare,
    clearPhantomGuard   = clearPhantomGuard,
    didWeaponSkillLand  = didWeaponSkillLand,
    attachFor           = attachFor,
    removeListeners     = removeListeners,
}

-- Register reviewed action manifest entries in opt-in Soul action registry (if not already present).
if soulActions and soulActions.register and soulActions.definitions then
    if not soulActions.definitions['trickster'] then
        soulActions.register('trickster', {
            spell = {},
            ability = {
                [ABIL_TRICK_ATTACK] = {
                    name = 'Trick Attack',
                    description = 'Route threat through an aligned ally; loaned from Lv10 for Trickster.',
                    recastTime = 60,
                },
            },
            weaponskill = {},
        })
    end
    if not soulActions.definitions['bandit'] then
        soulActions.register('bandit', {
            spell = {},
            ability = {
                [ABIL_SNEAK_ATTACK] = {
                    name = 'Sneak Attack',
                    description = 'Positional critical opener; loaned from Lv10 for Bandit.',
                    recastTime = 60,
                },
            },
            weaponskill = {},
        })
    end
    if not soulActions.definitions['phantom'] then
        soulActions.register('phantom', {
            spell = {},
            ability = {
                [ABIL_STEAL] = {
                    name = "Phantom's Dare",
                    description = '15y cold-start taunt (180 CE / 650 VE, 18s CD) and 6s one-hit guard against unavoidable magic/breath.',
                    gameplayProfile = 'thf_phantom_dare',
                    recastTime = 18,
                },
            },
            weaponskill = {},
        })
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
                'Starter Lv10 Trick Attack loan for positional threat transfer without subjob dependency.',
                'Every 20s, a landed Dagger/Sword weaponskill applies 5/7/9/12% Attack Down for 16s if the enemy is not already affected.',
                'Weakness: limited self-sustain and offensive throughput; missed WS never triggers suppression.',
            },
            extraAbilities = { ABIL_TRICK_ATTACK },
            mods = function(_player, level)
                return
                {
                    { xi.mod.DAGGER,      scale(level, 12, 20, 30, 42) },
                    { xi.mod.ACC,         scale(level, 10, 16, 24, 32) },
                    { xi.mod.DEX,         scale(level, 6, 10, 15, 20) },
                    { xi.mod.SUBTLE_BLOW, scale(level, 5, 8, 12, 16) },
                    { xi.mod.ENMITY,     -scale(level, 8, 12, 16, 20) },
                }
            end,
            onApply  = function(player) attachFor('trickster', player) end,
            onRemove = removeListeners,
        },
        {
            id = 2, key = 'bandit', name = 'Bandit', abr = 'BND',
            role = 'Damage', icon = 'bandit', reqLevel = 10,
            description = 'An opportunistic cutpurse: strikes hard when allies or weapon effects expose a target. Rewards reading vulnerabilities instead of building a personal stack bar.',
            highlights =
            {
                'Starter Lv10 Sneak Attack loan for immediate solo/party openers.',
                'Landed Dagger/Sword weaponskills exploit existing Defense Down for +75/100/125/150 TP (once per 12s).',
                'Missed WS yields zero refund and leaves the 12s ICD ready; Bandit never applies Defense Down itself.',
            },
            extraAbilities = { ABIL_SNEAK_ATTACK },
            mods = function(_player, level)
                return
                {
                    { xi.mod.DAGGER,      scale(level, 12, 22, 34, 48) },
                    { xi.mod.ACC,         scale(level, 10, 20, 30, 42) },
                    { xi.mod.ATT,         scale(level, 12, 24, 38, 55) },
                    { xi.mod.DEX,         scale(level, 6, 12, 18, 24) },
                    { xi.mod.CRITHITRATE, scale(level, 3, 5, 7, 9) },
                    { xi.mod.STORETP,     scale(level, 3, 5, 7, 10) },
                }
            end,
            onApply  = function(player) attachFor('bandit', player) end,
            onRemove = removeListeners,
        },
        {
            id = 3, key = 'phantom', name = 'Phantom', abr = 'PHN',
            role = 'Tank', icon = 'phantom', reqLevel = 10,
            description = 'An elusive trick-fighter: opens with Phantom\'s Dare and maintains enemy attention by frustrating physical attacks through avoidance; no shadow clones or martial riposte loop.',
            highlights =
            {
                'Phantom\'s Dare (15y, 18s CD, 0 TP, no /WAR): 180 CE / 650 VE + 6s one-hit 8/10/12/15% guard vs unavoidable magic/breath.',
                'Evaded regular melee attacks reinforce enmity (+30/40/55/70 CE, +85/115/150/190 VE) every 2s with Dagger/Katana.',
                'Weakness: sustained unavoidable magic/breath after the one-hit guard is consumed.',
            },
            extraAbilities = { ABIL_STEAL },
            mods = function(_player, level)
                return
                {
                    { xi.mod.DAGGER, scale(level, 10, 20, 30, 42) },
                    { xi.mod.EVA,    scale(level, 20, 35, 55, 75) },
                    { xi.mod.AGI,    scale(level, 7, 12, 18, 25) },
                    { xi.mod.HPP,    scale(level, 8, 12, 16, 20) },
                    { xi.mod.DMG,   -scale(level, 500, 700, 1000, 1200) },
                    { xi.mod.ENMITY, scale(level, 20, 30, 40, 50) },
                }
            end,
            onApply  = function(player) attachFor('phantom', player) end,
            onRemove = removeListeners,
        },
    }

    -- Register additively without replacing any existing THF entries.
    for _, entry in ipairs(specs) do
        local existing = spec.jobs[THF]
        local byKey = existing and existing.byKey
        if not byKey or not byKey[entry.key] then
            spec.registerCrystal(xi.job.THF, entry)
        end
    end
end

-- Reattach listeners on login/zone.
if xi.player and xi.player.onGameIn then
    m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
        super(player, firstLogin, zoning)
        for _, key in ipairs(KEYS) do
            if isActive(player, key) then
                attachFor(key, player)
                break
            end
        end
    end)
end

-- Server-confirmed HUD providers (optional, only if overlords_soul_hud is loaded).
if xi.overlords.hud and xi.overlords.hud.registerProvider then
    xi.overlords.hud.registerProvider('trickster', function(player)
        return { weaken_cd = math.ceil(cooldownRemaining(player, VAR_TRK_WEAKEN, 20)) }
    end)
    xi.overlords.hud.registerProvider('bandit', function(player)
        local tgt = player.getTarget and player:getTarget() or nil
        local defDown = (tgt and tgt.hasStatusEffect and tgt:hasStatusEffect(xi.effect.DEFENSE_DOWN)) and 1 or 0
        return {
            exploit_cd = math.ceil(cooldownRemaining(player, VAR_BND_EXPLOIT, 12)),
            def_down   = defDown,
        }
    end)
    xi.overlords.hud.registerProvider('phantom', function(player)
        local now = xi.overlords.nowSec()
        local guardUntil = player.getLocalVar and (player:getLocalVar(VAR_PHN_DARE_END) or 0) or 0
        local guardRem = guardUntil > now and math.ceil(guardUntil - now) or 0
        return {
            dare_cd   = math.ceil(cooldownRemaining(player, VAR_PHN_DARE_CD, 18)),
            evade_cd  = math.ceil(cooldownRemaining(player, VAR_PHN_EVADE, 2)),
            guard_rem = guardRem,
            guard_pct = guardRem > 0 and (player:getLocalVar(VAR_PHN_DARE_PCT) or 0) or 0,
        }
    end)
end

return m
