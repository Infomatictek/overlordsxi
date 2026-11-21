"""Verify Warmage's adaptive Blue Magic, virtual set and Soul isolation."""
from pathlib import Path
import re
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/blu_warmage_specs.lua"
PATCH = ROOT / "patches/0063-warmage-virtual-blue-kit.patch"


class WarmageNativeTests(unittest.TestCase):
    def test_virtual_set_is_read_only_and_spell_metadata_matches(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("if (warmage::isActive(PChar))", patch)
        self.assertIn("packet.SetSpells[slot++]", patch)
        self.assertIn("player->delModifiers(&blue->modList)", patch)
        self.assertIn("player->addModifiers(&blue->modList)", patch)
        self.assertIn("m_PSpell->setAOE(SPELLAOE_NONE)", patch)
        self.assertIn("m_warmageCast == warmage::isActive(caster)", patch)
        native = re.findall(r"SpellProfile\{ SpellID::(\w+),\s+(\d+),\s+(\d+),\s+(\d+)ms,\s+(\d+)s", patch)
        lua = re.findall(r"script = '(\w+)', name = '[^']+', unlockLvl = (\d+), castMs = (\d+), recastSec = (\d+), mpCost = (\d+)", MODULE.read_text(encoding="utf-8"))
        self.assertEqual(len(native), 11)
        self.assertEqual(sorted((name.lower(), level, cast, recast, mp) for name, level, mp, cast, recast in native), sorted(lua))

    def test_warmage_crystal_id_does_not_collide_with_azure_bastion_or_magus(self):
        src = MODULE.read_text(encoding="utf-8")
        self.assertRegex(src, r"id\s*=\s*3\s*,\s*key\s*=\s*'warmage'")


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class WarmageRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides = 100, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/globals/bluemagic', 'scripts/combat/basic/damage_multipliers',
            }) do
                package.preload[name] = function() return {} end
            end
            local function unit() return 1 end
            xi = {
                job = { BLU = 16 }, mod = { ACC = 1, MACC = 2, MATT = 3, INT = 4 },
                msg = { channel = { SYSTEM_3 = 29 }, basic = { NONE = 0, UNABLE_TO_USE_JA = 87 } },
                effect = { CHAIN_AFFINITY = 1, BURST_AFFINITY = 2, AZURE_LORE = 3, EFFLUX = 4, CONVERGENCE = 5 },
                attackType = { PHYSICAL = 1, MAGICAL = 2 }, damageType = { BLUNT = 1, SLASHING = 2, PIERCING = 3, ELEMENTAL = 10 },
                element = { FIRE = 1, THUNDER = 5 },
                data = { element = { getElementalResistanceRankModifier = function(e) return e end } },
                combat = { damage = {
                    calculateDamageAdjustment = unit,
                    physicalElementSDT = function(target, kind) return target.sdt[kind] or 1 end,
                    magicalElementSDT = function(target, kind) return target.magicSDT[kind] or 1 end,
                } },
                spells = { blue = {
                    getDefaultParams = function() return {} end,
                    usePhysicalSpell = function(_, _, _, params) physical = params; return 100 end,
                    useMagicalSpell = function(_, _, _, params) magical = params; return 200 end,
                } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            player = { key = 'warmage', level = 10, vars = {}, effects = { [1] = true },
                isPC = function() return true end, getMainJob = function() return 16 end,
                getMainLvl = function(self) return self.level end,
                getLocalVar = function(self, k) return self.vars[k] or 0 end,
                setLocalVar = function(self, k, v) self.vars[k] = v end,
                sendSoulSpellList = function() end, printToPlayer = function() end,
                checkDistance = function(_, target) return target.distance end,
                getTarget = function(self) return self.target end,
                hasStatusEffect = function(self, effect) return self.effects[effect] end,
                delStatusEffect = function(self, effect) self.effects[effect] = nil end,
                setWarmageKit = function(self, enabled) self.enabled = enabled end,
            }
            function mob(id)
                return { sdt = {}, magicSDT = {}, ranks = {}, distance = 10,
                    isMob = function() return true end, isAlive = function() return true end,
                    getID = function() return id end, getMod = function(self, key) return self.ranks[key] or 0 end,
                }
            end
            function makeSpell(id, element)
                return { getID = function() return id end, getElement = function() return element or 0 end }
            end
            target, other = mob(2), mob(3)
            player.target = target
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            assess = overrides['xi.actions.abilities.chain_affinity.onUseAbility']
            check = overrides['xi.actions.abilities.chain_affinity.onAbilityCheck']
            damage = xi.soulspire.warmage.damage
        """)

    def test_low_level_matches_ties_wrong_target_and_expiry(self):
        self.lua.execute("""
            assert(check(player, player, ability) == 0 and ability.recast == 12)
            target.sdt[1], target.sdt[2], target.sdt[3] = 0.5, 1, 1
            assess(player, player, ability)
            assert(hud(player).match == 6 and hud(player).window == 8)
            assert(damage(player, target, makeSpell(597), 100) == 100)
            assert(damage(player, target, makeSpell(551), 100) == 112)
            assert(damage(player, target, makeSpell(577), 100) == 112)
            assert(damage(player, target, makeSpell(551), 0) == 0)
            assert(damage(player, other, makeSpell(551), 100) == 100)
            now = 108
            assert(damage(player, target, makeSpell(551), 100) == 100 and hud(player).match == 0)
        """)

    def test_elemental_progression_and_native_spell_overrides(self):
        self.lua.execute("""
            target.sdt[1], target.sdt[2], target.sdt[3] = 0.5, 0.5, 0.5
            target.magicSDT[1], target.magicSDT[5] = 0.25, 1
            player.level = 50
            assess(player, player, ability)
            assert(hud(player).match == 7)
            player.level = 75
            assess(player, player, ability)
            assert(hud(player).match == 8)
            assert(damage(player, target, makeSpell(644, 5), 100) == 120)
            assert(damage(player, target, makeSpell(577), 100) == 100)
            local sprout = overrides['xi.actions.spells.blue.sprout_smack.onSpellCast']
            local heat = overrides['xi.actions.spells.blue.heat_breath.onSpellCast']
            assert(sprout(player, target, makeSpell(597)) == 100 and physical.damageType == 1 and not physical.hasChainAffinity)
            assert(heat(player, target, makeSpell(591, 1)) == 200 and magical.damageType == 11 and not magical.hasBurstAffinity)
            crystal.onApply(player)
            assert(player.enabled and player.effects[1] == nil)
            crystal.onRemove(player)
            assert(not player.enabled and hud(player).match == 0)
            player.key = 'magus'
            assert(sprout(player, target, makeSpell(597)) == 123)
        """)
