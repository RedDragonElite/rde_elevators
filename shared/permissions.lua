--[[
    rde_elevators v4.1 — shared/permissions.lua
    Red Dragon Elite | SerpentsByte

    v4.1 FIXES:
    ✅ Server-only IsAdmin no longer spams print() on every check. Uses
       RDE_Debug so console is clean unless Config.Debug = true.
    ✅ CanAccessFloor now branches server/client based on IsDuplicityVersion.
       Old version returned false on client (source=0 → 'invalid_source') so
       every restricted floor stayed greyed-out forever.
    ✅ Client uses ox_lib cache (cache.groups, cache.job) — no network calls
       per menu open.
--]]

Permissions = {}

local IS_SERVER = IsDuplicityVersion()

-- ═══════════════════════════════════════════════════════════════
-- 🔐 IsAdmin (SERVER) — Triple Layer: ACE → Steam → ox_core groups
-- ═══════════════════════════════════════════════════════════════

if IS_SERVER then
    function Permissions.IsAdmin(source)
        if not source or source < 1 then return false end

        RDE_Debug('[Perm] IsAdmin check for source', source, 'name=', GetPlayerName(source) or '?')

        -- 1) FiveM ACE permission (highest priority)
        if IsPlayerAceAllowed(source, Config.AdminSystem.AcePermission) then
            RDE_Debug('[Perm] ✅ GRANTED via ACE for', source)
            return true
        end

        -- 2) Steam ID fallback
        local steamId = GetPlayerIdentifierByType(source, 'steam')
        if steamId then
            for _, allowed in ipairs(Config.AdminSystem.steamIds or {}) do
                if steamId == allowed then
                    RDE_Debug('[Perm] ✅ GRANTED via Steam ID:', steamId)
                    return true
                end
            end
        end

        -- 3) ox_core groups
        local player = Ox.GetPlayer(source)
        if not player then
            RDE_Debug('[Perm] ❌ Ox.GetPlayer failed for', source)
            return false
        end

        local groups = player.groups
        if not groups or type(groups) ~= 'table' then
            RDE_Debug('[Perm] ❌ no groups on player', source)
            return false
        end

        for _, adminGroup in ipairs(Config.AdminSystem.AdminGroups) do
            if groups[adminGroup] then
                RDE_Debug('[Perm] ✅ GRANTED via ox_core group:', adminGroup, 'grade=', groups[adminGroup])
                return true
            end
        end

        RDE_Debug('[Perm] ❌ DENIED for', source)
        return false
    end
else
    -- ═══════════════════════════════════════════════════════════
    -- 🔐 IsAdmin (CLIENT) — local-only check via ox_lib cache
    -- ═══════════════════════════════════════════════════════════
    function Permissions.IsAdmin(_)
        local groups = cache and cache.groups or {}
        for _, adminGroup in ipairs(Config.AdminSystem.AdminGroups) do
            if groups[adminGroup] then return true end
        end
        return false
    end
end

-- Aliases (server uses identical logic, client falls through to local cache)
function Permissions.IsOwner(source)     return Permissions.IsAdmin(source) end
function Permissions.IsModerator(source) return Permissions.IsAdmin(source) end
function Permissions.IsVIP(source)       return Permissions.IsAdmin(source) end

function Permissions.GetLevel(source)
    if not source or (IS_SERVER and source < 1) then return 'user' end
    if Permissions.IsAdmin(source) then return 'admin' end
    return 'user'
end

-- ═══════════════════════════════════════════════════════════════
-- 🚪 CanAccessFloor — branches server vs client
-- ═══════════════════════════════════════════════════════════════
-- Pre-v4.1 the same function was called from both sides with source=0
-- on the client, which always failed. Now split cleanly.

if IS_SERVER then

    function Permissions.CanAccessFloor(source, restrictions)
        if not restrictions or not Config.Restrictions or not Config.Restrictions.Enabled then
            return true, nil
        end
        if not source or source < 1 then
            return false, 'invalid_source'
        end

        if Permissions.IsAdmin(source) then return true, nil end

        local player = Ox.GetPlayer(source)
        if not player then return false, 'player_not_found' end

        if restrictions.vip and Config.Restrictions.Types.vip then
            if not Permissions.IsVIP(source) then
                return false, 'vip_required'
            end
        end

        if restrictions.job and Config.Restrictions.Types.job then
            local playerJob = player.get and player.get('job')
            if not playerJob then return false, 'job_required' end

            if type(restrictions.job) == 'table' then
                local hasJob = false
                for _, allowedJob in ipairs(restrictions.job) do
                    if playerJob == allowedJob then hasJob = true break end
                end
                if not hasJob then return false, 'job_required' end
            elseif playerJob ~= restrictions.job then
                return false, 'job_required'
            end
        end

        return true, nil
    end

else

    -- CLIENT version: uses ox_lib `cache` (cache.groups, cache.job).
    -- The `source` argument is ignored on the client.
    function Permissions.CanAccessFloor(_, restrictions)
        if not restrictions or not Config.Restrictions or not Config.Restrictions.Enabled then
            return true, nil
        end

        -- Admins bypass everything
        if Permissions.IsAdmin(0) then return true, nil end

        if restrictions.vip and Config.Restrictions.Types.vip then
            if not Permissions.IsVIP(0) then
                return false, 'vip_required'
            end
        end

        if restrictions.job and Config.Restrictions.Types.job then
            local playerJob = cache and cache.job and cache.job.name
            if not playerJob then return false, 'job_required' end

            if type(restrictions.job) == 'table' then
                local hasJob = false
                for _, allowedJob in ipairs(restrictions.job) do
                    if playerJob == allowedJob then hasJob = true break end
                end
                if not hasJob then return false, 'job_required' end
            elseif playerJob ~= restrictions.job then
                return false, 'job_required'
            end
        end

        return true, nil
    end

end

return Permissions
