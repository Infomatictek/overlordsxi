# Channeler (BLM) — Soul Implementation Report

**CHN · Tier 2 Hybrid Support · Crystal slot BLM 2 · Lv.10–75**  
Select with `!spec set channeler` or Crystal Socket. Confirmed against the canonical roster and HybridSupport role override.

## Combat loop and progression

Use **Conduit Link** just as one party caster prepares an important spell. Spend 8% max MP and hold your own spell and ability actions while their spell starts and resolves. An unused link expires after eight seconds. A stronger pending link can replace a weaker one. A reserved cast takes priority. For the solo Lv.10 loop, a self-link costs no MP and discounts one eligible cast without speeding it up.

| Effective level | Ally cast time reduction | MP discount | Ally range | MP relay on completed allied cast | Max MP / M. Accuracy / Max HP |
|---|---|---|---|---|---|
| 10 | 20% | 15% | 15y | 0% | +8% / +8 / +4% |
| 30 | 25% | 15% | 15y | 5% | +12% / +14 / +6% |
| 50 | 25% | 25% | 20y | 5% | +16% / +22 / +8% |
| 70–75 | 30% | 25% | 20y | 5% | +20% / +30 / +10% |

The relay is based on MP actually spent. Canceling releases the link without a completion relay. Another Channeler, Ancient Magic including Ancient Invocation, instant casts, item casts and spells with no MP cost are excluded from allied links. Staff is the only WS family. Existing TP, talent and attack-speed rules apply. The kit has no pet or AoE support.

## Native actions and HUD

| Action | Internal spell or server/client ability ID | Timing |
|---|---|---|
| Conduit Link | 273 / 785 | Lv.10, 24s recast, one party PC or self |
| Conduit Bolt | 164 | Lv.10, 2s cast, 4s recast, 9 MP, single enemy |
| Aether Tap | 247 | Lv.30, 3s cast, 60s recast, 10 MP, one enemy with MP |

The native casting state reserves the modifier once per eligible spell, including the affordability check and final MP deduction. The HUD shows the setup window, reserved cast and recast. The [player guide](../../guides/channeler.md) and all three action names and descriptions generate in the wiki.

**Launcher commit:** `f46f5c1ea82c40730b16b313886f2a56bd20124f` on `feat/final-25-souls`.

## Verification

- Three focused Channeler tests and 61 local non-loopback tests passed. Cases include self-link, invalid targets, progression, competing links, a reserved cast, cancellation cleanup and per-Soul action identity.
- Strict roster audit found 45 registered and 21 planned. Exact Lua wiki generation and all three Channeler action entries validated. Launcher TSVs and 1,109 manifest entries verified.
- Applied the patch after the preceding Soul overlays on pinned LandSandBoat. Eleven touched or regression-sensitive native C++ files syntax-checked.
- **Manual Verification Required:** With two clients, run Lv.10/30/50/70/75 casts using a healer and damage caster, an ordinary Staff and zero talents. Confirm reduced cast and actual MP costs, exact one-cast reservation, completion relay, cancellation, hold range, competing Channelers, Ancient/instant/item exclusion, Soul/zone cleanup and native HUD/action presentation.
