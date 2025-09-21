RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    if ESX.PlayerData then
        ESX.PlayerData.job = {name = job.name, label = job.label, grade = job.grade, grade_name = job.grade_name, grade_label = job.grade_label, salary = job.salary}
    end
end)

local currentEmployees = {}

local function formatMinutes(m)
    if m < 60 then
        return m .. " Minuti"
    elseif m < 1440 then
        local h = math.floor(m / 60)
        local min = m % 60
        return string.format("%d Ore %02d Min", h, min)
    elseif m < 10080 then
        local d = math.floor(m / 1440)
        local remMins = m % 1440
        local h = math.floor(remMins / 60)
        return string.format("%d Giorni %02d Ore", d, h)
    elseif m < 43200 then
        local w = math.floor(m / 10080)
        local remMins = m % 10080
        local d = math.floor(remMins / 1440)
        return string.format("%d Settimane %02d Giorni", w, d)
     elseif m < 525600 then
        local month = math.floor(m / 43200)
        local remMins = m % 43200
        local d = math.floor(remMins / 1440)
        return string.format("%d Mesi %02d Giorni", month, d)
    else
        local y = math.floor(m / 525600)
        local remMins = m % 525600
        local month = math.floor(remMins / 43200)
        return string.format("%d Anni %02d Mesi", y, month)
    end
end

InMenu = function(bool)
    bool = bool == true
    if bool then
        if not DoesEntityExist(tablet) then
            lib.requestModel("prop_cs_tablet")
            tablet = CreateObject(GetHashKey("prop_cs_tablet"), 0, 0, 0, true, true, false)
            AttachEntityToEntity(tablet, cache.ped, GetPedBoneIndex(cache.ped, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            lib.requestAnimDict("amb@world_human_seat_wall_tablet@female@idle_a")
            lib.playAnim(cache.ped, "amb@world_human_seat_wall_tablet@female@idle_a", "idle_a", 1.0, 1.0, -1, 49, 0, false, false, false)
        end
    else
        if DoesEntityExist(tablet) then
            ClearPedTasks(cache.ped)
            DeleteEntity(tablet)
            tablet = nil
        end
    end
end

openBossMenu = function(job)
    local playerData = ESX.GetPlayerData()
    if not playerData or not playerData.job or not playerData.job.grade_name or playerData.job.grade_name ~= "boss" then
        return ESX.ShowNotification(source, "Non sei autorizzato ad accedere al menu boss. Devi essere un boss del tuo lavoro.", "error")
    end
    InMenu(true)
    lib.registerContext({
        id = "boss_main_menu",
        title = "Gestione Azienda",
        options = {
            {title = "Conto Società", description = "Gestisci i fondi aziendali", icon = "money-bill-wave", iconColor = "#28a745",
                onSelect = function()
                    FondiAziendali()
                end
            },
            {title = "Dipendenti", description = "Gestisci i dipendenti", icon = "users", iconColor = "#007bff",
                onSelect = function()
                    GestioneDipendenti()
                end
            },
            {title = "Gestione Gradi", description = "Modifica i gradi aziendali", icon = "sitemap", iconColor = "#ffc107",
                onSelect = function()
                    GestioneGradi()
                end
            },
            {title = "Cassaforte", description = "Accedi al deposito aziendale", icon = "lock", iconColor = "#6f42c1",
                onSelect = function()
                    CassaForte()
                    InMenu(false)
                end
            }
        },
        onExit = function()
            InMenu(false)
        end,
        onClose = function()
            InMenu(false)
        end
    })
    lib.showContext("boss_main_menu")
end

FondiAziendali = function()
    local balance = lib.callback.await("bossmenu:getCompanyBalance", false) or 0
    lib.registerContext({
        id = "account_menu",
        title = ("Menu Aziendale - %s"):format(ESX.GetPlayerData().job.label or ESX.GetPlayerData().job.name),
        menu = "boss_main_menu",
        options = {
            {title = ("Conto Aziendale: $%s"):format(ESX.Math.GroupDigits(balance)), icon = "building-columns", iconColor = "#F1F2F2", disabled = true},
            {title = "Deposita", icon = "money-bill-wave", iconColor = "#28a745",
                onSelect = function()
                    PrelevaDeposita("deposit")
                end
            },
            {title = "Preleva", icon = "hand-holding-usd", iconColor = "#dc3545",
                onSelect = function()
                    PrelevaDeposita("withdraw")
                end
            },
            {title = "Log Transazioni", icon = "list-alt", iconColor = "#007bff",
                onSelect = function()
                    VisualizzaLogTransazioni()
                end
            }
        },
        onExit = function()
            InMenu(false)
        end,
        onClose = function()
            InMenu(false)
        end
    })
    lib.showContext("account_menu")
end

VisualizzaLogTransazioni = function()
    local transactions = lib.callback.await("bossmenu:getAccountTransactions", false)
    local options = {}
    if transactions and #transactions > 0 then
        options[#options+1] = {
            title = 'Elimina tutte le transazioni',
            icon = 'trash',
            iconColor = '#ff0000',
            description = 'Cancella l\'intera cronologia transazioni',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Conferma Eliminazione Massiva',
                    content = 'Sei sicuro di voler cancellare TUTTE le transazioni? Questa azione è irreversibile!',
                    centered = true,
                    labels = { confirm = 'CONFERMA', cancel = 'ANNULLA' }
                })
                
                if confirm == 'confirm' then
                    local success = lib.callback.await('bossmenu:deleteAllTransactions', false)
                    if success then
                        ESX.ShowNotification('Tutte le transazioni eliminate!')
                        VisualizzaLogTransazioni()
                    else
                        ESX.ShowNotification('Eliminazione fallita!', 'error')
                    end
                end
            end
        }

        for _, trans in ipairs(transactions) do
            options[#options+1] = {
                title = ("%s $%s"):format((trans.type == 'deposit' and 'Deposito' or 'Prelievo'), ESX.Math.GroupDigits(trans.amount)),
                icon = (trans.type == 'deposit' and "piggy-bank" or "hand-holding-usd"),
                description = ("Effettuato da: %s - %s"):format(trans.player_name, trans.timestamp),
                metadata = {
                    { label = "ID Transazione", value = trans.id },
                    { label = "Tipo", value = (trans.type == 'deposit' and 'Deposito' or 'Prelievo') },
                    { label = "Importo", value = ("$%s"):format(ESX.Math.GroupDigits(trans.amount)) },
                    { label = "Data e Ora", value = trans.timestamp }
                },
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Conferma Eliminazione',
                        content = ('Sei sicuro di voler eliminare la transazione #%s del %s?'):format(trans.id, trans.timestamp),
                        centered = true,
                        labels = { confirm = 'ELIMINA', cancel = 'ANNULLA' }
                    })

                    if confirm == 'confirm' then
                        local success = lib.callback.await('bossmenu:deleteTransaction', false, trans.id)
                        if success then
                            ESX.ShowNotification('Transazione #'..trans.id..' eliminata!')
                            VisualizzaLogTransazioni()
                        else
                            VisualizzaLogTransazioni()
                            ESX.ShowNotification('Errore eliminazione transazione!', 'error')
                        end
                    end
                end,
                onExit = function()
                    InMenu(false)
                end,
                onClose = function()
                    InMenu(false)
                end
            }
        end
    else
        options[#options+1] = {title = "Nessuna transazione trovata", readOnly = true, icon = "database", description = "Non ci sono transazioni da visualizzare"}
    end

    lib.registerContext({
        id = "account_transactions_log",
        title = "Cronologia Transazioni",
        menu = "account_menu",
        options = options,
        onExit = function()
            InMenu(false)
        end,
        onClose = function()
            InMenu(false)
        end
    })
    lib.showContext("account_transactions_log")
end

PrelevaDeposita = function(action)
    local res = lib.inputDialog(action == "deposit" and "Deposita denaro" or "Preleva denaro", {
        { type = "number", label = "Importo", required = true, min = 1, icon = "dollar-sign", description = ("Saldo Aziendale: $%s | Contanti: $%s"):format(ESX.Math.GroupDigits(lib.callback.await("bossmenu:getCompanyBalance", false) or 0), exports.ox_inventory:Search('count', "money") or 0) }
    })

    if not res then
        return FondiAziendali()
    end
    local ok, msg = lib.callback.await("bossmenu:handleAccount", false, action, tonumber(res[1]))
    if ok then
        ESX.ShowNotification(msg)
    else
        ESX.ShowNotification(msg, "error")
    end
    FondiAziendali()
end

openEmployeeActions = function(employee)
    if not employee then
        ESX.ShowNotification("Errore: Dati dipendente non validi per le azioni.", "error")
        return
    end

    local contextOptions = {
        {title = 'Cambia Grado', icon = 'user-gear',
            onSelect = function()
                local grades = lib.callback.await('bossmenu:getCompanyGrades', false)

                if not grades or #grades == 0 then
                    ESX.ShowNotification('Nessun grado disponibile per questa azienda.')
                    return
                end

                local gradeOptions = {}
                for _, grade in ipairs(grades) do
                    gradeOptions[#gradeOptions + 1] = {value = grade.grade, label = ('%s (Grado: %s)'):format(grade.label, grade.grade)}
                end

                local input = lib.inputDialog('Seleziona nuovo grado', {
                    {
                        type = 'select',
                        label = 'Grado Aziendale',
                        options = gradeOptions,
                        required = true,
                        icon = 'user-shield'
                    }
                })

                if not input then
                    return openEmployeeActions(employee)
                end

                local selectedGrade = tonumber(input[1])
                local gradeData = nil

                for _, g in ipairs(grades) do
                    if g.grade == selectedGrade then
                        gradeData = g
                        break
                    end
                end

                if not gradeData then
                    return ESX.ShowNotification('Grado non valido!', 'error')
                end

                local confirm = lib.alertDialog({
                    header = 'Conferma Cambio Grado',
                    content = ('Sei sicuro di voler impostare **%s** come **%s**?'):format(employee.firstname .. ' ' .. employee.lastname, gradeData.label),
                    centered = true,
                    labels = { confirm = "Conferma", cancel = "Annulla" }
                })

                if confirm == 'confirm' then
                    local success, message = lib.callback.await('bossmenu:updateEmployeeGrade', false, employee.identifier, selectedGrade)
                    if success then
                        ESX.ShowNotification('Grado aggiornato con successo!')
                        GestioneDipendenti()
                    else
                        ESX.ShowNotification(("Errore: %s"):format(message or "Errore sconosciuto"), "error")
                    end
                end
            end
        },
        {title = 'Gestione Bonus', icon = 'hand-holding-dollar',
            onSelect = function()
                local input = lib.inputDialog('Bonus Dipendente', {
                    {type = 'number', label = 'Importo Bonus', icon = 'dollar-sign', required = true, min = 1, max = Sime.BossMenu.MaxBonus or 100000},
                    {type = 'select', label = 'Tipo Bonus',
                        options = {
                            {value = 'cash', label = 'Contanti'},
                            {value = 'bank', label = 'Banca'},
                            {value = 'salary_increase', label = 'Aumento Stipendio'},
                            {value = 'salary_decrease', label = 'Diminuisci Stipendio'}
                        },
                        required = true,
                    }
                })
                if input then
                    local success, message = lib.callback.await('bossmenu:giveBonus', false, employee.identifier, input[1], input[2])
                    if success then
                        ESX.ShowNotification(message, "success")
                        GestioneDipendenti()
                    else
                        ESX.ShowNotification(("Errore: %s"):format(message or "Errore sconosciuto"), "error")
                        GestioneDipendenti()
                    end
                else
                    GestioneDipendenti()
                end
            end,
            onExit = function()
                InMenu(false)
            end,
            onClose = function()
                InMenu(false)
            end
        },
        {
            title = 'Licenzia Dipendente',
            icon = 'user-xmark',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Conferma Licenziamento',
                    content = ('Sei sicuro di voler licenziare %s %s?'):format(employee.firstname or "Sconosciuto", employee.lastname or "Sconosciuto"),
                    centered = true,
                    labels = { confirm = 'Licenzia', cancel = 'Annulla' },
                })
                if confirm == 'confirm' then
                    local success, message = lib.callback.await('bossmenu:fireEmployee', false, employee.identifier)
                    if success then
                        lib.hideContext()
                        GestioneDipendenti()
                    else
                        ESX.ShowNotification(message, "error")
                    end
                end
            end,
            onExit = function()
                InMenu(false)
            end,
            onClose = function()
                InMenu(false)
            end
        }
    }

    lib.registerContext({
        id = 'employee_actions',
        title = ('%s %s'):format(employee.firstname or "Sconosciuto", employee.lastname or "Sconosciuto"),
        menu = 'employees_menu',
        options = contextOptions,
        onExit = function()
            InMenu(false)
        end,
        onClose = function()
            InMenu(false)
        end
    })
    lib.showContext('employee_actions')
end

GestioneDipendenti = function()
    local success, employees = lib.callback.await('bossmenu:getEmployeesWithDetails', false)

    local opts = {}

    opts[#opts+1] = {
        title = 'Assumi Dipendente',
        icon = 'user-plus',
        onSelect = function()
            local input = lib.inputDialog("Assumi Dipendente", { 
                { type = "number", icon = "user-plus", label = "ID Giocatore", required = true, min = 1}
            })
            
            if input then
                local hireSuccess, hireMessage = lib.callback.await('bossmenu:hireEmployee', false, input[1])
                if hireSuccess then
                    ESX.ShowNotification(hireMessage or "Dipendente assunto con successo!", "success")
                    GestioneDipendenti()
                else
                    ESX.ShowNotification(hireMessage or "Errore durante l'assunzione del dipendente.", "error")
                    GestioneGradi()
                end
            else
                GestioneDipendenti()
            end
        end,
        onExit = function()
           InMenu(false)
        end,
        onClose = function()
            InMenu(false)
        end
    }
    if success and type(employees) == 'table' and #employees > 0 then
        for _, employee in ipairs(employees) do
            opts[#opts+1] = {
                title = ('%s %s (%s) - %s'):format(employee.firstname, employee.lastname, employee.grade_label, employee.isOnline and "Online" or "Offline"),
                description = ('Stipendio: $%s | Ore: %s/%s'):format(
                    ESX.Math.GroupDigits(employee.grade_salary), formatMinutes(employee.weekly_hours), formatMinutes(employee.total_hours)),
                icon = employee.isOnline and 'check-circle' or 'times-circle',
                iconColor = employee.isOnline and '#4CAF50' or '#F44336',
                arrow = true,
                onSelect = function()
                    openEmployeeActions(employee)
                end,
                onExit = function()
                    InMenu(false)
                end,
                onClose = function()
                    InMenu(false)
                end
            }
        end
    else
        opts[#opts+1] = {
            title = "Nessun dipendente trovato",
            description = "Inizia assumendo nuovi dipendenti",
            readOnly = true,
            icon = "users-slash"
        }
        if not success then
            ESX.ShowNotification(("Errore nel recupero dei dipendenti: %s"):format(employees or "Errore sconosciuto"), "error")
        end
    end

    lib.registerContext({
        id = 'employees_menu',
        title = 'Gestione Dipendenti',
        menu = 'boss_main_menu',
        options = opts,
        onExit = function()
            InMenu(false)
        end,
        onClose = function()
            InMenu(false)
        end
    })
    lib.showContext('employees_menu')
    InMenu(true)
end

GestioneGradi = function()
    local gradesWithPlayers = lib.callback.await("bossmenu:getCompanyGrades", false)

    if not gradesWithPlayers or #gradesWithPlayers == 0 then
         ESX.ShowNotification("Nessun grado trovato per questo lavoro.")
         return lib.showContext("boss_main_menu")
    end

    local mainGradesOptions = {}

    for _, gradeData in ipairs(gradesWithPlayers) do
        local grade = gradeData
        local players = gradeData.players or {}

        local gradeMetadata = {}
        if #players > 0 then
            for _, player in ipairs(players) do
                table.insert(gradeMetadata, { label = "👤", value = player.name })
            end
        else
            table.insert(gradeMetadata, { label = "Stato", value = "Nessuna persona in citta con questo grado." })
        end

        mainGradesOptions[#mainGradesOptions+1] = {
            title = grade.label,
            description = ("Stipendio: $%s"):format(ESX.Math.GroupDigits(grade.salary)),
            icon = "briefcase",
            arrow = true,
            metadata = gradeMetadata,
            onSelect = function()
                lib.hideContext("grades_menu")
                local input = lib.inputDialog("Modifica Grado: " .. grade.label, {
                    { type = "input", label = "Nome Grado", description = "Inserisci il nome del grado", icon = "briefcase", default = grade.label, required = true },
                    { type = "number", label = "Stipendio", description = "Imposta il nuovo stipendio", icon = "dollar-sign", default = grade.salary, max = 5000, required = true }
                })

                if not input then
                    return GestioneGradi()
                end

                local confirm = lib.alertDialog({
                    header = "Modifica Confermata",
                    content = ("Sei sicuro di voler modificare il grado **%s** (originariamente **%s**) e impostare lo stipendio a **%d$**?"):format(input[1], grade.label, input[2]),
                    centered = true,
                    labels = { cancel = "No", confirm = "Si" }
                })
                if confirm then
                    TriggerServerEvent("bossmenu:updateGrade", grade.grade, input[1], input[2])
                    GestioneGradi()
                else
                    GestioneGradi()
                end
            end,
            onExit = function()
                InMenu(false)
            end,
            onClose = function()
                InMenu(false)
            end
        }
    end

    lib.registerContext({
        id = "grades_menu",
        title = "Gestione Gradi",
        menu = "boss_main_menu",
        options = mainGradesOptions,
    })

    lib.showContext("grades_menu")
end

CassaForte = function()
    if not ESX.PlayerData.job or ESX.PlayerData.job.name == Sime.BossMenu.LavoroBase or 'unemployed' then
        return ESX.ShowNotification("Non hai un lavoro valido.")
    end

    ESX.ShowNotification("Accesso in corso...")
    local result = lib.callback.await('bossmenu:ensureJobStash', false)

    if result.success then
        exports.ox_inventory:openInventory('stash', { id = result.stashId })
    else
        ESX.ShowNotification(result.message or "Accesso negato.")
    end
end

RegisterNetEvent('bossmenu:requestHireConfirmation', function(bossName, jobLabel)
    local response = lib.alertDialog({
        header = "Offerta di Lavoro",
        content = ('%s ti vuole assumere come %s\nVuoi accettare?'):format(bossName, jobLabel),
        centered = true,
        cancel = true,
        labels = { confirm = 'Accetta',  cancel = 'Rifiuta' }
    })
    if response == "confirm" then
        local success = lib.progressCircle({
            duration = 3500,
            label = "Firmando il contratto...",
            useWhileDead = false,
            canCancel = true,
            disable = { move = false, car = true, combat = false },
            anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' }
        })
        TriggerServerEvent('bossmenu:hireConfirmationResponse', success)
    else
        TriggerServerEvent('bossmenu:hireConfirmationResponse', false)
    end
end)

RegisterNetEvent("ls_unijob:openBossMenu")
AddEventHandler("ls_unijob:openBossMenu", function(job)
    if ESX.GetPlayerData().job.grade_name == "boss" then
        openBossMenu(job)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if lib.getOpenContextMenu() then
        lib.hideContext(onExit)
    end
    lib.closeAlertDialog()
    lib.closeInputDialog()
    InMenu(false)
end)