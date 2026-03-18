

-- client/hud_debug.lua
-- Sistema de debug visual

hudDebug = {}

hudDebug.enabled = BOTNPC.CONSTANTS.DEBUG.ENABLED
hudDebug.drawStates = BOTNPC.CONSTANTS.DEBUG.DRAW_STATES
hudDebug.drawVision = BOTNPC.CONSTANTS.DEBUG.DRAW_VISION

local screenWidth, screenHeight = guiGetScreenSize()

function hudDebug.init()
    if hudDebug.enabled then
        addEventHandler("onClientRender", root, hudDebug.render)
    end
    addCommandHandler("botdebug", hudDebug.toggle)
end

function hudDebug.toggle()
    if not getElementData(localPlayer, "botnpc:isAdmin") then
        outputChatBox("[BotNPC] Você não tem permissão para usar o Debug visual.", 255, 0, 0)
        return
    end
    
    hudDebug.enabled = not hudDebug.enabled
    
    if hudDebug.enabled then
        addEventHandler("onClientRender", root, hudDebug.render)
        outputChatBox("[BotNPC] Debug visual: ATIVADO", 0, 255, 0)
    else
        removeEventHandler("onClientRender", root, hudDebug.render)
        outputChatBox("[BotNPC] Debug visual: DESATIVADO", 255, 0, 0)
    end
end

function hudDebug.render()
    local px, py, pz = getElementPosition(localPlayer)
    local pdim = getElementDimension(localPlayer)
    local pint = getElementInterior(localPlayer)
    local streamedCount = 0
    
    -- Desenha Nodes e Conexões (Otimizado: Apenas se o Node Editor estiver desativado para evitar sobreposição)
    if hudDebug.enabled and not (nodeEditor and nodeEditor.enabled) then
        local nodes = getElementsByType("pathpoint")
        for _, node in ipairs(nodes) do
            local nx, ny, nz = getElementPosition(node)
            local dist = getDistanceBetweenPoints3D(px, py, pz, nx, ny, nz)
            
            if dist < 40 then
                local sx, sy = getScreenFromWorldPosition(nx, ny, nz)
                if sx then
                    dxDrawCircle(sx, sy, 4, tocolor(0, 255, 0, 100))
                    
                    -- Desenha conexões
                    local connections = getElementData(node, "connections") or {}
                    for targetId in pairs(connections) do
                        local target = getElementByID(tostring(targetId))
                        if isElement(target) then
                            local tx, ty, tz = getElementPosition(target)
                            local sx2, sy2 = getScreenFromWorldPosition(tx, ty, tz)
                            if sx2 then
                                dxDrawLine(sx, sy, sx2, sy2, tocolor(0, 255, 0, 30), 1)
                            end
                        end
                    end
                end
            end
        end
    end

    for bot, data in pairs(bots) do
        if isElement(bot) and data and data.state ~= "dead" then
            local bdim = getElementDimension(bot)
            local bint = getElementInterior(bot)
            
            -- Só renderiza se estiver na mesma dimensão e interior
            if bdim == pdim and bint == pint then
                if streaming.isStreamed(bot) then
                    streamedCount = streamedCount + 1
                
                end
                
                local bx, by, bz = getElementPosition(bot)
            local dist = getDistanceBetweenPoints3D(bx, by, bz, px, py, pz)
            
            if dist < 100 then
                local color = BOTNPC.CONSTANTS.DEBUG_COLORS[data.state] or tocolor(255,255,255,255)
                local sx, sy = getScreenFromWorldPosition(bx, by, bz + 1.2)
                
                if sx then
                    if hudDebug.drawStates then
                        -- Estado
                        dxDrawText(string.upper(data.state), sx - 1, sy - 31, sx - 1, sy - 31, tocolor(0,0,0,200), 1.2)
                        dxDrawText(string.upper(data.state), sx + 1, sy - 29, sx + 1, sy - 29, tocolor(0,0,0,200), 1.2)
                        dxDrawText(string.upper(data.state), sx, sy - 30, sx, sy - 30, color, 1.2)
                        
                        -- ID / Tipo / Time
                        local botType = BOTNPC.getBotType and BOTNPC.getBotType(bot) or "?"
                        local teamId = BOTNPC.getElementTeam and BOTNPC.getElementTeam(bot) or "neutral"

                        dxDrawText("ID: " .. data.id, sx - 1, sy - 22, sx - 1, sy - 22, tocolor(0,0,0,200), 1)
                        dxDrawText("ID: " .. data.id, sx + 1, sy - 20, sx + 1, sy - 20, tocolor(0,0,0,200), 1)
                        dxDrawText("ID: " .. data.id, sx, sy - 21, sx, sy - 21, tocolor(255,255,255,255), 1)

                        dxDrawText("T: " .. botType, sx - 1, sy - 10, sx - 1, sy - 10, tocolor(0,0,0,200), 0.9)
                        dxDrawText("T: " .. botType, sx + 1, sy - 8, sx + 1, sy - 8, tocolor(0,0,0,200), 0.9)
                        dxDrawText("T: " .. botType, sx, sy - 9, sx, sy - 9, tocolor(200,200,255,255), 0.9)

                        dxDrawText("G: " .. tostring(teamId), sx - 1, sy + 2, sx - 1, sy + 2, tocolor(0,0,0,200), 0.9)
                        dxDrawText("G: " .. tostring(teamId), sx + 1, sy + 4, sx + 1, sy + 4, tocolor(0,0,0,200), 0.9)
                        dxDrawText("G: " .. tostring(teamId), sx, sy + 3, sx, sy + 3, tocolor(200,255,200,255), 0.9)
                        
                        -- Health
                        local health = getElementHealth(bot)
                        local healthColor = tocolor(0,255,0,255)
                        if health < 50 then healthColor = tocolor(255,255,0,255) end
                        if health < 25 then healthColor = tocolor(255,0,0,255) end
                        
                        dxDrawText("HP: " .. math.floor(health), sx - 1, sy + 14, sx - 1, sy + 14, tocolor(0,0,0,200), 1)
                        dxDrawText("HP: " .. math.floor(health), sx + 1, sy + 16, sx + 1, sy + 16, tocolor(0,0,0,200), 1)
                        dxDrawText("HP: " .. math.floor(health), sx, sy + 15, sx, sy + 15, healthColor, 1)
                        
                        -- Alvo e Distância
                        if data.target and isElement(data.target) then
                            local tx, ty, tz = getElementPosition(data.target)
                            local tdist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
                            local targetName = getElementType(data.target) == "player" and getPlayerName(data.target) or "NPC"
                            
                            dxDrawText("Target: " .. targetName, sx, sy + 27, sx, sy + 27, tocolor(255, 100, 100, 255), 0.8)
                            dxDrawText("Dist: " .. string.format("%.1f", tdist) .. "m", sx, sy + 37, sx, sy + 37, tocolor(255, 200, 100, 255), 0.8)
                        end
                    end
                    
                    -- Squad
                    if data.squadId then
                        dxDrawText("S", sx - 1, sy + 48, sx - 1, sy + 48, tocolor(0,0,0,200), 1)
                        dxDrawText("S", sx + 1, sy + 50, sx + 1, sy + 50, tocolor(0,0,0,200), 1)
                        dxDrawText("S", sx, sy + 49, sx, sy + 49, tocolor(0,255,255,255), 1)
                    end
                end
                
                -- Linha para o alvo
                if data.target and isElement(data.target) then
                    local tx, ty, tz = getElementPosition(data.target)
                    local sx1, sy1 = getScreenFromWorldPosition(bx, by, bz + 1)
                    local sx2, sy2 = getScreenFromWorldPosition(tx, ty, tz + 1)
                    if sx1 and sx2 then
                        dxDrawLine(sx1, sy1, sx2, sy2, tocolor(255,0,0,150), 2)
                    end
                end
                
                -- Visão e Audição (Ranges)
                if hudDebug.drawVision then
                    local profile = BOTNPC.getTypeConfig(BOTNPC.getBotType(bot))
                    
                    -- Desenha Range de Visão (Cone)
                    local rot = getPedRotation(bot)
                    local visionCfg = (profile and profile.vision) or BOTNPC.CONSTANTS.VISION
                    
                    -- Fallback seguro para fov e distance
                    local baseFov = visionCfg.fov or 100
                    local baseDist = visionCfg.distance or 60
                    
                    local fov = (data.state == "combat" and visionCfg.proximityDist and dist <= visionCfg.proximityDist) and (visionCfg.proximityFov or 360) or baseFov
                    
                    local ang1 = math.rad(rot - fov / 2)
                    local ang2 = math.rad(rot + fov / 2)
                    
                    local x1 = bx + math.sin(ang1) * baseDist
                    local y1 = by + math.cos(ang1) * baseDist
                    local x2 = bx + math.sin(ang2) * baseDist
                    local y2 = by + math.cos(ang2) * baseDist
                    
                    local sx1, sy1 = getScreenFromWorldPosition(x1, y1, bz)
                    local sx2, sy2 = getScreenFromWorldPosition(x2, y2, bz)
                    local sxc, syc = getScreenFromWorldPosition(bx, by, bz)
                    
                    if sx1 and sx2 and sxc then
                        dxDrawLine(sxc, syc, sx1, sy1, tocolor(255,255,0,50), 1)
                        dxDrawLine(sxc, syc, sx2, sy2, tocolor(255,255,0,50), 1)
                    end

                    -- Desenha Range de Audição (Círculos)
                    if profile and profile.hearing then
                        local h = profile.hearing
                        -- Walk (Verde)
                        hudDebug.drawCircle3D(bx, by, bz - 0.9, h.walk, tocolor(0, 255, 0, 30))
                        -- Run (Amarelo)
                        hudDebug.drawCircle3D(bx, by, bz - 0.9, h.run, tocolor(255, 255, 0, 20))
                    end
                end
            end
        end
    end
end
    
    -- Info de Ruído do Player Local
    local noiseLevel = perception.getPedNoiseLevel and perception.getPedNoiseLevel(localPlayer) or 0
    local noiseText = noiseLevel == 2 and "RUNNING" or (noiseLevel == 1 and "WALKING" or "SILENT")
    local noiseColor = noiseLevel == 2 and tocolor(255, 0, 0) or (noiseLevel == 1 and tocolor(255, 255, 0) or tocolor(0, 255, 0))
    
    dxDrawRectangle(screenWidth - 210, 10, 200, 60, tocolor(0, 0, 0, 180))
    dxDrawText("YOUR NOISE", screenWidth - 205, 15, screenWidth - 10, 30, tocolor(255, 255, 255), 1.1, "default-bold", "center")
    dxDrawText(noiseText, screenWidth - 205, 35, screenWidth - 10, 60, noiseColor, 1.2, "default-bold", "center")

    -- Estatísticas na tela
    dxDrawRectangle(10, 10, 200, 100, tocolor(0, 0, 0, 180))
    dxDrawText("BOTNPC SYSTEM", 15, 15, 195, 30, tocolor(255,255,255,255), 1.2, "default-bold")
    dxDrawRectangle(15, 32, 190, 1, tocolor(255,255,255,100))
    
    local y = 40
    dxDrawText("Bots Total: " .. (#botList or 0), 15, y, 195, y+20, tocolor(0,255,0,255), 1)
    y = y + 18
    dxDrawText("Streamed: " .. streamedCount, 15, y, 195, y+20, tocolor(255,255,0,255), 1)
    y = y + 18
    dxDrawText("Dimension: " .. getElementDimension(localPlayer), 15, y, 195, y+20, tocolor(0,255,255,255), 1)
end

function hudDebug.drawCircle3D(x, y, z, radius, color)
    local segments = 16
    for i = 1, segments do
        local angle1 = (i - 1) * (360 / segments)
        local angle2 = i * (360 / segments)
        local x1 = x + math.cos(math.rad(angle1)) * radius
        local y1 = y + math.sin(math.rad(angle1)) * radius
        local x2 = x + math.cos(math.rad(angle2)) * radius
        local y2 = y + math.sin(math.rad(angle2)) * radius
        
        local sx1, sy1 = getScreenFromWorldPosition(x1, y1, z)
        local sx2, sy2 = getScreenFromWorldPosition(x2, y2, z)
        
        if sx1 and sx2 then
            dxDrawLine(sx1, sy1, sx2, sy2, color, 2)
        end
    end
end

outputDebugString("[BotNPC] HUD Debug carregado")
