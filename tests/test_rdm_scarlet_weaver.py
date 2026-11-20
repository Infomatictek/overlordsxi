"""Ensure Scarlet Weaver's forms affect only their intended damage paths."""
import unittest
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/rdm_scarlet_weaver_specs.lua"
PATCH = ROOT / "patches/0050-scarlet-weaver-native-actions.patch"


class ScarletWeaverNativeTests(unittest.TestCase):
    def test_yang_scopes_and_action_boundary(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("character->GetLocalVar(\"OX_SCW_ASPECT\") != 2", patch)
        self.assertIn("weapon->getSkillType() == xi::SkillType::Sword", patch)
        self.assertIn("weaponSlot == SLOT_MAIN && attack.GetAttackType() == PHYSICAL_ATTACK_TYPE::NORMAL", patch)
        self.assertIn("m_scarletAbility != currentScarlet", patch)
        self.assertIn("m_scarletCast == scarlet::isActive(caster)", patch)
        self.assertIn("case SpellID::Aero_III:   return { 70, 12 };", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ScarletWeaverRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides = 100, {}
            Module = { new = function() return { addOverride = function(_, path, fn) overrides[path] = fn end } end }
            for _, module in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs',
                'scripts/globals/player', 'scripts/globals/spells/damage_spell',
            }) do
                package.preload[module] = function() return {} end
            end
            xi = {
                job = { RDM = 5 }, mod = { SWORD = 1, ACC = 2, DEX = 3, INT = 4, MATT = 5 },
                msg = { basic = { CANNOT_CAST_SPELL = 1, UNABLE_TO_USE_JA = 87 } },
                soulspire = {
                    nowSec = function() return now end,
                    spec = {
                        is = function(p, _, key) return p.key == key end,
                        registerCrystal = function(_, entry) crystal = entry end,
                    },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            super = function() return 123 end
            player = {
                key = 'scarletweaver', level = 10, engaged = false, enmity = false, vars = {},
                isPC = function() return true end,
                getMainJob = function() return 5 end,
                getMainLvl = function(self) return self.level end,
                isEngaged = function(self) return self.engaged end,
                hasEnmity = function(self) return self.enmity end,
                getLocalVar = function(self, k) return self.vars[k] or 0 end,
                setLocalVar = function(self, k, v) self.vars[k] = v end,
                sendSoulSpellList = function() end,
            }
            spell = {
                id = 144, getID = function(self) return self.id end,
                setCastTime = function(self, ms) self.ms = ms end,
            }
            ability = {
                setRecast = function(self, sec) self.recast = sec end,
                setCE = function() end, setVE = function() end,
            }
            mob = { isMob = function() return true end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))

    def test_default_yang_free_swap_and_shared_combat_recovery(self):
        self.lua.execute("""
            crystal.onApply(player)
            assert(hud(player).form == 2 and hud(player).bonus == 15)
            local yin = overrides['xi.actions.abilities.composure.onAbilityCheck']
            local useYin = overrides['xi.actions.abilities.composure.onUseAbility']
            local yang = overrides['xi.actions.abilities.saboteur.onAbilityCheck']
            local useYang = overrides['xi.actions.abilities.saboteur.onUseAbility']
            local damage = xi.soulspire.rdmScarletWeaverSpecs.adjustDamage
            assert(yin(player, player, ability) == 0 and ability.recast == 0)
            useYin(player, player, ability)
            assert(hud(player).switch_cd == 0 and damage(player, spell, 100) == 115)
            spell.id = 147
            assert(damage(player, spell, 100) == 100)
            spell.id, player.enmity = 144, true
            useYang(player, player, ability)
            assert(hud(player).recovery_rem == 2 and hud(player).switch_cd == 12)
            assert(yin(player, player, ability) == 87)
            now = now + 12
            assert(yin(player, player, ability) == 0)
            useYin(player, player, ability)
            assert(damage(player, spell, 100) == 100)
            now = now + 2
            assert(damage(player, spell, 100) == 115 and damage(player, spell, -100) == -100)
            crystal.onRemove(player)
            player.key = 'crimsonduelist'
            assert(damage(player, spell, 100) == 100 and yin(player, player, ability) == 123)
        """)

    def test_level_gates(self):
        self.lua.execute("""
            local tempest = overrides['xi.actions.spells.black.aero_iii.onMagicCastingCheck']
            player.level = 50
            crystal.onApply(player)
            assert(tempest(player, mob, spell) == 1 and hud(player).bonus == 22)
            player.level = 75
            crystal.onApply(player)
            assert(tempest(player, mob, spell) == 0 and spell.ms == 3000 and hud(player).bonus == 25)
        """)
