local display = false
local darkMode = false

-- Helper function to handle all NUI callbacks with common logic
local function registerNUICallback(name, callback)
    RegisterNUICallback(name, function(data, cb)
        display = false
        SetNuiFocus(false, false)
        cb('ok')
        if callback then
            callback(data)
        end
    end)
end

-- Register NUI callbacks with consistent handling
registerNUICallback('amountSubmit', function(data)
    TriggerEvent('eskui:amountCallback', data.amount)
end)

registerNUICallback('listSelect', function(data)
    TriggerEvent('eskui:listCallback', data.index, data.item)
end)

registerNUICallback('close', function()
    TriggerEvent('eskui:closeCallback')
end)

registerNUICallback('dropdownSelect', function(data)
    TriggerEvent('eskui:dropdownCallback', data.index, data.value)
end)

-- Dark mode callback handler
RegisterNUICallback('darkModeChanged', function(data, cb)
    darkMode = data.darkMode
    cb('ok')
end)

-- NUI callback for server event execution (doesn't need the standard handling)
RegisterNUICallback('eskui_serverEvent', function(data, cb)
    TriggerServerEvent(data.event, table.unpack(data.args or {}))
    cb('ok')
end)

-- Register darkmode command
RegisterCommand('darkmode', function()
    darkMode = not darkMode
    SendNUIMessage({
        type = 'toggleDarkMode'
    })
    TriggerEvent('chat:addMessage', {
        color = {149, 107, 213},
        args = {"ESKUI", "Dark mode " .. (darkMode and "enabled" or "disabled")}
    })
end, false)

-- Register settings command
RegisterCommand('uisettings', function()
    SendNUIMessage({
        type = 'showSettings'
    })
    SetNuiFocus(true, true)
    display = true
end, false)

-- Add suggestion for commands
TriggerEvent('chat:addSuggestion', '/darkmode', 'Toggle ESKUI dark mode')
TriggerEvent('chat:addSuggestion', '/uisettings', 'Open ESKUI settings menu')

-- Utility to register and clean up eskui event handlers
local function registerEskuiHandler(event, handler)
    local handlerId = AddEventHandler(event, function(...)
        if handler(...) ~= false then
            RemoveEventHandler(handlerId)
        end
    end)
    return handlerId
end

-- Common function to show any UI type
local function showUI(type, title, data, callback, additionalHandler)
    if display then return end
    display = true
    SetNuiFocus(true, true)
    
    -- Prepare NUI message
    local message = {
        type = type,
        title = title
    }
    
    -- Add data parameters based on UI type
    for k, v in pairs(data or {}) do
        message[k] = v
    end
    
    -- Send message to NUI
    SendNUIMessage(message)
    
    -- Register event handler for response
    local eventName = 'eskui:' .. string.sub(type, 5) .. 'Callback'
    return registerEskuiHandler(eventName, function(...)
        if callback then
            callback(...)
        end
        return true
    end)
end

-- Export function for showing the amount input
exports('ShowAmount', function(title, callback)
    showUI('showAmount', title, {}, function(amount)
        if callback then
            callback(tonumber(amount))
        end
    end)
end)

-- Export function for showing the list
exports('ShowList', function(title, items, callback, subMenuCallback)
    showUI('showList', title, {items = items}, function(index, item)
        display = false
        SetNuiFocus(false, false)
        
        -- Event support
        if item and item.event then
            if item.eventType == 'server' then
                SendNUIMessage({
                    type = 'eskui_serverEvent',
                    event = item.event,
                    args = item.args or {}
                })
            else
                TriggerEvent(item.event, table.unpack(item.args or {}))
            end
        end
        
        -- Submenu support (submenu field)
        if item and item.submenu then
            local submenuItems = type(item.submenu) == 'function' and item.submenu() or item.submenu
            exports['eskui']:ShowList(item.label, submenuItems, callback, subMenuCallback)
            return
        end
        
        if callback then
            callback(index, item)
        end
    end)
end)

-- Export function for showing the dropdown
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

-- Export function to show the settings UI
exports('ShowSettings', function()
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showSettings'
    })
end)

-- Export function to toggle dark mode
exports('ToggleDarkMode', function()
    darkMode = not darkMode
    SendNUIMessage({
        type = 'toggleDarkMode'
    })
    return darkMode
end)

-- Test commands
RegisterCommand('testamount', function()
    exports['eskui']:ShowAmount('Enter Amount', function(amount)
        print('Amount entered: ' .. amount)
    end)
end)

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

-- Example of using submenu
RegisterCommand('testsubmenu', function()
    local items = {
        {label = 'Category 1', id = 'cat1'},
        {label = 'Category 2', id = 'cat2'},
        {label = 'Category 3', id = 'cat3'}
    }
    
    exports['eskui']:ShowList('Select Category', items, function(index, item)
        print('Final selection: ' .. item.label)
    end, function(index, item)
        -- This is the subMenuCallback
        if item.id == 'cat1' then
            return {
                title = 'Category 1 Items',
                items = {
                    {label = 'Sub Item 1', price = 100},
                    {label = 'Sub Item 2', price = 200}
                }
            }
        end
        -- Return nil for other categories to close the UI
        return nil
    end)
end)

-- Test command for dropdown
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