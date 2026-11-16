-----------------------------------
-- OverlordsXI Test Gear Resolver & Loadout Engine
-- Grants and equips level-appropriate 16-slot gear sets tailored to the
-- player's main job, active OverlordsXI crystal spec, role, and weapon type.
-----------------------------------
require('modules/custom/lua/overlords_job_specs')
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.testGear = xi.overlords.testGear or {}

local testGear = xi.overlords.testGear
local spec     = xi.overlords.spec

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

-- Vanilla BLM-equippable scythes usable without Lv.10+ Necromancer crystal
local VANILLA_BLM_SCYTHES =
{
    [16779] = true, -- Pitchfork
    [16780] = true, -- Pitchfork +1
    [16797] = true, -- Ark Scythe
}

-----------------------------------
-- Weapon Type Metadata & Aliases
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
    polearm    = { key = 'polearm',    label = 'Polearm',      skill = 8,  twoHand = true,  isH2H = false, isRanged = false },
    katana     = { key = 'katana',     label = 'Katana',       skill = 9,  twoHand = false, isH2H = false, isRanged = false },
    gkatana    = { key = 'gkatana',    label = 'Great Katana', skill = 10, twoHand = true,  isH2H = false, isRanged = false },
    club       = { key = 'club',       label = 'Club (Melee)', skill = 11, twoHand = false, isH2H = false, isRanged = false },
    club_mage  = { key = 'club_mage',  label = 'Club (Caster)',skill = 11, twoHand = false, isH2H = false, isRanged = false },
    staff      = { key = 'staff',      label = 'Staff (Tank)', skill = 12, twoHand = true,  isH2H = false, isRanged = false },
    staff_mage = { key = 'staff_mage', label = 'Staff (Mage)', skill = 12, twoHand = true,  isH2H = false, isRanged = false },
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
    club_mage    = 'club_mage',
    staff        = 'staff',
    pole_staff   = 'staff',
    staff_mage   = 'staff_mage',
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
    melee      = 'melee',
    dps        = 'melee',
    dd         = 'melee',
    tank       = 'tank',
    def        = 'tank',
    defense    = 'tank',
    mitigation = 'tank',
    ranged     = 'ranged',
    rng        = 'ranged',
    shooter    = 'ranged',
    caster     = 'caster',
    mage       = 'caster',
    magic      = 'caster',
    healer     = 'caster',
    nuker      = 'caster',
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
-- Weapon & Offhand Progression Pools
-----------------------------------
testGear.WEAPONS =
{
    h2h =
    {
        { id = 21535, lvl = 99, name = 'Varga Purnikawa' },
        { id = 21519, lvl = 99, name = 'Karambit' },
        { id = 21510, lvl = 99, name = 'Voluspa Knuckles' },
        { id = 18264, lvl = 75, name = 'Spharai' },
        { id = 18759, lvl = 71, name = 'Shlng. Baghnakhs' },
        { id = 17481, lvl = 75, name = 'Kaiser Knuckles' },
        { id = 18749, lvl = 70, name = 'Hades Sainti +1' },
        { id = 18364, lvl = 70, name = 'Pahluwan Katars' },
        { id = 16408, lvl = 70, name = 'Rune Baghnakhs' },
        { id = 18760, lvl = 69, name = 'Useshi' },
        { id = 17504, lvl = 60, name = 'Pagures' },
        { id = 18742, lvl = 60, name = 'Puppet Claws' },
        { id = 17473, lvl = 52, name = 'Torama Cesti' },
        { id = 16694, lvl = 50, name = 'Tct.mag. Hooks' },
        { id = 17503, lvl = 46, name = 'Exocets' },
        { id = 16699, lvl = 40, name = 'Himantes +1' },
        { id = 17510, lvl = 39, name = 'Vampiric Claws' },
        { id = 17515, lvl = 30, name = 'Hydro Claws +1' },
        { id = 16700, lvl = 27, name = 'Poison Cesti +1' },
        { id = 16437, lvl = 20, name = 'Metal Knuckles +1' },
        { id = 16702, lvl = 20, name = 'Cougar Baghnakhs' },
        { id = 17519, lvl = 20, name = 'Platoon Cesti' },
        { id = 16433, lvl = 10, name = 'Lgn. Knuckles' },
        { id = 16690, lvl =  1, name = 'Cesti +1' },
        { id = 17476, lvl =  1, name = 'Cat Baghnakhs +1' },
        { id = 20533, lvl =  1, name = 'Worm Feelers +1' },
    },
    dagger =
    {
        { id = 21590, lvl = 99, name = 'Mpu Gandring' },
        { id = 21565, lvl = 99, name = 'Tauret' },
        { id = 21567, lvl = 99, name = 'Gletis Knife' },
        { id = 21585, lvl = 99, name = 'Crepuscular Knife' },
        { id = 21564, lvl = 99, name = 'Kaja Knife' },
        { id = 20604, lvl = 99, name = 'Ternion Dagger +1' },
        { id = 20615, lvl = 99, name = 'Levante Dagger' },
        { id = 18270, lvl = 75, name = 'Mandau' },
        { id = 18269, lvl = 75, name = 'Batardeau' },
        { id = 19107, lvl = 74, name = 'Azoth' },
        { id = 19118, lvl = 75, name = 'Machismo' },
        { id = 18002, lvl = 73, name = 'Perseuss Harpe' },
        { id = 18024, lvl = 73, name = 'Jambiya +1' },
        { id = 18021, lvl = 72, name = 'Titans Baselarde' },
        { id = 17629, lvl = 70, name = 'Behem. Knife +1' },
        { id = 18019, lvl = 72, name = 'Xs Knife' },
        { id = 17620, lvl = 71, name = 'Misericorde +1' },
        { id = 17628, lvl = 70, name = 'Behemoth Knife' },
        { id = 16452, lvl = 71, name = 'Misericorde' },
        { id = 17619, lvl = 70, name = 'Daylight Dagger' },
        { id = 18027, lvl = 70, name = 'Palladium Dagger' },
        { id = 17609, lvl = 60, name = 'Cermet Knife +1' },
        { id = 16763, lvl = 59, name = 'Darksteel Kukri +1' },
        { id = 16469, lvl = 60, name = 'Cermet Knife' },
        { id = 16760, lvl = 57, name = 'Darksteel Kris +1' },
        { id = 17989, lvl = 57, name = 'Spark Kris +1' },
        { id = 16758, lvl = 55, name = 'Dst. Baselard +1' },
        { id = 17618, lvl = 56, name = 'Kidney Dagger' },
        { id = 16757, lvl = 50, name = 'Corsairs Knife' },
        { id = 17611, lvl = 46, name = 'Bone Knife +1' },
        { id = 16765, lvl = 51, name = 'Lust Dagger' },
        { id = 17980, lvl = 48, name = 'Hornetneedle' },
        { id = 18035, lvl = 46, name = 'Deathbone Knife' },
        { id = 19114, lvl = 49, name = 'Galkan Dagger' },
        { id = 16484, lvl = 45, name = 'Burglars Dagger' },
        { id = 16764, lvl = 40, name = 'Marauders Knife' },
        { id = 17607, lvl = 40, name = 'Corrosive Baselard' },
        { id = 16463, lvl = 40, name = 'Cmb.cst. Dagger' },
        { id = 16766, lvl = 40, name = 'Paper Knife' },
        { id = 18012, lvl = 40, name = 'Melt Baselard' },
        { id = 16487, lvl = 38, name = 'Minstrels Dagger' },
        { id = 18007, lvl = 38, name = 'Chiroptera Dagger' },
        { id = 17979, lvl = 34, name = 'Federation Kukri' },
        { id = 19106, lvl = 30, name = 'Thugs Jambiya +1' },
        { id = 16747, lvl = 30, name = 'Mrc.cpt. Kukri' },
        { id = 16744, lvl = 30, name = 'Ryl.sqr. Dagger' },
        { id = 19105, lvl = 30, name = 'Thugs Jambiya' },
        { id = 17631, lvl = 30, name = 'Hawkers Knife +1' },
        { id = 17630, lvl = 30, name = 'Hawkers Knife' },
        { id = 16497, lvl = 30, name = 'Sleep Dagger' },
        { id = 16749, lvl = 27, name = 'Kris +1' },
        { id = 16746, lvl = 20, name = 'Mercenarys Knife' },
        { id = 16745, lvl = 20, name = 'Decurions Dagger' },
        { id = 16748, lvl = 20, name = 'Kukri +1' },
        { id = 17993, lvl = 20, name = 'Platoon Dagger' },
        { id = 16741, lvl = 20, name = 'Poison Dagger +1' },
        { id = 16740, lvl =  9, name = 'Brass Dagger +1' },
        { id = 18029, lvl =  9, name = 'Piercing Dagger' },
        { id = 16490, lvl =  7, name = 'Blind Knife +1' },
        { id = 16471, lvl =  7, name = 'Blind Knife' },
        { id = 16491, lvl =  1, name = 'Bronze Knife +1' },
        { id = 16492, lvl =  1, name = 'Bronze Dagger +1' },
        { id = 16465, lvl =  1, name = 'Bronze Knife' },
        { id = 16448, lvl =  1, name = 'Bronze Dagger' },
        { id = 20568, lvl =  1, name = 'Wind Knife +1' },
        { id = 20593, lvl =  1, name = 'Hedron Dagger' },
    },
    sword =
    {
        { id = 20673, lvl = 99, name = 'Flametongue' },
        { id = 21621, lvl = 99, name = 'Naegling' },
        { id = 21620, lvl = 99, name = 'Kaja Sword' },
        { id = 21640, lvl = 99, name = 'Onion Sword Iii' },
        { id = 20699, lvl = 99, name = 'Koboto' },
        { id = 20717, lvl = 99, name = 'Arendsi Fleuret' },
        { id = 21602, lvl = 99, name = 'Onion Sword Iii' },
        { id = 18276, lvl = 75, name = 'Excalibur' },
        { id = 17759, lvl = 72, name = 'Koggelmander' },
        { id = 17755, lvl = 75, name = 'Beast Slayer' },
        { id = 17751, lvl = 74, name = 'Fragarach' },
        { id = 17719, lvl = 73, name = 'Mensur Epee' },
        { id = 17659, lvl = 74, name = 'Seiryus Sword' },
        { id = 17711, lvl = 72, name = 'Shivas Shotel' },
        { id = 17685, lvl = 73, name = 'Lex Talionis' },
        { id = 17637, lvl = 69, name = 'Wing Sword +1' },
        { id = 17662, lvl = 70, name = 'Company Sword' },
        { id = 16555, lvl = 70, name = 'Ridill' },
        { id = 16563, lvl = 70, name = 'Rune Blade' },
        { id = 17661, lvl = 70, name = 'Storm Scimitar' },
        { id = 16619, lvl = 68, name = 'Epee +1' },
        { id = 17665, lvl = 65, name = 'Ifrits Blade' },
        { id = 16542, lvl = 69, name = 'Wing Sword' },
        { id = 17737, lvl = 69, name = 'Corsairs Scimitar' },
        { id = 17652, lvl = 70, name = 'Joyeuse' },
        { id = 17722, lvl = 65, name = 'Phantom Fleuret' },
        { id = 17632, lvl = 65, name = 'Colichemarde +1' },
        { id = 16831, lvl = 60, name = 'Greed Scimitar' },
        { id = 17709, lvl = 60, name = 'Swan Bilbo' },
        { id = 16828, lvl = 60, name = 'Bastard Sword +1' },
        { id = 16577, lvl = 60, name = 'Bastard Sword' },
        { id = 17718, lvl = 60, name = 'Leech Scimitar' },
        { id = 17647, lvl = 59, name = 'Aramiss Rapier' },
        { id = 16809, lvl = 55, name = 'Wis.wiz. Anelace' },
        { id = 16825, lvl = 59, name = 'Cermet Sword +1' },
        { id = 16618, lvl = 60, name = 'Mailbreaker +1' },
        { id = 16514, lvl = 60, name = 'Mailbreaker' },
        { id = 16810, lvl = 50, name = 'Tct.mag. Espadon' },
        { id = 17726, lvl = 50, name = 'Immortals Shotel' },
        { id = 16571, lvl = 50, name = 'T.k. Army Sword' },
        { id = 16529, lvl = 50, name = 'Musketeers Sword' },
        { id = 16822, lvl = 49, name = 'Crimson Blade' },
        { id = 16804, lvl = 47, name = 'Flame Blade +1' },
        { id = 17706, lvl = 47, name = 'Vulcan Blade' },
        { id = 16817, lvl = 45, name = 'Holy Degen +1' },
        { id = 16533, lvl = 45, name = 'Ancient Sword' },
        { id = 16807, lvl = 40, name = 'Cmb.cst. Scimitar' },
        { id = 17667, lvl = 43, name = 'Jr.msk. Tuck +2' },
        { id = 17666, lvl = 43, name = 'Jr.msk. Tuck +1' },
        { id = 17717, lvl = 40, name = 'Immortals Scimitar' },
        { id = 17696, lvl = 40, name = 'Buzzard Tuck' },
        { id = 16823, lvl = 40, name = 'Flame Degen +1' },
        { id = 17705, lvl = 40, name = 'Vulcan Degen' },
        { id = 17693, lvl = 39, name = 'Grudge Sword' },
        { id = 16516, lvl = 40, name = 'Jr.msk. Tuck' },
        { id = 16826, lvl = 38, name = 'Divine Sword +1' },
        { id = 17673, lvl = 34, name = 'Republic Sword' },
        { id = 16636, lvl = 36, name = 'Tulwar +1' },
        { id = 16806, lvl = 30, name = 'Centurions Sword' },
        { id = 17740, lvl = 30, name = 'Steel Kilij +1' },
        { id = 16803, lvl = 30, name = 'Fleuret +1' },
        { id = 16634, lvl = 30, name = 'Broadsword +1' },
        { id = 16545, lvl = 30, name = 'Broadsword' },
        { id = 16819, lvl = 28, name = 'Mithran Scimitar' },
        { id = 16608, lvl = 27, name = 'Gladiator' },
        { id = 16532, lvl = 27, name = 'Gladius' },
        { id = 17650, lvl = 24, name = 'Nadrs' },
        { id = 16617, lvl = 23, name = 'Tuck +1' },
        { id = 16513, lvl = 23, name = 'Tuck' },
        { id = 17708, lvl = 19, name = 'Auriga Xiphos' },
        { id = 16633, lvl = 20, name = 'Degen +1' },
        { id = 17692, lvl = 20, name = 'Platoon Spatha' },
        { id = 16517, lvl = 20, name = 'Degen' },
        { id = 16629, lvl = 19, name = 'Small Sword' },
        { id = 16621, lvl = 18, name = 'Flame Sword' },
        { id = 17679, lvl = 15, name = 'Kingdom Sword' },
        { id = 16625, lvl = 13, name = 'Scimitar +1' },
        { id = 16552, lvl = 13, name = 'Scimitar' },
        { id = 17687, lvl = 13, name = 'Spark Bilbo +1' },
        { id = 16544, lvl = 10, name = 'Ryl.arc. Sword' },
        { id = 16627, lvl =  9, name = 'Spatha +1' },
        { id = 16801, lvl =  7, name = 'Sapara +1' },
        { id = 16624, lvl =  7, name = 'Xiphos +1' },
        { id = 16551, lvl =  7, name = 'Sapara' },
        { id = 16610, lvl =  1, name = 'Wax Sword +1' },
        { id = 16623, lvl =  1, name = 'Bronze Sword +1' },
        { id = 16534, lvl =  1, name = 'Onion Sword' },
        { id = 17749, lvl =  1, name = 'Ibushi Shinai +1' },
        { id = 20714, lvl =  1, name = 'Excalipoor Ii' },
    },
    gsword =
    {
        { id = 21674, lvl = 99, name = 'Nandaka' },
        { id = 18282, lvl = 75, name = 'Ragnarok' },
        { id = 20784, lvl = 75, name = 'Uruz Blade +1' },
        { id = 16942, lvl = 70, name = 'Balmung' },
        { id = 18371, lvl = 69, name = 'Gust Tongue +1' },
        { id = 18387, lvl = 70, name = 'Djinnbringer' },
        { id = 16616, lvl = 60, name = 'Zweihander +1' },
        { id = 19150, lvl = 50, name = 'Cobra Claymore' },
        { id = 16601, lvl = 40, name = 'Ryl.swd. Blade' },
        { id = 16937, lvl = 39, name = 'Icicle Sword' },
        { id = 16947, lvl = 25, name = 'Federation Sword' },
        { id = 16930, lvl = 20, name = 'Mrc. Greatsword' },
        { id = 18367, lvl = 10, name = 'Gust Claymore +1' },
        { id = 20781, lvl =  1, name = 'Sowilo Claymore' },
        { id = 16607, lvl =  1, name = 'Chaosbringer' },
        { id = 21682, lvl =  1, name = 'Lament' },
    },
    axe =
    {
        { id = 21722, lvl = 99, name = 'Dolichenus' },
        { id = 21721, lvl = 99, name = 'Kaja Axe' },
        { id = 18288, lvl = 75, name = 'Guttler' },
        { id = 17928, lvl = 70, name = 'Juggernaut' },
        { id = 17958, lvl = 71, name = 'Iron Ram Pick' },
        { id = 17938, lvl = 72, name = 'Woodvilles Axe' },
        { id = 17939, lvl = 70, name = 'Kriegsbeil' },
        { id = 16647, lvl = 70, name = 'Rune Axe' },
        { id = 17950, lvl = 70, name = 'Marid Ancus' },
        { id = 16684, lvl = 59, name = 'Kabrakans Axe' },
        { id = 17965, lvl = 60, name = 'Sirocco Axe' },
        { id = 17924, lvl = 60, name = 'Tungi' },
        { id = 16676, lvl = 48, name = 'Viking Axe' },
        { id = 16670, lvl = 50, name = 'Mythril Pick +1' },
        { id = 17932, lvl = 43, name = 'Cmb.cst. Axe +2' },
        { id = 16678, lvl = 40, name = 'Razor Axe' },
        { id = 16669, lvl = 40, name = 'Cmb.cst. Axe' },
        { id = 16680, lvl = 40, name = 'Barbaroi Axe' },
        { id = 16674, lvl = 39, name = 'Emeth Pick' },
        { id = 16665, lvl = 37, name = 'Mythril Axe +1' },
        { id = 17940, lvl = 28, name = 'Military Pick' },
        { id = 17947, lvl = 30, name = 'Garde Pick' },
        { id = 16663, lvl = 20, name = 'Battleaxe +1' },
        { id = 16643, lvl = 20, name = 'Battleaxe' },
        { id = 16648, lvl = 10, name = 'Legionnaires Axe' },
        { id = 16661, lvl =  8, name = 'Brass Axe +1' },
        { id = 16646, lvl =  1, name = 'Bronze Axe +1' },
        { id = 16640, lvl =  1, name = 'Bronze Axe' },
        { id = 21744, lvl =  1, name = 'Gramks Axe' },
        { id = 21745, lvl =  1, name = 'Dullahan Axe' },
    },
    gaxe =
    {
        { id = 21779, lvl = 99, name = 'Lycurgos' },
        { id = 18294, lvl = 75, name = 'Bravura' },
        { id = 18198, lvl = 74, name = 'Byakkos Axe' },
        { id = 18224, lvl = 73, name = 'Toporok +1' },
        { id = 18487, lvl = 68, name = 'Eriks Axe' },
        { id = 18206, lvl = 70, name = 'Rune Chopper' },
        { id = 18205, lvl = 59, name = 'Hydro Chopper +1' },
        { id = 18219, lvl = 50, name = 'Lcs. Voulge +1' },
        { id = 16710, lvl = 49, name = 'Gigant Axe' },
        { id = 16708, lvl = 37, name = 'Horror Voulge' },
        { id = 16721, lvl = 39, name = 'Huge Moth Axe' },
        { id = 16712, lvl = 30, name = 'Centurions Axe' },
        { id = 16714, lvl = 20, name = 'Neckchopper' },
        { id = 16713, lvl =  8, name = 'Hellfire Axe' },
        { id = 21760, lvl =  1, name = 'Dispatchers Axe' },
    },
    scythe =
    {
        { id = 21830, lvl = 99, name = 'Drepanum' },
        { id = 18306, lvl = 75, name = 'Apocalypse' },
        { id = 18043, lvl = 74, name = 'Suzakus Scythe' },
        { id = 18947, lvl = 70, name = 'Molioness Sickle' },
        { id = 18048, lvl = 70, name = 'King Maker' },
        { id = 16788, lvl = 58, name = 'Vassagos Scythe' },
        { id = 18055, lvl = 57, name = 'Ivory Sickle +1' },
        { id = 16786, lvl = 49, name = 'Brb. Scythe' },
        { id = 16771, lvl = 47, name = 'Falcastra' },
        { id = 18046, lvl = 40, name = 'Mutilator' },
        { id = 18953, lvl = 40, name = 'Beluga' },
        { id = 16776, lvl = 30, name = 'Mrc.cpt. Scythe' },
        { id = 16784, lvl = 27, name = 'Frostreaper' },
        { id = 16773, lvl = 20, name = 'Cruel Scythe' },
        { id = 18045, lvl = 20, name = 'Platoon Zaghnal' },
        { id = 16780, lvl = 10, name = 'Lgn. Scythe' },
        { id = 16778, lvl =  1, name = 'Brz. Zaghnal +1' },
        { id = 16779, lvl =  1, name = 'Pitchfork' },
        { id = 21821, lvl =  1, name = 'Lost Sickle +1' },
    },
    polearm =
    {
        { id = 21883, lvl = 99, name = 'Shining One' },
        { id = 18300, lvl = 75, name = 'Gungnir' },
        { id = 18130, lvl = 75, name = 'Dabo +1' },
        { id = 18089, lvl = 70, name = 'Schiltron Spear' },
        { id = 18084, lvl = 70, name = 'Rune Halberd' },
        { id = 16886, lvl = 60, name = 'Gnd.kgt. Lance' },
        { id = 18094, lvl = 60, name = 'Couse +1' },
        { id = 16874, lvl = 57, name = 'Partisan +1' },
        { id = 16851, lvl = 50, name = 'R.k. Army Lance' },
        { id = 18086, lvl = 40, name = 'Behourd Lance' },
        { id = 16891, lvl = 38, name = 'Obelisk Lance +1' },
        { id = 16866, lvl = 36, name = 'Halberd +1' },
        { id = 16844, lvl = 30, name = 'Ryl.sqr. Halberd' },
        { id = 18104, lvl = 20, name = 'Fuscina' },
        { id = 16859, lvl =  7, name = 'Bronze Spear +1' },
        { id = 16862, lvl =  1, name = 'Harpoon +1' },
        { id = 18103, lvl =  1, name = 'Pitchfork +1' },
    },
    katana =
    {
        { id = 21922, lvl = 99, name = 'Gokotai' },
        { id = 21921, lvl = 99, name = 'Kaja Katana' },
        { id = 18312, lvl = 75, name = 'Kikoku' },
        { id = 18311, lvl = 75, name = 'Yoshimitsu' },
        { id = 16904, lvl = 70, name = 'Fudo' },
        { id = 18422, lvl = 70, name = 'Ryumon' },
        { id = 17788, lvl = 60, name = 'Sairen' },
        { id = 16924, lvl = 57, name = 'Hocho' },
        { id = 18411, lvl = 50, name = 'Buboso' },
        { id = 16897, lvl = 50, name = 'Kageboshi' },
        { id = 17787, lvl = 39, name = 'Ohaguro' },
        { id = 17771, lvl = 40, name = 'Anju' },
        { id = 17792, lvl = 30, name = 'Nikkariaoe' },
        { id = 17775, lvl = 28, name = 'Fukuro' },
        { id = 17786, lvl = 20, name = 'Ganko' },
        { id = 16917, lvl = 19, name = 'Suzume' },
        { id = 16918, lvl =  7, name = 'Wakizashi +1' },
        { id = 16900, lvl =  7, name = 'Wakizashi' },
        { id = 16914, lvl =  1, name = 'Kunai +1' },
        { id = 16896, lvl =  1, name = 'Kunai' },
        { id = 21924, lvl =  1, name = 'Debahocho +1' },
        { id = 21934, lvl =  1, name = 'Yagyu Shortblade +1' },
    },
    gkatana =
    {
        { id = 21975, lvl = 99, name = 'Hachimonji' },
        { id = 18318, lvl = 75, name = 'Amanomurakumo' },
        { id = 18440, lvl = 71, name = 'Shirogatana +1' },
        { id = 16968, lvl = 70, name = 'Kamewari' },
        { id = 18434, lvl = 70, name = 'Kosetsusamonji' },
        { id = 17807, lvl = 60, name = 'Gld.msk. Uchigat.' },
        { id = 16965, lvl = 50, name = 'Koryukagemitsu' },
        { id = 17821, lvl = 40, name = 'Kagehide' },
        { id = 16979, lvl = 36, name = 'Ashura +1' },
        { id = 18451, lvl = 30, name = 'Mokusa' },
        { id = 16975, lvl = 26, name = 'Kanesada' },
        { id = 17820, lvl = 20, name = 'Gunromaru' },
        { id = 16978, lvl = 12, name = 'Uchigatana +1' },
        { id = 17811, lvl = 10, name = 'Katayama' },
        { id = 17809, lvl =  1, name = 'Mumeito' },
        { id = 17831, lvl =  1, name = 'Hardwood Katana' },
    },
    club =
    {
        { id = 21102, lvl = 99, name = 'Mafic Cudgel' },
        { id = 22031, lvl = 99, name = 'Maxentius' },
        { id = 22040, lvl = 99, name = 'Daybreak' },
        { id = 21091, lvl = 99, name = 'Loxotic Mace +1' },
        { id = 21101, lvl = 99, name = 'Herkuleskeule' },
        { id = 21104, lvl = 99, name = 'Eosuchus Club' },
        { id = 18874, lvl = 74, name = 'Brise-os +1' },
        { id = 18873, lvl = 74, name = 'Brise-os' },
        { id = 18848, lvl = 71, name = 'Brass Jadagna' },
        { id = 18856, lvl = 74, name = 'Deae Gratia' },
        { id = 18395, lvl = 68, name = 'Seawolf Cudgel' },
        { id = 18850, lvl = 73, name = 'Perdu Wand' },
        { id = 18872, lvl = 73, name = 'Lyft Ferule' },
        { id = 18398, lvl = 75, name = 'Raphaels Rod' },
        { id = 18405, lvl = 69, name = 'Jadagna' },
        { id = 18843, lvl = 68, name = 'Flan Smasher' },
        { id = 17471, lvl = 70, name = 'Horrent Mace' },
        { id = 18862, lvl = 69, name = 'Clearpath' },
        { id = 17436, lvl = 70, name = 'Platinum Rod +1' },
        { id = 18407, lvl = 70, name = 'Imperial Wand' },
        { id = 17465, lvl = 70, name = 'Mighty Cudgel' },
        { id = 17073, lvl = 70, name = 'Mistilteinn' },
        { id = 17438, lvl = 65, name = 'Titans Cudgel' },
        { id = 17427, lvl = 60, name = 'Ebony Wand +1' },
        { id = 17429, lvl = 59, name = 'Dominion Mace' },
        { id = 17054, lvl = 60, name = 'Ebony Wand' },
        { id = 18852, lvl = 63, name = 'Octave Club' },
        { id = 17428, lvl = 57, name = 'Darksteel Mace +1' },
        { id = 17037, lvl = 57, name = 'Darksteel Mace' },
        { id = 17443, lvl = 55, name = 'Thoths Wand' },
        { id = 17082, lvl = 50, name = 'Tct.mag. Wand' },
        { id = 17072, lvl = 50, name = 'Liliths Rod' },
        { id = 17415, lvl = 48, name = 'Shellbuster' },
        { id = 17421, lvl = 45, name = 'Moonwatch Wand' },
        { id = 17408, lvl = 39, name = 'Great Club +1' },
        { id = 17114, lvl = 38, name = 'Holy Maul +1' },
        { id = 17030, lvl = 39, name = 'Great Club' },
        { id = 17463, lvl = 39, name = 'Sealed Mace' },
        { id = 18853, lvl = 38, name = 'Spirit Maul' },
        { id = 17142, lvl = 36, name = 'Oak Cudgel +1' },
        { id = 17027, lvl = 36, name = 'Oak Cudgel' },
        { id = 17150, lvl = 30, name = 'Ryl.sqr. Mace' },
        { id = 17442, lvl = 28, name = 'Eremites Wand +1' },
        { id = 17441, lvl = 28, name = 'Eremites Wand' },
        { id = 17033, lvl = 27, name = 'Bone Cudgel +1' },
        { id = 17026, lvl = 27, name = 'Bone Cudgel' },
        { id = 17115, lvl = 20, name = 'Warhammer +1' },
        { id = 17044, lvl = 20, name = 'Warhammer' },
        { id = 17462, lvl = 20, name = 'Platoon Mace' },
        { id = 17145, lvl = 19, name = 'Mace +1' },
        { id = 17029, lvl = 20, name = 'Bouncer Club' },
        { id = 17140, lvl = 18, name = 'Yew Wand +1' },
        { id = 17139, lvl = 16, name = 'Solid Club' },
        { id = 18394, lvl = 10, name = 'Pilgrims Wand' },
        { id = 17028, lvl = 10, name = 'Freeswords Club' },
        { id = 17417, lvl =  5, name = 'Rabbit Stick' },
        { id = 17137, lvl =  1, name = 'Ash Club +1' },
        { id = 17087, lvl =  1, name = 'Maple Wand +1' },
        { id = 17024, lvl =  1, name = 'Ash Club' },
    },
    club_mage =
    {
        { id = 22040, lvl = 99, name = 'Daybreak' },
        { id = 22042, lvl = 99, name = 'Wizards Rod' },
        { id = 21071, lvl = 99, name = 'Cath Palug Hammer' },
        { id = 22031, lvl = 99, name = 'Maxentius' },
        { id = 22030, lvl = 99, name = 'Kaja Rod' },
        { id = 21104, lvl = 99, name = 'Eosuchus Club' },
        { id = 21102, lvl = 99, name = 'Mafic Cudgel' },
        { id = 18857, lvl = 72, name = 'Antares' },
        { id = 17073, lvl = 70, name = 'Mistilteinn' },
        { id = 17433, lvl = 65, name = 'Mythic Wand +1' },
        { id = 18854, lvl = 71, name = 'Fourth Mace' },
        { id = 18856, lvl = 74, name = 'Deae Gratia' },
        { id = 18841, lvl = 71, name = 'Templar Mace' },
        { id = 18398, lvl = 75, name = 'Raphaels Rod' },
        { id = 18843, lvl = 68, name = 'Flan Smasher' },
        { id = 18862, lvl = 69, name = 'Clearpath' },
        { id = 17427, lvl = 60, name = 'Ebony Wand +1' },
        { id = 17465, lvl = 70, name = 'Mighty Cudgel' },
        { id = 17054, lvl = 60, name = 'Ebony Wand' },
        { id = 17471, lvl = 70, name = 'Horrent Mace' },
        { id = 17438, lvl = 65, name = 'Titans Cudgel' },
        { id = 18852, lvl = 63, name = 'Octave Club' },
        { id = 17082, lvl = 50, name = 'Tct.mag. Wand' },
        { id = 17143, lvl = 48, name = 'Rose Wand +1' },
        { id = 17428, lvl = 57, name = 'Darksteel Mace +1' },
        { id = 17037, lvl = 57, name = 'Darksteel Mace' },
        { id = 17443, lvl = 55, name = 'Thoths Wand' },
        { id = 17415, lvl = 48, name = 'Shellbuster' },
        { id = 17421, lvl = 45, name = 'Moonwatch Wand' },
        { id = 17114, lvl = 38, name = 'Holy Maul +1' },
        { id = 17141, lvl = 32, name = 'Solid Wand' },
        { id = 17408, lvl = 39, name = 'Great Club +1' },
        { id = 18403, lvl = 32, name = 'High Mana Wand' },
        { id = 17030, lvl = 39, name = 'Great Club' },
        { id = 17142, lvl = 36, name = 'Oak Cudgel +1' },
        { id = 17027, lvl = 36, name = 'Oak Cudgel' },
        { id = 17442, lvl = 28, name = 'Eremites Wand +1' },
        { id = 17441, lvl = 28, name = 'Eremites Wand' },
        { id = 17150, lvl = 30, name = 'Ryl.sqr. Mace' },
        { id = 17033, lvl = 27, name = 'Bone Cudgel +1' },
        { id = 17026, lvl = 27, name = 'Bone Cudgel' },
        { id = 17140, lvl = 18, name = 'Yew Wand +1' },
        { id = 17051, lvl = 18, name = 'Yew Wand' },
        { id = 17029, lvl = 20, name = 'Bouncer Club' },
        { id = 17145, lvl = 19, name = 'Mace +1' },
        { id = 17139, lvl = 16, name = 'Solid Club' },
        { id = 17138, lvl =  9, name = 'Willow Wand +1' },
        { id = 18402, lvl =  9, name = 'Mana Wand' },
        { id = 17028, lvl = 10, name = 'Freeswords Club' },
        { id = 17417, lvl =  5, name = 'Rabbit Stick' },
        { id = 17087, lvl =  1, name = 'Maple Wand +1' },
        { id = 17049, lvl =  1, name = 'Maple Wand' },
        { id = 17137, lvl =  1, name = 'Ash Club +1' },
        { id = 17024, lvl =  1, name = 'Ash Club' },
    },
    staff =
    {
        { id = 22087, lvl = 99, name = 'Malignance Pole' },
        { id = 22056, lvl = 99, name = 'Gozuki Mezuki' },
        { id = 18990, lvl = 75, name = 'Tupsimati' },
        { id = 18994, lvl = 75, name = 'Laevateinn' },
        { id = 19005, lvl = 75, name = 'Nirvana' },
        { id = 17568, lvl = 75, name = 'Eight-sd. Pole +1' },
        { id = 17567, lvl = 75, name = 'Kirins Pole' },
        { id = 18595, lvl = 73, name = 'Mekki Shakki' },
        { id = 18582, lvl = 70, name = 'Yigit Staff' },
        { id = 17564, lvl = 69, name = 'Cocytus Pole' },
        { id = 17544, lvl = 60, name = 'Battle Staff +1' },
        { id = 17521, lvl = 59, name = 'Mahogany Pole +1' },
        { id = 17520, lvl = 59, name = 'Heavy Staff' },
        { id = 18633, lvl = 51, name = 'Chatoyant Staff' },
        { id = 17129, lvl = 50, name = 'Musketeers Pole' },
        { id = 17135, lvl = 50, name = 'Walrus Staff' },
        { id = 17524, lvl = 45, name = 'Footmans Staff' },
        { id = 17120, lvl = 40, name = 'Oak Pole +1' },
        { id = 17127, lvl = 39, name = 'Oak Staff +1' },
        { id = 17580, lvl = 33, name = 'Military Pole' },
        { id = 17119, lvl = 30, name = 'Elm Pole +1' },
        { id = 17117, lvl = 30, name = 'Hypno Staff' },
        { id = 17425, lvl = 25, name = 'Spiked Club +1' },
        { id = 17116, lvl = 20, name = 'Misery Staff' },
        { id = 17128, lvl = 10, name = 'Lgn. Staff' },
        { id = 17594, lvl = 10, name = 'Gelong Staff' },
        { id = 17123, lvl =  1, name = 'Ash Staff +1' },
        { id = 21154, lvl =  1, name = 'Malice Masher +1' },
    },
    staff_mage =
    {
        { id = 22062, lvl = 99, name = 'Laevateinn' },
        { id = 22055, lvl = 99, name = 'Oranyan' },
        { id = 22086, lvl = 99, name = 'Xoanon' },
        { id = 21152, lvl = 99, name = 'Reikikon' },
        { id = 22056, lvl = 99, name = 'Gozuki Mezuki' },
        { id = 18593, lvl = 73, name = 'Alkalurops' },
        { id = 17567, lvl = 75, name = 'Kirins Pole' },
        { id = 17599, lvl = 75, name = 'Diaboloss Pole' },
        { id = 17578, lvl = 72, name = 'Zen Pole' },
        { id = 18582, lvl = 70, name = 'Yigit Staff' },
        { id = 17586, lvl = 70, name = 'Mercurial Pole' },
        { id = 17574, lvl = 60, name = 'Archalauss Pole' },
        { id = 17544, lvl = 60, name = 'Battle Staff +1' },
        { id = 18633, lvl = 51, name = 'Chatoyant Staff' },
        { id = 17129, lvl = 50, name = 'Musketeers Pole' },
        { id = 17135, lvl = 50, name = 'Walrus Staff' },
        { id = 17573, lvl = 40, name = 'Himmel Stock' },
        { id = 17524, lvl = 45, name = 'Footmans Staff' },
        { id = 18615, lvl = 39, name = 'Passaddhi Staff +1' },
        { id = 17580, lvl = 33, name = 'Military Pole' },
        { id = 18604, lvl = 27, name = 'Astaroth Cane' },
        { id = 17425, lvl = 25, name = 'Spiked Club +1' },
        { id = 17116, lvl = 20, name = 'Misery Staff' },
        { id = 17128, lvl = 10, name = 'Lgn. Staff' },
        { id = 17594, lvl = 10, name = 'Gelong Staff' },
        { id = 17123, lvl =  1, name = 'Ash Staff +1' },
        { id = 21154, lvl =  1, name = 'Malice Masher +1' },
    },
}

testGear.SUBS =
{
    shield =
    {
        { id = 26403, lvl = 99, name = 'Srivatsa' },
        { id = 26487, lvl = 99, name = 'Sacro Bulwark' },
        { id = 27645, lvl = 99, name = 'Genmei Shield' },
        { id = 26420, lvl = 99, name = 'Adapa Shield' },
        { id = 28654, lvl = 99, name = 'Beatific Shield +1' },
        { id = 26421, lvl = 99, name = 'Nusku Shield' },
        { id = 28657, lvl = 99, name = 'Kaidate' },
        { id = 28658, lvl = 99, name = 'Sors Shield' },
        { id = 16176, lvl = 75, name = 'Simba Buckler' },
        { id = 12296, lvl = 74, name = 'Genbus Shield' },
        { id = 12388, lvl = 73, name = 'Kaiser Shield' },
        { id = 12408, lvl = 71, name = 'Absorbing Shield' },
        { id = 16179, lvl = 71, name = 'Airy Buckler' },
        { id = 16177, lvl = 71, name = 'Legion Scutum' },
        { id = 12361, lvl = 70, name = 'Sipar' },
        { id = 16165, lvl = 70, name = 'Storm Shield' },
        { id = 16181, lvl = 69, name = 'Terror Shield' },
        { id = 16180, lvl = 69, name = 'Harpy Shield' },
        { id = 12382, lvl = 68, name = 'Astral Aspis' },
        { id = 16172, lvl = 60, name = 'Iron Ram Shield' },
        { id = 12363, lvl = 60, name = 'Ptr.prt. Shield' },
        { id = 16187, lvl = 59, name = 'Adoubeurs Pavise' },
        { id = 12317, lvl = 58, name = 'Flame Shield' },
        { id = 12412, lvl = 55, name = 'Hoplon +1' },
        { id = 12380, lvl = 50, name = 'Divine Shield' },
        { id = 12313, lvl = 50, name = 'T.k. Army Shield' },
        { id = 16168, lvl = 50, name = 'Sentinel Shield' },
        { id = 12329, lvl = 48, name = 'Leather Shield +1' },
        { id = 16186, lvl = 42, name = 'Spellcasters Ecu' },
        { id = 12336, lvl = 40, name = 'Ryl.sqr. Shield' },
        { id = 12404, lvl = 40, name = 'Elegant Shield' },
        { id = 12365, lvl = 39, name = 'Nymph Shield +1' },
        { id = 12405, lvl = 38, name = 'Jennet Shield' },
        { id = 16183, lvl = 30, name = 'Nomad Mog. Shield' },
        { id = 12337, lvl = 20, name = 'Decurions Shield' },
        { id = 12334, lvl = 20, name = 'Strong Shield' },
        { id = 12371, lvl =  9, name = 'Clipeus' },
        { id = 12325, lvl =  9, name = 'Aspis +1' },
        { id = 12298, lvl =  9, name = 'Parana Shield' },
        { id = 16185, lvl =  8, name = 'Pelte' },
        { id = 12340, lvl =  1, name = 'Marine Shield' },
        { id = 28651, lvl =  1, name = 'Metal Slime Shield' },
    },
    grip_melee =
    {
        { id = 21417, lvl = 99, name = 'Utu Grip' },
        { id = 18801, lvl = 81, name = 'Danger Grip' },
        { id = 19048, lvl = 74, name = 'Reign Grip' },
        { id = 19029, lvl = 72, name = 'Brave Grip' },
        { id = 19027, lvl = 65, name = 'Claymore Grip' },
        { id = 19025, lvl = 60, name = 'Pole Grip' },
        { id = 19014, lvl = 55, name = 'Mythril Grip +1' },
        { id = 19039, lvl = 50, name = 'Orca Strap' },
        { id = 19010, lvl = 30, name = 'Brass Grip +1' },
        { id = 19044, lvl = 15, name = 'Disciple Grip' },
        { id = 19043, lvl =  5, name = 'Tenax Strap' },
    },
    grip_tank =
    {
        { id = 18802, lvl = 84, name = 'Vallus Grip' },
        { id = 18803, lvl = 83, name = 'Pax Grip' },
        { id = 19040, lvl = 69, name = 'Shark Strap' },
        { id = 19020, lvl = 65, name = 'Platinum Grip +1' },
        { id = 19016, lvl = 55, name = 'Raptor Strap +1' },
        { id = 19012, lvl = 30, name = 'Lizard Strap +1' },
        { id = 19044, lvl = 15, name = 'Disciple Grip' },
        { id = 19043, lvl =  5, name = 'Tenax Strap' },
    },
    grip_caster =
    {
        { id = 19056, lvl = 83, name = 'Elementa Grip' },
        { id = 19051, lvl = 75, name = 'Vivid Strap +1' },
        { id = 19030, lvl = 71, name = 'Wise Strap' },
        { id = 19038, lvl = 70, name = 'Dark Grip' },
        { id = 19028, lvl = 69, name = 'Magic Strap' },
        { id = 19023, lvl = 65, name = 'Staff Strap' },
        { id = 19018, lvl = 60, name = 'Bugard Strap +1' },
        { id = 19047, lvl = 53, name = 'Reaver Grip +1' },
        { id = 19012, lvl = 30, name = 'Lizard Strap +1' },
        { id = 19045, lvl = 19, name = 'Succubus Grip' },
        { id = 19043, lvl =  5, name = 'Tenax Strap' },
    },
}

testGear.RANGED =
{
    bow =
    {
        { id = 22129, lvl = 99, name = 'Yoichinoyumi' },
        { id = 22107, lvl = 99, name = 'Ullr' },
        { id = 18348, lvl = 75, name = 'Yoichinoyumi' },
        { id = 18701, lvl = 75, name = 'Cerberus Bow +1' },
        { id = 17192, lvl = 72, name = 'Ifrits Bow' },
        { id = 19215, lvl = 69, name = 'Amanokakoyumi' },
        { id = 19216, lvl = 69, name = 'Failnaught' },
        { id = 17158, lvl = 73, name = 'Rune Bow' },
        { id = 18714, lvl = 55, name = 'Valis Bow' },
        { id = 17189, lvl = 58, name = 'Rapid Bow +1' },
        { id = 17173, lvl = 50, name = 'War Bow +1' },
        { id = 17182, lvl = 50, name = 'Kaman +1' },
        { id = 17181, lvl = 40, name = 'Battle Bow +1' },
        { id = 17170, lvl = 38, name = 'Speed Bow' },
        { id = 17180, lvl = 30, name = 'Great Bow +1' },
        { id = 17208, lvl = 30, name = 'Hamayumi' },
        { id = 17178, lvl = 16, name = 'Power Bow +1' },
        { id = 17202, lvl = 20, name = 'Platoon Bow' },
        { id = 17167, lvl = 10, name = 'Ryl.arc. Longbow' },
        { id = 17159, lvl = 10, name = 'Freeswords Bow' },
        { id = 17175, lvl =  1, name = 'Shortbow +1' },
    },
    crossbow =
    {
        { id = 22119, lvl = 99, name = 'Wochowsen' },
        { id = 19209, lvl = 99, name = 'Molybdosis' },
        { id = 22167, lvl = 99, name = 'Dathaba Crossbow' },
        { id = 17214, lvl = 74, name = 'Staurobow +1' },
        { id = 17245, lvl = 70, name = 'Grosveneurs Bow' },
        { id = 18684, lvl = 70, name = 'Storm Zamburak' },
        { id = 17227, lvl = 60, name = 'Heavy Crossbow+1' },
        { id = 17226, lvl = 50, name = 'Arbalest +1' },
        { id = 17215, lvl = 40, name = 'Thugs Zamburak' },
        { id = 17229, lvl = 30, name = 'Zamburak +1' },
        { id = 17211, lvl = 20, name = 'Almogavar Bow' },
        { id = 17223, lvl = 10, name = 'Lgn. Crossbow' },
        { id = 17228, lvl =  1, name = 'Light Crossbow +1' },
    },
    gun =
    {
        { id = 22140, lvl = 99, name = 'Annihilator' },
        { id = 22142, lvl = 99, name = 'Armageddon' },
        { id = 21274, lvl = 99, name = 'Donar Gun' },
        { id = 18336, lvl = 75, name = 'Annihilator' },
        { id = 17264, lvl = 70, name = 'Hellfire +1' },
        { id = 19007, lvl = 75, name = 'Death Penalty' },
        { id = 19218, lvl = 69, name = 'Murderer' },
        { id = 18727, lvl = 60, name = 'Fourth Gun' },
        { id = 19227, lvl = 61, name = 'Blunderbuss +1' },
        { id = 18703, lvl = 60, name = 'Shark Gun' },
        { id = 17253, lvl = 50, name = 'Musketeer Gun' },
        { id = 18711, lvl = 50, name = 'Seadog Gun +1' },
        { id = 18702, lvl = 40, name = 'Trump Gun' },
        { id = 17256, lvl = 34, name = 'Serpentine Gun' },
        { id = 18716, lvl = 30, name = 'Marss Hexagun +1' },
        { id = 17272, lvl = 30, name = 'Military Gun' },
        { id = 17271, lvl = 20, name = 'Platoon Gun' },
        { id = 19225, lvl =  6, name = 'Musketoon +1' },
    },
    throwing =
    {
        { id = 22267, lvl = 99, name = 'Antitail +1' },
        { id = 21390, lvl = 99, name = 'Albin Bane' },
        { id = 21368, lvl = 75, name = 'Bestas Bane' },
        { id = 18709, lvl = 75, name = 'Snakeeye +1' },
        { id = 18141, lvl = 70, name = 'Ungur Boomerang' },
        { id = 17295, lvl = 68, name = 'Rising Sun +1' },
        { id = 17294, lvl = 55, name = 'Comet Tail' },
        { id = 17279, lvl = 57, name = 'Moonring Blade +1' },
        { id = 17293, lvl = 47, name = 'Yagudo Freezer' },
        { id = 18135, lvl = 43, name = 'Jr.msk.chakram +2' },
        { id = 17283, lvl = 40, name = 'Jr.msk. Chakram' },
        { id = 17282, lvl = 40, name = 'Cmb.cst. Bmerang' },
        { id = 17289, lvl = 28, name = 'Chakram +1' },
        { id = 17288, lvl = 24, name = 'Wingedge +1' },
        { id = 18170, lvl = 20, name = 'Platoon Edge' },
        { id = 18171, lvl = 20, name = 'Platoon Disc' },
        { id = 17291, lvl = 19, name = 'Flame Boomerang' },
        { id = 18246, lvl = 10, name = 'Rogetsurin' },
        { id = 17290, lvl =  6, name = 'Coarse Boomerang' },
    },
    chakram_dnc =
    {
        { id = 21368, lvl = 75, name = 'Besta\'s Bane' },
        { id = 18692, lvl = 75, name = 'Mamoolbane' },
        { id = 18694, lvl = 75, name = 'Trollbane' },
        { id = 18693, lvl = 75, name = 'Lamiabane' },
        { id = 21340, lvl = 75, name = 'Halakaala' },
        { id = 17295, lvl = 68, name = 'Rising Sun +1' },
        { id = 18231, lvl = 61, name = 'Death Chakram' },
        { id = 17279, lvl = 57, name = 'Moonring Blade +1' },
        { id = 18135, lvl = 43, name = 'Jr.Msk. Chakram +2' },
        { id = 17283, lvl = 40, name = 'Jr.Msk. Chakram' },
        { id = 17289, lvl = 28, name = 'Chakram +1' },
        { id = 18171, lvl = 20, name = 'Platoon Disc' },
        { id = 18246, lvl = 10, name = 'Rogetsurin' },
    },
    instrument =
    {
        { id = 18832, lvl = 83, name = 'Apollo\'s Flute' },
        { id = 17852, lvl = 72, name = 'Requiem Flute' },
        { id = 17379, lvl = 58, name = 'Hamelin Flute' },
        { id = 17378, lvl = 48, name = 'Angel\'s Flute +1' },
        { id = 17346, lvl = 23, name = 'Siren Flute' },
        { id = 17369, lvl =  4, name = 'Cornette +1' },
        { id = 17372, lvl =  1, name = 'Flute +1' },
    },
    handbell =
    {
        { id = 21372, lvl = 99, name = 'Dunna' },
        { id = 21460, lvl =  1, name = 'Matre Bell' },
    },
    animator =
    {
        { id = 17923, lvl = 87, name = 'Deluxe Animator' },
        { id = 17857, lvl = 71, name = 'Animator +1' },
        { id = 17858, lvl = 40, name = 'Turbo Animator' },
        { id = 17859, lvl =  1, name = 'Animator' },
    },
}

testGear.AMMO =
{
    arrow =
    {
        { id = 21298, lvl = 99, name = 'Artemiss Arrow', qty = 99 },
        { id = 21299, lvl = 99, name = 'Yoichis Arrow', qty = 99 },
        { id = 21309, lvl = 99, name = 'Chapuli Arrow', qty = 99 },
        { id = 17325, lvl = 70, name = 'Kabura Arrow', qty = 99 },
        { id = 18740, lvl = 60, name = 'Cmb.cst. Arrow', qty = 99 },
        { id = 17333, lvl = 70, name = 'Rune Arrow', qty = 99 },
        { id = 18178, lvl = 50, name = 'Bodkin Arrow', qty = 99 },
        { id = 18155, lvl = 40, name = 'Scorpion Arrow', qty = 99 },
        { id = 18156, lvl = 29, name = 'Horn Arrow', qty = 99 },
        { id = 17332, lvl = 15, name = 'Fang Arrow', qty = 99 },
        { id = 17319, lvl =  7, name = 'Bone Arrow', qty = 99 },
        { id = 17318, lvl =  1, name = 'Wooden Arrow', qty = 99 },
        { id = 17330, lvl =  1, name = 'Stone Arrow', qty = 99 },
    },
    bolt =
    {
        { id = 22295, lvl = 99, name = 'Hauksbok Bullet', qty = 99 },
        { id = 21313, lvl = 99, name = 'Gashing Bolt', qty = 99 },
        { id = 18739, lvl = 60, name = 'Irn.msk. Bolt', qty = 99 },
        { id = 19200, lvl = 45, name = 'Black Bolt', qty = 99 },
        { id = 17337, lvl = 40, name = 'Mythril Bolt', qty = 99 },
        { id = 18153, lvl = 30, name = 'Holy Bolt', qty = 99 },
        { id = 18152, lvl = 25, name = 'Venom Bolt', qty = 99 },
        { id = 18148, lvl = 15, name = 'Acid Bolt', qty = 99 },
        { id = 18150, lvl = 10, name = 'Blind Bolt', qty = 99 },
        { id = 17336, lvl =  1, name = 'Crossbow Bolt', qty = 99 },
        { id = 17339, lvl =  1, name = 'Bronze Bolt', qty = 99 },
    },
    bullet =
    {
        { id = 21327, lvl = 99, name = 'Eradicating Bullet', qty = 99 },
        { id = 21296, lvl = 99, name = 'Chrono Bullet', qty = 99 },
        { id = 21330, lvl = 99, name = 'Decimating Bullet', qty = 99 },
        { id = 19236, lvl = 75, name = 'Hightail Bullet', qty = 99 },
        { id = 18723, lvl = 66, name = 'Steel Bullet', qty = 99 },
        { id = 17341, lvl = 50, name = 'Silver Bullet', qty = 99 },
        { id = 17312, lvl = 50, name = 'Iron Bullet', qty = 99 },
        { id = 19201, lvl = 40, name = 'Electrum Bullet', qty = 99 },
        { id = 19228, lvl = 35, name = 'Paktong Bullet', qty = 99 },
        { id = 17340, lvl = 22, name = 'Bullet', qty = 99 },
        { id = 18713, lvl = 15, name = 'Copper Bullet', qty = 99 },
        { id = 19229, lvl = 11, name = 'Tin Bullet', qty = 99 },
        { id = 17343, lvl =  1, name = 'Bronze Bullet', qty = 99 },
    },
    shuriken =
    {
        { id = 22292, lvl = 99, name = 'Date Shuriken', qty = 99 },
        { id = 18712, lvl = 75, name = 'Koga Shuriken', qty = 99 },
        { id = 17304, lvl = 60, name = 'Fuma Shuriken', qty = 99 },
        { id = 17303, lvl = 48, name = 'Manji Shuriken', qty = 99 },
        { id = 17302, lvl = 28, name = 'Juji Shuriken', qty = 99 },
        { id = 17301, lvl = 18, name = 'Shuriken', qty = 99 },
        { id = 17296, lvl =  1, name = 'Pebble', qty = 99 },
    },
    oil =
    {
        { id = 18733, lvl = 50, name = 'Automat. Oil +2', qty = 12 },
        { id = 18732, lvl = 30, name = 'Automat. Oil +1', qty = 12 },
        { id = 18731, lvl = 15, name = 'Automaton Oil', qty = 12 },
    },
    orphic_egg =
    {
        { id = 18256, lvl =  1, name = 'Orphic Egg' },
    },
    ammo_melee =
    {
        { id = 19253, lvl = 84, name = 'Ravager\'s Orb' },
        { id = 19258, lvl = 83, name = 'Qirmiz Tathlum' },
        { id = 19249, lvl = 78, name = 'Thew Bomblet' },
        { id = 18707, lvl = 70, name = 'Fire Bomblet' },
        { id = 19212, lvl = 70, name = 'Black Tathlum' },
        { id = 19213, lvl = 70, name = 'White Tathlum' },
        { id = 18139, lvl = 63, name = 'Bomb Core' },
        { id = 18254, lvl = 58, name = 'Tiphia Sting' },
        { id = 18180, lvl = 55, name = 'Goblin Grenade' },
        { id = 18175, lvl = 50, name = 'Optical Needle' },
        { id = 19243, lvl = 30, name = 'Brio Dart' },
        { id = 19186, lvl = 15, name = 'Tiny Tathlum' },
        { id = 18166, lvl =  1, name = 'Happy Egg' },
    },
    ammo_tank =
    {
        { id = 21347, lvl = 75, name = 'Charitoni Sling' },
        { id = 19242, lvl = 73, name = 'Aumoniere +1' },
        { id = 19213, lvl = 70, name = 'White Tathlum' },
        { id = 19219, lvl = 69, name = 'Iwatsubute' },
        { id = 18257, lvl = 60, name = 'Bibiki Seashell' },
        { id = 18175, lvl = 50, name = 'Optical Needle' },
        { id = 19186, lvl = 15, name = 'Tiny Tathlum' },
        { id = 18166, lvl =  1, name = 'Happy Egg' },
    },
    ammo_caster =
    {
        { id = 18256, lvl =  1, name = 'Orphic Egg' },
        { id = 19257, lvl = 83, name = 'Incantor Stone' },
        { id = 19250, lvl = 79, name = 'Witchstone' },
        { id = 19270, lvl = 78, name = 'Quartz Tathlum' },
        { id = 17277, lvl = 70, name = 'Hedgehog Bomb' },
        { id = 18140, lvl = 66, name = 'Phtm. Tathlum' },
        { id = 19238, lvl = 56, name = 'Jasper Tathlum' },
        { id = 18174, lvl = 50, name = 'Mantra Coin' },
        { id = 18136, lvl = 25, name = 'Morion Tathlum' },
        { id = 19223, lvl = 11, name = 'Attar Of Roses' },
        { id = 18167, lvl =  1, name = 'Fortune Egg' },
    },
}

-----------------------------------
-- Role Armor & Accessory Pools
-----------------------------------
testGear.ROLE_GEAR =
{
    melee =
    {
        HEAD =
        {
            { id = 27783, lvl = 99, name = 'Skormoth Mask' },
            { id = 23411, lvl = 99, name = 'Ptero. Armet +3' },
            { id = 23096, lvl = 99, name = 'Kasuga Kabuto +2' },
            { id = 23092, lvl = 99, name = 'Heathens Burgeonet +2' },
            { id = 23091, lvl = 99, name = 'Chevaliers Armet +2' },
            { id = 23758, lvl = 99, name = 'Mpacas Cap' },
            { id = 25575, lvl = 99, name = 'Meghanada Visor +2' },
            { id = 23100, lvl = 99, name = 'Hashishin Kavuk +2' },
            { id = 23400, lvl = 99, name = 'Piety Cap +3' },
            { id = 23402, lvl = 99, name = 'Viti. Chapeau +3' },
            { id = 25578, lvl = 99, name = 'Jhakri Coronal +2' },
            { id = 23711, lvl = 99, name = 'Volte Tiara' },
            { id = 23761, lvl = 99, name = 'Nyame Helm' },
            { id = 11501, lvl = 75, name = 'Nocturnus Helm' },
            { id = 13928, lvl = 73, name = 'Hecatomb Cap +1' },
            { id = 16158, lvl = 71, name = 'Gnadbhods Helm' },
            { id = 13867, lvl = 70, name = 'War Beret +1' },
            { id = 13907, lvl = 70, name = 'Ogre Mask +1' },
            { id = 15187, lvl = 70, name = 'Hmn. Jinpachi +1' },
            { id = 16126, lvl = 70, name = 'Bowmans Mask' },
            { id = 16148, lvl = 68, name = 'Cobra Cap' },
            { id = 16125, lvl = 70, name = 'Breeder Mask' },
            { id = 15260, lvl = 70, name = 'Hydra Beret' },
            { id = 12516, lvl = 60, name = 'Chaos Burgeonet' },
            { id = 16067, lvl = 59, name = 'Abtal Turban' },
            { id = 11498, lvl = 59, name = 'Zeal Cap +1' },
            { id = 15267, lvl = 60, name = 'Pup. Taj' },
            { id = 13856, lvl = 60, name = 'Wizards Petasos' },
            { id = 12520, lvl = 60, name = 'Evokers Horn' },
            { id = 16140, lvl = 60, name = 'Scholars M.board' },
            { id = 13701, lvl = 58, name = 'Beak Helm +1' },
            { id = 16143, lvl = 55, name = 'Cobra Hat' },
            { id = 16065, lvl = 50, name = 'Storm Zucchetto' },
            { id = 15219, lvl = 39, name = 'Sinister Mask' },
            { id = 13831, lvl = 40, name = 'Sallet +1' },
            { id = 12462, lvl = 40, name = 'Tora Hachimaki' },
            { id = 12481, lvl = 38, name = 'Cuir Bandana +1' },
            { id = 12470, lvl = 30, name = 'Mrc.cpt. Headgear' },
            { id = 12438, lvl = 30, name = 'Centurions Visor' },
            { id = 13824, lvl = 30, name = 'Strong Bandana' },
            { id = 13830, lvl = 30, name = 'Lgn. Circlet' },
            { id = 12484, lvl = 20, name = 'Mrc. Hachimaki' },
            { id = 15186, lvl = 20, name = 'Trump Crown' },
            { id = 12487, lvl = 10, name = 'Faceguard +1' },
            { id = 12509, lvl = 10, name = 'Legionnaires Cap' },
            { id = 12510, lvl = 10, name = 'Ryl.ftm. Bandana' },
            { id = 16145, lvl = 10, name = 'Lunar Cap' },
            { id = 11811, lvl =  1, name = 'Destrier Beret' },
        },
        BODY =
        {
            { id = 23163, lvl = 99, name = 'Kasuga Domaru +2' },
            { id = 23165, lvl = 99, name = 'Peltasts Plackart +2' },
            { id = 23164, lvl = 99, name = 'Hattori Ningi +2' },
            { id = 23152, lvl = 99, name = 'Boii Lorica +2' },
            { id = 23159, lvl = 99, name = 'Heathens Cuirass +2' },
            { id = 23173, lvl = 99, name = 'Erilaz Surcoat +2' },
            { id = 23157, lvl = 99, name = 'Skulkers Vest +2' },
            { id = 23158, lvl = 99, name = 'Chevaliers Cuirass +2' },
            { id = 23160, lvl = 99, name = 'Nukumi Gausape +2' },
            { id = 23170, lvl = 99, name = 'Maculele Casaque +2' },
            { id = 23169, lvl = 99, name = 'Karagoz Farsetto +2' },
            { id = 23765, lvl = 99, name = 'Mpacas Doublet' },
            { id = 25786, lvl = 99, name = 'Ashera Harness' },
            { id = 23145, lvl = 99, name = 'Luhlaza Jubbah +2' },
            { id = 23156, lvl = 99, name = 'Lethargy Sayon +2' },
            { id = 25748, lvl = 99, name = 'Meg. Cuirie +1' },
            { id = 25794, lvl = 99, name = 'Jhakri Robe +2' },
            { id = 23768, lvl = 99, name = 'Nyame Mail' },
            { id = 14371, lvl = 73, name = 'Armada Hauberk' },
            { id = 11281, lvl = 75, name = 'Hachiryu Haramaki' },
            { id = 11354, lvl = 75, name = 'Nocturnus Mail' },
            { id = 14554, lvl = 75, name = 'Usukane Haramaki' },
            { id = 13793, lvl = 69, name = 'Hauberk +1' },
            { id = 14379, lvl = 73, name = 'Hct. Harness +1' },
            { id = 11306, lvl = 75, name = 'Etoile Casaque +1' },
            { id = 14550, lvl = 75, name = 'Skadis Cuirie' },
            { id = 11284, lvl = 72, name = 'Enkidus Harness' },
            { id = 13735, lvl = 59, name = 'Haubergeon +1' },
            { id = 14562, lvl = 75, name = 'Morrigans Robe' },
            { id = 14469, lvl = 75, name = 'Reverend Mail' },
            { id = 14590, lvl = 68, name = 'Cobra Harness' },
            { id = 13805, lvl = 67, name = 'Assault Jerkin' },
            { id = 14515, lvl = 70, name = 'Hydra Doublet' },
            { id = 13734, lvl = 57, name = 'Scp. Harness +1' },
            { id = 13755, lvl = 59, name = 'Flora Cotehardie' },
            { id = 13743, lvl = 60, name = 'Aketon +1' },
            { id = 14404, lvl = 50, name = 'Shm. Hara-ate' },
            { id = 27800, lvl = 45, name = 'Genta Hara-ate' },
            { id = 14445, lvl = 45, name = 'Luisant Haubert' },
            { id = 14407, lvl = 50, name = 'Cerise Doublet' },
            { id = 27798, lvl = 45, name = 'Ates Cuirass' },
            { id = 13710, lvl = 45, name = 'Brigandine +1' },
            { id = 12606, lvl = 50, name = 'Tct.mgc. Coat' },
            { id = 13813, lvl = 40, name = 'Divine Breastplate' },
            { id = 13728, lvl = 40, name = 'Jujitsu Gi' },
            { id = 12559, lvl = 40, name = 'Ryl.sqr. Chainmail' },
            { id = 13721, lvl = 40, name = 'Irn.msk. Gambison' },
            { id = 13719, lvl = 40, name = 'Ryl.sqr. Robe' },
            { id = 14465, lvl = 30, name = 'Nanban Kariginu' },
            { id = 12598, lvl = 30, name = 'Mrc.cpt. Doublet' },
            { id = 13707, lvl = 30, name = 'Strong Vest' },
            { id = 14427, lvl = 29, name = 'Seers Tunic +1' },
            { id = 12653, lvl = 20, name = 'Mercenarys Gi' },
            { id = 14447, lvl = 20, name = 'Barons Saio' },
            { id = 13818, lvl = 18, name = 'Garrison Tunica' },
            { id = 12661, lvl = 10, name = 'Solid Mail' },
            { id = 12629, lvl = 10, name = 'Lgn. Harness' },
            { id = 12630, lvl = 10, name = 'Ryl.ftm. Vest' },
            { id = 12607, lvl =  1, name = 'Bronze Harness +1' },
            { id = 14400, lvl =  1, name = 'Fishermans Apron' },
        },
        HANDS =
        {
            { id = 23224, lvl = 99, name = 'Skulkers Armlets +2' },
            { id = 23227, lvl = 99, name = 'Nukumi Manoplas +2' },
            { id = 23236, lvl = 99, name = 'Karagoz Guanti +2' },
            { id = 23231, lvl = 99, name = 'Hattori Tekko +2' },
            { id = 23232, lvl = 99, name = 'Peltasts Vambraces +2' },
            { id = 23237, lvl = 99, name = 'Maculele Bangles +2' },
            { id = 23226, lvl = 99, name = 'Heathens Gauntlets +2' },
            { id = 23220, lvl = 99, name = 'Bhikku Gloves +2' },
            { id = 23240, lvl = 99, name = 'Erilaz Gauntlets +2' },
            { id = 23772, lvl = 99, name = 'Mpacas Gloves' },
            { id = 23225, lvl = 99, name = 'Chevaliers Gauntlets +2' },
            { id = 23219, lvl = 99, name = 'Boii Mufflers +2' },
            { id = 23734, lvl = 99, name = 'Malignance Gloves' },
            { id = 23719, lvl = 99, name = 'Volte Mittens' },
            { id = 23775, lvl = 99, name = 'Nyame Gauntlets' },
            { id = 15015, lvl = 75, name = 'Hachiryu Kote' },
            { id = 14897, lvl = 74, name = 'Chs. Gauntlets +1' },
            { id = 14077, lvl = 73, name = 'Hct. Mittens +1' },
            { id = 14965, lvl = 75, name = 'Skadis Bazubands' },
            { id = 15023, lvl = 72, name = 'Enkidus Mittens' },
            { id = 14878, lvl = 70, name = 'Hachiman Kote +1' },
            { id = 14977, lvl = 75, name = 'Morrigans Cuffs' },
            { id = 14985, lvl = 75, name = 'Goliard Cuffs' },
            { id = 14022, lvl = 70, name = 'Alkyoneuss Brc.' },
            { id = 14999, lvl = 70, name = 'Vampiric Mitts' },
            { id = 14074, lvl = 70, name = 'Tarasque Mitts +1' },
            { id = 15001, lvl = 70, name = 'Breeder Mufflers' },
            { id = 14924, lvl = 70, name = 'Hydra Gloves' },
            { id = 14021, lvl = 60, name = 'Pallass Bracelets' },
            { id = 13963, lvl = 60, name = 'Healers Mitts' },
            { id = 13977, lvl = 57, name = 'Light Gauntlets' },
            { id = 14064, lvl = 58, name = 'Sand Gloves' },
            { id = 14843, lvl = 50, name = 'Spiked Fng.gnt.' },
            { id = 14020, lvl = 50, name = 'Enkeladoss Brc.' },
            { id = 14936, lvl = 50, name = 'Storm Manopolas' },
            { id = 14986, lvl = 34, name = 'Ochimusha Kote' },
            { id = 14019, lvl = 40, name = 'Ogygoss Brc.' },
            { id = 12743, lvl = 40, name = 'Cmb.cst. Mitts' },
            { id = 15058, lvl = 30, name = 'Combat Mittens +1' },
            { id = 14018, lvl = 30, name = 'Gigas Bracelets' },
            { id = 12694, lvl = 30, name = 'Ctr. F. Gauntlets' },
            { id = 14859, lvl = 29, name = 'Seers Mitts +1' },
            { id = 14054, lvl = 20, name = 'Barons Cuffs' },
            { id = 12719, lvl = 20, name = 'Mrc. Tekko' },
            { id = 13953, lvl = 20, name = 'White Mitts +1' },
            { id = 14841, lvl = 20, name = 'Garrison Gloves' },
            { id = 12752, lvl = 10, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, name = 'Ryl.ftm. Gloves' },
            { id = 12775, lvl =  8, name = 'Mitts +1' },
            { id = 14831, lvl =  1, name = 'Smithys Mitts' },
        },
        LEGS =
        {
            { id = 23583, lvl = 99, name = 'Ig. Flanchard +3' },
            { id = 23297, lvl = 99, name = 'Kasuga Haidate +2' },
            { id = 23611, lvl = 99, name = 'Mochi. Hakama +3' },
            { id = 23286, lvl = 99, name = 'Boii Cuisses +2' },
            { id = 23291, lvl = 99, name = 'Skulkers Culottes +2' },
            { id = 23287, lvl = 99, name = 'Bhikku Hose +2' },
            { id = 23299, lvl = 99, name = 'Peltasts Cuissots +2' },
            { id = 23294, lvl = 99, name = 'Nukumi Quijotes +2' },
            { id = 23301, lvl = 99, name = 'Hashishin Tayt +2' },
            { id = 23292, lvl = 99, name = 'Chevaliers Cuisses +2' },
            { id = 23303, lvl = 99, name = 'Kara. Pantaloni +2' },
            { id = 23307, lvl = 99, name = 'Erilaz Leg Guards +2' },
            { id = 23304, lvl = 99, name = 'Maculele Tights +2' },
            { id = 25880, lvl = 99, name = 'Meg. Chausses +2' },
            { id = 23290, lvl = 99, name = 'Lethargy Fuseau +2' },
            { id = 23782, lvl = 99, name = 'Nyame Flanchard' },
            { id = 14309, lvl = 73, name = 'Hct. Subligar +1' },
            { id = 12818, lvl = 75, name = 'Byakkos Haidate' },
            { id = 15633, lvl = 75, name = 'Usukane Hizayoroi' },
            { id = 15629, lvl = 75, name = 'Skadis Chausses' },
            { id = 16375, lvl = 73, name = 'Surge Subligar' },
            { id = 16343, lvl = 72, name = 'Enkidus Subligar' },
            { id = 14307, lvl = 72, name = 'Dusk Trousers +1' },
            { id = 15595, lvl = 70, name = 'Hydra Brais' },
            { id = 14318, lvl = 70, name = 'Conte Cosciales' },
            { id = 15614, lvl = 70, name = 'Exorcist Hose' },
            { id = 15394, lvl = 70, name = 'Hmn. Hakama +1' },
            { id = 16317, lvl = 68, name = 'Cobra Subligar' },
            { id = 16320, lvl = 69, name = 'Kensei Sitabaki' },
            { id = 15399, lvl = 70, name = 'Kings Cuisses' },
            { id = 15607, lvl = 59, name = 'Abtal Zerehs' },
            { id = 14223, lvl = 56, name = 'Choral Cannions' },
            { id = 12814, lvl = 55, name = 'Ryl.kgt. Breeches' },
            { id = 14215, lvl = 60, name = 'Temple Hose' },
            { id = 15612, lvl = 60, name = 'Strike Subligar' },
            { id = 14213, lvl = 58, name = 'Beak Trousers +1' },
            { id = 14334, lvl = 50, name = 'Shm. Haidate' },
            { id = 14216, lvl = 56, name = 'Healers Pantaln.' },
            { id = 14217, lvl = 56, name = 'Wizards Tonban' },
            { id = 16311, lvl = 56, name = 'Scholars Pants' },
            { id = 16374, lvl = 55, name = 'Layqa Seraweels' },
            { id = 16314, lvl = 55, name = 'Cobra Slops' },
            { id = 15368, lvl = 50, name = 'War Hose' },
            { id = 28081, lvl = 45, name = 'Ates Flanchard' },
            { id = 14246, lvl = 50, name = 'Steel Cuisses +1' },
            { id = 15371, lvl = 50, name = 'Dst. Codpiece' },
            { id = 28082, lvl = 45, name = 'Idis Trousers' },
            { id = 14335, lvl = 50, name = 'Nokizaru Hakama' },
            { id = 28083, lvl = 45, name = 'Genta-no-hakama' },
            { id = 15375, lvl = 50, name = 'Aries Subligar' },
            { id = 15382, lvl = 50, name = 'Scorpius Subligar' },
            { id = 15384, lvl = 50, name = 'Capri. Subligar' },
            { id = 15388, lvl = 50, name = 'Ophiu. Subligar' },
            { id = 12815, lvl = 40, name = 'Ryl.sqr. Breeches' },
            { id = 14244, lvl = 40, name = 'Iron Cuisses +1' },
            { id = 12870, lvl = 40, name = 'Cmb.cst. Slacks' },
            { id = 12911, lvl = 38, name = 'Cuir Trousers +1' },
            { id = 14333, lvl = 30, name = 'Noct Brais +1' },
            { id = 15422, lvl = 29, name = 'Black Hose' },
            { id = 12910, lvl = 30, name = 'Strong Trousers' },
            { id = 14330, lvl = 30, name = 'Rubious Slacks' },
            { id = 12854, lvl = 30, name = 'Mrc.cpt. Hose' },
            { id = 28202, lvl = 30, name = 'Dredger Hose' },
            { id = 12882, lvl = 20, name = 'Ryl.ftm. Trousers' },
            { id = 15405, lvl = 20, name = 'Barons Slops' },
            { id = 12863, lvl = 10, name = 'Solid Cuisses' },
            { id = 12915, lvl = 10, name = 'Freeswords Slops' },
            { id = 12899, lvl =  8, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, name = 'Brz. Subligar +1' },
            { id = 12897, lvl =  1, name = 'Slops +1' },
        },
        FEET =
        {
            { id = 23677, lvl = 99, name = 'Sak. Sune-ate +3' },
            { id = 23678, lvl = 99, name = 'Mochi. Kyahan +3' },
            { id = 23371, lvl = 99, name = 'Maculele Toe Shoes +2' },
            { id = 23681, lvl = 99, name = 'Luhlaza Charuqs +3' },
            { id = 23673, lvl = 99, name = 'Fall. Sollerets +3' },
            { id = 23679, lvl = 99, name = 'Ptero. Greaves +3' },
            { id = 23671, lvl = 99, name = 'Plun. Poulaines +3' },
            { id = 23361, lvl = 99, name = 'Nukumi Ocreae +2' },
            { id = 23643, lvl = 99, name = 'Pumm. Calligae +3' },
            { id = 23786, lvl = 99, name = 'Mpacas Boots' },
            { id = 23687, lvl = 99, name = 'Futhark Boots +3' },
            { id = 23359, lvl = 99, name = 'Chevaliers Sabatons +2' },
            { id = 23357, lvl = 99, name = 'Lethargy Houseaux +2' },
            { id = 23727, lvl = 99, name = 'Volte Spats' },
            { id = 23668, lvl = 99, name = 'Piety Duckbills +3' },
            { id = 23789, lvl = 99, name = 'Nyame Sollerets' },
            { id = 15719, lvl = 75, name = 'Usukane Sune-ate' },
            { id = 14181, lvl = 73, name = 'Hct. Leggings +1' },
            { id = 11386, lvl = 75, name = 'Comm. Bottes +1' },
            { id = 14162, lvl = 75, name = 'Agronas Leggings' },
            { id = 28272, lvl = 75, name = 'Adsilio Boots +1' },
            { id = 15332, lvl = 70, name = 'Hmn. Sune-ate +1' },
            { id = 15735, lvl = 75, name = 'Goliard Clogs' },
            { id = 15306, lvl = 70, name = 'Conte Gambieras' },
            { id = 14159, lvl = 70, name = 'Ogre Ledelsens +1' },
            { id = 15757, lvl = 68, name = 'Cobra Leggings' },
            { id = 15680, lvl = 70, name = 'Hydra Gaiters' },
            { id = 15709, lvl = 70, name = 'Mercenarys Boots' },
            { id = 15349, lvl = 67, name = 'Rutter Sabatons' },
            { id = 11373, lvl = 60, name = 'Seirenshi Habaki' },
            { id = 14094, lvl = 60, name = 'Rogues Poulaines' },
            { id = 15739, lvl = 59, name = 'Tabin Boots +1' },
            { id = 15693, lvl = 59, name = 'Abtal Boots' },
            { id = 14099, lvl = 60, name = 'Hunters Socks' },
            { id = 14084, lvl = 59, name = 'Dst. Sollerets +1' },
            { id = 15338, lvl = 59, name = 'Vampire Boots' },
            { id = 11371, lvl = 50, name = 'Seikenshi Habaki' },
            { id = 15691, lvl = 50, name = 'Storm Gambieras' },
            { id = 13046, lvl = 40, name = 'Plate Leggings +1' },
            { id = 12998, lvl = 40, name = 'Cmb.cst. Shoes' },
            { id = 15348, lvl = 38, name = 'Mountain Gaiters' },
            { id = 14207, lvl = 30, name = 'Noct Gaiters +1' },
            { id = 15318, lvl = 30, name = 'Rubious Pumps' },
            { id = 13039, lvl = 30, name = 'Strong Boots' },
            { id = 15326, lvl = 30, name = 'Gargoyle Boots' },
            { id = 28341, lvl = 30, name = 'Agrarian Boots' },
            { id = 13048, lvl = 20, name = 'Mages Sandals' },
            { id = 15344, lvl = 20, name = 'Barons Pigaches' },
            { id = 11412, lvl = 17, name = 'Mtt. Leggings +1' },
            { id = 15351, lvl =  7, name = 'Bounding Boots' },
            { id = 13003, lvl = 10, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, name = 'Solea +1' },
            { id = 14195, lvl =  1, name = 'Waders' },
        },
        NECK =
        {
            { id = 26004, lvl = 99, name = 'Lissome Necklace' },
            { id = 16275, lvl = 74, name = 'Ancient Torque' },
            { id = 16268, lvl = 70, name = 'Kubira Beads' },
            { id = 16266, lvl = 70, name = 'Wivre Gorget +1' },
            { id = 15523, lvl = 60, name = 'Chivalrous Chain' },
            { id = 13167, lvl = 50, name = 'Storm Gorget' },
            { id = 15515, lvl = 33, name = 'Peacock Amulet' },
            { id = 15504, lvl = 30, name = 'Ajase Beads' },
            { id = 13102, lvl = 30, name = 'Paisley Scarf' },
            { id = 13070, lvl = 30, name = 'Wolf Gorget +1' },
            { id = 13058, lvl = 20, name = 'Bloodbead Amulet' },
            { id = 13101, lvl = 10, name = 'Green Scarf' },
            { id = 16296, lvl =  9, name = 'Armigers Lace' },
            { id = 13098, lvl = 10, name = 'Rep.bronze Medal' },
            { id = 16273, lvl =  1, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 26341, lvl = 99, name = 'Moonbow Belt +1' },
            { id = 28408, lvl = 99, name = 'Grunfeld Rope' },
            { id = 15917, lvl = 72, name = 'Cuchulains Belt' },
            { id = 15954, lvl = 75, name = 'Fierce Belt' },
            { id = 15871, lvl = 70, name = 'Warriors Stone' },
            { id = 15879, lvl = 70, name = 'Sao. Koshi-ate' },
            { id = 15878, lvl = 70, name = 'Wyrm Belt' },
            { id = 15928, lvl = 72, name = 'Lycopodium Sash' },
            { id = 13186, lvl = 70, name = 'Black Belt' },
            { id = 15923, lvl = 69, name = 'Grenadier Belt' },
            { id = 15884, lvl = 60, name = 'Potent Belt' },
            { id = 13231, lvl = 48, name = 'Life Belt' },
            { id = 13202, lvl = 40, name = 'Brown Belt' },
            { id = 15286, lvl = 40, name = 'Tilt Belt' },
            { id = 13221, lvl = 30, name = 'Mrc.cpt. Belt' },
            { id = 15927, lvl = 30, name = 'Pinwheel Belt' },
            { id = 15285, lvl = 30, name = 'Avatar Belt' },
            { id = 13201, lvl = 18, name = 'Purple Belt' },
            { id = 15880, lvl = 20, name = 'Key Ring Belt' },
            { id = 15906, lvl = 20, name = 'Mohbwa Sash +1' },
            { id = 13225, lvl = 18, name = 'Brave Belt' },
            { id = 13219, lvl = 18, name = 'Magic Belt +1' },
            { id = 13191, lvl = 17, name = 'Lizard Belt +1' },
            { id = 13190, lvl =  8, name = 'Heko Obi +1' },
            { id = 15889, lvl =  7, name = 'Augmenting Belt' },
            { id = 13184, lvl =  1, name = 'White Belt' },
            { id = 13226, lvl =  1, name = 'Blood Stone +1' },
            { id = 15456, lvl =  1, name = 'Dash Sash' },
        },
        BACK =
        {
            { id = 28628, lvl = 99, name = 'Takaha Mantle' },
            { id = 28618, lvl = 99, name = 'Anchorets Mantle' },
            { id = 28617, lvl = 99, name = 'Maulers Mantle' },
            { id = 28630, lvl = 99, name = 'Updraft Mantle' },
            { id = 28629, lvl = 99, name = 'Yokaze Mantle' },
            { id = 28624, lvl = 99, name = 'Niht Mantle' },
            { id = 27594, lvl = 99, name = 'Annealed Mantle' },
            { id = 28634, lvl = 99, name = 'Dispersal Mantle' },
            { id = 27620, lvl = 99, name = 'Aurists Cape +1' },
            { id = 16216, lvl = 75, name = 'Cerb. Mantle +1' },
            { id = 16245, lvl = 70, name = 'Pantin Cape' },
            { id = 15475, lvl = 70, name = 'Charger Mantle' },
            { id = 11546, lvl = 75, name = 'Aesir Mantle' },
            { id = 13648, lvl = 70, name = 'Gigant Mantle' },
            { id = 13604, lvl = 60, name = 'Behem. Mantle +1' },
            { id = 11545, lvl = 60, name = 'Fourth Mantle' },
            { id = 15483, lvl = 50, name = 'Storm Mantle' },
            { id = 13675, lvl = 40, name = 'Rearguard Mantle' },
            { id = 13674, lvl = 40, name = 'Agile Mantle' },
            { id = 15468, lvl = 40, name = 'Resentment Cape' },
            { id = 13625, lvl = 39, name = 'Tundra Mantle' },
            { id = 13644, lvl = 30, name = 'Midnight Cape' },
            { id = 13673, lvl = 30, name = 'Magicians Mantle' },
            { id = 13680, lvl = 20, name = 'Variable Mantle' },
            { id = 13681, lvl = 20, name = 'Variable Cape' },
            { id = 13607, lvl = 10, name = 'Mist Silk Cape' },
            { id = 13599, lvl =  4, name = 'Rabbit Mantle +1' },
            { id = 16243, lvl =  1, name = 'Drovers Mantle' },
        },
        EAR =
        {
            { id = 26117, lvl = 99, name = 'Crep. Earring' },
            { id = 26118, lvl = 99, name = 'Sroda Earring' },
            { id = 26108, lvl = 99, name = 'Odr Earring' },
            { id = 26084, lvl = 99, name = 'Sherida Earring' },
            { id = 26081, lvl = 99, name = 'Mache Earring +1' },
            { id = 14813, lvl = 75, name = 'Brutal Earring' },
            { id = 16057, lvl = 75, name = 'Aesir Ear Pendant' },
            { id = 15979, lvl = 70, name = 'Fowling Earring' },
            { id = 13415, lvl = 70, name = 'Pixie Earring' },
            { id = 15994, lvl = 67, name = 'Harmonius Earring' },
            { id = 13403, lvl = 58, name = 'Assault Earring' },
            { id = 16037, lvl = 60, name = 'Helenuss Earring' },
            { id = 14761, lvl = 60, name = 'Elusive Earring' },
            { id = 15968, lvl = 50, name = 'Storm Loop' },
            { id = 15970, lvl = 50, name = 'Stoic Earring' },
            { id = 14806, lvl = 40, name = 'Intruder Earring' },
            { id = 13405, lvl = 40, name = 'Enhancing Earring' },
            { id = 16049, lvl = 40, name = 'Empire Earring' },
            { id = 11043, lvl = 30, name = 'Giants Earring' },
            { id = 16046, lvl = 30, name = 'Kazham Earring' },
            { id = 13365, lvl = 20, name = 'Shield Earring' },
            { id = 14757, lvl = 20, name = 'Mecurial Earring' },
            { id = 14695, lvl = 10, name = 'Hope Earring +1' },
            { id = 13380, lvl = 10, name = 'Hope Earring' },
            { id = 13402, lvl =  1, name = 'Cassie Earring' },
            { id = 28510, lvl =  1, name = 'M. Slime Earring' },
        },
        RING =
        {
            { id = 26186, lvl = 99, name = 'Ilabrat Ring' },
            { id = 26191, lvl = 99, name = 'Regal Ring' },
            { id = 28471, lvl = 99, name = 'Gere Ring' },
            { id = 26190, lvl = 99, name = 'Moonlight Ring' },
            { id = 26192, lvl = 99, name = 'Adoulin Ring +1' },
            { id = 27580, lvl = 99, name = 'Adoulin Ring' },
            { id = 15548, lvl = 75, name = 'Marss Ring' },
            { id = 11629, lvl = 75, name = 'Zilant Ring' },
            { id = 15818, lvl = 70, name = 'Molioness Ring' },
            { id = 15828, lvl = 70, name = 'Blood Ring' },
            { id = 14674, lvl = 57, name = 'Toreadors Ring' },
            { id = 13567, lvl = 57, name = 'Bomb Queen Ring' },
            { id = 15808, lvl = 50, name = 'Ulthalams Ring' },
            { id = 15778, lvl = 50, name = 'Unyielding Ring' },
            { id = 14675, lvl = 40, name = 'Woodsman Ring' },
            { id = 13281, lvl = 40, name = 'Snipers Ring +1' },
            { id = 15543, lvl = 30, name = 'Rajas Ring' },
            { id = 15551, lvl = 30, name = 'Shikaree Ring' },
            { id = 14652, lvl = 20, name = 'Protean Ring' },
            { id = 14653, lvl = 20, name = 'Variable Ring' },
            { id = 14670, lvl = 10, name = 'Safeguard Ring' },
            { id = 15790, lvl = 10, name = 'Multiple Ring' },
            { id = 13495, lvl =  1, name = 'San Dorian Ring' },
            { id = 13497, lvl =  1, name = 'Bastokan Ring' },
        },
    },
    tank =
    {
        HEAD =
        {
            { id = 23091, lvl = 99, name = 'Chevaliers Armet +2' },
            { id = 23757, lvl = 99, name = 'Sakpatas Helm' },
            { id = 23761, lvl = 99, name = 'Nyame Helm' },
            { id = 12434, lvl = 75, name = 'Genbus Kabuto' },
            { id = 16117, lvl = 75, name = 'Valhalla Helm' },
            { id = 13938, lvl = 72, name = 'Dusk Mask +1' },
            { id = 16146, lvl = 68, name = 'Iron Ram Sallet' },
            { id = 13914, lvl = 70, name = 'Aegishjalmr' },
            { id = 15247, lvl = 75, name = 'Clr. Cap +1' },
            { id = 13919, lvl = 70, name = 'Feral Mask' },
            { id = 16092, lvl = 75, name = 'Usukane Somen' },
            { id = 15160, lvl = 73, name = 'Genie Tiara' },
            { id = 16108, lvl = 75, name = 'Goliard Chapeau' },
            { id = 16131, lvl = 65, name = 'Wivre Mask +1' },
            { id = 15263, lvl = 70, name = 'Hydra Cap' },
            { id = 16083, lvl = 70, name = 'Mrc. Turban' },
            { id = 13848, lvl = 60, name = 'Gilt Armet' },
            { id = 16067, lvl = 59, name = 'Abtal Turban' },
            { id = 15266, lvl = 60, name = 'Corsairs Tricorne' },
            { id = 12513, lvl = 60, name = 'Warlocks Chapeau' },
            { id = 15265, lvl = 60, name = 'Magus Keffiyeh' },
            { id = 12439, lvl = 59, name = 'Bascinet +1' },
            { id = 12512, lvl = 56, name = 'Temple Crown' },
            { id = 12519, lvl = 60, name = 'Drachen Armet' },
            { id = 13701, lvl = 58, name = 'Beak Helm +1' },
            { id = 13856, lvl = 60, name = 'Wizards Petasos' },
            { id = 15267, lvl = 60, name = 'Pup. Taj' },
            { id = 16080, lvl = 53, name = 'Magi Hat' },
            { id = 15150, lvl = 50, name = 'Shock Mask' },
            { id = 15243, lvl = 50, name = 'Raven Beret' },
            { id = 15149, lvl = 50, name = 'Rival Ribbon' },
            { id = 12422, lvl = 40, name = 'Irn.msk. Armet' },
            { id = 12462, lvl = 40, name = 'Tora Hachimaki' },
            { id = 12481, lvl = 38, name = 'Cuir Bandana +1' },
            { id = 13834, lvl = 38, name = 'Mages Hat' },
            { id = 15171, lvl = 29, name = 'Kampfschaller' },
            { id = 12431, lvl = 30, name = 'Ryl. Squires Helm' },
            { id = 15172, lvl = 30, name = 'Noct Beret +1' },
            { id = 13824, lvl = 30, name = 'Strong Bandana' },
            { id = 15168, lvl = 30, name = 'Rubious Crown' },
            { id = 13830, lvl = 30, name = 'Lgn. Circlet' },
            { id = 15208, lvl = 20, name = 'Barons Chapeau' },
            { id = 15186, lvl = 20, name = 'Trump Crown' },
            { id = 12502, lvl =  9, name = 'Cmp. Eye Circlet' },
            { id = 12510, lvl = 10, name = 'Ryl.ftm. Bandana' },
            { id = 11811, lvl =  1, name = 'Destrier Beret' },
        },
        BODY =
        {
            { id = 23448, lvl = 99, name = 'Rev. Surcoat +3' },
            { id = 23768, lvl = 99, name = 'Nyame Mail' },
            { id = 14370, lvl = 73, name = 'Kaiser Cuirass' },
            { id = 14577, lvl = 75, name = 'Valhalla Brstplate' },
            { id = 12562, lvl = 75, name = 'Kirins Osode' },
            { id = 14546, lvl = 75, name = 'Ares Cuirass' },
            { id = 14538, lvl = 72, name = 'Hydra Mail +1' },
            { id = 14588, lvl = 68, name = 'Iron Ram Hauberk' },
            { id = 14505, lvl = 75, name = 'Asn. Vest +1' },
            { id = 11287, lvl = 71, name = 'Antares Harness' },
            { id = 14366, lvl = 70, name = 'Ogre Jerkin +1' },
            { id = 13802, lvl = 64, name = 'Arhats Gi +1' },
            { id = 14469, lvl = 75, name = 'Reverend Mail' },
            { id = 12638, lvl = 60, name = 'Fighters Lorica' },
            { id = 14570, lvl = 75, name = 'Goliard Saio' },
            { id = 13773, lvl = 70, name = 'Carnage Aketon' },
            { id = 14515, lvl = 70, name = 'Hydra Doublet' },
            { id = 12644, lvl = 60, name = 'Gallant Surcoat' },
            { id = 13771, lvl = 70, name = 'War Aketon +1' },
            { id = 13741, lvl = 60, name = 'Byrnie +1' },
            { id = 14591, lvl = 68, name = 'Cobra Robe' },
            { id = 13743, lvl = 60, name = 'Aketon +1' },
            { id = 12648, lvl = 58, name = 'Hunters Jerkin' },
            { id = 12641, lvl = 58, name = 'Wizards Coat' },
            { id = 13755, lvl = 59, name = 'Flora Cotehardie' },
            { id = 14412, lvl = 50, name = 'Parade Cuirass' },
            { id = 14411, lvl = 50, name = 'Aikido Gi' },
            { id = 12550, lvl = 50, name = 'Irn.msk. Cuirass' },
            { id = 14499, lvl = 50, name = 'Raven Jupon' },
            { id = 13710, lvl = 45, name = 'Brigandine +1' },
            { id = 13813, lvl = 40, name = 'Divine Breastplate' },
            { id = 12606, lvl = 50, name = 'Tct.mgc. Coat' },
            { id = 13724, lvl = 40, name = 'Breastplate +1' },
            { id = 12559, lvl = 40, name = 'Ryl.sqr. Chainmail' },
            { id = 13721, lvl = 40, name = 'Irn.msk. Gambison' },
            { id = 13728, lvl = 40, name = 'Jujitsu Gi' },
            { id = 13719, lvl = 40, name = 'Ryl.sqr. Robe' },
            { id = 14435, lvl = 29, name = 'Kampfbrust' },
            { id = 12566, lvl = 30, name = 'Ctr. Scale Mail' },
            { id = 13707, lvl = 30, name = 'Strong Vest' },
            { id = 12598, lvl = 30, name = 'Mrc.cpt. Doublet' },
            { id = 14427, lvl = 29, name = 'Seers Tunic +1' },
            { id = 12653, lvl = 20, name = 'Mercenarys Gi' },
            { id = 14447, lvl = 20, name = 'Barons Saio' },
            { id = 13818, lvl = 18, name = 'Garrison Tunica' },
            { id = 12661, lvl = 10, name = 'Solid Mail' },
            { id = 12629, lvl = 10, name = 'Lgn. Harness' },
            { id = 12630, lvl = 10, name = 'Ryl.ftm. Vest' },
            { id = 12607, lvl =  1, name = 'Bronze Harness +1' },
            { id = 14585, lvl =  1, name = 'Fourth Tunica' },
        },
        HANDS =
        {
            { id = 23775, lvl = 99, name = 'Nyame Gauntlets' },
            { id = 12690, lvl = 75, name = 'Seiryus Kote' },
            { id = 14061, lvl = 73, name = 'Kaiser Handschuhs' },
            { id = 15039, lvl = 75, name = 'Etoile Bangles +1' },
            { id = 14983, lvl = 75, name = 'Askar Manopolas' },
            { id = 14914, lvl = 75, name = 'Asn. Armlets +1' },
            { id = 14905, lvl = 75, name = 'Homam Manopolas' },
            { id = 15016, lvl = 71, name = 'Orcish Gauntlets' },
            { id = 14883, lvl = 70, name = 'Kings Gauntlets' },
            { id = 15009, lvl = 68, name = 'I.r. Dastanas' },
            { id = 14969, lvl = 75, name = 'Usukane Gote' },
            { id = 14911, lvl = 75, name = 'Clr. Mitts +1' },
            { id = 14871, lvl = 70, name = 'Trainers Gloves' },
            { id = 14977, lvl = 75, name = 'Morrigans Cuffs' },
            { id = 14007, lvl = 73, name = 'Zenith Mitts +1' },
            { id = 14951, lvl = 68, name = 'Dragon Kote' },
            { id = 14022, lvl = 70, name = 'Alkyoneuss Brc.' },
            { id = 14985, lvl = 75, name = 'Goliard Cuffs' },
            { id = 15017, lvl = 70, name = 'Toad Mittens' },
            { id = 14021, lvl = 60, name = 'Pallass Bracelets' },
            { id = 14063, lvl = 56, name = 'Prt. Bangles' },
            { id = 14936, lvl = 50, name = 'Storm Manopolas' },
            { id = 14019, lvl = 40, name = 'Ogygoss Brc.' },
            { id = 12793, lvl = 38, name = 'Mages Cuffs' },
            { id = 14018, lvl = 30, name = 'Gigas Bracelets' },
            { id = 14861, lvl = 30, name = 'Rubious Mitts' },
            { id = 15058, lvl = 30, name = 'Combat Mittens +1' },
            { id = 12782, lvl = 28, name = 'Wool Cuffs +1' },
            { id = 13953, lvl = 20, name = 'White Mitts +1' },
            { id = 14841, lvl = 20, name = 'Garrison Gloves' },
            { id = 12768, lvl = 10, name = 'Solid Fng. Gnt.' },
            { id = 12752, lvl = 10, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, name = 'Ryl.ftm. Gloves' },
            { id = 12775, lvl =  8, name = 'Mitts +1' },
            { id = 14831, lvl =  1, name = 'Smithys Mitts' },
        },
        LEGS =
        {
            { id = 23782, lvl = 99, name = 'Nyame Flanchard' },
            { id = 14283, lvl = 73, name = 'Kaiser Diechlings' },
            { id = 15591, lvl = 75, name = 'Sao. Haidate +1' },
            { id = 16345, lvl = 74, name = 'Magus Shalwar +1' },
            { id = 14307, lvl = 72, name = 'Dusk Trousers +1' },
            { id = 16315, lvl = 68, name = 'Iron Ram Hose' },
            { id = 15649, lvl = 75, name = 'Goliard Trews' },
            { id = 15619, lvl = 71, name = 'Princes Slops' },
            { id = 14238, lvl = 70, name = 'War Brais +1' },
            { id = 14279, lvl = 70, name = 'Ogre Trousers +1' },
            { id = 15595, lvl = 70, name = 'Hydra Brais' },
            { id = 15624, lvl = 70, name = 'Mrc. Subligar' },
            { id = 15598, lvl = 70, name = 'Hydra Hose' },
            { id = 14214, lvl = 58, name = 'Fighters Cuisses' },
            { id = 14220, lvl = 58, name = 'Gallant Breeches' },
            { id = 15600, lvl = 54, name = 'Magus Shalwar' },
            { id = 14212, lvl = 60, name = 'Gilt Cuisses' },
            { id = 15607, lvl = 59, name = 'Abtal Zerehs' },
            { id = 14215, lvl = 60, name = 'Temple Hose' },
            { id = 14219, lvl = 56, name = 'Rogues Culottes' },
            { id = 14209, lvl = 59, name = 'Dst. Breeches +1' },
            { id = 14213, lvl = 58, name = 'Beak Trousers +1' },
            { id = 14216, lvl = 56, name = 'Healers Pantaln.' },
            { id = 14217, lvl = 56, name = 'Wizards Tonban' },
            { id = 16311, lvl = 56, name = 'Scholars Pants' },
            { id = 16374, lvl = 55, name = 'Layqa Seraweels' },
            { id = 15621, lvl = 53, name = 'Magi Slops' },
            { id = 14335, lvl = 50, name = 'Nokizaru Hakama' },
            { id = 12806, lvl = 50, name = 'Irn.msk. Cuisses' },
            { id = 15579, lvl = 50, name = 'Raven Hose' },
            { id = 14246, lvl = 50, name = 'Steel Cuisses +1' },
            { id = 14334, lvl = 50, name = 'Shm. Haidate' },
            { id = 15375, lvl = 50, name = 'Aries Subligar' },
            { id = 15382, lvl = 50, name = 'Scorpius Subligar' },
            { id = 12916, lvl = 40, name = 'Cuisses +1' },
            { id = 12815, lvl = 40, name = 'Ryl.sqr. Breeches' },
            { id = 12870, lvl = 40, name = 'Cmb.cst. Slacks' },
            { id = 14244, lvl = 40, name = 'Iron Cuisses +1' },
            { id = 12911, lvl = 38, name = 'Cuir Trousers +1' },
            { id = 14332, lvl = 29, name = 'Kampfdiechlings' },
            { id = 12822, lvl = 30, name = 'Ctr. Cuisses' },
            { id = 12910, lvl = 30, name = 'Strong Trousers' },
            { id = 12854, lvl = 30, name = 'Mrc.cpt. Hose' },
            { id = 28202, lvl = 30, name = 'Dredger Hose' },
            { id = 12882, lvl = 20, name = 'Ryl.ftm. Trousers' },
            { id = 12881, lvl = 20, name = 'Lgn. Subligar' },
            { id = 15405, lvl = 20, name = 'Barons Slops' },
            { id = 12863, lvl = 10, name = 'Solid Cuisses' },
            { id = 12915, lvl = 10, name = 'Freeswords Slops' },
            { id = 12899, lvl =  8, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, name = 'Brz. Subligar +1' },
            { id = 12897, lvl =  1, name = 'Slops +1' },
        },
        FEET =
        {
            { id = 23789, lvl = 99, name = 'Nyame Sollerets' },
            { id = 14163, lvl = 73, name = 'Kaiser Schuhs' },
            { id = 11364, lvl = 75, name = 'Hachiryu Sune-ate' },
            { id = 15704, lvl = 72, name = 'Hydra Greaves +1' },
            { id = 15741, lvl = 75, name = 'Valk. Sabatons' },
            { id = 15719, lvl = 75, name = 'Usukane Sune-ate' },
            { id = 14161, lvl = 73, name = 'Blood Greaves' },
            { id = 15733, lvl = 75, name = 'Askar Gambieras' },
            { id = 11380, lvl = 70, name = 'Hermes Sandals +1' },
            { id = 14188, lvl = 72, name = 'Dusk Ledelsens +1' },
            { id = 15755, lvl = 68, name = 'Iron Ram Greaves' },
            { id = 15735, lvl = 75, name = 'Goliard Clogs' },
            { id = 15328, lvl = 69, name = 'Root Sabots' },
            { id = 15306, lvl = 70, name = 'Conte Gambieras' },
            { id = 15709, lvl = 70, name = 'Mercenarys Boots' },
            { id = 14109, lvl = 69, name = 'Torama Ledelsens' },
            { id = 15683, lvl = 70, name = 'Hydra Boots' },
            { id = 14099, lvl = 60, name = 'Hunters Socks' },
            { id = 14100, lvl = 52, name = 'Myochin Sune-ate' },
            { id = 14094, lvl = 60, name = 'Rogues Poulaines' },
            { id = 14087, lvl = 60, name = 'Gilt Sabatons' },
            { id = 15739, lvl = 59, name = 'Tabin Boots +1' },
            { id = 14088, lvl = 58, name = 'Bk. Ledelsens +1' },
            { id = 15338, lvl = 59, name = 'Vampire Boots' },
            { id = 15664, lvl = 50, name = 'Raven Gaiters' },
            { id = 12942, lvl = 50, name = 'Ryl.kgt. Sollerets' },
            { id = 15692, lvl = 50, name = 'Storm Crackows' },
            { id = 13046, lvl = 40, name = 'Plate Leggings +1' },
            { id = 12998, lvl = 40, name = 'Cmb.cst. Shoes' },
            { id = 15348, lvl = 38, name = 'Mountain Gaiters' },
            { id = 15321, lvl = 29, name = 'Kampfschuhs' },
            { id = 14135, lvl = 28, name = 'Air Solea +1' },
            { id = 12943, lvl = 30, name = 'Ryl.sqr. Sollerets' },
            { id = 12950, lvl = 30, name = 'Ctr. Greaves' },
            { id = 13039, lvl = 30, name = 'Strong Boots' },
            { id = 10648, lvl = 20, name = 'Areion Boots +1' },
            { id = 13045, lvl = 20, name = 'Ryl.ftm. Clogs' },
            { id = 13048, lvl = 20, name = 'Mages Sandals' },
            { id = 13012, lvl = 18, name = 'Power Sandals' },
            { id = 13024, lvl = 10, name = 'Solid Greaves' },
            { id = 13004, lvl = 10, name = 'Ryl.ftm. Boots' },
            { id = 13003, lvl = 10, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, name = 'Solea +1' },
            { id = 11400, lvl =  1, name = 'Noble Poulaines' },
        },
        NECK =
        {
            { id = 25455, lvl = 99, name = 'Kgt. Beads +2' },
            { id = 26037, lvl = 99, name = 'Moonlight Necklace' },
            { id = 28403, lvl = 99, name = 'Inq. Bead Necklace' },
            { id = 25503, lvl = 99, name = 'Smn. Collar +2' },
            { id = 28362, lvl = 99, name = 'Dualism Collar +1' },
            { id = 16267, lvl = 70, name = 'Ritter Gorget' },
            { id = 15536, lvl = 75, name = 'Rho Necklace' },
            { id = 16302, lvl = 70, name = 'Bloodbead Gorget' },
            { id = 15521, lvl = 60, name = 'Tempered Chain' },
            { id = 13166, lvl = 50, name = 'Hateful Collar' },
            { id = 13164, lvl = 40, name = 'Agile Gorget' },
            { id = 13065, lvl = 40, name = 'Gorget +1' },
            { id = 13129, lvl = 38, name = 'Spirit Torque' },
            { id = 13177, lvl = 39, name = 'Stone Gorget' },
            { id = 15504, lvl = 30, name = 'Ajase Beads' },
            { id = 13102, lvl = 30, name = 'Paisley Scarf' },
            { id = 13104, lvl = 30, name = 'Ryl.sqr. Collar' },
            { id = 13058, lvl = 20, name = 'Bloodbead Amulet' },
            { id = 13101, lvl = 10, name = 'Green Scarf' },
            { id = 16296, lvl =  9, name = 'Armigers Lace' },
            { id = 13098, lvl = 10, name = 'Rep.bronze Medal' },
            { id = 16273, lvl =  1, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 28456, lvl = 99, name = 'Kasiri Belt' },
            { id = 26341, lvl = 99, name = 'Moonbow Belt +1' },
            { id = 28437, lvl = 99, name = 'Flume Belt +1' },
            { id = 26324, lvl = 99, name = 'Latria Sash' },
            { id = 15893, lvl = 71, name = 'Marid Belt +1' },
            { id = 13186, lvl = 70, name = 'Black Belt' },
            { id = 15937, lvl = 75, name = 'Fettle Belt' },
            { id = 15878, lvl = 70, name = 'Wyrm Belt' },
            { id = 13239, lvl = 67, name = 'Kaiser Belt' },
            { id = 15874, lvl = 70, name = 'Sorcerers Belt' },
            { id = 15925, lvl = 70, name = 'Argute Belt' },
            { id = 13188, lvl = 70, name = 'Star Sash' },
            { id = 15912, lvl = 60, name = 'Lieutenants Sash' },
            { id = 15882, lvl = 50, name = 'Storm Belt' },
            { id = 15945, lvl = 50, name = 'Volant Belt' },
            { id = 13237, lvl = 38, name = 'Survival Belt' },
            { id = 13214, lvl = 40, name = 'Waistbelt +1' },
            { id = 15908, lvl = 40, name = 'Qiqirn Sash +1' },
            { id = 13272, lvl = 40, name = 'Corsette +1' },
            { id = 13221, lvl = 30, name = 'Mrc.cpt. Belt' },
            { id = 15927, lvl = 30, name = 'Pinwheel Belt' },
            { id = 15285, lvl = 30, name = 'Avatar Belt' },
            { id = 15906, lvl = 20, name = 'Mohbwa Sash +1' },
            { id = 13225, lvl = 18, name = 'Brave Belt' },
            { id = 15880, lvl = 20, name = 'Key Ring Belt' },
            { id = 13240, lvl = 15, name = 'Warriors Belt +1' },
            { id = 13190, lvl =  8, name = 'Heko Obi +1' },
            { id = 15889, lvl =  7, name = 'Augmenting Belt' },
            { id = 15456, lvl =  1, name = 'Dash Sash' },
        },
        BACK =
        {
            { id = 26269, lvl = 99, name = 'Moonlight Cape' },
            { id = 15481, lvl = 70, name = 'Valor Cape' },
            { id = 27597, lvl = 75, name = 'Emico Mantle' },
            { id = 13648, lvl = 70, name = 'Gigant Mantle' },
            { id = 13604, lvl = 60, name = 'Behem. Mantle +1' },
            { id = 15492, lvl = 60, name = 'Intensifying Cape' },
            { id = 15483, lvl = 50, name = 'Storm Mantle' },
            { id = 15468, lvl = 40, name = 'Resentment Cape' },
            { id = 13675, lvl = 40, name = 'Rearguard Mantle' },
            { id = 13625, lvl = 39, name = 'Tundra Mantle' },
            { id = 13644, lvl = 30, name = 'Midnight Cape' },
            { id = 13673, lvl = 30, name = 'Magicians Mantle' },
            { id = 13680, lvl = 20, name = 'Variable Mantle' },
            { id = 13681, lvl = 20, name = 'Variable Cape' },
            { id = 13607, lvl = 10, name = 'Mist Silk Cape' },
            { id = 13599, lvl =  4, name = 'Rabbit Mantle +1' },
            { id = 16243, lvl =  1, name = 'Drovers Mantle' },
        },
        EAR =
        {
            { id = 26117, lvl = 99, name = 'Crep. Earring' },
            { id = 26118, lvl = 99, name = 'Sroda Earring' },
            { id = 27540, lvl = 99, name = 'Eabani Earring' },
            { id = 16056, lvl = 75, name = 'Pagondas Earring' },
            { id = 16058, lvl = 75, name = 'Colossuss Earring' },
            { id = 15994, lvl = 67, name = 'Harmonius Earring' },
            { id = 15961, lvl = 70, name = 'Musical Earring' },
            { id = 14761, lvl = 60, name = 'Elusive Earring' },
            { id = 13397, lvl = 60, name = 'Ptm. Earring +1' },
            { id = 15970, lvl = 50, name = 'Stoic Earring' },
            { id = 15972, lvl = 50, name = 'Insomnia Earring' },
            { id = 14806, lvl = 40, name = 'Intruder Earring' },
            { id = 13405, lvl = 40, name = 'Enhancing Earring' },
            { id = 13404, lvl = 39, name = 'Nemesis Earring' },
            { id = 16049, lvl = 40, name = 'Empire Earring' },
            { id = 11043, lvl = 30, name = 'Giants Earring' },
            { id = 13366, lvl = 29, name = 'Dodge Earring' },
            { id = 13365, lvl = 20, name = 'Shield Earring' },
            { id = 14757, lvl = 20, name = 'Mecurial Earring' },
            { id = 14695, lvl = 10, name = 'Hope Earring +1' },
            { id = 13380, lvl = 10, name = 'Hope Earring' },
            { id = 13402, lvl =  1, name = 'Cassie Earring' },
            { id = 28510, lvl =  1, name = 'M. Slime Earring' },
        },
        RING =
        {
            { id = 26190, lvl = 99, name = 'Moonlight Ring' },
            { id = 26191, lvl = 99, name = 'Regal Ring' },
            { id = 26186, lvl = 99, name = 'Ilabrat Ring' },
            { id = 10798, lvl = 99, name = 'Eihwaz Ring' },
            { id = 28584, lvl = 99, name = 'Vexer Ring +1' },
            { id = 13566, lvl = 70, name = 'Defending Ring' },
            { id = 11630, lvl = 75, name = 'Corneus Ring' },
            { id = 15855, lvl = 66, name = 'Krousis Ring +1' },
            { id = 13567, lvl = 57, name = 'Bomb Queen Ring' },
            { id = 11636, lvl = 60, name = 'R.k. Sigil Ring' },
            { id = 15778, lvl = 50, name = 'Unyielding Ring' },
            { id = 13516, lvl = 50, name = 'Phalanx Ring' },
            { id = 15544, lvl = 30, name = 'Sattva Ring' },
            { id = 14650, lvl = 40, name = 'Marksmans Ring' },
            { id = 28568, lvl = 30, name = 'Resolution Ring' },
            { id = 13506, lvl = 16, name = 'Bomb Ring' },
            { id = 14653, lvl = 20, name = 'Variable Ring' },
            { id = 14670, lvl = 10, name = 'Safeguard Ring' },
            { id = 15790, lvl = 10, name = 'Multiple Ring' },
            { id = 13497, lvl =  1, name = 'Bastokan Ring' },
            { id = 13495, lvl =  1, name = 'San Dorian Ring' },
        },
    },
    ranged =
    {
        HEAD =
        {
            { id = 23095, lvl = 99, name = 'Amini Gapette +2' },
            { id = 23101, lvl = 99, name = 'Chasseurs Tricorne +2' },
            { id = 25575, lvl = 99, name = 'Meghanada Visor +2' },
            { id = 23761, lvl = 99, name = 'Nyame Helm' },
            { id = 11467, lvl = 74, name = 'Cor. Tricorne +1' },
            { id = 16159, lvl = 71, name = 'Zhagos Barbut' },
            { id = 16126, lvl = 70, name = 'Bowmans Mask' },
            { id = 13919, lvl = 70, name = 'Feral Mask' },
            { id = 15266, lvl = 60, name = 'Corsairs Tricorne' },
            { id = 15263, lvl = 70, name = 'Hydra Cap' },
            { id = 16067, lvl = 59, name = 'Abtal Turban' },
            { id = 15221, lvl = 60, name = 'Patrocluss Helm' },
            { id = 12513, lvl = 60, name = 'Warlocks Chapeau' },
            { id = 15265, lvl = 60, name = 'Magus Keffiyeh' },
            { id = 12518, lvl = 54, name = 'Hunters Beret' },
            { id = 13856, lvl = 60, name = 'Wizards Petasos' },
            { id = 12439, lvl = 59, name = 'Bascinet +1' },
            { id = 15267, lvl = 60, name = 'Pup. Taj' },
            { id = 12520, lvl = 60, name = 'Evokers Horn' },
            { id = 16140, lvl = 60, name = 'Scholars M.board' },
            { id = 11498, lvl = 59, name = 'Zeal Cap +1' },
            { id = 16143, lvl = 55, name = 'Cobra Hat' },
            { id = 12478, lvl = 50, name = 'Tct.mgc. Hat' },
            { id = 15243, lvl = 50, name = 'Raven Beret' },
            { id = 13847, lvl = 49, name = 'Mythril Sallet +1' },
            { id = 16066, lvl = 50, name = 'Storm Turban' },
            { id = 13831, lvl = 40, name = 'Sallet +1' },
            { id = 15219, lvl = 39, name = 'Sinister Mask' },
            { id = 12462, lvl = 40, name = 'Tora Hachimaki' },
            { id = 12481, lvl = 38, name = 'Cuir Bandana +1' },
            { id = 15172, lvl = 30, name = 'Noct Beret +1' },
            { id = 15171, lvl = 29, name = 'Kampfschaller' },
            { id = 12431, lvl = 30, name = 'Ryl. Squires Helm' },
            { id = 12470, lvl = 30, name = 'Mrc.cpt. Headgear' },
            { id = 13830, lvl = 30, name = 'Lgn. Circlet' },
            { id = 12484, lvl = 20, name = 'Mrc. Hachimaki' },
            { id = 15186, lvl = 20, name = 'Trump Crown' },
            { id = 12510, lvl = 10, name = 'Ryl.ftm. Bandana' },
            { id = 12509, lvl = 10, name = 'Legionnaires Cap' },
            { id = 16145, lvl = 10, name = 'Lunar Cap' },
            { id = 11811, lvl =  1, name = 'Destrier Beret' },
        },
        BODY =
        {
            { id = 23168, lvl = 99, name = 'Chasseurs Frac +2' },
            { id = 23162, lvl = 99, name = 'Amini Caban +2' },
            { id = 23142, lvl = 99, name = 'Mochi. Chainmail +2' },
            { id = 23768, lvl = 99, name = 'Nyame Mail' },
            { id = 14550, lvl = 75, name = 'Skadis Cuirie' },
            { id = 12562, lvl = 75, name = 'Kirins Osode' },
            { id = 14569, lvl = 75, name = 'Denali Jacket' },
            { id = 14540, lvl = 70, name = 'Kyudogi +1' },
            { id = 14554, lvl = 75, name = 'Usukane Haramaki' },
            { id = 14546, lvl = 75, name = 'Ares Cuirass' },
            { id = 14530, lvl = 72, name = 'Pln. Khazagand' },
            { id = 14562, lvl = 75, name = 'Morrigans Robe' },
            { id = 13776, lvl = 69, name = 'Blue Cotehard. +1' },
            { id = 13773, lvl = 70, name = 'Carnage Aketon' },
            { id = 14570, lvl = 75, name = 'Goliard Saio' },
            { id = 14589, lvl = 68, name = 'Fourth Brunne' },
            { id = 14590, lvl = 68, name = 'Cobra Harness' },
            { id = 14528, lvl = 59, name = 'Abtal Jawshan' },
            { id = 12648, lvl = 58, name = 'Hunters Jerkin' },
            { id = 14522, lvl = 58, name = 'Corsairs Frac' },
            { id = 14516, lvl = 70, name = 'Hydra Harness' },
            { id = 14515, lvl = 70, name = 'Hydra Doublet' },
            { id = 13743, lvl = 60, name = 'Aketon +1' },
            { id = 13755, lvl = 59, name = 'Flora Cotehardie' },
            { id = 14404, lvl = 50, name = 'Shm. Hara-ate' },
            { id = 14406, lvl = 50, name = 'Shikaree Aketon' },
            { id = 14402, lvl = 50, name = 'Nokizaru Gi' },
            { id = 14412, lvl = 50, name = 'Parade Cuirass' },
            { id = 14411, lvl = 50, name = 'Aikido Gi' },
            { id = 14403, lvl = 50, name = 'Rapparee Harness' },
            { id = 12550, lvl = 50, name = 'Irn.msk. Cuirass' },
            { id = 14405, lvl = 50, name = 'Wyvern Mail' },
            { id = 12606, lvl = 50, name = 'Tct.mgc. Coat' },
            { id = 14499, lvl = 50, name = 'Raven Jupon' },
            { id = 13721, lvl = 40, name = 'Irn.msk. Gambison' },
            { id = 13724, lvl = 40, name = 'Breastplate +1' },
            { id = 12559, lvl = 40, name = 'Ryl.sqr. Chainmail' },
            { id = 13719, lvl = 40, name = 'Ryl.sqr. Robe' },
            { id = 14435, lvl = 29, name = 'Kampfbrust' },
            { id = 14434, lvl = 30, name = 'Noct Doublet +1' },
            { id = 12598, lvl = 30, name = 'Mrc.cpt. Doublet' },
            { id = 13707, lvl = 30, name = 'Strong Vest' },
            { id = 14427, lvl = 29, name = 'Seers Tunic +1' },
            { id = 12653, lvl = 20, name = 'Mercenarys Gi' },
            { id = 14447, lvl = 20, name = 'Barons Saio' },
            { id = 13818, lvl = 18, name = 'Garrison Tunica' },
            { id = 12661, lvl = 10, name = 'Solid Mail' },
            { id = 12629, lvl = 10, name = 'Lgn. Harness' },
            { id = 12630, lvl = 10, name = 'Ryl.ftm. Vest' },
            { id = 12607, lvl =  1, name = 'Bronze Harness +1' },
            { id = 14400, lvl =  1, name = 'Fishermans Apron' },
        },
        HANDS =
        {
            { id = 23229, lvl = 99, name = 'Amini Glovelettes +2' },
            { id = 23235, lvl = 99, name = 'Chasseurs Gants +2' },
            { id = 23230, lvl = 99, name = 'Kasuga Kote +2' },
            { id = 23521, lvl = 99, name = 'Hachiya Tekko +3' },
            { id = 23734, lvl = 99, name = 'Malignance Gloves' },
            { id = 25803, lvl = 99, name = 'Meg. Gloves +1' },
            { id = 23775, lvl = 99, name = 'Nyame Gauntlets' },
            { id = 14902, lvl = 74, name = 'Nin. Tekko +1' },
            { id = 12690, lvl = 75, name = 'Seiryus Kote' },
            { id = 14059, lvl = 73, name = 'Blood Fng. Gnt.' },
            { id = 14965, lvl = 75, name = 'Skadis Bazubands' },
            { id = 14943, lvl = 73, name = 'Barb. Moufles' },
            { id = 14878, lvl = 70, name = 'Hachiman Kote +1' },
            { id = 15030, lvl = 74, name = 'Pup. Dastanas +1' },
            { id = 14959, lvl = 70, name = 'Mrc. Dastanas' },
            { id = 14892, lvl = 74, name = 'Hlr. Mitts +1' },
            { id = 13973, lvl = 60, name = 'Ninja Tekko' },
            { id = 14022, lvl = 70, name = 'Alkyoneuss Brc.' },
            { id = 14977, lvl = 75, name = 'Morrigans Cuffs' },
            { id = 14973, lvl = 75, name = 'Marduks Dastanas' },
            { id = 14985, lvl = 75, name = 'Goliard Cuffs' },
            { id = 14999, lvl = 70, name = 'Vampiric Mitts' },
            { id = 15017, lvl = 70, name = 'Toad Mittens' },
            { id = 14938, lvl = 59, name = 'Abtal Dastanas' },
            { id = 14944, lvl = 60, name = 'Deadeye Gloves' },
            { id = 14021, lvl = 60, name = 'Pallass Bracelets' },
            { id = 13963, lvl = 60, name = 'Healers Mitts' },
            { id = 13977, lvl = 57, name = 'Light Gauntlets' },
            { id = 14020, lvl = 50, name = 'Enkeladoss Brc.' },
            { id = 27939, lvl = 45, name = 'Idis Gloves' },
            { id = 14936, lvl = 50, name = 'Storm Manopolas' },
            { id = 12678, lvl = 40, name = 'Irn.msk. Gauntlets' },
            { id = 14019, lvl = 40, name = 'Ogygoss Brc.' },
            { id = 12793, lvl = 38, name = 'Mages Cuffs' },
            { id = 14865, lvl = 30, name = 'Noct Gloves +1' },
            { id = 14018, lvl = 30, name = 'Gigas Bracelets' },
            { id = 12726, lvl = 30, name = 'Mrc.cpt. Gloves' },
            { id = 12782, lvl = 28, name = 'Wool Cuffs +1' },
            { id = 14054, lvl = 20, name = 'Barons Cuffs' },
            { id = 12719, lvl = 20, name = 'Mrc. Tekko' },
            { id = 13953, lvl = 20, name = 'White Mitts +1' },
            { id = 14841, lvl = 20, name = 'Garrison Gloves' },
            { id = 12768, lvl = 10, name = 'Solid Fng. Gnt.' },
            { id = 12752, lvl = 10, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, name = 'Ryl.ftm. Gloves' },
            { id = 12775, lvl =  8, name = 'Mitts +1' },
            { id = 14831, lvl =  1, name = 'Smithys Mitts' },
        },
        LEGS =
        {
            { id = 23296, lvl = 99, name = 'Amini Bragues +2' },
            { id = 23302, lvl = 99, name = 'Chasseurs Culottes +2' },
            { id = 25880, lvl = 99, name = 'Meg. Chausses +2' },
            { id = 23782, lvl = 99, name = 'Nyame Flanchard' },
            { id = 15629, lvl = 75, name = 'Skadis Chausses' },
            { id = 14307, lvl = 72, name = 'Dusk Trousers +1' },
            { id = 16337, lvl = 75, name = 'Hachiryu Haidate' },
            { id = 16343, lvl = 72, name = 'Enkidus Subligar' },
            { id = 15387, lvl = 70, name = 'Trackers Kecks' },
            { id = 14238, lvl = 70, name = 'War Brais +1' },
            { id = 15641, lvl = 75, name = 'Morrigans Slops' },
            { id = 15394, lvl = 70, name = 'Hmn. Hakama +1' },
            { id = 15649, lvl = 75, name = 'Goliard Trews' },
            { id = 14318, lvl = 70, name = 'Conte Cosciales' },
            { id = 14279, lvl = 70, name = 'Ogre Trousers +1' },
            { id = 15399, lvl = 70, name = 'Kings Cuisses' },
            { id = 15624, lvl = 70, name = 'Mrc. Subligar' },
            { id = 15598, lvl = 70, name = 'Hydra Hose' },
            { id = 15607, lvl = 59, name = 'Abtal Zerehs' },
            { id = 14226, lvl = 52, name = 'Ninja Hakama' },
            { id = 14219, lvl = 56, name = 'Rogues Culottes' },
            { id = 15608, lvl = 55, name = 'Akinji Salvars' },
            { id = 14215, lvl = 60, name = 'Temple Hose' },
            { id = 14334, lvl = 50, name = 'Shm. Haidate' },
            { id = 14216, lvl = 56, name = 'Healers Pantaln.' },
            { id = 14217, lvl = 56, name = 'Wizards Tonban' },
            { id = 16311, lvl = 56, name = 'Scholars Pants' },
            { id = 16374, lvl = 55, name = 'Layqa Seraweels' },
            { id = 16314, lvl = 55, name = 'Cobra Slops' },
            { id = 14335, lvl = 50, name = 'Nokizaru Hakama' },
            { id = 12806, lvl = 50, name = 'Irn.msk. Cuisses' },
            { id = 15377, lvl = 50, name = 'Gemini Subligar' },
            { id = 15380, lvl = 50, name = 'Virgo Subligar' },
            { id = 14246, lvl = 50, name = 'Steel Cuisses +1' },
            { id = 15367, lvl = 50, name = 'Falconers Hose' },
            { id = 15371, lvl = 50, name = 'Dst. Codpiece' },
            { id = 12925, lvl = 49, name = 'Shn. Hakama +1' },
            { id = 15375, lvl = 50, name = 'Aries Subligar' },
            { id = 15381, lvl = 50, name = 'Libra Subligar' },
            { id = 15382, lvl = 50, name = 'Scorpius Subligar' },
            { id = 15384, lvl = 50, name = 'Capri. Subligar' },
            { id = 15388, lvl = 50, name = 'Ophiu. Subligar' },
            { id = 12815, lvl = 40, name = 'Ryl.sqr. Breeches' },
            { id = 14244, lvl = 40, name = 'Iron Cuisses +1' },
            { id = 12870, lvl = 40, name = 'Cmb.cst. Slacks' },
            { id = 12911, lvl = 38, name = 'Cuir Trousers +1' },
            { id = 12822, lvl = 30, name = 'Ctr. Cuisses' },
            { id = 14333, lvl = 30, name = 'Noct Brais +1' },
            { id = 12910, lvl = 30, name = 'Strong Trousers' },
            { id = 14330, lvl = 30, name = 'Rubious Slacks' },
            { id = 12854, lvl = 30, name = 'Mrc.cpt. Hose' },
            { id = 28202, lvl = 30, name = 'Dredger Hose' },
            { id = 12882, lvl = 20, name = 'Ryl.ftm. Trousers' },
            { id = 15405, lvl = 20, name = 'Barons Slops' },
            { id = 12863, lvl = 10, name = 'Solid Cuisses' },
            { id = 12915, lvl = 10, name = 'Freeswords Slops' },
            { id = 12899, lvl =  8, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, name = 'Brz. Subligar +1' },
            { id = 12897, lvl =  1, name = 'Slops +1' },
        },
        FEET =
        {
            { id = 23676, lvl = 99, name = 'Arcadian Socks +3' },
            { id = 23369, lvl = 99, name = 'Chasseurs Bottes +2' },
            { id = 23789, lvl = 99, name = 'Nyame Sollerets' },
            { id = 11384, lvl = 74, name = 'Cor. Bottes +1' },
            { id = 11364, lvl = 75, name = 'Hachiryu Sune-ate' },
            { id = 15719, lvl = 75, name = 'Usukane Sune-ate' },
            { id = 15661, lvl = 75, name = 'Homam Gambieras' },
            { id = 15715, lvl = 75, name = 'Skadis Jambeaux' },
            { id = 14181, lvl = 73, name = 'Hct. Leggings +1' },
            { id = 11378, lvl = 72, name = 'Enkidus Leggings' },
            { id = 14161, lvl = 73, name = 'Blood Greaves' },
            { id = 15332, lvl = 70, name = 'Hmn. Sune-ate +1' },
            { id = 15354, lvl = 74, name = 'Hlr. Duckbills +1' },
            { id = 15355, lvl = 74, name = 'Wzd. Sabots +1' },
            { id = 14113, lvl = 70, name = 'War Boots +1' },
            { id = 11395, lvl = 74, name = 'Sch. Loafers +1' },
            { id = 15723, lvl = 75, name = 'Marduks Crackows' },
            { id = 15735, lvl = 75, name = 'Goliard Clogs' },
            { id = 15744, lvl = 70, name = 'Bowmans Led.' },
            { id = 15328, lvl = 69, name = 'Root Sabots' },
            { id = 14099, lvl = 60, name = 'Hunters Socks' },
            { id = 15685, lvl = 56, name = 'Corsairs Bottes' },
            { id = 15693, lvl = 59, name = 'Abtal Boots' },
            { id = 14103, lvl = 56, name = 'Evokers Pigaches' },
            { id = 14094, lvl = 60, name = 'Rogues Poulaines' },
            { id = 11373, lvl = 60, name = 'Seirenshi Habaki' },
            { id = 14101, lvl = 54, name = 'Ninja Kyahan' },
            { id = 11404, lvl = 60, name = 'Promptitude Solea' },
            { id = 15323, lvl = 59, name = 'Cure Clogs' },
            { id = 15739, lvl = 59, name = 'Tabin Boots +1' },
            { id = 15338, lvl = 59, name = 'Vampire Boots' },
            { id = 12942, lvl = 50, name = 'Ryl.kgt. Sollerets' },
            { id = 15691, lvl = 50, name = 'Storm Gambieras' },
            { id = 12934, lvl = 40, name = 'Irn.msk. Sabatons' },
            { id = 12998, lvl = 40, name = 'Cmb.cst. Shoes' },
            { id = 15737, lvl = 39, name = 'Sarutobi Kyahan' },
            { id = 15348, lvl = 38, name = 'Mountain Gaiters' },
            { id = 12943, lvl = 30, name = 'Ryl.sqr. Sollerets' },
            { id = 12950, lvl = 30, name = 'Ctr. Greaves' },
            { id = 12982, lvl = 30, name = 'Mrc.cpt. Gaiters' },
            { id = 28341, lvl = 30, name = 'Agrarian Boots' },
            { id = 10648, lvl = 20, name = 'Areion Boots +1' },
            { id = 13045, lvl = 20, name = 'Ryl.ftm. Clogs' },
            { id = 13048, lvl = 20, name = 'Mages Sandals' },
            { id = 12975, lvl = 20, name = 'Mrc. Kyahan' },
            { id = 11412, lvl = 17, name = 'Mtt. Leggings +1' },
            { id = 15351, lvl =  7, name = 'Bounding Boots' },
            { id = 13003, lvl = 10, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, name = 'Solea +1' },
            { id = 14195, lvl =  1, name = 'Waders' },
        },
        NECK =
        {
            { id = 26027, lvl = 99, name = 'Iskur Gorget' },
            { id = 25415, lvl = 99, name = 'Rep. Plat. Medal' },
            { id = 28349, lvl = 75, name = 'Crested Torque' },
            { id = 16299, lvl = 69, name = 'Lleus Charm' },
            { id = 13128, lvl = 59, name = 'Spectacles' },
            { id = 15523, lvl = 60, name = 'Chivalrous Chain' },
            { id = 13165, lvl = 40, name = 'Jagd Gorget' },
            { id = 13107, lvl = 50, name = 'R.k. Army Collar' },
            { id = 13166, lvl = 50, name = 'Hateful Collar' },
            { id = 15515, lvl = 33, name = 'Peacock Amulet' },
            { id = 15504, lvl = 30, name = 'Ajase Beads' },
            { id = 13102, lvl = 30, name = 'Paisley Scarf' },
            { id = 13070, lvl = 30, name = 'Wolf Gorget +1' },
            { id = 13117, lvl = 14, name = 'Rangers Necklace' },
            { id = 13058, lvl = 20, name = 'Bloodbead Amulet' },
            { id = 13101, lvl = 10, name = 'Green Scarf' },
            { id = 13098, lvl = 10, name = 'Rep.bronze Medal' },
            { id = 16273, lvl =  1, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 26338, lvl = 99, name = 'K. Kachina Belt +1' },
            { id = 28411, lvl = 99, name = 'Yemaya Belt' },
            { id = 28415, lvl = 99, name = 'Eschan Stone' },
            { id = 15876, lvl = 70, name = 'Scouts Belt' },
            { id = 15920, lvl = 70, name = 'Commodore Belt' },
            { id = 15911, lvl = 75, name = 'Buccaneers Belt' },
            { id = 15879, lvl = 70, name = 'Sao. Koshi-ate' },
            { id = 13186, lvl = 70, name = 'Black Belt' },
            { id = 15923, lvl = 69, name = 'Grenadier Belt' },
            { id = 15874, lvl = 70, name = 'Sorcerers Belt' },
            { id = 13188, lvl = 70, name = 'Star Sash' },
            { id = 15886, lvl = 60, name = 'Precise Belt' },
            { id = 15945, lvl = 50, name = 'Volant Belt' },
            { id = 13202, lvl = 40, name = 'Brown Belt' },
            { id = 13214, lvl = 40, name = 'Waistbelt +1' },
            { id = 15908, lvl = 40, name = 'Qiqirn Sash +1' },
            { id = 15286, lvl = 40, name = 'Tilt Belt' },
            { id = 13221, lvl = 30, name = 'Mrc.cpt. Belt' },
            { id = 15927, lvl = 30, name = 'Pinwheel Belt' },
            { id = 15285, lvl = 30, name = 'Avatar Belt' },
            { id = 13201, lvl = 18, name = 'Purple Belt' },
            { id = 15906, lvl = 20, name = 'Mohbwa Sash +1' },
            { id = 15880, lvl = 20, name = 'Key Ring Belt' },
            { id = 13225, lvl = 18, name = 'Brave Belt' },
            { id = 13219, lvl = 18, name = 'Magic Belt +1' },
            { id = 13191, lvl = 17, name = 'Lizard Belt +1' },
            { id = 13190, lvl =  8, name = 'Heko Obi +1' },
            { id = 15889, lvl =  7, name = 'Augmenting Belt' },
            { id = 13184, lvl =  1, name = 'White Belt' },
            { id = 13226, lvl =  1, name = 'Blood Stone +1' },
            { id = 15456, lvl =  1, name = 'Dash Sash' },
        },
        BACK =
        {
            { id = 28627, lvl = 99, name = 'Lutian Cape' },
            { id = 28595, lvl = 99, name = 'Moondoe Mantle +1' },
            { id = 26269, lvl = 99, name = 'Moonlight Cape' },
            { id = 11541, lvl = 73, name = 'Fowlers Mantle +1' },
            { id = 15476, lvl = 70, name = 'Jaeger Mantle' },
            { id = 15488, lvl = 70, name = 'Gunners Mantle' },
            { id = 15491, lvl = 60, name = 'Bullseye Cape' },
            { id = 11545, lvl = 60, name = 'Fourth Mantle' },
            { id = 16237, lvl = 50, name = 'Thunderers Mantle' },
            { id = 15483, lvl = 50, name = 'Storm Mantle' },
            { id = 13674, lvl = 40, name = 'Agile Mantle' },
            { id = 13675, lvl = 40, name = 'Rearguard Mantle' },
            { id = 15468, lvl = 40, name = 'Resentment Cape' },
            { id = 13625, lvl = 39, name = 'Tundra Mantle' },
            { id = 13644, lvl = 30, name = 'Midnight Cape' },
            { id = 13673, lvl = 30, name = 'Magicians Mantle' },
            { id = 13680, lvl = 20, name = 'Variable Mantle' },
            { id = 13681, lvl = 20, name = 'Variable Cape' },
            { id = 13607, lvl = 10, name = 'Mist Silk Cape' },
            { id = 13599, lvl =  4, name = 'Rabbit Mantle +1' },
            { id = 16243, lvl =  1, name = 'Drovers Mantle' },
        },
        EAR =
        {
            { id = 26117, lvl = 99, name = 'Crep. Earring' },
            { id = 26118, lvl = 99, name = 'Sroda Earring' },
            { id = 28479, lvl = 99, name = 'Enervating Earring' },
            { id = 15988, lvl = 75, name = 'Beta Earring' },
            { id = 16056, lvl = 75, name = 'Pagondas Earring' },
            { id = 14762, lvl = 70, name = 'Attilas Earring' },
            { id = 15979, lvl = 70, name = 'Fowling Earring' },
            { id = 16013, lvl = 70, name = 'Stellar Earring' },
            { id = 15994, lvl = 67, name = 'Harmonius Earring' },
            { id = 15966, lvl = 60, name = 'Silver Fox Earring' },
            { id = 16035, lvl = 60, name = 'Altdorfs Earring' },
            { id = 15973, lvl = 50, name = 'Vision Earring' },
            { id = 15970, lvl = 50, name = 'Stoic Earring' },
            { id = 14806, lvl = 40, name = 'Intruder Earring' },
            { id = 13405, lvl = 40, name = 'Enhancing Earring' },
            { id = 16049, lvl = 40, name = 'Empire Earring' },
            { id = 11043, lvl = 30, name = 'Giants Earring' },
            { id = 16046, lvl = 30, name = 'Kazham Earring' },
            { id = 13365, lvl = 20, name = 'Shield Earring' },
            { id = 14757, lvl = 20, name = 'Mecurial Earring' },
            { id = 14695, lvl = 10, name = 'Hope Earring +1' },
            { id = 13380, lvl = 10, name = 'Hope Earring' },
            { id = 13402, lvl =  1, name = 'Cassie Earring' },
            { id = 28510, lvl =  1, name = 'M. Slime Earring' },
        },
        RING =
        {
            { id = 26191, lvl = 99, name = 'Regal Ring' },
            { id = 26187, lvl = 99, name = 'Dingir Ring' },
            { id = 26192, lvl = 99, name = 'Adoulin Ring +1' },
            { id = 26198, lvl = 99, name = 'Haverton Ring +1' },
            { id = 15549, lvl = 75, name = 'Bellonas Ring' },
            { id = 14627, lvl = 73, name = 'Dragon Ring +1' },
            { id = 13556, lvl = 70, name = 'Behemoth Ring +1' },
            { id = 13460, lvl = 70, name = 'Behemoth Ring' },
            { id = 13513, lvl = 55, name = 'Scorpion Ring +1' },
            { id = 13458, lvl = 55, name = 'Scorpion Ring' },
            { id = 15809, lvl = 50, name = 'Jalzahns Ring' },
            { id = 15779, lvl = 50, name = 'Garrulous Ring' },
            { id = 14650, lvl = 40, name = 'Marksmans Ring' },
            { id = 13281, lvl = 40, name = 'Snipers Ring +1' },
            { id = 15543, lvl = 30, name = 'Rajas Ring' },
            { id = 14660, lvl = 29, name = 'Bowyer Ring' },
            { id = 14652, lvl = 20, name = 'Protean Ring' },
            { id = 14653, lvl = 20, name = 'Variable Ring' },
            { id = 14670, lvl = 10, name = 'Safeguard Ring' },
            { id = 15790, lvl = 10, name = 'Multiple Ring' },
            { id = 13495, lvl =  1, name = 'San Dorian Ring' },
            { id = 13496, lvl =  1, name = 'Windurstian Ring' },
        },
    },
    caster =
    {
        HEAD =
        {
            { id = 23089, lvl = 99, name = 'Lethargy Chappel +2' },
            { id = 23401, lvl = 99, name = 'Arch. Petasos +3' },
            { id = 23104, lvl = 99, name = 'Arbatel Bonnet +2' },
            { id = 23105, lvl = 99, name = 'Azimuth Hood +2' },
            { id = 23100, lvl = 99, name = 'Hashishin Kavuk +2' },
            { id = 23760, lvl = 99, name = 'Bunzis Hat' },
            { id = 23759, lvl = 99, name = 'Agwus Cap' },
            { id = 23761, lvl = 99, name = 'Nyame Helm' },
            { id = 15229, lvl = 74, name = 'Wlk. Chapeau +1' },
            { id = 15233, lvl = 74, name = 'Bst. Helm +1' },
            { id = 16100, lvl = 75, name = 'Morrigans Coron.' },
            { id = 15239, lvl = 74, name = 'Evk. Horn +1' },
            { id = 16116, lvl = 75, name = 'Valkyries Hat' },
            { id = 15240, lvl = 75, name = 'Homam Zucchetto' },
            { id = 16108, lvl = 75, name = 'Goliard Chapeau' },
            { id = 15226, lvl = 74, name = 'Tpl. Crown +1' },
            { id = 13930, lvl = 72, name = 'Mahatma Hat' },
            { id = 12513, lvl = 60, name = 'Warlocks Chapeau' },
            { id = 15192, lvl = 71, name = 'Yasha Jinpachi +1' },
            { id = 15255, lvl = 75, name = 'Sct. Beret +1' },
            { id = 16114, lvl = 75, name = 'Valkyries Helm' },
            { id = 15236, lvl = 74, name = 'Myn. Kabuto +1' },
            { id = 16160, lvl = 71, name = 'Rees Headgear' },
            { id = 16081, lvl = 68, name = 'Curates Hat' },
            { id = 16129, lvl = 68, name = 'Wivre Hairpin +1' },
            { id = 15265, lvl = 60, name = 'Magus Keffiyeh' },
            { id = 13856, lvl = 60, name = 'Wizards Petasos' },
            { id = 16140, lvl = 60, name = 'Scholars M.board' },
            { id = 12520, lvl = 60, name = 'Evokers Horn' },
            { id = 13868, lvl = 60, name = 'Myochin Kabuto' },
            { id = 12519, lvl = 60, name = 'Drachen Armet' },
            { id = 12517, lvl = 56, name = 'Beast Helm' },
            { id = 12512, lvl = 56, name = 'Temple Crown' },
            { id = 15267, lvl = 60, name = 'Pup. Taj' },
            { id = 12514, lvl = 54, name = 'Rogues Bonnet' },
            { id = 13855, lvl = 54, name = 'Healers Cap' },
            { id = 12516, lvl = 60, name = 'Chaos Burgeonet' },
            { id = 12515, lvl = 56, name = 'Gallant Coronet' },
            { id = 13848, lvl = 60, name = 'Gilt Armet' },
            { id = 15266, lvl = 60, name = 'Corsairs Tricorne' },
            { id = 15221, lvl = 60, name = 'Patrocluss Helm' },
            { id = 12439, lvl = 59, name = 'Bascinet +1' },
            { id = 12518, lvl = 54, name = 'Hunters Beret' },
            { id = 16080, lvl = 53, name = 'Magi Hat' },
            { id = 16066, lvl = 50, name = 'Storm Turban' },
            { id = 13831, lvl = 40, name = 'Sallet +1' },
            { id = 12462, lvl = 40, name = 'Tora Hachimaki' },
            { id = 15219, lvl = 39, name = 'Sinister Mask' },
            { id = 12481, lvl = 38, name = 'Cuir Bandana +1' },
            { id = 11494, lvl = 30, name = 'Circes Hat' },
            { id = 13824, lvl = 30, name = 'Strong Bandana' },
            { id = 15168, lvl = 30, name = 'Rubious Crown' },
            { id = 15208, lvl = 20, name = 'Barons Chapeau' },
            { id = 15186, lvl = 20, name = 'Trump Crown' },
            { id = 12509, lvl = 10, name = 'Legionnaires Cap' },
            { id = 12487, lvl = 10, name = 'Faceguard +1' },
            { id = 16145, lvl = 10, name = 'Lunar Cap' },
            { id = 11811, lvl =  1, name = 'Destrier Beret' },
        },
        BODY =
        {
            { id = 23155, lvl = 99, name = 'Wicce Coat +2' },
            { id = 23172, lvl = 99, name = 'Azimuth Coat +2' },
            { id = 23171, lvl = 99, name = 'Arbatel Gown +2' },
            { id = 23156, lvl = 99, name = 'Lethargy Sayon +2' },
            { id = 23167, lvl = 99, name = 'Hashishin Mintan +2' },
            { id = 23714, lvl = 99, name = 'Volte Doublet' },
            { id = 23766, lvl = 99, name = 'Agwus Robe' },
            { id = 23768, lvl = 99, name = 'Nyame Mail' },
            { id = 14368, lvl = 73, name = 'Blood Scale Mail' },
            { id = 12562, lvl = 75, name = 'Kirins Osode' },
            { id = 14562, lvl = 75, name = 'Morrigans Robe' },
            { id = 14381, lvl = 72, name = 'Mahatma Hpl.' },
            { id = 14488, lvl = 75, name = 'Homam Corazza' },
            { id = 14591, lvl = 68, name = 'Cobra Robe' },
            { id = 11286, lvl = 71, name = 'Avalon Breastplate' },
            { id = 13794, lvl = 70, name = 'Heavy Cuirass' },
            { id = 14366, lvl = 70, name = 'Ogre Jerkin +1' },
            { id = 13762, lvl = 70, name = 'Dragon Mail +1' },
            { id = 13773, lvl = 70, name = 'Carnage Aketon' },
            { id = 13771, lvl = 70, name = 'War Aketon +1' },
            { id = 14439, lvl = 70, name = 'Hmn. Domaru +1' },
            { id = 14516, lvl = 70, name = 'Hydra Harness' },
            { id = 13745, lvl = 58, name = 'Justaucorps +1' },
            { id = 12638, lvl = 60, name = 'Fighters Lorica' },
            { id = 12644, lvl = 60, name = 'Gallant Surcoat' },
            { id = 14528, lvl = 59, name = 'Abtal Jawshan' },
            { id = 13743, lvl = 60, name = 'Aketon +1' },
            { id = 13735, lvl = 59, name = 'Haubergeon +1' },
            { id = 14412, lvl = 50, name = 'Parade Cuirass' },
            { id = 12606, lvl = 50, name = 'Tct.mgc. Coat' },
            { id = 14404, lvl = 50, name = 'Shm. Hara-ate' },
            { id = 14405, lvl = 50, name = 'Wyvern Mail' },
            { id = 14402, lvl = 50, name = 'Nokizaru Gi' },
            { id = 14499, lvl = 50, name = 'Raven Jupon' },
            { id = 13813, lvl = 40, name = 'Divine Breastplate' },
            { id = 13719, lvl = 40, name = 'Ryl.sqr. Robe' },
            { id = 13724, lvl = 40, name = 'Breastplate +1' },
            { id = 12559, lvl = 40, name = 'Ryl.sqr. Chainmail' },
            { id = 13721, lvl = 40, name = 'Irn.msk. Gambison' },
            { id = 13707, lvl = 30, name = 'Strong Vest' },
            { id = 14427, lvl = 29, name = 'Seers Tunic +1' },
            { id = 14432, lvl = 30, name = 'Rubious Tunic' },
            { id = 14447, lvl = 20, name = 'Barons Saio' },
            { id = 12653, lvl = 20, name = 'Mercenarys Gi' },
            { id = 13818, lvl = 18, name = 'Garrison Tunica' },
            { id = 12661, lvl = 10, name = 'Solid Mail' },
            { id = 12629, lvl = 10, name = 'Lgn. Harness' },
            { id = 12630, lvl = 10, name = 'Ryl.ftm. Vest' },
            { id = 14586, lvl =  1, name = 'Cobra Tunica' },
        },
        HANDS =
        {
            { id = 23222, lvl = 99, name = 'Wicce Gloves +2' },
            { id = 23234, lvl = 99, name = 'Hashishin Bazubands +2' },
            { id = 23239, lvl = 99, name = 'Azimuth Gloves +2' },
            { id = 23238, lvl = 99, name = 'Arbatel Bracers +2' },
            { id = 23223, lvl = 99, name = 'Lethargy Gantherots +2' },
            { id = 23773, lvl = 99, name = 'Agwus Gages' },
            { id = 23718, lvl = 99, name = 'Volte Gloves' },
            { id = 23775, lvl = 99, name = 'Nyame Gauntlets' },
            { id = 14977, lvl = 75, name = 'Morrigans Cuffs' },
            { id = 14916, lvl = 75, name = 'Abs. Gauntlets +1' },
            { id = 15041, lvl = 75, name = 'Argute Bracers +1' },
            { id = 14935, lvl = 72, name = 'Yigit Gages' },
            { id = 14985, lvl = 75, name = 'Goliard Cuffs' },
            { id = 14079, lvl = 72, name = 'Mahatma Cuffs' },
            { id = 14877, lvl = 70, name = 'Blessed Mitts +1' },
            { id = 14996, lvl = 75, name = 'Valk. Gauntlets' },
            { id = 14905, lvl = 75, name = 'Homam Manopolas' },
            { id = 14059, lvl = 73, name = 'Blood Fng. Gnt.' },
            { id = 12690, lvl = 75, name = 'Seiryus Kote' },
            { id = 14984, lvl = 75, name = 'Denali Wristbands' },
            { id = 14951, lvl = 68, name = 'Dragon Kote' },
            { id = 15013, lvl = 70, name = 'Vicious Mufflers' },
            { id = 15017, lvl = 70, name = 'Toad Mittens' },
            { id = 14022, lvl = 70, name = 'Alkyoneuss Brc.' },
            { id = 14021, lvl = 60, name = 'Pallass Bracelets' },
            { id = 13963, lvl = 60, name = 'Healers Mitts' },
            { id = 14867, lvl = 56, name = 'Magical Mitts' },
            { id = 14842, lvl = 50, name = 'Ivory Mitts' },
            { id = 14845, lvl = 50, name = 'Sly Gauntlets' },
            { id = 14937, lvl = 50, name = 'Storm Gages' },
            { id = 14019, lvl = 40, name = 'Ogygoss Brc.' },
            { id = 12743, lvl = 40, name = 'Cmb.cst. Mitts' },
            { id = 14859, lvl = 29, name = 'Seers Mitts +1' },
            { id = 14025, lvl = 27, name = 'Dvt. Mitts +1' },
            { id = 14018, lvl = 30, name = 'Gigas Bracelets' },
            { id = 14062, lvl = 20, name = 'Carbuncle Mitts' },
            { id = 14054, lvl = 20, name = 'Barons Cuffs' },
            { id = 14841, lvl = 20, name = 'Garrison Gloves' },
            { id = 12768, lvl = 10, name = 'Solid Fng. Gnt.' },
            { id = 12752, lvl = 10, name = 'Lgn. Mittens' },
            { id = 12753, lvl = 10, name = 'Ryl.ftm. Gloves' },
            { id = 12775, lvl =  8, name = 'Mitts +1' },
            { id = 14831, lvl =  1, name = 'Smithys Mitts' },
        },
        LEGS =
        {
            { id = 23289, lvl = 99, name = 'Wicce Chausses +2' },
            { id = 23290, lvl = 99, name = 'Lethargy Fuseau +2' },
            { id = 23306, lvl = 99, name = 'Azimuth Tights +2' },
            { id = 23305, lvl = 99, name = 'Arbatel Pants +2' },
            { id = 23301, lvl = 99, name = 'Hashishin Tayt +2' },
            { id = 23722, lvl = 99, name = 'Volte Brais' },
            { id = 23780, lvl = 99, name = 'Agwus Slops' },
            { id = 23782, lvl = 99, name = 'Nyame Flanchard' },
            { id = 15641, lvl = 75, name = 'Morrigans Slops' },
            { id = 15656, lvl = 75, name = 'Valkyries Cuishes' },
            { id = 14302, lvl = 72, name = 'Mahatma Slops' },
            { id = 15576, lvl = 75, name = 'Homam Cosciales' },
            { id = 16319, lvl = 74, name = 'Sangoma Lappa' },
            { id = 15647, lvl = 75, name = 'Askar Dirs' },
            { id = 15393, lvl = 70, name = 'Bls. Trousers +1' },
            { id = 15619, lvl = 71, name = 'Princes Slops' },
            { id = 14279, lvl = 70, name = 'Ogre Trousers +1' },
            { id = 16318, lvl = 68, name = 'Cobra Trews' },
            { id = 15597, lvl = 70, name = 'Hydra Brayettes' },
            { id = 15624, lvl = 70, name = 'Mrc. Subligar' },
            { id = 14238, lvl = 70, name = 'War Brais +1' },
            { id = 14218, lvl = 56, name = 'Warlocks Tights' },
            { id = 14224, lvl = 56, name = 'Hunters Braccae' },
            { id = 14221, lvl = 56, name = 'Chaos Flanchard' },
            { id = 14215, lvl = 60, name = 'Temple Hose' },
            { id = 14222, lvl = 60, name = 'Beast Trousers' },
            { id = 14212, lvl = 60, name = 'Gilt Cuisses' },
            { id = 14209, lvl = 59, name = 'Dst. Breeches +1' },
            { id = 15607, lvl = 59, name = 'Abtal Zerehs' },
            { id = 16311, lvl = 56, name = 'Scholars Pants' },
            { id = 14311, lvl = 50, name = 'Penance Slops' },
            { id = 14216, lvl = 56, name = 'Healers Pantaln.' },
            { id = 15612, lvl = 60, name = 'Strike Subligar' },
            { id = 14217, lvl = 56, name = 'Wizards Tonban' },
            { id = 16374, lvl = 55, name = 'Layqa Seraweels' },
            { id = 12924, lvl = 48, name = 'Magic Cuisses' },
            { id = 16314, lvl = 55, name = 'Cobra Slops' },
            { id = 15382, lvl = 50, name = 'Scorpius Subligar' },
            { id = 12926, lvl = 50, name = 'White Slacks +1' },
            { id = 14335, lvl = 50, name = 'Nokizaru Hakama' },
            { id = 15377, lvl = 50, name = 'Gemini Subligar' },
            { id = 15380, lvl = 50, name = 'Virgo Subligar' },
            { id = 15372, lvl = 40, name = 'Magic Slacks' },
            { id = 12916, lvl = 40, name = 'Cuisses +1' },
            { id = 12815, lvl = 40, name = 'Ryl.sqr. Breeches' },
            { id = 14244, lvl = 40, name = 'Iron Cuisses +1' },
            { id = 12870, lvl = 40, name = 'Cmb.cst. Slacks' },
            { id = 12911, lvl = 38, name = 'Cuir Trousers +1' },
            { id = 14328, lvl = 29, name = 'Seers Slacks +1' },
            { id = 12910, lvl = 30, name = 'Strong Trousers' },
            { id = 14330, lvl = 30, name = 'Rubious Slacks' },
            { id = 12917, lvl = 20, name = 'Mages Slacks' },
            { id = 12882, lvl = 20, name = 'Ryl.ftm. Trousers' },
            { id = 12863, lvl = 10, name = 'Solid Cuisses' },
            { id = 12915, lvl = 10, name = 'Freeswords Slops' },
            { id = 12899, lvl =  8, name = 'Sitabaki +1' },
            { id = 12823, lvl =  1, name = 'Brz. Subligar +1' },
            { id = 12897, lvl =  1, name = 'Slops +1' },
        },
        FEET =
        {
            { id = 23670, lvl = 99, name = 'Vitiation Boots +3' },
            { id = 23368, lvl = 99, name = 'Hashishin Basmak +2' },
            { id = 23372, lvl = 99, name = 'Arbatel Loafers +2' },
            { id = 23669, lvl = 99, name = 'Arch. Sabots +3' },
            { id = 23373, lvl = 99, name = 'Azimuth Gaiters +2' },
            { id = 23787, lvl = 99, name = 'Agwus Pigaches' },
            { id = 23788, lvl = 99, name = 'Bunzis Sabots' },
            { id = 23360, lvl = 99, name = 'Heathens Sollerets +2' },
            { id = 23682, lvl = 99, name = 'Lanun Bottes +3' },
            { id = 23789, lvl = 99, name = 'Nyame Sollerets' },
            { id = 12946, lvl = 75, name = 'Suzakus Sune-ate' },
            { id = 15727, lvl = 75, name = 'Morrigans Pgch.' },
            { id = 15350, lvl = 75, name = 'Rostrum Pumps' },
            { id = 15734, lvl = 75, name = 'Denali Gamashes' },
            { id = 15359, lvl = 74, name = 'Chs. Sollerets +1' },
            { id = 15661, lvl = 75, name = 'Homam Gambieras' },
            { id = 14159, lvl = 70, name = 'Ogre Ledelsens +1' },
            { id = 15331, lvl = 70, name = 'Blessed Pumps +1' },
            { id = 15758, lvl = 68, name = 'Cobra Crackows' },
            { id = 15705, lvl = 68, name = 'Ataractic Solea' },
            { id = 11380, lvl = 70, name = 'Hermes Sandals +1' },
            { id = 14113, lvl = 70, name = 'War Boots +1' },
            { id = 15709, lvl = 70, name = 'Mercenarys Boots' },
            { id = 15683, lvl = 70, name = 'Hydra Boots' },
            { id = 15710, lvl = 70, name = 'Volunteers Nails' },
            { id = 14094, lvl = 60, name = 'Rogues Poulaines' },
            { id = 14099, lvl = 60, name = 'Hunters Socks' },
            { id = 14087, lvl = 60, name = 'Gilt Sabatons' },
            { id = 11373, lvl = 60, name = 'Seirenshi Habaki' },
            { id = 14084, lvl = 59, name = 'Dst. Sollerets +1' },
            { id = 11404, lvl = 60, name = 'Promptitude Solea' },
            { id = 15323, lvl = 59, name = 'Cure Clogs' },
            { id = 15739, lvl = 59, name = 'Tabin Boots +1' },
            { id = 15338, lvl = 59, name = 'Vampire Boots' },
            { id = 14190, lvl = 50, name = 'Penance Sabots' },
            { id = 14086, lvl = 49, name = 'Mtl. Leggings +1' },
            { id = 28222, lvl = 45, name = 'Neits Pigaches' },
            { id = 15692, lvl = 50, name = 'Storm Crackows' },
            { id = 12973, lvl = 35, name = 'Mannequin Pumps' },
            { id = 15316, lvl = 29, name = 'Seers Pumps +1' },
            { id = 15318, lvl = 30, name = 'Rubious Pumps' },
            { id = 13039, lvl = 30, name = 'Strong Boots' },
            { id = 15326, lvl = 30, name = 'Gargoyle Boots' },
            { id = 13048, lvl = 20, name = 'Mages Sandals' },
            { id = 15344, lvl = 20, name = 'Barons Pigaches' },
            { id = 14206, lvl = 18, name = 'Garrison Boots' },
            { id = 13024, lvl = 10, name = 'Solid Greaves' },
            { id = 13004, lvl = 10, name = 'Ryl.ftm. Boots' },
            { id = 13003, lvl = 10, name = 'Lgn. Leggings' },
            { id = 13037, lvl =  8, name = 'Solea +1' },
            { id = 14195, lvl =  1, name = 'Waders' },
        },
        NECK =
        {
            { id = 26023, lvl = 99, name = 'Sanctity Necklace' },
            { id = 11584, lvl = 75, name = 'Lmg. Medallion +1' },
            { id = 16269, lvl = 70, name = 'Morganas Choker' },
            { id = 15522, lvl = 60, name = 'Enlightened Chain' },
            { id = 13135, lvl = 48, name = 'Promise Badge' },
            { id = 16262, lvl = 40, name = 'Mohbwa Scarf +1' },
            { id = 15504, lvl = 30, name = 'Ajase Beads' },
            { id = 13073, lvl = 26, name = 'Holy Phial' },
            { id = 13113, lvl = 20, name = 'Black Neckerchief' },
            { id = 13058, lvl = 20, name = 'Bloodbead Amulet' },
            { id = 13093, lvl =  7, name = 'Justice Badge' },
            { id = 16273, lvl =  1, name = 'Pullus Torque' },
        },
        WAIST =
        {
            { id = 26351, lvl = 99, name = 'Sacro Cord' },
            { id = 26329, lvl = 99, name = 'Luminary Sash' },
            { id = 26338, lvl = 99, name = 'K. Kachina Belt +1' },
            { id = 28415, lvl = 99, name = 'Eschan Stone' },
            { id = 28425, lvl = 75, name = 'Salire Belt' },
            { id = 15925, lvl = 70, name = 'Argute Belt' },
            { id = 15872, lvl = 70, name = 'Clerics Belt' },
            { id = 15915, lvl = 70, name = 'Sothic Rope' },
            { id = 13188, lvl = 70, name = 'Star Sash' },
            { id = 15877, lvl = 70, name = 'Koga Sarashi' },
            { id = 15292, lvl = 60, name = 'Penitents Rope' },
            { id = 15871, lvl = 70, name = 'Warriors Stone' },
            { id = 15875, lvl = 70, name = 'Monster Belt' },
            { id = 15878, lvl = 70, name = 'Wyrm Belt' },
            { id = 15879, lvl = 70, name = 'Sao. Koshi-ate' },
            { id = 15897, lvl = 58, name = 'Grace Corset' },
            { id = 15912, lvl = 60, name = 'Lieutenants Sash' },
            { id = 13220, lvl = 50, name = 'Ryl.kgt. Belt' },
            { id = 15883, lvl = 50, name = 'Storm Sash' },
            { id = 15908, lvl = 40, name = 'Qiqirn Sash +1' },
            { id = 13238, lvl = 40, name = 'Druids Rope' },
            { id = 13272, lvl = 40, name = 'Corsette +1' },
            { id = 13221, lvl = 30, name = 'Mrc.cpt. Belt' },
            { id = 13228, lvl = 28, name = 'Shamans Belt' },
            { id = 15927, lvl = 30, name = 'Pinwheel Belt' },
            { id = 15285, lvl = 30, name = 'Avatar Belt' },
            { id = 15906, lvl = 20, name = 'Mohbwa Sash +1' },
            { id = 15880, lvl = 20, name = 'Key Ring Belt' },
            { id = 13219, lvl = 18, name = 'Magic Belt +1' },
            { id = 13225, lvl = 18, name = 'Brave Belt' },
            { id = 13191, lvl = 17, name = 'Lizard Belt +1' },
            { id = 13190, lvl =  8, name = 'Heko Obi +1' },
            { id = 15889, lvl =  7, name = 'Augmenting Belt' },
            { id = 13226, lvl =  1, name = 'Blood Stone +1' },
            { id = 15456, lvl =  1, name = 'Dash Sash' },
        },
        BACK =
        {
            { id = 27620, lvl = 99, name = 'Aurists Cape +1' },
            { id = 28633, lvl = 99, name = 'Gunslingers Cape' },
            { id = 28615, lvl = 99, name = 'Toro Cape' },
            { id = 16242, lvl = 74, name = 'Ixion Cape' },
            { id = 13627, lvl = 71, name = 'Prism Cape' },
            { id = 11547, lvl = 75, name = 'Colossuss Mantle' },
            { id = 16228, lvl = 70, name = 'Aslan Cape' },
            { id = 15479, lvl = 70, name = 'Abyss Cape' },
            { id = 16230, lvl = 70, name = 'Lieutenants Cape' },
            { id = 15492, lvl = 60, name = 'Intensifying Cape' },
            { id = 13604, lvl = 60, name = 'Behem. Mantle +1' },
            { id = 15489, lvl = 50, name = 'Storm Cape' },
            { id = 13679, lvl = 50, name = 'Templars Mantle' },
            { id = 15483, lvl = 50, name = 'Storm Mantle' },
            { id = 15468, lvl = 40, name = 'Resentment Cape' },
            { id = 13675, lvl = 40, name = 'Rearguard Mantle' },
            { id = 13625, lvl = 39, name = 'Tundra Mantle' },
            { id = 13644, lvl = 30, name = 'Midnight Cape' },
            { id = 13673, lvl = 30, name = 'Magicians Mantle' },
            { id = 13681, lvl = 20, name = 'Variable Cape' },
            { id = 13680, lvl = 20, name = 'Variable Mantle' },
            { id = 13607, lvl = 10, name = 'Mist Silk Cape' },
            { id = 13599, lvl =  4, name = 'Rabbit Mantle +1' },
            { id = 16243, lvl =  1, name = 'Drovers Mantle' },
        },
        EAR =
        {
            { id = 26117, lvl = 99, name = 'Crep. Earring' },
            { id = 26118, lvl = 99, name = 'Sroda Earring' },
            { id = 26088, lvl = 99, name = 'Malignance Earring' },
            { id = 26085, lvl = 99, name = 'Regal Earring' },
            { id = 28478, lvl = 99, name = 'Etiolation Earring' },
            { id = 14808, lvl = 75, name = 'Novio Earring' },
            { id = 14812, lvl = 75, name = 'Loquac. Earring' },
            { id = 15992, lvl = 67, name = 'Celestial Earring' },
            { id = 15991, lvl = 67, name = 'Star Earring' },
            { id = 14728, lvl = 60, name = 'Phtm. Earring +1' },
            { id = 14727, lvl = 60, name = 'Phantom Earring' },
            { id = 14724, lvl = 47, name = 'Moldavite Earring' },
            { id = 15972, lvl = 50, name = 'Insomnia Earring' },
            { id = 13405, lvl = 40, name = 'Enhancing Earring' },
            { id = 14806, lvl = 40, name = 'Intruder Earring' },
            { id = 14766, lvl = 38, name = 'Geist Earring' },
            { id = 14721, lvl = 30, name = 'Morion Earring +1' },
            { id = 14720, lvl = 30, name = 'Morion Earring' },
            { id = 14757, lvl = 20, name = 'Mecurial Earring' },
            { id = 16041, lvl = 20, name = 'Federation Earring' },
            { id = 14694, lvl = 10, name = 'Energy Earring +1' },
            { id = 13379, lvl = 10, name = 'Energy Earring' },
            { id = 13402, lvl =  1, name = 'Cassie Earring' },
            { id = 28510, lvl =  1, name = 'M. Slime Earring' },
        },
        RING =
        {
            { id = 26192, lvl = 99, name = 'Adoulin Ring +1' },
            { id = 27580, lvl = 99, name = 'Adoulin Ring' },
            { id = 15800, lvl = 75, name = 'Omega Ring' },
            { id = 11633, lvl = 75, name = 'Galdr Ring' },
            { id = 14673, lvl = 69, name = 'Serene Ring' },
            { id = 15827, lvl = 70, name = 'Insect Ring' },
            { id = 13556, lvl = 70, name = 'Behemoth Ring +1' },
            { id = 15784, lvl = 60, name = 'Dominion Ring' },
            { id = 13545, lvl = 60, name = 'Demons Ring +1' },
            { id = 13464, lvl = 60, name = 'Demons Ring' },
            { id = 15777, lvl = 50, name = 'Hale Ring' },
            { id = 15807, lvl = 50, name = 'Balrahns Ring' },
            { id = 14651, lvl = 40, name = 'Mana Ring' },
            { id = 15547, lvl = 40, name = 'Vilmas Ring' },
            { id = 15545, lvl = 30, name = 'Tamas Ring' },
            { id = 15544, lvl = 30, name = 'Sattva Ring' },
            { id = 14652, lvl = 20, name = 'Protean Ring' },
            { id = 14653, lvl = 20, name = 'Variable Ring' },
            { id = 13285, lvl = 10, name = 'Eremites Ring +1' },
            { id = 13283, lvl = 10, name = 'Saintly Ring +1' },
            { id = 13496, lvl =  1, name = 'Windurstian Ring' },
            { id = 13495, lvl =  1, name = 'San Dorian Ring' },
        },
    },
}

-----------------------------------
-- Default Job & OverlordsXI Spec Profiles
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
    -- If previewing/equipping for a higher target level where a socketed crystal becomes active
    if specKey == nil and player ~= nil and spec ~= nil and optLevel ~= nil then
        local stored = spec.get(player, jobId)
        if stored ~= nil and optLevel >= (tonumber(stored.reqLevel) or spec.DEFAULT_REQ_LEVEL or 10) then
            specKey = stored.key
            specEntry = stored
        end
    end

    local j = xi.job or {}

    -- OverlordsXI Crystal Spec Overrides
    if jobId == (j.WAR or 1) then
        if specKey == 'gladiator' then
            return { role = 'tank', weapon = 'club', offhand = 'shield', ranged = 'none', ammo = 'ammo_tank', label = 'WAR Gladiator (Club & Shield Tank)', specEntry = specEntry }
        elseif specKey == 'commander' then
            return { role = 'melee', weapon = 'gaxe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_melee', label = 'WAR Commander (Great Axe)', specEntry = specEntry }
        elseif specKey == 'berserker' then
            return { role = 'melee', weapon = 'gaxe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_melee', label = 'WAR Berserker (Great Axe)', specEntry = specEntry }
        end
        return { role = 'melee', weapon = 'gaxe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_melee', label = 'Warrior (Great Axe)' }
    elseif jobId == (j.MNK or 2) then
        if specKey == 'sensei' then
            return { role = 'tank', weapon = 'staff', offhand = 'grip_tank', ranged = 'none', ammo = 'ammo_tank', label = 'MNK Sensei (Staff Evasion/Counter Tank)', specEntry = specEntry }
        end
        return { role = 'melee', weapon = 'h2h', offhand = 'none', ranged = 'none', ammo = 'ammo_melee', label = 'Monk (Hand-to-Hand)' }
    elseif jobId == (j.WHM or 3) then
        return { role = 'caster', weapon = 'club_mage', offhand = 'shield', ranged = 'none', ammo = 'ammo_caster', label = 'White Mage (Club & Shield)' }
    elseif jobId == (j.BLM or 4) then
        if specKey == 'necromancer' then
            return { role = 'caster', weapon = 'scythe', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'BLM Necromancer (Scythe & Undead)', specEntry = specEntry }
        end
        return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'Black Mage (Staff)' }
    elseif jobId == (j.RDM or 5) then
        return { role = 'caster', weapon = 'sword', offhand = 'shield', ranged = 'none', ammo = 'ammo_caster', label = 'Red Mage (Sword & Shield)' }
    elseif jobId == (j.THF or 6) then
        return { role = 'melee', weapon = 'dagger', offhand = 'auto', ranged = 'throwing', ammo = 'none', label = 'Thief (Dagger & Throwing)' }
    elseif jobId == (j.PLD or 7) then
        return { role = 'tank', weapon = 'sword', offhand = 'shield', ranged = 'none', ammo = 'ammo_tank', label = 'Paladin (Sword & Shield)' }
    elseif jobId == (j.DRK or 8) then
        return { role = 'melee', weapon = 'scythe', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_melee', label = 'Dark Knight (Scythe)' }
    elseif jobId == (j.BST or 9) then
        return { role = 'melee', weapon = 'axe', offhand = 'auto', ranged = 'none', ammo = 'ammo_melee', label = 'Beastmaster (Axe & Shield/Offhand)' }
    elseif jobId == (j.BRD or 10) then
        return { role = 'caster', weapon = 'dagger', offhand = 'shield', ranged = 'instrument', ammo = 'none', label = 'Bard (Dagger & Instrument)' }
    elseif jobId == (j.RNG or 11) then
        return { role = 'ranged', weapon = 'axe', offhand = 'auto', ranged = 'bow', ammo = 'arrow', label = 'Ranger (Axe & Bow)' }
    elseif jobId == (j.SAM or 12) then
        return { role = 'melee', weapon = 'gkatana', offhand = 'grip_melee', ranged = 'bow', ammo = 'arrow', label = 'Samurai (Great Katana & Bow)' }
    elseif jobId == (j.NIN or 13) then
        return { role = 'melee', weapon = 'katana', offhand = 'auto', ranged = 'none', ammo = 'shuriken', label = 'Ninja (Katana & Shuriken)' }
    elseif jobId == (j.DRG or 14) then
        return { role = 'melee', weapon = 'polearm', offhand = 'grip_melee', ranged = 'none', ammo = 'ammo_melee', label = 'Dragoon (Polearm)' }
    elseif jobId == (j.SMN or 15) then
        return { role = 'caster', weapon = 'staff_mage', offhand = 'grip_caster', ranged = 'none', ammo = 'ammo_caster', label = 'Summoner (Staff)' }
    elseif jobId == (j.BLU or 16) then
        return { role = 'melee', weapon = 'sword', offhand = 'auto', ranged = 'none', ammo = 'ammo_melee', label = 'Blue Mage (Sword)' }
    elseif jobId == (j.COR or 17) then
        return { role = 'ranged', weapon = 'sword', offhand = 'auto', ranged = 'gun', ammo = 'bullet', label = 'Corsair (Sword & Gun)' }
    elseif jobId == (j.PUP or 18) then
        return { role = 'melee', weapon = 'h2h', offhand = 'none', ranged = 'animator', ammo = 'oil', label = 'Puppetmaster (H2H & Animator)' }
    elseif jobId == (j.DNC or 19) then
        if specKey == 'bladewheel' then
            return { role = 'ranged', weapon = 'dagger', offhand = 'auto', ranged = 'chakram_dnc', ammo = 'none', label = 'DNC Bladewheel (Daggers & Chakram)', specEntry = specEntry }
        end
        return { role = 'melee', weapon = 'dagger', offhand = 'auto', ranged = 'throwing', ammo = 'none', label = 'Dancer (Daggers & Throwing)' }
    elseif jobId == (j.SCH or 20) then
        if specKey == 'medic' then
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

    return { role = 'melee', weapon = 'sword', offhand = 'shield', ranged = 'none', ammo = 'ammo_melee', label = 'Adventurer' }
end

-----------------------------------
-- Candidate Eligibility & Slot Resolution
-----------------------------------
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

    -- Special BLM Scythe check: non-vanilla scythes require Lv.10+ Necromancer crystal
    if opts.weaponKey == 'scythe' and player:getMainJob() == (xi.job and xi.job.BLM or 4) then
        local activeSpec = testGear.getActiveSpecKey(player, player:getMainJob())
        if activeSpec ~= 'necromancer' and not VANILLA_BLM_SCYTHES[entry.id] then
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
    for _, entry in ipairs(pool) do
        if isItemEquippable(player, entry, targetLevel, opts) then
            return entry
        end
    end
    return nil
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

    -- Mainhand weapon override
    if wKey == 'club' and profile.role == 'caster' then
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
            return nil, string.format('Unknown role: %s (use melee, tank, ranged, or caster)', tostring(opts.role))
        end
        profile.role  = rKey
        profile.label = string.format('%s (%s)', profile.label, rKey)
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
        -- If DNC Bladewheel is < Lv.10 (before Rogetsurin), fall back to throwing/ammo
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
        if ammoKey == nil or ammoKey == 'none' or ammoKey == 'arrow' or ammoKey == 'bolt' or ammoKey == 'bullet' then
            ammoKey = (profile.role == 'caster' and 'ammo_caster')
                or (profile.role == 'tank' and 'ammo_tank')
                or 'ammo_melee'
        end
        ammoItem = testGear.pickFromPool(player, testGear.AMMO[ammoKey], targetLevel)
        if ammoItem == nil and ammoKey == 'orphic_egg' then
            ammoItem = testGear.pickFromPool(player, testGear.AMMO.ammo_caster, targetLevel)
        end
        slots[slotEnum.AMMO] = ammoItem
    end

    -- 4. 5-Piece Armor + 7 Accessories
    local roleGear = testGear.ROLE_GEAR[profile.role] or testGear.ROLE_GEAR.melee
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

    -- Count how many new items need to be added
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

    -- Ordered equip sequence: MAIN before SUB, RANGED before AMMO, then armor & accessories
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

            -- Top up stackable ammo in inventory if not present in inventory
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

    loadout.addedCount    = addedCount
    loadout.equippedCount = equippedCount
    return loadout, nil
end

return testGear
