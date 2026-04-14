-- ================================================================
-- eightys_informants — Server
-- Indics, tips, pots-de-vin policiers
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local POLICE_JOBS = { police = true, vicesquad = true }
local TIP_REWARD  = 300   -- $ par tip validé
local BRIBE_MIN   = 200
local BRIBE_MAX   = 10000

-- ================================================================
-- DB INIT
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS informants (
            citizenid     VARCHAR(50) NOT NULL PRIMARY KEY,
            registered_at BIGINT      NOT NULL,
            total_tips    INT         NOT NULL DEFAULT 0,
            total_paid    BIGINT      NOT NULL DEFAULT 0
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS informant_tips (
            id            INT AUTO_INCREMENT PRIMARY KEY,
            informant_cid VARCHAR(50)  NOT NULL,
            target_name   VARCHAR(100) NOT NULL,
            activity      VARCHAR(200) NOT NULL,
            location      VARCHAR(100),
            created_at    BIGINT       NOT NULL,
            resolved      BOOLEAN      NOT NULL DEFAULT FALSE,
            rewarded      BOOLEAN      NOT NULL DEFAULT FALSE
        )
    ]])
    print('[eightys_informants] Système indics initialisé.')
end)

-- ================================================================
-- HELPERS
-- ================================================================
local function isPolice(Player)
    local job = Player and Player.PlayerData.job
    return job and POLICE_JOBS[job.name]
end

local function isInformant(cid)
    local rows = MySQL.query.await('SELECT citizenid FROM informants WHERE citizenid=?', { cid })
    return rows and rows[1] ~= nil
end

-- ================================================================
-- S'ENREGISTRER COMME INDIC (au commissariat)
-- ================================================================
RegisterNetEvent('eightys_informants:server:register', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    if isInformant(cid) then
        TriggerClientEvent('ox_lib:notify', src, {
            title='Indic', description='Vous êtes déjà enregistré comme informateur.', type='error'
        })
        return
    end

    MySQL.insert.await('INSERT INTO informants (citizenid, registered_at) VALUES (?,?)', { cid, os.time() })
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🤫 Informateur enregistré',
        description = 'Vous travaillez désormais pour le LAPD. Signalez des activités criminelles contre rémunération.',
        type        = 'success',
        duration    = 8000,
    })
    TriggerClientEvent('eightys_informants:client:registered', src)
end)

-- ================================================================
-- SOUMETTRE UN TIP
-- ================================================================
RegisterNetEvent('eightys_informants:server:submitTip', function(targetName, activity, location)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    if not isInformant(cid) then
        TriggerClientEvent('ox_lib:notify', src, { title='Indic', description='Vous n\'êtes pas enregistré.', type='error' })
        return
    end

    if not targetName or #targetName < 2 then
        TriggerClientEvent('ox_lib:notify', src, { title='Indic', description='Nom de cible invalide.', type='error' })
        return
    end

    MySQL.insert.await(
        'INSERT INTO informant_tips (informant_cid, target_name, activity, location, created_at) VALUES (?,?,?,?,?)',
        { cid, targetName:sub(1,99), (activity or ''):sub(1,199), location or 'Inconnu', os.time() }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        title       = '📞 Tip transmis',
        description = 'Votre information a été transmise au LAPD. Récompense versée si validée.',
        type        = 'success',
        duration    = 6000,
    })

    -- Alerter les policiers connectés
    local players = QBCore.Functions.GetPlayers()
    for _, pSrc in ipairs(players) do
        local P = QBCore.Functions.GetPlayer(pSrc)
        if P and isPolice(P) then
            TriggerClientEvent('ox_lib:notify', pSrc, {
                title       = '📞 Nouveau tip',
                description = string.format('Un indic signale %s pour "%s" à %s.',
                    targetName, activity or '?', location or 'lieu inconnu'),
                type        = 'warning',
                duration    = 10000,
            })
        end
    end
end)

-- ================================================================
-- VALIDER UN TIP (flic uniquement)
-- ================================================================
RegisterNetEvent('eightys_informants:server:validateTip', function(tipId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not isPolice(Player) then return end

    local rows = MySQL.query.await('SELECT * FROM informant_tips WHERE id=? AND resolved=FALSE', { tipId })
    local tip  = rows and rows[1]
    if not tip then
        TriggerClientEvent('ox_lib:notify', src, { title='Tips', description='Tip introuvable ou déjà traité.', type='error' })
        return
    end

    MySQL.update.await('UPDATE informant_tips SET resolved=TRUE, rewarded=TRUE WHERE id=?', { tipId })
    MySQL.update.await('UPDATE informants SET total_tips=total_tips+1, total_paid=total_paid+? WHERE citizenid=?',
        { TIP_REWARD, tip.informant_cid })

    -- Payer l'indic s'il est connecté
    local InformantPlayer = QBCore.Functions.GetPlayerByCitizenId(tip.informant_cid)
    if InformantPlayer then
        InformantPlayer.Functions.AddMoney('cash', TIP_REWARD, 'indic_reward')
        TriggerClientEvent('ox_lib:notify', InformantPlayer.PlayerData.source, {
            title       = '💵 Récompense',
            description = string.format('Votre tip sur %s a été validé. $%d versés.', tip.target_name, TIP_REWARD),
            type        = 'success',
            duration    = 8000,
        })
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title='Tips', description=string.format('Tip validé. $%d versés à l\'indic.', TIP_REWARD), type='success'
    })
end)

-- ================================================================
-- LISTER LES TIPS EN ATTENTE (flics uniquement)
-- ================================================================
RegisterNetEvent('eightys_informants:server:listTips', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not isPolice(Player) then return end

    local cutoff = os.time() - 7200 -- tips des 2 dernières heures
    local tips   = MySQL.query.await(
        'SELECT * FROM informant_tips WHERE resolved=FALSE AND created_at > ? ORDER BY created_at DESC LIMIT 10',
        { cutoff }
    )

    TriggerClientEvent('eightys_informants:client:showTips', src, tips or {})
end)

-- ================================================================
-- POT-DE-VIN — Un civil propose un pot-de-vin à un flic
-- ================================================================
RegisterNetEvent('eightys_informants:server:offerBribe', function(copSrc, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount < BRIBE_MIN or amount > BRIBE_MAX then
        TriggerClientEvent('ox_lib:notify', src, {
            title='Pot-de-vin', description=string.format('Montant entre $%d et $%d.', BRIBE_MIN, BRIBE_MAX), type='error'
        })
        return
    end

    local cash = Player.PlayerData.money['cash'] or 0
    if cash < amount then
        TriggerClientEvent('ox_lib:notify', src, { title='Pot-de-vin', description='Pas assez de cash.', type='error' })
        return
    end

    local Cop = QBCore.Functions.GetPlayer(copSrc)
    if not Cop or not isPolice(Cop) then
        TriggerClientEvent('ox_lib:notify', src, { title='Pot-de-vin', description='Cible invalide.', type='error' })
        return
    end

    -- Proposer au flic
    TriggerClientEvent('eightys_informants:client:bribeOffer', copSrc, {
        fromSrc    = src,
        fromName   = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        amount     = amount,
    })

    TriggerClientEvent('ox_lib:notify', src, {
        title       = '💸 Offre envoyée',
        description = string.format('Vous proposez $%d à l\'officier. Attendez sa réponse.', amount),
        type        = 'info',
        duration    = 6000,
    })
end)

-- ================================================================
-- RÉPONSE DU FLIC AU POT-DE-VIN
-- ================================================================
RegisterNetEvent('eightys_informants:server:bribeResponse', function(civilSrc, accepted, amount)
    local src    = source
    local Cop    = QBCore.Functions.GetPlayer(src)
    local Civil  = QBCore.Functions.GetPlayer(civilSrc)
    if not Cop or not Civil then return end

    if accepted then
        local cash = Civil.PlayerData.money['cash'] or 0
        if cash < amount then
            TriggerClientEvent('ox_lib:notify', src, { title='Pot-de-vin', description='Le civil n\'a plus l\'argent.', type='error' })
            return
        end
        Civil.Functions.RemoveMoney('cash', amount, 'bribe')
        Cop.Functions.AddMoney('cash', amount, 'bribe')

        TriggerClientEvent('ox_lib:notify', civilSrc, {
            title='💸 Pot-de-vin', description=string.format('L\'officier a accepté. $%d versés.', amount), type='success', duration=6000
        })
        TriggerClientEvent('ox_lib:notify', src, {
            title='💸 Pot-de-vin', description=string.format('$%d reçus. Soyez discret.', amount), type='success', duration=6000
        })
    else
        TriggerClientEvent('ox_lib:notify', civilSrc, {
            title='💸 Refus', description='L\'officier a refusé votre offre.', type='error', duration=6000
        })
        TriggerClientEvent('ox_lib:notify', src, {
            title='💸 Refus', description='Vous avez refusé le pot-de-vin.', type='info', duration=4000
        })
    end
end)
