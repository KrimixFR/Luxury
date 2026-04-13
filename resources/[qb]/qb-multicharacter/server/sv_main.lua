-- ================================================================
-- qb-multicharacter — Server
-- Gestion des personnages (création, listing)
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Envoyer la liste des personnages d'un joueur (1 seul par défaut)
RegisterNetEvent('qb-multicharacter:server:getChars', function()
    local src     = source
    local license = GetPlayerIdentifierByType(src, 'license')

    -- Vérifier si un personnage existe déjà dans l'index
    local RES = 'qb-core'
    local indexRaw = LoadResourceFile(RES, 'players/_index.json')
    local index = {}
    if indexRaw and indexRaw ~= '' then
        local ok, data = pcall(json.decode, indexRaw)
        if ok and type(data) == 'table' then index = data end
    end

    local citizenid = index[license]
    local chars = {}

    if citizenid then
        -- Charger les données du personnage
        local raw = LoadResourceFile(RES, 'players/' .. citizenid .. '.json')
        if raw and raw ~= '' then
            local ok, pData = pcall(json.decode, raw)
            if ok and pData then
                table.insert(chars, {
                    citizenid = pData.citizenid,
                    cid       = 1,
                    charinfo  = pData.charinfo,
                    job       = pData.job,
                    gang      = pData.gang,
                    money     = pData.money,
                    metadata  = pData.metadata,
                })
            end
        end
    end

    TriggerClientEvent('qb-multicharacter:client:showChars', src, chars)
end)

-- Créer un nouveau personnage
RegisterNetEvent('qb-multicharacter:server:createChar', function(charData)
    local src     = source
    local license = GetPlayerIdentifierByType(src, 'license')
    local name    = GetPlayerName(src) or 'Joueur'

    if not charData or not charData.firstname or not charData.lastname then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Erreur', type = 'error',
            description = 'Données de personnage invalides.',
        })
        return
    end

    -- Générer citizenid
    local citizenid = ''
    for i = 1, 3 do citizenid = citizenid .. string.char(string.byte('A') + math.random(0,25)) end
    for i = 1, 5 do citizenid = citizenid .. math.random(0,9) end

    -- Mettre à jour l'index
    local RES = 'qb-core'
    local indexRaw = LoadResourceFile(RES, 'players/_index.json')
    local index = {}
    if indexRaw and indexRaw ~= '' then
        local ok, data = pcall(json.decode, indexRaw)
        if ok and type(data) == 'table' then index = data end
    end
    index[license] = citizenid
    SaveResourceFile(RES, 'players/_index.json', json.encode(index), -1)

    -- Créer le fichier joueur avec le charinfo
    local pData = {
        citizenid = citizenid,
        license   = license,
        name      = name,
        charinfo  = {
            firstname   = charData.firstname,
            lastname    = charData.lastname,
            nationality = 'Américain',
            birthdate   = charData.birthdate or '01/01/1960',
            gender      = charData.gender or 0,
            phone       = '555-' .. math.random(1000, 9999),
            account     = 'US' .. citizenid,
        },
        job  = { name='unemployed', label='Chômeur', payment=0, onduty=true, grade={name='none',label='Sans emploi',level=0} },
        gang = { name='none', label='Aucun', grade={name='none',label='Aucune affiliation',level=0} },
        money    = { cash=500, bank=0, dirty=0 },
        metadata = { hunger=100, thirst=100, armor=0, ishandcuffed=false, injail=0, deathcount=0 },
        items    = {},
        position = { x=441.9, y=-982.2, z=30.7, heading=355.0 },
        dead     = false,
    }

    SaveResourceFile(RES, 'players/' .. citizenid .. '.json', json.encode(pData), -1)

    print(string.format('[qb-multicharacter] Personnage créé : %s %s (citizenid: %s)',
        charData.firstname, charData.lastname, citizenid))

    TriggerClientEvent('qb-multicharacter:client:charCreated', src)
end)
