local display = false
local darkMode = false
local windowOpacity = 0.95
local freeDrag = false

-- Common NUI callback handling
local function handleNUICallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        display = false
        SetNuiFocus(false, false)
        cb('ok')
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
    freeDragChanged = function(data) freeDrag = data.freeDrag end
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
    exports('ShowList', function(title, items, callback, subMenuCallback)
        showUI('showList', title, {items = items}, function(index, item)
            -- Event support
            if item and item.event then
                if item.eventType == 'server' then
                    TriggerServerEvent(item.event, table.unpack(item.args or {}))
                else
                    TriggerEvent(item.event, table.unpack(item.args or {}))
                end
            end
            
            -- Submenu support
            if item and item.submenu then
                local submenuItems = type(item.submenu) == 'function' and item.submenu() or item.submenu
                exports['eskui']:ShowList(item.label, submenuItems, callback, subMenuCallback)
                return
            end
            
            if callback then callback(index, item) end
        end)
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
    
    -- Test submenu
    RegisterCommand('testsubmenu', function()
        local items = {
            {label = 'Category 1', id = 'cat1'},
            {label = 'Category 2', id = 'cat2'},
            {label = 'Category 3', id = 'cat3'}
        }
        
        exports['eskui']:ShowList('Select Category', items, function(index, item)
            print('Final selection: ' .. item.label)
        end, function(index, item)
            if item.id == 'cat1' then
                return {
                    title = 'Category 1 Items',
                    items = {
                        {label = 'Sub Item 1', price = 100},
                        {label = 'Sub Item 2', price = 200}
                    }
                }
            end
            return nil
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
end

-- Initialize everything
registerExports()
registerTestCommands() 