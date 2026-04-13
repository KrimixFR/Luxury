-- ================================================================
-- QBCore — server/functions.lua
-- QBCore.Functions.* (serveur)
-- ================================================================

QBCore.Functions = QBCore.Functions or {}

-- Table des joueurs connectés { [source] = PlayerObject }
QBCore.Players = QBCore.Players or {}

-- Callbacks { [name] = handler }
local Callbacks = {}

-- ================================================================
-- GESTION DES JOUEURS
-- ================================================================

function QBCore.Functions.GetPlayer(source)
    return QBCore.Players[tonumber(source)]
end

function QBCore.Functions.GetPlayerByCitizenId(citizenid)
    for _, Player in pairs(QBCore.Players) do
        if Player.PlayerData.citizenid == citizenid then return Player end
    end
    return nil
end

function QBCore.Functions.GetQBPlayers()
    return QBCore.Players
end

-- ================================================================
-- ARGENT (raccourcis)
-- ================================================================

function QBCore.Functions.AddMoney(source, moneyType, amount, reason)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        return Player.Functions.AddMoney(moneyType, amount, reason)
    end
    return false
end

function QBCore.Functions.RemoveMoney(source, moneyType, amount, reason)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        return Player.Functions.RemoveMoney(moneyType, amount, reason)
    end
    return false
end

-- ================================================================
-- PERMISSIONS ACE
-- ================================================================

function QBCore.Functions.HasPermission(source, permission)
    return IsPlayerAceAllowed(tostring(source), permission)
end

function QBCore.Functions.AddPermission(source, permission)
    ExecuteCommand(string.format('add_principal identifier.license:%s %s', GetPlayerIdentifierByType(source, 'license'), permission))
end

function QBCore.Functions.RemovePermission(source, permission)
    ExecuteCommand(string.format('remove_principal identifier.license:%s %s', GetPlayerIdentifierByType(source, 'license'), permission))
end

-- ================================================================
-- CALLBACKS
-- ================================================================

function QBCore.Functions.CreateCallback(name, handler)
    Callbacks[name] = handler
end

RegisterNetEvent('QBCore:Server:TriggerCallback', function(name, requestId, ...)
    local src = source
    if not Callbacks[name] then
        TriggerClientEvent('QBCore:Client:TriggerCallback', src, requestId, nil)
        return
    end
    Callbacks[name](src, function(...)
        TriggerClientEvent('QBCore:Client:TriggerCallback', src, requestId, ...)
    end, ...)
end)

-- ================================================================
-- COMMANDES
-- ================================================================

QBCore.Commands = QBCore.Commands or {}

function QBCore.Commands.Add(name, help, params, restricted, handler, permission)
    RegisterCommand(name, function(source, args, rawCommand)
        local src = source

        -- Vérification permission
        if restricted and src ~= 0 then
            if permission and not QBCore.Functions.HasPermission(src, permission) then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Accès refusé', type = 'error',
                    description = 'Vous n\'avez pas la permission : ' .. permission,
                })
                return
            end
        end

        handler(src, args, rawCommand)
    end, restricted and src ~= 0)
end

-- ================================================================
-- DIVERS
-- ================================================================

function QBCore.Functions.Notify(source, text, notifyType, length)
    TriggerClientEvent('ox_lib:notify', source, {
        title       = notifyType == 'error' and 'Erreur' or notifyType == 'success' and 'Succès' or 'Info',
        description = text,
        type        = notifyType or 'inform',
        duration    = length or 5000,
    })
end

function QBCore.Functions.GetIdentifier(source, idType)
    return GetPlayerIdentifierByType(source, idType or 'license')
end

function QBCore.Functions.GetPlayers()
    return GetPlayers()
end
