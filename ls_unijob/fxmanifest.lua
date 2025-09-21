fx_version "cerulean"
game "gta5"
lua54 "yes"

shared_script {
	"@ox_lib/init.lua",
    "@es_extended/imports.lua",
    "shared/*.lua"
}

server_script {
    "@oxmysql/lib/MySQL.lua",
    "server/*.lua",
    "server/s_webhook.lua"
}

client_scripts {
    "client/*.lua"
}

escrow_ignore {
    "shared/sh_main.lua",
    "shared/sh_utils.lua",
    "server/s_webhook.lua"
}