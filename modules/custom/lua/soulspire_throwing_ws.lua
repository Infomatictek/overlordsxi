-----------------------------------
-- SoulspireXI Custom Throwing Weaponskills (#241-#252)
-- Registers xi.actions.weaponskills.<key>.onUseWeaponSkill for
-- Dancer Bladewheel chakram weaponskills. Wrapped by soulspire_ws_overrides.
-----------------------------------
require('scripts/globals/weaponskills')
-----------------------------------
xi = xi or {}
xi.actions = xi.actions or {}
xi.actions.weaponskills = xi.actions.weaponskills or {}

local function addFinishingMoves(player, amount)
    if player == nil or not player:isPC() or amount <= 0 then
        return
    end
    local maxMoves = 5
    local current = 0
    local effect = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    if effect ~= nil then
        current = effect:getPower()
        effect:setPower(math.min(maxMoves, current + amount))
    else
        player:addStatusEffect(xi.effect.FINISHING_MOVE_1, { power = math.min(maxMoves, amount), duration = 7200, origin = player })
    end
end

local function consumeAllFinishingMoves(player)
    if player == nil or not player:isPC() then
        return 0
    end
    local effect = player:getStatusEffect(xi.effect.FINISHING_MOVE_1)
    if effect == nil then
        return 0
    end
    local power = effect:getPower() or 0
    player:delStatusEffect(xi.effect.FINISHING_MOVE_1)
    return power
end

-- Ensure Throwing weaponskills (Chakrams in SLOT_RANGED with empty SLOT_AMMO)
-- execute all multi-hits and bonusHits instead of stopping at 1 hit from ammoCount = 0.
if xi.weaponskills ~= nil and xi.weaponskills.calculateRawWSDmg ~= nil then
    xi.weaponskills._origCalculateRawWSDmg = xi.weaponskills._origCalculateRawWSDmg or xi.weaponskills.calculateRawWSDmg
    xi.weaponskills.calculateRawWSDmg = function(attacker, target, wsID, tp, action, wsParams, calcParams)
        local restoreRangedSlot = false
        if
            calcParams ~= nil and
            calcParams.attackInfo ~= nil and
            calcParams.attackInfo.slot == xi.slot.RANGED and
            (calcParams.skillType == xi.skill.THROWING or (wsID ~= nil and wsID >= 241 and wsID <= 252)) and
            attacker ~= nil and
            attacker:isPC() and
            attacker:getEquippedItem(xi.slot.AMMO) == nil
        then
            calcParams.attackInfo.slot = xi.slot.AMMO
            restoreRangedSlot = true
        end

        local res = xi.weaponskills._origCalculateRawWSDmg(attacker, target, wsID, tp, action, wsParams, calcParams)
        if restoreRangedSlot and res ~= nil and res.attackInfo ~= nil then
            res.attackInfo.slot = xi.slot.RANGED
        end
        return res
    end
end

local function registerRangedWs(key, paramsBuilder, afterHitFn)
    xi.actions.weaponskills[key] = xi.actions.weaponskills[key] or {}
    xi.actions.weaponskills[key].onUseWeaponSkill = function(player, target, wsID, tp, primary, action, taChar)
        local params = paramsBuilder(player, target, wsID, tp)
        local damage, criticalHit, tpHits, extraHits = xi.weaponskills.doRangedWeaponskill(player, target, wsID, params, tp, action, primary)
        if afterHitFn ~= nil and damage > 0 then
            afterHitFn(player, target, wsID, tp, damage, criticalHit, tpHits, extraHits)
        end
        return tpHits, extraHits, criticalHit, damage
    end
end

local function registerMagicWs(key, paramsBuilder, afterHitFn)
    xi.actions.weaponskills[key] = xi.actions.weaponskills[key] or {}
    xi.actions.weaponskills[key].onUseWeaponSkill = function(player, target, wsID, tp, primary, action, taChar)
        local params = paramsBuilder(player, target, wsID, tp)
        local damage, criticalHit, tpHits, extraHits = xi.weaponskills.doMagicWeaponskill(player, target, wsID, params, tp, action, primary)
        if afterHitFn ~= nil and damage > 0 then
            afterHitFn(player, target, wsID, tp, damage, criticalHit, tpHits, extraHits)
        end
        return tpHits, extraHits, criticalHit, damage
    end
end

-- #241 Pirouette Toss
registerRangedWs('pirouette_toss', function()
    return {
        numHits = 1,
        ftpMod  = { 1.00, 1.50, 2.00 },
        dex_wsc = 0.4,
        agi_wsc = 0.2,
    }
end, function(player, _target, _wsID, tp)
    addFinishingMoves(player, tp >= 3000 and 2 or 1)
end)

-- #242 Whirling Waltz (Light Magic + Party Heal)
registerMagicWs('whirling_waltz', function()
    return {
        ftpMod  = { 1.25, 2.00, 2.75 },
        chr_wsc = 0.5,
        dex_wsc = 0.2,
        ele     = xi.element.LIGHT,
        skill   = xi.skill.THROWING,
        includemab = true,
    }
end, function(player, _target, _wsID, tp, damage)
    local ratio = (tp >= 3000 and 0.30) or (tp >= 2000 and 0.20) or 0.10
    local heal = math.max(1, math.floor(damage * ratio))
    local party = (player.getPartyWithTrusts and player:getPartyWithTrusts())
        or (player.getParty and player:getParty())
        or { player }
    local seen = {}
    local function healEntity(entity)
        if
            entity ~= nil and
            entity.getID and
            not seen[entity:getID()] and
            entity:isAlive() and
            (entity:getID() == player:getID() or player:checkDistance(entity) <= 10)
        then
            seen[entity:getID()] = true
            local actual = entity:addHP(heal)
            if
                (actual > 0 or entity:getID() ~= player:getID()) and
                player.messagePublic and
                xi.msg and
                xi.msg.basic and
                xi.msg.basic.RECOVERS_HP
            then
                player:messagePublic(xi.msg.basic.RECOVERS_HP, entity, 0, actual)
            end
        end
    end
    for _, member in ipairs(party) do
        healEntity(member)
        if member ~= nil and member.hasPet and member:hasPet() then
            healEntity(member:getPet())
        end
    end
    healEntity(player)
    if player.hasPet and player:hasPet() then
        healEntity(player:getPet())
    end
end)

-- #243 Ricochet Tango
registerRangedWs('ricochet_tango', function()
    return {
        numHits = 3,
        ftpMod  = { 1.00, 1.00, 1.00 },
        dex_wsc = 0.5,
    }
end)

-- #244 Crimson Samba (Dark Magic + HP Drain)
registerMagicWs('crimson_samba', function()
    return {
        ftpMod  = { 1.50, 2.25, 3.00 },
        chr_wsc = 0.4,
        int_wsc = 0.2,
        ele     = xi.element.DARK,
        skill   = xi.skill.THROWING,
        includemab = true,
    }
end, function(player, target, _wsID, tp, damage)
    if target:isUndead() then
        return
    end
    local ratio = (tp >= 3000 and 0.45) or (tp >= 2000 and 0.30) or 0.15
    local actual = player:addHP(math.max(1, math.floor(damage * ratio)))
    if actual > 0 and player.messagePublic and xi.msg and xi.msg.basic and xi.msg.basic.RECOVERS_HP then
        player:messagePublic(xi.msg.basic.RECOVERS_HP, player, 0, actual)
    end
end)

-- #245 Stutter Disc
registerRangedWs('stutter_disc', function()
    return {
        numHits = 1,
        ftpMod  = { 1.25, 1.25, 1.25 },
        agi_wsc = 0.4,
        chr_wsc = 0.2,
    }
end, function(player, target)
    target:addStatusEffect(xi.effect.MAGIC_EVASION_DOWN, { power = 15, duration = 60, origin = player })
end)

-- #246 Feathered Ring
registerRangedWs('feathered_ring', function()
    return {
        numHits    = 1,
        ftpMod     = { 1.75, 1.75, 1.75 },
        dex_wsc    = 0.6,
        critVaries = { 0.15, 0.25, 0.35 },
    }
end, function(player, target)
    target:addStatusEffect(xi.effect.BEWILDERED_DAZE_1, { power = 1, duration = 60, origin = player })
end)

-- #247 Bolero Cyclone (Wind AoE Magic + Evasion Down)
registerMagicWs('bolero_cyclone', function()
    return {
        ftpMod  = { 1.50, 2.50, 3.25 },
        chr_wsc = 0.4,
        agi_wsc = 0.3,
        ele     = xi.element.WIND,
        skill   = xi.skill.THROWING,
        includemab = true,
    }
end, function(player, target)
    target:addStatusEffect(xi.effect.EVASION_DOWN, { power = 20, duration = 60, origin = player })
end)

-- #248 Flamenco Finale (Consumes Finishing Moves for +fTP)
registerRangedWs('flamenco_finale', function(player)
    local fm = consumeAllFinishingMoves(player)
    local bonus = fm * 0.40
    return {
        numHits = 1,
        ftpMod  = { 2.50 + bonus, 3.30 + bonus, 4.10 + bonus },
        dex_wsc = 0.4,
        chr_wsc = 0.4,
    }
end)

-- #249 Tarantella Storm
registerRangedWs('tarantella_storm', function()
    return {
        numHits    = 5,
        ftpMod     = { 1.00, 1.00, 1.00 },
        dex_wsc    = 0.5,
        critVaries = { 0.10, 0.20, 0.35 },
    }
end, function(player, _target, _wsID, _tp, _dmg, criticalHit)
    if criticalHit then
        player:addStatusEffect(xi.effect.HASTE_SAMBA, { power = 1, duration = 30, origin = player })
    end
end)

-- #250 Grand Jete
registerRangedWs('grand_jete', function()
    return {
        numHits = 1,
        ftpMod  = { 3.50, 6.00, 8.50 },
        dex_wsc = 0.6,
        agi_wsc = 0.2,
    }
end, function(player, target)
    target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = 20, duration = 60, origin = player })
end)

-- #251 Aurora Fandango
registerRangedWs('aurora_fandango', function()
    return {
        numHits = 4,
        ftpMod  = { 2.75, 2.75, 2.75 },
        dex_wsc = 0.4,
        chr_wsc = 0.4,
    }
end, function(player, target)
    target:addStatusEffect(xi.effect.EVASION_DOWN, { power = 10, duration = 60, origin = player })
    player:addStatusEffect(xi.effect.HASTE_SAMBA, { power = 1, duration = 60, origin = player })
end)

-- #252 Terpsichore's Halo
registerMagicWs('terpsichores_halo', function()
    return {
        ftpMod  = { 3.00, 4.50, 6.00 },
        chr_wsc = 0.6,
        dex_wsc = 0.3,
        ele     = xi.element.LIGHT,
        skill   = xi.skill.THROWING,
        includemab = true,
    }
end, function(player, _target, _wsID, tp)
    local dur = (tp >= 3000 and 180) or (tp >= 2000 and 120) or 60
    player:setLocalVar('OX_CHAKRAM_AM', os.time() + dur)
    player:addStatusEffect(xi.effect.AFTERMATH_LV1, { power = 1, duration = dur, origin = player })
end)
