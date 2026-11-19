# Untamed (BST) — Playstyle Guide

## At a Glance
**The Feral Predator.** An aggressive Beastmaster and jug beast fight as equal hunters. Both contribute damage through timed, reciprocal actions. Untamed is not a pet commander or a mini tank, and does not build an artificial stack meter. This is a *mechanical interpretation* of Beastmaster's bond with wildlife; a full FFXI lore treatment will follow.

## Setup & Gear
- **Preferred master weapons:** Axe or Great Axe for Feral Synchronization. Good Accuracy, Attack and TP flow on the master; pet offensive performance also matters.
- **Pet:** An offensive jug beast with actual Ready attacks, not a guardian tank.
- **Starting at Lv10:** You should be able to play with normal appropriately leveled weapons. You don't need a rare endgame drop for your loop.

## How to Play (Step-by-Step)
1. Engage the *same target* as your pet. Direct your beast to focus a single enemy; do not scatter aggro.
2. When your pet is attacking the target, use an Axe/Great Axe weapon skill. Feral Synchronization grants the engaged pet a small TP acceleration (once per 8 seconds).
3. Time its actual Ready attack to capitalize on that opportunity. A completed pet Ready attack returns a small amount of TP to the master (once per 8 seconds).
4. Continue coordinating with the beast, rather than saving power for an arbitrary 100-stack finisher. Losing the pet costs substantial offensive value, and pet survival should be handled through sensible positioning and existing Beastmaster maintenance tools.
5. On lethal boss mechanics, protect or reposition your pet rather than expecting Huntsman/Alpha Warden immunity.

## Key Mechanics & Stacks
- **Feral Synchronization:** master weapon skill -> pet offensive opportunity -> pet Ready -> master offensive opportunity.
- **No custom stack meter:** it rewards target alignment and timing, not repeating fillers.
- **No guardian features:** no automatic enmity funnel, no Soul-Link damage sharing, no 100% conal/AoE pet immunity.
- **Weakness:** pet downtime, poor target alignment and mechanics that force disengagement.

## Common Mistakes (Don't Do This)
- Don't tank with Untamed's pet. Huntsman is the Ranger pet-tank commander; Alpha Warden is Beastmaster's Guardian/Soul-Link tank.
- Don't mistake the reciprocal TP reward for free extra weapon-skill hits. The pet performs its *real* Ready action.
- Don't optimize only the master's equipment; the pet needs to contribute meaningful DPS.

> This guide describes the first-pass implementation staged on `feature/bst-untamed-feral-sync`. It requires module-load integration, Lua syntax checks, and Lv10/Lv75 in-game verification before release.
