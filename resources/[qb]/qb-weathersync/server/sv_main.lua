-- qb-weathersync — Server
-- Synchronise la météo pour tous les joueurs

local currentWeather = 'EXTRASUNNY'  -- Toujours ensoleillé à LA
local blackout       = false
local baseHour       = 14            -- 14h (Los Angeles après-midi)
local baseMinute     = 0

-- Envoyer la météo aux nouveaux joueurs
RegisterNetEvent('qb-weathersync:server:requestWeather', function()
    local src = source
    TriggerClientEvent('qb-weathersync:client:syncWeather', src, currentWeather, blackout)
    TriggerClientEvent('qb-weathersync:client:syncTime',    src, baseHour, baseMinute)
end)

-- Commande admin pour changer la météo
RegisterCommand('weather', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'admin') then return end
    local w = args[1] and args[1]:upper() or 'EXTRASUNNY'
    currentWeather = w
    TriggerClientEvent('qb-weathersync:client:syncWeather', -1, currentWeather, blackout)
    print('[qb-weathersync] Météo changée : ' .. currentWeather)
end, true)

print('[qb-weathersync] Météo Los Angeles initialisée : ' .. currentWeather)
