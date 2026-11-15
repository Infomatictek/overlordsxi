-----------------------------------
-- OverlordsXI Bespoke WS Trees: Throwing (#241-#252, Dancer Bladewheel)
-----------------------------------
local H = require('modules/custom/lua/overlords_ws_tree_helpers')
local reg, ftp, node = H.reg, H.ftp, H.node
local cap, mast, hits = H.cap, H.mast, H.hits
local rangedAtkAcc, critMast, mabMacc = H.rangedAtkAcc, H.critMast, H.mabMacc
local multiFtp, elemFollow, stance, echo = H.multiFtp, H.elemFollow, H.stanceNode, H.echo

local DNC_STANCES =
{
    xi.effect.SABER_DANCE,
    xi.effect.FAN_DANCE,
    xi.effect.BUILDING_FLOURISH,
    xi.effect.CLIMACTIC_FLOURISH,
    xi.effect.PRESTO,
    xi.effect.GRAND_PAS,
}

-- #241 Pirouette Toss (Utility Opener + Finishing Move Generator)
reg(241, 'utility', {
    ftp({ 1.00, 1.50, 2.00 }),
    node(1, 2, 'pt_tempo', 'Spinning Tempo', 7, 'R1: +8..56 R.Acc & NextWS +4..28% WSD',
        function(r) return string.format('+%d R.Acc, NextWS +%d%%', r * 8, r * 4) end,
        { racc = { 8,16,24,32,40,48,56 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 15 } }),
    node(1, 3, 'pt_wsc', 'Dexterous Spin', 7, 'DEX +8..55%, AGI +4..30% WSC & +6..42 R.Atk',
        function(r) return string.format('DEX +%d%%, AGI +%d%%, +%d R.Atk', ({8,16,24,32,40,48,55})[r], r*4, r*6) end,
        { wsc = { dex = { .08,.16,.24,.32,.40,.48,.55 }, agi = { .04,.08,.12,.16,.20,.26,.30 } }, ratt = { 6,12,18,24,30,36,42 } }),
    rangedAtkAcc(2, 1, 'pt_force', 'Chakram Momentum', 10, 10),
    stance(2, 2, 'pt_st', 'Dancer Poise', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 8,16,24,32,40 }, racc = { 10,20,30,40,50 }, zeroDesc = 'DNC Stance: +8..40% WSD & +R.Acc' }),
    critMast(3, 1, 'pt_crit', 'Spinning Edge', 5, 6),
    node(3, 2, 'pt_flow', 'Encore Rhythm', 5, 'Next WS +60..300 TP & -5..25 Enmity',
        function(r) return string.format('NextWS +%d TP, -%d Enmity', r * 60, r * 5) end,
        { enmity = { -5,-10,-15,-20,-25 }, nextWs = { tp = { 60,120,180,240,300 }, dur = 15 } }),
    cap('capstone', 'Grand Pirouette', '+16/30/45% WSD & +150/300/450 TP Bonus',
        function(r) return string.format('+%d%% WSD, +%d TP Bonus', ({16,30,45})[r], r * 150) end,
        { wsd = { 16,30,45 }, tpBonus = { 150,300,450 } }),
    mast('pt_mast', 'Toss Mastery', 5, '+6..30% WSD & +10..50 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 6, r * 10) end,
        { wsd = { 6,12,18,24,30 }, racc = { 10,20,30,40,50 } }),
})

-- #242 Whirling Waltz (Light Magic + Party Heal)
reg(242, 'magic', {
    ftp({ 1.25, 2.00, 2.75 }),
    node(1, 2, 'ww_mab', 'Radiant Arc', 7, 'R1: +8..56 MAB & +6..42 MACC',
        function(r) return string.format('+%d MAB, +%d MACC', r * 8, r * 6) end,
        { matt = { 8,16,24,32,40,48,56 }, macc = { 6,12,18,24,30,36,42 } }),
    node(1, 3, 'ww_wsc', 'Charismatic Grace', 7, 'CHR +8..55%, DEX +4..30% WSC & +4..28% WSD',
        function(r) return string.format('CHR +%d%%, DEX +%d%%, +%d%% WSD', ({8,16,24,32,40,48,55})[r], r*4, r*4) end,
        { wsc = { chr = { .08,.16,.24,.32,.40,.48,.55 }, dex = { .04,.08,.12,.16,.20,.26,.30 } }, wsd = { 4,8,12,16,20,24,28 } }),
    mabMacc(2, 1, 'ww_arc', 'Waltz Resonance', 8, 8, 5),
    stance(2, 2, 'ww_st', 'Waltz Cadence', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 8,16,24,32,40 }, matt = { 10,20,30,40,50 }, zeroDesc = 'DNC Stance: +8..40% WSD & +MAB' }),
    elemFollow(3, 1, 'ww_light', 'Luminous Ring', 'LIGHT', 'Light', 11, false),
    node(3, 2, 'ww_enm', 'Soothing Spin', 5, '-6..30 Enmity & +60..300 TP Bonus',
        function(r) return string.format('-%d Enmity, +%d TP Bonus', r * 6, r * 60) end,
        { enmity = { -6,-12,-18,-24,-30 }, tpBonus = { 60,120,180,240,300 } }),
    cap('capstone', 'Divine Waltz Halo', '+16/30/45% WSD & +15/30/45 MAB',
        function(r) return string.format('+%d%% WSD, +%d MAB', ({16,30,45})[r], r * 15) end,
        { wsd = { 16,30,45 }, matt = { 15,30,45 } }),
    mast('ww_mast', 'Waltz Mastery', 5, '+7..35% WSD & +8..40 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 7, r * 8) end,
        { wsd = { 7,14,21,28,35 }, macc = { 8,16,24,32,40 } }),
})

-- #243 Ricochet Tango (3-Hit Multi-Hit)
reg(243, 'multihit', {
    ftp({ 1.00, 1.00, 1.00 }),
    node(1, 2, 'rt_acc', 'Precision Rebound', 7, 'R1: +8..56 R.Acc & +5..35% R.Atk',
        function(r) return string.format('+%d R.Acc, +%d%% R.Atk', r * 8, r * 5) end,
        { racc = { 8,16,24,32,40,48,56 }, atkPct = { 5,10,15,20,25,30,35 } }),
    node(1, 3, 'rt_wsc', 'Tango DEX', 7, 'DEX +8..60% WSC & +4..28% WSD',
        function(r) return string.format('DEX +%d%%, +%d%% WSD', ({8,16,24,32,40,50,60})[r], r*4) end,
        { wsc = { dex = { .08,.16,.24,.32,.40,.50,.60 } }, wsd = { 4,8,12,16,20,24,28 } }),
    hits(2, 1, 'rt_hits', 'Extra Ricochet', { 2, 2, 3 }, 6, 8),
    stance(2, 2, 'rt_st', 'Tango Tempo', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 8,16,24,32,40 }, racc = { 10,20,30,40,50 }, zeroDesc = 'DNC Stance: +8..40% WSD & +R.Acc' }),
    multiFtp(3, 1, 'rt_ftp', 'Rebound Force', 6, 8),
    critMast(3, 2, 'rt_crit', 'Tango Crit', 5, 6),
    cap('capstone', 'Endless Ricochet', '+16/32/48% WSD & +1/1/2 Extra Hits',
        function(r) return string.format('+%d%% WSD, +%d Hits', ({16,32,48})[r], ({1,1,2})[r]) end,
        { wsd = { 16,32,48 }, hits = { 1,1,2 } }),
    mast('rt_mast', 'Tango Mastery', 5, '+7..35% WSD & +10..50 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 7, r * 10) end,
        { wsd = { 7,14,21,28,35 }, racc = { 10,20,30,40,50 } }),
})

-- #244 Crimson Samba (Dark Magic + HP Drain)
reg(244, 'magic', {
    ftp({ 1.50, 2.25, 3.00 }),
    node(1, 2, 'cs_mab', 'Crimson Pulse', 7, 'R1: +8..56 MAB & +6..42 MACC',
        function(r) return string.format('+%d MAB, +%d MACC', r * 8, r * 6) end,
        { matt = { 8,16,24,32,40,48,56 }, macc = { 6,12,18,24,30,36,42 } }),
    node(1, 3, 'cs_wsc', 'Samba CHR/INT', 7, 'CHR +8..55%, INT +4..30% WSC & +4..28% WSD',
        function(r) return string.format('CHR +%d%%, INT +%d%%, +%d%% WSD', ({8,16,24,32,40,48,55})[r], r*4, r*4) end,
        { wsc = { chr = { .08,.16,.24,.32,.40,.48,.55 }, int = { .04,.08,.12,.16,.20,.26,.30 } }, wsd = { 4,8,12,16,20,24,28 } }),
    mabMacc(2, 1, 'cs_arc', 'Dark Cadence', 9, 9, 5),
    stance(2, 2, 'cs_st', 'Samba Trance', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 8,16,24,32,40 }, matt = { 10,20,30,40,50 }, zeroDesc = 'DNC Stance: +8..40% WSD & +MAB' }),
    elemFollow(3, 1, 'cs_dark', 'Shadow Edge', 'DARK', 'Dark', 12, false),
    node(3, 2, 'cs_drain', 'Blood Rhythm', 5, '+80..400 TP Bonus & -5..25 Enmity',
        function(r) return string.format('+%d TP Bonus, -%d Enmity', r * 80, r * 5) end,
        { tpBonus = { 80,160,240,320,400 }, enmity = { -5,-10,-15,-20,-25 } }),
    cap('capstone', 'Scarlet Samba', '+16/32/48% WSD & +15/30/45 MAB',
        function(r) return string.format('+%d%% WSD, +%d MAB', ({16,32,48})[r], r * 15) end,
        { wsd = { 16,32,48 }, matt = { 15,30,45 } }),
    mast('cs_mast', 'Samba Mastery', 5, '+7..35% WSD & +10..50 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 7, r * 10) end,
        { wsd = { 7,14,21,28,35 }, macc = { 10,20,30,40,50 } }),
})

-- #245 Stutter Disc (Utility + Magic Evasion Down + Extra Daze)
reg(245, 'utility', {
    ftp({ 1.25, 1.25, 1.25 }),
    node(1, 2, 'sd_debuff', 'Disrupting Spin', 7, 'R1: +8..56 R.Acc & Magic Evasion Down',
        function(r) return string.format('+%d R.Acc, MEVA-%d', r * 8, 10 + r * 5) end,
        { racc = { 8,16,24,32,40,48,56 },
          targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,20,25,30,35,40,45 }, duration = 60 }} }),
    node(1, 3, 'sd_wsc', 'Stutter AGI/CHR', 7, 'AGI +8..55%, CHR +4..30% WSC & +4..28% WSD',
        function(r) return string.format('AGI +%d%%, CHR +%d%%, +%d%% WSD', ({8,16,24,32,40,48,55})[r], r*4, r*4) end,
        { wsc = { agi = { .08,.16,.24,.32,.40,.48,.55 }, chr = { .04,.08,.12,.16,.20,.26,.30 } }, wsd = { 4,8,12,16,20,24,28 } }),
    rangedAtkAcc(2, 1, 'sd_force', 'Daze Force', 11, 11),
    stance(2, 2, 'sd_st', 'Dancer Rhythm', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 8,16,24,32,40 }, racc = { 10,20,30,40,50 }, zeroDesc = 'DNC Stance: +8..40% WSD & +R.Acc' }),
    node(3, 1, 'sd_macc', 'Disc Harmonics', 5, '+12..60 MACC & +60..300 TP Bonus',
        function(r) return string.format('+%d MACC, +%d TP Bonus', r * 12, r * 60) end,
        { macc = { 12,24,36,48,60 }, tpBonus = { 60,120,180,240,300 } }),
    node(3, 2, 'sd_next', 'Stutter Primer', 5, 'Next WS +6..30% WSD & -5..25 Enmity',
        function(r) return string.format('NextWS +%d%%, -%d Enmity', r * 6, r * 5) end,
        { enmity = { -5,-10,-15,-20,-25 }, nextWs = { wsd = { 6,12,18,24,30 }, dur = 15 } }),
    cap('capstone', 'Resonant Stutter', '+16/32/48% WSD & +150/300/450 TP Bonus',
        function(r) return string.format('+%d%% WSD, +%d TP Bonus', ({16,32,48})[r], r * 150) end,
        { wsd = { 16,32,48 }, tpBonus = { 150,300,450 } }),
    mast('sd_mast', 'Stutter Mastery', 5, '+7..35% WSD & +12..60 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 7, r * 12) end,
        { wsd = { 7,14,21,28,35 }, racc = { 12,24,36,48,60 } }),
})

-- #246 Feathered Ring (Crit WS + Bewildered Daze)
reg(246, 'crit', {
    ftp({ 1.75, 1.75, 1.75 }),
    node(1, 2, 'fr_crit', 'Feather Edge', 7, 'R1: +4..28% Crit Rate & +5..35% Crit Dmg',
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 4, r * 5) end,
        { critRate = { .04,.08,.12,.16,.20,.24,.28 }, critDmg = { 5,10,15,20,25,30,35 } }),
    node(1, 3, 'fr_wsc', 'Feathered DEX', 7, 'DEX +10..65% WSC & +8..56 R.Acc',
        function(r) return string.format('DEX +%d%%, +%d R.Acc', ({10,20,30,40,50,58,65})[r], r*8) end,
        { wsc = { dex = { .10,.20,.30,.40,.50,.58,.65 } }, racc = { 8,16,24,32,40,48,56 } }),
    rangedAtkAcc(2, 1, 'fr_force', 'Keen Ring', 12, 12),
    stance(2, 2, 'fr_st', 'Feather Stance', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 9,18,27,36,45 }, critRate = { .04,.08,.12,.16,.20 }, zeroDesc = 'DNC Stance: +9..45% WSD & +Crit' }),
    critMast(3, 1, 'fr_cm', 'Lethal Arc', 6, 8),
    echo('fr_echo', 'Feather Echo', 6, 70),
    cap('capstone', 'Plumed Severance', '+18/34/50% WSD & +10/18/25% Crit Rate',
        function(r) return string.format('+%d%% WSD, +%d%% Crit', ({18,34,50})[r], ({10,18,25})[r]) end,
        { wsd = { 18,34,50 }, critRate = { .10,.18,.25 } }),
    mast('fr_mast', 'Feather Mastery', 5, '+7..35% WSD & +12..60 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 7, r * 12) end,
        { wsd = { 7,14,21,28,35 }, racc = { 12,24,36,48,60 } }),
})

-- #247 Bolero Cyclone (Wind AoE Magic + Evasion Down)
reg(247, 'magic', {
    ftp({ 1.50, 2.50, 3.25 }),
    node(1, 2, 'bc_mab', 'Gale Spin', 7, 'R1: +8..56 MAB & Evasion Down',
        function(r) return string.format('+%d MAB, EVA-%d', r * 8, 10 + r * 5) end,
        { matt = { 8,16,24,32,40,48,56 },
          targetDebuffs = {{ effect = xi.effect.EVASION_DOWN, power = { 15,20,25,30,35,40,45 }, duration = 60 }} }),
    node(1, 3, 'bc_wsc', 'Bolero CHR/AGI', 7, 'CHR +8..55%, AGI +4..30% WSC & +4..28% WSD',
        function(r) return string.format('CHR +%d%%, AGI +%d%%, +%d%% WSD', ({8,16,24,32,40,48,55})[r], r*4, r*4) end,
        { wsc = { chr = { .08,.16,.24,.32,.40,.48,.55 }, agi = { .04,.08,.12,.16,.20,.26,.30 } }, wsd = { 4,8,12,16,20,24,28 } }),
    mabMacc(2, 1, 'bc_arc', 'Tempest Arcana', 10, 10, 5),
    stance(2, 2, 'bc_st', 'Cyclone Tempo', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'DNC Stance: +9..45% WSD & +MAB' }),
    elemFollow(3, 1, 'bc_wind', 'Zephyr Wake', 'WIND', 'Wind', 12, false),
    node(3, 2, 'bc_tp', 'Whirlwind Surge', 5, '+80..400 TP Bonus & -5..25 Enmity',
        function(r) return string.format('+%d TP Bonus, -%d Enmity', r * 80, r * 5) end,
        { tpBonus = { 80,160,240,320,400 }, enmity = { -5,-10,-15,-20,-25 } }),
    cap('capstone', 'Tempest Bolero', '+18/34/50% WSD & +18/34/50 MAB',
        function(r) return string.format('+%d%% WSD, +%d MAB', ({18,34,50})[r], ({18,34,50})[r]) end,
        { wsd = { 18,34,50 }, matt = { 18,34,50 } }),
    mast('bc_mast', 'Bolero Mastery', 5, '+7..35% WSD & +10..50 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 7, r * 10) end,
        { wsd = { 7,14,21,28,35 }, macc = { 10,20,30,40,50 } }),
})

-- #248 Flamenco Finale (Heavy Finisher Consuming Finishing Moves)
reg(248, 'heavy', {
    ftp({ 2.50, 3.30, 4.10 }),
    node(1, 2, 'ff_atk', 'Crescendo Force', 7, 'R1: +9..63% R.Atk & +8..56 R.Acc',
        function(r) return string.format('+%d%% R.Atk, +%d R.Acc', r * 9, r * 8) end,
        { atkPct = { 9,18,27,36,45,54,63 }, racc = { 8,16,24,32,40,48,56 } }),
    node(1, 3, 'ff_wsc', 'Finale DEX/CHR', 7, 'DEX +8..55%, CHR +6..40% WSC & +4..28% WSD',
        function(r) return string.format('DEX +%d%%, CHR +%d%%, +%d%% WSD', ({8,16,24,32,40,48,55})[r], ({6,12,18,24,30,35,40})[r], r*4) end,
        { wsc = { dex = { .08,.16,.24,.32,.40,.48,.55 }, chr = { .06,.12,.18,.24,.30,.35,.40 } }, wsd = { 4,8,12,16,20,24,28 } }),
    rangedAtkAcc(2, 1, 'ff_force', 'Climactic Drive', 13, 13),
    stance(2, 2, 'ff_st', 'Finale Focus', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 10,20,30,40,50 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'DNC Stance: +10..50% WSD & +R.Atk' }),
    critMast(3, 1, 'ff_crit', 'Finale Crit', 5, 7),
    echo('ff_echo', 'Finale Echo', 6, 80),
    cap('capstone', 'Grand Finale', '+20/36/55% WSD & +200/350/500 TP Bonus',
        function(r) return string.format('+%d%% WSD, +%d TP Bonus', ({20,36,55})[r], ({200,350,500})[r]) end,
        { wsd = { 20,36,55 }, tpBonus = { 200,350,500 } }),
    mast('ff_mast', 'Finale Mastery', 5, '+8..40% WSD & +12..60 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 8, r * 12) end,
        { wsd = { 8,16,24,32,40 }, racc = { 12,24,36,48,60 } }),
})

-- #249 Tarantella Storm (5-Hit Multi-Hit Crit)
reg(249, 'multihit', {
    ftp({ 1.00, 1.00, 1.00 }),
    node(1, 2, 'ts_acc', 'Frenetic Aim', 7, 'R1: +8..56 R.Acc & +3..21% Crit Rate',
        function(r) return string.format('+%d R.Acc, +%d%% Crit', r * 8, r * 3) end,
        { racc = { 8,16,24,32,40,48,56 }, critRate = { .03,.06,.09,.12,.15,.18,.21 } }),
    node(1, 3, 'ts_wsc', 'Tarantella DEX', 7, 'DEX +10..65% WSC & +4..28% WSD',
        function(r) return string.format('DEX +%d%%, +%d%% WSD', ({10,20,30,40,50,58,65})[r], r*4) end,
        { wsc = { dex = { .10,.20,.30,.40,.50,.58,.65 } }, wsd = { 4,8,12,16,20,24,28 } }),
    hits(2, 1, 'ts_hits', 'Whirlwind Hits', { 2, 3, 4, 5 }, 5, 6),
    stance(2, 2, 'ts_st', 'Storm Rhythm', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 9,18,27,36,45 }, critRate = { .04,.08,.12,.16,.20 }, zeroDesc = 'DNC Stance: +9..45% WSD & +Crit' }),
    multiFtp(3, 1, 'ts_ftp', 'Storm Momentum', 7, 8),
    critMast(3, 2, 'ts_crit', 'Storm Crit', 6, 8),
    cap('capstone', 'Maelstrom Dance', '+18/34/50% WSD & +1/2/2 Extra Hits',
        function(r) return string.format('+%d%% WSD, +%d Hits', ({18,34,50})[r], ({1,2,2})[r]) end,
        { wsd = { 18,34,50 }, hits = { 1,2,2 } }),
    mast('ts_mast', 'Tarantella Mastery', 5, '+7..35% WSD & +12..60 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 7, r * 12) end,
        { wsd = { 7,14,21,28,35 }, racc = { 12,24,36,48,60 } }),
})

-- #250 Grand Jete (Heavy Single-Hit + Defense Down)
reg(250, 'heavy', {
    ftp({ 3.50, 6.00, 8.50 }),
    node(1, 2, 'gj_atk', 'Soaring Impact', 7, 'R1: +10..70% R.Atk & Defense Down',
        function(r) return string.format('+%d%% R.Atk, DEF-%d%%', r * 10, 10 + r * 3) end,
        { atkPct = { 10,20,30,40,50,60,70 },
          targetDebuffs = {{ effect = xi.effect.DEFENSE_DOWN, power = { 12,15,18,21,24,27,30 }, duration = 60 }} }),
    node(1, 3, 'gj_wsc', 'Jete DEX/AGI', 7, 'DEX +10..65%, AGI +5..35% WSC & +5..35% WSD',
        function(r) return string.format('DEX +%d%%, AGI +%d%%, +%d%% WSD', ({10,20,30,40,50,58,65})[r], r*5, r*5) end,
        { wsc = { dex = { .10,.20,.30,.40,.50,.58,.65 }, agi = { .05,.10,.15,.20,.25,.30,.35 } }, wsd = { 5,10,15,20,25,30,35 } }),
    rangedAtkAcc(2, 1, 'gj_force', 'Apex Leap', 14, 14),
    stance(2, 2, 'gj_st', 'Aerial Focus', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 10,20,30,40,50 }, defIgnore = { .05,.10,.15,.20,.25 }, zeroDesc = 'DNC Stance: +10..50% WSD & DEF Ign' }),
    critMast(3, 1, 'gj_crit', 'Jete Crit', 6, 8),
    echo('gj_echo', 'Jete Echo', 7, 80),
    cap('capstone', 'Celestial Jete', '+22/40/60% WSD & 20/30/40% DEF Ignore',
        function(r) return string.format('+%d%% WSD, %d%% DEF Ign', ({22,40,60})[r], 10 + r * 10) end,
        { wsd = { 22,40,60 }, defIgnore = { .20,.30,.40 } }),
    mast('gj_mast', 'Jete Mastery', 5, '+8..40% WSD & +14..70 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 8, r * 14) end,
        { wsd = { 8,16,24,32,40 }, racc = { 14,28,42,56,70 } }),
})

-- #251 Aurora Fandango (Empyrean-Style 4-Hit + Evasion Down + Self Haste Samba)
reg(251, 'utility', {
    ftp({ 2.75, 2.75, 2.75 }),
    node(1, 2, 'af_atk', 'Dawnlight Spin', 7, 'R1: +9..63% R.Atk & +9..63 R.Acc',
        function(r) return string.format('+%d%% R.Atk, +%d R.Acc', r * 9, r * 9) end,
        { atkPct = { 9,18,27,36,45,54,63 }, racc = { 9,18,27,36,45,54,63 } }),
    node(1, 3, 'af_wsc', 'Fandango DEX/CHR', 7, 'DEX +8..55%, CHR +8..55% WSC & +5..35% WSD',
        function(r) return string.format('DEX +%d%%, CHR +%d%%, +%d%% WSD', ({8,16,24,32,40,48,55})[r], ({8,16,24,32,40,48,55})[r], r*5) end,
        { wsc = { dex = { .08,.16,.24,.32,.40,.48,.55 }, chr = { .08,.16,.24,.32,.40,.48,.55 } }, wsd = { 5,10,15,20,25,30,35 } }),
    hits(2, 1, 'af_hits', 'Aurora Hits', { 2, 3, 3, 4 }, 6, 8),
    stance(2, 2, 'af_st', 'Aurora Poise', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 10,20,30,40,50 }, racc = { 12,24,36,48,60 }, zeroDesc = 'DNC Stance: +10..50% WSD & +R.Acc' }),
    multiFtp(3, 1, 'af_ftp', 'Fandango Surge', 7, 9),
    critMast(3, 2, 'af_crit', 'Aurora Crit', 6, 8),
    cap('capstone', 'Empyrean Aurora', '+20/38/56% WSD & +1/1/2 Extra Hits',
        function(r) return string.format('+%d%% WSD, +%d Hits', ({20,38,56})[r], ({1,1,2})[r]) end,
        { wsd = { 20,38,56 }, hits = { 1,1,2 } }),
    mast('af_mast', 'Fandango Mastery', 5, '+8..40% WSD & +14..70 R.Acc',
        function(r) return string.format('+%d%% WSD, +%d R.Acc', r * 8, r * 14) end,
        { wsd = { 8,16,24,32,40 }, racc = { 14,28,42,56,70 } }),
})

-- #252 Terpsichore's Halo (Mythic-Style Light Capstone + Samba Aftermath)
reg(252, 'magic', {
    ftp({ 3.00, 4.50, 6.00 }),
    node(1, 2, 'th_mab', 'Muse Radiance', 7, 'R1: +10..70 MAB & +8..56 MACC',
        function(r) return string.format('+%d MAB, +%d MACC', r * 10, r * 8) end,
        { matt = { 10,20,30,40,50,60,70 }, macc = { 8,16,24,32,40,48,56 } }),
    node(1, 3, 'th_wsc', 'Muse CHR/DEX', 7, 'CHR +10..65%, DEX +6..40% WSC & +5..35% WSD',
        function(r) return string.format('CHR +%d%%, DEX +%d%%, +%d%% WSD', ({10,20,30,40,50,58,65})[r], ({6,12,18,24,30,35,40})[r], r*5) end,
        { wsc = { chr = { .10,.20,.30,.40,.50,.58,.65 }, dex = { .06,.12,.18,.24,.30,.35,.40 } }, wsd = { 5,10,15,20,25,30,35 } }),
    mabMacc(2, 1, 'th_arc', 'Terpsichore Arcana', 12, 12, 6),
    stance(2, 2, 'th_st', 'Muse Trance', 5, 'Saber/Fan/Flourish', DNC_STANCES,
        { wsd = { 10,20,30,40,50 }, matt = { 12,24,36,48,60 }, zeroDesc = 'DNC Stance: +10..50% WSD & +MAB' }),
    elemFollow(3, 1, 'th_light', 'Halo Afterglow', 'LIGHT', 'Light', 14, false),
    echo('th_echo', 'Muse Echo', 7, 90),
    cap('capstone', 'Mythic Halo', '+22/40/60% WSD & +20/40/60 MAB',
        function(r) return string.format('+%d%% WSD, +%d MAB', ({22,40,60})[r], r * 20) end,
        { wsd = { 22,40,60 }, matt = { 20,40,60 } }),
    mast('th_mast', 'Halo Mastery', 5, '+8..40% WSD & +14..70 MACC',
        function(r) return string.format('+%d%% WSD, +%d MACC', r * 8, r * 14) end,
        { wsd = { 8,16,24,32,40 }, macc = { 14,28,42,56,70 } }),
})
