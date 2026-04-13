-- qb-inventory client stub
local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('qb-inventory:client:ItemBox', function(item, action)
    if item then
        lib.notify({ title = action == 'add' and 'Item reçu' or 'Item retiré',
            description = (item.label or item.name or 'Item'),
            type = action == 'add' and 'success' or 'inform', duration = 3000 })
    end
end)
