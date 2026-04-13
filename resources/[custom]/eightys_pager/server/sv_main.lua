-- ================================================================
-- eightys_pager — Server
-- Envoi de messages, 911, stockage en BDD
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- ENVOYER UN MESSAGE BIPER
-- ================================================================
RegisterNetEvent('eightys_pager:server:sendMessage', function(targetId, message)
    local src    = source
    local Sender = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))

    if not Sender then return end

    -- Valider le message
    message = tostring(message):sub(1, Config.Pager.MaxMsgLength)
    if message == "" then return end

    if not Target then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Joueur introuvable",
            description = string.format("Aucun joueur avec l'ID %d.", targetId),
            type        = "error",
        })
        return
    end

    local senderName = string.format("%s %s",
        Sender.PlayerData.charinfo.firstname,
        Sender.PlayerData.charinfo.lastname)

    -- Envoyer au destinataire
    TriggerClientEvent('eightys_pager:client:receiveMessage', targetId, senderName, message, src)

    -- Confirmation à l'expéditeur
    TriggerClientEvent('ox_lib:notify', src, {
        title       = "Message envoyé",
        description = string.format("Biper de %s (ID %d) : message transmis.", senderName, targetId),
        type        = "success",
        duration    = 3000,
    })

    -- Sauvegarder en BDD
    MySQL.insert.await([[
        INSERT INTO pager_messages (sender_id, receiver_id, message, timestamp)
        VALUES (?, ?, ?, NOW())
    ]], {
        Sender.PlayerData.citizenid,
        Target.PlayerData.citizenid,
        message,
    })

    print(string.format("[PAGER] Message : %d → %d | %s", src, targetId, message))
end)

-- ================================================================
-- CHARGER LES MESSAGES D'UN JOUEUR
-- ================================================================
RegisterNetEvent('eightys_pager:server:loadMessages', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenId = Player.PlayerData.citizenid

    local rows = MySQL.query.await([[
        SELECT
            pm.message,
            pm.timestamp,
            CONCAT(c.firstname, ' ', c.lastname) AS sender_name,
            pm.sender_id
        FROM pager_messages pm
        LEFT JOIN characters c ON c.citizenid = pm.sender_id
        WHERE pm.receiver_id = ?
        ORDER BY pm.timestamp DESC
        LIMIT ?
    ]], { citizenId, Config.Pager.MaxMessages })

    local messages = {}
    if rows then
        for _, row in ipairs(rows) do
            table.insert(messages, {
                from   = row.sender_name or "Inconnu",
                fromId = row.sender_id   or 0,
                text   = row.message,
                time   = row.timestamp   or "",
            })
        end
    end

    TriggerClientEvent('eightys_pager:client:loadMessages', src, messages)
end)

-- ================================================================
-- APPEL 911
-- ================================================================
RegisterNetEvent('eightys_pager:server:call911', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local callerName = string.format("%s %s",
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname)

    -- Récupérer la position du joueur
    local playerPos = GetEntityCoords(GetPlayerPed(src))

    -- Notifier tous les policiers en ligne
    local allPlayers = QBCore.Functions.GetQBPlayers()
    for _, p in pairs(allPlayers) do
        local job = p.PlayerData.job and p.PlayerData.job.name
        if job == "police" or job == "vicesquad" then
            TriggerClientEvent('eightys_pager:client:receive911', p.PlayerData.source,
                callerName,
                { x = playerPos.x, y = playerPos.y, z = playerPos.z },
                nil
            )
        end
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title       = "Appel passé",
        description = "Le 911 a été contacté. Des officiers sont en route.",
        type        = "inform",
        duration    = 5000,
    })

    -- Log en BDD
    MySQL.insert.await([[
        INSERT INTO calls_911 (caller_id, x, y, z, timestamp)
        VALUES (?, ?, ?, ?, NOW())
    ]], {
        Player.PlayerData.citizenid,
        playerPos.x, playerPos.y, playerPos.z,
    })
end)

-- ================================================================
-- MESSAGE DEPUIS UNE SCÈNE DE CRIME (police seulement)
-- ================================================================
RegisterNetEvent('eightys_pager:server:policeAlert', function(message, x, y, z)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.PlayerData.job and Player.PlayerData.job.name
    if job ~= "police" and job ~= "vicesquad" then return end

    local senderName = string.format("[%s] %s %s",
        Player.PlayerData.job.label or "POLICE",
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname)

    -- Notifier tous les collègues
    local allPlayers = QBCore.Functions.GetQBPlayers()
    for _, p in pairs(allPlayers) do
        local pJob = p.PlayerData.job and p.PlayerData.job.name
        if (pJob == "police" or pJob == "vicesquad") and p.PlayerData.source ~= src then
            TriggerClientEvent('eightys_pager:client:receive911', p.PlayerData.source,
                senderName,
                { x = x, y = y, z = z },
                message
            )
        end
    end
end)

-- ================================================================
-- INITIALISATION BDD
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS pager_messages (
            id          INT AUTO_INCREMENT PRIMARY KEY,
            sender_id   VARCHAR(50) NOT NULL,
            receiver_id VARCHAR(50) NOT NULL,
            message     VARCHAR(255) NOT NULL,
            timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_receiver (receiver_id),
            INDEX idx_sender   (sender_id)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS calls_911 (
            id          INT AUTO_INCREMENT PRIMARY KEY,
            caller_id   VARCHAR(50) NOT NULL,
            x           FLOAT,
            y           FLOAT,
            z           FLOAT,
            timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    print("[eightys_pager] Système de communication initialisé.")
end)
