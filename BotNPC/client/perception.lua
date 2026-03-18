-- client/perception.lua
-- Sistema de percepção (visão e audição) unificado para bots

perception = {}

local DEFAULT_VISION = BOTNPC.CONSTANTS.VISION

-- Retorna distância 3D segura
function perception.getDistance(bot, target)
    if not isElement(bot) or not isElement(target) then
        return math.huge
    end
    local bx, by, bz = getElementPosition(bot)
    local tx, ty, tz = getElementPosition(target)
    return getDistance3D(bx, by, bz, tx, ty, tz)
end

-- Função utilitária para obter o nível de ruído atual de um ped (player ou NPC)
function perception.getPedNoiseLevel(ped)
    if not isPedOnGround(ped) then return 0 end
    if isPedDucked(ped) then return 0 end
    
    local vx, vy, vz = getElementVelocity(ped)
    local speed = math.sqrt(vx * vx + vy * vy)
    
    if speed > 0.25 then
        return 2 -- RUNNING
    elseif speed > 0.1 then
        return 1 -- WALKING
    end
    
    return 0
end

-- Verifica se o bot pode ver um alvo (FOV, distância, LOS, dimensão/interior)
function perception.canSee(bot, target)
    if not isElement(bot) or not isElement(target) then
        return false
    end

    if isPedDead(target) then
        return false
    end

    if getElementDimension(bot) ~= getElementDimension(target) or
       getElementInterior(bot) ~= getElementInterior(target) then
        return false
    end

    local profile = BOTNPC.getTypeConfig(BOTNPC.getBotType(bot))
    local visionCfg = (profile and profile.vision) or DEFAULT_VISION

    local bx, by, bz = getElementPosition(bot)
    local tx, ty, tz = getElementPosition(target)

    local dist = getDistance3D(bx, by, bz, tx, ty, tz)
    
    -- Fallback seguro para fov e distance
    local baseFov = visionCfg.fov or 100
    local baseDist = visionCfg.distance or 60
    local verticalFov = visionCfg.verticalFov or 70 -- Aumentado FOV vertical base
    
    -- Snipers e Guardas de longo alcance ganham bônus de visão vertical
    if profile.id == "sniper" or profile.id == "guard_pub" then
        verticalFov = 120
    end
    
    -- Proximidade Crítica: Se estiver colado (< 2.5m), o bot "percebe" apenas se estiver no mesmo nível ou visível
    if dist <= 2.5 then
        local dz = math.abs(tz - bz)
        if dz < 2.0 then -- Se a diferença de altura for pequena
            return true, dist
        end
    end

    -- Persistência de Combate: Se o bot já está em combate com esse alvo, a visão é facilitada
    local data = bots[bot]
    local isCombatTarget = (data and data.target == target)
    
    -- Ajuste dinâmico de FOV baseado na proximidade e estado de combate
    local currentFov = baseFov
    local currentVerticalFov = verticalFov
    
    -- Em combate, o bot tem "visão periférica" aumentada e foca no alvo mesmo se virar um pouco
    if isCombatTarget then
        currentFov = math.max(currentFov, 220) -- Aumenta FOV horizontal significativamente em combate
        currentVerticalFov = 160 -- Aumenta FOV vertical em combate
        
        -- Se estiver perto, vira visão 360
        if dist <= 30.0 then
            currentFov = 360
        end
    elseif visionCfg.proximityDist and dist <= visionCfg.proximityDist then
        currentFov = visionCfg.proximityFov or 360
        currentVerticalFov = 120
    end

    if dist > (isCombatTarget and (baseDist * 1.5) or baseDist) then
        return false
    end

    -- 1) Check FOV Horizontal
    local rot = getPedRotation(bot)
    local ang = getAngle(bx, by, tx, ty)
    if angleDifference(rot, ang) > currentFov / 2 then
        return false
    end
    
    -- 2) Check FOV Vertical (Evita que bots vejam coisas muito acima/abaixo sem olhar)
    local vAng = getVerticalAngle(bx, by, bz + 0.6, tx, ty, tz)
    if math.abs(vAng) > currentVerticalFov / 2 then
        -- Se estiver em combate, permitimos um ângulo vertical maior (bot "olhando" pro alvo)
        if not isCombatTarget or math.abs(vAng) > 80 then
            return false
        end
    end

    -- 3) Check Line of Sight (LOS)
    if not isLineOfSightClearEx(bx, by, bz, tx, ty, tz, bot) then
        return false
    end

    return true, dist
end

-- Procura o melhor alvo visível (player ou bot inimigo)
function perception.checkVision(bot)
    if not isElement(bot) then return nil end

    local bestTarget = nil
    local bestDist = math.huge
    
    -- Prioridade Especial: Se o bot está protegendo alguém, ele checa se o seu mestre está sob ataque
    local protectTarget = getElementData(bot, "bot:protectTarget") or getElementData(bot, "protecting")
    if isElement(protectTarget) then
        local attacker = getElementData(protectTarget, "bot:lastAttacker")
        if isElement(attacker) and not isPedDead(attacker) then
            local canSee, dist = perception.canSee(bot, attacker)
            if canSee then
                return attacker, dist -- Ataca imediatamente quem bateu no mestre
            end
        end
    end

    -- 1) Jogadores
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and not isPedDead(player) then
            if BOTNPC.shouldAttack(bot, player) then
                local canSee, dist = perception.canSee(bot, player)
                if canSee and dist < bestDist then
                    bestTarget = player
                    bestDist = dist
                end
            end
        end
    end

    -- 2) Outros bots e Peds (NPCs)
    for _, targetPed in ipairs(getElementsByType("ped", root, true)) do
        if targetPed ~= bot and isElement(targetPed) and not isPedDead(targetPed) then
            -- Verifica se é hostil ao bot
            if BOTNPC.shouldAttack(bot, targetPed) then
                local canSee, dist = perception.canSee(bot, targetPed)
                if canSee and dist < bestDist then
                    bestTarget = targetPed
                    bestDist = dist
                end
            end
        end
    end

    return bestTarget, bestDist
end

-- SISTEMA DE AUDIÇÃO (Eventos processados pelo audio_listener.lua)

function perception.onSoundHeard(bot, soundData)
    local data = bots[bot]
    if not data or data.state == "dead" then return end

    if not soundData or not soundData.position then return end
    
    local sx, sy, sz = unpack(soundData.position)
    local bx, by, bz = getElementPosition(bot)
    local dist = getDistanceBetweenPoints3D(bx, by, bz, sx, sy, sz)
    
    -- Filtro de Intensidade: Sons abafados/distantes em níveis diferentes de altura 
    -- são ignorados se não forem altos o suficiente (ex: passos agachados em ponte)
    -- TIROS e EXPLOSÕES são isentos deste filtro pois são muito altos.
    local isGunshot = soundData.type and soundData.type:find("gunshot")
    local isExplosion = soundData.type and soundData.type:find("explosion")
    
    if not isGunshot and not isExplosion and soundData.intensity < 0.25 and math.abs(sz - bz) > 3.0 then
        return
    end

    -- Validação de Hostilidade: Bots ignoram sons de aliados/neutros
    -- exceto se forem guardas privados (que seguem o player)
    local botType = BOTNPC.getBotType(bot)
    local soundSource = soundData.source
    
    if isElement(soundSource) then
        local isEnemy = BOTNPC.shouldAttack(bot, soundSource)
        local isGuardPriv = (botType == "guard_priv")
        local protectTarget = getElementData(bot, "bot:protectTarget") or getElementData(bot, "protecting")
        
        -- Se for inimigo, investiga.
        -- Se NÃO for inimigo:
        --   1) Se eu for um guarda privado e o som for do meu mestre (protectTarget), eu IGNORO.
        --   2) Caso contrário, ignoro (aliados, neutros, etc).
        if not isEnemy then
            local isMaster = (protectTarget == soundSource)
            if isMaster then
                return -- Ignora sons do mestre (passos, etc) para não entrar em modo investigação
            end
            return -- Ignora aliados/neutros
        end

        -- Filtro de Sensibilidade para Zumbis: Ignoram passos muito leves/distantes
        -- Isso evita que fiquem mudando de alvo por qualquer barulho mínimo
        if botType:find("zombie") and not isGunshot and not isExplosion then
            if soundData.intensity < 0.1 then
                return
            end
        end
    else
        -- Se o som não tem uma fonte (ex: hit em objeto/parede), ele é "neutro".
        -- Bots agressivos e zombies investigam qualquer barulho próximo suspeito.
        -- Bandidos são mais cautelosos e só investigam sons se forem altos.
        local profile = BOTNPC.getTypeConfig(botType)
        if not profile or profile.behavior == "passive" or profile.behavior == "coward" then
            return
        end
        
        -- Se for apenas um hit leve ou vidro quebrando longe, ignora se não for agressivo
        if not isGunshot and not isExplosion and soundData.intensity < 0.5 then
            return
        end
    end

    -- Se for um guarda de zona (guard_pub), ignora sons fora da zona
    local protectArea = getElementData(bot, "bot:protectArea")
    if protectArea and type(protectArea) == "table" then
        local ax, ay, az, radius = unpack(protectArea)
        if getDistanceBetweenPoints3D(sx, sy, sz, ax, ay, az) > radius * 1.5 then
            return
        end
    end

    -- Se já está em combate, o bot NÃO se distrai com sons de outras fontes.
    -- Ele só atualiza o rastro (lastSeen) se o som vier do ALVO ATUAL.
    if data.state == "combat" then
        if soundSource ~= data.target then
            return -- Ignora barulhos de terceiros enquanto luta
        end
        
        -- Se o bot NÃO vê o alvo agora, ele usa o som para manter o rastro
        if not perception.canSee(bot, data.target) then
            -- Só atualiza lastSeen se for um som alto (tiro, explosão, corrida)
            -- ou se o som vier do mesmo nível (dz < 3m)
            local dz = math.abs(sz - bz)
            if not isGunshot and not isExplosion and dz > 3.0 and soundData.intensity < 0.6 then
                return -- Ignora passos leves em outros níveis se não tem visão
            end
        end
        
        data.lastSeen = {sx, sy, sz}
        data.lastSeenTime = getTickCount()
        return
    end

    -- Se estava idle/patrol/guard, vai investigar o som
    data.lastSeen = {sx, sy, sz}
    data.lastSeenTime = getTickCount()
    data.searchStart = nil -- Resetar fase de busca para mover-se ao novo som
    
    -- Solicita caminho se estiver longe ou em outro interior
    local bx, by, bz = getElementPosition(bot)
    if getDistanceBetweenPoints3D(bx, by, bz, sx, sy, sz) > 10.0 or math.abs(bz - sz) > 2.0 then
        triggerServerEvent("bot:requestPath", bot, sx, sy, sz)
    end

    if aiStates and aiStates.setState then
        aiStates.setState(bot, "investigate")
    end
end
