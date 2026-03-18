-- Exemplo de como usar o resource BotNPC

--[[=========================================================================
--    EXEMPLO 1: SPAWN DE BOTS PADRÃO
--===========================================================================]]

addCommandHandler("spawnex", function(player, cmd, botType, amount)
    if not player or not isElement(player) then return end
    if not exports.BotNPC:isBot(player) then -- Evita que bots usem o comando
        botType = botType or "bandit"
        amount = tonumber(amount) or 1
        
        local x, y, z = getElementPosition(player)
        local dim = getElementDimension(player)
        
        local createdCount = 0
        for i = 1, amount do
            local px = x + math.random(-8, 8)
            local py = y + math.random(-8, 8)
            local bot = exports.BotNPC:createBot(px, py, z, math.random(0, 360), nil, botType, dim)
            if bot then
                createdCount = createdCount + 1
            end
        end
        
        outputChatBox("[BotNPC Example] " .. createdCount .. " bot(s) do tipo '" .. botType .. "' criados!", player, 0, 255, 0)
    end
end)

--[[=========================================================================
--    EXEMPLO 2: BOT COM LÓGICA DE COMBATE CUSTOMIZADA
--===========================================================================]]

local customBots = {}

-- Função para criar um bot "especial" que não usa a IA do BotNPC
addCommandHandler("spawncustom", function(player)
    if not player or not isElement(player) then return end

    local x, y, z = getElementPosition(player)
    local bot = createPed(73, x + 2, y, z) -- Skin de exemplo
    setElementData(bot, "customBot", true)
    setElementHealth(bot, 500)
    giveWeapon(bot, 24, 100, true) -- Desert Eagle
    
    customBots[bot] = {
        state = "idle",
        target = nil,
        lastAttack = 0
    }
    
    outputChatBox("[BotNPC Example] Bot customizado criado!", player, 0, 255, 200)
end)

-- Loop de processamento para os bots customizados
setTimer(function()
    for bot, data in pairs(customBots) do
        if not isElement(bot) or isPedDead(bot) then
            customBots[bot] = nil
        else
            -- Lógica de IA simples
            if not data.target or not isElement(data.target) or isPedDead(data.target) then
                -- Procura por um player próximo
                data.target = getNearestPlayer(bot)
            else
                -- Lógica de combate
                local bx, by, bz = getElementPosition(bot)
                local tx, ty, tz = getElementPosition(data.target)
                local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
                
                setPedLookAt(bot, tx, ty, tz, 2000)
                
                if dist < 20 then
                    local now = getTickCount()
                    if now - data.lastAttack > 1500 then
                        setPedControlState(bot, "fire", true)
                        setTimer(setPedControlState, 200, 1, bot, "fire", false)
                        data.lastAttack = now
                    end
                else
                    -- Apenas anda em direção ao alvo se estiver longe
                    setControlState(bot, "forwards", true)
                end
            end
        end
    end
end, 500, 0)

--[[=========================================================================
--    EXEMPLO 3: SPAWN COM VIDA E DANO CUSTOMIZADOS
--===========================================================================]]

addCommandHandler("spawnex2", function(player, cmd, hp, dmg)
    if not player or not isElement(player) then return end
    
    local x, y, z = getElementPosition(player)
    local dim = getElementDimension(player)
    
    hp = tonumber(hp) or 500
    dmg = tonumber(dmg) or 50
    
    -- Usando a nova tabela customData no export createBot
    local bot = exports.BotNPC:createBot(x + 3, y, z, 0, 105, "zombie_rynner", dim, 0, {
        health = hp,
        meleeDamage = dmg
    })
    
    if bot then
        outputChatBox("[BotNPC Example] Super Zumbi criado! Vida: " .. hp .. " | Dano: " .. dmg, player, 255, 50, 0)
    end
end)

--[[=========================================================================
--    EXEMPLO 4: GUARDAS PÚBLICOS E PRIVADOS
--===========================================================================]]

-- Spawn de um Guarda Público (Segurança de Zona)
addCommandHandler("spawnguardpub", function(player)
    if not player or not isElement(player) then return end
    
    local x, y, z = getElementPosition(player)
    local dim = getElementDimension(player)
    
    -- Spawna o bot
    local bot = exports.BotNPC:createBot(x + 5, y, z, 0, 280, "guard_pub", dim)
    
    if bot then
        -- Define uma zona de proteção fixa (40m de raio)
        exports.BotNPC:setBotProtectArea(bot, x, y, z, 40)
        outputChatBox("[BotNPC Example] Guarda Público criado! Ele protegerá esta zona.", player, 0, 100, 255)
    end
end)

-- Spawn de um Guarda Privado (Bodyguard)
addCommandHandler("spawnguardpriv", function(player)
    if not player or not isElement(player) then return end
    
    local x, y, z = getElementPosition(player)
    local dim = getElementDimension(player)
    
    -- Spawna o bot
    local bot = exports.BotNPC:createBot(x + 2, y, z, 0, 285, "guard_priv", dim)
    
    if bot then
        -- Define o player como alvo a ser protegido
        exports.BotNPC:setBotProtectTarget(bot, player)
        outputChatBox("[BotNPC Example] Guarda-costas criado! Ele irá te seguir e proteger.", player, 0, 255, 255)
    end
end)

-- Comando para remover todos os bots (útil para limpar testes)
addCommandHandler("clearbots", function(player)
    local count = exports.BotNPC:destroyAllBots()
    outputChatBox("[BotNPC Example] Foram removidos " .. (count or 0) .. " bots.", player, 255, 255, 0)
end)

-- Comando para testar o sistema de crime/wanted contra os guardas públicos
addCommandHandler("setwanted", function(player, cmd, level)
    local level = tonumber(level) or 1
    setElementData(player, "wantedLevel", level)
    outputChatBox("[BotNPC Example] Seu nível de procurado agora é: " .. level .. ". Os Guardas Públicos agora te atacarão!", player, 255, 0, 0)
end)

-- Função para pegar o player mais próximo
function getNearestPlayer(fromElement)
    local x, y, z = getElementPosition(fromElement)
    local nearest, nearestDist = nil, 9999
    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) then
            local px, py, pz = getElementPosition(p)
            local dist = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
            if dist < nearestDist then
                nearest = p
                nearestDist = dist
            end
        end
    end
    return nearest
end

