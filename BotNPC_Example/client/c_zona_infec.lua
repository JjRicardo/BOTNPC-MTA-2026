local show = false
local kills = 0
local total = 0
local lastKills = 0
local progressStart = 0
local progressDuration = 500 -- Tempo da animação em ms
local killText = ""

local screenW, screenH = guiGetScreenSize()

-- Cores (Cache para evitar tocolor no render)
local colorBG = tocolor(20, 20, 20, 180)
local colorBarBG = tocolor(40, 40, 40, 200)
local colorBarFill = tocolor(220, 50, 50, 220)
local colorText = tocolor(255, 255, 255, 255)
local colorTitle = tocolor(255, 70, 70, 255)
local colorGlow = tocolor(255, 255, 255, 150)

--=====================================================
-- INTERFACE TUNNEL (CLIENT UI)
--=====================================================

local ZombieUI = {}

function ZombieUI.show(state)
    show = state
    if state then
        progressStart = getTickCount()
        lastKills = kills
        killText = string.format("%d / %d ELIMINADOS", kills, total)
    end
    return true
end

function ZombieUI.update(k, t)
    lastKills = kills
    kills = k
    total = t
    killText = string.format("%d / %d ELIMINADOS", kills, total)
    progressStart = getTickCount()
    return true
end

Tunnel.bind("ZombieUI", ZombieUI)

--=====================================================
-- UI OTIMIZADA (MÁXIMO FPS)
--=====================================================

addEventHandler("onClientRender", root, function()
    if not show or total == 0 then return end

    local now = getTickCount()
    local elapsed = now - progressStart
    local progress = 0
    
    if elapsed < progressDuration then
        local animProgress = elapsed / progressDuration
        local currentKills = interpolateBetween(lastKills, 0, 0, kills, 0, 0, animProgress, "OutQuad")
        progress = currentKills / total
    else
        progress = kills / total
    end

    -- Configurações da UI (Clean Design)
    local w, h = 300, 60
    local x = (screenW - w) / 2
    local y = 40 
    
    -- Fundo principal
    dxDrawRectangle(x, y, w, h, colorBG)
    
    -- Título
    dxDrawText("ZONA INFECTADA", x, y + 5, x + w, y + 25, colorTitle, 1, "default-bold", "center", "top")
    
    -- Texto de kills (Usando cache do killText)
    if kills >= total and total > 0 then
        dxDrawText("ZONA LIMPA!", x, y + 22, x + w, y + 42, tocolor(50, 255, 50, 255), 0.9, "default-bold", "center", "top")
    else
        dxDrawText(killText, x, y + 22, x + w, y + 42, colorText, 0.9, "default-bold", "center", "top")
    end
    
    -- Barra de Progresso
    local barW, barH = w - 40, 8
    local barX, barY = x + 20, y + 42
    
    dxDrawRectangle(barX, barY, barW, barH, colorBarBG)
    dxDrawRectangle(barX, barY, barW * progress, barH, colorBarFill)
    
    -- Brilho na ponta
    if progress > 0 then
        dxDrawRectangle(barX + (barW * progress) - 2, barY, 2, barH, colorGlow)
    end
end)