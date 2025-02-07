-- server/main.lua
local ESX = exports['es_extended']:getSharedObject()
local ElevatorCache = {}

-- Function declarations first
local function LoadElevators()
    local result = MySQL.query.await('SELECT * FROM '..Config.TablePrefix..'elevators')
    for _, elevator in ipairs(result) do
        ElevatorCache[elevator.id] = {
            name = elevator.name,
            label = elevator.label,
            data = json.decode(elevator.data),
            created_by = elevator.created_by
        }
    end
end

local function isAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    for _, group in ipairs(Config.Permissions.AdminGroups) do
        if xPlayer.getGroup() == group then
            return true
        end
    end
    return false
end

-- Database initialization
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]]..Config.TablePrefix..[[elevators (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) NOT NULL,
            label VARCHAR(100) NOT NULL,
            data JSON NOT NULL,
            created_by VARCHAR(50),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_name (name)
        )
    ]])
    LoadElevators()
end)

-- CRUD Callbacks
lib.callback.register('rde_elevators:getElevators', function()
    return ElevatorCache
end)

lib.callback.register('rde_elevators:createElevator', function(source, data)
    if not isAdmin(source) then return false end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local success = MySQL.insert.await('INSERT INTO '..Config.TablePrefix..'elevators (name, label, data, created_by) VALUES (?, ?, ?, ?)', {
        data.name,
        data.label,
        json.encode(data.points),
        xPlayer.identifier
    })
    
    if success then
        ElevatorCache[success] = {
            name = data.name,
            label = data.label,
            data = data.points,
            created_by = xPlayer.identifier
        }
        TriggerClientEvent('rde_elevators:syncElevators', -1, ElevatorCache)
        return success
    end
    return false
end)

lib.callback.register('rde_elevators:updateElevator', function(source, id, data)
    if not isAdmin(source) then return false end
    
    local success = MySQL.update.await('UPDATE '..Config.TablePrefix..'elevators SET name = ?, label = ?, data = ? WHERE id = ?', {
        data.name,
        data.label,
        json.encode(data.points),
        id
    })
    
    if success then
        ElevatorCache[id] = {
            name = data.name,
            label = data.label,
            data = data.points,
            created_by = ElevatorCache[id].created_by
        }
        TriggerClientEvent('rde_elevators:syncElevators', -1, ElevatorCache)
        return true
    end
    return false
end)

lib.callback.register('rde_elevators:deleteElevator', function(source, id)
    if not isAdmin(source) then return false end
    
    local success = MySQL.query.await('DELETE FROM '..Config.TablePrefix..'elevators WHERE id = ?', {id})
    
    if success then
        ElevatorCache[id] = nil
        TriggerClientEvent('rde_elevators:syncElevators', -1, ElevatorCache)
        return true
    end
    return false
end)