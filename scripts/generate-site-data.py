#!/usr/bin/env python3
"""
OverlordsXI Wiki & Database Generator
-------------------------------------
Parses all custom OverlordsXI Lua modules, Weaponskill Catalog & 5-Spec Talent Trees,
Job Crystal Specs, Custom Job Abilities & Traits, Companions & Summons,
Combat/QoL Rules, Player Commands, Engine Patches, and Git Commit History
directly from the repository and emits:
  - site/data.json
  - site/data.js (window.OVERLORDS_DATA = ...)

Runs automatically via GitHub Actions on every push (or locally via `python scripts/generate-site-data.py`).
"""

import copy
import datetime
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
LUA_DIR = ROOT_DIR / "modules" / "custom" / "lua"
CMD_DIR = ROOT_DIR / "modules" / "custom" / "commands"
SQL_DIR = ROOT_DIR / "modules" / "custom" / "sql"
PATCH_DIR = ROOT_DIR / "patches"
GUIDES_DIR = ROOT_DIR / "docs" / "guides"
SITE_DIR = ROOT_DIR / "site"


def run_git(args):
    try:
        res = subprocess.run(
            ["git"] + args,
            cwd=str(ROOT_DIR),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
        )
        if res.returncode == 0:
            return res.stdout.strip()
    except Exception:
        pass
    return ""


def strip_lua_comments(src: str) -> str:
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.DOTALL)
    out_lines = []
    for line in src.splitlines():
        in_str = None
        escaped = False
        cut_idx = None
        i = 0
        while i < len(line):
            ch = line[i]
            if escaped:
                escaped = False
                i += 1
                continue
            if ch == "\\":
                escaped = True
                i += 1
                continue
            if in_str:
                if ch == in_str:
                    in_str = None
            else:
                if ch in ("'", '"'):
                    in_str = ch
                elif ch == "-" and i + 1 < len(line) and line[i + 1] == "-":
                    cut_idx = i
                    break
            i += 1
        out_lines.append(line[:cut_idx] if cut_idx is not None else line)
    return "\n".join(out_lines)


def find_balanced(text: str, start_idx: int, open_ch: str = "{", close_ch: str = "}") -> int:
    depth = 0
    in_str = None
    escaped = False
    for i in range(start_idx, len(text)):
        ch = text[i]
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if in_str:
            if ch == in_str:
                in_str = None
            continue
        if ch in ("'", '"'):
            in_str = ch
            continue
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return -1


def split_top_level_args(text: str) -> list[str]:
    parts = []
    cur = []
    depth_brace = 0
    depth_paren = 0
    depth_bracket = 0
    in_str = None
    escaped = False

    for ch in text:
        if escaped:
            cur.append(ch)
            escaped = False
            continue
        if ch == "\\":
            cur.append(ch)
            escaped = True
            continue
        if in_str:
            cur.append(ch)
            if ch == in_str:
                in_str = None
            continue
        if ch in ("'", '"'):
            in_str = ch
            cur.append(ch)
            continue
        if ch == "{":
            depth_brace += 1
        elif ch == "}":
            depth_brace -= 1
        elif ch == "(":
            depth_paren += 1
        elif ch == ")":
            depth_paren -= 1
        elif ch == "[":
            depth_bracket += 1
        elif ch == "]":
            depth_bracket -= 1
        elif ch == "," and depth_brace == 0 and depth_paren == 0 and depth_bracket == 0:
            parts.append("".join(cur).strip())
            cur = []
            continue
        cur.append(ch)

    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def unquote_lua_str(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and ((s[0] == "'" and s[-1] == "'") or (s[0] == '"' and s[-1] == '"')):
        inner = s[1:-1]
        inner = inner.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n")
        return inner
    return s


def parse_number_list(brace_expr: str) -> list[float]:
    m = re.search(r"\{([^}]*)\}", brace_expr)
    if not m:
        return []
    vals = []
    for tok in m.group(1).split(","):
        tok = tok.strip()
        if not tok:
            continue
        try:
            if tok.startswith("."):
                tok = "0" + tok
            vals.append(float(tok))
        except ValueError:
            pass
    return vals


# Human-readable labels and formatting for xi.mod.* constants
MOD_LABELS = {
    "HP": ("Max HP", "", 1),
    "HPP": ("Max HP", "%", 1),
    "MPP": ("Max MP", "%", 1),
    "ATT": ("Attack", "", 1),
    "ATTP": ("Attack", "%", 1),
    "RATT": ("Ranged Attack", "", 1),
    "RATTP": ("Ranged Attack", "%", 1),
    "ACC": ("Accuracy", "", 1),
    "RACC": ("Ranged Accuracy", "", 1),
    "DEF": ("Defense", "", 1),
    "DEFP": ("Defense", "%", 1),
    "MATT": ("Magic Atk. Bonus", "", 1),
    "MACC": ("Magic Accuracy", "", 1),
    "MDEF": ("Magic Defense", "", 1),
    "MEVA": ("Magic Evasion", "", 1),
    "MAGIC_DAMAGE": ("Magic Damage", "", 1),
    "MAG_DMG_DEALT": ("Magic Damage Dealt", "%", 1),
    "PHYS_DMG_DEALT": ("Physical Damage Dealt", "%", 1),
    "RANGED_DMG_DEALT": ("Ranged Damage Dealt", "%", 1),
    "MAGIC_BURST_BONUS_CAPPED": ("Magic Burst Bonus", "%", 1),
    "MAGIC_BURST_BONUS_UNCAPPED": ("Magic Burst Bonus II", "%", 1),
    "MAG_BURST_BONUS": ("Magic Burst Bonus", "%", 1),
    "MAGIC_ABSORB": ("Magic Absorb Rate", "%", 1),
    "EVA": ("Evasion", "", 1),
    "EVA_PERCENT": ("Evasion Rate", "%", 1),
    "EVASION": ("Evasion Skill", "", 1),
    "PARRY": ("Parry Skill", "", 1),
    "INQUARTATA": ("Parry Rate", "%", 1),
    "ADDITIVE_GUARD": ("Guard Rate", "%", 1),
    "COUNTER": ("Counter Rate", "%", 1),
    "COUNTER_DAMAGE": ("Counter Damage", "%", 1),
    "COUNTERSTANCE_EFFECT": ("Counterstance Bonus", "%", 1),
    "DODGE_EFFECT": ("Dodge Bonus", "", 1),
    "FOCUS_EFFECT": ("Focus Bonus", "", 1),
    "CHAKRA_MULT": ("Chakra Potency", "", 1),
    "STORETP": ("Store TP", "", 1),
    "SAVETP": ("Save TP", "", 1),
    "CONSERVE_TP": ("Conserve TP", "%", 1),
    "DOUBLE_ATTACK": ("Double Attack", "%", 1),
    "DOUBLE_ATTACK_DMG": ("Double Attack Damage", "%", 1),
    "TRIPLE_ATTACK": ("Triple Attack", "%", 1),
    "ZANSHIN": ("Zanshin", "%", 1),
    "DUAL_WIELD": ("Dual Wield Delay", "%", -1),
    "MARTIAL_ARTS": ("Martial Arts Delay", "", -1),
    "DELAYP": ("Attack Delay", "%", 1),
    "CRITHITRATE": ("Critical Hit Rate", "%", 1),
    "CRIT_DMG_INCREASE": ("Critical Hit Damage", "%", 1),
    "RANGED_CRIT_DMG_INC": ("Ranged Crit Damage", "%", 1),
    "CRITICAL_HIT_EVASION": ("Crit Hit Evasion", "%", 1),
    "CRIT_DEF_BONUS": ("Crit Defense Bonus", "%", 1),
    "HASTE_GEAR": ("Equipment Haste", "%", 0.01),
    "HASTE_ABILITY": ("Ability Haste", "%", 0.01),
    "HASTE_MAGIC": ("Magic Haste", "%", 0.01),
    "SUBTLE_BLOW": ("Subtle Blow", "", 1),
    "SUBTLE_BLOW_II": ("Subtle Blow II", "", 1),
    "KICK_ATTACK_RATE": ("Kick Attack Rate", "%", 1),
    "KICK_DMG": ("Kick Damage", "", 1),
    "SKILLCHAINDMG": ("Skillchain Damage", "%", 1),
    "SKILLCHAINBONUS": ("Skillchain Bonus", "%", 1),
    "ALL_WSDMG_ALL_HITS": ("Weaponskill Damage", "%", 1),
    "DMG": ("Damage Taken", "%", 0.01),
    "DMGPHYS": ("Physical Damage Taken", "%", 0.01),
    "DMGMAGIC": ("Magic Damage Taken", "%", 0.01),
    "DMGBREATH": ("Breath Damage Taken", "%", 0.01),
    "UDMMAGIC": ("Uncapped Magic DT", "%", 0.01),
    "UDMBREATH": ("Uncapped Breath DT", "%", 0.01),
    "FIRE_SDT": ("Fire Damage Taken", "%", 0.01),
    "ICE_SDT": ("Ice Damage Taken", "%", 0.01),
    "WIND_SDT": ("Wind Damage Taken", "%", 0.01),
    "EARTH_SDT": ("Earth Damage Taken", "%", 0.01),
    "THUNDER_SDT": ("Thunder Damage Taken", "%", 0.01),
    "WATER_SDT": ("Water Damage Taken", "%", 0.01),
    "LIGHT_SDT": ("Light Damage Taken", "%", 0.01),
    "DARK_SDT": ("Dark Damage Taken", "%", 0.01),
    "PHALANX": ("Phalanx", "", 1),
    "ENMITY": ("Enmity", "", 1),
    "ENMITY_LOSS_REDUCTION": ("Enmity Retention", "%", 1),
    "STATUSRES": ("Status Ailment Resist", "", 1),
    "KNOCKBACK_REDUCTION": ("Knockback Reduction", "%", 1),
    "KNOCKBACK_IMMUNE": ("Knockback Immunity", "", 1),
    "MOVE_SPEED_STACKABLE": ("Movement Speed", "%", 1),
    "CURE_POTENCY": ("Cure Potency", "%", 1),
    "CURE_POTENCY_RCVD": ("Cure Potency Received", "%", 1),
    "WALTZ_POTENCY": ("Waltz Potency", "%", 1),
    "HEALING_BREATH": ("Healing Breath Potency", "%", 1),
    "FASTCAST": ("Fast Cast", "%", 1),
    "UFASTCAST": ("Uncapped Fast Cast", "%", 1),
    "SPELLINTERRUPT": ("Spell Interruption Down", "%", 1),
    "ELEMENTAL_CELERITY": ("Elemental Cast Time Down", "%", 1),
    "DARK_MAGIC_CAST": ("Dark Magic Cast Time", "%", 1),
    "SONG_SPELLCASTING_TIME": ("Song Cast Time Down", "%", 1),
    "SONG_RECAST_DELAY": ("Song Recast Down", "s", 1),
    "RECAST_REDUCTION": ("Recast Reduction", "s", 1),
    "SNAPSHOT": ("Snapshot", "%", 1),
    "SNAP_SHOT": ("Snapshot", "%", 1),
    "RAPID_SHOT": ("Rapid Shot", "%", 1),
    "RECYCLE": ("Recycle", "%", 1),
    "REFRESH": ("Refresh", "/tick", 1),
    "REGEN": ("Regen", "/tick", 1),
    "REGEN_MULTIPLIER": ("Regen Potency", "%", 1),
    "REGEN_DURATION": ("Regen Duration", "s", 1),
    "REGAIN": ("Regain", " TP/tick", 1),
    "REGAIN_DOWN": ("Regain Down", "", 1),
    "MP_COST_REDUCTION": ("MP Cost Reduction", "%", 1),
    "OCCULT_ACUMEN": ("Occult Acumen", "", 1),
    "SUBLIMATION_BONUS": ("Sublimation Charge", "", 1),
    "EBULLIENCE_AMOUNT": ("Ebullience Bonus", "%", 1),
    "AUGMENTS_CONVERT": ("Enhances Convert", "", 1),
    "BERSERK_POTENCY": ("Berserk Potency", "%", 1),
    "BERSERK_DURATION": ("Berserk Duration", "s", 1),
    "DEFENDER_DURATION": ("Defender Duration", "s", 1),
    "AGGRESSOR_DURATION": ("Aggressor Duration", "s", 1),
    "WARCRY_DURATION": ("Warcry Duration", "s", 1),
    "ENHANCES_BLOOD_RAGE": ("Enhances Blood Rage", "", 1),
    "UTSUSEMI": ("Utsusemi Shadows", "", 1),
    "VFLOURISH_MACC": ("Violent Flourish M.Acc", "", 1),
    "PHANTOM_ROLL": ("Phantom Roll+", "", 1),
    "PHANTOM_DURATION": ("Phantom Roll Duration", "s", 1),
    "REPAIR_EFFECT": ("Repair Potency", "%", 1),
    "OVERLOAD_THRESH": ("Overload Threshold", "", 1),
    "PREVENT_OVERLOAD": ("Overload Immunity", "", 1),
    "AVATAR_PERPETUATION": ("Avatar Perpetuation", "", 1),
    "SIC_READY_RECAST": ("Sic / Ready Recast", "s", 1),
    "AUTO_MELEE_SKILL": ("Automaton Melee Skill", "", 1),
    "AUTO_RANGED_SKILL": ("Automaton Ranged Skill", "", 1),
    "AUTO_MAGIC_SKILL": ("Automaton Magic Skill", "", 1),
    "SHIELD": ("Shield Skill", "", 1),
    "SHIELDBLOCKRATE": ("Shield Block Rate", "%", 1),
    "SHIELD_DEF_BONUS": ("Shield Defense Bonus", "", 1),
    "PALISADE_BLOCK_BONUS": ("Shield Block Rate", "%", 1),
    "SHIELD_MASTERY_TP": ("Shield Mastery TP", "", 1),
    "HTH": ("Hand-to-Hand Skill", "", 1),
    "HANDTOHAND": ("Hand-to-Hand Skill", "", 1),
    "DAGGER": ("Dagger Skill", "", 1),
    "SWORD": ("Sword Skill", "", 1),
    "GSWORD": ("Great Sword Skill", "", 1),
    "GREAT_SWORD": ("Great Sword Skill", "", 1),
    "AXE": ("Axe Skill", "", 1),
    "SCYTHE": ("Scythe Skill", "", 1),
    "POLEARM": ("Polearm Skill", "", 1),
    "KATANA": ("Katana Skill", "", 1),
    "GKATANA": ("Great Katana Skill", "", 1),
    "GREAT_KATANA": ("Great Katana Skill", "", 1),
    "CLUB": ("Club Skill", "", 1),
    "STAFF": ("Staff Skill", "", 1),
    "ARCHERY": ("Archery Skill", "", 1),
    "MARKSMANSHIP": ("Marksmanship Skill", "", 1),
    "DIVINE": ("Divine Magic Skill", "", 1),
    "HEALING": ("Healing Magic Skill", "", 1),
    "ENHANCE": ("Enhancing Magic Skill", "", 1),
    "ENHANCING": ("Enhancing Magic Skill", "", 1),
    "ENFEEBLE": ("Enfeebling Magic Skill", "", 1),
    "ELEM": ("Elemental Magic Skill", "", 1),
    "DARK": ("Dark Magic Skill", "", 1),
    "SUMMONING": ("Summoning Magic Skill", "", 1),
    "NINJUTSU": ("Ninjutsu Skill", "", 1),
    "NINJA_TOOL": ("Ninja Tool Expertise", "%", 1),
    "SINGING": ("Singing Skill", "", 1),
    "STRING": ("String Instrument Skill", "", 1),
    "WIND": ("Wind Instrument Skill", "", 1),
    "BLUE": ("Blue Magic Skill", "", 1),
    "GEOMANCY": ("Geomancy Skill", "", 1),
    "HANDBELL": ("Handbell Skill", "", 1),
    "STR": ("STR", "", 1),
    "DEX": ("DEX", "", 1),
    "VIT": ("VIT", "", 1),
    "AGI": ("AGI", "", 1),
    "INT": ("INT", "", 1),
    "MND": ("MND", "", 1),
    "CHR": ("CHR", "", 1),
}


def format_mod_scaling(mod_code: str, expr: str, local_vars: dict[str, str]) -> dict:
    label, unit, mult = MOD_LABELS.get(mod_code, (mod_code.replace("_", " ").title(), "", 1))
    resolved = expr.strip()
    if resolved in local_vars:
        resolved = local_vars[resolved]

    def fmt_num(v: float) -> str:
        val = v * mult
        sign = "+" if val > 0 else ""
        if abs(val - round(val)) < 1e-6:
            return f"{sign}{int(round(val))}"
        return f"{sign}{val:.1f}"

    m_tier = re.search(r"scale(?:Commander)?Tier\s*\(\s*lvl\s*,\s*([^)]+)\)", resolved)
    if m_tier:
        nums = []
        for x in m_tier.group(1).split(","):
            x = x.strip()
            try:
                nums.append(float(x))
            except ValueError:
                pass
        if len(nums) == 3:
            tiers_str = f"{fmt_num(nums[0])} / {fmt_num(nums[1])} / {fmt_num(nums[2])}{unit}"
            return {"mod": mod_code, "label": label, "value": tiers_str, "bracket": "Lv.10 / 30 / 50+"}
        elif len(nums) >= 4:
            tiers_str = f"{fmt_num(nums[0])} / {fmt_num(nums[1])} / {fmt_num(nums[2])} / {fmt_num(nums[3])}{unit}"
            return {"mod": mod_code, "label": label, "value": tiers_str, "bracket": "Lv.10 / 30 / 50 / 70+"}

    if "lvl * 0.95" in resolved:
        return {"mod": mod_code, "label": label, "value": "+10 -> +71 (Rank A+)", "bracket": "Scales w/ Level"}

    if "getArcheryAPlusBonus" in resolved:
        return {"mod": mod_code, "label": label, "value": "Raises C+ -> A+ (+66 @ Lv.75)", "bracket": "Scales w/ Level"}

    try:
        v = float(resolved)
        return {"mod": mod_code, "label": label, "value": f"{fmt_num(v)}{unit}", "bracket": "Always Active"}
    except ValueError:
        return {"mod": mod_code, "label": label, "value": resolved, "bracket": "Passive"}


# ---------------------------------------------------------------------------
# 1. Parse Job Crystal Specs (*_specs.lua + overlords_job_specs.lua)
# ---------------------------------------------------------------------------
JOB_META = {
    "WAR": {"id": 1, "name": "Warrior", "color": "#ef4444", "badge": "WAR"},
    "MNK": {"id": 2, "name": "Monk", "color": "#f97316", "badge": "MNK"},
    "WHM": {"id": 3, "name": "White Mage", "color": "#f8fafc", "badge": "WHM"},
    "BLM": {"id": 4, "name": "Black Mage", "color": "#a855f7", "badge": "BLM"},
    "RDM": {"id": 5, "name": "Red Mage", "color": "#ec4899", "badge": "RDM"},
    "THF": {"id": 6, "name": "Thief", "color": "#eab308", "badge": "THF"},
    "PLD": {"id": 7, "name": "Paladin", "color": "#fde047", "badge": "PLD"},
    "DRK": {"id": 8, "name": "Dark Knight", "color": "#dc2626", "badge": "DRK"},
    "BST": {"id": 9, "name": "Beastmaster", "color": "#84cc16", "badge": "BST"},
    "BRD": {"id": 10, "name": "Bard", "color": "#38bdf8", "badge": "BRD"},
    "RNG": {"id": 11, "name": "Ranger", "color": "#22c55e", "badge": "RNG"},
    "SAM": {"id": 12, "name": "Samurai", "color": "#fb923c", "badge": "SAM"},
    "NIN": {"id": 13, "name": "Ninja", "color": "#f43f5e", "badge": "NIN"},
    "DRG": {"id": 14, "name": "Dragoon", "color": "#6366f1", "badge": "DRG"},
    "SMN": {"id": 15, "name": "Summoner", "color": "#10b981", "badge": "SMN"},
    "BLU": {"id": 16, "name": "Blue Mage", "color": "#3b82f6", "badge": "BLU"},
    "COR": {"id": 17, "name": "Corsair", "color": "#f59e0b", "badge": "COR"},
    "PUP": {"id": 18, "name": "Puppetmaster", "color": "#d946ef", "badge": "PUP"},
    "DNC": {"id": 19, "name": "Dancer", "color": "#f472b6", "badge": "DNC"},
    "SCH": {"id": 20, "name": "Scholar", "color": "#14b8a6", "badge": "SCH"},
    "GEO": {"id": 21, "name": "Geomancer", "color": "#2dd4bf", "badge": "GEO"},
    "RUN": {"id": 22, "name": "Rune Fencer", "color": "#06b6d4", "badge": "RUN"},
}

CUSTOM_TRAITS = {
    140: {"id": 140, "displayId": 1676, "name": "Commander's Tactics", "job": "WAR", "crystal": "Commander", "desc": "Unlocks short-cooldown tactical battle cries and single-stance Warcry sharing at Lv.10+."},
    141: {"id": 141, "displayId": 1677, "name": "Berserker's Fury", "job": "WAR", "crystal": "Berserker", "desc": "Amplifies Attack%, Double Attack, Weaponskill Damage, and Berserk/Blood Rage ferocity."},
    142: {"id": 142, "displayId": 1678, "name": "Spartan's Phalanx", "job": "WAR", "crystal": "Spartan", "desc": "Grants Polearm & Size-1 Buckler Mastery, Spartan's Grit damage-to-barrier conversion, charge-based Melee & Spell Brace deflection, and phalanx mitigation."},
    143: {"id": 143, "displayId": 1679, "name": "Sensei's Flow", "job": "MNK", "crystal": "Sensei", "desc": "Mastery of Staff deflection: parrying and evading restore HP/TP, build enmity, and riposte."},
    144: {"id": 144, "displayId": 1680, "name": "Medic's Grace", "job": "SCH", "crystal": "Medic", "desc": "Unlocks Call Eos, 2-hour Addendum: White, HP-free 2x Sublimation, and free 10y Accession on Cure/Regen."},
    145: {"id": 145, "displayId": 1681, "name": "Sage's Wisdom", "job": "SCH", "crystal": "Sage", "desc": "Unlocks Call Titania, 2-hour Addendum: Black, permanent Ebullience, and +50% 2-hour Helix spells."},
    146: {"id": 146, "displayId": 1682, "name": "Bladewheel Mastery", "job": "DNC", "crystal": "Bladewheel", "desc": "Enables ranged Chakram auto-attacks, 20y Steps/Flourishes/Sambas, and 12 custom Throwing weaponskills."},
    147: {"id": 147, "displayId": 1683, "name": "Harbinger's Drain", "job": "BLM", "crystal": "Necromancer", "desc": "Scythe WSs heal Tank Thralls (Undead Warrior / Dullahan) for 16/18/20/22% Thrall Max HP (clamp-proof) and Caster Thralls for 25-50% of WS damage."},
    148: {"id": 148, "displayId": 1684, "name": "Dark Pact", "job": "BLM", "crystal": "Necromancer", "desc": "While an Undead thrall is active, grants scaling Double Attack, Store TP, and Accuracy."},
    149: {"id": 149, "displayId": 1685, "name": "Grim Conversion", "job": "BLM", "crystal": "Necromancer", "desc": "Converts Magic Accuracy -> Accuracy, MAB -> Attack, Fast Cast -> Haste, and MB Bonus -> WSD."},
    150: {"id": 150, "displayId": 1686, "name": "Inquisitor's Ward", "job": "RUN", "crystal": "Inquisitor", "desc": "3-Rune Mastery at Lv.10+, non-consuming Runes, Runic Riposte on Parry, and dual Tank Stances."},
    151: {"id": 151, "displayId": 1687, "name": "Runic Brand", "job": "RUN", "crystal": "Spellblade", "desc": "3-Rune Mastery at Lv.10+, elemental discharges on every swing/WS, and Mono/Tri-Rune Resonance."},
    152: {"id": 152, "displayId": 1688, "name": "Sacred Pulse", "job": "RUN", "crystal": "Lifebinder", "desc": "3-Rune Mastery at Lv.10+, 15s CD AoE Vivacious Pulse with Rune boons, Runic Lifetap, and AoE Regen."},
    153: {"id": 153, "displayId": 1689, "name": "Black Belt's Mastery", "job": "MNK", "crystal": "Black Belt", "desc": "Pure Hand-to-Hand oath: amplifies Kick Attacks, Double Attack, Critical Hits, WSD, and refunds +75 TP per H2H weaponskill."},
    154: {"id": 154, "displayId": 1690, "name": "Chi Weaver's Pulse", "job": "MNK", "crystal": "Chi Weaver", "desc": "Empty-handed ranged Light Chi bolts (0-20y) emit a 12y AoE healing pulse around the target mob while mending the Monk at range."},
    158: {"id": 158, "displayId": 1694, "name": "Ronin's Mushin", "job": "SAM", "crystal": "Ronin", "desc": "Requires Great Katana: unlocks multi-charge Mind's Eye counter-anticipation, Mushin Stagger damage deferral, and Seigan mitigation."},
    159: {"id": 159, "displayId": 1695, "name": "Oisoya Mastery", "job": "SAM", "crystal": "Imperial Archer", "desc": "Raises Archery to A+ with 100% arrow preservation, 20y Bow auto-attacks, zero point-blank penalty, and Drawn Oisoya <-> Cosmic Brand combos."},
    160: {"id": 160, "displayId": 1696, "name": "Onimaru's Command", "job": "SAM", "crystal": "Warlord", "desc": "Requires Great Katana: empowers 20s Hagakure Iaijutsu Sundering Draw-Slashes, party-sharing Ashura's Edge stacks, and Onimaru Blood-Quench party HP/MP/TP Skillchain surges."},
    181: {"id": 181, "displayId": 1717, "name": "Warden's Ration", "job": "RNG", "crystal": "Huntsman", "desc": "Ranged Weaponskills heal your active beast for 15/18/20/22% Beast Max HP (clamp-proof) and grant +250 Pet TP."},
    182: {"id": 182, "displayId": 1718, "name": "Primeval Pack", "job": "RNG", "crystal": "Huntsman", "desc": "Grants Lv.10 Crossbow/Bolt QoL, 100% Ammo Recycle, zero ranged distance penalty, +12/16/20/25% HP, +15..50 Archery/Marksmanship, +12..38 RACC, +15..40% Snapshot/Rapid Shot, and +8..22 Store TP while a pet is active."},
    183: {"id": 183, "displayId": 1719, "name": "Apex Bond", "job": "RNG", "crystal": "Huntsman", "desc": "Modal pet stance: Glacial Tusker (Wild Raaz / Cehuetzi) anchors bosses with Tier 6 -60% DMG Dealt, 100% AoE/Conal immunity, 100% enmity transfer & 80% Cure forwarding; Volcanic Saurian (Stalker Raptor / Gabbrath) projects a 15y Party Pack Aura."},
}

CUSTOM_ABILITIES_BY_SPEC = {
    ("WAR", "commander"): [
        {"id": 2, "name": "Warcry (Commander)", "cd": "60s", "target": "Party (10y)", "desc": "Unlocked early at Lv.10 on a 60s recast (45s duration). Shares your single active WAR stance (Berserk, Defender, Aggressor, Retaliation, or Restraint) with the party."},
        {"id": 396, "name": "Tactical Breach", "cd": "20s", "target": "Enemy (15y)", "desc": "Marks target for 10s: +12/18/24/30% Skillchain DMG taken, +8/12/16/20% Magic Burst & Crit DMG taken, and grants +100/150/200/250 TP to the SC closer."},
        {"id": 397, "name": "Formation: Bulwark", "cd": "25s", "target": "Party (10y)", "desc": "15s ward: Stacking Phalanx (8 + 0.45*Lv), +5/10/15/20 MDEF, +12/18/25/35 Status Resist, and +30/50/75/100% Knockback Resist."},
        {"id": 398, "name": "Battle Cadence", "cd": "20s", "target": "Party (10y)", "desc": "12s rhythm: +12/18/24/30 Subtle Blow (+0/0/5/10 SB II), +10/15/22/30 Conserve TP, and +8/12/16/20% Cure Potency Received."},
        {"id": 399, "name": "Rallying Horn", "cd": "45s", "target": "Party (12y)", "desc": "Cleanses Slow/Bind (Lv30+ Weight/Para; Lv50+ DEF/MDEF Down; Lv70+ Atk/Acc Down), restores 5/7/9/12% Max HP, +75/125/175/250 TP, and +8/10/12/15% Move Speed (12s)."},
    ],
    ("WAR", "berserker"): [
        {"id": 400, "name": "Bloodlust Surge", "cd": "25s", "target": "Self", "desc": "10s burst: +10/14/18/24% Attack% and +15/22/30/40% Double Attack Damage at the cost of -10% Defense."},
        {"id": 401, "name": "Savage Cleave", "cd": "20s", "target": "Enemy (4y)", "desc": "Overstraining physical cleave (1.4x-2.6x Weapon DMG + STR, 0 TP gained) that inflicts 6/8/10/12% Max HP non-lethal self-recoil."},
    ],
    ("WAR", "spartan"): [
        {"id": 402, "name": "Impaling Thrust", "cd": "20s", "target": "Enemy (8y)", "desc": "Requires Polearm. High-enmity spear strike that Stuns (2s, +5s Silence mid-cast), applies Maim (-15% ATK / -20 ACC for 15s), and grants +2 Grit (+4 during Defender or Mighty Strikes)."},
        {"id": 403, "name": "Phalanx Ward", "cd": "35s (2 Grit)", "target": "Self (12s)", "desc": "Requires Polearm. Grants +15/22/30/38% Block, -10/12/15/18% DT, +25/35/45/55 Enmity, Knockback Immunity, and arms 1 Heavy Brace (-50% next hit, maxes Grit to 5, 2s Stun, Exposed Guard, +4s Silence vs spells)."},
    ],
    ("MNK", "sensei"): [
        {"id": 61, "name": "Iron Counterstance", "cd": "120s", "target": "Self", "desc": "Unlocked early at Lv.10 on a 120s recast: +30% Counter Rate, +20 Counter DMG, -10% Damage Taken, +20 Enmity, with ZERO Defense penalty."},
    ],
    ("MNK", "blackbelt"): [],
    ("MNK", "chiweaver"): [
        {"id": 429, "name": "Resonant Chi", "cd": "20s", "target": "Enemy (20y)", "desc": "Projects a concentrated Light Chi burst at up to 20y, triggering a 1.75x AoE healing pulse & debuff cleanse around the target mob and granting +125 TP."},
        {"id": 430, "name": "Tranquil Lotus", "cd": "30s", "target": "Party (12y AoE)", "desc": "Restores 12/16/20/24% Max HP (+MND) to nearby party members, Trusts, and pets, applying a 15s Sanctuary (+12/20/30/42 Regen, +10/15/20/25% Cure Rcvd, -10/14/18/22 Enmity)."},
        {"id": 431, "name": "Inner Harmony", "cd": "45s", "target": "Self", "desc": "18s meditative overdrive: +15/22/30/40% Cure Potency, +20/30/45/60 MAB & MACC, +5/8/11/15% Ability Haste, +10/18/28/40 Regen, and +40% Chi Bolt & Pulse potency."},
    ],
    ("SCH", "medic"): [
        {"id": 231, "name": "Call Eos", "cd": "300s", "target": "Self", "desc": "Summons Eos, a Light Arts faerie companion that maintains stackable Regen (I-V) on the party and automatically casts -na spells and Erase."},
    ],
    ("SCH", "sage"): [
        {"id": 289, "name": "Call Titania", "cd": "300s", "target": "Self", "desc": "Summons Titania, a Dark Arts faerie companion (BLM/RDM) that enfeebles targets, casts Drain/Aspir, and unleashes Tier I-V elemental nukes."},
    ],
    ("DNC", "bladewheel"): [
        {"id": 404, "name": "Throwing Stance", "cd": "5s", "target": "Self (Toggle)", "desc": "When active, overrides close-range melee swings so your Dancer throws their equipped Chakram at all ranges (0-20y)."},
    ],
    ("BLM", "necromancer"): [
        {"id": 405, "name": "Summon Undead Warrior", "cd": "60s", "target": "Self", "desc": "Summons a Skeleton Warrior thrall (WAR/DRK) that tanks and cleaves enemies."},
        {"id": 406, "name": "Summon Undead Mage", "cd": "60s", "target": "Self", "desc": "Summons a Skeleton Mage thrall (BLM/DRK) that casts Dark/Elemental spells."},
        {"id": 407, "name": "Corpse Explosion", "cd": "45s", "target": "Self / Pet AoE", "desc": "Detonates your active Undead thrall for massive Dark AoE damage around the pet."},
        {"id": 408, "name": "Grim Reaping", "cd": "30s", "target": "Enemy (15y)", "desc": "Commands your Undead Warrior or Dullahan to unleash a heavy physical cleave that heals the thrall (and inflicts DEF Down if Dullahan)."},
        {"id": 409, "name": "Grim Incantations", "cd": "30s", "target": "Enemy (20y)", "desc": "Commands your Undead Mage or Corse to cast a Dark burst that drains MP for the master and heals the thrall (and inflicts MDEF Down if Corse)."},
        {"id": 410, "name": "Summon Corse (Lv.75)", "cd": "60s", "target": "Self", "desc": "Lv.75 Capstone summon: calls an elite Corse archmage thrall with enhanced Grim Incantations."},
        {"id": 411, "name": "Summon Dullahan (Lv.75)", "cd": "60s", "target": "Self", "desc": "Lv.75 Capstone summon: calls an elite headless Dullahan knight thrall with enhanced Grim Reaping."},
    ],
    ("RUN", "inquisitor"): [
        {"id": 412, "name": "Stance: Iron Battuta", "cd": "15s", "target": "Self", "desc": "Physical Parry stance: +15/22/30/40% Parry Rate, -8/12/16/20% PDT, +15/25/35/50% DEF. Swapping stances triggers Steel Flash (AoE Enmity + 4-10% HP Stoneskin)."},
        {"id": 413, "name": "Stance: Runic Aegis", "cd": "15s", "target": "Self", "desc": "Elemental Ward stance: -10/15/20/25% MDT/BDT, +20/35/50/70 MEVA, +15/25/35/50 MDEF, +10/15/20/25% Magic Absorb. Swapping triggers Odyllic Pulse (Enmity + HP/MP + Cleanse)."},
        {"id": 414, "name": "Runic Convergence", "cd": "30s", "target": "Self", "desc": "Fuses both stances for 10s (-12/16/20/25% DT, +20/30/40/50% Parry, +30/45/60/80 MEVA, +Enmity) and heals 3% Max HP per active Rune."},
    ],
    ("RUN", "spellblade"): [
        {"id": 415, "name": "Effusion Slash", "cd": "20s", "target": "Enemy (4y)", "desc": "Non-consuming Great Sword arcane strike (1.5x-2.8x +20%/Rune) aligned to your newest Rune element. Can Magic Burst (+35% DMG) and grants +100/150/200/250 TP."},
        {"id": 416, "name": "Overcharge Runes", "cd": "30s", "target": "Self", "desc": "12s overdrive: +15/22/30/40 MAB, +10/14/18/24% Attack%, +15/20/25/30 MB Bonus, 2x Runic Brand damage, and refreshes active Rune durations."},
    ],
    ("RUN", "lifebinder"): [
        {"id": 383, "name": "Sacred Pulse (Vivacious Pulse)", "cd": "15s", "target": "Party (12y AoE)", "desc": "Unlocked at Lv.10 on a 15s recast: Party AoE heal + per-Rune boons (Lux: +25% heal & Regen; Unda: debuff cleanse; Tenebrae: MP & Refresh; Elemental: 25% Stoneskin)."},
        {"id": 417, "name": "Font of Life", "cd": "20s", "target": "Ally (15y)", "desc": "Restores 22/30/38/48% Max HP, cleanses 2 debuffs, and grants -10/14/18/22% Damage Taken & +10/15/20/25% Cure Potency Received for 12s."},
        {"id": 418, "name": "Sanctified Ward", "cd": "35s", "target": "Party (12y AoE)", "desc": "Instant 10/14/18/22% Party HP heal + 15s Sanctuary (+10/18/28/40 Regen/tick, -8/12/16/20% Damage Taken, and +15/25/35/50 Magic Evasion)."},
    ],
    ("SAM", "ronin"): [
        {"id": 174, "name": "Seigan (Mushin Tank Stance)", "cd": "15s", "target": "Self", "desc": "Unlocked at Lv.10 on a 15s recast (requires Great Katana): -8/10/12/14% Damage Taken, +12/15/18/20% DEF, +25/30/35/40 Enmity, and +12/15/18/20% Counter Rate."},
        {"id": 62, "name": "Third Eye (Mind's Eye)", "cd": "15s", "target": "Self", "desc": "Anticipates 2 (Lv.50+: 3) melee hits or single-target mob TP moves, countering with a Great Katana slash (+60 TP & heavy Enmity)."},
        {"id": 168, "name": "Blade Bash (Purify Interrupt)", "cd": "30s", "target": "Enemy (4y)", "desc": "30s recast: Stuns target, inflicts Attack Down (-15%), generates heavy Enmity, and completely purifies Mushin Stagger."},
    ],
    ("SAM", "imperialarcher"): [
        {"id": 438, "name": "Oisoya Shot", "cd": "25s", "target": "Enemy (20y)", "desc": "Requires Bow. Tenzen's signature piercing arrow shot at up to 20y: restores +200/250/300/350 TP, primes Chainbound (if unchained), and grants Drawn Oisoya (+Cosmic Brand if Great Katana equipped)."},
        {"id": 173, "name": "Hasso (Bow & Blade)", "cd": "30s", "target": "Self", "desc": "Unlocked at Lv.10 (usable with Bow or Great Katana): adds +8/10/13/15% Snapshot, +10/13/15/18% R.Atk%, +15/20/25/30 R.Acc, +4/7/10/12 AGI, and +10% Ability Haste even with Bow equipped."},
    ],
    ("SAM", "warlord"): [
        {"id": 288, "name": "Hagakure (Iaijutsu Sundering Noto)", "cd": "20s", "target": "Self / Target Debuff", "desc": "Unlocked at Lv.10 on a 20s recast (requires Great Katana): sheathes into Noto stance (15s), turning your next Tachi WS into an Iaijutsu Draw-Slash (+35..100% Crit Rate, +250..600 TP Bonus, Save TP, Chainbound) that cleaves the enemy's guard for -15% DEF, -10% MDEF, and -25 Evasion for 15s."},
        {"id": 453, "name": "Onimaru Tithe", "cd": "25s", "target": "Party (15y, 12s)", "desc": "Requires Great Katana. Unleashes the cursed energy of your Ashura's Edge stacks across all party members within 15y: immediately grants +350 TP, +12% Weaponskill Damage, and +15% Lifesteal on melee/ranged hits for 12s, and refreshes Ashura's Edge to 3 stacks."},
    ],
}

# Standard FFXI abilities unlocked early (Lv.10+) by Crystal Specs via extraAbilities
VANILLA_ABILITY_INFO = {
    2: ("Warcry", "60s", "Party (10y)", "Increases party Attack and shares active stances in OverlordsXI."),
    22: ("Invincible", "3600s", "Self", "Grants immunity to physical attacks for 30s."),
    27: ("Meikyo Shisui", "3600s", "Self", "Allows rapid Weapon Skill chaining for 30s."),
    28: ("Mijin Gakure", "3600s", "Enemy", "Sacrifices HP for massive elemental damage."),
    46: ("Shield Bash", "60s", "Enemy", "Strikes with shield to Stun target and generate enmity."),
    48: ("Sentinel", "300s", "Self", "Dramatically reduces physical damage taken and boosts enmity."),
    61: ("Call Wyvern", "1200s", "Self", "Summons your Wyvern companion."),
    62: ("Third Eye", "60s", "Self", "Anticipates incoming attacks and counters with Seigan."),
    63: ("Meditate", "180s", "Self", "Grants 1000–2000 TP over time."),
    64: ("Warding Circle", "300s", "Party", "Grants Demon Killer and Magic Defense Bonus against Demons."),
    66: ("Jump", "60s", "Enemy", "Leaps into the air to deliver a high-damage attack."),
    67: ("High Jump", "120s", "Enemy", "Leaping strike that sheds enmity or triggers spec effects."),
    68: ("Super Jump", "180s", "Enemy", "Evades all enmity briefly with a high leap."),
    69: ("Fight", "5s", "Enemy", "Commands your beast/pet to attack the target."),
    70: ("Heel", "5s", "Self", "Commands your pet to disengage and follow you."),
    72: ("Sic", "90s", "Enemy", "Commands your jug pet to execute a special ability."),
    73: ("Stay", "5s", "Self", "Commands your pet to hold position and regenerate."),
    78: ("Reward", "90s", "Self", "Restores your pet's HP and removes status ailments."),
    80: ("Spirit Link", "90s", "Self", "Transfers HP and status effects with your Wyvern."),
    85: ("Call Beast", "300s", "Self", "Calls a loyal beast companion."),
    92: ("Rampart", "180s", "Party", "Raises defense and grants Magic Shield to nearby party members."),
    96: ("Wild Card", "3600s", "Party", "Rolls the die to reset party Job Abilities and restore MP."),
    97: ("Phantom Roll", "60s", "Party", "Rolls a Corsair buff die for your party (crystal-customized)."),
    123: ("Double-Up", "5s", "Self", "Increases the total of your active Phantom Roll."),
    125: ("Fire Shot", "1s*", "Enemy", "Quick Draw: Fire shot + enhances Fire debuffs (2 charges)."),
    126: ("Ice Shot", "1s*", "Enemy", "Quick Draw: Ice shot + enhances Ice debuffs (2 charges)."),
    127: ("Wind Shot", "1s*", "Enemy", "Quick Draw: Wind shot + enhances Wind debuffs (2 charges)."),
    128: ("Earth Shot", "1s*", "Enemy", "Quick Draw: Earth shot + enhances Earth debuffs (2 charges)."),
    129: ("Thunder Shot", "1s*", "Enemy", "Quick Draw: Thunder shot + enhances Thunder debuffs (2 charges)."),
    130: ("Water Shot", "1s*", "Enemy", "Quick Draw: Water shot + enhances Water debuffs (2 charges)."),
    131: ("Light Shot", "1s*", "Enemy", "Quick Draw: Light shot + Sleeping/Light enhancement (2 charges)."),
    132: ("Dark Shot", "1s*", "Enemy", "Quick Draw: Dark shot + Dispel effect (2 charges)."),
    133: ("Random Deal", "1200s*", "Party", "Refreshes party Job Ability recast timers."),
    136: ("Activate", "1200s", "Self", "Summons your Automaton companion."),
    137: ("Repair", "90s*", "Self", "Restores your Automaton's HP and removes status ailments."),
    138: ("Deploy", "5s", "Enemy", "Commands your Automaton to engage the target."),
    140: ("Retrieve", "5s", "Self", "Commands your Automaton to disengage and follow."),
    141: ("Fire Maneuver", "10s", "Self", "Enhances Automaton Attack and offensive combat modules."),
    142: ("Ice Maneuver", "10s", "Self", "Enhances Automaton INT/Magic Attack and Enfeebling AI."),
    143: ("Wind Maneuver", "10s", "Self", "Enhances Automaton Haste and Ranged/Melee evasion."),
    144: ("Earth Maneuver", "10s", "Self", "Enhances Automaton Defense, Shield/Damage reduction, and tanking."),
    145: ("Thunder Maneuver", "10s", "Self", "Enhances Automaton Accuracy, Critical Hit Rate, and stun AI."),
    146: ("Water Maneuver", "10s", "Self", "Enhances Automaton MND, Magic Defense, and Cure thresholds."),
    147: ("Light Maneuver", "10s", "Self", "Enhances Automaton Regen, Light curing AI, and healing potency."),
    148: ("Dark Maneuver", "10s", "Self", "Enhances Automaton Refresh and MP conservation."),
    153: ("Martyr", "600s*", "Ally", "Sacrifices a portion of HP to restore an ally's HP."),
    154: ("Devotion", "600s*", "Ally", "Sacrifices a portion of HP to restore an ally's MP."),
    158: ("Chivalry", "600s*", "Self", "Converts TP into MP."),
    167: ("Shikikoyo", "300s", "Ally", "Transfers excess TP above 1000 to a party member."),
    168: ("Blade Bash", "180s*", "Enemy", "Two-handed strike that Stuns and lowers target Defense/Attack."),
    173: ("Hasso", "60s*", "Self", "Offensive stance granting Haste, Accuracy, and STR."),
    174: ("Seigan", "60s*", "Self", "Defensive counter-anticipation stance paired with Third Eye."),
    176: ("Diffusion", "600s*", "Self", "Extends your next self-target Blue Magic spell to party members in AoE."),
    177: ("Snake Eye", "300s*", "Self", "Forces the next Double-Up roll to land on 1."),
    178: ("Fold", "300s*", "Self", "Removes Bust or one active Phantom Roll immediately."),
    180: ("Ventriloquy", "60s*", "Enemy", "Swaps cumulative enmity with your Automaton."),
    181: ("Trance", "3600s", "Self", "Reduces TP cost of Waltzes and Sambas to zero for 60s."),
    184: ("Drain Samba", "60s", "Party", "Grants melee Drain Samba effect on attacks."),
    185: ("Drain Samba II", "60s", "Party", "Upgraded Drain Samba restoring greater HP on melee hits."),
    186: ("Drain Samba III", "60s", "Party", "Highest-tier Drain Samba lifetap aura for party."),
    190: ("Curing Waltz", "6s", "Ally", "Spends TP to instantly heal a party member."),
    191: ("Curing Waltz II", "8s", "Ally", "Mid-tier TP heal for a party member."),
    192: ("Curing Waltz III", "10s", "Ally", "High-potency TP heal for a party member."),
    193: ("Curing Waltz IV", "13s", "Ally", "Strong TP heal for a party member."),
    201: ("Quickstep", "5s", "Enemy", "Lowers target Evasion and grants Finishing Moves."),
    202: ("Box Step", "5s", "Enemy", "Lowers target Defense and grants Finishing Moves."),
    203: ("Stutter Step", "5s", "Enemy", "Lowers target Magic Resistance and grants Finishing Moves."),
    204: ("Animated Flourish", "30s", "Enemy", "Spends Finishing Moves for a high-enmity provoke."),
    205: ("Desperate Flourish", "20s", "Enemy", "Spends Finishing Moves to inflict Gravity."),
    207: ("Violent Flourish", "20s", "Enemy", "Spends Finishing Moves to Stun the target."),
    225: ("Snarl", "30s", "Self", "Transfers all of your accumulated enmity to your jug pet."),
    230: ("Sekkanoki", "300s", "Self", "Caps next Weapon Skill TP consumption to 1000 TP."),
    238: ("Fan Dance", "180s", "Self", "Reduces Physical Damage Taken and generates Waltz/Step enmity."),
    239: ("No Foot Rise", "180s", "Self", "Immediately generates maximum Finishing Moves."),
    245: ("Afflatus Solace", "60s*", "Self", "Unlocks Cure Stoneskin ward and Holy/Sacrifice bonuses."),
    248: ("Yonin", "180s*", "Self", "Tank stance boosting Enmity, Parry/DT, and Shadow mitigation."),
    251: ("Ready", "Charge", "Self", "Commands your pet to perform a Ready skill immediately."),
    258: ("Sengikori", "180s", "Self", "Enhances your next Skillchain damage bonus."),
    259: ("Futae", "180s*", "Self", "Spends Ninja Tools to double-cast / surge your next Ninjutsu."),
    287: ("Hamanoha", "300s", "Enemy", "Lowers target Accuracy, Attack, Magic Attack, and Store TP."),
    288: ("Hagakure", "180s*", "Self", "Grants Save TP and TP Bonus to your next Weapon Skill."),
    309: ("Cooldown", "300s*", "Self", "Halves your Automaton's current elemental burden."),
    310: ("Deus Ex Automata", "60s", "Self", "Summons an Automaton when Activate is on cooldown."),
    311: ("Curing Waltz V", "16s", "Ally", "Capstone single-target TP heal."),
    319: ("Restoring Breath", "60s", "Party", "Commands your Wyvern to heal party members immediately."),
    320: ("Konzen-ittai", "180s", "Enemy", "Primes the target for immediate Skillchain closing."),
    367: ("Swordplay", "300s", "Self", "Builds Evasion and Accuracy over time while avoiding hits."),
    369: ("Pflug", "180s", "Party", "Boosts status and elemental resistance matching active Runes."),
    371: ("Valiance", "300s", "Party", "Shares elemental damage reduction matching active Runes."),
    373: ("Liement", "180s", "Party", "Converts elemental damage matching active Runes into HP."),
    374: ("One for All", "300s", "Party", "Grants a Max-HP-scaled magic barrier to nearby party members."),
    376: ("Battuta", "300s", "Self", "Raises Parry Rate and deals elemental counter spikes on parry."),
    383: ("Vivacious Pulse", "60s*", "Party", "Restores HP/MP/Status based on active Runes."),
    387: ("Bestial Loyalty", "1200s*", "Self", "Calls your jug beast without consuming a jug."),
    394: ("Majesty", "60s", "Self", "Turns Cure spells AoE and improves Cure potency + Protect."),
}


def _clean_ident_name(raw_name: str, strip_prefix: str = "") -> str:
    s = raw_name.strip()
    if strip_prefix and s.startswith(strip_prefix):
        s = s[len(strip_prefix) :]
    # Restore common possessive forms like HIGH_ROLLER_STAKES / DREADNOUGHTS_CARAPACE
    s = re.sub(r"^IMP_", "Imperial ", s)
    words = [w for w in s.split("_") if w]
    out = []
    possessive_map = {
        "ALPHAS": "Alpha's",
        "ADVENTURER": "Adventurer's",
        "MUSICIAN": "Musician's",
        "MINSTREL": "Minstrel's",
        "WARLORD": "Warlord's",
        "DREADNOUGHTS": "Dreadnought's",
        "VANGUARDS": "Vanguard's",
        "PUGILISTS": "Pugilist's",
        "CRUSADERS": "Crusader's",
        "TROUBADOURS": "Troubadour's",
        "MANS": "Man's",
        "WARDENS": "Warden's",
    }
    for w in words:
        up = w.upper()
        if up in possessive_map:
            out.append(possessive_map[up])
        else:
            out.append(w.capitalize())
    return " ".join(out)


def _norm_key(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (text or "").lower())


def parse_lua_metadata() -> dict:
    """Dynamically extract trait names/comments and ability display names/comments from all *_specs.lua."""
    traits = {18: {"name": "Dual Wield", "desc": "Unlocks wielding a weapon in each hand and reduces dual-wield attack delay."}}
    ability_names = {}
    ability_comments = {}

    spec_files = [LUA_DIR / "overlords_job_specs.lua"] + sorted(LUA_DIR.glob("*_specs.lua"))
    seen = set()
    for fpath in spec_files:
        if not fpath.exists() or fpath.name in seen:
            continue
        seen.add(fpath.name)
        raw = fpath.read_text(encoding="utf-8", errors="replace")

        # 1. -- Custom Trait ID (173; Astral Sanctuary) or (166: Alpha's Soul-Link)
        for m in re.finditer(r"--\s*Custom Trait ID\s*\(\s*(\d+)\s*[;:]\s*([^)\r\n]+)\)", raw):
            tid = int(m.group(1))
            label = m.group(2).strip()
            if "display id" not in label.lower():
                traits[tid] = {"name": label, "desc": ""}

        # 2. local TRAIT_NAME = <ID>
        for m in re.finditer(r"local\s+(TRAIT_[A-Z0-9_]+)\s*=\s*(\d+)", raw):
            const_name = m.group(1)
            tid = int(m.group(2))
            if tid not in traits:
                traits[tid] = {"name": _clean_ident_name(const_name, "TRAIT_"), "desc": ""}

        # 3. local ABIL_NAME = <ID> -- Display: Clockwork Bulwark
        for m in re.finditer(r"local\s+(?:ABIL_[A-Z0-9_]+|[A-Z0-9_]+_ABIL_ID)\s*=\s*(\d+)([^\r\n]*)", raw):
            aid = int(m.group(1))
            tail = m.group(2)
            disp = re.search(r"--\s*Display:\s*(.+)$", tail)
            if disp:
                ability_names[aid] = disp.group(1).strip()

        # 4. Inline ability summary comments: -- 419: Grave Provoke (Lv.10+): High-enmity undead taunt + Attack Down
        for m in re.finditer(r"^\s*--\s*(\d{3,4})\s*:\s*([^:\r\n]+?)(?:\s*\([^)\r\n]+\))?\s*:\s*(.+)$", raw, re.MULTILINE):
            aid = int(m.group(1))
            aname = m.group(2).strip()
            adesc = m.group(3).strip()
            if "client display id" in adesc.lower() or "recastid" in aname.lower():
                continue
            ability_names.setdefault(aid, aname)
            ability_comments.setdefault(aid, adesc)

    # Ensure curated CUSTOM_TRAITS override/complete anything above
    for tid, ct in CUSTOM_TRAITS.items():
        traits[tid] = {"name": ct["name"], "desc": ct["desc"]}

    return {"traits": traits, "abilityNames": ability_names, "abilityComments": ability_comments}


def _extract_highlight_clause(highlights: list[str], target_name: str) -> str:
    """Find the most informative highlight clause describing an ability or trait."""
    t_norm = _norm_key(target_name)
    if not t_norm:
        return ""

    # Search with flexible apostrophe/punctuation matching; prefer definitions with Name ( or Name:
    def find_match_in_highlights(search_name: str, require_delim: bool) -> str:
        s_norm = _norm_key(search_name)
        if not s_norm:
            return ""
        chars = re.sub(r"[^A-Za-z0-9]", "", search_name)
        pat_core = r"['’\s:\-]*".join(re.escape(ch) for ch in chars)
        pat = pat_core + (r"\s*[\(:]" if require_delim else r"\b")
        for hl in highlights:
            if s_norm not in _norm_key(hl):
                continue
            cleaned = re.sub(r"^(?:Custom\s+JAs?|Crystal\s+JAs?|Tank\s+JAs?|JAs?)\s*:\s*", "", hl.strip(), flags=re.IGNORECASE)
            m = re.search(pat, cleaned, flags=re.IGNORECASE)
            if m:
                sub = cleaned[m.start() :].strip()
                # If a second named ability follows as ") & NextName (" or "), NextName (", trim cleanly after first clause
                split_m = re.search(r"\)\s*(?:&|;|,|and)\s+[A-Z][A-Za-z' -]+\s*\(", sub)
                if split_m and require_delim:
                    sub = sub[: split_m.start() + 1]
                return sub.rstrip(" ;.") + "."
            elif not require_delim:
                return cleaned.rstrip(" ;.") + "."
        return ""

    hit = find_match_in_highlights(target_name, require_delim=True)
    if hit:
        return hit
    hit = find_match_in_highlights(target_name, require_delim=False)
    if hit:
        return hit
    # For summon abilities like "Call Cehuetzi" / "Summon Corse", match the companion name in highlights
    stripped = re.sub(r"^(?:Call|Summon)\s+", "", target_name, flags=re.IGNORECASE).strip()
    if stripped and stripped.lower() != target_name.lower():
        for hl in highlights:
            if _norm_key(stripped) in _norm_key(hl):
                return hl.strip().rstrip(" ;.") + "."
    return ""


def _synthesize_trait_desc(trait_name: str, highlights: list[str], crystal_desc: str) -> str:
    """Synthesize a concise, factual trait description from a crystal's highlights & description."""
    direct = _extract_highlight_clause(highlights, trait_name)
    if direct:
        return direct
    parts = []
    for hl in highlights:
        # Skip pure stat dump lines when picking core mechanical summary
        if re.match(r"^(?:Passives?|Base Mods)\s*\(", hl, flags=re.IGNORECASE):
            continue
        parts.append(hl.rstrip(" ."))
        if len(parts) >= 2:
            break
    if parts:
        joined = "; ".join(parts)
        return (joined[:260].rsplit(" ", 1)[0] + "...") if len(joined) > 265 else joined + "."
    if crystal_desc:
        return crystal_desc.rstrip(" .") + "."
    return f"Core {trait_name} crystal mastery passive."


def resolve_spec_traits(
    extra_traits: list[int],
    jkey: str,
    cname: str,
    highlights: list[str],
    cdesc: str,
    lua_meta: dict,
) -> list[dict]:
    traits_map = lua_meta["traits"]
    out = []
    seen = set()
    for tid in extra_traits:
        if tid in seen:
            continue
        seen.add(tid)
        if tid in CUSTOM_TRAITS:
            ct = copy.deepcopy(CUSTOM_TRAITS[tid])
            out.append(ct)
            continue
        info = traits_map.get(tid, {})
        tname = info.get("name") or f"{cname} Mastery"
        tdesc = info.get("desc") or _synthesize_trait_desc(tname, highlights, cdesc)
        display_id = (1536 + tid) if 140 <= tid <= 255 else tid
        out.append({"id": tid, "displayId": display_id, "name": tname, "job": jkey, "crystal": cname, "desc": tdesc})
    return out


def resolve_spec_abilities(
    extra_ids: list[int],
    jkey: str,
    ckey: str,
    cname: str,
    highlights: list[str],
    sql_abils: dict[int, dict],
    lua_meta: dict,
) -> list[dict]:
    curated_by_id = {a["id"]: a for a in CUSTOM_ABILITIES_BY_SPEC.get((jkey, ckey), [])}
    disp_names = lua_meta["abilityNames"]
    lua_comments = lua_meta["abilityComments"]
    spec_abilities = []
    seen_aids = set()

    for aid in extra_ids:
        if aid in seen_aids:
            continue
        if aid in curated_by_id:
            spec_abilities.append(curated_by_id[aid])
            seen_aids.add(aid)
        elif aid in sql_abils:
            ab = copy.deepcopy(sql_abils[aid])
            if aid in disp_names:
                ab["name"] = disp_names[aid]
            desc = ""
            if aid in lua_comments:
                desc = lua_comments[aid]
            if not desc:
                desc = _extract_highlight_clause(highlights, ab["name"])
            if not desc and ab.get("sqlDesc"):
                desc = ab["sqlDesc"]
            if not desc:
                desc = f"{cname} custom Job Ability ({ab['cd']} recast, {ab['target']})."
            ab["desc"] = desc
            ab.pop("sqlDesc", None)
            spec_abilities.append(ab)
            seen_aids.add(aid)
        elif aid in VANILLA_ABILITY_INFO:
            vname, vcd, vtarget, vdesc = VANILLA_ABILITY_INFO[aid]
            hl_override = _extract_highlight_clause(highlights, vname)
            spec_abilities.append(
                {
                    "id": aid,
                    "name": disp_names.get(aid, vname),
                    "cd": vcd,
                    "target": vtarget,
                    "desc": hl_override if hl_override else f"{vdesc} (Unlocked at Lv.10 by {cname}).",
                }
            )
            seen_aids.add(aid)

    for a in CUSTOM_ABILITIES_BY_SPEC.get((jkey, ckey), []):
        if a["id"] not in seen_aids:
            spec_abilities.append(a)
            seen_aids.add(a["id"])
    return spec_abilities


def _parse_id_list_block(block: str, consts: dict) -> list[int]:
    """Parse Lua array body or `return { ... }` of IDs/constants cleanly."""
    ids = []
    for item in split_top_level_args(block):
        tok = item.strip()
        if not tok:
            continue
        # Handle `(xi.jobAbility and xi.jobAbility.WARCRY) or 2`
        m_or = re.search(r"\bor\s+(\d+)\b", tok)
        if m_or:
            ids.append(int(m_or.group(1)))
            continue
        if tok.isdigit():
            ids.append(int(tok))
        elif tok in consts and isinstance(consts[tok], int):
            ids.append(consts[tok])
    return ids


def _parse_crystal_entry(entry_str: str, consts: dict, job_key: str, fpath_name: str, sql_abils: dict, lua_meta: dict, fallback_idx: int) -> dict | None:
    entry_str = entry_str.strip()
    if not entry_str.startswith("{"):
        return None

    def extract_field(name: str, src: str = entry_str) -> str:
        fm = re.search(rf"\b{name}\s*=\s*(['\"](?:\\.|[^'\"])*['\"]|[A-Z0-9_]+|\d+)", src)
        if not fm:
            return ""
        val = fm.group(1)
        if val in consts:
            return str(consts[val])
        return unquote_lua_str(val)

    cid = extract_field("id")
    ckey = extract_field("key")
    cname = extract_field("name")
    if not cname or not ckey:
        return None
    crole = extract_field("role")
    cicon = extract_field("icon")
    creq = extract_field("reqLevel") or "10"
    cdesc = extract_field("description")

    highlights = []
    hm = re.search(r"\bhighlights\s*=\s*\{", entry_str)
    if hm:
        h_start = entry_str.find("{", hm.start())
        h_end = find_balanced(entry_str, h_start, "{", "}")
        if h_end != -1:
            h_body = entry_str[h_start + 1 : h_end]
            for h_item in split_top_level_args(h_body):
                h_item = h_item.strip()
                if h_item:
                    highlights.append(unquote_lua_str(h_item))

    # Extract extraTraits = { ... }
    extra_traits = []
    tm = re.search(r"\bextraTraits\s*=\s*\{", entry_str)
    if tm:
        t_start = entry_str.find("{", tm.start())
        t_end = find_balanced(entry_str, t_start, "{", "}")
        if t_end != -1:
            extra_traits = _parse_id_list_block(entry_str[t_start + 1 : t_end], consts)

    # Extract extraAbilities = { ... } or function(...) return { ... } end
    extra_abilities = []
    am = re.search(r"\bextraAbilities\s*=", entry_str)
    if am:
        after_eq = entry_str[am.end() :]
        if after_eq.lstrip().startswith("{"):
            a_start = entry_str.find("{", am.end())
            a_end = find_balanced(entry_str, a_start, "{", "}")
            if a_end != -1:
                extra_abilities = _parse_id_list_block(entry_str[a_start + 1 : a_end], consts)
        else:
            fn_m = re.search(r"function\b", after_eq)
            if fn_m:
                fn_slice = after_eq[fn_m.start() :]
                # Extract SHARED_* table references + any direct return { ... } IDs
                for ret_m in re.finditer(r"return\s*\{", fn_slice):
                    r_start = fn_slice.find("{", ret_m.start())
                    r_end = find_balanced(fn_slice, r_start, "{", "}")
                    if r_end != -1:
                        extra_abilities.extend(_parse_id_list_block(fn_slice[r_start + 1 : r_end], consts))
                for ref_m in re.finditer(r"ipairs\s*\(\s*([A-Z0-9_]+)\s*\)|table\.insert\s*\(\s*\w+\s*,\s*([A-Z0-9_]+|\d+)\s*\)", fn_slice):
                    sym = ref_m.group(1) or ref_m.group(2)
                    if sym and sym.isdigit():
                        extra_abilities.append(int(sym))
                    elif sym and sym in consts:
                        val = consts[sym]
                        if isinstance(val, list):
                            extra_abilities.extend(val)
                        elif isinstance(val, int):
                            extra_abilities.append(val)

    passive_mods = []
    mm = re.search(r"\bmods\s*=\s*function", entry_str)
    if mm:
        tail = entry_str[mm.start() :]
        end_m = re.search(r"\n\s*(?:onApply|onRemove|extraAbilities|extraTraits|description|highlights)\s*=", tail)
        fn_slice = tail[: end_m.start()] if end_m else tail
        local_vars = {}
        for lm in re.finditer(r"local\s+(\w+)\s*=\s*([^\r\n]+)", fn_slice):
            local_vars[lm.group(1).strip()] = lm.group(2).strip()

        seen_mods = set()
        for pm in re.finditer(r"\{\s*xi\.mod\.([A-Z0-9_]+)\s*,\s*([^}]+)\}", fn_slice):
            mod_name = pm.group(1).strip()
            mod_val = pm.group(2).strip()
            if mod_name not in seen_mods:
                seen_mods.add(mod_name)
                passive_mods.append(format_mod_scaling(mod_name, mod_val, local_vars))

    spec_traits = resolve_spec_traits(extra_traits, job_key, cname, highlights, cdesc, lua_meta)
    spec_abilities = resolve_spec_abilities(extra_abilities, job_key, ckey, cname, highlights, sql_abils, lua_meta)

    return {
        "id": int(cid) if cid.isdigit() else fallback_idx,
        "key": ckey,
        "name": cname,
        "role": crole,
        "icon": cicon,
        "reqLevel": int(creq) if creq.isdigit() else 10,
        "description": cdesc,
        "highlights": highlights,
        "passiveMods": passive_mods,
        "customAbilities": spec_abilities,
        "customTraits": spec_traits,
        "sourceFile": f"modules/custom/lua/{fpath_name}",
    }


def parse_job_specs(sql_abils: dict | None = None, lua_meta: dict | None = None) -> list[dict]:
    if sql_abils is None:
        sql_abils = parse_sql_custom_abilities()
    if lua_meta is None:
        lua_meta = parse_lua_metadata()

    spec_files = [LUA_DIR / "overlords_job_specs.lua"] + sorted(LUA_DIR.glob("*_specs.lua"))
    seen_files = set()
    jobs_out = {}

    for fpath in spec_files:
        if not fpath.exists() or fpath.name in seen_files:
            continue
        seen_files.add(fpath.name)
        raw = fpath.read_text(encoding="utf-8", errors="replace")
        clean = strip_lua_comments(raw)

        consts = {}
        for cm in re.finditer(r"local\s+([A-Z0-9_]+)\s*=\s*(?:\([^)]+\)\s*or\s*)?(['\"][^'\"]+['\"]|\d+)", clean):
            k, v = cm.group(1), cm.group(2)
            consts[k] = unquote_lua_str(v) if v[0] in ("'", '"') else int(v)
        # Also parse local SHARED_* = { ... } arrays
        for tm in re.finditer(r"local\s+(SHARED_[A-Z0-9_]+)\s*=\s*\{", clean):
            t_start = clean.find("{", tm.start())
            t_end = find_balanced(clean, t_start, "{", "}")
            if t_end != -1:
                consts[tm.group(1)] = _parse_id_list_block(clean[t_start + 1 : t_end], consts)

        for m in re.finditer(r"spec\.registerJob\s*\(\s*[^,]+,\s*['\"]([A-Z]+)['\"]\s*,", clean):
            job_key = m.group(1)
            brace_start = clean.find("{", m.end())
            if brace_start == -1:
                continue
            brace_end = find_balanced(clean, brace_start, "{", "}")
            if brace_end == -1:
                continue
            list_body = clean[brace_start + 1 : brace_end]
            crystals = []
            for entry_str in split_top_level_args(list_body):
                parsed = _parse_crystal_entry(entry_str, consts, job_key, fpath.name, sql_abils, lua_meta, len(crystals) + 1)
                if parsed:
                    crystals.append(parsed)

            jmeta = JOB_META.get(job_key, {"id": 99, "name": job_key, "color": "#60a5fa", "badge": job_key})
            jobs_out[job_key] = {
                "jobKey": job_key,
                "jobId": jmeta["id"],
                "jobName": jmeta["name"],
                "color": jmeta["color"],
                "sourceFile": f"modules/custom/lua/{fpath.name}",
                "crystals": crystals,
            }

        for m in re.finditer(r"spec\.registerCrystal\s*\(\s*xi\.job\.([A-Z]+)\s*,", clean):
            job_key = m.group(1)
            brace_start = clean.find("{", m.end())
            if brace_start == -1:
                continue
            brace_end = find_balanced(clean, brace_start, "{", "}")
            if brace_end == -1:
                continue
            entry_str = clean[brace_start : brace_end + 1]
            if job_key not in jobs_out:
                jmeta = JOB_META.get(job_key, {"id": 99, "name": job_key, "color": "#60a5fa", "badge": job_key})
                jobs_out[job_key] = {
                    "jobKey": job_key,
                    "jobId": jmeta["id"],
                    "jobName": jmeta["name"],
                    "color": jmeta["color"],
                    "sourceFile": f"modules/custom/lua/{fpath.name}",
                    "crystals": [],
                }
            parsed = _parse_crystal_entry(entry_str, consts, job_key, fpath.name, sql_abils, lua_meta, len(jobs_out[job_key]["crystals"]) + 1)
            if parsed:
                # Replace crystal with same key if already registered
                existing = jobs_out[job_key]["crystals"]
                idx = next((i for i, x in enumerate(existing) if x["key"] == parsed["key"]), None)
                if idx is not None:
                    existing[idx] = parsed
                else:
                    existing.append(parsed)
                existing.sort(key=lambda x: x["id"])

    return sorted(jobs_out.values(), key=lambda j: j["jobId"])


# ---------------------------------------------------------------------------
# 2. Companions & Custom Weapons/Items
# ---------------------------------------------------------------------------
def get_companions_and_equipment() -> dict:
    companions = [
        {
            "name": "Eos (Light Pixie)",
            "petId": 128,
            "job": "Scholar (Medic Crystal)",
            "unlock": "Call Eos (Ability #231, Lv.10+)",
            "jobs": "SCH / SMN",
            "role": "Party Healer, Regen Buffer & Debuff Cleanser",
            "summary": "A true server-side pet (not a Trust) that scales deterministically to the Scholar's level. Automatically maintains a custom stackable Eos Regen (status #789, tiers I–V) across the master, party members, and Trusts, and prioritizes removing debuffs with Poisona, Paralyna, Blindna, Silena, Stona, Viruna, Cursna, and Erase.",
            "spells": ["Regen I–V (Stackable)", "Poisona / Paralyna / Blindna / Silena", "Stona / Viruna / Cursna", "Erase"],
            "commands": ["!eos heal (Restores full HP)", "!eos dismiss (Releases companion)"],
            "specialItem": "Orphic Egg (#18256): Repurposed as a SCH-only Ammo item that grants level-scaling Refresh to Eos & Titania.",
            "sourceFile": "modules/custom/cpp/eos_companion.cpp",
        },
        {
            "name": "Titania (Dark Pixie)",
            "petId": 129,
            "job": "Scholar (Sage Crystal)",
            "unlock": "Call Titania (Ability #289, Lv.10+)",
            "jobs": "BLM / RDM",
            "role": "Dark Arts Enfeebler, Drain/Aspir & Elemental Nuker",
            "summary": "A Dark Arts faerie companion summoned at the Scholar's exact level. Automatically locks onto the Scholar's spell target, weakens enemies with enfeebling magic, sustains herself with Drain/Aspir, and casts Tier I–V elemental nukes.",
            "spells": ["Bio I–II / Poison I–II", "Paralyze / Slow / Blind", "Drain / Aspir", "Tier I–V Elemental Nukes"],
            "commands": ["!eos heal (Restores full HP)", "!eos dismiss (Releases companion)"],
            "specialItem": "Orphic Egg (#18256): Grants level-scaling MP Refresh to Titania.",
            "sourceFile": "modules/custom/cpp/eos_companion.cpp",
        },
        {
            "name": "Undead Warrior & Dullahan",
            "petId": "130 / 133",
            "job": "Black Mage (Necromancer Crystal)",
            "unlock": "Summon Undead Warrior (Lv.10+) / Summon Dullahan (Lv.75)",
            "jobs": "WAR / DRK",
            "role": "Frontline Undead Thrall & Physical Cleaver",
            "summary": "Melee undead thralls that hold enmity, activate the Necromancer's Dark Pact (+Double Attack, +Store TP, +Accuracy), receive healing from Harbinger's Drain on every Scythe weaponskill, and execute Grim Reaping on command (or detonate via Corpse Explosion).",
            "spells": ["Grim Reaping (30s CD physical cleave + self-heal)", "Dullahan Bonus: Inflicts Defense Down (-15%)", "Corpse Explosion (45s CD Dark AoE detonation)"],
            "commands": ["Fight / Heel / Stay / Leave", "Grim Reaping (#408)", "Corpse Explosion (#407)"],
            "specialItem": "All Scythes unlocked for BLM with A+ Scythe Skill when Necromancer is socketed.",
            "sourceFile": "modules/custom/lua/blm_specs.lua",
        },
        {
            "name": "Undead Mage & Corse",
            "petId": "131 / 132",
            "job": "Black Mage (Necromancer Crystal)",
            "unlock": "Summon Undead Mage (Lv.10+) / Summon Corse (Lv.75)",
            "jobs": "BLM / DRK (Mage) & BLM / SCH (Corse)",
            "role": "Backline Dark Caster & MP Siphon Thrall",
            "summary": "Caster undead thralls with custom dark/elemental spell lists (601/602). Maintain Dark Pact for the Necromancer and unleash Grim Incantations on command, dealing Dark magic damage while siphoning MP back to the Black Mage.",
            "spells": ["Grim Incantations (30s CD Dark burst + Master MP drain)", "Corse Bonus: +40% DMG & inflicts Magic Defense Down (-15%)", "Corpse Explosion (45s CD Dark AoE detonation)"],
            "commands": ["Fight / Heel / Stay / Leave", "Grim Incantations (#409)", "Corpse Explosion (#407)"],
            "specialItem": "Grim Conversion Trait: Converts BLM's MACC->ACC, MAB->ATT, Fast Cast->Haste, and MB Bonus->WSD.",
            "sourceFile": "modules/custom/lua/blm_specs.lua",
        },
    ]

    chakrams = [
        {"level": 10, "name": "Rogetsurin", "dmg": 16, "delay": 260, "stats": "R.Acc +4, AGI +2", "tier": "Starter"},
        {"level": 20, "name": "Platoon Disc", "dmg": 22, "delay": 260, "stats": "Balanced Lv.20 Throwing Disc", "tier": "Leveling"},
        {"level": 28, "name": "Chakram / Chakram +1", "dmg": "28 / 30", "delay": "260 / 255", "stats": "Classic Dancer Throwing Ring", "tier": "Leveling"},
        {"level": 40, "name": "War Hoop / Jr.Msk. Chakram (+1/+2)", "dmg": "36–42", "delay": "260–250", "stats": "Mid-level Ranged Progression", "tier": "Leveling"},
        {"level": 57, "name": "Moonring Blade / +1", "dmg": "48 / 50", "delay": "255 / 250", "stats": "Late-level Chakram", "tier": "Leveling"},
        {"level": 61, "name": "Death Chakram", "dmg": 53, "delay": 250, "stats": "DEX +3, R.Acc +6", "tier": "Bridge"},
        {"level": 68, "name": "Rising Sun / +1", "dmg": "58 / 60", "delay": "250 / 245", "stats": "Pre-75 High Base Damage", "tier": "Bridge"},
        {"level": 75, "name": "Aureole / Jinx Discus", "dmg": "56 / 58", "delay": "192 / 196", "stats": "Ultra-low delay rapid TP Chakrams", "tier": "Endgame 75"},
        {"level": 75, "name": "Halakaala / Aliyat Chakram", "dmg": "66 / 68", "delay": "250 / 255", "stats": "R.Atk +15, R.Acc +15, Snapshot +5", "tier": "Endgame 75"},
        {"level": 75, "name": "Mamoolbane (Relic)", "dmg": 82, "delay": 270, "stats": "R.Atk +25, R.Acc +25, WSD +15%", "tier": "RMEA 75"},
        {"level": 75, "name": "Lamiabane (Mythic)", "dmg": 76, "delay": 230, "stats": "R.Acc +22, CHR +10, Snapshot +8", "tier": "RMEA 75"},
        {"level": 75, "name": "Trollbane (Empyrean)", "dmg": 80, "delay": 250, "stats": "DEX +12, CHR +12, Crit Dmg +12%", "tier": "RMEA 75"},
        {"level": 75, "name": "Besta's Bane (Aeonic)", "dmg": 85, "delay": 260, "stats": "Store TP +10, R.Acc +20, Skillchain Bonus", "tier": "RMEA 75"},
    ]

    return {
        "companions": companions,
        "dncChakrams": chakrams,
        "customTraits": list(CUSTOM_TRAITS.values()),
    }


# ---------------------------------------------------------------------------
# 3. Parse Weaponskill Catalog & 5-Spec Talent Trees (219 WSs)
# ---------------------------------------------------------------------------
SKILL_NAMES_BY_ENUM = {
    "xi.skill.HAND_TO_HAND": (1, "Hand-to-Hand"),
    "xi.skill.DAGGER": (2, "Dagger"),
    "xi.skill.SWORD": (3, "Sword"),
    "xi.skill.GREAT_SWORD": (4, "Great Sword"),
    "xi.skill.AXE": (5, "Axe"),
    "xi.skill.GREAT_AXE": (6, "Great Axe"),
    "xi.skill.SCYTHE": (7, "Scythe"),
    "xi.skill.POLEARM": (8, "Polearm"),
    "xi.skill.KATANA": (9, "Katana"),
    "xi.skill.GREAT_KATANA": (10, "Great Katana"),
    "xi.skill.CLUB": (11, "Club"),
    "xi.skill.STAFF": (12, "Staff"),
    "xi.skill.ARCHERY": (25, "Archery"),
    "xi.skill.MARKSMANSHIP": (26, "Marksmanship"),
    "xi.skill.THROWING": (27, "Throwing"),
}

SC_BONUS_BY_TIER = {
    1: (5, 10, "Lv1"),
    2: (8, 15, "Lv1"),
    3: (10, 20, "Lv2"),
    4: (15, 28, "Lv3"),
}

# Current tier gates from overlords_ws_talents.lua
TIER_GATES = {
    1: {"reqWsPoints": 0, "reqLevel": 1},
    2: {"reqWsPoints": 2, "reqLevel": 5},
    3: {"reqWsPoints": 5, "reqLevel": 10},
    4: {"reqWsPoints": 8, "reqLevel": 15},
}

RANK_LEVEL_TABLES = {
    "sc": {1: [1, 18], 2: [5, 28], 3: [10, 42], 4: [15, 58]},
    1: {6: [1, 11, 22, 35, 50, 65], 7: [1, 10, 20, 32, 44, 56, 68]},
    2: {5: [5, 18, 32, 48, 64]},
    3: {5: [10, 24, 38, 54, 70]},
    4: {3: [15, 42, 68], 5: [15, 30, 45, 60, 75]},
}

SPEC_CATEGORIES = [
    {"key": "berserker",      "label": "Berserker (WAR)",       "specs": "WAR Berserker"},
    {"key": "commander",      "label": "Commander (WAR)",       "specs": "WAR Commander"},
    {"key": "spartan",        "label": "Spartan (WAR)",         "specs": "WAR Spartan (Polearm & Buckler Phalanx Tank), BRD Minstrel"},
    {"key": "sensei",         "label": "Sensei (MNK)",          "specs": "MNK Sensei (Staff Counter/Parry Tank)"},
    {"key": "blackbelt",      "label": "Black Belt (MNK)",      "specs": "MNK Black Belt (H2H Martial Finisher)"},
    {"key": "chiweaver",      "label": "Chi Weaver (MNK)",      "specs": "MNK Chi Weaver (0-MP Chi Pulse Healer)"},
    {"key": "inquisitor",     "label": "Inquisitor (RUN)",      "specs": "RUN Inquisitor (Runic Parry/Ward Tank)"},
    {"key": "spellblade",     "label": "Spellblade (RUN)",      "specs": "RUN Spellblade (Greatsword Conduction DPS)"},
    {"key": "lifebinder",     "label": "Lifebinder (RUN)",      "specs": "RUN Lifebinder (Runic Healer)"},
    {"key": "medic",          "label": "Medic (SCH)",           "specs": "SCH Medic (Call Eos Companion Healer)"},
    {"key": "sage",           "label": "Sage (SCH)",            "specs": "SCH Sage (Call Titania / Helix Caster), BRD Musician"},
    {"key": "necromancer",    "label": "Necromancer (BLM)",     "specs": "BLM Necromancer (Scythe & Undead Summoner)"},
    {"key": "bladewheel",     "label": "Bladewheel (DNC)",      "specs": "DNC Bladewheel (Chakram & Dagger), BRD Adventurer"},
    {"key": "ronin",          "label": "Ronin (SAM)",           "specs": "SAM Ronin (Great Katana Mushin Tank)"},
    {"key": "imperialarcher", "label": "Imperial Archer (SAM)", "specs": "SAM Imperial Archer (Bow & Great Katana)"},
    {"key": "warlord",        "label": "Warlord (SAM)",         "specs": "SAM Warlord (Great Katana Iaijutsu Support)"},
    {"key": "generic",        "label": "Generic (Unspecced)",   "specs": "Jobs without a Soul Crystal or off-spec weapons"},
]


def parse_ws_catalog() -> dict[int, dict]:
    cat_path = LUA_DIR / "overlords_ws_catalog.lua"
    if not cat_path.exists():
        return {}
    clean = strip_lua_comments(cat_path.read_text(encoding="utf-8", errors="replace"))
    m = re.search(r"catalog\.byId\s*=\s*\{", clean)
    if not m:
        return {}
    start_brace = clean.find("{", m.start())
    end_brace = find_balanced(clean, start_brace, "{", "}")
    body = clean[start_brace + 1 : end_brace]

    ws_by_id = {}
    for entry_m in re.finditer(r"\[(\d+)\]\s*=\s*\{", body):
        ws_id = int(entry_m.group(1))
        e_start = body.find("{", entry_m.start())
        e_end = find_balanced(body, e_start, "{", "}")
        if e_end == -1:
            continue
        ebody = body[e_start + 1 : e_end]

        def get_str(field):
            fm = re.search(rf"\b{field}\s*=\s*(['\"](?:\\.|[^'\"])*['\"])", ebody)
            return unquote_lua_str(fm.group(1)) if fm else ""

        skill_m = re.search(r"\bskill\s*=\s*(xi\.skill\.[A-Z_]+)", ebody)
        skill_enum = skill_m.group(1) if skill_m else ""
        skill_id, skill_label = SKILL_NAMES_BY_ENUM.get(skill_enum, (0, get_str("skillName") or "Unknown"))

        orig = {"ftp": [1.0, 1.0, 1.0], "wsc": {}, "numHits": 1, "skillchain": []}
        om = re.search(r"\borig\s*=\s*\{", ebody)
        if om:
            o_start = ebody.find("{", om.start())
            o_end = find_balanced(ebody, o_start, "{", "}")
            if o_end != -1:
                obody = ebody[o_start + 1 : o_end]
                ftp_m = re.search(r"\bftp\s*=\s*(\{[^}]*\})", obody)
                if ftp_m:
                    orig["ftp"] = parse_number_list(ftp_m.group(1))
                hits_m = re.search(r"\bnumHits\s*=\s*(\d+)", obody)
                if hits_m:
                    orig["numHits"] = int(hits_m.group(1))
                wsc_m = re.search(r"\bwsc\s*=\s*\{([^}]*)\}", obody)
                if wsc_m:
                    for sm in re.finditer(r"(\w+)\s*=\s*([0-9.]+)", wsc_m.group(1)):
                        orig["wsc"][sm.group(1).upper()] = int(round(float(sm.group(2)) * 100))
                sc_m = re.search(r"\bskillchain\s*=\s*\{([^}]*)\}", obody)
                if sc_m:
                    orig["skillchain"] = [
                        unquote_lua_str(x) for x in sc_m.group(1).split(",") if x.strip()
                    ]
                am_m = re.search(r"\baftermath\s*=\s*(['\"][^'\"]+['\"])", obody)
                if am_m:
                    orig["aftermath"] = unquote_lua_str(am_m.group(1))
                deb_m = re.search(r"\bdebuff\s*=\s*\{([^}]*)\}", obody)
                if deb_m:
                    lbl_m = re.search(r"label\s*=\s*(['\"][^'\"]+['\"])", deb_m.group(1))
                    if lbl_m:
                        orig["debuff"] = unquote_lua_str(lbl_m.group(1))

        ws_by_id[ws_id] = {
            "id": ws_id,
            "key": get_str("key"),
            "name": get_str("name"),
            "skillId": skill_id,
            "skillName": get_str("skillName") or skill_label,
            "wsType": get_str("wsType") or "physical",
            "elementName": get_str("elementName") or None,
            "isCustomThrowing": 241 <= ws_id <= 252,
            "orig": orig,
        }

    return ws_by_id


def extract_phys_flags_from_effect(effect_str: str) -> set[str]:
    """Detect physical stat keys inside an effect table so sanitizeNodeForNonPhysical mirrors Lua."""
    flags = set()
    for k in ("atkPct", "acc", "racc", "crit", "critCurve", "critDmg", "defIgnore", "hits", "bonusHits", "multiHitfTPAt"):
        if re.search(rf"\b{k}\b", effect_str):
            flags.add(k)
    return flags


def parse_single_helper_node(call_str: str) -> dict | None:
    call_str = call_str.strip()
    if not call_str:
        return None

    m = re.match(r"^([A-Za-z0-9_.]+)\s*\(", call_str)
    if not m:
        if call_str.startswith("{") and call_str.endswith("}"):
            key_m = re.search(r"\bkey\s*=\s*(['\"][^'\"]+['\"])", call_str)
            name_m = re.search(r"\bname\s*=\s*(['\"][^'\"]+['\"])", call_str)
            tier_m = re.search(r"\btier\s*=\s*(\d+)", call_str)
            col_m = re.search(r"\bcol\s*=\s*(\d+)", call_str)
            mr_m = re.search(r"\bmaxRank\s*=\s*(\d+)", call_str)
            ftp_m = re.search(r"\bftpCurve\s*=\s*(\{[^}]*\})", call_str)
            ret_str = re.search(r"return\s+(['\"][^'\"]+['\"])", call_str)
            curve = parse_number_list(ftp_m.group(1)) if ftp_m else [1.0, 1.5, 2.0]
            desc = (
                unquote_lua_str(ret_str.group(1))
                if ret_str
                else f"fTP 1.0 -> {curve[0]:.2f}/{curve[1]:.2f}/{curve[2]:.2f}"
            )
            return {
                "tier": int(tier_m.group(1)) if tier_m else 1,
                "col": int(col_m.group(1)) if col_m else 1,
                "key": unquote_lua_str(key_m.group(1)) if key_m else "ftp",
                "name": unquote_lua_str(name_m.group(1)) if name_m else "TP Scaling",
                "maxRank": int(mr_m.group(1)) if mr_m else 6,
                "desc": desc,
                "physFlags": extract_phys_flags_from_effect(call_str),
            }
        return None

    fn_name = m.group(1)
    p_start = call_str.find("(", m.start())
    p_end = find_balanced(call_str, p_start, "(", ")")
    if p_end == -1:
        return None
    args = split_top_level_args(call_str[p_start + 1 : p_end])

    if fn_name in ("ftp", "H.ftp", "h2hFtpCurveNode"):
        curve = parse_number_list(args[0]) if args else [1.0, 1.5, 2.0]
        c_str = "/".join(f"{x:.2f}" for x in curve)
        name = "TP Scaling"
        zero_desc = f"Base fTP 1.00 -> Scales up to {c_str}"
        if fn_name == "h2hFtpCurveNode" and len(args) >= 3 and args[2] != "nil":
            name = unquote_lua_str(args[2])
        if len(args) >= 2 and args[1].startswith("{"):
            nm = re.search(r"\bname\s*=\s*(['\"][^'\"]+['\"])", args[1])
            if nm:
                name = unquote_lua_str(nm.group(1))
            zd = re.search(r"\bzeroDesc\s*=\s*(['\"][^'\"]+['\"])", args[1])
            if zd:
                zero_desc = unquote_lua_str(zd.group(1))
        return {
            "tier": 1,
            "col": 1,
            "key": "ftp",
            "name": name,
            "maxRank": 6,
            "desc": zero_desc,
            "physFlags": set(),
        }

    if fn_name in ("utilFtp", "H.utilFtp") and len(args) >= 2:
        eff_str = args[3] if len(args) >= 4 else ""
        return {
            "tier": 1,
            "col": 1,
            "key": "ftp",
            "name": unquote_lua_str(args[0]),
            "maxRank": 6,
            "desc": unquote_lua_str(args[1]),
            "physFlags": extract_phys_flags_from_effect(eff_str),
        }

    if fn_name in ("node", "H.node", "gladStance", "schStance", "warStance", "senseiStance") and len(args) >= 6:
        eff_str = args[7] if len(args) >= 8 else ""
        flags = extract_phys_flags_from_effect(eff_str)
        if fn_name in ("gladStance", "warStance", "senseiStance") and re.search(r"\bstAtk\b|\bstCrit\b", eff_str):
            flags.add("atkPct")
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": int(args[4]),
            "desc": unquote_lua_str(args[5]),
            "physFlags": flags,
        }

    if fn_name == "N" and len(args) >= 7:
        eff_str = args[8] if len(args) >= 9 else ""
        return {
            "tier": int(args[2]),
            "col": int(args[3]),
            "key": unquote_lua_str(args[0]),
            "name": unquote_lua_str(args[1]),
            "maxRank": int(args[4]),
            "desc": unquote_lua_str(args[6]),
            "physFlags": extract_phys_flags_from_effect(eff_str),
        }

    if fn_name == "makeCurveNode" and args:
        tbl = args[0]
        key_m = re.search(r"\bkey\s*=\s*(['\"][^'\"]+['\"])", tbl)
        name_m = re.search(r"\bname\s*=\s*(['\"][^'\"]+['\"])", tbl)
        tier_m = re.search(r"\btier\s*=\s*(\d+)", tbl)
        col_m = re.search(r"\bcol\s*=\s*(\d+)", tbl)
        mr_m = re.search(r"\bmaxRank\s*=\s*(\d+)", tbl)
        zd_m = re.search(r"\bzeroDesc\s*=\s*(['\"](?:\\.|[^'\"])*['\"])", tbl)
        return {
            "tier": int(tier_m.group(1)) if tier_m else 1,
            "col": int(col_m.group(1)) if col_m else 1,
            "key": unquote_lua_str(key_m.group(1)) if key_m else "node",
            "name": unquote_lua_str(name_m.group(1)) if name_m else "Talent",
            "maxRank": int(mr_m.group(1)) if mr_m else 5,
            "desc": unquote_lua_str(zd_m.group(1)) if zd_m else "",
            "physFlags": set(),
        }

    if fn_name in ("atkAcc", "H.atkAcc") and len(args) >= 6:
        atk_s = int(float(args[4]))
        acc_s = int(float(args[5]))
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"+{atk_s}..{atk_s*5}% WS Atk & +{acc_s}..{acc_s*5} Acc",
            "physFlags": {"atkPct", "acc"},
        }

    if fn_name in ("wsdAcc", "H.wsdAcc") and len(args) >= 6:
        wsd_s = int(float(args[4]))
        acc_s = int(float(args[5]))
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"+{wsd_s}..{wsd_s*5}% WSD & +{acc_s}..{acc_s*5} Acc",
            "physFlags": {"acc"},
        }

    if fn_name in ("critMast", "H.critMast") and len(args) >= 6:
        cr_s = int(float(args[4]))
        cd_s = int(float(args[5]))
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"+{cr_s}..{cr_s*5}% Crit Rate & +{cd_s}..{cd_s*5}% Crit Dmg",
            "physFlags": {"crit", "critDmg"},
        }

    if fn_name in ("mabMacc", "H.mabMacc") and len(args) >= 6:
        mab_s = int(float(args[4]))
        macc_s = int(float(args[5]))
        wsd_s = int(float(args[6])) if len(args) >= 7 and args[6] != "nil" else 0
        desc = (
            f"+{mab_s}..{mab_s*5} MAB/MACC & +{wsd_s}..{wsd_s*5}% WSD"
            if wsd_s
            else f"+{mab_s}..{mab_s*5} MAB & +{macc_s}..{macc_s*5} MACC"
        )
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": desc,
            "physFlags": set(),
        }

    if fn_name in ("rangedAtkAcc", "H.rangedAtkAcc") and len(args) >= 6:
        atk_s = int(float(args[4]))
        racc_s = int(float(args[5]))
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"+{atk_s}..{atk_s*5}% R.Atk & +{racc_s}..{racc_s*5} R.Acc",
            "physFlags": {"atkPct", "racc"},
        }

    if fn_name in ("multiFtp", "H.multiFtp") and len(args) >= 5:
        wsd_s = int(float(args[4])) if args[4] != "nil" else 0
        atk_s = int(float(args[5])) if len(args) >= 6 and args[5] != "nil" else 0
        lbl = f"+{wsd_s*4}% WSD" if wsd_s else f"+{atk_s*4}% Atk"
        flags = {"multiHitfTPAt"}
        if atk_s:
            flags.add("atkPct")
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"R1-4: {lbl} | R5: fTP applies to ALL Hits!",
            "physFlags": flags,
        }

    if fn_name in ("elemFollow", "H.elemFollow") and len(args) >= 7:
        dmg_name = unquote_lua_str(args[5])
        pct_s = int(float(args[6]))
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"{dmg_name} elemental follow-up ({pct_s}..{pct_s*5}%)",
            "physFlags": set(),
        }

    if fn_name in ("stance", "stanceNode", "H.stanceNode") and len(args) >= 8:
        stance_lbl = unquote_lua_str(args[5])
        opts_str = args[7]
        zd_m = re.search(r"\bzeroDesc\s*=\s*(['\"](?:\\.|[^'\"])*['\"])", opts_str)
        desc = unquote_lua_str(zd_m.group(1)) if zd_m else f"{stance_lbl}: Active stance bonus"
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": int(args[4]),
            "desc": desc,
            "physFlags": extract_phys_flags_from_effect(opts_str),
        }

    if fn_name in ("hits", "H.hits") and len(args) >= 5:
        seq = [int(x) for x in parse_number_list(args[4])]
        mr = len(seq) if seq else 5
        target_h = seq[-1] if seq else 2
        if len(args) >= 8 and args[7] != "nil":
            desc = unquote_lua_str(args[7])
        else:
            atk_s = int(float(args[5])) if len(args) >= 6 and args[5] != "nil" else 0
            acc_s = int(float(args[6])) if len(args) >= 7 and args[6] != "nil" else 0
            parts = [f"Rebuild 1->{target_h} Hits"]
            if atk_s:
                parts.append(f"+{atk_s}..{atk_s*mr}% Atk")
            if acc_s:
                parts.append(f"+{acc_s}..{acc_s*mr} Acc")
            desc = " & ".join(parts)
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": mr,
            "desc": desc,
            "physFlags": {"hits", "atkPct", "acc"},
        }

    if fn_name in ("echo", "H.echo"):
        key = unquote_lua_str(args[0]) if len(args) >= 1 and args[0] != "nil" else "aftermath_echo"
        name = unquote_lua_str(args[1]) if len(args) >= 2 and args[1] != "nil" else "Relic Echo"
        wsd_s = int(float(args[2])) if len(args) >= 3 and args[2] != "nil" else 5
        tp_s = int(float(args[3])) if len(args) >= 4 and args[3] != "nil" else 60
        return {
            "tier": 3,
            "col": 2,
            "key": key,
            "name": name,
            "maxRank": 5,
            "desc": f"+{wsd_s}..{wsd_s*5}% WSD & +{tp_s}..{tp_s*5} TP Bonus",
            "physFlags": set(),
        }

    if fn_name in ("cap", "H.cap") and len(args) >= 3:
        eff_str = args[4] if len(args) >= 5 else ""
        return {
            "tier": 4,
            "col": 1,
            "key": unquote_lua_str(args[0]) if args[0] != "nil" else "capstone",
            "name": unquote_lua_str(args[1]),
            "maxRank": 3,
            "desc": unquote_lua_str(args[2]),
            "physFlags": extract_phys_flags_from_effect(eff_str),
        }

    if fn_name in ("mast", "H.mast") and len(args) >= 3:
        arg2 = args[2].strip()
        if arg2.isdigit():
            mr = int(arg2)
            desc = unquote_lua_str(args[3]) if len(args) >= 4 else ""
            eff_str = args[5] if len(args) >= 6 else ""
        else:
            mr = 5
            desc = unquote_lua_str(arg2)
            eff_str = args[4] if len(args) >= 5 else ""
        return {
            "tier": 4,
            "col": 2,
            "key": unquote_lua_str(args[0]),
            "name": unquote_lua_str(args[1]),
            "maxRank": mr,
            "desc": desc,
            "physFlags": extract_phys_flags_from_effect(eff_str),
        }

    return None


# ---------------------------------------------------------------------------
# Spec-Tree Expansion (mirrors overlords_ws_tree_helpers.lua 5-spec engine)
# ---------------------------------------------------------------------------
def is_magic_or_utility_ws(ws: dict, archetype: str) -> tuple[bool, str]:
    ws_id = ws["id"]
    ws_type = ws.get("wsType", "physical")
    if ws_type in ("magic", "utility"):
        return True, ws_type
    if ws_id in (39, 45):  # Spirits Within / Atonement
        return True, "utility"
    if archetype == "magic":
        return True, "magic"
    return False, ws_type


def get_default_element(ws: dict) -> str:
    if ws.get("elementName"):
        return ws["elementName"]
    sk = ws.get("skillId", 0)
    if sk == 7:
        return "Dark"
    if sk == 11:
        return "Light"
    if sk == 4:
        return "Ice"
    if sk in (5, 8):
        return "Thunder"
    if sk in (2, 9):
        return "Wind"
    if sk in (3, 10):
        return "Fire"
    return "Light"


def sanitize_node_for_non_physical(node: dict, ws: dict, ws_kind: str) -> dict:
    flags = node.get("physFlags") or set()
    if not flags:
        return node
    nc = copy.deepcopy(node)
    mr = nc.get("maxRank", 5)
    is_util = ws_kind == "utility"
    parts = []
    if is_util:
        if "crit" in flags or "critCurve" in flags or "critDmg" in flags or "hits" in flags or "bonusHits" in flags or "multiHitfTPAt" in flags:
            parts.append(f"+{6}..{6*mr}% Potency")
        if "acc" in flags or "racc" in flags or "defIgnore" in flags:
            parts.append(f"+{8}..{8*mr} MACC")
        if "crit" in flags or "critCurve" in flags or "critDmg" in flags:
            parts.append(f"+{60}..{60*mr} TP Bonus")
        if "hits" in flags or "bonusHits" in flags or "multiHitfTPAt" in flags:
            parts.append(f"+0.35..{0.35*mr:.2f} fTP")
        nc["desc"] = ", ".join(parts) if parts else "+Potency, +MACC & +TP Scaling"
    else:
        if "atkPct" in flags or "defIgnore" in flags:
            parts.append(f"+{8}..{8*mr} MAB")
        if "acc" in flags or "racc" in flags or "defIgnore" in flags:
            parts.append(f"+{8}..{8*mr} MACC")
        if "crit" in flags or "critCurve" in flags or "critDmg" in flags or "hits" in flags or "bonusHits" in flags or "multiHitfTPAt" in flags:
            parts.append(f"+{6}..{6*mr}% WSD")
        if "hits" in flags or "bonusHits" in flags or "multiHitfTPAt" in flags:
            parts.append(f"+0.35..{0.35*mr:.2f} fTP")
        nc["desc"] = ", ".join(parts) if parts else "+MAB, +MACC & +WSD Scaling"
    return nc


def find_grid_node(nodes: list[dict], tier: int, col: int) -> dict | None:
    for n in nodes:
        if n["tier"] == tier and n["col"] == col:
            return copy.deepcopy(n)
    return None


def make_scaling_t1_col1(ws: dict, base_t1_c1: dict | None, is_non_phys: bool, ws_kind: str) -> dict:
    if base_t1_c1 is not None:
        c = copy.deepcopy(base_t1_c1)
        c["tier"], c["col"], c["key"] = 1, 1, "ftp"
        return sanitize_node_for_non_physical(c, ws, ws_kind) if is_non_phys else c
    orig_ftp = ws.get("orig", {}).get("ftp") or [1.25, 2.00, 2.75]
    a = max(1.25, orig_ftp[0] if len(orig_ftp) > 0 else 1.25)
    b = max(1.85, orig_ftp[1] if len(orig_ftp) > 1 else 1.85)
    c = max(2.60, orig_ftp[2] if len(orig_ftp) > 2 else 2.60)
    return {"tier": 1, "col": 1, "key": "ftp", "name": "TP Scaling", "maxRank": 6, "desc": f"Base fTP 1.00 -> Scales up to {a:.2f}/{b:.2f}/{c:.2f}"}


def make_primary_wsc_node(ws: dict, tier: int, col: int, key: str, is_non_phys: bool, pref_stat: str | None) -> dict:
    orig_wsc = ws.get("orig", {}).get("wsc") or {}
    stat = pref_stat
    if stat is None:
        for s in ("STR", "DEX", "VIT", "AGI", "INT", "MND", "CHR"):
            if orig_wsc.get(s, 0) > 0:
                stat = s
                break
    stat = (stat or ("INT" if is_non_phys else "STR")).upper()
    if is_non_phys:
        if ws.get("wsType") == "magic":
            return {"tier": tier, "col": col, "key": key, "name": f"{stat} & Arcane Focus", "maxRank": 7, "desc": f"{stat} +12..85% WSC & +6..42 MACC"}
        return {"tier": tier, "col": col, "key": key, "name": f"{stat} & Potency", "maxRank": 7, "desc": f"{stat} +12..85% WSC & +45..315 TP Bonus"}
    return {"tier": tier, "col": col, "key": key, "name": f"{stat} Precision", "maxRank": 7, "desc": f"{stat} +12..85% WSC & +5..35 Acc"}


def build_tank_spec_nodes(ws: dict, archetype: str, base_nodes: list[dict]) -> list[dict]:
    is_non_phys, ws_kind = is_magic_or_utility_ws(ws, archetype)
    is_mag_dmg = ws.get("wsType") == "magic"
    sk = ws.get("skillId", 0)
    is_sensei = sk in (12, 1, 9, 2)
    is_gladiator = sk in (11, 5, 6)

    t1c1 = make_scaling_t1_col1(ws, find_grid_node(base_nodes, 1, 1), is_non_phys, ws_kind)
    t1c3 = make_primary_wsc_node(ws, 1, 3, "tk_t1_c3", is_non_phys, "VIT")

    if is_sensei:
        c1_t1 = {"tier": 1, "col": 2, "key": "tk_t1_c2", "name": "Sensei Provoke", "maxRank": 7, "desc": "+7..49 Enmity & +2..14% Counter (15s)"}
        c1_t2 = {"tier": 2, "col": 2, "key": "tk_t2_c2", "name": "Evasive Poise", "maxRank": 5, "desc": "Heal 3..15% Max HP & +5..25 EVA (20s)"}
        c1_t3 = {"tier": 3, "col": 2, "key": "tk_t3_c2", "name": "Sweeping Parry", "maxRank": 5, "desc": "+3..15% Parry (20s) & Stoneskin 120..360"}
        c1_t4 = {"tier": 4, "col": 2, "key": "tk_t4_c2", "name": "Grandmaster Guard", "maxRank": 3, "desc": "Phalanx 20..40 (30s) & +12..36% WSD"}
    elif is_gladiator:
        c1_t1 = {"tier": 1, "col": 2, "key": "tk_t1_c2", "name": "Bloodthirsty Taunt", "maxRank": 7, "desc": "+7..49 Enmity & Heal 2..14% Max HP"}
        c1_t2 = {"tier": 2, "col": 2, "key": "tk_t2_c2", "name": "Crimson Shield", "maxRank": 5, "desc": "+4..20% Shield Block (20s) & Stoneskin 120..360"}
        c1_t3 = {"tier": 3, "col": 2, "key": "tk_t3_c2", "name": "Sanguine Leech", "maxRank": 5, "desc": "Drains 12..40% WS dmg as HP & +8..40% WSD"}
        c1_t4 = {"tier": 4, "col": 2, "key": "tk_t4_c2", "name": "Immortal Gladiator", "maxRank": 3, "desc": "Phalanx 20..40 (30s) & Heal 6..18% Max HP"}
    else:
        c1_t1 = {"tier": 1, "col": 2, "key": "tk_t1_c2", "name": "Inquisitor Challenge", "maxRank": 7, "desc": "+7..49 Enmity & Stoneskin 90..330 (45s)"}
        c1_t2 = {"tier": 2, "col": 2, "key": "tk_t2_c2", "name": "Order Ward", "maxRank": 5, "desc": "Heal 3..15% Max HP & +3..15% Parry (20s)"}
        c1_t3 = {"tier": 3, "col": 2, "key": "tk_t3_c2", "name": "Sanctified Phalanx", "maxRank": 5, "desc": "Phalanx 16..36 (30s) & +6..30 Enmity"}
        c1_t4 = {"tier": 4, "col": 2, "key": "tk_t4_c2", "name": "Unbreakable Aegis", "maxRank": 3, "desc": "Stoneskin 250..500 & Heal 6..18% Max HP"}

    c2_t2 = {"tier": 2, "col": 1, "key": "tk_t2_c1", "name": "Suppressing Blow", "maxRank": 5, "desc": "Target -5..25% Atk & -8..40 Acc (45s)"}
    c2_t3 = {"tier": 3, "col": 1, "key": "tk_t3_c1", "name": "Spellbreaker Guard", "maxRank": 5, "desc": "Target -6..30 M.Atk & Drains 60..300 Target TP"}
    c2_t4 = {"tier": 4, "col": 1, "key": "tk_t4_c1", "name": "Bastion Judgment", "maxRank": 3, "desc": "Dispel 1-2, Target Slow 15..25% & +14..42% WSD"}

    if is_mag_dmg:
        c3_t2 = {"tier": 2, "col": 3, "key": "tk_t2_c3", "name": "Tank Stance Synergy", "maxRank": 5, "desc": "Tank Stance: +8..40% WSD & +8..40 MAB"}
        c3_t3 = {"tier": 3, "col": 3, "key": "tk_t3_c3", "name": "Runic Focus", "maxRank": 5, "desc": "+9..45 MAB, +9..45 MACC & +60..300 TP Bonus"}
        c3_t4 = {"tier": 4, "col": 3, "key": "tk_t4_c3", "name": "Vanguard Mastery", "maxRank": 5, "desc": "+7..35% WSD, +8..40 MAB & +6..30 Enmity"}
    elif is_non_phys:
        c3_t2 = {"tier": 2, "col": 3, "key": "tk_t2_c3", "name": "Tank Stance Synergy", "maxRank": 5, "desc": "Tank Stance: +8..40% WSD & +6..30 Enmity"}
        c3_t3 = {"tier": 3, "col": 3, "key": "tk_t3_c3", "name": "Bastion Focus", "maxRank": 5, "desc": "+6..30% WSD, +6..30 Enmity & +60..300 TP Bonus"}
        c3_t4 = {"tier": 4, "col": 3, "key": "tk_t4_c3", "name": "Vanguard Mastery", "maxRank": 5, "desc": "+8..40% WSD, +8..40 Enmity & Heal 3..15% HP"}
    else:
        c3_t2 = {"tier": 2, "col": 3, "key": "tk_t2_c3", "name": "Tank Stance Synergy", "maxRank": 5, "desc": "Tank Stance: +8..40% WSD & +8..40% Atk"}
        c3_t3 = {"tier": 3, "col": 3, "key": "tk_t3_c3", "name": "Vanguard Force", "maxRank": 5, "desc": "+1 Bonus Hit, +8..40% Atk & +8..40 Acc"}
        c3_t4 = {"tier": 4, "col": 3, "key": "tk_t4_c3", "name": "Vanguard Mastery", "maxRank": 5, "desc": "fTP ALL Hits, +6..30% WSD & +6..30 Enmity"}

    return [t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4]


def build_spellblade_spec_nodes(ws: dict, archetype: str, base_nodes: list[dict]) -> list[dict]:
    is_non_phys, ws_kind = is_magic_or_utility_ws(ws, archetype)
    is_mag_dmg = ws.get("wsType") == "magic"
    sk = ws.get("skillId", 0)
    is_ranged = ws.get("wsType") == "ranged"
    acc_lbl = "RAcc" if is_ranged else "Acc"
    ele_name = get_default_element(ws)
    is_necro = sk == 7
    is_sage = sk in (11, 12, 2)

    t1c1 = make_scaling_t1_col1(ws, find_grid_node(base_nodes, 1, 1), is_non_phys, ws_kind)
    t1c3 = make_primary_wsc_node(ws, 1, 3, "sb_t1_c3", is_non_phys, "INT")

    if is_necro:
        c1_t1 = {"tier": 1, "col": 2, "key": "sb_t1_c2", "name": "Harbinger Pact", "maxRank": 7, "desc": "Heals Undead Pet 10..70% HP/MP & +8..56 MAB" if is_mag_dmg else "Heals Undead Pet 10..70% HP/MP & +4..28% WSD"}
        c1_t2 = {"tier": 2, "col": 2, "key": "sb_t2_c2", "name": "Soul Siphon", "maxRank": 5, "desc": "HP Drain 8..40% & MP Drain 5..25% of WS dmg"}
        c1_t3 = {"tier": 3, "col": 2, "key": "sb_t3_c2", "name": "Necrotic Burst", "maxRank": 5, "desc": "Dark follow-up (12..60%)"}
        if is_mag_dmg:
            c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Lich Sovereign", "maxRank": 3, "desc": "Pet Heal 30..90%, +15..45% WSD & +15..45 MAB"}
        elif is_non_phys:
            c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Lich Sovereign", "maxRank": 3, "desc": "Pet Heal 30..90%, +15..45% WSD & +0.4..1.2 fTP"}
        else:
            c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Lich Sovereign", "maxRank": 3, "desc": "Pet Heal 30..90%, +15..45% WSD & 10..30% DEF Ign"}
    elif is_sage:
        c1_t1 = {"tier": 1, "col": 2, "key": "sb_t1_c2", "name": "Titania Covenant", "maxRank": 7, "desc": "Heals Titania/Pet 10..70% & +8..56 MAB" if is_mag_dmg else "Heals Titania/Pet 10..70% & +4..28% WSD"}
        c1_t2 = {"tier": 2, "col": 2, "key": "sb_t2_c2", "name": "Dark Arts Helix", "maxRank": 5, "desc": "MP Drain 6..30% & +9..45 MACC" if is_mag_dmg else "MP Drain 6..30% & +5..25% WSD"}
        c1_t3 = {"tier": 3, "col": 2, "key": "sb_t3_c2", "name": f"{ele_name} Helix Burst", "maxRank": 5, "desc": f"{ele_name} follow-up (12..60%)"}
        if is_mag_dmg:
            c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Sage Overcharge", "maxRank": 3, "desc": "+16..48% WSD, +18..54 MAB & -15..45 Target MEVA"}
        elif is_non_phys:
            c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Sage Overcharge", "maxRank": 3, "desc": "+16..48% WSD, +0.4..1.2 fTP & -15..45 Target MEVA"}
        else:
            c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Sage Overcharge", "maxRank": 3, "desc": "+16..48% WSD, 10..30% DEF Ign & -15..45 Target MEVA"}
    else:
        c1_t1 = {"tier": 1, "col": 2, "key": "sb_t1_c2", "name": "Conduction Edge", "maxRank": 7, "desc": "Grants +1..2 Conduction & +8..56 MAB" if is_mag_dmg else "Grants +1..2 Conduction & +4..28% WSD"}
        c1_t2 = {"tier": 2, "col": 2, "key": "sb_t2_c2", "name": "Runic Siphon", "maxRank": 5, "desc": "MP Drain 6..30% & +9..45 MACC" if is_mag_dmg else "MP Drain 6..30% & +5..25% WSD"}
        c1_t3 = {"tier": 3, "col": 2, "key": "sb_t3_c2", "name": f"{ele_name} Edgeflare", "maxRank": 5, "desc": f"{ele_name} follow-up (12..60%)"}
        c1_t4 = {"tier": 4, "col": 2, "key": "sb_t4_c2", "name": "Ascendant Spellblade", "maxRank": 3, "desc": "+2..3 Conduction, +15..45% WSD & +15..45 MAB" if is_mag_dmg else "+2..3 Conduction, +15..45% WSD & +0.4..1.2 fTP"}

    c2_t2 = {"tier": 2, "col": 1, "key": "sb_t2_c1", "name": "Arcane Breach", "maxRank": 5, "desc": "Target -6..30 M.Def & -8..40 M.Eva (45s)"}
    c2_t3 = {"tier": 3, "col": 1, "key": "sb_t3_c1", "name": "Runic Resonance", "maxRank": 5, "desc": "Runes/DarkArts: +9..45% WSD & +10..50 MAB" if is_mag_dmg else "Runes/DarkArts: +9..45% WSD & +60..300 TP Bonus"}
    c2_t4 = {"tier": 4, "col": 1, "key": "sb_t4_c1", "name": "Elemental Convergence", "maxRank": 3, "desc": "+15..45% SC Dmg & +0.5..1.5 fTP"}
    c3_t2 = {"tier": 2, "col": 3, "key": "sb_t2_c3", "name": "Spellweaver Tempo", "maxRank": 5, "desc": "+70..350 TP Bonus & +6..30% WSD"}

    if is_mag_dmg:
        c3_t3 = {"tier": 3, "col": 3, "key": "sb_t3_c3", "name": "Arcane Amplifier", "maxRank": 5, "desc": "+10..50 MAB, +10..50 MACC & +5..25% WSD"}
        c3_t4 = {"tier": 4, "col": 3, "key": "sb_t4_c3", "name": "Spellblade Mastery", "maxRank": 5, "desc": "+7..35% WSD, +10..50 MAB & +8..40% SC Dmg"}
    elif is_non_phys:
        c3_t3 = {"tier": 3, "col": 3, "key": "sb_t3_c3", "name": "Runic Amplifier", "maxRank": 5, "desc": "+7..35% WSD & +60..300 TP Bonus"}
        c3_t4 = {"tier": 4, "col": 3, "key": "sb_t4_c3", "name": "Spellblade Mastery", "maxRank": 5, "desc": "+7..35% WSD, +60..300 TP Bonus & +8..40% SC Dmg"}
    else:
        c3_t3 = {"tier": 3, "col": 3, "key": "sb_t3_c3", "name": "Enchanted Flurry", "maxRank": 5, "desc": f"+1 Bonus Hit, +5..25% WSD & +8..40 {acc_lbl}"}
        c3_t4 = {"tier": 4, "col": 3, "key": "sb_t4_c3", "name": "Spellblade Mastery", "maxRank": 5, "desc": "+7..35% WSD, +60..300 TP Bonus & +8..40% SC Dmg"}

    return [t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4]


def build_healer_spec_nodes(ws: dict, archetype: str, base_nodes: list[dict]) -> list[dict]:
    is_non_phys, ws_kind = is_magic_or_utility_ws(ws, archetype)
    is_mag_dmg = ws.get("wsType") == "magic"
    t1c1 = make_scaling_t1_col1(ws, find_grid_node(base_nodes, 1, 1), is_non_phys, ws_kind)
    t1c3 = make_primary_wsc_node(ws, 1, 3, "hl_t1_c3", is_non_phys, "MND")

    c1_t1 = {"tier": 1, "col": 2, "key": "hl_t1_c2", "name": "Vivacious Mending", "maxRank": 7, "desc": "Party Heal 3..21% Max HP & Eos/Pet Heal 10..70%"}
    c1_t2 = {"tier": 2, "col": 2, "key": "hl_t2_c2", "name": "Sanctuary Regen", "maxRank": 5, "desc": "Party Regen 12..32/tick (30s) & +6..30% WSD"}
    c1_t3 = {"tier": 3, "col": 2, "key": "hl_t3_c2", "name": "Runic Lifetap", "maxRank": 5, "desc": "MP Drain 8..40% of WS dmg & Party Refresh 3..15/t"}
    c1_t4 = {"tier": 4, "col": 2, "key": "hl_t4_c2", "name": "Lifebinder Benediction", "maxRank": 3, "desc": "Party Heal 10..30% Max HP & +15..45% WSD"}
    c2_t2 = {"tier": 2, "col": 1, "key": "hl_t2_c1", "name": "Pacifying Strike", "maxRank": 5, "desc": "+5..25 Subtle Blow & Target -5..25% Atk (45s)"}
    c2_t3 = {"tier": 3, "col": 1, "key": "hl_t3_c1", "name": "Solace Harmony", "maxRank": 5, "desc": "LightArts/Valiance: +9..45% WSD & +10..50 MAB" if is_mag_dmg else "LightArts/Valiance: +9..45% WSD & +60..300 TP Bonus"}
    c2_t4 = {"tier": 4, "col": 1, "key": "hl_t4_c1", "name": "Sanctified Ward", "maxRank": 3, "desc": "Stoneskin 250..500 & Party +80..240 TP"}
    c3_t2 = {"tier": 2, "col": 3, "key": "hl_t2_c3", "name": "Luminous Pulse", "maxRank": 5, "desc": "Light follow-up (11..55%)"}
    c3_t3 = {"tier": 3, "col": 3, "key": "hl_t3_c3", "name": "Mending Tempo", "maxRank": 5, "desc": "+70..350 TP Bonus & Target -6..30 M.Atk (45s)"}
    c3_t4 = {"tier": 4, "col": 3, "key": "hl_t4_c3", "name": "Healer Mastery", "maxRank": 5, "desc": "+7..35% WSD, +8..40 MACC & -4..20 Enmity" if is_mag_dmg else "+7..35% WSD, Party Heal 2..10% & -4..20 Enmity"}
    return [t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4]


def build_commander_spec_nodes(ws: dict, archetype: str, base_nodes: list[dict]) -> list[dict]:
    is_non_phys, ws_kind = is_magic_or_utility_ws(ws, archetype)
    is_mag_dmg = ws.get("wsType") == "magic"
    t1c1 = make_scaling_t1_col1(ws, find_grid_node(base_nodes, 1, 1), is_non_phys, ws_kind)
    t1c3 = make_primary_wsc_node(ws, 1, 3, "cm_t1_c3", is_non_phys, None)

    c1_t1 = {"tier": 1, "col": 2, "key": "cm_t1_c2", "name": "Rallying Cadence", "maxRank": 7, "desc": "Party +35..245 TP & NextWS +4..28% WSD (15s)"}
    c1_t2 = {"tier": 2, "col": 2, "key": "cm_t2_c2", "name": "Banner of War", "maxRank": 5, "desc": "Party Warcry (+6..30% Atk, 25s) & +5..25% WSD"}
    c1_t3 = {"tier": 3, "col": 2, "key": "cm_t3_c2", "name": "Tactical Haste", "maxRank": 5, "desc": "Party Haste +4..20% (25s) & +60..300 TP Bonus"}
    c1_t4 = {"tier": 4, "col": 2, "key": "cm_t4_c2", "name": "Supreme Commander", "maxRank": 3, "desc": "Party +100..300 TP, +15..45% WSD & +12..36% SC Dmg"}
    c2_t2 = {"tier": 2, "col": 1, "key": "cm_t2_c1", "name": "Sunder Formation", "maxRank": 5, "desc": "Target -5..25% DEF & -6..30 M.Def (45s)"}

    if is_mag_dmg:
        c2_t3 = {"tier": 3, "col": 1, "key": "cm_t3_c1", "name": "Command Presence", "maxRank": 5, "desc": "Command Stance: +9..45% WSD & +10..50 MAB"}
        c3_t2 = {"tier": 2, "col": 3, "key": "cm_t2_c3", "name": "Arcane Volley", "maxRank": 5, "desc": "+9..45 MAB & +9..45 MACC"}
        c3_t3 = {"tier": 3, "col": 3, "key": "cm_t3_c3", "name": "Resonant Chain", "maxRank": 5, "desc": "+8..40% SC Dmg & +0.25..1.25 fTP"}
    elif is_non_phys:
        c2_t3 = {"tier": 3, "col": 1, "key": "cm_t3_c1", "name": "Command Presence", "maxRank": 5, "desc": "Command Stance: +9..45% WSD & +60..300 TP"}
        c3_t2 = {"tier": 2, "col": 3, "key": "cm_t2_c3", "name": "Tactical Volley", "maxRank": 5, "desc": "+6..30% WSD & Party +40..200 TP"}
        c3_t3 = {"tier": 3, "col": 3, "key": "cm_t3_c3", "name": "Resonant Chain", "maxRank": 5, "desc": "+8..40% SC Dmg & +0.25..1.25 fTP"}
    else:
        c2_t3 = {"tier": 3, "col": 1, "key": "cm_t3_c1", "name": "Command Presence", "maxRank": 5, "desc": "Command Stance: +9..45% WSD & +8..40% Atk"}
        c3_t2 = {"tier": 2, "col": 3, "key": "cm_t2_c3", "name": "Vanguard Strike", "maxRank": 5, "desc": "+9..45% WS Atk & +9..45 Acc"}
        c3_t3 = {"tier": 3, "col": 3, "key": "cm_t3_c3", "name": "Coordinated Assault", "maxRank": 5, "desc": "+1 Bonus Hit & +8..40% SC Dmg"}

    c2_t4 = {"tier": 4, "col": 1, "key": "cm_t4_c1", "name": "Exposed Flank", "maxRank": 3, "desc": "Target -15..45 EVA/MEVA & NextWS +120..360 TP"}
    c3_t4 = {"tier": 4, "col": 3, "key": "cm_t4_c3", "name": "Commander Mastery", "maxRank": 5, "desc": "+7..35% WSD & Party +5..25% Crit (20s)"}
    return [t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4]


def build_berserker_spec_nodes(ws: dict, archetype: str, base_nodes: list[dict]) -> list[dict]:
    is_non_phys, ws_kind = is_magic_or_utility_ws(ws, archetype)
    is_mag_dmg = ws.get("wsType") == "magic"
    out = []
    grid = {1: {}, 2: {}, 3: {}, 4: {}}

    for raw in base_nodes:
        n = copy.deepcopy(raw)
        if is_non_phys:
            n = sanitize_node_for_non_physical(n, ws, ws_kind)
        t, c = n["tier"], n["col"]
        if t in grid and c not in grid[t]:
            grid[t][c] = n
            out.append(n)

    if 1 not in grid[1]:
        n = make_scaling_t1_col1(ws, None, is_non_phys, ws_kind)
        grid[1][1] = n
        out.append(n)
    if 2 not in grid[1]:
        if is_mag_dmg:
            n = {"tier": 1, "col": 2, "key": "zk_t1_c2", "name": "Arcane Surge", "maxRank": 7, "desc": "+8..56 MAB & +7..49 MACC"}
        elif is_non_phys:
            n = {"tier": 1, "col": 2, "key": "zk_t1_c2", "name": "Resonant Surge", "maxRank": 7, "desc": "+5..35% WSD & +45..315 TP Bonus"}
        else:
            n = {"tier": 1, "col": 2, "key": "zk_t1_c2", "name": "Fury Opener", "maxRank": 7, "desc": "+7..49% WS Atk & +4..28% WSD"}
        grid[1][2] = n
        out.append(n)
    if 3 not in grid[1]:
        n = make_primary_wsc_node(ws, 1, 3, "zk_t1_c3", is_non_phys, None)
        grid[1][3] = n
        out.append(n)

    if 3 not in grid[2]:
        if is_mag_dmg:
            n = {"tier": 2, "col": 3, "key": "zk_t2_c3", "name": "Overwhelming Arcana", "maxRank": 5, "desc": "+9..45 MAB, +5..25% WSD & +50..250 TP Bonus"}
        elif is_non_phys:
            n = {"tier": 2, "col": 3, "key": "zk_t2_c3", "name": "Overwhelming Force", "maxRank": 5, "desc": "+7..35% WSD & +60..300 TP Bonus"}
        else:
            n = {"tier": 2, "col": 3, "key": "zk_t2_c3", "name": "Armor Sundering", "maxRank": 5, "desc": "Ignores 6..30% DEF & +5..25% WSD"}
        grid[2][3] = n
        out.append(n)

    if 3 not in grid[3]:
        ele_name = get_default_element(ws)
        if is_non_phys:
            n = {"tier": 3, "col": 3, "key": "zk_t3_c3", "name": f"{ele_name} Detonation", "maxRank": 5, "desc": f"{ele_name} elemental follow-up (12..60%)"}
        else:
            n = {"tier": 3, "col": 3, "key": "zk_t3_c3", "name": "Bloodbath Momentum", "maxRank": 5, "desc": "+5..25% Crit, +6..30% Crit Dmg & 5..25% HP Drain"}
        grid[3][3] = n
        out.append(n)

    if 3 not in grid[4]:
        if is_non_phys:
            n = {"tier": 4, "col": 3, "key": "zk_t4_c3", "name": "Cataclysmic Apex", "maxRank": 5, "desc": "+0.3..1.5 fTP, +7..35% WSD & +8..40% SC Dmg"}
        else:
            n = {"tier": 4, "col": 3, "key": "zk_t4_c3", "name": "Berserker Apex", "maxRank": 5, "desc": "+1 Bonus Hit, fTP ALL Hits & +6..30% WSD"}
        grid[4][3] = n
        out.append(n)

    return out


def finalize_spec_nodes(raw_nodes: list[dict]) -> list[dict]:
    nodes = [copy.deepcopy({k: v for k, v in n.items() if k != "physFlags"}) for n in raw_nodes]
    for sc_tier in range(1, 5):
        b1, b2, sc_lvl = SC_BONUS_BY_TIER[sc_tier]
        nodes.append(
            {
                "tier": sc_tier,
                "col": 4,
                "key": f"sc_t{sc_tier}",
                "name": f"SC T{sc_tier} ({sc_lvl})",
                "maxRank": 2,
                "isSkillchain": True,
                "desc": f"Player-selectable {sc_lvl} Skillchain property (+{b1}/{b2}% SC Dmg)",
            }
        )
    nodes.sort(key=lambda n: (n["tier"], n["col"]))
    return nodes


def parse_ws_trees(ws_by_id: dict[int, dict]) -> list[dict]:
    tree_files = [LUA_DIR / "overlords_ws_talents.lua"] + sorted(LUA_DIR.glob("overlords_ws_trees_*.lua"))
    # Map ws_id -> {"mode": "reg"|"regB"|"regSpec"|"throwing", "archetype": str, "baseNodes": [...], "specNodes": {...}, "sourceFile": str}
    trees_by_ws_id = {}

    for fpath in tree_files:
        if not fpath.exists():
            continue
        clean = strip_lua_comments(fpath.read_text(encoding="utf-8", errors="replace"))
        src_rel = f"modules/custom/lua/{fpath.name}"

        # Capture local zerkXX = { ... } blocks (used by regGS in overlords_ws_trees_gs.lua)
        local_node_lists = {}
        for lm in re.finditer(r"local\s+(zerk\d+)\s*=\s*\{", clean):
            var_name = lm.group(1)
            b_start = clean.find("{", lm.start())
            b_end = find_balanced(clean, b_start, "{", "}")
            if b_end != -1:
                calls = split_top_level_args(clean[b_start + 1 : b_end])
                local_node_lists[var_name] = [pn for nc in calls if (pn := parse_single_helper_node(nc))]

        # 1. regGS(wsId, archetype, zerkN)
        for m in re.finditer(r"\bregGS\s*\(\s*(\d+)\s*,\s*['\"]([^'\"]+)['\"]\s*,\s*(zerk\d+)\s*(?:,|\))", clean):
            ws_id = int(m.group(1))
            archetype = m.group(2)
            var_name = m.group(3)
            trees_by_ws_id[ws_id] = {
                "mode": "reg",
                "archetype": archetype,
                "baseNodes": local_node_lists.get(var_name, []),
                "sourceFile": src_rel,
            }

        # 2. reg / H.reg / regB / H.regBaseline
        for m in re.finditer(r"\b(reg|regB|H\.reg|H\.regBaseline)\s*\(\s*(\d+)\s*,\s*['\"]([^'\"]+)['\"]\s*,", clean):
            fn_used = m.group(1)
            ws_id = int(m.group(2))
            archetype = m.group(3)
            b_start = clean.find("{", m.end())
            if b_start == -1:
                continue
            b_end = find_balanced(clean, b_start, "{", "}")
            if b_end == -1:
                continue
            node_calls = split_top_level_args(clean[b_start + 1 : b_end])
            parsed_nodes = [pn for nc in node_calls if (pn := parse_single_helper_node(nc))]
            mode = "regB" if fn_used in ("regB", "H.regBaseline") else "reg"
            if fpath.name == "overlords_ws_trees_throwing.lua":
                mode = "throwing"
            trees_by_ws_id[ws_id] = {
                "mode": mode,
                "archetype": archetype,
                "baseNodes": parsed_nodes,
                "sourceFile": src_rel,
            }

        # 3. registerCustomH2H(wsId, { archetype = '...', nodes = { ... } })
        for m in re.finditer(r"\bregisterCustomH2H\s*\(\s*(\d+)\s*,", clean):
            ws_id = int(m.group(1))
            b_start = clean.find("{", m.end())
            if b_start == -1:
                continue
            b_end = find_balanced(clean, b_start, "{", "}")
            if b_end == -1:
                continue
            spec_body = clean[b_start + 1 : b_end]
            arch_m = re.search(r"\barchetype\s*=\s*['\"]([^'\"]+)['\"]", spec_body)
            archetype = arch_m.group(1) if arch_m else "heavy"
            nm = re.search(r"\bnodes\s*=\s*\{", spec_body)
            if not nm:
                continue
            n_start = spec_body.find("{", nm.start())
            n_end = find_balanced(spec_body, n_start, "{", "}")
            node_calls = split_top_level_args(spec_body[n_start + 1 : n_end])
            parsed_nodes = [pn for nc in node_calls if (pn := parse_single_helper_node(nc))]
            trees_by_ws_id[ws_id] = {
                "mode": "reg",
                "archetype": archetype,
                "baseNodes": parsed_nodes,
                "sourceFile": src_rel,
            }

    out_list = []
    for ws_id in sorted(ws_by_id.keys()):
        ws = ws_by_id[ws_id]
        tinfo = trees_by_ws_id.get(
            ws_id,
            {"mode": "reg", "archetype": ws["wsType"], "baseNodes": [], "sourceFile": "modules/custom/lua/overlords_ws_talents.lua"},
        )
        archetype = tinfo["archetype"]
        base_nodes = tinfo["baseNodes"]
        mode = tinfo["mode"]
        is_non_phys, ws_kind = is_magic_or_utility_ws(ws, archetype)

        if mode == "throwing":
            cleaned = [sanitize_node_for_non_physical(n, ws, ws_kind) if is_non_phys else n for n in base_nodes]
            final_nodes = finalize_spec_nodes(cleaned)
            spec_trees = {"bladewheel": final_nodes}
        else:
            tank_nodes = build_tank_spec_nodes(ws, archetype, base_nodes)
            heal_nodes = build_healer_spec_nodes(ws, archetype, base_nodes)
            sb_nodes = build_spellblade_spec_nodes(ws, archetype, base_nodes)
            cmd_nodes = build_commander_spec_nodes(ws, archetype, base_nodes)
            zerk_nodes = build_berserker_spec_nodes(ws, archetype, base_nodes)

            if mode == "regB":
                # Inject Club/Staff Col 1 (Tank), Col 2 (Healer/Spellblade), Col 3 (Commander) into Col 1 of each spec
                def inject_col1(target_list, bespoke_col):
                    for tier in range(1, 5):
                        b_node = find_grid_node(base_nodes, tier, bespoke_col)
                        if b_node is not None:
                            b_node["tier"] = tier
                            b_node["col"] = 1
                            for idx, tn in enumerate(target_list):
                                if tn["tier"] == tier and tn["col"] == 1:
                                    target_list[idx] = b_node
                                    break

                inject_col1(tank_nodes, 1)
                inject_col1(heal_nodes, 2)
                inject_col1(sb_nodes, 2)
                inject_col1(cmd_nodes, 3)

            spec_map_raw = {
                "berserker": zerk_nodes,
                "tank": tank_nodes,
                "spellblade": sb_nodes,
                "healer": heal_nodes,
                "commander": cmd_nodes,
            }
            spec_trees = {}
            for s_key, s_nodes in spec_map_raw.items():
                cleaned = [sanitize_node_for_non_physical(n, ws, ws_kind) if is_non_phys else n for n in s_nodes]
                spec_trees[s_key] = finalize_spec_nodes(cleaned)

            final_nodes = spec_trees["berserker"]

        ws_entry = {
            **ws,
            "archetype": archetype,
            "sourceFile": tinfo["sourceFile"],
            "isSpecAdaptive": mode != "throwing",
            "maxPoints": sum(n["maxRank"] for n in final_nodes),
            "specTrees": spec_trees,
        }
        out_list.append(ws_entry)

    return out_list


# ---------------------------------------------------------------------------
# 4. Parse Server Combat, EXP, QoL & Progression Rules
# ---------------------------------------------------------------------------
def parse_server_rules() -> dict:
    boss_path = LUA_DIR / "boss_like_combat_and_exp.lua"
    header_features = []
    if boss_path.exists():
        raw = boss_path.read_text(encoding="utf-8", errors="replace")
        in_header = False
        cur_item = []
        for line in raw.splitlines()[:35]:
            if line.startswith("-- Features:"):
                in_header = True
                continue
            if in_header:
                if line.startswith("-----------------------------------"):
                    break
                stripped = re.sub(r"^--\s*", "", line).strip()
                m_num = re.match(r"^(\d+)\.\s+(.*)", stripped)
                if m_num:
                    if cur_item:
                        header_features.append(" ".join(cur_item))
                    cur_item = [m_num.group(2)]
                elif stripped and cur_item:
                    cur_item.append(stripped)
        if cur_item:
            header_features.append(" ".join(cur_item))

    return {
        "levelCap": 75,
        "qolUnlocks": "Level 99 QoL (80-slot Mog Safe 2/Sack/Case/Wardrobes 1-8, 5 Trusts via all 9 Rhapsodies KIs, all 22 Jobs unlocked, auto-capped skills)",
        "talentPointsPerLevel": 3,
        "maxPointsAt75": 225,
        "pointsPerMaxedWS": 56,
        "crystalUnlockLevel": 10,
        "wsUnlockRule": "All Weaponskills are visible from Level 1, and each WS is unlocked for use as soon as you invest at least 1 Talent Point into Tier 1 of that WS.",
        "tierGates": TIER_GATES,
        "rankLevelTables": RANK_LEVEL_TABLES,
        "specCategories": SPEC_CATEGORIES,
        "features": header_features,
        "baselinePlayerPace": [
            {"stat": "Baseline Haste", "value": "+25% (+15% Gear + 10% Ability)", "desc": "Brisk combat speed right from Level 1 without needing endgame Haste gear first."},
            {"stat": "Baseline Store TP", "value": "+25", "desc": "Faster TP generation on every melee and ranged swing."},
            {"stat": "Combat Regain", "value": "20 TP / tick", "desc": "Passive TP regeneration while engaged in battle."},
            {"stat": "Baseline Fast Cast", "value": "+15%", "desc": "Snappier spell casting and shorter recasts across all jobs."},
        ],
        "petCombatPace": [
            {"stat": "Pet Haste", "value": "+15% Magic Haste", "desc": "Applied automatically to all player pets, avatars, automatons, and companions."},
            {"stat": "Pet Store TP", "value": "+25", "desc": "Faster pet TP generation."},
            {"stat": "Pet Regain", "value": "15 TP / tick", "desc": "Continuous pet TP regeneration."},
        ],
        "mobScaling": {
            "normalLv25": "+45% HP, +22% ATT, +25% DEF, +22 ACC, +14 EVA, +18 MDEF/MEVA, +18% Haste",
            "normalLv75": "+96% HP, +47% ATT, +53% DEF, +47 ACC, +30 EVA, +38 MDEF/MEVA, +25% Haste",
            "nmBonus": "Notorious Monsters scale higher (+75% base HP, +32% ATT, +38% DEF, +50 Regain/Store TP, up to +30% Haste)",
            "levelGap": "dLvl <= 1: 1.0x | dLvl 2..7 (Tough -> IT+): soloable with a strong spec | dLvl >= 8 (IT++ Wall): steep mitigation & high threat",
        },
        "levelGapTable": [
            {"diff": "dLvl <= +1 (Even Match / Low Tough)", "playerDmg": "100%", "mobDmg": "100%", "note": "Standard solo / small-group pace"},
            {"diff": "dLvl +2 (Tough)", "playerDmg": "94%", "mobDmg": "108%", "note": "Noticeably sturdier"},
            {"diff": "dLvl +3 (Tough / VT)", "playerDmg": "88%", "mobDmg": "116%", "note": "Good EXP chain target"},
            {"diff": "dLvl +4 (Very Tough)", "playerDmg": "80%", "mobDmg": "126%", "note": "Requires active Spec & Talent build"},
            {"diff": "dLvl +5 (Incredibly Tough)", "playerDmg": "72%", "mobDmg": "138%", "note": "Boss-like solo duel"},
            {"diff": "dLvl +6 (IT+)", "playerDmg": "63%", "mobDmg": "152%", "note": "High threat; cooldowns & sustain needed"},
            {"diff": "dLvl +7 (High IT+)", "playerDmg": "54%", "mobDmg": "168%", "note": "Peak soloable challenge"},
            {"diff": "dLvl >= +8 (IT++ Wall)", "playerDmg": "30% -> 12%", "mobDmg": "215% -> 320%", "note": "Hard wall (+90 ACC/MACC, +75 EVA/MEVA)"},
        ],
        "qolCards": [
            {"title": "All 22 Jobs Unlocked on Login", "desc": "Every standard job from Warrior to Rune Fencer and Geomancer is unlocked immediately at character creation."},
            {"title": "80-Slot Wardrobes 1–8 & Bags", "desc": "Inventory, Mog Safe 1 & 2, Storage, Locker, Satchel, Sack, Case, and all 8 Mog Wardrobes are expanded to 80 slots automatically."},
            {"title": "5 Trusts & All 9 Rhapsodies KIs", "desc": "All 9 Rhapsodies of Vana'diel key items are granted on login, allowing up to 5 Trusts in a party immediately."},
            {"title": "29-Item BiS Lv.1 Starter Kit & 263-Weapon Shop", "desc": "New characters receive a 29-item BiS Lv.1 Starter Kit automatically and can open the 6-page Lv.1 Weapons Shop anywhere via !weapons."},
            {"title": "Auto-Capped Combat & Magic Skills", "desc": "Weapon, defense, and magic skills automatically cap for your level so you can swap weapons and specs freely without skill-up grinding."},
            {"title": "Anti-One-Shot Breath & Suicide Normalization", "desc": "Bomb Toss, Self-Destruct, Mijin Gakure, and HP-scaled breaths are capped to fair percentages of target Max HP."},
        ],
    }


# ---------------------------------------------------------------------------
# 5. Parse Custom Player Commands, Engine Patches & Git Commits
# ---------------------------------------------------------------------------
def find_lua_binary() -> str | None:
    for cand in ("lua5.3", "lua5.4", "luajit", "lua"):
        path = shutil.which(cand)
        if path:
            return path
    return None


def parse_sql_custom_abilities() -> dict[int, dict]:
    """Dynamically parse INSERT INTO abilities from all modules/custom/sql/*.sql files."""
    abils = {}
    for sql_file in sorted(SQL_DIR.glob("*.sql")):
        txt = sql_file.read_text(encoding="utf-8", errors="replace")
        # Extract any header/inline SQL summary comments for single ability IDs (exclude ranges like (432-437))
        sql_comments = {}
        for cm in re.finditer(r"^\s*--\s*(?:-\s*)?([A-Za-z0-9' &:.-]+?)\s*\((\d{3,4})(?!\s*[-–])[^)\r\n]*\)\s*(?::\s*([^\r\n]+)|\[([^\]]+)\])?", txt, re.MULTILINE):
            cid = int(cm.group(2))
            cname = cm.group(1).strip()
            cdetail = (cm.group(3) or "").strip()
            if "Abilities" in cname or "Custom" in cname:
                continue
            sql_comments[cid] = (cname, cdetail)

        for m in re.finditer(
            r"\(\s*(\d+)\s*,\s*'([^']+)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*([0-9.]+)\s*,\s*(\d+)\s*,\s*(\d+)",
            txt,
        ):
            aid = int(m.group(1))
            raw_name = m.group(2)
            recast = int(m.group(6))
            rng = float(m.group(8))
            is_aoe = int(m.group(9))
            radius = int(m.group(10))
            valid_target = int(m.group(5))
            if is_aoe and radius > 0:
                target_lbl = f"Party ({radius}y AoE)" if valid_target in (1, 3) else f"AoE ({radius}y)"
            elif valid_target == 4:
                target_lbl = f"Enemy ({int(rng)}y)" if rng > 0 else "Enemy"
            elif valid_target == 3:
                target_lbl = f"Ally ({int(rng)}y)" if rng > 0 else "Ally"
            else:
                target_lbl = "Self"
            comment_name, comment_detail = sql_comments.get(aid, ("", ""))
            display_name = comment_name if comment_name else _clean_ident_name(raw_name.upper())
            abils[aid] = {
                "id": aid,
                "name": display_name,
                "cd": f"{recast}s",
                "target": target_lbl,
                "sqlDesc": comment_detail,
                "desc": comment_detail or f"Custom Job Ability ({recast}s recast, {target_lbl}).",
            }
    return abils


def format_evaluated_mod(mod_code: str, values: list) -> dict:
    label, unit, mult = MOD_LABELS.get(mod_code, (mod_code.replace("_", " ").title(), "", 1))

    def fmt_num(v: float) -> str:
        val = float(v) * mult
        sign = "+" if val > 0 else ""
        if abs(val - round(val)) < 1e-6:
            return f"{sign}{int(round(val))}"
        return f"{sign}{val:.1f}"

    clean_vals = [v for v in values if isinstance(v, (int, float))]
    if not clean_vals:
        return {"mod": mod_code, "label": label, "value": "-", "bracket": "Passive"}

    if len(set(clean_vals)) == 1:
        return {"mod": mod_code, "label": label, "value": f"{fmt_num(clean_vals[0])}{unit}", "bracket": "Always Active"}

    # Check if Lv 75 differs from Lv 50
    if len(clean_vals) >= 4 and clean_vals[3] == clean_vals[2]:
        val_str = f"{fmt_num(clean_vals[0])} / {fmt_num(clean_vals[1])} / {fmt_num(clean_vals[2])}{unit}"
        return {"mod": mod_code, "label": label, "value": val_str, "bracket": "Lv.10 / 30 / 50+"}

    val_str = " / ".join(fmt_num(v) for v in clean_vals) + unit
    return {"mod": mod_code, "label": label, "value": val_str, "bracket": "Lv.10 / 30 / 50 / 70+"}


def run_lua_exporter(lua_bin: str) -> dict | None:
    """Execute scripts/export_lua_wiki_data.lua via real Lua for 100% ground-truth data."""
    exporter = ROOT_DIR / "scripts" / "export_lua_wiki_data.lua"
    if not exporter.exists():
        return None
    spec_mods = [f"modules/custom/lua/{p.stem}" for p in sorted(LUA_DIR.glob("*_specs.lua"))]
    tree_mods = [f"modules/custom/lua/{p.stem}" for p in sorted(LUA_DIR.glob("overlords_ws_trees_*.lua"))]
    cmd = [lua_bin, str(exporter), str(ROOT_DIR)] + spec_mods + tree_mods
    try:
        res = subprocess.run(
            cmd,
            cwd=str(ROOT_DIR),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        if res.returncode != 0:
            print(f"[warn] Lua exporter exited {res.returncode}: {res.stderr.strip()}")
            return None
        return json.loads(res.stdout)
    except Exception as exc:
        print(f"[warn] Lua exporter failed ({exc}), falling back to Python parser.")
        return None


def parse_spec_guides() -> dict[str, dict]:
    """Parse docs/guides/<spec_key>.md files into structured Playstyle Guides for the Wiki."""
    guides = {}
    if not GUIDES_DIR.exists():
        return guides

    def clean_md_item(line: str) -> str:
        s = re.sub(r"^\s*(?:[-*]|\d+\.)\s+", "", line.strip())
        return s.strip()

    for md_file in sorted(GUIDES_DIR.glob("*.md")):
        if md_file.stem.lower() == "readme":
            continue
        ckey = md_file.stem.lower()
        raw = md_file.read_text(encoding="utf-8", errors="replace")
        sections = {}
        current = None
        for line in raw.splitlines():
            hm = re.match(r"^##\s+(.+)$", line.strip())
            if hm:
                current = hm.group(1).strip().lower()
                sections[current] = []
            elif current is not None:
                sections[current].append(line)

        def collect_items(key_prefixes: tuple[str, ...]) -> list[str]:
            items = []
            for sk, lines in sections.items():
                if any(sk.startswith(p) for p in key_prefixes):
                    for ln in lines:
                        st = ln.strip()
                        if not st:
                            continue
                        if re.match(r"^(?:[-*]|\d+\.)\s+", st):
                            items.append(clean_md_item(st))
                        elif items:
                            items[-1] = f"{items[-1]} {st}"
                        else:
                            items.append(st)
            return items

        at_a_glance = " ".join(
            ln.strip()
            for sk, lines in sections.items()
            if sk.startswith("at a glance")
            for ln in lines
            if ln.strip()
        )
        setup = collect_items(("setup", "gear", "requirements"))
        loop = collect_items(("how to play", "core loop", "gameplay loop", "rotation"))
        mechanics = collect_items(("key mechanics", "mechanics", "stacks", "stances"))
        tips = collect_items(("common mistakes", "tips", "watch out", "avoid"))

        guides[ckey] = {
            "atAGlance": at_a_glance,
            "setup": setup,
            "loop": loop,
            "mechanics": mechanics,
            "tips": tips,
            "hasHandwrittenGuide": True,
            "sourceFile": f"docs/guides/{md_file.name}",
        }
    return guides


def build_fallback_guide(job: dict, crystal: dict) -> dict:
    """Automatic plain-English fallback guide when docs/guides/<spec_key>.md is not yet written."""
    desc = crystal.get("description", "")
    hls = crystal.get("highlights", [])
    abils = crystal.get("customAbilities", [])
    loop = [f"**Core Abilities:** {', '.join(a['name'] + ' (' + a['cd'] + ')' for a in abils[:4])}"] if abils else []
    mechanics = [h for h in hls if not re.match(r"^Passives?\s*\(", h, flags=re.IGNORECASE)][:4]
    return {
        "atAGlance": desc,
        "setup": [f"Socket `{crystal.get('name', '')}` via `!spec set {crystal.get('key', '')}` at Lv.{crystal.get('reqLevel', 10)}+."],
        "loop": loop,
        "mechanics": mechanics,
        "tips": [],
        "hasHandwrittenGuide": False,
    }


def parse_commands() -> list[dict]:
    """Dynamically scan modules/custom/commands/*.lua + boss_like_combat_and_exp.lua."""
    known_summaries = {
        "spec": "Interactive Job Crystal / Soul Spec selector menu, CLI inspector, and Ashita v4 [OXSPEC] sync.",
        "talent": "Spec-adaptive Weaponskill Talent Tree builder (4 Tiers, 56 pts per WS, Tier-1 WS unlock, Skillchain selector) & Ashita v4 0x1FD binary /talents UI bridge.",
        "gear": "Auto-grants and equips a full 16-slot level-appropriate gear loadout tailored to your Job, active Crystal Spec, Role, and Weapon.",
        "eos": "Controls Scholar's Eos (Medic) or Titania (Sage) faerie companion.",
    }
    cmds = []
    for cfile in sorted(CMD_DIR.glob("*.lua")):
        raw = cfile.read_text(encoding="utf-8", errors="replace")
        func_m = re.search(r"--\s*func:\s*(.+)", raw)
        desc_m = re.search(r"--\s*desc:\s*(.+)", raw)
        cmd_name = func_m.group(1).strip() if func_m else cfile.stem
        summary = known_summaries.get(cmd_name, desc_m.group(1).strip() if desc_m else f"Custom !{cmd_name} command.")

        usages = []
        for um in re.finditer(r"Usage:\s*([^'\"]+)", raw):
            for part in um.group(1).split("|"):
                p = part.strip()
                if p and p not in usages:
                    usages.append(p)
        if not usages:
            usages = [f"!{cmd_name}"]

        cmds.append(
            {
                "command": f"!{cmd_name}",
                "sourceFile": f"modules/custom/commands/{cfile.name}",
                "summary": summary,
                "usage": usages,
            }
        )

    # Also include inline commands from boss_like_combat_and_exp.lua
    cmds.append(
        {
            "command": "!weapons / !starterkit / !combat",
            "sourceFile": "modules/custom/lua/boss_like_combat_and_exp.lua",
            "summary": "Opens the 263-weapon Lv.1 Starter Shop anywhere, re-grants the 29-item BiS Lv.1 Starter Kit, or inspects combat scaling.",
            "usage": [
                "!weapons (or !startershop)",
                "!starterkit",
                "!combat",
                "!bossstance",
            ],
        }
    )
    return cmds


def parse_patches() -> list[dict]:
    readme_text = (ROOT_DIR / "README.md").read_text(encoding="utf-8", errors="replace") if (ROOT_DIR / "README.md").exists() else ""
    desc_map = {}
    for m in re.finditer(r"-\s*`patches/([^`]+\.patch)`\s*(.+)", readme_text):
        desc_map[m.group(1).strip()] = m.group(2).strip()

    extra_descriptions = {
        "0013-throwing-weaponskills.patch": "Registers the 12 custom Dancer Throwing weaponskills (#241–#252) in data/weapon_skills.yaml.",
        "0014-auto-ranged-attack.patch": "Enables automatic ranged attacks while engaged when a ranged spec (such as DNC Bladewheel) is active.",
        "0015-dnc-ranged-dances.patch": "Allows Steps and Flourishes to execute at ranged distances up to 20 yalms when Bladewheel is socketed.",
        "0016-eos-jugpet-spells-and-skills.patch": "Configures deterministic spell lists and AI casting cooldowns for Eos and Titania faerie pets.",
        "0017-blm-necromancer-pets.patch": "Configures custom Undead Warrior, Undead Mage, Corse, and Dullahan pet IDs (130–133) for BLM Necromancer.",
        "0018-search-job-labels.patch": "Streams active OverlordsXI Soul Crystal spec labels in `/search` and party search results.",
        "0019-talent-ws-unlocks.patch": "Gates Weaponskill usage until at least 1 Tier-1 Talent Point is invested and adds the `0x1FD` (`OXTL`) binary packet for instant Ashita `/talents` UI syncing.",
        "0020-aoe-healing-affect-pets.patch": "Allows custom party AoE healing abilities (such as RUN Lifebinder's Sanctified Ward) to affect pets and avatars.",
        "0021-mnk-chiweaver-ranged-chi.patch": "Enables unarmed ranged Chi bolt auto-attacks (0–20y), custom effects 829–830, and party/pet AoE reach for MNK Chi Weaver.",
        "0022-run-overcharge-effect.patch": "Registers RUN Spellblade Overcharge Runes custom effect ID 831 cleanly and raises MAX_EFFECTID to 832.",
        "0023-brd-spec-effects.patch": "Raises MAX_EFFECTID to 840 and registers BRD spec status effects 832–836.",
        "0024-sam-spec-effects.patch": "Raises MAX_EFFECTID to 848 and registers SAM spec status effects 837–841 (ronin_stagger, imp_drawn_oisoya, imp_cosmic_brand, warlord_noto, warlord_ashura).",
        "0025-bst-alpha-warden.patch": "Implements Alpha Warden pet enmity forwarding, Master/Pet damage split hooks, and shared recast reduction helpers.",
        "0025-pld-spec-effects.patch": "Adds PLD Aegis Sentinel/Retribution status effects and Shield Mastery interception hooks.",
        "0026-drk-spec-effects.patch": "Registers DRK Dreadnought spec status effects for Blood Tithe and Dread Bastion.",
        "0026-nin-kagemusha-spec.patch": "Implements NIN Kagemusha shadow-break hooks, Kawarimi Ash triggers, and custom spec effects.",
        "0027-blu-spec-effects.patch": "Registers BLU Azure Carapace spec status effects for Azure Surge and Bastion affinity buffs.",
        "0027-rdm-crimson-duelist.patch": "Adds RDM Crimson Duelist riposte, Flow weaving, and hex-mitigation C++ engine hooks.",
        "0028-healer-spec-effects.patch": "Registers status effect IDs for the WHM Bishop, PLD Martyr, BLU Magus, DNC Reveler, SMN Celestial, PUP Mechanist, GEO Arborist, and DRG Lifescale healer crystals.",
        "0029-shared-ox-status-slots.patch": "Allocates reusable shared OverlordsXI buff and debuff status effect slots (Breach, Cripple, etc.) across all Crystal Specs.",
        "0030-polearm-buckler-equip.patch": "Allows Warrior Spartan crystal holders to equip Polearms alongside Size-1 Buckler shields.",
        "0031-reduce-recasts-binding.patch": "Exposes player:reduceRecasts(seconds) Lua binding for spec abilities that shave ally cooldowns.",
        "0032-cor-gambler-effects.patch": "Adds Corsair Gambler ability-only recast reduction (reduceAbilityRecasts) and Lucky/Roll XI hook support.",
        "0033-blu-set-spell-binding.patch": "Exposes getBlueMagicSlots Lua bindings so BLU Crystal Specs can grant bonus Blue Magic set points and slots.",
        "0033-talent-packet-dispatch.patch": "Handles crystal socket change packet dispatch and instant Weaponskill talent sync updates.",
        "0034-talent-ws-gating.patch": "Enforces Tier-1 Weaponskill Talent gating cleanly in C++ battleutils when inspecting unlocked WSs.",
        "0035-rng-huntsman-pets.patch": "Configures custom Huntsman pet IDs and subjobs (Wild Raaz, Stalker Raptor, Cehuetzi, Gabbrath) in petutils.cpp for exact-level scaling.",
    }
    desc_map.update({k: v for k, v in extra_descriptions.items() if k not in desc_map})

    patches = []
    for pfile in sorted(PATCH_DIR.glob("*.patch")):
        raw = pfile.read_text(encoding="utf-8", errors="replace")
        touched_files = sorted(set(re.findall(r"^\+\+\+\s+b/(.+)$", raw, flags=re.MULTILINE)))
        added = sum(1 for ln in raw.splitlines() if ln.startswith("+") and not ln.startswith("+++"))
        removed = sum(1 for ln in raw.splitlines() if ln.startswith("-") and not ln.startswith("---"))
        num_m = re.match(r"^(\d+)-(.+)\.patch$", pfile.name)
        num_str = num_m.group(1) if num_m else ""
        slug = num_m.group(2).replace("-", " ").title() if num_m else pfile.stem
        desc = desc_map.get(pfile.name)
        if not desc:
            commit_msg = run_git(["log", "-n", "1", "--format=%s", "--", f"patches/{pfile.name}"])
            desc = commit_msg if commit_msg else f"Engine patch modifying {', '.join(touched_files)}."

        patches.append(
            {
                "number": num_str,
                "filename": pfile.name,
                "title": slug,
                "description": desc,
                "files": touched_files,
                "linesAdded": added,
                "linesRemoved": removed,
            }
        )
    return patches


def parse_git_commits(limit: int = 50) -> list[dict]:
    log_raw = run_git(
        [
            "log",
            f"-n{limit}",
            "--date=iso-strict",
            "--pretty=format:COMMIT_START%n%H%n%h%n%an%n%ad%n%s",
            "--numstat",
        ]
    )
    if not log_raw:
        return []

    commits = []
    blocks = log_raw.split("COMMIT_START\n")
    for blk in blocks:
        blk = blk.strip()
        if not blk:
            continue
        lines = blk.splitlines()
        if len(lines) < 5:
            continue
        full_hash, short_hash, author, date_iso, subject = lines[0], lines[1], lines[2], lines[3], lines[4]
        files = []
        total_add = 0
        total_del = 0
        for fline in lines[5:]:
            parts = fline.split("\t")
            if len(parts) == 3:
                a_str, d_str, fname = parts
                if fname.startswith("logs/"):
                    continue
                a_val = int(a_str) if a_str.isdigit() else 0
                d_val = int(d_str) if d_str.isdigit() else 0
                total_add += a_val
                total_del += d_val
                files.append({"path": fname, "added": a_val, "removed": d_val})

        commits.append(
            {
                "hash": full_hash,
                "shortHash": short_hash,
                "author": author,
                "date": date_iso,
                "subject": subject,
                "files": files,
                "totalAdded": total_add,
                "totalRemoved": total_del,
            }
        )
    return commits


def main():
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    sql_abils = parse_sql_custom_abilities()
    lua_meta = parse_lua_metadata()
    lua_bin = find_lua_binary()
    lua_data = run_lua_exporter(lua_bin) if lua_bin else None

    if lua_data:
        print(f"Using real Lua runtime ({lua_bin}) for exact module evaluation.")
        jobs = []
        for j in lua_data.get("jobSpecs", []):
            jkey = j["jobKey"]
            crystals_out = []
            for c in j.get("crystals", []):
                ckey = c["key"]
                cname = c["name"]
                highlights = c.get("highlights", [])
                cdesc = c.get("description", "")
                passive_mods = [format_evaluated_mod(m["mod"], m["values"]) for m in c.get("evaluatedMods", [])]

                spec_abilities = resolve_spec_abilities(
                    c.get("extraAbilities", []), jkey, ckey, cname, highlights, sql_abils, lua_meta
                )
                spec_traits = resolve_spec_traits(
                    c.get("extraTraits", []), jkey, cname, highlights, cdesc, lua_meta
                )

                crystals_out.append(
                    {
                        "id": c["id"],
                        "key": ckey,
                        "name": cname,
                        "role": c["role"],
                        "icon": c["icon"],
                        "reqLevel": c["reqLevel"],
                        "description": cdesc,
                        "highlights": highlights,
                        "passiveMods": passive_mods,
                        "customAbilities": spec_abilities,
                        "customTraits": spec_traits,
                    }
                )
            jobs.append(
                {
                    "jobKey": jkey,
                    "jobId": j["jobId"],
                    "jobName": j["jobName"],
                    "color": j["color"],
                    "crystals": crystals_out,
                }
            )

        ws_trees = lua_data.get("weaponskills", [])
        rules = parse_server_rules()
        if lua_data.get("tierGates"):
            rules["tierGates"] = {int(k): v for k, v in lua_data["tierGates"].items()}
        if lua_data.get("rankLevelTables"):
            rules["rankLevelTables"] = lua_data["rankLevelTables"]
        if lua_data.get("maxWsPoints"):
            rules["pointsPerMaxedWS"] = lua_data["maxWsPoints"]
        # Update combat pace dynamically from live boss_like_combat_and_exp.lua config if exported
        b_cfg = lua_data.get("bossConfig", {})
        if b_cfg.get("playerCombatPace"):
            pace_map = {x["mod"]: x["amount"] for x in b_cfg["playerCombatPace"]}
            haste_g = pace_map.get("HASTE_GEAR", 1500) / 100
            haste_a = pace_map.get("HASTE_ABILITY", 1000) / 100
            stp = pace_map.get("STORETP", 25)
            reg = pace_map.get("REGAIN", 20)
            fc = pace_map.get("FASTCAST", 15)
            rules["baselinePlayerPace"] = [
                {"stat": "Baseline Haste", "value": f"+{int(haste_g + haste_a)}% (+{int(haste_g)}% Gear + {int(haste_a)}% Ability)", "desc": "Brisk combat speed right from Level 1 without needing endgame Haste gear first."},
                {"stat": "Baseline Store TP", "value": f"+{stp}", "desc": "Faster TP generation on every melee and ranged swing."},
                {"stat": "Combat Regain", "value": f"{reg} TP / tick", "desc": "Passive TP regeneration while engaged in battle."},
                {"stat": "Baseline Fast Cast", "value": f"+{fc}%", "desc": "Snappier spell casting and shorter recasts across all jobs."},
            ]
    else:
        print("Lua runtime not found locally; using Python Lua parser fallback.")
        jobs = parse_job_specs(sql_abils=sql_abils, lua_meta=lua_meta)
        ws_catalog = parse_ws_catalog()
        ws_trees = parse_ws_trees(ws_catalog)
        rules = parse_server_rules()

    wiki_extras = get_companions_and_equipment()
    guides_map = parse_spec_guides()
    # Attach Playstyle Guide + dynamically populate all resolved custom job traits
    all_traits_by_id = {ct["id"]: copy.deepcopy(ct) for ct in CUSTOM_TRAITS.values()}
    for j in jobs:
        for c in j.get("crystals", []):
            ckey = c.get("key", "")
            c["guide"] = guides_map.get(ckey) or build_fallback_guide(j, c)
            for t in c.get("customTraits", []):
                tid = t.get("id")
                if isinstance(tid, int) and tid >= 140 and tid not in all_traits_by_id:
                    all_traits_by_id[tid] = t
    wiki_extras["customTraits"] = [all_traits_by_id[k] for k in sorted(all_traits_by_id)]
    commands = parse_commands()
    patches = parse_patches()
    commits = parse_git_commits(60)

    head_hash = run_git(["rev-parse", "--short", "HEAD"]) or "latest"
    branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"]) or "main"

    total_custom_jas = sum(len(c.get("customAbilities", [])) for j in jobs for c in j["crystals"])

    data = {
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "repo": "Infomatictek/overlordsxi",
        "launcherRepo": "Infomatictek/overlordsxi-launcher",
        "branch": branch,
        "headCommit": head_hash,
        "stats": {
            "totalJobsWithSpecs": len(jobs),
            "totalCrystalSpecs": sum(len(j["crystals"]) for j in jobs),
            "totalCustomAbilities": total_custom_jas,
            "totalCustomTraits": len(wiki_extras["customTraits"]),
            "totalCompanions": len(wiki_extras["companions"]),
            "totalWeaponskills": len(ws_trees),
            "totalWeaponSkillsCategories": len(set(w["skillName"] for w in ws_trees)),
            "totalPatches": len(patches),
            "totalRecentCommits": len(commits),
        },
        "serverRules": rules,
        "jobSpecs": jobs,
        "companions": wiki_extras["companions"],
        "dncChakrams": wiki_extras["dncChakrams"],
        "customTraits": wiki_extras["customTraits"],
        "weaponskills": ws_trees,
        "commands": commands,
        "patches": patches,
        "commits": commits,
    }

    json_path = SITE_DIR / "data.json"
    js_path = SITE_DIR / "data.js"

    json_text = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    json_path.write_text(json_text, encoding="utf-8")
    js_path.write_text(f"window.OVERLORDS_DATA = {json_text};\n", encoding="utf-8")

    print(
        f"Generated {json_path.relative_to(ROOT_DIR)} and {js_path.relative_to(ROOT_DIR)}: "
        f"{data['stats']['totalCrystalSpecs']} Crystal Specs ({total_custom_jas} Custom JAs, {data['stats']['totalCustomTraits']} Traits), "
        f"{data['stats']['totalWeaponskills']} Weaponskill Trees (5-spec adaptive), "
        f"{data['stats']['totalPatches']} Engine Patches, "
        f"{data['stats']['totalRecentCommits']} Git Commits."
    )


if __name__ == "__main__":
    main()
