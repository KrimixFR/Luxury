-- ================================================================
-- eightys_gangs — Server
-- Gestion des gangs, territoires, coffres et guerres
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- TERRITOIRES (chargés depuis la BDD ou défauts)
-- ================================================================
-- { id, name, gang, x, y, z, points }
local territories = {}

local defaultTerritories = {
    { id = 1, name = "South LS Hood",    gang = "los_rojo", x = 95.7,   y = -1932.6, z = 20.9, points = 100 },
    { id = 2, name = "East LS Hood",     gang = "los_azul", x = 692.9,  y = -1851.2, z = 30.5, points = 100 },
    { id = 3, name = "Port de La Mesa",  gang = "los_sur",  x = 1097.7, y = -3175.0, z = 5.9,  points = 100 },
    { id = 4, name = "Vinewood Hills",   gang = "la_cosa",  x = -1282.2,y = -1012.8, z = 5.0,  points = 100 },
    { id = 5, name = "Forum Drive",      gang = "los_rojo", x = -47.0,  y = -1757.3, z = 29.4, points = 80  },
    { id = 6, name = "Davis Avenue",     gang = "los_azul", x = 360.5,  y = -1601.5, z = 35.0, points = 80  },
}

-- ================================================================
-- CHARGEMENT DES TERRITOIRES DEPUIS LA BDD
-- ================================================================
local function loadTerritories()
    local rows = MySQL.query.await("SELECT * FROM gang_territories")
    if rows and #rows > 0 then
        territories = rows
    else
        territories = defaultTerritories
        -- Initialiser la BDD
        for _, t in ipairs(defaultTerritories) do
            MySQL.insert.await([[
                INSERT IGNORE INTO gang_territories (id, name, gang, x, y, z, points)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]], { t.id, t.name, t.gang, t.x, t.y, t.z, t.points })
        end
    end
    print("[eightys_gangs] " .. #territories .. " territoires chargés.")
end

-- ================================================================
-- REQUÊTE TERRITOIRES (client)
-- ================================================================
RegisterNetEvent('eightys_gangs:server:requestTerritories', function()
    local src = source
    TriggerClientEvent('eightys_gangs:client:receiveTerritories', src, territories)
end)

RegisterNetEvent('eightys_gangs:server:getTerritoryInfo', function(gangName)
    local src  = source
    local owned = {}
    for _, t in ipairs(territories) do
        if t.gang == gangName then
            table.insert(owned, t)
        end
    end

    local gang = Config.Gangs[gangName]
    if gang then
        lib.notify(src, {
            title       = gang.label .. " — Territoires",
            description = string.format("Vous contrôlez %d zone(s).", #owned),
            type        = "inform",
        })
    end
end)

-- ================================================================
-- MEMBRES EN LIGNE
-- ================================================================
RegisterNetEvent('eightys_gangs:server:getOnlineMembers', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangName = Player.PlayerData.gang and Player.PlayerData.gang.name
    if not gangName or gangName == "none" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Sans affiliation", type = "error",
            description = "Vous n'êtes membre d'aucun gang.",
        })
        return
    end

    local players = QBCore.Functions.GetQBPlayers()
    local members = {}

    for _, p in pairs(players) do
        if p.PlayerData.gang and p.PlayerData.gang.name == gangName then
            table.insert(members, {
                serverId = p.PlayerData.source,
                name     = p.PlayerData.charinfo.firstname .. " " .. p.PlayerData.charinfo.lastname,
                grade    = p.PlayerData.gang.grade and p.PlayerData.gang.grade.level or 0,
            })
        end
    end

    TriggerClientEvent('eightys_gangs:client:onlineMembers', src, members, gangName)
end)

-- ================================================================
-- RECRUTEMENT
-- ================================================================
RegisterNetEvent('eightys_gangs:server:recruitPlayer', function(targetId)
    local src       = source
    local Recruiter = QBCore.Functions.GetPlayer(src)
    local Target    = QBCore.Functions.GetPlayer(tonumber(targetId))

    if not Recruiter or not Target then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Joueur introuvable", type = "error",
            description = "Ce joueur n'est pas en ligne.",
        })
        return
    end

    local recruiterGang = Recruiter.PlayerData.gang
    if not recruiterGang or recruiterGang.name == "none" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Erreur", type = "error",
            description = "Vous n'êtes dans aucun gang.",
        })
        return
    end

    if recruiterGang.grade and recruiterGang.grade.level < 3 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Grade insuffisant", type = "error",
            description = "Seuls les Lieutenants+ peuvent recruter.",
        })
        return
    end

    local targetGang = Target.PlayerData.gang
    if targetGang and targetGang.name ~= "none" then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Déjà affilié", type = "error",
            description = "Ce joueur est déjà dans un gang.",
        })
        return
    end

    -- Recruter
    Target.Functions.SetGang(recruiterGang.name, 0)  -- Grade 0 : recrue
    TriggerClientEvent('ox_lib:notify', src, {
        title = "Recrutement réussi", type = "success",
        description = Target.PlayerData.charinfo.firstname .. " rejoint " .. Config.Gangs[recruiterGang.name].label,
    })
    TriggerClientEvent('ox_lib:notify', Target.PlayerData.source, {
        title = "Bienvenue !",
        description = "Vous avez rejoint : " .. Config.Gangs[recruiterGang.name].label,
        type = "success",
    })

    print(string.format("[GANGS] Recrutement : %d recrute %d dans %s",
        src, targetId, recruiterGang.name))
end)

-- ================================================================
-- QUITTER LE GANG
-- ================================================================
RegisterNetEvent('eightys_gangs:server:leaveGang', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local oldGang = Player.PlayerData.gang and Player.PlayerData.gang.name
    Player.Functions.SetGang("none", 0)

    TriggerClientEvent('ox_lib:notify', src, {
        title       = "Gang quitté",
        description = "Vous avez quitté " .. (Config.Gangs[oldGang] and Config.Gangs[oldGang].label or "votre gang") .. ".",
        type        = "inform",
    })
end)

-- ================================================================
-- COFFRE DU GANG (stash)
-- ================================================================
local gangStash = {}   -- { [gangName] = amount }

local function loadGangStash()
    local rows = MySQL.query.await("SELECT gang_name, amount FROM gang_stash")
    if rows then
        for _, row in ipairs(rows) do
            gangStash[row.gang_name] = row.amount
        end
    end
end

RegisterNetEvent('eightys_gangs:server:depositGangStash', function(amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.max(1, math.floor(tonumber(amount) or 0))
    local gangName = Player.PlayerData.gang and Player.PlayerData.gang.name

    if not gangName or gangName == "none" then return end

    local cash = Player.PlayerData.money["cash"] or 0
    if cash < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Fonds insuffisants", type = "error",
            description = string.format("Vous n'avez que $%d en poche.", cash),
        })
        return
    end

    Player.Functions.RemoveMoney('cash', amount, "depot-coffre-gang")
    gangStash[gangName] = (gangStash[gangName] or 0) + amount

    MySQL.insert.await([[
        INSERT INTO gang_stash (gang_name, amount) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE amount = amount + ?
    ]], { gangName, amount, amount })

    TriggerClientEvent('ox_lib:notify', src, {
        title = "Dépôt effectué", type = "success",
        description = string.format("$%d déposé dans le coffre de %s.",
            amount, Config.Gangs[gangName].label),
    })
end)

RegisterNetEvent('eightys_gangs:server:withdrawGangStash', function(amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.max(1, math.floor(tonumber(amount) or 0))
    local gangName  = Player.PlayerData.gang and Player.PlayerData.gang.name
    local gradeLevel = Player.PlayerData.gang and Player.PlayerData.gang.grade and Player.PlayerData.gang.grade.level or 0

    if not gangName or gangName == "none" or gradeLevel < 2 then return end

    local available = gangStash[gangName] or 0
    if available < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Coffre insuffisant", type = "error",
            description = string.format("Le coffre ne contient que $%d.", available),
        })
        return
    end

    Player.Functions.AddMoney('cash', amount, "retrait-coffre-gang")
    gangStash[gangName] = available - amount

    MySQL.update.await(
        "UPDATE gang_stash SET amount = amount - ? WHERE gang_name = ?",
        { amount, gangName }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        title = "Retrait effectué", type = "success",
        description = string.format("$%d retirés du coffre.", amount),
    })
end)

-- ================================================================
-- GUERRE DE TERRITOIRE
-- ================================================================
local ongoingWars = {}   -- { [zoneId] = { attacker, defender, startTime, attackerScore, defenderScore } }
local WAR_DURATION = 600  -- 10 minutes

RegisterNetEvent('eightys_gangs:server:declareTurfWar', function(zoneId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangName  = Player.PlayerData.gang and Player.PlayerData.gang.name
    local gradeLevel = Player.PlayerData.gang and Player.PlayerData.gang.grade and Player.PlayerData.gang.grade.level or 0

    if not gangName or gangName == "none" or gradeLevel < 3 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Impossible", type = "error",
            description = "Seul un Lieutenant+ peut déclarer une guerre.",
        })
        return
    end

    -- Trouver le territoire
    local zone = nil
    for _, t in ipairs(territories) do
        if t.id == zoneId then zone = t; break end
    end

    if not zone or zone.gang == gangName then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Erreur", type = "error",
            description = "Zone invalide ou déjà à vous.",
        })
        return
    end

    if ongoingWars[zoneId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Guerre en cours", type = "error",
            description = "Un conflit est déjà en cours sur cette zone.",
        })
        return
    end

    ongoingWars[zoneId] = {
        attacker      = gangName,
        defender      = zone.gang,
        startTime     = os.time(),
        attackerScore = 0,
        defenderScore = 0,
    }

    -- Notifier tous les joueurs
    TriggerClientEvent('eightys_gangs:client:warStarted', -1, gangName, zone.gang, zone.name)

    -- Minuterie de fin de guerre
    CreateThread(function()
        Wait(WAR_DURATION * 1000)
        if not ongoingWars[zoneId] then return end

        local war = ongoingWars[zoneId]
        ongoingWars[zoneId] = nil

        if war.attackerScore > war.defenderScore then
            -- L'attaquant prend le territoire
            zone.gang = gangName
            MySQL.update.await(
                "UPDATE gang_territories SET gang = ? WHERE id = ?",
                { gangName, zoneId }
            )
            TriggerClientEvent('eightys_gangs:client:territoryTaken', -1, gangName, zone.name)
        else
            -- Le défenseur conserve
            TriggerClientEvent('ox_lib:notify', -1, {
                title = "Territoire défendu",
                description = Config.Gangs[zone.gang].label .. " conserve " .. zone.name,
                type = "success",
            })
        end
    end)
end)

-- Score de guerre (tués ennemis)
RegisterNetEvent('eightys_gangs:server:warKill', function(zoneId, killerGang)
    if not ongoingWars[zoneId] then return end
    local war = ongoingWars[zoneId]
    if killerGang == war.attacker then
        war.attackerScore = war.attackerScore + 1
    elseif killerGang == war.defender then
        war.defenderScore = war.defenderScore + 1
    end
end)

-- ================================================================
-- INITIALISATION
-- ================================================================
CreateThread(function()
    -- Créer les tables si elles n'existent pas
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS gang_territories (
            id    INT PRIMARY KEY,
            name  VARCHAR(80)  NOT NULL,
            gang  VARCHAR(50)  NOT NULL DEFAULT 'none',
            x     FLOAT        NOT NULL,
            y     FLOAT        NOT NULL,
            z     FLOAT        NOT NULL,
            points INT         NOT NULL DEFAULT 100
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS gang_stash (
            gang_name VARCHAR(50) PRIMARY KEY,
            amount    INT NOT NULL DEFAULT 0
        )
    ]])

    loadTerritories()
    loadGangStash()

    print("[eightys_gangs] Système de gangs initialisé.")
end)
