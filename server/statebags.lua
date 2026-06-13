--[[
    rde_elevators v3.0 — server/statebags.lua
    Realtime StateBag Synchronization System
    Red Dragon Elite | BFS v6.66
--]]

local GLOBAL_KEY  = Config.StateBags.ElevatorData
local OCCUPIED_KEY = Config.StateBags.FloorOccupied

---@type table<integer, table<string, integer>> elevator_id → floor_name → player_count
local OccupiedMap = {}

-- ✅ FIX (#1 v1.0.0-alpha): AddStateBagChangeHandler fires AFTER the write,
-- so reading Player(src).state[PlayerFloor] inside the handler returns the
-- NEW value, not the old one. Decrementing the "previous" floor with the new
-- key silently decremented the CURRENT floor instead, causing occupied counts
-- to drift increasingly wrong across the session.
-- Fix: maintain our own server-side tracking table for each player's last
-- known floor and use that for the pre-decrement lookup.
---@type table<integer, {elevatorId: integer, floor: string}> src → last floor info
local PlayerLastFloor = {}

-- ─── PUSH GLOBAL STATE ─────────────────────────────────────────

function PushGlobalState(cache)
    GlobalState:set(GLOBAL_KEY, cache, true)
    RDE_Debug('[StateBags] GlobalState pushed —', TableCount(cache), 'elevators')
end

-- ─── RESET OCCUPIED STATE ──────────────────────────────────────

function ResetOccupied(elevatorId)
    OccupiedMap[elevatorId] = nil
    GlobalState:set(OCCUPIED_KEY .. ':' .. elevatorId, nil, true)
    RDE_Debug('[StateBags] Occupied state reset for elevator', elevatorId)
end

-- ─── UPDATE OCCUPIED STATE ─────────────────────────────────────

local function UpdateOccupiedState(elevatorId)
    GlobalState:set(
        OCCUPIED_KEY .. ':' .. elevatorId,
        OccupiedMap[elevatorId] or {},
        true
    )
    
    RDE_Debug('[StateBags] Occupied state updated for elevator', elevatorId)
end

-- ─── TRACK FLOOR ARRIVALS ──────────────────────────────────────
-- Listens for Player(src).state:set(PlayerFloor, ...) which is set
-- server-side by the rde_elevators:setPlayerFloor event handler.

AddStateBagChangeHandler(Config.StateBags.PlayerFloor, nil, function(bagName, _, value)
    local src = tonumber(bagName:match('player:(%d+)'))
    if not src or not value then return end

    local eid   = value.elevatorId
    local floor = value.floor
    if not eid or not floor then return end

    -- ✅ FIX (#1 v1.0.0-alpha): Use PlayerLastFloor (our own tracking table),
    -- NOT Player(src).state — which already holds the new value by the time
    -- the handler fires. Old code decremented the CURRENT floor instead of
    -- the previous one, causing occupied counts to drift infinitely upward.
    local prevState = PlayerLastFloor[src]
    if prevState and prevState.elevatorId and prevState.floor then
        local peid   = prevState.elevatorId
        local pfloor = prevState.floor
        if OccupiedMap[peid] and OccupiedMap[peid][pfloor] then
            OccupiedMap[peid][pfloor] = math.max(0, OccupiedMap[peid][pfloor] - 1)
            if OccupiedMap[peid][pfloor] == 0 then OccupiedMap[peid][pfloor] = nil end
            UpdateOccupiedState(peid)
        end
    end

    -- Record new floor BEFORE incrementing so next change sees the correct previous state
    PlayerLastFloor[src] = { elevatorId = eid, floor = floor }

    OccupiedMap[eid] = OccupiedMap[eid] or {}
    OccupiedMap[eid][floor] = (OccupiedMap[eid][floor] or 0) + 1
    UpdateOccupiedState(eid)

    RDE_Debug(('Player %d arrived at elevator %d, floor %s (count: %d)'):format(
        src, eid, floor, OccupiedMap[eid][floor]
    ))
end)

-- ─── TRACK FLOOR DEPARTURES ────────────────────────────────────

local function OnPlayerLeaveFloor(src)
    -- ✅ FIX (#1 v1.0.0-alpha): use PlayerLastFloor for authoritative floor info;
    -- the player statebag may already be nil/stale at drop time.
    local bagData = PlayerLastFloor[src] or Player(src).state[Config.StateBags.PlayerFloor]
    PlayerLastFloor[src] = nil  -- always clear tracking entry on leave

    if not bagData then return end

    local eid   = bagData.elevatorId
    local floor = bagData.floor
    if not eid or not floor then return end

    if OccupiedMap[eid] and OccupiedMap[eid][floor] then
        OccupiedMap[eid][floor] = math.max(0, OccupiedMap[eid][floor] - 1)

        if OccupiedMap[eid][floor] == 0 then
            OccupiedMap[eid][floor] = nil
        end

        UpdateOccupiedState(eid)

        RDE_Debug(('Player %d left elevator %d, floor %s'):format(src, eid, floor))
    end
end

-- ─── PLAYER DROP HANDLER ───────────────────────────────────────

AddEventHandler('playerDropped', function(reason)
    OnPlayerLeaveFloor(source)
    RDE_Debug(('Player %d dropped, floor tracking cleaned'):format(source))
end)

-- ─── MANUAL LEAVE EVENT ────────────────────────────────────────

RegisterNetEvent('rde_elevators:leaveFloor', function()
    OnPlayerLeaveFloor(source)
end)

-- ─── AUTO-CLEANUP THREAD ───────────────────────────────────────

-- Periodically validate occupied counts in case of desyncs
if Config.Debug then
    CreateThread(function()
        while true do
            Wait(60000) -- Every minute
            
            for elevatorId, floors in pairs(OccupiedMap) do
                for floorName, count in pairs(floors) do
                    -- Validate count by checking actual player states
                    local actualCount = 0
                    local players = GetPlayers()
                    
                    for _, playerId in ipairs(players) do
                        local state = Player(playerId).state[Config.StateBags.PlayerFloor]
                        if state and state.elevatorId == elevatorId and state.floor == floorName then
                            actualCount = actualCount + 1
                        end
                    end
                    
                    if actualCount ~= count then
                        RDE_Debug(('[Cleanup] Fixing desync: elevator %d, floor %s (was %d, should be %d)'):format(
                            elevatorId, floorName, count, actualCount
                        ))
                        
                        OccupiedMap[elevatorId][floorName] = actualCount > 0 and actualCount or nil
                        UpdateOccupiedState(elevatorId)
                    end
                end
            end
        end
    end)
end

-- ─── EXPORTS ───────────────────────────────────────────────────

exports('GetOccupiedCount', function(elevatorId, floorName)
    if not OccupiedMap[elevatorId] then return 0 end
    return OccupiedMap[elevatorId][floorName] or 0
end)

exports('GetAllOccupied', function(elevatorId)
    return OccupiedMap[elevatorId] or {}
end)
