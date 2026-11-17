-----------------------------------
-- OverlordsXI Bespoke WS Tree Helpers
-- Compact builders for 4-tier (56-pt) spec-filtered WS trees.
-- Supports all 7 spec categories:
--   berserker, blackbelt, commander, tank, spellblade, healer, chiweaver
-- Preserves each WS's unique Col 1 + T1 identity across specs while tailoring
-- Col 2 (spec identity) and Col 3 (archetype/element/aftermath/debuff).
-----------------------------------
local catalog = xi.overlords.wsCatalog
local talents = xi.overlords.wsTalents
local makeFtp = talents.makeCustomFtpNode
local makeNode = talents.makeSpecNode

local H = {}

local function pick(tbl, r)
    return tbl[r] or tbl[#tbl]
end

local function copyTable(src)
    if type(src) ~= 'table' then
        return src
    end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = copyTable(v)
    end
    return dst
end

function H.node(tier, col, key, name, maxRank, zeroDesc, rankDesc, effect, req)
    return makeNode(
    {
        tier     = tier,
        col      = col,
        key      = key,
        name     = name,
        maxRank  = maxRank,
        zeroDesc = zeroDesc,
        rankDesc = rankDesc,
        effect   = effect,
        requires = req,
    })
end

function H.ftp(curve, opts)
    opts = opts or {}
    return makeFtp(
    {
        key        = opts.key or 'ftp',
        name       = opts.name or 'TP Scaling',
        ftpCurve   = curve,
        zeroDesc   = opts.zeroDesc,
        zeroSuffix = opts.zeroSuffix,
        suffixFn   = opts.suffixFn,
        effect     = opts.effect,
    })
end

-----------------------------------
-- WS Inspection & Element Theme Metadata
-----------------------------------
local ELEM_THEMES =
{
    FIRE =
    {
        adj      = 'Blazing',
        debuff   = xi.effect.BURN,
        debLabel = 'Burn',
        debPwr   = { 6, 10, 14, 18, 22 },
        enBuff   = xi.effect.ENFIRE,
        enLabel  = 'Enfire',
    },
    ICE =
    {
        adj      = 'Glacial',
        debuff   = xi.effect.MAGIC_EVASION_DOWN,
        debLabel = 'MEVA-',
        debPwr   = { 8, 16, 24, 32, 40 },
        enBuff   = xi.effect.ENBLIZZARD,
        enLabel  = 'Enblizzard',
    },
    WIND =
    {
        adj      = 'Tempest',
        debuff   = xi.effect.EVASION_DOWN,
        debLabel = 'EVA-',
        debPwr   = { 8, 16, 24, 32, 40 },
        enBuff   = xi.effect.ENAERO,
        enLabel  = 'Enaero',
    },
    EARTH =
    {
        adj      = 'Seismic',
        debuff   = xi.effect.SLOW,
        debLabel = 'Slow',
        debPwr   = { 600, 1000, 1400, 1800, 2200 },
        debDisp  = function(r) return string.format('Slow %d%%', 4 + r * 4) end,
        enBuff   = xi.effect.ENSTONE,
        enLabel  = 'Enstone',
    },
    THUNDER =
    {
        adj      = 'Storm',
        debuff   = xi.effect.MAGIC_ACC_DOWN,
        debLabel = 'MACC-',
        debPwr   = { 8, 16, 24, 32, 40 },
        enBuff   = xi.effect.ENTHUNDER,
        enLabel  = 'Enthunder',
    },
    WATER =
    {
        adj      = 'Tidal',
        debuff   = xi.effect.ATTACK_DOWN,
        debLabel = 'Atk-',
        debPwr   = { 4, 8, 12, 16, 20 },
        debDisp  = function(r) return string.format('Atk -%d%%', r * 4) end,
        enBuff   = xi.effect.ENWATER,
        enLabel  = 'Enwater',
    },
    LIGHT =
    {
        adj      = 'Luminous',
        debuff   = xi.effect.ACCURACY_DOWN,
        debLabel = 'Acc-',
        debPwr   = { 8, 16, 24, 32, 40 },
        enBuff   = xi.effect.ENLIGHT,
        enLabel  = 'Enlight',
    },
    DARK =
    {
        adj      = 'Umbral',
        debuff   = xi.effect.PLAGUE,
        debLabel = 'Plague',
        debPwr   = { 2, 4, 6, 8, 10 },
        debDisp  = function(r) return string.format('Plague -%d TP/t', r * 2) end,
        enBuff   = xi.effect.ENDARK,
        enLabel  = 'Endark',
    },
}

local function isMagicOrUtilityWS(wsId, archetype)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    if ws ~= nil then
        if ws.wsType == 'magic' or ws.wsType == 'utility' then
            return true, ws.wsType
        end
    end
    if wsId == 39 or wsId == 45 then
        return true, 'utility'
    end
    if archetype == 'magic' then
        return true, 'magic'
    end
    return false, (ws and ws.wsType) or 'physical'
end

local function isMagicDamageWS(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    return ws ~= nil and ws.wsType == 'magic'
end

local function getDefaultElement(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    if ws and ws.elementName then
        return string.upper(ws.elementName), ws.elementName
    end
    local skill = ws and ws.skill or 0
    if skill == xi.skill.SCYTHE then
        return 'DARK', 'Dark'
    elseif skill == xi.skill.CLUB or skill == xi.skill.HAND_TO_HAND then
        return 'LIGHT', 'Light'
    elseif skill == xi.skill.GREAT_SWORD then
        return 'ICE', 'Ice'
    elseif skill == xi.skill.POLEARM or skill == xi.skill.AXE then
        return 'THUNDER', 'Thunder'
    elseif skill == xi.skill.DAGGER or skill == xi.skill.KATANA then
        return 'WIND', 'Wind'
    elseif skill == xi.skill.SWORD or skill == xi.skill.GREAT_KATANA then
        return 'FIRE', 'Fire'
    elseif skill == xi.skill.GREAT_AXE then
        return 'EARTH', 'Earth'
    end
    return 'LIGHT', 'Light'
end

local function getElementTheme(wsId)
    local eleUpper, eleName = getDefaultElement(wsId)
    return eleUpper, eleName, ELEM_THEMES[eleUpper] or ELEM_THEMES.LIGHT
end

-----------------------------------
-- Strict Sanitizers & Defensive / ChiWeaver Role Adapters
-----------------------------------
local function rebuildEffectDescription(nodeCopy, wsKind)
    local ce = nodeCopy.effect
    if type(ce) ~= 'table' then
        return
    end
    local mr = nodeCopy.maxRank or 5
    local isUtil = (wsKind == 'utility')
    nodeCopy.describe = function(r)
        if r <= 0 then
            local hint = {}
            if ce.hits then table.insert(hint, string.format('1->%d Hits', pick(ce.hits, mr))) end
            if ce.wsd then table.insert(hint, isUtil and '+Potency' or '+WSD') end
            if ce.potencyPct then table.insert(hint, '+Potency') end
            if ce.matt and not isUtil then table.insert(hint, '+MAB') end
            if ce.macc then table.insert(hint, '+MACC') end
            if ce.atkPct then table.insert(hint, '+Atk') end
            if ce.acc or ce.racc then table.insert(hint, '+Acc') end
            if ce.defIgnore then table.insert(hint, 'DEF Ign') end
            if ce.enmity then
                local eMax = pick(ce.enmity, mr)
                table.insert(hint, eMax < 0 and '-Enmity' or '+Enmity')
            end
            if ce.subtleBlow then table.insert(hint, '+Subtle Blow') end
            if ce.tpBonus then table.insert(hint, '+TP Bonus') end
            if ce.partyTp then table.insert(hint, '+Party TP') end
            if ce.ftpAdd then table.insert(hint, '+fTP') end
            if ce.scBonus then table.insert(hint, '+SC Dmg') end
            if ce.dispel then table.insert(hint, 'Dispel') end
            if ce.tpDrain then table.insert(hint, 'TP Drain') end
            if ce.hpDrain then table.insert(hint, 'HP Drain') end
            if ce.selfHeal then table.insert(hint, 'Self Heal') end
            if ce.elemFollow then table.insert(hint, (ce.elemFollow.ele or 'Elem') .. ' Follow-up') end
            if ce.partyHealPct then table.insert(hint, 'Party Heal') end
            if ce.selfMaxHpHealPct then table.insert(hint, 'Self Heal') end
            if ce.eosHeal then table.insert(hint, 'Pet Heal') end
            if ce.nextWs then table.insert(hint, 'NextWS') end
            if type(ce.statusBuffs) == 'table' then
                for _, sb in ipairs(ce.statusBuffs) do
                    if sb.effect == xi.effect.REGEN then table.insert(hint, 'Regen')
                    elseif sb.effect == xi.effect.STONESKIN then table.insert(hint, 'Stoneskin')
                    elseif sb.effect == xi.effect.PHALANX then table.insert(hint, 'Phalanx')
                    elseif sb.effect == xi.effect.REGAIN then table.insert(hint, 'Regain')
                    end
                end
            end
            if type(ce.partyBuffs) == 'table' then
                for _, pb in ipairs(ce.partyBuffs) do
                    if pb.effect == xi.effect.REGEN then table.insert(hint, 'Party Regen')
                    elseif pb.effect == xi.effect.PHALANX then table.insert(hint, 'Party Phalanx')
                    end
                end
            end
            if #hint == 0 then
                return nodeCopy.name or 'Enhanced Trait'
            end
            return table.concat(hint, ', ')
        end
        local parts = {}
        if ce.hits then table.insert(parts, string.format('%dh', pick(ce.hits, r))) end
        if ce.wsd then table.insert(parts, string.format('+%d%% %s', pick(ce.wsd, r), isUtil and 'Potency' or 'WSD')) end
        if ce.potencyPct then table.insert(parts, string.format('+%d%% Potency', pick(ce.potencyPct, r))) end
        if ce.atkPct then table.insert(parts, string.format('+%d%% Atk', pick(ce.atkPct, r))) end
        if ce.acc then table.insert(parts, string.format('+%d Acc', pick(ce.acc, r))) end
        if ce.racc then table.insert(parts, string.format('+%d RAcc', pick(ce.racc, r))) end
        if ce.defIgnore then table.insert(parts, string.format('%d%% DEF Ign', math.floor(pick(ce.defIgnore, r) * 100 + 0.5))) end
        if ce.matt and not isUtil then table.insert(parts, string.format('+%d MAB', pick(ce.matt, r))) end
        if ce.macc then table.insert(parts, string.format('+%d MACC', pick(ce.macc, r))) end
        if ce.enmity then
            local ev = pick(ce.enmity, r)
            table.insert(parts, ev < 0 and string.format('%d Enmity', ev) or string.format('+%d Enmity', ev))
        end
        if ce.subtleBlow then table.insert(parts, string.format('+%d SB', pick(ce.subtleBlow, r))) end
        if ce.tpBonus then table.insert(parts, string.format('+%d TP', pick(ce.tpBonus, r))) end
        if ce.partyTp then table.insert(parts, string.format('Party +%d TP', pick(ce.partyTp, r))) end
        if ce.ftpAdd then table.insert(parts, string.format('+%.2f fTP', pick(ce.ftpAdd, r))) end
        if ce.scBonus then table.insert(parts, string.format('+%d%% SC', pick(ce.scBonus, r))) end
        if ce.dispel then table.insert(parts, string.format('Dispel %d', pick(ce.dispel, r))) end
        if ce.tpDrain then table.insert(parts, string.format('-%d Tgt TP', pick(ce.tpDrain, r))) end
        if ce.hpDrain then table.insert(parts, string.format('%d%% HP Drain', pick(ce.hpDrain, r))) end
        if ce.selfHeal then table.insert(parts, string.format('Heal %d%%', pick(ce.selfHeal, r))) end
        if ce.elemFollow then
            table.insert(parts, string.format('%s +%d%%', ce.elemFollow.ele or 'Elem', pick(ce.elemFollow.pct, r)))
        end
        if ce.partyHealPct then table.insert(parts, string.format('Party Heal %d%%', pick(ce.partyHealPct, r))) end
        if ce.selfMaxHpHealPct then table.insert(parts, string.format('Heal %d%% HP', pick(ce.selfMaxHpHealPct, r))) end
        if ce.eosHeal then table.insert(parts, string.format('Pet Heal %d%%', pick(ce.eosHeal, r))) end
        if ce.nextWs then
            if ce.nextWs.wsd then table.insert(parts, string.format('NextWS +%d%% WSD', pick(ce.nextWs.wsd, r))) end
            if ce.nextWs.tp then table.insert(parts, string.format('NextWS +%d TP', pick(ce.nextWs.tp, r))) end
        end
        if type(ce.statusBuffs) == 'table' then
            for _, sb in ipairs(ce.statusBuffs) do
                if sb.effect == xi.effect.REGEN then table.insert(parts, string.format('Regen +%d/t', pick(sb.power, r)))
                elseif sb.effect == xi.effect.STONESKIN then table.insert(parts, string.format('Skin %d', pick(sb.power, r)))
                elseif sb.effect == xi.effect.PHALANX then table.insert(parts, string.format('Phalanx %d', pick(sb.power, r)))
                elseif sb.effect == xi.effect.REGAIN then table.insert(parts, string.format('Regain +%d', pick(sb.power, r)))
                end
            end
        end
        if type(ce.partyBuffs) == 'table' then
            for _, pb in ipairs(ce.partyBuffs) do
                if pb.effect == xi.effect.REGEN then table.insert(parts, string.format('Party Regen +%d/t', pick(pb.power, r)))
                elseif pb.effect == xi.effect.PHALANX then table.insert(parts, string.format('Party Phalanx %d', pick(pb.power, r)))
                end
            end
        end
        if #parts == 0 then
            return string.format('Rank %d/%d', r, mr)
        end
        return table.concat(parts, ', ')
    end
end

local function sanitizeNodeForNonPhysical(n, wsId, wsKind)
    if n == nil or type(n.effect) ~= 'table' then
        return n
    end
    local eff = n.effect
    local hadPhys = eff.atkPct or eff.acc or eff.racc or eff.crit or eff.critCurve
        or eff.critDmg or eff.defIgnore or eff.hits or eff.bonusHits or eff.multiHitfTPAt
        or (eff.stance and (eff.stance.atkPct or eff.stance.crit or eff.stance.critDmg or eff.stance.defIgnore))
    if not hadPhys then
        return n
    end

    local nodeCopy = copyTable(n)
    local ce = nodeCopy.effect
    local mr = nodeCopy.maxRank or 5

    local function seq(step)
        local t = {}
        for i = 1, mr do
            t[i] = i * step
        end
        return t
    end

    if ce.atkPct then
        ce.matt = ce.matt or seq(8)
        ce.atkPct = nil
    end
    if ce.acc or ce.racc then
        ce.macc = ce.macc or seq(8)
        ce.acc  = nil
        ce.racc = nil
    end
    if ce.crit or ce.critCurve or ce.critDmg then
        ce.wsd     = ce.wsd or seq(6)
        ce.tpBonus = ce.tpBonus or seq(60)
        ce.crit      = nil
        ce.critCurve = nil
        ce.critDmg   = nil
    end
    if ce.defIgnore then
        ce.macc = ce.macc or seq(9)
        ce.matt = ce.matt or seq(9)
        ce.defIgnore = nil
    end
    if ce.hits or ce.bonusHits or ce.multiHitfTPAt then
        ce.ftpAdd = ce.ftpAdd or seq(0.35)
        ce.wsd    = ce.wsd or seq(7)
        ce.hits          = nil
        ce.bonusHits     = nil
        ce.multiHitfTPAt = nil
    end
    if ce.stance then
        if ce.stance.atkPct then
            ce.stance.matt = ce.stance.matt or seq(10)
            ce.stance.atkPct = nil
        end
        if ce.stance.crit or ce.stance.critDmg or ce.stance.defIgnore then
            ce.stance.macc = ce.stance.macc or seq(10)
            ce.stance.wsd  = ce.stance.wsd or seq(8)
            ce.stance.crit      = nil
            ce.stance.critDmg   = nil
            ce.stance.defIgnore = nil
        end
    end

    rebuildEffectDescription(nodeCopy, wsKind)
    return nodeCopy
end

-- Remove ANY MP Drain / Refresh / MP-only potency from Chi Weaver nodes (Chi Weaver has 0 MP)
local function stripMpAndRefreshForChiWeaver(n, wsKind)
    if n == nil or type(n.effect) ~= 'table' then
        return n
    end
    local eff = n.effect
    local hasMp = (eff.mpDrain ~= nil) or (eff.mpToHpPct ~= nil)
    local hasRefresh = false
    for idx = 1, 2 do
        local list = (idx == 1) and eff.statusBuffs or eff.partyBuffs
        if type(list) == 'table' then
            for _, sb in ipairs(list) do
                if sb.effect == xi.effect.REFRESH then
                    hasRefresh = true
                end
            end
        end
    end
    local d0 = (type(n.describe) == 'function') and (select(2, pcall(n.describe, 0)) or '') or ''
    local hasMpPotency = (eff.potencyPct ~= nil) and type(d0) == 'string'
        and (d0:find(' MP') ~= nil or d0:match('^MP ') ~= nil)
    if not hasMp and not hasRefresh and not hasMpPotency then
        return n
    end

    local nodeCopy = copyTable(n)
    local ce = nodeCopy.effect
    local mr = nodeCopy.maxRank or 5
    local function seq(step)
        local t = {}
        for i = 1, mr do t[i] = i * step end
        return t
    end

    if ce.mpDrain or ce.mpToHpPct then
        ce.mpDrain   = nil
        ce.mpToHpPct = nil
        ce.partyTp   = ce.partyTp or seq(35)
        ce.tpBonus   = ce.tpBonus or seq(50)
    end
    if hasMpPotency then
        ce.potencyPct = nil
        ce.partyTp    = ce.partyTp or seq(35)
        ce.tpBonus    = ce.tpBonus or seq(45)
    end
    if type(ce.statusBuffs) == 'table' then
        for _, sb in ipairs(ce.statusBuffs) do
            if sb.effect == xi.effect.REFRESH then
                sb.effect = xi.effect.REGEN
                sb.power  = seq(2)
            end
        end
    end
    if type(ce.partyBuffs) == 'table' then
        for _, pb in ipairs(ce.partyBuffs) do
            if pb.effect == xi.effect.REFRESH then
                pb.effect = xi.effect.REGEN
                pb.power  = seq(2)
            end
        end
    end

    rebuildEffectDescription(nodeCopy, wsKind)
    return nodeCopy
end

-- H2H #1-#15 hardcoded high-damage keys in overlords_ws_overrides.lua
local H2H_MULTIHIT_T1_KEYS =
{
    rf_hits1 = true, spin_hits = true, af_hits1 = true, sp_hits1 = true,
    tk_hits  = true, vs_hits   = true, ss_hits  = true,
}

local H2H_DPS_SPIKE_KEYS =
{
    rf_hits1 = true, rf_hits2 = true, rf_mftp = true, rf_savage = true,
    spin_hits = true, spin_mftp = true,
    hf_atk = true,
    af_hits1 = true, af_hits2 = true, af_mftp = true,
    afury_atk = true, afury_critdmg = true,
    sp_hits1 = true, sp_hits2 = true, sp_critdmg = true,
    tk_hits = true,
    vs_hits = true, vs_critdmg = true,
    ss_hits = true, ss_mftp = true,
    crit = true,
}

-- Adapt any preserved baseNode so Tank / Healer / ChiWeaver keep WS identity
-- without exposing high-damage DPS spikes (bonusHits, multiHitfTPAt, Crit/ATK bursts)
local function adaptBaseNodeForRole(rawNode, wsId, archetype, roleCat)
    if rawNode == nil then
        return nil
    end
    local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local c = copyTable(rawNode)

    if isNonPhys then
        c = sanitizeNodeForNonPhysical(c, wsId, wsKind)
    end
    if roleCat == 'chiweaver' then
        c = stripMpAndRefreshForChiWeaver(c, wsKind)
    end

    local isDefensive = (roleCat == 'tank' or roleCat == 'healer' or roleCat == 'chiweaver')
    if not isDefensive then
        return c
    end

    local eleUpper, eleName, elem = getElementTheme(wsId)
    local mr = c.maxRank or 5
    local function seq(step)
        local t = {}
        for i = 1, mr do t[i] = i * step end
        return t
    end

    -- Replace pure DPS T1 C2 multi-hit rebuilders with the Spec's own T1 C2 node
    if c.tier == 1 and c.col == 2 then
        if H2H_MULTIHIT_T1_KEYS[c.key] then
            return nil
        end
        local eff = c.effect
        if type(eff) == 'table' and eff.hits then
            local maxH = pick(eff.hits, mr)
            if (maxH or 1) >= 3 then
                return nil
            end
        end
    end

    -- Handle H2H #1-#15 hardcoded key nodes in overlords_ws_overrides.lua
    local isH2HSpikeKey = (wsId <= 15) and (
        H2H_DPS_SPIKE_KEYS[c.key]
        or (c.key == 'capstone' and (wsId == 1 or wsId >= 5))
    )
    if isH2HSpikeKey then
        local preservedCurve = c.ftpCurve
        local baseName = c.name or 'Technique'
        local newKey = roleCat .. '_' .. tostring(c.key)
        if roleCat == 'tank' then
            local desc0, descFn, eff
            if c.tier == 1 and c.col == 1 and preservedCurve ~= nil then
                return H.ftp(preservedCurve, {
                    name = baseName,
                    zeroDesc = string.format('fTP 1.0->%.2f/%.2f/%.2f & +4..24 Enmity', preservedCurve[1], preservedCurve[2], preservedCurve[3]),
                    suffixFn = function(r) return string.format(', +%d Enmity', r * 4) end,
                    effect = { enmity = seq(4) },
                })
            elseif c.tier == 4 and c.col == 1 then
                desc0 = string.format('Stoneskin 150..300, +10..30%% WSD & %s', elem.debLabel)
                descFn = function(r)
                    local dTxt = elem.debDisp and elem.debDisp(r) or string.format('%s -%d', elem.debLabel, r * 12)
                    return string.format('Stoneskin %d, +%d%% WSD, %s', 75 + r * 75, r * 10, dTxt)
                end
                eff = {
                    wsd = seq(10),
                    statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 150, 225, 300 }, duration = 45, tier = 3 }},
                    targetDebuffs = {{ effect = elem.debuff, power = { 10, 20, 30 }, duration = 45 }},
                }
            elseif c.tier == 3 then
                desc0 = '+6..30 Enmity, +40..200 TP Bonus & +6..30% SC Dmg'
                descFn = function(r) return string.format('+%d Enmity, +%d TP, +%d%% SC', r * 6, r * 40, r * 6) end
                eff = { enmity = seq(6), tpBonus = seq(40), scBonus = seq(6) }
            else
                desc0 = '+5..25 Enmity, +6..30 Acc & +4..20% WSD'
                descFn = function(r) return string.format('+%d Enmity, +%d Acc, +%d%% WSD', r * 5, r * 6, r * 4) end
                eff = { enmity = seq(5), acc = seq(6), wsd = seq(4) }
            end
            local repl = H.node(c.tier, c.col, newKey, baseName, mr, desc0, descFn, eff, c.requires)
            if preservedCurve then repl.ftpCurve = preservedCurve end
            return repl
        else
            -- healer / chiweaver
            local desc0, descFn, eff
            if c.tier == 1 and c.col == 1 and preservedCurve ~= nil then
                return H.ftp(preservedCurve, {
                    name = baseName,
                    zeroDesc = string.format('fTP 1.0->%.2f/%.2f/%.2f & -4..24 Enmity', preservedCurve[1], preservedCurve[2], preservedCurve[3]),
                    suffixFn = function(r) return string.format(', %d Enmity', -(r * 4)) end,
                    effect = { enmity = { -4,-8,-12,-16,-20,-24 } },
                })
            elseif c.tier == 4 and c.col == 1 then
                desc0 = '+10..30% WSD, +8..24% SC Dmg & Party +60..180 TP'
                descFn = function(r) return string.format('+%d%% WSD, +%d%% SC, Party +%d TP', r * 10, r * 8, r * 60) end
                eff = { wsd = seq(10), scBonus = seq(8), partyTp = seq(60) }
            elseif c.tier == 3 then
                desc0 = 'Party +40..200 TP, +8..40 MACC & +6..30% SC Dmg'
                descFn = function(r) return string.format('Party +%d TP, +%d MACC, +%d%% SC', r * 40, r * 8, r * 6) end
                eff = { partyTp = seq(40), macc = seq(8), scBonus = seq(6) }
            else
                desc0 = '+4..20 Subtle Blow, -4..20 Enmity & +50..250 TP'
                descFn = function(r) return string.format('+%d SB, -%d Enmity, +%d TP', r * 4, r * 4, r * 50) end
                eff = { subtleBlow = seq(4), enmity = seq(-4), tpBonus = seq(50) }
            end
            local repl = H.node(c.tier, c.col, newKey, baseName, mr, desc0, descFn, eff, c.requires)
            if preservedCurve then repl.ftpCurve = preservedCurve end
            return repl
        end
    end

    -- Generic high-damage guard for declarative nodes (#16-#235)
    local ce = c.effect
    if type(ce) == 'table' then
        local changed = false
        if ce.bonusHits then
            ce.bonusHits = nil
            changed = true
            if roleCat == 'tank' then
                ce.enmity = ce.enmity or seq(5)
            else
                ce.subtleBlow = ce.subtleBlow or seq(4)
                ce.tpBonus = ce.tpBonus or seq(45)
            end
        end
        if ce.multiHitfTPAt then
            ce.multiHitfTPAt = nil
            changed = true
            ce.wsd = ce.wsd or seq(6)
            if roleCat == 'tank' then
                ce.enmity = ce.enmity or seq(5)
            else
                ce.enmity = ce.enmity or seq(-4)
            end
        end
        if ce.crit or ce.critCurve or ce.critDmg then
            ce.crit      = nil
            ce.critCurve = nil
            ce.critDmg   = nil
            changed = true
            if roleCat == 'tank' then
                ce.enmity = ce.enmity or seq(5)
                ce.acc    = ce.acc or seq(6)
            else
                ce.subtleBlow = ce.subtleBlow or seq(4)
                ce.macc       = ce.macc or seq(6)
            end
        end
        if ce.elemFollow and not isMagDmg then
            if roleCat == 'tank' or roleCat == 'healer' then
                -- Convert non-magic follow-up nukes to elemental debuff + enmity control
                ce.elemFollow = nil
                changed = true
                ce.targetDebuffs = ce.targetDebuffs or {{ effect = elem.debuff, power = elem.debPwr, duration = 45 }}
                if roleCat == 'tank' then
                    ce.enmity = ce.enmity or seq(5)
                else
                    ce.enmity = ce.enmity or seq(-4)
                end
            elseif roleCat == 'chiweaver' and eleUpper ~= 'LIGHT' then
                -- Chi Weaver channels Light Chi follow-up rather than off-element DPS nukes
                ce.elemFollow.ele = 'LIGHT'
                changed = true
            end
        end
        if ce.atkPct then
            local maxAtk = pick(ce.atkPct, mr)
            if maxAtk >= 55 then
                ce.atkPct = seq(7)
                changed = true
            end
        end
        if ce.wsd then
            local maxWsd = pick(ce.wsd, mr)
            if maxWsd >= 40 then
                ce.wsd = seq(mr == 3 and 10 or 6)
                changed = true
            end
        end
        if changed then
            rebuildEffectDescription(c, wsKind)
        end
    end

    return c
end

-----------------------------------
-- Spec Stance Lists
-----------------------------------
local TANK_STANCE_EFFECTS =
{
    xi.effect.DEFENDER,
    xi.effect.SENTINEL,
    xi.effect.RAMPART,
    xi.effect.VALLATION,
    xi.effect.VALIANCE,
    xi.effect.SWORDPLAY,
    xi.effect.BATTUTA,
    xi.effect.COUNTERSTANCE,
    xi.effect.DODGE,
    xi.effect.BLOOD_RAGE,
}

local SPELLBLADE_STANCE_EFFECTS =
{
    xi.effect.SWORDPLAY,
    xi.effect.VALLATION,
    xi.effect.VALIANCE,
    xi.effect.IGNIS,
    xi.effect.GELUS,
    xi.effect.FLABRA,
    xi.effect.TELLUS,
    xi.effect.SULPOR,
    xi.effect.UNDA,
    xi.effect.LUX,
    xi.effect.TENEBRAE,
    xi.effect.DARK_ARTS,
    xi.effect.ADDENDUM_BLACK,
}

local HEALER_STANCE_EFFECTS =
{
    xi.effect.LIGHT_ARTS,
    xi.effect.ADDENDUM_WHITE,
    xi.effect.AFFLATUS_SOLACE,
    xi.effect.VALIANCE,
    xi.effect.VALLATION,
}

local CHIWEAVER_STANCE_EFFECTS =
{
    (xi.effect and xi.effect.CHIWEAVER_HARMONY) or 830,
    (xi.effect and xi.effect.CHIWEAVER_LOTUS) or 829,
    xi.effect.BOOST,
    xi.effect.FOCUS,
    xi.effect.DODGE,
    xi.effect.FORMLESS_STRIKES,
    xi.effect.MAX_HP_BOOST,
    xi.effect.HUNDRED_FISTS,
}

local COMMANDER_STANCE_EFFECTS =
{
    xi.effect.WARCRY,
    xi.effect.BERSERK,
    xi.effect.RESTRAINT,
    xi.effect.AGGRESSOR,
    xi.effect.RETALIATION,
}

local BLACKBELT_STANCE_EFFECTS =
{
    xi.effect.BOOST,
    xi.effect.FOCUS,
    xi.effect.DODGE,
    xi.effect.FOOTWORK,
    xi.effect.IMPETUS,
    xi.effect.HUNDRED_FISTS,
    xi.effect.INNER_STRENGTH,
}

local BERSERKER_STANCE_EFFECTS =
{
    xi.effect.BERSERK,
    xi.effect.BLOOD_RAGE,
    xi.effect.LAST_RESORT,
    xi.effect.SOULEATER,
    xi.effect.IMPETUS,
    xi.effect.FOCUS,
    xi.effect.RESTRAINT,
}

local function findGridNode(nodes, tier, col)
    for _, n in ipairs(nodes or {}) do
        if n.tier == tier and n.col == col then
            return copyTable(n)
        end
    end
    return nil
end

local function rekeyNode(n, tier, col, newKey)
    local c = copyTable(n)
    c.tier = tier
    c.col  = col
    if newKey then
        c.key = newKey
    end
    c.requires = nil
    return c
end

local function makeScalingT1Col1(wsId, baseT1C1, isNonPhys)
    if baseT1C1 ~= nil then
        local c = rekeyNode(baseT1C1, 1, 1, 'ftp')
        return isNonPhys and sanitizeNodeForNonPhysical(c, wsId, 'magic') or c
    end
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local origFtp = (ws and ws.orig and ws.orig.ftp) or { 1.25, 2.00, 2.75 }
    local curve = {
        math.max(1.25, origFtp[1] or 1.25),
        math.max(1.85, origFtp[2] or 1.85),
        math.max(2.60, origFtp[3] or 2.60),
    }
    return H.ftp(curve)
end

local function makePrimaryWscNode(wsId, tier, col, key, isNonPhys, rolePrefStat)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local origWsc = (ws and ws.orig and ws.orig.wsc) or {}
    local stat = rolePrefStat
    if stat == nil then
        for _, s in ipairs({ 'str', 'dex', 'vit', 'agi', 'int', 'mnd', 'chr' }) do
            if (origWsc[s] or 0) > 0 then
                stat = s
                break
            end
        end
    end
    stat = stat or (isNonPhys and 'int' or 'str')
    local label = string.upper(stat)
    local wTbl = { 0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.85 }
    if isNonPhys then
        if isMagicDamageWS(wsId) then
            return H.node(tier, col, key, label .. ' & Arcane Focus', 7,
                string.format('%s +12..85%% WSC & +6..42 MACC', label),
                function(r) return string.format('%s +%d%% WSC, +%d MACC', label, math.floor(wTbl[r] * 100 + 0.5), r * 6) end,
                { wsc = { [stat] = wTbl }, macc = { 6, 12, 18, 24, 30, 36, 42 } })
        end
        return H.node(tier, col, key, label .. ' & Potency', 7,
            string.format('%s +12..85%% WSC & +45..315 TP Bonus', label),
            function(r) return string.format('%s +%d%% WSC, +%d TP', label, math.floor(wTbl[r] * 100 + 0.5), r * 45) end,
            { wsc = { [stat] = wTbl }, tpBonus = { 45, 90, 135, 180, 225, 270, 315 } })
    end
    return H.node(tier, col, key, label .. ' Precision', 7,
        string.format('%s +12..85%% WSC & +5..35 Acc', label),
        function(r) return string.format('%s +%d%% WSC, +%d Acc', label, math.floor(wTbl[r] * 100 + 0.5), r * 5) end,
        { wsc = { [stat] = wTbl }, acc = { 5, 10, 15, 20, 25, 30, 35 } })
end

-----------------------------------
-- WS-Differentiated Col 3 Builders (Eliminate Cookie-Cutter Trees)
-----------------------------------
local function makeTailoredCol3T2(wsId, archetype, isNonPhys, isMagDmg, roleCat)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local isRanged = (ws and ws.wsType == 'ranged')
    local accKey = isRanged and 'racc' or 'acc'
    local accLabel = isRanged and 'RAcc' or 'Acc'
    local eleUpper, eleName, elem = getElementTheme(wsId)

    if roleCat == 'tank' then
        return H.stanceNode(2, 3, 'tk_t2_c3', elem.adj .. ' Ward Stance', 5, 'Tank Stance', TANK_STANCE_EFFECTS,
            isMagDmg and { wsd = { 6,12,18,24,30 }, matt = { 8,16,24,32,40 }, zeroDesc = 'Tank Stance: +6..30% WSD & +8..40 MAB' }
                or (isNonPhys and { wsd = { 6,12,18,24,30 }, enmity = { 6,12,18,24,30 }, zeroDesc = 'Tank Stance: +6..30% WSD & +6..30 Enmity' }
                    or { wsd = { 6,12,18,24,30 }, atkPct = { 6,12,18,24,30 }, zeroDesc = 'Tank Stance: +6..30% WSD & +6..30% Atk' }))
    elseif roleCat == 'chiweaver' then
        return H.stanceNode(2, 3, 'cw_t2_c3', 'Harmony Stance', 5, 'Harmony/Lotus/Boost', CHIWEAVER_STANCE_EFFECTS,
            isMagDmg and { wsd = { 7,14,21,28,35 }, matt = { 8,16,24,32,40 }, zeroDesc = 'Chi Stance: +7..35% WSD & +8..40 MAB' }
                or { wsd = { 7,14,21,28,35 }, tpBonus = { 55,110,165,220,275 }, zeroDesc = 'Chi Stance: +7..35% WSD & +55..275 TP Bonus' })
    elseif roleCat == 'healer' then
        return H.stanceNode(2, 3, 'hl_t2_c3', 'Solace Harmony', 5, 'LightArts/Valiance', HEALER_STANCE_EFFECTS,
            isMagDmg and { wsd = { 7,14,21,28,35 }, matt = { 8,16,24,32,40 }, zeroDesc = 'LightArts/Valiance: +7..35% WSD & +8..40 MAB' }
                or { wsd = { 7,14,21,28,35 }, tpBonus = { 55,110,165,220,275 }, zeroDesc = 'LightArts/Valiance: +7..35% WSD & +55..275 TP Bonus' })
    elseif roleCat == 'spellblade' then
        return H.stanceNode(2, 3, 'sb_t2_c3', eleName .. ' Conduction', 5, 'Runes/DarkArts', SPELLBLADE_STANCE_EFFECTS,
            isMagDmg and { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'Runes/DarkArts: +9..45% WSD & +10..50 MAB' }
                or { wsd = { 9,18,27,36,45 }, tpBonus = { 60,120,180,240,300 }, zeroDesc = 'Runes/DarkArts: +9..45% WSD & +60..300 TP' })
    elseif roleCat == 'commander' then
        return H.stanceNode(2, 3, 'cm_t2_c3', 'Command Presence', 5, 'Warcry/Berserk/Restraint', COMMANDER_STANCE_EFFECTS,
            isMagDmg and { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'Command: +9..45% WSD & +10..50 MAB' }
                or (isNonPhys and { wsd = { 9,18,27,36,45 }, tpBonus = { 60,120,180,240,300 }, zeroDesc = 'Command: +9..45% WSD & +60..300 TP' }
                    or { wsd = { 9,18,27,36,45 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'Command: +9..45% WSD & +8..40% Atk' }))
    elseif roleCat == 'blackbelt' then
        return H.stanceNode(2, 3, 'bb_t2_c3', 'Martial Stance', 5, 'Boost/Focus/Footwork/HF', BLACKBELT_STANCE_EFFECTS,
            isMagDmg and { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'MNK Stance: +9..45% WSD & +10..50 MAB' }
                or (isNonPhys and { wsd = { 9,18,27,36,45 }, tpBonus = { 65,130,195,260,325 }, zeroDesc = 'MNK Stance: +9..45% WSD & +65..325 TP' }
                    or { wsd = { 9,18,27,36,45 }, crit = { 4,8,12,16,20 }, critDmg = { 4,8,12,16,20 }, zeroDesc = 'MNK Stance: +9..45% WSD & +Crit/Crit Dmg' }))
    end

    -- Berserker / DPS T2 C3 varied by archetype
    if isMagDmg then
        return H.node(2, 3, 'zk_t2_c3', eleName .. ' Arcana', 5, '+9..45 MAB, +5..25% WSD & +50..250 TP',
            function(r) return string.format('+%d MAB, +%d%% WSD, +%d TP', r * 9, r * 5, r * 50) end,
            { matt = { 9,18,27,36,45 }, wsd = { 5,10,15,20,25 }, tpBonus = { 50,100,150,200,250 } })
    elseif isNonPhys or archetype == 'utility' then
        return H.node(2, 3, 'zk_t2_c3', 'Tactical Overflow', 5, '+7..35% WSD & +60..300 TP Bonus',
            function(r) return string.format('+%d%% WSD, +%d TP', r * 7, r * 60) end,
            { wsd = { 7,14,21,28,35 }, tpBonus = { 60,120,180,240,300 } })
    elseif archetype == 'crit' then
        return H.node(2, 3, 'zk_t2_c3', 'Precision Lethality', 5, '+5..25% Crit, +6..30% Crit Dmg & +6..30 ' .. accLabel,
            function(r) return string.format('+%d%% Crit, +%d%% CrDmg, +%d %s', r * 5, r * 6, r * 6, accLabel) end,
            { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 }, [accKey] = { 6,12,18,24,30 } })
    elseif archetype == 'multihit' then
        return H.node(2, 3, 'zk_t2_c3', 'Relentless Cadence', 5, '+4..20 Store TP (12s) & +7..35% WS Atk, +8..40 ' .. accLabel,
            function(r) return string.format('+%d STP (12s), +%d%% Atk, +%d %s', r * 4, r * 7, r * 8, accLabel) end,
            { storeTp = { 4,8,12,16,20 }, atkPct = { 7,14,21,28,35 }, [accKey] = { 8,16,24,32,40 } })
    end
    return H.node(2, 3, 'zk_t2_c3', 'Armor Sundering', 5, 'Ignores 6..30% DEF & +5..25% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 6, r * 5) end,
        { defIgnore = { 0.06,0.12,0.18,0.24,0.30 }, wsd = { 5,10,15,20,25 } })
end

local function makeTailoredCol3T3(wsId, archetype, isNonPhys, isMagDmg, roleCat)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local orig = ws and ws.orig or {}
    local isRanged = (ws and ws.wsType == 'ranged')
    local accKey = isRanged and 'racc' or 'acc'
    local accLabel = isRanged and 'RAcc' or 'Acc'
    local eleUpper, eleName, elem = getElementTheme(wsId)
    local hasNativeDebuff = (orig.debuff ~= nil)

    if roleCat == 'tank' then
        if isMagDmg then
            return H.node(3, 3, 'tk_t3_c3', elem.adj .. ' Runic Focus', 5,
                string.format('+8..40 MAB, +8..40 MACC & %s', elem.debLabel),
                function(r)
                    local dTxt = elem.debDisp and elem.debDisp(r) or string.format('%s -%d', elem.debLabel, elem.debPwr[r])
                    return string.format('+%d MAB/MACC, %s', r * 8, dTxt)
                end,
                { matt = { 8,16,24,32,40 }, macc = { 8,16,24,32,40 },
                  targetDebuffs = {{ effect = elem.debuff, power = elem.debPwr, duration = 45 }} })
        elseif hasNativeDebuff or isNonPhys then
            return H.node(3, 3, 'tk_t3_c3', elem.adj .. ' Disruption', 5,
                string.format('+6..30 Enmity, %s & +50..250 TP Bonus', elem.debLabel),
                function(r)
                    local dTxt = elem.debDisp and elem.debDisp(r) or string.format('%s -%d', elem.debLabel, elem.debPwr[r])
                    return string.format('+%d Enmity, %s, +%d TP', r * 6, dTxt, r * 50)
                end,
                { enmity = { 6,12,18,24,30 }, tpBonus = { 50,100,150,200,250 },
                  targetDebuffs = {{ effect = elem.debuff, power = elem.debPwr, duration = 45 }} })
        end
        return H.node(3, 3, 'tk_t3_c3', 'Bastion Force', 5,
            '+6..30 Enmity, +8..40 ' .. accLabel .. ' & +15..75 DEF (20s)',
            function(r) return string.format('+%d Enmity, +%d %s, +%d DEF', r * 6, r * 8, accLabel, r * 15) end,
            { enmity = { 6,12,18,24,30 }, [accKey] = { 8,16,24,32,40 },
              postBuff = { effect = xi.effect.DEFENSE_BOOST, duration = 20, mods = {{ mod = xi.mod.DEF, val = { 15,30,45,60,75 } }} } })
    elseif roleCat == 'chiweaver' then
        if isMagDmg or ws.element ~= nil then
            return H.node(3, 3, 'cw_t3_c3', 'Light Chi Resonance', 5,
                'Light Follow-up 7..35% & +4..20 Subtle Blow',
                function(r) return string.format('Light +%d%% Follow-up, +%d SB', r * 7, r * 4) end,
                { subtleBlow = { 4,8,12,16,20 }, elemFollow = { ele = 'LIGHT', pct = { 7,14,21,28,35 } } })
        elseif hasNativeDebuff or archetype == 'utility' then
            return H.node(3, 3, 'cw_t3_c3', 'Pacifying Pulse', 5,
                '+10..50 MACC, -3..15 Enmity & Target -5..25 M.Atk',
                function(r) return string.format('+%d MACC, -%d Enmity, -%d MAtk', r * 10, r * 3, r * 5) end,
                { macc = { 10,20,30,40,50 }, enmity = { -3,-6,-9,-12,-15 },
                  targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = { 5,10,15,20,25 }, duration = 45 }} })
        end
        return H.node(3, 3, 'cw_t3_c3', 'Zenith Vitality', 5,
            '+60..300 TP Bonus, +4..20 Subtle Blow & -4..20 Enmity',
            function(r) return string.format('+%d TP, +%d SB, -%d Enmity', r * 60, r * 4, r * 4) end,
            { tpBonus = { 60,120,180,240,300 }, subtleBlow = { 4,8,12,16,20 }, enmity = { -4,-8,-12,-16,-20 } })
    elseif roleCat == 'healer' then
        if isMagDmg then
            return H.node(3, 3, 'hl_t3_c3', elem.adj .. ' Attunement', 5,
                '+9..45 MACC, -4..20 Enmity & Target -6..30 M.Atk',
                function(r) return string.format('+%d MACC, -%d Enmity, -%d MAtk', r * 9, r * 4, r * 6) end,
                { macc = { 9,18,27,36,45 }, enmity = { -4,-8,-12,-16,-20 },
                  targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = { 6,12,18,24,30 }, duration = 45 }} })
        end
        return H.node(3, 3, 'hl_t3_c3', 'Mending Tempo', 5,
            '+70..350 TP Bonus & Target -6..30 M.Atk (45s)',
            function(r) return string.format('+%d TP Bonus, Target -%d M.Atk', r * 70, r * 6) end,
            { tpBonus = { 70,140,210,280,350 }, targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = { 6,12,18,24,30 }, duration = 45 }} })
    elseif roleCat == 'spellblade' then
        if isMagDmg then
            return H.node(3, 3, 'sb_t3_c3', elem.adj .. ' Amplifier', 5,
                '+10..50 MAB, +10..50 MACC & +5..25% WSD',
                function(r) return string.format('+%d MAB/MACC, +%d%% WSD', r * 10, r * 5) end,
                { matt = { 10,20,30,40,50 }, macc = { 10,20,30,40,50 }, wsd = { 5,10,15,20,25 } })
        elseif isNonPhys then
            return H.node(3, 3, 'sb_t3_c3', elem.adj .. ' Edgeflare', 5,
                eleName .. ' Follow-up 10..50% & +8..40 MACC',
                function(r) return string.format('%s +%d%%, +%d MACC', eleName, r * 10, r * 8) end,
                { macc = { 8,16,24,32,40 }, elemFollow = { ele = eleUpper, pct = { 10,20,30,40,50 } } })
        end
        return H.node(3, 3, 'sb_t3_c3', elem.adj .. ' Enspell Flurry', 5,
            '+1 Bonus Hit, ' .. elem.enLabel .. ' (20s) & +8..40 ' .. accLabel,
            function(r) return string.format('+1 Hit, %s, +%d %s', elem.enLabel, r * 8, accLabel) end,
            { bonusHits = { 1,1,1,1,1 }, [accKey] = { 8,16,24,32,40 },
              statusBuffs = {{ effect = elem.enBuff, power = { 20,28,36,44,52 }, duration = 20 }} })
    elseif roleCat == 'commander' then
        if isNonPhys then
            return H.node(3, 3, 'cm_t3_c3', 'Resonant Command', 5,
                '+8..40% SC Dmg & +0.25..1.25 fTP',
                function(r) return string.format('+%d%% SC Dmg, +%.2f fTP', r * 8, r * 0.25) end,
                { scBonus = { 8,16,24,32,40 }, ftpAdd = { 0.25,0.50,0.75,1.00,1.25 } })
        end
        return H.node(3, 3, 'cm_t3_c3', 'Coordinated Assault', 5,
            '+1 Bonus Hit & +8..40% SC Dmg',
            function(r) return string.format('+1 Hit, +%d%% SC Dmg', r * 8) end,
            { bonusHits = { 1,1,1,1,1 }, scBonus = { 8,16,24,32,40 } })
    elseif roleCat == 'blackbelt' then
        if isMagDmg or isNonPhys then
            return H.node(3, 3, 'bb_t3_c3', elem.adj .. ' Chi Edge', 5,
                eleName .. ' Follow-up 9..45% & +6..30 Subtle Blow',
                function(r) return string.format('%s +%d%%, +%d SB', eleName, r * 9, r * 6) end,
                { subtleBlow = { 6,12,18,24,30 }, elemFollow = { ele = eleUpper, pct = { 9,18,27,36,45 } } })
        elseif archetype == 'crit' then
            return H.node(3, 3, 'bb_t3_c3', 'Vital Point Strike', 5,
                '+5..25% Crit, +6..30% Crit Dmg & +4..20 Subtle Blow',
                function(r) return string.format('+%d%% Crit, +%d%% CrDmg, +%d SB', r * 5, r * 6, r * 4) end,
                { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 }, subtleBlow = { 4,8,12,16,20 } })
        elseif archetype == 'multihit' then
            return H.node(3, 3, 'bb_t3_c3', 'Lightning Footwork', 5,
                '+4..20 Store TP, +8..40 ' .. accLabel .. ' & +5..25% Crit',
                function(r) return string.format('+%d STP (12s), +%d %s, +%d%% Crit', r * 4, r * 8, accLabel, r * 5) end,
                { storeTp = { 4,8,12,16,20 }, [accKey] = { 8,16,24,32,40 }, crit = { 5,10,15,20,25 } })
        end
        return H.node(3, 3, 'bb_t3_c3', 'Shatter Fist', 5,
            'Ignores 6..30% DEF & +6..30% Crit Dmg',
            function(r) return string.format('%d%% DEF Ign, +%d%% Crit Dmg', r * 6, r * 6) end,
            { defIgnore = { 0.06,0.12,0.18,0.24,0.30 }, critDmg = { 6,12,18,24,30 } })
    end

    -- Berserker / DPS T3 C3 varied by element / archetype (HP Drain halved to 3..13%)
    if isNonPhys then
        return H.elemFollow(3, 3, 'zk_t3_c3', eleName .. ' Detonation', eleUpper, eleName, 12, false)
    elseif archetype == 'heavy' then
        return H.node(3, 3, 'zk_t3_c3', elem.adj .. ' Cleaver', 5,
            eleName .. ' Follow-up 8..40% & +6..30% WS Atk',
            function(r) return string.format('%s +%d%%, +%d%% Atk', eleName, r * 8, r * 6) end,
            { atkPct = { 6,12,18,24,30 }, elemFollow = { ele = eleUpper, pct = { 8,16,24,32,40 } } })
    elseif archetype == 'crit' then
        return H.node(3, 3, 'zk_t3_c3', 'Sanguine Precision', 5,
            '+5..25% Crit, +6..30% Crit Dmg & 3..13% HP Drain',
            function(r) return string.format('+%d%% Crit, +%d%% CrDmg, %d%% Drain', r * 5, r * 6, ({3,5,8,10,13})[r]) end,
            { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 }, hpDrain = { 3,5,8,10,13 } })
    end
    return H.node(3, 3, 'zk_t3_c3', 'Bloodbath Momentum', 5,
        '+5..25% Crit, +6..30% Crit Dmg & 3..13% HP Drain',
        function(r) return string.format('+%d%% Crit, +%d%% CrDmg, %d%% Drain', r * 5, r * 6, ({3,5,8,10,13})[r]) end,
        { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 }, hpDrain = { 3,5,8,10,13 } })
end

local function makeTailoredCol3T4(wsId, archetype, isNonPhys, isMagDmg, roleCat)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local orig = ws and ws.orig or {}
    local aftermath = orig.aftermath
    local amLabel = aftermath == 'relic' and 'Relic' or (aftermath == 'mythic' and 'Mythic' or (aftermath == 'empyrean' and 'Empyrean' or nil))

    if roleCat == 'tank' then
        if isMagDmg then
            return H.node(4, 3, 'tk_t4_c3', (amLabel or 'Vanguard') .. ' Aegis', 5,
                '+6..30% WSD, +8..40 MAB & +6..30 Enmity',
                function(r) return string.format('+%d%% WSD, +%d MAB, +%d Enmity', r * 6, r * 8, r * 6) end,
                { wsd = { 6,12,18,24,30 }, matt = { 8,16,24,32,40 }, enmity = { 6,12,18,24,30 } })
        elseif isNonPhys then
            return H.node(4, 3, 'tk_t4_c3', (amLabel or 'Vanguard') .. ' Recovery', 5,
                '+6..30% WSD, +8..40 Enmity & Heal 2..8% HP',
                function(r) return string.format('+%d%% WSD, +%d Enmity, Heal %d%%', r * 6, r * 8, ({2,3,5,6,8})[r]) end,
                { wsd = { 6,12,18,24,30 }, enmity = { 8,16,24,32,40 }, selfMaxHpHealPct = { 2,3,5,6,8 } })
        end
        return H.node(4, 3, 'tk_t4_c3', (amLabel or 'Vanguard') .. ' Mastery', 5,
            'Stoneskin 150..350, +5..25% WSD & +6..30 Enmity',
            function(r) return string.format('Stoneskin %d, +%d%% WSD, +%d Enmity', 100 + r * 50, r * 5, r * 6) end,
            { wsd = { 5,10,15,20,25 }, enmity = { 6,12,18,24,30 },
              statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 150,200,250,300,350 }, duration = 45, tier = 3 }} })
    elseif roleCat == 'chiweaver' then
        local title = amLabel and (amLabel .. ' Harmony') or 'Chi Weaver Mastery'
        if isMagDmg then
            return H.node(4, 3, 'cw_t4_c3', title, 5,
                '+6..30% WSD, +8..40 MACC & Party +35..175 TP',
                function(r) return string.format('+%d%% WSD, +%d MACC, Party +%d TP', r * 6, r * 8, r * 35) end,
                { wsd = { 6,12,18,24,30 }, macc = { 8,16,24,32,40 }, partyTp = { 35,70,105,140,175 } })
        end
        return H.node(4, 3, 'cw_t4_c3', title, 5,
            '+6..30% WSD, Party Heal 1..5% & -4..20 Enmity',
            function(r) return string.format('+%d%% WSD, Party Heal %d%%, -%d Enmity', r * 6, r, r * 4) end,
            { wsd = { 6,12,18,24,30 }, partyHealPct = { 1,2,3,4,5 }, enmity = { -4,-8,-12,-16,-20 } })
    elseif roleCat == 'healer' then
        local title = amLabel and (amLabel .. ' Grace') or 'Healer Mastery'
        if isMagDmg then
            return H.node(4, 3, 'hl_t4_c3', title, 5,
                '+6..30% WSD, +8..40 MACC & -4..20 Enmity',
                function(r) return string.format('+%d%% WSD, +%d MACC, -%d Enmity', r * 6, r * 8, r * 4) end,
                { wsd = { 6,12,18,24,30 }, macc = { 8,16,24,32,40 }, enmity = { -4,-8,-12,-16,-20 } })
        end
        return H.node(4, 3, 'hl_t4_c3', title, 5,
            '+6..30% WSD, Party Heal 1..5% & -4..20 Enmity',
            function(r) return string.format('+%d%% WSD, Party Heal %d%%, -%d Enmity', r * 6, r, r * 4) end,
            { wsd = { 6,12,18,24,30 }, partyHealPct = { 1,2,3,4,5 }, enmity = { -4,-8,-12,-16,-20 } })
    elseif roleCat == 'spellblade' then
        local title = amLabel and (amLabel .. ' Conduction') or 'Spellblade Mastery'
        if isMagDmg then
            return H.node(4, 3, 'sb_t4_c3', title, 5,
                '+7..35% WSD, +10..50 MAB & +8..40% SC Dmg',
                function(r) return string.format('+%d%% WSD, +%d MAB, +%d%% SC', r * 7, r * 10, r * 8) end,
                { wsd = { 7,14,21,28,35 }, matt = { 10,20,30,40,50 }, scBonus = { 8,16,24,32,40 } })
        end
        return H.node(4, 3, 'sb_t4_c3', title, 5,
            '+7..35% WSD, +60..300 TP Bonus & +8..40% SC Dmg',
            function(r) return string.format('+%d%% WSD, +%d TP, +%d%% SC', r * 7, r * 60, r * 8) end,
            { wsd = { 7,14,21,28,35 }, tpBonus = { 60,120,180,240,300 }, scBonus = { 8,16,24,32,40 } })
    elseif roleCat == 'commander' then
        local title = amLabel and (amLabel .. ' Command') or 'Commander Mastery'
        return H.node(4, 3, 'cm_t4_c3', title, 5,
            '+7..35% WSD & Party +5..25% Crit (20s)',
            function(r) return string.format('+%d%% WSD, Party +%d%% Crit (20s)', r * 7, r * 5) end,
            { wsd = { 7,14,21,28,35 }, partyBuffs = {{ effect = xi.effect.POTENCY, power = { 5,10,15,20,25 }, duration = 20 }} })
    elseif roleCat == 'blackbelt' then
        local title = amLabel and (amLabel .. ' Belt Mastery') or 'Martial Zenith'
        if isNonPhys then
            return H.node(4, 3, 'bb_t4_c3', title, 5,
                '+7..35% WSD, +0.3..1.5 fTP & +8..40% SC Dmg',
                function(r) return string.format('+%d%% WSD, +%.1f fTP, +%d%% SC', r * 7, r * 0.3, r * 8) end,
                { wsd = { 7,14,21,28,35 }, ftpAdd = { 0.3,0.6,0.9,1.2,1.5 }, scBonus = { 8,16,24,32,40 } })
        elseif archetype == 'crit' then
            return H.node(4, 3, 'bb_t4_c3', title, 5,
                '+6..30% Crit, +6..30% Crit Dmg & +7..35% WSD',
                function(r) return string.format('+%d%% Crit, +%d%% CrDmg, +%d%% WSD', r * 6, r * 6, r * 7) end,
                { crit = { 6,12,18,24,30 }, critDmg = { 6,12,18,24,30 }, wsd = { 7,14,21,28,35 } })
        end
        return H.node(4, 3, 'bb_t4_c3', title, 5,
            '+1 Bonus Hit, fTP ALL Hits & +6..30% WSD',
            function(r) return string.format('+1 Hit, fTP ALL, +%d%% WSD', r * 6) end,
            { bonusHits = { 1,1,1,1,1 }, multiHitfTPAt = 1, wsd = { 6,12,18,24,30 } })
    end

    -- Berserker T4 C3 varied by aftermath / archetype
    if isNonPhys then
        return H.node(4, 3, 'zk_t4_c3', (amLabel or 'Cataclysmic') .. ' Apex', 5,
            '+0.3..1.5 fTP, +7..35% WSD & +8..40% SC Dmg',
            function(r) return string.format('+%.1f fTP, +%d%% WSD, +%d%% SC', r * 0.3, r * 7, r * 8) end,
            { ftpAdd = { 0.3,0.6,0.9,1.2,1.5 }, wsd = { 7,14,21,28,35 }, scBonus = { 8,16,24,32,40 } })
    elseif archetype == 'crit' then
        return H.node(4, 3, 'zk_t4_c3', (amLabel or 'Executioner') .. ' Apex', 5,
            '+6..30% Crit, +7..35% Crit Dmg & +6..30% WSD',
            function(r) return string.format('+%d%% Crit, +%d%% CrDmg, +%d%% WSD', r * 6, r * 7, r * 6) end,
            { crit = { 6,12,18,24,30 }, critDmg = { 7,14,21,28,35 }, wsd = { 6,12,18,24,30 } })
    end
    return H.node(4, 3, 'zk_t4_c3', (amLabel or 'Berserker') .. ' Apex', 5,
        '+1 Bonus Hit, fTP ALL Hits & +6..30% WSD',
        function(r) return string.format('+1 Hit, fTP ALL, +%d%% WSD', r * 6) end,
        { bonusHits = { 1,1,1,1,1 }, multiHitfTPAt = 1, wsd = { 6,12,18,24,30 } })
end

-----------------------------------
-- Unified Grid Assembler (Preserves WS Col 1 + T1, Injects Spec Col 2, Differentiates Col 3)
-----------------------------------
local function assembleSpecTree(wsId, archetype, baseNodes, roleCat, col2SpecNodes, defaultPrefStat)
    local isNonPhys, _ = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local grid = { {}, {}, {}, {} }

    local function put(n, force)
        if n == nil then return false end
        local t, c = n.tier, n.col
        if grid[t] and (force or grid[t][c] == nil) then
            grid[t][c] = n
            return true
        end
        return false
    end

    -- 1. Preserve Col 1 (T1..T4, incl. WS capstone) and T1 C3 from bespoke baseNodes
    for _, raw in ipairs(baseNodes or {}) do
        if raw.col == 1 or (raw.tier == 1 and raw.col == 3) then
            local adapted = adaptBaseNodeForRole(raw, wsId, archetype, roleCat)
            if adapted ~= nil then
                adapted.requires = nil
                put(adapted)
            end
        end
    end

    -- Ensure T1 C1 & T1 C3 exist
    if grid[1][1] == nil then
        put(makeScalingT1Col1(wsId, nil, isNonPhys))
    end
    if grid[1][3] == nil then
        put(makePrimaryWscNode(wsId, 1, 3, roleCat .. '_t1_c3', isNonPhys, defaultPrefStat))
    end

    -- Preserve baseNodes (1,2) when appropriate for WS identity & H2H hit-rebuilds
    local base12 = findGridNode(baseNodes, 1, 2)
    if base12 ~= nil then
        local adapted12 = adaptBaseNodeForRole(base12, wsId, archetype, roleCat)
        if adapted12 ~= nil then
            adapted12.requires = nil
            put(adapted12)
        end
    end

    -- 2. Place Spec T2..T4 in Col 2; place Spec T1 at (1,2) if free, else displace cleanly to (2,3)
    local specT1 = col2SpecNodes[1] and copyTable(col2SpecNodes[1]) or nil
    if specT1 ~= nil then
        if grid[1][2] == nil then
            specT1.tier, specT1.col = 1, 2
            put(specT1)
        elseif findGridNode(baseNodes, 2, 3) == nil and grid[2][3] == nil then
            specT1.tier, specT1.col = 2, 3
            put(specT1)
        end
    end

    for tier = 2, 4 do
        local sn = col2SpecNodes[tier] and copyTable(col2SpecNodes[tier]) or nil
        if sn ~= nil then
            sn.tier, sn.col = tier, 2
            put(sn)
        end
    end

    -- Fill any missing Col 1 T2..T4 (e.g. partial baseline trees)
    for tier = 2, 4 do
        if grid[tier][1] == nil then
            local fallback = findGridNode(baseNodes, tier, 1)
            if fallback ~= nil then
                local ad = adaptBaseNodeForRole(fallback, wsId, archetype, roleCat)
                if ad ~= nil then
                    ad.requires = nil
                    put(ad)
                end
            end
        end
    end

    -- 3. Preserve bespoke Col 3 (T2..T4) if supplied (e.g. GS), adapted for role
    for tier = 2, 4 do
        if grid[tier][3] == nil then
            local raw3 = findGridNode(baseNodes, tier, 3)
            if raw3 ~= nil then
                local adapted3 = adaptBaseNodeForRole(raw3, wsId, archetype, roleCat)
                if adapted3 ~= nil then
                    adapted3.requires = nil
                    put(adapted3)
                end
            end
        end
    end

    -- 4. Fill remaining empty Col 3 (T2..T4) with WS-differentiated Col 3 nodes
    if grid[2][3] == nil then
        put(makeTailoredCol3T2(wsId, archetype, isNonPhys, isMagDmg, roleCat))
    end
    if grid[3][3] == nil then
        put(makeTailoredCol3T3(wsId, archetype, isNonPhys, isMagDmg, roleCat))
    end
    if grid[4][3] == nil then
        put(makeTailoredCol3T4(wsId, archetype, isNonPhys, isMagDmg, roleCat))
    end

    local out = {}
    for tier = 1, 4 do
        for col = 1, 3 do
            if grid[tier][col] ~= nil then
                table.insert(out, grid[tier][col])
            end
        end
    end
    return out
end

-----------------------------------
-- Spec Tree Builders (All 7 Categories, Halved Healing)
-----------------------------------

-- 1) Tank (Inquisitor / Gladiator / Sensei) — all healing halved
local function buildTankSpecNodes(wsId, archetype, baseNodes)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local skill = ws and ws.skill or 0
    local isSensei = (skill == xi.skill.STAFF or skill == xi.skill.HAND_TO_HAND or skill == xi.skill.KATANA or skill == xi.skill.DAGGER)
    local isGladiator = (skill == xi.skill.CLUB or skill == xi.skill.AXE or skill == xi.skill.GREAT_AXE)

    local col2
    if isSensei then
        col2 =
        {
            H.node(1, 2, 'tk_t1_c2', 'Sensei Provoke', 7, '+7..49 Enmity & +2..14% Counter (15s)',
                function(r) return string.format('+%d Enmity, +%d%% Counter (15s)', r * 7, r * 2) end,
                { enmity = { 7,14,21,28,35,42,49 }, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 15, mods = {{ mod = xi.mod.COUNTER, val = { 2,4,6,8,10,12,14 } }} } }),
            H.node(2, 2, 'tk_t2_c2', 'Evasive Poise', 5, 'Heal 2..8% Max HP & +5..25 EVA (20s)',
                function(r) return string.format('Heal %d%% Max HP, +%d EVA (20s)', ({2,3,5,6,8})[r], r * 5) end,
                { selfMaxHpHealPct = { 2,3,5,6,8 }, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.EVA, val = { 5,10,15,20,25 } }} } }),
            H.node(3, 2, 'tk_t3_c2', 'Sweeping Parry', 5, '+3..15% Parry (20s) & Stoneskin 120..360',
                function(r) return string.format('+%d%% Parry, Stoneskin %d', r * 3, 60 + r * 60) end,
                { postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.INQUARTATA, val = { 3,6,9,12,15 } }} },
                  statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 120,180,240,300,360 }, duration = 45, tier = 3 }} }),
            H.node(4, 2, 'tk_t4_c2', 'Grandmaster Guard', 3, 'Phalanx 20..40 (30s) & +10..30% WSD',
                function(r) return string.format('Phalanx %d (30s), +%d%% WSD', 10 + r * 10, r * 10) end,
                { wsd = { 10,20,30 }, statusBuffs = {{ effect = xi.effect.PHALANX, power = { 20,30,40 }, duration = 30 }} }),
        }
    elseif isGladiator then
        col2 =
        {
            H.node(1, 2, 'tk_t1_c2', 'Bloodthirsty Taunt', 7, '+7..49 Enmity & Heal 1..7% Max HP',
                function(r) return string.format('+%d Enmity, Heal %d%% Max HP', r * 7, r) end,
                { enmity = { 7,14,21,28,35,42,49 }, selfMaxHpHealPct = { 1,2,3,4,5,6,7 } }),
            H.node(2, 2, 'tk_t2_c2', 'Crimson Shield', 5, '+4..20% Shield Block (20s) & Stoneskin 120..360',
                function(r) return string.format('+%d%% Block, Stoneskin %d', r * 4, 60 + r * 60) end,
                { postBuff = { effect = xi.effect.SHIELD_BREAK, duration = 20, mods = {{ mod = xi.mod.PALISADE_BLOCK_BONUS, val = { 4,8,12,16,20 } }} },
                  statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 120,180,240,300,360 }, duration = 45, tier = 3 }} }),
            H.node(3, 2, 'tk_t3_c2', 'Sanguine Leech', 5, 'Drains 6..20% WS dmg as HP & +6..30% WSD',
                function(r) return string.format('%d%% HP Drain, +%d%% WSD', ({6,10,13,17,20})[r], r * 6) end,
                { hpDrain = { 6,10,13,17,20 }, wsd = { 6,12,18,24,30 } }),
            H.node(4, 2, 'tk_t4_c2', 'Immortal Gladiator', 3, 'Phalanx 20..40 (30s) & Heal 3..9% Max HP',
                function(r) return string.format('Phalanx %d (30s), Heal %d%% HP', 10 + r * 10, r * 3) end,
                { selfMaxHpHealPct = { 3,6,9 }, statusBuffs = {{ effect = xi.effect.PHALANX, power = { 20,30,40 }, duration = 30 }} }),
        }
    else
        col2 =
        {
            H.node(1, 2, 'tk_t1_c2', 'Inquisitor Challenge', 7, '+7..49 Enmity & Stoneskin 90..330 (45s)',
                function(r) return string.format('+%d Enmity, Stoneskin %d', r * 7, 50 + r * 40) end,
                { enmity = { 7,14,21,28,35,42,49 }, statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 90,130,170,210,250,290,330 }, duration = 45, tier = 3 }} }),
            H.node(2, 2, 'tk_t2_c2', 'Order Ward', 5, 'Heal 2..8% Max HP & +3..15% Parry (20s)',
                function(r) return string.format('Heal %d%% Max HP, +%d%% Parry', ({2,3,5,6,8})[r], r * 3) end,
                { selfMaxHpHealPct = { 2,3,5,6,8 }, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.INQUARTATA, val = { 3,6,9,12,15 } }} } }),
            H.node(3, 2, 'tk_t3_c2', 'Sanctified Phalanx', 5, 'Phalanx 16..36 (30s) & +6..30 Enmity',
                function(r) return string.format('Phalanx %d (30s), +%d Enmity', 11 + r * 5, r * 6) end,
                { enmity = { 6,12,18,24,30 }, statusBuffs = {{ effect = xi.effect.PHALANX, power = { 16,21,26,31,36 }, duration = 30 }} }),
            H.node(4, 2, 'tk_t4_c2', 'Unbreakable Aegis', 3, 'Stoneskin 250..500 & Heal 3..9% Max HP',
                function(r) return string.format('Stoneskin %d, Heal %d%% HP', 125 + r * 125, r * 3) end,
                { selfMaxHpHealPct = { 3,6,9 }, statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 250,375,500 }, duration = 45, tier = 3 }} }),
        }
    end

    return assembleSpecTree(wsId, archetype, baseNodes, 'tank', col2, 'vit')
end

-- 2) Spellblade / Sage / Necromancer — all healing halved
local function buildSpellbladeSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local skill = ws and ws.skill or 0
    local eleUpper, eleName = getDefaultElement(wsId)
    local isNecro = (skill == xi.skill.SCYTHE)
    local isSage  = (skill == xi.skill.CLUB or skill == xi.skill.STAFF or skill == xi.skill.DAGGER)

    local col2
    if isNecro then
        col2 =
        {
            isMagDmg
                and H.node(1, 2, 'sb_t1_c2', 'Harbinger Pact', 7, 'Heals Undead Pet 3..18% HP/MP & +8..56 MAB',
                    function(r) return string.format('Pet Heal %d%%, +%d MAB', ({3,5,8,10,13,15,18})[r], r * 8) end,
                    { eosHeal = { 3,5,8,10,13,15,18 }, matt = { 8,16,24,32,40,48,56 } })
                or H.node(1, 2, 'sb_t1_c2', 'Harbinger Pact', 7, 'Heals Undead Pet 3..18% HP/MP & +4..28% WSD',
                    function(r) return string.format('Pet Heal %d%%, +%d%% WSD', ({3,5,8,10,13,15,18})[r], r * 4) end,
                    { eosHeal = { 3,5,8,10,13,15,18 }, wsd = { 4,8,12,16,20,24,28 } }),
            H.node(2, 2, 'sb_t2_c2', 'Soul Siphon', 5, 'HP Drain 2..10% & MP Drain 5..25% of WS dmg',
                function(r) return string.format('%d%% HP Drain, %d%% MP Drain', r * 2, r * 5) end,
                { hpDrain = { 2,4,6,8,10 }, mpDrain = { 5,10,15,20,25 } }),
            H.elemFollow(3, 2, 'sb_t3_c2', 'Necrotic Burst', 'DARK', 'Dark', 12, false),
            isMagDmg
                and H.node(4, 2, 'sb_t4_c2', 'Lich Sovereign', 3, 'Pet Heal 8..23%, +15..45% WSD & +15..45 MAB',
                    function(r) return string.format('Pet +%d%%, +%d%% WSD, +%d MAB', ({8,15,23})[r], r * 15, r * 15) end,
                    { eosHeal = { 8,15,23 }, wsd = { 15,30,45 }, matt = { 15,30,45 } })
                or (isNonPhys
                    and H.node(4, 2, 'sb_t4_c2', 'Lich Sovereign', 3, 'Pet Heal 8..23%, +15..45% WSD & +0.4..1.2 fTP',
                        function(r) return string.format('Pet +%d%%, +%d%% WSD, +%.1f fTP', ({8,15,23})[r], r * 15, r * 0.4) end,
                        { eosHeal = { 8,15,23 }, wsd = { 15,30,45 }, ftpAdd = { 0.4,0.8,1.2 } })
                    or H.node(4, 2, 'sb_t4_c2', 'Lich Sovereign', 3, 'Pet Heal 8..23%, +15..45% WSD & 10..30% DEF Ign',
                        function(r) return string.format('Pet +%d%%, +%d%% WSD, %d%% DEF Ign', ({8,15,23})[r], r * 15, r * 10) end,
                        { eosHeal = { 8,15,23 }, wsd = { 15,30,45 }, defIgnore = { .10,.20,.30 } })),
        }
    elseif isSage then
        col2 =
        {
            isMagDmg
                and H.node(1, 2, 'sb_t1_c2', 'Titania Covenant', 7, 'Heals Titania/Pet 3..18% & +8..56 MAB',
                    function(r) return string.format('Pet Heal %d%%, +%d MAB', ({3,5,8,10,13,15,18})[r], r * 8) end,
                    { eosHeal = { 3,5,8,10,13,15,18 }, matt = { 8,16,24,32,40,48,56 } })
                or H.node(1, 2, 'sb_t1_c2', 'Titania Covenant', 7, 'Heals Titania/Pet 3..18% & +4..28% WSD',
                    function(r) return string.format('Pet Heal %d%%, +%d%% WSD', ({3,5,8,10,13,15,18})[r], r * 4) end,
                    { eosHeal = { 3,5,8,10,13,15,18 }, wsd = { 4,8,12,16,20,24,28 } }),
            isMagDmg
                and H.node(2, 2, 'sb_t2_c2', 'Dark Arts Helix', 5, 'MP Drain 6..30% & +9..45 MACC',
                    function(r) return string.format('MP Drain %d%%, +%d MACC', r * 6, r * 9) end,
                    { mpDrain = { 6,12,18,24,30 }, macc = { 9,18,27,36,45 } })
                or H.node(2, 2, 'sb_t2_c2', 'Dark Arts Helix', 5, 'MP Drain 6..30% & +5..25% WSD',
                    function(r) return string.format('MP Drain %d%%, +%d%% WSD', r * 6, r * 5) end,
                    { mpDrain = { 6,12,18,24,30 }, wsd = { 5,10,15,20,25 } }),
            H.elemFollow(3, 2, 'sb_t3_c2', eleName .. ' Helix Burst', eleUpper, eleName, 12, false),
            isMagDmg
                and H.node(4, 2, 'sb_t4_c2', 'Sage Overcharge', 3, '+16..48% WSD, +18..54 MAB & -15..45 Target MEVA',
                    function(r) return string.format('+%d%% WSD, +%d MAB, -%d MEVA', r * 16, r * 18, r * 15) end,
                    { wsd = { 16,32,48 }, matt = { 18,36,54 }, targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 60 }} })
                or (isNonPhys
                    and H.node(4, 2, 'sb_t4_c2', 'Sage Overcharge', 3, '+16..48% WSD, +0.4..1.2 fTP & -15..45 Target MEVA',
                        function(r) return string.format('+%d%% WSD, +%.1f fTP, -%d MEVA', r * 16, r * 0.4, r * 15) end,
                        { wsd = { 16,32,48 }, ftpAdd = { 0.4,0.8,1.2 }, targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 60 }} })
                    or H.node(4, 2, 'sb_t4_c2', 'Sage Overcharge', 3, '+16..48% WSD, 10..30% DEF Ign & -15..45 Target MEVA',
                        function(r) return string.format('+%d%% WSD, %d%% DEF Ign, -%d MEVA', r * 16, r * 10, r * 15) end,
                        { wsd = { 16,32,48 }, defIgnore = { .10,.20,.30 }, targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 60 }} })),
        }
    else
        col2 =
        {
            isMagDmg
                and H.node(1, 2, 'sb_t1_c2', 'Conduction Edge', 7, 'Grants +1..2 Conduction & +8..56 MAB',
                    function(r) return string.format('+%d Conduction, +%d MAB', r >= 5 and 2 or 1, r * 8) end,
                    { conductionAdd = { 1,1,1,1,2,2,2 }, matt = { 8,16,24,32,40,48,56 } })
                or H.node(1, 2, 'sb_t1_c2', 'Conduction Edge', 7, 'Grants +1..2 Conduction & +4..28% WSD',
                    function(r) return string.format('+%d Conduction, +%d%% WSD', r >= 5 and 2 or 1, r * 4) end,
                    { conductionAdd = { 1,1,1,1,2,2,2 }, wsd = { 4,8,12,16,20,24,28 } }),
            isMagDmg
                and H.node(2, 2, 'sb_t2_c2', 'Runic Siphon', 5, 'MP Drain 6..30% & +9..45 MACC',
                    function(r) return string.format('MP Drain %d%%, +%d MACC', r * 6, r * 9) end,
                    { mpDrain = { 6,12,18,24,30 }, macc = { 9,18,27,36,45 } })
                or H.node(2, 2, 'sb_t2_c2', 'Runic Siphon', 5, 'MP Drain 6..30% & +5..25% WSD',
                    function(r) return string.format('MP Drain %d%%, +%d%% WSD', r * 6, r * 5) end,
                    { mpDrain = { 6,12,18,24,30 }, wsd = { 5,10,15,20,25 } }),
            H.elemFollow(3, 2, 'sb_t3_c2', eleName .. ' Edgeflare', eleUpper, eleName, 12, false),
            isMagDmg
                and H.node(4, 2, 'sb_t4_c2', 'Ascendant Spellblade', 3, '+2..3 Conduction, +15..45% WSD & +15..45 MAB',
                    function(r) return string.format('+%d Conduction, +%d%% WSD, +%d MAB', r >= 2 and 3 or 2, r * 15, r * 15) end,
                    { conductionAdd = { 2,3,3 }, wsd = { 15,30,45 }, matt = { 15,30,45 } })
                or H.node(4, 2, 'sb_t4_c2', 'Ascendant Spellblade', 3, '+2..3 Conduction, +15..45% WSD & +0.4..1.2 fTP',
                    function(r) return string.format('+%d Conduction, +%d%% WSD, +%.1f fTP', r >= 2 and 3 or 2, r * 15, r * 0.4) end,
                    { conductionAdd = { 2,3,3 }, wsd = { 15,30,45 }, ftpAdd = { 0.4,0.8,1.2 } }),
        }
    end

    return assembleSpecTree(wsId, archetype, baseNodes, 'spellblade', col2, 'int')
end

-- 3) Healer / Lifebinder / Medic — all healing & regen halved
local function buildHealerSpecNodes(wsId, archetype, baseNodes)
    local col2 =
    {
        H.node(1, 2, 'hl_t1_c2', 'Vivacious Mending', 7, 'Party Heal 1..10% Max HP & Pet Heal 3..18%',
            function(r) return string.format('Party Heal %d%%, Pet Heal %d%%', ({1,3,4,6,7,9,10})[r], ({3,5,8,10,13,15,18})[r]) end,
            { partyHealPct = { 1,3,4,6,7,9,10 }, eosHeal = { 3,5,8,10,13,15,18 } }),
        H.node(2, 2, 'hl_t2_c2', 'Sanctuary Regen', 5, 'Party Regen 6..16/tick (30s) & +5..25% WSD',
            function(r) return string.format('Party Regen %d/t, +%d%% WSD', ({6,9,11,14,16})[r], r * 5) end,
            { wsd = { 5,10,15,20,25 }, partyBuffs = {{ effect = xi.effect.REGEN, power = { 6,9,11,14,16 }, duration = 30 }} }),
        H.node(3, 2, 'hl_t3_c2', 'Runic Lifetap', 5, 'MP Drain 8..40% of WS dmg & Party Refresh 3..15/t',
            function(r) return string.format('MP Drain %d%%, Party Refresh %d/t', r * 8, r * 3) end,
            { mpDrain = { 8,16,24,32,40 }, partyBuffs = {{ effect = xi.effect.REFRESH, power = { 3,6,9,12,15 }, duration = 30 }} }),
        H.node(4, 2, 'hl_t4_c2', 'Lifebinder Benediction', 3, 'Party Heal 5..15% Max HP & +10..30% WSD',
            function(r) return string.format('Party Heal %d%%, +%d%% WSD', r * 5, r * 10) end,
            { partyHealPct = { 5,10,15 }, wsd = { 10,20,30 } }),
    }

    return assembleSpecTree(wsId, archetype, baseNodes, 'healer', col2, 'mnd')
end

-- 4) MNK Chi Weaver (Unarmed Ranged Light Chi & Pulse Healer)
-- STRICT RULE: ZERO MP, ZERO Refresh! Uses Max HP, Regen, TP/Party TP, Ability Haste, Cure Potency, Subtle Blow, Enmity-
local function buildChiWeaverSpecNodes(wsId, archetype, baseNodes)
    local col2 =
    {
        H.node(1, 2, 'cw_t1_c2', 'Resonant Chi Pulse', 7, 'Party Heal 1..10% Max HP, -3..21 Enmity & +4..28 MACC',
            function(r) return string.format('Party Heal %d%%, -%d Enmity, +%d MACC', ({1,3,4,6,7,9,10})[r], r * 3, r * 4) end,
            { partyHealPct = { 1,3,4,6,7,9,10 }, enmity = { -3,-6,-9,-12,-15,-18,-21 }, macc = { 4,8,12,16,20,24,28 } }),
        H.node(2, 2, 'cw_t2_c2', 'Tranquil Lotus Flow', 5, 'Party Regen 6..16/t (30s), +4..20 Subtle Blow & +5..25% WSD',
            function(r) return string.format('Party Regen %d/t, +%d SB, +%d%% WSD', ({6,9,11,14,16})[r], r * 4, r * 5) end,
            { subtleBlow = { 4,8,12,16,20 }, wsd = { 5,10,15,20,25 },
              partyBuffs = {{ effect = xi.effect.REGEN, power = { 6,9,11,14,16 }, duration = 30 }} }),
        H.node(3, 2, 'cw_t3_c2', 'Inner Chi Channeling', 5, 'Party +35..175 TP, +3..15% Cure Pot & +2..10% Abil Haste (18s)',
            function(r) return string.format('Party +%d TP, +%d%% CurePot, +%d%% JA Haste', r * 35, r * 3, r * 2) end,
            { partyTp = { 35,70,105,140,175 },
              postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {
                  { mod = xi.mod.CURE_POTENCY, val = { 3,6,9,12,15 } },
                  { mod = xi.mod.HASTE_ABILITY, val = { 200,400,600,800,1000 } },
              } } }),
        H.node(4, 2, 'cw_t4_c2', 'Lotus Benediction', 3, 'Party Heal 5..15% Max HP, Stoneskin 150..300 & +10..30% WSD',
            function(r) return string.format('Party Heal %d%%, Stoneskin %d, +%d%% WSD', r * 5, 75 + r * 75, r * 10) end,
            { partyHealPct = { 5,10,15 }, wsd = { 10,20,30 },
              statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 150,225,300 }, duration = 45, tier = 3 }} }),
    }

    return assembleSpecTree(wsId, archetype, baseNodes, 'chiweaver', col2, 'mnd')
end

-- 5) Commander
local function buildCommanderSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local col2 =
    {
        H.node(1, 2, 'cm_t1_c2', 'Rallying Cadence', 7, 'Party +35..245 TP & NextWS +4..28% WSD (15s)',
            function(r) return string.format('Party +%d TP, NextWS +%d%% WSD', r * 35, r * 4) end,
            { partyTp = { 35,70,105,140,175,210,245 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 15 } }),
        isMagDmg
            and H.node(2, 2, 'cm_t2_c2', 'Banner of Arcana', 5, 'Party Warcry (+6..30% Atk, 25s) & +7..35 MAB',
                function(r) return string.format('Party +%d%% Atk (25s), +%d MAB', r * 6, r * 7) end,
                { matt = { 7,14,21,28,35 }, partyBuffs = {{ effect = xi.effect.WARCRY, power = { 6,12,18,24,30 }, duration = 25 }} })
            or (isNonPhys
                and H.node(2, 2, 'cm_t2_c2', 'Banner of Clarity', 5, 'Party Warcry (+6..30% Atk, 25s) & +60..300 TP',
                    function(r) return string.format('Party +%d%% Atk (25s), +%d TP', r * 6, r * 60) end,
                    { tpBonus = { 60,120,180,240,300 }, partyBuffs = {{ effect = xi.effect.WARCRY, power = { 6,12,18,24,30 }, duration = 25 }} })
                or H.node(2, 2, 'cm_t2_c2', 'Banner of War', 5, 'Party Warcry (+6..30% Atk, 25s) & +5..25% WSD',
                    function(r) return string.format('Party +%d%% Atk (25s), +%d%% WSD', r * 6, r * 5) end,
                    { wsd = { 5,10,15,20,25 }, partyBuffs = {{ effect = xi.effect.WARCRY, power = { 6,12,18,24,30 }, duration = 25 }} })),
        H.node(3, 2, 'cm_t3_c2', 'Tactical Haste', 5, 'Party Haste +4..20% (25s) & +60..300 TP Bonus',
            function(r) return string.format('Party Haste +%d%% (25s), +%d TP', r * 4, r * 60) end,
            { tpBonus = { 60,120,180,240,300 }, partyBuffs = {{ effect = xi.effect.HASTE, power = { 400,800,1200,1600,2000 }, duration = 25 }} }),
        H.node(4, 2, 'cm_t4_c2', 'Supreme Commander', 3, 'Party +100..300 TP, +15..45% WSD & +12..36% SC Dmg',
            function(r) return string.format('Party +%d TP, +%d%% WSD, +%d%% SC', r * 100, r * 15, r * 12) end,
            { partyTp = { 100,200,300 }, wsd = { 15,30,45 }, scBonus = { 12,24,36 } }),
    }

    return assembleSpecTree(wsId, archetype, baseNodes, 'commander', col2, nil)
end

-- 6) MNK Black Belt (Hand-to-Hand Martial DPS: Kick Rate/DMG, DA, Store TP, Subtle Blow, Combo Momentum)
local function buildBlackBeltSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)

    local t1 = isMagDmg
        and H.node(1, 2, 'bb_t1_c2', 'Martial Momentum', 7, '+3..21 Subtle Blow, +7..49 MAB & NextWS +4..28% WSD',
            function(r) return string.format('+%d SB, +%d MAB, NextWS +%d%%', r * 3, r * 7, r * 4) end,
            { subtleBlow = { 3,6,9,12,15,18,21 }, matt = { 7,14,21,28,35,42,49 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 12 } })
        or (isNonPhys
            and H.node(1, 2, 'bb_t1_c2', 'Martial Momentum', 7, '+3..21 Subtle Blow, +45..315 TP & NextWS +4..28% WSD',
                function(r) return string.format('+%d SB, +%d TP, NextWS +%d%%', r * 3, r * 45, r * 4) end,
                { subtleBlow = { 3,6,9,12,15,18,21 }, tpBonus = { 45,90,135,180,225,270,315 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 12 } })
            or H.node(1, 2, 'bb_t1_c2', 'Martial Momentum', 7, '+3..21 Subtle Blow, +4..28% Atk & NextWS +4..28% WSD',
                function(r) return string.format('+%d SB, +%d%% Atk, NextWS +%d%%', r * 3, r * 4, r * 4) end,
                { subtleBlow = { 3,6,9,12,15,18,21 }, atkPct = { 4,8,12,16,20,24,28 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 12 } }))

    local t2 = isNonPhys
        and H.node(2, 2, 'bb_t2_c2', 'Relentless Footwork', 5, '+4..20 Store TP, +3..15% Kick Rate & +6..30 Kick DMG (18s)',
            function(r) return string.format('+%d STP, +%d%% Kick, +%d KickDMG (18s)', r * 4, r * 3, r * 6) end,
            { tpBonus = { 50,100,150,200,250 },
              postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {
                  { mod = xi.mod.KICK_ATTACK_RATE, val = { 3,6,9,12,15 } },
                  { mod = xi.mod.KICK_DMG, val = { 6,12,18,24,30 } },
                  { mod = xi.mod.STORETP, val = { 4,8,12,16,20 } },
              } } })
        or H.node(2, 2, 'bb_t2_c2', 'Relentless Kick', 5, '+3..15% Kick Rate, +6..30 Kick DMG & +4..20 Store TP (18s)',
            function(r) return string.format('+%d%% Kick, +%d KickDMG, +%d STP (18s)', r * 3, r * 6, r * 4) end,
            { postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 18, mods = {
                { mod = xi.mod.KICK_ATTACK_RATE, val = { 3,6,9,12,15 } },
                { mod = xi.mod.KICK_DMG, val = { 6,12,18,24,30 } },
                { mod = xi.mod.STORETP, val = { 4,8,12,16,20 } },
            } } })

    local t3 = isNonPhys
        and H.node(3, 2, 'bb_t3_c2', 'Flurry Blitz', 5, '+5..25% WSD, +2..10% JA Haste & +4..20% Double Atk (15s)',
            function(r) return string.format('+%d%% WSD, +%d%% JA Haste, +%d%% DA', r * 5, r * 2, r * 4) end,
            { wsd = { 5,10,15,20,25 },
              postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {
                  { mod = xi.mod.HASTE_ABILITY, val = { 200,400,600,800,1000 } },
                  { mod = xi.mod.DOUBLE_ATTACK, val = { 4,8,12,16,20 } },
              } } })
        or H.node(3, 2, 'bb_t3_c2', 'Flurry Blitz', 5, '+4..20% Double Atk, +2..10% JA Haste (15s) & +5..25% WSD',
            function(r) return string.format('+%d%% DA, +%d%% JA Haste, +%d%% WSD', r * 4, r * 2, r * 5) end,
            { wsd = { 5,10,15,20,25 },
              postBuff = { effect = xi.effect.POTENCY, duration = 15, mods = {
                  { mod = xi.mod.DOUBLE_ATTACK, val = { 4,8,12,16,20 } },
                  { mod = xi.mod.HASTE_ABILITY, val = { 200,400,600,800,1000 } },
              } } })

    local t4 = isNonPhys
        and H.node(4, 2, 'bb_t4_c2', 'Black Belt Apex', 3, '+12..36% WSD, +10..30% SC Dmg & NextWS +100..300 TP',
            function(r) return string.format('+%d%% WSD, +%d%% SC, NextWS +%d TP', r * 12, r * 10, r * 100) end,
            { wsd = { 12,24,36 }, scBonus = { 10,20,30 }, nextWs = { tp = { 100,200,300 }, dur = 12 } })
        or H.node(4, 2, 'bb_t4_c2', 'Black Belt Apex', 3, '+10..30% WSD, +6..18% Crit Dmg & NextWS +100..300 TP',
            function(r) return string.format('+%d%% WSD, +%d%% CrDmg, NextWS +%d TP', r * 10, r * 6, r * 100) end,
            { wsd = { 10,20,30 }, critDmg = { 6,12,18 }, nextWs = { tp = { 100,200,300 }, dur = 12 } })

    return assembleSpecTree(wsId, archetype, baseNodes, 'blackbelt', { t1, t2, t3, t4 }, 'str')
end

-- 7) Berserker / DPS (Preserves full bespoke baseNodes, enriches empty Col 3 per WS archetype/element/aftermath)
local function buildBerserkerSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local out = {}
    local grid = { {}, {}, {}, {} }

    for _, raw in ipairs(baseNodes or {}) do
        local n = copyTable(raw)
        if isNonPhys then
            n = sanitizeNodeForNonPhysical(n, wsId, wsKind)
        end
        if grid[n.tier] and grid[n.tier][n.col] == nil then
            grid[n.tier][n.col] = n
            table.insert(out, n)
        end
    end

    if grid[1][1] == nil then
        grid[1][1] = makeScalingT1Col1(wsId, nil, isNonPhys)
        table.insert(out, grid[1][1])
    end
    if grid[1][2] == nil then
        grid[1][2] = isMagDmg
            and H.node(1, 2, 'zk_t1_c2', 'Arcane Surge', 7, '+8..56 MAB & +7..49 MACC',
                function(r) return string.format('+%d MAB, +%d MACC', r * 8, r * 7) end,
                { matt = { 8,16,24,32,40,48,56 }, macc = { 7,14,21,28,35,42,49 } })
            or (isNonPhys
                and H.node(1, 2, 'zk_t1_c2', 'Resonant Surge', 7, '+5..35% WSD & +45..315 TP Bonus',
                    function(r) return string.format('+%d%% WSD, +%d TP', r * 5, r * 45) end,
                    { wsd = { 5,10,15,20,25,30,35 }, tpBonus = { 45,90,135,180,225,270,315 } })
                or H.node(1, 2, 'zk_t1_c2', 'Fury Opener', 7, '+7..49% WS Atk & +4..28% WSD',
                    function(r) return string.format('+%d%% Atk, +%d%% WSD', r * 7, r * 4) end,
                    { atkPct = { 7,14,21,28,35,42,49 }, wsd = { 4,8,12,16,20,24,28 } }))
        table.insert(out, grid[1][2])
    end
    if grid[1][3] == nil then
        grid[1][3] = makePrimaryWscNode(wsId, 1, 3, 'zk_t1_c3', isNonPhys, nil)
        table.insert(out, grid[1][3])
    end

    if grid[2][3] == nil then
        grid[2][3] = makeTailoredCol3T2(wsId, archetype, isNonPhys, isMagDmg, 'berserker')
        table.insert(out, grid[2][3])
    end
    if grid[3][3] == nil then
        grid[3][3] = makeTailoredCol3T3(wsId, archetype, isNonPhys, isMagDmg, 'berserker')
        table.insert(out, grid[3][3])
    end
    if grid[4][3] == nil then
        grid[4][3] = makeTailoredCol3T4(wsId, archetype, isNonPhys, isMagDmg, 'berserker')
        table.insert(out, grid[4][3])
    end

    return out
end

function H.regSpec(wsId, archetype, specNodes, opts)
    opts = opts or {}
    local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
    local cleaned = {}
    for specCat, list in pairs(specNodes or {}) do
        cleaned[specCat] = {}
        for _, n in ipairs(list or {}) do
            local nn = isNonPhys and sanitizeNodeForNonPhysical(n, wsId, wsKind) or n
            if specCat == 'chiweaver' then
                nn = stripMpAndRefreshForChiWeaver(nn, wsKind)
            end
            table.insert(cleaned[specCat], nn)
        end
    end
    talents.registerCustomWS(wsId,
    {
        archetype   = archetype,
        useBaseline = opts.useBaseline == true,
        specNodes   = cleaned,
        nodes       = cleaned.berserker or cleaned.blackbelt or cleaned.tank or {},
    })
end

local specProfiles = nil
local function getSpecProfiles()
    if specProfiles == nil then
        specProfiles = require('modules/custom/lua/overlords_ws_spec_profiles')
    end
    return specProfiles
end

function H.reg(wsId, archetype, nodes)
    local P = getSpecProfiles()
    local specNodes = P.buildAllSpecTrees(wsId, archetype, nodes, { useBaseline = false })
    H.regSpec(wsId, archetype, specNodes, { useBaseline = false })
end

function H.regBaseline(wsId, archetype, nodes)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local skill = ws and ws.skill or 0

    -- Throwing (#241-#252) preserves Dancer Bladewheel's dedicated 3x4 tree and synthesizes the other 12 specs
    if skill == xi.skill.THROWING then
        local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
        local cleaned = {}
        for _, n in ipairs(nodes or {}) do
            table.insert(cleaned, isNonPhys and sanitizeNodeForNonPhysical(n, wsId, wsKind) or n)
        end
        local P = getSpecProfiles()
        local specNodes = P.buildAllSpecTrees(wsId, archetype, cleaned, { useBaseline = true, preserveBladewheel = true })
        H.regSpec(wsId, archetype, specNodes, { useBaseline = true })
        return
    end

    -- Club & Staff: Generate 13 distinct 3x4 spec trees tailored to each spec + WS DNA
    local P = getSpecProfiles()
    local specNodes = P.buildAllSpecTrees(wsId, archetype, nodes, { useBaseline = false })
    H.regSpec(wsId, archetype, specNodes, { useBaseline = false })
end

-- Upgrade H2H (#1-#15) trees registered in overlords_ws_talents.lua to full 13-spec 3x4 trees
function H.upgradeExistingCustomRange(minWsId, maxWsId)
    local customMap = talents._customTrees or {}
    for wsId = minWsId, maxWsId do
        local cur = customMap[wsId]
        if cur ~= nil and cur.specNodes == nil and cur.nodes ~= nil then
            H.reg(wsId, cur.archetype or 'heavy', cur.nodes)
        end
    end
end

-- Common bespoke building blocks with exact data-driven tooltips + effects
function H.echo(key, name, wsdStep, tpStep)
    local wStep = wsdStep or 5
    local tStep = tpStep or 60
    local wTbl = { wStep, wStep * 2, wStep * 3, wStep * 4, wStep * 5 }
    local tTbl = { tStep, tStep * 2, tStep * 3, tStep * 4, tStep * 5 }
    return H.node(3, 2, key or 'aftermath_echo', name or 'Relic Echo', 5,
        string.format('+%d..%d%% WSD & +%d..%d TP Bonus', wStep, wStep * 5, tStep, tStep * 5),
        function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * wStep, r * tStep) end,
        { wsd = wTbl, tpBonus = tTbl })
end

function H.atkAcc(tier, col, key, name, atkStep, accStep, req)
    local aTbl, cTbl = {}, {}
    for i = 1, 5 do
        aTbl[i] = i * atkStep
        cTbl[i] = i * accStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% WS Atk & +%d..%d Acc', atkStep, atkStep * 5, accStep, accStep * 5),
        function(r) return string.format('+%d%% WS Atk, +%d Acc', r * atkStep, r * accStep) end,
        { atkPct = aTbl, acc = cTbl }, req)
end

function H.wsdAcc(tier, col, key, name, wsdStep, accStep, req)
    local wTbl, cTbl = {}, {}
    for i = 1, 5 do
        wTbl[i] = i * wsdStep
        cTbl[i] = i * accStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% WSD & +%d..%d Acc', wsdStep, wsdStep * 5, accStep, accStep * 5),
        function(r) return string.format('+%d%% WSD, +%d Acc', r * wsdStep, r * accStep) end,
        { wsd = wTbl, acc = cTbl }, req)
end

function H.critMast(tier, col, key, name, crStep, cdStep)
    local crTbl, cdTbl = {}, {}
    for i = 1, 5 do
        crTbl[i] = i * crStep
        cdTbl[i] = i * cdStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% Crit & +%d..%d%% Crit Dmg', crStep, crStep * 5, cdStep, cdStep * 5),
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * crStep, r * cdStep) end,
        { crit = crTbl, critDmg = cdTbl })
end

function H.mabMacc(tier, col, key, name, mabStep, maccStep, wsdStep)
    local mTbl, aTbl, wTbl = {}, {}, wsdStep and {} or nil
    for i = 1, 5 do
        mTbl[i] = i * mabStep
        aTbl[i] = i * maccStep
        if wTbl then
            wTbl[i] = i * wsdStep
        end
    end
    local zero = wTbl and string.format('+%d..%d MAB/MACC & +%d..%d%% WSD', mabStep, mabStep * 5, wsdStep, wsdStep * 5)
        or string.format('+%d..%d MAB & +%d..%d MACC', mabStep, mabStep * 5, maccStep, maccStep * 5)
    return H.node(tier, col, key, name, 5, zero,
        function(r)
            if wTbl then
                return string.format('+%d MAB, +%d MACC, +%d%% WSD', r * mabStep, r * maccStep, r * wsdStep)
            end
            return string.format('+%d MAB, +%d MACC', r * mabStep, r * maccStep)
        end,
        { matt = mTbl, macc = aTbl, wsd = wTbl })
end

function H.rangedAtkAcc(tier, col, key, name, atkStep, raccStep)
    local aTbl, rTbl = {}, {}
    for i = 1, 5 do
        aTbl[i] = i * atkStep
        rTbl[i] = i * raccStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% R.Atk & +%d..%d R.Acc', atkStep, atkStep * 5, raccStep, raccStep * 5),
        function(r) return string.format('+%d%% R.Atk, +%d R.Acc', r * atkStep, r * raccStep) end,
        { atkPct = aTbl, racc = rTbl })
end

function H.multiFtp(tier, col, key, name, wsdStep, atkStep)
    local wTbl = wsdStep and {} or nil
    local aTbl = atkStep and {} or nil
    for i = 1, 4 do
        if wTbl then wTbl[i] = i * wsdStep end
        if aTbl then aTbl[i] = i * atkStep end
    end
    if wTbl then wTbl[5] = 4 * wsdStep end
    if aTbl then aTbl[5] = 4 * atkStep end
    local label = wTbl and string.format('+%d%% WSD', wsdStep * 4) or string.format('+%d%% Atk', atkStep * 4)
    return H.node(tier, col, key, name, 5,
        string.format('R1-4:%s | R5:fTP ALL Hits!', label),
        function(r)
            if r >= 5 then
                return string.format('fTP ALL HITS + %s (MAX)', label)
            end
            return wTbl and string.format('+%d%% WSD (R5:fTP all hits)', r * wsdStep)
                or string.format('+%d%% Atk (R5:fTP all hits)', r * atkStep)
        end,
        { wsd = wTbl, atkPct = aTbl, multiHitfTPAt = 5 })
end

function H.elemFollow(tier, col, key, name, ele, dmgName, pctStep, packScale)
    local pTbl = {}
    for i = 1, 5 do pTbl[i] = i * pctStep end
    return H.node(tier, col, key, name, 5,
        string.format('%s follow-up (%d..%d%%%s)', dmgName, pctStep, pctStep * 5, packScale and ' +pack' or ''),
        function(r)
            return string.format('%s +%d%% follow-up%s', dmgName, r * pctStep, packScale and ' (+pack)' or '')
        end,
        { elemFollow = { ele = ele, pct = pTbl, scaleWithPack = packScale } })
end

function H.stanceNode(tier, col, key, name, maxRank, stanceLabel, effects, opts)
    opts = opts or {}
    local wsd = opts.wsd
    local atk = opts.atkPct
    local cr  = opts.crit
    local cd  = opts.critDmg
    local tp  = opts.tpBonus
    local mab = opts.matt
    local mac = opts.macc
    local di  = opts.defIgnore
    local schSpec = opts.schSpec
    return H.node(tier, col, key, name, maxRank,
        opts.zeroDesc or string.format('%s: +%s', stanceLabel, opts.summary or 'Stance bonus'),
        opts.rankDesc or function(r)
            local parts = {}
            if wsd then table.insert(parts, string.format('+%d%% WSD', pick(wsd, r))) end
            if atk then table.insert(parts, string.format('+%d%% Atk', pick(atk, r))) end
            if cr  then table.insert(parts, string.format('+%d%% Crit', pick(cr, r))) end
            if cd  then table.insert(parts, string.format('+%d%% CrDmg', pick(cd, r))) end
            if mab then table.insert(parts, string.format('+%d MAB', pick(mab, r))) end
            if mac then table.insert(parts, string.format('+%d MACC', pick(mac, r))) end
            if di  then table.insert(parts, string.format('-%d%% DEF', math.floor(pick(di, r) * 100 + 0.5))) end
            if tp  then table.insert(parts, string.format('+%d TP', pick(tp, r))) end
            return string.format('%s: %s', stanceLabel, table.concat(parts, ', '))
        end,
        {
            stance =
            {
                effects   = effects,
                schSpec   = schSpec,
                jobSpec   = opts.jobSpec,
                petAlive  = opts.petAlive,
                wsd       = wsd,
                atkPct    = atk,
                crit      = cr,
                tpBonus   = tp,
                matt      = mab,
                macc      = mac,
                critDmg   = cd,
                defIgnore = di,
                ftpAdd    = opts.ftpAdd,
            },
        }, opts.requires)
end

function H.hits(tier, col, key, name, hitSeq, atkStep, accStep, zeroDesc)
    local mr = #hitSeq
    local aTbl = atkStep and {} or nil
    local cTbl = accStep and {} or nil
    for i = 1, mr do
        if aTbl then aTbl[i] = i * atkStep end
        if cTbl then cTbl[i] = i * accStep end
    end
    local targetH = hitSeq[mr]
    local zd = zeroDesc or string.format('Rebuild 1->%d Hits%s%s', targetH,
        atkStep and string.format(' & +%d..%d%% Atk', atkStep, atkStep * mr) or '',
        accStep and string.format(' & +%d..%d Acc', accStep, accStep * mr) or '')
    return H.node(tier, col, key, name, mr, zd,
        function(r)
            local h = hitSeq[r] or targetH
            local p = { string.format('Hits: 1->%d', h) }
            if aTbl then table.insert(p, string.format('+%d%% Atk', aTbl[r])) end
            if cTbl then table.insert(p, string.format('+%d Acc', cTbl[r])) end
            return table.concat(p, ', ')
        end,
        { hits = hitSeq, atkPct = aTbl, acc = cTbl })
end

function H.cap(key, name, zeroDesc, rankDesc, effect, req)
    return H.node(4, 1, key or 'capstone', name, 3, zeroDesc, rankDesc, effect, req or { key = 'ftp', rank = 2 })
end

function H.mast(key, name, maxRank, zeroDesc, rankDesc, effect)
    if type(maxRank) == 'string' then
        return H.node(4, 2, key, name, 5, maxRank, zeroDesc, rankDesc)
    end
    return H.node(4, 2, key, name, maxRank or 5, zeroDesc, rankDesc, effect)
end

function H.utilFtp(name, zeroDesc, rankDesc, effect)
    return H.node(1, 1, 'ftp', name, 6, zeroDesc, rankDesc, effect)
end

H.pick = pick
H.buildTankSpecNodes       = buildTankSpecNodes
H.buildSpellbladeSpecNodes = buildSpellbladeSpecNodes
H.buildHealerSpecNodes     = buildHealerSpecNodes
H.buildChiWeaverSpecNodes  = buildChiWeaverSpecNodes
H.buildCommanderSpecNodes  = buildCommanderSpecNodes
H.buildBlackBeltSpecNodes  = buildBlackBeltSpecNodes
H.buildBerserkerSpecNodes  = buildBerserkerSpecNodes

return H
