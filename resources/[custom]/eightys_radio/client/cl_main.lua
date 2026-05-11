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

-- Volume local du joueur (0.0 – 1.0)
local localVolume = Config.Radio.RadioDefaultVolume or 0.8

-- Diffusions radio des autres joueurs reçues du serveur
-- nearbyBroadcasts[serverId] = { netId, audioFile, volume }
local nearbyBroadcasts = {}

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
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            muteRadio(veh)
        end
    end
end)

-- Détecter l'entrée / sortie de véhicule
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and veh ~= lastVeh then
            muteRadio(veh)
            -- Éjecter la cassette du véhicule précédent
            if insertedCassette then
                insertedCassette = nil
                TriggerServerEvent('eightys_radio:server:stopBroadcast')
                if deckOpen then updateDeckNUI() end
            end
        end

        if veh == 0 and lastVeh ~= 0 then
            -- Sorti du véhicule : stopper la diffusion
            insertedCassette = nil
            TriggerServerEvent('eightys_radio:server:stopBroadcast')
        end

        currentVeh = veh
        lastVeh    = veh
    end
end)

-- ================================================================
-- AUDIO AMBIANT — Son des voitures proches
-- ================================================================
CreateThread(function()
    while true do
        Wait(500)
        local ped       = PlayerPedId()
        local coords    = GetEntityCoords(ped)
        local maxDist   = Config.Radio.RadioMaxDist or 30.0
        local myId      = GetPlayerServerId(PlayerId())

        local bestVol   = 0.0
        local bestFile  = nil

        for pid, broadcast in pairs(nearbyBroadcasts) do
            -- Ne pas se jouer sa propre diffusion en ambiant
            if tonumber(pid) ~= myId then
                local veh = NetworkGetEntityFromNetworkId(broadcast.netId)
                if DoesEntityExist(veh) then
                    local dist = #(coords - GetEntityCoords(veh))
                    if dist < maxDist then
                        -- Falloff linéaire : plein volume à 0m, silence à maxDist
                        local falloff = 1.0 - (dist / maxDist)
                        local effVol  = broadcast.volume * falloff
                        if effVol > bestVol then
                            bestVol  = effVol
                            bestFile = broadcast.audioFile
                        end
                    end
                end
            end
        end

        if bestFile and bestVol > 0.02 then
            SendNUIMessage({ type = 'AMBIENT_PLAY', audioFile = bestFile, volume = bestVol })
        else
            SendNUIMessage({ type = 'AMBIENT_STOP' })
        end
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
        volume    = localVolume,
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

-- Régler le volume (appelé depuis le NUI)
RegisterNUICallback('setVolume', function(data, cb)
    local vol = tonumber(data.volume)
    if not vol then cb('err'); return end
    vol         = math.max(0.0, math.min(1.0, vol))
    localVolume = vol
    -- Appliquer immédiatement au lecteur local
    SendNUIMessage({ type = 'SET_VOLUME', volume = vol })
    -- Diffuser la mise à jour aux joueurs proches
    if insertedCassette and currentVeh ~= 0 then
        local netId = NetworkGetNetworkIdFromEntity(currentVeh)
        TriggerServerEvent('eightys_radio:server:updateBroadcast', netId, insertedCassette.audioFile, vol)
    end
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

    -- Couper la radio GTA
    if currentVeh ~= 0 then
        muteRadio(currentVeh)
        -- Démarrer la diffusion aux joueurs proches
        local netId = NetworkGetNetworkIdFromEntity(currentVeh)
        TriggerServerEvent('eightys_radio:server:updateBroadcast', netId, cassette.audioFile, localVolume)
    end

    updateDeckNUI()
    cb('ok')
end)

-- Éjecter la cassette (appelé depuis le NUI)
RegisterNUICallback('ejectCassette', function(_, cb)
    insertedCassette = nil
    if currentVeh ~= 0 then muteRadio(currentVeh) end
    TriggerServerEvent('eightys_radio:server:stopBroadcast')
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

    -- Demander l'état courant des diffusions
    TriggerServerEvent('eightys_radio:server:requestSync')

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
RegisterNetEvent('eightys_radio:client:syncBroadcasts', function(broadcasts)
    nearbyBroadcasts = broadcasts or {}
end)

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
