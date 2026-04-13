-- qb-progressbar client stub
local QBCore = exports['qb-core']:GetCoreObject()
-- qb-progressbar remplacé par lib.progressBar
exports('Progress', function(data, cb)
    lib.progressBar({ duration=data.duration or 3000, label=data.label or '', useWhileDead=false,
        canCancel=data.canCancel ~= false, disable=data.disableControls or {},
        anim=data.animation }, cb)
end)
exports('IsDoingSomething', function() return false end)
