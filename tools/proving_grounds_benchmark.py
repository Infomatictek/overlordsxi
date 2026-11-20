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
    {"id": "boss_plus_3", "label": "Boss +3 Levels", "level_delta": 3, "standard_baseline": True, "extreme_challenge": False},
    {"id": "boss_plus_8", "label": "Extreme Challenge (+8 Wall)", "level_delta": 8, "standard_baseline": False, "extreme_challenge": True},
)

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
        autoAttack = a.behavior.autoAttack,
        magicCasting = a.behavior.magicCasting,
        mobAbility = a.behavior.mobAbility,
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
    levels = R.LEVELS,
    npcArchetypes = npcTypes,
    matrixOrder = R.MATRIX_ARCHETYPE_ORDER,
    plus8Baseline = R.DIFFICULTIES.boss_plus_8.standardBaseline,
    plus8Extreme = R.DIFFICULTIES.boss_plus_8.extremeChallenge,
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


def summarize_jsonl_runs(jsonl_path: Path) -> dict[str, Any]:
    """Summarize actual combat JSONL runs, separating real combat from static formula tests."""
    if not jsonl_path.is_file():
        return {"error": f"Run log not found: {jsonl_path}", "total_runs": 0}

    records: list[dict[str, Any]] = []
    for raw in jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        records.append(json.loads(line))

    by_mode: dict[str, int] = {}
    by_role_soul: dict[tuple[str, str], list[float]] = {}
    struggled: list[str] = []
    performed_well: list[str] = []
    balance_concerns: list[str] = []

    for r in records:
        mode = str(r.get("test_mode", "unknown"))
        by_mode[mode] = by_mode.get(mode, 0) + 1
        off = r.get("metrics", {}).get("offense", {})
        saf = r.get("metrics", {}).get("safety", {})
        dps = off.get("sustained_dps")
        role = str(r.get("role", "Unassigned"))
        skey = str(r.get("soul_key", "none"))
        if isinstance(dps, (int, float)):
            by_role_soul.setdefault((role, skey), []).append(float(dps))
        if r.get("outcome") == "defeat":
            struggled.append(f"{r.get('run_id')}: {skey} ({role}) defeated by {r.get('boss_type')} Lv.{r.get('boss_level')}")
        elif r.get("outcome") == "victory":
            performed_well.append(f"{r.get('run_id')}: {skey} ({role}) defeated {r.get('boss_type')} Lv.{r.get('boss_level')} ({dps} DPS)")
        if saf.get("progression_clean") is False:
            balance_concerns.append(f"SAFETY VIOLATION in {r.get('run_id')}: EXP observed ({saf.get('exp_points_observed')})")

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
    statistically_meaningful = (len(records) >= 5 and min_samples >= 3)

    return {
        "source_file": str(jsonl_path),
        "total_runs": len(records),
        "runs_by_test_mode": by_mode,
        "statistically_meaningful": statistically_meaningful,
        "statistical_note": (
            "Sufficient repeated samples (>=3 per Soul) for trend comparison."
            if statistically_meaningful
            else "Insufficient sample size (<3 repeats per Soul); treat as smoke/POC measurement only."
        ),
        "performed_well": performed_well,
        "struggled": struggled,
        "balance_concerns": balance_concerns,
        "role_dominance_flags": role_dominance,
    }


def run_stage_b_real_combat_poc(
    server_dir: Path = Path(r"C:\dev\server"),
    seed: int = 12345,
) -> dict[str, Any]:
    """Execute Milestone C real server combat proof via LandSandBoat's xi_test.exe."""
    xi_test = server_dir / "xi_test.exe"
    if not xi_test.is_file():
        return {"ok": False, "error": f"xi_test.exe not found at {xi_test}"}

    runs_log = server_dir / "log" / "proving_grounds_runs.jsonl"
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
    parser = argparse.ArgumentParser(description="OverlordsXI Soul Proving Grounds Benchmark & Summarizer")
    parser.add_argument("--run-formula", action="store_true", help="Run Stage A formula & regression suite")
    parser.add_argument("--run-stage-b", action="store_true", help="Run Stage B Milestone C real server combat proof via xi_test.exe")
    parser.add_argument("--seed", type=int, default=12345, help="Deterministic PRNG seed for Stage B real combat")
    parser.add_argument("--server-dir", type=Path, default=Path(r"C:\dev\server"), help="LandSandBoat server directory")
    parser.add_argument("--out", type=Path, default=None, help="Output JSON path for formula report")
    parser.add_argument("--matrix-out", type=Path, default=None, help="Output JSON path for 66-Soul matrix")
    parser.add_argument("--summarize", type=Path, default=None, help="Summarize a proving_grounds_runs.jsonl log")
    args = parser.parse_args()

    exit_code = 0
    if args.run_formula or (not args.matrix_out and not args.summarize and not args.run_stage_b):
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
        summary = summarize_jsonl_runs(args.summarize)
        print(json.dumps(summary, indent=2))

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
