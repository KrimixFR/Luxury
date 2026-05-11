-- ================================================================
-- eightys_glovebox — Server
-- Boîte à gant persistante par plaque de véhicule
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Whitelist en lookup O(1)
local allowedSet = {}
for _, name in ipairs(Config.GloveBox.AllowedItems) do
    allowedSet[name] = true
end

-- ================================================================
-- INITIALISATION BASE DE DONNÉES
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS vehicle_glovebox (
            plate      VARCHAR(15) NOT NULL PRIMARY KEY,
            items      MEDIUMTEXT  NOT NULL DEFAULT '[]',
            updated_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    print('[eightys_glovebox] Boîte à gant initialisée.')
end)

-- ================================================================
-- HELPERS
-- ================================================================
local function loadBox(plate)
    local rows = MySQL.query.await('SELECT items FROM vehicle_glovebox WHERE plate = ?', { plate })
    if rows and rows[1] then
        local ok, t = pcall(json.decode, rows[1].items)
        return (ok and type(t) == 'table') and t or {}
    end
    return {}
end

local function saveBox(plate, items)
    MySQL.insert.await(
        'INSERT INTO vehicle_glovebox (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
        { plate, json.encode(items) }
    )
end

local function getTotalWeight(items)
    local w = 0
    for _, slot in ipairs(items) do
        local info = QBCore.Shared.Items[slot.name]
        if info then w = w + (info.weight or 0) * slot.amount end
    end
    return w
end

local function getSlotByName(items, name)
    for i, slot in ipairs(items) do
        if slot.name == name then return i, slot end
    end
    return nil, nil
end

-- Validation plaque : alphanumerique uniquement, 2-8 caractères
local function isValidPlate(plate)
    return type(plate) == 'string' and #plate >= 2 and #plate <= 8 and plate:match('^[A-Z0-9]+$') ~= nil
end

-- ================================================================
-- OUVRIR / CHARGER LA BOÎTE
-- ================================================================
RegisterNetEvent('eightys_glovebox:server:open', function(plate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not isValidPlate(plate) then return end

    local items  = loadBox(plate)
    local weight = getTotalWeight(items)
    TriggerClientEvent('eightys_glovebox:client:showMenu', src, plate, items, weight)
end)

-- ================================================================
-- DÉPOSER UN OBJET
-- ================================================================
RegisterNetEvent('eightys_glovebox:server:deposit', function(plate, itemName, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not isValidPlate(plate) then return end

    -- Validation de base
    itemName = tostring(itemName or '')
    amount   = math.floor(tonumber(amount) or 1)
    if amount < 1 or amount > 100 then return end

    -- Whitelist
    if not allowedSet[itemName] then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Boîte à gant',
            description = "Cet objet ne peut pas être rangé ici.",
            type        = 'error',
        })
        return
    end

    -- Le joueur possède bien l'objet
    local itemInfo = Player.Functions.GetItemByName(itemName)
    if not itemInfo or (itemInfo.amount or 0) < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Inventaire',
            description = "Vous n'avez pas assez de cet objet.",
            type        = 'error',
        })
        return
    end

    -- Charger la boîte
    local items  = loadBox(plate)
    local iInfo  = QBCore.Shared.Items[itemName]
    local addW   = (iInfo and iInfo.weight or 0) * amount

    -- Vérifier le poids
    if getTotalWeight(items) + addW > Config.GloveBox.MaxWeight then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Boîte pleine',
            description = string.format("Poids maximum atteint (%d g).", Config.GloveBox.MaxWeight),
            type        = 'error',
        })
        return
    end

    -- Vérifier les slots
    local idx, slot = getSlotByName(items, itemName)
    if not idx and #items >= Config.GloveBox.MaxSlots then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Boîte pleine',
            description = string.format("Maximum %d emplacements.", Config.GloveBox.MaxSlots),
            type        = 'error',
        })
        return
    end

    -- Retirer de l'inventaire
    Player.Functions.RemoveItem(itemName, amount)

    -- Ajouter dans la boîte
    if idx then
        items[idx].amount = items[idx].amount + amount
    else
        table.insert(items, {
            name   = itemName,
            label  = iInfo and iInfo.label or itemName,
            amount = amount,
        })
    end

    saveBox(plate, items)

    local newWeight = getTotalWeight(items)
    TriggerClientEvent('eightys_glovebox:client:showMenu', src, plate, items, newWeight)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'Boîte à gant',
        description = string.format('%s déposé(e).', iInfo and iInfo.label or itemName),
        type        = 'success',
    })

    print(string.format('[eightys_glovebox] Joueur %d dépose %dx %s (plaque: %s)', src, amount, itemName, plate))
end)

-- ================================================================
-- REPRENDRE UN OBJET
-- ================================================================
RegisterNetEvent('eightys_glovebox:server:withdraw', function(plate, itemName, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not isValidPlate(plate) then return end

    itemName = tostring(itemName or '')
    amount   = math.floor(tonumber(amount) or 1)
    if amount < 1 or amount > 100 then return end

    local items        = loadBox(plate)
    local idx, slot    = getSlotByName(items, itemName)

    if not idx or slot.amount < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Boîte à gant',
            description = "Quantité insuffisante dans la boîte.",
            type        = 'error',
        })
        return
    end

    -- Donner au joueur
    Player.Functions.AddItem(itemName, amount)

    -- Mettre à jour la boîte
    items[idx].amount = items[idx].amount - amount
    if items[idx].amount <= 0 then table.remove(items, idx) end

    saveBox(plate, items)

    local iInfo     = QBCore.Shared.Items[itemName]
    local newWeight = getTotalWeight(items)
    TriggerClientEvent('eightys_glovebox:client:showMenu', src, plate, items, newWeight)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'Boîte à gant',
        description = string.format('%s récupéré(e).', iInfo and iInfo.label or itemName),
        type        = 'success',
    })

    print(string.format('[eightys_glovebox] Joueur %d reprend %dx %s (plaque: %s)', src, amount, itemName, plate))
end)
