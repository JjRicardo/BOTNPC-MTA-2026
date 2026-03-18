-- Sistema de Zonas de Spawn para BotNPC

local botZones = {}

-- Cores para as áreas do mapa (para fácil identificação)
local ZONE_COLORS = {
    zombie_rynner = {255, 0, 0, 100},      -- Vermelho para zumbis
    bandit = {255, 150, 0, 100},         -- Laranja para bandidos
    guard = {0, 100, 255, 100},          -- Azul para guardas
    kungfu_master = {200, 0, 200, 100},   -- Roxo para lutadores
    default = {200, 200, 200, 80}        -- Cinza para outros
}

--[[=========================================================================
--    CRIAÇÃO E GERENCIAMENTO DE ZONAS
--===========================================================================]]

-- Função principal para criar uma zona de bots
function createBotZone(name, centerX, centerY, centerZ, radius, maxBots, botType, skin, dimension, interior, customData)
    dimension = dimension or 0
    interior = interior or 0

    local col = createColCircle(centerX, centerY, radius)
    setElementDimension(col, dimension)
    setElementInterior(col, interior)

    local zoneId = #botZones + 1
    
    -- Criar representação visual no radar/mapa
    local color = ZONE_COLORS[botType] or ZONE_COLORS.default
    local radarArea = createRadarArea(centerX - radius, centerY - radius, radius * 2, radius * 2, color[1], color[2], color[3], color[4], root)
    setElementDimension(radarArea, dimension)
    setElementData(radarArea, "zoneName", name)

    botZones[zoneId] = {
        id = zoneId,
        name = name,
        col = col,
        radarArea = radarArea,
        center = {centerX, centerY, centerZ},
        radius = radius,
        maxBots = maxBots,
        botType = botType,
        skin = skin,
        dimension = dimension,
        interior = interior,
        customData = customData, -- Armazena os dados customizados (vida, dano, etc)
        activeBots = {}
    }
    
    -- Timer para verificar e repovoar a zona periodicamente
    setTimer(refreshBotZone, 30000, 0, zoneId)
    
    -- Evento para notificar o jogador ao entrar na área
    addEventHandler("onColShapeHit", col, function(element)
        if getElementType(element) == "player" then
            outputChatBox("[ZONA] Você entrou em: " .. name, element, color[1], color[2], color[3])
            refreshBotZone(zoneId) -- Força uma verificação de spawn
        end
    end)

    outputDebugString("[BotNPC Example] Zona de perigo '" .. name .. "' criada!")
    return zoneId
end

-- Verifica e repovoa a zona com bots se necessário
function refreshBotZone(zoneId)
    local z = botZones[zoneId]
    if not z then return end
    
    -- 1. Limpa bots que já morreram ou foram removidos
    for i = #z.activeBots, 1, -1 do
        if not isElement(z.activeBots[i]) then
            table.remove(z.activeBots, i)
        end
    end
    
    -- 2. Calcula quantos bots precisam ser criados
    local toSpawn = z.maxBots - #z.activeBots
    if toSpawn > 0 then
        local skins = (type(z.skin) == "table") and z.skin or {z.skin}
        
        for i = 1, toSpawn do
            -- Posição de spawn aleatória dentro do raio da zona
            local angle = math.random() * 2 * math.pi
            local dist = math.random() * (z.radius * 0.8) -- 80% do raio para não spawnar na borda
            local sx = z.center[1] + math.cos(angle) * dist
            local sy = z.center[2] + math.sin(angle) * dist
            
            -- Usa a função exportada do BotNPC para criar o bot com os dados customizados da zona
            local bot = exports.BotNPC:createBot(sx, sy, z.center[3], math.random(360), skins[math.random(#skins)], z.botType, z.dimension, z.interior, z.customData)
            
            if bot then
                table.insert(z.activeBots, bot)
            end
        end
        outputDebugString("[BotNPC Example] Zona '" .. z.name .. "' repovoada com " .. toSpawn .. " bots.")
    end
end

--[[=========================================================================
--    SISTEMA DE RECOMPENSAS
--===========================================================================]]

local BOT_REWARDS = {
    zombie_rynner = {min = 50, max = 150, msg = "Zumbi Rápido abatido! +$%d"},
    bandit = {min = 100, max = 300, msg = "Bandido neutralizado! +$%d"},
    guard = {min = 80, max = 200, msg = "Guarda corrupto eliminado! +$%d"},
    kungfu_master = {min = 500, max = 1000, msg = "Mestre de Kung Fu derrotado! +$%d"},
    default = {min = 20, max = 50, msg = "Inimigo abatido. +$%d"}
}

-- Ouve o evento onBotWasted que o BotNPC dispara
addEventHandler("onBotWasted", root, function(killer, botType, botData)
    if not killer or getElementType(killer) ~= "player" then return end

    local rewardCfg = BOT_REWARDS[botType] or BOT_REWARDS.default
    local reward = math.random(rewardCfg.min, rewardCfg.max)
    
    givePlayerMoney(killer, reward)
    outputChatBox(string.format(rewardCfg.msg, reward), killer, 100, 255, 100)
end)

--[[=========================================================================
--    COMANDOS DE TESTE
--===========================================================================]]

addCommandHandler("zonas", function(player)
    outputChatBox("Comandos de Zona: /criarzone, /limparzonas", player)
end)

addCommandHandler("criarzone", function(player, cmd, type)
    local x, y, z = getElementPosition(player)
    local d = getElementDimension(player)
    local i = getElementInterior(player)
    local bType = type or "zombie_rynner"
    
    createBotZone("Zona de Teste", x, y, z, 50, 8, bType, nil, d, i)
    outputChatBox("Zona de teste do tipo '" .. bType .. "' criada na sua posição!", player, 0, 255, 0)
end)

addCommandHandler("limparzonas", function(player)
    for id, z in pairs(botZones) do
        for _, bot in ipairs(z.activeBots) do
            if isElement(bot) then destroyElement(bot) end
        end
        if isElement(z.col) then destroyElement(z.col) end
        if isElement(z.radarArea) then destroyElement(z.radarArea) end
    end
    botZones = {}
    outputChatBox("Todas as zonas de bots foram removidas.", player, 255, 100, 100)
end)

--[[=========================================================================
--    CRIAÇÃO DAS ZONAS PREDEFINIDAS
--===========================================================================]]

function createPresetZones()
    -- Exemplo 1: Zumbis no Aeroporto Abandonado (Dimensão 0, Exterior)
    createBotZone("Quarentena do Aeroporto", -1400, -300, 14, 80, 15, "zombie_rynner", {92, 105, 106, 107}, 0, 0)

    -- Exemplo 2: Bandidos no Interior de um Armazém (Dimensão 1, Interior 3)
    createBotZone("Depósito da Máfia", 2487.9, -1665.5, 13.5, 25, 8, "bandit", {120, 121, 122}, 1, 3)

    -- Exemplo 3: Guardas protegendo uma área em outra dimensão (Dimensão 5, Exterior)
    createBotZone("Posto de Controle Secreto", 1550, -1700, 14, 40, 6, "guard_pub", {280, 281, 282}, 5, 0)
    
    -- Exemplo 4: Lutadores em um Dojo (Dimensão 0, Interior 6)
    createBotZone("Dojo Cobra Kai", 2013.8, -1024.5, 24.8, 15, 5, "kungfu_master", {59, 180}, 0, 0)

    -- Exemplo 5: Super Zumbis (Vida alta e dano alto)
    createBotZone("Horda de Mutantes", -2400, -600, 35, 50, 10, "zombie_rynner", {105, 106}, 0, 0, {
        health = 400,
        meleeDamage = 45
    })

    -- Exemplo 6: Posto Policial (Guarda Público que não sai da zona)
    createBotZone("Posto Policial", 1544, -1675, 13.5, 30, 4, "guard_pub", {280, 281}, 0, 0)

    -- Exemplo 7: Área de Treinamento de Elite (Bots com HP alto e táticas avançadas)
    createBotZone("Base de Elite", 2490, -1670, 13.3, 40, 5, "bandit", {285, 287}, 0, 0, {
        health = 300,
        meleeDamage = 35
    })
end

-- Inicia a criação das zonas quando o resource começa
addEventHandler("onResourceStart", resourceRoot, createPresetZones)
