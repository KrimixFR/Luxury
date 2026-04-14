-- ================================================================
-- eightys_radio — Client
-- Lecteur cassette 80s : désactive la radio GTA, remplace par
-- des fichiers MP3 locaux via NUI (HTML5 Audio)
-- ================================================================

local QBCore      = exports['qb-core']:GetCoreObject()
local playerData  = nil
local currentVeh  = 0
local deckOpen    = false

-- Cassette actuellement insérée dans ce véhicule { name, label, audioFile, color }
local insertedCassette = nil

-- Index des cassettes par name pour lookup rapide
local cassetteIndex = {}
for _, c in ipairs(Config.Radio.Cassettes) do
    cassetteIndex[c.name] = c
end

-- ================================================================
-- RADIO — Désactivation systématique
-- Le son vient maintenant du NUI (MP3 local), pas de la radio GTA.
-- ================================================================
local function muteRadio(veh)
    if veh == 0 then return end
    SetVehRadioStation(veh, "OFF")
end

-- Désactiver la radio sur le véhicule courant toutes les 2s
-- (GTA peut la réactiver après certains events)
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            -- Le son vient du NUI (MP3) — toujours couper la radio GTA
            muteRadio(veh)
        end
    end
end)

-- Détecter l'entrée dans un véhicule
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and veh ~= lastVeh then
            -- Nouveau véhicule : couper la radio par défaut
            muteRadio(veh)
            -- Éjecter la cassette du véhicule précédent (chaque voiture a son propre lecteur)
            if insertedCassette then
                insertedCassette = nil
                if deckOpen then updateDeckNUI() end
            end
        end

        if veh == 0 and lastVeh ~= 0 then
            -- On est sorti du véhicule
            insertedCassette = nil
        end

        currentVeh = veh
        lastVeh    = veh
    end
end)

-- ================================================================
-- NUI — Mise à jour du lecteur
-- ================================================================
local function getCassettesInInventory()
    local pd    = QBCore.Functions.GetPlayerData()
    local found = {}
    if not pd or not pd.items then return found end
    for _, item in pairs(pd.items) do
        if cassetteIndex[item.name] and (item.amount or 0) > 0 then
            local c = cassetteIndex[item.name]
            table.insert(found, {
                name      = c.name,
                label     = c.label,
                color     = c.color,
                audioFile = c.audioFile,
                qty       = item.amount,
            })
        end
    end
    return found
end

function updateDeckNUI()
    SendNUIMessage({
        type      = 'UPDATE_DECK',
        cassettes = getCassettesInInventory(),
        inserted  = insertedCassette,
        playing   = insertedCassette ~= nil,
    })
end

-- ================================================================
-- OUVRIR / FERMER LE LECTEUR CASSETTE (touche G en véhicule)
-- ================================================================
local function openDeck()
    if deckOpen then return end
    deckOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'OPEN_DECK' })
    updateDeckNUI()
end

local function closeDeck()
    if not deckOpen then return end
    deckOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'CLOSE_DECK' })
end

RegisterNUICallback('closeDeck', function(_, cb)
    closeDeck()
    cb('ok')
end)

-- Insérer une cassette (appelé depuis le NUI)
RegisterNUICallback('insertCassette', function(data, cb)
    local cassette = cassetteIndex[data.name]
    if not cassette then cb('err'); return end

    -- Vérifier que le joueur a bien la cassette
    local pd = QBCore.Functions.GetPlayerData()
    local has = false
    if pd and pd.items then
        for _, item in pairs(pd.items) do
            if item.name == cassette.name and (item.amount or 0) > 0 then
                has = true; break
            end
        end
    end

    if not has then
        lib.notify({ title = "Cassette introuvable", description = "Vous n'avez plus cette cassette.", type = "error" })
        cb('err'); return
    end

    insertedCassette = cassette

    -- Couper la radio GTA (le son vient du NUI)
    if currentVeh ~= 0 then
        muteRadio(currentVeh)
    end

    updateDeckNUI()
    cb('ok')
end)

-- Éjecter la cassette (appelé depuis le NUI)
RegisterNUICallback('ejectCassette', function(_, cb)
    insertedCassette = nil
    if currentVeh ~= 0 then muteRadio(currentVeh) end
    updateDeckNUI()
    cb('ok')
end)

-- Keybinding G pour ouvrir le lecteur (en véhicule uniquement)
RegisterCommand('cassette_player', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        lib.notify({ title = "Lecteur cassette", description = "Vous devez être dans un véhicule.", type = "error" })
        return
    end

    if deckOpen then closeDeck() else openDeck() end
end, false)

RegisterKeyMapping('cassette_player', 'Lecteur cassette (ouvrir/fermer)', 'keyboard', 'G')

-- ================================================================
-- DISQUAIRE — Blip & interaction
-- ================================================================
local shopBlip = nil
local nearShop = false

CreateThread(function()
    -- Attendre que le joueur soit chargé
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    -- Créer le blip du disquaire
    local b = Config.Radio.ShopBlip
    local sp = Config.Radio.ShopLocation
    shopBlip = AddBlipForCoord(sp.x, sp.y, sp.z)
    SetBlipSprite(shopBlip,  b.sprite)
    SetBlipScale(shopBlip,   b.scale)
    SetBlipColour(shopBlip,  b.color)
    SetBlipAsShortRange(shopBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(b.label)
    EndTextCommandSetBlipName(shopBlip)
end)

-- Thread d'interaction avec le disquaire
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    while true do
        local sleep = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sp     = Config.Radio.ShopLocation

        if #(coords - sp) < 10.0 then
            sleep = 0
            -- Afficher le texte d'aide
            local onScreen, sx, sy = World3dToScreen2d(sp.x, sp.y, sp.z + 1.0)
            if onScreen then
                SetTextScale(0.35, 0.35)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(255, 200, 0, 215)
                SetTextEntry("STRING")
                SetTextCentre(true)
                AddTextComponentString("[E] Ray's Records — Acheter une cassette")
                DrawText(sx, sy)
            end

            if IsControlJustReleased(0, 38) and #(coords - sp) < Config.Radio.ShopInteract then
                openShopMenu()
            end
        end

        Wait(sleep)
    end
end)

-- ================================================================
-- MENU D'ACHAT DU DISQUAIRE
-- ================================================================
function openShopMenu()
    local options = {}

    for _, c in ipairs(Config.Radio.Cassettes) do
        local cap = c
        table.insert(options, {
            title       = cap.label,
            icon        = 'compact-disc',
            description = string.format('$%d — %s', cap.price, cap.name:gsub('cassette_', ''):upper()),
            onSelect    = function()
                lib.alertDialog({
                    header  = 'Acheter : ' .. cap.label,
                    content = string.format('Prix : **$%d**\n\nVoulez-vous acheter cette cassette ?', cap.price),
                    centered = true,
                    cancel  = true,
                }, function(confirmed)
                    if confirmed == 'confirm' then
                        TriggerServerEvent('eightys_radio:server:buyCassette', cap.name)
                    end
                end)
            end,
        })
    end

    -- Si le joueur est propriétaire du disquaire
    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.job and pd.job.name == Config.Radio.ShopJob then
        table.insert(options, { title = '── Gestion du disquaire ──', disabled = true })
        table.insert(options, {
            title    = 'Collecter la caisse',
            icon     = 'sack-dollar',
            onSelect = function()
                TriggerServerEvent('eightys_radio:server:collectTill')
            end,
        })
    end

    lib.registerContext({
        id      = 'cassette_shop',
        title   = "Ray's Records — 1987",
        options = options,
    })
    lib.showContext('cassette_shop')
end

-- ================================================================
-- EVENTS SERVEUR → CLIENT
-- ================================================================
RegisterNetEvent('eightys_radio:client:buySuccess', function(cassetteName)
    local c = cassetteIndex[cassetteName]
    if c then
        lib.notify({
            title       = 'Cassette achetée !',
            description = c.label .. ' — profitez du son !',
            type        = 'success',
            duration    = 4000,
        })
    end
end)

RegisterNetEvent('eightys_radio:client:tillCollected', function(amount)
    lib.notify({
        title       = 'Caisse collectée',
        description = string.format('Vous avez récupéré $%d de recettes.', amount),
        type        = 'success',
        duration    = 5000,
    })
end)
