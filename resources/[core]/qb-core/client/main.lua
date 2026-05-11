-- ================================================================
-- QBCore — client/main.lua
-- Gestion côté client : réception des données, login state
-- ================================================================

local IsLoggedIn = false

-- ================================================================
-- RÉCEPTION DES DONNÉES JOUEUR
-- ================================================================
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    IsLoggedIn = true
    LocalPlayer.state:set('isLoggedIn', true, true)
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    IsLoggedIn = false
    LocalPlayer.state:set('isLoggedIn', false, true)
    TriggerEvent('QBCore:Client:OnPlayerUnload')
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if type(val) ~= 'table' then return end
    -- Mettre à jour les données locales via QBCore.Functions
    for k, v in pairs(val) do
        QBCore.Functions.SetPlayerData(k, v)
    end
    TriggerEvent('QBCore:Player:SetPlayerData', val)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    QBCore.Functions.SetPlayerData('job', JobInfo)
    TriggerEvent('QBCore:Client:OnJobUpdate', JobInfo)
end)

-- ================================================================
-- EXPORTS CLIENT
-- ================================================================
exports('GetCoreObject', function()
    return QBCore
end)

-- ================================================================
-- ÉTAT LOGIN (accessible partout)
-- ================================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Initialiser l'état
    LocalPlayer.state:set('isLoggedIn', false, true)
end)
