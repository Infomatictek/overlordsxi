-----------------------------------
-- OverlordsXI % Max HP Regen Scaling
-- Scales base Regen I-V spell potency to % of target Max HP per tick (with boosted low-level floors),
-- while preserving caster multipliers (REGEN_MULTIPLIER, Light Arts, Merits, Embolden, etc.).
-----------------------------------
require('modules/module_utils')
require('scripts/globals/spells/enhancing_spell')
-----------------------------------
local m = Module:new('overlords_regen_potency')

local REGEN_PCT_TABLE =
{
    [xi.magic.spell.REGEN]     = { pct = 0.015, minPower = 12 }, -- 1.5% Max HP/tick
    [xi.magic.spell.REGEN_II]  = { pct = 0.020, minPower = 24 }, -- 2.0% Max HP/tick
    [xi.magic.spell.REGEN_III] = { pct = 0.025, minPower = 38 }, -- 2.5% Max HP/tick
    [xi.magic.spell.REGEN_IV]  = { pct = 0.035, minPower = 55 }, -- 3.5% Max HP/tick
    [xi.magic.spell.REGEN_V]   = { pct = 0.045, minPower = 75 }, -- 4.5% Max HP/tick
}

m:addOverride('xi.spells.enhancing.calculateEnhancingBasePower', function(caster, target, spell, spellId, spellEffect)
    if spellEffect == xi.effect.REGEN then
        local cfg = REGEN_PCT_TABLE[spellId]
        if cfg ~= nil and target ~= nil and target.getMaxHP then
            local maxHp = math.max(0, target:getMaxHP() or 0)
            return math.max(cfg.minPower, math.floor(maxHp * cfg.pct))
        end
    end

    return super(caster, target, spell, spellId, spellEffect)
end)

return m
