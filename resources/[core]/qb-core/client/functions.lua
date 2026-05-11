-- ================================================================
-- QBCore — client/functions.lua
-- QBCore.Functions.* (client)
-- ================================================================

QBCore.Functions = QBCore.Functions or {}

local PlayerData = {}
local IsLoggedIn = false

-- ================================================================
-- DONNÉES JOUEUR
-- ================================================================
function QBCore.Functions.GetPlayerData()
    return PlayerData
end

function QBCore.Functions.SetPlayerData(key, val)
    PlayerData[key] = val
end

-- ================================================================
-- CALLBACKS
-- ================================================================
local Callbacks = {}
local RequestIds = {}
local RequestCounter = 0

function QBCore.Functions.TriggerCallback(name, cb, ...)
    RequestCounter = RequestCounter + 1
    local requestId = RequestCounter
    RequestIds[requestId] = cb
    TriggerServerEvent('QBCore:Server:TriggerCallback', name, requestId, ...)
end

RegisterNetEvent('QBCore:Client:TriggerCallback', function(requestId, ...)
    if RequestIds[requestId] then
        RequestIds[requestId](...)
        RequestIds[requestId] = nil
    end
end)

-- ================================================================
-- NOTIFICATION
-- ================================================================
function QBCore.Functions.Notify(text, notifyType, length)
    lib.notify({
        title       = notifyType == 'error' and 'Erreur' or notifyType == 'success' and 'Succès' or 'Info',
        description = text,
        type        = notifyType or 'inform',
        duration    = length or 5000,
    })
end

-- ================================================================
-- UTILITAIRES
-- ================================================================
function QBCore.Functions.HasItem(itemName)
    if not PlayerData.items then return false end
    for _, item in ipairs(PlayerData.items) do
        if item.name == itemName then return item end
    end
    return false
end

function QBCore.Functions.GetJob()
    return PlayerData.job
end

function QBCore.Functions.GetGang()
    return PlayerData.gang
end

-- ================================================================
-- DRAW TEXT 3D (utilitaire commun)
-- ================================================================
function QBCore.Functions.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 220, 50, 215)
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = string.len(text) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- ================================================================
-- PROGRESS BAR
-- ================================================================
function QBCore.Functions.Progressbar(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, cb)
    lib.progressBar({
        duration    = duration,
        label       = label,
        useWhileDead = useWhileDead,
        canCancel   = canCancel,
        disable     = disableControls or {},
        anim        = animation,
    }, cb)
end
