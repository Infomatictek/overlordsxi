-----------------------------------
-- SoulspireXI Test Gear Resolver & Loadout Engine
-- Grants and equips level-appropriate 16-slot gear sets tailored to the
-- player's main job, active SoulspireXI crystal spec, role (TP, WS, Tank,
-- Ranged, Caster), and weapon type.
-----------------------------------
require('modules/custom/lua/soulspire_job_specs')
-----------------------------------
xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.testGear = xi.soulspire.testGear or {}

local testGear = xi.soulspire.testGear
local spec     = xi.soulspire.spec

testGear.LEVEL_BRACKETS = { 1, 10, 20, 30, 40, 50, 60, 70, 75, 99 }

-- Equippable containers checked before adding new items to INVENTORY
local EQUIP_CONTAINERS =
{
    0,  -- xi.inv.INVENTORY
    8,  -- xi.inv.WARDROBE
    10, -- xi.inv.WARDROBE2
    11, -- xi.inv.WARDROBE3
    12, -- xi.inv.WARDROBE4
    13, -- xi.inv.WARDROBE5
    14, -- xi.inv.WARDROBE6
    15, -- xi.inv.WARDROBE7
    16, -- xi.inv.WARDROBE8
}

-----------------------------------
-- Weapon Type & Role Metadata
-----------------------------------
testGear.WEAPON_INFO =
{
    h2h        = { key = 'h2h',        label = 'Hand-to-Hand', skill = 1,  twoHand = false, isH2H = true,  isRanged = false },
    dagger     = { key = 'dagger',     label = 'Dagger',       skill = 2,  twoHand = false, isH2H = false, isRanged = false },
    sword      = { key = 'sword',      label = 'Sword',        skill = 3,  twoHand = false, isH2H = false, isRanged = false },
    gsword     = { key = 'gsword',     label = 'Great Sword',  skill = 4,  twoHand = true,  isH2H = false, isRanged = false },
    axe        = { key = 'axe',        label = 'Axe',          skill = 5,  twoHand = false, isH2H = false, isRanged = false },
    gaxe       = { key = 'gaxe',       label = 'Great Axe',    skill = 6,  twoHand = true,  isH2H = false, isRanged = false },
    scythe     = { key = 'scythe',     label = 'Scythe',       skill = 7,  twoHand = true,  isH2H = false, isRanged = false },
    scythe_blm = { key = 'scythe_blm', label = 'Scythe (BLM)', skill = 7,  twoHand = true,  isH2H = false, isRanged = false },
    polearm    = { key = 'polearm',    label = 'Polearm',      skill = 8,  twoHand = true,  isH2H = false, isRanged = false },
    katana     = { key = 'katana',     label = 'Katana',       skill = 9,  twoHand = false, isH2H = false, isRanged = false },
    gkatana    = { key = 'gkatana',    label = 'Great Katana', skill = 10, twoHand = true,  isH2H = false, isRanged = false },
    club       = { key = 'club',       label = 'Club',          skill = 11, twoHand = false, isH2H = false, isRanged = false },
    club_mage  = { key = 'club_mage',  label = 'Club / Wand',   skill = 11, twoHand = false, isH2H = false, isRanged = false },
    staff      = { key = 'staff',      label = 'Staff',         skill = 12, twoHand = true,  isH2H = false, isRanged = false },
    staff_mage = { key = 'staff_mage', label = 'Staff',         skill = 12, twoHand = true,  isH2H = false, isRanged = false },
    bow        = { key = 'bow',        label = 'Bow & Arrow',  skill = 25, twoHand = false, isH2H = false, isRanged = true  },
    crossbow   = { key = 'crossbow',   label = 'Crossbow',     skill = 26, twoHand = false, isH2H = false, isRanged = true  },
    gun        = { key = 'gun',        label = 'Gun & Bullet', skill = 26, twoHand = false, isH2H = false, isRanged = true  },
    throwing   = { key = 'throwing',   label = 'Throwing',     skill = 27, twoHand = false, isH2H = false, isRanged = true  },
    chakram    = { key = 'chakram',    label = 'Chakram',      skill = 27, twoHand = false, isH2H = false, isRanged = true  },
    shuriken   = { key = 'shuriken',   label = 'Shuriken',     skill = 27, twoHand = false, isH2H = false, isRanged = true  },
}

testGear.WEAPON_ORDER =
{
    'h2h', 'dagger', 'sword', 'gsword', 'axe', 'gaxe',
    'scythe', 'polearm', 'katana', 'gkatana', 'club', 'staff',
    'bow', 'crossbow', 'gun', 'throwing', 'chakram',
}

-- Per-job valid combat weapon types shown in the weapon selector menu
testGear.JOB_WEAPONS =
{
    [1]  = { 'gaxe', 'axe', 'gsword', 'sword', 'scythe', 'polearm', 'club', 'dagger', 'h2h', 'staff', 'bow', 'crossbow', 'throwing' }, -- WAR
    [2]  = { 'h2h', 'staff', 'club', 'throwing' }, -- MNK
    [3]  = { 'club', 'staff' }, -- WHM
    [4]  = { 'staff', 'club' }, -- BLM (+ 'scythe' when Necromancer is active)
    [5]  = { 'sword', 'dagger', 'club', 'staff', 'bow' }, -- RDM
    [6]  = { 'dagger', 'sword', 'h2h', 'club', 'bow', 'crossbow', 'throwing' }, -- THF
    [7]  = { 'sword', 'club', 'gsword', 'polearm', 'staff', 'dagger' }, -- PLD
    [8]  = { 'scythe', 'gsword', 'sword', 'gaxe', 'axe', 'club', 'dagger', 'crossbow' }, -- DRK
    [9]  = { 'axe', 'scythe', 'sword', 'dagger', 'club' }, -- BST
    [10] = { 'dagger', 'sword', 'club', 'staff' }, -- BRD
    [11] = { 'bow', 'crossbow', 'gun', 'axe', 'dagger', 'sword', 'club', 'throwing' }, -- RNG
    [12] = { 'gkatana', 'polearm', 'sword', 'club', 'bow', 'throwing' }, -- SAM
    [13] = { 'katana', 'dagger', 'sword', 'gkatana', 'h2h', 'club', 'throwing', 'shuriken', 'bow' }, -- NIN
    [14] = { 'polearm', 'staff', 'sword', 'club', 'dagger' }, -- DRG
    [15] = { 'staff', 'club' }, -- SMN
    [16] = { 'sword', 'club' }, -- BLU
    [17] = { 'dagger', 'sword', 'gun', 'throwing' }, -- COR
    [18] = { 'h2h', 'dagger', 'club', 'throwing' }, -- PUP
    [19] = { 'dagger', 'sword', 'h2h', 'throwing', 'chakram' }, -- DNC
    [20] = { 'staff', 'club' }, -- SCH
    [21] = { 'club', 'staff', 'dagger' }, -- GEO
    [22] = { 'gsword', 'sword', 'gaxe', 'axe', 'club' }, -- RUN
}

local WEAPON_ALIASES =
{
    h2h          = 'h2h',
    handtohand   = 'h2h',
    fists        = 'h2h',
    knuckles     = 'h2h',
    dagger       = 'dagger',
    knife        = 'dagger',
    sword        = 'sword',
    blade        = 'sword',
    gs           = 'gsword',
    gsword       = 'gsword',
    greatsword   = 'gsword',
    axe          = 'axe',
    gaxe         = 'gaxe',
    greataxe     = 'gaxe',
    scythe       = 'scythe',
    scytheblm    = 'scythe_blm',
    polearm      = 'polearm',
    pole         = 'polearm',
    spear        = 'polearm',
    lance        = 'polearm',
    katana       = 'katana',
    gk           = 'gkatana',
    gkatana      = 'gkatana',
    greatkatana  = 'gkatana',
    club         = 'club',
    mace         = 'club',
    hammer       = 'club',
    wand         = 'club_mage',
    rod          = 'club_mage',
    clubmage     = 'club_mage',
    staff        = 'staff',
    polestaff    = 'staff',
    staffmage    = 'staff_mage',
    magestaff    = 'staff_mage',
    bow          = 'bow',
    archery      = 'bow',
    xbow         = 'crossbow',
    crossbow     = 'crossbow',
    bolt         = 'crossbow',
    gun          = 'gun',
    marksmanship = 'gun',
    rifle        = 'gun',
    throw        = 'throwing',
    throwing     = 'throwing',
    boomerang    = 'throwing',
    chakram      = 'chakram',
    disc         = 'chakram',
    bladewheel   = 'chakram',
    shuriken     = 'shuriken',
}

local ROLE_ALIASES =
{
    tp          = 'tp',
    tpset       = 'tp',
    haste       = 'tp',
    melee       = 'tp',
    dps         = 'tp',
    dd          = 'tp',
    ws          = 'ws',
    wsset       = 'ws',
    weaponskill = 'ws',
    str         = 'ws',
    tank        = 'tank',
    def         = 'tank',
    defense     = 'tank',
    dt          = 'tank',
    mitigation  = 'tank',
    ranged      = 'ranged',
    rng         = 'ranged',
    shooter     = 'ranged',
    caster      = 'caster',
    mage        = 'caster',
    magic       = 'caster',
    healer      = 'caster',
    nuker       = 'caster',
}

testGear.ROLE_LABELS =
{
    tp     = 'TP Set (Haste / Store TP / Multi-Hit)',
    ws     = 'WS Set (STR / Attack / WS Damage)',
    tank   = 'Tank Set (DT / HP / DEF / Evasion)',
    ranged = 'Ranged Set (R.Acc / R.Atk / Store TP)',
    caster = 'Caster Set (MAB / M.Acc / Fast Cast)',
}

function testGear.resolveWeaponKey(input)
    if input == nil then
        return nil
    end
    local norm = string.lower(tostring(input)):gsub('[%s_%-]+', '')
    return WEAPON_ALIASES[norm] or WEAPON_ALIASES[string.lower(tostring(input))]
end

function testGear.resolveRoleKey(input)
    if input == nil then
        return nil
    end
    local norm = string.lower(tostring(input)):gsub('[%s_%-]+', '')
    return ROLE_ALIASES[norm]
end

-----------------------------------
-- Weapon Progression Pools
-----------------------------------
testGear.WEAPONS =
{
    h2h =
    {
        { id = 21519, lvl = 99, jobs =  397747, name = 'Karambit' },
        { id = 21527, lvl = 99, jobs =  131074, name = 'Sakpatas Fists' },
        { id = 21518, lvl = 99, jobs =  397747, name = 'Kaja Knuckles' },
        { id = 18759, lvl = 71, jobs =  131074, name = 'Shlng. Baghnakhs' },
        { id = 18749, lvl = 70, jobs =  135427, name = 'Hades Sainti +1' },
        { id = 18748, lvl = 70, jobs =  135427, name = 'Hades Sainti' },
        { id = 17481, lvl = 75, jobs =  262643, name = 'Kaiser Knuckles' },
        { id = 16396, lvl = 75, jobs =  262643, name = 'Koenigs Knuckles' },
        { id = 17491, lvl = 58, jobs =       2, name = 'Spartan Cesti' },
        { id = 17502, lvl = 52, jobs =  135427, name = 'T.M. Hooks +2' },
        { id = 17501, lvl = 52, jobs =  135427, name = 'T.M. Hooks +1' },
        { id = 17472, lvl = 50, jobs =       2, name = 'Cross-Counters' },
        { id = 18752, lvl = 50, jobs =       2, name = 'Retaliators' },
        { id = 17484, lvl = 66, jobs =    4256, name = 'Stun Jamadhars +1' },
        { id = 16694, lvl = 50, jobs =  135427, name = 'Tct.Mag. Hooks' },
        { id = 17483, lvl = 63, jobs =    4256, name = 'Venom Katars +1' },
        { id = 16696, lvl = 48, jobs =  135427, name = 'Patas +1' },
        { id = 17503, lvl = 46, jobs =  397747, name = 'Exocets' },
        { id = 16446, lvl = 38, jobs =  262643, name = 'Mtl. Knuckles +1' },
        { id = 18350, lvl = 40, jobs =       2, name = 'Tourney Patas' },
        { id = 16393, lvl = 38, jobs =  262643, name = 'Mythril Knuckles' },
        { id = 16693, lvl = 38, jobs =    4256, name = 'Poison Katars +1' },
        { id = 16403, lvl = 38, jobs =    4256, name = 'Poison Katars' },
        { id = 17510, lvl = 39, jobs =  397747, name = 'Vampiric Claws' },
        { id = 16695, lvl = 33, jobs =  131219, name = 'Katars +1' },
        { id = 16445, lvl = 30, jobs =  135555, name = 'Claws +1' },
        { id = 17515, lvl = 30, jobs =  135555, name = 'Hydro Claws +1' },
        { id = 16437, lvl = 20, jobs =  262643, name = 'Metal Knuckles +1' },
        { id = 16444, lvl = 24, jobs =  397747, name = 'Baghnakhs +1' },
        { id = 17500, lvl = 15, jobs =  262643, name = 'Republic Knuckles' },
        { id = 16702, lvl = 20, jobs =  397747, name = 'Cougar Baghnakhs' },
        { id = 16438, lvl = 19, jobs =    4256, name = 'Slc. Baghnakhs +1' },
        { id = 16689, lvl =  9, jobs =  262643, name = 'Brass Knuckles +1' },
        { id = 16391, lvl =  9, jobs =  262643, name = 'Brass Knuckles' },
        { id = 16690, lvl =  1, jobs =  263667, name = 'Cesti +1' },
        { id = 16385, lvl =  1, jobs =  263667, name = 'Cesti' },
        { id = 17476, lvl =  1, jobs =  397747, name = 'Cat Baghnakhs +1' },
        { id = 16405, lvl =  1, jobs =  397747, name = 'Cat Baghnakhs' },
    },
    dagger =
    {
        { id = 21567, lvl = 99, jobs =  333360, name = 'Gletis Knife' },
        { id = 21565, lvl = 99, jobs =  464688, name = 'Tauret' },
        { id = 21585, lvl = 99, jobs =  333617, name = 'Crepuscular Knife' },
        { id = 21564, lvl = 99, jobs =  464688, name = 'Kaja Knife' },
        { id = 20604, lvl = 99, jobs = 1867769, name = 'Ternion Dagger +1' },
        { id = 20581, lvl = 99, jobs =  474849, name = 'Kustawi +1' },
        { id = 20615, lvl = 99, jobs = 1605625, name = 'Levante Dagger' },
        { id = 18002, lvl = 73, jobs =      33, name = 'Perseuss Harpe' },
        { id = 19107, lvl = 74, jobs =  262176, name = 'Azoth' },
        { id = 19118, lvl = 75, jobs =  464688, name = 'Machismo' },
        { id = 18024, lvl = 73, jobs =  474849, name = 'Jambiya +1' },
        { id = 18031, lvl = 72, jobs =  474849, name = 'Amir Jambiya' },
        { id = 17629, lvl = 70, jobs =  474849, name = 'Behem. Knife +1' },
        { id = 18019, lvl = 72, jobs =     288, name = 'Xs Knife' },
        { id = 18001, lvl = 68, jobs =      33, name = 'Harpe' },
        { id = 18021, lvl = 72, jobs = 1577593, name = 'Titans Baselarde' },
        { id = 17628, lvl = 70, jobs =  474849, name = 'Behemoth Knife' },
        { id = 17620, lvl = 71, jobs = 1605625, name = 'Misericorde +1' },
        { id = 17619, lvl = 70, jobs = 1605625, name = 'Daylight Dagger' },
        { id = 18027, lvl = 70, jobs = 1605625, name = 'Palladium Dagger' },
        { id = 16763, lvl = 59, jobs =  464033, name = 'Darksteel Kukri +1' },
        { id = 17615, lvl = 58, jobs =      32, name = 'Chicken Knife' },
        { id = 16760, lvl = 57, jobs = 1589256, name = 'Darksteel Kris +1' },
        { id = 17989, lvl = 57, jobs = 1589256, name = 'Spark Kris +1' },
        { id = 17609, lvl = 60, jobs =  474849, name = 'Cermet Knife +1' },
        { id = 19120, lvl = 57, jobs =  474849, name = 'Avis' },
        { id = 17618, lvl = 56, jobs = 1605625, name = 'Kidney Dagger' },
        { id = 16757, lvl = 50, jobs =   66592, name = 'Corsairs Knife' },
        { id = 16758, lvl = 55, jobs = 1577593, name = 'Dst. Baselard +1' },
        { id = 17611, lvl = 46, jobs =  474849, name = 'Bone Knife +1' },
        { id = 17980, lvl = 48, jobs =    5680, name = 'Hornetneedle' },
        { id = 16765, lvl = 51, jobs = 1605625, name = 'Lust Dagger' },
        { id = 17610, lvl = 46, jobs =  474849, name = 'Bone Knife' },
        { id = 17991, lvl = 43, jobs = 1589256, name = 'Cmb.Cst.Dagger +2' },
        { id = 19114, lvl = 49, jobs = 1605625, name = 'Galkan Dagger' },
        { id = 16484, lvl = 45, jobs = 1605625, name = 'Burglars Dagger' },
        { id = 17979, lvl = 34, jobs =  464033, name = 'Federation Kukri' },
        { id = 17607, lvl = 40, jobs = 1577593, name = 'Corrosive Baselard' },
        { id = 17973, lvl = 34, jobs = 1577593, name = 'Kingdom Dagger' },
        { id = 16463, lvl = 40, jobs = 1589256, name = 'Cmb.Cst. Dagger' },
        { id = 17978, lvl = 34, jobs =  464033, name = 'Windurstian Kukri' },
        { id = 16487, lvl = 38, jobs = 1605625, name = 'Minstrels Dagger' },
        { id = 17977, lvl = 25, jobs =  474849, name = 'Federation Knife' },
        { id = 19106, lvl = 30, jobs =  474849, name = 'Thugs Jambiya +1' },
        { id = 16744, lvl = 30, jobs = 1577593, name = 'Ryl.Sqr. Dagger' },
        { id = 17975, lvl = 25, jobs = 1605625, name = 'Republic Dagger' },
        { id = 17631, lvl = 30, jobs =    1280, name = 'Hawkers Knife +1' },
        { id = 17974, lvl = 25, jobs = 1605625, name = 'Bastokan Dagger' },
        { id = 16746, lvl = 20, jobs =  474849, name = 'Mercenarys Knife' },
        { id = 16745, lvl = 20, jobs = 1605625, name = 'Decurions Dagger' },
        { id = 16748, lvl = 20, jobs =  464033, name = 'Kukri +1' },
        { id = 17993, lvl = 20, jobs =    5680, name = 'Platoon Dagger' },
        { id = 16741, lvl = 20, jobs = 1605625, name = 'Poison Dagger +1' },
        { id = 16740, lvl =  9, jobs = 1605625, name = 'Brass Dagger +1' },
        { id = 16449, lvl =  9, jobs = 1605625, name = 'Brass Dagger' },
        { id = 16490, lvl =  7, jobs =  474849, name = 'Blind Knife +1' },
        { id = 16491, lvl =  1, jobs =  474849, name = 'Bronze Knife +1' },
        { id = 16492, lvl =  1, jobs = 1605625, name = 'Bronze Dagger +1' },
        { id = 16465, lvl =  1, jobs =  474849, name = 'Bronze Knife' },
        { id = 16448, lvl =  1, jobs = 1605625, name = 'Bronze Dagger' },
    },
    sword =
    {
        { id = 21621, lvl = 99, jobs = 2209777, name = 'Naegling' },
        { id = 20672, lvl = 99, jobs =   32848, name = 'Ice Brand' },
        { id = 21635, lvl = 99, jobs = 2097345, name = 'Malignance Sword' },
        { id = 21620, lvl = 99, jobs = 2209777, name = 'Kaja Sword' },
        { id = 20680, lvl = 99, jobs =   43233, name = 'Tanmogayi +1' },
        { id = 20679, lvl = 99, jobs =   43233, name = 'Tanmogayi' },
        { id = 20717, lvl = 99, jobs =  336465, name = 'Arendsi Fleuret' },
        { id = 20709, lvl = 99, jobs =  336465, name = 'Demers. Degen +1' },
        { id = 17753, lvl = 75, jobs = 2097345, name = 'Organics' },
        { id = 17719, lvl = 73, jobs =  336465, name = 'Mensur Epee' },
        { id = 17738, lvl = 71, jobs = 2097344, name = 'Hauteclaire' },
        { id = 17751, lvl = 74, jobs = 2130113, name = 'Fragarach' },
        { id = 17659, lvl = 74, jobs =    3489, name = 'Seiryus Sword' },
        { id = 17728, lvl = 73, jobs =   32768, name = 'Adaman Kilij +1' },
        { id = 17645, lvl = 66, jobs = 2097345, name = 'Espadon +1' },
        { id = 17765, lvl = 75, jobs =   35009, name = 'Concordia' },
        { id = 17653, lvl = 70, jobs = 2097345, name = 'Hrotti' },
        { id = 17711, lvl = 72, jobs =   43233, name = 'Shivas Shotel' },
        { id = 17655, lvl = 71, jobs =   36257, name = 'Snr.Msk. Scimitar' },
        { id = 17684, lvl = 73, jobs = 2195665, name = 'Griffinclaw' },
        { id = 17754, lvl = 72, jobs =  336465, name = 'Sylphid Epee' },
        { id = 17685, lvl = 73, jobs = 2473969, name = 'Lex Talionis' },
        { id = 16555, lvl = 70, jobs =    3489, name = 'Ridill' },
        { id = 17637, lvl = 69, jobs = 2143985, name = 'Wing Sword +1' },
        { id = 17665, lvl = 65, jobs =   36257, name = 'Ifrits Blade' },
        { id = 16619, lvl = 68, jobs =    8208, name = 'Epee +1' },
        { id = 16828, lvl = 60, jobs = 2097345, name = 'Bastard Sword +1' },
        { id = 17677, lvl = 52, jobs = 2097345, name = 'T.M. Espadon +2' },
        { id = 17737, lvl = 69, jobs =   65536, name = 'Corsairs Scimitar' },
        { id = 17714, lvl = 65, jobs = 2195665, name = 'Macuahuitl +1' },
        { id = 16563, lvl = 70, jobs = 2739961, name = 'Rune Blade' },
        { id = 16542, lvl = 69, jobs = 2143985, name = 'Wing Sword' },
        { id = 16557, lvl = 55, jobs =   36257, name = 'Msk.Cmd. Falchion' },
        { id = 17720, lvl = 65, jobs =  336465, name = 'Company Fleuret' },
        { id = 17722, lvl = 65, jobs =  336465, name = 'Phantom Fleuret' },
        { id = 17718, lvl = 60, jobs =   36257, name = 'Leech Scimitar' },
        { id = 16810, lvl = 50, jobs = 2097345, name = 'Tct.Mag. Espadon' },
        { id = 17709, lvl = 60, jobs =     512, name = 'Swan Bilbo' },
        { id = 16805, lvl = 55, jobs =    8208, name = 'Ryl.Grd. Fleuret' },
        { id = 16612, lvl = 56, jobs = 2097361, name = 'Saber +1' },
        { id = 16825, lvl = 59, jobs = 2143985, name = 'Cermet Sword +1' },
        { id = 16539, lvl = 59, jobs = 2143985, name = 'Cermet Sword' },
        { id = 16618, lvl = 60, jobs = 2439161, name = 'Mailbreaker +1' },
        { id = 17726, lvl = 50, jobs =   34977, name = 'Immortals Shotel' },
        { id = 16813, lvl = 55, jobs =  336465, name = 'Schlaeger +1' },
        { id = 16800, lvl = 47, jobs = 2097361, name = 'Knights Sword +1' },
        { id = 16571, lvl = 50, jobs = 2097361, name = 'T.K. Army Sword' },
        { id = 17675, lvl = 43, jobs =   34977, name = 'Cmb.Cst.Scmtr. +2' },
        { id = 16804, lvl = 47, jobs =   36257, name = 'Flame Blade +1' },
        { id = 16564, lvl = 47, jobs =   36257, name = 'Flame Blade' },
        { id = 16822, lvl = 49, jobs = 2143985, name = 'Crimson Blade' },
        { id = 16807, lvl = 40, jobs =   34977, name = 'Cmb.Cst. Scimitar' },
        { id = 17702, lvl = 42, jobs =   43233, name = 'Shotel +1' },
        { id = 16529, lvl = 50, jobs =  336465, name = 'Musketeers Sword' },
        { id = 16817, lvl = 45, jobs =  336465, name = 'Holy Degen +1' },
        { id = 16533, lvl = 45, jobs = 2209777, name = 'Ancient Sword' },
        { id = 17717, lvl = 40, jobs =   32768, name = 'Immortals Scimitar' },
        { id = 17693, lvl = 39, jobs =      64, name = 'Grudge Sword' },
        { id = 16812, lvl = 34, jobs = 2097345, name = 'War Sword' },
        { id = 16823, lvl = 40, jobs =  336465, name = 'Flame Degen +1' },
        { id = 16826, lvl = 38, jobs = 2195665, name = 'Divine Sword +1' },
        { id = 17673, lvl = 34, jobs = 2143985, name = 'Republic Sword' },
        { id = 16636, lvl = 36, jobs =   34977, name = 'Tulwar +1' },
        { id = 16816, lvl = 36, jobs = 2143985, name = 'Holy Sword +1' },
        { id = 16522, lvl = 40, jobs =  336465, name = 'Flame Degen' },
        { id = 16516, lvl = 40, jobs = 2439161, name = 'Jr.Msk. Tuck' },
        { id = 17740, lvl = 30, jobs =   32768, name = 'Steel Kilij +1' },
        { id = 16806, lvl = 30, jobs = 2143985, name = 'Centurions Sword' },
        { id = 16634, lvl = 30, jobs = 2195665, name = 'Broadsword +1' },
        { id = 16803, lvl = 30, jobs =    8208, name = 'Fleuret +1' },
        { id = 16819, lvl = 28, jobs =   34977, name = 'Mithran Scimitar' },
        { id = 16545, lvl = 30, jobs = 2195665, name = 'Broadsword' },
        { id = 16608, lvl = 27, jobs = 2209777, name = 'Gladiator' },
        { id = 17750, lvl = 25, jobs = 2209777, name = 'Anthos Xiphos' },
        { id = 17650, lvl = 24, jobs =   34977, name = 'Nadrs' },
        { id = 17708, lvl = 19, jobs =     209, name = 'Auriga Xiphos' },
        { id = 16617, lvl = 23, jobs = 2439161, name = 'Tuck +1' },
        { id = 16628, lvl = 18, jobs = 2097361, name = 'Longsword +1' },
        { id = 16621, lvl = 18, jobs = 2143985, name = 'Flame Sword' },
        { id = 16513, lvl = 23, jobs = 2439161, name = 'Tuck' },
        { id = 16633, lvl = 20, jobs =  336465, name = 'Degen +1' },
        { id = 17692, lvl = 20, jobs = 2143985, name = 'Platoon Spatha' },
        { id = 16517, lvl = 20, jobs =  336465, name = 'Degen' },
        { id = 16629, lvl = 19, jobs = 2439161, name = 'Small Sword' },
        { id = 16625, lvl = 13, jobs =   34977, name = 'Scimitar +1' },
        { id = 16802, lvl = 13, jobs = 2209777, name = 'Brass Xiphos +1' },
        { id = 16552, lvl = 13, jobs =   34977, name = 'Scimitar' },
        { id = 16627, lvl =  9, jobs = 2097361, name = 'Spatha +1' },
        { id = 16565, lvl =  9, jobs = 2097361, name = 'Spatha' },
        { id = 16544, lvl = 10, jobs = 2209777, name = 'Ryl.Arc. Sword' },
        { id = 16801, lvl =  7, jobs =   34977, name = 'Sapara +1' },
        { id = 16624, lvl =  7, jobs = 2209777, name = 'Xiphos +1' },
        { id = 16551, lvl =  7, jobs =   34977, name = 'Sapara' },
        { id = 16623, lvl =  1, jobs = 2143985, name = 'Bronze Sword +1' },
        { id = 16535, lvl =  1, jobs = 2143985, name = 'Bronze Sword' },
    },
    gsword =
    {
        { id = 21673, lvl = 99, jobs = 2097345, name = 'Kaja Claymore' },
        { id = 21672, lvl = 99, jobs = 2097345, name = 'Eletta Claymore' },
        { id = 19153, lvl = 74, jobs =     128, name = 'Naglering' },
        { id = 18385, lvl = 75, jobs = 2097345, name = 'Algol' },
        { id = 19163, lvl = 75, jobs = 2097345, name = 'Nightfall' },
        { id = 16942, lvl = 70, jobs =     128, name = 'Balmung' },
        { id = 16941, lvl = 69, jobs = 2097216, name = 'Flamberge +1' },
        { id = 18371, lvl = 69, jobs = 2097216, name = 'Gust Tongue +1' },
        { id = 18387, lvl = 70, jobs = 2097345, name = 'Djinnbringer' },
        { id = 19156, lvl = 69, jobs = 2097345, name = 'Balisarde' },
        { id = 16616, lvl = 60, jobs = 2097345, name = 'Zweihander +1' },
        { id = 16939, lvl = 59, jobs = 2097216, name = 'Ram-Dao +1' },
        { id = 16591, lvl = 60, jobs = 2097345, name = 'Zweihander' },
        { id = 19150, lvl = 50, jobs = 2097345, name = 'Cobra Claymore' },
        { id = 16958, lvl = 47, jobs = 2097344, name = 'Faussar +1' },
        { id = 16949, lvl = 43, jobs = 2097345, name = 'Ryl.Swd. Blade +2' },
        { id = 16601, lvl = 40, jobs = 2097216, name = 'Ryl.Swd. Blade' },
        { id = 16937, lvl = 39, jobs = 2097345, name = 'Icicle Sword' },
        { id = 16639, lvl = 36, jobs = 2097345, name = 'Fine Claymore' },
        { id = 16928, lvl = 27, jobs = 2097345, name = 'Hellfire Sword' },
        { id = 16935, lvl = 24, jobs = 2097345, name = 'Barbarians Sword' },
        { id = 16930, lvl = 20, jobs = 2097345, name = 'Mrc. Greatsword' },
        { id = 16931, lvl = 20, jobs = 2097345, name = '2-hand. Sword +1' },
        { id = 16638, lvl = 10, jobs = 2097345, name = 'Claymore +1' },
        { id = 18367, lvl = 10, jobs = 2097345, name = 'Gust Claymore +1' },
    },
    axe =
    {
        { id = 21721, lvl = 99, jobs = 2098561, name = 'Kaja Axe' },
        { id = 21720, lvl = 99, jobs = 2098561, name = 'Eletta Axe' },
        { id = 17928, lvl = 70, jobs =     257, name = 'Juggernaut' },
        { id = 17958, lvl = 71, jobs = 2098561, name = 'Iron Ram Pick' },
        { id = 17935, lvl = 71, jobs = 2097537, name = 'Tabarzin +1' },
        { id = 17938, lvl = 72, jobs = 2098561, name = 'Woodvilles Axe' },
        { id = 17939, lvl = 70, jobs = 2098561, name = 'Kriegsbeil' },
        { id = 17926, lvl = 68, jobs = 2098561, name = 'Acha Darmas' },
        { id = 17965, lvl = 60, jobs = 2098561, name = 'Sirocco Axe' },
        { id = 16679, lvl = 56, jobs =     256, name = 'Wrath Tabar' },
        { id = 17924, lvl = 60, jobs = 2098561, name = 'Tungi' },
        { id = 16676, lvl = 48, jobs = 2098561, name = 'Viking Axe' },
        { id = 16670, lvl = 50, jobs = 2097537, name = 'Mythril Pick +1' },
        { id = 17932, lvl = 43, jobs = 2098561, name = 'Cmb.Cst. Axe +2' },
        { id = 16669, lvl = 40, jobs = 2098561, name = 'Cmb.Cst. Axe' },
        { id = 16678, lvl = 40, jobs =       1, name = 'Razor Axe' },
        { id = 16680, lvl = 40, jobs =     256, name = 'Barbaroi Axe' },
        { id = 16665, lvl = 37, jobs = 2098561, name = 'Mythril Axe +1' },
        { id = 17940, lvl = 28, jobs = 2098561, name = 'Military Pick' },
        { id = 16672, lvl = 26, jobs = 2098561, name = 'Tigerhunter' },
        { id = 16663, lvl = 20, jobs = 2098561, name = 'Battleaxe +1' },
        { id = 16643, lvl = 20, jobs = 2098561, name = 'Battleaxe' },
        { id = 16648, lvl = 10, jobs = 2098561, name = 'Legionnaires Axe' },
        { id = 16661, lvl =  8, jobs = 2098561, name = 'Brass Axe +1' },
        { id = 16646, lvl =  1, jobs = 2098561, name = 'Bronze Axe +1' },
        { id = 16640, lvl =  1, jobs = 2098561, name = 'Bronze Axe' },
    },
    gaxe =
    {
        { id = 21778, lvl = 99, jobs = 2097281, name = 'Kaja Chopper' },
        { id = 21764, lvl = 99, jobs =       1, name = 'Drastic Axe' },
        { id = 21777, lvl = 99, jobs = 2097281, name = 'Eletta Chopper' },
        { id = 18497, lvl = 72, jobs =       1, name = 'Foolkiller' },
        { id = 18198, lvl = 74, jobs =     129, name = 'Byakkos Axe' },
        { id = 18224, lvl = 73, jobs = 2097281, name = 'Toporok +1' },
        { id = 18494, lvl = 71, jobs = 2097281, name = 'Fourth Toporok' },
        { id = 18487, lvl = 68, jobs = 2097281, name = 'Eriks Axe' },
        { id = 16729, lvl = 69, jobs = 2097281, name = 'Berserkers Axe' },
        { id = 16725, lvl = 59, jobs = 2097281, name = 'Massive Dst. Axe' },
        { id = 18205, lvl = 59, jobs = 2097281, name = 'Hydro Chopper +1' },
        { id = 18219, lvl = 50, jobs =       1, name = 'Lcs. Voulge +1' },
        { id = 18218, lvl = 50, jobs =       1, name = 'Leucous Voulge' },
        { id = 16710, lvl = 49, jobs = 2097281, name = 'Gigant Axe' },
        { id = 16727, lvl = 46, jobs = 2097281, name = 'Eisentaenzer' },
        { id = 16708, lvl = 37, jobs =     129, name = 'Horror Voulge' },
        { id = 16721, lvl = 39, jobs = 2097281, name = 'Huge Moth Axe' },
        { id = 16718, lvl = 34, jobs = 2097281, name = 'Heavy Axe +1' },
        { id = 16712, lvl = 30, jobs = 2097281, name = 'Centurions Axe' },
        { id = 18212, lvl = 28, jobs =     129, name = 'Military Axe' },
        { id = 16720, lvl = 25, jobs = 2097281, name = 'Plantbane' },
        { id = 16714, lvl = 20, jobs = 2097281, name = 'Neckchopper' },
        { id = 16719, lvl = 16, jobs = 2097281, name = 'Moth Axe' },
        { id = 16713, lvl =  8, jobs = 2097281, name = 'Hellfire Axe' },
        { id = 16709, lvl =  8, jobs = 2097281, name = 'Inferno Axe' },
    },
    scythe =
    {
        { id = 21829, lvl = 99, jobs =     393, name = 'Kaja Scythe' },
        { id = 21832, lvl = 99, jobs =     128, name = 'Agwus Scythe' },
        { id = 21828, lvl = 99, jobs =     393, name = 'Eletta Scythe' },
        { id = 18059, lvl = 73, jobs =     128, name = 'Tritons Scythe' },
        { id = 16791, lvl = 73, jobs =     128, name = 'Death Scythe +1' },
        { id = 18947, lvl = 70, jobs =     128, name = 'Molioness Sickle' },
        { id = 18043, lvl = 74, jobs =     385, name = 'Suzakus Scythe' },
        { id = 18064, lvl = 70, jobs =     128, name = 'Volunt. Scythe' },
        { id = 18946, lvl = 71, jobs =     385, name = 'Fourth Zaghnal' },
        { id = 18063, lvl = 72, jobs =     393, name = 'Garudas Sickle' },
        { id = 18950, lvl = 74, jobs =     393, name = 'White Joker' },
        { id = 18066, lvl = 69, jobs =     393, name = 'Blackjack' },
        { id = 18952, lvl = 69, jobs =     385, name = 'Faucheuse' },
        { id = 21817, lvl = 70, jobs =     393, name = 'Rune Scythe' },
        { id = 16788, lvl = 58, jobs =     128, name = 'Vassagos Scythe' },
        { id = 18055, lvl = 57, jobs =     393, name = 'Ivory Sickle +1' },
        { id = 16786, lvl = 49, jobs =     128, name = 'Brb. Scythe' },
        { id = 18054, lvl = 57, jobs =     393, name = 'Ivory Sickle' },
        { id = 16771, lvl = 47, jobs =     385, name = 'Falcastra' },
        { id = 18051, lvl = 46, jobs =     393, name = 'Antlion Sickle' },
        { id = 18050, lvl = 46, jobs =     393, name = 'Mandibular Sickle' },
        { id = 16782, lvl = 40, jobs =     128, name = 'Mythril Scythe +1' },
        { id = 18046, lvl = 40, jobs =     128, name = 'Mutilator' },
        { id = 18953, lvl = 40, jobs =     393, name = 'Beluga' },
        { id = 16785, lvl = 37, jobs =     385, name = 'Harvester' },
        { id = 16776, lvl = 30, jobs =     128, name = 'Mrc.Cpt. Scythe' },
        { id = 16784, lvl = 27, jobs =     385, name = 'Frostreaper' },
        { id = 18040, lvl = 24, jobs =     385, name = 'Webcutter' },
        { id = 16773, lvl = 20, jobs =     128, name = 'Cruel Scythe' },
        { id = 16781, lvl = 18, jobs =     128, name = 'Scythe +1' },
        { id = 16779, lvl = 20, jobs =     385, name = 'Zaghnal +1' },
        { id = 16770, lvl = 20, jobs =     385, name = 'Zaghnal' },
        { id = 16780, lvl = 10, jobs =     385, name = 'Lgn. Scythe' },
        { id = 16772, lvl = 10, jobs =     385, name = 'Brass Zaghnal +1' },
        { id = 16778, lvl =  1, jobs =     385, name = 'Brz. Zaghnal +1' },
        { id = 16768, lvl =  1, jobs =     385, name = 'Bronze Zaghnal' },
    },
    scythe_blm =
    {
        { id = 21829, lvl = 99, jobs =     393, name = 'Kaja Scythe' },
        { id = 21828, lvl = 99, jobs =     393, name = 'Eletta Scythe' },
        { id = 21827, lvl = 99, jobs =     393, name = 'Ajja Scythe' },
        { id = 18950, lvl = 74, jobs =     393, name = 'White Joker' },
        { id = 18066, lvl = 69, jobs =     393, name = 'Blackjack' },
        { id = 18063, lvl = 72, jobs =     393, name = 'Garudas Sickle' },
        { id = 21817, lvl = 70, jobs =     393, name = 'Rune Scythe' },
        { id = 18942, lvl = 70, jobs =     393, name = 'Naigama +1' },
        { id = 18055, lvl = 57, jobs =     393, name = 'Ivory Sickle +1' },
        { id = 18054, lvl = 57, jobs =     393, name = 'Ivory Sickle' },
        { id = 18051, lvl = 46, jobs =     393, name = 'Antlion Sickle' },
        { id = 18050, lvl = 46, jobs =     393, name = 'Mandibular Sickle' },
        { id = 18945, lvl = 46, jobs =     393, name = 'Jet Sickle' },
        { id = 18953, lvl = 40, jobs =     393, name = 'Beluga' },
        { id = 16785, lvl = 37, jobs =     385, name = 'Harvester' },
        { id = 16784, lvl = 27, jobs =     385, name = 'Frostreaper' },
        { id = 18040, lvl = 24, jobs =     385, name = 'Webcutter' },
        { id = 16779, lvl = 20, jobs =     385, name = 'Zaghnal +1' },
        { id = 16770, lvl = 20, jobs =     385, name = 'Zaghnal' },
        { id = 18045, lvl = 20, jobs = 2097537, name = 'Platoon Zaghnal' },
        { id = 16780, lvl = 10, jobs =     385, name = 'Lgn. Scythe' },
        { id = 16772, lvl = 10, jobs =     385, name = 'Brass Zaghnal +1' },
        { id = 16769, lvl = 10, jobs =     385, name = 'Brass Zaghnal' },
        { id = 16778, lvl =  1, jobs =     385, name = 'Brz. Zaghnal +1' },
        { id = 16768, lvl =  1, jobs =     385, name = 'Bronze Zaghnal' },
    },
    polearm =
    {
        { id = 21882, lvl = 99, jobs =   10305, name = 'Kaja Lance' },
        { id = 21855, lvl = 99, jobs =    8192, name = 'Lembing' },
        { id = 21881, lvl = 99, jobs =   10305, name = 'Eletta Lance' },
        { id = 18121, lvl = 75, jobs =    8192, name = 'Valkyries Fork' },
        { id = 18124, lvl = 75, jobs =    8192, name = 'Thalassocrat +1' },
        { id = 18109, lvl = 72, jobs =   10241, name = 'Leviathans Couse' },
        { id = 18126, lvl = 72, jobs =   10240, name = 'Tomoe' },
        { id = 18128, lvl = 69, jobs =    8192, name = 'Skystrider' },
        { id = 18130, lvl = 75, jobs =   10305, name = 'Dabo +1' },
        { id = 18116, lvl = 70, jobs =   10241, name = 'Engetsuto +1' },
        { id = 18129, lvl = 75, jobs =   10305, name = 'Dabo' },
        { id = 18115, lvl = 70, jobs =   10241, name = 'Engetsuto' },
        { id = 18089, lvl = 70, jobs =   10305, name = 'Schiltron Spear' },
        { id = 16886, lvl = 60, jobs =    8192, name = 'Gnd.Kgt. Lance' },
        { id = 18119, lvl = 60, jobs =    8192, name = 'Dark Mezraq +1' },
        { id = 18084, lvl = 70, jobs =  551497, name = 'Rune Halberd' },
        { id = 18094, lvl = 60, jobs =   10241, name = 'Couse +1' },
        { id = 18093, lvl = 60, jobs =   10241, name = 'Couse' },
        { id = 16889, lvl = 55, jobs =   10305, name = 'Battle Fork +1' },
        { id = 18081, lvl = 55, jobs =   10305, name = 'Spark Fork +1' },
        { id = 16877, lvl = 48, jobs =    8192, name = 'Mythril Lance +1' },
        { id = 16847, lvl = 48, jobs =    8192, name = 'Mythril Lance' },
        { id = 16857, lvl = 49, jobs =   10305, name = 'Wind Spear' },
        { id = 16851, lvl = 50, jobs =   10305, name = 'R.K. Army Lance' },
        { id = 18086, lvl = 40, jobs =    8192, name = 'Behourd Lance' },
        { id = 16891, lvl = 38, jobs =    8256, name = 'Obelisk Lance +1' },
        { id = 16890, lvl = 38, jobs =    8256, name = 'Obelisk Lance' },
        { id = 16866, lvl = 36, jobs =   10305, name = 'Halberd +1' },
        { id = 16836, lvl = 36, jobs =   10305, name = 'Halberd' },
        { id = 18090, lvl = 28, jobs =   10305, name = 'Military Spear' },
        { id = 16844, lvl = 30, jobs =   10305, name = 'Ryl.Sqr. Halberd' },
        { id = 18085, lvl = 20, jobs =    8192, name = 'Platoon Lance' },
        { id = 18104, lvl = 20, jobs =   10305, name = 'Fuscina' },
        { id = 16863, lvl = 20, jobs =   10305, name = 'Cruel Spear' },
        { id = 16859, lvl =  7, jobs =   10305, name = 'Bronze Spear +1' },
        { id = 16833, lvl =  7, jobs =   10305, name = 'Bronze Spear' },
        { id = 16862, lvl =  1, jobs =   10305, name = 'Harpoon +1' },
        { id = 16832, lvl =  1, jobs =   10305, name = 'Harpoon' },
    },
    katana =
    {
        { id = 21921, lvl = 99, jobs =    4096, name = 'Kaja Katana' },
        { id = 21920, lvl = 99, jobs =    4096, name = 'Eletta Katana' },
        { id = 18429, lvl = 72, jobs =    4096, name = 'Shusui' },
        { id = 18414, lvl = 73, jobs =    4096, name = 'Hirenjaku +1' },
        { id = 16904, lvl = 70, jobs =    4096, name = 'Fudo' },
        { id = 18422, lvl = 70, jobs =    4096, name = 'Ryumon' },
        { id = 17788, lvl = 60, jobs =    4096, name = 'Sairen' },
        { id = 16924, lvl = 57, jobs =    4096, name = 'Hocho' },
        { id = 18411, lvl = 50, jobs =    4096, name = 'Buboso' },
        { id = 17796, lvl = 48, jobs =    4096, name = 'Sai +1' },
        { id = 17787, lvl = 39, jobs =    4096, name = 'Ohaguro' },
        { id = 17772, lvl = 40, jobs =    4096, name = 'Zushio' },
        { id = 17792, lvl = 30, jobs =    4096, name = 'Nikkariaoe' },
        { id = 17775, lvl = 28, jobs =    4096, name = 'Fukuro' },
        { id = 16917, lvl = 19, jobs =    4096, name = 'Suzume' },
        { id = 17786, lvl = 20, jobs =    4096, name = 'Ganko' },
        { id = 16918, lvl =  7, jobs =    4096, name = 'Wakizashi +1' },
        { id = 16900, lvl =  7, jobs =    4096, name = 'Wakizashi' },
        { id = 16914, lvl =  1, jobs =    4096, name = 'Kunai +1' },
        { id = 16896, lvl =  1, jobs =    4096, name = 'Kunai' },
    },
    gkatana =
    {
        { id = 21974, lvl = 99, jobs =    6144, name = 'Kaja Tachi' },
        { id = 21973, lvl = 99, jobs =    6144, name = 'Eletta Tachi' },
        { id = 17810, lvl = 75, jobs =    2048, name = 'Futsuno Mitama' },
        { id = 18447, lvl = 72, jobs =    2048, name = 'Nanatsusaya' },
        { id = 18438, lvl = 70, jobs =    2048, name = 'Kumokirimaru' },
        { id = 16968, lvl = 70, jobs =    2048, name = 'Kamewari' },
        { id = 18435, lvl = 71, jobs =    6144, name = 'Hotarumaru' },
        { id = 18440, lvl = 71, jobs =    6144, name = 'Shirogatana +1' },
        { id = 18434, lvl = 70, jobs =    6144, name = 'Kosetsusamonji' },
        { id = 16980, lvl = 66, jobs =    6144, name = 'Sukesada' },
        { id = 17807, lvl = 60, jobs =    6144, name = 'Gld.Msk. Uchigat.' },
        { id = 16990, lvl = 59, jobs =    2048, name = 'Daihannya' },
        { id = 16974, lvl = 55, jobs =    6144, name = 'Dotanuki' },
        { id = 16965, lvl = 50, jobs =    2048, name = 'Koryukagemitsu' },
        { id = 16991, lvl = 48, jobs =    2048, name = 'Odenta' },
        { id = 17821, lvl = 40, jobs =    2048, name = 'Kagehide' },
        { id = 17800, lvl = 37, jobs =    2048, name = 'Hosodachi +1' },
        { id = 16979, lvl = 36, jobs =    6144, name = 'Ashura +1' },
        { id = 16962, lvl = 36, jobs =    6144, name = 'Ashura' },
        { id = 18451, lvl = 30, jobs =    2048, name = 'Mokusa' },
        { id = 16988, lvl = 27, jobs =    2048, name = 'Kotetsu' },
        { id = 16975, lvl = 26, jobs =    6144, name = 'Kanesada' },
        { id = 17820, lvl = 20, jobs =    2048, name = 'Gunromaru' },
        { id = 16983, lvl = 16, jobs =    2048, name = 'Nodachi +1' },
        { id = 17811, lvl = 10, jobs =    2048, name = 'Katayama' },
        { id = 16978, lvl = 12, jobs =    6144, name = 'Uchigatana +1' },
        { id = 16960, lvl = 12, jobs =    6144, name = 'Uchigatana' },
        { id = 16981, lvl =  8, jobs =    2048, name = 'Tachi +1' },
    },
    club =
    {
        { id = 21071, lvl = 99, jobs = 1048580, name = 'Cath Palug Hammer' },
        { id = 22031, lvl = 99, jobs = 1622044, name = 'Maxentius' },
        { id = 22040, lvl = 99, jobs = 1589788, name = 'Daybreak' },
        { id = 21102, lvl = 99, jobs = 4194303, name = 'Mafic Cudgel' },
        { id = 21091, lvl = 99, jobs = 2097281, name = 'Loxotic Mace +1' },
        { id = 21088, lvl = 99, jobs = 1048645, name = 'Divinity' },
        { id = 21104, lvl = 99, jobs = 4194303, name = 'Eosuchus Club' },
        { id = 18874, lvl = 74, jobs =      68, name = 'Brise-Os +1' },
        { id = 18873, lvl = 74, jobs =      68, name = 'Brise-Os' },
        { id = 18849, lvl = 71, jobs = 1048645, name = 'Brass Jadagna +1' },
        { id = 18848, lvl = 71, jobs = 1048645, name = 'Brass Jadagna' },
        { id = 18395, lvl = 68, jobs =       4, name = 'Seawolf Cudgel' },
        { id = 18872, lvl = 73, jobs = 1622044, name = 'Lyft Ferule' },
        { id = 18856, lvl = 74, jobs =   32767, name = 'Deae Gratia' },
        { id = 18406, lvl = 69, jobs = 1048645, name = 'Jadagna +1' },
        { id = 17432, lvl = 65, jobs = 1048580, name = 'Darksteel Maul +1' },
        { id = 18405, lvl = 69, jobs = 1048645, name = 'Jadagna' },
        { id = 18843, lvl = 68, jobs = 1622095, name = 'Flan Smasher' },
        { id = 18857, lvl = 72, jobs = 1589788, name = 'Antares' },
        { id = 17471, lvl = 70, jobs = 2097281, name = 'Horrent Mace' },
        { id = 18861, lvl = 69, jobs =   49176, name = 'Grandeur' },
        { id = 17458, lvl = 71, jobs = 1590047, name = 'Rsv.Cpt. Mace' },
        { id = 17465, lvl = 70, jobs = 1622095, name = 'Mighty Cudgel' },
        { id = 17428, lvl = 57, jobs = 1048645, name = 'Darksteel Mace +1' },
        { id = 17416, lvl = 54, jobs = 1048580, name = 'Arcana Breaker' },
        { id = 17037, lvl = 57, jobs = 1048645, name = 'Darksteel Mace' },
        { id = 17073, lvl = 70, jobs = 1622044, name = 'Mistilteinn' },
        { id = 17083, lvl = 47, jobs = 1048580, name = 'Time Hammer' },
        { id = 17438, lvl = 65, jobs = 4194303, name = 'Titans Cudgel' },
        { id = 17411, lvl = 43, jobs = 1048645, name = 'Holy Mace +1' },
        { id = 17114, lvl = 38, jobs = 1048580, name = 'Holy Maul +1' },
        { id = 17041, lvl = 43, jobs = 1048645, name = 'Holy Mace' },
        { id = 17080, lvl = 38, jobs = 1048580, name = 'Holy Maul' },
        { id = 17449, lvl = 34, jobs = 1048645, name = 'Kingdom Mace' },
        { id = 17408, lvl = 39, jobs =    2497, name = 'Great Club +1' },
        { id = 17415, lvl = 48, jobs = 4194303, name = 'Shellbuster' },
        { id = 17030, lvl = 39, jobs =    2497, name = 'Great Club' },
        { id = 17150, lvl = 30, jobs = 1048645, name = 'Ryl.Sqr. Mace' },
        { id = 17142, lvl = 36, jobs = 4194303, name = 'Oak Cudgel +1' },
        { id = 17453, lvl = 23, jobs = 1048580, name = 'Republic Hammer' },
        { id = 17027, lvl = 36, jobs = 4194303, name = 'Oak Cudgel' },
        { id = 17414, lvl = 24, jobs = 1048645, name = 'Pixie Mace' },
        { id = 17115, lvl = 20, jobs = 1048580, name = 'Warhammer +1' },
        { id = 17044, lvl = 20, jobs = 1048580, name = 'Warhammer' },
        { id = 17033, lvl = 27, jobs = 4194303, name = 'Bone Cudgel +1' },
        { id = 17145, lvl = 19, jobs = 1048645, name = 'Mace +1' },
        { id = 17026, lvl = 27, jobs = 4194303, name = 'Bone Cudgel' },
        { id = 17035, lvl = 19, jobs = 1048645, name = 'Mace' },
        { id = 17029, lvl = 20, jobs = 4194303, name = 'Bouncer Club' },
        { id = 17139, lvl = 16, jobs = 4194303, name = 'Solid Club' },
        { id = 17144, lvl =  5, jobs = 1048580, name = 'Bronze Hammer +1' },
        { id = 17028, lvl = 10, jobs = 4194303, name = 'Freeswords Club' },
        { id = 17138, lvl =  9, jobs = 1622044, name = 'Willow Wand +1' },
        { id = 17086, lvl =  4, jobs = 1048645, name = 'Bronze Mace +1' },
        { id = 17417, lvl =  5, jobs = 4194303, name = 'Rabbit Stick' },
        { id = 17137, lvl =  1, jobs = 4194303, name = 'Ash Club +1' },
        { id = 17087, lvl =  1, jobs = 1622044, name = 'Maple Wand +1' },
    },
    club_mage =
    {
        { id = 22040, lvl = 99, jobs = 1589788, name = 'Daybreak' },
        { id = 22042, lvl = 99, jobs = 1572888, name = 'Wizards Rod' },
        { id = 21071, lvl = 99, jobs = 1048580, name = 'Cath Palug Hammer' },
        { id = 22031, lvl = 99, jobs = 1622044, name = 'Maxentius' },
        { id = 22030, lvl = 99, jobs = 1622044, name = 'Kaja Rod' },
        { id = 21104, lvl = 99, jobs = 4194303, name = 'Eosuchus Club' },
        { id = 18857, lvl = 72, jobs = 1589788, name = 'Antares' },
        { id = 18841, lvl = 71, jobs =      68, name = 'Templar Mace' },
        { id = 17073, lvl = 70, jobs = 1622044, name = 'Mistilteinn' },
        { id = 17433, lvl = 65, jobs = 1622044, name = 'Mythic Wand +1' },
        { id = 17427, lvl = 60, jobs = 1622044, name = 'Ebony Wand +1' },
        { id = 17054, lvl = 60, jobs = 1622044, name = 'Ebony Wand' },
        { id = 18854, lvl = 71, jobs = 1590047, name = 'Fourth Mace' },
        { id = 17143, lvl = 48, jobs = 1622044, name = 'Rose Wand +1' },
        { id = 17082, lvl = 50, jobs = 1622044, name = 'Tct.Mag. Wand' },
        { id = 17141, lvl = 32, jobs = 1622044, name = 'Solid Wand' },
        { id = 17052, lvl = 32, jobs = 1622044, name = 'Chestnut Wand' },
        { id = 17140, lvl = 18, jobs = 1622044, name = 'Yew Wand +1' },
        { id = 17442, lvl = 28, jobs = 1622044, name = 'Eremites Wand +1' },
        { id = 17051, lvl = 18, jobs = 1622044, name = 'Yew Wand' },
        { id = 17138, lvl =  9, jobs = 1622044, name = 'Willow Wand +1' },
        { id = 17050, lvl =  9, jobs = 1622044, name = 'Willow Wand' },
        { id = 17445, lvl = 15, jobs = 4194303, name = 'Federation Club' },
        { id = 17444, lvl = 15, jobs = 4194303, name = 'Windurstian Club' },
        { id = 17087, lvl =  1, jobs = 1622044, name = 'Maple Wand +1' },
        { id = 17049, lvl =  1, jobs = 1622044, name = 'Maple Wand' },
        { id = 17417, lvl =  5, jobs = 4194303, name = 'Rabbit Stick' },
        { id = 17137, lvl =  1, jobs = 4194303, name = 'Ash Club +1' },
    },
    staff =
    {
        { id = 22087, lvl = 99, jobs = 1597518, name = 'Malignance Pole' },
        { id = 22056, lvl = 99, jobs = 4194303, name = 'Gozuki Mezuki' },
        { id = 22086, lvl = 99, jobs = 1590047, name = 'Xoanon' },
        { id = 17552, lvl = 51, jobs = 4194303, name = 'Terras Staff' },
        { id = 17551, lvl = 51, jobs = 4194303, name = 'Earth Staff' },
        { id = 18595, lvl = 73, jobs = 4194303, name = 'Mekki Shakki' },
        { id = 17591, lvl = 73, jobs =    8262, name = 'Primate Staff +1' },
        { id = 17575, lvl = 72, jobs =       8, name = 'Somnus Signa' },
        { id = 18598, lvl = 71, jobs = 4194303, name = 'Prester' },
        { id = 18582, lvl = 70, jobs = 1590047, name = 'Yigit Staff' },
        { id = 18597, lvl = 69, jobs = 1590047, name = 'Catalyst' },
        { id = 17544, lvl = 60, jobs =    8262, name = 'Battle Staff +1' },
        { id = 17543, lvl = 60, jobs =    8262, name = 'Battle Staff' },
        { id = 17129, lvl = 50, jobs = 1589262, name = 'Musketeers Pole' },
        { id = 17524, lvl = 45, jobs =    8262, name = 'Footmans Staff' },
        { id = 17523, lvl = 45, jobs =    8262, name = 'Quarterstaff' },
        { id = 17120, lvl = 40, jobs = 1589262, name = 'Oak Pole +1' },
        { id = 17098, lvl = 40, jobs = 1589262, name = 'Oak Pole' },
        { id = 17135, lvl = 50, jobs = 1590047, name = 'Walrus Staff' },
        { id = 17580, lvl = 33, jobs = 3851870, name = 'Military Pole' },
        { id = 17119, lvl = 30, jobs = 1589262, name = 'Elm Pole +1' },
        { id = 17097, lvl = 30, jobs = 1589262, name = 'Elm Pole' },
        { id = 17425, lvl = 25, jobs =    8262, name = 'Spiked Club +1' },
        { id = 17127, lvl = 39, jobs = 1590047, name = 'Oak Staff +1' },
        { id = 17424, lvl = 25, jobs =    8262, name = 'Spiked Club' },
        { id = 17091, lvl = 39, jobs = 1590047, name = 'Oak Staff' },
        { id = 17103, lvl = 18, jobs = 1589262, name = 'Mercenarys Pole' },
        { id = 17117, lvl = 30, jobs = 1590047, name = 'Hypno Staff' },
        { id = 17124, lvl = 16, jobs = 1589262, name = 'Holly Pole +1' },
        { id = 18605, lvl = 29, jobs = 1590047, name = 'Melampus Staff' },
        { id = 17542, lvl = 15, jobs = 1590047, name = 'Republic Staff' },
        { id = 17116, lvl = 20, jobs = 1590047, name = 'Misery Staff' },
        { id = 17594, lvl = 10, jobs = 4194303, name = 'Gelong Staff' },
        { id = 17128, lvl = 10, jobs = 1590047, name = 'Lgn. Staff' },
        { id = 17123, lvl =  1, jobs = 1590047, name = 'Ash Staff +1' },
        { id = 17088, lvl =  1, jobs = 1590047, name = 'Ash Staff' },
    },
    staff_mage =
    {
        { id = 22055, lvl = 99, jobs = 1589788, name = 'Oranyan' },
        { id = 22086, lvl = 99, jobs = 1590047, name = 'Xoanon' },
        { id = 18593, lvl = 73, jobs = 1589788, name = 'Alkalurops' },
        { id = 18594, lvl = 75, jobs = 1589788, name = 'Dorje' },
        { id = 18633, lvl = 51, jobs = 4194303, name = 'Chatoyant Staff' },
        { id = 18632, lvl = 51, jobs = 4194303, name = 'Iridal Staff' },
        { id = 17574, lvl = 60, jobs =   16384, name = 'Archalauss Pole' },
        { id = 18585, lvl = 68, jobs = 1590047, name = 'Kinnara Pole' },
        { id = 17563, lvl = 66, jobs = 1590047, name = 'Power Staff' },
        { id = 17573, lvl = 40, jobs =   16384, name = 'Himmel Stock' },
        { id = 18615, lvl = 39, jobs = 1590047, name = 'Passaddhi Staff +1' },
        { id = 18616, lvl = 43, jobs = 1590047, name = 'Qi Staff +1' },
        { id = 18606, lvl = 39, jobs = 1590047, name = 'Passaddhi Staff' },
        { id = 18605, lvl = 29, jobs = 1590047, name = 'Melampus Staff' },
        { id = 18604, lvl = 27, jobs = 1590047, name = 'Astaroth Cane' },
        { id = 17132, lvl = 17, jobs = 1590047, name = 'Monster Signa' },
        { id = 18599, lvl = 15, jobs = 1590047, name = 'Pestle' },
        { id = 17128, lvl = 10, jobs = 1590047, name = 'Lgn. Staff' },
        { id = 17130, lvl = 10, jobs = 1590047, name = 'Freeswords Staff' },
        { id = 17123, lvl =  1, jobs = 1590047, name = 'Ash Staff +1' },
        { id = 17088, lvl =  1, jobs = 1590047, name = 'Ash Staff' },
    },
}

-----------------------------------
-- Offhand (Shield & Grip) Pools
-----------------------------------
testGear.SUBS =
{
    shield =
    {
        { id = 26487, lvl = 99, jobs =     337, name = 'Sacro Bulwark' },
        { id = 27645, lvl = 99, jobs = 1622556, name = 'Genmei Shield' },
        { id = 28654, lvl = 99, jobs =    2385, name = 'Beatific Shield +1' },
        { id = 26420, lvl = 99, jobs =     385, name = 'Adapa Shield' },
        { id = 26421, lvl = 99, jobs =   66560, name = 'Nusku Shield' },
        { id = 28657, lvl = 99, jobs =    2529, name = 'Kaidate' },
        { id = 28658, lvl = 99, jobs = 3719388, name = 'Sors Shield' },
        { id = 12296, lvl = 74, jobs = 1622556, name = 'Genbus Shield' },
        { id = 12386, lvl = 75, jobs =   33169, name = 'Acheron Shield +1' },
        { id = 12407, lvl = 72, jobs =      64, name = 'Palmerins Shield' },
        { id = 12360, lvl = 72, jobs =    2529, name = 'Tatami Shield' },
        { id = 16181, lvl = 69, jobs =     193, name = 'Terror Shield' },
        { id = 12361, lvl = 70, jobs =    2385, name = 'Sipar' },
        { id = 16165, lvl = 70, jobs =    2421, name = 'Storm Shield' },
        { id = 16179, lvl = 71, jobs =  393248, name = 'Airy Buckler' },
        { id = 16177, lvl = 71, jobs = 4194303, name = 'Legion Scutum' },
        { id = 16180, lvl = 69, jobs = 1622044, name = 'Harpy Shield' },
        { id = 16172, lvl = 60, jobs =     193, name = 'Iron Ram Shield' },
        { id = 12347, lvl = 59, jobs =    2385, name = 'Spiked Buckler' },
        { id = 12380, lvl = 50, jobs =       4, name = 'Divine Shield' },
        { id = 12317, lvl = 58, jobs = 3719388, name = 'Flame Shield' },
        { id = 12412, lvl = 55, jobs =    2421, name = 'Hoplon +1' },
        { id = 12312, lvl = 50, jobs =     193, name = 'R.K. Army Shield' },
        { id = 12363, lvl = 60, jobs = 1720332, name = 'Ptr.Prt. Shield' },
        { id = 16168, lvl = 50, jobs =    2385, name = 'Sentinel Shield' },
        { id = 12329, lvl = 48, jobs =    2421, name = 'Leather Shield +1' },
        { id = 12405, lvl = 38, jobs =     193, name = 'Jennet Shield' },
        { id = 12349, lvl = 40, jobs =    2385, name = 'Balance Buckler' },
        { id = 12336, lvl = 40, jobs =    2421, name = 'Ryl.Sqr. Shield' },
        { id = 16186, lvl = 42, jobs = 3719388, name = 'Spellcasters Ecu' },
        { id = 12365, lvl = 39, jobs = 3719388, name = 'Nymph Shield +1' },
        { id = 16182, lvl = 30, jobs = 4194303, name = 'Town Mog. Shield' },
        { id = 12337, lvl = 20, jobs =    2385, name = 'Decurions Shield' },
        { id = 12334, lvl = 20, jobs =    2421, name = 'Strong Shield' },
        { id = 12371, lvl =  9, jobs =     193, name = 'Clipeus' },
        { id = 12325, lvl =  9, jobs =    2385, name = 'Aspis +1' },
        { id = 12330, lvl =  8, jobs =    2421, name = 'Maple Shield +1' },
        { id = 16185, lvl =  8, jobs = 3719388, name = 'Pelte' },
        { id = 28651, lvl =  1, jobs = 4194303, name = 'Metal Slime Shield' },
    },
    grip_melee =
    {
    },
    grip_tank =
    {
    },
    grip_caster =
    {
    },
}

-----------------------------------
-- Ranged & Instrument Pools
-----------------------------------
testGear.RANGED =
{
    bow =
    {
        { id = 22169, lvl = 99, jobs =    1024, name = 'Artemiss Bow +2' },
        { id = 22107, lvl = 99, jobs =    7665, name = 'Ullr' },
        { id = 18143, lvl = 71, jobs =    3072, name = 'Shigeto Bow +1' },
        { id = 18728, lvl = 71, jobs =    3265, name = 'Cobra Bow' },
        { id = 17158, lvl = 73, jobs =  581625, name = 'Rune Bow' },
        { id = 19215, lvl = 69, jobs =    3072, name = 'Amanokakoyumi' },
        { id = 19216, lvl = 69, jobs =    7665, name = 'Failnaught' },
        { id = 17187, lvl = 55, jobs =    1024, name = 'Eurytos Bow' },
        { id = 17173, lvl = 50, jobs =    3265, name = 'War Bow +1' },
        { id = 17189, lvl = 58, jobs =    7665, name = 'Rapid Bow +1' },
        { id = 17182, lvl = 50, jobs =    7665, name = 'Kaman +1' },
        { id = 17181, lvl = 40, jobs =    3265, name = 'Battle Bow +1' },
        { id = 17180, lvl = 30, jobs =    3265, name = 'Great Bow +1' },
        { id = 17179, lvl = 36, jobs =    7665, name = 'Composite Bow +1' },
        { id = 17208, lvl = 30, jobs =    7665, name = 'Hamayumi' },
        { id = 17202, lvl = 20, jobs =    7665, name = 'Platoon Bow' },
        { id = 17178, lvl = 16, jobs =    3265, name = 'Power Bow +1' },
        { id = 17167, lvl = 10, jobs =    3265, name = 'Ryl.Arc. Longbow' },
        { id = 17176, lvl =  7, jobs =    7665, name = 'Self Bow +1' },
        { id = 17175, lvl =  1, jobs =    7665, name = 'Shortbow +1' },
        { id = 22132, lvl =  1, jobs = 4194303, name = 'Artemiss Bow +1' },
    },
    crossbow =
    {
        { id = 22119, lvl = 99, jobs =    1024, name = 'Wochowsen' },
        { id = 22167, lvl = 99, jobs =    1185, name = 'Dathaba Crossbow' },
        { id = 22170, lvl = 99, jobs =   66560, name = 'Exeter' },
        { id = 17214, lvl = 74, jobs =    1185, name = 'Staurobow +1' },
        { id = 19207, lvl = 71, jobs =   65536, name = 'Great Cassandra' },
        { id = 17244, lvl = 67, jobs =    1024, name = 'Othinus Bow' },
        { id = 17243, lvl = 63, jobs =    1185, name = 'Velocity Bow +1' },
        { id = 17227, lvl = 60, jobs =    1185, name = 'Heavy Crossbow+1' },
        { id = 19217, lvl = 69, jobs =   66560, name = 'Basilisk' },
        { id = 17226, lvl = 50, jobs =    1185, name = 'Arbalest +1' },
        { id = 17268, lvl = 42, jobs =    5120, name = 'Negoroshiki +1' },
        { id = 17247, lvl = 37, jobs =    1185, name = 'Rikonodo' },
        { id = 17229, lvl = 30, jobs =    1185, name = 'Zamburak +1' },
        { id = 17211, lvl = 20, jobs =    1185, name = 'Almogavar Bow' },
        { id = 17266, lvl = 19, jobs =    5120, name = 'Tanegashima +1' },
        { id = 17223, lvl = 10, jobs =    1185, name = 'Lgn. Crossbow' },
        { id = 17228, lvl =  1, jobs =    1153, name = 'Light Crossbow +1' },
        { id = 19221, lvl =  5, jobs =   70688, name = 'Firefly' },
        { id = 21280, lvl =  1, jobs = 4194303, name = 'Decazoom Mk-Xi' },
    },
    gun =
    {
        { id = 22119, lvl = 99, jobs =    1024, name = 'Wochowsen' },
        { id = 19209, lvl = 99, jobs =   65536, name = 'Molybdosis' },
        { id = 21274, lvl = 99, jobs =   70688, name = 'Donar Gun' },
        { id = 19266, lvl = 77, jobs =    1185, name = 'Darkwing +1' },
        { id = 18147, lvl = 73, jobs =    1056, name = 'Culverin +1' },
        { id = 19207, lvl = 71, jobs =   65536, name = 'Great Cassandra' },
        { id = 17264, lvl = 70, jobs =    1024, name = 'Hellfire +1' },
        { id = 19217, lvl = 69, jobs =   66560, name = 'Basilisk' },
        { id = 19227, lvl = 61, jobs =   70688, name = 'Blunderbuss +1' },
        { id = 17235, lvl = 58, jobs =    1185, name = 'Armbrust' },
        { id = 17253, lvl = 50, jobs =    1024, name = 'Musketeer Gun' },
        { id = 17261, lvl = 56, jobs =   66560, name = 'Matchlock Gun +1' },
        { id = 17274, lvl = 46, jobs =   70688, name = 'Deluxe Carbine' },
        { id = 17247, lvl = 37, jobs =    1185, name = 'Rikonodo' },
        { id = 17272, lvl = 30, jobs =   70688, name = 'Military Gun' },
        { id = 17271, lvl = 20, jobs =   70688, name = 'Platoon Gun' },
        { id = 17266, lvl = 19, jobs =    5120, name = 'Tanegashima +1' },
        { id = 19221, lvl =  5, jobs =   70688, name = 'Firefly' },
        { id = 22154, lvl =  1, jobs = 4194303, name = 'Silver Gun+1' },
    },
    throwing =
    {
        { id = 22267, lvl = 99, jobs =    1057, name = 'Antitail +1' },
        { id = 21390, lvl = 99, jobs =  299040, name = 'Albin Bane' },
        { id = 21340, lvl = 99, jobs = 4194303, name = 'Halakaala' },
        { id = 18245, lvl = 75, jobs = 4194303, name = 'Aureole' },
        { id = 17295, lvl = 68, jobs =  299040, name = 'Rising Sun +1' },
        { id = 17294, lvl = 55, jobs =    1057, name = 'Comet Tail' },
        { id = 17279, lvl = 57, jobs =  299040, name = 'Moonring Blade +1' },
        { id = 18135, lvl = 43, jobs =  299040, name = 'Jr.Msk.Chakram +2' },
        { id = 17283, lvl = 40, jobs =  299040, name = 'Jr.Msk. Chakram' },
        { id = 17293, lvl = 47, jobs =    1057, name = 'Yagudo Freezer' },
        { id = 17282, lvl = 40, jobs =    1057, name = 'Cmb.Cst. Bmerang' },
        { id = 17289, lvl = 28, jobs =  299040, name = 'Chakram +1' },
        { id = 18170, lvl = 20, jobs =    1056, name = 'Platoon Edge' },
        { id = 18171, lvl = 20, jobs =  299040, name = 'Platoon Disc' },
        { id = 17291, lvl = 19, jobs =    1057, name = 'Flame Boomerang' },
        { id = 17290, lvl =  6, jobs =    1057, name = 'Coarse Boomerang' },
        { id = 22282, lvl =  1, jobs = 4194303, name = 'Grudge' },
    },
    instrument =
    {
    },
    animator =
    {
    },
    handbell =
    {
    },
    chakram_dnc =
    {
        { id = 21390, lvl = 99, jobs =  299040, name = 'Albin Bane' },
        { id = 21368, lvl = 99, jobs =  299040, name = 'Bestas Bane' },
        { id = 18692, lvl = 70, jobs = 4194303, name = 'Mamoolbane' },
        { id = 18694, lvl = 70, jobs = 4194303, name = 'Trollbane' },
        { id = 18693, lvl = 70, jobs = 4194303, name = 'Lamiabane' },
        { id = 21340, lvl = 99, jobs = 4194303, name = 'Halakaala' },
        { id = 17295, lvl = 68, jobs =  299040, name = 'Rising Sun +1' },
        { id = 18231, lvl = 61, jobs =  294912, name = 'Death Chakram' },
        { id = 17279, lvl = 57, jobs =  299040, name = 'Moonring Blade +1' },
        { id = 18135, lvl = 43, jobs =  299040, name = 'Jr.Msk.Chakram +2' },
        { id = 17283, lvl = 40, jobs =  299040, name = 'Jr.Msk. Chakram' },
        { id = 17289, lvl = 28, jobs =  299040, name = 'Chakram +1' },
        { id = 18171, lvl = 20, jobs =  299040, name = 'Platoon Disc' },
        { id = 18246, lvl = 15, jobs =  299040, name = 'Rogetsurin' },
    },
}

-----------------------------------
-- Ammo & Stat-Sachet Pools
-----------------------------------
testGear.AMMO =
{
    arrow =
    {
        { id = 21298, lvl = 99, jobs =    1024, name = 'Artemiss Arrow', qty = 99 },
        { id = 21309, lvl = 99, jobs =    7665, name = 'Chapuli Arrow', qty = 99 },
        { id = 17325, lvl = 70, jobs =    7665, name = 'Kabura Arrow', qty = 99 },
        { id = 18740, lvl = 60, jobs =    7665, name = 'Cmb.Cst. Arrow', qty = 99 },
        { id = 17333, lvl = 70, jobs =  581625, name = 'Rune Arrow', qty = 99 },
        { id = 18178, lvl = 50, jobs =    7665, name = 'Bodkin Arrow', qty = 99 },
        { id = 18155, lvl = 40, jobs =    7665, name = 'Scorpion Arrow', qty = 99 },
        { id = 18156, lvl = 29, jobs =    7665, name = 'Horn Arrow', qty = 99 },
        { id = 17332, lvl = 15, jobs =    7665, name = 'Fang Arrow', qty = 99 },
        { id = 17319, lvl =  7, jobs =    7665, name = 'Bone Arrow', qty = 99 },
        { id = 17318, lvl =  1, jobs = 4194303, name = 'Wooden Arrow', qty = 99 },
        { id = 17330, lvl =  1, jobs =    7665, name = 'Stone Arrow', qty = 99 },
    },
    bolt =
    {
        { id = 21313, lvl = 99, jobs =    1185, name = 'Gashing Bolt', qty = 99 },
        { id = 18739, lvl = 60, jobs =    1153, name = 'Irn.Msk. Bolt', qty = 99 },
        { id = 19200, lvl = 45, jobs =    1153, name = 'Black Bolt', qty = 99 },
        { id = 17337, lvl = 40, jobs =    1153, name = 'Mythril Bolt', qty = 99 },
        { id = 18153, lvl = 30, jobs =    1153, name = 'Holy Bolt', qty = 99 },
        { id = 18152, lvl = 25, jobs =    1185, name = 'Venom Bolt', qty = 99 },
        { id = 18148, lvl = 15, jobs =    1185, name = 'Acid Bolt', qty = 99 },
        { id = 18150, lvl = 10, jobs =    1185, name = 'Blind Bolt', qty = 99 },
        { id = 17336, lvl =  1, jobs = 4194303, name = 'Crossbow Bolt', qty = 99 },
        { id = 17339, lvl =  1, jobs =    1153, name = 'Bronze Bolt', qty = 99 },
    },
    bullet =
    {
        { id = 21327, lvl = 99, jobs =    1024, name = 'Eradicating Bullet', qty = 99 },
        { id = 21296, lvl = 99, jobs =   66560, name = 'Chrono Bullet', qty = 99 },
        { id = 21330, lvl = 99, jobs =   70688, name = 'Decimating Bullet', qty = 99 },
        { id = 19236, lvl = 75, jobs =    1024, name = 'Hightail Bullet', qty = 99 },
        { id = 18723, lvl = 66, jobs =   66560, name = 'Steel Bullet', qty = 99 },
        { id = 17341, lvl = 50, jobs =    1024, name = 'Silver Bullet', qty = 99 },
        { id = 17312, lvl = 50, jobs =   70688, name = 'Iron Bullet', qty = 99 },
        { id = 19201, lvl = 40, jobs =    1024, name = 'Electrum Bullet', qty = 99 },
        { id = 19228, lvl = 35, jobs =   70688, name = 'Paktong Bullet', qty = 99 },
        { id = 17340, lvl = 22, jobs =   70688, name = 'Bullet', qty = 99 },
        { id = 18713, lvl = 15, jobs =    1024, name = 'Copper Bullet', qty = 99 },
        { id = 19229, lvl = 11, jobs =   70688, name = 'Tin Bullet', qty = 99 },
        { id = 17343, lvl =  1, jobs = 4194303, name = 'Bronze Bullet', qty = 99 },
    },
    shuriken =
    {
        { id = 22292, lvl = 99, jobs =    4096, name = 'Date Shuriken', qty = 99 },
        { id = 18712, lvl = 75, jobs =    4096, name = 'Koga Shuriken', qty = 99 },
        { id = 17304, lvl = 60, jobs =    4096, name = 'Fuma Shuriken', qty = 99 },
        { id = 17303, lvl = 48, jobs =    4096, name = 'Manji Shuriken', qty = 99 },
        { id = 17302, lvl = 28, jobs =    4096, name = 'Juji Shuriken', qty = 99 },
        { id = 17301, lvl = 18, jobs =    4096, name = 'Shuriken', qty = 99 },
        { id = 17296, lvl =  1, jobs =   30639, name = 'Pebble', qty = 99 },
    },
    oil =
    {
        { id = 19185, lvl = 80, jobs =  131072, name = 'Automat. Oil +3', qty = 12 },
        { id = 18733, lvl = 50, jobs =  131072, name = 'Automat. Oil +2', qty = 12 },
        { id = 18732, lvl = 30, jobs =  131072, name = 'Automat. Oil +1', qty = 12 },
        { id = 18731, lvl = 15, jobs =  131072, name = 'Automaton Oil', qty = 12 },
    },
    orphic_egg =
    {
        { id = 18256, lvl =  1, jobs = 4194303, name = 'Orphic Egg' },
    },
    ammo_tp =
    {
        { id = 21371, lvl = 99, jobs = 2473971, name = 'Ginsen' },
        { id = 21363, lvl = 99, jobs = 4194303, name = 'Hasty Pinion +1' },
        { id = 19258, lvl = 83, jobs = 2363424, name = 'Qirmiz Tathlum' },
        { id = 19213, lvl = 70, jobs = 4194303, name = 'White Tathlum' },
        { id = 18254, lvl = 58, jobs = 4194303, name = 'Tiphia Sting' },
        { id = 18175, lvl = 50, jobs = 4194303, name = 'Optical Needle' },
        { id = 19243, lvl = 30, jobs = 4194303, name = 'Brio Dart' },
        { id = 19186, lvl = 15, jobs = 4194303, name = 'Tiny Tathlum' },
        { id = 18166, lvl =  1, jobs = 4194303, name = 'Happy Egg' },
    },
    ammo_ws =
    {
        { id = 19253, lvl = 84, jobs =       1, name = 'Ravagers Orb' },
        { id = 19249, lvl = 78, jobs = 2500642, name = 'Thew Bomblet' },
        { id = 18707, lvl = 70, jobs = 2101409, name = 'Fire Bomblet' },
        { id = 18139, lvl = 63, jobs = 2101409, name = 'Bomb Core' },
        { id = 18180, lvl = 55, jobs = 2101409, name = 'Goblin Grenade' },
        { id = 18175, lvl = 50, jobs = 4194303, name = 'Optical Needle' },
        { id = 19243, lvl = 30, jobs = 4194303, name = 'Brio Dart' },
        { id = 19186, lvl = 15, jobs = 4194303, name = 'Tiny Tathlum' },
        { id = 18166, lvl =  1, jobs = 4194303, name = 'Happy Egg' },
    },
    ammo_tank =
    {
        { id = 21347, lvl = 75, jobs = 4194303, name = 'Charitoni Sling' },
        { id = 19242, lvl = 73, jobs = 4194303, name = 'Aumoniere +1' },
        { id = 19213, lvl = 70, jobs = 4194303, name = 'White Tathlum' },
        { id = 19219, lvl = 69, jobs = 4194303, name = 'Iwatsubute' },
        { id = 18257, lvl = 60, jobs = 4194303, name = 'Bibiki Seashell' },
        { id = 18175, lvl = 50, jobs = 4194303, name = 'Optical Needle' },
        { id = 19186, lvl = 15, jobs = 4194303, name = 'Tiny Tathlum' },
        { id = 18166, lvl =  1, jobs = 4194303, name = 'Happy Egg' },
    },
    ammo_caster =
    {
        { id = 22271, lvl = 99, jobs = 4194303, name = 'Pemphredo Tathlum' },
        { id = 22252, lvl = 99, jobs = 4194303, name = 'Sapience Orb' },
        { id = 19257, lvl = 83, jobs =  524356, name = 'Incantor Stone' },
        { id = 19250, lvl = 79, jobs = 1589788, name = 'Witchstone' },
        { id = 19270, lvl = 78, jobs = 4194303, name = 'Quartz Tathlum' },
        { id = 17277, lvl = 70, jobs = 4194303, name = 'Hedgehog Bomb' },
        { id = 18140, lvl = 66, jobs = 4194303, name = 'Phtm. Tathlum' },
        { id = 19238, lvl = 56, jobs = 4194303, name = 'Jasper Tathlum' },
        { id = 18174, lvl = 50, jobs = 1622044, name = 'Mantra Coin' },
        { id = 18136, lvl = 25, jobs = 4194303, name = 'Morion Tathlum' },
        { id = 19223, lvl = 11, jobs = 4194303, name = 'Attar Of Roses' },
        { id = 18167, lvl =  1, jobs = 4194303, name = 'Fortune Egg' },
        { id = 18256, lvl =  1, jobs = 4194303, name = 'Orphic Egg' },
    },
}
testGear.AMMO.ammo_melee = testGear.AMMO.ammo_tp

-----------------------------------
-- Role Armor & Accessory Pools (tp, ws, tank, ranged, caster)
-----------------------------------
testGear.ROLE_GEAR =
{
    tp =
    {
        HEAD =
        {
            { id = 27783, lvl = 99, jobs = 2363683, name = 'Skormoth Mask' },
            { id = 27730, lvl = 99, jobs = 2458912, name = 'Iuitl Headgear +1' },
            { id = 23097, lvl = 99, jobs =    4096, name = 'Hattori Zukin +2' },
            { id = 23085, lvl = 99, jobs =       1, name = 'Boii Mask +2' },
            { id = 25572, lvl = 99, jobs = 2130452, name = 'Aya. Zucchetto +2' },
            { id = 23761, lvl = 99, jobs = 4194303, name = 'Nyame Helm' },
            { id = 15223, lvl = 74, jobs =   10368, name = 'Aces Helm' },
            { id = 16106, lvl = 75, jobs =   10689, name = 'Askar Zucchetto' },
            { id = 16092, lvl = 75, jobs =  137218, name = 'Usukane Somen' },
            { id = 16107, lvl = 75, jobs = 2462754, name = 'Denali Bonnet' },
            { id = 11497, lvl = 75, jobs = 3662710, name = 'Spurrer Beret' },
            { id = 11498, lvl = 59, jobs = 2472947, name = 'Zeal Cap +1' },
            { id = 15241, lvl = 75, jobs =   49180, name = 'Nashira Turban' },
            { id = 15221, lvl = 60, jobs = 2106337, name = 'Patrocluss Helm' },
            { id = 16148, lvl = 68, jobs = 2589730, name = 'Cobra Cap' },
            { id = 13867, lvl = 70, jobs =   66592, name = 'War Beret +1' },
            { id = 11495, lvl = 59, jobs = 2472947, name = 'Zeal Cap' },
            { id = 27659, lvl = 45, jobs = 2426144, name = 'Idis Mask' },
            { id = 15260, lvl = 70, jobs = 1589788, name = 'Hydra Beret' },
            { id = 27658, lvl = 45, jobs =    8385, name = 'Ates Mask' },
            { id = 27660, lvl = 45, jobs =  137218, name = 'Genta Kabuto' },
            { id = 16065, lvl = 50, jobs = 4194303, name = 'Storm Zucchetto' },
            { id = 11493, lvl = 25, jobs = 2473969, name = 'Precision Bandana' },
            { id = 16087, lvl = 35, jobs =    8385, name = 'Deimoss Mask' },
            { id = 16095, lvl = 35, jobs =  137218, name = 'Hikazu Kabuto' },
            { id = 13904, lvl = 34, jobs = 3662710, name = 'Fed. Headgear' },
            { id = 16086, lvl = 25, jobs =    8385, name = 'Phoboss Mask' },
            { id = 15219, lvl = 39, jobs = 4179646, name = 'Sinister Mask' },
            { id = 12470, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Headgear' },
            { id = 16094, lvl = 25, jobs =  137218, name = 'T.Kazu Jinpachi' },
            { id = 16085, lvl = 15, jobs =    8385, name = 'Enyos Mask' },
            { id = 13830, lvl = 30, jobs = 4179646, name = 'Lgn. Circlet' },
            { id = 12484, lvl = 20, jobs =    6146, name = 'Mrc. Hachimaki' },
            { id = 15186, lvl = 20, jobs = 4194303, name = 'Trump Crown' },
            { id = 15208, lvl = 20, jobs = 4179646, name = 'Barons Chapeau' },
            { id = 12487, lvl = 10, jobs = 2141649, name = 'Faceguard +1' },
            { id = 12432, lvl = 10, jobs = 2141649, name = 'Faceguard' },
            { id = 12509, lvl = 10, jobs = 2472947, name = 'Legionnaires Cap' },
            { id = 12510, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Bandana' },
            { id = 16144, lvl = 10, jobs = 4194303, name = 'Sol Cap' },
            { id = 11811, lvl =  1, jobs = 4194303, name = 'Destrier Beret' },
            { id = 12463, lvl =  1, jobs = 2472947, name = 'Bronze Cap +1' },
            { id = 10385, lvl =  1, jobs = 4194303, name = 'Cumulus Masque +1' },
            { id = 12448, lvl =  1, jobs = 2472947, name = 'Bronze Cap' },
        },
        BODY =
        {
            { id = 23170, lvl = 99, jobs =  262144, name = 'Maculele Casaque +2' },
            { id = 23163, lvl = 99, jobs =    2048, name = 'Kasuga Domaru +2' },
            { id = 23447, lvl = 99, jobs =      32, name = 'Pillagers Vest +3' },
            { id = 23152, lvl = 99, jobs =       1, name = 'Boii Lorica +2' },
            { id = 23165, lvl = 99, jobs =    8192, name = 'Peltasts Plackart +2' },
            { id = 23765, lvl = 99, jobs =  137218, name = 'Mpacas Doublet' },
            { id = 23733, lvl = 99, jobs =  496946, name = 'Malignance Tabard' },
            { id = 23764, lvl = 99, jobs =     193, name = 'Sakpatas Breastplate' },
            { id = 25763, lvl = 99, jobs = 2130452, name = 'Ayanmo Corazza +1' },
            { id = 25765, lvl = 99, jobs =  147712, name = 'Taliah Manteel +1' },
            { id = 25794, lvl = 99, jobs = 1605656, name = 'Jhakri Robe +2' },
            { id = 14554, lvl = 75, jobs =  137218, name = 'Usukane Haramaki' },
            { id = 11281, lvl = 75, jobs =    7171, name = 'Hachiryu Haramaki' },
            { id = 11282, lvl = 72, jobs =    8641, name = 'Aurum Cuirass' },
            { id = 14371, lvl = 73, jobs =     385, name = 'Armada Hauberk' },
            { id = 14590, lvl = 68, jobs = 2589730, name = 'Cobra Harness' },
            { id = 14404, lvl = 50, jobs =    2048, name = 'Shm. Hara-Ate' },
            { id = 14439, lvl = 70, jobs =    2048, name = 'Hmn. Domaru +1' },
            { id = 13793, lvl = 69, jobs =     385, name = 'Hauberk +1' },
            { id = 14570, lvl = 75, jobs = 1720860, name = 'Goliard Saio' },
            { id = 13735, lvl = 59, jobs =    6593, name = 'Haubergeon +1' },
            { id = 14403, lvl = 50, jobs =  262176, name = 'Rapparee Harness' },
            { id = 12555, lvl = 59, jobs =    6593, name = 'Haubergeon' },
            { id = 13734, lvl = 57, jobs = 2472947, name = 'Scp. Harness +1' },
            { id = 14515, lvl = 70, jobs = 1589788, name = 'Hydra Doublet' },
            { id = 27799, lvl = 45, jobs = 2426144, name = 'Idis Jerkin' },
            { id = 14445, lvl = 45, jobs =    6593, name = 'Luisant Haubert' },
            { id = 27801, lvl = 45, jobs =   16900, name = 'Namrus Jubbah' },
            { id = 27798, lvl = 45, jobs =    8385, name = 'Ates Cuirass' },
            { id = 27800, lvl = 45, jobs =  137218, name = 'Genta Hara-Ate' },
            { id = 13755, lvl = 59, jobs = 3069758, name = 'Flora Cotehardie' },
            { id = 13728, lvl = 40, jobs =    6146, name = 'Jujitsu Gi' },
            { id = 14557, lvl = 35, jobs =  137218, name = 'Hikazu Hara-Ate' },
            { id = 11349, lvl = 57, jobs = 1720332, name = 'Vivacity Coat +1' },
            { id = 13813, lvl = 40, jobs =       4, name = 'Divine Breastplate' },
            { id = 12606, lvl = 50, jobs = 4179646, name = 'Tct.Mgc. Coat' },
            { id = 12559, lvl = 40, jobs =    6593, name = 'Ryl.Sqr. Chainmail' },
            { id = 11338, lvl = 32, jobs = 2615158, name = 'Aegas Doublet' },
            { id = 14556, lvl = 25, jobs =  137218, name = 'Tsukikazu Togi' },
            { id = 14465, lvl = 30, jobs =    4096, name = 'Nanban Kariginu' },
            { id = 13719, lvl = 40, jobs = 4179646, name = 'Ryl.Sqr. Robe' },
            { id = 12598, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Doublet' },
            { id = 14435, lvl = 29, jobs =      65, name = 'Kampfbrust' },
            { id = 12566, lvl = 30, jobs = 2141649, name = 'Ctr. Scale Mail' },
            { id = 14427, lvl = 29, jobs = 1720332, name = 'Seers Tunic +1' },
            { id = 13818, lvl = 18, jobs = 4194303, name = 'Garrison Tunica' },
            { id = 14555, lvl = 15, jobs =  137218, name = 'Hoshikazu Gi' },
            { id = 12653, lvl = 20, jobs =    6146, name = 'Mercenarys Gi' },
            { id = 14447, lvl = 20, jobs = 4179646, name = 'Barons Saio' },
            { id = 12668, lvl =  8, jobs =    6146, name = 'Kenpogi +1' },
            { id = 12661, lvl = 10, jobs = 2141649, name = 'Solid Mail' },
            { id = 12560, lvl = 10, jobs = 2141649, name = 'Scale Mail' },
            { id = 12629, lvl = 10, jobs = 2472947, name = 'Lgn. Harness' },
            { id = 12607, lvl =  1, jobs = 2472947, name = 'Bronze Harness +1' },
            { id = 11330, lvl =  1, jobs = 4194303, name = 'Blksmith. Smock' },
            { id = 12576, lvl =  1, jobs = 2472947, name = 'Bronze Harness' },
            { id = 12615, lvl =  1, jobs = 4179646, name = 'Robe +1' },
        },
        HANDS =
        {
            { id = 27078, lvl = 99, jobs =    8192, name = 'Pel. Vambraces' },
            { id = 23236, lvl = 99, jobs =  131072, name = 'Karagoz Guanti +2' },
            { id = 23232, lvl = 99, jobs =    8192, name = 'Peltasts Vambraces +2' },
            { id = 23229, lvl = 99, jobs =    1024, name = 'Amini Glovelettes +2' },
            { id = 23734, lvl = 99, jobs =  496946, name = 'Malignance Gloves' },
            { id = 23771, lvl = 99, jobs =     193, name = 'Sakpatas Gauntlets' },
            { id = 23772, lvl = 99, jobs =  137218, name = 'Mpacas Gloves' },
            { id = 23774, lvl = 99, jobs =   16916, name = 'Bunzis Gloves' },
            { id = 23222, lvl = 99, jobs =       8, name = 'Wicce Gloves +2' },
            { id = 23775, lvl = 99, jobs = 4194303, name = 'Nyame Gauntlets' },
            { id = 14877, lvl = 70, jobs =       4, name = 'Blessed Mitts +1' },
            { id = 14878, lvl = 70, jobs =    2048, name = 'Hachiman Kote +1' },
            { id = 14875, lvl = 70, jobs =       4, name = 'Blessed Mitts' },
            { id = 14876, lvl = 70, jobs =    2048, name = 'Hachiman Kote' },
            { id = 14825, lvl = 72, jobs = 2473969, name = 'Dusk Gloves +1' },
            { id = 14969, lvl = 75, jobs =  137218, name = 'Usukane Gote' },
            { id = 15011, lvl = 68, jobs = 2589730, name = 'Cobra Mittens' },
            { id = 14977, lvl = 75, jobs =   32792, name = 'Morrigans Cuffs' },
            { id = 14924, lvl = 70, jobs = 1589788, name = 'Hydra Gloves' },
            { id = 15059, lvl = 65, jobs = 3662710, name = 'Finesse Gloves +1' },
            { id = 15006, lvl = 55, jobs =     193, name = 'Fourth Gauntlets' },
            { id = 14952, lvl = 52, jobs =     192, name = 'Ice Gauntlets' },
            { id = 14939, lvl = 55, jobs = 2473969, name = 'Akinji Bazubands' },
            { id = 13952, lvl = 34, jobs =    6146, name = 'Ochiudos Kote' },
            { id = 14986, lvl = 34, jobs =    6146, name = 'Ochimusha Kote' },
            { id = 14934, lvl = 55, jobs = 2473969, name = 'Jaridah Bazubands' },
            { id = 14843, lvl = 50, jobs =   11521, name = 'Spiked Fng.Gnt.' },
            { id = 15058, lvl = 30, jobs = 3662710, name = 'Combat Mittens +1' },
            { id = 12686, lvl = 50, jobs =    6593, name = 'Ryl.Kgt. Mufflers' },
            { id = 14052, lvl = 45, jobs =    6593, name = 'Luisant Moufles' },
            { id = 14874, lvl = 34, jobs =    6146, name = 'Horomusha Kote' },
            { id = 27940, lvl = 45, jobs =  137218, name = 'Genta Gote' },
            { id = 15053, lvl = 30, jobs = 3662710, name = 'Combat Mittens' },
            { id = 27941, lvl = 45, jobs =   16900, name = 'Namrus Dastanas' },
            { id = 13988, lvl = 60, jobs = 4179646, name = 'Mermans Bangles' },
            { id = 14044, lvl = 25, jobs =    6146, name = 'Federation Tekko' },
            { id = 27942, lvl = 45, jobs = 1605656, name = 'Neits Cuffs' },
            { id = 14034, lvl = 34, jobs =    6593, name = 'Kingdom Mufflers' },
            { id = 12687, lvl = 30, jobs =    6593, name = 'Ryl.Sqr. Mufflers' },
            { id = 12799, lvl = 14, jobs = 3662710, name = 'Battle Gloves' },
            { id = 12743, lvl = 40, jobs = 3851870, name = 'Cmb.Cst. Mitts' },
            { id = 14936, lvl = 50, jobs = 4194303, name = 'Storm Manopolas' },
            { id = 15052, lvl = 13, jobs = 2473969, name = 'Guerilla Gloves' },
            { id = 14979, lvl = 25, jobs =   32792, name = 'Bodbs Cuffs' },
            { id = 12694, lvl = 30, jobs = 2141649, name = 'Ctr. F. Gauntlets' },
            { id = 14970, lvl = 15, jobs =  137218, name = 'Hoshikazu Tekko' },
            { id = 14859, lvl = 29, jobs = 1720332, name = 'Seers Mitts +1' },
            { id = 14032, lvl = 15, jobs = 2472947, name = 'Republic Mittens' },
            { id = 12752, lvl = 10, jobs = 2472947, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Gloves' },
            { id = 14054, lvl = 20, jobs = 4179646, name = 'Barons Cuffs' },
            { id = 12768, lvl = 10, jobs = 2141649, name = 'Solid Fng. Gnt.' },
            { id = 12797, lvl =  9, jobs =     193, name = 'Coarse Gauntlets' },
            { id = 12775, lvl =  8, jobs = 3851870, name = 'Mitts +1' },
            { id = 14831, lvl =  1, jobs = 4194303, name = 'Smithys Mitts' },
            { id = 12695, lvl =  1, jobs = 2472947, name = 'Bronze Mittens +1' },
            { id = 12744, lvl =  1, jobs = 4179646, name = 'Cuffs +1' },
            { id = 12704, lvl =  1, jobs = 2472947, name = 'Bronze Mittens' },
        },
        LEGS =
        {
            { id = 23611, lvl = 99, jobs =    4096, name = 'Mochi. Hakama +3' },
            { id = 23287, lvl = 99, jobs =       2, name = 'Bhikku Hose +2' },
            { id = 23286, lvl = 99, jobs =       1, name = 'Boii Cuisses +2' },
            { id = 23297, lvl = 99, jobs =    2048, name = 'Kasuga Haidate +2' },
            { id = 25870, lvl = 99, jobs = 2130452, name = 'Aya. Cosciales +1' },
            { id = 23782, lvl = 99, jobs = 4194303, name = 'Nyame Flanchard' },
            { id = 15629, lvl = 75, jobs =   66848, name = 'Skadis Chausses' },
            { id = 12818, lvl = 75, jobs =    7939, name = 'Byakkos Haidate' },
            { id = 15633, lvl = 75, jobs =  137218, name = 'Usukane Hizayoroi' },
            { id = 15393, lvl = 70, jobs =       4, name = 'Bls. Trousers +1' },
            { id = 16343, lvl = 72, jobs = 2595874, name = 'Enkidus Subligar' },
            { id = 15576, lvl = 75, jobs =   41184, name = 'Homam Cosciales' },
            { id = 14334, lvl = 50, jobs =    2048, name = 'Shm. Haidate' },
            { id = 15391, lvl = 70, jobs =       4, name = 'Blessed Trousers' },
            { id = 16317, lvl = 68, jobs = 2589730, name = 'Cobra Subligar' },
            { id = 15394, lvl = 70, jobs =    2048, name = 'Hmn. Hakama +1' },
            { id = 15595, lvl = 70, jobs = 1589788, name = 'Hydra Brais' },
            { id = 28081, lvl = 45, jobs =    8385, name = 'Ates Flanchard' },
            { id = 15373, lvl = 47, jobs =      32, name = 'Bravos Subligar' },
            { id = 28082, lvl = 45, jobs = 2426144, name = 'Idis Trousers' },
            { id = 15614, lvl = 70, jobs =     385, name = 'Exorcist Hose' },
            { id = 15597, lvl = 70, jobs =     193, name = 'Hydra Brayettes' },
            { id = 16320, lvl = 69, jobs =    6146, name = 'Kensei Sitabaki' },
            { id = 14318, lvl = 70, jobs =    8193, name = 'Conte Cosciales' },
            { id = 14223, lvl = 56, jobs =     512, name = 'Choral Cannions' },
            { id = 15368, lvl = 50, jobs =      16, name = 'War Hose' },
            { id = 14255, lvl = 53, jobs =    6146, name = 'Mst. Sitabaki +1' },
            { id = 28083, lvl = 45, jobs =  137218, name = 'Genta-No-Hakama' },
            { id = 14216, lvl = 56, jobs =       4, name = 'Healers Pantaln.' },
            { id = 14217, lvl = 56, jobs =       8, name = 'Wizards Tonban' },
            { id = 16314, lvl = 55, jobs = 4179646, name = 'Cobra Slops' },
            { id = 15632, lvl = 35, jobs =   66848, name = 'Freyas Trousers' },
            { id = 15636, lvl = 35, jobs =  137218, name = 'Hikazu Hakama' },
            { id = 15384, lvl = 50, jobs =   16388, name = 'Capri. Subligar' },
            { id = 15375, lvl = 50, jobs = 1064968, name = 'Aries Subligar' },
            { id = 15381, lvl = 50, jobs = 2261520, name = 'Libra Subligar' },
            { id = 15382, lvl = 50, jobs =  524304, name = 'Scorpius Subligar' },
            { id = 12815, lvl = 40, jobs =    6593, name = 'Ryl.Sqr. Breeches' },
            { id = 15628, lvl = 35, jobs =    8385, name = 'Deimoss Cuisses' },
            { id = 14333, lvl = 30, jobs =   66592, name = 'Noct Brais +1' },
            { id = 14260, lvl = 25, jobs = 2472947, name = 'Republic Subligar' },
            { id = 12870, lvl = 40, jobs = 3851870, name = 'Cmb.Cst. Slacks' },
            { id = 15627, lvl = 25, jobs =    8385, name = 'Phoboss Cuisses' },
            { id = 15635, lvl = 25, jobs =  137218, name = 'Tsukikazu Haidate' },
            { id = 14314, lvl = 21, jobs = 4194303, name = 'Garrison Hose' },
            { id = 15626, lvl = 15, jobs =    8385, name = 'Enyos Cuisses' },
            { id = 12882, lvl = 20, jobs = 2473969, name = 'Ryl.Ftm. Trousers' },
            { id = 12855, lvl = 20, jobs =    6146, name = 'Mrc. Sitabaki' },
            { id = 12881, lvl = 20, jobs = 2472947, name = 'Lgn. Subligar' },
            { id = 12917, lvl = 20, jobs = 3851870, name = 'Mages Slacks' },
            { id = 12863, lvl = 10, jobs = 2141649, name = 'Solid Cuisses' },
            { id = 12816, lvl = 10, jobs = 2141649, name = 'Scale Cuisses' },
            { id = 12915, lvl = 10, jobs = 4179646, name = 'Freeswords Slops' },
            { id = 12898, lvl =  8, jobs = 3851870, name = 'Slacks +1' },
            { id = 12899, lvl =  8, jobs =    6146, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, jobs = 2472947, name = 'Brz. Subligar +1' },
            { id = 12832, lvl =  1, jobs = 2472947, name = 'Bronze Subligar' },
            { id = 12897, lvl =  1, jobs = 4179646, name = 'Slops +1' },
            { id = 12856, lvl =  1, jobs = 4179646, name = 'Slops' },
        },
        FEET =
        {
            { id = 23371, lvl = 99, jobs =  262144, name = 'Maculele Toe Shoes +2' },
            { id = 23643, lvl = 99, jobs =       1, name = 'Pumm. Calligae +3' },
            { id = 23366, lvl = 99, jobs =    8192, name = 'Peltasts Schynbalds +2' },
            { id = 23671, lvl = 99, jobs =      32, name = 'Plun. Poulaines +3' },
            { id = 23736, lvl = 99, jobs =  496946, name = 'Malignance Boots' },
            { id = 25951, lvl = 99, jobs = 2130452, name = 'Aya. Gambieras +2' },
            { id = 23789, lvl = 99, jobs = 4194303, name = 'Nyame Sollerets' },
            { id = 15719, lvl = 75, jobs =  137218, name = 'Usukane Sune-Ate' },
            { id = 15661, lvl = 75, jobs =   41184, name = 'Homam Gambieras' },
            { id = 11376, lvl = 72, jobs =    8641, name = 'Aurum Sabatons' },
            { id = 15332, lvl = 70, jobs =    2048, name = 'Hmn. Sune-Ate +1' },
            { id = 14188, lvl = 72, jobs = 2473969, name = 'Dusk Ledelsens +1' },
            { id = 15331, lvl = 70, jobs =       4, name = 'Blessed Pumps +1' },
            { id = 15757, lvl = 68, jobs = 2589730, name = 'Cobra Leggings' },
            { id = 15330, lvl = 70, jobs =    2048, name = 'Hmn. Sune-Ate' },
            { id = 13054, lvl = 39, jobs =    6146, name = 'Fuma Kyahan' },
            { id = 15737, lvl = 39, jobs =    6146, name = 'Sarutobi Kyahan' },
            { id = 11404, lvl = 60, jobs =  131072, name = 'Promptitude Solea' },
            { id = 15680, lvl = 70, jobs = 1589788, name = 'Hydra Gaiters' },
            { id = 15682, lvl = 70, jobs =     193, name = 'Hydra Sollerets' },
            { id = 15744, lvl = 70, jobs = 2473969, name = 'Bowmans Led.' },
            { id = 28218, lvl = 45, jobs =    8385, name = 'Ates Sollerets' },
            { id = 14089, lvl = 52, jobs =       1, name = 'Fighters Calligae' },
            { id = 15739, lvl = 59, jobs = 3662710, name = 'Tabin Boots +1' },
            { id = 11371, lvl = 50, jobs =       2, name = 'Seikenshi Habaki' },
            { id = 28222, lvl = 45, jobs = 1605656, name = 'Neits Pigaches' },
            { id = 15694, lvl = 55, jobs = 2473969, name = 'Akinji Nails' },
            { id = 15722, lvl = 35, jobs =  137218, name = 'Hikazu Sune-Ate' },
            { id = 15691, lvl = 50, jobs = 4194303, name = 'Storm Gambieras' },
            { id = 15718, lvl = 35, jobs =   66848, name = 'Freyas Ledelsens' },
            { id = 14133, lvl = 24, jobs = 2473969, name = 'Winged Boots +1' },
            { id = 15714, lvl = 35, jobs =    8385, name = 'Deimoss Leggings' },
            { id = 14132, lvl = 24, jobs = 2473969, name = 'Winged Boots' },
            { id = 14207, lvl = 30, jobs =   66592, name = 'Noct Gaiters +1' },
            { id = 14152, lvl = 25, jobs =    6146, name = 'Fed. Kyahan' },
            { id = 15348, lvl = 38, jobs = 4194303, name = 'Mountain Gaiters' },
            { id = 13014, lvl =  7, jobs = 2473969, name = 'Leaping Boots' },
            { id = 15351, lvl =  7, jobs = 2473969, name = 'Bounding Boots' },
            { id = 15716, lvl = 15, jobs =   66848, name = 'Njords Ledelsens' },
            { id = 11412, lvl = 17, jobs = 2472947, name = 'Mtt. Leggings +1' },
            { id = 28341, lvl = 30, jobs = 4194303, name = 'Agrarian Boots' },
            { id = 13045, lvl = 20, jobs = 4179646, name = 'Ryl.Ftm. Clogs' },
            { id = 13024, lvl = 10, jobs = 2141649, name = 'Solid Greaves' },
            { id = 12944, lvl = 10, jobs = 2141649, name = 'Scale Greaves' },
            { id = 13003, lvl = 10, jobs = 2472947, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, jobs = 3851870, name = 'Solea +1' },
            { id = 12951, lvl =  1, jobs = 2472947, name = 'Brz. Leggings +1' },
            { id = 12983, lvl =  1, jobs = 4179646, name = 'Ash Clogs +1' },
            { id = 11400, lvl =  1, jobs = 4194303, name = 'Noble Poulaines' },
            { id = 11403, lvl =  1, jobs = 4194303, name = 'Talaria' },
        },
        NECK =
        {
            { id = 26004, lvl = 99, jobs = 4194303, name = 'Lissome Necklace' },
            { id = 25473, lvl = 99, jobs =     512, name = 'Bards Charm +2' },
            { id = 26035, lvl = 99, jobs =    6146, name = 'Moonlight Nodowa' },
            { id = 25485, lvl = 99, jobs =    2048, name = 'Sam. Nodowa +2' },
            { id = 16275, lvl = 74, jobs = 4194303, name = 'Ancient Torque' },
            { id = 13056, lvl = 33, jobs = 4194303, name = 'Peacock Charm' },
            { id = 15515, lvl = 33, jobs = 4194303, name = 'Peacock Amulet' },
            { id = 15523, lvl = 60, jobs = 4194303, name = 'Chivalrous Chain' },
            { id = 11578, lvl = 74, jobs = 2594082, name = 'Tiercel Necklace' },
            { id = 13128, lvl = 59, jobs = 2465590, name = 'Spectacles' },
            { id = 16274, lvl = 74, jobs = 4194303, name = 'Almah Torque' },
            { id = 16266, lvl = 70, jobs = 4194303, name = 'Wivre Gorget +1' },
            { id = 16265, lvl = 70, jobs = 4194303, name = 'Wivre Gorget' },
            { id = 13123, lvl = 56, jobs = 2141649, name = 'Mermans Gorget' },
            { id = 13106, lvl = 55, jobs =    6593, name = 'Ryl.Grd. Collar' },
            { id = 13167, lvl = 50, jobs = 4194303, name = 'Storm Gorget' },
            { id = 16280, lvl = 40, jobs = 4194303, name = 'Haraldrs Muffler' },
            { id = 16304, lvl = 18, jobs = 4194303, name = 'Focus Collar +1' },
            { id = 13061, lvl = 21, jobs = 4194303, name = 'Spike Necklace' },
            { id = 13107, lvl = 50, jobs =    6593, name = 'R.K. Army Collar' },
            { id = 16301, lvl = 18, jobs = 4194303, name = 'Focus Collar' },
            { id = 13166, lvl = 50, jobs = 4194303, name = 'Hateful Collar' },
            { id = 13119, lvl = 24, jobs = 4194303, name = 'Tiger Stole' },
            { id = 13065, lvl = 40, jobs =     193, name = 'Gorget +1' },
            { id = 13113, lvl = 20, jobs = 3851870, name = 'Black Neckerchief' },
            { id = 16279, lvl =  3, jobs = 4194303, name = 'Pile Chain' },
            { id = 13058, lvl = 20, jobs = 4194303, name = 'Bloodbead Amulet' },
            { id = 13112, lvl =  7, jobs =      32, name = 'Rabbit Charm' },
            { id = 16296, lvl =  9, jobs = 2141649, name = 'Armigers Lace' },
            { id = 13101, lvl = 10, jobs = 4179646, name = 'Green Scarf' },
            { id = 13078, lvl =  1, jobs = 4194303, name = 'Portafurnace' },
            { id = 13121, lvl =  1, jobs = 4194303, name = 'Beast Collar' },
            { id = 13122, lvl =  1, jobs = 4194303, name = 'Miners Pendant' },
            { id = 16273, lvl =  1, jobs = 4194303, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 26334, lvl = 99, jobs = 2107521, name = 'Ioskeha Belt +1' },
            { id = 26333, lvl = 99, jobs = 2107521, name = 'Ioskeha Belt' },
            { id = 26341, lvl = 99, jobs =  131074, name = 'Moonbow Belt +1' },
            { id = 26336, lvl = 99, jobs =  155904, name = 'Klouskap Sash +1' },
            { id = 13186, lvl = 70, jobs =       2, name = 'Black Belt' },
            { id = 26365, lvl = 99, jobs = 4194303, name = 'Cornelias Belt' },
            { id = 13202, lvl = 40, jobs =       2, name = 'Brown Belt' },
            { id = 15458, lvl = 75, jobs = 4194303, name = 'Ninurtas Sash' },
            { id = 13250, lvl = 65, jobs = 2473969, name = 'Sonic Belt +1' },
            { id = 13249, lvl = 65, jobs = 2473969, name = 'Sonic Belt' },
            { id = 13189, lvl = 55, jobs = 2473969, name = 'Speed Belt' },
            { id = 15899, lvl = 55, jobs = 2473969, name = 'Velocious Belt' },
            { id = 15457, lvl = 50, jobs = 4194303, name = 'Swift Belt' },
            { id = 13201, lvl = 18, jobs =       2, name = 'Purple Belt' },
            { id = 15941, lvl = 44, jobs = 4194303, name = 'Headlong Belt' },
            { id = 15943, lvl = 54, jobs = 4194303, name = 'Virtuoso Belt' },
            { id = 13231, lvl = 48, jobs = 4194303, name = 'Life Belt' },
            { id = 15884, lvl = 60, jobs = 4194303, name = 'Potent Belt' },
            { id = 15286, lvl = 40, jobs = 4194303, name = 'Tilt Belt' },
            { id = 13214, lvl = 40, jobs =     193, name = 'Waistbelt +1' },
            { id = 15908, lvl = 40, jobs = 3851870, name = 'Qiqirn Sash +1' },
            { id = 13221, lvl = 30, jobs = 4179646, name = 'Mrc.Cpt. Belt' },
            { id = 15927, lvl = 30, jobs = 2166961, name = 'Pinwheel Belt' },
            { id = 15880, lvl = 20, jobs =      32, name = 'Key Ring Belt' },
            { id = 15271, lvl = 30, jobs = 4194303, name = 'Axe Belt' },
            { id = 13224, lvl = 20, jobs = 3851870, name = 'Silver Obi +1' },
            { id = 15906, lvl = 20, jobs = 3851870, name = 'Mohbwa Sash +1' },
            { id = 13191, lvl = 17, jobs = 4194303, name = 'Lizard Belt +1' },
            { id = 13190, lvl =  8, jobs = 3851870, name = 'Heko Obi +1' },
            { id = 13204, lvl =  8, jobs = 3851870, name = 'Heko Obi' },
            { id = 13210, lvl =  7, jobs = 2473969, name = 'Leather Belt +1' },
            { id = 15889, lvl =  7, jobs = 2473969, name = 'Augmenting Belt' },
            { id = 13184, lvl =  1, jobs =       2, name = 'White Belt' },
            { id = 15456, lvl =  1, jobs = 4194303, name = 'Dash Sash' },
            { id = 10847, lvl =  1, jobs = 4194303, name = 'Orc Belt' },
            { id = 10848, lvl =  1, jobs = 4194303, name = 'Quadav Belt' },
        },
        BACK =
        {
            { id = 28628, lvl = 99, jobs =    2048, name = 'Takaha Mantle' },
            { id = 28617, lvl = 99, jobs =       1, name = 'Maulers Mantle' },
            { id = 11007, lvl = 99, jobs = 2473971, name = 'Letalis Mantle' },
            { id = 28629, lvl = 99, jobs =    4096, name = 'Yokaze Mantle' },
            { id = 27620, lvl = 99, jobs = 1753628, name = 'Aurists Cape +1' },
            { id = 16241, lvl = 74, jobs = 2473971, name = 'Cuchulains Mantle' },
            { id = 16248, lvl = 70, jobs =  262144, name = 'Etoile Cape' },
            { id = 15479, lvl = 70, jobs =     128, name = 'Abyss Cape' },
            { id = 15482, lvl = 70, jobs =     512, name = 'Bards Cape' },
            { id = 16244, lvl = 70, jobs =   32768, name = 'Mirage Mantle' },
            { id = 11546, lvl = 75, jobs = 4194303, name = 'Aesir Mantle' },
            { id = 15475, lvl = 70, jobs = 2473971, name = 'Charger Mantle' },
            { id = 11545, lvl = 60, jobs = 4194303, name = 'Fourth Mantle' },
            { id = 11540, lvl = 51, jobs = 2473971, name = 'Accura Cape +1' },
            { id = 15493, lvl = 60, jobs = 2473971, name = 'Bushido Cape' },
            { id = 13604, lvl = 60, jobs = 2473971, name = 'Behem. Mantle +1' },
            { id = 13686, lvl = 47, jobs = 2473971, name = 'Jaguar Mantle' },
            { id = 11539, lvl = 26, jobs = 2473971, name = 'Exact. Mantle +1' },
            { id = 13678, lvl = 50, jobs =    7201, name = 'Snipers Mantle' },
            { id = 13674, lvl = 40, jobs =    7201, name = 'Agile Mantle' },
            { id = 13676, lvl = 50, jobs =    8641, name = 'Heavy Mantle' },
            { id = 15483, lvl = 50, jobs = 4194303, name = 'Storm Mantle' },
            { id = 13675, lvl = 40, jobs = 1589788, name = 'Rearguard Mantle' },
            { id = 11530, lvl = 26, jobs = 2473971, name = 'Exactitude Mantle' },
            { id = 13625, lvl = 39, jobs = 1758748, name = 'Tundra Mantle' },
            { id = 13644, lvl = 30, jobs = 1753628, name = 'Midnight Cape' },
            { id = 13643, lvl = 30, jobs = 1753628, name = 'Sarcenet Cape' },
            { id = 11528, lvl = 16, jobs = 2473971, name = 'Besieger Mantle' },
            { id = 13680, lvl = 20, jobs = 2473971, name = 'Variable Mantle' },
            { id = 13681, lvl = 20, jobs = 1753628, name = 'Variable Cape' },
            { id = 13600, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle +1' },
            { id = 13607, lvl = 10, jobs = 1753628, name = 'Mist Silk Cape' },
            { id = 13605, lvl =  7, jobs = 1753628, name = 'Cape +1' },
            { id = 13583, lvl =  7, jobs = 1753628, name = 'Cape' },
            { id = 13599, lvl =  4, jobs = 2473971, name = 'Rabbit Mantle +1' },
            { id = 11009, lvl =  1, jobs = 4194303, name = 'Shapers Shawl' },
            { id = 16243, lvl =  1, jobs = 4194303, name = 'Drovers Mantle' },
            { id = 11002, lvl =  1, jobs = 4194303, name = 'Dragon Tank' },
            { id = 13682, lvl =  1, jobs = 4194303, name = 'Ether Tank' },
        },
        EAR =
        {
            { id = 26084, lvl = 99, jobs = 2368818, name = 'Sherida Earring' },
            { id = 26116, lvl = 99, jobs =  133251, name = 'Schere Earring' },
            { id = 27541, lvl = 99, jobs = 4194303, name = 'Cessance Earring' },
            { id = 26081, lvl = 99, jobs = 4194303, name = 'Mache Earring +1' },
            { id = 14813, lvl = 75, jobs = 4194303, name = 'Brutal Earring' },
            { id = 14739, lvl = 72, jobs = 4194303, name = 'Suppanomimi' },
            { id = 15964, lvl = 72, jobs = 4194303, name = 'Hollow Earring' },
            { id = 15979, lvl = 70, jobs =   10433, name = 'Fowling Earring' },
            { id = 14814, lvl = 65, jobs = 4194303, name = 'Diaboloss Earring' },
            { id = 14762, lvl = 70, jobs =    6593, name = 'Attilas Earring' },
            { id = 13403, lvl = 58, jobs =    8641, name = 'Assault Earring' },
            { id = 13406, lvl = 63, jobs = 4194303, name = 'Mermans Earring' },
            { id = 14756, lvl = 52, jobs = 4194303, name = 'Accurate Earring' },
            { id = 13369, lvl = 55, jobs = 4194303, name = 'Spike Earring' },
            { id = 13325, lvl = 55, jobs = 4194303, name = 'Fang Earring' },
            { id = 15968, lvl = 50, jobs = 4194303, name = 'Storm Loop' },
            { id = 13363, lvl = 45, jobs = 4194303, name = 'Tor. Earring +1' },
            { id = 13324, lvl = 45, jobs = 4194303, name = 'Tortoise Earring' },
            { id = 14804, lvl = 49, jobs = 4194303, name = 'Harvest Earring' },
            { id = 14806, lvl = 40, jobs = 4194303, name = 'Intruder Earring' },
            { id = 13405, lvl = 40, jobs = 1758748, name = 'Enhancing Earring' },
            { id = 16014, lvl = 40, jobs = 4194303, name = 'Stormer Earring' },
            { id = 16015, lvl = 40, jobs = 4194303, name = 'Esse Earring' },
            { id = 13326, lvl = 21, jobs = 4194303, name = 'Beetle Earring +1' },
            { id = 11043, lvl = 30, jobs = 4194303, name = 'Giants Earring' },
            { id = 13323, lvl = 21, jobs = 4194303, name = 'Beetle Earring' },
            { id = 13435, lvl = 30, jobs = 4194303, name = 'Mercen. Earring' },
            { id = 13362, lvl = 16, jobs = 4194303, name = 'Bone Earring +1' },
            { id = 13321, lvl = 16, jobs = 4194303, name = 'Bone Earring' },
            { id = 14757, lvl = 20, jobs = 4194303, name = 'Mecurial Earring' },
            { id = 13365, lvl = 20, jobs = 4194303, name = 'Shield Earring' },
            { id = 14803, lvl = 10, jobs = 4194303, name = 'Optical Earring' },
            { id = 14688, lvl = 10, jobs = 4194303, name = 'Reflex Earring +1' },
            { id = 14689, lvl = 10, jobs = 4194303, name = 'Crg. Earring +1' },
            { id = 14690, lvl = 10, jobs = 4194303, name = 'Kldg. Earring +1' },
            { id = 13402, lvl =  1, jobs = 4194303, name = 'Cassie Earring' },
            { id = 28510, lvl =  1, jobs = 4194303, name = 'M. Slime Earring' },
            { id = 16003, lvl =  1, jobs = 4194303, name = 'Raising Earring' },
            { id = 28509, lvl =  1, jobs = 4194303, name = 'She-Slime Earring' },
        },
        RING =
        {
            { id = 28471, lvl = 99, jobs =  397602, name = 'Gere Ring' },
            { id = 26185, lvl = 99, jobs = 2238595, name = 'Niqmaddu Ring' },
            { id = 26182, lvl = 99, jobs = 4194303, name = 'Chirich Ring +1' },
            { id = 11651, lvl = 89, jobs = 2594082, name = 'Eponas Ring' },
            { id = 26186, lvl = 99, jobs = 2465590, name = 'Ilabrat Ring' },
            { id = 26181, lvl = 99, jobs = 4194303, name = 'Chirich Ring' },
            { id = 15543, lvl = 30, jobs = 4194303, name = 'Rajas Ring' },
            { id = 15548, lvl = 75, jobs = 4194303, name = 'Marss Ring' },
            { id = 13566, lvl = 70, jobs = 4194303, name = 'Defending Ring' },
            { id = 11629, lvl = 75, jobs = 4194303, name = 'Zilant Ring' },
            { id = 14674, lvl = 57, jobs = 4194303, name = 'Toreadors Ring' },
            { id = 15817, lvl = 49, jobs = 4194303, name = 'Ecphoria Ring' },
            { id = 15828, lvl = 70, jobs = 4194303, name = 'Blood Ring' },
            { id = 13281, lvl = 40, jobs = 4194303, name = 'Snipers Ring +1' },
            { id = 15808, lvl = 50, jobs = 4194303, name = 'Ulthalams Ring' },
            { id = 14675, lvl = 40, jobs = 4194303, name = 'Woodsman Ring' },
            { id = 13553, lvl = 39, jobs =    8641, name = 'Blitz Ring' },
            { id = 14682, lvl = 49, jobs = 4194303, name = 'Kshama Ring No.2' },
            { id = 15818, lvl = 70, jobs = 4194303, name = 'Molioness Ring' },
            { id = 13514, lvl = 30, jobs = 4194303, name = 'Archers Ring' },
            { id = 15551, lvl = 30, jobs = 4194303, name = 'Shikaree Ring' },
            { id = 14595, lvl = 14, jobs = 4194303, name = 'Balance Ring +1' },
            { id = 13524, lvl = 14, jobs = 4194303, name = 'Balance Ring' },
            { id = 14671, lvl = 30, jobs = 4194303, name = 'Allied Ring' },
            { id = 15559, lvl = 14, jobs = 4194303, name = 'Vision Ring' },
            { id = 14593, lvl = 14, jobs = 4194303, name = 'Courage Ring +1' },
            { id = 14670, lvl = 10, jobs = 4194303, name = 'Safeguard Ring' },
            { id = 13497, lvl =  1, jobs = 4194303, name = 'Bastokan Ring' },
            { id = 13282, lvl = 10, jobs = 4194303, name = 'Saintly Ring' },
            { id = 13283, lvl = 10, jobs = 4194303, name = 'Saintly Ring +1' },
            { id = 13495, lvl =  1, jobs = 4194303, name = 'San Dorian Ring' },
            { id = 10796, lvl =  1, jobs = 4194303, name = 'Decennial Ring' },
            { id = 11666, lvl =  1, jobs = 4194303, name = 'Novennial Ring' },
        },
    },
    ws =
    {
        HEAD =
        {
            { id = 27783, lvl = 99, jobs = 2363683, name = 'Skormoth Mask' },
            { id = 23085, lvl = 99, jobs =       1, name = 'Boii Mask +2' },
            { id = 23398, lvl = 99, jobs =       1, name = 'Agoge Mask +3' },
            { id = 23411, lvl = 99, jobs =    8192, name = 'Ptero. Armet +3' },
            { id = 23092, lvl = 99, jobs =     128, name = 'Heathens Burgeonet +2' },
            { id = 23091, lvl = 99, jobs =      64, name = 'Chevaliers Armet +2' },
            { id = 23400, lvl = 99, jobs =       4, name = 'Piety Cap +3' },
            { id = 25578, lvl = 99, jobs = 1605656, name = 'Jhakri Coronal +2' },
            { id = 23761, lvl = 99, jobs = 4194303, name = 'Nyame Helm' },
            { id = 11501, lvl = 75, jobs =   10689, name = 'Nocturnus Helm' },
            { id = 13928, lvl = 73, jobs = 2106337, name = 'Hecatomb Cap +1' },
            { id = 13927, lvl = 73, jobs = 2106337, name = 'Hecatomb Cap' },
            { id = 16158, lvl = 71, jobs = 4194303, name = 'Gnadbhods Helm' },
            { id = 13907, lvl = 70, jobs =     272, name = 'Ogre Mask +1' },
            { id = 13704, lvl = 70, jobs =     272, name = 'Ogre Mask' },
            { id = 15187, lvl = 70, jobs =    2048, name = 'Hmn. Jinpachi +1' },
            { id = 13845, lvl = 68, jobs =     385, name = 'Celata +1' },
            { id = 16131, lvl = 65, jobs = 2472947, name = 'Wivre Mask +1' },
            { id = 13867, lvl = 70, jobs =   66592, name = 'War Beret +1' },
            { id = 12516, lvl = 60, jobs =     128, name = 'Chaos Burgeonet' },
            { id = 16067, lvl = 59, jobs =    2497, name = 'Abtal Turban' },
            { id = 27658, lvl = 45, jobs =    8385, name = 'Ates Mask' },
            { id = 13841, lvl = 43, jobs = 2141649, name = 'Valkyries Mask' },
            { id = 16148, lvl = 68, jobs = 2589730, name = 'Cobra Cap' },
            { id = 16061, lvl = 59, jobs =    2497, name = 'Sipahi Turban' },
            { id = 11498, lvl = 59, jobs = 2472947, name = 'Zeal Cap +1' },
            { id = 27659, lvl = 45, jobs = 2426144, name = 'Idis Mask' },
            { id = 15185, lvl = 43, jobs = 2473969, name = 'Walkure Mask' },
            { id = 27660, lvl = 45, jobs =  137218, name = 'Genta Kabuto' },
            { id = 15260, lvl = 70, jobs = 1589788, name = 'Hydra Beret' },
            { id = 16065, lvl = 50, jobs = 4194303, name = 'Storm Zucchetto' },
            { id = 13904, lvl = 34, jobs = 3662710, name = 'Fed. Headgear' },
            { id = 13903, lvl = 34, jobs = 3662710, name = 'Win. Headgear' },
            { id = 15219, lvl = 39, jobs = 4179646, name = 'Sinister Mask' },
            { id = 12470, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Headgear' },
            { id = 12422, lvl = 40, jobs =     193, name = 'Irn.Msk. Armet' },
            { id = 13898, lvl = 34, jobs = 2141649, name = 'Republic Visor' },
            { id = 11493, lvl = 25, jobs = 2473969, name = 'Precision Bandana' },
            { id = 16086, lvl = 25, jobs =    8385, name = 'Phoboss Mask' },
            { id = 13902, lvl = 25, jobs =    6146, name = 'Fed. Hachimaki' },
            { id = 12484, lvl = 20, jobs =    6146, name = 'Mrc. Hachimaki' },
            { id = 13830, lvl = 30, jobs = 4179646, name = 'Lgn. Circlet' },
            { id = 12501, lvl = 11, jobs =       2, name = 'Monks Headgear' },
            { id = 16085, lvl = 15, jobs =    8385, name = 'Enyos Mask' },
            { id = 15186, lvl = 20, jobs = 4194303, name = 'Trump Crown' },
            { id = 12487, lvl = 10, jobs = 2141649, name = 'Faceguard +1' },
            { id = 12432, lvl = 10, jobs = 2141649, name = 'Faceguard' },
            { id = 12509, lvl = 10, jobs = 2472947, name = 'Legionnaires Cap' },
            { id = 12510, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Bandana' },
            { id = 16144, lvl = 10, jobs = 4194303, name = 'Sol Cap' },
            { id = 11811, lvl =  1, jobs = 4194303, name = 'Destrier Beret' },
            { id = 12463, lvl =  1, jobs = 2472947, name = 'Bronze Cap +1' },
            { id = 10385, lvl =  1, jobs = 4194303, name = 'Cumulus Masque +1' },
            { id = 12448, lvl =  1, jobs = 2472947, name = 'Bronze Cap' },
        },
        BODY =
        {
            { id = 23164, lvl = 99, jobs =    4096, name = 'Hattori Ningi +2' },
            { id = 23159, lvl = 99, jobs =     128, name = 'Heathens Cuirass +2' },
            { id = 23163, lvl = 99, jobs =    2048, name = 'Kasuga Domaru +2' },
            { id = 23165, lvl = 99, jobs =    8192, name = 'Peltasts Plackart +2' },
            { id = 23152, lvl = 99, jobs =       1, name = 'Boii Lorica +2' },
            { id = 23765, lvl = 99, jobs =  137218, name = 'Mpacas Doublet' },
            { id = 23768, lvl = 99, jobs = 4194303, name = 'Nyame Mail' },
            { id = 14371, lvl = 73, jobs =     385, name = 'Armada Hauberk' },
            { id = 12557, lvl = 73, jobs =     385, name = 'Adaman Hauberk' },
            { id = 14546, lvl = 75, jobs =    8385, name = 'Ares Cuirass' },
            { id = 14574, lvl = 75, jobs =     193, name = 'Valk. Breastplate' },
            { id = 11281, lvl = 75, jobs =    7171, name = 'Hachiryu Haramaki' },
            { id = 13793, lvl = 69, jobs =     385, name = 'Hauberk +1' },
            { id = 13735, lvl = 59, jobs =    6593, name = 'Haubergeon +1' },
            { id = 13741, lvl = 60, jobs =    6593, name = 'Byrnie +1' },
            { id = 12556, lvl = 69, jobs =     385, name = 'Hauberk' },
            { id = 12555, lvl = 59, jobs =    6593, name = 'Haubergeon' },
            { id = 13740, lvl = 60, jobs =    6593, name = 'Byrnie' },
            { id = 14562, lvl = 75, jobs =   32792, name = 'Morrigans Robe' },
            { id = 14590, lvl = 68, jobs = 2589730, name = 'Cobra Harness' },
            { id = 27800, lvl = 45, jobs =  137218, name = 'Genta Hara-Ate' },
            { id = 14572, lvl = 65, jobs = 3662710, name = 'Tabin Jupon +1' },
            { id = 14529, lvl = 55, jobs = 2473969, name = 'Akinji Peti' },
            { id = 14445, lvl = 45, jobs =    6593, name = 'Luisant Haubert' },
            { id = 13755, lvl = 59, jobs = 3069758, name = 'Flora Cotehardie' },
            { id = 14515, lvl = 70, jobs = 1589788, name = 'Hydra Doublet' },
            { id = 27798, lvl = 45, jobs =    8385, name = 'Ates Cuirass' },
            { id = 14404, lvl = 50, jobs =    2048, name = 'Shm. Hara-Ate' },
            { id = 13710, lvl = 45, jobs = 2473969, name = 'Brigandine +1' },
            { id = 13799, lvl = 52, jobs = 3662710, name = 'Gaia Doublet +1' },
            { id = 27801, lvl = 45, jobs =   16900, name = 'Namrus Jubbah' },
            { id = 13728, lvl = 40, jobs =    6146, name = 'Jujitsu Gi' },
            { id = 14557, lvl = 35, jobs =  137218, name = 'Hikazu Hara-Ate' },
            { id = 14549, lvl = 35, jobs =    8385, name = 'Deimoss Cuirass' },
            { id = 14465, lvl = 30, jobs =    4096, name = 'Nanban Kariginu' },
            { id = 13813, lvl = 40, jobs =       4, name = 'Divine Breastplate' },
            { id = 14565, lvl = 35, jobs =   32792, name = 'Machas Coat' },
            { id = 12606, lvl = 50, jobs = 4179646, name = 'Tct.Mgc. Coat' },
            { id = 14553, lvl = 35, jobs =   66848, name = 'Freyas Jerkin' },
            { id = 14353, lvl = 34, jobs = 3662710, name = 'Fed. Doublet' },
            { id = 14556, lvl = 25, jobs =  137218, name = 'Tsukikazu Togi' },
            { id = 14548, lvl = 25, jobs =    8385, name = 'Phoboss Cuirass' },
            { id = 14564, lvl = 25, jobs =   32792, name = 'Bodbs Robe' },
            { id = 12598, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Doublet' },
            { id = 13719, lvl = 40, jobs = 4179646, name = 'Ryl.Sqr. Robe' },
            { id = 12566, lvl = 30, jobs = 2141649, name = 'Ctr. Scale Mail' },
            { id = 14563, lvl = 15, jobs =   32792, name = 'Nemains Robe' },
            { id = 12590, lvl = 13, jobs =    6146, name = 'Power Gi' },
            { id = 13818, lvl = 18, jobs = 4194303, name = 'Garrison Tunica' },
            { id = 12653, lvl = 20, jobs =    6146, name = 'Mercenarys Gi' },
            { id = 12668, lvl =  8, jobs =    6146, name = 'Kenpogi +1' },
            { id = 12661, lvl = 10, jobs = 2141649, name = 'Solid Mail' },
            { id = 12560, lvl = 10, jobs = 2141649, name = 'Scale Mail' },
            { id = 12629, lvl = 10, jobs = 2472947, name = 'Lgn. Harness' },
            { id = 12607, lvl =  1, jobs = 2472947, name = 'Bronze Harness +1' },
            { id = 11330, lvl =  1, jobs = 4194303, name = 'Blksmith. Smock' },
            { id = 12576, lvl =  1, jobs = 2472947, name = 'Bronze Harness' },
            { id = 12615, lvl =  1, jobs = 4179646, name = 'Robe +1' },
        },
        HANDS =
        {
            { id = 23227, lvl = 99, jobs =     256, name = 'Nukumi Manoplas +2' },
            { id = 23224, lvl = 99, jobs =      32, name = 'Skulkers Armlets +2' },
            { id = 23232, lvl = 99, jobs =    8192, name = 'Peltasts Vambraces +2' },
            { id = 23236, lvl = 99, jobs =  131072, name = 'Karagoz Guanti +2' },
            { id = 23772, lvl = 99, jobs =  137218, name = 'Mpacas Gloves' },
            { id = 23219, lvl = 99, jobs =       1, name = 'Boii Mufflers +2' },
            { id = 23775, lvl = 99, jobs = 4194303, name = 'Nyame Gauntlets' },
            { id = 14873, lvl = 73, jobs =    6146, name = 'Bandomusha Kote' },
            { id = 14901, lvl = 74, jobs =    2048, name = 'Myn. Kote +1' },
            { id = 14077, lvl = 73, jobs = 2106337, name = 'Hct. Mittens +1' },
            { id = 14897, lvl = 74, jobs =     128, name = 'Chs. Gauntlets +1' },
            { id = 14965, lvl = 75, jobs =   66848, name = 'Skadis Bazubands' },
            { id = 14878, lvl = 70, jobs =    2048, name = 'Hachiman Kote +1' },
            { id = 13952, lvl = 34, jobs =    6146, name = 'Ochiudos Kote' },
            { id = 14986, lvl = 34, jobs =    6146, name = 'Ochimusha Kote' },
            { id = 15023, lvl = 72, jobs = 2595874, name = 'Enkidus Mittens' },
            { id = 14876, lvl = 70, jobs =    2048, name = 'Hachiman Kote' },
            { id = 14022, lvl = 70, jobs = 2472947, name = 'Alkyoneuss Brc.' },
            { id = 14892, lvl = 74, jobs =       4, name = 'Hlr. Mitts +1' },
            { id = 14874, lvl = 34, jobs =    6146, name = 'Horomusha Kote' },
            { id = 14074, lvl = 70, jobs = 2473969, name = 'Tarasque Mitts +1' },
            { id = 14952, lvl = 52, jobs =     192, name = 'Ice Gauntlets' },
            { id = 14021, lvl = 60, jobs = 2472947, name = 'Pallass Bracelets' },
            { id = 14977, lvl = 75, jobs =   32792, name = 'Morrigans Cuffs' },
            { id = 14843, lvl = 50, jobs =   11521, name = 'Spiked Fng.Gnt.' },
            { id = 14999, lvl = 70, jobs = 1573000, name = 'Vampiric Mitts' },
            { id = 13963, lvl = 60, jobs =       4, name = 'Healers Mitts' },
            { id = 14985, lvl = 75, jobs = 1720860, name = 'Goliard Cuffs' },
            { id = 14020, lvl = 50, jobs = 2472947, name = 'Enkeladoss Brc.' },
            { id = 13977, lvl = 57, jobs = 1753628, name = 'Light Gauntlets' },
            { id = 27941, lvl = 45, jobs =   16900, name = 'Namrus Dastanas' },
            { id = 14052, lvl = 45, jobs =    6593, name = 'Luisant Moufles' },
            { id = 27942, lvl = 45, jobs = 1605656, name = 'Neits Cuffs' },
            { id = 14019, lvl = 40, jobs = 2472947, name = 'Ogygoss Brc.' },
            { id = 14048, lvl = 43, jobs = 3851870, name = 'C.C. Mitts +2' },
            { id = 12743, lvl = 40, jobs = 3851870, name = 'Cmb.Cst. Mitts' },
            { id = 15058, lvl = 30, jobs = 3662710, name = 'Combat Mittens +1' },
            { id = 14018, lvl = 30, jobs = 2472947, name = 'Gigas Bracelets' },
            { id = 15053, lvl = 30, jobs = 3662710, name = 'Combat Mittens' },
            { id = 14963, lvl = 25, jobs =    8385, name = 'Phoboss Gnt.' },
            { id = 14038, lvl = 15, jobs = 2473969, name = 'Kingdom Gloves' },
            { id = 14032, lvl = 15, jobs = 2472947, name = 'Republic Mittens' },
            { id = 14031, lvl = 15, jobs = 2472947, name = 'Bastokan Mittens' },
            { id = 14037, lvl = 15, jobs = 2473969, name = 'San. Gloves' },
            { id = 12752, lvl = 10, jobs = 2472947, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Gloves' },
            { id = 12799, lvl = 14, jobs = 3662710, name = 'Battle Gloves' },
            { id = 14979, lvl = 25, jobs =   32792, name = 'Bodbs Cuffs' },
            { id = 12778, lvl = 12, jobs = 4179646, name = 'Linen Cuffs +1' },
            { id = 14859, lvl = 29, jobs = 1720332, name = 'Seers Mitts +1' },
            { id = 12768, lvl = 10, jobs = 2141649, name = 'Solid Fng. Gnt.' },
            { id = 12797, lvl =  9, jobs =     193, name = 'Coarse Gauntlets' },
            { id = 12775, lvl =  8, jobs = 3851870, name = 'Mitts +1' },
            { id = 14831, lvl =  1, jobs = 4194303, name = 'Smithys Mitts' },
            { id = 12695, lvl =  1, jobs = 2472947, name = 'Bronze Mittens +1' },
            { id = 12744, lvl =  1, jobs = 4179646, name = 'Cuffs +1' },
            { id = 12704, lvl =  1, jobs = 2472947, name = 'Bronze Mittens' },
        },
        LEGS =
        {
            { id = 27263, lvl = 99, jobs =    8192, name = 'Peltasts Cuissots' },
            { id = 23299, lvl = 99, jobs =    8192, name = 'Peltasts Cuissots +2' },
            { id = 23611, lvl = 99, jobs =    4096, name = 'Mochi. Hakama +3' },
            { id = 23583, lvl = 99, jobs =     128, name = 'Ig. Flanchard +3' },
            { id = 23286, lvl = 99, jobs =       1, name = 'Boii Cuisses +2' },
            { id = 23779, lvl = 99, jobs =  137218, name = 'Mpacas Hose' },
            { id = 23782, lvl = 99, jobs = 4194303, name = 'Nyame Flanchard' },
            { id = 14309, lvl = 73, jobs = 2106337, name = 'Hct. Subligar +1' },
            { id = 14308, lvl = 73, jobs = 2106337, name = 'Hecatomb Subligar' },
            { id = 15401, lvl = 71, jobs =     128, name = 'Onyx Cuisses' },
            { id = 15633, lvl = 75, jobs =  137218, name = 'Usukane Hizayoroi' },
            { id = 16337, lvl = 75, jobs =    7171, name = 'Hachiryu Haidate' },
            { id = 16343, lvl = 72, jobs = 2595874, name = 'Enkidus Subligar' },
            { id = 14318, lvl = 70, jobs =    8193, name = 'Conte Cosciales' },
            { id = 14317, lvl = 70, jobs =    8193, name = 'Barone Cosciales' },
            { id = 16320, lvl = 69, jobs =    6146, name = 'Kensei Sitabaki' },
            { id = 12814, lvl = 55, jobs =    6593, name = 'Ryl.Kgt. Breeches' },
            { id = 14223, lvl = 56, jobs =     512, name = 'Choral Cannions' },
            { id = 15595, lvl = 70, jobs = 1589788, name = 'Hydra Brais' },
            { id = 16317, lvl = 68, jobs = 2589730, name = 'Cobra Subligar' },
            { id = 28081, lvl = 45, jobs =    8385, name = 'Ates Flanchard' },
            { id = 15607, lvl = 59, jobs =    2497, name = 'Abtal Zerehs' },
            { id = 14334, lvl = 50, jobs =    2048, name = 'Shm. Haidate' },
            { id = 28083, lvl = 45, jobs =  137218, name = 'Genta-No-Hakama' },
            { id = 15403, lvl = 45, jobs =    6593, name = 'Luisant Brayettes' },
            { id = 28082, lvl = 45, jobs = 2426144, name = 'Idis Trousers' },
            { id = 14260, lvl = 25, jobs = 2472947, name = 'Republic Subligar' },
            { id = 14216, lvl = 56, jobs =       4, name = 'Healers Pantaln.' },
            { id = 15368, lvl = 50, jobs =      16, name = 'War Hose' },
            { id = 15636, lvl = 35, jobs =  137218, name = 'Hikazu Hakama' },
            { id = 15628, lvl = 35, jobs =    8385, name = 'Deimoss Cuisses' },
            { id = 14259, lvl = 25, jobs = 2472947, name = 'Bastokan Subligar' },
            { id = 14217, lvl = 56, jobs =       8, name = 'Wizards Tonban' },
            { id = 15627, lvl = 25, jobs =    8385, name = 'Phoboss Cuisses' },
            { id = 15635, lvl = 25, jobs =  137218, name = 'Tsukikazu Haidate' },
            { id = 16314, lvl = 55, jobs = 4179646, name = 'Cobra Slops' },
            { id = 15384, lvl = 50, jobs =   16388, name = 'Capri. Subligar' },
            { id = 15375, lvl = 50, jobs = 1064968, name = 'Aries Subligar' },
            { id = 15381, lvl = 50, jobs = 2261520, name = 'Libra Subligar' },
            { id = 15382, lvl = 50, jobs =  524304, name = 'Scorpius Subligar' },
            { id = 14314, lvl = 21, jobs = 4194303, name = 'Garrison Hose' },
            { id = 12870, lvl = 40, jobs = 3851870, name = 'Cmb.Cst. Slacks' },
            { id = 16367, lvl = 15, jobs = 2473969, name = 'Phl. Trousers' },
            { id = 15634, lvl = 15, jobs =  137218, name = 'Hoshikazu Hakama' },
            { id = 12882, lvl = 20, jobs = 2473969, name = 'Ryl.Ftm. Trousers' },
            { id = 15626, lvl = 15, jobs =    8385, name = 'Enyos Cuisses' },
            { id = 12917, lvl = 20, jobs = 3851870, name = 'Mages Slacks' },
            { id = 12863, lvl = 10, jobs = 2141649, name = 'Solid Cuisses' },
            { id = 12816, lvl = 10, jobs = 2141649, name = 'Scale Cuisses' },
            { id = 12915, lvl = 10, jobs = 4179646, name = 'Freeswords Slops' },
            { id = 12898, lvl =  8, jobs = 3851870, name = 'Slacks +1' },
            { id = 12899, lvl =  8, jobs =    6146, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, jobs = 2472947, name = 'Brz. Subligar +1' },
            { id = 12832, lvl =  1, jobs = 2472947, name = 'Bronze Subligar' },
            { id = 12897, lvl =  1, jobs = 4179646, name = 'Slops +1' },
            { id = 12856, lvl =  1, jobs = 4179646, name = 'Slops' },
        },
        FEET =
        {
            { id = 23677, lvl = 99, jobs =    2048, name = 'Sak. Sune-Ate +3' },
            { id = 23353, lvl = 99, jobs =       1, name = 'Boii Calligae +2' },
            { id = 23682, lvl = 99, jobs =   65536, name = 'Lanun Bottes +3' },
            { id = 23673, lvl = 99, jobs =     128, name = 'Fall. Sollerets +3' },
            { id = 23786, lvl = 99, jobs =  137218, name = 'Mpacas Boots' },
            { id = 23668, lvl = 99, jobs =       4, name = 'Piety Duckbills +3' },
            { id = 23789, lvl = 99, jobs = 4194303, name = 'Nyame Sollerets' },
            { id = 15719, lvl = 75, jobs =  137218, name = 'Usukane Sune-Ate' },
            { id = 15676, lvl = 75, jobs =    2048, name = 'Sao. Sune-Ate +1' },
            { id = 14181, lvl = 73, jobs = 2106337, name = 'Hct. Leggings +1' },
            { id = 15340, lvl = 71, jobs =     128, name = 'Onyx Sollerets' },
            { id = 14162, lvl = 75, jobs = 2594082, name = 'Agronas Leggings' },
            { id = 14159, lvl = 70, jobs =     272, name = 'Ogre Ledelsens +1' },
            { id = 15306, lvl = 70, jobs =    8193, name = 'Conte Gambieras' },
            { id = 15349, lvl = 67, jobs = 2473969, name = 'Rutter Sabatons' },
            { id = 15332, lvl = 70, jobs =    2048, name = 'Hmn. Sune-Ate +1' },
            { id = 15757, lvl = 68, jobs = 2589730, name = 'Cobra Leggings' },
            { id = 11373, lvl = 60, jobs =       2, name = 'Seirenshi Habaki' },
            { id = 15735, lvl = 75, jobs = 1720860, name = 'Goliard Clogs' },
            { id = 28222, lvl = 45, jobs = 1605656, name = 'Neits Pigaches' },
            { id = 15680, lvl = 70, jobs = 1589788, name = 'Hydra Gaiters' },
            { id = 15686, lvl = 54, jobs =  131072, name = 'Pup. Babouches' },
            { id = 28218, lvl = 45, jobs =    8385, name = 'Ates Sollerets' },
            { id = 28220, lvl = 45, jobs =  137218, name = 'Genta Sune-Ate' },
            { id = 15342, lvl = 45, jobs =    6593, name = 'Luisant Sollerets' },
            { id = 15691, lvl = 50, jobs = 4194303, name = 'Storm Gambieras' },
            { id = 14152, lvl = 25, jobs =    6146, name = 'Fed. Kyahan' },
            { id = 15718, lvl = 35, jobs =   66848, name = 'Freyas Ledelsens' },
            { id = 14133, lvl = 24, jobs = 2473969, name = 'Winged Boots +1' },
            { id = 14132, lvl = 24, jobs = 2473969, name = 'Winged Boots' },
            { id = 11412, lvl = 17, jobs = 2472947, name = 'Mtt. Leggings +1' },
            { id = 14151, lvl = 25, jobs =    6146, name = 'Win. Kyahan' },
            { id = 15348, lvl = 38, jobs = 4194303, name = 'Mountain Gaiters' },
            { id = 13014, lvl =  7, jobs = 2473969, name = 'Leaping Boots' },
            { id = 15351, lvl =  7, jobs = 2473969, name = 'Bounding Boots' },
            { id = 13012, lvl = 18, jobs = 4194303, name = 'Power Sandals' },
            { id = 13024, lvl = 10, jobs = 2141649, name = 'Solid Greaves' },
            { id = 12944, lvl = 10, jobs = 2141649, name = 'Scale Greaves' },
            { id = 13003, lvl = 10, jobs = 2472947, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, jobs = 3851870, name = 'Solea +1' },
            { id = 12951, lvl =  1, jobs = 2472947, name = 'Brz. Leggings +1' },
            { id = 12983, lvl =  1, jobs = 4179646, name = 'Ash Clogs +1' },
            { id = 11400, lvl =  1, jobs = 4194303, name = 'Noble Poulaines' },
            { id = 11403, lvl =  1, jobs = 4194303, name = 'Talaria' },
        },
        NECK =
        {
            { id = 26004, lvl = 99, jobs = 4194303, name = 'Lissome Necklace' },
            { id = 25461, lvl = 99, jobs =     128, name = 'Abyssal Beads +2' },
            { id = 25497, lvl = 99, jobs =    8192, name = 'Dgn. Collar +2' },
            { id = 25460, lvl = 99, jobs =     128, name = 'Abyssal Beads +1' },
            { id = 16268, lvl = 70, jobs = 2473969, name = 'Kubira Beads' },
            { id = 16275, lvl = 74, jobs = 4194303, name = 'Ancient Torque' },
            { id = 11582, lvl = 75, jobs = 4194303, name = 'Ire Torque +1' },
            { id = 16303, lvl = 73, jobs = 4194303, name = 'Larans Pendant' },
            { id = 15523, lvl = 60, jobs = 4194303, name = 'Chivalrous Chain' },
            { id = 13167, lvl = 50, jobs = 4194303, name = 'Storm Gorget' },
            { id = 16298, lvl = 67, jobs = 4194303, name = 'Knack Pendant' },
            { id = 16292, lvl = 60, jobs = 4194303, name = 'Bull Necklace' },
            { id = 13106, lvl = 55, jobs =    6593, name = 'Ryl.Grd. Collar' },
            { id = 13061, lvl = 21, jobs = 4194303, name = 'Spike Necklace' },
            { id = 13056, lvl = 33, jobs = 4194303, name = 'Peacock Charm' },
            { id = 15515, lvl = 33, jobs = 4194303, name = 'Peacock Amulet' },
            { id = 13076, lvl = 21, jobs = 4194303, name = 'Fang Necklace' },
            { id = 13119, lvl = 24, jobs = 4194303, name = 'Tiger Stole' },
            { id = 13107, lvl = 50, jobs =    6593, name = 'R.K. Army Collar' },
            { id = 13124, lvl = 49, jobs =    6146, name = 'Nodowa +1' },
            { id = 13166, lvl = 50, jobs = 4194303, name = 'Hateful Collar' },
            { id = 16280, lvl = 40, jobs = 4194303, name = 'Haraldrs Muffler' },
            { id = 13163, lvl = 35, jobs = 4194303, name = 'Medieval Collar' },
            { id = 16304, lvl = 18, jobs = 4194303, name = 'Focus Collar +1' },
            { id = 16296, lvl =  9, jobs = 2141649, name = 'Armigers Lace' },
            { id = 16301, lvl = 18, jobs = 4194303, name = 'Focus Collar' },
            { id = 13112, lvl =  7, jobs =      32, name = 'Rabbit Charm' },
            { id = 16279, lvl =  3, jobs = 4194303, name = 'Pile Chain' },
            { id = 13101, lvl = 10, jobs = 4179646, name = 'Green Scarf' },
            { id = 13078, lvl =  1, jobs = 4194303, name = 'Portafurnace' },
            { id = 13121, lvl =  1, jobs = 4194303, name = 'Beast Collar' },
            { id = 13122, lvl =  1, jobs = 4194303, name = 'Miners Pendant' },
            { id = 16273, lvl =  1, jobs = 4194303, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 26341, lvl = 99, jobs =  131074, name = 'Moonbow Belt +1' },
            { id = 26340, lvl = 99, jobs =  131074, name = 'Moonbow Belt' },
            { id = 28408, lvl = 99, jobs = 4194303, name = 'Grunfeld Rope' },
            { id = 28417, lvl = 99, jobs = 2363683, name = 'Sinew Belt' },
            { id = 15294, lvl = 71, jobs = 2472947, name = 'Warwolf Belt' },
            { id = 15917, lvl = 72, jobs = 2473969, name = 'Cuchulains Belt' },
            { id = 15954, lvl = 75, jobs = 2473971, name = 'Fierce Belt' },
            { id = 15878, lvl = 70, jobs =    8192, name = 'Wyrm Belt' },
            { id = 15871, lvl = 70, jobs =       1, name = 'Warriors Stone' },
            { id = 13186, lvl = 70, jobs =       2, name = 'Black Belt' },
            { id = 15923, lvl = 69, jobs = 2473969, name = 'Grenadier Belt' },
            { id = 15943, lvl = 54, jobs = 4194303, name = 'Virtuoso Belt' },
            { id = 13232, lvl = 43, jobs = 2473969, name = 'Swordbelt +1' },
            { id = 15884, lvl = 60, jobs = 4194303, name = 'Potent Belt' },
            { id = 15434, lvl = 45, jobs = 2473969, name = 'Vanguard Belt' },
            { id = 13198, lvl = 43, jobs = 2473969, name = 'Swordbelt' },
            { id = 15882, lvl = 50, jobs = 2473969, name = 'Storm Belt' },
            { id = 13202, lvl = 40, jobs =       2, name = 'Brown Belt' },
            { id = 13231, lvl = 48, jobs = 4194303, name = 'Life Belt' },
            { id = 15286, lvl = 40, jobs = 4194303, name = 'Tilt Belt' },
            { id = 13201, lvl = 18, jobs =       2, name = 'Purple Belt' },
            { id = 13225, lvl = 18, jobs = 2141649, name = 'Brave Belt' },
            { id = 13221, lvl = 30, jobs = 4179646, name = 'Mrc.Cpt. Belt' },
            { id = 13214, lvl = 40, jobs =     193, name = 'Waistbelt +1' },
            { id = 13240, lvl = 15, jobs = 2472947, name = 'Warriors Belt +1' },
            { id = 15880, lvl = 20, jobs =      32, name = 'Key Ring Belt' },
            { id = 13184, lvl =  1, jobs =       2, name = 'White Belt' },
            { id = 13224, lvl = 20, jobs = 3851870, name = 'Silver Obi +1' },
            { id = 13190, lvl =  8, jobs = 3851870, name = 'Heko Obi +1' },
            { id = 13204, lvl =  8, jobs = 3851870, name = 'Heko Obi' },
            { id = 13210, lvl =  7, jobs = 2473969, name = 'Leather Belt +1' },
            { id = 15456, lvl =  1, jobs = 4194303, name = 'Dash Sash' },
            { id = 10847, lvl =  1, jobs = 4194303, name = 'Orc Belt' },
            { id = 10848, lvl =  1, jobs = 4194303, name = 'Quadav Belt' },
        },
        BACK =
        {
            { id = 28624, lvl = 99, jobs =     128, name = 'Niht Mantle' },
            { id = 28630, lvl = 99, jobs =    8192, name = 'Updraft Mantle' },
            { id = 27594, lvl = 99, jobs = 2473971, name = 'Annealed Mantle' },
            { id = 28617, lvl = 99, jobs =       1, name = 'Maulers Mantle' },
            { id = 28612, lvl = 99, jobs = 4194303, name = 'Buquwik Cape' },
            { id = 16216, lvl = 75, jobs = 2473971, name = 'Cerb. Mantle +1' },
            { id = 16245, lvl = 70, jobs =  131072, name = 'Pantin Cape' },
            { id = 13690, lvl = 71, jobs = 2473971, name = 'Foragers Mantle' },
            { id = 15475, lvl = 70, jobs = 2473971, name = 'Charger Mantle' },
            { id = 13646, lvl = 61, jobs = 2473971, name = 'Amemet Mantle +1' },
            { id = 13694, lvl = 69, jobs = 2473971, name = 'Psilos Mantle' },
            { id = 11546, lvl = 75, jobs = 4194303, name = 'Aesir Mantle' },
            { id = 13604, lvl = 60, jobs = 2473971, name = 'Behem. Mantle +1' },
            { id = 13591, lvl = 60, jobs = 2473971, name = 'Behemoth Mantle' },
            { id = 15469, lvl = 52, jobs = 1753628, name = 'Bellicose Mantle' },
            { id = 13580, lvl = 55, jobs = 4194303, name = 'Ryl. Army Mantle' },
            { id = 13686, lvl = 47, jobs = 2473971, name = 'Jaguar Mantle' },
            { id = 13678, lvl = 50, jobs =    7201, name = 'Snipers Mantle' },
            { id = 13675, lvl = 40, jobs = 1589788, name = 'Rearguard Mantle' },
            { id = 13636, lvl = 37, jobs = 2473971, name = 'Cvl. Mantle +1' },
            { id = 13635, lvl = 37, jobs = 2473971, name = 'Cvl. Mantle' },
            { id = 15483, lvl = 50, jobs = 4194303, name = 'Storm Mantle' },
            { id = 13674, lvl = 40, jobs =    7201, name = 'Agile Mantle' },
            { id = 11539, lvl = 26, jobs = 2473971, name = 'Exact. Mantle +1' },
            { id = 11528, lvl = 16, jobs = 2473971, name = 'Besieger Mantle' },
            { id = 13625, lvl = 39, jobs = 1758748, name = 'Tundra Mantle' },
            { id = 11530, lvl = 26, jobs = 2473971, name = 'Exactitude Mantle' },
            { id = 13644, lvl = 30, jobs = 1753628, name = 'Midnight Cape' },
            { id = 13680, lvl = 20, jobs = 2473971, name = 'Variable Mantle' },
            { id = 13681, lvl = 20, jobs = 1753628, name = 'Variable Cape' },
            { id = 13600, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle +1' },
            { id = 13607, lvl = 10, jobs = 1753628, name = 'Mist Silk Cape' },
            { id = 13605, lvl =  7, jobs = 1753628, name = 'Cape +1' },
            { id = 13583, lvl =  7, jobs = 1753628, name = 'Cape' },
            { id = 13599, lvl =  4, jobs = 2473971, name = 'Rabbit Mantle +1' },
            { id = 11009, lvl =  1, jobs = 4194303, name = 'Shapers Shawl' },
            { id = 16243, lvl =  1, jobs = 4194303, name = 'Drovers Mantle' },
            { id = 11002, lvl =  1, jobs = 4194303, name = 'Dragon Tank' },
            { id = 13682, lvl =  1, jobs = 4194303, name = 'Ether Tank' },
        },
        EAR =
        {
            { id = 26107, lvl = 99, jobs =   10689, name = 'Thrud Earring' },
            { id = 26084, lvl = 99, jobs = 2368818, name = 'Sherida Earring' },
            { id = 26108, lvl = 99, jobs = 2462754, name = 'Odr Earring' },
            { id = 26116, lvl = 99, jobs =  133251, name = 'Schere Earring' },
            { id = 26081, lvl = 99, jobs = 4194303, name = 'Mache Earring +1' },
            { id = 28527, lvl = 99, jobs = 4194303, name = 'Tati Earring +1' },
            { id = 14813, lvl = 75, jobs = 4194303, name = 'Brutal Earring' },
            { id = 16057, lvl = 75, jobs = 4194303, name = 'Aesir Ear Pendant' },
            { id = 13406, lvl = 63, jobs = 4194303, name = 'Mermans Earring' },
            { id = 13403, lvl = 58, jobs =    8641, name = 'Assault Earring' },
            { id = 15965, lvl = 72, jobs = 4194303, name = 'Ethereal Earring' },
            { id = 13312, lvl = 63, jobs = 4194303, name = 'Coral Earring' },
            { id = 13369, lvl = 55, jobs = 4194303, name = 'Spike Earring' },
            { id = 15968, lvl = 50, jobs = 4194303, name = 'Storm Loop' },
            { id = 13325, lvl = 55, jobs = 4194303, name = 'Fang Earring' },
            { id = 13363, lvl = 45, jobs = 4194303, name = 'Tor. Earring +1' },
            { id = 13324, lvl = 45, jobs = 4194303, name = 'Tortoise Earring' },
            { id = 11042, lvl = 50, jobs =    6593, name = 'Rebel Earring' },
            { id = 13326, lvl = 21, jobs = 4194303, name = 'Beetle Earring +1' },
            { id = 14806, lvl = 40, jobs = 4194303, name = 'Intruder Earring' },
            { id = 11043, lvl = 30, jobs = 4194303, name = 'Giants Earring' },
            { id = 13323, lvl = 21, jobs = 4194303, name = 'Beetle Earring' },
            { id = 13362, lvl = 16, jobs = 4194303, name = 'Bone Earring +1' },
            { id = 13405, lvl = 40, jobs = 1758748, name = 'Enhancing Earring' },
            { id = 16014, lvl = 40, jobs = 4194303, name = 'Stormer Earring' },
            { id = 13402, lvl =  1, jobs = 4194303, name = 'Cassie Earring' },
            { id = 13321, lvl = 16, jobs = 4194303, name = 'Bone Earring' },
            { id = 14757, lvl = 20, jobs = 4194303, name = 'Mecurial Earring' },
            { id = 13365, lvl = 20, jobs = 4194303, name = 'Shield Earring' },
            { id = 14688, lvl = 10, jobs = 4194303, name = 'Reflex Earring +1' },
            { id = 14689, lvl = 10, jobs = 4194303, name = 'Crg. Earring +1' },
            { id = 14690, lvl = 10, jobs = 4194303, name = 'Kldg. Earring +1' },
            { id = 28510, lvl =  1, jobs = 4194303, name = 'M. Slime Earring' },
            { id = 16003, lvl =  1, jobs = 4194303, name = 'Raising Earring' },
            { id = 28509, lvl =  1, jobs = 4194303, name = 'She-Slime Earring' },
        },
        RING =
        {
            { id = 26191, lvl = 99, jobs = 2571747, name = 'Regal Ring' },
            { id = 28471, lvl = 99, jobs =  397602, name = 'Gere Ring' },
            { id = 26186, lvl = 99, jobs = 2465590, name = 'Ilabrat Ring' },
            { id = 26199, lvl = 99, jobs = 4194303, name = 'Karieyh Ring +1' },
            { id = 26214, lvl = 99, jobs = 4194303, name = 'Epaminondass Ring' },
            { id = 11628, lvl = 75, jobs = 4194303, name = 'Strigoi Ring' },
            { id = 15548, lvl = 75, jobs = 4194303, name = 'Marss Ring' },
            { id = 14630, lvl = 74, jobs = 4194303, name = 'Flame Ring' },
            { id = 11629, lvl = 75, jobs = 4194303, name = 'Zilant Ring' },
            { id = 15543, lvl = 30, jobs = 4194303, name = 'Rajas Ring' },
            { id = 15818, lvl = 70, jobs = 4194303, name = 'Molioness Ring' },
            { id = 13551, lvl = 49, jobs = 4194303, name = 'Kshama Ring No.8' },
            { id = 14609, lvl = 54, jobs = 4194303, name = 'Victory Ring +1' },
            { id = 13538, lvl = 54, jobs = 4194303, name = 'Victory Ring' },
            { id = 15808, lvl = 50, jobs = 4194303, name = 'Ulthalams Ring' },
            { id = 15778, lvl = 50, jobs = 4194303, name = 'Unyielding Ring' },
            { id = 14674, lvl = 57, jobs = 4194303, name = 'Toreadors Ring' },
            { id = 15779, lvl = 50, jobs = 4194303, name = 'Garrulous Ring' },
            { id = 15828, lvl = 70, jobs = 4194303, name = 'Blood Ring' },
            { id = 15792, lvl = 70, jobs = 4194303, name = 'Mercenarys Ring' },
            { id = 14601, lvl = 36, jobs = 4194303, name = 'Puissance Ring +1' },
            { id = 13530, lvl = 36, jobs = 4194303, name = 'Puissance Ring' },
            { id = 13281, lvl = 40, jobs = 4194303, name = 'Snipers Ring +1' },
            { id = 14593, lvl = 14, jobs = 4194303, name = 'Courage Ring +1' },
            { id = 13522, lvl = 14, jobs = 4194303, name = 'Courage Ring' },
            { id = 13514, lvl = 30, jobs = 4194303, name = 'Archers Ring' },
            { id = 15551, lvl = 30, jobs = 4194303, name = 'Shikaree Ring' },
            { id = 15544, lvl = 30, jobs = 4194303, name = 'Sattva Ring' },
            { id = 14595, lvl = 14, jobs = 4194303, name = 'Balance Ring +1' },
            { id = 13524, lvl = 14, jobs = 4194303, name = 'Balance Ring' },
            { id = 13495, lvl =  1, jobs = 4194303, name = 'San Dorian Ring' },
            { id = 13497, lvl =  1, jobs = 4194303, name = 'Bastokan Ring' },
            { id = 14670, lvl = 10, jobs = 4194303, name = 'Safeguard Ring' },
            { id = 13282, lvl = 10, jobs = 4194303, name = 'Saintly Ring' },
            { id = 10796, lvl =  1, jobs = 4194303, name = 'Decennial Ring' },
            { id = 11666, lvl =  1, jobs = 4194303, name = 'Novennial Ring' },
        },
    },
    tank =
    {
        HEAD =
        {
            { id = 23091, lvl = 99, jobs =      64, name = 'Chevaliers Armet +2' },
            { id = 23761, lvl = 99, jobs = 4194303, name = 'Nyame Helm' },
            { id = 23757, lvl = 99, jobs =     193, name = 'Sakpatas Helm' },
            { id = 23085, lvl = 99, jobs =       1, name = 'Boii Mask +2' },
            { id = 16117, lvl = 75, jobs =     193, name = 'Valhalla Helm' },
            { id = 12434, lvl = 75, jobs =    7939, name = 'Genbus Kabuto' },
            { id = 13911, lvl = 73, jobs =      65, name = 'Kaiser Schaller' },
            { id = 12421, lvl = 73, jobs =      65, name = 'Koenig Schaller' },
            { id = 13886, lvl = 63, jobs =    6146, name = 'Arh. Jinpachi +1' },
            { id = 16146, lvl = 68, jobs =     193, name = 'Iron Ram Sallet' },
            { id = 13914, lvl = 70, jobs =   10432, name = 'Aegishjalmr' },
            { id = 13881, lvl = 63, jobs =    6146, name = 'Arhats Jinpachi' },
            { id = 15160, lvl = 73, jobs =       8, name = 'Genie Tiara' },
            { id = 11497, lvl = 75, jobs = 3662710, name = 'Spurrer Beret' },
            { id = 12515, lvl = 56, jobs =      64, name = 'Gallant Coronet' },
            { id = 11498, lvl = 59, jobs = 2472947, name = 'Zeal Cap +1' },
            { id = 12511, lvl = 56, jobs =       1, name = 'Fighters Mask' },
            { id = 16112, lvl = 65, jobs = 3662710, name = 'Tabin Beret +1' },
            { id = 13848, lvl = 60, jobs =     193, name = 'Gilt Armet' },
            { id = 13951, lvl = 74, jobs = 1622044, name = 'Elite Beret +1' },
            { id = 15263, lvl = 70, jobs = 4194303, name = 'Hydra Cap' },
            { id = 16080, lvl = 53, jobs = 4179646, name = 'Magi Hat' },
            { id = 15150, lvl = 50, jobs = 2141649, name = 'Shock Mask' },
            { id = 27658, lvl = 45, jobs =    8385, name = 'Ates Mask' },
            { id = 13894, lvl = 43, jobs =     193, name = 'Irn.Msk. Armet +2' },
            { id = 13893, lvl = 43, jobs =     193, name = 'Irn.Msk. Armet +1' },
            { id = 15149, lvl = 50, jobs = 4194303, name = 'Rival Ribbon' },
            { id = 12422, lvl = 40, jobs =     193, name = 'Irn.Msk. Armet' },
            { id = 13831, lvl = 40, jobs =     193, name = 'Sallet +1' },
            { id = 12416, lvl = 40, jobs =     193, name = 'Sallet' },
            { id = 16095, lvl = 35, jobs =  137218, name = 'Hikazu Kabuto' },
            { id = 12481, lvl = 38, jobs = 2473969, name = 'Cuir Bandana +1' },
            { id = 15171, lvl = 29, jobs =      65, name = 'Kampfschaller' },
            { id = 13834, lvl = 38, jobs = 4179646, name = 'Mages Hat' },
            { id = 15167, lvl = 29, jobs =      65, name = 'Eisenschaller' },
            { id = 12431, lvl = 30, jobs =    6593, name = 'Ryl. Squires Helm' },
            { id = 15208, lvl = 20, jobs = 4179646, name = 'Barons Chapeau' },
            { id = 12438, lvl = 30, jobs = 2141649, name = 'Centurions Visor' },
            { id = 13896, lvl = 15, jobs = 2473969, name = 'Kingdom Bandana' },
            { id = 15186, lvl = 20, jobs = 4194303, name = 'Trump Crown' },
            { id = 12502, lvl =  9, jobs = 4179646, name = 'Cmp. Eye Circlet' },
            { id = 15180, lvl =  1, jobs = 4194303, name = 'Cache-Nez' },
            { id = 12510, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Bandana' },
            { id = 12487, lvl = 10, jobs = 2141649, name = 'Faceguard +1' },
            { id = 11811, lvl =  1, jobs = 4194303, name = 'Destrier Beret' },
            { id = 15176, lvl =  1, jobs = 4194303, name = 'Pumpkin Head II' },
            { id = 12463, lvl =  1, jobs = 2472947, name = 'Bronze Cap +1' },
        },
        BODY =
        {
            { id = 23768, lvl = 99, jobs = 4194303, name = 'Nyame Mail' },
            { id = 23764, lvl = 99, jobs =     193, name = 'Sakpatas Breastplate' },
            { id = 23170, lvl = 99, jobs =  262144, name = 'Maculele Casaque +2' },
            { id = 23164, lvl = 99, jobs =    4096, name = 'Hattori Ningi +2' },
            { id = 14577, lvl = 75, jobs =     193, name = 'Valhalla Brstplate' },
            { id = 14370, lvl = 73, jobs =      65, name = 'Kaiser Cuirass' },
            { id = 12549, lvl = 73, jobs =      65, name = 'Koenig Cuirass' },
            { id = 14538, lvl = 72, jobs = 2107392, name = 'Hydra Mail +1' },
            { id = 13802, lvl = 64, jobs =    6146, name = 'Arhats Gi +1' },
            { id = 11286, lvl = 71, jobs =  397154, name = 'Avalon Breastplate' },
            { id = 14588, lvl = 68, jobs =     193, name = 'Iron Ram Hauberk' },
            { id = 13795, lvl = 64, jobs =    6146, name = 'Arhats Gi' },
            { id = 12638, lvl = 60, jobs =       1, name = 'Fighters Lorica' },
            { id = 11287, lvl = 71, jobs = 2593459, name = 'Antares Harness' },
            { id = 13734, lvl = 57, jobs = 2472947, name = 'Scp. Harness +1' },
            { id = 14469, lvl = 75, jobs =       4, name = 'Reverend Mail' },
            { id = 14540, lvl = 70, jobs =    3072, name = 'Kyudogi +1' },
            { id = 12579, lvl = 57, jobs = 2472947, name = 'Scorpion Harness' },
            { id = 14570, lvl = 75, jobs = 1720860, name = 'Goliard Saio' },
            { id = 12644, lvl = 60, jobs =      64, name = 'Gallant Surcoat' },
            { id = 14412, lvl = 50, jobs =      65, name = 'Parade Cuirass' },
            { id = 14591, lvl = 68, jobs = 3850780, name = 'Cobra Robe' },
            { id = 14403, lvl = 50, jobs =  262176, name = 'Rapparee Harness' },
            { id = 13736, lvl = 45, jobs =     193, name = 'Stolid Breastplate' },
            { id = 13813, lvl = 40, jobs =       4, name = 'Divine Breastplate' },
            { id = 13710, lvl = 45, jobs = 2473969, name = 'Brigandine +1' },
            { id = 13799, lvl = 52, jobs = 3662710, name = 'Gaia Doublet +1' },
            { id = 14543, lvl = 53, jobs = 4179646, name = 'Magi Coat' },
            { id = 14411, lvl = 50, jobs =       2, name = 'Aikido Gi' },
            { id = 13812, lvl = 40, jobs =       4, name = 'Holy Breastplate' },
            { id = 13724, lvl = 40, jobs =     193, name = 'Breastplate +1' },
            { id = 14549, lvl = 35, jobs =    8385, name = 'Deimoss Cuirass' },
            { id = 12606, lvl = 50, jobs = 4179646, name = 'Tct.Mgc. Coat' },
            { id = 13728, lvl = 40, jobs =    6146, name = 'Jujitsu Gi' },
            { id = 12559, lvl = 40, jobs =    6593, name = 'Ryl.Sqr. Chainmail' },
            { id = 14435, lvl = 29, jobs =      65, name = 'Kampfbrust' },
            { id = 13719, lvl = 40, jobs = 4179646, name = 'Ryl.Sqr. Robe' },
            { id = 14431, lvl = 29, jobs =      65, name = 'Eisenbrust' },
            { id = 12566, lvl = 30, jobs = 2141649, name = 'Ctr. Scale Mail' },
            { id = 14548, lvl = 25, jobs =    8385, name = 'Phoboss Cuirass' },
            { id = 14351, lvl = 25, jobs =    6146, name = 'Federation Gi' },
            { id = 12598, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Doublet' },
            { id = 14427, lvl = 29, jobs = 1720332, name = 'Seers Tunic +1' },
            { id = 12653, lvl = 20, jobs =    6146, name = 'Mercenarys Gi' },
            { id = 13716, lvl = 16, jobs = 2472947, name = 'Bone Harness +1' },
            { id = 14547, lvl = 15, jobs =    8385, name = 'Enyos Brstplate' },
            { id = 13697, lvl = 17, jobs = 2473969, name = 'Fine Jerkin' },
            { id = 14447, lvl = 20, jobs = 4179646, name = 'Barons Saio' },
            { id = 12661, lvl = 10, jobs = 2141649, name = 'Solid Mail' },
            { id = 12560, lvl = 10, jobs = 2141649, name = 'Scale Mail' },
            { id = 12629, lvl = 10, jobs = 2472947, name = 'Lgn. Harness' },
            { id = 12630, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Vest' },
            { id = 14585, lvl =  1, jobs = 4194303, name = 'Fourth Tunica' },
            { id = 12607, lvl =  1, jobs = 2472947, name = 'Bronze Harness +1' },
            { id = 11330, lvl =  1, jobs = 4194303, name = 'Blksmith. Smock' },
            { id = 12576, lvl =  1, jobs = 2472947, name = 'Bronze Harness' },
        },
        HANDS =
        {
            { id = 23775, lvl = 99, jobs = 4194303, name = 'Nyame Gauntlets' },
            { id = 23771, lvl = 99, jobs =     193, name = 'Sakpatas Gauntlets' },
            { id = 23237, lvl = 99, jobs =  262144, name = 'Maculele Bangles +2' },
            { id = 23225, lvl = 99, jobs =      64, name = 'Chevaliers Gauntlets +2' },
            { id = 12690, lvl = 75, jobs =    7939, name = 'Seiryus Kote' },
            { id = 14061, lvl = 73, jobs =      65, name = 'Kaiser Handschuhs' },
            { id = 12677, lvl = 73, jobs =      65, name = 'Kng. Handschuhs' },
            { id = 14950, lvl = 72, jobs = 2107392, name = 'Hydra Fng. Gnt. +1' },
            { id = 15009, lvl = 68, jobs =     193, name = 'I.R. Dastanas' },
            { id = 14883, lvl = 70, jobs =      64, name = 'Kings Gauntlets' },
            { id = 15018, lvl = 70, jobs =     193, name = 'Ritterhentzes' },
            { id = 14877, lvl = 70, jobs =       4, name = 'Blessed Mitts +1' },
            { id = 14066, lvl = 63, jobs = 4179646, name = 'Feronias Bangles' },
            { id = 14951, lvl = 68, jobs = 2141649, name = 'Dragon Kote' },
            { id = 14936, lvl = 50, jobs = 4194303, name = 'Storm Manopolas' },
            { id = 13994, lvl = 63, jobs = 2472947, name = 'Dst. Mittens +1' },
            { id = 13961, lvl = 54, jobs =       1, name = 'Fighters Mufflers' },
            { id = 14063, lvl = 56, jobs = 4179646, name = 'Prt. Bangles' },
            { id = 13972, lvl = 56, jobs =    2048, name = 'Myochin Kote' },
            { id = 14020, lvl = 50, jobs = 2472947, name = 'Enkeladoss Brc.' },
            { id = 12734, lvl = 50, jobs = 4179646, name = 'Tct.Mgc. Cuffs' },
            { id = 27940, lvl = 45, jobs =  137218, name = 'Genta Gote' },
            { id = 14019, lvl = 40, jobs = 2472947, name = 'Ogygoss Brc.' },
            { id = 14018, lvl = 30, jobs = 2472947, name = 'Gigas Bracelets' },
            { id = 14863, lvl = 29, jobs =      65, name = 'Kampfhentzes' },
            { id = 12678, lvl = 40, jobs =     193, name = 'Irn.Msk. Gauntlets' },
            { id = 15058, lvl = 30, jobs = 3662710, name = 'Combat Mittens +1' },
            { id = 12793, lvl = 38, jobs = 4179646, name = 'Mages Cuffs' },
            { id = 15053, lvl = 30, jobs = 3662710, name = 'Combat Mittens' },
            { id = 12749, lvl = 16, jobs = 4179646, name = 'Scentless Armlets' },
            { id = 12799, lvl = 14, jobs = 3662710, name = 'Battle Gloves' },
            { id = 13953, lvl = 20, jobs = 3851870, name = 'White Mitts +1' },
            { id = 14038, lvl = 15, jobs = 2473969, name = 'Kingdom Gloves' },
            { id = 12768, lvl = 10, jobs = 2141649, name = 'Solid Fng. Gnt.' },
            { id = 12688, lvl = 10, jobs = 2141649, name = 'Scale Fng. Gnt.' },
            { id = 12752, lvl = 10, jobs = 2472947, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Gloves' },
            { id = 12775, lvl =  8, jobs = 3851870, name = 'Mitts +1' },
            { id = 14831, lvl =  1, jobs = 4194303, name = 'Smithys Mitts' },
            { id = 12695, lvl =  1, jobs = 2472947, name = 'Bronze Mittens +1' },
            { id = 12744, lvl =  1, jobs = 4179646, name = 'Cuffs +1' },
            { id = 12704, lvl =  1, jobs = 2472947, name = 'Bronze Mittens' },
        },
        LEGS =
        {
            { id = 23307, lvl = 99, jobs = 2097152, name = 'Erilaz Leg Guards +2' },
            { id = 23782, lvl = 99, jobs = 4194303, name = 'Nyame Flanchard' },
            { id = 23292, lvl = 99, jobs =      64, name = 'Chevaliers Cuisses +2' },
            { id = 23778, lvl = 99, jobs =     193, name = 'Sakpatas Cuisses' },
            { id = 14283, lvl = 73, jobs =      65, name = 'Kaiser Diechlings' },
            { id = 12805, lvl = 73, jobs =      65, name = 'Koenig Diechlings' },
            { id = 15616, lvl = 72, jobs = 2107392, name = 'Hydra Cuisses +1' },
            { id = 15407, lvl = 74, jobs =       1, name = 'Ucn. Subligar +1' },
            { id = 16315, lvl = 68, jobs =     193, name = 'Iron Ram Hose' },
            { id = 12818, lvl = 75, jobs =    7939, name = 'Byakkos Haidate' },
            { id = 15399, lvl = 70, jobs =      64, name = 'Kings Cuisses' },
            { id = 15619, lvl = 71, jobs = 4179646, name = 'Princes Slops' },
            { id = 14214, lvl = 58, jobs =       1, name = 'Fighters Cuisses' },
            { id = 14234, lvl = 65, jobs = 2472947, name = 'Dst. Subligar +1' },
            { id = 15600, lvl = 54, jobs =   32768, name = 'Magus Shalwar' },
            { id = 14220, lvl = 58, jobs =      64, name = 'Gallant Breeches' },
            { id = 14238, lvl = 70, jobs =   66592, name = 'War Brais +1' },
            { id = 14221, lvl = 56, jobs =     128, name = 'Chaos Flanchard' },
            { id = 14215, lvl = 60, jobs =       2, name = 'Temple Hose' },
            { id = 15595, lvl = 70, jobs = 1589788, name = 'Hydra Brais' },
            { id = 16318, lvl = 68, jobs = 3850780, name = 'Cobra Trews' },
            { id = 14213, lvl = 58, jobs = 2473969, name = 'Beak Trousers +1' },
            { id = 14217, lvl = 56, jobs =       8, name = 'Wizards Tonban' },
            { id = 14216, lvl = 56, jobs =       4, name = 'Healers Pantaln.' },
            { id = 14335, lvl = 50, jobs =    4096, name = 'Nokizaru Hakama' },
            { id = 12806, lvl = 50, jobs =     193, name = 'Irn.Msk. Cuisses' },
            { id = 15373, lvl = 47, jobs =      32, name = 'Bravos Subligar' },
            { id = 15621, lvl = 53, jobs = 4179646, name = 'Magi Slops' },
            { id = 15386, lvl = 50, jobs =      65, name = 'Pisces Subligar' },
            { id = 14246, lvl = 50, jobs = 2141649, name = 'Steel Cuisses +1' },
            { id = 15369, lvl = 50, jobs =       2, name = 'Aikido Koshita' },
            { id = 12919, lvl = 48, jobs = 2473969, name = 'Dino Trousers' },
            { id = 14276, lvl = 43, jobs = 3851870, name = 'C.C. Slacks +2' },
            { id = 12870, lvl = 40, jobs = 3851870, name = 'Cmb.Cst. Slacks' },
            { id = 12916, lvl = 40, jobs =     193, name = 'Cuisses +1' },
            { id = 12815, lvl = 40, jobs =    6593, name = 'Ryl.Sqr. Breeches' },
            { id = 12800, lvl = 40, jobs =     193, name = 'Cuisses' },
            { id = 14332, lvl = 29, jobs =      65, name = 'Kampfdiechlings' },
            { id = 12911, lvl = 38, jobs = 2473969, name = 'Cuir Trousers +1' },
            { id = 14329, lvl = 29, jobs =      65, name = 'Eisendiechlings' },
            { id = 14266, lvl = 25, jobs = 2473969, name = 'Kingdom Trousers' },
            { id = 15422, lvl = 29, jobs =     128, name = 'Black Hose' },
            { id = 12922, lvl = 24, jobs = 3851870, name = 'Martial Slacks' },
            { id = 12882, lvl = 20, jobs = 2473969, name = 'Ryl.Ftm. Trousers' },
            { id = 12881, lvl = 20, jobs = 2472947, name = 'Lgn. Subligar' },
            { id = 12855, lvl = 20, jobs =    6146, name = 'Mrc. Sitabaki' },
            { id = 12912, lvl = 16, jobs = 2472947, name = 'Bone Subligar +1' },
            { id = 12917, lvl = 20, jobs = 3851870, name = 'Mages Slacks' },
            { id = 12863, lvl = 10, jobs = 2141649, name = 'Solid Cuisses' },
            { id = 12816, lvl = 10, jobs = 2141649, name = 'Scale Cuisses' },
            { id = 12898, lvl =  8, jobs = 3851870, name = 'Slacks +1' },
            { id = 12899, lvl =  8, jobs =    6146, name = 'Sitabaki +1' },
            { id = 12908, lvl =  7, jobs = 2473969, name = 'Lth. Trousers +1' },
            { id = 12823, lvl =  1, jobs = 2472947, name = 'Brz. Subligar +1' },
            { id = 12832, lvl =  1, jobs = 2472947, name = 'Bronze Subligar' },
            { id = 12897, lvl =  1, jobs = 4179646, name = 'Slops +1' },
            { id = 12856, lvl =  1, jobs = 4179646, name = 'Slops' },
        },
        FEET =
        {
            { id = 23789, lvl = 99, jobs = 4194303, name = 'Nyame Sollerets' },
            { id = 23374, lvl = 99, jobs = 2097152, name = 'Erilaz Greaves +2' },
            { id = 23373, lvl = 99, jobs = 1048576, name = 'Azimuth Gaiters +2' },
            { id = 23785, lvl = 99, jobs =     193, name = 'Sakpatas Leggings' },
            { id = 15704, lvl = 72, jobs = 2107392, name = 'Hydra Greaves +1' },
            { id = 14163, lvl = 73, jobs =      65, name = 'Kaiser Schuhs' },
            { id = 12933, lvl = 73, jobs =      65, name = 'Koenig Schuhs' },
            { id = 15719, lvl = 75, jobs =  137218, name = 'Usukane Sune-Ate' },
            { id = 15661, lvl = 75, jobs =   41184, name = 'Homam Gambieras' },
            { id = 14188, lvl = 72, jobs = 2473969, name = 'Dusk Ledelsens +1' },
            { id = 11380, lvl = 70, jobs = 2293763, name = 'Hermes Sandals +1' },
            { id = 15755, lvl = 68, jobs =     193, name = 'Iron Ram Greaves' },
            { id = 11379, lvl = 70, jobs = 2293763, name = 'Hermes Sandals' },
            { id = 15328, lvl = 69, jobs = 3851870, name = 'Root Sabots' },
            { id = 14100, lvl = 52, jobs =    2048, name = 'Myochin Sune-Ate' },
            { id = 14110, lvl = 65, jobs = 2472947, name = 'Dst. Leggings +1' },
            { id = 14099, lvl = 60, jobs =    1024, name = 'Hunters Socks' },
            { id = 14089, lvl = 52, jobs =       1, name = 'Fighters Calligae' },
            { id = 14098, lvl = 52, jobs =     512, name = 'Choral Slippers' },
            { id = 14101, lvl = 54, jobs =    4096, name = 'Ninja Kyahan' },
            { id = 13054, lvl = 39, jobs =    6146, name = 'Fuma Kyahan' },
            { id = 15737, lvl = 39, jobs =    6146, name = 'Sarutobi Kyahan' },
            { id = 15739, lvl = 59, jobs = 3662710, name = 'Tabin Boots +1' },
            { id = 28219, lvl = 45, jobs = 2426144, name = 'Idis Ledelsens' },
            { id = 15707, lvl = 53, jobs = 4179646, name = 'Magi Pigaches' },
            { id = 28218, lvl = 45, jobs =    8385, name = 'Ates Sollerets' },
            { id = 15321, lvl = 29, jobs =      65, name = 'Kampfschuhs' },
            { id = 15692, lvl = 50, jobs = 4194303, name = 'Storm Crackows' },
            { id = 14135, lvl = 28, jobs = 3851870, name = 'Air Solea +1' },
            { id = 15317, lvl = 29, jobs =      65, name = 'Eisenschuhs' },
            { id = 11401, lvl = 25, jobs = 4179646, name = 'Ramblers Gaiters' },
            { id = 15348, lvl = 38, jobs = 4194303, name = 'Mountain Gaiters' },
            { id = 14133, lvl = 24, jobs = 2473969, name = 'Winged Boots +1' },
            { id = 13012, lvl = 18, jobs = 4194303, name = 'Power Sandals' },
            { id = 10648, lvl = 20, jobs =    1056, name = 'Areion Boots +1' },
            { id = 13052, lvl = 13, jobs = 3851870, name = 'Light Soleas' },
            { id = 14146, lvl = 15, jobs = 2473969, name = 'Kingdom Boots' },
            { id = 13014, lvl =  7, jobs = 2473969, name = 'Leaping Boots' },
            { id = 15351, lvl =  7, jobs = 2473969, name = 'Bounding Boots' },
            { id = 13024, lvl = 10, jobs = 2141649, name = 'Solid Greaves' },
            { id = 12944, lvl = 10, jobs = 2141649, name = 'Scale Greaves' },
            { id = 13031, lvl =  8, jobs =    6146, name = 'Kyahan +1' },
            { id = 13037, lvl =  8, jobs = 3851870, name = 'Solea +1' },
            { id = 11400, lvl =  1, jobs = 4194303, name = 'Noble Poulaines' },
            { id = 12951, lvl =  1, jobs = 2472947, name = 'Brz. Leggings +1' },
            { id = 12983, lvl =  1, jobs = 4179646, name = 'Ash Clogs +1' },
            { id = 11403, lvl =  1, jobs = 4194303, name = 'Talaria' },
        },
        NECK =
        {
            { id = 25503, lvl = 99, jobs =   16384, name = 'Smn. Collar +2' },
            { id = 26037, lvl = 99, jobs = 2101315, name = 'Moonlight Necklace' },
            { id = 25455, lvl = 99, jobs =      64, name = 'Kgt. Beads +2' },
            { id = 25545, lvl = 99, jobs = 2097152, name = 'Futhark Torque +2' },
            { id = 26002, lvl = 99, jobs = 4194303, name = 'Loricate Torque +1' },
            { id = 16267, lvl = 70, jobs = 2473969, name = 'Ritter Gorget' },
            { id = 16302, lvl = 70, jobs = 4194303, name = 'Bloodbead Gorget' },
            { id = 15536, lvl = 75, jobs = 4194303, name = 'Rho Necklace' },
            { id = 15521, lvl = 60, jobs = 4194303, name = 'Tempered Chain' },
            { id = 16266, lvl = 70, jobs = 4194303, name = 'Wivre Gorget +1' },
            { id = 13064, lvl = 55, jobs =     193, name = 'Irn.Msk. Gorget' },
            { id = 16293, lvl = 60, jobs = 4194303, name = 'Cougar Pendant' },
            { id = 13123, lvl = 56, jobs = 2141649, name = 'Mermans Gorget' },
            { id = 15504, lvl = 30, jobs = 2141649, name = 'Ajase Beads' },
            { id = 13166, lvl = 50, jobs = 4194303, name = 'Hateful Collar' },
            { id = 13105, lvl = 50, jobs =    6593, name = 'T.K. Army Collar' },
            { id = 13107, lvl = 50, jobs =    6593, name = 'R.K. Army Collar' },
            { id = 13135, lvl = 48, jobs = 4194303, name = 'Promise Badge' },
            { id = 13118, lvl = 35, jobs = 4194303, name = 'Shield Pendant' },
            { id = 13056, lvl = 33, jobs = 4194303, name = 'Peacock Charm' },
            { id = 15515, lvl = 33, jobs = 4194303, name = 'Peacock Amulet' },
            { id = 13058, lvl = 20, jobs = 4194303, name = 'Bloodbead Amulet' },
            { id = 13102, lvl = 30, jobs = 4179646, name = 'Paisley Scarf' },
            { id = 13104, lvl = 30, jobs =    6593, name = 'Ryl.Sqr. Collar' },
            { id = 16304, lvl = 18, jobs = 4194303, name = 'Focus Collar +1' },
            { id = 15503, lvl = 14, jobs = 4194303, name = 'Van Pendant' },
            { id = 13113, lvl = 20, jobs = 3851870, name = 'Black Neckerchief' },
            { id = 16296, lvl =  9, jobs = 2141649, name = 'Armigers Lace' },
            { id = 13101, lvl = 10, jobs = 4179646, name = 'Green Scarf' },
            { id = 16282, lvl =  5, jobs =  131072, name = 'Bfn. Collar +1' },
            { id = 13112, lvl =  7, jobs =      32, name = 'Rabbit Charm' },
            { id = 13069, lvl =  7, jobs = 2473969, name = 'Leather Gorget +1' },
            { id = 13078, lvl =  1, jobs = 4194303, name = 'Portafurnace' },
            { id = 13121, lvl =  1, jobs = 4194303, name = 'Beast Collar' },
            { id = 13122, lvl =  1, jobs = 4194303, name = 'Miners Pendant' },
            { id = 16273, lvl =  1, jobs = 4194303, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 13186, lvl = 70, jobs =       2, name = 'Black Belt' },
            { id = 26341, lvl = 99, jobs =  131074, name = 'Moonbow Belt +1' },
            { id = 26336, lvl = 99, jobs =  155904, name = 'Klouskap Sash +1' },
            { id = 26365, lvl = 99, jobs = 4194303, name = 'Cornelias Belt' },
            { id = 28456, lvl = 99, jobs = 2465590, name = 'Kasiri Belt' },
            { id = 13202, lvl = 40, jobs =       2, name = 'Brown Belt' },
            { id = 15458, lvl = 75, jobs = 4194303, name = 'Ninurtas Sash' },
            { id = 13250, lvl = 65, jobs = 2473969, name = 'Sonic Belt +1' },
            { id = 13249, lvl = 65, jobs = 2473969, name = 'Sonic Belt' },
            { id = 15877, lvl = 70, jobs =    4096, name = 'Koga Sarashi' },
            { id = 13189, lvl = 55, jobs = 2473969, name = 'Speed Belt' },
            { id = 15899, lvl = 55, jobs = 2473969, name = 'Velocious Belt' },
            { id = 15912, lvl = 60, jobs = 4194303, name = 'Lieutenants Sash' },
            { id = 15457, lvl = 50, jobs = 4194303, name = 'Swift Belt' },
            { id = 13201, lvl = 18, jobs =       2, name = 'Purple Belt' },
            { id = 13237, lvl = 38, jobs = 2465590, name = 'Survival Belt' },
            { id = 15941, lvl = 44, jobs = 4194303, name = 'Headlong Belt' },
            { id = 13216, lvl =  1, jobs = 4194303, name = 'Gold Mog. Belt' },
            { id = 13240, lvl = 15, jobs = 2472947, name = 'Warriors Belt +1' },
            { id = 13214, lvl = 40, jobs =     193, name = 'Waistbelt +1' },
            { id = 15908, lvl = 40, jobs = 3851870, name = 'Qiqirn Sash +1' },
            { id = 13221, lvl = 30, jobs = 4179646, name = 'Mrc.Cpt. Belt' },
            { id = 13272, lvl = 40, jobs = 4194303, name = 'Corsette +1' },
            { id = 13194, lvl = 15, jobs = 2472947, name = 'Warriors Belt' },
            { id = 13225, lvl = 18, jobs = 2141649, name = 'Brave Belt' },
            { id = 13217, lvl =  1, jobs = 4194303, name = 'Silver Mog. Belt' },
            { id = 15456, lvl =  1, jobs = 4194303, name = 'Dash Sash' },
            { id = 13224, lvl = 20, jobs = 3851870, name = 'Silver Obi +1' },
            { id = 13218, lvl =  1, jobs = 4194303, name = 'Bronze Mog. Belt' },
        },
        BACK =
        {
            { id = 26269, lvl = 99, jobs = 4194303, name = 'Moonlight Cape' },
            { id = 27615, lvl = 99, jobs = 2473971, name = 'Reiki Cloak' },
            { id = 28623, lvl = 99, jobs =      64, name = 'Weard Mantle' },
            { id = 28618, lvl = 99, jobs =       2, name = 'Anchorets Mantle' },
            { id = 15481, lvl = 70, jobs =      64, name = 'Valor Cape' },
            { id = 13652, lvl = 68, jobs = 1753628, name = 'Umbra Cape' },
            { id = 13648, lvl = 70, jobs = 4194303, name = 'Gigant Mantle' },
            { id = 13651, lvl = 68, jobs = 1753628, name = 'Cheviot Cape' },
            { id = 13604, lvl = 60, jobs = 2473971, name = 'Behem. Mantle +1' },
            { id = 13591, lvl = 60, jobs = 2473971, name = 'Behemoth Mantle' },
            { id = 11542, lvl = 53, jobs = 2473971, name = 'Kinesis Mantle +1' },
            { id = 13691, lvl = 60, jobs =      65, name = 'Knightly Mantle' },
            { id = 15492, lvl = 60, jobs = 1753628, name = 'Intensifying Cape' },
            { id = 15483, lvl = 50, jobs = 4194303, name = 'Storm Mantle' },
            { id = 13598, lvl = 46, jobs = 2473971, name = 'Bat Cape' },
            { id = 15468, lvl = 40, jobs = 2473971, name = 'Resentment Cape' },
            { id = 13616, lvl = 49, jobs = 1753628, name = 'Dodge Cape' },
            { id = 13644, lvl = 30, jobs = 1753628, name = 'Midnight Cape' },
            { id = 13623, lvl = 40, jobs =    8641, name = 'Earth Mantle' },
            { id = 13632, lvl = 24, jobs = 2473971, name = 'Nomads Mantle +1' },
            { id = 13674, lvl = 40, jobs =    7201, name = 'Agile Mantle' },
            { id = 13643, lvl = 30, jobs = 1753628, name = 'Sarcenet Cape' },
            { id = 13631, lvl = 24, jobs = 2473971, name = 'Nomads Mantle' },
            { id = 13613, lvl = 12, jobs = 2473971, name = 'Travelers Mantle' },
            { id = 13600, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle +1' },
            { id = 13680, lvl = 20, jobs = 2473971, name = 'Variable Mantle' },
            { id = 13588, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle' },
            { id = 13601, lvl = 18, jobs = 1753628, name = 'Cotton Cape +1' },
            { id = 13607, lvl = 10, jobs = 1753628, name = 'Mist Silk Cape' },
            { id = 13605, lvl =  7, jobs = 1753628, name = 'Cape +1' },
            { id = 13599, lvl =  4, jobs = 2473971, name = 'Rabbit Mantle +1' },
            { id = 13583, lvl =  7, jobs = 1753628, name = 'Cape' },
            { id = 11009, lvl =  1, jobs = 4194303, name = 'Shapers Shawl' },
            { id = 16243, lvl =  1, jobs = 4194303, name = 'Drovers Mantle' },
            { id = 11002, lvl =  1, jobs = 4194303, name = 'Dragon Tank' },
            { id = 13682, lvl =  1, jobs = 4194303, name = 'Ether Tank' },
        },
        EAR =
        {
            { id = 27540, lvl = 99, jobs = 4194303, name = 'Eabani Earring' },
            { id = 28483, lvl = 99, jobs = 4194303, name = 'Cryptic Earring' },
            { id = 28478, lvl = 99, jobs = 4194303, name = 'Etiolation Earring' },
            { id = 26117, lvl = 99, jobs = 4194303, name = 'Crep. Earring' },
            { id = 15965, lvl = 72, jobs = 4194303, name = 'Ethereal Earring' },
            { id = 16058, lvl = 75, jobs = 4194303, name = 'Colossuss Earring' },
            { id = 15994, lvl = 67, jobs = 4194303, name = 'Harmonius Earring' },
            { id = 16056, lvl = 75, jobs = 4194303, name = 'Pagondas Earring' },
            { id = 16010, lvl = 61, jobs = 4194303, name = 'Pennon Earring +1' },
            { id = 15993, lvl = 67, jobs = 4194303, name = 'Crimson Earring' },
            { id = 16009, lvl = 61, jobs = 4194303, name = 'Pennon Earring' },
            { id = 14761, lvl = 60, jobs = 4194303, name = 'Elusive Earring' },
            { id = 15970, lvl = 50, jobs = 4194303, name = 'Stoic Earring' },
            { id = 13418, lvl = 54, jobs = 2465590, name = 'Eris Earring +1' },
            { id = 14723, lvl = 33, jobs = 4194303, name = 'Pigeon Earring +1' },
            { id = 13359, lvl = 32, jobs = 4194303, name = 'Bloodbead Earring' },
            { id = 13397, lvl = 60, jobs = 4194303, name = 'Ptm. Earring +1' },
            { id = 15972, lvl = 50, jobs = 4194303, name = 'Insomnia Earring' },
            { id = 14722, lvl = 33, jobs = 4194303, name = 'Pigeon Earring' },
            { id = 15974, lvl = 50, jobs = 4194303, name = 'Velocity Earring' },
            { id = 14711, lvl = 49, jobs = 4194303, name = 'Allure Earring +1' },
            { id = 14806, lvl = 40, jobs = 4194303, name = 'Intruder Earring' },
            { id = 11043, lvl = 30, jobs = 4194303, name = 'Giants Earring' },
            { id = 13366, lvl = 29, jobs = 4194303, name = 'Dodge Earring' },
            { id = 13371, lvl = 24, jobs = 4194303, name = 'Mythril Earring +1' },
            { id = 13365, lvl = 20, jobs = 4194303, name = 'Shield Earring' },
            { id = 13370, lvl = 14, jobs = 4194303, name = 'Silver Earring +1' },
            { id = 14695, lvl = 10, jobs = 4194303, name = 'Hope Earring +1' },
            { id = 13402, lvl =  1, jobs = 4194303, name = 'Cassie Earring' },
            { id = 14757, lvl = 20, jobs = 4194303, name = 'Mecurial Earring' },
            { id = 14803, lvl = 10, jobs = 4194303, name = 'Optical Earring' },
            { id = 13380, lvl = 10, jobs = 4194303, name = 'Hope Earring' },
            { id = 28510, lvl =  1, jobs = 4194303, name = 'M. Slime Earring' },
            { id = 28509, lvl =  1, jobs = 4194303, name = 'She-Slime Earring' },
            { id = 28511, lvl =  1, jobs = 4194303, name = 'Slime Earring' },
        },
        RING =
        {
            { id = 26190, lvl = 99, jobs = 2368481, name = 'Moonlight Ring' },
            { id = 13566, lvl = 70, jobs = 4194303, name = 'Defending Ring' },
            { id = 26200, lvl = 99, jobs = 4194303, name = 'Vocane Ring +1' },
            { id = 27588, lvl = 99, jobs = 4194303, name = 'Vocane Ring' },
            { id = 26191, lvl = 99, jobs = 2571747, name = 'Regal Ring' },
            { id = 13567, lvl = 57, jobs = 4194303, name = 'Bomb Queen Ring' },
            { id = 15859, lvl = 75, jobs = 4194303, name = 'Succor Ring' },
            { id = 13302, lvl = 62, jobs = 4194303, name = 'Bloodbead Ring' },
            { id = 11630, lvl = 75, jobs = 4194303, name = 'Corneus Ring' },
            { id = 15855, lvl = 66, jobs = 4194303, name = 'Krousis Ring +1' },
            { id = 15544, lvl = 30, jobs = 4194303, name = 'Sattva Ring' },
            { id = 15844, lvl = 60, jobs = 4194303, name = 'Patronus Ring' },
            { id = 11636, lvl = 60, jobs = 4194303, name = 'R.K. Sigil Ring' },
            { id = 14674, lvl = 57, jobs = 4194303, name = 'Toreadors Ring' },
            { id = 15778, lvl = 50, jobs = 4194303, name = 'Unyielding Ring' },
            { id = 13516, lvl = 50, jobs = 4194303, name = 'Phalanx Ring' },
            { id = 14683, lvl = 49, jobs = 4194303, name = 'Kshama Ring No.4' },
            { id = 15775, lvl = 50, jobs = 4194303, name = 'Unfettered Ring' },
            { id = 14605, lvl = 36, jobs = 4194303, name = 'Verve Ring +1' },
            { id = 13534, lvl = 36, jobs = 4194303, name = 'Verve Ring' },
            { id = 13506, lvl = 16, jobs = 4194303, name = 'Bomb Ring' },
            { id = 13553, lvl = 39, jobs =    8641, name = 'Blitz Ring' },
            { id = 14597, lvl = 14, jobs = 4194303, name = 'Stamina Ring +1' },
            { id = 13514, lvl = 30, jobs = 4194303, name = 'Archers Ring' },
            { id = 15551, lvl = 30, jobs = 4194303, name = 'Shikaree Ring' },
            { id = 13526, lvl = 14, jobs = 4194303, name = 'Stamina Ring' },
            { id = 14592, lvl = 14, jobs = 4194303, name = 'Reflex Ring +1' },
            { id = 13497, lvl =  1, jobs = 4194303, name = 'Bastokan Ring' },
            { id = 14670, lvl = 10, jobs = 4194303, name = 'Safeguard Ring' },
            { id = 13493, lvl =  7, jobs = 4194303, name = 'Brass Ring +1' },
            { id = 13465, lvl =  7, jobs = 4194303, name = 'Brass Ring' },
            { id = 13495, lvl =  1, jobs = 4194303, name = 'San Dorian Ring' },
            { id = 13496, lvl =  1, jobs = 4194303, name = 'Windurstian Ring' },
            { id = 13492, lvl =  1, jobs = 4194303, name = 'Copper Ring +1' },
        },
    },
    ranged =
    {
        HEAD =
        {
            { id = 23101, lvl = 99, jobs =   65536, name = 'Chasseurs Tricorne +2' },
            { id = 23095, lvl = 99, jobs =    1024, name = 'Amini Gapette +2' },
            { id = 23385, lvl = 99, jobs =    1024, name = 'Orion Beret +3' },
            { id = 23755, lvl = 99, jobs =   66560, name = 'Ikengas Hat' },
            { id = 23711, lvl = 99, jobs = 2605043, name = 'Volte Tiara' },
            { id = 23761, lvl = 99, jobs = 4194303, name = 'Nyame Helm' },
            { id = 16159, lvl = 71, jobs = 4194303, name = 'Zhagos Barbut' },
            { id = 15235, lvl = 74, jobs =    1024, name = 'Htr. Beret +1' },
            { id = 11467, lvl = 74, jobs =   65536, name = 'Cor. Tricorne +1' },
            { id = 12518, lvl = 54, jobs =    1024, name = 'Hunters Beret' },
            { id = 16157, lvl = 72, jobs = 2595874, name = 'Enkidus Cap' },
            { id = 16126, lvl = 70, jobs = 2473969, name = 'Bowmans Mask' },
            { id = 13867, lvl = 70, jobs =   66592, name = 'War Beret +1' },
            { id = 15266, lvl = 60, jobs =   65536, name = 'Corsairs Tricorne' },
            { id = 12469, lvl = 70, jobs =   66592, name = 'War Beret' },
            { id = 16067, lvl = 59, jobs =    2497, name = 'Abtal Turban' },
            { id = 16148, lvl = 68, jobs = 2589730, name = 'Cobra Cap' },
            { id = 16061, lvl = 59, jobs =    2497, name = 'Sipahi Turban' },
            { id = 27660, lvl = 45, jobs =  137218, name = 'Genta Kabuto' },
            { id = 16068, lvl = 55, jobs = 2473969, name = 'Akinji Khud' },
            { id = 15263, lvl = 70, jobs = 4194303, name = 'Hydra Cap' },
            { id = 16141, lvl = 45, jobs =    6593, name = 'Iron Ram Helm' },
            { id = 27658, lvl = 45, jobs =    8385, name = 'Ates Mask' },
            { id = 16091, lvl = 35, jobs =   66848, name = 'Freyas Mask' },
            { id = 13856, lvl = 60, jobs =       8, name = 'Wizards Petasos' },
            { id = 15171, lvl = 29, jobs =      65, name = 'Kampfschaller' },
            { id = 12520, lvl = 60, jobs =   16384, name = 'Evokers Horn' },
            { id = 16140, lvl = 60, jobs =  524288, name = 'Scholars M.Board' },
            { id = 15172, lvl = 30, jobs =   66592, name = 'Noct Beret +1' },
            { id = 13855, lvl = 54, jobs =       4, name = 'Healers Cap' },
            { id = 15219, lvl = 39, jobs = 4179646, name = 'Sinister Mask' },
            { id = 16143, lvl = 55, jobs = 4179646, name = 'Cobra Hat' },
            { id = 16090, lvl = 25, jobs =   66848, name = 'Freyrs Mask' },
            { id = 13892, lvl = 34, jobs =    6593, name = 'Kingdom Helm' },
            { id = 12431, lvl = 30, jobs =    6593, name = 'Ryl. Squires Helm' },
            { id = 13904, lvl = 34, jobs = 3662710, name = 'Fed. Headgear' },
            { id = 16094, lvl = 25, jobs =  137218, name = 'T.Kazu Jinpachi' },
            { id = 12470, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Headgear' },
            { id = 13830, lvl = 30, jobs = 4179646, name = 'Lgn. Circlet' },
            { id = 13896, lvl = 15, jobs = 2473969, name = 'Kingdom Bandana' },
            { id = 12484, lvl = 20, jobs =    6146, name = 'Mrc. Hachimaki' },
            { id = 13895, lvl = 15, jobs = 2473969, name = 'San. Bandana' },
            { id = 16093, lvl = 15, jobs =  137218, name = 'H.Kazu Hachimaki' },
            { id = 12510, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Bandana' },
            { id = 15186, lvl = 20, jobs = 4194303, name = 'Trump Crown' },
            { id = 12487, lvl = 10, jobs = 2141649, name = 'Faceguard +1' },
            { id = 12432, lvl = 10, jobs = 2141649, name = 'Faceguard' },
            { id = 12509, lvl = 10, jobs = 2472947, name = 'Legionnaires Cap' },
            { id = 16144, lvl = 10, jobs = 4194303, name = 'Sol Cap' },
            { id = 11811, lvl =  1, jobs = 4194303, name = 'Destrier Beret' },
            { id = 12463, lvl =  1, jobs = 2472947, name = 'Bronze Cap +1' },
            { id = 10385, lvl =  1, jobs = 4194303, name = 'Cumulus Masque +1' },
            { id = 12448, lvl =  1, jobs = 2472947, name = 'Bronze Cap' },
        },
        BODY =
        {
            { id = 23458, lvl = 99, jobs =   65536, name = 'Laksa. Frac +3' },
            { id = 23762, lvl = 99, jobs =   66560, name = 'Ikengas Vest' },
            { id = 25789, lvl = 99, jobs =   66560, name = 'Nisroch Jerkin' },
            { id = 23168, lvl = 99, jobs =   65536, name = 'Chasseurs Frac +2' },
            { id = 23715, lvl = 99, jobs = 2605043, name = 'Volte Harness' },
            { id = 23768, lvl = 99, jobs = 4194303, name = 'Nyame Mail' },
            { id = 14550, lvl = 75, jobs =   66848, name = 'Skadis Cuirie' },
            { id = 14439, lvl = 70, jobs =    2048, name = 'Hmn. Domaru +1' },
            { id = 14512, lvl = 75, jobs =    4096, name = 'Kog. Chainmail +1' },
            { id = 11294, lvl = 74, jobs =   65536, name = 'Corsairs Frac +1' },
            { id = 14404, lvl = 50, jobs =    2048, name = 'Shm. Hara-Ate' },
            { id = 14540, lvl = 70, jobs =    3072, name = 'Kyudogi +1' },
            { id = 14437, lvl = 70, jobs =    2048, name = 'Hachiman Domaru' },
            { id = 12562, lvl = 75, jobs =    7939, name = 'Kirins Osode' },
            { id = 14568, lvl = 75, jobs =   10689, name = 'Askar Korazin' },
            { id = 14528, lvl = 59, jobs =    2497, name = 'Abtal Jawshan' },
            { id = 14590, lvl = 68, jobs = 2589730, name = 'Cobra Harness' },
            { id = 14524, lvl = 59, jobs =    2497, name = 'Sipahi Jawshan' },
            { id = 12648, lvl = 58, jobs =    1024, name = 'Hunters Jerkin' },
            { id = 14529, lvl = 55, jobs = 2473969, name = 'Akinji Peti' },
            { id = 13755, lvl = 59, jobs = 3069758, name = 'Flora Cotehardie' },
            { id = 14562, lvl = 75, jobs =   32792, name = 'Morrigans Robe' },
            { id = 14357, lvl = 43, jobs = 3662710, name = 'Irn.Msk.Gmbsn. +2' },
            { id = 14356, lvl = 43, jobs = 3662710, name = 'Irn.Msk.Gmbsn. +1' },
            { id = 13721, lvl = 40, jobs = 3662710, name = 'Irn.Msk. Gambison' },
            { id = 14572, lvl = 65, jobs = 3662710, name = 'Tabin Jupon +1' },
            { id = 14434, lvl = 30, jobs =   66592, name = 'Noct Doublet +1' },
            { id = 14570, lvl = 75, jobs = 1720860, name = 'Goliard Saio' },
            { id = 14435, lvl = 29, jobs =      65, name = 'Kampfbrust' },
            { id = 13710, lvl = 45, jobs = 2473969, name = 'Brigandine +1' },
            { id = 14557, lvl = 35, jobs =  137218, name = 'Hikazu Hara-Ate' },
            { id = 14422, lvl = 30, jobs =   66592, name = 'Noct Doublet' },
            { id = 11349, lvl = 57, jobs = 1720332, name = 'Vivacity Coat +1' },
            { id = 14431, lvl = 29, jobs =      65, name = 'Eisenbrust' },
            { id = 12606, lvl = 50, jobs = 4179646, name = 'Tct.Mgc. Coat' },
            { id = 14549, lvl = 35, jobs =    8385, name = 'Deimoss Cuirass' },
            { id = 12598, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Doublet' },
            { id = 14565, lvl = 35, jobs =   32792, name = 'Machas Coat' },
            { id = 13719, lvl = 40, jobs = 4179646, name = 'Ryl.Sqr. Robe' },
            { id = 14548, lvl = 25, jobs =    8385, name = 'Phoboss Cuirass' },
            { id = 14564, lvl = 25, jobs =   32792, name = 'Bodbs Robe' },
            { id = 12566, lvl = 30, jobs = 2141649, name = 'Ctr. Scale Mail' },
            { id = 13707, lvl = 30, jobs = 2473969, name = 'Strong Vest' },
            { id = 14551, lvl = 15, jobs =   66848, name = 'Njords Jerkin' },
            { id = 14427, lvl = 29, jobs = 1720332, name = 'Seers Tunic +1' },
            { id = 14464, lvl = 16, jobs =    1024, name = 'Trailers Tunica' },
            { id = 14563, lvl = 15, jobs =   32792, name = 'Nemains Robe' },
            { id = 12590, lvl = 13, jobs =    6146, name = 'Power Gi' },
            { id = 13818, lvl = 18, jobs = 4194303, name = 'Garrison Tunica' },
            { id = 12661, lvl = 10, jobs = 2141649, name = 'Solid Mail' },
            { id = 12560, lvl = 10, jobs = 2141649, name = 'Scale Mail' },
            { id = 12629, lvl = 10, jobs = 2472947, name = 'Lgn. Harness' },
            { id = 12630, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Vest' },
            { id = 12607, lvl =  1, jobs = 2472947, name = 'Bronze Harness +1' },
            { id = 11330, lvl =  1, jobs = 4194303, name = 'Blksmith. Smock' },
            { id = 12576, lvl =  1, jobs = 2472947, name = 'Bronze Harness' },
            { id = 12615, lvl =  1, jobs = 4179646, name = 'Robe +1' },
        },
        HANDS =
        {
            { id = 23229, lvl = 99, jobs =    1024, name = 'Amini Glovelettes +2' },
            { id = 23213, lvl = 99, jobs =   65536, name = 'Lanun Gants +2' },
            { id = 23769, lvl = 99, jobs =   66560, name = 'Ikengas Gloves' },
            { id = 23235, lvl = 99, jobs =   65536, name = 'Chasseurs Gants +2' },
            { id = 23719, lvl = 99, jobs = 2605043, name = 'Volte Mittens' },
            { id = 23775, lvl = 99, jobs = 4194303, name = 'Nyame Gauntlets' },
            { id = 14902, lvl = 74, jobs =    4096, name = 'Nin. Tekko +1' },
            { id = 12690, lvl = 75, jobs =    7939, name = 'Seiryus Kote' },
            { id = 14878, lvl = 70, jobs =    2048, name = 'Hachiman Kote +1' },
            { id = 14059, lvl = 73, jobs = 2204880, name = 'Blood Fng. Gnt.' },
            { id = 14876, lvl = 70, jobs =    2048, name = 'Hachiman Kote' },
            { id = 13973, lvl = 60, jobs =    4096, name = 'Ninja Tekko' },
            { id = 14965, lvl = 75, jobs =   66848, name = 'Skadis Bazubands' },
            { id = 14940, lvl = 72, jobs = 2569522, name = 'Pln. Dastanas' },
            { id = 14959, lvl = 70, jobs = 2141649, name = 'Mrc. Dastanas' },
            { id = 15011, lvl = 68, jobs = 2589730, name = 'Cobra Mittens' },
            { id = 14944, lvl = 60, jobs = 2473969, name = 'Deadeye Gloves' },
            { id = 14938, lvl = 59, jobs =    2497, name = 'Abtal Dastanas' },
            { id = 27939, lvl = 45, jobs = 2426144, name = 'Idis Gloves' },
            { id = 14892, lvl = 74, jobs =       4, name = 'Hlr. Mitts +1' },
            { id = 14036, lvl = 43, jobs =     193, name = 'Irn.Msk. Gnt. +2' },
            { id = 14035, lvl = 43, jobs =     193, name = 'Irn.Msk. Gnt. +1' },
            { id = 12678, lvl = 40, jobs =     193, name = 'Irn.Msk. Gauntlets' },
            { id = 27940, lvl = 45, jobs =  137218, name = 'Genta Gote' },
            { id = 13963, lvl = 60, jobs =       4, name = 'Healers Mitts' },
            { id = 14999, lvl = 70, jobs = 1573000, name = 'Vampiric Mitts' },
            { id = 27941, lvl = 45, jobs =   16900, name = 'Namrus Dastanas' },
            { id = 13977, lvl = 57, jobs = 1753628, name = 'Light Gauntlets' },
            { id = 14044, lvl = 25, jobs =    6146, name = 'Federation Tekko' },
            { id = 14007, lvl = 73, jobs = 1065500, name = 'Zenith Mitts +1' },
            { id = 12793, lvl = 38, jobs = 4179646, name = 'Mages Cuffs' },
            { id = 14865, lvl = 30, jobs =   66592, name = 'Noct Gloves +1' },
            { id = 27938, lvl = 45, jobs =    8385, name = 'Ates Gauntlets' },
            { id = 14968, lvl = 35, jobs =   66848, name = 'Freyas Gloves' },
            { id = 14043, lvl = 25, jobs =    6146, name = 'Windurstian Tekko' },
            { id = 14046, lvl = 34, jobs = 3662710, name = 'Federation Gloves' },
            { id = 14854, lvl = 30, jobs =   66592, name = 'Noct Gloves' },
            { id = 12726, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Gloves' },
            { id = 12782, lvl = 28, jobs = 4179646, name = 'Wool Cuffs +1' },
            { id = 14963, lvl = 25, jobs =    8385, name = 'Phoboss Gnt.' },
            { id = 14966, lvl = 15, jobs =   66848, name = 'Njords Gloves' },
            { id = 14962, lvl = 15, jobs =    8385, name = 'Enyos Gauntlets' },
            { id = 12778, lvl = 12, jobs = 4179646, name = 'Linen Cuffs +1' },
            { id = 14054, lvl = 20, jobs = 4179646, name = 'Barons Cuffs' },
            { id = 12719, lvl = 20, jobs =    6146, name = 'Mrc. Tekko' },
            { id = 12768, lvl = 10, jobs = 2141649, name = 'Solid Fng. Gnt.' },
            { id = 12797, lvl =  9, jobs =     193, name = 'Coarse Gauntlets' },
            { id = 12688, lvl = 10, jobs = 2141649, name = 'Scale Fng. Gnt.' },
            { id = 12752, lvl = 10, jobs = 2472947, name = 'Lgn. Mittens' },
            { id = 12775, lvl =  8, jobs = 3851870, name = 'Mitts +1' },
            { id = 14831, lvl =  1, jobs = 4194303, name = 'Smithys Mitts' },
            { id = 12695, lvl =  1, jobs = 2472947, name = 'Bronze Mittens +1' },
            { id = 12744, lvl =  1, jobs = 4179646, name = 'Cuffs +1' },
            { id = 12704, lvl =  1, jobs = 2472947, name = 'Bronze Mittens' },
        },
        LEGS =
        {
            { id = 23296, lvl = 99, jobs =    1024, name = 'Amini Bragues +2' },
            { id = 23302, lvl = 99, jobs =   65536, name = 'Chasseurs Culottes +2' },
            { id = 23776, lvl = 99, jobs =   66560, name = 'Ikengas Trousers' },
            { id = 23280, lvl = 99, jobs =   65536, name = 'Lanun Trews +2' },
            { id = 23723, lvl = 99, jobs = 2605043, name = 'Volte Tights' },
            { id = 23782, lvl = 99, jobs = 4194303, name = 'Nyame Flanchard' },
            { id = 15629, lvl = 75, jobs =   66848, name = 'Skadis Chausses' },
            { id = 16343, lvl = 72, jobs = 2595874, name = 'Enkidus Subligar' },
            { id = 14307, lvl = 72, jobs = 2473969, name = 'Dusk Trousers +1' },
            { id = 15572, lvl = 74, jobs =    2048, name = 'Myn. Haidate +1' },
            { id = 14334, lvl = 50, jobs =    2048, name = 'Shm. Haidate' },
            { id = 14226, lvl = 52, jobs =    4096, name = 'Ninja Hakama' },
            { id = 15387, lvl = 70, jobs =     385, name = 'Trackers Kecks' },
            { id = 15394, lvl = 70, jobs =    2048, name = 'Hmn. Hakama +1' },
            { id = 15392, lvl = 70, jobs =    2048, name = 'Hachiman Hakama' },
            { id = 16317, lvl = 68, jobs = 2589730, name = 'Cobra Subligar' },
            { id = 15608, lvl = 55, jobs = 2473969, name = 'Akinji Salvars' },
            { id = 15607, lvl = 59, jobs =    2497, name = 'Abtal Zerehs' },
            { id = 28081, lvl = 45, jobs =    8385, name = 'Ates Flanchard' },
            { id = 15641, lvl = 75, jobs =   32792, name = 'Morrigans Slops' },
            { id = 15373, lvl = 47, jobs =      32, name = 'Bravos Subligar' },
            { id = 14335, lvl = 50, jobs =    4096, name = 'Nokizaru Hakama' },
            { id = 14260, lvl = 25, jobs = 2472947, name = 'Republic Subligar' },
            { id = 28083, lvl = 45, jobs =  137218, name = 'Genta-No-Hakama' },
            { id = 14237, lvl = 61, jobs = 3662710, name = 'Battle Hose +1' },
            { id = 28082, lvl = 45, jobs = 2426144, name = 'Idis Trousers' },
            { id = 15649, lvl = 75, jobs = 1720860, name = 'Goliard Trews' },
            { id = 15598, lvl = 70, jobs = 4194303, name = 'Hydra Hose' },
            { id = 14259, lvl = 25, jobs = 2472947, name = 'Bastokan Subligar' },
            { id = 14333, lvl = 30, jobs =   66592, name = 'Noct Brais +1' },
            { id = 14268, lvl = 34, jobs = 2141649, name = 'Republic Cuisses' },
            { id = 14216, lvl = 56, jobs =       4, name = 'Healers Pantaln.' },
            { id = 14217, lvl = 56, jobs =       8, name = 'Wizards Tonban' },
            { id = 14332, lvl = 29, jobs =      65, name = 'Kampfdiechlings' },
            { id = 16314, lvl = 55, jobs = 4179646, name = 'Cobra Slops' },
            { id = 14246, lvl = 50, jobs = 2141649, name = 'Steel Cuisses +1' },
            { id = 15384, lvl = 50, jobs =   16388, name = 'Capri. Subligar' },
            { id = 15375, lvl = 50, jobs = 1064968, name = 'Aries Subligar' },
            { id = 15381, lvl = 50, jobs = 2261520, name = 'Libra Subligar' },
            { id = 15382, lvl = 50, jobs =  524304, name = 'Scorpius Subligar' },
            { id = 12922, lvl = 24, jobs = 3851870, name = 'Martial Slacks' },
            { id = 12870, lvl = 40, jobs = 3851870, name = 'Cmb.Cst. Slacks' },
            { id = 15630, lvl = 15, jobs =   66848, name = 'Njords Trousers' },
            { id = 16367, lvl = 15, jobs = 2473969, name = 'Phl. Trousers' },
            { id = 15634, lvl = 15, jobs =  137218, name = 'Hoshikazu Hakama' },
            { id = 12882, lvl = 20, jobs = 2473969, name = 'Ryl.Ftm. Trousers' },
            { id = 12917, lvl = 20, jobs = 3851870, name = 'Mages Slacks' },
            { id = 12863, lvl = 10, jobs = 2141649, name = 'Solid Cuisses' },
            { id = 12816, lvl = 10, jobs = 2141649, name = 'Scale Cuisses' },
            { id = 12915, lvl = 10, jobs = 4179646, name = 'Freeswords Slops' },
            { id = 12898, lvl =  8, jobs = 3851870, name = 'Slacks +1' },
            { id = 12899, lvl =  8, jobs =    6146, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, jobs = 2472947, name = 'Brz. Subligar +1' },
            { id = 12832, lvl =  1, jobs = 2472947, name = 'Bronze Subligar' },
            { id = 12897, lvl =  1, jobs = 4179646, name = 'Slops +1' },
            { id = 12856, lvl =  1, jobs = 4179646, name = 'Slops' },
        },
        FEET =
        {
            { id = 23676, lvl = 99, jobs =    1024, name = 'Arcadian Socks +3' },
            { id = 23783, lvl = 99, jobs =   66560, name = 'Ikengas Clogs' },
            { id = 23341, lvl = 99, jobs =    1024, name = 'Arcadian Socks +2' },
            { id = 23363, lvl = 99, jobs =    1024, name = 'Amini Bottillons +2' },
            { id = 23727, lvl = 99, jobs = 2605043, name = 'Volte Spats' },
            { id = 23789, lvl = 99, jobs = 4194303, name = 'Nyame Sollerets' },
            { id = 15719, lvl = 75, jobs =  137218, name = 'Usukane Sune-Ate' },
            { id = 15332, lvl = 70, jobs =    2048, name = 'Hmn. Sune-Ate +1' },
            { id = 15330, lvl = 70, jobs =    2048, name = 'Hmn. Sune-Ate' },
            { id = 11384, lvl = 74, jobs =   65536, name = 'Cor. Bottes +1' },
            { id = 11364, lvl = 75, jobs =    7171, name = 'Hachiryu Sune-Ate' },
            { id = 15757, lvl = 68, jobs = 2589730, name = 'Cobra Leggings' },
            { id = 14113, lvl = 70, jobs =   66592, name = 'War Boots +1' },
            { id = 28272, lvl = 75, jobs = 2473969, name = 'Adsilio Boots +1' },
            { id = 15354, lvl = 74, jobs =       4, name = 'Hlr. Duckbills +1' },
            { id = 15355, lvl = 74, jobs =       8, name = 'Wzd. Sabots +1' },
            { id = 15744, lvl = 70, jobs = 2473969, name = 'Bowmans Led.' },
            { id = 15685, lvl = 56, jobs =   65536, name = 'Corsairs Bottes' },
            { id = 14144, lvl = 43, jobs =     193, name = 'Irn.Msk. Sbtn. +2' },
            { id = 14143, lvl = 43, jobs =     193, name = 'Irn.Msk. Sbtn. +1' },
            { id = 12934, lvl = 40, jobs =     193, name = 'Irn.Msk. Sabatons' },
            { id = 14103, lvl = 56, jobs =   16384, name = 'Evokers Pigaches' },
            { id = 14099, lvl = 60, jobs =    1024, name = 'Hunters Socks' },
            { id = 14101, lvl = 54, jobs =    4096, name = 'Ninja Kyahan' },
            { id = 14114, lvl = 67, jobs =       4, name = 'Aristo. Pumps' },
            { id = 15694, lvl = 55, jobs = 2473969, name = 'Akinji Nails' },
            { id = 14167, lvl = 62, jobs = 4194303, name = 'Desert Boots +1' },
            { id = 14152, lvl = 25, jobs =    6146, name = 'Fed. Kyahan' },
            { id = 12942, lvl = 50, jobs =    6593, name = 'Ryl.Kgt. Sollerets' },
            { id = 15722, lvl = 35, jobs =  137218, name = 'Hikazu Sune-Ate' },
            { id = 14151, lvl = 25, jobs =    6146, name = 'Win. Kyahan' },
            { id = 14133, lvl = 24, jobs = 2473969, name = 'Winged Boots +1' },
            { id = 15691, lvl = 50, jobs = 4194303, name = 'Storm Gambieras' },
            { id = 14132, lvl = 24, jobs = 2473969, name = 'Winged Boots' },
            { id = 10648, lvl = 20, jobs =    1056, name = 'Areion Boots +1' },
            { id = 13014, lvl =  7, jobs = 2473969, name = 'Leaping Boots' },
            { id = 15351, lvl =  7, jobs = 2473969, name = 'Bounding Boots' },
            { id = 10647, lvl = 20, jobs =    1056, name = 'Areion Boots' },
            { id = 14154, lvl = 34, jobs = 3662710, name = 'Federation Gaiters' },
            { id = 15348, lvl = 38, jobs = 4194303, name = 'Mountain Gaiters' },
            { id = 12982, lvl = 30, jobs = 3662710, name = 'Mrc.Cpt. Gaiters' },
            { id = 14150, lvl = 25, jobs = 4179646, name = 'Kingdom Clogs' },
            { id = 13045, lvl = 20, jobs = 4179646, name = 'Ryl.Ftm. Clogs' },
            { id = 13024, lvl = 10, jobs = 2141649, name = 'Solid Greaves' },
            { id = 12944, lvl = 10, jobs = 2141649, name = 'Scale Greaves' },
            { id = 13003, lvl = 10, jobs = 2472947, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, jobs = 3851870, name = 'Solea +1' },
            { id = 12951, lvl =  1, jobs = 2472947, name = 'Brz. Leggings +1' },
            { id = 12983, lvl =  1, jobs = 4179646, name = 'Ash Clogs +1' },
            { id = 11400, lvl =  1, jobs = 4194303, name = 'Noble Poulaines' },
            { id = 11403, lvl =  1, jobs = 4194303, name = 'Talaria' },
        },
        NECK =
        {
            { id = 26027, lvl = 99, jobs =   70688, name = 'Iskur Gorget' },
            { id = 25491, lvl = 99, jobs =    4096, name = 'Ninja Nodowa +2' },
            { id = 25479, lvl = 99, jobs =    1024, name = 'Scouts Gorget +2' },
            { id = 25515, lvl = 99, jobs =   65536, name = 'Comm. Charm +2' },
            { id = 28400, lvl = 99, jobs = 2473969, name = 'Ocachi Gorget' },
            { id = 25415, lvl = 99, jobs = 4194303, name = 'Rep. Plat. Medal' },
            { id = 28349, lvl = 75, jobs = 4194303, name = 'Crested Torque' },
            { id = 15531, lvl = 74, jobs = 2473969, name = 'Qiqirn Collar' },
            { id = 16299, lvl = 69, jobs = 4194303, name = 'Lleus Charm' },
            { id = 15517, lvl = 69, jobs = 4194303, name = 'Snipers Collar' },
            { id = 13165, lvl = 40, jobs =    5680, name = 'Jagd Gorget' },
            { id = 13056, lvl = 33, jobs = 4194303, name = 'Peacock Charm' },
            { id = 15515, lvl = 33, jobs = 4194303, name = 'Peacock Amulet' },
            { id = 15516, lvl = 70, jobs = 4194303, name = 'Diaboloss Torque' },
            { id = 13128, lvl = 59, jobs = 2465590, name = 'Spectacles' },
            { id = 13117, lvl = 14, jobs =    1024, name = 'Rangers Necklace' },
            { id = 13123, lvl = 56, jobs = 2141649, name = 'Mermans Gorget' },
            { id = 15523, lvl = 60, jobs = 4194303, name = 'Chivalrous Chain' },
            { id = 16294, lvl = 60, jobs = 4194303, name = 'Crocodile Collar' },
            { id = 16280, lvl = 40, jobs = 4194303, name = 'Haraldrs Muffler' },
            { id = 13164, lvl = 40, jobs = 3662710, name = 'Agile Gorget' },
            { id = 13107, lvl = 50, jobs =    6593, name = 'R.K. Army Collar' },
            { id = 13061, lvl = 21, jobs = 4194303, name = 'Spike Necklace' },
            { id = 13060, lvl =  7, jobs = 4179646, name = 'Feather Collar +1' },
            { id = 13076, lvl = 21, jobs = 4194303, name = 'Fang Necklace' },
            { id = 13070, lvl = 30, jobs = 2473969, name = 'Wolf Gorget +1' },
            { id = 15504, lvl = 30, jobs = 2141649, name = 'Ajase Beads' },
            { id = 13112, lvl =  7, jobs =      32, name = 'Rabbit Charm' },
            { id = 13183, lvl =  7, jobs = 4194303, name = 'Wing Pendant' },
            { id = 16296, lvl =  9, jobs = 2141649, name = 'Armigers Lace' },
            { id = 13078, lvl =  1, jobs = 4194303, name = 'Portafurnace' },
            { id = 13121, lvl =  1, jobs = 4194303, name = 'Beast Collar' },
            { id = 13122, lvl =  1, jobs = 4194303, name = 'Miners Pendant' },
            { id = 16273, lvl =  1, jobs = 4194303, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 28411, lvl = 99, jobs = 2465590, name = 'Yemaya Belt' },
            { id = 26338, lvl = 99, jobs =   66560, name = 'K. Kachina Belt +1' },
            { id = 28415, lvl = 99, jobs = 4194303, name = 'Eschan Stone' },
            { id = 28441, lvl = 99, jobs =   66560, name = 'Ponente Sash' },
            { id = 15876, lvl = 70, jobs =    1024, name = 'Scouts Belt' },
            { id = 15920, lvl = 70, jobs =   65536, name = 'Commodore Belt' },
            { id = 15911, lvl = 75, jobs = 4194303, name = 'Buccaneers Belt' },
            { id = 15879, lvl = 70, jobs =    2048, name = 'Sao. Koshi-Ate' },
            { id = 15886, lvl = 60, jobs = 4194303, name = 'Precise Belt' },
            { id = 15945, lvl = 50, jobs = 4194303, name = 'Volant Belt' },
            { id = 15888, lvl = 60, jobs = 4194303, name = 'Hurling Belt' },
            { id = 13278, lvl = 52, jobs = 2473969, name = 'R.K. Belt +2' },
            { id = 13220, lvl = 50, jobs = 2473969, name = 'Ryl.Kgt. Belt' },
            { id = 15882, lvl = 50, jobs = 2473969, name = 'Storm Belt' },
            { id = 13202, lvl = 40, jobs =       2, name = 'Brown Belt' },
            { id = 13201, lvl = 18, jobs =       2, name = 'Purple Belt' },
            { id = 13221, lvl = 30, jobs = 4179646, name = 'Mrc.Cpt. Belt' },
            { id = 13214, lvl = 40, jobs =     193, name = 'Waistbelt +1' },
            { id = 15908, lvl = 40, jobs = 3851870, name = 'Qiqirn Sash +1' },
            { id = 15286, lvl = 40, jobs = 4194303, name = 'Tilt Belt' },
            { id = 15927, lvl = 30, jobs = 2166961, name = 'Pinwheel Belt' },
            { id = 15271, lvl = 30, jobs = 4194303, name = 'Axe Belt' },
            { id = 15926, lvl =  5, jobs =   70688, name = 'Bronze Bandolier' },
            { id = 13225, lvl = 18, jobs = 2141649, name = 'Brave Belt' },
            { id = 13224, lvl = 20, jobs = 3851870, name = 'Silver Obi +1' },
            { id = 13219, lvl = 18, jobs = 4179646, name = 'Magic Belt +1' },
            { id = 13184, lvl =  1, jobs =       2, name = 'White Belt' },
            { id = 13190, lvl =  8, jobs = 3851870, name = 'Heko Obi +1' },
            { id = 13204, lvl =  8, jobs = 3851870, name = 'Heko Obi' },
            { id = 13210, lvl =  7, jobs = 2473969, name = 'Leather Belt +1' },
            { id = 15456, lvl =  1, jobs = 4194303, name = 'Dash Sash' },
            { id = 10847, lvl =  1, jobs = 4194303, name = 'Orc Belt' },
            { id = 10848, lvl =  1, jobs = 4194303, name = 'Quadav Belt' },
        },
        BACK =
        {
            { id = 28627, lvl = 99, jobs =    1024, name = 'Lutian Cape' },
            { id = 28595, lvl = 99, jobs = 2473971, name = 'Moondoe Mantle +1' },
            { id = 16209, lvl = 84, jobs =   65536, name = 'Navarchs Mantle' },
            { id = 11006, lvl = 99, jobs = 2473971, name = 'Thall Mantle' },
            { id = 11541, lvl = 73, jobs = 2473971, name = 'Fowlers Mantle +1' },
            { id = 28612, lvl = 99, jobs = 4194303, name = 'Buquwik Cape' },
            { id = 16250, lvl = 72, jobs =   70688, name = 'Mamool Ja Mantle' },
            { id = 13646, lvl = 61, jobs = 2473971, name = 'Amemet Mantle +1' },
            { id = 11535, lvl = 73, jobs = 2473971, name = 'Fowlers Mantle' },
            { id = 13694, lvl = 69, jobs = 2473971, name = 'Psilos Mantle' },
            { id = 15491, lvl = 60, jobs = 2473971, name = 'Bullseye Cape' },
            { id = 13645, lvl = 61, jobs = 2473971, name = 'Amemet Mantle' },
            { id = 11545, lvl = 60, jobs = 4194303, name = 'Fourth Mantle' },
            { id = 16237, lvl = 50, jobs = 2473971, name = 'Thunderers Mantle' },
            { id = 15493, lvl = 60, jobs = 2473971, name = 'Bushido Cape' },
            { id = 13678, lvl = 50, jobs =    7201, name = 'Snipers Mantle' },
            { id = 13674, lvl = 40, jobs =    7201, name = 'Agile Mantle' },
            { id = 13632, lvl = 24, jobs = 2473971, name = 'Nomads Mantle +1' },
            { id = 13676, lvl = 50, jobs =    8641, name = 'Heavy Mantle' },
            { id = 15483, lvl = 50, jobs = 4194303, name = 'Storm Mantle' },
            { id = 13675, lvl = 40, jobs = 1589788, name = 'Rearguard Mantle' },
            { id = 15468, lvl = 40, jobs = 2473971, name = 'Resentment Cape' },
            { id = 13623, lvl = 40, jobs =    8641, name = 'Earth Mantle' },
            { id = 13625, lvl = 39, jobs = 1758748, name = 'Tundra Mantle' },
            { id = 13631, lvl = 24, jobs = 2473971, name = 'Nomads Mantle' },
            { id = 13644, lvl = 30, jobs = 1753628, name = 'Midnight Cape' },
            { id = 13643, lvl = 30, jobs = 1753628, name = 'Sarcenet Cape' },
            { id = 13680, lvl = 20, jobs = 2473971, name = 'Variable Mantle' },
            { id = 13681, lvl = 20, jobs = 1753628, name = 'Variable Cape' },
            { id = 13600, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle +1' },
            { id = 13588, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle' },
            { id = 13607, lvl = 10, jobs = 1753628, name = 'Mist Silk Cape' },
            { id = 13605, lvl =  7, jobs = 1753628, name = 'Cape +1' },
            { id = 13583, lvl =  7, jobs = 1753628, name = 'Cape' },
            { id = 13599, lvl =  4, jobs = 2473971, name = 'Rabbit Mantle +1' },
            { id = 11009, lvl =  1, jobs = 4194303, name = 'Shapers Shawl' },
            { id = 16243, lvl =  1, jobs = 4194303, name = 'Drovers Mantle' },
            { id = 11002, lvl =  1, jobs = 4194303, name = 'Dragon Tank' },
            { id = 13682, lvl =  1, jobs = 4194303, name = 'Ether Tank' },
        },
        EAR =
        {
            { id = 28479, lvl = 99, jobs = 4194303, name = 'Enervating Earring' },
            { id = 28493, lvl = 99, jobs = 4194303, name = 'Neritic Earring' },
            { id = 26084, lvl = 99, jobs = 2368818, name = 'Sherida Earring' },
            { id = 26107, lvl = 99, jobs =   10689, name = 'Thrud Earring' },
            { id = 15964, lvl = 72, jobs = 4194303, name = 'Hollow Earring' },
            { id = 14813, lvl = 75, jobs = 4194303, name = 'Brutal Earring' },
            { id = 15988, lvl = 75, jobs = 4194303, name = 'Beta Earring' },
            { id = 14762, lvl = 70, jobs =    6593, name = 'Attilas Earring' },
            { id = 16010, lvl = 61, jobs = 4194303, name = 'Pennon Earring +1' },
            { id = 14712, lvl = 67, jobs = 4194303, name = 'Nimble Earring +1' },
            { id = 13407, lvl = 67, jobs = 4194303, name = 'Nimble Earring' },
            { id = 15966, lvl = 60, jobs = 4194303, name = 'Silver Fox Earring' },
            { id = 15973, lvl = 50, jobs = 4194303, name = 'Vision Earring' },
            { id = 13361, lvl = 35, jobs = 4194303, name = 'Drone Earring' },
            { id = 16035, lvl = 60, jobs = 4194303, name = 'Altdorfs Earring' },
            { id = 16036, lvl = 60, jobs = 4194303, name = 'Wilhelms Earring' },
            { id = 13322, lvl = 35, jobs = 4194303, name = 'Wing Earring' },
            { id = 14804, lvl = 49, jobs = 4194303, name = 'Harvest Earring' },
            { id = 14806, lvl = 40, jobs = 4194303, name = 'Intruder Earring' },
            { id = 13405, lvl = 40, jobs = 1758748, name = 'Enhancing Earring' },
            { id = 11043, lvl = 30, jobs = 4194303, name = 'Giants Earring' },
            { id = 13435, lvl = 30, jobs = 4194303, name = 'Mercen. Earring' },
            { id = 13436, lvl = 30, jobs = 4194303, name = 'Wrestlers Earring' },
            { id = 13437, lvl = 30, jobs = 4194303, name = 'Healers Earring' },
            { id = 14757, lvl = 20, jobs = 4194303, name = 'Mecurial Earring' },
            { id = 13365, lvl = 20, jobs = 4194303, name = 'Shield Earring' },
            { id = 16039, lvl = 20, jobs = 4194303, name = 'Kingdom Earring' },
            { id = 16040, lvl = 20, jobs = 4194303, name = 'Republic Earring' },
            { id = 13402, lvl =  1, jobs = 4194303, name = 'Cassie Earring' },
            { id = 14688, lvl = 10, jobs = 4194303, name = 'Reflex Earring +1' },
            { id = 14689, lvl = 10, jobs = 4194303, name = 'Crg. Earring +1' },
            { id = 14690, lvl = 10, jobs = 4194303, name = 'Kldg. Earring +1' },
            { id = 28510, lvl =  1, jobs = 4194303, name = 'M. Slime Earring' },
            { id = 16003, lvl =  1, jobs = 4194303, name = 'Raising Earring' },
            { id = 28509, lvl =  1, jobs = 4194303, name = 'She-Slime Earring' },
        },
        RING =
        {
            { id = 26198, lvl = 99, jobs = 4194303, name = 'Haverton Ring +1' },
            { id = 27586, lvl = 99, jobs = 4194303, name = 'Haverton Ring' },
            { id = 26191, lvl = 99, jobs = 2571747, name = 'Regal Ring' },
            { id = 26187, lvl = 99, jobs =   70688, name = 'Dingir Ring' },
            { id = 15549, lvl = 75, jobs = 4194303, name = 'Bellonas Ring' },
            { id = 14627, lvl = 73, jobs = 4194303, name = 'Dragon Ring +1' },
            { id = 13556, lvl = 70, jobs = 4194303, name = 'Behemoth Ring +1' },
            { id = 13460, lvl = 70, jobs = 4194303, name = 'Behemoth Ring' },
            { id = 13504, lvl = 70, jobs = 4194303, name = 'Mermans Ring' },
            { id = 15789, lvl = 67, jobs = 4194303, name = 'Marid Ring +1' },
            { id = 15809, lvl = 50, jobs = 4194303, name = 'Jalzahns Ring' },
            { id = 15543, lvl = 30, jobs = 4194303, name = 'Rajas Ring' },
            { id = 13513, lvl = 55, jobs = 4194303, name = 'Scorpion Ring +1' },
            { id = 13458, lvl = 55, jobs = 4194303, name = 'Scorpion Ring' },
            { id = 13503, lvl = 45, jobs = 4194303, name = 'Carapace Ring +1' },
            { id = 13281, lvl = 40, jobs = 4194303, name = 'Snipers Ring +1' },
            { id = 13461, lvl = 45, jobs = 4194303, name = 'Carapace Ring' },
            { id = 14650, lvl = 40, jobs = 4194303, name = 'Marksmans Ring' },
            { id = 14675, lvl = 40, jobs = 4194303, name = 'Woodsman Ring' },
            { id = 14660, lvl = 29, jobs = 4194303, name = 'Bowyer Ring' },
            { id = 13501, lvl = 21, jobs = 4194303, name = 'Beetle Ring +1' },
            { id = 13457, lvl = 21, jobs = 4194303, name = 'Beetle Ring' },
            { id = 13500, lvl = 16, jobs = 4194303, name = 'Bone Ring +1' },
            { id = 13441, lvl = 16, jobs = 4194303, name = 'Bone Ring' },
            { id = 14592, lvl = 14, jobs = 4194303, name = 'Reflex Ring +1' },
            { id = 13521, lvl = 14, jobs = 4194303, name = 'Reflex Ring' },
            { id = 13496, lvl =  1, jobs = 4194303, name = 'Windurstian Ring' },
            { id = 13495, lvl =  1, jobs = 4194303, name = 'San Dorian Ring' },
            { id = 14670, lvl = 10, jobs = 4194303, name = 'Safeguard Ring' },
            { id = 13282, lvl = 10, jobs = 4194303, name = 'Saintly Ring' },
            { id = 10796, lvl =  1, jobs = 4194303, name = 'Decennial Ring' },
            { id = 11666, lvl =  1, jobs = 4194303, name = 'Novennial Ring' },
        },
    },
    caster =
    {
        HEAD =
        {
            { id = 27731, lvl = 99, jobs =  524820, name = 'Gende. Caubeen +1' },
            { id = 27771, lvl = 99, jobs =  524820, name = 'Gende. Caubeen' },
            { id = 23089, lvl = 99, jobs =      16, name = 'Lethargy Chappel +2' },
            { id = 23104, lvl = 99, jobs =  524288, name = 'Arbatel Bonnet +2' },
            { id = 23761, lvl = 99, jobs = 4194303, name = 'Nyame Helm' },
            { id = 15229, lvl = 74, jobs =      16, name = 'Wlk. Chapeau +1' },
            { id = 12513, lvl = 60, jobs =      16, name = 'Warlocks Chapeau' },
            { id = 16100, lvl = 75, jobs =   32792, name = 'Morrigans Coron.' },
            { id = 15233, lvl = 74, jobs =     256, name = 'Bst. Helm +1' },
            { id = 16160, lvl = 71, jobs = 4194303, name = 'Rees Headgear' },
            { id = 15265, lvl = 60, jobs =   32768, name = 'Magus Keffiyeh' },
            { id = 13856, lvl = 60, jobs =       8, name = 'Wizards Petasos' },
            { id = 16140, lvl = 60, jobs =  524288, name = 'Scholars M.Board' },
            { id = 16129, lvl = 68, jobs = 4194303, name = 'Wivre Hairpin +1' },
            { id = 13855, lvl = 54, jobs =       4, name = 'Healers Cap' },
            { id = 13868, lvl = 60, jobs =    2048, name = 'Myochin Kabuto' },
            { id = 12512, lvl = 56, jobs =       2, name = 'Temple Crown' },
            { id = 15221, lvl = 60, jobs = 2106337, name = 'Patrocluss Helm' },
            { id = 27662, lvl = 45, jobs = 1605656, name = 'Neits Crown' },
            { id = 11498, lvl = 59, jobs = 2472947, name = 'Zeal Cap +1' },
            { id = 16080, lvl = 53, jobs = 4179646, name = 'Magi Hat' },
            { id = 16066, lvl = 50, jobs = 4194303, name = 'Storm Turban' },
            { id = 16065, lvl = 50, jobs = 4194303, name = 'Storm Zucchetto' },
            { id = 15149, lvl = 50, jobs = 4194303, name = 'Rival Ribbon' },
            { id = 11494, lvl = 30, jobs = 4179646, name = 'Circes Hat' },
            { id = 15166, lvl = 29, jobs = 1720332, name = 'Seers Crown +1' },
            { id = 16103, lvl = 35, jobs =   32792, name = 'Machas Crown' },
            { id = 15163, lvl = 29, jobs = 1720332, name = 'Seers Crown' },
            { id = 15208, lvl = 20, jobs = 4179646, name = 'Barons Chapeau' },
            { id = 12422, lvl = 40, jobs =     193, name = 'Irn.Msk. Armet' },
            { id = 12481, lvl = 38, jobs = 2473969, name = 'Cuir Bandana +1' },
            { id = 13890, lvl = 15, jobs = 2472947, name = 'Republic Cap' },
            { id = 13889, lvl = 15, jobs = 2472947, name = 'Bastokan Cap' },
            { id = 15147, lvl = 19, jobs = 4194303, name = 'Garrison Sallet' },
            { id = 12509, lvl = 10, jobs = 2472947, name = 'Legionnaires Cap' },
            { id = 12500, lvl =  6, jobs = 4179646, name = 'Travelers Hat' },
            { id = 12526, lvl =  1, jobs = 4194303, name = 'Copper Hairpin +1' },
            { id = 13825, lvl =  5, jobs = 4194303, name = 'Bone Hairpin +1' },
            { id = 12496, lvl =  1, jobs = 4194303, name = 'Copper Hairpin' },
            { id = 11811, lvl =  1, jobs = 4194303, name = 'Destrier Beret' },
            { id = 12463, lvl =  1, jobs = 2472947, name = 'Bronze Cap +1' },
        },
        BODY =
        {
            { id = 23155, lvl = 99, jobs =       8, name = 'Wicce Coat +2' },
            { id = 23172, lvl = 99, jobs = 1048576, name = 'Azimuth Coat +2' },
            { id = 23171, lvl = 99, jobs =  524288, name = 'Arbatel Gown +2' },
            { id = 23156, lvl = 99, jobs =      16, name = 'Lethargy Sayon +2' },
            { id = 23768, lvl = 99, jobs = 4194303, name = 'Nyame Mail' },
            { id = 13774, lvl = 68, jobs =       4, name = 'Aristocrats Coat' },
            { id = 14368, lvl = 73, jobs = 2204880, name = 'Blood Scale Mail' },
            { id = 14562, lvl = 75, jobs =   32792, name = 'Morrigans Robe' },
            { id = 14558, lvl = 75, jobs =   16900, name = 'Marduks Jubbah' },
            { id = 12605, lvl = 68, jobs =       4, name = 'Nobles Tunic' },
            { id = 12562, lvl = 75, jobs =    7939, name = 'Kirins Osode' },
            { id = 14381, lvl = 72, jobs = 3850780, name = 'Mahatma Hpl.' },
            { id = 14591, lvl = 68, jobs = 3850780, name = 'Cobra Robe' },
            { id = 11286, lvl = 71, jobs =  397154, name = 'Avalon Breastplate' },
            { id = 14403, lvl = 50, jobs =  262176, name = 'Rapparee Harness' },
            { id = 14438, lvl = 70, jobs =       4, name = 'Blessed Bliaut +1' },
            { id = 13745, lvl = 58, jobs = 4179646, name = 'Justaucorps +1' },
            { id = 12650, lvl = 58, jobs =   16384, name = 'Evokers Doublet' },
            { id = 27801, lvl = 45, jobs =   16900, name = 'Namrus Jubbah' },
            { id = 27802, lvl = 45, jobs = 1605656, name = 'Neits Coat' },
            { id = 14517, lvl = 70, jobs =     193, name = 'Hydra Haubert' },
            { id = 11353, lvl = 63, jobs = 3662710, name = 'Menetriers Alb +1' },
            { id = 13797, lvl = 35, jobs = 4179646, name = 'Bishops Robe +1' },
            { id = 14439, lvl = 70, jobs =    2048, name = 'Hmn. Domaru +1' },
            { id = 13710, lvl = 45, jobs = 2473969, name = 'Brigandine +1' },
            { id = 13770, lvl = 70, jobs =    4096, name = 'War Shinobi Gi +1' },
            { id = 13796, lvl = 35, jobs = 4179646, name = 'Bishops Robe' },
            { id = 14565, lvl = 35, jobs =   32792, name = 'Machas Coat' },
            { id = 13719, lvl = 40, jobs = 4179646, name = 'Ryl.Sqr. Robe' },
            { id = 14447, lvl = 20, jobs = 4179646, name = 'Barons Saio' },
            { id = 14427, lvl = 29, jobs = 1720332, name = 'Seers Tunic +1' },
            { id = 13724, lvl = 40, jobs =     193, name = 'Breastplate +1' },
            { id = 12559, lvl = 40, jobs =    6593, name = 'Ryl.Sqr. Chainmail' },
            { id = 14424, lvl = 29, jobs = 1720332, name = 'Seers Tunic' },
            { id = 13721, lvl = 40, jobs = 3662710, name = 'Irn.Msk. Gambison' },
            { id = 14560, lvl = 25, jobs =   16900, name = 'Eas Doublet' },
            { id = 14435, lvl = 29, jobs =      65, name = 'Kampfbrust' },
            { id = 12566, lvl = 30, jobs = 2141649, name = 'Ctr. Scale Mail' },
            { id = 13707, lvl = 30, jobs = 2473969, name = 'Strong Vest' },
            { id = 13729, lvl = 19, jobs = 4179646, name = 'Priests Robe' },
            { id = 14559, lvl = 15, jobs =   16900, name = 'Anus Doublet' },
            { id = 12653, lvl = 20, jobs =    6146, name = 'Mercenarys Gi' },
            { id = 14339, lvl = 15, jobs = 2472947, name = 'Republic Harness' },
            { id = 14586, lvl =  1, jobs = 4194303, name = 'Cobra Tunica' },
            { id = 12661, lvl = 10, jobs = 2141649, name = 'Solid Mail' },
            { id = 12560, lvl = 10, jobs = 2141649, name = 'Scale Mail' },
            { id = 12629, lvl = 10, jobs = 2472947, name = 'Lgn. Harness' },
            { id = 14584, lvl =  1, jobs = 4194303, name = 'I.R. Jack Coat' },
            { id = 12607, lvl =  1, jobs = 2472947, name = 'Bronze Harness +1' },
            { id = 11330, lvl =  1, jobs = 4194303, name = 'Blksmith. Smock' },
        },
        HANDS =
        {
            { id = 23222, lvl = 99, jobs =       8, name = 'Wicce Gloves +2' },
            { id = 23239, lvl = 99, jobs = 1048576, name = 'Azimuth Gloves +2' },
            { id = 23238, lvl = 99, jobs =  524288, name = 'Arbatel Bracers +2' },
            { id = 23223, lvl = 99, jobs =      16, name = 'Lethargy Gantherots +2' },
            { id = 23775, lvl = 99, jobs = 4194303, name = 'Nyame Gauntlets' },
            { id = 14877, lvl = 70, jobs =       4, name = 'Blessed Mitts +1' },
            { id = 14875, lvl = 70, jobs =       4, name = 'Blessed Mitts' },
            { id = 14977, lvl = 75, jobs =   32792, name = 'Morrigans Cuffs' },
            { id = 14935, lvl = 72, jobs = 1622556, name = 'Yigit Gages' },
            { id = 14985, lvl = 75, jobs = 1720860, name = 'Goliard Cuffs' },
            { id = 14825, lvl = 72, jobs = 2473969, name = 'Dusk Gloves +1' },
            { id = 15013, lvl = 70, jobs = 1573000, name = 'Vicious Mufflers' },
            { id = 14951, lvl = 68, jobs = 2141649, name = 'Dragon Kote' },
            { id = 14984, lvl = 75, jobs = 2462754, name = 'Denali Wristbands' },
            { id = 15017, lvl = 70, jobs = 3851870, name = 'Toad Mittens' },
            { id = 15004, lvl = 52, jobs =  524288, name = 'Scholars Bracers' },
            { id = 14956, lvl = 53, jobs = 4179646, name = 'Magi Cuffs' },
            { id = 14867, lvl = 56, jobs = 3851870, name = 'Magical Mitts' },
            { id = 13954, lvl = 53, jobs = 4179646, name = 'Silk Cuffs +1' },
            { id = 14937, lvl = 50, jobs = 4194303, name = 'Storm Gages' },
            { id = 14845, lvl = 50, jobs =  164376, name = 'Sly Gauntlets' },
            { id = 14025, lvl = 27, jobs = 3851870, name = 'Dvt. Mitts +1' },
            { id = 14859, lvl = 29, jobs = 1720332, name = 'Seers Mitts +1' },
            { id = 15007, lvl = 55, jobs = 4179646, name = 'Cobra Cuffs' },
            { id = 14827, lvl = 50, jobs =   16384, name = 'Penance Cuffs' },
            { id = 14826, lvl = 50, jobs =   16384, name = 'Austere Cuffs' },
            { id = 14927, lvl = 70, jobs = 4194303, name = 'Hydra Bracers' },
            { id = 14884, lvl = 25, jobs = 1589260, name = 'Mycophile Cuffs' },
            { id = 14856, lvl = 29, jobs = 1720332, name = 'Seers Mitts' },
            { id = 12750, lvl = 36, jobs = 4179646, name = 'New Moon Armlets' },
            { id = 14062, lvl = 20, jobs =   16384, name = 'Carbuncle Mitts' },
            { id = 14054, lvl = 20, jobs = 4179646, name = 'Barons Cuffs' },
            { id = 12678, lvl = 40, jobs =     193, name = 'Irn.Msk. Gauntlets' },
            { id = 14019, lvl = 40, jobs = 2472947, name = 'Ogygoss Brc.' },
            { id = 12798, lvl = 11, jobs = 3851870, name = 'Zealots Mitts' },
            { id = 14841, lvl = 20, jobs = 4194303, name = 'Garrison Gloves' },
            { id = 12768, lvl = 10, jobs = 2141649, name = 'Solid Fng. Gnt.' },
            { id = 12797, lvl =  9, jobs =     193, name = 'Coarse Gauntlets' },
            { id = 12688, lvl = 10, jobs = 2141649, name = 'Scale Fng. Gnt.' },
            { id = 12752, lvl = 10, jobs = 2472947, name = 'Lgn. Mittens' },
            { id = 12775, lvl =  8, jobs = 3851870, name = 'Mitts +1' },
            { id = 14831, lvl =  1, jobs = 4194303, name = 'Smithys Mitts' },
            { id = 12695, lvl =  1, jobs = 2472947, name = 'Bronze Mittens +1' },
            { id = 12744, lvl =  1, jobs = 4179646, name = 'Cuffs +1' },
            { id = 12704, lvl =  1, jobs = 2472947, name = 'Bronze Mittens' },
        },
        LEGS =
        {
            { id = 23289, lvl = 99, jobs =       8, name = 'Wicce Chausses +2' },
            { id = 23290, lvl = 99, jobs =      16, name = 'Lethargy Fuseau +2' },
            { id = 23306, lvl = 99, jobs = 1048576, name = 'Azimuth Tights +2' },
            { id = 23305, lvl = 99, jobs =  524288, name = 'Arbatel Pants +2' },
            { id = 23782, lvl = 99, jobs = 4194303, name = 'Nyame Flanchard' },
            { id = 15641, lvl = 75, jobs =   32792, name = 'Morrigans Slops' },
            { id = 15576, lvl = 75, jobs =   41184, name = 'Homam Cosciales' },
            { id = 15393, lvl = 70, jobs =       4, name = 'Bls. Trousers +1' },
            { id = 14302, lvl = 72, jobs = 3850780, name = 'Mahatma Slops' },
            { id = 15391, lvl = 70, jobs =       4, name = 'Blessed Trousers' },
            { id = 15656, lvl = 75, jobs =     193, name = 'Valkyries Cuishes' },
            { id = 12818, lvl = 75, jobs =    7939, name = 'Byakkos Haidate' },
            { id = 15648, lvl = 75, jobs = 2462754, name = 'Denali Kecks' },
            { id = 14311, lvl = 50, jobs =   16384, name = 'Penance Slops' },
            { id = 16318, lvl = 68, jobs = 3850780, name = 'Cobra Trews' },
            { id = 12924, lvl = 48, jobs = 2141649, name = 'Magic Cuisses' },
            { id = 15597, lvl = 70, jobs =     193, name = 'Hydra Brayettes' },
            { id = 14218, lvl = 56, jobs =      16, name = 'Warlocks Tights' },
            { id = 14224, lvl = 56, jobs =    1024, name = 'Hunters Braccae' },
            { id = 28085, lvl = 45, jobs = 1605656, name = 'Neits Slops' },
            { id = 14310, lvl = 50, jobs =   16384, name = 'Austere Slops' },
            { id = 15372, lvl = 40, jobs = 1720844, name = 'Magic Slacks' },
            { id = 14286, lvl = 42, jobs = 3662710, name = 'Frog Trousers' },
            { id = 15624, lvl = 70, jobs = 2472947, name = 'Mrc. Subligar' },
            { id = 15621, lvl = 53, jobs = 4179646, name = 'Magi Slops' },
            { id = 14209, lvl = 59, jobs =    6593, name = 'Dst. Breeches +1' },
            { id = 15644, lvl = 35, jobs =   32792, name = 'Machas Slops' },
            { id = 14328, lvl = 29, jobs = 1720332, name = 'Seers Slacks +1' },
            { id = 14325, lvl = 29, jobs = 1720332, name = 'Seers Slacks' },
            { id = 14335, lvl = 50, jobs =    4096, name = 'Nokizaru Hakama' },
            { id = 12916, lvl = 40, jobs =     193, name = 'Cuisses +1' },
            { id = 12815, lvl = 40, jobs =    6593, name = 'Ryl.Sqr. Breeches' },
            { id = 14244, lvl = 40, jobs = 2141649, name = 'Iron Cuisses +1' },
            { id = 12918, lvl = 38, jobs = 4179646, name = 'Mages Slops' },
            { id = 15643, lvl = 25, jobs =   32792, name = 'Bodbs Slops' },
            { id = 12917, lvl = 20, jobs = 3851870, name = 'Mages Slacks' },
            { id = 12910, lvl = 30, jobs = 2473969, name = 'Strong Trousers' },
            { id = 14274, lvl = 15, jobs = 4179646, name = 'Federation Slops' },
            { id = 12882, lvl = 20, jobs = 2473969, name = 'Ryl.Ftm. Trousers' },
            { id = 12855, lvl = 20, jobs =    6146, name = 'Mrc. Sitabaki' },
            { id = 12863, lvl = 10, jobs = 2141649, name = 'Solid Cuisses' },
            { id = 12816, lvl = 10, jobs = 2141649, name = 'Scale Cuisses' },
            { id = 12915, lvl = 10, jobs = 4179646, name = 'Freeswords Slops' },
            { id = 12898, lvl =  8, jobs = 3851870, name = 'Slacks +1' },
            { id = 12899, lvl =  8, jobs =    6146, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, jobs = 2472947, name = 'Brz. Subligar +1' },
            { id = 12832, lvl =  1, jobs = 2472947, name = 'Bronze Subligar' },
            { id = 12897, lvl =  1, jobs = 4179646, name = 'Slops +1' },
            { id = 12856, lvl =  1, jobs = 4179646, name = 'Slops' },
        },
        FEET =
        {
            { id = 23372, lvl = 99, jobs =  524288, name = 'Arbatel Loafers +2' },
            { id = 23670, lvl = 99, jobs =      16, name = 'Vitiation Boots +3' },
            { id = 23373, lvl = 99, jobs = 1048576, name = 'Azimuth Gaiters +2' },
            { id = 23356, lvl = 99, jobs =       8, name = 'Wicce Sabots +2' },
            { id = 23789, lvl = 99, jobs = 4194303, name = 'Nyame Sollerets' },
            { id = 15350, lvl = 75, jobs = 1720844, name = 'Rostrum Pumps' },
            { id = 15727, lvl = 75, jobs =   32792, name = 'Morrigans Pgch.' },
            { id = 12946, lvl = 75, jobs =    7939, name = 'Suzakus Sune-Ate' },
            { id = 15669, lvl = 75, jobs =      16, name = 'Dls. Boots +1' },
            { id = 15331, lvl = 70, jobs =       4, name = 'Blessed Pumps +1' },
            { id = 15661, lvl = 75, jobs =   41184, name = 'Homam Gambieras' },
            { id = 15734, lvl = 75, jobs = 2462754, name = 'Denali Gamashes' },
            { id = 15329, lvl = 70, jobs =       4, name = 'Blessed Pumps' },
            { id = 14159, lvl = 70, jobs =     272, name = 'Ogre Ledelsens +1' },
            { id = 15758, lvl = 68, jobs = 3850780, name = 'Cobra Crackows' },
            { id = 15682, lvl = 70, jobs =     193, name = 'Hydra Sollerets' },
            { id = 13054, lvl = 39, jobs =    6146, name = 'Fuma Kyahan' },
            { id = 15737, lvl = 39, jobs =    6146, name = 'Sarutobi Kyahan' },
            { id = 14096, lvl = 52, jobs =     128, name = 'Chaos Sollerets' },
            { id = 11404, lvl = 60, jobs =  131072, name = 'Promptitude Solea' },
            { id = 15705, lvl = 68, jobs = 3851870, name = 'Ataractic Solea' },
            { id = 28222, lvl = 45, jobs = 1605656, name = 'Neits Pigaches' },
            { id = 12973, lvl = 35, jobs = 4194303, name = 'Mannequin Pumps' },
            { id = 14103, lvl = 56, jobs =   16384, name = 'Evokers Pigaches' },
            { id = 15751, lvl = 55, jobs = 4179646, name = 'Cobra Pigaches' },
            { id = 28218, lvl = 45, jobs =    8385, name = 'Ates Sollerets' },
            { id = 15709, lvl = 70, jobs =   10368, name = 'Mercenarys Boots' },
            { id = 11367, lvl = 70, jobs =    6146, name = 'Nobushi Kyahan' },
            { id = 15316, lvl = 29, jobs = 1720332, name = 'Seers Pumps +1' },
            { id = 14084, lvl = 59, jobs =    6593, name = 'Dst. Sollerets +1' },
            { id = 11401, lvl = 25, jobs = 4179646, name = 'Ramblers Gaiters' },
            { id = 15313, lvl = 29, jobs = 1720332, name = 'Seers Pumps' },
            { id = 14206, lvl = 18, jobs = 4194303, name = 'Garrison Boots' },
            { id = 13048, lvl = 20, jobs = 3851870, name = 'Mages Sandals' },
            { id = 15344, lvl = 20, jobs = 4179646, name = 'Barons Pigaches' },
            { id = 14140, lvl = 15, jobs = 2472947, name = 'Republic Leggings' },
            { id = 13024, lvl = 10, jobs = 2141649, name = 'Solid Greaves' },
            { id = 12944, lvl = 10, jobs = 2141649, name = 'Scale Greaves' },
            { id = 13004, lvl = 10, jobs = 2473969, name = 'Ryl.Ftm. Boots' },
            { id = 13003, lvl = 10, jobs = 2472947, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, jobs = 3851870, name = 'Solea +1' },
            { id = 12951, lvl =  1, jobs = 2472947, name = 'Brz. Leggings +1' },
            { id = 12983, lvl =  1, jobs = 4179646, name = 'Ash Clogs +1' },
            { id = 11400, lvl =  1, jobs = 4194303, name = 'Noble Poulaines' },
            { id = 11403, lvl =  1, jobs = 4194303, name = 'Talaria' },
        },
        NECK =
        {
            { id = 26023, lvl = 99, jobs = 4194303, name = 'Sanctity Necklace' },
            { id = 25437, lvl = 99, jobs =       8, name = 'Src. Stole +2' },
            { id = 25436, lvl = 99, jobs =       8, name = 'Src. Stole +1' },
            { id = 25443, lvl = 99, jobs =      16, name = 'Dls. Torque +2' },
            { id = 11580, lvl = 75, jobs = 1720860, name = 'Fylgja Torque +1' },
            { id = 28393, lvl = 75, jobs = 4194303, name = 'Goetic Torque' },
            { id = 11584, lvl = 75, jobs = 4194303, name = 'Lmg. Medallion +1' },
            { id = 13175, lvl = 58, jobs =   16388, name = 'Ajari Necklace' },
            { id = 15510, lvl = 73, jobs = 4194303, name = 'Prudence Torque' },
            { id = 13131, lvl = 67, jobs =     192, name = 'Dst. Gorget +1' },
            { id = 16269, lvl = 70, jobs = 4194303, name = 'Morganas Choker' },
            { id = 15522, lvl = 60, jobs = 4194303, name = 'Enlightened Chain' },
            { id = 13135, lvl = 48, jobs = 4194303, name = 'Promise Badge' },
            { id = 13126, lvl = 58, jobs = 4194303, name = 'Torque +1' },
            { id = 16262, lvl = 40, jobs = 4194303, name = 'Mohbwa Scarf +1' },
            { id = 11624, lvl = 33, jobs = 4194303, name = 'Solon Torque' },
            { id = 16264, lvl = 50, jobs = 4194303, name = 'Beak Necklace +1' },
            { id = 16263, lvl = 50, jobs = 4194303, name = 'Beak Necklace' },
            { id = 13073, lvl = 26, jobs = 4194303, name = 'Holy Phial' },
            { id = 16261, lvl = 40, jobs = 4194303, name = 'Mohbwa Scarf' },
            { id = 13093, lvl =  7, jobs = 4194303, name = 'Justice Badge' },
            { id = 13099, lvl = 30, jobs = 4194303, name = 'Rep.Iron Medal' },
            { id = 13113, lvl = 20, jobs = 3851870, name = 'Black Neckerchief' },
            { id = 13070, lvl = 30, jobs = 2473969, name = 'Wolf Gorget +1' },
            { id = 13058, lvl = 20, jobs = 4194303, name = 'Bloodbead Amulet' },
            { id = 16285, lvl = 20, jobs = 4194303, name = 'Pendant Compass' },
            { id = 13098, lvl = 10, jobs = 4194303, name = 'Rep.Bronze Medal' },
            { id = 13101, lvl = 10, jobs = 4179646, name = 'Green Scarf' },
            { id = 13096, lvl =  9, jobs = 4194303, name = 'Dog Collar' },
            { id = 13078, lvl =  1, jobs = 4194303, name = 'Portafurnace' },
            { id = 13121, lvl =  1, jobs = 4194303, name = 'Beast Collar' },
            { id = 13122, lvl =  1, jobs = 4194303, name = 'Miners Pendant' },
            { id = 16273, lvl =  1, jobs = 4194303, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 26364, lvl = 99, jobs = 2097216, name = 'Sroda Belt' },
            { id = 26357, lvl = 99, jobs = 4194303, name = 'Skrymir Cord +1' },
            { id = 26351, lvl = 99, jobs = 1605660, name = 'Sacro Cord' },
            { id = 26356, lvl = 99, jobs = 4194303, name = 'Skrymir Cord' },
            { id = 13186, lvl = 70, jobs =       2, name = 'Black Belt' },
            { id = 28425, lvl = 75, jobs = 4194303, name = 'Salire Belt' },
            { id = 15925, lvl = 70, jobs =  524288, name = 'Argute Belt' },
            { id = 13202, lvl = 40, jobs =       2, name = 'Brown Belt' },
            { id = 15458, lvl = 75, jobs = 4194303, name = 'Ninurtas Sash' },
            { id = 13250, lvl = 65, jobs = 2473969, name = 'Sonic Belt +1' },
            { id = 13249, lvl = 65, jobs = 2473969, name = 'Sonic Belt' },
            { id = 15872, lvl = 70, jobs =       4, name = 'Clerics Belt' },
            { id = 13189, lvl = 55, jobs = 2473969, name = 'Speed Belt' },
            { id = 15899, lvl = 55, jobs = 2473969, name = 'Velocious Belt' },
            { id = 15292, lvl = 60, jobs = 1622556, name = 'Penitents Rope' },
            { id = 15924, lvl = 69, jobs = 4179646, name = 'Demagogues Sash' },
            { id = 15457, lvl = 50, jobs = 4194303, name = 'Swift Belt' },
            { id = 13201, lvl = 18, jobs =       2, name = 'Purple Belt' },
            { id = 15941, lvl = 44, jobs = 4194303, name = 'Headlong Belt' },
            { id = 13220, lvl = 50, jobs = 2473969, name = 'Ryl.Kgt. Belt' },
            { id = 15908, lvl = 40, jobs = 3851870, name = 'Qiqirn Sash +1' },
            { id = 13238, lvl = 40, jobs = 1758748, name = 'Druids Rope' },
            { id = 15287, lvl = 40, jobs = 3851870, name = 'Mantra Belt' },
            { id = 13221, lvl = 30, jobs = 4179646, name = 'Mrc.Cpt. Belt' },
            { id = 13228, lvl = 28, jobs = 3851870, name = 'Shamans Belt' },
            { id = 15906, lvl = 20, jobs = 3851870, name = 'Mohbwa Sash +1' },
            { id = 15905, lvl = 20, jobs = 3851870, name = 'Mohbwa Sash' },
            { id = 13214, lvl = 40, jobs =     193, name = 'Waistbelt +1' },
            { id = 13272, lvl = 40, jobs = 4194303, name = 'Corsette +1' },
            { id = 13211, lvl = 14, jobs = 4194303, name = 'Friars Rope' },
            { id = 15947, lvl = 28, jobs = 4194303, name = 'Griot Belt +1' },
            { id = 13190, lvl =  8, jobs = 3851870, name = 'Heko Obi +1' },
            { id = 13204, lvl =  8, jobs = 3851870, name = 'Heko Obi' },
            { id = 13210, lvl =  7, jobs = 2473969, name = 'Leather Belt +1' },
            { id = 15889, lvl =  7, jobs = 2473969, name = 'Augmenting Belt' },
            { id = 15456, lvl =  1, jobs = 4194303, name = 'Dash Sash' },
            { id = 10847, lvl =  1, jobs = 4194303, name = 'Orc Belt' },
            { id = 10848, lvl =  1, jobs = 4194303, name = 'Quadav Belt' },
            { id = 10849, lvl =  1, jobs = 4194303, name = 'Yagudo Belt' },
        },
        BACK =
        {
            { id = 27620, lvl = 99, jobs = 1753628, name = 'Aurists Cape +1' },
            { id = 28632, lvl = 99, jobs =   32768, name = 'Cornflower Cape' },
            { id = 28620, lvl = 99, jobs =       8, name = 'Bane Cape' },
            { id = 28633, lvl = 99, jobs =   65536, name = 'Gunslingers Cape' },
            { id = 28607, lvl = 99, jobs = 2473971, name = 'Aput Mantle +1' },
            { id = 27599, lvl = 75, jobs = 1753628, name = 'Dew Silk Cape +1' },
            { id = 16242, lvl = 74, jobs = 1065484, name = 'Ixion Cape' },
            { id = 13627, lvl = 71, jobs = 1753628, name = 'Prism Cape' },
            { id = 27598, lvl = 75, jobs = 1753628, name = 'Dew Silk Cape' },
            { id = 15479, lvl = 70, jobs =     128, name = 'Abyss Cape' },
            { id = 16228, lvl = 70, jobs = 1753628, name = 'Aslan Cape' },
            { id = 16244, lvl = 70, jobs =   32768, name = 'Mirage Mantle' },
            { id = 15478, lvl = 70, jobs =       2, name = 'Melee Cape' },
            { id = 15490, lvl = 60, jobs = 1753628, name = 'Miraculous Cape' },
            { id = 13611, lvl = 43, jobs = 1753628, name = 'Red Cape +1' },
            { id = 15492, lvl = 60, jobs = 1753628, name = 'Intensifying Cape' },
            { id = 15471, lvl = 73, jobs = 4194303, name = 'Merciful Cape' },
            { id = 16214, lvl = 65, jobs = 2473971, name = 'Lamia Mantle +1' },
            { id = 13687, lvl = 60, jobs = 1753628, name = 'Sapient Cape' },
            { id = 15489, lvl = 50, jobs = 1753628, name = 'Storm Cape' },
            { id = 13586, lvl = 43, jobs = 1753628, name = 'Red Cape' },
            { id = 13581, lvl = 55, jobs = 4194303, name = 'Fed. Army Mantle' },
            { id = 13679, lvl = 50, jobs =     192, name = 'Templars Mantle' },
            { id = 13610, lvl = 32, jobs = 1753628, name = 'Black Cape +1' },
            { id = 13618, lvl = 32, jobs = 1753628, name = 'White Cape +1' },
            { id = 13577, lvl = 32, jobs = 1753628, name = 'Black Cape' },
            { id = 13585, lvl = 32, jobs = 1753628, name = 'White Cape' },
            { id = 13676, lvl = 50, jobs =    8641, name = 'Heavy Mantle' },
            { id = 16237, lvl = 50, jobs = 2473971, name = 'Thunderers Mantle' },
            { id = 15468, lvl = 40, jobs = 2473971, name = 'Resentment Cape' },
            { id = 13614, lvl = 25, jobs = 1753628, name = 'Bonze Cape' },
            { id = 13644, lvl = 30, jobs = 1753628, name = 'Midnight Cape' },
            { id = 13643, lvl = 30, jobs = 1753628, name = 'Sarcenet Cape' },
            { id = 13659, lvl = 30, jobs = 4194303, name = 'Mercen. Mantle' },
            { id = 13681, lvl = 20, jobs = 1753628, name = 'Variable Cape' },
            { id = 13607, lvl = 10, jobs = 1753628, name = 'Mist Silk Cape' },
            { id = 13680, lvl = 20, jobs = 2473971, name = 'Variable Mantle' },
            { id = 13600, lvl = 18, jobs = 2473971, name = 'Dhalmel Mantle +1' },
            { id = 13605, lvl =  7, jobs = 1753628, name = 'Cape +1' },
            { id = 13583, lvl =  7, jobs = 1753628, name = 'Cape' },
            { id = 13599, lvl =  4, jobs = 2473971, name = 'Rabbit Mantle +1' },
            { id = 11009, lvl =  1, jobs = 4194303, name = 'Shapers Shawl' },
            { id = 16243, lvl =  1, jobs = 4194303, name = 'Drovers Mantle' },
            { id = 11002, lvl =  1, jobs = 4194303, name = 'Dragon Tank' },
            { id = 13682, lvl =  1, jobs = 4194303, name = 'Ether Tank' },
        },
        EAR =
        {
            { id = 26088, lvl = 99, jobs = 1589404, name = 'Malignance Earring' },
            { id = 26085, lvl = 99, jobs = 1606172, name = 'Regal Earring' },
            { id = 26109, lvl = 99, jobs =      16, name = 'Snotra Earring' },
            { id = 26117, lvl = 99, jobs = 4194303, name = 'Crep. Earring' },
            { id = 28474, lvl = 99, jobs = 4194303, name = 'Mendi. Earring' },
            { id = 16002, lvl = 73, jobs = 2514972, name = 'Roundel Earring' },
            { id = 14808, lvl = 75, jobs = 4194303, name = 'Novio Earring' },
            { id = 14807, lvl = 54, jobs =      64, name = 'Hospitaler Earring' },
            { id = 14812, lvl = 75, jobs = 4194303, name = 'Loquac. Earring' },
            { id = 15992, lvl = 67, jobs = 4194303, name = 'Celestial Earring' },
            { id = 14724, lvl = 47, jobs = 4194303, name = 'Moldavite Earring' },
            { id = 15991, lvl = 67, jobs = 4194303, name = 'Star Earring' },
            { id = 14728, lvl = 60, jobs = 4194303, name = 'Phtm. Earring +1' },
            { id = 14714, lvl = 67, jobs = 4194303, name = 'Omn. Earring +1' },
            { id = 14727, lvl = 60, jobs = 4194303, name = 'Phantom Earring' },
            { id = 15971, lvl = 50, jobs = 4194303, name = 'Antivenom Earring' },
            { id = 15972, lvl = 50, jobs = 4194303, name = 'Insomnia Earring' },
            { id = 14721, lvl = 30, jobs = 4194303, name = 'Morion Earring +1' },
            { id = 14710, lvl = 49, jobs = 4194303, name = 'Mana Earring +1' },
            { id = 14766, lvl = 38, jobs = 4194303, name = 'Geist Earring' },
            { id = 14720, lvl = 30, jobs = 4194303, name = 'Morion Earring' },
            { id = 13405, lvl = 40, jobs = 1758748, name = 'Enhancing Earring' },
            { id = 14760, lvl = 29, jobs = 4194303, name = 'Cunning Earring' },
            { id = 11043, lvl = 30, jobs = 4194303, name = 'Giants Earring' },
            { id = 13364, lvl = 17, jobs = 4194303, name = 'Valor Earring' },
            { id = 14757, lvl = 20, jobs = 4194303, name = 'Mecurial Earring' },
            { id = 16039, lvl = 20, jobs = 4194303, name = 'Kingdom Earring' },
            { id = 16040, lvl = 20, jobs = 4194303, name = 'Republic Earring' },
            { id = 14694, lvl = 10, jobs = 4194303, name = 'Energy Earring +1' },
            { id = 13379, lvl = 10, jobs = 4194303, name = 'Energy Earring' },
            { id = 13336, lvl = 10, jobs = 4194303, name = 'Onyx Earring' },
            { id = 14688, lvl = 10, jobs = 4194303, name = 'Reflex Earring +1' },
            { id = 13402, lvl =  1, jobs = 4194303, name = 'Cassie Earring' },
            { id = 28510, lvl =  1, jobs = 4194303, name = 'M. Slime Earring' },
            { id = 16003, lvl =  1, jobs = 4194303, name = 'Raising Earring' },
            { id = 28509, lvl =  1, jobs = 4194303, name = 'She-Slime Earring' },
        },
        RING =
        {
            { id = 26192, lvl = 99, jobs = 4194303, name = 'Adoulin Ring +1' },
            { id = 26194, lvl = 99, jobs = 4194303, name = 'Weather. Ring +1' },
            { id = 26184, lvl = 99, jobs = 4194303, name = 'Stikini Ring +1' },
            { id = 27580, lvl = 99, jobs = 4194303, name = 'Adoulin Ring' },
            { id = 15800, lvl = 75, jobs = 4194303, name = 'Omega Ring' },
            { id = 15806, lvl = 72, jobs = 4194303, name = 'Celestial Ring' },
            { id = 11633, lvl = 75, jobs = 4194303, name = 'Galdr Ring' },
            { id = 11632, lvl = 75, jobs = 4194303, name = 'Karka Ring' },
            { id = 15777, lvl = 50, jobs = 4194303, name = 'Hale Ring' },
            { id = 14673, lvl = 69, jobs = 1589788, name = 'Serene Ring' },
            { id = 15545, lvl = 30, jobs = 4194303, name = 'Tamas Ring' },
            { id = 15784, lvl = 60, jobs =  474915, name = 'Dominion Ring' },
            { id = 15807, lvl = 50, jobs = 4194303, name = 'Balrahns Ring' },
            { id = 14610, lvl = 54, jobs = 4194303, name = 'Genius Ring +1' },
            { id = 14668, lvl = 56, jobs = 4194303, name = 'Zoredonite Ring' },
            { id = 14685, lvl = 49, jobs = 4194303, name = 'Kshama Ring No.5' },
            { id = 14686, lvl = 49, jobs = 4194303, name = 'Kshama Ring No.9' },
            { id = 15827, lvl = 70, jobs = 4194303, name = 'Insect Ring' },
            { id = 14602, lvl = 36, jobs = 4194303, name = 'Wisdom Ring +1' },
            { id = 14604, lvl = 36, jobs = 4194303, name = 'Solace Ring +1' },
            { id = 14667, lvl = 25, jobs = 4194303, name = 'Carect Ring' },
            { id = 26219, lvl =  1, jobs = 4194303, name = 'Najis Loop' },
            { id = 13283, lvl = 10, jobs = 4194303, name = 'Saintly Ring +1' },
            { id = 13285, lvl = 10, jobs = 4194303, name = 'Eremites Ring +1' },
            { id = 14594, lvl = 14, jobs = 4194303, name = 'Kldg. Ring +1' },
            { id = 14596, lvl = 14, jobs = 4194303, name = 'Trq. Ring +1' },
            { id = 13282, lvl = 10, jobs = 4194303, name = 'Saintly Ring' },
            { id = 15546, lvl = 15, jobs = 4194303, name = 'Fasting Ring' },
            { id = 13514, lvl = 30, jobs = 4194303, name = 'Archers Ring' },
            { id = 13496, lvl =  1, jobs = 4194303, name = 'Windurstian Ring' },
            { id = 13495, lvl =  1, jobs = 4194303, name = 'San Dorian Ring' },
            { id = 13440, lvl =  1, jobs = 4194303, name = 'Ascetics Ring' },
        },
    },
}
testGear.ROLE_GEAR.melee = testGear.ROLE_GEAR.tp

-----------------------------------
-- Default Job & SoulspireXI Spec Profiles
-----------------------------------
function testGear.getActiveSpecKey(player, jobId)
    if player == nil or spec == nil then
        return nil, nil
    end
    local targetJob = jobId or player:getMainJob()
    local entry = spec.get(player, targetJob)
    if entry ~= nil and spec.isLevelEligible(player, targetJob, entry) then
        return entry.key, entry
    end
    return nil, nil
end

function testGear.getDefaultProfile(player, optJobId, optLevel)
    local jobId = optJobId or (player and player:getMainJob()) or 1
    local specKey, specEntry = testGear.getActiveSpecKey(player, jobId)
    if specKey == nil and player ~= nil and spec ~= nil and optLevel ~= nil then
        local stored = spec.get(player, jobId)
        if stored ~= nil and optLevel >= (tonumber(stored.reqLevel) or spec.DEFAULT_REQ_LEVEL or 10) then
            specKey = stored.key
            specEntry = stored
        end
    end

    local j = xi.job or {}

    if jobId == (j.WAR or 1) then
        if specKey == 'spartan' or specKey == 'gladiator' then
            return { role = 'tank', weapon = 'polearm', offhand = 'none', ranged = 'none', ammo = 'ammo_tank', label = 'WAR Spartan (Polearm & Buckler Tank)', specEntry = specEntry }
        elseif specKey == 'commander' then
            return { role = 'tp', weapon = 'gaxe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'WAR Commander (Great Axe TP)', specEntry = specEntry }
        elseif specKey == 'berserker' then
            return { role = 'tp', weapon = 'gaxe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'WAR Berserker (Great Axe TP)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'gaxe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'Warrior (Great Axe TP)' }
    elseif jobId == (j.MNK or 2) then
        if specKey == 'sensei' then
            return { role = 'tank', weapon = 'staff', offhand = 'grip_tank', ranged = 'none', ammo = 'ammo_tank', label = 'MNK Sensei (Staff Counter Tank)', specEntry = specEntry }
        elseif specKey == 'blackbelt' then
            return { role = 'tp', weapon = 'h2h', offhand = 'none', ranged = 'none', ammo = 'ammo_tp', label = 'MNK Black Belt (Hand-to-Hand DPS)', specEntry = specEntry }
        elseif specKey == 'chiweaver' then
            return { role = 'caster', weapon = 'none', offhand = 'none', ranged = 'none', ammo = 'ammo_caster', label = 'MNK Chi Weaver (Unarmed Chi Healer)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'h2h', offhand = 'none', ranged = 'none', ammo = 'ammo_tp', label = 'Monk (Hand-to-Hand TP)' }
    elseif jobId == (j.WHM or 3) then
        if specKey == 'valkyrie' then
            return { role = 'tp', weapon = 'polearm', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'WHM Valkyrie (Polearm Support)', specEntry = specEntry }
        elseif specKey == 'zealot' then
            return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'WHM Zealot (Staff Communion)', specEntry = specEntry }
        end
        return { role = 'caster', weapon = 'club_mage', offhand = 'shield', ranged = 'none', ammo = 'ammo_caster', label = 'White Mage (Club & Shield)' }
    elseif jobId == (j.BLM or 4) then
        if specKey == 'necromancer' then
            return { role = 'caster', weapon = 'scythe_blm', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'BLM Necromancer (Scythe & Undead)', specEntry = specEntry }
        end
        return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'Black Mage (Staff)' }
    elseif jobId == (j.RDM or 5) then
        return { role = 'caster', weapon = 'sword', offhand = 'shield', ranged = 'none', ammo = 'ammo_caster', label = 'Red Mage (Sword & Shield)' }
    elseif jobId == (j.THF or 6) then
        if specKey == 'phantom' then
            return { role = 'tank', weapon = 'dagger', offhand = 'none', ranged = 'none', ammo = 'ammo_tank', label = 'THF Phantom (Evasion Tank)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'dagger', offhand = 'auto', ranged = 'throwing', ammo = 'none', label = 'Thief (Dagger TP)' }
    elseif jobId == (j.PLD or 7) then
        if specKey == 'oathbreaker' then
            return { role = 'tp', weapon = 'gsword', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'PLD Oathbreaker (Great Sword)', specEntry = specEntry }
        end
        return { role = 'tank', weapon = 'sword', offhand = 'shield', ranged = 'none', ammo = 'ammo_tank', label = 'Paladin (Sword & Shield Tank)' }
    elseif jobId == (j.DRK or 8) then
        if specKey == 'reaper' then
            return { role = 'tp', weapon = 'scythe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'DRK Reaper (Scythe)', specEntry = specEntry }
        elseif specKey == 'scourge' then
            return { role = 'caster', weapon = 'scythe', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'DRK Scourge (Scythe Curses)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'scythe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'Dark Knight (Scythe TP)' }
    elseif jobId == (j.BST or 9) then
        if specKey == 'untamed' then
            return { role = 'tp', weapon = 'axe', offhand = 'none', ranged = 'none', ammo = 'ammo_tp', label = 'BST Untamed (Pack Assault)', specEntry = specEntry }
        elseif specKey == 'beastspeaker' then
            return { role = 'tp', weapon = 'axe', offhand = 'none', ranged = 'none', ammo = 'ammo_tp', label = 'BST Beastspeaker (Quarry Support)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'axe', offhand = 'auto', ranged = 'none', ammo = 'ammo_tp', label = 'Beastmaster (Axe TP)' }
    elseif jobId == (j.BRD or 10) then
        return { role = 'caster', weapon = 'dagger', offhand = 'shield', ranged = 'instrument', ammo = 'none', label = 'Bard (Dagger & Instrument)' }
    elseif jobId == (j.RNG or 11) then
        if specKey == 'sniper' then
            return { role = 'ranged', weapon = 'dagger', offhand = 'none', ranged = 'crossbow', ammo = 'bolt', label = 'RNG Sniper (Crossbow)', specEntry = specEntry }
        elseif specKey == 'arcanearcher' then
            return { role = 'ranged', weapon = 'dagger', offhand = 'none', ranged = 'bow', ammo = 'arrow', label = 'RNG Arcane Archer (Bow)', specEntry = specEntry }
        end
        return { role = 'ranged', weapon = 'dagger', offhand = 'auto', ranged = 'bow', ammo = 'arrow', label = 'Ranger (Dagger & Bow)' }
    elseif jobId == (j.SAM or 12) then
        if specKey == 'ronin' then
            return { role = 'tank', weapon = 'gkatana', offhand = 'grip_tank', ranged = 'none', ammo = 'ammo_tank', label = 'SAM Ronin (Great Katana Mushin Tank)', specEntry = specEntry }
        elseif specKey == 'imperialarcher' then
            return { role = 'ranged', weapon = 'gkatana', offhand = 'grip_melee', ranged = 'bow', ammo = 'arrow', label = 'SAM Imperial Archer (Bow & Great Katana)', specEntry = specEntry }
        elseif specKey == 'warlord' then
            return { role = 'tp', weapon = 'gkatana', offhand = 'grip_melee', ranged = 'bow', ammo = 'arrow', label = 'SAM Warlord (Great Katana Iaijutsu DPS)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'gkatana', offhand = 'grip_melee', ranged = 'bow', ammo = 'arrow', label = 'Samurai (Great Katana TP)' }
    elseif jobId == (j.NIN or 13) then
        if specKey == 'nightblade' then
            return { role = 'caster', weapon = 'katana', offhand = 'auto', ranged = 'none', ammo = 'ammo_caster', label = 'NIN Nightblade (Katana Seals)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'katana', offhand = 'auto', ranged = 'none', ammo = 'shuriken', label = 'Ninja (Katana & Shuriken TP)' }
    elseif jobId == (j.DRG or 14) then
        if specKey == 'lancer' then
            return { role = 'tp', weapon = 'polearm', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'DRG Lancer (Polearm Vault)', specEntry = specEntry }
        elseif specKey == 'skyborn' then
            return { role = 'tank', weapon = 'polearm', offhand = 'grip_tank', ranged = 'none', ammo = 'ammo_tank', label = 'DRG Skyborn (Polearm Guard)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'polearm', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_tp', label = 'Dragoon (Polearm TP)' }
    elseif jobId == (j.SMN or 15) then
        if specKey == 'primalist' then
            return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'SMN Primalist (Elemental Pacts)', specEntry = specEntry }
        end
        return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'Summoner (Staff)' }
    elseif jobId == (j.BLU or 16) then
        if specKey == 'warmage' then
            return { role = 'caster', weapon = 'sword', offhand = 'none', ranged = 'none', ammo = 'ammo_caster', label = 'BLU Warmage (Monster Magic)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'sword', offhand = 'auto', ranged = 'none', ammo = 'ammo_tp', label = 'Blue Mage (Sword TP)' }
    elseif jobId == (j.COR or 17) then
        return { role = 'ranged', weapon = 'dagger', offhand = 'auto', ranged = 'gun', ammo = 'bullet', label = 'Corsair (Dagger & Gun)' }
    elseif jobId == (j.PUP or 18) then
        return { role = 'tp', weapon = 'h2h', offhand = 'none', ranged = 'animator', ammo = 'oil', label = 'Puppetmaster (H2H & Animator TP)' }
    elseif jobId == (j.DNC or 19) then
        if specKey == 'bladewheel' then
            return { role = 'ranged', weapon = 'dagger', offhand = 'auto', ranged = 'chakram_dnc', ammo = 'none', label = 'DNC Bladewheel (Daggers & Chakram)', specEntry = specEntry }
        end
        return { role = 'tp', weapon = 'dagger', offhand = 'auto', ranged = 'throwing', ammo = 'none', label = 'Dancer (Daggers & Throwing TP)' }
    elseif jobId == (j.SCH or 20) then
        if specKey == 'archivist' then
            return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'SCH Archivist (Staff & Countermeasures)', specEntry = specEntry }
        elseif specKey == 'medic' then
            return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'orphic_egg', label = 'SCH Medic (Staff & Orphic Egg)', specEntry = specEntry }
        elseif specKey == 'sage' then
            return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'orphic_egg', label = 'SCH Sage (Staff & Orphic Egg)', specEntry = specEntry }
        end
        return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'orphic_egg', label = 'Scholar (Staff & Orphic Egg)' }
    elseif jobId == (j.GEO or 21) then
        return { role = 'caster', weapon = 'club_mage', offhand = 'shield', ranged = 'handbell', ammo = 'none', label = 'Geomancer (Club & Handbell)' }
    elseif jobId == (j.RUN or 22) then
        if specKey == 'inquisitor' then
            return { role = 'tank', weapon = 'gsword', offhand = 'grip_tank', ranged = 'none', ammo = 'ammo_tank', label = 'RUN Inquisitor (Great Sword Ward Tank)', specEntry = specEntry }
        elseif specKey == 'spellblade' then
            return { role = 'melee', weapon = 'gsword', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_melee', label = 'RUN Spellblade (Great Sword Effusion DPS)', specEntry = specEntry }
        elseif specKey == 'lifebinder' then
            return { role = 'caster', weapon = 'gsword', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'RUN Lifebinder (Great Sword Runic Healer)', specEntry = specEntry }
        end
        return { role = 'tank', weapon = 'gsword', offhand = 'grip_tank', ranged = 'none', ammo = 'ammo_tank', label = 'Rune Fencer (Great Sword Tank)' }
    end

    return { role = 'tp', weapon = 'sword', offhand = 'shield', ranged = 'none', ammo = 'ammo_tp', label = 'Adventurer' }
end

-----------------------------------
-- Candidate Eligibility & Slot Resolution
-----------------------------------
local function hasJobBit(jobsMask, jobId)
    if jobsMask == nil or jobId == nil or jobId < 1 or jobId > 22 then
        return true
    end
    local divisor = 2 ^ (jobId - 1)
    return math.floor(jobsMask / divisor) % 2 == 1
end

local function hasDualWield(player)
    if player == nil or not player.hasTrait then
        return false
    end
    local dwTrait = (xi.trait and xi.trait.DUAL_WIELD) or 18
    return player:hasTrait(dwTrait)
end

local function isItemEquippable(player, entry, targetLevel, opts)
    if player == nil or entry == nil or entry.id == nil then
        return false
    end
    if entry.lvl > targetLevel then
        return false
    end
    opts = opts or {}
    if opts.excludeId ~= nil and entry.id == opts.excludeId then
        return false
    end

    local jobId = player.getMainJob and player:getMainJob() or 1
    local blmJob = (xi.job and xi.job.BLM) or 4

    -- BLM Necromancer Scythe check:
    -- scythe_blm allows shared WAR/DRK/BST zaghnals at < Lv.40 and native BLM scythes at >= Lv.40,
    -- while never allowing DRK-exclusive (jobs == 128) scythes.
    if (opts.weaponKey == 'scythe_blm' or opts.weaponKey == 'scythe') and jobId == blmJob then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec ~= 'necromancer' and opts.targetLevel and opts.targetLevel >= 10 then
            local stored = spec and spec.get(player, jobId) or nil
            if stored and stored.key == 'necromancer' then
                activeSpec = 'necromancer'
            end
        end
        if activeSpec ~= 'necromancer' then
            return false
        end
    else
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        local soulWeapon = (opts.weaponKey == 'polearm' and activeSpec == 'valkyrie') or
            (opts.weaponKey == 'katana' and activeSpec == 'phantom')
        -- Strictly verify vanilla job bitmask so SQL overrides for other specs never leak items across jobs.
        -- Soul weapon exceptions are checked by player:canEquipItem below.
        if not soulWeapon and entry.jobs ~= nil and not hasJobBit(entry.jobs, jobId) then
            return false
        end
    end

    if player.canEquipItem then
        return player:canEquipItem(entry.id, false)
    end
    return true
end

function testGear.pickFromPool(player, pool, targetLevel, opts)
    if pool == nil then
        return nil
    end
    opts = opts or {}
    opts.targetLevel = targetLevel
    for _, entry in ipairs(pool) do
        if isItemEquippable(player, entry, targetLevel, opts) then
            return entry
        end
    end
    return nil
end

function testGear.isWeaponAllowedForJob(player, wKey)
    if player == nil or wKey == nil then
        return false
    end
    local jobId = player:getMainJob()
    if jobId == (xi.job.SMN or 15) and testGear.getActiveSpecKey(player, jobId) == 'primalist' then
        return wKey == 'staff' or wKey == 'staff_mage' or wKey == 'club' or wKey == 'club_mage'
    end
    if jobId == (xi.job.BST or 9) and testGear.getActiveSpecKey(player, jobId) == 'untamed' then
        return wKey == 'axe' or wKey == 'gaxe'
    end
    if jobId == (xi.job.BST or 9) and testGear.getActiveSpecKey(player, jobId) == 'beastspeaker' then
        return wKey == 'axe'
    end
    if jobId == (xi.job.SCH or 20) and testGear.getActiveSpecKey(player, jobId) == 'archivist' then
        return wKey == 'staff' or wKey == 'staff_mage' or wKey == 'club' or wKey == 'club_mage'
    end
    if jobId == (xi.job.BLU or 16) and testGear.getActiveSpecKey(player, jobId) == 'warmage' then
        return wKey == 'sword' or wKey == 'club' or wKey == 'club_mage'
    end
    if jobId == (xi.job.DRG or 14) then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec == 'lancer' or activeSpec == 'skyborn' then return wKey == 'polearm' end
    end
    if jobId == (xi.job.NIN or 13) and testGear.getActiveSpecKey(player, jobId) == 'nightblade' then
        return wKey == 'katana'
    end
    if jobId == (xi.job.RNG or 11) then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec == 'sniper' then return wKey == 'crossbow' or wKey == 'gun' or wKey == 'dagger' end
        if activeSpec == 'arcanearcher' then return wKey == 'bow' or wKey == 'dagger' end
    end
    if jobId == (xi.job.DRK or 8) then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec == 'reaper' or activeSpec == 'scourge' then return wKey == 'scythe' end
    end
    if jobId == (xi.job.PLD or 7) and testGear.getActiveSpecKey(player, jobId) == 'oathbreaker' then
        return wKey == 'gsword'
    end
    if jobId == (xi.job.THF or 6) then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec == 'phantom' then
            return wKey == 'dagger' or wKey == 'katana'
        elseif activeSpec == 'bandit' or activeSpec == 'trickster' then
            return wKey == 'dagger' or wKey == 'sword'
        end
    end
    if jobId == (xi.job.WHM or 3) then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec == 'valkyrie' then
            return wKey == 'polearm'
        elseif activeSpec == 'zealot' then
            return wKey == 'staff' or wKey == 'staff_mage'
        end
    end
    local blmJob = (xi.job and xi.job.BLM) or 4
    if (wKey == 'scythe' or wKey == 'scythe_blm') and jobId == blmJob then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        local stored = spec and spec.get(player, jobId) or nil
        return activeSpec == 'necromancer' or (stored ~= nil and stored.key == 'necromancer')
    end
    local mnkJob = (xi.job and xi.job.MNK) or 2
    if jobId == mnkJob then
        local activeSpec = testGear.getActiveSpecKey(player, jobId)
        if activeSpec == 'blackbelt' then
            return wKey == 'h2h'
        elseif activeSpec == 'chiweaver' then
            return false
        end
    end
    local allowedList = testGear.JOB_WEAPONS[jobId]
    if allowedList == nil then
        return true
    end
    local baseKey = wKey
    if wKey == 'club_mage' then
        baseKey = 'club'
    elseif wKey == 'staff_mage' then
        baseKey = 'staff'
    end
    for _, k in ipairs(allowedList) do
        if k == baseKey or k == wKey then
            return true
        end
    end
    return false
end

function testGear.applyWeaponOverride(profile, weaponOverride, player)
    local wKey = testGear.resolveWeaponKey(weaponOverride)
    if wKey == nil then
        return false, string.format('Unknown weapon type: %s', tostring(weaponOverride))
    end

    local info = testGear.WEAPON_INFO[wKey]
    if info == nil then
        return false, string.format('Unsupported weapon type: %s', tostring(weaponOverride))
    end

    if player ~= nil and not testGear.isWeaponAllowedForJob(player, wKey) then
        if player:getMainJob() == ((xi.job and xi.job.MNK) or 2) then
            local activeSpec = testGear.getActiveSpecKey(player, player:getMainJob())
            if activeSpec == 'blackbelt' then
                return false, 'MNK Black Belt can only wield Hand-to-Hand weapons.'
            elseif activeSpec == 'chiweaver' then
                return false, 'MNK Chi Weaver fights unarmed and cannot equip weapons.'
            end
        end
        return false, string.format('%s cannot use %s weapons.', spec and spec.getJobName(player:getMainJob()) or 'Your job', info.label)
    end

    -- Ranged weapon overrides adjust ranged + ammo while preserving mainhand
    if wKey == 'bow' then
        profile.ranged = 'bow'
        profile.ammo   = 'arrow'
        profile.label  = profile.label .. ' [Bow]'
        return true, nil
    elseif wKey == 'crossbow' then
        profile.ranged = 'crossbow'
        profile.ammo   = 'bolt'
        profile.label  = profile.label .. ' [Crossbow]'
        return true, nil
    elseif wKey == 'gun' then
        profile.ranged = 'gun'
        profile.ammo   = 'bullet'
        profile.label  = profile.label .. ' [Gun]'
        return true, nil
    elseif wKey == 'throwing' then
        profile.ranged = 'throwing'
        profile.ammo   = 'none'
        profile.label  = profile.label .. ' [Throwing]'
        return true, nil
    elseif wKey == 'chakram' then
        if player and player:getMainJob() == (xi.job and xi.job.DNC or 19) then
            profile.ranged = 'chakram_dnc'
        else
            profile.ranged = 'throwing'
        end
        profile.ammo  = 'none'
        profile.label = profile.label .. ' [Chakram]'
        return true, nil
    elseif wKey == 'shuriken' then
        profile.ranged = 'none'
        profile.ammo   = 'shuriken'
        profile.label  = profile.label .. ' [Shuriken]'
        return true, nil
    end

    local jobId = player and player:getMainJob() or 1
    local blmJob = (xi.job and xi.job.BLM) or 4

    -- Mainhand weapon override
    if (wKey == 'scythe' or wKey == 'scythe_blm') and jobId == blmJob then
        profile.weapon = 'scythe_blm'
    elseif wKey == 'club' and profile.role == 'caster' then
        profile.weapon = 'club_mage'
    elseif wKey == 'staff' and profile.role == 'caster' then
        profile.weapon = 'staff_mage'
    else
        profile.weapon = wKey
    end

    if info.isH2H then
        profile.offhand = 'none'
    elseif info.twoHand then
        if profile.role == 'tank' then
            profile.offhand = 'grip_tank'
        elseif profile.role == 'caster' then
            profile.offhand = 'grip_caster'
        else
            profile.offhand = 'grip_melee'
        end
    else
        if profile.role == 'tank' then
            profile.offhand = 'shield'
        else
            profile.offhand = 'auto'
        end
    end

    profile.label = string.format('%s [%s]', profile.label, info.label)
    return true, nil
end

function testGear.buildLoadout(player, opts)
    opts = opts or {}
    if player == nil then
        return nil, 'Invalid player.'
    end

    if spec and spec.ensureUpToDate then
        spec.ensureUpToDate(player)
    end

    local mainLvl = player.getMainLvl and player:getMainLvl() or 1
    local targetLevel = tonumber(opts.level) or mainLvl
    targetLevel = math.max(1, math.min(99, math.floor(targetLevel)))

    local profile = testGear.getDefaultProfile(player, player:getMainJob(), targetLevel)

    if opts.role ~= nil then
        local rKey = testGear.resolveRoleKey(opts.role)
        if rKey == nil then
            return nil, string.format('Unknown gear set/role: %s (use tp, ws, tank, ranged, or caster)', tostring(opts.role))
        end
        profile.role  = rKey
        if rKey == 'ws' and (profile.ammo == 'ammo_tp' or profile.ammo == 'ammo_melee') then
            profile.ammo = 'ammo_ws'
        elseif rKey == 'tp' and profile.ammo == 'ammo_ws' then
            profile.ammo = 'ammo_tp'
        end
        profile.label = string.format('%s [%s]', profile.label, testGear.ROLE_LABELS[rKey] or string.upper(rKey))
    end

    if opts.weapon ~= nil then
        local ok, err = testGear.applyWeaponOverride(profile, opts.weapon, player)
        if not ok then
            return nil, err
        end
    end

    local slots = {}
    local slotEnum = xi.slot or
    {
        MAIN = 0, SUB = 1, RANGED = 2, AMMO = 3,
        HEAD = 4, BODY = 5, HANDS = 6, LEGS = 7, FEET = 8,
        NECK = 9, WAIST = 10, EAR1 = 11, EAR2 = 12,
        RING1 = 13, RING2 = 14, BACK = 15,
    }

    -- 1. Mainhand Weapon
    local weaponPool = testGear.WEAPONS[profile.weapon]
    local mainItem = testGear.pickFromPool(player, weaponPool, targetLevel, { weaponKey = profile.weapon })
    if mainItem == nil and profile.weapon == 'club_mage' then
        mainItem = testGear.pickFromPool(player, testGear.WEAPONS.club, targetLevel, { weaponKey = 'club' })
    elseif mainItem == nil and profile.weapon == 'staff_mage' then
        mainItem = testGear.pickFromPool(player, testGear.WEAPONS.staff, targetLevel, { weaponKey = 'staff' })
    elseif mainItem == nil and profile.weapon == 'gaxe' then
        mainItem = testGear.pickFromPool(player, testGear.WEAPONS.axe, targetLevel, { weaponKey = 'axe' })
    elseif mainItem == nil and profile.weapon == 'gsword' then
        mainItem = testGear.pickFromPool(player, testGear.WEAPONS.sword, targetLevel, { weaponKey = 'sword' })
    elseif mainItem == nil and profile.weapon == 'gkatana' then
        mainItem = testGear.pickFromPool(player, testGear.WEAPONS.sword, targetLevel, { weaponKey = 'sword' })
    end
    slots[slotEnum.MAIN] = mainItem

    -- 2. Sub Slot (Grip, Shield, or Dual-Wield Offhand)
    local subItem = nil
    local wInfo = testGear.WEAPON_INFO[profile.weapon]
    if mainItem ~= nil and profile.offhand ~= 'none' then
        if wInfo and wInfo.twoHand then
            local gripPool = testGear.SUBS[profile.offhand] or testGear.SUBS.grip_melee
            subItem = testGear.pickFromPool(player, gripPool, targetLevel)
        elseif wInfo and not wInfo.isH2H then
            if profile.offhand == 'auto' and hasDualWield(player) then
                subItem = testGear.pickFromPool(player, weaponPool, targetLevel, { excludeId = mainItem.id, weaponKey = profile.weapon })
            end
            if subItem == nil then
                subItem = testGear.pickFromPool(player, testGear.SUBS.shield, targetLevel)
            end
        end
    end
    slots[slotEnum.SUB] = subItem

    -- 3. Ranged & Ammo Slots
    local rangedItem = nil
    local ammoItem   = nil
    if profile.ranged ~= nil and profile.ranged ~= 'none' then
        local rPool = testGear.RANGED[profile.ranged]
        rangedItem = testGear.pickFromPool(player, rPool, targetLevel)
        if rangedItem == nil and profile.ranged == 'chakram_dnc' then
            rangedItem = testGear.pickFromPool(player, testGear.RANGED.throwing, targetLevel)
        end
    end

    if rangedItem ~= nil then
        slots[slotEnum.RANGED] = rangedItem
        if profile.ammo ~= nil and profile.ammo ~= 'none' then
            ammoItem = testGear.pickFromPool(player, testGear.AMMO[profile.ammo], targetLevel)
        end
        slots[slotEnum.AMMO] = ammoItem
    else
        slots[slotEnum.RANGED] = nil
        local ammoKey = profile.ammo
        if ammoKey == nil or ammoKey == 'none' or ammoKey == 'arrow' or ammoKey == 'bolt' or ammoKey == 'bullet' or ammoKey == 'ammo_melee' then
            if profile.role == 'caster' then
                ammoKey = 'ammo_caster'
            elseif profile.role == 'tank' then
                ammoKey = 'ammo_tank'
            elseif profile.role == 'ws' then
                ammoKey = 'ammo_ws'
            else
                ammoKey = 'ammo_tp'
            end
        end
        ammoItem = testGear.pickFromPool(player, testGear.AMMO[ammoKey], targetLevel)
        if ammoItem == nil and ammoKey == 'orphic_egg' then
            ammoItem = testGear.pickFromPool(player, testGear.AMMO.ammo_caster, targetLevel)
        end
        if ammoItem == nil and ammoKey == 'ammo_ws' then
            ammoItem = testGear.pickFromPool(player, testGear.AMMO.ammo_tp, targetLevel)
        end
        slots[slotEnum.AMMO] = ammoItem
    end

    -- 4. 5-Piece Armor + 7 Accessories
    local roleGear = testGear.ROLE_GEAR[profile.role] or testGear.ROLE_GEAR.tp
    slots[slotEnum.HEAD]  = testGear.pickFromPool(player, roleGear.HEAD,  targetLevel)
    slots[slotEnum.BODY]  = testGear.pickFromPool(player, roleGear.BODY,  targetLevel)
    slots[slotEnum.HANDS] = testGear.pickFromPool(player, roleGear.HANDS, targetLevel)
    slots[slotEnum.LEGS]  = testGear.pickFromPool(player, roleGear.LEGS,  targetLevel)
    slots[slotEnum.FEET]  = testGear.pickFromPool(player, roleGear.FEET,  targetLevel)
    slots[slotEnum.NECK]  = testGear.pickFromPool(player, roleGear.NECK,  targetLevel)
    slots[slotEnum.WAIST] = testGear.pickFromPool(player, roleGear.WAIST, targetLevel)
    slots[slotEnum.BACK]  = testGear.pickFromPool(player, roleGear.BACK,  targetLevel)

    local ear1 = testGear.pickFromPool(player, roleGear.EAR, targetLevel)
    local ear2 = testGear.pickFromPool(player, roleGear.EAR, targetLevel, { excludeId = ear1 and ear1.id or nil })
    slots[slotEnum.EAR1] = ear1
    slots[slotEnum.EAR2] = ear2

    local ring1 = testGear.pickFromPool(player, roleGear.RING, targetLevel)
    local ring2 = testGear.pickFromPool(player, roleGear.RING, targetLevel, { excludeId = ring1 and ring1.id or nil })
    slots[slotEnum.RING1] = ring1
    slots[slotEnum.RING2] = ring2

    return
    {
        level   = targetLevel,
        profile = profile,
        slots   = slots,
    }, nil
end

-----------------------------------
-- Inventory & Auto-Equip Execution
-----------------------------------
local function findOwnedContainer(player, itemId)
    if player == nil or not player.hasItem then
        return nil
    end
    for _, containerId in ipairs(EQUIP_CONTAINERS) do
        if player:hasItem(itemId, containerId) then
            return containerId
        end
    end
    return nil
end

function testGear.ensureBagSpace(player, neededSlots)
    if player == nil then
        return 0
    end
    local invId = (xi.inv and xi.inv.INVENTORY) or 0
    local free = player.getFreeSlotsCount and player:getFreeSlotsCount(invId) or 0
    if free < neededSlots and player.getContainerSize and player.changeContainerSize then
        local curSize = player:getContainerSize(invId) or 30
        if curSize < 80 then
            local delta = 80 - curSize
            player:changeContainerSize(invId, delta)
            free = player:getFreeSlotsCount(invId) or 0
        end
    end
    return free
end

function testGear.equipLoadout(player, opts)
    opts = opts or {}
    if player == nil then
        return nil, 'Invalid player.'
    end

    -- Optional level change before building/equipping loadout
    if opts.setLevel and opts.level ~= nil and player.setLevel then
        local targetLvl = math.max(1, math.min(99, math.floor(tonumber(opts.level) or 1)))
        if player:getMainLvl() ~= targetLvl then
            player:setLevel(targetLvl)
        end
        if spec and spec.ensureUpToDate then
            spec.ensureUpToDate(player)
        end
    end

    local loadout, err = testGear.buildLoadout(player, opts)
    if loadout == nil then
        return nil, err
    end

    local slotEnum = xi.slot or
    {
        MAIN = 0, SUB = 1, RANGED = 2, AMMO = 3,
        HEAD = 4, BODY = 5, HANDS = 6, LEGS = 7, FEET = 8,
        NECK = 9, WAIST = 10, EAR1 = 11, EAR2 = 12,
        RING1 = 13, RING2 = 14, BACK = 15,
    }
    local invId = (xi.inv and xi.inv.INVENTORY) or 0

    local toAddCount = 0
    for slotId = 0, 15 do
        local entry = loadout.slots[slotId]
        if entry ~= nil and findOwnedContainer(player, entry.id) == nil then
            toAddCount = toAddCount + 1
        end
    end

    testGear.ensureBagSpace(player, toAddCount + 2)

    -- Unequip SUB, RANGED, and AMMO first so 1H<->2H and Bow<->Thrown/Ammo transitions never conflict
    if player.unequipItem then
        player:unequipItem(slotEnum.SUB)
        player:unequipItem(slotEnum.AMMO)
        player:unequipItem(slotEnum.RANGED)
        if loadout.slots[slotEnum.MAIN] == nil then
            player:unequipItem(slotEnum.MAIN)
        end
    end

    local equipOrder =
    {
        slotEnum.MAIN,
        slotEnum.SUB,
        slotEnum.RANGED,
        slotEnum.AMMO,
        slotEnum.HEAD,
        slotEnum.BODY,
        slotEnum.HANDS,
        slotEnum.LEGS,
        slotEnum.FEET,
        slotEnum.NECK,
        slotEnum.WAIST,
        slotEnum.EAR1,
        slotEnum.EAR2,
        slotEnum.RING1,
        slotEnum.RING2,
        slotEnum.BACK,
    }

    local addedCount    = 0
    local equippedCount = 0
    local mainLvl       = player.getMainLvl and player:getMainLvl() or 1

    for _, slotId in ipairs(equipOrder) do
        local entry = loadout.slots[slotId]
        if entry ~= nil then
            local containerId = findOwnedContainer(player, entry.id)
            local qty = tonumber(entry.qty) or 1

            if qty > 1 and (not player.hasItem or not player:hasItem(entry.id, invId)) then
                containerId = nil
            end

            if containerId == nil then
                local added = player:addItem(entry.id, qty, true)
                if added then
                    addedCount = addedCount + 1
                    containerId = invId
                end
            end

            if containerId ~= nil and opts.equip ~= false and entry.lvl <= mainLvl then
                player:equipItem(entry.id, containerId, slotId)
                equippedCount = equippedCount + 1
            end
        end
    end

    if opts.capSkills ~= false and player.capAllSkills then
        player:capAllSkills()
    end
    if player.recalculateSkillsTable then
        player:recalculateSkillsTable()
    end

    loadout.addedCount    = addedCount
    loadout.equippedCount = equippedCount
    return loadout, nil
end

return testGear

