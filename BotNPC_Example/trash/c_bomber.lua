-- client/c_bomber.lua
-- Lógica client-side para o Bomber arremessar granadas

local BOMBER_THROW_COOLDOWN = 4000 -- 4 segundos entre granadas
local lastThrowTick = {}

addEventHandler("onClientRender", root, function()
    -- Procuramos todos os peds marcados como Bomber
    for _, bot in ipairs(getElementsByType("ped", root, true)) do
        if getElementData(bot, "bot:isBomber") and not isPedDead(bot) then
            -- Só processa se o bot estiver perto do localPlayer para economizar CPU
            local bx, by, bz = getElementPosition(bot)
            local px, py, pz = getElementPosition(localPlayer)
            
            if getDistanceBetweenPoints3D(bx, by, bz, px, py, pz) < 100 then
                local now = getTickCount()
                local last = lastThrowTick[bot] or 0
                
                if now - last > BOMBER_THROW_COOLDOWN then
                    -- Tenta achar o alvo atual do bot
                    -- O BotNPC não exporta o alvo diretamente, então vamos achar o inimigo mais próximo dele
                    local target = findNearestEnemy(bot)
                    
                    if target then
                        local tx, ty, tz = getElementPosition(target)
                        local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
                        
                        -- Só joga se estiver a uma distância média (10m a 35m)
                        if dist > 8.0 and dist < 35.0 then
                            throwGrenadeAt(bot, tx, ty, tz)
                            lastThrowTick[bot] = now
                        end
                    end
                end
            end
        end
    end
end)

-- Função auxiliar para achar inimigo mais próximo (baseado na lógica do BotNPC)
function findNearestEnemy(bot)
    local bx, by, bz = getElementPosition(bot)
    local bestTarget = nil
    local bestDist = 40.0
    
    -- Checa players
    for _, p in ipairs(getElementsByType("player")) do
        if not isPedDead(p) then
            -- Usa o export do BotNPC para saber se é inimigo
            if exports.BotNPC:isBot(bot) and not (getElementData(bot, "bot:team") == getElementData(p, "bot:team")) then
                local tx, ty, tz = getElementPosition(p)
                local d = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
                if d < bestDist then
                    bestTarget = p
                    bestDist = d
                end
            end
        end
    end
    return bestTarget
end

-- Simula o arremesso de granada
function throwGrenadeAt(bot, tx, ty, tz)
    local bx, by, bz = getElementPosition(bot)
    
    -- Faz o bot olhar para o alvo
    setPedRotation(bot, (360 - math.deg(math.atan2((tx - bx), (ty - by)))) % 360)
    
    -- Executa animação de arremesso
    setPedAnimation(bot, "GRENADE", "WEAPON_throw", 1000, false, false, false, false)
    
    -- Cria o projétil após um pequeno delay (tempo da animação)
    setTimer(function()
        if isElement(bot) then
            local x, y, z = getPositionFromElementOffset(bot, 0, 0.5, 0.8)
            -- Cria projétil de granada (Tipo 16)
            createProjectile(bot, 16, x, y, z, 1.0, nil, 0, 0, 0, tx - x, ty - y, (tz - z) + 2)
        end
    end, 400, 1)
end

function getPositionFromElementOffset(element, offX, offY, offZ)
    local m = getElementMatrix(element)
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
    return x, y, z
end
