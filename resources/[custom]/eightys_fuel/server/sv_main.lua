-- ================================================================
-- eightys_fuel — Server
-- Persistance du carburant par plaque, paiement pompe
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- BASE DE DONNÉES
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS vehicle_fuel (
            plate      VARCHAR(15) NOT NULL PRIMARY KEY,
            fuel       FLOAT       NOT NULL DEFAULT 100.0,
            updated_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    print('[eightys_fuel] Système carburant initialisé.')
end)

-- ================================================================
-- CHARGER / SAUVEGARDER
-- ================================================================
local function loadFuel(plate)
    local rows = MySQL.query.await('SELECT fuel FROM vehicle_fuel WHERE plate = ?', { plate })
    if rows and rows[1] then
        return math.max(0, math.min(Config.Fuel.MaxFuel, rows[1].fuel))
    end
    return Config.Fuel.DefaultFuel
end

local function saveFuel(plate, fuel)
    fuel = math.max(0, math.min(Config.Fuel.MaxFuel, fuel))
    MySQL.insert.await(
        'INSERT INTO vehicle_fuel (plate, fuel) VALUES (?, ?) ON DUPLICATE KEY UPDATE fuel = VALUES(fuel)',
        { plate, fuel }
    )
end

-- ================================================================
-- EVENTS
-- ================================================================

-- Client demande le carburant d'un véhicule au spawn/entrée
RegisterNetEvent('eightys_fuel:server:getFuel', function(plate)
    local src = source
    if type(plate) ~= 'string' or #plate < 2 or #plate > 8 then return end
    local fuel = loadFuel(plate)
    TriggerClientEvent('eightys_fuel:client:setFuel', src, plate, fuel)
end)

-- Client sauvegarde le carburant périodiquement
RegisterNetEvent('eightys_fuel:server:saveFuel', function(plate, fuel)
    local src = source
    if type(plate) ~= 'string' or #plate < 2 or #plate > 8 then return end
    fuel = tonumber(fuel)
    if not fuel then return end
    saveFuel(plate, fuel)
end)

-- Client demande à faire le plein à la station
RegisterNetEvent('eightys_fuel:server:refuel', function(plate, currentFuel)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(plate) ~= 'string' or #plate < 2 or #plate > 8 then return end

    currentFuel = math.max(0, math.min(Config.Fuel.MaxFuel, tonumber(currentFuel) or 0))
    local needed  = Config.Fuel.MaxFuel - currentFuel
    if needed < 1 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Plein', description = 'Le réservoir est déjà plein.', type = 'inform' })
        return
    end

    local cost = math.ceil(needed * Config.Fuel.PricePerUnit)
    local cash = Player.PlayerData.money['cash'] or 0

    -- Calculer ce qu'on peut remplir avec le cash disponible
    if cash <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Pas de cash', description = 'Vous n\'avez pas d\'argent.', type = 'error' })
        return
    end

    local affordable = math.min(needed, math.floor(cash / Config.Fuel.PricePerUnit))
    local actualCost = math.ceil(affordable * Config.Fuel.PricePerUnit)
    local newFuel    = currentFuel + affordable

    Player.Functions.RemoveMoney('cash', actualCost, 'carburant')
    saveFuel(plate, newFuel)

    TriggerClientEvent('eightys_fuel:client:setFuel', src, plate, newFuel)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '⛽ Plein fait',
        description = string.format('%.0f unités — $%d', affordable, actualCost),
        type        = 'success',
        duration    = 3000,
    })
end)
