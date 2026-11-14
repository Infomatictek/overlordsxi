-- OverlordsXI: Strip default weaponskill skillchain properties.
-- Players start with zero skillchain properties (so utility WSs do not
-- interrupt chains) and opt into / choose their skillchain properties via
-- each WS talent tree starting at Level 1.

UPDATE `weapon_skills`
SET `primary_sc` = 0,
    `secondary_sc` = 0,
    `tertiary_sc` = 0
WHERE `id` > 0;
