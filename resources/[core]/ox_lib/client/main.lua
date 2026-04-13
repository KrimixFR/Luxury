-- ================================================================
-- ox_lib — client/main.lua
-- Réception des événements serveur et gestion NUI
-- ================================================================

-- Notification déclenchée depuis le serveur
RegisterNetEvent('ox_lib:notify', function(data)
    if type(data) ~= 'table' then return end
    lib.notify(data)
end)

-- Backward compat : certains scripts triggerent ox_lib:notify avec source
RegisterNetEvent('ox_lib:notify:client', function(data)
    lib.notify(data)
end)
