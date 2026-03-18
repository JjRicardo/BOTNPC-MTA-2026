-- Exemplo de integração entre BotNPC_Example e [CD]_drop_arma
-- Este script demonstra como criar drops de armas ao matar NPCs e em zonas específicas

local LOOT_BY_TYPE = {
    zombie_rynner = {
        {id = 22, ammo = 50, chance = 30}, -- Colt 45
        {id = 25, ammo = 10, chance = 10}, -- Shotgun
    },
    bandit = {
        {id = 24, ammo = 35, chance = 40}, -- Desert Eagle
        {id = 29, ammo = 90, chance = 20}, -- MP5
        {id = 30, ammo = 120, chance = 10}, -- AK-47
    },
    guard = {
        {id = 31, ammo = 150, chance = 25}, -- M4
        {id = 23, ammo = 45, chance = 35}, -- Silenced Pistol
    }
}

--[[=========================================================================
--    EXEMPLO 1: DROP AO MATAR UM NPC (PED)
--===========================================================================]]

-- O evento 'onBotWasted' é disparado pelo resource BotNPC quando um bot morre
addEventHandler("onBotWasted", root, function(killer, botType, botData)
    -- source é o PED que morreu
    local x, y, z = getElementPosition(source)
    local int = getElementInterior(source)
    local dim = getElementDimension(source)

    local loots = LOOT_BY_TYPE[botType] or LOOT_BY_TYPE.default
    
    for _, loot in ipairs(loots) do
        if math.random(100) <= loot.chance then
            -- Usando o export do [CD]_drop_arma
            -- exports["[CD]_drop_arma"]:createGroundWeapon(weaponid, ammo, clip, x, y, z, rx, ry, rz, interior, dimension)
            exports["[CD]_drop_arma"]:createGroundWeapon(
                loot.id, 
                loot.id == 8 and 1 or loot.ammo, -- Munição (1 se for faca/espada)
                0, -- Clip
                x + math.random(-5, 5) / 10, 
                y + math.random(-5, 5) / 10, 
                z - 0.9, -- Ajuste para o chão
                90, 0, math.random(360), -- Rotação (90 no RX para ficar deitada)
                int, 
                dim
            )
            
            outputDebugString("[Loot Example] NPC do tipo '" .. botType .. "' dropou arma ID: " .. loot.id)
        end
    end
end)

--[[=========================================================================
--    EXEMPLO 2: DROP EM UMA ZONA ESPECÍFICA (ÁREA DE LOOT)
--===========================================================================]]

local lootZones = {}

function createLootZone(name, x, y, z, radius, intervalMs)
    local col = createColSphere(x, y, z, radius)
    local marker = createMarker(x, y, z - 1, "cylinder", radius * 2, 255, 255, 0, 50)
    
    lootZones[col] = {
        name = name,
        pos = {x, y, z},
        interval = intervalMs,
        timer = nil
    }

    -- Quando um player entra na zona, começa a spawnar loots aleatórios
    addEventHandler("onColShapeHit", col, function(element)
        if getElementType(element) == "player" then
            local data = lootZones[source]
            if not isTimer(data.timer) then
                outputChatBox("[LOOT] Você entrou na zona '" .. data.name .. "'. Itens surgirão aqui!", element, 255, 255, 0)
                
                data.timer = setTimer(function(c)
                    local d = lootZones[c]
                    if d then
                        -- Escolhe uma arma aleatória para o drop da zona
                        local weapons = {22, 24, 25, 29, 30, 31, 33}
                        local wid = weapons[math.random(#weapons)]
                        
                        -- Dropa em posição aleatória dentro da zona
                        local angle = math.random() * 2 * math.pi
                        local dist = math.random() * (radius * 0.7)
                        local lx = d.pos[1] + math.cos(angle) * dist
                        local ly = d.pos[2] + math.sin(angle) * dist
                        
                        exports["[CD]_drop_arma"]:createGroundWeapon(wid, 30, 0, lx, ly, d.pos[3] - 0.9, 90, 0, math.random(360))
                        outputDebugString("[Loot Example] Drop periódico na zona '" .. d.name .. "': ID " .. wid)
                    end
                end, data.interval, 0, source)
            end
        end
    end)

    -- Para o timer quando ninguém mais estiver na zona
    addEventHandler("onColShapeLeave", col, function(element)
        if getElementType(element) == "player" then
            local playersIn = getElementsWithinColShape(source, "player")
            if #playersIn == 0 then
                local data = lootZones[source]
                if isTimer(data.timer) then
                    killTimer(data.timer)
                    data.timer = nil
                    outputDebugString("[Loot Example] Zona '" .. data.name .. "' agora está vazia. Parando drops.")
                end
            end
        end
    end)
end

-- Criar uma zona de loot de exemplo no spawn (ou use o comando abaixo)
addEventHandler("onResourceStart", resourceRoot, function()
    -- Exemplo: Uma zona de loot no aeroporto de Los Santos
    createLootZone("Suprimentos Aéreos", 1935, -2300, 13.5, 15, 10000) -- A cada 10 segundos
end)

-- Comando para criar zona de loot na posição atual
addCommandHandler("criarlootzone", function(player, cmd, name, radius, interval)
    local x, y, z = getElementPosition(player)
    radius = tonumber(radius) or 10
    interval = (tonumber(interval) or 5) * 1000
    name = name or "Zona Custom"
    
    createLootZone(name, x, y, z, radius, interval)
    outputChatBox("[Loot Example] Zona '" .. name .. "' criada com sucesso!", player, 0, 255, 0)
end)
