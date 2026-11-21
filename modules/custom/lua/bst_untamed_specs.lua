require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/pets')
require('scripts/globals/utils')

local m = Module:new('soulspire_bst_untamed')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.BST] then require('modules/custom/lua/bst_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')

local REND, FIGHT, HEEL, LEAVE, REWARD, CALL, READY, LOYALTY, KICK = 52, 69, 70, 71, 78, 85, 251, 387, 672
local ACTIVE = 'OX_UNT_ACTIVE'
local TO_PET, TO_MASTER = 'OX_UNT_TO_PET', 'OX_UNT_TO_MASTER'
local LISTENER = 'OX_UNT_AXE_WS'
local COOLDOWN = 8
local petStats =
{
    { xi.mod.ACC, 'OX_UNT_ACC', 10, 18, 28, 40 },
    { xi.mod.ATT, 'OX_UNT_ATT', 15, 28, 42, 60 },
    { xi.mod.DOUBLE_ATTACK, 'OX_UNT_DA', 3, 5, 7, 10 },
}

local function scale(level, low, middle, high, cap)
    if level >= 70 then return cap end
    if level >= 50 then return high end
    if level >= 30 then return middle end
    return low
end

local function active(player)
    return player and player:isPC() and player:getMainJob() == xi.job.BST and player:getMainLvl() >= 10 and
        player:getLocalVar(ACTIVE) == 1 and spec.is(player, xi.job.BST, 'untamed')
end

local function companion(player)
    local pet = player:getPet()
    if pet and pet:isAlive() and player:hasJugPet() and pet:getPetID() == xi.petId.HARE_FAMILIAR then return pet end
end

local function axe(player)
    local weapon = player:getWeaponSkillType(xi.slot.MAIN)
    return weapon == xi.skill.AXE or weapon == xi.skill.GREAT_AXE
end

local function sharesTarget(player, pet, target)
    if not target or not target:isMob() or not target:isAlive() or not axe(player) then return false end
    local primary, petTarget = player:getTarget(), pet:getTarget()
    return player:getZoneID() == pet:getZoneID() and pet:getZoneID() == target:getZoneID() and
        primary and petTarget and primary:getID() == target:getID() and petTarget:getID() == target:getID()
end

local function remaining(player, marker)
    return math.max(0, player:getLocalVar(marker) - xi.soulspire.nowSec())
end

local function exchange(player, pet, target, damage, fromPet)
    if not active(player) or not pet or not damage or damage <= 0 or not sharesTarget(player, pet, target) then return false end
    local marker = fromPet and TO_MASTER or TO_PET
    local recipient = fromPet and player or pet
    if remaining(player, marker) > 0 or recipient:getTP() >= 3000 then return false end
    local level = player:getMainLvl()
    recipient:addTP(fromPet and scale(level, 75, 100, 125, 150) or scale(level, 125, 175, 225, 275))
    player:setLocalVar(marker, xi.soulspire.nowSec() + COOLDOWN)
    return true
end

local function syncPet(pet, level)
    for _, row in ipairs(petStats) do
        local before = pet:getLocalVar(row[2])
        local after = level > 0 and scale(level, row[3], row[4], row[5], row[6]) or 0
        if before ~= after then
            pet:addMod(row[1], after - before)
            pet:setLocalVar(row[2], after)
        end
    end
end

local function apply(player)
    if not spec.is(player, xi.job.BST, 'untamed') or player:getMainLvl() < 10 then return end
    player:setLocalVar(ACTIVE, 1)
    player:removeListener(LISTENER)
    player:addListener('WEAPONSKILL_USE', LISTENER, function(actor, target, _, _, _, damage)
        if active(actor) then exchange(actor, companion(actor), target, damage, false) end
    end)
    local pet = companion(player)
    if pet then syncPet(pet, player:getMainLvl()) end
    player:sendSoulSpellList()
end

local function remove(player)
    local pet = companion(player)
    player:setLocalVar(ACTIVE, 0)
    player:removeListener(LISTENER)
    if pet then
        syncPet(pet, 0)
        if pet:getLocalVar('OX_UNT_SUMMONED') == 1 then player:despawnPet() end
    end
    player:sendSoulSpellList()
end

local function callCheck(player, target, ability)
    if not active(player) then return super(player, target, ability) end
    if player:getPet() then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    return 0, 0
end

local function callUse(player, target, ability, action)
    if not active(player) then return super(player, target, ability, action) end
    xi.pet.spawnPet(player, xi.petId.HARE_FAMILIAR)
    local pet = companion(player)
    if pet then
        pet:setLocalVar('OX_UNT_SUMMONED', 1)
        syncPet(pet, player:getMainLvl())
    end
    return 0
end

for _, name in ipairs({ 'call_beast', 'bestial_loyalty' }) do
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', callCheck)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', callUse)
end

m:addOverride('xi.actions.abilities.charm.onAbilityCheck', function(player, target, ability)
    if not active(player) then return super(player, target, ability) end
    local pet = companion(player)
    if not pet or not sharesTarget(player, pet, target) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.charm.onUseAbility', function(player, target, ability, action)
    if not active(player) then return super(player, target, ability, action) end
    local pet = companion(player)
    if not pet or not sharesTarget(player, pet, target) then return 0 end
    local hitRate = xi.combat.physicalHitRate.getPhysicalHitRate(player, target, 0, xi.slot.MAIN, false)
    if math.random() >= hitRate then
        if action then action:messageID(target:getID(), xi.msg.basic.HIT_MISS) end
        return 0
    end
    local weapon = player:getWeaponSkillType(xi.slot.MAIN)
    local pdif = xi.combat.physical.calculateMeleePDIF(player, target, weapon, 1, false, true, false, 0, false, xi.slot.MAIN, false)
    local base = player:getWeaponDmg(xi.slot.MAIN) + math.floor(player:getStat(xi.mod.STR) / 4)
    local scalar = xi.combat.damage.calculateDamageAdjustment(target, true, false, false, false) *
        xi.combat.damage.physicalElementSDT(target, xi.damageType.SLASHING)
    local damage = math.max(0, math.floor(base * pdif * scalar * scale(player:getMainLvl(), 1.2, 1.35, 1.5, 1.65)))
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        damage = xi.customBossServer.scaleDamageByLevelGap(player, target, damage)
    end
    damage = utils.clamp(utils.handlePhalanx(target, damage), 0, 99999)
    damage = utils.handleStoneskin(target, damage, xi.attackType.PHYSICAL)
    local hp = target:getHP()
    target:takeDamage(target:checkDamageCap(damage), player, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    local landed = math.max(0, hp - target:getHP())
    if landed > 0 then
        target:updateEnmityFromDamage(player, landed)
        exchange(player, pet, target, landed, false)
    end
    if action then action:messageID(target:getID(), xi.msg.basic.JA_DAMAGE) end
    return landed
end)

m:addOverride('xi.actions.abilities.pets.foot_kick.onAbilityCheck', function(player, target, ability)
    if not active(player) then return super(player, target, ability) end
    local pet = companion(player)
    if not pet or not sharesTarget(player, pet, player:getTarget()) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    return 0, 0
end)

m:addOverride('xi.actions.abilities.pets.foot_kick.onPetAbility', function(target, pet, skill, owner, action)
    local hp = target:getHP()
    local result = super(target, pet, skill, owner, action)
    if active(owner) then
        local expected = companion(owner)
        if expected and expected:getID() == pet:getID() then exchange(owner, pet, target, hp - target:getHP(), true) end
    end
    return result
end)

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if player:getMainJob() ~= xi.job.BST or not spec.is(player, xi.job.BST, 'untamed') then return end
        if player:getMainLvl() >= 10 then
            apply(player)
            player:recalculateAbilitiesTable()
        elseif player:getLocalVar(ACTIVE) == 1 then
            remove(player)
            player:recalculateAbilitiesTable()
        end
    end)
end

actions.register('untamed',
{
    ability =
    {
        [REND] = { name = 'Pack Rend', description = 'Strike your beast’s target with an axe. A landed hit feeds TP to your beast when the link is ready.', recastTime = 8 },
        [FIGHT] = { name = 'Set Quarry', description = 'Order your beast to attack one enemy.', recastTime = 5 },
        [HEEL] = { name = 'Fall Back', description = 'Call your beast back to your side.', recastTime = 5 },
        [LEAVE] = { name = 'Dismiss Beast', description = 'Dismiss your active companion.', recastTime = 5 },
        [REWARD] = { name = 'Feed Beast', description = 'Spend pet food from the ammo slot to heal your companion.', recastTime = 90 },
        [CALL] = { name = 'Call Packmate', description = 'Summon a hare companion without spending a jug.', recastTime = 300 },
        [READY] = { name = 'Pack Commands', description = 'Open your companion’s technique list.' },
        [LOYALTY] = { name = 'Rally Packmate', description = 'Summon a replacement hare companion on a separate cooldown.', recastTime = 1200 },
        [KICK] = { name = 'Raking Kick', description = 'Your beast strikes your shared enemy. A landed hit returns TP to you when the link is ready. Costs one charge.' },
    },
})

spec.registerCrystal(xi.job.BST,
{
    id = 1, key = 'untamed', name = 'Untamed', abr = 'UNT', role = 'Damage', icon = 'untamed', reqLevel = 10,
    description = 'Fight alongside an offensive hare and trade TP as you land attacks against the same enemy.',
    highlights =
    {
        'Lv.10: Call Packmate, Set Quarry, Pack Rend and Raking Kick give the Soul a complete opening loop.',
        'Pack Rend or landed axe and great axe weapon skills feed the hare 125/175/225/275 TP.',
        'Landed Raking Kick returns 75/100/125/150 TP. The two links each recover in 8 seconds.',
        'Lv.30: Rally Packmate adds a separate summon recast. Offensive scaling increases at Lv.30, 50 and 70.',
    },
    extraAbilities = function(_, level)
        if level < 10 then return {} end
        -- The native pet command table exposes KICK only while the hare is present.
        local learned = { REND, FIGHT, HEEL, LEAVE, REWARD, CALL, READY, KICK }
        if level >= 30 then learned[#learned + 1] = LOYALTY end
        return learned
    end,
    mods = function(_, level)
        return
        {
            { xi.mod.AXE, scale(level, 12, 22, 34, 46) },
            { xi.mod.GREAT_AXE, scale(level, 10, 18, 28, 38) },
            { xi.mod.ACC, scale(level, 10, 18, 28, 40) },
            { xi.mod.ATT, scale(level, 12, 25, 38, 55) },
            { xi.mod.DOUBLE_ATTACK, scale(level, 3, 5, 7, 10) },
            { xi.mod.STORETP, scale(level, 3, 5, 8, 12) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('untamed', function(player)
        local pet = companion(player)
        return
        {
            pet = pet and 1 or 0,
            pet_tp = pet and pet:getTP() or 0,
            master_tp = player:getTP(),
            shared = pet and sharesTarget(player, pet, player:getTarget()) and 1 or 0,
            to_pet = remaining(player, TO_PET),
            to_master = remaining(player, TO_MASTER),
        }
    end)
end

return m
