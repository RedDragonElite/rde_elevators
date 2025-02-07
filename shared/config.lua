-- shared/config.lua
Config = {
    Debug = false,
    DefaultDistance = 2.0,
    TablePrefix = 'rde_',
    
    Permissions = {
        -- Groups that can manage elevators
        AdminGroups = {
            'admin',
            'superadmin'
        }
    },
    
    Notify = {
        -- Notification settings
        Success = {
            type = 'success',
            duration = 3000
        },
        Error = {
            type = 'error',
            duration = 3000
        }
    },
    
    Target = {
        -- ox_target settings
        Icon = 'fas fa-elevator',
        Distance = 2.0,
        Size = vec3(2, 2, 3)
    },
    
    Teleport = {
        -- Teleport settings
        FadeTime = 500,
        WaitTime = 500
    }
}