-----------------------------------
-- SoulspireXI WS Foundation v1 (provisional; 1000 TP targets)
--
-- This is intentionally a data-only damage floor. Spending the FIRST point
-- in any WS grants a usable Foundation; the existing talent trees continue
-- to add their own scaling/identity on top. No free debuffs, crit, attack,
-- defense-ignore, healing, or skillchain properties are granted here.
--
-- These benchmark values are DESIGN PROXIES, not live parses. Revalidate
-- after the Haste/TP overhaul and at levels 10/30/50/75.
-----------------------------------
local foundation = {}

-- base10/base75 include the representative weapon + fSTR (or
-- ranged weapon+ammo+ranged fSTR) used during design discussions.
-- stat10=20, stat75=80, WSC correction=0.85 throughout.
-- target75 refers to a 1000-TP SINGLE-TARGET WS raw proxy.
local PROFILES =
{
    ['Hand-to-Hand'] = { base10 = 15, base75 = 55,  target75 = 170, wsc = 0.50 },
    ['Dagger']       = { base10 = 10, base75 = 45,  target75 = 220, wsc = 0.50 },
    ['Sword']        = { base10 = 13, base75 = 56,  target75 = 230, wsc = 0.50 },
    ['Great Sword']  = { base10 = 24, base75 = 93,  target75 = 390, wsc = 0.50 },
    ['Axe']          = { base10 = 16, base75 = 60,  target75 = 250, wsc = 0.50 },
    ['Great Axe']    = { base10 = 27, base75 = 98,  target75 = 370, wsc = 0.50 },
    ['Scythe']       = { base10 = 26, base75 = 93,  target75 = 375, wsc = 0.50 },
    ['Polearm']      = { base10 = 29, base75 = 98,  target75 = 390, wsc = 0.50 },
    ['Katana']       = { base10 = 14, base75 = 53,  target75 = 244, wsc = 0.50 },
    ['Great Katana'] = { base10 = 32, base75 = 103, target75 = 260, wsc = 0.50 },
    ['Club']         = { base10 = 13, base75 = 53,  target75 = 200, wsc = 0.50 },
    ['Staff']        = { base10 = 17, base75 = 63,  target75 = 209, wsc = 0.50 },
    ['Archery']      = { base10 = 24, base75 = 118, target75 = 304, wsc = 0.50 },
    ['Marksmanship'] = { base10 = 26, base75 = 108, target75 = 284, wsc = 0.50 },
    ['Throwing']     = { base10 = 14, base75 = 53,  target75 = 184, wsc = 0.40 },
}
foundation.PROFILES = PROFILES

-- Magical and hybrid WS damage must be verified with real engine formulas.
-- These are conservative starter coefficients from the first design pass.
local MAGIC_FTP =
{
    ['Dagger'] = 2.70, ['Sword'] = 2.70, ['Great Sword'] = 2.80,
    ['Axe'] = 2.75, ['Scythe'] = 2.78, ['Polearm'] = 2.78,
    ['Katana'] = 2.75, ['Club'] = 2.40, ['Staff'] = 2.20,
    ['Marksmanship'] = 2.50, ['Throwing'] = 2.10,
}
local HYBRID_FTP =
{
    ['Katana'] = 1.85, ['Great Katana'] = 1.10,
    ['Archery'] = 1.25, ['Marksmanship'] = 1.25,
}
local MAGIC_WS_FTP =
{
    [47] = 2.35, -- Sanguine Blade: HP drain is talent/role restricted
    [58] = 2.20, -- Herculean Slash
    [107] = 2.55, -- Infernal Scythe
    [178] = 1.75, -- Earth Crusher (AoE)
    [189] = 1.75, -- Cataclysm (AoE)
}
local HYBRID_WS_FTP =
{
    [132] = 1.20, -- Blade: Chi: two-hit hybrid
    [148] = 0.75, -- Tachi: Jinpu: two-hit hybrid, reduced GK budget
}

local function round3(x)
    return math.floor(x * 1000 + 0.5) / 1000
end

-- Preserve original stat identity, but normalize the TOTAL first-point WSC
-- to the approved weapon-category budget.
local function normalizeWsc(ws, total)
    local input = ws.orig and ws.orig.wsc or {}
    local sum = 0
    for _, weight in pairs(input) do
        if type(weight) == 'number' and weight > 0 then
            sum = sum + weight
        end
    end
    if sum <= 0 then
        return {}
    end
    local out = {}
    for stat, weight in pairs(input) do
        if type(weight) == 'number' and weight > 0 then
            out[stat] = total * weight / sum
        end
    end
    return out
end

function foundation.get(ws)
    if type(ws) ~= 'table' or type(ws.orig) ~= 'table' then
        return nil
    end

    local p = PROFILES[ws.skillName]
    if p == nil or ws.wsType == 'utility' then
        return nil
    end

    local orig = ws.orig
    local hits = math.max(1, math.min(8, tonumber(orig.numHits) or 1))
    local isPhysical = ws.wsType == 'physical' or ws.wsType == 'ranged'
    local ratio = (isPhysical and p.wsc) or 0.55
    local wsc = normalizeWsc(ws, ratio)
    local ftp

    if isPhysical then
        -- Carry is explicitly permitted at Foundation even if the original
        -- WS lacked it. Full hit count is retained; total fTP is normalized.
        local aoeScale = orig.aoe and 0.80 or 1.00
        local totalFtp = p.target75 * aoeScale / (p.base75 + 80 * 0.85 * p.wsc)
        ftp = totalFtp / hits
    elseif ws.wsType == 'magic' then
        ftp = MAGIC_WS_FTP[ws.id] or MAGIC_FTP[ws.skillName] or 2.40
        if orig.aoe and MAGIC_WS_FTP[ws.id] == nil then
            ftp = ftp * 0.80
        end
    elseif ws.wsType == 'hybrid' then
        ftp = HYBRID_WS_FTP[ws.id] or HYBRID_FTP[ws.skillName] or 1.25
    else
        return nil
    end

    ftp = round3(ftp)
    return
    {
        ftp = { ftp, round3(ftp * 1.08), round3(ftp * 1.16) },
        numHits = hits,
        multiHitfTP = hits > 1,
        wsc = wsc,
        isPhysical = isPhysical,
    }
end

return foundation
