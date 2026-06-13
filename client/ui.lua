--[[
    rde_elevators v3.0 — client/ui.lua
    UI Helper Functions
    Red Dragon Elite | BFS v6.66
--]]

-- Simple UI notification wrapper
function ShowNotification(title, description, type, duration)
    lib.notify({
        title = title,
        description = description,
        type = type or 'info',
        duration = duration or 3000,
        position = Config.Notify[type == 'success' and 'Success' or 'Info'].position
    })
end

-- Export
exports('ShowNotification', ShowNotification)
