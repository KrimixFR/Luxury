-- qb-atm server stub
local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('qb-atm:server:withdraw', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    if Player.Functions.RemoveMoney('bank', amount, 'retrait-atm') then
        Player.Functions.AddMoney('cash', amount, 'retrait-atm')
        TriggerClientEvent('ox_lib:notify', src, { title='Retrait', description='$'..amount..' retirés.', type='success' })
    end
end)
