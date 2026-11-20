"""Automated contract & live-Lua simulation tests for SoulspireXI — Burrows Reborn: The First Descent."""
from __future__ import annotations

import json
import re
import tempfile
import unittest
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]
SQL_PATH = REPO_ROOT / "modules" / "custom" / "sql" / "soulspire_burrows_first_descent.sql"
PATCH_PATH = REPO_ROOT / "patches" / "0046-burrows-reborn-first-descent-instance.patch"
CONFIG_LUA = REPO_ROOT / "modules" / "custom" / "lua" / "soulspire_burrows_config.lua"
RUNTIME_LUA = REPO_ROOT / "modules" / "custom" / "lua" / "soulspire_burrows_first_descent.lua"
PG_REGISTRY_LUA = REPO_ROOT / "modules" / "custom" / "lua" / "soulspire_proving_grounds_registry.lua"
DOC_PATH = REPO_ROOT / "docs" / "burrows-reborn-first-descent.md"
INIT_APPEND_PATH = REPO_ROOT / "modules" / "init.append.txt"


class BurrowsPackagingAndBrandingTests(unittest.TestCase):
    def test_no_legacy_server_name_in_new_files(self):
        legacy_pat = re.compile(r"overlordsxi", re.IGNORECASE)
        for path in (SQL_PATH, PATCH_PATH, CONFIG_LUA, RUNTIME_LUA, DOC_PATH):
            text = path.read_text(encoding="utf-8")
            self.assertIsNone(
                legacy_pat.search(text),
                msg=f"Legacy server name found in {path.name}; all new content must use SoulspireXI.",
            )

    def test_sql_registers_ghoyus_reverie_instance_12901_idempotently(self):
        sql = SQL_PATH.read_text(encoding="utf-8")
        self.assertIn("INSERT INTO `instance_list`", sql)
        self.assertIn("12901", sql)
        self.assertIn("'the_first_descent'", sql)
        self.assertIn("ON DUPLICATE KEY UPDATE", sql)

    def test_patch_creates_ghoyus_reverie_instance_bridge(self):
        patch = PATCH_PATH.read_text(encoding="utf-8")
        self.assertIn("+++ b/scripts/zones/Ghoyus_Reverie/instances/the_first_descent.lua", patch)
        for cb in (
            "onInstanceCreated",
            "onInstanceCreatedCallback",
            "afterInstanceRegister",
            "onInstanceTimeUpdate",
            "onInstanceProgressUpdate",
            "onInstanceComplete",
            "onInstanceFailure",
        ):
            self.assertIn(f"instanceObject.{cb}", patch)

    def test_init_append_registration_order(self):
        lines = [
            ln.strip()
            for ln in INIT_APPEND_PATH.read_text(encoding="utf-8-sig").splitlines()
            if ln.strip() and not ln.strip().startswith("--")
        ]
        pg_idx = lines.index("custom/lua/soulspire_proving_grounds_registry.lua")
        sql_idx = lines.index("custom/sql/soulspire_burrows_first_descent.sql")
        cfg_idx = lines.index("custom/lua/soulspire_burrows_config.lua")
        run_idx = lines.index("custom/lua/soulspire_burrows_first_descent.lua")
        self.assertLess(pg_idx, cfg_idx)
        self.assertLess(sql_idx, cfg_idx)
        self.assertLess(cfg_idx, run_idx)


@unittest.skipIf(LuaRuntime is None, "lupa Lua runtime not installed")
class BurrowsLiveLuaSimulationTests(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self._bootstrap_mock_env()

    def _bootstrap_mock_env(self):
        log_dir = str(Path(self.tmpdir.name) / "burrows_log").replace("\\", "/")
        self.log_runs_path = Path(self.tmpdir.name) / "burrows_log" / "runs.jsonl"

        self.lua.execute(
            """
            xi = {
                zone = {
                    GHOYUS_REVERIE = 129,
                    GM_HOME = 210,
                    PORT_SAN_DORIA = 232,
                    BASTOK_MINES = 234,
                    PORT_WINDURST = 240,
                    RULUDE_GARDENS = 243,
                },
                objType = { PC = 1, MOB = 2, PET = 3, NPC = 4 },
                status = { NORMAL = 0, DISAPPEAR = 2, DEAD = 3 },
                msg = { channel = { SYSTEM_3 = 20 } },
                attackType = { PHYSICAL = 1, MAGICAL = 2 },
                damageType = { PIERCING = 2, BLUNT = 3, EARTH = 8 },
                effect = {
                    LEVEL_RESTRICTION = 143,
                    LEVEL_SYNC = 276,
                    STUN = 10,
                    SILENCE = 6,
                    DEFENSE_DOWN = 149,
                    DEFENDER = 57,
                    SENTINEL = 62,
                    RAMPART = 623,
                    PALISADE = 478,
                    PHALANX = 116,
                    COPY_IMAGE = 66,
                },
                mod = {
                    COMBAT_SKILLUP_RATE = 101,
                    MAGIC_SKILLUP_RATE = 102,
                    HPP = 103,
                    ATTP = 104,
                    DEFP = 105,
                    DMGPHYS = 106,
                    DMGMAGIC = 107,
                    MDEF = 108,
                },
                mobMod = {
                    NO_DROPS = 201,
                    GIL_MAX = 202,
                    EXP_BONUS = 203,
                    MAGIC_COOL = 204,
                    NO_MOVE = 205,
                },
                soulspire = {
                    spec = {
                        refreshCalls = {},
                        petSyncCalls = {},
                        refreshPlayer = function(p)
                            xi.soulspire.spec.refreshCalls[p:getID()] = (xi.soulspire.spec.refreshCalls[p:getID()] or 0) + 1
                        end,
                        syncPetRoleMods = function(p, pet)
                            xi.soulspire.spec.petSyncCalls[p:getID()] = (xi.soulspire.spec.petSyncCalls[p:getID()] or 0) + 1
                        end,
                        getActiveSpecKey = function(p)
                            return p._soulKey or 'berserker'
                        end,
                    },
                    kurogane = {
                        dismissCalls = {},
                        dismissAll = function(p)
                            xi.soulspire.kurogane.dismissCalls[p:getID()] = (xi.soulspire.kurogane.dismissCalls[p:getID()] or 0) + 1
                        end,
                    },
                },
                customBossServer = {
                    paceCalls = {},
                    mobScalingCalls = 0,
                    applyPlayerCombatPace = function(p, force)
                        xi.customBossServer.paceCalls[p:getID()] = (xi.customBossServer.paceCalls[p:getID()] or 0) + 1
                    end,
                    applyMobScaling = function(m)
                        xi.customBossServer.mobScalingCalls = xi.customBossServer.mobScalingCalls + 1
                        m:setLocalVar('[CustomBoss]Applied', 1)
                    end,
                },
            }

            MOCK = {
                instances = {},
                nextInstId = 1,
                nextMobId = 9000,
            }

            function MOCK.newMob(def)
                MOCK.nextMobId = MOCK.nextMobId + 1
                local mob = {
                    _id = MOCK.nextMobId,
                    _name = def.name or 'Mob',
                    _packetName = def.packetName or def.name or 'Mob',
                    _lvl = def.minLevel or 10,
                    _hp = 500,
                    _maxHp = 500,
                    _alive = true,
                    _status = xi.status.NORMAL,
                    _localVars = {},
                    _mods = {},
                    _mobMods = {},
                    _effects = {},
                    _listeners = {},
                    _dropId = 999,
                    _cfh = false,
                    _target = nil,
                    _def = def,
                    _usedSkills = {},
                }
                function mob:getID() return self._id end
                function mob:getName() return self._name end
                function mob:getMainLvl() return self._lvl end
                function mob:setMobLevel(l) self._lvl = l end
                function mob:getHP() return self._hp end
                function mob:getMaxHP() return self._maxHp end
                function mob:getHPP() return math.floor((self._hp / math.max(1, self._maxHp)) * 100) end
                function mob:setHP(v) self._hp = math.max(0, math.min(self._maxHp, v)) end
                function mob:updateHealth() end
                function mob:isAlive() return self._alive and self._hp > 0 end
                function mob:getStatus() return self._status end
                function mob:setStatus(s) self._status = s end
                function mob:setLocalVar(k, v) self._localVars[k] = v end
                function mob:getLocalVar(k) return self._localVars[k] or 0 end
                function mob:addMod(k, v) self._mods[k] = (self._mods[k] or 0) + v end
                function mob:delMod(k, v) self._mods[k] = (self._mods[k] or 0) - v end
                function mob:getMod(k) return self._mods[k] or 0 end
                function mob:setMobMod(k, v) self._mobMods[k] = v end
                function mob:getMobMod(k) return self._mobMods[k] or 0 end
                function mob:setDropID(id) self._dropId = id end
                function mob:setCallForHelpFlag(f) self._cfh = f end
                function mob:getCallForHelpFlag() return self._cfh end
                function mob:setSpellList(id) self._spellList = id end
                function mob:setMagicCastingEnabled(f) self._magicEnabled = f end
                function mob:setSpawn(x, y, z, r) self._pos = { x = x, y = y, z = z, rot = r } end
                function mob:spawn()
                    self._alive = true
                    if self._def.onMobSpawn then self._def.onMobSpawn(self) end
                end
                function mob:getTarget() return self._target end
                function mob:engage(target)
                    self._target = target
                    if self._def.onMobEngage then self._def.onMobEngage(self, target) end
                end
                function mob:addStatusEffect(eff, p, t, d) self._effects[eff] = p or 1 end
                function mob:hasStatusEffect(eff) return self._effects[eff] ~= nil end
                function mob:delStatusEffect(eff) self._effects[eff] = nil end
                function mob:useMobAbility(skillId) self._usedSkills[#self._usedSkills + 1] = skillId end
                function mob:addListener(ev, tag, fn)
                    self._listeners[ev] = self._listeners[ev] or {}
                    self._listeners[ev][tag] = fn
                end
                function mob:fireListener(ev, ...)
                    for _, fn in pairs(self._listeners[ev] or {}) do
                        fn(self, ...)
                    end
                end
                function mob:kill(killer)
                    self._hp = 0
                    self._alive = false
                    self._status = xi.status.DEAD
                    if self._def.onMobDeath then self._def.onMobDeath(self, killer, {}) end
                end
                return mob
            end

            function MOCK.newInstance()
                local id = MOCK.nextInstId
                MOCK.nextInstId = MOCK.nextInstId + 1
                local inst = {
                    _id = id,
                    _localVars = {},
                    _timeLimit = 1800,
                    _mobs = {},
                    _npcs = {},
                    _chars = {},
                    _completed = false,
                    _failed = false,
                }
                function inst:getID() return self._id end
                function inst:setLocalVar(k, v) self._localVars[k] = v end
                function inst:getLocalVar(k) return self._localVars[k] or 0 end
                function inst:setTimeLimit(s) self._timeLimit = s end
                function inst:getTimeLimit() return self._timeLimit end
                function inst:getChars()
                    local out = {}
                    for _, p in ipairs(self._chars) do
                        if p:getZoneID() == xi.zone.GHOYUS_REVERIE then
                            out[#out + 1] = p
                        end
                    end
                    return out
                end
                function inst:insertDynamicEntity(def)
                    if def.objtype == xi.objType.NPC then
                        self._npcs[#self._npcs + 1] = def
                        return def
                    end
                    local m = MOCK.newMob(def)
                    self._mobs[#self._mobs + 1] = m
                    return m
                end
                function inst:complete()
                    self._completed = true
                    xi.soulspire.burrows.instance.onInstanceComplete(self)
                end
                function inst:fail()
                    self._failed = true
                    xi.soulspire.burrows.instance.onInstanceFailure(self)
                end
                MOCK.instances[id] = inst
                return inst
            end

            function MOCK.newPlayer(id, name, mainLvl, zoneId, soulKey)
                local pet = {
                    _lvl = mainLvl,
                    _hp = 200,
                    _maxHp = 200,
                    _localVars = {},
                    isAlive = function() return true end,
                    getMainLvl = function(self) return self._lvl end,
                    setLocalVar = function(self, k, v) self._localVars[k] = v end,
                    updateHealth = function() end,
                    getMaxHP = function(self) return self._maxHp end,
                    setHP = function(self, v) self._hp = v end,
                }
                local p = {
                    _id = id,
                    _name = name,
                    _origMainLvl = mainLvl,
                    _mainLvl = mainLvl,
                    _origSubLvl = math.floor(mainLvl / 2),
                    _subJob = 1,
                    _subLvl = math.floor(mainLvl / 2),
                    _zoneId = zoneId or xi.zone.PORT_SAN_DORIA,
                    _pos = { x = 0, y = 0, z = 0, rot = 0 },
                    _hp = 300,
                    _maxHp = 300,
                    _mp = 100,
                    _maxMp = 100,
                    _alive = true,
                    _status = xi.status.NORMAL,
                    _localVars = {},
                    _charVars = {},
                    _mods = {},
                    _effects = {},
                    _restriction = 0,
                    _party = nil,
                    _leader = nil,
                    _instance = nil,
                    _messages = {},
                    _lastMenu = nil,
                    _soulKey = soulKey or 'berserker',
                    _pet = pet,
                    _damageTaken = {},
                }
                p._party = { p }
                p._leader = p
                function p:isPC() return true end
                function p:getID() return self._id end
                function p:getName() return self._name end
                function p:getMainLvl() return self._mainLvl end
                function p:getSubJob() return self._subJob end
                function p:getSubLvl() return self._subLvl end
                function p:getZoneID() return self._zoneId end
                function p:setPos(x, y, z, r, zoneId)
                    self._pos = { x = x, y = y, z = z, rot = r }
                    if zoneId then self._zoneId = zoneId end
                    if zoneId == xi.zone.GHOYUS_REVERIE and self._instance then
                        xi.soulspire.burrows.instance.afterInstanceRegister(self)
                    end
                end
                function p:isAlive() return self._alive and self._hp > 0 end
                function p:getStatus() return self._status end
                function p:setStatus(s)
                    self._status = s
                    if s == xi.status.NORMAL then self._alive = true end
                end
                function p:getHP() return self._hp end
                function p:getMaxHP() return self._maxHp end
                function p:setHP(v)
                    self._hp = math.max(0, math.min(self._maxHp, v))
                    self._alive = self._hp > 0
                end
                function p:getMP() return self._mp end
                function p:getMaxMP() return self._maxMp end
                function p:setMP(v) self._mp = math.max(0, math.min(self._maxMp, v)) end
                function p:updateHealth() end
                function p:takeDamage(dmg)
                    self._damageTaken[#self._damageTaken + 1] = dmg
                    self:setHP(self._hp - dmg)
                end
                function p:setLocalVar(k, v) self._localVars[k] = v end
                function p:getLocalVar(k) return self._localVars[k] or 0 end
                function p:setCharVar(k, v) self._charVars[k] = v end
                function p:getCharVar(k) return self._charVars[k] or 0 end
                function p:addMod(k, v) self._mods[k] = (self._mods[k] or 0) + v end
                function p:delMod(k, v) self._mods[k] = (self._mods[k] or 0) - v end
                function p:getMod(k) return self._mods[k] or 0 end
                function p:levelRestriction(lvl)
                    if lvl ~= nil then
                        self._restriction = lvl
                        if lvl > 0 and lvl < self._origMainLvl then
                            self._mainLvl = lvl
                            self._subLvl = math.min(self._origSubLvl, math.floor(lvl / 2))
                            self._pet._lvl = lvl
                        else
                            self._mainLvl = self._origMainLvl
                            self._subLvl = self._origSubLvl
                            self._pet._lvl = self._origMainLvl
                        end
                    end
                    return self._restriction
                end
                function p:addStatusEffect(eff, arg1, arg2, arg3)
                    if eff == xi.effect.LEVEL_RESTRICTION then
                        local pow = type(arg1) == 'table' and arg1.power or arg1
                        self._effects[eff] = pow
                        self:levelRestriction(pow)
                    else
                        self._effects[eff] = type(arg1) == 'table' and arg1.power or (arg1 or 1)
                    end
                end
                function p:delStatusEffectSilent(eff)
                    self._effects[eff] = nil
                    if eff == xi.effect.LEVEL_RESTRICTION then
                        self:levelRestriction(0)
                    end
                end
                function p:hasStatusEffect(eff) return self._effects[eff] ~= nil end
                function p:hasPet() return self._pet ~= nil end
                function p:getPet() return self._pet end
                function p:getParty() return self._party end
                function p:getPartyLeader() return self._leader end
                function p:setInstance(inst)
                    self._instance = inst
                    if inst then
                        inst._chars[#inst._chars + 1] = self
                    end
                end
                function p:getInstance() return self._instance end
                function p:createInstance(instanceId)
                    local inst = MOCK.newInstance()
                    xi.soulspire.burrows.instance.onInstanceCreated(inst)
                    xi.soulspire.burrows.instance.onInstanceCreatedCallback(self, inst)
                end
                function p:printToPlayer(msg) self._messages[#self._messages + 1] = msg end
                function p:customMenu(menu) self._lastMenu = menu end
                function p:countdown(sec) self._countdown = sec end
                return p
            end

            function MOCK.makeParty(players)
                for _, p in ipairs(players) do
                    p._party = players
                    p._leader = players[1]
                end
                return players
            end
            """
        )

        # Load the real SoulspireXI Lua modules directly!
        self.lua.execute(PG_REGISTRY_LUA.read_text(encoding="utf-8"))
        self.lua.execute(CONFIG_LUA.read_text(encoding="utf-8"))
        self.lua.execute(f"xi.soulspire.burrows.config.LOG_BASE_DIR = '{log_dir}'")
        self.lua.execute(f"xi.soulspire.burrows.config.LOG_RUNS_PATH = '{log_dir}/runs.jsonl'")
        self.lua.execute(RUNTIME_LUA.read_text(encoding="utf-8"))

    def test_hub_menu_and_party_eligibility_validation(self):
        res = self.lua.execute(
            """
            local B = xi.soulspire.burrows.runtime
            local p1 = MOCK.newPlayer(1, 'FreshTen', 10, xi.zone.PORT_SAN_DORIA)
            local menu = B.buildHubMenu(p1)

            -- Low Man rejects 4 players; Full Party rejects 1-3 and 7+ alliances
            local p2 = MOCK.newPlayer(2, 'AllyTwo', 75, xi.zone.PORT_SAN_DORIA)
            local p3 = MOCK.newPlayer(3, 'AllyThree', 30, xi.zone.PORT_SAN_DORIA)
            local p4 = MOCK.newPlayer(4, 'AllyFour', 15, xi.zone.PORT_SAN_DORIA)
            local p5 = MOCK.newPlayer(5, 'AllyFive', 50, xi.zone.PORT_SAN_DORIA)
            local p6 = MOCK.newPlayer(6, 'AllySix', 10, xi.zone.PORT_SAN_DORIA)
            local p7 = MOCK.newPlayer(7, 'AllySeven', 10, xi.zone.PORT_SAN_DORIA)

            local C = xi.soulspire.burrows.config
            local rSoloLow = C.validatePartyEligibility(p1, { p1 }, 'low_man')
            local rSoloFull = C.validatePartyEligibility(p1, { p1 }, 'full_party')
            local rFourLow = C.validatePartyEligibility(p1, MOCK.makeParty({ p1, p2, p3, p4 }), 'low_man')
            local rNonLeader = C.validatePartyEligibility(p2, MOCK.makeParty({ p1, p2 }), 'low_man')
            local rSixFull = C.validatePartyEligibility(p1, MOCK.makeParty({ p1, p2, p3, p4, p5, p6 }), 'full_party')
            local rAlliance = C.validatePartyEligibility(p1, MOCK.makeParty({ p1, p2, p3, p4, p5, p6, p7 }), 'full_party')

            local pLow = MOCK.newPlayer(8, 'LvNine', 9, xi.zone.PORT_SAN_DORIA)
            local rBelowLvl = C.validatePartyEligibility(p1, MOCK.makeParty({ p1, pLow }), 'low_man')

            local pWrongZone = MOCK.newPlayer(9, 'FarAway', 20, xi.zone.BASTOK_MINES)
            local rWrongZone = C.validatePartyEligibility(p1, MOCK.makeParty({ p1, pWrongZone }), 'low_man')

            local pDead = MOCK.newPlayer(10, 'Fallen', 20, xi.zone.PORT_SAN_DORIA)
            pDead:setHP(0)
            local rDead = C.validatePartyEligibility(p1, MOCK.makeParty({ p1, pDead }), 'low_man')

            return {
                menuOptionCount = #menu.options,
                menuTitle = menu.title,
                soloLow = rSoloLow.code,
                soloFull = rSoloFull.code,
                fourLow = rFourLow.code,
                nonLeader = rNonLeader.code,
                sixFull = rSixFull.code,
                alliance = rAlliance.code,
                belowLvl = rBelowLvl.code,
                wrongZone = rWrongZone.code,
                dead = rDead.code,
            }
            """
        )
        self.assertEqual(res["menuOptionCount"], 4)
        self.assertIn("SoulspireXI", res["menuTitle"])
        self.assertEqual(res["soloLow"], "eligible")
        self.assertEqual(res["soloFull"], "party_size_mismatch")
        self.assertEqual(res["fourLow"], "party_size_mismatch")
        self.assertEqual(res["nonLeader"], "not_party_leader")
        self.assertEqual(res["sixFull"], "eligible")
        self.assertEqual(res["alliance"], "alliance_not_allowed")
        self.assertEqual(res["belowLvl"], "member_below_level")
        self.assertEqual(res["wrongZone"], "member_wrong_zone")
        self.assertEqual(res["dead"], "member_dead")

    def test_low_man_full_run_level_sync_soul_compat_adaptations_and_replay(self):
        res = self.lua.execute(
            """
            local B = xi.soulspire.burrows.runtime
            local I = xi.soulspire.burrows.instance

            local tank = MOCK.newPlayer(101, 'Tank75', 75, xi.zone.BASTOK_MINES, 'spartan')
            local healer = MOCK.newPlayer(102, 'Fresh10', 10, xi.zone.BASTOK_MINES, 'lifebinder')
            MOCK.makeParty({ tank, healer })

            local ok, err = B.requestEntry(tank, 'low_man')
            assert(ok, tostring(err))

            local session = B.getSessionForPlayer(tank)
            assert(session ~= nil, 'session missing')

            -- Verify Level 10 Sync + SoulspireXI Soul/HP/Pet/Clone compatibility + Skill-up Lock
            local syncCheck = {
                tankLvl = tank:getMainLvl(),
                tankSub = tank:getSubLvl(),
                tankPetLvl = tank:getPet():getMainLvl(),
                healerLvl = healer:getMainLvl(),
                tankSkillLock = tank:getMod(xi.mod.COMBAT_SKILLUP_RATE),
                tankSoulRefresh = xi.soulspire.spec.refreshCalls[101] or 0,
                tankPaceRefresh = xi.customBossServer.paceCalls[101] or 0,
                tankCloneDismiss = xi.soulspire.kurogane.dismissCalls[101] or 0,
                tankPetSync = xi.soulspire.spec.petSyncCalls[101] or 0,
                inGhoyus = (tank:getZoneID() == xi.zone.GHOYUS_REVERIE),
            }

            -- ALL mobs must be spawned immediately at instance start (boss showcased + flank hidden unlocks)
            local boss = session.bossState and session.bossState.mob or nil
            local shaman = session.shamanState and session.shamanState.mob or nil
            local sg = session.stoneguardState and session.stoneguardState.mob or nil
            assert(boss ~= nil and shaman ~= nil and sg ~= nil, 'All 3 encounters must spawn at start')
            assert(session.shamanState.acolyte == nil, 'Low Man must not spawn Burrow Acolyte')

            -- Grudgeburrow starts with FULL intact protections (ATTP +18, DEFP +25, DMGPHYS -2000)
            local initialBossMods = {
                attp = boss:getMod(xi.mod.ATTP),
                defp = boss:getMod(xi.mod.DEFP),
                physDt = boss:getMod(xi.mod.DMGPHYS),
            }

            local mobNoRewards = {
                expVar = shaman:getLocalVar('[BurrowsReborn]ExpeditionMob'),
                pgVar = shaman:getLocalVar('[ProvingGrounds]TrialMob'),
                dropId = shaman._dropId,
                noDrops = shaman:getMobMod(xi.mobMod.NO_DROPS),
                gilMax = shaman:getMobMod(xi.mobMod.GIL_MAX),
                expBonus = shaman:getMobMod(xi.mobMod.EXP_BONUS),
                cfh = shaman:getCallForHelpFlag(),
            }

            -- Hidden Unlock 1: Interrupt Burrow Shaman via Weapon Skill -> strips Grudgeburrow ATTP live!
            shaman:engage(tank)
            for t = 1, 6 do I.onInstanceTimeUpdate(session.instance, t) end
            assert(session.shamanState.ritualState == 'channeling', 'Shaman should be channeling ritual')
            shaman:fireListener('WEAPONSKILL_TAKE', tank)
            assert(session.shamanState.ritualState == 'broken', 'WS should interrupt ritual')
            assert(boss:getMod(xi.mod.ATTP) == 0, 'Breaking Shaman ritual must strip boss ATTP live')
            shaman:kill(tank)

            -- Hidden Unlock 2: Engage Stoneguard (already spawned!) -> magic shatter + defeat strips boss armor live!
            sg:engage(tank)
            for t = 7, 16 do I.onInstanceTimeUpdate(session.instance, t) end
            assert(session.stoneguardState.stanceActive == true, 'Stoneguard should enter Iron Shell')
            local stancePhysDt = sg:getMod(xi.mod.DMGPHYS)

            local hpBeforeSpike = tank:getHP()
            sg:fireListener('TAKE_DAMAGE', 20, tank, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
            local tookSpike = (tank:getHP() < hpBeforeSpike)
            sg:fireListener('TAKE_DAMAGE', 70, healer, xi.attackType.MAGICAL, xi.damageType.EARTH)
            assert(session.stoneguardState.stanceActive == false, 'Magic burst should shatter Iron Shell')
            assert(session.stoneguardState.exposedActive == true, 'Stoneguard should be Exposed')
            assert(session.stoneguardCleanBreak == true, 'Clean break flag should be set')
            sg:kill(tank)

            local adapt = session.bossAdaptations
            assert(adapt.ritualEmpowered == false, 'Ritual was broken -> unempowered')
            assert(adapt.armorWeakened == true, 'Stoneguard defeated -> armor weakened')

            local bossMods = {
                attp = boss:getMod(xi.mod.ATTP),
                defp = boss:getMod(xi.mod.DEFP),
                physDt = boss:getMod(xi.mod.DMGPHYS),
            }

            -- Fight Grudgeburrow through a telegraphed Crushing Burrow Slam + Exposed Core + AoE Tremor
            tank:addStatusEffect(xi.effect.DEFENDER, 1, 0, 60)
            boss:engage(tank)
            for t = 17, 50 do
                tank:setHP(tank:getMaxHP())
                healer:setHP(healer:getMaxHP())
                I.onInstanceTimeUpdate(session.instance, t)
            end
            local slams = session.bossState.heavySlamsResolved
            local tremors = session.bossState.aoeTremorsResolved
            local healerHasDefDown = healer:hasStatusEffect(xi.effect.DEFENSE_DOWN)

            -- Defeat Grudgeburrow -> Victory + 12s grace -> full state restore + safe hub return
            boss:kill(tank)
            assert(session.outcome == 'victory')
            for t = 51, 64 do I.onInstanceTimeUpdate(session.instance, t) end

            local restored = {
                tankLvl = tank:getMainLvl(),
                tankSub = tank:getSubLvl(),
                tankZone = tank:getZoneID(),
                healerZone = healer:getZoneID(),
                tankSkillLock = tank:getMod(xi.mod.COMBAT_SKILLUP_RATE),
                activeVar = tank:getCharVar('[BurrowsReborn]Active'),
            }

            -- Immediate replay with zero cooldown/restrictions!
            local replayOk, replayErr = B.requestEntry(tank, 'low_man')

            return {
                syncCheck = syncCheck,
                initialBossMods = initialBossMods,
                mobNoRewards = mobNoRewards,
                stancePhysDt = stancePhysDt,
                tookSpike = tookSpike,
                bossMods = bossMods,
                slams = slams,
                tremors = tremors,
                healerHasDefDown = healerHasDefDown,
                restored = restored,
                replayOk = replayOk,
                replayErr = replayErr,
            }
            """
        )

        sc = res["syncCheck"]
        self.assertEqual(sc["tankLvl"], 10)
        self.assertEqual(sc["tankSub"], 5)
        self.assertEqual(sc["tankPetLvl"], 10)
        self.assertEqual(sc["healerLvl"], 10)
        self.assertEqual(sc["tankSkillLock"], -100)
        self.assertGreaterEqual(sc["tankSoulRefresh"], 1)
        self.assertGreaterEqual(sc["tankPaceRefresh"], 1)
        self.assertGreaterEqual(sc["tankCloneDismiss"], 1)
        self.assertGreaterEqual(sc["tankPetSync"], 1)
        self.assertTrue(sc["inGhoyus"])

        # Initial showcased Grudgeburrow has both hidden locks intact
        self.assertEqual(res["initialBossMods"]["attp"], 18)
        self.assertEqual(res["initialBossMods"]["defp"], 25)
        self.assertEqual(res["initialBossMods"]["physDt"], -2000)

        nr = res["mobNoRewards"]
        self.assertEqual(nr["expVar"], 1)
        self.assertEqual(nr["pgVar"], 1)
        self.assertEqual(nr["dropId"], 0)
        self.assertEqual(nr["noDrops"], 1)
        self.assertEqual(nr["gilMax"], -1)
        self.assertEqual(nr["expBonus"], -100)
        self.assertTrue(nr["cfh"])

        self.assertEqual(res["stancePhysDt"], -6500)
        self.assertTrue(res["tookSpike"])
        # After both hidden unlocks, Grudgeburrow mods stripped live
        self.assertEqual(res["bossMods"]["attp"], 0)
        self.assertEqual(res["bossMods"]["defp"], -25)
        self.assertEqual(res["bossMods"]["physDt"], 1500)
        self.assertGreaterEqual(res["slams"], 1)
        self.assertGreaterEqual(res["tremors"], 1)
        self.assertFalse(res["healerHasDefDown"])

        rest = res["restored"]
        self.assertEqual(rest["tankLvl"], 75)
        self.assertEqual(rest["tankSub"], 37)
        self.assertEqual(rest["tankZone"], 234)  # Bastok Mines
        self.assertEqual(rest["healerZone"], 234)
        self.assertEqual(rest["tankSkillLock"], 0)
        self.assertEqual(rest["activeVar"], 0)
        self.assertTrue(res["replayOk"])

        # Verify telemetry JSONL file was written with rewards_suppressed = true
        self.assertTrue(self.log_runs_path.is_file())
        records = [json.loads(line) for line in self.log_runs_path.read_text(encoding="utf-8").splitlines() if line.strip()]
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["server"], "SoulspireXI")
        self.assertEqual(records[0]["outcome"], "victory")
        self.assertTrue(records[0]["rewards_suppressed"])
        self.assertEqual(records[0]["exp_awarded"], 0)
        self.assertEqual(records[0]["gil_awarded"], 0)
        self.assertEqual(records[0]["items_awarded"], 0)

    def test_full_party_empowered_boss_and_concurrent_instance_isolation(self):
        res = self.lua.execute(
            """
            local B = xi.soulspire.burrows.runtime
            local I = xi.soulspire.burrows.instance

            -- Party A: Low Man (2 players) -> breaks Shaman ritual + kills Stoneguard
            local a1 = MOCK.newPlayer(201, 'A1', 50, xi.zone.PORT_SAN_DORIA, 'berserker')
            local a2 = MOCK.newPlayer(202, 'A2', 10, xi.zone.PORT_SAN_DORIA, 'medic')
            MOCK.makeParty({ a1, a2 })

            -- Party B: Full Party (6 players) -> rushes Grudgeburrow directly (no hidden unlocks!)
            local bParty = {}
            for i = 1, 6 do
                bParty[i] = MOCK.newPlayer(300 + i, 'B' .. i, 10 + i * 10, xi.zone.PORT_WINDURST, 'commander')
            end
            MOCK.makeParty(bParty)

            assert(B.requestEntry(a1, 'low_man'))
            assert(B.requestEntry(bParty[1], 'full_party'))

            local sessA = B.getSessionForPlayer(a1)
            local sessB = B.getSessionForPlayer(bParty[1])
            assert(sessA.runId ~= sessB.runId, 'Concurrent parties must have distinct runIds')
            assert(sessA.instance ~= sessB.instance, 'Concurrent parties must have isolated instances')
            assert(sessB.shamanState.acolyte ~= nil, 'Full Party must spawn Burrow Acolyte at start')
            assert(sessB.bossState.mob ~= nil and sessB.stoneguardState.mob ~= nil, 'All Full Party mobs must spawn at start')

            -- Party A breaks Shaman ritual via STUN and kills Stoneguard -> Grudgeburrow weakened live
            sessA.shamanState.mob:engage(a1)
            for t = 1, 6 do I.onInstanceTimeUpdate(sessA.instance, t) end
            sessA.shamanState.mob:addStatusEffect(xi.effect.STUN, 1, 0, 5)
            I.onInstanceTimeUpdate(sessA.instance, 7)
            assert(sessA.shamanState.ritualState == 'broken')
            sessA.shamanState.mob:kill(a1)
            sessA.stoneguardState.mob:kill(a1)

            -- Party B rushes straight to Grudgeburrow without touching Shaman or Stoneguard
            sessB.bossState.mob:engage(bParty[1])
            for t = 1, 30 do
                for _, p in ipairs(bParty) do p:setHP(p:getMaxHP()) end
                I.onInstanceTimeUpdate(sessB.instance, t)
            end
            local bDefDownApplied = bParty[1]:hasStatusEffect(xi.effect.DEFENSE_DOWN)
            local bBossAttp = sessB.bossState.mob:getMod(xi.mod.ATTP)
            local bBossDefp = sessB.bossState.mob:getMod(xi.mod.DEFP)
            sessB.bossState.mob:kill(bParty[1])

            return {
                aEmpowered = sessA.bossAdaptations.ritualEmpowered,
                aBossAttp = sessA.bossState.mob:getMod(xi.mod.ATTP),
                aBossDefp = sessA.bossState.mob:getMod(xi.mod.DEFP),
                bEmpowered = sessB.bossAdaptations.ritualEmpowered,
                bArmorWeak = sessB.bossAdaptations.armorWeakened,
                bBossAttp = bBossAttp,
                bBossDefp = bBossDefp,
                bDefDownApplied = bDefDownApplied,
                bOutcome = sessB.outcome,
            }
            """
        )

        self.assertFalse(res["aEmpowered"])
        self.assertEqual(res["aBossAttp"], 0)
        self.assertEqual(res["aBossDefp"], -25)
        self.assertTrue(res["bEmpowered"])
        self.assertFalse(res["bArmorWeak"])
        self.assertEqual(res["bBossAttp"], 18)
        self.assertEqual(res["bBossDefp"], 25)
        self.assertTrue(res["bDefDownApplied"])
        self.assertEqual(res["bOutcome"], "victory")

    def test_wipe_failure_recovery_and_disconnect_handling(self):
        res = self.lua.execute(
            """
            local B = xi.soulspire.burrows.runtime
            local I = xi.soulspire.burrows.instance

            -- 1. Party Wipe Recovery
            local w1 = MOCK.newPlayer(401, 'WipeHero', 60, xi.zone.RULUDE_GARDENS, 'spartan')
            assert(B.requestEntry(w1, 'low_man'))
            local sessW = B.getSessionForPlayer(w1)
            w1:setHP(0)
            for t = 1, 10 do I.onInstanceTimeUpdate(sessW.instance, t) end
            local wipeResult = {
                outcome = sessW.outcome,
                alive = w1:isAlive(),
                lvl = w1:getMainLvl(),
                zone = w1:getZoneID(),
                sessionCleared = (B.getAllActiveSessions()[sessW.runId] == nil),
            }

            -- 2. Partial Disconnect & Full Empty-Instance Teardown
            local d1 = MOCK.newPlayer(501, 'Stay', 45, xi.zone.PORT_SAN_DORIA, 'berserker')
            local d2 = MOCK.newPlayer(502, 'Dropper', 45, xi.zone.PORT_SAN_DORIA, 'medic')
            MOCK.makeParty({ d1, d2 })
            assert(B.requestEntry(d1, 'low_man'))
            local sessD = B.getSessionForPlayer(d1)

            -- d2 disconnects / exits to hub -> d1's instance stays alive!
            B.restorePlayerState(d2, { warpToHub = true })
            for t = 1, 25 do I.onInstanceTimeUpdate(sessD.instance, t) end
            local stillRunningAfterPartial = (B.getAllActiveSessions()[sessD.runId] ~= nil)

            -- d1 also leaves -> after 20s empty grace, instance tears down cleanly
            B.restorePlayerState(d1, { warpToHub = true })
            for t = 26, 50 do I.onInstanceTimeUpdate(sessD.instance, t) end
            local clearedAfterFullEmpty = (B.getAllActiveSessions()[sessD.runId] == nil)

            return {
                wipeResult = wipeResult,
                d2LvlRestored = d2:getMainLvl(),
                d2Zone = d2:getZoneID(),
                stillRunningAfterPartial = stillRunningAfterPartial,
                clearedAfterFullEmpty = clearedAfterFullEmpty,
            }
            """
        )

        wr = res["wipeResult"]
        self.assertEqual(wr["outcome"], "defeat")
        self.assertTrue(wr["alive"])
        self.assertEqual(wr["lvl"], 60)
        self.assertEqual(wr["zone"], 243)  # Ru'Lude Gardens
        self.assertTrue(wr["sessionCleared"])

        self.assertEqual(res["d2LvlRestored"], 45)
        self.assertEqual(res["d2Zone"], 232)  # Port San d'Oria
        self.assertTrue(res["stillRunningAfterPartial"])
        self.assertTrue(res["clearedAfterFullEmpty"])


if __name__ == "__main__":
    unittest.main()
