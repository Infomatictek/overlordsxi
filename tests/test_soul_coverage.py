"""Unit tests for static registration evidence extraction."""
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'audit_soul_coverage.py'
spec = importlib.util.spec_from_file_location('audit_souls', SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class RegistrationEvidenceTests(unittest.TestCase):
    def test_ignores_parentheses_inside_strings(self):
        source = """spec.registerJob(xi.job.MNK, 'MNK', {
            {key = SENSEI_KEY, description = 'test (more)'},
            {key = BLACKBELT_KEY, description = 'not ) done'},
            {key = CHIWEAVER_KEY},
        })"""
        hit = mod.REGISTRATION.search(source)
        args = mod.extract_registration_args(source, hit.end())
        keys = set()
        for match in mod.KEY_ASSIGNMENT.finditer(args):
            keys.add(match.group(2))
        self.assertEqual(keys, {'SENSEI_KEY', 'BLACKBELT_KEY', 'CHIWEAVER_KEY'})

    def test_quoted_escaped_parenthesis(self):
        source = """spec.registerCrystal(xi.job.NIN, {
            key = 'kurogane', name = 'Shadow \\' )',
        })"""
        hit = mod.REGISTRATION.search(source)
        self.assertIn('kurogane', mod.extract_registration_args(source, hit.end()))

    def test_handles_nested_functions(self):
        source = """spec.registerJob(xi.job.RUN, 'RUN', {
          {key = SPELLBLADE_KEY, mods = function(p) return
            { {xi.mod.ATT, math.floor(p:getMainLvl() / 2)} } end},
          {key = LIFEBINDER_KEY}
        })"""
        hit = mod.REGISTRATION.search(source)
        args = mod.extract_registration_args(source, hit.end())
        self.assertIn('LIFEBINDER_KEY', args)


if __name__ == '__main__':
    unittest.main()
