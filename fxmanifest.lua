fx_version 'cerulean'
game 'gta5'

author 'ESKUI'
description 'Modern UI System for FiveM'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'framework/framework.lua',
    'client/client.lua',
    'client/client_shop.lua',
    'client/client_test.lua'
}

server_scripts {
    'server/server.lua',
    'server/server_shop.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/script.js'
} 