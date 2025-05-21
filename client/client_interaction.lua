-- Interaction prompt system for ESKUI
local InteractionPrompt = {}
local interactionNUI = nil
local isInteractionShowing = false
local nearbyInteractions = {}
local interactionThreadActive = false

-- Access darkMode variable from client.lua
local darkMode = false

-- Listen for dark mode changes
RegisterNetEvent('eskui:darkModeChanged')
AddEventHandler('eskui:darkModeChanged', function(isEnabled)
    darkMode = isEnabled
    
    -- Update interaction prompt if it's showing
    if isInteractionShowing then
        -- Refresh the interaction prompt with new dark mode setting
        local promptConfig = {
            darkMode = darkMode
        }
        SendNUIMessage({
            type = 'updateInteractionDarkMode',
            config = promptConfig
        })
    end
end)

-- Initialize the interaction prompt system
Citizen.CreateThread(function()
    -- Wait for framework to initialize
    while not Framework.IsInitialized() do
        Citizen.Wait(100)
    end
    
    -- Load the interaction prompt UI
    interactionNUI = LoadResourceFile(GetCurrentResourceName(), "html/interaction.html")
    
    -- Start checking for nearby interactions
    CheckNearbyInteractions()
end)

-- Show the interaction prompt
function InteractionPrompt.Show(config)
    if isInteractionShowing then return end
    
    -- Default config using values from Config.Interaction
    local promptConfig = {
        key = Config.Interaction.keyName,
        isMouse = Config.Interaction.isMouse,
        position = Config.Interaction.position,
        color = Config.Interaction.color,
        scale = Config.Interaction.scale,
        textLeft = Config.Interaction.textLeft,
        textRight = Config.Interaction.textRight,
        pulseEffect = Config.Interaction.pulseEffect,
        darkMode = darkMode -- Add the dark mode state
    }
    
    -- Override with any provided config
    if config then
        for k, v in pairs(config) do
            promptConfig[k] = v
        end
    end
    
    -- Send to NUI
    SendNUIMessage({
        type = 'showInteraction',
        config = promptConfig
    })
    
    isInteractionShowing = true
end

-- Hide the interaction prompt
function InteractionPrompt.Hide()
    if not isInteractionShowing then return end
    
    SendNUIMessage({
        type = 'hideInteraction'
    })
    
    isInteractionShowing = false
end

-- Register a new interaction zone
function InteractionPrompt.Register(id, coords, radius, config, action)
    -- Handle arrays of coordinates
    if type(coords[1]) == "table" or type(coords[1]) == "vector3" then
        for _, coord in ipairs(coords) do
            InteractionPrompt.Register(id .. "_" .. _, coord, radius, config, action)
        end
        return
    end
    
    -- Make sure coordinates are in vector3 format
    if type(coords) ~= "vector3" then
        coords = vector3(coords.x, coords.y, coords.z)
    end
    
    -- Create new interaction
    local interaction = {
        id = id,
        coords = coords,
        radius = radius or Config.Interaction.showDistance,
        config = config or {},
        action = action
    }
    
    -- Add to interactions table
    table.insert(nearbyInteractions, interaction)
    
    -- Debug message
    if Config.Debug then
        print("^2[ESKUI] Registered interaction zone: " .. id .. "^7")
    end
    
    return interaction
end

-- Create interactions for all shop locations
function InteractionPrompt.RegisterShops()
    if not Config.Shops then return end
    
    for shopIndex, shop in ipairs(Config.Shops) do
        local shopConfig = {
            textLeft = "Press",
            textRight = "to open " .. shop.name
        }
        
        InteractionPrompt.Register(
            "shop_" .. shopIndex,
            shop.locations,
            Config.Interaction.showDistance,
            shopConfig,
            function()
                -- Open shop
                OpenShop(shop)
                return true -- Return true to remove interaction after triggering
            end
        )
    end
end

-- Check for nearby interactions continuously
function CheckNearbyInteractions()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500) -- Check every half second
            
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearestInteraction = nil
            local nearestDistance = 999.0
            
            -- Find the nearest interaction point
            for _, interaction in ipairs(nearbyInteractions) do
                local distance = #(playerCoords - interaction.coords)
                
                if distance < interaction.radius and distance < nearestDistance then
                    nearestInteraction = interaction
                    nearestDistance = distance
                end
            end
            
            -- Start or stop interaction thread based on whether an interaction is nearby
            if nearestInteraction and not interactionThreadActive then
                StartInteractionThread(nearestInteraction)
            elseif not nearestInteraction and isInteractionShowing then
                InteractionPrompt.Hide()
            end
        end
    end)
end

-- Start interaction thread for a specific interaction
function StartInteractionThread(interaction)
    if interactionThreadActive then return end
    
    interactionThreadActive = true
    
    Citizen.CreateThread(function()
        local interactionId = interaction.id
        
        if Config.Debug then
            print("^2[ESKUI] Starting interaction thread for: " .. interactionId .. "^7")
        end
        
        -- Show the interaction prompt
        InteractionPrompt.Show(interaction.config)
        
        while interactionThreadActive do
            Citizen.Wait(0)
            
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - interaction.coords)
            
            -- Check if player is still in range
            if distance > interaction.radius then
                interactionThreadActive = false
                InteractionPrompt.Hide()
                break
            end
            
            -- Check if the interaction key is pressed
            if IsControlJustPressed(0, Config.Interaction.key) then
                -- Hide prompt
                InteractionPrompt.Hide()
                
                -- Call action if exists
                if interaction.action then
                    local removeInteraction = interaction.action()
                    
                    -- If action returns true, remove this interaction
                    if removeInteraction then
                        -- Find and remove this interaction
                        for i, inter in ipairs(nearbyInteractions) do
                            if inter.id == interactionId then
                                table.remove(nearbyInteractions, i)
                                if Config.Debug then
                                    print("^2[ESKUI] Removed interaction: " .. interactionId .. "^7")
                                end
                                break
                            end
                        end
                    end
                end
                
                interactionThreadActive = false
                break
            end
        end
        
        -- Ensure prompt is hidden when thread ends
        InteractionPrompt.Hide()
        interactionThreadActive = false
    end)
end

-- Export functions
exports('RegisterInteraction', InteractionPrompt.Register)
exports('ShowInteractionPrompt', InteractionPrompt.Show)
exports('HideInteractionPrompt', InteractionPrompt.Hide)

-- Test commands for interaction prompt
if Config.Debug then
    -- Test command to show the interaction prompt
    RegisterCommand('testinteraction', function()
        -- Show interaction prompt
        InteractionPrompt.Show()
        
        -- Automatic hide after 5 seconds
        Citizen.SetTimeout(5000, function()
            InteractionPrompt.Hide()
        end)
    end, false)
    
    -- Test command to register an interaction at the player's position
    RegisterCommand('createinteraction', function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Generate a unique ID
        local id = "test_interaction_" .. math.random(1000, 9999)
        
        -- Register the interaction
        InteractionPrompt.Register(
            id,
            playerCoords,
            2.0,
            {
                textLeft = "Press",
                textRight = "to test interaction"
            },
            function()
                TriggerEvent('chat:addMessage', {
                    color = {149, 107, 213},
                    args = {"ESKUI", "Test interaction triggered!"}
                })
                return false -- Don't remove after triggering
            end
        )
        
        -- Add a blip for easier finding
        local blip = AddBlipForCoord(playerCoords)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 27)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Test Interaction")
        EndTextCommandSetBlipName(blip)
        
        -- Notification
        Framework.ShowNotification("Created interaction at your position", "success")
    end, false)
    
    -- Register shop interactions when resource starts
    RegisterNetEvent('onClientResourceStart')
    AddEventHandler('onClientResourceStart', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            -- Register shop interactions
            Citizen.SetTimeout(2000, function()
                InteractionPrompt.RegisterShops()
            end)
        end
    end)
    
    -- Command to manually register shop interactions
    RegisterCommand('registershops', function()
        InteractionPrompt.RegisterShops()
        Framework.ShowNotification("Registered shop interactions", "success")
    end, false)
    
    -- Command to test a mouse button prompt
    RegisterCommand('testmouse', function()
        InteractionPrompt.Show({
            key = 'LMB',
            isMouse = true,
            textLeft = "Click",
            textRight = "to test mouse interaction"
        })
        
        -- Automatic hide after 5 seconds
        Citizen.SetTimeout(5000, function()
            InteractionPrompt.Hide()
        end)
    end, false)
    
    -- Add command suggestions
    TriggerEvent('chat:addSuggestion', '/testinteraction', 'Test the interaction prompt')
    TriggerEvent('chat:addSuggestion', '/testmouse', 'Test the mouse interaction prompt')
    TriggerEvent('chat:addSuggestion', '/createinteraction', 'Create an interaction at your current position')
    TriggerEvent('chat:addSuggestion', '/registershops', 'Register interaction prompts for all shops')
end 