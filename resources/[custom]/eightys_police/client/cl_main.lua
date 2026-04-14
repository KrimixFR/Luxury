-- ================================================================
-- eightys_police — Client
-- LAPD & Vice Squad — Los Angeles 1987
-- Toutes les interactions via menu ALT (plus de commandes texte)
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local isPolice    = false
local isViceSquad = false
local isCuffed    = false
local radarActive = false
local menuOpen    = false   -- verrou pour éviter les doubles ouvertures

-- ================================================================
-- JOB — Suivi en temps réel
-- ================================================================
local function refreshJob()
    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.job then
        isPolice    = pd.job.name == "police"
        isViceSquad = pd.job.name == "vicesquad"
    end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    refreshJob()
    setupPoliceBlips()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    isPolice    = job.name == "police"
    isViceSquad = job.name == "vicesquad"
end)

-- ================================================================
-- BLIPS
-- ================================================================
local function setupPoliceBlips()
    for _, loc in ipairs(Config.Police.Locations) do
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, loc.blip.sprite)
        SetBlipScale(blip, loc.blip.scale)
        SetBlipColour(blip, loc.blip.color)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(loc.blip.label)
        EndTextCommandSetBlipName(blip)
    end
end

-- ================================================================
-- TEXTE 3D — indicateur visuel sur les zones
-- ================================================================
local function drawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(100, 180, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)
    DrawRect(sx, sy + 0.0125, 0.015 + string.len(text) / 370, 0.03, 0, 0, 0, 75)
end

-- ================================================================
-- ANIMATIONS — Helpers
-- ================================================================
local function loadAnim(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        t = t + 10
        if t >= 3000 then break end
    end
end

-- Flic : geste menottage (tend les mains en avant, 2.2s)
local function playCuffAnim(ped)
    loadAnim("mp_arresting")
    TaskPlayAnim(ped, "mp_arresting", "a_uncuff", 4.0, -4.0, 2200, 0, 0, false, false, false)
end

-- Cible : mains levées → mains dans le dos
local function playBeingCuffedAnim(ped)
    loadAnim("random@arrests")
    if HasAnimDictLoaded("random@arrests") then
        TaskPlayAnim(ped, "random@arrests", "idle_2_hands_up", 8.0, -8.0, 1200, 0, 0, false, false, false)
        Wait(1200)
    end
    loadAnim("mp_arresting")
    SetEnableHandcuffs(ped, true)
    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
end

-- ================================================================
-- THREAD — Blocage des contrôles quand menotté
-- ================================================================
CreateThread(function()
    while true do
        if isCuffed then
            DisableControlAction(0, 24, true)  -- Attaque
            DisableControlAction(0, 25, true)  -- Corps à corps
            DisableControlAction(0, 47, true)  -- Arme
            DisableControlAction(0, 58, true)  -- Snipe
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 37, true)  -- Enter vehicle
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ================================================================
-- EVENTS REÇUS DU SERVEUR
-- ================================================================
RegisterNetEvent('eightys_police:client:cuffPlayer', function()
    isCuffed = true
    CreateThread(function() playBeingCuffedAnim(PlayerPedId()) end)
    lib.notify({ title = "Menottes", description = "Vous êtes menottés. Restez calme.", type = "error", duration = 5000 })
end)

RegisterNetEvent('eightys_police:client:uncuffPlayer', function()
    isCuffed = false
    local ped = PlayerPedId()
    SetEnableHandcuffs(ped, false)
    StopAnimTask(ped, "mp_arresting", "idle", 1.0)
    ClearPedTasks(ped)
    lib.notify({ title = "Libéré", description = "Vous avez été libéré des menottes.", type = "success", duration = 3000 })
end)

RegisterNetEvent('eightys_police:client:sendToJail', function(sentence)
    local ped        = PlayerPedId()
    local jailCoords = Config.Police.JailLocation
    isCuffed = false
    SetEnableHandcuffs(ped, false)
    SetEntityCoords(ped, jailCoords.x, jailCoords.y, jailCoords.z, false, false, false, true)
    SetEntityHeading(ped, jailCoords.w)
    lib.notify({
        title       = "Arrêté",
        description = string.format("Pénitencier — %d minute(s).", math.floor(sentence / 60)),
        type        = "error", duration = 8000,
    })
    CreateThread(function()
        Wait(sentence * 1000)
        local rel = Config.Police.Locations[1].coords
        SetEntityCoords(ped, rel.x, rel.y, rel.z, false, false, false, true)
        lib.notify({ title = "Libéré", description = "Peine purgée. Bonne conduite.", type = "success", duration = 5000 })
    end)
end)

-- ================================================================
-- MENU ALT — Sous-menu joueur (avec état menottes depuis serveur)
-- ================================================================
local function openPlayerActions(player)
    -- Récupérer l'état menottes depuis le serveur avant d'afficher le menu
    QBCore.Functions.TriggerCallback('eightys_police:getCuffState', function(isTargetCuffed)
        local ped     = PlayerPedId()
        local actions = {}

        -- ---- Menotter / Démenotter ----
        if isTargetCuffed then
            table.insert(actions, {
                title       = "Retirer les menottes",
                icon        = "unlock",
                description = "Libérer le suspect",
                onSelect    = function()
                    CreateThread(function()
                        playCuffAnim(ped)
                        Wait(2200)
                        TriggerServerEvent('eightys_police:server:toggleCuff', player.srvId)
                        menuOpen = false
                    end)
                end,
            })
        else
            table.insert(actions, {
                title       = "Menotter",
                icon        = "link",
                description = "Passer les menottes au suspect",
                onSelect    = function()
                    CreateThread(function()
                        -- Orienter le flic vers la cible
                        local tc = GetEntityCoords(GetPlayerPed(player.localId))
                        TaskTurnPedToFaceCoord(ped, tc.x, tc.y, tc.z, 800)
                        Wait(800)
                        playCuffAnim(ped)
                        Wait(2200)
                        TriggerServerEvent('eightys_police:server:toggleCuff', player.srvId)
                        menuOpen = false
                    end)
                end,
            })
        end

        -- ---- Arrêter ----
        table.insert(actions, {
            title       = "Arrêter",
            icon        = "gavel",
            description = "Envoyer au pénitencier",
            onSelect    = function()
                local input = lib.inputDialog("Emprisonnement de " .. player.name, {
                    { type = "number", label = "Durée (minutes)", min = 1, max = 30, default = 5 },
                })
                if input and input[1] then
                    TriggerServerEvent('eightys_police:server:arrestPlayer', player.srvId, input[1] * 60)
                end
                menuOpen = false
            end,
        })

        -- ---- Fouiller ----
        table.insert(actions, {
            title       = "Fouiller",
            icon        = "magnifying-glass",
            description = "Chercher des objets illégaux sur le suspect",
            onSelect    = function()
                CreateThread(function()
                    lib.progressBar({
                        duration     = 3000,
                        label        = "Fouille de " .. player.name .. "...",
                        useWhileDead = false,
                        canCancel    = false,
                        disable      = { car = true, combat = true },
                        anim         = { dict = "anim@narcotics@trash_search", clip = "trashsearch_litter_idle" },
                    }, function(cancelled)
                        if not cancelled then
                            TriggerServerEvent('eightys_police:server:searchPlayer', player.srvId)
                        end
                    end)
                    menuOpen = false
                end)
            end,
        })

        lib.registerContext({
            id      = 'police_player_actions',
            title   = string.format('%s  [%.1f m]', player.name, player.dist),
            options = actions,
        })
        lib.showContext('police_player_actions')
    end, player.srvId)
end

-- ================================================================
-- MENU ALT — Menu principal police
-- ================================================================
local function openPoliceMenu()
    if menuOpen then return end
    menuOpen = true

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local options = {}

    -- ---- Section joueurs proches ----
    local nearby = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local tPed = GetPlayerPed(pid)
            local dist = #(coords - GetEntityCoords(tPed))
            if dist <= 15.0 then
                table.insert(nearby, {
                    localId = pid,
                    srvId   = GetPlayerServerId(pid),
                    name    = GetPlayerName(pid),
                    dist    = dist,
                })
            end
        end
    end

    -- Trier par distance croissante
    table.sort(nearby, function(a, b) return a.dist < b.dist end)

    if #nearby > 0 then
        for _, p in ipairs(nearby) do
            local captured = p  -- capture de la variable pour la closure
            table.insert(options, {
                title       = captured.name,
                icon        = 'user',
                description = string.format('%.1f m', captured.dist),
                onSelect    = function()
                    openPlayerActions(captured)
                end,
            })
        end
    else
        table.insert(options, {
            title    = 'Aucun suspect à proximité',
            icon     = 'circle-info',
            disabled = true,
        })
    end

    -- ---- Séparateur — Actions personnelles ----
    table.insert(options, { title = '── Actions officier ──', disabled = true })

    -- Armurerie
    local atStation = false
    for _, loc in ipairs(Config.Police.Locations) do
        if #(coords - vector3(loc.coords.x, loc.coords.y, loc.coords.z)) < 15.0 then
            atStation = true
            break
        end
    end
    table.insert(options, {
        title       = 'Armurerie',
        icon        = 'gun',
        description = atStation and 'Récupérer l\'équipement' or 'Réservé au commissariat',
        disabled    = not atStation,
        onSelect    = function()
            TriggerServerEvent('eightys_police:server:openArmory')
            menuOpen = false
        end,
    })

    -- Collecte de preuves
    table.insert(options, {
        title    = 'Ramasser des preuves',
        icon     = 'bag-shopping',
        onSelect = function()
            menuOpen = false
            CreateThread(function()
                lib.progressBar({
                    duration     = 3000,
                    label        = 'Collecte de preuves...',
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { car = true, combat = true },
                    anim         = { dict = 'anim@narcotics@trash_search', clip = 'trashsearch_litter_idle' },
                }, function(cancelled)
                    if not cancelled then TriggerServerEvent('eightys_police:server:collectEvidence') end
                end)
            end)
        end,
    })

    -- Radar vitesse
    table.insert(options, {
        title       = radarActive and 'Radar — Désactiver' or 'Radar — Activer',
        icon        = radarActive and 'circle-stop' or 'satellite-dish',
        description = 'Surveiller les excès de vitesse',
        onSelect    = function()
            radarActive = not radarActive
            lib.notify({
                title       = radarActive and 'Radar activé' or 'Radar désactivé',
                description = radarActive and 'Surveillance des vitesses active.' or '',
                type        = 'inform',
            })
            menuOpen = false
        end,
    })

    lib.registerContext({
        id      = 'police_main_menu',
        title   = 'Interaction Police',
        options = options,
    })
    lib.showContext('police_main_menu')
end

-- ================================================================
-- TOUCHE ALT — Ouverture du menu
-- ================================================================
RegisterCommand('police_interaction', function()
    if not isPolice and not isViceSquad then return end
    openPoliceMenu()
end, false)

RegisterKeyMapping('police_interaction', 'Menu d\'interaction Police', 'keyboard', 'LMENU')

-- Reset du verrou si le NUI se ferme sans sélection
RegisterNUICallback('contextMenuClosed', function(_, cb)
    menuOpen = false
    cb('ok')
end)

-- ================================================================
-- RADAR — Thread de surveillance (indépendant du menu)
-- ================================================================
CreateThread(function()
    while true do
        Wait(2000)
        if not radarActive or (not isPolice and not isViceSquad) then goto continue end

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, pid in ipairs(GetActivePlayers()) do
            if pid ~= PlayerId() then
                local tPed = GetPlayerPed(pid)
                local veh  = GetVehiclePedIsIn(tPed, false)
                if veh ~= 0 and #(coords - GetEntityCoords(tPed)) < 80.0 then
                    local speed = GetEntitySpeed(veh) * 2.237
                    if speed > 80 then
                        lib.notify({
                            title       = 'EXCÈS DE VITESSE',
                            description = string.format('ID %d — %.0f MPH', GetPlayerServerId(pid), speed),
                            type        = 'error',
                            duration    = 4000,
                        })
                    end
                end
            end
        end

        ::continue::
    end
end)

-- ================================================================
-- 3D TEXT — Indicateur zone commissariat
-- ================================================================
CreateThread(function()
    while true do
        local sleep = 2000

        if isPolice or isViceSquad then
            local coords = GetEntityCoords(PlayerPedId())
            for _, loc in ipairs(Config.Police.Locations) do
                if #(coords - vector3(loc.coords.x, loc.coords.y, loc.coords.z)) < 30.0 then
                    sleep = 0
                    drawText3D(loc.coords.x, loc.coords.y, loc.coords.z + 1.0,
                        '[ALT] Menu Police')
                end
            end
        end

        Wait(sleep)
    end
end)
