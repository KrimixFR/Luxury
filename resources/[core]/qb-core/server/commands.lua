-- ================================================================
-- QBCore — server/commands.lua
-- Commandes serveur utilitaires
-- ================================================================

-- /players — Liste les joueurs connectés
RegisterCommand('players', function(source, args)
    local src = source
    if src ~= 0 and not QBCore.Functions.HasPermission(src, 'admin') then return end

    local count = 0
    local msg = 'Joueurs connectés :\n'
    for playerId, Player in pairs(QBCore.Players) do
        count = count + 1
        msg = msg .. string.format('  [%d] %s — %s (%s)\n',
            playerId,
            Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            Player.PlayerData.job.label,
            Player.PlayerData.citizenid)
    end
    msg = msg .. string.format('Total : %d joueur(s).', count)
    print(msg)
end, true)

-- /saveall — Sauvegarder tous les joueurs
RegisterCommand('saveall', function(source)
    if source ~= 0 and not QBCore.Functions.HasPermission(source, 'admin') then return end
    local count = 0
    for _, Player in pairs(QBCore.Players) do
        Player.Functions.Save()
        count = count + 1
    end
    print(string.format('[QBCore] Sauvegarde : %d joueur(s) sauvegardés.', count))
end, true)

-- Sauvegarde automatique toutes les 5 minutes
CreateThread(function()
    while true do
        Wait(300000)
        local count = 0
        for _, Player in pairs(QBCore.Players) do
            Player.Functions.Save()
            count = count + 1
        end
        if count > 0 then
            print(string.format('[QBCore] Sauvegarde automatique : %d joueur(s).', count))
        end
    end
end)
