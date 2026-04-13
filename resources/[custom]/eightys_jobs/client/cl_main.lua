-- ================================================================
-- eightys_jobs — Client
-- Emplois civils : taxi, mécano, camionneur, pêcheur
-- Los Angeles 1987
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local currentJob     = nil
local isOnDuty       = false
local activeDelivery = nil     -- Livraison en cours { destination, reward }
local jobBlips       = {}

-- ================================================================
-- INIT
-- ================================================================
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.job then
        currentJob = playerData.job.name
        isOnDuty   = playerData.job.onduty
    end
    createJobBlips()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    currentJob = JobInfo.name
    isOnDuty   = JobInfo.onduty
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if val and val.job then
        currentJob = val.job.name
        isOnDuty   = val.job.onduty
    end
end)

-- ================================================================
-- BLIPS DES EMPLOIS
-- ================================================================
local function createJobBlips()
    for _, blip in ipairs(jobBlips) do RemoveBlip(blip) end
    jobBlips = {}

    for jobName, job in pairs(Config.Jobs) do
        if job.location then
            local blip = AddBlipForCoord(job.location.x, job.location.y, job.location.z)
            SetBlipSprite(blip,  job.blip.sprite)
            SetBlipScale(blip,   job.blip.scale)
            SetBlipColour(blip,  job.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(job.label)
            EndTextCommandSetBlipName(blip)
            table.insert(jobBlips, blip)
        end
    end
end

-- ================================================================
-- TEXTE 3D
-- ================================================================
local function drawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 220, 50, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = string.len(text) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- ================================================================
-- MENU EMPLOI (point de travail)
-- ================================================================
local function openJobMenu(jobName, job)
    local options = {}

    if not isOnDuty then
        table.insert(options, {
            title       = "Prendre mon service",
            icon        = "briefcase",
            description = "Commencer à travailler",
            onSelect    = function()
                TriggerServerEvent('eightys_jobs:server:setDuty', jobName, true)
                lib.notify({ title = job.label, description = "Service commencé !", type = "success" })
            end,
        })
    else
        table.insert(options, {
            title       = "Quitter le service",
            icon        = "door-open",
            description = "Terminer votre journée",
            onSelect    = function()
                TriggerServerEvent('eightys_jobs:server:setDuty', jobName, false)
                lib.notify({ title = job.label, description = "Service terminé. Bonne journée !", type = "inform" })
            end,
        })
    end

    -- Missions spécifiques selon le job
    if jobName == "taxi" and isOnDuty then
        table.insert(options, {
            title       = "Chercher un client",
            icon        = "car",
            description = "Aller chercher un passager généré",
            onSelect    = function()
                startTaxiMission()
            end,
        })
    end

    if jobName == "trucker" and isOnDuty then
        table.insert(options, {
            title       = "Prendre une livraison",
            icon        = "truck",
            description = "Récupérer une mission de livraison",
            onSelect    = function()
                TriggerServerEvent('eightys_jobs:server:startDelivery')
            end,
        })
    end

    if jobName == "fisher" and isOnDuty then
        table.insert(options, {
            title       = "Aller pêcher",
            icon        = "fish",
            description = "Se rendre sur un spot de pêche",
            onSelect    = function()
                startFishingMission()
            end,
        })
    end

    if jobName == "mechanic" and isOnDuty then
        table.insert(options, {
            title       = "Réparer un véhicule",
            icon        = "wrench",
            description = "Réparer le véhicule le plus proche",
            onSelect    = function()
                startRepairMission()
            end,
        })
    end

    -- Voir son salaire
    table.insert(options, {
        title       = "Voir mon grade & salaire",
        icon        = "dollar-sign",
        description = "Informations sur votre emploi",
        onSelect    = function()
            TriggerServerEvent('eightys_jobs:server:getJobInfo', jobName)
        end,
    })

    lib.registerContext({
        id      = "job_menu_" .. jobName,
        title   = job.label .. (isOnDuty and " — En service" or " — Hors service"),
        options = options,
    })
    lib.showContext("job_menu_" .. jobName)
end

-- ================================================================
-- MISSION TAXI
-- ================================================================
local taxiActive      = false
local taxiDestBlip    = nil
local taxiPickupBlip  = nil

local taxiDestinations = {
    { label = "Aéroport", coords = vector3(-1034.7, -2733.8, 20.2) },
    { label = "LAPD HQ",  coords = vector3(441.9,   -982.2,  30.7) },
    { label = "Vinewood", coords = vector3(-692.8,   572.3,  120.9) },
    { label = "Port",     coords = vector3(1097.7,  -3175.0, 5.9)  },
    { label = "Mall",     coords = vector3(31.1,    -712.5,  44.5) },
}

local function startTaxiMission()
    if taxiActive then
        lib.notify({ title = "Taxi", description = "Vous avez déjà un passager.", type = "error" })
        return
    end

    -- Destination aléatoire
    local dest = taxiDestinations[math.random(#taxiDestinations)]
    taxiActive = true

    -- Blip de ramassage (position actuelle du taxi)
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    taxiPickupBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(taxiPickupBlip, 1)
    SetBlipColour(taxiPickupBlip, 66)
    SetBlipRoute(taxiPickupBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Passager à prendre")
    EndTextCommandSetBlipName(taxiPickupBlip)

    -- Simuler que le passager monte après 30 secondes
    lib.notify({
        title       = "Taxi",
        description = string.format("Passager monté ! Destination : %s", dest.label),
        type        = "inform",
        duration    = 5000,
    })

    -- Blip de destination
    if taxiPickupBlip then RemoveBlip(taxiPickupBlip) end
    taxiDestBlip = AddBlipForCoord(dest.coords.x, dest.coords.y, dest.coords.z)
    SetBlipSprite(taxiDestBlip, 38)
    SetBlipColour(taxiDestBlip, 5)
    SetBlipRoute(taxiDestBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Déposer le passager — " .. dest.label)
    EndTextCommandSetBlipName(taxiDestBlip)

    -- Attendre l'arrivée à destination
    CreateThread(function()
        local arrived = false
        while not arrived and taxiActive do
            Wait(1000)
            local ped2   = PlayerPedId()
            local pos    = GetEntityCoords(ped2)
            local dist   = #(pos - dest.coords)

            if dist < 15.0 then
                arrived    = true
                taxiActive = false
                RemoveBlip(taxiDestBlip)

                -- Paiement (entre 30 et 80$)
                local reward = math.random(30, 80)
                TriggerServerEvent('eightys_jobs:server:payJobReward', "taxi", reward, "course-taxi")

                lib.notify({
                    title       = "Course terminée !",
                    description = string.format("Passager déposé à %s. Gain : $%d", dest.label, reward),
                    type        = "success",
                    duration    = 5000,
                })
            end
        end
    end)
end

-- ================================================================
-- MISSION PÊCHE
-- ================================================================
local fishingSpots = {
    vector3(-706.5, -1476.9, 1.9),
    vector3(-1073.9, -2746.0, 3.0),
    vector3(748.9,  -1383.0, 3.0),
}

local function startFishingMission()
    local spot = fishingSpots[math.random(#fishingSpots)]

    -- Blip
    local fishBlip = AddBlipForCoord(spot.x, spot.y, spot.z)
    SetBlipSprite(fishBlip, 68)
    SetBlipColour(fishBlip, 3)
    SetBlipRoute(fishBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Spot de pêche")
    EndTextCommandSetBlipName(fishBlip)

    lib.notify({
        title       = "Pêche",
        description = "Rejoignez le spot de pêche indiqué sur la carte.",
        type        = "inform",
    })

    -- Attendre l'arrivée
    CreateThread(function()
        while true do
            Wait(1000)
            local ped  = PlayerPedId()
            local pos  = GetEntityCoords(ped)
            local dist = #(pos - spot)

            if dist < 10.0 then
                RemoveBlip(fishBlip)
                -- Interaction de pêche
                lib.progressBar({
                    duration      = math.random(8000, 20000),
                    label         = "Pêche en cours...",
                    useWhileDead  = false,
                    canCancel     = true,
                    disable       = { car = true, combat = true, move = true },
                    anim = {
                        dict = "amb@world_human_stand_fishing@idle_a",
                        clip = "idle_a",
                    },
                }, function(cancelled)
                    if not cancelled then
                        local fishCount = math.random(1, 5)
                        local reward    = fishCount * math.random(10, 25)
                        TriggerServerEvent('eightys_jobs:server:payJobReward', "fisher", reward, "vente-poissons")
                        TriggerServerEvent('eightys_jobs:server:addFishToInventory', fishCount)
                        lib.notify({
                            title       = "Pêche réussie !",
                            description = string.format("Vous avez pêché %d poisson(s). Gain : $%d", fishCount, reward),
                            type        = "success",
                        })
                    end
                end)
                break
            end
        end
    end)
end

-- ================================================================
-- MISSION MÉCANO
-- ================================================================
local function startRepairMission()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Chercher le véhicule cassé le plus proche
    local nearestVeh = nil
    local minDist    = 20.0

    local vehs = GetGamePool("CVehicle")
    for _, veh in ipairs(vehs) do
        if GetPedInVehicleSeat(veh, -1) == 0 then  -- Vide
            local vehPos = GetEntityCoords(veh)
            local dist   = #(coords - vehPos)
            local health = GetVehicleBodyHealth(veh)

            if dist < minDist and health < 900.0 then
                minDist    = dist
                nearestVeh = veh
            end
        end
    end

    if not nearestVeh then
        lib.notify({ title = "Mécano", description = "Aucun véhicule abîmé à proximité.", type = "error" })
        return
    end

    lib.progressBar({
        duration     = 15000,
        label        = "Réparation en cours...",
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, combat = true },
        anim = {
            dict = "mini@repair",
            clip = "fixing_a_ped",
        },
    }, function(cancelled)
        if not cancelled then
            SetVehicleFixed(nearestVeh)
            SetVehicleEngineHealth(nearestVeh, 1000.0)
            SetVehicleBodyHealth(nearestVeh, 1000.0)

            local reward = math.random(50, 150)
            TriggerServerEvent('eightys_jobs:server:payJobReward', "mechanic", reward, "reparation")

            lib.notify({
                title       = "Réparation terminée",
                description = string.format("Véhicule remis à neuf. Gain : $%d", reward),
                type        = "success",
            })
        end
    end)
end

-- ================================================================
-- LIVRAISON (Camionneur)
-- ================================================================
RegisterNetEvent('eightys_jobs:client:startDelivery', function(deliveryData)
    activeDelivery = deliveryData

    -- Blip de livraison
    local dBlip = AddBlipForCoord(deliveryData.x, deliveryData.y, deliveryData.z)
    SetBlipSprite(dBlip, 477)
    SetBlipColour(dBlip, 47)
    SetBlipRoute(dBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Livraison — " .. deliveryData.label)
    EndTextCommandSetBlipName(dBlip)

    lib.notify({
        title       = "Livraison",
        description = string.format("Destination : %s\nRécompense : ~$%d", deliveryData.label, deliveryData.reward),
        type        = "inform",
        duration    = 7000,
    })

    -- Surveiller l'arrivée
    CreateThread(function()
        while activeDelivery do
            Wait(1000)
            local ped  = PlayerPedId()
            local pos  = GetEntityCoords(ped)
            local dist = #(pos - vector3(deliveryData.x, deliveryData.y, deliveryData.z))

            if dist < 20.0 then
                RemoveBlip(dBlip)
                activeDelivery = nil

                lib.progressBar({
                    duration     = 5000,
                    label        = "Déchargement...",
                    useWhileDead = false,
                    canCancel    = false,
                    disable      = { car = true, combat = true },
                    anim = {
                        dict = "anim@heists@ornate_bank@hack",
                        clip = "hack_enter",
                    },
                }, function()
                    TriggerServerEvent('eightys_jobs:server:completeDelivery', deliveryData.reward)
                    lib.notify({
                        title       = "Livraison terminée !",
                        description = string.format("Livré à %s. Gain : $%d", deliveryData.label, deliveryData.reward),
                        type        = "success",
                    })
                end)
                break
            end
        end
    end)
end)

-- ================================================================
-- THREAD PRINCIPAL — Interaction avec les zones d'emploi
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end
    createJobBlips()
end)

CreateThread(function()
    while true do
        local sleep = 2000

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for jobName, job in pairs(Config.Jobs) do
            if job.location then
                local dist = #(coords - vector3(job.location.x, job.location.y, job.location.z))
                if dist < 30.0 then
                    sleep = 0
                    if dist < 3.0 then
                        drawText3D(job.location.x, job.location.y, job.location.z + 1.0,
                            "[E] " .. job.label)
                        if IsControlJustReleased(0, 38) then
                            openJobMenu(jobName, job)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
