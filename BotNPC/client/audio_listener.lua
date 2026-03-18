-- client/audio_listener.lua
-- Sistema de captura de áudio para os bots

local audioListener = {
    enabled = true,
    lastSounds = {},
    soundHistory = {},
    debug = false
}

-- Constantes de áudio (podem ser movidas para constants.lua depois)
local AUDIO_CONSTANTS = {
    FOOTSTEPS = {
        CROUCH = {
            distance = 8,
            intensity = 0.2,
            cooldown = 400
        },
        WALK = {
            distance = 15,
            intensity = 0.5,
            cooldown = 350
        },
        RUN = {
            distance = 25,
            intensity = 0.9,
            cooldown = 300
        },
        SPRINT = {
            distance = 30,
            intensity = 1.0,
            cooldown = 250
        }
    },
    
    WEAPONS = {
        -- Pistolas (menos barulho)
        [22] = {distance = 45, intensity = 0.8}, -- Colt 45
        [23] = {distance = 45, intensity = 0.8}, -- Silenced
        [24] = {distance = 50, intensity = 0.9}, -- Desert Eagle
        
        -- Submetralhadoras
        [28] = {distance = 55, intensity = 0.9}, -- Uzi
        [29] = {distance = 60, intensity = 0.95}, -- MP5
        [32] = {distance = 55, intensity = 0.9}, -- Tec9
        
        -- Rifles
        [30] = {distance = 150, intensity = 1.0}, -- AK47
        [31] = {distance = 80, intensity = 1.0}, -- M4
        
        -- Espingardas
        [25] = {distance = 60, intensity = 1.0}, -- Shotgun
        [26] = {distance = 65, intensity = 1.0}, -- Sawnoff
        [27] = {distance = 70, intensity = 1.0}, -- SPAS12
        
        -- Snipers
        [33] = {distance = 90, intensity = 0.95}, -- Country Rifle
        [34] = {distance = 100, intensity = 0.9}, -- Sniper Rifle
        
        -- Explosivos
        [16] = {distance = 120, intensity = 1.0}, -- Grenade
        [18] = {distance = 150, intensity = 1.0}, -- Molotov
        [39] = {distance = 200, intensity = 1.0}, -- Rocket Launcher
        
        -- Default para armas não listadas
        default = {distance = 60, intensity = 0.8}
    },
    
    VEHICLES = {
        ENGINE = {distance = 40, intensity = 0.7},
        HORN = {distance = 50, intensity = 0.9},
        TIRE_POP = {distance = 35, intensity = 0.6},
        EXPLOSION = {distance = 150, intensity = 1.0}
    },
    
    -- Sons ambientais/eventos
    ENVIRONMENT = {
        DOOR_BREAK = {distance = 30, intensity = 0.6},
        GLASS_BREAK = {distance = 25, intensity = 0.5},
        BULLET_HIT = {distance = 20, intensity = 0.4}
    }
}

-- Inicializar listener
function initAudioListener()
    -- Evento de tiros
    addEventHandler("onClientPlayerWeaponFire", root, onClientWeaponFire)
    
    -- Evento de passos (usando animações para detectar)
    addEventHandler("onClientPlayerDamage", root, onPedDamage)
    addEventHandler("onClientPedDamage", root, onPedDamage)
    addEventHandler("onClientPedWasted", root, onPedWasted)
    addEventHandler("onClientPlayerWasted", root, onPedWasted)
    
    -- Detectar passos via animações
    addEventHandler("onClientPlayerWeaponSwitch", root, onWeaponSwitch)
    
    -- Timer para verificar animações de movimento
    setTimer(checkPedMovement, 100, 0)
    
    -- Eventos de veículo
    addEventHandler("onClientVehicleExplode", root, onVehicleExplode)
    addEventHandler("onClientVehicleDamage", root, onVehicleDamage)
    
    -- Eventos de explosão (Granadas, RPG, etc)
    addEventHandler("onClientExplosion", root, onClientExplosion)
    
    -- Eventos de ambiente
    addEventHandler("onClientObjectBreak", root, onObjectBreak)
    
    outputDebugString("[BotNPC] AudioListener inicializado com sucesso!")
end

-- DETECTAR PASSOS
local playerStates = {}
local lastStepTimes = {}

function checkPedMovement()
    if not audioListener.enabled then return end
    
    local peds = getElementsByType("ped", root, true)
    local players = getElementsByType("player", root, true)
    
    -- Combinar peds e players para processamento
    local entities = {}
    for _, p in ipairs(peds) do table.insert(entities, p) end
    for _, p in ipairs(players) do table.insert(entities, p) end
    
    for _, entity in ipairs(entities) do
        if isElement(entity) and not isPedDead(entity) then
            local now = getTickCount()
            local entityID = tostring(entity)
            
            -- Pegar velocidade
            local vx, vy, vz = getElementVelocity(entity)
            local speed = math.sqrt(vx^2 + vy^2 + vz^2) * 50
            
            -- Verificar se está se movendo
            if speed > 0.05 then
                local isDucked = isPedDucked(entity)
                local isInVehicle = isPedInVehicle(entity)
                
                -- Só processar se não estiver em veículo
                if not isInVehicle then
                    local stepType, stepData
                    
                    -- Detectar tipo de passo baseado na velocidade
                    if isDucked then
                        stepType = "CROUCH"
                        stepData = AUDIO_CONSTANTS.FOOTSTEPS.CROUCH
                    elseif speed > 0.8 then
                        stepType = "SPRINT"
                        stepData = AUDIO_CONSTANTS.FOOTSTEPS.SPRINT
                    elseif speed > 0.4 then
                        stepType = "RUN"
                        stepData = AUDIO_CONSTANTS.FOOTSTEPS.RUN
                    else
                        stepType = "WALK"
                        stepData = AUDIO_CONSTANTS.FOOTSTEPS.WALK
                    end
                    
                    -- Verificar cooldown
                    local lastStep = lastStepTimes[entityID] or 0
                    if now - lastStep > stepData.cooldown then
                        -- Registrar som de passo
                        registerSoundForBots(
                            "footstep_" .. stepType:lower(),
                            entity,
                            stepData.intensity,
                            stepData.distance
                        )
                        
                        lastStepTimes[entityID] = now
                        
                        -- Debug visual
                        if audioListener.debug then
                            local x, y, z = getElementPosition(entity)
                            local r, g, b = getStepColor(stepType)
                            dxDrawLine3D(x, y, z, x, y, z + 2, tocolor(r, g, b, 255), 3)
                        end
                    end
                end
            end
        end
    end
end

function getStepColor(stepType)
    if stepType == "CROUCH" then return 100, 100, 100
    elseif stepType == "WALK" then return 0, 255, 0
    elseif stepType == "RUN" then return 255, 255, 0
    else return 255, 0, 0 end
end

-- DETECTAR TIROS
function onClientWeaponFire(weapon, ammo, ammoInClip, hitX, hitY, hitZ, hitElement)
    if not audioListener.enabled then return end
    
    -- Ignorar arremessos de explosivos (o som virá da explosão em si)
    if weapon == 16 or weapon == 17 or weapon == 18 or weapon == 39 then
        return
    end
    
    local shooter = source
    
    -- Pegar dados da arma
    local weaponData = AUDIO_CONSTANTS.WEAPONS[weapon] or AUDIO_CONSTANTS.WEAPONS.default
    
    -- Registrar tiro
    registerSoundForBots(
        "gunshot_" .. weapon,
        shooter,
        weaponData.intensity,
        weaponData.distance
    )
    
    -- Se acertou algo, registrar som de impacto
    if hitElement then
        local hitType = getElementType(hitElement)
        if hitType == "player" or hitType == "ped" then
            -- Som de acerto em corpo
            registerSoundForBots(
                "bullet_hit_flesh",
                hitX and {x = hitX, y = hitY, z = hitZ} or hitElement,
                0.3,
                15
            )
        elseif hitType == "vehicle" then
            -- Som de acerto em veículo
            registerSoundForBots(
                "bullet_hit_metal",
                hitX and {x = hitX, y = hitY, z = hitZ} or hitElement,
                0.4,
                20
            )
        else
            -- Som de acerto em objeto/parede
            registerSoundForBots(
                "bullet_hit_concrete",
                hitX and {x = hitX, y = hitY, z = hitZ} or hitElement,
                0.3,
                15
            )
        end
    end
end

-- DETECTAR EXPLOSÕES DE PROJÉTEIS (GRANADAS, ETC)
function onClientExplosion(x, y, z, type)
    if not audioListener.enabled then return end
    
    -- Ignorar alguns tipos de explosões irrelevantes para os bots
    -- 4 = Teargas (opcional), 12 = Tiny
    if type == 12 then return end
    
    local sourceEntity = source -- Quem causou a explosão (player/bot)
    
    registerSoundForBots(
        "explosion_" .. type,
        {x = x, y = y, z = z}, -- Posição exata do impacto
        1.0, -- Intensidade máxima
        AUDIO_CONSTANTS.VEHICLES.EXPLOSION.distance or 150
    )
end

-- DETECTAR EXPLOSÕES DE VEÍCULOS
function onVehicleExplode()
    if not audioListener.enabled then return end
    
    local vehicle = source
    local x, y, z = getElementPosition(vehicle)
    
    registerSoundForBots(
        "vehicle_explosion",
        {x = x, y = y, z = z}, -- Posição exata do veículo
        AUDIO_CONSTANTS.VEHICLES.EXPLOSION.intensity,
        AUDIO_CONSTANTS.VEHICLES.EXPLOSION.distance
    )
end

-- DETECTAR DANO EM VEÍCULOS
function onVehicleDamage(loss)
    if not audioListener.enabled then return end
    if loss < 10 then return end -- Ignorar danos pequenos
    
    local vehicle = source
    
    registerSoundForBots(
        "vehicle_damage",
        vehicle,
        0.5,
        30
    )
end

-- DETECTAR OBJETOS QUEBRADOS
function onObjectBreak(breakType)
    if not audioListener.enabled then return end
    
    local object = source
    local soundType = "glass_break"
    local data = AUDIO_CONSTANTS.ENVIRONMENT.GLASS_BREAK
    
    if breakType == "door" then
        soundType = "door_break"
        data = AUDIO_CONSTANTS.ENVIRONMENT.DOOR_BREAK
    end
    
    registerSoundForBots(
        soundType,
        object,
        data.intensity,
        data.distance
    )
end

-- REGISTRAR SOM PARA TODOS OS BOTS
function registerSoundForBots(soundType, source, intensity, maxDistance)
    if not source then return end
    
    local now = getTickCount()
    local dim = isElement(source) and getElementDimension(source) or 0
    
    -- Obter posição da fonte
    local pos
    if isElement(source) then
        pos = {getElementPosition(source)}
    else
        pos = {source.x, source.y, source.z}
    end
    
    -- Para cada bot sincronizado no cliente
    for bot, data in pairs(bots or {}) do
        if isElement(bot) and data.state ~= "dead" and bot ~= source then
            if getElementDimension(bot) == dim then
                -- Verificar distância
                local bx, by, bz = getElementPosition(bot)
                local dist = getDistanceBetweenPoints3D(bx, by, bz, pos[1], pos[2], pos[3])
                
                -- Ajuste dinâmico baseado no tipo de bot (BotNPC)
                local botMaxDistance = maxDistance
                local profile = BOTNPC and BOTNPC.getTypeConfig and BOTNPC.getTypeConfig(BOTNPC.getBotType(bot))
                
                if profile and profile.hearing then
                    if soundType:find("footstep_walk") then
                        botMaxDistance = profile.hearing.walk or maxDistance
                    elseif soundType:find("footstep_run") or soundType:find("footstep_sprint") then
                        botMaxDistance = profile.hearing.run or maxDistance
                    elseif soundType:find("gunshot") then
                        botMaxDistance = profile.hearing.gunshot or maxDistance
                    end
                end

                if dist <= botMaxDistance then
                    -- Verificação Vertical: Se houver uma diferença de altura significativa (> 3m), 
                    -- vamos checar se o som está bloqueado por teto/chão (LOS).
                    local dz = math.abs(pos[3] - bz)
                    local isBlocked = false
                    
                    if dz > 3.0 then
                        -- Se o som vier de cima ou de baixo com grande diferença, 
                        -- verificamos se há algo sólido bloqueando o caminho direto (chão da ponte, teto, etc)
                        if not isLineOfSightClear(bx, by, bz + 1, pos[1], pos[2], pos[3], true, true, false, true, true, false, false) then
                            -- Se houver bloqueio, reduzimos o alcance do som (mufled)
                            -- Para tiros, o bloqueio vertical (como uma ponte) não deve impedir totalmente a audição
                            local isGunshot = soundType:find("gunshot")
                            local blockThreshold = isGunshot and 0.8 or 0.4 -- Tiros são ouvidos através de obstáculos em até 80% do range
                            
                            if dist > (botMaxDistance * blockThreshold) then
                                isBlocked = true
                            end
                            
                            -- Som abafado: Tiros perdem menos intensidade que passos ao atravessar superfícies
                            local reduction = isGunshot and 0.8 or 0.5
                            intensity = intensity * reduction
                        end
                    end

                    if not isBlocked then
                        -- Calcular intensidade percebida
                        local perceivedIntensity = intensity * (1 - (dist / botMaxDistance))
                        
                        -- Disparar evento para o bot
                        triggerBotSoundEvent(bot, soundType, source, perceivedIntensity, dist, pos)
                    end
                end
            end
        end
    end
    
    -- Guardar no histórico para debug
    if audioListener.debug then
        table.insert(audioListener.soundHistory, 1, {
            type = soundType,
            time = now,
            pos = pos,
            intensity = intensity
        })
        
        -- Manter apenas últimos 50 sons
        if #audioListener.soundHistory > 50 then
            table.remove(audioListener.soundHistory)
        end
    end
end

-- FUNÇÃO PARA TRIGGERAR EVENTO NO BOT
function triggerBotSoundEvent(bot, soundType, source, intensity, distance, position)
    -- Chamar diretamente a percepção do bot (ambos são client-side)
    if perception and perception.onSoundHeard then
        perception.onSoundHeard(bot, {
            type = soundType,
            source = source,
            intensity = intensity,
            distance = distance,
            position = position,
            time = getTickCount()
        })
    end
end

-- Timer para registrar passos do player local (Desativado: agora usa checkPlayerMovement)
-- setTimer(function() ... end, 400, 0)

-- EVENTO PARA QUANDO JOGADOR MORRE
function onPedWasted(totalAmmo, killer, killerWeapon, bodypart)
    if not audioListener.enabled then return end
    if not isElement(source) then return end
    
    local victim = source
    
    -- Som de corpo caindo
    registerSoundForBots(
        "body_fall",
        victim,
        0.4,
        20
    )
end

-- EVENTO DE DANO (PODE GERAR GRITOS)
function onPedDamage(attacker, weapon, bodypart, loss)
    if not audioListener.enabled then return end
    if loss < 10 then return end
    
    local victim = source
    
    -- 30% de chance de gritar quando toma dano
    if math.random() < 0.3 then
        registerSoundForBots(
            "pain_sound",
            victim,
            0.5,
            25
        )
    end
end

-- TROCAR ARMA (SOM DE RELOAD)
function onWeaponSwitch(previous, current)
    if not audioListener.enabled then return end
    
    local entity = source
    
    -- Som de troca de arma (bem baixo)
    registerSoundForBots(
        "weapon_switch",
        entity,
        0.2,
        10
    )
end

-- FUNÇÕES DE DEBUG
function toggleAudioDebug()
    audioListener.debug = not audioListener.debug
    outputChatBox("[BotNPC] Audio debug: " .. (audioListener.debug and "ON" or "OFF"))
end

function drawAudioDebug()
    if not audioListener.debug then return end
    
    local sx, sy = 10, 200
    local line = 0
    
    dxDrawText("Últimos sons detectados:", sx, sy, sx + 200, sy + 20, tocolor(255, 255, 255, 255))
    sy = sy + 25
    
    local now = getTickCount()
    for i, sound in ipairs(audioListener.soundHistory) do
        local age = (now - sound.time) / 1000
        local alpha = math.max(0, 255 - (age * 100))
        
        local text = string.format("%s - %.1fm ago", sound.type, age)
        dxDrawText(text, sx, sy + (line * 15), sx + 200, sy + 20 + (line * 15), tocolor(255, 255, 255, alpha))
        
        line = line + 1
        if line > 20 then break end
    end
end

addEventHandler("onClientRender", root, drawAudioDebug)

-- COMANDO PARA DEBUG
addCommandHandler("botaudio", function()
    if not getElementData(localPlayer, "botnpc:isAdmin") then
        outputChatBox("[BotNPC] Você não tem permissão para usar o Debug de áudio.", 255, 0, 0)
        return
    end
    toggleAudioDebug()
end)

-- Inicializar
initAudioListener()