-- OverlordsXI Scholar spec data.

-- Addendum: White is already level 10 upstream, but keep both explicit for this ruleset.
UPDATE `abilities`
SET `level` = 10
WHERE `name` IN ('addendum_white', 'addendum_black');
