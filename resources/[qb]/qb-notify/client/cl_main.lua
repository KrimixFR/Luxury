-- qb-notify client stub
local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('QBCore:Notify', function(text, notifyType, length)
    lib.notify({ title='Info', description=text, type=notifyType or 'inform', duration=length or 5000 })
end)
