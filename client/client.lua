-- Import globals from client_menus.lua
-- display -> Display
-- darkMode -> DarkMode
-- windowOpacity -> WindowOpacity
-- freeDrag -> FreeDrag
-- state -> State
-- ShopCheckoutHandler is already a global

-- Register commands
local function registerCommands()
    RegisterCommand('darkmode', function()
        DarkMode = not DarkMode
        SendNUIMessage({type = 'toggleDarkMode'})
        TriggerEvent('chat:addMessage', {
            color = {149, 107, 213},
            args = {"ESKUI", "Dark mode " .. (DarkMode and "enabled" or "disabled")}
        })
    end, false)

    RegisterCommand('uisettings', function()
        SendNUIMessage({type = 'showSettings'})
        SetNuiFocus(true, true)
    end, false)

    -- Add command suggestions
    TriggerEvent('chat:addSuggestion', '/darkmode', 'Toggle ESKUI dark mode')
    TriggerEvent('chat:addSuggestion', '/uisettings', 'Open ESKUI settings menu')
    
    -- Test commands for debugging
    if Config.Debug then
        -- Debug command to check current UI state and handlers
        RegisterCommand('debugshop', function()
            print("^2[ESKUI DEBUG] ========= CURRENT UI STATE =========^7")
            print("^2[ESKUI DEBUG] Display: " .. tostring(Display) .. "^7")
            print("^2[ESKUI DEBUG] Dark Mode: " .. tostring(DarkMode) .. "^7")
            print("^2[ESKUI DEBUG] Window Opacity: " .. tostring(WindowOpacity) .. "^7")
            print("^2[ESKUI DEBUG] Free Drag: " .. tostring(FreeDrag) .. "^7")
            print("^2[ESKUI DEBUG] ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
            
            -- Check if any menu is open
            if State.currentMenuData then
                print("^2[ESKUI DEBUG] Current Menu: " .. (State.currentMenuData.title or "Unknown") .. "^7")
                print("^2[ESKUI DEBUG] Menu Items: " .. (State.currentMenuData.items and #State.currentMenuData.items or 0) .. "^7")
            else
                print("^2[ESKUI DEBUG] No menu currently open^7")
            end
            
            -- Check menu history
            if State.menuHistory and #State.menuHistory > 0 then
                print("^2[ESKUI DEBUG] Menu history size: " .. #State.menuHistory .. "^7")
            else
                print("^2[ESKUI DEBUG] No menu history^7")
            end
            
            -- Force cleanup of any dangling handlers
            if ShopCheckoutHandler then
                print("^2[ESKUI DEBUG] Forcing cleanup of ShopCheckoutHandler^7")
                RemoveEventHandler(ShopCheckoutHandler)
                ShopCheckoutHandler = nil
            end
            
            print("^2[ESKUI DEBUG] ========= END UI STATE =========^7")
        end, false)
        
        -- Add command suggestion
        TriggerEvent('chat:addSuggestion', '/debugshop', 'Debug the current shop UI state')
    end
end

-- Global key detection thread
local function startKeyDetectionThread()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            
            -- Check if the interaction key is pressed
            if IsControlJustPressed(0, Config.Interaction.key) then
                -- Only proceed if UI isn't displayed
                if not Display then
                    -- If in debug mode, print information
                    if Config.Debug then
                        print("^2[ESKUI] Interaction key pressed in client.lua^7")
                    end
                    
                    -- Check if we're near any interaction point
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    local hasInteractedWithPoint = false
                    
                    -- Get nearby interactions from the exported function
                    local interactions = exports['eskui']:GetNearbyInteractions()
                    
                    -- Check if any shop is close enough to interact directly
                    for _, interaction in ipairs(interactions or {}) do
                        local distance = #(playerCoords - interaction.coords)
                        
                        if distance < interaction.radius then
                            -- We found an interaction point that we're in range of
                            if interaction.action then
                                hasInteractedWithPoint = true
                                
                                -- Call the action directly
                                Citizen.SetTimeout(50, function()
                                    interaction.action()
                                end)
                                
                                if Config.Debug then
                                    print("^2[ESKUI] Directly triggering interaction: " .. interaction.id .. "^7")
                                end
                                
                                -- Only trigger one interaction
                                break
                            end
                        end
                    end
                    
                    -- If we didn't directly interact with a point, check for any nearby points
                    if not hasInteractedWithPoint then
                        -- Add a delay to ensure UI processes complete
                        Citizen.SetTimeout(100, function()
                            -- Check for nearby interactions and show prompt if in range
                            exports['eskui']:CheckForNearbyAndShow()
                        end)
                    end
                end
            end
        end
    end)
end

-- Initialize commands and key detection
registerCommands()
startKeyDetectionThread() 