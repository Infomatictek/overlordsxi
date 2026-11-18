-----------------------------------
-- Custom Server Module: Level 75 Cap + 99 QoL + Boss-Like Combat & High EXP
--
-- Features:
--   1. Faster baseline combat pace for players, pets, and mobs (+25% player
--      baseline Haste, +25 Store TP, +20 Regain, +15 Fast Cast; +12-25% mob
--      Haste + Regain/Store TP).
--   2. Progressive Lv 1-75 boss-like combat modifiers on all normal mobs and
--      NMs (scaling across Spec tiers at Lv 10/30/50/70+), plus level-gap
--      scaling (EM-IT soloable with a good spec but tougher; IT++ at +8 levels
--      is the wall) and anti-one-shot breath/suicide move normalization.
--   3. Greatly increased EXP per kill (higher per-monster caps, extended 3x
--      chain timers, boosted chain multipliers, and extra kill multipliers)
--      to compensate for longer, boss-like fights.
--   4. Level 99 QoL unlocks (Mog Sack/Case/Safe 2 & Wardrobes 1-8 resized to
--      80 slots, all 9 Rhapsodies of Vana'diel key items for 5 Trusts + bonuses,
--      all 22 standard jobs unlocked, and all combat/magic skills auto-capped).
--   5. BiS Lv.1 All-Jobs Starter Kit (29 items) auto-granted on new characters
--      and existing logins via `!starterkit`.
--   6. Lv.1 Weapons Shop (`!weapons`, `!startershop`, & city Starter Weapons
--      Moogles) with Featured BiS/HQ page + 5 full catalog pages (263 weapons).
--   7. `!bossstance` & `!combat` player commands.
-----------------------------------
require('modules/module_utils')
require('scripts/combat/physical_utilities')
require('scripts/combat/physical_hit_rate')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/globals/mobs')
require('scripts/globals/mobskills')
require('scripts/globals/experience_points')
require('scripts/globals/player')
require('scripts/globals/server')
require('scripts/globals/shop')
require('scripts/globals/spells/damage_spell')
require('scripts/globals/weaponskills')
require('scripts/zones/Port_San_dOria/Zone')
require('scripts/zones/Northern_San_dOria/Zone')
require('scripts/zones/Bastok_Mines/Zone')
require('scripts/zones/Port_Windurst/Zone')
require('scripts/zones/RuLude_Gardens/Zone')
-----------------------------------
local m = Module:new('boss_like_combat_and_exp')

xi.customBossServer = xi.customBossServer or {}

xi.customBossServer.config =
{
    -- Always-on baseline combat pace & deep HP pool applied to all players so
    -- combat feels brisk and healing spells/abilities have a deep health pool
    -- to work with instead of constantly overhealing.
    -- Note: Regain is intentionally NOT applied as a passive xi.mod.REGAIN modifier;
    -- it is granted via combatRegain ONLY while in verified active combat.
    playerCombatPace =
    {
        { mod = xi.mod.HASTE_GEAR,    amount = 1500 }, -- +15% Gear Haste
        { mod = xi.mod.HASTE_ABILITY, amount = 1000 }, -- +10% Ability Haste (25% total baseline Haste)
        { mod = xi.mod.STORETP,       amount = 25 },   -- +25 Store TP
        { mod = xi.mod.FASTCAST,      amount = 15 },   -- +15% Fast Cast
    },
    playerBaseHpp     = 100, -- +100% of character Base HP (applied via BASE_HP so -HP / Convert HP->MP gear is NOT doubled)
    playerHpPerLevel  = 12,  -- +12 Base HP per level

    -- Always-on baseline combat pace & HP pool applied to player pets/companions.
    petCombatPace =
    {
        { mod = xi.mod.HPP,           amount = 100 },  -- +100% Pet Max HP (2.0x HP)
        { mod = xi.mod.HASTE_MAGIC,   amount = 1500 }, -- +15% Haste
        { mod = xi.mod.STORETP,       amount = 25 },
    },

    -- Active-combat-only Regain (ticks every 3s ONLY when actively exchanging blows/casts/damage
    -- with a live, engaged mob within the last `windowSec` seconds; engaging from afar gives 0).
    combatRegain =
    {
        windowSec    = 6,  -- Must have dealt/taken a real combat action within the last 6s
        playerAmount = 20, -- +20 TP/tick in actual combat
        stanceAmount = 15, -- +15 extra TP/tick in actual combat when !bossstance is enabled
        petAmount    = 15, -- +15 TP/tick for player pets in actual combat
    },

    -- Modifiers added to every regular (non-NM) mob on spawn (scaled by getMobLevelScale(lvl)).
    -- Higher ATTP & MATT pair with levelGap.normalMobBaseDmgMult (1.65x) so mobs chunk
    -- through the deeper player HP pools and make healing feel impactful.
    normalMob =
    {
        hpp                 = 45,
        regain              = 30,
        storetp             = 35,
        defp                = 25,
        mdef                = 18,
        meva                = 18,
        attp                = 45,
        matt                = 32,
        acc                 = 24,
        eva                 = 14,
        haste               = 1800,
        maxHaste            = 2500,
        fastcast            = 18,
        maxFastcast         = 35,
        magicCoolMultiplier = 0.68,
    },

    -- Stronger modifiers added to Notorious Monsters on spawn (scaled by getMobLevelScale(lvl)).
    nm =
    {
        hpp                 = 75,
        regain              = 50,
        storetp             = 50,
        defp                = 38,
        mdef                = 28,
        meva                = 30,
        attp                = 65,
        matt                = 50,
        acc                 = 36,
        eva                 = 22,
        haste               = 2200,
        maxHaste            = 3000,
        fastcast            = 25,
        maxFastcast         = 45,
        magicCoolMultiplier = 0.58,
    },

    -- Level-difference & baseline mob outgoing damage scaling (dLvl = mobLvl - playerLvl):
    --   normalMobBaseDmgMult / nmBaseDmgMult : Baseline outgoing damage multiplier for all wild mobs
    --   dLvl <= 1  : Even Match / low Tough (1.00x player dmg dealt, 1.00x * baseMobMult taken)
    --   dLvl 2..7  : Tough -> IT+ (soloable with a good spec, but takes longer & hits harder)
    --   dLvl >= 8  : IT++ Wall (8+ levels above player: steep mitigation & heavy incoming threat)
    levelGap =
    {
        wallStartDiff        = 8,
        normalMobBaseDmgMult = 1.65, -- 1.65x baseline outgoing damage for normal mobs
        nmBaseDmgMult        = 1.85, -- 1.85x baseline outgoing damage for NMs

        -- Player/Pet damage dealt multiplier vs higher-level mob (dLvl >= 2)
        playerDmgDealt =
        {
            [2] = 0.94, -- Tough (-6%)
            [3] = 0.88, -- VT (-12%)
            [4] = 0.80, -- VT+ (-20%)
            [5] = 0.72, -- IT (-28%)
            [6] = 0.63, -- IT+ (-37%)
            [7] = 0.54, -- High IT+ (-46%)
            [8] = 0.38, -- IT++ Wall (-62%)
            [9] = 0.28, -- IT++ (-72%)
            [10] = 0.20, -- IT++ (-80%)
        },
        playerDmgDealtStepAfter10 = 0.03,
        playerDmgDealtFloor       = 0.12,

        -- Wild Mob extra damage multiplier vs lower-level player/pet (dLvl >= 2), multiplied by baseDmgMult
        mobDmgDealt =
        {
            [2] = 1.08, -- Tough (+8%)
            [3] = 1.16, -- VT (+16%)
            [4] = 1.26, -- VT+ (+26%)
            [5] = 1.38, -- IT (+38%)
            [6] = 1.52, -- IT+ (+52%)
            [7] = 1.68, -- High IT+ (+68%)
            [8] = 1.95, -- IT++ Wall (+95%)
            [9] = 2.25, -- IT++ (+125%)
            [10] = 2.55, -- IT++ (+155%)
        },
        mobDmgDealtStepAfter10 = 0.15,
        mobDmgDealtCap         = 3.00,
    },

    -- Tank pressure tuning: ensures mobs deal meaningful physical damage through heavy
    -- Tank DEF/Block/Parry stacking without increasing damage taken by DPS, Supports, or Healers.
    tankPressure =
    {
        normalMobPdifFloor      = 0.65, -- Raises mob minimum raw pDIF from 0.25 -> 0.65 against high-DEF tanks
        nmPdifFloor             = 0.75, -- Raises NM minimum raw pDIF to 0.75 against high-DEF tanks
        critPdifFloorBonus      = 0.20, -- Extra floor on mob critical hits
        mobMinFstr              = -2,   -- Prevents high VIT from cratering mob base weapon damage below -2 fSTR
        parryPassiveCap         = 50,   -- Max 50% passive/stance Parry rate (65% during active burst CDs)
        parryBurstCap           = 65,
        blockPassiveCap         = 60,   -- Max 60% passive/stance Shield Block rate (75% during active burst CDs)
        blockBurstCap           = 75,
        blockMinBleedthroughPct = 0.35, -- Blocked hits always bleed through at least 35% of the hit (max 65% reduced)
    },

    -- Breath & HP-based suicide move anti-one-shot tuning (scaled for deeper player HP pools).
    breath =
    {
        baseHpDamageMultiplier = 0.85, -- Scales unboosted mob HP breath formula for 2x+ player HP
        normalPerLevelCap      = 9.5,  -- Normal mob breath cap: lvl * 9.5 + 35
        normalFlatCap          = 35,
        nmPerLevelCap          = 13.0, -- NM breath cap: lvl * 13.0 + 55
        nmFlatCap              = 55,
        normalMaxTargetHpShare = 0.35, -- Max 35% of target Max HP at EM/T (scales up on VT/IT/IT++)
        nmMaxTargetHpShare     = 0.45, -- Max 45% of target Max HP for NMs at EM/T
        hardMaxTargetHpShare   = 0.75, -- Absolute cap even on IT++ (75% of target Max HP)
    },

    -- EXP scaling applied with settings/map.lua EXP_RATE = 1.0.
    exp =
    {
        evenMatchTnlShare        = 0.50, -- 50% of TNL per Even-Match kill (2 kills/level)
        nmEvenMatchTnlShare      = 1.00, -- 100% of TNL per Even-Match NM kill (1 kill/level)
        dropPerLevelPct          = 20,   -- -20% of Even-Match EXP per lesser mob level
        higherLevelBonusPerLevel = 0.20, -- +20% of Even-Match EXP per higher mob level
        maxHigherLevelBonusSteps = 5,

        -- Prevents one kill from overflowing multiple levels while matching EM/higher steps.
        maxTnlShare =
        {
            normalEvenMatch      = 0.50,
            normalPerHigherLevel = 0.10,
            normalMax            = 1.00,
            nmMax                = 1.00,
        },

        -- -20% of Even-Match EXP per level below the player (levelDiff < 0).
        lesserLevelMultipliers =
        {
            [-1] = 0.80,
            [-2] = 0.60,
            [-3] = 0.40,
            [-4] = 0.20,
            [-5] = 0.05,
        },
        defaultLesserMultiplier = 0.02,

        -- Matches scripts/globals/experience_points.lua { maxLevel, cap } schema.
        perMonsterCaps =
        {
            { maxLevel = 50,  cap = 50000 },
            { maxLevel = 60,  cap = 60000 },
            { maxLevel = 255, cap = 100000 },
        },

        -- 3x retail chain timers (capped at 600s) for longer boss-like fights.
        chainWindows =
        {
            { maxLevel =   9, start = 150, windows = { 150, 120,  90,  60,  30 } },
            { maxLevel =  19, start = 300, windows = { 300, 240, 180, 120,  60 } },
            { maxLevel =  29, start = 450, windows = { 450, 360, 270, 180,  90 } },
            { maxLevel =  39, start = 600, windows = { 600, 480, 360, 240, 120 } },
            { maxLevel =  49, start = 600, windows = { 600, 600, 450, 300, 150 } },
            { maxLevel =  59, start = 600, windows = { 600, 600, 540, 360, 180 } },
            { maxLevel = 255, start = 600, windows = { 600, 600, 600, 420, 210 } },
        },

        -- 1-indexed chain multipliers for Chains 0, 1, 2, 3, 4, 5+.
        chainMultipliers =
        {
            1.0, -- Chain 0
            1.4, -- Chain 1
            1.6, -- Chain 2
            1.8, -- Chain 3
            2.0, -- Chain 4
            2.5, -- Chain 5+
        },
    },

    -- Toggleable with `!bossstance` — edit or expand these mods when adding
    -- custom player damage-boosting abilities (Regain is handled in combatRegain.stanceAmount).
    playerBuffStance =
    {
        { mod = xi.mod.ATTP,        amount = 35 },
        { mod = xi.mod.RATTP,       amount = 35 },
        { mod = xi.mod.MATT,        amount = 30 },
        { mod = xi.mod.ACC,         amount = 40 },
        { mod = xi.mod.STORETP,     amount = 25 },
        { mod = xi.mod.CRITHITRATE, amount = 10 },
    },

    -- 29 Best-in-Slot Level 1 All-Jobs starter items auto-granted once per character.
    starterKit =
    {
        xi.item.DESTRIER_BERET,
        xi.item.SPROUT_BERET,
        xi.item.CHOCOBO_SHIRT,
        xi.item.RHAPSODY_SHIRT_P1,
        xi.item.DREAM_MITTENS_P1,
        xi.item.DREAM_TROUSERS_P1,
        xi.item.TRACK_PANTS_P1,
        xi.item.DREAM_BOOTS_P1,
        xi.item.SPRINTERS_SHOES,
        xi.item.METAL_SLIME_SHIELD,
        xi.item.MANDRAGUARD,
        xi.item.HAPPY_EGG,
        xi.item.ORPHIC_EGG,
        xi.item.BEAST_COLLAR,
        xi.item.CHOCOBO_PULLUS_TORQUE,
        xi.item.GOLD_MOOGLE_BELT,
        xi.item.DASH_SASH,
        xi.item.CASSIE_EARRING,
        xi.item.METAL_SLIME_EARRING,
        xi.item.SHE_SLIME_EARRING,
        xi.item.NAJIS_LOOP,
        xi.item.SAN_DORIAN_RING,
        xi.item.BASTOKAN_RING,
        xi.item.WINDURSTIAN_RING,
        xi.item.ECHAD_RING,
        xi.item.EMPRESS_BAND,
        xi.item.WARP_RING,
        xi.item.SHAPERS_SHAWL,
        xi.item.DROVERS_MANTLE,
    },

    -- Core Lv.1 All-Jobs slots auto-equipped on new character creation.
    starterKitAutoEquip =
    {
        { id = xi.item.DESTRIER_BERET,        slot = xi.slot.HEAD },
        { id = xi.item.CHOCOBO_SHIRT,         slot = xi.slot.BODY },
        { id = xi.item.DREAM_MITTENS_P1,      slot = xi.slot.HANDS },
        { id = xi.item.DREAM_TROUSERS_P1,     slot = xi.slot.LEGS },
        { id = xi.item.DREAM_BOOTS_P1,        slot = xi.slot.FEET },
        { id = xi.item.HAPPY_EGG,             slot = xi.slot.AMMO },
        { id = xi.item.CHOCOBO_PULLUS_TORQUE, slot = xi.slot.NECK },
        { id = xi.item.GOLD_MOOGLE_BELT,      slot = xi.slot.WAIST },
        { id = xi.item.CASSIE_EARRING,        slot = xi.slot.EAR1 },
        { id = xi.item.METAL_SLIME_EARRING,   slot = xi.slot.EAR2 },
        { id = xi.item.NAJIS_LOOP,            slot = xi.slot.RING1 },
        { id = xi.item.ECHAD_RING,            slot = xi.slot.RING2 },
        { id = xi.item.SHAPERS_SHAWL,         slot = xi.slot.BACK },
    },
}

xi.customBossServer.weaponsShop =
{
    -- Page 0: 58 Curated BiS / HQ Level 1 weapons, ammo, instruments, & bell.
    featured =
    {
        { 17859, 10 }, -- animator
        { 17476, 10 }, -- cat_baghnakhs_+1
        { 16690, 10 }, -- cesti_+1
        { 20533, 10 }, -- worm_feelers_+1
        { 21538, 10 }, -- lizard_fangs_+1
        { 16491, 10 }, -- bronze_knife_+1
        { 16492, 10 }, -- bronze_dagger_+1
        { 16483, 10 }, -- onion_knife
        { 20568, 10 }, -- wind_knife_+1
        { 16753, 10 }, -- ceremonial_dagger
        { 20577, 10 }, -- chicken_knife_ii
        { 16610, 10 }, -- wax_sword_+1
        { 16623, 10 }, -- bronze_sword_+1
        { 16534, 10 }, -- onion_sword
        { 17749, 10 }, -- ibushi_shinai_+1
        { 20667, 10 }, -- blizzard_brand_+1
        { 20669, 10 }, -- firetongue_+1
        { 20714, 10 }, -- excalipoor_ii
        { 21608, 10 }, -- onion_sword_ii
        { 21609, 10 }, -- save_the_queen_ii
        { 20781, 10 }, -- sowilo_claymore
        { 16606, 10 }, -- rusty_greatsword
        { 21658, 10 }, -- brave_blade_ii
        { 16646, 10 }, -- bronze_axe_+1
        { 16640, 10 }, -- bronze_axe
        { 21787, 10 }, -- poison_axe_+1
        { 21760, 10 }, -- dispatchers_axe
        { 16778, 10 }, -- brz._zaghnal_+1
        { 16768, 10 }, -- bronze_zaghnal
        { 21821, 10 }, -- lost_sickle_+1
        { 16862, 10 }, -- harpoon_+1
        { 16832, 10 }, -- harpoon
        { 21868, 10 }, -- sha_wujings_la._+1
        { 16914, 10 }, -- kunai_+1
        { 16896, 10 }, -- kunai
        { 21924, 10 }, -- debahocho_+1
        { 21934, 10 }, -- yagyu_shortblade_+1
        { 17809, 10 }, -- mumeito
        { 17831, 10 }, -- hardwood_katana
        { 21978, 10 }, -- mutsunokami_+1
        { 21966, 10 }, -- zanmato_+1
        { 17137, 10 }, -- ash_club_+1
        { 17087, 10 }, -- maple_wand_+1
        { 17068, 10 }, -- onion_rod
        { 17074, 10 }, -- chocobo_wand
        { 17123, 10 }, -- ash_staff_+1
        { 17104, 10 }, -- onion_staff
        { 17175, 10 }, -- shortbow_+1
        { 17318,  1 }, -- wooden_arrow
        { 17330,  1 }, -- stone_arrow
        { 17228, 10 }, -- light_crossbow_+1
        { 22154, 10 }, -- silver_gun+1
        { 17336,  1 }, -- crossbow_bolt
        { 17343,  1 }, -- bronze_bullet
        { 17296,  1 }, -- pebble
        { 17373, 10 }, -- maple_harp_+1
        { 17844, 10 }, -- flute_+2
        { 21460, 10 }, -- matre_bell
    },

    -- Pages 1..5: Complete catalog of all 263 non-bait, non-GM Lv.1 weapons from xidb.
    catalog =
    {
        -- Page 1 (53 items: Animator, H2H, Dagger, Sword)
        {
            { 17859, 10 }, -- animator
            { 17476, 10 }, -- cat_baghnakhs_+1
            { 16690, 10 }, -- cesti_+1
            { 16405, 10 }, -- cat_baghnakhs
            { 20533, 10 }, -- worm_feelers_+1
            { 21538, 10 }, -- lizard_fangs_+1
            { 16385, 10 }, -- cesti
            { 20514, 10 }, -- aphelion_knuckles
            { 18763, 10 }, -- trainee_scissors
            { 20532, 10 }, -- worm_feelers
            { 21509, 10 }, -- premium_mogti
            { 21530, 10 }, -- tokkosho
            { 21536, 10 }, -- dazbogs_knuckles
            { 21537, 10 }, -- lizard_fangs
            { 16443, 10 }, -- fruit_punches
            { 21520, 10 }, -- ethereal_fists
            { 16491, 10 }, -- bronze_knife_+1
            { 16492, 10 }, -- bronze_dagger_+1
            { 16465, 10 }, -- bronze_knife
            { 16483, 10 }, -- onion_knife
            { 16447, 10 }, -- rusty_dagger
            { 16448, 10 }, -- bronze_dagger
            { 16482, 10 }, -- onion_dagger
            { 20568, 10 }, -- wind_knife_+1
            { 20593, 10 }, -- hedron_dagger
            { 20569, 10 }, -- esikuva
            { 20570, 10 }, -- norgish_dagger
            { 20571, 10 }, -- infiltrator
            { 20573, 10 }, -- aern_dagger
            { 20574, 10 }, -- aern_dagger_ii
            { 20576, 10 }, -- qutrub_knife
            { 21571, 10 }, -- ethereal_dagger
            { 21572, 10 }, -- esoteric_athame
            { 16753, 10 }, -- ceremonial_dagger
            { 20578, 10 }, -- wind_knife
            { 19101, 10 }, -- trainee_knife
            { 19110, 10 }, -- trainees_needle
            { 20577, 10 }, -- chicken_knife_ii
            { 16610, 10 }, -- wax_sword_+1
            { 16623, 10 }, -- bronze_sword_+1
            { 16600, 10 }, -- wax_sword
            { 16535, 10 }, -- bronze_sword
            { 16534, 10 }, -- onion_sword
            { 17749, 10 }, -- ibushi_shinai_+1
            { 20667, 10 }, -- blizzard_brand_+1
            { 20669, 10 }, -- firetongue_+1
            { 20714, 10 }, -- excalipoor_ii
            { 17748, 10 }, -- ibushi_shinai
            { 20656, 10 }, -- ja_ja_sword
            { 20670, 10 }, -- macana
            { 20691, 10 }, -- kyukoto
            { 17764, 10 }, -- trainee_sword
            { 20665, 10 }, -- kamlanauts_sword
        },
        -- Page 2 (53 items: Sword, Great Sword, Axe, Great Axe, Scythe, Polearm)
        {
            { 20666, 10 }, -- blizzard_brand
            { 20668, 10 }, -- firetongue
            { 20674, 10 }, -- aern_sword
            { 20675, 10 }, -- aern_sword_ii
            { 20694, 10 }, -- fermion_sword
            { 20713, 10 }, -- excalipoor
            { 21608, 10 }, -- onion_sword_ii
            { 21623, 10 }, -- twinned_blade
            { 21624, 10 }, -- ethereal_sword
            { 21636, 10 }, -- nihility
            { 21638, 10 }, -- extinction
            { 21609, 10 }, -- save_the_queen_ii
            { 18912, 10 }, -- ark_saber
            { 18913, 10 }, -- ark_sword
            { 20781, 10 }, -- sowilo_claymore
            { 16606, 10 }, -- rusty_greatsword
            { 16607, 10 }, -- chaosbringer
            { 21682, 10 }, -- lament
            { 21658, 10 }, -- brave_blade_ii
            { 21666, 10 }, -- ethereal_great_sword
            { 21680, 10 }, -- goujian
            { 21681, 10 }, -- ophidian_sword
            { 21693, 10 }, -- irradiance_blade
            { 16646, 10 }, -- bronze_axe_+1
            { 16640, 10 }, -- bronze_axe
            { 21713, 10 }, -- ethereal_axe
            { 21741, 10 }, -- demonic_axe
            { 21742, 10 }, -- aern_axe
            { 21743, 10 }, -- aern_axe_ii
            { 21744, 10 }, -- gramks_axe
            { 21745, 10 }, -- dullahan_axe
            { 18545, 10 }, -- ark_tabar
            { 21760, 10 }, -- dispatchers_axe
            { 21787, 10 }, -- poison_axe_+1
            { 18502, 10 }, -- trainee_axe
            { 21759, 10 }, -- autarchs_axe
            { 21761, 10 }, -- zadha_chopper
            { 21770, 10 }, -- helgoland
            { 21771, 10 }, -- ethereal_great_axe
            { 21786, 10 }, -- poison_axe
            { 16778, 10 }, -- brz._zaghnal_+1
            { 16768, 10 }, -- bronze_zaghnal
            { 21821, 10 }, -- lost_sickle_+1
            { 21838, 10 }, -- ethereal_scythe
            { 21840, 10 }, -- mavens_scythe
            { 18567, 10 }, -- colibri_scythe
            { 21820, 10 }, -- lost_sickle
            { 18563, 10 }, -- ark_scythe
            { 20909, 10 }, -- hoe
            { 16862, 10 }, -- harpoon_+1
            { 16832, 10 }, -- harpoon
            { 18103, 10 }, -- pitchfork_+1
            { 21868, 10 }, -- sha_wujings_la._+1
        },
        -- Page 3 (53 items: Polearm, Katana, Great Katana, Club)
        {
            { 18102, 10 }, -- pitchfork
            { 20931, 10 }, -- celestial_spear
            { 20953, 10 }, -- escritorio
            { 21860, 10 }, -- aern_spear
            { 21861, 10 }, -- aern_spear_ii
            { 21867, 10 }, -- sha_wujings_lance
            { 21874, 10 }, -- abyssbringer
            { 21862, 10 }, -- mizukage_naginata
            { 21863, 10 }, -- tzee_xicus_blade
            { 21873, 10 }, -- ethereal_spear
            { 20933, 10 }, -- hotengeki
            { 21886, 10 }, -- iapetus
            { 16914, 10 }, -- kunai_+1
            { 16896, 10 }, -- kunai
            { 21924, 10 }, -- debahocho_+1
            { 21934, 10 }, -- yagyu_shortblade_+1
            { 19274, 10 }, -- trainee_burin
            { 21911, 10 }, -- ethereal_katana
            { 21923, 10 }, -- debahocho
            { 21933, 10 }, -- yagyu_shortblade
            { 17809, 10 }, -- mumeito
            { 17831, 10 }, -- hardwood_katana
            { 21978, 10 }, -- mutsunokami_+1
            { 21966, 10 }, -- zanmato_+1
            { 18441, 10 }, -- shinai
            { 18436, 10 }, -- lotus_katana
            { 17830, 10 }, -- wooden_katana
            { 21024, 10 }, -- ohakari
            { 21962, 10 }, -- ethereal_tachi
            { 21967, 10 }, -- melon_slicer
            { 21977, 10 }, -- mutsunokami
            { 21965, 10 }, -- zanmato
            { 18464, 10 }, -- ark_tachi
            { 17137, 10 }, -- ash_club_+1
            { 17087, 10 }, -- maple_wand_+1
            { 17024, 10 }, -- ash_club
            { 17049, 10 }, -- maple_wand
            { 17058, 10 }, -- caduceus
            { 17074, 10 }, -- chocobo_wand
            { 22046, 10 }, -- feline_hagoita_+1
            { 18400, 10 }, -- charm_wand_+1
            { 18845, 10 }, -- miracle_wand_+1
            { 17068, 10 }, -- onion_rod
            { 18864, 10 }, -- dream_bell_+1
            { 18869, 10 }, -- lady_bell_+1
            { 21108, 10 }, -- kyuka_uchiwa_+1
            { 21997, 10 }, -- magicians_rod_+1
            { 22018, 10 }, -- seika_uchiwa_+1
            { 22020, 10 }, -- jingly_rod_+1
            { 21096, 10 }, -- heartbeater_+1
            { 18399, 10 }, -- charm_wand
            { 18844, 10 }, -- miracle_wand
            { 18846, 10 }, -- battledore
        },
        -- Page 4 (52 items: Club, Staff)
        {
            { 21117, 10 }, -- hagoita
            { 22039, 10 }, -- floral_hagoita
            { 22045, 10 }, -- feline_hagoita
            { 21087, 10 }, -- heartstopper_+1
            { 21098, 10 }, -- leafkin_bopper_+1
            { 21951, 10 }, -- shaded_moogle_rod_+1
            { 18863, 10 }, -- dream_bell
            { 18868, 10 }, -- lady_bell
            { 18889, 10 }, -- momiji_uchiwa
            { 21107, 10 }, -- kyuka_uchiwa
            { 21543, 10 }, -- ryofu_uchiwa
            { 21950, 10 }, -- bud_rod
            { 21996, 10 }, -- magicians_rod
            { 22017, 10 }, -- seika_uchiwa
            { 22019, 10 }, -- jingly_rod
            { 22032, 10 }, -- thunder_hammer
            { 22043, 10 }, -- apkallu_scepter
            { 22044, 10 }, -- tengu_war_fan
            { 22052, 10 }, -- summer_uchiwa
            { 21095, 10 }, -- heartbeater
            { 22004, 10 }, -- soulflayers_wand
            { 22005, 10 }, -- burrowers_wand
            { 17031, 10 }, -- shell_scepter
            { 17032, 10 }, -- gobbie_gavel
            { 18401, 10 }, -- moogle_rod
            { 18842, 10 }, -- nmd._moogle_rod
            { 18871, 10 }, -- kitty_rod
            { 18880, 10 }, -- maestros_baton
            { 18881, 10 }, -- melomane_mallet
            { 21074, 10 }, -- kupo_rod
            { 21086, 10 }, -- heartstopper
            { 21097, 10 }, -- leafkin_bopper
            { 21113, 10 }, -- p._sprig._club
            { 21114, 10 }, -- r._sprig._club
            { 21118, 10 }, -- g._spriggan_club
            { 21949, 10 }, -- shaded_moogle_rod
            { 22003, 10 }, -- arthros_scepter
            { 22047, 10 }, -- korrigan_mallet
            { 22048, 10 }, -- adenium_mallet
            { 22049, 10 }, -- citrullus_mallet
            { 22050, 10 }, -- chac-chacs
            { 22051, 10 }, -- lycopodium_mallet
            { 22053, 10 }, -- ethereal_club
            { 18866, 10 }, -- club_hammer
            { 18855, 10 }, -- trainee_hammer
            { 21542, 10 }, -- ja_ja_mace
            { 17123, 10 }, -- ash_staff_+1
            { 17088, 10 }, -- ash_staff
            { 17104, 10 }, -- onion_staff
            { 21154, 10 }, -- malice_masher_+1
            { 21994, 10 }, -- erudites_staff_+1
            { 21995, 10 }, -- mavens_staff
        },
        -- Page 5 (52 items: Staff, Archery, Marksmanship, Throwing, Instruments, Bell)
        {
            { 17565, 10 }, -- trick_staff
            { 17566, 10 }, -- treat_staff
            { 17583, 10 }, -- kgd._signet_staff
            { 17584, 10 }, -- rep._signet_staff
            { 17585, 10 }, -- fed._signet_staff
            { 18612, 10 }, -- ram_staff
            { 18613, 10 }, -- fourth_staff
            { 18614, 10 }, -- cobra_staff
            { 21153, 10 }, -- malice_masher
            { 22065, 10 }, -- aern_staff
            { 22066, 10 }, -- aern_staff_ii
            { 22067, 10 }, -- levin
            { 22068, 10 }, -- savage._pole
            { 22069, 10 }, -- hapy_staff
            { 22070, 10 }, -- ranine_staff
            { 22071, 10 }, -- profane_staff
            { 22072, 10 }, -- lamia_staff
            { 22089, 10 }, -- sophistry
            { 22090, 10 }, -- ethereal_staff
            { 18600, 10 }, -- cavers_shovel
            { 21993, 10 }, -- erudites_staff
            { 17175, 10 }, -- shortbow_+1
            { 17318,  1 }, -- wooden_arrow
            { 17330,  1 }, -- stone_arrow
            { 17152, 10 }, -- shortbow
            { 17331,  1 }, -- old_arrow
            { 22132, 10 }, -- artemiss_bow_+1
            { 22124, 10 }, -- artemiss_bow
            { 22112, 10 }, -- mizukage-no-yumi
            { 22146, 10 }, -- ethereal_bow
            { 17336,  1 }, -- crossbow_bolt
            { 17339,  1 }, -- bronze_bolt
            { 17335,  1 }, -- rusty_bolt
            { 17228, 10 }, -- light_crossbow_+1
            { 17216, 10 }, -- light_crossbow
            { 17343,  1 }, -- bronze_bullet
            { 22154, 10 }, -- silver_gun+1
            { 21272, 10 }, -- troll_gun
            { 21280, 10 }, -- decazoom_mk-xi
            { 22153, 10 }, -- silver_gun
            { 22165, 10 }, -- ethereal_gun
            { 17296,  1 }, -- pebble
            { 18468,  1 }, -- bonanza_ball
            { 21346,  1 }, -- leafkin_grenade
            { 22282, 10 }, -- grudge
            { 22275,  1 }, -- pamama_peel
            { 17353, 10 }, -- maple_harp
            { 17373, 10 }, -- maple_harp_+1
            { 17345, 10 }, -- flute
            { 17372, 10 }, -- flute_+1
            { 17844, 10 }, -- flute_+2
            { 21460, 10 }, -- matre_bell
        },
    },
}

local qolContainers =
{
    xi.inv.MOGSACK,
    xi.inv.MOGCASE,
    xi.inv.MOGSAFE2,
    xi.inv.WARDROBE,
    xi.inv.WARDROBE2,
    xi.inv.WARDROBE3,
    xi.inv.WARDROBE4,
    xi.inv.WARDROBE5,
    xi.inv.WARDROBE6,
    xi.inv.WARDROBE7,
    xi.inv.WARDROBE8,
}

local rhapsodyKeyItems =
{
    xi.keyItem.RHAPSODY_IN_WHITE,
    xi.keyItem.RHAPSODY_IN_UMBER,
    xi.keyItem.RHAPSODY_IN_AZURE,
    xi.keyItem.RHAPSODY_IN_CRIMSON,
    xi.keyItem.RHAPSODY_IN_EMERALD,
    xi.keyItem.RHAPSODY_IN_MAUVE,
    xi.keyItem.RHAPSODY_IN_FUCHSIA,
    xi.keyItem.RHAPSODY_IN_PUCE,
    xi.keyItem.RHAPSODY_IN_OCHRE,
}

local function applyExperienceTableOverrides()
    local expCfg = xi.customBossServer.config.exp
    xi.experiencePoints.perMonsterCaps   = expCfg.perMonsterCaps
    xi.experiencePoints.chainWindows     = expCfg.chainWindows
    xi.experiencePoints.chainMultipliers = expCfg.chainMultipliers
end

-- Progressive Lv 1-75 scaling curve matching Spec & WS Talent tiers at Lv 10, 30, 50, and 70+.
local function getMobLevelScale(level)
    local lvl = math.max(1, tonumber(level) or 1)
    if lvl <= 1 then
        return 0.25
    elseif lvl <= 9 then
        return 0.25 + (lvl - 1) * 0.05 -- Lv 2..9: 0.30 -> 0.65
    elseif lvl <= 29 then
        return 0.70 + (lvl - 10) * 0.02 -- Lv 10..29: 0.70 -> 1.08
    elseif lvl <= 49 then
        return 1.12 + (lvl - 30) * 0.02 -- Lv 30..49: 1.12 -> 1.50
    elseif lvl <= 69 then
        return 1.55 + (lvl - 50) * 0.02 -- Lv 50..69: 1.55 -> 1.93
    end

    -- Lv 70..75+: 1.98 -> 2.13 (capped at 2.25)
    return math.min(2.25, 1.98 + (lvl - 70) * 0.03)
end

xi.customBossServer.getMobLevelScale = getMobLevelScale

local function isWildMob(entity)
    if entity == nil or not entity.isMob or not entity:isMob() then
        return false
    end

    if entity.isPet and entity:isPet() then
        return false
    end

    if entity.getMaster and entity:getMaster() ~= nil then
        return false
    end

    return true
end

local function getPlayerSideLevel(entity)
    if entity == nil then
        return nil
    end

    if entity.isPC and entity:isPC() then
        return entity.getMainLvl and entity:getMainLvl() or 1
    end

    local master = entity.getMaster and entity:getMaster() or nil
    if master ~= nil and master.isPC and master:isPC() then
        local eLvl = entity.getMainLvl and entity:getMainLvl() or 1
        local mLvl = master.getMainLvl and master:getMainLvl() or 1
        return math.max(eLvl, mLvl)
    end

    return nil
end

local function nowSeconds()
    if GetSystemTime then
        return GetSystemTime()
    end
    return os.time()
end

-- Stamps verified active combat between a player/pet and a wild mob.
-- Engaging (/attack) from afar does NOT call this; an actual swing, WS, spell,
-- ability, or damage exchange must occur.
local function markInActualCombat(actor, target)
    if actor == nil or target == nil or actor == target then
        return
    end

    local mobEntity    = nil
    local playerEntity = nil
    local petEntity    = nil

    if isWildMob(actor) then
        mobEntity = actor
    elseif isWildMob(target) then
        mobEntity = target
    end

    if mobEntity == nil or (mobEntity.isAlive and not mobEntity:isAlive()) then
        return
    end

    local other = (mobEntity == actor) and target or actor
    if other.isPC and other:isPC() then
        playerEntity = other
        if other.getPet then
            petEntity = other:getPet()
        end
    elseif other.isPet and other:isPet() then
        petEntity = other
        if other.getMaster then
            local m = other:getMaster()
            if m and m.isPC and m:isPC() then
                playerEntity = m
            end
        end
    end

    if playerEntity == nil and petEntity == nil then
        return
    end

    local ts    = nowSeconds()
    local mobId = (mobEntity.getID and mobEntity:getID()) or 0

    if mobEntity.setLocalVar then
        mobEntity:setLocalVar('[CustomBoss]LastCombatTs', ts)
    end

    if playerEntity and playerEntity.setLocalVar then
        playerEntity:setLocalVar('[CustomBoss]LastCombatTs', ts)
        if mobId > 0 then
            playerEntity:setLocalVar('[CustomBoss]CombatMobId', mobId)
        end
    end

    if petEntity and petEntity.setLocalVar and petEntity.isAlive and petEntity:isAlive() then
        petEntity:setLocalVar('[CustomBoss]LastCombatTs', ts)
        if mobId > 0 then
            petEntity:setLocalVar('[CustomBoss]CombatMobId', mobId)
        end
    end
end

xi.customBossServer.markInActualCombat = markInActualCombat

-- Returns true ONLY when the entity has dealt or taken an actual combat action
-- within `combatRegain.windowSec` (default 6s) AND the enemy mob is still alive & engaged.
local function isInActualCombat(entity)
    if entity == nil or not entity.getLocalVar then
        return false
    end

    if entity.isAlive and not entity:isAlive() then
        return false
    end

    if entity.hasStatusEffect and xi.effect and xi.effect.HEALING and entity:hasStatusEffect(xi.effect.HEALING) then
        return false
    end

    local regainCfg = xi.customBossServer.config.combatRegain or {}
    local windowSec = regainCfg.windowSec or 6
    local lastTs    = entity:getLocalVar('[CustomBoss]LastCombatTs')
    if lastTs <= 0 or (nowSeconds() - lastTs) > windowSec then
        return false
    end

    if isWildMob(entity) then
        return (entity.isEngaged and entity:isEngaged()) or false
    end

    -- Check current target first
    local targ = entity.getTarget and entity:getTarget() or nil
    if isWildMob(targ) and (not targ.isAlive or targ:isAlive()) and (not targ.isEngaged or targ:isEngaged()) then
        return true
    end

    -- Or check the last combat mob ID in the same zone
    local mobId = entity:getLocalVar('[CustomBoss]CombatMobId')
    if mobId > 0 and GetMobByID then
        local mob = GetMobByID(mobId)
        if isWildMob(mob) and (not mob.isAlive or mob:isAlive()) and (not mob.isEngaged or mob:isEngaged()) then
            return true
        end
    end

    return false
end

xi.customBossServer.isInActualCombat = isInActualCombat

-- Processes 3s combat-only Regain on EFFECTS_TICK and cancels any out-of-combat
-- xi.mod.REGAIN tick from TickRegen so Regain NEVER ticks out of actual combat.
local function onEntityCombatRegainTick(entity)
    if entity == nil or (entity.isAlive and not entity:isAlive()) then
        return
    end

    local inCombat  = isInActualCombat(entity)
    local regainCfg = xi.customBossServer.config.combatRegain or {}

    if isWildMob(entity) then
        if inCombat and entity.addTP then
            local mobRegain = entity:getLocalVar('[CustomBoss]MobRegain')
            if mobRegain > 0 then
                entity:addTP(mobRegain)
            end
        end
        return
    end

    if not inCombat then
        -- Cancel out any xi.mod.REGAIN that CStatusEffectContainer::TickRegen just added
        -- so gear/buff Regain never builds TP while idle or /attack-locked from afar.
        if entity.getMod and entity.delTP and entity.getTP then
            local passiveRegain = (entity:getMod(xi.mod.REGAIN) or 0) - (entity:getMod(xi.mod.REGAIN_DOWN) or 0)
            if passiveRegain > 0 then
                local curTp = entity:getTP() or 0
                if curTp > 0 then
                    entity:delTP(math.min(curTp, passiveRegain))
                end
            end
        end
        return
    end

    if entity.isPC and entity:isPC() then
        local amt = regainCfg.playerAmount or 20
        if entity:getLocalVar('[CustomBoss]StanceApplied') == 1 then
            amt = amt + (regainCfg.stanceAmount or 15)
        end
        if amt > 0 and entity.addTP then
            entity:addTP(amt)
        end
    elseif entity.isPet and entity:isPet() then
        local amt = regainCfg.petAmount or 15
        if amt > 0 and entity.addTP then
            entity:addTP(amt)
        end
    end
end

xi.customBossServer.onEntityCombatRegainTick = onEntityCombatRegainTick

-- Applies or refreshes the baseline combat pace on a player pet without stacking.
local function applyPetCombatPace(pet)
    if pet == nil or not pet.getLocalVar then
        return
    end

    local master = pet.getMaster and pet:getMaster() or nil
    if master == nil or not master.isPC or not master:isPC() then
        return
    end

    if pet.addListener and pet:getLocalVar('[CustomBoss]PetListenersBound') == 0 then
        pet:setLocalVar('[CustomBoss]PetListenersBound', 1)
        pet:addListener('EFFECTS_TICK', 'CUSTOM_BOSS_PET_REGAIN', function(p)
            onEntityCombatRegainTick(p)
        end)
        pet:addListener('MELEE_SWING_HIT', 'CUSTOM_BOSS_PET_HIT', function(p, targ)
            markInActualCombat(p, targ)
        end)
        pet:addListener('MELEE_SWING_MISS', 'CUSTOM_BOSS_PET_MISS', function(p, targ)
            markInActualCombat(p, targ)
        end)
        pet:addListener('TAKE_DAMAGE', 'CUSTOM_BOSS_PET_DMG', function(p, amount, attacker)
            if (tonumber(amount) or 0) > 0 and attacker then
                markInActualCombat(p, attacker)
            end
        end)
    end

    if pet:getLocalVar('[CustomBoss]PetPaceApplied') == 1 then
        return
    end

    local paceCfg = xi.customBossServer.config.petCombatPace or {}
    local prevHpp = pet.getHPP and pet:getHPP() or 100
    if pet.addMod then
        for _, entry in ipairs(paceCfg) do
            pet:addMod(entry.mod, entry.amount)
        end
    end

    if pet.updateHealth then
        pet:updateHealth()
        if (not pet.isEngaged or not pet:isEngaged()) or prevHpp >= 95 then
            if pet.addHP and pet.getMaxHP then
                pet:addHP(pet:getMaxHP())
            end
        end
    end

    pet:setLocalVar('[CustomBoss]PetPaceApplied', 1)
end

-- Applies progressive Lv 1-75 boss-like modifiers to a wild mob once per spawn life.
local function applyMobScaling(mob)
    if not isWildMob(mob) then
        return
    end

    -- Attach persistent spawn/engage/tick listeners once per mob entity so respawns
    -- are scaled immediately at spawn and Regain only ticks during active combat.
    if mob.addListener and mob:getLocalVar('[CustomBoss]ListenersBound') == 0 then
        mob:setLocalVar('[CustomBoss]ListenersBound', 1)
        mob:addListener('SPAWN', 'CUSTOM_BOSS_SPAWN', function(spawnedMob)
            if spawnedMob then
                spawnedMob:setLocalVar('[CustomBoss]ListenersBound', 1)
                xi.customBossServer.applyMobScaling(spawnedMob)
            end
        end)
        mob:addListener('ENGAGE', 'CUSTOM_BOSS_ENGAGE', function(engagedMob, target)
            if engagedMob then
                xi.customBossServer.applyMobScaling(engagedMob)
            end
            if target and target.isPet and target:isPet() then
                applyPetCombatPace(target)
            end
        end)
        mob:addListener('EFFECTS_TICK', 'CUSTOM_BOSS_MOB_REGAIN', function(tickMob)
            onEntityCombatRegainTick(tickMob)
        end)
    end

    if mob:getLocalVar('[CustomBoss]Applied') == 1 then
        return
    end

    mob:setLocalVar('[CustomBoss]Applied', 1)

    local mobLvl    = mob:getMainLvl()
    local cfg       = xi.customBossServer.config
    local preset    = mob:isNM() and cfg.nm or cfg.normalMob
    local scale     = getMobLevelScale(mobLvl)
    local hasteAmt  = math.min(preset.maxHaste or 2500, math.floor((preset.haste or 1800) * scale))
    local fcAmt     = math.min(preset.maxFastcast or 35, math.floor((preset.fastcast or 15) * scale))
    local hppBonus  = (mobLvl >= 2 and preset.hpp and preset.hpp > 0) and math.floor(preset.hpp * scale) or 0
    local mobRegain = math.floor((preset.regain or 30) * scale)

    -- Store combat-only Regain on localVar instead of xi.mod.REGAIN so mobs only gain
    -- Regain TP while actively fighting (never when idle or kited without combat).
    mob:setLocalVar('[CustomBoss]MobRegain', mobRegain)

    local mobMods =
    {
        { xi.mod.STORETP,     math.floor((preset.storetp or 35) * scale) },
        { xi.mod.DEFP,        math.floor((preset.defp or 25) * scale) },
        { xi.mod.MDEF,        math.floor((preset.mdef or 18) * scale) },
        { xi.mod.MEVA,        math.floor((preset.meva or 18) * scale) },
        { xi.mod.ATTP,        math.floor((preset.attp or 22) * scale) },
        { xi.mod.MATT,        math.floor((preset.matt or 14) * scale) },
        { xi.mod.ACC,         math.floor((preset.acc or 22) * scale) },
        { xi.mod.EVA,         math.floor((preset.eva or 14) * scale) },
        { xi.mod.HASTE_MAGIC, hasteAmt },
        { xi.mod.FASTCAST,    fcAmt },
    }

    if hppBonus > 0 then
        table.insert(mobMods, { xi.mod.HPP, hppBonus })
        mob:setLocalVar('[CustomBoss]HppBonus', hppBonus)
    end

    for _, modPair in ipairs(mobMods) do
        if modPair[2] and modPair[2] > 0 then
            mob:addMod(modPair[1], modPair[2])
        end
    end

    if hppBonus > 0 then
        local prevHpp = mob.getHPP and mob:getHPP() or 100
        mob:updateHealth()
        if not mob:isEngaged() or prevHpp >= 95 then
            mob:addHP(mob:getMaxHP())
        else
            local targetHp = math.max(1, math.floor(mob:getMaxHP() * (prevHpp / 100)))
            if targetHp > mob:getHP() then
                mob:addHP(targetHp - mob:getHP())
            end
        end
    end

    local currentCool = mob:getMobMod(xi.mobMod.MAGIC_COOL)
    if currentCool > 0 and preset.magicCoolMultiplier then
        mob:setMobMod(xi.mobMod.MAGIC_COOL, math.max(10, math.floor(currentCool * preset.magicCoolMultiplier)))
    end
end

xi.customBossServer.applyMobScaling = applyMobScaling

local function ensureCombatEntitiesScaled(actor, target)
    if isWildMob(actor) then
        applyMobScaling(actor)
    elseif actor and actor.isPet and actor:isPet() then
        applyPetCombatPace(actor)
    end

    if isWildMob(target) then
        applyMobScaling(target)
    elseif target and target.isPet and target:isPet() then
        applyPetCombatPace(target)
    end
end

local function scanAndScaleZoneMobs(zone)
    if zone == nil or not zone.getMobs then
        return
    end

    local ok, mobs = pcall(function()
        return zone:getMobs()
    end)
    if not ok or type(mobs) ~= 'table' then
        return
    end

    for _, mob in pairs(mobs) do
        if isWildMob(mob) then
            applyMobScaling(mob)
        end
    end
end

-- Returns the damage multiplier based on level gap between a player/pet and a wild mob.
local function getLevelGapDamageMultiplier(attacker, defender)
    ensureCombatEntitiesScaled(attacker, defender)

    local gapCfg = xi.customBossServer.config.levelGap
    if not gapCfg then
        return 1.0
    end

    -- Case 1: Player / Pet / Trust attacking a Wild Mob
    local attackerPlayerLvl = getPlayerSideLevel(attacker)
    if attackerPlayerLvl ~= nil and isWildMob(defender) then
        local mobLvl = defender:getMainLvl()
        local dLvl   = mobLvl - attackerPlayerLvl
        if dLvl <= 1 then
            return 1.0
        end

        local tbl = gapCfg.playerDmgDealt or {}
        if tbl[dLvl] ~= nil then
            return tbl[dLvl]
        end

        local base10 = tbl[10] or 0.20
        local step   = gapCfg.playerDmgDealtStepAfter10 or 0.03
        local floor  = gapCfg.playerDmgDealtFloor or 0.12
        return math.max(floor, base10 - math.max(0, dLvl - 10) * step)
    end

    -- Case 2: Wild Mob attacking a Player / Pet / Trust
    local defenderPlayerLvl = getPlayerSideLevel(defender)
    if isWildMob(attacker) and defenderPlayerLvl ~= nil then
        local mobLvl  = attacker:getMainLvl()
        local dLvl    = mobLvl - defenderPlayerLvl
        local isNM    = attacker.isNM and attacker:isNM() or false
        local baseOut = isNM and (gapCfg.nmBaseDmgMult or 1.85) or (gapCfg.normalMobBaseDmgMult or 1.65)
        if dLvl <= 1 then
            return baseOut
        end

        local tbl = gapCfg.mobDmgDealt or {}
        if tbl[dLvl] ~= nil then
            return baseOut * tbl[dLvl]
        end

        local base10 = tbl[10] or 2.55
        local step   = gapCfg.mobDmgDealtStepAfter10 or 0.15
        local cap    = gapCfg.mobDmgDealtCap or 3.00
        return baseOut * math.min(cap, base10 + math.max(0, dLvl - 10) * step)
    end

    return 1.0
end

xi.customBossServer.getLevelGapDamageMultiplier = getLevelGapDamageMultiplier

xi.customBossServer.scaleDamageByLevelGap = function(attacker, defender, damage)
    local dmg = tonumber(damage) or 0
    if dmg <= 0 then
        return 0
    end

    markInActualCombat(attacker, defender)

    local mult = getLevelGapDamageMultiplier(attacker, defender)
    if mult == 1.0 then
        return math.floor(dmg)
    end

    return math.max(1, math.floor(dmg * mult + 0.5))
end

-- Returns physical hit-rate adjustment (in 0..1 fraction) for level differences.
local function getLevelGapHitRateDelta(attacker, defender)
    ensureCombatEntitiesScaled(attacker, defender)

    local attackerPlayerLvl = getPlayerSideLevel(attacker)
    if attackerPlayerLvl ~= nil and isWildMob(defender) then
        local dLvl = defender:getMainLvl() - attackerPlayerLvl
        if dLvl <= 1 then
            return 0
        elseif dLvl <= 7 then
            return -0.02 * (dLvl - 1) -- -2% to -12% on Tough..IT+
        else
            return -0.12 - (dLvl - 7) * 0.05 -- Steep penalty on IT++ (8+ levels higher)
        end
    end

    local defenderPlayerLvl = getPlayerSideLevel(defender)
    if isWildMob(attacker) and defenderPlayerLvl ~= nil then
        local dLvl = attacker:getMainLvl() - defenderPlayerLvl
        if dLvl <= 1 then
            return 0
        elseif dLvl <= 7 then
            return 0.02 * (dLvl - 1) -- +2% to +12% on Tough..IT+
        else
            return 0.12 + (dLvl - 7) * 0.04 -- +16% to +28% on IT++
        end
    end

    return 0
end

-- Returns magic accuracy offset for level differences.
local function getLevelGapMagicAccDelta(actor, target)
    ensureCombatEntitiesScaled(actor, target)

    local actorPlayerLvl = getPlayerSideLevel(actor)
    if actorPlayerLvl ~= nil and isWildMob(target) then
        local dLvl = target:getMainLvl() - actorPlayerLvl
        if dLvl <= 1 then
            return 0
        elseif dLvl <= 7 then
            return -3 * (dLvl - 1) -- -3 to -18 MACC on Tough..IT+
        else
            return -18 - (dLvl - 7) * 10 -- Steep MACC wall on IT++ (8+ levels higher)
        end
    end

    local targetPlayerLvl = getPlayerSideLevel(target)
    if isWildMob(actor) and targetPlayerLvl ~= nil then
        local dLvl = actor:getMainLvl() - targetPlayerLvl
        if dLvl <= 1 then
            return 0
        elseif dLvl <= 7 then
            return 3 * (dLvl - 1)
        else
            return 18 + (dLvl - 7) * 8
        end
    end

    return 0
end

local function grantStarterKit(player, isNewChar)
    local cfg          = xi.customBossServer.config
    local addedCount   = 0
    local skippedCount = 0

    for _, itemId in ipairs(cfg.starterKit) do
        if not player:hasItem(itemId) then
            if player:getFreeSlotsCount() > 0 and player:addItem(itemId) then
                addedCount = addedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end

    if skippedCount == 0 then
        player:setCharVar('[CustomBoss]StarterKit', 1)
    end

    if isNewChar then
        for _, entry in ipairs(cfg.starterKitAutoEquip) do
            if player:hasItem(entry.id, xi.inv.INVENTORY) then
                player:equipItem(entry.id, xi.inv.INVENTORY, entry.slot)
            end
        end
    end

    return addedCount, skippedCount
end

local function applyQoLUnlocks(player)
    for _, container in ipairs(qolContainers) do
        local currentSize = player:getContainerSize(container)
        if currentSize < 80 then
            player:changeContainerSize(container, 80 - currentSize)
        end
    end

    for _, keyItemId in ipairs(rhapsodyKeyItems) do
        if not player:hasKeyItem(keyItemId) then
            player:addKeyItem(keyItemId)
        end
    end

    for jobId = xi.job.NONE, xi.job.RUN do
        if not player:hasJob(jobId) then
            player:unlockJob(jobId)
        end
    end
end

local function openWeaponsShop(player, page)
    local shopCfg   = xi.customBossServer.weaponsShop
    local pageIndex = tonumber(page) or 0
    local stock     = pageIndex == 0 and shopCfg.featured or shopCfg.catalog[pageIndex]

    if not stock then
        player:printToPlayer('Invalid weapons shop page. Use 0 (Featured BiS) or 1-5 (Full Lv.1 Catalog).', xi.msg.channel.SYSTEM_3, '')
        return
    end

    local label = pageIndex == 0
        and string.format('Featured BiS & HQ Lv.1 Weapons (%d items). Type !weapons 1-5 for all %d Lv.1 weapons.', #stock, 263)
        or string.format('All Lv.1 Weapons Catalog - Page %d of %d (%d items). Type !weapons 0 for Featured BiS.', pageIndex, #shopCfg.catalog, #stock)

    player:printToPlayer(label, xi.msg.channel.SYSTEM_3, '')
    xi.shop.general(player, stock)
end

local function showStarterWeaponsMenu(player, menuPage)
    local function openShopDelayed(page)
        return function(playerArg)
            playerArg:timer(50, function(delayedPlayer)
                openWeaponsShop(delayedPlayer, page)
            end)
        end
    end

    local pageOptions =
    {
        [1] =
        {
            { 'Featured BiS & HQ (p.0)',       openShopDelayed(0) },
            { 'Catalog p.1 (H2H/Dgr/Swd)',     openShopDelayed(1) },
            { 'Catalog p.2 (Swd/GS/Axe/Scy)',  openShopDelayed(2) },
            {
                'More Pages ->',
                function(playerArg)
                    showStarterWeaponsMenu(playerArg, 2)
                end,
            },
        },
        [2] =
        {
            { 'Catalog p.3 (Pol/Kat/GKt/Clb)', openShopDelayed(3) },
            { 'Catalog p.4 (Clubs)',           openShopDelayed(4) },
            { 'Catalog p.5 (Stf/Rng/Inst/Bell)', openShopDelayed(5) },
            {
                '<- Back',
                function(playerArg)
                    showStarterWeaponsMenu(playerArg, 1)
                end,
            },
        },
    }

    local menu =
    {
        title   = 'Lv.1 Weapons Shop',
        options = pageOptions[menuPage] or pageOptions[1],
    }

    player:timer(50, function(playerArg)
        playerArg:customMenu(menu)
    end)
end

-- Applies or refreshes the always-on baseline player combat pace & deep HP pool cleanly without stacking.
-- Uses xi.mod.BASE_HP (scaled from player:getBaseHP()) instead of xi.mod.HPP so negative-HP gear
-- and "Convert HP to MP" items are never doubled.
xi.customBossServer.applyPlayerCombatPace = function(player, enable)
    if player == nil or not player.getLocalVar then
        return
    end

    local cfg       = xi.customBossServer.config
    local paceCfg   = cfg.playerCombatPace or {}
    local isApplied = player:getLocalVar('[CustomBoss]PaceApplied') == 1
    local prevHpp   = player:getLocalVar('[CustomBoss]PaceHpp')
    local prevFlat  = player:getLocalVar('[CustomBoss]PaceFlatHp')
    local prevBase  = player:getLocalVar('[CustomBoss]PaceBaseHp')
    local curHppPct = player.getHPP and player:getHPP() or 100

    -- Clean up any legacy PaceHpp / PaceFlatHp from earlier versions
    if prevHpp > 0 then
        player:delMod(xi.mod.HPP, prevHpp)
        player:setLocalVar('[CustomBoss]PaceHpp', 0)
    end
    if prevFlat > 0 then
        player:delMod(xi.mod.HP, prevFlat)
        player:setLocalVar('[CustomBoss]PaceFlatHp', 0)
    end

    if not enable then
        if isApplied then
            for _, entry in ipairs(paceCfg) do
                player:delMod(entry.mod, entry.amount)
            end
            player:setLocalVar('[CustomBoss]PaceApplied', 0)
        end
        if prevBase > 0 then
            player:delMod(xi.mod.BASE_HP, prevBase)
            player:setLocalVar('[CustomBoss]PaceBaseHp', 0)
        end
        if player.updateHealth then
            player:updateHealth()
        end
        return
    end

    if not isApplied then
        for _, entry in ipairs(paceCfg) do
            player:addMod(entry.mod, entry.amount)
        end
        player:setLocalVar('[CustomBoss]PaceApplied', 1)
    end

    local lvl        = (player.getMainLvl and player:getMainLvl()) or 1
    local rawBaseHp  = (player.getBaseHP and player:getBaseHP()) or (lvl * 20)
    local hppPct     = math.max(0, tonumber(cfg.playerBaseHpp) or 100)
    local perLvl     = math.max(0, tonumber(cfg.playerHpPerLevel) or 12)
    local targetBase = math.max(0, math.floor(rawBaseHp * (hppPct / 100) + lvl * perLvl))

    if prevBase ~= targetBase then
        if prevBase > 0 then
            player:delMod(xi.mod.BASE_HP, prevBase)
        end
        if targetBase > 0 then
            player:addMod(xi.mod.BASE_HP, targetBase)
        end
        player:setLocalVar('[CustomBoss]PaceBaseHp', targetBase)

        if player.updateHealth then
            player:updateHealth()
            if not isInActualCombat(player) or curHppPct >= 95 then
                if player.addHP and player.getMaxHP then
                    player:addHP(player:getMaxHP())
                end
            end
        end
    end
end

-- Applies or removes the custom player offensive stance modifiers cleanly without stacking.
xi.customBossServer.applyCustomPlayerBuffs = function(player, enable)
    local isApplied = player:getLocalVar('[CustomBoss]StanceApplied') == 1

    if enable and not isApplied then
        for _, entry in ipairs(xi.customBossServer.config.playerBuffStance) do
            player:addMod(entry.mod, entry.amount)
        end

        player:setLocalVar('[CustomBoss]StanceApplied', 1)
    elseif not enable and isApplied then
        for _, entry in ipairs(xi.customBossServer.config.playerBuffStance) do
            player:delMod(entry.mod, entry.amount)
        end

        player:setLocalVar('[CustomBoss]StanceApplied', 0)
    end
end

local function attachPlayerCombatListeners(player)
    if player == nil or not player.addListener then
        return
    end

    player:removeListener('CUSTOM_BOSS_PC_ENGAGE')
    player:removeListener('CUSTOM_BOSS_PC_DISENGAGE')
    player:removeListener('CUSTOM_BOSS_PC_REGAIN')
    player:removeListener('CUSTOM_BOSS_PC_HIT')
    player:removeListener('CUSTOM_BOSS_PC_MISS')
    player:removeListener('CUSTOM_BOSS_PC_DMG')
    player:removeListener('CUSTOM_BOSS_PC_WS')
    player:removeListener('CUSTOM_BOSS_PC_MAGIC')
    player:removeListener('CUSTOM_BOSS_PC_ABILITY')

    player:addListener('ENGAGE', 'CUSTOM_BOSS_PC_ENGAGE', function(pc, target)
        if isWildMob(target) then
            applyMobScaling(target)
        end
        if pc and pc.getPet then
            local pet = pc:getPet()
            if pet then
                applyPetCombatPace(pet)
            end
        end
    end)

    player:addListener('DISENGAGE', 'CUSTOM_BOSS_PC_DISENGAGE', function(pc)
        if pc and pc.setLocalVar then
            pc:setLocalVar('[CustomBoss]LastCombatTs', 0)
            pc:setLocalVar('[CustomBoss]CombatMobId', 0)
        end
    end)

    player:addListener('EFFECTS_TICK', 'CUSTOM_BOSS_PC_REGAIN', function(pc)
        xi.customBossServer.applyPlayerCombatPace(pc, true)
        onEntityCombatRegainTick(pc)
        if pc and pc.getPet then
            local pet = pc:getPet()
            if pet then
                applyPetCombatPace(pet)
            end
        end
    end)

    player:addListener('MELEE_SWING_HIT', 'CUSTOM_BOSS_PC_HIT', function(pc, target)
        markInActualCombat(pc, target)
    end)

    player:addListener('MELEE_SWING_MISS', 'CUSTOM_BOSS_PC_MISS', function(pc, target)
        markInActualCombat(pc, target)
    end)

    player:addListener('TAKE_DAMAGE', 'CUSTOM_BOSS_PC_DMG', function(pc, amount, attacker)
        if (tonumber(amount) or 0) > 0 and attacker then
            markInActualCombat(pc, attacker)
        end
    end)

    player:addListener('WEAPONSKILL_USE', 'CUSTOM_BOSS_PC_WS', function(pc, target)
        markInActualCombat(pc, target)
    end)

    player:addListener('MAGIC_USE', 'CUSTOM_BOSS_PC_MAGIC', function(pc, target)
        if isWildMob(target) then
            markInActualCombat(pc, target)
        elseif target ~= nil and isInActualCombat(target) then
            -- Party healer/buffer casting on an ally who is actively in combat
            local mobId = target.getLocalVar and target:getLocalVar('[CustomBoss]CombatMobId') or 0
            if pc.setLocalVar then
                pc:setLocalVar('[CustomBoss]LastCombatTs', nowSeconds())
                if mobId > 0 then
                    pc:setLocalVar('[CustomBoss]CombatMobId', mobId)
                end
            end
        end
    end)

    player:addListener('ABILITY_USE', 'CUSTOM_BOSS_PC_ABILITY', function(pc, target)
        if isWildMob(target) then
            markInActualCombat(pc, target)
        elseif target ~= nil and target ~= pc and isInActualCombat(target) then
            local mobId = target.getLocalVar and target:getLocalVar('[CustomBoss]CombatMobId') or 0
            if pc.setLocalVar then
                pc:setLocalVar('[CustomBoss]LastCombatTs', nowSeconds())
                if mobId > 0 then
                    pc:setLocalVar('[CustomBoss]CombatMobId', mobId)
                end
            end
        end
    end)
end

local function getPartyExpScale(member, data)
    local hasSignet = member and member:hasStatusEffect(xi.effect.SIGNET)
        and data.regionId and data.regionId >= xi.region.RONFAURE and data.regionId <= xi.region.JEUNO
        or false

    local partyShare = 1.0
    if data.partySize and data.partySize > 1 then
        partyShare = xi.experiencePoints.getExperienceShare(data.partySize, hasSignet)
    end

    local partyGrade = 1.0
    if data.highestMemberLevel and data.memberLevel and data.highestMemberLevel > data.memberLevel then
        if data.highestMemberLevel > 50 or data.highestMemberLevel > data.memberLevel + 7 then
            partyGrade = data.memberLevel / data.highestMemberLevel
        elseif data.highestMemberTNL and data.highestMemberTNL > 0 and data.memberTNL and data.memberTNL > 0 then
            partyGrade = data.memberTNL / data.highestMemberTNL
        end
    end

    return partyShare * partyGrade
end

local function scaleCalculatedExp(result, member, mob, data)
    if not result or not result.exp or result.exp <= 0 or not data then
        return result
    end

    local expCfg    = xi.customBossServer.config.exp
    local capCfg    = expCfg.maxTnlShare
    local isNM      = mob and mob:isNM()
    local mobLvl    = (mob and (mob:getMainLvl() + mob:getMod(xi.mod.EXP_LVL_MOD))) or data.highestMemberLevel
    local refLevel  = data.highestMemberLevel or (member and member:getMainLvl()) or mobLvl
    local levelDiff = mobLvl - refLevel
    local memberTNL = data.memberTNL or 0

    if memberTNL <= 0 then
        return result
    end

    -- Anchor Even Match directly to % of TNL so solo leveling pace stays consistent from Lv 1 to 75.
    local emShare = isNM and expCfg.nmEvenMatchTnlShare or expCfg.evenMatchTnlShare
    local evenExp = memberTNL * emShare * getPartyExpScale(member, data)

    if levelDiff < 0 then
        local lesserMult = expCfg.lesserLevelMultipliers[levelDiff] or expCfg.defaultLesserMultiplier
        local capShare   = isNM and capCfg.nmMax or capCfg.normalMax
        result.exp       = math.max(1, math.floor(math.min(evenExp * lesserMult, memberTNL * capShare)))
    else
        local higherSteps = math.min(levelDiff, expCfg.maxHigherLevelBonusSteps)
        local chainMult   = 1.0
        if result.chainActive and data.chainNumber then
            local chains = xi.experiencePoints.chainMultipliers
            chainMult    = chains[math.min(data.chainNumber + 1, #chains)] or 1.0
        end

        local scaledExp = evenExp * (1 + higherSteps * expCfg.higherLevelBonusPerLevel) * chainMult
        local tnlShare  = isNM and capCfg.nmMax
            or math.min(capCfg.normalEvenMatch + higherSteps * capCfg.normalPerHigherLevel, capCfg.normalMax)
        if not isNM and result.chainActive then
            tnlShare = capCfg.normalMax
        end

        result.exp = math.max(1, math.floor(math.min(scaledExp, memberTNL * tnlShare)))
    end

    return result
end

xi.customBossServer.scaleCalculatedExp = scaleCalculatedExp

-- Apply immediately at module load and again on server start so tables stay active.
applyExperienceTableOverrides()

m:addOverride('xi.server.onServerStart', function()
    super()
    applyExperienceTableOverrides()
end)

m:addOverride('xi.experiencePoints.calculate', function(member, mob, data)
    local result = super(member, mob, data)
    return xi.customBossServer.scaleCalculatedExp(result, member, mob, data)
end)

m:addOverride('xi.mob.onMobSpawnEx', function(mob)
    super(mob)
    applyMobScaling(mob)
end)

-----------------------------------
-- Combat Level-Gap, Tank Armor-Piercing Floor, Block/Parry Caps & Breath Overrides
-----------------------------------
local function applyMobArmorPiercingPdifFloor(actor, target, rawPdif, isCritical)
    if not isWildMob(actor) or getPlayerSideLevel(target) == nil then
        return rawPdif
    end

    local tpCfg = xi.customBossServer.config.tankPressure
    if not tpCfg or rawPdif >= 1.0 then
        -- DPS, Supports, and Healers sit at rawPdif >= 1.0, so their incoming damage is untouched.
        return rawPdif
    end

    local isNM     = actor.isNM and actor:isNM() or false
    local minFloor = isNM and (tpCfg.nmPdifFloor or 0.75) or (tpCfg.normalMobPdifFloor or 0.65)
    if isCritical then
        minFloor = minFloor + (tpCfg.critPdifFloorBonus or 0.20)
    end

    -- Smoothly compress low-wRatio tank pDIF into [minFloor, 1.0] so DEF still matters
    -- without letting mobs drop to 0.25 pDIF scratch damage.
    local blended = minFloor + math.max(0, rawPdif - 0.25) * ((1.0 - minFloor) / 0.75)
    return math.max(minFloor, blended)
end

xi.customBossServer.applyMobArmorPiercingPdifFloor = applyMobArmorPiercingPdifFloor

m:addOverride('xi.combat.physical.calculateMeleeStatFactor', function(actor, target)
    local fstr = super(actor, target)
    if isWildMob(actor) and getPlayerSideLevel(target) ~= nil then
        local tpCfg   = xi.customBossServer.config.tankPressure
        local minFstr = (tpCfg and tpCfg.mobMinFstr) or -2
        if fstr < minFstr then
            return minFstr
        end
    end
    return fstr
end)

m:addOverride('xi.combat.physical.calculateRangedStatFactor', function(actor, target)
    local fstr = super(actor, target)
    if isWildMob(actor) and getPlayerSideLevel(target) ~= nil then
        local tpCfg   = xi.customBossServer.config.tankPressure
        local minFstr = ((tpCfg and tpCfg.mobMinFstr) or -2) * 2
        if fstr < minFstr then
            return minFstr
        end
    end
    return fstr
end)

m:addOverride('xi.combat.physical.calculateParryRate', function(defender, attacker)
    local rate = super(defender, attacker)
    if defender and defender.isPC and defender:isPC() then
        local tpCfg  = xi.customBossServer.config.tankPressure or {}
        local hasBurst = defender.hasStatusEffect and (
            (xi.effect.ISSEKIGAN and defender:hasStatusEffect(xi.effect.ISSEKIGAN)) or
            (xi.effect.BATTUTA and defender:hasStatusEffect(xi.effect.BATTUTA)) or
            defender:hasStatusEffect(825) -- EFFECT_RUNIC_CONVERGENCE
        )
        local cap = hasBurst and (tpCfg.parryBurstCap or 65) or (tpCfg.parryPassiveCap or 50)
        if rate > cap then
            rate = cap
        end
    end
    return rate
end)

m:addOverride('xi.combat.physical.calculateBlockRate', function(defender, attacker)
    local rate = super(defender, attacker)
    if defender and defender.isPC and defender:isPC() then
        local tpCfg  = xi.customBossServer.config.tankPressure or {}
        local hasBurst = defender.hasStatusEffect and (
            (xi.effect.PALISADE and defender:hasStatusEffect(xi.effect.PALISADE)) or
            (xi.effect.REPRISAL and defender:hasStatusEffect(xi.effect.REPRISAL)) or
            defender:hasStatusEffect(820) -- SPARTAN_WARD_EFFECT_ID (formerly GLADIATOR_WARD_EFFECT_ID)
        )
        local cap = hasBurst and (tpCfg.blockBurstCap or 75) or (tpCfg.blockPassiveCap or 60)
        if rate > cap then
            rate = cap
        end
    end
    return rate
end)

m:addOverride('xi.combat.physical.getDamageReductionForBlock', function(defender, attacker, damage)
    local reduction = super(defender, attacker, damage)
    local dmg       = tonumber(damage) or 0
    if dmg <= 0 then
        return 0
    end

    local tpCfg        = xi.customBossServer.config.tankPressure or {}
    local minBleedPct  = tpCfg.blockMinBleedthroughPct or 0.35
    local maxReduction = math.max(0, dmg - math.max(1, math.floor(dmg * minBleedPct)))
    return math.min(reduction, maxReduction)
end)

m:addOverride('xi.combat.physical.calculateMeleePDIF', function(actor, target, weaponType, wsAttackMod, isCritical, applyLevelCorrection, tpIgnoresDefense, tpFactor, isWeaponskill, weaponSlot, isCannonball)
    ensureCombatEntitiesScaled(actor, target)
    markInActualCombat(actor, target)
    local pdif = super(actor, target, weaponType, wsAttackMod, isCritical, applyLevelCorrection, tpIgnoresDefense, tpFactor, isWeaponskill, weaponSlot, isCannonball)
    pdif       = applyMobArmorPiercingPdifFloor(actor, target, pdif, isCritical)
    local mult = getLevelGapDamageMultiplier(actor, target)
    return pdif * mult
end)

m:addOverride('xi.combat.physical.calculateRangedPDIF', function(actor, target, weaponType, wsAttackMod, isCritical, applyLevelCorrection, tpIgnoresDefense, tpFactor, isWeaponskill, bonusRangedAttack)
    ensureCombatEntitiesScaled(actor, target)
    markInActualCombat(actor, target)
    local pdif = super(actor, target, weaponType, wsAttackMod, isCritical, applyLevelCorrection, tpIgnoresDefense, tpFactor, isWeaponskill, bonusRangedAttack)
    pdif       = applyMobArmorPiercingPdifFloor(actor, target, pdif, isCritical)
    local mult = getLevelGapDamageMultiplier(actor, target)
    return pdif * mult
end)

m:addOverride('xi.combat.physicalHitRate.getPhysicalHitRate', function(attacker, target, bonus, slot, isWeaponskill)
    local rate  = super(attacker, target, bonus, slot, isWeaponskill)
    local delta = getLevelGapHitRateDelta(attacker, target)
    if delta == 0 then
        return rate
    end

    local cap = xi.combat.physicalHitRate.getPhysicalHitRateCap(attacker, slot)
    return utils.clamp(rate + delta, 0.20, cap)
end)

m:addOverride('xi.combat.physicalHitRate.getRangedHitRate', function(attacker, target, bonus, isWeaponskill)
    local rate  = super(attacker, target, bonus, isWeaponskill)
    local delta = getLevelGapHitRateDelta(attacker, target)
    if delta == 0 then
        return rate
    end

    return utils.clamp(rate + delta, 0.20, 0.95)
end)

m:addOverride('xi.combat.magicHitRate.calculateResistRate', function(actor, target, fedData)
    local maccDelta = getLevelGapMagicAccDelta(actor, target)
    if maccDelta == 0 or type(fedData) ~= 'table' then
        return super(actor, target, fedData)
    end

    local copy = {}
    for k, v in pairs(fedData) do
        copy[k] = v
    end
    copy.bonusMacc = (copy.bonusMacc or 0) + maccDelta
    return super(actor, target, copy)
end)

m:addOverride('xi.spells.damage.calculateMagicBonusDiff', function(caster, target, spellId, skillType, spellElement, bonusMATT)
    markInActualCombat(caster, target)
    local diff = super(caster, target, spellId, skillType, spellElement, bonusMATT)
    local mult = getLevelGapDamageMultiplier(caster, target)
    return diff * mult
end)

m:addOverride('xi.weaponskills.takeWeaponskillDamage', function(defender, attacker, wsParams, primaryMsg, attack, wsResults, action)
    ensureCombatEntitiesScaled(attacker, defender)
    markInActualCombat(attacker, defender)
    if
        wsResults and
        type(wsResults.finalDmg) == 'number' and
        wsResults.finalDmg > 0 and
        attack and
        (attack.type == xi.attackType.MAGICAL or attack.type == xi.attackType.BREATH)
    then
        wsResults.finalDmg = xi.customBossServer.scaleDamageByLevelGap(attacker, defender, wsResults.finalDmg)
    end

    return super(defender, attacker, wsParams, primaryMsg, attack, wsResults, action)
end)

-- Normalize mob breath attacks so boosted boss HP never causes one-shots.
m:addOverride('xi.mobskills.mobBreathMove', function(mob, target, skill, action, skillParams)
    ensureCombatEntitiesScaled(mob, target)
    markInActualCombat(mob, target)

    local adjustedParams = skillParams
    local breathCfg      = xi.customBossServer.config.breath or {}
    local isWild         = isWildMob(mob)

    if isWild and type(skillParams) == 'table' then
        adjustedParams = {}
        for k, v in pairs(skillParams) do
            adjustedParams[k] = v
        end

        -- 1. Strip out our custom HPP modifier AND apply baseHpDamageMultiplier (0.55x)
        --    so inflated mob HP never inflates breath damage.
        local hppBonus  = mob:getLocalVar('[CustomBoss]HppBonus')
        if hppBonus <= 0 then
            hppBonus = math.max(0, mob:getMod(xi.mod.HPP))
        end
        local hppDivisor = 1 + (hppBonus / 100)
        local baseMult   = (breathCfg.baseHpDamageMultiplier or 0.55) / hppDivisor
        local rawPct     = adjustedParams.percentMultipier or 0.10
        adjustedParams.percentMultipier = rawPct * baseMult

        -- 2. Apply a level-scaled breath cap AND target Max HP anti-one-shot cap
        local mobLvl    = mob:getMainLvl()
        local isNM      = mob:isNM()
        local gapMult   = getLevelGapDamageMultiplier(mob, target)
        local perLvl    = isNM and (breathCfg.nmPerLevelCap or 6.0) or (breathCfg.normalPerLevelCap or 4.5)
        local flatCap   = isNM and (breathCfg.nmFlatCap or 25) or (breathCfg.normalFlatCap or 15)
        local levelCap  = math.max(20, math.floor((mobLvl * perLvl + flatCap) * gapMult))

        if adjustedParams.damageCap then
            levelCap = math.min(adjustedParams.damageCap, levelCap)
        end

        if target and target.getMaxHP then
            local targetMaxHp = math.max(1, target:getMaxHP())
            local baseShare   = isNM and (breathCfg.nmMaxTargetHpShare or 0.45) or (breathCfg.normalMaxTargetHpShare or 0.35)
            local hardShare   = breathCfg.hardMaxTargetHpShare or 0.75
            local effShare    = math.min(hardShare, baseShare * gapMult)
            local hpShareCap  = math.max(15, math.floor(targetMaxHp * effShare))
            levelCap          = math.min(levelCap, hpShareCap)
        end

        adjustedParams.damageCap = levelCap
    end

    return super(mob, target, skill, action, adjustedParams)
end)

-- Normalize HP-based suicide moves (Bomb Toss Suicide, Self-Destruct, Final Sting, Core Meltdown)
-- that pass skill:getMobHP() into mobMagicalMove so boosted mob HP doesn't one-shot players.
m:addOverride('xi.mobskills.mobMagicalMove', function(mob, target, skill, action, skillParams)
    ensureCombatEntitiesScaled(mob, target)
    markInActualCombat(mob, target)

    local adjustedParams = skillParams
    if isWildMob(mob) and type(skillParams) == 'table' and type(skillParams.baseDamage) == 'number' then
        local mobLvl = math.max(1, mob:getMainLvl())
        -- Normal magical mobskills use nil (lvl + 2) or small flat values; HP-based suicide moves
        -- pass skill:getMobHP() / N which exceeds lvl * 4.
        if skillParams.baseDamage > mobLvl * 4 then
            adjustedParams = {}
            for k, v in pairs(skillParams) do
                adjustedParams[k] = v
            end

            local hppBonus = mob:getLocalVar('[CustomBoss]HppBonus')
            if hppBonus <= 0 then
                hppBonus = math.max(0, mob:getMod(xi.mod.HPP))
            end
            local hppDivisor = 1 + (hppBonus / 100)
            local unboosted  = math.floor(skillParams.baseDamage / hppDivisor)
            local maxBase    = mobLvl * (mob:isNM() and 8 or 6) + 30
            adjustedParams.baseDamage = math.min(unboosted, maxBase)
        end
    end

    return super(mob, target, skill, action, adjustedParams)
end)

m:addOverride('xi.player.charCreate', function(player)
    super(player)
    applyQoLUnlocks(player)
    player:capAllSkills()
    player:setCharVar('[CustomBoss]SkillsCapped', 1)
    grantStarterKit(player, true)
    xi.customBossServer.applyPlayerCombatPace(player, true)
    attachPlayerCombatListeners(player)
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    applyQoLUnlocks(player)

    if player:getCharVar('[CustomBoss]StarterKit') == 0 then
        grantStarterKit(player, false)
    end

    if not zoning or player:getCharVar('[CustomBoss]SkillsCapped') == 0 then
        player:capAllSkills()
        player:setCharVar('[CustomBoss]SkillsCapped', 1)
    end

    xi.customBossServer.applyPlayerCombatPace(player, true)
    attachPlayerCombatListeners(player)

    if player:getCharVar('[CustomBoss]Stance') == 1 then
        xi.customBossServer.applyCustomPlayerBuffs(player, true)
    end

    if player.getZone then
        scanAndScaleZoneMobs(player:getZone())
    end
end)

m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    player:capAllSkills()
    xi.customBossServer.applyPlayerCombatPace(player, true)
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    player:capAllSkills()
    xi.customBossServer.applyPlayerCombatPace(player, true)
end)

local starterMoogleSpawns =
{
    { zoneName = 'Port_San_dOria',     x =   2.000, y =   0.000, z =  -2.000, rotation =  64 },
    { zoneName = 'Northern_San_dOria', x = 118.500, y =  -0.199, z =  -8.459, rotation = 160 },
    { zoneName = 'Bastok_Mines',       x =  83.500, y =   0.000, z = -64.102, rotation = 109 },
    { zoneName = 'Port_Windurst',      x = 185.200, y = -11.999, z = 217.730, rotation = 223 },
    { zoneName = 'RuLude_Gardens',     x =  -3.700, y =   8.999, z = -41.341, rotation = 125 },
}

for _, spawn in ipairs(starterMoogleSpawns) do
    m:addOverride(string.format('xi.zones.%s.Zone.onInitialize', spawn.zoneName), function(zone)
        super(zone)

        zone:insertDynamicEntity({
            objtype    = xi.objType.NPC,
            name       = 'Starter_Weapons',
            packetName = 'Starter Weapons',
            look       = 981,
            x          = spawn.x,
            y          = spawn.y,
            z          = spawn.z,
            rotation   = spawn.rotation,
            widescan   = 1,
            onTrigger  = function(player, npc)
                showStarterWeaponsMenu(player, 1)
            end,
        })
    end)
end

local bossStanceCmd = {}

bossStanceCmd.cmdprops =
{
    permission = 0,
    parameters = '',
}

bossStanceCmd.onTrigger = function(player)
    local nextState = player:getCharVar('[CustomBoss]Stance') == 1 and 0 or 1
    player:setCharVar('[CustomBoss]Stance', nextState)
    xi.customBossServer.applyCustomPlayerBuffs(player, nextState == 1)

    if nextState == 1 then
        player:printToPlayer('Hero\'s Stance ENABLED: +35% ATT/RATT, +30 MAB, +40 ACC, +25 Store TP, +15 Regain, +10% Crit.', xi.msg.channel.SYSTEM_3, '')
    else
        player:printToPlayer('Hero\'s Stance DISABLED.', xi.msg.channel.SYSTEM_3, '')
    end
end

xi.module.registerCommand('bossstance', bossStanceCmd)

local combatCmd = {}

combatCmd.cmdprops =
{
    permission = 0,
    parameters = 'ss',
}

combatCmd.onTrigger = function(player, arg1, arg2)
    local cfg    = xi.customBossServer.config
    local action = arg1 and string.lower(tostring(arg1)) or nil

    if action == 'hp' then
        local num = tonumber(arg2)
        if num == nil or num < 0 or num > 300 then
            player:printToPlayer('Usage: !combat hp <0-300> (sets Player baseline +Max HP%, default 100)', xi.msg.channel.SYSTEM_3, '')
            return
        end
        cfg.playerBaseHpp = math.floor(num + 0.5)
        xi.customBossServer.applyPlayerCombatPace(player, true)
        player:printToPlayer(string.format('Set Player baseline Max HP bonus to +%d%% (current Max HP: %d).', cfg.playerBaseHpp, player:getMaxHP()), xi.msg.channel.SYSTEM_3, '')
        return
    elseif action == 'mobdmg' then
        local num = tonumber(arg2)
        if num == nil or num < 0.5 or num > 5.0 then
            player:printToPlayer('Usage: !combat mobdmg <0.5-5.0> (sets Normal Mob outgoing damage multiplier, default 1.65)', xi.msg.channel.SYSTEM_3, '')
            return
        end
        cfg.levelGap.normalMobBaseDmgMult = math.floor(num * 100 + 0.5) / 100
        cfg.levelGap.nmBaseDmgMult        = math.floor((num + 0.20) * 100 + 0.5) / 100
        player:printToPlayer(string.format('Set Mob Outgoing Damage Multiplier to %.2fx (Normal) / %.2fx (NM).', cfg.levelGap.normalMobBaseDmgMult, cfg.levelGap.nmBaseDmgMult), xi.msg.channel.SYSTEM_3, '')
        return
    end

    local pLvl   = (player and player.getMainLvl and player:getMainLvl()) or 1
    local mLvl   = tonumber(arg1) or pLvl
    mLvl         = math.max(1, math.min(99, math.floor(mLvl)))
    local scale  = getMobLevelScale(mLvl)
    local norm   = cfg.normalMob
    local breath = cfg.breath
    local gapCfg = cfg.levelGap

    local hpp    = mLvl >= 2 and math.floor((norm.hpp or 45) * scale) or 0
    local attp   = math.floor((norm.attp or 45) * scale)
    local defp   = math.floor((norm.defp or 25) * scale)
    local acc    = math.floor((norm.acc or 24) * scale)
    local eva    = math.floor((norm.eva or 14) * scale)
    local mdef   = math.floor((norm.mdef or 18) * scale)
    local haste  = math.min(norm.maxHaste or 2500, math.floor((norm.haste or 1800) * scale))
    local bCap   = math.floor(mLvl * (breath.normalPerLevelCap or 9.5) + (breath.normalFlatCap or 35))
    local mBase  = gapCfg.normalMobBaseDmgMult or 1.65

    if player and player.getZone then
        scanAndScaleZoneMobs(player:getZone())
    end

    player:printToPlayer(
        string.format('Player Pace & Pool: +%d%% Max HP (+%d HP/lvl), +25%% Haste, +25 Store TP, +20 Combat-Only Regain, +15%% Fast Cast.',
            cfg.playerBaseHpp or 100, cfg.playerHpPerLevel or 6),
        xi.msg.channel.SYSTEM_3, '')
    player:printToPlayer(
        string.format('Lv.%d Normal Mob (%.2fx): +%d%% HP | +%d%% ATT (%.2fx OutDmg) | +%d%% DEF | +%d ACC/+%d EVA | +%d MDEF | +%.1f%% Haste | Breath Cap ~%d.',
            mLvl, scale, hpp, attp, mBase, defp, acc, eva, mdef, haste / 100, bCap),
        xi.msg.channel.SYSTEM_3, '')
    player:printToPlayer(
        'Usage: !combat [mobLvl] | !combat hp <0-300> | !combat mobdmg <0.5-5.0>',
        xi.msg.channel.SYSTEM_3, '')
end

xi.module.registerCommand('combat', combatCmd)

local function openWeaponsShopTrigger(player, page)
    openWeaponsShop(player, page)
end

local function makeWeaponsShopCommand()
    return {
        cmdprops =
        {
            permission = 0,
            parameters = 'i',
        },
        onTrigger = openWeaponsShopTrigger,
    }
end

xi.module.registerCommand('weapons', makeWeaponsShopCommand())
xi.module.registerCommand('startershop', makeWeaponsShopCommand())

local starterKitCmd = {}

starterKitCmd.cmdprops =
{
    permission = 0,
    parameters = '',
}

starterKitCmd.onTrigger = function(player)
    applyQoLUnlocks(player)
    player:capAllSkills()
    player:setCharVar('[CustomBoss]SkillsCapped', 1)

    local addedCount, skippedCount = grantStarterKit(player, false)

    if skippedCount > 0 then
        player:printToPlayer(string.format('Starter Kit partial: added %d item(s), skipped %d item(s) (inventory full). Free space and run !starterkit again.', addedCount, skippedCount), xi.msg.channel.SYSTEM_3, '')
    else
        player:printToPlayer(string.format('Starter Kit complete: added %d missing item(s), all 22 jobs unlocked, and all skills capped.', addedCount), xi.msg.channel.SYSTEM_3, '')
    end
end

xi.module.registerCommand('starterkit', starterKitCmd)

local expCmd = {}

expCmd.cmdprops =
{
    permission = 0,
    parameters = 'ss',
}

local function printExpSummary(player)
    local expCfg    = xi.customBossServer.config.exp
    local emPct     = math.floor(expCfg.evenMatchTnlShare * 100 + 0.5)
    local killsPer  = math.floor((1 / expCfg.evenMatchTnlShare) * 10 + 0.5) / 10
    local lesser    = expCfg.lesserLevelMultipliers

    player:printToPlayer(
        string.format('EXP Pacing: Even Match = %d%% TNL (~%.1f kills/lvl), Drop = %d%%/lvl below.',
            emPct, killsPer, expCfg.dropPerLevelPct or 20),
        xi.msg.channel.SYSTEM_3, '')
    player:printToPlayer(
        string.format('Lesser Mobs (%% of EM): -1=%d%% | -2=%d%% | -3=%d%% | -4=%d%% | -5=%d%%',
            math.floor((lesser[-1] or 0) * 100 + 0.5),
            math.floor((lesser[-2] or 0) * 100 + 0.5),
            math.floor((lesser[-3] or 0) * 100 + 0.5),
            math.floor((lesser[-4] or 0) * 100 + 0.5),
            math.floor((lesser[-5] or 0) * 100 + 0.5)),
        xi.msg.channel.SYSTEM_3, '')
    player:printToPlayer(
        'Usage: !exp | !exp kills <n> | !exp drop <pct> | !exp level <1-75> | !exp give <amount>',
        xi.msg.channel.SYSTEM_3, '')
end

expCmd.onTrigger = function(player, action, arg)
    local expCfg = xi.customBossServer.config.exp
    action = action and string.lower(action) or nil

    if action == nil or action == 'help' or action == 'status' then
        printExpSummary(player)
        return
    end

    local num = tonumber(arg)
    if action == 'kills' then
        if num == nil or num < 1 or num > 100 then
            player:printToPlayer('Usage: !exp kills <1-100> (Even Match kills per level)', xi.msg.channel.SYSTEM_3, '')
            return
        end

        local share = 1 / num
        expCfg.evenMatchTnlShare                = share
        expCfg.maxTnlShare.normalEvenMatch      = share
        expCfg.maxTnlShare.normalPerHigherLevel = share * expCfg.higherLevelBonusPerLevel
        player:printToPlayer(string.format('Set Even Match pace to %.1f kill(s)/level (%d%% TNL per EM kill).', num, math.floor(share * 100 + 0.5)), xi.msg.channel.SYSTEM_3, '')
        return
    end

    if action == 'drop' then
        if num == nil or num < 0 or num > 100 then
            player:printToPlayer('Usage: !exp drop <0-100> (EXP drop % per level below you)', xi.msg.channel.SYSTEM_3, '')
            return
        end

        expCfg.dropPerLevelPct = math.floor(num + 0.5)
        for d = 1, 5 do
            local raw = 1 - d * (num / 100)
            expCfg.lesserLevelMultipliers[-d] = math.max(0.02, math.floor(raw * 1000 + 0.5) / 1000)
        end

        printExpSummary(player)
        return
    end

    if action == 'level' then
        if num == nil or num < 1 or num > 75 then
            player:printToPlayer('Usage: !exp level <1-75>', xi.msg.channel.SYSTEM_3, '')
            return
        end

        local targetLevel = math.floor(num)
        player:setLevel(targetLevel)
        player:printToPlayer(string.format('Set %s\'s level to %d.', player:getName(), targetLevel), xi.msg.channel.SYSTEM_3, '')
        return
    end

    if action == 'give' then
        if num == nil or num < 1 or num > 1000000 then
            player:printToPlayer('Usage: !exp give <1-1000000>', xi.msg.channel.SYSTEM_3, '')
            return
        end

        local amount = math.floor(num)
        player:addExp(amount)
        player:printToPlayer(string.format('Gave %d EXP. Current level: %d.', amount, player:getMainLvl()), xi.msg.channel.SYSTEM_3, '')
        return
    end

    printExpSummary(player)
end

xi.module.registerCommand('exp', expCmd)

-- Support live FileWatcher hot-reload without restarting xi_map.
if xi.commands ~= nil and xi.commands.bossstance ~= nil then
    package.loaded['scripts/globals/experience_points'] = nil
    require('scripts/globals/experience_points')

    local origCalculate = xi.experiencePoints.calculate
    xi.experiencePoints.calculate = function(member, mob, data)
        local result = origCalculate(member, mob, data)
        return xi.customBossServer.scaleCalculatedExp(result, member, mob, data)
    end

    applyExperienceTableOverrides()
    xi.commands.exp    = expCmd
    xi.commands.combat = combatCmd
end
