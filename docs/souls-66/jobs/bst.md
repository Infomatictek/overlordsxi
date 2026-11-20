# BST · Soul specifications

[Untamed](#untamed) · [Alpha Warden](#alpha-warden) · [Beastspeaker](#beastspeaker) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Untamed | Synchronize beast and master | Both can stay on one target and land actual Ready attacks |
| Alpha Warden | Share a master-held hit | The master must hold hate while the beast shares damage |
| Beastspeaker | Read family and expose a damage type | Physical allies can coordinate their swings to an observed weakness |

## Untamed

BST 1 · UNT · Damage · Partially Implemented · [staged implementation](https://github.com/Infomatictek/overlordsxi/blob/a9de23d38a041653bf1dcee565b8b6b688fe2eb4/modules/custom/lua/bst_untamed.lua) · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Fight beside an offensive jug beast on the same target. Land an axe WS to feed its TP, then time the beast's real Ready move to return TP to the master. Either can act first.

**Why choose it.** Choose coordinated master and beast DPS with two meaningful damage sources. Pugilist prepares a frame's WS for a chain. Huntsman defends with a pet and Alpha Warden shares incoming damage. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set untamed` once the Soul is registered. Axe or great axe, offensive jug and obtainable starter beast. Master and pet accuracy before attack.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Call Beast, Bestial Loyalty, Fight, Heel, Stay, Leave, Ready (only offensive moves of the active beast), Reward, Familiar. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Use staged Feral Synchronization: +125 pet TP from qualifying master WS and +75 master TP from real damaging Ready, independent personal 8s ICDs per direction. Temporarily grant starter jug summon, one legal offensive Ready, Fight, Reward and one axe WS. Same living enemy required in both directions. |
| 30–49 | 175 pet / 100 master TP. Keep staged reversible pet offense modifiers. |
| 50–69 | 225 / 125 TP. Pet death or target mismatch denies reciprocal return. Native master and beast attacks still work independently. |
| 70–75 | 275 / 150 TP through 75. Ordinary attacks, canceled Ready, zero-damage/missed moves and wrong targets cannot earn it. No added synthetic hit or immunity. |

**Source or integration decision.** The staged master listener checks pet-target equality. The pet callback checks completion, owner, weapon and ICD, without inspecting the Ready target or damage. Add bilateral target and successful offensive-action checks before spending either ICD. Start with existing staged pet coefficients. At 75 test a 40–60% contribution target for each partner over a stationary single-boss sample; a pet is allowed to die to meaningful mechanics.

**HUD.** Pet target/HP/TP, two eligibility timers. No extra resource meter.. Show server-confirmed events and state only.

**Acceptance fight.** Log master WS and actual pet action in reverse order as well. Dismiss and resummon during ICD and verify no duplicate modifier or recycled entity-ID inheritance. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from monster ecology, jug beasts and Ready commands and its signature decision (“Synchronize beast and master”). This is a setting-inspired hook for later writing.

## Alpha Warden

BST 2 · ALW · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/bst_specs.lua#L1191) · [existing guide](../../guides/alphawarden.md)

**Player decision.** Keep a guardian alive while the master holds the boss. Let Soul-Link split incoming master damage and route pet threat back to the master. Time Soul Bond and Reward before linked damage endangers the beast.

**Why choose it.** Pick a tank that can take the hit itself and share it with a bonded pet. Huntsman wants the boss attacking the pet. Losing the guardian removes Alpha Warden's defining protection. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set alphawarden` once the Soul is registered. One-handed axe and empty sub. HP, pet HP, guard and enmity.

Pinned main WS specialization skills: axe. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | The registered guardian orders and Ready moves of its actual companion; Reward, Snarl, Stay and Heel. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Fight, Heel, Sic, Stay, Reward, Call Beast, Snarl, Ready, Bestial Loyalty, Soul Bond, Feral Roar. |
| Existing traits | Alpha's Soul-Link (166). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Call Beast or Bestial Loyalty, Fight, Reward, Soul Bond and Feral Roar. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| CHR | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +14 / +20 / +26 / +32% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Tank Beast Roster (0 Jugs): Bestial Loyalty (5s CD) cycles Crab / Beetle / Tortoise / Tiger; Call Beast (15s CD, usable in combat) summons @ 100% Master level; Zero-Biscuit Reward (25s CD) heals both 20% + 2 cleanse + 12s Hybrid Regen.
- Always-On 50% Soul-Link & Cure Mirroring: splits 50% Master damage to Pet (pauses <15% HP), funnels 100% Pet melee & Ready enmity to Master, mirrors 60% Cure/Waltz/Regen + 100% overheal to Pet; 1H Axe WSs heal Pet 15-25% + Cripple.
- Tank-Reworked Ready Skills: grant Master +100 TP, heavy enmity, and spec utility (Crab DEF/MDT/Stoneskin/Cripple/Breach; Beetle Guard/Stun/Slow+Expose/Spoil; Tortoise DT+KB-Immune/Stun+Breach/AccDown; Tiger Para+Cripple/PackTP/Heal).
- Soul Bond (35s CD): equalizes Master & Pet HP% (min +15% if within 10%) + 15% Stoneskin; Feral Roar (25s CD): 8y AoE Stun + Slow + threat +1 Ready charge; Familiar: -25% DT, +25% HP & full Ready charges (30s).

**HUD.** Guardian HP, Soul-Link and threat recipient. Show server-confirmed events and state only.

**Acceptance fight.** Verify a master hit splits once and pet threat accrues to the master. Remove or kill pet and verify the master takes the normal hit. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from monster ecology, jug beasts and Ready commands and its signature decision (“Share a master-held hit”). This is a setting-inspired hook for later writing.

## Beastspeaker

BST 3 · BSP · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Read a monster's family and watch its behavior. Send the beast to expose the appropriate physical opening, then call the damage type your melee allies should exploit.

**Why choose it.** Choose physical team coordination against varied monster families. Arcane Archer consumes an elemental mark on one hit; Huntsman issues defensive orders. Beastspeaker pays pet travel time and has limited value without physical allies. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set beastspeaker` once the Soul is registered. Axe, accurate offensive pet and pet survival gear.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Read Quarry, Expose Quarry, Call Beast, Bestial Loyalty, Fight, Heel, Stay, Reward, Leave and active pet's native Ready. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Read Quarry 15y, 10s CD identifies family and current least-resistant of blunt/slashing/piercing; tie priority blunt→slash→pierce. Expose orders engaged pet on same target, 25s CD. On next successful pet melee hit within 6s expose selected type for 8s: +8% matching allied regular physical hits, including master, up to 2 per actor. For unknown family expose +4%. No threat changes. |
| 30–49 | Known-family exposure 10%. Read also reports target's last completed physical or magical ability. |
| 50–69 | Exposure lasts 10s. Permit a manual choice among the three types after Read instead of the default, useful for party composition. |
| 70–75 | Known-family exposure 12%, unknown 6%. Multiple readings never compound; one exposure per enemy. Never applies to WS or skillchain. |

**Source or integration decision.** Pet Read/Expose does not break claim or order the beast to acquire an unengaged add. Non-beast family entries use the same data-driven rules; unknown families take the stated fallback.

**HUD.** Family, selected type, pet delivery deadline and exposure.. Show server-confirmed events and state only.

**Acceptance fight.** Use a non-beast and an unknown-family boss. Compare matching and off-type hits. Keep pet on another target to verify exposure fails. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from monster ecology, jug beasts and Ready commands and its signature decision (“Read family and expose a damage type”). This is a setting-inspired hook for later writing.
