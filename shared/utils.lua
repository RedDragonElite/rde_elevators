--[[
    rde_elevators v4.1.1 — shared/utils.lua
    Enhanced Utility Functions
    Red Dragon Elite | BFS v6.66
--]]

-- ════════════════════════════════════════════════════════════════════
-- 🗄️ DATABASE BOOLEAN HELPERS (RDE OX Standards v2)
-- ────────────────────────────────────────────────────────────────────
-- oxmysql casts TINYINT(1) inconsistently — sometimes as number 0/1,
-- sometimes as boolean true/false, depending on driver version and
-- MySQL/MariaDB build. `row.col == 1` therefore silently fails when
-- the driver decided to hand you `true` instead of `1`.
--
-- ALWAYS funnel TINYINT(1) reads through DbBool() and writes through
-- BoolDb(). This is the only safe pattern.
-- ════════════════════════════════════════════════════════════════════

--- Convert any DB-flavored boolean representation to a Lua boolean.
--- Accepts: true/false, 1/0, "1"/"0", "true"/"false", nil.
---@param v any
---@return boolean
function DbBool(v)
    if v == nil                  then return false end
    if type(v) == 'boolean'      then return v end
    if type(v) == 'number'       then return v == 1 end
    if type(v) == 'string'       then return v == '1' or v == 'true' end
    return false
end

--- Convert a Lua boolean to the integer form oxmysql wants in writes.
---@param b boolean
---@return integer
function BoolDb(b)
    return b and 1 or 0
end

--- Debug print helper — only logs when Config.Debug is true
---@param ... any
function RDE_Debug(...)
    if not Config.Debug then return end
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print(('[^2rde_elevators^7] [^3DEBUG^7] %s'):format(table.concat(parts, ' ')))
end

--- Info log (always shown)
---@param ... any
function RDE_Info(...)
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print(('[^2rde_elevators^7] [^5INFO^7] %s'):format(table.concat(parts, ' ')))
end

--- Error log (always shown)
---@param ... any
function RDE_Error(...)
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print(('[^2rde_elevators^7] [^1ERROR^7] %s'):format(table.concat(parts, ' ')))
end

--- Success log (always shown)
---@param ... any
function RDE_Success(...)
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print(('[^2rde_elevators^7] [^2SUCCESS^7] %s'):format(table.concat(parts, ' ')))
end

--- Count entries in a table (pairs-safe)
---@param t table
---@return integer
function TableCount(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Deep-copy a table
---@param orig table
---@return table
function DeepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = type(v) == 'table' and DeepCopy(v) or v
    end
    return copy
end

--- Clamp a number between min and max
---@param val number
---@param min number
---@param max number
---@return number
function Clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

--- Round a number to specified decimal places
---@param num number
---@param decimals number
---@return number
function Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

--- Format time in seconds to readable string
---@param seconds number
---@return string
function FormatTime(seconds)
    if seconds < 60 then
        return ('%ds'):format(math.floor(seconds))
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return ('%dm %ds'):format(mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return ('%dh %dm'):format(hours, mins)
    end
end

--- Get distance between two coords
---@param c1 vector3
---@param c2 vector3
---@return number
function GetDistance(c1, c2)
    return #(c1 - c2)
end

--- Convert table to JSON string (safe)
---@param t table
---@return string
function TableToJson(t)
    local success, result = pcall(json.encode, t)
    if success then
        return result
    else
        RDE_Error('Failed to encode table to JSON:', result)
        return '{}'
    end
end

--- Convert JSON string to table (safe)
---@param str string
---@return table
function JsonToTable(str)
    if not str or str == '' then return {} end
    local success, result = pcall(json.decode, str)
    if success then
        return result or {}
    else
        RDE_Error('Failed to decode JSON:', result)
        return {}
    end
end

--- Check if table contains value
---@param t table
---@param val any
---@return boolean
function TableContains(t, val)
    for _, v in pairs(t) do
        if v == val then return true end
    end
    return false
end

--- Get table keys as array
---@param t table
---@return table
function TableKeys(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    return keys
end

--- Get table values as array
---@param t table
---@return table
function TableValues(t)
    local values = {}
    for _, v in pairs(t) do
        values[#values + 1] = v
    end
    return values
end

--- Merge two tables (deep merge)
---@param t1 table
---@param t2 table
---@return table
function TableMerge(t1, t2)
    local result = DeepCopy(t1)
    for k, v in pairs(t2) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = TableMerge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--- Generate unique ID
---@return string
function GenerateId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local id = ''
    for i = 1, 16 do
        local rand = math.random(1, #chars)
        id = id .. chars:sub(rand, rand)
    end
    return id .. '_' .. os.time()
end

--- Format number with thousands separator
---@param num number
---@return string
function FormatNumber(num)
    local formatted = tostring(num)
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

--- Get current timestamp
---@return number
function GetTimestamp()
    return os.time()
end

--- Check if value is empty (nil, empty string, empty table)
---@param val any
---@return boolean
function IsEmpty(val)
    if val == nil then return true end
    if type(val) == 'string' and val == '' then return true end
    if type(val) == 'table' and next(val) == nil then return true end
    return false
end

--- Sanitize string for database (remove special chars)
---@param str string
---@return string
function SanitizeString(str)
    if not str then return '' end
    return str:gsub('[^a-zA-Z0-9_%-]', '_'):lower()
end

--- Get vehicle class name
---@param class number
---@return string
function GetVehicleClassName(class)
    local classes = {
        [0]  = 'Compacts',
        [1]  = 'Sedans',
        [2]  = 'SUVs',
        [3]  = 'Coupes',
        [4]  = 'Muscle',
        [5]  = 'Sports Classics',
        [6]  = 'Sports',
        [7]  = 'Super',
        [8]  = 'Motorcycles',
        [9]  = 'Off-road',
        [10] = 'Industrial',
        [11] = 'Utility',
        [12] = 'Vans',
        [13] = 'Cycles',
        [14] = 'Boats',
        [15] = 'Helicopters',
        [16] = 'Planes',
        [17] = 'Service',
        [18] = 'Emergency',
        [19] = 'Military',
        [20] = 'Commercial',
        [21] = 'Trains',
    }
    return classes[class] or 'Unknown'
end

--- Performance: Cache wrapper
local CacheStore = {}
function GetCached(key, ttl, callback)
    local cached = CacheStore[key]
    if cached and (os.time() - cached.time) < ttl then
        return cached.value
    end
    
    local value = callback()
    CacheStore[key] = {
        value = value,
        time = os.time()
    }
    return value
end

--- Clear cache entry
function ClearCache(key)
    CacheStore[key] = nil
end

--- Clear all cache
function ClearAllCache()
    CacheStore = {}
end

return {
    RDE_Debug = RDE_Debug,
    RDE_Info = RDE_Info,
    RDE_Error = RDE_Error,
    TableCount = TableCount,
    DeepCopy = DeepCopy,
    Clamp = Clamp,
    Round = Round,
    FormatTime = FormatTime,
    GetDistance = GetDistance,
    TableToJson = TableToJson,
    JsonToTable = JsonToTable,
    TableContains = TableContains,
    TableKeys = TableKeys,
    TableValues = TableValues,
    TableMerge = TableMerge,
    GenerateId = GenerateId,
    FormatNumber = FormatNumber,
    GetTimestamp = GetTimestamp,
    IsEmpty = IsEmpty,
    SanitizeString = SanitizeString,
    GetVehicleClassName = GetVehicleClassName,
    GetCached = GetCached,
    ClearCache = ClearCache,
    ClearAllCache = ClearAllCache,
}
