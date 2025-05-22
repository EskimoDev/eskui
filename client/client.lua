local display = false
local darkMode = false
local windowOpacity = 0.95
local freeDrag = false
local state = {
    menuHistory = {}
}

-- Shared checkout handler variable
ShopCheckoutHandler = nil

-- Helper function to manage UI focus state
local function setUIFocus(show)
    display = show
    SetNuiFocus(show, show)
    -- Notify the interaction system of UI state change
    TriggerEvent('eskui:uiStateChanged', show)
    
    -- When closing, check for nearby interactions
    if not show then
        exports['eskui']:CheckForNearbyAndShow()
    end
end

-- Helper function to send NUI messages with common structure
local function sendUIMessage(messageType, title, data)
    -- Create message with common structure
    local message = {
        type = messageType,
        title = title
    }
    
    -- Add additional data if provided
    if data then
        for k, v in pairs(data) do 
            message[k] = v 
        end
    end
    
    SendNUIMessage(message)
end

-- Helper function for submenu operations
local function processSubmenuItems(submenuItems, addBackButton)
    -- Ensure submenuItems is a valid table
    if submenuItems == nil then
        print("ERROR: Submenu items is nil - creating empty table")
        submenuItems = {}
    elseif type(submenuItems) ~= 'table' then
        print("ERROR: Submenu items is not a table, type: " .. type(submenuItems))
        submenuItems = {}
    end
    
    -- Add a back button if requested and not already present
    if addBackButton then
        local hasBackButton = false
        for _, item in ipairs(submenuItems) do
            if item and item.isBack then 
                hasBackButton = true
                break
            end
        end
        
        if not hasBackButton then
            print("Adding back button to submenu")
            table.insert(submenuItems, { 
                label = 'Back', 
                isBack = true, 
                icon = '⬅️' 
            })
        end
    end
    
    return submenuItems
end

-- Common NUI callback handling
local function handleNUICallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        print("Received NUI callback: " .. name)
        
        -- Always acknowledge the callback first to avoid NUI freezes
        cb('ok')
        
        -- For submenu navigation, don't reset focus
        if name == 'submenuSelect' or name == 'submenuBack' then
            -- Make sure display stays true to maintain UI visibility
            setUIFocus(true)
            
            if handler then 
                -- Run the callback handler with the data
                handler(data)
            end
            return
        end
        
        -- For regular callbacks, reset focus and close UI
        setUIFocus(false)
        
        if handler then handler(data) end
    end)
end

-- Create generic handler for simple event callbacks
local function createEventCallback(eventName, preProcessor)
    return function(data)
        local processedData = data
        if preProcessor then
            processedData = preProcessor(data)
        end
        TriggerEvent(eventName, table.unpack(processedData))
    end
end

-- Register standard callbacks with common pattern
local callbacks = {
    amountSubmit = function(data) 
        TriggerEvent('eskui:amountCallback', data.amount)
    end,
    listSelect = function(data) 
        TriggerEvent('eskui:listCallback', data.index, data.item)
    end,
    dropdownSelect = function(data) 
        TriggerEvent('eskui:dropdownCallback', data.index, data.value)
    end,
    darkModeChanged = function(data) 
        darkMode = data.darkMode 
        -- Trigger event for other modules
        TriggerEvent('eskui:darkModeChanged', darkMode)
    end,
    opacityChanged = function(data) windowOpacity = data.windowOpacity end,
    freeDragChanged = function(data) freeDrag = data.freeDrag end,
    close = function() 
        setUIFocus(false)
        TriggerEvent('eskui:closeCallback')
    end,
    shopCheckout = function(data) 
        if Config.Debug then
            print("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK TRIGGERED =========^7")
            print("^6[ESKUI DEBUG] Data received from UI: " .. tostring(data ~= nil) .. "^7")
            print("^6[ESKUI DEBUG] ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
        end
        
        -- Prevent duplicate checkout processes
        if _G.checkoutInProgress then
            if Config.Debug then
                print("^6[ESKUI DEBUG] Checkout already in progress, ignoring duplicate callback^7")
                print("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK IGNORED =========^7")
            end
            return
        end
        
        -- Set checkout in progress flag
        _G.checkoutInProgress = true
        
        -- Clear the flag after timeout (consolidated to one place)
        Citizen.SetTimeout(5000, function()
            _G.checkoutInProgress = false
            if Config.Debug then
                print("^6[ESKUI DEBUG] Checkout in progress flag cleared after timeout^7")
            end
        end)
        
        print("Received shop checkout callback with total: $" .. data.total)
        
        -- Add debugging to check item data
        if Config.Debug then
            print("^6[ESKUI DEBUG] Processing shop checkout with " .. #data.items .. " items^7")
            
            for i, item in ipairs(data.items) do
                print("^6[ESKUI DEBUG] Item #" .. i .. ": " .. item.id .. " x" .. item.quantity .. "^7")
                
                -- Make sure the item has the inventoryName property for the framework
                if item.inventoryName then
                    print("^6[ESKUI DEBUG]   - Using inventory name: " .. item.inventoryName .. "^7")
                else
                    print("^6[ESKUI DEBUG] No inventory name available for item: " .. item.id .. "^7")
                end
            end
        end
        
        -- Close UI and set focus properly
        setUIFocus(false)
        
        -- Process the shop checkout
        if Config.Debug then
            print("^6[ESKUI DEBUG] Triggering eskui:shopCheckoutCallback event^7")
        end
        
        TriggerEvent('eskui:shopCheckoutCallback', data)
        
        if Config.Debug then
            print("^6[ESKUI DEBUG] Event triggered successfully^7")
            print("^6[ESKUI DEBUG] ShopCheckoutHandler after event: " .. tostring(ShopCheckoutHandler) .. "^7")
            print("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK COMPLETE =========^7")
        end
    end,
    submenuSelect = function(data) 
        -- Debug
        print("Handling submenu selection for item: " .. (data.item.label or "unknown"))
        
        -- IMPORTANT: Explicitly set UI state to shown
        setUIFocus(true)
        
        -- Handle submenu selection
        if data.item and data.item.submenu then
            -- Get submenu items - can be direct table or function returning table
            local submenuItems
            if type(data.item.submenu) == "function" then
                submenuItems = data.item.submenu()
                print("Got submenu items from function")
            else
                submenuItems = data.item.submenu
                print("Got submenu items from table") 
            end
            
            -- Process and validate the submenu items (add back button, etc.)
            submenuItems = processSubmenuItems(submenuItems, true)
            
            -- Print debug info about the submenu items
            print("Submenu items count: " .. #submenuItems)
            for i, item in ipairs(submenuItems) do
                print("  Item " .. i .. ": " .. (item.label or "no label"))
            end
            
            -- Store current menu in history for back navigation
            if not state.menuHistory then state.menuHistory = {} end
            if state.currentMenuData then
                table.insert(state.menuHistory, state.currentMenuData)
                print("Added current menu to history, history size: " .. #state.menuHistory)
            end
            
            -- Store current submenu data
            state.currentMenuData = {
                title = data.item.label,
                items = submenuItems,
                parentIndex = data.index
            }
            
            -- Send the submenu message
            sendUIMessage('showList', data.item.label, {
                items = submenuItems,
                isSubmenu = true
            })
            
            -- Debug
            print("Showing submenu: " .. data.item.label .. " with " .. #submenuItems .. " items")
        else
            print("ERROR: Submenu selection with no submenu data")
        end
    end,
    submenuBack = function()
        -- Debug
        print("Handling back navigation in submenu")
        
        -- Ensure UI stays visible and focused
        setUIFocus(true)
        
        -- Navigate back to previous menu if history exists
        if state.menuHistory and #state.menuHistory > 0 then
            -- Get previous menu
            local prevMenu = table.remove(state.menuHistory)
            print("Going back to menu: " .. prevMenu.title .. " with " .. #prevMenu.items .. " items")
            
            -- Update current menu data first
            state.currentMenuData = prevMenu
            
            -- Send the message 
            sendUIMessage('showList', prevMenu.title, {
                items = prevMenu.items,
                isSubmenu = #state.menuHistory > 0
            })
            
            print("Successfully navigated back to previous menu")
        else
            -- If no history left, close the menu
            print("No menu history, closing UI")
            setUIFocus(false)
            TriggerEvent('eskui:closeCallback')
        end
    end
}

-- Register all callbacks
for name, handler in pairs(callbacks) do
    handleNUICallback(name, handler)
end

-- Register commands
RegisterCommand('darkmode', function()
    darkMode = not darkMode
    sendUIMessage('toggleDarkMode')
    TriggerEvent('chat:addMessage', {
        color = {149, 107, 213},
        args = {"ESKUI", "Dark mode " .. (darkMode and "enabled" or "disabled")}
    })
end, false)

RegisterCommand('uisettings', function()
    sendUIMessage('showSettings')
    setUIFocus(true)
end, false)

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/darkmode', 'Toggle ESKUI dark mode')
TriggerEvent('chat:addSuggestion', '/uisettings', 'Open ESKUI settings menu')

-- Handler registration with automatic cleanup
local function registerEskuiHandler(event, handler)
    -- Store handlers by event name to prevent duplicates
    if not _G.registeredHandlers then
        _G.registeredHandlers = {}
    end
    
    -- Validate inputs to prevent errors
    if not event or type(event) ~= 'string' then
        print("^1[ESKUI ERROR] Invalid event name passed to registerEskuiHandler^7")
        return nil
    end
    
    if not handler or type(handler) ~= 'function' then
        print("^1[ESKUI ERROR] Invalid handler function passed to registerEskuiHandler^7")
        return nil
    end
    
    -- Check for existing handler for this event and remove it
    if _G.registeredHandlers[event] then
        if Config.Debug then
            print("^2[ESKUI DEBUG] Found existing handler for event: " .. event .. "^7")
        end
        
        -- Remove the existing handler
        RemoveEventHandler(_G.registeredHandlers[event])
        _G.registeredHandlers[event] = nil
        
        if Config.Debug then
            print("^2[ESKUI DEBUG] Removed existing handler for event: " .. event .. "^7")
        end
    end
    
    -- Store handlerId in local scope before using it in the event handler
    local handlerId = nil
    
    -- Create the handler function first - add ... parameter to make it a vararg function
    local eventFunction = function(...)
        if Config.Debug then
            print("^2[ESKUI DEBUG] Event handler triggered for: " .. event .. "^7")
        end
        
        local result = false
        
        -- Call the handler with pcall to catch any errors
        local success, handlerResult = pcall(function(...)
            return handler(...)
        end, ...)
        
        -- Check if handler executed successfully
        if success then
            result = handlerResult
            
            if Config.Debug then
                print("^2[ESKUI DEBUG] Handler executed successfully, result: " .. tostring(result) .. "^7")
            end
        else
            print("^1[ESKUI ERROR] Error in event handler: " .. tostring(handlerResult) .. "^7")
        end
        
        -- If handler returned true or nil, we should remove this handler
        if result ~= false then
            -- Only try to remove if handlerId is valid
            if handlerId then
                -- Use pcall to prevent errors if removal fails
                pcall(function()
                    if Config.Debug then
                        print("^2[ESKUI DEBUG] Removing handler for event: " .. event .. "^7")
                    end
                    
                    RemoveEventHandler(handlerId)
                    
                    -- Also remove from our tracking table
                    if _G.registeredHandlers then
                        _G.registeredHandlers[event] = nil
                    end
                end)
                handlerId = nil
            end
        end
        
        return result
    end
    
    -- Now register the handler and store the ID
    handlerId = AddEventHandler(event, eventFunction)
    
    -- Store in our tracking table
    _G.registeredHandlers[event] = handlerId
    
    if Config.Debug then
        print("^2[ESKUI DEBUG] Registered handler for event: " .. event .. " with ID: " .. tostring(handlerId) .. "^7")
    end
    
    -- Return the handler ID for reference
    return handlerId
end

-- Show UI with common functionality
local function showUI(type, title, data, callback)
    if display then return end
    
    setUIFocus(true)
    
    -- Send NUI message
    sendUIMessage(type, title, data)
    
    -- Register event handler for response
    local eventName = 'eskui:' .. string.sub(type, 5) .. 'Callback'
    return registerEskuiHandler(eventName, function(...)
        if callback then callback(...) end
        return true
    end)
end

-- Create generic export for common UI types
local function createUIExport(uiType, callbackProcessor)
    return function(title, data, callback, extraData)
        local uiData = {}
        
        -- Handle different parameter types based on UI type
        if uiType == 'showList' then
            uiData.items = data
            uiData.isSubmenu = #(state.menuHistory or {}) > 0
            
            -- Store this menu in state for history tracking
            state.currentMenuData = {
                title = title,
                items = data,
                callback = callback
            }
        elseif uiType == 'showDropdown' then
            uiData.options = data
            uiData.selectedIndex = extraData -- selectedIndex parameter
        end
        
        -- Show the UI
        return showUI(uiType, title, uiData, function(...)
            if callbackProcessor then
                callbackProcessor(callback, ...)
            elseif callback then
                callback(...)
            end
        end)
    end
end

-- Export UI functions with streamlined patterns
local function registerExports()
    -- Amount input
    exports('ShowAmount', function(title, callback)
        showUI('showAmount', title, {}, function(amount)
            if callback then callback(tonumber(amount)) end
        end)
    end)
    
    -- List selection - using the generic export creator
    exports('ShowList', function(title, items, callback, submenuHandler)
        -- Store the menu history for navigation
        if not state.menuHistory then state.menuHistory = {} end
        
        -- Check if this is a submenu (but not a back navigation)
        local isSubmenu = #state.menuHistory > 0
        
        -- Send items to UI
        showUI('showList', title, {items = items, isSubmenu = isSubmenu}, function(index, item)
            -- Check if this is a "back" button
            if item and item.isBack and #state.menuHistory > 0 then
                -- Get previous menu (handled by submenuBack callback)
                return
            end
            
            -- Event support
            if item and item.event then
                if item.eventType == 'server' then
                    TriggerServerEvent(item.event, table.unpack(item.args or {}))
                else
                    TriggerEvent(item.event, table.unpack(item.args or {}))
                end
            end
            
            -- Call the callback if provided
            if callback then callback(index, item) end
            
            -- Clear menu history when we make a final selection
            state.menuHistory = {}
        end)
        
        -- Store this menu in state for history tracking
        state.currentMenuData = {
            title = title,
            items = items,
            callback = callback
        }
    end)
    
    -- Dropdown selection
    exports('ShowDropdown', function(title, options, callback, selectedIndex)
        showUI('showDropdown', title, {
            options = options,
            selectedIndex = selectedIndex
        }, function(index, value)
            if callback and (index ~= nil or value ~= nil) then
                callback(index, value)
            end
        end)
    end)
    
    -- Notification system
    exports('ShowNotification', function(params)
        -- Set defaults if not provided
        local data = {
            notificationType = params.type or 'info', -- info, success, error, warning
            title = params.title or 'Notification',
            message = params.message or '',
            duration = params.duration or 5000,
            icon = params.icon,
            closable = params.closable ~= false
        }
        
        -- Send notification to UI
        sendUIMessage('showNotification', data.title, {
            notificationType = data.notificationType,
            message = data.message,
            duration = data.duration,
            icon = data.icon,
            closable = data.closable
        })
        
        -- Return notification data for potential reference
        return data
    end)
    
    -- Settings UI
    exports('ShowSettings', function()
        showUI('showSettings', 'UI Settings', {})
    end)
    
    -- Dark mode toggle
    exports('ToggleDarkMode', function()
        darkMode = not darkMode
        sendUIMessage('toggleDarkMode')
        return darkMode
    end)
    
    -- Shop UI
    exports('ShowShop', function(title, categories, items, callback)
        if Config.Debug then
            print("^4[ESKUI DEBUG] ========= SHOWSHOP EXPORT CALLED =========^7")
            print("^4[ESKUI DEBUG] Shop Title: " .. title .. "^7")
            print("^4[ESKUI DEBUG] Categories: " .. #categories .. "^7")
            print("^4[ESKUI DEBUG] Items: " .. #items .. "^7")
            print("^4[ESKUI DEBUG] Current ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
        end
        
        showUI('showShop', title, {
            categories = categories,
            items = items
        })
        
        -- Register event handler for checkout response
        local eventName = 'eskui:shopCheckoutCallback'
        
        if Config.Debug then
            print("^4[ESKUI DEBUG] Registering event handler for: " .. eventName .. "^7")
        end
        
        -- Store the handler ID in the global variable from client_shop.lua
        ShopCheckoutHandler = registerEskuiHandler(eventName, function(data)
            if Config.Debug then
                print("^4[ESKUI DEBUG] ========= SHOP CHECKOUT CALLBACK EXECUTED =========^7")
                print("^4[ESKUI DEBUG] Handler callback received data: " .. tostring(data ~= nil) .. "^7")
                if data and data.items then
                    print("^4[ESKUI DEBUG] Items in checkout: " .. #data.items .. "^7")
                end
            end
            
            if callback then callback(data) end
            
            if Config.Debug then
                print("^4[ESKUI DEBUG] Original callback executed, returning true to remove handler^7")
                print("^4[ESKUI DEBUG] ========= SHOP CHECKOUT CALLBACK COMPLETE =========^7")
            end
            
            return true -- Remove handler after callback is processed
        end)
        
        if Config.Debug then
            print("^4[ESKUI DEBUG] Registered handler with ID: " .. tostring(ShopCheckoutHandler) .. "^7")
            print("^4[ESKUI DEBUG] ========= SHOWSHOP EXPORT COMPLETE =========^7")
        end
        
        return ShopCheckoutHandler -- Return the handler ID for reference
    end)
end

-- Initialize everything
registerExports() 

-- Global key detection
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Check if the interaction key is pressed
        if IsControlJustPressed(0, Config.Interaction.key) then
            -- Only proceed if UI isn't displayed
            if not display then
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

-- Test commands for debugging
if Config.Debug then
    -- Debug command to check current UI state and handlers
    RegisterCommand('debugshop', function()
        print("^2[ESKUI DEBUG] ========= CURRENT UI STATE =========^7")
        print("^2[ESKUI DEBUG] Display: " .. tostring(display) .. "^7")
        print("^2[ESKUI DEBUG] Dark Mode: " .. tostring(darkMode) .. "^7")
        print("^2[ESKUI DEBUG] Window Opacity: " .. tostring(windowOpacity) .. "^7")
        print("^2[ESKUI DEBUG] Free Drag: " .. tostring(freeDrag) .. "^7")
        print("^2[ESKUI DEBUG] ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
        
        -- Check if any menu is open
        if state.currentMenuData then
            print("^2[ESKUI DEBUG] Current Menu: " .. (state.currentMenuData.title or "Unknown") .. "^7")
            print("^2[ESKUI DEBUG] Menu Items: " .. (state.currentMenuData.items and #state.currentMenuData.items or 0) .. "^7")
        else
            print("^2[ESKUI DEBUG] No menu currently open^7")
        end
        
        -- Check menu history
        if state.menuHistory and #state.menuHistory > 0 then
            print("^2[ESKUI DEBUG] Menu history size: " .. #state.menuHistory .. "^7")
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