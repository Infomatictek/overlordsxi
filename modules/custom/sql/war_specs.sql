-- OverlordsXI Warrior spec data.
-- Unlocks Warcry at level 10 on the client ability list so Commander WAR can
-- use it as soon as souls unlock at Lv 10; non-Commander WARs and /WAR subjobs
-- below Lv 35 remain gated in war_specs.lua.

UPDATE `abilities`
SET `level` = 10
WHERE `name` = 'warcry';
