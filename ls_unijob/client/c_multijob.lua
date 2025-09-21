RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    if ESX.PlayerData then
        ESX.PlayerData.job = job
        TriggerServerEvent('ls_utils:server:clientJobUpdated', job.name, job.grade)

    else
        print('^1[LS_UNIJOB] Error: esx:setJob client handler - ESX.PlayerData non disponibile.^7')
    end
end)

local function GetBaseJobName()
    return Sime.BossMenu.LavoroBase or "unemployed" 
end

local inService = false

RegisterNetEvent("ls_utils:SyncService")
AddEventHandler("ls_utils:SyncService", function(state)
    inService = state
end)

MostraLavori = function()
    Citizen.CreateThread(function()
        local hoSalvato, err
        local success, errore = pcall(function()
            hoSalvato, err = lib.callback.await('ls_utils:getJobs', 500, false)
        end)
        if not success or err then
            ESX.ShowNotification("Errore nel recupero dei lavori: " .. tostring(errore or err), "error")
            return
        end
        if not hoSalvato then hoSalvato = {} end

        local menuLavori = { id="menu_lavori", title="Multi Lavoro", options={} }

        table.insert(menuLavori.options, {title = "Servizio", description = ("Stato attuale: %s"):format(inService and "In Servizio" or "Fuori Servizio"), icon = inService and "fa-toggle-on" or "fa-toggle-off", iconColor = inService and "#00ff00" or "#ff0000",
            onSelect = function()
                local inservizio = lib.progressCircle({
                    duration = 3500,
                    label = inService and "Uscendo dal Servizio" or "Entrando in Servizio",
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = false, car = true, combat = false },
                    anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' }
                })
                if inservizio then
                    TriggerServerEvent("ls_utils:InServizio", not inService)
                    Wait(500)
                    MostraLavori()
                end
            end
        })

        local allJobs = {}
        do
            local found = false
            for _, sj in ipairs(hoSalvato) do
                if sj.name == ESX.PlayerData.job.name and sj.grade == ESX.PlayerData.job.grade then
                    table.insert(allJobs, sj)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(allJobs, {name = ESX.PlayerData.job.name, grade = ESX.PlayerData.job.grade,label = ESX.PlayerData.job.label or ESX.PlayerData.job.name, gradeLabel = ESX.PlayerData.job.grade_label or ("Grado " .. ESX.PlayerData.job.grade), salary = ESX.PlayerData.job.salary or "N/D"})
            end
        end

        for _, sj in ipairs(hoSalvato) do
            if not (sj.name == ESX.PlayerData.job.name and sj.grade == ESX.PlayerData.job.grade) and sj.name ~= GetBaseJobName() then
                table.insert(allJobs, sj)
            end
        end

        local baseInfo = lib.callback.await('ls_utils:getJobInfo', true, GetBaseJobName())
        while #allJobs < (Sime.MultiJob.Max or 2) do
            table.insert(allJobs, {name = GetBaseJobName(), grade = 0, label = (baseInfo and baseInfo.label) or GetBaseJobName(), gradeLabel = baseInfo.grades["0"].label, salary = baseInfo.grades["0"].salary or "N/D"})
        end

        for i = 1, (Sime.MultiJob.Max or 2) do
            local job = allJobs[i]
            local isCurrent = (job.name == ESX.PlayerData.job.name and job.grade == ESX.PlayerData.job.grade)
            
            table.insert(menuLavori.options, {title = ("%s%s"):format(job.label, (not isCurrent) and (" (Grado " .. job.grade .. ")") or ""), description = ("Grado: %s [%s]\nSalario: $%s"):format(job.gradeLabel, job.grade, job.salary), icon = isCurrent and "star" or "briefcase", iconColor = isCurrent and "#ffd700" or nil, disabled = false,
                onSelect = function()
                    local opts = {}
                    if job.name ~= GetBaseJobName() then
                        table.insert(opts, {title="Ore Lavorate", description=("Totale lavorate con questo lavoro: %sh"):format(job.ore_lavorate or 0), icon="hourglass-half", iconColor="#00aaff", disabled=true, progress= math.random(25,60), colorScheme="teal"})
                    end
                    table.insert(opts, {title = isCurrent and "Attualmente in uso" or "Imposta Come Attivo", description = ("Lavoro: %s (Grado %s)"):format(job.label, job.gradeLabel), icon = isCurrent and "star" or "check", iconColor = isCurrent and "#ffd700" or "#00ff00", disabled = isCurrent,
                        onSelect = not isCurrent and function()
                            TriggerServerEvent("ls_utils:cambiaLavoro", job.name, job.grade)
                            ESX.PlayerData.job = {name = job.name, grade = job.grade, label = job.label, grade_label= job.gradeLabel, salary = job.salary}
                            Wait(100)
                            MostraLavori()
                        end or nil
                    })

                    if Sime.MultiJob.AutoLicenziarsi then
                        table.insert(opts, {title = "Licenziati", description = ("Licenziati da: %s"):format(job.label), icon = "trash", iconColor = "#ff0000",
                            onSelect = function()
                                local a = lib.alertDialog({
                                    header = "Sei sicuro?",
                                    content = ("Vuoi Licenziarti da '%s' (Grado %s)?"):format(job.label, job.gradeLabel),
                                    centered = true,
                                    cancel = true,
                                    labels = {cancel = "Annulla", confirm = "Conferma"}
                                })

                                if a == "confirm" then
                                    local dimissioni = lib.progressCircle({
                                        duration = 3500,
                                        label = "Stai dando le dimissioni...",
                                        useWhileDead = false,
                                        canCancel = true,
                                        disable = { move = false, car = true, combat = false },
                                        anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' }
                                    })
                                    if dimissioni then
                                        TriggerServerEvent("ls_utils:removeJob", job.name)
                                        Wait(500)
                                        MostraLavori()
                                    else
                                        lib.showContext("job_actions")
                                    end
                                end
                            end
                        })
                    end

                    lib.registerContext({id = "job_actions", title = "Opzioni Lavoro", menu = "menu_lavori", options = opts})
                    lib.showContext("job_actions")
                end
            })
        end

        lib.registerContext(menuLavori)
        lib.showContext("menu_lavori")
    end)
end

if Sime.MultiJob.Attivo then
    lib.addKeybind({name = Sime.MultiJob.Comando, description = '[LS_UNIJOB] Apri gestione multi lavori', defaultMapper = 'keyboard', defaultKey = 'F6',
        onReleased = function()
            MostraLavori()
        end
    })
end