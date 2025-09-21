local JobChangeCooldown = {}

MySQL.ready(function()
    local success, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS ls_multijob (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(60) NOT NULL,
                job VARCHAR(60) NOT NULL,
                grado INT NOT NULL,
                ore_lavorate INT DEFAULT 0,
                UNIQUE KEY unique_job_per_player (identifier, job)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])
    end)
    if success then
        return true
    else
        return false
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60 * 1000)
        for _, playerId in ipairs(ESX.GetPlayers()) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer and xPlayer.job and xPlayer.job.name ~= (Sime.BossMenu.LavoroBase or "unemployed") then
                MySQL.update([[UPDATE ls_multijob  SET ore_lavorate = ore_lavorate + ?  WHERE identifier = ?  AND job = ?]], {1/60, xPlayer.identifier, xPlayer.job.name})
                Citizen.Wait(250)
            end
        end
    end
end)

local function CheckCooldown(source)
    local cooldownTime = 5 * 1000
    local currentTime = GetGameTimer()

    if not JobChangeCooldown[source] then
        JobChangeCooldown[source] = currentTime + cooldownTime
        return true
    end

    if currentTime < JobChangeCooldown[source] then
        return false, math.ceil((JobChangeCooldown[source] - currentTime) / 1000)
    end

    JobChangeCooldown[source] = currentTime + cooldownTime
    return true
end

lib.callback.register('ls_utils:getJobs', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        print('^1[LS_UNIJOB] getJobs: Player not found for source '..source..'^7')
        return nil, 'Player non trovato'
    end

    local result, err = MySQL.query.await([[
        SELECT
            m.job,
            m.grado,
            m.ore_lavorate, -- <-- AGGIUNTO: Seleziona le ore lavorate
            COALESCE(j.label, m.job) AS job_label,
            COALESCE(jg.label, CONCAT('Grado ', m.grado)) AS grade_label,
            COALESCE(jg.salary, 0) AS salary
        FROM ls_multijob m
        JOIN (
            SELECT identifier, job, MAX(id) as max_id
            FROM ls_multijob
            WHERE identifier = ?
            GROUP BY identifier, job
        ) latest_jobs ON m.identifier = latest_jobs.identifier AND m.job = latest_jobs.job AND m.id = latest_jobs.max_id
        LEFT JOIN jobs j ON m.job = j.name
        LEFT JOIN job_grades jg ON m.job = jg.job_name AND m.grado = jg.grade
        WHERE m.identifier = ?
        ORDER BY m.id ASC
    ]], {xPlayer.identifier, xPlayer.identifier})

    if err then
        print('^1[LS_UNIJOB] Error fetching jobs from database for identifier '..xPlayer.identifier..':^7', err)
        return nil, 'Errore database'
    end

    if not result then
         print('^1[LS_UNIJOB] Database query for jobs returned nil for identifier '..xPlayer.identifier..'^7')
         return nil, 'Errore database'
    end

    local jobs = {}
    for _, row in ipairs(result) do
        jobs[#jobs + 1] = {
            name = row.job,
            label = row.job_label or row.job,
            grade = row.grado,
            gradeLabel = row.grade_label or ("Grado " .. tostring(row.grado)),
            salary = row.salary or 0,
            ore_lavorate = row.ore_lavorate or 0
        }
    end
        local currentJob = xPlayer.job
        local foundCurrent = false
        if currentJob and currentJob.name and currentJob.grade ~= nil then
            for _, job in ipairs(jobs) do
                if job.name == currentJob.name and job.grade == currentJob.grade then
                    foundCurrent = true
                    break
                end
            end
            if not foundCurrent and currentJob.name ~= (Sime.BossMenu.LavoroBase or "unemployed") then
                local currentJobHours, errHours = MySQL.scalar.await('SELECT ore_lavorate FROM ls_multijob WHERE identifier = ? AND job = ? ORDER BY id DESC LIMIT 1', {xPlayer.identifier, currentJob.name})
                if errHours then
                    print('^1[LS_UNIJOB] Error fetching hours for current job '..currentJob.name..' for identifier '..xPlayer.identifier..':^7', errHours)
                end

                table.insert(jobs, {name = currentJob.name, label = currentJob.label or currentJob.name, grade = currentJob.grade, gradeLabel = currentJob.grade_label or ("Grado " .. tostring(currentJob.grade)), salary = currentJob.salary or 0, ore_lavorate = currentJobHours or 0})
            end
        end
    return jobs
end)

lib.callback.register('ls_utils:getJobInfo', function(source, jobName)
    local job = ESX.Jobs[jobName]
    if job then
        return {
            label = job.label,
            grades = job.grades
        }
    else
        local jobLabel, errLabel = MySQL.scalar.await('SELECT label FROM jobs WHERE name = ?', {jobName})
        if errLabel then
        end

        if jobLabel then
            local grades, errGrades = MySQL.query.await('SELECT grade, label, salary FROM job_grades WHERE job_name = ? ORDER BY grade ASC', {jobName})
            if errGrades then
            end

            local gradesMap = {}
            for _, grade in ipairs(grades or {}) do
                gradesMap[tostring(grade.grade)] = {
                    label = grade.label,
                    salary = grade.salary
                }
            end
            return {
                label = jobLabel,
                grades = gradesMap
            }
        end
    end
    return nil
end)

RegisterNetEvent('ls_utils:cambiaLavoro', function(newJob, newGrade)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end
--[[ 
    local canChange, remaining = CheckCooldown(source)
    if not canChange then
        TriggerClientEvent('esx:showNotification', source, ('Devi aspettare %s secondi prima di cambiare lavoro di nuovo.'):format(remaining), 'error')
        return false
    end ]]

    local previousJobName = xPlayer.job.name
    local previousJobGrade = xPlayer.job.grade
    local identifier = xPlayer.identifier

    local success, err = pcall(function()
        MySQL.transaction({
            {
                query = 'INSERT INTO ls_multijob (identifier, job, grado) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grado = VALUES(grado)',
                values = {identifier, previousJobName, previousJobGrade}
            },
            {
                query = 'UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?',
                values = {newJob, newGrade, identifier}
            }
        }, function(transactionSuccess)
            if transactionSuccess then
                xPlayer.setJob(newJob, newGrade)
                TriggerClientEvent('esx:setJob', source, {name = xPlayer.job.name, label = xPlayer.job.label, grade = xPlayer.job.grade, grade_name = xPlayer.job.grade_name, grade_label = xPlayer.job.grade_label, salary = xPlayer.job.salary})
                Wait(100)
                 local jobLabel = ESX.Jobs[newJob] and ESX.Jobs[newJob].label or newJob
                 TriggerClientEvent('esx:showNotification', source, ('Il tuo lavoro è stato cambiato a %s (grado %s)'):format(jobLabel, newGrade))

                 if Sime.MultiJob.WebHookAttivi then
                     WebHook(SimeMultiJob.Server.Webhook["CambioLavoro"], "⚡ Cambio Lavoro ⚡", {{name="📌 Giocatore", value=("%s (%s)"):format(xPlayer.getName(), identifier), inline=false}, {name="🏢 Nuovo Lavoro", value=newJob, inline=false}, {name="🔄 Grado Assegnato", value=newGrade, inline=false}, {name="⏰ Orario", value=os.date("%x | %X"), inline=false}})
                 end
            else
                TriggerClientEvent('esx:showNotification', source, 'Errore durante il salvataggio del cambio lavoro nel database. Riprova.', 'error')
            end
        end)
    end)

    if not success then
        local errString = tostring(err)
        if not string.find(errString, 'Duplicate entry') then
            TriggerClientEvent('esx:showNotification', source, 'Errore critico durante il cambio lavoro. Contatta un amministratore.', 'error')
        end
        return false
    end

    return true
end)

RegisterNetEvent('esx:setJob', function(newJob, oldJob)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    local identifier = xPlayer.identifier
    local jobName = newJob.name
    local jobGrade = newJob.grade

    if not jobName or jobGrade == nil then
        return false
    end

    local success, err = pcall(function()
        MySQL.Async.execute('INSERT INTO ls_multijob (identifier, job, grado) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grado = ?',
        {identifier, jobName, jobGrade, jobGrade},
        function(rowsChanged)
        end)
    end)

    if not success then
        local errString = tostring(err)
        if not string.find(errString, 'Duplicate entry') then
        end
        return false
    end

    return true
end)

RegisterNetEvent('ls_utils:server:clientJobUpdated', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end
    local identifier = xPlayer.identifier
    local jobName = xPlayer.job.name
    local jobGrade = xPlayer.job.grade

    if not jobName or jobGrade == nil then
        return false
    end

    local success, err = pcall(function()
        MySQL.Async.execute('INSERT INTO ls_multijob (identifier, job, grado) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grado = VALUES(grado)',
        {identifier, jobName, jobGrade},
        function(rowsChanged)
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM ls_multijob WHERE identifier = ?', {identifier}, function(totalJobs)
                local maxJobs = Sime.MultiJob.Max or 2
                if totalJobs > maxJobs then
                    MySQL.Async.fetchAll('SELECT id FROM ls_multijob WHERE identifier = ? ORDER BY id ASC LIMIT ?', {identifier, totalJobs - maxJobs}, function(oldestJobs)
                        if oldestJobs and #oldestJobs > 0 then
                            local idsToDelete = {}
                            for _, row in ipairs(oldestJobs) do
                                table.insert(idsToDelete, row.id)
                            end
                            local deleteSuccess, deleteErr = pcall(function()
                                 MySQL.Async.execute('DELETE FROM ls_multijob WHERE id IN (?)', {idsToDelete}, function(deletedOldRows)
                                 end)
                            end)
                            if not deleteSuccess then
                                return false
                            end
                        end
                    end)
                end
            end)
        end)
    end)

    if not success then
        local errString = tostring(err)
        if not string.find(errString, 'Duplicate entry') then
        end
        return false
    end

    return true
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if not Sime.MultiJob.Attivo or not xPlayer.job.name or xPlayer.job.grade == nil then
        return false
    end

    local jobName, jobGrade, identifier = xPlayer.job.name, xPlayer.job.grade, xPlayer.identifier

    local success, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO ls_multijob (identifier, job, grado)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE grado = ?
        ]], {identifier, jobName, jobGrade, jobGrade})
    end)

    if not success then
        local errString = tostring(err)
        if not string.find(errString, 'Duplicate entry') then
        end
        return false
    end

    return true
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CreateThread(function()
            Wait(1000)
            MigrateExistingJobs()
        end)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    if not Sime.MultiJob.Attivo or not xPlayer.job or not xPlayer.job.name or xPlayer.job.grade == nil then
        return false
    end

    local jobName = xPlayer.job.name
    local jobGrade = xPlayer.job.grade
    local identifier = xPlayer.identifier

    local success, err = pcall(function()
        MySQL.Async.execute('INSERT INTO ls_multijob (identifier, job, grado) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grado = VALUES(grado)', {identifier, jobName, jobGrade}, function(rowsChanged)
            if rowsChanged > 0 then
                return true
            else
                return false
            end
        end)
    end)

    if not success then
        local errString = tostring(err)
        if not string.find(errString, 'Duplicate entry') then
        end
        return false
    end

    return true
end)

RegisterNetEvent("ls_utils:removeJob")
AddEventHandler("ls_utils:removeJob", function(jobName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if jobName == (Sime.BossMenu.LavoroBase or 'unemployed') then
        xPlayer.showNotification("Non puoi rimuovere il tuo lavoro base.", "error")
        return
    end

    local hasJob, errHasJob = MySQL.scalar.await("SELECT COUNT(*) FROM ls_multijob WHERE identifier = ? AND job = ?", {xPlayer.identifier, jobName})
    if errHasJob then
        xPlayer.showNotification("Errore database durante la rimozione lavoro.", "error")
        return
    end

    if hasJob == 0 then
        xPlayer.showNotification("Non hai questo lavoro salvato.", "error")
        return
    end

    local deleteSuccess, deleteErr = MySQL.query.await("DELETE FROM ls_multijob WHERE identifier = ? AND job = ?", {xPlayer.identifier, jobName})
    if deleteErr then
         xPlayer.showNotification("Errore database durante la rimozione lavoro.", "error")
         return
    end

    if xPlayer.job.name == jobName then
        local nuovoLavoro = Sime.BossMenu.LavoroBase or 'unemployed'
        local nuovoGrado = 0
        xPlayer.setJob(nuovoLavoro, nuovoGrado)
        TriggerClientEvent("esx:showNotification", xPlayer.source, ('Ti sei auto licenziato adesso sei: %s'):format(ESX.Jobs[nuovoLavoro].label or nuovoLavoro))
    else
        TriggerClientEvent("esx:showNotification", xPlayer.source, ('Lavoro %s rimosso dalla tua lista'):format(ESX.Jobs[jobName].label or jobName))
    end
    if Sime.MultiJob.WebHookAttivi then
        WebHook(SimeMultiJob.Server.Webhook["RimozioneLavoro"], "🗑️ Rimozione Lavoro 🗑️", {{name="📌 Giocatore", value=("%s (%s)"):format(xPlayer.getName(), xPlayer.identifier), inline=false}, {name="🏢 Lavoro Rimosso", value=jobName, inline=false}, {name="⏰ Orario", value=os.date("%x | %X"), inline=false}})
    end
end)

RegisterCommand('rimuovilavoro', function(source, args)
    local src = source
    local xPlayer = (src > 0) and ESX.GetPlayerFromId(src) or nil

    if src ~= 0 then
        if not xPlayer or xPlayer.getGroup() ~= 'admin' then
             if src > 0 then TriggerClientEvent("esx:showNotification", src, 'Non hai i permessi per usare questo comando.', 'error') end
             return
        end
    end

    local targetId = tonumber(args[1])
    local jobName = args[2]

    if not targetId or not jobName then
        if src > 0 then
            TriggerClientEvent("esx:showNotification", src, 'Uso: /rimuovilavoro [ID] [lavoro]', 'error')
        end
        return
    end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        local targetIdentifier, errIdentifier = MySQL.scalar.await('SELECT identifier FROM users WHERE id = ?', {targetId})
        if errIdentifier then
             if src > 0 then TriggerClientEvent("esx:showNotification", src, 'Errore database.', 'error') end
             return
        end

        if not targetIdentifier then
             if src > 0 then
                 TriggerClientEvent("esx:showNotification", src, 'ID Giocatore non trovato nel database.', 'error')
             end
             return
        end

        local deleteSuccess, deleteErr = MySQL.query.await('DELETE FROM ls_multijob WHERE identifier = ? AND job = ?', {targetIdentifier, jobName})
         if deleteErr then
             if src > 0 then TriggerClientEvent("esx:showNotification", src, 'Errore database durante la rimozione lavoro.', 'error') end
             return
         end


        if src > 0 then
            TriggerClientEvent("esx:showNotification", src, ('Lavoro %s rimosso da ID %s (offline)'):format(jobName, targetId))
        end

        if Sime.MultiJob.WebHookAttivi then
            WebHook(SimeMultiJob.Server.Webhook["RimozioneLavoro"], "🗑️ Rimozione Lavoro (Admin) 🗑️", {{name="📌 Admin", value=("%s (%s)"):format(src > 0 and xPlayer.getName() or "Console", src > 0 and xPlayer.identifier or "N/A"), inline=false}, {name="🏢 Lavoro Rimosso", value=jobName, inline=false}, {name="👤 Target (Offline)", value=("%s (ID: %s, Identifier: %s)"):format("Offline", targetId, targetIdentifier), inline=false}, {name="⏰ Orario", value=os.date("%x | %X"), inline=false}})
        end

        return
    end

    local targetIdentifier = target.identifier

    local deleteSuccess, deleteErr = MySQL.query.await('DELETE FROM ls_multijob WHERE identifier = ? AND job = ?', {targetIdentifier, jobName})
    if deleteErr then
         if src > 0 then TriggerClientEvent("esx:showNotification", src, 'Errore database durante la rimozione lavoro.', 'error') end
         return
    end


    if target.job.name == jobName then
        local nuovoLavoro = Sime.BossMenu.LavoroBase or 'unemployed'
        local nuovoGrado = 0
        target.setJob(nuovoLavoro, nuovoGrado)
        TriggerClientEvent("esx:showNotification", target.source, ('Il tuo lavoro %s è stato rimosso da un amministratore. Adesso sei: %s'):format(ESX.Jobs[jobName].label or jobName, ESX.Jobs[nuovoLavoro].label or nuovoLavoro), 'error')
    else
         TriggerClientEvent("esx:showNotification", target.source, ('Il tuo lavoro %s è stato rimosso da un amministratore'):format(ESX.Jobs[jobName].label or jobName), 'error')
    end

    if src > 0 then
        TriggerClientEvent("esx:showNotification", src, ('Lavoro %s rimosso da %s'):format(jobName, target.getName()))
    end

    if Sime.MultiJob.WebHookAttivi then
        WebHook(SimeMultiJob.Server.Webhook["RimozioneLavoro"], "🗑️ Rimozione Lavoro (Admin) 🗑️", {{name="📌 Admin", value=("%s (%s)"):format(src > 0 and xPlayer.getName() or "Console", src > 0 and xPlayer.identifier or "N/A"), inline=false}, {name="🏢 Lavoro Rimosso", value=jobName, inline=false}, {name="👤 Target (Online)", value=("%s (ID: %s, Identifier: %s)"):format(target.getName(), targetId, targetIdentifier), inline=false}, {name="⏰ Orario", value=os.date("%x | %X"), inline=false}})
    end
end, true)

function MigrateExistingJobs()
    local results, errResults = MySQL.query.await([[
        SELECT u.identifier, u.job, u.job_grade as grado
        FROM users u
        LEFT JOIN jobs j ON u.job = j.name
        WHERE u.job IS NOT NULL AND u.job != '' AND u.job != 'unemployed'
    ]])

    if errResults then
         return false
    end

    if not results or #results == 0 then
        return false
    end

    local queries = {}
    for _, row in ipairs(results) do
        table.insert(queries, {query = [[INSERT INTO ls_multijob (identifier, job, grado) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grado = VALUES(grado)]], values = {row.identifier, row.job, row.grado}})
    end


    local success, err = MySQL.transaction.await(queries)

    if success then
        return true
    else
        local errString = tostring(err)
        if string.find(errString, 'Duplicate entry') then
             return true
        else
            return false
        end
    end
    return success
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CreateThread(function()
            Wait(1000)
            MigrateExistingJobs()
        end)
    end
end)

local dropQueue    = {}
local processing   = false

AddEventHandler('playerDropped', function(reason)
    local _src    = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    if not xPlayer or not Sime.MultiJob.Attivo or not xPlayer.job or not xPlayer.job.name or xPlayer.job.grade == nil then
        return
    end
    dropQueue[#dropQueue + 1] = {id = xPlayer.identifier, job = xPlayer.job.name, grade = xPlayer.job.grade}
    if not processing then
        processing = true
        processDropQueue()
    end
end)

function processDropQueue()
    if #dropQueue == 0 then
        processing = false
        return
    end
    local entry = table.remove(dropQueue, 1)
    MySQL.Async.execute([[INSERT INTO ls_multijob (identifier, job, grado) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grado = VALUES(grado)]], {entry.id, entry.job, entry.grade}, function(rows)
        Citizen.SetTimeout(100, processDropQueue)
    end)
end