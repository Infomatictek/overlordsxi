# Arcane Archer (RNG) — Playstyle Guide

## At a Glance
Arcane Archer is a Tier 3 **Bow support** Soul that chooses one element and marks a quarry for the party's next matching elemental payoff. **Attunement Arrow** delivers the mark; a matching direct spell or skillchain from an ally can spend it for extra damage. It is a coordination specialization, not a general permanent ranged damage buff. When solo, you can claim a mark yourself with an elemental Bow weapon skill at half strength.

## Setup & Gear
- **Unlock:** Equip the Arcane Archer Soul Crystal or use `!spec set arcanearcher` from Lv. 10.
- **Weapon:** Bring a **Bow and compatible arrows**. Archery is the eligible weapon-skill family and Attunement Arrow requires a landed Bow shot to place its mark.
- **Stats:** Accuracy and Archery skill help land the marking projectile. Magic Accuracy may support related magic interactions, but the core damage reward is determined by the party's correctly matched hit.
- **Plan an element:** Choose Fire, Ice, Wind, Earth, Lightning or Water to match an upcoming allied spell or skillchain before you spend an arrow.
- **Talent independence:** The team-support mark works from Lv. 10 with ordinary gear, any subjob and no weapon-skill talents. Solo self-claims depend on access to a matching elemental Bow weapon skill.

## How to Play (Step-by-Step)
1. **Coordinate the next elemental hit:** Ask your team which direct spell or skillchain it is preparing and choose the same element.
2. **Select your attunement:** Use **Next Attunement** or **Previous Attunement** to cycle through Fire, Ice, Wind, Earth, Lightning and Water. Each selector has a 1-second recast.
3. **Mark the quarry:** Fire **Attunement Arrow** at a living enemy within 20 yalms. A successful Bow hit places your selected elemental mark on that target.
4. **Call the follow-up:** Have an ally from your party land a matching direct elemental spell or skillchain while the mark is live. The first eligible positive-damage result claims the bonus.
5. **Avoid wasted arrows:** A missed Attunement Arrow still consumes one arrow and begins its 16-second recast, without placing or replacing a mark.
6. **Use solo fallback deliberately:** If fighting without another nearby party player, an eligible matching elemental Bow weapon skill can claim your own mark for **half the party bonus**.
7. **Handle target changes:** A new successfully placed mark on another quarry replaces your previous live mark. Recoordinate your team's element and target before the next shot.
8. **Use your HUD:** Track selected element, the current target's mark element and remaining duration, and Attunement Arrow's recast.

## Key Mechanics & Stacks
- **Level 10–29:** Mark lasts **10 seconds**; a party follow-up gains **12% damage**, or **6%** for eligible solo self-claim.
- **Level 30–49:** Mark lasts **12 seconds**; party bonus **15%**, solo half-bonus **7%** after integer rounding.
- **Level 50–69:** Mark lasts **12 seconds**; party bonus **18%**, solo **9%**.
- **Level 70–75:** Mark lasts **14 seconds**; party bonus **20%**, solo **10%**.
- **Attunement Arrow:** A Bow shot on a 16-second recast. Only a landed valid hit marks the enemy; misses still consume ammunition.
- **Element matching:** Fire, Ice, Wind, Earth, Lightning and Water are selectable; the follow-up's actual resolved element must match. For multi-element skillchains, the engine's chosen resulting element matters.
- **Eligible party claims:** A party member's matching direct spell or skillchain that deals positive damage can claim the mark. Periodic damage and unrelated attacks cannot.
- **Solo claim:** The owner can claim their own mark only through a matching elemental Bow weapon skill while solo, at half the normal percentage.
- **Mark ownership:** One active marked enemy per Arcane Archer; an enemy has only its most recent successful mark. Only eligible hits that actually reduce HP spend it.
- **Soul HUD:** Shows the current attunement, marked target element/duration and arrow cooldown.

## Common Mistakes (Don't Do This)
- **Picking an element without talking to the party:** The bonus is lost if the actual allied damage element differs.
- **Assuming a missed arrow marks anyway:** A miss still spends ammunition and cooldown, but leaves no new mark.
- **Treating the mark as a general damage vulnerability:** Only eligible matching elemental direct spells or skillchains can consume the party bonus.
- **Forgetting the solo restriction:** An Arcane Archer's own Bow weapon-skill claim uses a separate half-strength rule when solo.
- **Replacing a mark before the party consumes it:** Each newly landed mark replaces the old one. Wait for the planned follow-up when possible.
- **Ignoring skillchain element resolution:** The server-selected resulting element—not just the player's intended element—determines whether the mark is matched.
