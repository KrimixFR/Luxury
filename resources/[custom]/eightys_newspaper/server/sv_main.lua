-- ================================================================
-- eightys_newspaper — Server
-- Journal généré toutes les heures depuis les événements du serveur
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================================================
-- DB INIT
-- ================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS newspaper_events (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            event_type VARCHAR(30)  NOT NULL,
            headline   VARCHAR(200) NOT NULL,
            body       TEXT         NOT NULL,
            location   VARCHAR(100),
            created_at BIGINT       NOT NULL
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS newspaper_editions (
            id             INT AUTO_INCREMENT PRIMARY KEY,
            edition_number INT  NOT NULL,
            articles       TEXT NOT NULL,
            published_at   BIGINT NOT NULL
        )
    ]])
    print('[eightys_newspaper] Journal initialisé.')
end)

-- ================================================================
-- EXPORT — Logger un événement (appelé par d'autres resources)
-- Usage: exports['eightys_newspaper']:logEvent('death', 'Titre', 'Corps', 'South LS')
-- ================================================================
exports('logEvent', function(eventType, headline, body, location)
    if not eventType or not headline or not body then return end
    MySQL.insert.await(
        'INSERT INTO newspaper_events (event_type, headline, body, location, created_at) VALUES (?,?,?,?,?)',
        { eventType, headline:sub(1, 199), body, location or 'Los Santos', os.time() }
    )
end)

-- ================================================================
-- ÉCOUTE D'ÉVÉNEMENTS INTERNES
-- ================================================================

-- Mort d'un joueur
AddEventHandler('eightys_newspaper:log:death', function(victimName, location)
    local headlines = {
        string.format('Un homme abattu à %s', location),
        string.format('Fusillade mortelle à %s', location),
        string.format('Règlement de comptes : un mort à %s', location),
        string.format('Violence à %s : une victime', location),
    }
    MySQL.insert.await(
        'INSERT INTO newspaper_events (event_type, headline, body, location, created_at) VALUES (?,?,?,?,?)',
        { 'death',
          headlines[math.random(#headlines)],
          string.format(
            'Un homme a été retrouvé mort dans le quartier de %s. ' ..
            'Les autorités ont ouvert une enquête. ' ..
            'La victime, identifiée sous le nom de %s, aurait succombé à ses blessures par balle. ' ..
            'Le LAPD appelle les témoins à se manifester.',
            location, victimName),
          location, os.time() }
    )
end)

-- Arrestation
AddEventHandler('eightys_newspaper:log:arrest', function(suspectName, charges, location)
    MySQL.insert.await(
        'INSERT INTO newspaper_events (event_type, headline, body, location, created_at) VALUES (?,?,?,?,?)',
        { 'arrest',
          string.format('Arrestation à %s', location),
          string.format(
            'Le LAPD a procédé à l\'arrestation de %s dans le secteur de %s. ' ..
            'Le suspect est mis en cause pour %s. ' ..
            'Une audience est prévue dans les prochains jours.',
            suspectName, location, charges),
          location, os.time() }
    )
end)

-- Saisie de drogue
AddEventHandler('eightys_newspaper:log:drugbust', function(amount, drugType, location)
    MySQL.insert.await(
        'INSERT INTO newspaper_events (event_type, headline, body, location, created_at) VALUES (?,?,?,?,?)',
        { 'drugbust',
          string.format('Saisie record : %d doses de %s', amount, drugType),
          string.format(
            'La Vice Squad du LAPD a mené une opération d\'envergure dans le secteur de %s. ' ..
            '%d doses de %s ont été saisies lors d\'un raid éclair. ' ..
            'Plusieurs individus ont pris la fuite. L\'enquête se poursuit.',
            location, amount, drugType),
          location, os.time() }
    )
end)

-- Braquage / Vol
AddEventHandler('eightys_newspaper:log:robbery', function(location, amount)
    MySQL.insert.await(
        'INSERT INTO newspaper_events (event_type, headline, body, location, created_at) VALUES (?,?,?,?,?)',
        { 'robbery',
          string.format('Braquage à %s : $%d dérobés', location, amount),
          string.format(
            'Des individus armés ont commis un braquage à %s. ' ..
            'Le butin estimé à $%d. ' ..
            'Les auteurs ont pris la fuite avant l\'arrivée des forces de l\'ordre. ' ..
            'Le LAPD recherche activement les suspects.',
            location, amount),
          location, os.time() }
    )
end)

-- ================================================================
-- GÉNÉRATION DU JOURNAL (toutes les heures)
-- ================================================================
local editionNumber = 1

local GENERIC_ARTICLES = {
    {
        headline = 'Los Santos : la canicule persiste',
        body     = 'Les températures continuent de battre des records à Los Santos. Les habitants sont invités à rester hydratés et à éviter les sorties aux heures les plus chaudes. Le thermomètre a atteint 38°C ce matin à South LS.',
    },
    {
        headline = 'Le port de La Mesa tourne à plein régime',
        body     = 'Les activités portuaires de La Mesa sont en hausse. Les syndicats des dockers négocient actuellement de nouvelles conditions salariales avec la direction. Aucun incident n\'est à signaler cette semaine.',
    },
    {
        headline = 'Vinewood : inauguration d\'un nouveau club',
        body     = 'Un nouvel établissement nocturne a ouvert ses portes dans le quartier de Vinewood. Le club, qui peut accueillir jusqu\'à 400 personnes, promet une programmation musicale axée sur le rock et le funk. Ouverture vendredi soir.',
    },
    {
        headline = 'Rockford Hills : les résidents se plaignent du bruit',
        body     = 'Les habitants aisés de Rockford Hills ont déposé une pétition auprès de la mairie concernant les nuisances sonores nocturnes. La ville promet d\'examiner la situation dans les plus brefs délais.',
    },
    {
        headline = 'Météo : week-end ensoleillé annoncé',
        body     = 'Le bureau météorologique de Los Santos prévoit un week-end dégagé avec des températures clémentes. Les amateurs de plage sont attendus en nombre à Vespucci Beach.',
    },
}

CreateThread(function()
    -- Récupérer le dernier numéro
    Wait(5000) -- laisser la DB s'initialiser
    local last = MySQL.query.await('SELECT MAX(edition_number) as n FROM newspaper_editions')
    if last and last[1] and last[1].n then
        editionNumber = last[1].n + 1
    end

    -- Générer une première édition si aucune n'existe
    if editionNumber == 1 then
        generateEdition()
    end

    -- Boucle horaire
    while true do
        Wait(3600000) -- 1h réelle
        generateEdition()
    end
end)

function generateEdition()
    local since  = os.time() - 3600
    local events = MySQL.query.await(
        'SELECT * FROM newspaper_events WHERE created_at > ? ORDER BY created_at DESC LIMIT 7',
        { since }
    )

    local articles = {}

    if events and #events > 0 then
        for _, ev in ipairs(events) do
            table.insert(articles, {
                event_type = ev.event_type,
                headline   = ev.headline,
                body       = ev.body,
                location   = ev.location,
            })
        end
    end

    -- Compléter avec des articles génériques si moins de 3 événements
    while #articles < 3 do
        local generic = GENERIC_ARTICLES[math.random(#GENERIC_ARTICLES)]
        table.insert(articles, { event_type='generic', headline=generic.headline, body=generic.body })
    end

    MySQL.insert.await(
        'INSERT INTO newspaper_editions (edition_number, articles, published_at) VALUES (?,?,?)',
        { editionNumber, json.encode(articles), os.time() }
    )

    print(string.format('[eightys_newspaper] Édition n°%d générée (%d articles).', editionNumber, #articles))
    editionNumber = editionNumber + 1

    TriggerClientEvent('eightys_newspaper:client:newEdition', -1, editionNumber - 1)
end

-- ================================================================
-- ACHETER LE JOURNAL (déclenché par le client)
-- ================================================================
RegisterNetEvent('eightys_newspaper:server:buy', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if (Player.PlayerData.money['cash'] or 0) < 5 then
        TriggerClientEvent('ox_lib:notify', src, {
            title='Kiosque', description='Il vous faut $5 pour acheter le journal.', type='error'
        })
        return
    end

    Player.Functions.RemoveMoney('cash', 5, 'journal')

    -- Récupérer la dernière édition
    local edition = MySQL.query.await('SELECT * FROM newspaper_editions ORDER BY edition_number DESC LIMIT 1')
    local data

    if edition and edition[1] then
        data = {
            number   = edition[1].edition_number,
            date     = os.date('%d/%m/%Y', edition[1].published_at),
            articles = json.decode(edition[1].articles),
        }
    else
        data = {
            number   = 1,
            date     = os.date('%d/%m/%Y'),
            articles = { { event_type='generic', headline='Los Santos Chronicle', body='Première édition. Aucun incident à signaler.' } },
        }
    end

    TriggerClientEvent('eightys_newspaper:client:receiveEdition', src, data)
end)
