-- ================================================================
-- eightys_drugs — Server
-- Logique serveur : inventaire, économie, anti-exploit
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Cooldowns anti-spam (par joueur)
local cooldowns = {}
local COLLECT_CD  = 30    -- secondes entre chaque collecte
local PROCESS_CD  = drug and drug.processTime or 30
local SELL_CD     = 10

local function getCooldown(src, action)
    if not cooldowns[src] then cooldowns[src] = {} end
    return cooldowns[src][action]
end

local function setCooldown(src, action, seconds)
    if not cooldowns[src] then cooldowns[src] = {} end
    cooldowns[src][action] = os.time() + seconds
end

local function isOnCooldown(src, action)
    local cd = getCooldown(src, action)
    return cd and os.time() < cd
end

-- ================================================================
-- COLLECTE DE MATIÈRE PREMIÈRE
-- ================================================================
RegisterNetEvent('eightys_drugs:server:collectSupply', function(drugName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local drug = Config.Drugs[drugName]
    if not drug then return end

    -- Anti-spam
    if isOnCooldown(src, "collect_" .. drugName) then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Trop tôt",
            description = "Attendez avant de ramasser à nouveau.",
            type        = "error",
        })
        return
    end

    -- Vérifier l'espace dans l'inventaire (QBCore)
    local item = Player.Functions.GetItemByName(drug.rawItem)
    local currentQty = item and item.amount or 0

    if currentQty >= 20 then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Inventaire plein",
            description = "Vous ne pouvez pas porter plus de 20 " .. drug.rawItem:gsub("_", " "),
            type        = "error",
        })
        return
    end

    -- Ajouter l'item
    Player.Functions.AddItem(drug.rawItem, 1)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[drug.rawItem], "add")

    setCooldown(src, "collect_" .. drugName, COLLECT_CD)
    TriggerClientEvent('eightys_drugs:client:collectSuccess', src, drugName)

    -- Log
    print(string.format("[DRUGS] Collecte : joueur %d a récupéré 1x %s", src, drug.rawItem))
end)

-- ================================================================
-- TRAITEMENT EN LABORATOIRE
-- ================================================================
RegisterNetEvent('eightys_drugs:server:processDrug', function(drugName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local drug = Config.Drugs[drugName]
    if not drug then return end

    if isOnCooldown(src, "process_" .. drugName) then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "En cours",
            description = "Un traitement est déjà en cours.",
            type        = "error",
        })
        return
    end

    -- Vérifier que le joueur possède la matière première
    local rawItem = Player.Functions.GetItemByName(drug.rawItem)
    if not rawItem or rawItem.amount < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Manque de stock",
            description = string.format("Vous n'avez pas de %s.", drug.rawItem:gsub("_", " ")),
            type        = "error",
        })
        return
    end

    -- Transformer : retirer matière première, ajouter produit traité
    Player.Functions.RemoveItem(drug.rawItem, 1)
    Player.Functions.AddItem(drug.processedItem, 1)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[drug.processedItem], "add")

    setCooldown(src, "process_" .. drugName, drug.processTime + 5)
    TriggerClientEvent('eightys_drugs:client:processSuccess', src, drugName)

    print(string.format("[DRUGS] Labo : joueur %d a transformé 1x %s → 1x %s",
        src, drug.rawItem, drug.processedItem))
end)

-- ================================================================
-- VENTE DE DROGUE
-- ================================================================
RegisterNetEvent('eightys_drugs:server:sellDrug', function(drugName, qty)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local drug = Config.Drugs[drugName]
    if not drug then return end

    -- Validation quantité
    qty = math.max(1, math.min(50, math.floor(tonumber(qty) or 1)))

    if isOnCooldown(src, "sell_" .. drugName) then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Patience",
            description = "L'acheteur n'est pas encore prêt.",
            type        = "error",
        })
        return
    end

    -- Vérifier le stock
    local processedItem = Player.Functions.GetItemByName(drug.processedItem)
    if not processedItem or processedItem.amount < qty then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Stock insuffisant",
            description = string.format("Vous n'avez que %d %s.",
                processedItem and processedItem.amount or 0,
                drug.label),
            type        = "error",
        })
        return
    end

    -- Calculer le prix (variable selon le risque et la demande)
    local basePrice  = math.random(drug.sellPrice.min, drug.sellPrice.max)
    local totalEarned = basePrice * qty

    -- Retirer les drogues de l'inventaire
    Player.Functions.RemoveItem(drug.processedItem, qty)

    -- Payer en cash (argent sale, pas de virement)
    Player.Functions.AddMoney('cash', totalEarned, "vente-drogue-" .. drugName)

    -- Risque d'arrestation selon le niveau de risque
    local busted = false
    if drug.riskLevel >= 3 then
        local rollChance = math.random(1, 100)
        -- Plus de quantité = plus de risque
        local bustThreshold = drug.riskLevel * 3 + (qty * 2)
        if rollChance <= bustThreshold then
            busted = true
            -- Ajouter niveau de recherche
            TriggerClientEvent('eightys_drugs:client:busted', src, drugName)
        end
    end

    setCooldown(src, "sell_" .. drugName, SELL_CD)

    if not busted then
        TriggerClientEvent('eightys_drugs:client:sellSuccess', src, drugName, qty, totalEarned)
    end

    -- Log serveur
    print(string.format("[DRUGS] Vente : joueur %d vend %dx %s pour $%d (bust: %s)",
        src, qty, drug.label, totalEarned, tostring(busted)))

    -- Sauvegarder en base pour les stats
    MySQL.insert.await([[
        INSERT INTO drug_sales (player_id, drug_name, quantity, earned, timestamp)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE timestamp = NOW()
    ]], {
        Player.PlayerData.citizenid,
        drugName,
        qty,
        totalEarned,
    })
end)

-- ================================================================
-- USAGE DE DROGUE (consommation)
-- ================================================================
RegisterNetEvent('eightys_drugs:server:useDrug', function(drugName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local drug = Config.Drugs[drugName]
    if not drug then return end

    local processedItem = Player.Functions.GetItemByName(drug.processedItem)
    if not processedItem or processedItem.amount < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Rien à consommer",
            description = "Vous n'avez pas de " .. drug.label,
            type        = "error",
        })
        return
    end

    -- Retirer la dose
    Player.Functions.RemoveItem(drug.processedItem, 1)

    -- Déclencher les effets côté client
    TriggerClientEvent('eightys_drugs:client:drugEffect', src, drugName)

    print(string.format("[DRUGS] Usage : joueur %d consomme 1x %s", src, drug.label))
end)

-- ================================================================
-- NETTOYAGE AU DÉCONNECT
-- ================================================================
AddEventHandler('playerDropped', function()
    local src = source
    cooldowns[src] = nil
end)

-- ================================================================
-- INITIALISATION BASE DE DONNÉES
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS drug_sales (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            player_id  VARCHAR(50) NOT NULL,
            drug_name  VARCHAR(50) NOT NULL,
            quantity   INT NOT NULL DEFAULT 0,
            earned     INT NOT NULL DEFAULT 0,
            timestamp  DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_player (player_id),
            INDEX idx_drug   (drug_name)
        )
    ]])
    print("[eightys_drugs] Table drug_sales vérifiée/créée.")
end)
