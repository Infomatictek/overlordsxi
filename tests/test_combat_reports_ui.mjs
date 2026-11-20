import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const SITE_DIR = path.join(REPO_ROOT, 'site');

const crModule = require(path.join(SITE_DIR, 'combat-reports.js'));
const {
  parseJsonlText,
  computeRollingAverage,
  buildTimeSeriesClient,
  analyzeEncounterClient,
  createSyntheticDemoReport,
  buildMarkdownClient,
  formatCombatMs,
  formatMetric,
} = crModule._internals;

test('wiki index.html preserves existing navigation and adds Combat Reports cleanly', () => {
  const html = fs.readFileSync(path.join(SITE_DIR, 'index.html'), 'utf8');
  for (const page of ['overview', 'combat', 'crystals', 'talents', 'companions', 'commands', 'patches', 'reports']) {
    assert.ok(html.includes(`data-page="${page}"`), `Expected nav item data-page="${page}"`);
  }
  assert.ok(html.includes('combat-reports.css'), 'Expected combat-reports.css link');
  assert.ok(html.includes('combat-reports.js'), 'Expected combat-reports.js script');
  assert.ok(html.includes('data.js'), 'Expected existing data.js script preserved');
  assert.ok(html.includes('syncStatusPill'), 'Expected GitHub sync pill preserved');
});

test('parseJsonlText parses valid JSONL and counts malformed lines safely', () => {
  const sample = '{"run_id":"r1","value":10}\nnot json\n[1,2,3]\n{"run_id":"r2","value":20}\n';
  const parsed = parseJsonlText(sample);
  assert.equal(parsed.items.length, 2);
  assert.equal(parsed.skipped, 2);
  assert.equal(parsed.items[0].run_id, 'r1');
});

test('computeRollingAverage computes exact trailing windows', () => {
  const res = computeRollingAverage([10, 20, 30, 40, 50], 3);
  assert.deepEqual(res, [10, 15, 20, 30, 40]);
});

test('buildTimeSeriesClient handles Lua empty-table objects and never fabricates v1.0.0 series', () => {
  // v1.0.0 summary-only (no snapshots, no events)
  const v1 = buildTimeSeriesClient({ encounter_duration_sec: 45 }, [], []);
  assert.equal(v1.source, 'unavailable');
  assert.equal(v1.points.length, 0);
  assert.equal(v1.has_vitals, false);

  // v2.0.0 snapshots with Lua `{}` for empty pets_and_clones
  const snaps = [
    {
      combat_sec: 0,
      players: [{ hp: 500, max_hp: 500, hp_pct: 100, mp: 100, max_mp: 200, tp: 500, alive: true }],
      boss: { hp: 1000, max_hp: 1000, hp_pct: 100, ce_primary: 100, ve_primary: 200 },
      pets_and_clones: {},
      interval: { damage_dealt: 100, player_damage: 100, pet_clone_damage: 0, damage_received: 50, healing_done: 0 },
    },
    {
      combat_sec: 1,
      players: [{ hp: 450, max_hp: 500, hp_pct: 90, mp: 80, max_mp: 200, tp: 1000, alive: true }],
      boss: { hp: 800, max_hp: 1000, hp_pct: 80, ce_primary: 150, ve_primary: 250 },
      pets_and_clones: {},
      interval: { damage_dealt: 200, player_damage: 200, pet_clone_damage: 0, damage_received: 0, healing_done: 50 },
    },
  ];
  const v2 = buildTimeSeriesClient({}, snaps, []);
  assert.equal(v2.source, 'snapshots');
  assert.equal(v2.has_vitals, true);
  assert.equal(v2.has_mp, true);
  assert.equal(v2.points.length, 2);
  assert.equal(v2.points[1].rolling_dps_5s, 150);
  assert.equal(v2.points[0].player_mp_pct, 50);
});

test('formatMetric preserves unavailable strings with tooltip and never fabricates zero', () => {
  const html = formatMetric('unavailable', { overhealing: 'unavailable: MAGIC_USE reports applied recovery only' }, 'overhealing');
  assert.ok(html.includes('Unavailable'));
  assert.ok(html.includes('MAGIC_USE reports applied recovery only'));
  assert.ok(!html.includes('>0<'));
});

test('synthetic demo report triggers expected deterministic rules and exports Markdown', () => {
  const demo = createSyntheticDemoReport();
  assert.equal(demo.is_demo, true);
  assert.equal(demo.meta.character_name, 'DemoTester (Synthetic)');
  const rules = new Set(demo.diagnostics.findings.map((f) => f.rule));
  assert.ok(rules.has('damage_spike'), 'Expected damage_spike finding');
  assert.ok(rules.has('clone_loss'), 'Expected clone_loss finding');
  assert.ok(rules.has('combat_downtime'), 'Expected combat_downtime finding');
  assert.ok(rules.has('tp_cap_waste'), 'Expected tp_cap_waste finding');
  assert.ok(rules.has('healing_downtime'), 'Expected healing_downtime finding');

  const md = buildMarkdownClient(demo);
  assert.ok(md.includes(demo.meta.run_id));
  assert.ok(md.includes('Deterministic Findings'));
  assert.equal(formatCombatMs(11600, 'combat'), '+00:11.60');
  assert.equal(formatCombatMs(null, 'preparation'), 'prep');
});

test('analyzeEncounterClient detects player death + 5s recap, OOM, interrupts, and threat losses', () => {
  const summary = {
    outcome: 'defeat',
    metrics: {
      offense: { spell_interrupts: 2, spell_casts: 4 },
      defense: { deaths: 1 },
      healing: { healing_downtime_sec: 'unavailable' },
      threat: { threat_losses: 1 },
      resources_and_pets: { pet_uptime_pct: 55 },
    },
  };
  const events = [
    { combat_ms: 8000, phase: 'combat', event_type: 'damage_taken', source_name: 'Boss', target_name: 'Hero', value: 200 },
    { combat_ms: 10000, phase: 'combat', event_type: 'death', source_name: 'Boss', target_name: 'Hero', value: 0 },
  ];
  const snaps = Array.from({ length: 10 }, (_, s) => ({
    combat_sec: s,
    players: [{ hp: 400 - s * 30, max_hp: 400, hp_pct: ((400 - s * 30) / 400) * 100, mp: s >= 3 ? 0 : 100, max_mp: 200, tp: 500, alive: s < 9 }],
    boss: { hp: 1000, max_hp: 1000, hp_pct: 100 },
    pets_and_clones: [],
    interval: { damage_dealt: 50, player_damage: 50, pet_clone_damage: 0, damage_received: 30, healing_done: 0 },
  }));
  const ts = buildTimeSeriesClient(summary, snaps, events);
  const diag = analyzeEncounterClient(summary, events, ts);
  const rules = new Set(diag.findings.map((f) => f.rule));
  assert.ok(rules.has('player_death'));
  assert.ok(rules.has('mp_depletion'));
  assert.ok(rules.has('spell_interrupts'));
  assert.ok(rules.has('threat_loss'));
  assert.ok(rules.has('pet_low_uptime'));
  const deathFinding = diag.findings.find((f) => f.rule === 'player_death');
  assert.equal(deathFinding.evidence.recap_5s.length, 1);
});

test('mount renders auth gate cleanly when backend returns unauthenticated', async () => {
  const prevFetch = globalThis.fetch;
  const prevDoc = globalThis.document;
  globalThis.fetch = async (url) => {
    if (String(url).endsWith('/auth/me')) {
      return {
        ok: true,
        status: 200,
        text: async () => JSON.stringify({
          authenticated: false,
          user: null,
          csrf_token: null,
          providers: ['local', 'discord'],
          retention_per_character: 50,
        }),
      };
    }
    return { ok: false, status: 404, text: async () => '{}' };
  };
  globalThis.document = {
    getElementById: () => null,
  };
  const container = {
    innerHTML: '',
    querySelector: () => null,
    querySelectorAll: () => [],
  };
  try {
    await crModule.mount(container, {});
    assert.ok(container.innerHTML.includes('Sign In to Private Reports'));
    assert.ok(container.innerHTML.includes('Do not use your FFXI game password'));
    assert.ok(container.innerHTML.includes('Sign in with Discord'));
    assert.ok(container.innerHTML.includes('Local Read-Only JSONL Viewer'));
  } finally {
    globalThis.fetch = prevFetch;
    globalThis.document = prevDoc;
  }
});
