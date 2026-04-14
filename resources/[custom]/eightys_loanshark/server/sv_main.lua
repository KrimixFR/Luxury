-- ================================================================
-- EIGHTYS LOANSHARK — Server
-- Los Santos 1987 — Prêteur usurier
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local C = Config.LoanShark or {
    MinLoan             = 500,
    MaxLoan             = 25000,
    InterestRatePerCycle = 0.15,  -- 15% par cycle
    CycleDuration       = 7200,   -- 2h réelles = 1 "jour"
    GraceCycles         = 1,      -- 1 cycle de grâce avant intérêts
    MaxLoans            = 1,
}

-- ================================================================
-- DB INIT
-- ================================================================

MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS loans (
        id           INT AUTO_INCREMENT PRIMARY KEY,
        citizenid    VARCHAR(50) NOT NULL,
        amount       BIGINT NOT NULL,
        remaining    BIGINT NOT NULL,
        borrowed_at  BIGINT NOT NULL,
        due_at       BIGINT NOT NULL,
        last_interest BIGINT NOT NULL,
        paid         BOOLEAN NOT NULL DEFAULT FALSE
    )
]])

-- ================================================================
-- HELPERS
-- ================================================================

local function GetActiveLoan(citizenid)
    local loans = MySQL.query.await('SELECT * FROM loans WHERE citizenid=? AND paid=FALSE LIMIT 1', { citizenid })
    if loans and #loans > 0 then
        return loans[1]
    end
    return nil
end

local function BuildSyncData(loan)
    if not loan then
        return { hasLoan = false, amount = 0, remaining = 0, dueIn = 0 }
    end
    local dueIn = loan.due_at - os.time()
    return {
        hasLoan   = true,
        amount    = loan.amount,
        remaining = loan.remaining,
        dueIn     = dueIn,
    }
end

local function SyncToPlayer(source, loan)
    TriggerClientEvent('eightys_loanshark:client:sync', source, BuildSyncData(loan))
end

-- ================================================================
-- EVENT: requestSync
-- ================================================================

RegisterNetEvent('eightys_loanshark:server:requestSync', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local loan = GetActiveLoan(Player.PlayerData.citizenid)
    SyncToPlayer(src, loan)
end)

-- ================================================================
-- EVENT: takeLoan
-- ================================================================

RegisterNetEvent('eightys_loanshark:server:takeLoan', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Vérifier pas de prêt en cours
    local existing = GetActiveLoan(citizenid)
    if existing then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = 'Vous avez déjà un prêt en cours. Remboursez-le d\'abord.',
            type        = 'error',
            duration    = 6000,
        })
        return
    end

    -- Valider le montant
    amount = math.floor(tonumber(amount) or 0)
    if amount < C.MinLoan or amount > C.MaxLoan then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = string.format('Le montant doit être entre $%d et $%d.', C.MinLoan, C.MaxLoan),
            type        = 'error',
            duration    = 6000,
        })
        return
    end

    local now    = os.time()
    local due_at = now + C.CycleDuration * C.GraceCycles

    -- Insérer en DB
    MySQL.insert.await(
        'INSERT INTO loans (citizenid, amount, remaining, borrowed_at, due_at, last_interest, paid) VALUES (?,?,?,?,?,?,FALSE)',
        { citizenid, amount, amount, now, due_at, now }
    )

    -- Donner l'argent
    Player.Functions.AddMoney('cash', amount, 'loan_shark')

    -- Notification avec date d'échéance lisible
    local dateStr = os.date('%d/%m %H:%M', due_at)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'Prêteur usurier',
        description = string.format('Vous avez emprunté $%d. Remboursez avant le %s.', amount, dateStr),
        type        = 'success',
        duration    = 8000,
    })

    -- Sync client
    local loan = GetActiveLoan(citizenid)
    SyncToPlayer(src, loan)
end)

-- ================================================================
-- EVENT: repay
-- ================================================================

RegisterNetEvent('eightys_loanshark:server:repay', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Vérifier prêt en cours
    local loan = GetActiveLoan(citizenid)
    if not loan then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = 'Vous n\'avez aucun prêt en cours.',
            type        = 'error',
            duration    = 5000,
        })
        return
    end

    -- Valider le montant
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = 'Montant invalide.',
            type        = 'error',
            duration    = 4000,
        })
        return
    end

    -- Plafonner au remaining
    if amount > loan.remaining then
        amount = loan.remaining
    end

    -- Vérifier que le joueur a assez de cash
    local playerCash = Player.PlayerData.money['cash']
    if playerCash < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = string.format('Vous n\'avez pas assez de cash. Vous avez $%d.', playerCash),
            type        = 'error',
            duration    = 6000,
        })
        return
    end

    -- Retirer le cash
    Player.Functions.RemoveMoney('cash', amount, 'loan_shark_repay')

    local newRemaining = loan.remaining - amount

    if newRemaining <= 0 then
        -- Prêt entièrement remboursé
        MySQL.update.await('UPDATE loans SET remaining=0, paid=TRUE WHERE id=?', { loan.id })
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = 'Dette entièrement remboursée ! Vous êtes libéré.',
            type        = 'success',
            duration    = 8000,
        })
        SyncToPlayer(src, nil)
    else
        -- Remboursement partiel
        MySQL.update.await('UPDATE loans SET remaining=? WHERE id=?', { newRemaining, loan.id })
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Prêteur usurier',
            description = string.format('Remboursement partiel de $%d. Il vous reste $%d à rembourser.', amount, newRemaining),
            type        = 'warning',
            duration    = 7000,
        })
        loan.remaining = newRemaining
        SyncToPlayer(src, loan)
    end
end)

-- ================================================================
-- THREAD D'INTÉRÊTS (toutes les 5 minutes)
-- ================================================================

CreateThread(function()
    while true do
        Wait(300000) -- 5 min
        local now   = os.time()
        local loans = MySQL.query.await('SELECT * FROM loans WHERE paid=FALSE')
        for _, loan in ipairs(loans or {}) do
            -- Appliquer les intérêts si le cycle est écoulé
            if now - loan.last_interest >= C.CycleDuration then
                local interest      = math.floor(loan.remaining * C.InterestRatePerCycle)
                local newRemaining  = loan.remaining + interest
                MySQL.update.await(
                    'UPDATE loans SET remaining=?, last_interest=? WHERE id=?',
                    { newRemaining, now, loan.id }
                )
                -- Notifier le joueur s'il est connecté
                local Player = QBCore.Functions.GetPlayerByCitizenId(loan.citizenid)
                if Player then
                    TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                        title       = 'Prêteur usurier',
                        description = string.format('Intérêts appliqués (+$%d). Vous devez maintenant $%d.', interest, newRemaining),
                        type        = 'error',
                        duration    = 8000,
                    })
                    TriggerClientEvent('eightys_loanshark:client:sync', Player.PlayerData.source, {
                        hasLoan   = true,
                        remaining = newRemaining,
                    })
                end
            end

            -- Envoyer le collecteur si overdue de plus de 2 cycles
            if now > loan.due_at + C.CycleDuration * 2 then
                local Player = QBCore.Functions.GetPlayerByCitizenId(loan.citizenid)
                if Player then
                    TriggerClientEvent('eightys_loanshark:client:collectorWarning', Player.PlayerData.source)
                end
            end
        end
    end
end)

-- ================================================================
-- SYNC AU LOGIN
-- ================================================================

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src  = Player.PlayerData.source
    local loan = GetActiveLoan(Player.PlayerData.citizenid)
    SyncToPlayer(src, loan)
end)
