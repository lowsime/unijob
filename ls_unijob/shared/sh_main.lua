Sime = {
    BossMenu = {
        WebHookAttivi = true,
        LavoroBase = "disoccupato",
        LavoroBoss = "boss",
        SlotDeposito = 50,
        PesoDeposito = 250000,
        MaxPrelievo =  1000000,
        MaxBonus = 100000,
    },
    MultiJob = {
        Attivo = true,
        Comando = "multijobs",
        WebHookAttivi = true,
        Max = 2,
        AutoLicenziarsi = true,
    },
    CreaFazione = {
        Comando = "CreateFaz",
        WebHookAttivi = true,
        StartFazione = 50000,
        Staff = {
            "admin",
        },
        Marker = {
            Grandezza = vec3(1.0, 1.2, 1.0),
            Bossmenu = "ls_boss",
            Camerino = "ls_wardrobe",
            Garage = "ls_car",
            Parcheggio = "ls_garage",
            Deposito = "ls_storage",
        }
    }
}