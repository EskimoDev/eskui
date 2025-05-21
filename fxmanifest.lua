-- Resource metadata
fx_version 'cerulean'
game 'gta5'
author 'ESKUI'
description 'Modern UI System for FiveM'
version '1.0.0'

-- Add dependencies to ensure frameworks are loaded first
dependencies {
    'es_extended'
}

-- Configuration files (order matters - config.lua must be loaded before shops.lua)
shared_scripts {
    'cfg/config.lua', -- Load main config first
    'cfg/shops.lua'   -- Load shops config after
}

-- Framework and client scripts
client_scripts {
    'framework/framework.lua',
    'client/client.lua',
    'client/client_shop.lua',
    'client/client_test.lua',
    'client/client_interaction.lua'
}

-- Server scripts
server_scripts {
    'server/server.lua',
    'server/server_shop.lua'
}

-- NUI settings
ui_page 'html/index.html'

-- HTML/CSS/JS files
files {
    'html/index.html',
    'html/interaction.html',
    'html/styles.css',
    'html/script.js'
} 