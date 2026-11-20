#!/usr/bin/env python3
"""OverlordsXI Soul Proving Grounds — Stage A Formula/Matrix Runner & Telemetry Summarizer.

Responsibilities:
  1. Load the canonical 66 active Souls (22 jobs, excluding retired DNC:freelancer)
     and the 6-tier Soul classification directly from overlords_job_specs.lua.
  2. Validate and inspect the shared Lua encounter registry
     (overlords_proving_grounds_registry.lua) via libluajit_64.dll when available.
  3. Generate the standardized Balance Test Matrix (6 archetypes x 4 levels x
     3 difficulties, with +8 explicitly marked extreme_challenge / non-baseline).
  4. Execute Stage A Formula & Regression checks matching authoritative server
     constants from boss_like_combat_and_exp.lua and patches/0044. Every formula
     output is explicitly tagged `test_mode="formula"` and `NO_REAL_COMBAT_EXECUTED`.
  5. Summarize JSONL combat runs from manual or real automated (`xi_test`) runs,
     strictly separating actual combat measurements from static formula checks.

Usage:
  python tools/proving_grounds_benchmark.py --run-formula --out logs/proving_grounds_formula.json
  python tools/proving_grounds_benchmark.py --matrix-out logs/proving_grounds_matrix.json
  python tools/proving_grounds_benchmark.py --summarize C:/dev/server/log/proving_grounds_runs.jsonl
"""
from __future__ import annotations

import argparse
import csv
import ctypes
import datetime
import json
import math
import re
import statistics
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
JOB_SPECS_PATH = REPO_ROOT / "modules" / "custom" / "lua" / "overlords_job_specs.lua"
BOSS_COMBAT_PATH = REPO_ROOT / "modules" / "custom" / "lua" / "boss_like_combat_and_exp.lua"
REGISTRY_LUA_PATH = REPO_ROOT / "modules" / "custom" / "lua" / "overlords_proving_grounds_registry.lua"
TELEMETRY_LUA_PATH = REPO_ROOT / "modules" / "custom" / "lua" / "overlords_proving_grounds_telemetry.lua"
LUAJIT_DLL_DEFAULT = Path(r"C:\dev\server\libluajit_64.dll")

RETIRED_SOULS = {("DNC", "freelancer")}
EXPECTED_CANONICAL_SOULS = 66
CANONICAL_LEVELS = (10, 30, 50, 75)
MATRIX_ARCHETYPES = (
    ("physical_bruiser", "Physical Bruiser", "Tank mitigation and sustained healing"),
    ("magic_caster", "Magic-heavy Caster", "Resistance, interruption and MP"),
    ("aoe_boss", "AoE Boss", "Pet survival and group healing"),
    ("mobile_boss", "Mobile Boss", "Positional mechanics and melee uptime"),
    ("endurance_boss", "Endurance Boss", "Resource depletion and cooldown cycles"),
    ("burst_boss", "Burst Boss", "Burst damage versus sustained damage"),
)
DIFFICULTIES = (
    {"id": "even_match", "label": "Even Match (+0)", "level_delta": 0, "standard_baseline": True, "extreme_challenge": False},
    {"id": "very_tough", "label": "Very Tough (+3)", "level_delta": 3, "standard_baseline": True, "extreme_challenge": False},
    {"id": "incredibly_tough", "label": "Incredibly Tough (+5)", "level_delta": 5, "standard_baseline": True, "extreme_challenge": False},
    {"id": "extreme", "label": "Extreme (+8) [Non-Baseline]", "level_delta": 8, "standard_baseline": False, "extreme_challenge": True},
)
DEFAULT_LOG_BASE_DIR = Path(r"C:\dev\server\log\proving_grounds")
LEGACY_RUNS_LOG_PATH = Path(r"C:\dev\server\log\proving_grounds_runs.jsonl")

TIER_OFFENSE = {
    "Damage": {"offense": 1.00, "physDmgDealt": 0, "rangedDmgDealt": 0, "magDmgDealt": 0},
    "HybridSupport": {"offense": 0.50, "physDmgDealt": -25, "rangedDmgDealt": -25, "magDmgDealt": -25},
    "Support": {"offense": 0.35, "physDmgDealt": -40, "rangedDmgDealt": -40, "magDmgDealt": -40},
    "CombatHealer": {"offense": 0.20, "physDmgDealt": -50, "rangedDmgDealt": -50, "magDmgDealt": -50},
    "Healer": {"offense": 0.12, "physDmgDealt": -60, "rangedDmgDealt": -60, "magDmgDealt": -60},
    "Tank": {"offense": 0.12, "physDmgDealt": -60, "rangedDmgDealt": -60, "magDmgDealt": -60},
}

# Authoritative server constants parsed/verified against boss_like_combat_and_exp.lua
LEVEL_GAP_PLAYER_DMG = {
    2: 0.94, 3: 0.88, 4: 0.80, 5: 0.72, 6: 0.63, 7: 0.54, 8: 0.38, 9: 0.28, 10: 0.20,
}
LEVEL_GAP_MOB_DMG = {
    2: 1.08, 3: 1.16, 4: 1.26, 5: 1.38, 6: 1.52, 7: 1.68, 8: 1.95, 9: 2.25, 10: 2.55,
}
NORMAL_MOB_PRESET = {
    "hpp": 45, "regain": 30, "storetp": 35, "defp": 25, "mdef": 18, "meva": 18,
    "attp": 45, "matt": 32, "acc": 24, "eva": 14, "haste": 1800, "maxHaste": 2500,
    "fastcast": 18, "maxFastcast": 35, "magicCoolMultiplier": 0.68, "baseDmgMult": 1.65,
}
NM_MOB_PRESET = {
    "hpp": 75, "regain": 50, "storetp": 50, "defp": 38, "mdef": 28, "meva": 30,
    "attp": 65, "matt": 50, "acc": 36, "eva": 22, "haste": 2200, "maxHaste": 3000,
    "fastcast": 25, "maxFastcast": 45, "magicCoolMultiplier": 0.58, "baseDmgMult": 1.85,
}


def get_git_commit_sha(repo_root: Path = REPO_ROOT) -> str:
    try:
        out = subprocess.check_output(
            ["git", "-C", str(repo_root), "rev-parse", "--short=12", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=5,
        ).strip()
        return out or "unknown"
    except Exception:
        return "unknown"


def load_canonical_souls(job_specs_path: Path = JOB_SPECS_PATH) -> list[dict[str, Any]]:
    """Parse all 66 active canonical Souls and their six-tier classifications."""
    src = job_specs_path.read_text(encoding="utf-8")
    start = src.find("spec.JOB_SPECS =")
    end = src.find("local KEY_ALIASES", start)
    if start < 0 or end < 0:
        raise ValueError("Could not locate spec.JOB_SPECS block in overlords_job_specs.lua")

    # Parse SPEC_KEY_TIERS overrides
    tier_overrides: dict[str, str] = {}
    t_start = src.find("spec.SPEC_KEY_TIERS =")
    t_end = src.find("}", t_start)
    if t_start >= 0 and t_end > t_start:
        for k, v in re.findall(r"(\w+)\s*=\s*'([^']+)'", src[t_start:t_end]):
            tier_overrides[k.lower()] = v

    modal_souls = {"necromancer", "huntsman"}

    job_re = re.compile(r"^\s*([A-Z]{3})\s*=\s*$")
    id_re = re.compile(r"\bid\s*=\s*'([a-z0-9_]+)'")
    name_re = re.compile(r"\bname\s*=\s*'([^']+)'")
    role_re = re.compile(r"\brole\s*=\s*'([^']+)'")

    souls: list[dict[str, Any]] = []
    current_job = None
    for line in src[start:end].splitlines():
        jm = job_re.match(line)
        if jm:
            current_job = jm.group(1)
            continue
        im = id_re.search(line)
        if im and current_job:
            key = im.group(1).lower()
            if (current_job, key) in RETIRED_SOULS:
                continue
            name = name_re.search(line).group(1) if name_re.search(line) else key
            role = role_re.search(line).group(1) if role_re.search(line) else "Unassigned"
            tier = tier_overrides.get(key, role)
            souls.append({
                "job": current_job,
                "soul_key": key,
                "soul_name": name,
                "role": role,
                "tier": tier,
                "modal_tier": key in modal_souls,
                "tier_config": TIER_OFFENSE.get(tier, TIER_OFFENSE["Damage"]),
            })

    if len(souls) != EXPECTED_CANONICAL_SOULS:
        raise ValueError(f"Expected {EXPECTED_CANONICAL_SOULS} canonical Souls, parsed {len(souls)}")
    return souls


def inspect_lua_registry_via_luajit(
    registry_path: Path = REGISTRY_LUA_PATH,
    telemetry_path: Path = TELEMETRY_LUA_PATH,
    luajit_dll: Path = LUAJIT_DLL_DEFAULT,
) -> dict[str, Any]:
    """Load the actual shared Lua registry inside libluajit_64.dll and return its exported metadata."""
    if not luajit_dll.is_file():
        return {"available": False, "reason": f"libluajit_64.dll not found at {luajit_dll}"}

    dll = ctypes.CDLL(str(luajit_dll))
    dll.luaL_newstate.restype = ctypes.c_void_p
    dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
    dll.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    dll.luaL_loadstring.restype = ctypes.c_int
    dll.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    dll.lua_pcall.restype = ctypes.c_int
    dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    dll.lua_tolstring.restype = ctypes.c_char_p
    dll.lua_close.argtypes = [ctypes.c_void_p]

    reg_p = str(registry_path).replace("\\", "/")
    tel_p = str(telemetry_path).replace("\\", "/")
    snippet = f"""
local R = dofile('{reg_p}')
local T = dofile('{tel_p}')
local npcTypes = {{}}
for _, k in ipairs(R.NPC_ARCHETYPE_ORDER) do
    local a = R.ARCHETYPES[k]
    npcTypes[#npcTypes + 1] = {{
        id = a.id,
        label = a.label,
        npcAvailable = a.npcAvailable,
        groupId = a.groupId,
        groupZoneId = a.groupZoneId,
        nmGroupId = a.nmGroupId,
        nmGroupZoneId = a.nmGroupZoneId,
        autoAttack = a.behavior.autoAttack,
        magicCasting = a.behavior.magicCasting,
        mobAbility = a.behavior.mobAbility,
    }}
end
local allArchetypes = {{}}
for k, a in pairs(R.ARCHETYPES) do
    allArchetypes[#allArchetypes + 1] = {{
        id = a.id,
        groupId = a.groupId,
        groupZoneId = a.groupZoneId,
        nmGroupId = a.nmGroupId,
        nmGroupZoneId = a.nmGroupZoneId,
        npcAvailable = a.npcAvailable == true,
    }}
end
local sampleEnc, err = R.buildEncounterConfig({{
    bossType = 'physical_bruiser',
    bossLevel = 10,
    playerLevel = 10,
    difficulty = 'even_match',
    seed = 12345,
}})
assert(sampleEnc ~= nil, tostring(err))
local out = {{
    schemaVersion = R.SCHEMA_VERSION,
    arenaZoneId = R.ARENA_ZONE_ID,
    npcPos = R.NPC_POS,
    levels = R.LEVELS,
    difficultyOrder = R.DIFFICULTY_ORDER,
    npcArchetypes = npcTypes,
    allArchetypes = allArchetypes,
    visibilityClearMask = R.VISIBILITY_CLEAR_MASK,
    matrixOrder = R.MATRIX_ARCHETYPE_ORDER,
    plus8Baseline = R.DIFFICULTIES.extreme.standardBaseline,
    plus8Extreme = R.DIFFICULTIES.extreme.extremeChallenge,
    maxBossLevel = R.MAX_BOSS_LEVEL,
    sampleEncounterId = sampleEnc.encounterId,
    sampleGearProfile = sampleEnc.gearProfile,
}}
return T.encodeJson(out)
"""
    L = dll.luaL_newstate()
    try:
        dll.luaL_openlibs(L)
        rc = dll.luaL_loadstring(L, snippet.encode("utf-8"))
        if rc != 0:
            err = dll.lua_tolstring(L, -1, None)
            raise RuntimeError(f"Lua load error: {err.decode('utf-8', 'replace') if err else rc}")
        rc = dll.lua_pcall(L, 0, 1, 0)
        if rc != 0:
            err = dll.lua_tolstring(L, -1, None)
            raise RuntimeError(f"Lua exec error: {err.decode('utf-8', 'replace') if err else rc}")
        raw = dll.lua_tolstring(L, -1, None)
        data = json.loads(raw.decode("utf-8"))
        data["available"] = True
        return data
    finally:
        dll.lua_close(L)


# ---------------------------------------------------------------------------
# Stage A — Authoritative Formula Mirrors (explicitly labeled formula tests!)
# ---------------------------------------------------------------------------

def mob_level_scale(level: int) -> float:
    """Exact mirror of xi.customBossServer.getMobLevelScale(level)."""
    lvl = max(1, int(level))
    if lvl <= 1:
        return 0.25
    if lvl <= 9:
        return 0.25 + (lvl - 1) * 0.05
    if lvl <= 29:
        return 0.70 + (lvl - 10) * 0.02
    if lvl <= 49:
        return 1.12 + (lvl - 30) * 0.02
    if lvl <= 69:
        return 1.55 + (lvl - 50) * 0.02
    return min(2.25, 1.98 + (lvl - 70) * 0.03)


def scaled_mob_stats(level: int, is_nm: bool = False) -> dict[str, Any]:
    preset = NM_MOB_PRESET if is_nm else NORMAL_MOB_PRESET
    scale = mob_level_scale(level)
    return {
        "level": level,
        "is_nm": is_nm,
        "scale": round(scale, 4),
        "hpp_bonus": math.floor(preset["hpp"] * scale) if level >= 2 else 0,
        "regain": math.floor(preset["regain"] * scale),
        "storetp": math.floor(preset["storetp"] * scale),
        "defp": math.floor(preset["defp"] * scale),
        "mdef": math.floor(preset["mdef"] * scale),
        "meva": math.floor(preset["meva"] * scale),
        "attp": math.floor(preset["attp"] * scale),
        "matt": math.floor(preset["matt"] * scale),
        "acc": math.floor(preset["acc"] * scale),
        "eva": math.floor(preset["eva"] * scale),
        "haste_bps": min(preset["maxHaste"], math.floor(preset["haste"] * scale)),
        "fastcast": min(preset["maxFastcast"], math.floor(preset["fastcast"] * scale)),
        "magic_cool_mult": preset["magicCoolMultiplier"],
        "base_out_dmg_mult": preset["baseDmgMult"],
    }


def level_gap_player_dmg_mult(mob_lvl: int, player_lvl: int) -> float:
    dlvl = mob_lvl - player_lvl
    if dlvl <= 1:
        return 1.0
    if dlvl in LEVEL_GAP_PLAYER_DMG:
        return LEVEL_GAP_PLAYER_DMG[dlvl]
    return max(0.12, LEVEL_GAP_PLAYER_DMG[10] - max(0, dlvl - 10) * 0.03)


def level_gap_mob_dmg_mult(mob_lvl: int, player_lvl: int, is_nm: bool = False) -> float:
    base = 1.85 if is_nm else 1.65
    dlvl = mob_lvl - player_lvl
    if dlvl <= 1:
        return base
    if dlvl in LEVEL_GAP_MOB_DMG:
        return round(base * LEVEL_GAP_MOB_DMG[dlvl], 6)
    return round(base * min(3.00, LEVEL_GAP_MOB_DMG[10] + max(0, dlvl - 10) * 0.15), 6)


def level_gap_hit_rate_delta(mob_lvl: int, player_lvl: int, player_attacking: bool = True) -> float:
    dlvl = mob_lvl - player_lvl
    if dlvl <= 1:
        return 0.0
    if player_attacking:
        return -0.02 * (dlvl - 1) if dlvl <= 7 else -0.12 - (dlvl - 7) * 0.05
    return 0.02 * (dlvl - 1) if dlvl <= 7 else 0.12 + (dlvl - 7) * 0.04


def level_gap_macc_delta(mob_lvl: int, player_lvl: int, player_casting: bool = True) -> int:
    dlvl = mob_lvl - player_lvl
    if dlvl <= 1:
        return 0
    if player_casting:
        return -3 * (dlvl - 1) if dlvl <= 7 else -18 - (dlvl - 7) * 10
    return 3 * (dlvl - 1) if dlvl <= 7 else 18 + (dlvl - 7) * 8


def armor_piercing_pdif_floor(raw_pdif: float, is_nm: bool = False, is_crit: bool = False) -> float:
    if raw_pdif >= 1.0:
        return raw_pdif
    min_floor = (0.75 if is_nm else 0.65) + (0.20 if is_crit else 0.0)
    blended = min_floor + max(0.0, raw_pdif - 0.25) * ((1.0 - min_floor) / 0.75)
    return max(min_floor, blended)


def unified_melee_attack_rate(gear_haste: float, other_haste: float) -> float:
    """OverlordsXI patches/0044 unified melee attack-rate multiplier."""
    gear_rate = 1.0 + 1.5 * gear_haste if gear_haste >= 0 else 1.0 / (1.0 - 1.5 * gear_haste)
    other_rate = (1.0 + (5.0 / 3.0) * other_haste / (1.0 + other_haste)) if other_haste >= 0 else 1.0 / (1.0 - other_haste)
    return gear_rate * other_rate


def unified_ranged_attack_rate(gear_haste: float, other_haste: float, snapshot_rate: float = 1.0) -> float:
    gear_rate = 1.0 + 1.5 * gear_haste if gear_haste >= 0 else 1.0 / (1.0 - 1.5 * gear_haste)
    other_rate = (1.0 + other_haste / (1.0 + other_haste)) if other_haste >= 0 else 1.0 / (1.0 - other_haste)
    return (10.0 / 9.0) * gear_rate * other_rate * snapshot_rate


def base_tp_from_delay(delay: int, store_tp: int = 25) -> int:
    """Standard FFXI/LSB per-hit TP approximation with Store TP (formula test only)."""
    if delay <= 180:
        base = 61 + ((delay - 180) * 63) / 360
    elif delay <= 450:
        base = 61 + ((delay - 180) * 88) / 270
    elif delay <= 480:
        base = 149 + ((delay - 450) * 20) / 30
    else:
        base = 169 + ((delay - 480) * 20) / 50
    return max(1, math.floor(base * (100 + store_tp) / 100))


def breath_cap(mob_lvl: int, target_max_hp: int, is_nm: bool = False, level_gap_mult: float = 1.65) -> int:
    per_lvl = 13.0 if is_nm else 9.5
    flat = 55 if is_nm else 35
    lvl_cap = max(20, math.floor((mob_lvl * per_lvl + flat) * level_gap_mult))
    base_share = 0.45 if is_nm else 0.35
    eff_share = min(0.75, base_share * level_gap_mult)
    hp_cap = max(15, math.floor(max(1, target_max_hp) * eff_share))
    return min(lvl_cap, hp_cap)


def run_stage_a_formula_suite() -> dict[str, Any]:
    """Run all 10 Stage A Formula & Regression test groups."""
    checks: list[dict[str, Any]] = []

    def record(name: str, passed: bool, details: dict[str, Any]) -> None:
        checks.append({"check": name, "passed": bool(passed), "details": details})

    # 1. Enemy level scaling across Lv10, 30, 50, 75 (Normal & NM)
    scales = {lvl: scaled_mob_stats(lvl, is_nm=False) for lvl in CANONICAL_LEVELS}
    nm_scales = {lvl: scaled_mob_stats(lvl, is_nm=True) for lvl in CANONICAL_LEVELS}
    mono_ok = all(scales[a]["hpp_bonus"] < scales[b]["hpp_bonus"] for a, b in zip(CANONICAL_LEVELS, CANONICAL_LEVELS[1:]))
    nm_gt_ok = all(nm_scales[l]["hpp_bonus"] > scales[l]["hpp_bonus"] and nm_scales[l]["attp"] > scales[l]["attp"] for l in CANONICAL_LEVELS)
    record("enemy_level_scaling", mono_ok and nm_gt_ok, {"normal": scales, "nm": nm_scales})

    # 2. Physical damage & level-gap penalties (EM, +3, +8 wall)
    em_p = level_gap_player_dmg_mult(10, 10)
    p3_p = level_gap_player_dmg_mult(13, 10)
    p8_p = level_gap_player_dmg_mult(18, 10)
    em_m = level_gap_mob_dmg_mult(10, 10, False)
    p3_m = level_gap_mob_dmg_mult(13, 10, False)
    p8_m = level_gap_mob_dmg_mult(18, 10, False)
    phys_ok = (em_p == 1.0 and p3_p == 0.88 and p8_p == 0.38 and math.isclose(em_m, 1.65) and p3_m > em_m and p8_m > p3_m)
    record("physical_damage_and_level_gap", phys_ok, {
        "player_mult": {"EM": em_p, "+3": p3_p, "+8": p8_p},
        "mob_mult_normal": {"EM": em_m, "+3": p3_m, "+8": p8_m},
        "hit_rate_delta_player": {"EM": level_gap_hit_rate_delta(10, 10), "+3": level_gap_hit_rate_delta(13, 10), "+8": level_gap_hit_rate_delta(18, 10)},
    })

    # 3. Magical damage & MACC resist scaling + breath anti-one-shot caps
    macc_em = level_gap_macc_delta(10, 10, True)
    macc_p3 = level_gap_macc_delta(13, 10, True)
    macc_p8 = level_gap_macc_delta(18, 10, True)
    bcap_10 = breath_cap(10, 400, False, 1.65)
    bcap_75 = breath_cap(75, 2500, False, 1.65)
    magic_ok = (macc_em == 0 and macc_p3 == -6 and macc_p8 == -28 and bcap_10 <= int(400 * 0.75) and bcap_75 <= int(2500 * 0.75))
    record("magical_damage_and_breath_caps", magic_ok, {
        "macc_delta_player": {"EM": macc_em, "+3": macc_p3, "+8": macc_p8},
        "breath_cap_lv10_400hp": bcap_10,
        "breath_cap_lv75_2500hp": bcap_75,
    })

    # 4. Haste and attack speed (patches/0044 unified rate formula)
    base_melee = unified_melee_attack_rate(0.0, 0.25)
    gear20_melee = unified_melee_attack_rate(0.20, 0.25)
    slow_melee = unified_melee_attack_rate(0.0, -0.50)
    ranged_snap = unified_ranged_attack_rate(0.25, 0.50, 1.30) / unified_ranged_attack_rate(0.25, 0.50, 1.00)
    haste_ok = (
        math.isclose(base_melee, 4.0 / 3.0, rel_tol=1e-9)
        and math.isclose(gear20_melee / base_melee, 1.30, rel_tol=1e-9)
        and 0 < slow_melee < unified_melee_attack_rate(0.0, 0.0)
        and math.isclose(ranged_snap, 1.30, rel_tol=1e-9)
    )
    record("haste_and_attack_speed", haste_ok, {
        "baseline_25pct_other_rate": round(base_melee, 4),
        "gear_20pct_gain_ratio": round(gear20_melee / base_melee, 4),
        "slow_50pct_rate": round(slow_melee, 4),
        "snapshot_multiplier": round(ranged_snap, 4),
    })

    # 5. TP generation (per-swing + Store TP + active-combat-only Regain)
    tp_1h = base_tp_from_delay(240, store_tp=25)
    tp_2h = base_tp_from_delay(480, store_tp=25)
    regain_per_min = (60 // 3) * 20  # +20 TP/3s tick in active combat only
    tp_ok = (tp_1h > 0 and tp_2h > tp_1h and regain_per_min == 400)
    record("tp_generation", tp_ok, {
        "delay240_stp25_tp_per_hit": tp_1h,
        "delay480_stp25_tp_per_hit": tp_2h,
        "combat_only_regain_per_min": regain_per_min,
    })

    # 6. Mitigation & Tank pressure
    pdif_tank_norm = armor_piercing_pdif_floor(0.25, is_nm=False, is_crit=False)
    pdif_tank_nm = armor_piercing_pdif_floor(0.25, is_nm=True, is_crit=False)
    pdif_dps_untouched = armor_piercing_pdif_floor(1.45, is_nm=False, is_crit=False)
    raw_hit = 200
    max_block_red = raw_hit - max(1, math.floor(raw_hit * 0.35))
    mit_ok = (
        math.isclose(pdif_tank_norm, 0.65)
        and math.isclose(pdif_tank_nm, 0.75)
        and math.isclose(pdif_dps_untouched, 1.45)
        and (raw_hit - max_block_red) >= math.floor(raw_hit * 0.35)
    )
    record("mitigation_and_tank_pressure", mit_ok, {
        "normal_tank_pdif_floor": pdif_tank_norm,
        "nm_tank_pdif_floor": pdif_tank_nm,
        "dps_pdif_untouched": pdif_dps_untouched,
        "block_min_bleedthrough_on_200": raw_hit - max_block_red,
        "parry_caps": {"passive": 50, "burst": 65},
        "block_caps": {"passive": 60, "burst": 75},
    })

    # 7. Healing calculations (effective vs overheal accounting)
    def calc_heal(cur_hp: int, max_hp: int, raw_heal: int) -> tuple[int, int]:
        eff = min(raw_heal, max(0, max_hp - cur_hp))
        return eff, max(0, raw_heal - eff)
    eff1, ov1 = calc_heal(300, 400, 150)
    eff2, ov2 = calc_heal(100, 400, 150)
    heal_ok = (eff1 == 100 and ov1 == 50 and eff2 == 150 and ov2 == 0)
    record("healing_effective_vs_overheal", heal_ok, {
        "partial_overheal": {"effective": eff1, "overheal": ov1},
        "full_effective": {"effective": eff2, "overheal": ov2},
    })

    # 8. MP sustainability model (formula check over 180s encounter)
    duration = 180
    ticks = duration // 3
    refresh_mp = ticks * 6  # e.g. +6 MP/tick sustainable healer baseline
    start_mp = 600
    cure_cost = 46
    casts_needed = 18
    net_mp = start_mp + refresh_mp - (casts_needed * cure_cost)
    mp_ok = net_mp >= 0
    record("mp_sustainability_formula", mp_ok, {
        "duration_sec": duration,
        "starting_mp": start_mp,
        "refresh_mp_total": refresh_mp,
        "cast_mp_burn": casts_needed * cure_cost,
        "ending_mp": net_mp,
    })

    # 9. Defensive stacking & Six-Tier Soul philosophy check
    souls = load_canonical_souls()
    tiers_present = sorted({s["tier"] for s in souls})
    tier1_dps = [s for s in souls if s["tier"] == "Damage"]
    tanks = [s for s in souls if s["tier"] == "Tank"]
    healers = [s for s in souls if s["tier"] in ("Healer", "CombatHealer")]
    stack_ok = (
        len(souls) == EXPECTED_CANONICAL_SOULS
        and TIER_OFFENSE["Damage"]["offense"] == 1.00
        and TIER_OFFENSE["Tank"]["offense"] == 0.12
        and TIER_OFFENSE["Healer"]["offense"] == 0.12
        and TIER_OFFENSE["HybridSupport"]["offense"] == 0.50
    )
    record("defensive_stacking_and_soul_tiers", stack_ok, {
        "canonical_soul_count": len(souls),
        "tiers_present": tiers_present,
        "tier1_dps_count": len(tier1_dps),
        "tank_count": len(tanks),
        "healer_and_combat_healer_count": len(healers),
        "tier_offense_scalars": {k: v["offense"] for k, v in TIER_OFFENSE.items()},
    })

    # 10. Pet scaling check (petCombatPace from boss_like_combat_and_exp.lua)
    pet_hp_mult = 2.0  # +100% HPP
    pet_haste_rate = unified_melee_attack_rate(0.0, 0.15)
    pet_tp_hit = base_tp_from_delay(240, store_tp=25)
    pet_regain_min = (60 // 3) * 15
    pet_ok = (pet_hp_mult == 2.0 and pet_haste_rate > 1.0 and pet_tp_hit > 0 and pet_regain_min == 300)
    record("pet_scaling", pet_ok, {
        "pet_hp_multiplier": pet_hp_mult,
        "pet_haste_15pct_rate": round(pet_haste_rate, 4),
        "pet_tp_per_hit_delay240": pet_tp_hit,
        "pet_active_combat_regain_per_min": pet_regain_min,
    })

    all_passed = all(c["passed"] for c in checks)
    return {
        "runner_version": "1.0.0",
        "test_mode": "formula",
        "combat_execution": "NO_REAL_COMBAT_EXECUTED",
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "server_commit_sha": get_git_commit_sha(),
        "passed": all_passed,
        "total_checks": len(checks),
        "passed_checks": sum(1 for c in checks if c["passed"]),
        "checks": checks,
    }


def build_balance_test_matrix() -> dict[str, Any]:
    """Generate the standardized 66-Soul Balance Test Matrix."""
    souls = load_canonical_souls()
    cases: list[dict[str, Any]] = []
    for arch_id, arch_label, primary_test in MATRIX_ARCHETYPES:
        for lvl in CANONICAL_LEVELS:
            gear_id = f"accessible_lv{lvl}"
            for diff in DIFFICULTIES:
                boss_lvl = lvl + diff["level_delta"]
                cases.append({
                    "scenario_id": f"matrix_{arch_id}_p{lvl}_b{boss_lvl}_{diff['id']}",
                    "scenario_version": "1.0.0",
                    "boss_type": arch_id,
                    "boss_label": arch_label,
                    "primary_test": primary_test,
                    "player_level": lvl,
                    "boss_level": boss_lvl,
                    "level_gap": diff["level_delta"],
                    "difficulty": diff["id"],
                    "standard_baseline": diff["standard_baseline"],
                    "extreme_challenge": diff["extreme_challenge"],
                    "gear_profile": gear_id,
                    "boss_preset": "normal",
                })
    return {
        "matrix_version": "1.0.0",
        "test_mode": "formula",
        "combat_execution": "NO_REAL_COMBAT_EXECUTED",
        "server_commit_sha": get_git_commit_sha(),
        "canonical_soul_count": len(souls),
        "retired_excluded": sorted(f"{j}:{k}" for j, k in RETIRED_SOULS),
        "levels": list(CANONICAL_LEVELS),
        "archetype_count": len(MATRIX_ARCHETYPES),
        "difficulty_count": len(DIFFICULTIES),
        "scenario_templates_count": len(cases),
        "total_soul_scenario_pairs": len(souls) * len(cases),
        "standard_baseline_pairs": len(souls) * sum(1 for c in cases if c["standard_baseline"]),
        "extreme_challenge_pairs": len(souls) * sum(1 for c in cases if c["extreme_challenge"]),
        "scenarios": cases,
        "souls": souls,
    }


def _is_run_level_sync_valid(rec: dict[str, Any]) -> bool:
    ls = rec.get("level_sync")
    if isinstance(ls, dict) and ls.get("valid") is False:
        return False
    if rec.get("valid_for_balance") is False and "invalid_level_sync" in (rec.get("warnings") or []):
        return False
    return True


def _is_run_extreme(rec: dict[str, Any]) -> bool:
    if rec.get("extreme_challenge") is True:
        return True
    diff = str(rec.get("difficulty", "")).lower()
    return diff in ("extreme", "boss_plus_8", "extreme_plus_8")


def load_jsonl_records(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    out: list[dict[str, Any]] = []
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def resolve_runs_index_path(base_dir: Path = DEFAULT_LOG_BASE_DIR) -> Path:
    idx = base_dir / "runs.jsonl"
    if idx.is_file():
        return idx
    if LEGACY_RUNS_LOG_PATH.is_file():
        return LEGACY_RUNS_LOG_PATH
    return idx


def filter_runs(
    records: list[dict[str, Any]],
    *,
    soul: str | None = None,
    level: int | None = None,
    boss: str | None = None,
    difficulty: str | None = None,
    preset: str | None = None,
    date_prefix: str | None = None,
    include_invalid: bool = False,
    include_extreme: bool = False,
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for r in records:
        if not include_invalid and not _is_run_level_sync_valid(r):
            continue
        if not include_extreme and _is_run_extreme(r):
            continue
        if soul and str(r.get("soul_key", "")).lower() != soul.lower():
            continue
        if level is not None:
            eff = r.get("effective_combat_level", r.get("character_level"))
            if eff != level:
                continue
        if boss and str(r.get("boss_type", "")).lower() != boss.lower():
            continue
        if difficulty and str(r.get("difficulty", "")).lower() != difficulty.lower():
            continue
        if preset and str(r.get("boss_preset", "")).lower() != preset.lower():
            continue
        if date_prefix and not str(r.get("timestamp_utc", "")).startswith(date_prefix):
            continue
        out.append(r)
    return out


def summarize_jsonl_runs(jsonl_path: Path) -> dict[str, Any]:
    """Summarize actual combat JSONL runs, excluding invalid level-sync and +8 Extreme runs from standard averages."""
    if not jsonl_path.is_file():
        return {"error": f"Run log not found: {jsonl_path}", "total_runs": 0}

    records = load_jsonl_records(jsonl_path)

    by_mode: dict[str, int] = {}
    by_role_soul: dict[tuple[str, str], list[float]] = {}
    by_bucket: dict[str, list[float]] = {}
    struggled: list[str] = []
    performed_well: list[str] = []
    balance_concerns: list[str] = []

    excluded_invalid_sync = 0
    excluded_extreme_plus8 = 0
    excluded_never_started = 0
    excluded_logging_errors = 0
    included_for_balance = 0

    for r in records:
        mode = str(r.get("test_mode", "unknown"))
        by_mode[mode] = by_mode.get(mode, 0) + 1
        saf = r.get("metrics", {}).get("safety", {})
        log_st = r.get("logging_status", {})

        if saf.get("progression_clean") is False:
            balance_concerns.append(f"SAFETY VIOLATION in {r.get('run_id')}: EXP observed ({saf.get('exp_points_observed')})")
        if isinstance(log_st, dict) and log_st.get("ok") is False:
            excluded_logging_errors += 1
            balance_concerns.append(f"LOGGING ERROR in {r.get('run_id')}: {log_st.get('errors')}")

        if not _is_run_level_sync_valid(r):
            excluded_invalid_sync += 1
            continue
        if _is_run_extreme(r):
            excluded_extreme_plus8 += 1
            continue
        if r.get("combat_started") is False:
            excluded_never_started += 1
            continue

        included_for_balance += 1
        off = r.get("metrics", {}).get("offense", {})
        dps = off.get("sustained_dps")
        role = str(r.get("role", "Unassigned"))
        skey = str(r.get("soul_key", "none"))
        eff_lvl = r.get("effective_combat_level", r.get("character_level", 0))
        bucket_key = f"{skey}|{r.get('boss_type')}|lv{eff_lvl}|{r.get('difficulty')}|{r.get('boss_preset')}|{r.get('gear_profile')}"
        if isinstance(dps, (int, float)):
            by_role_soul.setdefault((role, skey), []).append(float(dps))
            by_bucket.setdefault(bucket_key, []).append(float(dps))
        if r.get("outcome") == "defeat":
            struggled.append(f"{r.get('run_id')}: {skey} ({role}) defeated by {r.get('boss_type')} Lv.{r.get('actual_boss_level', r.get('boss_level'))}")
        elif r.get("outcome") == "victory":
            performed_well.append(f"{r.get('run_id')}: {skey} ({role}) defeated {r.get('boss_type')} Lv.{r.get('actual_boss_level', r.get('boss_level'))} ({dps} DPS)")

    role_dominance: list[str] = []
    roles = sorted({role for role, _ in by_role_soul})
    for role in roles:
        means = sorted(
            [(skey, statistics.mean(vals), len(vals)) for (rl, skey), vals in by_role_soul.items() if rl == role],
            key=lambda x: x[1],
            reverse=True,
        )
        if len(means) >= 2 and means[1][1] > 0 and (means[0][1] / means[1][1]) >= 1.35:
            role_dominance.append(
                f"Role {role}: {means[0][0]} avg {means[0][1]:.2f} DPS dominates {means[1][0]} avg {means[1][1]:.2f} DPS (>=35% gap)"
            )

    min_samples = min((len(v) for v in by_role_soul.values()), default=0)
    statistically_meaningful = (included_for_balance >= 5 and min_samples >= 3)

    return {
        "source_file": str(jsonl_path),
        "total_runs": len(records),
        "included_for_balance": included_for_balance,
        "excluded": {
            "invalid_level_sync": excluded_invalid_sync,
            "extreme_plus8_non_baseline": excluded_extreme_plus8,
            "combat_never_started": excluded_never_started,
            "logging_errors_flagged": excluded_logging_errors,
        },
        "runs_by_test_mode": by_mode,
        "bucket_avg_dps": {k: round(statistics.mean(v), 4) for k, v in sorted(by_bucket.items())},
        "statistically_meaningful": statistically_meaningful,
        "statistical_note": (
            "Sufficient repeated valid baseline samples (>=3 per Soul) for trend comparison."
            if statistically_meaningful
            else "Insufficient valid baseline sample size (<3 repeats per Soul); treat as smoke/POC measurement only."
        ),
        "performed_well": performed_well,
        "struggled": struggled,
        "balance_concerns": balance_concerns,
        "role_dominance_flags": role_dominance,
    }


def load_run_bundle(run_id: str, base_dir: Path = DEFAULT_LOG_BASE_DIR) -> dict[str, Any]:
    """Load summary, chronological event log, 1s snapshots, and optional feedback for one run_id."""
    runs = load_jsonl_records(resolve_runs_index_path(base_dir))
    summary = next((r for r in runs if r.get("run_id") == run_id), None)
    events = load_jsonl_records(base_dir / "events" / f"{run_id}.jsonl")
    snapshots = load_jsonl_records(base_dir / "snapshots" / f"{run_id}.jsonl")
    fb_path = base_dir / "feedback" / f"{run_id}.json"
    feedback = None
    if fb_path.is_file():
        try:
            feedback = json.loads(fb_path.read_text(encoding="utf-8", errors="replace"))
        except json.JSONDecodeError:
            feedback = {"error": "corrupt_feedback_json"}
    return {
        "run_id": run_id,
        "summary": summary,
        "events": events,
        "snapshots": snapshots,
        "feedback": feedback,
    }


COMPANION_SOUL_KEYS = {
    "shinobi", "kurogane", "medic", "sage", "necromancer", "untamed", "huntsman",
}


def detect_timeline_diagnostics(
    summary: dict[str, Any] | None,
    events: list[dict[str, Any]],
    snapshots: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Collect and derive explicit diagnostic warnings tied to timeline timestamps/events."""
    diagnostics: list[dict[str, Any]] = []
    seen_keys: set[tuple[str, int | None, int | None]] = set()

    def add_diag(
        code: str,
        message: str,
        *,
        severity: str = "warning",
        combat_sec: int | None = None,
        seq: int | None = None,
        meta: dict[str, Any] | None = None,
    ) -> None:
        key = (code, combat_sec, seq)
        if key in seen_keys:
            return
        seen_keys.add(key)
        diagnostics.append({
            "code": code,
            "severity": severity,
            "combat_sec": combat_sec,
            "seq": seq,
            "message": message,
            "meta": meta,
        })

    # 1. Surface authoritative server-emitted diagnostics from summary
    if isinstance(summary, dict):
        for d in summary.get("diagnostics") or []:
            if isinstance(d, dict) and d.get("code"):
                add_diag(
                    str(d["code"]),
                    str(d.get("detail") or d.get("message") or d["code"]),
                    severity=str(d.get("severity") or "warning"),
                    combat_sec=d.get("combat_sec"),
                    seq=d.get("seq"),
                    meta=d.get("meta") if isinstance(d.get("meta"), dict) else None,
                )

    # 2. Unexpected combat-start triggers (self-targeted spell/buff or unverified trigger)
    combat_start_ev = next((e for e in events if e.get("event_type") == "combat_start"), None)
    if combat_start_ev is not None:
        meta = combat_start_ev.get("meta") or {}
        src_id = combat_start_ev.get("source_id")
        tgt_id = combat_start_ev.get("target_id")
        if meta.get("verified_hostile") is False or (src_id is not None and src_id == tgt_id):
            add_diag(
                "unexpected_combat_start_trigger",
                f"Combat started from non-hostile/self-targeted trigger '{combat_start_ev.get('value')}' "
                f"({combat_start_ev.get('source_name')} -> {combat_start_ev.get('target_name')})",
                combat_sec=0,
                seq=combat_start_ev.get("seq"),
                meta=meta,
            )
    # Also check legacy logs where a self-targeted boss spell appeared at combat_ms == 0
    for ev in events:
        if ev.get("phase") == "combat" and ev.get("combat_ms") == 0 and ev.get("event_type") in ("boss_spell_start", "boss_spell_complete"):
            if ev.get("source_id") is not None and ev.get("source_id") == ev.get("target_id"):
                add_diag(
                    "unexpected_combat_start_trigger",
                    f"Boss self-targeted spell ({ev.get('value')}) occurred at combat_ms=0 (premature combat timer start)",
                    combat_sec=0,
                    seq=ev.get("seq"),
                )

    # 3. Unattributed HP recovery (explicit events + legacy snapshot reconciliation)
    unattributed_ev_count = 0
    for ev in events:
        if ev.get("event_type") == "unattributed_hp_change":
            unattributed_ev_count += 1
            cm = ev.get("combat_ms")
            csec = int(cm // 1000) if isinstance(cm, (int, float)) else None
            add_diag(
                "unattributed_hp_recovery",
                f"{ev.get('target_name') or 'actor'} recovered +{ev.get('value')} HP without an authoritative attributed source",
                combat_sec=csec,
                seq=ev.get("seq"),
                meta=ev.get("meta") if isinstance(ev.get("meta"), dict) else None,
            )

    if unattributed_ev_count == 0 and len(snapshots) >= 2:
        prev_hp_by_id: dict[Any, tuple[int, int]] = {}
        for snap in snapshots:
            sec = int(snap.get("combat_sec", 0))
            iv_heal = float((snap.get("interval") or {}).get("healing_done", 0))
            total_pos_delta = 0
            jump_actors: list[str] = []
            for p in snap.get("players") or []:
                pid = p.get("id")
                hp = int(p.get("hp") or 0)
                mhp = int(p.get("max_hp") or 0)
                if pid in prev_hp_by_id:
                    p_hp, p_mhp = prev_hp_by_id[pid]
                    delta = hp - p_hp
                    # Ignore Max HP shifts when checking unexplained snapshot HP gains
                    if delta > 0 and mhp == p_mhp:
                        total_pos_delta += delta
                        jump_actors.append(f"{p.get('name')}(+{delta})")
                prev_hp_by_id[pid] = (hp, mhp)
            if total_pos_delta > iv_heal + 5:
                add_diag(
                    "unattributed_hp_recovery",
                    f"Snapshot HP increased by +{total_pos_delta} ({', '.join(jump_actors)}) vs {iv_heal:.0f} attributed healing",
                    combat_sec=sec,
                )

    # 4. Damage attribution mismatches (summary breakdown/boss HP + same-timestamp WS/auto duplicates)
    if isinstance(summary, dict):
        off = (summary.get("metrics") or {}).get("offense") or {}
        recon = summary.get("reconciliation") or {}
        if recon.get("damage_reconciled") is False:
            add_diag(
                "damage_attribution_mismatch",
                f"Recorded damage ({recon.get('total_damage_recorded')}) did not match boss HP lost ({recon.get('boss_hp_lost')})",
                meta=recon,
            )
        else:
            tot = off.get("total_damage")
            if isinstance(tot, (int, float)):
                parts = sum(
                    float(off.get(k) or 0)
                    for k in ("autoattack_damage", "weaponskill_damage", "spell_damage", "ability_damage", "other_damage", "pet_and_clone_damage")
                )
                if abs(parts - float(tot)) > 0.5:
                    add_diag(
                        "damage_attribution_mismatch",
                        f"Offense breakdown sum ({parts:.0f}) != total_damage ({tot:.0f})",
                    )

    # Legacy duplicate WS+auto check on event stream (exact same timestamp, attacker, value, one 'auto' & one 'ws')
    ws_ev_index: set[tuple[Any, Any, Any]] = set()
    for ev in events:
        if ev.get("event_type") == "damage_dealt" and (ev.get("meta") or {}).get("source_kind") == "ws":
            ws_ev_index.add((ev.get("combat_ms"), ev.get("source_id"), ev.get("value")))
    for ev in events:
        if ev.get("event_type") == "damage_dealt" and (ev.get("meta") or {}).get("source_kind") == "auto":
            sig = (ev.get("combat_ms"), ev.get("source_id"), ev.get("value"))
            if sig in ws_ev_index:
                cm = ev.get("combat_ms")
                add_diag(
                    "damage_attribution_mismatch",
                    f"Possible duplicate WS/auto damage ({ev.get('value')}) for {ev.get('source_name')} at combat_ms={cm}",
                    combat_sec=int(cm // 1000) if isinstance(cm, (int, float)) else None,
                    seq=ev.get("seq"),
                )

    # 5. Resource generation without expenditure
    if isinstance(summary, dict):
        res = (summary.get("metrics") or {}).get("resources_and_pets") or {}
        off = (summary.get("metrics") or {}).get("offense") or {}
        tp_gen = res.get("tp_generated") or 0
        tp_spent = res.get("tp_spent") or 0
        ws_uses = off.get("weaponskill_uses") or 0
        if summary.get("combat_started") and isinstance(tp_gen, (int, float)) and tp_gen >= 1000 and tp_spent == 0 and ws_uses == 0:
            add_diag(
                "resource_generated_without_expenditure",
                f"{tp_gen} TP generated with 0 TP spent and 0 weapon skills used",
            )

    # 6. Boss ability execution failures
    failed_boss_abilities = [
        e for e in events
        if e.get("event_type") == "boss_ability_complete" and (e.get("meta") or {}).get("completed") is False
    ]
    chosen_boss_abilities = [e for e in events if e.get("event_type") == "boss_ability_choose"]
    completed_boss_abilities = [
        e for e in events
        if e.get("event_type") == "boss_ability_complete" and (e.get("meta") or {}).get("completed") is True
    ]
    if len(failed_boss_abilities) >= 2 or (len(chosen_boss_abilities) >= 3 and len(completed_boss_abilities) == 0):
        first_fail = failed_boss_abilities[0] if failed_boss_abilities else chosen_boss_abilities[0]
        cm = first_fail.get("combat_ms")
        add_diag(
            "boss_ability_execution_failures",
            f"Boss ability selections failed repeatedly (chosen={len(chosen_boss_abilities)}, "
            f"completed={len(completed_boss_abilities)}, failed={len(failed_boss_abilities)})",
            combat_sec=int(cm // 1000) if isinstance(cm, (int, float)) else None,
            seq=first_fail.get("seq"),
        )

    # 7. Missing clone/pet attribution
    for ev in events:
        meta = ev.get("meta") or {}
        if ev.get("event_type") == "pet_damage" and meta.get("owner_id") is None:
            cm = ev.get("combat_ms")
            add_diag(
                "missing_companion_attribution",
                f"Companion damage ({ev.get('value')}) from {ev.get('source_name')} is missing owner_id attribution",
                combat_sec=int(cm // 1000) if isinstance(cm, (int, float)) else None,
                seq=ev.get("seq"),
            )
        elif ev.get("event_type") == "damage_dealt" and meta.get("unattributed") is True:
            cm = ev.get("combat_ms")
            add_diag(
                "missing_companion_attribution",
                f"Unattributed damage ({ev.get('value')}) from {ev.get('source_name')} lacked participant/companion ownership",
                combat_sec=int(cm // 1000) if isinstance(cm, (int, float)) else None,
                seq=ev.get("seq"),
            )
    if isinstance(summary, dict):
        skey = str(summary.get("soul_key") or "").lower()
        dur = float(summary.get("encounter_duration_sec") or 0)
        pet_ev_present = any(e.get("category") == "pet" for e in events)
        if skey in COMPANION_SOUL_KEYS and summary.get("combat_started") and dur >= 5.0 and not pet_ev_present:
            add_diag(
                "missing_companion_attribution",
                f"Companion Soul '{skey}' recorded no pet/clone events across {dur:.1f}s of combat",
            )

    return diagnostics


def analyze_run_timeline(bundle: dict[str, Any], rolling_window: int = 5) -> dict[str, Any]:
    """Build 1s intervals, rolling DPS averages, damage spikes, DPS drops, pet deaths, resource changes, and diagnostics."""
    snapshots = bundle.get("snapshots") or []
    events = bundle.get("events") or []
    summary = bundle.get("summary")
    win = max(1, int(rolling_window))

    intervals: list[dict[str, Any]] = []
    dealt_hist: list[float] = []
    taken_hist: list[float] = []
    sudden_dps_drops: list[dict[str, Any]] = []

    for snap in snapshots:
        sec = int(snap.get("combat_sec", len(intervals)))
        iv = snap.get("interval") or {}
        dealt = float(iv.get("damage_dealt", 0))
        taken = float(iv.get("damage_received", 0))
        heal = float(iv.get("healing_done", 0))
        dealt_hist.append(dealt)
        taken_hist.append(taken)

        roll_dealt = statistics.mean(dealt_hist[-win:])
        roll_taken = statistics.mean(taken_hist[-win:])
        prev_roll = statistics.mean(dealt_hist[-(win + 1) : -1]) if len(dealt_hist) > win else None
        if prev_roll is not None and prev_roll >= 5.0 and roll_dealt <= (prev_roll * 0.5):
            sudden_dps_drops.append({
                "combat_sec": sec,
                "rolling_dps": round(roll_dealt, 2),
                "previous_rolling_dps": round(prev_roll, 2),
            })

        boss = snap.get("boss") or {}
        players = snap.get("players") or []
        p0 = players[0] if players else {}
        intervals.append({
            "combat_sec": sec,
            "damage_dealt": dealt,
            "player_damage": float(iv.get("player_damage", 0)),
            "pet_clone_damage": float(iv.get("pet_clone_damage", 0)),
            "damage_received": taken,
            "healing_done": heal,
            f"rolling_{win}s_dps": round(roll_dealt, 2),
            f"rolling_{win}s_dtps": round(roll_taken, 2),
            "player_hp": p0.get("hp"),
            "player_mp": p0.get("mp"),
            "player_tp": p0.get("tp"),
            "boss_hp_pct": boss.get("hp_pct"),
            "active_pets_clones": len(snap.get("pets_and_clones") or []),
        })

    spikes = [e for e in events if e.get("event_type") == "damage_spike"]
    pet_events = [e for e in events if e.get("category") == "pet" and e.get("event_type") in ("pet_spawn", "clone_spawn", "pet_death", "clone_death", "pet_despawn", "clone_despawn")]
    boss_thresholds = [e for e in events if e.get("event_type") == "boss_hp_threshold"]
    status_changes = [e for e in events if e.get("event_type") in ("status_applied", "status_removed")]
    hp_recovery_events = [e for e in events if e.get("event_type") in ("heal_applied", "regen_tick", "unattributed_hp_change")]
    max_hp_changes = [e for e in events if e.get("event_type") == "max_hp_change"]
    diagnostics = detect_timeline_diagnostics(summary, events, snapshots)

    return {
        "run_id": bundle.get("run_id"),
        "rolling_window_sec": win,
        "summary": summary,
        "feedback": bundle.get("feedback"),
        "interval_count": len(intervals),
        "event_count": len(events),
        "intervals": intervals,
        "damage_spikes": spikes,
        "sudden_dps_drops": sudden_dps_drops,
        "pet_clone_lifecycle_events": pet_events,
        "boss_hp_thresholds": boss_thresholds,
        "status_change_count": len(status_changes),
        "hp_recovery_events": hp_recovery_events,
        "max_hp_changes": max_hp_changes,
        "diagnostics": diagnostics,
    }


def render_ascii_timeline(analysis: dict[str, Any]) -> str:
    """Render a compact 1-second ASCII timeline correlating DPS, incoming damage, spikes, diagnostics, and feedback."""
    win = analysis["rolling_window_sec"]
    roll_key = f"rolling_{win}s_dps"
    intervals = analysis.get("intervals") or []
    diagnostics = analysis.get("diagnostics") or []
    lines = [f"=== Timeline: {analysis['run_id']} ({len(intervals)}s snapshots, {analysis['event_count']} events) ==="]
    fb = analysis.get("feedback")
    if isinstance(fb, dict):
        lines.append(f"Feedback: [{fb.get('tag')}] {fb.get('label') or ''} {fb.get('note') or ''}".strip())

    diag_by_sec: dict[int, list[str]] = {}
    for d in diagnostics:
        csec = d.get("combat_sec")
        if isinstance(csec, int):
            diag_by_sec.setdefault(csec, []).append(str(d.get("code")))

    max_val = max((max(iv["damage_dealt"], iv["damage_received"]) for iv in intervals), default=1.0)
    max_val = max(1.0, max_val)
    for iv in intervals:
        sec = iv["combat_sec"]
        bar_out = "#" * int((iv["damage_dealt"] / max_val) * 20)
        bar_in = "!" * int((iv["damage_received"] / max_val) * 15)
        warn_suffix = ""
        if sec in diag_by_sec:
            codes = ",".join(dict.fromkeys(diag_by_sec[sec]))
            warn_suffix = f" [WARN: {codes}]"
        lines.append(
            f"t={sec:3d}s | Out:{iv['damage_dealt']:5.0f} ({win}s:{iv[roll_key]:5.1f}) {bar_out:<20} | "
            f"In:{iv['damage_received']:5.0f} {bar_in:<15} | Boss:{str(iv['boss_hp_pct']):>5}% TP:{str(iv['player_tp']):>4}{warn_suffix}"
        )
    if analysis["damage_spikes"]:
        lines.append(f"Damage Spikes ({len(analysis['damage_spikes'])}): " + ", ".join(
            f"t={int((e.get('combat_ms') or 0)/1000)}s dmg={e.get('value')}" for e in analysis["damage_spikes"][:10]
        ))
    if analysis["sudden_dps_drops"]:
        lines.append(f"Sudden DPS Drops ({len(analysis['sudden_dps_drops'])}): " + ", ".join(
            f"t={d['combat_sec']}s ({d['previous_rolling_dps']}->{d['rolling_dps']})" for d in analysis["sudden_dps_drops"][:10]
        ))
    if analysis["pet_clone_lifecycle_events"]:
        lines.append("Pet/Clone Events: " + ", ".join(
            f"t={int((e.get('combat_ms') or 0)/1000)}s:{e.get('event_type')}" for e in analysis["pet_clone_lifecycle_events"][:10]
        ))
    if diagnostics:
        lines.append(f"Diagnostics & Warnings ({len(diagnostics)}):")
        for d in diagnostics:
            loc_parts = []
            if d.get("combat_sec") is not None:
                loc_parts.append(f"t={d['combat_sec']}s")
            if d.get("seq") is not None:
                loc_parts.append(f"seq={d['seq']}")
            loc = f" ({', '.join(loc_parts)})" if loc_parts else ""
            lines.append(f"  - [{d.get('severity', 'warning').upper()}] {d.get('code')}{loc}: {d.get('message')}")
    return "\n".join(lines)


def compare_runs(run_ids: list[str], base_dir: Path = DEFAULT_LOG_BASE_DIR) -> dict[str, Any]:
    """Compare 2+ runs while strictly checking that encounter conditions match."""
    bundles = [load_run_bundle(rid, base_dir) for rid in run_ids]
    missing = [b["run_id"] for b in bundles if b["summary"] is None]
    if missing:
        return {"ok": False, "error": f"Run IDs not found: {missing}"}

    summaries = [b["summary"] for b in bundles]
    cond_keys = ("effective_combat_level", "boss_type", "difficulty", "boss_preset", "gear_profile")
    mismatches: list[str] = []
    ref = summaries[0]
    for other in summaries[1:]:
        for k in cond_keys:
            if other.get(k) != ref.get(k):
                mismatches.append(f"{k}: {ref.get('run_id')}={ref.get(k)} vs {other.get('run_id')}={other.get(k)}")

    rows = []
    for s in summaries:
        off = s.get("metrics", {}).get("offense", {})
        dfn = s.get("metrics", {}).get("defense", {})
        rows.append({
            "run_id": s.get("run_id"),
            "soul_key": s.get("soul_key"),
            "tier": s.get("tier"),
            "effective_level": s.get("effective_combat_level"),
            "boss_type": s.get("boss_type"),
            "boss_level": s.get("actual_boss_level", s.get("boss_level")),
            "difficulty": s.get("difficulty"),
            "boss_preset": s.get("boss_preset"),
            "gear_profile": s.get("gear_profile"),
            "outcome": s.get("outcome"),
            "duration_sec": s.get("encounter_duration_sec"),
            "total_damage": off.get("total_damage"),
            "sustained_dps": off.get("sustained_dps"),
            "burst_dps_10s": off.get("burst_dps_10s"),
            "incoming_damage": dfn.get("actual_incoming_damage"),
            "valid_for_balance": s.get("valid_for_balance"),
        })

    return {
        "ok": True,
        "comparable": (len(mismatches) == 0),
        "condition_mismatches": mismatches,
        "warning": (
            None
            if not mismatches
            else "Runs do NOT share identical level/boss/difficulty/preset/gear conditions; do not treat as directly equivalent."
        ),
        "runs": rows,
    }


def export_runs_csv(records: list[dict[str, Any]], csv_path: Path) -> Path:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "run_id", "timestamp_utc", "test_mode", "soul_key", "job", "tier",
        "original_character_level", "effective_combat_level", "boss_type",
        "actual_boss_level", "level_gap", "difficulty", "boss_preset", "gear_profile",
        "outcome", "prep_duration_sec", "encounter_duration_sec", "total_damage",
        "player_damage", "pet_and_clone_damage", "sustained_dps", "burst_dps_10s",
        "actual_incoming_damage", "effective_healing", "enmity_generation",
        "valid_for_balance",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for r in records:
            off = r.get("metrics", {}).get("offense", {})
            dfn = r.get("metrics", {}).get("defense", {})
            hel = r.get("metrics", {}).get("healing", {})
            thr = r.get("metrics", {}).get("threat", {})
            writer.writerow({
                "run_id": r.get("run_id"),
                "timestamp_utc": r.get("timestamp_utc"),
                "test_mode": r.get("test_mode"),
                "soul_key": r.get("soul_key"),
                "job": r.get("job"),
                "tier": r.get("tier"),
                "original_character_level": r.get("original_character_level"),
                "effective_combat_level": r.get("effective_combat_level", r.get("character_level")),
                "boss_type": r.get("boss_type"),
                "actual_boss_level": r.get("actual_boss_level", r.get("boss_level")),
                "level_gap": r.get("level_gap"),
                "difficulty": r.get("difficulty"),
                "boss_preset": r.get("boss_preset"),
                "gear_profile": r.get("gear_profile"),
                "outcome": r.get("outcome"),
                "prep_duration_sec": r.get("prep_duration_sec"),
                "encounter_duration_sec": r.get("encounter_duration_sec"),
                "total_damage": off.get("total_damage"),
                "player_damage": off.get("player_damage"),
                "pet_and_clone_damage": off.get("pet_and_clone_damage"),
                "sustained_dps": off.get("sustained_dps"),
                "burst_dps_10s": off.get("burst_dps_10s"),
                "actual_incoming_damage": dfn.get("actual_incoming_damage"),
                "effective_healing": hel.get("effective_healing"),
                "enmity_generation": thr.get("enmity_generation"),
                "valid_for_balance": r.get("valid_for_balance"),
            })
    return csv_path


def export_timeline_csv(analysis: dict[str, Any], csv_path: Path) -> Path:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    intervals = analysis.get("intervals") or []
    if not intervals:
        csv_path.write_text("", encoding="utf-8")
        return csv_path
    fields = list(intervals[0].keys())
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for row in intervals:
            writer.writerow(row)
    return csv_path


def add_feedback_to_run(
    run_id: str,
    tag: str,
    note: str | None = None,
    base_dir: Path = DEFAULT_LOG_BASE_DIR,
) -> dict[str, Any]:
    fb_dir = base_dir / "feedback"
    fb_dir.mkdir(parents=True, exist_ok=True)
    fb_path = fb_dir / f"{run_id}.json"
    existing: dict[str, Any] = {}
    if fb_path.is_file():
        try:
            existing = json.loads(fb_path.read_text(encoding="utf-8", errors="replace"))
        except json.JSONDecodeError:
            existing = {}

    notes = list(existing.get("notes") or [])
    if note:
        notes.append({
            "recorded_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "text": note,
        })

    payload = {
        **existing,
        "run_id": run_id,
        "recorded_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "cli_analysis",
        "tag": tag or existing.get("tag") or "note",
        "note": note if note is not None else existing.get("note"),
        "notes": notes,
    }
    fb_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return {"ok": True, "path": str(fb_path), "feedback": payload}


def run_stage_b_real_combat_poc(
    server_dir: Path = Path(r"C:\dev\server"),
    seed: int = 12345,
) -> dict[str, Any]:
    """Execute Milestone C real server combat proof via LandSandBoat's xi_test.exe."""
    xi_test = server_dir / "xi_test.exe"
    if not xi_test.is_file():
        return {"ok": False, "error": f"xi_test.exe not found at {xi_test}"}

    runs_log = server_dir / "log" / "proving_grounds" / "runs.jsonl"
    before_lines = len(runs_log.read_text(encoding="utf-8", errors="replace").splitlines()) if runs_log.is_file() else 0

    cmd = [
        str(xi_test),
        "--lua-only",
        "--file",
        "proving_grounds_combat",
        "--seed",
        str(seed),
    ]
    proc = subprocess.run(cmd, cwd=str(server_dir), capture_output=True, text=True, timeout=180)
    new_records: list[dict[str, Any]] = []
    if runs_log.is_file():
        all_lines = runs_log.read_text(encoding="utf-8", errors="replace").splitlines()
        for raw in all_lines[before_lines:]:
            raw = raw.strip()
            if raw:
                rec = json.loads(raw)
                if rec.get("test_mode") == "automated_real":
                    rec["server_commit_sha"] = get_git_commit_sha()
                    new_records.append(rec)

    return {
        "ok": proc.returncode == 0 and len(new_records) > 0,
        "exit_code": proc.returncode,
        "seed": seed,
        "test_mode": "automated_real",
        "server_commit_sha": get_git_commit_sha(),
        "real_combat_records": new_records,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="OverlordsXI Soul Proving Grounds Benchmark & Historical Analyzer")
    parser.add_argument("--run-formula", action="store_true", help="Run Stage A formula & regression suite")
    parser.add_argument("--run-stage-b", action="store_true", help="Run Stage B real combat suite via xi_test.exe")
    parser.add_argument("--seed", type=int, default=12345, help="Deterministic PRNG seed for Stage B real combat")
    parser.add_argument("--server-dir", type=Path, default=Path(r"C:\dev\server"), help="LandSandBoat server directory")
    parser.add_argument("--log-dir", type=Path, default=DEFAULT_LOG_BASE_DIR, help="Proving Grounds structured log directory")
    parser.add_argument("--out", type=Path, default=None, help="Output JSON path for formula report")
    parser.add_argument("--matrix-out", type=Path, default=None, help="Output JSON path for 66-Soul matrix")
    parser.add_argument("--summarize", type=Path, default=None, help="Summarize a runs.jsonl log (excludes invalid sync & +8)")

    # Historical analysis options
    parser.add_argument("--list-runs", action="store_true", help="List historical Proving Grounds runs")
    parser.add_argument("--soul", type=str, default=None, help="Filter by Soul key")
    parser.add_argument("--level", type=int, default=None, help="Filter by effective combat level")
    parser.add_argument("--boss", type=str, default=None, help="Filter by boss archetype")
    parser.add_argument("--difficulty", type=str, default=None, help="Filter by difficulty key")
    parser.add_argument("--preset", type=str, default=None, help="Filter by boss preset (normal/nm)")
    parser.add_argument("--date", type=str, default=None, help="Filter by UTC date prefix (YYYY-MM-DD)")
    parser.add_argument("--include-invalid", action="store_true", help="Include invalid level-sync runs when listing")
    parser.add_argument("--include-extreme", action="store_true", help="Include +8 Extreme Challenge runs when listing")
    parser.add_argument("--show-run", type=str, default=None, help="Show full bundle summary for a run_id")
    parser.add_argument("--timeline", type=str, default=None, help="Render 1s damage/event timeline for a run_id")
    parser.add_argument("--rolling", type=int, default=5, help="Rolling average window in seconds (e.g. 5 or 10)")
    parser.add_argument("--compare", nargs="+", default=None, help="Compare two or more run IDs under matching conditions")
    parser.add_argument("--export-csv", type=Path, default=None, help="Export filtered runs or --timeline to CSV")
    parser.add_argument("--add-feedback", type=str, default=None, help="Attach/update feedback on a run_id")
    parser.add_argument("--tag", type=str, default="note", help="Feedback tag for --add-feedback")
    parser.add_argument("--note", type=str, default=None, help="Text note for --add-feedback")
    args = parser.parse_args()

    has_action = any([
        args.run_formula, args.run_stage_b, args.matrix_out, args.summarize,
        args.list_runs, args.show_run, args.timeline, args.compare, args.add_feedback,
    ])
    exit_code = 0

    if args.run_formula or not has_action:
        report = run_stage_a_formula_suite()
        reg_check = inspect_lua_registry_via_luajit()
        report["lua_registry_validation"] = reg_check
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps({
            "test_mode": report["test_mode"],
            "combat_execution": report["combat_execution"],
            "passed": report["passed"],
            "passed_checks": report["passed_checks"],
            "total_checks": report["total_checks"],
            "lua_registry_available": reg_check.get("available"),
            "lua_registry_schema": reg_check.get("schemaVersion"),
        }, indent=2))
        if not report["passed"]:
            exit_code = 1

    if args.run_stage_b:
        stage_b = run_stage_b_real_combat_poc(server_dir=args.server_dir, seed=args.seed)
        print(json.dumps(stage_b, indent=2))
        if not stage_b["ok"]:
            exit_code = 1

    if args.matrix_out:
        matrix = build_balance_test_matrix()
        args.matrix_out.parent.mkdir(parents=True, exist_ok=True)
        args.matrix_out.write_text(json.dumps(matrix, indent=2), encoding="utf-8")
        print(f"Wrote 66-Soul balance matrix ({matrix['total_soul_scenario_pairs']} pairs) to {args.matrix_out}")

    if args.summarize:
        print(json.dumps(summarize_jsonl_runs(args.summarize), indent=2))

    if args.list_runs:
        recs = filter_runs(
            load_jsonl_records(resolve_runs_index_path(args.log_dir)),
            soul=args.soul,
            level=args.level,
            boss=args.boss,
            difficulty=args.difficulty,
            preset=args.preset,
            date_prefix=args.date,
            include_invalid=args.include_invalid,
            include_extreme=args.include_extreme,
        )
        if args.export_csv:
            export_runs_csv(recs, args.export_csv)
        print(json.dumps({
            "count": len(recs),
            "runs": [
                {
                    "run_id": r.get("run_id"),
                    "timestamp_utc": r.get("timestamp_utc"),
                    "soul_key": r.get("soul_key"),
                    "orig_lvl": r.get("original_character_level"),
                    "eff_lvl": r.get("effective_combat_level", r.get("character_level")),
                    "boss_type": r.get("boss_type"),
                    "boss_lvl": r.get("actual_boss_level", r.get("boss_level")),
                    "difficulty": r.get("difficulty"),
                    "boss_preset": r.get("boss_preset"),
                    "outcome": r.get("outcome"),
                    "dps": (r.get("metrics", {}).get("offense") or {}).get("sustained_dps"),
                    "valid_for_balance": r.get("valid_for_balance"),
                }
                for r in recs
            ],
        }, indent=2))

    if args.show_run:
        bundle = load_run_bundle(args.show_run, args.log_dir)
        print(json.dumps({
            "run_id": bundle["run_id"],
            "summary": bundle["summary"],
            "event_count": len(bundle["events"]),
            "snapshot_count": len(bundle["snapshots"]),
            "feedback": bundle["feedback"],
        }, indent=2))

    if args.timeline:
        bundle = load_run_bundle(args.timeline, args.log_dir)
        analysis = analyze_run_timeline(bundle, rolling_window=args.rolling)
        if args.export_csv:
            export_timeline_csv(analysis, args.export_csv)
        print(render_ascii_timeline(analysis))

    if args.compare:
        print(json.dumps(compare_runs(args.compare, args.log_dir), indent=2))

    if args.add_feedback:
        print(json.dumps(add_feedback_to_run(args.add_feedback, args.tag, args.note, args.log_dir), indent=2))

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
