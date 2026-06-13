--[[
    rde_elevators v4.0 — client/admin.lua
    Full-Featured Ingame Admin Panel — Next Gen
    Red Dragon Elite | BFS v6.66

    v4.0 NEW:
    ✅ Per-elevator ENABLE / DISABLE toggle (ingame)
    ✅ Per-elevator VEHICLE MODE toggle (bug-fixed)
    ✅ Per-elevator BLIP customization: sprite, color, scale, label
    ✅ Blip sprite selector (labeled presets)
    ✅ Blip color picker (named GTA colors)
    ✅ All icons: Lucide (icons.overextended.dev)
    ✅ Status badges: enabled/vehicle/maintenance
    ✅ Cleaner menu hierarchy
--]]

-- ════════════════════════════════════════════════════════════════
-- 🎨 UI CONSTANTS
-- ════════════════════════════════════════════════════════════════

local STATUS_ICONS = {
    enabled     = 'circle-check',
    disabled    = 'circle-x',
    vehicle_on  = 'car',
    vehicle_off = 'footprints',
    maintenance = 'triangle-alert',
    blip        = 'map-pin',
    floors      = 'layers',
    edit        = 'pencil',
    delete      = 'trash-2',
    stats       = 'bar-chart-2',
    back        = 'chevron-left',
    create      = 'plus-circle',
    teleport    = 'zap',
    add_floor   = 'map-pin-plus',
    remove_floor= 'map-pin-minus',
    emergency   = 'siren',
}

local BLIP_SPRITES = {
    { label = 'Elevator (default)',   value = 357 },
    { label = 'Garage / Car',         value = 225 },
    { label = 'Star / VIP',           value = 311 },
    { label = 'Police Station',       value = 60  },
    { label = 'Hospital',             value = 61  },
    { label = 'Warehouse',            value = 473 },
    { label = 'Construction',         value = 318 },
    { label = 'Casino',               value = 571 },
    { label = 'Nightclub',            value = 272 },
    { label = 'Hotel',                value = 245 },
    { label = 'Subway',               value = 471 },
    { label = 'Parking',              value = 318 },
    { label = 'Apartment',            value = 40  },
    { label = 'Shopping',             value = 73  },
    { label = 'Business',             value = 374 },
}

local BLIP_COLORS = {
    { label = 'White',       value = 0   },
    { label = 'Red',         value = 1   },
    { label = 'Green',       value = 2   },
    { label = 'Blue',        value = 3   },
    { label = 'White 2',     value = 4   },
    { label = 'Yellow',      value = 5   },
    { label = 'Pink',        value = 6   },
    { label = 'Dark Orange', value = 7   },
    { label = 'Purple',      value = 27  },
    { label = 'Cyan',        value = 38  },
    { label = 'Teal',        value = 30  },
    { label = 'Dark Green',  value = 25  },
    { label = 'Grey',        value = 40  },
    { label = 'Dark Grey',   value = 9   },
    { label = 'Light Blue',  value = 29  },
    { label = 'Gold',        value = 46  },
    { label = 'Orange',      value = 17  },
}

-- ════════════════════════════════════════════════════════════════
-- 🛡️ ADMIN GUARD
-- ════════════════════════════════════════════════════════════════

local _adminVerified = false

local function EnsureAdmin(cb)
    if _adminVerified then cb() return end
    -- Fast path: ox_core cache
    if IsLocalPlayerAdmin() then
        _adminVerified = true
        cb()
        return
    end
    -- Fallback: server verification
    local ok = lib.callback.await('rde_elevators:checkAdmin', false)
    if ok then
        _adminVerified = true
        cb()
    else
        lib.notify({ title = L('notifications.unauthorized'), description = L('notifications.unauthorized_desc'), type = 'error' })
    end
end

-- Reset admin cache on resource restart
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then _adminVerified = false end
end)

-- ════════════════════════════════════════════════════════════════
-- 📋 MAIN ADMIN MENU
-- ════════════════════════════════════════════════════════════════

function OpenAdminMenu()
    EnsureAdmin(function()
        local options = {
            {
                title       = L('admin.create_new'),
                description = L('admin.create_desc'),
                icon        = STATUS_ICONS.create,
                iconColor   = '#10b981',
                onSelect    = CreateElevator,
            },
            {
                title       = 'Emergency Stop — All Elevators',
                description = 'Put ALL elevators into maintenance mode immediately',
                icon        = STATUS_ICONS.emergency,
                iconColor   = '#ef4444',
                onSelect    = function()
                    local confirm = lib.alertDialog({
                        header  = '🚨 Emergency Stop',
                        content = 'This will put ALL elevators into maintenance mode. Are you sure?',
                        centered = true,
                        cancel  = true,
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('rde_elevators:emergencyStopAll')
                        lib.notify({ title = '🚨 Emergency Stop', description = 'All elevators are now in maintenance mode.', type = 'warning' })
                    end
                end,
            },
        }

        -- Sort elevators by ID
        local sortedIds = {}
        for id in pairs(Elevators) do sortedIds[#sortedIds+1] = id end
        table.sort(sortedIds)

        for _, id in ipairs(sortedIds) do
            local elev      = Elevators[id]
            local isEnabled = elev.enabled ~= false
            local mainKey   = Config.StateBags.Maintenance .. ':' .. id
            local inMaint   = GlobalState[mainKey] or false

            -- Status badge
            local statusIcon, statusColor, statusDesc
            if inMaint then
                statusIcon  = STATUS_ICONS.maintenance
                statusColor = '#f59e0b'
                statusDesc  = '⚠️ MAINTENANCE'
            elseif not isEnabled then
                statusIcon  = STATUS_ICONS.disabled
                statusColor = '#6b7280'
                statusDesc  = '⭕ OFFLINE'
            elseif elev.vehicle_mode then
                statusIcon  = STATUS_ICONS.vehicle_on
                statusColor = '#3b82f6'
                statusDesc  = '🚗 VEHICLE MODE'
            else
                statusIcon  = STATUS_ICONS.enabled
                statusColor = '#10b981'
                statusDesc  = '✅ ACTIVE'
            end

            local floorCount = TableCount(elev.data or {})
            options[#options+1] = {
                title       = ('[%d] %s'):format(id, elev.label),
                description = ('%s  |  %d floor(s)  |  %s'):format(elev.name, floorCount, statusDesc),
                icon        = statusIcon,
                iconColor   = statusColor,
                onSelect    = function() ManageElevator(id) end,
            }
        end

        lib.registerContext({ id = 'rde_elevator_admin', title = '🐉 RDE Elevators — Admin', options = options })
        lib.showContext('rde_elevator_admin')
    end)
end

-- ════════════════════════════════════════════════════════════════
-- 🏗️ MANAGE SINGLE ELEVATOR
-- ════════════════════════════════════════════════════════════════

function ManageElevator(id)
    local elev = Elevators[id]
    if not elev then return end

    local isEnabled = elev.enabled ~= false
    local mainKey   = Config.StateBags.Maintenance .. ':' .. id
    local inMaint   = GlobalState[mainKey] or false
    local floorCount = TableCount(elev.data or {})

    local options = {
        -- ── ENABLE / DISABLE ──────────────────────────────────────
        {
            title       = isEnabled and '⭕  Disable This Elevator' or '✅  Enable This Elevator',
            description = isEnabled and 'Takes elevator offline — players cannot use it' or 'Puts elevator back online',
            icon        = isEnabled and STATUS_ICONS.disabled or STATUS_ICONS.enabled,
            iconColor   = isEnabled and '#ef4444' or '#10b981',
            onSelect    = function() ToggleEnabled(id) end,
        },
        -- ── VEHICLE MODE ──────────────────────────────────────────
        {
            title       = elev.vehicle_mode and '🚶  Switch to Ped Mode' or '🚗  Switch to Vehicle Mode',
            description = elev.vehicle_mode and 'Players will no longer be able to use this elevator with vehicles' or 'Allow vehicles to use this elevator',
            icon        = elev.vehicle_mode and STATUS_ICONS.vehicle_off or STATUS_ICONS.vehicle_on,
            iconColor   = elev.vehicle_mode and '#6b7280' or '#3b82f6',
            onSelect    = function() ToggleVehicleMode(id) end,
        },
        -- ── MAINTENANCE ───────────────────────────────────────────
        {
            title       = inMaint and '🔓  End Maintenance' or '⚠️  Start Maintenance',
            description = inMaint and 'Restore normal elevator operation' or 'Only admins can use the elevator during maintenance',
            icon        = STATUS_ICONS.maintenance,
            iconColor   = inMaint and '#10b981' or '#f59e0b',
            onSelect    = function()
                TriggerServerEvent('rde_elevators:toggleMaintenance', id)
                Wait(150)
                ManageElevator(id)
            end,
        },
        -- ── BLIP ──────────────────────────────────────────────────
        {
            title       = '🗺️  Customize Blip',
            description = 'Change sprite, color, scale and label for this elevator\'s minimap marker',
            icon        = STATUS_ICONS.blip,
            iconColor   = '#8b5cf6',
            onSelect    = function() CustomizeBlip(id) end,
        },
        -- ── FLOORS ────────────────────────────────────────────────
        {
            title       = ('🏢  Manage Floors (%d)'):format(floorCount),
            description = 'Add, remove or teleport to floors',
            icon        = STATUS_ICONS.floors,
            iconColor   = '#06b6d4',
            onSelect    = function() ManageFloors(id) end,
        },
        -- ── EDIT ──────────────────────────────────────────────────
        {
            title       = '✏️  Edit Name & Label',
            description = ('Name: %s  |  Label: %s'):format(elev.name, elev.label),
            icon        = STATUS_ICONS.edit,
            iconColor   = '#f59e0b',
            onSelect    = function() EditElevator(id) end,
        },
        -- ── STATS ─────────────────────────────────────────────────
        {
            title       = '📊  View Statistics',
            description = 'Usage data for this elevator',
            icon        = STATUS_ICONS.stats,
            iconColor   = '#10b981',
            onSelect    = function() ViewStats(id) end,
        },
        -- ── DELETE ────────────────────────────────────────────────
        {
            title       = '🗑️  Delete Elevator',
            description = 'Permanently remove this elevator and all its floors',
            icon        = STATUS_ICONS.delete,
            iconColor   = '#ef4444',
            onSelect    = function() DeleteElevator(id) end,
        },
    }

    lib.registerContext({
        id      = 'rde_elevator_manage',
        title   = ('[%d] %s — Settings'):format(id, elev.label),
        menu    = 'rde_elevator_admin',
        options = options,
    })
    lib.showContext('rde_elevator_manage')
end

-- ════════════════════════════════════════════════════════════════
-- ✅ TOGGLE ENABLED
-- ════════════════════════════════════════════════════════════════

function ToggleEnabled(id)
    local ok = false
    pcall(function() ok = lib.callback.await('rde_elevators:toggleEnabled', false, id) or false end)
    if ok then
        local elev = Elevators[id]
        local state = elev and (elev.enabled ~= false) and 'OFFLINE' or 'ONLINE'
        lib.notify({ title = '⚡ Elevator Toggled', description = ('Elevator is now %s'):format(state), type = 'success' })
        Wait(200)
        ManageElevator(id)
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- 🚗 TOGGLE VEHICLE MODE
-- ════════════════════════════════════════════════════════════════

function ToggleVehicleMode(id)
    local ok = false
    pcall(function() ok = lib.callback.await('rde_elevators:toggleVehicle', false, id) or false end)
    if ok then
        lib.notify({ title = '🚗 Vehicle Mode Toggled', type = 'success' })
        Wait(200)
        ManageElevator(id)
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- 🗺️ BLIP CUSTOMIZATION
-- ════════════════════════════════════════════════════════════════

function CustomizeBlip(id)
    local elev = Elevators[id]
    if not elev then return end

    local blip = elev.blip or {}

    -- Build sprite options string
    local spriteStr = ''
    for i, s in ipairs(BLIP_SPRITES) do
        spriteStr = spriteStr .. i .. ' = ' .. s.label
        if i < #BLIP_SPRITES then spriteStr = spriteStr .. '\n' end
    end

    -- Build color options string
    local colorStr = ''
    for i, c in ipairs(BLIP_COLORS) do
        colorStr = colorStr .. i .. ' = ' .. c.label .. ' (ID: ' .. c.value .. ')'
        if i < #BLIP_COLORS then colorStr = colorStr .. '\n' end
    end

    -- Find current sprite/color index
    local curSpriteIdx = 1
    for i, s in ipairs(BLIP_SPRITES) do
        if s.value == (blip.sprite or Config.Blips.Sprite) then curSpriteIdx = i break end
    end
    local curColorIdx = 1
    for i, c in ipairs(BLIP_COLORS) do
        if c.value == (blip.color or Config.Blips.Color) then curColorIdx = i break end
    end

    local input = lib.inputDialog(
        ('🗺️ Blip Settings — %s'):format(elev.label),
        {
            {
                -- ✅ FIX (v4.1.1): per-elevator blip visibility toggle.
                -- Some elevators (garages, secret entrances) shouldn't clutter
                -- everyone's minimap. This lets admins hide them per-elevator
                -- without disabling the whole blip system.
                type        = 'checkbox',
                label       = 'Show blip on minimap',
                description = 'Uncheck to hide this elevator from the minimap entirely (zone interaction stays active)',
                checked     = blip.enabled ~= false,
            },
            {
                type        = 'select',
                label       = 'Blip Icon / Sprite',
                description = 'Choose the minimap icon for this elevator',
                options     = (function()
                    local opts = {}
                    for _, s in ipairs(BLIP_SPRITES) do
                        opts[#opts+1] = { label = s.label, value = tostring(s.value) }
                    end
                    return opts
                end)(),
                default     = tostring(blip.sprite or Config.Blips.Sprite),
            },
            {
                type        = 'select',
                label       = 'Blip Color',
                description = 'Choose the minimap marker color',
                options     = (function()
                    local opts = {}
                    for _, c in ipairs(BLIP_COLORS) do
                        opts[#opts+1] = { label = c.label, value = tostring(c.value) }
                    end
                    return opts
                end)(),
                default     = tostring(blip.color or Config.Blips.Color),
            },
            {
                type        = 'slider',
                label       = 'Blip Scale',
                description = 'Size of the minimap marker (0.3 = tiny, 1.5 = large)',
                default     = math.floor((blip.scale or Config.Blips.Scale) * 10),
                min         = 3,
                max         = 15,
                step        = 1,
            },
            {
                type        = 'input',
                label       = 'Custom Label (leave blank to use elevator label)',
                description = 'Text shown when hovering the blip on the minimap',
                default     = blip.label or '',
                max         = 80,
            },
        }
    )

    if not input then return end

    -- Input indexes shifted by 1 because of the new checkbox at position [1]
    local newBlip = {
        enabled = input[1] == true,
        sprite  = tonumber(input[2]) or Config.Blips.Sprite,
        color   = tonumber(input[3]) or Config.Blips.Color,
        scale   = (tonumber(input[4]) or 7) / 10.0,
        label   = (input[5] and input[5] ~= '') and input[5] or nil,
    }

    local ok = false
    pcall(function() ok = lib.callback.await('rde_elevators:setBlip', false, id, newBlip) or false end)

    if ok then
        lib.notify({ title = '🗺️ Blip Updated', description = 'Minimap marker updated for all players', type = 'success' })
        Wait(200)
        ManageElevator(id)
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- 🏢 FLOOR MANAGEMENT
-- ════════════════════════════════════════════════════════════════

function ManageFloors(id)
    local elev = Elevators[id]
    if not elev then return end

    local options = {
        {
            title       = '➕  Add Floor at Current Position',
            description = 'Register your current position as a new floor',
            icon        = STATUS_ICONS.add_floor,
            iconColor   = '#10b981',
            onSelect    = function() AddFloor(id) end,
        },
    }

    local sortedFloors = {}
    for name in pairs(elev.data or {}) do sortedFloors[#sortedFloors+1] = name end
    table.sort(sortedFloors)

    for _, floorName in ipairs(sortedFloors) do
        local fd     = elev.data[floorName]
        local point  = fd.point or fd
        options[#options+1] = {
            title       = floorName,
            description = ('X: %.1f  Y: %.1f  Z: %.1f  H: %.1f°'):format(point.x, point.y, point.z, point.w or 0),
            icon        = 'layers',
            iconColor   = '#06b6d4',
            metadata    = {
                { label = 'Actions', value = 'Teleport | Remove' },
            },
            onSelect    = function() FloorOptions(id, floorName) end,
        }
    end

    lib.registerContext({
        id      = 'rde_elevator_floors',
        title   = ('🏢 Floors — %s'):format(elev.label),
        menu    = 'rde_elevator_manage',
        options = options,
    })
    lib.showContext('rde_elevator_floors')
end

function FloorOptions(id, floorName)
    lib.registerContext({
        id      = 'rde_floor_options',
        title   = ('Floor: %s'):format(floorName),
        menu    = 'rde_elevator_floors',
        options = {
            {
                title     = '⚡ Teleport Here',
                icon      = STATUS_ICONS.teleport,
                iconColor = '#8b5cf6',
                onSelect  = function()
                    lib.callback.await('rde_elevators:teleport', false, id, floorName)
                    lib.notify({ title = 'Teleported', description = floorName, type = 'success' })
                end,
            },
            {
                title     = '🗑️ Remove This Floor',
                icon      = STATUS_ICONS.remove_floor,
                iconColor = '#ef4444',
                onSelect  = function() RemoveFloor(id, floorName) end,
            },
        },
    })
    lib.showContext('rde_floor_options')
end

-- ════════════════════════════════════════════════════════════════
-- 🏗️ CREATE ELEVATOR
-- ════════════════════════════════════════════════════════════════

function CreateElevator()
    local input = lib.inputDialog('➕ Create New Elevator', {
        { type = 'input',    label = L('input.elevator_name'),  required = true, min = 3, max = 50 },
        { type = 'input',    label = L('input.elevator_label'), required = true, min = 3, max = 100 },
        { type = 'checkbox', label = L('input.enable_vehicle'), checked = false },
    })
    if not input then return end

    local name, label, vehicleMode = input[1], input[2], input[3]
    local ok, id = pcall(function()
        return lib.callback.await('rde_elevators:create', false, name, label, vehicleMode)
    end)

    if ok and id then
        lib.notify({ title = L('notifications.elevator_created'), description = label, type = 'success' })
        Wait(300)
        OpenAdminMenu()
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- ✏️ EDIT ELEVATOR
-- ════════════════════════════════════════════════════════════════

function EditElevator(id)
    local elev = Elevators[id]
    if not elev then return end

    local input = lib.inputDialog(('✏️ Edit — %s'):format(elev.label), {
        { type = 'input', label = L('input.elevator_name'),  default = elev.name,  required = true, min = 3, max = 50 },
        { type = 'input', label = L('input.elevator_label'), default = elev.label, required = true, min = 3, max = 100 },
    })
    if not input then return end

    local ok = false
    pcall(function() ok = lib.callback.await('rde_elevators:edit', false, id, input[1], input[2]) or false end)

    if ok then
        lib.notify({ title = 'Updated', description = input[2], type = 'success' })
        Wait(200)
        ManageElevator(id)
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- ➕ ADD FLOOR
-- ════════════════════════════════════════════════════════════════

function AddFloor(id)
    local ped     = cache.ped  -- ✅ FIX (#3 v1.0.0-alpha): cache.ped not PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local elev    = Elevators[id]
    if not elev then return end

    local input = lib.inputDialog('➕ Add Floor', {
        { type = 'input', label = L('input.floor_name'), required = true, min = 1, max = 30 },
    })
    if not input or not input[1] then return end

    local floorName = input[1]
    local points    = DeepCopy(elev.data or {})
    points[floorName] = { x = coords.x, y = coords.y, z = coords.z, w = heading }

    local ok = false
    pcall(function() ok = lib.callback.await('rde_elevators:savePoints', false, id, points) or false end)

    if ok then
        lib.notify({ title = L('notifications.floor_added'), description = floorName, type = 'success' })
        Wait(200)
        ManageFloors(id)
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- 🗑️ REMOVE FLOOR
-- ════════════════════════════════════════════════════════════════

function RemoveFloor(id, floorName)
    local confirm = lib.alertDialog({
        header  = ('Remove Floor: %s'):format(floorName),
        content = 'Are you sure? This cannot be undone.',
        centered = true,
        cancel   = true,
    })
    if confirm ~= 'confirm' then return end

    local elev   = Elevators[id]
    if not elev then return end
    local points = DeepCopy(elev.data or {})
    points[floorName] = nil

    local ok = false
    pcall(function() ok = lib.callback.await('rde_elevators:savePoints', false, id, points) or false end)

    if ok then
        lib.notify({ title = L('notifications.floor_removed'), description = floorName, type = 'success' })
        Wait(200)
        ManageFloors(id)
    else
        lib.notify({ title = L('notifications.error'), type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- 📊 STATS
-- ════════════════════════════════════════════════════════════════

function ViewStats(id)
    local stats = lib.callback.await('rde_elevators:getStats', false, id)
    if not stats then
        lib.notify({ title = 'Stats unavailable', type = 'error' })
        return
    end

    lib.registerContext({
        id      = 'rde_elevator_stats',
        title   = '📊 Elevator Statistics',
        menu    = 'rde_elevator_manage',
        options = {
            { title = '📈 Total Uses',      description = tostring(stats.total_uses),    icon = 'trending-up',   disabled = true },
            { title = '👥 Unique Users',     description = tostring(stats.unique_users),  icon = 'users',         disabled = true },
            { title = '⭐ Most Popular Floor',description = stats.most_popular or 'N/A',  icon = 'star',          disabled = true },
        },
    })
    lib.showContext('rde_elevator_stats')
end

-- ════════════════════════════════════════════════════════════════
-- 🗑️ DELETE ELEVATOR
-- ════════════════════════════════════════════════════════════════

function DeleteElevator(id)
    local elev = Elevators[id]
    if not elev then return end

    local confirm = lib.alertDialog({
        header  = ('🗑️ Delete: %s'):format(elev.label),
        content = 'This will permanently delete the elevator and ALL its floors. This cannot be undone!',
        centered = true,
        cancel   = true,
    })
    if confirm ~= 'confirm' then return end

    local ok, reason = false, nil
    pcall(function()
        ok, reason = lib.callback.await('rde_elevators:delete', false, id)
    end)

    if ok then
        lib.notify({ title = 'Elevator Deleted', description = elev.label, type = 'success' })
        Wait(300)
        OpenAdminMenu()
    else
        lib.notify({ title = L('notifications.error'), description = reason or '', type = 'error' })
    end
end

-- ════════════════════════════════════════════════════════════════
-- ⌨️ COMMAND
-- ════════════════════════════════════════════════════════════════

-- ✅ FIX (#6 v1.0.0-alpha): chat:addSuggestion was missing for all client commands
RegisterCommand('elevatoradmin', function()
    OpenAdminMenu()
end, false)
TriggerEvent('chat:addSuggestion', '/elevatoradmin', 'Open the RDE Elevator admin panel')

RegisterCommand('elevators', function()
    OpenAdminMenu()
end, false)
TriggerEvent('chat:addSuggestion', '/elevators', 'Open the RDE Elevator admin panel')

RDE_Debug('Admin panel v4.0 loaded!')
