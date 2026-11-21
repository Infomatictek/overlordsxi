"""Focused regression tests for COR Flintlock ranged-only combat foundation."""
from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


class FlintlockRangedOnlyFoundationTests(unittest.TestCase):
    def test_patch_0074_contains_all_ranged_only_and_visual_hiding_hooks(self):
        patch_path = REPO_ROOT / "patches" / "0074-flintlock-ranged-only-combat.patch"
        self.assertTrue(patch_path.is_file(), "Missing patches/0074-flintlock-ranged-only-combat.patch")
        text = patch_path.read_text(encoding="utf-8")

        # 1. CAttackState blocks melee fallback when OX_RANGED_ONLY == 1
        self.assertIn("src/map/ai/states/attack_state.cpp", text)
        self.assertIn('GetLocalVar("OX_RANGED_ONLY") == 1', text)
        self.assertIn("tryAutoRanged(true);", text)

        # 2. CWeaponSkillState blocks melee WS while allowing Marksmanship/Archery/Throwing WS
        self.assertIn("src/map/ai/states/weaponskill_state.cpp", text)
        self.assertIn("xi::SkillType::Marksmanship", text)
        self.assertIn("MsgBasic::CannotUseWeaponskill", text)

        # 3. Configurable damage & TP scaling in battle_entity.cpp and battleutils.cpp
        self.assertIn("src/map/entities/battle_entity.cpp", text)
        self.assertIn('GetLocalVar("OX_AUTO_RANGED_DMG_PCT")', text)
        self.assertIn("src/map/utils/battleutils.cpp", text)
        self.assertIn('GetLocalVar("OX_AUTO_RANGED_TP_PCT")', text)

        # 4. Main/Sub melee model hiding in all 3 appearance packets + instant refresh on toggle
        for pkt_file in (
            "src/map/packets/s2c/0x051_grap_list.cpp",
            "src/map/packets/s2c/0x00a_login.cpp",
            "src/map/packets/char_update.cpp",
        ):
            self.assertIn(pkt_file, text)
        self.assertIn('GetLocalVar("OX_HIDE_MELEE_LOOK") == 1', text)
        self.assertIn("hideMelee ? 0x6000 : look->main + 0x6000", text)
        self.assertIn("hideMelee ? 0x7000 : look->sub + 0x7000", text)
        self.assertIn("src/map/lua/lua_base_entity.cpp", text)
        self.assertIn("PChar->updatemask |= UPDATE_LOOK;", text)
        self.assertIn("GP_SERV_COMMAND_GRAP_LIST", text)

    def test_lua_syntax_and_flintlock_spec_configuration(self):
        cor_specs = (REPO_ROOT / "modules" / "custom" / "lua" / "cor_specs.lua").read_text(encoding="utf-8")
        job_specs = (REPO_ROOT / "modules" / "custom" / "lua" / "soulspire_job_specs.lua").read_text(encoding="utf-8")

        self.assertIn("rangedOnly    = true", cor_specs)
        self.assertIn("hideMeleeLook = true", cor_specs)
        self.assertIn("damagePct     = 100", cor_specs)
        self.assertIn("tpPct         = 100", cor_specs)

        # Ensure soulspire_job_specs clears all 4 vars on spec removal and sets them cleanly on apply
        for var_name in (
            "OX_RANGED_ONLY",
            "OX_HIDE_MELEE_LOOK",
            "OX_AUTO_RANGED_DMG_PCT",
            "OX_AUTO_RANGED_TP_PCT",
        ):
            self.assertGreaterEqual(
                job_specs.count(var_name),
                3,
                f"Expected {var_name} to be cleared in removeAppliedMods, set in refreshPlayer, and cleared in else branch",
            )

        lua_bin = shutil.which("luajit") or shutil.which("lua")
        if lua_bin:
            for rel in ("modules/custom/lua/cor_specs.lua", "modules/custom/lua/soulspire_job_specs.lua"):
                proc = subprocess.run(
                    [lua_bin, "-bl", str(REPO_ROOT / rel)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(proc.returncode, 0, f"Lua syntax check failed for {rel}:\n{proc.stderr}")


if __name__ == "__main__":
    unittest.main()
