-- ================================================================
-- eightys_needs — Server
-- Faim, soif, péremption des aliments, épiceries
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Index rapide des aliments
local foodIndex = {}
for name, data in pairs(Config.Needs.Foods) do
    foodIndex[name] = data
end

-- ================================================================
-- HELPERS — Métadonnées joueur
-- ================================================================
local function getNeeds(Player)
    local hunger = Player.PlayerData.metadata['hunger']
    local thirst = Player.PlayerData.metadata['thirst']
    return tonumber(hunger) or 100, tonumber(thirst) or 100
end

local function setNeeds(Player, hunger, thirst)
    hunger = math.max(0, math.min(100, math.floor(hunger)))
    thirst = math.max(0, math.min(100, math.floor(thirst)))
    Player.Functions.SetMetaData('hunger', hunger)
    Player.Functions.SetMetaData('thirst', thirst)
    TriggerClientEvent('eightys_needs:client:update', Player.PlayerData.source, hunger, thirst)
end

-- ================================================================
-- DÉCROISSANCE — Tick toutes les 5 minutes
-- ================================================================
CreateThread(function()
    while true do
        Wait(Config.Needs.TickInterval)
        local players = QBCore.Functions.GetPlayers()
        for _, src in ipairs(players) do
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                local hunger, thirst = getNeeds(Player)
                setNeeds(Player,
                    hunger - Config.Needs.HungerDecay,
                    thirst - Config.Needs.ThirstDecay
                )
            end
        end
    end
end)

-- ================================================================
-- ITEMS ALIMENTAIRES — Enregistrement comme utilisables
-- ================================================================
for itemName, foodData in pairs(foodIndex) do
    local name = itemName
    local data = foodData

    QBCore.Functions.CreateUseableItem(name, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end

        -- Vérifier la péremption
        local expires = item.info and item.info.expires
        local isExpired = expires and expires > 0 and os.time() > expires

        if isExpired then
            -- Retirer quand même l'item (il est consommé même pourri)
            Player.Functions.RemoveItem(name, 1, item.slot)
            TriggerClientEvent('eightys_needs:client:illness', source, Config.Needs.IllnessDuration)
            TriggerClientEvent('ox_lib:notify', source, {
                title       = '🤢 Intoxication alimentaire',
                description = 'Cette nourriture était périmée...',
                type        = 'error',
                duration    = 5000,
            })
            print(string.format('[eightys_needs] Joueur %d a mangé %s périmé (expiré le %s)',
                source, name, os.date('%d/%m/%Y %H:%M', expires)))
            return
        end

        -- Consommer l'item
        Player.Functions.RemoveItem(name, 1, item.slot)

        local hunger, thirst = getNeeds(Player)
        setNeeds(Player, hunger + data.hunger, thirst + data.thirst)

        -- Notifier le client pour l'animation
        TriggerClientEvent('eightys_needs:client:eat', source, name, data.hunger > 0)

        -- Affichage selon les valeurs
        local newHunger, newThirst = getNeeds(QBCore.Functions.GetPlayer(source))
        TriggerClientEvent('ox_lib:notify', source, {
            title    = data.hunger > 0 and 'Repas' or 'Boisson',
            description = string.format('Faim : %d%%  •  Soif : %d%%', newHunger, newThirst),
            type     = 'inform',
            duration = 3000,
        })
    end)
end

-- ================================================================
-- ÉPICERIE — Achat d'aliments avec date de péremption
-- ================================================================
RegisterNetEvent('eightys_needs:server:buyFood', function(itemName, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 or amount > 10 then return end

    -- Vérifier que c'est un item du catalogue
    local shopItem = nil
    for _, si in ipairs(Config.Needs.ShopItems) do
        if si.name == itemName then shopItem = si; break end
    end
    if not shopItem then return end

    local foodData = foodIndex[itemName]
    if not foodData then return end

    local totalPrice = shopItem.price * amount
    local cash = Player.PlayerData.money['cash'] or 0

    if cash < totalPrice then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Fonds insuffisants',
            description = string.format('Il vous faut $%d.', totalPrice),
            type        = 'error',
        })
        return
    end

    Player.Functions.RemoveMoney('cash', totalPrice, 'achat_nourriture')

    -- Donner les items avec date de péremption dans info
    local expires = foodData.expiresIn > 0 and (os.time() + foodData.expiresIn) or 0
    for i = 1, amount do
        Player.Functions.AddItem(itemName, 1, nil, { expires = expires })
    end

    local expiryStr = expires > 0
        and ('Périme le ' .. os.date('%d/%m/%Y', expires))
        or  'Ne périme pas'

    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'Achat',
        description = string.format('%dx %s — $%d\n%s', amount, itemName, totalPrice, expiryStr),
        type        = 'success',
        duration    = 4000,
    })
end)

-- ================================================================
-- SYNC AU CHARGEMENT DU JOUEUR
-- ================================================================
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local hunger, thirst = getNeeds(Player)
    TriggerClientEvent('eightys_needs:client:update', src, hunger, thirst)
end)

-- Compat : sync aussi sur demande client
RegisterNetEvent('eightys_needs:server:requestSync', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local hunger, thirst = getNeeds(Player)
    TriggerClientEvent('eightys_needs:client:update', src, hunger, thirst)
end)
