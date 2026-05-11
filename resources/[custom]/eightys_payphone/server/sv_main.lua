-- ================================================================
-- eightys_payphone — Server
-- Appels entre joueurs via cabines téléphoniques
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- appels en cours : callId → { caller, receiver, startTime }
local activeCalls = {}
-- joueurs en attente d'appel : receiverSrc → { caller, callId }
local pendingCalls = {}

local function genCallId()
    return tostring(math.random(100000, 999999))
end

-- ================================================================
-- INITIER UN APPEL
-- ================================================================
RegisterNetEvent('eightys_payphone:server:call', function(targetName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    targetName = tostring(targetName or ''):lower():gsub('%s+', '')
    if #targetName < 2 then return end

    -- Trouver le joueur cible (par prénom/nom partiel)
    local target = nil
    for _, p in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(p)
        if P then
            local fn = (P.PlayerData.charinfo.firstname or ''):lower()
            local ln = (P.PlayerData.charinfo.lastname  or ''):lower()
            if fn:find(targetName, 1, true) or ln:find(targetName, 1, true) then
                target = P; break
            end
        end
    end

    if not target then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '☎ Cabine', description = 'Personne de ce nom n\'est près d\'une cabine.', type = 'error'
        })
        return
    end

    if target.PlayerData.source == src then
        TriggerClientEvent('ox_lib:notify', src, { title = '☎ Cabine', description = 'Vous ne pouvez pas vous appeler vous-même.', type = 'error' })
        return
    end

    -- Vérifier que la cible est near d'une cabine (validé côté client)
    -- Le client target devra répondre
    local callId = genCallId()
    pendingCalls[target.PlayerData.source] = { caller = src, callId = callId }

    -- Débiter le coût au demandeur
    Player.Functions.RemoveMoney('cash', Config.Payphone.CallCost, 'appel_cabine')

    -- Notifier le demandeur
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '☎ Appel en cours…',
        description = 'En attente de réponse de ' .. target.PlayerData.charinfo.firstname,
        type        = 'inform', duration = 10000,
    })

    -- Notifier la cible
    local callerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    TriggerClientEvent('eightys_payphone:client:incomingCall', target.PlayerData.source, callId, callerName)

    -- Timeout 15 secondes
    SetTimeout(15000, function()
        if pendingCalls[target.PlayerData.source] and pendingCalls[target.PlayerData.source].callId == callId then
            pendingCalls[target.PlayerData.source] = nil
            TriggerClientEvent('ox_lib:notify', src, { title = '☎ Pas de réponse', type = 'error', duration = 3000 })
            TriggerClientEvent('eightys_payphone:client:callEnded', target.PlayerData.source)
        end
    end)
end)

-- ================================================================
-- RÉPONDRE À L'APPEL
-- ================================================================
RegisterNetEvent('eightys_payphone:server:answer', function(callId)
    local src     = source
    local pending = pendingCalls[src]
    if not pending or pending.callId ~= callId then return end

    local callerSrc = pending.caller
    pendingCalls[src] = nil

    activeCalls[callId] = { caller = callerSrc, receiver = src, startTime = os.time() }

    -- Lancer la voix entre les deux joueurs via MumbleSetTalkingGroupSettings ou simplement notifier
    TriggerClientEvent('eightys_payphone:client:callConnected', callerSrc,  callId)
    TriggerClientEvent('eightys_payphone:client:callConnected', src, callId)

    local callerPlayer   = QBCore.Functions.GetPlayer(callerSrc)
    local receiverPlayer = QBCore.Functions.GetPlayer(src)
    if callerPlayer and receiverPlayer then
        TriggerClientEvent('ox_lib:notify', callerSrc, {
            title = '☎ Connecté', description = receiverPlayer.PlayerData.charinfo.firstname .. ' a décroché.', type = 'success'
        })
        TriggerClientEvent('ox_lib:notify', src, {
            title = '☎ Connecté', description = 'En ligne avec ' .. callerPlayer.PlayerData.charinfo.firstname, type = 'success'
        })
    end
end)

-- ================================================================
-- RACCROCHER
-- ================================================================
RegisterNetEvent('eightys_payphone:server:hangup', function(callId)
    local src  = source
    local call = activeCalls[callId]
    if not call then return end

    local other = (call.caller == src) and call.receiver or call.caller
    activeCalls[callId] = nil

    TriggerClientEvent('eightys_payphone:client:callEnded', other)
    TriggerClientEvent('eightys_payphone:client:callEnded', src)

    TriggerClientEvent('ox_lib:notify', other, { title = '☎ Raccroché', type = 'inform', duration = 2000 })
end)

-- ================================================================
-- REFUSER
-- ================================================================
RegisterNetEvent('eightys_payphone:server:decline', function(callId)
    local src     = source
    local pending = pendingCalls[src]
    if not pending or pending.callId ~= callId then return end

    local callerSrc = pending.caller
    pendingCalls[src] = nil

    TriggerClientEvent('eightys_payphone:client:callEnded', src)
    TriggerClientEvent('ox_lib:notify', callerSrc, { title = '☎ Appel refusé', type = 'error', duration = 3000 })
end)

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    -- Couper les appels actifs
    for id, call in pairs(activeCalls) do
        if call.caller == src or call.receiver == src then
            local other = (call.caller == src) and call.receiver or call.caller
            activeCalls[id] = nil
            TriggerClientEvent('eightys_payphone:client:callEnded', other)
        end
    end
    -- Annuler les appels en attente
    if pendingCalls[src] then
        TriggerClientEvent('ox_lib:notify', pendingCalls[src].caller, {
            title = '☎ Appel annulé', description = 'Le correspondant s\'est déconnecté.', type = 'error'
        })
        pendingCalls[src] = nil
    end
end)
