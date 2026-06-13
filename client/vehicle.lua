--[[
    rde_elevators v1.5.0 — client/vehicle.lua
    Vehicle Elevator — Multiplayer Sync + Hardened Teleport + IPL Passenger Fix
    Red Dragon Elite | BFS v6.66

    v4.1 FIXES:
    ✅ Every teleport CreateThread is now guarded — sound failures, particle
       failures, or any other side-effect can NEVER prevent SetEntityCoords.
       Pre-v4.1, the broken sounds.lua nil-indexed Config.Sounds.DoorClose
       and crashed the thread BEFORE the teleport line ever executed.
    ✅ Fade-wait loops have a deadline (max 2 s) so a stuck fade never
       freezes the player.
    ✅ Vehicle teleport: removed clearArea=true on SetEntityCoords for ped
       to avoid spawning area-clear glitches.

    v1.5.0 FIX:
    ✅ IPL Passenger Interior Fix — GTA V's portal-culling system only
       activates the interior renderer when a ped physically crosses a portal
       boundary. Passengers placed into vehicles via SetPedIntoVehicle (or
       already seated when the driver enters an IPL interior) never cross a
       portal — interior is invisible in 3rd-person even though IPL geometry
       and collisions are fully loaded via bob74_ipl / RequestIpl().
       Fix: lib.onCache('vehicle') triggers a lightweight watcher that calls
       LoadInterior() + IsInteriorReady() when the vehicle enters a portal-
       based interior. Dynamic sleep: 750ms outside interior, 5000ms after
       activation. Thread self-terminates when player exits vehicle.
--]]

local _currentElevatorId = nil
local _currentFloorName  = nil

-- Pending state for arrival handler
local _pendingCam      = nil
local _pendingElevator = nil
local _pendingFloor    = nil

-- ─── HELPERS ───────────────────────────────────────────────────

local function SafePlay(fn)
    if type(fn) ~= 'function' then return end
    pcall(fn)
end

local function WaitForFadeOut(maxMs)
    local deadline = GetGameTimer() + (maxMs or 2000)
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(20) end
end

local function WaitForFadeIn(maxMs)
    local deadline = GetGameTimer() + (maxMs or 2000)
    while not IsScreenFadedIn() and GetGameTimer() < deadline do Wait(20) end
end

-- ─── VEHICLE VALIDATION ────────────────────────────────────────

local function CanVehicleUseElevator(vehicle)
    if not vehicle or vehicle == 0 then return false, 'no_vehicle' end

    local class = GetVehicleClass(vehicle)
    if not Config.Vehicle.AllowedClasses[class] then
        return false, 'vehicle_not_allowed'
    end

    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local length = max.y - min.y
    if length > Config.Vehicle.MaxVehicleLength then
        return false, 'vehicle_too_big'
    end

    return true
end

-- ─── MAIN ENTRY POINT ─────────────────────────────────────────

---@param elevator ElevatorEntry
---@param targetFloor string
---@param point table { x, y, z, w }
function TeleportToFloor(elevator, targetFloor, point)
    if not elevator or not targetFloor or not point then return end

    local ped       = cache.ped
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local vehicle   = inVehicle and GetVehiclePedIsIn(ped, false) or nil
    local doVehicle = inVehicle and elevator.vehicle_mode and Config.Vehicle.Enabled

    if _currentElevatorId then
        TriggerServerEvent('rde_elevators:leaveFloor')
    end

    if doVehicle then
        local canUse, reason = CanVehicleUseElevator(vehicle)
        if not canUse then
            local msg = reason == 'vehicle_too_big' and 'vehicle_too_big' or 'vehicle_not_allowed'
            lib.notify({
                title = L('notifications.' .. msg),
                description = L('notifications.' .. msg .. '_desc'),
                type = 'error',
            })
            return
        end
    end

    SetCooldown()
    TriggerServerEvent('rde_elevators:trackUsage', elevator.id, _currentFloorName, targetFloor)

    if doVehicle then
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        if not vehicleNetId or vehicleNetId == 0 then
            lib.notify({ title = L('notifications.error'), type = 'error' })
            return
        end

        if Config.Vehicle.CinematicMode then
            _DoCinematicThenServer(ped, vehicle, vehicleNetId, elevator, targetFloor, point)
        else
            _DoFadeThenServer(ped, vehicle, vehicleNetId, elevator, targetFloor, point)
        end
    else
        _DoStandardTeleport(ped, elevator, targetFloor, point)
    end
end

-- ─── CINEMATIC → SERVER ───────────────────────────────────────

function _DoCinematicThenServer(ped, vehicle, vehicleNetId, elevator, targetFloor, point)
    CreateThread(function()
        SafePlay(function()
            lib.notify({
                title = L('notifications.entering_garage'),
                description = L('notifications.entering_garage_desc'),
                type = 'info',
                duration = 2000,
            })
        end)
        SafePlay(PlayDoorCloseSound)

        FreezeEntityPosition(vehicle, true)
        Wait((Config.Vehicle.DoorAnimationTime or 2000) / 2)

        local fakeCam
        SafePlay(function()
            local camPos = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            fakeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamCoord(fakeCam, camPos.x, camPos.y, camPos.z)
            SetCamRot(fakeCam, camRot.x, camRot.y, camRot.z, 2)
            SetCamActive(fakeCam, true)
            RenderScriptCams(true, false, 0, true, true)
        end)

        if Config.Teleport.Particles.Enabled then SafePlay(function() TriggerParticleEffect(vehicle, true) end) end
        if Config.Teleport.CameraShake.Enabled then
            SafePlay(function() ShakeGameplayCam(Config.Teleport.CameraShake.Type, Config.Teleport.CameraShake.Intensity) end)
        end

        DoScreenFadeOut(Config.Teleport.FadeOut)
        WaitForFadeOut(2000)
        Wait(Config.Teleport.Hold)

        FreezeEntityPosition(vehicle, false)

        _pendingCam      = fakeCam
        _pendingElevator = elevator
        _pendingFloor    = targetFloor

        TriggerServerEvent('rde_elevators:vehicleTeleport', vehicleNetId, point, elevator.id, targetFloor)
    end)
end

-- ─── SIMPLE FADE → SERVER ──────────────────────────────────────

function _DoFadeThenServer(ped, vehicle, vehicleNetId, elevator, targetFloor, point)
    CreateThread(function()
        SafePlay(PlayDoorCloseSound)
        if Config.Teleport.Particles.Enabled then SafePlay(function() TriggerParticleEffect(vehicle, true) end) end

        DoScreenFadeOut(Config.Teleport.FadeOut)
        WaitForFadeOut(2000)
        Wait(Config.Teleport.Hold)

        _pendingCam      = nil
        _pendingElevator = elevator
        _pendingFloor    = targetFloor

        TriggerServerEvent('rde_elevators:vehicleTeleport', vehicleNetId, point, elevator.id, targetFloor)
    end)
end

-- ─── DRIVER: REPORTS OCCUPANTS ────────────────────────────────

RegisterNetEvent('rde_elevators:reportOccupants')
AddEventHandler('rde_elevators:reportOccupants', function(vehicleNetId, point, elevatorId, targetFloor)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return end

    local occupants = {}
    local maxSeats  = GetVehicleMaxNumberOfPassengers(vehicle)

    for seat = -1, maxSeats - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 and ped ~= cache.ped then
            for _, pid in ipairs(GetActivePlayers()) do
                if GetPlayerPed(pid) == ped then
                    local serverId = GetPlayerServerId(pid)
                    if serverId and serverId ~= 0 then
                        occupants[tostring(seat)] = serverId
                    end
                    break
                end
            end
        end
    end

    TriggerServerEvent('rde_elevators:syncOccupants', occupants, vehicleNetId, point, elevatorId, targetFloor)
    RDE_Debug(('[Vehicle] Reported %d occupants to server'):format(TableCount(occupants)))
end)

-- ─── DRIVER: TELEPORT EXECUTION ───────────────────────────────

RegisterNetEvent('rde_elevators:doVehicleTeleport')
AddEventHandler('rde_elevators:doVehicleTeleport', function(vehicleNetId, point)
    local cap_netId    = vehicleNetId
    local cap_point    = point
    local cap_cam      = _pendingCam
    local cap_elevator = _pendingElevator
    local cap_floor    = _pendingFloor
    _pendingCam      = nil
    _pendingElevator = nil
    _pendingFloor    = nil

    CreateThread(function()
        local vehicle = NetworkGetEntityFromNetworkId(cap_netId)
        if not vehicle or vehicle == 0 then return end

        local spawnZ = cap_point.z + (Config.Vehicle.SpawnZOffset or 0.5)
        SetEntityCoords(vehicle, cap_point.x, cap_point.y, spawnZ, false, false, false, true)
        SetEntityHeading(vehicle, cap_point.w or 0.0)

        Wait(150)

        _DoArrivalSequence(vehicle, cap_elevator, cap_floor, cap_cam)
    end)
end)

-- ─── PASSENGER: SYNC ──────────────────────────────────────────

RegisterNetEvent('rde_elevators:passengerSync')
AddEventHandler('rde_elevators:passengerSync', function(vehicleNetId, seat, point)
    CreateThread(function()
        DoScreenFadeOut(Config.Teleport.FadeOut)
        WaitForFadeOut(2000)

        local vehicle  = NetworkGetEntityFromNetworkId(vehicleNetId)
        local target   = vec3(point.x, point.y, point.z + (Config.Vehicle.SpawnZOffset or 0.5))
        local deadline = GetGameTimer() + 3000

        while GetGameTimer() < deadline do
            vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                if #(GetEntityCoords(vehicle) - target) < 5.0 then break end
            end
            Wait(100)
        end

        local ped = cache.ped
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            SetPedIntoVehicle(ped, vehicle, seat)
        end

        -- ✅ FIX (#10 v1.0.0-alpha): Direct coord teleport to an IPL interior
        -- doesn't update GTA V's interior rendering context for passengers.
        --
        -- ✅ FIX (#12 v1.5.1): GetInteriorAtCoords at the garage floor point
        -- returns 0 for mansion/garage IPLs because the portal trigger boundary
        -- sits ~1 unit above the floor. bob74_ipl also only calls RefreshInterior()
        -- on init — never LoadInterior() — so the passenger's rendering context
        -- is never activated on teleport. Fix: cascade Z+1.0 → Z → target to
        -- reliably hit the portal boundary, then call RefreshInterior() after
        -- IsInteriorReady() to fully re-activate interior props/styles.
        RequestCollisionAtCoord(target.x, target.y, target.z)

        Wait(150)  -- let vehicle entity position settle on this client
        local vc       = GetEntityCoords(vehicle)
        local interior = GetInteriorAtCoords(vc.x, vc.y, vc.z + 1.0)
        if interior == 0 then interior = GetInteriorAtCoords(vc.x, vc.y, vc.z) end
        if interior == 0 then interior = GetInteriorAtCoords(target.x, target.y, target.z) end

        if interior ~= 0 then
            LoadInterior(interior)
            local intDeadline = GetGameTimer() + 4000
            while not IsInteriorReady(interior) and GetGameTimer() < intDeadline do
                Wait(100)
            end
            RefreshInterior(interior)  -- re-activate bob74_ipl interior props/styles
            RDE_Debug('[Vehicle] Passenger interior activated, id:', interior)
        else
            -- Open-world IPL (no portal ID): wait for collision + force streaming focus
            local colDeadline = GetGameTimer() + 3000
            while not HasCollisionLoadedAroundEntity(vehicle) and GetGameTimer() < colDeadline do
                Wait(50)
            end
            SetFocusPosAndVel(vc.x, vc.y, vc.z, 0.0, 0.0, 0.0)
            Wait(1000)
            ClearFocus()
        end

        Wait(200)
        DoScreenFadeIn(Config.Teleport.FadeIn)
        WaitForFadeIn(2000)

        SafePlay(PlayElevatorDing)
        RDE_Debug('[Vehicle] Passenger sync complete, seat:', seat)
    end)
end)

-- ─── FLOOR REGISTRATION ───────────────────────────────────────

RegisterNetEvent('rde_elevators:registerFloor')
AddEventHandler('rde_elevators:registerFloor', function(elevatorId, floorName)
    _currentElevatorId = elevatorId
    _currentFloorName  = floorName
    TriggerServerEvent('rde_elevators:setPlayerFloor', elevatorId, floorName)
    RDE_Debug('[Floor] Registered on elevator', elevatorId, 'floor', floorName)
end)

-- ─── ARRIVAL SEQUENCE (driver only) ───────────────────────────

function _DoArrivalSequence(vehicle, elevator, targetFloor, fakeCam)
    if Config.Teleport.Particles.Enabled then
        Wait(200)
        SafePlay(function() TriggerParticleEffect(vehicle, false) end)
    end

    if fakeCam then
        SafePlay(function()
            RenderScriptCams(false, false, 0, true, true)
            SetCamActive(fakeCam, false)
            DestroyCam(fakeCam, false)
        end)
    end

    DoScreenFadeIn(Config.Teleport.FadeIn)
    WaitForFadeIn(2000)

    SafePlay(PlayElevatorDing)
    if Config.Vehicle.UseParkingSound then SafePlay(PlayParkingSound) end

    SafePlay(function()
        lib.notify({
            title = L('notifications.leaving_garage'),
            description = L('notifications.leaving_garage_desc'),
            type = 'success',
            duration = 2000,
        })
    end)

    if elevator and targetFloor then
        _RegisterPlayerFloor(elevator.id, targetFloor)
    end

    RDE_Debug('[Vehicle] Teleport completed →', targetFloor)
end

-- ─── STANDARD PED TELEPORT ────────────────────────────────────

function _DoStandardTeleport(ped, elevator, targetFloor, point)
    CreateThread(function()
        SafePlay(PlayDoorCloseSound)
        if Config.Teleport.CameraShake.Enabled then
            SafePlay(function() ShakeGameplayCam(Config.Teleport.CameraShake.Type, Config.Teleport.CameraShake.Intensity) end)
        end

        DoScreenFadeOut(Config.Teleport.FadeOut)
        WaitForFadeOut(2000)

        FreezeEntityPosition(ped, true)
        RequestCollisionAtCoord(point.x, point.y, point.z)
        local colDeadline = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colDeadline do
            Wait(50)
        end

        Wait(Config.Teleport.Hold)

        SetEntityCoords(ped, point.x, point.y, point.z, false, false, false, false)
        SetEntityHeading(ped, point.w or 0.0)
        FreezeEntityPosition(ped, false)
        Wait(50)

        DoScreenFadeIn(Config.Teleport.FadeIn)
        WaitForFadeIn(2000)

        SafePlay(PlayElevatorDing)
        _RegisterPlayerFloor(elevator.id, targetFloor)
        RDE_Debug('[Teleport] Standard ped teleport →', targetFloor)
    end)
end

-- ─── FLOOR REGISTRATION ───────────────────────────────────────

function _RegisterPlayerFloor(elevatorId, floorName)
    _currentElevatorId = elevatorId
    _currentFloorName  = floorName
    TriggerServerEvent('rde_elevators:setPlayerFloor', elevatorId, floorName)
    SafePlay(function()
        lib.notify({
            title = L('notifications.arrived'),
            description = L('notifications.arrived_desc', floorName),
            type = 'success',
            duration = 2500,
        })
    end)
    RDE_Debug('[Floor] Registered on elevator', elevatorId, 'floor', floorName)
end

-- ─── PARTICLE HELPER ──────────────────────────────────────────

function TriggerParticleEffect(entity, isDeparture)
    if not Config.Teleport.Particles.Enabled then return end
    CreateThread(function()
        pcall(function()
            local coords = GetEntityCoords(entity)
            RequestNamedPtfxAsset(Config.Teleport.Particles.Effect)
            local timeout = GetGameTimer() + 3000
            while not HasNamedPtfxAssetLoaded(Config.Teleport.Particles.Effect) and GetGameTimer() < timeout do
                Wait(10)
            end
            if not HasNamedPtfxAssetLoaded(Config.Teleport.Particles.Effect) then return end

            UseParticleFxAsset(Config.Teleport.Particles.Effect)
            local particle = StartParticleFxLoopedAtCoord(
                Config.Teleport.Particles.Name,
                coords.x, coords.y, coords.z,
                0.0, 0.0, 0.0,
                Config.Teleport.Particles.Scale,
                false, false, false, false
            )
            Wait(Config.Teleport.Particles.Duration)
            StopParticleFxLooped(particle, 0)
            RemoveNamedPtfxAsset(Config.Teleport.Particles.Effect)
        end)
    end)
end

-- ─── IPL PASSENGER INTERIOR FIX (v1.5.0) ─────────────────────
-- Root cause: GTA V's portal-culling system only activates the interior
-- rendering context when a ped physically crosses a portal boundary.
-- Passengers placed into vehicles via SetPedIntoVehicle — or already seated
-- when the driver enters a bob74_ipl/RequestIpl() interior — never cross a
-- portal. Result: interior is invisible in 3rd-person (collisions present,
-- first-person works). This fix is complementary to Fix #10 in passengerSync
-- which handles the elevator-teleport case. This watcher catches the general
-- "drive in as passenger" case.
--
-- Approach:
--   • lib.onCache('vehicle') is event-driven — zero overhead when not in a
--     vehicle. Only starts the watcher when the local player enters a vehicle
--     as a passenger.
--   • Dynamic sleep: 750ms while outside (to catch the interior entry moment),
--     5000ms after activation (interior won't change frequently once inside).
--   • Token pattern: stale threads from rapid vehicle switches self-terminate.
--   • Thread self-terminates when player exits vehicle or becomes driver.

local _ipl_token         = nil   -- unique table ref per session
local _ipl_last_interior = 0

local function _StopIplWatcher()
    _ipl_token         = nil
    _ipl_last_interior = 0
end

local function _StartIplWatcher(vehicle)
    local token = {}            -- new unique table = new identity
    _ipl_token         = token
    _ipl_last_interior = 0

    CreateThread(function()
        local activated = false  -- true once LoadInterior() succeeded

        while _ipl_token == token do
            Wait(activated and 5000 or 750)
            -- ↑ 5000ms once interior is active (vehicle won't jump interiors
            --   frequently; only need to detect exit + re-entry in same session)
            -- ↑ 750ms otherwise (catch the moment driver enters an IPL interior)

            -- Self-terminate conditions
            if not DoesEntityExist(vehicle)
            or GetPedInVehicleSeat(vehicle, -1) == cache.ped then
                if _ipl_token == token then _ipl_token = nil end
                return
            end

            local coords   = GetEntityCoords(vehicle)
            -- Z+1.0 cascade: portal trigger boundary sits ~1 unit above the floor.
            -- Garage/mansion IPLs return 0 at floor level but non-zero at Z+1.0.
            local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z + 1.0)
            if interior == 0 then interior = GetInteriorAtCoords(coords.x, coords.y, coords.z) end

            if interior ~= 0 and interior ~= _ipl_last_interior then
                -- New portal-based interior detected — activate rendering context.
                -- Inner thread: LoadInterior + IsInteriorReady can block up to 5s.
                -- Keep outer watcher alive and responsive during that wait.
                _ipl_last_interior = interior   -- set before inner thread (no re-trigger)
                activated          = true
                local cap_interior = interior
                CreateThread(function()
                    LoadInterior(cap_interior)
                    local deadline = GetGameTimer() + 5000
                    while not IsInteriorReady(cap_interior) and GetGameTimer() < deadline do
                        Wait(100)
                    end
                    RefreshInterior(cap_interior)
                    RDE_Debug('[IPL] Passenger interior context activated, id:', cap_interior)
                end)

            elseif interior == 0 and activated then
                -- Left the interior — reset so next entry re-triggers LoadInterior
                activated          = false
                _ipl_last_interior = 0
            end
        end
    end)
end

-- Event-driven entry point — fires whenever local player's vehicle state changes
lib.onCache('vehicle', function(vehicle)
    _StopIplWatcher()
    if not vehicle or vehicle == 0 then return end  -- left vehicle

    -- SetTimeout: seat assignment needs ~1 frame to settle after entering.
    -- 250ms is enough on any hardware without being noticeable.
    SetTimeout(250, function()
        if cache.vehicle ~= vehicle then return end              -- already left again
        if GetPedInVehicleSeat(vehicle, -1) == cache.ped then return end  -- is driver
        _StartIplWatcher(vehicle)
        RDE_Debug('[IPL] Passenger watcher started for vehicle:', vehicle)
    end)
end)

-- ─── EXPORTS ──────────────────────────────────────────────────

exports('TeleportToFloor', TeleportToFloor)
exports('GetCurrentFloor', function() return _currentFloorName, _currentElevatorId end)
