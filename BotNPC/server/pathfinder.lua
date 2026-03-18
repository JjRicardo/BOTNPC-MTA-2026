-- server/pathfinder.lua
-- Sistema de pathfinding

pathfinder = {}

pathfinder.nodes = {}
pathfinder.nodeGrid = {}
pathfinder.gridSize = BOTNPC.CONSTANTS.PATHFINDING.GRID_SIZE

function pathfinder.init()
    pathfinder.scanNodes()
    outputDebugString("[BotNPC] Pathfinder inicializado com " .. #pathfinder.nodes .. " nós")
end

function pathfinder.scanNodes()
    pathfinder.nodes = {}
    pathfinder.nodeGrid = {}
    
    for _, node in ipairs(getElementsByType("pathpoint")) do
        pathfinder.registerNode(node)
    end
end

function pathfinder.registerNode(node)
    local id = getElementID(node) or (#pathfinder.nodes + 1)
    local x, y, z = getElementPosition(node)
    local dim = getElementDimension(node)
    
    pathfinder.nodes[id] = {
        element = node,
        x = x, y = y, z = z,
        dimension = dim,
        connections = {}
    }
    
    -- Index por grid
    local gx = math.floor(x / pathfinder.gridSize)
    local gy = math.floor(y / pathfinder.gridSize)
    
    if not pathfinder.nodeGrid[dim] then pathfinder.nodeGrid[dim] = {} end
    if not pathfinder.nodeGrid[dim][gy] then pathfinder.nodeGrid[dim][gy] = {} end
    if not pathfinder.nodeGrid[dim][gy][gx] then pathfinder.nodeGrid[dim][gy][gx] = {} end
    
    table.insert(pathfinder.nodeGrid[dim][gy][gx], id)
    
    return id
end

function pathfinder.connectNodes(id1, id2, oneway)
    local node1 = pathfinder.nodes[id1]
    local node2 = pathfinder.nodes[id2]
    
    if not node1 or not node2 then return false end
    
    node1.connections[id2] = true
    
    if not oneway then
        node2.connections[id1] = true
    end
    
    return true
end

function pathfinder.findPath(startX, startY, endX, endY, dimension)
    local startNode = pathfinder.getNearestNode(startX, startY, dimension)
    local endNode = pathfinder.getNearestNode(endX, endY, dimension)
    
    if not startNode or not endNode then
        return {}
    end
    
    -- A* simplificado
    local openSet = {[startNode] = true}
    local closedSet = {}
    local cameFrom = {}
    local gScore = {[startNode] = 0}
    local fScore = {[startNode] = pathfinder.heuristic(startNode, endNode)}
    
    while next(openSet) do
        local current = pathfinder.getLowestFScore(openSet, fScore)
        
        if current == endNode then
            return pathfinder.reconstructPath(cameFrom, current)
        end
        
        openSet[current] = nil
        closedSet[current] = true
        
        for neighbor in pairs(pathfinder.nodes[current].connections) do
            if not closedSet[neighbor] then
                local tentativeGScore = gScore[current] + 
                    pathfinder.getDistance(current, neighbor)
                
                if not gScore[neighbor] or tentativeGScore < gScore[neighbor] then
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeGScore
                    fScore[neighbor] = tentativeGScore + pathfinder.heuristic(neighbor, endNode)
                    
                    if not openSet[neighbor] then
                        openSet[neighbor] = true
                    end
                end
            end
        end
    end
    
    return {}
end

function pathfinder.getNearestNode(x, y, dimension)
    local bestNode = nil
    local bestDist = math.huge
    local maxDist = BOTNPC.CONSTANTS.PATHFINDING.MAX_NODE_DISTANCE
    
    for id, node in pairs(pathfinder.nodes) do
        if node.dimension == dimension then
            local dist = getDistanceBetweenPoints2D(x, y, node.x, node.y)
            if dist < bestDist and dist < maxDist then
                bestDist = dist
                bestNode = id
            end
        end
    end
    
    return bestNode
end

function pathfinder.heuristic(id1, id2)
    local node1 = pathfinder.nodes[id1]
    local node2 = pathfinder.nodes[id2]
    
    if not node1 or not node2 then return math.huge end
    
    return getDistanceBetweenPoints2D(node1.x, node1.y, node2.x, node2.y)
end

function pathfinder.getDistance(id1, id2)
    return pathfinder.heuristic(id1, id2)
end

function pathfinder.getLowestFScore(set, fScore)
    local lowest = math.huge
    local lowestNode = nil
    
    for node in pairs(set) do
        if fScore[node] and fScore[node] < lowest then
            lowest = fScore[node]
            lowestNode = node
        end
    end
    
    return lowestNode
end

function pathfinder.reconstructPath(cameFrom, current)
    local path = {current}
    
    while cameFrom[current] do
        current = cameFrom[current]
        table.insert(path, 1, current)
    end
    
    return path
end

outputDebugString("[BotNPC] Pathfinder carregado")