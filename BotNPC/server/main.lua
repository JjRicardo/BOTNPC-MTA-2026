-- server/main.lua
-- Arquivo principal do servidor

-- Lista de grupos ACL que podem usar comandos de debug/editor
local ADMIN_ACL_GROUPS = {"Admin", "Console", "Staff", "SuperModerator", "Moderator"}

function isPlayerAdmin(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    local account = getPlayerAccount(player)
    if isGuestAccount(account) then return false end
    
    for _, group in ipairs(ADMIN_ACL_GROUPS) do
        local aclGroup = aclGetGroup(group)
        if aclGroup and isObjectInACLGroup("user." .. getAccountName(account), aclGroup) then
            return true
        end
    end
    return false
end

-- Sincroniza o status de admin quando o jogador loga
addEventHandler("onPlayerLogin", root, function()
    local isAdmin = isPlayerAdmin(source)
    setElementData(source, "botnpc:isAdmin", isAdmin, true)
    if isAdmin then
        outputChatBox("[BotNPC] Você tem acesso aos comandos de Debug e Editor.", source, 0, 255, 0)
    end
end)

-- Limpa status hostil do player ao morrer ou deslogar
addEventHandler("onPlayerWasted", root, function()
    setElementData(source, "bot:isHostile", nil, true)
    setElementData(source, "bot:witnesses", nil, true)
end)

addEventHandler("onPlayerQuit", root, function()
    setElementData(source, "bot:isHostile", nil, true)
    setElementData(source, "bot:witnesses", nil, true)
end)

-- Sincroniza para quem já está logado no start do resource
local function syncAllAdmins()
    for _, player in ipairs(getElementsByType("player")) do
        setElementData(player, "botnpc:isAdmin", isPlayerAdmin(player), true)
    end
end

addEvent("onBotWasted", true) -- Evento para outros resources consumirem

function onResourceStart()
    outputDebugString("[BotNPC] Servidor iniciado - Sistema de Bots de Combate")
    
    syncAllAdmins()
    
    -- Inicializa sistemas
    if botManager and botManager.init then
        botManager.init()
    end
    
    if pathfinder and pathfinder.init then
        pathfinder.init()
    end
    
    -- Timer principal
    local interval = BOTNPC.CONSTANTS.TICK_INTERVAL or 250
    setTimer(function()
        if botManager and botManager.updateAll then
            botManager.updateAll()
        end
    end, interval, 0)
    
    -- Auto-save
    setTimer(function()
        if persistence and persistence.autoSave then
            persistence.autoSave()
        end
    end, 60000 * 60, 0)
end
addEventHandler("onResourceStart", resourceRoot, onResourceStart)

function onResourceStop()
    outputDebugString("[BotNPC] Servidor parando")
    
    if persistence and persistence.saveBots then
        persistence.saveBots()
    end
    
    if botManager and botManager.destroyAll then
        botManager.destroyAll()
    end
end
addEventHandler("onResourceStop", resourceRoot, onResourceStop)

-- Sincronização de Pounce do Hunter (Server-side)
addEvent("bot:hunterPounceSync", true)
addEventHandler("bot:hunterPounceSync", root, function(target, isStarting)
    if not isElement(source) or not isElement(target) then return end
    
    if isStarting then
        -- Validação de distância (Fail-safe servidor)
        local bx, by, bz = getElementPosition(source)
        local tx, ty, tz = getElementPosition(target)
        if getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz) > 4.5 then return end

        -- 1. Vítima DEITA no chão e fica IMOBILIZADA
        setElementFrozen(target, true)
        setPedAnimation(target, "BEACH", "Lay_Bac_Loop", -1, true, false, false, false)
        
        -- 2. Notifica a vítima (se for player) para forçar a animação localmente (evita levantar)
        if getElementType(target) == "player" then
            triggerClientEvent(target, "bot:forceVictimAnim", target, true)
        end

        -- 3. Posiciona o Hunter MONTADO para o ATAQUE FERAL
        -- Centralizado no peito
        setElementPosition(source, tx, ty, tz + 0.55)
        local tr = getPedRotation(target)
        setPedRotation(source, tr)
        
        -- 4. Hunter: animação de soco no chão (melee_2 fight_b = FightB_G na wiki MTA)
        setPedAnimation(source, "fight_b", "FightB_G", -1, true, false, false, false)
        
        -- Garante que o bot está com o estilo de luta correto para essa animação
        setPedFightingStyle(source, 15)
        
        -- Vincula o alvo para limpeza posterior
        setElementData(source, "bot:pounceTarget", target, true)
        setElementData(target, "bot:isPinned", true, true)
    else
        -- 5. Liberação
        setElementFrozen(target, false)
        
        -- Notifica a vítima para liberar os controles
        if getElementType(target) == "player" then
            triggerClientEvent(target, "bot:forceVictimAnim", target, false)
        end

        -- Reseta animações
        setPedAnimation(target)
        setPedAnimation(source)
        
        setElementData(source, "bot:pounceTarget", nil, true)
        setElementData(target, "bot:isPinned", nil, true)
    end
end)

-- Sincronização de Backstab (Server-side)
addEvent("bot:backstabSync", true)
addEventHandler("bot:backstabSync", root, function(target, px, py, pz, rot)
    if not isElement(source) or not isElement(target) then return end
    
    -- Validação de distância (Fail-safe servidor)
    local bx, by, bz = getElementPosition(source)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz) > 3.5 then return end

    -- Alinha o bot e a vítima
    setElementPosition(source, px, py, pz)
    setPedRotation(source, rot)
    setPedRotation(target, rot)
    
    -- Trava a vítima durante a execução (aprox 2 segundos de animação)
    setElementFrozen(target, true)
    
    -- Executa as animações em ambos
    setPedAnimation(source, "KNIFE", "KILL_Knife_Player", -1, false, false, false, false)
    setPedAnimation(target, "KNIFE", "KILL_Knife_Ped", -1, false, false, false, false)
    
    -- Libera a vítima após o término da animação (ou morte)
    setTimer(function(t)
        if isElement(t) then
            setElementFrozen(t, false)
            -- Se não morreu, reseta animação
            if not isPedDead(t) then
                setPedAnimation(t)
            end
        end
    end, 2500, 1, target)
end)

-- Evento de tiro (Otimizado com bytedata)
-- Evento de dano do player no bot (Sincronizado)
addEvent("bot:onPlayerHitBot", true)
addEventHandler("bot:onPlayerHitBot", root, function(victim, dmgBytes, bodypart, weapon)
    local attacker = source
    if not isElement(attacker) or not isElement(victim) then return end
    
    local damage = bytesToData("f", dmgBytes)
    
    -- Se o dano for 0 (ex: soco nativo que o cliente cancelou), usa o valor da tabela
    if not damage or damage <= 0 then
        local config = BOTNPC.CONSTANTS.DAMAGE_SYSTEM
        damage = config.PLAYER_VS_BOT[weapon or 0] or 15.0
    end
    
    if combatLogic and combatLogic.applyDamage then
        -- Aplica o dano no bot (Vítima)
        combatLogic.applyDamage(attacker, victim, damage, bodypart, weapon)
    end
end)

-- Evento de tiro sincronizado (Bot disparando)
addEvent("bot:shoot", true)
addEventHandler("bot:shoot", root, function(target, dmgBytes, bodypart, animBlock, animName, isGrab, isKick)
    local bot = source
    if not isElement(bot) or not isElement(target) then return end
    
    local damage = bytesToData("f", dmgBytes)
    isGrab = (isGrab == true)
    isKick = (isKick == true)
    
    local weapon = getPedWeapon(bot)
    local isTargetBlocking = getElementData(target, "player:isBlocking") or getElementData(target, "bot:isBlocking")
    
    -- Bloqueio: soco não acerta (applyDamage zera dano). Chute pode quebrar a guarda; agarrão ignora bloqueio.
    if weapon == 0 and isTargetBlocking and not isGrab then
        if isKick and math.random() < 0.8 then
            -- Chute: 80% de chance de quebrar o bloqueio e acertar
            local blockKey = getElementType(target) == "player" and "player:isBlocking" or "bot:isBlocking"
            setElementData(target, blockKey, false, false)
            setTimer(function(p, key) if isElement(p) then setElementData(p, key, true, false) end end, 150, 1, target, blockKey)
        end
        -- Se for soco (não isKick), não quebra; applyDamage vai zerar o dano e disparar onClientBlock
    end
    
    if combatLogic and combatLogic.applyDamage then
        combatLogic.applyDamage(bot, target, damage, bodypart, nil, animBlock, animName, isGrab)
    end
end)

-- Sincronização de Ataque Melee (Estilo Slothbot)
addEvent("bot:meleeTrigger", true)
addEventHandler("bot:meleeTrigger", root, function(target)
    local bot = source
    if not isElement(bot) or not isElement(target) then return end
    
    -- Avisa todos os clientes para rodarem a sequência de animação/controle do bot
    triggerClientEvent(root, "bot:onMeleeAttack", bot, target)
end)

-- Sincronização de bots para novos jogadores ou quando mudam de dimensão
addEvent("bot:requestSync", true)
addEventHandler("bot:requestSync", root, function()
    local player = client or source
    if not isElement(player) then return end
    
    local count = 0
    if botManager and botManager.bots then
        for bot, data in pairs(botManager.bots) do
            if isElement(bot) and data.state ~= "dead" then
                local syncBytes = dataToBytes("iii", data.id, data.dimension, data.interior)
                -- Usa resourceRoot como source para garantir o recebimento em todas as dimensões
                triggerClientEvent(player, "bot:sync", resourceRoot, bot, syncBytes)
                count = count + 1
            end
        end
    end
    outputDebugString("[BotNPC] Sincronizados " .. count .. " bots para o jogador " .. getPlayerName(player))
end)

-- Sincroniza quando o player muda de dimensão para garantir que os bots da nova dimensão apareçam
addEventHandler("onPlayerElementDimensionChange", root, function(oldDim, newDim)
    -- Dá um pequeno delay para o MTA processar a mudança de dimensão nativa
    setTimer(triggerEvent, 500, 1, "bot:requestSync", source)
end)

-- Evento de morte
addEvent("bot:death", true)
addEventHandler("bot:death", root, function(killer)
    local bot = source
    if botManager and botManager.destroyBot then
        botManager.destroyBot(bot, killer)
    end
end)

-- Evento para o cliente solicitar um caminho (ex: ao ouvir som)
addEvent("bot:requestPath", true)
addEventHandler("bot:requestPath", root, function(tx, ty, tz)
    local bot = source
    if not isElement(bot) or not tx or not ty or not tz then return end
    
    if pathfinder and pathfinder.findPath then
        local bx, by, bz = getElementPosition(bot)
        local dim = getElementDimension(bot)
        local int = getElementInterior(bot)
        local path = pathfinder.findPath(bx, by, bz, tx, ty, tz, dim, int)
        
        if #path > 0 then
            local visualPath = {}
            for _, nodeId in ipairs(path) do
                local node = pathfinder.nodes[nodeId]
                if node then
                    table.insert(visualPath, {node.x, node.y, node.z})
                end
            end
            setElementData(bot, "bot:path", visualPath, true)
        end
    end
end)

-- Evento de bot travado (Stuck)
addEvent("onBotStuck", true)
addEventHandler("onBotStuck", root, function()
    local bot = source
    if not isElement(bot) then return end
    
    local target = getElementData(bot, "target")
    local investigatePos = getElementData(bot, "bot:investigatePos")
    
    local tx, ty, tz
    if isElement(target) then
        tx, ty, tz = getElementPosition(target)
    elseif investigatePos then
        tx, ty, tz = unpack(investigatePos)
    end

    if tx then
        -- Força o recálculo da rota
        triggerEvent("bot:requestPath", bot, tx, ty, tz)
    else
        -- Se não tem target, tenta apenas dar um passo pro lado
        local x, y, z = getElementPosition(bot)
        local angle = math.random(0, 360)
        local nx = x + math.cos(math.rad(angle)) * 2
        local ny = y + math.sin(math.rad(angle)) * 2
        -- Move temporariamente
        triggerClientEvent(root, "bot:forceMove", bot, nx, ny)
    end
end)

-- EXPORTS
function createBot(x, y, z, rot, skin, botType, dimension, interior, customData)
    local bot = botManager.createBot(x, y, z, rot, skin, botType, dimension, interior, customData)
    return bot
end

function createBotsInArea(centerX, centerY, centerZ, radius, count, skin, botType, dimension)
    local spawned = botManager.createBotsInArea(centerX, centerY, centerZ, radius, count, skin, botType, dimension)
    return spawned
end

function getBots()
    return botManager.getAll()
end

function getBotsInDimension(dimension)
    return botManager.getInDimension(dimension)
end

function getBotCount()
    return botManager.getCount()
end

function destroyBot(bot)
    return botManager.destroyBot(bot)
end

function destroyAllBots()
    return botManager.destroyAll()
end

function destroyBotsInDimension(dimension)
    return botManager.destroyInDimension(dimension)
end

function setBotTarget(bot, target)
    return botManager.setTarget(bot, target)
end

function getBotData(bot)
    return botManager.getData(bot)
end

function setBotProtectTarget(bot, target)
    return botManager.setBotProtectTarget(bot, target)
end

function setBotProtectArea(bot, x, y, z, radius)
    return botManager.setBotProtectArea(bot, x, y, z, radius)
end

function isBot(element)
    return botManager.isBot(element)
end

function createSquad(leader, members, squadType)
    if squadManager and squadManager.createSquad then
        return squadManager.createSquad(leader, members, squadType)
    end
    return false
end