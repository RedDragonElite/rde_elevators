--[[
    rde_elevators v4.1 — client/effects.lua
    Visual Effects & Cinematic Camera System
    Red Dragon Elite | BFS v6.66

    v4.1 FIXES:
    ✅ 3D-Text proximity loop no longer drops to Wait(0). Standards banned
       Wait(0) loops because they spin at 60+ FPS and cost real performance.
       Now: 5 ms minimum when very close, 1000 ms when far away.
    ✅ Scaleform / particle wait loops have a hard timeout — no more chance
       of infinite Wait(0) if an asset never loads.
--]]

-- ─── 3D TEXT MARKERS ───────────────────────────────────────────

local Show3DText = Config.UI.Show3DText

CreateThread(function()
    if not Show3DText then return end

    while true do
        local sleep = 1000
        local ped = cache.ped  -- ✅ FIX (#3 v1.0.0-alpha): cache.ped not PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        for _, elevator in pairs(Elevators or {}) do
            if elevator.data then
                for floorName, floorData in pairs(elevator.data) do
                    local point = floorData.point or floorData
                    local coords = vector3(point.x, point.y, point.z)
                    local dist = #(playerCoords - coords)

                    if dist < 10.0 then
                        sleep = 5  -- v4.1: was 0 (banned by Standards)
                        if dist < 2.0 then
                            Draw3DText(
                                point.x, point.y, point.z + 1.5,
                                ('[%s]\n%s'):format(elevator.label, floorName),
                                0.35
                            )
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

function Draw3DText(x, y, z, text, scale)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- ─── SCREEN EFFECTS ────────────────────────────────────────────

function TriggerScreenFlash(duration)
    duration = duration or 500
    CreateThread(function()
        local scaleform = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
        local timeout = GetGameTimer() + 3000
        while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < timeout do Wait(10) end
        if not HasScaleformMovieLoaded(scaleform) then return end

        BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE')
        PushScaleformMovieMethodParameterString('Elevator')
        PushScaleformMovieMethodParameterString('Traveling...')
        PushScaleformMovieMethodParameterInt(5)
        EndScaleformMovieMethod()

        local startTime = GetGameTimer()
        while (GetGameTimer() - startTime) < duration do
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)  -- this loop MUST be per-frame to draw the scaleform
        end

        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end)
end

-- ─── LIGHT EFFECTS ─────────────────────────────────────────────

function CreateElevatorLight(coords, color, intensity, range, duration)
    CreateThread(function()
        local light = CreateLight({
            coords = coords,
            color = color or { r = 0, g = 255, b = 136 },
            intensity = intensity or 2.0,
            range = range or 5.0,
        })
        if duration then
            Wait(duration)
            RemoveLight(light)
        end
    end)
end

-- ─── CAMERA EFFECTS ────────────────────────────────────────────

function ShakeCamera(intensity, duration)
    if not Config.Teleport.CameraShake.Enabled then return end
    intensity = intensity or Config.Teleport.CameraShake.Intensity
    duration  = duration  or Config.Teleport.CameraShake.Duration

    ShakeGameplayCam(Config.Teleport.CameraShake.Type, intensity)
    CreateThread(function()
        Wait(duration)
        StopGameplayCamShaking(true)
    end)
end

-- ─── CINEMATIC TRANSITIONS ─────────────────────────────────────

function DoCinematicTransition(fromCoords, toCoords, duration)
    duration = duration or 3000
    CreateThread(function()
        local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(cam, fromCoords.x, fromCoords.y, fromCoords.z + 2.0)
        PointCamAtCoord(cam, toCoords.x, toCoords.y, toCoords.z)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, duration, true, true)
        SetCamCoord(cam, toCoords.x, toCoords.y, toCoords.z + 2.0)
        Wait(duration)
        RenderScriptCams(false, true, duration, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    end)
end

-- ─── LOADING SCREEN EFFECT ─────────────────────────────────────

local LoadingActive = false

function ShowElevatorLoading(message, duration)
    if LoadingActive then return end
    LoadingActive = true
    message  = message  or 'Traveling...'
    duration = duration or 2000

    CreateThread(function()
        SendNUIMessage({ action = 'showLoading', message = message, duration = duration })
        Wait(duration)
        SendNUIMessage({ action = 'hideLoading' })
        LoadingActive = false
    end)
end

-- ─── FLOOR INDICATOR HUD ───────────────────────────────────────

local ShowingFloorIndicator = false

function ShowFloorIndicator(floorName, duration)
    if ShowingFloorIndicator then return end
    ShowingFloorIndicator = true
    duration = duration or 3000

    CreateThread(function()
        SendNUIMessage({ action = 'showFloorIndicator', floor = floorName, duration = duration })
        Wait(duration)
        SendNUIMessage({ action = 'hideFloorIndicator' })
        ShowingFloorIndicator = false
    end)
end

-- ─── AMBIENT EFFECTS ───────────────────────────────────────────

function TriggerElevatorAmbience(coords, duration)
    duration = duration or 5000

    CreateThread(function()
        if not Config.Teleport.Particles.Enabled then return end
        pcall(function()
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

            Wait(duration)

            StopParticleFxLooped(particle, 0)
            RemoveNamedPtfxAsset(Config.Teleport.Particles.Effect)
        end)
    end)
end

-- ─── POST-PROCESSING ───────────────────────────────────────────

function ApplyTeleportFilter(duration)
    duration = duration or 1000
    CreateThread(function()
        SetTimecycleModifier('NG_filmic19')
        SetTimecycleModifierStrength(0.5)
        Wait(duration)
        for i = 5, 0, -1 do
            SetTimecycleModifierStrength(i / 10)
            Wait(100)
        end
        ClearTimecycleModifier()
    end)
end

-- ─── CLEANUP ───────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    RenderScriptCams(false, false, 0, true, true)
end)

-- ─── EXPORTS ───────────────────────────────────────────────────

exports('TriggerScreenFlash',   TriggerScreenFlash)
exports('ShakeCamera',          ShakeCamera)
exports('ShowElevatorLoading',  ShowElevatorLoading)
exports('ShowFloorIndicator',   ShowFloorIndicator)
exports('ApplyTeleportFilter',  ApplyTeleportFilter)
