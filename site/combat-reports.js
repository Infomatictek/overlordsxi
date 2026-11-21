/**
 * SoulspireXI Wiki — Combat Reports Analytics Dashboard
 * -----------------------------------------------------
 * Visualizes Soul Proving Grounds server-side JSONL telemetry (schema v1 & v2).
 * Supports:
 *  - Authenticated private backend mode (/api/combat/* behind SWAG/Nginx)
 *  - Shared read-only links (#share/<token>)
 *  - Local offline read-only JSONL file viewer & clearly labeled synthetic demo
 *  - 1-second damage graphs, rolling averages, event markers, HP/MP/TP, pets/clones
 *  - Deterministic anomaly detection (zero AI tokens)
 *  - Fight-feel feedback, timestamped notes, pinning, sharing, JSONL/PNG/MD/CSV exports
 */
(function (root) {
  'use strict';

  const UNAVAILABLE = 'unavailable';
  const API_BASE_KEY = 'overlordsxi_combat_api_base_v1';
  const FEEDBACK_OPTIONS_DEFAULT = [
    { key: 'felt_great', label: 'Felt Great' },
    { key: 'damage_felt_weak', label: 'Damage Felt Weak' },
    { key: 'survival_felt_bad', label: 'Survival Felt Bad' },
    { key: 'resource_problems', label: 'Resource Problems' },
    { key: 'mechanics_felt_unfair', label: 'Mechanics Felt Unfair' },
    { key: 'skip', label: 'Skip / Neutral' },
  ];

  // =========================================================================
  // Pure Helpers & Client-Side Schema/Diagnostics Mirror (for local/demo mode)
  // =========================================================================
  function escapeHtml(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function isNum(v) {
    return typeof v === 'number' && Number.isFinite(v);
  }

  function normalizeLuaList(v) {
    return Array.isArray(v) ? v : [];
  }

  function formatMetric(val, availMap, availKey, suffix = '') {
    if (val === UNAVAILABLE || val === undefined || val === null) {
      const tip = (availMap && availKey && availMap[availKey]) || 'Not instrumented in this telemetry schema';
      return `<span class="unavailable-pill" title="${escapeHtml(tip)}">Unavailable</span>`;
    }
    if (typeof val === 'boolean') return val ? 'Yes' : 'No';
    if (typeof val === 'number') {
      const s = Number.isInteger(val) ? val.toLocaleString() : Number(val.toFixed(2)).toLocaleString();
      return `${s}${suffix}`;
    }
    return `${escapeHtml(val)}${suffix}`;
  }

  function formatPctFromRatio(val, availMap, availKey) {
    if (!isNum(val)) return formatMetric(val, availMap, availKey);
    return `${(val * 100).toFixed(1)}%`;
  }

  function formatCombatMs(ms, phase) {
    if (!isNum(ms)) return phase === 'preparation' ? 'prep' : '—';
    const totalSec = ms / 1000;
    const mins = Math.floor(totalSec / 60);
    const secs = (totalSec - mins * 60).toFixed(2).padStart(5, '0');
    return `+${String(mins).padStart(2, '0')}:${secs}`;
  }

  function parseJsonlText(text) {
    const out = [];
    let skipped = 0;
    for (const raw of String(text || '').split(/\r?\n/)) {
      const line = raw.trim();
      if (!line) continue;
      try {
        const obj = JSON.parse(line);
        if (obj && typeof obj === 'object' && !Array.isArray(obj)) out.push(obj);
        else skipped++;
      } catch (_) {
        skipped++;
      }
    }
    return { items: out, skipped };
  }

  function computeRollingAverage(values, windowSec) {
    const win = Math.max(1, windowSec | 0);
    const out = [];
    let running = 0;
    for (let i = 0; i < values.length; i++) {
      running += values[i];
      if (i >= win) running -= values[i - win];
      out.push(Number((running / Math.min(i + 1, win)).toFixed(2)));
    }
    return out;
  }

  function buildTimeSeriesClient(summary, snapshots, events) {
    const normSnaps = (snapshots || []).map((s) => ({
      ...s,
      players: normalizeLuaList(s.players),
      pets_and_clones: normalizeLuaList(s.pets_and_clones),
    }));
    const points = [];
    let source = 'unavailable';

    if (normSnaps.length > 0) {
      source = 'snapshots';
      const bySec = new Map();
      let maxSec = 0;
      for (const s of normSnaps) {
        const sec = isNum(s.combat_sec) ? Math.floor(s.combat_sec) : isNum(s.combat_ms) ? Math.floor(s.combat_ms / 1000) : bySec.size;
        bySec.set(sec, s);
        if (sec > maxSec) maxSec = sec;
      }
      let lastKnown = null;
      for (let sec = 0; sec <= maxSec; sec++) {
        const snap = bySec.get(sec) || null;
        if (snap) lastKnown = snap;
        const ref = snap || lastKnown || {};
        const iv = (snap && snap.interval) || {};
        const cum = (ref && ref.cumulative) || {};
        const p0 = (ref.players && ref.players[0]) || {};
        const boss = ref.boss || {};
        const comps = normalizeLuaList(ref.pets_and_clones);
        const aliveComps = comps.filter((c) => c && c.alive !== false);
        const hpVals = comps.filter((c) => c && isNum(c.hp_pct)).map((c) => c.hp_pct);
        const mpPct = isNum(p0.mp) && isNum(p0.max_mp) && p0.max_mp > 0 ? Number(((p0.mp / p0.max_mp) * 100).toFixed(2)) : null;

        points.push({
          sec,
          damage_dealt: isNum(iv.damage_dealt) ? iv.damage_dealt : 0,
          player_damage: isNum(iv.player_damage) ? iv.player_damage : 0,
          pet_clone_damage: isNum(iv.pet_clone_damage) ? iv.pet_clone_damage : 0,
          damage_received: isNum(iv.damage_received) ? iv.damage_received : 0,
          healing_done: isNum(iv.healing_done) ? iv.healing_done : 0,
          cum_damage: isNum(cum.total_damage) ? cum.total_damage : null,
          cum_incoming: isNum(cum.incoming_damage) ? cum.incoming_damage : null,
          cum_healing: isNum(cum.effective_healing) ? cum.effective_healing : null,
          player_hp: isNum(p0.hp) ? p0.hp : null,
          player_max_hp: isNum(p0.max_hp) ? p0.max_hp : null,
          player_hp_pct: isNum(p0.hp_pct) ? p0.hp_pct : null,
          player_mp: isNum(p0.mp) ? p0.mp : null,
          player_max_mp: isNum(p0.max_mp) ? p0.max_mp : null,
          player_mp_pct: mpPct,
          player_tp: isNum(p0.tp) ? p0.tp : null,
          player_alive: typeof p0.alive === 'boolean' ? p0.alive : null,
          player_buffs: isNum(p0.buff_count) ? p0.buff_count : null,
          boss_hp: isNum(boss.hp) ? boss.hp : null,
          boss_max_hp: isNum(boss.max_hp) ? boss.max_hp : null,
          boss_hp_pct: isNum(boss.hp_pct) ? boss.hp_pct : null,
          boss_ce: isNum(boss.ce_primary) ? boss.ce_primary : null,
          boss_ve: isNum(boss.ve_primary) ? boss.ve_primary : null,
          boss_target: boss.target_name || null,
          pet_count: comps.length,
          pet_alive_count: aliveComps.length,
          pet_avg_hp_pct: hpVals.length ? Number((hpVals.reduce((a, b) => a + b, 0) / hpVals.length).toFixed(2)) : null,
        });
      }
    } else if (events && events.length > 0) {
      const combatEvs = events.filter((e) => e.phase === 'combat' && isNum(e.combat_ms));
      if (combatEvs.length > 0) {
        source = 'events_binned';
        let maxSec = Math.max(...combatEvs.map((e) => Math.floor(e.combat_ms / 1000)));
        if (isNum(summary?.encounter_duration_sec) && Math.floor(summary.encounter_duration_sec) > maxSec) {
          maxSec = Math.floor(summary.encounter_duration_sec);
        }
        const buckets = Array.from({ length: maxSec + 1 }, () => ({ dmg: 0, p: 0, pet: 0, inc: 0, heal: 0 }));
        for (const ev of combatEvs) {
          const sec = Math.max(0, Math.min(maxSec, Math.floor(ev.combat_ms / 1000)));
          const v = isNum(ev.value) ? ev.value : 0;
          if (ev.event_type === 'damage_dealt') { buckets[sec].dmg += v; buckets[sec].p += v; }
          else if (ev.event_type === 'pet_damage') { buckets[sec].dmg += v; buckets[sec].pet += v; }
          else if (ev.event_type === 'damage_taken') buckets[sec].inc += v;
          else if (ev.event_type === 'heal_applied') buckets[sec].heal += v;
        }
        let cd = 0, ci = 0, ch = 0;
        buckets.forEach((b, sec) => {
          cd += b.dmg; ci += b.inc; ch += b.heal;
          points.push({
            sec, damage_dealt: b.dmg, player_damage: b.p, pet_clone_damage: b.pet,
            damage_received: b.inc, healing_done: b.heal,
            cum_damage: cd, cum_incoming: ci, cum_healing: ch,
            player_hp: null, player_max_hp: null, player_hp_pct: null,
            player_mp: null, player_max_mp: null, player_mp_pct: null,
            player_tp: null, player_alive: null, boss_hp: null, boss_max_hp: null, boss_hp_pct: null,
            boss_ce: null, boss_ve: null, pet_count: null, pet_alive_count: null, pet_avg_hp_pct: null,
          });
        });
      }
    }

    const r3 = computeRollingAverage(points.map((p) => p.damage_dealt), 3);
    const r5 = computeRollingAverage(points.map((p) => p.damage_dealt), 5);
    const r10 = computeRollingAverage(points.map((p) => p.damage_dealt), 10);
    const ri5 = computeRollingAverage(points.map((p) => p.damage_received), 5);
    const rh5 = computeRollingAverage(points.map((p) => p.healing_done), 5);
    points.forEach((p, i) => {
      p.rolling_dps_3s = r3[i];
      p.rolling_dps_5s = r5[i];
      p.rolling_dps_10s = r10[i];
      p.rolling_inc_5s = ri5[i];
      p.rolling_hps_5s = rh5[i];
    });

    return {
      source,
      points,
      has_vitals: source === 'snapshots',
      has_mp: points.some((p) => (p.player_max_mp || 0) > 0),
      has_pets: points.some((p) => (p.pet_count || 0) > 0) || (events || []).some((e) => e.category === 'pet'),
    };
  }

  function extractMarkersClient(events) {
    const markers = [];
    for (const ev of events || []) {
      if (!isNum(ev.combat_ms)) continue;
      const sec = Number((ev.combat_ms / 1000).toFixed(2));
      const m = ev.meta || {};
      const t = ev.event_type;
      if (t === 'weaponskill_use' || (t === 'damage_dealt' && m.source_kind === 'ws')) {
        markers.push({ sec, seq: ev.seq, kind: 'weaponskill', label: `${m.skill_name || 'WS'}${isNum(ev.value) && ev.value > 0 ? ` (${ev.value})` : ''}` });
      } else if (t === 'defensive_ability_use') {
        markers.push({ sec, seq: ev.seq, kind: 'defensive_cd', label: m.ability_name || 'Defensive CD' });
      } else if (t === 'damage_spike') {
        markers.push({ sec, seq: ev.seq, kind: 'damage_spike', label: `Spike ${ev.value}${isNum(m.hp_share_pct) ? ` (${m.hp_share_pct}% HP)` : ''}` });
      } else if (t === 'death') {
        markers.push({ sec, seq: ev.seq, kind: 'death', label: `Death: ${ev.target_name || 'Player'}` });
      } else if (t === 'clone_death' || t === 'pet_death') {
        markers.push({ sec, seq: ev.seq, kind: 'clone_loss', label: `${t}: ${ev.target_name || 'Companion'}` });
      } else if (t === 'clone_spawn' || t === 'pet_spawn') {
        markers.push({ sec, seq: ev.seq, kind: 'pet_spawn', label: `Spawn: ${ev.source_name || 'Companion'}` });
      } else if (t === 'boss_ability_start' || t === 'boss_spell_start') {
        markers.push({ sec, seq: ev.seq, kind: 'boss_ability', label: t === 'boss_spell_start' ? `Boss Spell #${m.spell_id ?? ev.value}` : `Boss Skill #${m.skill_id ?? ev.value}` });
      } else if (t === 'boss_hp_threshold') {
        markers.push({ sec, seq: ev.seq, kind: 'boss_threshold', label: `Boss ${ev.value}% HP` });
      } else if (t === 'boss_target_change') {
        markers.push({ sec, seq: ev.seq, kind: 'threat_loss', label: `Target -> ${ev.target_name || ev.value}` });
      }
    }
    return markers;
  }

  function analyzeEncounterClient(summary, events, ts) {
    const findings = [];
    const pts = (ts && ts.points) || [];
    const metrics = (summary && summary.metrics) || {};
    const off = metrics.offense || {};
    const def = metrics.defense || {};
    const heal = metrics.healing || {};
    const thr = metrics.threat || {};
    const res = metrics.resources_and_pets || {};
    const maxHpVals = pts.filter((p) => isNum(p.player_max_hp) && p.player_max_hp > 0).map((p) => p.player_max_hp);
    const maxHp = maxHpVals.length ? Math.max(...maxHpVals) : null;

    const add = (id, rule, severity, category, title, detail, combat_sec = null, evidence = {}) => {
      findings.push({ id, rule, severity, category, title, detail, combat_sec, evidence });
    };

    const spikes = (events || []).filter((e) => e.event_type === 'damage_spike');
    if (spikes.length) {
      spikes.forEach((ev, idx) => {
        const share = ev.meta?.hp_share_pct;
        add(
          `spike_${idx + 1}`, 'damage_spike', isNum(share) && share >= 50 ? 'critical' : 'warning', 'spike',
          `Damage Spike: ${ev.value} dmg${isNum(share) ? ` (${share}% Max HP)` : ''}`,
          `${ev.source_name || 'Boss'} dealt ${ev.value} damage in a single hit.`,
          isNum(ev.combat_ms) ? Number((ev.combat_ms / 1000).toFixed(2)) : null,
          { damage: ev.value, hp_share_pct: share }
        );
      });
    } else if (isNum(def.spike_hit_count) && def.spike_hit_count > 0) {
      add('spike_sum', 'damage_spike', 'warning', 'spike', `${def.spike_hit_count} Damage Spike(s) (Max ${def.max_damage_spike || 0})`, 'Summary recorded >=25% Max HP spike hits.');
    }

    const deaths = (events || []).filter((e) => e.event_type === 'death');
    if (deaths.length) {
      deaths.forEach((ev, idx) => {
        const sec = isNum(ev.combat_ms) ? Number((ev.combat_ms / 1000).toFixed(2)) : null;
        const recap = isNum(ev.combat_ms)
          ? (events || []).filter((p) => isNum(p.combat_ms) && p.combat_ms >= ev.combat_ms - 5000 && p.combat_ms <= ev.combat_ms && ['damage_taken', 'damage_spike', 'heal_applied', 'boss_ability_start', 'defensive_ability_use'].includes(p.event_type))
              .slice(-8)
              .map((p) => ({ combat_sec: Number((p.combat_ms / 1000).toFixed(2)), event_type: p.event_type, source: p.source_name, value: p.value }))
          : [];
        add(`death_${idx + 1}`, 'player_death', 'critical', 'death', `Player Death: ${ev.target_name || 'Player'} defeated by ${ev.source_name || 'Boss'}`, `Defeated at +${sec ?? '?'}s.`, sec, { recap_5s: recap });
      });
    } else if ((isNum(def.deaths) && def.deaths > 0) || summary?.outcome === 'defeat') {
      add('death_sum', 'player_death', 'critical', 'death', 'Encounter Defeat', 'Player death recorded in summary.');
    }

    (events || []).filter((e) => e.event_type === 'clone_death' || e.event_type === 'pet_death').forEach((ev, idx) => {
      const sec = isNum(ev.combat_ms) ? Number((ev.combat_ms / 1000).toFixed(2)) : null;
      const isClone = ev.event_type === 'clone_death';
      add(`comp_${idx + 1}`, isClone ? 'clone_loss' : 'pet_loss', 'warning', 'clone_pet', `${isClone ? 'Clone' : 'Pet'} Lost: ${ev.target_name || 'Companion'}`, `Defeated by ${ev.source_name || 'Boss'} at +${sec ?? '?'}s.`, sec);
    });

    const alivePts = pts.filter((p) => p.player_alive !== false);
    const findRuns = (arr, pred) => {
      const runs = [];
      let s = null, p = null, c = 0;
      for (const item of arr) {
        if (pred(item)) {
          if (s === null) { s = item.sec; c = 1; } else c++;
          p = item.sec;
        } else {
          if (s !== null) runs.push([s, p, c]);
          s = null; p = null; c = 0;
        }
      }
      if (s !== null) runs.push([s, p, c]);
      return runs;
    };

    const dtRuns = findRuns(alivePts, (p) => (p.damage_dealt || 0) <= 0).filter((r) => r[2] >= 5);
    if (dtRuns.length) {
      const total = dtRuns.reduce((a, r) => a + r[2], 0);
      const longest = dtRuns.reduce((a, b) => (b[2] > a[2] ? b : a));
      const pct = Number(((total / Math.max(1, alivePts.length)) * 100).toFixed(1));
      add('combat_downtime', 'combat_downtime', pct >= 20 ? 'warning' : 'info', 'downtime', `Offensive Downtime: ${total}s (${pct}%)`, `Longest zero-damage gap was ${longest[2]}s (+${longest[0]}s to +${longest[1]}s).`, longest[0]);
    }

    if (ts?.has_vitals) {
      const tpRuns = findRuns(alivePts, (p) => isNum(p.player_tp) && p.player_tp >= 2900).filter((r) => r[2] >= 5);
      if (tpRuns.length) {
        const total = tpRuns.reduce((a, r) => a + r[2], 0);
        add('tp_overcap', 'tp_cap_waste', 'warning', 'resource', `TP Capped (>= 2900) for ${total}s`, `TP remained near 3000 without spending starting at +${tpRuns[0][0]}s.`, tpRuns[0][0]);
      }
      if (ts.has_mp) {
        const mpRuns = findRuns(alivePts, (p) => isNum(p.player_mp_pct) && p.player_mp_pct <= 15).filter((r) => r[2] >= 5);
        if (mpRuns.length) {
          const total = mpRuns.reduce((a, r) => a + r[2], 0);
          const hitZero = alivePts.some((p) => p.player_mp === 0 && (p.player_max_mp || 0) > 0);
          add('mp_depletion', 'mp_depletion', hitZero ? 'critical' : 'warning', 'resource', `${hitZero ? 'Out of MP (OOM)' : 'Low MP'} for ${total}s`, `MP remained <= 15% starting at +${mpRuns[0][0]}s.`, mpRuns[0][0]);
        }
      }
    }

    if (isNum(off.spell_interrupts) && off.spell_interrupts > 0) {
      add('spell_interrupts', 'spell_interrupts', 'warning', 'resource', `${off.spell_interrupts} Spell Interrupt(s)`, 'Spell casts were interrupted during combat.');
    }
    if (isNum(thr.threat_losses) && thr.threat_losses > 0) {
      add('threat_losses', 'threat_loss', 'warning', 'resource', `${thr.threat_losses} Threat Loss(es)`, 'Boss switched target away from primary player.');
    }
    if (isNum(res.pet_uptime_pct) && res.pet_uptime_pct < 70) {
      add('pet_uptime', 'pet_low_uptime', 'warning', 'clone_pet', `Low Pet/Clone Uptime (${res.pet_uptime_pct}%)`, 'Companion uptime fell below 70%.');
    }
    if (maxHp && alivePts.length >= 3) {
      let best = 0, bestSec = 0;
      for (let i = 0; i < alivePts.length; i++) {
        let sum = 0;
        for (let j = Math.max(0, i - 2); j <= i; j++) sum += alivePts[j].damage_received || 0;
        if (sum > best) { best = sum; bestSec = alivePts[i].sec; }
      }
      if (best / maxHp >= 0.4) {
        add('burst_3s', 'incoming_burst_3s', best / maxHp >= 0.7 ? 'critical' : 'warning', 'spike', `3-Second Incoming Burst: ${Math.round(best)} dmg (${((best / maxHp) * 100).toFixed(1)}% Max HP)`, `Peak 3s incoming burst ended at +${bestSec}s.`, bestSec);
      }
    }
    if (isNum(heal.healing_downtime_sec) && heal.healing_downtime_sec >= 10) {
      add('heal_gap', 'healing_downtime', 'warning', 'downtime', `Max Healing Gap: ${heal.healing_downtime_sec}s`, 'Longest gap between heals was >= 10s.');
    }

    const counts = { critical: 0, warning: 0, info: 0 };
    findings.forEach((f) => { if (counts[f.severity] !== undefined) counts[f.severity]++; });
    return { rule_engine_version: '1.0.0', counts, total: findings.length, findings };
  }

  /**
   * Purely synthetic, non-private demo encounter (strictly fictional "DemoTester" data)
   * so the static wiki works out-of-the-box for offline evaluation without exposing private logs.
   */
  function createSyntheticDemoReport() {
    const runId = 'pg_demo_synthetic_shinobi_lv75';
    const events = [
      { run_id: runId, seq: 1, phase: 'preparation', session_ms: 0, category: 'lifecycle', event_type: 'session_start', source_id: 1, source_name: 'DemoTester', target_id: 900, target_name: 'DE_Crucible_AoE', value: 75, meta: { boss_type: 'aoe_boss', difficulty: 'very_tough' } },
      { run_id: runId, seq: 2, phase: 'combat', session_ms: 8000, combat_ms: 0, category: 'lifecycle', event_type: 'combat_start', source_id: 1, source_name: 'DemoTester', target_id: 900, target_name: 'DE_Crucible_AoE', value: 'melee_hit', meta: { prep_duration_ms: 8000 } },
      { run_id: runId, seq: 3, phase: 'combat', session_ms: 8200, combat_ms: 200, category: 'pet', event_type: 'clone_spawn', source_id: 101, source_name: 'Shadow_Clone_1', value: 75, meta: { kind: 'clone', owner_id: 1, max_hp: 950 } },
      { run_id: runId, seq: 4, phase: 'combat', session_ms: 8300, combat_ms: 300, category: 'pet', event_type: 'clone_spawn', source_id: 102, source_name: 'Shadow_Clone_2', value: 75, meta: { kind: 'clone', owner_id: 1, max_hp: 950 } },
      { run_id: runId, seq: 5, phase: 'combat', session_ms: 14000, combat_ms: 6000, category: 'offense', event_type: 'damage_dealt', source_id: 1, source_name: 'DemoTester', target_id: 900, target_name: 'DE_Crucible_AoE', value: 1480, meta: { source_kind: 'ws', skill_name: 'Blade: Jin', tp_spent: 1120 } },
      { run_id: runId, seq: 6, phase: 'combat', session_ms: 19000, combat_ms: 11000, category: 'boss', event_type: 'boss_ability_start', source_id: 900, source_name: 'DE_Crucible_AoE', target_id: 1, target_name: 'DemoTester', value: 665, meta: { skill_id: 665 } },
      { run_id: runId, seq: 7, phase: 'combat', session_ms: 19600, combat_ms: 11600, category: 'defense', event_type: 'damage_taken', source_id: 900, source_name: 'DE_Crucible_AoE', target_id: 1, target_name: 'DemoTester', value: 620, meta: { boss_action_seq: 6, boss_skill_id: 665 } },
      { run_id: runId, seq: 8, phase: 'combat', session_ms: 19600, combat_ms: 11600, category: 'defense', event_type: 'damage_spike', source_id: 900, source_name: 'DE_Crucible_AoE', target_id: 1, target_name: 'DemoTester', value: 620, meta: { hp_share_pct: 36.5, boss_action_seq: 6 } },
      { run_id: runId, seq: 9, phase: 'combat', session_ms: 19700, combat_ms: 11700, category: 'pet', event_type: 'clone_death', source_id: 900, source_name: 'DE_Crucible_AoE', target_id: 102, target_name: 'Shadow_Clone_2', value: 0, meta: { kind: 'clone', owner_id: 1 } },
      { run_id: runId, seq: 10, phase: 'combat', session_ms: 21000, combat_ms: 13000, category: 'defense', event_type: 'defensive_ability_use', source_id: 1, source_name: 'DemoTester', target_id: 1, target_name: 'DemoTester', value: 210, meta: { ability_name: 'utsusemi_ni' } },
      { run_id: runId, seq: 11, phase: 'combat', session_ms: 22000, combat_ms: 14000, category: 'defense', event_type: 'heal_applied', source_id: 1, source_name: 'DemoTester', target_id: 1, target_name: 'DemoTester', value: 420, meta: { spell_id: 4 } },
      { run_id: runId, seq: 12, phase: 'combat', session_ms: 28000, combat_ms: 20000, category: 'boss', event_type: 'boss_hp_threshold', source_id: 900, source_name: 'DE_Crucible_AoE', value: 50, meta: { hp_pct: 49.2 } },
      { run_id: runId, seq: 13, phase: 'combat', session_ms: 34000, combat_ms: 26000, category: 'offense', event_type: 'damage_dealt', source_id: 1, source_name: 'DemoTester', target_id: 900, target_name: 'DE_Crucible_AoE', value: 1790, meta: { source_kind: 'ws', skill_name: 'Blade: Ku', tp_spent: 2950 } },
      { run_id: runId, seq: 14, phase: 'combat', session_ms: 42000, combat_ms: 34000, category: 'boss', event_type: 'boss_death', source_id: 1, source_name: 'DemoTester', target_id: 900, target_name: 'DE_Crucible_AoE', value: 0 },
      { run_id: runId, seq: 15, phase: 'post', session_ms: 42000, combat_ms: 34000, category: 'lifecycle', event_type: 'session_end', source_id: 1, source_name: 'DemoTester', target_id: 900, target_name: 'DE_Crucible_AoE', value: 0, meta: { outcome: 'victory' } },
    ];

    const snapshots = [];
    let cumDmg = 0, cumPDmg = 0, cumPet = 0, cumInc = 0, cumHeal = 0;
    let pHp = 1700, bHp = 12500, tp = 0;
    for (let s = 0; s <= 34; s++) {
      const downtime = s >= 15 && s <= 19;
      let pDmg = downtime ? 0 : 210 + ((s * 37) % 90);
      let petDmg = downtime ? 0 : (s < 12 ? 120 : 65);
      if (s === 6) pDmg += 1480;
      if (s === 26) pDmg += 1790;
      const dmg = pDmg + petDmg;
      const inc = s === 11 ? 620 : (s % 3 === 0 ? 115 : 0);
      const heal = s === 14 ? 420 : (s === 24 ? 260 : 0);
      cumDmg += dmg; cumPDmg += pDmg; cumPet += petDmg; cumInc += inc; cumHeal += heal;
      pHp = Math.max(220, Math.min(1700, pHp - inc + heal));
      bHp = Math.max(0, bHp - dmg);
      if (s === 6) tp = 120;
      else if (s >= 20 && s <= 25) tp = 2960; // Intentional synthetic TP cap demonstration
      else if (s === 26) tp = 80;
      else tp = Math.min(2960, tp + 220);

      const comps = s < 12
        ? [
            { id: 101, name: 'Shadow_Clone_1', kind: 'clone', owner_id: 1, hp: 820, max_hp: 950, hp_pct: 86.3, alive: true },
            { id: 102, name: 'Shadow_Clone_2', kind: 'clone', owner_id: 1, hp: Math.max(0, 950 - s * 75), max_hp: 950, hp_pct: Math.max(0, Number((((950 - s * 75) / 950) * 100).toFixed(1))), alive: true },
          ]
        : [{ id: 101, name: 'Shadow_Clone_1', kind: 'clone', owner_id: 1, hp: 640, max_hp: 950, hp_pct: 67.4, alive: true }];

      snapshots.push({
        run_id: runId,
        combat_sec: s,
        combat_ms: s * 1000,
        players: [{ id: 1, name: 'DemoTester', hp: pHp, max_hp: 1700, hp_pct: Number(((pHp / 1700) * 100).toFixed(1)), mp: 0, max_mp: 0, tp, alive: true, buff_count: 3 }],
        boss: { id: 900, name: 'DE_Crucible_AoE', hp: bHp, max_hp: 12500, hp_pct: Number(((bHp / 12500) * 100).toFixed(1)), target_id: 1, target_name: 'DemoTester', ce_primary: 800 + s * 45, ve_primary: 1900 + (s % 5) * 140, debuff_count: 2 },
        pets_and_clones: comps,
        interval: { damage_dealt: dmg, player_damage: pDmg, pet_clone_damage: petDmg, damage_received: inc, healing_done: heal },
        cumulative: { total_damage: cumDmg, player_damage: cumPDmg, pet_clone_damage: cumPet, incoming_damage: cumInc, effective_healing: cumHeal },
        soul_resources: UNAVAILABLE,
      });
    }

    const summary = {
      run_id: runId,
      telemetry_schema_version: '2.0.0',
      timestamp_utc: '2026-11-20T00:00:00Z',
      encounter_id: 'pg_aoe_boss_normal_p75_b78_very_tough_solo',
      encounter_version: '2.0.0',
      soul_name: 'Shinobi',
      soul_key: 'shinobi',
      job: 'NIN',
      role: 'Shadow Clone Melee DPS',
      tier: 'Damage',
      original_character_level: 75,
      effective_combat_level: 75,
      character_level: 75,
      boss_type: 'aoe_boss',
      boss_level: 78,
      actual_boss_level: 78,
      level_gap: 3,
      difficulty: 'very_tough',
      standard_baseline: true,
      extreme_challenge: false,
      boss_preset: 'normal',
      level_sync: { valid: true, original_level: 75, expected_level: 75, effective_level: 75, restriction_active: false, warnings: [] },
      gear_profile: 'accessible_lv75',
      party_composition: 'solo',
      combat_started: true,
      prep_duration_sec: 8,
      encounter_duration_sec: 34,
      total_session_sec: 42,
      test_mode: 'synthetic_demo',
      outcome: 'victory',
      seed: 12345,
      valid_for_balance: true,
      warnings: [],
      metrics: {
        offense: {
          total_damage: cumDmg, player_damage: cumPDmg, sustained_dps: Number((cumDmg / 34).toFixed(2)),
          burst_dps_10s: Number(((cumDmg / 34) * 1.42).toFixed(2)),
          autoattack_damage: cumPDmg - 3270, weaponskill_damage: 3270, spell_damage: 0, pet_and_clone_damage: cumPet,
          melee_hits: 38, melee_misses: 4, hit_rate: 0.9048, crit_hits: 7, crit_rate: 0.1842,
          weaponskill_uses: 2, ability_uses: 3, spell_casts: 2, spell_interrupts: 0,
        },
        defense: {
          raw_incoming_damage: UNAVAILABLE, actual_incoming_damage: cumInc, mitigated_damage: UNAVAILABLE,
          block_rate: UNAVAILABLE, parry_rate: UNAVAILABLE, evasion_rate: UNAVAILABLE,
          incoming_swings_hit: 9, incoming_swings_missed: 6, max_damage_spike: 620, spike_hit_count: 1,
          deaths: 0, defensive_cd_uses: 1,
        },
        healing: {
          effective_healing: cumHeal, overhealing: UNAVAILABLE, healing_per_second: Number((cumHeal / 34).toFixed(2)),
          mp_consumed: 0, mp_recovered: 0, healing_downtime_sec: 10.0,
        },
        threat: {
          enmity_generation: 4230, max_ce: 2330, max_ve: 2460, threat_samples: 35, tank_aggro_uptime_pct: 100, threat_losses: 0,
        },
        resources_and_pets: {
          tp_generated: 4820, tp_spent: 4070, mp_efficiency: UNAVAILABLE, avg_active_buffs: 3.0,
          pet_survival: false, pet_uptime_pct: 100, pet_dps: Number((cumPet / 34).toFixed(2)), pet_deaths: 1,
          soul_specific_metrics: UNAVAILABLE,
        },
        boss: { abilities_used: 1, spells_cast: 0 },
        safety: { exp_events_observed: 0, exp_points_observed: 0, progression_clean: true },
      },
      metric_availability: {
        raw_incoming_damage: 'unavailable: TAKE_DAMAGE listener receives post-mitigation final damage only',
        mitigated_damage: 'unavailable: depends on raw_incoming_damage',
        block_parry_evade_split: 'unavailable: MELEE_SWING_MISS aggregates dodge/parry/shadow misses without per-reaction split',
        overhealing: 'unavailable: MAGIC_USE action param reports applied HP recovery without pre-cap amount',
        soul_specific_metrics: 'unavailable: per-Soul custom gauge hooks not yet instrumented in Lua telemetry',
      },
      logging_status: { ok: true, partial_recording: false, events_written: events.length, events_dropped: 0, snapshots_written: snapshots.length, snapshots_dropped: 0, errors: [] },
    };

    const ts = buildTimeSeriesClient(summary, snapshots, events);
    const markers = extractMarkersClient(events);
    const diagnostics = analyzeEncounterClient(summary, events, ts);
    return {
      read_only: true,
      is_demo: true,
      meta: { run_id: runId, schema_version: '2.0.0', timestamp_utc: summary.timestamp_utc, character_name: 'DemoTester (Synthetic)', pinned: false, events_count: events.length, snapshots_count: snapshots.length, has_events_file: true, has_snapshots_file: true, has_feedback_file: false },
      summary,
      time_series: ts,
      markers,
      pet_summary: {
        has_activity: true, pet_and_clone_damage: cumPet, damage_share_pct: Number(((cumPet / cumDmg) * 100).toFixed(2)),
        pet_dps: summary.metrics.resources_and_pets.pet_dps, pet_uptime_pct: 100, pet_survival: false, pet_deaths: 1,
        companions: [
          { key: 'clone:101', name: 'Shadow_Clone_1', kind: 'clone', spawns: 1, deaths: 0, despawns: 0, damage_dealt: Math.round(cumPet * 0.65), damage_taken: 310, max_hp: 950, samples: 35, alive_samples: 35 },
          { key: 'clone:102', name: 'Shadow_Clone_2', kind: 'clone', spawns: 1, deaths: 1, despawns: 0, damage_dealt: Math.round(cumPet * 0.35), damage_taken: 950, max_hp: 950, samples: 12, alive_samples: 12 },
        ],
      },
      diagnostics,
      feedback: { tag: 'felt_great', label: 'Felt Great', summary_text: 'Synthetic sample showing AoE spike, clone loss, 5s movement downtime, and TP cap window.', source: 'synthetic_demo', updated_at: summary.timestamp_utc },
      notes: [
        { id: 1, author_name: 'DemoTester', combat_sec: 11.6, phase: 'combat', body: 'Boss Grand Slam AoE knocked out Shadow Clone 2 and spiked player HP.', created_at: summary.timestamp_utc },
      ],
      events,
      raw_files: {
        summary: JSON.stringify(summary) + '\n',
        events: events.map((e) => JSON.stringify(e)).join('\n') + '\n',
        snapshots: snapshots.map((s) => JSON.stringify(s)).join('\n') + '\n',
      },
    };
  }

  function buildMarkdownClient(report) {
    const meta = report.meta || {};
    const s = report.summary || {};
    const m = s.metrics || {};
    const off = m.offense || {};
    const def = m.defense || {};
    const heal = m.healing || {};
    const lines = [
      `# SoulspireXI Combat Report — \`${meta.run_id}\``,
      '',
      `- **Date (UTC):** \`${s.timestamp_utc || ''}\``,
      `- **Character:** \`${meta.character_name || 'Not logged'}\``,
      `- **Soul / Job:** **${s.soul_name || 'None'}** (\`${s.job || 'UNKNOWN'}\`)`,
      `- **Encounter:** Effective Lv.${s.effective_combat_level ?? '?'} vs \`${s.boss_type || 'unknown'}\` Lv.${s.actual_boss_level ?? s.boss_level ?? '?'} (\`${s.difficulty || ''}\`)`,
      `- **Outcome:** \`${s.outcome || ''}\` | **Duration:** \`${s.encounter_duration_sec ?? '?'}s\``,
      '',
      '## Key Metrics',
      `- Total Damage: ${off.total_damage ?? 'Unavailable'} | Sustained DPS: ${off.sustained_dps ?? 'Unavailable'} | 10s Burst DPS: ${off.burst_dps_10s ?? 'Unavailable'}`,
      `- Actual Incoming Damage: ${def.actual_incoming_damage ?? 'Unavailable'} | Max Spike: ${def.max_damage_spike ?? 'Unavailable'} | Deaths: ${def.deaths ?? 0}`,
      `- Effective Healing: ${heal.effective_healing ?? 'Unavailable'} | HPS: ${heal.healing_per_second ?? 'Unavailable'}`,
      '',
      '## Deterministic Findings',
    ];
    const findings = report.diagnostics?.findings || [];
    if (!findings.length) lines.push('_No anomalies flagged._');
    else findings.forEach((f) => lines.push(`- **[${String(f.severity).toUpperCase()}]** ${isNum(f.combat_sec) ? `\`+${f.combat_sec}s\` ` : ''}**${f.title}** — ${f.detail}`));
    return lines.join('\n') + '\n';
  }

  function downloadBlob(filename, content, mime) {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  // =========================================================================
  // Application State & API Client
  // =========================================================================
  const DEFAULT_API_BASE =
    (typeof location !== 'undefined' && (location.hostname === 'wiki.soulspirexi.com' || location.hostname === 'soulspirexi.com'))
      ? 'https://api.soulspirexi.com/api/combat'
      : '/api/combat';

  const crState = {
    apiBase: (typeof localStorage !== 'undefined' && localStorage.getItem(API_BASE_KEY)) || DEFAULT_API_BASE,
    backendAvailable: null,
    authChecked: false,
    authenticated: false,
    user: null,
    csrfToken: null,
    providers: ['local'],
    feedbackOptions: FEEDBACK_OPTIONS_DEFAULT,
    retentionPerChar: 50,
    mode: 'backend', // 'backend' | 'local' | 'shared'
    shareToken: null,
    view: 'list', // 'list' | 'detail'
    filters: {
      soul: '',
      level: '',
      boss_type: '',
      difficulty: '',
      outcome: '',
      date_from: '',
      date_to: '',
      character: '',
      pinned: '',
      valid_only: false,
      q: '',
    },
    listData: null,
    localReports: [], // Loaded in browser via local JSONL file picker or demo
    activeReport: null,
    statusMessage: null,
    statusTone: 'info',
    showAdminPanel: false,
    adminData: null,
    showShareDrawer: false,
    lastCreatedShare: null,
    chartOpts: {
      dmgBars: true,
      roll5: true,
      roll10: true,
      incoming: true,
      healing: true,
      markers: true,
      showThreat: false,
    },
    timeline: {
      phase: '',
      category: '',
      q: '',
      secFrom: null,
      secTo: null,
      page: 0,
      pageSize: 100,
    },
    draftNoteSec: '',
  };

  function setStatus(msg, tone = 'info') {
    crState.statusMessage = msg;
    crState.statusTone = tone;
  }

  async function apiFetch(path, opts = {}) {
    const url = `${crState.apiBase}${path}`;
    const headers = { ...(opts.headers || {}) };
    if (opts.json !== undefined) {
      headers['Content-Type'] = 'application/json';
    }
    if (crState.csrfToken && opts.method && !['GET', 'HEAD', 'OPTIONS'].includes(opts.method.toUpperCase())) {
      headers['X-CSRF-Token'] = crState.csrfToken;
    }
    const res = await fetch(url, {
      method: opts.method || 'GET',
      credentials: 'include',
      headers,
      body: opts.json !== undefined ? JSON.stringify(opts.json) : opts.body,
      cache: 'no-store',
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch (_) {}
    if (!res.ok) {
      const err = new Error(data?.message || data?.error || `HTTP ${res.status}`);
      err.status = res.status;
      err.payload = data;
      throw err;
    }
    return data;
  }

  function updateReportsSidebarBadge() {
    const badge = document.getElementById('badgeReportsStatus');
    if (!badge) return;
    if (crState.mode === 'shared') badge.textContent = 'Shared';
    else if (crState.mode === 'local') badge.textContent = `Local (${crState.localReports.length})`;
    else if (crState.authenticated) badge.textContent = crState.listData ? String(crState.listData.total) : 'Live';
    else badge.textContent = 'Private';
  }

  async function checkAuth() {
    try {
      const data = await apiFetch('/auth/me');
      crState.backendAvailable = true;
      crState.authChecked = true;
      crState.authenticated = Boolean(data.authenticated);
      crState.user = data.user || null;
      crState.csrfToken = data.csrf_token || null;
      crState.providers = data.providers || ['local'];
      crState.feedbackOptions = data.feedback_options || FEEDBACK_OPTIONS_DEFAULT;
      crState.retentionPerChar = data.retention_per_character || 50;
    } catch (_) {
      crState.backendAvailable = false;
      crState.authChecked = true;
      crState.authenticated = false;
      crState.user = null;
      crState.csrfToken = null;
    }
    updateReportsSidebarBadge();
  }

  async function loadBackendRuns() {
    const params = new URLSearchParams();
    const f = crState.filters;
    if (f.soul) params.set('soul', f.soul);
    if (f.level) params.set('level', f.level);
    if (f.boss_type) params.set('boss_type', f.boss_type);
    if (f.difficulty) params.set('difficulty', f.difficulty);
    if (f.outcome) params.set('outcome', f.outcome);
    if (f.date_from) params.set('date_from', f.date_from);
    if (f.date_to) params.set('date_to', f.date_to);
    if (f.character) params.set('character', f.character);
    if (f.pinned) params.set('pinned', f.pinned);
    if (f.valid_only) params.set('valid_only', 'true');
    if (f.q) params.set('q', f.q);
    params.set('limit', '100');
    crState.listData = await apiFetch(`/reports?${params.toString()}`);
    updateReportsSidebarBadge();
  }

  async function openBackendReport(runId) {
    crState.activeReport = await apiFetch(`/reports/${encodeURIComponent(runId)}`);
    crState.view = 'detail';
    crState.timeline = { phase: '', category: '', q: '', secFrom: null, secTo: null, page: 0, pageSize: 100 };
    crState.lastCreatedShare = null;
    crState.showShareDrawer = false;
    if (typeof window !== 'undefined' && window.location) {
      window.history.replaceState(null, '', `#reports/${encodeURIComponent(runId)}`);
    }
  }

  async function openSharedToken(token) {
    crState.mode = 'shared';
    crState.shareToken = token;
    crState.statusMessage = null;
    try {
      crState.activeReport = await apiFetch(`/shared/${encodeURIComponent(token)}`);
      crState.view = 'detail';
      crState.timeline = { phase: '', category: '', q: '', secFrom: null, secTo: null, page: 0, pageSize: 100 };
    } catch (err) {
      crState.activeReport = null;
      crState.view = 'list';
      setStatus(`Share link error: ${err.message}`, 'danger');
    }
    updateReportsSidebarBadge();
  }

  async function handleLocalFiles(fileList) {
    const files = Array.from(fileList || []);
    if (!files.length) return;
    const runsSummaries = [];
    const eventsByRun = new Map();
    const snapsByRun = new Map();
    const fbByRun = new Map();
    const rawByRun = new Map();

    for (const file of files) {
      const text = await file.text();
      const name = file.name.toLowerCase();
      if (name.endsWith('.json')) {
        try {
          const obj = JSON.parse(text);
          if (obj && obj.run_id) {
            fbByRun.set(obj.run_id, { obj, raw: text });
          }
        } catch (_) {}
        continue;
      }
      const { items } = parseJsonlText(text);
      if (!items.length) continue;
      const first = items[0];
      if (first.metrics && first.run_id) {
        for (const rawLine of text.split(/\r?\n/)) {
          const line = rawLine.trim();
          if (!line) continue;
          try {
            const obj = JSON.parse(line);
            if (obj && obj.run_id && obj.metrics) {
              runsSummaries.push({ obj, rawLine: line });
            }
          } catch (_) {}
        }
      } else if (first.event_type && first.run_id) {
        eventsByRun.set(first.run_id, { items, raw: text });
      } else if (first.interval && first.run_id) {
        snapsByRun.set(first.run_id, { items, raw: text });
      }
    }

    const built = runsSummaries.map(({ obj, rawLine }) => {
      const rid = obj.run_id;
      const evRec = eventsByRun.get(rid) || { items: [], raw: null };
      const snRec = snapsByRun.get(rid) || { items: [], raw: null };
      const fbRec = fbByRun.get(rid) || null;
      const ts = buildTimeSeriesClient(obj, snRec.items, evRec.items);
      const markers = extractMarkersClient(evRec.items);
      const diagnostics = analyzeEncounterClient(obj, evRec.items, ts);
      const charName =
        obj.character_name ||
        (snRec.items[0]?.players && Array.isArray(snRec.items[0].players) && snRec.items[0].players[0]?.name) ||
        evRec.items.find((e) => e.event_type === 'session_start')?.source_name ||
        null;
      const petDmg = obj.metrics?.offense?.pet_and_clone_damage || 0;
      const totDmg = obj.metrics?.offense?.total_damage || 0;
      rawByRun.set(rid, { summary: rawLine + '\n', events: evRec.raw, snapshots: snRec.raw, feedback: fbRec?.raw || null });
      return {
        read_only: true,
        is_local: true,
        meta: {
          run_id: rid,
          schema_version: obj.telemetry_schema_version || obj.encounter_version || '1.0.0',
          timestamp_utc: obj.timestamp_utc || '',
          character_name: charName,
          pinned: false,
          events_count: evRec.items.length,
          snapshots_count: snRec.items.length,
          has_events_file: Boolean(evRec.raw),
          has_snapshots_file: Boolean(snRec.raw),
          has_feedback_file: Boolean(fbRec?.raw),
        },
        summary: obj,
        time_series: ts,
        markers,
        pet_summary: {
          has_activity: petDmg > 0 || (obj.metrics?.resources_and_pets?.pet_deaths || 0) > 0 || evRec.items.some((e) => e.category === 'pet'),
          pet_and_clone_damage: petDmg,
          damage_share_pct: totDmg > 0 ? Number(((petDmg / totDmg) * 100).toFixed(2)) : UNAVAILABLE,
          pet_dps: obj.metrics?.resources_and_pets?.pet_dps ?? UNAVAILABLE,
          pet_uptime_pct: obj.metrics?.resources_and_pets?.pet_uptime_pct ?? UNAVAILABLE,
          pet_survival: obj.metrics?.resources_and_pets?.pet_survival ?? UNAVAILABLE,
          pet_deaths: obj.metrics?.resources_and_pets?.pet_deaths ?? 0,
          companions: [],
        },
        diagnostics,
        feedback: fbRec ? { tag: fbRec.obj.tag || 'skip', label: fbRec.obj.label || fbRec.obj.tag, summary_text: fbRec.obj.note || '', source: fbRec.obj.source || 'npc_menu', updated_at: fbRec.obj.recorded_utc || '' } : null,
        notes: [],
        events: evRec.items,
        raw_files: rawByRun.get(rid),
      };
    });

    if (!built.length) {
      setStatus('No valid Proving Grounds summary JSONL records found in the selected file(s). Select runs.jsonl (and optional events/snapshots JSONL files).', 'warn');
      return;
    }

    crState.mode = 'local';
    crState.localReports = built.reverse();
    crState.view = built.length === 1 ? 'detail' : 'list';
    crState.activeReport = built.length === 1 ? built[0] : null;
    setStatus(`Loaded ${built.length} local encounter report(s) in browser read-only mode. Nothing was uploaded.`, 'ok');
    updateReportsSidebarBadge();
  }

  function getLocalFilteredList() {
    const f = crState.filters;
    const all = crState.localReports || [];
    const items = all.map((r) => {
      const s = r.summary;
      const m = s.metrics || {};
      return {
        run_id: r.meta.run_id,
        schema_version: r.meta.schema_version,
        timestamp_utc: s.timestamp_utc || '',
        character_name: r.meta.character_name,
        soul_key: s.soul_key || 'none',
        soul_name: s.soul_name || 'None',
        job: s.job || 'UNKNOWN',
        effective_combat_level: s.effective_combat_level ?? s.character_level ?? null,
        boss_type: s.boss_type || 'unknown',
        actual_boss_level: s.actual_boss_level ?? s.boss_level ?? null,
        difficulty: s.difficulty || 'even_match',
        outcome: s.outcome || 'completed',
        encounter_duration_sec: s.encounter_duration_sec ?? null,
        total_damage: m.offense?.total_damage ?? null,
        sustained_dps: m.offense?.sustained_dps ?? UNAVAILABLE,
        burst_dps_10s: m.offense?.burst_dps_10s ?? UNAVAILABLE,
        actual_incoming_damage: m.defense?.actual_incoming_damage ?? null,
        effective_healing: m.healing?.effective_healing ?? null,
        deaths: m.defense?.deaths ?? 0,
        pet_deaths: m.resources_and_pets?.pet_deaths ?? 0,
        events_count: r.meta.events_count,
        snapshots_count: r.meta.snapshots_count,
        pinned: false,
        feedback_label: r.feedback?.label || null,
        notes_count: (r.notes || []).length,
        active_shares: 0,
        valid_for_balance: s.valid_for_balance,
      };
    });

    const filtered = items.filter((it) => {
      if (f.soul && it.soul_key.toLowerCase() !== f.soul.toLowerCase() && it.soul_name.toLowerCase() !== f.soul.toLowerCase()) return false;
      if (f.level && String(it.effective_combat_level) !== String(f.level)) return false;
      if (f.boss_type && it.boss_type !== f.boss_type) return false;
      if (f.difficulty && it.difficulty !== f.difficulty) return false;
      if (f.outcome && it.outcome !== f.outcome) return false;
      if (f.date_from && it.timestamp_utc < f.date_from) return false;
      if (f.date_to && it.timestamp_utc > `${f.date_to}T23:59:59Z`) return false;
      if (f.valid_only && it.valid_for_balance !== true) return false;
      if (f.q) {
        const hay = `${it.run_id} ${it.soul_name} ${it.boss_type} ${it.character_name || ''}`.toLowerCase();
        if (!hay.includes(f.q.toLowerCase())) return false;
      }
      return true;
    });

    const uniq = (arr) => Array.from(new Set(arr.filter((v) => v !== null && v !== undefined && v !== ''))).sort();
    const soulMap = new Map();
    items.forEach((i) => soulMap.set(i.soul_key, i.soul_name));
    return {
      total: filtered.length,
      pinned_total: 0,
      items: filtered,
      facets: {
        souls: Array.from(soulMap.entries()).map(([key, name]) => ({ key, name })),
        levels: uniq(items.map((i) => i.effective_combat_level)).sort((a, b) => a - b),
        boss_types: uniq(items.map((i) => i.boss_type)),
        difficulties: uniq(items.map((i) => i.difficulty)),
        outcomes: uniq(items.map((i) => i.outcome)),
        characters: uniq(items.map((i) => i.character_name)),
      },
    };
  }

  // =========================================================================
  // Interactive HTML5 Canvas Chart Renderer (High-DPI + Hover + Click + PNG)
  // =========================================================================
  const MARKER_COLORS = {
    weaponskill: '#fbbf24',
    defensive_cd: '#38bdf8',
    boss_ability: '#c084fc',
    boss_threshold: '#94a3b8',
    damage_spike: '#f43f5e',
    death: '#ef4444',
    clone_loss: '#f97316',
    pet_spawn: '#2dd4bf',
    threat_loss: '#eab308',
    note: '#10b981',
  };

  function setupHiDPICanvas(canvas) {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.max(320, Math.floor(rect.width || 720));
    const h = Math.max(200, Math.floor(rect.height || 280));
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { ctx, w, h };
  }

  function drawDamageChart(canvas, report, hoverIdx = -1) {
    const pts = report.time_series?.points || [];
    if (!canvas || !pts.length) return null;
    const { ctx, w, h } = setupHiDPICanvas(canvas);
    const pad = { l: 54, r: 22, t: 28, b: 32 };
    const pw = w - pad.l - pad.r;
    const ph = h - pad.t - pad.b;

    ctx.fillStyle = '#0b1222';
    ctx.fillRect(0, 0, w, h);

    const opts = crState.chartOpts;
    let maxVal = 10;
    for (const p of pts) {
      if (opts.dmgBars) maxVal = Math.max(maxVal, p.damage_dealt || 0);
      if (opts.roll5) maxVal = Math.max(maxVal, p.rolling_dps_5s || 0);
      if (opts.roll10) maxVal = Math.max(maxVal, p.rolling_dps_10s || 0);
      if (opts.incoming) maxVal = Math.max(maxVal, p.damage_received || 0);
      if (opts.healing) maxVal = Math.max(maxVal, p.healing_done || 0);
    }
    maxVal = Math.ceil(maxVal * 1.12);

    const maxSec = Math.max(1, pts[pts.length - 1].sec);
    const xOfSec = (sec) => pad.l + (sec / maxSec) * pw;
    const yOfVal = (v) => pad.t + ph - (Math.max(0, v) / maxVal) * ph;

    // Grid & Y labels
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.14)';
    ctx.lineWidth = 1;
    ctx.font = '11px JetBrains Mono, monospace';
    ctx.fillStyle = '#94a3b8';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
      const v = (maxVal * i) / 4;
      const y = yOfVal(v);
      ctx.beginPath();
      ctx.moveTo(pad.l, y);
      ctx.lineTo(w - pad.r, y);
      ctx.stroke();
      ctx.fillText(Math.round(v).toLocaleString(), pad.l - 6, y + 4);
    }

    // X ticks
    ctx.textAlign = 'center';
    const xStep = Math.max(1, Math.ceil(maxSec / 8));
    for (let s = 0; s <= maxSec; s += xStep) {
      const x = xOfSec(s);
      ctx.fillText(`+${s}s`, x, h - 10);
    }

    const barW = Math.max(2, Math.min(14, (pw / Math.max(1, pts.length)) * 0.72));

    // 1-second stacked damage bars (Player + Pet/Clone)
    if (opts.dmgBars) {
      for (const p of pts) {
        const x = xOfSec(p.sec) - barW / 2;
        const pH = ((p.player_damage || 0) / maxVal) * ph;
        const petH = ((p.pet_clone_damage || 0) / maxVal) * ph;
        if (pH > 0) {
          ctx.fillStyle = 'rgba(56, 189, 248, 0.42)';
          ctx.fillRect(x, pad.t + ph - pH, barW, pH);
        }
        if (petH > 0) {
          ctx.fillStyle = 'rgba(168, 85, 247, 0.62)';
          ctx.fillRect(x, pad.t + ph - pH - petH, barW, petH);
        }
      }
    }

    const drawLine = (key, color, width, dash = []) => {
      ctx.save();
      ctx.strokeStyle = color;
      ctx.lineWidth = width;
      ctx.setLineDash(dash);
      ctx.beginPath();
      pts.forEach((p, idx) => {
        const x = xOfSec(p.sec);
        const y = yOfVal(p[key] || 0);
        if (idx === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      });
      ctx.stroke();
      ctx.restore();
    };

    if (opts.incoming) drawLine('damage_received', '#f43f5e', 1.8);
    if (opts.healing) drawLine('healing_done', '#10b981', 1.8);
    if (opts.roll5) drawLine('rolling_dps_5s', '#38bdf8', 2.2);
    if (opts.roll10) drawLine('rolling_dps_10s', '#fbbf24', 2.2, [5, 3]);

    // Event & Note Markers along top rail
    if (opts.markers) {
      const allMarkers = [
        ...(report.markers || []),
        ...(report.notes || []).filter((n) => isNum(n.combat_sec)).map((n) => ({ sec: n.combat_sec, kind: 'note', label: `Note: ${n.body.slice(0, 32)}` })),
      ];
      for (const mk of allMarkers) {
        if (mk.sec < 0 || mk.sec > maxSec) continue;
        const x = xOfSec(mk.sec);
        const col = MARKER_COLORS[mk.kind] || '#cbd5e1';
        ctx.strokeStyle = `${col}55`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x, pad.t);
        ctx.lineTo(x, pad.t + ph);
        ctx.stroke();

        ctx.fillStyle = col;
        ctx.beginPath();
        ctx.arc(x, pad.t + 6, mk.kind === 'death' || mk.kind === 'damage_spike' ? 4.5 : 3.2, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Hover crosshair
    if (hoverIdx >= 0 && hoverIdx < pts.length) {
      const hp = pts[hoverIdx];
      const x = xOfSec(hp.sec);
      ctx.strokeStyle = 'rgba(255,255,255,0.45)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, pad.t);
      ctx.lineTo(x, pad.t + ph);
      ctx.stroke();
    }

    // Legend strip
    ctx.textAlign = 'left';
    ctx.font = '10px Inter, sans-serif';
    ctx.fillStyle = '#cbd5e1';
    ctx.fillText('Click any second to jump timeline & pre-fill note timestamp', pad.l, 14);

    return { pad, pw, ph, maxSec, pts };
  }

  function drawVitalsChart(canvas, report, hoverIdx = -1) {
    const pts = report.time_series?.points || [];
    if (!canvas || !pts.length || !report.time_series?.has_vitals) return null;
    const { ctx, w, h } = setupHiDPICanvas(canvas);
    const pad = { l: 54, r: 22, t: 28, b: 32 };
    const pw = w - pad.l - pad.r;
    const ph = h - pad.t - pad.b;

    ctx.fillStyle = '#0b1222';
    ctx.fillRect(0, 0, w, h);

    const maxSec = Math.max(1, pts[pts.length - 1].sec);
    const xOfSec = (sec) => pad.l + (sec / maxSec) * pw;
    const yOfPct = (pct) => pad.t + ph - (Math.max(0, Math.min(100, pct)) / 100) * ph;

    // 0-100% grid + Boss thresholds (75, 50, 25)
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.14)';
    ctx.lineWidth = 1;
    ctx.font = '11px JetBrains Mono, monospace';
    ctx.fillStyle = '#94a3b8';
    ctx.textAlign = 'right';
    for (const pct of [0, 25, 50, 75, 100]) {
      const y = yOfPct(pct);
      ctx.beginPath();
      ctx.moveTo(pad.l, y);
      ctx.lineTo(w - pad.r, y);
      ctx.stroke();
      ctx.fillText(`${pct}%`, pad.l - 6, y + 4);
    }

    ctx.textAlign = 'center';
    const xStep = Math.max(1, Math.ceil(maxSec / 8));
    for (let s = 0; s <= maxSec; s += xStep) {
      ctx.fillText(`+${s}s`, xOfSec(s), h - 10);
    }

    const drawPctLine = (getter, color, width, dash = []) => {
      ctx.save();
      ctx.strokeStyle = color;
      ctx.lineWidth = width;
      ctx.setLineDash(dash);
      ctx.beginPath();
      let started = false;
      for (const p of pts) {
        const val = getter(p);
        if (!isNum(val)) continue;
        const x = xOfSec(p.sec);
        const y = yOfPct(val);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
      ctx.restore();
    };

    drawPctLine((p) => p.player_hp_pct, '#10b981', 2.4);
    if (report.time_series.has_mp) {
      drawPctLine((p) => p.player_mp_pct, '#3b82f6', 2.0);
    }
    drawPctLine((p) => (isNum(p.player_tp) ? (p.player_tp / 3000) * 100 : null), '#fbbf24', 1.9, [4, 3]);
    drawPctLine((p) => p.boss_hp_pct, '#f43f5e', 2.0);

    if (crState.chartOpts.showThreat) {
      const maxEnm = Math.max(1, ...pts.map((p) => (p.boss_ce || 0) + (p.boss_ve || 0)));
      drawPctLine((p) => (isNum(p.boss_ce) ? (((p.boss_ce || 0) + (p.boss_ve || 0)) / maxEnm) * 100 : null), '#c084fc', 1.6, [2, 2]);
    }

    if (hoverIdx >= 0 && hoverIdx < pts.length) {
      const x = xOfSec(pts[hoverIdx].sec);
      ctx.strokeStyle = 'rgba(255,255,255,0.45)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, pad.t);
      ctx.lineTo(x, pad.t + ph);
      ctx.stroke();
    }

    ctx.textAlign = 'left';
    ctx.font = '10px Inter, sans-serif';
    ctx.fillStyle = '#cbd5e1';
    ctx.fillText('Green: Player HP%  •  Gold Dashed: TP (0–3000)  •  Rose: Boss HP%' + (report.time_series.has_mp ? '  •  Blue: MP%' : ''), pad.l, 14);

    return { pad, pw, ph, maxSec, pts };
  }

  function bindInteractiveChart(canvasId, tooltipId, drawFn, report, onClickSec) {
    const canvas = document.getElementById(canvasId);
    const tip = document.getElementById(tooltipId);
    if (!canvas) return;
    let geom = drawFn(canvas, report, -1);
    if (!geom) return;

    const findIdx = (clientX) => {
      const rect = canvas.getBoundingClientRect();
      const x = clientX - rect.left;
      const frac = Math.max(0, Math.min(1, (x - geom.pad.l) / Math.max(1, geom.pw)));
      const targetSec = Math.round(frac * geom.maxSec);
      const idx = geom.pts.findIndex((p) => p.sec >= targetSec);
      return idx >= 0 ? idx : geom.pts.length - 1;
    };

    canvas.onmousemove = (e) => {
      const idx = findIdx(e.clientX);
      geom = drawFn(canvas, report, idx) || geom;
      if (!tip || idx < 0) return;
      const p = geom.pts[idx];
      const nearMarkers = (report.markers || []).filter((m) => Math.abs(m.sec - p.sec) <= 1.0).slice(0, 4);
      tip.innerHTML = `
        <div class="cr-mono" style="font-weight:700; color:#fff; margin-bottom:4px;">Combat +${p.sec}s</div>
        <div>DMG: <strong style="color:#38bdf8">${p.damage_dealt}</strong> (5s: ${p.rolling_dps_5s} / 10s: ${p.rolling_dps_10s})</div>
        <div>Incoming: <strong style="color:#fb7185">${p.damage_received}</strong> | Heal: <strong style="color:#34d399">${p.healing_done}</strong></div>
        ${isNum(p.player_hp) ? `<div>HP: ${p.player_hp}/${p.player_max_hp} (${p.player_hp_pct}%) | TP: ${p.player_tp}</div>` : ''}
        ${isNum(p.player_max_mp) && p.player_max_mp > 0 ? `<div>MP: ${p.player_mp}/${p.player_max_mp} (${p.player_mp_pct}%)</div>` : ''}
        ${isNum(p.boss_hp_pct) ? `<div>Boss HP: ${p.boss_hp_pct}%${isNum(p.boss_ce) ? ` | CE:${p.boss_ce} VE:${p.boss_ve}` : ''}</div>` : ''}
        ${nearMarkers.length ? `<div style="margin-top:4px; border-top:1px solid rgba(148,163,184,0.2); padding-top:4px; color:#fde68a;">${nearMarkers.map((m) => `• ${escapeHtml(m.label)}`).join('<br/>')}</div>` : ''}
      `;
      const rect = canvas.getBoundingClientRect();
      const left = Math.min(rect.width - 210, Math.max(8, e.clientX - rect.left + 14));
      tip.style.left = `${left}px`;
      tip.style.top = '10px';
      tip.classList.remove('hidden');
    };

    canvas.onmouseleave = () => {
      drawFn(canvas, report, -1);
      if (tip) tip.classList.add('hidden');
    };

    canvas.onclick = (e) => {
      const idx = findIdx(e.clientX);
      if (idx >= 0 && onClickSec) onClickSec(geom.pts[idx].sec);
    };
  }

  // =========================================================================
  // UI Rendering
  // =========================================================================
  function outcomePill(outcome) {
    const o = String(outcome || 'unknown').toLowerCase();
    const cls = o === 'victory' ? 'cr-pill-victory' : o === 'defeat' ? 'cr-pill-defeat' : 'cr-pill-reset';
    return `<span class="cr-pill ${cls}">${escapeHtml(outcome || 'unknown')}</span>`;
  }

  function renderStatusBanner() {
    if (!crState.statusMessage) return '';
    const cls = crState.statusTone === 'danger' ? 'cr-notice-danger' : crState.statusTone === 'warn' ? 'cr-notice-warn' : crState.statusTone === 'ok' ? 'cr-notice-ok' : '';
    return `<div class="cr-notice ${cls}">${escapeHtml(crState.statusMessage)}</div>`;
  }

  function renderAuthGate() {
    const hasDiscord = crState.providers.includes('discord');
    const hasGithub = crState.providers.includes('github');
    const hasLocalAuth = crState.providers.includes('local');

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">📊 Soul Proving Grounds Telemetry &bull; Private by Default</div>
        <h1>Combat Reports &amp; Encounter Analytics</h1>
        <p>
          Inspect server-authoritative Proving Grounds encounter reports with 1-second DPS graphs, rolling averages,
          HP/MP/TP vitals, pet &amp; Shinobi clone tracking, chronological event timelines, and deterministic rule diagnostics—zero AI tokens required.
        </p>
      </section>

      ${renderStatusBanner()}

      <div class="cr-auth-grid">
        <div class="cr-auth-card">
          <h3>🔐 Sign In to Private Reports</h3>
          ${
            crState.backendAvailable === false
              ? `<div class="cr-notice cr-notice-warn">
                  Backend API at <code>${escapeHtml(crState.apiBase)}</code> is not reachable from this static host.
                  You can configure a backend URL below, or use the <strong>Local JSONL Viewer</strong> on the right.
                </div>`
              : `<div class="cr-notice">
                  Reports are private by default. Sign in with your dedicated Combat Analytics account or OAuth provider.
                  <strong>Do not use your FFXI game password.</strong>
                </div>`
          }

          ${
            hasLocalAuth && crState.backendAvailable !== false
              ? `
              <form id="crLoginForm">
                <div class="cr-form-row">
                  <label for="crLoginUser">Analytics Username</label>
                  <input id="crLoginUser" class="cr-input" type="text" autocomplete="username" required />
                </div>
                <div class="cr-form-row">
                  <label for="crLoginPass">Analytics Password</label>
                  <input id="crLoginPass" class="cr-input" type="password" autocomplete="current-password" required />
                </div>
                <button type="submit" class="btn-primary" style="width:100%;">Sign In</button>
              </form>
            `
              : ''
          }

          ${
            (hasDiscord || hasGithub) && crState.backendAvailable !== false
              ? (() => {
                  const basePath =
                    typeof window !== 'undefined' && window.location && window.location.pathname
                      ? window.location.pathname
                      : '/';
                  const returnTo = encodeURIComponent(`${basePath}#reports`);
                  return `
              <div class="cr-oauth-row">
                ${hasDiscord ? `<a class="btn-secondary" href="${escapeHtml(crState.apiBase)}/auth/oauth/discord/start?return_to=${returnTo}">Sign in with Discord</a>` : ''}
                ${hasGithub ? `<a class="btn-secondary" href="${escapeHtml(crState.apiBase)}/auth/oauth/github/start?return_to=${returnTo}">Sign in with GitHub</a>` : ''}
              </div>
            `;
                })()
              : ''
          }

          <details style="margin-top:0.9rem; font-size:0.8rem; color:var(--text-muted);">
            <summary style="cursor:pointer;">Backend API Endpoint Settings</summary>
            <div class="cr-form-row" style="margin-top:0.5rem;">
              <label for="crApiBaseInput">API Base URL (default: <code>/api/combat</code>)</label>
              <div style="display:flex; gap:0.45rem;">
                <input id="crApiBaseInput" class="cr-input" style="flex:1;" value="${escapeHtml(crState.apiBase)}" />
                <button type="button" class="btn-secondary cr-btn-sm" id="crSaveApiBaseBtn">Reconnect</button>
              </div>
            </div>
          </details>
        </div>

        <div class="cr-auth-card">
          <h3>📂 Local Read-Only JSONL Viewer</h3>
          <p style="font-size:0.86rem; color:var(--text-secondary); margin-top:0.25rem;">
            Inspect Proving Grounds logs directly in your browser without uploading anything to a server.
            Select <code>runs.jsonl</code> (or <code>proving_grounds_runs.jsonl</code>) together with optional
            <code>events/&lt;run_id&gt;.jsonl</code>, <code>snapshots/&lt;run_id&gt;.jsonl</code>, and <code>feedback/&lt;run_id&gt;.json</code> files.
          </p>
          <div class="cr-dropzone" id="crLocalDropzone">
            <div style="font-size:0.88rem; color:var(--text-primary); margin-bottom:0.5rem;">Drop Proving Grounds JSONL files here</div>
            <input type="file" id="crLocalFileInput" multiple accept=".jsonl,.json" style="display:none;" />
            <button type="button" class="btn-primary cr-btn-sm" id="crPickFilesBtn">Choose JSONL Files...</button>
          </div>
          <div style="margin-top:0.95rem; padding-top:0.85rem; border-top:1px solid var(--border-subtle); display:flex; align-items:center; justify-content:space-between; gap:0.6rem; flex-wrap:wrap;">
            <span style="font-size:0.8rem; color:var(--text-muted);">Want to preview the charts &amp; rules first?</span>
            <button type="button" class="btn-secondary cr-btn-sm" id="crLoadDemoBtn">Load Synthetic Demo Report</button>
          </div>
        </div>
      </div>
    `;
  }

  function renderTopToolbar() {
    const isBackend = crState.mode === 'backend' && crState.authenticated;
    const isShared = crState.mode === 'shared';
    const isLocal = crState.mode === 'local';

    return `
      <div class="cr-toolbar">
        <div class="cr-toolbar-group">
          ${
            isBackend
              ? `<span class="cr-user-pill">
                  <span>👤 ${escapeHtml(crState.user.display_name)}</span>
                  <span class="cr-user-role">${escapeHtml(crState.user.role)}</span>
                </span>
                <span style="font-size:0.78rem; color:var(--text-muted);">Retention: ${crState.retentionPerChar} recent/char + pinned</span>`
              : isShared
              ? `<span class="cr-pill cr-pill-purple">🔗 Shared Read-Only Report</span>`
              : `<span class="cr-pill cr-pill-cyan">📂 Local Browser Mode (Read-Only)</span>`
          }
        </div>
        <div class="cr-toolbar-group">
          ${
            isBackend && crState.user?.role === 'admin'
              ? `<button class="btn-secondary cr-btn-sm" id="crAdminImportBtn">↻ Import Local Logs</button>
                 <button class="btn-secondary cr-btn-sm" id="crToggleAdminBtn">${crState.showAdminPanel ? 'Hide Admin' : 'Admin & Retention'}</button>`
              : ''
          }
          ${
            isLocal || isShared
              ? `<button class="btn-secondary cr-btn-sm" id="crBackToAuthBtn">Sign In / Backend Mode</button>`
              : ''
          }
          ${
            isLocal
              ? `<input type="file" id="crLocalFileInputInline" multiple accept=".jsonl,.json" style="display:none;" />
                 <button class="btn-secondary cr-btn-sm" id="crPickFilesInlineBtn">+ Open JSONL</button>`
              : ''
          }
          ${
            isBackend
              ? `<button class="btn-secondary cr-btn-sm" id="crLogoutBtn">Sign Out</button>`
              : ''
          }
        </div>
      </div>
    `;
  }

  function renderAdminPanel() {
    if (!crState.showAdminPanel || !crState.authenticated || crState.user?.role !== 'admin') return '';
    const ret = crState.adminData?.retention;
    const users = crState.adminData?.users || [];
    return `
      <div class="cr-panel" style="margin-bottom:1rem; border-color:var(--border-gold);">
        <h3>🛡️ Admin Controls — Retention &amp; Accounts</h3>
        <div class="cr-split-2" style="margin-bottom:0;">
          <div>
            <div style="font-size:0.84rem; color:var(--text-secondary); margin-bottom:0.5rem;">
              Default policy: keep <strong>${ret?.max_unpinned_per_character ?? crState.retentionPerChar}</strong> newest unpinned reports per character, plus all pinned reports.
              ${ret ? `(Currently ${ret.total_runs} total: ${ret.unpinned_runs} unpinned, ${ret.pinned_runs} pinned)` : ''}
            </div>
            <button class="btn-secondary cr-btn-sm" id="crAdminPruneBtn">Run Retention Prune Now</button>
            ${
              ret?.by_character?.length
                ? `<div class="wiki-table-wrap" style="margin-top:0.65rem;">
                    <table class="cr-timeline-table">
                      <thead><tr><th>Character</th><th>Unpinned</th><th>Pinned</th></tr></thead>
                      <tbody>${ret.by_character.map((c) => `<tr><td>${escapeHtml(c.character_name)}</td><td>${c.unpinned_count}</td><td>${c.pinned_count}</td></tr>`).join('')}</tbody>
                    </table>
                  </div>`
                : ''
            }
          </div>
          <div>
            <div style="font-size:0.84rem; font-weight:600; margin-bottom:0.45rem;">Analytics Accounts (${users.length})</div>
            <div style="max-height:170px; overflow-y:auto;">
              ${users.map((u) => `
                <div class="cr-share-row">
                  <div>
                    <strong>${escapeHtml(u.username)}</strong> <span class="cr-user-role">${escapeHtml(u.role)}</span>
                    <div style="font-size:0.74rem; color:var(--text-muted);">Provider: ${escapeHtml(u.auth_provider)} • Linked chars: ${escapeHtml((u.character_names || []).join(', ') || 'All (admin) / None')}</div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        </div>
      </div>
    `;
  }

  function renderRunsList() {
    const data = crState.mode === 'local' ? getLocalFilteredList() : crState.listData;
    const facets = data?.facets || { souls: [], levels: [], boss_types: [], difficulties: [], outcomes: [], characters: [] };
    const items = data?.items || [];
    const f = crState.filters;

    return `
      <section class="wiki-hero" style="padding:1.35rem 1.6rem;">
        <div class="hero-eyebrow">📊 Proving Grounds Telemetry &bull; Deterministic Analytics</div>
        <h1 style="font-size:1.75rem;">Combat Reports</h1>
        <p style="margin-bottom:0;">
          Filter encounters by Soul, level, boss type, difficulty, outcome, and date. Pin key reference fights to keep them past the ${crState.retentionPerChar}-report per-character retention window.
        </p>
      </section>

      ${renderTopToolbar()}
      ${renderStatusBanner()}
      ${renderAdminPanel()}

      <div class="cr-filter-bar">
        <div class="cr-filter-field">
          <label>Soul</label>
          <select class="cr-select" data-cr-filter="soul">
            <option value="">All Souls</option>
            ${facets.souls.map((s) => `<option value="${escapeHtml(s.key)}" ${f.soul === s.key ? 'selected' : ''}>${escapeHtml(s.name)}</option>`).join('')}
          </select>
        </div>
        <div class="cr-filter-field">
          <label>Effective Level</label>
          <select class="cr-select" data-cr-filter="level">
            <option value="">All Levels</option>
            ${facets.levels.map((lv) => `<option value="${lv}" ${String(f.level) === String(lv) ? 'selected' : ''}>Lv. ${lv}</option>`).join('')}
          </select>
        </div>
        <div class="cr-filter-field">
          <label>Boss Type</label>
          <select class="cr-select" data-cr-filter="boss_type">
            <option value="">All Bosses</option>
            ${facets.boss_types.map((b) => `<option value="${escapeHtml(b)}" ${f.boss_type === b ? 'selected' : ''}>${escapeHtml(b)}</option>`).join('')}
          </select>
        </div>
        <div class="cr-filter-field">
          <label>Difficulty</label>
          <select class="cr-select" data-cr-filter="difficulty">
            <option value="">All Difficulties</option>
            ${facets.difficulties.map((d) => `<option value="${escapeHtml(d)}" ${f.difficulty === d ? 'selected' : ''}>${escapeHtml(d)}</option>`).join('')}
          </select>
        </div>
        <div class="cr-filter-field">
          <label>Outcome</label>
          <select class="cr-select" data-cr-filter="outcome">
            <option value="">All Outcomes</option>
            ${facets.outcomes.map((o) => `<option value="${escapeHtml(o)}" ${f.outcome === o ? 'selected' : ''}>${escapeHtml(o)}</option>`).join('')}
          </select>
        </div>
        <div class="cr-filter-field">
          <label>Date From</label>
          <input type="date" class="cr-input" data-cr-filter="date_from" value="${escapeHtml(f.date_from)}" />
        </div>
        <div class="cr-filter-field">
          <label>Date To</label>
          <input type="date" class="cr-input" data-cr-filter="date_to" value="${escapeHtml(f.date_to)}" />
        </div>
        <div class="cr-filter-field">
          <label>Search</label>
          <input type="search" class="cr-input" placeholder="Run ID, character, note..." data-cr-filter="q" value="${escapeHtml(f.q)}" />
        </div>
        <label class="cr-check-row">
          <input type="checkbox" id="crFilterPinned" ${f.pinned === 'true' ? 'checked' : ''} /> Pinned only
        </label>
        <label class="cr-check-row">
          <input type="checkbox" id="crFilterValid" ${f.valid_only ? 'checked' : ''} /> Balance valid only
        </label>
      </div>

      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem; margin-bottom:0.7rem;">
        <div style="font-size:0.84rem; color:var(--text-muted);">
          Showing <strong>${items.length}</strong> of <strong>${data?.total ?? 0}</strong> encounter(s) (${data?.pinned_total ?? 0} pinned)
        </div>
        <div style="display:flex; gap:0.5rem;">
          <button class="btn-secondary cr-btn-sm" id="crResetFiltersBtn">Reset Filters</button>
          ${crState.mode === 'backend' ? `<button class="btn-secondary cr-btn-sm" id="crExportListCsvBtn">⬇ Export List CSV</button>` : ''}
        </div>
      </div>

      <div class="wiki-card" style="padding:0; overflow-x:auto;">
        ${
          items.length === 0
            ? `<div style="padding:1.8rem; text-align:center; color:var(--text-muted);">
                No encounter reports match the current filters.
              </div>`
            : `<table class="cr-runs-table">
                <thead>
                  <tr>
                    <th style="width:36px;">Pin</th>
                    <th>Date (UTC)</th>
                    <th>Character</th>
                    <th>Soul / Job / Lv</th>
                    <th>Boss / Diff</th>
                    <th>Outcome</th>
                    <th>Dur</th>
                    <th>DPS (10s)</th>
                    <th>Incoming</th>
                    <th>Healing</th>
                    <th>Feel / Notes</th>
                  </tr>
                </thead>
                <tbody>
                  ${items.map((r) => `
                    <tr data-open-run="${escapeHtml(r.run_id)}">
                      <td>
                        ${
                          crState.mode === 'backend'
                            ? `<button class="cr-pin-btn ${r.pinned ? 'pinned' : ''}" data-pin-run="${escapeHtml(r.run_id)}" data-pin-val="${r.pinned ? '0' : '1'}" title="${r.pinned ? 'Unpin report' : 'Pin report (exempt from retention)'}">${r.pinned ? '★' : '☆'}</button>`
                            : '—'
                        }
                      </td>
                      <td class="cr-mono" style="font-size:0.76rem; white-space:nowrap;">${escapeHtml((r.timestamp_utc || '').replace('T', ' ').replace('Z', ''))}</td>
                      <td>${escapeHtml(r.character_name || 'Not logged')}</td>
                      <td>
                        <strong>${escapeHtml(r.soul_name)}</strong>
                        <span class="cr-mono" style="color:var(--text-muted); font-size:0.76rem;">${escapeHtml(r.job)} Lv.${r.effective_combat_level ?? '?'}</span>
                      </td>
                      <td>
                        ${escapeHtml(r.boss_type)} <span class="cr-mono" style="font-size:0.76rem; color:var(--text-muted);">Lv.${r.actual_boss_level ?? '?'}</span>
                        <div><span class="cr-pill ${r.extreme_challenge ? 'cr-pill-warn' : 'cr-pill-cyan'}" style="font-size:0.66rem;">${escapeHtml(r.difficulty)}</span></div>
                      </td>
                      <td>${outcomePill(r.outcome)}</td>
                      <td class="cr-mono">${isNum(r.encounter_duration_sec) ? `${r.encounter_duration_sec}s` : '—'}</td>
                      <td class="cr-mono">
                        <strong>${isNum(r.sustained_dps) ? r.sustained_dps.toFixed(1) : 'Unavail'}</strong>
                        <span style="color:var(--text-muted); font-size:0.74rem;">(${isNum(r.burst_dps_10s) ? r.burst_dps_10s.toFixed(1) : '—'})</span>
                      </td>
                      <td class="cr-mono">${isNum(r.actual_incoming_damage) ? r.actual_incoming_damage.toLocaleString() : '—'}${r.deaths > 0 ? ` <span style="color:#fb7185;">💀${r.deaths}</span>` : ''}</td>
                      <td class="cr-mono">${isNum(r.effective_healing) ? r.effective_healing.toLocaleString() : '—'}</td>
                      <td style="font-size:0.76rem;">
                        ${r.feedback_label ? `<span class="cr-pill cr-pill-purple">${escapeHtml(r.feedback_label)}</span>` : '<span style="color:var(--text-muted);">—</span>'}
                        ${r.notes_count > 0 ? `<span style="margin-left:4px; color:var(--accent-cyan);">📝${r.notes_count}</span>` : ''}
                        ${r.active_shares > 0 ? `<span style="margin-left:4px; color:var(--accent-gold);">🔗${r.active_shares}</span>` : ''}
                      </td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>`
        }
      </div>
    `;
  }

  function renderReportDetail() {
    const r = crState.activeReport;
    if (!r) return '';
    const meta = r.meta || {};
    const s = r.summary || {};
    const m = s.metrics || {};
    const off = m.offense || {};
    const def = m.defense || {};
    const heal = m.healing || {};
    const thr = m.threat || {};
    const res = m.resources_and_pets || {};
    const avail = s.metric_availability || {};
    const diag = r.diagnostics || { counts: { critical: 0, warning: 0, info: 0 }, findings: [] };
    const ts = r.time_series || { source: 'unavailable', points: [] };
    const petSum = r.pet_summary || { has_activity: false, companions: [] };
    const canEdit = !r.read_only && crState.mode === 'backend' && crState.authenticated;

    const autoDmg = isNum(off.autoattack_damage) ? off.autoattack_damage : 0;
    const wsDmg = isNum(off.weaponskill_damage) ? off.weaponskill_damage : 0;
    const spellDmg = isNum(off.spell_damage) ? off.spell_damage : 0;
    const petDmg = isNum(off.pet_and_clone_damage) ? off.pet_and_clone_damage : 0;
    const totDmg = Math.max(1, autoDmg + wsDmg + spellDmg + petDmg);

    const dlPrefix = crState.mode === 'shared'
      ? `${crState.apiBase}/shared/${encodeURIComponent(crState.shareToken)}/download`
      : `${crState.apiBase}/reports/${encodeURIComponent(meta.run_id)}/download`;

    // Timeline filtering
    const tf = crState.timeline;
    const filteredEvents = (r.events || []).filter((ev) => {
      if (tf.phase && ev.phase !== tf.phase) return false;
      if (tf.category && ev.category !== tf.category) return false;
      if (tf.secFrom !== null || tf.secTo !== null) {
        if (!isNum(ev.combat_ms)) return false;
        const sec = ev.combat_ms / 1000;
        if (tf.secFrom !== null && sec < tf.secFrom) return false;
        if (tf.secTo !== null && sec > tf.secTo) return false;
      }
      if (tf.q && !JSON.stringify(ev).toLowerCase().includes(tf.q.toLowerCase())) return false;
      return true;
    });
    const totalPages = Math.max(1, Math.ceil(filteredEvents.length / tf.pageSize));
    const page = Math.min(tf.page, totalPages - 1);
    const pageEvents = filteredEvents.slice(page * tf.pageSize, (page + 1) * tf.pageSize);

    const fb = r.feedback || { tag: 'skip', label: 'Skip / Neutral', summary_text: '' };

    return `
      ${renderTopToolbar()}
      ${renderStatusBanner()}

      <div class="cr-detail-header">
        <div class="cr-detail-top">
          <div>
            <div style="display:flex; align-items:center; gap:0.5rem; flex-wrap:wrap;">
              ${crState.mode !== 'shared' ? `<button class="btn-secondary cr-btn-sm" id="crBackToListBtn">&larr; All Reports</button>` : ''}
              ${outcomePill(s.outcome)}
              <span class="cr-pill cr-pill-cyan">Schema v${escapeHtml(meta.schema_version || '1.0.0')}</span>
              ${s.extreme_challenge ? `<span class="cr-pill cr-pill-warn">Extreme Challenge (Non-Baseline)</span>` : ''}
              ${s.valid_for_balance === false ? `<span class="cr-pill cr-pill-defeat">Excluded from Balance</span>` : ''}
              ${r.is_demo ? `<span class="cr-pill cr-pill-purple">Synthetic Demo Fixture</span>` : ''}
              ${r.share ? `<span class="cr-pill cr-pill-purple">Shared Link${r.share.expires_at ? ` • Expires ${escapeHtml(r.share.expires_at)}` : ''}</span>` : ''}
            </div>
            <h1 class="cr-detail-title">
              ${escapeHtml(s.soul_name || 'None')} (${escapeHtml(s.job || 'UNKNOWN')}) vs ${escapeHtml(s.boss_type || 'unknown')} Lv.${escapeHtml(s.actual_boss_level ?? s.boss_level ?? '?')}
            </h1>
            <div class="cr-mono" style="font-size:0.78rem; color:var(--text-muted);">${escapeHtml(meta.run_id)}</div>
          </div>

          <div style="display:flex; flex-wrap:wrap; gap:0.45rem; align-items:center;">
            ${
              canEdit
                ? `<button class="btn-secondary cr-btn-sm" id="crDetailPinBtn">${meta.pinned ? '★ Pinned' : '☆ Pin Report'}</button>
                   <button class="btn-primary cr-btn-sm" id="crToggleShareBtn">🔗 Share Link (${(r.shares || []).filter((sh) => sh.active).length})</button>`
                : ''
            }
            <button class="btn-secondary cr-btn-sm" id="crExportMdBtn">⬇ Markdown Summary</button>
            <button class="btn-secondary cr-btn-sm" id="crExportCsvBtn">⬇ Timeline CSV</button>
            ${
              crState.mode !== 'local'
                ? `<a class="btn-secondary cr-btn-sm" href="${dlPrefix}?file=bundle">⬇ Original JSONL (.zip)</a>
                   <a class="btn-secondary cr-btn-sm" href="${dlPrefix}?file=summary">⬇ Summary .jsonl</a>`
                : `<button class="btn-secondary cr-btn-sm" id="crLocalDownloadJsonlBtn">⬇ Summary .jsonl</button>`
            }
          </div>
        </div>

        <div class="cr-meta-strip">
          <span><strong>Date:</strong> <span class="cr-mono">${escapeHtml(s.timestamp_utc || 'N/A')}</span></span>
          <span><strong>Character:</strong> ${escapeHtml(meta.character_name || 'Not logged')}</span>
          <span><strong>Level:</strong> Effective Lv.${escapeHtml(s.effective_combat_level ?? '?')} (Orig Lv.${escapeHtml(s.original_character_level ?? '?')})</span>
          <span><strong>Difficulty:</strong> ${escapeHtml(s.difficulty || 'even_match')} (gap ${s.level_gap ?? 0})</span>
          <span><strong>Combat:</strong> ${escapeHtml(s.encounter_duration_sec ?? '?')}s (Prep: ${escapeHtml(s.prep_duration_sec ?? 0)}s)</span>
          <span><strong>Gear:</strong> ${escapeHtml(s.gear_profile || 'unknown')}</span>
          <span><strong>Mode:</strong> ${escapeHtml(s.test_mode || 'manual')}</span>
        </div>
      </div>

      ${
        canEdit && crState.showShareDrawer
          ? `<div class="cr-panel" style="margin-bottom:1.1rem; border-color:var(--border-accent);">
              <h3>🔗 Private Share Links (Read-Only, Revocable, Optionally Expiring)</h3>
              <form id="crCreateShareForm" style="display:flex; flex-wrap:wrap; gap:0.55rem; align-items:flex-end;">
                <div class="cr-filter-field" style="flex:1; min-width:180px;">
                  <label>Label (optional)</label>
                  <input id="crShareLabel" class="cr-input" placeholder="e.g. Balance review with dev team" />
                </div>
                <div class="cr-filter-field" style="width:160px;">
                  <label>Expiration</label>
                  <select id="crShareExpiry" class="cr-select">
                    <option value="24">24 Hours</option>
                    <option value="168" selected>7 Days</option>
                    <option value="720">30 Days</option>
                    <option value="">Never expires</option>
                  </select>
                </div>
                <button type="submit" class="btn-primary cr-btn-sm">Generate Share Link</button>
              </form>
              ${
                crState.lastCreatedShare
                  ? `<div class="cr-notice cr-notice-ok" style="margin-top:0.75rem;">
                      <strong>New Share Link (copy now — raw token is not shown again):</strong>
                      <div style="display:flex; gap:0.5rem; margin-top:0.35rem; align-items:center;">
                        <input class="cr-input cr-mono" style="flex:1;" readonly value="${escapeHtml(crState.lastCreatedShare.share_url)}" id="crNewShareUrlInput" />
                        <button type="button" class="btn-primary cr-btn-sm" id="crCopyShareUrlBtn">Copy URL</button>
                      </div>
                    </div>`
                  : ''
              }
              <div style="margin-top:0.75rem;">
                ${(r.shares || []).length === 0
                  ? `<div style="font-size:0.82rem; color:var(--text-muted);">No share links created. This report is strictly private.</div>`
                  : (r.shares || []).map((sh) => `
                    <div class="cr-share-row">
                      <div>
                        <code class="cr-mono">${escapeHtml(sh.token_prefix)}…</code>
                        <strong>${escapeHtml(sh.label || 'Untitled share')}</strong>
                        <span class="cr-pill ${sh.active ? 'cr-pill-victory' : 'cr-pill-reset'}">${sh.revoked_at ? 'Revoked' : sh.expired ? 'Expired' : 'Active'}</span>
                        <div style="font-size:0.74rem; color:var(--text-muted);">
                          Views: ${sh.access_count} • Created: ${escapeHtml(sh.created_at)}${sh.expires_at ? ` • Expires: ${escapeHtml(sh.expires_at)}` : ' • No expiration'}
                        </div>
                      </div>
                      ${sh.active ? `<button class="cr-btn-danger" data-revoke-share="${sh.id}">Revoke</button>` : ''}
                    </div>
                  `).join('')}
              </div>
            </div>`
          : ''
      }

      <!-- Deterministic Findings -->
      <div class="cr-findings-panel">
        <div class="cr-findings-header">
          <h3>🔎 Deterministic Rule Diagnostics (Zero AI Tokens)</h3>
          <div style="display:flex; gap:0.4rem; flex-wrap:wrap;">
            <span class="cr-pill cr-pill-defeat">${diag.counts.critical} Critical</span>
            <span class="cr-pill cr-pill-warn">${diag.counts.warning} Warning</span>
            <span class="cr-pill cr-pill-cyan">${diag.counts.info} Info</span>
          </div>
        </div>
        ${
          diag.findings.length === 0
            ? `<div style="font-size:0.85rem; color:#34d399;">✓ No damage spikes, deaths, clone losses, downtime gaps, or resource issues flagged.</div>`
            : `<div class="cr-finding-list">
                ${diag.findings.map((f) => `
                  <div class="cr-finding-item sev-${escapeHtml(f.severity)}">
                    <div class="cr-finding-top">
                      <span class="cr-finding-title">[${escapeHtml(f.severity.toUpperCase())}] ${escapeHtml(f.title)}</span>
                      ${isNum(f.combat_sec) ? `<button class="cr-jump-btn" data-jump-sec="${f.combat_sec}">Jump to +${f.combat_sec}s</button>` : ''}
                    </div>
                    <div class="cr-finding-detail">${escapeHtml(f.detail)}</div>
                    ${
                      f.evidence?.recap_5s?.length
                        ? `<details style="margin-top:0.35rem; font-size:0.78rem;">
                            <summary style="cursor:pointer; color:var(--accent-gold);">View 5-Second Death Recap (${f.evidence.recap_5s.length} events)</summary>
                            <div class="cr-mono" style="margin-top:0.3rem; padding:0.45rem; background:rgba(0,0,0,0.35); border-radius:4px;">
                              ${f.evidence.recap_5s.map((ev) => `+${ev.combat_sec}s • ${escapeHtml(ev.event_type)} • ${escapeHtml(ev.source || '')} • ${escapeHtml(ev.value)}`).join('<br/>')}
                            </div>
                          </details>`
                        : ''
                    }
                  </div>
                `).join('')}
              </div>`
        }
      </div>

      <!-- KPI Metric Grid -->
      <div class="cr-kpi-grid">
        <div class="cr-kpi-card">
          <h4><span>⚔️ Offense</span><span class="cr-mono">${formatMetric(off.sustained_dps, avail, 'sustained_dps', ' DPS')}</span></h4>
          <div class="cr-kv-list">
            <div class="cr-kv-row"><span>Total / Player Damage</span><strong>${formatMetric(off.total_damage)} / ${formatMetric(off.player_damage ?? off.total_damage)}</strong></div>
            <div class="cr-kv-row"><span>10s Peak Burst DPS</span><strong>${formatMetric(off.burst_dps_10s, avail, 'burst_dps_10s')}</strong></div>
            <div class="cr-kv-row"><span>Hit Rate / Crit Rate</span><strong>${formatPctFromRatio(off.hit_rate, avail, 'hit_rate')} / ${formatPctFromRatio(off.crit_rate, avail, 'crit_rate')}</strong></div>
            <div class="cr-kv-row"><span>WS / JA / Spells / Int</span><strong>${off.weaponskill_uses ?? 0} / ${off.ability_uses ?? 0} / ${off.spell_casts ?? 0} / ${off.spell_interrupts ?? 0}</strong></div>
          </div>
          <div class="cr-dmg-bar" title="Auto / WS / Spell / Pet &amp; Clone share">
            <div style="width:${(autoDmg / totDmg) * 100}%; background:#38bdf8;"></div>
            <div style="width:${(wsDmg / totDmg) * 100}%; background:#fbbf24;"></div>
            <div style="width:${(spellDmg / totDmg) * 100}%; background:#10b981;"></div>
            <div style="width:${(petDmg / totDmg) * 100}%; background:#a855f7;"></div>
          </div>
          <div class="cr-dmg-bar-legend">
            <span><span class="cr-legend-dot" style="background:#38bdf8;"></span>Auto ${autoDmg.toLocaleString()}</span>
            <span><span class="cr-legend-dot" style="background:#fbbf24;"></span>WS ${wsDmg.toLocaleString()}</span>
            <span><span class="cr-legend-dot" style="background:#10b981;"></span>Spell ${spellDmg.toLocaleString()}</span>
            <span><span class="cr-legend-dot" style="background:#a855f7;"></span>Pet/Clone ${petDmg.toLocaleString()}</span>
          </div>
        </div>

        <div class="cr-kpi-card">
          <h4><span>🛡️ Defense &amp; Incoming</span><span>${def.deaths ? `💀 ${def.deaths}` : 'Alive'}</span></h4>
          <div class="cr-kv-list">
            <div class="cr-kv-row"><span>Actual Incoming DMG</span><strong>${formatMetric(def.actual_incoming_damage)}</strong></div>
            <div class="cr-kv-row"><span>Max Spike / Spike Hits</span><strong>${formatMetric(def.max_damage_spike)} / ${def.spike_hit_count ?? 0}</strong></div>
            <div class="cr-kv-row"><span>Swings Hit / Missed</span><strong>${def.incoming_swings_hit ?? 0} / ${def.incoming_swings_missed ?? 0}</strong></div>
            <div class="cr-kv-row"><span>Defensive CDs Used</span><strong>${def.defensive_cd_uses ?? 0}</strong></div>
            <div class="cr-kv-row"><span>Raw / Mitigated DMG</span><strong>${formatMetric(def.raw_incoming_damage, avail, 'raw_incoming_damage')} / ${formatMetric(def.mitigated_damage, avail, 'mitigated_damage')}</strong></div>
            <div class="cr-kv-row"><span>Block / Parry / Evade</span><strong>${formatMetric(def.block_rate, avail, 'block_parry_evade_split')}</strong></div>
          </div>
        </div>

        <div class="cr-kpi-card">
          <h4><span>💚 Healing &amp; Threat</span><span>${formatMetric(heal.healing_per_second, avail, 'healing_per_second', ' HPS')}</span></h4>
          <div class="cr-kv-list">
            <div class="cr-kv-row"><span>Effective Healing</span><strong>${formatMetric(heal.effective_healing)}</strong></div>
            <div class="cr-kv-row"><span>Overhealing</span><strong>${formatMetric(heal.overhealing, avail, 'overhealing')}</strong></div>
            <div class="cr-kv-row"><span>Max Healing Gap</span><strong>${formatMetric(heal.healing_downtime_sec, avail, 'healing_downtime_sec', 's')}</strong></div>
            <div class="cr-kv-row"><span>MP Consumed / Recov</span><strong>${heal.mp_consumed ?? 0} / ${heal.mp_recovered ?? 0}</strong></div>
            <div class="cr-kv-row"><span>Max Enmity (CE / VE)</span><strong>${formatMetric(thr.enmity_generation)} (${thr.max_ce ?? 0}/${thr.max_ve ?? 0})</strong></div>
            <div class="cr-kv-row"><span>Aggro Uptime / Losses</span><strong>${formatMetric(thr.tank_aggro_uptime_pct, avail, 'tank_aggro_uptime_pct', '%')} / ${thr.threat_losses ?? 0}</strong></div>
          </div>
        </div>

        <div class="cr-kpi-card">
          <h4><span>⚡ Resources &amp; Pets/Clones</span><span>${petSum.has_activity ? 'Active' : 'None'}</span></h4>
          <div class="cr-kv-list">
            <div class="cr-kv-row"><span>TP Generated / Spent</span><strong>${formatMetric(res.tp_generated)} / ${formatMetric(res.tp_spent)}</strong></div>
            <div class="cr-kv-row"><span>MP Efficiency</span><strong>${formatMetric(res.mp_efficiency, avail, 'mp_efficiency')}</strong></div>
            <div class="cr-kv-row"><span>Avg Active Buffs</span><strong>${formatMetric(res.avg_active_buffs)}</strong></div>
            <div class="cr-kv-row"><span>Pet/Clone DPS (Share)</span><strong>${formatMetric(petSum.pet_dps)} (${formatMetric(petSum.damage_share_pct, null, null, '%')})</strong></div>
            <div class="cr-kv-row"><span>Pet Uptime / Deaths</span><strong>${formatMetric(petSum.pet_uptime_pct, avail, 'pet_uptime_pct', '%')} / ${petSum.pet_deaths ?? 0}</strong></div>
            <div class="cr-kv-row"><span>Soul Gauge Metrics</span><strong>${formatMetric(res.soul_specific_metrics, avail, 'soul_specific_metrics')}</strong></div>
          </div>
        </div>
      </div>

      <!-- Chart 1: 1-Second Damage, Rolling Averages & Event Markers -->
      <div class="cr-chart-card">
        <div class="cr-chart-header">
          <h3>📈 1-Second Damage, Incoming, Healing &amp; Rolling Averages</h3>
          <div class="cr-chart-toggles">
            <button class="cr-toggle-chip ${crState.chartOpts.dmgBars ? 'active' : ''}" data-chart-toggle="dmgBars">1s DMG Bars</button>
            <button class="cr-toggle-chip ${crState.chartOpts.roll5 ? 'active' : ''}" data-chart-toggle="roll5">5s Avg</button>
            <button class="cr-toggle-chip ${crState.chartOpts.roll10 ? 'active' : ''}" data-chart-toggle="roll10">10s Avg</button>
            <button class="cr-toggle-chip ${crState.chartOpts.incoming ? 'active' : ''}" data-chart-toggle="incoming">Incoming</button>
            <button class="cr-toggle-chip ${crState.chartOpts.healing ? 'active' : ''}" data-chart-toggle="healing">Healing</button>
            <button class="cr-toggle-chip ${crState.chartOpts.markers ? 'active' : ''}" data-chart-toggle="markers">Markers (${(r.markers || []).length})</button>
            ${ts.points.length ? `<button class="btn-secondary cr-btn-sm" data-export-png="crDmgCanvas">📷 PNG</button>` : ''}
          </div>
        </div>
        ${
          ts.points.length === 0
            ? `<div class="cr-notice">1-second timeline is unavailable for this encounter (summary-only v1.0.0 log or combat never started).</div>`
            : `<div class="cr-canvas-wrap">
                <canvas id="crDmgCanvas"></canvas>
                <div id="crDmgTooltip" class="cr-chart-tooltip hidden"></div>
              </div>`
        }
      </div>

      <!-- Chart 2: HP / MP / TP & Boss HP% -->
      <div class="cr-chart-card">
        <div class="cr-chart-header">
          <h3>❤️ Player HP / MP / TP &amp; Boss HP%</h3>
          <div class="cr-chart-toggles">
            <button class="cr-toggle-chip ${crState.chartOpts.showThreat ? 'active' : ''}" data-chart-toggle="showThreat">Enmity Overlay</button>
            ${ts.has_vitals ? `<button class="btn-secondary cr-btn-sm" data-export-png="crVitalsCanvas">📷 PNG</button>` : ''}
          </div>
        </div>
        ${
          !ts.has_vitals
            ? `<div class="cr-notice">Per-second HP/MP/TP snapshots are unavailable for this run (requires v2.0.0 <code>snapshots/&lt;run_id&gt;.jsonl</code>).</div>`
            : `<div class="cr-canvas-wrap">
                <canvas id="crVitalsCanvas"></canvas>
                <div id="crVitalsTooltip" class="cr-chart-tooltip hidden"></div>
              </div>`
        }
      </div>

      <!-- Pet & Clone Performance Table (when active) -->
      ${
        petSum.has_activity
          ? `<div class="cr-panel" style="margin-bottom:1.15rem;">
              <h3>🦊 Pet &amp; Shinobi Clone Performance</h3>
              ${
                petSum.companions && petSum.companions.length
                  ? `<div class="wiki-table-wrap">
                      <table class="cr-timeline-table">
                        <thead><tr><th>Companion</th><th>Kind</th><th>Spawns</th><th>Deaths</th><th>Damage Dealt</th><th>Damage Taken</th><th>Max HP</th></tr></thead>
                        <tbody>
                          ${petSum.companions.map((c) => `
                            <tr>
                              <td><strong>${escapeHtml(c.name)}</strong></td>
                              <td><span class="cr-pill cr-pill-purple">${escapeHtml(c.kind)}</span></td>
                              <td class="cr-mono">${c.spawns}</td>
                              <td class="cr-mono" style="color:${c.deaths > 0 ? '#fb7185' : 'inherit'};">${c.deaths}</td>
                              <td class="cr-mono">${(c.damage_dealt || 0).toLocaleString()}</td>
                              <td class="cr-mono">${(c.damage_taken || 0).toLocaleString()}</td>
                              <td class="cr-mono">${c.max_hp ?? '—'}</td>
                            </tr>
                          `).join('')}
                        </tbody>
                      </table>
                    </div>`
                  : `<div style="font-size:0.84rem; color:var(--text-secondary);">Total Pet/Clone Damage: <strong>${formatMetric(petSum.pet_and_clone_damage)}</strong> • Pet Deaths: <strong>${petSum.pet_deaths ?? 0}</strong> • Uptime: <strong>${formatMetric(petSum.pet_uptime_pct, avail, 'pet_uptime_pct', '%')}</strong></div>`
              }
            </div>`
          : ''
      }

      <!-- Fight Feel Feedback & Timestamped Notes -->
      <div class="cr-split-2">
        <div class="cr-panel">
          <h3>💬 How Did This Fight Feel?</h3>
          <div class="cr-feedback-chips" id="crFeedbackChips">
            ${crState.feedbackOptions.map((opt) => `
              <button type="button" class="cr-fb-chip ${fb.tag === opt.key ? 'active' : ''}" data-fb-tag="${escapeHtml(opt.key)}" ${!canEdit ? 'disabled' : ''}>
                ${escapeHtml(opt.label)}
              </button>
            `).join('')}
          </div>
          <div class="cr-form-row">
            <label for="crFeedbackText">Feel Summary / Balance Notes</label>
            <textarea id="crFeedbackText" class="cr-textarea" placeholder="Describe pacing, survivability, rotation feel, or boss tuning..." ${!canEdit ? 'readonly' : ''}>${escapeHtml(fb.summary_text || '')}</textarea>
          </div>
          ${canEdit ? `<button class="btn-primary cr-btn-sm" id="crSaveFeedbackBtn">Save Feedback</button>` : `<span style="font-size:0.76rem; color:var(--text-muted);">Source: ${escapeHtml(fb.source || 'read-only')}</span>`}
        </div>

        <div class="cr-panel">
          <h3>📝 Timestamped Notes (${(r.notes || []).length})</h3>
          <div style="max-height:220px; overflow-y:auto; margin-bottom:0.7rem;">
            ${
              (r.notes || []).length === 0
                ? `<div style="font-size:0.82rem; color:var(--text-muted);">No notes yet. Click any second on the chart or timeline to add a timestamped note.</div>`
                : (r.notes || []).map((n) => `
                  <div class="cr-note-item">
                    <div style="flex:1;">
                      <div class="cr-note-meta">
                        ${isNum(n.combat_sec) ? `<button class="cr-jump-btn" data-jump-sec="${n.combat_sec}">+${n.combat_sec}s</button>` : `<span class="cr-pill cr-pill-reset">General</span>`}
                        <strong>${escapeHtml(n.author_name || 'User')}</strong>
                      </div>
                      <div class="cr-note-body">${escapeHtml(n.body)}</div>
                    </div>
                    ${canEdit ? `<button class="cr-btn-danger" data-del-note="${n.id}" title="Delete note">&times;</button>` : ''}
                  </div>
                `).join('')
            }
          </div>
          ${
            canEdit
              ? `<form id="crAddNoteForm" style="display:flex; flex-direction:column; gap:0.5rem;">
                  <div style="display:flex; gap:0.5rem;">
                    <input id="crNoteSecInput" class="cr-input cr-mono" style="width:120px;" type="number" step="0.1" min="0" placeholder="Sec (opt)" value="${escapeHtml(crState.draftNoteSec)}" />
                    <input id="crNoteBodyInput" class="cr-input" style="flex:1;" placeholder="Add a timestamped observation..." required />
                    <button type="submit" class="btn-primary cr-btn-sm">Add</button>
                  </div>
                </form>`
              : ''
          }
        </div>
      </div>

      <!-- Chronological Combat Event Timeline -->
      <div class="cr-panel" id="crTimelineSection">
        <div class="cr-chart-header">
          <h3>📜 Chronological Combat Event Timeline (${filteredEvents.length.toLocaleString()} events)</h3>
          ${tf.secFrom !== null ? `<button class="btn-secondary cr-btn-sm" id="crClearTimeWindowBtn">Showing +${tf.secFrom}s to +${tf.secTo}s &times;</button>` : ''}
        </div>
        <div class="cr-timeline-controls">
          <select class="cr-select" id="crTlPhase">
            <option value="">All Phases</option>
            <option value="preparation" ${tf.phase === 'preparation' ? 'selected' : ''}>preparation</option>
            <option value="combat" ${tf.phase === 'combat' ? 'selected' : ''}>combat</option>
            <option value="post" ${tf.phase === 'post' ? 'selected' : ''}>post</option>
          </select>
          <select class="cr-select" id="crTlCategory">
            <option value="">All Categories</option>
            ${['offense', 'defense', 'boss', 'pet', 'resource', 'lifecycle'].map((c) => `<option value="${c}" ${tf.category === c ? 'selected' : ''}>${c}</option>`).join('')}
          </select>
          <input type="search" class="cr-input" id="crTlSearch" style="min-width:220px; flex:1;" placeholder="Filter event type, source, skill..." value="${escapeHtml(tf.q)}" />
        </div>

        ${
          filteredEvents.length === 0
            ? `<div style="font-size:0.84rem; color:var(--text-muted); padding:0.8rem 0;">No chronological events recorded or matched for this filter.</div>`
            : `<div class="wiki-table-wrap">
                <table class="cr-timeline-table">
                  <thead>
                    <tr>
                      <th>Time</th>
                      <th>Phase</th>
                      <th>Category</th>
                      <th>Event</th>
                      <th>Source &rarr; Target</th>
                      <th>Value</th>
                      <th>Details</th>
                      ${canEdit ? '<th></th>' : ''}
                    </tr>
                  </thead>
                  <tbody>
                    ${pageEvents.map((ev) => {
                      const danger = ['death', 'damage_spike', 'clone_death', 'pet_death'].includes(ev.event_type);
                      const detailStr = ev.meta ? Object.entries(ev.meta).map(([k, v]) => `${k}=${v}`).join(', ') : '';
                      const secVal = isNum(ev.combat_ms) ? (ev.combat_ms / 1000).toFixed(1) : '';
                      return `
                        <tr class="${danger ? 'ev-danger' : ''}">
                          <td class="cr-mono" style="white-space:nowrap;">${formatCombatMs(ev.combat_ms, ev.phase)}</td>
                          <td><span class="cr-mono" style="font-size:0.72rem; color:var(--text-muted);">${escapeHtml(ev.phase || '')}</span></td>
                          <td><span class="cr-pill cr-pill-cyan" style="font-size:0.66rem;">${escapeHtml(ev.category || '')}</span></td>
                          <td class="cr-mono">${escapeHtml(ev.event_type || '')}</td>
                          <td>${escapeHtml(ev.source_name || '—')}${ev.target_name ? ` &rarr; ${escapeHtml(ev.target_name)}` : ''}</td>
                          <td class="cr-mono"><strong>${escapeHtml(ev.value ?? '')}</strong></td>
                          <td class="cr-mono" style="font-size:0.72rem; color:var(--text-muted);">${escapeHtml(detailStr)}</td>
                          ${canEdit && secVal ? `<td><button class="cr-jump-btn" data-prefill-note-sec="${secVal}" title="Add note at +${secVal}s">+Note</button></td>` : canEdit ? '<td></td>' : ''}
                        </tr>
                      `;
                    }).join('')}
                  </tbody>
                </table>
              </div>
              <div class="cr-pagination">
                <span>Page ${page + 1} of ${totalPages}</span>
                <div style="display:flex; gap:0.45rem;">
                  <button class="btn-secondary cr-btn-sm" id="crTlPrevBtn" ${page <= 0 ? 'disabled' : ''}>&larr; Prev</button>
                  <button class="btn-secondary cr-btn-sm" id="crTlNextBtn" ${page >= totalPages - 1 ? 'disabled' : ''}>Next &rarr;</button>
                </div>
              </div>`
        }
      </div>
    `;
  }

  // =========================================================================
  // Render Coordinator & Event Binding
  // =========================================================================
  let currentContainer = null;

  async function rerender() {
    if (!currentContainer) return;
    renderInto(currentContainer);
  }

  function renderInto(container) {
    currentContainer = container;
    if (crState.mode === 'shared') {
      container.innerHTML = crState.activeReport ? renderReportDetail() : renderAuthGate();
    } else if (crState.mode === 'local') {
      container.innerHTML = crState.view === 'detail' && crState.activeReport ? renderReportDetail() : renderRunsList();
    } else if (!crState.authenticated) {
      container.innerHTML = renderAuthGate();
    } else if (crState.view === 'detail' && crState.activeReport) {
      container.innerHTML = renderReportDetail();
    } else {
      container.innerHTML = renderRunsList();
    }
    bindEvents(container);
  }

  function jumpToSecond(sec) {
    crState.timeline.secFrom = Math.max(0, Math.floor(sec) - 2);
    crState.timeline.secTo = Math.ceil(sec) + 2;
    crState.timeline.page = 0;
    crState.draftNoteSec = String(Number(sec).toFixed(1));
    rerender();
    const el = document.getElementById('crTimelineSection');
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function bindEvents(container) {
    // Login form
    const loginForm = container.querySelector('#crLoginForm');
    if (loginForm) {
      loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = container.querySelector('#crLoginUser').value.trim();
        const password = container.querySelector('#crLoginPass').value;
        try {
          const data = await apiFetch('/auth/login', { method: 'POST', json: { username, password } });
          crState.authenticated = true;
          crState.user = data.user;
          crState.csrfToken = data.csrf_token;
          crState.mode = 'backend';
          crState.statusMessage = null;
          await loadBackendRuns();
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    }

    const saveApiBtn = container.querySelector('#crSaveApiBaseBtn');
    if (saveApiBtn) {
      saveApiBtn.addEventListener('click', async () => {
        const val = container.querySelector('#crApiBaseInput').value.trim().replace(/\/+$/, '') || '/api/combat';
        crState.apiBase = val;
        try { localStorage.setItem(API_BASE_KEY, val); } catch (_) {}
        await checkAuth();
        if (crState.authenticated) await loadBackendRuns();
        rerender();
      });
    }

    // Local file picker & dropzone
    const bindPicker = (btnSel, inputSel) => {
      const btn = container.querySelector(btnSel);
      const inp = container.querySelector(inputSel);
      if (btn && inp) {
        btn.addEventListener('click', () => inp.click());
        inp.addEventListener('change', async () => {
          await handleLocalFiles(inp.files);
          rerender();
        });
      }
    };
    bindPicker('#crPickFilesBtn', '#crLocalFileInput');
    bindPicker('#crPickFilesInlineBtn', '#crLocalFileInputInline');

    const dz = container.querySelector('#crLocalDropzone');
    if (dz) {
      dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('dragover'); });
      dz.addEventListener('dragleave', () => dz.classList.remove('dragover'));
      dz.addEventListener('drop', async (e) => {
        e.preventDefault();
        dz.classList.remove('dragover');
        await handleLocalFiles(e.dataTransfer?.files);
        rerender();
      });
    }

    const demoBtn = container.querySelector('#crLoadDemoBtn');
    if (demoBtn) {
      demoBtn.addEventListener('click', () => {
        const demo = createSyntheticDemoReport();
        crState.mode = 'local';
        crState.localReports = [demo];
        crState.activeReport = demo;
        crState.view = 'detail';
        setStatus('Loaded synthetic demo encounter (fictional DemoTester data — no real player logs).', 'info');
        updateReportsSidebarBadge();
        rerender();
      });
    }

    const backToAuthBtn = container.querySelector('#crBackToAuthBtn');
    if (backToAuthBtn) {
      backToAuthBtn.addEventListener('click', async () => {
        crState.mode = 'backend';
        crState.shareToken = null;
        crState.activeReport = null;
        crState.view = 'list';
        crState.statusMessage = null;
        await checkAuth();
        if (crState.authenticated) await loadBackendRuns();
        rerender();
      });
    }

    const logoutBtn = container.querySelector('#crLogoutBtn');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', async () => {
        try { await apiFetch('/auth/logout', { method: 'POST' }); } catch (_) {}
        crState.authenticated = false;
        crState.user = null;
        crState.csrfToken = null;
        crState.listData = null;
        crState.activeReport = null;
        crState.view = 'list';
        setStatus('Signed out.', 'info');
        updateReportsSidebarBadge();
        rerender();
      });
    }

    // Admin actions
    const adminImportBtn = container.querySelector('#crAdminImportBtn');
    if (adminImportBtn) {
      adminImportBtn.addEventListener('click', async () => {
        try {
          const res = await apiFetch('/admin/import', { method: 'POST' });
          setStatus(`Imported ${res.imported} run(s), ${res.skipped_unchanged} unchanged, pruned ${res.retention?.deleted_count || 0} old unpinned run(s).`, 'ok');
          await loadBackendRuns();
          rerender();
        } catch (err) {
          setStatus(`Import failed: ${err.message}`, 'danger');
          rerender();
        }
      });
    }

    const toggleAdminBtn = container.querySelector('#crToggleAdminBtn');
    if (toggleAdminBtn) {
      toggleAdminBtn.addEventListener('click', async () => {
        crState.showAdminPanel = !crState.showAdminPanel;
        if (crState.showAdminPanel) {
          try {
            const [retention, usersRes] = await Promise.all([apiFetch('/admin/retention'), apiFetch('/admin/users')]);
            crState.adminData = { retention, users: usersRes.users || [] };
          } catch (err) {
            setStatus(err.message, 'danger');
          }
        }
        rerender();
      });
    }

    const pruneBtn = container.querySelector('#crAdminPruneBtn');
    if (pruneBtn) {
      pruneBtn.addEventListener('click', async () => {
        try {
          const res = await apiFetch('/admin/retention/prune', { method: 'POST' });
          setStatus(`Retention prune complete: removed ${res.deleted_count} old unpinned run(s).`, 'ok');
          await loadBackendRuns();
          const retention = await apiFetch('/admin/retention');
          crState.adminData = { ...(crState.adminData || {}), retention };
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    }

    // List filters
    const applyFilter = async () => {
      if (crState.mode === 'backend' && crState.authenticated) {
        try { await loadBackendRuns(); } catch (err) { setStatus(err.message, 'danger'); }
      }
      rerender();
    };
    container.querySelectorAll('[data-cr-filter]').forEach((el) => {
      const key = el.getAttribute('data-cr-filter');
      const evName = el.tagName === 'SELECT' || el.type === 'date' ? 'change' : 'keydown';
      el.addEventListener(evName, (e) => {
        if (evName === 'keydown' && e.key !== 'Enter') return;
        crState.filters[key] = el.value;
        applyFilter();
      });
      if (el.type === 'search') {
        el.addEventListener('change', () => { crState.filters[key] = el.value; applyFilter(); });
      }
    });
    const fp = container.querySelector('#crFilterPinned');
    if (fp) fp.addEventListener('change', () => { crState.filters.pinned = fp.checked ? 'true' : ''; applyFilter(); });
    const fv = container.querySelector('#crFilterValid');
    if (fv) fv.addEventListener('change', () => { crState.filters.valid_only = fv.checked; applyFilter(); });

    const resetBtn = container.querySelector('#crResetFiltersBtn');
    if (resetBtn) {
      resetBtn.addEventListener('click', () => {
        crState.filters = { soul: '', level: '', boss_type: '', difficulty: '', outcome: '', date_from: '', date_to: '', character: '', pinned: '', valid_only: false, q: '' };
        applyFilter();
      });
    }

    const exportListCsv = container.querySelector('#crExportListCsvBtn');
    if (exportListCsv) {
      exportListCsv.addEventListener('click', () => {
        const params = new URLSearchParams();
        Object.entries(crState.filters).forEach(([k, v]) => { if (v) params.set(k, String(v)); });
        params.set('format', 'csv');
        window.location.href = `${crState.apiBase}/reports?${params.toString()}`;
      });
    }

    // Pin buttons in table
    container.querySelectorAll('[data-pin-run]').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const rid = btn.getAttribute('data-pin-run');
        const pinned = btn.getAttribute('data-pin-val') === '1';
        try {
          await apiFetch(`/reports/${encodeURIComponent(rid)}/pin`, { method: 'POST', json: { pinned } });
          await loadBackendRuns();
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    });

    // Open run row
    container.querySelectorAll('[data-open-run]').forEach((row) => {
      row.addEventListener('click', async () => {
        const rid = row.getAttribute('data-open-run');
        if (crState.mode === 'local') {
          crState.activeReport = crState.localReports.find((r) => r.meta.run_id === rid) || null;
          crState.view = 'detail';
          crState.timeline = { phase: '', category: '', q: '', secFrom: null, secTo: null, page: 0, pageSize: 100 };
          rerender();
          return;
        }
        try {
          await openBackendReport(rid);
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    });

    // Detail actions
    const backBtn = container.querySelector('#crBackToListBtn');
    if (backBtn) {
      backBtn.addEventListener('click', async () => {
        crState.view = 'list';
        crState.activeReport = null;
        if (typeof window !== 'undefined' && window.location) window.history.replaceState(null, '', '#reports');
        if (crState.mode === 'backend' && crState.authenticated) await loadBackendRuns();
        rerender();
      });
    }

    const detailPinBtn = container.querySelector('#crDetailPinBtn');
    if (detailPinBtn && crState.activeReport) {
      detailPinBtn.addEventListener('click', async () => {
        const rid = crState.activeReport.meta.run_id;
        const nextPinned = !crState.activeReport.meta.pinned;
        try {
          await apiFetch(`/reports/${encodeURIComponent(rid)}/pin`, { method: 'POST', json: { pinned: nextPinned } });
          crState.activeReport.meta.pinned = nextPinned;
          setStatus(nextPinned ? 'Report pinned (protected from retention pruning).' : 'Report unpinned.', 'ok');
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    }

    const toggleShareBtn = container.querySelector('#crToggleShareBtn');
    if (toggleShareBtn) {
      toggleShareBtn.addEventListener('click', () => {
        crState.showShareDrawer = !crState.showShareDrawer;
        rerender();
      });
    }

    const createShareForm = container.querySelector('#crCreateShareForm');
    if (createShareForm && crState.activeReport) {
      createShareForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const rid = crState.activeReport.meta.run_id;
        const label = container.querySelector('#crShareLabel').value.trim();
        const expRaw = container.querySelector('#crShareExpiry').value;
        try {
          const res = await apiFetch(`/reports/${encodeURIComponent(rid)}/shares`, {
            method: 'POST',
            json: { label, expires_in_hours: expRaw ? Number(expRaw) : null },
          });
          crState.lastCreatedShare = res.share;
          await openBackendReport(rid);
          crState.showShareDrawer = true;
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    }

    const copyShareBtn = container.querySelector('#crCopyShareUrlBtn');
    if (copyShareBtn) {
      copyShareBtn.addEventListener('click', async () => {
        const val = container.querySelector('#crNewShareUrlInput')?.value || '';
        if (navigator.clipboard && val) {
          await navigator.clipboard.writeText(val);
          setStatus('Share URL copied to clipboard.', 'ok');
          rerender();
        }
      });
    }

    container.querySelectorAll('[data-revoke-share]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const sid = btn.getAttribute('data-revoke-share');
        try {
          await apiFetch(`/shares/${encodeURIComponent(sid)}`, { method: 'DELETE' });
          await openBackendReport(crState.activeReport.meta.run_id);
          crState.showShareDrawer = true;
          setStatus('Share link revoked immediately.', 'ok');
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    });

    // Exports
    const exportMdBtn = container.querySelector('#crExportMdBtn');
    if (exportMdBtn && crState.activeReport) {
      exportMdBtn.addEventListener('click', () => {
        if (crState.mode !== 'local') {
          const base = crState.mode === 'shared'
            ? `${crState.apiBase}/shared/${encodeURIComponent(crState.shareToken)}/download?file=markdown`
            : `${crState.apiBase}/reports/${encodeURIComponent(crState.activeReport.meta.run_id)}/download?file=markdown`;
          window.location.href = base;
        } else {
          downloadBlob(`${crState.activeReport.meta.run_id}_report.md`, buildMarkdownClient(crState.activeReport), 'text/markdown;charset=utf-8');
        }
      });
    }

    const exportCsvBtn = container.querySelector('#crExportCsvBtn');
    if (exportCsvBtn && crState.activeReport) {
      exportCsvBtn.addEventListener('click', () => {
        if (crState.mode !== 'local') {
          const base = crState.mode === 'shared'
            ? `${crState.apiBase}/shared/${encodeURIComponent(crState.shareToken)}/download?file=csv`
            : `${crState.apiBase}/reports/${encodeURIComponent(crState.activeReport.meta.run_id)}/download?file=csv`;
          window.location.href = base;
        } else {
          const pts = crState.activeReport.time_series?.points || [];
          const cols = ['sec', 'damage_dealt', 'player_damage', 'pet_clone_damage', 'rolling_dps_5s', 'rolling_dps_10s', 'damage_received', 'healing_done', 'player_hp_pct', 'player_tp', 'boss_hp_pct'];
          const rows = [cols.join(','), ...pts.map((p) => cols.map((c) => p[c] ?? '').join(','))];
          downloadBlob(`${crState.activeReport.meta.run_id}_timeline.csv`, rows.join('\n') + '\n', 'text/csv;charset=utf-8');
        }
      });
    }

    const localDlJsonl = container.querySelector('#crLocalDownloadJsonlBtn');
    if (localDlJsonl && crState.activeReport) {
      localDlJsonl.addEventListener('click', () => {
        const txt = crState.activeReport.raw_files?.summary || (JSON.stringify(crState.activeReport.summary) + '\n');
        downloadBlob(`${crState.activeReport.meta.run_id}_summary.jsonl`, txt, 'application/x-ndjson;charset=utf-8');
      });
    }

    container.querySelectorAll('[data-export-png]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const cid = btn.getAttribute('data-export-png');
        const c = document.getElementById(cid);
        if (!c) return;
        const a = document.createElement('a');
        a.href = c.toDataURL('image/png');
        a.download = `${crState.activeReport?.meta?.run_id || 'combat'}_${cid}.png`;
        a.click();
      });
    });

    // Chart toggles & drawing
    container.querySelectorAll('[data-chart-toggle]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const key = btn.getAttribute('data-chart-toggle');
        crState.chartOpts[key] = !crState.chartOpts[key];
        rerender();
      });
    });

    if (crState.view === 'detail' && crState.activeReport) {
      bindInteractiveChart('crDmgCanvas', 'crDmgTooltip', drawDamageChart, crState.activeReport, jumpToSecond);
      bindInteractiveChart('crVitalsCanvas', 'crVitalsTooltip', drawVitalsChart, crState.activeReport, jumpToSecond);
    }

    // Jump buttons
    container.querySelectorAll('[data-jump-sec]').forEach((btn) => {
      btn.addEventListener('click', () => jumpToSecond(Number(btn.getAttribute('data-jump-sec'))));
    });

    // Feedback
    let selectedFbTag = crState.activeReport?.feedback?.tag || 'skip';
    container.querySelectorAll('[data-fb-tag]').forEach((btn) => {
      btn.addEventListener('click', () => {
        selectedFbTag = btn.getAttribute('data-fb-tag');
        container.querySelectorAll('[data-fb-tag]').forEach((b) => b.classList.toggle('active', b === btn));
      });
    });
    const saveFbBtn = container.querySelector('#crSaveFeedbackBtn');
    if (saveFbBtn && crState.activeReport) {
      saveFbBtn.addEventListener('click', async () => {
        const summary_text = container.querySelector('#crFeedbackText').value;
        try {
          const res = await apiFetch(`/reports/${encodeURIComponent(crState.activeReport.meta.run_id)}/feedback`, {
            method: 'PUT',
            json: { tag: selectedFbTag, summary_text },
          });
          crState.activeReport.feedback = res.feedback;
          setStatus('Fight feedback saved.', 'ok');
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    }

    // Notes
    const addNoteForm = container.querySelector('#crAddNoteForm');
    if (addNoteForm && crState.activeReport) {
      addNoteForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const secVal = container.querySelector('#crNoteSecInput').value.trim();
        const body = container.querySelector('#crNoteBodyInput').value.trim();
        if (!body) return;
        try {
          const res = await apiFetch(`/reports/${encodeURIComponent(crState.activeReport.meta.run_id)}/notes`, {
            method: 'POST',
            json: { body, combat_sec: secVal !== '' ? Number(secVal) : null },
          });
          crState.activeReport.notes = [...(crState.activeReport.notes || []), res.note];
          crState.draftNoteSec = '';
          setStatus('Timestamped note added.', 'ok');
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    }

    container.querySelectorAll('[data-del-note]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const nid = btn.getAttribute('data-del-note');
        try {
          await apiFetch(`/reports/${encodeURIComponent(crState.activeReport.meta.run_id)}/notes/${encodeURIComponent(nid)}`, { method: 'DELETE' });
          crState.activeReport.notes = (crState.activeReport.notes || []).filter((n) => String(n.id) !== String(nid));
          rerender();
        } catch (err) {
          setStatus(err.message, 'danger');
          rerender();
        }
      });
    });

    container.querySelectorAll('[data-prefill-note-sec]').forEach((btn) => {
      btn.addEventListener('click', () => {
        crState.draftNoteSec = btn.getAttribute('data-prefill-note-sec');
        const inp = document.getElementById('crNoteSecInput');
        if (inp) {
          inp.value = crState.draftNoteSec;
          document.getElementById('crNoteBodyInput')?.focus();
        }
      });
    });

    // Timeline controls
    const tlPhase = container.querySelector('#crTlPhase');
    const tlCat = container.querySelector('#crTlCategory');
    const tlSearch = container.querySelector('#crTlSearch');
    const clearWin = container.querySelector('#crClearTimeWindowBtn');
    const prevBtn = container.querySelector('#crTlPrevBtn');
    const nextBtn = container.querySelector('#crTlNextBtn');

    if (tlPhase) tlPhase.addEventListener('change', () => { crState.timeline.phase = tlPhase.value; crState.timeline.page = 0; rerender(); });
    if (tlCat) tlCat.addEventListener('change', () => { crState.timeline.category = tlCat.value; crState.timeline.page = 0; rerender(); });
    if (tlSearch) tlSearch.addEventListener('change', () => { crState.timeline.q = tlSearch.value; crState.timeline.page = 0; rerender(); });
    if (clearWin) clearWin.addEventListener('click', () => { crState.timeline.secFrom = null; crState.timeline.secTo = null; crState.timeline.page = 0; rerender(); });
    if (prevBtn) prevBtn.addEventListener('click', () => { crState.timeline.page = Math.max(0, crState.timeline.page - 1); rerender(); });
    if (nextBtn) nextBtn.addEventListener('click', () => { crState.timeline.page += 1; rerender(); });
  }

  // =========================================================================
  // Public Integration API for site/app.js
  // =========================================================================
  const api = {
    async mount(container, opts = {}) {
      currentContainer = container;
      if (opts.shareToken) {
        container.innerHTML = '<div class="wiki-card">Loading shared Combat Report...</div>';
        await openSharedToken(opts.shareToken);
        renderInto(container);
        return;
      }

      if (crState.mode === 'backend' && !crState.authChecked) {
        container.innerHTML = '<div class="wiki-card">Connecting to Combat Analytics service...</div>';
        await checkAuth();
      }

      if (crState.mode === 'backend' && crState.authenticated) {
        try {
          if (opts.runId) {
            await openBackendReport(opts.runId);
          } else if (!crState.listData) {
            await loadBackendRuns();
          }
        } catch (err) {
          setStatus(err.message, 'danger');
        }
      }
      renderInto(container);
    },

    _internals: {
      parseJsonlText,
      computeRollingAverage,
      buildTimeSeriesClient,
      extractMarkersClient,
      analyzeEncounterClient,
      createSyntheticDemoReport,
      buildMarkdownClient,
      formatCombatMs,
      formatMetric,
    },
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.OverlordsCombatReports = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);
