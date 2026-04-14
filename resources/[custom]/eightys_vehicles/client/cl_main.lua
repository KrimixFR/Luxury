-- ================================================================
-- eightys_vehicles — Client
-- Trafic ambiant 80s uniquement + contrôle des joueurs
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- LOOKUP TABLES (construites depuis Config)
-- ================================================================
local allowedSet = {}
local bannedSet  = {}

CreateThread(function()
    for _, v in ipairs(Config.AllowedVehicles) do allowedSet[v:lower()] = true end
    for _, v in ipairs(Config.BannedVehicles)  do bannedSet[v:lower()]  = true end
end)

local function getModelName(vehicle)
    return GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
end

local function isAllowed(vehicle)
    local m = getModelName(vehicle)
    if bannedSet[m]  then return false end
    if allowedSet[m] then return true  end
    return true  -- modèle inconnu (mod custom) → autorisé par défaut
end

-- ================================================================
-- SUPPRESSION DU TRAFIC AMBIANT MODERNE
-- SetVehicleModelIsSuppressed empêche le jeu de spawner ce modèle
-- en trafic ambiant. Appelé au démarrage puis toutes les 5 min.
-- ================================================================
local function suppressModernTraffic()
    local count = 0
    for _, model in ipairs(Config.BannedVehicles) do
        local hash = GetHashKey(model)
        if IsModelValid(hash) then
            SetVehicleModelIsSuppressed(hash, true)
            count = count + 1
        end
    end
    return count
end

CreateThread(function()
    -- Attendre que le monde soit chargé
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(2000)

    local n = suppressModernTraffic()
    print(string.format('[eightys_vehicles] %d modèles modernes supprimés du trafic ambiant.', n))

    -- Réappliquer périodiquement (GTA peut réinitialiser après zone change)
    while true do
        Wait(300000)  -- toutes les 5 minutes
        suppressModernTraffic()
    end
end)

-- ================================================================
-- NETTOYAGE DES VÉHICULES MODERNES DÉJÀ SPAWNÉS
-- Parcourt les véhicules proches et supprime les modèles interdits
-- s'ils n'ont pas de conducteur joueur.
-- ================================================================
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(5000)

    while true do
        Wait(30000)  -- toutes les 30 secondes

        local playerPed = PlayerPedId()
        local playerVeh = GetVehiclePedIsIn(playerPed, false)
        local pool = GetGamePool('CVehicle')

        for _, veh in ipairs(pool) do
            -- Ne pas toucher le véhicule du joueur local
            if veh ~= playerVeh then
                local driver = GetPedInVehicleSeat(veh, -1)
                -- Ne pas toucher les véhicules conduits par un joueur humain
                if not IsPedAPlayer(driver) then
                    if bannedSet[getModelName(veh)] then
                        -- Supprimer silencieusement le véhicule moderne
                        DeleteVehicle(veh)
                    end
                end
            end
        end
    end
end)

-- ================================================================
-- CONTRÔLE DU VÉHICULE JOUEUR
-- Avertissement immédiat + expulsion après 60 secondes
-- ================================================================
local ejectionTimers = {}  -- source → timestamp

CreateThread(function()
    while true do
        Wait(3000)

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 then
            if not isAllowed(veh) then
                local model = getModelName(veh)
                local now   = GetGameTimer()

                if not ejectionTimers[veh] then
                    -- Premier contact : avertissement
                    ejectionTimers[veh] = now
                    lib.notify({
                        title       = "Véhicule hors période",
                        description = string.format(
                            "Le '%s' n'existait pas en 1987. Quittez le véhicule dans 60 secondes.",
                            model:upper()),
                        type     = "error",
                        duration = 8000,
                    })
                    TriggerServerEvent('eightys_vehicles:server:reportBannedVehicle', model)

                elseif (now - ejectionTimers[veh]) >= 60000 then
                    -- 60 secondes écoulées → expulsion forcée
                    ejectionTimers[veh] = nil

                    -- Sortir le joueur du véhicule
                    TaskLeaveVehicle(ped, veh, 16)
                    Wait(1500)

                    -- Supprimer le véhicule (sauf si un autre joueur est dedans)
                    local hasOtherPlayer = false
                    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                        local occupant = GetPedInVehicleSeat(veh, seat)
                        if occupant ~= 0 and IsPedAPlayer(occupant) and occupant ~= ped then
                            hasOtherPlayer = true
                            break
                        end
                    end

                    if not hasOtherPlayer then
                        DeleteVehicle(veh)
                    end

                    lib.notify({
                        title       = "Véhicule confisqué",
                        description = "Ce véhicule ne correspond pas au lore de 1987.",
                        type        = "error",
                        duration    = 6000,
                    })
                    TriggerServerEvent('eightys_vehicles:server:reportBannedVehicle', model .. ' [EXPULSÉ]')

                elseif (now - ejectionTimers[veh]) >= 30000 then
                    -- Rappel à 30 secondes
                    local remaining = math.ceil((60000 - (now - ejectionTimers[veh])) / 1000)
                    lib.notify({
                        title       = "⚠ Expulsion imminente",
                        description = string.format(
                            "Quittez le '%s' — %ds restants.",
                            model:upper(), remaining),
                        type     = "warning",
                        duration = 4000,
                    })
                end
            else
                -- Véhicule autorisé → annuler le timer s'il existait
                ejectionTimers[veh] = nil
            end
        end
    end
end)

-- ================================================================
-- HYDRAULIQUES — LOW-RIDERS (commande H)
-- ================================================================
local hydraulicsEnabled = false
local lowRiderModels = {
    voodoo=true, tornado=true, tornado2=true, tornado3=true,
    tornado4=true, tornado5=true, tornado6=true,
    buccaneer=true, buccaneer2=true,
    chino=true, chino2=true,
    peyote=true, peyote2=true, peyote3=true,
}

local function isLowRider(vehicle)
    return lowRiderModels[getModelName(vehicle)] == true
end

RegisterCommand('hydro', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        lib.notify({ title = "Hydrauliques", description = "Pas dans un véhicule.", type = "error" })
        return
    end
    if not isLowRider(veh) then
        lib.notify({ title = "Hydrauliques", description = "Ce véhicule n'a pas d'hydrauliques.", type = "error" })
        return
    end
    hydraulicsEnabled = not hydraulicsEnabled
    if hydraulicsEnabled then
        SetVehicleHandling(veh, "fSuspensionForce",   0.5)
        SetVehicleHandling(veh, "fSuspensionCompDamp", 0.1)
        lib.notify({ title = "Hydrauliques ON",  description = "Les ressorts sont activés.", type = "success" })
    else
        SetVehicleHandling(veh, "fSuspensionForce",   1.0)
        SetVehicleHandling(veh, "fSuspensionCompDamp", 1.0)
        lib.notify({ title = "Hydrauliques OFF", description = "Suspension normale.", type = "inform" })
    end
end, false)

RegisterKeyMapping('hydro', 'Activer/désactiver les hydrauliques', 'keyboard', 'H')

CreateThread(function()
    while true do
        Wait(0)
        if not hydraulicsEnabled then goto continue end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 or not isLowRider(veh) then hydraulicsEnabled = false; goto continue end

        if IsControlPressed(0, 44) then
            SetVehicleHandling(veh, "fSuspensionRaise",  0.3)
        elseif IsControlPressed(0, 38) then
            SetVehicleHandling(veh, "fSuspensionRaise", -0.3)
        else
            SetVehicleHandling(veh, "fSuspensionRaise",  0.0)
        end

        ::continue::
    end
end)

-- ================================================================
-- RADIO — Station Classic Rock au montée en voiture
-- ================================================================
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and veh ~= lastVeh then
            SetVehRadioStation(veh, "RADIO_01_CLASS_ROCK")
        end
        lastVeh = veh
    end
end)

-- ================================================================
-- COMMANDE /vehinfo
-- ================================================================
RegisterCommand('vehinfo', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        lib.notify({ title = "Info véhicule", description = "Pas dans un véhicule.", type = "inform" })
        return
    end
    local model   = getModelName(veh)
    local speed   = math.floor(GetEntitySpeed(veh) * 2.237)
    local health  = math.floor((GetVehicleEngineHealth(veh) / 1000) * 100)
    local plate   = GetVehicleNumberPlateText(veh)
    local allowed = isAllowed(veh)
    lib.alertDialog({
        header  = "Infos Véhicule",
        content = string.format(
            "Modèle : **%s**\nVitesse : **%d MPH**\nMoteur : **%d%%**\nPlaque : **%s**\nÉpoque : **%s**",
            model:upper(), speed, health, plate,
            allowed and "✓ Années 80" or "✗ Hors période"),
        centered = true,
    })
end, false)
