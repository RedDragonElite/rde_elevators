--[[
    rde_elevators v4.1 — client/sounds.lua
    Advanced Multi-Theme Sound System (HARDENED)
    Red Dragon Elite | BFS v6.66

    🚨 v4.1 CRITICAL FIX 🚨
    Old version did `Config.Sounds.Ding.Volume`, `Config.Sounds.DoorClose.Volume`,
    `Config.Sounds.Moving.Enabled`, `Config.Sounds.Moving.Loop` — none of which
    existed in shared/config.lua's Config.Sounds table. Result: nil-indexing
    crashed the entire teleport CreateThread *before* SetEntityCoords ever ran.
    Both ped and vehicle teleport were dead.

    This rewrite is fully defensive: every config lookup is guarded, every
    sound function works even if Config.Sounds is partially defined, and
    PlaySound() catches its own errors so a sound failure can NEVER bring
    down a teleport thread again.
--]]

-- ─── SOUND THEMES ──────────────────────────────────────────────

local SoundThemes = {
    modern = {
        ding = { ref = 'START_SWITCH_PRESS',   set = 'DLC_HEIST_FINALE_BANK_SOUNDS' },
        door = { ref = 'CLICK_SPECIAL',        set = 'MP_UNLOCK_SOUNDS' },
        move = { ref = 'ELEVATOR_MUSIC',       set = 'ELEVATOR_MUSIC' },
    },
    classic = {
        ding = { ref = 'CHECKPOINT_NORMAL',    set = 'HUD_MINI_GAME_SOUNDSET' },
        door = { ref = 'HIGHLIGHT_NAV_UP_DOWN',set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        move = { ref = 'SCREEN_FLASH',         set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    },
    luxury = {
        ding = { ref = 'DOOR_BUZZ',            set = 'DLC_VW_APARTMENT_DOOR_SOUNDS' },
        door = { ref = 'PAINT_COMPLETE',       set = 'DLC_TUNER_CAR_MEET_SETUP_REPAIR_SOUNDS' },
        move = { ref = 'TUMBLER_PIN_FALL',     set = 'SAFE_CRACK_MINIGAME_SOUNDS' },
    },
    industrial = {
        ding = { ref = 'DOOR_CLOSE',           set = 'HACKING_DOORS' },
        door = { ref = 'CELL_GATES',           set = 'PRISON_ALARMS' },
        move = { ref = 'DRONE_BEEP',           set = 'DLC_H3_ARCADE_DRONE_SOUNDS' },
    },
}

-- ─── DEFENSIVE CONFIG ACCESS ───────────────────────────────────
-- All accesses are guarded — a missing Config.Sounds.X never crashes.

local function GetSoundCfg(key)
    local s = Config.Sounds
    if not s then return nil end
    local v = s[key]
    if type(v) ~= 'table' then return nil end
    return v
end

local function IsSoundEnabled(key)
    local cfg = GetSoundCfg(key)
    if not cfg then return false end
    -- nil → treated as enabled (backwards-compat)
    return cfg.Enabled ~= false
end

local function GetSoundVolume(key)
    local cfg = GetSoundCfg(key)
    if cfg and type(cfg.Volume) == 'number' then return cfg.Volume end
    local fallback = (Config.Sounds and Config.Sounds.Volume) or 0.5
    return fallback
end

local function GetCurrentTheme()
    local themeName = (Config.Sounds and Config.Sounds.Theme) or 'modern'
    return SoundThemes[themeName] or SoundThemes.modern
end

-- ─── ACTIVE SOUND TRACKING ─────────────────────────────────────

local ActiveSounds = {}

-- ─── CORE PLAY FUNCTION (BULLETPROOF) ──────────────────────────
-- Wrapped in pcall so a sound error NEVER crashes the caller's thread.

local function PlaySound(soundKey, themeKey)
    if not IsSoundEnabled(soundKey) then return end

    local theme = GetCurrentTheme()
    local entry = theme[themeKey] or theme.ding
    if not entry or not entry.ref or not entry.set then return end

    CreateThread(function()
        local ok, err = pcall(function()
            local soundId = GetSoundId()
            PlaySoundFrontend(soundId, entry.ref, entry.set, true)
            ActiveSounds[soundKey] = soundId
            Wait(3000)
            if ActiveSounds[soundKey] == soundId then
                StopSound(soundId)
                ReleaseSoundId(soundId)
                ActiveSounds[soundKey] = nil
            end
        end)
        if not ok then RDE_Debug('[Sounds] PlaySound failed:', soundKey, err) end
    end)
end

-- ─── PUBLIC SOUND API ──────────────────────────────────────────

function PlayElevatorDing()
    PlaySound('Ding', 'ding')
end

function PlayDoorOpenSound()
    PlaySound('DoorOpen', 'door')
end

function PlayDoorCloseSound()
    PlaySound('DoorClose', 'door')
end

function PlayMovingSound()
    if not IsSoundEnabled('Moving') then return end

    local theme = GetCurrentTheme()
    local move  = theme.move or theme.ding
    if not move then return end

    local cfg  = GetSoundCfg('Moving') or {}
    local loop = cfg.Loop == true

    CreateThread(function()
        local ok, err = pcall(function()
            local soundId = GetSoundId()
            PlaySoundFrontend(soundId, move.ref, move.set, true)
            ActiveSounds['Moving'] = soundId
            if not loop then
                Wait(3000)
                if ActiveSounds['Moving'] == soundId then
                    StopSound(soundId)
                    ReleaseSoundId(soundId)
                    ActiveSounds['Moving'] = nil
                end
            end
        end)
        if not ok then RDE_Debug('[Sounds] PlayMovingSound failed:', err) end
    end)
end

function StopMovingSound()
    local soundId = ActiveSounds['Moving']
    if not soundId then return end
    pcall(function()
        StopSound(soundId)
        ReleaseSoundId(soundId)
    end)
    ActiveSounds['Moving'] = nil
end

function PlayParkingSound()
    if not Config.Vehicle or not Config.Vehicle.UseParkingSound then return end
    CreateThread(function()
        pcall(function()
            local soundId = GetSoundId()
            PlaySoundFrontend(soundId, 'QUIT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            Wait(1000)
            StopSound(soundId)
            ReleaseSoundId(soundId)
        end)
    end)
end

-- ─── THEME SWITCHING ───────────────────────────────────────────

function SetSoundTheme(themeName)
    if SoundThemes[themeName] then
        Config.Sounds = Config.Sounds or {}
        Config.Sounds.Theme = themeName
        RDE_Debug('[Sounds] Theme changed to:', themeName)
        return true
    end
    RDE_Error('[Sounds] Invalid theme:', themeName)
    return false
end

-- ─── SOUND TEST COMMAND (ADMIN) ────────────────────────────────

-- ✅ FIX (#6 v1.0.0-alpha): chat:addSuggestion added
RegisterCommand('testelevatorsounds', function()
    if not Permissions.IsAdmin(0) then return end

    lib.registerContext({
        id = 'rde_elevator_sound_test',
        title = '🔊 Sound Test',
        options = {
            { title = 'Play Ding',           icon = 'bell',           onSelect = function() PlayElevatorDing()   end },
            { title = 'Play Door Open',      icon = 'door-open',      onSelect = function() PlayDoorOpenSound()  end },
            { title = 'Play Door Close',     icon = 'door-closed',    onSelect = function() PlayDoorCloseSound() end },
            { title = 'Play Moving (Loop)',  icon = 'arrows-up-down', onSelect = function() PlayMovingSound()    end },
            { title = 'Stop Moving',         icon = 'circle-stop',    onSelect = function() StopMovingSound()    end },
            { title = 'Play Parking Sound',  icon = 'car',            onSelect = function() PlayParkingSound()   end },
        }
    })
    lib.showContext('rde_elevator_sound_test')
end, false)
TriggerEvent('chat:addSuggestion', '/testelevatorsounds', '[Admin] Test elevator sound themes')

-- ─── CLEANUP ON RESOURCE STOP ──────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, soundId in pairs(ActiveSounds) do
        pcall(function() StopSound(soundId); ReleaseSoundId(soundId) end)
    end
    ActiveSounds = {}
end)

-- ─── EXPORTS ───────────────────────────────────────────────────

exports('PlayElevatorDing', PlayElevatorDing)
exports('PlayDoorSound',    PlayDoorOpenSound)
exports('PlayMovingSound',  PlayMovingSound)
exports('StopMovingSound',  StopMovingSound)
exports('SetSoundTheme',    SetSoundTheme)
