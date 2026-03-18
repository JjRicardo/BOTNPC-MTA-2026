-- client/node_editor.lua
-- Sistema de edição de nodes visual DX

local nodeEditor = {}
nodeEditor.enabled = false
nodeEditor.selectedNode = nil
nodeEditor.screenW, nodeEditor.screenH = guiGetScreenSize()

function nodeEditor.toggle()
    if not getElementData(localPlayer, "botnpc:isAdmin") then
        outputChatBox("[BotNPC] Você não tem permissão para usar o Node Editor.", 255, 0, 0)
        return
    end
    
    nodeEditor.enabled = not nodeEditor.enabled
    if nodeEditor.enabled then
        addEventHandler("onClientRender", root, nodeEditor.render)
        showCursor(false)
        outputChatBox("[NodeEditor] Ativado.", 0, 255, 0)
        outputChatBox("Comandos: /addnode, /delnode [id], /linknode [id1] [id2], /resetlink, /savenodes", 200, 200, 255)
    else
        removeEventHandler("onClientRender", root, nodeEditor.render)
        showCursor(false)
        outputChatBox("[NodeEditor] Desativado.", 255, 0, 0)
    end
end
addCommandHandler("editnodes", nodeEditor.toggle)

function nodeEditor.render()
    if not nodeEditor.enabled then return end
    
    local px, py, pz = getElementPosition(localPlayer)
    local nodes = getElementsByType("pathpoint")
    
    -- UI de Ajuda no topo
    dxDrawRectangle(nodeEditor.screenW/2 - 150, 10, 300, 60, tocolor(0, 0, 0, 150))
    dxDrawText("NODE EDITOR ATIVO", 0, 15, nodeEditor.screenW, 30, tocolor(255, 255, 0, 255), 1.2, "default-bold", "center")
    dxDrawText("/addnode - Criar | /savenodes - Salvar", 0, 35, nodeEditor.screenW, 50, tocolor(255, 255, 255, 200), 1, "default", "center")

    for _, node in ipairs(nodes) do
        local nx, ny, nz = getElementPosition(node)
        local dist = getDistanceBetweenPoints3D(px, py, pz, nx, ny, nz)
        
        if dist < 40 then
            local sx, sy = getScreenFromWorldPosition(nx, ny, nz)
            if sx then
                local id = getElementID(node) or "N/A"
                local color = tocolor(0, 255, 0, 200)
                
                -- Desenha o node
                dxDrawCircle(sx, sy, 6, color)
                dxDrawText(id, sx + 10, sy - 5, sx + 10, sy - 5, tocolor(255, 255, 255, 200), 1, "default-bold")
                
                -- Desenha conexões
                local connections = getElementData(node, "connections") or {}
                for targetId in pairs(connections) do
                    local target = getElementByID(tostring(targetId))
                    if isElement(target) then
                        local tx, ty, tz = getElementPosition(target)
                        local sx2, sy2 = getScreenFromWorldPosition(tx, ty, tz)
                        if sx2 then
                            dxDrawLine(sx, sy, sx2, sy2, tocolor(0, 255, 0, 50), 2)
                        end
                    end
                end
            end
        end
    end
end

function nodeEditor.addNode()
    if not nodeEditor.enabled then return end
    local x, y, z = getElementPosition(localPlayer)
    triggerServerEvent("onNodeEditorAdd", localPlayer, x, y, z - 0.95)
end
addCommandHandler("addnode", nodeEditor.addNode)

function nodeEditor.delNode(cmd, id)
    if not nodeEditor.enabled then return end
    if not id then return outputChatBox("Uso: /delnode [id]", 255, 0, 0) end
    triggerServerEvent("onNodeEditorDel", localPlayer, id)
end
addCommandHandler("delnode", nodeEditor.delNode)

function nodeEditor.resetLink()
    if not nodeEditor.enabled then return end
    triggerServerEvent("onNodeEditorReset", localPlayer)
end
addCommandHandler("resetlink", nodeEditor.resetLink)

function nodeEditor.linkNodes(cmd, id1, id2)
    if not nodeEditor.enabled then return end
    if not id1 or not id2 then
        outputChatBox("Uso: /linknode [id1] [id2]", 255, 0, 0)
        return
    end
    triggerServerEvent("onNodeEditorLink", localPlayer, id1, id2)
end
addCommandHandler("linknode", nodeEditor.linkNodes)

function nodeEditor.saveNodes()
    if not nodeEditor.enabled then return end
    triggerServerEvent("onNodeEditorSave", localPlayer)
end
addCommandHandler("savenodes", nodeEditor.saveNodes)

outputDebugString("[BotNPC] Node Editor DX carregado")
