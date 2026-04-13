-- ================================================================
-- eightys_gangs — Client
-- Système de gangs, territoires et guerres de rues
-- Los Angeles 1987
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Données locales
local myGang        = nil
local myGrade       = 0
local gangBlips     = {}
local territoryZones = {}

-- ================================================================
-- INITIALISATION DES DONNÉES DU JOUEUR
-- ================================================================
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.gang then
        myGang  = playerData.gang.name
        myGrade = playerData.gang.grade.level
    end
    setupGangBlips()
    setupTerritoryZones()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if val and val.gang then
        myGang  = val.gang.name
        myGrade = val.gang.grade and val.gang.grade.level or 0
    end
end)

-- ================================================================
-- BLIPS DES GANGS SUR LA CARTE
-- ================================================================
local function setupGangBlips()
    -- Supprimer les anciens blips
    for _, blip in ipairs(gangBlips) do
        RemoveBlip(blip)
    end
    gangBlips = {}

    for gangName, gang in pairs(Config.Gangs) do
        -- Blip du quartier général (premier spawn)
        if gang.spawns and gang.spawns[1] then
            local sp = gang.spawns[1]
            local blip = AddBlipForCoord(sp.x, sp.y, sp.z)
            SetBlipSprite(blip,  gang.blip.sprite)
            SetBlipScale(blip,   gang.blip.scale)
            SetBlipColour(blip,  gang.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(gang.label)
            EndTextCommandSetBlipName(blip)
            table.insert(gangBlips, blip)
        end
    end
end

-- ================================================================
-- ZONES DE TERRITOIRE
-- ================================================================
local territoryData = {}   -- { gangName, points } chargé du serveur

local function setupTerritoryZones()
    TriggerServerEvent('eightys_gangs:server:requestTerritories')
end

RegisterNetEvent('eightys_gangs:client:receiveTerritories', function(data)
    territoryData = data
    -- Redessiner les blips de territoire
    for _, zone in ipairs(territoryData) do
        local gang = Config.Gangs[zone.gang]
        if gang then
            local blip = AddBlipForCoord(zone.x, zone.y, zone.z)
            SetBlipSprite(blip, 9)
            SetBlipScale(blip, 1.2)
            SetBlipColour(blip, gang.blip.color)
            SetBlipAsShortRange(blip, false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("[TURF] " .. gang.label .. " (" .. zone.points .. " pts)")
            EndTextCommandSetBlipName(blip)
            table.insert(gangBlips, blip)
        end
    end
end)

-- ================================================================
-- TEXTE 3D
-- ================================================================
local function drawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 220, 50, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = string.len(text) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- ================================================================
-- INTERACTION AVEC LES SPAWN POINTS DU GANG
-- ================================================================
local function handleGangSpawnZones()
    if not myGang then return end
    local gang = Config.Gangs[myGang]
    if not gang then return end

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for _, spawnCoord in ipairs(gang.spawns) do
        local dist = #(coords - vector3(spawnCoord.x, spawnCoord.y, spawnCoord.z))
        if dist < 3.0 then
            drawText3D(spawnCoord.x, spawnCoord.y, spawnCoord.z + 1.0,
                "[E] Menu Gang — " .. gang.label)

            if IsControlJustReleased(0, 38) then
                openGangMenu()
            end
        end
    end
end

-- ================================================================
-- MENU GANG
-- ================================================================
local function openGangMenu()
    if not myGang then
        lib.notify({
            title       = "Sans affiliation",
            description = "Vous n'êtes membre d'aucun gang.",
            type        = "error",
        })
        return
    end

    local gang = Config.Gangs[myGang]
    if not gang then return end

    local options = {
        {
            title    = "Membres en ligne",
            icon     = "users",
            onSelect = function()
                TriggerServerEvent('eightys_gangs:server:getOnlineMembers')
            end,
        },
        {
            title    = "Territoires contrôlés",
            icon     = "map",
            onSelect = function()
                TriggerServerEvent('eightys_gangs:server:getTerritoryInfo', myGang)
            end,
        },
        {
            title    = "Déposer de l'argent dans le coffre",
            icon     = "sack-dollar",
            onSelect = function()
                local input = lib.inputDialog("Coffre du gang", {
                    { type = "number", label = "Montant ($)", min = 1, max = 10000 },
                })
                if input and input[1] then
                    TriggerServerEvent('eightys_gangs:server:depositGangStash', input[1])
                end
            end,
        },
        {
            title    = "Retirer de l'argent du coffre",
            icon     = "hand-holding-dollar",
            description = myGrade >= 2 and "Réservé aux Sergents+" or "Accès refusé (grade insuffisant)",
            disabled = myGrade < 2,
            onSelect = function()
                if myGrade < 2 then return end
                local input = lib.inputDialog("Retrait coffre", {
                    { type = "number", label = "Montant ($)", min = 1, max = 5000 },
                })
                if input and input[1] then
                    TriggerServerEvent('eightys_gangs:server:withdrawGangStash', input[1])
                end
            end,
        },
        {
            title    = "Recruter un joueur",
            icon     = "user-plus",
            description = myGrade >= 3 and "Réservé aux Lieutenants+" or "Accès refusé",
            disabled = myGrade < 3,
            onSelect = function()
                if myGrade < 3 then return end
                local input = lib.inputDialog("Recruter", {
                    { type = "number", label = "ID du joueur à recruter" },
                })
                if input and input[1] then
                    TriggerServerEvent('eightys_gangs:server:recruitPlayer', input[1])
                end
            end,
        },
        {
            title    = "Quitter le gang",
            icon     = "door-open",
            description = "⚠ Action irréversible",
            onSelect = function()
                local confirm = lib.alertDialog({
                    header  = "Quitter " .. gang.label .. " ?",
                    content = "Vous perdrez tous vos avantages de gang. Êtes-vous sûr ?",
                    centered = true,
                    cancel  = true,
                })
                if confirm == "confirm" then
                    TriggerServerEvent('eightys_gangs:server:leaveGang')
                end
            end,
        },
    }

    lib.registerContext({
        id      = "gang_menu",
        title   = gang.label .. " — Grade : " .. (gang.grades[myGrade] and gang.grades[myGrade].label or "Inconnu"),
        options = options,
    })
    lib.showContext("gang_menu")
end

-- ================================================================
-- GUERRE DE TERRITOIRE (notification)
-- ================================================================
RegisterNetEvent('eightys_gangs:client:warStarted', function(attackerGang, defenderGang, zoneName)
    local attacker = Config.Gangs[attackerGang]
    local defender = Config.Gangs[defenderGang]
    if attacker and defender then
        lib.notify({
            title       = "⚔ Guerre de territoire !",
            description = string.format("%s attaque %s à %s !", attacker.label, defender.label, zoneName),
            type        = "error",
            duration    = 10000,
            position    = "top",
        })
    end
end)

RegisterNetEvent('eightys_gangs:client:territoryTaken', function(gangName, zoneName)
    local gang = Config.Gangs[gangName]
    if gang then
        lib.notify({
            title       = "Territoire capturé",
            description = string.format("%s contrôle maintenant %s !", gang.label, zoneName),
            type        = "success",
            duration    = 8000,
            position    = "top",
        })
        TriggerServerEvent('eightys_gangs:server:requestTerritories')  -- Rafraîchir
    end
end)

-- ================================================================
-- NOTIFICATIONS MEMBRES EN LIGNE
-- ================================================================
RegisterNetEvent('eightys_gangs:client:onlineMembers', function(members, gangName)
    local gang = Config.Gangs[gangName]
    if not gang or not members then return end

    local options = {}
    for _, m in ipairs(members) do
        table.insert(options, {
            title = string.format("[ID:%d] %s — %s",
                m.serverId, m.name,
                gang.grades[m.grade] and gang.grades[m.grade].label or "Inconnu"),
            icon  = "user",
        })
    end

    if #options == 0 then
        lib.notify({ title = "Gang vide", description = "Aucun membre en ligne.", type = "inform" })
        return
    end

    lib.registerContext({
        id      = "gang_members",
        title   = gang.label .. " — Membres en ligne (" .. #options .. ")",
        options = options,
    })
    lib.showContext("gang_members")
end)

-- ================================================================
-- THREAD PRINCIPAL
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end

    -- Init données joueur
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.gang then
        myGang  = playerData.gang.name
        myGrade = playerData.gang.grade and playerData.gang.grade.level or 0
    end

    setupGangBlips()
    setupTerritoryZones()
end)

CreateThread(function()
    while true do
        local sleep = 2000

        if myGang then
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local gang   = Config.Gangs[myGang]

            if gang then
                for _, sp in ipairs(gang.spawns) do
                    if #(coords - vector3(sp.x, sp.y, sp.z)) < 30.0 then
                        sleep = 0
                        break
                    end
                end
            end
        end

        handleGangSpawnZones()
        Wait(sleep)
    end
end)
