-- maps/generators/navmesh_loader.lua
-- Carregador de navmesh (para expansão futura)

navmeshLoader = {}

navmeshLoader.navmeshes = {}

function navmeshLoader.loadNavmesh(mapName)
    outputDebugString("[BotNPC] Navmesh loading not implemented yet")
    return false
end

function navmeshLoader.getNearestNavPoint(x, y, z)
    return nil
end

function navmeshLoader.findPath(startX, startY, startZ, endX, endY, endZ)
    return {}
end

outputDebugString("[BotNPC] Navmesh loader carregado")