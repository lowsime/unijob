MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ls_bossmenu` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `job_name` VARCHAR(60) NOT NULL,
            `total_hours` INT(11) NOT NULL DEFAULT 0,
            `weekly_hours` INT(11) NOT NULL DEFAULT 0,
            `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_identifier_job` (`identifier`, `job_name`),
            INDEX `identifier_index` (`identifier`),
            INDEX `job_name_index` (`job_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ls_bossmenu_transactions` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `job_name` VARCHAR(60) NOT NULL COLLATE 'utf8mb4_unicode_ci',
            `type` ENUM('deposit','withdraw') NOT NULL COLLATE 'utf8mb4_unicode_ci',
            `amount` INT(11) NOT NULL DEFAULT '0',
            `player_identifier` VARCHAR(60) NOT NULL COLLATE 'utf8mb4_unicode_ci',
            `player_name` VARCHAR(255) NOT NULL COLLATE 'utf8mb4_unicode_ci',
            `description` TEXT NULL COLLATE 'utf8mb4_unicode_ci',
            `status` ENUM('pending', 'completed', 'failed') NOT NULL DEFAULT 'completed' COLLATE 'utf8mb4_unicode_ci',
            `timestamp` TIMESTAMP NOT NULL DEFAULT current_timestamp(),
            `deleted_by` VARCHAR(60) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
            `deleted_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`) USING BTREE,
            INDEX `job_name_index` (`job_name`) USING BTREE,
            INDEX `player_identifier_index` (`player_identifier`) USING BTREE
        ) ENGINE=InnoDB COLLATE='utf8mb4_unicode_ci';
    ]])
end)

local function isPlayerAuthorizedBoss(xPlayer)
    return xPlayer and xPlayer.job and xPlayer.job.grade_name == "boss"
end

updateBossMenu = function()
    local onlinePlayersData = {}

    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job and xPlayer.job.name ~= (Sime.BossMenu.LavoroBase or 'unemployed') then
             table.insert(onlinePlayersData, { identifier = xPlayer.identifier, jobName = xPlayer.job.name })
        end
    end

    if #onlinePlayersData > 0 then
        for _, playerData in ipairs(onlinePlayersData) do
             MySQL.query.await([[
                 INSERT INTO ls_bossmenu (identifier, job_name, total_hours, weekly_hours)
                 VALUES (?, ?, 0, 0)
                 ON DUPLICATE KEY UPDATE
                    total_hours = total_hours + TIMESTAMPDIFF(MINUTE, last_updated, CURRENT_TIMESTAMP),
                    weekly_hours = weekly_hours + TIMESTAMPDIFF(MINUTE, last_updated, CURRENT_TIMESTAMP);
             ]], {playerData.identifier, playerData.jobName})
        end
    end
    SetTimeout(60000 * 10, updateBossMenu)
end

updateBossMenu()

AddEventHandler('cron:runAt', function(hour, minute)
    if hour == 0 and minute == 0 then
        MySQL.update.await(('UPDATE ls_bossmenu SET weekly_hours = 0 WHERE job_name != "%s"'):format(Sime.BossMenu.LavoroBase or "unemployed"))
    end
end)

lib.callback.register("bossmenu:getCompanyBalance", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not xPlayer.job or not xPlayer.job.name then
        return 0
    end
    local result = MySQL.query.await("SELECT * FROM addon_account_data WHERE account_name = ?", { "society_" .. xPlayer.job.name })
    return result[1] and result[1].money or 0
end)

lib.callback.register('bossmenu:getEmployees', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.job or not xPlayer.job.name then
        return {}
    end
    local query = [[
        SELECT u.identifier, u.firstname, u.lastname, u.job, u.job_grade,' jg.label AS grade_label, jg.salary AS grade_salary, bm.total_hours, bm.weekly_hours
        FROM users u
        LEFT JOIN job_grades jg ON u.job_grade = jg.grade AND u.job COLLATE utf8mb4_unicode_ci = jg.job_name COLLATE utf8mb4_unicode_ci
        LEFT JOIN ls_bossmenu bm ON u.identifier COLLATE utf8mb4_unicode_ci = bm.identifier AND u.job COLLATE utf8mb4_unicode_ci = bm.job_name
        WHERE u.job COLLATE utf8mb4_unicode_ci = ?
    ]]
    local employees = MySQL.query.await(query, {xPlayer.job.name})

    if not employees then
        return {}
    end
    return employees
end)

lib.callback.register('bossmenu:getEmployeesWithDetails', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.job or not xPlayer.job.name then
        return false, "Informazioni sul giocatore o sul lavoro non disponibili."
    end
    if not isPlayerAuthorizedBoss(xPlayer) then
        return false, "Non sei autorizzato a visualizzare i dipendenti."
    end

    local jobName = xPlayer.job.name
    local users = MySQL.query.await("SELECT identifier, firstname, lastname, job_grade, job FROM users WHERE job = ?", { jobName })
    if not users then
        return false, "Nessun utente trovato per questo lavoro."
    end
    local jobGrades = MySQL.query.await("SELECT grade, label, salary FROM job_grades WHERE job_name = ?", { jobName })
    local jobGradesMap = {}
    if jobGrades then
        for _, gradeInfo in ipairs(jobGrades) do
            jobGradesMap[tostring(gradeInfo.grade)] = gradeInfo
        end
    end
    local bossMenuEntries = MySQL.query.await("SELECT identifier, total_hours, weekly_hours FROM ls_bossmenu WHERE job_name = ?", { jobName })
    local bossMenuMap = {}
    if bossMenuEntries then
        for _, entry in ipairs(bossMenuEntries) do
            bossMenuMap[tostring(entry.identifier)] = entry
        end
    end

    local employeesWithDetails = {}
    for _, user in ipairs(users) do
        local employeeData = {
            identifier = user.identifier,
            firstname = user.firstname,
            lastname = user.lastname,
            job = user.job,
            job_grade = user.job_grade,
            grade_label = "Sconosciuto",
            grade_salary = 0,
            total_hours = 0,
            weekly_hours = 0
        }
        local employeePlayer = ESX.GetPlayerFromIdentifier(user.identifier)
        employeeData.isOnline = (employeePlayer ~= nil)

        if user.job_grade ~= nil then
            local gradeInfo = jobGradesMap[tostring(user.job_grade)]
            if gradeInfo then
                employeeData.grade_label = gradeInfo.label or "Sconosciuto"
                employeeData.grade_salary = gradeInfo.salary or 0
            end
        end

        if user.identifier ~= nil then
            local hoursInfo = bossMenuMap[tostring(user.identifier)]
            if hoursInfo then
                employeeData.total_hours = hoursInfo.total_hours or 0
                employeeData.weekly_hours = hoursInfo.weekly_hours or 0
            end
        end
        table.insert(employeesWithDetails, employeeData)
    end
    return true, employeesWithDetails
end)

lib.callback.register("bossmenu:getCompanyGrades", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.job or not xPlayer.job.name then return {} end

    local jobName = xPlayer.job.name
    local grades = MySQL.query.await("SELECT * FROM job_grades WHERE job_name = ? ORDER BY grade ASC", { jobName })
    if not grades then return {} end
    local playersAtGrade = {}
    for _, grade in ipairs(grades) do
        playersAtGrade[grade.grade] = {}
    end
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local targetPlayer = ESX.GetPlayerFromId(playerId)
        if targetPlayer and targetPlayer.job and targetPlayer.job.name == jobName then
            if playersAtGrade[targetPlayer.job.grade] then
                table.insert(playersAtGrade[targetPlayer.job.grade], {
                    name = targetPlayer.getName(),
                    source = playerId
                })
            end
        end
    end
    local gradesWithPlayers = {}
    for _, grade in ipairs(grades) do
        grade.players = playersAtGrade[grade.grade] or {}
        table.insert(gradesWithPlayers, grade)
    end

    return gradesWithPlayers
end)

lib.callback.register('bossmenu:deleteTransaction', function(source, transactionId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then return false end

    local exists = MySQL.scalar.await('SELECT 1 FROM ls_bossmenu_transactions WHERE id = ? AND job_name = ?', {transactionId, xPlayer.job.name})

    if not exists then
        return false
    end

    MySQL.query.await('START TRANSACTION')
    local success = MySQL.update.await(
        'DELETE FROM ls_bossmenu_transactions WHERE id = ? AND job_name = ?', 
        {transactionId, xPlayer.job.name}
    ) > 0

    if Sime.BossMenu.WebHookAttivi then
        WebHook(SimeBossMenu.Server.WebHook["EliminaTransazione"], "🔥 ELIMINAZIONE DI TRANSAZIONI 🔥", {{name="📌 Responsabile",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🏢 Azienda",value=xPlayer.job.label,inline=false},{name="🗑️ Transazioni Eliminate",value=count,inline=false},{name="⏰ Orario",value=os.date("%x | %X"),inline=false}})
    end

    MySQL.query.await('COMMIT')
    return success
end)

lib.callback.register('bossmenu:deleteAllTransactions', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then return false end

    if MySQL.scalar.await('SELECT COUNT(id) FROM ls_bossmenu_transactions WHERE job_name = ?', {xPlayer.job.name}) == 0 then
        return false
    end
    MySQL.query.await('START TRANSACTION')
    local success = MySQL.update.await('DELETE FROM ls_bossmenu_transactions WHERE job_name = ?', {xPlayer.job.name}) > 0
    if Sime.BossMenu.WebHookAttivi then
        WebHook(SimeBossMenu.Server.WebHook["TogliTutteLeTransazioni"], "🗑️ **ELIMINAZIONE MASSA TRANSAZIONI** 🗑️", {{name="👤 Responsabile",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🏢 Azienda",value=xPlayer.job.label,inline=false},{name="📦 Transazioni Eliminate",value=count,inline=false},{name="⏰ Orario",value=os.date("%x | %X"),inline=false}})
    end
    MySQL.query.await('COMMIT')
    return success
end)

lib.callback.register("bossmenu:handleAccount", function(source, action, amount)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then 
        return false, "Non sei autorizzato ad eseguire questa azione."
    end

    local account = "society_" .. xPlayer.job.name
    local nuovoSaldoAziendale

    amount = math.floor(tonumber(amount) or 0)
    local maxLimit = Sime.BossMenu.MaxPrelievo or 1000000
    if amount < 1 then
        return false, "L'importo deve essere almeno 1."
    elseif amount > maxLimit then
        return false, ("Importo non valido (Massimo: $%s)"):format(ESX.Math.GroupDigits(maxLimit))
    end

    MySQL.query.await('START TRANSACTION')

    local balance = MySQL.scalar.await("SELECT money FROM addon_account_data WHERE account_name = ? FOR UPDATE", {account})

    if balance == nil then
        MySQL.query.await('ROLLBACK')
        return false, "Conto societario non trovato. Assicurati che l'account della società sia configurato nel DB."
    end

    if action == "deposit" then
        if xPlayer.getMoney() < amount then
            MySQL.query.await('ROLLBACK')
            return false, "Fondi personali insufficienti."
        end
    elseif action == "withdraw" then
        if amount > balance then
            MySQL.query.await('ROLLBACK')
            return false, ("Fondi insufficienti! Saldo: $%s"):format(ESX.Math.GroupDigits(balance))
        end
        if amount > (balance * 0.8) then
            MySQL.query.await('ROLLBACK')
            return false, "Limite prelievo: puoi prelevare al massimo l'80% del saldo aziendale."
        end
    else
        MySQL.query.await('ROLLBACK')
        return false, "Azione sconosciuta."
    end

    local queryOperator = action == "deposit" and "+" or "-"
    local updateResult = MySQL.update.await(
        "UPDATE addon_account_data SET money = money " .. queryOperator .. " ? WHERE account_name = ?", 
        {amount, account}
    )

    if not updateResult or updateResult == 0 then
        MySQL.query.await('ROLLBACK')
        return false, "Errore durante l'aggiornamento del saldo aziendale nel database."
    end

    if action == "deposit" then
        xPlayer.removeMoney(amount)
    else
        xPlayer.addMoney(amount)
    end
    MySQL.insert.await("INSERT INTO ls_bossmenu_transactions (job_name, type, amount, player_identifier, player_name) VALUES (?, ?, ?, ?, ?)", {xPlayer.job.name, action, amount, xPlayer.identifier, xPlayer.getName()})
    MySQL.query.await('COMMIT')

    nuovoSaldoAziendale = MySQL.scalar.await("SELECT money FROM addon_account_data WHERE account_name = ?", {account}) or 0

    if Sime.BossMenu.WebHookAttivi then
        WebHook(SimeBossMenu.Server.WebHook["PrelievoDeposito"], "💰 Gestione Fondi Aziendali 💰", {{name="⚡ Azione",value=action:upper(),inline=false},{name="👤 Responsabile",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🏢 Azienda",value=xPlayer.job.label,inline=false},{name="💵 Importo",value=("$%s"):format(ESX.Math.GroupDigits(amount)),inline=false},{name="📊 Nuovo Saldo",value=("$%s"):format(ESX.Math.GroupDigits(nuovoSaldoAziendale)),inline=false},{name="⏰ Orario",value=os.date("%x | %X"),inline=false}})
    end

    return true, ("Nuovo saldo Aziendale: $%s"):format(ESX.Math.GroupDigits(nuovoSaldoAziendale))
end)

lib.callback.register("bossmenu:getCompanyBalance", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then return false end

    local account = "society_" .. xPlayer.job.name
    local balance = MySQL.scalar.await("SELECT money FROM addon_account_data WHERE account_name = ?", { account }) or 0
    return balance
end)

lib.callback.register("bossmenu:getAccountTransactions", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    return MySQL.query.await([[
        SELECT 
            id,
            job_name, 
            type, 
            amount, 
            player_identifier, 
            player_name, 
            DATE_FORMAT(timestamp, '%d/%m/%Y %H:%i') AS timestamp 
        FROM ls_bossmenu_transactions 
        WHERE job_name = ? 
        ORDER BY timestamp DESC
    ]], {xPlayer.job.name})
end)

lib.callback.register('bossmenu:updateEmployeeGrade', function(source, xTargetIdentifier, nuovogrado)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then return false end

    local target = ESX.GetPlayerFromIdentifier(xTargetIdentifier)

    if not target then
        return false, "Il dipendente con quell'ID non è stato trovato online."
    elseif target.job.name ~= xPlayer.job.name then
        return false, "Non puoi cambiare il grado a dipendenti di un'altra azienda."
    elseif not jobGrades or #jobGrades == 0 then
        return false, "Nessun grado disponibile per questa azienda."
    elseif target.identifier == xPlayer.identifier then
        return false, "Non puoi modificare il tuo stesso grado!"
    else
        local gradeExists = false
        for _, gradeData in ipairs(jobGrades) do
            if gradeData.grade == nuovogrado then
                gradeExists = true
                break
            end
        end
        
        if not gradeExists then
            return false, "Il grado selezionato non è valido per questa azienda."
        end
    end

    local gradeLabelResult = MySQL.query.await("SELECT label FROM job_grades WHERE job_name = ? AND grade = ?", { target.job.name, nuovogrado })
    local gradeLabel = gradeLabelResult[1] and gradeLabelResult[1].label or "Grado sconosciuto"
    target.setJob(target.job.name, nuovogrado)
    TriggerClientEvent('esx:showNotification', source, ('Hai impostato il grado di %s %s a %s.'):format(target.get('firstName'), target.get('lastName'), gradeLabel))
    TriggerClientEvent('esx:showNotification', target.source, ('Il tuo grado in %s è stato cambiato a %s da %s.'):format(target.job.label, gradeLabel, xPlayer.getName()))
    if Sime.BossMenu.WebHookAttivi then
        WebHook(SimeBossMenu.Server.WebHook["CambiaGrado"], "🔄 CAMBIO GRADO DIPENDENTE 🔄", {{name="👤 Responsabile",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🆙 Dipendente",value=("%s (%s)"):format(target.getName(),target.identifier),inline=false},{name="🏷️ Nuovo Grado",value=("%s (%s)"):format(gradeLabel,nuovogrado),inline=false},{name="🏢 Azienda",value=xPlayer.job.label,inline=false},{name="⏰ Orario Cambio Grado (Server)",value=os.date("%x | %X %p"),inline=false}})
    end
    return true
end)

local pendingHires = {}

lib.callback.register('bossmenu:hireEmployee', function(source, targetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then return false end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        return false, "Giocatore non trovato in città"
    end
    
    if xPlayer.identifier == target.identifier then
        return false, "Non puoi assumere te stesso"
    end

     if target.job.name == xPlayer.job.name then
        return false, "Il giocatore è già un dipendente"
    end

    TriggerClientEvent('bossmenu:requestHireConfirmation', target.source, xPlayer.getName(), xPlayer.job.label)

    local startTime = GetGameTimer()
    local timeout = 30000
    
    while GetGameTimer() - startTime < timeout do
        if pendingHires[target.source] ~= nil then
            break
        end
        Citizen.Wait(100)
    end

    local confirmed = pendingHires[target.source] or false
    pendingHires[target.source] = nil

    if not confirmed then
        TriggerClientEvent('esx:showNotification', source, 'Operazione annullata o scaduta', 'error')
        return false, "Conferma fallita"
    end

    if not confirmed then
        TriggerClientEvent('esx:showNotification', source, 'Offerta rifiutata dal dipendente', 'error')
        return false, "Offerta rifiutata"
    end

    local jobGrades = MySQL.query.await('SELECT * FROM job_grades WHERE job_name = ? ORDER BY grade ASC', {xPlayer.job.name})
    if not jobGrades or #jobGrades == 0 then
        return false, "Nessun grado disponibile"
    end

    local lowestGrade = jobGrades[1].grade
    local gradeLabel = jobGrades[1].label

    target.setJob(xPlayer.job.name, lowestGrade)

    TriggerClientEvent('esx:showNotification', source, ('Hai assunto %s come %s'):format(target.getName(), gradeLabel))
    TriggerClientEvent('esx:showNotification', target.source, ('Sei stato assunto come %s'):format(gradeLabel))

    target.setJob(xPlayer.job.name, lowestGrade)
    if Sime.BossMenu.WebHookAttivi then
        WebHook(SimeBossMenu.Server.WebHook["Assunzione"], "🎉 NUOVA ASSUNZIONE 🎉", {{name="👤 Manager",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🆕 Dipendente",value=("%s (%s)"):format(target.getName(),target.identifier),inline=false},{name="🏷️ Ruolo",value=("%s (Grado %s)"):format(gradeLabel,lowestGrade),inline=false},{name="📅 Data",value=os.date("%d/%m/%Y %H:%M"),inline=false}})
    end
    return true, "Assunzione completata"
end)

RegisterNetEvent('bossmenu:hireConfirmationResponse', function(response)
    pendingHires[source] = response
end)

lib.callback.register('bossmenu:fireEmployee', function(source, xTarget)
    local xPlayer = ESX.GetPlayerFromId(source)
    local target = ESX.GetPlayerFromIdentifier(xTarget)

    if xTarget == xPlayer.identifier then
        return false, "Non puoi licenziare te stesso!"
    end
    if not target then
        return false, "Il dipendente con quell'ID non è stato trovato."
    end

    if target.job.name ~= xPlayer.job.name then
        return false, "Non puoi licenziare dipendenti di un'altra azienda."
    end

    target.setJob(Sime.BossMenu.LavoroBase or 'unemployed', 0)
    TriggerClientEvent('esx:showNotification', source, ('Hai licenziato %s %s.'):format(target.get('firstName'), target.get('lastName')))
    TriggerClientEvent('esx:showNotification', target.source, ('Sei stato licenziato da %s.'):format(xPlayer.job.label), 'error')
    if Sime.BossMenu.WebHookAttivi then
        WebHook(SimeBossMenu.Server.WebHook["Licenziamento"], "⚠️ LICENZIAMENTO DIPENDENTE ⚠️", {{name="👤 Responsabile",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🚪 Dipendente Licenziato",value=("%s (%s)"):format(target.getName(),target.identifier),inline=false},{name="🏢 Azienda",value=xPlayer.job.label,inline=false},{name="⏰ Orario Licenziamento (Server)",value=os.date("%x | %X %p"),inline=false}})
    end
    return true
end)

lib.callback.register('bossmenu:getPlayerNameAndGrade', function(source, targetId)
    local target = ESX.GetPlayerFromId(targetId)
    if target and target.job then
        local jobGrades = MySQL.query.await('SELECT * FROM job_grades WHERE job_name = ?', {xPlayer.job.name})
        if jobGrades then
            for _, gradeData in ipairs(jobGrades) do
                if gradeData.name == target.job.grade then
                    return {firstname = target.get('firstName'), lastname = target.get('lastName'), grade_label = gradeData.label, grade_salary = gradeData.salary}
                end
            end
        end
    end
    return nil
end)

RegisterNetEvent("bossmenu:updateGrade", function(gradeId, newLabel, newSalary)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then return false end

    local jobName = xPlayer.job.name
    local result = MySQL.update.await("UPDATE job_grades SET label = ?, salary = ? WHERE job_name = ? AND grade = ?", { newLabel, newSalary, jobName, gradeId })
    
    if result and result > 0 then
        if Sime.BossMenu.WebHookAttivi then
            WebHook(SimeBossMenu.Server.WebHook["Promozione"], "🆙 AGGIORNAMENTO GRADO LAVORATIVO 🆙", {{name="👤 Azione Eseguita Da",value=("%s (%s)"):format(xPlayer.getName(),xPlayer.identifier),inline=false},{name="🏢 Lavoro",value=jobName,inline=false},{name="🔼 Grado Aggiornato (ID)",value=gradeId,inline=false},{name="🏷️ Nuova Etichetta Grado",value=newLabel,inline=false},{name="💰 Nuovo Stipendio",value=("$%s"):format(ESX.Math.GroupDigits(newSalary)),inline=false},{name="⏰ Orario Aggiornamento (Server)",value=os.date("%x | %X %p"),inline=false}})
        end
    else
        TriggerClientEvent("esx:showNotification", src, "Errore durante l'aggiornamento del grado o grado non trovato.", "error")
    end
end)

lib.callback.register('bossmenu:giveBonus', function(source, targetIdentifier, amount, bonusType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or not isPlayerAuthorizedBoss(xPlayer) then
        return false, "Non sei autorizzato ad eseguire questa azione."
    end

    local target = ESX.GetPlayerFromIdentifier(targetIdentifier)
    if not target then
        return false, "Il dipendente con quell'ID non è presente nella città."
    end

    if target.job.name ~= xPlayer.job.name then
        return false, "Non puoi erogare bonus a dipendenti di un'altra azienda."
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, "Importo del bonus non valido."
    end

    if bonusType == 'salary_increase' or bonusType == 'salary_decrease' then
        local finalAmount = amount * (bonusType == 'salary_decrease' and -1 or 1)

        local currentSalary = MySQL.scalar.await('SELECT salary FROM job_grades WHERE job_name = ? AND grade = ?', {target.job.name, target.job.grade})

        if not currentSalary then
            return false, "Errore nel recupero dello stipendio attuale."
        end

        if currentSalary + finalAmount < 0 then
            return false, "Lo stipendio non può essere inferiore a 0."
        end

        local updateResult = MySQL.update.await('UPDATE job_grades SET salary = salary + ? WHERE job_name = ? AND grade = ?', {
            finalAmount, target.job.name, target.job.grade
        })

        if not updateResult or updateResult == 0 then
            return false, ('Errore durante l\'aggiornamento dello stipendio per il grado %s.'):format(target.job.grade_label)
        end
        
        TriggerClientEvent('esx:showNotification', src, ('Stipendio del dipendente %s aggiornato con successo!'):format(target.getName()))
        return true, ('Stipendio di %s modificato con successo per %s!'):format(ESX.Math.GroupDigits(amount), target.getName())

    else
        local accountName = 'society_' .. xPlayer.job.name
        local societyAccount = MySQL.scalar.await("SELECT money FROM addon_account_data WHERE account_name = ?", {accountName})
        local bonusGivenAsCashFallback = false
        if societyAccount == nil then
            bonusGivenAsCashFallback = true
            target.addMoney(amount)         
        else
            if societyAccount < amount then
                return false, "Fondi aziendali insufficienti per erogare il bonus."
            end

            local updateResult = MySQL.update.await('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {amount, accountName})
            if not updateResult or updateResult == 0 then
                return false, "Errore durante il prelievo dei fondi aziendali."
            end

            if bonusType == 'cash' then
                target.addMoney(amount)
            elseif bonusType == 'bank' then
                target.addAccountMoney('bank', amount)
            else
                MySQL.update.await('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {amount, accountName})
                return false, "Tipo di bonus non valido."
            end
        end

        TriggerClientEvent('esx:showNotification', src, ('Bonus di $%s erogato con successo a %s!'):format(ESX.Math.GroupDigits(amount), target.getName()))
        TriggerClientEvent('esx:showNotification', target.source, ('Hai ricevuto un bonus di $%s da %s!'):format(ESX.Math.GroupDigits(amount), xPlayer.getName()))

        if Sime.BossMenu.WebHookAttivi then
            WebHook(SimeBossMenu.Server.WebHook["Bonus"], "🎉 EROGAZIONE BONUS 🎉", {{name="💼 Responsabile Bonus", value=("%s (%s)"):format(xPlayer.getName(), xPlayer.identifier), inline=false}, {name="🏢 Azienda", value=xPlayer.job.label, inline=false}, {name="🎯 Destinatario", value=("%s (%s)"):format(target.getName(), targetIdentifier), inline=false}, {name="💰 Tipo di Bonus", value=bonusGivenAsCashFallback and "Contanti (Fallback)" or bonusType, inline=false}, {name="💵 Importo", value=("$%s"):format(ESX.Math.GroupDigits(amount)), inline=false}, {name="⏰ Orario Erogazione (Server)", value=os.date("%x | %X %p"), inline=false}})
        end

        return true, "Bonus erogato con successo."
    end
end)

lib.callback.register('bossmenu:ensureJobStash', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { success = false, message = "Giocatore non trovato." } end
    
    if not isPlayerAuthorizedBoss(xPlayer) then
        return { success = false, message = "Non autorizzato." }
    end

    local stashId = ("boss_safe_%s"):format(xPlayer.job.name)

    if GetResourceState("ox_inventory") == "started" then
        local ok, err = pcall(function()
            exports.ox_inventory:RegisterStash(stashId, ("Cassa Forte Aziendale: %s"):format(xPlayer.job.label), Sime.BossMenu.SlotDeposito or 50, Sime.BossMenu.PesoDeposito or 250000, nil)
        end)

        if not ok then
            return false, err
        end
        return true
    else
        return false, "La risorsa ox_inventory non è avviata!"
    end

    if not ok then
        return { success = false, message = "Errore nel registrare la cassaforte: " .. tostring(err) }
    end

    return { success = true, stashId = stashId }
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        MySQL.update.await("UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?", { xPlayer.job.name, xPlayer.job.grade, xPlayer.identifier })
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            MySQL.update.await("UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?", { xPlayer.job.name, xPlayer.job.grade, xPlayer.identifier })
        end
    end
end)