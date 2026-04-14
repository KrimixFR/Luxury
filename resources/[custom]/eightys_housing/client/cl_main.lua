-- ================================================================
-- eightys_housing — Client
-- Affichage des appartements, entrée/sortie, menu gestion
-- ================================================================

local QBCore    = exports['qb-core']:GetCoreObject()
local myAptId   = nil   -- id de l'appartement loué par ce joueur
local insideApt = nil   -- id de l'appartement où on se trouve actuellement

-- ================================================================
-- SYNC DEPUIS LE SERVEUR
-- ================================================================
RegisterNetEvent('eightys_housing:client:setRental', function(aptId)
    myAptId = aptId
end)

-- ================================================================
-- UTILS
-- ================================================================
local function getAptById(id)
    for _, apt in ipairs(Config.Housing.Apartments) do
        if apt.id == id then return apt end
    end
    return nil
end

-- ================================================================
-- BLIPS & MARQUEURS — Extérieurs des appartements
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    TriggerServerEvent('eightys_housing:server:requestSync')

    for _, apt in ipairs(Config.Housing.Apartments) do
        local blip = AddBlipForCoord(apt.exterior.x, apt.exterior.y, apt.exterior.z)
        SetBlipSprite(blip, 40)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(apt.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ================================================================
-- INTERACTIONS EXTÉRIEURES (entrée & location)
-- ================================================================
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    while true do
        local sleep  = 2000
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, apt in ipairs(Config.Housing.Apartments) do
            local dist = #(coords - apt.exterior)
            if dist < 15.0 then
                sleep = 0

                -- Marqueur au sol
                DrawMarker(20, apt.exterior.x, apt.exterior.y, apt.exterior.z - 0.9,
                    0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.3,
                    80, 180, 255, 80, false, true, 2, false, nil, nil, false)

                if dist < 2.5 then
                    local onScreen, sx, sy = World3dToScreen2d(apt.exterior.x, apt.exterior.y, apt.exterior.z + 0.5)
                    if onScreen then
                        SetTextScale(0.32, 0.32)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 200, 0, 215)
                        SetTextEntry("STRING")
                        SetTextCentre(true)
                        local hint = apt.id == myAptId
                            and ("[E] " .. apt.label .. " — Entrer")
                            or  ("[E] " .. apt.label .. " — Louer ($" .. apt.price .. ")")
                        AddTextComponentString(hint)
                        DrawText(sx, sy)
                    end

                    if IsControlJustReleased(0, 38) then
                        if apt.id == myAptId then
                            enterApartment(apt)
                        else
                            openRentMenu(apt)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ================================================================
-- ENTRER DANS L'APPARTEMENT
-- ================================================================
function enterApartment(apt)
    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoords(PlayerPedId(), apt.interior.x, apt.interior.y, apt.interior.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), apt.heading or 0.0)
    insideApt = apt.id
    Wait(500)
    DoScreenFadeIn(500)

    lib.notify({ title = '🏠 ' .. apt.label, description = 'Vous êtes chez vous.', type = 'inform', duration = 3000 })
end

-- ================================================================
-- SORTIR DE L'APPARTEMENT (depuis l'intérieur)
-- ================================================================
CreateThread(function()
    while true do
        Wait(500)
        if insideApt then
            local apt    = getAptById(insideApt)
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if apt then
                local dist = #(coords - apt.interior)

                -- Marqueur de sortie
                DrawMarker(20, apt.interior.x, apt.interior.y, apt.interior.z - 0.9,
                    0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.3,
                    255, 100, 50, 80, false, true, 2, false, nil, nil, false)

                if dist < 2.0 then
                    local onScreen, sx, sy = World3dToScreen2d(apt.interior.x, apt.interior.y, apt.interior.z + 0.5)
                    if onScreen then
                        SetTextScale(0.32, 0.32)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 200, 0, 215)
                        SetTextEntry("STRING")
                        SetTextCentre(true)
                        AddTextComponentString("[E] Sortir  |  [F] Ouvrir le coffre  |  [G] Menu logement")
                        DrawText(sx, sy)
                    end

                    -- Sortir
                    if IsControlJustReleased(0, 38) then
                        leaveApartment(apt)
                    end

                    -- Coffre
                    if IsControlJustReleased(0, 23) then
                        TriggerServerEvent('eightys_housing:server:openStash', insideApt)
                    end

                    -- Menu gestion
                    if IsControlJustReleased(0, 47) then
                        openTenantMenu(apt)
                    end
                end
            end
        end
    end
end)

function leaveApartment(apt)
    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoords(PlayerPedId(), apt.exterior.x, apt.exterior.y, apt.exterior.z, false, false, false, true)
    insideApt = nil
    Wait(500)
    DoScreenFadeIn(500)
end

-- ================================================================
-- MENU DE LOCATION
-- ================================================================
function openRentMenu(apt)
    lib.alertDialog({
        header   = '🏠 Louer : ' .. apt.label,
        content  = string.format(
            'Caution : **$%d**\nLoyer hebdomadaire : **$%d**\n\nVoulez-vous louer cet appartement ?',
            apt.price, apt.rent
        ),
        centered = true,
        cancel   = true,
    }, function(confirmed)
        if confirmed == 'confirm' then
            TriggerServerEvent('eightys_housing:server:rent', apt.id)
        end
    end)
end

-- ================================================================
-- MENU LOCATAIRE (depuis l'intérieur)
-- ================================================================
function openTenantMenu(apt)
    lib.registerContext({
        id    = 'housing_tenant',
        title = '🏠 ' .. apt.label,
        options = {
            {
                title       = 'Définir comme point de respawn',
                icon        = 'bed',
                description = 'Vous réapparaîtrez ici à votre prochaine connexion',
                onSelect    = function()
                    -- Sauvegarder dans les métadonnées
                    TriggerServerEvent('eightys_housing:server:setSpawn', apt.id)
                    lib.notify({ title = '🏠 Lit enregistré', description = 'Vous respawnerez ici.', type = 'success' })
                end,
            },
            {
                title    = 'Ouvrir le coffre',
                icon     = 'box',
                onSelect = function()
                    TriggerServerEvent('eightys_housing:server:openStash', apt.id)
                end,
            },
            {
                title       = 'Résilier le bail',
                icon        = 'door-open',
                description = 'Vous perdrez votre appartement (caution non remboursée)',
                onSelect    = function()
                    lib.alertDialog({
                        header  = 'Résilier le bail',
                        content = 'Êtes-vous sûr ? La caution ne sera pas remboursée.',
                        centered = true,
                        cancel  = true,
                    }, function(confirmed)
                        if confirmed == 'confirm' then
                            TriggerServerEvent('eightys_housing:server:vacate')
                            leaveApartment(apt)
                        end
                    end)
                end,
            },
        },
    })
    lib.showContext('housing_tenant')
end
