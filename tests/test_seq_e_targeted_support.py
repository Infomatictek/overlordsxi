"""Sequence E unit and regression tests for targeted defense and support (11 Souls):
Valkyrie, Channeler, Royal Tactician, Scourge, Arcane Archer, Nightblade,
Skyborn, Archivist, Beastspeaker, Herald, and Diviner.
"""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]
INIT_APPEND = REPO_ROOT / 'modules' / 'init.append.txt'
LUA_DIR = REPO_ROOT / 'modules' / 'custom' / 'lua'

SEQ_E_MODULES = [
    'whm_valkyrie.lua',
    'blm_channeler.lua',
    'rdm_royal_tactician.lua',
    'drk_scourge.lua',
    'rng_arcane_archer.lua',
    'nin_nightblade.lua',
    'drg_skyborn.lua',
    'sch_archivist.lua',
    'bst_beastspeaker.lua',
    'smn_herald.lua',
    'geo_diviner.lua',
]


def build_seq_e_harness(repo_root: Path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    escaped = str(repo_root).replace('\\', '/')
    lua.execute(f"""
        package.path = '{escaped}/?.lua;' .. package.path
        _TEST_NOW = 4000
        function getMonotonicSeconds() return _TEST_NOW end

        package.loaded['modules/module_utils'] = true
        package.loaded['scripts/globals/player'] = true

        Module = {{}}
        function Module:new(name)
            return {{ name = name, overrides = {{}}, addOverride = function(self, t, fn) self.overrides[t] = fn end }}
        end

        xi = {{
            job = {{
                WAR = 1, MNK = 2, WHM = 3, BLM = 4, RDM = 5, THF = 6,
                PLD = 7, DRK = 8, BST = 9, BRD = 10, RNG = 11, SAM = 12,
                NIN = 13, DRG = 14, SMN = 15, BLU = 16, COR = 17, PUP = 18,
                DNC = 19, SCH = 20, GEO = 21, RUN = 22,
            }},
            mod = {{
                POLEARM = 1, HPP = 2, MEVA = 3, MPP = 4, MACC = 5, ARCHERY = 6,
                RACC = 7, NINJUTSU = 8, ENMITY = 9, DMG = 10, AXE = 11, ACC = 12,
                SUMMONING_MAGIC_SKILL = 13, GEOMANCY = 14,
            }},
        }}

        require('modules/custom/lua/overlords_job_specs')

        function makeEntity(opts)
            opts = opts or {{}}
            local e = {{
                _id = opts.id or 1,
                _isPC = opts.isPC == true,
                _isMob = opts.isMob == true,
                _alive = opts.alive ~= false,
                _job = opts.job or 1,
                _lvl = opts.lvl or 75,
                _zone = opts.zone or 100,
                _maxHP = opts.maxHP or 1000,
                _dist = opts.dist or 5,
                _target = opts.target,
                _vars = {{}},
                _charVars = {{}},
                _enmity = {{}},
            }}
            function e:getID() return self._id end
            function e:isPC() return self._isPC end
            function e:isMob() return self._isMob end
            function e:isAlive() return self._alive end
            function e:getMainJob() return self._job end
            function e:getMainLvl() return self._lvl end
            function e:getZoneID() return self._zone end
            function e:getMaxHP() return self._maxHP end
            function e:checkDistance() return self._dist end
            function e:getTarget() return self._target end
            function e:getLocalVar(k) return self._vars[k] or 0 end
            function e:setLocalVar(k, v) self._vars[k] = v end
            function e:getCharVar(k) return self._charVars[k] or 0 end
            function e:setCharVar(k, v) self._charVars[k] = v end
            function e:addEnmity(actor, ce, ve)
                self._enmity[#self._enmity + 1] = {{ actor = actor, ce = ce, ve = ve }}
            end
            return e
        end
    """)
    for mod_name in SEQ_E_MODULES:
        lua.execute(f"dofile('{str(LUA_DIR / mod_name).replace(chr(92), '/')}')")
    return lua


class SequenceELoaderOrderTests(unittest.TestCase):
    def test_all_11_modules_registered_after_existing_job_specs(self):
        lines = [line.strip() for line in INIT_APPEND.read_text(encoding='utf-8').splitlines()]
        idx_hud = lines.index('custom/lua/overlords_soul_hud.lua')
        for mod_name in SEQ_E_MODULES:
            self.assertGreater(lines.index(f'custom/lua/{mod_name}'), idx_hud)


@unittest.skipIf(LuaRuntime is None, 'lupa not installed')
class SequenceELuaBehaviorTests(unittest.TestCase):
    def test_valkyrie_cast_interruption_atomic_claim_and_manual_cancel_exclusion(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local vlk = xi.overlords.valkyrie
            local v1 = makeEntity({ id = 1, isPC = true, job = xi.job.WHM, lvl = 75 })
            local v2 = makeEntity({ id = 2, isPC = true, job = xi.job.WHM, lvl = 75 })
            local ally = makeEntity({ id = 3, isPC = true, job = xi.job.BLM, lvl = 75 })
            v1:setCharVar('OX_SPEC_WHM', 3)
            v2:setCharVar('OX_SPEC_WHM', 3)

            assert(vlk.selectWingmate(v1, ally) == true)
            assert(vlk.selectWingmate(v2, ally) == true)

            -- Manual cancel never arms Escort
            assert(vlk.onCastInterrupted(ally, 144, 1, { fromHostileDamage = false, manualCancel = true }) == false)
            assert(vlk.executeEscort(v1, ally) == nil)

            -- Hostile damage interrupt arms Escort; first Valkyrie claims atomically, second fails
            assert(vlk.onCastInterrupted(ally, 144, 2, { fromHostileDamage = true }) == true)
            local esc = assert(vlk.executeEscort(v1, ally))
            assert(esc.sirdBonus == 100 and esc.refundPct == 25)
            assert(vlk.executeEscort(v2, ally) == nil)

            -- Completed retry of exact spell refunds 25% of actual MP paid (25 of 100)
            local ref, used = vlk.resolveEscortedRetry(ally, 144, 100, true)
            assert(ref == 25 and used == true)
        """)

    def test_channeler_conduit_anti_recursion_ancient_exclusion_and_cancel(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local chn = xi.overlords.channeler
            local c1 = makeEntity({ id = 10, isPC = true, job = xi.job.BLM, lvl = 75 })
            local c2 = makeEntity({ id = 11, isPC = true, job = xi.job.BLM, lvl = 75 })
            local ally = makeEntity({ id = 12, isPC = true, job = xi.job.WHM, lvl = 75 })
            c1:setCharVar('OX_SPEC_BLM', 2)
            c2:setCharVar('OX_SPEC_BLM', 2)

            local link = assert(chn.startConduitLink(c1, ally))
            assert(link.castSaving == 30 and link.mpSaving == 25)

            -- Cannot link another Channeler already maintaining a channel
            local bad, err = chn.startConduitLink(c2, c1)
            assert(bad == nil and err == 'recipient_is_channeling')

            -- Ancient Magic is never accelerated
            local ctA, mpA, usedA = chn.onRecipientCastStart(ally, 7.0, 200, { isAncientMagic = true })
            assert(ctA == 7.0 and mpA == 200 and usedA == false)

            -- Eligible spell gets -30% cast time and -25% MP cost; completion relays 5%
            local ct, mp, used = chn.onRecipientCastStart(ally, 10.0, 100, {})
            assert(ct == 7.0 and mp == 75 and used == true)
            local relay = chn.onRecipientCastEnd(ally, 75, true)
            assert(relay == 3)
        """)

    def test_royal_tactician_orders_overwrite_and_resist_fallback(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local ryt = xi.overlords.royalTactician
            local p = makeEntity({ id = 20, isPC = true, job = xi.job.RDM, lvl = 75 })
            local ally = makeEntity({ id = 21, isPC = true, job = xi.job.WAR, lvl = 75 })
            p:setCharVar('OX_SPEC_RDM', 2)

            -- Slow opens Advance, then Blind overwrites with Recompose before issuing
            assert(ryt.onEnfeebleResolved(p, 'slow', {}).orderType == 'advance')
            assert(ryt.onEnfeebleResolved(p, 'blind', {}).orderType == 'recompose')
            local ord = assert(ryt.issueOrder(p, ally))
            assert(ord.orderType == 'recompose' and ord.mpDiscount == 25)
            -- Non-instant completed spell consumes Recompose (25 of 100 MP)
            assert(ryt.consumeRecompose(ally, 100, { completed = true, isInstant = false }) == 25)
            assert(ryt.consumeRecompose(ally, 100, { completed = true, isInstant = false }) == 0)

            -- Full resist at Lv75 grants half-potency Advance (7% ACC, 4 STP)
            _TEST_NOW = _TEST_NOW + 20
            assert(ryt.onEnfeebleResolved(p, 'paralyze', { fullResist = true }).halfPotency == true)
            local halfOrd = assert(ryt.issueOrder(p, ally))
            assert(halfOrd.orderType == 'advance' and halfOrd.accPct == 7 and halfOrd.storeTp == 4)
        """)

    def test_scourge_single_slot_curse_and_hard_immunity_fallback(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local scr = xi.overlords.scourge
            local s1 = makeEntity({ id = 30, isPC = true, job = xi.job.DRK, lvl = 75 })
            local s2 = makeEntity({ id = 31, isPC = true, job = xi.job.DRK, lvl = 75 })
            local boss = makeEntity({ id = 300, isMob = true, alive = true })
            s1:setCharVar('OX_SPEC_DRK', 3)
            s2:setCharVar('OX_SPEC_DRK', 3)

            -- Apply Withering (15% TP reduction); resisted Ash leaves Withering intact
            assert(scr.castCurse(s1, boss, 'withering', {}) ~= nil)
            local _, st = scr.castCurse(s2, boss, 'ash', { resisted = true })
            assert(st == 'resisted')
            local dTp, pct = scr.applyCurseDamageReduction(boss, 'physical_tp', 1000, {})
            assert(dTp == 850 and pct == 15)
            -- Autos and scripted HP sets unchanged
            assert(scr.applyCurseDamageReduction(boss, 'physical_tp', 1000, { isAutoAttack = true }) == 1000)

            -- Hard immunity on same active category (withering) must NOT proc fallback
            _TEST_NOW = _TEST_NOW + 13
            local fbBad, fbErr = scr.castCurse(s2, boss, 'withering', { hardImmune = true })
            assert(fbBad == nil and fbErr == 'existing_curse_active')

            -- Hard immunity on Famine (no active Famine) grants half-potency (15%) one-hit heal suppression
            _TEST_NOW = _TEST_NOW + 15
            local fb, fbSt = scr.castCurse(s2, boss, 'famine', { hardImmune = true })
            assert(fbSt == 'immunity_fallback' and fb.pct == 15)
            local h1, hp1 = scr.applyFamineHealReduction(boss, 1000, {})
            assert(h1 == 850 and hp1 == 15)
            local h2, hp2 = scr.applyFamineHealReduction(boss, 1000, {})
            assert(h2 == 1000 and hp2 == 0)
        """)

    def test_arcane_archer_exclusive_mark_single_claim_and_solo_half_bonus(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local aca = xi.overlords.arcaneArcher
            local rng = makeEntity({ id = 40, isPC = true, job = xi.job.RNG, lvl = 75 })
            local ally1 = makeEntity({ id = 41, isPC = true, job = xi.job.BLM, lvl = 75 })
            local ally2 = makeEntity({ id = 42, isPC = true, job = xi.job.BLM, lvl = 75 })
            local mob = makeEntity({ id = 400, isMob = true, alive = true })
            rng:setCharVar('OX_SPEC_RNG', 3)

            assert(aca.fireAttunementArrow(rng, mob, 'fire', { partyId = 7 }) ~= nil)
            -- Wrong element / DoT / unrelated party cannot claim
            assert(aca.consumeMark(ally1, mob, 'ice', 100, { partyId = 7, isDirectElementalSpell = true }) == 100)
            assert(aca.consumeMark(ally1, mob, 'fire', 100, { partyId = 7, isDoT = true }) == 100)
            assert(aca.consumeMark(ally1, mob, 'fire', 100, { partyId = 99, isDirectElementalSpell = true }) == 100)
            -- First matching ally consumes (+20% -> 120); second simultaneous ally gets ordinary damage
            local d1, ok1 = aca.consumeMark(ally1, mob, 'fire', 100, { partyId = 7, isDirectElementalSpell = true })
            local d2, ok2 = aca.consumeMark(ally2, mob, 'fire', 100, { partyId = 7, isDirectElementalSpell = true })
            assert(d1 == 120 and ok1 == true and d2 == 100 and ok2 == false)

            -- Solo own elemental bow WS consumes at half bonus (+10% -> 110)
            _TEST_NOW = _TEST_NOW + 17
            assert(aca.fireAttunementArrow(rng, mob, 'fire', { partyId = 7 }) ~= nil)
            local ds, oks = aca.consumeMark(rng, mob, 'fire', 100, { isOwnElementalBowWS = true })
            assert(ds == 110 and oks == true)
        """)

    def test_nightblade_seals_mismatch_retry_and_single_sequence_limit(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local ngb = xi.overlords.nightblade
            local n1 = makeEntity({ id = 50, isPC = true, job = xi.job.NIN, lvl = 75 })
            local n2 = makeEntity({ id = 51, isPC = true, job = xi.job.NIN, lvl = 75 })
            local boss = makeEntity({ id = 500, isMob = true, alive = true })
            n1:setCharVar('OX_SPEC_NIN', 3)
            n2:setCharVar('OX_SPEC_NIN', 3)

            -- Mismatch sets 3s retry and never interrupts
            local rMis, eMis = ngb.castSeal(n1, boss, 'severing', { seq = 1, category = 'physical_tp' })
            assert(rMis == nil and eMis == 'mismatch_retry')

            -- Uninterruptible spell gets 12% fallback at Lv75; second Nightblade cannot layer on same seq
            _TEST_NOW = _TEST_NOW + 3
            local rec, st = ngb.castSeal(n1, boss, 'severing', { seq = 2, category = 'spell', uninterruptible = true })
            assert(st == 'weakened' and rec.reductionPct == 12)
            local rec2, st2 = ngb.castSeal(n2, boss, 'severing', { seq = 2, category = 'spell', uninterruptible = true })
            assert(rec2 == nil and st2 == 'already_sealed')
            assert(ngb.applySealedActionDamage(boss, 2, 1000, {}) == 880)
        """)

    def test_skyborn_keeps_targetability_hate_and_mitigates_once(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local sky = xi.overlords.skyborn
            local drg = makeEntity({ id = 60, isPC = true, job = xi.job.DRG, lvl = 75, maxHP = 1500 })
            local boss = makeEntity({ id = 600, isMob = true, alive = true })
            drg:setCharVar('OX_SPEC_DRG', 2)

            -- Cold-start Grounding Cry (+200 CE / +700 VE)
            assert(sky.executeGroundingCry(drg, boss) == true)
            assert(#boss._enmity == 1 and boss._enmity[1].ce == 200 and boss._enmity[1].ve == 700)

            -- Skyward Guard keeps targetability and hate; reduces Lv75 hit by 50% and lands with +100/+300 + 10% ward
            local g = assert(sky.startSkywardGuard(drg, boss))
            assert(g.targetable == true and g.hateRetained == true)
            -- Scripted HP-set excluded
            local dScript, uScript = sky.resolveGuardedHit(drg, 999, { isScriptedFatalOrHpSet = true })
            assert(dScript == 999 and uScript == false)
            local dHit, uHit = sky.resolveGuardedHit(drg, 1000, {})
            assert(dHit == 500 and uHit == true)
            assert(#boss._enmity == 2 and boss._enmity[2].ce == 100 and boss._enmity[2].ve == 300)
            assert(drg:getLocalVar('OX_SKY_WARD_HP') == 150)
        """)

    def test_archivist_exact_action_id_matching_and_highest_page_wins(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local arc = xi.overlords.archivist
            local a1 = makeEntity({ id = 70, isPC = true, job = xi.job.SCH, lvl = 75 })
            local a2 = makeEntity({ id = 71, isPC = true, job = xi.job.SCH, lvl = 10 })
            local ally = makeEntity({ id = 72, isPC = true, job = xi.job.PLD, lvl = 75 })
            local boss = makeEntity({ id = 700, isMob = true, alive = true })
            a1:setCharVar('OX_SPEC_SCH', 3)
            a2:setCharVar('OX_SPEC_SCH', 3)

            assert(arc.startRecord(a1, boss, { spawnGen = 1 }) == true)
            assert(arc.onEnemyActionCompleted(a1, boss, 501, 'magical', { spawnGen = 1 }) ~= nil)
            assert(arc.startRecord(a2, boss, { spawnGen = 1 }) == true)
            assert(arc.onEnemyActionCompleted(a2, boss, 501, 'magical', { spawnGen = 1 }) ~= nil)

            assert(arc.fileCountermeasure(a1, ally, 1) ~= nil) -- 30%
            assert(arc.fileCountermeasure(a2, ally, 1) ~= nil) -- 20%

            -- Wrong action ID 502 never consumes page
            local dw, pw = arc.applyFiledCountermeasure(ally, boss, 502, 1000, { spawnGen = 1 })
            assert(dw == 1000 and pw == 0)
            -- Exact action ID 501 consumes highest page only (30% -> 700)
            local d1, p1 = arc.applyFiledCountermeasure(ally, boss, 501, 1000, { spawnGen = 1 })
            assert(d1 == 700 and p1 == 30)
        """)

    def test_beastspeaker_family_exposure_caps_and_unknown_fallback(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local bsp = xi.overlords.beastspeaker
            local mob = makeEntity({ id = 800, isMob = true, alive = true })
            local otherMob = makeEntity({ id = 801, isMob = true, alive = true })
            local p = makeEntity({ id = 80, isPC = true, job = xi.job.BST, lvl = 75 })
            local pet = makeEntity({ id = 81, isPC = false, alive = true, target = otherMob })
            p:setCharVar('OX_SPEC_BST', 3)

            local r = assert(bsp.readQuarry(p, mob, { family = 'unknown' }))
            assert(r.knownFamily == false and r.dmgType == 'blunt')
            -- Pet on wrong target rejects Expose
            assert(bsp.orderExpose(p, pet, mob) == nil)
            -- Retarget pet to mob -> delivers 6% unknown-family blunt exposure at Lv75
            pet._target = mob
            assert(bsp.orderExpose(p, pet, mob) ~= nil)
            assert(bsp.onPetMeleeHit(p, pet, mob, 50) ~= nil)

            -- Multiattack subhits in round 1 claim once; round 2 claims 2nd; round 3 capped at 2
            local h1, ok1 = bsp.applyExposure(p, mob, 'blunt', 100, { roundSeq = 1 })
            local h1b, ok1b = bsp.applyExposure(p, mob, 'blunt', 100, { roundSeq = 1 })
            local h2, ok2 = bsp.applyExposure(p, mob, 'blunt', 100, { roundSeq = 2 })
            local h3, ok3 = bsp.applyExposure(p, mob, 'blunt', 100, { roundSeq = 3 })
            assert(h1 == 106 and ok1 == true and h1b == 100 and ok1b == false)
            assert(h2 == 106 and ok2 == true and h3 == 100 and ok3 == false)
        """)

    def test_herald_accord_per_member_claim_and_avatar_swap_cleanup(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local hld = xi.overlords.herald
            local smn = makeEntity({ id = 90, isPC = true, job = xi.job.SMN, lvl = 75, zone = 100 })
            local a1 = makeEntity({ id = 91, isPC = true, job = xi.job.BLM, lvl = 75, zone = 100 })
            local a2 = makeEntity({ id = 92, isPC = true, job = xi.job.RDM, lvl = 75, zone = 100 })
            smn:setCharVar('OX_SPEC_SMN', 3)

            assert(hld.castAccord(smn, 'ifrit', { smn, a1, a2 }) ~= nil)
            -- Two allies claim independently (+12% at Lv75); repeat by ally1 gets ordinary damage
            local d1, o1 = hld.claimAccordBonus(a1, 'fire', 100, {})
            local d1r, o1r = hld.claimAccordBonus(a1, 'fire', 100, {})
            local d2, o2 = hld.claimAccordBonus(a2, 'fire', 100, {})
            assert(d1 == 112 and o1 == true and d1r == 100 and o1r == false and d2 == 112 and o2 == true)

            -- Dismissing/swapping avatar ends Accord for remaining unclaimed members
            hld.endAccord(smn)
            local ds, os = hld.claimAccordBonus(smn, 'fire', 100, {})
            assert(ds == 100 and os == false)
        """)

    def test_diviner_corridor_geometry_endpoints_floors_and_two_lines(self):
        lua = build_seq_e_harness(REPO_ROOT)
        lua.execute("""
            local div = xi.overlords.diviner
            local d1 = makeEntity({ id = 95, isPC = true, job = xi.job.GEO, lvl = 75, zone = 100 }) -- +35, width 2.5
            local d2 = makeEntity({ id = 96, isPC = true, job = xi.job.GEO, lvl = 10, zone = 100 }) -- +12, width 2.0
            d1:setCharVar('OX_SPEC_GEO', 1)
            d2:setCharVar('OX_SPEC_GEO', 1)

            assert(div.layMeridian(d1, { x = 0, y = 0, z = 0 }) ~= nil)
            assert(div.layMeridian(d2, { x = 0, y = 0, z = 0 }) ~= nil)
            local casters = { [95] = { x = 10, y = 0, z = 0 }, [96] = { x = 10, y = 0, z = 0 } }

            -- Inside both lines: strongest (+35) wins
            assert(div.sampleAllyBonus({ x = 5, y = 0, z = 1 }, 100, casters) == 35)
            -- Beyond segment end (x = 14) or outside width (z = 4) or another floor (y = 5): 0 bonus
            assert(div.sampleAllyBonus({ x = 14, y = 0, z = 0 }, 100, casters) == 0)
            assert(div.sampleAllyBonus({ x = 5, y = 0, z = 4 }, 100, casters) == 0)
            assert(div.sampleAllyBonus({ x = 5, y = 5, z = 0 }, 100, casters) == 0)

            -- Shift d1 to caster pos (10,0,0): segment length 0 (<3y) -> inactive, weaker d2 (+12) takes over!
            assert(div.shiftMeridian(d1, { x = 10, y = 0, z = 0 }) ~= nil)
            assert(div.sampleAllyBonus({ x = 5, y = 0, z = 1 }, 100, casters) == 12)
        """)


if __name__ == '__main__':
    unittest.main()
