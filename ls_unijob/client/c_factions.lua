RegisterNetEvent('creajob', function()
    MenuCreatejob()
end)

RegisterCommand(Sime.CreaFazione.Comando, function()
    lib.callback.await('ls_utils:server:createjob')
end)

function MenuCreatejob()
    local jobs = {}

    table.insert(jobs, {label = "Crea una Fazione", icon = "plus", iconColor = "#3AD244", description = "Avvia la creazione di una nuova fazione.", args = {action = 'createjob'}})
    table.insert(jobs, {label = "Visualizza Fazioni", icon = "list", iconColor = "#2771B7", description = "Mostra l'elenco delle fazioni disponibili.", args = {action = 'viewfactions'}})

    lib.registerMenu({
        id = 'createjob',
        title = 'JOB CREATOR - LISTA',
        position = 'top-right',
        options = jobs
    }, function(selected, scrollIndex, args)
        if args.action == 'createjob' then
            CreateJob()
        elseif args.action == 'viewfactions' then
            local factions = {}
            local factionData = lib.callback.await('jobcreator:getjobs')

            for k, v in pairs(factionData) do
                local jobLabel = v.label
                if v.num_grades and v.num_grades > 0 then
                    jobLabel = jobLabel .. ' (' .. v.num_grades .. ' gradi)'
                end
                table.insert(factions, {label = jobLabel, icon = "landmark-flag", iconColor = "#2771B7", args = {action = 'jobmenu', name = v.name}})
            end

            lib.registerMenu({
                id = 'viewfactions',
                title = 'Fazioni Create',
                position = 'top-right',
                options = factions,
                onClose = function(keyPressed)
                    MenuCreatejob()
                end
            }, function(selected, scrollIndex, args)
                JobMenu(args.name)
            end)

            lib.showMenu('viewfactions')
        end
    end)
    lib.showMenu('createjob')
end

local tabella = {
    name = nil,
    label = nil,
    bossmenu = {},
    depositi = {},
    camerino = {},
    garage = {},
    blips = {},
    grades = {}
}

function CreateJob()
    lib.registerMenu({
        id = "jobmenu",
        title = "JOB CREATOR - CREAZIONE",
        position = "top-right",
        onClose = function(keyPressed)
            MenuCreatejob()
        end,
        options = {
            {label = "Nome: " .. (tabella.name or ""), description = "Nome identificativo nel comando /setjob.", args = {action = "name"}, icon = "user", iconColor = "#3498DB"},
            {label = "Label: " .. (tabella.label or ""), description = "Nome visibile ai giocatori.", args = {action = "label"}, icon = "tag", iconColor = "#2ECC71"},
            {label = "Gradi: " .. #tabella.grades, description = "Numero di gradi disponibili per il lavoro.", args = {action = "grades"}, icon = "ranking-star", iconColor = "#F39C12"},
            {label = "Conferma Creazione", description = "Conferma e crea il nuovo lavoro.", args = {action = "creafazione"}, icon = "check-circle", iconColor = "#E74C3C"}
        }
    }, function(selected, scrollIndex, args)
        if args.action == "name" then
            local input = lib.inputDialog("Nome Lavoro", {
                {type = "input", label = "Nome", description = "Inserisci il nome del lavoro nel comando /setjob.", icon = "briefcase", required = true}
            })
            if input and input[1] then
                if lib.callback.await('jobcreator:checkJob', false, input[1]) then
                    ESX.ShowNotification(("Il lavoro con il nome \"%s\" esiste già."):format(input[1]))
                    CreateJob()
                else
                    tabella.name = input[1]
                    CreateJob()
                end
            else
                CreateJob()
            end
            CreateJob()
        elseif args.action == "label" then
            local input = lib.inputDialog("Label Lavoro", {
                {type = "input", label = "Label", description = "Inserisci il nome visibile del lavoro.", icon = "briefcase", required = true}
            })
            if input then
                tabella.label = input[1]
            else
                CreateJob()
            end
            CreateJob()
        elseif args.action == "grades" then
            GradesMenu()
        elseif args.action == "creafazione" then
            TriggerServerEvent("jobcreator:azioni", "creafazione", tabella)
            tabella = {name = nil, label = nil, bossmenu = {}, depositi = {}, camerino = {}, garage = {}, blips = {}, grades = {}}
            CreateJob()
        end
    end)
    lib.showMenu("jobmenu")
end

function GradesMenu()
    local menugradi = {}

    table.insert(menugradi, {label = "Crea un nuovo grado", icon = "plus", iconColor = "blue", description = "Aggiungi un nuovo grado al lavoro", args = {action = "creagradi"}})

    for k, v in pairs(tabella.grades) do
        table.insert(menugradi, {label = string.format("%s – (%d)", v.label, v.numgrado), icon = "user", iconColor = "orange", close = false, args = {gradeIndex = k}})
    end

    lib.registerMenu({
        id = "menugradi",
        title = "JOB CREATOR – GRADI",
        description = "Seleziona un grado esistente o creane uno nuovo",
        position = "top-right",
        options = menugradi,
        onClose = function()
            CreateJob()
        end
    }, function(selected, scrollIndex, args)
        if args.action == "creagradi" then
            local input = lib.inputDialog("Crea un nuovo grado", {
                {type = "number", label = "Numero Grado", default = (#tabella.grades > 0 and #tabella.grades or 1), description = "Numero identificativo del grado"},
                {type = "input", label = "Nome Grado", default = "grade" .. (#tabella.grades > 0 and #tabella.grades or 1), description = "Nome interno del grado"},
                {type = "input", label = "Label Grado", default = "Grado " .. (#tabella.grades > 0 and #tabella.grades or 1), description = "Etichetta visualizzata ai giocatori"},
                {type = "number", label = "Stipendio", default = 100, description = "Stipendio assegnato al grado"}
            })
            if input and #input == 4 then
                table.insert(tabella.grades, {numgrado = input[1], name = input[2], label = input[3], salary = input[4]})
                GradesMenu()
            else
                GradesMenu()
            end
        end
    end)

    lib.showMenu("menugradi")
end

function JobMenu(job)
    local json = lib.callback.await('jobcreator:getjson')
    for k, data in pairs(json) do
        if job == data.name then
            local elements = {
                {label = "Boss Menu", icon = "user", iconColor = "#3498DB", description = "Gestisci ruoli e permessi. Boss Menù creati: " .. #data.bossmenu, args = {action = "bossmenu"}},
                {label = "Depositi", icon = "box", iconColor = "#F39C12", description = "Visualizza e gestisci i depositi disponibili. Depositi creati: " .. #data.depositi, args = {action = "depositi"}},
                {label = "Camerini", icon = "shirt", iconColor = "#2ECC71", description = "Gestisci gli abiti disponibili. Camerini creati: " .. #data.camerino, args = {action = "camerino"}},
                {label = "Blips", icon = "map-pin", iconColor = "#E67E22", description = "Visualizza e modifica i blips sulla mappa. Blips creati: " .. #data.blips, args = {action = "blips"}},
                {label = "Garage", icon = "car", iconColor = "#9B59B6", description = "Gestisci i veicoli disponibili. Garage creati: " .. #data.garage, args = {action = "garage"}},
                {label = "Gradi", icon = "user", iconColor = "#1ABC9C", description = "Gestisci i ruoli e i gradi dei membri. Gradi creati: " .. #data.grades, args = {action = "grades"}},
                {label = "Elimina Lavoro", icon = "times", iconColor = "#E74C3C", description = "Rimuovi definitivamente il lavoro selezionato.", args = {action = "delete"}}
            }

            lib.registerMenu({
                id = 'jobmenu',
                title = 'JOB CREATOR - '..data.label,
                position = 'top-right',
                onClose = function(keyPressed)
                    MenuCreatejob()
                end,
                options = elements
            }, function(selected, scrollIndex, args)
                Actions(args.action, data.name)
            end)
            
            lib.showMenu('jobmenu')
        end
    end
end


function OpenDepositDetails(v, index, job)
    local deposit = v.depositi[index]

    lib.registerMenu({
        id = 'menudepositidetails',
        title = 'JOB CREATOR - DEPOSITO DETTAGLI',
        position = 'top-right',
        options = {
            {label = "Teletrasportati", icon = "map-pin", iconColor = "#3498DB", description = "Spostati direttamente alla posizione selezionata.", args = {action = "tippati"}},
            {label = "Modifica Posizione", icon = "map-marker-alt", iconColor = "#F39C12", description = "Aggiorna la posizione attuale del deposito.", args = {action = "modifica1"}},
            {label = "Modifica Impostazioni", icon = "cogs", iconColor = "#2ECC71", description = "Personalizza le impostazioni del deposito.", args = {action = "modifica2"}},
            {label = "Elimina Deposito", icon = "trash", iconColor = "#E74C3C", description = "Rimuovi definitivamente il deposito selezionato.", args = {action = "delete"}}
        },
        onClose = function() 
            Actions('depositi', job)
        end
    }, function(selected, scrollIndex, args)
        if args.action == 'tippati' then
                local alert = lib.alertDialog({
                header = 'Teletrasporto',
                content = "Sicuro di voler teletrasportarti immediatamente alla posizione del deposito?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                SetEntityCoords(cache.ped, vector3(deposit.pos.x, deposit.pos.y, deposit.pos.z))
                Actions('depositi', job)
            else
                Actions('depositi', job)
            end
        elseif args.action == 'modifica1' then
            local coords = GetEntityCoords(cache.ped)
            local alert = lib.alertDialog({
                header = 'Modifica Posizione',
                content = "Sei sicuro di voler modificare la posizione del deposito?\n\n{x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z .. "}",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                deposit.pos = coords
                TriggerServerEvent('jobcreator:azioni', 'creadeposito', v)
                Actions('depositi', job)
            else
                Actions('depositi', job)
            end
        elseif args.action == 'modifica2' then
            local input = lib.inputDialog("MODIFICA DEPOSITO", {
                {type = "input", default = "x = " .. deposit.pos.x .. ", y = " .. deposit.pos.y .. ", z = " .. deposit.pos.z, label = "Coordinate", description = "Posizione esatta del deposito.", icon = "map-marker-alt", disabled = true},
                {type = "input", label = "Nome Deposito", default = deposit.name, description = "Nome identificativo del deposito.", icon = "warehouse"},
                {type = "number", label = "Numero Slots", default = deposit.slots, description = "Capacità massima di slot disponibili.", icon = "database"},
                {type = "number", label = "Peso Massimo", default = deposit.peso, description = "Limite massimo di peso contenuto nel deposito.", icon = "balance-scale"},
                {type = "number", label = "Grado Minimo", default = deposit.mingrade, description = "Livello minimo richiesto per l'accesso.", icon = "user-shield", min = 0}
            })
            if input then
                v.depositi[index] = {
                    pos = deposit.pos,
                    name = input[2],
                    slots = input[3],
                    peso = input[4],
                    mingrade = input[5]
                }
                TriggerServerEvent('jobcreator:azioni', 'creadeposito', v)
                Actions('depositi', job)
            else
                Actions('depositi', job)
            end
        elseif args.action == 'delete' then
            local alert = lib.alertDialog({
                header = 'Elimina Deposito',
                content = "Sei sicuro di voler eliminare il deposito?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                table.remove(v.depositi, index)
                TriggerServerEvent('jobcreator:azioni', 'creadeposito', v)
                Actions('depositi', job)
            end
        end
    end)
    lib.showMenu('menudepositidetails')
end

function OpenBossMenuDetails(v, index, job)
    local bossmenu = v.bossmenu[index]
    lib.registerMenu({
        id = 'menubossmenudetails',
        title = 'JOB CREATOR - BOSSMENU DETTAGLI',
        position = 'top-right',
        options = {
            {label = "Teletrasportati", icon = "map-pin", iconColor = "#3498DB", description = "Spostati immediatamente alla posizione selezionata.", args = {action = "tippati"}},
            {label = "Modifica Posizione", icon = "map-marker-alt", iconColor = "#F39C12", description = "Aggiorna la posizione attuale del boss menu.", args = {action = "modifica1"}},
            {label = "Modifica Impostazioni", icon = "cogs", iconColor = "#2ECC71", description = "Modifica le impostazioni generali del boss menu.", args = {action = "modifica2"}},
            {label = "Elimina Boss Menu", icon = "trash", iconColor = "#E74C3C", description = "Rimuovi definitivamente il boss menu.", args = {action = "delete"}}
        },
        onClose = function()
            Actions('bossmenu', job)
        end
    }, function(selected, scrollIndex, args)
        if args.action == 'tippati' then
                local alert = lib.alertDialog({
                header = 'Teletrasporto',
                content = "Sicuro di voler teletrasportarti immediatamente alla posizione del bossmenu?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                SetEntityCoords(cache.ped, vector3(bossmenu.pos.x, bossmenu.pos.y, bossmenu.pos.z))
                Actions('bossmenu', job)
                OpenBossMenuDetails(v, args.index, job)
            else
                OpenBossMenuDetails(v, args.index, job)
            end
        elseif args.action == 'modifica1' then
            local coords = GetEntityCoords(cache.ped)
            local alert = lib.alertDialog({
                header = 'Modifica Posizione Boss Menu',
                content = "Sei sicuro di voler modificare la posizione del bossmenu?\n\n{x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z .. "}",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                bossmenu.pos = coords
                TriggerServerEvent('jobcreator:azioni', 'creabossmenu', v)
                Actions('bossmenu', job)
            else
                Actions('bossmenu', job)
            end
        elseif args.action == 'modifica2' then
            local jsoncoords = "x = " .. bossmenu.pos.x .. ", y = " .. bossmenu.pos.y .. ", z = " .. bossmenu.pos.z
            local input = lib.inputDialog("Modifica Boss Menu", {
                {type = "input", default = jsoncoords, label = "Coordinate", description = "Coordinate esatte della posizione del Boss Menu.", icon = "map-marker-alt", disabled = true},
                {type = "number", label = "Grado Minimo", default = bossmenu.mingrade, description = "Livello minimo richiesto per l'accesso al menu.", icon = "user-shield", min = 0}
            })
            if input then
                bossmenu.mingrade = input[2]
                TriggerServerEvent('jobcreator:azioni', 'creabossmenu', v)
                Actions('bossmenu', job)
            else
                Actions('bossmenu', job)
            end
        elseif args.action == 'delete' then
            local alert = lib.alertDialog({
                header = 'ELIMINA BOSSMENU',
                content = "Sei sicuro di voler eliminare il bossmenu?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                v.bossmenu[index] = nil
                TriggerServerEvent('jobcreator:azioni', 'creabossmenu', v)
                Actions('bossmenu', job)
            else
                Actions('bossmenu', job)
            end
        end
    end)
    lib.showMenu('menubossmenudetails')
end

function OpenCamerinoDetails(v, index, job)
    local camerino = v.camerino[index]
    lib.registerMenu({
        id = 'menucamerinodetails',
        title = 'JOB CREATOR - CAMERINO DETTAGLI',
        position = 'top-right',
        options = {
            {label = "Teletrasportati", icon = "map-pin", iconColor = "#3498DB", description = "Spostati immediatamente alla posizione selezionata.", args = {action = "tippati"}},
            {label = "Modifica Posizione", icon = "map-marker-alt", iconColor = "#F39C12", description = "Aggiorna la posizione del camerino sulla mappa.", args = {action = "modifica1"}},
            {label = "Modifica Impostazioni", icon = "sliders-h", iconColor = "#2ECC71", description = "Personalizza le impostazioni del camerino.", args = {action = "modifica2"}},
            {label = "Elimina Camerino", icon = "trash", iconColor = "#E74C3C", description = "Rimuovi definitivamente il camerino selezionato.", args = {action = "delete"}}
        },
        onClose = function()
            Actions('camerino', job)
        end
    }, function(selected, scrollIndex, args)
        if args.action == 'tippati' then
            local alert = lib.alertDialog({
                header = 'Teletrasporto',
                content = "Sicuro di voler teletrasportarti immediatamente alla posizione del camerino?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                SetEntityCoords(cache.ped, vector3(camerino.pos.x, camerino.pos.y, camerino.pos.z))
                Actions('camerino', job)
            else
                Actions('camerino', job)
            end
        elseif args.action == 'modifica1' then
            local coords = GetEntityCoords(cache.ped)
            local alert = lib.alertDialog({
                header = 'Modifica Posizione Camerino',
                content = "Sei sicuro di voler modificare la posizione del camerino?\n\n{x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z .. "}",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                camerino.pos = coords
                TriggerServerEvent('jobcreator:azioni', 'creacamerino', v)
                Actions('camerino', job)
            else
                Actions('camerino', job)
            end
        elseif args.action == 'modifica2' then
            local jsoncoords = "x = " .. camerino.pos.x .. ", y = " .. camerino.pos.y .. ", z = " .. camerino.pos.z
            local input = lib.inputDialog("Modifica Camerino", {
                {type = "input", default = jsoncoords, label = "Coordinate", description = "Posizione esatta del camerino.", icon = "map-marker-alt", iconColor = "#F39C12", disabled = true},
                {type = "number", label = "Grado Minimo", default = camerino.mingrade, description = "Livello minimo richiesto per accedere al camerino.", icon = "user-shield", iconColor = "#3498DB", min = 0}
            })
            if input then
                camerino.mingrade = input[2]
                TriggerServerEvent('jobcreator:azioni', 'creacamerino', v)
                Actions('camerino', job)
            else
                Actions('camerino', job)
            end
        elseif args.action == 'delete' then
            local alert = lib.alertDialog({
                header = 'Elimina Camerino',
                content = "Sei sicuro di voler eliminare il camerino?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                v.camerino[index] = nil
                TriggerServerEvent('jobcreator:azioni', 'creacamerino', v)
                Actions('camerino', job)
            else
                Actions('camerino', job)
            end
        end
    end)

    lib.showMenu('menucamerinodetails')
end

function OpenBlipDetails(v, index, job)
    local blip = v.blips[index]
    lib.registerMenu({
        id = 'menublipdetails',
        title = 'JOB CREATOR - BLIP DETTAGLI',
        position = 'top-right',
        options = {
            {label = "Teletrasportati", icon = "map-pin", iconColor = "#3498DB", description = "Spostati istantaneamente alla posizione selezionata.", args = {action = "tippati"}},
            {label = "Modifica Posizione", icon = "map-marker-alt", iconColor = "#F39C12", description = "Aggiorna la posizione del blip sulla mappa.", args = {action = "modifica1"}},
            {label = "Modifica Impostazioni", icon = "sliders-h", iconColor = "#2ECC71", description = "Personalizza le impostazioni avanzate del blip.", args = {action = "modifica2"}},
            {label = "Elimina Blip", icon = "trash", iconColor = "#E74C3C", description = "Rimuovi definitivamente il blip selezionato dalla mappa.", args = {action = "delete"}}
        },
        onClose = function()
            Actions('blips', job)
        end
    }, function(selected, scrollIndex, args)
        if args.action == 'tippati' then
            local alert = lib.alertDialog({
                header = 'Teletrasporto',
                content = "Sicuro di voler teletrasportarti immediatamente alla posizione del blip?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                SetEntityCoords(cache.ped, vector3(blip.pos.x, blip.pos.y, blip.pos.z))
                Actions('blips', job)
            else
                Actions('blips', job)
            end
        elseif args.action == 'modifica1' then
            local coords = GetEntityCoords(cache.ped)
            local alert = lib.alertDialog({
                header = 'Modifica Posizione Blip',
                content = "Sei sicuro di voler modificare la posizione del blip?\n\n{x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z .. "}",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                blip.pos = coords
                TriggerServerEvent('jobcreator:azioni', 'creablip', v)
                Actions('blips', job)
            else
                Actions('blips', job)
            end
        elseif args.action == 'modifica2' then
            local jsoncoords = "x = " .. blip.pos.x .. ", y = " .. blip.pos.y .. ", z = " .. blip.pos.z
            local input = lib.inputDialog("Modifica Blip", {
                {type = "input", default = jsoncoords, label = "Coordinate", description = "Posizione esatta del blip sulla mappa.", icon = "map-marker-alt", disabled = true},
                {type = "input", label = "Nome Blip", default = blip.name, description = "Nome identificativo del blip sulla mappa.", icon = "tag"},
                {type = "number", label = "ID Blip", default = blip.id, description = "ID unico assegnato al blip sulla mappa.", icon = "fingerprint"},
                {type = "number", label = "Colore Blip", default = blip.color, description = "Colore con cui verrà visualizzato il blip.", icon = "palette"},
                {type = "input", label = "Grandezza Blip", precision = true, default = blip.scale, description = "Dimensione del blip sulla mappa.", icon = "expand-arrows-alt"}
            })
            if input then
                blip.name = input[2]
                blip.id = input[3]
                blip.color = input[4]
                blip.scale = input[5]
                TriggerServerEvent('jobcreator:azioni', 'creablip', v)
                Actions('blips', job)
            else
                Actions('blips', job)
            end
        elseif args.action == 'delete' then
            local alert = lib.alertDialog({
                header = 'Elimina Blip',
                content = "Sei sicuro di voler eliminare il blip?",
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                v.blips[index] = nil
                TriggerServerEvent('jobcreator:azioni', 'creablip', v)
                Actions('blips', job)
            else
                Actions('blips', job)
            end
        end
    end)

    lib.showMenu('menublipdetails')
end

function Actions(azione, job)
    local json = lib.callback.await('jobcreator:getjson')
    for k,v in pairs(json) do
        if job == v.name  then
            if azione == 'depositi' then
                local depositi = {}
                table.insert(depositi, {label = "Crea un nuovo deposito", icon = "plus", iconColor = "#2ECC71", description = "Crea un nuovo deposito per la gestione degli oggetti e delle risorse.", args = {action = "creadeposito"}})
                for c, e in pairs(v.depositi) do
                    table.insert(depositi, {label = e.name .. " - (" .. e.slots .. ")", icon = "box", iconColor = "#F39C12", description = "Capacità: " .. e.slots .. " slot | Peso: " .. e.peso .. " kg", args = {index = c}})
                end
                lib.registerMenu({
                    id = 'menudepositi',
                    title = 'JOB CREATOR - DEPOSITI',
                    position = 'top-right',
                    options = depositi,
                    onClose = function() 
                        JobMenu(job)
                    end
                }, function(selected, scrollIndex, args)
                    if args.action == 'creadeposito' then
                        local coords = GetEntityCoords(cache.ped)
                        local jsoncoords = "x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z
                        local input = lib.inputDialog("Crea un nuovo deposito", {
                            {type = "input", default = jsoncoords, label = "Coordinate", description = "Coordinate esatte del deposito", icon = "map-marker-alt", disabled = true},
                            {type = "input", label = "Nome Deposito", default = "Deposito", description = "Nome identificativo del deposito", icon = "warehouse"},
                            {type = "number", label = "Numero Slots", default = 100, description = "Numero massimo di slot disponibili", icon = "database"},
                            {type = "number", label = "Capacità Peso", default = 1000, description = "Limite massimo di peso contenuto", icon = "balance-scale"},
                            {type = "number", label = "Grado Minimo", default = 0, description = "Grado minimo richiesto per l'accesso", icon = "user-shield", min = 0}
                        })
                        if input then
                            table.insert(v.depositi, {pos = GetEntityCoords(cache.ped), name = input[2], slots = input[3], peso = input[4], mingrade = input[5]})
                            TriggerServerEvent('jobcreator:azioni', 'creadeposito', v)
                            Actions('depositi', job)
                        else
                            Actions('depositi', job)
                        end
                    else
                        OpenDepositDetails(v, args.index, job)
                    end
                end)
                lib.showMenu('menudepositi')
            elseif azione == 'bossmenu' then
                local bossmenus = {}
                table.insert(bossmenus, {label = "Crea un nuovo Boss Menu", icon = "plus", iconColor = "#2ECC71", description = "Crea un nuovo Boss Menu per gestire l'organizzazione e i ruoli.", args = {action = "creabossmenu"}})
                for c, e in pairs(v.bossmenu) do
                    table.insert(bossmenus, {label = "Boss Menu (" .. c .. ")", icon = "laptop", iconColor = "#3498DB", description = "Gestisci ruoli e permessi nel Boss Menu " .. c .. ".",  args = {index = c}})
                end

                lib.registerMenu({
                    id = 'menubossmenu',
                    title = 'JOB CREATOR - BOSSMENU',
                    position = 'top-right',
                    options = bossmenus,
                    onClose = function()
                        JobMenu(job)
                    end
                }, function(selected, scrollIndex, args)
                    if args.action == 'creabossmenu' then
                        local coords = GetEntityCoords(cache.ped)
                        local jsoncoords = "x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z
                        local input = lib.inputDialog("Crea un nuovo Boss Menu", {
                            {type = "input", default = jsoncoords, label = "Coordinate", description = "Coordinate esatte della posizione del Boss Menu.", icon = "map-marker-alt", disabled = true},
                            {type = "number", label = "Grado Minimo", default = 0, description = "Livello minimo richiesto per accedere al Boss Menu.", icon = "user-shield", min = 0}
                        })
                        if input then
                            table.insert(v.bossmenu, {pos = coords, mingrade = input[2]})
                            TriggerServerEvent('jobcreator:azioni', 'creabossmenu', v)
                            Actions('bossmenu', job)
                        else
                            Actions('bossmenu', job)
                        end
                    else
                        OpenBossMenuDetails(v, args.index, job)
                    end
                end)

                lib.showMenu('menubossmenu')
            elseif azione == 'camerino' then
                local camerino = {}
                table.insert(camerino, {label = "Crea un nuovo Camerino", icon = "plus", iconColor = "#2ECC71", description = "Aggiungi un nuovo Camerino per la personalizzazione degli abiti.", args = {action = "creacamerino"}})
                for c, e in pairs(v.camerino) do
                    table.insert(camerino, {label = "Camerino (" .. c .. ")", icon = "shirt", iconColor = "#F39C12", description = "Gestisci gli abiti e gli accessori disponibili nel Camerino " .. c .. ".", args = {index = c}})
                end

                lib.registerMenu({
                    id = 'menucamerino',
                    title = 'JOB CREATOR - CAMERINO',
                    position = 'top-right',
                    options = camerino,
                    onClose = function()
                        JobMenu(job)
                    end
                }, function(selected, scrollIndex, args)
                    if args.action == 'creacamerino' then
                        local coords = GetEntityCoords(cache.ped)
                        local jsoncoords = "x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z
                        local input = lib.inputDialog("Camerino", {
                            {type = "input", default = jsoncoords, label = "Coordinate", description = "Posizione esatta del camerino.", icon = "map-marker-alt", disabled = true},
                            {type = "number", label = "Grado Minimo", default = 0, description = "Livello minimo richiesto per accedere al camerino.", icon = "user-shield", min = 0}
                        })
                        if input then
                            table.insert(v.camerino, {pos = coords, mingrade = input[2]})
                            TriggerServerEvent('jobcreator:azioni', 'creacamerino', v)
                            Actions('camerino', job)
                        else
                            Actions('camerino', job)
                        end
                    else
                        OpenCamerinoDetails(v, args.index, job)
                    end
                end)

                lib.showMenu('menucamerino')
            elseif azione == 'blips' then
                local blip = {}

                table.insert(blip, {label = "Crea Nuovo Blip", icon = "plus", description = "Aggiungi un nuovo blip alla mappa con parametri personalizzati.", args = {action = "creablip"}})
                for a, b in pairs(v.blips) do
                    table.insert(blip, {label = b.name .. " (" .. a .. ")", icon = "map-pin", description = "Blip #" .. a .. " - Posizione sulla mappa.", args = {index = a}})
                end

                lib.registerMenu({
                    id = 'menublip',
                    title = 'JOB CREATOR - BLIP',
                    position = 'top-right',
                    options = blip,
                    onClose = function()
                        JobMenu(job)
                    end
                }, function(selected, scrollIndex, args)
                    if args.action == 'creablip' then
                        local coords = GetEntityCoords(cache.ped)
                        local jsoncoords = "x = " .. coords.x .. ", y = " .. coords.y .. ", z = " .. coords.z
                        local input = lib.inputDialog("Crea Nuovo Blip", {
                            {type = "input", default = jsoncoords, label = "Coordinate", description = "Posizione esatta del blip sulla mappa.", icon = "map-marker-alt", disabled = true},
                            {type = "input", label = "Nome Blip", default = "Blip", description = "Nome identificativo del blip sulla mappa.", icon = "tag"},
                            {type = "number", label = "ID Blip", default = 1, description = "ID unico assegnato al blip sulla mappa.", icon = "fingerprint"},
                            {type = "number", label = "Colore Blip", default = 1, description = "Colore con cui verrà visualizzato il blip sulla mappa.", icon = "palette"},
                            {type = "input", label = "Grandezza Blip", precision = true, default = "0.7", description = "Dimensione del blip sulla mappa.", icon = "expand-arrows-alt"}
                        })
                        if input then
                            table.insert(v.blips, {
                                pos = coords,
                                id = input[3],
                                color = input[4],
                                scale = input[5],
                                name = input[2],
                            })
                            TriggerServerEvent('jobcreator:azioni', 'creablip', v)
                            Actions('blips', job)
                        else
                            Actions('blips', job)
                        end
                    else
                        OpenBlipDetails(v, args.index, job)
                    end
                end)

                lib.showMenu('menublip')
            elseif azione == 'garage' then
                OpenGarageMenu(v)
            elseif azione == 'grades' then 
                local function GradesMenu()
                local menugradi = {}
                table.insert(menugradi, {label = "Crea un nuovo grado", icon = "plus", iconColor = "#2ECC71", description = "Crea un nuovo grado personalizzato con nome, stipendio e privilegi.", args = {value = "addgrade"}})

                for a, b in pairs(v.grades) do
                    table.insert(menugradi, {label = b.label .. " - (" .. b.numgrado .. ")", icon = "pen-ruler",  iconColor = "#3498DB", description = "Questa fazione ha un totale di " .. #v.grades .. " gradi disponibili.", args = {value = a}})
                end
            
                lib.registerMenu({
                    id = 'grades_menu',
                    title = 'JOB CREATOR - GRADI',
                    position = 'top-right',
                    options = menugradi,
                    onClose = function()
                        JobMenu(job)
                    end
                }, function(selected, scrollIndex, args)
                    local value = args.value
            
                    if value == 'addgrade' then
                        local input = lib.inputDialog("AGGIUNGI NUOVO GRADO", {
                            {type = "number", label = "Numero Grado", default = #v.grades, description = "Posizione del grado nell'organizzazione (/setjob)", icon = "hashtag", min = 1},
                            {type = "input", label = "Nome Grado", default = "grade" .. #v.grades, description = "Nome assegnato al nuovo grado", icon = "signature"},
                            {type = "input", label = "Etichetta Grado", default = "Grado " .. #v.grades, description = "Etichetta visibile del grado", icon = "id-badge"},
                            {type = "number", label = "Stipendio", default = 100, description = "Importo dello stipendio per il grado", icon = "money-bill-wave", min =  0, max = 10000}
                        })
                        if input then
                            table.insert(v.grades, {
                                numgrado = input[1],
                                name = input[2],
                                label = input[3],
                                salary = input[4]
                            })
                            TriggerServerEvent('jobcreator:azioni', 'addgrade', v)
                            GradesMenu()
                        else
                            GradesMenu()
                        end
                    else
                        lib.registerMenu({
                            id = 'grades_actions_menu',
                            title = 'JOB CREATOR - GRADI',
                            position = 'top-right',
                            options = {
                                {label = "Modifica Grado", icon = "edit", iconColor = "#3498DB", description = "Modifica i dettagli del grado, compreso nome e stipendio.", args = {value = "modifica", grade = value}},
                                {label = "Elimina Grado", icon = "trash", iconColor = "#E74C3C", description = "Rimuovi definitivamente il grado selezionato.", args = {value = "elimina", grade = value}}
                            },
                            onClose = function()
                                GradesMenu()
                            end
                        }, function(selectedAction, scrollIndexAction, actionArgs)
                            local gradeValue = actionArgs.grade
                            local selectedValue = actionArgs.value
            
                            if selectedValue == 'modifica' then
                                local gradeData = v.grades[gradeValue]
                                local input = lib.inputDialog("Modifica Grado", {
                                    {type = "number", label = "Numero Grado", default = gradeData.numgrado, description = "Numero identificativo del grado nel /setjob", icon = "hashtag", min = 0},
                                    {type = "input", label = "Nome Grado", default = gradeData.name, description = "Nome del grado assegnato", icon = "signature"},
                                    {type = "input", label = "Label Grado", default = gradeData.label, description = "Etichetta visualizzata per il grado", icon = "id-badge"},
                                    {type = "number", label = "Stipendio", default = gradeData.salary, description = "Importo dello stipendio per il grado", icon = "money-bill-wave", max = 10000}
                                })
                                if input then
                                    v.grades[gradeValue] = {numgrado = input[1], name = input[2], label = input[3], salary = input[4]}
                                    TriggerServerEvent('jobcreator:azioni', 'addgrade', v)
                                else
                                    GradesMenu()
                                end
                            elseif selectedValue == 'elimina' then
                                local alert = lib.alertDialog({
                                    header = 'Elimina Grado',
                                    content = "Sei sicuro di voler eliminare il grado?",
                                    centered = true,
                                    cancel = true
                                })
                                if alert == 'confirm' then
                                    v.grades[gradeValue] = nil
                                    TriggerServerEvent('jobcreator:azioni', 'addgrade', v)
                                    GradesMenu()
                                else
                                    GradesMenu()
                                end
                            end
                        end)
                        lib.showMenu('grades_actions_menu')
                    end
                end)
            
                lib.showMenu('grades_menu')
            end
            GradesMenu()  
            elseif azione == 'delete' then
                local alert = lib.alertDialog({
                    header = 'Elimina Fazione',
                    content = "Sei sicuro di voler eliminare il job?",
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' then
                    TriggerServerEvent('jobcreator:azioni', azione, v)
                else
                    Actions('garage')
                end
            end
        end
    end
end

function OpenGarageMenu(v)
    local options = {}
    
    table.insert(options, {label = 'Crea nuovo garage', icon = 'plus', iconColor = '#2ecc71', description = 'Aggiungi un nuovo garage alla tua fazione', args = 'creagarage'})
    for id, data in pairs(v.garage) do
        table.insert(options, {label = ('Garage #%d - %s'):format(id, data.name), icon = 'car', iconColor = '#2680eb', description = ('Grado minimo: %d | Veicoli: %d'):format(data.mingrade, #data.listaveicoli), args = id})
    end

    lib.registerMenu({
        id = 'menugarage',
        title = 'Gestione Garage',
        description = 'Scegli un garage o creane uno nuovo',
        position = 'top-right',
        options = options,
        onClose = function()
            JobMenu(v.name)
        end
    }, function(selected, scrollIndex, args)
        if args == 'creagarage' then
            local input = lib.inputDialog('Crea Nuovo Garage', {
                {type = 'input', label = 'Nome garage', description = 'Inserisci il nome del garage', default = 'Garage ' .. (#v.garage + 1), icon = 'signature'},
                {type = 'number', label = 'Grado minimo',description = 'Imposta il grado minimo richiesto', default = 0, icon = 'ranking-star'}
            })
            if input then
                table.insert(v.garage, {name = input[1], mingrade = input[2], listaveicoli = {}})
                TriggerServerEvent('jobcreator:azioni', args, v)
                ESX.ShowNotification("Garage creato con successo")
            else
                ESX.ShowNotification("Creazione garage annullata")
            end
            OpenGarageMenu(v)
        else
            OpenGarageActionsMenu(v, args)
        end
    end)
    lib.showMenu('menugarage')
end

function OpenGarageActionsMenu(v, garageId)
    local options = {
        {label = 'Modifica il Garage', icon = 'pen', iconColor = 'blue', description = 'Modifica le impostazioni e i dettagli del garage', args = 'modifica'},
        {label = 'Elimina il Garage', icon = 'trash', iconColor = 'red', description = 'Rimuovi definitivamente il garage selezionato', args = 'elimina'}
    }

    lib.registerMenu({
        id = 'menugarageactions',
        title = 'JOB CREATOR - ' .. v.garage[garageId].name,
        description = "Seleziona l'azione da eseguire sul garage",
        position = 'top-right',
        options = options,
    }, function(selected, scrollIndex, args)
        if args == 'modifica' then
            OpenModifyGarageMenu(v, garageId)
        elseif args == 'elimina' then
            local alert = lib.alertDialog({
                header = 'Elimina Garage',
                content = 'Sei sicuro di voler eliminare il garage?',
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                v.garage[garageId] = nil
                TriggerServerEvent('jobcreator:azioni', 'creagarage', v)
            else
                Actions('garage')
            end
        end
    end)
    lib.showMenu('menugarageactions')
end

function OpenModifyGarageMenu(v, garageId)
    local opt = {
        {label = 'Imposta Punto di Ritiro', description = 'Salva la posizione attuale come punto di ritiro', icon = 'map-pin', iconColor = 'orange', args = 'punto1'},
        {label = 'Imposta Punto di Spawn', description = 'Salva la posizione attuale come punto di spawn veicoli', icon = 'location-dot', iconColor = 'green', args = 'punto2'},
        {label = 'Gestisci Lista Veicoli', description = 'Aggiungi o modifica i veicoli di questo garage', icon = 'car', iconColor = 'blue', args = 'listaveh'}
    }

    lib.registerMenu({
        id = 'modificagarage',
        title = 'Modifica Garage - ' .. v.garage[garageId].name,
        position = 'top-right',
        options = opt
    }, function(selected, scrollIndex, args)
        if args == 'punto1' then
            local coords = GetEntityCoords(cache.ped)
            local alert = lib.alertDialog({
                header = 'Punto di Ritiro',
                content = ("Sei sicuro di voler salvare questo punto?\n\n{ x = %.2f, y = %.2f, z = %.2f }"):format(coords.x, coords.y, coords.z),
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                v.garage[garageId].pos1 = coords
                TriggerServerEvent('jobcreator:azioni', 'punto1', v)
            else
                OpenModifyGarageMenu(v, garageId)
            end
        elseif args == 'punto2' then
            local coords = GetEntityCoords(cache.ped)
            local alert = lib.alertDialog({
                header = 'Punto di Spawn',
                content = ("Salvare questa posizione come spawn veicoli?\n\n{ x = %.2f, y = %.2f, z = %.2f }"):format(coords.x, coords.y, coords.z),
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                v.garage[garageId].pos2 = coords
                v.garage[garageId].heading = GetEntityHeading(cache.ped)
                TriggerServerEvent('jobcreator:azioni', 'punto2', v)
            else
                OpenModifyGarageMenu(v, garageId)
            end
        elseif args == 'listaveh' then
            OpenVehicleListMenu(v, garageId)
        end
    end)

    lib.showMenu('modificagarage')
end

function OpenVehicleListMenu(v, garageId)
    local vehs = {}

    table.insert(vehs, {label = 'Aggiungi Veicolo',description = 'Aggiungi un nuovo veicolo al garage', icon = 'plus', iconColor = 'green', args = 'addveh'})

    for a, b in pairs(v.garage[garageId].listaveicoli) do
        table.insert(vehs, {label = b.label .. ' (' .. a .. ')', description = ('Targa: %s | Grado minimo: %s'):format(b.targa or "N/A", b.mingrade or 0), icon = 'car', iconColor = 'blue', args = a})
    end

    lib.registerMenu({
        id = 'listaveh',
        title = 'Lista Veicoli',
        position = 'top-right',
        options = vehs
    }, function(selected, scrollIndex, args)
        if args == 'addveh' then
            local input = lib.inputDialog('Aggiungi Veicolo', {
                {type = 'input', label = 'Nome modello', default = 'blista', description = 'Nome di spawn del veicolo', icon = 'code'},
                {type = 'input', label = 'Nome visualizzato', default = 'Veicolo', description = 'Etichetta visualizzata nella lista', icon = 'tag'},
                {type = 'input', label = 'Targa', default = 'Targa', description = 'Targa personalizzata del veicolo', icon = 'keyboard'},
                {type = 'number', label = 'Grado minimo', default = 0, description = 'Grado minimo richiesto per l\'utilizzo', icon = 'shield'},
                {type = 'color', label = 'Colore', format = 'rgba', description = 'Colore personalizzato del veicolo', icon = 'palette'},
                {type = 'checkbox', label = 'Fullkit', description = 'Attiva modifiche prestazionali complete', icon = 'cogs'}
            })
            if input then
                table.insert(v.garage[garageId].listaveicoli, {name = input[1], label = input[2], targa = input[3], mingrade = input[4], color = lib.math.torgba(input[5]), fullkit = input[6]})
                TriggerServerEvent('jobcreator:azioni', 'addveh', v)
                OpenVehicleListMenu(v, garageId)
            else
                OpenVehicleListMenu(v, garageId)
            end
        end
    end)
    lib.showMenu('listaveh')
end

CreateThread(function()
    RegisterMarkers()
end)

RegisterNetEvent('registerMarkers', function()
    RegisterMarkers()
end)

local createdBlips = {}

function RegisterMarkers()
    local json = lib.callback.await('jobcreator:getjson')
    
    for _, blip in pairs(createdBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    createdBlips = {} 
    for k, v in pairs(json) do
        for a, b in pairs(v.depositi) do
            TriggerEvent('gridsystem:unregisterMarker', 'deposito'..v.name..a)
        end
        for a, b in pairs(v.bossmenu) do
            TriggerEvent('gridsystem:unregisterMarker', 'bossmenu'..v.name..a)
        end
        for a, b in pairs(v.camerino) do
            TriggerEvent('gridsystem:unregisterMarker', 'camerino'..v.name..a)
        end
        for a, b in pairs(v.garage) do
            TriggerEvent('gridsystem:unregisterMarker', 'pos1'..v.name..a)
            TriggerEvent('gridsystem:unregisterMarker', 'pos2'..v.name..a)
        end
        if v.blips then
            for a, b in pairs(v.blips) do
                local blip = AddBlipForCoord(b.pos.x, b.pos.y, b.pos.z)
                SetBlipSprite(blip, b.id)
                SetBlipDisplay(blip, 2)
                SetBlipColour(blip, b.color)
                SetBlipAsShortRange(blip, true)
                SetBlipScale(blip, tonumber(b.scale))
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(b.name)
                EndTextCommandSetBlipName(blip)
                table.insert(createdBlips, blip)
            end
        end
        if v.depositi then
            for a,b in pairs(v.depositi) do
                TriggerEvent('gridsystem:registerMarker', {
                    name = 'deposito'..v.name..a,
                    pos = vector3(b.pos.x,b.pos.y,b.pos.z),
                    scale = Sime.CreaFazione.Marker.Grandezza or vector3(1.0, 1.0, 1.0),
                    control = 'E',
                    type = -1,        
                    drawDistance = 5,
                    interactDistance = 2,
                    msg = 'DEPOSITO',
                    color = { r = 255, g = 255, b = 255 },
                    permission = v.name,
                    jobGrade = b.mingrade,
                    texture = Sime.CreaFazione.Marker.Deposito,
                    action = function()
                        exports.ox_inventory:openInventory('stash', v.name..a)
                    end,
                })
            end
        end
        if v.bossmenu then
            for a,b in pairs(v.bossmenu) do
                TriggerEvent('gridsystem:registerMarker', {
                    name = 'bossmenu'..v.name..a,
                    pos = vector3(b.pos.x,b.pos.y,b.pos.z),
                    scale = Sime.CreaFazione.Marker.Grandezza or vector3(1.0, 1.0, 1.0),
                    control = 'E',
                    type = -1,        
                    drawDistance = 5,
                    interactDistance = 2,
                    msg = 'BOSSMENU '..a,
                    color = { r = 255, g = 255, b = 255 },
                    permission = v.name,
                    jobGrade = b.mingrade,
                    texture = Sime.CreaFazione.Marker.Bossmenu,
                    action = function()
                        ApriBossMenu(ESX.GetPlayerData().job.name)
                    end
                })
            end
        end
        if v.camerino then
            for a,b in pairs(v.camerino) do
                TriggerEvent('gridsystem:registerMarker', {
                    name = 'camerino'..v.name..a,
                    pos = vector3(b.pos.x,b.pos.y,b.pos.z),
                    scale = Sime.CreaFazione.Marker.Grandezza or vector3(1.0, 1.0, 1.0),
                    control = 'E',
                    type = -1,
                    msg = 'CAMERINO '..a,
                    color = { r = 255, g = 255, b = 255 },
                    permission = v.name,
                    jobGrade = b.mingrade,
                    texture = Sime.CreaFazione.Marker.Camerino,
                    action = function()
                        TriggerScreenblurFadeIn(500)
                        DoScreenFadeOut(500)
                        Wait(700)
                        ApriArmadietto()
                        Wait(1200)
                        DoScreenFadeIn(200)
                        TriggerScreenblurFadeOut(800)
                    end
                })
            end
        end
        if v.garage then
            for a,b in pairs(v.garage) do
                if b.pos1 then
                    TriggerEvent('gridsystem:registerMarker', {
                        name = 'pos1'..v.name..a,
                        pos = vector3(b.pos1.x,b.pos1.y,b.pos1.z),
                        scale = Sime.CreaFazione.Marker.Grandezza or vector3(1.0, 1.0, 1.0),
                        control = 'E',
                        type = -1,    
                        drawDistance = 5,
                        interactDistance = 2,
                        msg = 'GARAGE '..a,
                        color = { r = 255, g = 255, b = 255 },
                        permission = v.name,
                        jobGrade = b.mingrade,
                        texture = Sime.CreaFazione.Marker.Garage,
                        action = function()
                            if IsPedOnFoot(cache.ped) and not IsPedInAnyVehicle(cache.ped) then
                                ApriGarage(v, v.name, v.garage[a])
                            end
                        end
                    })
                end
                if b.pos2 then
                    TriggerEvent('gridsystem:registerMarker', {
                        name = 'pos2'..v.name..a,
                        pos = vector3(b.pos2.x,b.pos2.y,b.pos2.z),
                        scale = Sime.CreaFazione.Marker.Grandezza or vector3(1.0, 1.0, 1.0),
                        control = 'E',
                        type = -1,    
                        drawDistance = 5,
                        interactDistance = 2,
                        msg = 'DEPOSITO VEICOLO',
                        color = { r = 255, g = 255, b = 255 },
                        permission = v.name,
                        jobGrade = b.mingrade,
                        texture = Sime.CreaFazione.Marker.Parcheggio,
                        action = function()
                            if IsPedInAnyVehicle(cache.ped, false) then
                                local vehicle = GetVehiclePedIsIn(cache.ped, false)
                                TaskLeaveVehicle(cache.ped, vehicle, 0)
                                while IsPedInAnyVehicle(cache.ped, false) do
                                    Wait(100)
                                end
                                FreezeEntityPosition(vehicle, true)
                                SetEntityCollision(vehicle, false, false)
                                SetVehicleEngineOn(vehicle, false, false, true)
                                lib.requestNamedPtfxAsset("cut_carsteal5")
                                UseParticleFxAssetNextCall("cut_carsteal5")
                                local smokeEffect = StartParticleFxLoopedOnEntity("veh_exhaust_car", vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, false, false, false)
                                for alpha = 255, 0, -15 do
                                    SetEntityAlpha(vehicle, alpha, false)
                                    Wait(40)
                                end
                                StopParticleFxLooped(smokeEffect, false)
                                ESX.Game.DeleteVehicle(vehicle)

                                ESX.ShowNotification("Hai depositato il veicolo con successo.")
                            else
                                ESX.ShowNotification("Non sei in un veicolo...")
                            end
                        end
                    })
                end
            end
        end
    end
end

local previewVehicle = nil

function ApriGarage(data, job, garage)
    if data.name ~= job then return end

    local function DeletePreview()
        if previewVehicle and DoesEntityExist(previewVehicle) then
            ESX.Game.DeleteVehicle(previewVehicle)
            previewVehicle = nil
        end
    end

    local elements = {}

    for _, dt in pairs(garage.listaveicoli) do
        elements[#elements+1] = {
            title = dt.label,
            icon = "car",
            iconColor = "blue",
            arrow = true,
            description = ("Targa: %s"):format(dt.targa),
            metadata = {
                ("> Potenza: %s"):format(math.floor(GetVehicleModelAcceleration(GetHashKey(dt.name)) * 100)),
                ("> Velocità: %s km/h"):format(math.floor(GetVehicleModelMaxSpeed(GetHashKey(dt.name)) * 3.6)),
                ("> Manovrabilità: %s"):format(math.floor(GetVehicleModelEstimatedAgility(GetHashKey(dt.name)) * 100)),
                ("> Frenata: %s"):format(math.floor(GetVehicleModelMaxBraking(GetHashKey(dt.name)) * 100)),
                ("> Trazione: %s"):format(math.floor(GetVehicleModelMaxTraction(GetHashKey(dt.name)) * 100)),
                ("> Sedili: %s"):format(GetVehicleModelNumberOfSeats(GetHashKey(dt.name)))
            },
            args = {
                model = dt.name,
                colore = dt.color,
                targa = dt.targa,
                grado = dt.mingrade
            },
            onSelect = function(args)
                DeletePreview()
                ESX.Game.SpawnLocalVehicle(args.model, garage.pos2, garage.heading, function(vehicle)
                    SetEntityAlpha(vehicle, 150, false)
                    FreezeEntityPosition(vehicle, true)
                    SetEntityCollision(vehicle, false, false)
                    if args.colore then
                        SetVehicleCustomPrimaryColour(vehicle, args.colore.x, args.colore.y, args.colore.z)
                        SetVehicleCustomSecondaryColour(vehicle, args.colore.x, args.colore.y, args.colore.z)
                    end
                    previewVehicle = vehicle
                end)

                lib.registerContext({
                    id = 'confirm_spawn_garage',
                    title = ("Modello: %s"):format(args.model and args.model:gsub("^%l", string.upper) or "Auto"),
                    menu = 'job_garage_context',
                    options = {
                        {
                            title = 'Conferma Spawn',
                            icon = 'check',
                            iconColor = 'green',
                            onSelect = function()
                                DeletePreview()
                                if ESX.Game.IsSpawnPointClear(garage.pos2, 3.5) then
                                    ESX.Game.SpawnVehicle(args.model, garage.pos2, garage.heading, function(vehicle)
                                        TriggerScreenblurFadeIn(500)
                                        DoScreenFadeOut(500)
                                        Wait(700)
                                        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
                                        if args.targa and args.targa ~= "" then
                                            SetVehicleNumberPlateText(vehicle, args.targa)
                                        end
                                        if args.colore then
                                            SetVehicleCustomPrimaryColour(vehicle, args.colore.x, args.colore.y, args.colore.z)
                                            SetVehicleCustomSecondaryColour(vehicle, args.colore.x, args.colore.y, args.colore.z)
                                        end
                                        Wait(1200)
                                        DoScreenFadeIn(200)
                                        TriggerScreenblurFadeOut(800)
                                    end)
                                else
                                    ESX.ShowNotification("Punto di spawn occupato")
                                end
                            end
                        }
                    },
                    onBack = DeletePreview,
                    onClose = DeletePreview,
                    onExit = DeletePreview
                })
                lib.showContext('confirm_spawn_garage')
            end
        }
    end
    if #elements == 0 then
        elements[1] = {title = "Nessun Veicolo Disponibile", icon = "ban", iconColor = "red", disabled = true}
    end

    lib.registerContext({
        id = 'job_garage_context',
        title = ("Lista Veicoli - %s"):format(ESX.GetPlayerData().job.label),
        options = elements,
        onClose = DeletePreview,
        onBack = DeletePreview,
        onExit = DeletePreview
    })

    lib.showContext('job_garage_context')
end

RegisterNetEvent('DeleteFaz', function(nome)
    DeleteFaz(nome)
end)

function DeleteFaz(nome)
    local json = lib.callback.await('jobcreator:getjson')
    for _, v in pairs(json) do
        if v.depositi then
            for i = 1, #v.depositi do
                TriggerEvent('gridsystem:unregisterMarker', 'deposito'..nome..i)
            end
        end
        if v.bossmenu then
            for i = 1, #v.bossmenu do
                TriggerEvent('gridsystem:unregisterMarker', 'bossmenu'..nome..i)
            end
        end
        if v.camerino then
            for i = 1, #v.camerino do
                TriggerEvent('gridsystem:unregisterMarker', 'camerino'..nome..i)
            end
        end
        if v.garage then
            for i = 1, #v.garage do
                TriggerEvent('gridsystem:unregisterMarker', 'pos1'..nome..i)
                TriggerEvent('gridsystem:unregisterMarker', 'pos2'..nome..i)
            end
        end
    end
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if previewVehicle then
            ESX.Game.DeleteVehicle(previewVehicle)
            previewVehicle = nil
        end
    end
end)