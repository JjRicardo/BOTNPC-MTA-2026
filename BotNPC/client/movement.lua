-- client/movement.lua
-- Sistema de movimento

movement = {}

local stuckData = {}

function movement.moveTo(bot, targetX, targetY, shouldRun, lookX, lookY)
    if not isElement(bot) then return end
    
    local bx, by, bz = getElementPosition(bot)
    local data = bots[bot]
    
    -- Salva o alvo para o loop de rotação suave no main.lua
    if data then
        data.moveTarget = {targetX, targetY}
        data.lookTarget = lookX and {lookX, lookY} or nil
    end

    -- Lógica de direção: Se o bot precisa olhar para um lado e andar para outro (recuo)
    if lookX and lookY then
        local angle = (360 - math.deg(math.atan2((lookX - bx), (lookY - by)))) % 360
        local moveAngle = (360 - math.deg(math.atan2((targetX - bx), (targetY - by)))) % 360
        local diff = math.abs(angle - moveAngle)
        if diff > 180 then diff = 360 - diff end

        if diff > 130 then -- Andando para trás
            setPedControlState(bot, "forwards", false)
            setPedControlState(bot, "backwards", true)
        else
            setPedControlState(bot, "forwards", true)
            setPedControlState(bot, "backwards", false)
        end
        
        -- Se estiver olhando pra um alvo fixo (lookX/Y), a rotação suave deve seguir o lookTarget
        if data then data.moveTarget = {lookX, lookY} end
    else
        setPedControlState(bot, "forwards", true)
        setPedControlState(bot, "backwards", false)
    end
    
    if shouldRun == "sprint" then
        setPedControlState(bot, "sprint", true)
        setPedControlState(bot, "walk", false)
    elseif shouldRun == "run" or shouldRun == true then
        setPedControlState(bot, "sprint", false)
        setPedControlState(bot, "walk", false)
    else
        setPedControlState(bot, "sprint", false)
        setPedControlState(bot, "walk", true)
    end

    -- Auto-jump para obstáculos
    movement.checkObstacles(bot)
    
    -- Verificação de travamento (stuck)
    movement.checkStuck(bot, targetX, targetY)
end

function movement.checkStuck(bot, tx, ty)
    if not isElement(bot) then return end
    
    local now = getTickCount()
    local data = stuckData[bot] or {lastPos = {getElementPosition(bot)}, lastCheck = now, stuckCount = 0}
    
    if now - data.lastCheck > 1000 then -- Verifica a cada 1 segundo
        local x, y, z = getElementPosition(bot)
        local distMoved = getDistanceBetweenPoints3D(x, y, z, unpack(data.lastPos))
        
        if distMoved < 0.2 and getPedControlState(bot, "forwards") then
            data.stuckCount = data.stuckCount + 1
            
            if data.stuckCount >= 2 then -- Se ficar parado por 2 segundos tentando andar
                -- Tenta desviar: pula ou tenta uma pequena rotação aleatória
                movement.jump(bot)
                
                -- Se estiver muito tempo travado, avisa o servidor para recalcular rota
                if data.stuckCount >= 4 then
                    triggerServerEvent("onBotStuck", bot)
                    data.stuckCount = 0
                end
            end
        else
            data.stuckCount = 0
        end
        
        data.lastPos = {x, y, z}
        data.lastCheck = now
        stuckData[bot] = data
    end
end

function movement.checkObstacles(bot)
    if not isElement(bot) then return end
    
    local bx, by, bz = getElementPosition(bot)
    local rot = getPedRotation(bot)
    local rad = math.rad(rot)
    
    -- Decide a direção do check: se está andando pra trás, checa atrás
    local mult = 1.0
    if getPedControlState(bot, "backwards") then
        mult = -1.0
    elseif not getPedControlState(bot, "forwards") then
        return -- Não está andando
    end

    -- Ponto à frente (ou atrás) do bot
    local fx = bx - math.sin(rad) * mult * 1.2
    local fy = by + math.cos(rad) * mult * 1.2
    
    -- Raycast na altura da canela/joelho
    local isHit = processLineOfSight(bx, by, bz - 0.5, fx, fy, bz - 0.5, true, true, false, true, false, false, false, false, bot)
    
    if isHit then
        -- Se atingiu algo baixo, verifica se em cima está livre
        local isHeadHit = processLineOfSight(bx, by, bz + 0.5, fx, fy, bz + 0.5, true, true, false, true, false, false, false, false, bot)
        if not isHeadHit then
            movement.jump(bot)
        end
    end
end

function movement.jump(bot)
    if not isElement(bot) then return end
    setPedControlState(bot, "jump", true)
    setTimer(function(b)
        if isElement(b) then
            setPedControlState(b, "jump", false)
        end
    end, 800, 1, bot)
end

function movement.stop(bot)
    if not isElement(bot) then return end
    
    local data = bots[bot]
    if data then
        data.moveTarget = nil
        data.lookTarget = nil
    end
    
    setPedControlState(bot, "forwards", false)
    setPedControlState(bot, "backwards", false)
    setPedControlState(bot, "sprint", false)
    setPedControlState(bot, "walk", false)
    setPedControlState(bot, "jump", false)
end

function movement.facePosition(bot, targetX, targetY)
    if not isElement(bot) then return end
    
    local data = bots[bot]
    if data then
        data.moveTarget = {targetX, targetY}
        data.lookTarget = nil
    end
    
    -- Para rotação instantânea se necessário em alguns casos, mas deixamos o PreRender suavizar
    -- Se o bot está parado, o PreRender ainda vai girar ele suavemente para o moveTarget
end

function movement.isMoving(bot)
    return getPedControlState(bot, "forwards") or getPedControlState(bot, "backwards") or false
end

outputDebugString("[BotNPC] Movement carregado")