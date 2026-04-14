-- ================================================================
-- eightys_hud — Client
-- HUD rétro néon style Los Angeles 1987
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local hudData = {
    health  = 100,
    armor   = 0,
    cash    = 0,
    wanted  = 0,
    speed   = 0,
    job     = "Chômeur",
    street  = "",
    talking = false,
    dead    = false,
}

local hudVisible = true

-- ================================================================
-- AFFICHAGE DU HUD
-- ================================================================
local function sendHudUpdate(data)
    SendNUIMessage({
        type = "UPDATE_HUD",
        data = data,
    })
end

local function sendHudVisible(visible)
    SendNUIMessage({
        type    = "SET_VISIBLE",
        visible = visible,
    })
end

-- ================================================================
-- THREAD PRINCIPAL — Mise à jour toutes les 500ms avec dirty flag
-- Le NUI n'est contacté que si au moins une valeur a changé
-- ================================================================
local lastSent = {}  -- copie des dernières valeurs envoyées

local function hudDirty(new)
    for k, v in pairs(new) do
        if lastSent[k] ~= v then return true end
    end
    return false
end

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end

    sendHudVisible(true)

    while true do
        Wait(500)

        local ped       = PlayerPedId()
        local vehicle   = GetVehiclePedIsIn(ped, false)
        local playerPos = GetEntityCoords(ped)

        -- Santé (GTA : 100 = 0%, 200 = 100%)
        local health = math.max(0, math.floor(((GetEntityHealth(ped) - 100) / 100) * 100))
        local armor  = math.floor(GetPedArmour(ped))

        -- Vitesse MPH (0 hors véhicule)
        local speedMph = vehicle ~= 0
            and math.floor(GetEntitySpeed(vehicle) * 2.237)
            or 0

        -- Wanted level
        local wanted = GetPlayerWantedLevel(PlayerId())

        -- Cash & job (depuis PlayerData en mémoire — pas de réseau)
        local playerData = QBCore.Functions.GetPlayerData()
        local cash     = 0
        local jobLabel = "Chômeur"
        if playerData then
            cash     = (playerData.money and playerData.money["cash"]) or 0
            jobLabel = (playerData.job   and playerData.job.label)     or "Chômeur"
        end

        -- Rue (lookup uniquement si position a changé de plus de 10m)
        local street = lastSent.street or ""
        if not lastSent._pos
            or #(playerPos - lastSent._pos) > 10.0 then
            local sh, ch = GetStreetNameAtCoord(playerPos.x, playerPos.y, playerPos.z)
            local sn     = GetStreetNameFromHashKey(sh)
            local cn     = GetStreetNameFromHashKey(ch)
            street = (cn and cn ~= "") and (sn .. " & " .. cn) or sn
            lastSent._pos = playerPos
        end

        local dead = IsEntityDead(ped)

        local newData = {
            health = health,
            armor  = armor,
            speed  = speedMph,
            wanted = wanted,
            cash   = cash,
            job    = jobLabel,
            street = street,
            dead   = dead,
        }

        -- N'envoyer au NUI que si au moins un champ a changé
        if hudDirty(newData) then
            hudData = newData
            for k, v in pairs(newData) do lastSent[k] = v end
            sendHudUpdate(hudData)
        end
    end
end)

-- ================================================================
-- EVENTS QBCore — Mise à jour instantanée
-- ================================================================
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)  -- Laisser le temps au spawn
    sendHudVisible(true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    sendHudVisible(false)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if hudData then
        hudData.job = JobInfo.label or "Chômeur"
        sendHudUpdate(hudData)
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if val and val.money then
        if hudData then
            hudData.cash = val.money["cash"] or 0
            sendHudUpdate(hudData)
        end
    end
end)

-- ================================================================
-- TOUCHE : Afficher/masquer le HUD
-- ================================================================
RegisterCommand('hud', function()
    hudVisible = not hudVisible
    sendHudVisible(hudVisible)
    if hudVisible then
        lib.notify({ title = "HUD", description = "HUD affiché", type = "success" })
    else
        lib.notify({ title = "HUD", description = "HUD masqué", type = "inform" })
    end
end, false)

-- ================================================================
-- NUI CALLBACKS
-- ================================================================
RegisterNUICallback('hudReady', function(_, cb)
    -- Le NUI est prêt, on envoie la config
    SendNUIMessage({
        type   = "SET_CONFIG",
        config = Config.HUD,
    })
    sendHudUpdate(hudData)
    cb('ok')
end)
