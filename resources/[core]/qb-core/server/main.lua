-- ================================================================
-- QBCore — server/main.lua
-- Connexion des joueurs, chargement des données, exports
-- ================================================================

QBCore.Player = QBCore.Player or {}

-- ================================================================
-- CONNEXION D'UN JOUEUR
-- ================================================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src     = source
    local license = GetPlayerIdentifierByType(src, 'license')

    if not license or license == '' then
        setKickReason('Aucun identifiant de licence détecté. Vérifiez votre connexion Steam.')
        CancelEvent()
        return
    end
end)

-- ================================================================
-- JOUEUR PRÊT (déclenché par qb-multicharacter après sélection)
-- ================================================================
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src     = source
    local license = GetPlayerIdentifierByType(src, 'license') or 'unknown'
    local name    = GetPlayerName(src) or 'Joueur'

    -- Charger ou créer le joueur
    if not QBCore.Players[src] then
        -- Chercher un citizenid existant pour cette license
        local citizenid = nil
        -- Scan des fichiers joueurs (simple recherche par license)
        local indexRaw = LoadResourceFile(GetCurrentResourceName(), 'players/_index.json')
        local index = {}
        if indexRaw and indexRaw ~= '' then
            local ok, data = pcall(json.decode, indexRaw)
            if ok and type(data) == 'table' then index = data end
        end

        citizenid = index[license]
        local isNew = false

        if not citizenid then
            -- Générer un nouveau citizenid
            local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            citizenid = ''
            for i = 1, 3 do citizenid = citizenid .. string.char(string.byte('A') + math.random(0,25)) end
            for i = 1, 5 do citizenid = citizenid .. math.random(0,9) end
            -- Sauvegarder dans l'index
            index[license] = citizenid
            SaveResourceFile(GetCurrentResourceName(), 'players/_index.json', json.encode(index), -1)
            isNew = true
        end

        local Player = QBCore.Player.CreatePlayer(src, license, name, citizenid, isNew)
        Player.PlayerData.source = src
        QBCore.Players[src] = Player
    end

    local Player = QBCore.Players[src]

    -- Synchroniser les données côté client
    TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
    TriggerClientEvent('QBCore:Player:SetPlayerData', src, Player.PlayerData)

    -- Événement local pour les autres resources (AddEventHandler)
    TriggerEvent('QBCore:Server:PlayerLoaded', Player)

    print(string.format('[QBCore] Joueur connecté : %s (src:%d, citizenid:%s)',
        name, src, Player.PlayerData.citizenid))
end)

-- ================================================================
-- DÉCONNEXION
-- ================================================================
AddEventHandler('playerDropped', function(reason)
    local src    = source
    local Player = QBCore.Players[src]

    if Player then
        -- Sauvegarder la position via coords
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            Player.Functions.SaveLocation(coords, heading)
        else
            Player.Functions.Save()
        end
        TriggerClientEvent('QBCore:Client:OnPlayerUnload', src)
        QBCore.Players[src] = nil
        print(string.format('[QBCore] Joueur déconnecté : src %d (%s)', src, reason))
    end
end)

-- ================================================================
-- EXPORTS (pour les autres resources)
-- ================================================================
exports('GetCoreObject', function()
    return QBCore
end)

-- ================================================================
-- COMMANDES ADMIN DE BASE
-- ================================================================
RegisterCommand('setjob', function(source, args)
    if source ~= 0 and not QBCore.Functions.HasPermission(source, 'admin') then return end
    local targetId = tonumber(args[1])
    local jobName  = args[2]
    local grade    = tonumber(args[3]) or 0
    local Target   = QBCore.Functions.GetPlayer(targetId)
    if Target then
        Target.Functions.SetJob(jobName, grade)
        print(string.format('[QBCore] setjob: %d → %s grade %d', targetId, jobName, grade))
    end
end, true)

RegisterCommand('setgang', function(source, args)
    if source ~= 0 and not QBCore.Functions.HasPermission(source, 'admin') then return end
    local targetId = tonumber(args[1])
    local gangName = args[2]
    local grade    = tonumber(args[3]) or 0
    local Target   = QBCore.Functions.GetPlayer(targetId)
    if Target then
        Target.Functions.SetGang(gangName, grade)
    end
end, true)

RegisterCommand('givemoney', function(source, args)
    if source ~= 0 and not QBCore.Functions.HasPermission(source, 'admin') then return end
    local targetId = tonumber(args[1])
    local moneyType = args[2] or 'cash'
    local amount   = tonumber(args[3]) or 0
    local Target   = QBCore.Functions.GetPlayer(targetId)
    if Target then Target.Functions.AddMoney(moneyType, amount, 'admin-give') end
end, true)

RegisterCommand('giveitem', function(source, args)
    if source ~= 0 and not QBCore.Functions.HasPermission(source, 'admin') then return end
    local targetId = tonumber(args[1])
    local itemName = args[2]
    local count    = tonumber(args[3]) or 1
    local Target   = QBCore.Functions.GetPlayer(targetId)
    if Target then Target.Functions.AddItem(itemName, count) end
end, true)

-- ================================================================
-- INIT
-- ================================================================
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print('[QBCore] Framework Los Santos 1987 démarré.')
    print('[QBCore] Stockage joueurs : players/*.json (pas de MySQL requis)')
end)
