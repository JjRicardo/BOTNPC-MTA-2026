-- shared/constants.lua
-- Configurações globais do sistema

BOTNPC = BOTNPC or {}

BOTNPC.CONSTANTS = {
    -- Performance
    MAX_BOTS = 200,
    TICK_INTERVAL = 250,
    DEATH_DELAY = 10000, -- 10 segundos antes de sumir o corpo
    BOTS_PER_TICK = 15,
    STUCK_TIME = 3000,
    
    -- Stream
    STREAM_DISTANCE = 300,
    UNSTREAM_DISTANCE = 350,
    
    -- Estados da IA
    STATES = {
        IDLE = "idle",
        PATROL = "patrol",
        INVESTIGATE = "investigate",
        COMBAT = "combat",
        FOLLOW = "follow",
        GUARD = "guard"
    },

    -- Liga/desliga comportamentos base por estado
    -- Pode ser sobrescrito por bot via elementData "bot:ai:states" (tabela).
    STATE_ENABLED = {
        idle = true,
        patrol = true,
        investigate = true,
        combat = true,
        follow = true,
        guard = true
    },
    
    -- Visão
    VISION = {
        distance = 60,
        fov = 100,
        memoryTime = 5000
    },
    
    -- Audição
    HEARING = {
        walk = 20,
        run = 40,
        gunshot = 120,
        explosion = 200
    },
    
    -- Combate
    COMBAT = {
        ACCURACY_GLOBAL_MULT = 0.6, -- Redução de 40% na precisão geral dos bots
        ACCURACY_BASE = 0.5,
        ACCURACY_MOVEMENT_PENALTY = 0.35,
        REACTION_TIME = 300,
        
        -- Multiplicadores globais de dano
        PED_TO_PLAYER_MULT = 1.0,  -- Dano que o Bot dá no Player
        PLAYER_TO_PED_MULT = 1.0,  -- Dano que o Player dá no Bot
        PLAYER_TO_PLAYER_MULT = 1.0 -- Dano que o Player dá em outro Player (PvP)
    },
    
    -- Pathfinding
    PATHFINDING = {
        NODE_RADIUS = 15,
        MAX_NODE_DISTANCE = 50,
        JUMP_CHANCE = 0.3,
        GRID_SIZE = 50
    },
    
    -- Cores para debug
    DEBUG_COLORS = {
        idle = tocolor(150, 150, 150, 255),
        patrol = tocolor(0, 255, 255, 255),
        combat = tocolor(255, 0, 0, 255),
        investigate = tocolor(255, 255, 0, 255),
        follow = tocolor(0, 0, 255, 255),
        guard = tocolor(128, 0, 128, 255)
    },
    
    -- Configurações de Dano (Facinho de editar)
    DAMAGE_SYSTEM = {
        -- Dano Melee (Socos/Chutes) que QUALQUER Ped dá no Player
        PED_MELEE_DAMAGE = 10.0,
        
        -- Multiplicadores por Osso (Cabeça, Tronco, etc)
        -- 9: Cabeça, 3: Tronco, 4: Pelvis, 5: Braço Esq, 6: Braço Dir, 7: Perna Esq, 8: Perna Dir
        BONE_MULTIPLIERS = {
            [9] = 10, -- Cabeça (Dano Crítico reduzido de 2.5)
            [3] = 1.0, -- Tronco (Dano Base)
            [4] = 0.8, -- Pelvis
            [5] = 0.6, -- Braço
            [6] = 0.6, -- Braço
            [7] = 0.6, -- Perna
            [8] = 0.6, -- Perna
        },

        -- Dano de Armas: Ped vs Player (Dano Fixo por Bala/Explosão)
        PED_VS_PLAYER = {
            [0] = 6,  -- Soco
            [4] = 12,  -- Knife
            [8] = 18,  -- Katana
            [9] = 24,  -- Chainsaw
            [16] = 60, -- Granada
            [18] = 30, -- Molotov (Dano inicial)
            [22] = 9, -- Colt 45
            [23] = 9, -- Silenced
            [24] = 20, -- Deagle
            [25] = 6, -- Shotgun (por pellet)
            [26] = 9, -- Sawnoff
            [27] = 9, -- Combat Shotgun
            [28] = 7, -- Uzi
            [29] = 8, -- MP5
            [32] = 7, -- Tec9
            [30] = 12, -- AK-47
            [31] = 11, -- M4
            [33] = 18, -- Country Rifle
            [34] = 60, -- Sniper
            [35] = 80, -- RPG
            [36] = 80, -- HS Rocket
            [37] = 15, -- Flamethrower
            [38] = 30, -- Minigun
            [39] = 80, -- Satchel
            [51] = 80, -- Explosão de Veículo
        },

        -- Dano de Armas: Player vs Player (Dano Fixo por Bala/Explosão)
        PLAYER_VS_PLAYER = {
            [0] = 15,  -- Soco
            [4] = 25,  -- Knife
            [8] = 45,  -- Katana
            [9] = 60,  -- Chainsaw
            [16] = 90, -- Granada
            [18] = 50, -- Molotov
            [22] = 20, -- Colt 45
            [23] = 20, -- Silenced
            [24] = 45, -- Deagle
            [25] = 15, -- Shotgun
            [26] = 20, -- Sawnoff
            [27] = 25, -- Combat Shotgun
            [28] = 15, -- Uzi
            [29] = 18, -- MP5
            [32] = 15, -- Tec9
            [30] = 25, -- AK-47
            [31] = 22, -- M4
            [33] = 40, -- Country Rifle
            [34] = 100, -- Sniper
            [35] = 150, -- RPG
            [36] = 150, -- HS Rocket
            [37] = 25, -- Flamethrower
            [38] = 60, -- Minigun
            [39] = 150, -- Satchel
            [51] = 120, -- Explosão de Veículo
        },

        -- Dano de Armas: Player vs Bot (Dano Fixo por Bala/Explosão)
        PLAYER_VS_BOT = {
            [0] = 15,  -- Soco
            [1] = 20,  -- Soco Inglês
            [2] = 25,  -- Golf Club
            [3] = 25,  -- Nightstick
            [4] = 30,  -- Knife
            [5] = 30,  -- Baseball Bat
            [6] = 30,  -- Shovel
            [7] = 30,  -- Pool Cue
            [8] = 40,  -- Katana
            [9] = 50,  -- Chainsaw
            [16] = 200, -- Granada (Zumbis morrem na hora quase sempre)
            [18] = 100, -- Molotov
            [22] = 25, -- Colt 45
            [23] = 25, -- Silenced
            [24] = 50, -- Deagle
            [25] = 20, -- Shotgun
            [26] = 30, -- Sawnoff
            [27] = 35, -- Combat Shotgun
            [28] = 20, -- Uzi
            [29] = 22, -- MP5
            [32] = 20, -- Tec9
            [30] = 30, -- AK-47
            [31] = 30, -- M4
            [33] = 50, -- Country Rifle
            [34] = 150, -- Sniper
            [35] = 300, -- RPG
            [36] = 300, -- HS Rocket
            [37] = 40, -- Flamethrower
            [38] = 80, -- Minigun
            [39] = 300, -- Satchel
            [51] = 250, -- Explosão de Veículo
        },
    },
    
    -- Debug
    DEBUG = {
        ENABLED = false,
        DRAW_STATES = true,
        DRAW_PATHS = true,
        DRAW_VISION = true
    }
}

outputDebugString("[BotNPC] Constantes carregadas")