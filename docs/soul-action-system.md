# Soul Action System — implementation contract

## Goal
A player sees only the current Soul action identity. Underlying FFXI spell, ability and WS IDs are private implementation details. Different Souls may map the same underlying ID to different identities.

## Current status
- `modules/custom/lua/overlords_soul_actions.lua` is an **opt-in data registry**, not an active enforcement or client remapping hook.
- Existing gameplay remains unchanged until permissions are audited and enforcement is integrated.
- No claim is made that Ashita 4 can rewrite every native menu, macro, combat message or visual effect.

## Registry usage
```lua
local actions = require('modules/custom/lua/overlords_soul_actions')
actions.register('example_soul', {
    spell = {
        [1] = {
            name = 'Example Spell',
            description = 'The Soul-specific effect visible to the player.',
            gameplayProfile = 'example_server_handler',
            effectProfile = 'example_client_visual',
            castTime = 12,
            mpCost = 100,
        },
    },
    ability = {},
    weaponskill = {},
})
assert(actions.isAllowed('example_soul', 'spell', 1))
local visible = actions.presentation('example_soul', 'spell', 1)
```

Spell ID 1 above is only an example; do not treat it as a verified Water mapping.

## Integration gates
1. Audit every canonical Soul and its effective spell/JA/WS access at levels 10, 30, 50, and 75; include subjob, items, equipment, custom JAs and zone/level-sync behavior.
2. Preserve all current actions until audited Soul lists are complete. Treat missing registry definitions as *not configured*, not a reason to deny live actions.
3. Add server-side checks at authoritative cast/JA/WS execution boundaries. Check the active Soul and action ID; deny unlisted actions after the corresponding Soul has opted into enforcement. Test client packets and direct commands, not just menus.
4. Keep gameplay profiles server-side: casting time, recast, costs, target legality, damage, enmity, resist and interruption behavior. Validate that client cast bars agree with server timing.
5. Add a versioned server-to-Ashita identity sync keyed by caster, active Soul, action kind and underlying action ID. Clear stale identity on zoning, logout, job change and Soul change.
6. Test local spell menu, hotbar, macro, native log, cast bar, nearby-player log and visual effect separately. Fall back safely if native UI rewriting is unsupported; do not claim complete replacement until measured.
7. Prototype one Astromancer Water-to-Tsunami identity after confirming actual spell ID and desired balance. Avoid hardcoding illustrative values as live balance.
8. Only then enable per-Soul strict whitelists and begin the complete naming/ability redesign.

## Safety
- No global DAT rename for shared action IDs.
- No implicit inheritance from base jobs once a Soul is opted into strict permissions.
- No client-side authority over damage or access.
- No forced cast/animation packet modifications without two-client tests.
- Main is a playable test environment: ship non-disruptive foundations first.
