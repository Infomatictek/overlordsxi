LSB-Faerie XIPivot overlay
==========================

This overlay does not replace any live FFXI install files. It contains custom
client text DATs for the LandSandBoat SCH Call Eos ability.

Files:

- ROM/181/72.DAT: ability name table
- ROM/181/74.DAT: ability help text table
- ROM/118/114.DAT: spell/ability metadata table
- ROM/118/108.DAT: weapon/ammo item text table

Changed client-facing ability entry:

- ID 743, a blank unused display slot for server ability ID 231, now shows as Call Eos.
- ID 743 now targets the caster instead of enemies. Its metadata recast is set to
  the client-safe cap for this DAT; the real 5 minute cooldown is enforced by the
  server ability recast.
- Item ID 18256, Orphic Egg, now shows Eos: "Refresh" scales with level.

Server mapping:

- LandSandBoat ability ID 231 is the protocol-safe SCH Call Eos job ability slot.
- The server script for ability 231 summons the custom Eos pet.
- Tabula Rasa is restored to normal behavior and no longer summons the faerie.
- Modus Veritas is restored to normal behavior and remains ability ID 214.

For your current custom DAT loader, copy the contents of this folder into:

C:\DATs\Overlords

If you also want to load it with Windower XIPivot, place this folder under:

C:\Windower\Windower\addons\XIPivot\data\DATS\LSB-Faerie

Then add LSB-Faerie to XIPivot's overlay list or run:

//pivot add LSB-Faerie

For the cleanest result, enable the overlay before launching FFXI.
