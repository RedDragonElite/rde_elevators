--[[
    ██████╗ ██████╗ ███████╗
    ██╔══██╗██╔══██╗██╔════╝
    ██████╔╝██║  ██║█████╗
    ██╔══██╗██║  ██║██╔══╝
    ██║  ██║██████╔╝███████╗
    ╚═╝  ╚═╝╚═════╝ ╚══════╝
    Red Dragon Elite — rde_elevators v1.5.1
    BFS v6.66 License — Free code. Free minds.
    https://rd-elite.com | SerpentsByte

    🔥 v1.5.0 — IPL PASSENGER INTERIOR FIX 🔥
    🔧 FIX: Passengers in vehicles never saw IPL interiors (bob74_ipl / RequestIpl)
            in 3rd-person. Root cause: GTA V's portal-culling system only activates
            the interior renderer when a ped physically crosses a portal boundary.
            Passengers placed into vehicles (or already seated when the driver
            enters) never cross a portal. Collisions were present, first-person
            worked — only 3rd-person rendering was broken.
            Fix: lib.onCache('vehicle') starts a lightweight passenger watcher
            that calls LoadInterior() + IsInteriorReady() when the vehicle enters
            a portal-based interior. Dynamic sleep: 750ms outside / 5000ms after
            activation. Token-pattern prevents stale threads on rapid vehicle
            switches. Self-terminates on vehicle exit or driver-seat change.
            Complements Fix #10 (passengerSync teleport case) — now both the
            elevator-teleport AND the drive-in-as-passenger cases are covered.
--]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'rde_elevators'
description 'RDE Elevator System v1.5.1 — Next Gen | Ultra-Realistic Garage System | Advanced Admin | IPL Passenger Fix'
author      'SerpentsByte | rd-elite.com'
version     '1.5.1'
repository  'https://github.com/RedDragonElite/rde_elevators'

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'shared/config.lua',
    'shared/utils.lua',
    'shared/permissions.lua',
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/vehicle.lua',
    'client/admin.lua',
    'client/effects.lua',
    'client/sounds.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/statebags.lua',
    'server/analytics.lua',
    'server/commands.lua',
}

files {
    'locales/*.json',
    'html/index.html',
}

ui_page 'html/index.html'

dependencies {
    'ox_core',
    'ox_lib',
    'ox_target',
    'oxmysql',
}
