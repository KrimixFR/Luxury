-- ================================================================
-- QBCore Shared — Données partagées client/serveur
-- ================================================================

QBCore = QBCore or {}
QBCore.Shared = QBCore.Shared or {}

QBCore.Shared.Items   = QBShared and QBShared.Items or {}
QBCore.Shared.Version = '1.0.0'

-- ================================================================
-- EMPLOIS PAR DÉFAUT
-- ================================================================
QBCore.Shared.Jobs = {
    ['unemployed'] = {
        label       = 'Chômeur',
        defaultDuty = true,
        offDutyPay  = false,
        grades      = { [0] = { name='none', label='Sans emploi', payment=0 } },
    },
    -- Les autres jobs sont définis dans eightys_core/config.lua
    -- et synchronisés au démarrage par qb-core/server/main.lua
}

-- ================================================================
-- GANGS PAR DÉFAUT
-- ================================================================
QBCore.Shared.Gangs = {
    ['none'] = {
        label  = 'Aucun',
        grades = { [0] = { name='none', label='Aucune affiliation' } },
    },
}

-- ================================================================
-- VÉHICULES PARTAGÉS
-- ================================================================
QBCore.Shared.Vehicles = {}

-- ================================================================
-- UTILITAIRES COMMUNS
-- ================================================================
function QBCore.Shared.SplitStr(str, delimiter)
    local result = {}
    local pattern = string.format('([^%s]+)', delimiter)
    str:gsub(pattern, function(c) result[#result+1] = c end)
    return result
end

function QBCore.Shared.RoundNumber(number, decimals)
    local power = 10 ^ decimals
    return math.floor(number * power + 0.5) / power
end

function QBCore.Shared.GroupDigits(number)
    local s = tostring(math.floor(number))
    local result = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return result:gsub('^,', '')
end
