-- ================================================================
-- eightys_newspaper — Client
-- Kiosques à journaux, NUI, notifications nouvelle édition
-- ================================================================

local paperOpen = false

local kiosks = {
    vector3(146.0,   -1040.0, 29.4),   -- Fleeca South LS
    vector3(-540.0,  -197.0,  38.2),   -- Rockford Hills
    vector3(368.0,   -700.0,  28.5),   -- Downtown
    vector3(-1222.0, -904.0,  12.3),   -- Forum Drive
}

-- ================================================================
-- HELPERS
-- ================================================================
function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 215); SetTextEntry("STRING"); SetTextCentre(true)
    AddTextComponentString(text); DrawText(sx, sy)
end

-- ================================================================
-- EVENTS SERVEUR
-- ================================================================
RegisterNetEvent('eightys_newspaper:client:receiveEdition', function(data)
    paperOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'OPEN_PAPER', data = data })
end)

RegisterNetEvent('eightys_newspaper:client:newEdition', function(num)
    lib.notify({
        title       = '📰 Los Santos Chronicle',
        description = string.format('Nouvelle édition disponible ! (N°%d) — Achetez-la au kiosque pour $5.', num),
        type        = 'info',
        duration    = 10000,
    })
end)

-- ================================================================
-- NUI CALLBACKS
-- ================================================================
RegisterNUICallback('close', function(_, cb)
    paperOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ================================================================
-- BLIPS KIOSQUES
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    for _, coords in ipairs(kiosks) do
        local b = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(b, 175); SetBlipScale(b, 0.6); SetBlipColour(b, 0)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Kiosque à journaux")
        EndTextCommandSetBlipName(b)
    end
end)

-- ================================================================
-- THREAD PROXIMITÉ
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, kiosk in ipairs(kiosks) do
            if #(coords - kiosk) < 12.0 then
                sleep = 0
                if #(coords - kiosk) < 2.0 then
                    DrawText3D(kiosk.x, kiosk.y, kiosk.z + 0.5, '[E] Acheter le journal ($5)')
                    if IsControlJustReleased(0, 38) and not paperOpen then
                        TriggerServerEvent('eightys_newspaper:server:buy')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ================================================================
-- TOUCHE ECHAP
-- ================================================================
CreateThread(function()
    while true do
        Wait(0)
        if paperOpen and IsControlJustReleased(0, 200) then
            paperOpen = false
            SetNuiFocus(false, false)
            SendNUIMessage({ type = 'CLOSE' })
        end
    end
end)
