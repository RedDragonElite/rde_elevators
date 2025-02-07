-- client/main.lua
local ESX = exports['es_extended']:getSharedObject()
local Elevators = {}
local isAdmin = false

-- Check admin status - UPDATED VERSION
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    if not xPlayer then return end
    
    -- Get player group and handle both string and function cases
    local playerGroup = type(xPlayer.getGroup) == 'function' and xPlayer.getGroup() or xPlayer.group
    
    -- Check if player is admin or superadmin
    isAdmin = playerGroup == 'admin' or playerGroup == 'superadmin'
    
    -- Debug print
    print('Player Group:', playerGroup)
    print('Is Admin:', isAdmin)
end)

-- Utility functions - UPDATED VERSION
function IsPlayerAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    -- Get player group and handle both string and function cases
    local playerGroup = type(xPlayer.getGroup) == 'function' and xPlayer.getGroup() or xPlayer.group
    
    -- Check if player is admin or superadmin
    return playerGroup == 'admin' or playerGroup == 'superadmin'
end

-- Sync elevators
RegisterNetEvent('rde_elevators:syncElevators')
AddEventHandler('rde_elevators:syncElevators', function(elevatorData)
    Elevators = elevatorData
    CreateElevatorTargets()
end)

-- Initial load
CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(100) end
    Elevators = lib.callback.await('rde_elevators:getElevators', false)
    CreateElevatorTargets()
end)

-- Register command for admin menu with improved permission checking
RegisterCommand('elevators', function()
    print('Command triggered') -- Debug print
    print('Current isAdmin status:', isAdmin) -- Debug print
    
    -- Force recheck admin status
    local xPlayer = ESX.GetPlayerData()
    if xPlayer then
        local playerGroup = type(xPlayer.getGroup) == 'function' and xPlayer.getGroup() or xPlayer.group
        isAdmin = playerGroup == 'admin' or playerGroup == 'superadmin'
        print('Rechecked admin status. Group:', playerGroup, 'IsAdmin:', isAdmin) -- Debug print
    end
    
    if not isAdmin then 
        print('Not admin') -- Debug print
        lib.notify({
            title = 'Access Denied',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return 
    end
    print('Opening admin menu') -- Debug print
    OpenElevatorAdminMenu()
end, false)

function TeleportToFloor(point)
    local ped = PlayerPedId()
    
    -- Ensure the point exists and has valid coordinates
    if not point or not point.x or not point.y or not point.z then
        lib.notify({
            title = 'Error',
            description = 'Invalid teleport destination',
            type = 'error'
        })
        return
    end

    -- Add a loading animation
    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(0) end

    -- Handle vehicle teleportation
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        SetEntityCoords(vehicle, point.x, point.y, point.z)
        SetEntityHeading(vehicle, point.w)
    else
        SetEntityCoords(ped, point.x, point.y, point.z)
        SetEntityHeading(ped, point.w)
    end

    -- Add small delay to prevent falling through ground
    Wait(100)
    
    -- Fade back in
    DoScreenFadeIn(800)
    while not IsScreenFadedIn() do Wait(0) end
end

function CreateElevatorTargets()
    -- Remove existing zones if they exist
    for id, elevator in pairs(Elevators) do
        for floorName, _ in pairs(elevator.data) do
            exports.ox_target:removeZone('elevator_' .. id .. '_' .. floorName)
        end
    end
    
    -- Create new zones
    for id, elevator in pairs(Elevators) do
        for floorName, point in pairs(elevator.data) do
            exports.ox_target:addBoxZone({
                name = 'elevator_' .. id .. '_' .. floorName,
                coords = vec3(point.x, point.y, point.z),
                size = Config.Target.Size,
                rotation = point.w,
                debug = Config.Debug,
                options = {
                    {
                        name = 'elevator_' .. id .. '_' .. floorName,
                        icon = Config.Target.Icon,
                        label = ('%s - %s'):format(elevator.label, floorName),
                        distance = Config.Target.Distance,
                        onSelect = function()
                            OpenElevatorMenu(id, floorName)
                        end
                    }
                }
            })
        end
    end
end

function OpenElevatorMenu(elevatorId, currentFloor)
    local elevator = Elevators[elevatorId]
    local options = {}
    
    for floorName, point in pairs(elevator.data) do
        if floorName ~= currentFloor then
            options[#options + 1] = {
                title = floorName,
                description = ('Travel to %s'):format(floorName),
                icon = Config.Target.Icon,
                onSelect = function()
                    TeleportToFloor(point)
                end
            }
        end
    end
    
    lib.registerContext({
        id = 'elevator_menu',
        title = elevator.label,
        options = options
    })
    
    lib.showContext('elevator_menu')
end

function OpenElevatorAdminMenu()
    print('OpenElevatorAdminMenu called') -- Debug print

    local options = {
        {
            title = 'Create New Elevator',
            description = 'Add a new elevator to the system',
            icon = 'plus',
            color = 'green', -- Add color for the icon
            onSelect = function()
                CreateNewElevator()
            end
        }
    }

    for id, elevator in pairs(Elevators) do
        options[#options + 1] = {
            title = elevator.label,
            description = elevator.name,
            icon = 'elevator',
            color = 'blue', -- Add color for the icon
            menu = 'elevator_manage_' .. id,
            metadata = {
                {label = 'ID', value = id},
                {label = 'Created By', value = elevator.created_by}
            }
        }

        lib.registerContext({
            id = 'elevator_manage_' .. id,
            title = elevator.label,
            menu = 'elevator_admin',
            options = {
                {
                    title = 'Edit Elevator',
                    description = 'Modify elevator settings',
                    icon = 'edit',
                    color = 'orange', -- Add color for the icon
                    onSelect = function()
                        EditElevator(id)
                    end
                },
                {
                    title = 'Add Floor Point',
                    description = 'Add new floor to elevator',
                    icon = 'plus',
                    color = 'green', -- Add color for the icon
                    onSelect = function()
                        AddFloorPoint(id)
                    end
                },
                {
                    title = 'Remove Floor Point',
                    description = 'Remove floor from elevator',
                    icon = 'minus',
                    color = 'red', -- Add color for the icon
                    onSelect = function()
                        RemoveFloorPoint(id)
                    end
                },
                {
                    title = 'Delete Elevator',
                    description = 'Permanently delete elevator',
                    icon = 'trash',
                    color = 'red', -- Add color for the icon
                    onSelect = function()
                        DeleteElevator(id)
                    end
                }
            }
        })
    end

    lib.registerContext({
        id = 'elevator_admin',
        title = 'Elevator Management',
        options = options
    })

    lib.showContext('elevator_admin')
end

function CreateNewElevator()
    local input = lib.inputDialog('Create New Elevator', {
        {type = 'input', label = 'Internal Name', required = true},
        {type = 'input', label = 'Display Label', required = true}
    })
    
    if not input then return end
    
    local elevatorData = {
        name = input[1],
        label = input[2],
        points = {}
    }
    
    local success = lib.callback.await('rde_elevators:createElevator', false, elevatorData)
    
    if success then
        lib.notify(Config.Notify.Success)
        AddFloorPoint(success)
    else
        lib.notify(Config.Notify.Error)
    end
end

function EditElevator(id)
    local elevator = Elevators[id]
    
    local input = lib.inputDialog('Edit Elevator', {
        {type = 'input', label = 'Internal Name', required = true, default = elevator.name},
        {type = 'input', label = 'Display Label', required = true, default = elevator.label}
    })
    
    if not input then return end
    
    local updatedData = {
        name = input[1],
        label = input[2],
        points = elevator.data
    }
    
    local success = lib.callback.await('rde_elevators:updateElevator', false, id, updatedData)
    
    if success then
        lib.notify(Config.Notify.Success)
    else
        lib.notify(Config.Notify.Error)
    end
end

function AddFloorPoint(id)
    local input = lib.inputDialog('Add Floor Point', {
        {type = 'input', label = 'Floor Name', required = true}
    })
    
    if not input then return end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local elevator = Elevators[id]
    local points = elevator.data
    points[input[1]] = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = heading
    }
    
    local success = lib.callback.await('rde_elevators:updateElevator', false, id, {
        name = elevator.name,
        label = elevator.label,
        points = points
    })
    
    if success then
        lib.notify(Config.Notify.Success)
    else
        lib.notify(Config.Notify.Error)
    end
end

function RemoveFloorPoint(id)
    local elevator = Elevators[id]
    local options = {}
    
    for floorName, _ in pairs(elevator.data) do
        options[#options + 1] = {
            value = floorName,
            label = floorName
        }
    end
    
    local input = lib.inputDialog('Remove Floor Point', {
        {type = 'select', label = 'Select Floor', options = options, required = true}
    })
    
    if not input then return end
    
    local points = elevator.data
    points[input[1]] = nil
    
    local success = lib.callback.await('rde_elevators:updateElevator', false, id, {
        name = elevator.name,
        label = elevator.label,
        points = points
    })
    
    if success then
        lib.notify(Config.Notify.Success)
    else
        lib.notify(Config.Notify.Error)
    end
end

function DeleteElevator(id)
    local confirm = lib.alertDialog({
        header = 'Confirm Deletion',
        content = 'Are you sure you want to delete this elevator?',
        cancel = true
    })
    
    if confirm == 'confirm' then
        local success = lib.callback.await('rde_elevators:deleteElevator', false, id)
        
        if success then
            lib.notify(Config.Notify.Success)
        else
            lib.notify(Config.Notify.Error)
        end
    end
end