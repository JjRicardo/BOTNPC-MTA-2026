-- client/streaming.lua
-- Sistema de streaming

streaming = {}

streaming.streamedBots = {}
streaming.botGrid = {}
streaming.gridSize = BOTNPC.CONSTANTS.PATHFINDING.GRID_SIZE

function streaming.init()
    outputDebugString("[BotNPC] Streaming inicializado")
end

function streaming.update()
    local px, py, pz = getElementPosition(localPlayer)
    local dim = getElementDimension(localPlayer)
    local int = getElementInterior(localPlayer)
    local streamDist = BOTNPC.CONSTANTS.STREAM_DISTANCE
    
    for bot, data in pairs(bots) do
        if isElement(bot) and data and data.state ~= "dead" then
            local bdim = getElementDimension(bot)
            local bint = getElementInterior(bot)
            
            local sameSpace = (bdim == dim and bint == int)
            
            -- Só calcula distância se estiver no mesmo interior e dimensão
            -- pois getElementPosition pode falhar ou retornar 0,0,0 se o elemento estiver fora do sync
            if sameSpace then
                local bx, by, bz = getElementPosition(bot)
                local dist = getDistanceBetweenPoints3D(bx, by, bz, px, py, pz)
                
                if dist <= streamDist then
                    if not streaming.streamedBots[bot] then
                        setElementAlpha(bot, 255)
                        setElementCollisionsEnabled(bot, true)
                        streaming.streamedBots[bot] = true
                        triggerEvent("bot:streamIn", bot)
                    end
                else
                    if streaming.streamedBots[bot] then
                        setElementAlpha(bot, 0)
                        setElementCollisionsEnabled(bot, false)
                        streaming.streamedBots[bot] = nil
                        triggerEvent("bot:streamOut", bot)
                    end
                end
            else
                -- Se não estiver no mesmo espaço, desliga streaming e alpha
                if streaming.streamedBots[bot] then
                    setElementAlpha(bot, 0)
                    setElementCollisionsEnabled(bot, false)
                    streaming.streamedBots[bot] = nil
                    triggerEvent("bot:streamOut", bot)
                end
            end
        end
    end
end

function streaming.isStreamed(bot)
    return streaming.streamedBots[bot] or false
end

outputDebugString("[BotNPC] Streaming carregado")