lib.callback.register("ls_utils:server:createjob", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
TriggerClientEvent("creajob", source)
    return false
end)

local json = require("json")

lib.callback.register("jobcreator:getjobs", function(source)
    return MySQL.Sync.fetchAll("SELECT j.*, COUNT(jg.grade) AS num_grades " .. "FROM jobs j " .. "LEFT JOIN job_grades jg ON j.name = jg.job_name " .. "GROUP BY j.name")
end)

lib.callback.register('jobcreator:checkJob', function(source, jobName)
    local result = MySQL.query.await('SELECT * FROM jobs WHERE name = ?', {jobName})
    return result[1] or false
end)

lib.callback.register("jobcreator:getjson", function(source)
    return json.decode(LoadResourceFile(GetCurrentResourceName(), "shared/sh_factions.json"))
end)

CreateThread(function()
    for k, v in pairs(json.decode(LoadResourceFile(GetCurrentResourceName(), "shared/sh_factions.json"))) do
        for a, b in pairs(v.depositi) do
            exports.ox_inventory:RegisterStash(string.format("%s%s", v.name, a), b.name, tonumber(b.slots), b.peso * 1000, false)
        end
    end
end)

RegisterNetEvent("jobcreator:azioni", function(azione, data)
    local jobs = LoadResourceFile(GetCurrentResourceName(), "shared/sh_factions.json")
    local decoded = json.decode(jobs)
    if azione == "creadeposito" then
        for b,c in pairs(data) do
            for k,v in pairs(data.depositi) do
                exports.ox_inventory:RegisterStash(string.format("%s%s", data.name, k), v.name, tonumber(v.slots), v.peso * 1000, false)
            end
            for i, jobData in ipairs(decoded) do
                if jobData.name == data.name then
                    decoded[i] = data
                    break
                end
            end
            SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
            TriggerClientEvent("registerMarkers", -1)
        end
    elseif azione == "creabossmenu" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "creacamerino" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "creablip" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "creagarage" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "punto1" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "punto2" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "addveh" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("registerMarkers", -1)
    elseif azione == "addgrade" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                decoded[i] = data
                break
            end
        end
        local hasSkinMale, hasSkinFemale = false, false
        for _, col in ipairs(MySQL.Sync.fetchAll("SHOW COLUMNS FROM job_grades")) do
            if col.Field == "skin_male"   then hasSkinMale   = true end
            if col.Field == "skin_female" then hasSkinFemale = true end
        end
        MySQL.prepare("DELETE FROM job_grades WHERE job_name = ?", { data.name })
        for k, v in pairs(data.grades) do
            if hasSkinMale and hasSkinFemale then
                MySQL.prepare("INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, '{}', '{}')", { data.name, v.numgrado, v.name, v.label, v.salary })
            else
                MySQL.prepare("INSERT INTO job_grades (job_name, grade, name, label, salary) VALUES (?, ?, ?, ?, ?)", { data.name, v.numgrado, v.name, v.label, v.salary })
            end
        end
        Wait(500)
        ESX.RefreshJobs()
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
    elseif azione == "delete" then 
        for i, jobData in ipairs(decoded) do
            if jobData.name == data.name then
                Citizen.Wait(100)
                table.remove(decoded, i)
                break
            end
        end
        MySQL.prepare("DELETE FROM job_grades WHERE job_name = ?", { data.name })
        MySQL.prepare("DELETE FROM jobs WHERE name = ?", { data.name })
        MySQL.prepare("DELETE FROM addon_account_data WHERE account_name = ?", { string.format("society_%s", data.name) })
        MySQL.prepare("DELETE FROM addon_account WHERE name = ?", { string.format("society_%s", data.name) })
        Wait(500)
        ESX.RefreshJobs()
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        TriggerClientEvent("DeleteFaz", -1, data.name)
    elseif azione == "creafazione" then 
        table.insert(decoded, data)
        Wait(300)
        MySQL.insert("INSERT IGNORE INTO jobs (name, label) VALUES (?, ?)", { data.name, data.label })
        local columns = MySQL.Sync.fetchAll("SHOW COLUMNS FROM job_grades")
        local hasSkinMale, hasSkinFemale = false, false
        for _, col in ipairs(MySQL.Sync.fetchAll("SHOW COLUMNS FROM job_grades")) do
            if col.Field == "skin_male"   then hasSkinMale   = true end
            if col.Field == "skin_female" then hasSkinFemale = true end
        end
        for k, v in pairs(data.grades) do
            if hasSkinMale and hasSkinFemale then
                MySQL.prepare("INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, '{}', '{}')", { data.name, v.numgrado, v.name, v.label, v.salary })
            else
                MySQL.prepare("INSERT INTO job_grades (job_name, grade, name, label, salary) VALUES (?, ?, ?, ?, ?)", { data.name, v.numgrado, v.name, v.label, v.salary })
            end
        end
        MySQL.insert("INSERT IGNORE INTO addon_account (name, label) VALUES (?, ?)", { string.format("society_%s", data.name), data.label })
        MySQL.insert("INSERT IGNORE INTO addon_account_data (account_name, money) VALUES (?, ?)", { string.format("society_%s", data.name), Sime.CreaFazione.StartFazione or 50000 })
        Wait(500)
        ESX.RefreshJobs()
        SaveResourceFile(GetCurrentResourceName(), "shared/sh_factions.json", json.encode(decoded, { indent = true }), -1)
        if Sime.CreaFazione.WebHookAttivi then
            WebHook(SimeFazioni.Server.Webhook["CreaFazione"], "JOB CREATOR", {{name = "Descrizione", value = (source and GetPlayerName(source) or "Giocatore sconosciuto") .. " ha creato una fazione", inline = false}})
        end
    end
end)