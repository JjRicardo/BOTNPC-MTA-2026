-- server/s_bomber.lua
-- Lógica customizada para o bot "Bomber" sem mexer no core do BotNPC

-- Comando para spawnar o bot Bomber
addCommandHandler("spawnbomber", function(player)
    local x, y, z = getElementPosition(player)
    local dim = getElementDimension(player)
    
    -- Criamos um bot do tipo 'bandit' como base (ele já tem IA de combate armado)
    local bot = exports.BotNPC:createBot(x + 5, y, z, 0, 264, "zombie_rynner", dim, 0, {
        health = 250
    })
    
    if bot then
        -- Marcamos ele como um Bomber para os scripts customizados
        setElementData(bot, "bot:isBomber", true, true)
        outputChatBox("[BotNPC Example] Bomber criado! Cuidado com a explosão ao morrer.", player, 255, 100, 0)
    end
end)

-- Lógica de explosão ao morrer e atração de Peds
addEventHandler("onBotWasted", root, function(killer, botType, data)
    -- 'source' é o Ped do bot que morreu
    if getElementData(source, "bot:isBomber") then
        local x, y, z = getElementPosition(source)
        local dim = getElementDimension(source)
        
        -- 1. Cria a explosão (Tipo 2 = Grande)
        createExplosion(x, y, z, 2)
        
        -- 2. Atrai todos os bots num raio de 150m para a posição da explosão
        local radius = 150.0
        local allPeds = getElementsByType("ped")
        local count = 0
        
        for _, ped in ipairs(allPeds) do
            if ped ~= source and exports.BotNPC:isBot(ped) then
                local px, py, pz = getElementPosition(ped)
                local dist = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
                
                if dist <= radius and getElementDimension(ped) == dim then
                    -- Setamos a posição de investigação no Element Data
                    -- O BotNPC core lê esse dado automaticamente e faz o bot ir até lá
                    setElementData(ped, "bot:investigatePos", {x, y, z}, true)
                    count = count + 1
                end
            end
        end
        
        outputDebugString("[Bomber] Explosão atraiu " .. count .. " bots para a posição.")
    end
end)
