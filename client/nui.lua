--[[
    rde_elevators v3.0 — client/nui.lua
    NUI Communication Handler
    Red Dragon Elite | BFS v6.66
--]]

local NUIOpen = false

-- ─── NUI CALLBACKS ─────────────────────────────────────────────

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    NUIOpen = false
    cb('ok')
end)

RegisterNUICallback('selectFloor', function(data, cb)
    local elevatorId = data.elevatorId
    local floorName = data.floorName
    
    if elevatorId and floorName then
        -- Get elevator and floor data
        local elevator = Elevators[elevatorId]
        if elevator and elevator.data[floorName] then
            local point = elevator.data[floorName].point or elevator.data[floorName]
            TeleportToFloor(elevator, floorName, point)
        end
    end
    
    SetNuiFocus(false, false)
    NUIOpen = false
    cb('ok')
end)

-- ─── OPEN NUI MENU ─────────────────────────────────────────────

function OpenNUIElevatorMenu(elevatorId, currentFloor)
    if not Config.UseNUI then return false end
    
    local elevator = Elevators[elevatorId]
    if not elevator then return false end
    
    -- Build floor data for NUI
    local floors = {}
    for floorName, floorData in pairs(elevator.data) do
        if floorName ~= currentFloor then
            local point = floorData.point or floorData
            local restrictions = floorData.restrictions
            local canAccess, reason = Permissions.CanAccessFloor(0, restrictions)
            
            floors[#floors + 1] = {
                name = floorName,
                canAccess = canAccess,
                restricted = restrictions ~= nil,
                restrictionType = restrictions and (restrictions.vip and 'vip' or restrictions.job and 'job') or nil,
            }
        end
    end
    
    -- Send to NUI
    SendNUIMessage({
        action = 'openElevator',
        data = {
            elevatorId = elevatorId,
            elevatorName = elevator.label,
            currentFloor = currentFloor,
            floors = floors,
            vehicleMode = elevator.vehicle_mode,
        }
    })
    
    SetNuiFocus(true, true)
    NUIOpen = true
    
    return true
end

-- ─── CLOSE NUI ─────────────────────────────────────────────────

RegisterCommand('closeelevator', function()
    if NUIOpen then
        SetNuiFocus(false, false)
        NUIOpen = false
        SendNUIMessage({ action = 'close' })
    end
end, false)

RegisterKeyMapping('closeelevator', 'Close Elevator Menu', 'keyboard', 'ESCAPE')

-- Export
exports('OpenNUIElevatorMenu', OpenNUIElevatorMenu)
