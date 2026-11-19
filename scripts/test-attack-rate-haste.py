#!/usr/bin/env python3
"""Deterministic balance regression checks for the OX haste foundation.

Run: python scripts/test-attack-rate-haste.py
These tests mirror the formulas in patches/0044 and mnk_specs.lua; they do
not replace compiling xi_map and testing real attack packets.
"""
import math


def melee(gear, other):
    gear_rate = 1 + 1.5 * gear if gear >= 0 else 1 / (1 - 1.5 * gear)
    other_rate = (1 + (5 / 3) * other / (1 + other)) if other >= 0 else 1 / (1 - other)
    return gear_rate * other_rate


def ranged(gear, other, snapshot_rate=1.0):
    gear_rate = 1 + 1.5 * gear if gear >= 0 else 1 / (1 - 1.5 * gear)
    other_rate = 1 + other / (1 + other) if other >= 0 else 1 / (1 - other)
    return (10 / 9) * gear_rate * other_rate * snapshot_rate


def check():
    # 15% innate + 10% ability, now zero gear haste: original 25% delay reduction.
    assert math.isclose(melee(0, .25), 4 / 3, rel_tol=1e-10)
    assert math.isclose(ranged(0, .25), 4 / 3, rel_tol=1e-10)
    # Ordinary old-era haste pieces must retain meaningful value.
    assert math.isclose(melee(.05, .25) / melee(0, .25), 1.075)
    assert math.isclose(melee(.20, .25) / melee(0, .25), 1.30)
    # No wasted categories, even well beyond FFXI's traditional caps.
    for other in (.25, .5, 1, 2, 5):
        for gear in (0, .05, .25, .5, 1):
            assert melee(gear + .01, other) > melee(gear, other)
            assert melee(gear, other + .01) > melee(gear, other)
            assert ranged(gear + .01, other) > ranged(gear, other)
            assert ranged(gear, other + .01) > ranged(gear, other)
    # Snapshot and gear haste must multiply, not consume one another's value.
    assert math.isclose(ranged(.25, .5, 1.3) / ranged(.25, .5), 1.3)
    # Negative haste (Slow) must remain finite and actually slow attack rounds.
    for negative in (-.1, -.5, -1, -2):
        assert 0 < melee(0, negative) < melee(0, 0)
        assert 0 < melee(negative, 0) < melee(0, 0)
    # Character baseline is faster than the original unmodified attack cadence.
    assert melee(0, .25) > 1
    print("PASS: baseline, gear upgrades, uncapped stacking, Snapshot, Slow")


if __name__ == "__main__":
    check()
