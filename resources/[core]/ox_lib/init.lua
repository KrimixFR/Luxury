-- ================================================================
-- ox_lib — init.lua
-- Chargé par :  shared_scripts { '@ox_lib/init.lua' }
-- Définit lib.notify, lib.progressBar, lib.inputDialog, etc.
-- ================================================================

lib = lib or {}

-- ================================================================
-- lib.notify({ title, description, type, duration, position })
-- Types: 'success' | 'error' | 'inform' | 'warning'
-- ================================================================
if IsDuplicityVersion() then
    -- Côté serveur : on déclenche l'événement client
    function lib.notify(source, data)
        if type(source) == 'table' then
            -- Appelé sans source → broadcast (ou notification locale en contexte non-event)
            TriggerClientEvent('ox_lib:notify', -1, source)
        else
            TriggerClientEvent('ox_lib:notify', source, data)
        end
    end
else
    -- Côté client
    function lib.notify(data)
        if type(data) ~= 'table' then return end
        SendNUIMessage({
            type     = 'NOTIFY',
            title    = data.title    or '',
            message  = data.description or data.message or '',
            style    = data.type     or 'inform',
            duration = data.duration or 4000,
            position = data.position or 'top-right',
        })
    end
end

-- ================================================================
-- lib.progressBar(data, callback)
-- ================================================================
if not IsDuplicityVersion() then
    function lib.progressBar(data, cb)
        if type(data) ~= 'table' then if cb then cb(true) end return end

        local duration   = data.duration   or 3000
        local label      = data.label      or ''
        local canCancel  = data.canCancel ~= false
        local useWhileDead = data.useWhileDead or false
        local disabled   = data.disable   or {}

        -- Vérifications rapides
        if not useWhileDead and IsEntityDead(PlayerPedId()) then
            if cb then cb(true) end
            return
        end

        -- Lancer l'animation
        local ped    = PlayerPedId()
        local animDict = data.anim and data.anim.dict
        local animClip = data.anim and data.anim.clip
        if animDict and animClip then
            RequestAnimDict(animDict)
            local timeout = GetGameTimer() + 3000
            while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do
                Wait(100)
            end
            if HasAnimDictLoaded(animDict) then
                TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, duration, 49, 0, false, false, false)
            end
        end

        -- Afficher la barre NUI
        SendNUIMessage({
            type     = 'PROGRESS_START',
            label    = label,
            duration = duration,
        })

        -- Écouter annulation (BACKSPACE)
        local cancelled = false
        local startTime = GetGameTimer()

        CreateThread(function()
            while GetGameTimer() - startTime < duration do
                Wait(0)

                -- Désactiver les contrôles
                if disabled.car     then DisableControlAction(0, 59, true) end
                if disabled.combat  then
                    DisableControlAction(0, 24, true)
                    DisableControlAction(0, 25, true)
                    DisableControlAction(0, 47, true)
                end
                if disabled.move    then
                    DisableControlAction(0, 30, true)
                    DisableControlAction(0, 31, true)
                end

                -- Annulation
                if canCancel and IsControlJustReleased(0, 194) then  -- BACKSPACE
                    cancelled = true
                    break
                end
            end

            -- Stopper l'animation
            if animDict and animClip then
                StopAnimTask(ped, animDict, animClip, 1.0)
            end

            SendNUIMessage({ type = 'PROGRESS_STOP' })

            if cb then cb(cancelled) end
        end)
    end
end

-- ================================================================
-- lib.inputDialog(title, fields) → values[] | nil
-- Bloquant (via Citizen.Await)
-- ================================================================
if not IsDuplicityVersion() then
    function lib.inputDialog(title, fields)
        if type(fields) ~= 'table' then return nil end

        local p = promise.new()

        SendNUIMessage({
            type   = 'INPUT_OPEN',
            title  = title or 'Entrée',
            fields = fields,
        })
        SetNuiFocus(true, true)

        RegisterNUICallback('inputSubmit', function(data, cb)
            SetNuiFocus(false, false)
            cb('ok')
            p:resolve(data.values)
        end)

        RegisterNUICallback('inputCancel', function(_, cb)
            SetNuiFocus(false, false)
            cb('ok')
            p:resolve(nil)
        end)

        return Citizen.Await(p)
    end
end

-- ================================================================
-- lib.registerContext(data) + lib.showContext(id)
-- ================================================================
if not IsDuplicityVersion() then
    local contexts = {}

    function lib.registerContext(data)
        if not data or not data.id then return end
        contexts[data.id] = data
    end

    function lib.showContext(id)
        local ctx = contexts[id]
        if not ctx then return end

        SendNUIMessage({
            type    = 'CONTEXT_OPEN',
            context = ctx,
        })
        SetNuiFocus(true, true)

        RegisterNUICallback('contextSelect', function(data, cb)
            cb('ok')
            local option = ctx.options and ctx.options[tonumber(data.index)]
            if option and type(option.onSelect) == 'function' then
                SetNuiFocus(false, false)
                option.onSelect()
            end
        end)

        RegisterNUICallback('contextClose', function(_, cb)
            SetNuiFocus(false, false)
            cb('ok')
        end)
    end

    function lib.hideContext()
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'CONTEXT_CLOSE' })
    end
end

-- ================================================================
-- lib.alertDialog(data) → 'confirm' | 'cancel'
-- ================================================================
if not IsDuplicityVersion() then
    function lib.alertDialog(data)
        if type(data) ~= 'table' then return 'cancel' end

        local p = promise.new()

        SendNUIMessage({
            type    = 'ALERT_OPEN',
            header  = data.header  or 'Confirmation',
            content = data.content or '',
            cancel  = data.cancel  ~= false,
        })
        SetNuiFocus(true, true)

        RegisterNUICallback('alertConfirm', function(_, cb)
            SetNuiFocus(false, false)
            cb('ok')
            p:resolve('confirm')
        end)

        RegisterNUICallback('alertCancel', function(_, cb)
            SetNuiFocus(false, false)
            cb('ok')
            p:resolve('cancel')
        end)

        return Citizen.Await(p)
    end
end
