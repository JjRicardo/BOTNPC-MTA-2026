-- server/node_editor_server.lua
-- Sistema de edição de nodes visual (Server-side)

local nodeEditorServer = {}
local lastCreatedNode = {} -- Por player

function nodeEditorServer.addNode(x, y, z)
    local player = source
    if not isPlayerAdmin(player) then return end
    
    local node = createElement("pathpoint")
    if node then
        setElementPosition(node, x, y, z)
        local id = "node_" .. (math.random(1000, 9999))
        setElementID(node, id)
        
        -- Auto-conexão com o último node criado pelo player
        if lastCreatedNode[player] and isElement(lastCreatedNode[player]) then
            local prevNode = lastCreatedNode[player]
            local prevID = getElementID(prevNode)
            
            -- Link bidirecional
            local conn1 = getElementData(node, "connections") or {}
            conn1[prevID] = true
            setElementData(node, "connections", conn1, true)
            
            local conn2 = getElementData(prevNode, "connections") or {}
            conn2[id] = true
            setElementData(prevNode, "connections", conn2, true)
            
            outputChatBox("[NodeEditor] Node criado e linkado ao anterior!", player, 0, 255, 0)
        else
            outputChatBox("[NodeEditor] Primeiro node criado com ID: " .. id, player, 0, 255, 0)
        end
        
        lastCreatedNode[player] = node
    end
end
addEvent("onNodeEditorAdd", true)
addEventHandler("onNodeEditorAdd", root, nodeEditorServer.addNode)

function nodeEditorServer.resetLastNode()
    if not isPlayerAdmin(source) then return end
    lastCreatedNode[source] = nil
    outputChatBox("[NodeEditor] Sequência de auto-link resetada.", source, 255, 255, 0)
end
addEvent("onNodeEditorReset", true)
addEventHandler("onNodeEditorReset", root, nodeEditorServer.resetLastNode)

function nodeEditorServer.delNode(id)
    if not isPlayerAdmin(source) then return end
    local node = getElementByID(tostring(id))
    if isElement(node) then
        -- Remove referências em outros nodes
        local allNodes = getElementsByType("pathpoint")
        for _, n in ipairs(allNodes) do
            local conn = getElementData(n, "connections")
            if conn and conn[id] then
                conn[id] = nil
                setElementData(n, "connections", conn, true)
            end
        end
        destroyElement(node)
        outputChatBox("[NodeEditor] Node " .. id .. " removido.", source, 255, 0, 0)
    end
end
addEvent("onNodeEditorDel", true)
addEventHandler("onNodeEditorDel", root, nodeEditorServer.delNode)

function nodeEditorServer.linkNodes(id1, id2)
    if not isPlayerAdmin(source) then return end
    local node1 = getElementByID(tostring(id1))
    local node2 = getElementByID(tostring(id2))
    
    if not isElement(node1) or not isElement(node2) then
        outputChatBox("[NodeEditor] Erro: Um ou ambos os IDs são inválidos.", source, 255, 0, 0)
        return
    end
    
    local connections1 = getElementData(node1, "connections") or {}
    connections1[id2] = true
    setElementData(node1, "connections", connections1, true)
    
    local connections2 = getElementData(node2, "connections") or {}
    connections2[id1] = true
    setElementData(node2, "connections", connections2, true)
    
    outputChatBox("[NodeEditor] Nodes " .. id1 .. " e " .. id2 .. " linkados com sucesso!", source, 0, 255, 0)
end
addEvent("onNodeEditorLink", true)
addEventHandler("onNodeEditorLink", root, nodeEditorServer.linkNodes)

function nodeEditorServer.saveNodes()
    if not isPlayerAdmin(source) then return end
    local customNodes = {
        paths = {},
        covers = {}
    }
    
    local nodes = getElementsByType("pathpoint")
    for _, node in ipairs(nodes) do
        local x, y, z = getElementPosition(node)
        local id = getElementID(node)
        local connections = getElementData(node, "connections") or {}
        
        table.insert(customNodes.paths, {
            x = x, y = y, z = z,
            id = id,
            connections = connections
        })
    end
    
    -- Carrega covers existentes se houver
    if defaultNodes and defaultNodes.covers then
        customNodes.covers = defaultNodes.covers
    end
    
    local json = toJSON(customNodes, true)
    local file = fileCreate("maps/custom_nodes.json")
    if file then
        fileWrite(file, json)
        fileClose(file)
        outputChatBox("[NodeEditor] Nodes salvos com sucesso em maps/custom_nodes.json!", source, 0, 255, 0)
    else
        outputChatBox("[NodeEditor] Erro ao salvar nodes.", source, 255, 0, 0)
    end
end
addEvent("onNodeEditorSave", true)
addEventHandler("onNodeEditorSave", root, nodeEditorServer.saveNodes)

outputDebugString("[BotNPC] Node Editor Server carregado")
