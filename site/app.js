/**
 * OverlordsXI Server Wiki & Live Encyclopedia Engine
 * --------------------------------------------------
 * Zero-maintenance static SPA for SWAG / Nginx / GitHub Pages.
 * Automatically resolves the latest commit SHA from GitHub so
 * raw.githubusercontent.com never serves stale cached data.json.
 */
(function () {
  'use strict';

  const STORAGE_KEY = 'overlordsxi_wiki_sync_cfg_v1';
  const DEFAULT_CFG = {
    repo: 'Infomatictek/overlordsxi',
    branch: 'main',
    customDataUrl: '',
    token: '',
  };

  const SPEC_VIEW_META = [
    { key: 'berserker', label: 'Berserker / DPS', hint: 'WAR Berserker, SAM, DRK, DRG, THF, NIN, RNG, MNK DPS' },
    { key: 'tank', label: 'Tank / Vanguard', hint: 'RUN Inquisitor, WAR Gladiator, MNK Sensei, PLD' },
    { key: 'spellblade', label: 'Spellblade / Arcana', hint: 'RUN Spellblade, SCH Sage, BLM Necromancer, RDM, BLU, SMN' },
    { key: 'healer', label: 'Healer / Mending', hint: 'RUN Lifebinder, SCH Medic, WHM, BRD, GEO' },
    { key: 'commander', label: 'Commander / Tactical', hint: 'WAR Commander, COR' },
  ];

  let state = {
    data: window.OVERLORDS_DATA || null,
    activePage: 'overview',
    selectedJobKey: 'ALL',
    selectedSkillName: 'Hand-to-Hand',
    selectedWsId: 1,
    selectedWsSpec: 'berserker',
    wsSearchQuery: '',
    syncCfg: loadSyncConfig(),
    liveCommits: null,
  };

  function loadSyncConfig() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        return { ...DEFAULT_CFG, ...JSON.parse(raw) };
      }
    } catch (_) {}
    return { ...DEFAULT_CFG };
  }

  function saveSyncConfig(cfg) {
    state.syncCfg = { ...DEFAULT_CFG, ...cfg };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state.syncCfg));
    } catch (_) {}
  }

  function escapeHtml(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function formatRelativeDate(isoStr) {
    if (!isoStr) return '';
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return isoStr;
    return d.toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  // ---------------------------------------------------------------------------
  // Live GitHub / Data.json Sync (Bypasses Fastly 5-min raw branch cache)
  // ---------------------------------------------------------------------------
  async function syncFromGitHub() {
    const dot = document.getElementById('syncDot');
    const txt = document.getElementById('syncText');
    const setStatus = (label, color) => {
      if (txt) txt.textContent = label;
      if (dot) {
        dot.style.background = color;
        dot.style.boxShadow = `0 0 8px ${color}`;
      }
    };

    setStatus('Syncing...', '#fbbf24');

    const headers = { Accept: 'application/vnd.github.v3+json' };
    if (state.syncCfg.token) {
      headers.Authorization = `Bearer ${state.syncCfg.token}`;
    }

    // 1. Query GitHub Commits API first (uncached) to get the exact latest commit SHA
    let latestSha = '';
    try {
      const apiCommitsUrl = `https://api.github.com/repos/${state.syncCfg.repo}/commits?sha=${encodeURIComponent(
        state.syncCfg.branch
      )}&per_page=25&t=${Date.now()}`;
      const res = await fetch(apiCommitsUrl, { headers, cache: 'no-store' });
      if (res.ok) {
        const commitsArr = await res.json();
        if (Array.isArray(commitsArr) && commitsArr.length > 0) {
          latestSha = commitsArr[0].sha || '';
          state.liveCommits = commitsArr.map((c) => ({
            hash: c.sha,
            shortHash: (c.sha || '').slice(0, 7),
            author: c.commit?.author?.name || c.author?.login || 'Author',
            date: c.commit?.author?.date || '',
            subject: (c.commit?.message || '').split('\n')[0],
            files: [],
            totalAdded: 0,
            totalRemoved: 0,
          }));
        }
      }
    } catch (_) {}

    // 2. Fetch data.json — prioritize customDataUrl, then immutable commit-SHA raw URL, then branch/local
    const candidateUrls = [];
    if (state.syncCfg.customDataUrl) {
      candidateUrls.push(state.syncCfg.customDataUrl);
    }
    if (!state.syncCfg.token) {
      if (latestSha) {
        candidateUrls.push(
          `https://raw.githubusercontent.com/${state.syncCfg.repo}/${latestSha}/site/data.json`
        );
      }
      candidateUrls.push(
        `https://raw.githubusercontent.com/${state.syncCfg.repo}/${state.syncCfg.branch}/site/data.json?t=${Date.now()}`
      );
    }
    candidateUrls.push(`./data.json?t=${Date.now()}`);

    let loadedRemoteJson = false;
    for (const url of candidateUrls) {
      try {
        const res = await fetch(url, { cache: 'no-store' });
        if (res.ok) {
          const json = await res.json();
          if (json && json.jobSpecs && json.weaponskills) {
            state.data = json;
            loadedRemoteJson = true;
            break;
          }
        }
      } catch (_) {}
    }

    if (state.data && state.liveCommits && state.liveCommits.length > 0 && !state.data.headCommit) {
      state.data.headCommit = state.liveCommits[0].shortHash;
    }

    updateSidebarMeta();
    renderCurrentPage();
    setStatus(
      loadedRemoteJson
        ? `Live (${state.data?.headCommit || latestSha.slice(0, 7) || 'main'})`
        : `Local (${state.data?.headCommit || 'bundled'})`,
      '#10b981'
    );
  }

  function updateSidebarMeta() {
    if (!state.data) return;
    const cBadge = document.getElementById('badgeCrystalsCount');
    const wBadge = document.getElementById('badgeWsCount');
    const cHash = document.getElementById('sidebarCommitHash');
    if (cBadge) cBadge.textContent = state.data.stats?.totalCrystalSpecs || 11;
    if (wBadge) wBadge.textContent = state.data.stats?.totalWeaponskills || 219;
    if (cHash) cHash.textContent = state.data.headCommit || 'latest';

    const jobSublist = document.getElementById('sidebarJobLinks');
    if (jobSublist && state.data.jobSpecs) {
      jobSublist.innerHTML = state.data.jobSpecs
        .map(
          (j) => `
          <button class="job-Quick-link" data-job-jump="${escapeHtml(j.jobKey)}">
            <span>
              <span class="job-pill-mini" style="background:${escapeHtml(j.color)}">${escapeHtml(j.jobKey)}</span>
              ${escapeHtml(j.jobName)}
            </span>
            <span class="nav-badge">${j.crystals.length}</span>
          </button>
        `
        )
        .join('');

      jobSublist.querySelectorAll('[data-job-jump]').forEach((btn) => {
        btn.addEventListener('click', () => {
          state.selectedJobKey = btn.getAttribute('data-job-jump');
          navigateTo('crystals');
        });
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation & Page Router
  // ---------------------------------------------------------------------------
  function navigateTo(page, opts = {}) {
    state.activePage = page;
    if (opts.jobKey) state.selectedJobKey = opts.jobKey;
    if (opts.skillName) state.selectedSkillName = opts.skillName;
    if (opts.wsId) state.selectedWsId = Number(opts.wsId);
    if (opts.wsSpec) state.selectedWsSpec = opts.wsSpec;

    document.querySelectorAll('.nav-item[data-page]').forEach((btn) => {
      btn.classList.toggle('active', btn.getAttribute('data-page') === page);
    });

    renderCurrentPage();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function renderCurrentPage() {
    const main = document.getElementById('wikiMainContent');
    if (!main || !state.data) return;

    switch (state.activePage) {
      case 'overview':
        main.innerHTML = renderOverviewPage();
        bindOverviewEvents(main);
        break;
      case 'combat':
        main.innerHTML = renderCombatPage();
        break;
      case 'crystals':
        main.innerHTML = renderCrystalsPage();
        bindCrystalsEvents(main);
        break;
      case 'talents':
        main.innerHTML = renderTalentsPage();
        bindTalentsEvents(main);
        break;
      case 'companions':
        main.innerHTML = renderCompanionsPage();
        break;
      case 'commands':
        main.innerHTML = renderCommandsPage();
        break;
      case 'patches':
        main.innerHTML = renderPatchesPage();
        break;
      default:
        main.innerHTML = renderOverviewPage();
        bindOverviewEvents(main);
    }
  }

  // ---------------------------------------------------------------------------
  // PAGE 1: Overview & Quick Start Wiki Home
  // ---------------------------------------------------------------------------
  function renderOverviewPage() {
    const d = state.data;
    const s = d.stats || {};

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">⚡ Classic Level 75 Cap &bull; Level 99 QoL &bull; Spec-Adaptive WS Trees</div>
        <h1>Welcome to the OverlordsXI Encyclopedia</h1>
        <p>
          OverlordsXI blends the iconic <strong>Level 75 Era cap</strong> with modern <strong>Level 99 Quality-of-Life</strong>,
          faster baseline combat pacing, transformative <strong>Lv.10+ Job Soul Crystals</strong>, and a deep
          <strong>Spec-Adaptive 56-point Talent Tree for every Weaponskill in the game</strong>.
        </p>

        <div class="stat-grid">
          <div class="stat-card" data-nav="crystals">
            <div class="stat-value">${s.totalCrystalSpecs || 11} Soul Crystals</div>
            <div class="stat-label">Across ${s.totalJobsWithSpecs || 6} Jobs (${s.totalCustomAbilities || 28} Custom JAs)</div>
          </div>
          <div class="stat-card" data-nav="talents">
            <div class="stat-value">${s.totalWeaponskills || 219} WS Trees</div>
            <div class="stat-label">5 Spec Views &bull; Unlock via Tier 1</div>
          </div>
          <div class="stat-card" data-nav="companions">
            <div class="stat-value">6 Custom Pets</div>
            <div class="stat-label">Eos, Titania, Warrior, Mage, Corse &amp; Dullahan</div>
          </div>
          <div class="stat-card" data-nav="combat">
            <div class="stat-value">+25% Haste</div>
            <div class="stat-label">Always-On Player Pace + 20/tick Regain</div>
          </div>
          <div class="stat-card" data-nav="commands">
            <div class="stat-value">80-Slot Bags</div>
            <div class="stat-label">All 22 Jobs, 5 Trusts &amp; Lv.1 Starter Shop</div>
          </div>
        </div>
      </section>

      <div class="section-header">
        <h2>🧭 Core Pillars of OverlordsXI</h2>
        <span class="section-sub">Click any system below to explore the full wiki guide</span>
      </div>

      <div class="card-grid-2">
        <div class="wiki-card">
          <h3>
            <span>💎 Job Soul Crystals (Lv. 10+)</span>
            <span class="badge badge-gold">!spec</span>
          </h3>
          <p>
            Starting at <strong>Level 10</strong> in your main job, you can socket a Job Soul Crystal that reshapes how your job plays—turning
            <strong>Warrior</strong> into a party-buffing <em>Commander</em>, a burst <em>Berserker</em>, or a blood-leeching Club &amp; Shield <em>Gladiator</em> tank;
            <strong>Monk</strong> into an evasive Staff-parrying <em>Sensei</em> tank;
            <strong>Scholar</strong> into a faerie-summoning <em>Medic</em> (Eos) or <em>Sage</em> (Titania);
            <strong>Black Mage</strong> into a Scythe-wielding <em>Necromancer</em>;
            <strong>Dancer</strong> into a 20-yalm ranged Chakram <em>Bladewheel</em>; and
            <strong>Rune Fencer</strong> into an <em>Inquisitor</em> tank, <em>Spellblade</em> DPS, or <em>Lifebinder</em> healer.
          </p>
          <button class="btn-primary" data-nav="crystals">Explore All ${s.totalCrystalSpecs || 11} Job Crystals &rarr;</button>
        </div>

        <div class="wiki-card">
          <h3>
            <span>🌟 Spec-Adaptive WS Talent Trees</span>
            <span class="badge badge-cyan">!talent / /talents</span>
          </h3>
          <p>
            All ${s.totalWeaponskills || 219} Weaponskills are <strong>visible from Level 1</strong> and unlock for use as soon as you invest
            <strong>1 point in Tier 1</strong>. You earn <strong>3 Talent Points per job level</strong> (<strong>225 pts at Lv. 75</strong>—4 maxed WSs at 56 pts each).
            Each WS dynamically reshapes across <strong>5 Spec Trees</strong> (<em>Berserker, Tank, Spellblade, Healer, Commander</em>) and enforces strict
            Magic/Utility stat sanitization—no dead physical stats on Magic/Utility WSs!
          </p>
          <button class="btn-primary" data-nav="talents">Browse All ${s.totalWeaponskills || 219} Weaponskill Trees &rarr;</button>
        </div>

        <div class="wiki-card">
          <h3>
            <span>⚔️ Brisk Combat Pace &amp; Boss-Like Mobs</span>
            <span class="badge badge-emerald">Lv. 1–75</span>
          </h3>
          <p>
            Players begin at Level 1 with <strong>+25% baseline Haste</strong> (+15% Gear + 10% JA), <strong>+25 Store TP</strong>,
            <strong>20 TP/tick Regain</strong> in combat, and <strong>+15% Fast Cast</strong>. Mobs scale progressively from Lv. 1 to 75
            with boss-like durability and rewards: higher per-kill EXP caps, <strong>3x longer EXP chain timers</strong>, and anti-one-shot caps on
            breath/suicide moves.
          </p>
          <button class="btn-secondary" data-nav="combat">Read Combat &amp; EXP Mechanics &rarr;</button>
        </div>

        <div class="wiki-card">
          <h3>
            <span>🎒 Instant Level 99 QoL &amp; Starter Loadouts</span>
            <span class="badge badge-purple">!weapons / !gear</span>
          </h3>
          <p>
            Every new character logs in with <strong>all 22 Jobs unlocked</strong>, <strong>all 8 Mog Wardrobes &amp; bags expanded to 80 slots</strong>,
            <strong>all 9 Rhapsodies of Vana'diel key items</strong> (summon up to 5 Trusts immediately), auto-capped combat &amp; magic skills,
            a <strong>29-item BiS Lv.1 Starter Kit</strong>, and instant access to the 263-item Lv.1 Weapons Shop via <code>!weapons</code>.
          </p>
          <button class="btn-secondary" data-nav="commands">View All Player Commands &rarr;</button>
        </div>
      </div>

      <div class="section-header">
        <h2>💎 Job Soul Crystal Directory</h2>
        <span class="section-sub">Select any job to jump straight to its passive scaling, custom Job Abilities, and traits</span>
      </div>

      <div class="card-grid-3">
        ${(d.jobSpecs || [])
          .map(
            (j) => `
          <div class="wiki-card" style="border-top: 3px solid ${escapeHtml(j.color)}">
            <h3>
              <span>${escapeHtml(j.jobName)} (<code>${escapeHtml(j.jobKey)}</code>)</span>
              <span class="badge badge-cyan">${j.crystals.length} ${j.crystals.length === 1 ? 'Crystal' : 'Crystals'}</span>
            </h3>
            <ul class="highlight-list" style="margin-bottom: 1rem;">
              ${j.crystals
                .map(
                  (c) =>
                    `<li><strong>${escapeHtml(c.name)}</strong> — <span style="color:var(--accent-gold)">${escapeHtml(
                      c.role
                    )}</span></li>`
                )
                .join('')}
            </ul>
            <button class="btn-secondary" data-job-card="${escapeHtml(j.jobKey)}" style="width:100%">
              Open ${escapeHtml(j.jobName)} Wiki &rarr;
            </button>
          </div>
        `
          )
          .join('')}
      </div>
    `;
  }

  function bindOverviewEvents(container) {
    container.querySelectorAll('[data-nav]').forEach((el) => {
      el.addEventListener('click', () => navigateTo(el.getAttribute('data-nav')));
    });
    container.querySelectorAll('[data-job-card]').forEach((el) => {
      el.addEventListener('click', () =>
        navigateTo('crystals', { jobKey: el.getAttribute('data-job-card') })
      );
    });
  }

  // ---------------------------------------------------------------------------
  // PAGE 2: Combat, EXP & Level 99 QoL Rules
  // ---------------------------------------------------------------------------
  function renderCombatPage() {
    const r = state.data.serverRules || {};

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">⚔️ Server Ruleset &bull; boss_like_combat_and_exp.lua</div>
        <h1>Combat Pace, Mob Scaling, EXP &amp; Level 99 QoL</h1>
        <p>
          OverlordsXI eliminates the slow early-game swing timers of vanilla FFXI while making every monster fight feel like an engaging,
          rewarding encounter with dramatically boosted EXP chains and full Level 99 convenience from your very first login.
        </p>
      </section>

      <div class="section-header">
        <h2>⚡ Always-On Player &amp; Pet Combat Pace</h2>
        <span class="section-sub">Applied automatically to all players and pets from Level 1 to 75</span>
      </div>

      <div class="card-grid-2">
        <div class="wiki-card">
          <h3><span>Player Baseline Combat Modifiers</span><span class="badge badge-cyan">Always Active</span></h3>
          <div class="wiki-table-wrap">
            <table class="wiki-table">
              <thead>
                <tr>
                  <th>Modifier</th>
                  <th>Bonus</th>
                  <th>Effect</th>
                </tr>
              </thead>
              <tbody>
                ${(r.baselinePlayerPace || [])
                  .map(
                    (row) => `
                  <tr>
                    <td><strong>${escapeHtml(row.stat)}</strong></td>
                    <td><code>${escapeHtml(row.value)}</code></td>
                    <td>${escapeHtml(row.desc)}</td>
                  </tr>
                `
                  )
                  .join('')}
              </tbody>
            </table>
          </div>
        </div>

        <div class="wiki-card">
          <h3><span>Pet &amp; Companion Baseline Pace</span><span class="badge badge-gold">Eos / Titania / Undead / Avatars</span></h3>
          <div class="wiki-table-wrap">
            <table class="wiki-table">
              <thead>
                <tr>
                  <th>Modifier</th>
                  <th>Bonus</th>
                  <th>Effect</th>
                </tr>
              </thead>
              <tbody>
                ${(r.petCombatPace || [])
                  .map(
                    (row) => `
                  <tr>
                    <td><strong>${escapeHtml(row.stat)}</strong></td>
                    <td><code>${escapeHtml(row.value)}</code></td>
                    <td>${escapeHtml(row.desc)}</td>
                  </tr>
                `
                  )
                  .join('')}
              </tbody>
            </table>
          </div>
          <p style="margin-top:0.9rem; font-size:0.86rem; color:var(--text-muted);">
            * Additionally, all player, pet, and Trust DoT effects (Dia, Bio, Poison, Elemental DoTs, Helix, Kaustra, Requiem) emit exact per-tick damage lines in the combat log.
          </p>
        </div>
      </div>

      <div class="section-header">
        <h2>🐉 Progressive Mob Scaling &amp; The IT++ Level-Gap Wall</h2>
        <span class="section-sub">Mobs scale across Spec tiers (Lv. 10 / 30 / 50 / 70+) to match Soul Crystals &amp; WS Talents</span>
      </div>

      <div class="card-grid-2">
        <div class="wiki-card">
          <h3><span>Monster Stat Scaling (Lv. 1 &rarr; 75)</span><span class="badge badge-purple">Normal &amp; NMs</span></h3>
          <ul class="highlight-list">
            <li><strong>Lv. 1–9 Smooth Ramp:</strong> Gentle onboarding before your Lv. 10 Soul Crystal unlocks (<code>0.35x &rarr; 0.72x</code> scale).</li>
            <li><strong>Around Lv. 25 (1.0x Scale):</strong> Regular mobs gain <code>${escapeHtml(r.mobScaling?.normalLv25)}</code>.</li>
            <li><strong>At Lv. 75 Cap (2.15x Scale):</strong> Regular mobs gain <code>${escapeHtml(r.mobScaling?.normalLv75)}</code>.</li>
            <li><strong>Notorious Monsters (NMs):</strong> ${escapeHtml(r.mobScaling?.nmBonus)}.</li>
            <li><strong>Anti-One-Shot Breath &amp; Suicide Caps:</strong> Bomb Toss, Self-Destruct, Mijin Gakure, and HP-proportional breaths are capped to fair percentages of your Max HP so boss-scaled HP pools never cause unfair one-shots.</li>
          </ul>
        </div>

        <div class="wiki-card">
          <h3><span>Level-Difference Scaling (<code>dLvl = MobLvl - PlayerLvl</code>)</span><span class="badge badge-gold">Wall @ +8 Lvls</span></h3>
          <div class="wiki-table-wrap">
            <table class="wiki-table">
              <thead>
                <tr>
                  <th>Level Gap</th>
                  <th>Player/Pet DMG</th>
                  <th>Mob DMG</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                ${(r.levelGapTable || [])
                  .map(
                    (row) => `
                  <tr>
                    <td><strong>${escapeHtml(row.diff)}</strong></td>
                    <td><code>${escapeHtml(row.playerDmg)}</code></td>
                    <td><code>${escapeHtml(row.mobDmg)}</code></td>
                    <td>${escapeHtml(row.note)}</td>
                  </tr>
                `
                  )
                  .join('')}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="section-header">
        <h2>✨ Level 99 Quality-of-Life Unlocks &amp; Starter Kit</h2>
        <span class="section-sub">Everything unlocked automatically on login</span>
      </div>

      <div class="card-grid-3">
        ${(r.qolCards || [])
          .map(
            (c) => `
          <div class="wiki-card">
            <h3><span>${escapeHtml(c.title)}</span></h3>
            <p style="margin:0">${escapeHtml(c.desc)}</p>
          </div>
        `
          )
          .join('')}
      </div>
    `;
  }

  // ---------------------------------------------------------------------------
  // PAGE 3: Job Soul Crystals & Spec Encyclopedia
  // ---------------------------------------------------------------------------
  function renderCrystalsPage() {
    const jobs = state.data.jobSpecs || [];
    const filteredJobs =
      state.selectedJobKey === 'ALL'
        ? jobs
        : jobs.filter((j) => j.jobKey === state.selectedJobKey);

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">💎 Job Soul Crystal System &bull; Unlocks at Level 10 (!spec)</div>
        <h1>Job Soul Crystals &amp; Specializations</h1>
        <p>
          At <strong>Level 10</strong> in any supported job, use <code>!spec</code> (or the Ashita v4 Equipment Crystal UI) to socket a Soul Crystal.
          Each crystal grants level-scaling passive stats (scaling at <strong>Lv. 10 / 30 / 50 / 70+</strong>), custom Job Traits in your traits menu,
          new active Job Abilities, and deep transformations to existing abilities and spells.
        </p>
      </section>

      <div class="job-filter-bar">
        <button class="filter-chip ${state.selectedJobKey === 'ALL' ? 'active' : ''}" data-job-filter="ALL">
          All Jobs (${jobs.reduce((acc, j) => acc + j.crystals.length, 0)} Crystals)
        </button>
        ${jobs
          .map(
            (j) => `
          <button class="filter-chip ${state.selectedJobKey === j.jobKey ? 'active' : ''}" data-job-filter="${escapeHtml(j.jobKey)}">
            ${escapeHtml(j.jobKey)} &bull; ${escapeHtml(j.jobName)} (${j.crystals.length})
          </button>
        `
          )
          .join('')}
      </div>

      ${filteredJobs
        .map((job) =>
          job.crystals
            .map((c) => renderSingleCrystalCard(job, c))
            .join('')
        )
        .join('')}
    `;
  }

  function renderSingleCrystalCard(job, c) {
    const mods = c.passiveMods || [];
    const abils = c.customAbilities || [];
    const traits = c.customTraits || [];

    return `
      <article class="crystal-card" id="crystal-${escapeHtml(job.jobKey)}-${escapeHtml(c.key)}">
        <div class="crystal-header">
          <div class="crystal-title-group">
            <div class="crystal-job-crest" style="background:${escapeHtml(job.color)}">
              ${escapeHtml(job.jobKey)}
            </div>
            <div>
              <h2 class="crystal-name">${escapeHtml(c.name)} <span style="font-weight:400; font-size:0.95rem; color:var(--text-muted)">(${escapeHtml(job.jobName)} Soul Crystal)</span></h2>
              <div class="crystal-role">${escapeHtml(c.role)}</div>
            </div>
          </div>
          <div style="display:flex; gap:0.5rem; align-items:center; flex-wrap:wrap;">
            <span class="badge badge-gold">Unlocks @ Lv. ${c.reqLevel || 10}</span>
            <code>!spec set ${escapeHtml(c.key)}</code>
          </div>
        </div>

        <p style="font-size:0.98rem; color:var(--text-primary); margin-top:0;">
          ${escapeHtml(c.description)}
        </p>

        <div class="crystal-columns">
          <div>
            <h4 style="margin:0 0 0.6rem; color:var(--accent-cyan); text-transform:uppercase; font-size:0.78rem; letter-spacing:0.06em;">
              ✨ Key Mechanics &amp; Ability Transformations
            </h4>
            <ul class="highlight-list">
              ${(c.highlights || []).map((h) => `<li>${escapeHtml(h)}</li>`).join('')}
            </ul>

            ${
              traits.length > 0
                ? `
              <h4 style="margin:1.25rem 0 0.55rem; color:var(--accent-gold); text-transform:uppercase; font-size:0.78rem; letter-spacing:0.06em;">
                🎖️ Unlocks Custom Job Trait(s)
              </h4>
              <div style="display:flex; flex-direction:column; gap:0.45rem;">
                ${traits
                  .map(
                    (t) => `
                  <div class="ability-box" style="border-color:var(--border-gold);">
                    <div class="ability-box-top">
                      <span class="ability-box-name">${escapeHtml(t.name)}</span>
                      <span class="ability-box-meta">Trait #${t.id}</span>
                    </div>
                    <div style="font-size:0.84rem; color:var(--text-secondary);">${escapeHtml(t.desc)}</div>
                  </div>
                `
                  )
                  .join('')}
              </div>
            `
                : ''
            }
          </div>

          <div>
            <h4 style="margin:0 0 0.6rem; color:var(--accent-cyan); text-transform:uppercase; font-size:0.78rem; letter-spacing:0.06em;">
              📊 Scaling Passive Stat Modifiers
            </h4>
            ${
              mods.length > 0
                ? `
              <div class="wiki-table-wrap">
                <table class="wiki-table">
                  <thead>
                    <tr>
                      <th>Stat / Modifier</th>
                      <th>Scaling Value</th>
                      <th>Tiers</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${mods
                      .map(
                        (m) => `
                      <tr>
                        <td><strong>${escapeHtml(m.label)}</strong></td>
                        <td><code>${escapeHtml(m.value)}</code></td>
                        <td style="color:var(--text-muted); font-size:0.78rem;">${escapeHtml(m.bracket)}</td>
                      </tr>
                    `
                      )
                      .join('')}
                  </tbody>
                </table>
              </div>
            `
                : `<div class="wiki-card" style="background:rgba(10,15,29,0.5); padding:0.9rem;">
                    <p style="margin:0; font-size:0.88rem;">Passives are applied dynamically via spell/stance overrides and companion bond effects (see Key Mechanics).</p>
                   </div>`
            }
          </div>
        </div>

        ${
          abils.length > 0
            ? `
          <h4 style="margin:1.4rem 0 0.4rem; color:#fff; text-transform:uppercase; font-size:0.78rem; letter-spacing:0.06em;">
            ⚡ Crystal-Unlocked Active Job Abilities (${abils.length})
          </h4>
          <div class="ability-grid">
            ${abils
              .map(
                (a) => `
              <div class="ability-box">
                <div class="ability-box-top">
                  <span class="ability-box-name">${escapeHtml(a.name)}</span>
                  <span class="ability-box-meta">CD: ${escapeHtml(a.cd)} &bull; ${escapeHtml(a.target)}</span>
                </div>
                <div style="font-size:0.84rem; color:var(--text-secondary);">${escapeHtml(a.desc)}</div>
              </div>
            `
              )
              .join('')}
          </div>
        `
            : ''
        }
      </article>
    `;
  }

  function bindCrystalsEvents(container) {
    container.querySelectorAll('[data-job-filter]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.selectedJobKey = btn.getAttribute('data-job-filter');
        renderCurrentPage();
      });
    });
  }

  // ---------------------------------------------------------------------------
  // PAGE 4: Weaponskill Talent Trees Explorer (All 219 WSs + 5 Spec Views)
  // ---------------------------------------------------------------------------
  function renderTalentsPage() {
    const allWs = state.data.weaponskills || [];
    const skillCategories = [];
    const seenSkills = new Set();
    for (const w of allWs) {
      if (!seenSkills.has(w.skillName)) {
        seenSkills.add(w.skillName);
        skillCategories.push(w.skillName);
      }
    }

    const filteredWs = allWs.filter((w) => {
      if (state.wsSearchQuery.trim() !== '') {
        const q = state.wsSearchQuery.toLowerCase();
        return (
          w.name.toLowerCase().includes(q) ||
          w.skillName.toLowerCase().includes(q) ||
          (w.archetype || '').toLowerCase().includes(q)
        );
      }
      return w.skillName === state.selectedSkillName;
    });

    const activeWs =
      allWs.find((w) => w.id === state.selectedWsId) ||
      filteredWs[0] ||
      allWs[0];

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">🌟 Spec-Adaptive Weaponskill Talents &bull; 3 Pts/Lv (225 Pts @ Lv.75)</div>
        <h1>Weaponskill Talent Tree Encyclopedia (${allWs.length} WSs)</h1>
        <p>
          Every Weaponskill is visible from Level 1 and <strong>unlocks for combat use when you invest 1+ Talent Point in Tier 1</strong>.
          Base PC WSs start at <code>1 Hit, fTP 1.0, 0% WSC, No Skillchain</code> and reshape dynamically across <strong>5 Spec Trees</strong>
          (<em>Berserker, Tank, Spellblade, Healer, Commander</em>). Tier gates unlock at <strong>Lv. 1 / Lv. 5 / Lv. 10 / Lv. 15</strong>,
          with individual node ranks scaling smoothly up to Lv. 75.
        </p>
      </section>

      <div class="job-filter-bar" id="wsSkillFilterBar">
        ${skillCategories
          .map((sk) => {
            const count = allWs.filter((w) => w.skillName === sk).length;
            const isActive = state.wsSearchQuery === '' && state.selectedSkillName === sk;
            return `
              <button class="filter-chip ${isActive ? 'active' : ''}" data-skill-filter="${escapeHtml(sk)}">
                ${escapeHtml(sk)} (${count})
              </button>
            `;
          })
          .join('')}
      </div>

      <div class="ws-explorer-layout">
        <div class="ws-list-panel">
          <input
            type="search"
            id="wsFilterInput"
            class="form-input"
            placeholder="Filter weaponskills by name..."
            value="${escapeHtml(state.wsSearchQuery)}"
          />
          <div class="ws-list-scroll">
            ${filteredWs
              .map(
                (w) => `
              <button class="ws-item-btn ${activeWs && activeWs.id === w.id ? 'active' : ''}" data-ws-id="${w.id}">
                <span>
                  <strong style="color:var(--text-muted); font-family:var(--font-mono); font-size:0.75rem;">#${w.id}</strong>
                  ${escapeHtml(w.name)}
                </span>
                <span class="badge ${w.isCustomThrowing ? 'badge-gold' : 'badge-cyan'}" style="font-size:0.68rem;">
                  ${escapeHtml(w.archetype || w.wsType)}
                </span>
              </button>
            `
              )
              .join('')}
          </div>
        </div>

        <div class="ws-tree-panel">
          ${activeWs ? renderSingleWsTree(activeWs) : '<p>Select a weaponskill to inspect its talent tree.</p>'}
        </div>
      </div>
    `;
  }

  function renderSingleWsTree(ws) {
    const orig = ws.orig || {};
    const wscEntries = Object.entries(orig.wsc || {});
    const wscText = wscEntries.length
      ? wscEntries.map(([k, v]) => `${k} ${v}%`).join(' / ')
      : 'None';
    const ftpArr = orig.ftp || [1, 1, 1];
    const ftpText = ftpArr.map((n) => Number(n).toFixed(2)).join(' / ');
    const scText = (orig.skillchain || []).join(' / ') || 'None';

    const specTrees = ws.specTrees || {};
    const isSpecAdaptive = ws.isSpecAdaptive !== false && Object.keys(specTrees).length > 1;
    const activeSpecKey = isSpecAdaptive
      ? (specTrees[state.selectedWsSpec] ? state.selectedWsSpec : 'berserker')
      : Object.keys(specTrees)[0] || 'default';
    const activeNodes = (isSpecAdaptive ? specTrees[activeSpecKey] : specTrees[activeSpecKey] || ws.nodes) || [];
    const specList = (state.data.serverRules?.specCategories || []).map((s) => ({
      key: s.key,
      label: s.label,
      hint: s.specs || s.hint || '',
    }));
    const effectiveSpecs = specList.length > 0 ? specList : SPEC_VIEW_META;
    const activeSpecInfo = effectiveSpecs.find((s) => s.key === activeSpecKey);

    const tg = state.data.serverRules?.tierGates || {};
    const tGate = (n, defLvl, defPts, sfx = ' Required') => {
      const g = tg[n] || tg[String(n)];
      const lvl = g ? g.reqLevel : defLvl;
      const pts = g ? g.reqWsPoints : defPts;
      return `Lv. ${lvl}+ &bull; ${pts}+ WS Pts${sfx}`;
    };

    const tierMeta = {
      1: { title: 'Tier 1 — Foundation & Unlock Gate', gate: tGate(1, 1, 0, ' (Invest 1 pt here to unlock WS)') },
      2: { title: 'Tier 2 — Specialization', gate: tGate(2, 5, 2) },
      3: { title: 'Tier 3 — Mastery', gate: tGate(3, 10, 5) },
      4: { title: 'Tier 4 — Capstone & Apex', gate: tGate(4, 15, 8) },
    };

    return `
      <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:flex-start; gap:1rem; padding-bottom:1rem; border-bottom:1px solid var(--border-subtle);">
        <div>
          <div style="display:flex; align-items:center; gap:0.6rem; flex-wrap:wrap;">
            <h2 style="font-family:var(--font-display); margin:0; font-size:1.55rem; color:#fff;">
              #${ws.id} ${escapeHtml(ws.name)}
            </h2>
            <span class="badge badge-cyan">${escapeHtml(ws.skillName)}</span>
            <span class="badge badge-gold">Type: ${escapeHtml((ws.wsType || 'physical').toUpperCase())}</span>
            ${ws.isCustomThrowing ? '<span class="badge badge-purple">Custom DNC Bladewheel WS</span>' : ''}
          </div>
          <div style="margin-top:0.5rem; font-size:0.86rem; color:var(--text-muted);">
            Vanilla Reference: <code>${orig.numHits || 1} Hit(s)</code> &bull;
            Orig fTP: <code>${escapeHtml(ftpText)}</code> &bull;
            Orig WSC: <code>${escapeHtml(wscText)}</code> &bull;
            Default SC Affinity: <code>${escapeHtml(scText)}</code>
          </div>
        </div>
        <div style="text-align:right;">
          <span class="badge badge-emerald">WS Cap: 56 Pts (${activeNodes.reduce((s, n) => s + (n.maxRank || 0), 0)} Total in Tree)</span>
          <div style="font-size:0.75rem; color:var(--text-muted); margin-top:4px;">
            Source: <code>${escapeHtml(ws.sourceFile || '')}</code>
          </div>
        </div>
      </div>

      ${
        isSpecAdaptive
          ? `
        <div style="margin-top:1rem; padding:0.85rem 1rem; background:rgba(10,15,29,0.72); border:1px solid var(--border-accent); border-radius:10px;">
          <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem; margin-bottom:0.65rem;">
            <strong style="font-size:0.82rem; color:var(--accent-cyan); text-transform:uppercase; letter-spacing:0.06em;">
              💎 Spec Tree View (Adapts automatically to your active Soul Crystal / Job):
            </strong>
            <span style="font-size:0.78rem; color:var(--text-muted);">${escapeHtml(activeSpecInfo?.hint || '')}</span>
          </div>
          <div class="job-filter-bar" style="margin-bottom:0;">
            ${effectiveSpecs.map(
              (sp) => `
              <button class="filter-chip ${activeSpecKey === sp.key ? 'active' : ''}" data-ws-spec="${escapeHtml(sp.key)}">
                ${escapeHtml(sp.label)}
              </button>
            `
            ).join('')}
          </div>
        </div>
      `
          : `
        <div style="margin-top:0.85rem;">
          <span class="badge badge-purple">Dedicated DNC Bladewheel Chakram Tree</span>
        </div>
      `
      }

      ${[1, 2, 3, 4]
        .map((tierNum) => {
          const tNodes = activeNodes.filter((n) => n.tier === tierNum);
          const meta = tierMeta[tierNum];
          return `
            <div class="tier-block">
              <div class="tier-block-header">
                <span class="tier-title">${meta.title}</span>
                <span style="font-size:0.78rem; color:var(--text-muted);">${meta.gate}</span>
              </div>
              <div class="tier-nodes-grid">
                ${tNodes
                  .map((n) => {
                    const rlt = state.data.serverRules?.rankLevelTables || {};
                    const lvls = n.rankLevels || (n.isSkillchain ? rlt.sc?.[String(n.tier)] : rlt[String(n.tier)]?.[String(n.maxRank)]) || [];
                    const lvlHint =
                      lvls.length > 1
                        ? `Lv.${lvls[0]}..${lvls[lvls.length - 1]}`
                        : `Lv.${lvls[0] || n.reqLevel || 1}+`;
                    return `
                  <div class="talent-node-card ${n.isSkillchain ? 'sc-node' : ''} ${n.key === 'capstone' ? 'capstone-node' : ''}">
                    <div class="node-top">
                      <span class="node-name">${escapeHtml(n.name)}</span>
                      <span class="node-ranks">${n.maxRank} Ranks &bull; ${escapeHtml(lvlHint)}</span>
                    </div>
                    <div class="node-desc">${escapeHtml(n.desc)}</div>
                  </div>
                `;
                  })
                  .join('')}
              </div>
            </div>
          `;
        })
        .join('')}
    `;
  }

  function bindTalentsEvents(container) {
    container.querySelectorAll('[data-skill-filter]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.wsSearchQuery = '';
        state.selectedSkillName = btn.getAttribute('data-skill-filter');
        const firstInSkill = (state.data.weaponskills || []).find(
          (w) => w.skillName === state.selectedSkillName
        );
        if (firstInSkill) state.selectedWsId = firstInSkill.id;
        renderCurrentPage();
      });
    });

    container.querySelectorAll('[data-ws-id]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.selectedWsId = Number(btn.getAttribute('data-ws-id'));
        renderCurrentPage();
      });
    });

    container.querySelectorAll('[data-ws-spec]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.selectedWsSpec = btn.getAttribute('data-ws-spec');
        renderCurrentPage();
      });
    });

    const filterInput = container.querySelector('#wsFilterInput');
    if (filterInput) {
      filterInput.addEventListener('input', (e) => {
        state.wsSearchQuery = e.target.value;
        renderCurrentPage();
        const reInput = document.getElementById('wsFilterInput');
        if (reInput) {
          reInput.focus();
          reInput.setSelectionRange(reInput.value.length, reInput.value.length);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // PAGE 5: Companions, Custom Pets & Equipment Progression
  // ---------------------------------------------------------------------------
  function renderCompanionsPage() {
    const comps = state.data.companions || [];
    const chakrams = state.data.dncChakrams || [];
    const traits = state.data.customTraits || [];

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">🧚 Companions &amp; Custom Gear &bull; True Pets &amp; Item Overhauls</div>
        <h1>Custom Companions, Thralls &amp; Equipment</h1>
        <p>
          OverlordsXI introduces <strong>6 deterministic custom pets</strong> across Scholar and Black Mage, repurposes
          <strong>Orphic Egg</strong> for faerie Refresh scaling, unlocks <strong>all Scythes for Necromancer BLM</strong>,
          and overhauls <strong>21 Dancer Chakrams (Lv. 10–75)</strong> for ranged Bladewheel combat.
        </p>
      </section>

      <div class="section-header">
        <h2>🧚 Scholar Faeries &amp; Black Mage Undead Thralls</h2>
        <span class="section-sub">Real server-side pets that scale deterministically to the master's level</span>
      </div>

      <div class="card-grid-2">
        ${comps
          .map(
            (c) => `
          <div class="wiki-card">
            <h3>
              <span>${escapeHtml(c.name)}</span>
              <span class="badge badge-gold">Pet ID: ${escapeHtml(c.petId)}</span>
            </h3>
            <div style="font-size:0.84rem; color:var(--accent-cyan); font-weight:600; margin-bottom:0.65rem;">
              ${escapeHtml(c.job)} &bull; ${escapeHtml(c.unlock)} &bull; Jobs: <code>${escapeHtml(c.jobs)}</code>
            </div>
            <p>${escapeHtml(c.summary)}</p>
            <div style="margin-top:0.75rem;">
              <strong style="font-size:0.8rem; color:var(--text-muted); text-transform:uppercase;">Spells &amp; Signature Actions:</strong>
              <ul class="highlight-list" style="margin-top:0.35rem;">
                ${(c.spells || []).map((s) => `<li>${escapeHtml(s)}</li>`).join('')}
              </ul>
            </div>
            <div style="margin-top:0.85rem; padding-top:0.7rem; border-top:1px solid var(--border-subtle); font-size:0.83rem; color:var(--text-secondary);">
              <strong>Equipment Synergy:</strong> ${escapeHtml(c.specialItem)}
            </div>
          </div>
        `
          )
          .join('')}
      </div>

      <div class="section-header">
        <h2>🪃 Dancer Bladewheel Chakram Progression (Lv. 10–75)</h2>
        <span class="section-sub">All 21 Chakrams are DNC-exclusive and scaled to match Bow + Arrow total damage without using ammo</span>
      </div>

      <div class="wiki-table-wrap">
        <table class="wiki-table">
          <thead>
            <tr>
              <th>Level</th>
              <th>Chakram Name</th>
              <th>Tier</th>
              <th>Base DMG</th>
              <th>Delay</th>
              <th>Custom Modifiers &amp; Notes</th>
            </tr>
          </thead>
          <tbody>
            ${chakrams
              .map(
                (ch) => `
              <tr>
                <td><strong>Lv. ${ch.level}</strong></td>
                <td><strong>${escapeHtml(ch.name)}</strong></td>
                <td><span class="badge badge-cyan">${escapeHtml(ch.tier)}</span></td>
                <td><code>DMG: ${escapeHtml(ch.dmg)}</code></td>
                <td><code>Delay: ${escapeHtml(ch.delay)}</code></td>
                <td>${escapeHtml(ch.stats)}</td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>
      </div>

      <div class="section-header">
        <h2>🎖️ Custom Job Traits Reference (IDs 140–152)</h2>
        <span class="section-sub">Injected dynamically into the in-game Job Traits menu when your Soul Crystal is active</span>
      </div>

      <div class="wiki-table-wrap">
        <table class="wiki-table">
          <thead>
            <tr>
              <th>Trait ID</th>
              <th>Trait Name</th>
              <th>Job &amp; Crystal</th>
              <th>Effect Summary</th>
            </tr>
          </thead>
          <tbody>
            ${traits
              .map(
                (t) => `
              <tr>
                <td><code>#${t.id}</code></td>
                <td><strong>${escapeHtml(t.name)}</strong></td>
                <td><span class="badge badge-gold">${escapeHtml(t.job)} &bull; ${escapeHtml(t.crystal)}</span></td>
                <td>${escapeHtml(t.desc)}</td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>
      </div>
    `;
  }

  // ---------------------------------------------------------------------------
  // PAGE 6: Player Commands, Client Launcher & Ashita v4 Addons
  // ---------------------------------------------------------------------------
  function renderCommandsPage() {
    const cmds = state.data.commands || [];

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">⌨️ Player Commands &amp; Client Addons</div>
        <h1>In-Game Commands, Custom Menus &amp; Launcher</h1>
        <p>
          Every custom system on OverlordsXI can be controlled either through <strong>in-game chat commands / paginated customMenus</strong>
          or through our custom <strong>Ashita v4 UI addons</strong> bundled with <code>OverlordsLauncher.exe</code>.
        </p>
      </section>

      <div class="section-header">
        <h2>💬 Player Chat Commands</h2>
        <span class="section-sub">All commands below require Permission 0 (usable by every player)</span>
      </div>

      <div class="card-grid-2">
        ${cmds
          .map(
            (c) => `
          <div class="wiki-card">
            <h3>
              <code>${escapeHtml(c.command)}</code>
              <span class="badge badge-cyan">Player Command</span>
            </h3>
            <p>${escapeHtml(c.summary)}</p>
            <div style="background:rgba(7,11,20,0.75); border:1px solid var(--border-subtle); border-radius:8px; padding:0.75rem 0.9rem; font-family:var(--font-mono); font-size:0.82rem; color:#7dd3fc;">
              ${(c.usage || []).map((u) => `<div>${escapeHtml(u)}</div>`).join('')}
            </div>
          </div>
        `
          )
          .join('')}
      </div>

      <div class="section-header">
        <h2>🖥️ Client Launcher &amp; Ashita v4 Custom UI Addons</h2>
        <span class="section-sub">Auto-installed by OverlordsLauncher.exe</span>
      </div>

      <div class="card-grid-3">
        <div class="wiki-card">
          <h3><span>Overlords Talents UI</span><code>/talents</code></h3>
          <p>
            Graphical 4-tier Weaponskill Talent Tree window in Ashita v4. Browse all 15 weapon categories across your active spec view,
            click nodes to invest or refund points, unlock WSs at Tier 1, and cycle Skillchains via the <code>0x1FD OXTL</code> binary packet.
          </p>
        </div>

        <div class="wiki-card">
          <h3><span>Crystal Socket UI</span><code>0x11F / 0x1FF</code></h3>
          <p>
            Integrates directly with the Equipment menu and custom binary packets (<code>CRYS</code> / <code>CRYC</code>) plus the silent
            <code>[OXSPEC]</code> protocol so you can inspect and socket Soul Crystals with zero chat spam.
          </p>
        </div>

        <div class="wiki-card">
          <h3><span>Kazenoeye Live Status HUD</span><code>0x1FE OXKE</code></h3>
          <p>
            Powered by <code>kazenoeye_sync.cpp</code>, the server streams authoritative mob and pet status effect icons and exact remaining
            millisecond timers to nearby party members.
          </p>
        </div>
      </div>
    `;
  }

  // ---------------------------------------------------------------------------
  // PAGE 7: Engine Patches & Live GitHub Commit Feed
  // ---------------------------------------------------------------------------
  function renderPatchesPage() {
    const patches = state.data.patches || [];
    const commits = state.liveCommits || state.data.commits || [];

    return `
      <section class="wiki-hero">
        <div class="hero-eyebrow">🔧 Engine Architecture &amp; Live Repository History</div>
        <h1>C++ Engine Patches &amp; Live GitHub Commits</h1>
        <p>
          OverlordsXI keeps its custom logic modular inside <code>modules/custom/</code> paired with <strong>${patches.length} targeted C++ engine patches</strong>.
          This page also displays the latest commits directly from <code>${escapeHtml(state.syncCfg.repo)}</code>.
        </p>
      </section>

      <div class="section-header">
        <h2>🧩 Numbered C++ Engine Patches (${patches.length})</h2>
        <span class="section-sub">Applied automatically by scripts/setup-local-server.ps1</span>
      </div>

      <div class="wiki-table-wrap">
        <table class="wiki-table">
          <thead>
            <tr>
              <th>Patch #</th>
              <th>Patch File</th>
              <th>What It Unlocks / Changes</th>
              <th>Modified Engine Files</th>
            </tr>
          </thead>
          <tbody>
            ${patches
              .map(
                (p) => `
              <tr>
                <td><span class="badge badge-gold">#${escapeHtml(p.number)}</span></td>
                <td><code>${escapeHtml(p.filename)}</code></td>
                <td>${escapeHtml(p.description)}</td>
                <td>
                  ${(p.files || [])
                    .map((f) => `<div style="margin-bottom:2px;"><code>${escapeHtml(f)}</code></div>`)
                    .join('')}
                </td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>
      </div>

      <div class="section-header">
        <h2>📡 Recent GitHub Commits (${commits.length})</h2>
        <span class="section-sub">Synced from ${escapeHtml(state.syncCfg.repo)} (${escapeHtml(state.syncCfg.branch)})</span>
      </div>

      <div class="wiki-table-wrap">
        <table class="wiki-table">
          <thead>
            <tr>
              <th>Commit</th>
              <th>Date</th>
              <th>Summary</th>
              <th>Author</th>
            </tr>
          </thead>
          <tbody>
            ${commits
              .slice(0, 35)
              .map(
                (c) => `
              <tr>
                <td><code>${escapeHtml(c.shortHash)}</code></td>
                <td style="white-space:nowrap; color:var(--text-muted);">${escapeHtml(formatRelativeDate(c.date))}</td>
                <td>
                  <strong>${escapeHtml(c.subject)}</strong>
                  ${
                    c.files && c.files.length > 0
                      ? `<div style="margin-top:4px; font-size:0.76rem; color:var(--text-muted);">
                          ${c.files
                            .slice(0, 4)
                            .map((f) => `<code>${escapeHtml(f.path)}</code>`)
                            .join(' ')}
                          ${c.files.length > 4 ? `+${c.files.length - 4} more` : ''}
                         </div>`
                      : ''
                  }
                </td>
                <td style="color:var(--text-secondary);">${escapeHtml(c.author)}</td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>
      </div>
    `;
  }

  // ---------------------------------------------------------------------------
  // Global Instant Search (Searches Crystals, Abilities, WSs across 5 specs, Companions)
  // ---------------------------------------------------------------------------
  function performGlobalSearch(query) {
    const q = query.trim().toLowerCase();
    if (!q || !state.data) return [];

    const results = [];

    for (const job of state.data.jobSpecs || []) {
      for (const c of job.crystals || []) {
        const hay = `${job.jobKey} ${job.jobName} ${c.name} ${c.role} ${c.description} ${(c.highlights || []).join(' ')}`.toLowerCase();
        if (hay.includes(q)) {
          results.push({
            title: `${job.jobKey}: ${c.name} Crystal`,
            sub: `${c.role} — ${c.description.slice(0, 90)}...`,
            tag: 'Job Crystal',
            action: () => navigateTo('crystals', { jobKey: job.jobKey }),
          });
        }
        for (const ab of c.customAbilities || []) {
          if (`${ab.name} ${ab.desc}`.toLowerCase().includes(q)) {
            results.push({
              title: `${ab.name} (${job.jobKey} ${c.name} JA)`,
              sub: `${ab.cd} CD • ${ab.desc.slice(0, 90)}...`,
              tag: 'Custom JA',
              action: () => navigateTo('crystals', { jobKey: job.jobKey }),
            });
          }
        }
      }
    }

    for (const comp of state.data.companions || []) {
      if (`${comp.name} ${comp.job} ${comp.summary} ${comp.specialItem}`.toLowerCase().includes(q)) {
        results.push({
          title: comp.name,
          sub: `${comp.job} — ${comp.role}`,
          tag: 'Companion',
          action: () => navigateTo('companions'),
        });
      }
    }

    for (const ws of state.data.weaponskills || []) {
      let matchedSpec = null;
      let nodeMatch = null;
      const specTrees = ws.specTrees || { default: ws.nodes || [] };
      for (const [sKey, sNodes] of Object.entries(specTrees)) {
        const hit = (sNodes || []).find((n) => `${n.name} ${n.desc}`.toLowerCase().includes(q));
        if (hit) {
          matchedSpec = sKey;
          nodeMatch = hit;
          break;
        }
      }
      if (
        ws.name.toLowerCase().includes(q) ||
        ws.skillName.toLowerCase().includes(q) ||
        nodeMatch
      ) {
        results.push({
          title: `#${ws.id} ${ws.name} (${ws.skillName})`,
          sub: nodeMatch
            ? `[${matchedSpec}] ${nodeMatch.name} — ${nodeMatch.desc}`
            : `5-Spec 56-pt Talent Tree`,
          tag: 'Weaponskill',
          action: () =>
            navigateTo('talents', {
              skillName: ws.skillName,
              wsId: ws.id,
              wsSpec: matchedSpec && SPEC_VIEW_META.some((s) => s.key === matchedSpec) ? matchedSpec : undefined,
            }),
        });
      }
      if (results.length >= 18) break;
    }

    for (const cmd of state.data.commands || []) {
      if (`${cmd.command} ${cmd.summary}`.toLowerCase().includes(q)) {
        results.push({
          title: cmd.command,
          sub: cmd.summary,
          tag: 'Command',
          action: () => navigateTo('commands'),
        });
      }
    }

    return results.slice(0, 12);
  }

  function setupGlobalListeners() {
    document.querySelectorAll('.nav-item[data-page]').forEach((btn) => {
      btn.addEventListener('click', () => {
        navigateTo(btn.getAttribute('data-page'));
      });
    });

    const brandBtn = document.getElementById('brandHomeBtn');
    if (brandBtn) {
      brandBtn.addEventListener('click', () => navigateTo('overview'));
    }

    const syncPill = document.getElementById('syncStatusPill');
    if (syncPill) {
      syncPill.addEventListener('click', () => syncFromGitHub());
    }

    const searchInput = document.getElementById('globalSearchInput');
    const dropdown = document.getElementById('searchResultsDropdown');

    if (searchInput && dropdown) {
      searchInput.addEventListener('input', () => {
        const q = searchInput.value;
        const hits = performGlobalSearch(q);
        if (!q.trim() || hits.length === 0) {
          dropdown.classList.add('hidden');
          dropdown.innerHTML = '';
          return;
        }
        dropdown.innerHTML = hits
          .map(
            (h, idx) => `
          <div class="search-result-item" data-hit-idx="${idx}">
            <div>
              <div class="search-result-title">${escapeHtml(h.title)}</div>
              <div class="search-result-sub">${escapeHtml(h.sub)}</div>
            </div>
            <span class="search-result-tag">${escapeHtml(h.tag)}</span>
          </div>
        `
          )
          .join('');
        dropdown.classList.remove('hidden');

        dropdown.querySelectorAll('[data-hit-idx]').forEach((item) => {
          item.addEventListener('click', () => {
            const idx = Number(item.getAttribute('data-hit-idx'));
            dropdown.classList.add('hidden');
            searchInput.value = '';
            if (hits[idx] && hits[idx].action) hits[idx].action();
          });
        });
      });

      document.addEventListener('click', (e) => {
        if (!e.target.closest('.topbar-search')) {
          dropdown.classList.add('hidden');
        }
      });

      document.addEventListener('keydown', (e) => {
        if (e.key === '/' && document.activeElement !== searchInput && !['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) {
          e.preventDefault();
          searchInput.focus();
        } else if (e.key === 'Escape') {
          dropdown.classList.add('hidden');
        }
      });
    }

    const modal = document.getElementById('syncConfigModal');
    const openBtn = document.getElementById('openSyncConfigBtn');
    const closeBtn = document.getElementById('closeSyncConfigBtn');
    const saveBtn = document.getElementById('saveSyncConfigBtn');
    const resetBtn = document.getElementById('resetSyncConfigBtn');

    const repoIn = document.getElementById('cfgRepoInput');
    const branchIn = document.getElementById('cfgBranchInput');
    const urlIn = document.getElementById('cfgDataUrlInput');
    const tokenIn = document.getElementById('cfgTokenInput');

    if (openBtn && modal) {
      openBtn.addEventListener('click', () => {
        repoIn.value = state.syncCfg.repo;
        branchIn.value = state.syncCfg.branch;
        urlIn.value = state.syncCfg.customDataUrl;
        tokenIn.value = state.syncCfg.token;
        modal.classList.remove('hidden');
      });
    }
    if (closeBtn && modal) {
      closeBtn.addEventListener('click', () => modal.classList.add('hidden'));
    }
    if (saveBtn && modal) {
      saveBtn.addEventListener('click', () => {
        saveSyncConfig({
          repo: repoIn.value.trim() || DEFAULT_CFG.repo,
          branch: branchIn.value.trim() || DEFAULT_CFG.branch,
          customDataUrl: urlIn.value.trim(),
          token: tokenIn.value.trim(),
        });
        modal.classList.add('hidden');
        syncFromGitHub();
      });
    }
    if (resetBtn && modal) {
      resetBtn.addEventListener('click', () => {
        saveSyncConfig(DEFAULT_CFG);
        modal.classList.add('hidden');
        syncFromGitHub();
      });
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    setupGlobalListeners();
    updateSidebarMeta();
    renderCurrentPage();
    syncFromGitHub();
  });
})();
