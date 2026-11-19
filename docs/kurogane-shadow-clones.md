# Kurogane (NIN Soul Crystal — Abr: KRG | Tier-1 Pure Damage)

- **Command:** `!spec set kurogane` (Unlocks at Lv. 10)
- **Allowed Weapons (`ALLOWED_SKILLS_BY_SPEC`):** `xi.skill.KATANA`
- **Playstyle Loop:** Utsusemi summons multiple fragile, short-lived copies of the Ninja. Each copy independently selects attacks against its owner's target; the player times recasts around enemy AoE and chooses Katana WS talents that affect the clones' offensive decisions.
- **Passives (Lv10/30/50/70+):**
  - +10/16/22/28 STR and DEX
  - +15/25/35/50 Katana skill
  - +8/12/16/20% Attack, +5/8/12/16% WS Damage
  - +5/8/11/14 Double Attack, +5/10/15/20 Store TP
  - -20/-25/-30/-40 Enmity
  - Tier-1 role scaling: `PHYS_DMG_DEALT = 0`, `MAG_DMG_DEALT = 0`.
  - All values are initial tuning targets, not measured DPS.
- **Unique Mechanics:**
  - **Independent Shadow Clones:** Utsusemi: Ichi creates up to three real NPC clones, Ni creates up to four. Owner-wide normal cap five; replacement at cap replaces the oldest. Each clone's lifetime is 6–10 seconds, HP exactly 1, and offensive stats are snapshotted on spawn, scaled to an owner-wide damage budget.
  - **Independent Decision-Making:** Every clone has a distinct time offset, attack cooldown, and weighted choice between melee, shuriken, offensive Ninjutsu, and occasional WS. Choices and timings are independent, including when two clones pick the same behavior. Clones target only the owner's current valid engaged enemy; no autonomous target acquisition, AoE pulls or independent loot/TP.
  - **AoE Fragility:** Any valid damaging enemy attack, including AoE, can instantly kill a clone. Death/expiry produces smoke. No clone-death buffs, no damage retaliation, no healing, no absorbed player damage. Clone AI cannot spawn more clones.
  - **Clone Damage:** owner + all clones combined calibrated to Tier-1 DPS (~8x tank baseline), under actual boss AoE cadence. Clones do not use default offensive coefficients unscaled; every damage action respects owner-wide clone damage cap. Clone WS do not create uncontrolled skillchains.
  - **JA Enhancements:** Kurogane Utsusemi creates NPC clones rather than `COPY_IMAGE`/defensive shadows. Kagemusha's original Utsusemi and Kage Bunshin remain entirely unchanged.
- **Custom Job Abilities (2), proposed and not active:**
  1. **Shadow Legion** (CD: 90s, Self): Spawns a rapid wave of up to eight clones in staggered batches; active pool is bounded. No defensive effects or group utility.
  2. **Phantom Assault** (CD: 30s, current enemy within 20y): For 5s, surviving clones choose offensive actions more aggressively and with shorter independent decision windows. Does not synchronize their animation or reward deaths.
- **WS Talent Profile (`overlords_ws_spec_profiles.lua`):**
  - `SPEC_META`: `pref = 'dex'`, `role = 'dps'`, `pfx = 'krg'`
  - `STANCE_DEFS`: Innin, Futae, Sange (offensive contexts only)
  - `Col 1 / Col 2 / Col 3 Hooks`: Existing bespoke WS builders currently apply the Kurogane profile. Dedicated clone behavior hooks **not yet implemented**. Proposed future bridges: clone action weighting (Col 1), clone WS action selection (Col 2), cadence/targeting within DPS budget (Col 3).

## Status of this branch

The Soul's additive `spec.registerCrystal` entry (canonical NIN branch 1), Tier-1 passive mods, Katana WS profile, and opt-in **GM-only dynamic entity spawn probe** are implemented. The existing `nin_specs.lua` module is already included in `modules/init.append.txt`, so no second NIN module registration is needed. **The central feature—real independently acting clone NPCs—is not implemented yet.** Do not deploy this branch expecting Utsusemi to produce clones. The existing Kagemusha-only Utsusemi override remains unchanged; Kurogane would currently use ordinary Ninja behavior.

## Clone visibility fix (November 18, 2026)

LandSandBoat requires a complete equipped look **before** `insertDynamicEntity` inserts a MOB into its zone, otherwise it can remain invisible. Kurogane previously supplied the player's numeric `getModelId()` and then called `setLook()` on a MOB; `setLook()` is NPC-only and cannot reconstruct the player look. The test probe now serializes a 20-byte PC appearance using `getRace()`, `getFace()`, and `getEquipmentModelIds()` into the initial `look` field.

**Limitation:** The existing player Lua binding exposes only five equipment appearance fields. Leg/foot visuals currently use basic starter defaults; exact full equipment mirroring still requires extending the engine binding or a C++ helper. The mob's visibility and combat still need in-game confirmation.

Successful test output now includes the first clone's entity ID, status and zone in addition to count. If nothing appears, capture that output immediately after spawning.

## First playable test: GM-only visual clone probe

The server branch now includes `modules/custom/lua/kurogane_clones.lua` and a GM-only `!kurogane` command. This is a **real dynamic-MOB spawn experiment**, not a complete playable DPS Soul. It is disabled by default and never modifies normal Utsusemi.

1. Deploy updated Lua modules/commands to a development LandSandBoat checkout and restart `xi_map`.
2. Use a GM character (permission 4+), set NIN Lv10+, and enter `!spec set kurogane`.
3. Engage and select a disposable test mob in an isolated zone.
4. Enter `!kurogane enable`, then `!kurogane spawn 3`.
5. Inspect whether copies appear, look like the player, have exactly 1 HP, and disappear independently after 6–10 seconds. Use `!kurogane status` to verify counts and earliest expiration; `!kurogane dismiss` to clean up.
6. **Optional, isolated-zone GM-only melee test:** On a disposable target, use `!kurogane combat on` and then `!kurogane spawn 3`. Observe whether the server's native allied-MOB AI actually engages the selected monster with staggered starts, and whether the target can attack them. Damage is deliberately reduced, but it is **not owner-attributed and the real effective damage is unverified**. Stop with `!kurogane combat off`.
7. Test target loss, zoning, Soul switch, repeated summons, and boss AoE in a safe environment. End with `!kurogane disable`.
8. **Do not test in a populated zone.** Native dynamic MOB faction/AoE behavior, character-model look serialization and despawn lifecycle are unverified on the target LSB build.

By default, combat is OFF: the initial probe is visual-only. The separate `combat on` switch makes clones request **native melee combat** using `updateEnmity` on the owner's current selected enemy. Native mob AI may attack without owner kill/EXP credit, and there are no scripted Ninjutsu or WS attacks yet. `PHYS_DMG_DEALT` and Attack penalties are test safeguards, **not an authoritative damage cap**. Confirm behavior in isolation before expanding the feature. Do not enable this probe on production.

## Engine integration requirements (must be completed before release)

1. Add a server-managed multi-entity clone system; LandSandBoat's normal single-pet slot is unsuitable for 3–8 simultaneous copies.
2. Replicate the owner's character look and equipped weapons in spawned clones, with a unique owner association, full defensive vulnerability and exactly 1 HP. Restrict clone target acquisition to the owner's engaged enemy.
3. Hook Kurogane-only Utsusemi completion *before* vanilla `COPY_IMAGE` effect application. On success, spawn Ichi/Ni copies **without** granting the owner any protective Utsusemi shadow effect. Preserve Kagemusha-specific spell overrides untouched.
4. Implement independent clone schedules (staggered jitter/weighted choices) in the real entity combat system; implement safe owner-attributed damage and prevention of recursive triggers/skillchain side effects.
5. Implement immediate cleanup on expiry, death, owner death, zoning, logout, unsocket, job/level changes, despawn and server reset. Repeated casting must respect the per-owner cap.
6. Define and register two new NIN custom JA IDs/recasts in SQL and client ability data; **do not reuse 443/444**, which belong to Kagemusha.
7. Implement Kurogane WS talent bridge and tests (NPC cap, 1-HP AoE death, targeting, gear snapshot, logout/zone cleanup, Kagemusha nonregression, owner-wide DPS attribution).
8. Optionally expose live clone count/remaining lifetimes through `xi.overlords.hud.registerProvider('kurogane', collectorFn)` once a real backend supplies authoritative values.
9. Run full LSB C++ compilation, Lua integration checks, database migration checks and in-game validation before merging.

This is a development specification and registry scaffold, **not a finished playable clone feature**.
