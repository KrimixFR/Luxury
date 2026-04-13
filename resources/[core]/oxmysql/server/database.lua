-- ================================================================
-- oxmysql — server/database.lua
-- Base de données JSON intégrée (pas besoin de MySQL externe)
-- Stockage : resources/[core]/oxmysql/db/<table>.json
-- Expose les exports : query_await, insert_await, update_await
-- ================================================================

local DB      = {}      -- Tables en mémoire  { [tableName] = { rows[] } }
local SCHEMAS = {}      -- Schémas des tables  { [tableName] = { [colName] = {default, type, pk, ai} } }
local AI_SEQ  = {}      -- AUTO_INCREMENT par table
local RES     = GetCurrentResourceName()

-- ================================================================
-- PERSISTANCE JSON
-- ================================================================
local function dbPath(tableName)
    return 'db/' .. tableName .. '.json'
end

local function loadTable(name)
    if DB[name] then return DB[name] end
    local raw = LoadResourceFile(RES, dbPath(name))
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        DB[name] = (ok and type(data) == 'table') and data or {}
    else
        DB[name] = {}
    end
    -- Trouver le max de l'auto-increment
    local maxId = 0
    for _, row in ipairs(DB[name]) do
        if row.id and type(row.id) == 'number' and row.id > maxId then
            maxId = row.id
        end
    end
    AI_SEQ[name] = maxId
    return DB[name]
end

local function saveTable(name)
    if not DB[name] then return end
    SaveResourceFile(RES, dbPath(name), json.encode(DB[name]), -1)
end

-- ================================================================
-- UTILITAIRES SQL BASIQUES
-- ================================================================

-- Extraire le nom de la table d'une requête
local function tableName(query)
    return
        query:match('[Cc][Rr][Ee][Aa][Tt][Ee]%s+[Tt][Aa][Bb][Ll][Ee]%s+[Ii][Ff]%s+[Nn][Oo][Tt]%s+[Ee][Xx][Ii][Ss][Tt][Ss]%s+([%w_]+)')
        or query:match('[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Gg][Nn][Oo][Rr][Ee]%s+[Ii][Nn][Tt][Oo]%s+([%w_]+)')
        or query:match('[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+([%w_]+)')
        or query:match('[Uu][Pp][Dd][Aa][Tt][Ee]%s+([%w_]+)')
        or query:match('[Ff][Rr][Oo][Mm]%s+([%w_]+)')
        or query:match('[Cc][Rr][Ee][Aa][Tt][Ee]%s+[Tt][Aa][Bb][Ll][Ee]%s+([%w_]+)')
end

-- Substituer les ? par les params
local function bindParams(query, params)
    if not params then return query end
    local i = 0
    return (query:gsub('%?', function()
        i = i + 1
        local v = params[i]
        if v == nil then return 'NULL' end
        if type(v) == 'string' then return "'" .. v:gsub("'", "''") .. "'"
        elseif type(v) == 'number' then return tostring(v)
        elseif type(v) == 'boolean' then return v and '1' or '0'
        else return tostring(v)
        end
    end))
end

-- Évaluer une condition WHERE simple :  col = 'val'  /  col = 123
local function evalWhere(row, whereStr)
    if not whereStr or whereStr == '' then return true end

    -- Gérer plusieurs conditions (AND)
    local conditions = {}
    for cond in (whereStr .. ' AND '):gmatch('(.-)%s+[Aa][Nn][Dd]%s+') do
        table.insert(conditions, cond:match('^%s*(.-)%s*$'))
    end
    if #conditions == 0 then table.insert(conditions, whereStr) end

    for _, cond in ipairs(conditions) do
        local col, op, val = cond:match("([%w_]+)%s*([><=!]+)%s*'([^']*)'")
        if not col then
            col, op, val = cond:match("([%w_]+)%s*([><=!]+)%s*([%-]?%d+%.?%d*)")
            if val then val = tonumber(val) end
        end
        if not col then return true end  -- On ne sait pas évaluer → ne pas filtrer

        local rowVal = row[col]
        if op == '='  or op == '==' then
            if type(val) == 'number' then
                if tonumber(rowVal) ~= val then return false end
            else
                if tostring(rowVal) ~= tostring(val) then return false end
            end
        elseif op == '!=' or op == '<>' then
            if tostring(rowVal) == tostring(val) then return false end
        elseif op == '>=' then
            if (tonumber(rowVal) or 0) < (tonumber(val) or 0) then return false end
        elseif op == '<=' then
            if (tonumber(rowVal) or 0) > (tonumber(val) or 0) then return false end
        elseif op == '>' then
            if (tonumber(rowVal) or 0) <= (tonumber(val) or 0) then return false end
        elseif op == '<' then
            if (tonumber(rowVal) or 0) >= (tonumber(val) or 0) then return false end
        end
    end
    return true
end

-- Extraire la clause WHERE (après le mot-clé WHERE, avant ORDER/LIMIT/GROUP)
local function extractWhere(query)
    local where = query:match('[Ww][Hh][Ee][Rr][Ee]%s+(.+)')
    if not where then return nil end
    -- Couper avant ORDER / LIMIT / GROUP
    where = where:gsub('%s+[Oo][Rr][Dd][Ee][Rr]%s+.*', '')
                 :gsub('%s+[Ll][Ii][Mm][Ii][Tt]%s+.*', '')
                 :gsub('%s+[Gg][Rr][Oo][Uu][Pp]%s+.*', '')
    return where:match('^%s*(.-)%s*$')
end

-- ================================================================
-- CREATE TABLE
-- ================================================================
local function execCreate(query)
    local name = tableName(query)
    if not name then return end
    loadTable(name)   -- Initialise si pas encore en mémoire
    -- Rien d'autre à faire : on stocke les données telles quelles
end

-- ================================================================
-- INSERT
-- ================================================================
local function execInsert(query, params)
    local name = tableName(query)
    if not name then return 0 end
    local rows = loadTable(name)

    -- Récupérer la liste des colonnes
    local colStr  = query:match('%(([^%)]+)%)%s*[Vv][Aa][Ll][Uu][Ee][Ss]')
    local valStr  = query:match('[Vv][Aa][Ll][Uu][Ee][Ss]%s*%(([^%)]+)%)')

    if not colStr or not valStr then return 0 end

    -- Parser les noms de colonnes
    local cols = {}
    for col in colStr:gmatch('[%w_]+') do table.insert(cols, col) end

    -- Parser les valeurs (avec params substitués)
    local boundQuery = bindParams(query, params)
    local boundValStr = boundQuery:match('[Vv][Aa][Ll][Uu][Ee][Ss]%s*%(([^%)]+)%)')

    local vals = {}
    if boundValStr then
        for val in (boundValStr .. ','):gmatch("([^,]*),") do
            val = val:match("^%s*'(.*)'%s*$") or val:match("^%s*(.-)%s*$")
            if val == 'NULL' or val == 'null' then val = nil
            elseif val == 'NOW()' or val:match('[Nn][Oo][Ww]%(%)') then
                val = os.date('%Y-%m-%d %H:%M:%S')
            else
                val = tonumber(val) or val
            end
            table.insert(vals, val)
        end
    end

    -- Construire la ligne
    local newRow = {}
    for i, col in ipairs(cols) do
        newRow[col] = vals[i]
    end

    -- Vérifier ON DUPLICATE KEY
    local isIgnore   = query:match('[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Gg][Nn][Oo][Rr][Ee]')
    local dupUpdate  = query:match('[Oo][Nn]%s+[Dd][Uu][Pp][Ll][Ii][Cc][Aa][Tt][Ee]%s+[Kk][Ee][Yy]%s+[Uu][Pp][Dd][Aa][Tt][Ee]%s+(.+)')

    -- Trouver la PK (première colonne nommée 'id' ou colonne unique)
    local pkCol  = nil
    local pkVal  = nil
    for _, col in ipairs(cols) do
        if col == 'id' or col:match('_id$') or col:match('^%w+_name$') then
            pkCol = col
            pkVal = newRow[col]
            break
        end
    end

    -- Vérifier les doublons
    if pkCol and pkVal then
        for i, row in ipairs(rows) do
            if row[pkCol] == pkVal then
                if isIgnore then
                    return 0   -- INSERT IGNORE : ne rien faire
                elseif dupUpdate then
                    -- Appliquer les mises à jour
                    local boundDup = bindParams(dupUpdate, params)
                    for upd in (boundDup .. ','):gmatch('([^,]+),') do
                        local col2, val2 = upd:match("([%w_]+)%s*=%s*'([^']*)'")
                        if not col2 then
                            col2, val2 = upd:match("([%w_]+)%s*=%s*([%w_%.%(%)%+%-]+)")
                        end
                        if col2 then
                            -- col = col + val
                            local addMatch = val2 and val2:match(col2 .. '%s*%+%s*(.+)')
                            if addMatch then
                                rows[i][col2] = (rows[i][col2] or 0) + (tonumber(addMatch) or 0)
                            elseif val2 == 'NOW()' then
                                rows[i][col2] = os.date('%Y-%m-%d %H:%M:%S')
                            else
                                rows[i][col2] = tonumber(val2) or val2
                            end
                        end
                    end
                    saveTable(name)
                    return rows[i].id or 1
                end
                break
            end
        end
    end

    -- AUTO INCREMENT id
    if not newRow['id'] then
        AI_SEQ[name] = (AI_SEQ[name] or 0) + 1
        newRow['id'] = AI_SEQ[name]
    end
    if not newRow['timestamp'] then
        newRow['timestamp'] = os.date('%Y-%m-%d %H:%M:%S')
    end

    table.insert(rows, newRow)
    saveTable(name)
    return newRow['id'] or #rows
end

-- ================================================================
-- SELECT
-- ================================================================
local function execSelect(query, params)
    local boundQuery = bindParams(query, params)

    -- Récupérer le nom principal de la table (support JOIN simple)
    local mainTable = boundQuery:match('[Ff][Rr][Oo][Mm]%s+([%w_]+)')
    if not mainTable then return {} end

    local rows = loadTable(mainTable)

    -- Clause WHERE
    local whereStr = extractWhere(boundQuery)
    local filtered = {}
    for _, row in ipairs(rows) do
        if evalWhere(row, whereStr) then
            table.insert(filtered, row)
        end
    end

    -- JOIN simplifié (LEFT JOIN characters ON ...)
    local joinTable, joinOn = boundQuery:match('[Jj][Oo][Ii][Nn]%s+([%w_]+)%s+[Oo][Nn]%s+([^\n]+)')
    if joinTable then
        local joinRows = loadTable(joinTable)
        -- Extraire les colonnes du ON (ex: c.citizenid = pm.sender_id)
        local jCol1, jCol2 = joinOn:match('([%w_]+)%.([%w_]+)%s*=%s*[%w_]+%.([%w_]+)')
        if not jCol1 then
            jCol2, jCol1 = joinOn:match('[%w_]+%.([%w_]+)%s*=%s*[%w_]+%.([%w_]+)')
        end
        if jCol2 and jCol1 then
            for _, mainRow in ipairs(filtered) do
                for _, joinRow in ipairs(joinRows) do
                    if mainRow[jCol1] == joinRow[jCol2] or mainRow[jCol2] == joinRow[jCol1] then
                        -- Fusionner les colonnes du join dans le main row
                        for k, v in pairs(joinRow) do
                            if not mainRow[k] then mainRow[k] = v end
                        end
                        -- Construire sender_name si disponible
                        if joinRow['firstname'] and joinRow['lastname'] then
                            mainRow['sender_name'] = joinRow['firstname'] .. ' ' .. joinRow['lastname']
                        end
                        break
                    end
                end
            end
        end
    end

    -- ORDER BY
    local orderCol, orderDir = boundQuery:match('[Oo][Rr][Dd][Ee][Rr]%s+[Bb][Yy]%s+([%w_%.]+)%s*([Aa][Ss][Cc]?[Ee]?[Nn]?[Dd]?|[Dd][Ee][Ss][Cc]?)?')
    if orderCol then
        local desc = orderDir and orderDir:upper():sub(1,4) == 'DESC'
        table.sort(filtered, function(a, b)
            local va, vb = a[orderCol] or 0, b[orderCol] or 0
            return desc and va > vb or va < vb
        end)
    end

    -- LIMIT
    local limitN = boundQuery:match('[Ll][Ii][Mm][Ii][Tt]%s+(%d+)')
    if limitN then
        limitN = tonumber(limitN)
        while #filtered > limitN do table.remove(filtered) end
    end

    -- GROUP BY avec COUNT(*)
    local groupCol = boundQuery:match('[Gg][Rr][Oo][Uu][Pp]%s+[Bb][Yy]%s+([%w_]+)')
    if groupCol then
        local groups = {}
        local groupOrder = {}
        for _, row in ipairs(filtered) do
            local key = tostring(row[groupCol] or '')
            if not groups[key] then
                groups[key] = { [groupCol] = row[groupCol], count = 0 }
                table.insert(groupOrder, key)
            end
            groups[key].count = groups[key].count + 1
            groups[key]['arrests'] = groups[key].count  -- alias commun
        end
        filtered = {}
        for _, k in ipairs(groupOrder) do table.insert(filtered, groups[k]) end
    end

    return filtered
end

-- ================================================================
-- UPDATE
-- ================================================================
local function execUpdate(query, params)
    local name = tableName(query)
    if not name then return 0 end
    local rows  = loadTable(name)
    local boundQuery = bindParams(query, params)

    -- Extraire SET clause
    local setStr  = boundQuery:match('[Ss][Ee][Tt]%s+(.-)%s+[Ww][Hh][Ee][Rr][Ee]')
                 or boundQuery:match('[Ss][Ee][Tt]%s+(.+)$')
    local whereStr = extractWhere(boundQuery)

    if not setStr then return 0 end

    local affected = 0
    for _, row in ipairs(rows) do
        if evalWhere(row, whereStr) then
            affected = affected + 1
            for assignment in (setStr .. ','):gmatch('([^,]+),') do
                local col, val = assignment:match("([%w_]+)%s*=%s*'([^']*)'")
                if not col then
                    col, val = assignment:match("([%w_]+)%s*=%s*([%w_%.%(%)%+%-]+)")
                end
                if col then
                    col = col:match('^%s*(.-)%s*$')
                    -- col = col + val
                    local addMatch = val and val:match(col .. '%s*%+%s*(.+)')
                    local subMatch = val and val:match(col .. '%s*%-%s*(.+)')
                    if addMatch then
                        row[col] = (row[col] or 0) + (tonumber(addMatch) or 0)
                    elseif subMatch then
                        row[col] = (row[col] or 0) - (tonumber(subMatch) or 0)
                    elseif val == 'NOW()' then
                        row[col] = os.date('%Y-%m-%d %H:%M:%S')
                    else
                        row[col] = tonumber(val) or val
                    end
                end
            end
        end
    end

    if affected > 0 then saveTable(name) end
    return affected
end

-- ================================================================
-- DISPATCHER PRINCIPAL
-- ================================================================
local function dispatch(query, params)
    if not query then return nil end
    local q = query:match('^%s*(.-)%s*$')
    local op = q:upper():sub(1, 6)

    if op == 'CREATE' then execCreate(q);              return nil
    elseif op == 'INSERT' then return execInsert(q, params)
    elseif op == 'UPDATE' then return execUpdate(q, params)
    elseif op:sub(1, 6) == 'SELECT' then return execSelect(q, params)
    else
        -- Requête non reconnue : ne pas crasher
        return nil
    end
end

-- ================================================================
-- EXPORTS
-- ================================================================
exports('query_await', function(query, params)
    return dispatch(query, params) or {}
end)

exports('insert_await', function(query, params)
    return dispatch(query, params) or 0
end)

exports('update_await', function(query, params)
    return dispatch(query, params) or 0
end)

-- Créer le dossier db au démarrage
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RES then return end
    -- Les fichiers se créent automatiquement via SaveResourceFile
    print('[oxmysql] Base de données JSON initialisée. Stockage : db/*.json')
end)
