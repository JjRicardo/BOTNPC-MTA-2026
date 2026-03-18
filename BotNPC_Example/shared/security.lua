-- security.lua shared cache false

-- [[ MTA Tunnel - Security & Performance Layer ]] --
if (not isElement(localPlayer)) then
    -- Configuration
    local Config = {
        salt = "mta-tunnel-v2-secure-salt",
        maxCallsPerMinute = 60, -- Rate limit
        maxViolationsBeforeBlock = 5, -- Block player after this many violations
        violationCooldown = 60000 * 30, -- 30 minutes block
        logToFile = true, -- Log to a file
        alertAdmins = true, -- Alert players in ACL 'Admin'
        
        -- Resource validation
        validateResources = false, -- Se true, apenas recursos na whitelist podem chamar o túnel
        allowedResources = {
            ["BotNPC_Example"] = true,
        }
    }

    -- Internal data tracking
    local playerTokens = {}
    local playerStats = {} -- { calls = 0, violations = 0, lastCall = 0, blockedUntil = 0 }

    -- Helper: Log security events
    local function logSecurity(player, message, level)
        local playerName = isElement(player) and getPlayerName(player) or "Unknown"
        local playerSerial = isElement(player) and getPlayerSerial(player) or "N/A"
        local logMsg = ("[Tunnel Security] [%s] %s (Serial: %s)"):format(playerName, message, playerSerial)
        
        outputDebugString(logMsg, level or 2)

        if (Config.alertAdmins) then
            for _, p in ipairs(getElementsByType("player")) do
                local acc = getPlayerAccount(p)
                if (not isGuestAccount(acc) and isObjectInACLGroup("user." .. getAccountName(acc), aclGetGroup("Admin"))) then
                    outputChatBox("#ff0000" .. logMsg, p, 255, 255, 255, true)
                end
            end
        end
    end

    -- Function to generate a unique token for a player
    function Tunnel.generateToken(player)
        if (not isElement(player)) then return nil end
        
        -- Cache token if already generated
        if (playerTokens[player]) then return playerTokens[player] end

        local serial = getPlayerSerial(player)
        local fingerprint = "no-fingerprint"
        
        -- Check if fingerprint resource is available
        local res = getResourceFromName("[CD]_Fingerprint")
        if (res and getResourceState(res) == "running") then
            fingerprint = exports["[CD]_Fingerprint"]:getPlayerFingerprint(player) or "no-fingerprint"
        end
        
        local token = md5(serial .. fingerprint .. Config.salt)
        playerTokens[player] = token
        return token
    end

    -- Middleware to validate security, rate limiting and source resource
    Tunnel.middleware(function(func, args, player, token, sourceRes)
        if (not player or not isElement(player)) then
            return true, args
        end

        -- 1. Validate Source Resource (Security improvement)
        if (Config.validateResources) then
            if (not Config.allowedResources[sourceRes]) then
                logSecurity(player, ("Unauthorized Resource: %s tried to call %s"):format(tostring(sourceRes), tostring(func)), 1)
                return false, "Unauthorized Resource: Access Denied"
            end
        end

        local now = getTickCount()
        local stats = playerStats[player] or { calls = 0, violations = 0, lastCall = 0, blockedUntil = 0 }
        playerStats[player] = stats

        -- 1. Check if blocked
        if (stats.blockedUntil > now) then
            local remaining = math.ceil((stats.blockedUntil - now) / 1000)
            return false, "Blocked: Security violations. Try again in " .. remaining .. "s"
        end

        -- 2. Rate Limiting (Anti-Spam)
        if (now - stats.lastCall < 1000) then -- Simple 1 call per second check or use counter
            stats.calls = stats.calls + 1
            if (stats.calls > Config.maxCallsPerMinute) then
                stats.violations = stats.violations + 1
                logSecurity(player, "Rate limit exceeded (func: " .. tostring(func) .. ")", 2)
                
                if (stats.violations >= Config.maxViolationsBeforeBlock) then
                    stats.blockedUntil = now + Config.violationCooldown
                    logSecurity(player, "PLAYER BLOCKED for security violations", 1)
                end
                
                return false, "Spam detected. Slow down."
            end
        else
            -- Reset counter every second or minute (here simplified)
            if (now - stats.lastCall > 60000) then
                stats.calls = 0
            end
        end
        stats.lastCall = now

        -- 3. Token Validation
        local expectedToken = Tunnel.generateToken(player)
        if (token ~= expectedToken) then
            stats.violations = stats.violations + 1
            logSecurity(player, "Invalid token attempt (func: " .. tostring(func) .. ")", 1)
            
            if (stats.violations >= Config.maxViolationsBeforeBlock) then
                stats.blockedUntil = now + Config.violationCooldown
                logSecurity(player, "PLAYER BLOCKED for security violations", 1)
            end

            return false, "Unauthorized: Invalid security token"
        end

        return true, args
    end)

    -- Send token to client when ready
    local function sendTokenToClient(player)
        if (not isElement(player)) then return end
        local token = Tunnel.generateToken(player)
        if (token) then
            triggerClientEvent(player, "__tunnel:setToken", resourceRoot, token)
        end
    end

    -- Event handlers
    addEventHandler("onPlayerFingerprint", root, function(fingerprint)
        -- Regenerate token when fingerprint is ready
        playerTokens[source] = nil 
        sendTokenToClient(source)
    end)

    addEventHandler("onPlayerJoin", root, function()
        playerStats[source] = { calls = 0, violations = 0, lastCall = 0, blockedUntil = 0 }
        setTimer(sendTokenToClient, 1500, 1, source)
    end)

    addEventHandler("onPlayerQuit", root, function()
        playerTokens[source] = nil
        playerStats[source] = nil
    end)
else
    -- Client side: receive the token
    addEvent("__tunnel:setToken", true)
    addEventHandler("__tunnel:setToken", resourceRoot, function(token)
        Tunnel.setToken(token)
    end)
end
