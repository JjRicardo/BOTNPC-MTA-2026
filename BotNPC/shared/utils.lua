-- shared/utils.lua
-- Funções utilitárias

function getAngle(x1, y1, x2, y2)
    local angle = -math.deg(math.atan2(x2 - x1, y2 - y1))
    return (angle < 0) and (angle + 360) or angle
end

function getVerticalAngle(x1, y1, z1, x2, y2, z2)
    local dist2D = getDistanceBetweenPoints2D(x1, y1, x2, y2)
    local dz = z2 - z1
    return math.deg(math.atan2(dz, dist2D))
end

function angleDifference(a, b)
    local diff = math.abs(a - b)
    if diff > 180 then diff = 360 - diff end
    return diff
end

function getDistance2D(x1, y1, x2, y2)
    return getDistanceBetweenPoints2D(x1, y1, x2, y2)
end

function getDistance3D(x1, y1, z1, x2, y2, z2)
    return getDistanceBetweenPoints3D(x1, y1, z1, x2, y2, z2)
end

function isLineOfSightClearEx(x1, y1, z1, x2, y2, z2, ignoreElement)
    return isLineOfSightClear(
        x1, y1, z1 + 1.1,
        x2, y2, z2 + 1.1,
        true, -- checkBuildings
        true, -- checkVehicles
        false, -- checkPeds (false para não se auto-bloquearem ou bloquearem por aliados)
        true, -- checkObjects
        true, -- checkDummies
        false, -- seeThroughStuff
        false, -- ignoreSomeObjects
        ignoreElement
    )
end

function getNearestPlayer(x, y, z, dimension)
    local nearest = nil
    local nearestDist = math.huge
    
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and not isPedDead(player) then
            if dimension == nil or getElementDimension(player) == dimension then
                local px, py, pz = getElementPosition(player)
                local dist = getDistance3D(x, y, z, px, py, pz)
                if dist < nearestDist then
                    nearest = player
                    nearestDist = dist
                end
            end
        end
    end
    
    return nearest, nearestDist
end

function getPlayersInDimension(dimension)
    local players = {}
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and not isPedDead(player) then
            if getElementDimension(player) == dimension then
                table.insert(players, player)
            end
        end
    end
    return players
end

function table.removeValue(t, value)
    for i = #t, 1, -1 do
        if t[i] == value then
            table.remove(t, i)
        end
    end
end

outputDebugString("[BotNPC] Utils carregados")