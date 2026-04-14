-- ================================================================
-- eightys_radio — Server
-- Disquaire Ray's Records : achats, caisse, stock
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Index des cassettes par name
local cassetteIndex = {}
for _, c in ipairs(Config.Radio.Cassettes) do
    cassetteIndex[c.name] = c
end

-- ================================================================
-- INITIALISATION BASE DE DONNÉES
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS radio_till (
            id      INT AUTO_INCREMENT PRIMARY KEY,
            balance INT NOT NULL DEFAULT 0
        )
    ]])
    -- S'assurer qu'il y a toujours une ligne de caisse
    local rows = MySQL.query.await('SELECT id FROM radio_till LIMIT 1')
    if not rows or #rows == 0 then
        MySQL.insert.await('INSERT INTO radio_till (balance) VALUES (0)')
    end
    print('[eightys_radio] Disquaire Ray\'s Records initialisé.')
end)

-- ================================================================
-- ACHETER UNE CASSETTE
-- ================================================================
RegisterNetEvent('eightys_radio:server:buyCassette', function(cassetteName)
    local src     = source
    local Player  = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cassette = cassetteIndex[cassetteName]
    if not cassette then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erreur', description = 'Cassette introuvable.', type = 'error' })
        return
    end

    -- Vérifier le cash
    local cash = Player.PlayerData.money['cash'] or 0
    if cash < cassette.price then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Fonds insuffisants',
            description = string.format('Il vous faut $%d. Vous avez $%d.', cassette.price, cash),
            type        = 'error',
        })
        return
    end

    -- Déduire le cash
    Player.Functions.RemoveMoney('cash', cassette.price, 'achat_cassette')

    -- Donner la cassette
    Player.Functions.AddItem(cassetteName, 1)

    -- Créditer la caisse (commission propriétaire)
    local commission = math.floor(cassette.price * Config.Radio.CommissionPct)
    MySQL.update.await('UPDATE radio_till SET balance = balance + ?', { commission })

    -- Confirmer au client
    TriggerClientEvent('eightys_radio:client:buySuccess', src, cassetteName)

    print(string.format('[eightys_radio] Vente : joueur %d achète %s pour $%d (caisse +$%d)',
        src, cassetteName, cassette.price, commission))
end)

-- ================================================================
-- COLLECTER LA CAISSE (propriétaire du disquaire)
-- ================================================================
RegisterNetEvent('eightys_radio:server:collectTill', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Vérifier le job
    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if jobName ~= Config.Radio.ShopJob then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Accès refusé', description = 'Réservé au propriétaire du disquaire.', type = 'error'
        })
        return
    end

    -- Lire le solde
    local rows = MySQL.query.await('SELECT balance FROM radio_till LIMIT 1')
    if not rows or #rows == 0 then return end

    local balance = rows[1].balance or 0
    if balance <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Caisse vide', description = 'Aucune recette à collecter.', type = 'inform'
        })
        return
    end

    -- Vider la caisse et payer le propriétaire
    MySQL.update.await('UPDATE radio_till SET balance = 0')
    Player.Functions.AddMoney('cash', balance, 'caisse_disquaire')

    TriggerClientEvent('eightys_radio:client:tillCollected', src, balance)
    print(string.format('[eightys_radio] Caisse collectée par joueur %d : $%d', src, balance))
end)
