-----------------------------------
-- OverlordsXI Bespoke WS Trees: Great Sword (#48-#61)
-- Full 5-Spec (tank, spellblade, healer, commander, berserker) 3-Column Trees
-- (+ Col 4 Skillchain Augments = 16 nodes per spec view).
-- Strictly respects wsType ('magic' on #50 Frostbite, #51 Freezebite, #58 Herculean Slash
-- uses ZERO physical Attack, Accuracy, Crit, DEF Ignore, or Multi-Hit).
-----------------------------------
local H = require('modules/custom/lua/overlords_ws_tree_helpers')
local regSpec, ftp, node = H.regSpec, H.ftp, H.node
local atkAcc, mabMacc = H.atkAcc, H.mabMacc
local elemFollow, stance, echo = H.elemFollow, H.stanceNode, H.echo

local TANK_EFF = { xi.effect.VALLATION, xi.effect.VALIANCE, xi.effect.SWORDPLAY, xi.effect.BATTUTA, xi.effect.PFLUG, xi.effect.DEFENDER, xi.effect.SENTINEL }
local SB_EFF   = { xi.effect.SWORDPLAY, xi.effect.VALLATION, xi.effect.VALIANCE, xi.effect.IGNIS, xi.effect.GELUS, xi.effect.FLABRA, xi.effect.TELLUS, xi.effect.SULPOR, xi.effect.UNDA, xi.effect.LUX, xi.effect.TENEBRAE }
local HL_EFF   = { xi.effect.VALIANCE, xi.effect.VALLATION, xi.effect.SWORDPLAY, xi.effect.AFFLATUS_SOLACE, xi.effect.LIGHT_ARTS }
local CMD_EFF  = { xi.effect.WARCRY, xi.effect.BERSERK, xi.effect.RESTRAINT, xi.effect.AGGRESSOR, xi.effect.RETALIATION }
local ZERK_EFF = { xi.effect.BERSERK, xi.effect.BLOOD_RAGE, xi.effect.LAST_RESORT, xi.effect.SOULEATER, xi.effect.RESTRAINT }

-- Helper to register a Great Sword WS with bespoke Berserker nodes and tailored Tank/Spellblade/Healer/Commander overrides
local function regGS(wsId, archetype, zerkNodes, customSpecs)
    customSpecs = customSpecs or {}
    local specNodes =
    {
        berserker  = customSpecs.berserker  or H.buildBerserkerSpecNodes(wsId, archetype, zerkNodes),
        tank       = customSpecs.tank       or H.buildTankSpecNodes(wsId, archetype, zerkNodes),
        spellblade = customSpecs.spellblade or H.buildSpellbladeSpecNodes(wsId, archetype, zerkNodes),
        healer     = customSpecs.healer     or H.buildHealerSpecNodes(wsId, archetype, zerkNodes),
        commander  = customSpecs.commander  or H.buildCommanderSpecNodes(wsId, archetype, zerkNodes),
    }
    regSpec(wsId, archetype, specNodes)
end

-- Helper to replace specific (tier, col) entries in a generated 12-node spec list
local function withCustomNodes(baseList, overrides)
    local out = {}
    for _, n in ipairs(baseList) do
        table.insert(out, n)
    end
    for _, ov in ipairs(overrides or {}) do
        local replaced = false
        for idx, cur in ipairs(out) do
            if cur.tier == ov.tier and cur.col == ov.col then
                out[idx] = ov
                replaced = true
                break
            end
        end
        if not replaced then
            table.insert(out, ov)
        end
    end
    return out
end

---------------------------------------------------------------------------
-- #48 Hard Slash (Physical Opener & Primer)
---------------------------------------------------------------------------
local zerk48 = {
    ftp({ 1.40, 2.40, 3.50 }),
    node(1, 2, 'hs_prime', 'Momentum Strike', 7, '+6..42% Atk & primes Next WS (+4..28% WSD)',
        function(r) return string.format('+%d%% Atk, NextWS +%d%% WSD', r * 6, r * 4) end,
        { atkPct = { 6,12,18,24,30,36,42 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 12 } }),
    node(1, 3, 'wsc_str', 'Heavy STR', 7, 'STR +14..100% WSC & +5..35 Acc',
        function(r) return string.format('STR +%d%% WSC, +%d Acc', ({14,28,42,56,70,85,100})[r], r * 5) end,
        { wsc = { str = { .14,.28,.42,.56,.70,.85,1.00 } }, acc = { 5,10,15,20,25,30,35 } }),
    atkAcc(2, 1, 'hs_force', 'Crushing Weight', 10, 10),
    node(2, 2, 'hs_flow', 'Follow-Through', 5, 'Next WS +60..300 TP Bonus & +6..30 Store TP',
        function(r) return string.format('NextWS +%d TP, +%d STP (12s)', r * 60, r * 6) end,
        { storeTp = { 6,12,18,24,30 }, nextWs = { tp = { 60,120,180,240,300 }, dur = 12 } }),
    node(2, 3, 'hs_sunder', 'Splitting Edge', 5, 'Ignores 6..30% DEF & +4..20% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 6, r * 4) end,
        { defIgnore = { .06,.12,.18,.24,.30 }, wsd = { 4,8,12,16,20 } }),
    node(3, 1, 'hs_def', 'Sunder Armor', 5, 'Target DEF -4..20% (45s) & +5..25% WSD',
        function(r) return string.format('Target -%d%% DEF, +%d%% WSD', r * 4, r * 5) end,
        { wsd = { 5,10,15,20,25 }, targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = { 4,8,12,16,20 }, duration = 45 }} }),
    stance(3, 2, 'hs_st', 'Fury Stance', 5, 'Berserk/LR/Souleater', ZERK_EFF,
        { wsd = { 7,14,21,28,35 }, atkPct = { 6,12,18,24,30 }, zeroDesc = 'Berserk/LR/Souleater: +7..35% WSD & +Atk' }),
    node(3, 3, 'hs_crit', 'Rending Tempo', 5, '+5..25% Crit Rate & +6..30% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 6) end,
        { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 } }),
    node(4, 1, 'capstone', 'Iron Momentum', 3, '1->2 Hits, +12/22/32% WSD & +10..30% DEF Ign',
        function(r) return string.format('2h, +%d%% WSD, %d%% DEF Ign', ({12,22,32})[r], r * 10) end,
        { hits = { 2,2,2 }, wsd = { 12,22,32 }, defIgnore = { .10,.20,.30 } }),
    node(4, 2, 'hs_cap2', 'Relentless Opener', 3, 'Next WS +12..36% WSD & +100..300 TP Bonus',
        function(r) return string.format('NextWS +%d%% WSD, +%d TP', r * 12, r * 100) end,
        { nextWs = { wsd = { 12,24,36 }, tp = { 100,200,300 }, dur = 15 } }),
    node(4, 3, 'hs_mast', 'Hard Mastery', 5, '+6..30% WSD & +5..25% Crit',
        function(r) return string.format('+%d%% WSD, +%d%% Crit', r * 6, r * 5) end,
        { wsd = { 6,12,18,24,30 }, crit = { 5,10,15,20,25 } }),
}
regGS(48, 'utility', zerk48)

---------------------------------------------------------------------------
-- #49 Power Slash (Physical Crit Bruiser, STR/VIT)
---------------------------------------------------------------------------
local zerk49 = {
    ftp({ 1.25, 1.85, 2.50 }),
    node(1, 2, 'ps_edge', 'Brutal Crit Edge', 7, '+4..25% Crit Rate & +6..42% WS Atk',
        function(r) return string.format('+%d%% Crit, +%d%% Atk', ({4,8,11,15,18,22,25})[r], r * 6) end,
        { crit = { 4,8,11,15,18,22,25 }, atkPct = { 6,12,18,24,30,36,42 } }),
    node(1, 3, 'ps_wsc', 'Stalwart STR/VIT', 7, 'STR/VIT +8..60% WSC & +5..35 Acc',
        function(r) local v = ({8,16,24,32,42,51,60})[r]; return string.format('STR/VIT +%d%% WSC, +%d Acc', v, r * 5) end,
        { wsc = { str = { .08,.16,.24,.32,.42,.51,.60 }, vit = { .08,.16,.24,.32,.42,.51,.60 } }, acc = { 5,10,15,20,25,30,35 } }),
    node(2, 1, 'ps_crit', 'TP Crit Curve', 5, 'TP Crit Rate: up to +18..50% at 3000 TP',
        function(r) local t = ({{9,14,18},{12,19,26},{15,24,34},{18,29,42},{22,35,50}})[r]; return string.format('Crit +%d/%d/%d%%', t[1], t[2], t[3]) end,
        { critCurve = {{.09,.14,.18},{.12,.19,.26},{.15,.24,.34},{.18,.29,.42},{.22,.35,.50}} }),
    atkAcc(2, 2, 'ps_force', 'Crushing Force', 10, 10),
    node(2, 3, 'ps_pierce', 'Vital Sundering', 5, 'Ignores 6..30% DEF & +4..20% Crit Dmg',
        function(r) return string.format('Ignores %d%% DEF, +%d%% CrDmg', r * 6, r * 4) end,
        { defIgnore = { .06,.12,.18,.24,.30 }, critDmg = { 4,8,12,16,20 } }),
    node(3, 1, 'ps_cd', 'Sundering Crit', 5, '+9..45% Critical Hit Damage on WS',
        function(r) return string.format('+%d%% WS Crit Damage', r * 9) end,
        { critDmg = { 9,18,27,36,45 } }),
    stance(3, 2, 'ps_st', 'Fury Stance', 5, 'Berserk/LR/BloodRage', ZERK_EFF,
        { wsd = { 8,16,24,32,40 }, critDmg = { 5,10,15,20,25 }, zeroDesc = 'Berserk/LR/BloodRage: +8..40% WSD & +CrDmg' }),
    node(3, 3, 'ps_leech', 'Savage Reaping', 5, 'Drains 6..30% WS dmg as HP & +5..25% WSD',
        function(r) return string.format('%d%% HP Drain, +%d%% WSD', r * 6, r * 5) end,
        { hpDrain = { 6,12,18,24,30 }, wsd = { 5,10,15,20,25 } }),
    node(4, 1, 'capstone', 'Absolute Power', 3, '1->2 Hits, fTP ALL & +12/24/36% WSD',
        function(r) return string.format('2 Hits, fTP ALL, +%d%% WSD', r * 12) end,
        { hits = { 2,2,2 }, wsd = { 12,24,36 }, multiHitfTPAt = 1 }),
    node(4, 2, 'ps_cap2', 'Executioner Edge', 3, '+10..30% Crit Dmg & +8..24% DEF Ignore',
        function(r) return string.format('+%d%% Crit Dmg, %d%% DEF Ign', r * 10, r * 8) end,
        { critDmg = { 10,20,30 }, defIgnore = { .08,.16,.24 } }),
    node(4, 3, 'ps_mast', 'Power Mastery', 5, '+6..30% WSD & +6..30% Crit',
        function(r) return string.format('+%d%% WSD, +%d%% Crit', r * 6, r * 6) end,
        { wsd = { 6,12,18,24,30 }, crit = { 6,12,18,24,30 } }),
}
regGS(49, 'crit', zerk49)

---------------------------------------------------------------------------
-- #50 Frostbite (PURE MAGIC Ice Nuker — ZERO physical stats in any spec!)
---------------------------------------------------------------------------
local zerk50 = {
    ftp({ 1.40, 2.90, 4.60 }),
    node(1, 2, 'fb50_ice', 'Glacial Blade', 7, '+8..56 MAB, +7..49 MACC & Enblizzard (20s)',
        function(r) return string.format('+%d MAB, +%d MACC, Enblizzard', r * 8, r * 7) end,
        { matt = { 8,16,24,32,40,48,56 }, macc = { 7,14,21,28,35,42,49 },
          statusBuffs = {{ effect = xi.effect.ENBLIZZARD, power = { 14,20,26,34,42,50,60 }, duration = 20 }} }),
    node(1, 3, 'fb50_wsc', 'Rime STR/INT', 7, 'STR/INT +6..45% WSC & +4..28% WSD',
        function(r) local v = ({6,12,18,24,30,38,45})[r]; return string.format('STR/INT +%d%% WSC, +%d%% WSD', v, r * 4) end,
        { wsc = { str = { .06,.12,.18,.24,.30,.38,.45 }, int = { .06,.12,.18,.24,.30,.38,.45 } }, wsd = { 4,8,12,16,20,24,28 } }),
    mabMacc(2, 1, 'fb50_arc', 'Frost Arcana', 9, 8, 5),
    stance(2, 2, 'fb50_st', 'Cryo Fury Stance', 5, 'Gelus/Berserk/LR', { xi.effect.GELUS, xi.effect.VALIANCE, xi.effect.VALLATION, xi.effect.LAST_RESORT, xi.effect.BERSERK },
        { wsd = { 8,16,24,32,40 }, matt = { 10,20,30,40,50 }, zeroDesc = 'Gelus/Berserk/LR: +8..40% WSD & +10..50 MAB' }),
    node(2, 3, 'fb50_mdef', 'Frostbite Breach', 5, 'Target -6..30 M.Def & -8..40 M.Eva (45s)',
        function(r) return string.format('Target -%d M.Def, -%d M.Eva', r * 6, r * 8) end,
        { targetDebuffs = {
            { effect = xi.effect.MAGIC_DEF_DOWN, power = { 6,12,18,24,30 }, duration = 45 },
            { effect = xi.effect.MAGIC_EVASION_DOWN, power = { 8,16,24,32,40 }, duration = 45 },
        } }),
    elemFollow(3, 1, 'fb50_ice2', 'Hoarfrost Burst', 'ICE', 'Ice', 11, false),
    node(3, 2, 'fb50_tp', 'Glacial Surge', 5, '+70..350 TP Bonus & +6..30 MACC',
        function(r) return string.format('+%d TP Bonus, +%d MACC', r * 70, r * 6) end,
        { tpBonus = { 70,140,210,280,350 }, macc = { 6,12,18,24,30 } }),
    node(3, 3, 'fb50_sc', 'Cryo Resonance', 5, '+8..40% SC Dmg & +8..40 MAB',
        function(r) return string.format('+%d%% SC Dmg, +%d MAB', r * 8, r * 8) end,
        { scBonus = { 8,16,24,32,40 }, matt = { 8,16,24,32,40 } }),
    node(4, 1, 'capstone', 'Absolute Zero', 3, '+16/30/45% WSD & +15/30/45 MAB',
        function(r) return string.format('+%d%% WSD, +%d MAB', ({16,30,45})[r], r * 15) end,
        { wsd = { 16,30,45 }, matt = { 15,30,45 } }),
    node(4, 2, 'fb50_cap2', 'Winter Cataclysm', 3, '+0.5..1.5 fTP & +12..36% SC Dmg',
        function(r) return string.format('+%.1f fTP, +%d%% SC Dmg', r * 0.5, r * 12) end,
        { ftpAdd = { 0.5,1.0,1.5 }, scBonus = { 12,24,36 } }),
    node(4, 3, 'fb50_mast', 'Frost Mastery', 5, '+6..30% WSD & +8..40 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 6, r * 8) end,
        { wsd = { 6,12,18,24,30 }, macc = { 8,16,24,32,40 } }),
}
regGS(50, 'magic', zerk50)

---------------------------------------------------------------------------
-- #51 Freezebite (PURE MAGIC Superior Ice Nuke + Paralysis — ZERO physical stats!)
---------------------------------------------------------------------------
local zerk51 = {
    ftp({ 1.50, 3.25, 5.50 }),
    node(1, 2, 'fr_ice', 'Permafrost Edge', 7, '+9..63 MAB, +7..49 MACC & Enblizzard (20s)',
        function(r) return string.format('+%d MAB, +%d MACC, Enblizzard', r * 9, r * 7) end,
        { matt = { 9,18,27,36,45,54,63 }, macc = { 7,14,21,28,35,42,49 },
          statusBuffs = {{ effect = xi.effect.ENBLIZZARD, power = { 16,24,32,40,48,58,68 }, duration = 20 }} }),
    node(1, 3, 'fr_wsc', 'Cryo STR/INT', 7, 'STR/INT +6..45% WSC & +5..35% WSD',
        function(r) local v = ({6,12,18,24,30,38,45})[r]; return string.format('STR/INT +%d%% WSC, +%d%% WSD', v, r * 5) end,
        { wsc = { str = { .06,.12,.18,.24,.30,.38,.45 }, int = { .06,.12,.18,.24,.30,.38,.45 } }, wsd = { 5,10,15,20,25,30,35 } }),
    mabMacc(2, 1, 'fr_arc', 'Cryo Arcana', 10, 8, 5),
    stance(2, 2, 'fr_st', 'Rune Affinity', 5, 'Gelus/Battuta/LR', { xi.effect.GELUS, xi.effect.BATTUTA, xi.effect.VALIANCE, xi.effect.LAST_RESORT, xi.effect.BERSERK },
        { wsd = { 9,18,27,36,45 }, matt = { 12,24,36,48,60 }, zeroDesc = 'Gelus/Battuta/LR: +9..45% WSD & +12..60 MAB' }),
    node(2, 3, 'fr_shred', 'Subzero Exposure', 5, 'Target -7..35 M.Def & -8..40 M.Eva (45s)',
        function(r) return string.format('Target -%d M.Def, -%d M.Eva', r * 7, r * 8) end,
        { targetDebuffs = {
            { effect = xi.effect.MAGIC_DEF_DOWN, power = { 7,14,21,28,35 }, duration = 45 },
            { effect = xi.effect.MAGIC_EVASION_DOWN, power = { 8,16,24,32,40 }, duration = 45 },
        } }),
    elemFollow(3, 1, 'fr_ice2', 'Glacier Shatter', 'ICE', 'Ice', 12, false),
    node(3, 2, 'fr_para', 'Numbing Chill', 5, 'Inflicts Paralysis (13..25%) & +60..300 TP Bonus',
        function(r) return string.format('Paralyze %d%%, +%d TP Bonus', 10 + r * 3, r * 60) end,
        { tpBonus = { 60,120,180,240,300 }, targetDebuffs = {{ effect = xi.effect.PARALYSIS, power = { 13,16,19,22,25 }, duration = 45 }} }),
    node(3, 3, 'fr_sc', 'Deep Freeze Chain', 5, '+9..45% SC Dmg & +6..30% MP Drain',
        function(r) return string.format('+%d%% SC Dmg, %d%% MP Drain', r * 9, r * 6) end,
        { scBonus = { 9,18,27,36,45 }, mpDrain = { 6,12,18,24,30 } }),
    node(4, 1, 'capstone', 'Glacial Apex', 3, '+18/32/48% WSD & +15/30/45 MAB',
        function(r) return string.format('+%d%% WSD, +%d MAB', ({18,32,48})[r], r * 15) end,
        { wsd = { 18,32,48 }, matt = { 15,30,45 } }),
    node(4, 2, 'fr_cap2', 'Permafrost Sovereign', 3, '+0.6..1.8 fTP & +15..45% SC Dmg',
        function(r) return string.format('+%.1f fTP, +%d%% SC Dmg', r * 0.6, r * 15) end,
        { ftpAdd = { 0.6,1.2,1.8 }, scBonus = { 15,30,45 } }),
    node(4, 3, 'fr_mast', 'Freeze Mastery', 5, '+6..30% WSD & +8..40 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 6, r * 8) end,
        { wsd = { 6,12,18,24,30 }, macc = { 8,16,24,32,40 } }),
}
regGS(51, 'magic', zerk51)

---------------------------------------------------------------------------
-- #52 Shockwave (AoE Sleep Pack Controller + Cleave)
---------------------------------------------------------------------------
local zerk52 = {
    ftp({ 1.15, 1.50, 1.90 }, { suffixFn = function(r) return ' +Sleep' .. (r >= 6 and ' (MAX)' or '') end,
        effect = { nativeDebuff = { 1,2,3,4,5,6 } } }),
    node(1, 2, 'sw_pack', 'Quake Pack Control', 7, '+6..42% WSD/extra mob & +12..84 MACC',
        function(r) return string.format('+%d%% WSD/mob, +%d MACC', r * 6, r * 12) end,
        { packWsdPerMob = { 6,12,18,24,30,36,42 }, macc = { 12,24,36,48,60,72,84 }, nativeDebuff = true }),
    node(1, 3, 'sw_wsc', 'Resonant STR/MND', 7, 'STR/MND +5..35% WSC & +5..35 Acc',
        function(r) return string.format('STR/MND +%d%% WSC, +%d Acc', r * 5, r * 5) end,
        { wsc = { str = { .05,.10,.15,.20,.25,.30,.35 }, mnd = { .05,.10,.15,.20,.25,.30,.35 } }, acc = { 5,10,15,20,25,30,35 } }),
    node(2, 1, 'sw_enm', 'Tremor Sundering', 5, 'Target -5..25% DEF & +6..30% WSD',
        function(r) return string.format('Target -%d%% DEF, +%d%% WSD', r * 5, r * 6) end,
        { wsd = { 6,12,18,24,30 }, targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = { 5,10,15,20,25 }, duration = 45 }} }),
    atkAcc(2, 2, 'sw_force', 'Sweeping Force', 10, 10),
    node(2, 3, 'sw_pierce', 'Shockwave Breach', 5, 'Ignores 6..30% DEF & +8..40 MACC',
        function(r) return string.format('Ignores %d%% DEF, +%d MACC', r * 6, r * 8) end,
        { defIgnore = { .06,.12,.18,.24,.30 }, macc = { 8,16,24,32,40 } }),
    elemFollow(3, 1, 'sw_dark', 'Dark Shockwave', 'DARK', 'Dark', 12, true),
    stance(3, 2, 'sw_st', 'Pack Fury Stance', 5, 'Berserk/LR/Warcry', ZERK_EFF,
        { wsd = { 8,16,24,32,40 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'Berserk/LR: +8..40% WSD & +8..40% Atk' }),
    node(3, 3, 'sw_drain', 'Seismic Leech', 5, 'Drains 6..30% WS dmg as HP & +5..25% Crit',
        function(r) return string.format('%d%% HP Drain, +%d%% Crit', r * 6, r * 5) end,
        { hpDrain = { 6,12,18,24,30 }, crit = { 5,10,15,20,25 } }),
    node(4, 1, 'capstone', 'Cataclysmic Wave', 3, '1->2h, +12/22/32% WSD & AoE -20..30% Atk',
        function(r) return string.format('2h, +%d%% WSD, -%d%% Atk', ({12,22,32})[r], 15 + r * 5) end,
        { hits = { 2,2,2 }, wsd = { 12,22,32 }, targetDebuffs = {{ effect = xi.effect.ATTACK_DOWN, power = { 20,25,30 }, duration = 45 }} }),
    node(4, 2, 'sw_cap2', 'Pack Annihilator', 3, '+0.5..1.5 fTP & +10..30% WSD',
        function(r) return string.format('+%.1f fTP, +%d%% WSD', r * 0.5, r * 10) end,
        { ftpAdd = { 0.5,1.0,1.5 }, wsd = { 10,20,30 } }),
    node(4, 3, 'sw_mast', 'Wave Mastery', 5, '+6..30% WSD & +10..50 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 6, r * 10) end,
        { wsd = { 6,12,18,24,30 }, macc = { 10,20,30,40,50 } }),
}
regGS(52, 'utility', zerk52)

---------------------------------------------------------------------------
-- #53 Crescent Moon (Lunar Slasher, STR/INT)
---------------------------------------------------------------------------
local zerk53 = {
    ftp({ 1.35, 2.25, 3.40 }),
    node(1, 2, 'cm_edge', 'Lunar Arc', 7, '+6..42% WS Atk & +4..28% WSD',
        function(r) return string.format('+%d%% Atk, +%d%% WSD', r * 6, r * 4) end,
        { atkPct = { 6,12,18,24,30,36,42 }, wsd = { 4,8,12,16,20,24,28 } }),
    node(1, 3, 'cm_wsc', 'Moon STR/INT', 7, 'STR +11..80% / INT +5..35% WSC & +5..35 Acc',
        function(r) return string.format('STR %d%%/INT %d%% WSC, +%d Acc', ({11,22,34,45,56,68,80})[r], r * 5, r * 5) end,
        { wsc = { str = { .11,.22,.34,.45,.56,.68,.80 }, int = { .05,.10,.15,.20,.25,.30,.35 } }, acc = { 5,10,15,20,25,30,35 } }),
    atkAcc(2, 1, 'cm_force', 'Crescent Drive', 10, 10),
    elemFollow(2, 2, 'cm_dark', 'Lunar Shadow', 'DARK', 'Dark', 9, false),
    node(2, 3, 'cm_pierce', 'Lunar Sunder', 5, 'Ignores 6..30% DEF & +4..20% Crit',
        function(r) return string.format('Ignores %d%% DEF, +%d%% Crit', r * 6, r * 4) end,
        { defIgnore = { .06,.12,.18,.24,.30 }, crit = { 4,8,12,16,20 } }),
    stance(3, 1, 'cm_st', 'Night Stance', 5, 'LR/Souleater/Berserk', ZERK_EFF,
        { wsd = { 8,16,24,32,40 }, atkPct = { 6,12,18,24,30 }, zeroDesc = 'LR/Souleater/Berserk: +8..40% WSD & +Atk' }),
    node(3, 2, 'cm_sc', 'Moonlight Chain', 5, '+8..40% SC Dmg & +60..300 TP Bonus',
        function(r) return string.format('+%d%% SC Dmg, +%d TP Bonus', r * 8, r * 60) end,
        { scBonus = { 8,16,24,32,40 }, tpBonus = { 60,120,180,240,300 } }),
    node(3, 3, 'cm_cd', 'Lunar Execution', 5, '+8..40% Crit Dmg & +5..25% WSD',
        function(r) return string.format('+%d%% Crit Dmg, +%d%% WSD', r * 8, r * 5) end,
        { critDmg = { 8,16,24,32,40 }, wsd = { 5,10,15,20,25 } }),
    node(4, 1, 'capstone', 'Full Crescent', 3, '1->2 Hits, fTP ALL & +14/26/38% WSD',
        function(r) return string.format('2 Hits, fTP ALL, +%d%% WSD', ({14,26,38})[r]) end,
        { hits = { 2,2,2 }, wsd = { 14,26,38 }, multiHitfTPAt = 1 }),
    node(4, 2, 'cm_cap2', 'Eclipse Cleaver', 3, '+0.5..1.5 fTP & +10..30% DEF Ignore',
        function(r) return string.format('+%.1f fTP, %d%% DEF Ign', r * 0.5, r * 10) end,
        { ftpAdd = { 0.5,1.0,1.5 }, defIgnore = { .10,.20,.30 } }),
    node(4, 3, 'cm_mast', 'Crescent Mastery', 5, '+6..30% WSD & +10..50 Acc',
        function(r) return string.format('+%d%% WSD, +%d Acc', r * 6, r * 10) end,
        { wsd = { 6,12,18,24,30 }, acc = { 10,20,30,40,50 } }),
}
regGS(53, 'heavy', zerk53)

---------------------------------------------------------------------------
-- #54 Sickle Moon (2-Hit Lunar Cleave, STR/AGI)
---------------------------------------------------------------------------
local zerk54 = {
    ftp({ 1.40, 2.30, 3.30 }),
    node(1, 2, 'sm_hits', 'Twin Crescent', 7, '1->2 Hits (R6: 3h) & +5..35% WS Atk',
        function(r) return string.format('Hits: 1->%d, +%d%% Atk', r >= 6 and 3 or 2, r * 5) end,
        { hits = { 2,2,2,2,2,3,3 }, atkPct = { 5,10,15,20,25,30,35 } }),
    node(1, 3, 'sm_wsc', 'Lunar STR/AGI', 7, 'STR/AGI +8..60% WSC & +5..35 Acc',
        function(r) local v = ({8,16,24,32,42,51,60})[r]; return string.format('STR/AGI +%d%% WSC, +%d Acc', v, r * 5) end,
        { wsc = { str = { .08,.16,.24,.32,.42,.51,.60 }, agi = { .08,.16,.24,.32,.42,.51,.60 } }, acc = { 5,10,15,20,25,30,35 } }),
    atkAcc(2, 1, 'sm_force', 'Sickle Velocity', 10, 10),
    H.multiFtp(2, 2, 'sm_mftp', 'Lunar Cascade', 5, nil),
    node(2, 3, 'sm_crit', 'Keen Sickle', 5, '+5..25% Crit Rate & +6..30% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 6) end,
        { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 } }),
    stance(3, 1, 'sm_st', 'Reaping Stance', 5, 'LR/Berserk/Souleater', ZERK_EFF,
        { wsd = { 8,16,24,32,40 }, crit = { 4,8,12,16,20 }, zeroDesc = 'LR/Berserk/Souleater: +8..40% WSD & +Crit' }),
    node(3, 2, 'sm_def', 'Reaping Cut', 5, 'Ignores 6..30% DEF & +4..20% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 6, r * 4) end,
        { defIgnore = { .06,.12,.18,.24,.30 }, wsd = { 4,8,12,16,20 } }),
    elemFollow(3, 3, 'sm_wind', 'Gale Crescent', 'WIND', 'Wind', 10, false),
    node(4, 1, 'capstone', 'Harvest Moon', 3, '+12/24/36% WSD & +10/20/30% SC Dmg',
        function(r) return string.format('+%d%% WSD, +%d%% SC Dmg', r * 12, r * 10) end,
        { wsd = { 12,24,36 }, scBonus = { 10,20,30 } }),
    node(4, 2, 'sm_cap2', 'Triple Moon', 3, '+1 Bonus Hit & +10..30% Crit Dmg',
        function(r) return string.format('+1 Hit, +%d%% Crit Dmg', r * 10) end,
        { bonusHits = { 1,1,1 }, critDmg = { 10,20,30 } }),
    node(4, 3, 'sm_mast', 'Sickle Mastery', 5, '+6..30% WSD & +6..30% Crit',
        function(r) return string.format('+%d%% WSD, +%d%% Crit', r * 6, r * 6) end,
        { wsd = { 6,12,18,24,30 }, crit = { 6,12,18,24,30 } }),
}
regGS(54, 'multihit', zerk54)

---------------------------------------------------------------------------
-- #55 Spinning Slash (Heavy DEF-Ignore Slasher, STR/INT)
---------------------------------------------------------------------------
local zerk55 = {
    ftp({ 1.85, 2.80, 3.80 }),
    node(1, 2, 'sp_pierce', 'Whirlwind Breach', 7, 'Ignores 7..45% DEF & +6..42% WS Atk',
        function(r) return string.format('Ignores %d%% DEF, +%d%% Atk', ({7,13,19,25,31,38,45})[r], r * 6) end,
        { defIgnore = { .07,.13,.19,.25,.31,.38,.45 }, atkPct = { 6,12,18,24,30,36,42 } }),
    node(1, 3, 'sp_wsc', 'Cyclone STR/INT', 7, 'STR/INT +8..55% WSC & +5..35 Acc',
        function(r) local v = ({8,16,24,32,40,48,55})[r]; return string.format('STR/INT +%d%% WSC, +%d Acc', v, r * 5) end,
        { wsc = { str = { .08,.16,.24,.32,.40,.48,.55 }, int = { .08,.16,.24,.32,.40,.48,.55 } }, acc = { 5,10,15,20,25,30,35 } }),
    atkAcc(2, 1, 'sp_force', 'Centrifugal Torque', 12, 10),
    stance(2, 2, 'sp_st', 'Cyclone Stance', 5, 'LR/Berserk/Souleater', ZERK_EFF,
        { wsd = { 8,16,24,32,40 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'LR/Berserk/Souleater: +8..40% WSD & +Atk' }),
    node(2, 3, 'sp_sunder', 'Rending Spin', 5, 'Target -5..25% DEF (45s) & +5..25% WSD',
        function(r) return string.format('Target -%d%% DEF, +%d%% WSD', r * 5, r * 5) end,
        { wsd = { 5,10,15,20,25 }, targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = { 5,10,15,20,25 }, duration = 45 }} }),
    node(3, 1, 'sp_tp', 'Momentum Spin', 5, '+70..350 TP Bonus & +5..25% WSD',
        function(r) return string.format('+%d TP Bonus, +%d%% WSD', r * 70, r * 5) end,
        { tpBonus = { 70,140,210,280,350 }, wsd = { 5,10,15,20,25 } }),
    elemFollow(3, 2, 'sp_shock', 'Runic Shockwave', 'WIND', 'Wind', 10, false),
    node(3, 3, 'sp_crit', 'Vortex Crit', 5, '+5..25% Crit Rate & +7..35% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 7) end,
        { crit = { 5,10,15,20,25 }, critDmg = { 7,14,21,28,35 } }),
    node(4, 1, 'capstone', 'Tornado Cleave', 3, '1->2 Hits, fTP ALL & +14/26/38% WSD',
        function(r) return string.format('2 Hits, fTP ALL, +%d%% WSD', ({14,26,38})[r]) end,
        { hits = { 2,2,2 }, wsd = { 14,26,38 }, multiHitfTPAt = 1 }),
    node(4, 2, 'sp_cap2', 'Unstoppable Spin', 3, '+0.6..1.8 fTP & +12..36% SC Dmg',
        function(r) return string.format('+%.1f fTP, +%d%% SC Dmg', r * 0.6, r * 12) end,
        { ftpAdd = { 0.6,1.2,1.8 }, scBonus = { 12,24,36 } }),
    node(4, 3, 'sp_mast', 'Spinning Mastery', 5, '+6..30% WSD & +10..50% WS Atk',
        function(r) return string.format('+%d%% WSD, +%d%% Atk', r * 6, r * 10) end,
        { wsd = { 6,12,18,24,30 }, atkPct = { 10,20,30,40,50 } }),
}
regGS(55, 'heavy', zerk55)

---------------------------------------------------------------------------
-- #56 Ground Strike (High-TP Multiplier Nuker, STR/INT)
---------------------------------------------------------------------------
local zerk56 = {
    ftp({ 1.50, 2.25, 3.50 }),
    node(1, 2, 'gs_atk', 'Tectonic Force', 7, '+12..85% WS Attack & +4..28% WSD',
        function(r) return string.format('+%d%% WS Atk, +%d%% WSD', ({12,24,36,48,60,72,85})[r], r * 4) end,
        { atkPct = { 12,24,36,48,60,72,85 }, wsd = { 4,8,12,16,20,24,28 } }),
    node(1, 3, 'gs_wsc', 'Earthshaker STR/INT', 7, 'STR/INT +9..65% WSC & +5..35 Acc',
        function(r) local v = ({9,18,27,36,46,55,65})[r]; return string.format('STR/INT +%d%% WSC, +%d Acc', v, r * 5) end,
        { wsc = { str = { .09,.18,.27,.36,.46,.55,.65 }, int = { .09,.18,.27,.36,.46,.55,.65 } }, acc = { 5,10,15,20,25,30,35 } }),
    node(2, 1, 'gs_def', 'Faultline Shatter', 5, 'Ignores 7..35% DEF & Target -4..20% DEF',
        function(r) return string.format('Ignores %d%% DEF, Target -%d%% DEF', r * 7, r * 4) end,
        { defIgnore = { .07,.14,.21,.28,.35 }, targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = { 4,8,12,16,20 }, duration = 60 }} }),
    stance(2, 2, 'gs_st', 'Cataclysm Stance', 5, 'LR/Souleater/Berserk', ZERK_EFF,
        { wsd = { 9,18,27,36,45 }, tpBonus = { 50,100,150,200,250 }, zeroDesc = 'LR/Souleater/Berserk: +9..45% WSD & +TP' }),
    node(2, 3, 'gs_crit', 'Seismic Impact', 5, '+5..25% Crit Rate & +7..35% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 7) end,
        { crit = { 5,10,15,20,25 }, critDmg = { 7,14,21,28,35 } }),
    node(3, 1, 'gs_tp', 'Seismic Surge', 5, '+80..400 TP Bonus & +6..30% WSD',
        function(r) return string.format('+%d TP Bonus, +%d%% WSD', r * 80, r * 6) end,
        { tpBonus = { 80,160,240,320,400 }, wsd = { 6,12,18,24,30 } }),
    elemFollow(3, 2, 'gs_earth', 'Magma Fissure', 'EARTH', 'Earth', 11, false),
    node(3, 3, 'gs_sc', 'Tectonic Chain', 5, '+9..45% SC Dmg & +8..40 Acc',
        function(r) return string.format('+%d%% SC Dmg, +%d Acc', r * 9, r * 8) end,
        { scBonus = { 9,18,27,36,45 }, acc = { 8,16,24,32,40 } }),
    node(4, 1, 'capstone', 'Continental Smash', 3, '1->2 Hits, +15/28/42% WSD & +0.4/0.8/1.2 fTP',
        function(r) return string.format('2h, +%d%% WSD, +%.1f fTP', ({15,28,42})[r], r * 0.4) end,
        { hits = { 2,2,2 }, wsd = { 15,28,42 }, ftpAdd = { 0.4,0.8,1.2 } }),
    node(4, 2, 'gs_cap2', 'Earthbreaker', 3, 'fTP ALL Hits & +12..36% Crit Dmg',
        function(r) return string.format('fTP ALL Hits, +%d%% Crit Dmg', r * 12) end,
        { multiHitfTPAt = 1, critDmg = { 12,24,36 } }),
    node(4, 3, 'gs_mast', 'Ground Mastery', 5, '+7..35% WSD & +10..50 Acc',
        function(r) return string.format('+%d%% WSD, +%d Acc', r * 7, r * 10) end,
        { wsd = { 7,14,21,28,35 }, acc = { 10,20,30,40,50 } }),
}
regGS(56, 'heavy', zerk56)

---------------------------------------------------------------------------
-- #57 Scourge (Relic Aftermath Finisher, STR/VIT)
---------------------------------------------------------------------------
local zerk57 = {
    ftp({ 2.50, 3.00, 3.60 }),
    node(1, 2, 'sc_force', 'Ragnarok Cleave', 7, '+10..70% WS Attack & Ignores 5..35% DEF',
        function(r) return string.format('+%d%% WS Atk, Ignores %d%% DEF', r * 10, r * 5) end,
        { atkPct = { 10,20,30,40,50,60,70 }, defIgnore = { .05,.10,.15,.20,.25,.30,.35 } }),
    node(1, 3, 'sc_wsc', 'Relic STR/VIT', 7, 'STR/VIT +8..55% WSC & +5..35 Acc',
        function(r) local v = ({8,16,24,32,40,48,55})[r]; return string.format('STR/VIT +%d%% WSC, +%d Acc', v, r * 5) end,
        { wsc = { str = { .08,.16,.24,.32,.40,.48,.55 }, vit = { .08,.16,.24,.32,.40,.48,.55 } }, acc = { 5,10,15,20,25,30,35 } }),
    H.critMast(2, 1, 'sc_crit', 'Doombringer Crit', 5, 6),
    stance(2, 2, 'sc_st', 'Valhalla Stance', 5, 'LR/Souleater/Berserk', ZERK_EFF,
        { wsd = { 9,18,27,36,45 }, crit = { 4,8,12,16,20 }, zeroDesc = 'LR/Souleater/Berserk: +9..45% WSD & +Crit' }),
    node(2, 3, 'sc_leech', 'Ragnarok Drain', 5, 'Drains 7..35% WS dmg as HP & +5..25% WSD',
        function(r) return string.format('%d%% HP Drain, +%d%% WSD', r * 7, r * 5) end,
        { hpDrain = { 7,14,21,28,35 }, wsd = { 5,10,15,20,25 } }),
    echo('aftermath_echo', 'Relic Echo', 6, 70),
    elemFollow(3, 1, 'sc_light', 'Twilight Burst', 'LIGHT', 'Light', 11, false),
    node(3, 3, 'sc_sc', 'Relic Chain', 5, '+9..45% SC Dmg & +8..40% WS Atk',
        function(r) return string.format('+%d%% SC Dmg, +%d%% Atk', r * 9, r * 8) end,
        { scBonus = { 9,18,27,36,45 }, atkPct = { 8,16,24,32,40 } }),
    node(4, 1, 'capstone', 'Ragnarok Doom', 3, '1->2 Hits, fTP ALL & +16/30/45% WSD',
        function(r) return string.format('2 Hits, fTP ALL, +%d%% WSD', ({16,30,45})[r]) end,
        { hits = { 2,2,2 }, wsd = { 16,30,45 }, multiHitfTPAt = 1 }),
    node(4, 2, 'sc_cap2', 'Twilight Execution', 3, '+0.6..1.8 fTP & +12..36% Crit Dmg',
        function(r) return string.format('+%.1f fTP, +%d%% Crit Dmg', r * 0.6, r * 12) end,
        { ftpAdd = { 0.6,1.2,1.8 }, critDmg = { 12,24,36 } }),
    node(4, 3, 'sc_mast', 'Scourge Mastery', 5, '+7..35% WSD & +7..35% Crit Dmg',
        function(r) return string.format('+%d%% WSD, +%d%% Crit Dmg', r * 7, r * 7) end,
        { wsd = { 7,14,21,28,35 }, critDmg = { 7,14,21,28,35 } }),
}
regGS(57, 'heavy', zerk57)

---------------------------------------------------------------------------
-- #58 Herculean Slash (PURE MAGIC Ice/Thunder Paralyze Nuke — ZERO physical stats!)
---------------------------------------------------------------------------
local zerk58 = {
    ftp({ 2.20, 3.10, 4.20 }, { suffixFn = function(r) return ' +Paralyze' .. (r >= 6 and ' (MAX)' or '') end,
        effect = { nativeDebuff = { 1,2,3,4,5,6 } } }),
    node(1, 2, 'hs58_ice', 'Titan Frost', 7, '+9..63 MAB, +12..84 MACC & Enblizzard (20s)',
        function(r) return string.format('+%d MAB, +%d MACC, Enblizzard', r * 9, r * 12) end,
        { matt = { 9,18,27,36,45,54,63 }, macc = { 12,24,36,48,60,72,84 }, nativeDebuff = true,
          statusBuffs = {{ effect = xi.effect.ENBLIZZARD, power = { 16,24,32,40,48,58,68 }, duration = 20 }} }),
    node(1, 3, 'hs58_wsc', 'Colossus VIT/INT', 7, 'VIT +12..85% / INT +6..42% WSC & +4..28% WSD',
        function(r) return string.format('VIT +%d%%/INT +%d%% WSC, +%d%% WSD', ({12,24,36,48,60,72,85})[r], r * 6, r * 4) end,
        { wsc = { vit = { .12,.24,.36,.48,.60,.72,.85 }, int = { .06,.12,.18,.24,.30,.36,.42 } }, wsd = { 4,8,12,16,20,24,28 } }),
    mabMacc(2, 1, 'hs58_arc', 'Herculean Arcana', 10, 10, 5),
    stance(2, 2, 'hs58_st', 'Aegis Stance', 5, 'Valiance/Battuta/Berserk', { xi.effect.VALIANCE, xi.effect.VALLATION, xi.effect.BATTUTA, xi.effect.LAST_RESORT, xi.effect.BERSERK },
        { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'Valiance/Battuta/Berserk: +9..45% WSD & +MAB' }),
    node(2, 3, 'hs58_mdef', 'Colossal Breach', 5, 'Target -7..35 M.Def & -8..40 M.Eva (60s)',
        function(r) return string.format('Target -%d M.Def, -%d M.Eva', r * 7, r * 8) end,
        { targetDebuffs = {
            { effect = xi.effect.MAGIC_DEF_DOWN, power = { 7,14,21,28,35 }, duration = 60 },
            { effect = xi.effect.MAGIC_EVASION_DOWN, power = { 8,16,24,32,40 }, duration = 60 },
        } }),
    node(3, 1, 'hs58_deb', 'Olympian Freeze', 5, 'Target Slow (15..30%) & -6..30 M.Atk (60s)',
        function(r) return string.format('Slow %d%%, M.Atk -%d (60s)', 12 + r * 3 + (r == 5 and 3 or 0), r * 6) end,
        { targetDebuffs = {
            { effect = xi.effect.SLOW, power = { 1500,1800,2200,2600,3000 }, duration = 60 },
            { effect = xi.effect.MAGIC_ATK_DOWN, power = { 6,12,18,24,30 }, duration = 60 },
        } }),
    elemFollow(3, 2, 'hs58_burst', 'Glacial Thunder', 'ICE', 'Ice', 12, false),
    node(3, 3, 'hs58_tp', 'Titan Surge', 5, '+80..400 TP Bonus & +8..40% SC Dmg',
        function(r) return string.format('+%d TP Bonus, +%d%% SC Dmg', r * 80, r * 8) end,
        { tpBonus = { 80,160,240,320,400 }, scBonus = { 8,16,24,32,40 } }),
    node(4, 1, 'capstone', 'Labor of Hercules', 3, '+18/34/50% WSD, +15/30/45 MAB & Stoneskin 250/380/500',
        function(r) return string.format('+%d%% WSD, +%d MAB, Skin %d', ({18,34,50})[r], r * 15, ({250,380,500})[r]) end,
        { wsd = { 18,34,50 }, matt = { 15,30,45 },
          statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 250,380,500 }, duration = 120, tier = 3 }} }),
    node(4, 2, 'hs58_cap2', 'Olympian Overcharge', 3, '+0.6..1.8 fTP & +15..45% SC Dmg',
        function(r) return string.format('+%.1f fTP, +%d%% SC Dmg', r * 0.6, r * 15) end,
        { ftpAdd = { 0.6,1.2,1.8 }, scBonus = { 15,30,45 } }),
    node(4, 3, 'hs58_mast', 'Herculean Mastery', 5, '+7..35% WSD & +10..50 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 7, r * 10) end,
        { wsd = { 7,14,21,28,35 }, macc = { 10,20,30,40,50 } }),
}
regGS(58, 'magic', zerk58)

---------------------------------------------------------------------------
-- #59 Torcleaver (Empyrean VIT Cleaver, VIT)
---------------------------------------------------------------------------
local zerk59 = {
    ftp({ 3.25, 4.75, 6.75 }),
    node(1, 2, 'tc_vit', 'Caladbolg VIT', 7, 'VIT +14..95% WSC & +5..35% WSD',
        function(r) return string.format('VIT +%d%% WSC, +%d%% WSD', ({14,28,42,56,70,82,95})[r], r * 5) end,
        { wsc = { vit = { .14,.28,.42,.56,.70,.82,.95 } }, wsd = { 5,10,15,20,25,30,35 } }),
    node(1, 3, 'tc_edge', 'Sovereign Cleave', 7, '+7..49% WS Atk & Ignores 5..35% DEF',
        function(r) return string.format('+%d%% Atk, Ignores %d%% DEF', r * 7, r * 5) end,
        { atkPct = { 7,14,21,28,35,42,49 }, defIgnore = { .05,.10,.15,.20,.25,.30,.35 } }),
    atkAcc(2, 1, 'tc_force', 'Titanic Impact', 12, 10),
    stance(2, 2, 'tc_st', 'Empyrean Stance', 5, 'LR/Berserk/Souleater', ZERK_EFF,
        { wsd = { 10,20,30,40,50 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'LR/Berserk/Souleater: +10..50% WSD & +Atk' }),
    node(2, 3, 'tc_sunder', 'Caladbolg Breach', 5, 'Target -5..25% DEF (60s) & +6..30% Crit Dmg',
        function(r) return string.format('Target -%d%% DEF, +%d%% CrDmg', r * 5, r * 6) end,
        { critDmg = { 6,12,18,24,30 }, targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = { 5,10,15,20,25 }, duration = 60 }} }),
    echo('aftermath_echo', 'Empyrean Echo', 6, 75),
    H.critMast(3, 1, 'tc_crit', 'Cleaver Execution', 5, 7),
    elemFollow(3, 3, 'tc_light', 'Caladbolg Radiance', 'LIGHT', 'Light', 11, false),
    node(4, 1, 'capstone', 'Caladbolg Zenith', 3, '1->2 Hits, +16/30/45% WSD & +10/20/30% SC Dmg',
        function(r) return string.format('2h, +%d%% WSD, +%d%% SC Dmg', ({16,30,45})[r], r * 10) end,
        { hits = { 2,2,2 }, wsd = { 16,30,45 }, scBonus = { 10,20,30 } }),
    node(4, 2, 'tc_cap2', 'Titanic Overdrive', 3, 'fTP ALL Hits & +0.6..1.8 fTP',
        function(r) return string.format('fTP ALL Hits, +%.1f fTP', r * 0.6) end,
        { multiHitfTPAt = 1, ftpAdd = { 0.6,1.2,1.8 } }),
    node(4, 3, 'tc_mast', 'Torcleaver Mastery', 5, '+8..40% WSD & +10..50 Acc',
        function(r) return string.format('+%d%% WSD, +%d Acc', r * 8, r * 10) end,
        { wsd = { 8,16,24,32,40 }, acc = { 10,20,30,40,50 } }),
}
regGS(59, 'heavy', zerk59)

---------------------------------------------------------------------------
-- #60 Resolution (5-Hit Multi-Attack Barrage, STR)
---------------------------------------------------------------------------
local zerk60 = {
    ftp({ 0.85, 1.50, 2.25 }),
    H.hits(1, 2, 'res_hits', 'Fivefold Cascade', { 2, 2, 3, 3, 4, 4, 5 }, 5, 5),
    node(1, 3, 'res_wsc', 'Relentless STR', 7, 'STR +13..90% WSC & +4..28% WSD',
        function(r) return string.format('STR +%d%% WSC, +%d%% WSD', ({13,26,39,52,65,78,90})[r], r * 4) end,
        { wsc = { str = { .13,.26,.39,.52,.65,.78,.90 } }, wsd = { 4,8,12,16,20,24,28 } }),
    H.multiFtp(2, 1, 'res_mftp', 'Resolution Transfer', 6, nil),
    atkAcc(2, 2, 'res_force', 'Barrage Drive', 12, 10),
    node(2, 3, 'res_pierce', 'Cascade Piercer', 5, 'Ignores 6..30% DEF & +6..30 Store TP',
        function(r) return string.format('Ignores %d%% DEF, +%d STP', r * 6, r * 6) end,
        { defIgnore = { .06,.12,.18,.24,.30 }, storeTp = { 6,12,18,24,30 } }),
    stance(3, 1, 'res_st', 'Unyielding Stance', 5, 'LR/Souleater/Berserk', ZERK_EFF,
        { wsd = { 8,16,24,32,40 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'LR/Souleater/Berserk: +8..40% WSD & +Atk' }),
    node(3, 2, 'res_da', 'Momentum Flurry', 5, 'Grants +5..25% Double Attack (15s) & +5..25% WSD',
        function(r) return string.format('+%d%% DA (15s), +%d%% WSD', r * 5, r * 5) end,
        { wsd = { 5,10,15,20,25 },
          postBuff = { effect = xi.effect.WARCRY, duration = 15, mods = {{ mod = xi.mod.DOUBLE_ATTACK, val = { 5,10,15,20,25 } }} } }),
    node(3, 3, 'res_crit', 'Fivefold Crit', 5, '+5..25% Crit Rate & +6..30% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 6) end,
        { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 } }),
    node(4, 1, 'capstone', 'Supreme Resolution', 3, 'fTP ALL Hits, +14/26/38% WSD & +10..30% DEF Ign',
        function(r) return string.format('fTP ALL, +%d%% WSD, %d%% DEF Ign', ({14,26,38})[r], r * 10) end,
        { multiHitfTPAt = 1, wsd = { 14,26,38 }, defIgnore = { .10,.20,.30 } }),
    node(4, 2, 'res_cap2', 'Unending Barrage', 3, '+1 Bonus Hit & +12..36% SC Dmg',
        function(r) return string.format('+1 Hit, +%d%% SC Dmg', r * 12) end,
        { bonusHits = { 1,1,1 }, scBonus = { 12,24,36 } }),
    node(4, 3, 'res_mast', 'Resolution Mastery', 5, '+7..35% WSD & +6..30% Crit',
        function(r) return string.format('+%d%% WSD, +%d%% Crit', r * 7, r * 6) end,
        { wsd = { 7,14,21,28,35 }, crit = { 6,12,18,24,30 } }),
}
regGS(60, 'multihit', zerk60)

---------------------------------------------------------------------------
-- #61 Dimidiation (Ergonic 2-Hit Light/Runic Finisher, DEX)
---------------------------------------------------------------------------
local zerk61 = {
    ftp({ 2.25, 4.50, 6.75 }),
    node(1, 2, 'dim_hits', 'Epeolatry Twin Cut', 7, '1->2 Hits, +8..56% WS Atk & +5..35 Acc',
        function(r) return string.format('2 Hits, +%d%% Atk, +%d Acc', r * 8, r * 5) end,
        { hits = { 2,2,2,2,2,2,2 }, atkPct = { 8,16,24,32,40,48,56 }, acc = { 5,10,15,20,25,30,35 } }),
    node(1, 3, 'dim_wsc', 'Ergonic DEX', 7, 'DEX +13..90% WSC & +4..28% WSD',
        function(r) return string.format('DEX +%d%% WSC, +%d%% WSD', ({13,26,39,52,65,78,90})[r], r * 4) end,
        { wsc = { dex = { .13,.26,.39,.52,.65,.78,.90 } }, wsd = { 4,8,12,16,20,24,28 } }),
    node(2, 1, 'dim_def', 'Dimensional Cleave', 5, 'Ignores 7..35% DEF & +5..25% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 7, r * 5) end,
        { defIgnore = { .07,.14,.21,.28,.35 }, wsd = { 5,10,15,20,25 } }),
    stance(2, 2, 'dim_st', 'Runic Mastery Stance', 5, 'Swordplay/Valiance/Berserk', { xi.effect.SWORDPLAY, xi.effect.VALIANCE, xi.effect.VALLATION, xi.effect.BATTUTA, xi.effect.LAST_RESORT, xi.effect.BERSERK },
        { wsd = { 10,20,30,40,50 }, atkPct = { 10,20,30,40,50 }, zeroDesc = 'Swordplay/Valiance/Berserk: +10..50% WSD & +Atk' }),
    node(2, 3, 'dim_crit', 'Ergonic Precision', 5, '+6..30% Crit Rate & +7..35% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 6, r * 7) end,
        { crit = { 6,12,18,24,30 }, critDmg = { 7,14,21,28,35 } }),
    echo('aftermath_echo', 'Mythic Echo', 6, 80),
    elemFollow(3, 1, 'dim_light', 'Runic Light Burst', 'LIGHT', 'Light', 12, false),
    node(3, 3, 'dim_sc', 'Bifurcating Chain', 5, '+10..50% SC Dmg & +60..300 TP Bonus',
        function(r) return string.format('+%d%% SC Dmg, +%d TP Bonus', r * 10, r * 60) end,
        { scBonus = { 10,20,30,40,50 }, tpBonus = { 60,120,180,240,300 } }),
    node(4, 1, 'capstone', 'Ergonic Bifurcation', 3, 'fTP ALL Hits, +16/30/45% WSD & +12/24/36% SC Dmg',
        function(r) return string.format('fTP ALL, +%d%% WSD, +%d%% SC', ({16,30,45})[r], r * 12) end,
        { multiHitfTPAt = 1, wsd = { 16,30,45 }, scBonus = { 12,24,36 } }),
    node(4, 2, 'dim_cap2', 'Epeolatry Sovereign', 3, '+0.6..1.8 fTP & +10..30% DEF Ignore',
        function(r) return string.format('+%.1f fTP, %d%% DEF Ign', r * 0.6, r * 10) end,
        { ftpAdd = { 0.6,1.2,1.8 }, defIgnore = { .10,.20,.30 } }),
    node(4, 3, 'dim_mast', 'Dimidiation Mastery', 5, '+8..40% WSD & +7..35% Crit',
        function(r) return string.format('+%d%% WSD, +%d%% Crit', r * 8, r * 7) end,
        { wsd = { 8,16,24,32,40 }, crit = { 7,14,21,28,35 } }),
}
regGS(61, 'multihit', zerk61)
