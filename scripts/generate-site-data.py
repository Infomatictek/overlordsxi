#!/usr/bin/env python3
"""
OverlordsXI Wiki & Database Generator
-------------------------------------
Parses all custom OverlordsXI Lua modules, Weaponskill Catalog & Talent Trees,
Job Crystal Specs, Custom Job Abilities & Traits, Companions & Summons,
Combat/QoL Rules, Player Commands, Engine Patches, and Git Commit History
directly from the repository and emits:
  - site/data.json
  - site/data.js (window.OVERLORDS_DATA = ...)

Runs automatically via GitHub Actions on every push (or locally via `python scripts/generate-site-data.py`).
"""

import datetime
import json
import re
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
LUA_DIR = ROOT_DIR / "modules" / "custom" / "lua"
CMD_DIR = ROOT_DIR / "modules" / "custom" / "commands"
SQL_DIR = ROOT_DIR / "modules" / "custom" / "sql"
CPP_DIR = ROOT_DIR / "modules" / "custom" / "cpp"
PATCH_DIR = ROOT_DIR / "patches"
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
    "EVA": ("Evasion", "", 1),
    "EVA_PERCENT": ("Evasion Rate", "%", 1),
    "EVASION": ("Evasion Skill", "", 1),
    "PARRY": ("Parry Skill", "", 1),
    "INQUARTATA": ("Parry Rate", "%", 1),
    "COUNTER": ("Counter Rate", "%", 1),
    "COUNTER_DAMAGE": ("Counter Damage", "%", 1),
    "STORETP": ("Store TP", "", 1),
    "DOUBLE_ATTACK": ("Double Attack", "%", 1),
    "ALL_WSDMG_ALL_HITS": ("Weaponskill Damage", "%", 1),
    "DMG": ("Damage Taken", "%", 0.01),
    "ENMITY": ("Enmity", "", 1),
    "ENMITY_LOSS_REDUCTION": ("Enmity Retention", "%", 1),
    "CURE_POTENCY": ("Cure Potency", "%", 1),
    "CURE_POTENCY_RCVD": ("Cure Potency Received", "%", 1),
    "FASTCAST": ("Fast Cast", "%", 1),
    "SNAPSHOT": ("Snapshot", "%", 1),
    "REFRESH": ("Refresh", "/tick", 1),
    "REGEN_MULTIPLIER": ("Regen Potency", "%", 1),
    "REGEN_DURATION": ("Regen Duration", "s", 1),
    "OCCULT_ACUMEN": ("Occult Acumen", "", 1),
    "SHIELD": ("Shield Skill", "", 1),
    "SHIELD_DEF_BONUS": ("Shield Defense Bonus", "", 1),
    "PALISADE_BLOCK_BONUS": ("Shield Block Rate", "%", 1),
    "SHIELD_MASTERY_TP": ("Shield Mastery TP", "", 1),
    "CLUB": ("Club Skill", "", 1),
    "STAFF": ("Staff Skill", "", 1),
    "GREAT_SWORD": ("Great Sword Skill", "", 1),
    "SCYTHE": ("Scythe Skill", "", 1),
    "ENHANCING": ("Enhancing Magic Skill", "", 1),
    "DIVINE": ("Divine Magic Skill", "", 1),
    "HEALING": ("Healing Magic Skill", "", 1),
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

    # Check `scaleTier(lvl, a, b, c, d)`
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
            bracket = "Lv.10 / 30 / 50+"
            return {"mod": mod_code, "label": label, "value": tiers_str, "bracket": bracket}
        elif len(nums) >= 4:
            tiers_str = f"{fmt_num(nums[0])} / {fmt_num(nums[1])} / {fmt_num(nums[2])} / {fmt_num(nums[3])}{unit}"
            bracket = "Lv.10 / 30 / 50 / 70+"
            return {"mod": mod_code, "label": label, "value": tiers_str, "bracket": bracket}

    # Check formula like `math.max(10, math.floor(lvl * 0.95))`
    if "lvl * 0.95" in resolved:
        return {"mod": mod_code, "label": label, "value": "+10 -> +71 (Rank A+)", "bracket": "Scales w/ Level"}

    # Check plain number
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
    142: {"id": 142, "displayId": 1678, "name": "Gladiator's Bastion", "job": "WAR", "crystal": "Gladiator", "desc": "Grants Shield Mastery, Bloodthirsty Club & Shield self-leech, and heavy damage mitigation."},
    143: {"id": 143, "displayId": 1679, "name": "Sensei's Flow", "job": "MNK", "crystal": "Sensei", "desc": "Mastery of Staff deflection: parrying and evading restore HP/TP, build enmity, and riposte."},
    144: {"id": 144, "displayId": 1680, "name": "Medic's Grace", "job": "SCH", "crystal": "Medic", "desc": "Unlocks Call Eos, 2-hour Addendum: White, HP-free 2x Sublimation, and free 10y Accession on Cure/Regen."},
    145: {"id": 145, "displayId": 1681, "name": "Sage's Wisdom", "job": "SCH", "crystal": "Sage", "desc": "Unlocks Call Titania, 2-hour Addendum: Black, permanent Ebullience, and +50% 2-hour Helix spells."},
    146: {"id": 146, "displayId": 1682, "name": "Bladewheel Mastery", "job": "DNC", "crystal": "Bladewheel", "desc": "Enables ranged Chakram auto-attacks, 20y Steps/Flourishes/Sambas, and 12 custom Throwing weaponskills."},
    147: {"id": 147, "displayId": 1683, "name": "Harbinger's Drain", "job": "BLM", "crystal": "Necromancer", "desc": "Weaponskill damage heals your active Undead summon and fuels Dark magic synergy."},
    148: {"id": 148, "displayId": 1684, "name": "Dark Pact", "job": "BLM", "crystal": "Necromancer", "desc": "While an Undead thrall is active, grants scaling Double Attack, Store TP, and Accuracy."},
    149: {"id": 149, "displayId": 1685, "name": "Grim Conversion", "job": "BLM", "crystal": "Necromancer", "desc": "Converts Magic Accuracy -> Accuracy, MAB -> Attack, Fast Cast -> Haste, and MB Bonus -> WSD."},
    150: {"id": 150, "displayId": 1686, "name": "Inquisitor's Ward", "job": "RUN", "crystal": "Inquisitor", "desc": "3-Rune Mastery at Lv.10+, non-consuming Runes, Runic Riposte on Parry, and dual Tank Stances."},
    151: {"id": 151, "displayId": 1687, "name": "Runic Brand", "job": "RUN", "crystal": "Spellblade", "desc": "3-Rune Mastery at Lv.10+, elemental discharges on every swing/WS, and Mono/Tri-Rune Resonance."},
    152: {"id": 152, "displayId": 1688, "name": "Sacred Pulse", "job": "RUN", "crystal": "Lifebinder", "desc": "3-Rune Mastery at Lv.10+, 15s CD AoE Vivacious Pulse with Rune boons, Runic Lifetap, and AoE Regen."},
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
    ("WAR", "gladiator"): [
        {"id": 402, "name": "Crimson Crush", "cd": "20s", "target": "Enemy (4y)", "desc": "Requires Club + Shield. High-enmity blunt strike that drains 4/6/8/10% Max HP (doubled during Blood Rage or Mighty Strikes)."},
        {"id": 403, "name": "Vanguard Ward", "cd": "30s", "target": "Self", "desc": "12s bastion: +12/18/25/35% Shield Block Rate, -8/10/12/15% Damage Taken, and +20/30/40/50 Enmity."},
    ],
    ("MNK", "sensei"): [
        {"id": 61, "name": "Iron Counterstance", "cd": "120s", "target": "Self", "desc": "Unlocked early at Lv.10 on a 120s recast: +30% Counter Rate, +20 Counter DMG, -10% Damage Taken, +20 Enmity, with ZERO Defense penalty."},
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
}


def parse_job_specs() -> list[dict]:
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
        for cm in re.finditer(r"local\s+([A-Z0-9_]+)\s*=\s*(['\"][^'\"]+['\"]|\d+)", clean):
            k, v = cm.group(1), cm.group(2)
            consts[k] = unquote_lua_str(v) if v[0] in ("'", '"') else int(v)

        for m in re.finditer(r"spec\.registerJob\s*\(\s*[^,]+,\s*['\"]([A-Z]+)['\"]\s*,", clean):
            job_key = m.group(1)
            brace_start = clean.find("{", m.end())
            if brace_start == -1:
                continue
            brace_end = find_balanced(clean, brace_start, "{", "}")
            if brace_end == -1:
                continue
            list_body = clean[brace_start + 1 : brace_end]
            entries_raw = split_top_level_args(list_body)

            crystals = []
            for entry_str in entries_raw:
                entry_str = entry_str.strip()
                if not entry_str.startswith("{"):
                    continue

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

                # Parse passive mods inside mods = function(...)
                passive_mods = []
                mm = re.search(r"\bmods\s*=\s*function", entry_str)
                if mm:
                    fn_slice = entry_str[mm.start() :]
                    local_vars = {}
                    for lm in re.finditer(r"local\s+(\w+)\s*=\s*([^\r\n]+)", fn_slice):
                        local_vars[lm.group(1).strip()] = lm.group(2).strip()

                    ret_m = re.search(r"return\s*\{", fn_slice)
                    if ret_m:
                        r_start = fn_slice.find("{", ret_m.start())
                        r_end = find_balanced(fn_slice, r_start, "{", "}")
                        if r_end != -1:
                            r_body = fn_slice[r_start + 1 : r_end]
                            for mod_item in split_top_level_args(r_body):
                                mod_item = mod_item.strip()
                                if mod_item.startswith("{") and mod_item.endswith("}"):
                                    inner = mod_item[1:-1].strip()
                                    kv = split_top_level_args(inner)
                                    if len(kv) >= 2:
                                        mod_name = kv[0].replace("xi.mod.", "").strip()
                                        mod_val = kv[1].strip()
                                        passive_mods.append(format_mod_scaling(mod_name, mod_val, local_vars))

                # Resolve custom traits for this spec
                spec_traits = [
                    t for t in CUSTOM_TRAITS.values() if t["job"] == job_key and t["crystal"].lower() == cname.lower()
                ]
                spec_abilities = CUSTOM_ABILITIES_BY_SPEC.get((job_key, ckey), [])

                crystals.append(
                    {
                        "id": int(cid) if cid.isdigit() else len(crystals) + 1,
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
                        "sourceFile": f"modules/custom/lua/{fpath.name}",
                    }
                )

            jmeta = JOB_META.get(job_key, {"id": 99, "name": job_key, "color": "#60a5fa", "badge": job_key})
            jobs_out[job_key] = {
                "jobKey": job_key,
                "jobId": jmeta["id"],
                "jobName": jmeta["name"],
                "color": jmeta["color"],
                "sourceFile": f"modules/custom/lua/{fpath.name}",
                "crystals": crystals,
            }

    return sorted(jobs_out.values(), key=lambda j: j["jobId"])


# ---------------------------------------------------------------------------
# 2. Parse Companions & Custom Weapons/Items (Wiki Encyclopedia Section)
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
# 3. Parse Weaponskill Catalog & Bespoke Talent Trees (219 WSs)
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

TIER_GATES = {
    1: {"reqWsPoints": 0, "reqLevel": 1},
    2: {"reqWsPoints": 10, "reqLevel": 20},
    3: {"reqWsPoints": 22, "reqLevel": 42},
    4: {"reqWsPoints": 35, "reqLevel": 62},
}


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
        }

    if fn_name in ("utilFtp", "H.utilFtp") and len(args) >= 2:
        return {
            "tier": 1,
            "col": 1,
            "key": "ftp",
            "name": unquote_lua_str(args[0]),
            "maxRank": 6,
            "desc": unquote_lua_str(args[1]),
        }

    if fn_name in ("node", "H.node") and len(args) >= 6:
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": int(args[4]),
            "desc": unquote_lua_str(args[5]),
        }

    if fn_name == "N" and len(args) >= 7:
        return {
            "tier": int(args[2]),
            "col": int(args[3]),
            "key": unquote_lua_str(args[0]),
            "name": unquote_lua_str(args[1]),
            "maxRank": int(args[4]),
            "desc": unquote_lua_str(args[6]),
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
        }

    if fn_name in ("multiFtp", "H.multiFtp") and len(args) >= 5:
        wsd_s = int(float(args[4])) if args[4] != "nil" else 0
        atk_s = int(float(args[5])) if len(args) >= 6 and args[5] != "nil" else 0
        lbl = f"+{wsd_s*4}% WSD" if wsd_s else f"+{atk_s*4}% Atk"
        return {
            "tier": int(args[0]),
            "col": int(args[1]),
            "key": unquote_lua_str(args[2]),
            "name": unquote_lua_str(args[3]),
            "maxRank": 5,
            "desc": f"R1-4: {lbl} | R5: fTP applies to ALL Hits!",
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
        }

    if fn_name in ("cap", "H.cap") and len(args) >= 3:
        return {
            "tier": 4,
            "col": 1,
            "key": unquote_lua_str(args[0]) if args[0] != "nil" else "capstone",
            "name": unquote_lua_str(args[1]),
            "maxRank": 3,
            "desc": unquote_lua_str(args[2]),
        }

    if fn_name in ("mast", "H.mast") and len(args) >= 3:
        arg2 = args[2].strip()
        if arg2.isdigit():
            mr = int(arg2)
            desc = unquote_lua_str(args[3]) if len(args) >= 4 else ""
        else:
            mr = 5
            desc = unquote_lua_str(arg2)
        return {
            "tier": 4,
            "col": 2,
            "key": unquote_lua_str(args[0]),
            "name": unquote_lua_str(args[1]),
            "maxRank": mr,
            "desc": desc,
        }

    return None


def parse_ws_trees(ws_by_id: dict[int, dict]) -> list[dict]:
    tree_files = [LUA_DIR / "overlords_ws_talents.lua"] + sorted(LUA_DIR.glob("overlords_ws_trees_*.lua"))
    trees_by_ws_id = {}

    for fpath in tree_files:
        if not fpath.exists():
            continue
        clean = strip_lua_comments(fpath.read_text(encoding="utf-8", errors="replace"))

        for m in re.finditer(r"\b(?:reg|regB|H\.reg|H\.regBaseline)\s*\(\s*(\d+)\s*,\s*['\"]([^'\"]+)['\"]\s*,", clean):
            ws_id = int(m.group(1))
            archetype = m.group(2)
            b_start = clean.find("{", m.end())
            if b_start == -1:
                continue
            b_end = find_balanced(clean, b_start, "{", "}")
            if b_end == -1:
                continue
            nodes_body = clean[b_start + 1 : b_end]
            node_calls = split_top_level_args(nodes_body)
            parsed_nodes = []
            for nc in node_calls:
                pn = parse_single_helper_node(nc)
                if pn:
                    parsed_nodes.append(pn)
            trees_by_ws_id[ws_id] = {
                "archetype": archetype,
                "nodes": parsed_nodes,
                "sourceFile": f"modules/custom/lua/{fpath.name}",
            }

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
            nodes_body = spec_body[n_start + 1 : n_end]
            node_calls = split_top_level_args(nodes_body)
            parsed_nodes = []
            for nc in node_calls:
                pn = parse_single_helper_node(nc)
                if pn:
                    parsed_nodes.append(pn)
            trees_by_ws_id[ws_id] = {
                "archetype": archetype,
                "nodes": parsed_nodes,
                "sourceFile": f"modules/custom/lua/{fpath.name}",
            }

    out_list = []
    for ws_id in sorted(ws_by_id.keys()):
        ws = ws_by_id[ws_id]
        tinfo = trees_by_ws_id.get(ws_id, {"archetype": ws["wsType"], "nodes": [], "sourceFile": "modules/custom/lua/overlords_ws_talents.lua"})
        nodes = list(tinfo["nodes"])

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
        for n in nodes:
            gate = TIER_GATES.get(n["tier"], TIER_GATES[1])
            n["reqLevel"] = gate["reqLevel"]
            n["reqWsPoints"] = gate["reqWsPoints"]

        ws_entry = {
            **ws,
            "archetype": tinfo["archetype"],
            "sourceFile": tinfo["sourceFile"],
            "maxPoints": sum(n["maxRank"] for n in nodes),
            "nodes": nodes,
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
def parse_commands() -> list[dict]:
    return [
        {
            "command": "!spec",
            "sourceFile": "modules/custom/commands/spec.lua",
            "summary": "Interactive Job Crystal / Soul Spec selector menu, CLI inspector, and Ashita v4 [OXSPEC] sync.",
            "usage": [
                "!spec",
                "!spec list",
                "!spec info [crystal]",
                "!spec set <crystal>",
                "!spec remove",
            ],
        },
        {
            "command": "!talent",
            "sourceFile": "modules/custom/commands/talent.lua",
            "summary": "Weaponskill Talent Tree builder (4 Tiers, 56 pts per WS, Skillchain selector) & Ashita v4 /talents UI bridge.",
            "usage": [
                "!talent",
                "/talents (or /tal in Ashita v4 UI)",
            ],
        },
        {
            "command": "!gear",
            "sourceFile": "modules/custom/commands/gear.lua",
            "summary": "Auto-grants and equips a full 16-slot level-appropriate gear loadout tailored to your Job, active Crystal Spec, Role, and Weapon.",
            "usage": [
                "!gear",
                "!gear menu",
                "!gear <level> [weapon]",
                "!gear role <melee|tank|ranged|caster>",
                "!gear info",
            ],
        },
        {
            "command": "!eos",
            "sourceFile": "modules/custom/commands/eos.lua",
            "summary": "Controls Scholar's Eos (Medic) or Titania (Sage) faerie companion.",
            "usage": [
                "!eos heal",
                "!eos dismiss",
            ],
        },
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
        },
    ]


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

        patches.append(
            {
                "number": num_str,
                "filename": pfile.name,
                "title": slug,
                "description": desc_map.get(pfile.name, f"Engine patch modifying {', '.join(touched_files)}."),
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

    jobs = parse_job_specs()
    ws_catalog = parse_ws_catalog()
    ws_trees = parse_ws_trees(ws_catalog)
    rules = parse_server_rules()
    wiki_extras = get_companions_and_equipment()
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

    json_text = json.dumps(data, indent=2, ensure_ascii=False)
    json_path.write_text(json_text, encoding="utf-8")
    js_path.write_text(f"window.OVERLORDS_DATA = {json_text};\n", encoding="utf-8")

    print(
        f"Generated {json_path.relative_to(ROOT_DIR)} and {js_path.relative_to(ROOT_DIR)}: "
        f"{data['stats']['totalCrystalSpecs']} Crystal Specs ({total_custom_jas} Custom JAs, {data['stats']['totalCustomTraits']} Traits), "
        f"{data['stats']['totalWeaponskills']} Weaponskill Trees, "
        f"{data['stats']['totalPatches']} Engine Patches, "
        f"{data['stats']['totalRecentCommits']} Git Commits."
    )


if __name__ == "__main__":
    main()
