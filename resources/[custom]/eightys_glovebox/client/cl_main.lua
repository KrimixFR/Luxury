-- ================================================================
-- eightys_glovebox — Client
-- Boîte à gant : stocker de petits objets dans son véhicule
-- ================================================================

local QBCore       = exports['qb-core']:GetCoreObject()
local currentPlate = nil

-- Lookup whitelist côté client (pour filtrer l'inventaire sans aller serveur)
local allowedSet = {}
for _, name in ipairs(Config.GloveBox.AllowedItems) do
    allowedSet[name] = true
end

-- ================================================================
-- OUVRIR LA BOÎTE À GANT
-- ================================================================
RegisterCommand('glovebox', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        lib.notify({ title = 'Boîte à gant', description = 'Vous devez être dans un véhicule.', type = 'error' })
        return
    end

    -- Récupérer la plaque, supprimer les espaces GTA
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    currentPlate = plate
    TriggerServerEvent('eightys_glovebox:server:open', plate)
end, false)

RegisterKeyMapping('glovebox', 'Ouvrir la boîte à gant', 'keyboard', Config.GloveBox.OpenKey)

-- ================================================================
-- AFFICHER LE MENU PRINCIPAL
-- ================================================================
RegisterNetEvent('eightys_glovebox:client:showMenu', function(plate, items, weight)
    currentPlate = plate
    local maxSlots = Config.GloveBox.MaxSlots
    local maxW     = Config.GloveBox.MaxWeight
    local options  = {}

    -- Contenu de la boîte
    if #items > 0 then
        for _, slot in ipairs(items) do
            local s = slot
            table.insert(options, {
                title       = string.format('%s', s.label or s.name),
                icon        = 'box-open',
                description = string.format('Quantité : %d — Cliquer pour reprendre', s.amount),
                onSelect    = function()
                    if s.amount > 1 then
                        local input = lib.inputDialog('Reprendre — ' .. (s.label or s.name), {
                            { type = 'number', label = 'Quantité', default = 1, min = 1, max = s.amount, required = true },
                        })
                        if input and input[1] then
                            TriggerServerEvent('eightys_glovebox:server:withdraw', plate, s.name, tonumber(input[1]))
                        end
                    else
                        TriggerServerEvent('eightys_glovebox:server:withdraw', plate, s.name, 1)
                    end
                end,
            })
        end
    else
        table.insert(options, {
            title    = '— Boîte vide —',
            icon     = 'inbox',
            disabled = true,
        })
    end

    -- Séparateur
    table.insert(options, { title = '──────────────', disabled = true })

    -- Bouton dépôt
    table.insert(options, {
        title       = 'Déposer un objet',
        icon        = 'arrow-right-to-bracket',
        description = 'Choisir dans votre inventaire',
        onSelect    = function()
            openDepositMenu(plate)
        end,
    })

    lib.registerContext({
        id      = 'glovebox_main',
        title   = string.format('Boîte à gant [%s]  %d/%d — %dg/%dg',
                    plate, #items, maxSlots, weight, maxW),
        options = options,
    })
    lib.showContext('glovebox_main')
end)

-- ================================================================
-- MENU DE DÉPÔT — liste des objets compatibles en inventaire
-- ================================================================
function openDepositMenu(plate)
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not pd.items then
        lib.notify({ title = 'Boîte à gant', description = 'Inventaire inaccessible.', type = 'error' })
        return
    end

    local options = {}

    for _, item in pairs(pd.items) do
        if allowedSet[item.name] and (item.amount or 0) > 0 then
            local it = item
            table.insert(options, {
                title       = string.format('%s', it.label or it.name),
                icon        = 'circle-arrow-right',
                description = string.format('En poche : %d', it.amount),
                onSelect    = function()
                    if it.amount > 1 then
                        local input = lib.inputDialog('Déposer — ' .. (it.label or it.name), {
                            { type = 'number', label = 'Quantité', default = 1, min = 1, max = it.amount, required = true },
                        })
                        if input and input[1] then
                            TriggerServerEvent('eightys_glovebox:server:deposit', plate, it.name, tonumber(input[1]))
                        end
                    else
                        TriggerServerEvent('eightys_glovebox:server:deposit', plate, it.name, 1)
                    end
                end,
            })
        end
    end

    if #options == 0 then
        lib.notify({
            title       = 'Boîte à gant',
            description = 'Aucun objet compatible dans votre inventaire.',
            type        = 'inform',
        })
        return
    end

    lib.registerContext({
        id      = 'glovebox_deposit',
        title   = 'Déposer dans la boîte à gant',
        menu    = 'glovebox_main',   -- flèche retour vers le menu principal
        options = options,
    })
    lib.showContext('glovebox_deposit')
end
