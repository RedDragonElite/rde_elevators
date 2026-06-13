--[[
    rde_elevators v3.0 — server/analytics.lua
    Advanced Analytics & Statistics System
    Red Dragon Elite | BFS v6.66
--]]

if not Config.Analytics.Enabled then return end

local AnalyticsCache = {
    hourly = {},
    daily = {},
    popular = {},
}

-- ─── TRACK USAGE IN MEMORY ─────────────────────────────────────

if Config.Analytics.TrackUsage then
    AddEventHandler('rde_elevators:trackUsage', function()
        local src = source
        local player = Ox.GetPlayer(src)
        if not player then return end
        
        local hour = os.date('%Y-%m-%d %H:00:00')
        local day = os.date('%Y-%m-%d')
        
        -- Increment hourly counter
        AnalyticsCache.hourly[hour] = (AnalyticsCache.hourly[hour] or 0) + 1
        
        -- Increment daily counter
        AnalyticsCache.daily[day] = (AnalyticsCache.daily[day] or 0) + 1
        
        RDE_Debug('[Analytics] Usage tracked:', hour, AnalyticsCache.hourly[hour])
    end)
end

-- ─── TRACK POPULAR FLOORS ──────────────────────────────────────

if Config.Analytics.TrackPopular then
    RegisterNetEvent('rde_elevators:trackUsage', function(elevatorId, fromFloor, toFloor)
        if not toFloor then return end
        
        local key = ('%d:%s'):format(elevatorId, toFloor)
        AnalyticsCache.popular[key] = (AnalyticsCache.popular[key] or 0) + 1
        
        RDE_Debug('[Analytics] Popular floor tracked:', key, AnalyticsCache.popular[key])
    end)
end

-- ─── GET PEAK USAGE TIME ───────────────────────────────────────
-- ✅ FIX (#5 v1.0.0-alpha): Config.Analytics.TrackPeakTimes was never defined
-- in config.lua — this block never executed and GetPeakUsageTime / its export
-- were dead code. Guard removed; function is always available when the
-- analytics module is loaded.

function GetPeakUsageTime()
        local maxUses = 0
        local peakHour = nil
        
        for hour, uses in pairs(AnalyticsCache.hourly) do
            if uses > maxUses then
                maxUses = uses
                peakHour = hour
            end
        end
        
        return peakHour, maxUses
end

exports('GetPeakUsageTime', GetPeakUsageTime)

-- ─── GET MOST POPULAR FLOOR ────────────────────────────────────

function GetMostPopularFloor(elevatorId)
    local maxUses = 0
    local popularFloor = nil
    
    for key, uses in pairs(AnalyticsCache.popular) do
        local eid, floor = key:match('(%d+):(.+)')
        eid = tonumber(eid)
        
        if eid == elevatorId and uses > maxUses then
            maxUses = uses
            popularFloor = floor
        end
    end
    
    return popularFloor, maxUses
end

exports('GetMostPopularFloor', GetMostPopularFloor)

-- ─── ANALYTICS CLEANUP THREAD ──────────────────────────────────

-- Clean old analytics data (keep last 7 days)
CreateThread(function()
    while true do
        Wait(3600000) -- Every hour
        
        local cutoffDate = os.time() - (7 * 24 * 60 * 60) -- 7 days ago
        local cutoffStr = os.date('%Y-%m-%d', cutoffDate)
        
        -- Clean hourly data
        for hour in pairs(AnalyticsCache.hourly) do
            if hour < cutoffStr then
                AnalyticsCache.hourly[hour] = nil
                RDE_Debug('[Analytics] Cleaned old hourly data:', hour)
            end
        end
        
        -- Clean daily data
        for day in pairs(AnalyticsCache.daily) do
            if day < cutoffStr then
                AnalyticsCache.daily[day] = nil
                RDE_Debug('[Analytics] Cleaned old daily data:', day)
            end
        end
    end
end)

-- ─── PERIODIC DATABASE BACKUP ──────────────────────────────────

if Config.Advanced and Config.Advanced.AutoBackup then
    CreateThread(function()
        while true do
            Wait(Config.Advanced and Config.Advanced.BackupInterval or 3600000)
            
            -- This would backup critical elevator data
            -- For now, just log it
            RDE_Debug('[Analytics] Auto-backup checkpoint')
            
            -- You could implement actual backup logic here
            -- For example, exporting to JSON file or backup table
        end
    end)
end

-- ─── EXPORT ANALYTICS DATA ─────────────────────────────────────

exports('GetAnalytics', function()
    return {
        hourly = AnalyticsCache.hourly,
        daily = AnalyticsCache.daily,
        popular = AnalyticsCache.popular,
    }
end)

exports('GetHourlyStats', function()
    return AnalyticsCache.hourly
end)

exports('GetDailyStats', function()
    return AnalyticsCache.daily
end)

exports('GetPopularFloors', function()
    return AnalyticsCache.popular
end)

RDE_Info('[Analytics] System initialized')
