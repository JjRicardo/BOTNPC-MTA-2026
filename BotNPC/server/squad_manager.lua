-- server/squad_manager.lua
-- Gerenciador de esquadrões

squadManager = {}

squadManager.squads = {}
squadManager.nextId = 1

function squadManager.createSquad(name, leader)
    local squad = {
        id = squadManager.nextId,
        name = name or "Squad " .. squadManager.nextId,
        leader = leader,
        members = {},
        formation = "line",
        spacing = 3,
        createdAt = getTickCount()
    }
    
    if leader then
        squad.members[leader] = true
        setElementData(leader, "squadId", squad.id, true)
        setElementData(leader, "squadLeader", true, true)
    end
    
    squadManager.squads[squad.id] = squad
    squadManager.nextId = squadManager.nextId + 1
    
    outputDebugString("[BotNPC] Esquadrão '" .. squad.name .. "' criado")
    
    return squad
end

function squadManager.addMember(squadId, bot)
    local squad = squadManager.squads[squadId]
    if not squad then return false end
    
    squad.members[bot] = true
    setElementData(bot, "squadId", squadId, true)
    
    if not squad.leader then
        squadManager.setLeader(squadId, bot)
    end
    
    return true
end

function squadManager.removeMember(squadId, bot)
    local squad = squadManager.squads[squadId]
    if not squad then return false end
    
    squad.members[bot] = nil
    setElementData(bot, "squadId", nil, true)
    setElementData(bot, "squadLeader", nil, true)
    
    if squad.leader == bot then
        squad.leader = nil
        for member in pairs(squad.members) do
            squadManager.setLeader(squadId, member)
            break
        end
    end
    
    return true
end

function squadManager.setLeader(squadId, bot)
    local squad = squadManager.squads[squadId]
    if not squad or not squad.members[bot] then return false end
    
    if squad.leader then
        setElementData(squad.leader, "squadLeader", nil, true)
    end
    
    squad.leader = bot
    setElementData(bot, "squadLeader", true, true)
    
    return true
end

function squadManager.setFormation(squadId, formation)
    local squad = squadManager.squads[squadId]
    if not squad then return false end
    
    squad.formation = formation
    return true
end

function squadManager.getSquad(squadId)
    return squadManager.squads[squadId]
end

function squadManager.getBotSquad(bot)
    local squadId = getElementData(bot, "squadId")
    if not squadId then return nil end
    return squadManager.squads[squadId]
end

function squadManager.destroySquad(squadId)
    local squad = squadManager.squads[squadId]
    if not squad then return false end
    
    for member in pairs(squad.members) do
        if isElement(member) then
            setElementData(member, "squadId", nil, true)
            setElementData(member, "squadLeader", nil, true)
        end
    end
    
    squadManager.squads[squadId] = nil
    return true
end

outputDebugString("[BotNPC] SquadManager carregado")