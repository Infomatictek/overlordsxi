-- OverlordsXI WS Evolution experiment: Combo + Sanguine Blade.
-- Deliberately versioned storage in ws_talents.lua: old invested ranks are preserved.
-- Five immediate, one-rank decisions. Each stage is exclusive; hybrid effects coexist.
-- The first decision is the identity, not a small percentage tax.
local talents = xi.overlords and xi.overlords.wsTalents
if not talents then return end

local function node(key, name, stage, col, description, effect, extra)
    local tier = stage
    local n =
    {
        key = key, name = name, tier = tier, col = col,
        stage = stage, exclusiveGroup = 'evo_stage_' .. stage,
        maxRank = 1, reqWsPoints = stage - 1,
        reqLevel = ({ 1, 5, 10, 15, 25 })[stage],
        noAutoRequires = true,
        effect = effect or {},
        describe = function(rank)
            return (rank > 0 and '[ACTIVE] ' or '') .. description
        end,
    }
    for k, v in pairs(extra or {}) do n[k] = v end
    return n
end

-- Five stages with two choices each; the client renders all five rows.
talents.registerCustomWS(1,
{
    archetype = 'utility',
    evolution = true,
    nodes =
    {
        node('e_co_open', 'Explosive Opening', 1, 1,
             'Combo primes the next WS: +20% potency and +100 TP bonus (12s).',
             { nextWs = { wsd = 20, tp = 100, dur = 12 } }),
        node('e_co_flow', 'Relentless Flow', 1, 2,
             'Combo primes next WS with +350 TP bonus and +25 accuracy (12s).',
             { nextWs = { tp = 350, acc = 25, dur = 12 } }),
        node('e_co_hits', 'Driving Impact', 2, 1,
             'Combo becomes a 2-hit strike and improves next-WS accuracy.',
             { hits = 2, nextWs = { acc = 35 } }),
        node('e_co_window', 'Open Window', 2, 2,
             'Your Combo opening lasts 18s; next WS gains +45 accuracy.',
             { nextWs = { acc = 45, dur = 18 } }),
        node('e_co_edge', 'Directed Pressure', 3, 1,
             'Your next WS gains a further +12% potency.',
             { nextWs = { wsd = 12 } }),
        node('e_co_tempo', 'Pressure Cycling', 3, 2,
             'Your next WS gains a further +180 effective TP.',
             { nextWs = { tp = 180 } }),
        node('e_co_focus', 'Flexible Targeting', 4, 1,
             'Your next WS gains +60 accuracy and +50 magic accuracy.',
             { nextWs = { acc = 60, macc = 50 } }),
        node('e_co_force', 'Measured Assault', 4, 2,
             'Your next WS gains an additional +10% potency.',
             { nextWs = { wsd = 10 } }),
        node('e_co_break', 'Singular Opening', 5, 1,
             'Mastery: next WS gains +28% potency; capitalize on one opening.',
             { nextWs = { wsd = 28 } }),
        node('e_co_storm', 'Sustained Opening', 5, 2,
             'Mastery: next WS gains +300 TP bonus and +10% potency.',
             { nextWs = { tp = 300, wsd = 10 } }),
    },
})

-- Avoid a universal HP-drain nuke. Offensive identities are restricted to
-- appropriate Souls/specs; other Souls still retain the base WS.
talents.registerCustomWS(47,
{
    archetype = 'magic',
    evolution = true,
    nodes =
    {
        node('e_sg_arcane', 'Arcane Reaver', 1, 1,
             'Magical strike: spellblade-scaled Dark damage, +50 MAB, +35 MACC.',
             { ftpCurve = { 1.8, 2.5, 3.3 }, matt = 50, macc = 35, wsc = { int = 0.35, mnd = 0.25 } },
             { allowedSpecs = { spellblade = true, magus = true, vampire = true }, allowedJobs = { [xi.job.RDM] = true } }),
        node('e_sg_blood', 'Blood Discipline', 1, 2,
             'Controlled sustain identity: +8% HP recovery from WS damage.',
             { ftpCurve = { 1.6, 2.1, 2.7 }, hpDrain = 8 }, { allowedSpecs = { vampire = true, lifebinder = true, aegistemplar = true, templar = true } }),
        node('e_sg_surge', 'Abyssal Surge', 2, 1,
             'Your Dark WS gains +40 MAB and +40 MACC.',
             { matt = 40, macc = 40 }, { allowedSpecs = { spellblade = true, magus = true, vampire = true }, allowedJobs = { [xi.job.RDM] = true } }),
        node('e_sg_focus', 'Dark Precision', 2, 2,
             'Improve resource flow: +200 effective TP and +40 magic accuracy.',
             { macc = 40, tpBonus = 200 }),
        node('e_sg_mana', 'Soul Siphon', 3, 1,
             'Recover MP equal to 12% of WS damage (capped separately).',
             { mpDrain = 12 }),
        node('e_sg_pressure', 'Soul Pressure', 3, 2,
             'Gain +35 MAB and +12% magical WS potency.',
             { matt = 35, wsd = 12 }, { allowedSpecs = { spellblade = true, magus = true, vampire = true }, allowedJobs = { [xi.job.RDM] = true } }),
        node('e_sg_control', 'Vital Control', 4, 1,
             'Improve controlled HP recovery by 4% of damage.',
             { hpDrain = 4 }),
        node('e_sg_force', 'Abyssal Edge', 4, 2,
             'Gain +45 MAB and +40 magic accuracy.',
             { matt = 45, macc = 40 }, { allowedSpecs = { spellblade = true, magus = true, vampire = true }, allowedJobs = { [xi.job.RDM] = true } }),
        node('e_sg_eclipse', 'Eclipse Reaver', 5, 1,
             'Mastery: powerful magical damage scaling, +65 MAB, +20% potency.',
             { matt = 65, wsd = 20 },
             { allowedSpecs = { spellblade = true, magus = true, vampire = true }, allowedJobs = { [xi.job.RDM] = true } }),
        node('e_sg_hunger', 'Measured Hunger', 5, 2,
             'Mastery: controlled recovery +6% HP and +8% MP from damage.',
             { hpDrain = 6, mpDrain = 8 },
             { allowedSpecs = { vampire = true, lifebinder = true, aegistemplar = true, templar = true } }),
    },
})
