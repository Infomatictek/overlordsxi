-- ---------------------------------------------------------------------------
-- SoulspireXI — Burrows Reborn: The First Descent (Instance Registration)
-- Idempotent registration of instance 12901 in Ghoyu's Reverie (zone 129).
-- ---------------------------------------------------------------------------

INSERT INTO `instance_list` (
    `instanceid`,
    `instance_name`,
    `instance_zone`,
    `entrance_zone`,
    `overlay_id`,
    `time_limit`,
    `start_x`,
    `start_y`,
    `start_z`,
    `start_rot`,
    `music_day`,
    `music_night`,
    `battlesolo`,
    `battlemulti`
) VALUES (
    12901,
    'the_first_descent',
    129,
    243,
    NULL,
    30,
    458.000,
    0.000,
    416.000,
    192,
    NULL,
    NULL,
    NULL,
    NULL
)
ON DUPLICATE KEY UPDATE
    `instance_name` = VALUES(`instance_name`),
    `instance_zone` = VALUES(`instance_zone`),
    `entrance_zone` = VALUES(`entrance_zone`),
    `overlay_id`    = VALUES(`overlay_id`),
    `time_limit`    = VALUES(`time_limit`),
    `start_x`       = VALUES(`start_x`),
    `start_y`       = VALUES(`start_y`),
    `start_z`       = VALUES(`start_z`),
    `start_rot`     = VALUES(`start_rot`);
