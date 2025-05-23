-- UI Menu System for ESKUI
-- This file contains all menu-related functions moved from client.lua

-- Global variables for UI state (accessible to other files)
Display = false
DarkMode = false
WindowOpacity = 0.95
FreeDrag = false
State = {
    menuHistory = {}
}

-- Shared checkout handler variable (kept global)
ShopCheckoutHandler = nil

-- Helper function to manage UI focus state
local function setUIFocus(show)
    Display = show
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

-- Debug printing helper function
local function debugPrint(...)
    if Config.Debug then
        print(...)
    end
end

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
        debugPrint("^2[ESKUI DEBUG] Found existing handler for event: " .. event .. "^7")
        
        -- Remove the existing handler
        RemoveEventHandler(_G.registeredHandlers[event])
        _G.registeredHandlers[event] = nil
        
        debugPrint("^2[ESKUI DEBUG] Removed existing handler for event: " .. event .. "^7")
    end
    
    -- Store handlerId in local scope before using it in the event handler
    local handlerId = nil
    
    -- Create the handler function first - add ... parameter to make it a vararg function
    local eventFunction = function(...)
        debugPrint("^2[ESKUI DEBUG] Event handler triggered for: " .. event .. "^7")
        
        local result = false
        
        -- Call the handler with pcall to catch any errors
        local success, handlerResult = pcall(function(...)
            return handler(...)
        end, ...)
        
        -- Check if handler executed successfully
        if success then
            result = handlerResult
            debugPrint("^2[ESKUI DEBUG] Handler executed successfully, result: " .. tostring(result) .. "^7")
        else
            print("^1[ESKUI ERROR] Error in event handler: " .. tostring(handlerResult) .. "^7")
        end
        
        -- If handler returned true or nil, we should remove this handler
        if result ~= false then
            -- Only try to remove if handlerId is valid
            if handlerId then
                -- Use pcall to prevent errors if removal fails
                pcall(function()
                    debugPrint("^2[ESKUI DEBUG] Removing handler for event: " .. event .. "^7")
                    
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
    
    debugPrint("^2[ESKUI DEBUG] Registered handler for event: " .. event .. " with ID: " .. tostring(handlerId) .. "^7")
    
    -- Return the handler ID for reference
    return handlerId
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
        
        -- Special case for shopCheckout callback - don't close UI
        if name == 'shopCheckout' then
            -- Keep the UI open
            setUIFocus(true)
            
            if handler then handler(data) end
            return
        end
        
        -- For regular callbacks, reset focus and close UI
        setUIFocus(false)
        
        if handler then handler(data) end
    end)
end

-- Show UI with common functionality
local function showUI(type, title, data, callback)
    if Display then return end
    
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

-- Handle submenu selection
local function handleSubmenuSelection(data)
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
        if not State.menuHistory then State.menuHistory = {} end
        if State.currentMenuData then
            table.insert(State.menuHistory, State.currentMenuData)
            print("Added current menu to history, history size: " .. #State.menuHistory)
        end
        
        -- Store current submenu data
        State.currentMenuData = {
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
end

-- Handle submenu back navigation
local function handleSubmenuBack()
    -- Debug
    print("Handling back navigation in submenu")
    
    -- Ensure UI stays visible and focused
    setUIFocus(true)
    
    -- Navigate back to previous menu if history exists
    if State.menuHistory and #State.menuHistory > 0 then
        -- Get previous menu
        local prevMenu = table.remove(State.menuHistory)
        print("Going back to menu: " .. prevMenu.title .. " with " .. #prevMenu.items .. " items")
        
        -- Update current menu data first
        State.currentMenuData = prevMenu
        
        -- Send the message 
        sendUIMessage('showList', prevMenu.title, {
            items = prevMenu.items,
            isSubmenu = #State.menuHistory > 0
        })
        
        print("Successfully navigated back to previous menu")
    else
        -- If no history left, close the menu
        print("No menu history, closing UI")
        setUIFocus(false)
        TriggerEvent('eskui:closeCallback')
    end
end

-- Handle shop checkout
local function handleShopCheckout(data)
    debugPrint("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK TRIGGERED =========^7")
    debugPrint("^6[ESKUI DEBUG] Data received from UI: " .. tostring(data ~= nil) .. "^7")
    debugPrint("^6[ESKUI DEBUG] ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
    
    -- Prevent duplicate checkout processes
    if _G.checkoutInProgress then
        debugPrint("^6[ESKUI DEBUG] Checkout already in progress, ignoring duplicate callback^7")
        debugPrint("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK IGNORED =========^7")
        return
    end
    
    -- Set checkout in progress flag
    _G.checkoutInProgress = true
    
    -- Clear the flag after timeout (consolidated to one place)
    Citizen.SetTimeout(5000, function()
        _G.checkoutInProgress = false
        debugPrint("^6[ESKUI DEBUG] Checkout in progress flag cleared after timeout^7")
    end)
    
    print("Received shop checkout callback with total: $" .. data.total)
    
    -- Add debugging to check item data
    if Config.Debug then
        debugPrint("^6[ESKUI DEBUG] Processing shop checkout with " .. #data.items .. " items^7")
        
        for i, item in ipairs(data.items) do
            debugPrint("^6[ESKUI DEBUG] Item #" .. i .. ": " .. item.id .. " x" .. item.quantity .. "^7")
            
            -- Make sure the item has the inventoryName property for the framework
            if item.inventoryName then
                debugPrint("^6[ESKUI DEBUG]   - Using inventory name: " .. item.inventoryName .. "^7")
            else
                debugPrint("^6[ESKUI DEBUG] No inventory name available for item: " .. item.id .. "^7")
            end
        end
    end
    
    -- Close UI and set focus properly
    setUIFocus(false)
    
    -- Process the shop checkout
    debugPrint("^6[ESKUI DEBUG] Triggering eskui:shopCheckoutCallback event^7")
    
    TriggerEvent('eskui:shopCheckoutCallback', data)
    
    debugPrint("^6[ESKUI DEBUG] Event triggered successfully^7")
    debugPrint("^6[ESKUI DEBUG] ShopCheckoutHandler after event: " .. tostring(ShopCheckoutHandler) .. "^7")
    debugPrint("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK COMPLETE =========^7")
end

-- Register exports
local function registerExports()
    -- Amount input
    exports('ShowAmount', function(title, callback)
        showUI('showAmount', title, {}, function(amount)
            if callback then callback(tonumber(amount)) end
        end)
    end)
    
    -- List selection
    exports('ShowList', function(title, items, callback, submenuHandler)
        -- Store the menu history for navigation
        if not State.menuHistory then State.menuHistory = {} end
        
        -- Check if this is a submenu (but not a back navigation)
        local isSubmenu = #State.menuHistory > 0
        
        -- Send items to UI
        showUI('showList', title, {items = items, isSubmenu = isSubmenu}, function(index, item)
            -- Check if this is a "back" button
            if item and item.isBack and #State.menuHistory > 0 then
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
            State.menuHistory = {}
        end)
        
        -- Store this menu in state for history tracking
        State.currentMenuData = {
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
        DarkMode = not DarkMode
        sendUIMessage('toggleDarkMode')
        return DarkMode
    end)
    
    -- Shop UI
    exports('ShowShop', function(title, categories, items, callback)
        debugPrint("^4[ESKUI DEBUG] ========= SHOWSHOP EXPORT CALLED =========^7")
        debugPrint("^4[ESKUI DEBUG] Shop Title: " .. title .. "^7")
        debugPrint("^4[ESKUI DEBUG] Categories: " .. #categories .. "^7")
        debugPrint("^4[ESKUI DEBUG] Items: " .. #items .. "^7")
        debugPrint("^4[ESKUI DEBUG] Current ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
        
        showUI('showShop', title, {
            categories = categories,
            items = items
        })
        
        -- Register event handler for checkout response
        local eventName = 'eskui:shopCheckoutCallback'
        
        debugPrint("^4[ESKUI DEBUG] Registering event handler for: " .. eventName .. "^7")
        
        -- Store the handler ID in the global variable from client_shop.lua
        ShopCheckoutHandler = registerEskuiHandler(eventName, function(data)
            debugPrint("^4[ESKUI DEBUG] ========= SHOP CHECKOUT CALLBACK EXECUTED =========^7")
            debugPrint("^4[ESKUI DEBUG] Handler callback received data: " .. tostring(data ~= nil) .. "^7")
            if data and data.items then
                debugPrint("^4[ESKUI DEBUG] Items in checkout: " .. #data.items .. "^7")
            end
            
            if callback then callback(data) end
            
            debugPrint("^4[ESKUI DEBUG] Original callback executed, returning true to remove handler^7")
            debugPrint("^4[ESKUI DEBUG] ========= SHOP CHECKOUT CALLBACK COMPLETE =========^7")
            
            return true -- Remove handler after callback is processed
        end)
        
        debugPrint("^4[ESKUI DEBUG] Registered handler with ID: " .. tostring(ShopCheckoutHandler) .. "^7")
        debugPrint("^4[ESKUI DEBUG] ========= SHOWSHOP EXPORT COMPLETE =========^7")
        
        return ShopCheckoutHandler -- Return the handler ID for reference
    end)
end

-- Register all callback handlers
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
        DarkMode = data.darkMode 
        -- Trigger event for other modules
        TriggerEvent('eskui:darkModeChanged', DarkMode)
    end,
    opacityChanged = function(data) WindowOpacity = data.windowOpacity end,
    freeDragChanged = function(data) FreeDrag = data.freeDrag end,
    close = function() 
        setUIFocus(false)
        TriggerEvent('eskui:closeCallback')
    end,
    shopCheckout = handleShopCheckout,
    submenuSelect = handleSubmenuSelection,
    submenuBack = handleSubmenuBack
}

-- Register all callbacks
for name, handler in pairs(callbacks) do
    handleNUICallback(name, handler)
end

-- Initialize exports and commands
registerExports()

-- Provide a function to get the dark mode state
function GetDarkMode()
    return DarkMode
end

-- Provide a function to check if UI is displayed
function IsUIDisplayed()
    return Display
end 