local PlayerService = {}

RegisterNetEvent("ls_utils:InServizio")
AddEventHandler("ls_utils:InServizio", function(stato)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local nuovoStato = stato

    if nuovoStato == xPlayer.getJob().onDuty ~= nil and xPlayer.getJob().onDuty or PlayerService[src] == xPlayer.getJob().name then
        TriggerClientEvent("esx:showNotification", src, nuovoStato and "Sei già in servizio!" or "Non sei in servizio!")
        return false
    end

    if xPlayer.getJob().onDuty ~= nil then
        xPlayer.setJob(xPlayer.getJob().name, xPlayer.getJob().grade, nuovoStato)
    else
        PlayerService[src] = nuovoStato and xPlayer.getJob().name or nil
    end

    TriggerEvent("ls_utils:SyncService", src, nuovoStato)
    TriggerClientEvent("esx:showNotification", src, nuovoStato and "Sei entrato in servizio!" or "Sei uscito dal servizio!")

    return true
end)

RegisterNetEvent("ls_utils:SyncService")
AddEventHandler("ls_utils:SyncService", function(targetSrc, state)
    TriggerClientEvent("ls_utils:SyncService", targetSrc, state)
end)

RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(source, newJob, oldJob)
    if PlayerService[source] and oldJob.name ~= newJob.name then
        PlayerService[source] = nil
    end
end)

AddEventHandler("esx:playerDropped", function(playerId)
    if PlayerService[playerId] then
        PlayerService[playerId] = nil
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src, jobName in pairs(PlayerService) do
        if jobName then
            PlayerService[src] = nil
            TriggerClientEvent("ls_utils:SyncService", src, false)
        end
    end
end)