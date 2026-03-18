-- shared/events.lua
-- Declaração de eventos

-- Eventos do servidor
addEvent("bot:create", true)
addEvent("bot:destroy", true)
addEvent("bot:shoot", true)
addEvent("bot:death", true)
addEvent("bot:stateChange", true)
addEvent("bot:targetChange", true)

-- Eventos do cliente
addEvent("bot:sync", true)
addEvent("bot:onDeath", true)
addEvent("bot:onSoundHeard", true)
addEvent("bot:streamIn", true)
addEvent("bot:streamOut", true)
addEvent("bot:damage", true)
addEvent("bot:follow", true)
addEvent("bot:guard", true)
addEvent("bot:stop", true)

outputDebugString("[BotNPC] Eventos declarados")