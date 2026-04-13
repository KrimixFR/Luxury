-- ================================================================
-- eightys_police — Client
-- LAPD & Vice Squad — Los Angeles 1987
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local isPolice     = false
local isViceSquad  = false
local isCuffed     = false
local isEscorted   = false
local escortTarget = nil

-- ================================================================
-- VÉRIFICATION DU JOB
-- ================================================================
local function checkJob()
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.job then
        isPolice    = playerData.job.name == "police"
        isViceSquad = playerData.job.name == "vicesquad"
    end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    checkJob()
    setupPoliceBlips()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    isPolice    = JobInfo.name == "police"
    isViceSquad = JobInfo.name == "vicesquad"
end)

-- ================================================================
-- BLIPS POLICE
-- ================================================================
local function setupPoliceBlips()
    for _, loc in ipairs(Config.Police.Locations) do
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, loc.blip.sprite)
        SetBlipScale(blip, loc.blip.scale)
        SetBlipColour(blip, loc.blip.color)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(loc.blip.label)
        EndTextCommandSetBlipName(blip)
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
        SetTextColour(100, 180, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = string.len(text) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- ================================================================
-- MENOTTES — Systeme d'arrestation
-- ================================================================
RegisterNetEvent('eightys_police:client:cuffPlayer', function()
    isCuffed = true

    -- Animations
    local ped = PlayerPedId()
    RequestAnimDict("mp_arresting")
    while not HasAnimDictLoaded("mp_arresting") do Wait(100) end

    SetEnableHandcuffs(ped, true)
    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    lib.notify({
        title       = "Menottes",
        description = "Vous êtes menottés. Restez calme.",
        type        = "error",
        duration    = 5000,
    })

    -- Bloquer certaines actions
    CreateThread(function()
        while isCuffed do
            Wait(0)
            DisableControlAction(0, 24, true)  -- Attaque
            DisableControlAction(0, 25, true)  -- Attaque corps à corps
            DisableControlAction(0, 47, true)  -- Arme
            DisableControlAction(0, 58, true)  -- Snipe
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 37, true)  -- Enter vehicle
        end
    end)
end)

RegisterNetEvent('eightys_police:client:uncuffPlayer', function()
    isCuffed = false
    local ped = PlayerPedId()
    SetEnableHandcuffs(ped, false)
    StopAnimTask(ped, "mp_arresting", "idle", 1.0)
    ClearPedTasks(ped)

    lib.notify({
        title       = "Libéré",
        description = "Vous avez été libéré des menottes.",
        type        = "success",
        duration    = 3000,
    })
end)

-- ================================================================
-- TÉLÉPORTATION EN PRISON
-- ================================================================
RegisterNetEvent('eightys_police:client:sendToJail', function(sentence)
    local ped = PlayerPedId()
    local jailCoords = Config.Police.JailLocation

    -- Téléporter au pénitencier
    SetEntityCoords(ped, jailCoords.x, jailCoords.y, jailCoords.z, false, false, false, true)
    SetEntityHeading(ped, jailCoords.w)

    isCuffed = false
    SetEnableHandcuffs(ped, false)

    lib.notify({
        title       = "Arrêté",
        description = string.format("Vous avez été envoyé au pénitencier pour %d minutes.", math.floor(sentence / 60)),
        type        = "error",
        duration    = 8000,
    })

    -- Timer de libération
    CreateThread(function()
        Wait(sentence * 1000)
        local releaseCoords = Config.Police.Locations[1].coords
        SetEntityCoords(ped, releaseCoords.x, releaseCoords.y, releaseCoords.z, false, false, false, true)
        lib.notify({
            title       = "Libéré",
            description = "Vous avez purgé votre peine. Restez dans le droit chemin.",
            type        = "success",
            duration    = 5000,
        })
    end)
end)

-- ================================================================
-- COMMANDES POLICE UNIQUEMENT
-- ================================================================

-- /menottes — Menotter le joueur le plus proche
RegisterCommand('menottes', function()
    if not isPolice and not isViceSquad then
        lib.notify({ title = "Accès refusé", description = "Réservé aux forces de l'ordre.", type = "error" })
        return
    end

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local maxDist = Config.Police.CuffDistance
    local target = nil
    local minDist = maxDist + 1

    -- Trouver le joueur le plus proche
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed  = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(coords - targetCoords)
            if dist < minDist then
                minDist = dist
                target  = playerId
            end
        end
    end

    if target and minDist <= maxDist then
        TriggerServerEvent('eightys_police:server:cuffPlayer', GetPlayerServerId(target))
    else
        lib.notify({ title = "Trop loin", description = "Aucun joueur à portée.", type = "inform" })
    end
end, false)

-- /arreter — Arrêter et emprisonner
RegisterCommand('arreter', function(source, args)
    if not isPolice and not isViceSquad then
        lib.notify({ title = "Accès refusé", type = "error", description = "Réservé aux forces de l'ordre." })
        return
    end

    local minutes = tonumber(args[1]) or 5
    minutes = math.max(1, math.min(30, minutes))

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local target = nil
    local minDist = Config.Police.CuffDistance + 1

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed  = GetPlayerPed(playerId)
            local dist = #(coords - GetEntityCoords(targetPed))
            if dist < minDist then
                minDist = dist
                target  = playerId
            end
        end
    end

    if target and minDist <= Config.Police.CuffDistance then
        TriggerServerEvent('eightys_police:server:arrestPlayer', GetPlayerServerId(target), minutes * 60)
    else
        lib.notify({ title = "Trop loin", type = "inform", description = "Aucun joueur à portée." })
    end
end, false)

-- /sacpreuves — Ramasser des preuves
RegisterCommand('sacpreuves', function()
    if not isPolice and not isViceSquad then
        lib.notify({ title = "Accès refusé", type = "error", description = "Réservé aux forces de l'ordre." })
        return
    end

    lib.progressBar({
        duration = 3000,
        label    = "Collecte de preuves...",
        useWhileDead = false,
        canCancel    = true,
        disable = { car = true, combat = true },
        anim = {
            dict  = "anim@narcotics@trash_search",
            clip  = "trashsearch_litter_idle",
        },
    }, function(cancelled)
        if not cancelled then
            TriggerServerEvent('eightys_police:server:collectEvidence')
        end
    end)
end, false)

-- /armurerie — Accéder à l'armurerie (dans le commissariat)
RegisterCommand('armurerie', function()
    if not isPolice and not isViceSquad then
        lib.notify({ title = "Accès refusé", type = "error" })
        return
    end

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local atStation = false

    for _, loc in ipairs(Config.Police.Locations) do
        if #(coords - vector3(loc.coords.x, loc.coords.y, loc.coords.z)) < 15.0 then
            atStation = true
            break
        end
    end

    if not atStation then
        lib.notify({
            title       = "Hors zone",
            description = "Vous devez être au commissariat.",
            type        = "error",
        })
        return
    end

    TriggerServerEvent('eightys_police:server:openArmory')
end, false)

-- ================================================================
-- RADAR VITESSE (Vice Squad)
-- ================================================================
local radarActive = false

RegisterCommand('radar', function()
    if not isPolice and not isViceSquad then return end

    radarActive = not radarActive
    lib.notify({
        title       = radarActive and "Radar activé" or "Radar désactivé",
        description = radarActive and "Surveillance des vitesses active." or "",
        type        = "inform",
    })
end, false)

CreateThread(function()
    while true do
        Wait(2000)
        if not radarActive or (not isPolice and not isViceSquad) then goto continue end

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, playerId in ipairs(GetActivePlayers()) do
            if playerId ~= PlayerId() then
                local targetPed = GetPlayerPed(playerId)
                local vehicle   = GetVehiclePedIsIn(targetPed, false)

                if vehicle ~= 0 then
                    local dist = #(coords - GetEntityCoords(targetPed))
                    if dist < 80.0 then
                        local speed = GetEntitySpeed(vehicle) * 2.237  -- MPH
                        if speed > 80 then   -- > 80 MPH
                            lib.notify({
                                title       = string.format("⚡ EXCÈS DE VITESSE"),
                                description = string.format("ID %d — %.0f MPH", GetPlayerServerId(playerId), speed),
                                type        = "error",
                                duration    = 4000,
                            })
                        end
                    end
                end
            end
        end

        ::continue::
    end
end)

-- ================================================================
-- AFFICHAGE DANS LES ZONES POLICE
-- ================================================================
CreateThread(function()
    while true do
        local sleep = 2000

        if isPolice or isViceSquad then
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for _, loc in ipairs(Config.Police.Locations) do
                if #(coords - vector3(loc.coords.x, loc.coords.y, loc.coords.z)) < 30.0 then
                    sleep = 0
                    drawText3D(loc.coords.x, loc.coords.y, loc.coords.z + 1.0,
                        "[/menottes] Menotter  |  [/arreter X] Arrêter  |  [/armurerie] Équipement")
                end
            end
        end

        Wait(sleep)
    end
end)
