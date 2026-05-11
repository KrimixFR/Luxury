-- ================================================================
-- eightys_jobs — Server
-- Paiement des salaires, livraisons, gestion des missions
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Points de livraison (camionneur)
local deliveryPoints = {
    { label = "Entrepôt South LS",  x = 984.7,   y = -3194.0, z = 5.9,  reward = 200 },
    { label = "Dock de La Mesa",    x = 1097.7,  y = -3175.0, z = 5.9,  reward = 250 },
    { label = "Supermarché Davis",  x = 96.5,    y = -1925.9, z = 20.9, reward = 150 },
    { label = "Dépôt Industriel",   x = 500.0,   y = -1940.0, z = 25.0, reward = 180 },
    { label = "Restaurant Vinewood",x = -692.8,  y = 572.3,   z = 120.9,reward = 220 },
    { label = "Marché Central",     x = -31.1,   y = -712.5,  z = 44.5, reward = 160 },
}

-- ================================================================
-- PRISE / FIN DE SERVICE
-- ================================================================
RegisterNetEvent('eightys_jobs:server:setDuty', function(jobName, onDuty)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerJob = Player.PlayerData.job and Player.PlayerData.job.name
    if playerJob ~= jobName then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Emploi invalide", type = "error",
            description = "Vous n'avez pas cet emploi.",
        })
        return
    end

    Player.Functions.SetJobDuty(onDuty)

    print(string.format("[JOBS] Joueur %d : %s — %s",
        src, jobName, onDuty and "prise de service" or "fin de service"))
end)

-- ================================================================
-- PAIEMENT D'UN REWARD
-- ================================================================
RegisterNetEvent('eightys_jobs:server:payJobReward', function(jobName, amount, reason)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerJob = Player.PlayerData.job and Player.PlayerData.job.name
    if playerJob ~= jobName then return end

    if not Player.PlayerData.job.onduty then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Hors service", type = "error",
            description = "Vous devez être en service pour être payé.",
        })
        return
    end

    amount = math.max(1, math.floor(tonumber(amount) or 0))
    Player.Functions.AddMoney('cash', amount, "job-" .. jobName .. "-" .. (reason or "mission"))

    -- Log en BDD
    MySQL.insert.await([[
        INSERT INTO job_earnings (player_id, job_name, amount, reason, timestamp)
        VALUES (?, ?, ?, ?, NOW())
    ]], {
        Player.PlayerData.citizenid,
        jobName,
        amount,
        reason or "mission",
    })

    print(string.format("[JOBS] Paiement : joueur %d reçoit $%d (%s)", src, amount, reason or "mission"))
end)

-- ================================================================
-- AJOUTER DES POISSONS (pêcheur)
-- ================================================================
RegisterNetEvent('eightys_jobs:server:addFishToInventory', function(count)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local added = Player.Functions.AddItem("fish", count)
    if added then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items["fish"], "add")
    end
end)

-- ================================================================
-- DÉMARRER UNE LIVRAISON (camionneur)
-- ================================================================
RegisterNetEvent('eightys_jobs:server:startDelivery', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerJob = Player.PlayerData.job and Player.PlayerData.job.name
    if playerJob ~= "trucker" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Emploi requis", type = "error",
            description = "Réservé aux camionneurs.",
        })
        return
    end

    if not Player.PlayerData.job.onduty then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Hors service", type = "error",
            description = "Prenez votre service d'abord.",
        })
        return
    end

    -- Choisir un point de livraison aléatoire
    local delivery = deliveryPoints[math.random(#deliveryPoints)]
    TriggerClientEvent('eightys_jobs:client:startDelivery', src, delivery)

    print(string.format("[JOBS] Livraison : joueur %d → %s ($%d)", src, delivery.label, delivery.reward))
end)

-- ================================================================
-- COMPLÉTER UNE LIVRAISON
-- ================================================================
RegisterNetEvent('eightys_jobs:server:completeDelivery', function(reward)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerJob = Player.PlayerData.job and Player.PlayerData.job.name
    if playerJob ~= "trucker" then return end

    reward = math.max(100, math.min(500, math.floor(tonumber(reward) or 150)))

    Player.Functions.AddMoney('cash', reward, "livraison-camion")

    MySQL.insert.await([[
        INSERT INTO job_earnings (player_id, job_name, amount, reason, timestamp)
        VALUES (?, ?, ?, ?, NOW())
    ]], {
        Player.PlayerData.citizenid,
        "trucker",
        reward,
        "livraison",
    })

    print(string.format("[JOBS] Livraison complétée : joueur %d reçoit $%d", src, reward))
end)

-- ================================================================
-- INFOS D'EMPLOI (retour client)
-- ================================================================
RegisterNetEvent('eightys_jobs:server:getJobInfo', function(jobName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job       = Config.Jobs[jobName]
    local playerJob = Player.PlayerData.job

    if not job or not playerJob then return end

    local gradeLevel = playerJob.grade and playerJob.grade.level or 0
    local gradeInfo  = job.grades[gradeLevel]
    local nextGrade  = job.grades[gradeLevel + 1]

    local msg = string.format(
        "Emploi : **%s**\nGrade : **%s** (niveau %d)\nSalaire à la mission : **$%d**\n%s",
        job.label,
        gradeInfo and gradeInfo.label or "Inconnu",
        gradeLevel,
        gradeInfo and gradeInfo.payment or 0,
        nextGrade and string.format("Prochain grade : %s ($%d)", nextGrade.label, nextGrade.payment) or "Grade maximum atteint !"
    )

    TriggerClientEvent('ox_lib:alertDialog', src, {
        header  = job.label,
        content = msg,
        centered = true,
    })
end)

-- ================================================================
-- SALAIRE HORAIRE (toutes les heures)
-- ================================================================
CreateThread(function()
    while true do
        Wait(3600000)   -- 1 heure réelle

        local players = QBCore.Functions.GetQBPlayers()
        for _, Player in pairs(players) do
            local jobName  = Player.PlayerData.job and Player.PlayerData.job.name
            local onDuty   = Player.PlayerData.job and Player.PlayerData.job.onduty
            local grade    = Player.PlayerData.job and Player.PlayerData.job.grade and Player.PlayerData.job.grade.level or 0

            if jobName and onDuty and Config.Jobs[jobName] then
                local job     = Config.Jobs[jobName]
                local gradeData = job.grades[grade]
                if gradeData and gradeData.payment then
                    local payment = gradeData.payment
                    Player.Functions.AddMoney('cash', payment, "salaire-horaire-" .. jobName)

                    TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                        title       = "Salaire versé",
                        description = string.format("$%d ajoutés (salaire horaire — %s).", payment, job.label),
                        type        = "success",
                        duration    = 5000,
                    })
                end
            end
        end
    end
end)

-- ================================================================
-- INITIALISATION BDD
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS job_earnings (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            player_id  VARCHAR(50) NOT NULL,
            job_name   VARCHAR(50) NOT NULL,
            amount     INT NOT NULL DEFAULT 0,
            reason     VARCHAR(100),
            timestamp  DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_player (player_id),
            INDEX idx_job    (job_name)
        )
    ]])
    print("[eightys_jobs] Système d'emplois civils initialisé.")
end)
