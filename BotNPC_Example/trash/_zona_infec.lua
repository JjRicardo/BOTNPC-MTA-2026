--=====================================================
--  INTERIOR INFECTION SYSTEM
--=====================================================

local botZones = {}
local playerContribution = {}

--=====================================================
-- CONFIGURAÇÕES
--=====================================================

local ZONE_COLOR = {255, 0, 0, 120}
local ZONE_COOLDOWN = 60 * 60 * 1000 -- 1 Hora de cooldown
local REMOVE_DELAY = 1000 
local SPAWN_DELAY = 5000 -- 5 Segundos de delay para spawn

local NOTIFY_KILL_STEP = 5
local DEBUG_MODE = true 

--=====================================================
-- TIPOS DE BOTS E SKINS
--=====================================================

local BOT_TYPES = {
    ["zombie"] = {
        skins = {9, 43, 70}, 
        name = "Infectado Clássico"
    },
    ["zombie_wakie"] = {
        skins = {9, 43, 70}, 
        name = "Infectado Lento"
    },
    ["zombie_walker"] = {
        skins = {9, 43, 70}, 
        name = "Infectado Andante"
    },
    ["zombie_rynner"] = {
        skins = {9, 43, 70}, 
        name = "Infectado Corredor"
    },
    ["toxic_zombie"] = {
        skins = {9, 43, 70}, 
        name = "Infectado Tóxico"
    },
    ["zombie_hunter"] = {
        skins = {1001}, 
        name = "Infectado Caçador"
    },
    ["heavy_boss"] = {
        skins = {1001}, 
        name = "Infectado Brutamontes (BOSS)"
    }
}

function getSkinsForType(typeName)
    return BOT_TYPES[typeName] and BOT_TYPES[typeName].skins or {9, 43, 70}
end

--=====================================================
-- NOTIFICAÇÃO
--=====================================================

function sendNotification(player, msg, type)
    if exports["[CD]_DxMessages"] then
        exports["[CD]_DxMessages"]:DataShowCreateNotification(player, msg, type or "info")
    else
        outputChatBox(msg, player, 255, 255, 255, true)
    end
end

function sendCityAlert(msg)
    for _, p in ipairs(getElementsByType("player")) do
        sendNotification(p, msg, "warning")
    end
    outputChatBox("#FF4444[ASTRALIS] #FFFFFF" .. msg, root, 255, 255, 255, true)
end

function debugPrint(...)
    if not DEBUG_MODE then return end
    local txt = ""
    for _, v in ipairs({...}) do
        txt = txt .. " " .. tostring(v)
    end
    outputDebugString("[ZONE] " .. txt)
end

--=====================================================
-- SPAWN DE BOTS
--=====================================================

function spawnBots(zoneId)
    local z = botZones[zoneId]
    if not z or z.isCleared or z.isSpawning then return 0 end
    
    z.isSpawning = true
    local spawned = 0
    
    for i, pt in ipairs(z.spawnPoints) do
        local sx, sy, sz, rot, botType = pt[1], pt[2], pt[3], pt[4], pt[5]
        
        local typeSkins = getSkinsForType(botType or "normal")
        local skin = typeSkins[math.random(#typeSkins)]
        
        -- Integração com sistema de skins customizadas [CD_BaixarMODS]
        local finalModel = skin
        local isCustom = false
        local dataName, baseDataName
        
        if exports["[CD_BaixarMODS]"] then
            local baseModel, custom, dName, bDName = exports["[CD_BaixarMODS]"]:checkModelID(skin, "ped")
            if tonumber(baseModel) then
                finalModel = baseModel
                isCustom = custom
                dataName = dName
                baseDataName = bDName
            end
        end

        local bot = exports.BotNPC:createBot(
            sx, sy, sz,
            rot or math.random(360),
            finalModel,
            botType or "zombie",
            z.interior or 0,
            z.dimension or 0
        )
        
        if bot then
            setElementData(bot, "zoneID", zoneId)
            setElementData(bot, "botType", botType or "normal")
            setElementInterior(bot, z.interior or 0)
            setElementDimension(bot, z.dimension or 0)
            
            -- Aplica os dados da skin customizada se necessário
            if isCustom then
                setElementData(bot, dataName, skin)
                setElementData(bot, baseDataName, finalModel)
            end
            
            table.insert(z.activeBots, bot)
            spawned = spawned + 1
        end
    end
    
    z.isSpawning = false
    if spawned > 0 then
        debugPrint(string.format("✅ Spawnou %d bots em %s", spawned, z.name))
    end
    
    return spawned
end

--=====================================================
-- REMOVER BOTS
--=====================================================

function removeAllBots(zoneId)
    local z = botZones[zoneId]
    if not z then return end
    
    for i = #z.activeBots, 1, -1 do
        local bot = z.activeBots[i]
        if isElement(bot) then
            setElementData(bot, "silentRemoval", true)
            exports.BotNPC:destroyBot(bot)
        end
        table.remove(z.activeBots, i)
    end
    
    if z.spawnTimer and isTimer(z.spawnTimer) then
        killTimer(z.spawnTimer)
        z.spawnTimer = nil
    end
    
    debugPrint(string.format("❌ Limpou todos os bots em %s", z.name))
end

--=====================================================
-- RECOMPENSAS
--=====================================================

function calculateReward(zoneId, player, kills)
    local z = botZones[zoneId]
    if not z then return end
    
    local contribution = (kills / z.totalKillsRequired) * 100
    local moneyReward = math.floor(100 * kills * 1.5)
    local expReward = math.floor(10 * kills * 1.2)
    
    if contribution >= 50 then
        moneyReward = moneyReward * 2
        expReward = expReward * 2
        sendNotification(player, "🏆 Bônus por alta contribuição! (+100%)", "success")
    elseif contribution >= 25 then
        moneyReward = moneyReward * 1.5
        expReward = expReward * 1.5
        sendNotification(player, "🏆 Bônus por boa contribuição! (+50%)", "success")
    end
    
    return moneyReward, expReward, contribution
end

function giveRewards(zoneId)
    local z = botZones[zoneId]
    if not z or not z.playerContributions then return end
    
    local sorted = {}
    for player, kills in pairs(z.playerContributions) do
        if isElement(player) and kills > 0 then
            table.insert(sorted, {player = player, kills = kills})
        end
    end
    
    if #sorted > 0 then
        table.sort(sorted, function(a, b) return a.kills > b.kills end)
        
        sendCityAlert("📊 Ranking da zona " .. z.name .. ":")
        for i, data in ipairs(sorted) do
            if i <= 5 then
                local name = getPlayerName(data.player):gsub("#%x%x%x%x%x%x", "")
                sendCityAlert(string.format("%dº %s - %d kills", i, name, data.kills))
            end
        end
        
        for _, data in ipairs(sorted) do
            local player = data.player
            local kills = data.kills
            local money, exp, contrib = calculateReward(zoneId, player, kills)
            sendNotification(player, string.format(
                "💰 Recompensa: $%d | EXP: %d | Contribuição: %.1f%%",
                money, exp, contrib
            ), "success")
        end
    end
    
    z.playerContributions = {}
end

--=====================================================
-- CRIAR ZONA DE INTERIOR
--=====================================================

function createInteriorZone(name, x, y, z, radius, interior, dimension, spawnPoints)
    local id = #botZones + 1
    
    local col = createColCircle(x, y, radius)
    setElementInterior(col, interior or 0)
    setElementDimension(col, dimension or 0)
    
    botZones[id] = {
        id = id,
        name = name,
        col = col,
        center = {x, y, z},
        interior = interior or 0,
        dimension = dimension or 0,
        radius = radius,
        spawnPoints = spawnPoints or {},
        totalKillsRequired = #spawnPoints,
        killsDone = 0,
        activeBots = {},
        playersInZone = {},
        isCleared = false,
        playerContributions = {},
        spawnTimer = nil,
        isSpawning = false
    }
    
    local zData = botZones[id]
    
    -- Evento de entrada
    addEventHandler("onColShapeHit", col, function(element)
        if getElementType(element) ~= "player" then return end
        if zData.isCleared then return end
        
        -- Verifica interior e dimensão
        if getElementInterior(element) ~= zData.interior or getElementDimension(element) ~= zData.dimension then
            return
        end
        
        zData.playersInZone[element] = true
        
        -- Delay de 5 segundos para spawnar os bots
        if not zData.spawnTimer and #zData.activeBots == 0 then
            sendNotification(element, "☣ Algo está se movendo... (5s)", "warning")
            zData.spawnTimer = setTimer(function()
                spawnBots(id)
                zData.spawnTimer = nil
            end, SPAWN_DELAY, 1)
        end
        
        sendNotification(element, "☣ Você entrou no interior infectado: " .. name, "warning")
        
        -- Sincronizar UI
        triggerClientEvent(element, "zombieUIShow", element, true)
        triggerClientEvent(element, "zombieUIUpdate", element, zData.killsDone, zData.totalKillsRequired)
    end)
    
    -- Evento de saída
    addEventHandler("onColShapeLeave", col, function(element)
        if getElementType(element) ~= "player" then return end
        
        zData.playersInZone[element] = nil
        
        -- Se não houver mais players na zona, remove os bots
        local playersCount = 0
        for p, _ in pairs(zData.playersInZone) do
            if isElement(p) then playersCount = playersCount + 1 end
        end
        
        if playersCount == 0 then
            removeAllBots(id)
        end
        
        -- Esconder UI
        triggerClientEvent(element, "zombieUIShow", element, false)
    end)
    
    debugPrint("✅ Zona de interior criada: " .. name)
end

--=====================================================
-- MORTE DE BOT
--=====================================================

addEventHandler("onBotWasted", root, function(killer)
    local zoneId = getElementData(source, "zoneID")
    if not zoneId then return end
    
    local z = botZones[zoneId]
    if not z or z.isCleared then return end
    
    -- Se o bot foi removido pelo sistema (player saiu), não conta kill
    if getElementData(source, "silentRemoval") then
        for i, bot in ipairs(z.activeBots) do
            if bot == source then
                table.remove(z.activeBots, i)
                break
            end
        end
        return
    end
    
    -- Remove da lista
    for i, bot in ipairs(z.activeBots) do
        if bot == source then
            table.remove(z.activeBots, i)
            break
        end
    end
    
    -- Registra kill se o killer for player
    if isElement(killer) and getElementType(killer) == "player" then
        z.playerContributions[killer] = (z.playerContributions[killer] or 0) + 1
        
        -- Alerta de kill para o jogador
        local botType = getElementData(source, "botType") or "normal"
        local botName = BOT_TYPES[botType] and BOT_TYPES[botType].name or "Infectado"
        sendNotification(killer, "💀 Você eliminou um " .. botName .. "!", "info")
    end
    
    z.killsDone = z.killsDone + 1
    local remaining = z.totalKillsRequired - z.killsDone
    
    -- Atualizar UI
    for p, _ in pairs(z.playersInZone) do
        if isElement(p) then
            triggerClientEvent(p, "zombieUIUpdate", p, z.killsDone, z.totalKillsRequired)
        end
    end
    
    if remaining <= 0 then
        clearZone(zoneId)
    end
end)

--=====================================================
-- LIMPAR ZONA
--=====================================================

function clearZone(zoneId)
    local z = botZones[zoneId]
    if not z then return end
    
    z.isCleared = true
    
    -- Sincronizar UI final
    for p, _ in pairs(z.playersInZone) do
        if isElement(p) then
            triggerClientEvent(p, "zombieUIUpdate", p, z.totalKillsRequired, z.totalKillsRequired)
            setTimer(function(player)
                if isElement(player) then
                    triggerClientEvent(player, "zombieUIShow", player, false)
                end
            end, 5000, 1, p)
        end
    end
    
    -- Notificação de limpeza
    local contributors = {}
    for player, kills in pairs(z.playerContributions) do
        if isElement(player) and kills > 0 then
            table.insert(contributors, getPlayerName(player):gsub("#%x%x%x%x%x%x", ""))
        end
    end
    
    if #contributors > 0 then
        local names = table.concat(contributors, ", ")
        sendCityAlert("✅ O interior " .. z.name .. " foi limpa por: " .. names .. "!")
    else
        sendCityAlert("✅ O interior " .. z.name .. " está seguro novamente!")
    end
    
    -- Limpa bots restantes (se houver)
    removeAllBots(zoneId)
    
    -- Dá as recompensas
    giveRewards(zoneId)
    
    -- Respawn após cooldown de 1 hora
    setTimer(function()
        respawnZone(zoneId)
    end, ZONE_COOLDOWN, 1)
end

--=====================================================
-- RESPAWN DA ZONA
--=====================================================

function respawnZone(zoneId)
    local z = botZones[zoneId]
    if not z then return end
    
    z.isCleared = false
    z.killsDone = 0
    z.playerContributions = {}
    
    sendCityAlert("☣️ A infestação retornou ao interior: " .. z.name .. "!")
    
    -- Se já houver players dentro, inicia o spawn delay
    local playersIn = 0
    for p, _ in pairs(z.playersInZone) do
        if isElement(p) then playersIn = playersIn + 1 end
    end
    
    if playersIn > 0 and not z.spawnTimer then
        z.spawnTimer = setTimer(function()
            spawnBots(zoneId)
            z.spawnTimer = nil
        end, SPAWN_DELAY, 1)
    end
end

--=====================================================
-- DESTRUIR TODAS AS ZONAS
--=====================================================

function destroyAllZones()
    for id, z in pairs(botZones) do
        removeAllBots(id)
        if isElement(z.col) then destroyElement(z.col) end
    end
    botZones = {}
end

--=====================================================
-- EVENTOS DE PLAYER
--=====================================================

addEventHandler("onPlayerQuit", root, function()
    for id, z in pairs(botZones) do
        if z.playersInZone[source] then
            z.playersInZone[source] = nil
            
            -- Se não houver mais players, remove bots
            local count = 0
            for p, _ in pairs(z.playersInZone) do
                if isElement(p) then count = count + 1 end
            end
            if count == 0 then removeAllBots(id) end
        end
    end
end)

--=====================================================
-- EVENTOS DE RESOURCE
--=====================================================

addEventHandler("onResourceStop", resourceRoot, function()
    destroyAllZones()
end)

addEventHandler("onResourceStart", resourceRoot, function()
    -- Exemplo de criação de interior infectado
    createInteriorZone(
        "Delegacia Abandonada", 
        246.7, 63.9, 1003.6, -- Centro do ColShape
        30,                  -- Raio do ColShape
        6,                   -- Interior
        1,                   -- Dimensão
        {
            -- {x, y, z, rot, tipo}
            {246.7, 63.9, 1003.6, 0, "zombie_wakie"},
            {250.0, 65.0, 1003.6, 90, "zombie_walker"},
            {243.0, 60.0, 1003.6, 180, "heavy_boss"},
        }
    )
end)