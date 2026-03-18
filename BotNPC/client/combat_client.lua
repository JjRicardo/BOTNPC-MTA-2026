-- client/combat_client.lua
-- Sistema de combate no cliente

combat = {}

local function getBotCombatProfile(bot)
    if not BOTNPC or not BOTNPC.BOT_TYPES or not BOTNPC.BOT_TYPES.CONFIG then
        return nil
    end
    local botType = BOTNPC.getBotType and BOTNPC.getBotType(bot) or nil
    return BOTNPC.BOT_TYPES.CONFIG[botType or "bandit"]
end

-- Animações de luta por grupo (bloco GTA: ped=melee_1, fight_b=melee_2, fight_c=melee_3, fight_d=melee_4, fight_e=kick)
-- Ver: https://wiki.multitheftauto.com/wiki/Animation_Groups
local FIGHT_ANIM_BLOCKS = {
    ped     = { "FightA_1", "FightA_2", "FightA_3", "HitA_1", "HitA_2", "HitA_3" },
    fight_b = { "FightB_1", "FightB_2", "FightB_3", "HitB_1", "HitB_2", "HitB_3" },
    fight_c = { "FightC_1", "FightC_2", "FightC_3", "HitC_1", "HitC_2", "HitC_3" },
    fight_d = { "FightD_1", "FightD_2", "FightD_3", "HitD_1", "HitD_2", "HitD_3" },
    fight_e = { "FIGHTkick", "FIGHTkick_B", "HIT_FightKick", "Hit_FightKick_B" },
}

-- Reação do alvo ao ser acertado (animação por bloco do ataque)
local HIT_REACTION_ANIMS = {
    ped     = { "HitA_1", "HitA_2", "HitA_3" },
    fight_b = { "HitB_1", "HitB_2", "HitB_3" },
    fight_c = { "HitC_1", "HitC_2", "HitC_3" },
    fight_d = { "HitD_1", "HitD_2", "HitD_3" },
    fight_e = { "HIT_FightKick", "Hit_FightKick_B" },
}

-- Animações de agarrão (ignoram bloqueio; alvo toca reação de "agarrado")
local function isGrabAnim(animName)
    if not animName or type(animName) ~= "string" then return false end
    return animName:find("_G$") or animName:find("_M$")
end

-- Combos por tipo: usa setPedAnimation para forçar o estilo (setPedFightingStyle no MTA só afeta "special attack")
local MELEE_STYLE_COMBOS = {
    boxer = {
        minAttacks = 5, maxAttacks = 9,
        punchChance = 0.92,
        intervalMin = 220, intervalMax = 380,
        punchBlock = "fight_b", kickBlock = "fight_b",
        punchAnims = FIGHT_ANIM_BLOCKS.fight_b,
        kickAnims = { "FightB_M", "FightB_G" },
        animDuration = 380,
        hitDelay = 220,
    },
    kungfu_master = {
        minAttacks = 5, maxAttacks = 8,
        punchChance = 0.55,
        intervalMin = 250, intervalMax = 400,
        punchBlock = "fight_c", kickBlock = "fight_c",
        punchAnims = FIGHT_ANIM_BLOCKS.fight_c,
        kickAnims = { "FightC_M", "FightC_G" },
        animDuration = 400,
        hitDelay = 260,
    },
    karate_master = {
        minAttacks = 4, maxAttacks = 8,
        punchChance = 0.45,
        intervalMin = 220, intervalMax = 360,
        punchBlock = "fight_d", kickBlock = "fight_d",
        punchAnims = FIGHT_ANIM_BLOCKS.fight_d,
        kickAnims = { "FightD_M", "FightD_G" },
        animDuration = 340,
        hitDelay = 200,
    },
    kickboxer = {
        minAttacks = 4, maxAttacks = 7,
        punchChance = 0.55,
        intervalMin = 240, intervalMax = 400,
        punchBlock = "fight_b", kickBlock = "fight_e",
        punchAnims = FIGHT_ANIM_BLOCKS.fight_b,
        kickAnims = FIGHT_ANIM_BLOCKS.fight_e,
        animDuration = 360,
        hitDelay = 240,
    },
    muay_thai = {
        minAttacks = 4, maxAttacks = 7,
        punchChance = 0.38,
        intervalMin = 280, intervalMax = 450,
        punchBlock = "fight_d", kickBlock = "fight_e",
        punchAnims = FIGHT_ANIM_BLOCKS.fight_d,
        kickAnims = FIGHT_ANIM_BLOCKS.fight_e,
        animDuration = 420,
        hitDelay = 280,
    },
    streetfighter = {
        minAttacks = 4, maxAttacks = 7,
        punchChance = 0.72,
        intervalMin = 260, intervalMax = 400,
        punchBlock = "ped", kickBlock = "ped",
        punchAnims = FIGHT_ANIM_BLOCKS.ped,
        kickAnims = { "FightA_M", "FightA_G" },
        animDuration = 340,
        hitDelay = 220,
    },
}

function combat.shoot(bot, target)
    if not isElement(bot) or not isElement(target) then return end
    
    local data = bots[bot]
    if not data then return end

    -- Cooldown de tiro para evitar resetar animações
    local now = getTickCount()
    if data.lastShot and now < data.lastShot then
        return
    end
    
    local weapon = getPedWeapon(bot)
    local profile = getBotCombatProfile(bot)
    
    -- Se o tipo não usa armas, nem tenta atirar
    if profile and profile.useRanged == false then
        return
    end

    -- Se o bot está desarmado mas deveria ter uma arma, tenta forçar o slot
    if weapon == 0 and profile and profile.weapon then
        for slot = 1, 12 do
            if getPedWeapon(bot, slot) == profile.weapon then
                setPedWeaponSlot(bot, slot)
                weapon = profile.weapon
                break
            end
        end
    end

    -- Se ainda estiver desarmado e o tipo for ranged, não faz nada (espera sync)
    if weapon == 0 and profile and profile.useRanged then
        return
    end

    local weaponData = getWeaponData(weapon)
    local x, y, z = getElementPosition(target)
    local bx, by, bz = getElementPosition(bot)
    local aimX, aimY, aimZ = x, y, z
    
    -- Sniper: Mira randomizada usando ossos reais
    if weapon == 34 then
        local rand = math.random()
        local boneID = 3 -- Torso padrão
        if rand > 0.85 then
            boneID = 8 -- Cabeça
        elseif rand > 0.5 then
            boneID = 3 -- Torso
        elseif rand > 0.25 then
            boneID = 2 -- Pelvis
        else
            boneID = 52 -- Perna Esq (Exemplo)
        end
        
        local tx, ty, tz = getPedBonePosition(target, boneID)
        aimX, aimY, aimZ = tx, ty, tz
        data.targetBone = boneID -- Salva para o laser visual
    end
    
    -- Mira padrão no peito (z + 0.5 a 1.2) em vez dos pés (z)
    -- Adicionamos um pequeno desvio vertical aleatório para evitar que todos os bots mirem no mesmo ponto exato
    if not data.targetBone then
        aimZ = z + 0.6 + (math.random() * 0.6)
    end
    
    -- Correção da Mira Vertical: Forçamos o bot a mirar na altura do peito do alvo
    -- O motor do GTA às vezes reseta o AimTarget se for chamado rápido demais
    setPedAimTarget(bot, aimX, aimY, aimZ)
    
    -- Sistema de tiro sincronizado (estilo slothbot)
    local shootDuration = 200
    local nextShotDelay = weaponData.fireRate or 1000

    -- Forçamos o bot a encarar o alvo horizontalmente antes de mirar verticalmente
    movement.facePosition(bot, aimX, aimY)

    -- Lógica para Granadeiros e Molotovs (Otimizado com createProjectile para precisão e efeitos)
    local isProjectile = (weapon == 16 or weapon == 18)
    if isProjectile then
        local dist = getDistanceBetweenPoints3D(bx, by, bz, x, y, z)
        
        -- Só arremessa se o alvo estiver num range razoável (5m a 35m)
        if dist < 5.0 or dist > 40.0 then
            -- Se estiver muito perto ou longe demais, o bot não arremessa, apenas encara
            movement.facePosition(bot, x, y)
            return
        end

        -- Olha para o alvo antes de arremessar
        movement.facePosition(bot, x, y)
        setPedControlState(bot, "aim_weapon", true)
        
        -- Executa animação de arremesso
        setPedAnimation(bot, "GRENADE", "WEAPON_throw", 1000, false, false, false, false)
        
        -- Agenda o nascimento do projétil sincronizado com o movimento do braço (aprox 400ms)
        setTimer(function(b, targetPed, wID)
            if isElement(b) and isElement(targetPed) then
                local tx, ty, tz = getElementPosition(targetPed)
                local startX, startY, startZ = getPedBonePosition(b, 25) -- Mão direita
                
                -- Calcula vetor de direção e força baseada na distância
                local dx, dy, dz = tx - startX, ty - startY, tz - startZ
                local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
                
                -- Normaliza o vetor e aplica velocidade
                local speed = 0.2 + (distance * 0.025)
                speed = math.min(speed, 1.2) -- Velocidade máxima
                
                local vx = (dx / distance) * speed
                local vy = (dy / distance) * speed
                local vz = (dz / distance) * speed
                
                -- Eleva o ângulo de lançamento (Z) para fazer a parábola
                vz = vz + 0.15 + (distance * 0.008)
                
                -- Adiciona um pequeno erro aleatório para espalhamento
                vx = vx + (math.random() - 0.5) * 0.05
                vy = vy + (math.random() - 0.5) * 0.05
                
                -- Cria o projétil real no mundo
                local proj = createProjectile(b, wID, startX, startY, startZ, speed, nil, 0, 0, 0, vx, vy, vz)
                
                if isElement(proj) then
                    -- Marca o projétil para detonação controlada (Preciso para fogo no chão)
                    setElementData(proj, "bot:projOwner", b, false)
                    setElementData(proj, "bot:projType", wID, false)

                    -- Fail-safe (Caso o projétil caia do mapa ou o evento não triggue)
                    setTimer(function(p, weaponID)
                        if isElement(p) then
                            local px, py, pz = getElementPosition(p)
                            if pz < -50 then -- Só detona via timer se cair do mapa (Fail-safe)
                                local explosionType = (weaponID == 18) and 1 or 0
                                createExplosion(px, py, pz, explosionType)
                                destroyElement(p)
                            end
                        end
                    end, 5000, 1, proj, wID) -- Verifica apenas uma vez após 5 segundos

                    -- Som local de arremesso
                    local s = playSound3D("sounds/mgroan" .. math.random(1, 10) .. ".ogg", startX, startY, startZ)
                    if isElement(s) then setSoundMaxDistance(s, 20) setSoundVolume(s, 0.5) end
                end
            end
        end, 400, 1, bot, target, weapon)

        -- Reseta estado após o arremesso
        setTimer(function(b)
            if isElement(b) then 
                setPedControlState(b, "aim_weapon", false)
            end
        end, 1200, 1, bot)
        
        shootDuration = 4500 -- Cooldown maior para não virar spam de granada
    elseif weapon == 34 then -- Sniper
        setPedControlState(bot, "aim_weapon", true)
        -- Snipers "miram" com laser por 1.5 segundos antes de disparar
        setTimer(function(b)
            if isElement(b) then setPedControlState(b, "fire", true) end
        end, 1500, 1, bot)
        setTimer(function(b)
            if isElement(b) then setPedControlState(b, "fire", false) end
        end, 1800, 1, bot)
        setTimer(function(b)
            if isElement(b) then setPedControlState(b, "aim_weapon", false) end
        end, 2200, 1, bot)
        shootDuration = 2500
    else
        -- Para armas automáticas, podemos atirar por um tempo randômico
        if weapon >= 28 and weapon <= 32 then -- SMGs e Rifles de Assalto
            shootDuration = math.random(500, 1500)
        end

        setPedControlState(bot, "aim_weapon", true) -- Força mira para armas comuns também
        setPedControlState(bot, "fire", true)
        
        -- Otimização: A cada frame, re-ajusta o alvo de mira enquanto atira
        -- Isso impede que o bot "trave" a mira no céu se o alvo se mover rápido
        local updateTimer = setTimer(function(b, t)
            if isElement(b) and isElement(t) then
                local tx, ty, tz = getElementPosition(t)
                setPedAimTarget(b, tx, ty, tz + 0.8)
            end
        end, 100, (shootDuration / 100) - 1, bot, target)

        setTimer(function(b)
            if isElement(b) then
                setPedControlState(b, "fire", false)
                setPedControlState(b, "aim_weapon", false)
            end
        end, shootDuration, 1, bot)
    end
    
    -- Calcula precisão e aplica dano via servidor
    local baseAccuracy = weaponData.accuracy or BOTNPC.CONSTANTS.COMBAT.ACCURACY_BASE or 0.6
    local globalMult = BOTNPC.CONSTANTS.COMBAT.ACCURACY_GLOBAL_MULT or 0.5
    local accuracy = baseAccuracy * globalMult
    
    -- Bônus por agachar
    if isPedDucked(bot) then
        accuracy = accuracy + 0.1
    end

    -- Penalidade por movimento
    if movement.isMoving(bot) then
        accuracy = accuracy - (BOTNPC.CONSTANTS.COMBAT.ACCURACY_MOVEMENT_PENALTY or 0.35)
    end
    
    accuracy = math.max(0.05, math.min(0.95, accuracy))
    local distance = perception.getDistance(bot, target)
    local damage = weaponData.damage or 10
    
    if distance > (weaponData.range or 30) then
        damage = damage * 0.4
    end
    
    -- Lógica de Acerto: Se o bot errar o alvo principal, verificamos se acerta outro bot/player no caminho
    local hitElement = target
    local isHit = (math.random() < accuracy)
    
    if not isHit and not isProjectile then
        -- Simulação de tiro perdido (Line of Sight com desvio)
        local startX, startY, startZ = getPedBonePosition(bot, 25) -- Mão direita (aproximado da arma)
        local targetX, targetY, targetZ = aimX, aimY, aimZ
        
        -- Vetor de direção original
        local dx, dy, dz = targetX - startX, targetY - startY, targetZ - startZ
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist > 0 then
            dx, dy, dz = dx/dist, dy/dist, dz/dist
            
            -- Adiciona um desvio aleatório baseado na imprecisão (spread)
            local spread = (1 - accuracy) * 0.15
            dx = dx + (math.random() - 0.5) * spread
            dy = dy + (math.random() - 0.5) * spread
            dz = dz + (math.random() - 0.5) * spread
            
            -- Estende o raio do tiro
            local endX = startX + dx * (weaponData.range or 50)
            local endY = startY + dy * (weaponData.range or 50)
            local endZ = startZ + dz * (weaponData.range or 50)
            
            -- Verifica colisão real do "tiro perdido"
            local hit, _, _, _, hitElementFound = processLineOfSight(startX, startY, startZ, endX, endY, endZ, true, true, true, true, true, false, false, false, bot)
            
            if hit and isElement(hitElementFound) and (getElementType(hitElementFound) == "ped" or getElementType(hitElementFound) == "player") then
                hitElement = hitElementFound
                isHit = true -- Acertou algo acidentalmente!
                -- Reduz dano de tiro acidental para 70% (opcional, realismo)
                damage = damage * 0.7
            end
        end
    end
    
    -- Ignora trigger de dano direto para projéteis (o dano virá da explosão real)
    if isHit and not isProjectile then
        local dmgBytes = dataToBytes("f", damage)
        
        -- Sorteia um osso para o bot acertar
        local possibleBones = {3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 6, 7, 8, 9}
        local hitBone = possibleBones[math.random(#possibleBones)]
        
        triggerServerEvent("bot:shoot", bot, hitElement, dmgBytes, hitBone)
    end
    
    -- Define o próximo momento permitido para atirar (duração do burst + intervalo entre bursts)
    data.lastShot = getTickCount() + shootDuration + (nextShotDelay * 1.5)
end

function combat.meleeAttack(bot, target)
    if not isElement(bot) or not isElement(target) then return end
    
    -- APENAS o syncer (controlador) do bot dispara o início do ataque
    if not isElementSyncer(bot) then return end
    
    local data = bots[bot]
    if not data then return end
    
    local now = getTickCount()
    
    -- Intervalo customizado baseado no bot profile
    local profile = getBotCombatProfile(bot)
    local interval = profile and profile.meleeInterval or 800
    
    if now - (data.lastMeleeAttack or 0) < interval then return end
    data.lastMeleeAttack = now
    
    -- Thinker client dispara o trigger pro servidor sincronizar o ataque para todos
    triggerServerEvent("bot:meleeTrigger", bot, target)
end

-- Evento Sincronizado: Rodado em TODOS os clientes que veem o bot (Estilo Slothbot)
addEvent("bot:onMeleeAttack", true)
addEventHandler("bot:onMeleeAttack", root, function(target)
    local bot = source
    if not isElement(bot) or not isElement(target) then return end
    
    local profile = getBotCombatProfile(bot)
    local bx, by, bz = getElementPosition(bot)
    local tx, ty, tz = getElementPosition(target)
    local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
    
    -- Se estiver muito longe para melee, ignora (fail-safe)
    if dist > 3.5 then return end

    -- ZUMBI (Combo de socos OU facada pelas costas simulando mordida)
    if profile and profile.meleeStyle == "punch_slow" then
        local bx, by, bz = getElementPosition(bot)
        local tx, ty, tz = getElementPosition(target)
        
        -- Verifica se o bot está atrás do alvo para Backstab (mordida pelas costas)
        local targetRot = getPedRotation(target)
        local botRot = getPedRotation(bot)
        local angleToTarget = getAngle(bx, by, tx, ty)
        
        -- Bot está atrás do alvo (ângulo de visão do alvo > 120° = costas)
        local isBehind = angleDifference(targetRot, angleToTarget) > 120
        local isFacingSameDir = angleDifference(targetRot, botRot) < 60
        local veryClose = dist < 2.2  -- Bem perto = ideal para "mordida"
        
        -- Se estiver atrás e perto: prioriza animação de facada pelas costas (simula mordida)
        -- Chance maior quando muito perto (100% a 2m), 70% entre 2–3.5m
        local backstabChance = veryClose and 1.0 or (isBehind and 0.7 or 0)
        if isBehind and isFacingSameDir and math.random() < backstabChance then
            -- BACKSTAB (facada pelas costas = mordida de zumbi)
            local rad = math.rad(targetRot)
            local px = tx - math.sin(rad) * 0.85
            local py = ty + math.cos(rad) * 0.85
            
            triggerServerEvent("bot:backstabSync", bot, target, px, py, bz, targetRot)
            setPedAnimation(bot, "KNIFE", "KILL_Knife_Player", -1, false, false, false, false)
            setPedAnimation(target, "KNIFE", "KILL_Knife_Ped", -1, false, false, false, false)
            
            if isElementSyncer(bot) then
                setTimer(function(b, t, p)
                    if isElement(b) and isElement(t) and not isPedDead(t) then
                        -- Validação de distância (fail-safe)
                        local bx, by, bz = getElementPosition(b)
                        local tx, ty, tz = getElementPosition(t)
                        if getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz) <= 3.5 then
                            local damage = 40 * (p and p.damageMult or 1.0) -- Reduzido dano base de backstab de 60 para 40
                            triggerServerEvent("bot:shoot", b, t, dataToBytes("f", damage), 3, "knife", "DAM_back")
                            fxAddBlood(tx, ty, tz + 0.6, 0, 0, 0, 5)
                        end
                    end
                end, 1500, 1, bot, target, profile)
            end
            return
        end

        -- ATAQUE NA FRENTE: combo de socos no alvo (3 a 5 golpes)
        movement.facePosition(bot, tx, ty)
        
        local attackCount = 0
        local maxAttacks = math.random(3, 5)  -- Combo de socos mais longo
        
        local function doZombieAttack()
            if not isElement(bot) or not isElement(target) or isPedDead(target) or attackCount >= maxAttacks then 
                return 
            end
            
            local useKick = (attackCount > 0 and attackCount % 3 == 0) and (math.random() > 0.5)  -- Ocasional chute no meio do combo
            local control = useKick and "secondary_fire" or "fire"
            
            movement.facePosition(bot, tx, ty)
            setPedControlState(bot, control, true)
            setTimer(function(b, c) if isElement(b) then setPedControlState(b, c, false) end end, 200, 1, bot, control)
            
            attackCount = attackCount + 1
            if attackCount < maxAttacks then
                setTimer(doZombieAttack, math.random(280, 420), 1)  -- Intervalo um pouco mais rápido para combo fluido
            end
        end
        doZombieAttack()
        
        -- Dano vem do Fighting Style nativo do GTA no contato
        return
    end

    -- COMBATE NATIVO: Para Bots que usam Fighting Styles do GTA (Mestres, Bosses, etc)
    -- Isso permite que o bot use o combo real do GTA (Boxe, Kung Fu, etc) e detecte o hit naturalmente
    if profile and profile.fightingStyle and profile.fightingStyle ~= 4 then
        local bx, by, bz = getElementPosition(bot)
        local tx, ty, tz = getElementPosition(target)
        local dist = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)
        
        -- SISTEMA DE ENCAIXE (Alignment): 
        -- Garante que o bot esteja na distância ideal para o soco nativo do GTA conectar
        if dist > 1.1 and dist <= 3.5 then
            local angle = math.atan2(ty - by, tx - bx)
            local nx = bx + math.cos(angle) * (dist - 0.75) -- Mais perto ainda para garantir o hit nativo
            local ny = by + math.sin(angle) * (dist - 0.75)
            setElementPosition(bot, nx, ny, bz, false)
        elseif dist > 3.5 then
            return
        end

        movement.facePosition(bot, tx, ty)

        -- Garante que o estilo de luta está aplicado (re-aplica para segurança)
        setPedFightingStyle(bot, profile.fightingStyle)

        -- Para mestres, o GTA exige o estado "aim_weapon" para ativar combos de luta especiais e lock-on
        setPedControlState(bot, "aim_weapon", true)

        -- Executa o combo nativo (Pressiona e solta o botão de bater para gerar combos fluídos)
        local attackCount = 0
        local maxAttacks = math.random(4, 7)
        
        local function doNativeAttack()
            if not isElement(bot) or not isElement(target) or isPedDead(target) or attackCount >= maxAttacks then
                if isElement(bot) then 
                    setPedControlState(bot, "aim_weapon", false)
                    setPedControlState(bot, "fire", false)
                end
                return
            end
            
            -- Atualiza face a cada golpe do combo para não errar o soco
            local _tx, _ty, _tz = getElementPosition(target)
            movement.facePosition(bot, _tx, _ty)

            -- Aciona o controle nativo "fire" (Soco)
            setPedControlState(bot, "fire", true)
            
            -- Delay variado para simular um humano "clicando" o botão de ataque
            -- Isso ajuda o motor do GTA a entender que é um combo e não um "segurar"
            local clickTime = math.random(150, 250)
            local nextClickDelay = math.random(350, 500)

            setTimer(function(b) 
                if isElement(b) then 
                    setPedControlState(b, "fire", false)
                end 
            end, clickTime, 1, bot)

            attackCount = attackCount + 1
            if attackCount < maxAttacks then
                -- Intervalo entre golpes do combo nativo (Ajustado para o ritmo do GTA)
                setTimer(doNativeAttack, nextClickDelay, 1)
            else
                -- Finaliza o estado de mira após o combo
                setTimer(function(b)
                    if isElement(b) then setPedControlState(b, "aim_weapon", false) end
                end, 600, 1, bot)
            end
        end
        
        doNativeAttack()
        return
    end

    -- OUTROS: Soco Simples
    setPedControlState(bot, "fire", true)
    setTimer(function(b) if isElement(b) then setPedControlState(b, "fire", false) end end, 200, 1, bot)
end)

-- Lógica de Aura Tóxica (Somente para o Zombie Tóxico como solicitado)
 setTimer(function()
     if isPedDead(localPlayer) then return end
     local px, py, pz = getElementPosition(localPlayer)
     
     for bot, data in pairs(bots) do
         if isElement(bot) and not isPedDead(bot) then
             local profile = getBotCombatProfile(bot)
             -- Só o zombie_toxic causa dano por aura agora
             if profile and profile.id == "toxic_zombie" then
                 local bx, by, bz = getElementPosition(bot)
                 local dist = getDistanceBetweenPoints3D(px, py, pz, bx, by, bz)
                 
                 if dist <= 3.5 then -- Raio da aura tóxica
                     -- Aplica dano leve contínuo por estar perto
                     local toxicDmg = 3.0 -- Dano por "tick" da aura
                     triggerServerEvent("bot:shoot", bot, localPlayer, dataToBytes("f", toxicDmg), 3)
                     
                     -- Efeito visual opcional (fumaça verde, etc)
                     fxAddBlood(px, py, pz + 0.5, 0, 0, 0, 1)
                 end
             end
         end
     end
 end, 1000, 0) -- Verifica a cada 1 segundo

-- RENDERIZAÇÃO DE MIRA LASER PARA SNIPERS
local function renderLasers()
    for bot, data in pairs(bots or {}) do
        if isElement(bot) and data.state == "combat" and not isPedDead(bot) then
            local botType = BOTNPC.getBotType(bot)
            if botType == "sniper" then
                local weapon = getPedWeapon(bot)
                if weapon == 34 and getPedControlState(bot, "aim_weapon") and data.target then
                    -- Pega a posição da arma (osso da mão direita)
                    local x, y, z = getPedBonePosition(bot, 25)
                    
                    -- Pega a posição atual do alvo (segue o osso sorteado)
                    local tx, ty, tz
                    if data.targetBone then
                        tx, ty, tz = getPedBonePosition(data.target, data.targetBone)
                    else
                        tx, ty, tz = getElementPosition(data.target)
                        tz = tz + 1.1 -- Mira no peito se não tiver osso definido
                    end
                    
                    -- Cor do laser (mais brilhante se estiver atirando)
                    local isFiring = getPedControlState(bot, "fire")
                    local color = isFiring and tocolor(255, 0, 0, 255) or tocolor(255, 0, 0, 120)
                    
                    -- Checa colisão para o laser não atravessar paredes
                    local hit, hx, hy, hz = processLineOfSight(x, y, z, tx, ty, tz, true, true, false, true, true, false, false, false, bot)
                    if hit then
                        dxDrawLine3D(x, y, z, hx, hy, hz, color, 2)
                        -- Ponto de impacto visual
                        dxDrawLine3D(hx, hy, hz, hx, hy, hz + 0.02, color, 5)
                    else
                        dxDrawLine3D(x, y, z, tx, ty, tz, color, 2)
                    end
                end
            end
        end
    end
end
addEventHandler("onClientRender", root, renderLasers)

-- Lógica de Pounce para Zombie Hunter (Estilo L4D)
function combat.hunterPounce(bot, target)
    if not isElement(bot) or not isElement(target) then return end
    if not isElementSyncer(bot) then return end
    
    local data = bots[bot]
    if not data or data.isPouncing then return end
    
    local now = getTickCount()
    local profile = getBotCombatProfile(bot)
    local cooldown = profile and profile.pounceCooldown or 8000
    
    if data.lastPounce and now - data.lastPounce < cooldown then return end
    
    local bx, by, bz = getElementPosition(bot)
    local tx, ty, tz = getElementPosition(target)
    local dx, dy, dz = tx - bx, ty - by, tz - bz
    local dist2D = math.sqrt(dx*dx + dy*dy)
    
    -- Range ideal do Hunter L4D (10m a 40m)
    if dist2D < 6.0 or dist2D > 40.0 then return end
    if not perception.canSee(bot, target) then return end
    
    -- Inicia sequência de bote
    data.isPouncing = true
    data.lastPounce = now
    data.pounceTarget = target
    data.pounceDamageReceived = 0
    
    -- 1. PREPARAÇÃO (Crouch do L4D)
    setPedControlState(bot, "duck", true)
    setPedAnimation(bot, "PED", "cower", 300, false, false, false, false)
    
    setTimer(function(b, t)
        if not isElement(b) or not isElement(t) then 
            if bots[b] then bots[b].isPouncing = false end
            return 
        end
        
        local bx2, by2, bz2 = getElementPosition(b)
        local tx2, ty2, tz2 = getElementPosition(t)
        
        -- Ponto de aterrissagem FIXO (permite desviar: se o player sair, hunter erra)
        local jumpData = {
            bot = b,
            target = t,
            startPos = {bx2, by2, bz2},
            landPos = {tx2, ty2, tz2},
            startTime = getTickCount(),
            duration = 800,
            peakHeight = 3.5
        }
        bots[b].activePounce = jumpData
        
        -- Limpa tarefas para movimento livre
        setPedControlState(b, "duck", false)
        setPedAnimation(b, "PARACHUTE", "FALL_SkyDive", -1, true, false, false, false)
        
        -- Grito predatório
        local s = playSound3D("sounds/mgroan" .. math.random(1, 10) .. ".ogg", bx2, by2, bz2)
        if isElement(s) then setSoundVolume(s, 1.0) attachElements(s, b) end
    end, 300, 1, bot, target)
end

-- Processamento do Salto (Trajetória de Arco Geométrico)
local function processPounceJumps()
    local now = getTickCount()
    for bot, data in pairs(bots) do
        -- 1. POSICIONAMENTO E ANIMAÇÃO DURANTE O ATAQUE (PINAGEM/TAKEDOWN)
        if data.isPounceHitting and data.pounceTarget and isElement(data.pounceTarget) then
            local target = data.pounceTarget
            local tx, ty, tz = getElementPosition(target)
            local tr = getPedRotation(target)
            
            -- FORÇA O BOT A PARAR QUALQUER MOVIMENTO (LIMPA CONTROLES)
            setPedControlState(bot, "forwards", false)
            setPedControlState(bot, "backwards", false)
            setPedControlState(bot, "left", false)
            setPedControlState(bot, "right", false)
            setPedControlState(bot, "sprint", false)
            setPedControlState(bot, "walk", false)

            -- FORÇA A VÍTIMA A FICAR PARADA E DEITADA (SEM RESETAR ANIMAÇÃO)
            local _, tAnim = getPedAnimation(target)
            if tAnim ~= "Lay_Bac_Loop" then
                setPedAnimation(target, "BEACH", "Lay_Bac_Loop", -1, true, false, false, false)
            end
            setElementVelocity(target, 0, 0, 0)
            
            -- POSICIONA O BOT MONTADO (animação já iniciada em startHunterPounceHit)
            setPedRotation(bot, tr)
            setElementPosition(bot, tx, ty, tz + 0.55, false)
        end

        -- 2. ANIMAÇÃO DE DEITADO DURANTE O RECUO (Manter deitado até o Hunter se afastar)
        if data.isPouncing and data.pounceTarget and isElement(data.pounceTarget) and not data.isPounceHitting then
            if data.activePounce and data.activePounce.isRetreat then
                local elapsedRetreat = now - data.activePounce.startTime
                -- Aumentado para 800ms (tempo quase total do pulo de recuo)
                if elapsedRetreat < 800 then
                    local _, tAnim = getPedAnimation(data.pounceTarget)
                    if tAnim ~= "Lay_Bac_Loop" then
                        setPedAnimation(data.pounceTarget, "BEACH", "Lay_Bac_Loop", -1, true, false, false, false)
                    end
                    setElementVelocity(data.pounceTarget, 0, 0, 0)
                else
                    -- Liberação final da animação local
                    local _, tAnim = getPedAnimation(data.pounceTarget)
                    if tAnim == "Lay_Bac_Loop" then
                        setPedAnimation(data.pounceTarget, nil)
                    end
                end
            end
        end

        -- 3. PROCESSAMENTO DO SALTO (ARCO)
        if data.isPouncing and data.activePounce and not data.isPounceHitting then
            local jump = data.activePounce
            if not isElement(jump.bot) then
                data.activePounce = nil
                data.isPouncing = false
                return
            end
            
            local elapsed = now - jump.startTime
            local progress = elapsed / jump.duration
            
            -- Posição final desejada (retreat = targetPos; ida = landPos FIXO para permitir desvio)
            local tx, ty, tz
            if jump.isRetreat then
                tx, ty, tz = unpack(jump.targetPos)
            else
                tx, ty, tz = unpack(jump.landPos)
            end
            
            local bx, by, bz = unpack(jump.startPos)
            
            -- Interpolação Linear (X, Y)
            local curX = bx + (tx - bx) * math.min(1.0, progress)
            local curY = by + (ty - by) * math.min(1.0, progress)
            
            local p = math.min(1.0, progress)
            local arcZ = 4 * jump.peakHeight * p * (1 - p)
            local curZ = bz + (tz - bz) * p + arcZ
            
            setElementPosition(bot, curX, curY, curZ, false)
            
            if not jump.isRetreat then
                movement.facePosition(bot, tx, ty)
            end
            
            -- Detecção de impacto (ida): só acerta se o alvo ainda estiver perto do ponto de aterrissagem (desvio)
            if not jump.isRetreat and isElement(jump.target) then
                local distToLand = getDistanceBetweenPoints3D(curX, curY, curZ, tx, ty, tz)
                if distToLand < 1.6 then
                    local ax, ay, az = getElementPosition(jump.target)
                    local distTargetToLand = getDistanceBetweenPoints3D(ax, ay, az, tx, ty, tz)
                    data.activePounce = nil
                    if distTargetToLand <= 2.0 then
                        combat.startHunterPounceHit(bot, jump.target)
                    else
                        setPedAnimation(bot, nil)
                        combat.endHunterPounce(bot, false) -- Desviou
                    end
                    return
                end
            end
            
            if progress >= 1.0 then
                data.activePounce = nil
                setPedAnimation(bot, nil)
                if jump.isRetreat then
                    data.isPouncing = false
                else
                    combat.endHunterPounce(bot, false) -- Errou (não chegou em cima do alvo)
                end
            end
        end
    end
end
addEventHandler("onClientRender", root, processPounceJumps)

function combat.startHunterPounceHit(bot, target)
    local data = bots[bot]
    if not data then return end
    
    local profile = getBotCombatProfile(bot)
    if not profile or profile.id ~= "zombie_hunter" then
        return
    end

    if isTimer(data.pounceColTimer) then killTimer(data.pounceColTimer) end
    
    data.isPouncing = true
    data.isPounceHitting = true
    data.pounceTarget = target
    data.pounceStartTime = getTickCount()
    
    -- Animação de SOCO NO CHÃO (fight_b / FightB_G = melee_2 na wiki MTA)
    setPedAnimation(bot, "fight_b", "FightB_G", -1, true, false, false, false)
    
    -- Sincroniza pinagem, anexação e animações no servidor (IMEDIATO)
    triggerServerEvent("bot:hunterPounceSync", bot, target, true)
    
    -- Loop de ataque rápido (L4D Style)
    data.pounceAttackTimer = setTimer(function(b, t)
        if not isElement(b) or not isElement(t) or isPedDead(t) then
            combat.endHunterPounce(b, true)
            return
        end
        
        -- VERIFICA SE O ALVO JÁ ESTÁ DEITADO ANTES DE DAR DANO
        local _, anim = getPedAnimation(t)
        if anim ~= "Lay_Bac_Loop" then
            return -- Espera o alvo deitar para começar a contar o dano
        end
        
        local p = getBotCombatProfile(b)
        local damage = 6 * (p and p.damageMult or 1.0)
        
        -- Efeito visual de sangue
        local tx, ty, tz = getElementPosition(t)
        fxAddBlood(tx, ty, tz + 0.5, 0, 0, 0, 3)
        
        -- Aplica o dano via servidor
        triggerServerEvent("bot:shoot", b, t, dataToBytes("f", damage), 0, "fist", "DAM_stomach")
        
        -- Finaliza após 5 segundos de ATAQUE EFETIVO (Dando dano)
        if getTickCount() - data.pounceStartTime > 5000 then
            combat.endHunterPounce(b, true)
        end
    end, 500, 0, bot, target) -- Intervalo de dano lento e pausado
end

function combat.endHunterPounce(bot, jumpAway)
    local data = bots[bot]
    if not data or not data.isPouncing then return end
    
    -- PARA O DANO IMEDIATAMENTE
    if isTimer(data.pounceAttackTimer) then killTimer(data.pounceAttackTimer) end
    if isTimer(data.pounceColTimer) then killTimer(data.pounceColTimer) end
    
    local target = data.pounceTarget
    
    -- REABILITA COLISÕES
    if isElement(bot) and isElement(target) then
        setElementCollidableWith(bot, target, true)
    end
    
    data.isPounceHitting = false
    
    -- Avisa o servidor para liberar a vítima e as animações
    triggerServerEvent("bot:hunterPounceSync", bot, target, false)
    
    -- 4. RECUO (Salto para trás baseado em Render)
    if isElement(bot) then
        -- Se errou o alvo, apenas faz a animação de queda e libera
        if not jumpAway then
            setPedAnimation(bot, "PED", "FLOOR_hit_f", 1200, false, true, false, false)
            setTimer(function(b) if bots[b] then bots[b].isPouncing = false end end, 1200, 1, bot)
            return
        end

        -- Configuração do Salto de Recuo (Arco Inverso Exato)
        local bx, by, bz = getElementPosition(bot)
        local rot = getPedRotation(bot)
        local rad = math.rad(rot)
        
        -- Calcula destino (12 metros para trás, o inverso do salto de ida)
        local tx = bx - math.sin(rad) * 12
        local ty = by + math.cos(rad) * 12
        local tz = bz
        
        local retreatData = {
            bot = bot,
            targetPos = {tx, ty, tz},
            startPos = {bx, by, bz},
            startTime = getTickCount(),
            duration = 850, -- Salto de recuo um pouco mais rápido que o de ida
            peakHeight = 3.5, -- Mesmo arco do salto de ida
            isRetreat = true
        }
        data.activePounce = retreatData -- Ativa o processamento no Render
        
        setPedAnimation(bot, "PARACHUTE", "FALL_SkyDive", -1, true, false, false, false)
        
        -- Som de fuga predatória
        local s = playSound3D("sounds/mgroan" .. math.random(1, 10) .. ".ogg", bx, by, bz)
        if isElement(s) then setSoundVolume(s, 1.0) attachElements(s, bot) end
    end
end

-- Detecção de dano para cancelar pounce
addEventHandler("onClientPedDamage", root, function(attacker, weapon, bodypart, loss)
    local bot = source
    if not isBot(bot) then return end
    
    local data = bots[bot]
    if not data then return end
    
    -- Durante o ataque no chão: acumula dano e pode soltar a vítima
    if data.isPouncing and data.isPounceHitting then
        data.pounceDamageReceived = (data.pounceDamageReceived or 0) + loss
        local profile = getBotCombatProfile(bot)
        local threshold = profile and profile.pounceDamageThreshold or 30
        if data.pounceDamageReceived >= threshold then
            combat.endHunterPounce(bot, true)
        end
        return
    end
    
    -- Durante o salto (antes de prender): tiro cancela o pulo
    if data.isPouncing and data.activePounce and not data.isPounceHitting then
        data.activePounce = nil
        combat.endHunterPounce(bot, true)
    end
end)

-- Feedback de bloqueio no cliente
addEvent("bot:onClientBlock", true)
addEventHandler("bot:onClientBlock", localPlayer, function(attacker)
    -- Efeito sonoro de impacto no bloqueio
    local x, y, z = getElementPosition(localPlayer)
    local s = playSound3D("sounds/mgroan" .. math.random(1, 5) .. ".ogg", x, y, z)
    if isElement(s) then 
        setSoundVolume(s, 0.4)
        setSoundSpeed(s, 1.5) -- Mais agudo para parecer impacto
    end
end)

-- Força animação de deitado na vítima (PLAYER)
addEvent("bot:forceVictimAnim", true)
addEventHandler("bot:forceVictimAnim", root, function(isStarting)
    if isStarting then
        -- Trava controles e animação no próprio cliente do player atacado
        addEventHandler("onClientRender", root, forceLocalVictimAnim)
        toggleAllControls(false, true, false)
    else
        removeEventHandler("onClientRender", root, forceLocalVictimAnim)
        toggleAllControls(true)
        setPedAnimation(localPlayer)
    end
end)

function forceLocalVictimAnim()
    if not isPedDead(localPlayer) then
        local _, anim = getPedAnimation(localPlayer)
        if anim ~= "Lay_Bac_Loop" then
            setPedAnimation(localPlayer, "BEACH", "Lay_Bac_Loop", -1, true, false, false, false)
        end
        setElementVelocity(localPlayer, 0, 0, 0)
    end
end

outputDebugString("[BotNPC] Combat client carregado")