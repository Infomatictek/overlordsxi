import re
import unittest
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]


def build_lua_harness():
    """Creates a realistic LuaRuntime harness for OverlordsXI custom modules."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    repo_lua_root = str(REPO_ROOT).replace('\\', '/')

    setup_code = f"""
    local REPO_ROOT = '{repo_lua_root}'

    -- Trackable virtual clock for deterministic cooldown/window tests
    _G._TEST_NOW = 1000
    function getMonotonicSeconds()
        return _G._TEST_NOW
    end

    xi = xi or {{}}
    xi.settings = {{ main = {{ CURE_POWER = 1.0 }} }}
    xi.job = {{
        WAR = 1, MNK = 2, WHM = 3, BLM = 4, RDM = 5, THF = 6, PLD = 7, DRK = 8,
        BST = 9, BRD = 10, RNG = 11, SAM = 12, NIN = 13, DRG = 14, SMN = 15,
        BLU = 16, COR = 17, PUP = 18, DNC = 19, SCH = 20, GEO = 21, RUN = 22,
    }}
    xi.slot = {{
        MAIN = 0, SUB = 1, RANGED = 2, AMMO = 3,
        HEAD = 4, BODY = 5, HANDS = 6, LEGS = 7, FEET = 8,
        NECK = 9, WAIST = 10, EAR1 = 11, EAR2 = 12,
        RING1 = 13, RING2 = 14, BACK = 15,
    }}
    xi.skill = {{
        NONE = 0, HAND_TO_HAND = 1, DAGGER = 2, SWORD = 3, GREAT_SWORD = 4,
        AXE = 5, GREAT_AXE = 6, SCYTHE = 7, POLEARM = 8, KATANA = 9,
        GREAT_KATANA = 10, CLUB = 11, STAFF = 12, ARCHERY = 25,
        MARKSMANSHIP = 26, THROWING = 27,
    }}
    xi.trait = {{ DUAL_WIELD = 18 }}
    xi.recast = {{ MAGIC = 0, ABILITY = 1 }}
    xi.zoneMisc = {{ PET = 1 }}
    xi.attackType = {{ NONE = 0, PHYSICAL = 1, MAGICAL = 2, RANGED = 3, BREATH = 4, SPECIAL = 5 }}
    xi.damageType = {{ NONE = 0, PIERCING = 1, SLASHING = 2, IMPACT = 3, HTH = 4, ELEMENTAL = 5 }}
    xi.msg = {{
        channel = {{ SYSTEM_3 = 20 }},
        basic = {{
            UNABLE_TO_USE_JA = 87,
            CANT_BE_USED_IN_AREA = 316,
            CANNOT_ATTACK_TARGET = 446,
            TOO_FAR_AWAY = 78,
            RECOVERS_HP = 24,
            ALREADY_HAS_A_PET = 315,
            REQUIRES_A_PET = 314,
        }},
    }}
    xi.mod = {{
        HPP = 1, VIT = 2, DEX = 3, STR = 4, AGI = 5, CHR = 6,
        AXE = 10, DAGGER = 11, ARCHERY = 12, MARKSMANSHIP = 13,
        ACC = 20, RACC = 21, ATTP = 22, RATTP = 23, DEFP = 24,
        EVA = 25, MEVA = 26, MATT = 27, MACC = 28, MDEF = 29,
        DMG = 30, DMGPHYS = 31, DMGMAGIC = 32, DMGBREATH = 33,
        UDMBREATH = 34, UDMMAGIC = 35,
        ENMITY = 40, ENMITY_LOSS_REDUCTION = 41,
        STORETP = 42, SNAP_SHOT = 43, RAPID_SHOT = 44, RECYCLE = 45,
        PHYS_DMG_DEALT = 50, RANGED_DMG_DEALT = 51, MAG_DMG_DEALT = 52,
        ALL_WSDMG_ALL_HITS = 53,
        HASTE_ABILITY = 60, MOVE_SPEED_STACKABLE = 75,
        CURE_POTENCY = 80, CURE_POTENCY_RCVD = 81,
        INQUARTATA = 82, ADDITIVE_GUARD = 83, SIC_READY_RECAST = 84,
        DELAYP = 85, REGEN = 86, KNOCKBACK_REDUCTION = 87,
    }}
    xi.effect = {{
        HEALING = 33, STUN = 10, STONESKIN = 37, DEFENSE_BOOST = 93,
        EVASION_BOOST = 92, ATTACK_DOWN = 147, DEFENSE_DOWN = 149,
        EVASION_DOWN = 148, REGEN = 42, SHELL = 41, COUNTERSTANCE = 442,
        SLOW = 13, ACCURACY_DOWN = 146, PARALYSIS = 4,
    }}
    xi.petId = {{ SHEEP_FAMILIAR = 21 }}

    utils = {{
        handleStoneskin = function(_target, dmg, _atkType) return dmg end,
        clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end,
    }}

    -- Global getCureFinal mock (overridden by rng_specs.lua)
    _G._MOCK_CURE_FINAL = 200
    function getCureFinal(_caster, _spell, _basecure, _minCure, _isBlueMagic)
        return _G._MOCK_CURE_FINAL
    end

    xi.player = {{
        onGameIn = function() end,
        onZoneOut = function() end,
        onPlayerLevelUp = function() end,
        onPlayerLevelDown = function() end,
    }}
    xi.pet = {{
        spawnPet = function(player, petId)
            if _G._SPAWN_PET_IMPL then
                _G._SPAWN_PET_IMPL(player, petId)
            end
        end,
    }}
    xi.combat = {{
        physical = {{ canGuard = function() return false end }},
        ranged = {{
            attackDistancePenalty = function() return 10 end,
            accuracyDistancePenalty = function() return 10 end,
        }},
    }}
    xi.mobskills = {{
        mobPhysicalMove = function(_mob, _target, _skill, _action, params)
            return {{ damage = (params and params.baseDmg) or 500, hitsLanded = 1 }}
        end,
        mobMagicalMove = function(_mob, _target, _skill, _action, params)
            return {{ damage = (params and params.baseDmg) or 500, hitsLanded = 1 }}
        end,
        mobBreathMove = function(_mob, _target, _skill, _action, params)
            return {{ damage = (params and params.baseDmg) or 500, hitsLanded = 1 }}
        end,
        mobRangedMove = function(_mob, _target, _skill, _action, params)
            return {{ damage = (params and params.baseDmg) or 500, hitsLanded = 1 }}
        end,
        processDamage = function(_actor, _target, _skill, _action, info)
            return info and info.damage or 0
        end,
    }}
    xi.spells = {{
        damage = {{
            calculateAreaOfEffectResistance = function(_target, _spell)
                return 1.0
            end,
            useDamageSpell = function(caster, target, spell)
                local mult = xi.spells.damage.calculateAreaOfEffectResistance(target, spell)
                local dmg = math.floor(((spell and spell._baseDmg) or 500) * mult)
                if target.takeDamage then
                    dmg = target:takeDamage(dmg, caster, xi.attackType.MAGICAL, xi.damageType.ELEMENTAL)
                end
                return dmg
            end,
        }},
    }}
    xi.actions = {{
        abilities = {{ pets = {{}} }},
        spells = {{ white = {{}} }},
    }}
    for _, sname in ipairs({{
        'cure', 'cure_ii', 'cure_iii', 'cure_iv', 'cure_v', 'cure_vi',
        'curaga', 'curaga_ii', 'curaga_iii', 'curaga_iv', 'curaga_v',
    }}) do
        xi.actions.spells.white[sname] = {{
            onSpellCast = function(caster, target, spell)
                local final = getCureFinal(caster, spell, 100, 10, false)
                local diff = math.max(0, target:getMaxHP() - target:getHP())
                local applied = math.min(diff, final)
                target:addHP(applied)
                return applied
            end,
        }}
    end
    for _, wname in ipairs({{
        'curing_waltz', 'curing_waltz_ii', 'curing_waltz_iii',
        'curing_waltz_iv', 'curing_waltz_v', 'divine_waltz', 'divine_waltz_ii',
    }}) do
        xi.actions.abilities[wname] = {{ onUseAbility = function() return 0 end }}
    end
    xi.job_utils = {{
        beastmaster = {{
            checkCallBeast = function() return 0, 0 end,
            useCallBeast = function() end,
            checkBestialLoyalty = function() return 0, 0 end,
            useBestialLoyalty = function() end,
            checkReward = function() return 0, 0 end,
            useReward = function() return 0 end,
            checkSnarl = function() return 0, 0 end,
            useSnarl = function() end,
            useFamiliar = function() return 0 end,
        }},
    }}
    for _, rskill in ipairs({{
        'scissor_guard', 'bubble_curtain', 'metallic_body', 'bubble_shower', 'big_scissors',
        'rhino_guard', 'rhino_attack', 'power_attack', 'hi-freq_field', 'spoil',
        'harden_shell', 'tortoise_stomp', 'aqua_breath', 'roar', 'claw_cyclone',
        'razor_fang', 'secretion', 'brain_crush', 'infrasonics',
    }}) do
        xi.actions.abilities.pets[rskill] = {{ onPetAbility = function() return 0 end }}
    end

    -- Minimal Module:new + addOverride engine
    local function resolvePath(path)
        local parts = {{}}
        for p in string.gmatch(path, '[^%.]+') do
            table.insert(parts, p)
        end
        local cur = _G
        for i = 1, #parts - 1 do
            cur[parts[i]] = cur[parts[i]] or {{}}
            cur = cur[parts[i]]
        end
        return cur, parts[#parts]
    end

    Module = {{}}
    function Module:new(name)
        local obj = {{ name = name, overrides = {{}} }}
        function obj:addOverride(path, fn)
            local tbl, key = resolvePath(path)
            local orig = tbl[key]
            tbl[key] = function(...)
                local prevSuper = _G.super
                _G.super = orig or function() end
                local ok, r1, r2, r3 = pcall(fn, ...)
                _G.super = prevSuper
                if not ok then
                    error(r1)
                end
                return r1, r2, r3
            end
        end
        return obj
    end

    -- Custom require loader mapped to REPO_ROOT
    local origRequire = require
    local loadedCustom = {{}}
    function require(modPath)
        if loadedCustom[modPath] ~= nil then
            return loadedCustom[modPath]
        end
        if string.sub(modPath, 1, 15) == 'modules/custom/' then
            local fullPath = REPO_ROOT .. '/' .. modPath .. '.lua'
            local chunk, err = loadfile(fullPath)
            if not chunk then
                error('Failed to load ' .. fullPath .. ': ' .. tostring(err))
            end
            local res = chunk()
            loadedCustom[modPath] = res or true
            return loadedCustom[modPath]
        end
        -- Ignore LandSandBoat core requires already stubbed above
        loadedCustom[modPath] = true
        return true
    end

    -- Load modules in server init order
    require('modules/custom/lua/overlords_status_registry')
    require('modules/custom/lua/overlords_job_specs')
    require('modules/custom/lua/overlords_shared_slots')
    require('modules/custom/lua/overlords_test_gear')
    require('modules/custom/lua/bst_specs')
    require('modules/custom/lua/rng_specs')
    require('modules/custom/lua/overlords_soul_hud')

    -- Entity factories
    local nextEntId = 100
    local function makeEffect(effId, power, duration, origin, icon)
        local eff = {{
            _id = effId,
            _power = power or 0,
            _duration = duration or 0,
            _origin = origin,
            _icon = icon,
            _mods = {{}},
        }}
        function eff:getEffectType() return self._id end
        function eff:getPower() return self._power end
        function eff:getTimeRemaining() return self._duration * 1000 end
        function eff:addMod(m, v) table.insert(self._mods, {{ m, v }}) end
        function eff:getMods() return self._mods end
        return eff
    end

    function makeEntity(opts)
        opts = opts or {{}}
        nextEntId = nextEntId + 1
        local e = {{
            _id = opts.id or nextEntId,
            _name = opts.name or 'Entity',
            _isPC = opts.isPC == true,
            _isPet = opts.isPet == true,
            _isMob = opts.isMob == true,
            _job = opts.job or xi.job.RNG,
            _lvl = opts.lvl or 10,
            _hp = opts.hp or 1000,
            _maxHp = opts.maxHp or 1000,
            _tp = opts.tp or 0,
            _alive = opts.alive ~= false,
            _engaged = opts.engaged == true,
            _allegiance = opts.allegiance or (opts.isMob and 0 or 1),
            _mods = {{}},
            _charVars = {{}},
            _localVars = {{}},
            _effects = {{}},
            _listeners = {{}},
            _equip = {{}},
            _recasts = {{}},
            _ce = {{}},
            _ve = {{}},
            _target = nil,
            _pet = nil,
            _master = opts.master,
            _petId = opts.petId or 0,
            _distances = {{}},
            _messages = {{}},
            _petAttacks = {{}},
            _unequipped = {{}},
            _stats = opts.stats or {{ [xi.mod.VIT] = 50, [xi.mod.DEX] = 50, [xi.mod.STR] = 50, [xi.mod.AGI] = 50 }},
            _allowPet = opts.allowPet ~= false,
        }}

        function e:getID() return self._id end
        function e:getName() return self._name end
        function e:isPC() return self._isPC end
        function e:isPet() return self._isPet end
        function e:isMob() return self._isMob end
        function e:isAlive() return self._alive and self._hp > 0 end
        function e:isEngaged() return self._engaged end
        function e:getAllegiance() return self._allegiance end
        function e:getMainJob() return self._job end
        function e:getMainLvl() return self._lvl end
        function e:setLevel(l) self._lvl = l end
        function e:getHP() return self._hp end
        function e:getMaxHP() return self._maxHp end
        function e:getHPP() return math.floor((self._hp / math.max(1, self._maxHp)) * 100) end
        function e:setHP(v) self._hp = math.max(0, math.min(self._maxHp, math.floor(v))) end
        function e:addHP(v)
            local before = self._hp
            self._hp = math.max(0, math.min(self._maxHp, self._hp + math.floor(v)))
            return self._hp - before
        end
        function e:getTP() return self._tp end
        function e:setTP(v) self._tp = math.max(0, math.min(3000, math.floor(v))) end
        function e:addTP(v) self._tp = math.max(0, math.min(3000, self._tp + math.floor(v))) end
        function e:getStat(m) return self._stats[m] or 50 end
        function e:updateHealth()
            local hpp = self:getMod(xi.mod.HPP)
            self._maxHp = math.floor((opts.maxHp or 1000) * (100 + hpp) / 100)
            if self._hp > self._maxHp then self._hp = self._maxHp end
        end
        function e:addMod(m, v) self._mods[m] = (self._mods[m] or 0) + v end
        function e:delMod(m, v) self._mods[m] = (self._mods[m] or 0) - v end
        function e:getMod(m) return self._mods[m] or 0 end
        function e:getCharVar(k) return self._charVars[k] or 0 end
        function e:setCharVar(k, v) self._charVars[k] = v end
        function e:getLocalVar(k) return self._localVars[k] or 0 end
        function e:setLocalVar(k, v) self._localVars[k] = v end
        function e:getTarget() return self._target end
        function e:setTarget(t) self._target = t end
        function e:hasPet() return self._pet ~= nil end
        function e:getPet() return self._pet end
        function e:hasJugPet() return self._pet ~= nil and self._job == xi.job.BST end
        function e:getMaster() return self._master end
        function e:getPetID() return self._petId end
        function e:despawnPet()
            if self._pet ~= nil then
                local old = self._pet
                self._pet = nil
                old:triggerListener('DESPAWN', old)
            end
        end
        function e:petAttack(mob)
            table.insert(self._petAttacks, mob)
            if self._pet then
                self._pet._engaged = true
                self._pet._target = mob
            end
        end
        function e:canUseMisc(_flag) return self._allowPet end
        function e:hasTrait(tid)
            local extra = xi.overlords.spec.getExtraTraits(self)
            for _, id in ipairs(extra) do
                if id == tid then return true end
            end
            return false
        end
        function e:setEquip(slot, itemId, skillType)
            if itemId == nil then
                self._equip[slot] = nil
                return
            end
            self._equip[slot] = {{
                id = itemId,
                skillType = skillType,
                getID = function() return itemId end,
                getSkillType = function() return skillType end,
            }}
        end
        function e:getEquippedItem(slot) return self._equip[slot] end
        function e:getEquipID(slot) return self._equip[slot] and self._equip[slot].id or 0 end
        function e:getWeaponSkillType(slot) return self._equip[slot] and self._equip[slot].skillType or xi.skill.NONE end
        function e:unequipItem(slot)
            if self._equip[slot] ~= nil then
                table.insert(self._unequipped, {{ slot = slot, id = self._equip[slot].id }})
                self._equip[slot] = nil
            end
        end
        function e:addRecast(_rt, rid, sec) self._recasts[rid] = sec end
        function e:getRecast(_rt, rid) return self._recasts[rid] or 0 end
        function e:resetRecast(_rt, rid) self._recasts[rid] = 0 end
        function e:checkDistance(other)
            if other == nil then return 999 end
            return self._distances[other:getID()] or 3.0
        end
        function e:setDistance(other, d)
            self._distances[other:getID()] = d
            other._distances[self._id] = d
        end
        function e:printToPlayer(msg) table.insert(self._messages, msg) end
        function e:recalculateSkillsTable() end
        function e:recalculateAbilitiesTable() end
        function e:pushStatus() end
        function e:addListener(ev, name, fn)
            self._listeners[ev] = self._listeners[ev] or {{}}
            self._listeners[ev][name] = fn
        end
        function e:removeListener(name)
            for _, map in pairs(self._listeners) do
                map[name] = nil
            end
        end
        function e:triggerListener(ev, ...)
            local map = self._listeners[ev]
            if not map then return end
            for _, fn in pairs(map) do
                fn(...)
            end
        end
        function e:hasStatusEffect(id) return self._effects[id] ~= nil end
        function e:getStatusEffect(id) return self._effects[id] end
        function e:delStatusEffectSilent(id)
            local eff = self._effects[id]
            if eff then
                for _, pair in ipairs(eff:getMods()) do
                    self:delMod(pair[1], pair[2])
                end
                self._effects[id] = nil
            end
        end
        function e:addStatusEffect(id, params)
            params = params or {{}}
            local eff = makeEffect(id, params.power, params.duration, params.origin, params.icon)
            self._effects[id] = eff
            -- Invoke shared slot onEffectGain if present
            local slotNames = {{
                [876] = 'ox_sup_offense', [877] = 'ox_sup_chain', [878] = 'ox_sup_ward',
                [879] = 'ox_deb_breach', [880] = 'ox_deb_cripple', [881] = 'ox_deb_expose',
            }}
            local sname = slotNames[id]
            if sname and xi.effects[sname] and xi.effects[sname].onEffectGain then
                xi.effects[sname].onEffectGain(self, eff)
            end
            for _, pair in ipairs(eff:getMods()) do
                self:addMod(pair[1], pair[2])
            end
            return true
        end
        function e:getCE(ent) return self._ce[ent:getID()] or 0 end
        function e:getVE(ent) return self._ve[ent:getID()] or 0 end
        function e:setCE(ent, v) self._ce[ent:getID()] = v end
        function e:setVE(ent, v) self._ve[ent:getID()] = v end
        function e:addEnmity(ent, ce, ve)
            local id = ent:getID()
            self._ce[id] = (self._ce[id] or 0) + (ce or 0)
            self._ve[id] = (self._ve[id] or 0) + (ve or 0)
        end
        function e:updateEnmityFromDamage(ent, dmg)
            self:addEnmity(ent, math.floor(dmg * 0.5), math.floor(dmg * 1.5))
        end
        function e:updateClaim(_ent) end
        function e:takeDamage(amount, attacker, attackType, damageType)
            local dmg = amount
            if xi.overlords.onPreTakeDamage then
                dmg = xi.overlords.onPreTakeDamage(self, dmg, attacker, attackType, damageType)
            end
            self._hp = math.max(0, self._hp - dmg)
            if self._hp == 0 and self._alive then
                self._alive = false
                self:triggerListener('DEATH', self, attacker)
            end
            return dmg
        end
        function e:setMobLevel(l) self._lvl = l end
        function e:setModelId(m) self._modelId = m end
        function e:renameEntity(n) self._name = n end
        return e
    end

    _G._SPAWN_PET_IMPL = function(player, petId)
        local names = {{
            [134] = 'Wild Raaz', [135] = 'Stalker Raptor',
            [136] = 'Cehuetzi',  [137] = 'Gabbrath',
            [24]  = 'CourierCarrie',
        }}
        if _G._FORCE_FALLBACK_PET and petId >= 134 and petId <= 137 then
            return
        end
        local pet = makeEntity({{
            name = names[petId] or ('Pet_' .. tostring(petId)),
            isPet = true,
            lvl = player:getMainLvl(),
            hp = 1000,
            maxHp = 1000,
            master = player,
            petId = petId,
        }})
        player._pet = pet
        player:setDistance(pet, 3.0)
    end
    """
    lua.execute(setup_code)
    return lua


@unittest.skipIf(LuaRuntime is None, 'lupa is required for Lua runtime tests')
class HuntsmanOverhaulTests(unittest.TestCase):
    def setUp(self):
        self.lua = build_lua_harness()

    def test_activation_deactivation_and_no_ranged_provisioning(self):
        res = self.lua.execute("""
            local p = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 10 })
            p:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            local entry, err = xi.overlords.spec.set(p, xi.job.RNG, 'huntsman')
            assert(entry ~= nil and err == nil, tostring(err))

            local hasDW = p:hasTrait(xi.trait.DUAL_WIELD)
            local axeSkill = p:getMod(xi.mod.AXE)
            local archerySkill = p:getMod(xi.mod.ARCHERY)
            local rangedEquipped = p:getEquipID(xi.slot.RANGED)
            local masterEnmity = p:getMod(xi.mod.ENMITY)
            local autoRanged = p:getLocalVar('OX_AUTO_RANGED')

            -- Deactivate Soul and confirm all mods/traits clean up
            xi.overlords.spec.clear(p, xi.job.RNG)
            local afterAxe = p:getMod(xi.mod.AXE)
            local afterEnmity = p:getMod(xi.mod.ENMITY)
            local afterDW = p:hasTrait(xi.trait.DUAL_WIELD)

            return hasDW, axeSkill, archerySkill, rangedEquipped, masterEnmity, autoRanged, afterAxe, afterEnmity, afterDW
        """)
        hasDW, axeSkill, archerySkill, rangedEq, masterEnmity, autoRanged, afterAxe, afterEnmity, afterDW = res
        self.assertTrue(hasDW)
        self.assertEqual(axeSkill, 15)
        self.assertEqual(archerySkill, 0)
        self.assertEqual(rangedEq, 0)
        self.assertEqual(masterEnmity, -20)
        self.assertEqual(autoRanged, 0)
        self.assertEqual(afterAxe, 0)
        self.assertEqual(afterEnmity, 0)
        self.assertFalse(afterDW)

    def test_level_scaling_10_30_50_70_75_and_apex_unlocks(self):
        res = self.lua.execute("""
            local out = {}
            for _, lvl in ipairs({ 10, 30, 50, 70, 75 }) do
                local p = makeEntity({ isPC = true, job = xi.job.RNG, lvl = lvl })
                p:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
                xi.overlords.spec.set(p, xi.job.RNG, 'huntsman')
                local abils = xi.overlords.spec.getExtraAbilities(p)
                local hasApex = false
                for _, aid in ipairs(abils) do
                    if aid == 485 or aid == 486 then hasApex = true end
                end
                out[lvl] = {
                    hpp = p:getMod(xi.mod.HPP),
                    axe = p:getMod(xi.mod.AXE),
                    bg = xi.overlords.huntsman.getBeastguardReduction(lvl),
                    apex = hasApex,
                    enmity = p:getMod(xi.mod.ENMITY),
                }
            end
            return out[10].hpp, out[30].hpp, out[50].hpp, out[70].hpp, out[75].hpp,
                   out[10].bg, out[30].bg, out[50].bg, out[70].bg, out[75].bg,
                   out[70].apex, out[75].apex, out[75].enmity
        """)
        self.assertEqual(res[:5], (10, 12, 15, 18, 18))
        self.assertEqual(res[5:10], (0.25, 0.28, 0.32, 0.35, 0.35))
        self.assertFalse(res[10])
        self.assertTrue(res[11])
        self.assertEqual(res[12], -20)

    def test_all_four_companions_summon_and_fallback_and_swap_no_whistle(self):
        res = self.lua.execute("""
            local p = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75 })
            p:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(p, xi.job.RNG, 'huntsman')

            local summoned = {}
            for _, abil in ipairs({ 'call_wild_raaz', 'call_stalker_raptor', 'call_cehuetzi', 'call_gabbrath' }) do
                local err = xi.actions.abilities[abil].onAbilityCheck(p, p, {})
                assert(err == 0, abil .. ' check failed: ' .. tostring(err))
                xi.actions.abilities[abil].onUseAbility(p, p, {})
                local pet = p:getPet()
                assert(pet ~= nil, abil .. ' did not spawn pet')
                table.insert(summoned, pet:getPetID())
            end

            -- Swapping pets intentionally must NOT trigger Last Whistle
            local hud = xi.overlords.huntsman.getHudState(p)
            return summoned[1], summoned[2], summoned[3], summoned[4], hud.whistle_cd, hud.whistle_ready
        """)
        self.assertEqual(res[:4], (134, 135, 136, 137))
        self.assertEqual(res[4], 0)
        self.assertEqual(res[5], 0)

    def test_threat_ownership_for_both_tusker_and_saurian_and_alpha_warden_compat(self):
        res = self.lua.execute("""
            -- Huntsman with Wild Raaz (Tusker)
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 50 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local tusker = rng:getPet()
            local mob1 = makeEntity({ isMob = true, name = 'Boss1', lvl = 50 })
            mob1:addEnmity(rng, 500, 1200)
            rng:triggerListener('ATTACK', rng, mob1)
            local rngCe1, tuskerCe1, tuskerEnmityMod = mob1:getCE(rng), mob1:getCE(tusker), tusker:getMod(xi.mod.ENMITY)

            -- Huntsman with Stalker Raptor (Saurian) also transfers Master->Pet enmity
            xi.actions.abilities.call_stalker_raptor.onUseAbility(rng, rng, {})
            local saurian = rng:getPet()
            local mob2 = makeEntity({ isMob = true, name = 'Boss2', lvl = 50 })
            mob2:addEnmity(rng, 400, 900)
            rng:triggerListener('ATTACK', rng, mob2)
            local rngCe2, saurianCe2, saurianEnmityMod = mob2:getCE(rng), mob2:getCE(saurian), saurian:getMod(xi.mod.ENMITY)

            -- BST Alpha Warden MUST keep Tank-tier Master Enmity (+100 at Lv.50) and Pet->Master funnel
            local bst = makeEntity({ isPC = true, job = xi.job.BST, lvl = 50 })
            bst:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(bst, xi.job.BST, 'alphawarden')
            local bstEnmityMod = bst:getMod(xi.mod.ENMITY)

            return rngCe1, tuskerCe1, tuskerEnmityMod, rngCe2, saurianCe2, saurianEnmityMod, bstEnmityMod
        """)
        rngCe1, tuskerCe1, tuskerEnmMod, rngCe2, saurianCe2, saurianEnmMod, bstEnmMod = res
        self.assertEqual(rngCe1, 0)
        self.assertEqual(tuskerCe1, 500)
        self.assertEqual(tuskerEnmMod, 110)
        self.assertEqual(rngCe2, 0)
        self.assertEqual(saurianCe2, 400)
        self.assertEqual(saurianEnmMod, 125)
        self.assertEqual(bstEnmMod, 100)

    def test_beastguard_aoe_vs_single_target_and_range_conditions(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local pet = rng:getPet()
            local mob = makeEntity({ isMob = true, name = 'Dragon', lvl = 75 })
            mob:setTarget(pet)
            rng:setDistance(pet, 6.0)

            local aoeSkill   = { isAoE = function() return true end,  isConal = function() return false end }
            local conalSkill = { isAoE = function() return false end, isConal = function() return true end }
            local stSkill    = { isAoE = function() return false end, isConal = function() return false end }

            -- Eligible AoE & Conal at 6y (Lv.75 -> 35% reduction -> 650)
            local aoeDmg   = xi.mobskills.mobPhysicalMove(mob, rng, aoeSkill, {}, { baseDmg = 1000 }).damage
            local conalDmg = xi.mobskills.mobMagicalMove(mob, rng, conalSkill, {}, { baseDmg = 1000 }).damage
            -- Single-target mobskill must NOT be reduced (1000)
            local stDmg    = xi.mobskills.mobPhysicalMove(mob, rng, stSkill, {}, { baseDmg = 1000 }).damage

            -- AoE magic spell via useDamageSpell (Lv.75 -> 650)
            local aoeSpell = { isAoE = function() return 1 end, getTotalTargets = function() return 3 end, _baseDmg = 1000 }
            local spellDmg = xi.spells.damage.useDamageSpell(mob, rng, aoeSpell)

            -- Out of 8y range -> immediately stops working (1000)
            rng:setDistance(pet, 9.0)
            local farDmg = xi.mobskills.mobPhysicalMove(mob, rng, aoeSkill, {}, { baseDmg = 1000 }).damage

            -- Mob targeting Ranger instead of pet -> immediately stops working (1000)
            rng:setDistance(pet, 4.0)
            mob:setTarget(rng)
            local aggroDmg = xi.mobskills.mobPhysicalMove(mob, rng, aoeSkill, {}, { baseDmg = 1000 }).damage

            return aoeDmg, conalDmg, stDmg, spellDmg, farDmg, aggroDmg
        """)
        self.assertEqual(res, (650, 650, 1000, 650, 1000, 1000))

    def test_predators_feint_evasion_expiry_dagger_bonus_and_anti_stack(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            rng:setEquip(xi.slot.SUB, 16448, xi.skill.DAGGER)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_stalker_raptor.onUseAbility(rng, rng, {})
            local pet = rng:getPet()
            local mob = makeEntity({ isMob = true, name = 'NM', lvl = 75 })
            rng:setTarget(mob)
            mob:addEnmity(rng, 750, 1500)

            local baseEva = rng:getMod(xi.mod.EVA)
            local abilObj = { _recast = 45, setRecast = function(self, v) self._recast = v end }
            local err = xi.actions.abilities.predators_feint.onAbilityCheck(rng, rng, abilObj)
            assert(err == 0)
            xi.actions.abilities.predators_feint.onUseAbility(rng, rng, abilObj)

            local feintEva = rng:getMod(xi.mod.EVA) - baseEva
            local rngCeAfter = mob:getCE(rng)
            local petCeAfter = mob:getCE(pet)

            -- Attempting to re-trigger within 3s window must NOT stack EVA
            xi.actions.abilities.predators_feint.onUseAbility(rng, rng, abilObj)
            local stackedEva = rng:getMod(xi.mod.EVA) - baseEva

            -- Advance clock past 3s and tick -> EVA cleanly removed
            _G._TEST_NOW = _G._TEST_NOW + 4
            rng:triggerListener('TICK', rng)
            local afterExpireEva = rng:getMod(xi.mod.EVA) - baseEva

            return abilObj._recast, feintEva, stackedEva, afterExpireEva, rngCeAfter, petCeAfter, #rng._petAttacks
        """)
        recast, feintEva, stackedEva, afterExpireEva, rngCe, petCe, petAtkCount = res
        self.assertEqual(recast, 40)  # 45s - 5s Dagger bonus
        self.assertEqual(feintEva, 165)  # 150 Lv.75 + 15 Dagger
        self.assertEqual(stackedEva, 165)  # No stacking exploit
        self.assertEqual(afterExpireEva, 0)  # Clean expiry
        self.assertEqual(rngCe, 0)
        self.assertGreaterEqual(petCe, 750)
        self.assertGreaterEqual(petAtkCount, 1)

    def test_guardians_call_single_hit_interception_and_pet_death_handling(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75, maxHp = 1000, hp = 1000 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local pet = rng:getPet()
            local mob = makeEntity({ isMob = true, name = 'Boss', lvl = 75 })
            rng:setDistance(pet, 8.0)

            -- Arm Guardian's Call
            local err = xi.actions.abilities.guardians_call.onAbilityCheck(rng, rng, {})
            assert(err == 0)
            xi.actions.abilities.guardians_call.onUseAbility(rng, rng, {})

            local petPreHp = pet:getHP()
            -- First single-target hit: intercepted by pet (player takes 0, pet takes mitigated damage)
            local hit1 = rng:takeDamage(400, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
            local petPostHp = pet:getHP()
            -- Second hit in multi-hit sequence: NOT intercepted (player takes full 400)
            local hit2 = rng:takeDamage(400, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)

            -- 2. Re-arm Guardian's Call and fire an AoE spell -> must NOT intercept AoE
            xi.actions.abilities.guardians_call.onUseAbility(rng, rng, {})
            local aoeSpell = { isAoE = function() return 1 end, getTotalTargets = function() return 3 end, _baseDmg = 300 }
            mob:setTarget(pet)
            local aoeHit = xi.spells.damage.useDamageSpell(mob, rng, aoeSpell)
            local stillArmedAfterAoE = xi.overlords.huntsman.getHudState(rng).guard_call > 0

            -- 3. Kill pet during window -> must disarm cleanly
            pet:takeDamage(pet:getHP() + 500, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
            local hitAfterPetDeath = rng:takeDamage(200, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
            local hud = xi.overlords.huntsman.getHudState(rng)

            return hit1, petPreHp - petPostHp, hit2, aoeHit, stillArmedAfterAoE, hitAfterPetDeath, hud.guard_call
        """)
        hit1, petTook, hit2, aoeHit, stillArmed, hitAfterPetDeath, gcRem = res
        self.assertEqual(hit1, 0)
        self.assertEqual(petTook, 288)  # 400 * (1 - 0.28) Tusker DT
        self.assertEqual(hit2, 400)
        self.assertEqual(aoeHit, 195)  # 300 * (1 - 0.35) Beastguard AoE reduction, NOT intercepted
        self.assertTrue(stillArmed)
        self.assertEqual(hitAfterPetDeath, 200)
        self.assertEqual(gcRem, 0)

    def test_zoning_and_soul_switching_no_duplicate_mods_or_leaks(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local axeBefore = rng:getMod(xi.mod.AXE)
            local accBefore = rng:getMod(xi.mod.ACC)

            -- Arm Guardian's Call, then zone out and zone back in
            xi.actions.abilities.guardians_call.onUseAbility(rng, rng, {})
            xi.player.onZoneOut(rng)
            xi.player.onGameIn(rng, false, true)

            local axeAfterZone = rng:getMod(xi.mod.AXE)
            local accAfterZone = rng:getMod(xi.mod.ACC)
            local gcAfterZone  = xi.overlords.huntsman.getHudState(rng).guard_call
            local lwAfterZone  = xi.overlords.huntsman.getHudState(rng).whistle_cd

            return axeBefore, axeAfterZone, accBefore, accAfterZone, gcAfterZone, lwAfterZone
        """)
        axeBefore, axeAfterZone, accBefore, accAfterZone, gcAfterZone, lwAfterZone = res
        self.assertEqual(axeBefore, axeAfterZone)
        self.assertEqual(accBefore, accAfterZone)
        self.assertEqual(gcAfterZone, 0)
        self.assertEqual(lwAfterZone, 0)

    def test_last_whistle_escape_window_emergency_resummon_and_cooldown(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 50, maxHp = 1000, hp = 1000 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local pet = rng:getPet()
            local mob = makeEntity({ isMob = true, name = 'Boss', lvl = 50 })

            -- Put summon recast on cooldown (60s)
            rng:addRecast(xi.recast.ABILITY, 245, 60)
            local baseEva = rng:getMod(xi.mod.EVA)
            local baseSpd = rng:getMod(xi.mod.MOVE_SPEED_STACKABLE)

            -- Kill pet in combat -> triggers Last Whistle
            pet:takeDamage(pet:getHP() + 999, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
            local escapeEva = rng:getMod(xi.mod.EVA) - baseEva
            local escapeSpd = rng:getMod(xi.mod.MOVE_SPEED_STACKABLE) - baseSpd
            local summonRecastAfter = rng:getRecast(xi.recast.ABILITY, 245)

            -- Ranger is STILL vulnerable to damage during escape window
            local dmgTaken = rng:takeDamage(150, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)

            -- Emergency resummon spawns companion at 50% Max HP and 0 TP
            xi.actions.abilities.call_stalker_raptor.onUseAbility(rng, rng, {})
            local pet2 = rng:getPet()
            local emergHpp = pet2:getHPP()
            local emergTp  = pet2:getTP()

            -- Advance clock 5s -> escape window expires cleanly
            _G._TEST_NOW = _G._TEST_NOW + 5
            rng:triggerListener('TICK', rng)
            local afterEva = rng:getMod(xi.mod.EVA) - baseEva
            local afterSpd = rng:getMod(xi.mod.MOVE_SPEED_STACKABLE) - baseSpd

            -- Killing pet2 within 180s cooldown must NOT trigger Last Whistle again
            rng:addRecast(xi.recast.ABILITY, 245, 60)
            pet2:takeDamage(pet2:getHP() + 999, mob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
            local secondRecast = rng:getRecast(xi.recast.ABILITY, 245)

            return escapeEva, escapeSpd, summonRecastAfter, dmgTaken, emergHpp, emergTp, afterEva, afterSpd, secondRecast
        """)
        self.assertEqual(res, (80, 25, 0, 150, 50, 0, 0, 0, 60))

    def test_wardens_ration_axe_ws_healing_icd_and_recast_reduction(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local pet = rng:getPet()
            local mob = makeEntity({ isMob = true, name = 'Boss', lvl = 75 })
            pet:setHP(math.floor(pet:getMaxHP() * 0.50))
            local preHp = pet:getHP()
            rng:addRecast(xi.recast.ABILITY, 246, 20)

            -- Ranged WS must NOT trigger Warden's Ration
            local rangedWs = { getSkillType = function() return xi.skill.ARCHERY end, getID = function() return 192 end }
            rng:triggerListener('WEAPONSKILL_USE', rng, mob, rangedWs)
            local afterRangedHp = pet:getHP()

            -- 1H Axe WS triggers Warden's Ration (Lv.75 -> 16% Max HP, +200 TP, -3s recast)
            local axeWs = { getSkillType = function() return xi.skill.AXE end, getID = function() return 64 end }
            rng:triggerListener('WEAPONSKILL_USE', rng, mob, axeWs)
            local afterAxeHp = pet:getHP()
            local petTp = pet:getTP()
            local recastAfter = rng:getRecast(xi.recast.ABILITY, 246)

            -- Immediate second Axe WS inside 6s ICD must NOT double-heal
            rng:triggerListener('WEAPONSKILL_USE', rng, mob, axeWs)
            local afterIcdHp = pet:getHP()

            return afterRangedHp - preHp, afterAxeHp - preHp, math.floor(pet:getMaxHP() * 0.16), petTp, recastAfter, afterIcdHp - afterAxeHp
        """)
        rangedHeal, axeHeal, expectedHeal, petTp, recastAfter, icdHeal = res
        self.assertEqual(rangedHeal, 0)
        self.assertEqual(axeHeal, expectedHeal)
        self.assertEqual(petTp, 200)
        self.assertEqual(recastAfter, 17)
        self.assertEqual(icdHeal, 0)

    def test_weapon_whitelist_single_axe_vs_dagger_and_gear_command(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 30 })
            rng:setEquip(xi.slot.MAIN, 16530, xi.skill.SWORD) -- incompatible mainhand
            rng:setEquip(xi.slot.SUB,  12300, xi.skill.NONE)  -- incompatible subhand
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            local unequippedCount = #rng._unequipped

            -- Equip 1H Axe only
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            rng:triggerListener('ITEM_EQUIP', rng)
            local singleAcc = rng:getMod(xi.mod.ACC)
            local singleStp = rng:getMod(xi.mod.STORETP)
            local singleEva = rng:getMod(xi.mod.EVA)

            -- Equip optional offhand Dagger
            rng:setEquip(xi.slot.SUB, 16448, xi.skill.DAGGER)
            rng:triggerListener('ITEM_EQUIP', rng)
            local dwAcc = rng:getMod(xi.mod.ACC)
            local dwEva = rng:getMod(xi.mod.EVA)

            -- Check !gear profile & weapon whitelist
            local profile = xi.overlords.testGear.getDefaultProfile(rng, xi.job.RNG, 30)
            local allowAxe = xi.overlords.testGear.isWeaponAllowedForJob(rng, 'axe')
            local allowDagger = xi.overlords.testGear.isWeaponAllowedForJob(rng, 'dagger')
            local allowBow = xi.overlords.testGear.isWeaponAllowedForJob(rng, 'bow')
            local loadout = xi.overlords.testGear.buildLoadout(rng, { level = 10 })

            return unequippedCount, singleAcc, singleStp, singleEva, dwAcc, dwEva,
                   profile.weapon, profile.offhand, allowAxe, allowDagger, allowBow,
                   loadout.slots[xi.slot.MAIN] ~= nil, loadout.slots[xi.slot.SUB] ~= nil,
                   loadout.slots[xi.slot.RANGED] == nil
        """)
        (unCount, sAcc, sStp, sEva, dwAcc, dwEva,
         profWpn, profOff, allowAxe, allowDag, allowBow,
         hasMain, hasSub, noRanged) = res
        self.assertEqual(unCount, 2)
        self.assertEqual(sAcc, 14)
        self.assertEqual(sStp, 14)
        self.assertEqual(sEva, 0)
        self.assertEqual(dwAcc, 12)
        self.assertEqual(dwEva, 10)
        self.assertEqual(profWpn, 'axe')
        self.assertEqual(profOff, 'dagger')
        self.assertTrue(allowAxe)
        self.assertTrue(allowDag)
        self.assertFalse(allowBow)
        self.assertTrue(hasMain)
        self.assertTrue(hasSub)
        self.assertTrue(noRanged)

    def test_shared_slots_table_callback_caps_and_huntsman_debuffs(self):
        res = self.lua.execute("""
            local slots = xi.overlords.slots
            local target = makeEntity({ isMob = true, name = 'Dummy', lvl = 75 })

            -- 1. Modifier table applies mods
            slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, 15, 15, target, {
                { xi.mod.ATTP, -15 }, { xi.mod.ACC, -20 }
            }, xi.effect.ATTACK_DOWN)
            local attp1, acc1 = target:getMod(xi.mod.ATTP), target:getMod(xi.mod.ACC)

            -- 2. Equal-power shorter duration must NOT overwrite longer buff
            local overwrote = slots.applySlot(target, slots.EFF_OX_DEB_CRIPPLE, 15, 6, target, {
                { xi.mod.ATTP, -10 }
            }, xi.effect.ATTACK_DOWN)

            -- 3. Callback function form ALSO works and enforces EFF_OX_SUP_WARD caps (-1500 DMG, +35 MEVA)
            local ally = makeEntity({ isPC = true, job = xi.job.WAR, lvl = 75 })
            slots.applySlot(ally, slots.EFF_OX_SUP_WARD, 2000, 15, ally, function(eff)
                eff:addMod(xi.mod.DMG, -5000)
                eff:addMod(xi.mod.MEVA, 99)
            end, xi.effect.SHELL)
            local wardDmg, wardMeva = ally:getMod(xi.mod.DMG), ally:getMod(xi.mod.MEVA)

            -- 4. Huntsman Saurian Rend (Gabbrath) applies Expose + Breach modifiers cleanly
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_gabbrath.onUseAbility(rng, rng, {})
            local boss = makeEntity({ isMob = true, name = 'Boss', lvl = 75 })
            xi.actions.abilities.saurian_rend.onUseAbility(rng, boss, {}, {})
            local bossEva, bossDefp = boss:getMod(xi.mod.EVA), boss:getMod(xi.mod.DEFP)

            return attp1, acc1, overwrote, wardDmg, wardMeva, bossEva, bossDefp
        """)
        self.assertEqual(res, (-15, -20, False, -1500, 35, -20, -15))

    def test_cure_forwarding_uses_real_getCureFinal_and_warhorn_registry(self):
        res = self.lua.execute("""
            local rng = makeEntity({ isPC = true, job = xi.job.RNG, lvl = 75, maxHp = 1000, hp = 950 })
            rng:setEquip(xi.slot.MAIN, 16640, xi.skill.AXE)
            xi.overlords.spec.set(rng, xi.job.RNG, 'huntsman')
            xi.actions.abilities.call_wild_raaz.onUseAbility(rng, rng, {})
            local pet = rng:getPet()
            pet:setHP(200)

            -- Cast Cure with real getCureFinal = 400 (50 actual healed + 350 overheal -> 70% of 400 = 280)
            local whm = makeEntity({ isPC = true, job = xi.job.WHM, lvl = 75 })
            _G._MOCK_CURE_FINAL = 400
            xi.actions.spells.white.cure_iv.onSpellCast(whm, rng, {})
            local petHealed = pet:getHP() - 200

            -- Register a mock custom warhorn and verify getEquippedWarhorn picks it up
            xi.overlords.huntsman.registerWarhorn(29999, { name = 'Test Warhorn', feintEvaBonus = 20 })
            rng:setEquip(xi.slot.RANGED, 29999, xi.skill.NONE)
            local wh = xi.overlords.huntsman.getEquippedWarhorn(rng)
            local hud = xi.overlords.huntsman.getHudState(rng)

            return petHealed, wh ~= nil and wh.name or '', hud.warhorn
        """)
        self.assertEqual(res, (280, 'Test Warhorn', 1))

class HuntsmanSqlValidationTests(unittest.TestCase):
    def test_sql_recast_ids_fit_uint8_and_abilities_exist(self):
        sql_text = (REPO_ROOT / 'modules' / 'custom' / 'sql' / 'rng_specs.sql').read_text(encoding='utf-8')
        rows = re.findall(
            r"\(\s*(\d+)\s*,\s*'([^']+)'\s*,\s*11\s*,\s*255\s*,\s*\d+\s*,\s*(\d+)\s*,\s*(\d+)\s*,",
            sql_text,
        )
        by_name = {name: (int(aid), int(cd), int(rid)) for aid, name, cd, rid in rows}
        expected = {
            'call_wild_raaz', 'call_stalker_raptor', 'rimetusk_gore',
            'saurian_rend', 'primeval_takedown', 'call_cehuetzi', 'call_gabbrath',
            'predators_feint', 'guardians_call',
        }
        self.assertEqual(set(by_name.keys()), expected)
        for name, (_aid, _cd, rid) in by_name.items():
            self.assertGreaterEqual(rid, 1, f'{name} recastId must be >= 1')
            self.assertLessEqual(rid, 254, f'{name} recastId must fit uint8_t (<= 254)')


if __name__ == '__main__':
    unittest.main()
