--[[
    rde_elevators v4.1 — client/main.lua
    Core: StateBag listener, elevator targets, floor navigation
    Red Dragon Elite | BFS v6.66

    v4.1 FIXES:
    ✅ Per-ID statebag handler (Config.StateBags.DataPrefix .. id) replaces
       the old full-cache handler. Reacts to ONE elevator at a time.
    ✅ pcall around every ox_target add/remove (Standards requirement).
    ✅ elevatorDeleted handler no longer double-removes zones.
    ✅ Initial load: single canonical path via lib.callback.await('getAll').
       StateBag deltas only mutate after init is complete (race-safe).
    ✅ Per-elevator rebuild — only the changed elevator's zones/blips are
       rebuilt, not the whole world (less flicker, less ox_target churn).
--]]

---@type table<integer, ElevatorEntry>
Elevators = {}

local ActiveZones = {}    -- zoneName → true
local Blips       = {}    -- id → { floorName → blip handle }
local LastUseTime = 0
local _initDone   = false  -- guards StateBag deltas until initial load completes

-- Locale
Locale = {}
local CurrentLanguage = Config.DefaultLanguage

-- ─── LOCALE ───────────────────────────────────────────────────

CreateThread(function()
    local file = ('locales/%s.json'):format(CurrentLanguage)
    local content = LoadResourceFile(GetCurrentResourceName(), file)
    if content then
        Locale = json.decode(content) or {}
    else
        RDE_Error('[Locale] Failed to load:', file)
        Locale = {}
    end
end)

function L(path, ...)
    local keys, value = {}, Locale
    for k in path:gmatch('[^.]+') do keys[#keys+1] = k end
    for _, k in ipairs(keys) do
        if type(value) == 'table' then value = value[k]
        else return path end
    end
    if type(value) == 'string' and select('#', ...) > 0 then
        return value:format(...)
    end
    return value or path
end

-- ─── ADMIN CHECK ──────────────────────────────────────────────

function IsLocalPlayerAdmin()
    local groups = cache and cache.groups or {}
    for group in pairs(groups) do
        if group == 'admin' or group == 'superadmin' or group == 'god' or
           group == 'management' or group == 'owner' then
            return true
        end
    end
    return false
end

-- ─── COOLDOWN ─────────────────────────────────────────────────

function IsOnCooldown()
    if not Config.Cooldown.Enabled then return false end
    if Config.Cooldown.AdminBypass and IsLocalPlayerAdmin() then return false end
    local now = GetGameTimer()
    if (now - LastUseTime) < Config.Cooldown.Duration then
        return true, math.ceil((Config.Cooldown.Duration - (now - LastUseTime)) / 1000)
    end
    return false
end

function SetCooldown()
    LastUseTime = GetGameTimer()
end

-- ─── ZONE HELPERS ─────────────────────────────────────────────

local function GetZoneName(elevatorId, floorName)
    return ('rde_elev_%s_%s'):format(elevatorId, floorName)
end

local function SafeRemoveZone(zoneName)
    if not ActiveZones[zoneName] then return end
    pcall(function() exports.ox_target:removeZone(zoneName) end)
    ActiveZones[zoneName] = nil
end

local function RemoveElevatorZones(id, elevator)
    elevator = elevator or Elevators[id]
    if not elevator or not elevator.data then return end
    for floorName in pairs(elevator.data) do
        SafeRemoveZone(GetZoneName(id, floorName))
    end
end

local function RemoveElevatorBlips(id)
    if not Blips[id] then return end
    for _, handle in pairs(Blips[id]) do
        if DoesBlipExist(handle) then RemoveBlip(handle) end
    end
    Blips[id] = nil
end

-- ─── BUILD A SINGLE ELEVATOR'S ZONES ──────────────────────────

local function BuildElevatorZones(id, elevator)
    if not elevator or not elevator.data then return end

    local isEnabled = elevator.enabled ~= false
    local mainKey   = Config.StateBags.Maintenance .. ':' .. id
    local inMaint   = GlobalState[mainKey] or false

    for floorName, floorData in pairs(elevator.data) do
        local point    = floorData.point or floorData
        local zoneName = GetZoneName(id, floorName)

        -- Icon based on state
        local icon = Config.Target.Icon
        if not isEnabled then       icon = 'ban'
        elseif inMaint then         icon = 'triangle-alert'
        elseif elevator.vehicle_mode then icon = 'car'
        end

        local label = ('%s — %s'):format(elevator.label, floorName)
        if not isEnabled then label = label .. ' [OFFLINE]'
        elseif inMaint then   label = label .. ' [MAINTENANCE]' end

        local ok = pcall(function()
            exports.ox_target:addBoxZone({
                name     = zoneName,
                coords   = vec3(point.x, point.y, point.z),
                size     = Config.Target.Size,
                rotation = point.w or 0.0,
                debug    = Config.Target.Debug,
                options  = {
                    {
                        name     = zoneName,
                        icon     = icon,
                        label    = label,
                        distance = Config.Target.Distance,
                        onSelect = function()
                            if not isEnabled then
                                lib.notify({
                                    title = L('notifications.elevator_disabled'),
                                    description = L('notifications.elevator_disabled_desc'),
                                    type = 'error',
                                })
                                return
                            end
                            OpenElevatorMenu(id, floorName)
                        end,
                    }
                },
            })
        end)
        if ok then ActiveZones[zoneName] = true end
    end
end

-- ─── BUILD A SINGLE ELEVATOR'S BLIPS ──────────────────────────

local function BuildElevatorBlips(id, elevator)
    if not Config.Blips.Enabled or not elevator or not elevator.data then return end

    -- ✅ FIX (v4.1.1): Per-elevator blip visibility toggle. Allows admins to
    -- hide an elevator from the minimap entirely (e.g. secret elevators,
    -- garage entrances that would clutter the map for every player).
    -- Default true when the field is missing (back-compat for old data).
    local blipCfg = elevator.blip or {}
    if blipCfg.enabled == false then
        RemoveElevatorBlips(id)
        return
    end

    Blips[id] = Blips[id] or {}
    local isEnabled = elevator.enabled ~= false
    local mainKey   = Config.StateBags.Maintenance .. ':' .. id
    local inMaint   = GlobalState[mainKey] or false

    local sprite  = blipCfg.sprite or Config.Blips.Sprite
    local scale   = blipCfg.scale  or Config.Blips.Scale

    local color
    if inMaint then               color = Config.Blips.StateColors.maintenance
    elseif not isEnabled then     color = Config.Blips.StateColors.disabled
    elseif elevator.vehicle_mode then color = Config.Blips.StateColors.vehicle
    else color = blipCfg.color or Config.Blips.StateColors.enabled
    end

    local blipLabel = blipCfg.label or elevator.label

    local function MakeBlip(point, label)
        local blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipSprite(blip, sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, scale)
        SetBlipColour(blip, color)
        SetBlipAsShortRange(blip, true)
        if not isEnabled then SetBlipAlpha(blip, 128) end
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)
        return blip
    end

    if Config.Blips.ShowAllFloors then
        for floorName, floorData in pairs(elevator.data) do
            local point = floorData.point or floorData
            local label = ('%s - %s'):format(blipLabel, floorName)
            Blips[id][floorName] = MakeBlip(point, label)
        end
    else
        for floorName, floorData in pairs(elevator.data) do
            local point = floorData.point or floorData
            Blips[id][floorName] = MakeBlip(point, blipLabel)
            break  -- only first floor
        end
    end
end

-- ─── FULL REBUILD (used on initial load + global state changes) ────

function RebuildTargets()
    for zoneName in pairs(ActiveZones) do
        pcall(function() exports.ox_target:removeZone(zoneName) end)
    end
    ActiveZones = {}

    for id, elevator in pairs(Elevators) do
        BuildElevatorZones(id, elevator)
    end

    RDE_Debug('[Targets] Registered', TableCount(ActiveZones), 'zones')
end

function RebuildBlips()
    for id in pairs(Blips) do RemoveElevatorBlips(id) end
    Blips = {}
    if not Config.Blips.Enabled then return end
    for id, elevator in pairs(Elevators) do
        BuildElevatorBlips(id, elevator)
    end
end

-- ─── PER-ELEVATOR REBUILD (used on incremental updates) ────────

local function RebuildOneElevator(id)
    local elevator = Elevators[id]
    if not elevator then return end
    RemoveElevatorZones(id, elevator)
    RemoveElevatorBlips(id)
    BuildElevatorZones(id, elevator)
    BuildElevatorBlips(id, elevator)
end

-- ─── INCOMING SYNC EVENTS ──────────────────────────────────────
-- Single sync path from server: per-ID events fired by UpdateStatebag()
-- on the server. We also keep a StateBag handler as a redundancy net
-- for late-joiners and resource restarts.

RegisterNetEvent('rde_elevators:statebagUpdate')
AddEventHandler('rde_elevators:statebagUpdate', function(id, data)
    if not id or not data then return end
    if not _initDone then return end  -- ignore until initial load is done
    Elevators[id] = data
    RebuildOneElevator(id)
    RDE_Debug('[Sync] Update elevator', id)
end)

RegisterNetEvent('rde_elevators:statebagDelete')
AddEventHandler('rde_elevators:statebagDelete', function(id)
    if not id then return end
    if not _initDone then return end
    RemoveElevatorZones(id)
    RemoveElevatorBlips(id)
    Elevators[id] = nil
    RDE_Debug('[Sync] Delete elevator', id)
end)

-- ✅ FIX (#9 v1.0.0-alpha): AddStateBagChangeHandler keyFilter is EXACT-MATCH
-- only (RDE OX Standards Anti-Pattern #2 — same bug as rde_crew). The old
-- handler watched Config.StateBags.DataPrefix as the key, which never matches
-- the actual per-ID keys (DataPrefix .. "42" etc.). Safety net was dead code.
-- Fix: use nil keyFilter + pattern-match inside, scoped to 'global' bag only.
AddStateBagChangeHandler(nil, 'global', function(bagName, key, value)
    if not _initDone then return end
    -- Only care about per-elevator data keys (DataPrefix .. numeric id)
    local escapedPrefix = Config.StateBags.DataPrefix:gsub('([%-%.%+%*%?%^%$%(%)%%])', '%%%1')
    local id = tonumber(key and key:match(escapedPrefix .. '(%d+)$'))
    if not id then return end

    if not value or value._deleted then
        RemoveElevatorZones(id)
        RemoveElevatorBlips(id)
        Elevators[id] = nil
    else
        Elevators[id] = value
        RebuildOneElevator(id)
    end
end)

-- ─── LEGACY BROADCAST EVENT (kept for compatibility) ──────────
-- Old admin.lua code may still trigger these names directly. They just
-- route through the same sync logic now.

RegisterNetEvent('rde_elevators:elevatorCreated', function(id, elevator)
    if not id or not elevator or not _initDone then return end
    Elevators[id] = elevator
    RebuildOneElevator(id)
end)

RegisterNetEvent('rde_elevators:elevatorUpdated', function(id, elevator)
    if not id or not elevator or not _initDone then return end
    Elevators[id] = elevator
    RebuildOneElevator(id)
end)

RegisterNetEvent('rde_elevators:elevatorDeleted', function(id)
    if not id or not _initDone then return end
    RemoveElevatorZones(id)
    RemoveElevatorBlips(id)
    Elevators[id] = nil
end)

RegisterNetEvent('rde_elevators:onSync', function()
    local latest = lib.callback.await('rde_elevators:getAll', false) or {}
    Elevators = latest
    RebuildTargets()
    RebuildBlips()
end)

-- ─── INITIAL LOAD (single canonical path) ─────────────────────

CreateThread(function()
    while not cache.ped do Wait(100) end

    -- Always pull authoritative state via callback. The full-cache GlobalState
    -- is a fallback only if the callback fails.
    local latest = lib.callback.await('rde_elevators:getAll', false)
    if not latest or TableCount(latest) == 0 then
        latest = GlobalState[Config.StateBags.ElevatorData] or {}
    end

    Elevators = latest or {}

    -- ✅ FIX (#8 v1.0.0-alpha): Race condition — if the server was still
    -- running its init DB queries when this callback fired, both getAll
    -- and the GlobalState fallback return empty. We get _initDone = true
    -- with zero elevators and zones never rebuild.
    -- Fix: if we got nothing, wait 3s and retry once. The server's
    -- ox:playerLoaded hook will also trigger an onSync from server side,
    -- so one of the two will succeed.
    if TableCount(Elevators) == 0 then
        RDE_Debug('[Init] Got 0 elevators — server may still be loading, retrying in 3s...')
        Wait(3000)
        local retry = lib.callback.await('rde_elevators:getAll', false)
        if retry and TableCount(retry) > 0 then
            Elevators = retry
            RDE_Debug('[Init] Retry succeeded')
        else
            -- Last resort: GlobalState may be populated by now
            local gs = GlobalState[Config.StateBags.ElevatorData]
            if gs and TableCount(gs) > 0 then
                Elevators = gs
                RDE_Debug('[Init] Retry via GlobalState fallback')
            end
        end
    end

    RebuildTargets()
    RebuildBlips()

    _initDone = true
    RDE_Info('[Init] Loaded', TableCount(Elevators), 'elevators')
end)

-- ─── ELEVATOR MENU ────────────────────────────────────────────

function OpenElevatorMenu(elevatorId, currentFloor)
    local elevator = Elevators[elevatorId]
    if not elevator then return end

    if elevator.enabled == false then
        lib.notify({ title = L('notifications.elevator_disabled'), description = L('notifications.elevator_disabled_desc'), type = 'error' })
        return
    end

    local mainKey = Config.StateBags.Maintenance .. ':' .. elevatorId
    local inMaint = GlobalState[mainKey]
    if inMaint and not IsLocalPlayerAdmin() then
        lib.notify({ title = L('notifications.maintenance_mode'), description = L('notifications.maintenance_mode_desc'), type = 'error' })
        return
    end

    local onCD, remaining = IsOnCooldown()
    if onCD then
        lib.notify({ title = L('notifications.cooldown'), description = L('notifications.cooldown_desc', remaining), type = 'warning' })
        return
    end

    local occupiedKey  = Config.StateBags.FloorOccupied .. ':' .. elevatorId
    local occupiedData = GlobalState[occupiedKey] or {}
    local options = {}

    for floorName, floorData in pairs(elevator.data) do
        if floorName ~= currentFloor then
            local point         = floorData.point or floorData
            local restrictions  = floorData.restrictions
            local occupiedCount = occupiedData[floorName] or 0
            -- Client-side access check — uses ox_lib cache, NOT broken source=0 path
            local canAccess, _ = Permissions.CanAccessFloor(0, restrictions)
            local meta = {}

            if occupiedCount > 0 then
                meta[#meta+1] = { label = L('elevator.occupied'), value = L('elevator.players', occupiedCount), color = 'yellow' }
            end
            if elevator.vehicle_mode then
                meta[#meta+1] = { label = 'Mode', value = L('elevator.vehicle_ok'), color = 'blue' }
            end
            if restrictions then
                if restrictions.vip then
                    meta[#meta+1] = { label = 'Access', value = L('elevator.vip_only'), color = canAccess and 'green' or 'red' }
                end
                if restrictions.job then
                    meta[#meta+1] = { label = 'Access', value = L('elevator.job_required'), color = canAccess and 'green' or 'red' }
                end
            end
            if inMaint then
                meta[#meta+1] = { label = 'Status', value = L('elevator.maintenance'), color = 'orange' }
            end

            local floorIcon = 'arrow-up'
            if elevator.vehicle_mode then floorIcon = 'car' end
            if restrictions and restrictions.vip then floorIcon = 'star' end
            if restrictions and restrictions.job == 'police' then floorIcon = 'shield' end

            options[#options+1] = {
                title       = floorName,
                description = L('elevator.travel_to', floorName),
                icon        = floorIcon,
                metadata    = meta,
                disabled    = not canAccess or (inMaint and not IsLocalPlayerAdmin()),
                onSelect    = function()
                    if canAccess and not (inMaint and not IsLocalPlayerAdmin()) then
                        TeleportToFloor(elevator, floorName, point)
                    else
                        lib.notify({ title = L('notifications.access_denied'), description = L('notifications.access_denied_desc'), type = 'error' })
                    end
                end,
            }
        end
    end

    if #options == 0 then
        lib.notify({ title = elevator.label, description = L('elevator.no_floors'), type = 'inform' })
        return
    end

    lib.registerContext({
        id      = 'rde_elevator_menu',
        title   = L('elevator.menu_title', elevator.label, currentFloor),
        options = options,
    })
    lib.showContext('rde_elevator_menu')
end

-- ─── ADMIN-COMMAND TELEPORT (server-driven) ───────────────────

RegisterNetEvent('rde_elevators:teleportToElevator')
AddEventHandler('rde_elevators:teleportToElevator', function(point)
    if not point then return end
    CreateThread(function()
        local ped = cache.ped  -- ✅ FIX (#3 v1.0.0-alpha): cache.ped not PlayerPedId()
        DoScreenFadeOut(Config.Teleport.FadeOut)
        local deadline = GetGameTimer() + 2000
        while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(20) end

        -- ✅ FIX (#7 v1.0.0-alpha): load collision at destination before placing
        -- ped — same fix as _DoStandardTeleport (prevents Z-snap to roof)
        FreezeEntityPosition(ped, true)
        RequestCollisionAtCoord(point.x, point.y, point.z)
        local colDeadline = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colDeadline do
            Wait(50)
        end

        SetEntityCoords(ped, point.x, point.y, point.z, false, false, false, false)
        if point.w then SetEntityHeading(ped, point.w) end
        FreezeEntityPosition(ped, false)
        Wait(Config.Teleport.Hold)
        DoScreenFadeIn(Config.Teleport.FadeIn)
    end)
end)

-- ─── CLEANUP ON RESOURCE STOP ─────────────────────────────────

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for zoneName in pairs(ActiveZones) do
        pcall(function() exports.ox_target:removeZone(zoneName) end)
    end
    ActiveZones = {}
    for id in pairs(Blips) do RemoveElevatorBlips(id) end
    Blips = {}
end)

-- ─── EXPORTS ──────────────────────────────────────────────────

exports('OpenElevatorMenu', OpenElevatorMenu)
exports('GetElevators',     function() return Elevators end)
exports('IsOnCooldown',     IsOnCooldown)
exports('RebuildBlips',     RebuildBlips)
exports('RebuildTargets',   RebuildTargets)
