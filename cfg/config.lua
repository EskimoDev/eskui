Config = {}

-- Framework settings
Config.Framework = 'esx' -- Options: 'esx', 'qbcore', 'standalone'

-- Debug mode
Config.Debug = true -- Set to false in production

-- Money settings
Config.MoneyTypes = {
    cash = "money",  -- ESX cash account name (can be "money" or direct money property)
    bank = "bank"    -- ESX bank account name
}
Config.DefaultMoneyType = Config.MoneyTypes.cash -- Which account to use by default

-- Interaction Prompt settings
Config.Interaction = {
    -- Key to press for interaction (see: https://docs.fivem.net/docs/game-references/controls/)
    key = 38, -- E key by default
    keyName = "E", -- Display name for key
    isMouse = false, -- Whether it's a mouse button or keyboard key
    
    -- UI settings
    position = "center", -- Options: "center", "bottom"
    showDistance = 2.0, -- Maximum distance to show prompt
    color = "#007AFF", -- Primary color for the prompt
    scale = 1.0, -- Size multiplier
    
    -- Text settings
    textLeft = "Press",
    textRight = "to interact",
    
    -- Animation settings
    pulseEffect = true, -- Whether the icon should pulse
    fadeInSpeed = 0.2, -- Speed of fade in (seconds)
    fadeOutSpeed = 0.2 -- Speed of fade out (seconds)
}