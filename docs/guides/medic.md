# Medic (SCH) — Playstyle Guide

## At a Glance
Medic is a dedicated **Scholar healer** supported by the faerie **Eos**. The specialization combines **Light Arts and Addendum: White**, enhanced Cure/Regen coverage, fast-growing **Sublimation** MP storage and a real companion that can apply additional regeneration and remove ailments. Your job is to maintain steady healing while Eos provides autonomous triage; the faerie is useful support, not a substitute for actively answering dangerous boss damage.

## Setup & Gear
- **Unlock:** Equip the Medic Soul Crystal or use `!spec set medic` from Lv. 10.
- **Companion:** Use **Call Eos** to summon the faerie when allowed by the zone and pet restrictions. A summon cannot begin while you already control another pet.
- **Equipment:** Staff or Club with MND, Healing Magic skill, Cure Potency, Fast Cast and MP support. The **Orphic Egg** in the ammo slot is a useful companion support item when available.
- **Position:** Position yourself to reach injured party members and remain within practical support distance of Eos. Avoid forcing the faerie into encounters where its autonomous casts will repeatedly fail or be interrupted.
- **Recovery planning:** Keep **Sublimation** charging when MP reserves are healthy so stored MP is available during prolonged fights.

## How to Play (Step-by-Step)
1. **Summon Eos:** Use **Call Eos** before a demanding encounter. Check that your companion is active, healthy and able to support the group.
2. **Prepare Light Arts:** Activate **Light Arts** and **Addendum: White** when appropriate. Medic extends Addendum: White's effect duration to **two hours**, reducing the need to repeatedly renew it.
3. **Start Sublimation:** Activate **Sublimation** to accumulate MP. Medic's active Sublimation tick grows the stored reserve at **twice the normal calculated rate** without the usual HP loss.
4. **Heal the party:** Use your available Cure and Regen spells according to injury and expected damage. Medic adapts qualifying radial-Accession Cure and Regen spell handling into **10-yalm radial coverage**, so preserve Stratagem charges where the action is already eligible.
5. **Let Eos triage ailments:** Eos's autonomous behavior can cleanse debuffs and provide additional regeneration. Pay attention to party members Eos cannot reach and fill gaps with your own magic.
6. **Layer regeneration:** Eos's regeneration uses a separate **Eos Regen** status, which can coexist with your normal Regen spell instead of replacing it.
7. **Manage long fights:** Release your stored Sublimation MP when you need it; keep Eos healthy and consider companion MP support in sustained encounters.
8. **Respond to changes:** If Eos is defeated, dismissed, or lost during a Soul change, resummon it when available and adjust your healing priorities until support resumes.

## Key Mechanics & Stacks
- **Eos companion:** A real faerie pet under Medic, with its own HP and MP needs. Call Eos is available from Lv. 10 if pet summoning is allowed and no other pet is active.
- **Eos Regen:** Companion-cast Regen creates a distinct effect that coexists with ordinary Regen; individual Eos Regen ranks scale by spell, recipient maximum HP and their own duration.
- **Regeneration examples:** Eos Regen ranks use at least **10/18/26/36/48 HP** per tick for the five corresponding ranks, plus percentage-of-target-HP scaling.
- **Addendum: White:** Medic extends its status duration to **7,200 seconds**, allowing sustained healer stance use.
- **Sublimation:** Stored MP increases at twice the calculated tick amount; when the storage cap is reached, the completed reserve lasts up to two hours.
- **Cure/Regen radius:** Medic changes qualifying **radial-Accession** Cure/Regen handling into ordinary **10-yalm radial** spells. The full spell-availability and Accession flag behavior should be checked in live play before assuming all Cures automatically become AoE.
- **Companion commands:** Eos can be managed with the available faerie commands, including healer support and dismissal as implemented by the command module.
- **Role boundaries:** Medic prioritizes healing and cleansing over offensive spell damage; preserve enough MP for emergencies.
- **Level progression:** Healing capacity, available Cure/Regen ranks and equipment options improve through Lv. 10, 30, 50 and 75. The faerie can use increasingly potent Regen according to what its spell behavior permits.

## Common Mistakes (Don't Do This)
- **Assuming Eos will heal everything automatically:** Autonomous casting has range, resource and availability limits. Maintain your own healing rotation.
- **Letting Sublimation sit idle during a long fight:** The extra MP recovery is most valuable when proactively charged.
- **Overwriting party Regens unnecessarily:** Eos Regen is separate; coordinate your own Regen ranks with it rather than assuming they are mutually exclusive.
- **Treating the 10-yalm radius as universal for every Cure cast:** The server hook specifically checks eligible radial-Accession Cure/Regen spells; verify the effective behavior in game.
- **Forgetting the companion's MP:** Long encounters can exhaust Eos without appropriate support.
- **Changing Souls without accounting for your pet:** Leaving Medic can dismiss Eos, removing its regeneration and cleanse support.
