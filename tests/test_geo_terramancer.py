"""Verify fault placement, position and entity identity at delayed execution."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/geo_terramancer_specs.lua"
PATCH = ROOT / "patches/0069-terramancer-native-actions.patch"


class TerramancerNativeTests(unittest.TestCase):
    def test_uses_real_stone_pipeline_and_shared_recast(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("const bool armed = GetLocalVar", patch)
        self.assertIn("static_cast<xi::Recast>(sibling), 8s", patch)
        self.assertIn("caster->entityId().instanceRunId != target->entityId().instanceRunId", patch)
        self.assertIn("!battleutils::HasClaim(caster, target)", patch)
        self.assertIn("spell::GetSpell(SpellID::Stone)", patch)
        self.assertIn("luautils::OnSpellCast(caster, target, stone.get(), &action)", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class TerramancerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            now, overrides, entities = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
            }) do package.preload[name] = function() return {} end end
            package.preload['modules/custom/lua/soulspire_soul_actions'] = function()
                return { register = function(_, data) catalog = data end }
            end
            xi = {
                job = { GEO = 21 }, mod = { INT = 1, MATT = 2, MACC = 3 },
                msg = { basic = { MAGIC_UNABLE_TO_CAST = 17, MAGIC_NO_EFFECT = 75, NONE = 0, UNABLE_TO_USE_JA = 87 },
                    channel = { SYSTEM_3 = 29 } },
                soulspire = { nowSec = function() return now end,
                    spec = { is = function(p, _, k) return p.key == k end,
                        registerCrystal = function(_, data) crystal = data end },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            function actor(id, tag)
                local entity = {
                    key = 'terramancer', level = 10, zone = 1, battle = 0, vars = {}, mp = 100, alive = true,
                    pos = { x = 0, y = 0, z = 0 }, timers = {}, listeners = {},
                    isPC = function() return tag == 'player' end, isMob = function() return tag == 'mob' end,
                    getMaster = function() end, isAlive = function(self) return self.alive end,
                    getID = function() return id end, getName = function() return 'Quarry' end,
                    getZoneID = function(self) return self.zone end, getBattleID = function(self) return self.battle end,
                    getMainJob = function() return 21 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    getMP = function(self) return self.mp end, getMaxMP = function() return 100 end,
                    delMP = function(self, n) self.mp = self.mp - n end,
                    hasClaim = function(self, opponent) return self.claim == opponent end,
                    getPos = function(self) return self.pos end, checkDistance = function() return 10 end,
                    timer = function(self, delay, fn) self.timers[delay] = fn end,
                    sendSoulSpellList = function() end,
                    printToPlayer = function(self, msg) self.notice = msg end,
                    addListener = function(self, _, k, callback) self.listeners[k] = callback end,
                    removeListener = function(self, k) self.listeners[k] = nil end,
                    resolveTerramancerFault = function(self, target, deep) self.hit = { target, deep } end,
                }
                entities[id] = entity
                return entity
            end
            GetMobByID = function(id) return entities[id] end
            GetPlayerByID = function(id) return entities[id] end
            super = function() return 100 end
            spell = { setMsg = function(self, n) self.msg = n end }
            p, quarry, nearby = actor(1, 'player'), actor(4, 'mob'), actor(5, 'mob')
            quarry.vars.OX_ARC_SPAWN = 1
            p.claim = quarry
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(p)
            shallowCheck = overrides['xi.actions.spells.black.stone_ii.onMagicCastingCheck']
            shallow = overrides['xi.actions.spells.black.stone_ii.onSpellCast']
            deepCheck = overrides['xi.actions.spells.black.stone_iii.onMagicCastingCheck']
            deep = overrides['xi.actions.spells.black.stone_iii.onSpellCast']
            cancel = overrides['xi.actions.abilities.full_circle.onUseAbility']
            scalar = overrides['xi.spells.damage.calculateBaseDamage']
        """)

    def test_starter_spends_once_and_delivers_to_bound_quarry(self):
        self.lua.execute("""
            assert(shallowCheck(p, quarry, spell) == 0 and deepCheck(p, quarry, spell) == 17)
            shallow(p, quarry, spell)
            assert(p.mp == 93 and hud(p).fuse == 2 and hud(p).inside == 1)
            assert(shallowCheck(p, quarry, spell) == 17)
            shallow(p, quarry, spell)
            assert(p.mp == 93 and spell.msg == 75)
            local callback = quarry.timers[2000]
            now = 102
            quarry.pos.x, quarry.pos.y = 3, 3
            callback(quarry)
            assert(p.hit[1] == quarry and not p.hit[2] and hud(p).cooldown == 6)
            p.hit = nil
            callback(nearby)
            assert(p.hit == nil)
        """)

    def test_movement_claim_or_respawn_prevents_damage(self):
        self.lua.execute("""
            shallow(p, quarry, spell)
            quarry.pos.x = 3.1
            quarry.timers[2000](quarry)
            assert(p.hit == nil and p.notice)
            now = 108
            shallow(p, quarry, spell)
            p.claim = nearby
            quarry.timers[2000](quarry)
            assert(p.hit == nil)
            now, p.claim = 116, quarry
            shallow(p, quarry, spell)
            quarry.vars.OX_ARC_SPAWN = 2
            quarry.timers[2000](quarry)
            assert(p.hit == nil)
        """)

    def test_later_fault_cost_and_explicit_invalidation(self):
        self.lua.execute("""
            p.level = 30
            assert(deepCheck(p, quarry, spell) == 0)
            deep(p, quarry, spell)
            assert(p.mp == 88 and hud(p).fuse == 4)
            cancel(p, p)
            quarry.timers[4000](quarry)
            assert(p.hit == nil and p.mp == 88)
            now = 108
            deep(p, quarry, spell)
            p.listeners.OX_TRM_CLEAR_FAULT(p)
            quarry.timers[4000](quarry)
            assert(p.hit == nil)
            p.vars.OX_TRM_SCALAR = 280
            assert(scalar(p, quarry, 159) == 280 and scalar(p, quarry, 160) == 100)
            crystal.onRemove(p)
            p.key = 'verdant'
            assert(shallowCheck(p, quarry, spell) == 100 and scalar(p, quarry, 159) == 100)
        """)
