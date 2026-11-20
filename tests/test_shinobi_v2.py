"""Automated regression tests for Shinobi 2.0 (server Lua, C++ patch, HUD, and client contract)."""

from __future__ import annotations

import ctypes
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
LAUNCHER_ROOT = Path(r'C:\overlordsxi-launcher')
LUAJIT_DLL = Path(r'C:\dev\server\libluajit_64.dll')


def run_luajit(script: str) -> tuple[int, str | None]:
    dll = ctypes.CDLL(str(LUAJIT_DLL))
    dll.luaL_newstate.restype = ctypes.c_void_p
    dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
    dll.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    dll.luaL_loadstring.restype = ctypes.c_int
    dll.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    dll.lua_pcall.restype = ctypes.c_int
    dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    dll.lua_tolstring.restype = ctypes.c_char_p
    dll.lua_close.argtypes = [ctypes.c_void_p]

    L = dll.luaL_newstate()
    dll.luaL_openlibs(L)
    rc = dll.luaL_loadstring(L, script.encode('utf-8'))
    if rc == 0:
        rc = dll.lua_pcall(L, 0, 0, 0)
    err = None
    if rc != 0:
        err = dll.lua_tolstring(L, -1, None).decode('utf-8', 'replace')
    dll.lua_close(L)
    return rc, err


class ShinobiV2RegressionTests(unittest.TestCase):
    def test_cpp_patch_present_and_well_formed(self):
        patch_path = REPO_ROOT / 'patches' / '0045-shinobi-ninjutsu-kit.patch'
        self.assertTrue(patch_path.exists(), 'Missing patches/0045-shinobi-ninjutsu-kit.patch')
        text = patch_path.read_text(encoding='utf-8')
        for token in (
            'isShinobiSpec',
            'isShinobiKitSpell',
            'OX_SHINOBI_ACTIVE',
            'SpellID::Katon_Ichi',
            'SpellID::Hyoton_Ichi',
            'SpellID::Huton_Ichi',
            'SpellID::Doton_Ichi',
            'SpellID::Raiton_Ichi',
            'SpellID::Suiton_Ichi',
            'SpellID::Utsusemi_Ichi',
            'SpellID::Utsusemi_Ni',
        ):
            self.assertIn(token, text)

    def test_boss_module_excludes_player_allied_clones(self):
        boss_lua = (REPO_ROOT / 'modules' / 'custom' / 'lua' / 'boss_like_combat_and_exp.lua').read_text(encoding='utf-8')
        self.assertIn('isPlayerAlliedMob', boss_lua)
        self.assertIn('xi.allegiance.PLAYER', boss_lua)
        self.assertIn("dynamicOwnerId", boss_lua)

    @unittest.skipUnless(LAUNCHER_ROOT.exists(), 'Local launcher repo not present')
    def test_server_and_client_action_tables_match(self):
        expected_spells = {
            320: ('False Assault', 10),
            323: ('Mirror Step', 10),
            326: ('Crosscut', 10),
            329: ('Shadow Pin', 30),
            332: ('Thunder Relay', 50),
            335: ('Final Mirage', 70),
            338: ('Shadow Squadron: Ichi', 10),
            339: ('Shadow Squadron: Ni', 37),
        }
        expected_abilities = {
            999: ('Shadow Legion', 10),
            1000: ('Phantom Assault', 10),
        }

        addon_dir = LAUNCHER_ROOT / 'addons' / 'ashita4' / 'soulspire_soul_actions'
        if not addon_dir.exists():
            addon_dir = LAUNCHER_ROOT / 'addons' / 'ashita4' / 'overlords_soul_actions'
        actions_tsv = addon_dir / 'data' / 'soul_actions.tsv'
        vis_tsv = addon_dir / 'data' / 'visibility.tsv'
        self.assertTrue(actions_tsv.exists())
        self.assertTrue(vis_tsv.exists())

        actions = {}
        for line in actions_tsv.read_text(encoding='utf-8').splitlines():
            if not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            soul, kind, aid, name, desc = parts[:5]
            self.assertLessEqual(len(name), 79)
            self.assertLessEqual(len(desc), 180)
            self.assertNotIn('Prototype', desc)
            self.assertNotIn('not implemented', desc.lower())
            actions[(soul, kind, int(aid))] = (name, desc)

        vis = {}
        for line in vis_tsv.read_text(encoding='utf-8').splitlines():
            if not line or line.startswith('#'):
                continue
            soul, kind, aid, lvl, rule = line.split('\t')
            vis[(soul, kind, int(aid))] = (int(lvl), rule)

        for sid, (name, lvl) in expected_spells.items():
            self.assertEqual(actions[('shinobi', 'spell', sid)][0], name)
            self.assertEqual(vis[('shinobi', 'spell', sid)], (lvl, 'unlock'))

        for aid, (name, lvl) in expected_abilities.items():
            self.assertEqual(actions[('shinobi', 'ability', aid)][0], name)
            self.assertEqual(vis[('shinobi', 'ability', aid)], (lvl, 'unlock'))

    @unittest.skipUnless(LUAJIT_DLL.exists(), 'Local libluajit_64.dll not available')
    def test_tactical_cycle_commands_permissions_and_hud_in_luajit(self):
        clones_path = str(REPO_ROOT / 'modules' / 'custom' / 'lua' / 'kurogane_clones.lua').replace('\\', '\\\\')
        nin_path = str(REPO_ROOT / 'modules' / 'custom' / 'lua' / 'nin_specs.lua').replace('\\', '\\\\')
        hud_path = str(REPO_ROOT / 'modules' / 'custom' / 'lua' / 'soulspire_soul_hud.lua').replace('\\', '\\\\')

        script = f"""
        -- Deterministic fake server environment for Shinobi 2.0 unit regression
        local simNow = 1000.0
        math.randomseed(42)
        math.randomFloat = function(a, b) return a + (b - a) * 0.5 end

        local origRequire = require
        function require(name)
            if type(name) == 'string' and (name:match('^modules/') or name:match('^scripts/')) then
                return {{}}
            end
            return origRequire(name)
        end

        local overrides = {{}}
        Module = {{}}
        function Module:new(name)
            local obj = {{ name = name }}
            function obj:addOverride(path, fn)
                local prev = overrides[path]
                overrides[path] = function(...)
                    local oldSuper = _G.super
                    _G.super = prev or function() return 0 end
                    local r1, r2, r3 = fn(...)
                    _G.super = oldSuper
                    return r1, r2, r3
                end
            end
            return obj
        end

        xi = {{
            job = {{ NIN = 13, WAR = 1 }},
            objType = {{ MOB = 2 }},
            allegiance = {{ PLAYER = 1, MOB = 0 }},
            mobMod = {{ NO_DROPS = 1, NO_EXP = 2, NO_DESPAWN = 3, NO_STANDBACK = 4, MULTI_HIT = 5 }},
            roamFlag = {{ SCRIPTED = 1 }},
            status = {{ DISAPPEAR = 2 }},
            slot = {{ MAIN = 0, SUB = 1 }},
            skill = {{ KATANA = 9 }},
            attackType = {{ PHYSICAL = 1, MAGICAL = 2, BREATH = 3, SPECIAL = 4 }},
            damageType = {{ SLASHING = 1 }},
            recast = {{ ABILITY = 0, MAGIC = 1 }},
            msg = {{
                basic = {{
                    NONE = 0,
                    CANNOT_CAST_SPELL = 47,
                    MAGIC_NO_EFFECT = 75,
                    UNABLE_TO_USE_JA = 87,
                    JA_NO_EFFECT = 156,
                    MAGIC_GAIN_EFFECT = 230,
                    GAINS_EFFECT_OF_STATUS = 266,
                    USES_ABILITY_EFFECT = 242,
                }},
                channel = {{ SYSTEM_3 = 1 }},
            }},
            magic = {{
                spellGroup = {{ NINJUTSU = 4 }},
                spell = {{
                    KATON_ICHI = 320, HYOTON_ICHI = 323, HUTON_ICHI = 326,
                    DOTON_ICHI = 329, RAITON_ICHI = 332, SUITON_ICHI = 335,
                    UTSUSEMI_ICHI = 338, UTSUSEMI_NI = 339,
                }},
            }},
            mod = {{
                STR = 1, DEX = 2, VIT = 3, AGI = 4, ATT = 5, DEF = 6, ATTP = 7, DEFP = 8,
                KATANA = 9, NINJUTSU = 10, ALL_WSDMG_ALL_HITS = 11, DOUBLE_ATTACK = 12,
                TRIPLE_ATTACK = 13, QUAD_ATTACK = 14, STORETP = 15, ENMITY = 16,
                ENMITY_LOSS_REDUCTION = 17, PHYS_DMG_DEALT = 18, DMGMAGIC = 19, DMG = 20,
                ACC = 21, MACC = 22, MATT = 23, MEVA = 24, HPP = 25, SUBTLE_BLOW = 26,
                INQUARTATA = 27, SPELLINTERRUPT = 28, NINJA_TOOL = 29, UTSUSEMI = 30,
                UFASTCAST = 31,
            }},
            effect = {{
                COPY_IMAGE = 66, COPY_IMAGE_2 = 444, COPY_IMAGE_3 = 445, COPY_IMAGE_4 = 446,
                THIRD_EYE = 67, YONIN = 420, FUTAE = 443, MIGAWARI = 471, STUN = 10, SLOW = 13,
                NINJUTSU_ELE_DEBUFF = 999,
            }},
            soulspire = {{
                nowSec = function() return simNow end,
                getStatusIcon = function(id) return id end,
                spec = {{
                    _active = {{}},
                    registerJob = function() end,
                    registerCrystal = function() end,
                    ensureUpToDate = function() end,
                    is = function(p, jobId, key)
                        return p._specKey == key and p:getMainJob() == jobId and p:getMainLvl() >= 10
                    end,
                    get = function(p, jobId)
                        if p._specKey then return {{ key = p._specKey, id = p._specKey == 'kurogane' and 1 or 2 }} end
                        return nil
                    end,
                    isLevelEligible = function(p) return p:getMainLvl() >= 10 end,
                }},
            }},
        }}

        -- Mock vanilla spell handlers (to prove Shinobi suppresses them and Kagemusha preserves them)
        local vanillaCastCount = 0
        for _, sname in ipairs({{ 'katon_ichi', 'hyoton_ichi', 'huton_ichi', 'doton_ichi', 'raiton_ichi', 'suiton_ichi' }}) do
            overrides['xi.actions.spells.ninjutsu.' .. sname .. '.onMagicCastingCheck'] = function() return 0 end
            overrides['xi.actions.spells.ninjutsu.' .. sname .. '.onSpellCast'] = function(c, t, sp)
                vanillaCastCount = vanillaCastCount + 1
                t:addStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF, {{ power = 30, duration = 15, origin = c }})
                return 50
            end
        end
        for _, utsu in ipairs({{ 'utsusemi_ichi', 'utsusemi_ni' }}) do
            overrides['xi.actions.spells.ninjutsu.' .. utsu .. '.onMagicCastingCheck'] = function() return 0 end
        end
        overrides['xi.spells.enhancing.useEnhancingNinjutsu'] = function() return xi.effect.COPY_IMAGE end
        overrides['xi.spells.canUseSpellOverride'] = function() return false end

        dofile('{clones_path}')
        dofile('{nin_path}')
        dofile('{hud_path}')

        local K = xi.soulspire.kurogane
        local hud = xi.soulspire.hud

        local allEntities = {{}}
        local nextMobId = 90000
        function GetPlayerByID(id) return allEntities[id] end
        function DespawnMob(id)
            local m = allEntities[id]
            if m then
                m._alive = false
                m._spawned = false
                if m._listeners and m._listeners.DESPAWN then
                    for _, fn in pairs(m._listeners.DESPAWN) do fn(m) end
                end
            end
        end

        local function makeTarget(id, lvl)
            local t = {{
                _id = id, _lvl = lvl, _zone = 100, _alive = true, _effects = {{}},
                _damageLog = {{}}, _attrLog = {{}}, _resetEnmityCount = 0, _failTakeDamage = false,
            }}
            function t:getID() return self._id end
            function t:isMob() return true end
            function t:isAlive() return self._alive end
            function t:getZoneID() return self._zone end
            function t:getPos() return {{ x = 10, y = 0, z = 10 }} end
            function t:getStat(mod) return mod == xi.mod.DEF and (self._lvl * 3) or self._lvl end
            function t:addBaseEnmity() end
            function t:resetEnmity() self._resetEnmityCount = self._resetEnmityCount + 1 end
            function t:addStatusEffect(eff) self._effects[eff] = true end
            function t:hasStatusEffect(eff) return self._effects[eff] == true end
            function t:attributeDamageTo(owner, dmg)
                self._attrLog[#self._attrLog + 1] = {{ owner = owner:getID(), dmg = dmg }}
                return true
            end
            function t:takeDamage(dmg, attacker, atkType, dmgType)
                if self._failTakeDamage then error('simulated takeDamage failure') end
                self._damageLog[#self._damageLog + 1] = {{ dmg = dmg, attacker = attacker:getID(), atkType = atkType, dmgType = dmgType }}
            end
            allEntities[id] = t
            return t
        end

        local function makeZone(zoneId)
            local z = {{ _id = zoneId }}
            function z:getID() return self._id end
            function z:isNavigablePoint() return true end
            function z:insertDynamicEntity(cfg)
                nextMobId = nextMobId + 1
                local mob = {{
                    _id = nextMobId, _alive = true, _spawned = false, _hp = 100, _maxHp = 100,
                    _delay = 240, _mods = {{}}, _listeners = {{}}, _engaged = false, _target = nil,
                    _look = cfg.lookSource:getLookSnapshot(), _localVars = {{}},
                }}
                function mob:getID() return self._id end
                function mob:isMob() return true end
                function mob:isAlive() return self._alive end
                function mob:isSpawned() return self._spawned end
                function mob:spawn() self._spawned = true end
                function mob:setMobMod() end
                function mob:setDropID() end
                function mob:setMobAbilityEnabled() end
                function mob:setMagicCastingEnabled() end
                function mob:setRoamFlags() end
                function mob:setSpawn() end
                function mob:setLocalVar(k, v) self._localVars[k] = v end
                function mob:getLocalVar(k) return self._localVars[k] or 0 end
                function mob:setDamage(d) self._dmg = d end
                function mob:addMod(m, v) self._mods[m] = (self._mods[m] or 0) + v end
                function mob:setMod(m, v) self._mods[m] = v end
                function mob:getMod(m) return self._mods[m] or 0 end
                function mob:setDelay(d) self._delay = d end
                function mob:setMaxHP(hp) self._maxHp = hp end
                function mob:setHP(hp) self._hp = hp end
                function mob:getHP() return self._hp end
                function mob:getLookSnapshot() return self._look end
                function mob:lookAt() end
                function mob:addEnmity(tgt) self._engaged = true; self._target = tgt end
                function mob:updateTarget() end
                function mob:isEngaged() return self._engaged end
                function mob:getTarget() return self._target end
                function mob:addListener(ev, name, fn) self._listeners[ev] = self._listeners[ev] or {{}}; self._listeners[ev][name] = fn end
                function mob:removeListener(name) for _, b in pairs(self._listeners) do b[name] = nil end end
                allEntities[mob._id] = mob
                return mob
            end
            return z
        end

        local function makePlayer(id, lvl, specKey)
            local z = makeZone(100)
            local p = {{
                _id = id, _lvl = lvl, _job = xi.job.NIN, _specKey = specKey, _alive = true,
                _engaged = false, _target = nil, _zone = z, _localVars = {{}}, _spells = {{}},
                _listeners = {{}}, _messages = {{}}, _effects = {{}}, _mods = {{}},
            }}
            function p:getID() return self._id end
            function p:getName() return 'TestShinobi' end
            function p:isPC() return true end
            function p:isAlive() return self._alive end
            function p:getMainJob() return self._job end
            function p:getMainLvl() return self._lvl end
            function p:getZoneID() return self._zone:getID() end
            function p:getZone() return self._zone end
            function p:getXPos() return 0 end
            function p:getYPos() return 0 end
            function p:getZPos() return 0 end
            function p:getRotPos() return 0 end
            function p:isEngaged() return self._engaged end
            function p:getTarget() return self._target end
            function p:setLocalVar(k, v) self._localVars[k] = v end
            function p:getLocalVar(k) return self._localVars[k] or 0 end
            function p:hasSpell(id) return self._spells[id] == true end
            function p:addSpell(id) self._spells[id] = true end
            function p:getStat(mod)
                if mod == xi.mod.ATT then return self._lvl * 4 end
                return self._lvl + 15
            end
            function p:getLookSnapshot()
                return {{ face=1, race=2, head=10, body=20, hands=30, legs=40, feet=50, main=60, sub=70, ranged=0, modelSize=1 }}
            end
            function p:addListener(ev, name, fn) self._listeners[ev] = self._listeners[ev] or {{}}; self._listeners[ev][name] = fn end
            function p:removeListener(name) for _, b in pairs(self._listeners) do b[name] = nil end end
            function p:printToPlayer(msg) self._messages[#self._messages + 1] = msg end
            function p:hasStatusEffect(eff) return self._effects[eff] == true end
            function p:delStatusEffect() end
            function p:delStatusEffectSilent() end
            function p:addStatusEffect(eff) self._effects[eff] = true end
            function p:setMod(m, v) self._mods[m] = v end
            function p:getMod(m) return self._mods[m] or 0 end
            function p:getRecast() return 0 end
            allEntities[id] = p
            return p
        end

        local function makeSpell(id)
            local sp = {{ _id = id, _msg = nil, _castMs = 4000 }}
            function sp:getID() return self._id end
            function sp:getSpellGroup() return xi.magic.spellGroup.NINJUTSU end
            function sp:setMsg(m) self._msg = m end
            function sp:setCastTime(ms) self._castMs = ms end
            return sp
        end

        local function makeAbility()
            local ab = {{ _msg = nil }}
            function ab:setMsg(m) self._msg = m end
            return ab
        end

        -- 1. Test Lv10 unlock boundaries & pre-cast rejection
        local p = makePlayer(1, 10, 'kurogane')
        local mob = makeTarget(5001, 10)
        p._engaged = true
        p._target = mob

        local canUse = overrides['xi.spells.canUseSpellOverride']
        assert(canUse(p, makeSpell(338)) == true, 'Lv10 Shinobi must be allowed Shadow Squadron Ichi (338)')
        assert(canUse(p, makeSpell(320)) == true, 'Lv10 Shinobi must be allowed False Assault (320)')
        assert(canUse(p, makeSpell(323)) == true, 'Lv10 Shinobi must be allowed Mirror Step (323)')
        assert(canUse(p, makeSpell(326)) == true, 'Lv10 Shinobi must be allowed Crosscut (326)')
        assert(canUse(p, makeSpell(329)) == false, 'Lv10 Shinobi must NOT be allowed Shadow Pin (329)')
        assert(canUse(p, makeSpell(339)) == false, 'Lv10 Shinobi must NOT be allowed Shadow Squadron Ni (339)')
        assert(canUse(p, makeSpell(332)) == false, 'Lv10 Shinobi must NOT be allowed Thunder Relay (332)')
        assert(canUse(p, makeSpell(335)) == false, 'Lv10 Shinobi must NOT be allowed Final Mirage (335)')

        -- Pre-cast rejection with 0 clones must return CANNOT_CAST_SPELL before any cast/cost
        local checkFA = overrides['xi.actions.spells.ninjutsu.katon_ichi.onMagicCastingCheck']
        assert(checkFA(p, mob, makeSpell(320)) == xi.msg.basic.CANNOT_CAST_SPELL, 'False Assault must fail with 0 clones')

        -- Cast Shadow Squadron: Ichi (338) -> 2 clones, 0 defensive COPY_IMAGE shadows
        local useEnh = overrides['xi.spells.enhancing.useEnhancingNinjutsu']
        local sp338 = makeSpell(338)
        useEnh(p, p, sp338)
        assert(sp338._msg == xi.msg.basic.NONE, 'Shadow Squadron Ichi should succeed')
        assert(not p:hasStatusEffect(xi.effect.COPY_IMAGE), 'Shinobi must never gain defensive Utsusemi shadows')
        local snap = K.getSnapshot(p)
        assert(snap.clones == 2, 'Ichi must summon 2 clones')
        assert(snap.phase == 0 and snap.feint_hits == 0, 'Initial phase must be Building 0/2')

        -- 2. Test Build Feint requires 2 DISTINCT living clones within 6s
        local st = K._owners[p:getID()]
        local c1 = st.clones[1].mobId
        local c2 = st.clones[2].mobId
        K._onVerifiedCloneHit(p, p:getID(), c1, simNow)
        assert(K.getSnapshot(p).phase == 0 and K.getSnapshot(p).feint_hits == 1, '1 clone hit must stay Building 1/2')
        -- Same clone hitting again must NOT build Feint!
        simNow = simNow + 2
        K._onVerifiedCloneHit(p, p:getID(), c1, simNow)
        assert(K.getSnapshot(p).phase == 0 and K.getSnapshot(p).feint_hits == 1, 'Same clone hitting twice must NOT build Feint')
        -- Advance beyond 6s window -> first hit expires
        simNow = simNow + 7
        K._onVerifiedCloneHit(p, p:getID(), c2, simNow)
        assert(K.getSnapshot(p).phase == 0 and K.getSnapshot(p).feint_hits == 1, 'Stale hit >6s must expire')
        -- Now c1 hits within 6s of c2 -> FEINT READY!
        simNow = simNow + 2
        K._onVerifiedCloneHit(p, p:getID(), c1, simNow)
        snap = K.getSnapshot(p)
        assert(snap.phase == 1 and snap.phase_rem == 20, '2 distinct clone hits within 6s must trigger Feint Ready (20s)')

        -- 3. Test Feint -> Switch -> Cascade cycle & anti-repeat rule
        local castFA = overrides['xi.actions.spells.ninjutsu.katon_ichi.onSpellCast']
        local castMS = overrides['xi.actions.spells.ninjutsu.hyoton_ichi.onSpellCast']
        local castCC = overrides['xi.actions.spells.ninjutsu.huton_ichi.onSpellCast']

        local sp320 = makeSpell(320)
        castFA(p, mob, sp320)
        assert(sp320._msg == xi.msg.basic.NONE)
        assert(not mob:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'False Assault must NOT apply NINJUTSU_ELE_DEBUFF')
        assert(vanillaCastCount == 0, 'Vanilla Katon must be suppressed for Shinobi')
        snap = K.getSnapshot(p)
        assert(snap.phase == 2 and snap.last_cmd == 'FA' and snap.opening_rem == 12, 'False Assault must advance Feint->Switch and set 12s Opening')

        -- Repeating False Assault in Switch must NOT advance to Cascade and must NOT consume its own Opening!
        simNow = simNow + 1
        castFA(p, mob, makeSpell(320))
        snap = K.getSnapshot(p)
        assert(snap.phase == 2 and snap.opening_rem == 12, 'Repeating False Assault must NOT advance Switch->Cascade')

        -- Different command (Mirror Step) advances Switch -> Cascade and consumes Opening (12s duration)
        simNow = simNow + 1
        castMS(p, mob, makeSpell(323))
        snap = K.getSnapshot(p)
        assert(snap.phase == 3 and snap.last_cmd == 'MS' and snap.opening_rem == 0 and snap.mirror_rem == 12,
            'Mirror Step must advance Switch->Cascade and consume Opening for 12s rhythm')
        assert(not mob:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Mirror Step must NOT debuff enemy')

        -- Repeating Mirror Step in Cascade must NOT trigger Cascade!
        castMS(p, mob, makeSpell(323))
        assert(K.getSnapshot(p).phase == 3, 'Repeating Mirror Step must NOT trigger Cascade')

        -- Different command (Crosscut) triggers Cascade and resets cycle to Building!
        local dmgBeforeCC = #mob._damageLog
        castCC(p, mob, makeSpell(326))
        assert(#mob._damageLog == dmgBeforeCC + 4, 'Crosscut (2 clones) + Cascade (2 clones) must apply 4 bounded strikes')
        snap = K.getSnapshot(p)
        assert(snap.phase == 0 and snap.last_cmd == '', 'Cascade must reset phase to Building')

        -- 4. Test Lv30 Shadow Pin, Lv37 Ni, Lv50 Thunder Relay, Lv70 Final Mirage & Level Sync
        local checkSP = overrides['xi.actions.spells.ninjutsu.doton_ichi.onMagicCastingCheck']
        local checkTR = overrides['xi.actions.spells.ninjutsu.raiton_ichi.onMagicCastingCheck']
        local checkFM = overrides['xi.actions.spells.ninjutsu.suiton_ichi.onMagicCastingCheck']
        local checkNi = overrides['xi.actions.spells.ninjutsu.utsusemi_ni.onMagicCastingCheck']
        assert(checkSP(p, mob, makeSpell(329)) == xi.msg.basic.CANNOT_CAST_SPELL, 'Lv10 must block Shadow Pin')
        assert(checkNi(p, p, makeSpell(339)) == xi.msg.basic.CANNOT_CAST_SPELL, 'Lv10 must block Shadow Squadron Ni')
        assert(checkTR(p, mob, makeSpell(332)) == xi.msg.basic.CANNOT_CAST_SPELL, 'Lv10 must block Thunder Relay')
        assert(checkFM(p, mob, makeSpell(335)) == xi.msg.basic.CANNOT_CAST_SPELL, 'Lv10 must block Final Mirage')

        -- Level up to 75 -> invalidates stale Lv10 clones automatically!
        p._lvl = 75
        assert(K.getSnapshot(p).clones == 0, 'Level change must invalidate stale-level clones')
        -- Summon Ni (3) + Ichi (2) -> 5 clones
        useEnh(p, p, makeSpell(339))
        useEnh(p, p, makeSpell(338))
        assert(K.getSnapshot(p).clones == 5, 'Ni + Ichi must field 5 clones')
        -- Summon Ni again -> capped at 5
        useEnh(p, p, makeSpell(339))
        assert(K.getSnapshot(p).clones == 5, 'Clone count must never exceed 5')

        -- Build Feint at Lv75 and test Shadow Pin + Thunder Relay + Final Mirage
        st = K._owners[p:getID()]
        K._onVerifiedCloneHit(p, p:getID(), st.clones[1].mobId, simNow)
        K._onVerifiedCloneHit(p, p:getID(), st.clones[2].mobId, simNow + 1)
        assert(K.getSnapshot(p).phase == 1, 'Lv75 Build Feint failed')

        overrides['xi.actions.spells.ninjutsu.doton_ichi.onSpellCast'](p, mob, makeSpell(329))
        assert(K.getSnapshot(p).phase == 2 and K.getSnapshot(p).pin_rem == 12, 'Shadow Pin must advance Feint->Switch')
        assert(not mob:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Shadow Pin must NOT debuff enemy')

        local dmgBeforeTR = #mob._damageLog
        overrides['xi.actions.spells.ninjutsu.raiton_ichi.onSpellCast'](p, mob, makeSpell(332))
        assert(#mob._damageLog == dmgBeforeTR + 5, 'Thunder Relay with 5 clones must strike 5 times')
        assert(K.getSnapshot(p).phase == 3, 'Thunder Relay must advance Switch->Cascade')

        local dmgBeforeFM = #mob._damageLog
        overrides['xi.actions.spells.ninjutsu.suiton_ichi.onSpellCast'](p, mob, makeSpell(335))
        assert(#mob._damageLog == dmgBeforeFM + 5, 'Final Mirage with 5 clones must strike 5 times')
        assert(K.getSnapshot(p).phase == 0, 'Final Mirage must consume Cascade phase and reset')

        -- Level sync back to 29 -> blocks Shadow Pin (329), Ni (339), Thunder Relay (332), Final Mirage (335)!
        p._lvl = 29
        assert(K.getSnapshot(p).clones == 0, 'Level sync down must dismiss stale clones')
        useEnh(p, p, makeSpell(338))
        assert(checkSP(p, mob, makeSpell(329)) == xi.msg.basic.CANNOT_CAST_SPELL, 'Lv29 sync must block Shadow Pin')
        assert(checkNi(p, p, makeSpell(339)) == xi.msg.basic.CANNOT_CAST_SPELL, 'Lv29 sync must block Ni')

        -- 5. Test Shadow Legion audited fix (no fake attribution when takeDamage errors) & Phantom Assault integration
        p._lvl = 75
        useEnh(p, p, makeSpell(338))
        mob._failTakeDamage = true
        local beforeAttr = K.getSnapshot(p).attributed_hits
        local slOk, slCount = K.executeShadowLegion(p, mob)
        assert(slOk and slCount == 2)
        assert(K.getSnapshot(p).attributed_hits == beforeAttr, 'Failed takeDamage must NOT increment attributed hits')
        mob._failTakeDamage = false

        local paOk, paBoosted, paDur = K.executePhantomAssault(p)
        assert(paOk and paBoosted == 2 and paDur == 8, 'Phantom Assault must boost living clones for 8s')
        assert(K.getSnapshot(p).phantom_rem == 8)

        -- 6. Test HUD packet payload & size budget
        local pkt = hud.buildPacketData(p)
        assert(pkt.soulKey == 'kurogane' and pkt.unlocked == 1)
        assert(#pkt.kv <= 224, 'HUD KV exceeds 224-byte budget: ' .. #pkt.kv)
        for _, key in ipairs({{ 'clones=', 'phase=', 'phase_rem=', 'feint_hits=', 'opening_rem=', 'last_cmd=' }}) do
            assert(pkt.kv:find(key, 1, true), 'HUD KV missing key ' .. key .. ' in ' .. pkt.kv)
        end

        -- 7. Test Kagemusha unaffected (vanilla Katon applies NINJUTSU_ELE_DEBUFF!)
        local kgm = makePlayer(2, 75, 'kagemusha')
        local mob2 = makeTarget(5002, 75)
        overrides['xi.actions.spells.ninjutsu.katon_ichi.onSpellCast'](kgm, mob2, makeSpell(320))
        assert(vanillaCastCount == 1, 'Kagemusha Katon must still call vanilla handler')
        assert(mob2:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Kagemusha Katon must preserve vanilla debuff')

        -- 8. Test cleanup on target change & disengage
        p._target = mob2
        assert(K.getSnapshot(p).clones == 0 and K.getSnapshot(p).phase == 0, 'Target change must dismiss clones and reset phase')
        """

        rc, err = run_luajit(script)
        self.assertEqual(rc, 0, f'Shinobi 2.0 LuaJIT regression failed: {err}')


if __name__ == '__main__':
    unittest.main()
