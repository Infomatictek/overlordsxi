# Shinobi Soul Redesign 2.0 — Audited Baseline and Integration Contract

Status: **AUDITED / DESIGN PROPOSAL / NOT DEPLOYED**. Feature branch only. This is not evidence of completed live balance testing.

## Source-of-truth audit (2026-11-19)

- Server: `modules/custom/lua/nin_specs.lua`, `modules/custom/lua/kurogane_clones.lua`, `modules/custom/sql/nin_specs.sql`, `modules/custom/lua/overlords_job_specs.lua`.
- Launcher: `addons/ashita4/overlords_soul_actions/data/soul_actions.tsv`, `data/visibility.tsv`, `catalog.lua`, `visibility.lua`, `native_actions.lua`.
- Guide: `docs/guides/shinobi.md` currently incorrectly labels some production handlers as only planned. Update only when client/server rollout is verified.
- Canonical player name: Shinobi; persistent key `kurogane`; canonical Ninja branch 1; Tier 1 physical DPS; Lv75 cap.
- Ninja passives at Lv10/30/50/70+: STR/DEX +10/16/22/28, Katana +15/25/35/50, ATTP +8/12/16/20, all-hit WS damage +5/8/12/16, Double Attack +5/8/11/14, Store TP +5/10/15/20, Enmity -20/-25/-30/-40.
- Clone spawning is already hooked into Shinobi's Utsusemi. Ichi=2, Ni=3; hard cap=5; only owner's engaged enemy; transactional spawn replacement; real allied dynamic MOB; appearance and equipment via `lookSource`, validated with `getLookSnapshot`; damage attributed with `attributeDamageTo`.
- Clone lifetime random 25–30 sec. Clone HP `clamp(20 + 2*level,40,170)`. Damage base `max(8,floor(level*0.72+6))`, native physical damage modifier -60, single-hit rules, no autonomous casting/WS, delay random 210–270 engine units. Phantom Assault changes existing clone attack delay to 0.75× for 8 sec. Shadow Legion triggers individual single-target strikes with a 120ms stagger.
- Clone engagement retries capped at three; 250ms owner tick. Clone threat cleared on ATTACK; clone owner and target lifecycle listeners cleanup on disengage, death, despawn, invalid target and Soul change.
- Server bespoke actions: Shadow Legion abilityId **487**, recastId 238, 90 sec, range 12y; Phantom Assault abilityId **488**, recastId 239, 30 sec, self. Both are registered at DB level 255 and dynamically exposed by Soul `extraAbilities` at Lv10+. They have server-side handlers; these are NOT imaginary pending mechanics.
- Existing launcher catalog defines only `shinobi spell 338` and `shinobi spell 339` names and help; visibility unlocks 338@10 and 339@37. Native action integration for 487/488 still requires authoritative resource-ID mapping and a client-visible test. Do not assume DB ability IDs equal Ashita's ability-menu resource IDs. Current launcher documentation states ability ID range 512–2047.
- Existing HUD local vars include `OX_KRG_CLONE_COUNT`, `OX_KRG_NEXT_EXP`, `OX_KRG_PHANTOM_REM`. Do not replace the functioning combat/appearance backend.
- Known design/risk checks: cap-preserving transactional replacement, exact target and party credit, owner death/logout/zone change, interruption, five summoned clones and dynamic entity cap, idle clone AI, spikes/AoE at boss +0/+3/+8, timeouts and level sync. Verify the actual code path, not the old guide's implementation-status statements.

## Stable action design

| Player-facing action | Server mapping | Available at | Cost/recast | Verified server behavior | Native rollout |
| --- | --- | --- | --- | --- | --- |
| Shadow Squadron: Ichi | Ninjutsu spell 338 (Utsusemi: Ichi) | 10 | Preserve authoritative spell cost/recast | Summons 2 offensive clones; no defensive Utsusemi on Shinobi | Name and visibility currently present |
| Shadow Squadron: Ni | Ninjutsu spell 339 (Utsusemi: Ni) | 37 under existing client policy, subject to server access audit | Preserve authoritative spell cost/recast | Summons 3 offensive clones, total cap 5 | Name and visibility currently present |
| Shadow Legion | Server JA 487, recast ID 238; client resource ID unresolved | Currently Soul-registered from 10 | 90 sec | Ordered coordinated strikes from surviving clones at engaged target | Blocked on ID mapping and menu audit |
| Phantom Assault | Server JA 488, recast ID 239; client resource ID unresolved | Currently Soul-registered from 10 | 30 sec | 8 sec 25% shorter native delay for current living clones | Blocked on ID mapping and menu audit |

Native menu descriptions should be based on the verified server behavior; the external action table is the source for display. Do not add native DLL special cases or custom DAT animations.

## Progression and design review

- **Lv10:** Full identity with Ichi and at least one living-clone command. Current server exposes both JAs at this level; keep this unless measured low-level testing indicates overload.
- **Lv30:** More passive effectiveness and better player competence, not extra automatic clone damage. No forced new button.
- **Lv37:** Existing client policy surfaces Ni. Confirm this matches the server granting of spell 339, including spell-list access and level sync, before release.
- **Lv50:** Higher level mastery through squad replacement and timing, no extra pet-tank mitigation.
- **Lv70–75:** Complete offensive stats and independent encounter performance. Strict Lv75 level cap.

## Balance protocol / release gates

Run six encounter styles (physical, magical, AoE, mobile, endurance, burst window), each at levels 10, 30, 50, 75, at even-match and +3; +8 separately as an extreme encounter. Record player damage, each clone's damage, clone uptime and death causes, action uses, damage after full squad loss, boss engagement/targeting, enmity, cooldown and resource consumption, and test gear. Enforce Tier-1 pure DPS: no self-heal, mitigation, tank shadows or guaranteed invulnerability.

Before merge:
1. Confirm native client resource mapping for server ability IDs 487/488 using existing native action code and real Ashita data; record both IDs.
2. Audit authoritative server unlocking for spells 338/339 and abilities across levels and synced levels. Verify Soul swap invisibility and server-denied actions.
3. Write native catalog+visibility entries and tests using mapped IDs; update launcher manifest hashes/sizes via the repository script, not by hand.
4. Correct stale Shinobi guide status and ensure wiki reflects actual live mechanics.
5. Execute automated Lua regressions and native visibility tests; capture output.
6. Run real-world tests, only then consider merges/deployment to `main`. Restart affected server processes **only** through the user's existing RPC interface, after build/sync; verify logs and loaded modules.

## Possible defect requiring regression

`K.executeShadowLegion` estimates and reports delayed hits before those callbacks execute, and its `target:takeDamage` invocation is wrapped in `pcall` without checking success before updating attribution telemetry. Confirm whether callbacks that fail, target dies or leaves, or late clone expirations produce misleading damage totals. Fix atomically with unit tests, never by introducing an extra damage application.

## In-game acceptance checklist

- [ ] Shinobi at Lv10 sees only eligible, correctly named actions.
- [ ] Ichi creates two correctly equipped, engaging clones.
- [ ] Five is a strict cap; failed replacement preserves healthy clones.
- [ ] Ni appears only when actually eligible, including level sync.
- [ ] Commands operate on the exact target without defensive effects.
- [ ] Incidental AoE isn't instant five-clone deletion every encounter; boss hits can kill clones.
- [ ] Clone DPS + player DPS matches Tier-1 total budget.
- [ ] Kagemusha and Nightblade retain their distinct gameplay.
- [ ] Swap, zone, disengage and death clean up safely.
- [ ] HUD and guide agree with measured behavior.
