-- client/ai_states.lua
-- Máquina de estados da IA

aiStates = {}
local states = {}

-- Auxiliar para pegar config do bot
local function getBotConfig(bot)
    local botType = getElementData(bot, "bot:type") or "bandit"
    return BOTNPC.getTypeConfig(botType)
end

local function isStateEnabled(bot, stateName)
    local overrides = getElementData(bot, "bot:ai:states")
    if type(overrides) == "table" and overrides[stateName] ~= nil then
        return overrides[stateName] and true or false
    end
    local defaults = BOTNPC and BOTNPC.CONSTANTS and BOTNPC.CONSTANTS.STATE_ENABLED
    if type(defaults) == "table" and defaults[stateName] ~= nil then
        return defaults[stateName] and true or false
    end
    return true
end

-- Auxiliar para buscar cover próximo
local function findNearbyCover(bot, maxDist)
    local bx, by, bz = getElementPosition(bot)
    local covers = getElementsByType("colshape", resourceRoot)
    local bestCover = nil
    local bestDist = maxDist or 25.0
    
    for _, col in ipairs(covers) do
        if getElementData(col, "isCover") then
            local cx, cy, cz = getElementPosition(col)
            local d = getDistanceBetweenPoints3D(bx, by, bz, cx, cy, cz)
            if d < bestDist then
                bestCover = col
                bestDist = d
            end
        end
    end
    return bestCover
end

-- Handlers por estado
local function hasObstacleAhead(bot, distance)
    local bx, by, bz = getElementPosition(bot)
    local rz = getPedRotation(bot)
    
    local aheadX = bx - math.sin(math.rad(rz)) * distance
    local aheadY = by + math.cos(math.rad(rz)) * distance
    
    local hit, _, _, _, _, hitBuilding = processLineOfSight(
        bx, by, bz + 0.5,
        aheadX, aheadY, bz + 0.5,
        true, false, false, true, true, false, false, false, bot
    )
    
    if hit then
        local _, _, _, _, _, _, _, hitZ = processLineOfSight(
            bx, by, bz + 1.5,
            aheadX, aheadY, bz + 1.5,
            true, false, false, true, true, false, false, false, bot
        )
        return (hitZ and hitZ > bz + 0.5) and "wall" or "obstacle"
    end
    return "clear"
end

local function ensureMoveRuntime(data)
    if not data then return end
    if not data.lastPos then data.lastPos = nil end
    if not data.lastMoveCheck then data.lastMoveCheck = nil end
end

-- Função para seguir um caminho de nodes
function aiStates.followPath(bot, data)
    local path = getElementData(bot, "bot:path")
    if not path or #path == 0 then return false end

    local bx, by, bz = getElementPosition(bot)
    
    -- Se não temos um node atual no path, começa do primeiro
    if not data.currentPathNode then
        data.currentPathNode = 1
    end

    local node = path[data.currentPathNode]
    if not node then
        setElementData(bot, "bot:path", nil, true)
        data.currentPathNode = nil
        return false
    end

    local tx, ty, tz = unpack(node)
    local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)

    -- Se chegou no node atual, vai pro próximo
    if dist < 1.5 then
        data.currentPathNode = data.currentPathNode + 1
        if data.currentPathNode > #path then
            setElementData(bot, "bot:path", nil, true)
            data.currentPathNode = nil
            return false
        end
        -- Pega o novo node
        node = path[data.currentPathNode]
        tx, ty, tz = unpack(node)
    end

    local cfg = getBotConfig(bot)
    movement.moveTo(bot, tx, ty, (cfg and cfg.moveStyle) or "walk")
    return true
end

-- Verificação simples de "stuck" para evitar ficar batendo em parede
function aiStates.checkStuck(bot, data)
    if not isElement(bot) or not data or data.state == "dead" then return end

    local now = getTickCount()
    local bx, by, bz = getElementPosition(bot)

    if not data.lastPos then
        data.lastPos = {bx, by, bz}
        data.lastMoveCheck = now
        return
    end

    local elapsed = now - (data.lastMoveCheck or 0)
    if elapsed < (BOTNPC.CONSTANTS.STUCK_TIME or 3000) then
        return
    end

    local lx, ly, lz = unpack(data.lastPos)
    local dist = getDistance3D(bx, by, bz, lx, ly, lz)

    if dist < 0.5 then
        -- Se estiver em combate ou investigação e estiver travado por muito tempo (2 verificações)
        if (data.state == "combat" or data.state == "investigate") then
            data.stuckCount = (data.stuckCount or 0) + 1
            if data.stuckCount >= 3 then -- ~9 segundos travado
                data.stuckCount = 0
                data.target = nil
                aiStates.setState(bot, "patrol")
                return true
            end
        end

        local decide = math.random(1, 10)
        if decide <= 4 then
            movement.jump(bot)
        else
            local dir = math.random(0, 360)
            local nx = bx + math.cos(math.rad(dir)) * 2
            local ny = by + math.sin(math.rad(dir)) * 2
            movement.moveTo(bot, nx, ny, true)
        end
    end

    data.lastPos = {bx, by, bz}
    data.lastMoveCheck = now
end

function aiStates.updateChase(bot, data, target)
    if not isElement(target) then return end
    
    -- Tenta seguir o path se houver um
    if aiStates.followPath(bot, data) then
        return
    end

    local tx, ty, tz = getElementPosition(target)
    local bx, by, bz = getElementPosition(bot)
    
    local cfg = getBotConfig(bot)
    -- Se for um bot que deveria ser ranged mas está desarmado, tenta não colar no player
    local moveStyle = (cfg and cfg.moveStyle) or "walk"
    local isRanged = cfg and cfg.combatStyle == "ranged"
    
    -- Se for ranged e estiver muito perto, tenta recuar em vez de colidir
    local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
    if isRanged and dist < 4.0 then
        -- Tenta recuar (mesma lógica do combat update)
        local dx, dy = bx - tx, by - ty
        local mag = math.sqrt(dx*dx + dy*dy)
        if mag > 0 then
            local rx = bx + (dx/mag) * 6
            local ry = by + (dy/mag) * 6
            movement.moveTo(bot, rx, ry, moveStyle, tx, ty)
            return
        end
    end

    -- Se tem obstáculo, tenta desviar ou pular
    local obstacle = hasObstacleAhead(bot, 1.5)
    
    if obstacle == "obstacle" then
        movement.jump(bot)
    elseif obstacle == "wall" then
        -- Desvio lateral inteligente
        local angle = getAngle(bx, by, tx, ty)
        local tryAngle = angle + (data.strafeDir or 1) * 45
        local dx = bx - math.sin(math.rad(tryAngle)) * 5
        local dy = by + math.cos(math.rad(tryAngle)) * 5
        movement.moveTo(bot, dx, dy, moveStyle)
        return
    end

    -- Movimentação normal
    movement.moveTo(bot, tx, ty, moveStyle, tx, ty)
end

states.idle = {
    enter = function(bot, data)
        movement.stop(bot)
        ensureMoveRuntime(data)
        data.idleStart = getTickCount()
        data.idleDuration = math.random(3000, 6000)
    end,
    update = function(bot, data)
        local bx, by, bz = getElementPosition(bot)
        local target = perception.checkVision(bot)
        
        -- Investigação de Ponto de Interesse
        local investigatePos = getElementData(bot, "bot:investigatePos")
        local protectArea = getElementData(bot, "bot:protectArea")
        
        if investigatePos and not target then
            local ix, iy, iz = unpack(investigatePos)
            local dist = getDistanceBetweenPoints3D(bx, by, bz, ix, iy, iz)
            
            -- Se for guard_pub, só investiga se o ponto estiver dentro ou perto da zona
            local canInvestigate = true
            if protectArea and type(protectArea) == "table" then
                local ax, ay, az, radius = unpack(protectArea)
                if getDistanceBetweenPoints3D(ix, iy, iz, ax, ay, az) > radius * 1.5 then
                    canInvestigate = false
                end
            end

            if canInvestigate and dist > 3.0 then
                local cfg = getBotConfig(bot)
                movement.moveTo(bot, ix, iy, (cfg and cfg.moveStyle))
                return
            elseif not canInvestigate or dist <= 3.0 then
                setElementData(bot, "bot:investigatePos", nil, true)
            end
        end

        -- Lógica de Proteção de Área (Prioritária para guard_pub)
        if protectArea and type(protectArea) == "table" then
            local ax, ay, az, radius = unpack(protectArea)
            local distToArea = getDistanceBetweenPoints3D(bx, by, bz, ax, ay, az)
            
            if distToArea > radius then
                movement.moveTo(bot, ax, ay, distToArea > radius * 1.5)
                return
            end
        end

        if target then
            if protectArea then
                local tx, ty, tz = getElementPosition(target)
                local ax, ay, az, radius = unpack(protectArea)
                if getDistanceBetweenPoints3D(tx, ty, tz, ax, ay, az) > radius * 1.2 then
                    target = nil
                end
            end

            if target then
                data.target = target
                data.lastSeen = {getElementPosition(target)}
                data.lastSeenTime = getTickCount()
                if isStateEnabled(bot, "combat") then
                    aiStates.setState(bot, "combat")
                end
                return
            end
        end
        
        -- Proteção de Elemento (Prioritária para guard_priv / seguidores)
        -- Se o bot tem uma área para proteger (guard_pub), ele NÃO segue elementos por padrão
        local protectTarget = getElementData(bot, "bot:protectTarget") or getElementData(bot, "protecting")
        if isElement(protectTarget) and not isPedDead(protectTarget) then
            -- Se for guard_priv ou se não houver área de proteção, ele segue
            if not protectArea or getBotConfig(bot).id == "guard_priv" then
                local tx, ty, tz = getElementPosition(protectTarget)
                local tr = getPedRotation(protectTarget)
                
                -- Busca todos os guardas ativos para este mestre para definir a formação
                local myGuards = {}
                local allPeds = getElementsByType("ped", root, true)
                for _, p in ipairs(allPeds) do
                    if getElementData(p, "bot:protectTarget") == protectTarget then
                        table.insert(myGuards, p)
                    end
                end
                -- Ordena por ID para manter posições consistentes
                table.sort(myGuards, function(a, b) 
                    return (getElementData(a, "bot:id") or 0) < (getElementData(b, "bot:id") or 0) 
                end)

                local numGuards = #myGuards
                local myIndex = 1
                for i, g in ipairs(myGuards) do
                    if g == bot then myIndex = i break end
                end

                local offsetAngle = 0
                local offsetDist = 12.0

                -- FORMAÇÕES DINÂMICAS
                if numGuards == 2 then
                    -- Formação V: 2 atrás (160 e 200 graus)
                    offsetAngle = (myIndex == 1) and 160 or 200
                    offsetDist = 12.0
                elseif numGuards == 3 then
                    -- Formação Y: 2 atrás (150, 210) e 1 na frente (0)
                    if myIndex == 1 then offsetAngle = 150 offsetDist = 12.0
                    elseif myIndex == 2 then offsetAngle = 210 offsetDist = 12.0
                    else offsetAngle = 0 offsetDist = 10.0 end
                elseif numGuards == 4 then
                    -- Formação X: Protegido no centro (45, 135, 225, 315)
                    local angles = {45, 135, 225, 315}
                    offsetAngle = angles[myIndex] or 180
                    offsetDist = 12.0
                elseif numGuards >= 5 then
                    -- Formação Circular: Distribuído uniformemente
                    offsetAngle = (360 / numGuards) * (myIndex - 1)
                    offsetDist = 14.0
                else
                    -- 1 Guarda: Fica atrás (180)
                    offsetAngle = 180
                    offsetDist = 12.0
                end

                -- Matemática de Posição MTA (0=N, 90=W, 180=S, 270=E)
                local rad = math.rad(tr + offsetAngle)
                local targetX = tx - math.sin(rad) * offsetDist
                local targetY = ty + math.cos(rad) * offsetDist
                
                local distToTarget = getDistanceBetweenPoints2D(bx, by, targetX, targetY)
                local distToMaster = getDistanceBetweenPoints2D(bx, by, tx, ty)
                
                -- Lógica de seguimento Estabilizada:
                if distToTarget > 3.0 then
                    local moveStyle = distToTarget > 18.0 and "run" or "walk"
                    movement.moveTo(bot, targetX, targetY, moveStyle)
                    data.isFollowing = true
                    return
                elseif distToMaster < 6.0 then
                    -- Se o mestre se aproximar demais, o bot recua para manter distância
                    local escapeRad = math.rad(tr + offsetAngle) -- Recua na direção do seu ponto
                    movement.moveTo(bot, tx - math.sin(escapeRad) * (offsetDist + 4), ty + math.cos(escapeRad) * (offsetDist + 4), "walk")
                    return
                else
                    if data.isFollowing then
                        movement.stop(bot)
                        data.isFollowing = false
                    end
                    movement.facePosition(bot, tx, ty)
                end
                
                -- COMPORTAMENTO DE PATRULHA OCIOSA (Investigação ao redor do mestre)
                -- Se estiver parado na posição há algum tempo, faz uma pequena patrulha circular
                if not data.isFollowing and not data.target then
                    if not data.lastPatrolTime or getTickCount() - data.lastPatrolTime > 15000 then
                        local patrolAngle = math.random(0, 360)
                        local pRad = math.rad(patrolAngle)
                        local px = tx + math.sin(pRad) * (offsetDist + math.random(3, 6))
                        local py = ty + math.cos(pRad) * (offsetDist + math.random(3, 6))
                        
                        movement.moveTo(bot, px, py, "walk")
                        data.lastPatrolTime = getTickCount()
                        return
                    end
                end

                -- Impede que o bot entre em patrol genérico se estiver protegendo alguém
                data.idleStart = getTickCount() 
                if not data.isFollowing then
                    movement.facePosition(bot, tx, ty)
                end
                return
            end
        end

        if getTickCount() - (data.idleStart or 0) > (data.idleDuration or 5000) then
            aiStates.setState(bot, "patrol")
        end
    end
}

states.investigate = {
    enter = function(bot, data)
        ensureMoveRuntime(data)
        data.investigateStart = getTickCount()
        data.searchStart = nil
    end,
    update = function(bot, data)
        local target = perception.checkVision(bot)
        if target then
            data.target = target
            aiStates.setState(bot, "combat")
            return
        end

        -- Timeout Global de Investigação (Evita ficar preso no estado infinitamente)
        local now = getTickCount()
        if now - (data.investigateStart or 0) > 30000 then -- 30 segundos máximo
            setElementData(bot, "bot:investigatePos", nil, true)
            aiStates.setState(bot, "idle")
            return
        end

        -- Prioriza posição explicitamente setada (ex.: áudio / script)
        local investigatePos = getElementData(bot, "bot:investigatePos")
        local protectArea = getElementData(bot, "bot:protectArea")

        if investigatePos then
            local ix, iy, iz = unpack(investigatePos)
            
            -- Se for guard_priv e a posição de investigação for muito perto do mestre, ignora
            local protectTarget = getElementData(bot, "bot:protectTarget") or getElementData(bot, "protecting")
            if isElement(protectTarget) and getBotConfig(bot).id == "guard_priv" then
                local mx, my, mz = getElementPosition(protectTarget)
                if getDistanceBetweenPoints3D(ix, iy, iz, mx, my, mz) < 8.0 then
                    setElementData(bot, "bot:investigatePos", nil, true)
                    aiStates.setState(bot, "idle")
                    return
                end
            end

            -- Se for guard_pub, valida se o ponto está na zona
            if protectArea and type(protectArea) == "table" then
                local ax, ay, az, radius = unpack(protectArea)
                if getDistanceBetweenPoints3D(ix, iy, iz, ax, ay, az) > radius * 1.5 then
                    setElementData(bot, "bot:investigatePos", nil, true)
                    aiStates.setState(bot, "idle")
                    return
                end
            end
            data.lastSeen = {ix, iy, iz}
        end

        if not data.lastSeen then
            aiStates.setState(bot, "idle")
            return
        end

        local bx, by, bz = getElementPosition(bot)
        local lx, ly, lz = unpack(data.lastSeen)
        local dist = getDistanceBetweenPoints2D(bx, by, lx, ly)

        local cfg = getBotConfig(bot)
        local isZombie = cfg and cfg.id:find("zombie")
        
        -- Zumbis sempre correm para investigar TIROS ou EXPLOSÕES
        local investigatePos = getElementData(bot, "bot:investigatePos")
        local moveStyle = (cfg and cfg.moveStyle) or "walk"
        if isZombie and not investigatePos then
            -- Se for um som direto (não via script), zumbis ficam excitados e correm
            moveStyle = (cfg.moveStyle == "sprint") and "sprint" or "run"
        end

        -- Tenta seguir o path se houver um (útil para investigação em interiores)
        if aiStates.followPath(bot, data) then
            return
        end

        -- Movimentação: Se estiver longe do ponto (2D), ele deve se mover.
        if dist > 1.5 then
            -- Se a altura for MUITO diferente (ex: o player está num teto e o bot no chão)
            -- o bot ainda tenta chegar perto na horizontal (X,Y) antes de "desistir".
            movement.moveTo(bot, lx, ly, moveStyle)
            aiStates.checkStuck(bot, data)
            return
        end

        -- Se chegou no ponto (dist <= 1.5), inicia a fase de procura (girar)
        if not data.searchStart then data.searchStart = now end
        
        -- Se o ponto estiver em um nível muito diferente verticalmente (> 3.5m)
        -- o bot desiste mais rápido (2 segundos) pois não consegue subir paredes.
        local searchTime = (isZombie) and 3000 or 6000
        if math.abs(bz - lz) > 3.5 then
            searchTime = 2000
        end
        
        if now - data.searchStart > searchTime then
            setElementData(bot, "bot:investigatePos", nil, true)
            aiStates.setState(bot, "idle")
            return
        end

        movement.stop(bot)
        setPedRotation(bot, (getPedRotation(bot) + 10) % 360)
    end
}

states.combat = {
    enter = function(bot, data)
        ensureMoveRuntime(data)
        data.combatStart = getTickCount()
        data.lastMeleeAttack = 0
        data.strafeDir = math.random() > 0.5 and 1 or -1
        data.lastStrafeChange = getTickCount()
        data.lastRollTime = 0
        data.coverElement = nil
        data.inCover = false

        -- Som de alerta para zumbis ao entrar em combate
        local cfg = getBotConfig(bot)
        if cfg and cfg.attackSounds and #cfg.attackSounds > 0 then
            local soundPath = cfg.attackSounds[math.random(#cfg.attackSounds)]
            local bx, by, bz = getElementPosition(bot)
            local sound = playSound3D(soundPath, bx, by, bz)
            if isElement(sound) then
                setSoundMaxDistance(sound, 40)
                setSoundVolume(sound, 1.0)
                attachElements(sound, bot)
            end
        end
    end,
    update = function(bot, data)
        local target = data.target
        if not isElement(target) or isPedDead(target) or not BOTNPC.shouldAttack(bot, target) then
            data.target = nil
            setPedControlState(bot, "duck", false)
            data.inCover = false
            data.coverElement = nil
            aiStates.setState(bot, "idle")
            return
        end

        local cfg = getBotConfig(bot)
        if not cfg then
            outputDebugString("[BotNPC] Erro: Bot #" .. (data.id or "?") .. " sem config!")
            aiStates.setState(bot, "idle")
            return
        end

        local bx, by, bz = getElementPosition(bot)
        local tx, ty, tz = getElementPosition(target)
        local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
        local now = getTickCount()

        -- ISOLAMENTO DO HUNTER: Comportamento Híbrido (Pounce + Melee + Distância)
        if cfg and cfg.id == "zombie_hunter" and not data.isPouncing then
            local bx, by, bz = getElementPosition(bot)
            local tx, ty, tz = getElementPosition(target)
            local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
            
            -- 1. Alcance Melee: Se estiver colado, dá socos como outros bots
            if dist <= (cfg.attackDistance or 2.5) then
                -- Deixa cair para a lógica de melee padrão abaixo
            -- 2. Zona de Fuga: Se estiver entre melee e pounce, ele foge para se reposicionar
            elseif dist < 15.0 then
                local dx, dy = bx - tx, by - ty
                local mag = math.sqrt(dx*dx + dy*dy)
                if mag > 0 then
                    movement.moveTo(bot, tx + (dx/mag) * 30, ty + (dy/mag) * 30, "run", tx, ty)
                end
                return
            -- 3. Zona de Bote: 15m a 40m
            elseif dist <= 40.0 then
                movement.stop(bot)
                movement.facePosition(bot, tx, ty)
                setPedControlState(bot, "duck", true)
                
                if perception.canSee(bot, target) then
                    if math.random() < 0.15 then
                        combat.hunterPounce(bot, target)
                    end
                end
                return
            -- 4. Muito longe: Se aproxima de mansinho
            else
                movement.moveTo(bot, tx, ty, "walk", tx, ty)
                return
            end
        end

        -- BLOQUEIO DE IA DURANTE POUNCE
        if data.isPouncing then
            return
        end

        -- Limite de Perseguição: Se o alvo se afastar demais (2x a distância de visão), desiste.
        local baseVisionDist = (cfg and cfg.vision and cfg.vision.distance) or 60
        if dist > (baseVisionDist * 2.5) then
            data.target = nil
            setPedControlState(bot, "duck", false)
            aiStates.setState(bot, "patrol")
            return
        end

        local canSee = perception.canSee(bot, target)
        
        -- Timeout de Combate se estiver travado ou sem progresso
        if not canSee then
            if not data.lostVisionTime then 
                data.lostVisionTime = now 
                -- Solicita caminho se perdeu a visão
                triggerServerEvent("bot:requestPath", bot, tx, ty, tz)
            end
            -- Se ficou mais de 15 segundos tentando chegar na última posição sem sucesso
            if now - data.lostVisionTime > 15000 then
                data.target = nil
                data.lostVisionTime = nil
                aiStates.setState(bot, "patrol")
                return
            end
        else
            data.lostVisionTime = nil
        end

        -- Lógica de Rolamento Tático (Evita tiros)
        if cfg and cfg.canRoll and now - data.lastRollTime > 4000 then
            -- Chance de rolar se estiver sendo alvejado ou em combate próximo
            if dist < 20.0 and math.random() < 0.08 then
                local rollDir = math.random() > 0.5 and 1 or -1
                local angle = getAngle(bx, by, tx, ty) + 90 * rollDir
                local rx = bx - math.sin(math.rad(angle)) * 3
                local ry = by + math.cos(math.rad(angle)) * 3
                
                setPedControlState(bot, "aim_weapon", true)
                movement.moveTo(bot, rx, ry, true, tx, ty)
                setPedControlState(bot, "jump", true)
                data.lastRollTime = now
                
                setTimer(function(b) 
                    if isElement(b) then 
                        setPedControlState(b, "jump", false)
                    end 
                end, 400, 1, bot)
                return -- Bloqueia outras ações durante o início do rolamento
            end
        end

        -- Lógica Específica para Snipers
        local isSniper = cfg and cfg.id == "sniper"
        if isSniper then
            if canSee then
                -- Snipers ficam agachados e parados focando o alvo
                setPedControlState(bot, "duck", true)
                
                -- Se estiver muito perto do alvo (raro para sniper), tenta recuar um pouco
                if dist < 15.0 then
                    local dx, dy = bx - tx, by - ty
                    local mag = math.sqrt(dx*dx + dy*dy)
                    if mag > 0 then
                        local rx = bx + (dx/mag) * 5
                        local ry = by + (dy/mag) * 5
                        movement.moveTo(bot, rx, ry, false, tx, ty)
                    end
                else
                    movement.stop(bot)
                    movement.facePosition(bot, tx, ty)
                end
                
                combat.shoot(bot, target)
                return
            end
            
            -- Se perdeu a visão, snipers voltam para patrulha/área protegida mais rápido
            if not canSee and data.lastSeenTime and now - data.lastSeenTime > 5000 then
                data.target = nil
                aiStates.setState(bot, "patrol")
                return
            end
        end

        -- Lógica de Busca de Cover
        if cfg and cfg.prefersCover and not data.coverElement and math.random() < 0.1 then
            local cover = findNearbyCover(bot, 20.0)
            if cover then
                data.coverElement = cover
            end
        end

        -- NOVO: Lógica de Seguimento para Guardas Privados (Bodyguards) em Combate
        -- Se for guard_priv e o master estiver longe, prioriza ficar perto dele
        local protectTarget = getElementData(bot, "bot:protectTarget") or getElementData(bot, "protecting")
        if cfg.id == "guard_priv" and isElement(protectTarget) and not isPedDead(protectTarget) then
            local mx, my, mz = getElementPosition(protectTarget)
            local distToMaster = getDistanceBetweenPoints3D(bx, by, bz, mx, my, mz)
            
            -- Se estiver MUITO longe do mestre (> 25m), ele para de focar tanto no alvo e corre pro mestre
            if distToMaster > 25.0 then
                movement.moveTo(bot, mx, my, "run", tx, ty) -- Corre mas ainda olha pro alvo
                return
            elseif distToMaster < 10.0 then
                -- Se o mestre chegar muito perto durante o combate, o bot recua para manter distância de cobertura
                local dx, dy = bx - mx, by - my
                local mag = math.sqrt(dx*dx + dy*dy)
                if mag > 0 then
                    local rx, ry = bx + (dx/mag) * 5, by + (dy/mag) * 5
                    movement.moveTo(bot, rx, ry, "walk", tx, ty)
                    return
                end
            end
        end

        -- Decisão de Movimentação em Combate (Strafe, Avanço ou Recuo)

        -- Se tem um cover marcado, tenta ir até ele
        if data.coverElement and isElement(data.coverElement) then
            local cx, cy, cz = getElementPosition(data.coverElement)
            local distToCover = getDistanceBetweenPoints3D(bx, by, bz, cx, cy, cz)
            
            if distToCover > 1.0 then
                movement.moveTo(bot, cx, cy, true, tx, ty)
                data.inCover = false
            else
                -- Chegou no cover
                data.inCover = true
                local coverData = getElementData(data.coverElement, "coverData")
                movement.facePosition(bot, tx, ty)
                
                -- Se for cover baixo, agacha
                if coverData and coverData.type == "low" then
                    setPedControlState(bot, "duck", true)
                end
                
                -- Atira do cover (estilo blind fire / peek)
                if math.random() < 0.7 then
                    combat.shoot(bot, target)
                end
                
                -- Chance de sair do cover após um tempo
                if math.random() < 0.02 then
                    data.coverElement = nil
                    data.inCover = false
                    setPedControlState(bot, "duck", false)
                end
                return
            end
        end

        -- Tempo de reação inicial
        local reactionTime = BOTNPC.CONSTANTS.COMBAT.REACTION_TIME or 500
        if now - data.combatStart < reactionTime then
            movement.facePosition(bot, tx, ty)
            return
        end
        
        -- Lógica de Prioridade para Guardas
        local protectTarget = getElementData(bot, "bot:protectTarget") or getElementData(bot, "protecting")
        if isElement(protectTarget) and not isPedDead(protectTarget) then
            local ptx, pty, ptz = getElementPosition(protectTarget)
            local distToVIP = getDistanceBetweenPoints3D(bx, by, bz, ptx, pty, ptz)
            
            -- Se o VIP se afastou muito, o bot para de lutar e corre de volta
            if distToVIP > 15.0 then
                movement.moveTo(bot, ptx, pty, true, tx, ty)
                setPedControlState(bot, "duck", false)
                return
            elseif distToVIP > 8.0 then
                -- Se o VIP está se afastando mas ainda perto, anda atirando
                movement.moveTo(bot, ptx, pty, false, tx, ty)
            end

            if target == protectTarget then
                data.target = nil
                aiStates.setState(bot, "idle")
                return
            end
        end

        -- Lógica de Prioridade para Proteção de Área
        local protectArea = getElementData(bot, "bot:protectArea")
        if protectArea and type(protectArea) == "table" then
            local ax, ay, az, radius = unpack(protectArea)
            local distToArea = getDistanceBetweenPoints3D(bx, by, bz, ax, ay, az)
            
            -- Se o bot se afastou demais da zona ou o alvo saiu da zona, ele desiste
            local targetDistToArea = getDistanceBetweenPoints3D(tx, ty, tz, ax, ay, az)
            
            if distToArea > radius * 2.0 or targetDistToArea > radius * 1.5 then
                data.target = nil
                setPedControlState(bot, "duck", false)
                aiStates.setState(bot, "idle")
                movement.moveTo(bot, ax, ay, true)
                return
            end
        end

        if canSee then
            data.lastSeen = {tx, ty, tz}
            data.lastSeenTime = now
            data.lostVisionTime = nil
            data.lostVisionMoveDelay = nil
            
            -- Estilo de Combate
            local combatStyle = cfg and cfg.combatStyle or "melee"
            

            local useRanged = cfg and cfg.useRanged
            local hasWeapon = getPedWeapon(bot) > 0
            
            -- Se o bot deveria usar arma mas está desarmado, ele NÃO deve ir para melee
            -- Ele deve continuar tentando manter distância enquanto recarrega/sincroniza
            if useRanged and not hasWeapon then
                combatStyle = "ranged"
            end
            
            if combatStyle == "ranged" or (combatStyle == "hybrid" and dist > 12.0) or (useRanged and dist > 6.0) then
                -- Lógica de Distanciamento Inteligente (Evita loop de corrida)
                if dist < 8.0 and useRanged then
                    -- Se estiver MUITO perto, tenta um strafe lateral largo para sair da frente do alvo
                    setPedControlState(bot, "duck", false)
                    local angle = getAngle(bx, by, tx, ty) + 90 * (data.strafeDir or 1)
                    local sx = bx - math.sin(math.rad(angle)) * 5
                    local sy = by + math.cos(math.rad(angle)) * 5
                    movement.moveTo(bot, sx, sy, true, tx, ty)
                elseif dist < 20.0 and useRanged then
                    -- Distância de recuo tático (diagonal para trás)
                    setPedControlState(bot, "duck", false)
                    local angle = getAngle(tx, ty, bx, by) + (20 * (data.strafeDir or 1))
                    local rx = bx - math.sin(math.rad(angle)) * 10
                    local ry = by + math.cos(math.rad(angle)) * 10
                    movement.moveTo(bot, rx, ry, true, tx, ty)
                elseif dist > 40.0 and useRanged then
                    -- Se estiver muito longe, se aproxima um pouco para melhorar precisão
                    movement.moveTo(bot, tx, ty, false, tx, ty)
                else
                    -- Strafe tático padrão (mantendo distância) mantendo o olhar no alvo
                    if now - (data.lastStrafeChange or 0) > math.random(3000, 5000) then
                        data.strafeDir = (data.strafeDir or 1) * -1
                        data.lastStrafeChange = now
                    end
                    
                    local angle = getAngle(bx, by, tx, ty) + 85 * (data.strafeDir or 1)
                    local sx = bx - math.sin(math.rad(angle)) * 6
                    local sy = by + math.cos(math.rad(angle)) * 6
                    movement.moveTo(bot, sx, sy, false, tx, ty)
                end
                
                combat.shoot(bot, target)
                
            elseif combatStyle == "melee" or (combatStyle == "hybrid" and dist <= 12.0) then
                setPedControlState(bot, "duck", false)
                
                -- Se o bot está em animação de ataque, ele deve focar o alvo
                local animBlock, animName = getPedAnimation(bot)
                local isAttacking = animName and (
                    animName:find("Fight") or 
                    animName:find("Attack") or 
                    animName:find("KICK") or 
                    animName == "KILL_Knife_Player" or 
                    animName:find("BIKEV_attack") or 
                    animName:find("FightB_") or
                    animName:find("Hit") or
                    (animBlock and animBlock:find("FIGHT"))
                )
                
                -- Distância de engajamento melee: 2.5m (Gatilho de ataque)
                -- Zumbi tóxico ataca de um pouco mais longe para compensar a lentidão
                local attackDist = (cfg and cfg.meleeStyle == "toxic") and 2.8 or 2.5
                
                if dist <= attackDist then
                    movement.facePosition(bot, tx, ty)
                    -- Só para o bot se ele não estiver no meio de um golpe
                    if not isAttacking and movement.isMoving(bot) then 
                        movement.stop(bot) 
                    end
                    combat.meleeAttack(bot, target)
                else
                    -- PERSEGUE O ALVO (Nunca para de correr se estiver fora do range)
                    aiStates.updateChase(bot, data, target)
                    aiStates.checkStuck(bot, data)
                end
            end
        else
            setPedControlState(bot, "duck", false)
            -- Se perdeu de vista, vai até a última posição vista
            if data.lastSeen then
                local lx, ly, lz = unpack(data.lastSeen)
                local ldist = getDistanceBetweenPoints3D(bx, by, bz, lx, ly, lz)
                local ldist2D = getDistanceBetweenPoints2D(bx, by, lx, ly)
                
                -- Se a distância 2D é pequena mas a 3D é grande, o alvo está em outro nível (ponte/teto)
                -- ou o local é inacessível verticalmente.
                if ldist2D < 1.5 and math.abs(bz - lz) > 2.0 then
                    ldist = 0 -- Força o bot a considerar que "chegou" ao ponto X/Y
                end

                if ldist > 1.5 then
                    -- Tenta seguir o path se houver um
                    if aiStates.followPath(bot, data) then
                        aiStates.checkStuck(bot, data)
                        return
                    end

                    -- Se for um bot armado, ele espera um pouco (2-4s) antes de carregar
                    -- Isso evita o "encontro no meio" em trocas de tiro.
                    local isRanged = cfg and cfg.combatStyle == "ranged"
                    if isRanged then
                        if not data.lostVisionMoveDelay then
                            data.lostVisionMoveDelay = now + math.random(2000, 4000)
                        end
                        
                        if now < data.lostVisionMoveDelay then
                            -- Fica parado ou faz strafe curto enquanto espera
                            movement.stop(bot)
                            movement.facePosition(bot, lx, ly)
                            return
                        end
                    end

                    movement.moveTo(bot, lx, ly, (cfg and cfg.moveStyle))
                    aiStates.checkStuck(bot, data)
                else
                    -- Chegou na última posição e não viu ninguém
                    -- Se o alvo estiver muito acima/abaixo, o bot desiste mais rápido de procurar
                    local waitTime = math.abs(bz - lz) > 3.5 and 2000 or 5000
                    
                    if now - data.lastSeenTime > waitTime then
                        data.target = nil
                        data.lastSeen = nil -- Limpa a última posição para evitar "travar" nela
                        aiStates.setState(bot, "patrol")
                    end
                end
            else
                aiStates.setState(bot, "idle")
            end
        end
    end
}

states.patrol = {
    enter = function(bot, data)
        ensureMoveRuntime(data)
        data.patrolTarget = nil
    end,
    update = function(bot, data)
        if isStateEnabled(bot, "combat") then
            if perception.checkVision(bot) then
                aiStates.setState(bot, "combat")
                return
            end
        end

        local bx, by, bz = getElementPosition(bot)
        
        -- Se estiver protegendo área, patrulha dentro dela
        local protectArea = getElementData(bot, "bot:protectArea")
        if protectArea then
            if not data.patrolTarget then
                local ax, ay, az, radius = unpack(protectArea)
                local angle = math.random(0, 360)
                local dist = math.random(0, radius)
                data.patrolTarget = {ax + math.cos(math.rad(angle)) * dist, ay + math.sin(math.rad(angle)) * dist}
            end
        end

        if not data.patrolTarget then
            local angle = math.random(0, 360)
            data.patrolTarget = {bx + math.cos(math.rad(angle)) * 15, by + math.sin(math.rad(angle)) * 15}
        end

        local dist = getDistanceBetweenPoints2D(bx, by, data.patrolTarget[1], data.patrolTarget[2])
        if dist > 1.0 then
            movement.moveTo(bot, data.patrolTarget[1], data.patrolTarget[2], false) -- Patrulha sempre caminha
            aiStates.checkStuck(bot, data)
        else
            aiStates.setState(bot, "idle")
        end
    end
}

states.follow = {
    enter = function(bot, data)
        ensureMoveRuntime(data)
    end,
    update = function(bot, data)
        local leader = data.followTarget
        if not isElement(leader) or isPedDead(leader) then
            data.followTarget = nil
            aiStates.setState(bot, "idle")
            return
        end

        if isStateEnabled(bot, "combat") then
            local target = perception.checkVision(bot)
            if target then
                data.target = target
                aiStates.setState(bot, "combat")
                return
            end
        end

        local lx, ly, lz = getElementPosition(leader)
        local bx, by, bz = getElementPosition(bot)
        local dist = getDistanceBetweenPoints2D(bx, by, lx, ly)

        local cfg = getBotConfig(bot)
        local shouldRun = (cfg and cfg.moveStyle == "run") or dist > 8.0

        if dist > 5 then
            movement.moveTo(bot, lx, ly, shouldRun)
            aiStates.checkStuck(bot, data)
        elseif dist < 2 then
            local angle = getAngle(bx, by, lx, ly)
            local backX = bx - math.cos(math.rad(angle)) * 3
            local backY = by - math.sin(math.rad(angle)) * 3
            movement.moveTo(bot, backX, backY, true)
            aiStates.checkStuck(bot, data)
        else
            movement.stop(bot)
        end
    end
}

states.guard = {
    enter = function(bot, data)
        ensureMoveRuntime(data)
        data.guardStart = getTickCount()
    end,
    update = function(bot, data)
        if isStateEnabled(bot, "combat") then
            local target = perception.checkVision(bot)
            if target then
                data.target = target
                aiStates.setState(bot, "combat")
                return
            end
        end

        if data.guardPoint then
            local gx, gy = data.guardPoint[1], data.guardPoint[2]
            local bx, by = getElementPosition(bot)
            local dist = getDistanceBetweenPoints2D(bx, by, gx, gy)

            if dist > 3 then
                movement.moveTo(bot, gx, gy, false)
                aiStates.checkStuck(bot, data)
            else
                movement.stop(bot)
            end
        else
            aiStates.setState(bot, "idle")
        end
    end
}

function aiStates.setState(bot, newState)
    local data = bots[bot]
    if not data or data.state == newState then return end

    -- Se estado está desabilitado, não troca
    if not isStateEnabled(bot, newState) then
        return
    end
    
    data.state = newState
    setElementData(bot, "bot:state", newState, true)
    
    if states[newState] and states[newState].enter then
        states[newState].enter(bot, data)
    end
end

function aiStates.update(bot)
    local data = bots[bot]
    if not data or not isElement(bot) or isPedDead(bot) then return end
    
    local state = data.state or "idle"
    if not isStateEnabled(bot, state) then
        -- se estado atual foi desabilitado, cai pro idle se permitido, senão só para
        if isStateEnabled(bot, "idle") and state ~= "idle" then
            aiStates.setState(bot, "idle")
        else
            movement.stop(bot)
        end
        return
    end
    if states[state] and states[state].update then
        states[state].update(bot, data)
    end
end

outputDebugString("[BotNPC] AI States carregado")