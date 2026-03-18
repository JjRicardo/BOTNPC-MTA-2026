-- maps/generators/node_generator.lua
-- Gerador automático de pathpoints

nodeGenerator = {}

nodeGenerator.generatedNodes = {}
nodeGenerator.gridSize = BOTNPC.CONSTANTS.PATHFINDING.NODE_RADIUS

function nodeGenerator.generateInArea(centerX, centerY, radius, step, dimension)
    step = step or nodeGenerator.gridSize
    dimension = dimension or 0
    
    local nodes = {}
    
    for x = -radius, radius, step do
        for y = -radius, radius, step do
            local worldX = centerX + x
            local worldY = centerY + y
            local _, _, groundZ = getGroundPosition(worldX, worldY, 1000)
            
            if groundZ then
                local node = createObject(2993, worldX, worldY, groundZ, 0, 0, 0)
                if node then
                    setElementDimension(node, dimension)
                    setElementData(node, "generated", true, false)
                    table.insert(nodes, node)
                    table.insert(nodeGenerator.generatedNodes, node)
                end
            end
        end
    end
    
    outputDebugString("[BotNPC] Gerados " .. #nodes .. " pathpoints")
    return nodes
end

function nodeGenerator.clearGenerated()
    for _, node in ipairs(nodeGenerator.generatedNodes) do
        if isElement(node) then
            destroyElement(node)
        end
    end
    nodeGenerator.generatedNodes = {}
end

outputDebugString("[BotNPC] Node generator carregado")