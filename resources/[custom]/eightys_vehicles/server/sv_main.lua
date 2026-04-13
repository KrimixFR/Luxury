-- ================================================================
-- eightys_vehicles — Server
-- Logs et gestion serveur des véhicules hors période
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Compteur d'avertissements par joueur
local warnings = {}

RegisterNetEvent('eightys_vehicles:server:reportBannedVehicle', function(model)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not warnings[src] then warnings[src] = 0 end
    warnings[src] = warnings[src] + 1

    print(string.format("[VEHICLES] Avertissement #%d : joueur %d conduit '%s' (hors période)",
        warnings[src], src, model))

    -- Après 3 avertissements, notifier les admins
    if warnings[src] >= 3 then
        local admins = {}
        for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
            if QBCore.Functions.HasPermission(p.PlayerData.source, 'admin') then
                table.insert(admins, p.PlayerData.source)
            end
        end

        for _, adminSrc in ipairs(admins) do
            TriggerClientEvent('ox_lib:notify', adminSrc, {
                title       = "[ALERTE] Véhicule hors période",
                description = string.format("Joueur ID %d conduit '%s' (×%d)", src, model, warnings[src]),
                type        = "error",
                duration    = 10000,
            })
        end
    end
end)

-- Nettoyer au déconnect
AddEventHandler('playerDropped', function()
    warnings[source] = nil
end)

-- ================================================================
-- COMMANDE ADMIN : Réinitialiser les avertissements
-- ================================================================
QBCore.Commands.Add('reset_veh_warns', 'Réinitialiser les avertissements véhicules [Admin]',
    {{ name = "id", help = "ID du joueur" }}, true,
    function(source, args)
        local src = source
        if not QBCore.Functions.HasPermission(src, 'admin') then return end

        local targetId = tonumber(args[1])
        if targetId and warnings[targetId] then
            warnings[targetId] = 0
            TriggerClientEvent('ox_lib:notify', src, {
                title = "Avertissements réinitialisés",
                description = string.format("Joueur %d : 0 avertissement.", targetId),
                type = "success",
            })
        end
    end,
'admin')
