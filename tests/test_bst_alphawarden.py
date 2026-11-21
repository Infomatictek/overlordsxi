"""Regression tests for BST Alpha Warden pet modifier compatibility and damage penalties."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/bst_specs.lua"


class AlphaWardenStaticTests(unittest.TestCase):
    def test_no_unguarded_dmg_dealt_mod_literals(self):
        src = MODULE.read_text(encoding="utf-8")
        # Ensure PHYS/RANGED/MAG_DMG_DEALT are only inserted when the enum exists
        self.assertIn("if xi.mod.PHYS_DMG_DEALT then", src)
        self.assertIn("if xi.mod.RANGED_DMG_DEALT then", src)
        self.assertIn("if xi.mod.MAG_DMG_DEALT then", src)
        self.assertIn("xi.mod.ATTP, -60", src)
        self.assertIn("xi.mod.RATTP, -60", src)
        self.assertIn("xi.mod.MATT, -60", src)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class AlphaWardenRuntimeTests(unittest.TestCase):
    def _load_module(self, include_dmg_dealt: bool):
        lua = LuaRuntime()
        lua.execute(f"""
            overrides = {{}}
            registered_jobs = {{}}
            Module = {{
                new = function()
                    return {{
                        addOverride = function(_, path, fn) overrides[path] = fn end,
                    }}
                end,
            }}
            for _, name in ipairs({{
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs',
                'modules/custom/lua/soulspire_shared_slots', 'scripts/combat/physical_utilities',
                'scripts/globals/job_utils/beastmaster', 'scripts/globals/pets',
                'scripts/globals/player', 'scripts/globals/status',
                'scripts/globals/magic', 'scripts/globals/weaponskills',
                'scripts/globals/combat/damage', 'scripts/globals/spell_data',
            }}) do package.preload[name] = function() return {{}} end end

            xi = {{
                job = {{ BST = 9 }},
                slot = {{ MAIN = 0, SUB = 1 }},
                skill = {{ AXE = 5, GREAT_AXE = 6 }},
                attackType = {{ PHYSICAL = 1, MAGICAL = 2, RANGED = 3, BREATH = 4 }},
                effect = {{ PROVOKE = 1 }},
                msg = {{ basic = {{ JA_NO_EFFECT = 1, UNABLE_TO_USE_JA = 2 }} }},
                pet = {{ spawnPet = function() end }},
                mod = {{
                    HPP = 2, VIT = 10, CHR = 14, DEFP = 63, DMG = 160,
                    ENMITY = 27, ENMITY_LOSS_REDUCTION = 427, AXE = 84,
                    SIC_READY_RECAST = 1052, INQUARTATA = 963, ADDITIVE_GUARD = 1091,
                    DMGBREATH = 162, UDMBREATH = 389, DMGMAGIC = 163, UDMMAGIC = 388,
                    ATTP = 62, RATTP = 66, MATT = 28, ALL_WSDMG_ALL_HITS = 840,
                    {"PHYS_DMG_DEALT = 9001, RANGED_DMG_DEALT = 9002, MAG_DMG_DEALT = 9003," if include_dmg_dealt else ""}
                }},
                soulspire = {{
                    spec = {{
                        is = function(p, jobId, key) return p.job == jobId and p.specKey == key end,
                        ensureUpToDate = function() end,
                        registerJob = function(jobId, key, specs) registered_jobs[jobId] = specs end,
                        getTierConfig = function() return {{ offense = 0.12 }} end,
                    }},
                    hud = {{ registerProvider = function() end }},
                }},
            }}
        """)
        lua.execute(MODULE.read_text(encoding="utf-8"))
        return lua

    def test_pet_receives_fallback_offense_penalties_without_nil_addmod(self):
        lua = self._load_module(include_dmg_dealt=False)
        res = lua.execute("""
            local petMods = {}
            local pet = {
                getID = function() return 5001 end,
                getMaster = function() return nil end,
                addMod = function(_, modId, val)
                    assert(type(modId) == 'number', 'addMod received non-numeric modId: ' .. tostring(modId))
                    assert(type(val) == 'number', 'addMod received non-numeric val: ' .. tostring(val))
                    petMods[modId] = (petMods[modId] or 0) + val
                end,
                delMod = function(_, modId, val)
                    assert(type(modId) == 'number', 'delMod received non-numeric modId: ' .. tostring(modId))
                    petMods[modId] = (petMods[modId] or 0) - val
                end,
                updateHealth = function() end,
                getMaxHP = function() return 500 end,
                setHP = function() end,
                removeListener = function() end,
                addListener = function() end,
                delStatusEffectSilent = function() end,
            }
            local player = {
                job = xi.job.BST, specKey = 'alphawarden',
                getID = function() return 1001 end,
                isPC = function() return true end,
                getMainJob = function() return xi.job.BST end,
                getMainLvl = function() return 10 end,
                hasJugPet = function() return true end,
                getPet = function() return pet end,
                getLocalVar = function() return 0 end,
                setLocalVar = function() end,
                getEquipID = function() return 0 end,
                removeListener = function() end,
                addListener = function() end,
                delStatusEffectSilent = function() end,
            }
            pet.getMaster = function() return player end

            local entry = registered_jobs[xi.job.BST][1]
            entry.onApply(player)
            local attp_on = petMods[xi.mod.ATTP]
            local rattp_on = petMods[xi.mod.RATTP]
            local matt_on = petMods[xi.mod.MATT]
            local ws_on = petMods[xi.mod.ALL_WSDMG_ALL_HITS]
            local dmg_on = petMods[xi.mod.DMG]
            local hpp_on = petMods[xi.mod.HPP]

            -- Switch off Alpha Warden -> all pet mods must clean up to 0
            player.specKey = 'untamed'
            entry.onRemove(player)
            return {
                attp_on = attp_on, rattp_on = rattp_on, matt_on = matt_on, ws_on = ws_on,
                dmg_on = dmg_on, hpp_on = hpp_on,
                attp_off = petMods[xi.mod.ATTP], dmg_off = petMods[xi.mod.DMG],
            }
        """)
        self.assertEqual(res["attp_on"], -60)
        self.assertEqual(res["rattp_on"], -60)
        self.assertEqual(res["matt_on"], -60)
        self.assertEqual(res["ws_on"], -60)
        self.assertEqual(res["dmg_on"], -3000)
        self.assertEqual(res["hpp_on"], 14)
        self.assertEqual(res["attp_off"], 0)
        self.assertEqual(res["dmg_off"], 0)


if __name__ == "__main__":
    unittest.main()
