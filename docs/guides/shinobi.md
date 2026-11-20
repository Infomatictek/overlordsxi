# Shinobi (NIN) — Shadow Clone Commander 2.0 Guide

**Soul:** Shinobi · Ninja branch 1 · Tier 1 Pure Physical DPS · unlock level 10 · SoulspireXI level cap 75  
**Legacy internal key:** `kurogane` (retained for saved Soul data and existing scripts)  
**Selection:** `!spec set shinobi` or `!spec set kurogane`

## What is Shinobi?

**Shinobi is a Tier 1 pure physical DPS shadow-clone commander.** Instead of defensive Utsusemi images, Shinobi fields up to **five fragile offensive shadow clones** that copy your appearance and equipment and independently attack your engaged target. You weave Katana autoattacks and weaponskills with **zero-tool Ninjutsu squad commands** and two signature Job Abilities through one cohesive **Feint → Switch → Cascade** tactical cycle.

**Shinobi is not a tank or support Soul.** Clones do not intercept hits for you, grant personal mitigation, heal, hold enemy hate, apply enemy debuffs, or grant party-wide damage bonuses. Heavy boss AoEs and direct hits can kill clones; managing squad uptime and command sequencing is your core skill expression.

## Complete Shinobi Action Kit

All eight Shinobi Ninjutsu spells require **zero Ninja tools** on Shinobi and unlock dynamically at their effective level (level sync enforced server-side and reflected in the native Ninjutsu menu).

| Player-Facing Action | Server Mapping | Unlock Lv | Cast | Recast | Effect |
| --- | --- | --- | --- | --- | --- |
| **Shadow Squadron: Ichi** | Spell 338 (`Utsusemi: Ichi`) | 10 | 1.5s | 20s | Summon **2** offensive shadow clones against your engaged enemy (max 5 active, 25–30s, zero defensive shadows). |
| **False Assault** | Spell 320 (`Katon: Ichi`) | 10 | 0.5s | 12s | Lead clone feint strike + establishes **Opening** on owner for **12s** (+25% potency or +2s duration on your next *different* squad command). No enemy debuff. |
| **Mirror Step** | Spell 323 (`Hyoton: Ichi`) | 10 | 0.5s | 16s | Shifts living clones into an alternating fast/heavy attack rhythm for **10s** (12s w/ Opening), rewarding multiple living clones (+4% melee per extra clone, up to +16% at 5). |
| **Crosscut** | Spell 326 (`Huton: Ichi`) | 10 | 0.5s | 14s | Rapid staggered single-target physical strikes (90ms stagger) from every living clone (bounded total cap, owner-attributed once, no AoE/skillchain). |
| **Shadow Pin** | Spell 329 (`Doton: Ichi`) | 30 | 0.5s | 18s | Locks living clones onto your engaged target for **12s** (14s w/ Opening): refreshes engagement/facing on mobile bosses, extends active tactical phase by +4s (cap 20s), and grants living clones +ACC / +melee damage. No enemy debuff or tank enmity. |
| **Shadow Squadron: Ni** | Spell 339 (`Utsusemi: Ni`) | 37 | 1.2s | 30s | Summons **3** offensive shadow clones against your engaged enemy (max 5 active, transactional replacement of oldest copies). |
| **Thunder Relay** | Spell 332 (`Raiton: Ichi`) | 50 | 0.5s | 22s | High-tempo escalating sequential strikes (60ms cadence) across living clones. Requires **2+ living clones** for the full escalating relay chain (bounded cap, no AoE/extra TP). |
| **Final Mirage** | Spell 335 (`Suiton: Ichi`) | 70 | 1.0s | 45s | High-commitment single-target squad finisher scaling with living clones (1–5) and consuming your active tactical phase (and Opening) for peak capped burst. |
| **Shadow Legion** | JA 487 (Client ID 999, Recast 238) | 10 | Instant | 90s | Every surviving clone launches one staggered (120ms) coordinated physical strike (~1× Katana WS at 5 clones). Integrates with Opening and the tactical cycle. |
| **Phantom Assault** | JA 488 (Client ID 1000, Recast 239) | 10 | Instant | 30s | Accelerates currently living clones by **-25% native autoattack interval** for **8s** while preserving staggered timing. Integrates with the tactical cycle. |

## The Tactical Cycle: Feint → Switch → Cascade

Shinobi tracks **one server-authoritative tactical phase** on your Soul HUD:

1. **Build Feint (`0/2` → `2/2`):** Two **distinct living clones** land real, verified, owner-attributed melee hits on your engaged enemy within **6 seconds** → enters **Feint Ready (20s)**.
2. **Feint Ready (20s):** Any successful squad command activates its effect and advances the phase to **Switch Ready (20s)**.
3. **Switch Ready (20s):** A **different** successful squad command within 20 seconds advances the phase to **Cascade Ready (20s)**. Repeating the same command executes normally but does **not** advance the phase.
4. **Cascade Ready (20s):** A subsequent **different** qualifying squad command triggers a capped **Cascade Coordinated Strike** from surviving clones and resets the cycle to Building. (Casting **Final Mirage** at Lv70 consumes the active phase directly for its amplified finisher and resets the cycle.)

**State reset rules:** Phase progress and tactical buffs reset cleanly on target change, disengagement, owner death, zoning, Soul change, level sync/change, phase timeout, or loss of all living clones. Failed/invalid casts are rejected before consuming cooldowns, tools, or phase progress.

## Level-10 Gameplay Loop

1. Engage your enemy and cast **Shadow Squadron: Ichi** (2 offensive clones).
2. Let two distinct living clones land melee hits within 6 seconds to establish **Feint Ready**.
3. Cast **False Assault** to set your 12s **Opening** and advance to **Switch Ready**.
4. Follow with **Mirror Step** (sustained alternating rhythm) or **Phantom Assault** to consume Opening and advance to **Cascade Ready**.
5. Unleash **Crosscut** (or **Shadow Legion**) to trigger the **Cascade Coordinated Strike** and reset the cycle.
6. Refresh **Shadow Squadron: Ichi** (and **Ni** from Lv37+) as clones expire or fall to boss AoEs, weaving Katana weaponskills throughout.

## Clone Baseline & Survivability

| Property | Live Setting |
| --- | --- |
| Level cap | 75 (effective level enforced under Level Sync) |
| Active clone cap | 5 maximum (transactional staging: failed replacement never deletes existing clones) |
| Clone lifetime | 25–30 seconds independent expiry per clone |
| Clone HP | `clamp(20 + 2 × Ninja level, 40, 170)` (40 HP @ Lv10 → 170 HP @ Lv75) |
| Splash durability | -30% magical splash damage taken (survives minor spikes & 1 incidental AoE; heavy boss AoEs & direct melee hits remain lethal) |
| Threat & attribution | Clones clear native enmity on every hit; owner receives damage, claim, and reward credit via `attributeDamageTo` |

## Gear and Passives

- **Weapon:** Katana (dual wield). Maintain your own accuracy, attack, STR/DEX, haste, and weaponskill damage alongside your squad.
- **Passives (Lv10 / 30 / 50 / 70+):** +10/16/22/28 STR and DEX; +15/25/35/50 Katana skill; +8/12/16/20% Attack; +5/8/12/16% all-hit WS damage; +5/8/11/14 Double Attack; +5/10/15/20 Store TP; -20/-25/-30/-40 Enmity.
- **Distinct from Kagemusha & Nightblade:** Kagemusha (branch 2) remains the defensive shadow tank (Kage Bunshin 443, Smoke Lotus 444, defensive Utsusemi). Nightblade (branch 3) retains its reactive seal support identity.

## Soul HUD & GM Diagnostics

- **Soul HUD (`soulspire_soulhud`):** Displays living clones (`0–5` violet pips), current tactical phase (`BUILD 0/2..1/2`, `FEINT RDY`, `SWITCH RDY (!LAST)`, `CASCADE RDY (!LAST)`, `OPEN`), phase countdown bar (`0–20s`), and next-command readiness.
- **GM Diagnostics (`!kurogane`):** Permission-4 testers can inspect live clone/phase telemetry with `!kurogane status`, `!kurogane look`, `!kurogane spawn [1-5]`, and `!kurogane dismiss`.
