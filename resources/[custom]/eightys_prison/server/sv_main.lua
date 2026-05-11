-- ================================================================
-- eightys_prison — Server
-- Incarcération, activités (musculation, marché noir), contacts
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- DB INIT
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS prison_records (
            citizenid    VARCHAR(50) NOT NULL PRIMARY KEY,
            sentence_end BIGINT      NOT NULL DEFAULT 0,
            total_time   INT         NOT NULL DEFAULT 0,
            last_workout BIGINT      NOT NULL DEFAULT 0,
            contacts     TEXT        NOT NULL DEFAULT '[]'
        )
    ]])
    print('[eightys_prison] Système prison initialisé.')
end)

-- ================================================================
-- HELPERS
-- ================================================================
local PRISON_SPAWN  = { x=1649.4, y=2564.6, z=45.7, h=90.0  }
local RELEASE_SPAWN = { x=1853.7, y=2586.5, z=45.7, h=270.0 }
local WORKOUT_COST  = 0      -- gratuit mais cooldown
local WORKOUT_COOLDOWN    = 1800  -- 30min
local WORKOUT_BUFF_DURATION = 3600 -- 1h

local CONTRABAND = {
    { item='cigarettes', label='Cigarettes',  price=50  },
    { item='bandage',    label='Pansement',   price=150 },
    { item='lighter',    label='Briquet',     price=30  },
}

local function getRecord(cid)
    local rows = MySQL.query.await('SELECT * FROM prison_records WHERE citizenid=?', { cid })
    return rows and rows[1] or nil
end

local function ensureRecord(cid)
    local rec = getRecord(cid)
    if not rec then
        MySQL.insert.await('INSERT INTO prison_records (citizenid) VALUES (?)', { cid })
        rec = getRecord(cid)
    end
    return rec
end

-- ================================================================
-- INCARCÉRER UN JOUEUR
-- Export appelé par eightys_police ou commande admin
-- ================================================================
exports('jailPlayer', function(targetSrc, minutes, reason)
    local Player = QBCore.Functions.GetPlayer(targetSrc)
    if not Player then return false end

    local cid        = Player.PlayerData.citizenid
    local sentenceEnd = os.time() + (minutes * 60)
    local totalTime   = minutes * 60

    ensureRecord(cid)
    MySQL.update.await(
        'UPDATE prison_records SET sentence_end=?, total_time=total_time+? WHERE citizenid=?',
        { sentenceEnd, totalTime, cid }
    )

    TriggerClientEvent('eightys_prison:client:jail', targetSrc, {
        sentenceEnd = sentenceEnd,
        reason      = reason or 'Détention légale',
        minutes     = minutes,
    })

    -- Log pour le journal
    local charInfo = Player.PlayerData.charinfo
    local name     = charInfo.firstname .. ' ' .. charInfo.lastname
    TriggerEvent('eightys_newspaper:log:arrest', name, reason or 'Infraction', 'Bolingbroke Penitentiary')

    print(string.format('[eightys_prison] %s incarcéré pour %d min. (%s)', name, minutes, reason or '?'))
    return true
end)

-- ================================================================
-- COMMANDE — /jail [id] [minutes] [raison]
-- ================================================================
RegisterCommand('jail', function(src, args)
    local QBCoreObj = exports['qb-core']:GetCoreObject()
    -- Autorisation : admin ou flic
    local Caller = src ~= 0 and QBCoreObj.Functions.GetPlayer(src)
    if src ~= 0 and Caller then
        local job = Caller.PlayerData.job
        if not (job and (job.name == 'police' or job.name == 'vicesquad' or Caller.PlayerData.group == 'admin')) then
            TriggerClientEvent('ox_lib:notify', src, { title='Prison', description='Accès refusé.', type='error' })
            return
        end
    end

    local targetId = tonumber(args[1])
    local minutes  = tonumber(args[2]) or 5
    local reason   = table.concat(args, ' ', 3) or 'Arrestation'

    if not targetId then
        TriggerClientEvent('ox_lib:notify', src, { title='Prison', description='Usage: /jail [id] [minutes] [raison]', type='error' })
        return
    end

    local success = exports['eightys_prison']:jailPlayer(targetId, minutes, reason)
    if not success then
        TriggerClientEvent('ox_lib:notify', src, { title='Prison', description='Joueur introuvable.', type='error' })
    end
end, false)

-- ================================================================
-- LIBÉRATION ANTICIPÉE (admin)
-- ================================================================
RegisterCommand('unjail', function(src, args)
    local targetId = tonumber(args[1])
    if not targetId then return end

    local Player = QBCore.Functions.GetPlayer(targetId)
    if not Player then return end

    MySQL.update.await('UPDATE prison_records SET sentence_end=0 WHERE citizenid=?',
        { Player.PlayerData.citizenid })
    TriggerClientEvent('eightys_prison:client:release', targetId)
end, true)

-- ================================================================
-- SYNC AU LOGIN (si peine en cours)
-- ================================================================
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    local src = Player.PlayerData.source

    local rec = getRecord(Player.PlayerData.citizenid)
    if rec and rec.sentence_end and rec.sentence_end > os.time() then
        TriggerClientEvent('eightys_prison:client:jail', src, {
            sentenceEnd = rec.sentence_end,
            reason      = 'Peine en cours',
            minutes     = math.ceil((rec.sentence_end - os.time()) / 60),
        })
    end
end)

RegisterNetEvent('eightys_prison:server:requestSync', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local rec = getRecord(Player.PlayerData.citizenid)
    if rec and rec.sentence_end and rec.sentence_end > os.time() then
        TriggerClientEvent('eightys_prison:client:jail', src, {
            sentenceEnd = rec.sentence_end,
            reason      = 'Peine en cours',
            minutes     = math.ceil((rec.sentence_end - os.time()) / 60),
        })
    end
end)

-- ================================================================
-- MUSCULATION — Buff de force temporaire
-- ================================================================
RegisterNetEvent('eightys_prison:server:workout', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local rec = ensureRecord(cid)
    local now = os.time()

    if now - rec.last_workout < WORKOUT_COOLDOWN then
        local wait = math.ceil((WORKOUT_COOLDOWN - (now - rec.last_workout)) / 60)
        TriggerClientEvent('ox_lib:notify', src, {
            title='Musculation', description=string.format('Trop fatigué. Reposez-vous %d min.', wait), type='error'
        })
        return
    end

    MySQL.update.await('UPDATE prison_records SET last_workout=? WHERE citizenid=?', { now, cid })

    TriggerClientEvent('eightys_prison:client:workoutBuff', src, WORKOUT_BUFF_DURATION)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '💪 Séance terminée',
        description = 'Vous vous sentez plus fort. Buff actif 1h.',
        type        = 'success',
        duration    = 6000,
    })
end)

-- ================================================================
-- MARCHÉ NOIR — Acheter de la contrebande
-- ================================================================
RegisterNetEvent('eightys_prison:server:buyContraband', function(itemName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local found = nil
    for _, c in ipairs(CONTRABAND) do
        if c.item == itemName then found = c break end
    end

    if not found then
        TriggerClientEvent('ox_lib:notify', src, { title='Marché', description='Article introuvable.', type='error' })
        return
    end

    if (Player.PlayerData.money['cash'] or 0) < found.price then
        TriggerClientEvent('ox_lib:notify', src, {
            title='Marché', description=string.format('Il vous faut $%d.', found.price), type='error'
        })
        return
    end

    Player.Functions.RemoveMoney('cash', found.price, 'prison_contraband')
    Player.Functions.AddItem(found.item, 1)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🤝 Marché noir',
        description = string.format('%s obtenu pour $%d.', found.label, found.price),
        type        = 'success',
    })
end)
