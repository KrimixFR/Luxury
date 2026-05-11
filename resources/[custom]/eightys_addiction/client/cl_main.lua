local addicted     = false
local drugName     = 'none'
local lastUse      = 0          -- timestamp serveur (os.time) mis à jour par sync
local inWithdrawal = false
local detoxLocation = vector3(297.8, -584.5, 43.3) -- hôpital

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 215); SetTextEntry("STRING"); SetTextCentre(true)
    AddTextComponentString(text); DrawText(sx, sy)
end

local function applyWithdrawalEffects()
    if inWithdrawal then return end
    inWithdrawal = true
    SetPedMotionBlur(PlayerPedId(), true)
    ShakeGameCam('DRUNK_SHAKE', 0.3)
    SetRunSprintMultiplierForPlayer(PlayerId(), 0.6)
    lib.notify({
        title       = '🥵 Manque',
        description = 'Votre corps réclame sa dose...',
        type        = 'error',
        duration    = 10000,
    })
end

local function clearWithdrawalEffects()
    if not inWithdrawal then return end
    inWithdrawal = false
    SetPedMotionBlur(PlayerPedId(), false)
    StopGameplayCamShaking(true)
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

-- ─────────────────────────────────────────────
-- Sync serveur → client
-- ─────────────────────────────────────────────

RegisterNetEvent('eightys_addiction:client:state', function(data)
    addicted = data.addicted
    drugName = data.drug
    lastUse  = data.last_use

    -- Si le joueur vient de terminer une désintox, on retire les effets
    if not addicted then
        clearWithdrawalEffects()
    end
end)

-- ─────────────────────────────────────────────
-- Export consommation (appelé par eightys_drugs)
-- ─────────────────────────────────────────────

exports('recordDrugUse', function(drug)
    -- Mise à jour locale immédiate du timestamp (en secondes, comme os.time)
    lastUse = math.floor(GetGameTimer() / 1000) + (os.time() - math.floor(GetGameTimer() / 1000))
    -- On utilise directement os.time côté serveur ; localement on note le moment
    lastUse = os.time and os.time() or (GetGameTimer() / 1000)

    TriggerServerEvent('eightys_addiction:server:recordUse', drug)

    -- Effet positif immédiat si déjà en manque
    if addicted and inWithdrawal then
        clearWithdrawalEffects()
        lib.notify({
            title       = 'Dose',
            description = 'Votre corps se stabilise...',
            type        = 'success',
            duration    = 4000,
        })
    end
end)

-- ─────────────────────────────────────────────
-- Thread sevrage (toutes les 30s)
-- ─────────────────────────────────────────────

local lastHealthDrain = 0   -- timestamp GetGameTimer pour le drain de santé toutes les 60s

CreateThread(function()
    while true do
        Wait(30000)

        if not addicted then
            -- Pas d'addiction : s'assurer que les effets sont bien retirés
            if inWithdrawal then clearWithdrawalEffects() end
        else
            local now = os.time()
            local timeSinceLastUse = now - lastUse

            if timeSinceLastUse < 3600 then
                -- Dose récente : pas de symptômes
                clearWithdrawalEffects()
            elseif timeSinceLastUse > 7200 then
                -- Plus de 2h sans drogue : symptômes de sevrage
                applyWithdrawalEffects()

                -- Drain de santé toutes les 60s si pas de dose depuis 4h
                if timeSinceLastUse > 14400 then
                    local gt = GetGameTimer()
                    if gt - lastHealthDrain >= 60000 then
                        lastHealthDrain = gt
                        local ped = PlayerPedId()
                        local hp  = GetEntityHealth(ped)
                        if hp > 100 then
                            SetEntityHealth(ped, hp - 5)
                        end
                    end
                end
            end
            -- Entre 1h et 2h : pas encore de symptômes, mais aucun retrait non plus
        end
    end
end)

-- ─────────────────────────────────────────────
-- Thread détox à l'hôpital (toutes les 2s)
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(2000)

        if addicted then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local dist = #(pos - detoxLocation)

            if dist < 2.0 then
                -- Affichage du prompt
                DrawText3D(detoxLocation.x, detoxLocation.y, detoxLocation.z + 1.0,
                    '[E] Demander une désintoxication ($1,000)')

                -- Détection de la touche E
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('eightys_addiction:server:detox')
                end
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Sync au login
-- ─────────────────────────────────────────────

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    TriggerServerEvent('eightys_addiction:server:requestSync')
end)
