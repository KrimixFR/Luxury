-- ================================================================
-- eightys_payphone — Client
-- Cabines téléphoniques — 1987 (pas de portable !)
-- ================================================================

local QBCore      = exports['qb-core']:GetCoreObject()
local nearPhone   = false
local activeCallId = nil
local inCall      = false

-- ================================================================
-- BLIPS & MARQUEURS
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    for _, coords in ipairs(Config.Payphone.Locations) do
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 402)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 4)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Cabine téléphonique")
        EndTextCommandSetBlipName(blip)
    end
end)

-- ================================================================
-- INTERACTION AVEC LES CABINES
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearPhone    = false

        for _, phoneCoords in ipairs(Config.Payphone.Locations) do
            local dist = #(coords - phoneCoords)
            if dist < 8.0 then
                sleep = 0

                if dist < Config.Payphone.UseDist + 0.5 then
                    nearPhone = true

                    local onScreen, sx, sy = World3dToScreen2d(phoneCoords.x, phoneCoords.y, phoneCoords.z + 0.5)
                    if onScreen then
                        SetTextScale(0.32, 0.32)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 200, 0, 215)
                        SetTextEntry("STRING")
                        SetTextCentre(true)
                        if inCall then
                            AddTextComponentString("☎ En communication — [E] Raccrocher")
                        else
                            AddTextComponentString("☎ Cabine téléphonique — [E] Appeler ($" .. Config.Payphone.CallCost .. ")")
                        end
                        DrawText(sx, sy)
                    end

                    if IsControlJustReleased(0, 38) then
                        if inCall then
                            hangup()
                        else
                            openCallMenu()
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ================================================================
-- MENU D'APPEL
-- ================================================================
function openCallMenu()
    local input = lib.inputDialog('☎ Cabine téléphonique', {
        { type = 'input', label = 'Nom du correspondant', placeholder = 'Ex: Jean', required = true },
    })
    if input and input[1] and #input[1] >= 2 then
        TriggerServerEvent('eightys_payphone:server:call', input[1])

        -- Animation décrocher
        local ped  = PlayerPedId()
        local dict = 'mp_facial'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 1000 do Wait(100); t = t + 100 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, 'facials@gen_male@base', 1.0, 1.0, -1, 49, 0, false, false, false)
        end
    end
end

-- ================================================================
-- APPEL ENTRANT
-- ================================================================
RegisterNetEvent('eightys_payphone:client:incomingCall', function(callId, callerName)
    if not nearPhone then
        -- On n'est pas près d'une cabine, refuser automatiquement
        TriggerServerEvent('eightys_payphone:server:decline', callId)
        return
    end

    activeCallId = callId

    -- Sonnerie (bruit de téléphone)
    PlaySoundFrontend(-1, "Phone_SoundSet_Default", "PHONE_RING_SOUNDSET", true)

    lib.registerContext({
        id    = 'payphone_incoming',
        title = '☎ Appel entrant — ' .. callerName,
        options = {
            {
                title    = 'Décrocher',
                icon     = 'phone',
                onSelect = function()
                    TriggerServerEvent('eightys_payphone:server:answer', callId)
                end,
            },
            {
                title    = 'Raccrocher',
                icon     = 'phone-slash',
                onSelect = function()
                    TriggerServerEvent('eightys_payphone:server:decline', callId)
                    activeCallId = nil
                end,
            },
        },
    })
    lib.showContext('payphone_incoming')
end)

-- ================================================================
-- APPEL CONNECTÉ
-- ================================================================
RegisterNetEvent('eightys_payphone:client:callConnected', function(callId)
    activeCallId = callId
    inCall       = true
    lib.hideContext()

    -- Maintenir l'animation téléphone
    local ped  = PlayerPedId()
    local dict = 'cellphone@in_car@ds'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 1000 do Wait(100); t = t + 100 end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, 'idle_a', 1.0, 1.0, -1, 49, 0, false, false, false)
    end
end)

-- ================================================================
-- FIN D'APPEL
-- ================================================================
RegisterNetEvent('eightys_payphone:client:callEnded', function()
    inCall       = false
    activeCallId = nil
    lib.hideContext()
    ClearPedTasks(PlayerPedId())
    lib.notify({ title = '☎ Appel terminé', type = 'inform', duration = 2000 })
end)

-- ================================================================
-- RACCROCHER LOCALEMENT
-- ================================================================
function hangup()
    if activeCallId then
        TriggerServerEvent('eightys_payphone:server:hangup', activeCallId)
    end
    inCall       = false
    activeCallId = nil
    ClearPedTasks(PlayerPedId())
end
