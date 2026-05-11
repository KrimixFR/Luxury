-- qb-menu client stub
local QBCore = exports['qb-core']:GetCoreObject()
-- qb-menu est remplacé par lib.registerContext + lib.showContext (ox_lib)
QBCore.UI = QBCore.UI or {}
QBCore.UI.Menu = {}
function QBCore.UI.Menu.Open(type, ns, name, cb, close, title, options)
    -- Convertir en ox_lib context
    local opts = {}
    if options then
        for i, opt in ipairs(options) do
            table.insert(opts, { title = opt.header or opt.title or 'Option', onSelect = function()
                if opt.onSelect then opt.onSelect() end
            end })
        end
    end
    lib.registerContext({ id = 'qbmenu_' .. (name or 'menu'), title = title or name or 'Menu', options = opts })
    lib.showContext('qbmenu_' .. (name or 'menu'))
end
function QBCore.UI.Menu.Close() if lib.hideContext then lib.hideContext() end end
