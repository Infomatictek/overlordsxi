-----------------------------------
-- SoulspireXI — 66-Soul WS Talent Mechanics & Role Guardrails (Foundation Pass 2.0)
--
-- Single reusable registry of:
--   1. All 66 canonical Souls' metadata, preferred WSC stats, and real implemented
--      stance/status/pet/clone hooks (zero invented Soul resources).
--   2. Shared three-branch builders:
--        Col 1 = Damage  (HOW the WS deals damage)
--        Col 2 = Utility (WHY and WHEN the WS is used)
--        Col 3 = Soul    (WHAT the WS means to the active Soul)
--   3. Strict 6-tier role guardrails:
--        - Tier-1 pure DPS Souls never gain substantial self-healing, Stoneskin,
--          Phalanx, Regen, or tank mitigation from Utility/Soul WS talents.
--        - Tanks/Healers strip high-variance crit/bonus-hit spikes.
--        - Pet effects only on genuine pet Souls; zero MP/Refresh on Chi Weaver.
--        - PLD Sanguine Blade sustain abuse strictly capped.
-----------------------------------
local E = require('modules/custom/lua/soulspire_ws_eligibility')

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.wsSoulMechanics = xi.soulspire.wsSoulMechanics or {}

local M = xi.soulspire.wsSoulMechanics

local EFF = xi.effect or {}

-- Numeric fallbacks for custom status effect IDs (defined in *_specs.lua)
local CUSTOM_EFF =
{
    CMD_BREACH  = 815, CMD_BULWARK = 816, CMD_CADENCE = 817, CMD_HORN    = 818,
    ZRK_SURGE   = 819, GLD_WARD    = 820, INQ_BATTUTA = 821, INQ_AEGIS   = 822,
    INQ_CONV    = 823, SPB_FLARE   = 824, LFB_FONT    = 825, LFB_WARD    = 826,
    SPB_COND    = 827, SPB_ASCEND  = 828, CHW_LOTUS   = 829, CHW_HARMONY = 830,
    RON_STAGGER = 837, IMP_OISOYA  = 838, IMP_BRAND   = 839, WRL_NOTO    = 840,
    WRL_ASHURA  = 841, AEG_ZEAL    = 842, AEG_CONSEC  = 843, AEG_RETRIB  = 844,
    KAG_SHADOW  = 846, BSH_VEIL    = 860, TMP_BEACON  = 863, MAG_CONDUIT = 865,
    VMP_FEAST   = 867, CEL_STAR    = 869, ANM_CELL    = 871, VRD_CANOPY  = 872,
    WYV_SCALE   = 874, GMB_ADV     = 884,
}

-- Canonical 66-Soul profile & real implemented mechanic map
M.PROFILES =
{
    -- WAR
    berserker = {
        pfx = 'zrk', pref = 'str', role = 'Damage', tier = 'Damage',
        tag = 'Bloodlust', utilTag = 'Pressure', soulTag = 'Fury',
        stance = { label = 'Bloodlust', jobSpec = 'berserker', effects = { EFF.BERSERK, EFF.BLOOD_RAGE, EFF.AGGRESSOR, EFF.RESTRAINT, CUSTOM_EFF.ZRK_SURGE } },
        soulHook = { id = 'war_bloodlust_surge', kind = 'resource_build', label = 'Bloodlust Surge', localVar = 'OX_ZRK_SURGE_PTS', delta = { 1, 1, 2, 2, 3 }, maxStack = 10, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    commander = {
        pfx = 'cmd', pref = 'str', role = 'Support', tier = 'Support',
        tag = 'Banner', utilTag = 'Tactics', soulTag = 'Command',
        stance = { label = 'Command', jobSpec = 'commander', effects = { EFF.WARCRY, EFF.RESTRAINT, EFF.RETALIATION, CUSTOM_EFF.CMD_BREACH, CUSTOM_EFF.CMD_BULWARK, CUSTOM_EFF.CMD_CADENCE, CUSTOM_EFF.CMD_HORN } },
        soulHook = { id = 'war_tactical_breach', kind = 'party_pulse', label = 'Tactical Breach', partyTp = { 40, 75, 110, 145, 180 }, targetDebuff = EFF.DEFENSE_DOWN, debuffPower = { 5, 8, 11, 14, 18 } },
    },
    spartan = {
        pfx = 'spt', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Phalanx', utilTag = 'Bulwark', soulTag = 'Grit',
        stance = { label = 'Vanguard', jobSpec = 'spartan', effects = { EFF.DEFENDER, EFF.RETALIATION, EFF.SENTINEL, EFF.RAMPART, CUSTOM_EFF.GLD_WARD } },
        soulHook = { id = 'war_spartan_grit', kind = 'resource_build', label = 'Spartan Grit', localVar = 'OX_SPARTAN_GRIT', delta = { 1, 2, 2, 3, 4 }, maxStack = 20, enmity = { 4, 8, 12, 16, 20 } },
    },

    -- MNK
    blackbelt = {
        pfx = 'bbt', pref = 'dex', role = 'Damage', tier = 'Damage',
        tag = 'Impetus', utilTag = 'Tempo', soulTag = 'Footwork',
        stance = { label = 'Footwork/Impetus', jobSpec = 'blackbelt', effects = { EFF.FOOTWORK, EFF.IMPETUS, EFF.FOCUS, EFF.HUNDRED_FISTS } },
        soulHook = { id = 'mnk_impetus_chain', kind = 'next_ws_prime', label = 'Impetus Chain', nextWsd = { 4, 8, 12, 16, 20 }, nextTp = { 40, 80, 120, 160, 200 } },
    },
    chiweaver = {
        pfx = 'chw', pref = 'mnd', role = 'Healer', tier = 'Healer', noMp = true,
        tag = 'Chi', utilTag = 'Harmony', soulTag = 'Lotus',
        stance = { label = 'Lotus/Harmony', jobSpec = 'chiweaver', effects = { CUSTOM_EFF.CHW_LOTUS, CUSTOM_EFF.CHW_HARMONY, EFF.FOCUS, EFF.DODGE } },
        soulHook = { id = 'mnk_chi_harmony', kind = 'party_pulse', label = 'Chi Harmony', partyHealPct = { 2, 3, 4, 5, 6 }, chiBlastPct = { 10, 20, 30, 40, 50 } },
    },
    sensei = {
        pfx = 'sen', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Kata', utilTag = 'Riposte', soulTag = 'Dojo',
        stance = { label = 'Dojo Stance', jobSpec = 'sensei', effects = { EFF.COUNTERSTANCE, EFF.DODGE, EFF.FOCUS, EFF.PERFECT_COUNTER } },
        soulHook = { id = 'mnk_dojo_riposte', kind = 'enmity_surge', label = 'Dojo Counter', enmity = { 5, 10, 15, 20, 25 }, subtleBlow = { 3, 6, 9, 12, 15 } },
    },

    -- WHM
    bishop = {
        pfx = 'bsh', pref = 'mnd', role = 'Healer', tier = 'Healer',
        tag = 'Solace', utilTag = 'Mercy', soulTag = 'Sanctum',
        stance = { label = 'Solace/Veil', jobSpec = 'bishop', effects = { EFF.AFFLATUS_SOLACE, EFF.DIVINE_SEAL, CUSTOM_EFF.BSH_VEIL } },
        soulHook = { id = 'whm_solace_mend', kind = 'party_pulse', label = 'Solace Grace', partyHealPct = { 2, 3, 4, 5, 6 }, mpReturn = { 12, 24, 36, 48, 60 } },
    },
    zealot = {
        pfx = 'zel', pref = 'mnd', role = 'Damage', tier = 'Damage',
        tag = 'Radiant', utilTag = 'Condemn', soulTag = 'Zealotry',
        stance = { label = 'Afflatus Misery', jobSpec = 'zealot', effects = { EFF.AFFLATUS_MISERY, EFF.DIVINE_SEAL } },
        soulHook = { id = 'whm_zealot_sanctify', kind = 'stance_empower', label = 'Sanctified Judgment', matt = { 10, 18, 26, 34, 42 }, macc = { 8, 16, 24, 32, 40 } },
    },
    valkyrie = {
        pfx = 'vlk', pref = 'str', role = 'Support', tier = 'Support',
        tag = 'Valkyr', utilTag = 'AegisWing', soulTag = 'Wingmate',
        stance = { label = 'Wingmate', jobSpec = 'valkyrie', effects = { EFF.AFFLATUS_SOLACE, EFF.AFFLATUS_MISERY, EFF.HASTE } },
        soulHook = { id = 'whm_valkyrie_wingmate', kind = 'party_pulse', label = 'Wingmate Surge', partyTp = { 45, 80, 115, 150, 185 }, partyHealPct = { 2, 3, 4, 5, 6 } },
    },

    -- BLM
    astromancer = {
        pfx = 'ast', pref = 'int', role = 'Damage', tier = 'Damage',
        tag = 'Astral', utilTag = 'Alignment', soulTag = 'Starlight',
        stance = { label = 'Celestial Alignment', jobSpec = 'astromancer', effects = { EFF.ELEMENTAL_SEAL, EFF.MANAFONT, EFF.CASCADE } },
        soulHook = { id = 'blm_astromancer_celestial', kind = 'mp_siphon', label = 'Celestial Siphon', mpReturn = { 15, 30, 45, 60, 75 }, matt = { 10, 18, 26, 34, 42 } },
    },
    channeler = {
        pfx = 'chn', pref = 'int', role = 'Support', tier = 'HybridSupport',
        tag = 'Resonance', utilTag = 'Conduit', soulTag = 'Channel',
        stance = { label = 'Resonance', jobSpec = 'channeler', effects = { EFF.ELEMENTAL_SEAL, EFF.MANAWALL, EFF.DARK_ARTS } },
        soulHook = { id = 'blm_channeler_resonance', kind = 'party_pulse', label = 'Arcane Resonance', partyTp = { 40, 75, 110, 145, 180 }, macc = { 8, 16, 24, 32, 40 } },
    },
    necromancer = {
        pfx = 'nec', pref = 'int', role = 'Tank', tier = 'Tank', pet = true,
        tag = 'Ossuary', utilTag = 'Blight', soulTag = 'DarkPact',
        stance = { label = 'Dark Pact', jobSpec = 'necromancer', petAlive = true, effects = { EFF.MANA_WALL, EFF.ELEMENTAL_SEAL, EFF.SOULEATER } },
        soulHook = { id = 'blm_necromancer_pact', kind = 'pet_tp_heal', label = 'Dark Pact', eosHeal = { 6, 10, 14, 18, 22 }, petTp = { 80, 140, 200, 260, 320 }, enmity = { 4, 8, 12, 16, 20 } },
    },

    -- RDM
    crimsonduelist = {
        pfx = 'dls', pref = 'dex', role = 'Tank', tier = 'Tank',
        tag = 'Riposte', utilTag = 'Enfeeble', soulTag = 'CrimsonFlow',
        stance = { label = 'Crimson Flow', jobSpec = 'crimsonduelist', effects = { EFF.COMPOSURE, EFF.SABOTEUR, EFF.PHALANX, EFF.STONESKIN } },
        soulHook = { id = 'rdm_crimson_flow', kind = 'resource_build', label = 'Crimson Flow', localVar = 'OX_CRIMSON_FLOW', delta = { 1, 1, 2, 2, 3 }, maxStack = 5, enmity = { 5, 10, 15, 20, 25 } },
    },
    royaltactician = {
        pfx = 'ryt', pref = 'mnd', role = 'Support', tier = 'Support',
        tag = 'Edict', utilTag = 'Sabotage', soulTag = 'Tactician',
        stance = { label = 'Royal Tactics', jobSpec = 'royaltactician', effects = { EFF.COMPOSURE, EFF.SABOTEUR, EFF.STYMIE } },
        soulHook = { id = 'rdm_tactical_enfeeble', kind = 'debuff_extend', label = 'Tactical Sabotage', targetDebuff = EFF.MAGIC_DEF_DOWN, debuffPower = { 5, 9, 13, 17, 22 }, partyTp = { 35, 65, 95, 125, 155 } },
    },
    scarletweaver = {
        pfx = 'scw', pref = 'int', role = 'Damage', tier = 'Damage',
        tag = 'Scarlet', utilTag = 'Weave', soulTag = 'YinYang',
        stance = { label = 'Yin/Yang Weave', jobSpec = 'scarletweaver', effects = { EFF.COMPOSURE, EFF.CHAINSPELL, EFF.ENFIRE, EFF.ENBLIZZARD, EFF.ENAERO, EFF.ENSTONE, EFF.ENTHUNDER, EFF.ENWATER } },
        soulHook = { id = 'rdm_scarlet_weave', kind = 'resource_build', label = 'Yin/Yang Weave', localVar = 'OX_SCARLET_WEAVE', delta = { 1, 1, 2, 2, 3 }, maxStack = 6, matt = { 10, 18, 26, 34, 42 }, bonusWsd = { 4, 8, 12, 16, 20 } },
    },

    -- THF
    bandit = {
        pfx = 'bnd', pref = 'dex', role = 'Damage', tier = 'Damage',
        tag = 'Ambush', utilTag = 'Tempo', soulTag = 'Opening',
        stance = { label = 'Find the Gap', jobSpec = 'bandit', effects = { EFF.SNEAK_ATTACK, EFF.TRICK_ATTACK, EFF.FEINT, EFF.CONSPIRATOR } },
        soulHook = { id = 'thf_bandit_opening', kind = 'tp_refund', label = 'Find the Gap', tpRefund = { 60, 110, 160, 210, 260 }, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    trickster = {
        pfx = 'trk', pref = 'dex', role = 'Support', tier = 'Support',
        tag = 'Feint', utilTag = 'Misdirect', soulTag = 'Blame',
        stance = { label = 'Pass the Blame', jobSpec = 'trickster', effects = { EFF.TRICK_ATTACK, EFF.FEINT, EFF.CONSPIRATOR } },
        soulHook = { id = 'thf_pass_blame', kind = 'debuff_extend', label = 'Pass the Blame', targetDebuff = EFF.ATTACK_DOWN, debuffPower = { 5, 9, 13, 17, 21 }, enmity = { -6, -12, -18, -24, -30 } },
    },
    phantom = {
        pfx = 'phn', pref = 'agi', role = 'Tank', tier = 'Tank',
        tag = 'Mirage', utilTag = 'Evasion', soulTag = 'Shadow',
        stance = { label = 'Phantom Shroud', jobSpec = 'phantom', effects = { EFF.PERFECT_DODGE, EFF.COPY_IMAGE, EFF.FEINT } },
        soulHook = { id = 'thf_phantom_shadow', kind = 'enmity_surge', label = 'Phantom Decoy', enmity = { 5, 10, 15, 20, 25 }, subtleBlow = { 3, 6, 9, 12, 15 } },
    },

    -- PLD
    defender = {
        pfx = 'aeg', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Aegis', utilTag = 'Intercept', soulTag = 'Zeal',
        stance = { label = 'Aegis/Zeal', jobSpec = 'defender', effects = { EFF.SENTINEL, EFF.RAMPART, EFF.MAJESTY, EFF.PALISADE, CUSTOM_EFF.AEG_ZEAL, CUSTOM_EFF.AEG_CONSEC, CUSTOM_EFF.AEG_RETRIB } },
        soulHook = { id = 'pld_zeal_nova', kind = 'resource_build', label = 'Zeal Stack', localVar = 'OX_AEGIS_ZEAL_STACKS', delta = { 1, 1, 1, 2, 2 }, maxStack = 5, enmity = { 5, 10, 15, 20, 25 } },
    },
    templar = {
        pfx = 'tmp', pref = 'mnd', role = 'Healer', tier = 'CombatHealer',
        tag = 'Majesty', utilTag = 'Chivalry', soulTag = 'Beacon',
        stance = { label = 'Majesty/Beacon', jobSpec = 'templar', effects = { EFF.MAJESTY, EFF.DIVINE_SEAL, CUSTOM_EFF.TMP_BEACON } },
        soulHook = { id = 'pld_beacon_light', kind = 'party_pulse', label = 'Beacon of Light', partyHealPct = { 2, 3, 4, 5, 6 }, mpReturn = { 10, 20, 30, 40, 50 } },
    },
    oathbreaker = {
        pfx = 'otb', pref = 'str', role = 'Damage', tier = 'Damage',
        tag = 'Reckoning', utilTag = 'Ruin', soulTag = 'Oathbreak',
        stance = { label = 'Reckoning', jobSpec = 'oathbreaker', effects = { EFF.SENTINEL, EFF.RAMPART, EFF.ENLIGHT, EFF.REPRISAL } },
        soulHook = { id = 'pld_oathbreaker_reckoning', kind = 'resource_build', label = 'Reckoning Charge', localVar = 'OX_OATHBREAKER_RECKONING', delta = { 1, 1, 2, 2, 3 }, maxStack = 10, bonusWsd = { 4, 8, 12, 16, 20 } },
    },

    -- DRK
    reaper = {
        pfx = 'rpr', pref = 'str', role = 'Damage', tier = 'Damage',
        tag = 'Finality', utilTag = 'Harvest', soulTag = 'Reap',
        stance = { label = 'Last Resort/Souleater', jobSpec = 'reaper', effects = { EFF.LAST_RESORT, EFF.SOULEATER, EFF.DARK_SEAL, EFF.NETHER_VOID } },
        soulHook = { id = 'drk_reaper_finality', kind = 'stance_empower', label = 'Finality Mark', bonusWsd = { 5, 10, 15, 20, 25 }, defIgnore = { 0.04, 0.08, 0.12, 0.16, 0.20 } },
    },
    dreadnought = {
        pfx = 'drn', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Bloodpool', utilTag = 'Dread', soulTag = 'Siphon',
        stance = { label = 'Blood-Pool', jobSpec = 'dreadnought', effects = { EFF.DREAD_SPIKES, EFF.ENDARK, EFF.LAST_RESORT, EFF.DARK_SEAL } },
        soulHook = { id = 'drk_blood_pool', kind = 'resource_build', label = 'Blood-Pool Charge', localVar = 'OX_DREAD_BLOODPOOL', delta = { 1, 1, 2, 2, 3 }, maxStack = 10, enmity = { 5, 10, 15, 20, 25 } },
    },
    scourge = {
        pfx = 'scr', pref = 'int', role = 'Support', tier = 'Support',
        tag = 'Curse', utilTag = 'Wither', soulTag = 'Scourge',
        stance = { label = 'Scourge Curse', jobSpec = 'scourge', effects = { EFF.DARK_SEAL, EFF.NETHER_VOID, EFF.ENDARK } },
        soulHook = { id = 'drk_scourge_curse', kind = 'debuff_extend', label = 'Scourge Blight', targetDebuff = EFF.ATTACK_DOWN, debuffPower = { 5, 9, 13, 17, 21 }, macc = { 8, 16, 24, 32, 40 } },
    },

    -- BRD
    adventurer = {
        pfx = 'adv', pref = 'dex', role = 'Damage', tier = 'Damage',
        tag = 'Encore', utilTag = 'Tempo', soulTag = 'Cadence',
        stance = { label = 'Cadence', jobSpec = 'adventurer', effects = { EFF.MARCH, EFF.MINUET, EFF.MADRIGAL, EFF.SOUL_VOICE } },
        soulHook = { id = 'brd_cadence_encore', kind = 'resource_build', label = 'Cadence Stack', localVar = 'OX_ADV_CADENCE', delta = { 1, 1, 2, 2, 3 }, maxStack = 5, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    musician = {
        pfx = 'mus', pref = 'chr', role = 'Support', tier = 'HybridSupport',
        tag = 'Aria', utilTag = 'Chord', soulTag = 'Ballad',
        stance = { label = 'Ballad/Aria', jobSpec = 'musician', effects = { EFF.BALLAD, EFF.MARCH, EFF.SOUL_VOICE, EFF.TROUBADOUR } },
        soulHook = { id = 'brd_musician_ballad', kind = 'party_pulse', label = 'Harmonic Pulse', partyTp = { 40, 75, 110, 145, 180 }, mpReturn = { 10, 20, 30, 40, 50 } },
    },
    minstrel = {
        pfx = 'min', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Dirge', utilTag = 'Chant', soulTag = 'Anthem',
        stance = { label = 'Minstrel Anthem', jobSpec = 'minstrel', effects = { EFF.MINNE, EFF.MAMBO, EFF.CAROL, EFF.SOUL_VOICE } },
        soulHook = { id = 'brd_minstrel_anthem', kind = 'enmity_surge', label = 'Taunting Anthem', enmity = { 5, 10, 15, 20, 25 }, subtleBlow = { 3, 6, 9, 12, 15 } },
    },

    -- RNG
    sniper = {
        pfx = 'snp', pref = 'agi', role = 'Damage', tier = 'Damage', singleTargetOnly = true,
        tag = 'Sightline', utilTag = 'Ballistic', soulTag = 'Deadshot',
        stance = { label = 'Sightline', jobSpec = 'sniper', effects = { EFF.SHARPSHOT, EFF.BARRAGE, EFF.VELOCITY_SHOT, EFF.DOUBLE_SHOT } },
        soulHook = { id = 'rng_sniper_sightline', kind = 'stance_empower', label = 'Sightline Focus', bonusWsd = { 5, 10, 15, 20, 25 }, tpBonus = { 60, 120, 180, 240, 300 } },
    },
    huntsman = {
        pfx = 'hnt', pref = 'agi', role = 'Tank', tier = 'Tank', pet = true,
        tag = 'Apex', utilTag = 'Ration', soulTag = 'PackBond',
        stance = { label = 'Apex Bond', jobSpec = 'huntsman', petAlive = true, effects = { EFF.SHARPSHOT, EFF.BARRAGE, EFF.CAMOUFLAGE, EFF.UNLIMITED_SHOT } },
        soulHook = { id = 'rng_huntsman_ration', kind = 'pet_tp_heal', label = "Warden's Ration", eosHeal = { 6, 10, 14, 18, 22 }, petTp = { 80, 140, 200, 260, 320 }, enmity = { 4, 8, 12, 16, 20 } },
    },
    arcanearcher = {
        pfx = 'aca', pref = 'agi', role = 'Support', tier = 'Support',
        tag = 'Attune', utilTag = 'Quiver', soulTag = 'ArcaneBow',
        stance = { label = 'Attunement', jobSpec = 'arcanearcher', effects = { EFF.SHARPSHOT, EFF.VELOCITY_SHOT, EFF.UNLIMITED_SHOT } },
        soulHook = { id = 'rng_arcane_attune', kind = 'debuff_extend', label = 'Attunement Mark', targetDebuff = EFF.MAGIC_DEF_DOWN, debuffPower = { 5, 9, 13, 17, 21 }, partyTp = { 35, 65, 95, 125, 155 } },
    },

    -- SAM
    ronin = {
        pfx = 'ron', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Seigan', utilTag = 'Purify', soulTag = 'Mushin',
        stance = { label = 'Seigan/Mushin', jobSpec = 'ronin', effects = { EFF.SEIGAN, EFF.THIRD_EYE, EFF.WARDING_CIRCLE, EFF.MEIKYO_SHISUI, CUSTOM_EFF.RON_STAGGER } },
        soulHook = { id = 'sam_ronin_stagger', kind = 'enmity_surge', label = 'Mushin Purify', enmity = { 5, 10, 15, 20, 25 }, tpRefund = { 40, 80, 120, 160, 200 } },
    },
    imperialarcher = {
        pfx = 'imp', pref = 'agi', role = 'Support', tier = 'Support',
        tag = 'Oisoya', utilTag = 'Volley', soulTag = 'Cosmic',
        stance = { label = 'Oisoya/Hasso', jobSpec = 'imperialarcher', effects = { EFF.HASSO, EFF.SENGIKORI, EFF.MEIKYO_SHISUI, EFF.SHARPSHOT, CUSTOM_EFF.IMP_OISOYA, CUSTOM_EFF.IMP_BRAND } },
        soulHook = { id = 'sam_drawn_oisoya', kind = 'next_ws_prime', label = 'Drawn Oisoya', nextWsd = { 4, 8, 12, 16, 20 }, nextTp = { 50, 100, 150, 200, 250 } },
    },
    warlord = {
        pfx = 'wrl', pref = 'str', role = 'Support', tier = 'HybridSupport',
        tag = 'Iaijutsu', utilTag = 'Noto', soulTag = 'Ashura',
        stance = { label = 'Noto/Ashura', jobSpec = 'warlord', effects = { EFF.HASSO, EFF.HAGAKURE, EFF.SENGIKORI, EFF.SEKKANOKI, CUSTOM_EFF.WRL_NOTO, CUSTOM_EFF.WRL_ASHURA } },
        soulHook = { id = 'sam_ashura_edge', kind = 'resource_build', label = "Ashura's Edge", localVar = 'OX_WARLORD_ASHURA', delta = { 1, 1, 2, 2, 3 }, maxStack = 5, partyTp = { 35, 65, 95, 125, 155 } },
    },

    -- NIN
    kurogane = {
        pfx = 'krg', pref = 'dex', role = 'Damage', tier = 'Damage', clones = true,
        tag = 'Shinobi', utilTag = 'Flurry', soulTag = 'CloneSync',
        stance = { label = 'Clone Assault', jobSpec = 'kurogane', effects = { EFF.INNIN, EFF.FUTAE, EFF.SANGE } },
        soulHook = { id = 'nin_kurogane_clone_sync', kind = 'clone_interaction', label = 'Clone Sync', localVar = 'OX_KRG_CLONE_SYNC', delta = { 1, 1, 2, 2, 3 }, maxStack = 6, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    kagemusha = {
        pfx = 'kag', pref = 'agi', role = 'Tank', tier = 'Tank',
        tag = 'Yonin', utilTag = 'Decoy', soulTag = 'Utsusemi',
        stance = { label = 'Yonin/Shadow', jobSpec = 'kagemusha', effects = { EFF.YONIN, EFF.FUTAE, EFF.COPY_IMAGE, EFF.ISSEKIGAN, CUSTOM_EFF.KAG_SHADOW } },
        soulHook = { id = 'nin_kagemusha_shadows', kind = 'enmity_surge', label = 'Shadow Veil', enmity = { 5, 10, 15, 20, 25 }, subtleBlow = { 3, 6, 9, 12, 15 } },
    },
    nightblade = {
        pfx = 'ngb', pref = 'dex', role = 'Support', tier = 'Support',
        tag = 'Seal', utilTag = 'Sabotage', soulTag = 'Nightseal',
        stance = { label = 'Reactive Seal', jobSpec = 'nightblade', effects = { EFF.INNIN, EFF.FUTAE, EFF.COPY_IMAGE } },
        soulHook = { id = 'nin_nightblade_seal', kind = 'debuff_extend', label = 'Reactive Seal', targetDebuff = EFF.EVASION_DOWN, debuffPower = { 8, 16, 24, 32, 40 }, partyTp = { 35, 65, 95, 125, 155 } },
    },

    -- DRG
    lancer = {
        pfx = 'lnc', pref = 'str', role = 'Damage', tier = 'Damage',
        tag = 'Vault', utilTag = 'Skewer', soulTag = 'Dragoon',
        stance = { label = 'Vault/Jump', jobSpec = 'lancer', effects = { EFF.SPIRIT_SURGE, EFF.FLY_HIGH } },
        soulHook = { id = 'drg_lancer_vault', kind = 'next_ws_prime', label = 'Vault Momentum', nextWsd = { 4, 8, 12, 16, 20 }, nextTp = { 50, 95, 140, 185, 230 } },
    },
    skyborn = {
        pfx = 'sky', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Skyward', utilTag = 'Grounding', soulTag = 'Aerie',
        stance = { label = 'Skyward Guard', jobSpec = 'skyborn', effects = { EFF.SPIRIT_SURGE, EFF.FLY_HIGH, EFF.SENTINEL } },
        soulHook = { id = 'drg_skyborn_guard', kind = 'enmity_surge', label = 'Grounding Cry', enmity = { 5, 10, 15, 20, 25 }, targetDebuff = EFF.ATTACK_DOWN, debuffPower = { 4, 8, 12, 16, 20 } },
    },
    wyvernheart = {
        pfx = 'wyv', pref = 'mnd', role = 'Healer', tier = 'CombatHealer', pet = true,
        tag = 'Wyrm', utilTag = 'Breath', soulTag = 'Wyrmscale',
        stance = { label = 'Breath/Wyrm', jobSpec = 'wyvernheart', petAlive = true, effects = { EFF.SPIRIT_SURGE, EFF.FLY_HIGH, CUSTOM_EFF.WYV_SCALE } },
        soulHook = { id = 'drg_wyrmscale_breath', kind = 'pet_tp_heal', label = 'Wyrmscale Breath', eosHeal = { 6, 10, 14, 18, 22 }, petTp = { 80, 140, 200, 260, 320 }, partyHealPct = { 2, 3, 4, 5, 6 } },
    },

    -- BLU
    warmage = {
        pfx = 'wmg', pref = 'str', role = 'Damage', tier = 'Damage',
        tag = 'Azure', utilTag = 'Chain', soulTag = 'Warmage',
        stance = { label = 'Chain Affinity', jobSpec = 'warmage', effects = { EFF.CHAIN_AFFINITY, EFF.BURST_AFFINITY, EFF.AZURE_LORE, EFF.EFFLUX } },
        soulHook = { id = 'blu_warmage_surge', kind = 'stance_empower', label = 'Chain Surge', bonusWsd = { 4, 8, 12, 16, 20 }, matt = { 8, 16, 24, 32, 40 } },
    },
    magus = {
        pfx = 'mag', pref = 'mnd', role = 'Healer', tier = 'CombatHealer',
        tag = 'Osmosis', utilTag = 'Conduit', soulTag = 'Mending',
        stance = { label = 'Diffusion/Conduit', jobSpec = 'magus', effects = { EFF.DIFFUSION, EFF.AZURE_LORE, CUSTOM_EFF.MAG_CONDUIT } },
        soulHook = { id = 'blu_magus_mending', kind = 'party_pulse', label = 'Azure Mending', partyHealPct = { 2, 3, 4, 5, 6 }, mpReturn = { 12, 24, 36, 48, 60 } },
    },
    azurebastion = {
        pfx = 'azb', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Carapace', utilTag = 'Chitin', soulTag = 'AzureSurge',
        stance = { label = 'Chitin Carapace', jobSpec = 'azurebastion', effects = { EFF.DIFFUSION, EFF.UNBRIDLED_LEARNING, EFF.PHALANX } },
        soulHook = { id = 'blu_azure_carapace', kind = 'resource_build', label = 'Azure Surge', localVar = 'OX_AZURE_SURGE', delta = { 1, 1, 2, 2, 3 }, maxStack = 5, enmity = { 5, 10, 15, 20, 25 } },
    },

    -- COR
    flintlock = {
        pfx = 'flt', pref = 'agi', role = 'Damage', tier = 'Damage', singleTargetOnly = true,
        tag = 'Deadeye', utilTag = 'Powder', soulTag = 'Chamber',
        stance = { label = 'Deadeye Chamber', jobSpec = 'flintlock', effects = { EFF.CORSAIRS_ROLL, EFF.TRIPLE_SHOT } },
        soulHook = { id = 'cor_flintlock_deadeye', kind = 'tp_refund', label = 'Deadeye Detonation', tpRefund = { 60, 110, 160, 210, 260 }, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    gambler = {
        pfx = 'gmb', pref = 'chr', role = 'Support', tier = 'Support',
        tag = 'Fortune', utilTag = 'Ante', soulTag = 'Jackpot',
        stance = { label = 'Advantage/Roll', jobSpec = 'gambler', effects = { CUSTOM_EFF.GMB_ADV, EFF.CORSAIRS_ROLL, EFF.SAMURAI_ROLL, EFF.CHAOS_ROLL } },
        soulHook = { id = 'cor_gambler_advantage', kind = 'party_pulse', label = 'Loaded Dice', partyTp = { 45, 85, 125, 165, 205 }, macc = { 8, 16, 24, 32, 40 } },
    },
    buccaneer = {
        pfx = 'buc', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Galleon', utilTag = 'Board', soulTag = 'Grapeshot',
        stance = { label = 'Grapeshot', jobSpec = 'buccaneer', effects = { EFF.GALLANTS_ROLL, EFF.SENTINEL } },
        soulHook = { id = 'cor_buccaneer_grapeshot', kind = 'resource_build', label = 'Point-Blank Grapeshot', localVar = 'OX_BUC_GRAPESHOT', delta = { 1, 1, 2, 2, 3 }, maxStack = 5, enmity = { 5, 10, 15, 20, 25 } },
    },

    -- DNC
    bladewheel = {
        pfx = 'blw', pref = 'dex', role = 'Damage', tier = 'Damage',
        tag = 'Chakram', utilTag = 'Flourish', soulTag = 'Wheel',
        stance = { label = 'Bladewheel', jobSpec = 'bladewheel', localVar = 'OX_THROW_STANCE', effects = { EFF.SABER_DANCE, EFF.HASTE_SAMBA, EFF.CLIMACTIC_FLOURISH, EFF.BUILDING_FLOURISH } },
        soulHook = { id = 'dnc_bladewheel_stance', kind = 'tp_refund', label = 'Chakram Momentum', tpRefund = { 55, 105, 155, 205, 255 }, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    vampire = {
        pfx = 'vmp', pref = 'chr', role = 'Healer', tier = 'CombatHealer',
        tag = 'Crimson', utilTag = 'Samba', soulTag = 'Nocturne',
        stance = { label = 'Samba/Trance', jobSpec = 'vampire', effects = { EFF.DRAIN_SAMBA, EFF.TRANCE, EFF.CONTRADANCE, CUSTOM_EFF.VMP_FEAST } },
        soulHook = { id = 'dnc_vampire_feast', kind = 'party_pulse', label = 'Crimson Feast', partyHealPct = { 2, 3, 4, 5, 6 }, hpDrain = { 3, 4, 5, 6, 8 } },
    },
    miragesentinel = {
        pfx = 'mrs', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'FanDance', utilTag = 'Pirouette', soulTag = 'Mirage',
        stance = { label = 'Fan/Pirouette', jobSpec = 'miragesentinel', effects = { EFF.FAN_DANCE, EFF.ISSEKIGAN, EFF.TRANCE } },
        soulHook = { id = 'dnc_mirage_fandance', kind = 'enmity_surge', label = 'Fan Dance Refresh', enmity = { 5, 10, 15, 20, 25 }, subtleBlow = { 3, 6, 9, 12, 15 } },
    },

    -- SCH
    medic = {
        pfx = 'med', pref = 'mnd', role = 'Healer', tier = 'Healer', pet = true,
        tag = 'Triage', utilTag = 'Remedy', soulTag = 'Eos',
        stance = { label = 'White/Eos', schSpec = 'medic', petAlive = true, effects = { EFF.LIGHT_ARTS, EFF.ADDENDUM_WHITE, EFF.SUBLIMATION_ACTIVATED, EFF.SUBLIMATION_COMPLETE } },
        soulHook = { id = 'sch_medic_eos', kind = 'pet_tp_heal', label = 'Eos Triage', eosHeal = { 6, 10, 14, 18, 22 }, partyHealPct = { 2, 3, 4, 5, 6 } },
    },
    sage = {
        pfx = 'sag', pref = 'int', role = 'Damage', tier = 'Damage', pet = true,
        tag = 'Theorem', utilTag = 'Axiom', soulTag = 'Helix',
        stance = { label = 'Black/Fae', schSpec = 'sage', petAlive = true, effects = { EFF.DARK_ARTS, EFF.ADDENDUM_BLACK, EFF.EBULLIENCE, EFF.IMMANENCE } },
        soulHook = { id = 'sch_sage_helix', kind = 'mp_siphon', label = 'Helix Theorem', mpReturn = { 15, 28, 42, 56, 70 }, matt = { 10, 18, 26, 34, 42 } },
    },
    archivist = {
        pfx = 'arc', pref = 'int', role = 'Support', tier = 'Support',
        tag = 'Codex', utilTag = 'Stratagem', soulTag = 'Archive',
        stance = { label = 'Grimoire', jobSpec = 'archivist', effects = { EFF.LIGHT_ARTS, EFF.DARK_ARTS, EFF.IMMANENCE, EFF.ALACRITY } },
        soulHook = { id = 'sch_archivist_tome', kind = 'party_pulse', label = 'Stratagem Pulse', partyTp = { 40, 75, 110, 145, 180 }, mpReturn = { 10, 20, 30, 40, 50 } },
    },

    -- BST
    untamed = {
        pfx = 'unt', pref = 'str', role = 'Damage', tier = 'Damage', pet = true,
        tag = 'Feral', utilTag = 'Maul', soulTag = 'Savagery',
        stance = { label = 'Feral Sync', jobSpec = 'untamed', petAlive = true, effects = { EFF.KILLER_INSTINCT, EFF.UNLEASH } },
        soulHook = { id = 'bst_untamed_feral', kind = 'pet_tp_heal', label = 'Feral Tandem', petTp = { 100, 175, 250, 325, 400 }, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    alphawarden = {
        pfx = 'alw', pref = 'vit', role = 'Tank', tier = 'Tank', pet = true,
        tag = 'Alpha', utilTag = 'PackGuard', soulTag = 'Warden',
        stance = { label = 'Pack Bond', jobSpec = 'alphawarden', petAlive = true, effects = { EFF.KILLER_INSTINCT, EFF.SENTINEL } },
        soulHook = { id = 'bst_alpha_pack', kind = 'pet_tp_heal', label = 'Alpha Pack Mend', eosHeal = { 6, 10, 14, 18, 22 }, petTp = { 80, 140, 200, 260, 320 }, enmity = { 5, 10, 15, 20, 25 } },
    },
    beastspeaker = {
        pfx = 'bsp', pref = 'chr', role = 'Support', tier = 'Support', pet = true,
        tag = 'Call', utilTag = 'Rally', soulTag = 'Pack',
        stance = { label = 'Pack Rally', jobSpec = 'beastspeaker', petAlive = true, effects = { EFF.KILLER_INSTINCT, EFF.SPUR } },
        soulHook = { id = 'bst_beastspeaker_rally', kind = 'pet_tp_heal', label = 'Pack Rally', petTp = { 90, 160, 230, 300, 370 }, partyTp = { 35, 65, 95, 125, 155 } },
    },

    -- SMN
    primalist = {
        pfx = 'prm', pref = 'int', role = 'Damage', tier = 'Damage', pet = true,
        tag = 'Primal', utilTag = 'Pact', soulTag = 'Avatar',
        stance = { label = 'Astral Pact', jobSpec = 'primalist', petAlive = true, effects = { EFF.ASTRAL_FLOW, EFF.AVATARS_FAVOR, EFF.ASTRAL_CONDUIT } },
        soulHook = { id = 'smn_primalist_surge', kind = 'pet_tp_heal', label = 'Primal Conduit', petTp = { 100, 175, 250, 325, 400 }, mpReturn = { 12, 24, 36, 48, 60 } },
    },
    celestial = {
        pfx = 'cel', pref = 'mnd', role = 'Healer', tier = 'Healer', pet = true,
        tag = 'Astral', utilTag = 'Sanctuary', soulTag = 'Starlight',
        stance = { label = 'Astral/Sanctuary', jobSpec = 'celestial', petAlive = true, effects = { EFF.ASTRAL_FLOW, EFF.AVATARS_FAVOR, CUSTOM_EFF.CEL_STAR } },
        soulHook = { id = 'smn_celestial_starlight', kind = 'pet_tp_heal', label = 'Starlight Mend', eosHeal = { 6, 10, 14, 18, 22 }, partyHealPct = { 2, 3, 4, 5, 6 } },
    },
    herald = {
        pfx = 'hld', pref = 'chr', role = 'Support', tier = 'Support', pet = true,
        tag = 'Herald', utilTag = 'Boon', soulTag = 'Favor',
        stance = { label = "Avatar's Favor", jobSpec = 'herald', petAlive = true, effects = { EFF.AVATARS_FAVOR, EFF.ASTRAL_FLOW } },
        soulHook = { id = 'smn_herald_pact', kind = 'pet_tp_heal', label = 'Herald Boon', petTp = { 90, 160, 230, 300, 370 }, partyTp = { 35, 65, 95, 125, 155 } },
    },

    -- PUP
    pugilist = {
        pfx = 'pgl', pref = 'str', role = 'Damage', tier = 'Damage', pet = true, noMp = true,
        tag = 'Tandem', utilTag = 'Sync', soulTag = 'Overdrive',
        stance = { label = 'Tandem/Limiter', jobSpec = 'pugilist', petAlive = true, effects = { EFF.FIRE_MANEUVER, EFF.THUNDER_MANEUVER, EFF.WIND_MANEUVER, EFF.OVERDRIVE } },
        soulHook = { id = 'pup_pugilist_tandem', kind = 'pet_tp_heal', label = 'Tandem Sync', petTp = { 100, 175, 250, 325, 400 }, bonusWsd = { 4, 8, 12, 16, 20 } },
    },
    vanguard = {
        pfx = 'vng', pref = 'vit', role = 'Tank', tier = 'Tank', pet = true, noMp = true,
        tag = 'Bulwark', utilTag = 'Alloy', soulTag = 'Clockwork',
        stance = { label = 'Bulwark/Maneuver', jobSpec = 'vanguard', petAlive = true, effects = { EFF.EARTH_MANEUVER, EFF.LIGHT_MANEUVER, EFF.WATER_MANEUVER, EFF.OVERDRIVE } },
        soulHook = { id = 'pup_vanguard_bulwark', kind = 'pet_tp_heal', label = 'Clockwork Bulwark', eosHeal = { 6, 10, 14, 18, 22 }, petTp = { 80, 140, 200, 260, 320 }, enmity = { 5, 10, 15, 20, 25 } },
    },
    animist = {
        pfx = 'anm', pref = 'mnd', role = 'Healer', tier = 'CombatHealer', pet = true, noMp = true,
        tag = 'Aether', utilTag = 'Repair', soulTag = 'Cell',
        stance = { label = 'Maneuver/Aegis', jobSpec = 'animist', petAlive = true, effects = { EFF.LIGHT_MANEUVER, EFF.WATER_MANEUVER, EFF.WIND_MANEUVER, EFF.EARTH_MANEUVER, EFF.OVERDRIVE, CUSTOM_EFF.ANM_CELL } },
        soulHook = { id = 'pup_animist_cells', kind = 'pet_tp_heal', label = 'Aether Cell Pulse', eosHeal = { 6, 10, 14, 18, 22 }, partyHealPct = { 2, 3, 4, 5, 6 } },
    },

    -- RUN
    spellblade = {
        pfx = 'spb', pref = 'int', role = 'Damage', tier = 'Damage',
        tag = 'Rune', utilTag = 'Sigil', soulTag = 'Edgeflare',
        stance = { label = 'Edgeflare', jobSpec = 'spellblade', effects = { EFF.SWORDPLAY, EFF.IGNIS, EFF.GELUS, EFF.FLABRA, EFF.TELLUS, EFF.SULPOR, EFF.UNDA, EFF.LUX, EFF.TENEBRAE, CUSTOM_EFF.SPB_FLARE, CUSTOM_EFF.SPB_COND, CUSTOM_EFF.SPB_ASCEND } },
        soulHook = { id = 'run_spellblade_conduction', kind = 'resource_build', label = 'Conduction Surge', conductionAdd = { 1, 1, 2, 2, 3 }, matt = { 8, 16, 24, 32, 40 } },
    },
    lifebinder = {
        pfx = 'lfb', pref = 'mnd', role = 'Healer', tier = 'Healer',
        tag = 'Lifetap', utilTag = 'Ward', soulTag = 'Font',
        stance = { label = 'Font/Ward', jobSpec = 'lifebinder', effects = { EFF.VALIANCE, EFF.VALLATION, EFF.SWORDPLAY, EFF.LUX, EFF.UNDA, CUSTOM_EFF.LFB_FONT, CUSTOM_EFF.LFB_WARD } },
        soulHook = { id = 'run_lifebinder_lifetap', kind = 'party_pulse', label = 'Runic Lifetap', partyHealPct = { 2, 3, 4, 5, 6 }, mpReturn = { 10, 20, 30, 40, 50 } },
    },
    inquisitor = {
        pfx = 'inq', pref = 'vit', role = 'Tank', tier = 'Tank',
        tag = 'Verdict', utilTag = 'Inquest', soulTag = 'Battuta',
        stance = { label = 'Battuta/Rune', jobSpec = 'inquisitor', effects = { EFF.SWORDPLAY, EFF.BATTUTA, EFF.PFLUG, EFF.LIEMENT, EFF.VALLATION, EFF.FOIL, CUSTOM_EFF.INQ_BATTUTA, CUSTOM_EFF.INQ_AEGIS, CUSTOM_EFF.INQ_CONV } },
        soulHook = { id = 'run_inquisitor_riposte', kind = 'enmity_surge', label = 'Runic Verdict', enmity = { 5, 10, 15, 20, 25 }, mpReturn = { 8, 16, 24, 32, 40 } },
    },

    -- GEO
    terramancer = {
        pfx = 'trm', pref = 'int', role = 'Damage', tier = 'Damage',
        tag = 'Fault', utilTag = 'Tremor', soulTag = 'Telluric',
        stance = { label = 'Telluric Surge', jobSpec = 'terramancer', effects = { EFF.BOLSTER, EFF.BLAZE_OF_GLORY, EFF.ECLIPTIC_ATTRITION } },
        soulHook = { id = 'geo_terramancer_fault', kind = 'stance_empower', label = 'Faultline Rupture', matt = { 10, 18, 26, 34, 42 }, macc = { 8, 16, 24, 32, 40 } },
    },
    verdant = {
        pfx = 'vrd', pref = 'mnd', role = 'Healer', tier = 'Healer', pet = true,
        tag = 'Sylvan', utilTag = 'Renewal', soulTag = 'Canopy',
        stance = { label = 'Luopan/Canopy', jobSpec = 'verdant', petAlive = true, effects = { EFF.BOLSTER, CUSTOM_EFF.VRD_CANOPY } },
        soulHook = { id = 'geo_verdant_canopy', kind = 'pet_tp_heal', label = "Nature's Surge", eosHeal = { 6, 10, 14, 18, 22 }, partyHealPct = { 2, 3, 4, 5, 6 } },
    },
    diviner = {
        pfx = 'div', pref = 'int', role = 'Support', tier = 'Support', pet = true,
        tag = 'Meridian', utilTag = 'Leyline', soulTag = 'Luopan',
        stance = { label = 'Meridian Luopan', jobSpec = 'diviner', petAlive = true, effects = { EFF.BOLSTER, EFF.BLAZE_OF_GLORY } },
        soulHook = { id = 'geo_diviner_meridian', kind = 'pet_tp_heal', label = 'Meridian Pulse', eosHeal = { 5, 9, 13, 17, 21 }, partyTp = { 35, 65, 95, 125, 155 } },
    },
}

-- Pure Tier-1 DPS defensive status effects that must NEVER appear on Damage-tier Souls
local PURE_DPS_BLOCKED_BUFFS =
{
    [EFF.STONESKIN or 37]     = true,
    [EFF.PHALANX or 116]      = true,
    [EFF.REGEN or 42]         = true,
    [EFF.DEFENSE_BOOST or 93] = true,
}

function M.getProfile(soulKey)
    local norm = E.normalizeSoulKey(soulKey)
    return norm and M.PROFILES[norm] or nil
end

function M.isPureDps(soulKey)
    local p = M.getProfile(soulKey)
    return p ~= nil and p.tier == 'Damage'
end

function M.isTankOrHealer(soulKey)
    local p = M.getProfile(soulKey)
    if p == nil then
        return false
    end
    return p.tier == 'Tank' or p.tier == 'Healer' or p.tier == 'CombatHealer'
end

function M.isPetSoul(soulKey)
    local p = M.getProfile(soulKey)
    return p ~= nil and p.pet == true
end

function M.isNoMpSoul(soulKey)
    local p = M.getProfile(soulKey)
    return p ~= nil and p.noMp == true
end

-- Enforce strict role integrity guardrails on any talent node's effect table
function M.enforceRoleGuardrails(node, soulKey, wsId)
    if node == nil or type(node.effect) ~= 'table' then
        return node
    end
    local p = M.getProfile(soulKey)
    if p == nil then
        return node
    end
    local eff = node.effect

    -- 1. Pure Tier-1 DPS Souls must not gain substantial self-healing, mitigation, or defensive wards
    if p.tier == 'Damage' then
        eff.selfHeal         = nil
        eff.selfMaxHpHealPct = nil
        eff.partyHealPct     = nil
        eff.hpDrain          = nil
        eff.mpToHpPct        = nil
        if type(eff.statusBuffs) == 'table' then
            for i = #eff.statusBuffs, 1, -1 do
                if PURE_DPS_BLOCKED_BUFFS[eff.statusBuffs[i].effect] then
                    table.remove(eff.statusBuffs, i)
                end
            end
            if #eff.statusBuffs == 0 then
                eff.statusBuffs = nil
            end
        end
        if type(eff.partyBuffs) == 'table' then
            for i = #eff.partyBuffs, 1, -1 do
                if PURE_DPS_BLOCKED_BUFFS[eff.partyBuffs[i].effect] then
                    table.remove(eff.partyBuffs, i)
                end
            end
            if #eff.partyBuffs == 0 then
                eff.partyBuffs = nil
            end
        end
    end

    -- 2. Tanks and Healers strip high-variance crit/bonus-hit spikes
    if M.isTankOrHealer(soulKey) then
        eff.bonusHits     = nil
        eff.multiHitfTPAt = nil
        eff.crit          = nil
        eff.critCurve     = nil
        eff.critDmg       = nil
        if type(eff.stance) == 'table' then
            eff.stance.crit    = nil
            eff.stance.critDmg = nil
        end
    end

    -- 3. Pet effects only on genuine pet Souls
    if not p.pet then
        eff.eosHeal = nil
        eff.petTp   = nil
    end

    -- 4. Zero MP / Refresh on no-MP Souls (Chi Weaver, PUP Souls)
    if p.noMp then
        eff.mpDrain   = nil
        eff.mpReturn  = nil
        eff.mpToHpPct = nil
        if type(eff.statusBuffs) == 'table' then
            for i = #eff.statusBuffs, 1, -1 do
                if eff.statusBuffs[i].effect == (EFF.REFRESH or 43) then
                    table.remove(eff.statusBuffs, i)
                end
            end
        end
        if type(eff.partyBuffs) == 'table' then
            for i = #eff.partyBuffs, 1, -1 do
                if eff.partyBuffs[i].effect == (EFF.REFRESH or 43) then
                    table.remove(eff.partyBuffs, i)
                end
            end
        end
    end

    -- 5. PLD Defender Sanguine Blade (#47) sustain abuse cap
    if (soulKey == 'defender' or soulKey == 'aegistemplar') and wsId == 47 then
        if type(eff.hpDrain) == 'table' then
            for i = 1, #eff.hpDrain do
                eff.hpDrain[i] = math.min(8, eff.hpDrain[i])
            end
        elseif type(eff.hpDrain) == 'number' then
            eff.hpDrain = math.min(8, eff.hpDrain)
        end
        eff.selfMaxHpHealPct = nil
    end

    return node
end

return M
