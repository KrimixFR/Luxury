-- qb-ambulancejob client stub
local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('hospital:client:Revive', function()
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(GetEntityCoords(ped), false, true)
    SetEntityHealth(ped, 200)
end)
