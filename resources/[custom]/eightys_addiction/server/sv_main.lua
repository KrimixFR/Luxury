local QBCore = exports['qb-core']:GetCoreObject()

-- Création de la table au démarrage
MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS drug_addiction (
        citizenid VARCHAR(50) PRIMARY KEY,
        drug VARCHAR(30) NOT NULL DEFAULT 'none',
        use_count INT NOT NULL DEFAULT 0,
        last_use BIGINT NOT NULL DEFAULT 0,
        addicted BOOLEAN NOT NULL DEFAULT FALSE,
        detox_until BIGINT NOT NULL DEFAULT 0
    )
]])

-- Récupère ou crée la ligne d'addiction d'un joueur
local function getOrCreateRecord(citizenid)
    local result = MySQL.query.await('SELECT * FROM drug_addiction WHERE citizenid = ?', { citizenid })
    if result and result[1] then
        return result[1]
    end
    MySQL.insert.await(
        'INSERT INTO drug_addiction (citizenid) VALUES (?)',
        { citizenid }
    )
    return {
        citizenid  = citizenid,
        drug       = 'none',
        use_count  = 0,
        last_use   = 0,
        addicted   = false,
        detox_until = 0,
    }
end

-- Synchronise l'état d'addiction vers le client
local function syncToClient(src, record)
    TriggerClientEvent('eightys_addiction:client:state', src, {
        addicted  = record.addicted == 1 or record.addicted == true,
        drug      = record.drug,
        last_use  = record.last_use,
    })
end

-- Enregistrement d'une consommation de drogue
RegisterNetEvent('eightys_addiction:server:recordUse', function(drugName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local record = getOrCreateRecord(citizenid)
    local now = os.time()

    local newUseCount
    local newAddicted = record.addicted == 1 or record.addicted == true

    if record.drug == drugName then
        -- Même drogue : on incrémente
        newUseCount = record.use_count + 1
        if newUseCount >= 5 then
            newAddicted = true
        end
    else
        -- Nouvelle drogue : reset
        newUseCount = 1
        -- On n'efface pas l'addiction existante si elle était déjà là,
        -- mais on change la drogue de référence
        newAddicted = false
    end

    MySQL.update.await(
        'UPDATE drug_addiction SET drug = ?, use_count = ?, last_use = ?, addicted = ? WHERE citizenid = ?',
        { drugName, newUseCount, now, newAddicted, citizenid }
    )

    record.drug      = drugName
    record.use_count = newUseCount
    record.last_use  = now
    record.addicted  = newAddicted

    syncToClient(src, record)
end)

-- Désintoxication à l'hôpital
RegisterNetEvent('eightys_addiction:server:detox', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cash = Player.PlayerData.money['cash']
    if not cash or cash < 1000 then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Hôpital',
            description = 'Vous n\'avez pas assez d\'argent liquide. (1 000$)',
            type        = 'error',
            duration    = 5000,
        })
        return
    end

    Player.Functions.RemoveMoney('cash', 1000, 'detox')

    local citizenid = Player.PlayerData.citizenid
    local detoxUntil = os.time() + 3600

    MySQL.update.await(
        'UPDATE drug_addiction SET addicted = FALSE, use_count = 0, drug = \'none\', detox_until = ? WHERE citizenid = ?',
        { detoxUntil, citizenid }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'Hôpital',
        description = 'Traitement administré. Restez sobre pendant au moins une heure.',
        type        = 'success',
        duration    = 8000,
    })

    syncToClient(src, {
        addicted  = false,
        drug      = 'none',
        last_use  = 0,
    })
end)

-- Envoi de l'état au chargement du joueur
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    local src    = Player.PlayerData.source
    local record = getOrCreateRecord(Player.PlayerData.citizenid)
    syncToClient(src, record)
end)

-- Sync à la demande du client (appelé après isLoggedIn)
RegisterNetEvent('eightys_addiction:server:requestSync', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local record = getOrCreateRecord(citizenid)
    syncToClient(src, record)
end)
