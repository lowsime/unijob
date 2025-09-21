WebHook = function(url, title, fields)
    local embedFields = {}
    for _, field in ipairs(fields) do
        table.insert(embedFields, {name = field.name, value = field.value, inline = field.inline or false})
    end
    PerformHttpRequest(url, function(status, text)
    end, "POST", json.encode {
        username   = "Hazard City",
        avatar_url = "https://i.postimg.cc/wMPTRYQL/hazardgif.gif",
        embeds     = {{
            title = title,
            color = 3999972,
            author = {name = "Hazard City", icon_url = "https://i.postimg.cc/wMPTRYQL/hazardgif.gif"},
            fields = embedFields,
            footer = {text = ("Hazard City > | %s"):format(os.date("%x | %X %p"))}
        }}
    }, {["Content-Type"] = "application/json"})
end

ApriBossMenu = function(job)
    TriggerEvent("ls_unijob:openBossMenu", job)
end

ApriArmadietto = function()
    if GetResourceState("illenium-appearance") == "started" then
        TriggerEvent("illenium-appearance:client:openClothingShop", cache.ped, true)
    elseif GetResourceState("fivem-appearance") == "started" then
        exports["fivem-appearance"]:setPedAppearance(cache.ped)
    end
end