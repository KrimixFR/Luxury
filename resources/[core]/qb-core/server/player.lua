-- ================================================================
-- QBCore — server/player.lua
-- Classe Player : données, méthodes Add/Remove money, items, job, gang
-- ================================================================

-- S'assurer que QBCore.Player existe (main.lua charge après ce fichier)
QBCore        = QBCore or {}
QBCore.Player = QBCore.Player or {}

local RES = GetCurrentResourceName()

-- ================================================================
-- PERSISTANCE (JSON par joueur)
-- ================================================================
local function playerPath(citizenid)
    return 'players/' .. citizenid .. '.json'
end

local function loadPlayerFile(citizenid)
    local raw = LoadResourceFile(RES, playerPath(citizenid))
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then return data end
    end
    return nil
end

local function savePlayerFile(citizenid, data)
    SaveResourceFile(RES, playerPath(citizenid), json.encode(data), -1)
end

-- ================================================================
-- DONNÉES PAR DÉFAUT D'UN NOUVEAU JOUEUR
-- ================================================================
local function defaultPlayerData(citizenid, license, name)
    return {
        citizenid = citizenid,
        license   = license,
        name      = name,
        charinfo  = {
            firstname   = 'Nouveau',
            lastname    = 'Joueur',
            nationality = 'Américain',
            birthdate   = '01/01/1960',
            gender      = 0,
            phone       = '555-' .. math.random(1000, 9999),
            account     = 'US' .. citizenid,
        },
        job = {
            name    = 'unemployed',
            label   = 'Chômeur',
            payment = 0,
            onduty  = true,
            grade   = { name = 'none', label = 'Sans emploi', level = 0 },
        },
        gang = {
            name  = 'none',
            label = 'Aucun',
            grade = { name = 'none', label = 'Aucune affiliation', level = 0 },
        },
        money = {
            cash  = 500,
            bank  = 0,
            dirty = 0,
        },
        metadata = {
            hunger      = 100,
            thirst      = 100,
            armor       = 0,
            ishandcuffed= false,
            injail      = 0,
            deathcount  = 0,
        },
        items    = {},
        position = { x = 441.9, y = -982.2, z = 30.7, heading = 355.0 },
        dead     = false,
    }
end

-- ================================================================
-- GÉNÉRATION DU CITIZENID
-- ================================================================
local function generateCitizenId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local id = ''
    for i = 1, 3 do id = id .. chars:sub(math.random(1,26), math.random(1,26)):sub(1,1) end
    for i = 1, 5 do id = id .. math.random(0, 9) end
    return id
end

-- ================================================================
-- CRÉATION DU PLAYER OBJECT
-- ================================================================
function QBCore.Player.CreatePlayer(src, license, name, citizenid, isNew)
    local savedData = not isNew and loadPlayerFile(citizenid)
    local pData     = savedData or defaultPlayerData(citizenid or generateCitizenId(), license, name)

    if not pData.citizenid then pData.citizenid = citizenid or generateCitizenId() end
    pData.source = src

    -- -------------------------------------------------------
    -- MÉTHODES DU PLAYER
    -- -------------------------------------------------------
    local Player = {
        PlayerData = pData,
        Functions  = {},
    }

    -- Sauvegarder
    function Player.Functions.Save()
        pData.position = nil  -- Sera mis à jour au disconnect
        savePlayerFile(pData.citizenid, pData)
    end

    -- Notifier les changements de data au client
    function Player.Functions.UpdatePlayerData()
        TriggerClientEvent('QBCore:Player:SetPlayerData', src, pData)
    end

    -- --- ARGENT ---
    function Player.Functions.AddMoney(moneyType, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        if not pData.money[moneyType] then pData.money[moneyType] = 0 end
        pData.money[moneyType] = pData.money[moneyType] + amount
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
        return true
    end

    function Player.Functions.RemoveMoney(moneyType, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        if not pData.money[moneyType] then return false end
        if pData.money[moneyType] < amount then return false end
        pData.money[moneyType] = pData.money[moneyType] - amount
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
        return true
    end

    function Player.Functions.SetMoney(moneyType, amount)
        pData.money[moneyType] = math.floor(tonumber(amount) or 0)
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
    end

    function Player.Functions.GetMoney(moneyType)
        return pData.money[moneyType] or 0
    end

    -- --- INVENTAIRE ---
    function Player.Functions.AddItem(itemName, count, slot, metadata)
        count = math.floor(tonumber(count) or 1)
        if count <= 0 then return false end
        local item = QBCore.Shared.Items[itemName]
        if not item then return false end

        -- Chercher si déjà dans l'inventaire
        for _, invItem in ipairs(pData.items) do
            if invItem.name == itemName then
                invItem.amount = (invItem.amount or 0) + count
                Player.Functions.UpdatePlayerData()
                Player.Functions.Save()
                return true
            end
        end

        -- Nouveau item
        table.insert(pData.items, {
            name      = itemName,
            label     = item.label,
            amount    = count,
            type      = item.type or 'item',
            useable   = item.useable,
            weight    = item.weight or 0,
            metadata  = metadata or {},
        })
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
        return true
    end

    function Player.Functions.RemoveItem(itemName, count)
        count = math.floor(tonumber(count) or 1)
        for i, invItem in ipairs(pData.items) do
            if invItem.name == itemName then
                if (invItem.amount or 0) < count then return false end
                invItem.amount = invItem.amount - count
                if invItem.amount <= 0 then table.remove(pData.items, i) end
                Player.Functions.UpdatePlayerData()
                Player.Functions.Save()
                return true
            end
        end
        return false
    end

    function Player.Functions.GetItemByName(itemName)
        for _, invItem in ipairs(pData.items) do
            if invItem.name == itemName then return invItem end
        end
        return nil
    end

    function Player.Functions.HasItem(itemName, count)
        count = count or 1
        local item = Player.Functions.GetItemByName(itemName)
        return item and (item.amount or 0) >= count
    end

    -- --- JOB ---
    function Player.Functions.SetJob(jobName, gradeLevel)
        gradeLevel = gradeLevel or 0
        local jobConfig = Config and Config.Jobs and Config.Jobs[jobName]
        if jobConfig then
            local gradeData = jobConfig.grades[gradeLevel] or jobConfig.grades[0] or {}
            pData.job = {
                name    = jobName,
                label   = jobConfig.label,
                payment = gradeData.payment or 0,
                onduty  = jobConfig.defaultDuty ~= false,
                grade   = { name = gradeData.name or 'grade', label = gradeData.label or 'Grade', level = gradeLevel },
            }
        else
            pData.job = {
                name  = jobName, label = jobName, payment = 0, onduty = true,
                grade = { name = 'none', label = 'Grade', level = gradeLevel },
            }
        end
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
        TriggerClientEvent('QBCore:Client:OnJobUpdate', src, pData.job)
    end

    function Player.Functions.SetJobDuty(onduty)
        pData.job.onduty = onduty
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
    end

    -- --- GANG ---
    function Player.Functions.SetGang(gangName, gradeLevel)
        gradeLevel = gradeLevel or 0
        local gangConfig = Config and Config.Gangs and Config.Gangs[gangName]
        if gangConfig then
            local gradeData = gangConfig.grades[gradeLevel] or gangConfig.grades[0] or {}
            pData.gang = {
                name  = gangName,
                label = gangConfig.label,
                grade = { name = gradeData.name or 'grade', label = gradeData.label or 'Grade', level = gradeLevel },
            }
        else
            pData.gang = {
                name = 'none', label = 'Aucun',
                grade = { name = 'none', label = 'Aucun', level = 0 },
            }
        end
        Player.Functions.UpdatePlayerData()
        Player.Functions.Save()
    end

    -- --- METADATA ---
    function Player.Functions.SetMetaData(meta, val)
        pData.metadata[meta] = val
        Player.Functions.UpdatePlayerData()
    end

    function Player.Functions.GetMetaData(meta)
        return pData.metadata[meta]
    end

    -- --- CHARINFO ---
    function Player.Functions.SetCharInfo(key, val)
        pData.charinfo[key] = val
        Player.Functions.Save()
    end

    -- --- POSITION ---
    function Player.Functions.SaveLocation(coords, heading)
        pData.position = { x = coords.x, y = coords.y, z = coords.z, heading = heading or 0 }
        Player.Functions.Save()
    end

    return Player
end
