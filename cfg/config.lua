Config = {}

-- Framework settings
Config.Framework = 'esx' -- Options: 'esx', 'qbcore', 'standalone'

-- Debug mode
Config.Debug = true -- Set to false in production

-- Money settings
Config.MoneyTypes = {
    cash = "cash",
    bank = "bank"
}
Config.DefaultMoneyType = Config.MoneyTypes.cash -- Which account to use by default

-- Notification system settings
Config.NotificationSystem = 'eskui' -- Options: 'framework', 'eskui', 'custom'

-- Custom notification export (only used if NotificationSystem is set to 'custom')
Config.CustomNotification = {
    -- Example of how to set up a custom notification:
    -- resource = 'mythic_notify',  -- Resource name
    -- func = 'SendAlert',          -- Export function name
    -- params = function(type, title, message, duration)  -- How to format parameters for the custom notification
    --     return {
    --         type = type,
    --         text = message,
    --         length = duration / 1000  -- If your system uses seconds instead of milliseconds
    --     }
    -- end
    
    -- Default uses eskui's notification as example:
    resource = 'eskui',
    func = 'ShowNotification',
    params = function(type, title, message, duration)
        return {
            type = type,
            title = title,
            message = message,
            duration = duration
        }
    end
}

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