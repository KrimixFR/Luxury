-- qb-input client stub
local QBCore = exports['qb-core']:GetCoreObject()
-- qb-input remplacé par lib.inputDialog
exports('ShowInput', function(opts)
    if not opts then return nil end
    local fields = {}
    for _, row in ipairs(opts.options or {}) do
        table.insert(fields, { type = row.type or 'input', label = row.text or row.label or '', placeholder = row.placeholder or '' })
    end
    return lib.inputDialog(opts.header or 'Saisie', fields)
end)
