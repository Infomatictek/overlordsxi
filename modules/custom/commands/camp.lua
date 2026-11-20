-----------------------------------
-- func: camp
-- desc: Party-size-aware leveling & Lv.75 merit camp warp menu for SoulspireXI.
--       Checks party size (Solo / Duo / Trio) and player level before
--       displaying optimal camps that stay below the +8 IT++ wall.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'sss',
}

local BRACKETS = { 1, 10, 20, 30, 40, 50, 60, 70, 75 }

local MODE_INFO =
{
    solo = { key = 'solo', label = 'Solo', targetNote = 'EM to Tough (+0 to +2)' },
    duo  = { key = 'duo',  label = 'Duo',  targetNote = 'Tough to VT+ (+2 to +4)' },
    trio = { key = 'trio', label = 'Trio', targetNote = 'VT+ to High IT+ (+4 to +7)' },
}

-- Coordinates sourced from LandSandBoat Survival Guides & Home Points (safe arrival spots).
local CAMPS =
{
    [1] =
    {
        solo =
        {
            mobRange = 'Lv.1-3',
            spots =
            {
                { label = 'West Ronfaure (1-4)',      zone = xi.zone.WEST_RONFAURE,     x = -451.40, y = -19.75, z = -218.00, rot = 128, mobs = 'Worms, Rabbits, Sheep, Orcs (Lv.1-4)' },
                { label = 'North Gustaberg (1-4)',    zone = xi.zone.NORTH_GUSTABERG,   x = -581.84, y =  40.00, z =   53.14, rot =  96, mobs = 'Bees, Worms, Lizards, Quadavs (Lv.1-4)' },
                { label = 'West Sarutabaruta (1-4)',  zone = xi.zone.WEST_SARUTABARUTA, x =  -14.75, y = -12.00, z =  315.75, rot =   0, mobs = 'Mandragoras, Rabbits, Bees, Crawlers (Lv.1-4)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.2-5',
            spots =
            {
                { label = 'La Theine Plateau (3-7)',   zone = xi.zone.LA_THEINE_PLATEAU,   x =  774.35, y = 29.00, z = -18.57, rot = 0, mobs = 'Bees, Sheep, Akbaba (Lv.3-7)' },
                { label = 'Konschtat Highlands (3-7)', zone = xi.zone.KONSCHTAT_HIGHLANDS, x = -223.00, y = 71.07, z = 828.00, rot = 0, mobs = 'Lizards, Bees, Sheep (Lv.3-7)' },
                { label = 'Tahrongi Canyon (3-7)',     zone = xi.zone.TAHRONGI_CANYON,     x = -160.00, y = 47.25, z = 647.11, rot = 0, mobs = 'Pygmaioi, Bees, Wild Dhalmel edge (Lv.3-7)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.3-6',
            spots =
            {
                { label = 'Dangruf Wadi (4-8)',         zone = xi.zone.DANGRUF_WADI,         x = -23.16, y =  0.35, z =   0.15, rot = 0, mobs = 'Crabs, Lizards, Goblins (Lv.4-8)' },
                { label = 'Inner Horutoto Ruins (5-9)', zone = xi.zone.INNER_HORUTOTO_RUINS, x = 452.94, y = -8.00, z = 181.07, rot = 0, mobs = 'Bats, Goblins, Slimes (Lv.5-9)' },
                { label = 'Zeruhn Mines (3-7)',         zone = xi.zone.ZERUHN_MINES,         x = -10.05, y =  0.00, z =   5.81, rot = 0, mobs = 'Bats, Worms, Crabs (Lv.3-7)' },
            },
        },
    },

    [10] =
    {
        solo =
        {
            mobRange = 'Lv.10-12',
            spots =
            {
                { label = 'Pashhow Marshlands (10-13)', zone = xi.zone.PASHHOW_MARSHLANDS, x =  466.06, y =  24.00, z = 410.91, rot = 32, mobs = 'Funguars, Crawlers, Flies (Lv.10-13)' },
                { label = 'Buburimu Peninsula (10-13)', zone = xi.zone.BUBURIMU_PENINSULA, x = -485.74, y = -32.00, z =  47.32, rot = 64, mobs = 'Mandragoras, Dhalmel, Crawlers (Lv.10-13)' },
                { label = 'La Theine Plateau (9-13)',   zone = xi.zone.LA_THEINE_PLATEAU,  x =  774.35, y =  29.00, z = -18.57, rot =  0, mobs = 'Funguars, Crabs, Orcs (Lv.9-13)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.12-14',
            spots =
            {
                { label = 'Valkurm Dunes (11-15)',      zone = xi.zone.VALKURM_DUNES,      x =  137.90, y =  -7.50, z =   97.00, rot = 162, mobs = 'Sand Hares, Snippers, Lizards (Lv.11-15)' },
                { label = 'Maze of Shakhrami (11-15)',  zone = xi.zone.MAZE_OF_SHAKHRAMI,  x = -338.99, y = -12.21, z = -179.00, rot =   0, mobs = 'Worms, Bats, Goblins (Lv.11-15)' },
                { label = 'Buburimu Peninsula (12-15)', zone = xi.zone.BUBURIMU_PENINSULA, x = -485.74, y = -32.00, z =   47.32, rot =  64, mobs = 'Crawlers, Goblins, Dhalmel (Lv.12-15)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.14-16',
            spots =
            {
                { label = 'Valkurm Dunes Beach (14-17)', zone = xi.zone.VALKURM_DUNES,  x =  137.90, y =  -7.50, z =   97.00, rot = 162, mobs = 'Pugils, Snippers, Goblins (Lv.14-17)' },
                { label = 'Gusgen Mines (14-18)',        zone = xi.zone.GUSGEN_MINES,   x =   59.91, y = -67.93, z = -267.18, rot =   0, mobs = 'Skeletons, Flies, Ghouls (Lv.14-18)' },
                { label = "Ordelle's Caves (14-18)",     zone = xi.zone.ORDELLES_CAVES, x = -102.91, y =   0.10, z =  632.90, rot =   0, mobs = 'Bats, Beetles, Goblins (Lv.14-18)' },
            },
        },
    },

    [20] =
    {
        solo =
        {
            mobRange = 'Lv.20-22',
            spots =
            {
                { label = 'Qufim Island Entr. (20-23)', zone = xi.zone.QUFIM_ISLAND,       x = -251.98, y = -19.96, z = 298.21, rot = 64, mobs = 'Land Worms, Clippers (Lv.20-23)' },
                { label = 'Buburimu Peninsula (18-22)', zone = xi.zone.BUBURIMU_PENINSULA, x = -485.74, y = -32.00, z =  47.32, rot = 64, mobs = 'Bull Dhalmel, Goblins, Pugils (Lv.18-22)' },
                { label = 'Jugner Forest (19-23)',      zone = xi.zone.JUGNER_FOREST,      x =   62.99, y =   0.00, z = -12.75, rot = 65, mobs = 'Tigers, Beetles, Orcs (Lv.19-23)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.22-24',
            spots =
            {
                { label = 'Qufim Island Pond (21-25)', zone = xi.zone.QUFIM_ISLAND,     x = -212.00, y = -21.00, z =  93.00, rot = 64, mobs = 'Clippers, Pugils, Gigas (Lv.21-25)' },
                { label = 'Korroloka Tunnel (21-25)',  zone = xi.zone.KORROLOKA_TUNNEL, x = -463.82, y = -10.08, z = -22.20, rot =  0, mobs = 'Land Worms, Clippers, Seeker Bats (Lv.21-25)' },
                { label = 'Yuhtunga Jungle (22-25)',   zone = xi.zone.YUHTUNGA_JUNGLE,  x = -239.51, y =   0.00, z = -402.77, rot = 64, mobs = 'Mandragoras, Goblins (Lv.22-25)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.24-26',
            spots =
            {
                { label = 'Qufim Island Tower (24-27)',  zone = xi.zone.QUFIM_ISLAND,          x = -212.00, y = -21.00, z =   93.00, rot =  64, mobs = 'Gigas, Pugils, Night Banshees (Lv.24-27)' },
                { label = 'Yuhtunga Jungle (24-28)',     zone = xi.zone.YUHTUNGA_JUNGLE,       x = -239.51, y =   0.00, z = -402.77, rot =  64, mobs = 'Mandragoras, Goblins, Bees (Lv.24-28)' },
                { label = 'Eastern Altepa Des. (24-28)', zone = xi.zone.EASTERN_ALTEPA_DESERT, x = -258.88, y =   8.60, z = -265.00, rot = 128, mobs = 'Spiders, Beetles, Anticans (Lv.24-28)' },
            },
        },
    },

    [30] =
    {
        solo =
        {
            mobRange = 'Lv.30-32',
            spots =
            {
                { label = 'Yuhtunga Jungle (28-33)',      zone = xi.zone.YUHTUNGA_JUNGLE,       x = -239.51, y = 0.00, z = -402.77, rot =  64, mobs = 'Mandragoras, Crawlers, Sahagin (Lv.28-33)' },
                { label = 'Sauromugue Champaign (29-33)', zone = xi.zone.SAUROMUGUE_CHAMPAIGN,  x =  344.83, y = 6.22, z = -255.30, rot =   0, mobs = 'Sabertooth Tigers, Lizards, Crawlers (Lv.29-33)' },
                { label = 'Eastern Altepa Des. (30-33)',  zone = xi.zone.EASTERN_ALTEPA_DESERT, x = -258.88, y = 8.60, z = -265.00, rot = 128, mobs = 'Anticans, Sand Beetles, Spiders (Lv.30-33)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.32-34',
            spots =
            {
                { label = 'Yhoator Jungle (31-35)',     zone = xi.zone.YHOATOR_JUNGLE,     x =  197.82, y =   0.00, z = -81.82, rot = 160, mobs = 'Mandragoras, Wood Goblins, Lizards (Lv.31-35)' },
                { label = 'Sea Serpent Grotto (32-35)', zone = xi.zone.SEA_SERPENT_GROTTO, x =  223.97, y = -23.71, z = 334.99, rot =   0, mobs = 'Ironshells, Sahagin, Bats (Lv.32-35)' },
                { label = 'Garlaige Citadel (32-36)',   zone = xi.zone.GARLAIGE_CITADEL,   x = -381.75, y =  -6.00, z = 363.50, rot = 128, mobs = 'Siege Bats, Beetles (Lv.32-36)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.34-36',
            spots =
            {
                { label = "Crawler's Nest (33-37)",        zone = xi.zone.CRAWLERS_NEST,         x =  364.00, y =  -32.20, z = -22.03, rot =  64, mobs = 'Worker Crawlers, Maze Makers, Beetles (Lv.33-37)' },
                { label = 'Garlaige Citadel (34-38)',      zone = xi.zone.GARLAIGE_CITADEL,      x = -381.75, y =   -6.00, z = 363.50, rot = 128, mobs = 'Siege/Funnel Bats, Chamber Beetles (Lv.34-38)' },
                { label = "Upper Delkfutt's Twr. (33-37)", zone = xi.zone.UPPER_DELKFUTTS_TOWER, x = -365.00, y = -176.50, z = -36.00, rot =   0, mobs = 'Gigas, Dolls, Bats (Lv.33-37)' },
            },
        },
    },

    [40] =
    {
        solo =
        {
            mobRange = 'Lv.40-42',
            spots =
            {
                { label = 'Western Altepa Des. (39-43)', zone = xi.zone.WESTERN_ALTEPA_DESERT, x = 419.33, y =  -3.12, z =  11.68, rot =  0, mobs = 'Beetles, Dhalmel, Scorpions, Anticans (Lv.39-43)' },
                { label = 'Bibiki Bay (39-43)',          zone = xi.zone.BIBIKI_BAY,            x = 493.72, y =  -3.04, z = 728.05, rot =  0, mobs = 'Efts, Dhalmel, Crabs (Lv.39-43)' },
                { label = "Crawler's Nest (40-43)",      zone = xi.zone.CRAWLERS_NEST,         x = 364.00, y = -32.20, z = -22.03, rot = 64, mobs = 'Soldier Crawlers, Helm Beetles (Lv.40-43)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.42-44',
            spots =
            {
                { label = "Crawler's Nest (41-45)",   zone = xi.zone.CRAWLERS_NEST,    x =  364.00, y = -32.20, z = -22.03, rot =  64, mobs = 'Soldier Crawlers, Exorays, Hornflies (Lv.41-45)' },
                { label = 'Garlaige Citadel (42-45)', zone = xi.zone.GARLAIGE_CITADEL, x = -381.75, y =  -6.00, z = 363.50, rot = 128, mobs = 'Fallen Knights, Bats, Beetles (Lv.42-45)' },
                { label = 'Yhoator Jungle (41-45)',   zone = xi.zone.YHOATOR_JUNGLE,   x =  197.82, y =   0.00, z = -81.82, rot = 160, mobs = 'Goblins, Tonberries, Lizards (Lv.41-45)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.44-46',
            spots =
            {
                { label = 'Quicksand Caves (44-48)',    zone = xi.zone.QUICKSAND_CAVES,        x = -984.00, y =  17.00, z = -289.00, rot =   0, mobs = 'Anticans, Sand Lizards, Helm Beetles (Lv.44-48)' },
                { label = 'Labyrinth of Onzozo (44-48)', zone = xi.zone.LABYRINTH_OF_ONZOZO,   x =  -62.30, y = -20.10, z = -280.69, rot =   0, mobs = 'Cockatrices, Goblins, Manticores (Lv.44-48)' },
                { label = 'Eldieme Necropolis (43-47)', zone = xi.zone.THE_ELDIEME_NECROPOLIS, x =  419.21, y = -52.25, z =  -99.50, rot = 128, mobs = 'Lich, Skeletons, Ghouls, Ghosts (Lv.43-47)' },
            },
        },
    },

    [50] =
    {
        solo =
        {
            mobRange = 'Lv.50-52',
            spots =
            {
                { label = 'Wajaom Woodlands (50-53)', zone = xi.zone.WAJAOM_WOODLANDS, x = -838.97, y = -20.00, z =   99.19, rot =   0, mobs = 'Lesser Colibri, Puks, Marids (Lv.50-53)' },
                { label = 'Cape Teriggan (50-53)',    zone = xi.zone.CAPE_TERIGGAN,    x = -186.67, y =   7.90, z =  -67.00, rot = 128, mobs = 'Robber Crabs, Bunnies, Cockatrices (Lv.50-53)' },
                { label = 'Kuftal Tunnel (50-53)',    zone = xi.zone.KUFTAL_TUNNEL,    x =  -16.84, y = -20.47, z = -237.00, rot =   0, mobs = 'Robber Crabs, Sand Lizards (Lv.50-53)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.52-54',
            spots =
            {
                { label = 'Wajaom Woodlands (52-56)', zone = xi.zone.WAJAOM_WOODLANDS, x = -838.97, y = -20.00, z =   99.19, rot = 0, mobs = 'Lesser Colibri, Leypoint Puks (Lv.52-56)' },
                { label = 'Kuftal Tunnel (52-56)',    zone = xi.zone.KUFTAL_TUNNEL,    x =  -16.84, y = -20.47, z = -237.00, rot = 0, mobs = 'Robber Crabs, Sand Lizards, Spiders (Lv.52-56)' },
                { label = "Fei'Yin (51-55)",          zone = xi.zone.FEIYIN,           x =  243.00, y = -24.00, z =   62.00, rot = 0, mobs = 'Bats, Golems, Dolls, Specters (Lv.51-55)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.54-56',
            spots =
            {
                { label = 'Bhaflau Thickets (54-58)',    zone = xi.zone.BHAFLAU_THICKETS,   x = -98.00, y = -10.00, z = -493.00, rot = 192, mobs = 'Colibri, Spiders, Mamool Ja (Lv.54-58)' },
                { label = 'Aydeewa Subterrane (54-58)',  zone = xi.zone.AYDEEWA_SUBTERRANE, x =   5.00, y =  20.67, z =  -89.98, rot =   0, mobs = 'Chigoes, Puks, Diremites (Lv.54-58)' },
                { label = 'The Boyahda Tree (54-58)',    zone = xi.zone.THE_BOYAHDA_TREE,   x =  88.00, y = -15.00, z = -217.00, rot =   0, mobs = 'Robber Crabs, Bark Spiders (Lv.54-58)' },
            },
        },
    },

    [60] =
    {
        solo =
        {
            mobRange = 'Lv.60-62',
            spots =
            {
                { label = 'The Boyahda Tree (59-63)', zone = xi.zone.THE_BOYAHDA_TREE, x =   88.00, y = -15.00, z = -217.00, rot = 0, mobs = 'Moss Efts, Bark Spiders, Death Caps (Lv.59-63)' },
                { label = 'Cape Teriggan (60-63)',    zone = xi.zone.CAPE_TERIGGAN,    x = -303.00, y =  -8.00, z =  526.00, rot = 0, mobs = 'Velociraptors, Sand Lizards, Goblins (Lv.60-63)' },
                { label = 'Wajaom Woodlands (59-63)', zone = xi.zone.WAJAOM_WOODLANDS, x = -838.97, y = -20.00, z =   99.19, rot = 0, mobs = 'Puks, Lesser Colibri, Marids (Lv.59-63)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.62-64',
            spots =
            {
                { label = 'Caedarva Mire SG (62-65)', zone = xi.zone.CAEDARVA_MIRE,    x = -660.00, y = -13.36, z =  342.78, rot = 0, mobs = 'Jnun, Chigoes, Karakul, Imps (Lv.62-65)' },
                { label = 'The Boyahda Tree (62-66)', zone = xi.zone.THE_BOYAHDA_TREE, x =   88.00, y = -15.00, z = -217.00, rot = 0, mobs = 'Steelshells, Processionaires, Korrigans (Lv.62-66)' },
                { label = 'Bibiki Bay (61-65)',       zone = xi.zone.BIBIKI_BAY,       x =  493.72, y =  -3.04, z =  728.05, rot = 0, mobs = 'Hobgoblins, Dhalmels, Ravens (Lv.61-65)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.64-66',
            spots =
            {
                { label = 'Mount Zhayolm (64-68)',    zone = xi.zone.MOUNT_ZHAYOLM,    x = -540.84, y =  -4.00, z =   70.81, rot =  74, mobs = 'Wamouracampa, Erucas, Trolls (Lv.64-68)' },
                { label = 'Bhaflau Thickets (64-68)', zone = xi.zone.BHAFLAU_THICKETS, x =  -98.00, y = -10.00, z = -493.00, rot = 192, mobs = 'Greater Colibri, Mamool Ja, Puks (Lv.64-68)' },
                { label = "Ru'Aun Gardens (63-67)",   zone = xi.zone.RUAUN_GARDENS,    x =    5.00, y = -42.00, z =  526.00, rot =   0, mobs = 'Flamingos, Weapons, Dolls (Lv.63-67)' },
            },
        },
    },

    [70] =
    {
        solo =
        {
            mobRange = 'Lv.70-72',
            spots =
            {
                { label = 'The Boyahda Tree (69-73)', zone = xi.zone.THE_BOYAHDA_TREE, x =   88.00, y = -15.00, z = -217.00, rot = 0, mobs = 'Mourioche, Elder Goobbues, Crabs (Lv.69-73)' },
                { label = 'Uleguerand Range (69-73)', zone = xi.zone.ULEGUERAND_RANGE, x = -220.00, y =  -1.00, z =  -62.00, rot = 0, mobs = 'Snolls, Buffalo, Tigers (Lv.69-73)' },
                { label = "Ru'Aun Gardens (68-72)",   zone = xi.zone.RUAUN_GARDENS,    x =    5.00, y = -42.00, z =  526.00, rot = 0, mobs = 'Flamingos, Spriggans, Weapons (Lv.68-72)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.72-74',
            spots =
            {
                { label = 'Bhaflau Thickets (71-75)',      zone = xi.zone.BHAFLAU_THICKETS,       x =  -98.00, y = -10.00, z = -493.00, rot = 192, mobs = 'Greater Colibri, Mamool Ja, Puks (Lv.71-75)' },
                { label = "Shrine of Ru'Avitau (71-75)",   zone = xi.zone.THE_SHRINE_OF_RUAVITAU, x =  -13.00, y =  48.00, z =   61.00, rot =   0, mobs = 'Aura Statues, Detectives, Weapons (Lv.71-75)' },
                { label = 'Caedarva Mire Azouph (72-75)',  zone = xi.zone.CAEDARVA_MIRE,          x = -449.00, y =  13.00, z = -497.00, rot =   0, mobs = 'Imps, Marsh Murre, Qutrubs (Lv.72-75)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.74-76',
            spots =
            {
                { label = 'Caedarva Mire Azouph (74-77)', zone = xi.zone.CAEDARVA_MIRE, x = -449.00, y =  13.00, z = -497.00, rot = 0, mobs = 'Imps, Lamiae, Merrow (Lv.74-77)' },
                { label = 'Arrapago Reef (74-78)',        zone = xi.zone.ARRAPAGO_REEF, x =  475.97, y = -15.64, z =  -20.00, rot = 0, mobs = 'Qutrubs, Lamiae, Imps (Lv.74-78)' },
                { label = "Ru'Aun Gardens (74-77)",       zone = xi.zone.RUAUN_GARDENS, x =    5.00, y = -42.00, z =  526.00, rot = 0, mobs = 'Groundskeepers, Weapons, Dolls (Lv.74-77)' },
            },
        },
    },

    [75] =
    {
        solo =
        {
            mobRange = 'Lv.75-77 Merits',
            spots =
            {
                { label = 'Bhaflau Colibri (75-78)',    zone = xi.zone.BHAFLAU_THICKETS,       x =  -98.00, y = -10.00, z = -493.00, rot = 192, mobs = 'Greater Colibri (Lv.75-78) — Fast LP/hr' },
                { label = 'Caedarva Mire (75-77)',      zone = xi.zone.CAEDARVA_MIRE,          x = -449.00, y =  13.00, z = -497.00, rot =   0, mobs = 'Imps, Marsh Murre, Lamia (Lv.75-77)' },
                { label = "Shrine of Ru'Avitau (74-77)", zone = xi.zone.THE_SHRINE_OF_RUAVITAU, x = -13.00, y =  48.00, z =   61.00, rot =   0, mobs = 'Weapons, Dolls, Aura Statues (Lv.74-77)' },
                { label = 'Oldton Movalpolos (73-77)',  zone = xi.zone.OLDTON_MOVALPOLOS,      x = -260.78, y =   8.00, z =  -54.00, rot = 128, mobs = 'Moblins & Bugbears (Lv.73-77)' },
            },
        },
        duo =
        {
            mobRange = 'Lv.77-79 Merits',
            spots =
            {
                { label = 'Bhaflau Mamool/Bird (76-80)', zone = xi.zone.BHAFLAU_THICKETS,   x = -98.00, y = -10.00, z = -493.00, rot = 192, mobs = 'Mamool Ja & Greater Colibri (Lv.76-80)' },
                { label = 'Aydeewa Subterrane (76-80)',  zone = xi.zone.AYDEEWA_SUBTERRANE, x =   5.00, y =  20.67, z =  -89.98, rot =   0, mobs = 'Puks, Diremites, Crawlers (Lv.76-80)' },
                { label = 'Arrapago Reef (76-80)',       zone = xi.zone.ARRAPAGO_REEF,      x = 475.97, y = -15.64, z =  -20.00, rot =   0, mobs = 'Qutrubs, Imps, Merrow (Lv.76-80)' },
                { label = "Al'Taieu Sea (76-80)",        zone = xi.zone.ALTAIEU,            x =   7.00, y =   0.00, z =  709.00, rot = 192, mobs = 'Aern, Phuabo, Xzomit (Lv.76-80)' },
            },
        },
        trio =
        {
            mobRange = 'Lv.79-82 Merits',
            spots =
            {
                { label = 'Mount Zhayolm (78-82)', zone = xi.zone.MOUNT_ZHAYOLM, x = -540.84, y =  -4.00, z =   70.81, rot = 74, mobs = 'Trolls, Wamoura, Dahaks (Lv.78-82) — Watch Lv.83+ IT++ wall' },
                { label = 'Mamook (78-82)',        zone = xi.zone.MAMOOK,        x =  217.16, y = -23.84, z = -103.14, rot =  0, mobs = 'Mamool Ja, Puks, Poroggos (Lv.78-82)' },
                { label = 'Arrapago Reef (79-82)', zone = xi.zone.ARRAPAGO_REEF, x =  475.97, y = -15.64, z =  -20.00, rot =  0, mobs = 'Imps, Lamiae, Merrow (Lv.79-82)' },
                { label = 'Kuftal Tunnel (77-81)', zone = xi.zone.KUFTAL_TUNNEL, x =  -16.84, y = -20.47, z = -237.00, rot =  0, mobs = 'Kuftal Delvers, Crabs, Tigers (Lv.77-81)' },
            },
        },
    },
}

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function delaySendMenu(player, menuBuilder)
    player:timer(50, function(playerArg)
        if playerArg ~= nil then
            playerArg:customMenu(menuBuilder())
        end
    end)
end

-- Checks real PC party size first (and separately counts Trusts for context).
local function detectPartyInfo(player)
    local seen     = {}
    local pcCount  = 0
    local trustCnt = 0

    local pcParty = player.getParty and player:getParty() or nil
    if type(pcParty) == 'table' then
        for _, member in pairs(pcParty) do
            if member ~= nil and member.getID and not seen[member:getID()] then
                seen[member:getID()] = true
                if member.isPC and member:isPC() then
                    pcCount = pcCount + 1
                end
            end
        end
    end

    if pcCount == 0 then
        pcCount = 1
        if player.getID then
            seen[player:getID()] = true
        end
    end

    local withTrusts = player.getPartyWithTrusts and player:getPartyWithTrusts() or nil
    if type(withTrusts) == 'table' then
        for _, member in pairs(withTrusts) do
            if member ~= nil and member.getID and not seen[member:getID()] then
                seen[member:getID()] = true
                if member.isTrust and member:isTrust() then
                    trustCnt = trustCnt + 1
                end
            end
        end
    end

    local mode = 'solo'
    if pcCount == 2 then
        mode = 'duo'
    elseif pcCount >= 3 then
        mode = 'trio'
    end

    return
    {
        pcCount    = pcCount,
        trustCount = trustCnt,
        mode       = mode,
        label      = MODE_INFO[mode].label,
    }
end

local function getRecommendedBracket(level)
    local lvl = tonumber(level) or 1
    if lvl >= 75 then
        return 75
    elseif lvl < 10 then
        return 1
    end
    return math.floor(lvl / 10) * 10
end

local function resolveBracket(raw)
    local num = tonumber(raw)
    if num == nil then
        return nil
    end
    if num >= 75 then
        return 75
    elseif num < 10 then
        return 1
    end
    return math.floor(num / 10) * 10
end

local function resolveMode(raw)
    if raw == nil then
        return nil
    end
    local s = string.lower(tostring(raw))
    if s == 'solo' or s == '1' then
        return 'solo'
    elseif s == 'duo' or s == '2' then
        return 'duo'
    elseif s == 'trio' or s == '3' then
        return 'trio'
    end
    return nil
end

local function isPartyWarpEnabled(player)
    return player:getCharVar('[CampWarp]Party') == 1
end

local function formatPartyTag(partyInfo)
    if partyInfo.trustCount > 0 then
        return string.format('%s (%d PC%s + %d Trust%s)',
            partyInfo.label,
            partyInfo.pcCount,
            partyInfo.pcCount == 1 and '' or 's',
            partyInfo.trustCount,
            partyInfo.trustCount == 1 and '' or 's')
    end
    return string.format('%s (%d PC%s)',
        partyInfo.label,
        partyInfo.pcCount,
        partyInfo.pcCount == 1 and '' or 's')
end

local function warpToCamp(player, mode, bracket, spot)
    if player == nil or spot == nil then
        return
    end

    if player.isAlive and not player:isAlive() then
        tell(player, 'Cannot warp while KO\'d.')
        return
    end

    local partyInfo = detectPartyInfo(player)
    local warpParty = isPartyWarpEnabled(player) and partyInfo.pcCount > 1

    tell(player, string.format('Warping to [%s Lv.%d] %s -> %s',
        MODE_INFO[mode].label, bracket, spot.label, spot.mobs))

    if warpParty and player.getParty then
        local warped = 0
        for _, member in pairs(player:getParty()) do
            if member ~= nil and member.isPC and member:isPC() and (not member.isAlive or member:isAlive()) then
                if member:getID() ~= player:getID() then
                    tell(member, string.format('%s warped the party to %s (%s).', player:getName(), spot.label, spot.mobs))
                end
                member:setPos(spot.x, spot.y, spot.z, spot.rot, spot.zone)
                warped = warped + 1
            end
        end
        if warped > 1 then
            tell(player, string.format('Warped %d party member(s).', warped))
        end
    else
        player:setPos(spot.x, spot.y, spot.z, spot.rot, spot.zone)
    end
end

local function printCampsToChat(player, mode, bracket)
    local bracketData = CAMPS[bracket] and CAMPS[bracket][mode]
    if not bracketData then
        return
    end
    local tag = bracket == 75 and 'Lv.75 Merits' or string.format('Lv.%d', bracket)
    tell(player, string.format('=== %s %s (%s | %s) ===',
        MODE_INFO[mode].label, tag, bracketData.mobRange, MODE_INFO[mode].targetNote))
    for idx, spot in ipairs(bracketData.spots) do
        tell(player, string.format('  %d. %s - %s', idx, spot.label, spot.mobs))
    end
end

local function printUsage(player)
    tell(player, 'Usage: !camp | !camp go | !camp <level> | !camp <solo|duo|trio> [level] | !camp party | !camp list')
end

-----------------------------------
-- Party-Aware customMenu UI
-----------------------------------
local openMainMenu
local openBracketsPage
local openCampSpotsMenu
local openModeSelectMenu

openCampSpotsMenu = function(player, mode, bracket, modeOverride)
    local bracketData = CAMPS[bracket] and CAMPS[bracket][mode]
    if not bracketData then
        return openMainMenu(player, modeOverride)
    end

    local options = {}
    for _, spot in ipairs(bracketData.spots) do
        local capturedSpot = spot
        table.insert(options,
        {
            capturedSpot.label,
            function(p)
                warpToCamp(p, mode, bracket, capturedSpot)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openMainMenu(p, modeOverride) end)
        end,
    })

    local bLabel = bracket == 75 and 'Lv.75 Merits' or string.format('Lv.%d', bracket)
    return
    {
        title   = string.format('%s %s (%s)', MODE_INFO[mode].label, bLabel, bracketData.mobRange),
        options = options,
    }
end

openBracketsPage = function(player, mode, page, modeOverride)
    page = page or 1
    local perPage    = 5
    local totalPages = math.max(1, math.ceil(#BRACKETS / perPage))
    page = math.max(1, math.min(page, totalPages))

    local curBracket = getRecommendedBracket(player:getMainLvl())
    local startIdx   = (page - 1) * perPage + 1
    local endIdx     = math.min(#BRACKETS, startIdx + perPage - 1)
    local options    = {}

    for idx = startIdx, endIdx do
        local br          = BRACKETS[idx]
        local bracketData = CAMPS[br][mode]
        local prefix      = (br == curBracket) and '[*] ' or ''
        local bName       = (br == 75) and 'Lv.75 Merits' or string.format('Lv.%d', br)
        local capturedBr  = br
        table.insert(options,
        {
            string.format('%s%s (%s)', prefix, bName, bracketData.mobRange),
            function(p)
                delaySendMenu(p, function() return openCampSpotsMenu(p, mode, capturedBr, modeOverride) end)
            end,
        })
    end

    if page > 1 then
        table.insert(options,
        {
            'Prev Brackets',
            function(p)
                delaySendMenu(p, function() return openBracketsPage(p, mode, page - 1, modeOverride) end)
            end,
        })
    elseif page < totalPages then
        table.insert(options,
        {
            'More Brackets ->',
            function(p)
                delaySendMenu(p, function() return openBracketsPage(p, mode, page + 1, modeOverride) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openMainMenu(p, modeOverride) end)
        end,
    })

    return
    {
        title   = string.format('%s Brackets (%d/%d)', MODE_INFO[mode].label, page, totalPages),
        options = options,
    }
end

openModeSelectMenu = function(player)
    local partyInfo = detectPartyInfo(player)
    local options   =
    {
        {
            string.format('Auto (Detected: %s)', partyInfo.label),
            function(p)
                delaySendMenu(p, function() return openMainMenu(p, nil) end)
            end,
        },
        {
            'Solo Camps (EM to Tough)',
            function(p)
                delaySendMenu(p, function() return openMainMenu(p, 'solo') end)
            end,
        },
        {
            'Duo Camps (Tough to VT+)',
            function(p)
                delaySendMenu(p, function() return openMainMenu(p, 'duo') end)
            end,
        },
        {
            'Trio Camps (VT+ to High IT+)',
            function(p)
                delaySendMenu(p, function() return openMainMenu(p, 'trio') end)
            end,
        },
        {
            'Back',
            function(p)
                delaySendMenu(p, function() return openMainMenu(p, nil) end)
            end,
        },
    }

    return
    {
        title   = string.format('Mode Override (%s)', formatPartyTag(partyInfo)),
        options = options,
    }
end

openMainMenu = function(player, modeOverride)
    local partyInfo  = detectPartyInfo(player)
    local mode       = modeOverride or partyInfo.mode
    local playerLvl  = player:getMainLvl()
    local recBracket = getRecommendedBracket(playerLvl)
    local recData    = CAMPS[recBracket][mode]
    local recLabel   = recBracket == 75 and 'Lv.75 Merits' or string.format('Lv.%d', recBracket)
    local modeTag    = modeOverride and string.format('%s*', MODE_INFO[mode].label) or MODE_INFO[mode].label

    local options =
    {
        {
            string.format('[*] Recommended: %s (%s)', recLabel, recData.mobRange),
            function(p)
                delaySendMenu(p, function() return openCampSpotsMenu(p, mode, recBracket, modeOverride) end)
            end,
        },
        {
            string.format('Browse %s Brackets (1-40)', MODE_INFO[mode].label),
            function(p)
                delaySendMenu(p, function() return openBracketsPage(p, mode, 1, modeOverride) end)
            end,
        },
        {
            string.format('Browse %s Brackets (50-75)', MODE_INFO[mode].label),
            function(p)
                delaySendMenu(p, function() return openBracketsPage(p, mode, 2, modeOverride) end)
            end,
        },
        {
            string.format('Switch Mode (Now: %s)', modeTag),
            function(p)
                delaySendMenu(p, function() return openModeSelectMenu(p) end)
            end,
        },
    }

    if partyInfo.pcCount > 1 then
        local partyOn = isPartyWarpEnabled(player)
        table.insert(options,
        {
            string.format('Warp Whole Party: %s', partyOn and 'ON' or 'OFF'),
            function(p)
                p:setCharVar('[CampWarp]Party', partyOn and 0 or 1)
                tell(p, string.format('Warp Whole Party is now %s.', partyOn and 'OFF (Self Only)' or 'ON'))
                delaySendMenu(p, function() return openMainMenu(p, modeOverride) end)
            end,
        })
    end

    table.insert(options,
    {
        'Close',
        function()
        end,
    })

    return
    {
        title   = string.format('Camp Warp | %s | Lv.%d', formatPartyTag(partyInfo), playerLvl),
        options = options,
    }
end

commandObj.onTrigger = function(player, arg1, arg2, arg3)
    local partyInfo  = detectPartyInfo(player)
    local playerLvl  = player:getMainLvl()
    local recBracket = getRecommendedBracket(playerLvl)
    local cmd        = arg1 and string.lower(tostring(arg1)) or nil

    if cmd == nil or cmd == 'menu' then
        local recData = CAMPS[recBracket][partyInfo.mode]
        tell(player, string.format('Party Check: %s | Lv.%d -> Showing %s Lv.%d camps (%s, %s).',
            formatPartyTag(partyInfo),
            playerLvl,
            partyInfo.label,
            recBracket,
            recData.mobRange,
            MODE_INFO[partyInfo.mode].targetNote))
        player:customMenu(openMainMenu(player, nil))
        return
    end

    if cmd == 'help' then
        printUsage(player)
        return
    end

    if cmd == 'party' then
        local nextVal = isPartyWarpEnabled(player) and 0 or 1
        player:setCharVar('[CampWarp]Party', nextVal)
        tell(player, string.format('Warp Whole Party is now %s.', nextVal == 1 and 'ON' or 'OFF (Self Only)'))
        return
    end

    if cmd == 'go' or cmd == 'now' then
        local spot = CAMPS[recBracket][partyInfo.mode].spots[1]
        warpToCamp(player, partyInfo.mode, recBracket, spot)
        return
    end

    if cmd == 'list' then
        local mode = resolveMode(arg2) or partyInfo.mode
        local br   = resolveBracket(arg3) or resolveBracket(arg2) or recBracket
        printCampsToChat(player, mode, br)
        return
    end

    local explicitMode = resolveMode(cmd)
    if explicitMode ~= nil then
        local br = resolveBracket(arg2)
        if br ~= nil then
            player:customMenu(openCampSpotsMenu(player, explicitMode, br, explicitMode))
        else
            player:customMenu(openMainMenu(player, explicitMode))
        end
        return
    end

    local explicitBracket = resolveBracket(cmd)
    if explicitBracket ~= nil then
        local mode = resolveMode(arg2) or partyInfo.mode
        player:customMenu(openCampSpotsMenu(player, mode, explicitBracket, resolveMode(arg2)))
        return
    end

    printUsage(player)
end

xi.commands = xi.commands or {}
xi.commands.camp = commandObj

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('camp', commandObj)
    xi.module.registerCommand('camps', commandObj)
end

return commandObj
