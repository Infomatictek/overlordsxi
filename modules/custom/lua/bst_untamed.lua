-----------------------------------
-- OverlordsXI Untamed (BST 1) — Feral Synchronization (Sequence B)
-- Pure DPS: master and jug beast trade offensive openings on the same living target.
-- No resource meter, no pet threat transfer, no defensive guardians.
-- Additive to existing Alpha Warden BST implementation (must load after bst_specs.lua).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local soulActions = nil
do
    local ok, mod = pcall(require, 'modules/custom/lua/overlords_soul_actions')
    if ok and type(mod) == 'table' then
        soulActions = mod
    end
end

local m = Module:new('overlords_bst_untamed')
local spec = xi.overlords.spec
local BST = xi.job.BST
local KEY = 'untamed'

local ABIL_FIGHT           = (xi.jobAbility and xi.jobAbility.FIGHT) or 69
local ABIL_REWARD          = (xi.jobAbility and xi.jobAbility.REWARD) or 78
local ABIL_CALL_BEAST      = (xi.jobAbility and xi.jobAbility.CALL_BEAST) or 85
local ABIL_READY           = (xi.jobAbility and xi.jobAbility.READY) or 251
local ABIL_BESTIAL_LOYALTY = (xi.jobAbility and xi.jobAbility.BESTIAL_LOYALTY) or 387

local MASTER_WS_LISTENER = 'OX_UNTAMED_MASTER_WS'
local PET_HIT_LISTENER   = 'OX_UNTAMED_PET_HIT'
local PET_WS_LISTENER    = 'OX_UNTAMED_PET_WS'
local PET_TP_MARKER      = 'OX_UNTAMED_PET_REACTION'
local MASTER_TP_MARKER   = 'OX_UNTAMED_MASTER_REACTION'
local petModsByID        = {}
local petLastHitByEntity = setmetatable({}, { __mode = 'k' })

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

local function sameZone(a, b)
    if not a or not b then return false end
    if not a.getZoneID or not b.getZoneID then return true end
    return a:getZoneID() == b:getZoneID()
end

local function didActionLand(target, action, damage)
    if type(damage) == 'number' then
        return damage > 0
    end
    if action and action.getMsg and target and target.getID then
        local msg = action:getMsg(target:getID())
        local skillMiss = xi.msg and xi.msg.basic and xi.msg.basic.SKILL_MISS or 188
        local hitMiss = xi.msg and xi.msg.basic and xi.msg.basic.HIT_MISS or 15
        if msg == skillMiss or msg == hitMiss or msg == 0 then
            return false
        end
        return true
    end
    return false
end

local function cooldownRemaining(entity, marker, cooldown)
    if not entity or not entity.getLocalVar then return 0 end
    local now = xi.overlords.nowSec()
    local previous = entity:getLocalVar(marker) or 0
    if previous == 0 or previous > now then return 0 end
    local rem = cooldown - (now - previous)
    return rem > 0 and rem or 0
end

local function isReady(entity, marker, cooldown)
    if not entity or not entity.getLocalVar then return false end
    local now = xi.overlords.nowSec()
    local previous = entity:getLocalVar(marker) or 0
    if previous > now then previous = 0 end
    return previous == 0 or (now - previous) >= cooldown
end

local function stampCooldown(entity, marker)
    if entity and entity.setLocalVar then
        entity:setLocalVar(marker, xi.overlords.nowSec())
    end
end

local function clearPetMods(pet)
    if not pet or not pet.getID then return end
    local id = pet:getID()
    local prev = petModsByID[id]
    if prev and prev.entity == pet and pet.delMod then
        for _, bonus in ipairs(prev.bonuses) do
            pet:delMod(bonus[1], bonus[2])
        end
    end
    petModsByID[id] = nil
    petLastHitByEntity[pet] = nil
end

local function syncPetMods(master, pet)
    if not pet or not pet.getID or not pet.addMod then return end
    if not isUntamed(master) then clearPetMods(pet); return end

    -- Offensive pet identity only; never grant guardian immunity, HP, damage-split, or extra enmity.
    local level = master:getMainLvl()
    local desired =
    {
        { xi.mod.ACC,           tier(level, 10, 18, 28, 40) },
        { xi.mod.ATT,           tier(level, 15, 28, 42, 60) },
        { xi.mod.DOUBLE_ATTACK, tier(level, 3, 5, 7, 10) },
    }
    local id = pet:getID()
    local prev = petModsByID[id]
    local changed = prev == nil or prev.entity ~= pet or #prev.bonuses ~= #desired
    if not changed then
        for index, bonus in ipairs(desired) do
            if prev.bonuses[index][1] ~= bonus[1] or prev.bonuses[index][2] ~= bonus[2] then
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
    petModsByID[id] = { entity = pet, bonuses = desired }
end

local function detach(master)
    if not master then return end
    if master.removeListener then master:removeListener(MASTER_WS_LISTENER) end
    local pet = master.getPet and master:getPet() or nil
    if pet and pet.removeListener then
        pet:removeListener(PET_HIT_LISTENER)
        pet:removeListener(PET_WS_LISTENER)
    end
    if pet then clearPetMods(pet) end
end

local function attachPet(master, pet)
    if not isUntamed(master) or not pet or not pet.addListener then return end
    if pet.removeListener then
        pet:removeListener(PET_HIT_LISTENER)
        pet:removeListener(PET_WS_LISTENER)
    end
    petLastHitByEntity[pet] = nil
    syncPetMods(master, pet)

    -- Record actual landed offensive Ready hit (positive damage on a living enemy).
    pet:addListener('WEAPONSKILL_USE', PET_HIT_LISTENER,
    function(actor, target, _skill, _tp, action, damage)
        if not actor or not target or not target.isMob or not target:isMob() or
           not target.getID then
            return
        end
        if didActionLand(target, action, damage) then
            petLastHitByEntity[actor] =
            {
                targetId = target:getID(),
                target   = target,
                damage   = damage or 1,
                time     = xi.overlords.nowSec(),
            }
        else
            petLastHitByEntity[actor] = nil
        end
    end)

    -- On completed Ready, verify bilateral target equality + positive delivered damage before spending ICD.
    pet:addListener('WEAPONSKILL_STATE_EXIT', PET_WS_LISTENER,
    function(actor, _skill, completed)
        local lastHit = petLastHitByEntity[actor]
        petLastHitByEntity[actor] = nil

        if not completed or not actor or not actor.getMaster then return end
        local owner = actor:getMaster()
        if not isUntamed(owner) or alivePet(owner) ~= actor or
           not isMeleeAxe(owner) or not owner.addTP then
            return
        end
        if not lastHit or lastHit.damage <= 0 then
            return
        end
        if (xi.overlords.nowSec() - lastHit.time) > 5 then
            return
        end

        local masterTarget = owner.getTarget and owner:getTarget() or nil
        if not masterTarget or not masterTarget.getID or
           not masterTarget.isAlive or not masterTarget:isAlive() or
           masterTarget:getID() ~= lastHit.targetId or
           not sameZone(owner, masterTarget) or not sameZone(actor, masterTarget) then
            return
        end

        if not isReady(owner, MASTER_TP_MARKER, 8) then
            return
        end
        stampCooldown(owner, MASTER_TP_MARKER)
        owner:addTP(tier(owner:getMainLvl(), 75, 100, 125, 150))
    end)
end

local function attach(master)
    if not isUntamed(master) or not master.addListener then return end
    detach(master)
    master:addListener('WEAPONSKILL_USE', MASTER_WS_LISTENER,
    function(actor, target, _wsId, _tp, action, damage)
        if not isUntamed(actor) or not isMeleeAxe(actor) or
           not target or not target.isMob or not target:isMob() or
           not target.isAlive or not target:isAlive() then
            return
        end
        if not didActionLand(target, action, damage) then
            return
        end
        local pet = alivePet(actor)
        if not pet or not pet.addTP then return end
        local targetID = target.getID and target:getID() or nil
        local petTarget = pet.getTarget and pet:getTarget() or nil
        if targetID == nil or not petTarget or not petTarget.getID or
           petTarget:getID() ~= targetID or
           not sameZone(actor, target) or not sameZone(pet, target) then
            return
        end
        if not isReady(actor, PET_TP_MARKER, 8) then return end
        stampCooldown(actor, PET_TP_MARKER)

        pet:addTP(tier(actor:getMainLvl(), 125, 175, 225, 275))
    end)
    local pet = alivePet(master)
    if pet then attachPet(master, pet) end
end

-- Expose helpers for unit/regression tests.
xi.overlords.bstUntamed =
{
    attach       = attach,
    attachPet    = attachPet,
    detach       = detach,
    syncPetMods  = syncPetMods,
    clearPetMods = clearPetMods,
}

-- Register reviewed action manifest entries in opt-in Soul action registry.
if soulActions and soulActions.register and soulActions.definitions and not soulActions.definitions[KEY] then
    soulActions.register(KEY, {
        spell = {},
        ability = {
            [ABIL_FIGHT] = { name = 'Fight', description = 'Order active jug beast to engage target.', recastTime = 10 },
            [ABIL_REWARD] = { name = 'Reward', description = 'Restore pet HP using pet food; loaned from Lv10.', recastTime = 90 },
            [ABIL_CALL_BEAST] = { name = 'Call Beast', description = 'Summon jug beast from ammo slot; loaned from Lv10.', recastTime = 300 },
            [ABIL_READY] = { name = 'Ready', description = 'Command jug beast offensive Ready skill; loaned from Lv10.', recastTime = 10 },
            [ABIL_BESTIAL_LOYALTY] = { name = 'Bestial Loyalty', description = 'Summon jug beast without consuming jug; loaned from Lv10.', recastTime = 1200 },
        },
        weaponskill = {},
    })
end

if BST ~= nil then
    -- Additive registration: never replace Alpha Warden's registerJob table or pet hooks.
    spec.registerCrystal(xi.job.BST,
    {
        id = 1,
        key = KEY,
        name = 'Untamed',
        abr = 'UNT',
        role = 'Damage',
        icon = 'untamed',
        reqLevel = 10,
        description = 'A feral melee predator fighting alongside an offensive jug beast. Landed Master Axe/Great Axe weaponskills hasten the beast\'s next attack, while landed offensive pet Ready skills return TP to the master.',
        highlights =
        {
            'Lv10 starter loan for Call Beast, Bestial Loyalty, Fight, Reward, and Ready.',
            'Feral Synchronization: landed master WS on shared living target grants +125/175/225/275 pet TP (8s ICD); landed offensive Ready grants +75/100/125/150 master TP (8s ICD).',
            'Both master and pet are damage dealers; no tank enmity transfer, damage split, guardian immunity, or synthetic extra hit.',
        },
        extraAbilities = { ABIL_FIGHT, ABIL_REWARD, ABIL_CALL_BEAST, ABIL_READY, ABIL_BESTIAL_LOYALTY },
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
        onApply  = attach,
        onRemove = detach,
    })
end

-- Reattach when zoning/relogging and when a different jug pet is spawned.
if xi.player and xi.player.onGameIn then
    m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
        super(player, firstLogin, zoning)
        if isUntamed(player) then attach(player) end
    end)
end

if xi.pet and xi.pet.spawnPet then
    m:addOverride('xi.pet.spawnPet', function(master, petID, state, target)
        super(master, petID, state, target)
        if isUntamed(master) then
            local pet = alivePet(master)
            if pet then attachPet(master, pet) end
        end
    end)
end

if xi.overlords.hud and xi.overlords.hud.registerProvider then
    xi.overlords.hud.registerProvider(KEY, function(player)
        local pet = alivePet(player)
        local masterTgt = player.getTarget and player:getTarget() or nil
        local petTgt = pet and pet.getTarget and pet:getTarget() or nil
        local sameTgt = (masterTgt and petTgt and masterTgt.getID and petTgt.getID and masterTgt:getID() == petTgt:getID()) and 1 or 0
        return {
            pet_tp_cd    = math.ceil(cooldownRemaining(player, PET_TP_MARKER, 8)),
            master_tp_cd = math.ceil(cooldownRemaining(player, MASTER_TP_MARKER, 8)),
            same_target  = sameTgt,
        }
    end)
end

return m
