-- ================================================================
-- eightys_pager — Client
-- Système de biper et cabines téléphoniques
-- Pas de smartphones en 1987 — que du low-tech !
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local pagerOpen       = false
local messages        = {}    -- Messages stockés localement
local nearPayphone    = false
local payPhoneBlips   = {}

-- ================================================================
-- CRÉATION DES BLIPS CABINES
-- ================================================================
local function createPayphoneBlips()
    for _, phone in ipairs(Config.Pager.PayphoneLocations) do
        local blip = AddBlipForCoord(phone.coords.x, phone.coords.y, phone.coords.z)
        SetBlipSprite(blip, 303)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Cabine — " .. phone.label)
        EndTextCommandSetBlipName(blip)
        table.insert(payPhoneBlips, blip)
    end
end

-- ================================================================
-- OUVRIR LE PAGER (UI NUI)
-- ================================================================
local function openPager()
    if pagerOpen then return end
    pagerOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        type     = "OPEN_PAGER",
        messages = messages,
    })
end

local function closePager()
    if not pagerOpen then return end
    pagerOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "CLOSE_PAGER" })
end

-- ================================================================
-- ENVOYER UN MESSAGE VIA BIPER
-- ================================================================
local function sendPagerMessage()
    local input = lib.inputDialog("Envoyer un message biper", {
        { type = "number", label = "ID du destinataire",           min = 1             },
        { type = "input",  label = "Message (120 chars max)",      maxLength = 120     },
    })

    if not input or not input[1] or not input[2] or input[2] == "" then return end

    local targetId = tonumber(input[1])
    local message  = tostring(input[2])

    TriggerServerEvent('eightys_pager:server:sendMessage', targetId, message)
end

-- ================================================================
-- RÉCEPTION D'UN MESSAGE
-- ================================================================
RegisterNetEvent('eightys_pager:client:receiveMessage', function(senderName, message, senderId)
    -- Beep sonore
    PlaySound(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    PlaySound(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)

    -- Ajouter à la liste locale
    table.insert(messages, 1, {
        from    = senderName,
        fromId  = senderId,
        text    = message,
        time    = os.date("%H:%M"),
    })

    -- Garder max 10 messages
    while #messages > Config.Pager.MaxMessages do
        table.remove(messages)
    end

    -- Notification sur l'écran
    lib.notify({
        title       = string.format("📟 Message de %s", senderName),
        description = message,
        type        = "inform",
        duration    = 7000,
        position    = "top-right",
    })

    -- Mettre à jour le NUI si ouvert
    if pagerOpen then
        SendNUIMessage({
            type     = "UPDATE_MESSAGES",
            messages = messages,
        })
    end
end)

-- ================================================================
-- CABINES TÉLÉPHONIQUES — Interaction
-- ================================================================
local function handlePayphones()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    nearPayphone = false

    for _, phone in ipairs(Config.Pager.PayphoneLocations) do
        local dist = #(coords - phone.coords)
        if dist < 2.5 then
            nearPayphone = true

            -- Texte 3D
            local onScreen, _x, _y = World3dToScreen2d(phone.coords.x, phone.coords.y, phone.coords.z + 1.0)
            if onScreen then
                SetTextScale(0.35, 0.35)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(100, 255, 100, 215)
                SetTextEntry("STRING")
                SetTextCentre(true)
                AddTextComponentString("[E] Utiliser la cabine — " .. phone.label)
                DrawText(_x, _y)
                local factor = 0.07
                DrawRect(_x, _y + 0.0125, factor, 0.03, 0, 0, 0, 75)
            end

            if IsControlJustReleased(0, 38) then
                openPayphoneMenu(phone)
            end
            break
        end
    end
end

local function openPayphoneMenu(phone)
    -- Animation
    local ped = PlayerPedId()
    RequestAnimDict("amb@world_human_mobile_film_shocking@male@idle_a")
    while not HasAnimDictLoaded("amb@world_human_mobile_film_shocking@male@idle_a") do Wait(100) end
    TaskPlayAnim(ped, "amb@world_human_mobile_film_shocking@male@idle_a", "idle_a", 8.0, -8.0, -1, 49, 0, false, false, false)

    lib.registerContext({
        id    = "payphone_menu",
        title = "☎ Cabine Téléphonique — " .. phone.label,
        options = {
            {
                title    = "Envoyer un message biper",
                icon     = "pager",
                description = "Envoyer un message à un joueur via son biper",
                onSelect = function()
                    StopAnimTask(ped, "amb@world_human_mobile_film_shocking@male@idle_a", "idle_a", 1.0)
                    sendPagerMessage()
                end,
            },
            {
                title    = "Lire mes messages",
                icon     = "envelope",
                description = string.format("%d message(s) non lus", #messages),
                onSelect = function()
                    StopAnimTask(ped, "amb@world_human_mobile_film_shocking@male@idle_a", "idle_a", 1.0)
                    openPager()
                end,
            },
            {
                title    = "Appel d'urgence — LAPD",
                icon     = "phone",
                description = "Contacter le 911",
                onSelect = function()
                    StopAnimTask(ped, "amb@world_human_mobile_film_shocking@male@idle_a", "idle_a", 1.0)
                    TriggerServerEvent('eightys_pager:server:call911')
                end,
            },
            {
                title    = "Raccrocher",
                icon     = "xmark",
                onSelect = function()
                    StopAnimTask(ped, "amb@world_human_mobile_film_shocking@male@idle_a", "idle_a", 1.0)
                end,
            },
        },
    })
    lib.showContext("payphone_menu")
end

-- ================================================================
-- COMMANDE : Ouvrir son biper
-- ================================================================
RegisterCommand('biper', function()
    if pagerOpen then
        closePager()
    else
        -- Charger les messages depuis le serveur si nécessaire
        TriggerServerEvent('eightys_pager:server:loadMessages')
    end
end, false)

RegisterKeyMapping('biper', 'Ouvrir le biper', 'keyboard', 'NUMPAD0')

-- ================================================================
-- NUI CALLBACKS
-- ================================================================
RegisterNUICallback('pagerReady', function(_, cb)
    SendNUIMessage({
        type     = "INIT",
        messages = messages,
    })
    cb('ok')
end)

RegisterNUICallback('closePager', function(_, cb)
    closePager()
    cb('ok')
end)

RegisterNUICallback('sendMessage', function(data, cb)
    if data and data.targetId and data.message then
        TriggerServerEvent('eightys_pager:server:sendMessage', tonumber(data.targetId), tostring(data.message))
    end
    cb('ok')
end)

RegisterNUICallback('deleteMessage', function(data, cb)
    if data and data.index then
        table.remove(messages, tonumber(data.index))
        SendNUIMessage({ type = "UPDATE_MESSAGES", messages = messages })
    end
    cb('ok')
end)

-- ================================================================
-- MESSAGES CHARGÉS DEPUIS LE SERVEUR
-- ================================================================
RegisterNetEvent('eightys_pager:client:loadMessages', function(serverMessages)
    messages = serverMessages or {}
    if pagerOpen then
        SendNUIMessage({ type = "UPDATE_MESSAGES", messages = messages })
    else
        openPager()
    end
end)

-- ================================================================
-- APPEL 911 REÇU PAR LA POLICE
-- ================================================================
RegisterNetEvent('eightys_pager:client:receive911', function(callerName, coords, message)
    lib.notify({
        title       = "🚨 Appel 911",
        description = string.format("De : %s\n%s", callerName, message or "Urgence signalée"),
        type        = "error",
        duration    = 15000,
        position    = "top",
    })

    -- Afficher un blip temporaire
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("911 — " .. callerName)
    EndTextCommandSetBlipName(blip)

    -- Supprimer le blip après 3 minutes
    CreateThread(function()
        Wait(180000)
        RemoveBlip(blip)
    end)
end)

-- ================================================================
-- THREAD PRINCIPAL
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end
    createPayphoneBlips()
end)

CreateThread(function()
    while true do
        local sleep = 2000

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, phone in ipairs(Config.Pager.PayphoneLocations) do
            if #(coords - phone.coords) < 20.0 then
                sleep = 0
                break
            end
        end

        handlePayphones()
        Wait(sleep)
    end
end)
