-- ================================================================
-- qb-spawn — Client
-- Spawn du joueur après sélection de personnage
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Point de spawn par défaut (devant LAPD)
local DEFAULT_SPAWN = vector4(441.9, -982.2, 30.7, 355.0)

-- ================================================================
-- SPAWNER LE JOUEUR
-- ================================================================
local function spawnPlayer(coords, heading, cb)
    DoScreenFadeOut(500)
    Wait(500)

    local ped = PlayerPedId()

    -- Désactiver le ragdoll temporairement
    SetPedCanRagdoll(ped, false)
    SetEntityVisible(ped, true, false)

    -- Téléporter
    local x = coords.x or coords[1] or DEFAULT_SPAWN.x
    local y = coords.y or coords[2] or DEFAULT_SPAWN.y
    local z = coords.z or coords[3] or DEFAULT_SPAWN.z
    local h = heading or coords.w or DEFAULT_SPAWN.w

    NetworkResurrectLocalPlayer(x, y, z, h, true, true)
    SetEntityCoords(ped, x, y, z, false, false, false, true)
    SetEntityHeading(ped, h)

    Wait(500)

    -- Réactiver
    SetPedCanRagdoll(ped, true)
    SetEntityVisible(ped, true, false)

    -- Fade in
    DoScreenFadeIn(1000)

    if cb then cb() end
end

-- ================================================================
-- ÉVÉNEMENTS
-- ================================================================
RegisterNetEvent('QBCore:Client:SpawnPlayer', function(coords, heading)
    spawnPlayer(coords or DEFAULT_SPAWN, heading)
    -- Notifier le framework que le joueur est prêt
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
end)

-- Au premier chargement : spawn auto
RegisterNetEvent('playerSpawned', function()
    -- Appelé par FiveM spawnmanager
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)

    -- Attendre que qb-multicharacter choisisse un spawn
    -- Si pas de multicharacter, spawn au point par défaut
    Wait(2000)
    if not LocalPlayer.state.isLoggedIn then
        spawnPlayer(DEFAULT_SPAWN, DEFAULT_SPAWN.w, function()
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        end)
    end
end)
