require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_geo_terramancer')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.GEO] then require('modules/custom/lua/geo_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')

local ACTIVE, APPLIED, COOLDOWN, SCALAR = 'OX_TRM_ACTIVE', 'OX_TRM_APPLIED', 'OX_TRM_COOLDOWN', 'OX_TRM_SCALAR'
local CANCEL = 345
local DEATH = 'OX_TRM_CLEAR_FAULT'
local slots = {}

local function now()
    return xi.soulspire.nowSec()
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function active(player)
    return player and player:isPC() and player:isAlive() and player:getMainJob() == xi.job.GEO and
        player:getMainLvl() >= 10 and player:getLocalVar(ACTIVE) == 1 and spec.is(player, xi.job.GEO, 'terramancer')
end

local function eligible(player, enemy)
    return enemy and enemy:isMob() and enemy:isAlive() and not enemy:getMaster() and player:getZoneID() == enemy:getZoneID() and
        player:getBattleID() == enemy:getBattleID() and player:hasClaim(enemy)
end

local function mpCost(player, deep)
    return math.max(1, math.ceil(player:getMaxMP() * (deep and 12 or 7) / 100))
end

local function canPlace(player, enemy, deep)
    return active(player) and (not deep or player:getMainLvl() >= 30) and not slots[player:getID()] and
        player:getLocalVar(COOLDOWN) <= now() and player:getMP() >= mpCost(player, deep) and
        eligible(player, enemy) and player:checkDistance(enemy) <= 18
end

local function inFault(enemy, fault)
    local pos = enemy:getPos()
    local dx, dz = pos.x - fault.x, pos.z - fault.z
    return dx * dx + dz * dz <= 9 and math.abs(pos.y - fault.y) <= 3
end

local function erupt(id, quarry, fault)
    if slots[id] ~= fault then return end
    slots[id] = nil
    local player = GetPlayerByID(id)
    if not active(player) or (fault.deep and player:getMainLvl() < 30) or
        not eligible(player, quarry) or quarry:getID() ~= fault.target or quarry:getLocalVar('OX_ARC_SPAWN') ~= fault.spawn then
        return
    end
    if inFault(quarry, fault) then
        player:resolveTerramancerFault(quarry, fault.deep)
    else
        player:printToPlayer('The fault collapses after the quarry leaves the mark.', xi.msg.channel.SYSTEM_3)
    end
end

local function place(player, quarry, deep)
    local id, pos = player:getID(), quarry:getPos()
    local fuse = deep and 4 or 2
    local fault =
    {
        deep = deep, x = pos.x, y = pos.y, z = pos.z, target = quarry:getID(), spawn = quarry:getLocalVar('OX_ARC_SPAWN'),
        expires = now() + fuse,
    }
    player:delMP(mpCost(player, deep))
    player:setLocalVar(APPLIED, 1)
    player:setLocalVar(COOLDOWN, now() + 8)
    slots[id] = fault
    quarry:timer(fuse * 1000, function(bound)
        erupt(id, bound, fault)
    end)
    player:timer((fuse + 1) * 1000, function()
        if slots[id] == fault then slots[id] = nil end
    end)
end

for _, fault in ipairs({ { 'stone_ii', false }, { 'stone_iii', true } }) do
    local root = 'xi.actions.spells.black.' .. fault[1]
    local deep = fault[2]
    m:addOverride(root .. '.onMagicCastingCheck', function(player, target, spell)
        if not active(player) then return super(player, target, spell) end
        if not canPlace(player, target, deep) then return xi.msg.basic.MAGIC_UNABLE_TO_CAST end
        return 0
    end)
    m:addOverride(root .. '.onSpellCast', function(player, target, spell)
        if not active(player) then return super(player, target, spell) end
        if not canPlace(player, target, deep) then
            spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
            return 0
        end
        place(player, target, deep)
        spell:setMsg(xi.msg.basic.NONE)
        return 0
    end)
end

m:addOverride('xi.spells.damage.calculateBaseDamage', function(caster, target, id, group, skill, stat)
    local base = super(caster, target, id, group, skill, stat)
    if id == 159 and active(caster) then
        local multiplier = caster:getLocalVar(SCALAR)
        if multiplier > 0 then return math.floor(base * multiplier / 100) end
    end
    return base
end)

m:addOverride('xi.actions.abilities.full_circle.onAbilityCheck', function(player, target, ability)
    if not active(player) then return super(player, target, ability) end
    if not slots[player:getID()] then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setMsg(xi.msg.basic.NONE)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.full_circle.onUseAbility', function(player, target, ability, action)
    if not active(player) then return super(player, target, ability, action) end
    slots[player:getID()] = nil
    return 0
end)

local spellKit =
{
    [159] = { script = 'stone', name = 'Stone Chip', description = 'Strike one enemy with earth magic and establish your claim.', unlockLvl = 10, castMs = 500, recastSec = 4, mpCost = 3 },
    [160] = { script = 'stone_ii', name = 'Shallow Fault', description = 'Mark your claimed enemy’s position. Erupt after two seconds if it remains within the mark. Costs 7% max MP.', unlockLvl = 10, castMs = 750, recastSec = 8 },
    [161] = { script = 'stone_iii', name = 'Deep Fault', description = 'Mark a claimed enemy for a stronger eruption after four seconds. Costs 12% max MP.', unlockLvl = 30, castMs = 750, recastSec = 8 },
}
xi.soulspire.geoTerramancerSpecs = { TERRAMANCER_KIT_SPELLS = spellKit }
actions.register('terramancer',
{
    spell = spellKit,
    ability = { [CANCEL] = { name = 'Cancel Fault', description = 'Collapse your pending fault without a refund.', recastTime = 10 } },
})

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    player:removeListener(DEATH)
    player:addListener('DEATH', DEATH, function(owner) slots[owner:getID()] = nil end)
    player:sendSoulSpellList()
end

local function remove(player)
    slots[player:getID()] = nil
    player:removeListener(DEATH)
    player:setLocalVar(ACTIVE, 0)
    player:setLocalVar(APPLIED, 0)
    player:sendSoulSpellList()
end

spec.registerCrystal(xi.job.GEO,
{
    id = 3, key = 'terramancer', name = 'Terramancer', abr = 'TRM', role = 'Damage', icon = 'terramancer', reqLevel = 10,
    description = 'Predict a claimed quarry’s position and erupt a single-target fault beneath it.',
    highlights =
    {
        'Lv.10: Stone Chip establishes claim. Shallow Fault erupts after two seconds. Lv.30: Deep Fault erupts after four.',
        'The fault hits only the original claimed enemy and spawn if it stays within three horizontal and three vertical yalms.',
        'Both faults share an eight-second recast. Invalid placement costs nothing. A successfully armed fault spends its cost even if the quarry moves.',
    },
    extraAbilities = function(_, level) return level >= 10 and { CANCEL } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.INT, scale(level, 8, 15, 22, 30) },
            { xi.mod.MATT, scale(level, 10, 18, 28, 38) },
            { xi.mod.MACC, scale(level, 8, 15, 24, 34) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if player:getMainJob() ~= xi.job.GEO or not spec.is(player, xi.job.GEO, 'terramancer') then return end
        if event == 'onGameIn' then slots[player:getID()] = nil end
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
    xi.soulspire.hud.registerProvider('terramancer', function(player)
        local fault = slots[player:getID()]
        local target = fault and GetMobByID(fault.target)
        local valid = target and eligible(player, target) and target:getLocalVar('OX_ARC_SPAWN') == fault.spawn
        return
        {
            fuse = fault and math.max(0, fault.expires - now()) or 0,
            kind = fault and (fault.deep and 'Deep Fault' or 'Shallow Fault') or '',
            quarry = valid and target:getName() or '',
            inside = valid and inFault(target, fault) and 1 or 0,
            cooldown = math.max(0, player:getLocalVar(COOLDOWN) - now()),
        }
    end)
end

return m
