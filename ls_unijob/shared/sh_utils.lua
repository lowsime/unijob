WebHook = function(url, title, fields)
    local embedFields = {}
    for _, field in ipairs(fields) do
        table.insert(embedFields, {name = field.name, value = field.value, inline = field.inline or false})
    end
    PerformHttpRequest(url, function(status, text)
    end, "POST", json.encode {
        username   = "Nome Server tuo",
        avatar_url = "immagine png o gif",
        embeds     = {{
            title = title,
            color = 3999972,
            author = {name = "Nome Server tuo", icon_url = "immagine png o gif"},
            fields = embedFields,
            footer = {text = ("Nome Server tuo > | %s"):format(os.date("%x | %X %p"))}
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
