-- qb-banking client stub
local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('qb-banking:client:openBank', function()
    lib.notify({ title='Fleeca Bank', description='Bienvenue à la Fleeca Bank.', type='inform' })
end)
