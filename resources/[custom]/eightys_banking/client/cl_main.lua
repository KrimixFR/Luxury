-- ================================================================
-- eightys_banking — Client
-- ATM (NUI), guichet bancaire, blips, interaction
-- ================================================================

local QBCore       = exports['qb-core']:GetCoreObject()
local atmOpen      = false
local myAccount    = { balance=0, hasCard=false, hasPin=false, last4=nil, blocked=false }

-- ================================================================
-- SYNC COMPTE
-- ================================================================
RegisterNetEvent('eightys_banking:client:accountData', function(data)
    myAccount = data
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    TriggerServerEvent('eightys_banking:server:requestSync')
end)

-- ================================================================
-- BLIPS
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    for _, branch in ipairs(Config.Banking.Branches) do
        local b = AddBlipForCoord(branch.coords.x, branch.coords.y, branch.coords.z)
        SetBlipSprite(b, 207); SetBlipScale(b, 0.8); SetBlipColour(b, 2)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(branch.label)
        EndTextCommandSetBlipName(b)
    end

    for _, coords in ipairs(Config.Banking.ATMs) do
        local b = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(b, 277); SetBlipScale(b, 0.6); SetBlipColour(b, 2)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Distributeur Fleeca")
        EndTextCommandSetBlipName(b)
    end
end)

-- ================================================================
-- ATM — Interaction
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, atm in ipairs(Config.Banking.ATMs) do
            if #(coords - atm) < 12.0 then
                sleep = 0
                if #(coords - atm) < 1.8 then
                    DrawText3D(atm.x, atm.y, atm.z + 0.6, "[E] Utiliser le distributeur")
                    if IsControlJustReleased(0, 38) and not atmOpen then
                        openATM()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 200, 0, 215); SetTextEntry("STRING"); SetTextCentre(true)
    AddTextComponentString(text); DrawText(sx, sy)
end

function openATM()
    -- Collecter les cartes en inventaire
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not pd.items then return end

    local cards = {}
    for _, item in pairs(pd.items) do
        if (item.name == 'bank_card' or item.name == 'business_card') and item.info then
            table.insert(cards, {
                name         = item.name,
                account_type = item.name == 'bank_card' and 'personal' or 'business',
                citizenid    = item.info.citizenid,
                business_id  = item.info.business_id,
                business_name= item.info.business_name,
                last4        = item.info.last4,
                owner        = item.info.owner,
            })
        end
    end

    if #cards == 0 then
        lib.notify({ title='💳 Distributeur', description="Vous n'avez aucune carte bancaire.", type='error' })
        return
    end

    atmOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type='OPEN_ATM', cards=cards })
end

-- NUI callbacks
RegisterNUICallback('atm_verifyPin', function(data, cb)
    TriggerServerEvent('eightys_banking:server:atmVerifyPin', data.card, data.pin)
    cb('ok')
end)

RegisterNUICallback('atm_withdraw', function(data, cb)
    TriggerServerEvent('eightys_banking:server:atmWithdraw', data.card, data.pin, data.amount)
    cb('ok')
end)

RegisterNUICallback('atm_close', function(_, cb)
    atmOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('eightys_banking:client:atmResult', function(result)
    SendNUIMessage({ type='ATM_RESULT', result=result })
end)

-- ================================================================
-- GUICHET BANCAIRE — Interaction
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, branch in ipairs(Config.Banking.Branches) do
            if #(coords - branch.coords) < 15.0 then
                sleep = 0
                if #(coords - branch.coords) < 2.5 then
                    DrawMarker(20, branch.coords.x, branch.coords.y, branch.coords.z - 0.95,
                        0,0,0,0,0,0,0.6,0.6,0.3, 50,180,255,80, false,true,2,false,nil,nil,false)
                    DrawText3D(branch.coords.x, branch.coords.y, branch.coords.z + 0.5,
                        "[E] " .. branch.label .. " — Guichet")
                    if IsControlJustReleased(0, 38) then
                        openBranchMenu(branch.label)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function openBranchMenu(branchLabel)
    local pd      = QBCore.Functions.GetPlayerData()
    local job     = pd and pd.job
    local options = {}

    -- Solde
    table.insert(options, {
        title       = string.format('Solde : $%s', myAccount.balance),
        icon        = 'building-columns',
        disabled    = true,
    })
    table.insert(options, { title='──────────────', disabled=true })

    -- Dépôt
    table.insert(options, {
        title       = 'Déposer du cash',
        icon        = 'arrow-right-to-bracket',
        description = 'Mettre de l\'argent sur votre compte',
        onSelect    = function()
            local input = lib.inputDialog('Dépôt — ' .. branchLabel, {
                { type='number', label='Montant ($)', min=Config.Banking.DepositMin, required=true },
            })
            if input and input[1] then
                TriggerServerEvent('eightys_banking:server:deposit', tonumber(input[1]))
            end
        end,
    })

    -- Retrait
    table.insert(options, {
        title       = 'Retirer du cash',
        icon        = 'arrow-right-from-bracket',
        description = 'Récupérer de l\'argent en espèces',
        onSelect    = function()
            local input = lib.inputDialog('Retrait — ' .. branchLabel, {
                { type='number', label='Montant ($)', min=Config.Banking.WithdrawMin, max=Config.Banking.WithdrawMax, required=true },
            })
            if input and input[1] then
                TriggerServerEvent('eightys_banking:server:withdraw', tonumber(input[1]))
            end
        end,
    })

    table.insert(options, { title='──────────────', disabled=true })

    -- Carte
    if not myAccount.hasCard then
        table.insert(options, {
            title    = 'Obtenir une carte bancaire',
            icon     = 'credit-card',
            onSelect = function()
                TriggerServerEvent('eightys_banking:server:issueCard')
            end,
        })
    else
        table.insert(options, {
            title       = string.format('Carte **** %s', myAccount.last4 or '????'),
            icon        = 'credit-card',
            description = myAccount.blocked and '⚠ Carte bloquée' or (myAccount.hasPin and 'PIN configuré' or 'Aucun PIN défini'),
            onSelect    = function() openCardMenu() end,
        })
    end

    -- Compte entreprise (si patron)
    if job and job.grade then
        local maxGrade = 0
        if Config.Jobs and Config.Jobs[job.name] then
            for g, _ in pairs(Config.Jobs[job.name].grades or {}) do
                if g > maxGrade then maxGrade = g end
            end
        end
        if job.grade.level >= maxGrade and maxGrade > 0 then
            table.insert(options, { title='──────────────', disabled=true })
            table.insert(options, {
                title    = 'Compte entreprise',
                icon     = 'briefcase',
                onSelect = function() openBusinessMenu(job.name, job.label) end,
            })
        end
    end

    lib.registerContext({ id='bank_counter', title='🏦 '..branchLabel, options=options })
    lib.showContext('bank_counter')
end

function openCardMenu()
    local options = {}

    if myAccount.hasPin then
        table.insert(options, {
            title='Changer le code PIN', icon='key',
            onSelect=function() promptSetPin('personal', nil) end,
        })
    else
        table.insert(options, {
            title='Définir un code PIN', icon='key',
            description='Obligatoire pour utiliser un distributeur',
            onSelect=function() promptSetPin('personal', nil) end,
        })
    end

    if myAccount.blocked then
        table.insert(options, {
            title='Débloquer ma carte', icon='unlock',
            onSelect=function()
                TriggerServerEvent('eightys_banking:server:unblockCard', 'personal', nil)
            end,
        })
    end

    lib.registerContext({ id='bank_card_menu', title='💳 Ma carte', menu='bank_counter', options=options })
    lib.showContext('bank_card_menu')
end

function openBusinessMenu(jobName, jobLabel)
    local options = {}
    table.insert(options, {
        title='Créer un compte entreprise', icon='building',
        description='Compte séparé pour '..jobLabel,
        onSelect=function()
            TriggerServerEvent('eightys_banking:server:createBusiness', jobName, jobLabel)
        end,
    })
    table.insert(options, {
        title='Déposer sur le compte entreprise', icon='arrow-right-to-bracket',
        onSelect=function()
            local input = lib.inputDialog('Dépôt entreprise — '..jobLabel, {
                { type='number', label='Montant ($)', min=Config.Banking.DepositMin, required=true },
            })
            if input and input[1] then
                TriggerServerEvent('eightys_banking:server:businessDeposit', jobName, tonumber(input[1]))
            end
        end,
    })
    table.insert(options, {
        title='Changer le PIN entreprise', icon='key',
        onSelect=function() promptSetPin('business', jobName) end,
    })
    lib.registerContext({ id='bank_business_menu', title='🏢 Compte '..jobLabel, menu='bank_counter', options=options })
    lib.showContext('bank_business_menu')
end

function promptSetPin(accountType, businessId)
    local input = lib.inputDialog('Définir un code PIN', {
        { type='number', label='Code PIN (4 chiffres)', placeholder='Ex : 1987', min=1000, max=9999, required=true },
    })
    if input and input[1] then
        TriggerServerEvent('eightys_banking:server:setPin', tostring(input[1]), accountType, businessId)
    end
end
