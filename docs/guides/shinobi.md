# Shinobi (NIN) — Shadow Clone Management Guide

**Soul:** Shinobi · Ninja branch 1 · Pure DPS · unlock level 10 · OverlordsXI level cap 75  
**Legacy internal key:** `kurogane` (retained for saved Soul data and existing scripts)  
**Selection:** `!spec set shinobi` or the existing `!spec set kurogane` command

## What is Shinobi?

**Shinobi is all about managing your shadow clones.** Instead of relying on defensive Utsusemi shadows, this Soul builds a small squad of real, fragile Ninja copies that fight alongside you. Your job is to **create, maintain, replace, and command** those clones while keeping up your own Katana damage.

A Shinobi who summons five shadows and ignores them is missing the point: the best damage comes from timing replacements around enemy attacks and activating clone abilities when enough copies are still alive.

**Shinobi is not a tank or pet-support Soul.** Clones do not intercept attacks for the Ninja, grant defensive buffs, heal, or hold enemy hate. Boss spikes and AoE attacks can destroy them.

## The shadow-management gameplay loop

1. **Build your squad.** Under the planned production Utsusemi override, Ichi summons **2** offensive shadows and Ni summons **3**. You can control at most **5** at once.
2. **Maintain pressure.** Keep attacking with Katana while the shadows independently attack your engaged target. Their staggered attacks are part of your total damage.
3. **Watch your count and timing.** Shadows expire after **25–30 seconds**, and dangerous bosses can kill them earlier. Don't waste a summon just before a known AoE.
4. **Recover intelligently.** When shadows die or time out, use the appropriate Utsusemi cast to rebuild your squad. Summons at cap must safely replace the oldest clones; a failed replacement must not remove a healthy one.
5. **Command a full squad.** Use **Shadow Legion** for a coordinated single-target strike from the shadows that are alive, or **Phantom Assault** for a short window of faster shadow autoattacks.
6. **Read the encounter.** Against OverlordsXI's harder level-75 bosses, saving a summon until *after* a heavy AoE can be more valuable than filling the squad immediately.

The core skill is **shadow uptime and timing**, not a separate resource meter. Your strongest moments come from keeping several copies alive and directing them at the right time.

## Signature abilities — planned production behavior

| Ability | Effect | Recast |
| --- | --- | --- |
| Utsusemi: Ichi | Create 2 offensive shadows against your engaged target; no defensive images for Shinobi | Existing spell recast |
| Utsusemi: Ni | Create 3 offensive shadows against your engaged target; maximum of 5 total | Existing spell recast |
| **Shadow Legion** | All surviving shadows perform one coordinated single-target burst; does **not** summon more clones | 90 seconds |
| **Phantom Assault** | Existing shadows attack faster for 8 seconds; no new clones or defensive benefit | 30 seconds |

**Shadow Legion and Phantom Assault require surviving shadows.** Your choices about when to summon and how to keep clones attacking directly determine the value of these JAs. Both JAs are intentionally different from Kagemusha's defensive Ninja abilities.

## Current tested clone-engine baseline

The existing **GM-only test backend** can summon up to five native-MOB clones with copied player appearance, independent melee engagement and owner damage attribution.

| Mechanic | Current test setting |
| --- | --- |
| Level limit | Server cap 75 |
| Active shadows | At most 5 |
| Clone lifespan | 25–30 seconds, unless killed sooner |
| Clone HP | `clamp(20 + 2 × Ninja level, 40, 170)` |
| Clone target | Only the Ninja's engaged enemy |
| Shadow durability | Can survive minor spikes, but direct hits and boss AoE remain dangerous |
| Threat and rewards | Clones are not tanks; owner receives attack/claim credit through the tested native bridge |

**Important implementation status:** The GM test clone engine exists. The Utsusemi spell override, player-accessible Shadow Legion and Phantom Assault JAs, client DAT entries, and final clone damage tuning **are not yet live**. Do not mistake the intended production gameplay for implemented functionality.

## Gear and passives

- **Weapon:** Katana. Maintain your own accuracy, attack, STR/DEX and weapon-skill damage while coordinating the squad.
- **Passives at levels 10 / 30 / 50 / 70+:** +10/16/22/28 STR and DEX; +15/25/35/50 Katana skill; +8/12/16/20% Attack; +5/8/12/16% WS damage; +5/8/11/14 Double Attack; +5/10/15/20 Store TP; -20/-25/-30/-40 Enmity.
- **Distinct from Kagemusha:** Shinobi sacrifices defensive Utsusemi for offensive shadow management. Kagemusha retains its existing tank-oriented abilities and mechanics.

## GM-only engine testing

Until the production JAs and DAT entries are implemented, a permission-4 tester can engage a disposable enemy and run:

```text
!kurogane enable
!kurogane combat on
!kurogane spawn 3
!kurogane status
!kurogane dismiss
!kurogane disable
```

These **legacy internal command names** remain unchanged deliberately to avoid breaking scripts and test workflows.

For engine diagnostics, boss AoE testing and cleanup checks, read [Shinobi shadow clone engine (legacy Kurogane filename)](../kurogane-shadow-clones.md). For the build and client-work implementation contract, read [Shinobi production ability specification](kurogane-production-abilities.md).

## Practical tips

- A squad of **three live shadows** may be better than a full squad that dies immediately to a telegraphed attack.
- **Rebuild after AoE**, not automatically before it.
- Use **Shadow Legion** when the squad is healthy and your target is stable.
- Use **Phantom Assault** when several existing shadows have enough time left to benefit from its eight-second duration.
- Keep attacking; the Ninja is always an active source of damage, never just a spectator commanding pets.
