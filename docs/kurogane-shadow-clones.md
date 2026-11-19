# Kurogane Shadow Clone Engine

Kurogane is the canonical Ninja branch 1 (`KRG`); Kagemusha is branch 2. The
current implementation provides a GM-gated, native-MOB clone engine for repair
and balance testing. It is not yet connected to Utsusemi or exposed as a player
ability.

## Current implementation

`modules/custom/lua/kurogane_clones.lua` creates up to five independent dynamic
MOBs. Each clone:

- snapshots the owner's visible race, face, size, armor and all three weapon
  slots before the entity is inserted into the zone;
- has exactly 1 HP, a separately randomized 6–10 second lifetime, a staggered
  engagement request, native pathing and a native attack timer;
- can engage only the enemy the owner was fighting at summon time;
- makes at most three bounded engagement requests and is reported inactive if
  the native controller never enters an attack state against the exact target;
- is registered on the enemy at zero base enmity so normal enemy AoE selection
  can include it, while any enmity earned by its attacks is immediately removed;
- transfers final-attacker credit, reward claim, damage-derived threat and the
  matching Records of Eminence damage event to the owner after a native hit,
  without applying damage a second time;
- has no drop ID, no independent EXP/reward ownership, no master/pet link, no
  support actions, and no path that can recursively summon clones.

The experimental attack is deliberately single-hit native melee. Double,
triple and quadruple attack are suppressed so the ownership hook can account
for the one result exposed by the Lua action binding. Damage and attack are
heavily reduced while behavior is being validated; these values are safeguards,
not the production Kurogane damage budget.

The owner timer observes state every 250 ms, but it does not issue an unbounded
engagement loop. Each clone also owns its expiry timer, and death/despawn
listeners remove it from the owner's records. Owner death, disengage, target
loss, Soul/job invalidation and explicit dismissal remove the active set. A
fresh login clears stale Lua userdata. Each clone also carries a generic
`dynamicOwnerId`; `patches/0040-kurogane-owner-attribution-cleanup.patch`
despawns matching dynamic entities from `DecreaseZoneCounter` when their owner
zones or logs out, without occupying the engine's single-pet slot. The
clone-owned 6–10 second expiry remains a final backstop. Zone, logout and
reconnect behavior must still be exercised in the target multi-process
deployment.

## Root causes repaired

### Appearance

The old Lua reconstruction used `getEquipmentModelIds()`, which exposes only
head, body, hands, main and sub on this LandSandBoat revision. Legs, feet and
ranged were unavailable, lockstyle and hidden-head state were ignored, and a
post-insertion `setLook()` could not repair an equipped MOB that had already
been sent as invisible.

`patches/0038-kurogane-authoritative-player-look.patch` adds:

- `lookSource = owner` support to dynamic-entity creation. The engine copies
  the authoritative visible `look_t` before zone insertion, including
  lockstyle, hidden-head behavior and all eight equipment slots. Player
  physical size is mapped to the MOB packet's `modelSize`, while the MOB look
  is marked `MODEL_EQUIPPED`.
- `getLookSnapshot()`, which exposes face, race, model size, head, body, hands,
  legs, feet, main, sub and ranged for diagnostics.

Lua compares the owner and clone snapshots after spawn and fails closed on any
mismatch. Changing gear later affects only future summons, by design.

### Native engagement

The previous prototype stunned new clones, placing them in a non-changeable
inactive state, then treated a successful `updateEnmity()` call as proof of
combat. That API can accept a request even when the AI never entered an attack
state.

The repair removes the startup stun, validates spawn offsets against the
navmesh, adds the target to each clone's own enmity container, asks the native
controller to update its target, and verifies both `isEngaged()` and the actual
target ID. Starts and retries are independently jittered and capped at three.
Diagnostics distinguish startup, engaged, inactive and wrong-target clones.

### Ownership and tanking

Unmodified native MOB attacks assign final-attacker state and threat to the
attacking MOB. The clone attack listener now removes clone threat
synchronously and passes the already-dealt single-hit result to the focused
`attributeDamageTo()` engine helper. That helper atomically records the Ninja
as final attacker, transfers reward claim, adds matching damage-derived enmity,
and emits the owner's Records of Eminence damage event. It never applies HP
damage or fires `TAKE_DAMAGE` a second time. This narrow bridge must still be
confirmed with reward, claim, hate and killing-blow tests before production use.

### Registry isolation

The older Kagemusha table carried a raw `id = 1`, although the registry's
canonicalization already resolved its key to branch 2 at runtime. The literal
now says branch 2 as well, matching Kurogane branch 1 and the launcher mapping
without changing Kagemusha behavior. `patches/0039-kurogane-regression-tests.patch`
asserts forward and reverse lookup for both Souls. Kagemusha's Utsusemi, Kage
Bunshin and Smoke Lotus code is otherwise unchanged.

## GM controls and diagnostics

All commands require permission level 4. The enable and combat flags are
process-local and reset when `xi_map` restarts.

| Command | Effect |
| --- | --- |
| `!kurogane enable` | Allows experimental dynamic clone creation. |
| `!kurogane combat on` | Enables native single-hit melee and owner claim/threat transfer. |
| `!kurogane spawn 1` … `!kurogane spawn 5` | Summons against the owner's currently engaged MOB. |
| `!kurogane status` | Reports clone states, appearance matches, target health/identity, attributed hits, engagement attempts, next expiry and last error. |
| `!kurogane dismiss` | Despawns this owner's active clones. |
| `!kurogane combat off` | Disables combat and dismisses every active test clone in this map process. |
| `!kurogane disable` | Disables both experimental gates and dismisses every active test clone in this map process. |

Interpret the important status fields as follows:

- `eng`: native AI is engaged with the exact summoned target;
- `start`: the clone is within its independently staggered startup window;
- `inactive`: no exact native engagement is currently observable;
- `wrong`: the clone's actual target differs from the summoned target;
- `Look n/n`: all authoritative appearance fields matched after insertion;
- `Hits`: attacks for which owner attribution completed;
- `attempts`: total native engagement requests; and
- `Error`: the latest appearance, engagement or attribution failure.

## Exact development-server test procedure

These steps are a test plan, not a record of completed in-game validation.

1. Apply the numbered patches to the matching LandSandBoat checkout, mirror the
   custom modules and init entries, build the map server, and restart `xi_map`.
2. On a permission-4 character, set Ninja level 10 or higher and select
   Kurogane with `!spec set kurogane`.
3. Enter an isolated development zone, engage one disposable MOB, and keep that
   MOB as the character's battle target.
4. Run `!kurogane enable`, `!kurogane combat on`, then
   `!kurogane spawn 3`. Immediately run `!kurogane status`, repeat after two
   seconds, and repeat before the last clone expires.
5. Confirm three visible character models, `Look 3/3`, staggered transitions
   from `start` to `eng`, exact target ID, non-synchronized attack timing and
   independently spaced disappearances within 6–10 seconds. Capture the full
   status line if any clone becomes inactive or wrong-target.
6. Repeat after equipping visibly distinct head, body, hands, legs, feet, main,
   sub and ranged models. Repeat with lockstyle enabled and with head display
   hidden. Existing clones must retain their spawn snapshot; new clones must
   match the new visible look.
7. Use a controlled enemy AoE. Confirm clones have 1 HP, can be hit by the
   normal AoE path and disappear on any positive damage. Confirm they do not
   intercept single-target hate, become the top-hate tank, heal, buff, drop
   items or spawn further clones.
8. On a fresh disposable target, record claim and hate before spawning. Confirm
   clone hits increment `Hits`, the Ninja retains claim/reward ownership,
   killing blows credit the Ninja, and the enemy's threat list does not retain
   a clone. Verify EXP, loot and Records of Eminence behavior explicitly.
9. Run `!kurogane spawn 5`, followed by `!kurogane spawn 3`. Confirm the active
   total never exceeds five and the oldest entities are replaced cleanly.
10. Exercise cleanup separately: `!kurogane dismiss`, combat off, disengage,
    target death, owner death, Soul switch, job change, zone transfer, logout,
    reconnect and map-server restart. Confirm no visible entity, stale count or
    reusable entity ID remains after each case.
11. Select Kagemusha (`!spec set kagemusha`) and confirm its branch resolves to
    ID 2 and its established Utsusemi, Kage Bunshin (443) and Smoke Lotus (444)
    paths still work. The Kurogane command must refuse spawning for Kagemusha.
12. Finish with `!kurogane disable` and inspect the map log for dynamic-entity,
    Lua listener, look-copy, target or despawn errors.

## Known limitations and release gate

- The engine is GM-only and disabled by default. Kurogane Utsusemi still uses
  ordinary Ninja behavior; no spell completion hook currently summons clones.
- Only conservative native melee is implemented. Shuriken, offensive Ninjutsu,
  clone weapon skills, Shadow Legion, Phantom Assault and the final owner-wide
  DPS budget remain future work.
- Owner attribution is intentionally limited to one native melee result. It
  does not yet constitute a general combat-owner field for arbitrary multi-hit,
  ranged, magic, weapon-skill or skillchain events. Only the matching
  single-hit Records of Eminence damage event is bridged.
- Exact appearance, enemy AoE inclusion, navigation, reward ownership and all
  cleanup cases require observation on the deployment's client and map-server
  topology.

Do not enable this feature in production or connect it to Utsusemi until the
build checks and every relevant in-game case above have passed and been
recorded. No unperformed in-game result should be inferred from this document.
