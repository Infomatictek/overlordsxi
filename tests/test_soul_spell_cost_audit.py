"""Regression tests for the Global 66-Soul Spell Cost & Level Compatibility Audit."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATCH_0072 = ROOT / "patches/0072-dreadnought-spell-mp-cost.patch"
PATCH_0073 = ROOT / "patches/0073-soul-spell-cost-audit-fixes.patch"
DRK_LUA = ROOT / "modules/custom/lua/drk_specs.lua"
BLU_LUA = ROOT / "modules/custom/lua/blu_specs.lua"
BLU_HEALER_LUA = ROOT / "modules/custom/lua/blu_healer_specs.lua"
RUN_LUA = ROOT / "modules/custom/lua/run_specs.lua"
NIN_LUA = ROOT / "modules/custom/lua/nin_specs.lua"
TERRAMANCER_LUA = ROOT / "modules/custom/lua/geo_terramancer_specs.lua"
AUDIT_DOC = ROOT / "docs/audits/SOUL_SPELL_COST_AUDIT.md"
REAL_ENGINE_SUITE = ROOT / "tests/lua/soul_spell_cost_audit.lua"


def magus_scaled_mp(lvl: int, req_lvl: int, base_mp: int) -> int:
    if lvl >= req_lvl:
        return base_mp
    ratio = min(1.0, max(0.20, lvl / req_lvl))
    return max(4, int(base_mp * ratio + 0.5))


def runic_cost(is_sever: bool, lvl: int, stacks: int) -> int:
    l = max(10, min(75, lvl))
    if is_sever:
        base = 32 if l <= 55 else 32 + int(((l - 55) * 8.0) / 20.0 + 0.5)
    else:
        base = 8 if l <= 15 else 8 + int(((l - 15) * 16.0) / 60.0 + 0.5)
    factor = 1.0 - 0.15 * max(0, min(3, stacks))
    return max(1, int(base * factor) if is_sever else int(base * factor + 0.5))


class SoulSpellCostAuditTests(unittest.TestCase):
    def test_dreadnought_fix_remains_intact(self):
        patch = PATCH_0072.read_text(encoding="utf-8")
        lua_src = DRK_LUA.read_text(encoding="utf-8")
        self.assertIn('caster->GetLocalVar("OX_DRN_SCYTHE") == 1', patch)
        self.assertIn("if (m_spellId == static_cast<SpellID>(246)) m_PSpell->setMPCost(12);", patch)
        self.assertIn("if (m_spellId == static_cast<SpellID>(277)) m_PSpell->setMPCost(0);", patch)
        self.assertIn("player:setLocalVar('OX_DRN_SCYTHE', 1)", lua_src)
        self.assertIn("player:setLocalVar('OX_DRN_SCYTHE', 0)", lua_src)
        # Dread Spikes retains 10% current HP cost and >15% HP casting check
        self.assertIn("dread_spikes.onMagicCastingCheck", lua_src)
        self.assertIn("dread_spikes.onSpellCast", lua_src)

    def test_azure_bastion_surge_and_discounts_run_before_has_cost_without_double_discount(self):
        patch = PATCH_0073.read_text(encoding="utf-8")
        lua_src = BLU_LUA.read_text(encoding="utf-8")
        self.assertIn('caster->GetLocalVar("OX_AZB_ACTIVE") == 1', patch)
        self.assertIn("HasStatusEffect(static_cast<xi::StatusEffect>(858))", patch)
        self.assertIn("m_PSpell->setMPCost(0);", patch)
        self.assertIn("m_PSpell->setCastTime(0ms);", patch)
        self.assertIn("sid == 623 || sid == 692 || sid == 529 || sid == 527 || sid == 688 || sid == 666", patch)
        self.assertIn("xi::StatusEffect::AzureLore", patch)

        self.assertIn("player:setLocalVar('OX_AZB_ACTIVE', 1)", lua_src)
        self.assertIn("player:setLocalVar('OX_AZB_ACTIVE', 0)", lua_src)
        # Ensure OX_BLU_MAGIC_START no longer calls setMPCost (preventing double discount)
        m = re.search(r"addListener\('MAGIC_START',\s*'OX_BLU_MAGIC_START'.*?^\s{4}end\)", lua_src, re.M | re.S)
        self.assertIsNotNone(m)
        self.assertNotIn("setMPCost", m.group(0))

    def test_magus_scales_on_clone_and_never_mutates_in_can_use_spell_override(self):
        patch = PATCH_0073.read_text(encoding="utf-8")
        lua_src = BLU_HEALER_LUA.read_text(encoding="utf-8")
        self.assertIn('caster->GetLocalVar("OX_MAG_ACTIVE") == 1', patch)
        self.assertIn("kMagusBaseline", patch)
        self.assertIn("player:setLocalVar('OX_MAG_ACTIVE', 1)", lua_src)
        self.assertIn("player:setLocalVar('OX_MAG_ACTIVE', 0)", lua_src)

        # Verify canUseSpellOverride is strictly read-only (no spell:setMPCost)
        m = re.search(r"m:addOverride\('xi\.spells\.canUseSpellOverride'.*?^end\)", lua_src, re.M | re.S)
        self.assertIsNotNone(m)
        self.assertNotIn("setMPCost", m.group(0))

        # Verify all 17 baseline spells match representative levels 10, 30, 50, 75
        self.assertEqual(magus_scaled_mp(10, 94, 145), 29)   # White Wind Lv10
        self.assertEqual(magus_scaled_mp(30, 94, 145), 46)   # White Wind Lv30
        self.assertEqual(magus_scaled_mp(50, 94, 145), 77)   # White Wind Lv50
        self.assertEqual(magus_scaled_mp(75, 94, 145), 116)  # White Wind Lv75
        self.assertEqual(magus_scaled_mp(10, 58, 72), 14)    # Magic Fruit Lv10
        self.assertEqual(magus_scaled_mp(58, 58, 72), 72)    # Magic Fruit at vanilla unlock

    def test_run_spellblade_conduction_discount_applies_before_has_cost(self):
        patch = PATCH_0073.read_text(encoding="utf-8")
        lua_src = RUN_LUA.read_text(encoding="utf-8")
        self.assertIn('caster->GetLocalVar("OX_RUN_SPELLBLADE") == 1', patch)
        self.assertIn("(sid == 363 || sid == 364)", patch)
        self.assertIn('caster->GetLocalVar("OX_RUN_CONDUCTION")', patch)
        self.assertIn("player:setLocalVar('OX_RUN_SPELLBLADE', 0)", lua_src)

        # Verify representative levels 10, 30, 50, 55, 75 across 0..3 Conduction stacks
        self.assertEqual(runic_cost(False, 10, 0), 8)
        self.assertEqual(runic_cost(False, 10, 3), 4)
        self.assertEqual(runic_cost(False, 30, 0), 12)
        self.assertEqual(runic_cost(False, 50, 0), 17)
        self.assertEqual(runic_cost(False, 75, 0), 24)
        self.assertEqual(runic_cost(False, 75, 3), 13)
        self.assertEqual(runic_cost(True, 55, 0), 32)
        self.assertEqual(runic_cost(True, 55, 3), 17)
        self.assertEqual(runic_cost(True, 75, 0), 40)
        self.assertEqual(runic_cost(True, 75, 3), 22)

    def test_kagemusha_zero_tool_kit_covers_all_10_spells_with_dual_katanas(self):
        patch = PATCH_0073.read_text(encoding="utf-8")
        lua_src = NIN_LUA.read_text(encoding="utf-8")
        self.assertIn('PChar->GetLocalVar("OX_KGM_DUAL_KATANA") == 1', patch)
        self.assertIn("isKagemushaKitSpell", patch)
        for spell_enum in [
            "SpellID::Katon_Ichi", "SpellID::Hyoton_Ichi", "SpellID::Huton_Ichi",
            "SpellID::Doton_Ichi", "SpellID::Raiton_Ichi", "SpellID::Suiton_Ichi",
            "SpellID::Utsusemi_Ichi", "SpellID::Utsusemi_Ni",
            "SpellID::Hojo_Ichi", "SpellID::Kurayami_Ichi",
        ]:
            self.assertIn(spell_enum, patch)
        self.assertIn("player:setLocalVar('OX_KGM_DUAL_KATANA', 1)", lua_src)
        self.assertIn("player:setLocalVar('OX_KGM_DUAL_KATANA', 0)", lua_src)

    def test_failed_casts_do_not_consume_terramancer_mp(self):
        lua_src = TERRAMANCER_LUA.read_text(encoding="utf-8")
        self.assertIn("canPlace(player, target, deep)", lua_src)
        self.assertIn("player:delMP(mpCost(player, deep))", lua_src)
        # delMP only happens inside place(), which is called from onSpellCast, never onMagicCastingCheck
        check_idx = lua_src.index(".onMagicCastingCheck")
        delmp_idx = lua_src.index("player:delMP(mpCost(player, deep))")
        place_idx = lua_src.index("local function place(")
        self.assertLess(place_idx, delmp_idx)
        self.assertLess(delmp_idx, check_idx)

    def test_audit_report_and_real_engine_suite_exist(self):
        self.assertTrue(AUDIT_DOC.exists(), "docs/audits/SOUL_SPELL_COST_AUDIT.md must exist")
        doc = AUDIT_DOC.read_text(encoding="utf-8")
        self.assertIn("Dreadnought", doc)
        self.assertIn("Azure Bastion", doc)
        self.assertIn("Magus", doc)
        self.assertIn("Spellblade", doc)
        self.assertIn("Kagemusha", doc)
        self.assertTrue(REAL_ENGINE_SUITE.exists(), "tests/lua/soul_spell_cost_audit.lua must exist")


if __name__ == "__main__":
    unittest.main()
