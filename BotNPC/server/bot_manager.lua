-- server/bot_manager.lua
-- Gerenciador de bots

botManager = {}

-- Dados
botManager.bots = {}
botManager.botList = {}
botManager.botCount = 0
botManager.nextId = 1
botManager.maxBots = BOTNPC.CONSTANTS.MAX_BOTS
botManager.dimensionBots = {}

function botManager.init()
    outputDebugString("[BotNPC] BotManager inicializado")
end

function botManager.setMaxBots(max)
    botManager.maxBots = max
end

function botManager.createBot(x, y, z, rot, skin, botType, dimension, interior, customData)
    if botManager.botCount >= botManager.maxBots then
        outputDebugString("[BotNPC] Limite de bots atingido")
        return false
    end
    
    skin = skin or math.random(0, 300)
    rot = rot or 0
    botType = botType or "bandit"
    dimension = dimension or 0
    interior = interior or 0
    customData = type(customData) == "table" and customData or {}
    
    local bot = createPed(skin, x, y, z, rot)
    if not bot then return false end
    
    setElementDimension(bot, dimension)
    setElementInterior(bot, interior)
    
    -- Aplica defaults do tipo de bot (HP, Time, etc)
    if BOTNPC and BOTNPC.applyBotDefaults then
        BOTNPC.applyBotDefaults(bot, botType)
    end
    
    local profile = BOTNPC and BOTNPC.getTypeConfig and BOTNPC.getTypeConfig(botType)
    
    -- Vida Customizada: Prioridade para o parâmetro customData.health
    local initialHP = tonumber(customData.health) or (profile and profile.health) or 100
    setElementHealth(bot, initialHP)
    
    -- Dano Melee Customizado: Armazena no elementData para ser lido no combat_logic
    if tonumber(customData.meleeDamage) then
        setElementData(bot, "bot:meleeDamage", tonumber(customData.meleeDamage), false)
    end

    -- Alvo de Proteção Customizado (ex: Guardas Privados)
    if isElement(customData.protectTarget) then
        setElementData(bot, "bot:protectTarget", customData.protectTarget, true)
    end

    -- Define skill Hitman (999) para todas as armas para o bot segurar no estilo correto
    for stat = 69, 79 do
        setPedStat(bot, stat, 999)
    end

    -- Aplica o estilo de luta se definido no perfil
    if profile and profile.fightingStyle then
        setPedFightingStyle(bot, profile.fightingStyle)
    end

    -- Habilita Super Soco se configurado no perfil
    if profile and profile.superPunch then
        setElementData(bot, "bot:superPunch", true, true)
    end

    -- Configuração automática para Guardas Públicos e Snipers (Patrulha local)
    if botType == "guard_pub" then
        botManager.setBotProtectArea(bot, x, y, z, 40)
    elseif botType == "sniper" then
        botManager.setBotProtectArea(bot, x, y, z, 15) -- Snipers patrulham área menor
    end
    
    local id = botManager.nextId
    
    -- Equipa arma base se configurada no tipo
    if profile and profile.useRanged and profile.weapon then
        local weaponID = tonumber(profile.weapon)
        local ammo = tonumber(profile.ammo) or 500
        if weaponID and weaponID > 0 then
            giveWeapon(bot, weaponID, ammo, true)
            setPedWeaponSlot(bot, getSlotFromWeapon(weaponID))
            outputDebugString("[BotNPC] Arma " .. weaponID .. " entregue ao bot #" .. id)
        end
    end
    
    -- Marcação compatível com sistemas de IA/áudio
    setElementData(bot, "bot", true, false)
    setElementData(bot, "bot:id", id, false)
    setElementData(bot, "bot:isBot", true, false)
    setElementData(bot, "bot:type", botType, true) -- Exporta o tipo para o cliente
    
    -- Aplica o estilo de luta explicitly (Re-garante que o motor do GTA reconheça para o NPC)
    if profile and profile.fightingStyle then
        setPedFightingStyle(bot, profile.fightingStyle)
        setElementData(bot, "bot:fightingStyle", profile.fightingStyle, true)
    end
    
    botManager.nextId = botManager.nextId + 1
    
    botManager.bots[bot] = {
        id = id,
        skin = skin,
        botType = botType,
        health = initialHP,
        meleeDamage = tonumber(customData.meleeDamage),
        spawnPos = {x, y, z},
        dimension = dimension,
        interior = interior,
        createdAt = getTickCount(),
        state = "idle"
    }
    
    table.insert(botManager.botList, bot)
    botManager.botCount = botManager.botCount + 1
    
    -- Index por dimensão
    if not botManager.dimensionBots[dimension] then
        botManager.dimensionBots[dimension] = {}
    end
    botManager.dimensionBots[dimension][bot] = true
    
    outputDebugString("[BotNPC] Bot #" .. id .. " (" .. botType .. ") criado na dimensão " .. dimension)
    
    -- Notifica clientes (Otimizado com Bytedata)
    -- IMPORTANTE: Usamos resourceRoot como source para que o evento chegue a todos,
    -- mesmo que o bot esteja em outra dimensão/interior (MTA restringe sync de peds)
    local syncBytes = dataToBytes("iii", id, dimension, interior)
    triggerClientEvent(root, "bot:sync", resourceRoot, bot, syncBytes)
    
    return bot
end

function botManager.createBotsInArea(centerX, centerY, centerZ, radius, count, skin, botType, dimension)
    local spawned = {}
    dimension = dimension or 0
    botType = botType or "bandit"
    
    for i = 1, count do
        if botManager.botCount >= botManager.maxBots then break end
        
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * radius
        local x = centerX + math.cos(angle) * dist
        local y = centerY + math.sin(angle) * dist
        
        local bot = botManager.createBot(x, y, centerZ, math.random(0, 360), skin, botType, dimension)
        if bot then
            table.insert(spawned, bot)
        end
    end
    
    return spawned
end

function botManager.setBotProtectTarget(bot, target)
    if not isElement(bot) then return false end
    setElementData(bot, "bot:protectTarget", target, true)
    return true
end

function botManager.setBotProtectArea(bot, x, y, z, radius)
    if not isElement(bot) then return false end
    setElementData(bot, "bot:protectArea", {x, y, z, radius or 30}, true)
    return true
end

function botManager.destroyBot(bot, killer)
    if not isElement(bot) then return false end
    
    local data = botManager.bots[bot]
    if not data then
        destroyElement(bot)
        return false
    end
    
    -- Se já está marcado como morto, não repete
    if data.state == "dead" then return false end
    data.state = "dead"
    
    outputDebugString("[BotNPC] Bot #" .. data.id .. " entrou em estado de morte. Killer: " .. (isElement(killer) and getElementType(killer) or "N/A"))
    
    -- Notifica clientes para rodarem animação de morte (Otimizado)
    triggerClientEvent(root, "bot:onDeath", bot)
    
    -- Efeito de morte especial (Explosão, etc)
    if combatLogic and combatLogic.handleBotDeath then
        combatLogic.handleBotDeath(bot)
    end
    
    -- Dispara evento para outros resources (SERVER-SIDE)
    -- source = ped do bot
    -- argumentos: killer, botType, data
    triggerEvent("onBotWasted", bot, killer, data.botType, data)
    
    -- Se não estiver morto ainda (ex: destruição via comando), mata ele
    if not isPedDead(bot) then
        killPed(bot)
    end

    -- Delay antes de remover o elemento para deixar o corpo no chão (ex: 10 segundos)
    local deathDelay = BOTNPC.CONSTANTS and BOTNPC.CONSTANTS.DEATH_DELAY or 10000
    
    setTimer(function(b, id, dim)
        if isElement(b) then
            -- Remove da dimensão
            if botManager.dimensionBots[dim] then
                botManager.dimensionBots[dim][b] = nil
            end
            
            -- Remove das listas
            botManager.bots[b] = nil
            table.removeValue(botManager.botList, b)
            botManager.botCount = math.max(0, botManager.botCount - 1)
            
            destroyElement(b)
            outputDebugString("[BotNPC] Bot #" .. id .. " removido após delay de morte")
        end
    end, deathDelay, 1, bot, data.id, data.dimension)
    
    return true
end

function botManager.destroyAll()
    local count = 0
    for bot in pairs(botManager.bots) do
        if isElement(bot) then
            botManager.destroyBot(bot)
            count = count + 1
        end
    end
    return count
end

function botManager.destroyInDimension(dimension)
    local count = 0
    for bot in pairs(botManager.dimensionBots[dimension] or {}) do
        if isElement(bot) then
            botManager.destroyBot(bot)
            count = count + 1
        end
    end
    return count
end

function botManager.updateAll()
    for bot, data in pairs(botManager.bots) do
        if not isElement(bot) then
            botManager.destroyBot(bot)
        elseif getElementHealth(bot) <= 0 and data.state ~= "dead" then
            -- Se a vida está zero mas o bot ainda não foi processado como morto,
            -- triggeramos a morte. Como não temos o killer aqui no loop manual,
            -- passamos nil. O onPedWasted deve ter pego o killer real se disponível.
            triggerEvent("bot:death", bot, nil)
        end
    end
end

function botManager.getCount()
    return botManager.botCount
end

function botManager.getAll()
    return botManager.botList
end

function botManager.getInDimension(dimension)
    local result = {}
    for bot in pairs(botManager.dimensionBots[dimension] or {}) do
        if isElement(bot) then
            table.insert(result, bot)
        end
    end
    return result
end

function botManager.getData(bot)
    return botManager.bots[bot]
end

function botManager.isBot(element)
    return botManager.bots[element] and true or false
end

function botManager.setTarget(bot, target)
    local data = botManager.bots[bot]
    if not data then return false end
    
    setElementData(bot, "target", target, true)
    return true
end

-- Eventos
addEventHandler("onElementDestroy", root, function()
    local bot = source
    if botManager.bots[bot] then
        botManager.destroyBot(bot)
    end
end)

addEventHandler("onPedWasted", root, function(_, killer)
    local bot = source
    if botManager.bots[bot] then
        triggerEvent("bot:death", bot, killer)
    end
end)

outputDebugString("[BotNPC] BotManager carregado")