-- maps/default_nodes.lua
-- Pontos de Pathfinding e Cover

defaultNodes = {
    -- Pontos de Pathfinding (Onde os bots podem andar)
    paths = {
        {x = 0, y = 0, z = 3},
        {x = 10, y = 0, z = 3},
    },
    
    -- Pontos de Cover (Onde os bots buscam proteção em combate)
    covers = {
        -- Exemplo: {x, y, z, rot, type}
        -- type: "low" (agachado), "high" (em pé atrás de parede)
        {x = 2495.0, y = -1670.0, z = 13.3, rot = 90, type = "low"},
        {x = 2480.0, y = -1665.0, z = 13.3, rot = 0, type = "high"},
    }
}

local createdElements = {}

-- Limpa todos os elementos criados anteriormente
function clearAllNodes()
    for _, el in ipairs(createdElements) do
        if isElement(el) then destroyElement(el) end
    end
    createdElements = {}
end

-- Carrega nós customizados se existirem
function loadCustomNodes()
    if fileExists("maps/custom_nodes.json") then
        local file = fileOpen("maps/custom_nodes.json")
        if file then
            local content = fileRead(file, fileGetSize(file))
            fileClose(file)
            
            local customData = fromJSON(content)
            if customData then
                -- Mescla paths
                if customData.paths then
                    for _, p in ipairs(customData.paths) do
                        table.insert(defaultNodes.paths, p)
                    end
                end
                -- Mescla covers
                if customData.covers then
                    for _, c in ipairs(customData.covers) do
                        table.insert(defaultNodes.covers, c)
                    end
                end
                outputDebugString("[BotNPC] Nós customizados carregados com sucesso (JSON).")
            end
        end
    elseif fileExists("maps/custom_nodes.lua") then
        -- Tenta carregar o arquivo .lua como uma tabela se possível, mas JSON é preferível.
        -- Para evitar o erro de loadstring, vamos apenas avisar que o formato .lua é depreciado.
        outputDebugString("[BotNPC] AVISO: maps/custom_nodes.lua detectado, mas loadstring está bloqueado. Use .json.", 2)
    end
    
    -- Após carregar, cria os elementos físicos
    clearAllNodes()
    createDefaultNodes()
end
addEventHandler("onResourceStart", resourceRoot, loadCustomNodes)

function getMapCovers()
    return defaultNodes.covers or {}
end

function createDefaultNodes()
    -- Em vez de criar objetos físicos (2993), agora usamos apenas elementos lógicos 'pathpoint'
    -- Isso remove os markers/objetos visíveis e melhora a performance.
    for i, nodeData in ipairs(defaultNodes.paths) do
        local node = createElement("pathpoint")
        if node then
            setElementPosition(node, nodeData.x, nodeData.y, nodeData.z)
            setElementID(node, nodeData.id or ("node_" .. i))
            if nodeData.connections then
                setElementData(node, "connections", nodeData.connections, true)
            end
            table.insert(createdElements, node)
        end
    end
    
    -- Pontos de cover continuam como colshapes para detecção física de IA
    for i, cover in ipairs(defaultNodes.covers) do
        local col = createColSphere(cover.x, cover.y, cover.z, 1.5)
        if col then
            setElementData(col, "isCover", true, true)
            setElementData(col, "coverData", cover, true)
            table.insert(createdElements, col)
        end
    end
end

outputDebugString("[BotNPC] Default nodes carregado")