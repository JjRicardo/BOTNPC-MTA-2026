-- shared/teams.lua
-- Sistema de times e relacionamentos para bots e players

BOTNPC = BOTNPC or {}
BOTNPC.TEAMS = BOTNPC.TEAMS or {}

-- IDs de time padrão
BOTNPC.TEAMS.ID = {
    NEUTRAL   = "neutral",
    PLAYER    = "player",
    BOT_GUARD = "bot_guard",
    BOT_ENEMY = "bot_enemy",
    ZOMBIE    = "zombie",
    MONSTER   = "monster"
}

-- Relações entre times
-- Valores possíveis: "ally", "enemy", "neutral"
BOTNPC.TEAMS.RELATIONS = {
    neutral = {
        neutral   = "neutral",
        player    = "neutral",
        bot_guard = "neutral",
        bot_enemy = "enemy",
        zombie    = "enemy",
        monster   = "enemy"
    },
    player = {
        neutral   = "neutral",
        player    = "ally",
        bot_guard = "ally",
        bot_enemy = "enemy",
        zombie    = "enemy",
        monster   = "enemy"
    },
    bot_guard = {
        neutral   = "neutral",
        player    = "ally",
        bot_guard = "ally",
        bot_enemy = "enemy",
        zombie    = "enemy",
        monster   = "enemy"
    },
    bot_enemy = {
        neutral   = "enemy",
        player    = "enemy",
        bot_guard = "enemy",
        bot_enemy = "ally",
        zombie    = "ally",
        monster   = "neutral"
    },
    zombie = {
        neutral   = "enemy",
        player    = "enemy",
        bot_guard = "enemy",
        bot_enemy = "ally",
        zombie    = "ally",
        monster   = "ally"
    },
    monster = {
        neutral   = "enemy",
        player    = "enemy",
        bot_guard = "enemy",
        bot_enemy = "enemy",
        zombie    = "ally",
        monster   = "ally"
    }
}

local DEFAULT_TEAM = BOTNPC.TEAMS.ID.NEUTRAL

-- Util: obtém ID de time a partir de elemento ou string
local function resolveTeamId(team)
    if not team then
        return DEFAULT_TEAM
    end

    local t = type(team)
    if t == "string" then
        return team
    end

    if isElement(team) then
        local teamId = getElementData(team, "bot:team")
        if teamId then
            return teamId
        end
    end

    return DEFAULT_TEAM
end

function BOTNPC.setElementTeam(element, teamId)
    if not isElement(element) then return false end
    teamId = teamId or DEFAULT_TEAM
    setElementData(element, "bot:team", teamId, true)
    return true
end

function BOTNPC.getElementTeam(element)
    if not isElement(element) then
        return DEFAULT_TEAM
    end
    return getElementData(element, "bot:team") or DEFAULT_TEAM
end

function BOTNPC.getRelation(teamA, teamB)
    local idA = resolveTeamId(teamA)
    local idB = resolveTeamId(teamB)

    local row = BOTNPC.TEAMS.RELATIONS[idA] or BOTNPC.TEAMS.RELATIONS[DEFAULT_TEAM]
    return (row and row[idB]) or "neutral"
end

function BOTNPC.areEnemies(a, b)
    return BOTNPC.getRelation(a, b) == "enemy"
end

function BOTNPC.areAllies(a, b)
    return BOTNPC.getRelation(a, b) == "ally"
end

outputDebugString("[BotNPC] Teams carregado")

