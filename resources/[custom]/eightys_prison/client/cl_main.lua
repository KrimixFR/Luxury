-- ================================================================
-- eightys_prison — Client
-- Incarcération, musculation, marché noir, libération
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local inPrison     = false
local sentenceEnd  = 0
local workoutBuff  = false

local PRISON_COORDS  = vector4(1649.4, 2564.6, 45.7, 90.0)
local WORKOUT_COORDS = vector3(1720.0, 2612.5, 45.6)
local MARKET_COORDS  = vector3(1690.0, 2570.0, 45.6)
local RELEASE_COORDS = vector4(1853.7, 2586.5, 45.7, 270.0)

local CONTRABAND = {
    { item='cigarettes', label='Cigarettes',  price=50  },
    { item='bandage',    label='Pansement',   price=150 },
    { item='lighter',    label='Briquet',     price=30  },
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

local function teleport(coords)
    DoScreenFadeOut(500)
    Wait(600)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    DoScreenFadeIn(500)
end

-- ================================================================
-- INCARCÉRATION
-- ================================================================
RegisterNetEvent('eightys_prison:client:jail', function(data)
    inPrison    = true
    sentenceEnd = data.sentenceEnd

    lib.notify({
        title       = '🔒 Incarcéré',
        description = string.format('Peine : %d min. Motif : %s', data.minutes, data.reason),
        type        = 'error',
        duration    = 10000,
    })

    teleport(PRISON_COORDS)

    -- Retirer les armes
    RemoveAllPedWeapons(PlayerPedId(), true)
end)

-- ================================================================
-- LIBÉRATION
-- ================================================================
RegisterNetEvent('eightys_prison:client:release', function()
    inPrison    = false
    sentenceEnd = 0

    lib.notify({
        title       = '🔓 Libéré',
        description = 'Votre peine est terminée. Bienvenue dans le monde libre.',
        type        = 'success',
        duration    = 8000,
    })

    teleport(RELEASE_COORDS)
end)

-- ================================================================
-- BUFF MUSCULATION
-- ================================================================
RegisterNetEvent('eightys_prison:client:workoutBuff', function(duration)
    workoutBuff = true
    SetPedArmour(PlayerPedId(), 50)  -- donne de l'armure symboliquement

    SetTimeout(duration * 1000, function()
        workoutBuff = false
        lib.notify({ title='💪 Buff expiré', description='L\'effet de la séance de sport s\'est dissipé.', type='info' })
    end)
end)

-- ================================================================
-- MENU MARCHÉ NOIR
-- ================================================================
local function openMarketMenu()
    local options = {}
    for _, item in ipairs(CONTRABAND) do
        table.insert(options, {
            title       = item.label,
            icon        = 'box',
            description = string.format('$%d', item.price),
            onSelect    = function()
                TriggerServerEvent('eightys_prison:server:buyContraband', item.item)
            end,
        })
    end
    lib.registerContext({ id='prison_market', title='🤝 Marché Noir', options=options })
    lib.showContext('prison_market')
end

-- ================================================================
-- THREAD PRINCIPAL — MINUTERIE ET INTERACTIONS
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    TriggerServerEvent('eightys_prison:server:requestSync')
end)

CreateThread(function()
    while true do
        Wait(1000)

        if inPrison then
            local remaining = sentenceEnd - os.time()

            if remaining <= 0 then
                -- Peine terminée
                TriggerServerEvent('eightys_prison:client:release') -- le serveur confirme
                inPrison = false
                TriggerClientEvent('eightys_prison:client:release', PlayerId())
            else
                -- Afficher le temps restant en HUD
                local mins = math.floor(remaining / 60)
                local secs = remaining % 60
                -- Dessin simple en haut de l'écran
                SetTextFont(4); SetTextScale(0.4, 0.4)
                SetTextColour(255, 80, 80, 220)
                SetTextEntry("STRING")
                AddTextComponentString(string.format('🔒 PEINE : %02d:%02d', mins, secs))
                DrawText(0.5, 0.02)
                SetTextCentre(true)
            end
        end
    end
end)

-- ================================================================
-- THREAD PROXIMITÉ — Musculation et marché
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    while true do
        local sleep = 2000

        if inPrison then
            sleep = 0
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)

            -- Zone musculation
            if #(coords - WORKOUT_COORDS) < 2.5 then
                DrawText3D(WORKOUT_COORDS.x, WORKOUT_COORDS.y, WORKOUT_COORDS.z + 1.0, '[E] S\'entraîner (boost de force)')
                if IsControlJustReleased(0, 38) then
                    lib.progressBar({
                        duration = 8000,
                        label    = 'Musculation...',
                        useWhileDead = false,
                        canCancel    = false,
                        anim = { dict='amb@world_human_push_ups@male@base', clip='base', flag=49 },
                    })
                    TriggerServerEvent('eightys_prison:server:workout')
                end
            end

            -- Zone marché noir
            if #(coords - MARKET_COORDS) < 2.5 then
                DrawText3D(MARKET_COORDS.x, MARKET_COORDS.y, MARKET_COORDS.z + 1.0, '[E] Marché noir')
                if IsControlJustReleased(0, 38) then
                    openMarketMenu()
                end
            end
        end

        Wait(sleep)
    end
end)
