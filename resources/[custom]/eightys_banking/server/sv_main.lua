-- ================================================================
-- eightys_banking — Server
-- Comptes personnels & entreprise, cartes CB, PIN, transactions
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- BASE DE DONNÉES
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS bank_accounts (
            citizenid     VARCHAR(50)  NOT NULL PRIMARY KEY,
            balance       BIGINT       NOT NULL DEFAULT 0,
            card_number   VARCHAR(16)  UNIQUE,
            pin           VARCHAR(4)   DEFAULT NULL,
            blocked       BOOLEAN      NOT NULL DEFAULT FALSE,
            attempts      TINYINT      NOT NULL DEFAULT 0,
            blocked_until BIGINT       NOT NULL DEFAULT 0
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS bank_business (
            business_id   VARCHAR(50)  NOT NULL PRIMARY KEY,
            business_name VARCHAR(100) NOT NULL,
            balance       BIGINT       NOT NULL DEFAULT 0,
            card_number   VARCHAR(16)  UNIQUE,
            pin           VARCHAR(4)   DEFAULT NULL,
            owner_cid     VARCHAR(50)  NOT NULL,
            blocked       BOOLEAN      NOT NULL DEFAULT FALSE,
            attempts      TINYINT      NOT NULL DEFAULT 0,
            blocked_until BIGINT       NOT NULL DEFAULT 0
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS bank_transactions (
            id           INT AUTO_INCREMENT PRIMARY KEY,
            account_id   VARCHAR(50)  NOT NULL,
            account_type VARCHAR(10)  NOT NULL,
            type         VARCHAR(20)  NOT NULL,
            amount       BIGINT       NOT NULL,
            description  VARCHAR(200),
            timestamp    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    print('[eightys_banking] Système bancaire initialisé.')
end)

-- ================================================================
-- HELPERS
-- ================================================================
local function genCardNumber()
    -- Format Fleeca : 4987 XXXX XXXX XXXX
    return Config.Banking.CardPrefix .. string.format('%012d', math.random(100000000000, 999999999999))
end

local function logTx(accountId, accountType, txType, amount, desc)
    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, account_type, type, amount, description) VALUES (?,?,?,?,?)',
        { accountId, accountType, txType, amount, desc }
    )
end

local function getAccount(citizenid)
    local rows = MySQL.query.await('SELECT * FROM bank_accounts WHERE citizenid = ?', { citizenid })
    return rows and rows[1] or nil
end

local function getBusiness(businessId)
    local rows = MySQL.query.await('SELECT * FROM bank_business WHERE business_id = ?', { businessId })
    return rows and rows[1] or nil
end

local function ensureAccount(citizenid)
    local acc = getAccount(citizenid)
    if not acc then
        MySQL.insert.await('INSERT INTO bank_accounts (citizenid) VALUES (?)', { citizenid })
        acc = getAccount(citizenid)
    end
    return acc
end

local function isBlocked(acc)
    if not acc.blocked then return false end
    if os.time() > acc.blocked_until then
        -- Débloquer automatiquement
        MySQL.update.await('UPDATE bank_accounts SET blocked=FALSE, attempts=0 WHERE citizenid=?', { acc.citizenid })
        return false
    end
    return true
end

local function isBusinessBlocked(acc)
    if not acc.blocked then return false end
    if os.time() > acc.blocked_until then
        MySQL.update.await('UPDATE bank_business SET blocked=FALSE, attempts=0 WHERE business_id=?', { acc.business_id })
        return false
    end
    return true
end

-- ================================================================
-- CALLBACK — Solde frais (appelé à l'ouverture du guichet)
-- ================================================================
QBCore.Functions.CreateCallback('eightys_banking:getAccount', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(nil) return end
    local acc = ensureAccount(Player.PlayerData.citizenid)
    cb({
        balance = acc.balance,
        hasCard = acc.card_number ~= nil,
        hasPin  = acc.pin ~= nil,
        last4   = acc.card_number and acc.card_number:sub(-4) or nil,
        blocked = isBlocked(acc),
    })
end)

-- ================================================================
-- SYNC AU LOGIN
-- ================================================================
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local acc = ensureAccount(Player.PlayerData.citizenid)
    TriggerClientEvent('eightys_banking:client:accountData', src, {
        balance     = acc.balance,
        hasCard     = acc.card_number ~= nil,
        hasPin      = acc.pin ~= nil,
        last4       = acc.card_number and acc.card_number:sub(-4) or nil,
        blocked     = isBlocked(acc),
    })
end)

RegisterNetEvent('eightys_banking:server:requestSync', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local acc = ensureAccount(Player.PlayerData.citizenid)
    TriggerClientEvent('eightys_banking:client:accountData', src, {
        balance     = acc.balance,
        hasCard     = acc.card_number ~= nil,
        hasPin      = acc.pin ~= nil,
        last4       = acc.card_number and acc.card_number:sub(-4) or nil,
        blocked     = isBlocked(acc),
    })
end)

-- ================================================================
-- GUICHET — DÉPÔT (uniquement en agence, en personne)
-- ================================================================
RegisterNetEvent('eightys_banking:server:deposit', function(amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Banking.DepositMin then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Montant minimum : $'..Config.Banking.DepositMin, type='error' })
        return
    end

    local cash = Player.PlayerData.money['cash'] or 0
    if cash < amount then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description="Vous n'avez pas assez de cash.", type='error' })
        return
    end

    local cid = Player.PlayerData.citizenid
    local acc = ensureAccount(cid)

    Player.Functions.RemoveMoney('cash', amount, 'depot_banque')
    MySQL.update.await('UPDATE bank_accounts SET balance = balance + ? WHERE citizenid = ?', { amount, cid })
    logTx(cid, 'personal', 'deposit', amount, 'Dépôt au guichet')

    local newBal = acc.balance + amount
    TriggerClientEvent('ox_lib:notify', src, {
        title='🏦 Dépôt effectué', description=string.format('$%d déposés. Solde : $%d', amount, newBal), type='success', duration=5000
    })
    TriggerClientEvent('eightys_banking:client:accountData', src, {
        balance=newBal, hasCard=acc.card_number~=nil, hasPin=acc.pin~=nil,
        last4=acc.card_number and acc.card_number:sub(-4) or nil, blocked=false
    })
end)

-- ================================================================
-- GUICHET — RETRAIT
-- ================================================================
local function doWithdraw(src, Player, cid, amount, accountType, businessId)
    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Banking.WithdrawMin or amount > Config.Banking.WithdrawMax then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Montant invalide.', type='error' })
        return
    end

    if accountType == 'personal' then
        local acc = getAccount(cid)
        if not acc or acc.balance < amount then
            TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Solde insuffisant.', type='error' })
            return
        end
        MySQL.update.await('UPDATE bank_accounts SET balance = balance - ? WHERE citizenid = ?', { amount, cid })
        Player.Functions.AddMoney('cash', amount, 'retrait_banque')
        logTx(cid, 'personal', 'withdrawal', amount, 'Retrait guichet')
        TriggerClientEvent('ox_lib:notify', src, {
            title='🏦 Retrait effectué', description=string.format('$%d retirés.', amount), type='success', duration=4000
        })
        local newAcc = getAccount(cid)
        TriggerClientEvent('eightys_banking:client:accountData', src, {
            balance=newAcc.balance, hasCard=newAcc.card_number~=nil, hasPin=newAcc.pin~=nil,
            last4=newAcc.card_number and newAcc.card_number:sub(-4) or nil, blocked=false
        })
    elseif accountType == 'business' and businessId then
        local biz = getBusiness(businessId)
        if not biz or biz.balance < amount then
            TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Solde entreprise insuffisant.', type='error' })
            return
        end
        MySQL.update.await('UPDATE bank_business SET balance = balance - ? WHERE business_id = ?', { amount, businessId })
        Player.Functions.AddMoney('cash', amount, 'retrait_entreprise')
        logTx(businessId, 'business', 'withdrawal', amount, 'Retrait par '..cid)
        TriggerClientEvent('ox_lib:notify', src, {
            title='🏦 Retrait entreprise', description=string.format('$%d retirés du compte %s.', amount, biz.business_name), type='success', duration=4000
        })
    end
end

RegisterNetEvent('eightys_banking:server:withdraw', function(amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    doWithdraw(src, Player, Player.PlayerData.citizenid, amount, 'personal', nil)
end)

-- ================================================================
-- ÉMETTRE UNE CARTE BANCAIRE PERSONNELLE
-- ================================================================
RegisterNetEvent('eightys_banking:server:issueCard', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local acc = ensureAccount(cid)

    if acc.card_number then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Vous avez déjà une carte.', type='error' })
        return
    end

    local cardNum = genCardNumber()
    -- Éviter les collisions
    while MySQL.query.await('SELECT card_number FROM bank_accounts WHERE card_number=? UNION SELECT card_number FROM bank_business WHERE card_number=?', {cardNum, cardNum})[1] do
        cardNum = genCardNumber()
    end

    MySQL.update.await('UPDATE bank_accounts SET card_number=? WHERE citizenid=?', { cardNum, cid })

    local charInfo = Player.PlayerData.charinfo
    local ownerName = charInfo.firstname .. ' ' .. charInfo.lastname

    Player.Functions.AddItem('bank_card', 1, nil, {
        citizenid = cid,
        last4     = cardNum:sub(-4),
        owner     = ownerName,
    })

    TriggerClientEvent('ox_lib:notify', src, {
        title='💳 Carte émise',
        description=string.format('Carte Fleeca **** %s au nom de %s.', cardNum:sub(-4), ownerName),
        type='success', duration=5000
    })
    TriggerClientEvent('eightys_banking:client:accountData', src, {
        balance=acc.balance, hasCard=true, hasPin=acc.pin~=nil, last4=cardNum:sub(-4), blocked=false
    })
end)

-- ================================================================
-- DÉFINIR / CHANGER LE CODE PIN
-- ================================================================
RegisterNetEvent('eightys_banking:server:setPin', function(pin, accountType, businessId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    pin = tostring(pin or '')
    if not pin:match('^%d%d%d%d$') then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='PIN invalide (4 chiffres requis).', type='error' })
        return
    end

    local cid = Player.PlayerData.citizenid

    if accountType == 'business' and businessId then
        local biz = getBusiness(businessId)
        if not biz or biz.owner_cid ~= cid then
            TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Accès refusé.', type='error' })
            return
        end
        MySQL.update.await('UPDATE bank_business SET pin=? WHERE business_id=?', { pin, businessId })
    else
        MySQL.update.await('UPDATE bank_accounts SET pin=? WHERE citizenid=?', { pin, cid })
    end

    TriggerClientEvent('ox_lib:notify', src, { title='💳 Code PIN', description='Votre PIN a été mis à jour.', type='success' })
end)

-- ================================================================
-- DÉBLOQUER UNE CARTE (en agence uniquement)
-- ================================================================
RegisterNetEvent('eightys_banking:server:unblockCard', function(accountType, businessId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    if accountType == 'business' and businessId then
        local biz = getBusiness(businessId)
        if not biz or biz.owner_cid ~= cid then return end
        MySQL.update.await('UPDATE bank_business SET blocked=FALSE, attempts=0 WHERE business_id=?', { businessId })
    else
        MySQL.update.await('UPDATE bank_accounts SET blocked=FALSE, attempts=0 WHERE citizenid=?', { cid })
    end

    TriggerClientEvent('ox_lib:notify', src, { title='💳 Carte débloquée', type='success' })
end)

-- ================================================================
-- ATM — VÉRIFIER LE PIN D'UNE CARTE
-- La carte peut appartenir à n'importe qui (volée = valide)
-- ================================================================
RegisterNetEvent('eightys_banking:server:atmVerifyPin', function(cardMeta, pin)
    local src = source
    pin = tostring(pin or '')
    if not pin:match('^%d%d%d%d$') then return end
    if not cardMeta or not cardMeta.account_type then return end

    local accountId = cardMeta.account_type == 'personal' and cardMeta.citizenid or cardMeta.business_id

    if cardMeta.account_type == 'personal' then
        local acc = getAccount(accountId)
        if not acc then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Compte introuvable." })
            return
        end
        if isBlocked(acc) then
            local remaining = math.ceil((acc.blocked_until - os.time()) / 60)
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg=string.format("Carte bloquée. Réessayez dans %d min.", remaining) })
            return
        end
        if not acc.pin then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Aucun PIN défini. Rendez-vous en agence." })
            return
        end
        if acc.pin ~= pin then
            local newAttempts = acc.attempts + 1
            if newAttempts >= Config.Banking.PinAttempts then
                MySQL.update.await('UPDATE bank_accounts SET blocked=TRUE, attempts=0, blocked_until=? WHERE citizenid=?',
                    { os.time() + Config.Banking.BlockDuration, accountId })
                TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Trop de tentatives. Carte bloquée 5 minutes." })
            else
                MySQL.update.await('UPDATE bank_accounts SET attempts=? WHERE citizenid=?', { newAttempts, accountId })
                TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg=string.format("PIN incorrect. %d tentative(s) restante(s).", Config.Banking.PinAttempts - newAttempts) })
            end
            return
        end
        -- PIN correct
        MySQL.update.await('UPDATE bank_accounts SET attempts=0 WHERE citizenid=?', { accountId })
        TriggerClientEvent('eightys_banking:client:atmResult', src, {
            ok=true, balance=acc.balance, last4=acc.card_number:sub(-4),
            accountType='personal', accountId=accountId
        })

    elseif cardMeta.account_type == 'business' then
        local biz = getBusiness(accountId)
        if not biz then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Compte entreprise introuvable." })
            return
        end
        if isBusinessBlocked(biz) then
            local remaining = math.ceil((biz.blocked_until - os.time()) / 60)
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg=string.format("Carte bloquée. Réessayez dans %d min.", remaining) })
            return
        end
        if not biz.pin then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Aucun PIN défini sur cette carte." })
            return
        end
        if biz.pin ~= pin then
            local newAttempts = biz.attempts + 1
            if newAttempts >= Config.Banking.PinAttempts then
                MySQL.update.await('UPDATE bank_business SET blocked=TRUE, attempts=0, blocked_until=? WHERE business_id=?',
                    { os.time() + Config.Banking.BlockDuration, accountId })
                TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Trop de tentatives. Carte bloquée 5 minutes." })
            else
                MySQL.update.await('UPDATE bank_business SET attempts=? WHERE business_id=?', { newAttempts, accountId })
                TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg=string.format("PIN incorrect. %d tentative(s) restante(s).", Config.Banking.PinAttempts - newAttempts) })
            end
            return
        end
        MySQL.update.await('UPDATE bank_business SET attempts=0 WHERE business_id=?', { accountId })
        TriggerClientEvent('eightys_banking:client:atmResult', src, {
            ok=true, balance=biz.balance, last4=biz.card_number:sub(-4),
            accountType='business', accountId=accountId, businessName=biz.business_name
        })
    end
end)

-- ================================================================
-- ATM — RETRAIT
-- ================================================================
RegisterNetEvent('eightys_banking:server:atmWithdraw', function(cardMeta, pin, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    pin    = tostring(pin or '')
    amount = math.floor(tonumber(amount) or 0)

    if amount < Config.Banking.WithdrawMin or amount > Config.Banking.WithdrawMax then
        TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Montant invalide." })
        return
    end
    if not cardMeta or not cardMeta.account_type then return end

    local accountId = cardMeta.account_type == 'personal' and cardMeta.citizenid or cardMeta.business_id

    if cardMeta.account_type == 'personal' then
        local acc = getAccount(accountId)
        if not acc or acc.blocked or not acc.pin or acc.pin ~= pin then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Accès refusé." })
            return
        end
        if acc.balance < amount then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Solde insuffisant." })
            return
        end
        MySQL.update.await('UPDATE bank_accounts SET balance = balance - ? WHERE citizenid = ?', { amount, accountId })
        Player.Functions.AddMoney('cash', amount, 'retrait_atm')
        logTx(accountId, 'personal', 'atm_withdrawal', amount, 'Retrait DAB')
        local newBal = acc.balance - amount
        TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=true, withdrawn=amount, balance=newBal })

    elseif cardMeta.account_type == 'business' then
        local biz = getBusiness(accountId)
        if not biz or biz.blocked or not biz.pin or biz.pin ~= pin then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Accès refusé." })
            return
        end
        if biz.balance < amount then
            TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=false, msg="Solde entreprise insuffisant." })
            return
        end
        MySQL.update.await('UPDATE bank_business SET balance = balance - ? WHERE business_id = ?', { amount, accountId })
        Player.Functions.AddMoney('cash', amount, 'retrait_atm_entreprise')
        logTx(accountId, 'business', 'atm_withdrawal', amount, 'Retrait DAB par '..Player.PlayerData.citizenid)
        local newBal = biz.balance - amount
        TriggerClientEvent('eightys_banking:client:atmResult', src, { ok=true, withdrawn=amount, balance=newBal, businessName=biz.business_name })
    end
end)

-- ================================================================
-- COMPTE ENTREPRISE — Création (patron uniquement)
-- ================================================================
RegisterNetEvent('eightys_banking:server:createBusiness', function(businessId, businessName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid    = Player.PlayerData.citizenid
    -- Seul le grade le plus élevé du job peut créer un compte entreprise
    local job    = Player.PlayerData.job
    if not job or job.name ~= businessId then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Vous ne travaillez pas dans cette entreprise.', type='error' })
        return
    end

    local maxGrade = 0
    if Config.Jobs and Config.Jobs[businessId] then
        for g, _ in pairs(Config.Jobs[businessId].grades or {}) do
            if g > maxGrade then maxGrade = g end
        end
    end
    if job.grade.level < maxGrade then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Seul le patron peut créer un compte entreprise.', type='error' })
        return
    end

    local existing = getBusiness(businessId)
    if existing then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Ce compte entreprise existe déjà.', type='error' })
        return
    end

    local cardNum = genCardNumber()
    MySQL.insert.await(
        'INSERT INTO bank_business (business_id, business_name, owner_cid, card_number) VALUES (?,?,?,?)',
        { businessId, businessName or businessId, cid, cardNum }
    )

    Player.Functions.AddItem('business_card', 1, nil, {
        business_id   = businessId,
        business_name = businessName or businessId,
        last4         = cardNum:sub(-4),
        account_type  = 'business',
    })

    TriggerClientEvent('ox_lib:notify', src, {
        title='🏦 Compte entreprise créé',
        description=string.format('Carte entreprise %s **** %s.', businessName or businessId, cardNum:sub(-4)),
        type='success', duration=5000
    })
end)

-- ================================================================
-- COMPTE ENTREPRISE — Dépôt par le patron
-- ================================================================
RegisterNetEvent('eightys_banking:server:businessDeposit', function(businessId, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local biz = getBusiness(businessId)
    if not biz or biz.owner_cid ~= cid then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description='Accès refusé.', type='error' })
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Banking.DepositMin then return end

    local cash = Player.PlayerData.money['cash'] or 0
    if cash < amount then
        TriggerClientEvent('ox_lib:notify', src, { title='Banque', description="Cash insuffisant.", type='error' })
        return
    end

    Player.Functions.RemoveMoney('cash', amount, 'depot_entreprise')
    MySQL.update.await('UPDATE bank_business SET balance = balance + ? WHERE business_id = ?', { amount, businessId })
    logTx(businessId, 'business', 'deposit', amount, 'Dépôt par '..cid)

    local newBiz = getBusiness(businessId)
    TriggerClientEvent('ox_lib:notify', src, {
        title='🏦 Dépôt entreprise',
        description=string.format('$%d déposés. Solde %s : $%d', amount, biz.business_name, newBiz.balance),
        type='success', duration=5000
    })
end)

-- ================================================================
-- EXPORT — Créditer un compte entreprise (utilisé par d'autres ressources)
-- ================================================================
exports('creditBusiness', function(businessId, amount, reason)
    if not businessId or not amount then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local biz = getBusiness(businessId)
    if not biz then return false end
    MySQL.update.await('UPDATE bank_business SET balance = balance + ? WHERE business_id = ?', { amount, businessId })
    logTx(businessId, 'business', 'credit', amount, reason or 'Credit externe')
    return true
end)
