-- maps/map_editor.lua
-- Editor de Nós e Covers para BotNPC

local tempNodes = {}
local tempCovers = {}
local tempLinks = {}
local markers = {}
local isEditing = false

-- Adiciona um nó de pathfinding
addCommandHandler("addnode", function(player)
    if not isPlayerAdmin(player) then return end
    
    local x, y, z = getElementPosition(player)
    z = z - 0.95 -- Ajuste para o chão
    
    local node = {x = x, y = y, z = z, id = #tempNodes + 1}
    table.insert(tempNodes, node)
    
    -- Visualização
    local marker = createMarker(x, y, z, "cylinder", 0.5, 0, 255, 0, 150)
    table.insert(markers, marker)
    
    outputChatBox("[BotNPC Editor] Nó #" .. node.id .. " adicionado.", player, 0, 255, 0)
end)

-- Adiciona um ponto de cover
addCommandHandler("addcover", function(player, cmd, type)
    if not isPlayerAdmin(player) then return end
    
    type = type or "high"
    if type ~= "low" and type ~= "high" then
        outputChatBox("Uso: /addcover [low/high]", player, 255, 0, 0)
        return
    end
    
    local x, y, z = getElementPosition(player)
    local _, _, rot = getElementRotation(player)
    z = z - 0.95
    
    local cover = {x = x, y = y, z = z, rot = rot, type = type}
    table.insert(tempCovers, cover)
    
    -- Visualização
    local r, g, b = (type == "low" and 255 or 0), 0, (type == "high" and 255 or 0)
    local marker = createMarker(x, y, z, "arrow", 0.5, r, g, b, 150)
    table.insert(markers, marker)
    
    outputChatBox("[BotNPC Editor] Cover (" .. type .. ") adicionado.", player, 0, 255, 0)
end)

-- Liga os dois últimos nós criados
addCommandHandler("linknodes", function(player)
    if not isPlayerAdmin(player) then return end
    
    local count = #tempNodes
    if count < 2 then
        outputChatBox("[BotNPC Editor] Você precisa de pelo menos 2 nós para criar um link.", player, 255, 0, 0)
        return
    end
    
    local nodeA = tempNodes[count-1]
    local nodeB = tempNodes[count]
    
    table.insert(tempLinks, {from = nodeA.id, to = nodeB.id})
    outputChatBox("[BotNPC Editor] Link criado entre Nó #" .. nodeA.id .. " e Nó #" .. nodeB.id, player, 0, 255, 255)
end)

-- Salva os nós em um arquivo
addCommandHandler("savenodes", function(player)
    if not isPlayerAdmin(player) then return end
    
    if #tempNodes == 0 and #tempCovers == 0 then
        outputChatBox("[BotNPC Editor] Nada para salvar.", player, 255, 0, 0)
        return
    end
    
    local file = fileCreate("maps/custom_nodes.lua")
    if not file then
        outputChatBox("[BotNPC Editor] Erro ao criar arquivo.", player, 255, 0, 0)
        return
    end
    
    local content = "-- Custom Nodes gerado pelo Editor\n\n"
    content = content .. "customNodes = {\n"
    
    -- Salva Paths
    content = content .. "    paths = {\n"
    for _, node in ipairs(tempNodes) do
        content = content .. string.format("        {x = %.4f, y = %.4f, z = %.4f},\n", node.x, node.y, node.z)
    end
    content = content .. "    },\n\n"
    
    -- Salva Covers
    content = content .. "    covers = {\n"
    for _, cover in ipairs(tempCovers) do
        content = content .. string.format("        {x = %.4f, y = %.4f, z = %.4f, rot = %.4f, type = '%s'},\n", cover.x, cover.y, cover.z, cover.rot, cover.type)
    end
    content = content .. "    }\n"
    content = content .. "}\n"
    
    fileWrite(file, content)
    fileClose(file)
    
    outputChatBox("[BotNPC Editor] Mapa salvo em 'maps/custom_nodes.lua'!", player, 0, 255, 0)
    
    -- Recarrega os nós no servidor
    if loadCustomNodes then
        loadCustomNodes()
    end
end)

-- Limpa a sessão atual
addCommandHandler("clearnodes", function(player)
    if not isPlayerAdmin(player) then return end
    
    tempNodes = {}
    tempCovers = {}
    tempLinks = {}
    
    for _, m in ipairs(markers) do destroyElement(m) end
    markers = {}
    
    outputChatBox("[BotNPC Editor] Sessão limpa.", player, 255, 255, 0)
end)
