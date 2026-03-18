-- shared/bot_types.lua
-- Definição de tipos/arquetipos de bots e regras de agressão

BOTNPC = BOTNPC or {}
BOTNPC.BOT_TYPES = BOTNPC.BOT_TYPES or {}

BOTNPC.BOT_TYPES.CONFIG = {
    -- Heavy Boss (Super Soco e muita vida)
    heavy_boss = {
        id = "heavy_boss",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        meleeStyle = "heavy",
        fightingStyle = 15, -- KUNGFU ou similar pesado
        superPunch = true,  -- Habilita o knockback massivo
        moveStyle = "run",
        health = 500,
        damageMult = 1.2,
        vision = { distance = 60, fov = 140 },
        hearing = { walk = 40, run = 80, gunshot = 200 }
    },

    -- Bandido armado (corre até o alvo ou atira)
    bandit = {
        id = "bandit",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "ranged",
        useRanged = true,
        canRoll = true,      -- Habilita rolamento tático
        prefersCover = true, -- Tenta buscar cover se disponível
        weapon = 31, -- M4
        ammo = 500,
        moveStyle = "run",
        health = 100,
        damageMult = 0.7,
        vision = { distance = 80, fov = 110 },
        hearing = { walk = 30, run = 60, gunshot = 150 }
    },

    -- Zumbi que caminha até o alvo (Wakie - Lento)
    zombie_wakie = {
        id = "zombie_wakie",
        baseTeam = "zombie",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        meleeStyle = "punch_slow",
        fightingStyle = 15, -- Estilo Lutador (GRAB_KICK)
        meleeInterval = 3500, -- Intervalo bem lento (3.5 segundos)
        moveStyle = "walk", -- Caminha (Lento)
        health = 150,
        damageMult = 0.6,
        vision = { distance = 30, fov = 100 },
        hearing = { walk = 20, run = 40, gunshot = 100 },
        attackSounds = {"sounds/mgroan1.ogg", "sounds/mgroan2.ogg"}
    },

    -- Zumbi que anda rápido (Walker - Intermediário)
    zombie_walker = {
        id = "zombie_walker",
        baseTeam = "zombie",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        meleeStyle = "punch_slow",
        fightingStyle = 15, -- Estilo Lutador (GRAB_KICK)
        meleeInterval = 3000, -- Intervalo lento (3 segundos)
        moveStyle = "run", -- Corre padrão (Médio)
        health = 180,
        damageMult = 0.5,
        vision = { distance = 35, fov = 110 },
        hearing = { walk = 30, run = 60, gunshot = 150 },
        attackSounds = {"sounds/mgroan5.ogg", "sounds/mgroan6.ogg"}
    },

    -- Zumbi que corre até o alvo (Rynner - Rápido)
    zombie_rynner = {
        id = "zombie_rynner",
        baseTeam = "zombie",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        meleeStyle = "punch_slow",
        fightingStyle = 15, -- Estilo Lutador (GRAB_KICK)
        meleeInterval = 2500, -- Intervalo lento (2.5 segundos)
        moveStyle = "sprint", -- Sprint (Rápido)
        health = 200,
        damageMult = 2,
        vision = { distance = 40, fov = 120 },
        hearing = { walk = 40, run = 80, gunshot = 200 },
        attackSounds = {"sounds/mgroan3.ogg", "sounds/mgroan4.ogg"}
    },

    -- Guarda Público (Policial/Segurança de Zona)
    -- Protege uma área, não segue players fora dela
    guard_pub = {
        id = "guard_pub",
        baseTeam = "bot_guard",
        behavior = "defensive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "ranged",
        useRanged = true,
        canRoll = true,
        prefersCover = true,
        weapon = 31, -- M4
        ammo = 1000,
        moveStyle = "run",
        health = 200,
        damageMult = 0.7,
        vision = { distance = 120, fov = 380 },
        hearing = { walk = 30, run = 60, gunshot = 150 }
    },

    -- Guarda Privado (Bodyguard/Guarda-costas)
    -- Segue e protege um alvo específico (Player ou Ped)
    guard_priv = {
        id = "guard_priv",
        baseTeam = "bot_guard",
        behavior = "defensive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "ranged",
        useRanged = true,
        canRoll = true,
        prefersCover = true,
        weapon = 29, -- MP5
        ammo = 500,
        moveStyle = "run",
        health = 150,
        damageMult = 0.8,
        vision = { distance = 80, fov = 100 },
        hearing = { walk = 25, run = 50, gunshot = 120 }
    },

    -- Zumbi clássico (ataques de soco/mestre)
    zombie = {
        id = "zombie",
        baseTeam = "zombie",
        behavior = "aggressive",
        targetPlayers = true,
        combatStyle = "melee",
        meleeStyle = "punch_slow",
        fightingStyle = 15, -- Estilo Lutador (GRAB_KICK)
        meleeInterval = 3000,
        moveStyle = "walk",
        health = 100,
        damageMult = 0.4,
        vision = { distance = 30, fov = 100 },
        hearing = { walk = 40, run = 80, gunshot = 250 }
    },

    -- NOVO: Zumbi Tóxico (Lento)
    toxic_zombie = {
        id = "toxic_zombie",
        baseTeam = "zombie",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        meleeStyle = "punch_slow",
        fightingStyle = 15, -- Estilo Lutador (GRAB_KICK)
        meleeInterval = 4000, -- Bem lento
        moveStyle = "walk", -- Lento como pedido
        health = 300,       -- Mais resistente
        damageMult = 0.25,   -- Dano de soco baixo
        vision = { distance = 30, fov = 90 },
        hearing = { walk = 20, run = 40, gunshot = 100 }
    },

    -- Mestre de Kung Fu com ataques corpo a corpo avançados
    kungfu_master = {
        id = "kungfu_master",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        fightingStyle = 6, -- KUNG_FU (ID 6)
        moveStyle = "run",
        health = 200,
        damageMult = 0.5,
        vision = { distance = 50, fov = 130 },
        hearing = { walk = 35, run = 70, gunshot = 180 }
    },

    -- Mestre de Karate com combos rápidos
    karate_master = {
        id = "karate_master",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        fightingStyle = 16, -- ELBOWS (ID 16)
        moveStyle = "run",
        health = 180,
        damageMult = 0.4,
        vision = { distance = 45, fov = 125 },
        hearing = { walk = 30, run = 65, gunshot = 160 }
    },

    -- Lutador de rua (Street Fighter)
    streetfighter = {
        id = "streetfighter",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        fightingStyle = 4, -- STANDARD (ID 4)
        moveStyle = "run",
        health = 160,
        damageMult = 0.4,
        vision = { distance = 40, fov = 120 },
        hearing = { walk = 30, run = 60, gunshot = 150 }
    },

    -- Lutador de Kickbox (Kickboxer)
    kickboxer = {
        id = "kickboxer",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        fightingStyle = 15, -- GRAB_KICK (ID 15)
        moveStyle = "run",
        health = 170,
        damageMult = 0.4,
        vision = { distance = 45, fov = 125 },
        hearing = { walk = 30, run = 65, gunshot = 160 }
    },

    -- Boxeador
    boxer = {
        id = "boxer",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        fightingStyle = 5, -- BOXING (ID 5)
        moveStyle = "run",
        health = 190,
        damageMult = 0.5,
        vision = { distance = 40, fov = 120 },
        hearing = { walk = 30, run = 60, gunshot = 150 }
    },

    -- NOVO: Zombie Hunter (Pulo, Pounce e Ataque de Proximidade)
    zombie_hunter = {
        id = "zombie_hunter",
        baseTeam = "zombie",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee", -- Mudado para melee para permitir socos quando perto
        useRanged = false,
        meleeStyle = "punch_slow",
        fightingStyle = 15,     -- Estilo Lutador (GRAB_KICK)
        meleeInterval = 2000,   -- Intervalo lento para socos
        moveStyle = "run",
        health = 150,
        damageMult = 0.6,
        pounceRange = 40.0,     -- Distância máxima do pulo
        pounceCooldown = 8000,  -- Tempo entre pulos
        pounceDamageThreshold = 30, -- Dano para cancelar o pounce
        vision = { distance = 60, fov = 160 },
        hearing = { walk = 50, run = 100, gunshot = 300 }
    },

    -- Lutador de Joelhadas (Muay Thai style)
    muay_thai = {
        id = "muay_thai",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "melee",
        useRanged = false,
        fightingStyle = 7, -- KNEE_HEAD (ID 7)
        moveStyle = "run",
        health = 180,
        damageMult = 0.4,
        vision = { distance = 45, fov = 125 },
        hearing = { walk = 30, run = 65, gunshot = 160 }
    },

    -- Sniper (Fica parado em cover, atira de longe com mira laser)
    sniper = {
        id = "sniper",
        baseTeam = "bot_enemy",
        behavior = "aggressive",
        targetPlayers = true,
        targetBots = true,
        combatStyle = "ranged",
        useRanged = true,
        canRoll = false,      -- Snipers não rolam, mantêm posição
        prefersCover = true, 
        weapon = 34, -- Sniper Rifle
        ammo = 100,
        moveStyle = "walk",
        health = 100,
        damageMult = 1.2,
        vision = { distance = 250, fov = 80 }, -- Visão de longo alcance, mas estreita
        hearing = { walk = 20, run = 40, gunshot = 120 }
    },
}

local DEFAULT_TYPE = "bandit"

function BOTNPC.getBotType(element)
    if not isElement(element) then
        return DEFAULT_TYPE
    end
    return getElementData(element, "bot:type") or DEFAULT_TYPE
end

function BOTNPC.setBotType(element, botType)
    if not isElement(element) then return false end
    botType = botType or DEFAULT_TYPE
    setElementData(element, "bot:type", botType, true)
    return true
end

function BOTNPC.getTypeConfig(botType)
    local cfg = BOTNPC.BOT_TYPES.CONFIG[botType or DEFAULT_TYPE]
    if not cfg then
        -- Se o tipo não existir, retorna o tipo padrão (bandit)
        return BOTNPC.BOT_TYPES.CONFIG[DEFAULT_TYPE]
    end
    return cfg
end

-- Aplica tipo e time padrão de acordo com o arquetipo escolhido
function BOTNPC.applyBotDefaults(bot, botType)
    if not isElement(bot) then return end

    botType = botType or DEFAULT_TYPE
    local cfg = BOTNPC.getTypeConfig(botType)

    BOTNPC.setBotType(bot, botType)

    if cfg and BOTNPC.setElementTeam then
        BOTNPC.setElementTeam(bot, cfg.baseTeam)
    end
end

-- Regra genérica de "este bot deveria atacar este alvo?"
-- Usa tipo + times. Pode ser expandido para medo, fuga, etc.
function BOTNPC.shouldAttack(bot, target)
    if not isElement(bot) or not isElement(target) then
        return false
    end

    -- Não ataca a si mesmo
    if bot == target then
        return false
    end

    if isPedDead(target) then
        return false
    end

    local botType = BOTNPC.getBotType(bot)
    local cfg = BOTNPC.getTypeConfig(botType)

    -- Se não houver config, cair no sistema de times padrão
    if not cfg then
        return BOTNPC.areEnemies and BOTNPC.areEnemies(bot, target) or false
    end

    local targetType = getElementType(target)
    local isPlayer = (targetType == "player")
    local isPed = (targetType == "ped")

    if isPlayer and not cfg.targetPlayers then
        return false
    end

    if isPed and not isPlayer and not cfg.targetBots then
        return false
    end

    -- Comportamentos básicos
    if cfg.behavior == "passive" then
        return false
    end

    if cfg.behavior == "coward" then
        -- No futuro podemos fazer esse tipo fugir. Por enquanto, não ataca.
        return false
    end

    -- Lógica de Proteção: Se estiver protegendo um elemento, ignora ele como inimigo
    local protectTarget = getElementData(bot, "bot:protectTarget")
    if protectTarget == target then
        return false
    end

    -- Regra de Ouro para Guardas Públicos: Só atacam se o alvo for explicitamente inimigo
    -- Eles nunca "suspeitam" de jogadores neutros/aliados, a menos que sejam atacados ou alertados.
    if botType == "guard_pub" then
        local isEnemy = BOTNPC.areEnemies(bot, target)
        
        if not isEnemy then
            -- Se o alvo for um Player
            if getElementType(target) == "player" then
                -- Global: Wanted level (GTA nativo)
                if getElementData(target, "wantedLevel") and getElementData(target, "wantedLevel") > 0 then
                    isEnemy = true
                else
                    -- Local: Sistema de Testemunhas (Queima de arquivo)
                    -- O bot só ataca se ele for uma das testemunhas do crime do player
                    local witnesses = getElementData(target, "bot:witnesses")
                    if witnesses and witnesses[bot] then
                        isEnemy = true
                    end
                end
            -- Se o alvo for um Bot Guard_Priv que protege alguém hostil aos Guardas Públicos
            elseif getElementType(target) == "ped" and getElementData(target, "bot:type") == "guard_priv" then
                local master = getElementData(target, "bot:protectTarget")
                if isElement(master) then
                    if (getElementData(master, "wantedLevel") and getElementData(master, "wantedLevel") > 0) then
                        isEnemy = true
                    else
                        local witnesses = getElementData(master, "bot:witnesses")
                        if witnesses and witnesses[bot] then
                            isEnemy = true
                        end
                    end
                end
            end
        end
        return isEnemy
    end

    -- Lógica de Inimizade para Guardas Privados (Defesa do Mestre)
    if botType == "guard_priv" then
        local master = getElementData(bot, "bot:protectTarget")
        if isElement(master) then
            -- Se o alvo está atacando o mestre, ele vira inimigo instantâneo
            if getElementData(master, "bot:lastAttacker") == target then
                return true
            end
            -- Se o alvo for um Guarda Público hostil ao mestre, o guarda privado ataca ele
            if getElementData(target, "bot:type") == "guard_pub" then
                if (getElementData(master, "wantedLevel") and getElementData(master, "wantedLevel") > 0) then
                    return true
                else
                    local witnesses = getElementData(master, "bot:witnesses")
                    if witnesses and witnesses[target] then
                        return true
                    end
                end
            end
        end
    end

    -- Se o alvo estiver atacando quem o bot protege, ele é um inimigo prioritário
    -- (Isso é tratado também no alertGuards no servidor)

    -- Por padrão, usa o sistema de times para decidir inimigos
    if BOTNPC.areEnemies then
        return BOTNPC.areEnemies(bot, target)
    end

    return false
end

outputDebugString("[BotNPC] Bot types carregado")

