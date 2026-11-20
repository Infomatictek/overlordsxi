require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/job_utils/summoner')
require('scripts/globals/player')
require('scripts/globals/pets')

local m = Module:new('soulspire_smn_herald')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.SMN] then require('modules/custom/lua/smn_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')

local ACTIVE, ACCORD = 'OX_HLD_ACTIVE', 250
local elementNames = { 'Fire', 'Ice', 'Wind', 'Earth', 'Thunder', 'Water', 'Light', 'Dark' }
local roster =
{
    { 296, xi.petId.CARBUNCLE,  516, xi.element.LIGHT,   'Carbuncle',  'meteorite',   'Light Response', 10 },
    { 298, xi.petId.IFRIT,      545, xi.element.FIRE,    'Ifrit',      'fire_ii',     'Flame Response', 10 },
    { 302, xi.petId.SHIVA,      609, xi.element.ICE,     'Shiva',      'blizzard_ii', 'Frost Response', 30 },
    { 301, xi.petId.GARUDA,     593, xi.element.WIND,    'Garuda',     'aero_ii',     'Wind Response',  30 },
    { 299, xi.petId.TITAN,      561, xi.element.EARTH,   'Titan',      'stone_ii',    'Stone Response', 50 },
    { 300, xi.petId.LEVIATHAN,  577, xi.element.WATER,   'Leviathan',  'water_ii',    'Tidal Response', 50 },
    { 303, xi.petId.RAMUH,      625, xi.element.THUNDER, 'Ramuh',      'thunder_ii',  'Storm Response', 50 },
}
local byPet, byPact = {}, {}
local accords, members, pendingPacts = {}, {}, {}
local H = {}
xi.soulspire.herald = H

local function now()
    return xi.soulspire.nowSec()
end

local function scale(level, low, middle, high, cap)
    if level >= 70 then return cap end
    if level >= 50 then return high end
    if level >= 30 then return middle end
    return low
end

local function active(player)
    return player and player:isPC() and player:isAlive() and player:getMainJob() == xi.job.SMN and
        player:getMainLvl() >= 10 and player:getLocalVar(ACTIVE) == 1 and spec.is(player, xi.job.SMN, 'herald')
end

local function avatar(player)
    local pet = player:getPet()
    local row = pet and byPet[pet:getPetID()]
    if pet and pet:isAlive() and row and player:getMainLvl() >= row[8] then return pet, row end
end

local function sameBattle(a, b)
    return a:getZoneID() == b:getZoneID() and a:getBattleID() == b:getBattleID()
end

local function isEnemy(owner, target)
    return target and target:isMob() and target:isAlive() and not target:getMaster() and sameBattle(owner, target)
end

local function presentInParty(owner, member)
    if not member or not member:isAlive() or not sameBattle(owner, member) then return false end
    if owner:getID() == member:getID() then return true end
    for _, current in ipairs(owner:getParty()) do
        if current:getID() == member:getID() then return true end
    end
    return false
end

local function endAccord(id)
    local accord = accords[id]
    if not accord then return end
    for memberID, entry in pairs(accord.members) do
        if members[memberID] == entry then members[memberID] = nil end
    end
    accords[id] = nil
end

local function envoy(accord)
    if accord.expires <= now() then return end
    local owner = GetPlayerByID(accord.herald)
    if not active(owner) or owner:getZoneID() ~= accord.zone or owner:getBattleID() ~= accord.battle then return end
    local pet = avatar(owner)
    if pet and pet:getID() == accord.pet then return owner end
end

local function createAccord(player, pet, element)
    local id, level = player:getID(), player:getMainLvl()
    local previous = accords[id]
    endAccord(id)
    local accord =
    {
        herald = id, pet = pet:getID(), element = element, pct = scale(level, 8, 10, 10, 12),
        expires = now() + (level >= 70 and 10 or 8),
        zone = player:getZoneID(), battle = player:getBattleID(), members = {},
    }
    local function invite(member)
        local memberID = member:getID()
        if not member:isPC() or not member:isAlive() or not sameBattle(player, member) or
            (memberID ~= id and player:checkDistance(member) > 15) then return end
        local prior = members[memberID] or previous and previous.members[memberID]
        local live = prior and envoy(prior.accord)
        if live and prior.accord.pct > accord.pct then return end
        local entry =
        {
            accord = accord,
            spent = live and prior.accord.element == element and (prior.spent or prior.reserved) or false,
        }
        members[memberID] = entry
        accord.members[memberID] = entry
    end
    invite(player)
    for _, member in ipairs(player:getParty()) do
        if member:getID() ~= id then invite(member) end
    end
    accords[id] = accord
    player:timer((accord.expires - now()) * 1000, function()
        if accords[id] == accord then endAccord(id) end
    end)
end

function H.reserve(actor, target, element, damage, ordinaryDamage)
    if damage <= 0 then return damage end
    local principal = actor:isPC() and actor or actor:isPet() and actor:getMaster() or nil
    if not principal or not principal:isPC() or not principal:isAlive() or not isEnemy(principal, target) or
        not sameBattle(principal, actor) then return damage end
    local entry = members[principal:getID()]
    if not entry or entry.spent or entry.reserved or entry.accord.element ~= element then return damage end
    local owner = envoy(entry.accord)
    if not owner or not presentInParty(owner, principal) then return damage end
    local base = math.min(damage, ordinaryDamage or damage)
    local boosted = target:checkDamageCap(math.min(99999, damage + math.floor(base * entry.accord.pct / 100)))
    if boosted <= damage then return damage end
    entry.reserved = true
    return boosted, entry
end

function H.finish(entry, hpLost)
    if not entry then return end
    entry.reserved = nil
    if hpLost > 0 then entry.spent = true end
end

function H.preparePetClaim(pet, target, element, damage, ordinaryDamage)
    -- The native pet callback settles this claim with actual HP loss.
    if pet:getLocalVar('OX_HLD_PET_SCOPE') ~= 1 or pet:getLocalVar('OX_HLD_PET_PENDING') == 1 then return damage end
    local boosted, entry = H.reserve(pet, target, element, damage, ordinaryDamage)
    if entry then
        pendingPacts[pet:getID()] = { target = target:getID(), entry = entry }
        pet:setLocalVar('OX_HLD_PET_PENDING', 1)
    end
    return boosted
end

function H.finishPetClaim(pet, target, hpLost)
    local pending = pendingPacts[pet:getID()]
    pendingPacts[pet:getID()] = nil
    pet:setLocalVar('OX_HLD_PET_PENDING', 0)
    if pending then H.finish(pending.entry, pending.target == target:getID() and hpLost or 0) end
end

local function pactMP(player)
    return scale(player:getMainLvl(), 8, 12, 16, 20)
end

function H.pactCost(player, id)
    if active(player) and byPact[id] then return pactMP(player) end
end

local function accordCost(player)
    return math.max(1, math.ceil(player:getMaxMP() * 0.08))
end

m:addOverride('xi.actions.abilities.avatars_favor.onAbilityCheck', function(player, target, ability)
    if not active(player) then return super(player, target, ability) end
    if not avatar(player) or player:getMP() < accordCost(player) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setMsg(xi.msg.basic.NONE)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.avatars_favor.onUseAbility', function(player, target, ability, action)
    if not active(player) then return super(player, target, ability, action) end
    local pet, row = avatar(player)
    if not pet or player:getMP() < accordCost(player) then return 0 end
    player:delMP(accordCost(player))
    createAccord(player, pet, row[4])
    return 0
end)

m:addOverride('xi.actions.abilities.release.onUseAbility', function(player, target, ability, action)
    if active(player) then endAccord(player:getID()) end
    return super(player, target, ability, action)
end)

m:addOverride('xi.pet.spawnPet', function(owner, petID, state, target)
    super(owner, petID, state, target)
    if active(owner) then endAccord(owner:getID()) end
end)

local spellKit, abilityKit = {}, {}
local unpackRow = table.unpack or unpack
for _, row in ipairs(roster) do
    local spell, petID, id, element, name, script, response, level = unpackRow(row)
    byPet[petID], byPact[id] = row, row
    spellKit[spell] =
    {
        script = name:lower(), name = 'Invite ' .. name,
        description = 'Invite ' .. name .. ' to select the element of your next Astral Accord.',
        unlockLvl = level, castMs = 1500, recastSec = 5, mpCost = 5,
    }
    abilityKit[id] = { name = response, description = 'Command an elemental strike that can claim your Astral Accord.', recastTime = 20 }
    local hook = 'xi.actions.abilities.pets.' .. script
    m:addOverride(hook .. '.onAbilityCheck', function(player, target, ability)
        if not active(player) then return super(player, target, ability) end
        local pet, current = avatar(player)
        if not pet or current ~= row or not isEnemy(player, target) or
            pet:getCurrentAction() == xi.action.category.PET_MOBABILITY_FINISH then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
        return super(player, target, ability)
    end)
    m:addOverride(hook .. '.onPetAbility', function(target, pet, skill, owner, action)
        if not active(owner) then return super(target, pet, skill, owner, action) end
        local current, petInfo = avatar(owner)
        if not current or current:getID() ~= pet:getID() or petInfo ~= row or not isEnemy(owner, target) or
            owner:getMP() < pactMP(owner) then return 0 end
        xi.job_utils.summoner.onUseBloodPact(target, pet, skill, owner, action)
        local params =
        {
            baseDamage = pet:getMainLvl() + 4, fTP = { 1.5, 2.0, 2.5 }, int_wSC = 0.30,
            element = element, attackType = xi.attackType.MAGICAL, damageType = xi.damageType.ELEMENTAL + element,
            shadowBehavior = xi.mobskills.shadowBehavior.IGNORE_SHADOWS, dStatMultiplier = 1.5,
            canMagicBurst = true, primaryMessage = xi.msg.basic.USES_JA_TAKE_DAMAGE,
        }
        local result = xi.mobskills.mobMagicalMove(pet, target, skill, action, params)
        if xi.mobskills.processDamage(pet, target, skill, action, result) then
            target:takeDamage(result.damage, pet, result.attackType, result.damageType)
        end
        return result.damage
    end)
end

abilityKit[ACCORD] = { name = 'Astral Accord', description = 'Invite nearby party members to empower one hit matching your avatar’s element. Costs 8% max MP.', recastTime = 30 }
abilityKit[88] = { name = 'Send Envoy', description = 'Send your avatar after the selected enemy.', recastTime = 5 }
abilityKit[89] = { name = 'Recall Envoy', description = 'Call your avatar back to your side.', recastTime = 5 }
abilityKit[90] = { name = 'Dismiss Envoy', description = 'Dismiss your avatar and end its Astral Accord.', recastTime = 5 }
abilityKit[91] = { name = 'Envoy Responses', description = 'Open the active avatar’s elemental response menu.' }
actions.register('herald', { spell = spellKit, ability = abilityKit })
xi.soulspire.smnHeraldSpecs = { HERALD_KIT_SPELLS = spellKit }

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    if player:getPet() and not avatar(player) then player:despawnPet() end
    player:sendSoulSpellList()
end

local function remove(player)
    endAccord(player:getID())
    player:setLocalVar(ACTIVE, 0)
    if player:getPet() and byPet[player:getPet():getPetID()] then player:despawnPet() end
    player:sendSoulSpellList()
end

spec.registerCrystal(xi.job.SMN,
{
    id = 3, key = 'herald', name = 'Herald', abr = 'HLD', role = 'Support', icon = 'herald', reqLevel = 10,
    description = 'Invite a party to follow your avatar’s element. Each member has a separate opportunity to strengthen one matching hit.',
    highlights =
    {
        'Lv.10: Invite Carbuncle or Ifrit, cast Astral Accord and follow through with the avatar’s response.',
        'Astral Accord snapshots party members within 15 yalms, costs 8% Max MP and recasts in 30 seconds.',
        'One matching direct elemental hit per member. Pets share their master’s claim. The bonus scales to 8/10/10/12%.',
        'Shiva and Garuda open at Lv.30. Titan, Leviathan and Ramuh open at Lv.50. The window extends from 8 to 10 seconds at Lv.70.',
    },
    extraAbilities = function(_, level)
        if level < 10 then return {} end
        local kit = { 88, 89, 90, 91, ACCORD }
        for _, row in ipairs(roster) do
            if level >= row[8] then kit[#kit + 1] = row[3] end
        end
        return kit
    end,
    mods = function(_, level)
        return
        {
            { xi.mod.SUMMONING_MAGIC_SKILL, scale(level, 10, 18, 28, 38) },
            { xi.mod.MPP, scale(level, 6, 10, 14, 18) },
            { xi.mod.PERPETUATION_REDUCTION, scale(level, 3, 4, 5, 6) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if player:getMainJob() ~= xi.job.SMN or not spec.is(player, xi.job.SMN, 'herald') then return end
        if event == 'onGameIn' then endAccord(player:getID()) end
        if player:getMainLvl() >= 10 then
            apply(player)
            player:recalculateAbilitiesTable()
        elseif player:getLocalVar(ACTIVE) == 1 then
            remove(player)
            player:recalculateAbilitiesTable()
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('herald', function(player)
        local _, row = avatar(player)
        local accord = accords[player:getID()]
        local readyCount, total = 0, 0
        local live = accord and envoy(accord)
        if live then
            for id, entry in pairs(accord.members) do
                if members[id] == entry and presentInParty(player, GetPlayerByID(id)) then
                    total = total + 1
                    if not entry.spent then readyCount = readyCount + 1 end
                end
            end
        end
        return
        {
            avatar = row and row[5] or '', element = row and elementNames[row[4]] or '',
            window = live and accord.expires - now() or 0,
            ready = readyCount, total = total, pct = live and accord.pct or 0, mp = accordCost(player),
        }
    end)
end

return m
