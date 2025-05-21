local display = false
local darkMode = false
local windowOpacity = 0.95
local freeDrag = false
local state = {
    menuHistory = {}
}

-- Common NUI callback handling
local function handleNUICallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        print("Received NUI callback: " .. name)
        
        -- Always acknowledge the callback first to avoid NUI freezes
        cb('ok')
        
        -- For submenu navigation, don't reset focus
        if name == 'submenuSelect' or name == 'submenuBack' then
            -- Make sure display stays true to maintain UI visibility
            display = true
            SetNuiFocus(true, true)
            
            if handler then 
                -- Run the callback handler with the data
                handler(data)
            end
            return
        end
        
        -- For regular callbacks, reset focus and close UI
        display = false
        SetNuiFocus(false, false)
        
        if handler then handler(data) end
    end)
end

-- Register standard callbacks with common pattern
local callbacks = {
    amountSubmit = function(data) TriggerEvent('eskui:amountCallback', data.amount) end,
    listSelect = function(data) TriggerEvent('eskui:listCallback', data.index, data.item) end,
    close = function() TriggerEvent('eskui:closeCallback') end,
    dropdownSelect = function(data) TriggerEvent('eskui:dropdownCallback', data.index, data.value) end,
    darkModeChanged = function(data) darkMode = data.darkMode end,
    opacityChanged = function(data) windowOpacity = data.windowOpacity end,
    freeDragChanged = function(data) freeDrag = data.freeDrag end,
    submenuSelect = function(data) 
        -- Debug
        print("Handling submenu selection for item: " .. (data.item.label or "unknown"))
        
        -- IMPORTANT: Explicitly set UI state to shown
        display = true
        SetNuiFocus(true, true)
        
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
            
            -- Ensure submenuItems is a valid table
            if submenuItems == nil then
                print("ERROR: Submenu items is nil - creating empty table")
                submenuItems = {}
            elseif type(submenuItems) ~= 'table' then
                print("ERROR: Submenu items is not a table, type: " .. type(submenuItems))
                submenuItems = {}
            end
            
            -- Add a back button if not already present
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
            
            -- Store current menu in history for back navigation
            if not state.menuHistory then state.menuHistory = {} end
            if state.currentMenuData then
                table.insert(state.menuHistory, state.currentMenuData)
                print("Added current menu to history, history size: " .. #state.menuHistory)
            end
            
            -- Print debug info about the submenu items
            print("Submenu items count: " .. #submenuItems)
            for i, item in ipairs(submenuItems) do
                print("  Item " .. i .. ": " .. (item.label or "no label"))
            end
            
            -- Important: We need to create a proper NUI message with all fields
            local message = {
                type = 'showList',
                title = data.item.label,
                items = submenuItems,
                isSubmenu = true
            }
            print("Sending submenu NUI message - submenuItems count: " .. #submenuItems)
            
            -- Store current submenu data
            state.currentMenuData = {
                title = data.item.label,
                items = submenuItems,
                parentIndex = data.index
            }
            
            -- Show the submenu with a short delay
            Citizen.CreateThread(function()
                Citizen.Wait(50)
                
                -- Double check we're still in display mode (a safeguard)
                if not display then
                    print("WARNING: display was set to false before submenu could be shown")
                    display = true
                    SetNuiFocus(true, true)
                end
                
                -- Send the message and ensure focus
                SendNUIMessage(message)
                SetNuiFocus(true, true)
                
                -- Debug
                print("Showing submenu: " .. data.item.label .. " with " .. #submenuItems .. " items")
            end)
        else
            print("ERROR: Submenu selection with no submenu data")
        end
    end,
    submenuBack = function()
        -- Debug
        print("Handling back navigation in submenu")
        
        -- Ensure UI stays visible and focused
        display = true
        SetNuiFocus(true, true)
        
        -- Navigate back to previous menu if history exists
        if state.menuHistory and #state.menuHistory > 0 then
            -- Get previous menu
            local prevMenu = table.remove(state.menuHistory)
            print("Going back to menu: " .. prevMenu.title .. " with " .. #prevMenu.items .. " items")
            
            -- Create a proper NUI message with all fields
            local message = {
                type = 'showList',
                title = prevMenu.title,
                items = prevMenu.items,
                isSubmenu = #state.menuHistory > 0
            }
            
            -- Update current menu data first
            state.currentMenuData = prevMenu
            
            -- Important: Show previous menu with a short delay
            Citizen.CreateThread(function()
                Citizen.Wait(50)
                
                -- Double check we're still in display mode (a safeguard)
                if not display then
                    print("WARNING: display was set to false before previous menu could be shown")
                    display = true
                    SetNuiFocus(true, true)
                end
                
                -- Send the message and ensure focus
                SendNUIMessage(message)
                SetNuiFocus(true, true)
                
                print("Successfully navigated back to previous menu")
            end)
        else
            -- If no history left, close the menu
            print("No menu history, closing UI")
            display = false
            SetNuiFocus(false, false)
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
    SendNUIMessage({type = 'toggleDarkMode'})
    TriggerEvent('chat:addMessage', {
        color = {149, 107, 213},
        args = {"ESKUI", "Dark mode " .. (darkMode and "enabled" or "disabled")}
    })
end, false)

RegisterCommand('uisettings', function()
    SendNUIMessage({type = 'showSettings'})
    SetNuiFocus(true, true)
    display = true
end, false)

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/darkmode', 'Toggle ESKUI dark mode')
TriggerEvent('chat:addSuggestion', '/uisettings', 'Open ESKUI settings menu')

-- Handler registration with automatic cleanup
local function registerEskuiHandler(event, handler)
    local handlerId = AddEventHandler(event, function(...)
        if handler(...) ~= false then RemoveEventHandler(handlerId) end
    end)
    return handlerId
end

-- Show UI with common functionality
local function showUI(type, title, data, callback)
    if display then return end
    
    display = true
    SetNuiFocus(true, true)
    
    -- Prepare and send NUI message
    local message = {type = type, title = title}
    for k, v in pairs(data or {}) do message[k] = v end
    SendNUIMessage(message)
    
    -- Register event handler for response
    local eventName = 'eskui:' .. string.sub(type, 5) .. 'Callback'
    return registerEskuiHandler(eventName, function(...)
        if callback then callback(...) end
        return true
    end)
end

-- Export UI functions with streamlined patterns
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
        if not state.menuHistory then state.menuHistory = {} end
        
        -- Check if this is a submenu (but not a back navigation, which gets handled separately)
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
        SendNUIMessage({
            type = 'showNotification',
            notificationType = data.notificationType,
            title = data.title,
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
        SendNUIMessage({type = 'toggleDarkMode'})
        return darkMode
    end)
end

-- Register test commands
local function registerTestCommands()
    -- Test amount input
    RegisterCommand('testamount', function()
        exports['eskui']:ShowAmount('Enter Amount', function(amount)
            print('Amount entered: ' .. amount)
        end)
    end)
    
    -- Test list selection
    RegisterCommand('testlist', function()
        local items = {
            {label = 'Item 1', price = 100},
            {label = 'Item 2', price = 200},
            {label = 'This is a very long item name that will trigger the scrolling text effect when hovered over', price = 300},
            {label = 'Item 4', price = 400},
            {label = 'Item 5', price = 500}
        }
        
        exports['eskui']:ShowList('Select an Item', items, function(index, item)
            print('Selected item: ' .. item.label .. ' at index ' .. index)
        end)
    end)
    
    -- Test dropdown
    RegisterCommand('testdropdown', function()
        local options = {
            'Option 1',
            'Option 2',
            'Option 3',
            'A very long dropdown option that will be truncated',
            'Option 5'
        }
        exports['eskui']:ShowDropdown('Select a Dropdown Option', options, function(index, value)
            if index ~= nil and value ~= nil then
                print(('Dropdown selected: %s (index %d)'):format(value, index))
            else
                print('Dropdown cancelled or no selection made.')
            end
        end)
    end)
    
    -- Test submenu list
    RegisterCommand('testsubmenu', function()
        local mainMenu = {
            {label = 'Food', icon = '🍔', submenu = {
                {label = 'Burger', price = 10, description = 'Delicious burger'},
                {label = 'Pizza', price = 15, description = 'Tasty pizza'},
                {label = 'Salad', price = 8, description = 'Healthy option'},
                {label = 'Back', isBack = true, icon = '⬅️'}
            }},
            {label = 'Drinks', icon = '🥤', submenu = function()
                -- Example of dynamic submenu using function
                return {
                    {label = 'Soda', price = 3, description = 'Refreshing drink'},
                    {label = 'Water', price = 1, description = 'Stay hydrated'},
                    {label = 'Coffee', price = 5, description = 'Wake up!'},
                    {label = 'Back', isBack = true, icon = '⬅️'}
                }
            end},
            {label = 'Desserts', icon = '🍦', submenu = {
                {label = 'Ice Cream', price = 6, description = 'Cold and sweet'},
                {label = 'Cake', price = 7, description = 'Slice of heaven'},
                {label = 'Back', isBack = true, icon = '⬅️'}
            }},
            {label = 'Exit', description = 'Close the menu'}
        }
        
        -- Debug print the menu structure
        print("Main menu items count: " .. #mainMenu)
        for i, item in ipairs(mainMenu) do
            print("Item " .. i .. ": " .. item.label)
            if item.submenu then
                print("  Has submenu: " .. type(item.submenu))
                if type(item.submenu) == 'table' then
                    print("  Submenu items: " .. #item.submenu)
                    for j, subitem in ipairs(item.submenu) do
                        print("    Subitem " .. j .. ": " .. subitem.label)
                    end
                end
            end
        end
        
        -- Show the menu
        exports['eskui']:ShowList('Restaurant Menu', mainMenu, function(index, item)
            if item and item.price then
                print(('Selected: %s for $%s'):format(item.label, item.price))
                TriggerEvent('chat:addMessage', {
                    color = {149, 107, 213},
                    args = {"ESKUI", ('You ordered: %s for $%s'):format(item.label, item.price)}
                })
            end
        end)
    end)
    
    -- Test notifications
    RegisterCommand('notify', function(source, args, rawCommand)
        local type = args[1] or 'info'
        
        -- Default messages based on notification type
        local titles = {
            info = 'Information',
            success = 'Success',
            error = 'Error',
            warning = 'Warning'
        }
        
        local messages = {
            info = 'This is an information notification.',
            success = 'The operation was completed successfully!',
            warning = 'Please be cautious with this action.',
            error = 'An error occurred while processing your request.'
        }
        
        -- Validate type
        if not titles[type] then
            type = 'info'
        end
        
        -- Debug output
        print('Showing notification of type: ' .. type)
        
        exports['eskui']:ShowNotification({
            type = type,
            title = titles[type],
            message = messages[type],
            duration = 5000
        })
        
        -- Show syntax help if no args
        if #args == 0 then
            TriggerEvent('chat:addMessage', {
                color = {149, 107, 213},
                args = {"ESKUI", "Notification syntax: /notify [type]\nTypes: info, success, error, warning"}
            })
        end
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/testsubmenu', 'Test ESKUI submenu functionality')
    TriggerEvent('chat:addSuggestion', '/notify', 'Show a test notification', {
        { name = "type", help = "Notification type (info, success, error, warning)" }
    })
end

-- Initialize everything
registerExports()
registerTestCommands() 