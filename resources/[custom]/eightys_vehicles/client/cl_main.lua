-- ================================================================
-- eightys_vehicles — Client
-- Restriction aux véhicules des années 80
-- Low-riders, muscle cars, hydrauliques
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Table de lookup rapide pour les véhicules autorisés
local allowedVehicles = {}
local bannedVehicles  = {}

-- ================================================================
-- INITIALISATION DES LISTES
-- ================================================================
CreateThread(function()
    for _, v in ipairs(Config.AllowedVehicles) do
        allowedVehicles[v:lower()] = true
    end
    for _, v in ipairs(Config.BannedVehicles) do
        bannedVehicles[v:lower()] = true
    end
end)

-- ================================================================
-- VÉRIFICATION DU VÉHICULE ACTUEL
-- ================================================================
local lastVehicle    = 0
local warnedVehicle  = 0
local checkInterval  = 5000   -- ms

local function getVehicleModel(vehicle)
    return GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
end

local function isVehicleAllowed(vehicle)
    local model = getVehicleModel(vehicle)
    -- Véhicule dans la liste blanche → OK
    if allowedVehicles[model] then return true end
    -- Véhicule dans la liste noire → interdit
    if bannedVehicles[model] then return false end
    -- Inconnu → autorisé par défaut (pour les mods customs)
    return true
end

CreateThread(function()
    while true do
        Wait(checkInterval)

        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and vehicle ~= lastVehicle then
            lastVehicle = vehicle

            if not isVehicleAllowed(vehicle) then
                local model = getVehicleModel(vehicle)

                if warnedVehicle ~= vehicle then
                    warnedVehicle = vehicle

                    lib.notify({
                        title       = "⚠ Véhicule non période",
                        description = string.format("Le '%s' n'existait pas en 1987. Ce véhicule sera signalé.", model),
                        type        = "error",
                        duration    = 8000,
                    })

                    -- Signaler au serveur
                    TriggerServerEvent('eightys_vehicles:server:reportBannedVehicle', model)
                end
            end
        elseif vehicle == 0 then
            lastVehicle   = 0
            warnedVehicle = 0
        end
    end
end)

-- ================================================================
-- HYDRAULIQUES — LOW-RIDERS (commandes)
-- ================================================================
-- Les low-riders de LA années 80 avaient des hydrauliques

local hydraulicsEnabled = false
local hydVehicles = {
    "voodoo", "tornado", "buccaneer", "chino",
}

local function isLowRider(vehicle)
    local model = getVehicleModel(vehicle)
    for _, v in ipairs(hydVehicles) do
        if model == v then return true end
    end
    return false
end

-- Activer/désactiver les hydrauliques
RegisterCommand('hydro', function()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        lib.notify({ title = "Hydrauliques", description = "Vous n'êtes pas dans un véhicule.", type = "error" })
        return
    end

    if not isLowRider(vehicle) then
        lib.notify({ title = "Hydrauliques", description = "Ce véhicule n'a pas d'hydrauliques.", type = "error" })
        return
    end

    hydraulicsEnabled = not hydraulicsEnabled

    if hydraulicsEnabled then
        -- Activer l'animation hydraulique (suspension basse)
        SetVehicleHandling(vehicle, "fSuspensionForce", 0.5)
        SetVehicleHandling(vehicle, "fSuspensionCompDamp", 0.1)
        lib.notify({ title = "Hydrauliques ON", description = "Les ressorts sont activés.", type = "success" })
    else
        -- Remettre la suspension normale
        SetVehicleHandling(vehicle, "fSuspensionForce", 1.0)
        SetVehicleHandling(vehicle, "fSuspensionCompDamp", 1.0)
        lib.notify({ title = "Hydrauliques OFF", description = "Suspension normale.", type = "inform" })
    end
end, false)

RegisterKeyMapping('hydro', 'Activer/désactiver les hydrauliques du low-rider', 'keyboard', 'H')

-- Contrôle hydrauliques (monter/descendre)
CreateThread(function()
    while true do
        Wait(0)

        if not hydraulicsEnabled then goto continue end

        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle == 0 or not isLowRider(vehicle) then
            hydraulicsEnabled = false
            goto continue
        end

        -- Q = avant haut, E = arrière haut, SPACE = tout haut
        if IsControlPressed(0, 44) then  -- Q
            SetVehicleHandling(vehicle, "fSuspensionRaise", 0.3)
        elseif IsControlPressed(0, 38) then  -- E
            SetVehicleHandling(vehicle, "fSuspensionRaise", -0.3)
        else
            SetVehicleHandling(vehicle, "fSuspensionRaise", 0.0)
        end

        ::continue::
    end
end)

-- ================================================================
-- AFFICHAGE DES INFOS VÉHICULE (overlay)
-- ================================================================
local vehicleInfoVisible = false

RegisterCommand('vehinfo', function()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        lib.notify({ title = "Info véhicule", description = "Vous n'êtes pas dans un véhicule.", type = "inform" })
        return
    end

    local model    = getVehicleModel(vehicle)
    local speed    = math.floor(GetEntitySpeed(vehicle) * 2.237)
    local health   = math.floor((GetVehicleEngineHealth(vehicle) / 1000) * 100)
    local plate    = GetVehicleNumberPlateText(vehicle)
    local allowed  = isVehicleAllowed(vehicle)

    lib.alertDialog({
        header  = "Infos Véhicule",
        content = string.format(
            "Modèle : **%s**\nVitesse : **%d MPH**\nMoteur : **%d%%**\nPlaque : **%s**\nÉpoque : **%s**",
            model:upper(), speed, health, plate,
            allowed and "✓ Années 80" or "✗ Hors période"
        ),
        centered = true,
    })
end, false)

-- ================================================================
-- STYLE RADIO EN VOITURE (station 80s par défaut)
-- ================================================================
AddEventHandler('eightys_vehicles:client:enterVehicle', function(vehicle)
    -- Mettre une station radio des années 80 par défaut
    -- Radio Mirror Park = musique synth/80s dans GTA V
    local radioStation = "RADIO_01_CLASS_ROCK"  -- Classic Rock
    SetVehRadioStation(vehicle, radioStation)
end)

-- Détecter l'entrée dans un véhicule
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and veh ~= lastVeh then
            TriggerEvent('eightys_vehicles:client:enterVehicle', veh)
        end
        lastVeh = veh
    end
end)
