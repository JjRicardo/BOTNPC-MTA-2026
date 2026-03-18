-- client/pvp_damage.lua
-- Sistema de dano customizado para Player vs Player e Player vs Ped

local function onPlayerDamage(attacker, weapon, bodypart, loss)
    -- Se o alvo for o player local e o dano for de explosão sem atacante direto (ex: carro explodindo)
    -- ou se houver um atacante mas for o player local.
    if getElementType(source) == "player" then
        -- Se for explosão/dano sem atacante (ex: 51, 16, 18), permitimos que o servidor processe
        local isExplosive = (weapon == 16 or weapon == 18 or weapon == 35 or weapon == 36 or weapon == 39 or weapon == 51)
        
        if (attacker and attacker == localPlayer) or (not attacker and isExplosive) then
            local distance = 0
            if attacker then
                local ax, ay, az = getElementPosition(attacker)
                local px, py, pz = getElementPosition(source)
                distance = getDistanceBetweenPoints3D(ax, ay, az, px, py, pz)
            end

            -- Trigger para o servidor processar o dano
            triggerServerEvent("pvp:applyDamage", localPlayer, source, attacker or localPlayer, weapon, bodypart, distance)
            cancelEvent()
        end
    end
end

-- Dano em jogadores (PvP)
addEventHandler("onClientPlayerDamage", root, onPlayerDamage)

-- Dano em peds/bots (Player vs Ped)
addEventHandler("onClientPedDamage", root, function(attacker, weapon, bodypart, loss)
    -- Se o alvo for um bot do sistema
    if isBot(source) then
        local isExplosive = (weapon == 16 or weapon == 18 or weapon == 35 or weapon == 36 or weapon == 39 or weapon == 51)
        
        -- Somente o próprio atacante reporta o dano ao servidor para evitar duplicidade
        -- Se não houver atacante e for explosão, o localPlayer reporta (como proxy)
        if (attacker and attacker == localPlayer) or (not attacker and isExplosive) then
            local distance = 0
            if attacker then
                local ax, ay, az = getElementPosition(attacker)
                local px, py, pz = getElementPosition(source)
                distance = getDistanceBetweenPoints3D(ax, ay, az, px, py, pz)
            end

            triggerServerEvent("pvp:applyDamage", localPlayer, source, attacker or localPlayer, weapon, bodypart, distance)
            cancelEvent()
        end
    end
end)
