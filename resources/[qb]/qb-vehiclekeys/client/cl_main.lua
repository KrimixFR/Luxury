-- qb-vehiclekeys client stub
local QBCore = exports['qb-core']:GetCoreObject()
-- Les clés sont gérées simplement : entrer dans un véhicule le démarre
exports('addKey', function(plate) end)
exports('removeKey', function(plate) end)
exports('hasKey', function(plate) return true end)
RegisterNetEvent('vehiclekeys:client:SetOwner', function() end)
