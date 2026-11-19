# Kurogane (NIN branch 1) — Production Ability Specification

Status: **DESIGN APPROVED FOR IMPLEMENTATION; NOT LIVE**. This replaces the earlier proposal for Shadow Legion as an extra clone-wave summoner. Existing native-MOB clone code remains GM-gated until validation.

## Guardrails
- OverlordsXI level cap **75**. Kurogane is a level-10+ Katana pure-DPS Soul, distinct from Kagemusha (NIN branch 2, defensive tank).
- Kurogane can have **at most five real offensive shadow entities**, never five extra Utsusemi defensive images. Shadows should not tank, heal, support, independently acquire targets, or provide defensive buffs.
- Existing tuning baseline: clones live 25–30 seconds, max HP = clamp(20 + 2 x owner's main level, 40, 170), and stay vulnerable to spikes, direct attacks, and enemy AoE. Spikes should not instantly kill a fresh clone; bosses can still kill clones with significant hits.
- Preserve correct player-look snapshot (race, face, lockstyle, hidden head, eight weapon/armor slots), attribution to owner, low clone hate, owner/target cleanup, and five-clone rollback safety.
- No builder/spender meter; no Soul talent tree or WS Evolution edits. Avoid general-purpose utility JAs and unplanned defensive effects. Existing Kagemusha **Kage Bunshin (443)** and **Smoke Lotus (444)** must remain unchanged.

## Clone creation — Utsusemi for Kurogane only
- **Utsusemi: Ichi:** on successful spell completion, summon **two** offensive shadows against the Ninja's current single engaged enemy.
- **Utsusemi: Ni:** on successful spell completion, summon **three** offensive shadows against the same target.
- Both obey **five** active copies total. Combined Ichi and Ni can build up to five; when at cap, refresh the oldest copies safely, with no overshoot and no loss of pre-existing clones on failed allocation.
- Kurogane does **not** gain ordinary defensive Utsusemi images from this override. Keep vanilla spell recasts/MP/item constraints unless the existing implementation mandates a compatible adjustment.
- Do not summon on interrupted/failed casts or when disengaged/invalid target/zone. Do not accidentally invoke ordinary defensive Utsusemi effects. Avoid generic global spell hooks that affect Kagemusha or other Ninjas.
- Keep staggered independent native melee timers and single-target owner attribution. If a production spell-cast hook or claim-safe damage bridge is missing, implement it with limited, testable changes instead of silently faking results.

## JA 1 — Shadow Legion (90-second recast)
**Purpose:** a dramatic coordinated single-target burst, not additional summons.
- Requires **at least one living, active Kurogane shadow**, an engaged Ninja and the exact shared live target. On invalid cast, do not consume the cooldown.
- On activation, all living current shadows perform **one synchronized strike each** at the Ninja's current target, with visual stagger of roughly 0.1–0.2 seconds per copy. Damage is credited exactly once to the Ninja.
- Damage should scale with **1–5 surviving shadows**, but the **combined five-clone strike** should start no higher than approximately **one ordinary Katana weaponskill's damage** in a comparable target/gear test. Do not assume nominal 1-HP test combat damage reflects production tuning.
- Does **not** create, consume, heal, refresh, extend, grant invulnerability to, or reposition shadows.
- No extra skillchain properties, automatic weapon skills, recursive hit events, or AoE damage. Surviving clones resume ordinary attacks.
- If the existing native clone action API cannot safely generate an immediate strike and attribute its damage, use a narrowly scoped server helper with tests. Never apply damage twice.

## JA 2 — Phantom Assault (30-second recast)
**Purpose:** short sustained-pressure window, clearly distinct from Shadow Legion.
- Requires **at least one living Kurogane shadow** and the exact shared live target; invalid cast does not consume cooldown.
- For **8 seconds**, current shadows have **25% shorter native autoattack delay** (not a flat extra attack event). They maintain **independently staggered attack schedules**; do not synchronize their autoattacks.
- Buff applies only to shadows alive when activated; newly summoned replacements during the window use their normal timing. Every affected shadow reverts to its original native delay after the effect or on cleanup. No stacking if recast is manipulated.
- No extra shadows, no shadow refresh, no AoE, no enmity generation beyond existing owner attribution, no damage reduction or mitigation, no direct player buff.
- Respect the actual combat-delay caps and avoid changing the player's own attack-delay system.

## Deployment/data requirements for Antigravity
- Implement two real Ninja Soul-specific JAs, not GM chat commands, on server and Ashita client: legal unused **ability IDs** allocated after searching current server/launcher registries and DAT entries. Preserve 443/444 for Kagemusha.
- Provide ability names/descriptions/recasts/level availability and correct soul-specific visibility; align server ability tables, jobs, action dispatch, Lua/C++ hooks, client DAT/native overrides, launcher assets and manifest SHA-256/size entries.
- Launcher repo: `Infomatictek/overlordsxi-launcher`; server repo: `Infomatictek/overlordsxi`. Both **main** branches are the user's playable test environment. Implement in minimal isolated changes, validate branches first, then merge/push main once checks pass.
- Ensure launcher auto-update actually delivers DAT and addon assets; update manifest after content changes. No Kagemusha behavior changes, no WS Evolution or talent UI edits.
- Keep GM test controls until the production behavior is validated. Do not enable untested server-wide clone creation or call a passing internal look snapshot a client-visible appearance test.
- Document chosen ability IDs, build/restart and in-game test instructions for the 75-cap environment.

## Release tests
1. Level-75 Kurogane can activate each JA and sees correct names/icons/ability timers; non-Kurogane Ninja cannot.
2. Ichi=2, Ni=3, total<=5; no defensive Utsusemi shadows; failed summon at cap preserves preexisting entities.
3. JA 1 uses exactly existing copies, 1–5 hits, one target, owner attribution once, no clone count/lifetime change.
4. JA 2 speeds only living copies for 8 seconds, preserves stagger, restores their normal delay and leaves later summons untouched.
5. Spikes are survivable when small; strong direct hits and boss AoE remain dangerous. Shadows cannot hold permanent top hate, double award rewards, or generate extra skillchains.
6. Character death, target death, disengage, zone, logout, Soul switch and timeout clean up shadows and any temporary attack-delay changes.
7. Client DAT updates display and invoke the actual new abilities; launcher manifest hashes and sizes match files; Kagemusha 443/444 still work.
8. Report exactly which tests ran versus what requires a live client. Do not claim visual or combat validation without an in-game run.
