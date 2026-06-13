--[[
    rde_elevators v4.1 — shared/config.lua
    Red Dragon Elite | BFS v6.66
    NEXT GEN CONFIGURATION

    v4.1 FIX: Config.Sounds completely re-structured. Old layout had only
    Volume/Theme/UseFallback/FallbackDing/FallbackDoor — but client/sounds.lua
    indexed Config.Sounds.Ding.Volume, Config.Sounds.DoorClose.Volume,
    Config.Sounds.Moving.Enabled etc. → nil-indexing → CRASH inside teleport
    threads BEFORE SetEntityCoords ran. That is why nothing teleported anymore.
--]]

Config = {}

-- ════════════════════════════════════════════════════════════════
-- ⚙️ GENERAL
-- ════════════════════════════════════════════════════════════════

Config.Debug           = false
Config.TablePrefix     = 'rde_'
Config.DefaultLanguage = 'en'   -- 'en' or 'de'

-- NUI: true = React UI | false = ox_lib context menus
Config.UseNUI = false

-- ════════════════════════════════════════════════════════════════
-- 👮 ADMIN VERIFICATION (Triple Layer)
-- ════════════════════════════════════════════════════════════════

Config.AdminSystem = {
    AdminGroups   = { 'admin', 'superadmin', 'mod', 'god', 'management', 'owner' },
    AcePermission = 'rde_elevators.admin',
    steamIds      = {
        'steam:110000101605859',  -- SerpentsByte | RedDragonElite Owner
    },
}

-- ════════════════════════════════════════════════════════════════
-- 🎯 TARGET SYSTEM
-- ════════════════════════════════════════════════════════════════

Config.Target = {
    Icon     = 'elevator',   -- Lucide icon name (icons.overextended.dev)
    Distance = 2.5,
    Size     = vec3(2.5, 2.5, 3.0),
    Debug    = false,
}

-- ════════════════════════════════════════════════════════════════
-- 🚗 VEHICLE & GARAGE SYSTEM
-- ════════════════════════════════════════════════════════════════

Config.Vehicle = {
    Enabled           = true,
    CinematicMode     = true,
    SpawnZOffset      = 0.5,
    MaxVehicleLength  = 12.0,
    DoorAnimationTime = 2000,
    UseParkingSound   = true,

    AllowedClasses = {
        [0]  = true,   -- Compacts
        [1]  = true,   -- Sedans
        [2]  = true,   -- SUVs
        [3]  = true,   -- Coupes
        [4]  = true,   -- Muscle
        [5]  = true,   -- Sports Classics
        [6]  = true,   -- Sports
        [7]  = true,   -- Super
        [8]  = true,   -- Motorcycles
        [9]  = true,   -- Off-road
        [10] = false,  -- Industrial
        [11] = false,  -- Utility
        [12] = false,  -- Vans
        [13] = false,  -- Cycles
        [14] = false,  -- Boats
        [15] = false,  -- Helicopters
        [16] = false,  -- Planes
        [17] = false,  -- Service
        [18] = false,  -- Emergency
        [19] = false,  -- Military
        [20] = false,  -- Commercial
        [21] = false,  -- Trains
    },
}

-- ════════════════════════════════════════════════════════════════
-- ⏱️ COOLDOWN & ANTI-SPAM
-- ════════════════════════════════════════════════════════════════

Config.Cooldown = {
    Enabled     = true,
    Duration    = 3000,
    ShowTimer   = true,
    AdminBypass = true,
}

-- ════════════════════════════════════════════════════════════════
-- 🎬 TELEPORT EFFECTS
-- ════════════════════════════════════════════════════════════════

Config.Teleport = {
    FadeOut = 800,
    FadeIn  = 800,
    Hold    = 200,

    CameraShake = {
        Enabled   = true,
        Type      = 'SMALL_EXPLOSION_SHAKE',
        Intensity = 0.15,
        Duration  = 500,
    },

    Particles = {
        Enabled  = true,
        Effect   = 'scr_rcbarry2',
        Name     = 'scr_exp_clown',
        Scale    = 1.0,
        Duration = 2000,
    },
}

-- ════════════════════════════════════════════════════════════════
-- 🗺️ BLIPS — Default (overridable per elevator in Admin Panel)
-- ════════════════════════════════════════════════════════════════

Config.Blips = {
    Enabled       = true,
    Sprite        = 357,
    Color         = 2,
    Scale         = 0.75,
    Label         = 'Elevator',
    ShowAllFloors = false,
    FlashOnUse    = false,

    StateColors = {
        enabled     = 2,    -- Green
        disabled    = 40,   -- Grey
        maintenance = 1,    -- Red
        vehicle     = 38,   -- Blue
    },

    Sprites = {
        default      = 357,
        vehicle      = 225,
        vip          = 311,
        police       = 60,
        medical      = 61,
        warehouse    = 473,
        construction = 318,
        casino       = 571,
        nightclub    = 272,
        hotel        = 245,
    },
}

-- ════════════════════════════════════════════════════════════════
-- 🔊 SOUND SYSTEM
-- ════════════════════════════════════════════════════════════════
-- ✅ v4.1 FIX: full structure restored. Every sound type that sounds.lua
-- references has its own { Enabled, Volume } table so nil-indexing is
-- impossible. Setting Enabled = false disables that sound cleanly.

Config.Sounds = {
    Volume      = 0.5,
    Theme       = 'modern',   -- modern | classic | luxury | industrial
    UseFallback = true,

    Ding      = { Enabled = true, Volume = 0.5 },
    DoorOpen  = { Enabled = true, Volume = 0.5 },
    DoorClose = { Enabled = true, Volume = 0.5 },
    Moving    = { Enabled = false, Volume = 0.3, Loop = true },

    -- Legacy fallback definitions (used by older sound calls if theme missing)
    FallbackDing = { name = 'CHECKPOINT_NORMAL',     set = 'HUD_MINI_GAME_SOUNDSET' },
    FallbackDoor = { name = 'HIGHLIGHT_NAV_UP_DOWN', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

-- ════════════════════════════════════════════════════════════════
-- 🚨 EMERGENCY & MAINTENANCE
-- ════════════════════════════════════════════════════════════════

Config.Emergency = {
    Enabled                  = true,
    Command                  = 'elevatormaintenance',
    NotifyAll                = true,
    BootPlayersOnMaintenance = false,
}

-- ════════════════════════════════════════════════════════════════
-- 📊 ANALYTICS
-- ════════════════════════════════════════════════════════════════

Config.Analytics = {
    Enabled        = true,
    SaveToDB       = true,
    TrackUsage     = true,
    TrackPopular   = true,
    TrackPeakTimes = true,   -- ✅ FIX (#5 v1.0.0-alpha): added missing field
    StatsCommand   = 'elevatorstats',
}

-- ════════════════════════════════════════════════════════════════
-- 💬 NOTIFICATIONS
-- ════════════════════════════════════════════════════════════════

Config.Notify = {
    Success = { type = 'success', duration = 3000, position = 'top-right' },
    Error   = { type = 'error',   duration = 4000, position = 'top-right' },
    Info    = { type = 'inform',  duration = 3000, position = 'top-right' },
    Warning = { type = 'warning', duration = 3500, position = 'top-right' },
}

-- ════════════════════════════════════════════════════════════════
-- 🎨 UI CUSTOMIZATION
-- ════════════════════════════════════════════════════════════════

Config.UI = {
    PrimaryColor   = '#00ff88',
    SecondaryColor = '#0a0a0a',
    AccentColor    = '#ff4444',
    Font           = 'Rajdhani, sans-serif',
    ShowPreview    = true,
    Show3DText     = true,
}

-- ════════════════════════════════════════════════════════════════
-- 🔐 FLOOR RESTRICTIONS
-- ════════════════════════════════════════════════════════════════

Config.Restrictions = {
    Enabled = true,
    Types   = { job = true, vip = true, group = true, gang = true },
}

-- ════════════════════════════════════════════════════════════════
-- 📡 STATEBAG KEYS
-- ════════════════════════════════════════════════════════════════
-- DataPrefix is the per-elevator key prefix used by the StateBag handler
-- (e.g. 'rde_elevators:data:1'). ElevatorData is the legacy full-cache
-- key, kept only for the migration callback that ships full state on join.

Config.StateBags = {
    ElevatorData  = 'rde_elevators:data',        -- legacy full-cache (initial hydration only)
    DataPrefix    = 'rde_elevators:data:',       -- per-ID key (real-time sync)
    FloorOccupied = 'rde_elevators:occupied',
    PlayerFloor   = 'rde_elevators:floor',
    Maintenance   = 'rde_elevators:maintenance',
    Statistics    = 'rde_elevators:stats',
}
