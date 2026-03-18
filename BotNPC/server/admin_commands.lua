-- server/admin_commands.lua
-- Comandos administrativos

local function npcHelpLines()
    return {
        "Comandos BotNPC (teste):",
        "/help_npc",
        "/botdebug",
        "/editnodes",
        "/spawnnpc [botType] [amount]  (Tipos: bandit, sniper, grenadier, molotov_man, zombie_walker, etc)",
        "/guardbot [amount]",
        "/botstats",
        "/botfollow",
        "/botstop",
        "/killbots",
        "/botsave",
        "/botload",
        "/npcinvestigate [x] [y] [z]  (força bots próximos a investigar)",
        "/npcprotectarea [radius]      (define bot:protectArea pros bots próximos)",
        "/npccleararea                 (remove bot:protectArea dos bots próximos)",
        "/npcinfo                      (debug: mostra tipo/vida do bot mais próximo)",
        "/npctoggle [state] [0/1]      (habilita/desabilita estado via elementData pros bots próximos)",
    }
end

addCommandHandler("help_npc", function(player)
    if not isPlayerAdmin(player) then return end
    for _, line in ipairs(npcHelpLines()) do
        outputChatBox("[BotNPC] " .. line, player, 200, 255, 200)
    end
end)

-- Criar bots básicos (inimigos)
addCommandHandler("spawnnpc", function(player, cmd, botType, amount)
    if not isPlayerAdmin(player) then return end
    botType = botType or "bandit"
    amount = tonumber(amount) or 1
    local x, y, z = getElementPosition(player)
    local dim = getElementDimension(player)
    local int = getElementInterior(player)
    local count = 0

    for i = 1, amount do
        local spawnX = x + math.random(-5, 5)
        local spawnY = y + math.random(-5, 5)
        local customData = {}
        if botType == "guard_priv" then
            customData.protectTarget = player
        end
        local bot = botManager.createBot(spawnX, spawnY, z, math.random(0, 360), nil, botType, dim, int, customData)
        if bot then
            count = count + 1
        end
    end
    
    outputChatBox("[BotNPC] " .. count .. " bots do tipo '" .. botType .. "' criados!", player, 0, 255, 0)
end)

-- Criar bots guardiões que protegem o player
addCommandHandler("guardbot", function(player, cmd, amount)
    if not isPlayerAdmin(player) then return end
    amount = tonumber(amount) or 1
    local x, y, z = getElementPosition(player)
    local dim = getElementDimension(player)
    local int = getElementInterior(player)
    local count = 0

    for i = 1, amount do
        local spawnX = x + math.random(-5, 5)
        local spawnY = y + math.random(-5, 5)
        local bot = botManager.createBot(spawnX, spawnY, z, math.random(0, 360), nil, "guard_priv", dim, int)
        if bot then
            setElementData(bot, "bot:protectTarget", player, true)
            triggerClientEvent(root, "bot:follow", bot, bot, player)
            count = count + 1
        end
    end

    outputChatBox("[BotNPC] " .. count .. " bots guardiões criados!", player, 0, 255, 0)
end)

-- Força bots próximos a investigar uma posição
addCommandHandler("npcinvestigate", function(player, cmd, x, y, z)
    if not isPlayerAdmin(player) then return end
    local px, py, pz = getElementPosition(player)
    local dim = getElementDimension(player)
    local radius = 60

    x = tonumber(x) or px
    y = tonumber(y) or py
    z = tonumber(z) or pz

    local count = 0
    for _, bot in ipairs(botManager.getInDimension(dim) or {}) do
        if isElement(bot) then
            local bx, by, bz = getElementPosition(bot)
            if getDistanceBetweenPoints3D(px, py, pz, bx, by, bz) <= radius then
                setElementData(bot, "bot:investigatePos", {x, y, z}, true)
                count = count + 1
            end
        end
    end

    outputChatBox("[BotNPC] InvestigatePos setado para " .. count .. " bots (raio " .. radius .. ").", player, 0, 255, 0)
end)

-- Define uma área de proteção pros bots próximos
addCommandHandler("npcprotectarea", function(player, cmd, radius)
    if not isPlayerAdmin(player) then return end
    radius = tonumber(radius) or 40

    local px, py, pz = getElementPosition(player)
    local dim = getElementDimension(player)
    local count = 0

    for _, bot in ipairs(botManager.getInDimension(dim) or {}) do
        if isElement(bot) then
            local bx, by, bz = getElementPosition(bot)
            if getDistanceBetweenPoints3D(px, py, pz, bx, by, bz) <= 60 then
                setElementData(bot, "bot:protectArea", {px, py, pz, radius}, true)
                count = count + 1
            end
        end
    end

    outputChatBox("[BotNPC] bot:protectArea aplicado em " .. count .. " bots (radius=" .. radius .. ").", player, 0, 255, 0)
end)

addCommandHandler("npccleararea", function(player)
    if not isPlayerAdmin(player) then return end
    local px, py, pz = getElementPosition(player)
    local dim = getElementDimension(player)
    local count = 0

    for _, bot in ipairs(botManager.getInDimension(dim) or {}) do
        if isElement(bot) then
            local bx, by, bz = getElementPosition(bot)
            if getDistanceBetweenPoints3D(px, py, pz, bx, by, bz) <= 60 then
                setElementData(bot, "bot:protectArea", nil, true)
                count = count + 1
            end
        end
    end

    outputChatBox("[BotNPC] bot:protectArea removido de " .. count .. " bots.", player, 255, 255, 0)
end)

-- Debug: mostra info do bot mais próximo (tipo/vida/time/estado)
addCommandHandler("npcinfo", function(player)
    if not isPlayerAdmin(player) then return end
    local px, py, pz = getElementPosition(player)
    local dim = getElementDimension(player)

    local closest, bestDist = nil, math.huge
    for _, bot in ipairs(botManager.getInDimension(dim) or {}) do
        if isElement(bot) then
            local bx, by, bz = getElementPosition(bot)
            local d = getDistanceBetweenPoints3D(px, py, pz, bx, by, bz)
            if d < bestDist then
                bestDist = d
                closest = bot
            end
        end
    end

    if not closest or bestDist > 80 then
        outputChatBox("[BotNPC] Nenhum bot próximo (<=80m).", player, 255, 255, 0)
        return
    end

    local botType = getElementData(closest, "bot:type") or "bandit"
    local cfg = BOTNPC.getTypeConfig(botType) or {}
    local hp = getElementHealth(closest)
    local expected = tonumber(cfg.health) or 100

    outputChatBox(("[BotNPC] Bot mais próximo: type=%s hp=%.1f (cfg=%d) dist=%.1f"):format(botType, hp, expected, bestDist), player, 200, 255, 200)
    outputChatBox(("[BotNPC] combatStyle=%s moveStyle=%s damageMult=%s"):format(tostring(cfg.combatStyle), tostring(cfg.moveStyle), tostring(cfg.damageMult)), player, 200, 255, 200)
    outputChatBox(("[BotNPC] fightingStyle=%s (Nativo: %s)"):format(tostring(cfg.fightingStyle), tostring(getPedFightingStyle(closest))), player, 200, 255, 200)
end)

addCommandHandler("npctoggle", function(player, cmd, stateName, enabled)
    if not isPlayerAdmin(player) then return end
    stateName = tostring(stateName or ""):lower()
    enabled = tostring(enabled or "1")
    local flag = (enabled == "1" or enabled == "true" or enabled == "on")

    local allowed = {
        idle = true,
        patrol = true,
        investigate = true,
        combat = true,
        follow = true,
        guard = true
    }
    if not allowed[stateName] then
        outputChatBox("[BotNPC] Estado inválido. Use: idle/patrol/investigate/combat/follow/guard", player, 255, 0, 0)
        return
    end

    local px, py, pz = getElementPosition(player)
    local dim = getElementDimension(player)
    local count = 0

    for _, bot in ipairs(botManager.getInDimension(dim) or {}) do
        if isElement(bot) then
            local bx, by, bz = getElementPosition(bot)
            if getDistanceBetweenPoints3D(px, py, pz, bx, by, bz) <= 60 then
                local t = getElementData(bot, "bot:ai:states")
                if type(t) ~= "table" then t = {} end
                t[stateName] = flag
                setElementData(bot, "bot:ai:states", t, true)
                count = count + 1
            end
        end
    end

    outputChatBox(("[BotNPC] %s=%s aplicado em %d bots (raio 60m)."):format(stateName, tostring(flag), count), player, 0, 255, 0)
end)

-- Kill all bots
addCommandHandler("killbots", function(player)
    if not isPlayerAdmin(player) then return end
    local count = botManager.destroyAll()
    outputChatBox("[BotNPC] " .. count .. " bots destruídos!", player, 255, 0, 0)
end)

-- Status do sistema
addCommandHandler("botstats", function(player)
    if not isPlayerAdmin(player) then return end
    local total = botManager.getCount()
    local dim = getElementDimension(player)
    local dimCount = 0
    local botsInDim = botManager.getInDimension(dim)
    if botsInDim then dimCount = #botsInDim end
    
    outputChatBox("[BotNPC] Total: " .. total .. " | Na sua dimensão: " .. dimCount, player, 0, 255, 0)
end)

-- Follow player
addCommandHandler("botfollow", function(player)
    if not isPlayerAdmin(player) then return end
    local dim = getElementDimension(player)
    local px, py, pz = getElementPosition(player)
    local count = 0
    
    local botsInDim = botManager.getInDimension(dim)
    for _, bot in ipairs(botsInDim or {}) do
        if isElement(bot) then
            local bx, by, bz = getElementPosition(bot)
            local dist = getDistanceBetweenPoints3D(px, py, pz, bx, by, bz)
            
            if dist < 30 then
                triggerClientEvent(root, "bot:follow", bot, bot, player)
                count = count + 1
            end
        end
    end
    outputChatBox("[BotNPC] " .. count .. " bots seguindo você", player, 0, 255, 0)
end)

-- Stop bots
addCommandHandler("botstop", function(player)
    if not isPlayerAdmin(player) then return end
    local dim = getElementDimension(player)
    local count = 0
    
    local botsInDim = botManager.getInDimension(dim)
    for _, bot in ipairs(botsInDim or {}) do
        triggerClientEvent(root, "bot:stop", bot, bot)
        count = count + 1
    end
    
    outputChatBox("[BotNPC] " .. count .. " bots parados", player, 255, 255, 0)
end)

-- Save/Load
addCommandHandler("botsave", function(player)
    if not isPlayerAdmin(player) then return end
    if persistence and persistence.saveBots then
        if persistence.saveBots() then
            outputChatBox("[BotNPC] Bots salvos!", player, 0, 255, 0)
        else
            outputChatBox("[BotNPC] Erro ao salvar", player, 255, 0, 0)
        end
    end
end)

addCommandHandler("botload", function(player)
    if not isPlayerAdmin(player) then return end
    if persistence and persistence.loadBots then
        if persistence.loadBots() then
            outputChatBox("[BotNPC] Bots carregados!", player, 0, 255, 0)
        else
            outputChatBox("[BotNPC] Erro ao carregar", player, 255, 0, 0)
        end
    end
end)

outputDebugString("[BotNPC] Admin commands carregado")
