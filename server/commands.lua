--[[
    rde_elevators v3.0 — server/commands.lua
    Admin Commands System
    Red Dragon Elite | BFS v6.66
    
    ✅ PRODUCTION READY v3:
    - Proper permission checks
    - Client teleport events (not direct SetEntityCoords)
    - Error handling on all operations
    - Null-safety checks
--]]

-- ═══════════════════════════════════════════════════════════════
-- 🎮 ADMIN COMMANDS
-- ═══════════════════════════════════════════════════════════════

-- NOTE: /elevators command is CLIENT-SIDE ONLY (see client/admin.lua)
-- We do NOT register it here to avoid conflicts!

--- /reloadelevators - Reload all elevators from database
RegisterCommand('reloadelevators', function(source, args, rawCommand)
    if not Permissions.IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end
    
    LoadElevators()

    -- ✅ FIX (#8 v1.0.0-alpha): reloadelevators was calling LoadElevators() but
    -- never telling any client to re-fetch. Every connected client kept its
    -- stale (or empty) local Elevators table. Now we broadcast onSync to all
    -- clients so they call getAll and rebuild zones/blips.
    TriggerClientEvent('rde_elevators:onSync', -1)

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Elevators Reloaded',
        description = ('Loaded %d elevators from database'):format(TableCount(Elevators)),
        type = 'success'
    })
    
    RDE_Success('Elevators reloaded by', GetPlayerName(source))
end, false)

--- /gotoelev [id] [floor] - Teleport to specific elevator floor
RegisterCommand('gotoelev', function(source, args, rawCommand)
    if not Permissions.IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end
    
    local elevatorId = tonumber(args[1])
    local floorName = args[2]
    
    if not elevatorId or not floorName then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Invalid Usage',
            description = 'Usage: /gotoelev [elevator_id] [floor_name]',
            type = 'error'
        })
        return
    end
    
    local elevator = GetElevatorCache(elevatorId)
    if not elevator then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Elevator not found',
            type = 'error'
        })
        return
    end
    
    if not elevator.data or not elevator.data[floorName] then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Floor not found',
            type = 'error'
        })
        return
    end
    
    local point = elevator.data[floorName]
    
    -- Trigger client teleport event (proper way!)
    TriggerClientEvent('rde_elevators:teleportToElevator', source, point)
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Teleported',
        description = ('Teleported to %s - %s'):format(elevator.label, floorName),
        type = 'success'
    })
end, false)

--- /listelev - List all elevators
RegisterCommand('listelev', function(source, args, rawCommand)
    if not Permissions.IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end
    
    if TableCount(Elevators) == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Elevators',
            description = 'No elevators found',
            type = 'inform'
        })
        return
    end
    
    print('^2[RDE Elevators]^7 === ELEVATOR LIST ===')
    for id, elevator in pairs(Elevators) do
        local floorCount = TableCount(elevator.data or {})
        print(string.format('^3ID: %d^7 | ^5%s^7 (%s) | ^6%d floors^7 | Vehicle: %s',
            id,
            elevator.label,
            elevator.name,
            floorCount,
            elevator.vehicle_mode and '^2Yes^7' or '^1No^7'
        ))
    end
    print('^2[RDE Elevators]^7 === Total: ' .. TableCount(Elevators) .. ' ===')
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Elevators',
        description = 'Check server console for elevator list',
        type = 'inform'
    })
end, false)

--- /elevstats [id] - Show elevator statistics
RegisterCommand('elevstats', function(source, args, rawCommand)
    if not Permissions.IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end
    
    local elevatorId = tonumber(args[1])
    
    if not elevatorId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Invalid Usage',
            description = 'Usage: /elevstats [elevator_id]',
            type = 'error'
        })
        return
    end
    
    local elevator = GetElevatorCache(elevatorId)
    if not elevator then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Elevator not found',
            type = 'error'
        })
        return
    end
    
    -- Get statistics
    local success, stats = pcall(function()
        return MySQL.query.await([[
            SELECT 
                COUNT(*) as total_uses,
                COUNT(DISTINCT user_identifier) as unique_users,
                to_floor as most_popular,
                COUNT(*) as popularity
            FROM rde_elevator_analytics
            WHERE elevator_id = ?
            GROUP BY to_floor
            ORDER BY popularity DESC
            LIMIT 1
        ]], {elevatorId})
    end)
    
    if not success or not stats or #stats == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = elevator.label,
            description = 'No statistics available yet',
            type = 'inform'
        })
        return
    end
    
    local stat = stats[1]
    
    print('^2[RDE Elevators]^7 === STATISTICS: ' .. elevator.label .. ' ===')
    print('^6Total Uses:^7 ' .. (stat.total_uses or 0))
    print('^6Unique Users:^7 ' .. (stat.unique_users or 0))
    print('^6Most Popular Floor:^7 ' .. (stat.most_popular or 'N/A'))
    print('^2[RDE Elevators]^7 =========================')
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Statistics',
        description = 'Check server console for detailed stats',
        type = 'inform'
    })
end, false)

--- /elevmaint [id] - Toggle maintenance mode
RegisterCommand('elevmaint', function(source, args, rawCommand)
    if not Permissions.IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end
    
    local elevatorId = tonumber(args[1])
    
    if not elevatorId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Invalid Usage',
            description = 'Usage: /elevmaint [elevator_id]',
            type = 'error'
        })
        return
    end
    
    if not Elevators[elevatorId] then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Elevator not found',
            type = 'error'
        })
        return
    end
    
    local maintenanceKey = ('rde_elevators:maintenance:%d'):format(elevatorId)
    local currentState = GlobalState[maintenanceKey] or false
    local newState = not currentState
    
    GlobalState:set(maintenanceKey, newState, true)
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Maintenance Mode',
        description = ('Elevator %d: %s'):format(elevatorId, newState and 'ENABLED' or 'DISABLED'),
        type = newState and 'warning' or 'success'
    })
    
    RDE_Debug('Maintenance mode toggled for elevator', elevatorId, 'by', GetPlayerName(source))
end, false)

--- /elevstopall - Emergency stop all elevators
RegisterCommand('elevstopall', function(source, args, rawCommand)
    if not Permissions.IsOwner(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Only server owners can use this command',
            type = 'error'
        })
        return
    end
    
    for id in pairs(Elevators) do
        GlobalState:set(('rde_elevators:maintenance:%d'):format(id), true, true)
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '🚨 EMERGENCY STOP',
        description = 'All elevators are now in maintenance mode',
        type = 'warning'
    })
    
    RDE_Success('EMERGENCY STOP activated by', GetPlayerName(source))
end, false)

--- /elevresumeall - Resume all elevators
RegisterCommand('elevresumeall', function(source, args, rawCommand)
    if not Permissions.IsOwner(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Only server owners can use this command',
            type = 'error'
        })
        return
    end
    
    for id in pairs(Elevators) do
        GlobalState:set(('rde_elevators:maintenance:%d'):format(id), false, true)
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '✅ All Elevators Resumed',
        description = 'All elevators are now operational',
        type = 'success'
    })
    
    RDE_Success('All elevators resumed by', GetPlayerName(source))
end, false)

--- /elevdeleteall - DELETE ALL ELEVATORS (DANGEROUS!)
RegisterCommand('elevdeleteall', function(source, args, rawCommand)
    if not Permissions.IsOwner(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Only server owners can use this command',
            type = 'error'
        })
        return
    end
    
    -- Require confirmation argument
    if args[1] ~= 'CONFIRM' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '⚠️ WARNING',
            description = 'This will DELETE ALL ELEVATORS! Use: /elevdeleteall CONFIRM',
            type = 'error'
        })
        return
    end
    
    local count = TableCount(Elevators)
    
    -- Delete from database
    local success = pcall(function()
        MySQL.query.await('TRUNCATE TABLE rde_elevators')
        MySQL.query.await('TRUNCATE TABLE rde_elevator_analytics')
    end)
    
    if not success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Failed to delete elevators from database',
            type = 'error'
        })
        return
    end
    
    -- Clear GlobalState
    for id in pairs(Elevators) do
        GlobalState:set(('rde_elevators:data:%d'):format(id), nil, true)
        GlobalState:set(('rde_elevators:occupied:%d'):format(id), nil, true)
        GlobalState:set(('rde_elevators:maintenance:%d'):format(id), nil, true)
    end
    
    Elevators = {}
    -- ✅ FIX (#4 v1.0.0-alpha): ElevatorCache no longer exists after v4.1 refactor.
    -- Removed phantom assignment that was silently creating a new global table.

    TriggerClientEvent('ox_lib:notify', source, {
        title = '💀 ALL DELETED',
        description = ('Deleted %d elevators and all analytics data'):format(count),
        type = 'error'
    })
    
    RDE_Success('ALL ELEVATORS DELETED by', GetPlayerName(source), '- Count:', count)
end, false)

RDE_Debug('Server commands.lua loaded successfully!')
