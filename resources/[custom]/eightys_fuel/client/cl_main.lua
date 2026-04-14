-- ================================================================
-- eightys_fuel — Client
-- Consommation de carburant, jauge, stations, alerte
-- ================================================================

local QBCore      = exports['qb-core']:GetCoreObject()
local vehicleFuel = {}   -- [plate] = fuel
local currentPlate = nil
local alertSent    = false
local saveTimer    = 0

-- ================================================================
-- RÉCUPÉRER LE CARBURANT D'UN VÉHICULE
-- ================================================================
local function getPlate(veh)
    return GetVehicleNumberPlateText(veh):gsub('%s+', '')
end

RegisterNetEvent('eightys_fuel:client:setFuel', function(plate, fuel)
    vehicleFuel[plate] = fuel
    if plate == currentPlate then
        updateFuelHUD(fuel)
    end
end)

-- ================================================================
-- CONSOMMATION & GESTION DU CARBURANT
-- ================================================================
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local plate = getPlate(veh)

            -- Charger le carburant depuis le serveur si inconnu
            if not vehicleFuel[plate] then
                vehicleFuel[plate] = Config.Fuel.DefaultFuel
                TriggerServerEvent('eightys_fuel:server:getFuel', plate)
            end

            currentPlate = plate
            local fuel   = vehicleFuel[plate] or Config.Fuel.DefaultFuel

            -- Calculer la consommation selon le régime moteur
            local rpm    = GetVehicleCurrentRpm(veh)
            local speed  = GetEntitySpeed(veh) * 3.6
            local isOn   = GetIsVehicleEngineRunning(veh)

            if isOn and speed > 5 then
                local consumption = Config.Fuel.ConsumptionRate * rpm * (GetVehicleThrottleOffset(veh) + 0.1)
                fuel = math.max(0, fuel - consumption)
                vehicleFuel[plate] = fuel
            end

            -- Moteur cale si vide
            if fuel <= 0 then
                SetVehicleEngineOn(veh, false, true, false)
                if not alertSent then
                    lib.notify({ title = '⛽ En panne', description = 'Vous êtes à court de carburant !', type = 'error', duration = 5000 })
                    alertSent = true
                end
            elseif fuel <= Config.Fuel.LowFuelAlert and not alertSent then
                lib.notify({ title = '⛽ Carburant faible', description = string.format('%.0f%% restant', fuel), type = 'warning', duration = 4000 })
                alertSent = true
            elseif fuel > Config.Fuel.LowFuelAlert then
                alertSent = false
            end

            updateFuelHUD(fuel)

            -- Sauvegarder toutes les 30 secondes
            saveTimer = saveTimer + 1
            if saveTimer >= 30 then
                saveTimer = 0
                TriggerServerEvent('eightys_fuel:server:saveFuel', plate, fuel)
            end
        else
            -- Pas en voiture : vider l'affichage
            if currentPlate then
                -- Sauvegarder avant de quitter
                if vehicleFuel[currentPlate] then
                    TriggerServerEvent('eightys_fuel:server:saveFuel', currentPlate, vehicleFuel[currentPlate])
                end
                currentPlate = nil
                alertSent    = false
                hideFuelHUD()
            end
        end
    end
end)

-- ================================================================
-- HUD — Jauge de carburant (via DrawRect natif, pas de NUI)
-- ================================================================
local showHUD   = false
local fuelLevel = 100.0

function updateFuelHUD(fuel)
    fuelLevel = fuel
    showHUD   = true
end

function hideFuelHUD()
    showHUD = false
end

CreateThread(function()
    while true do
        Wait(0)
        if showHUD then
            local pct = fuelLevel / Config.Fuel.MaxFuel

            -- Fond de la barre
            DrawRect(0.957, 0.945, 0.074, 0.012, 0, 0, 0, 160)
            -- Barre carburant
            local r = pct > 0.3 and 80  or 255
            local g = pct > 0.3 and 200 or 60
            DrawRect(0.957 - (0.037 * (1 - pct)), 0.945, 0.074 * pct, 0.009, r, g, 20, 220)

            -- Texte ⛽ et valeur
            SetTextFont(4)
            SetTextScale(0.22, 0.22)
            SetTextColour(200, 200, 200, 200)
            SetTextEntry("STRING")
            AddTextComponentString(string.format("⛽ %.0f%%", fuelLevel))
            DrawText(0.924, 0.938)
        end
    end
end)

-- ================================================================
-- STATIONS ESSENCE — Blips & interaction
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    for _, station in ipairs(Config.Fuel.Stations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 361)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, 1)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, station in ipairs(Config.Fuel.Stations) do
            local dist = #(coords - station.coords)
            if dist < 20.0 then
                sleep = 0
                if dist < 4.0 then
                    local onScreen, sx, sy = World3dToScreen2d(station.coords.x, station.coords.y, station.coords.z + 0.8)
                    if onScreen then
                        SetTextScale(0.35, 0.35)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 200, 0, 215)
                        SetTextEntry("STRING")
                        SetTextCentre(true)
                        AddTextComponentString("[E] " .. station.label .. " — Faire le plein ($" .. Config.Fuel.PricePerUnit .. "/u)")
                        DrawText(sx, sy)
                    end

                    if IsControlJustReleased(0, 38) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh ~= 0 then
                            local plate = getPlate(veh)
                            local fuel  = vehicleFuel[plate] or Config.Fuel.DefaultFuel
                            TriggerServerEvent('eightys_fuel:server:refuel', plate, fuel)
                        else
                            lib.notify({ title = '⛽ Station', description = 'Vous devez être dans un véhicule.', type = 'error' })
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
