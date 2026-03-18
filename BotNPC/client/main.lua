-- client/main.lua
-- Arquivo principal do cliente

-- Variáveis globais
bots = {}
botList = {}
botCount = 0
thinkIndex = 1
streamedBots = {}
currentDimension = getElementDimension(localPlayer)

-- Inicialização
function onClientResourceStart()
    outputDebugString("[BotNPC] Cliente iniciado")
    
    if streaming and streaming.init then
        streaming.init()
    end
    
    if hudDebug and hudDebug.init then
        hudDebug.init()
    end
    
    local interval = BOTNPC.CONSTANTS.TICK_INTERVAL or 250
    setTimer(function()
        if botCount > 0 then
            processAI()
        end
    end, interval, 0)
    
    -- Novo Loop de Movimento Suave (PreRender para rotação fluída)
    addEventHandler("onClientPreRender", root, function()
        if botCount == 0 then return end
        
        -- Só processa bots que estão perto e visíveis
        if not streaming or not streaming.streamedBots then return end
        
        for bot, _ in pairs(streaming.streamedBots) do
            if isElement(bot) and not isPedDead(bot) then
                local data = bots[bot]
                if data and data.state ~= "dead" then
                    -- Se o bot tem um alvo de movimento, suaviza a rotação
                    if data.moveTarget then
                        local tx, ty = data.moveTarget[1], data.moveTarget[2]
                        local bx, by = getElementPosition(bot)
                        
                        -- Rotação suave em direção ao alvo
                        local targetRot = (360 - math.deg(math.atan2((tx - bx), (ty - by)))) % 360
                        local currentRot = getPedRotation(bot)
                        
                        -- Interpolação simples de ângulo
                        local diff = targetRot - currentRot
                        if diff > 180 then diff = diff - 360 elseif diff < -180 then diff = diff + 360 end
                        
                        -- Velocidade de rotação: 10 graus por frame (aprox)
                        local step = diff * 0.15
                        setPedRotation(bot, currentRot + step)
                    end
                end
            end
        end
    end)
    
    setTimer(updateStreaming, 1000, 0)
    
    -- Sincroniza estado de bloqueio para o servidor
    setTimer(function()
        local isAiming = getControlState("aim_weapon")
        if isAiming ~= getElementData(localPlayer, "player:isBlocking") then
            setElementData(localPlayer, "player:isBlocking", isAiming, true)
        end
    end, 200, 0)
    
    -- Evento de movimento forçado (Stuck fix)
addEvent("bot:forceMove", true)
addEventHandler("bot:forceMove", root, function(x, y)
    local bot = source
    if not isElement(bot) then return end
    
    if movement and movement.moveTo then
        movement.moveTo(bot, x, y, true)
        -- Para de se mover após 1 segundo
        setTimer(function(b)
            if isElement(b) then
                movement.stop(b)
            end
        end, 1000, 1, bot)
    end
end)

-- Solicita sincronização de bots existentes
    triggerServerEvent("bot:requestSync", localPlayer)
end
addEventHandler("onClientResourceStart", resourceRoot, onClientResourceStart)

addEventHandler("onClientElementDimensionChange", localPlayer, function(_, newDim)
    currentDimension = newDim
end)

-- Processamento da IA
function processAI()
    local processed = 0
    local maxPerTick = BOTNPC.CONSTANTS.BOTS_PER_TICK or 15
    
    while processed < maxPerTick do
        local bot = botList[thinkIndex]
        
        if not bot then
            thinkIndex = 1
            break
        end
        
        local data = bots[bot]
        
        if data and data.state ~= "dead" and isElement(bot) and not isPedDead(bot) then
            -- Só processa a IA se o bot estiver "streamed" e se formos o SYNCR do bot
            -- Isso evita que múltiplos jogadores tentem mover o mesmo bot ao mesmo tempo
            if streaming and streaming.isStreamed(bot) and isElementSyncer(bot) then
                if aiStates and aiStates.update then
                    aiStates.update(bot)
                end
            end
        end
        
        thinkIndex = thinkIndex + 1
        processed = processed + 1
        
        if thinkIndex > #botList then
            thinkIndex = 1
            break
        end
    end
end

-- Streaming
function updateStreaming()
    if streaming and streaming.update then
        streaming.update()
    end
end

-- Eventos de sync
addEvent("bot:sync", true)
function onBotSync(bot, syncBytes)
    if not isElement(bot) then return end
    
    -- Decodifica dados otimizados
    local id, dimension, interior = bytesToData("iii", syncBytes)
    
    -- Garante que o interior e dimensão estejam corretos no cliente (MTA as vezes falha no sync inicial de createPed)
    if getElementDimension(bot) ~= dimension then setElementDimension(bot, dimension) end
    if getElementInterior(bot) ~= interior then setElementInterior(bot, interior) end
    
    if not bots[bot] then
        local botType = getElementData(bot, "bot:type") or "bandit"
        bots[bot] = {
            id = id,
            dimension = dimension, -- Salva para referência rápida
            interior = interior,   -- Salva para referência rápida
            state = "idle",
            botType = botType,
            lastPos = nil,
            lastMoveCheck = nil,
            target = nil,
            lastSeen = nil,
            lastSeenTime = 0
        }
        table.insert(botList, bot)
        botCount = #botList
        
        -- Sincroniza o estilo de luta client-side para garantir as animações de combo
        if BOTNPC and BOTNPC.getTypeConfig then
            local profile = BOTNPC.getTypeConfig(botType)
            if profile and profile.fightingStyle then
                setPedFightingStyle(bot, profile.fightingStyle)
            end
        end
        
        -- Aplica transparência inicial se não estiver na mesma dimensão
        if dimension ~= currentDimension then
            setElementAlpha(bot, 0)
            setElementCollisionsEnabled(bot, false)
        end
        
        -- Inicializa estado
        if aiStates and aiStates.setState then
            aiStates.setState(bot, "idle")
        end
    end
end
addEventHandler("bot:sync", root, onBotSync)

addEvent("bot:onDeath", true)
addEventHandler("bot:onDeath", root, function(killer)
    local bot = source
    if not bots[bot] then return end
    
    local data = bots[bot]
    data.state = "dead"
    
    -- Para movimento e reseta animações para a morte padrão do GTA
    if movement and movement.stop then
        movement.stop(bot)
    end
    setPedAnimation(bot)
    
    outputDebugString("[BotNPC] Bot #" .. (data.id or "?") .. " morreu no cliente")
end)

addEvent("bot:death", true)
addEventHandler("bot:death", root, function()
    local bot = source
    if bots[bot] then
        bots[bot].state = "dead"
        if movement and movement.stop then
            movement.stop(bot)
        end
    end
end)

addEvent("bot:follow", true)
addEventHandler("bot:follow", root, function(bot, target)
    if bots[bot] then
        bots[bot].followTarget = target
        if aiStates and aiStates.setState then
            aiStates.setState(bot, "follow")
        else
            bots[bot].state = "follow"
        end
    end
end)

addEvent("bot:guard", true)
addEventHandler("bot:guard", root, function(bot, x, y, z)
    if bots[bot] then
        bots[bot].guardPoint = {x, y, z}
        if aiStates and aiStates.setState then
            aiStates.setState(bot, "guard")
        else
            bots[bot].state = "guard"
        end
    end
end)

addEvent("bot:stop", true)
addEventHandler("bot:stop", root, function(bot)
    if bots[bot] then
        bots[bot].followTarget = nil
        bots[bot].guardPoint = nil
        if movement and movement.stop then
            movement.stop(bot)
        end
        if aiStates and aiStates.setState then
            aiStates.setState(bot, "idle")
        else
            bots[bot].state = "idle"
        end
    end
end)

-- Limpeza
addEventHandler("onClientElementDestroy", root, function()
    local bot = source
    if bots[bot] then
        bots[bot] = nil
        table.removeValue(botList, bot)
        botCount = #botList
    end
end)

addEventHandler("onClientPedWasted", root, function()
    local bot = source
    if bots[bot] then
        bots[bot].state = "dead"
        triggerServerEvent("bot:death", bot)
    end
end)

-- Sincronização de Fighting Style no cliente
addEvent("bot:syncFightingStyle", true)
addEventHandler("bot:syncFightingStyle", root, function(style)
    if isElement(source) then
        setPedFightingStyle(source, style)
    end
end)

-- Sincroniza via ElementData (Garante aplicação em todos os clientes)
addEventHandler("onClientElementDataChange", root, function(dataName, oldValue)
    if dataName == "bot:fightingStyle" then
        local style = getElementData(source, dataName)
        if style then
            setPedFightingStyle(source, style)
        end
    end
end)

-- Reação visual e dano customizado quando o player leva um hit nativo do bot
addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    if not isElement(attacker) or getElementType(attacker) ~= "ped" then return end
    
    -- Verifica se o atacante é um BotNPC
    if not isBot(attacker) then return end
    
    -- Se for dano Melee (Soco, Faca, etc)
    if weapon >= 0 and weapon <= 15 then
        -- Só processa se o player estiver vivo
        if isPedDead(localPlayer) then return end

        -- Verifica se o jogador está bloqueando (Client-side Check para resposta rápida)
        local isBlocking = getControlState("aim_weapon") or getElementData(localPlayer, "player:isBlocking")
        
        if isBlocking then
            local bx, by = getElementPosition(attacker)
            local px, py = getElementPosition(localPlayer)
            local rot = getPedRotation(localPlayer)
            local angle = getAngle(px, py, bx, by)
            
            if math.abs(angleDifference(rot, angle)) < 140 then
                -- Bloqueio com sucesso! Cancela o dano nativo e ignora o resto.
                cancelEvent()
                if triggerEvent("bot:onClientBlock", localPlayer, attacker) then end
                return
            end
        end

        -- Se não bloqueou, cancelamos o dano nativo para aplicar o nosso (balanceado)
        cancelEvent()

        local damageMult = profile and profile.damageMult or 1.0
        
        -- Dano Melee Base reduzido para 10 (antes 15)
        local finalDamage = 10 * damageMult
        local dmgBytes = dataToBytes("f", finalDamage)
        
        triggerServerEvent("bot:shoot", attacker, localPlayer, dmgBytes, bodypart)
        
        -- Efeito de Impacto (Feeling de PvP)
        local ax, ay, az = getElementPosition(attacker)
        local vx, vy, vz = getElementPosition(localPlayer)
        local dx, dy = vx - ax, vy - ay
        local dist = math.sqrt(dx*dx + dy*dy)
        
        -- 1. Knockback / Stagger
        local isSuper = getElementData(attacker, "bot:superPunch")
        local isMaster = (botType == "kungfu_master" or botType == "karate_master" or botType == "kickboxer")
        
        if dist > 0 then
            local force = 0.05 -- Força base (stagger leve)
            if isSuper then 
                force = 0.5 
            elseif isMaster then
                force = 0.12 -- Impacto maior para mestres
            end
            
            -- Aplica o empurrão (knockback)
            setElementVelocity(localPlayer, (dx/dist)*force, (dy/dist)*force, isSuper and 0.35 or 0.1)
        end

        -- 2. Trava controles brevemente (Hit-Stun)
        -- Isso simula o player sentindo o impacto e sendo incapaz de bater de volta por milissegundos
        local stunTime = isSuper and 600 or (isMaster and 350 or 150)
        
        if not isPedDead(localPlayer) then
            toggleAllControls(false, true, false)
            setTimer(toggleAllControls, stunTime, 1, true, true, false)
            
            -- Se for um mestre, força uma animação de dor/impacto leve
            if isMaster and not isPedInVehicle(localPlayer) then
                setPedAnimation(localPlayer, "PED", "pain_front", stunTime, false, true, false, false)
            end
        end
    end
end)

-- Detecção de dano entre Bots ou Player no Bot
addEventHandler("onClientPedDamage", root, function(attacker, weapon, bodypart, loss)
    local victim = source
    if not isBot(victim) then return end
    
    -- Só processa se o atacante for o localPlayer OU se formos o syncer da vítima
    -- (Para evitar que múltiplos clientes enviem o mesmo dano)
    local isLocalHit = (attacker == localPlayer)
    local isSyncer = isElementSyncer(victim)
    
    if not isLocalHit and not isSyncer then return end
    
    -- Se o atacante for outro BOT, processamos o dano melee Bot -> Bot
    if isBot(attacker) and weapon >= 0 and weapon <= 15 then
        cancelEvent()
        local dmgBytes = dataToBytes("f", loss * 1.5) -- Aumenta um pouco o dano Bot vs Bot para ser mais rápido
        triggerServerEvent("bot:shoot", attacker, victim, dmgBytes, bodypart)
        return
    end

    -- Dano do Player no Bot
    if isLocalHit then
        cancelEvent()
        local damage = loss
        local dmgBytes = dataToBytes("f", damage)
        triggerServerEvent("bot:onPlayerHitBot", localPlayer, victim, dmgBytes, bodypart, weapon)
    end
end)

-- Reação visual quando o player ou bot leva dano (evento remoto)
addEvent("bot:hitReaction", true)
addEventHandler("bot:hitReaction", resourceRoot, function(attacker, bodypart, damage, animBlock, animName, isGrab, targetOverride)
    local victim = targetOverride or localPlayer
    if not isElement(victim) or isPedDead(victim) then return end
    if isPedInVehicle(victim) then return end

    -- Animação de Flinch (Impacto)
    local bp = tonumber(bodypart) or 3
    local targetBlock = "ped"
    local targetAnim = "DAM_stomach"
    local time = 400
    if isGrab then time = 750 end -- Agarrão: reação mais longa (alvo "agarrado")

    if bp == 9 then targetAnim = "KO_shot_face" -- Reação mais forte para cabeça
    elseif bp == 7 or bp == 8 then targetAnim = "DAM_leg" end
    
    -- Reação específica do estilo de luta (soco/chute/agarrão)
    if animBlock and animName then
        targetBlock = animBlock
        targetAnim = animName
    end

    -- Aplica animação de reação. Bloqueio bloqueia só soco; agarrão sempre acerta e toca reação
    local isBlocking = (victim == localPlayer) and (getControlState("aim_weapon") or getElementData(victim, "player:isBlocking")) or getElementData(victim, "bot:isBlocking")
    if not isBlocking or isGrab then
        setPedAnimation(victim, targetBlock, targetAnim, time, false, false, false, false)
        
        -- Efeito de Sangue (Realismo)
        local vx, vy, vz = getElementPosition(victim)
        local bx, by, bz = getPedBonePosition(victim, bp)
        fxAddBlood(bx, by, bz, 0, 0, 0, math.random(1, 3), 1.0)
        
        -- Som de Impacto Realista
        local s = playSound3D("sounds/mgroan" .. math.random(1, 10) .. ".ogg", bx, by, bz)
        if isElement(s) then setSoundVolume(s, 0.8) setSoundMaxDistance(s, 20) end
    end

    -- Knockback (Empurrão físico)
    if isElement(attacker) then
        local ax, ay, az = getElementPosition(attacker)
        local vx, vy, vz = getElementPosition(victim)
        local dx, dy = vx - ax, vy - ay
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 0 then
            -- Força do knockback baseada no dano (mínimo 0.1, máximo 0.3)
            local force = math.max(0.1, math.min(0.3, (damage or 10) / 100))
            if isGrab then force = force * 1.5 end -- Agarrões empurram mais
            
            local curVX, curVY, curVZ = getElementVelocity(victim)
            setElementVelocity(victim, curVX + (dx/dist) * force, curVY + (dy/dist) * force, curVZ + 0.1)
        end
    end
end)

-- Exports
function getBotsInDimension(dimension)
    local result = {}
    dimension = dimension or currentDimension
    
    for bot, data in pairs(bots) do
        if isElement(bot) and data and data.state ~= "dead" then
            if getElementDimension(bot) == dimension then
                table.insert(result, bot)
            end
        end
    end
    return result
end

function getBotCount()
    return botCount
end

function isBot(element)
    if not isElement(element) then return false end
    if bots[element] then return true end
    return getElementData(element, "bot:isBot") and true or false
end

function getBotData(bot)
    return bots[bot]
end

function getBotState(bot)
    return bots[bot] and bots[bot].state or nil
end

function getBotTarget(bot)
    return bots[bot] and bots[bot].target or nil
end

function isBotStreamed(bot)
    return streamedBots[bot] or false
end

function toggleBotDebug()
    if hudDebug and hudDebug.toggle then
        hudDebug.toggle()
    end
end

-- Efeito de Tela para Explosões Próximas (Granadas/Molotovs)
addEventHandler("onClientExplosion", root, function(x, y, z, type)
    -- Só aplica o efeito se for uma explosão de granada (16), molotov (18) ou similar
    local px, py, pz = getElementPosition(localPlayer)
    local dist = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
    
    if dist < 25.0 then
        -- Intensidade baseada na distância (0.0 a 1.0)
        local intensity = (25.0 - dist) / 25.0
        
        -- Flash de luz se for muito perto (Dano ocular/atordoamento)
        if dist < 10.0 then
            fadeCamera(false, 0.1, 255, 255, 255)
            setTimer(fadeCamera, 100, 1, true, 0.8)
        end

        -- Camera Shake Suave usando PreRender por tempo limitado
        local startTime = getTickCount()
        local duration = 600 -- 0.6 segundos de tremor
        
        local function applyShake()
            local now = getTickCount()
            local elapsed = now - startTime
            
            if elapsed > duration then
                removeEventHandler("onClientPreRender", root, applyShake)
                return
            end
            
            -- Reduz a intensidade conforme o tempo passa (fade out do tremor)
            local timeMult = (duration - elapsed) / duration
            local curIntensity = intensity * timeMult * 0.4 -- Escala final
            
            local ox = (math.random() - 0.5) * curIntensity
            local oy = (math.random() - 0.5) * curIntensity
            local oz = (math.random() - 0.5) * curIntensity
            
            -- Aplica offset na posição e no alvo da câmera (Mais fluido que setCameraRotation)
            local cx, cy, cz, lx, ly, lz = getCameraMatrix()
            setCameraMatrix(cx + ox, cy + oy, cz + oz, lx, ly, lz)
        end
        addEventHandler("onClientPreRender", root, applyShake)
        
        -- Garante que a câmera volte ao normal após o efeito
        setTimer(function()
            setCameraTarget(localPlayer)
        end, duration + 100, 1)
    end
end)

outputDebugString("[BotNPC] Client main carregado")