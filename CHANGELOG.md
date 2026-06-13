# 🐉 rde_elevators — CHANGELOG

All notable changes to this project are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.5.1] — 2026-06-13 — HOTFIX

### Fixed

| # | Fix | Impact |
|---|---|---|
| **#12** | **IPL Portal Boundary Fix** — `GetInteriorAtCoords` at the floor-level target point returned 0 for mansion/garage interiors (Richman Villa, etc.) because GTA V's portal trigger boundary sits ~1 unit above the floor. Additionally, `bob74_ipl` only calls `RefreshInterior(id)` on init — never `LoadInterior(id)` — so the passenger's interior rendering context was never activated even when the interior ID existed. Fix: cascade `Z+1.0 → Z → target` to reliably hit the portal boundary; call `RefreshInterior(interior)` after `IsInteriorReady()` to fully re-activate interior entity sets and styles. Open-world IPLs (no portal ID) fall through to `SetFocusPosAndVel` + collision wait. Applied in both `passengerSync` and `_StartIplWatcher`. | Passengers now see portal-based IPL interiors (mansions, garages) in 3rd-person |

### Technical Details — #12

- **Root cause 1:** `GetInteriorAtCoords(floor.x, floor.y, floor.z)` → 0 because portal boundary is at `floor.z + ~1.0`
- **Root cause 2:** `bob74_ipl` calls only `RefreshInterior(interiorId)` on all clients at startup — `LoadInterior(interiorId)` is never called for players who don't physically walk through the portal
- **Cascade lookup:** `vc.z + 1.0` → `vc.z` → original `target` coords (3 attempts, first non-zero wins)
- **`RefreshInterior` call:** re-activates all entity sets and styles configured by bob74_ipl (furniture, style, wallpaper, etc.)
- **Fallback path:** if all 3 attempts return 0 (true open-world IPL geometry) → `SetFocusPosAndVel` + collision wait
- **Debug log:** `[Vehicle] Passenger interior activated, id: XXXXX` confirms activation in F8

---

## [1.5.0] — 2026-06-13

### Fixed

| # | Fix | Impact |
|---|---|---|
| **#11** | **IPL Passenger Interior Fix** — Passengers in vehicles never saw bob74_ipl / `RequestIpl()` interiors in 3rd-person. Root cause: GTA V's portal-culling system only activates the interior renderer when a ped physically crosses a portal boundary. Passengers placed into vehicles (or already seated when the driver enters an IPL interior) never cross a portal — collisions were present, first-person worked, 3rd-person was blind. Fix: `lib.onCache('vehicle')` starts a lightweight watcher that calls `LoadInterior()` + `IsInteriorReady()` + `RefreshInterior()` when the vehicle enters a portal-based interior. | Passengers now see IPL interiors correctly in 3rd-person |

### Technical Details — #11

- **Trigger:** `lib.onCache('vehicle', ...)` — event-driven, zero overhead when not in a vehicle
- **Thread lifetime:** only while local player is a passenger; self-terminates on vehicle exit or seat change to driver
- **Dynamic sleep:** `750ms` while outside an interior (catches entry moment), `5000ms` after activation (avoids pointless polling while stationary inside)
- **Token pattern:** stale threads from rapid vehicle switches self-terminate immediately
- **Inner thread:** `LoadInterior()` + `IsInteriorReady()` (up to 5s) runs in a separate coroutine to keep the outer watcher loop responsive
- **Complementary to Fix #10** (passengerSync teleport case): #10 handles elevator teleports, #11 handles the general drive-in-as-passenger case

---

## [1.0.1-alpha] — 2026-05-XX

### Fixed

| # | Fix | Impact |
|---|---|---|
| **#9** | `AddStateBagChangeHandler` keyFilter was EXACT-MATCH only — old handler watched `Config.StateBags.DataPrefix` directly, which never matched per-ID keys (`DataPrefix .. "42"`). Safety net was dead code. Fix: `nil` keyFilter + pattern-match inside, scoped to `'global'` bag | StateBag delta updates now actually fire |
| **#8** | Race condition on init — if server was still running DB queries when the client callback fired, both `getAll` and the GlobalState fallback returned empty. `_initDone = true` with zero elevators, zones never rebuilt. Fix: retry after 3s + final GlobalState fallback | Elevators now load correctly on late-join |
| **Blip Toggle** | Per-elevator blip visibility toggle — admins can hide individual elevators from the minimap (secret elevators, garage entries). Zone interaction stays active even when blip is hidden. `blip.enabled = false` in elevator data | Map stays clean for servers with many elevators |

---

## [1.0.0-alpha] — 2026-05-XX

Initial GitHub release. Full rewrite from v4.x internal to public release.

### Fixed (Pre-Release Audit — 10 Bugs)

| # | Fix | Impact |
|---|---|---|
| **#1** | `sounds.lua` nil-indexed `Config.Sounds.DoorClose` → crashed teleport thread before `SetEntityCoords` | Every teleport was silently broken |
| **#2** | `Wait()` inside NetEvent handlers (RDE OX Standards anti-pattern #1) | Blocked server Lua thread on every teleport |
| **#3** | `PlayerPedId()` used instead of `cache.ped` throughout vehicle.lua | Wrong ped on streamer boundary |
| **#4** | Triple-broadcast sync (per-ID GlobalState + full-cache GlobalState + TriggerClientEvent) → three redundant sync paths | Race conditions on every elevator update |
| **#5** | `Permissions.CanAccessFloor(0, ...)` always denied on client (source=0 is server-only valid) | All VIP/job floor restrictions silently blocked everyone |
| **#6** | `ElevatorCache` table as second source of truth alongside `Elevators` → desync | Stale state after admin edits |
| **#7** | Missing collision load before `SetEntityCoords` → ped snapped to roof on multi-story buildings | Players spawned on rooftops |
| **#8** | 3D-text loop ran `Wait(0)` → 60fps native spam (RDE OX Standards anti-pattern) | Unnecessary CPU load |
| **#9** | Initial load race: StateBag handler fired before `getAll` callback completed, mutated empty `Elevators` | Zones never built on fast-joining clients |
| **#10** | Elevator teleport didn't call `LoadInterior()` + `IsInteriorReady()` for passengers before fade-in → interior invisible after teleport | Passengers saw black world after elevator ride |

---

*Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)*  
*REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.*  
*RDE FOREVER. SYSTEM FAILURE. ⚡777⚡*
