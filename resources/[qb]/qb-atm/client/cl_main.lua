-- qb-atm client stub
local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('qb-atm:client:openATM', function()
    lib.notify({ title='ATM', description='Retraits disponibles via /atm', type='inform' })
end)
