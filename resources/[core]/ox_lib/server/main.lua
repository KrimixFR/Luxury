-- ================================================================
-- ox_lib — server/main.lua
-- Fonctions serveur (notify vers client)
-- ================================================================

-- Permet aux scripts d'utiliser TriggerClientEvent('ox_lib:notify', src, data)
-- Le handler est côté client (client/main.lua)

-- Export serveur pour notifier un joueur
exports('notify', function(source, data)
    TriggerClientEvent('ox_lib:notify', source, data)
end)
