-- OverlordsXI Monk spec data.
-- Unlocks Counterstance at level 10 on the client ability list so Sensei MNK
-- can use Iron Counterstance as soon as souls unlock at Lv 10; non-Sensei MNKs
-- and /MNK subjobs below Lv 45 remain gated in mnk_specs.lua.

UPDATE `abilities`
SET `level` = 10
WHERE `name` = 'counterstance';
