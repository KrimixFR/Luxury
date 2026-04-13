-- ================================================================
-- eightys_police — Server
-- Logique serveur : arrestations, armurerie, preuves
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- MENOTTER UN JOUEUR
-- ================================================================
RegisterNetEvent('eightys_police:server:cuffPlayer', function(targetSrc)
    local src     = source
    local Officer = QBCore.Functions.GetPlayer(src)
    local Target  = QBCore.Functions.GetPlayer(tonumber(targetSrc))

    if not Officer or not Target then return end

    local jobName = Officer.PlayerData.job and Officer.PlayerData.job.name
    if jobName ~= "police" and jobName ~= "vicesquad" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Accès refusé", type = "error",
            description = "Vous n'êtes pas officier de police.",
        })
        return
    end

    TriggerClientEvent('eightys_police:client:cuffPlayer', targetSrc)

    TriggerClientEvent('ox_lib:notify', src, {
        title = "Joueur menotté",
        description = string.format("%s %s a été menotté.",
            Target.PlayerData.charinfo.firstname,
            Target.PlayerData.charinfo.lastname),
        type = "success",
    })

    print(string.format("[POLICE] %d a menotté %d", src, targetSrc))
end)

-- ================================================================
-- LIBÉRER DES MENOTTES
-- ================================================================
RegisterNetEvent('eightys_police:server:uncuffPlayer', function(targetSrc)
    local src     = source
    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return end

    local jobName = Officer.PlayerData.job and Officer.PlayerData.job.name
    if jobName ~= "police" and jobName ~= "vicesquad" then return end

    TriggerClientEvent('eightys_police:client:uncuffPlayer', tonumber(targetSrc))

    TriggerClientEvent('ox_lib:notify', src, {
        title = "Menottes retirées", type = "inform",
        description = "Le joueur a été libéré des menottes.",
    })
end)

-- ================================================================
-- ARRESTATION & EMPRISONNEMENT
-- ================================================================
RegisterNetEvent('eightys_police:server:arrestPlayer', function(targetSrc, sentence)
    local src     = source
    local Officer = QBCore.Functions.GetPlayer(src)
    local Target  = QBCore.Functions.GetPlayer(tonumber(targetSrc))

    if not Officer or not Target then return end

    local jobName = Officer.PlayerData.job and Officer.PlayerData.job.name
    if jobName ~= "police" and jobName ~= "vicesquad" then return end

    -- Valider la sentence
    sentence = math.max(60, math.min(Config.Police.MaxJailTime, math.floor(sentence or 300)))

    -- Saisir les armes et drogues
    local itemsSeized = {}
    local weapons     = Target.PlayerData.items

    -- Retirer l'argent (caution possible)
    local targetCash = Target.PlayerData.money["cash"] or 0
    local bail       = Config.Police.BailAmount

    -- Enregistrer l'arrestation en BDD
    MySQL.insert.await([[
        INSERT INTO police_arrests (officer_id, suspect_id, sentence, timestamp)
        VALUES (?, ?, ?, NOW())
    ]], {
        Officer.PlayerData.citizenid,
        Target.PlayerData.citizenid,
        sentence,
    })

    -- Envoyer en prison
    TriggerClientEvent('eightys_police:client:uncuffPlayer', targetSrc)
    TriggerClientEvent('eightys_police:client:sendToJail', targetSrc, sentence)

    -- Réinitialiser le niveau de recherche
    TriggerClientEvent('eightys_police:client:clearWanted', targetSrc)

    TriggerClientEvent('ox_lib:notify', src, {
        title = "Arrestation enregistrée",
        description = string.format("%s %s — %d minutes.",
            Target.PlayerData.charinfo.firstname,
            Target.PlayerData.charinfo.lastname,
            math.floor(sentence / 60)),
        type = "success",
    })

    print(string.format("[POLICE] Arrestation : officier %d emprisonne %d pour %ds",
        src, targetSrc, sentence))
end)

-- ================================================================
-- RÉINITIALISER LE NIVEAU WANTED (client event)
-- ================================================================
RegisterNetEvent('eightys_police:client:clearWanted', function()
    -- Ce event est déclenché sur le client cible, pas besoin de logique serveur
    -- mais on le re-register pour être complet
end)

-- ================================================================
-- ARMURERIE
-- ================================================================
RegisterNetEvent('eightys_police:server:openArmory', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jobName  = Player.PlayerData.job and Player.PlayerData.job.name
    if jobName ~= "police" and jobName ~= "vicesquad" then return end

    local armory = Config.Police.Armory[jobName]
    if not armory then return end

    -- Donner les armes et munitions
    for _, weapon in ipairs(armory.weapons) do
        Player.Functions.AddItem(weapon, 1)
    end
    for ammoType, count in pairs(armory.ammo) do
        Player.Functions.AddItem(ammoType, count)
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title       = "Armurerie",
        description = "Équipement récupéré. Bonne patrouille.",
        type        = "success",
    })

    print(string.format("[POLICE] Armurerie : officier %d s'équipe (%s)", src, jobName))
end)

-- ================================================================
-- COLLECTE DE PREUVES
-- ================================================================
RegisterNetEvent('eightys_police:server:collectEvidence', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if jobName ~= "police" and jobName ~= "vicesquad" then return end

    -- Ajouter un sac de preuves à l'inventaire
    local added = Player.Functions.AddItem(Config.Police.EvidenceBagItem, 1)

    if added then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Preuves collectées",
            description = "Sac de preuves ajouté à votre inventaire.",
            type        = "success",
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Inventaire plein",
            description = "Impossible d'ajouter le sac de preuves.",
            type        = "error",
        })
    end
end)

-- ================================================================
-- STATISTIQUES POLICE (admin)
-- ================================================================
QBCore.Commands.Add('stats_police', 'Statistiques des arrestations [Admin]', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Accès refusé", type = "error"
        })
        return
    end

    local rows = MySQL.query.await([[
        SELECT officer_id, COUNT(*) as arrests
        FROM police_arrests
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY officer_id
        ORDER BY arrests DESC
        LIMIT 10
    ]])

    if rows then
        local msg = "Top arrêts (7 jours) :\n"
        for i, row in ipairs(rows) do
            msg = msg .. string.format("%d. %s — %d arrestations\n", i, row.officer_id, row.arrests)
        end
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Stats Police", description = msg, type = "inform", duration = 10000
        })
    end
end, 'admin')

-- ================================================================
-- INITIALISATION BDD
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS police_arrests (
            id          INT AUTO_INCREMENT PRIMARY KEY,
            officer_id  VARCHAR(50) NOT NULL,
            suspect_id  VARCHAR(50) NOT NULL,
            sentence    INT NOT NULL DEFAULT 0,
            timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_officer  (officer_id),
            INDEX idx_suspect  (suspect_id)
        )
    ]])
    print("[eightys_police] Tables police initialisées.")
end)
