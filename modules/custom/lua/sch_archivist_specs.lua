-- Archivist (SCH) - record exact enemy actions and file targeted pages.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_sch_archivist')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.SCH] then require('modules/custom/lua/sch_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local ACTIVE, RECORD_CD, FILE_CD = 'OX_ARC_ACTIVE', 'OX_ARC_RECORD_CD', 'OX_ARC_FILE_CD'
local SAMPLE_SEQ, SAMPLE_END = 'OX_ARC_SAMPLE_SEQ', 'OX_ARC_SAMPLE_END'
local SELECTED, RECORD_SEQ = 'OX_ARC_SELECTED', 'OX_ARC_RECORD_SEQ'
local CAST_RECORD, PAGE_TARGET = 'OX_ARC_CAST_RECORD', 'OX_ARC_PAGE_TARGET'
local recordsByOwner, pagesByVictim = {}, {}
local recordHelp = 'Watch one enemy for 12 seconds and record its next completed hostile spell or technique. 6s recast.'
local indexHelp = 'Cycle between your live records to select a different countermeasure. 1s recast.'
local ARCHIVIST_KIT_SPELLS =
{
    [99] =
    {
        script = 'sandstorm', name = 'File Countermeasure', unlockLvl = 10, castMs = 500, recastSec = 15, mpCost = 0,
        description = 'Give one party member a page against your selected recorded action. One exact matching action deals less damage. 15s recast.',
    },
    [159] =
    {
        script = 'stone', name = 'Margin Note', unlockLvl = 10, castMs = 500, recastSec = 6, mpCost = 4,
        description = 'Strike one enemy with earth magic between observations. Costs 4 MP. 6s recast.',
    },
}
xi.soulspire.schArchivistSpecs = { ARCHIVIST_KIT_SPELLS = ARCHIVIST_KIT_SPELLS }

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function isArchivist(player)
    return player and player:isPC() and player:getMainJob() == xi.job.SCH and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.SCH, 'archivist')
end

local function isEnemy(enemy)
    return enemy and enemy:isMob() and enemy:isAlive()
end

local function notify(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function matchingParty(player, target)
    if not target or not target:isPC() or not target:isAlive() or player:getZoneID() ~= target:getZoneID() or
        player:getBattleID() ~= target:getBattleID()
    then
        return false
    end
    if player:getID() == target:getID() then return true end
    for _, member in ipairs(player:getParty()) do
        if member:getID() == target:getID() then return true end
    end
    return false
end

local function liveRecords(player)
    local list = recordsByOwner[player:getID()] or {}
    for index = #list, 1, -1 do
        if list[index].expires <= now() or list[index].zone ~= player:getZoneID() or list[index].battle ~= player:getBattleID() then
            table.remove(list, index)
        end
    end
    local capacity = player:getMainLvl() >= 50 and 2 or 1
    while #list > capacity do table.remove(list, 1) end
    if #list == 0 then recordsByOwner[player:getID()] = nil end
    return list
end

local function findRecord(list, id)
    for index, record in ipairs(list) do
        if record.token == id then return record, index end
    end
    return nil, 0
end

local function selectedRecord(player)
    local list = liveRecords(player)
    return findRecord(list, player:getLocalVar(SELECTED)) or list[#list]
end

local function saveRecord(player, enemy, category, actionId, name)
    local list = liveRecords(player)
    local spawn = enemy:getLocalVar('OX_ARC_SPAWN')
    for index = #list, 1, -1 do
        local record = list[index]
        if record.enemy == enemy:getID() and record.spawn == spawn and record.category == category and record.action == actionId then
            table.remove(list, index)
        end
    end
    local id = player:getLocalVar(RECORD_SEQ) % 4294967295 + 1
    player:setLocalVar(RECORD_SEQ, id)
    local display = string.sub(tostring(name):gsub('_', ' '):gsub('(%a)([%w]*)', function(first, rest) return first:upper() .. rest end), 1, 28)
    list[#list + 1] =
    {
        token = id, enemy = enemy:getID(), spawn = spawn, action = actionId, category = category, name = display,
        zone = player:getZoneID(), battle = player:getBattleID(), expires = now() + 60,
    }
    recordsByOwner[player:getID()] = list
    liveRecords(player)
    player:setLocalVar(SELECTED, id)
    notify(player, 'Recorded ' .. display .. '.')
    player:timer(60000, function(owner) liveRecords(owner) end)
end

m:addOverride('xi.actions.abilities.modus_veritas.onAbilityCheck', function(player, target, ability)
    if not isArchivist(player) then return super(player, target, ability) end
    if not isEnemy(target) or player:checkDistance(target) > 20 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(6)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.modus_veritas.onUseAbility', function(player, target, ability, action)
    if not isArchivist(player) then return super(player, target, ability, action) end
    local ownerId = player:getID()
    local token = player:getLocalVar(SAMPLE_SEQ) % 4294967295 + 1
    local spawn = target:getLocalVar('OX_ARC_SPAWN')
    local listener = ('OX_ARC_SAMPLE_%d_%d'):format(ownerId, token)
    player:setLocalVar(SAMPLE_SEQ, token)
    player:setLocalVar(SAMPLE_END, now() + 12)
    player:setLocalVar(RECORD_CD, now() + 6)
    target:addListener('SOUL_ARCHIVIST_ACTION_COMPLETED', listener, function(enemy, category, actionId, name)
        local owner = GetPlayerByID(ownerId)
        if isArchivist(owner) and owner:getLocalVar(SAMPLE_SEQ) == token and owner:getLocalVar(SAMPLE_END) > now() and
            enemy:getLocalVar('OX_ARC_SPAWN') == spawn and owner:getZoneID() == enemy:getZoneID() and
            owner:getBattleID() == enemy:getBattleID()
        then
            owner:setLocalVar(SAMPLE_END, 0)
            saveRecord(owner, enemy, category, actionId, name)
        end
        enemy:removeListener(listener)
    end)
    target:timer(12000, function(enemy) enemy:removeListener(listener) end)
    if action then action:messageID(target:getID(), xi.msg.basic.NONE) end
    notify(player, 'Watching ' .. target:getName() .. ' for its next hostile action.')
    return 0
end)

local function removeOwnedPage(player)
    local victimId = player:getLocalVar(PAGE_TARGET)
    local pages = pagesByVictim[victimId]
    if pages then
        pages[player:getID()] = nil
        if not next(pages) then pagesByVictim[victimId] = nil end
    end
    player:setLocalVar(PAGE_TARGET, 0)
end

local function validRecipient(player, target)
    return matchingParty(player, target) and
        (target:getID() == player:getID() or player:checkDistance(target) <= (player:getMainLvl() >= 30 and 20 or 15))
end

m:addOverride('xi.actions.spells.white.sandstorm.onMagicCastingCheck', function(player, target, spell)
    if not isArchivist(player) then return super(player, target, spell) end
    local record = selectedRecord(player)
    if not record or not validRecipient(player, target) then return xi.msg.basic.MAGIC_UNABLE_TO_CAST end
    player:setLocalVar(CAST_RECORD, record.token)
    return 0
end)

m:addOverride('xi.actions.spells.white.sandstorm.onSpellCast', function(player, target, spell, action)
    if not isArchivist(player) then return super(player, target, spell, action) end
    local record = findRecord(liveRecords(player), player:getLocalVar(CAST_RECORD))
    if not record or not validRecipient(player, target) then
        spell:setMsg(xi.msg.basic.MAGIC_NO_EFFECT)
        return 0
    end
    removeOwnedPage(player)

    local level = player:getMainLvl()
    local expires = now() + (level >= 70 and 25 or 20)
    local victimId, ownerId = target:getID(), player:getID()
    local entry =
    {
        expires = expires, name = record.name, enemy = record.enemy, spawn = record.spawn,
        action = record.action, category = record.category, pct = scale(level, 20, 25, 25, 30),
    }
    local pages = pagesByVictim[victimId] or {}
    pages[ownerId] = entry
    pagesByVictim[victimId] = pages
    player:setLocalVar(PAGE_TARGET, victimId)
    player:setLocalVar(FILE_CD, now() + 15)
    player:setLocalVar('OX_ARC_FILE_APPLIED', 1)
    target:timer((expires - now()) * 1000, function(victim)
        local current = pagesByVictim[victim:getID()]
        if current and current[ownerId] == entry then
            current[ownerId] = nil
            if not next(current) then pagesByVictim[victim:getID()] = nil end
        end
    end)
    spell:setMsg(xi.msg.basic.NONE)
    notify(player, 'Filed a countermeasure for ' .. record.name .. ' on ' .. target:getName() .. '.')
    return 0
end)

local function directDamage(attackType)
    return attackType == xi.attackType.PHYSICAL or attackType == xi.attackType.RANGED or
        attackType == xi.attackType.MAGICAL or attackType == xi.attackType.BREATH
end

local priorDamage = xi.soulspire.onPreTakeDamage
xi.soulspire.onPreTakeDamage = function(victim, amount, enemy, attackType, damageType)
    if priorDamage then amount = priorDamage(victim, amount, enemy, attackType, damageType) end
    if type(amount) ~= 'number' or amount <= 0 or not victim:isPC() or not isEnemy(enemy) or not directDamage(attackType) then return amount end
    local category, actionId = enemy:getLocalVar('OX_ARC_CATEGORY'), enemy:getLocalVar('OX_ARC_ACTION')
    if category == 0 or actionId == 0 then return amount end
    local sequence, enemyId = enemy:getLocalVar('OX_ARC_SEQUENCE'), enemy:getID()
    if victim:getLocalVar('OX_ARC_APPLIED_SEQ') == sequence and victim:getLocalVar('OX_ARC_APPLIED_ENEMY') == enemyId and
        victim:getLocalVar('OX_ARC_APPLIED_SPAWN') == enemy:getLocalVar('OX_ARC_SPAWN')
    then
        return amount - math.floor(amount * victim:getLocalVar('OX_ARC_APPLIED_PCT') / 100)
    end

    local pages = pagesByVictim[victim:getID()]
    if not pages then return amount end
    local highest, chosenOwner = 0, nil
    for ownerId, page in pairs(pages) do
        local owner = GetPlayerByID(ownerId)
        if page.expires <= now() or not isArchivist(owner) or not matchingParty(owner, victim) then
            pages[ownerId] = nil
        elseif page.enemy == enemyId and page.spawn == enemy:getLocalVar('OX_ARC_SPAWN') and
            page.action == actionId and page.category == category and page.pct > highest
        then
            highest, chosenOwner = page.pct, owner
        end
    end
    if chosenOwner then
        removeOwnedPage(chosenOwner)
        victim:setLocalVar('OX_ARC_APPLIED_SEQ', sequence)
        victim:setLocalVar('OX_ARC_APPLIED_ENEMY', enemyId)
        victim:setLocalVar('OX_ARC_APPLIED_SPAWN', enemy:getLocalVar('OX_ARC_SPAWN'))
        victim:setLocalVar('OX_ARC_APPLIED_PCT', highest)
    elseif not next(pages) then
        pagesByVictim[victim:getID()] = nil
    end
    return amount - math.floor(amount * highest / 100)
end

m:addOverride('xi.actions.abilities.sublimation.onAbilityCheck', function(player, target, ability)
    if not isArchivist(player) then return super(player, target, ability) end
    if player:getMainLvl() < 50 or #liveRecords(player) < 2 then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(1)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.sublimation.onUseAbility', function(player, target, ability, action)
    if not isArchivist(player) then return super(player, target, ability, action) end
    local records = liveRecords(player)
    if #records < 2 then return 0 end
    local _, index = findRecord(records, player:getLocalVar(SELECTED))
    local record = records[(index % #records) + 1]
    player:setLocalVar(SELECTED, record.token)
    if action then action:messageID(player:getID(), xi.msg.basic.NONE) end
    notify(player, 'Selected ' .. record.name .. '.')
    return 0
end)

local function clear(player)
    recordsByOwner[player:getID()] = nil
    player:setLocalVar(SAMPLE_END, 0)
    player:setLocalVar(SELECTED, 0)
    player:setLocalVar(CAST_RECORD, 0)
    removeOwnedPage(player)
end

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    for _, effect in ipairs({ xi.effect.LIGHT_ARTS, xi.effect.DARK_ARTS, xi.effect.ADDENDUM_WHITE, xi.effect.ADDENDUM_BLACK, xi.effect.ACCESSION }) do
        if player:hasStatusEffect(effect) then player:delStatusEffect(effect) end
    end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    clear(player)
    player:sendSoulSpellList()
end

actions.register('archivist',
{
    spell = ARCHIVIST_KIT_SPELLS,
    ability =
    {
        [214] = { name = 'Record', description = recordHelp, recastTime = 6 },
        [233] = { name = 'Index Pages', description = indexHelp, recastTime = 1 },
    },
})

spec.registerCrystal(xi.job.SCH,
{
    id = 3, key = 'archivist', name = 'Archivist', abr = 'ARC', role = 'Support', icon = 'archivist', reqLevel = 10,
    description = 'Observe one enemy, record an exact hostile action, and prepare a specific countermeasure for an ally.',
    highlights =
    {
        'Record watches for 12 seconds and stores exact enemy actions for 60 seconds. One slot at Lv.10 and two from Lv.50.',
        'File Countermeasure protects one target against the exact recorded action for 20 seconds (25 at Lv.70+).',
        'Protection scales to 20/25/25/30%. When multiple pages match, only the strongest applies.',
        'Index Pages unlocks at Lv.50 to choose between two live records. Margin Note provides single-target earth damage.',
    },
    extraAbilities = function(_, level)
        if level >= 50 then return { 214, 233 } end
        return level >= 10 and { 214 } or {}
    end,
    mods = function(_, level)
        return
        {
            { xi.mod.MPP, scale(level, 6, 10, 14, 18) },
            { xi.mod.MACC, scale(level, 8, 14, 22, 30) },
            { xi.mod.HPP, scale(level, 4, 6, 8, 10) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isArchivist(player) then
            if event == 'onGameIn' then clear(player) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('archivist', function(player)
        local record = selectedRecord(player)
        local pages = pagesByVictim[player:getLocalVar(PAGE_TARGET)] or {}
        local page = pages[player:getID()]
        return
        {
            entries = #liveRecords(player), slots = player:getMainLvl() >= 50 and 2 or 1,
            record = record and record.name or '', record_rem = record and math.max(0, record.expires - now()) or 0,
            recording = math.max(0, player:getLocalVar(SAMPLE_END) - now()),
            page_rem = page and math.max(0, page.expires - now()) or 0,
            record_cd = math.max(0, player:getLocalVar(RECORD_CD) - now()),
            file_cd = math.max(0, player:getLocalVar(FILE_CD) - now()),
        }
    end)
end

return m
