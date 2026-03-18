--=====================================================
--  INTERIOR INFECTION SYSTEM
--=====================================================

local interiorZones = {}
local intPlayerContribution = {}

--=====================================================
-- CONFIGURAÇÕES
--=====================================================

local ZONE_COLOR = {255, 0, 0, 120}
local ZONE_COOLDOWN = 60 * 60 * 1000 -- 1 Hora de cooldown
local REMOVE_DELAY = 1000 

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

local function getSkinsForType(typeName)
    return BOT_TYPES[typeName] and BOT_TYPES[typeName].skins or {9, 43, 70}
end

--=====================================================
-- NOTIFICAÇÃO
--=====================================================

local function sendNotification(player, msg, type)
    if exports["[CD]_DxMessages"] then
        exports["[CD]_DxMessages"]:DataShowCreateNotification(player, msg, type or "info")
    else
        outputChatBox(msg, player, 255, 255, 255, true)
    end
end

local function sendCityAlert(msg)
    for _, p in ipairs(getElementsByType("player")) do
        sendNotification(p, msg, "warning")
    end
    outputChatBox("#FF4444[ASTRALIS] #FFFFFF" .. msg, root, 255, 255, 255, true)
end

local function debugPrint(...)
    if not DEBUG_MODE then return end
    local txt = ""
    for _, v in ipairs({...}) do
        txt = txt .. " " .. tostring(v)
    end
    outputDebugString("[INT-ZONE] " .. txt)
end

--=====================================================
-- SPAWN DE BOTS
--=====================================================

local function spawnBots(zoneId)
    local z = interiorZones[zoneId]
    if not z or z.isCleared or z.isSpawning then return 0 end
    
    debugPrint("Iniciando spawnBots para a zona: " .. z.name)
    
    if not exports.BotNPC then
        outputDebugString("❌ ERRO: Recurso BotNPC não encontrado ou não exporta funções!")
        return 0
    end
    
    z.isSpawning = true
    local spawned = 0
    
    for i, pt in ipairs(z.spawnPoints) do
        local sx, sy, sz, rot, botType, health, damage = pt[1], pt[2], pt[3], pt[4], pt[5], pt[6], pt[7]
        
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

        debugPrint(string.format("Tentando criar bot em %.2f, %.2f, %.2f (Dim: %d, Int: %d)", sx, sy, sz, z.dimension, z.interior))

        local bot = exports.BotNPC:createBot(
            sx, sy, sz,
            rot or math.random(360),
            finalModel,
            botType or "zombie",
            z.dimension or 0,
            z.interior or 0,
            { health = health, meleeDamage = damage }
        )
        
        if bot and isElement(bot) then
            debugPrint("Bot criado com sucesso! Element: " .. tostring(bot))
            setElementData(bot, "interiorZoneID", zoneId) -- CHAVE ÚNICA PARA INTERIORES
            setElementData(bot, "botType", botType or "normal")
            
            -- Reforça interior e dimensão
            setElementInterior(bot, z.interior or 0)
            setElementDimension(bot, z.dimension or 0)
            
            -- Aplica os dados da skin customizada se necessário
            if isCustom then
                setElementData(bot, dataName, skin)
                setElementData(bot, baseDataName, finalModel)
            end
            
            table.insert(z.activeBots, bot)
            spawned = spawned + 1
        else
            debugPrint("❌ Falha ao criar bot via BotNPC:createBot")
        end
    end
    
    z.isSpawning = false
    if spawned > 0 then
        debugPrint(string.format("✅ Spawnou %d bots em %s", spawned, z.name))
        -- Notifica jogadores na zona
        for p, _ in pairs(z.playersInZone) do
            if isElement(p) then
                sendNotification(p, "⚠️ " .. spawned .. " infectados surgiram!", "warning")
            end
        end
    end
    
    return spawned
end

--=====================================================
-- REMOVER BOTS
--=====================================================

local function removeAllBots(zoneId)
    local z = interiorZones[zoneId]
    if not z then return end
    
    for i = #z.activeBots, 1, -1 do
        local bot = z.activeBots[i]
        if isElement(bot) then
            setElementData(bot, "silentRemoval", true)
            if exports.BotNPC then
                exports.BotNPC:destroyBot(bot)
            else
                destroyElement(bot)
            end
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

local function calculateReward(zoneId, player, kills)
    local z = interiorZones[zoneId]
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

local function giveRewards(zoneId)
    local z = interiorZones[zoneId]
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
-- LÓGICA DE ENTRADA E SAÍDA (REFATORADO)
--=====================================================

local function handlePlayerEntry(player, zoneId)
    local zData = interiorZones[zoneId]
    if not zData then
        debugPrint("handlePlayerEntry: zoneId " .. tostring(zoneId) .. " não encontrada")
        return
    end
    
    if zData.isCleared then
        debugPrint("handlePlayerEntry: zona " .. zData.name .. " já está limpa")
        return
    end
    
    if zData.playersInZone[player] then
        debugPrint("handlePlayerEntry: player " .. getPlayerName(player) .. " já está na lista da zona " .. zData.name)
        return
    end
    
    zData.playersInZone[player] = true
    debugPrint("Player " .. getPlayerName(player) .. " registrado na zona " .. zData.name)
    
    -- Spawn imediato conforme solicitado (sem delay)
    if #zData.activeBots == 0 then
        spawnBots(zoneId)
    end
    
    sendNotification(player, "☣ Você entrou no interior infectado: " .. zData.name, "warning")
end

local function handlePlayerLeave(player, zoneId)
    local zData = interiorZones[zoneId]
    if not zData then return end
    
    zData.playersInZone[player] = nil
    
    -- Se não houver mais players na zona, remove os bots
    local playersCount = 0
    for p, _ in pairs(zData.playersInZone) do
        if isElement(p) then playersCount = playersCount + 1 end
    end
    
    if playersCount == 0 then
        removeAllBots(zoneId)
    end
end

--=====================================================
-- CRIAR ZONA DE INTERIOR
--=====================================================

local function createInteriorZone(name, x, y, z, radius, interior, dimension, spawnPoints)
    local id = #interiorZones + 1
    
    -- Criamos o col apenas para referência visual/debug ou outras lógicas se necessário,
    -- mas o spawn agora é via evento de TP do Interior System.
    local col = createColCircle(x, y, radius)
    setElementInterior(col, interior or 0)
    setElementDimension(col, dimension or 0)
    
    interiorZones[id] = {
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
    
    debugPrint("✅ Zona de interior registrada: " .. name .. " (Int: " .. interior .. ", Dim: " .. dimension .. ")")
end

--=====================================================
-- GATILHOS DO SISTEMA DE INTERIOR (CD_Interior_System)
--=====================================================

addEvent("CD_Interior:OnPlayerEnter", true)
addEventHandler("CD_Interior:OnPlayerEnter", root, function(label, interior, dimension)
    local player = source
    debugPrint(string.format("Recebido OnPlayerEnter: %s (Int: %d, Dim: %d)", label, interior, dimension))
    
    for id, z in pairs(interiorZones) do
        -- Busca pelo interior e dimensão (ou pelo nome se preferir)
        if z.interior == interior and z.dimension == dimension then
            handlePlayerEntry(player, id)
        end
    end
end)

addEvent("CD_Interior:OnPlayerExit", true)
addEventHandler("CD_Interior:OnPlayerExit", root, function(label, interior, dimension)
    local player = source
    debugPrint(string.format("Recebido OnPlayerExit: %s", label))
    
    for id, z in pairs(interiorZones) do
        if z.playersInZone[player] then
            handlePlayerLeave(player, id)
        end
    end
end)

--=====================================================
-- MORTE DE BOT
--=====================================================

addEventHandler("onBotWasted", root, function(killer)
    local zoneId = getElementData(source, "interiorZoneID") -- CHAVE ESPECÍFICA PARA INTERIORES
    if not zoneId then return end
    
    local z = interiorZones[zoneId]
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
        -- local botType = getElementData(source, "botType") or "normal"
        -- local botName = BOT_TYPES[botType] and BOT_TYPES[botType].name or "Infectado"
        -- sendNotification(killer, "💀 Você eliminou um " .. botName .. "!", "info")
    end
    
    z.killsDone = z.killsDone + 1
    local remaining = z.totalKillsRequired - z.killsDone
    
    if remaining <= 0 then
        -- Limpar Zona
        z.isCleared = true
        local contributors = {}
        for player, kills in pairs(z.playerContributions) do
            if isElement(player) and kills > 0 then
                table.insert(contributors, (getPlayerName(player):gsub("#%x%x%x%x%x%x", "")))
            end
        end
        
        if #contributors >= 0 then
            local names = table.concat(contributors, ", ")
            sendCityAlert("✅ O interior " .. z.name .. " foi limpa por: " .. names .. "!")
        else
            sendCityAlert("✅ O interior " .. z.name .. " está seguro novamente!")
        end
        
        removeAllBots(zoneId)
        giveRewards(zoneId)
        
        setTimer(function()
            local rz = interiorZones[zoneId]
            if not rz then return end
            rz.isCleared = false
            rz.killsDone = 0
            rz.playerContributions = {}
            sendCityAlert("☣️ A infestação retornou ao interior: " .. rz.name .. "!")
            
            local playersIn = 0
            for p, _ in pairs(rz.playersInZone) do
                if isElement(p) then playersIn = playersIn + 1 end
            end
            if playersIn > 0 then
                spawnBots(zoneId)
            end
        end, ZONE_COOLDOWN, 1)
    end
end)


local function destroyAllInteriorZones()
    debugPrint("Limpando todos os interiores e bots de interior...")
    
    for id, z in pairs(interiorZones) do
        removeAllBots(id)
        if isElement(z.col) then destroyElement(z.col) end
    end

    local allPeds = getElementsByType("ped")
    
    if exports.BotNPC and exports.BotNPC.getBots then
        local botList = exports.BotNPC:getBots()
        for _, b in ipairs(botList) do
            local found = false
            for _, p in ipairs(allPeds) do
                if p == b then found = true break end
            end
            if not found then table.insert(allPeds, b) end
        end
    end

    for _, ped in ipairs(allPeds) do
        if isElement(ped) and getElementData(ped, "interiorZoneID") then
            if exports.BotNPC then
                exports.BotNPC:destroyBot(ped)
            else
                destroyElement(ped)
            end
        end
    end
    
    interiorZones = {}
end

--=====================================================
-- EVENTOS DE PLAYER
--=====================================================

addEventHandler("onPlayerQuit", root, function()
    for id, z in pairs(interiorZones) do
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
    destroyAllInteriorZones()
end)

addEventHandler("onResourceStart", resourceRoot, function()
    -- Limpeza de segurança no início para evitar duplicação em caso de restart forçado
    destroyAllInteriorZones()
    
    -- Exemplo de criação de interior infectado
    createInteriorZone(
        "Motel Vermelho", 
        2221.015, -1150.11, 1025.797, 
        10, 15, 0,
        {
            {2223.856, -1142.555, 1025.797, 180, "zombie_rynner", 150, 40},
            {2228.136, -1144.45, 1025.797, 180, "zombie_rynner", 150, 40},
            {2227.878, -1138.918, 1029.797, 180, "zombie_rynner", 150, 40},
            {2252.29, -1159.648, 1029.797, 180, "zombie_rynner", 150, 40},
            {2246.867, -1194.677, 1029.797, 180, "zombie_rynner", 350, 45},
            {2195.551, -1192.951, 1029.804, 180, "zombie_rynner", 150, 40},
            {2186.771, -1180.222, 1033.797, 180, "zombie_rynner", 150, 40},
            {2203.71, -1178.251, 1029.797, 180, "zombie_rynner", 150, 40},
            {2198.857, -1172.867, 1029.804, 180, "zombie_rynner", 150, 40},
            {2191.997, -1144.238, 1029.797, 180, "zombie_rynner", 250, 45},
            {2197.622, -1147.338, 1033.797, 180, "zombie_rynner", 250, 45},
            {2185.001, -1153.58, 1029.797, 180, "zombie_rynner", 300, 45},
            {2225.988, -1176.291, 1029.797, 180, "zombie_rynner", 300, 45},
        }
    )
end)

--=====================================================
-- COMANDOS DE DEBUG
--=====================================================

addCommandHandler("testspawn", function(player)
    -- Apenas Admin
    local acc = getPlayerAccount(player)
    if isGuestAccount(acc) or not isObjectInACLGroup("user."..getAccountName(acc), aclGetGroup("Admin")) then 
        return 
    end
    
    local pInt, pDim = getElementInterior(player), getElementDimension(player)
    outputChatBox("Buscando zona para Int: " .. pInt .. " Dim: " .. pDim, player)
    
    local found = false
    for id, z in pairs(interiorZones) do
        if z.interior == pInt and z.dimension == pDim then
            outputChatBox("Zona encontrada: " .. z.name .. ". Forçando spawn...", player)
            spawnBots(id)
            found = true
        end
    end
    
    if not found then
        outputChatBox("Nenhuma zona configurada para este interior/dimensão.", player)
    end
end)