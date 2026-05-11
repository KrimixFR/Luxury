-- ================================================================
-- oxmysql — lib/MySQL.lua
-- Shim chargé par les scripts via :  shared_scripts { '@oxmysql/lib/MySQL.lua' }
-- Expose MySQL.query.await / MySQL.insert.await / MySQL.update.await
-- ================================================================

if IsDuplicityVersion() then  -- Côté serveur uniquement

    MySQL = MySQL or {}

    -- -------------------------------------------------------
    -- MySQL.query.await(query, params) → rows[]
    -- -------------------------------------------------------
    MySQL.query = MySQL.query or {}
    MySQL.query.await = function(query, params)
        if not query then return {} end
        local ok, result = pcall(function()
            return exports['oxmysql']:query_await(query, params or {})
        end)
        if ok then return result or {} end
        return {}
    end

    -- -------------------------------------------------------
    -- MySQL.insert.await(query, params) → insertId (number)
    -- -------------------------------------------------------
    MySQL.insert = MySQL.insert or {}
    MySQL.insert.await = function(query, params)
        if not query then return 0 end
        local ok, result = pcall(function()
            return exports['oxmysql']:insert_await(query, params or {})
        end)
        if ok then return result or 0 end
        return 0
    end

    -- -------------------------------------------------------
    -- MySQL.update.await(query, params) → affectedRows (number)
    -- -------------------------------------------------------
    MySQL.update = MySQL.update or {}
    MySQL.update.await = function(query, params)
        if not query then return 0 end
        local ok, result = pcall(function()
            return exports['oxmysql']:update_await(query, params or {})
        end)
        if ok then return result or 0 end
        return 0
    end

end
