-----------------------------------
-- OverlordsXI Warrior Crystal Specs
-- Registers Warrior crystals (Commander, Berserker, Spartan [formerly Gladiator]) and
-- implements their passive scaling stats and ability transformations.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/combat/skillchain')
require('scripts/globals/job_utils/warrior')
require('scripts/globals/spells/damage_spell')
-----------------------------------
local m = Module:new('overlords_war_specs')

local spec = xi.overlords.spec

local COMMANDER_KEY = 'commander'
local BERSERKER_KEY = 'berserker'
local SPARTAN_KEY = 'spartan'

local COMMANDER_BREACH_ABIL_ID  = 396
local COMMANDER_BULWARK_ABIL_ID = 397
local COMMANDER_CADENCE_ABIL_ID = 398
local COMMANDER_HORN_ABIL_ID    = 399
local BERSERKER_SURGE_ABIL_ID   = 400
local BERSERKER_CLEAVE_ABIL_ID  = 401
local SPARTAN_THRUST_ABIL_ID   = 402
local SPARTAN_WARD_ABIL_ID    = 403

local COMMANDER_BREACH_EFFECT_ID  = 815
local COMMANDER_BULWARK_EFFECT_ID = 816
local COMMANDER_CADENCE_EFFECT_ID = 817
local COMMANDER_REGROUP_EFFECT_ID = 818
local BERSERKER_SURGE_EFFECT_ID   = 819
local SPARTAN_WARD_EFFECT_ID    = 820

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.TACTICAL_BREACH   = COMMANDER_BREACH_ABIL_ID
xi.jobAbility.FORMATION_BULWARK = COMMANDER_BULWARK_ABIL_ID
xi.jobAbility.BATTLE_CADENCE    = COMMANDER_CADENCE_ABIL_ID
xi.jobAbility.RALLYING_HORN     = COMMANDER_HORN_ABIL_ID
xi.jobAbility.BLOODLUST_SURGE   = BERSERKER_SURGE_ABIL_ID
xi.jobAbility.SAVAGE_CLEAVE     = BERSERKER_CLEAVE_ABIL_ID
xi.jobAbility.IMPALING_THRUST   = SPARTAN_THRUST_ABIL_ID
xi.jobAbility.PHALANX_WARD      = SPARTAN_WARD_ABIL_ID
xi.jobAbility.CRIMSON_CRUSH     = SPARTAN_THRUST_ABIL_ID -- legacy alias
xi.jobAbility.VANGUARD_WARD     = SPARTAN_WARD_ABIL_ID   -- legacy alias

xi.effect = xi.effect or {}
xi.effect.COMMANDER_BREACH  = COMMANDER_BREACH_EFFECT_ID
xi.effect.COMMANDER_BULWARK = COMMANDER_BULWARK_EFFECT_ID
xi.effect.COMMANDER_CADENCE = COMMANDER_CADENCE_EFFECT_ID
xi.effect.COMMANDER_REGROUP = COMMANDER_REGROUP_EFFECT_ID
xi.effect.BERSERKER_SURGE   = BERSERKER_SURGE_EFFECT_ID
xi.effect.GLADIATOR_WARD    = SPARTAN_WARD_EFFECT_ID -- legacy alias
xi.effect.SPARTAN_WARD      = SPARTAN_WARD_EFFECT_ID

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.tactical_breach   = xi.actions.abilities.tactical_breach or {}
xi.actions.abilities.formation_bulwark = xi.actions.abilities.formation_bulwark or {}
xi.actions.abilities.battle_cadence    = xi.actions.abilities.battle_cadence or {}
xi.actions.abilities.rallying_horn     = xi.actions.abilities.rallying_horn or {}
xi.actions.abilities.bloodlust_surge   = xi.actions.abilities.bloodlust_surge or {}
xi.actions.abilities.savage_cleave     = xi.actions.abilities.savage_cleave or {}
xi.actions.abilities.impaling_thrust   = xi.actions.abilities.impaling_thrust or {}
xi.actions.abilities.phalanx_ward      = xi.actions.abilities.phalanx_ward or {}

xi.effects = xi.effects or {}
xi.effects.commander_breach  = xi.effects.commander_breach or {}
xi.effects.commander_bulwark = xi.effects.commander_bulwark or {}
xi.effects.commander_cadence = xi.effects.commander_cadence or {}
xi.effects.commander_regroup = xi.effects.commander_regroup or {}
xi.effects.berserker_surge   = xi.effects.berserker_surge or {}
xi.effects.gladiator_ward    = xi.effects.gladiator_ward or {}

local COMMANDER_STANCES =
{
    xi.effect.BERSERK,
    xi.effect.DEFENDER,
    xi.effect.AGGRESSOR,
    xi.effect.RETALIATION,
    xi.effect.RESTRAINT,
}

local pendingWarcryMods = {}
local pendingBloodRageMods = {}
local pendingCommanderMods = {}

local function scaleTier(lvl, low, mid, high)
    local l = lvl or 1
    if l >= 50 then
        return high
    elseif l >= 30 then
        return mid
    end
    return low
end

local function scaleCommanderTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 then
        return lv70, 4
    elseif l >= 50 then
        return lv50, 3
    elseif l >= 30 then
        return lv30, 2
    end
    return lv10, 1
end

local function isWarriorSpec(entity, specKey)
    if entity == nil or not entity:isPC() or entity:getMainJob() ~= xi.job.WAR then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.WAR, specKey)
end

local function hasShieldEquipped(player)
    if player == nil then
        return false
    end

    if player.getEquippedItem and xi.slot and xi.slot.SUB then
        local sub = player:getEquippedItem(xi.slot.SUB)
        if sub ~= nil and sub.isShield then
            return sub:isShield()
        end
    end

    if player.getShieldSize then
        return (player:getShieldSize() or 0) > 0
    end

    return false
end

-----------------------------------
-- Spartan helpers: Polearm + Size-1 Buckler, Spartan's Grit, Spear-Wall Brace
-----------------------------------
local GRIT_VAR       = 'OX_SPT_GRIT'
local BRACE_VAR      = 'OX_SPT_BRACE'      -- 0 none, 1 light, 2 heavy
local BRACE_MOD_VAR  = 'OX_SPT_BRACE_MOD'  -- DMG mod value currently applied
local BRACE_TOK_VAR  = 'OX_SPT_BRACE_TOK'
local ADRENALINE_VAR = 'OX_SPT_ADRENALINE'
local TICK_VAR       = 'OX_SPT_TICK'
local MAX_GRIT       = 5

local gritBlockStamp = {}

local function hasPolearmMain(player)
    return player ~= nil and
        player.getWeaponSkillType and
        xi.slot and xi.skill and
        player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
end

-- Real Size-1 Buckler in SUB.
local function hasSize1Buckler(player)
    if player == nil or not player.getEquippedItem or not xi.slot then
        return false
    end

    local sub = player:getEquippedItem(xi.slot.SUB)
    return sub ~= nil and sub.isShield ~= nil and sub:isShield() and sub:getShieldSize() == 1
end

-- Real Size-1 Buckler or empty SUB (virtual Aspis Buckler).
local function hasBucklerSetup(player)
    if hasSize1Buckler(player) then
        return true
    end

    return player ~= nil and player.getEquippedItem ~= nil and player:getEquippedItem(xi.slot.SUB) == nil
end

local function isPhalanxSetup(player)
    return hasPolearmMain(player) and hasBucklerSetup(player)
end

local function getGrit(player)
    return player:getLocalVar(GRIT_VAR)
end

local function addGrit(player, amount)
    if player == nil or amount == nil or amount <= 0 then
        return 0
    end

    local grit = utils.clamp(getGrit(player) + amount, 0, MAX_GRIT)
    player:setLocalVar(GRIT_VAR, grit)
    return grit
end

local function getTierIndex(lvl)
    local l = lvl or 1
    if l >= 70 then
        return 4
    elseif l >= 50 then
        return 3
    elseif l >= 30 then
        return 2
    end
    return 1
end

local function pickTier(lvl, a, b, c, d)
    local list = { a, b, c, d }
    return list[getTierIndex(lvl)]
end

local function applyDebuff(target, effectId, power, duration, origin, mods)
    if target == nil or xi.overlords == nil or xi.overlords.slots == nil then
        return false
    end

    local clean = {}
    for _, pair in ipairs(mods) do
        if pair[1] ~= nil then
            table.insert(clean, pair)
        end
    end

    return xi.overlords.slots.applySlot(target, effectId, power, duration, origin, clean, effectId)
end

-- Maim / Cripple: -15% ATTP, -20 ACC
local function applyMaim(target, origin, duration)
    applyDebuff(target, xi.effect.EFF_OX_DEB_CRIPPLE, 15, duration or 15, origin,
    {
        { xi.mod.ATTP, -15 },
        { xi.mod.ACC,  -20 },
    })
end

-- Off-Balance: -15 ACC, -15% Multi-Attack, +20% Cast Time
local function applyOffBalance(target, origin)
    applyDebuff(target, xi.effect.EFF_OX_DEB_EXPOSE, 15, 6, origin,
    {
        { xi.mod.ACC,           -15 },
        { xi.mod.DOUBLE_ATTACK, -15 },
        { xi.mod.TRIPLE_ATTACK, -15 },
        { xi.mod.FASTCAST,      -20 },
    })
end

-- Exposed Guard: -15% DEF / -15 MDEF, 0% Multi-Attack / Crit
local function applyExposedGuard(target, origin)
    applyDebuff(target, xi.effect.EFF_OX_DEB_BREACH, 15, 8, origin,
    {
        { xi.mod.DEFP,          -15 },
        { xi.mod.MDEF,          -15 },
        { xi.mod.DOUBLE_ATTACK, -100 },
        { xi.mod.TRIPLE_ATTACK, -100 },
        { xi.mod.CRITHITRATE,   -100 },
    })
end

local function isTargetCasting(target)
    if target == nil or not target.getCurrentAction or not xi.action then
        return false
    end

    local act = target:getCurrentAction()
    return act == xi.action.MAGIC_START or act == xi.action.MAGIC_CASTING
end

local function staggerTarget(target, origin, seconds, silenceSeconds)
    if target == nil or not target.addStatusEffect then
        return
    end

    target:addStatusEffect(xi.effect.STUN, { power = 1, duration = seconds, origin = origin })
    if silenceSeconds ~= nil and silenceSeconds > 0 then
        target:addStatusEffect(xi.effect.SILENCE, { power = 1, duration = silenceSeconds, origin = origin })
    end
end

-- Brace: a one-shot damage cut implemented as a temporary DMG mod that is
-- removed the moment the next hit lands (TAKE_DAMAGE).
local function disarmBrace(player)
    if player == nil then
        return
    end

    local applied = player:getLocalVar(BRACE_MOD_VAR)
    if applied ~= 0 then
        player:delMod(xi.mod.DMG, applied)
    end

    player:setLocalVar(BRACE_MOD_VAR, 0)
    player:setLocalVar(BRACE_VAR, 0)
end

local function armBrace(player, level)
    if player == nil then
        return
    end

    disarmBrace(player)

    -- Light: -25% hit damage. Heavy: -50% hit damage.
    local dmgMod = level >= 2 and -5000 or -2500
    player:addMod(xi.mod.DMG, dmgMod)
    player:setLocalVar(BRACE_MOD_VAR, dmgMod)
    player:setLocalVar(BRACE_VAR, level)

    local token = player:getLocalVar(BRACE_TOK_VAR) + 1
    player:setLocalVar(BRACE_TOK_VAR, token)
    player:timer(10000, function(p)
        if p ~= nil and p:getLocalVar(BRACE_TOK_VAR) == token and p:getLocalVar(BRACE_VAR) > 0 then
            disarmBrace(p)
        end
    end)
end

-- Iron Resolve: HP barrier from consumed Grit. Non-stacking (never replaces a stronger barrier).
local function applyIronResolve(player, stacks)
    if stacks <= 0 then
        return
    end

    local lvl      = player:getMainLvl()
    local perStack = pickTier(lvl, 4, 5, 6, 7)
    local capPct   = hasSize1Buckler(player) and 40 or 35
    local pct      = math.min(capPct, perStack * stacks)
    local amount   = math.floor(player:getMaxHP() * pct / 100)

    local existing = player:getStatusEffect(xi.effect.STONESKIN)
    if existing ~= nil and existing:getPower() >= amount then
        return
    end

    player:delStatusEffectSilent(xi.effect.STONESKIN)
    player:addStatusEffect(xi.effect.STONESKIN, { power = amount, duration = 30, origin = player })
end

-- Adrenaline Surge: 20% Max HP self-heal below 50% HP, 30s ICD.
local function tryAdrenalineSurge(player)
    if player == nil or not isWarriorSpec(player, SPARTAN_KEY) then
        return
    end

    local maxHp = player:getMaxHP()
    if maxHp <= 0 or player:getHP() >= maxHp * 0.5 then
        return
    end

    local now = os.time()
    if now < player:getLocalVar(ADRENALINE_VAR) then
        return
    end

    player:setLocalVar(ADRENALINE_VAR, now + 30)
    player:addHP(math.floor(maxHp * 0.20))
end

local function onSpartanHit(defender, amount, attacker, attackType)
    if defender == nil or not isWarriorSpec(defender, SPARTAN_KEY) or not isPhalanxSetup(defender) then
        return
    end

    if (amount or 0) <= 0 and attacker == nil then
        return
    end

    local brace = defender:getLocalVar(BRACE_VAR)
    local spell = attackType == xi.attackType.MAGICAL or attackType == xi.attackType.SPELL

    if brace > 0 then
        disarmBrace(defender)

        if attacker ~= nil and attacker.getID then
            if brace >= 2 then
                -- Phalanx Deflection
                defender:setLocalVar(GRIT_VAR, MAX_GRIT)
                staggerTarget(attacker, defender, 2, spell and 4 or 0)
                applyExposedGuard(attacker, defender)
            else
                -- Light Brace
                addGrit(defender, 1)
                applyOffBalance(attacker, defender)
            end
        end

        return
    end

    local stamp = gritBlockStamp[defender:getID()]
    if stamp ~= nil and os.clock() - stamp < 0.5 then
        return
    end

    addGrit(defender, 1)
end

-- Tactical Instinct: warn when the engaged target is coiling for a heavy attack / casting.
local function startTacticalInstinct(player)
    if player == nil or not player.timer then
        return
    end

    local token = player:getLocalVar(TICK_VAR) + 1
    player:setLocalVar(TICK_VAR, token)

    local warnedTp, warnedCast = false, false

    local function tick(p)
        if
            p == nil or
            p:getLocalVar(TICK_VAR) ~= token or
            not isWarriorSpec(p, SPARTAN_KEY)
        then
            return
        end

        local target = p.getTarget and p:getTarget() or nil
        if target ~= nil and target.getTP and p:getBattleTarget() ~= nil then
            if target:getTP() >= 750 then
                if not warnedTp then
                    warnedTp = true
                    p:printToPlayer(string.format('[Sense] %s is coiling for a heavy attack!', target:getName()))
                end
            else
                warnedTp = false
            end

            if isTargetCasting(target) then
                if not warnedCast then
                    warnedCast = true
                    p:printToPlayer(string.format('[Sense] %s is coiling for a heavy attack!', target:getName()))
                end
            else
                warnedCast = false
            end
        else
            warnedTp, warnedCast = false, false
        end

        p:timer(1500, tick)
    end

    player:timer(1500, tick)
end

local function detachSpartanListeners(player)
    if player ~= nil and player.removeListener then
        player:removeListener('OX_SPT_HIT')
        player:removeListener('OX_SPT_WS')
    end

    if player ~= nil then
        player:setLocalVar(TICK_VAR, player:getLocalVar(TICK_VAR) + 1)
        disarmBrace(player)
        player:setLocalVar(GRIT_VAR, 0)
        player:setLocalVar('OX_POLEARM_BUCKLER', 0)
    end
end

local function attachSpartanListeners(player)
    if player == nil or not player.addListener then
        return
    end

    detachSpartanListeners(player)
    player:setLocalVar('OX_POLEARM_BUCKLER', 1)

    player:addListener('TAKE_DAMAGE', 'OX_SPT_HIT', function(defender, amount, attacker, attackType, _damageType)
        onSpartanHit(defender, amount, attacker, attackType)
    end)

    -- Spartan's Grit: any Polearm WS (that landed) converts Grit into Iron Resolve.
    player:addListener('WEAPONSKILL_USE', 'OX_SPT_WS', function(actor, target, _ws, _tp, _action, dmg)
        if
            actor == nil or
            target == nil or
            target == actor or
            (dmg ~= nil and dmg <= 0) or
            not isWarriorSpec(actor, SPARTAN_KEY) or
            not hasPolearmMain(actor)
        then
            return
        end

        local stacks = getGrit(actor)
        if stacks <= 0 then
            return
        end

        actor:setLocalVar(GRIT_VAR, 0)
        applyIronResolve(actor, stacks)

        if target.addEnmity then
            target:addEnmity(actor, 100 * stacks, 300 * stacks)
        end

        applyMaim(target, actor, 15)
    end)

    startTacticalInstinct(player)
end

local function clearOtherCommanderStances(player, keepEffectId)
    if player == nil then
        return
    end

    for _, effId in ipairs(COMMANDER_STANCES) do
        if effId ~= keepEffectId and player:hasStatusEffect(effId) then
            player:delStatusEffectSilent(effId)
        end
    end
end

local function enforceSingleCommanderStance(player)
    if player == nil then
        return
    end

    local kept = nil
    for _, effId in ipairs(COMMANDER_STANCES) do
        if player:hasStatusEffect(effId) then
            if kept == nil then
                kept = effId
            else
                player:delStatusEffectSilent(effId)
            end
        end
    end
end

local function getCommanderActiveStance(player)
    if player == nil then
        return nil
    end

    for _, effId in ipairs(COMMANDER_STANCES) do
        if player:hasStatusEffect(effId) then
            return effId
        end
    end

    return nil
end

-----------------------------------
-- Crystal Definitions (WAR)
-----------------------------------
if xi.job and xi.job.WAR then
    spec.registerJob(xi.job.WAR, 'WAR',
    {
        {
            id          = 1,
            key         = COMMANDER_KEY,
            name        = 'Commander',
            role        = 'Active Tactical Buffer',
            icon        = 'blue_crystal',
            reqLevel    = 10,
            extraAbilities =
            {
                (xi.jobAbility and xi.jobAbility.WARCRY) or 2,
                COMMANDER_BREACH_ABIL_ID,
                COMMANDER_BULWARK_ABIL_ID,
                COMMANDER_CADENCE_ABIL_ID,
                COMMANDER_HORN_ABIL_ID,
            },
            extraTraits    = { 140 },
            description = 'Active battlefield tactician (Lv10+): weaves short-cooldown party & mark JAs that scale stronger as you level (Lv10/30/50/70+), shares your active WAR stance with Warcry, and trades swing uptime for JA animation locks.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +5/8/12% Max HP, +8/16/28 Attack, +6/12/20 Acc, +4/8/12 Store TP.',
                'Early & Rapid Warcry (Lv10, 60s CD): Shares your single active WAR stance (Berserk, Defender, Aggressor, Retaliation, or Restraint) with the party.',
                'Tactical Breach (Lv10, 20s CD, 10s, Enemy 15y): +12/18/24/30% Skillchain DMG, +8/12/16/20% Magic Burst & Crit DMG, +100/150/200/250 TP on SC close.',
                'Formation: Bulwark (Lv10, 25s CD, 15s, Party 10y): Stacking Phalanx (8 + 0.45*Lv), +5/10/15/20 MDEF, +12/18/25/35 Status Resist, +30/50/75/100% Knockback Resist.',
                'Battle Cadence (Lv10, 20s CD, 12s, Party 10y): +12/18/24/30 Subtle Blow (+0/0/5/10 SB II), +10/15/22/30 Conserve TP, +8/12/16/20% Cure Rcvd.',
                'Rallying Horn (Lv10, 45s CD, 12s, Party 12y): Cleanses Slow/Bind (Lv30+ Weight/Para; Lv50+ DEF/MDEF Down; Lv70+ Atk/Acc Down), +5/7/9/12% HP, +75/125/175/250 TP, +8/10/12/15% Move Speed.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.HPP,     scaleTier(lvl, 5, 8, 12) },
                    { xi.mod.ATT,     scaleTier(lvl, 8, 16, 28) },
                    { xi.mod.ACC,     scaleTier(lvl, 6, 12, 20) },
                    { xi.mod.STORETP, scaleTier(lvl, 4, 8, 12) },
                }
            end,
            onApply = function(player)
                enforceSingleCommanderStance(player)
            end,
        },
        {
            id          = 2,
            key         = BERSERKER_KEY,
            name        = 'Berserker',
            role        = 'Fury / Heavy Burst DPS',
            icon        = 'crimson_shard',
            reqLevel    = 10,
            extraAbilities =
            {
                BERSERKER_SURGE_ABIL_ID,
                BERSERKER_CLEAVE_ABIL_ID,
            },
            extraTraits = { 141 },
            description = 'Unrelenting fury (Lv10+): amplifies Berserk, Blood Rage, and Warcry with heavy Attack, Double Attack, and WSD.',
            highlights  =
            {
                'Passives (Lv10/30/50+): +8/12/16% Attack, +6/10/14% Double Attack, +5/8/12% WS Damage, +5/10/15 Store TP.',
                'Bloodlust Surge (Lv10, 25s CD, 10s, Self): +10/14/18/24% Attack% and +15/22/30/40% Double Attack Damage at -10% DEF%.',
                'Savage Cleave (Lv10, 20s CD, Enemy 4y): Overstraining physical strike (0 TP gained) that inflicts 6/8/10/12% Max HP recoil.',
                'Berserk: +10% extra Attack%, +60s duration, and instantly grants +300 TP on activation.',
                'Aggressor: Removes -25 Evasion penalty and grants +5% Critical Hit Rate.',
                'Blood Rage: +10% extra Critical Hit Rate and +15s duration.',
                'Warcry: +8% extra Attack% potency.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.ATTP,               scaleTier(lvl, 8, 12, 16) },
                    { xi.mod.DOUBLE_ATTACK,      scaleTier(lvl, 6, 10, 14) },
                    { xi.mod.ALL_WSDMG_ALL_HITS, scaleTier(lvl, 5, 8, 12) },
                    { xi.mod.STORETP,            scaleTier(lvl, 5, 10, 15) },
                }
            end,
        },
        {
            id          = 3,
            key         = SPARTAN_KEY,
            name        = 'Spartan',
            role        = 'Phalanx Spear-Wall & Grit Barrier Tank',
            icon        = 'amber_crescent',
            reqLevel    = 10,
            extraAbilities =
            {
                SPARTAN_THRUST_ABIL_ID,
                SPARTAN_WARD_ABIL_ID,
            },
            extraTraits = { 142 },
            description = 'Frontline phalanx tank (Lv10+): requires a Polearm paired with a Size-1 Buckler (or an empty SUB for a virtual Aspis Buckler) to unlock Spear-Wall Guard/Block, Spartan\'s Grit damage-to-barrier conversion, and charge-based Melee & Spell Brace deflection.',
            highlights  =
            {
                'Passives (Lv10/30/50/70+): +12/16/20/25% Max HP, +8/14/20/26 VIT, +14/20/26/32% DEF (+12/24/36/48 Shield DEF), -8/11/14/18% Damage Taken, +60/80/100/120 Enmity, +20/30/40/50% Enmity Retention.',
                'Phalanx Spear & Buckler Mastery: +15/25/35/50 Polearm & Shield skill, +10/16/22/28% Block Rate, +15/25/35/45 Shield TP. Real Size-1 Buckler: +10% Block and Iron Resolve cap 40% Max HP; empty SUB: 10% virtual Aspis Buckler block.',
                'Spartan\'s Grit: taking damage or blocking grants +1 Grit (max 5). Any Polearm WS consumes all Grit for an Iron Resolve barrier (4/5/6/7% Max HP per stack, cap 35%/40%), heavy enmity, and Maim.',
                'Impaling Thrust (Lv10, 20s CD, Enemy 8y, Polearm): Stun 2s (+5s Silence mid-cast), Maim, +2 Grit (+4 during Defender / Mighty Strikes).',
                'Phalanx Ward (Lv10, 35s CD, 2 Grit, Self 12s, Polearm): +15/22/30/38% Block, -10/12/15/18% DT, +25/35/45/55 Enmity, Knockback Immunity, arms a Heavy Brace.',
                'Spear-Wall Brace: Defender (15s CD) arms a Light Brace (-25% next hit, +1 Grit, Off-Balance). Heavy Brace: -50% next hit, Grit to 5, 2s Stun, Exposed Guard (+4s Silence vs spells).',
                'Tactical Instinct: warns when your target crosses 750 TP or begins casting.',
                'Tier 6 Tank: -60% Physical & Magical Damage Dealt, no negative ATTP/RATTP/WSD penalties.',
                'WAR JAs: Warcry (party -8% DMG, +20 self Enmity, Adrenaline Surge below 50% HP), Provoke (Adrenaline Surge below 50% HP), Mighty Strikes (-25% DT, +50 Enmity, instant 5 Grit).',
            },
            mods = function(_player, lvl)
                local mods =
                {
                    { xi.mod.HPP,                  pickTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.VIT,                  pickTier(lvl, 8, 14, 20, 26) },
                    { xi.mod.DEFP,                 pickTier(lvl, 14, 20, 26, 32) },
                    { xi.mod.SHIELD_DEF_BONUS,     pickTier(lvl, 12, 24, 36, 48) },
                    { xi.mod.DMG,                  pickTier(lvl, -800, -1100, -1400, -1800) },
                    { xi.mod.ENMITY,               pickTier(lvl, 60, 80, 100, 120) },
                    { xi.mod.POLEARM,              pickTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.SHIELD,               pickTier(lvl, 15, 25, 35, 50) },
                    { xi.mod.PALISADE_BLOCK_BONUS, pickTier(lvl, 10, 16, 22, 28) },
                    { xi.mod.SHIELD_MASTERY_TP,    pickTier(lvl, 15, 25, 35, 45) },
                }

                if xi.mod.ENMITY_LOSS_REDUCTION then
                    table.insert(mods, { xi.mod.ENMITY_LOSS_REDUCTION, pickTier(lvl, 20, 30, 40, 50) })
                end

                return mods
            end,
            onApply = function(player)
                attachSpartanListeners(player)
            end,
            onRemove = function(player)
                detachSpartanListeners(player)
            end,
        },
    })
end

-----------------------------------
-- Commander Early & Short-CD Warcry Gate
-----------------------------------
m:addOverride('xi.actions.abilities.warcry.onAbilityCheck', function(player, target, ability)
    if player ~= nil and player:isPC() then
        spec.ensureUpToDate(player)

        if isWarriorSpec(player, COMMANDER_KEY) then
            if ability ~= nil and ability.setRecast then
                ability:setRecast(60)
            end
        else
            local warLvl = 0
            if player:getMainJob() == xi.job.WAR then
                warLvl = player:getMainLvl()
            elseif player.getSubJob and player:getSubJob() == xi.job.WAR and player.getSubLvl then
                warLvl = player:getSubLvl()
            end

            if warLvl < 35 then
                return xi.msg.basic.UNABLE_TO_USE_JA, 0
            end
        end
    end

    return super(player, target, ability)
end)

-----------------------------------
-- Warrior Ability & Effect Overrides
-----------------------------------
m:addOverride('xi.job_utils.warrior.useBerserk', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.BERSERK)
        local duration = 180 + player:getMod(xi.mod.BERSERK_DURATION)
        player:addStatusEffect(xi.effect.BERSERK, { power = 10, duration = duration, origin = player, subPower = 10 })
        return xi.effect.BERSERK
    elseif isWarriorSpec(player, BERSERKER_KEY) then
        local warriorLevel = player:getMainLvl()
        local levelScale   = math.floor((warriorLevel - 40) / 10) * 2
        local power        = 35 + player:getMod(xi.mod.BERSERK_POTENCY) + utils.clamp(levelScale, 0, 10)
        local duration     = 240 + player:getMod(xi.mod.BERSERK_DURATION)

        player:addStatusEffect(xi.effect.BERSERK, { power = power, duration = duration, origin = player, subPower = 25 })
        if player.addTP then
            player:addTP(300)
        end

        return xi.effect.BERSERK
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.warrior.useDefender', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.DEFENDER)
        local duration = 180 + player:getMod(xi.mod.DEFENDER_DURATION)
        player:addStatusEffect(xi.effect.DEFENDER, { power = 15, duration = duration, origin = player, subPower = 1 })
        return xi.effect.DEFENDER
    elseif isWarriorSpec(player, SPARTAN_KEY) then
        local duration = 180 + player:getMod(xi.mod.DEFENDER_DURATION)
        player:addStatusEffect(xi.effect.DEFENDER, { power = 30, duration = duration, origin = player, subPower = 2 })
        if hasPolearmMain(player) then
            armBrace(player, 1)
        end

        return xi.effect.DEFENDER
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.defender.onEffectGain', function(target, effect)
    super(target, effect)

    if effect == nil then
        return
    end

    local tag = effect:getSubPower()
    if tag == 1 then
        -- Commander Defender: +15% DEFP with only -10% ATTP/RATTP penalty (vs retail -25%)
        effect:addMod(xi.mod.ATTP, 15)
        effect:addMod(xi.mod.RATTP, 15)
    elseif tag == 2 then
        -- Spartan Defender (Spear-Wall): +30% DEFP, -10% PDT, +15% Block, zero Attack penalty, arms Light Brace
        effect:addMod(xi.mod.DMGPHYS, -1000)
        effect:addMod(xi.mod.PALISADE_BLOCK_BONUS, 15)
        effect:addMod(xi.mod.ATTP, 25)
        effect:addMod(xi.mod.RATTP, 25)
    end
end)

m:addOverride('xi.job_utils.warrior.useAggressor', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.AGGRESSOR)
        local merits = player:getMerit(xi.merit.AGGRESSIVE_AIM)
        player:addStatusEffect(xi.effect.AGGRESSOR, { power = merits, duration = 180 + player:getMod(xi.mod.AGGRESSOR_DURATION), origin = player, subPower = 3 })
        return xi.effect.AGGRESSOR
    elseif isWarriorSpec(player, BERSERKER_KEY) then
        local merits = player:getMerit(xi.merit.AGGRESSIVE_AIM)
        player:addStatusEffect(xi.effect.AGGRESSOR, { power = merits, duration = 180 + player:getMod(xi.mod.AGGRESSOR_DURATION), origin = player, subPower = 1 })
        return xi.effect.AGGRESSOR
    elseif isWarriorSpec(player, SPARTAN_KEY) then
        local merits = player:getMerit(xi.merit.AGGRESSIVE_AIM)
        player:addStatusEffect(xi.effect.AGGRESSOR, { power = merits, duration = 180 + player:getMod(xi.mod.AGGRESSOR_DURATION), origin = player, subPower = 2 })
        return xi.effect.AGGRESSOR
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.aggressor.onEffectGain', function(target, effect)
    super(target, effect)

    if effect == nil then
        return
    end

    local tag = effect:getSubPower()
    if tag == 1 then
        -- Berserker Aggressor: no EVA penalty + 5% Crit
        effect:addMod(xi.mod.EVA, 25)
        effect:addMod(xi.mod.CRITHITRATE, 5)
    elseif tag == 2 then
        -- Gladiator Aggressor (Challenger's Stance): no EVA penalty, +20 Enmity, +10% Shield Block Rate
        effect:addMod(xi.mod.EVA, 25)
        effect:addMod(xi.mod.ENMITY, 20)
        effect:addMod(xi.mod.PALISADE_BLOCK_BONUS, 10)
    elseif tag == 3 then
        -- Commander Aggressor: self +15 ACC/RACC and only -10 EVA (vs +25/-25)
        effect:addMod(xi.mod.ACC, -10)
        effect:addMod(xi.mod.RACC, 15)
        effect:addMod(xi.mod.EVA, 15)
    end
end)

m:addOverride('xi.job_utils.warrior.useRetaliation', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.RETALIATION)
        player:addStatusEffect(xi.effect.RETALIATION, { power = 1, duration = 180, origin = player, subPower = 2 })
        return xi.effect.RETALIATION
    elseif isWarriorSpec(player, SPARTAN_KEY) then
        player:addStatusEffect(xi.effect.RETALIATION, { power = 1, duration = 180, origin = player, subPower = 3 })
        return xi.effect.RETALIATION
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.retaliation.onEffectGain', function(target, effect)
    if effect ~= nil then
        local tag = effect:getSubPower()
        if tag == 2 then
            -- Commander Retaliation: no movement speed penalty + 8% Counter
            effect:addMod(xi.mod.COUNTER, 8)
            return
        elseif tag == 3 then
            -- Gladiator Retaliation: no movement speed penalty + 12% Counter + 15 Enmity
            effect:addMod(xi.mod.COUNTER, 12)
            effect:addMod(xi.mod.ENMITY, 15)
            return
        end
    end

    super(target, effect)
end)

m:addOverride('xi.effects.retaliation.onEffectLose', function(target, effect)
    if effect ~= nil and (effect:getSubPower() == 2 or effect:getSubPower() == 3) then
        return
    end

    super(target, effect)
end)

m:addOverride('xi.job_utils.warrior.useRestraint', function(player, target, ability)
    if isWarriorSpec(player, COMMANDER_KEY) then
        clearOtherCommanderStances(player, xi.effect.RESTRAINT)
    end

    return super(player, target, ability)
end)

m:addOverride('xi.job_utils.warrior.useBloodRage', function(player, target, ability)
    if isWarriorSpec(player, BERSERKER_KEY) then
        local power    = 30 + player:getJobPointLevel(xi.jp.BLOOD_RAGE_EFFECT)
        local duration = 45 + player:getMod(xi.mod.ENHANCES_BLOOD_RAGE)

        target:addStatusEffect(xi.effect.BLOOD_RAGE, { power = power, duration = duration, origin = player })

        if player:getID() ~= target:getID() then
            ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
        end

        return xi.effect.BLOOD_RAGE
    end

    return super(player, target, ability)
end)

m:addOverride('xi.effects.blood_rage.onEffectGain', function(target, effect)
    super(target, effect)

    if target == nil or effect == nil then
        return
    end

    if effect:getSubPower() == 1 then
        local extra = pendingBloodRageMods[target:getID()]
        if extra ~= nil then
            for _, pair in ipairs(extra) do
                effect:addMod(pair[1], pair[2])
            end
        end
    end
end)

m:addOverride('xi.job_utils.warrior.useWarcry', function(player, target, ability)
    local isCmd  = isWarriorSpec(player, COMMANDER_KEY)
    local isBrk  = isWarriorSpec(player, BERSERKER_KEY)
    local isSpt  = isWarriorSpec(player, SPARTAN_KEY)
    if not isCmd and not isBrk and not isSpt then
        return super(player, target, ability)
    end

    if isCmd then
        local isSelf    = (player:getID() == target:getID())
        local stance    = getCommanderActiveStance(player)
        local merit     = player:getMerit(xi.merit.SAVAGERY)
        local tpBonus   = merit + 100
        local warcryAtk = 8
        local duration  = 45 + player:getMod(xi.mod.WARCRY_DURATION)
        local extra     = nil

        if stance == xi.effect.BERSERK then
            -- Self Berserk grants +10% Atk; Warcry gives Commander +5% (15% total) and allies +15%
            warcryAtk = isSelf and 5 or 15
        elseif stance == xi.effect.DEFENDER then
            -- Self Defender grants +15% DEF; Warcry grants Commander +5% DEF (20% total) and allies +20% DEF, plus -8% DMG
            warcryAtk = 8
            extra =
            {
                { xi.mod.DEFP, isSelf and 5 or 20 },
                { xi.mod.DMG,  -800 },
            }
        elseif stance == xi.effect.AGGRESSOR then
            -- Self Aggressor grants +15 Acc/RAcc; Warcry brings everyone to +25 Acc/RAcc & +8% Double Attack
            warcryAtk = 8
            local accShare = isSelf and 10 or 25
            extra =
            {
                { xi.mod.ACC,           accShare },
                { xi.mod.RACC,          accShare },
                { xi.mod.DOUBLE_ATTACK, 8 },
            }
        elseif stance == xi.effect.RETALIATION then
            -- Self Retaliation grants +8% Counter; Warcry brings everyone to +12% Counter & +10 Store TP
            warcryAtk = 8
            extra =
            {
                { xi.mod.COUNTER, isSelf and 4 or 12 },
                { xi.mod.STORETP, 10 },
            }
        elseif stance == xi.effect.RESTRAINT then
            -- Restraint stance Warcry inspires party WS Burst: +12% WSD & +200 total TP Bonus
            warcryAtk = 8
            tpBonus = merit + 200
            extra =
            {
                { xi.mod.ALL_WSDMG_ALL_HITS, 12 },
            }
        end

        if target:hasStatusEffect(xi.effect.WARCRY) then
            target:delStatusEffectSilent(xi.effect.WARCRY)
        end

        local targetId = target:getID()
        pendingWarcryMods[targetId] = extra
        target:addStatusEffect(xi.effect.WARCRY, { power = warcryAtk, duration = duration, origin = player, subPower = tpBonus })
        pendingWarcryMods[targetId] = nil

        if not isSelf then
            ability:setMsg(xi.msg.basic.JA_ATK_ENHANCED)
        end

        return xi.effect.WARCRY
    end

    if isSpt then
        local isSelf   = (player:getID() == target:getID())
        local duration = 30 + player:getMod(xi.mod.WARCRY_DURATION)

        if target:hasStatusEffect(xi.effect.WARCRY) then
            target:delStatusEffectSilent(xi.effect.WARCRY)
        end

        -- Party -8% DMG routed through the capped shared ward slot (EFF_OX_SUP_WARD)
        if xi.overlords and xi.overlords.slots and xi.overlords.slots.applyPartyWard then
            xi.overlords.slots.applyPartyWard(player, target, -800, 0, duration, xi.effect.WARCRY)
        end

        local targetId = target:getID()
        pendingWarcryMods[targetId] = isSelf and { { xi.mod.ENMITY, 20 } } or nil
        target:addStatusEffect(xi.effect.WARCRY, { power = 0, duration = duration, origin = player, subPower = player:getMerit(xi.merit.SAVAGERY) })
        pendingWarcryMods[targetId] = nil

        if isSelf then
            tryAdrenalineSurge(player)
        else
            ability:setMsg(xi.msg.basic.JA_ATK_ENHANCED)
        end

        return xi.effect.WARCRY
    end

    -- Berserker Warcry
    local merit    = player:getMerit(xi.merit.SAVAGERY)
    local warLevel = utils.getActiveJobLevel(player, xi.job.WAR)
    local power    = (math.floor((warLevel / 4) + 4.75) / 256) * 100 + 8
    local duration = 30 + player:getMod(xi.mod.WARCRY_DURATION)

    target:addStatusEffect(xi.effect.WARCRY, { power = power, duration = duration, origin = player, subPower = merit })

    if player:getID() ~= target:getID() then
        ability:setMsg(xi.msg.basic.JA_ATK_ENHANCED)
    end

    return xi.effect.WARCRY
end)

m:addOverride('xi.effects.warcry.onEffectGain', function(target, effect)
    super(target, effect)

    if target == nil or effect == nil then
        return
    end

    local extra = pendingWarcryMods[target:getID()]
    if extra ~= nil then
        for _, pair in ipairs(extra) do
            effect:addMod(pair[1], pair[2])
        end
    end
end)

m:addOverride('xi.job_utils.warrior.useMightyStrikes', function(player, target, ability)
    if not isWarriorSpec(player, SPARTAN_KEY) then
        return super(player, target, ability)
    end

    player:addStatusEffect(xi.effect.MIGHTY_STRIKES, { power = 1, duration = 60, origin = player, subPower = 2 })
    player:setLocalVar(GRIT_VAR, MAX_GRIT)

    return xi.effect.MIGHTY_STRIKES
end)

m:addOverride('xi.effects.mighty_strikes.onEffectGain', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 2 then
        target:addMod(xi.mod.DMG, -2500)
        target:addMod(xi.mod.ENMITY, 50)
    end
end)

m:addOverride('xi.effects.mighty_strikes.onEffectLose', function(target, effect)
    super(target, effect)

    if effect ~= nil and effect:getSubPower() == 2 then
        target:delMod(xi.mod.DMG, -2500)
        target:delMod(xi.mod.ENMITY, 50)
    end
end)

-----------------------------------
-- Spartan Phalanx Block Mastery + Grit on Block
-----------------------------------
m:addOverride('xi.combat.physical.calculateBlockRate', function(defender, attacker)
    local rate = super(defender, attacker)

    if isWarriorSpec(defender, SPARTAN_KEY) and hasPolearmMain(defender) and hasSize1Buckler(defender) then
        rate = utils.clamp((tonumber(rate) or 0) + 10, 5, 100)
    end

    return rate
end)

m:addOverride('xi.combat.physical.isBlocked', function(defender, attacker)
    local blocked = super(defender, attacker)

    if blocked and isWarriorSpec(defender, SPARTAN_KEY) and isPhalanxSetup(defender) then
        gritBlockStamp[defender:getID()] = os.clock()
        if defender:getLocalVar(BRACE_VAR) == 0 then
            addGrit(defender, 1)
        end
    end

    return blocked
end)


-----------------------------------
-- Commander Custom Active Job Abilities (Lv10+, Scaling Lv10/30/50/70+)
-----------------------------------
local BREACH_SC_PCT    = { 12, 18, 24, 30 }
local BREACH_MB_PCT    = { 8, 12, 16, 20 }
local BREACH_CRIT_PCT  = { 8, 12, 16, 20 }
local BREACH_CLOSER_TP = { 100, 150, 200, 250 }

local function getCommanderLevel(player)
    if player ~= nil and player.getMainLvl then
        return player:getMainLvl() or 10
    end
    return 10
end

local function listContainsEntityId(list, targetId)
    if type(list) ~= 'table' or targetId == nil then
        return false
    end

    for _, member in ipairs(list) do
        if member ~= nil and member.getID and member:getID() == targetId then
            return true
        end
    end

    return false
end

local function isCommanderAlly(origin, originId, actor)
    if actor == nil then
        return false
    end

    local checkActor = actor
    if actor.getMaster and actor:getMaster() ~= nil then
        checkActor = actor:getMaster()
    end

    local resolvedOriginId = originId
    if origin ~= nil and origin.getID then
        resolvedOriginId = origin:getID()
    end

    local actorId = checkActor.getID and checkActor:getID() or nil
    if resolvedOriginId ~= nil and actorId == resolvedOriginId then
        return true
    end

    if origin ~= nil then
        if origin.isInPartyWith and origin:isInPartyWith(checkActor) then
            return true
        end
        if origin.getAlliance and listContainsEntityId(origin:getAlliance(), actorId) then
            return true
        end
        if origin.getPartyWithTrusts and listContainsEntityId(origin:getPartyWithTrusts(), actorId) then
            return true
        end
        if origin.getParty and listContainsEntityId(origin:getParty(), actorId) then
            return true
        end
    end

    if resolvedOriginId ~= nil then
        if checkActor.getAlliance and listContainsEntityId(checkActor:getAlliance(), resolvedOriginId) then
            return true
        end
        if checkActor.getPartyWithTrusts and listContainsEntityId(checkActor:getPartyWithTrusts(), resolvedOriginId) then
            return true
        end
        if checkActor.getParty and listContainsEntityId(checkActor:getParty(), resolvedOriginId) then
            return true
        end
    end

    return false
end

local function applyPendingCommanderEffectMods(target, effect)
    if target == nil or effect == nil then
        return
    end

    local mods = pendingCommanderMods[target:getID()]
    if mods ~= nil then
        for _, pair in ipairs(mods) do
            effect:addMod(pair[1], pair[2])
        end
    end
end

local function applyCommanderTimedEffect(target, effectId, power, duration, origin, subPower, iconId, mods)
    if target == nil then
        return
    end

    if target:hasStatusEffect(effectId) then
        target:delStatusEffectSilent(effectId)
    end

    local targetId = target:getID()
    pendingCommanderMods[targetId] = mods
    target:addStatusEffect(effectId,
    {
        power    = power,
        duration = duration,
        origin   = origin,
        subPower = subPower or 0,
        icon     = iconId,
    })
    pendingCommanderMods[targetId] = nil
end

local function getActiveBreachInfo(target, actor)
    if target == nil or actor == nil or not target.getStatusEffect then
        return nil
    end

    local effect = target:getStatusEffect(COMMANDER_BREACH_EFFECT_ID)
    if effect == nil then
        return nil
    end

    local origin = effect.getOrigin and effect:getOrigin() or nil
    local originId = effect.getSubPower and effect:getSubPower() or 0
    if not isCommanderAlly(origin, originId, actor) then
        return nil
    end

    local tier = utils.clamp(effect:getPower() or 1, 1, 4)
    return
    {
        tier     = tier,
        scPct    = BREACH_SC_PCT[tier],
        mbPct    = BREACH_MB_PCT[tier],
        closerTp = BREACH_CLOSER_TP[tier],
    }
end

-- 1) Tactical Breach (396): 20s CD, 10s Enemy Mark
m:addOverride('xi.actions.abilities.tactical_breach.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, COMMANDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if target == nil or target:getID() == player:getID() then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.tactical_breach.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local critPct, tier = scaleCommanderTier(lvl, BREACH_CRIT_PCT[1], BREACH_CRIT_PCT[2], BREACH_CRIT_PCT[3], BREACH_CRIT_PCT[4])
    local iconId = xi.effect and xi.effect.CONSPIRATOR or COMMANDER_BREACH_EFFECT_ID

    applyCommanderTimedEffect(
        target,
        COMMANDER_BREACH_EFFECT_ID,
        tier,
        10,
        player,
        player:getID(),
        iconId,
        {
            { xi.mod.CRIT_DEF_BONUS, -critPct },
        }
    )

    return COMMANDER_BREACH_EFFECT_ID
end)

m:addOverride('xi.effects.commander_breach.onEffectGain', function(target, effect)
    applyPendingCommanderEffectMods(target, effect)
end)

m:addOverride('xi.effects.commander_breach.onEffectLose', function(target, effect)
end)

m:addOverride('xi.combat.skillchain.calculateSkillchainDamage', function(actor, target, baseDamage)
    local breach = getActiveBreachInfo(target, actor)
    if breach == nil then
        return super(actor, target, baseDamage)
    end

    actor:addMod(xi.mod.SKILLCHAINBONUS, breach.scPct)
    local ok, result = pcall(super, actor, target, baseDamage)
    actor:delMod(xi.mod.SKILLCHAINBONUS, breach.scPct)

    if not ok then
        error(result)
    end

    if (tonumber(result) or 0) > 0 and actor.addTP then
        actor:addTP(breach.closerTp)
    end

    return result
end)

m:addOverride('xi.spells.damage.calculateIfMagicBurstBonus', function(caster, target, spellId, skillType, spellElement)
    local bonus = super(caster, target, spellId, skillType, spellElement)
    local breach = getActiveBreachInfo(target, caster)
    if breach ~= nil then
        bonus = bonus + (breach.mbPct / 100)
    end
    return bonus
end)

-- 2) Formation: Bulwark (397): 25s CD, 15s Party 10y Mitigation
m:addOverride('xi.actions.abilities.formation_bulwark.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, COMMANDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.formation_bulwark.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local phalanxVal = 8 + math.floor(lvl * 0.45)
    local mdefVal, tier = scaleCommanderTier(lvl, 5, 10, 15, 20)
    local statusResVal = scaleCommanderTier(lvl, 12, 18, 25, 35)
    local kbRedVal = scaleCommanderTier(lvl, 30, 50, 75, 100)
    local iconId = xi.effect and xi.effect.PHALANX or COMMANDER_BULWARK_EFFECT_ID

    applyCommanderTimedEffect(
        target,
        COMMANDER_BULWARK_EFFECT_ID,
        phalanxVal,
        15,
        player,
        tier,
        iconId,
        {
            { xi.mod.PHALANX,             phalanxVal },
            { xi.mod.MDEF,                mdefVal },
            { xi.mod.STATUSRES,           statusResVal },
            { xi.mod.KNOCKBACK_REDUCTION, kbRedVal },
        }
    )

    return COMMANDER_BULWARK_EFFECT_ID
end)

m:addOverride('xi.effects.commander_bulwark.onEffectGain', function(target, effect)
    applyPendingCommanderEffectMods(target, effect)
end)

m:addOverride('xi.effects.commander_bulwark.onEffectLose', function(target, effect)
end)

-- 3) Battle Cadence (398): 20s CD, 12s Party 10y Subtle Blow / Conserve TP / Cure Rcvd
m:addOverride('xi.actions.abilities.battle_cadence.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, COMMANDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.battle_cadence.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local subtleBlow, tier = scaleCommanderTier(lvl, 12, 18, 24, 30)
    local subtleBlowII = scaleCommanderTier(lvl, 0, 0, 5, 10)
    local conserveTp = scaleCommanderTier(lvl, 10, 15, 22, 30)
    local cureRcvd = scaleCommanderTier(lvl, 8, 12, 16, 20)
    local iconId = xi.effect and xi.effect.HASTE or COMMANDER_CADENCE_EFFECT_ID

    local mods =
    {
        { xi.mod.SUBTLE_BLOW,       subtleBlow },
        { xi.mod.CONSERVE_TP,       conserveTp },
        { xi.mod.CURE_POTENCY_RCVD, cureRcvd },
    }
    if subtleBlowII > 0 and xi.mod.SUBTLE_BLOW_II then
        table.insert(mods, { xi.mod.SUBTLE_BLOW_II, subtleBlowII })
    end

    applyCommanderTimedEffect(
        target,
        COMMANDER_CADENCE_EFFECT_ID,
        subtleBlow,
        12,
        player,
        tier,
        iconId,
        mods
    )

    return COMMANDER_CADENCE_EFFECT_ID
end)

m:addOverride('xi.effects.commander_cadence.onEffectGain', function(target, effect)
    applyPendingCommanderEffectMods(target, effect)
end)

m:addOverride('xi.effects.commander_cadence.onEffectLose', function(target, effect)
end)

-- 4) Rallying Horn (399): 45s CD, Instant Cleanse/Heal/TP + 12s Move Speed
m:addOverride('xi.actions.abilities.rallying_horn.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, COMMANDER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.rallying_horn.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local healPct, tier = scaleCommanderTier(lvl, 5, 7, 9, 12)
    local tpPulse = scaleCommanderTier(lvl, 75, 125, 175, 250)
    local moveSpeed = scaleCommanderTier(lvl, 8, 10, 12, 15)
    local iconId = xi.effect and xi.effect.QUICKENING or COMMANDER_REGROUP_EFFECT_ID

    local cleanseList =
    {
        xi.effect.SLOW,
        xi.effect.BIND,
    }
    if tier >= 2 then
        table.insert(cleanseList, xi.effect.WEIGHT)
        table.insert(cleanseList, xi.effect.PARALYSIS)
    end
    if tier >= 3 then
        table.insert(cleanseList, xi.effect.DEFENSE_DOWN)
        table.insert(cleanseList, xi.effect.MAGIC_DEF_DOWN)
    end
    if tier >= 4 then
        table.insert(cleanseList, xi.effect.ATTACK_DOWN)
        table.insert(cleanseList, xi.effect.ACCURACY_DOWN)
    end

    for _, debuffId in ipairs(cleanseList) do
        if debuffId ~= nil and target:hasStatusEffect(debuffId) then
            target:delStatusEffect(debuffId)
        end
    end

    local maxHp = target.getMaxHP and target:getMaxHP() or 0
    local healAmount = math.max(8, math.floor(maxHp * healPct / 100))
    if maxHp > 0 and target.addHP then
        local healed = target:addHP(healAmount)
        if
            (healed > 0 or target:getID() ~= player:getID()) and
            player.messagePublic and
            xi.msg and
            xi.msg.basic and
            xi.msg.basic.RECOVERS_HP
        then
            player:messagePublic(xi.msg.basic.RECOVERS_HP, target, 0, healed)
        end
    end

    if target.addTP then
        target:addTP(tpPulse)
    end

    applyCommanderTimedEffect(
        target,
        COMMANDER_REGROUP_EFFECT_ID,
        moveSpeed,
        12,
        player,
        tier,
        iconId,
        {
            { xi.mod.MOVE_SPEED_STACKABLE, moveSpeed },
        }
    )

    return COMMANDER_REGROUP_EFFECT_ID
end)

m:addOverride('xi.effects.commander_regroup.onEffectGain', function(target, effect)
    applyPendingCommanderEffectMods(target, effect)
end)

m:addOverride('xi.effects.commander_regroup.onEffectLose', function(target, effect)
end)

-----------------------------------
-- Berserker Custom Active Job Abilities (Lv10+, Scaling Lv10/30/50/70+)
-----------------------------------
-- 1) Bloodlust Surge (400): 25s CD, 10s Self (+Attack%, +Double Attack Damage, -10% DEF%)
m:addOverride('xi.actions.abilities.bloodlust_surge.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, BERSERKER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.bloodlust_surge.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local attp, tier = scaleCommanderTier(lvl, 10, 14, 18, 24)
    local daDmg = scaleCommanderTier(lvl, 15, 22, 30, 40)
    local iconId = xi.effect and xi.effect.BERSERK or BERSERKER_SURGE_EFFECT_ID

    applyCommanderTimedEffect(
        target,
        BERSERKER_SURGE_EFFECT_ID,
        attp,
        10,
        player,
        tier,
        iconId,
        {
            { xi.mod.ATTP,              attp },
            { xi.mod.DOUBLE_ATTACK_DMG, daDmg },
            { xi.mod.DEFP,              -10 },
        }
    )

    return BERSERKER_SURGE_EFFECT_ID
end)

m:addOverride('xi.effects.berserker_surge.onEffectGain', function(target, effect)
    applyPendingCommanderEffectMods(target, effect)
end)

m:addOverride('xi.effects.berserker_surge.onEffectLose', function(target, effect)
end)

-- 2) Savage Cleave (401): 20s CD, Enemy 4y, Overstraining physical strike (0 TP gained, self-recoil HP)
m:addOverride('xi.actions.abilities.savage_cleave.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, BERSERKER_KEY) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if target == nil or target:getID() == player:getID() then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.savage_cleave.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local mult = scaleCommanderTier(lvl, 1.4, 1.8, 2.2, 2.6)
    local recoilPct = scaleCommanderTier(lvl, 6, 8, 10, 12)

    local weaponDmg = player.getWeaponDmg and (player:getWeaponDmg() or 0) or 0
    local strStat = player.getStat and xi.mod and xi.mod.STR and (player:getStat(xi.mod.STR) or 0) or 0
    local damage = math.max(15, math.floor(weaponDmg * mult + strStat * 0.6 + lvl * 1.5))
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        damage = xi.customBossServer.scaleDamageByLevelGap(player, target, damage)
    end

    if target ~= nil and target.takeDamage and xi.attackType and xi.damageType then
        target:takeDamage(damage, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING or xi.damageType.BLUNT)
    end

    -- Overstraining recoil: never kills the Berserker (leaves at least 1 HP)
    local curHp = player.getHP and (player:getHP() or 0) or 0
    local maxHp = player.getMaxHP and (player:getMaxHP() or 0) or 0
    if curHp > 1 and maxHp > 0 and player.takeDamage then
        local recoil = math.min(curHp - 1, math.max(1, math.floor(maxHp * recoilPct / 100)))
        if recoil > 0 then
            player:takeDamage(recoil, player, xi.attackType.NONE, xi.damageType.NONE)
        end
    end

    return damage
end)

-----------------------------------
-- Spartan Custom Active Job Abilities (reuse IDs 402 / 403, Lv10+, scaling Lv10/30/50/70+)
-----------------------------------
-- 1) Impaling Thrust (402): 20s CD, Enemy 8y, Polearm
m:addOverride('xi.actions.abilities.impaling_thrust.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, SPARTAN_KEY) or not hasPolearmMain(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if target == nil or target:getID() == player:getID() then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.impaling_thrust.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local weaponDmg = player.getWeaponDmg and (player:getWeaponDmg() or 0) or 0
    local vitStat = player.getStat and xi.mod and xi.mod.VIT and (player:getStat(xi.mod.VIT) or 0) or 0
    local damage = math.max(12, math.floor(weaponDmg * 1.1 + vitStat * 0.5 + lvl * 1.0))
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        damage = xi.customBossServer.scaleDamageByLevelGap(player, target, damage)
    end

    local casting = isTargetCasting(target)

    if target ~= nil and target.takeDamage and xi.attackType and xi.damageType then
        target:takeDamage(damage, player, xi.attackType.PHYSICAL, xi.damageType.PIERCING or xi.damageType.BLUNT)
    end

    if target ~= nil and target.addEnmity then
        target:addEnmity(player, 150, 450)
    end

    staggerTarget(target, player, 2, casting and 5 or 0)
    applyMaim(target, player, 15)

    local boosted = player:hasStatusEffect(xi.effect.DEFENDER) or player:hasStatusEffect(xi.effect.MIGHTY_STRIKES)
    addGrit(player, boosted and 4 or 2)

    return damage
end)

-- 2) Phalanx Ward (403): 35s CD, 2 Grit, Self 12s, status effect 820
m:addOverride('xi.actions.abilities.phalanx_ward.onAbilityCheck', function(player, target, ability)
    if not isWarriorSpec(player, SPARTAN_KEY) or not hasPolearmMain(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    if getGrit(player) < 2 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    return 0, 0
end)

m:addOverride('xi.actions.abilities.phalanx_ward.onUseAbility', function(player, target, ability)
    local lvl = getCommanderLevel(player)
    local blockBonus, tier = scaleCommanderTier(lvl, 15, 22, 30, 38)
    local dtBps = scaleCommanderTier(lvl, -1000, -1200, -1500, -1800)
    local enmityVal = scaleCommanderTier(lvl, 25, 35, 45, 55)
    local iconId = xi.effect and xi.effect.DEFENDER or SPARTAN_WARD_EFFECT_ID

    player:setLocalVar(GRIT_VAR, math.max(0, getGrit(player) - 2))

    local mods =
    {
        { xi.mod.PALISADE_BLOCK_BONUS, blockBonus },
        { xi.mod.DMG,                  dtBps },
        { xi.mod.ENMITY,               enmityVal },
    }
    if xi.mod.KNOCKBACK_REDUCTION then
        table.insert(mods, { xi.mod.KNOCKBACK_REDUCTION, 100 })
    end

    applyCommanderTimedEffect(target, SPARTAN_WARD_EFFECT_ID, blockBonus, 12, player, tier, iconId, mods)
    armBrace(player, 2)

    return SPARTAN_WARD_EFFECT_ID
end)

m:addOverride('xi.effects.gladiator_ward.onEffectGain', function(target, effect)
    applyPendingCommanderEffectMods(target, effect)
end)

m:addOverride('xi.effects.gladiator_ward.onEffectLose', function(target, effect)
end)

-- Defender: 15s CD for Spartan (Polearm)
m:addOverride('xi.actions.abilities.defender.onAbilityCheck', function(player, target, ability)
    if isWarriorSpec(player, SPARTAN_KEY) and hasPolearmMain(player) and ability ~= nil and ability.setRecast then
        ability:setRecast(15)
    end

    return super(player, target, ability)
end)

-- Provoke: Adrenaline Surge below 50% HP
m:addOverride('xi.actions.abilities.provoke.onUseAbility', function(player, target, ability)
    tryAdrenalineSurge(player)
    return super(player, target, ability)
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if isWarriorSpec(player, SPARTAN_KEY) then
        attachSpartanListeners(player)
    end
end)

return m
