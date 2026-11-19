-----------------------------------
-- OverlordsXI Untamed (BST) — Feral Synchronization
-- Pure DPS: master and beast trade offensive openings.
-- No resource meter, no pet threat transfer, no defensive guardians.
-- Additive to existing Alpha Warden BST implementation.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_bst_untamed')
local spec = xi.overlords.spec
local BST = xi.job.BST
local KEY = 'untamed'
local MASTER_WS_LISTENER = 'OX_UNTAMED_MASTER_WS'
local PET_WS_LISTENER = 'OX_UNTAMED_PET_WS'
local PET_TP_MARKER = 'OX_UNTAMED_PET_REACTION'
local MASTER_TP_MARKER = 'OX_UNTAMED_MASTER_REACTION'
local petModsByID = {}

local function tier(level, low, mid, high, cap)
    if level >= 70 then return cap end
    if level >= 50 then return high end
    if level >= 30 then return mid end
    return low
end

local function isUntamed(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == BST and player:getMainLvl() >= 10 and
        spec.is(player, BST, KEY)
end

local function alivePet(master)
    local pet = master and master.getPet and master:getPet() or nil
    if not pet or not pet.isAlive or not pet:isAlive() then return nil end
    if master.hasJugPet and not master:hasJugPet() then return nil end
    return pet
end

local function isMeleeAxe(master)
    if not master or not master.getWeaponSkillType then return false end
    local weapon = master:getWeaponSkillType(xi.slot.MAIN)
    return weapon == xi.skill.AXE or weapon == xi.skill.GREAT_AXE
end

-- Only one opportunity for each side per window. This is a reaction-
-- timing mechanic, not a permanent or indefinitely accumulating stack.
local function ready(entity, marker, cooldown)
    if not entity or not entity.getLocalVar or not entity.setLocalVar then return false end
    local now = xi.overlords.nowSec()
    local previous = entity:getLocalVar(marker) or 0
    if previous > now then previous = 0 end
    if previous ~= 0 and now - previous < cooldown then return false end
    entity:setLocalVar(marker, now)
    return true
end

local function clearPetMods(pet)
    if not pet or not pet.getID then return end
    local id = pet:getID()
    local prev = petModsByID[id]
    if prev and pet.delMod then
        for _, bonus in ipairs(prev) do
            pet:delMod(bonus[1], bonus[2])
        end
    end
    petModsByID[id] = nil
end

local function syncPetMods(master, pet)
    if not pet or not pet.getID or not pet.addMod then return end
    if not isUntamed(master) then clearPetMods(pet); return end

    -- Offensive pet identity only; never grant the guardian's defensive
    -- immunity, HP, damage-split, or extra enmity.
    local level = master:getMainLvl()
    local desired =
    {
        { xi.mod.ACC, tier(level, 10, 18, 28, 40) },
        { xi.mod.ATT, tier(level, 15, 28, 42, 60) },
        { xi.mod.DOUBLE_ATTACK, tier(level, 3, 5, 7, 10) },
    }
    local id = pet:getID()
    local prev = petModsByID[id]
    local changed = prev == nil or #prev ~= #desired
    if not changed then
        for index, bonus in ipairs(desired) do
            if prev[index][1] ~= bonus[1] or prev[index][2] ~= bonus[2] then
                changed = true
                break
            end
        end
    end
    if not changed then return end
    clearPetMods(pet)
    for _, bonus in ipairs(desired) do
        pet:addMod(bonus[1], bonus[2])
    end
    petModsByID[id] = desired
end

local function detach(master)
    if not master then return end
    if master.removeListener then master:removeListener(MASTER_WS_LISTENER) end
    local pet = master.getPet and master:getPet() or nil
    if pet and pet.removeListener then pet:removeListener(PET_WS_LISTENER) end
    if pet then clearPetMods(pet) end
end

local function attachPet(master, pet)
    if not isUntamed(master) or not pet or not pet.addListener then return end
    if pet.removeListener then pet:removeListener(PET_WS_LISTENER) end
    syncPetMods(master, pet)
    pet:addListener('WEAPONSKILL_STATE_EXIT', PET_WS_LISTENER,
    function(actor, _skill, completed)
        if not completed or not actor or not actor.getMaster then return end
        local owner = actor:getMaster()
        if not isUntamed(owner) or alivePet(owner) ~= actor or
           not isMeleeAxe(owner) or not owner.addTP or
           not ready(owner, MASTER_TP_MARKER, 8) then
            return
        end

        -- The beast's real Ready action opens an offensive opportunity
        -- for the master. Modest TP return instead of a copied damage hit.
        owner:addTP(tier(owner:getMainLvl(), 75, 100, 125, 150))
    end)
end

local function attach(master)
    if not isUntamed(master) or not master.addListener then return end
    detach(master)
    master:addListener('WEAPONSKILL_USE', MASTER_WS_LISTENER,
    function(actor, target)
        if not isUntamed(actor) or not isMeleeAxe(actor) or
           not target or not target.isAlive or not target:isAlive() then
            return
        end
        local pet = alivePet(actor)
        if not pet or not pet.addTP then return end
        local targetID = target.getID and target:getID() or nil
        local petTarget = pet.getTarget and pet:getTarget() or nil
        if targetID == nil or not petTarget or not petTarget.getID or
           petTarget:getID() ~= targetID then
            return
        end
        if not ready(actor, PET_TP_MARKER, 8) then return end

        -- Successful master WS timing accelerates the engaged pet's next
        -- real Ready attack. No duplicate hit or artificial pet command.
        pet:addTP(tier(actor:getMainLvl(), 125, 175, 225, 275))
    end)
    local pet = alivePet(master)
    if pet then attachPet(master, pet) end
end

if BST ~= nil then
    -- Do not replace Alpha Warden's registerJob table or pet hooks.
    spec.registerCrystal(BST,
    {
        id = 1,
        key = KEY,
        name = 'Untamed',
        abr = 'UNT',
        role = 'Damage',
        icon = 'untamed',
        reqLevel = 10,
        description = 'A feral melee predator fighting alongside a dangerous pet. Master Axe/Great Axe weaponskills hasten the beast\'s next attack, while pet Ready skills create a reciprocal attack opening for the master.',
        highlights =
        {
            'Feral Synchronization: master WS while both focus one target grants pet TP every 8s; successful pet Ready grants master TP every 8s.',
            'Both master and pet are damage dealers; no tank enmity transfer, damage split, guardian immunity, or artificial extra hit.',
            'Active positioning, shared targeting, and coordinated timing matter. Weakness: loses much of its value when pet is absent or cannot stay engaged.',
            'No dedicated builder/spender resource bar, and no unique custom JA/DAT IDs required.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.AXE,           tier(level, 12, 22, 34, 46) },
                { xi.mod.GREAT_AXE,     tier(level, 10, 18, 28, 38) },
                { xi.mod.ACC,           tier(level, 10, 18, 28, 40) },
                { xi.mod.ATT,           tier(level, 12, 25, 38, 55) },
                { xi.mod.DOUBLE_ATTACK, tier(level, 3, 5, 7, 10) },
                { xi.mod.STORETP,       tier(level, 3, 5, 8, 12) },
            }
        end,
        onApply = attach,
        onRemove = detach,
    })
end

-- Reattach when zoning/relogging and when a different jug pet is spawned.
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if isUntamed(player) then attach(player) end
end)

if xi.pet and xi.pet.spawnPet then
    m:addOverride('xi.pet.spawnPet', function(master, petID, state, target)
        super(master, petID, state, target)
        if isUntamed(master) then
            local pet = alivePet(master)
            if pet then attachPet(master, pet) end
        end
    end)
end

return m
