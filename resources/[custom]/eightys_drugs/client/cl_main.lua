-- ================================================================
-- eightys_drugs — Client
-- Système de drogues complet : collecte → labo → vente
-- Los Angeles 1987 : crack, cocaïne, weed, PCP
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Blips sur la carte
local blips = {}

-- ================================================================
-- CRÉATION DES BLIPS
-- ================================================================
local function createDrugBlips()
    for drugName, drug in pairs(Config.Drugs) do
        -- Blip d'approvisionnement (supply)
        local supplyBlip = AddBlipForCoord(drug.supplyCoords.x, drug.supplyCoords.y, drug.supplyCoords.z)
        SetBlipSprite(supplyBlip, 140)
        SetBlipScale(supplyBlip, 0.7)
        SetBlipColour(supplyBlip, 5)
        SetBlipAsShortRange(supplyBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("[Supply] " .. drug.label)
        EndTextCommandSetBlipName(supplyBlip)
        table.insert(blips, supplyBlip)

        -- Blip du laboratoire
        local labBlip = AddBlipForCoord(drug.labCoords.x, drug.labCoords.y, drug.labCoords.z)
        SetBlipSprite(labBlip, 311)
        SetBlipScale(labBlip, 0.7)
        SetBlipColour(labBlip, 1)
        SetBlipAsShortRange(labBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("[Labo] " .. drug.label)
        EndTextCommandSetBlipName(labBlip)
        table.insert(blips, labBlip)

        -- Blips de vente
        for _, sellCoord in ipairs(drug.sellCoords) do
            local sellBlip = AddBlipForCoord(sellCoord.x, sellCoord.y, sellCoord.z)
            SetBlipSprite(sellBlip, 75)
            SetBlipScale(sellBlip, 0.6)
            SetBlipColour(sellBlip, 46)
            SetBlipAsShortRange(sellBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("[Vente] " .. drug.label)
            EndTextCommandSetBlipName(sellBlip)
            table.insert(blips, sellBlip)
        end
    end
end

-- ================================================================
-- TEXTE 3D HELPER
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

        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- ================================================================
-- COLLECTE DE MATIÈRE PREMIÈRE (Supply)
-- ================================================================
local isCollecting = false

local function handleSupplyZone(drugName, drug)
    local ped    = PlayerPedId()
    local coords = drug.supplyCoords
    local dist   = #(GetEntityCoords(ped) - coords)

    if dist < 2.0 then
        drawText3D(coords.x, coords.y, coords.z + 1.0,
            "[E] Ramasser " .. drug.rawItem:gsub("_", " ") .. " (×1)")

        if IsControlJustReleased(0, 38) and not isCollecting then -- E
            isCollecting = true

            lib.progressBar({
                duration = 5000,
                label    = "Ramassage de matière première...",
                useWhileDead  = false,
                canCancel     = true,
                disable = { car = true, combat = true },
                anim = {
                    dict   = "amb@prop_human_parking_meter@male@idle_a",
                    clip   = "idle_a",
                },
            }, function(cancelled)
                isCollecting = false
                if not cancelled then
                    TriggerServerEvent('eightys_drugs:server:collectSupply', drugName)
                end
            end)
        end
    end
end

-- ================================================================
-- TRAITEMENT EN LABORATOIRE (Lab)
-- ================================================================
local isProcessing = false

local function handleLabZone(drugName, drug)
    local ped    = PlayerPedId()
    local coords = drug.labCoords
    local dist   = #(GetEntityCoords(ped) - coords)

    if dist < 2.5 then
        drawText3D(coords.x, coords.y, coords.z + 1.0,
            "[E] Transformer " .. drug.label .. " (×1)")

        if IsControlJustReleased(0, 38) and not isProcessing then
            isProcessing = true

            lib.progressBar({
                duration = drug.processTime * 1000,
                label    = "Traitement en cours : " .. drug.label .. "...",
                useWhileDead  = false,
                canCancel     = true,
                disable = { car = true, combat = true, move = false },
                anim = {
                    dict   = "anim@heists@prison_heiststation@cop_reactions",
                    clip   = "cop_b_idle",
                },
            }, function(cancelled)
                isProcessing = false
                if not cancelled then
                    TriggerServerEvent('eightys_drugs:server:processDrug', drugName)
                end
            end)
        end
    end
end

-- ================================================================
-- VENTE DE DROGUE (Sell)
-- ================================================================
local isSelling = false

local function handleSellZone(drugName, drug, sellCoord)
    local ped  = PlayerPedId()
    local dist = #(GetEntityCoords(ped) - sellCoord)

    if dist < 2.0 then
        drawText3D(sellCoord.x, sellCoord.y, sellCoord.z + 1.0,
            "[E] Vendre " .. drug.label)

        if IsControlJustReleased(0, 38) and not isSelling then
            isSelling = true

            -- Demander la quantité via ox_lib
            local input = lib.inputDialog("Vente de " .. drug.label, {
                { type = "number", label = "Quantité à vendre", default = 1, min = 1, max = 50 },
            })

            if input and input[1] and input[1] > 0 then
                lib.progressBar({
                    duration = 3000,
                    label    = "Transaction en cours...",
                    useWhileDead  = false,
                    canCancel     = false,
                    disable = { car = true, combat = true },
                    anim = {
                        dict  = "mp_common",
                        clip  = "givetake1_a",
                    },
                }, function(cancelled)
                    isSelling = false
                    if not cancelled then
                        TriggerServerEvent('eightys_drugs:server:sellDrug', drugName, input[1])
                    end
                end)
            else
                isSelling = false
            end
        end
    end
end

-- ================================================================
-- EFFETS DE DROGUE (après consommation)
-- ================================================================
local activeEffects = {}

local function applyDrugEffects(drugName)
    local drug = Config.Drugs[drugName]
    if not drug or not drug.effects then return end

    local ped = PlayerPedId()

    -- Boost de vitesse de déplacement
    if drug.effects.speedBoost and drug.effects.speedBoost ~= 1.0 then
        SetPedMoveRateOverride(ped, drug.effects.speedBoost)
    end

    -- Stamina infinie
    if drug.effects.staminaBoost then
        ResetPlayerStamina(PlayerId())
    end

    -- Effet visuel (post-processing)
    if drugName == "crack" or drugName == "pcp" then
        AnimpostfxPlay("Rampage", 0, true)
    elseif drugName == "cocaine" then
        AnimpostfxPlay("HeistCelebPass", 0, false)
    elseif drugName == "weed" then
        AnimpostfxPlay("SwitchOpenMichaelInOut", 0, false)
    end

    -- Timer de fin d'effet
    activeEffects[drugName] = true
    CreateThread(function()
        local endTime = GetGameTimer() + (drug.effects.duration * 1000)
        while GetGameTimer() < endTime do
            Wait(1000)
            -- Drain de santé progressif
            if drug.effects.healthDrain and drug.effects.healthDrain > 0 then
                local currentHp = GetEntityHealth(ped)
                SetEntityHealth(ped, math.max(100, currentHp - drug.effects.healthDrain))
            end
            -- Continuer la stamina
            if drug.effects.staminaBoost then
                ResetPlayerStamina(PlayerId())
            end
        end

        -- Fin des effets
        SetPedMoveRateOverride(ped, 1.0)
        AnimpostfxStopAll()
        activeEffects[drugName] = nil

        lib.notify({
            title       = "Effet terminé",
            description = "L'effet de " .. drug.label .. " s'estompe...",
            type        = "inform",
            duration    = 5000,
        })
    end)
end

-- ================================================================
-- THREAD PRINCIPAL — Détection zones
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end
    createDrugBlips()
end)

CreateThread(function()
    while true do
        local sleep = 2000

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for drugName, drug in pairs(Config.Drugs) do
            -- Zone supply
            if #(coords - drug.supplyCoords) < 30.0 then
                sleep = 0
                handleSupplyZone(drugName, drug)
            end

            -- Zone labo
            if #(coords - drug.labCoords) < 30.0 then
                sleep = 0
                handleLabZone(drugName, drug)
            end

            -- Zones de vente
            for _, sellCoord in ipairs(drug.sellCoords) do
                if #(coords - sellCoord) < 30.0 then
                    sleep = 0
                    handleSellZone(drugName, drug, sellCoord)
                end
            end
        end

        Wait(sleep)
    end
end)

-- ================================================================
-- EVENTS SERVEUR → CLIENT
-- ================================================================
RegisterNetEvent('eightys_drugs:client:drugEffect', function(drugName)
    applyDrugEffects(drugName)
end)

RegisterNetEvent('eightys_drugs:client:collectSuccess', function(drugName)
    local drug = Config.Drugs[drugName]
    if drug then
        lib.notify({
            title       = "Approvisionnement",
            description = "Vous avez récupéré : " .. drug.rawItem:gsub("_", " "),
            type        = "success",
            duration    = 3000,
        })
    end
end)

RegisterNetEvent('eightys_drugs:client:processSuccess', function(drugName)
    local drug = Config.Drugs[drugName]
    if drug then
        lib.notify({
            title       = "Labo",
            description = drug.label .. " prête à la vente.",
            type        = "success",
            duration    = 3000,
        })
    end
end)

RegisterNetEvent('eightys_drugs:client:sellSuccess', function(drugName, qty, earned)
    local drug = Config.Drugs[drugName]
    if drug then
        lib.notify({
            title       = "Vente",
            description = string.format("Vendu %dx %s pour $%d", qty, drug.label, earned),
            type        = "success",
            duration    = 5000,
        })
    end
end)
