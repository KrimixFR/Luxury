-- qb-weathersync — Client

local currentWeather = 'EXTRASUNNY'
local blackout       = false

local function applyWeather(weather)
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
    SetOverrideWeather(weather)
end

RegisterNetEvent('qb-weathersync:client:syncWeather', function(weather, isBlackout)
    currentWeather = weather or 'EXTRASUNNY'
    blackout       = isBlackout or false
    applyWeather(currentWeather)
    if blackout then SetArtificialLightsState(true) end
end)

RegisterNetEvent('qb-weathersync:client:syncTime', function(hour, minute)
    NetworkOverrideClockTime(hour, minute, 0)
end)

-- Au chargement, demander la météo au serveur
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-weathersync:server:requestWeather')
end)

-- Thread de maintien de la météo (éviter que GTA la réinitialise)
CreateThread(function()
    while true do
        Wait(60000)  -- Toutes les minutes
        if currentWeather then applyWeather(currentWeather) end
    end
end)
