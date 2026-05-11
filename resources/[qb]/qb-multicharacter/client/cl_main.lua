-- ================================================================
-- qb-multicharacter — Client
-- Écran de création / sélection de personnage Los Santos 1987
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local CHAR_CAM_COORDS = vector3(441.9, -982.2, 32.0)
local charCam = nil
local nuiOpen = false

-- ================================================================
-- CAMÉRA CINÉMATIQUE À LA CONNEXION
-- ================================================================
local function setupCamera()
    DoScreenFadeOut(0)
    Wait(500)

    -- Cacher le HUD et le ped
    DisplayHud(false)
    DisplayRadar(false)

    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)

    -- Créer une caméra cinématique
    charCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(charCam, CHAR_CAM_COORDS.x, CHAR_CAM_COORDS.y, CHAR_CAM_COORDS.z + 3.0)
    SetCamRot(charCam, -10.0, 0.0, 95.0, 2)
    SetCamFov(charCam, 50.0)
    RenderScriptCams(true, false, 0, true, true)

    -- Afficher l'UI
    Wait(1000)
    DoScreenFadeIn(800)
    Wait(800)

    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({ type = 'OPEN' })
end

-- ================================================================
-- FINALISER LE SPAWN APRÈS SÉLECTION
-- ================================================================
local function finalizeSpawn(charData)
    SetNuiFocus(false, false)
    nuiOpen = false

    DoScreenFadeOut(500)
    Wait(500)

    -- Détruire la caméra
    if charCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(charCam, false)
        charCam = nil
    end

    -- Réafficher le ped
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)

    -- Téléporter au spawn
    local spawnCoords = Config and Config.DefaultSpawn or vector4(441.9, -982.2, 30.7, 355.0)
    NetworkResurrectLocalPlayer(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, true)
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z)
    SetEntityHeading(ped, spawnCoords.w)

    Wait(500)

    -- Réactiver HUD
    DisplayHud(true)
    DisplayRadar(true)

    DoScreenFadeIn(800)

    -- Notifier le serveur que le joueur est chargé
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
end

-- ================================================================
-- NUI CALLBACKS
-- ================================================================
RegisterNUICallback('createChar', function(data, cb)
    if data and data.firstname and data.lastname then
        TriggerServerEvent('qb-multicharacter:server:createChar', {
            firstname = tostring(data.firstname),
            lastname  = tostring(data.lastname),
            birthdate = tostring(data.birthdate or '01/01/1960'),
            gender    = tonumber(data.gender) or 0,
        })
    end
    cb('ok')
end)

RegisterNUICallback('selectChar', function(data, cb)
    cb('ok')
    finalizeSpawn(data)
end)

RegisterNUICallback('cancelChar', function(_, cb)
    cb('ok')
    -- Rester sur l'écran de sélection
    SendNUIMessage({ type = 'OPEN' })
end)

-- ================================================================
-- ÉVÉNEMENTS SERVEUR → CLIENT
-- ================================================================
RegisterNetEvent('qb-multicharacter:client:showChars', function(chars)
    SendNUIMessage({ type = 'SHOW_CHARS', chars = chars })
end)

RegisterNetEvent('qb-multicharacter:client:charCreated', function()
    -- Personnage créé, spawner directement
    finalizeSpawn({})
end)

-- ================================================================
-- LANCEMENT AU SPAWN
-- ================================================================
AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(1000)
        if not LocalPlayer.state.isLoggedIn then
            setupCamera()
            -- Demander les personnages existants
            TriggerServerEvent('qb-multicharacter:server:getChars')
        end
    end)
end)
