-- shared/weapons_data.lua
-- Dados de armas

BOTNPC = BOTNPC or {}
BOTNPC.WEAPONS = BOTNPC.WEAPONS or {}

BOTNPC.WEAPONS.DATA = {
    -- Corpo a corpo (padrão)
    melee = {
        id = 0,
        name = "Melee",
        damage = 10,
        range = 2,
        cooldown = 800,
        type = "melee"
    },
    
    -- Pistolas
    [22] = { -- Colt 45
        id = 22,
        name = "Colt 45",
        damage = 18,
        range = 35,
        accuracy = 0.8,
        fireRate = 300,
        type = "pistol"
    },
    [23] = { -- Silenced
        id = 23,
        name = "Silenced",
        damage = 18,
        range = 35,
        accuracy = 0.85,
        fireRate = 300,
        type = "pistol"
    },
    [24] = { -- Deagle
        id = 24,
        name = "Desert Eagle",
        damage = 30,
        range = 40,
        accuracy = 0.75,
        fireRate = 400,
        type = "pistol"
    },
    
    -- Submetralhadoras
    [28] = { -- Uzi
        id = 28,
        name = "UZI",
        damage = 12,
        range = 40,
        accuracy = 0.6,
        fireRate = 100,
        type = "smg"
    },
    [32] = { -- Tec9
        id = 32,
        name = "Tec9",
        damage = 12,
        range = 40,
        accuracy = 0.6,
        fireRate = 100,
        type = "smg"
    },
    [29] = { -- MP5
        id = 29,
        name = "MP5",
        damage = 14,
        range = 55,
        accuracy = 0.7,
        fireRate = 100,
        type = "smg"
    },
    
    -- Shotguns
    [25] = { -- Shotgun
        id = 25,
        name = "Shotgun",
        damage = 10,
        range = 35,
        accuracy = 0.4,
        fireRate = 800,
        type = "shotgun"
    },
    [26] = { -- Sawnoff
        id = 26,
        name = "Sawnoff",
        damage = 10,
        range = 25,
        accuracy = 0.4,
        fireRate = 800,
        type = "shotgun"
    },
    [27] = { -- SPAS-12
        id = 27,
        name = "SPAS-12",
        damage = 14,
        range = 40,
        accuracy = 0.5,
        fireRate = 600,
        type = "shotgun"
    },
    
    -- Rifles
    [30] = { -- AK-47
        id = 30,
        name = "AK-47",
        damage = 22,
        range = 70,
        accuracy = 0.65,
        fireRate = 120,
        type = "rifle"
    },
    [31] = { -- M4
        id = 31,
        name = "M4",
        damage = 20,
        range = 80,
        accuracy = 0.8,
        fireRate = 100,
        type = "rifle"
    },
    [33] = { -- Country Rifle
        id = 33,
        name = "Country Rifle",
        damage = 30,
        range = 90,
        accuracy = 0.9,
        fireRate = 800,
        type = "rifle"
    },
    
    -- Snipers
    [34] = { -- Sniper
        id = 34,
        name = "Sniper",
        damage = 65,
        range = 250,
        accuracy = 1.0,
        fireRate = 1200,
        type = "sniper"
    },

    -- Heavy Weapons
    [38] = { -- Minigun
        id = 38,
        name = "Minigun",
        damage = 35,
        range = 100,
        accuracy = 0.9,
        fireRate = 50,
        type = "heavy"
    }
}

function getWeaponData(weaponId)
    local data = BOTNPC.WEAPONS.DATA[weaponId]
    if not data then
        -- Default genérico para armas de fogo não listadas
        if weaponId >= 22 and weaponId <= 34 or weaponId == 38 then
            return {
                id = weaponId,
                name = "Generic Gun",
                damage = 14,
                range = 50,
                accuracy = 0.6,
                fireRate = 200,
                type = "gun"
            }
        end
        return BOTNPC.WEAPONS.DATA.melee
    end
    return data
end

outputDebugString("[BotNPC] Dados de armas carregados")