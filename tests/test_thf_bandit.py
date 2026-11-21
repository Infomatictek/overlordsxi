"""Verify Bandit exposure timing and native action scoping."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/thf_bandit_specs.lua"
PATCH = ROOT / "patches/0052-bandit-native-actions.patch"


class BanditNativeTests(unittest.TestCase):
    def test_weapon_skill_start_precedes_resolution_and_scoped_actions(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn('triggerListener("SOUL_WS_START", m_PEntity, PTarget, m_PSkill.get())', patch)
        self.assertIn("return id == 44 || id == 45", patch)
        self.assertIn("m_banditAbility != currentBandit", patch)
        self.assertIn("static_cast<uint8>(xi::SkillType::Dagger)", patch)
        self.assertIn("PSpell->getSpellGroup() != SPELLGROUP_TRUST", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class BanditRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, listeners = 100, {}, {}
            Module = { new = function() return {
                addOverride = function(_, path, fn) overrides[path] = fn end,
            } end }
            for _, name in ipairs({ 'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player' }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { THF = 6 }, slot = { MAIN = 0 }, skill = { DAGGER = 2, SWORD = 3 },
                effect = { DEFENSE_DOWN = 1, SNEAK_ATTACK = 2 },
                mod = { DAGGER = 1, ACC = 2, ATT = 3, DEX = 4, CRITHITRATE = 5, STORETP = 6 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, USES_JA = 100 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            player = {
                key = 'bandit', level = 10, weapon = 2, tp = 0, vars = {},
                isPC = function() return true end,
                getMainJob = function() return 6 end,
                getMainLvl = function(self) return self.level end,
                getWeaponSkillType = function(self) return self.weapon end,
                getTarget = function(self) return self.target end,
                getLocalVar = function(self, key) return self.vars[key] or 0 end,
                setLocalVar = function(self, key, val) self.vars[key] = val end,
                addListener = function(_, event, key, fn) listeners[key] = fn end,
                removeListener = function(_, key) listeners[key] = nil end,
                addStatusEffect = function(self, effect, options) self.effect = options end,
                delStatusEffectSilent = function(self) self.effect = nil end,
                sendSoulSpellList = function() end,
                addTP = function(self, val) self.tp = self.tp + val end,
            }
            mob = { exposed = false, isAlive = function() return true end, isMob = function() return true end,
                getID = function() return 17 end, hasStatusEffect = function(self) return self.exposed end }
            player.target = mob
            ability = {
                setRecast = function(self, sec) self.recast = sec end,
                setRange = function() end, setCE = function() end, setVE = function() end,
            }
            action = { messageID = function(self, id, message) self.message = message end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(player)
            prepare = function() listeners.OX_BND_WS_START(player, mob) end
            resolve = function(damage) listeners.OX_BND_WS_USE(player, mob, nil, 1000, nil, damage) end
        """)

    def test_solo_level_ten_opening_miss_consume_and_recast(self):
        self.lua.execute("""
            local checkGap = overrides['xi.actions.abilities.mug.onAbilityCheck']
            local useGap = overrides['xi.actions.abilities.mug.onUseAbility']
            assert(#crystal.extraAbilities(player, 10) == 2)
            assert(checkGap(player, mob, ability) == 0 and ability.recast == 24)
            useGap(player, mob, ability, action)
            assert(hud(player).gap_rem == 15 and action.message == 100)
            prepare()
            resolve(0)
            assert(player.tp == 0 and hud(player).gap_rem == 15)
            prepare()
            resolve(200)
            assert(player.tp == 75 and hud(player).gap_rem == 0 and hud(player).exploit_cd == 12)
            mob.exposed = true
            prepare()
            resolve(200)
            assert(player.tp == 75)
            now, player.level = 112, 75
            prepare()
            resolve(200)
            assert(player.tp == 225)
        """)

    def test_existing_defense_down_and_cleanup(self):
        self.lua.execute("""
            prepare()
            mob.exposed = true
            resolve(200)
            assert(player.tp == 0)
            prepare()
            listeners.OX_BND_WS_EXIT(player)
            resolve(200)
            assert(player.tp == 0)
            player.weapon = 12
            prepare()
            resolve(200)
            assert(player.tp == 0)
            crystal.onRemove(player)
            player.key = 'phantom'
            assert(listeners.OX_BND_WS_START == nil)
            assert(overrides['xi.actions.abilities.mug.onUseAbility'](player, mob, ability, action) == 123)
        """)
