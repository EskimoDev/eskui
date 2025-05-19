local display = false

-- Register the NUI callback for amount input
RegisterNUICallback('amountSubmit', function(data, cb)
    display = false
    SetNuiFocus(false, false)
    cb('ok')
    TriggerEvent('eskui:amountCallback', data.amount)
end)

-- Register the NUI callback for list selection
RegisterNUICallback('listSelect', function(data, cb)
    cb('ok')
    TriggerEvent('eskui:listCallback', data.index, data.item)
end)

-- Register the NUI callback for closing
RegisterNUICallback('close', function(data, cb)
    display = false
    SetNuiFocus(false, false)
    cb('ok')
    TriggerEvent('eskui:closeCallback')
end)

-- Register the NUI callback for dropdown selection
RegisterNUICallback('dropdownSelect', function(data, cb)
    display = false
    SetNuiFocus(false, false)
    cb('ok')
    TriggerEvent('eskui:dropdownCallback', data.index, data.value)
end)

-- NUI callback for server event execution
RegisterNUICallback('eskui_serverEvent', function(data, cb)
    TriggerServerEvent(data.event, table.unpack(data.args or {}))
    cb('ok')
end)

-- Utility to register and clean up eskui event handlers
local function registerEskuiHandler(event, handler)
    local handlerId
    handlerId = AddEventHandler(event, function(...)
        if handler(...) ~= false then
            if handlerId then RemoveEventHandler(handlerId) end
        end
    end)
    return handlerId
end

-- Export function for showing the amount input
exports('ShowAmount', function(title, callback)
    if display then return end
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "showAmount",
        title = title
    })
    RegisterNetEvent('eskui:amountCallback')
    AddEventHandler('eskui:amountCallback', function(amount)
        RemoveEventHandler('eskui:amountCallback')
        if callback then
            callback(tonumber(amount))
        end
        -- If no callback, just close (already closed by NUI callback)
    end)
end)

-- Export function for showing the list (with event, submenu, and optional fields support)
exports('ShowList', function(title, items, callback, subMenuCallback)
    if display then return end
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "showList",
        title = title,
        items = items
    })
    local handlerId
    handlerId = AddEventHandler('eskui:listCallback', function(index, item)
        if handlerId then RemoveEventHandler(handlerId) end
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
    if display then return end
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "showDropdown",
        title = title,
        options = options,
        selectedIndex = selectedIndex
    })
    local handlerId
    handlerId = AddEventHandler('eskui:dropdownCallback', function(index, value)
        if handlerId then RemoveEventHandler(handlerId) end
        display = false
        SetNuiFocus(false, false)
        if callback and (index ~= nil or value ~= nil) then
            callback(index, value)
        end
        -- If no callback or no data, just close (already closed by NUI callback)
    end)
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