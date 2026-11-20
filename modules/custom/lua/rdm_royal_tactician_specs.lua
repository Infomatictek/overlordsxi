-- Royal Tactician (RDM) — translate enfeebling outcomes into targeted party orders.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_rdm_royal_tactician')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.RDM] then
    require('modules/custom/lua/rdm_specs')
end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local ISSUE_ORDER, ADVANCE, RECOMPOSE = 275, 1, 2
local PENDING, PENDING_UNTIL, HALF = 'OX_RYT_PENDING', 'OX_RYT_PENDING_UNTIL', 'OX_RYT_HALF'
local LAST, ORDERS_CD, FALLBACK_CD = 'OX_RYT_LAST', 'OX_RYT_ORDERS_CD', 'OX_RYT_FALLBACK_CD'
local OWNER, RECIPIENT, ORDER_UNTIL = 'OX_RYT_OWNER', 'OX_RYT_RECIPIENT', 'OX_RYT_ORDER_UNTIL'
local KIND, PERCENT, ACC, STP = 'OX_RYT_ORDER_KIND', 'OX_RYT_ORDER_PCT', 'OX_RYT_ORDER_ACC', 'OX_RYT_ORDER_STP'
local ORDER_HELP = 'Issue the order opened by your latest successful enfeeble. Costs no MP. Targets one party member or yourself. 18s recast.'

local ROYALTACTICIAN_KIT_SPELLS =
{
    [56] = { group = 'white', script = 'slow', name = 'Break Stride', unlockLvl = 10, castMs = 2000, recastSec = 20,
        order = ADVANCE, description = 'Hinder one enemy attack speed. Landing this opens Advance. 20s recast.' },
    [58] = { group = 'white', script = 'paralyze', name = 'Seize Initiative', unlockLvl = 10, castMs = 3000, recastSec = 10,
        order = ADVANCE, description = 'Interfere with one enemy action. Landing this opens Advance. 10s recast.' },
    [254] = { group = 'black', script = 'blind', name = 'Obscure Aim', unlockLvl = 10, castMs = 2000, recastSec = 10,
        order = RECOMPOSE, description = 'Reduce one enemy accuracy. Landing this opens Recompose. 10s recast.' },
    [59] = { group = 'white', script = 'silence', name = 'Quiet Front', unlockLvl = 10, castMs = 3000, recastSec = 10,
        order = RECOMPOSE, description = 'Stop one enemy from casting magic. Landing this opens Recompose. 10s recast.' },
    [260] = { group = 'black', script = 'dispel', name = 'Unravel Defense', unlockLvl = 30, castMs = 3000, recastSec = 10,
        description = 'Remove one enemy enhancement and reopen the last order you issued. 10s recast.' },
}
xi.soulspire.rdmRoyalTacticianSpecs = { ROYALTACTICIAN_KIT_SPELLS = ROYALTACTICIAN_KIT_SPELLS }

local function isTactician(player)
    return player and player:isPC() and player:getMainJob() == xi.job.RDM and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.RDM, 'royaltactician')
end

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function remaining(player, variable)
    return math.max(0, player:getLocalVar(variable) - now())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function clearOrder(target)
    local acc, stp = target:getLocalVar(ACC), target:getLocalVar(STP)
    if acc > 0 then target:delMod(xi.mod.ACC, acc) end
    if stp > 0 then target:delMod(xi.mod.STORETP, stp) end
    target:setLocalVar(ACC, 0)
    target:setLocalVar(STP, 0)
    target:setLocalVar(OWNER, 0)
    target:setLocalVar(KIND, 0)
    target:setLocalVar(ORDER_UNTIL, 0)
end

local function clearOwnedOrder(player)
    local id = player:getLocalVar(RECIPIENT)
    if id > 0 then
        local target = id == player:getID() and player or GetPlayerByID(id)
        if target and target:getLocalVar(OWNER) == player:getID() then clearOrder(target) end
    end
    player:setLocalVar(RECIPIENT, 0)
end

local function clearPending(player)
    player:setLocalVar(PENDING, 0)
    player:setLocalVar(PENDING_UNTIL, 0)
    player:setLocalVar(HALF, 0)
end

local function record(player, entry, message)
    local resisted = message == xi.msg.basic.MAGIC_RESIST or message == xi.msg.basic.MAGIC_COMPLETE_RESIST
    if resisted then
        if player:getMainLvl() < 50 or remaining(player, FALLBACK_CD) > 0 then return end
        player:setLocalVar(FALLBACK_CD, now() + 24)
    elseif message == xi.msg.basic.MAGIC_NO_EFFECT then
        return
    end
    local last = player:getLocalVar(LAST)
    local order = entry.order or (last > 0 and last or ADVANCE)
    player:setLocalVar(PENDING, order)
    player:setLocalVar(PENDING_UNTIL, now() + 6)
    player:setLocalVar(HALF, resisted and 1 or 0)
end

local function isPartyPC(player, target)
    if not target or not target:isPC() or not target:isAlive() or target:getZoneID() ~= player:getZoneID() then return false end
    if player:getID() == target:getID() then return true end
    for _, member in ipairs(player:getParty()) do
        if member:getID() == target:getID() then return true end
    end
    return false
end

local function potency(player, order)
    local level = player:getMainLvl()
    local divider = player:getLocalVar(HALF) == 1 and 2 or 1
    if order == ADVANCE then
        return math.floor(scale(level, 10, 10, 10, 15) / divider), math.floor(scale(level, 0, 5, 5, 8) / divider)
    end
    return math.floor(scale(level, 15, 20, 20, 25) / divider), 0
end

for _, entry in pairs(ROYALTACTICIAN_KIT_SPELLS) do
    local path = 'xi.actions.spells.' .. entry.group .. '.' .. entry.script
    m:addOverride(path .. '.onMagicCastingCheck', function(caster, target, spell)
        if not isTactician(caster) then return super(caster, target, spell) end
        if caster:getMainLvl() < entry.unlockLvl or not target:isMob() then return xi.msg.basic.CANNOT_CAST_SPELL end
        return super(caster, target, spell)
    end)
    m:addOverride(path .. '.onSpellCast', function(caster, target, spell)
        local result = super(caster, target, spell)
        if isTactician(caster) and target:isMob() then record(caster, entry, spell:getMessage()) end
        return result
    end)
end

m:addOverride('xi.actions.abilities.spontaneity.onAbilityCheck', function(player, target, ability)
    if not isTactician(player) then return super(player, target, ability) end
    local order = player:getLocalVar(PENDING)
    if order == 0 or remaining(player, PENDING_UNTIL) == 0 or remaining(player, ORDERS_CD) > 0 or
        not isPartyPC(player, target) or player:checkDistance(target) > 15
    then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    local percent, stp = potency(player, order)
    if remaining(target, ORDER_UNTIL) > 0 and target:getLocalVar(KIND) == order and
        (target:getLocalVar(PERCENT) * 100 + target:getLocalVar(STP)) >= (percent * 100 + stp)
    then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRecast(18)
    ability:setRange(15)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.spontaneity.onUseAbility', function(player, target, ability, action)
    if not isTactician(player) then return super(player, target, ability, action) end
    local order = player:getLocalVar(PENDING)
    local percent, stp = potency(player, order)
    clearOwnedOrder(player)
    clearOrder(target)
    clearPending(player)
    player:setLocalVar(LAST, order)
    player:setLocalVar(ORDERS_CD, now() + 18)
    player:setLocalVar(RECIPIENT, target:getID())
    local expiration = now() + 8
    local ownerId = player:getID()
    target:setLocalVar(OWNER, ownerId)
    target:setLocalVar(KIND, order)
    target:setLocalVar(PERCENT, percent)
    target:setLocalVar(ORDER_UNTIL, expiration)
    if order == ADVANCE then
        local acc = math.floor(target:getACC() * percent / 100)
        target:addMod(xi.mod.ACC, acc)
        target:addMod(xi.mod.STORETP, stp)
        target:setLocalVar(ACC, acc)
        target:setLocalVar(STP, stp)
    end
    target:timer(8000, function(entity)
        if entity:getLocalVar(OWNER) == ownerId and entity:getLocalVar(ORDER_UNTIL) == expiration then
            clearOrder(entity)
        end
    end)
    return 0
end)

local function apply(player)
    player:setLocalVar('OX_RYT_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar('OX_RYT_ACTIVE', 0)
    clearPending(player)
    clearOwnedOrder(player)
    player:setLocalVar(LAST, 0)
    player:sendSoulSpellList()
end

actions.register('royaltactician',
{
    spell = ROYALTACTICIAN_KIT_SPELLS,
    ability = { [ISSUE_ORDER] = { name = 'Issue Order', description = ORDER_HELP, recastTime = 18 } },
})

spec.registerCrystal(xi.job.RDM,
{
    id = 2, key = 'royaltactician', name = 'Royal Tactician', abr = 'RYT', role = 'Support',
    icon = 'royaltactician', reqLevel = 10,
    description = 'Choose a useful enfeeble, then make the tactical decision of who receives your order.',
    highlights =
    {
        'Break Stride and Seize Initiative open Advance. Obscure Aim and Quiet Front open Recompose.',
        'Lv.30 Unravel Defense repeats the last issued order. Lv.50+ a full resist can grant a half-potency order.',
        'A new enfeeble replaces the pending order. Same-kind orders use the highest potency already active on the recipient.',
    },
    extraAbilities = function(_, level) return level >= 10 and { ISSUE_ORDER } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.MPP,  scale(level, 6, 10, 14, 18) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if event == 'onGameIn' and player:isPC() then
            clearOrder(player)
            clearPending(player)
            clearOwnedOrder(player)
        end
        if isTactician(player) then apply(player) end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('royaltactician', function(player)
        local pending = remaining(player, PENDING_UNTIL)
        return
        {
            pending = pending > 0 and player:getLocalVar(PENDING) or 0, pending_rem = pending,
            half = pending > 0 and player:getLocalVar(HALF) or 0,
            order_cd = remaining(player, ORDERS_CD), fallback_cd = remaining(player, FALLBACK_CD),
        }
    end)
end

return m
