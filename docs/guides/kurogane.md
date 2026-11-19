# Kurogane (NIN) — Playstyle Guide

## At a glance

Kurogane is the Ninja branch 1, Tier 1 pure-damage Soul (`KRG`), unlocked at
level 10 with `!spec set kurogane`. Its intended identity is an offensive
shadow-clone Ninja: fragile copies fight the Ninja's current enemy on independent
timers and vanish to damaging AoE. Clones are not defensive Utsusemi images,
tanks, healers or support pets.

The Soul's registry, passive bonuses and Katana weapon-skill profile are active.
A repaired native-MOB clone engine is available only through permission-4 GM
commands for development testing. Utsusemi does not summon these entities yet,
and the clone engine must not be enabled on a production map server.

## Setup and gear

- Allowed weapon-skill weapon: Katana (`xi.skill.KATANA`).
- Suggested priorities: STR, DEX, Katana skill, Attack, Accuracy and weapon-skill
  damage, with offensive Ninjutsu as a secondary option.
- Passive tiers at levels 10/30/50/70+: +10/16/22/28 STR and DEX;
  +15/25/35/50 Katana skill; +8/12/16/20% Attack;
  +5/8/12/16% weapon-skill damage; +5/8/11/14 Double Attack;
  +5/10/15/20 Store TP; and -20/-25/-30/-40 Enmity.
- These are initial tuning values, not a measured clone-inclusive damage budget.

## Intended production loop

1. Engage one enemy and use Kurogane's future Utsusemi override to create
   offensive 1-HP entities instead of protective copy images.
2. Maintain Katana pressure while copies enter native combat on separately
   staggered schedules. They remain locked to the Ninja's engaged target.
3. Time new summons after dangerous enemy AoE: a damaging AoE can remove the
   entire active group, and clone deaths grant no buff or retaliation.
4. Shape future clone choices through offensive talents. Ranged throws,
   Ninjutsu, weapon skills and the proposed Shadow Legion/Phantom Assault
   abilities are not implemented in the current engine probe.

The normal cap is five entities. Current test clones have independent 6–10
second lifetimes. Excess test summons replace the oldest copies. Existing
entities keep the visible equipment snapshot they received when summoned.

## Current GM-only test flow

On a development server, a permission-4 tester can engage a disposable enemy
and run:

```text
!kurogane enable
!kurogane combat on
!kurogane spawn 3
!kurogane status
!kurogane dismiss
!kurogane disable
```

`status` distinguishes engaged, staggered-start, inactive and wrong-target
entities; reports authoritative appearance matches, target state, attribution
hits, request attempts, next expiry and the last error. A successful spawn
message is diagnostic evidence only. Appearance, 1-HP AoE death, native combat,
owner reward/claim attribution and cleanup still require controlled in-game
observation.

The complete development procedure and interpretation of each diagnostic field
are in [Kurogane Shadow Clone Engine](../kurogane-shadow-clones.md).

## Boundaries

- Kurogane is branch 1; Kagemusha is branch 2. Kagemusha's defensive Utsusemi,
  Kage Bunshin and Smoke Lotus paths are separate and must remain unchanged.
- Current experimental entities use conservative single-hit melee only. They
  have no healing, support, independent target acquisition, recursive summon,
  loot or intended EXP path.
- The native engine copies the owner's complete currently visible look at spawn,
  including lockstyle and weapon appearances. Later equipment changes are
  reflected only by later summons.
- The current Utsusemi behavior is ordinary Ninja behavior. Do not describe the
  intended clone loop as live player-facing gameplay until the spell hook,
  balance work and recorded validation are complete.
