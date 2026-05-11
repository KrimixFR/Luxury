-- ================================================================
-- eightys_needs — Client
-- Affichage faim/soif, debuffs, animations, épiceries
-- ================================================================

local QBCore     = exports['qb-core']:GetCoreObject()
local hunger     = 100
local thirst     = 100
local nuiVisible = false

-- ================================================================
-- MISE À JOUR HUD
-- ================================================================
RegisterNetEvent('eightys_needs:client:update', function(h, t)
    hunger = h
    thirst = t
    SendNUIMessage({ type = 'UPDATE', hunger = hunger, thirst = thirst })

    -- Debuffs si seuils critiques
    applyDebuffs()
end)

-- ================================================================
-- DEBUFFS — Faim / soif critique
-- ================================================================
local debuffActive = false

function applyDebuffs()
    local critical = hunger <= Config.Needs.StarveThreshold or thirst <= Config.Needs.DehydrateThreshold
    if critical and not debuffActive then
        debuffActive = true
        CreateThread(function()
            while hunger <= Config.Needs.StarveThreshold or thirst <= Config.Needs.DehydrateThreshold do
                Wait(0)
                local ped = PlayerPedId()
                -- Vision floue légère
                SetTimecycleModifier('drug_flying_base')
                SetTimecycleModifierStrength(0.15)
                -- Légère désorientation
                ShakeGameplayCam('DRUNK_SHAKE', 0.05)
                -- Ralentir le sprint si affamé
                if hunger <= Config.Needs.StarveThreshold then
                    SetRunSprintMultiplierForPlayer(PlayerId(), 0.85)
                end
                Wait(500)
            end
            -- Rétablir
            ClearTimecycleModifier()
            StopGameplayCamShaking(true)
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            debuffActive = false
        end)
    end
end

-- ================================================================
-- MALADIE — Intoxication alimentaire
-- ================================================================
RegisterNetEvent('eightys_needs:client:illness', function(duration)
    CreateThread(function()
        local ped     = PlayerPedId()
        local endTime = GetGameTimer() + duration * 1000

        -- Animation de malaise
        RequestAnimDict('mp_player_inteat@burger')
        while not HasAnimDictLoaded('mp_player_inteat@burger') do Wait(100) end

        lib.notify({ title = '🤢 Malaise', description = 'Vous vous sentez très mal...', type = 'error', duration = 5000 })

        while GetGameTimer() < endTime do
            Wait(0)
            SetTimecycleModifier('drug_flying_base')
            SetTimecycleModifierStrength(0.4)
            ShakeGameplayCam('DRUNK_SHAKE', 0.2)
            SetRunSprintMultiplierForPlayer(PlayerId(), 0.6)

            -- Vomissement toutes les 20 secondes
            if GetGameTimer() % 20000 < 100 then
                if not IsEntityPlayingAnim(ped, 'mp_player_inteat@burger', 'puke_exit', 3) then
                    TaskPlayAnim(ped, 'mp_player_inteat@burger', 'puke_exit', 4.0, 4.0, 3000, 0, 0, false, false, false)
                end
            end
        end

        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    end)
end)

-- ================================================================
-- ANIMATION — Manger / boire
-- ================================================================
RegisterNetEvent('eightys_needs:client:eat', function(itemName, isFood)
    local ped  = PlayerPedId()
    local dict = isFood and 'mp_player_inteat@burger' or 'mp_player_intdrink@beer'
    local anim = isFood and 'eat_burger'               or 'drink_beer'

    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 2000 do Wait(100); t = t + 100 end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, anim, 3.0, 3.0, 2500, 49, 0, false, false, false)
    end
end)

-- ================================================================
-- NUI — Affichage barres
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    -- Afficher le HUD
    SendNUIMessage({ type = 'SHOW' })
    nuiVisible = true

    -- Demander la synchro initiale
    TriggerServerEvent('eightys_needs:server:requestSync')
end)

-- ================================================================
-- ÉPICERIES — Blips & interaction
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    -- Créer les blips
    for _, shop in ipairs(Config.Needs.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 52)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, shop.blipColor)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.label)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, shop in ipairs(Config.Needs.Shops) do
            local dist = #(coords - shop.coords)
            if dist < 15.0 then
                sleep = 0

                if dist < 3.5 then
                    local onScreen, sx, sy = World3dToScreen2d(shop.coords.x, shop.coords.y, shop.coords.z + 0.8)
                    if onScreen then
                        SetTextScale(0.35, 0.35)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 200, 0, 215)
                        SetTextEntry("STRING")
                        SetTextCentre(true)
                        AddTextComponentString("[E] " .. shop.label .. " — Acheter")
                        DrawText(sx, sy)
                    end

                    if IsControlJustReleased(0, 38) then
                        openShopMenu(shop.label)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ================================================================
-- MENU D'ÉPICERIE
-- ================================================================
function openShopMenu(shopLabel)
    local options = {}
    for _, si in ipairs(Config.Needs.ShopItems) do
        local item     = si
        local foodData = Config.Needs.Foods[item.name]
        if foodData then
            local expiryDesc
            if foodData.expiresIn == 0 then
                expiryDesc = 'Ne périme pas'
            elseif foodData.expiresIn < 172800 then
                expiryDesc = string.format('Périme dans %d heure(s)', math.floor(foodData.expiresIn / 3600))
            else
                expiryDesc = string.format('Périme dans %d jour(s)', math.floor(foodData.expiresIn / 86400))
            end

            table.insert(options, {
                title       = string.format('%s  —  $%d', item.name:gsub('^%l', string.upper), item.price),
                icon        = foodData.hunger > 0 and 'burger-soda' or 'bottle-water',
                description = expiryDesc,
                onSelect    = function()
                    local input = lib.inputDialog('Acheter — ' .. item.name, {
                        { type = 'number', label = 'Quantité', default = 1, min = 1, max = 10, required = true },
                    })
                    if input and input[1] then
                        TriggerServerEvent('eightys_needs:server:buyFood', item.name, tonumber(input[1]))
                    end
                end,
            })
        end
    end

    lib.registerContext({
        id      = 'needs_shop',
        title   = shopLabel,
        options = options,
    })
    lib.showContext('needs_shop')
end
