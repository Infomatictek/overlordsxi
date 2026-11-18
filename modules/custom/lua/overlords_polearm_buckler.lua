-----------------------------------
-- OverlordsXI: 2H Polearm + Size-1 Buckler (WAR Spartan/Gladiator)
-- * Shield block support for a Polearm main + Buckler sub (+10% virtual
--   Aspis Buckler block when the sub slot is empty).
-- * Shared helpers for !buckler / !shield.
-- Equip rules live in C++ (charutils::CanEquipPolearmBuckler, patch 0030).
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('overlords_polearm_buckler')

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.buckler = xi.overlords.buckler or {}

local B = xi.overlords.buckler

B.VIRTUAL_BLOCK_RATE   = 10 -- percent
B.VIRTUAL_ABSORB_RATE  = 50 -- percent of damage absorbed on a virtual block

B.containers = { 0, 8, 10, 11, 12, 13, 14, 15, 16 } -- inventory, wardrobe 1-8

B.isPolearmBucklerPlayer = function(player)
    return player ~= nil and
        player:isPC() and
        player:getMainJob() == xi.job.WAR and
        player:getLocalVar('OX_POLEARM_BUCKLER') == 1
end

B.hasPolearmMain = function(player)
    local main = player:getEquippedItem(xi.slot.MAIN)
    return main ~= nil and player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
end

-- Returns list of { id, name, container, reqLvl } of carried Size-1 shields.
B.findBucklers = function(player)
    local found = {}
    local lvl   = player:getMainLvl()

    for _, containerId in ipairs(B.containers) do
        local items = player:getItems(containerId)
        for _, item in pairs(items or {}) do
            if item:isShield() and item:getShieldSize() == 1 and item:getReqLvl() <= lvl then
                table.insert(found,
                {
                    id        = item:getID(),
                    name      = item:getName(),
                    container = containerId,
                })
            end
        end
    end

    return found
end

B.equipBuckler = function(player, entry)
    if entry == nil then
        player:unequipItem(xi.slot.SUB)
    else
        player:equipItem(entry.id, entry.container, xi.slot.SUB)
    end
end

local function virtualBlock(defender)
    if not B.isPolearmBucklerPlayer(defender) or not B.hasPolearmMain(defender) then
        return false
    end

    local sub = defender:getEquippedItem(xi.slot.SUB)
    return sub == nil
end

m:addOverride('xi.combat.physical.canBlock', function(defender, attacker, super)
    if virtualBlock(defender) then
        return defender:isFacing(attacker) and
            not defender:hasPreventActionEffect(true) and
            defender:getSkillRank(xi.skill.SHIELD) > 0
    end

    return super(defender, attacker)
end)

m:addOverride('xi.combat.physical.calculateBlockRate', function(defender, attacker, super)
    if virtualBlock(defender) then
        return B.VIRTUAL_BLOCK_RATE
    end

    -- Real Buckler in SUB with a 2H Polearm in MAIN: stock logic only inspects SUB.
    return super(defender, attacker)
end)

m:addOverride('xi.combat.physical.getDamageReductionForBlock', function(defender, attacker, damage, super)
    if virtualBlock(defender) then
        if damage <= 0 then
            return 0
        end

        local reduced = math.max(0, damage - defender:getMod(xi.mod.SHIELD_DEF_BONUS))
        reduced = math.floor(reduced * (100 - B.VIRTUAL_ABSORB_RATE) / 100)
        return damage - reduced
    end

    return super(defender, attacker, damage)
end)

return m