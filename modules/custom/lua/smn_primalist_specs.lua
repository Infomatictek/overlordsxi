require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/job_utils/summoner')
require('scripts/globals/player')
require('scripts/globals/pets')

local m = Module:new('soulspire_smn_primalist')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.SMN] then require('modules/custom/lua/smn_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')

local ACTIVE, CHOICE_A, CHOICE_B = 'OX_PRM_ACTIVE', 'OX_PRM_CHOICE_A', 'OX_PRM_CHOICE_B'
local CHALLENGE, RETREAT, RELEASE, MENU, SELECT_A, SELECT_B = 88, 89, 90, 91, 232, 296
local AVATARS =
{
    { 296, xi.petId.CARBUNCLE,  516, xi.element.LIGHT,   'Carbuncle',  'meteorite',  'Astral Comet',  10 },
    { 298, xi.petId.IFRIT,      545, xi.element.FIRE,    'Ifrit',      'fire_ii',    'Inferno Brand', 10 },
    { 302, xi.petId.SHIVA,      609, xi.element.ICE,     'Shiva',      'blizzard_ii','Glacial Edge',  30 },
    { 301, xi.petId.GARUDA,     593, xi.element.WIND,    'Garuda',     'aero_ii',    'Gale Rend',     30 },
    { 299, xi.petId.TITAN,      561, xi.element.EARTH,   'Titan',      'stone_ii',   'Fault Strike',  30 },
    { 300, xi.petId.LEVIATHAN,  577, xi.element.WATER,   'Leviathan',  'water_ii',   'Undertow',      30 },
    { 303, xi.petId.RAMUH,      625, xi.element.THUNDER, 'Ramuh',      'thunder_ii', 'Storm Lance',   30 },
}
local byPet, byPact = {}, {}
local windows = {}
local P = {}
xi.soulspire.primalist = P

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
    return player and player:isPC() and player:getMainJob() == xi.job.SMN and player:getMainLvl() >= 10 and
        player:getLocalVar(ACTIVE) == 1 and spec.is(player, xi.job.SMN, 'primalist')
end

local function available(player, info)
    local level = player:getMainLvl()
    return info and (info[8] == 10 or level >= 50 or (level >= 30 and
        (info[1] == player:getLocalVar(CHOICE_A) or info[1] == player:getLocalVar(CHOICE_B))))
end

local function avatar(player)
    local pet = player:getPet()
    local info = pet and byPet[pet:getPetID()]
    if not pet or not pet:isAlive() or not available(player, info) then return end
    return pet, info
end

local function targetable(player, enemy)
    return enemy and enemy:isMob() and enemy:isAlive() and not enemy:getMaster() and
        enemy:getZoneID() == player:getZoneID() and enemy:getBattleID() == player:getBattleID()
end

local function pactCost(player)
    return scale(player:getMainLvl(), 8, 14, 20, 26)
end

function P.pactCost(player, id)
    if active(player) and byPact[id] then return pactCost(player) end
end

local function weakest(target, element)
    local modifier = xi.data.element.getElementalResistanceRankModifier
    local rank = target:getMod(modifier(element))
    for elem = xi.element.FIRE, xi.element.DARK do
        if target:getMod(modifier(elem)) < rank then return false end
    end
    return true
end

local function window(player, pet)
    local state = windows[player:getID()]
    if pet and state and state.pet == pet:getID() and state.untilSec > now() then return state end
end

local function applyChallenge(player, pet, target, element, damage)
    local state = window(player, pet)
    if not state or state.target ~= target:getID() or state.spawn ~= target:getLocalVar('OX_ARC_SPAWN') then return damage end
    windows[player:getID()] = nil
    if damage <= 0 or not weakest(target, element) then return damage end
    return math.floor(damage * (100 + scale(player:getMainLvl(), 20, 25, 30, 35)) / 100)
end

m:addOverride('xi.actions.abilities.assault.onAbilityCheck', function(player, target, ability)
    if not active(player) then return super(player, target, ability) end
    if not avatar(player) or not targetable(player, target) or player:checkDistance(target) > 20 then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setMsg(xi.msg.basic.NONE)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.assault.onUseAbility', function(player, target, ability, action)
    if not active(player) then return super(player, target, ability, action) end
    local pet = avatar(player)
    if not pet or not targetable(player, target) then return 0 end
    local id = player:getID()
    local record =
    {
        pet = pet:getID(), target = target:getID(), spawn = target:getLocalVar('OX_ARC_SPAWN'),
        untilSec = now() + (player:getMainLvl() >= 70 and 15 or 12),
    }
    windows[id] = record
    player:timer((record.untilSec - now()) * 1000, function()
        if windows[id] == record then windows[id] = nil end
    end)
    player:petAttack(target)
    return 0
end)

local function clear(player)
    windows[player:getID()] = nil
end

for _, name in ipairs({ 'retreat', 'release' }) do
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', function(player, target, ability, action)
        if active(player) then clear(player) end
        return super(player, target, ability, action)
    end)
end

local spellKit, abilityKit = {}, {}
local unpackAvatar = table.unpack or unpack
for _, info in ipairs(AVATARS) do
    local spell, petID, ability, element, name, script, pactName, unlock = unpackAvatar(info)
    byPet[petID], byPact[ability] = info, info
    local suffix = unlock == 30 and ' Choose it in a loan slot from Lv. 30. All prime avatars are available at Lv. 50.' or ''
    spellKit[spell] =
    {
        script = name:lower(), name = 'Call ' .. name, description = 'Summon ' .. name .. ' for its elemental pact.' .. suffix,
        unlockLvl = unlock, castMs = 1500, recastSec = 5, mpCost = 5,
    }
    abilityKit[ability] =
    {
        name = pactName, description = 'Command ' .. name .. ' to strike one enemy with its element. An active Challenge can empower the strike.' .. suffix,
        recastTime = 18,
    }
    local hook = 'xi.actions.abilities.pets.' .. script
    m:addOverride(hook .. '.onAbilityCheck', function(player, target, ja)
        if not active(player) then return super(player, target, ja) end
        local pet, current = avatar(player)
        if not pet or current ~= info or not targetable(player, target) or
            pet:getCurrentAction() == xi.action.category.PET_MOBABILITY_FINISH then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        return super(player, target, ja)
    end)
    m:addOverride(hook .. '.onPetAbility', function(target, pet, skill, owner, action)
        if not active(owner) then return super(target, pet, skill, owner, action) end
        local current, petInfo = avatar(owner)
        if not current or current:getID() ~= pet:getID() or petInfo ~= info or not targetable(owner, target) or
            owner:getMP() < pactCost(owner) then return 0 end

        xi.job_utils.summoner.onUseBloodPact(target, pet, skill, owner, action)
        local params =
        {
            baseDamage = pet:getMainLvl() + 8, fTP = { 2.5, 3.0, 3.5 }, int_wSC = 0.30,
            element = element, attackType = xi.attackType.MAGICAL, damageType = xi.damageType.ELEMENTAL + element,
            shadowBehavior = xi.mobskills.shadowBehavior.IGNORE_SHADOWS, dStatMultiplier = 1.5,
            canMagicBurst = true, primaryMessage = xi.msg.basic.USES_JA_TAKE_DAMAGE,
        }
        local result = xi.mobskills.mobMagicalMove(pet, target, skill, action, params)
        result.damage = applyChallenge(owner, pet, target, element, result.damage)
        if xi.mobskills.processDamage(pet, target, skill, action, result) then
            target:takeDamage(result.damage, pet, result.attackType, result.damageType)
        end
        return result.damage
    end)
end

local function choiceValid(value)
    return value >= 299 and value <= 303
end

local function syncChoices(player)
    local a, b = player:getCharVar(CHOICE_A), player:getCharVar(CHOICE_B)
    if not choiceValid(a) then a = 302 end
    if not choiceValid(b) or b == a then b = a == 301 and 302 or 301 end
    player:setLocalVar(CHOICE_A, a)
    player:setLocalVar(CHOICE_B, b)
end

local function cycle(player, slot, other)
    local selected = player:getLocalVar(slot)
    repeat
        selected = selected >= 303 and 299 or selected + 1
    until selected ~= player:getLocalVar(other)
    player:setCharVar(slot, selected)
    syncChoices(player)
    if player:getPet() and not avatar(player) then player:despawnPet() end
    clear(player)
    player:sendSoulSpellList()
end

for _, slot in ipairs({
    { 'elemental_siphon', CHOICE_A, CHOICE_B },
    { 'mana_cede', CHOICE_B, CHOICE_A },
}) do
    local hook = 'xi.actions.abilities.' .. slot[1]
    m:addOverride(hook .. '.onAbilityCheck', function(player, target, ability)
        if not active(player) then return super(player, target, ability) end
        if player:getMainLvl() < 30 or player:getMainLvl() >= 50 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
        ability:setMsg(xi.msg.basic.NONE)
        return 0, 0
    end)
    m:addOverride(hook .. '.onUseAbility', function(player, target, ability, action)
        if not active(player) then return super(player, target, ability, action) end
        if player:getMainLvl() >= 30 and player:getMainLvl() < 50 then cycle(player, slot[2], slot[3]) end
        return 0
    end)
end

m:addOverride('xi.pet.spawnPet', function(player, petID, state, target)
    super(player, petID, state, target)
    if active(player) then clear(player) end
end)

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    syncChoices(player)
    if player:getPet() and not avatar(player) then player:despawnPet() end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    clear(player)
    if player:getPet() and byPet[player:getPet():getPetID()] then player:despawnPet() end
    player:sendSoulSpellList()
end

abilityKit[CHALLENGE] = { name = 'Challenge Aspect', description = 'Send your avatar after an enemy and commit its element to the next matching pact.', recastTime = 20 }
abilityKit[RETREAT] = { name = 'Recall Avatar', description = 'Call your avatar back and close any open Challenge.', recastTime = 5 }
abilityKit[RELEASE] = { name = 'End Manifestation', description = 'Dismiss your avatar and close any open Challenge.', recastTime = 5 }
abilityKit[MENU] = { name = 'Elemental Pacts', description = 'Open the active avatar’s elemental pact menu.' }
abilityKit[SELECT_A] = { name = 'Attune First Prime', description = 'Cycle the first avatar loan slot from Lv. 30 through 49.', recastTime = 1 }
abilityKit[SELECT_B] = { name = 'Attune Second Prime', description = 'Cycle the second avatar loan slot from Lv. 30 through 49.', recastTime = 1 }
actions.register('primalist', { spell = spellKit, ability = abilityKit })
xi.soulspire.smnPrimalistSpecs = { PRIMALIST_KIT_SPELLS = spellKit }

spec.registerCrystal(xi.job.SMN,
{
    id = 1, key = 'primalist', name = 'Primalist', abr = 'PRM', role = 'Damage', icon = 'primalist', reqLevel = 10,
    description = 'Commit an avatar’s element to a single target and exploit the enemy’s weakest elemental resistance.',
    highlights =
    {
        'Lv.10: Call Carbuncle or Ifrit and use Challenge Aspect with its single-target elemental pact.',
        'Lv.30: Pick two additional primes. Lv.50: All seven avatars are available.',
        'Challenges empower matching pacts by 20/25/30/35% for the least resisted element. The window lasts 12 seconds, or 15 from Lv.70.',
    },
    extraAbilities = function(_, level)
        if level < 10 then return {} end
        local kit = { CHALLENGE, RETREAT, RELEASE, MENU }
        if level >= 30 and level < 50 then
            kit[#kit + 1] = SELECT_A
            kit[#kit + 1] = SELECT_B
        end
        for _, info in ipairs(AVATARS) do
            if level >= info[8] then kit[#kit + 1] = info[3] end
        end
        return kit
    end,
    mods = function(_, level)
        return
        {
            { xi.mod.SUMMONING_MAGIC_SKILL, scale(level, 12, 22, 34, 46) },
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
        if player:getMainJob() ~= xi.job.SMN or not spec.is(player, xi.job.SMN, 'primalist') then return end
        if event == 'onGameIn' then clear(player) end
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
    xi.soulspire.hud.registerProvider('primalist', function(player)
        local pet, info = avatar(player)
        local state = window(player, pet)
        local a, b = '', ''
        for _, row in ipairs(AVATARS) do
            if row[1] == player:getLocalVar(CHOICE_A) then a = row[5] end
            if row[1] == player:getLocalVar(CHOICE_B) then b = row[5] end
        end
        local target = state and GetMobByID(state.target)
        return
        {
            avatar = info and info[5] or '',
            window = state and state.untilSec - now() or 0,
            match = target and targetable(player, target) and target:getLocalVar('OX_ARC_SPAWN') == state.spawn and weakest(target, info[4]) and 1 or 0,
            pact_mp = pactCost(player),
            choice = player:getMainLvl() >= 30 and player:getMainLvl() < 50 and (a .. ' / ' .. b) or '',
        }
    end)
end

return m
