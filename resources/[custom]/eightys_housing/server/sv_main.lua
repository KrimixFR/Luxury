-- ================================================================
-- eightys_housing — Server
-- Location d'appartements, coffre personnel, point de respawn
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Index des appartements par id
local aptIndex = {}
for _, apt in ipairs(Config.Housing.Apartments) do
    aptIndex[apt.id] = apt
end

-- ================================================================
-- BASE DE DONNÉES
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS housing_rentals (
            citizenid  VARCHAR(50)  NOT NULL PRIMARY KEY,
            apt_id     VARCHAR(50)  NOT NULL,
            rented_at  BIGINT       NOT NULL,
            rent_paid  BIGINT       NOT NULL DEFAULT 0
        )
    ]])
    print('[eightys_housing] Système logements initialisé.')
end)

-- ================================================================
-- HELPERS
-- ================================================================
local function getRental(citizenid)
    local rows = MySQL.query.await('SELECT * FROM housing_rentals WHERE citizenid = ?', { citizenid })
    return rows and rows[1] or nil
end

local function getAptById(aptId)
    return aptIndex[aptId]
end

-- ================================================================
-- CHARGER LES DONNÉES AU LOGIN
-- ================================================================
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    local src    = Player.PlayerData.source
    local rental = getRental(Player.PlayerData.citizenid)
    if rental then
        TriggerClientEvent('eightys_housing:client:setRental', src, rental.apt_id)
    end
end)

RegisterNetEvent('eightys_housing:server:requestSync', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local rental = getRental(Player.PlayerData.citizenid)
    if rental then
        TriggerClientEvent('eightys_housing:client:setRental', src, rental.apt_id)
    end
end)

-- ================================================================
-- LOUER UN APPARTEMENT
-- ================================================================
RegisterNetEvent('eightys_housing:server:rent', function(aptId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local apt = getAptById(aptId)
    if not apt then return end

    local cid    = Player.PlayerData.citizenid
    local rental = getRental(cid)

    if rental then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Logement', description = 'Vous avez déjà un appartement.', type = 'error'
        })
        return
    end

    local cash = Player.PlayerData.money['cash'] or 0
    if cash < apt.price then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Fonds insuffisants',
            description = string.format('Il vous faut $%d de caution.', apt.price),
            type        = 'error',
        })
        return
    end

    Player.Functions.RemoveMoney('cash', apt.price, 'caution_appartement')

    MySQL.insert.await(
        'INSERT INTO housing_rentals (citizenid, apt_id, rented_at, rent_paid) VALUES (?, ?, ?, ?)',
        { cid, aptId, os.time(), os.time() }
    )

    TriggerClientEvent('eightys_housing:client:setRental', src, aptId)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🏠 Appartement loué !',
        description = apt.label .. ' — Caution de $' .. apt.price .. ' payée.',
        type        = 'success',
        duration    = 5000,
    })

    print(string.format('[eightys_housing] %s loue %s (caution $%d)', cid, aptId, apt.price))
end)

-- ================================================================
-- RÉSILIER LA LOCATION
-- ================================================================
RegisterNetEvent('eightys_housing:server:vacate', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid    = Player.PlayerData.citizenid
    MySQL.query.await('DELETE FROM housing_rentals WHERE citizenid = ?', { cid })
    TriggerClientEvent('eightys_housing:client:setRental', src, nil)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Logement', description = 'Vous avez quitté votre appartement.', type = 'inform'
    })
end)

-- ================================================================
-- PAYER LE LOYER HEBDOMADAIRE
-- ================================================================
-- Vérification toutes les heures (côté serveur) : si 7 jours écoulés
CreateThread(function()
    while true do
        Wait(3600000)  -- Toutes les heures
        local rows = MySQL.query.await('SELECT * FROM housing_rentals')
        if not rows then goto continue end

        local now = os.time()
        for _, rental in ipairs(rows) do
            local apt = getAptById(rental.apt_id)
            if apt then
                local weeklySeconds = 7 * 24 * 3600
                if now - rental.rent_paid >= weeklySeconds then
                    -- Tenter de prélever le loyer
                    local Player = QBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
                    if Player then
                        local cash  = Player.PlayerData.money['cash'] or 0
                        local bank  = Player.PlayerData.money['bank'] or 0
                        local total = cash + bank
                        if total >= apt.rent then
                            -- Prélever en priorité sur le cash, puis la banque
                            local fromCash = math.min(cash, apt.rent)
                            local fromBank = apt.rent - fromCash
                            if fromCash > 0 then Player.Functions.RemoveMoney('cash', fromCash, 'loyer') end
                            if fromBank > 0 then Player.Functions.RemoveMoney('bank', fromBank, 'loyer') end
                            MySQL.update.await('UPDATE housing_rentals SET rent_paid = ? WHERE citizenid = ?',
                                { now, rental.citizenid })
                            TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                                title       = '🏠 Loyer prélevé',
                                description = string.format('$%d déduits pour %s.', apt.rent, apt.label),
                                type        = 'inform', duration = 6000,
                            })
                        else
                            -- Pas assez d'argent → expulsion
                            MySQL.query.await('DELETE FROM housing_rentals WHERE citizenid = ?', { rental.citizenid })
                            TriggerClientEvent('eightys_housing:client:setRental', Player.PlayerData.source, nil)
                            TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                                title       = '🏠 Expulsion',
                                description = 'Vous n\'avez pas pu payer le loyer. Vous êtes expulsé(e).',
                                type        = 'error', duration = 8000,
                            })
                        end
                    end
                end
            end
        end
        ::continue::
    end
end)

-- ================================================================
-- POINT DE RESPAWN
-- ================================================================
RegisterNetEvent('eightys_housing:server:setSpawn', function(aptId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid    = Player.PlayerData.citizenid
    local rental = getRental(cid)
    if not rental or rental.apt_id ~= aptId then return end
    Player.Functions.SetMetaData('spawn_apt', aptId)
end)

-- Appliquer le spawn sauvegardé au chargement
RegisterNetEvent('eightys_housing:server:applySpawn', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local aptId  = Player.PlayerData.metadata['spawn_apt']
    if aptId and aptIndex[aptId] then
        TriggerClientEvent('eightys_housing:client:spawnInside', src, aptId)
    end
end)

-- ================================================================
-- COFFRE PERSONNEL — Accès via ox_lib stash
-- ================================================================
RegisterNetEvent('eightys_housing:server:openStash', function(aptId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid    = Player.PlayerData.citizenid
    local rental = getRental(cid)
    if not rental or rental.apt_id ~= aptId then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Accès refusé', type = 'error' })
        return
    end

    -- Utiliser ox_lib stash (unique par citizenid + aptId)
    local stashId = 'housing_' .. cid .. '_' .. aptId
    exports.ox_inventory:RegisterStash(stashId, 'Coffre — ' .. (aptIndex[aptId] and aptIndex[aptId].label or aptId),
        Config.Housing.StashSlots, Config.Housing.StashMaxWeight, false, nil, { src })
    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
end)
