-- server/pvp_logic.lua
-- Lógica de combate para Player vs Player e Player vs Bot

pvpLogic = {}

addEvent("pvp:applyDamage", true)
addEventHandler("pvp:applyDamage", root, function(victim, attacker, weapon, bodypart, distance)
    if not isElement(victim) or not isElement(attacker) then return end
    
    -- Chama o combatLogic que agora cuida de todas as tabelas de dano e ossos
    if combatLogic and combatLogic.applyDamage then
        -- Passamos o weapon ID enviado pelo cliente para evitar dessincronização
        combatLogic.applyDamage(attacker, victim, 0, bodypart, weapon)
    end
    
    outputDebugString(string.format("[PvP-Dmg] %s -> %s | Weapon: %d | Bone: %d | Dist: %.1f", 
        getPlayerName(attacker), getElementType(victim), weapon, bodypart, distance))
end)
