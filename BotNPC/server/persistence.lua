-- server/persistence.lua
-- Sistema de salvamento

persistence = {}

persistence.saveFile = "botnpcsave.json"
persistence.binSaveFile = "botnpcsave.bin"
persistence.autoSaveEnabled = true

function persistence.saveBots()
    local botsToSave = {}
    
    for bot, data in pairs(botManager.bots) do
        if isElement(bot) and data.state ~= "dead" then
            local x, y, z = getElementPosition(bot)
            local rot = getPedRotation(bot)
            local dimension = getElementDimension(bot)
            local interior = getElementInterior(bot)
            local health = getElementHealth(bot)
            local skin = getElementModel(bot)
            local botType = getElementData(bot, "bot:type") or "bandit"
            
            table.insert(botsToSave, {
                x = x, y = y, z = z,
                rot = rot,
                skin = skin,
                health = health,
                dimension = dimension,
                interior = interior,
                botType = botType
            })
        end
    end
    
    -- Versão Binária (Muito mais leve)
    local file = fileCreate(persistence.binSaveFile)
    if file then
        -- Header: Quantidade de bots (int32)
        fileWrite(file, dataToBytes("i", #botsToSave))
        
        for _, b in ipairs(botsToSave) do
            -- Formato: 3 floats (pos), 1 float (rot), 3 ints (skin, dim, int), 1 float (hp), string (type)
            -- Como o bytedata.lua que temos suporta strings de tamanho fixo 'c', mas o tipo pode variar, 
            -- vamos salvar o tipo como uma string simples separada ou mapear para IDs.
            -- Para manter simples e compatível com o seu bytedata.lua:
            local botBytes = dataToBytes("ffffiiiif", b.x, b.y, b.z, b.rz or b.rot, b.skin, b.dimension, b.interior, 0, b.health)
            fileWrite(file, botBytes)
            -- O tipo salvamos como string + null terminator
            fileWrite(file, b.botType .. "\0")
        end
        fileClose(file)
    end

    -- Mantém o JSON apenas como backup legível se necessário
    local jsonData = { bots = botsToSave, version = "1.1", timestamp = getRealTime().timestamp }
    local json = toJSON(jsonData, true)
    local jfile = fileCreate(persistence.saveFile)
    if jfile then
        fileWrite(jfile, json)
        fileClose(jfile)
    end
    
    outputDebugString("[BotNPC] " .. #botsToSave .. " bots salvos (Binário + JSON)")
    return true
end

function persistence.loadBots()
    local path = fileExists(persistence.binSaveFile) and persistence.binSaveFile or (fileExists(persistence.saveFile) and persistence.saveFile or nil)
    if not path then return false end
    
    if path:find("%.json") then
        -- Carregamento JSON legado
        local file = fileOpen(path)
        local json = fileRead(file, fileGetSize(file))
        fileClose(jfile)
        local data = fromJSON(json)
        if not data or not data.bots then return false end
        
        local count = 0
        for _, b in ipairs(data.bots) do
            local bot = botManager.createBot(b.x, b.y, b.z, b.rot, b.skin, b.botType, b.dimension, b.interior)
            if bot then
                setElementHealth(bot, b.health)
                count = count + 1
            end
        end
        outputDebugString("[BotNPC] " .. count .. " bots carregados via JSON")
        return true
    else
        -- Carregamento Binário Otimizado
        local file = fileOpen(path)
        if not file then return false end
        
        local size = fileGetSize(file)
        local countBytes = fileRead(file, 4)
        local totalBots = bytesToData("i", countBytes)
        local loadedCount = 0
        
        for i = 1, totalBots do
            -- Lemos os dados fixos (9 campos: 4f + 4i + 1f = 36 bytes)
            local botBytes = fileRead(file, 36)
            local x, y, z, rot, skin, dim, int, _, health = bytesToData("ffffiiiif", botBytes)
            
            -- Lemos o tipo (até o null terminator)
            local botType = ""
            while true do
                local char = fileRead(file, 1)
                if char == "\0" or char == "" then break end
                botType = botType .. char
            end
            
            local bot = botManager.createBot(x, y, z, rot, skin, botType, dim, int)
            if bot then
                setElementHealth(bot, health)
                loadedCount = loadedCount + 1
            end
        end
        fileClose(file)
        outputDebugString("[BotNPC] " .. loadedCount .. " bots carregados via Binário")
        return true
    end
end

function persistence.autoSave()
    if persistence.autoSaveEnabled then
        persistence.saveBots()
    end
end

function persistence.toggleAutoSave(enabled)
    persistence.autoSaveEnabled = enabled
end

outputDebugString("[BotNPC] Persistence carregado")