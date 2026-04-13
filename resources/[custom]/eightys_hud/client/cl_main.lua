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
-- THREAD PRINCIPAL — Mise à jour toutes les 500ms
-- ================================================================
CreateThread(function()
    -- Attendre que le joueur soit chargé
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end

    sendHudVisible(true)

    while true do
        Wait(500)

        local ped       = PlayerPedId()
        local vehicle   = GetVehiclePedIsIn(ped, false)
        local isInVeh   = vehicle ~= 0
        local playerPos = GetEntityCoords(ped)

        -- Santé (GTA : 0-200, 0-100 = mort, 100-200 = vie)
        local rawHealth = GetEntityHealth(ped)
        local health    = math.max(0, math.floor(((rawHealth - 100) / 100) * 100))

        -- Armure
        local armor = math.floor(GetPedArmour(ped))

        -- Vitesse (en MPH)
        local speedMps = 0
        if isInVeh then
            speedMps = GetEntitySpeed(vehicle)
        end
        local speedMph = math.floor(speedMps * 2.237)

        -- Niveau de recherche
        local wanted = GetPlayerWantedLevel(PlayerId())

        -- Argent (via QBCore PlayerData)
        local playerData = QBCore.Functions.GetPlayerData()
        local cash       = 0
        local jobLabel   = "Chômeur"
        if playerData then
            if playerData.money then
                cash = playerData.money["cash"] or 0
            end
            if playerData.job then
                jobLabel = playerData.job.label or "Chômeur"
            end
        end

        -- Rue actuelle
        local streetHash, crossingHash = GetStreetNameAtCoord(playerPos.x, playerPos.y, playerPos.z)
        local streetName    = GetStreetNameFromHashKey(streetHash)
        local crossingName  = GetStreetNameFromHashKey(crossingHash)
        local displayStreet = streetName
        if crossingName and crossingName ~= "" then
            displayStreet = streetName .. " & " .. crossingName
        end

        -- Mort ?
        local dead = IsEntityDead(ped)

        hudData = {
            health  = health,
            armor   = armor,
            speed   = speedMph,
            wanted  = wanted,
            cash    = cash,
            job     = jobLabel,
            street  = displayStreet,
            dead    = dead,
        }

        sendHudUpdate(hudData)
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
