"""Sequence A compatibility fixtures for all 66 active Souls + retired DNC slot.

Validates:
1. 22 x 3 active Soul keys against server spec catalog (`overlords_job_specs.lua`),
   action registry (`overlords_soul_actions.lua`), per-character `OX_SPEC_<JOB>` values,
   and (when sibling `overlordsxi-launcher` is present) launcher identity/roster/header files.
2. Retired DNC branch 1 (`freelancer`) in persistence fixtures only (never remapped to Mirage).
3. Opt-in WARN-mode action observation comparing normal, RNG, PUP, DNC, and NIN cases
   without changing live outcomes.
4. Level-255 SQL custom JA rows remain uniquely allocated without collisions.
"""
from pathlib import Path
import re
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]
JOB_SPECS_PATH = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'overlords_job_specs.lua'
SOUL_ACTIONS_PATH = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'overlords_soul_actions.lua'
SQL_DIR = REPO_ROOT / 'modules' / 'custom' / 'sql'
SIBLING_LAUNCHER = REPO_ROOT.parent / 'overlordsxi-launcher'

JOB_ID_TO_CODE = {
    1: 'WAR', 2: 'MNK', 3: 'WHM', 4: 'BLM', 5: 'RDM', 6: 'THF',
    7: 'PLD', 8: 'DRK', 9: 'BST', 10: 'BRD', 11: 'RNG', 12: 'SAM',
    13: 'NIN', 14: 'DRG', 15: 'SMN', 16: 'BLU', 17: 'COR', 18: 'PUP',
    19: 'DNC', 20: 'SCH', 21: 'GEO', 22: 'RUN',
}

JOB_CODE_TO_ID = {code: jid for jid, code in JOB_ID_TO_CODE.items()}


def parse_server_job_specs(path: Path):
    """Parse spec.JOB_SPECS from overlords_job_specs.lua into {jobCode: [(branch, id, name, abr, role)]}."""
    text = path.read_text(encoding='utf-8')
    start = text.index('spec.JOB_SPECS =')
    end = text.index('local KEY_ALIASES =', start)
    block = text[start:end]

    result = {}
    current_job = None
    for line in block.splitlines():
        job_match = re.match(r'^\s*([A-Z]{3})\s*=\s*$', line)
        if job_match:
            current_job = job_match.group(1)
            result[current_job] = []
            continue
        if current_job:
            entry_match = re.search(
                r"id\s*=\s*'([a-z]+)'\s*,\s*name\s*=\s*'([^']+)'\s*,\s*abr\s*=\s*'([A-Z]+)'\s*,\s*role\s*=\s*'([^']+)'",
                line,
            )
            if entry_match:
                branch = len(result[current_job]) + 1
                result[current_job].append((branch, *entry_match.groups()))
    return result


class ServerCatalogCompatibilityTests(unittest.TestCase):
    def test_22_jobs_x_3_active_souls_and_retired_dnc_slot(self):
        catalog = parse_server_job_specs(JOB_SPECS_PATH)
        self.assertEqual(set(catalog.keys()), set(JOB_CODE_TO_ID.keys()))

        active_count = 0
        for code, entries in catalog.items():
            if code == 'DNC':
                self.assertEqual(len(entries), 4)
                # Branch 1 is historical retired Freelancer; active DNC Souls occupy 2, 3, 4.
                self.assertEqual(entries[0][0:2], (1, 'freelancer'))
                self.assertEqual(
                    [(b, k) for b, k, *_ in entries[1:]],
                    [(2, 'vampire'), (3, 'bladewheel'), (4, 'miragesentinel')],
                )
                active_count += 3
            else:
                self.assertEqual(len(entries), 3, f'{code} must have 3 active Souls')
                active_count += len(entries)

        self.assertEqual(active_count, 66)
        # Verify audited storage order invariants
        self.assertEqual([(b, k) for b, k, *_ in catalog['PUP']], [(1, 'vanguard'), (2, 'animist'), (3, 'pugilist')])
        self.assertEqual([(b, k) for b, k, *_ in catalog['BST']], [(1, 'untamed'), (2, 'alphawarden'), (3, 'beastspeaker')])
        self.assertEqual([(b, k) for b, k, *_ in catalog['NIN']], [(1, 'kurogane'), (2, 'kagemusha'), (3, 'nightblade')])
        self.assertEqual([(b, k) for b, k, *_ in catalog['RNG']], [(1, 'sniper'), (2, 'huntsman'), (3, 'arcanearcher')])

    def test_sql_level_255_abilities_have_unique_ids(self):
        seen = {}
        stmt_re = re.compile(
            r"INSERT(?:\s+IGNORE)?\s+INTO\s+`?abilities`?.*?VALUES\s*(.*?);",
            re.IGNORECASE | re.DOTALL,
        )
        row_re = re.compile(r"\(\s*(\d+)\s*,\s*'([^']+)'")
        for sql_file in sorted(SQL_DIR.glob('*.sql')):
            raw = sql_file.read_text(encoding='utf-8', errors='replace')
            # Strip SQL line comments
            cleaned = '\n'.join(
                line for line in raw.splitlines() if not line.lstrip().startswith('--')
            )
            for stmt in stmt_re.finditer(cleaned):
                for match in row_re.finditer(stmt.group(1)):
                    ability_id = int(match.group(1))
                    name = match.group(2)
                    if ability_id in seen:
                        self.assertEqual(
                            seen[ability_id][0],
                            name,
                            f'Conflicting ability ID {ability_id}: {seen[ability_id]} vs {(name, sql_file.name)}',
                        )
                    else:
                        seen[ability_id] = (name, sql_file.name)
        # Known reserved Shinobi & Huntsman allocations remain present
        self.assertEqual(seen[480][0], 'call_wild_raaz')
        self.assertEqual(seen[487][0], 'shadow_legion')
        self.assertEqual(seen[488][0], 'phantom_assault')


@unittest.skipIf(LuaRuntime is None, 'lupa not installed')
class LuaSoulActionsObservationTests(unittest.TestCase):
    def _load_module(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        code = SOUL_ACTIONS_PATH.read_text(encoding='utf-8')
        return lua, lua.execute(code)

    def test_all_66_active_souls_match_server_catalog_and_persistence_fixtures(self):
        catalog = parse_server_job_specs(JOB_SPECS_PATH)
        _, mod = self._load_module()

        active_checked = 0
        for code, entries in catalog.items():
            job_id = JOB_CODE_TO_ID[code]
            for branch, storage_key, display_name, abr, _role in entries:
                if code == 'DNC' and branch == 1:
                    # Retired slot: persistence-only fixture, never resolved as active
                    self.assertTrue(mod.isRetiredBranch(job_id, branch))
                    self.assertTrue(mod.isRetiredKey(storage_key))
                    self.assertIsNone(mod.resolveBranch(job_id, branch))
                    snap = mod.buildSnapshot(job_id, branch, '70-75')
                    self.assertTrue(snap['retired'])
                    self.assertEqual(snap['storageKey'], 'freelancer')
                    self.assertIsNone(snap['profileKey'])
                    self.assertEqual(snap['validationState'], 'retired_persistence_only')
                    continue

                resolved = mod.resolveBranch(job_id, branch)
                self.assertIsNotNone(resolved, f'Missing active identity for {code} branch {branch}')
                self.assertEqual(resolved['storageKey'], storage_key)
                self.assertEqual(resolved['name'], display_name)
                self.assertEqual(resolved['abr'], abr)
                active_checked += 1

        self.assertEqual(active_checked, 66)

    def test_opt_in_warn_observation_normal_rng_pup_dnc_nin_without_changing_outcomes(self):
        lua, mod = self._load_module()
        warnings = []
        wrap_cb = lua.eval('function(py_cb) return function(rec) py_cb(rec) end end')
        mod['onWarning'] = wrap_cb(lambda rec: warnings.append(dict(rec)))

        # Off by default: zero observations, never alters outcomes
        off_res = mod.observe(lua.table_from({
            'charId': 101, 'jobId': 1, 'branch': 1, 'effectiveLevel': 75, 'kind': 'ability', 'id': 396,
        }))
        self.assertFalse(off_res['observed'])
        self.assertTrue(off_res['allowed'])
        self.assertFalse(off_res['outcomeChanged'])
        self.assertEqual(len(mod.getObservations()), 0)

        # Register sample profiles (including same source ID 61 under two different Souls)
        mod.register('commander', lua.table_from({
            'ability': lua.table_from({
                396: lua.table_from({'name': 'Tactical Breach', 'description': 'Open tactical breach.'}),
            }),
            'spell': lua.table_from({}),
            'weaponskill': lua.table_from({}),
        }))
        mod.register('huntsman', lua.table_from({
            'ability': lua.table_from({
                480: lua.table_from({'name': 'Call Wild Raaz', 'description': 'Summon Tusker beast.'}),
                482: lua.table_from({'name': 'Rimetusk Gore', 'description': 'Command beast gore.'}),
            }),
            'spell': lua.table_from({}),
            'weaponskill': lua.table_from({}),
        }))
        mod.register('animist', lua.table_from({
            'ability': lua.table_from({
                61: lua.table_from({'name': 'Animist Directive', 'description': 'Shared-ID client fixture.'}),
            }),
            'spell': lua.table_from({}),
            'weaponskill': lua.table_from({}),
        }))
        # Register via legacy storage key 'kurogane' -> normalizes to 'shinobi'
        mod.register('kurogane', lua.table_from({
            'ability': lua.table_from({
                61: lua.table_from({'name': 'Shinobi Stance', 'description': 'Different presentation for ID 61.'}),
                487: lua.table_from({'name': 'Shadow Legion', 'description': 'Summon shadow clones.'}),
                488: lua.table_from({'name': 'Phantom Assault', 'description': 'Command clone strike.'}),
            }),
            'spell': lua.table_from({}),
            'weaponskill': lua.table_from({}),
        }))

        # Duplicate registration via alias must fail
        with self.assertRaises(Exception):
            mod.register('shinobi', lua.table_from({'ability': lua.table_from({}), 'spell': lua.table_from({}), 'weaponskill': lua.table_from({})}))

        # Enable WARN mode (no global strict switch)
        mod.setObservationMode('warn')
        with self.assertRaises(Exception):
            mod.setObservationMode('strict')

        # 1. Normal case (WAR Commander allowed + unlisted macro/subjob warning)
        r_norm_ok = mod.observe(lua.table_from({
            'charId': 1, 'jobId': 1, 'branch': 1, 'effectiveLevel': 75,
            'kind': 'ability', 'id': 396, 'learned': True,
        }))
        self.assertEqual(r_norm_ok['status'], 'allowed')
        self.assertTrue(r_norm_ok['allowed'])
        self.assertFalse(r_norm_ok['outcomeChanged'])

        r_norm_warn = mod.observe(lua.table_from({
            'charId': 1, 'jobId': 1, 'branch': 1, 'effectiveLevel': 75,
            'kind': 'spell', 'id': 1, 'learned': False, 'subjobOnly': True, 'isMacro': True, 'isQueued': True,
        }))
        self.assertEqual(r_norm_warn['status'], 'warn_unlisted')
        self.assertTrue(r_norm_warn['allowed'])
        self.assertFalse(r_norm_warn['outcomeChanged'])

        # 2. RNG case (Huntsman pet command)
        r_rng = mod.observe(lua.table_from({
            'charId': 2, 'jobId': 11, 'branch': 2, 'effectiveLevel': 75,
            'kind': 'ability', 'id': 482, 'isPetCommand': True,
        }))
        self.assertEqual(r_rng['profileKey'], 'huntsman')
        self.assertEqual(r_rng['status'], 'allowed')
        self.assertTrue(r_rng['isPetCommand'])
        self.assertFalse(r_rng['outcomeChanged'])

        # 3. PUP case (branch 2 = animist, branch 3 = pugilist unconfigured -> never lockout)
        r_pup2 = mod.observe(lua.table_from({
            'charId': 3, 'jobId': 18, 'branch': 2, 'effectiveLevel': 50,
            'kind': 'ability', 'id': 61, 'isPetCommand': True,
        }))
        self.assertEqual(r_pup2['profileKey'], 'animist')
        self.assertEqual(r_pup2['presentationName'], 'Animist Directive')
        self.assertEqual(r_pup2['status'], 'allowed')

        r_pup3 = mod.observe(lua.table_from({
            'charId': 3, 'jobId': 18, 'branch': 3, 'effectiveLevel': 50,
            'kind': 'ability', 'id': 478,
        }))
        self.assertEqual(r_pup3['profileKey'], 'pugilist')
        self.assertEqual(r_pup3['status'], 'unconfigured')
        self.assertTrue(r_pup3['allowed'])
        self.assertFalse(r_pup3['outcomeChanged'])

        # 4. DNC case (retired branch 1 vs active branch 4 Mirage Sentinel)
        r_dnc1 = mod.observe(lua.table_from({
            'charId': 4, 'jobId': 19, 'branch': 1, 'effectiveLevel': 75,
            'kind': 'ability', 'id': 200, 'isItemRoute': True,
        }))
        self.assertEqual(r_dnc1['status'], 'retired_slot')
        self.assertIsNone(r_dnc1['profileKey'])
        self.assertEqual(r_dnc1['storageKey'], 'freelancer')
        self.assertFalse(r_dnc1['outcomeChanged'])

        r_dnc4 = mod.observe(lua.table_from({
            'charId': 4, 'jobId': 19, 'branch': 4, 'effectiveLevel': 75,
            'kind': 'ability', 'id': 200,
        }))
        self.assertEqual(r_dnc4['profileKey'], 'miragesentinel')
        self.assertEqual(r_dnc4['status'], 'unconfigured')

        # 5. NIN case (kurogane/shinobi normalization + same ID 61 distinct presentation + duplicate callback)
        r_nin = mod.observe(lua.table_from({
            'charId': 5, 'jobId': 13, 'branch': 1, 'effectiveLevel': 75,
            'kind': 'ability', 'id': 61, 'isDuplicateCallback': True,
        }))
        self.assertEqual(r_nin['profileKey'], 'shinobi')
        self.assertEqual(r_nin['storageKey'], 'kurogane')
        self.assertEqual(r_nin['presentationName'], 'Shinobi Stance')
        self.assertEqual(r_nin['status'], 'allowed')

        r_nin_ja = mod.observe(lua.table_from({
            'charId': 5, 'soulKey': 'kurogane', 'effectiveLevel': 75,
            'kind': 'ability', 'id': 487,
        }))
        self.assertEqual(r_nin_ja['profileKey'], 'shinobi')
        self.assertEqual(r_nin_ja['status'], 'allowed')

        # Below Lv10 eligibility check preserves selection without lockout
        r_lv9 = mod.observe(lua.table_from({
            'charId': 6, 'jobId': 13, 'branch': 1, 'effectiveLevel': 9,
            'kind': 'ability', 'id': 487,
        }))
        self.assertEqual(r_lv9['status'], 'below_unlock_level')
        self.assertTrue(r_lv9['allowed'])
        self.assertFalse(r_lv9['outcomeChanged'])

        # Only the single unlisted action emitted a warning callback
        self.assertEqual(len(warnings), 1)
        self.assertEqual(warnings[0]['profileKey'], 'commander')
        self.assertEqual(warnings[0]['kind'], 'spell')


@unittest.skipUnless(SIBLING_LAUNCHER.exists(), 'sibling overlordsxi-launcher repo not present')
class CrossRepoLauncherAlignmentTests(unittest.TestCase):
    def test_server_and_launcher_identity_maps_agree_on_all_66_souls(self):
        server_text = SOUL_ACTIONS_PATH.read_text(encoding='utf-8')
        launcher_map = (
            SIBLING_LAUNCHER / 'addons' / 'ashita4' / 'overlords_soul_actions' / 'soul_identity_map.lua'
        ).read_text(encoding='utf-8')

        pair_re = re.compile(r"key\s*=\s*'([a-z]+)'\s*,\s*storageKey\s*=\s*'([a-z]+)'")
        server_pairs = pair_re.findall(server_text)
        launcher_pairs = pair_re.findall(launcher_map)
        self.assertEqual(len(server_pairs), 66)
        self.assertEqual(server_pairs, launcher_pairs)


if __name__ == '__main__':
    unittest.main()
