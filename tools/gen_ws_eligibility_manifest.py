#!/usr/bin/env python3
"""Generate the authoritative 66-Soul Weapon Eligibility Manifest (JSON + Lua).

Single source of truth for:
  - modules/custom/data/ws_eligibility_manifest.json  (Python / Autoparser / Wiki / CI)
  - modules/custom/lua/soulspire_ws_eligibility.lua   (Lua runtime / UI / talent validation)

Eligibility is explicit per canonical Soul (never inferred from base-job
weapon proficiency tables). Only Primary and justified Secondary Signature
weapon families receive WS talent definitions.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "modules/custom/lua/soulspire_ws_catalog.lua"
JOB_SPECS_PATH = ROOT / "modules/custom/lua/soulspire_job_specs.lua"
MANIFEST_JSON_PATH = ROOT / "modules/custom/data/ws_eligibility_manifest.json"
MANIFEST_LUA_PATH = ROOT / "modules/custom/lua/soulspire_ws_eligibility.lua"

MANIFEST_SCHEMA_VERSION = "2.0.0"

SKILL_ID_BY_NAME: dict[str, int] = {
    "Hand-to-Hand": 1,
    "Dagger": 2,
    "Sword": 3,
    "Great Sword": 4,
    "Axe": 5,
    "Great Axe": 6,
    "Scythe": 7,
    "Polearm": 8,
    "Katana": 9,
    "Great Katana": 10,
    "Club": 11,
    "Staff": 12,
    "Archery": 25,
    "Marksmanship": 26,
    "Throwing": 27,
}

SKILL_CONST_BY_NAME: dict[str, str] = {
    "Hand-to-Hand": "HAND_TO_HAND",
    "Dagger": "DAGGER",
    "Sword": "SWORD",
    "Great Sword": "GREAT_SWORD",
    "Axe": "AXE",
    "Great Axe": "GREAT_AXE",
    "Scythe": "SCYTHE",
    "Polearm": "POLEARM",
    "Katana": "KATANA",
    "Great Katana": "GREAT_KATANA",
    "Club": "CLUB",
    "Staff": "STAFF",
    "Archery": "ARCHERY",
    "Marksmanship": "MARKSMANSHIP",
    "Throwing": "THROWING",
}

# Standard FFXI / SoulspireXI base-job theoretically equipable weapon skill families
# (used strictly to calculate the reduction achieved by Soul-level filtering).
BASE_JOB_THEORETICAL_SKILLS: dict[str, list[str]] = {
    "WAR": ["Hand-to-Hand", "Dagger", "Sword", "Great Sword", "Axe", "Great Axe", "Scythe", "Polearm", "Club", "Staff", "Archery", "Marksmanship", "Throwing"],
    "MNK": ["Hand-to-Hand", "Club", "Staff", "Throwing"],
    "WHM": ["Club", "Staff", "Polearm", "Throwing"],
    "BLM": ["Dagger", "Club", "Staff", "Scythe", "Throwing"],
    "RDM": ["Dagger", "Sword", "Club", "Staff", "Archery", "Throwing"],
    "THF": ["Hand-to-Hand", "Dagger", "Sword", "Katana", "Club", "Archery", "Marksmanship", "Throwing"],
    "PLD": ["Dagger", "Sword", "Great Sword", "Club", "Staff", "Polearm"],
    "DRK": ["Dagger", "Sword", "Great Sword", "Axe", "Great Axe", "Scythe", "Club", "Marksmanship"],
    "BST": ["Dagger", "Sword", "Axe", "Great Axe", "Scythe", "Club"],
    "BRD": ["Dagger", "Sword", "Club", "Staff", "Throwing"],
    "RNG": ["Dagger", "Sword", "Axe", "Club", "Archery", "Marksmanship", "Throwing"],
    "SAM": ["Dagger", "Sword", "Polearm", "Great Katana", "Club", "Archery", "Throwing"],
    "NIN": ["Hand-to-Hand", "Dagger", "Sword", "Katana", "Great Katana", "Club", "Archery", "Marksmanship", "Throwing"],
    "DRG": ["Dagger", "Sword", "Polearm", "Staff", "Club"],
    "SMN": ["Dagger", "Club", "Staff"],
    "BLU": ["Sword", "Club"],
    "COR": ["Dagger", "Sword", "Marksmanship", "Throwing"],
    "PUP": ["Hand-to-Hand", "Dagger", "Club", "Throwing"],
    "DNC": ["Hand-to-Hand", "Dagger", "Sword", "Throwing"],
    "SCH": ["Dagger", "Club", "Staff", "Throwing"],
    "GEO": ["Dagger", "Club", "Staff"],
    "RUN": ["Sword", "Great Sword", "Axe", "Great Axe", "Club"],
}

# Explicit, canonical per-Soul weapon eligibility rules across all 66 Souls.
# Each entry: (primary_weapons, secondary_signature_weapons, evidence, exclusion_note)
SOUL_ELIGIBILITY_SPEC: dict[str, dict[str, Any]] = {
    # WAR
    "berserker": {
        "primary": ["Great Axe"],
        "secondary": ["Axe"],
        "evidence": ["war_specs.lua", "docs/guides/berserker.md", "Bloodlust Surge physical burst loop"],
        "exclusion_note": "Incidental base WAR weapons (Sword, Dagger, H2H, GS, Scythe, Polearm, Club, Staff, Ranged) are outside Berserker's axe-cleaver burst identity.",
    },
    "commander": {
        "primary": ["Great Axe"],
        "secondary": ["Sword"],
        "evidence": ["war_specs.lua", "docs/guides/commander.md", "Tactical Breach / Warcry support loop"],
        "exclusion_note": "Incidental base WAR weapons outside Great Axe (primary) and Sword (1H tactical support) are excluded.",
    },
    "spartan": {
        "primary": ["Polearm"],
        "secondary": [],
        "evidence": ["war_specs.lua (xi.skill.POLEARM)", "soulspire_polearm_buckler.lua", "docs/guides/spartan.md"],
        "exclusion_note": "Spartan mechanics (Grit, Iron Resolve, Polearm+Buckler) strictly require Polearm.",
    },
    # MNK
    "blackbelt": {
        "primary": ["Hand-to-Hand"],
        "secondary": [],
        "evidence": ["mnk_specs.lua", "docs/guides/blackbelt.md", "Footwork/Impetus martial DPS loop"],
        "exclusion_note": "Staff/Club/Throwing are outside Black Belt's pure Hand-to-Hand martial identity.",
    },
    "chiweaver": {
        "primary": ["Hand-to-Hand"],
        "secondary": [],
        "evidence": ["mnk_specs.lua", "docs/guides/chiweaver.md", "0-MP Lotus/Harmony H2H healer"],
        "exclusion_note": "Chi Weaver healing/bolting loop is strictly Hand-to-Hand.",
    },
    "sensei": {
        "primary": ["Staff"],
        "secondary": [],
        "evidence": ["mnk_specs.lua (xi.skill.STAFF)", "docs/guides/sensei.md", "Dojo Staff counter tank"],
        "exclusion_note": "Sensei's signature defensive loop requires main-hand Staff; H2H/Club/Throwing excluded.",
    },
    # WHM
    "bishop": {
        "primary": ["Club"],
        "secondary": ["Staff"],
        "evidence": ["whm_specs.lua (CLUB/STAFF)", "docs/guides/bishop.md"],
        "exclusion_note": "Polearm and Throwing are outside Bishop's clerical healing identity.",
    },
    "zealot": {
        "primary": ["Staff"],
        "secondary": [],
        "evidence": ["whm_zealot_specs.lua (xi.skill.STAFF)", "docs/guides/zealot.md"],
        "exclusion_note": "Zealot's custom holy nuking mechanics require main-hand Staff.",
    },
    "valkyrie": {
        "primary": ["Polearm"],
        "secondary": [],
        "evidence": ["whm_valkyrie_specs.lua (xi.skill.POLEARM)", "docs/guides/valkyrie.md"],
        "exclusion_note": "Valkyrie's Wingmate/aerial support kit requires main-hand Polearm.",
    },
    # BLM
    "astromancer": {
        "primary": ["Staff"],
        "secondary": [],
        "evidence": ["blm_astromancer_specs.lua", "docs/guides/astromancer.md"],
        "exclusion_note": "Dagger, Club, Scythe, and Throwing are incidental to Astromancer's Staff casting identity.",
    },
    "channeler": {
        "primary": ["Staff"],
        "secondary": [],
        "evidence": ["blm_channeler_specs.lua", "docs/guides/channeler.md (Staff eligible family)"],
        "exclusion_note": "Channeler explicitly designates Staff as its sole WS family.",
    },
    "necromancer": {
        "primary": ["Scythe"],
        "secondary": [],
        "evidence": ["blm_specs.lua (xi.skill.SCYTHE)", "docs/guides/necromancer.md"],
        "exclusion_note": "Necromancer's Dark Pact recovery requires main-hand Scythe.",
    },
    # RDM
    "crimsonduelist": {
        "primary": ["Sword"],
        "secondary": [],
        "evidence": ["rdm_specs.lua (xi.skill.SWORD, empty offhand)", "docs/guides/crimsonduelist.md"],
        "exclusion_note": "Crimson Duelist mandates 1H Sword with empty offhand; Dagger/Club/Staff/Archery excluded.",
    },
    "royaltactician": {
        "primary": ["Sword"],
        "secondary": [],
        "evidence": ["rdm_royal_tactician_specs.lua", "docs/guides/royaltactician.md"],
        "exclusion_note": "Royal Tactician designates Sword as its eligible melee WS family.",
    },
    "scarletweaver": {
        "primary": ["Sword"],
        "secondary": [],
        "evidence": ["rdm_scarlet_weaver_specs.lua", "docs/guides/scarletweaver.md", "Yin/Yang Sword specialization"],
        "exclusion_note": "Scarlet Weaver's Yang/Yin weaving requires Sword (supporting physical & magical Sword WS).",
    },
    # THF
    "bandit": {
        "primary": ["Dagger"],
        "secondary": ["Sword"],
        "evidence": ["thf_bandit_specs.lua (DAGGER/SWORD)", "docs/guides/bandit.md"],
        "exclusion_note": "Find the Gap opening and TP refund require Dagger or Sword; all other base THF weapons excluded.",
    },
    "trickster": {
        "primary": ["Dagger"],
        "secondary": ["Sword"],
        "evidence": ["thf_trickster_specs.lua (DAGGER/SWORD)", "docs/guides/trickster.md"],
        "exclusion_note": "Pass the Blame threat-transfer requires Dagger or Sword; other base THF weapons excluded.",
    },
    "phantom": {
        "primary": ["Dagger"],
        "secondary": ["Katana"],
        "evidence": ["thf_phantom_specs.lua (DAGGER/KATANA)", "docs/guides/phantom.md"],
        "exclusion_note": "Phantom shadow-tank triggers require Dagger or Katana; other base THF weapons excluded.",
    },
    # PLD
    "defender": {
        "primary": ["Club"],
        "secondary": ["Sword"],
        "evidence": ["pld_specs.lua (CLUB + Shield Zeal/Holy Nova)", "docs/guides/aegistemplar.md", "Sword signature PLD secondary"],
        "exclusion_note": "Great Sword, Staff, Polearm, and Dagger are excluded; Club primary + Sword secondary (Sanguine sustain strictly gated).",
    },
    "templar": {
        "primary": ["Club"],
        "secondary": [],
        "evidence": ["pld_healer_specs.lua (xi.skill.CLUB)", "docs/guides/templar.md"],
        "exclusion_note": "Templar Beacon of Light / Perpetual Majesty loop centers on Club + Shield.",
    },
    "oathbreaker": {
        "primary": ["Great Sword"],
        "secondary": [],
        "evidence": ["pld_oathbreaker_specs.lua (xi.skill.GREAT_SWORD)", "docs/guides/oathbreaker.md"],
        "exclusion_note": "Oathbreaker Reckoning retaliation loop requires Great Sword.",
    },
    # DRK
    "reaper": {
        "primary": ["Scythe"],
        "secondary": [],
        "evidence": ["drk_reaper_specs.lua (xi.skill.SCYTHE)", "docs/guides/reaper.md"],
        "exclusion_note": "Reaper Finality execution requires Scythe; Great Sword/Sword/Axe/Great Axe excluded.",
    },
    "dreadnought": {
        "primary": ["Scythe"],
        "secondary": [],
        "evidence": ["drk_specs.lua (xi.skill.SCYTHE)", "docs/guides/dreadnought.md"],
        "exclusion_note": "Dreadnought Blood-Pool drain tank loop requires Scythe.",
    },
    "scourge": {
        "primary": ["Scythe"],
        "secondary": [],
        "evidence": ["drk_scourge_specs.lua", "docs/guides/scourge.md (Scythe eligible family)"],
        "exclusion_note": "Scourge explicitly designates Scythe as its sole eligible WS family.",
    },
    # BRD
    "adventurer": {
        "primary": ["Dagger"],
        "secondary": ["Sword"],
        "evidence": ["brd_specs.lua (weaponConfig dual_1h DAGGER/SWORD)", "docs/guides/adventurer.md"],
        "exclusion_note": "Adventurer Cadence loop and dual-wield config authorize Dagger and Sword only.",
    },
    "musician": {
        "primary": ["Dagger"],
        "secondary": ["Staff"],
        "evidence": ["brd_specs.lua", "docs/guides/musician.md"],
        "exclusion_note": "Musician is a pure instrument caster; Sword/Club/Throwing excluded.",
    },
    "minstrel": {
        "primary": ["Dagger"],
        "secondary": ["Sword"],
        "evidence": ["brd_specs.lua", "docs/guides/minstrel.md"],
        "exclusion_note": "Minstrel shield-tank uses 1H Dagger/Sword; Club/Staff/Throwing excluded.",
    },
    # RNG
    "sniper": {
        "primary": ["Marksmanship"],
        "secondary": [],
        "evidence": ["rng_sniper_specs.lua", "docs/guides/sniper.md (Gun/Crossbow)"],
        "exclusion_note": "Sniper Sightline Shot requires Marksmanship (Gun/Crossbow); melee and Archery excluded.",
    },
    "huntsman": {
        "primary": ["Archery"],
        "secondary": ["Marksmanship"],
        "evidence": ["rng_specs.lua (ARCHERY/MARKSMANSHIP)", "docs/guides/huntsman.md"],
        "exclusion_note": "Huntsman Warden's Ration triggers on Archery or Marksmanship WS; melee weapons excluded.",
    },
    "arcanearcher": {
        "primary": ["Archery"],
        "secondary": [],
        "evidence": ["rng_arcane_archer_specs.lua", "docs/guides/arcanearcher.md (Bow/Archery only)"],
        "exclusion_note": "Arcane Archer Attunement Arrow strictly uses Archery.",
    },
    # SAM
    "ronin": {
        "primary": ["Great Katana"],
        "secondary": [],
        "evidence": ["sam_specs.lua (GREAT_KATANA)", "docs/guides/ronin.md"],
        "exclusion_note": "Ronin Seigan/Stagger loop requires Great Katana; incidental SAM weapons excluded.",
    },
    "warlord": {
        "primary": ["Great Katana"],
        "secondary": [],
        "evidence": ["sam_specs.lua (GREAT_KATANA)", "docs/guides/warlord.md"],
        "exclusion_note": "Warlord Noto/Ashura loop requires Great Katana.",
    },
    "imperialarcher": {
        "primary": ["Great Katana"],
        "secondary": ["Archery"],
        "evidence": ["sam_specs.lua (GREAT_KATANA + ARCHERY)", "docs/guides/imperialarcher.md"],
        "exclusion_note": "Imperial Archer Drawn Oisoya alternates Great Katana and Archery; other SAM weapons excluded.",
    },
    # NIN
    "kurogane": {
        "primary": ["Katana"],
        "secondary": [],
        "evidence": ["nin_specs.lua (KATANA)", "kurogane_clones.lua", "docs/guides/shinobi.md"],
        "exclusion_note": "Shinobi/Kurogane clone assault loop centers on Katana; incidental NIN weapons excluded.",
    },
    "kagemusha": {
        "primary": ["Katana"],
        "secondary": [],
        "evidence": ["nin_specs.lua (KATANA)", "docs/guides/kagemusha.md"],
        "exclusion_note": "Kagemusha Yonin/Shadow rebuild loop requires Katana.",
    },
    "nightblade": {
        "primary": ["Katana"],
        "secondary": [],
        "evidence": ["nin_nightblade_specs.lua", "docs/guides/nightblade.md (Katana eligible family)"],
        "exclusion_note": "Nightblade explicitly designates Katana as its sole eligible WS family.",
    },
    # DRG
    "lancer": {
        "primary": ["Polearm"],
        "secondary": [],
        "evidence": ["drg_lancer_specs.lua (POLEARM)", "docs/guides/lancer.md"],
        "exclusion_note": "Lancer Vault follow-up requires Polearm; Sword/Dagger/Staff/Club excluded.",
    },
    "skyborn": {
        "primary": ["Polearm"],
        "secondary": [],
        "evidence": ["drg_skyborn_specs.lua (POLEARM)", "docs/guides/skyborn.md"],
        "exclusion_note": "Skyborn Grounding Cry / Skyward Guard requires Polearm.",
    },
    "wyvernheart": {
        "primary": ["Polearm"],
        "secondary": [],
        "evidence": ["drg_specs.lua (POLEARM)", "docs/guides/wyvernheart.md"],
        "exclusion_note": "Wyvernheart Wyrmscale loop requires Polearm.",
    },
    # BLU
    "warmage": {
        "primary": ["Sword"],
        "secondary": ["Club"],
        "evidence": ["blu_warmage_specs.lua", "docs/guides/warmage.md (Sword and Club)"],
        "exclusion_note": "All non-Sword/Club weapon families are unsupported on BLU Warmage.",
    },
    "magus": {
        "primary": ["Sword"],
        "secondary": ["Club"],
        "evidence": ["blu_healer_specs.lua (SWORD/CLUB)", "docs/guides/magus.md"],
        "exclusion_note": "All non-Sword/Club weapon families are unsupported on BLU Magus.",
    },
    "azurebastion": {
        "primary": ["Sword"],
        "secondary": ["Club"],
        "evidence": ["blu_specs.lua (SWORD/CLUB)", "docs/guides/azurebastion.md"],
        "exclusion_note": "Azure Surge triggers on Sword or Club WS only.",
    },
    # COR
    "flintlock": {
        "primary": ["Marksmanship"],
        "secondary": [],
        "evidence": ["cor_specs.lua (MARKSMANSHIP)", "docs/guides/flintlock.md (Gun Deadeye Chamber)"],
        "exclusion_note": "Flintlock Deadeye Chamber detonation requires Marksmanship (Gun); Dagger/Sword excluded.",
    },
    "gambler": {
        "primary": ["Marksmanship"],
        "secondary": ["Dagger"],
        "evidence": ["cor_specs.lua", "docs/guides/gambler.md", "P.ALLOWED_SKILLS_BY_SPEC"],
        "exclusion_note": "Gambler uses Marksmanship + Dagger; Sword/Throwing excluded.",
    },
    "buccaneer": {
        "primary": ["Sword"],
        "secondary": [],
        "evidence": ["cor_specs.lua (xi.skill.SWORD Point-Blank Pistol)", "docs/guides/buccaneer.md"],
        "exclusion_note": "Buccaneer Point-Blank Pistol Grapeshot builder triggers specifically on 1H Sword WS.",
    },
    # DNC
    "bladewheel": {
        "primary": ["Throwing"],
        "secondary": ["Dagger"],
        "evidence": ["dnc_specs.lua (THROWING/DAGGER)", "soulspire_throwing_ws.lua", "docs/guides/bladewheel.md"],
        "exclusion_note": "Bladewheel centers on custom Chakram Throwing WS with Dagger melee backup; Sword/H2H excluded.",
    },
    "vampire": {
        "primary": ["Dagger"],
        "secondary": ["Throwing"],
        "evidence": ["dnc_healer_specs.lua (DAGGER/THROWING)", "docs/guides/vampire.md"],
        "exclusion_note": "Vampire Finishing Move healing triggers on Dagger or Throwing WS; Sword/H2H excluded.",
    },
    "miragesentinel": {
        "primary": ["Dagger"],
        "secondary": [],
        "evidence": ["dnc_specs.lua (dual DAGGER mandatory)", "docs/guides/miragesentinel.md"],
        "exclusion_note": "Mirage Sentinel Fan Dance refresh strictly mandates Dagger in Main and Sub.",
    },
    # SCH
    "medic": {
        "primary": ["Club"],
        "secondary": ["Staff"],
        "evidence": ["sch_specs.lua", "docs/guides/medic.md (Staff or Club)"],
        "exclusion_note": "Dagger and Throwing are incidental to Medic's Eos healer identity.",
    },
    "sage": {
        "primary": ["Staff"],
        "secondary": ["Club"],
        "evidence": ["sch_specs.lua", "docs/guides/sage.md (Staff or Club)"],
        "exclusion_note": "Dagger, Sword, and Throwing are outside Sage's elemental scholar identity.",
    },
    "archivist": {
        "primary": ["Staff"],
        "secondary": ["Club"],
        "evidence": ["sch_archivist_specs.lua", "docs/guides/archivist.md (Staff and Club)"],
        "exclusion_note": "Archivist explicitly designates Staff and Club as its eligible WS families.",
    },
    # BST
    "untamed": {
        "primary": ["Great Axe"],
        "secondary": ["Axe"],
        "evidence": ["bst_untamed_specs.lua (AXE/GREAT_AXE)", "docs/guides/untamed.md"],
        "exclusion_note": "Untamed feral pack-DPS authorizes Great Axe and Axe; Dagger/Sword/Scythe/Club excluded.",
    },
    "alphawarden": {
        "primary": ["Axe"],
        "secondary": [],
        "evidence": ["bst_specs.lua (xi.skill.AXE)", "docs/guides/alphawarden.md"],
        "exclusion_note": "Alpha Warden pack-tank loop centers on Axe.",
    },
    "beastspeaker": {
        "primary": ["Axe"],
        "secondary": [],
        "evidence": ["bst_beastspeaker_specs.lua", "docs/guides/beastspeaker.md (Axe eligible family)"],
        "exclusion_note": "Beastspeaker explicitly designates Axe as its sole eligible WS family.",
    },
    # SMN
    "primalist": {
        "primary": ["Staff"],
        "secondary": ["Club"],
        "evidence": ["smn_primalist_specs.lua", "docs/guides/primalist.md (Staff and Club)"],
        "exclusion_note": "Dagger is incidental to Primalist's avatar-burst caster identity.",
    },
    "celestial": {
        "primary": ["Staff"],
        "secondary": ["Club"],
        "evidence": ["smn_specs.lua (STAFF/CLUB)", "docs/guides/celestial.md"],
        "exclusion_note": "Dagger is incidental to Celestial's Starlight Mend healer identity.",
    },
    "herald": {
        "primary": ["Staff"],
        "secondary": ["Club"],
        "evidence": ["smn_herald_specs.lua", "docs/guides/herald.md (Staff and Club)"],
        "exclusion_note": "Dagger is incidental to Herald's avatar-support identity.",
    },
    # PUP
    "pugilist": {
        "primary": ["Hand-to-Hand"],
        "secondary": [],
        "evidence": ["pup_specs.lua (HAND_TO_HAND)", "docs/guides/pugilist.md"],
        "exclusion_note": "Pugilist tandem automaton DPS uses Hand-to-Hand; Dagger/Club/Throwing excluded.",
    },
    "vanguard": {
        "primary": ["Hand-to-Hand"],
        "secondary": [],
        "evidence": ["pup_specs.lua (HAND_TO_HAND)", "docs/guides/vanguard.md"],
        "exclusion_note": "Vanguard Clockwork Bulwark tank uses Hand-to-Hand; Dagger/Club/Throwing excluded.",
    },
    "animist": {
        "primary": ["Hand-to-Hand"],
        "secondary": [],
        "evidence": ["pup_healer_specs.lua (HAND_TO_HAND)", "docs/guides/animist.md"],
        "exclusion_note": "Animist Aether Cells combat healer uses Hand-to-Hand; Dagger/Club/Throwing excluded.",
    },
    # RUN
    "spellblade": {
        "primary": ["Great Sword"],
        "secondary": [],
        "evidence": ["run_specs.lua (GREAT_SWORD)", "docs/guides/spellblade.md"],
        "exclusion_note": "Spellblade Edgeflare strictly requires Great Sword.",
    },
    "lifebinder": {
        "primary": ["Great Sword"],
        "secondary": [],
        "evidence": ["run_specs.lua", "docs/guides/lifebinder.md (Great Sword Runic Lifetap)"],
        "exclusion_note": "Incidental base RUN weapons (Sword, Axe, Great Axe, Club) excluded from Lifebinder.",
    },
    "inquisitor": {
        "primary": ["Great Sword"],
        "secondary": [],
        "evidence": ["run_specs.lua (GREAT_SWORD parry bonus)", "docs/guides/inquisitor.md"],
        "exclusion_note": "Incidental base RUN weapons (Sword, Axe, Great Axe, Club) excluded from Inquisitor.",
    },
    # GEO
    "terramancer": {
        "primary": ["Club"],
        "secondary": ["Staff"],
        "evidence": ["geo_terramancer_specs.lua", "docs/guides/terramancer.md (Club and Staff)"],
        "exclusion_note": "Dagger is incidental to Terramancer's geomantic caster identity.",
    },
    "verdant": {
        "primary": ["Club"],
        "secondary": ["Staff"],
        "evidence": ["geo_specs.lua (CLUB/STAFF)", "docs/guides/verdant.md"],
        "exclusion_note": "Dagger is incidental to Verdant's Nature's Surge healer identity.",
    },
    "diviner": {
        "primary": ["Club"],
        "secondary": ["Staff"],
        "evidence": ["geo_diviner_specs.lua", "docs/guides/diviner.md (Club and Staff)"],
        "exclusion_note": "Dagger is incidental to Diviner's luopan support identity.",
    },
}


def load_ws_catalog() -> dict[str, list[dict[str, Any]]]:
    txt = CATALOG_PATH.read_text(encoding="utf-8")
    matches = list(re.finditer(r"^\s*\[(\d+)\]\s*=\s*\n\s*\{", txt, re.M))
    by_skill: dict[str, list[dict[str, Any]]] = {k: [] for k in SKILL_ID_BY_NAME}
    for i, m in enumerate(matches):
        ws_id = int(m.group(1))
        block = txt[m.start(): matches[i + 1].start() if i + 1 < len(matches) else len(txt)]
        key_m = re.search(r"key\s*=\s*'([^']+)'", block)
        name_m = re.search(r"name\s*=\s*'([^']+)'", block)
        skill_m = re.search(r"skillName\s*=\s*'([^']+)'", block)
        type_m = re.search(r"wsType\s*=\s*'([^']+)'", block)
        if not (key_m and name_m and skill_m and type_m):
            continue
        by_skill[skill_m.group(1)].append({
            "id": ws_id,
            "key": key_m.group(1),
            "name": name_m.group(1),
            "skill_name": skill_m.group(1),
            "skill_id": SKILL_ID_BY_NAME[skill_m.group(1)],
            "ws_type": type_m.group(1),
        })
    for k in by_skill:
        by_skill[k].sort(key=lambda x: x["id"])
    return by_skill


def load_canonical_souls() -> list[dict[str, Any]]:
    src = JOB_SPECS_PATH.read_text(encoding="utf-8")
    m = re.search(r"spec\.JOB_SPECS\s*=\s*\{(.*?)\n\}", src, re.S)
    assert m, "spec.JOB_SPECS not found"
    tm = re.search(r"spec\.SPEC_KEY_TIERS\s*=\s*\{(.*?)\n\}", src, re.S)
    tiers = dict(re.findall(r"(\w+)\s*=\s*'([^']+)'", tm.group(1))) if tm else {}

    souls: list[dict[str, Any]] = []
    cur_job = None
    for line in m.group(1).splitlines():
        jm = re.match(r"\s*([A-Z]{3})\s*=", line)
        if jm:
            cur_job = jm.group(1)
        sm = re.search(
            r"id\s*=\s*'([^']+)'\s*,\s*name\s*=\s*'([^']+)'\s*,\s*abr\s*=\s*'([^']+)'\s*,\s*role\s*=\s*'([^']+)'",
            line,
        )
        if sm and cur_job:
            skey, sname, abr, role = sm.groups()
            if (cur_job, skey) == ("DNC", "freelancer"):
                continue
            tier = tiers.get(skey, role)
            if skey == "defender" and "aegistemplar" in tiers:
                tier = tiers["aegistemplar"]
            souls.append({
                "soul_key": skey,
                "soul_name": sname,
                "abbr": abr,
                "job": cur_job,
                "role": role,
                "tier": tier,
            })
    return souls


def build_manifest() -> dict[str, Any]:
    ws_by_skill = load_ws_catalog()
    souls = load_canonical_souls()
    assert len(souls) == 66, f"Expected 66 canonical souls, got {len(souls)}"

    all_skills = list(SKILL_ID_BY_NAME.keys())
    soul_entries: dict[str, Any] = {}

    total_theoretical_combos = 0
    total_approved_combos = 0
    total_excluded_theoretical_combos = 0
    total_all_catalog_combos = len(souls) * sum(len(v) for v in ws_by_skill.values())

    for s in souls:
        skey = s["soul_key"]
        assert skey in SOUL_ELIGIBILITY_SPEC, f"Missing eligibility spec for {skey}"
        spec = SOUL_ELIGIBILITY_SPEC[skey]
        primary = list(spec["primary"])
        secondary = list(spec["secondary"])
        approved_skills = primary + [w for w in secondary if w not in primary]
        approved_set = set(approved_skills)

        job_theoretical = BASE_JOB_THEORETICAL_SKILLS[s["job"]]
        theoretical_set = set(job_theoretical) | approved_set
        excluded_from_job = [w for w in job_theoretical if w not in approved_set]
        unsupported = [w for w in all_skills if w not in theoretical_set]

        eligible_ws = []
        for sk in approved_skills:
            eligible_ws.extend(ws_by_skill[sk])
        eligible_ws.sort(key=lambda x: x["id"])

        theoretical_ws_count = sum(len(ws_by_skill[sk]) for sk in theoretical_set)
        approved_ws_count = len(eligible_ws)
        excluded_ws_count = theoretical_ws_count - approved_ws_count

        total_theoretical_combos += theoretical_ws_count
        total_approved_combos += approved_ws_count
        total_excluded_theoretical_combos += excluded_ws_count

        soul_entries[skey] = {
            "soul_key": skey,
            "soul_name": s["soul_name"],
            "job": s["job"],
            "role": s["role"],
            "tier": s["tier"],
            "primary_weapons": primary,
            "secondary_signature_weapons": secondary,
            "approved_weapon_families": approved_skills,
            "approved_skill_ids": [SKILL_ID_BY_NAME[w] for w in approved_skills],
            "eligible_ws_ids": [w["id"] for w in eligible_ws],
            "eligible_ws_keys": [w["key"] for w in eligible_ws],
            "eligible_ws_count": approved_ws_count,
            "theoretical_job_ws_count": theoretical_ws_count,
            "excluded_job_ws_count": excluded_ws_count,
            "excluded_weapon_families": excluded_from_job,
            "unsupported_weapon_families": unsupported,
            "exclusion_reason": spec["exclusion_note"],
            "evidence": list(spec["evidence"]),
        }

    # 12 non-SC talent nodes per (Soul, WS)
    nodes_per_ws = 12
    reduction_vs_job_pct = round(
        (total_excluded_theoretical_combos / total_theoretical_combos) * 100.0, 2
    ) if total_theoretical_combos else 0.0
    reduction_vs_all_pct = round(
        ((total_all_catalog_combos - total_approved_combos) / total_all_catalog_combos) * 100.0, 2
    ) if total_all_catalog_combos else 0.0

    return {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "canonical_soul_count": len(souls),
        "total_catalog_ws": sum(len(v) for v in ws_by_skill.values()),
        "summary": {
            "total_all_catalog_soul_ws_combinations": total_all_catalog_combos,
            "total_theoretical_equipable_soul_ws_combinations": total_theoretical_combos,
            "total_approved_soul_ws_combinations": total_approved_combos,
            "total_excluded_equipable_soul_ws_combinations": total_excluded_theoretical_combos,
            "reduction_vs_equipable_pct": reduction_vs_job_pct,
            "reduction_vs_full_catalog_pct": reduction_vs_all_pct,
            "estimated_talent_defs_without_filtering": total_theoretical_combos * nodes_per_ws,
            "estimated_talent_defs_with_filtering": total_approved_combos * nodes_per_ws,
            "estimated_talent_defs_avoided": total_excluded_theoretical_combos * nodes_per_ws,
        },
        "skill_id_map": SKILL_ID_BY_NAME,
        "souls": soul_entries,
    }


def render_lua(manifest: dict[str, Any]) -> str:
    lines: list[str] = [
        "-----------------------------------",
        "-- SoulspireXI — Authoritative 66-Soul Weapon Eligibility Manifest",
        "-- AUTO-GENERATED by tools/gen_ws_eligibility_manifest.py",
        "-- Source of truth: modules/custom/data/ws_eligibility_manifest.json",
        "--",
        "-- Do not infer eligibility from base-job weapon proficiency tables.",
        "-- Excluded weapon families generate ZERO talent definitions.",
        "-----------------------------------",
        "xi = xi or {}",
        "xi.soulspire = xi.soulspire or {}",
        "xi.soulspire.wsEligibility = xi.soulspire.wsEligibility or {}",
        "",
        "local E = xi.soulspire.wsEligibility",
        f"E.SCHEMA_VERSION = '{manifest['schema_version']}'",
        "",
        "local S = xi.skill or {}",
        "",
        "E.ALIASES =",
        "{",
        "    aegistemplar = 'defender',",
        "    shinobi      = 'kurogane',",
        "    gladiator    = 'spartan',",
        "    soulbeast    = 'alphawarden',",
        "    marionettist = 'vanguard',",
        "    caller       = 'celestial',",
        "}",
        "",
        "E.CANONICAL_SOULS =",
        "{",
    ]
    for skey in manifest["souls"]:
        lines.append(f"    '{skey}',")
    lines.append("}")
    lines.append("")
    lines.append("E.SOULS =")
    lines.append("{")
    for skey, entry in manifest["souls"].items():
        skill_pairs = ", ".join(
            f"[S.{SKILL_CONST_BY_NAME[w]} or {SKILL_ID_BY_NAME[w]}] = true"
            for w in entry["approved_weapon_families"]
        )
        prim = ", ".join(f"'{w}'" for w in entry["primary_weapons"])
        sec = ", ".join(f"'{w}'" for w in entry["secondary_signature_weapons"])
        lines.append(f"    {skey} =")
        lines.append("    {")
        lines.append(f"        soulKey = '{skey}',")
        lines.append(f"        job = '{entry['job']}',")
        lines.append(f"        role = '{entry['role']}',")
        lines.append(f"        tier = '{entry['tier']}',")
        lines.append(f"        primary = {{ {prim} }},")
        lines.append(f"        secondary = {{ {sec} }},")
        lines.append(f"        skills = {{ {skill_pairs} }},")
        lines.append("    },")
    lines.append("}")
    lines.append("")
    lines.extend([
        "function E.normalizeSoulKey(soulKey)",
        "    if soulKey == nil or soulKey == '' then",
        "        return nil",
        "    end",
        "    local k = string.lower(tostring(soulKey))",
        "    return E.ALIASES[k] or k",
        "end",
        "",
        "function E.getEntry(soulKey)",
        "    local k = E.normalizeSoulKey(soulKey)",
        "    if k == nil then",
        "        return nil",
        "    end",
        "    return E.SOULS[k]",
        "end",
        "",
        "function E.isSkillEligible(soulKey, skillId)",
        "    if soulKey == 'generic' or soulKey == 'base' or soulKey == nil or soulKey == '' then",
        "        return true",
        "    end",
        "    local entry = E.getEntry(soulKey)",
        "    if entry == nil then",
        "        return false",
        "    end",
        "    return entry.skills[skillId] == true",
        "end",
        "",
        "function E.getAllowedSkillsMap(soulKey)",
        "    local entry = E.getEntry(soulKey)",
        "    return entry and entry.skills or nil",
        "end",
        "",
        "function E.getAllowedSoulsForSkill(skillId)",
        "    local out = {}",
        "    for _, skey in ipairs(E.CANONICAL_SOULS) do",
        "        local entry = E.SOULS[skey]",
        "        if entry ~= nil and entry.skills[skillId] == true then",
        "            table.insert(out, skey)",
        "        end",
        "    end",
        "    return out",
        "end",
        "",
        "function E.isWsEligible(soulKey, wsId)",
        "    local catalog = xi.soulspire and xi.soulspire.wsCatalog",
        "    local ws = catalog and catalog.byId and catalog.byId[wsId]",
        "    if ws == nil then",
        "        return false",
        "    end",
        "    return E.isSkillEligible(soulKey, ws.skill)",
        "end",
        "",
        "function E.getEligibleWsIds(soulKey)",
        "    local catalog = xi.soulspire and xi.soulspire.wsCatalog",
        "    local out = {}",
        "    if catalog == nil or catalog.orderedIds == nil then",
        "        return out",
        "    end",
        "    for _, wsId in ipairs(catalog.orderedIds) do",
        "        local ws = catalog.byId[wsId]",
        "        if ws ~= nil and E.isSkillEligible(soulKey, ws.skill) then",
        "            table.insert(out, wsId)",
        "        end",
        "    end",
        "    return out",
        "end",
        "",
        "return E",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    manifest = build_manifest()
    MANIFEST_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_JSON_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    MANIFEST_LUA_PATH.write_text(render_lua(manifest), encoding="utf-8")
    s = manifest["summary"]
    print(f"Wrote {MANIFEST_JSON_PATH.relative_to(ROOT)} and {MANIFEST_LUA_PATH.relative_to(ROOT)}")
    print(f"  Canonical Souls: {manifest['canonical_soul_count']}")
    print(f"  Theoretical equipable Soul x WS: {s['total_theoretical_equipable_soul_ws_combinations']}")
    print(f"  Approved Soul x WS:              {s['total_approved_soul_ws_combinations']}")
    print(f"  Excluded equipable Soul x WS:    {s['total_excluded_equipable_soul_ws_combinations']} ({s['reduction_vs_equipable_pct']}% reduction)")
    print(f"  Talent defs avoided (12/WS):     {s['estimated_talent_defs_avoided']} ({s['estimated_talent_defs_without_filtering']} -> {s['estimated_talent_defs_with_filtering']})")


if __name__ == "__main__":
    main()
