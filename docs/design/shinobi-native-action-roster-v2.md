# Shinobi Native Soul Action Roster 2.0 — DESIGN SPECIFICATION

Status: DESIGN PROPOSAL, NOT IMPLEMENTED. Scope: server Soul `kurogane`, native display Soul `shinobi`, NIN, Tier 1 pure DPS, level cap 75. This document does not assert a game/client test.

## Verified baseline on main (19 Nov 2026)
- `modules/custom/lua/nin_specs.lua`: Shinobi ID 487 Shadow Legion; ID 488 Phantom Assault; Kagemusha IDs 443 and 444 are reserved; Shinobi Utsusemi spell IDs 338/339 map to spawn 2/3 independent clones.
- `modules/custom/lua/kurogane_clones.lua`: at most 5 clones, independently engaged melee, owner attribution, 25–30s lifespan, low durability, attack-speed support.
- Launcher `addons/ashita4/overlords_soul_actions/data/soul_actions.tsv`: native Shadow Squadron: Ichi (338) and Ni (339) definitions; `visibility.tsv` uses effective-level unlocks 10 and 37.
- The launcher and server have separate client/server action ID conventions. Do not assume their numeric IDs are identical for abilities. Inspect native resource IDs and recast groups before adding records.
- Existing guides that say all production hooks are absent are stale relative to the current server Lua. Validate deployment before calling features live.

## Non-negotiable boundaries
- Pure offense only: no personal mitigation, healing, enemy status effects shared with others, clone tanking, enemy movement control, or partywide damage multipliers.
- All clones remain independent physical attackers and retain owner-only attribution. No recursive actions, extra loot/EXP credit, skillchain disruption, or duplicate damage.
- Soul-specific override only; Kagemusha and all other Souls unaffected. Preserve engine's five-clone cap and rollback behavior.
- HUD is one *current tactical phase*, not three simultaneous cooldown/proc trackers; a compact separate 0–5 living clone counter is permitted.
- Effective-level checks apply on action listing, casts, level sync, and server dispatch. Unmanaged native actions stay unmodified until eligibility is audited.
- Original action packets/recasts/icons stay compatible unless a verified, scoped change is necessary.

## Action roster (UNVERIFIED repurpose candidates marked *)
| Native display name | Type | Source server ID | Proposed minimum effective level | Target | Design |
|---|---|---:|---:|---|---|
| Shadow Squadron: Ichi | Spell | 338 verified | 10 | Self / engaged enemy precondition | Existing 2-clone summon |
| Shadow Squadron: Ni | Spell | 339 verified | 37 (launcher policy; audit server) | Self / engaged enemy precondition | Existing 3-clone summon |
| False Assault* | Spell | 320 Katon: Ichi | 10 | Engaged enemy | Order each participating clone to fake one attack beat; next eligible independent clone hit qualifies for Feint setup; no enemy debuff |
| Mirror Step* | Spell | 323 Hyoton: Ichi | 10 | Engaged enemy | Clone squad alternates strike timing; participating clones retain independent attack timers and normal pathing |
| Crosscut* | Spell | 326 Huton: Ichi | 10 | Engaged enemy | Queue a short bounded, alternating physical strike sequence; no AoE and no immediate duplicate native damage |
| Shadow Pin* | Spell | 329 Doton: Ichi | 30 | Engaged enemy | Squad concentrates attacks on owner's already engaged target, never immobilizes or debuffs it |
| Thunder Relay* | Spell | 332 Raiton: Ichi | 50 | Engaged enemy | A rapid relay of eligible clones' single-hit offensive turns, subject to owner attribution validation |
| Final Mirage* | Spell | 335 Suiton: Ichi | 70 | Engaged enemy | Higher-commitment coordination command that upgrades the personal Cascade payoff without enemy effects |
| Shadow Legion | Ability | 487 verified | 10 (audit server unlock) | Engaged enemy | Preserve existing 90s coordinated strike; can consume Cascade for capped modest owner-only enhancement after tuning |
| Phantom Assault | Ability | 488 verified | 10 (audit server unlock) | Self | Preserve existing 30s cooldown / 8s native delay reduction on currently living clones |

*Candidate source spell IDs 320/323/326/329/332/335 are referenced in the checked-in Ninja script's spell table. They are **not verified as safe client repurpose slots or as unlocked for Shinobi**. Inspect server spell/skill requirements, scroll learning rules, recast group, resources, shared effects, launcher visibility, and other Soul use. No client IDs, cast times, MP, icon IDs or recast groups are invented here.

### Player-facing tactical cycle — proposal
1. **Build Feint:** Two *distinct living clones* land verified, owner-attributed melee hits on the owner's currently engaged target within a six-second sliding window. HUD displays FEINT READY. Each hit counts at most once and does not duplicate damage.
2. **Trigger Feint:** Any successful squad command used while Feint is ready applies its command-specific owner-only bonus. HUD changes to SWITCH READY, retains last successful command family, and starts a 20-second window.
3. **Trigger Switch:** A successful **different** squad command within the window produces its own owner-only bonus and changes HUD to CASCADE READY (20 seconds). Repeating the same family does not advance phase.
4. **Trigger Cascade:** A successful third squad command, different from the immediately preceding command, triggers a bounded, clone-count-scaled coordinated strike and resets phase to BUILD FEINT. If there are no eligible surviving clones at cast resolution, reject without consuming recast/MP and do not advance phase.
5. Phase progress is **personal**, not an effect on the enemy; it cannot alter party members' damage, accuracy, enmity or debuff state. No player autoattack gating and no 'next successful melee attack' Pressure proc. All bonuses are attached to clone command outcomes.
6. A command which fails server validation (wrong Soul, invalid enemy, no squad, wrong level, transition rejected, clone execution failure) cannot consume a phase, charge, MP, TP or recast. Define transactional prechecks + precise action-commit boundaries with tests.
7. Reset phase on death, Soul switch, target change, disengage, level sync removing access, zone/logout, and when all clones expire. If a phase timer expires, return to BUILD FEINT, retaining no hidden pending proc.
8. For balance, owner-only Cascade hit is capped by a per-level budget and tested across Lv10/30/50/75, even-match/+3 boss regimes. Five clones should not break the established collective ~30–40% baseline DPS budget without an explicit measured retune.

## Native identity and presentation
- Display only the custom Soul names in all supported native menus/tooltips/macros. Never show original spell names to the Shinobi where the native resolver supports scoped remapping. No global DAT replacement.
- Two existing 338/339 native resource entries are already populated in launcher TSV. Future spell candidates require both `soul_actions.tsv` and `visibility.tsv` eligibility work; ability 487/488 require **verified client-resource IDs**, not assumed equality with server IDs.
- Keep original server action IDs wherever feasible. Leave original other-Soul spell behavior intact when Soul != `kurogane`.
- Suggested descriptions: False Assault: "Order shadows to create an opening for your next squad tactic." Mirror Step: "Order shadows into an alternating attack pattern." Crosscut: "Command a rapid, coordinated series of shadow strikes." Shadow Pin: "Focus your shadows on your engaged foe." Thunder Relay: "Pass a rapid strike through your active shadows." Final Mirage: "Commit the squad to a finishing coordination pattern."
- Do not invent or change combat-log text paths or icons without verifying supported hooks.

## Server-authoritative HUD state proposal
`soul=shinobi, effectiveLevel, targetId, cloneCount, phase=BUILD|FEINT_READY|SWITCH_READY|CASCADE_READY, phaseExpiresAt, previousCommandFamily, distinctCloneHitIdsWindow, sequenceVersion`.
Render one highlighted phase, expiry indicator when relevant and 0–5 clone count. State must originate on the server; never trust client-generated proc triggers.

## Implementation gates
1. Audit each candidate spell's server ID, canonical client ID, shared recast group, scroll/skill-level acquisition, and conflicts with other Souls; only then settle unlock level, MP/cast/recast cost and icons.
2. Validate native client list filtering, renaming, descriptions, macro resolution for spells and abilities; verify 487/488 client identity separately.
3. Introduce an isolated squad-command dispatcher and authoritative tactical state machine. Prove no duplicate owner attribution and no global enemy effects.
4. Add server tests for exact target, staggered clones, proc ownership, cooldown non-consumption on failure, level-sync, Soul switch, Kagemusha unchanged, AoE/clones dying mid-command, zone and logout.
5. Add launcher mapping and visibility tests. Update manifest and any delivered native assets only after testing.
6. Run real server and in-game Lv10/30/50/75 combat tests; report simulated vs actual separately.
7. Keep `main` unchanged until implementation and release verification are complete. This design branch is a specification, not deployed gameplay.
