-- OverlordsXI BRD Custom Job Abilities (432-437)
-- Level set to 255 so these abilities stay hidden unless dynamically unlocked
-- at Lv.10+ for each BRD crystal via patch 0007 (extraAbilities).

DELETE FROM `abilities`
WHERE `abilityId` IN (432, 433, 434, 435, 436, 437)
   OR `name` IN (
       'lunge_flourish',
       'troubadours_encore',
       'grand_finale',
       'lyrical_overdrive',
       'dissonant_chord',
       'iron_aria'
   );

-- Adventurer (1): Lunge & Flourish (20s CD, Enemy 4y, recastId 209)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (432, 'lunge_flourish', 10, 255, 4, 20, 209, 110, 0, 126, 1500, 0, 6, 4.0, 0, 0, 1, 60, 0, 0, NULL);

-- Adventurer (1): Troubadour's Encore (45s CD, Self, recastId 210)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (433, 'troubadours_encore', 10, 255, 1, 45, 210, 100, 0, 239, 1800, 0, 6, 0.0, 0, 0, 10, 40, 0, 0, NULL);

-- Musician (2): Grand Finale (20s CD, Enemy 20y, recastId 211)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (434, 'grand_finale', 10, 255, 4, 20, 211, 110, 0, 126, 1600, 0, 6, 20.0, 0, 0, 1, 60, 0, 0, NULL);

-- Musician (2): Lyrical Overdrive (45s CD, Self, recastId 212)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (435, 'lyrical_overdrive', 10, 255, 1, 45, 212, 100, 0, 239, 1800, 0, 6, 0.0, 0, 0, 10, 40, 0, 0, NULL);

-- Minstrel (3): Dissonant Chord (15s CD, Enemy 20y, high enmity snap-taunt, recastId 213)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (436, 'dissonant_chord', 10, 255, 4, 15, 213, 110, 0, 126, 1500, 0, 6, 20.0, 0, 0, 900, 1800, 0, 0, NULL);

-- Minstrel (3): Iron Aria (45s CD, Self, recastId 214)
INSERT INTO `abilities`
    (`abilityId`, `name`, `job`, `level`, `validTarget`, `recastTime`, `recastId`, `message1`, `message2`,
     `animation`, `animationTime`, `castTime`, `actionType`, `range`, `isAOE`, `radius`, `CE`, `VE`,
     `meritModID`, `addType`, `content_tag`)
VALUES
    (437, 'iron_aria', 10, 255, 1, 45, 214, 100, 0, 239, 1800, 0, 6, 0.0, 0, 0, 300, 600, 0, 0, NULL);
