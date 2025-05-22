-- Interaction prompt system for ESKUI
local InteractionPrompt = {}
local interactionNUI = nil
local isInteractionShowing = false
local nearbyInteractions = {}
local interactionThreadActive = false
local isAnyUIVisible = false -- Flag to track if any UI is currently visible
local isInitialized = false

-- Access darkMode variable from client.lua
local darkMode = false

-- Create a function to get the nearbyInteractions for other scripts
function GetNearbyInteractions()
    return nearbyInteractions
end

-- Export the function to get nearby interactions
exports('GetNearbyInteractions', GetNearbyInteractions)

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

-- Register for UI state changes to detect when UI is opened or closed
RegisterNetEvent('eskui:uiStateChanged')
AddEventHandler('eskui:uiStateChanged', function(isOpen)
    -- Update the global UI visibility flag
    isAnyUIVisible = isOpen
    
    if isAnyUIVisible then
        -- If any UI is opened, hide the interaction prompt immediately
        InteractionPrompt.Hide()
        interactionThreadActive = false
    else
        -- UI just closed, check for nearby interactions with a delay
        Citizen.SetTimeout(200, function()
            -- Only show if no other UI is visible
            if not isAnyUIVisible then
                InteractionPrompt.CheckForNearbyAndShow()
            end
        end)
    end
    
    if Config.Debug then
        print("^2[ESKUI] UI State Changed - isOpen: " .. tostring(isOpen) .. "^7")
    end
end)

-- Initialize the interaction prompt system
Citizen.CreateThread(function()
    -- Wait a moment for everything to load
    Citizen.Wait(1000)
    
    -- Wait for framework to initialize
    Framework.WaitForInitialization(function()
        isInitialized = true
        
        -- Load the interaction prompt UI
        interactionNUI = LoadResourceFile(GetCurrentResourceName(), "html/interaction.html")
        
        -- Start checking for nearby interactions
        CheckNearbyInteractions()
        
        -- Register shop interactions with a delay to ensure everything is loaded
        Citizen.SetTimeout(1000, function()
            InteractionPrompt.RegisterShops()
            if Config.Debug then
                print("^2[ESKUI] Registered shop interactions after framework initialization^7")
            end
        end)
        
        if Config.Debug then
            print("^2[ESKUI] Interaction system initialized after framework ready^7")
        end
    end)
end)

-- Global key listener for interaction key
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Skip if not initialized
        if not isInitialized then
            Citizen.Wait(500)
            goto continue
        end
        
        -- Check if the interaction key is pressed
        if IsControlJustPressed(0, Config.Interaction.key) then
            -- Only check for interactions if no UI is currently visible
            if not isAnyUIVisible then
                -- Add a delay to let other UI processes happen first
                Citizen.SetTimeout(200, function()
                    if Config.Debug then
                        print("^2[ESKUI] Interaction key pressed, checking for nearby interactions^7")
                    end
                    
                    -- Check for nearby interactions to show the prompt again
                    InteractionPrompt.CheckForNearbyAndShow()
                end)
            end
        end
        
        ::continue::
    end
end)

-- Show the interaction prompt
function InteractionPrompt.Show(config)
    -- Don't show if any UI is visible
    if isAnyUIVisible then
        if Config.Debug then
            print("^3[ESKUI] Cannot show interaction prompt - UI is visible^7")
        end
        return
    end
    
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
    
    if Config.Debug then
        print("^2[ESKUI] Showing interaction prompt^7")
    end
end

-- Hide the interaction prompt
function InteractionPrompt.Hide()
    if not isInteractionShowing then return end
    
    SendNUIMessage({
        type = 'hideInteraction'
    })
    
    isInteractionShowing = false
    
    if Config.Debug then
        print("^2[ESKUI] Hiding interaction prompt^7")
    end
end

-- Register a new interaction zone
function InteractionPrompt.Register(id, coords, radius, config, action)
    -- Skip if not initialized
    if not isInitialized then
        if Config.Debug then
            print("^3[ESKUI] Cannot register interaction - system not initialized yet^7")
        end
        return nil
    end
    
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
    if not Config.Shops then 
        if Config.Debug then
            print("^3[ESKUI] Cannot register shop interactions - Config.Shops is nil^7")
        end
        return 
    end
    
    -- Clear any existing shop interactions first
    local newInteractions = {}
    for _, interaction in ipairs(nearbyInteractions) do
        if not string.match(interaction.id, "^shop_") then
            table.insert(newInteractions, interaction)
        end
    end
    nearbyInteractions = newInteractions
    
    -- Register all shops
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
                return false -- Return false to keep the interaction available for future use
            end
        )
    end
    
    if Config.Debug then
        print("^2[ESKUI] Registered " .. #Config.Shops .. " shop interactions^7")
    end
end

-- Check for nearby interactions continuously
function CheckNearbyInteractions()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500) -- Check every half second
            
            -- Skip if not initialized
            if not isInitialized then
                Citizen.Wait(1000)
                goto continue
            end
            
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
            
            ::continue::
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
        
        -- Add a flag to track if we've just handled a key press
        local keyHandled = false
        
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
            
            -- Reset key handled flag when key is released
            if not IsControlPressed(0, Config.Interaction.key) then
                keyHandled = false
            end
            
            -- Check if the interaction key is pressed (using IsControlJustReleased for better responsiveness)
            if IsControlJustPressed(0, Config.Interaction.key) and not keyHandled then
                -- Set flag to prevent multiple activations
                keyHandled = true
                
                -- Hide prompt
                InteractionPrompt.Hide()
                
                -- Call action if exists
                if interaction.action then
                    -- Call with a slight delay to ensure button press is fully processed
                    Citizen.SetTimeout(50, function()
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
                    end)
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

-- Check if player is near an interaction and show prompt if needed
function InteractionPrompt.CheckForNearbyAndShow()
    -- Skip if not initialized
    if not isInitialized then
        if Config.Debug then
            print("^3[ESKUI] Cannot check for nearby interactions - system not initialized^7")
        end
        return
    end
    
    -- Wait a short moment to ensure other operations complete
    Citizen.SetTimeout(100, function()
        -- Don't show the interaction if there's already an active interaction thread
        if interactionThreadActive then 
            if Config.Debug then
                print("^3[ESKUI] Interaction thread already active, not showing prompt^7")
            end
            return 
        end
        
        -- Don't show when the UI is already showing
        if isInteractionShowing then 
            if Config.Debug then
                print("^3[ESKUI] Interaction prompt already showing, not showing again^7")
            end
            return 
        end
        
        -- Don't show when any UI is visible
        if isAnyUIVisible then
            if Config.Debug then
                print("^3[ESKUI] UI is visible, not showing interaction prompt^7")
            end
            return
        end
        
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
        
        -- If a nearby interaction is found, start its thread
        if nearestInteraction then
            if Config.Debug then
                print("^2[ESKUI] Found nearby interaction: " .. nearestInteraction.id .. " at distance: " .. nearestDistance .. "^7")
            end
            StartInteractionThread(nearestInteraction)
        else
            if Config.Debug then
                print("^3[ESKUI] No nearby interactions found in range^7")
                print("^3[ESKUI] Total interactions registered: " .. #nearbyInteractions .. "^7")
                if #nearbyInteractions > 0 then
                    print("^3[ESKUI] Nearest interaction distance: " .. nearestDistance .. "^7")
                end
            end
        end
    end)
end

-- Export functions
exports('RegisterInteraction', InteractionPrompt.Register)
exports('ShowInteractionPrompt', InteractionPrompt.Show)
exports('HideInteractionPrompt', InteractionPrompt.Hide)
exports('CheckForNearbyAndShow', InteractionPrompt.CheckForNearbyAndShow)

-- Register shop interactions when resource starts
RegisterNetEvent('onClientResourceStart')
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Register shop interactions after framework initialization
        Framework.WaitForInitialization(function()
            Citizen.SetTimeout(2000, function()
                InteractionPrompt.RegisterShops()
                if Config.Debug then
                    print("^2[ESKUI] Registered shop interactions on resource start^7")
                end
            end)
        end)
    end
end)

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