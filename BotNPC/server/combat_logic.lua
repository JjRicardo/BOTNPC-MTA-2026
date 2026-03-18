-- server/combat_logic.lua
-- Lógica de combate no servidor

combatLogic = {}

combatLogic._lastHitTick = combatLogic._lastHitTick or {}

local function sameWorld(a, b)
    return isElement(a) and isElement(b) and
        getElementDimension(a) == getElementDimension(b) and
        getElementInterior(a) == getElementInterior(b)
end

local function getAimAngleOk(attacker, target, maxDeltaDeg)
    local ax, ay, az = getElementPosition(attacker)
    local tx, ty, tz = getElementPosition(target)
    local rot = getPedRotation(attacker)
    local ang = getAngle(ax, ay, tx, ty)
    return angleDifference(rot, ang) <= (maxDeltaDeg or 60)
end

function combatLogic.validateBotHit(attacker, target, baseDamage)
    if not isElement(attacker) or not isElement(target) then return false end
    if isPedDead(attacker) or isPedDead(target) then return false end
    if not sameWorld(attacker, target) then return false end

    -- NOVO: Bots e Peds não podem causar dano enquanto estão nadando
    if isElementInWater(attacker) then
        return false
    end

    -- Rate limit por atacante->alvo (evita spam / "dano fantasma")
    local now = getTickCount()
    local key = tostring(attacker) .. ":" .. tostring(target)
    local last = combatLogic._lastHitTick[key] or 0
    if now - last < 80 then -- Reduzi para 80ms (mais fluído para SMGs)
        return false
    end
    combatLogic._lastHitTick[key] = now

    local dist = combatLogic.getDistance(attacker, target)
    local isAttackerPlayer = getElementType(attacker) == "player"
    local weaponId = getPedWeapon(attacker) or 0
    
    -- Se for explosivo, pulamos as validações de distância/LOS/FOV tradicionais
    local isExplosive = (weaponId == 16 or weaponId == 17 or weaponId == 18 or 
                         weaponId == 35 or weaponId == 36 or weaponId == 39 or 
                         weaponId == 51)

    -- Se for player, confiamos no client-side para LOS e FOV, pois ele já disparou o evento.
    if isAttackerPlayer then
        if isExplosive then return true end
        
        local weaponData = getWeaponData(weaponId) or {}
        local range = tonumber(weaponData.range) or 150
        
        if dist > (range + 25.0) then 
            return false 
        end
        return true
    end

    -- Se o atacante for um BOT
    if isExplosive then return true end
    
    -- Tolerância de distância para Melee (Reduzido para 4.0m para evitar animações distantes)
    local isMelee = (weaponId == 0 or weaponId == nil) or dist <= 4.0

    if isMelee then
        -- Se o dano for corpo a corpo, verificamos uma distância máxima razoável.
        if dist > 4.5 then return false end
        return true
    end

    -- Ranged: exige estar mais/menos mirando no alvo e dentro do alcance da arma
    -- Verificamos se o bot está encarando o alvo (horizontalmente)
    if not getAimAngleOk(attacker, target, 75) then
        return false
    end

    -- Verificamos se o bot está mirando verticalmente (não pode estar apontando pro céu/chão)
    -- Pegamos a rotação vertical real do Ped no servidor (aprox)
    -- Como o servidor não tem controle perfeito da mira, usamos uma validação de FOV 3D
    local ax, ay, az = getElementPosition(attacker)
    local tx, ty, tz = getElementPosition(target)
    local vAng = getVerticalAngle(ax, ay, az + 0.6, tx, ty, tz)
    
    -- Se o ângulo vertical for muito diferente do esperado (ex: alvo no chão e bot mirando no céu)
    -- (O servidor não sincroniza perfeitamente a mira, mas podemos evitar abusos)
    if math.abs(vAng) > 85 then -- Bloqueia se o alvo estiver fora do FOV vertical de 85 graus
        return false
    end

    local weaponId = getPedWeapon(attacker) or 0
    local weaponData = getWeaponData(weaponId) or {}
    local range = tonumber(weaponData.range) or 40
    if dist > (range + 10.0) then 
        return false
    end

    return true
end

function combatLogic.applyDamage(attacker, target, damage, bodypart, weaponOverride, animBlock, animName, isGrab)
    if not isElement(target) or isPedDead(target) then return end
    
    local attackerType = getElementType(attacker)
    local targetType = getElementType(target)
    local weaponId = weaponOverride or getPedWeapon(attacker)
    
    -- Lógica de Bloqueio (Defesa)
    local isBlocking = false
    if (weaponId == 0 or weaponId == nil) and not isGrab then
        if targetType == "player" then
            -- Jogador bloqueia
            -- Se o atacante for um BOT e o alvo um player, confiamos no client do player.
            -- Mas fazemos um check de segurança no server se o element data estiver presente.
            if getElementData(target, "player:isBlocking") then
                if getAimAngleOk(target, attacker, 120) then
                    isBlocking = true
                end
            end
        else
            -- Bot bloqueia via element data
            if getElementData(target, "bot:isBlocking") or getElementData(target, "bot:isAiming") then
                if getAimAngleOk(target, attacker, 110) then
                    isBlocking = true
                end
            end
        end
    end

    local finalDamage = damage
    if isBlocking then
        finalDamage = 0
        if targetType == "player" then
            triggerClientEvent(target, "bot:onClientBlock", target, attacker)
        end
        return
    end

    local bodypart = bodypart or 3
    local config = BOTNPC.CONSTANTS.DAMAGE_SYSTEM
    local multipliers = config.BONE_MULTIPLIERS or {}
    local boneMult = multipliers[bodypart] or 1.0
    
    if attackerType == "ped" then
        -- O atacante é um Bot
        if weaponId == 0 or weaponId == nil then
            if not damage or damage <= 0 then
                local customMelee = getElementData(attacker, "bot:meleeDamage")
                finalDamage = tonumber(customMelee) or config.PED_MELEE_DAMAGE or 15.0
            else
                finalDamage = damage
            end
        else
            if targetType == "player" then
                finalDamage = config.PED_VS_PLAYER[weaponId] or 10.0
            else
                finalDamage = config.PED_VS_PLAYER[weaponId] or 15.0
            end
        end
    elseif attackerType == "player" then
        if targetType == "player" then
            finalDamage = config.PLAYER_VS_PLAYER[weaponId] or 15.0
        elseif targetType == "ped" then
            finalDamage = config.PLAYER_VS_BOT[weaponId] or 25.0
        end
    end

    finalDamage = finalDamage * boneMult
    -- Removido a segunda aplicação de redução de bloqueio para evitar erro de cálculo redundante
    -- if isBlocking and not isGrab then finalDamage = finalDamage * 0.2 end

    if not combatLogic.validateBotHit(attacker, target, finalDamage) then
        return
    end

    if targetType == "player" then
        -- Dano em jogador (Aplica armadura e vida)
        local health = getElementHealth(target)
        local armor = getPedArmor(target)
        
        if armor > 0 then
            if armor >= finalDamage then
                setPedArmor(target, armor - finalDamage)
                finalDamage = 0
            else
                finalDamage = finalDamage - armor
                setPedArmor(target, 0)
            end
        end
        
        if finalDamage > 0 then
            health = health - finalDamage
            setElementData(target, "bot:lastAttacker", attacker, false)
            
            if health <= 0 then
                killPed(target, attacker)
            else
                setElementHealth(target, health)
            end
        end

        -- Reação visual de hit (client-side)
        if finalDamage > 0 or animBlock then
            triggerClientEvent(target, "bot:hitReaction", resourceRoot, attacker, bodypart, finalDamage, animBlock, animName, isGrab)
        end
        
    else
        -- Dano em bot ou outro ped
        if attackerType == "player" then
            local botType = getElementData(target, "bot:type")
            local protectTarget = getElementData(target, "bot:protectTarget")
            
            -- Se o atacante for o mestre do bot (guard_priv), ele NÃO fica hostil
            if botType == "guard_priv" and protectTarget == attacker then
                -- Fogo amigo ignorado: o bot continua fiel ao mestre
            elseif botType == "guard_pub" or botType == "guard_priv" then
                -- Player atacou um guarda (que não é seu mestre): fica hostil
                -- Sistema de Testemunhas: Todos os guardas próximos que virem o ataque viram testemunhas
                local x, y, z = getElementPosition(target)
                local witnesses = getElementData(attacker, "bot:witnesses") or {}
                local col = createColSphere(x, y, z, 40)
                local nearbyPeds = getElementsWithinColShape(col, "ped")
                
                for _, ped in ipairs(nearbyPeds) do
                    if isElement(ped) and getElementData(ped, "bot:isBot") then
                        local pType = getElementData(ped, "bot:type")
                        -- Se for do mesmo tipo (guarda), ele vira testemunha
                        if pType == botType then
                            witnesses[ped] = true
                        end
                    end
                end
                destroyElement(col)
                
                setElementData(attacker, "bot:witnesses", witnesses, true)
                setElementData(attacker, "bot:isHostile", true, true)
                
                -- O bot guarda foca imediatamente em quem o atacou
                setElementData(target, "bot:lastAttacker", attacker, false)
            end
        end

        local health = getElementHealth(target)
        health = health - finalDamage
        
        if health <= 0 then
            killPed(target, attacker)
        else
            setElementHealth(target, health)
            if finalDamage > 0 or animBlock then
                triggerClientEvent(root, "bot:hitReaction", resourceRoot, attacker, bodypart, finalDamage, animBlock, animName, isGrab, target)
            end
        end
    end

    -- Alerta guardas próximos
    combatLogic.alertGuards(target, attacker)
end

function combatLogic.handleBotDeath(bot)
    if not isElement(bot) then return end
    
    -- Se o bot estava em um pounce (Zombie Hunter), libera a vítima
    local pounceTarget = getElementData(bot, "bot:pounceTarget")
    if isElement(pounceTarget) then
        setElementFrozen(pounceTarget, false)
        setPedAnimation(pounceTarget, nil)
        setElementData(bot, "bot:pounceTarget", nil, true)
    end

    -- Limpa o bot das listas de testemunhas de todos os jogadores
    local players = getElementsByType("player")
    for _, player in ipairs(players) do
        local witnesses = getElementData(player, "bot:witnesses")
        if witnesses and witnesses[bot] then
            witnesses[bot] = nil
            
            -- Verifica se ainda restam testemunhas vivas
            local count = 0
            for w, _ in pairs(witnesses) do
                if isElement(w) and not isPedDead(w) then
                    count = count + 1
                end
            end
            
            if count == 0 then
                -- Nenhuma testemunha restou: o jogador está limpo!
                setElementData(player, "bot:isHostile", nil, true)
                setElementData(player, "bot:witnesses", nil, true)
            else
                setElementData(player, "bot:witnesses", witnesses, true)
            end
        end
    end

    local botType = BOTNPC.getBotType(bot)
    local cfg = BOTNPC.getTypeConfig(botType)
    if not cfg then return end
    
    -- Efeito de morte especial: Explosão
    if cfg.deathEffect == "explode" then
        local x, y, z = getElementPosition(bot)
        createExplosion(x, y, z, 6, nil) -- Explosão tipo 6 (pequena)
        
        -- Atração de Zumbis: Avisa todos os zumbis próximos
        local col = createColSphere(x, y, z, 50)
        local nearbyPeds = getElementsWithinColShape(col, "ped")
        
        for _, ped in ipairs(nearbyPeds) do
            if ped ~= bot and BOTNPC.isBot(ped) then
                local pedType = BOTNPC.getBotType(ped)
                -- Se for um tipo de zumbi, ele corre para o local da explosão
                if string.find(pedType, "zombie") then
                    -- Criamos um "ponto de interesse" temporário ou setamos um target invisível
                    -- Por enquanto, vamos apenas alertar o bot para investigar a posição
                    setElementData(ped, "bot:investigatePos", {x, y, z}, true)
                end
            end
        end
        destroyElement(col)
        outputDebugString("[BotNPC] Bot explosivo detonado! Zumbis alertados no raio de 50m.")
    end
end

function combatLogic.alertGuards(victim, attacker)
    if not isElement(victim) or not isElement(attacker) then return end
    
    local x, y, z = getElementPosition(victim)
    local col = createColSphere(x, y, z, 30)
    local nearbyPeds = getElementsWithinColShape(col, "ped")
    
    for _, ped in ipairs(nearbyPeds) do
        if getElementData(ped, "bot:isBot") then
            local protectTarget = getElementData(ped, "bot:protectTarget")
            if protectTarget == victim then
                -- O guarda detecta o atacante do seu VIP
                setElementData(ped, "target", attacker, true)
            end
        end
    end
    destroyElement(col)
end

function combatLogic.calculateDamage(weaponId, distance)
    local weaponData = getWeaponData(weaponId)
    local damage = weaponData.damage
    
    if distance > weaponData.range then
        damage = damage * 0.5 -- Dano reduzido fora do range
    end
    
    return damage
end

function combatLogic.canSee(attacker, target)
    local ax, ay, az = getElementPosition(attacker)
    local tx, ty, tz = getElementPosition(target)

    -- Em algumas builds o servidor não expõe isLineOfSightClear/processLineOfSight.
    -- Se não houver API de LOS, retornamos true para não quebrar o combate base.
    if type(isLineOfSightClear) == "function" then
        return isLineOfSightClear(
            ax, ay, az + 1,
            tx, ty, tz + 1,
            true, true, false, true, false, false, false,
            attacker
        )
    end

    if type(processLineOfSight) == "function" then
        local hit = processLineOfSight(
            ax, ay, az + 1,
            tx, ty, tz + 1,
            true,  -- checkBuildings
            true,  -- checkVehicles
            false, -- checkPeds
            true,  -- checkObjects
            true,  -- checkDummies
            false, -- seeThroughStuff
            false, -- ignoreSomeObjectsForCamera
            false, -- shootThroughStuff
            attacker
        )
        return not hit
    end

    return true
end

function combatLogic.getDistance(attacker, target)
    local ax, ay, az = getElementPosition(attacker)
    local tx, ty, tz = getElementPosition(target)
    return getDistanceBetweenPoints3D(ax, ay, az, tx, ty, tz)
end

outputDebugString("[BotNPC] CombatLogic carregado")