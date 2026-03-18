--=====================================================
--  ZOMBIE ZONE SYSTEM (OPEN WORLD)
--=====================================================

local zombieZones = {}
local playerContribution = {}

--=====================================================
-- CONFIGURAÇÕES
--=====================================================

local ZONE_COLOR = {255, 0, 0, 120}
local ZONE_COOLDOWN = 15 * 60 * 1000 
local REMOVE_DELAY = 1000 

local ESCALATION_TIME = 15 * 60 * 1000 
local GROWTH_STEPS = 5 

local NOTIFY_KILL_STEP = 5
local DEBUG_MODE = true 

local BOTS_PER_PLAYER = 5 
local isInitializing = false -- Trava de segurança para restart

--=====================================================
-- INTERFACE TUNNEL (CLIENT UI)
--=====================================================

local clientUI = Tunnel.get("ZombieUI")

--=====================================================
-- LISTA DE SKINS
--=====================================================

local ZOMBIE_SKINS = {
    [9] = true,   
    [43] = true,  
    [70] = true,  
    -- [1001] = true, -- Skin customizada exemplo (ID do CD_BaixarMODS)
}

local function getAvailableSkins()
    local skins = {}
    for skinId, _ in pairs(ZOMBIE_SKINS) do
        table.insert(skins, skinId)
    end
    return skins
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
    outputDebugString("[ZONE] " .. txt)
end

--=====================================================
-- FILTRO DE PONTOS DE SPAWN
--=====================================================

local function filterSpawnPoints(zoneId)
    local z = zombieZones[zoneId]
    if not z then return end
    
    z.spawnPoints = {}
    
    for _, pt in ipairs(z.allSpawnPoints) do
        local dist = getDistanceBetweenPoints2D(
            z.center[1], z.center[2],
            pt[1], pt[2]
        )
        
        if dist <= z.currentRadius then
            table.insert(z.spawnPoints, pt)
        end
    end
end

--=====================================================
-- CRIAR ZONA
--=====================================================
local function spawnBots(zoneId, amount)
    local z = zombieZones[zoneId]
    if not z or amount <= 0 or z.isCleared then return 0 end
    
    -- Se for mais de 1 bot, escalonamos o spawn para evitar lag/queda de FPS
    if amount > 1 then
        local count = 0
        setTimer(function()
            if not z.isCleared then
                spawnBots(zoneId, 1)
            end
        end, 100, amount)
        return amount
    end

    local spawned = 0
    local remaining = z.totalKillsRequired - z.killsDone
    
    -- amount aqui será sempre 1 devido ao escalonamento acima
    for i = 1, amount do
        local sx, sy, sz
        
        if #z.spawnPoints > 0 then
            local pt = z.spawnPoints[math.random(#z.spawnPoints)]
            sx, sy, sz = pt[1], pt[2], pt[3]
        else
            local angle = math.random() * math.pi * 2
            local dist = math.random() * z.currentRadius * 0.8
            
            sx = z.center[1] + math.cos(angle) * dist
            sy = z.center[2] + math.sin(angle) * dist
            sz = z.center[3]
        end
        
        local skin = z.skins[math.random(#z.skins)]
        
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
            math.random(360),
            finalModel,
            "zombie_rynner",
            0, 0
        )
        
        if bot then
            setElementData(bot, "zoneID", zoneId)
            
            if isCustom then
                setElementData(bot, dataName, skin)
                setElementData(bot, baseDataName, finalModel)
            end
            
            table.insert(z.activeBots, bot)
            spawned = spawned + 1
        end
    end
    
    return spawned
end

--=====================================================
-- REMOVER BOTS EXCEDENTES
--=====================================================

local function removeExcessBots(zoneId, amount)
    local z = zombieZones[zoneId]
    if not z or amount <= 0 then return end
    
    local removed = 0
    for i = #z.activeBots, 1, -1 do
        local bot = z.activeBots[i]
        if isElement(bot) then
            setElementData(bot, "silentRemoval", true) 
            exports.BotNPC:destroyBot(bot)
            table.remove(z.activeBots, i)
            removed = removed + 1
        else
            table.remove(z.activeBots, i)
        end
        
        if removed >= amount then break end
    end
    
    debugPrint(string.format("❌ Removeu %d bots em %s", removed, z.name))
end

--=====================================================
-- RECOMPENSAS
--=====================================================

local function calculateReward(zoneId, player, kills)
    local z = zombieZones[zoneId]
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
    local z = zombieZones[zoneId]
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
-- CRESCIMENTO GRADUAL DA ZONA
--=====================================================

local function startGradualGrowth(zoneId)
    local z = zombieZones[zoneId]
    if not z or z.isCleared then return end
    
    z.currentGrowthStep = 0
    z.stepRadius = (z.maxRadius - z.originalRadius) / GROWTH_STEPS
    
    if z.growthTimer then
        killTimer(z.growthTimer)
    end
    
    z.growthTimer = setTimer(function()
        if z.isCleared then
            if z.growthTimer then
                killTimer(z.growthTimer)
                z.growthTimer = nil
            end
            return
        end
        
        z.currentGrowthStep = z.currentGrowthStep + 1
        
        if z.currentGrowthStep <= GROWTH_STEPS then
            z.currentRadius = z.originalRadius + (z.stepRadius * z.currentGrowthStep)
            
            if isElement(z.col) then
                setColShapeRadius(z.col, z.currentRadius)
            end
            
            if isElement(z.radar) then
                destroyElement(z.radar)
            end
            
            z.radar = createRadarArea(
                z.center[1] - z.currentRadius,
                z.center[2] - z.currentRadius,
                z.currentRadius * 2,
                z.currentRadius * 2,
                ZONE_COLOR[1], ZONE_COLOR[2], ZONE_COLOR[3], ZONE_COLOR[4]
            )
            
            filterSpawnPoints(zoneId)
            
            sendCityAlert(string.format("⚠️ A zona %s está se expandindo! (Etapa %d/%d)",
                z.name, z.currentGrowthStep, GROWTH_STEPS))
        end
        
        if z.currentGrowthStep >= GROWTH_STEPS then
            if z.growthTimer then
                killTimer(z.growthTimer)
                z.growthTimer = nil
            end
            sendCityAlert("💀 A zona " .. z.name .. " atingiu seu tamanho máximo!")
        end
        
    end, ESCALATION_TIME / GROWTH_STEPS, GROWTH_STEPS)
end

--=====================================================
-- LIMPAR ZONA
--=====================================================

local function clearZone(zoneId)
    local z = zombieZones[zoneId]
    if not z then return end
    
    z.isCleared = true
    
    if z.growthTimer then
        killTimer(z.growthTimer)
        z.growthTimer = nil
    end
    
    for p, _ in pairs(z.playersInZone) do
        if isElement(p) then
            setTimer(function(player)
                if isElement(player) then
                    clientUI.show(player, false)
                end
            end, 5000, 1, p)
        end
    end
    
    local contributors = {}
    for player, kills in pairs(z.playerContributions) do
        if isElement(player) and kills > 0 then
            table.insert(contributors, (getPlayerName(player):gsub("#%x%x%x%x%x%x", "")))
        end
    end
    
    if #contributors > 0 then
        local names = table.concat(contributors, ", ")
        sendCityAlert("✅ A zona " .. z.name .. " foi limpa por: " .. names .. "!")
    else
        sendCityAlert("✅ Cidadão de Astralis limparam a zona " .. z.name .. "!")
    end
    
    for _, bot in ipairs(z.activeBots) do
        if isElement(bot) then
            setElementData(bot, "silentRemoval", true)
            exports.BotNPC:destroyBot(bot)
        end
    end
    z.activeBots = {}
    
    giveRewards(zoneId)
    
    if isElement(z.radar) then
        setRadarAreaColor(z.radar, 0, 255, 0, 120)
        setTimer(function()
            if isElement(z.radar) then
                destroyElement(z.radar)
            end
        end, 3000, 1)
    end
    
    setTimer(function()
        local function respawnZone(zid)
            local rz = zombieZones[zid]
            if not rz then return end
            
            rz.isCleared = false
            rz.killsDone = 0
            rz.currentRadius = rz.originalRadius
            rz.playerContributions = {}
            
            if isElement(rz.col) then
                setColShapeRadius(rz.col, rz.currentRadius)
            end
            
            if isElement(rz.radar) then
                destroyElement(rz.radar)
            end
            
            rz.radar = createRadarArea(
                rz.center[1] - rz.currentRadius,
                rz.center[2] - rz.currentRadius,
                rz.currentRadius * 2,
                rz.currentRadius * 2,
                ZONE_COLOR[1], ZONE_COLOR[2], ZONE_COLOR[3], ZONE_COLOR[4]
            )
            
            sendCityAlert("☣️ A infestação retornou em " .. rz.name .. "!")
            
            filterSpawnPoints(zid)
            
            local playersIn = 0
            for p, _ in pairs(rz.playersInZone) do
                if isElement(p) then playersIn = playersIn + 1 end
            end
            
            spawnBots(zid, rz.initialBots + (playersIn * BOTS_PER_PLAYER))
        end
        respawnZone(zoneId)
    end, ZONE_COOLDOWN, 1)
end

--=====================================================
-- CRIAR ZONA
--=====================================================

local function createZombieZone(name, x, y, z, initialRadius, maxRadius, skins, spawnPoints, totalKills, initialBots)
    local id = #zombieZones + 1
    
    local col = createColCircle(x, y, initialRadius)
    
    local radar = createRadarArea(
        x - initialRadius, y - initialRadius,
        initialRadius * 2, initialRadius * 2,
        ZONE_COLOR[1], ZONE_COLOR[2], ZONE_COLOR[3], ZONE_COLOR[4]
    )
    
    zombieZones[id] = {
        id = id,
        name = name,
        col = col,
        radar = radar,
        center = {x, y, z},
        originalRadius = initialRadius,
        currentRadius = initialRadius,
        maxRadius = maxRadius or initialRadius,
        skins = skins,
        allSpawnPoints = spawnPoints or {},
        spawnPoints = {},
        totalKillsRequired = totalKills or 100,
        killsDone = 0,
        initialBots = initialBots or 10,
        activeBots = {},
        playersInZone = {},
        isCleared = false,
        playerContributions = {},
        growthTimer = nil
    }
    
    filterSpawnPoints(id)
    
    sendCityAlert("☣️ Infestação detectada em " .. name .. "!")
    
    addEventHandler("onColShapeHit", col, function(element)
        if getElementType(element) ~= "player" then return end
        local zData = zombieZones[id]
        if zData.isCleared then return end
        
        -- Open World zones only work in Dimension 0 and Interior 0
        if getElementInterior(element) ~= 0 or getElementDimension(element) ~= 0 then return end
        
        zData.playersInZone[element] = true
        
        -- Só spawna bots extras se NÃO estiver inicializando o recurso
        if not isInitializing then
            spawnBots(id, BOTS_PER_PLAYER)
        end
        
        sendNotification(element, "☣ Você entrou na zona infectada " .. name .. "!", "warning")
        clientUI.show(element, true)
        clientUI.update(element, zData.killsDone, zData.totalKillsRequired)
    end)
    
    addEventHandler("onColShapeLeave", col, function(element)
        if getElementType(element) ~= "player" then return end
        local zData = zombieZones[id]
        
        if zData.playersInZone[element] then
            zData.playersInZone[element] = nil
            removeExcessBots(id, BOTS_PER_PLAYER)
            clientUI.show(element, false)
        end
    end)
    
    if maxRadius > initialRadius then
        startGradualGrowth(id)
    end
    
    spawnBots(id, zombieZones[id].initialBots)
end

--=====================================================
-- MORTE DE BOT
--=====================================================

addEventHandler("onBotWasted", root, function(killer)
    -- Ignora eventos de morte se o recurso estiver inicializando
    if isInitializing then return end

    local zoneId = getElementData(source, "zoneID")
    if not zoneId then return end
    
    local z = zombieZones[zoneId]
    if not z or z.isCleared then return end
    
    -- Se o bot foi removido por cleanup do script antigo ou novo, não faz nada
    if getElementData(source, "silentRemoval") then
        for i, bot in ipairs(z.activeBots) do
            if bot == source then
                table.remove(z.activeBots, i)
                break
            end
        end
        return
    end
    
    -- Remove da lista de bots ativos da zona atual
    local found = false
    for i, bot in ipairs(z.activeBots) do
        if bot == source then
            table.remove(z.activeBots, i)
            found = true
            break
        end
    end
    
    -- Se o bot não estava na lista desta zona (era um bot órfão de um restart anterior),
    -- nós ignoramos a morte dele para não spawnar duplicado.
    if not found then 
        debugPrint("Ignorando morte de bot órfão para evitar duplicação.")
        return 
    end
    
    if isElement(killer) and getElementType(killer) == "player" then
        z.playerContributions[killer] = (z.playerContributions[killer] or 0) + 1
    end
    
    z.killsDone = z.killsDone + 1
    
    local remaining = z.totalKillsRequired - z.killsDone
    
    for p, _ in pairs(z.playersInZone) do
        if isElement(p) then
            clientUI.update(p, z.killsDone, z.totalKillsRequired)
        end
    end
    
    if remaining > 0 then
        spawnBots(zoneId, 1)
    else
        clearZone(zoneId)
    end
end)

--=====================================================
-- DESTRUIR TODAS AS ZONAS
--=====================================================

local function destroyAllZombieZones()
    debugPrint("Limpando todas as zonas e bots de mundo aberto...")
    
    for id, z in pairs(zombieZones) do
        -- Destrói os bots da tabela de cada zona
        for _, bot in ipairs(z.activeBots) do
            if isElement(bot) then
                setElementData(bot, "silentRemoval", true) -- ESSENCIAL: Evita que o onBotWasted crie novos bots
                if exports.BotNPC then
                    exports.BotNPC:destroyBot(bot)
                else
                    destroyElement(bot)
                end
            end
        end
        z.activeBots = {}
        
        if isElement(z.col) then destroyElement(z.col) end
        if isElement(z.radar) then destroyElement(z.radar) end
    end
    
    -- Varredura de segurança: Deleta qualquer Ped que tenha zoneID (bots órfãos)
    local allPeds = getElementsByType("ped")
    
    -- Se o BotNPC tiver o export getBots, usamos ele também para garantir
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
        if isElement(ped) and getElementData(ped, "zoneID") then
            setElementData(ped, "silentRemoval", true) -- Trava aqui também
            if exports.BotNPC then
                exports.BotNPC:destroyBot(ped)
            else
                destroyElement(ped)
            end
        end
    end
    
    zombieZones = {}
end

--=====================================================
-- EVENTOS DE PLAYER
--=====================================================

addEventHandler("onPlayerQuit", root, function()
    for id, z in pairs(zombieZones) do
        if z.playersInZone[source] then
            z.playersInZone[source] = nil
            removeExcessBots(id, BOTS_PER_PLAYER)
        end
    end
end)

--=====================================================
-- EVENTOS DE RESOURCE
--=====================================================

addEventHandler("onResourceStop", resourceRoot, function()
    destroyAllZombieZones()
end)

addEventHandler("onResourceStart", resourceRoot, function()
    -- Ativa trava de inicialização
    isInitializing = true
    
    -- Limpeza de segurança no início para evitar duplicação em caso de restart forçado
    destroyAllZombieZones()
    
    createZombieZone(
        "Aero Porto Infestado - SF",
        -1500.597, -385.424, 15.822,
        50,  
        150, 
        getAvailableSkins(),
        {
            {-1420.057, -398.052, 5.978},
            {-1513.235, -275.492, 5.978},
            {-1546.379, -325.398, 12.378},
            {-1431.666, -308.936, 9.178},
            {-1540.263, -395.473, 9.052},
            {-1546.119, -331.539, 9.052},
            {-1484.233, -468.948, 12.252},
            {-1554.293, -439.97, 5.852},
            {-1583.774, -388.877, 10.569}
        },
        50, 
        15   
    )
    
    -- Desativa trava após 2 segundos (tempo suficiente para o MTA processar os ColShapes)
    setTimer(function()
        isInitializing = false
    end, 2000, 1)
end)