-- ================================================================
-- eightys_loanshark — Client
-- NPC prêteur usurier, menus ox_lib, avertissement collecteur
-- ================================================================

local hasLoan      = false
local loanRemaining = 0
local sharkPed     = nil
local sharkCoords  = vector3(135.8, -1300.5, 29.2)

-- ================================================================
-- HELPERS
-- ================================================================
function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 220, 0, 215); SetTextEntry("STRING"); SetTextCentre(true)
    AddTextComponentString(text); DrawText(sx, sy)
end

-- ================================================================
-- SYNC SERVEUR → CLIENT
-- ================================================================
RegisterNetEvent('eightys_loanshark:client:sync', function(data)
    hasLoan       = data.hasLoan or false
    loanRemaining = data.remaining or 0
end)

RegisterNetEvent('eightys_loanshark:client:collectorWarning', function()
    lib.notify({
        title       = '⚠ Homme de main',
        description = 'Eddie a envoyé quelqu\'un vous chercher. Payez votre dette rapidement.',
        type        = 'error',
        duration    = 15000,
    })
    ShakeGameCam('MEDIUM_EXPLOSION_SHAKE', 0.3)
    Wait(500)
    ShakeGameCam('DRUNK_SHAKE', 0.15)
    Wait(3000)
    StopGameplayCamShaking(true)
end)

-- ================================================================
-- MENU PRÊTEUR
-- ================================================================
local function openSharkMenu()
    local options = {}

    if hasLoan then
        table.insert(options, {
            title    = string.format('Dette en cours : $%s', math.floor(loanRemaining)),
            icon     = 'circle-exclamation',
            disabled = true,
        })
        table.insert(options, { title = '──────────────', disabled = true })
        table.insert(options, {
            title       = 'Rembourser partiellement',
            icon        = 'money-bill',
            description = 'Régler une partie de votre dette',
            onSelect    = function()
                local input = lib.inputDialog('Remboursement partiel', {
                    { type = 'number', label = 'Montant ($)', min = 100, required = true },
                })
                if input and input[1] then
                    TriggerServerEvent('eightys_loanshark:server:repay', tonumber(input[1]))
                end
            end,
        })
        table.insert(options, {
            title       = string.format('Tout rembourser ($%s)', math.floor(loanRemaining)),
            icon        = 'check',
            description = 'Solder la dette intégralement',
            onSelect    = function()
                TriggerServerEvent('eightys_loanshark:server:repay', loanRemaining)
            end,
        })
    else
        table.insert(options, {
            title       = 'Emprunter de l\'argent',
            icon        = 'hand-holding-dollar',
            description = 'Prêt rapide — 15% d\'intérêts par jour (2h réelles)',
            onSelect    = function()
                local input = lib.inputDialog('Emprunt — Eddie le Prêteur', {
                    { type = 'number', label = 'Montant ($500 – $25,000)', min = 500, max = 25000, required = true },
                })
                if input and input[1] then
                    TriggerServerEvent('eightys_loanshark:server:takeLoan', tonumber(input[1]))
                end
            end,
        })
    end

    lib.registerContext({
        id      = 'loanshark_menu',
        title   = '💰 Eddie le Prêteur',
        options = options,
    })
    lib.showContext('loanshark_menu')
end

-- ================================================================
-- SPAWN DU PED
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    TriggerServerEvent('eightys_loanshark:server:requestSync')

    RequestModel('a_m_m_business_01')
    while not HasModelLoaded('a_m_m_business_01') do Wait(100) end

    sharkPed = CreatePed(4, GetHashKey('a_m_m_business_01'),
        sharkCoords.x, sharkCoords.y, sharkCoords.z - 1.0, 200.0, false, true)
    SetEntityInvincible(sharkPed, true)
    SetBlockingOfNonTemporaryEvents(sharkPed, true)
    FreezeEntityPosition(sharkPed, true)
    TaskStartScenarioInPlace(sharkPed, 'WORLD_HUMAN_SMOKING', 0, true)

    -- Blip
    local b = AddBlipForCoord(sharkCoords.x, sharkCoords.y, sharkCoords.z)
    SetBlipSprite(b, 380); SetBlipScale(b, 0.7); SetBlipColour(b, 1)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Eddie le Prêteur")
    EndTextCommandSetBlipName(b)

    SetModelAsNoLongerNeeded('a_m_m_business_01')
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
        local dist   = #(coords - sharkCoords)

        if dist < 15.0 then
            sleep = 0
            if dist < 2.5 then
                DrawText3D(sharkCoords.x, sharkCoords.y, sharkCoords.z + 0.8, '[E] Parler à Eddie')
                if IsControlJustReleased(0, 38) then
                    openSharkMenu()
                end
            end
        end
        Wait(sleep)
    end
end)
