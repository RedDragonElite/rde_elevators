# rde_elevators

🛗 NEXT-GEN ELEVATOR & GARAGE SYSTEM V1.5.1 — Built on ox_core & StateBags!

[![Version](https://img.shields.io/badge/version-1.5.1-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_elevators)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag-black?style=for-the-badge)](https://github.com/RedDragonElite/rde_elevators/blob/main/LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-blue?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/Framework-ox__core-blue?style=for-the-badge)](https://github.com/overextended/ox_core)
[![Quality](https://img.shields.io/badge/Quality-Production-gold?style=for-the-badge)](https://github.com/RedDragonElite)

**🛗 RDE ELEVATORS | Next-Gen Elevator & Garage System for FiveM ox_core | Vehicle Mode | Cinematic | StateBag-Synced | Production-Ready**

*Built by [Red Dragon Elite](https://rd-elite.com) | Free Forever | No Paywalls | No Legacy*

[📖 Installation](#-installation) • [⚙️ Configuration](#️-configuration) • [🚗 Vehicle Mode](#-vehicle-mode) • [🛡 Admin System](#-admin-system) • [📡 Exports](#-exports) • [🐛 Troubleshooting](#-troubleshooting) • [🌐 Website](https://rd-elite.com)

---

## 🔥 Why This Destroys Every Other Elevator Script

Every other elevator script is either paid, a 200-line ESX relic, or breaks the moment two players touch it.

We said no.

| ❌ Other Elevator Scripts | ✅ rde_elevators |
|---|---|
| Static teleport, no sync | Real-time StateBag sync across all clients |
| Driver only — passengers get left behind | Full multiplayer vehicle sync, all seats |
| Breaks in IPL interiors (passengers see nothing) | IPL Passenger Interior Fix — portal-culling activated for all seats |
| ESX / QBCore bloat | ox_core only — the future, not the past |
| Admin creates elevators in a config file | Live in-game CRUD admin — no server restart |
| 0.5ms+ idle usage | < 0.01ms idle — event-driven, no polling |
| One floor type fits all | VIP floors, job-locked floors, vehicle-only floors |
| Paid or locked down | 100% free forever — RDE Black Flag |

### 🎯 Key Features

- 🛗 **Full Elevator System** — unlimited elevators, unlimited floors, live CRUD admin
- 🚗 **Vehicle Mode** — drive your car into the elevator, it teleports with you. All passengers sync
- 🎬 **Cinematic Mode** — fake camera, particle effects, shake, door animation on vehicle entry
- 👥 **Full Multiplayer Sync** — all vehicle seats tracked, every passenger teleported server-side
- 🔒 **Floor Access Control** — VIP flags, job locks, grade requirements per floor
- 🔧 **Maintenance Mode** — lock any elevator instantly, admins can still use it
- 🗺️ **Blip System** — per-elevator minimap blips with state colours, per-elevator visibility toggle
- 📍 **Floor Occupancy** — real-time player count per floor shown in the menu
- 🎯 **ox_target Zones** — box zones per floor, icon adapts to elevator state
- 📉 **Cooldown System** — configurable, admin bypass, per-player
- 🌍 **Multilanguage** — EN / DE out of the box, add any language in minutes
- 🛡 **Server-Side Authority** — all sensitive actions validated server-side
- ⚙️ **Zero-Config Start** — sensible defaults, tables auto-create, no SQL import needed
- 🐉 **GTA V Engine Fix** — IPL interior portal-culling manually activated for passengers (v1.5.1)

---

## 📸 Screenshots

> Drop a PR with your screenshots!

---

## 📦 Dependencies

```
oxmysql        → https://github.com/overextended/oxmysql
ox_lib         → https://github.com/overextended/ox_lib
ox_core        → https://github.com/overextended/ox_core
ox_target      → https://github.com/overextended/ox_target
```

---

## 🚀 Installation

### Step 1: Clone or download

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_elevators.git
```

### Step 2: Add to server.cfg

```cfg
# Dependencies first — order matters!
ensure oxmysql
ensure ox_lib
ensure ox_core
ensure ox_target

# The elevator system
ensure rde_elevators
```

### Step 3: Configure

Edit `shared/config.lua` — sensible defaults work out of the box. See [Configuration](#️-configuration).

### Step 4: Start your server

That's it. No SQL import needed — tables auto-create on first run.

---

## ⚙️ Configuration

`shared/config.lua` is fully self-documented. Key sections:

```lua
-- Master debug toggle
Config.Debug = false

-- Admin groups
Config.AdminSystem = {
    AdminGroups   = { 'admin', 'superadmin', 'mod', 'god', 'management', 'owner' },
    AcePermission = 'rde_elevators.admin',
    steamIds      = {
        'steam:110000101605859',  -- add your steam ID here
    },
}

-- Language: 'en' or 'de'
Config.DefaultLanguage = 'en'

-- UI mode: true = NUI | false = ox_lib context menus
Config.UseNUI = false

-- Cooldown between elevator uses
Config.Cooldown = {
    Enabled      = true,
    Duration     = 5000,   -- ms
    AdminBypass  = true,
}
```

---

## 🚗 Vehicle Mode

When `vehicle_mode = true` is set on an elevator, players can drive into it and the entire vehicle teleports to the target floor.

### How it works

1. Player drives vehicle onto the elevator target zone
2. `CanVehicleUseElevator()` validates class + length
3. Fade out / cinematic camera (if `CinematicMode = true`)
4. Driver's client notifies server via `rde_elevators:vehicleTeleport`
5. Server resolves all passengers by seat, notifies each client individually
6. Driver's client teleports the vehicle entity
7. Passenger clients re-seat themselves after confirming vehicle position
8. All clients call `LoadInterior()` + `IsInteriorReady()` for IPL interiors
9. Fade in — everyone's on the new floor

### Vehicle restrictions

```lua
Config.Vehicle = {
    Enabled           = true,
    CinematicMode     = true,
    MaxVehicleLength  = 12.0,   -- metres (blocks trucks, trailers)

    AllowedClasses = {
        [0]  = true,   -- Compacts
        [1]  = true,   -- Sedans
        -- ... configure per class
        [14] = false,  -- Boats
        [16] = false,  -- Planes
    },
}
```

### IPL Passenger Interior Fix (v1.5.1)

> **tl;dr:** passengers now see IPL interiors in 3rd-person. This was a GTA V engine limitation.

GTA V's portal-culling system only activates the interior renderer when a ped **physically crosses a portal boundary**. Passengers placed into vehicles via `SetPedIntoVehicle` — or already seated when the driver enters a `bob74_ipl` / `RequestIpl()` interior — never cross a portal. Result: interior invisible in 3rd-person, first-person worked, collisions were present.

The fix (`client/vehicle.lua`, `_StartIplWatcher`) uses `lib.onCache('vehicle')` to start a lightweight passenger watcher that calls `LoadInterior()` + `IsInteriorReady()` + `RefreshInterior()` whenever the vehicle enters a portal-based interior. The thread is event-driven (zero cost when not in a vehicle), uses a token pattern to prevent stale threads, and switches from `750ms` → `5000ms` sleep after activation. Uses Z+1.0 cascade for reliable portal detection and calls `RefreshInterior()` to re-activate bob74_ipl interior entity sets.

---

## 🛡 Admin System

### Access

Access is triple-layer verified: ACE permission → ox_core group → Steam ID fallback.

```cfg
# server.cfg — grant ACE access
add_principal identifier.steam:YOUR_STEAM_HEX group.admin
add_ace group.admin rde_elevators.admin allow
```

### In-Game Commands

| Command | Description |
|---|---|
| `/elevator create` | Open creation wizard (name, label, mode) |
| `/elevator edit [id]` | Edit existing elevator |
| `/elevator delete [id]` | Delete elevator + all its floors |
| `/elevator tp [id] [floor]` | Teleport yourself to a floor |
| `/elevator maintenance [id]` | Toggle maintenance mode |
| `/elevator list` | List all elevators with IDs |
| `/elevator reload` | Force-sync all clients |

### Floor Creation

Floors are created in the admin UI:
1. Stand at the physical floor location
2. Select "Add Floor" → enter floor name
3. Optionally set VIP flag, job restriction, grade
4. Save — zone and blip appear instantly server-wide (StateBag sync, no restart)

---

## 🗂 Folder Structure

```
rde_elevators/
├── fxmanifest.lua
├── README.md
├── CHANGELOG.md
├── LICENSE
├── shared/
│   ├── config.lua          ← All config + StateBag keys
│   ├── utils.lua           ← DbBool/BoolDb, RDE_Debug/Info/Error helpers
│   └── permissions.lua     ← Triple-layer admin check, floor access
├── server/
│   ├── main.lua            ← Core logic, DB, callbacks, vehicle sync
│   ├── statebags.lua       ← UpdateStatebag(), floor occupancy sync
│   ├── analytics.lua       ← Usage tracking
│   └── commands.lua        ← Admin commands
├── client/
│   ├── main.lua            ← StateBag handlers, zone/blip build, menus
│   ├── vehicle.lua         ← Vehicle teleport, passenger sync, IPL fix
│   ├── ui.lua              ← ox_lib context menu rendering
│   ├── admin.lua           ← Admin UI (create/edit/delete)
│   ├── effects.lua         ← Particle effects
│   ├── sounds.lua          ← Audio (ding, door, parking)
│   └── nui.lua             ← NUI bridge (when Config.UseNUI = true)
├── locales/
│   ├── en.json             ← English (default)
│   └── de.json             ← Deutsch
└── html/
    └── index.html          ← NUI interface
```

---

## 📡 Exports

### Client

```lua
-- Teleport to a floor programmatically
exports['rde_elevators']:TeleportToFloor(elevator, 'Floor 2', { x=0, y=0, z=10, w=0 })

-- Get current floor state
local floorName, elevatorId = exports['rde_elevators']:GetCurrentFloor()

-- Check cooldown state
local onCD, remainingMs = exports['rde_elevators']:IsOnCooldown()

-- Get all loaded elevators
local elevators = exports['rde_elevators']:GetElevators()

-- Force-rebuild all blips
exports['rde_elevators']:RebuildBlips()

-- Force-rebuild all ox_target zones
exports['rde_elevators']:RebuildTargets()
```

---

## 🔧 Debug Mode

Enable with `Config.Debug = true` in `shared/config.lua`, then watch server/client console:

| Log Tag | What it tells you |
|---|---|
| `[Init]` | Elevator load, callback result, retry logic |
| `[Sync]` | StateBag delta updates (per-elevator) |
| `[Targets]` | Zone count after rebuild |
| `[Teleport]` | Ped teleport coordinates |
| `[Vehicle]` | Vehicle teleport, occupant report, seat assignments |
| `[Floor]` | Floor registration, server confirmation |
| `[IPL]` | Passenger interior context activation (v1.5.1) |

---

## 🛡 Security

- All sensitive actions validated **server-side** (teleport coords, floor access, maintenance toggle)
- StateBags for real-time sync — no client polling
- ox_core group checks on all privileged callbacks
- ACE permission support + Steam ID whitelist fallback
- Floor restriction enforcement: server validates job/grade via ox_core player state
- Vehicle class + length validated before teleport — no remote exploit via spoofed class

---

## 🐛 Troubleshooting

### Elevators don't load on join

1. Enable `Config.Debug = true`
2. Check server console for `[Init]` output — did `getAll` return 0?
3. Ensure `oxmysql` is running and the `rde_elevators` table exists
4. If fresh install: restart the resource once after first run (tables auto-create on start)

### Passengers don't see the interior (IPL)

Fixed in **v1.5.0** (#11). Update to the latest release. If you're still seeing this:

1. Confirm the IPL is loaded via bob74_ipl on **all clients** (not just the requester)
2. Check client console for `[IPL] Passenger interior context activated` — if missing, watcher didn't start
3. Ensure `GetInteriorAtCoords()` returns non-zero for your IPL — some IPLs are pure geometry (no portal system), in which case this fix doesn't apply and the interior should be visible anyway

### Vehicle teleports but passengers end up outside

The passenger sync waits up to 3s for the vehicle to arrive at the target position. On high-latency connections this can time out. Increase the deadline in `passengerSync` in `client/vehicle.lua` if needed.

### Elevator zones don't appear

1. Check `[Targets]` debug output — how many zones registered?
2. Verify `ox_target` is running and loaded **before** `rde_elevators`
3. `pcall` wraps every zone add — check if ox_target is throwing errors

### `attempt to index a nil value` on startup

Check the order in `server.cfg`. `oxmysql` must load before `rde_elevators`. `ox_lib` and `ox_core` must also be before.

### Maintenance mode doesn't sync

Maintenance state uses a per-elevator StateBag key. Restart the resource to force a full resync if GlobalState isn't propagating.

### Blips not showing

Check `Config.Blips.Enabled = true` and that the elevator's `blip.enabled` field is not explicitly `false`. Run `/elevator edit [id]` and verify blip settings.

---

## 📚 Tech Stack

```
ox_core        → Player & group management, charId, getGroups()
ox_lib         → UI, callbacks, notifications, onCache()
ox_target      → Box zones per floor, state-adaptive icons
oxmysql        → Async database (auto-create tables, prepared statements)
StateBags      → Realtime server → all-clients sync (per-elevator delta)
GTA V Engine   → LoadInterior / IsInteriorReady / RefreshInterior (IPL fix)
```

---

## 🤝 Contributing

PRs are always welcome.

1. **Fork** the repository
2. **Create** a branch: `git checkout -b fix/your-fix`
3. **Test** on a live server before submitting
4. **Commit**: `git commit -m 'fix: description'`
5. **Push** and open a Pull Request

**Guidelines:**

- ✅ Keep the RDE header in all files
- ✅ No `Wait()` inside NetEvent handlers — wrap in `CreateThread`
- ✅ No `PlayerPedId()` — use `cache.ped`
- ✅ DB booleans through `DbBool()` / `BoolDb()` — never raw `== 1`
- ✅ Test on a live server before PR
- ❌ No telemetry, no paywalls, no ESX/QBCore
- ❌ No `Wait(0)` loops unless absolutely necessary and documented

---

## 📜 License

**RDE Black Flag Source License v6.66**

```
###################################################################################
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#   PROJECT:    RDE_ELEVATORS (NEXT-GEN ELEVATOR & GARAGE SYSTEM FOR FIVEM)       #
#   ARCHITECT:  .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com     #
#   WARNING: THIS CODE IS PROTECTED BY DIGITAL VOODOO AND PURE HATRED FOR LEAKERS #
#   1. FREE USE — Cost: 0.00€. If you paid for this, you got scammed by a rat.    #
#   2. TEBEX KILL SWITCH — Sell this = instant DMCA + Nostr public shaming.       #
#   3. CREDIT OATH — Keep this header. Don't be a skid.                           #
#   4. CURSE OF COPY-PASTE — RTFM or you WILL break something. Don't @ me.        #
#   "We build the future on the graves of paid resources."                        #
#   "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."                          #
###################################################################################
```

**TL;DR:** ✅ Free forever ✅ Keep the header ❌ Don't sell it ❌ Don't be a skid

---

## ⚡ Related Projects

| Resource | Description |
|---|---|
| [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) | Decentralized FiveM logging via Nostr — replace Discord forever |
| [rde_aipd](https://github.com/RedDragonElite/rde_aipd) | Next-Gen AI Police & Crime System |
| [rde_ipl](https://github.com/RedDragonElite/rde_ipl) | IPL management with collision sync |
| [awesome-ox-rde](https://github.com/RedDragonElite/awesome-ox-rde) | Curated list of the best ox_core resources |

---

## 🌐 Community & Support

| | |
|---|---|
| 🌍 **Website** | [rd-elite.com](https://rd-elite.com) |
| 🐙 **GitHub** | [github.com/RedDragonElite](https://github.com/RedDragonElite) |
| 🟣 **Nostr** | `npub1wr4e24zn6zzjqx8kvnelfvktf0pu6l2gx4gvw06zead2eqyn23sq9tsd94` |

**Before opening an issue:** Read the README → check Troubleshooting → read CHANGELOG.md → include your console logs. Don't open issues without logs.

---

**Made with 🔥 and raw elevator engineering by [Red Dragon Elite](https://rd-elite.com)**

*The future is ours. We are already inside.*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

**RDE FOREVER. SYSTEM FAILURE. ⚡777⚡**

[![Website](https://img.shields.io/badge/Website-Visit-red?style=for-the-badge&logo=google-chrome)](https://rd-elite.com)
[![Nostr](https://img.shields.io/badge/Nostr-Follow-purple?style=for-the-badge&logo=rss)](https://primal.net/p/npub1wr4e24zn6zzjqx8kvnelfvktf0pu6l2gx4gvw06zead2eqyn23sq9tsd94)
