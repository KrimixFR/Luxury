-- ================================================================
-- eightys_informants — Client
-- Menus indic (commissariat), tips policiers, pots-de-vin
-- ================================================================

local QBCore       = exports['qb-core']:GetCoreObject()
local isInformant  = false
local policeStation = vector3(441.9, -982.2, 30.7) -- LAPD HQ

local POLICE_JOBS = { police = true, vicesquad = true }

-- ================================================================
-- HELPERS
-- ================================================================
function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 215); SetTextEntry("STRING"); SetTextCentre(true)
    AddTextComponentString(text); DrawText(sx, sy)
end

local function isPolice()
    local pd  = QBCore.Functions.GetPlayerData()
    local job = pd and pd.job
    return job and POLICE_JOBS[job.name]
end

-- ================================================================
-- SYNC
-- ================================================================
RegisterNetEvent('eightys_informants:client:registered', function()
    isInformant = true
end)

-- ================================================================
-- AFFICHAGE DES TIPS (flic uniquement)
-- ================================================================
RegisterNetEvent('eightys_informants:client:showTips', function(tips)
    if #tips == 0 then
        lib.notify({ title='Tips', description='Aucun tip en attente.', type='info' })
        return
    end

    local options = {}
    for _, tip in ipairs(tips) do
        local dateStr = os.date('%H:%M', tip.created_at)
        table.insert(options, {
            title       = string.format('[%s] %s', dateStr, tip.target_name),
            description = string.format('%s — %s', tip.activity or '?', tip.location or '?'),
            icon        = 'phone',
            onSelect    = function()
                TriggerServerEvent('eightys_informants:server:validateTip', tip.id)
            end,
        })
    end

    lib.registerContext({ id='tips_list', title='📞 Tips en attente', options=options })
    lib.showContext('tips_list')
end)

-- ================================================================
-- OFFRE DE POT-DE-VIN REÇUE (flic)
-- ================================================================
RegisterNetEvent('eightys_informants:client:bribeOffer', function(data)
    local options = {
        {
            title       = string.format('Accepter $%d de %s', data.amount, data.fromName),
            icon        = 'check',
            onSelect    = function()
                TriggerServerEvent('eightys_informants:server:bribeResponse', data.fromSrc, true, data.amount)
            end,
        },
        {
            title    = 'Refuser',
            icon     = 'xmark',
            onSelect = function()
                TriggerServerEvent('eightys_informants:server:bribeResponse', data.fromSrc, false, data.amount)
            end,
        },
    }
    lib.registerContext({ id='bribe_offer', title='💸 Offre de pot-de-vin', options=options })
    lib.showContext('bribe_offer')
end)

-- ================================================================
-- MENU CIVIL — Commissariat (indic + pot-de-vin)
-- ================================================================
local function openCivilMenu()
    local options = {}

    if not isInformant then
        table.insert(options, {
            title       = 'Devenir informateur',
            icon        = 'user-secret',
            description = 'Signalez des activités criminelles contre $300 par tip validé',
            onSelect    = function()
                lib.registerContext({
                    id      = 'informant_confirm',
                    title   = '⚠ Confirmation',
                    options = {{
                        title       = 'Confirmer — Je travaillerai pour le LAPD',
                        icon        = 'check',
                        description = 'Attention : si les criminels l\'apprennent, vous serez en danger.',
                        onSelect    = function()
                            TriggerServerEvent('eightys_informants:server:register')
                        end,
                    }},
                })
                lib.showContext('informant_confirm')
            end,
        })
    else
        table.insert(options, {
            title       = 'Soumettre un tip',
            icon        = 'phone',
            description = 'Signaler une activité criminelle',
            onSelect    = function()
                local input = lib.inputDialog('Tip au LAPD', {
                    { type='input',  label='Nom du suspect',      required=true  },
                    { type='input',  label='Activité observée',   required=true  },
                    { type='input',  label='Lieu',                required=false },
                })
                if input and input[1] and input[2] then
                    TriggerServerEvent('eightys_informants:server:submitTip', input[1], input[2], input[3])
                end
            end,
        })
    end

    table.insert(options, {
        title       = 'Proposer un pot-de-vin à un officier',
        icon        = 'money-bill',
        description = 'Ciblez un officier à proximité (risqué)',
        onSelect    = function()
            -- Chercher un flic proche
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local players = QBCore.Functions.GetPlayers and {} or {}

            local input = lib.inputDialog('Pot-de-vin', {
                { type='number', label='Montant ($200 – $10,000)', min=200, max=10000, required=true },
                { type='input',  label='ID du serveur du flic (affiché au-dessus de lui)', required=true },
            })
            if input and input[1] and input[2] then
                local copSrc = tonumber(input[2])
                if copSrc then
                    TriggerServerEvent('eightys_informants:server:offerBribe', copSrc, tonumber(input[1]))
                end
            end
        end,
    })

    lib.registerContext({ id='civil_police_menu', title='🏛 LAPD — Hall d\'accueil', options=options })
    lib.showContext('civil_police_menu')
end

-- ================================================================
-- MENU FLIC — Tips en attente
-- ================================================================
local function openPoliceMenu()
    local options = {
        {
            title    = 'Consulter les tips',
            icon     = 'phone',
            description = 'Voir les signalements des informateurs',
            onSelect = function()
                TriggerServerEvent('eightys_informants:server:listTips')
            end,
        },
    }
    lib.registerContext({ id='police_tips_menu', title='📞 Tips informateurs', options=options })
    lib.showContext('police_tips_menu')
end

-- ================================================================
-- THREAD PROXIMITÉ — Commissariat
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist   = #(coords - policeStation)

        if dist < 20.0 then
            sleep = 0
            if dist < 3.0 then
                if isPolice() then
                    DrawText3D(policeStation.x, policeStation.y, policeStation.z + 1.0, '[E] Tips informateurs')
                    if IsControlJustReleased(0, 38) then openPoliceMenu() end
                else
                    DrawText3D(policeStation.x, policeStation.y, policeStation.z + 1.0, '[E] Hall d\'accueil LAPD')
                    if IsControlJustReleased(0, 38) then openCivilMenu() end
                end
            end
        end
        Wait(sleep)
    end
end)
