-----------------------------------
-- func: gear
-- desc: Grants and equips level-appropriate 16-slot testing gear tailored to
--       the player's main job, active OverlordsXI crystal spec, role, and weapon.
-----------------------------------
require('modules/custom/lua/overlords_job_specs')
package.loaded['modules/custom/lua/overlords_gear_resolver'] = nil
package.loaded['modules/custom/lua/overlords_test_gear'] = nil
require('modules/custom/lua/overlords_test_gear')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'sss',
}

local testGear = xi.overlords.testGear
local spec     = xi.overlords.spec

local SLOT_LABELS =
{
    [0]  = 'Main',
    [1]  = 'Sub',
    [2]  = 'Ranged',
    [3]  = 'Ammo',
    [4]  = 'Head',
    [5]  = 'Body',
    [6]  = 'Hands',
    [7]  = 'Legs',
    [8]  = 'Feet',
    [9]  = 'Neck',
    [10] = 'Waist',
    [11] = 'Ear1',
    [12] = 'Ear2',
    [13] = 'Ring1',
    [14] = 'Ring2',
    [15] = 'Back',
}

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function delaySendMenu(player, menuBuilder)
    player:timer(50, function(playerArg)
        if playerArg ~= nil then
            playerArg:customMenu(menuBuilder())
        end
    end)
end

local function printUsage(player)
    tell(player, 'Usage: !gear | !gear best | !gear tp | !gear ws | !gear menu | !gear <level> [weapon]')
    tell(player, '       !gear role <tp|ws|tank|ranged|caster> | !gear level <1-75> | !gear info | !gear bag')
    tell(player, 'Weapons: h2h, dagger, sword, gs, axe, gaxe, scythe, polearm, katana, gk, club, staff, bow, crossbow, gun, throwing, chakram')
end

local function summarizeWeapons(loadout)
    local slots = loadout.slots or {}
    local parts = {}
    if slots[0] ~= nil then
        table.insert(parts, string.format('%s (Lv.%d)', slots[0].name, slots[0].lvl))
    end
    if slots[1] ~= nil then
        table.insert(parts, string.format('%s (Lv.%d)', slots[1].name, slots[1].lvl))
    end
    if slots[2] ~= nil then
        table.insert(parts, string.format('%s (Lv.%d)', slots[2].name, slots[2].lvl))
    elseif slots[3] ~= nil then
        table.insert(parts, string.format('%s (Lv.%d)', slots[3].name, slots[3].lvl))
    end
    if #parts == 0 then
        return 'Unarmed'
    end
    return table.concat(parts, ' / ')
end

local function printLoadoutDetails(player, loadout)
    if loadout == nil then
        return
    end
    tell(player, string.format('=== Lv.%d %s Loadout ===', loadout.level, loadout.profile.label))
    for slotId = 0, 15 do
        local label = SLOT_LABELS[slotId] or tostring(slotId)
        local item = loadout.slots[slotId]
        if item ~= nil then
            local qtyStr = (item.qty and item.qty > 1) and string.format(' x%d', item.qty) or ''
            tell(player, string.format('  %-6s: %s%s [Lv.%d, #%d]', label, item.name, qtyStr, item.lvl, item.id))
        end
    end
end

local function executeEquip(player, opts)
    opts = opts or {}
    -- Only '!gear level' changes player level; ordinary gear requests do not.
    local loadout, err = testGear.equipLoadout(player, opts)
    if loadout == nil then
        tell(player, err or 'Unable to equip test gear loadout.')
        return nil
    end

    if loadout.equippedCount == 0 then
        tell(player, string.format('No equippable items found for %s at Lv.%d.', loadout.profile.label, loadout.level))
        return loadout
    end

    tell(player, string.format(
        'Equipped Lv.%d %s: %s (%d slots equipped, %d added).',
        loadout.level,
        loadout.profile.label,
        summarizeWeapons(loadout),
        loadout.equippedCount or 0,
        loadout.addedCount or 0
    ))
    return loadout
end

-----------------------------------
-- Interactive customMenu UI (!gear menu)
-----------------------------------
local openRootMenu
local openWeaponMenu
local openRoleMenu
local openLevelMenu

local function getAvailableWeaponKeys(player)
    local lvl = player:getMainLvl()
    local profile = testGear.getDefaultProfile(player, player:getMainJob(), lvl)
    local available = {}
    for _, wKey in ipairs(testGear.WEAPON_ORDER) do
        local info = testGear.WEAPON_INFO[wKey]
        if info ~= nil and testGear.isWeaponAllowedForJob(player, wKey) then
            if wKey == 'bow' or wKey == 'crossbow' or wKey == 'gun' or wKey == 'throwing' then
                local item = testGear.pickFromPool(player, testGear.RANGED[wKey], lvl)
                if item ~= nil then
                    table.insert(available, { key = wKey, label = info.label, item = item })
                end
            elseif wKey == 'chakram' then
                local pool = (player:getMainJob() == (xi.job and xi.job.DNC or 19)) and testGear.RANGED.chakram_dnc or testGear.RANGED.throwing
                local item = testGear.pickFromPool(player, pool, lvl)
                if item ~= nil then
                    table.insert(available, { key = wKey, label = info.label, item = item })
                end
            else
                local poolKey = wKey
                local label = info.label
                if wKey == 'scythe' and player:getMainJob() == (xi.job and xi.job.BLM or 4) then
                    poolKey = 'scythe_blm'
                elseif wKey == 'club' and profile.role == 'caster' then
                    poolKey = 'club_mage'
                    label = testGear.WEAPON_INFO.club_mage and testGear.WEAPON_INFO.club_mage.label or label
                elseif wKey == 'staff' and profile.role == 'caster' then
                    poolKey = 'staff_mage'
                    label = testGear.WEAPON_INFO.staff_mage and testGear.WEAPON_INFO.staff_mage.label or label
                end
                local item = testGear.pickFromPool(player, testGear.WEAPONS[poolKey] or testGear.WEAPONS[wKey], lvl, { weaponKey = poolKey })
                if item ~= nil then
                    table.insert(available, { key = wKey, label = label, item = item })
                end
            end
        end
    end
    return available
end

openWeaponMenu = function(player, page)
    page = page or 1
    local available = getAvailableWeaponKeys(player)
    local perPage = 5
    local totalPages = math.max(1, math.ceil(#available / perPage))
    page = math.max(1, math.min(page, totalPages))

    local startIdx = (page - 1) * perPage + 1
    local endIdx   = math.min(#available, startIdx + perPage - 1)
    local options  = {}

    for idx = startIdx, endIdx do
        local entry = available[idx]
        local capturedKey = entry.key
        table.insert(options,
        {
            string.format('%s (%s)', entry.label, entry.item.name),
            function(p)
                executeEquip(p, { weapon = capturedKey })
                delaySendMenu(p, function() return openRootMenu(p) end)
            end,
        })
    end

    if page > 1 then
        table.insert(options,
        {
            'Prev Page',
            function(p)
                delaySendMenu(p, function() return openWeaponMenu(p, page - 1) end)
            end,
        })
    end

    if page < totalPages then
        table.insert(options,
        {
            'Next Page',
            function(p)
                delaySendMenu(p, function() return openWeaponMenu(p, page + 1) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openRootMenu(p) end)
        end,
    })

    return
    {
        title   = string.format('Weapon Type (%d/%d)', page, totalPages),
        options = options,
    }
end

openRoleMenu = function(player)
    local roles =
    {
        { key = 'tp',     label = 'TP Set (Haste / Store TP / Multi)' },
        { key = 'ws',     label = 'WS Set (STR / DEX / WSD / Attack)' },
        { key = 'tank',   label = 'Tank / Mitigation Set' },
        { key = 'ranged', label = 'Ranged DPS Set' },
        { key = 'caster', label = 'Caster / Healer Set' },
    }
    local options = {}

    for _, r in ipairs(roles) do
        local capturedRole = r.key
        table.insert(options,
        {
            r.label,
            function(p)
                executeEquip(p, { role = capturedRole })
                delaySendMenu(p, function() return openRootMenu(p) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openRootMenu(p) end)
        end,
    })

    return
    {
        title   = 'Select Gear Set Role',
        options = options,
    }
end

openLevelMenu = function(player, page)
    page = page or 1
    local brackets = testGear.LEVEL_BRACKETS
    local perPage = 5
    local totalPages = math.max(1, math.ceil(#brackets / perPage))
    page = math.max(1, math.min(page, totalPages))

    local startIdx = (page - 1) * perPage + 1
    local endIdx   = math.min(#brackets, startIdx + perPage - 1)
    local options  = {}

    for idx = startIdx, endIdx do
        local lvl = brackets[idx]
        local capturedLvl = lvl
        table.insert(options,
        {
            string.format('Level %d + Gear', capturedLvl),
            function(p)
                executeEquip(p, { level = capturedLvl, setLevel = true })
                delaySendMenu(p, function() return openRootMenu(p) end)
            end,
        })
    end

    if page > 1 then
        table.insert(options,
        {
            'Prev Page',
            function(p)
                delaySendMenu(p, function() return openLevelMenu(p, page - 1) end)
            end,
        })
    end

    if page < totalPages then
        table.insert(options,
        {
            'Next Page',
            function(p)
                delaySendMenu(p, function() return openLevelMenu(p, page + 1) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openRootMenu(p) end)
        end,
    })

    return
    {
        title   = string.format('Set Level & Gear (%d/%d)', page, totalPages),
        options = options,
    }
end

openRootMenu = function(player)
    local lvl = player:getMainLvl()
    local profile = testGear.getDefaultProfile(player, player:getMainJob(), lvl)
    local options =
    {
        {
            string.format('Equip Recommended (Lv.%d)', lvl),
            function(p)
                executeEquip(p, {})
            end,
        },
        {
            string.format('Equip Best-Pool Gear (Lv.%d)', lvl),
            function(p)
                executeEquip(p, { accessibility = 'best' })
            end,
        },
        {
            string.format('Equip TP Set (Lv.%d)', lvl),
            function(p)
                executeEquip(p, { role = 'tp' })
            end,
        },
        {
            string.format('Equip WS Set (Lv.%d)', lvl),
            function(p)
                executeEquip(p, { role = 'ws' })
            end,
        },
        {
            'Choose Weapon Type...',
            function(p)
                delaySendMenu(p, function() return openWeaponMenu(p, 1) end)
            end,
        },
        {
            'Choose Role / Set Preset...',
            function(p)
                delaySendMenu(p, function() return openRoleMenu(p) end)
            end,
        },
        {
            'Set Level & Equip Gear...',
            function(p)
                delaySendMenu(p, function() return openLevelMenu(p, 1) end)
            end,
        },
        {
            'Inspect Recommended Slots',
            function(p)
                local loadout, err = testGear.buildLoadout(p, {})
                if loadout then
                    printLoadoutDetails(p, loadout)
                else
                    tell(p, err or 'Unable to build loadout.')
                end
                delaySendMenu(p, function() return openRootMenu(p) end)
            end,
        },
        {
            'Cap Skills & Expand Bag (80)',
            function(p)
                testGear.ensureBagSpace(p, 80)
                if p.capAllSkills then
                    p:capAllSkills()
                end
                tell(p, 'Expanded inventory to 80 slots and capped all combat/magic skills.')
                delaySendMenu(p, function() return openRootMenu(p) end)
            end,
        },
        {
            'Close',
            function() end,
        },
    }

    return
    {
        title   = profile.label,
        options = options,
    }
end

-----------------------------------
-- Command Entrypoint
-----------------------------------
local function parseExtraOpts(a, b, opts)
    opts = opts or {}
    for _, token in ipairs({ a, b }) do
        if token ~= nil and token ~= '' then
            local lower = string.lower(tostring(token))
            local num = tonumber(token)
            if num ~= nil then
                opts.level = num
            elseif lower == 'best' then
                opts.accessibility = 'best'
            elseif testGear.resolveRoleKey(token) ~= nil then
                opts.role = testGear.resolveRoleKey(token)
            elseif testGear.resolveWeaponKey(token) ~= nil then
                opts.weapon = testGear.resolveWeaponKey(token)
            else
                return nil, string.format('Unrecognized argument: %s', tostring(token))
            end
        end
    end
    return opts, nil
end

commandObj.onTrigger = function(player, arg1, arg2, arg3)
    if player == nil then
        return
    end

    local cmd = arg1 and string.lower(arg1) or nil

    -- 1. Default (!gear, !gear auto, !gear equip): immediately grant & equip recommended loadout
    if cmd == 'best' then
        local opts, err = parseExtraOpts(arg2, arg3, { accessibility = 'best' })
        if opts == nil then
            tell(player, err)
            printUsage(player)
            return
        end
        executeEquip(player, opts)
        return
    end

    if cmd == nil or cmd == 'auto' or cmd == 'equip' then
        local opts, err = parseExtraOpts(arg2, arg3, {})
        if opts == nil then
            tell(player, err)
            printUsage(player)
            return
        end
        executeEquip(player, opts)
        return
    end

    -- 2. Interactive Menu (!gear menu | !gear ui)
    if cmd == 'menu' or cmd == 'ui' then
        player:customMenu(openRootMenu(player))
        return
    end

    -- 3. Help (!gear help)
    if cmd == 'help' or cmd == '?' then
        printUsage(player)
        return
    end

    -- 4. Inspect / List (!gear info [level|weapon] | !gear list)
    if cmd == 'info' or cmd == 'list' or cmd == 'show' or cmd == 'preview' then
        local opts, err = parseExtraOpts(arg2, arg3, {})
        if opts == nil then
            tell(player, err)
            printUsage(player)
            return
        end
        local loadout, bErr = testGear.buildLoadout(player, opts)
        if loadout == nil then
            tell(player, bErr or 'Unable to build loadout.')
            return
        end
        printLoadoutDetails(player, loadout)
        return
    end

    -- 5. Bag & Skills utilities (!gear bag | !gear skills)
    if cmd == 'bag' or cmd == 'inventory' then
        testGear.ensureBagSpace(player, 80)
        tell(player, 'Inventory capacity expanded to 80 slots.')
        return
    end

    if cmd == 'skills' or cmd == 'cap' then
        if player.capAllSkills then
            player:capAllSkills()
        end
        tell(player, string.format('Capped all combat and magic skills for Lv.%d.', player:getMainLvl()))
        return
    end

    -- 6. Explicit Level Change + Gear (!gear level <1-99> [weapon|role])
    if cmd == 'level' or cmd == 'lvl' or cmd == 'lv' then
        local targetLvl = tonumber(arg2)
        if targetLvl == nil or targetLvl < 1 or targetLvl > 75 then
            tell(player, 'Usage: !gear level <1-75> [weapon|role]')
            return
        end
        local opts, err = parseExtraOpts(arg3, nil, { level = targetLvl, setLevel = true })
        if opts == nil then
            tell(player, err)
            return
        end
        executeEquip(player, opts)
        return
    end

    -- 7. Explicit Weapon Override (!gear weapon <type> [level|role])
    if cmd == 'weapon' or cmd == 'wpn' or cmd == 'w' then
        if arg2 == nil or arg2 == '' then
            tell(player, 'Usage: !gear weapon <type> [level]')
            tell(player, 'Types: h2h, dagger, sword, gs, axe, gaxe, scythe, polearm, katana, gk, club, staff, bow, crossbow, gun, throwing, chakram')
            return
        end
        local wKey = testGear.resolveWeaponKey(arg2)
        if wKey == nil then
            tell(player, string.format('Unknown weapon type: %s', tostring(arg2)))
            printUsage(player)
            return
        end
        local opts, err = parseExtraOpts(arg3, nil, { weapon = wKey })
        if opts == nil then
            tell(player, err)
            return
        end
        executeEquip(player, opts)
        return
    end

    -- 8. Explicit Role Override (!gear role <tp|ws|tank|ranged|caster> [weapon|level])
    if cmd == 'role' or cmd == 'set' then
        local rKey = testGear.resolveRoleKey(arg2)
        if rKey == nil then
            tell(player, 'Usage: !gear role <tp|ws|tank|ranged|caster> [weapon|level]')
            return
        end
        local opts, err = parseExtraOpts(arg3, nil, { role = rKey })
        if opts == nil then
            tell(player, err)
            return
        end
        executeEquip(player, opts)
        return
    end

    -- 9. Shorthand (!gear <level|weapon|role> [arg2] [arg3])
    local opts = {}
    local num1 = tonumber(arg1)
    if num1 ~= nil then
        if num1 < 1 or num1 > 75 then
            tell(player, 'Level must be between 1 and 75.')
            return
        end
        opts.level = num1
    elseif testGear.resolveWeaponKey(arg1) ~= nil then
        opts.weapon = testGear.resolveWeaponKey(arg1)
    elseif testGear.resolveRoleKey(arg1) ~= nil then
        opts.role = testGear.resolveRoleKey(arg1)
    else
        tell(player, string.format('Unknown !gear option: %s', tostring(arg1)))
        printUsage(player)
        return
    end

    local parsedOpts, err = parseExtraOpts(arg2, arg3, opts)
    if parsedOpts == nil then
        tell(player, err)
        printUsage(player)
        return
    end

    executeEquip(player, parsedOpts)
end

xi.commands = xi.commands or {}
xi.commands.gear = commandObj

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('gear', commandObj)
end

return commandObj


