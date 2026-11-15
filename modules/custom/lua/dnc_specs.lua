-----------------------------------
-- OverlordsXI Dancer Crystal Specs
-- Registers the Bladewheel (Ranged Chakram) Dancer soul crystal,
-- its passive ranged scaling stats, and ranged Violent Flourish support.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/physical_utilities')
require('scripts/globals/job_utils/dancer')
-----------------------------------
local m = Module:new('overlords_dnc_specs')

local spec = xi.overlords.spec

local BLADEWHEEL_KEY = 'bladewheel'

local function scaleTier(lvl, low, mid, high, cap75)
    local l = lvl or 1
    if l >= 70 then
        return cap75 or high
    elseif l >= 50 then
        return high
    elseif l >= 30 then
        return mid
    end
    return low
end

local function isBladewheelDnc(player)
    if player == nil or not player:isPC() or player:getMainJob() ~= xi.job.DNC then
        return false
    end
    spec.ensureUpToDate(player)
    return spec.is(player, xi.job.DNC, BLADEWHEEL_KEY)
end

-- Support ranged Violent Flourish when Bladewheel is active with a Throwing weapon
m:addOverride('xi.job_utils.dancer.useViolentFlourishAbility', function(player, target, ability, action)
    if
        not isBladewheelDnc(player) or
        player:getLocalVar('OX_DNC_RANGED') ~= 1 or
        player:getWeaponSkillType(xi.slot.RANGED) ~= xi.skill.THROWING or
        player:checkDistance(target) <= 4.0
    then
        return super(player, target, ability, action)
    end

    local status = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    if status == nil then
        return
    end

    local numMoves = status:getPower()
    local fmEffect = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    if fmEffect ~= nil then
        if numMoves <= 1 then
            player:delStatusEffect(xi.effect.FINISHING_MOVE_1)
        else
            fmEffect:setPower(numMoves - 1)
        end
    end

    local racc = player:getRACC()
    local eva = target:getEVA()
    local hitRate = math.clamp(0.75 + (racc - eva) * 0.005, 0.20, 0.95)

    if math.random() <= hitRate then
        local weaponDamage = math.max(1, player:getRangedDmg())
        local baseDmg = weaponDamage + math.floor(player:getStat(xi.mod.AGI) * 0.5)
        local pdif = xi.combat.physical.calculateRangedPDIF(player, target, xi.skill.THROWING, 1.0, false, false, false, 0.0, false)
        local dmg = math.max(1, math.floor(baseDmg * pdif))

        dmg = utils.handleStoneskin(target, dmg, xi.attackType.RANGED)
        target:takeDamage(dmg, player, xi.attackType.RANGED, xi.damageType.PIERCING)
        target:updateEnmityFromDamage(player, dmg)
        action:recordDamage(target, xi.attackType.RANGED, dmg)

        local maccParams =
        {
            effectId       = xi.effect.STUN,
            magicalElement = xi.element.THUNDER,
            skillRank      = xi.skillRank.A_PLUS,
            actorStat      = xi.mod.INT,
            bonusMacc      = player:getMod(xi.mod.VFLOURISH_MACC),
        }
        local resistRate = xi.combat.magicHitRate.calculateResistRate(player, target, maccParams)
        if resistRate > 0.25 then
            target:addStatusEffect(xi.effect.STUN, 1, 0, 2)
        end
    else
        action:messageID(target:getID(), xi.msg.basic.USES_BUT_MISSES)
    end
end)

if xi.job and xi.job.DNC then
    spec.registerJob(xi.job.DNC, 'DNC',
    {
        {
            id           = 1,
            key          = BLADEWHEEL_KEY,
            name         = 'Bladewheel',
            role         = 'Ranged Chakram Dancer',
            icon         = 'chakram_crystal',
            throwWs      = true,
            autoRanged   = { minLevel = 10, maxRange = 20, skills = { 'throwing' } },
            rangedDances = true,
            description  = 'Ranged chakram spec: auto-attacks with your chakram when out of melee range, unlocks 12 Throwing weaponskills, and lets Steps, Flourishes, and Sambas work at range.',
            highlights   =
            {
                'Auto-attacks with equipped chakram when outside melee range.',
                'Unlocks 12 custom Dancer Throwing weaponskills (Lv 5-75).',
                'Steps and offensive Flourishes work up to 20 yalms.',
                'Drain, Aspir, and Haste Samba trigger on ranged chakram hits.',
                'Passive +R.Acc, +R.Atk, +Snapshot, +AGI, and +CHR.',
            },
            mods = function(_player, lvl)
                local racc = scaleTier(lvl, 10, 22, 36, 48)
                local ratt = scaleTier(lvl, 10, 24, 40, 54)
                local snap = scaleTier(lvl, 5, 10, 15, 20)
                local stat = scaleTier(lvl, 3, 6, 10, 14)
                return
                {
                    { xi.mod.RACC, racc },
                    { xi.mod.RATT, ratt },
                    { xi.mod.SNAPSHOT, snap },
                    { xi.mod.AGI, stat },
                    { xi.mod.CHR, stat },
                }
            end,
        },
    })
end

return m
