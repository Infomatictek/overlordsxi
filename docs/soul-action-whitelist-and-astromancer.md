# SoulspireXI — Soul-Approved Spells and Abilities + Astromancer Ancient Magic

**Design decision, 2026-11-19; not implemented.** Reviewed current `modules/custom/lua/soulspire_job_specs.lua` and `patches/0007-spec-ability-unlocks.patch`. They expose `extraAbilities` / `getExtraAbilities` (granting extra actions), **not a demonstrated centralized denylist** for normal job spells and abilities. Never claim this is already enforced.

## Policy: every active Soul owns an explicit action kit
1. **Base job grants are not automatically approved.** On an active Lv10+ Soul, maintain explicit `allowedSpells`, `allowedAbilities`, `allowedWeaponSkills` (if needed), `extraSpells` and `extraAbilities`, plus intentionally approved universal exceptions. Do not reinterpret existing `extraAbilities` (additive) as permission filtering.
2. **Server-authoritative check at execution**, not solely via client menus. Spell checks must cover `CanUseSpell` / equivalent paths including macros and other requests. Ability checks must cover the common execution/unlock paths and handle recast/charges safely. A client-visible curated spell/ability menu is a follow-up, not a security barrier.
3. **No learned-spell deletion.** A Soul switch changes **usability**, not the character's permanently learned spells. On normal level sync/subjob/job change, reevaluate entitlement and refresh visible action tables without stale entries.
4. **Level 10 must be complete.** Each Soul receives every action needed for its elementary loop by Lv10, even if iconic named actions normally unlock later. Implement low-level derivatives where necessary, rather than mass-granting high-level Ancient Magic.
5. **Do not remove basic functions without intent:** e.g. safe job tools, core movement/travel/survival abilities and GM actions should be reviewed as explicit exemptions. No automatic blanket \"all job native spells\" exception.
6. **Avoid softlocking character recovery.** Switching to a Soul with a narrow kit must remain possible; no soul / below Lv10 follows a separately documented vanilla policy. No action should be usable through a non-whitelisted subjob, item script or automation bypass unless intentionally allowed.
7. **Release migration:** audit-only `WARN` mode → compare logs of actual Lv10–75 usage → opt-in block for unimplemented/new Souls → validate known playable Souls one by one. Never flip all 66 Souls to strict blocking in one push.
8. **Soul identity tests:** each new kit must explicitly justify why every ability/spell is present. An allowed spell cannot silently undermine another Soul's signature role.

## Proposed registry shape (DESIGN ONLY)

```lua
-- In the canonical Soul registry (conceptual, no existing implementation):
{
    key = 'astromancer',
    allowedSpells = function(player, level)
        -- Return a set of explicitly authorized learned spells by ID.
        -- Resolve basic elemental + defensive/utility exceptions by level.
    end,
    allowedAbilities = { ... }, -- include ordinary permitted job actions
    extraSpells = { ... },     -- explicit grants/level overrides, if required
    extraAbilities = { ... },  -- still additive, unchanged
    permissionPolicy = 'strict',
}
```

**Evaluation strategy:** Build a cached permissions snapshot whenever Soul, job/subjob, level, sync state or learned spells change. Cache only IDs, level and Soul key; do not store live Entity references. Recheck during execution on the server. Use `allow`/\`deny\` reason codes for telemetry to debug client mismatch. Empty or missing permission data in a strict Soul is an explicit configuration error, not permission to cast everything. Fail safely without stranding the character.

## Astromancer — BLM (DPS), Ancient Magic

### Primary loop
1. **Read the encounter:** identify the right element and choose a safe, meaningful cast window.
2. **Prepare:** use ordinary elemental spells or a dedicated low-level **Ancient Invocation** training spell to establish positioning and maintain participation, *not* a proprietary stack bar.
3. **Commit:** begin an iconic **Ancient Magic** cast with high MP cost, meaningful cast time and clear tells.
4. **Impact / recovery:** one exceptional single-target direct magic strike, then reposition, restore MP and wait for the next favorable window.

### Anti-burst-stacking rule — Astral Saturation
- Record **per-enemy, shared across Astromancers**, whether it has received empowered Ancient Magic recently.
- Initial tuning **candidate**, not measured: 20-second saturation window after the first empowered impact; further Ancient Magic impacts on the same enemy within that interval **lose most of the unique Soul's bonus multiplier**, while normal spells and other Souls' damage remain unchanged.
- Resolve **atomically when the server commits the damaging hit**, not when the player starts casting. Simultaneous impacts must not both gain full bonuses.
- Do not flat-reduce every BLM spell, do not block Sage Helix/Primalist/skillchains/weapon skills, and do not turn a full Astromancer raid into zero damage. The mechanic should reduce *special bonus stacking*, not nullify all follow-up casts.
- Cap special hit damage or handle huge multipliers within the global high-boss-health combat framework to prevent skipping intended boss encounters; evaluate without arbitrarily immunizing every boss.
- A personal Ancient Magic shared-recovery interval (candidate 15–20 seconds) prevents single-character rotational spam; its exact length and hit budget should be adjusted from Lv10 and Lv75 logs.

### Explicit action kit outline (IDs and normal game unlock levels must be verified)
- **Allowed offense:** approved basic elemental spells for filler and element tests, Lv10 **Ancient Invocation** training action with suitable damage and resource costs, named Ancient Magic I and subsequent approved Ancient Magic upgrades at accessible levels, optional select elemental enfeebles if needed for elemental planning.
- **Allowed utility:** only deliberately selected BLM spell tools, including chosen basic self-protection / travel; enumerate before launch.
- **Denied by default:** all unlisted tiered damage spells, other Souls' proprietary spells and unapproved job abilities. Do not remove a fundamental mechanic without a documented substitute.
- **Allowed JAs:** only the subset that reinforces Ancient Magic casting and MP preparedness, rather than broad free instant nuke spam.
- **No pet**, **no sustained Helix engine**, **no routine unrestricted top-tier elemental spam**.

### Why bring Astromancer over Sage?
**Astromancer:** strongest deliberate one-hit elemental commitments during a short boss opening, with its own casting and shared per-target saturation limitations. **Sage:** Titania + Helix + Ebullience-derived steady elemental pressure through enemy movement and long fights. Keep total value competitive at equal encounter difficulty; Astromancer may be uniquely valuable for a single brief magic-damage objective but not strictly dominate general boss DPS.

### Lv10 / Lv30 / Lv50 / Lv70–75 growth
- **10:** low-level Ancient Invocation spell + basic elemental filler. The one-cast/reposition loop works in an ordinary staff.
- **30:** one tactical way to identify/shape elemental alignment; not additional burst stacking.
- **50:** iconic Ancient Magic becomes a higher-impact, high-commitment option; training version remains available if useful.
- **70–75:** empowered Ancient Magic remains single-target and deliberately paced. New spell choices deepen elemental tactics rather than adding unrelated action bars.

### Minimum tests before gameplay merge
- Action whitelist works for spells, JAs, subjobs and macros even with UI tampering.
- Correct action list appears/refreshes on soul set/remove, zone, login, relog, level down and /sync.
- A level-10 Astromancer has enough spells/abilities to participate even without classic Ancient Magic.
- Two simultaneous Ancient Magic hits hit the same boss: exactly one gets the exclusive Astral Saturation bonus.
- A second boss remains unsaturated; other Souls' attacks/spells are unchanged.
- Use weak/normal/high-MEVA bosses; test cast interruptions, elemental resistance, MP economy, resists, party burst phases and damage cap.
- Compare sustained 5–10min encounters with Sage + Titania and focused phase damage with Primalist and Zealot.
- No unintended AoE (very dangerous on SoulspireXI).

## Cross-Soul scope
Action approval profiles should eventually cover **all 66 active Souls**, not just Astromancer. First implement central permission evaluation and auditing, then migrate **new Souls first**, then independently test/convert existing Souls. This prevents accidental deletion of Chi Weaver, Black Belt, Flintlock, Shinobi and other already functional rotations.

**Status:** no new C++ hooks or Lua permission filters have been deployed by this document.
