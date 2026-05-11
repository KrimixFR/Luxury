-- ================================================================
-- eightys_economy — Server
-- Prix des drogues dynamiques selon l'offre et la demande
-- Reset toutes les heures — export getDrugPrice() pour eightys_drugs
-- ================================================================

-- ================================================================
-- DB INIT
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS drug_market (
            drug        VARCHAR(30) NOT NULL PRIMARY KEY,
            sales_count INT         NOT NULL DEFAULT 0,
            multiplier  FLOAT       NOT NULL DEFAULT 1.0,
            last_reset  BIGINT      NOT NULL DEFAULT 0,
            drought     BOOLEAN     NOT NULL DEFAULT FALSE
        )
    ]])

    -- Initialiser les drogues manquantes
    for drugName, _ in pairs(Config.Drugs or {}) do
        MySQL.insert.await(
            'INSERT IGNORE INTO drug_market (drug, last_reset) VALUES (?, ?)',
            { drugName, os.time() }
        )
    end

    print('[eightys_economy] Marché des drogues initialisé.')
end)

-- ================================================================
-- CACHE EN MÉMOIRE (évite des requêtes DB à chaque vente)
-- ================================================================
local marketCache = {}

local function loadCache()
    local rows = MySQL.query.await('SELECT * FROM drug_market')
    for _, row in ipairs(rows or {}) do
        marketCache[row.drug] = {
            sales_count = row.sales_count,
            multiplier  = row.multiplier,
            drought     = row.drought == 1 or row.drought == true,
            last_reset  = row.last_reset,
        }
    end
end

CreateThread(function()
    Wait(3000) -- attendre la DB init
    loadCache()
end)

-- ================================================================
-- EXPORT — Obtenir le prix actuel d'une drogue
-- Retourne un prix dans [min, max] ajusté par le multiplicateur
-- ================================================================
exports('getDrugPrice', function(drugName)
    local drug = Config.Drugs and Config.Drugs[drugName]
    if not drug then return 0 end

    local data = marketCache[drugName]
    local mult = data and data.multiplier or 1.0

    local baseMin = drug.sellPrice.min
    local baseMax = drug.sellPrice.max

    -- Prix aléatoire dans la fourchette, ajusté par le multiplicateur
    local price = math.floor((baseMin + math.random() * (baseMax - baseMin)) * mult)

    -- Plancher : jamais en dessous de 50% du minimum de base
    price = math.max(price, math.floor(baseMin * 0.5))

    return price
end)

-- ================================================================
-- EXPORT — Enregistrer une vente (appelé par eightys_drugs)
-- ================================================================
exports('recordSale', function(drugName, quantity)
    if not drugName then return end
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))

    local data = marketCache[drugName]
    if not data then return end

    data.sales_count = data.sales_count + quantity

    -- Recalculer le multiplicateur
    -- 0 vente = ×1.0, 50 ventes = ×0.5 (min), entre les deux = linéaire
    local MAX_SALES   = 50
    local MIN_MULT    = 0.5
    local ratio       = math.min(data.sales_count / MAX_SALES, 1.0)
    data.multiplier   = 1.0 - ratio * (1.0 - MIN_MULT)

    -- Si drought, ignorer la réduction (pénurie = prix haut)
    if data.drought then
        data.multiplier = math.max(data.multiplier, 1.5)
    end

    marketCache[drugName].multiplier  = data.multiplier
    marketCache[drugName].sales_count = data.sales_count

    MySQL.update.await(
        'UPDATE drug_market SET sales_count=?, multiplier=? WHERE drug=?',
        { data.sales_count, data.multiplier, drugName }
    )
end)

-- ================================================================
-- EXPORT — Déclencher une pénurie (appel admin ou raid policier)
-- ================================================================
exports('triggerDrought', function(drugName, duration)
    duration = duration or 7200 -- 2h par défaut
    if not marketCache[drugName] then return end

    marketCache[drugName].drought    = true
    marketCache[drugName].multiplier = math.max(marketCache[drugName].multiplier, 1.8)

    MySQL.update.await(
        'UPDATE drug_market SET drought=TRUE, multiplier=1.8 WHERE drug=?',
        { drugName }
    )

    print(string.format('[eightys_economy] Pénurie de %s déclenchée (%ds).', drugName, duration))

    -- Auto-fin de pénurie
    SetTimeout(duration * 1000, function()
        if marketCache[drugName] then
            marketCache[drugName].drought = false
            MySQL.update.await('UPDATE drug_market SET drought=FALSE WHERE drug=?', { drugName })
            print(string.format('[eightys_economy] Pénurie de %s terminée.', drugName))
            -- Notifier tous les clients connectés
            TriggerClientEvent('eightys_economy:client:droughtEnd', -1, drugName)
        end
    end)

    TriggerClientEvent('eightys_economy:client:drought', -1, drugName)
end)

-- ================================================================
-- RESET HORAIRE DES COMPTEURS
-- ================================================================
CreateThread(function()
    while true do
        Wait(3600000) -- 1h

        for drugName, data in pairs(marketCache) do
            -- Remettre les compteurs à zéro et revenir vers ×1.0
            local newMult = data.drought and 1.5 or 1.0
            marketCache[drugName].sales_count = 0
            marketCache[drugName].multiplier  = newMult

            MySQL.update.await(
                'UPDATE drug_market SET sales_count=0, multiplier=?, last_reset=? WHERE drug=?',
                { newMult, os.time(), drugName }
            )
        end

        print('[eightys_economy] Marché réinitialisé.')
    end
end)

-- ================================================================
-- COMMANDE ADMIN — Déclencher une pénurie
-- /drought [drogue] [duree_secondes]
-- ================================================================
RegisterCommand('drought', function(src, args)
    if src ~= 0 then
        local Player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        if not Player or not Player.PlayerData.group == 'admin' then return end
    end

    local drugName = args[1]
    local duration = tonumber(args[2]) or 7200

    if not drugName or not Config.Drugs[drugName] then
        print('[eightys_economy] Usage: /drought [drogue] [duree_s]')
        print('[eightys_economy] Drogues: ' .. table.concat(
            (function() local t={} for k in pairs(Config.Drugs) do t[#t+1]=k end return t end)(), ', '
        ))
        return
    end

    exports['eightys_economy']:triggerDrought(drugName, duration)
    TriggerClientEvent('ox_lib:notify', -1, {
        title       = '📰 Marché',
        description = string.format('Pénurie de %s en cours. Prix en hausse.', Config.Drugs[drugName].label),
        type        = 'warning',
        duration    = 8000,
    })
end, true)
