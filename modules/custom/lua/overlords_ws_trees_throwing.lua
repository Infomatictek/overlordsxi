-----------------------------------
-- OverlordsXI Bespoke WS Trees: Throwing (#241-#252, Dancer Bladewheel)
-- 3-Branch Customizable Trees (77 pts available, 56-pt WS cap, Usable Baseline):
--   Col 1: Samba & Waltz (Support / Sustain / Drain & Aspir Chakram)
--   Col 2: Flourish & Precision (Crit / Multi-Hit / Bouncing Chakram)
--   Col 3: Arcane Chakram (Elemental Rings & Enfeebling Chakram)
--   Col 4: Skillchain Augments (Player-selectable SC properties)
-----------------------------------
local H = require('modules/custom/lua/overlords_ws_tree_helpers')
local regB, node = H.regBaseline, H.node

local DNC_STANCES =
{
    xi.effect.SABER_DANCE,
    xi.effect.FAN_DANCE,
    xi.effect.BUILDING_FLOURISH,
    xi.effect.CLIMACTIC_FLOURISH,
    xi.effect.PRESTO,
    xi.effect.GRAND_PAS,
}

local function dncStance(t, c, k, name, mr, zeroDesc, rankDesc, eff, req)
    eff.stance = {
        jobSpec = 'bladewheel',
        effects = DNC_STANCES,
        wsd     = eff.stWsd,
        atkPct  = eff.stAtk,
        crit    = eff.stCrit,
        matt    = eff.stMatt,
    }
    eff.stWsd, eff.stAtk, eff.stCrit, eff.stMatt = nil, nil, nil, nil
    return node(t, c, k, name, mr, zeroDesc, rankDesc, eff, req)
end

local function makeThrowingWS(wsId, archetype, ele, eleName, debuffEff, debuffName, debuffPower, extra)
    local p = 't' .. wsId .. '_'
    extra = extra or {}
    return regB(wsId, archetype, {
        -- Col 1: Samba & Waltz (Support / Sustain)
        node(1, 1, p .. 's1', extra.s1Name or 'Drain Samba Spin', 7,
            'Lv1+: +8..56% HP Drain & -4..28 Enmity',
            function(r) return string.format('%d%% HP Drain, -%d Enmity', r * 8, r * 4) end,
            { hpDrain = { 8,16,24,32,40,48,56 }, enmity = { -4,-8,-12,-16,-20,-24,-28 } }),
        node(2, 1, p .. 's2', extra.s2Name or 'Waltz Resonance', 6,
            'Party Heal 4..24% Max HP & NextWS +5..30% WSD',
            function(r) return string.format('Party +%d%% HP, NextWS +%d%% WSD', r * 4, r * 5) end,
            { partyHealPct = { 4,8,12,16,20,24 }, nextWs = { wsd = { 5,10,15,20,25,30 }, dur = 15 } },
            { key = p .. 's1', rank = 2 }),
        node(3, 1, p .. 's3', extra.s3Name or 'Aspir & Haste Cadence', 6,
            'MP Drain 5..30% & +4..14% JA Haste (15s)',
            function(r) return string.format('MP Drain %d%%, +%d%% JA Haste', r * 5, 2 + r * 2) end,
            { mpDrain = { 5,10,15,20,25,30 },
              postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 15, mods = {{ mod = xi.mod.HASTE_ABILITY, val = { 400,600,800,1000,1200,1400 } }} } },
            { key = p .. 's2', rank = 2 }),
        node(4, 1, p .. 's4', extra.s4Name or 'Grand Samba Finale', 4,
            'Party +75..300 TP, Party Regen 15..30/t & +15..60% WSD',
            function(r) return string.format('Party +%d TP, Regen +%d/t, +%d%% WSD', r * 75, 10 + r * 5, r * 15) end,
            { partyTp = { 75,150,225,300 }, wsd = { 15,30,45,60 },
              partyBuffs = {{ effect = xi.effect.REGEN, power = { 15,20,25,30 }, duration = 30 }} },
            { key = p .. 's3', rank = 2 }),

        -- Col 2: Flourish & Precision (Crit / Multi-Hit)
        node(1, 2, p .. 'f1', extra.f1Name or 'Chakram Precision', 7,
            'Lv1+: +8..56 R.Acc & +7..49% R.Atk',
            function(r) return string.format('+%d R.Acc, +%d%% R.Atk', r * 8, r * 7) end,
            { racc = { 8,16,24,32,40,48,56 }, atkPct = { 7,14,21,28,35,42,49 } }),
        dncStance(2, 2, p .. 'f2', extra.f2Name or 'Bladewheel Flourish', 6,
            '+4..24% Crit & Bladewheel/Stance +10..60% WSD',
            function(r) return string.format('+%d%% Crit, Spec +%d%% WSD', r * 4, r * 10) end,
            { crit = { 4,8,12,16,20,24 }, stWsd = { 10,20,30,40,50,60 } },
            { key = p .. 'f1', rank = 2 }),
        node(3, 2, p .. 'f3', extra.f3Name or 'Ricochet Bounce', 6,
            '+1 Bonus Hit & +6..36% Crit DMG',
            function(r) return string.format('+1 Hit, +%d%% Crit DMG', r * 6) end,
            { bonusHits = { 1,1,1,1,1,1 }, critDmg = { 6,12,18,24,30,36 } },
            { key = p .. 'f2', rank = 2 }),
        node(4, 2, p .. 'f4', extra.f4Name or 'Apex Chakram', 4,
            'fTP ALL HITS, +1 Bonus Hit & +18..72% WSD',
            function(r) return string.format('fTP ALL HITS, +1 Hit, +%d%% WSD', r * 18) end,
            { multiHitfTPAt = 1, bonusHits = { 1,1,1,1 }, wsd = { 18,36,54,72 } },
            { key = p .. 'f3', rank = 2 }),

        -- Col 3: Arcane Chakram (Elemental / Debuff)
        node(1, 3, p .. 'a1', extra.a1Name or 'Arcane Spin', 7,
            'Lv1+: +8..56 MAB, +7..49 MACC & +5..35% CHR WSC',
            function(r) return string.format('+%d MAB, +%d MACC, CHR +%d%%', r * 8, r * 7, r * 5) end,
            { matt = { 8,16,24,32,40,48,56 }, macc = { 7,14,21,28,35,42,49 },
              wsc = { chr = { .05,.10,.15,.20,.25,.30,.35 } } }),
        node(2, 3, p .. 'a2', extra.a2Name or (debuffName .. ' Step'), 6,
            string.format('Inflicts %s (45s) & +70..420 TP Bonus', debuffName),
            function(r) return string.format('%s (%d), +%d TP Bonus', debuffName, debuffPower[r], r * 70) end,
            { tpBonus = { 70,140,210,280,350,420 },
              targetDebuffs = {{ effect = debuffEff, power = debuffPower, duration = 45 }} },
            { key = p .. 'a1', rank = 2 }),
        node(3, 3, p .. 'a3', extra.a3Name or (eleName .. ' Ring'), 6,
            string.format('%s Follow-up 12..72%% & +10..60%% SC Dmg', eleName),
            function(r) return string.format('%s +%d%%, +%d%% SC Dmg', eleName, r * 12, r * 10) end,
            { elemFollow = { ele = ele, pct = { 12,24,36,48,60,72 } }, scBonus = { 10,20,30,40,50,60 } },
            { key = p .. 'a2', rank = 2 }),
        node(4, 3, p .. 'a4', extra.a4Name or (eleName .. ' Finale'), 4,
            '+20..80% WSD, +20..80 MAB & +1.0..4.0 fTP',
            function(r) return string.format('+%d%% WSD, +%d MAB, +%.1f fTP', r * 20, r * 20, r * 1.0) end,
            { wsd = { 20,40,60,80 }, matt = { 20,40,60,80 }, ftpAdd = { 1.0,2.0,3.0,4.0 } },
            { key = p .. 'a3', rank = 2 }),
    })
end

-- #241 Pirouette Toss (Utility Opener)
makeThrowingWS(241, 'utility', 'WIND', 'Wind', xi.effect.EVASION_DOWN, 'Evasion Down', { 15,25,35,45,55,65 }, {
    s1Name = 'Opening Samba', f1Name = 'Pirouette Aim', a1Name = 'Zephyr Spin',
    f4Name = 'Grand Pirouette',
})

-- #242 Whirling Waltz (Light Magic + Heal)
makeThrowingWS(242, 'magic', 'LIGHT', 'Light', xi.effect.MAGIC_EVASION_DOWN, 'MEVA Down', { 10,16,22,28,34,40 }, {
    s1Name = 'Healing Waltz Spin', f1Name = 'Waltz Precision', a1Name = 'Radiant Arc',
    s4Name = 'Divine Waltz Halo',
})

-- #243 Ricochet Tango (3-Hit Multi-Hit)
makeThrowingWS(243, 'multihit', 'THUNDER', 'Thunder', xi.effect.DEFENSE_DOWN, 'DEF Down', { 5,9,13,17,21,25 }, {
    s1Name = 'Tango Leech', f1Name = 'Rebound Aim', a1Name = 'Spark Ring',
    f4Name = 'Endless Ricochet',
})

-- #244 Crimson Samba (Dark Magic + Drain)
makeThrowingWS(244, 'magic', 'DARK', 'Dark', xi.effect.ATTACK_DOWN, 'Atk Down', { 6,12,18,24,30,36 }, {
    s1Name = 'Crimson Drain', f1Name = 'Samba Precision', a1Name = 'Shadow Pulse',
    a4Name = 'Scarlet Samba',
})

-- #245 Stutter Disc (Utility + MEVA Down)
makeThrowingWS(245, 'utility', 'ICE', 'Ice', xi.effect.MAGIC_EVASION_DOWN, 'MEVA Down', { 12,18,24,30,36,42 }, {
    s1Name = 'Stutter Aspir', f1Name = 'Disc Precision', a1Name = 'Frost Disrupt',
    a4Name = 'Shattering Disc',
})

-- #246 Feathered Ring (Ranged Crit)
makeThrowingWS(246, 'crit', 'WIND', 'Wind', xi.effect.CRIT_HIT_EVASION_DOWN, 'Crit Eva Down', { 4,7,10,13,16,20 }, {
    s1Name = 'Feather Drain', f1Name = 'Falcon Aim', a1Name = 'Gale Feather',
    f4Name = 'Featherstorm',
})

-- #247 Bolero Cyclone (Wind AoE Magic)
makeThrowingWS(247, 'magic', 'WIND', 'Wind', xi.effect.SLOW, 'Slow', { 1500,1900,2300,2700,3100,3500 }, {
    s1Name = 'Cyclone Siphon', f1Name = 'Cyclone Aim', a1Name = 'Tempest Spin',
    a4Name = 'Gale Bolero',
})

-- #248 Flamenco Finale (Heavy Ranged Finisher)
makeThrowingWS(248, 'heavy', 'FIRE', 'Fire', xi.effect.DEFENSE_DOWN, 'DEF Down', { 6,10,14,18,22,26 }, {
    s1Name = 'Finale Drain', f1Name = 'Flamenco Aim', a1Name = 'Blaze Ring',
    f4Name = 'Grand Flamenco',
})

-- #249 Tarantella Storm (5-Hit Barrage)
makeThrowingWS(249, 'multihit', 'THUNDER', 'Thunder', xi.effect.PARALYSIS, 'Paralyze', { 10,15,20,25,30,35 }, {
    s1Name = 'Storm Drain', f1Name = 'Barrage Aim', a1Name = 'Volt Chakram',
    f4Name = 'Endless Storm',
})

-- #250 Grand Jete (Relic Heavy Finisher)
makeThrowingWS(250, 'heavy', 'LIGHT', 'Light', xi.effect.DEFENSE_DOWN, 'DEF Down', { 8,12,16,20,24,28 }, {
    s1Name = 'Relic Samba', f1Name = 'Relic Aim', a1Name = 'Astral Jete',
    f4Name = 'Relic Grand Jete',
})

-- #251 Aurora Fandango (Empyrean 4-Hit)
makeThrowingWS(251, 'multihit', 'ICE', 'Ice', xi.effect.EVASION_DOWN, 'Evasion Down', { 15,25,35,45,55,65 }, {
    s1Name = 'Aurora Samba', f1Name = 'Dawnlight Aim', a1Name = 'Aurora Frost',
    f4Name = 'Empyrean Aurora',
})

-- #252 Terpsichore's Halo (Mythic Light Finale)
makeThrowingWS(252, 'magic', 'LIGHT', 'Light', xi.effect.MAGIC_DEF_DOWN, 'MDEF Down', { 8,14,20,26,32,38 }, {
    s1Name = 'Muse Samba', f1Name = 'Muse Aim', a1Name = 'Muse Radiance',
    a4Name = 'Mythic Halo',
})
