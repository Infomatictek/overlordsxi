-----------------------------------
-- OverlordsXI Bespoke Weaponskill Trees: Throwing / Dancer Bladewheel (#241 - #252)
-----------------------------------
-- 12 bespoke 3-column talent trees for the Dancer Chakram / Bladewheel kit:
--
-- Physical Single-Hit Throwing WSs (Massive fTP scaling across T1-T4, ZERO magic filler):
--   #241 Pirouette Toss      (1-hit Opener, DEX 40% / AGI 20%, +1-2 Finishing Moves)
--   #245 Stutter Disc        (1-hit Debuff/Breach, AGI 40% / CHR 20%, MEVA/DEF Shred)
--   #246 Feathered Ring      (1-hit Critical, DEX 60%, Crit Rate + Bewildered Daze)
--   #248 Flamenco Finale     (1-hit Heavy Finisher, DEX 40% / CHR 40%, FM Scaling)
--   #250 Grand Jete          (1-hit Relic Finisher, DEX 60% / AGI 20%, DEF Down 20%)
--
-- Physical Multi-Hit Throwing WSs (Early T1 fTP Transfer + fTP Increases + Bonus Hits):
--   #243 Ricochet Tango      (3-hit Banked Multi-Hit, DEX 50%, T1 fTP Transfer + fTP + Hits)
--   #249 Tarantella Storm    (5-hit Crit Barrage, DEX 50%, T1 fTP Transfer + fTP + Crit)
--   #251 Aurora Fandango     (4-hit Empyrean Barrage, DEX 40% / CHR 40%, T1 fTP Transfer + fTP)
--
-- Magical Single-Hit Throwing WSs (High Single-Hit fTP Scaling + Elemental / Waltz Mastery):
--   #242 Whirling Waltz      (Light Elemental + Party Waltz Heal, CHR 50% / DEX 20%)
--   #244 Crimson Samba       (Dark Elemental + Vampiric Drain, CHR 40% / INT 20%)
--   #247 Bolero Cyclone      (Wind Elemental + Evasion Down Cyclone, CHR 40% / AGI 30%)
--   #252 Terpsichore's Halo  (Mythic Light Elemental + Dancer Regalia, CHR 60% / DEX 30%)
-----------------------------------
require('modules/custom/lua/overlords_ws_tree_helpers')
-----------------------------------
local h    = xi.overlords.wsTreeHelpers
local regB = h.regB
local N    = h.N

---------------------------------------------------------------------------
-- #241 PIROUETTE TOSS (Physical Ranged 1-Hit Opener, DEX 40% / AGI 20%, +1-2 FM)
-- Col 1: Choreographed Momentum (TP Return, Party TP, Haste & Store TP)
-- Col 2: Spinning Apex (Massive Single-Hit fTP Scaling + DEX/AGI WSC)
-- Col 3: Opening Breach (Ranged Atk/Acc, DEF Ignore & Follow-up WS Power)
---------------------------------------------------------------------------
regB(241, 'heavy',
{
    -- Tier 1
    N('c1_t1', 'Opening Rhythm', 1, 1, 6, nil,
        '+4..24 R.Acc, +4..24 Store TP on WS',
        function(r) return string.format('+%d R.Acc, +%d Store TP on WS', r * 4, r * 4) end,
        { racc = { 4, 8, 12, 16, 20, 24 }, storeTp = { 4, 8, 12, 16, 20, 24 } }),
    N('c2_t1', 'Pirouette Velocity', 1, 2, 7, nil,
        '+0.60..4.50 Single-Hit fTP, +4..28% DEX WSC',
        function(r)
            local f = ({ 0.60, 1.20, 1.80, 2.40, 3.10, 3.80, 4.50 })[r]
            return string.format('+%.2f fTP, +%d%% DEX WSC', f, r * 4)
        end,
        {
            ftpAdd = { 0.60, 1.20, 1.80, 2.40, 3.10, 3.80, 4.50 },
            wsc    = { dex = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Edge Release', 1, 3, 7, nil,
        '+6..42% R.Atk, +0.30..2.10 fTP',
        function(r) return string.format('+%d%% R.Atk, +%.2f fTP', r * 6, r * 0.30) end,
        {
            atkPct = { 6, 12, 18, 24, 30, 36, 42 },
            ftpAdd = { 0.30, 0.60, 0.90, 1.20, 1.50, 1.80, 2.10 },
        }),

    -- Tier 2
    N('c1_t2', 'Dancer\'s Tempo', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants +4..20% Haste and +5..25 Store TP (30s) after WS',
        function(r) return string.format('+%d%% Haste, +%d Store TP (30s)', r * 4, r * 5) end,
        {
            postBuff = {
                effect   = xi.effect.HASTE,
                duration = 30,
                mods     = { [xi.mod.HASTE_MAGIC] = { 400, 800, 1200, 1600, 2000 }, [xi.mod.STORETP] = { 5, 10, 15, 20, 25 } },
            },
        }),
    N('c2_t2', 'Gyroscopic Torque', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.50..2.75 Single-Hit fTP, +5..25% AGI WSC',
        function(r)
            local f = ({ 0.50, 1.00, 1.55, 2.15, 2.75 })[r]
            return string.format('+%.2f fTP, +%d%% AGI WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.50, 1.00, 1.55, 2.15, 2.75 },
            wsc    = { agi = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Slicing Entry', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        'Ignores 7..35% DEF, +4..20% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 7, r * 4) end,
        { defIgnore = { 0.07, 0.14, 0.21, 0.28, 0.35 }, wsd = { 4, 8, 12, 16, 20 } }),

    -- Tier 3
    N('c1_t3', 'Troupe Opener', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Grants 40..200 TP to party members and +50..250 TP Bonus',
        function(r) return string.format('+%d Party TP, +%d TP Bonus', r * 40, r * 50) end,
        { partyTp = { 40, 80, 120, 160, 200 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c2_t3', 'Centrifugal Drive', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.60..3.25 Single-Hit fTP, +5..25% Crit Rate',
        function(r)
            local f = ({ 0.60, 1.20, 1.85, 2.55, 3.25 })[r]
            return string.format('+%.2f fTP, +%d%% Crit Rate', f, r * 5)
        end,
        { ftpAdd = { 0.60, 1.20, 1.85, 2.55, 3.25 }, crit = { 0.05, 0.10, 0.15, 0.20, 0.25 } }),
    N('c3_t3', 'Setup Flourish', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        'Next WS within 15s gains +10..50% WSD and +80..400 TP refund',
        function(r) return string.format('Next WS: +%d%% WSD, +%d TP', r * 10, r * 80) end,
        { nextWs = { wsd = { 10, 20, 30, 40, 50 }, tp = { 80, 160, 240, 320, 400 }, dur = 15 } }),

    -- Tier 4
    N('c1_t4', 'Encore Spin', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Refunds 120..360 TP and heals self for 8..24% Max HP',
        function(r) return string.format('+%d TP Refund, %d%% Max HP Heal', r * 120, r * 8) end,
        { nextWs = { tp = { 120, 240, 360 }, dur = 15 }, selfMaxHpHealPct = { 8, 16, 24 } }),
    N('c2_t4', 'Pirouette Mastery', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.00..4.50 Single-Hit fTP, +8..32% WSD, +10..40% DEX WSC',
        function(r)
            local f = ({ 1.00, 2.10, 3.25, 4.50 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% DEX WSC', f, r * 8, r * 10)
        end,
        {
            ftpAdd = { 1.00, 2.10, 3.25, 4.50 },
            wsd    = { 8, 16, 24, 32 },
            wsc    = { dex = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Curtain Raiser', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.75..3.00 fTP, Ignores 10..40% DEF, +10..40% R.Atk',
        function(r) return string.format('+%.2f fTP, %d%% DEF Ign, +%d%% R.Atk', r * 0.75, r * 10, r * 10) end,
        {
            ftpAdd    = { 0.75, 1.50, 2.25, 3.00 },
            defIgnore = { 0.10, 0.20, 0.30, 0.40 },
            atkPct    = { 10, 20, 30, 40 },
        }),
})

---------------------------------------------------------------------------
-- #242 WHIRLING WALTZ (Magical Light 1-Hit + Party Heal, CHR 50% / DEX 20%)
-- Col 1: Curing Waltz Resonance (Party Heal %, Party Regen & Enmity Calm)
-- Col 2: Radiant Waltz fTP (Massive Single-Hit fTP Scaling + CHR/DEX WSC)
-- Col 3: Luminescent Chakra (MAB, MACC, WSD & Light Follow-up)
---------------------------------------------------------------------------
regB(242, 'magic',
{
    -- Tier 1
    N('c1_t1', 'Soothing Spin', 1, 1, 6, nil,
        'Heals party for 3..18% Max HP, -4..24 Enmity',
        function(r) return string.format('Party Heal %d%% Max HP, -%d Enmity', r * 3, r * 4) end,
        { partyHealPct = { 3, 6, 9, 12, 15, 18 }, enmity = { -4, -8, -12, -16, -20, -24 } }),
    N('c2_t1', 'Waltz Momentum', 1, 2, 7, nil,
        '+0.60..4.50 Single-Hit fTP, +4..28% CHR WSC',
        function(r)
            local f = ({ 0.60, 1.20, 1.80, 2.40, 3.10, 3.80, 4.50 })[r]
            return string.format('+%.2f fTP, +%d%% CHR WSC', f, r * 4)
        end,
        {
            ftpAdd = { 0.60, 1.20, 1.80, 2.40, 3.10, 3.80, 4.50 },
            wsc    = { chr = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Luminous Edge', 1, 3, 7, nil,
        '+5..35 MAB, +5..35 MACC on WS',
        function(r) return string.format('+%d MAB, +%d MACC', r * 5, r * 5) end,
        { matt = { 5, 10, 15, 20, 25, 30, 35 }, macc = { 5, 10, 15, 20, 25, 30, 35 } }),

    -- Tier 2
    N('c1_t2', 'Waltz of Renewal', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants Party Regen (6..30 HP/tick, 30s)',
        function(r) return string.format('Party Regen %d HP/tick (30s)', r * 6) end,
        { partyBuffs = { { effect = xi.effect.REGEN, power = { 6, 12, 18, 24, 30 }, duration = 30 } } }),
    N('c2_t2', 'Graceful Arc', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.55..3.00 Single-Hit fTP, +5..25% DEX WSC',
        function(r)
            local f = ({ 0.55, 1.10, 1.70, 2.35, 3.00 })[r]
            return string.format('+%.2f fTP, +%d%% DEX WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.55, 1.10, 1.70, 2.35, 3.00 },
            wsc    = { dex = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Prism Refraction', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        '+6..30 MAB, +4..20% WSD',
        function(r) return string.format('+%d MAB, +%d%% WSD', r * 6, r * 4) end,
        { matt = { 6, 12, 18, 24, 30 }, wsd = { 4, 8, 12, 16, 20 } }),

    -- Tier 3
    N('c1_t3', 'Divine Ballroom', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Heals party for +4..20% Max HP and grants 30..150 Party TP',
        function(r) return string.format('+%d%% Party Heal, +%d Party TP', r * 4, r * 30) end,
        { partyHealPct = { 4, 8, 12, 16, 20 }, partyTp = { 30, 60, 90, 120, 150 } }),
    N('c2_t3', 'Sunlit Crescendo', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.65..3.50 Single-Hit fTP, +50..250 TP Bonus',
        function(r)
            local f = ({ 0.65, 1.30, 2.00, 2.75, 3.50 })[r]
            return string.format('+%.2f fTP, +%d TP Bonus', f, r * 50)
        end,
        { ftpAdd = { 0.65, 1.30, 2.00, 2.75, 3.50 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c3_t3', 'Solar Trail', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        'Deals +7..35% Light elemental follow-up damage',
        function(r) return string.format('+%d%% Light Follow-up DMG', r * 7) end,
        { elemFollow = { ele = xi.element.LIGHT, pct = { 7, 14, 21, 28, 35 } } }),

    -- Tier 4
    N('c1_t4', 'Sanctuary Waltz', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Grants Party Refresh (3..9 MP/tick, 30s) and +8..24% Self Max HP Heal',
        function(r) return string.format('Party Refresh %d MP/t, +%d%% Self Heal', r * 3, r * 8) end,
        {
            partyBuffs       = { { effect = xi.effect.REFRESH, power = { 3, 6, 9 }, duration = 30 } },
            selfMaxHpHealPct = { 8, 16, 24 },
        }),
    N('c2_t4', 'Grand Waltz Finale', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.10..4.75 Single-Hit fTP, +8..32% WSD, +10..40% CHR WSC',
        function(r)
            local f = ({ 1.10, 2.25, 3.50, 4.75 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% CHR WSC', f, r * 8, r * 10)
        end,
        {
            ftpAdd = { 1.10, 2.25, 3.50, 4.75 },
            wsd    = { 8, 16, 24, 32 },
            wsc    = { chr = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Dawnlight Surge', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.75..3.00 fTP, +10..40 MAB, +8..32% Light Follow-up',
        function(r) return string.format('+%.2f fTP, +%d MAB, +%d%% Light DMG', r * 0.75, r * 10, r * 8) end,
        {
            ftpAdd     = { 0.75, 1.50, 2.25, 3.00 },
            matt       = { 10, 20, 30, 40 },
            elemFollow = { ele = xi.element.LIGHT, pct = { 8, 16, 24, 32 } },
        }),
})

---------------------------------------------------------------------------
-- #243 RICOCHET TANGO (Physical Ranged 3-Hit Multi-Hit, DEX 50%)
-- Col 1: Banked Rebound (R.Acc, Store TP, Haste & TP Return)
-- Col 2: Early fTP Transfer & Multi-Hit Scaling (T1 fTP Transfer + fTP + Bonus Hits!)
-- Col 3: Shrapnel Angles (fTP Increases + DEF Ignore + Crit & R.Atk)
---------------------------------------------------------------------------
regB(243, 'multihit',
{
    -- Tier 1: Opens fTP Transfer immediately at Rank 1 of Col 2 + fTP increases!
    N('c1_t1', 'Banked Trajectory', 1, 1, 6, nil,
        '+5..30 R.Acc, +4..24 Store TP on WS',
        function(r) return string.format('+%d R.Acc, +%d Store TP', r * 5, r * 4) end,
        { racc = { 5, 10, 15, 20, 25, 30 }, storeTp = { 4, 8, 12, 16, 20, 24 } }),
    N('c2_t1', 'Ricochet Transfer', 1, 2, 7, nil,
        'R1: fTP Transfers to ALL Hits! +0.35..2.80 fTP, +4..28% DEX WSC',
        function(r)
            local f = ({ 0.35, 0.70, 1.10, 1.50, 1.90, 2.35, 2.80 })[r]
            return string.format('fTP ALL Hits, +%.2f fTP, +%d%% DEX WSC', f, r * 4)
        end,
        {
            multiHitfTPAt = 1,
            ftpAdd        = { 0.35, 0.70, 1.10, 1.50, 1.90, 2.35, 2.80 },
            wsc           = { dex = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Razor Carom', 1, 3, 7, nil,
        '+0.25..1.75 fTP, +6..42% R.Atk',
        function(r) return string.format('+%.2f fTP, +%d%% R.Atk', r * 0.25, r * 6) end,
        {
            ftpAdd = { 0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75 },
            atkPct = { 6, 12, 18, 24, 30, 36, 42 },
        }),

    -- Tier 2
    N('c1_t2', 'Tango Cadence', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants +4..20% Haste and +10..50 R.Acc (30s) after WS',
        function(r) return string.format('+%d%% Haste, +%d R.Acc (30s)', r * 4, r * 10) end,
        {
            postBuff = {
                effect   = xi.effect.HASTE,
                duration = 30,
                mods     = { [xi.mod.HASTE_MAGIC] = { 400, 800, 1200, 1600, 2000 }, [xi.mod.RACC] = { 10, 20, 30, 40, 50 } },
            },
        }),
    N('c2_t2', 'Double Rebound', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.35..1.75 fTP, +1 Hit at R3, +2 Hits at R5',
        function(r)
            local hAdd = r >= 5 and 2 or (r >= 3 and 1 or 0)
            return string.format('+%.2f fTP%s', r * 0.35, hAdd > 0 and string.format(', +%d Hit(s)', hAdd) or '')
        end,
        {
            ftpAdd    = { 0.35, 0.70, 1.05, 1.40, 1.75 },
            bonusHits = { 0, 0, 1, 1, 2 },
        }),
    N('c3_t2', 'Armor Deflection', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        'Ignores 6..30% DEF, +4..20% Crit Rate',
        function(r) return string.format('Ignores %d%% DEF, +%d%% Crit Rate', r * 6, r * 4) end,
        { defIgnore = { 0.06, 0.12, 0.18, 0.24, 0.30 }, crit = { 0.04, 0.08, 0.12, 0.16, 0.20 } }),

    -- Tier 3
    N('c1_t3', 'Catch & Release', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Refunds 50..250 TP after WS, +50..250 TP Bonus',
        function(r) return string.format('+%d TP Refund, +%d TP Bonus', r * 50, r * 50) end,
        { nextWs = { tp = { 50, 100, 150, 200, 250 }, dur = 15 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c2_t3', 'Pinball Volley', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.40..2.00 fTP, +5..25% AGI WSC, +4..20% WSD',
        function(r) return string.format('+%.2f fTP, +%d%% AGI WSC, +%d%% WSD', r * 0.40, r * 5, r * 4) end,
        {
            ftpAdd = { 0.40, 0.80, 1.20, 1.60, 2.00 },
            wsc    = { agi = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
            wsd    = { 4, 8, 12, 16, 20 },
        }),
    N('c3_t3', 'Serrated Rim', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        '+4..20% Crit DMG, Inflicts -8..40 DEF Down (45s)',
        function(r) return string.format('+%d%% Crit DMG, -%d DEF Down (45s)', r * 4, r * 8) end,
        {
            critDmg       = { 4, 8, 12, 16, 20 },
            targetDebuffs = { { effect = xi.effect.DEFENSE_DOWN, power = { 8, 16, 24, 32, 40 }, duration = 45 } },
        }),

    -- Tier 4
    N('c1_t4', 'Endless Tango', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Grants 60..180 Party TP and +8..24% Next WS WSD',
        function(r) return string.format('+%d Party TP, Next WS +%d%% WSD', r * 60, r * 8) end,
        { partyTp = { 60, 120, 180 }, nextWs = { wsd = { 8, 16, 24 }, dur = 15 } }),
    N('c2_t4', 'Infinite Ricochet', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+0.60..2.40 fTP (All Hits), +1 Bonus Hit at R2 & R4, +6..24% WSD',
        function(r)
            local hAdd = r >= 4 and 2 or (r >= 2 and 1 or 0)
            return string.format('+%.2f fTP, +%d Hit(s), +%d%% WSD', r * 0.60, hAdd, r * 6)
        end,
        {
            ftpAdd    = { 0.60, 1.20, 1.80, 2.40 },
            bonusHits = { 0, 1, 1, 2 },
            wsd       = { 6, 12, 18, 24 },
        }),
    N('c3_t4', 'Lethal Geometry', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.50..2.00 fTP, Ignores 8..32% DEF, +8..32% DEX WSC',
        function(r) return string.format('+%.2f fTP, %d%% DEF Ign, +%d%% DEX WSC', r * 0.50, r * 8, r * 8) end,
        {
            ftpAdd    = { 0.50, 1.00, 1.50, 2.00 },
            defIgnore = { 0.08, 0.16, 0.24, 0.32 },
            wsc       = { dex = { 0.08, 0.16, 0.24, 0.32 } },
        }),
})

---------------------------------------------------------------------------
-- #244 CRIMSON SAMBA (Magical Dark 1-Hit + HP Drain, CHR 40% / INT 20%)
-- Col 1: Sanguine Feast (HP Drain %, MP Drain %, Self Max HP Heal)
-- Col 2: Blood-Moon fTP (Massive Single-Hit fTP Scaling + CHR/INT WSC)
-- Col 3: Umbral Chakram (MAB, MACC, Dark Follow-up & Dispel)
---------------------------------------------------------------------------
regB(244, 'magic',
{
    -- Tier 1
    N('c1_t1', 'Sanguine Sip', 1, 1, 6, nil,
        'Drains 5..30% of WS damage as HP, +3..18 Subtle Blow',
        function(r) return string.format('%d%% HP Drain, +%d Subtle Blow', r * 5, r * 3) end,
        { hpDrain = { 5, 10, 15, 20, 25, 30 }, subtleBlow = { 3, 6, 9, 12, 15, 18 } }),
    N('c2_t1', 'Crimson Velocity', 1, 2, 7, nil,
        '+0.60..4.50 Single-Hit fTP, +4..28% CHR WSC',
        function(r)
            local f = ({ 0.60, 1.20, 1.80, 2.40, 3.10, 3.80, 4.50 })[r]
            return string.format('+%.2f fTP, +%d%% CHR WSC', f, r * 4)
        end,
        {
            ftpAdd = { 0.60, 1.20, 1.80, 2.40, 3.10, 3.80, 4.50 },
            wsc    = { chr = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Dusk Edge', 1, 3, 7, nil,
        '+5..35 MAB, +5..35 MACC on WS',
        function(r) return string.format('+%d MAB, +%d MACC', r * 5, r * 5) end,
        { matt = { 5, 10, 15, 20, 25, 30, 35 }, macc = { 5, 10, 15, 20, 25, 30, 35 } }),

    -- Tier 2
    N('c1_t2', 'Essence Siphon', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Drains 3..15% of WS damage as MP and 20..100 TP from target',
        function(r) return string.format('%d%% MP Drain, %d TP Drain', r * 3, r * 20) end,
        { mpDrain = { 3, 6, 9, 12, 15 }, tpDrain = { 20, 40, 60, 80, 100 } }),
    N('c2_t2', 'Scarlet Spiral', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.55..3.00 Single-Hit fTP, +5..25% INT WSC',
        function(r)
            local f = ({ 0.55, 1.10, 1.70, 2.35, 3.00 })[r]
            return string.format('+%.2f fTP, +%d%% INT WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.55, 1.10, 1.70, 2.35, 3.00 },
            wsc    = { int = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Shadow Amp', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        '+6..30 MAB, +4..20% WSD',
        function(r) return string.format('+%d MAB, +%d%% WSD', r * 6, r * 4) end,
        { matt = { 6, 12, 18, 24, 30 }, wsd = { 4, 8, 12, 16, 20 } }),

    -- Tier 3
    N('c1_t3', 'Blood Samba Surge', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Heals party for 3..15% Max HP and drains +5..25% HP',
        function(r) return string.format('Party Heal %d%% Max HP, +%d%% HP Drain', r * 3, r * 5) end,
        { partyHealPct = { 3, 6, 9, 12, 15 }, hpDrain = { 5, 10, 15, 20, 25 } }),
    N('c2_t3', 'Nocturne Torque', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.65..3.50 Single-Hit fTP, +50..250 TP Bonus',
        function(r)
            local f = ({ 0.65, 1.30, 2.00, 2.75, 3.50 })[r]
            return string.format('+%.2f fTP, +%d TP Bonus', f, r * 50)
        end,
        { ftpAdd = { 0.65, 1.30, 2.00, 2.75, 3.50 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c3_t3', 'Abyssal Wake', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        'Deals +7..35% Dark elemental follow-up damage and dispels at R5',
        function(r) return string.format('+%d%% Dark Follow-up%s', r * 7, r >= 5 and ', Dispel 1 Buff' or '') end,
        { elemFollow = { ele = xi.element.DARK, pct = { 7, 14, 21, 28, 35 } }, dispel = { 0, 0, 0, 0, 1 } }),

    -- Tier 4
    N('c1_t4', 'Immortal Samba', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Drains +10..30% HP, +6..18% MP, and grants Party Regen (8..24 HP/t)',
        function(r) return string.format('+%d%% HP/+%d%% MP Drain, Party Regen %d', r * 10, r * 6, r * 8) end,
        {
            hpDrain    = { 10, 20, 30 },
            mpDrain    = { 6, 12, 18 },
            partyBuffs = { { effect = xi.effect.REGEN, power = { 8, 16, 24 }, duration = 30 } },
        }),
    N('c2_t4', 'Crimson Eclipse', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.10..4.75 Single-Hit fTP, +8..32% WSD, +10..40% CHR WSC',
        function(r)
            local f = ({ 1.10, 2.25, 3.50, 4.75 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% CHR WSC', f, r * 8, r * 10)
        end,
        {
            ftpAdd = { 1.10, 2.25, 3.50, 4.75 },
            wsd    = { 8, 16, 24, 32 },
            wsc    = { chr = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Vampiric Horizon', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.75..3.00 fTP, +10..40 MAB, +8..32% Dark Follow-up',
        function(r) return string.format('+%.2f fTP, +%d MAB, +%d%% Dark DMG', r * 0.75, r * 10, r * 8) end,
        {
            ftpAdd     = { 0.75, 1.50, 2.25, 3.00 },
            matt       = { 10, 20, 30, 40 },
            elemFollow = { ele = xi.element.DARK, pct = { 8, 16, 24, 32 } },
        }),
})

---------------------------------------------------------------------------
-- #245 STUTTER DISC (Physical Ranged 1-Hit Debuff/Breach, AGI 40% / CHR 20%)
-- Col 1: Hexing Step (DEF Down, EVA Down, Slow, Dispel & TP Steal)
-- Col 2: Stutter Impact fTP (Massive Single-Hit fTP Scaling + AGI/CHR WSC)
-- Col 3: Armor Shatter (DEF Ignore, R.Atk%, R.Acc & WSD — ZERO magic filler!)
---------------------------------------------------------------------------
regB(245, 'heavy',
{
    -- Tier 1
    N('c1_t1', 'Faltering Guard', 1, 1, 6, nil,
        'Inflicts -6..36 Defense Down and -6..36 Evasion Down (45s)',
        function(r) return string.format('-%d DEF Down, -%d EVA Down (45s)', r * 6, r * 6) end,
        {
            targetDebuffs = {
                { effect = xi.effect.DEFENSE_DOWN, power = { 6, 12, 18, 24, 30, 36 }, duration = 45 },
                { effect = xi.effect.EVASION_DOWN, power = { 6, 12, 18, 24, 30, 36 }, duration = 45 },
            },
        }),
    N('c2_t1', 'Stutter Impulse', 1, 2, 7, nil,
        '+0.65..4.75 Single-Hit fTP, +4..28% AGI WSC',
        function(r)
            local f = ({ 0.65, 1.30, 1.95, 2.60, 3.30, 4.00, 4.75 })[r]
            return string.format('+%.2f fTP, +%d%% AGI WSC', f, r * 4)
        end,
        {
            ftpAdd = { 0.65, 1.30, 1.95, 2.60, 3.30, 4.00, 4.75 },
            wsc    = { agi = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Pinpoint Throw', 1, 3, 7, nil,
        '+6..42 R.Acc, +6..42% R.Atk, +0.25..1.75 fTP',
        function(r) return string.format('+%d R.Acc, +%d%% R.Atk, +%.2f fTP', r * 6, r * 6, r * 0.25) end,
        {
            racc   = { 6, 12, 18, 24, 30, 36, 42 },
            atkPct = { 6, 12, 18, 24, 30, 36, 42 },
            ftpAdd = { 0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75 },
        }),

    -- Tier 2
    N('c1_t2', 'Hamstring Spin', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Inflicts 6..30% Slow (45s) and steals 20..100 TP from target',
        function(r) return string.format('%d%% Slow (45s), %d TP Drain', r * 6, r * 20) end,
        {
            targetDebuffs = { { effect = xi.effect.SLOW, power = { 600, 1200, 1800, 2400, 3000 }, duration = 45 } },
            tpDrain       = { 20, 40, 60, 80, 100 },
        }),
    N('c2_t2', 'Discordant Torque', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.55..3.00 Single-Hit fTP, +5..25% CHR WSC',
        function(r)
            local f = ({ 0.55, 1.10, 1.70, 2.35, 3.00 })[r]
            return string.format('+%.2f fTP, +%d%% CHR WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.55, 1.10, 1.70, 2.35, 3.00 },
            wsc    = { chr = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Plate Cracker', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        'Ignores 8..40% DEF, +4..20% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 8, r * 4) end,
        { defIgnore = { 0.08, 0.16, 0.24, 0.32, 0.40 }, wsd = { 4, 8, 12, 16, 20 } }),

    -- Tier 3
    N('c1_t3', 'Shatter Enchantment', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Dispels 1 buff (2 at R5) and inflicts -6..30% Attack Down (45s)',
        function(r) return string.format('Dispel %d Buff(s), -%d%% ATK Down', r >= 5 and 2 or 1, r * 6) end,
        {
            dispel        = { 1, 1, 1, 1, 2 },
            targetDebuffs = { { effect = xi.effect.ATTACK_DOWN, power = { 6, 12, 18, 24, 30 }, duration = 45 } },
        }),
    N('c2_t3', 'Syncopated Impact', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.65..3.50 Single-Hit fTP, +50..250 TP Bonus',
        function(r)
            local f = ({ 0.65, 1.30, 2.00, 2.75, 3.50 })[r]
            return string.format('+%.2f fTP, +%d TP Bonus', f, r * 50)
        end,
        { ftpAdd = { 0.65, 1.30, 2.00, 2.75, 3.50 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c3_t3', 'Exposed Flank', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        '+5..25% Crit Rate, +5..25% Crit DMG',
        function(r) return string.format('+%d%% Crit Rate, +%d%% Crit DMG', r * 5, r * 5) end,
        { crit = { 0.05, 0.10, 0.15, 0.20, 0.25 }, critDmg = { 5, 10, 15, 20, 25 } }),

    -- Tier 4
    N('c1_t4', 'Total Breakdown', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Steals 12..36% of target TP and grants 60..180 Party TP',
        function(r) return string.format('Steals %d%% Target TP, +%d Party TP', r * 12, r * 60) end,
        { tpStealPct = { 12, 24, 36 }, partyTp = { 60, 120, 180 } }),
    N('c2_t4', 'Stutter Annihilation', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.15..5.00 Single-Hit fTP, +8..32% WSD, +10..40% AGI WSC',
        function(r)
            local f = ({ 1.15, 2.40, 3.70, 5.00 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% AGI WSC', f, r * 8, r * 10)
        end,
        {
            ftpAdd = { 1.15, 2.40, 3.70, 5.00 },
            wsd    = { 8, 16, 24, 32 },
            wsc    = { agi = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Nullifying Cleave', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.80..3.20 fTP, Ignores 10..40% DEF, +10..40% R.Atk',
        function(r) return string.format('+%.2f fTP, %d%% DEF Ign, +%d%% R.Atk', r * 0.80, r * 10, r * 10) end,
        {
            ftpAdd    = { 0.80, 1.60, 2.40, 3.20 },
            defIgnore = { 0.10, 0.20, 0.30, 0.40 },
            atkPct    = { 10, 20, 30, 40 },
        }),
})

---------------------------------------------------------------------------
-- #246 FEATHERED RING (Physical Ranged 1-Hit Critical, DEX 60%, Crit Rate + Daze)
-- Col 1: Plumed Precision (R.Acc, Subtle Blow, Evasion Down & Haste)
-- Col 2: Razor Plume fTP (Massive Single-Hit fTP Scaling + DEX WSC)
-- Col 3: Heartseeker Ring (Crit Rate, Crit DMG, DEF Ignore & WSD — ZERO magic!)
---------------------------------------------------------------------------
regB(246, 'crit',
{
    -- Tier 1
    N('c1_t1', 'Feather Balance', 1, 1, 6, nil,
        '+6..36 R.Acc, +4..24 Subtle Blow',
        function(r) return string.format('+%d R.Acc, +%d Subtle Blow', r * 6, r * 4) end,
        { racc = { 6, 12, 18, 24, 30, 36 }, subtleBlow = { 4, 8, 12, 16, 20, 24 } }),
    N('c2_t1', 'Plumed Velocity', 1, 2, 7, nil,
        '+0.65..4.75 Single-Hit fTP, +5..35% DEX WSC',
        function(r)
            local f = ({ 0.65, 1.30, 1.95, 2.60, 3.30, 4.00, 4.75 })[r]
            return string.format('+%.2f fTP, +%d%% DEX WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.65, 1.30, 1.95, 2.60, 3.30, 4.00, 4.75 },
            wsc    = { dex = { 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35 } },
        }),
    N('c3_t1', 'Keen Quills', 1, 3, 7, nil,
        '+4..28% Crit Rate, +3..21% Crit DMG, +0.25..1.75 fTP',
        function(r) return string.format('+%d%% Crit, +%d%% Crit DMG, +%.2f fTP', r * 4, r * 3, r * 0.25) end,
        {
            crit    = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 },
            critDmg = { 3, 6, 9, 12, 15, 18, 21 },
            ftpAdd  = { 0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75 },
        }),

    -- Tier 2
    N('c1_t2', 'Bewildering Plume', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Inflicts -10..50 Evasion Down (45s) and grants +4..20% Haste (30s)',
        function(r) return string.format('-%d EVA Down (45s), +%d%% Haste (30s)', r * 10, r * 4) end,
        {
            targetDebuffs = { { effect = xi.effect.EVASION_DOWN, power = { 10, 20, 30, 40, 50 }, duration = 45 } },
            postBuff      = { effect = xi.effect.HASTE, duration = 30, mods = { [xi.mod.HASTE_MAGIC] = { 400, 800, 1200, 1600, 2000 } } },
        }),
    N('c2_t2', 'Aero-Ring Spin', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.60..3.25 Single-Hit fTP, +5..25% AGI WSC',
        function(r)
            local f = ({ 0.60, 1.20, 1.85, 2.55, 3.25 })[r]
            return string.format('+%.2f fTP, +%d%% AGI WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.60, 1.20, 1.85, 2.55, 3.25 },
            wsc    = { agi = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Vital Seam', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        'Ignores 7..35% DEF, +5..25% Crit DMG',
        function(r) return string.format('Ignores %d%% DEF, +%d%% Crit DMG', r * 7, r * 5) end,
        { defIgnore = { 0.07, 0.14, 0.21, 0.28, 0.35 }, critDmg = { 5, 10, 15, 20, 25 } }),

    -- Tier 3
    N('c1_t3', 'Dancer\'s Poise', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Refunds 50..250 TP after WS and grants +50..250 TP Bonus',
        function(r) return string.format('+%d TP Refund, +%d TP Bonus', r * 50, r * 50) end,
        { nextWs = { tp = { 50, 100, 150, 200, 250 }, dur = 15 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c2_t3', 'Swallowtail Drive', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.70..3.75 Single-Hit fTP, +5..25% WSD',
        function(r)
            local f = ({ 0.70, 1.40, 2.15, 2.95, 3.75 })[r]
            return string.format('+%.2f fTP, +%d%% WSD', f, r * 5)
        end,
        { ftpAdd = { 0.70, 1.40, 2.15, 2.95, 3.75 }, wsd = { 5, 10, 15, 20, 25 } }),
    N('c3_t3', 'Arterial Edge', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        '+5..25% Crit Rate, +8..40% R.Atk',
        function(r) return string.format('+%d%% Crit Rate, +%d%% R.Atk', r * 5, r * 8) end,
        { crit = { 0.05, 0.10, 0.15, 0.20, 0.25 }, atkPct = { 8, 16, 24, 32, 40 } }),

    -- Tier 4
    N('c1_t4', 'Featherstorm Tempo', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Grants 60..180 Party TP and heals self for 8..24% Max HP',
        function(r) return string.format('+%d Party TP, %d%% Self Max HP Heal', r * 60, r * 8) end,
        { partyTp = { 60, 120, 180 }, selfMaxHpHealPct = { 8, 16, 24 } }),
    N('c2_t4', 'Phoenix Ring Apex', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.20..5.25 Single-Hit fTP, +8..32% WSD, +10..40% DEX WSC',
        function(r)
            local f = ({ 1.20, 2.50, 3.85, 5.25 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% DEX WSC', f, r * 8, r * 10)
        end,
        {
            ftpAdd = { 1.20, 2.50, 3.85, 5.25 },
            wsd    = { 8, 16, 24, 32 },
            wsc    = { dex = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Deadeye Plume', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.85..3.40 fTP, +8..32% Crit DMG, Ignores 10..40% DEF',
        function(r) return string.format('+%.2f fTP, +%d%% Crit DMG, %d%% DEF Ign', r * 0.85, r * 8, r * 10) end,
        {
            ftpAdd    = { 0.85, 1.70, 2.55, 3.40 },
            critDmg   = { 8, 16, 24, 32 },
            defIgnore = { 0.10, 0.20, 0.30, 0.40 },
        }),
})

---------------------------------------------------------------------------
-- #247 BOLERO CYCLONE (Magical Wind 1-Hit + Evasion Down, CHR 40% / AGI 30%)
-- Col 1: Gale Vortex (Evasion Down, Gravity, Silence & Pack/AoE Control)
-- Col 2: Cyclone fTP Scaling (Massive Single-Hit fTP Scaling + CHR/AGI WSC)
-- Col 3: Tempest Resonance (MAB, MACC, WSD & Wind Elemental Follow-up)
---------------------------------------------------------------------------
regB(247, 'magic',
{
    -- Tier 1
    N('c1_t1', 'Downdraft Spin', 1, 1, 6, nil,
        'Inflicts -7..42 Evasion Down (45s), +4..24 Store TP',
        function(r) return string.format('-%d EVA Down (45s), +%d Store TP', r * 7, r * 4) end,
        {
            targetDebuffs = { { effect = xi.effect.EVASION_DOWN, power = { 7, 14, 21, 28, 35, 42 }, duration = 45 } },
            storeTp       = { 4, 8, 12, 16, 20, 24 },
        }),
    N('c2_t1', 'Bolero Updraft', 1, 2, 7, nil,
        '+0.65..4.75 Single-Hit fTP, +4..28% CHR WSC',
        function(r)
            local f = ({ 0.65, 1.30, 1.95, 2.60, 3.30, 4.00, 4.75 })[r]
            return string.format('+%.2f fTP, +%d%% CHR WSC', f, r * 4)
        end,
        {
            ftpAdd = { 0.65, 1.30, 1.95, 2.60, 3.30, 4.00, 4.75 },
            wsc    = { chr = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Zephyr Edge', 1, 3, 7, nil,
        '+5..35 MAB, +5..35 MACC on WS',
        function(r) return string.format('+%d MAB, +%d MACC', r * 5, r * 5) end,
        { matt = { 5, 10, 15, 20, 25, 30, 35 }, macc = { 5, 10, 15, 20, 25, 30, 35 } }),

    -- Tier 2
    N('c1_t2', 'Gale Shear', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Inflicts Weight/Gravity (30s) and 6..30% Slow (45s)',
        function(r) return string.format('Gravity (30s), %d%% Slow (45s)', r * 6) end,
        {
            targetDebuffs = {
                { effect = xi.effect.WEIGHT, power = { 25, 30, 35, 40, 50 }, duration = 30 },
                { effect = xi.effect.SLOW,   power = { 600, 1200, 1800, 2400, 3000 }, duration = 45 },
            },
        }),
    N('c2_t2', 'Vortex Torque', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.60..3.25 Single-Hit fTP, +5..25% AGI WSC',
        function(r)
            local f = ({ 0.60, 1.20, 1.85, 2.55, 3.25 })[r]
            return string.format('+%.2f fTP, +%d%% AGI WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.60, 1.20, 1.85, 2.55, 3.25 },
            wsc    = { agi = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Squall Amplifier', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        '+6..30 MAB, +4..20% WSD',
        function(r) return string.format('+%d MAB, +%d%% WSD', r * 6, r * 4) end,
        { matt = { 6, 12, 18, 24, 30 }, wsd = { 4, 8, 12, 16, 20 } }),

    -- Tier 3
    N('c1_t3', 'Vacuum Choke', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Dispels 1 buff and grants +4..20% Haste (30s)',
        function(r) return string.format('Dispel 1 Buff, +%d%% Haste (30s)', r * 4) end,
        {
            dispel   = { 1, 1, 1, 1, 2 },
            postBuff = { effect = xi.effect.HASTE, duration = 30, mods = { [xi.mod.HASTE_MAGIC] = { 400, 800, 1200, 1600, 2000 } } },
        }),
    N('c2_t3', 'Eye of the Bolero', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.65..3.50 Single-Hit fTP, +50..250 TP Bonus',
        function(r)
            local f = ({ 0.65, 1.30, 2.00, 2.75, 3.50 })[r]
            return string.format('+%.2f fTP, +%d TP Bonus', f, r * 50)
        end,
        { ftpAdd = { 0.65, 1.30, 2.00, 2.75, 3.50 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c3_t3', 'Emerald Cyclone', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        'Deals +7..35% Wind elemental follow-up damage',
        function(r) return string.format('+%d%% Wind Follow-up DMG', r * 7) end,
        { elemFollow = { ele = xi.element.WIND, pct = { 7, 14, 21, 28, 35 } } }),

    -- Tier 4
    N('c1_t4', 'Tailwind Encore', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Grants 60..180 Party TP and refunds 100..300 TP',
        function(r) return string.format('+%d Party TP, +%d TP Refund', r * 60, r * 100) end,
        { partyTp = { 60, 120, 180 }, nextWs = { tp = { 100, 200, 300 }, dur = 15 } }),
    N('c2_t4', 'Supercell Finale', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.15..5.00 Single-Hit fTP, +8..32% WSD, +10..40% CHR WSC',
        function(r)
            local f = ({ 1.15, 2.40, 3.70, 5.00 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% CHR WSC', f, r * 8, r * 10)
        end,
        {
            ftpAdd = { 1.15, 2.40, 3.70, 5.00 },
            wsd    = { 8, 16, 24, 32 },
            wsc    = { chr = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Tempest Sovereign', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.80..3.20 fTP, +10..40 MAB, +8..32% Wind Follow-up',
        function(r) return string.format('+%.2f fTP, +%d MAB, +%d%% Wind DMG', r * 0.80, r * 10, r * 8) end,
        {
            ftpAdd     = { 0.80, 1.60, 2.40, 3.20 },
            matt       = { 10, 20, 30, 40 },
            elemFollow = { ele = xi.element.WIND, pct = { 8, 16, 24, 32 } },
        }),
})

---------------------------------------------------------------------------
-- #248 FLAMENCO FINALE (Physical Ranged 1-Hit Heavy Finisher, DEX 40% / CHR 40%)
-- Col 1: Standing Ovation (TP Bonus, TP Refund, Party TP & Finale Sustain)
-- Col 2: Grand Finale fTP (Colossal Single-Hit fTP Scaling + DEX/CHR WSC)
-- Col 3: Executioner's Stamp (DEF Ignore, R.Atk%, WSD & Crit DMG — ZERO magic!)
---------------------------------------------------------------------------
regB(248, 'heavy',
{
    -- Tier 1
    N('c1_t1', 'RhythmicClap', 1, 1, 6, nil,
        '+40..240 TP Bonus, +5..30 R.Acc',
        function(r) return string.format('+%d TP Bonus, +%d R.Acc', r * 40, r * 5) end,
        { tpBonus = { 40, 80, 120, 160, 200, 240 }, racc = { 5, 10, 15, 20, 25, 30 } }),
    N('c2_t1', 'Flamenco Crescendo', 1, 2, 7, nil,
        '+0.80..5.60 Single-Hit fTP, +4..28% DEX WSC',
        function(r)
            local f = ({ 0.80, 1.60, 2.40, 3.20, 4.00, 4.80, 5.60 })[r]
            return string.format('+%.2f fTP, +%d%% DEX WSC', f, r * 4)
        end,
        {
            ftpAdd = { 0.80, 1.60, 2.40, 3.20, 4.00, 4.80, 5.60 },
            wsc    = { dex = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Heel Stamp', 1, 3, 7, nil,
        '+7..49% R.Atk, +0.35..2.45 Single-Hit fTP',
        function(r) return string.format('+%d%% R.Atk, +%.2f fTP', r * 7, r * 0.35) end,
        {
            atkPct = { 7, 14, 21, 28, 35, 42, 49 },
            ftpAdd = { 0.35, 0.70, 1.05, 1.40, 1.75, 2.10, 2.45 },
        }),

    -- Tier 2
    N('c1_t2', 'Passionate Flourish', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Refunds 50..250 TP after WS and grants +5..25 Store TP (30s)',
        function(r) return string.format('+%d TP Refund, +%d Store TP (30s)', r * 50, r * 5) end,
        {
            nextWs   = { tp = { 50, 100, 150, 200, 250 }, dur = 15 },
            postBuff = { effect = xi.effect.STORE_TP, duration = 30, mods = { [xi.mod.STORETP] = { 5, 10, 15, 20, 25 } } },
        }),
    N('c2_t2', 'Duende Passion', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.70..3.75 Single-Hit fTP, +5..25% CHR WSC',
        function(r)
            local f = ({ 0.70, 1.40, 2.15, 2.95, 3.75 })[r]
            return string.format('+%.2f fTP, +%d%% CHR WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.70, 1.40, 2.15, 2.95, 3.75 },
            wsc    = { chr = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Armor Rend', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        'Ignores 8..40% DEF, +5..25% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 8, r * 5) end,
        { defIgnore = { 0.08, 0.16, 0.24, 0.32, 0.40 }, wsd = { 5, 10, 15, 20, 25 } }),

    -- Tier 3
    N('c1_t3', 'Bravura Applause', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Grants 50..250 Party TP and heals self for 4..20% Max HP',
        function(r) return string.format('+%d Party TP, %d%% Self Max HP Heal', r * 50, r * 4) end,
        { partyTp = { 50, 100, 150, 200, 250 }, selfMaxHpHealPct = { 4, 8, 12, 16, 20 } }),
    N('c2_t3', 'Compas Overdrive', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.80..4.25 Single-Hit fTP, +5..25% Crit Rate',
        function(r)
            local f = ({ 0.80, 1.60, 2.45, 3.35, 4.25 })[r]
            return string.format('+%.2f fTP, +%d%% Crit Rate', f, r * 5)
        end,
        { ftpAdd = { 0.80, 1.60, 2.45, 3.35, 4.25 }, crit = { 0.05, 0.10, 0.15, 0.20, 0.25 } }),
    N('c3_t3', 'Decisive Strike', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        '+5..25% Crit DMG, +8..40% R.Atk',
        function(r) return string.format('+%d%% Crit DMG, +%d%% R.Atk', r * 5, r * 8) end,
        { critDmg = { 5, 10, 15, 20, 25 }, atkPct = { 8, 16, 24, 32, 40 } }),

    -- Tier 4
    N('c1_t4', 'Encore Curtain', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Next WS within 15s gains +12..36% WSD and +120..360 TP refund',
        function(r) return string.format('Next WS: +%d%% WSD, +%d TP Refund', r * 12, r * 120) end,
        { nextWs = { wsd = { 12, 24, 36 }, tp = { 120, 240, 360 }, dur = 15 } }),
    N('c2_t4', 'Supreme Finale', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.50..6.00 Single-Hit fTP, +10..40% WSD, +10..40% CHR WSC',
        function(r) return string.format('+%.2f fTP, +%d%% WSD, +%d%% CHR WSC', r * 1.50, r * 10, r * 10) end,
        {
            ftpAdd = { 1.50, 3.00, 4.50, 6.00 },
            wsd    = { 10, 20, 30, 40 },
            wsc    = { chr = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Fatal Coup', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+1.00..4.00 fTP, Ignores 10..40% DEF, +8..32% Crit DMG',
        function(r) return string.format('+%.2f fTP, %d%% DEF Ign, +%d%% Crit DMG', r * 1.00, r * 10, r * 8) end,
        {
            ftpAdd    = { 1.00, 2.00, 3.00, 4.00 },
            defIgnore = { 0.10, 0.20, 0.30, 0.40 },
            critDmg   = { 8, 16, 24, 32 },
        }),
})

---------------------------------------------------------------------------
-- #249 TARANTELLA STORM (Physical Ranged 5-Hit Crit Barrage, DEX 50%)
-- Col 1: Frenzy Tempo (R.Acc, Haste, Store TP & TP Return)
-- Col 2: Early fTP Transfer & Storm Hits (T1 fTP Transfer + fTP + Bonus Hits!)
-- Col 3: Venomous Barrage (Crit Rate, Crit DMG, DEF Ignore & fTP — ZERO magic!)
---------------------------------------------------------------------------
regB(249, 'multihit',
{
    -- Tier 1: Opens fTP Transfer immediately at Rank 1 of Col 2 + fTP increases!
    N('c1_t1', 'Whirling Frenzy', 1, 1, 6, nil,
        '+5..30 R.Acc, +4..24 Store TP on WS',
        function(r) return string.format('+%d R.Acc, +%d Store TP', r * 5, r * 4) end,
        { racc = { 5, 10, 15, 20, 25, 30 }, storeTp = { 4, 8, 12, 16, 20, 24 } }),
    N('c2_t1', 'Tarantella Transfer', 1, 2, 7, nil,
        'R1: fTP Transfers to ALL Hits! +0.35..2.80 fTP, +4..28% DEX WSC',
        function(r)
            local f = ({ 0.35, 0.70, 1.10, 1.50, 1.90, 2.35, 2.80 })[r]
            return string.format('fTP ALL Hits, +%.2f fTP, +%d%% DEX WSC', f, r * 4)
        end,
        {
            multiHitfTPAt = 1,
            ftpAdd        = { 0.35, 0.70, 1.10, 1.50, 1.90, 2.35, 2.80 },
            wsc           = { dex = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Spider\'s Fang', 1, 3, 7, nil,
        '+4..28% Crit Rate, +0.25..1.75 fTP',
        function(r) return string.format('+%d%% Crit Rate, +%.2f fTP', r * 4, r * 0.25) end,
        {
            crit   = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 },
            ftpAdd = { 0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75 },
        }),

    -- Tier 2
    N('c1_t2', 'Delirium Rush', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants +5..25% Haste and +6..30 Store TP (30s) after WS',
        function(r) return string.format('+%d%% Haste, +%d Store TP (30s)', r * 5, r * 6) end,
        {
            postBuff = {
                effect   = xi.effect.HASTE,
                duration = 30,
                mods     = { [xi.mod.HASTE_MAGIC] = { 500, 1000, 1500, 2000, 2500 }, [xi.mod.STORETP] = { 6, 12, 18, 24, 30 } },
            },
        }),
    N('c2_t2', 'Relentless Swarm', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.35..1.75 fTP, +1 Hit at R3, +2 Hits at R5',
        function(r)
            local hAdd = r >= 5 and 2 or (r >= 3 and 1 or 0)
            return string.format('+%.2f fTP%s', r * 0.35, hAdd > 0 and string.format(', +%d Hit(s)', hAdd) or '')
        end,
        {
            ftpAdd    = { 0.35, 0.70, 1.05, 1.40, 1.75 },
            bonusHits = { 0, 0, 1, 1, 2 },
        }),
    N('c3_t2', 'Lacerating Storm', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        '+5..25% Crit DMG, Ignores 6..30% DEF',
        function(r) return string.format('+%d%% Crit DMG, Ignores %d%% DEF', r * 5, r * 6) end,
        { critDmg = { 5, 10, 15, 20, 25 }, defIgnore = { 0.06, 0.12, 0.18, 0.24, 0.30 } }),

    -- Tier 3
    N('c1_t3', 'Fevered Momentum', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Refunds 50..250 TP after WS and grants +50..250 TP Bonus',
        function(r) return string.format('+%d TP Refund, +%d TP Bonus', r * 50, r * 50) end,
        { nextWs = { tp = { 50, 100, 150, 200, 250 }, dur = 15 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c2_t3', 'Cyclonic Barrage', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.40..2.00 fTP, +5..25% AGI WSC, +4..20% WSD',
        function(r) return string.format('+%.2f fTP, +%d%% AGI WSC, +%d%% WSD', r * 0.40, r * 5, r * 4) end,
        {
            ftpAdd = { 0.40, 0.80, 1.20, 1.60, 2.00 },
            wsc    = { agi = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
            wsd    = { 4, 8, 12, 16, 20 },
        }),
    N('c3_t3', 'Thousand Cuts', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        '+8..40% R.Atk, +4..20% Crit Rate',
        function(r) return string.format('+%d%% R.Atk, +%d%% Crit Rate', r * 8, r * 4) end,
        { atkPct = { 8, 16, 24, 32, 40 }, crit = { 0.04, 0.08, 0.12, 0.16, 0.20 } }),

    -- Tier 4
    N('c1_t4', 'Contagious Rhythm', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Grants 70..210 Party TP and heals self for 8..24% Max HP',
        function(r) return string.format('+%d Party TP, %d%% Self Max HP Heal', r * 70, r * 8) end,
        { partyTp = { 70, 140, 210 }, selfMaxHpHealPct = { 8, 16, 24 } }),
    N('c2_t4', 'Apex Tarantella', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+0.65..2.60 fTP (All Hits), +1 Bonus Hit at R3, +6..24% WSD',
        function(r) return string.format('+%.2f fTP, %s+%d%% WSD', r * 0.65, r >= 3 and '+1 Hit, ' or '', r * 6) end,
        {
            ftpAdd    = { 0.65, 1.30, 1.95, 2.60 },
            bonusHits = { 0, 0, 1, 1 },
            wsd       = { 6, 12, 18, 24 },
        }),
    N('c3_t4', 'Death by Chakram', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.55..2.20 fTP, +8..32% Crit DMG, Ignores 8..32% DEF',
        function(r) return string.format('+%.2f fTP, +%d%% Crit DMG, %d%% DEF Ign', r * 0.55, r * 8, r * 8) end,
        {
            ftpAdd    = { 0.55, 1.10, 1.65, 2.20 },
            critDmg   = { 8, 16, 24, 32 },
            defIgnore = { 0.08, 0.16, 0.24, 0.32 },
        }),
})

---------------------------------------------------------------------------
-- #250 GRAND JETE (Physical Ranged 1-Hit Relic Finisher, DEX 60% / AGI 20%)
-- Col 1: Relic Afterglow (TP Bonus, Attack Buff, Party TP & Enmity Control)
-- Col 2: Soaring Leap fTP (Colossal Single-Hit fTP Scaling + DEX/AGI WSC)
-- Col 3: Skyfall Impact (DEF Ignore, R.Atk%, WSD & Crit — ZERO magic!)
---------------------------------------------------------------------------
regB(250, 'heavy',
{
    -- Tier 1
    N('c1_t1', 'Relic Poise', 1, 1, 6, nil,
        '+45..270 TP Bonus, -4..24 Enmity',
        function(r) return string.format('+%d TP Bonus, -%d Enmity', r * 45, r * 4) end,
        { tpBonus = { 45, 90, 135, 180, 225, 270 }, enmity = { -4, -8, -12, -16, -20, -24 } }),
    N('c2_t1', 'Grand Leap Velocity', 1, 2, 7, nil,
        '+0.90..6.30 Single-Hit fTP, +5..35% DEX WSC',
        function(r) return string.format('+%.2f fTP, +%d%% DEX WSC', r * 0.90, r * 5) end,
        {
            ftpAdd = { 0.90, 1.80, 2.70, 3.60, 4.50, 5.40, 6.30 },
            wsc    = { dex = { 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35 } },
        }),
    N('c3_t1', 'Meteor Descent', 1, 3, 7, nil,
        '+7..49% R.Atk, +0.40..2.80 Single-Hit fTP',
        function(r) return string.format('+%d%% R.Atk, +%.2f fTP', r * 7, r * 0.40) end,
        {
            atkPct = { 7, 14, 21, 28, 35, 42, 49 },
            ftpAdd = { 0.40, 0.80, 1.20, 1.60, 2.00, 2.40, 2.80 },
        }),

    -- Tier 2
    N('c1_t2', 'Etoile Afterglow', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants +6..30% Attack/R.Atk and +10..50 R.Acc (30s) after WS',
        function(r) return string.format('+%d%% R.Atk, +%d R.Acc (30s)', r * 6, r * 10) end,
        {
            postBuff = {
                effect   = xi.effect.ATTACK_BOOST,
                duration = 30,
                mods     = { [xi.mod.ATTP] = { 6, 12, 18, 24, 30 }, [xi.mod.RATTP] = { 6, 12, 18, 24, 30 }, [xi.mod.RACC] = { 10, 20, 30, 40, 50 } },
            },
        }),
    N('c2_t2', 'Airborne Hangtime', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.75..4.00 Single-Hit fTP, +5..25% AGI WSC',
        function(r)
            local f = ({ 0.75, 1.50, 2.30, 3.15, 4.00 })[r]
            return string.format('+%.2f fTP, +%d%% AGI WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.75, 1.50, 2.30, 3.15, 4.00 },
            wsc    = { agi = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Crushing Plunge', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        'Ignores 9..45% DEF, +5..25% WSD',
        function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 9, r * 5) end,
        { defIgnore = { 0.09, 0.18, 0.27, 0.36, 0.45 }, wsd = { 5, 10, 15, 20, 25 } }),

    -- Tier 3
    N('c1_t3', 'Prima Momentum', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Refunds 60..300 TP after WS and grants 40..200 Party TP',
        function(r) return string.format('+%d TP Refund, +%d Party TP', r * 60, r * 40) end,
        { nextWs = { tp = { 60, 120, 180, 240, 300 }, dur = 15 }, partyTp = { 40, 80, 120, 160, 200 } }),
    N('c2_t3', 'Stratosphere Arc', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.85..4.50 Single-Hit fTP, +5..25% Crit Rate',
        function(r)
            local f = ({ 0.85, 1.70, 2.60, 3.55, 4.50 })[r]
            return string.format('+%.2f fTP, +%d%% Crit Rate', f, r * 5)
        end,
        { ftpAdd = { 0.85, 1.70, 2.60, 3.55, 4.50 }, crit = { 0.05, 0.10, 0.15, 0.20, 0.25 } }),
    N('c3_t3', 'Shattered Stage', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        '+6..30% Crit DMG, Inflicts -8..40 DEF Down (60s)',
        function(r) return string.format('+%d%% Crit DMG, -%d DEF Down (60s)', r * 6, r * 8) end,
        {
            critDmg       = { 6, 12, 18, 24, 30 },
            targetDebuffs = { { effect = xi.effect.DEFENSE_DOWN, power = { 8, 16, 24, 32, 40 }, duration = 60 } },
        }),

    -- Tier 4
    N('c1_t4', 'Ovation Recovery', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Heals self for 10..30% Max HP and grants Next WS +12..36% WSD',
        function(r) return string.format('%d%% Self Max HP Heal, Next WS +%d%% WSD', r * 10, r * 12) end,
        { selfMaxHpHealPct = { 10, 20, 30 }, nextWs = { wsd = { 12, 24, 36 }, dur = 15 } }),
    N('c2_t4', 'Grand Jete Mastery', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.60..6.50 Single-Hit fTP, +10..40% WSD, +10..40% DEX WSC',
        function(r)
            local f = ({ 1.60, 3.20, 4.85, 6.50 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% DEX WSC', f, r * 10, r * 10)
        end,
        {
            ftpAdd = { 1.60, 3.20, 4.85, 6.50 },
            wsd    = { 10, 20, 30, 40 },
            wsc    = { dex = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Relic Cataclysm', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+1.00..4.00 fTP, Ignores 10..40% DEF, +12..48% R.Atk',
        function(r) return string.format('+%.2f fTP, %d%% DEF Ign, +%d%% R.Atk', r * 1.00, r * 10, r * 12) end,
        {
            ftpAdd    = { 1.00, 2.00, 3.00, 4.00 },
            defIgnore = { 0.10, 0.20, 0.30, 0.40 },
            atkPct    = { 12, 24, 36, 48 },
        }),
})

---------------------------------------------------------------------------
-- #251 AURORA FANDANGO (Physical Ranged 4-Hit Empyrean Multi-Hit, DEX 40% / CHR 40%)
-- Col 1: Empyrean Radiance (Haste, Store TP, Party TP & Self Sustain)
-- Col 2: Early fTP Transfer & Empyrean Flurry (T1 fTP Transfer + fTP + Bonus Hits!)
-- Col 3: Northern Lights Barrage (Crit Rate, Crit DMG, DEF Ignore & fTP — ZERO magic!)
---------------------------------------------------------------------------
regB(251, 'multihit',
{
    -- Tier 1: Opens fTP Transfer immediately at Rank 1 of Col 2 + fTP increases!
    N('c1_t1', 'Aurora Step', 1, 1, 6, nil,
        '+6..36 R.Acc, +5..30 Store TP on WS',
        function(r) return string.format('+%d R.Acc, +%d Store TP', r * 6, r * 5) end,
        { racc = { 6, 12, 18, 24, 30, 36 }, storeTp = { 5, 10, 15, 20, 25, 30 } }),
    N('c2_t1', 'Fandango Transfer', 1, 2, 7, nil,
        'R1: fTP Transfers to ALL Hits! +0.40..3.10 fTP, +4..28% DEX WSC',
        function(r)
            local f = ({ 0.40, 0.80, 1.25, 1.70, 2.15, 2.60, 3.10 })[r]
            return string.format('fTP ALL Hits, +%.2f fTP, +%d%% DEX WSC', f, r * 4)
        end,
        {
            multiHitfTPAt = 1,
            ftpAdd        = { 0.40, 0.80, 1.25, 1.70, 2.15, 2.60, 3.10 },
            wsc           = { dex = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28 } },
        }),
    N('c3_t1', 'Starlight Razor', 1, 3, 7, nil,
        '+0.30..2.10 fTP, +6..42% R.Atk',
        function(r) return string.format('+%.2f fTP, +%d%% R.Atk', r * 0.30, r * 6) end,
        {
            ftpAdd = { 0.30, 0.60, 0.90, 1.20, 1.50, 1.80, 2.10 },
            atkPct = { 6, 12, 18, 24, 30, 36, 42 },
        }),

    -- Tier 2
    N('c1_t2', 'Borealis Tempo', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants +5..25% Haste and +6..30 Store TP (30s) after WS',
        function(r) return string.format('+%d%% Haste, +%d Store TP (30s)', r * 5, r * 6) end,
        {
            postBuff = {
                effect   = xi.effect.HASTE,
                duration = 30,
                mods     = { [xi.mod.HASTE_MAGIC] = { 500, 1000, 1500, 2000, 2500 }, [xi.mod.STORETP] = { 6, 12, 18, 24, 30 } },
            },
        }),
    N('c2_t2', 'Celestial Volley', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.40..2.00 fTP, +5..25% CHR WSC, +1 Hit at R3 & +2 Hits at R5',
        function(r)
            local hAdd = r >= 5 and 2 or (r >= 3 and 1 or 0)
            return string.format('+%.2f fTP, +%d%% CHR WSC%s', r * 0.40, r * 5, hAdd > 0 and string.format(', +%d Hit(s)', hAdd) or '')
        end,
        {
            ftpAdd    = { 0.40, 0.80, 1.20, 1.60, 2.00 },
            wsc       = { chr = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
            bonusHits = { 0, 0, 1, 1, 2 },
        }),
    N('c3_t2', 'Prismatic Edges', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        '+5..25% Crit Rate, +5..25% Crit DMG',
        function(r) return string.format('+%d%% Crit Rate, +%d%% Crit DMG', r * 5, r * 5) end,
        { crit = { 0.05, 0.10, 0.15, 0.20, 0.25 }, critDmg = { 5, 10, 15, 20, 25 } }),

    -- Tier 3
    N('c1_t3', 'Charis Boon', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Grants 50..250 Party TP and +50..250 TP Bonus',
        function(r) return string.format('+%d Party TP, +%d TP Bonus', r * 50, r * 50) end,
        { partyTp = { 50, 100, 150, 200, 250 }, tpBonus = { 50, 100, 150, 200, 250 } }),
    N('c2_t3', 'Polaris Cascade', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.45..2.25 fTP, +5..25% WSD',
        function(r) return string.format('+%.2f fTP, +%d%% WSD', r * 0.45, r * 5) end,
        { ftpAdd = { 0.45, 0.90, 1.35, 1.80, 2.25 }, wsd = { 5, 10, 15, 20, 25 } }),
    N('c3_t3', 'Astral Breach', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        'Ignores 7..35% DEF, +8..40% R.Atk',
        function(r) return string.format('Ignores %d%% DEF, +%d%% R.Atk', r * 7, r * 8) end,
        { defIgnore = { 0.07, 0.14, 0.21, 0.28, 0.35 }, atkPct = { 8, 16, 24, 32, 40 } }),

    -- Tier 4
    N('c1_t4', 'Empyrean Encore', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Refunds 100..300 TP and heals party for 6..18% Max HP',
        function(r) return string.format('+%d TP Refund, Party Heal %d%% Max HP', r * 100, r * 6) end,
        { nextWs = { tp = { 100, 200, 300 }, dur = 15 }, partyHealPct = { 6, 12, 18 } }),
    N('c2_t4', 'Aurora Crown', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+0.75..3.00 fTP (All Hits), +1 Bonus Hit at R2 & R4, +7..28% WSD',
        function(r)
            local hAdd = r >= 4 and 2 or (r >= 2 and 1 or 0)
            return string.format('+%.2f fTP, +%d Hit(s), +%d%% WSD', r * 0.75, hAdd, r * 7)
        end,
        {
            ftpAdd    = { 0.75, 1.50, 2.25, 3.00 },
            bonusHits = { 0, 1, 1, 2 },
            wsd       = { 7, 14, 21, 28 },
        }),
    N('c3_t4', 'Horizon Sovereign', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+0.60..2.40 fTP, +8..32% Crit DMG, Ignores 9..36% DEF',
        function(r) return string.format('+%.2f fTP, +%d%% Crit DMG, %d%% DEF Ign', r * 0.60, r * 8, r * 9) end,
        {
            ftpAdd    = { 0.60, 1.20, 1.80, 2.40 },
            critDmg   = { 8, 16, 24, 32 },
            defIgnore = { 0.09, 0.18, 0.27, 0.36 },
        }),
})

---------------------------------------------------------------------------
-- #252 TERPSICHORE'S HALO (Magical Mythic Light 1-Hit, CHR 60% / DEX 30%)
-- Col 1: Muse's Blessing (Party TP, Party Heal/Regen/Refresh & Mythic Sustain)
-- Col 2: Mythic Halo fTP (Colossal Single-Hit fTP Scaling + CHR/DEX WSC)
-- Col 3: Celestial Radiance (MAB, MACC, WSD & Light Elemental Follow-up)
---------------------------------------------------------------------------
regB(252, 'magic',
{
    -- Tier 1
    N('c1_t1', 'Muse\'s Grace', 1, 1, 6, nil,
        'Heals party for 4..24% Max HP, +40..240 TP Bonus',
        function(r) return string.format('Party Heal %d%% Max HP, +%d TP Bonus', r * 4, r * 40) end,
        { partyHealPct = { 4, 8, 12, 16, 20, 24 }, tpBonus = { 40, 80, 120, 160, 200, 240 } }),
    N('c2_t1', 'Terpsichore Velocity', 1, 2, 7, nil,
        '+0.85..6.00 Single-Hit fTP, +5..35% CHR WSC',
        function(r)
            local f = ({ 0.85, 1.70, 2.55, 3.40, 4.25, 5.10, 6.00 })[r]
            return string.format('+%.2f fTP, +%d%% CHR WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.85, 1.70, 2.55, 3.40, 4.25, 5.10, 6.00 },
            wsc    = { chr = { 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35 } },
        }),
    N('c3_t1', 'Halo Brilliance', 1, 3, 7, nil,
        '+6..42 MAB, +6..42 MACC on WS',
        function(r) return string.format('+%d MAB, +%d MACC', r * 6, r * 6) end,
        { matt = { 6, 12, 18, 24, 30, 36, 42 }, macc = { 6, 12, 18, 24, 30, 36, 42 } }),

    -- Tier 2
    N('c1_t2', 'Chorus of Light', 2, 1, 5, { key = 'c1_t1', rank = 2 },
        'Grants Party Regen (8..40 HP/tick) and Refresh (2..10 MP/tick) for 30s',
        function(r) return string.format('Party Regen %d, Refresh %d (30s)', r * 8, r * 2) end,
        {
            partyBuffs = {
                { effect = xi.effect.REGEN,   power = { 8, 16, 24, 32, 40 }, duration = 30 },
                { effect = xi.effect.REFRESH, power = { 2, 4, 6, 8, 10 },    duration = 30 },
            },
        }),
    N('c2_t2', 'Sacred Choreography', 2, 2, 5, { key = 'c2_t1', rank = 2 },
        '+0.75..4.00 Single-Hit fTP, +5..25% DEX WSC',
        function(r)
            local f = ({ 0.75, 1.50, 2.30, 3.15, 4.00 })[r]
            return string.format('+%.2f fTP, +%d%% DEX WSC', f, r * 5)
        end,
        {
            ftpAdd = { 0.75, 1.50, 2.30, 3.15, 4.00 },
            wsc    = { dex = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
        }),
    N('c3_t2', 'Seraphic Focus', 2, 3, 5, { key = 'c3_t1', rank = 2 },
        '+7..35 MAB, +5..25% WSD',
        function(r) return string.format('+%d MAB, +%d%% WSD', r * 7, r * 5) end,
        { matt = { 7, 14, 21, 28, 35 }, wsd = { 5, 10, 15, 20, 25 } }),

    -- Tier 3
    N('c1_t3', 'Mythic Encore', 3, 1, 5, { key = 'c1_t2', rank = 2 },
        'Grants 60..300 Party TP and refunds 50..250 Self TP',
        function(r) return string.format('+%d Party TP, +%d Self TP Refund', r * 60, r * 50) end,
        { partyTp = { 60, 120, 180, 240, 300 }, nextWs = { tp = { 50, 100, 150, 200, 250 }, dur = 15 } }),
    N('c2_t3', 'Goddess Spin', 3, 2, 5, { key = 'c2_t2', rank = 2 },
        '+0.85..4.50 Single-Hit fTP, +5..25% WSD',
        function(r)
            local f = ({ 0.85, 1.70, 2.60, 3.55, 4.50 })[r]
            return string.format('+%.2f fTP, +%d%% WSD', f, r * 5)
        end,
        { ftpAdd = { 0.85, 1.70, 2.60, 3.55, 4.50 }, wsd = { 5, 10, 15, 20, 25 } }),
    N('c3_t3', 'Sunburst Corona', 3, 3, 5, { key = 'c3_t2', rank = 2 },
        'Deals +8..40% Light elemental follow-up damage',
        function(r) return string.format('+%d%% Light Follow-up DMG', r * 8) end,
        { elemFollow = { ele = xi.element.LIGHT, pct = { 8, 16, 24, 32, 40 } } }),

    -- Tier 4
    N('c1_t4', 'Eternal Ovations', 4, 1, 3, { key = 'c1_t3', rank = 2 },
        'Heals party for +8..24% Max HP and grants Next WS +12..36% WSD',
        function(r) return string.format('+%d%% Party Heal, Next WS +%d%% WSD', r * 8, r * 12) end,
        { partyHealPct = { 8, 16, 24 }, nextWs = { wsd = { 12, 24, 36 }, dur = 15 } }),
    N('c2_t4', 'Apotheosis of Dance', 4, 2, 4, { key = 'c2_t3', rank = 2 },
        '+1.60..6.50 Single-Hit fTP, +10..40% WSD, +10..40% CHR WSC',
        function(r)
            local f = ({ 1.60, 3.20, 4.85, 6.50 })[r]
            return string.format('+%.2f fTP, +%d%% WSD, +%d%% CHR WSC', f, r * 10, r * 10)
        end,
        {
            ftpAdd = { 1.60, 3.20, 4.85, 6.50 },
            wsd    = { 10, 20, 30, 40 },
            wsc    = { chr = { 0.10, 0.20, 0.30, 0.40 } },
        }),
    N('c3_t4', 'Terpsichore\'s Crown', 4, 3, 4, { key = 'c3_t3', rank = 2 },
        '+1.00..4.00 fTP, +12..48 MAB, +10..40% Light Follow-up',
        function(r) return string.format('+%.2f fTP, +%d MAB, +%d%% Light DMG', r * 1.00, r * 12, r * 10) end,
        {
            ftpAdd     = { 1.00, 2.00, 3.00, 4.00 },
            matt       = { 12, 24, 36, 48 },
            elemFollow = { ele = xi.element.LIGHT, pct = { 10, 20, 30, 40 } },
        }),
})
