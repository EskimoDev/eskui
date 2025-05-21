-- Test commands for ESKUI
-- This file contains all test commands for the UI framework

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

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/testamount', 'Test ESKUI amount input')
TriggerEvent('chat:addSuggestion', '/testlist', 'Test ESKUI list selection')
TriggerEvent('chat:addSuggestion', '/testdropdown', 'Test ESKUI dropdown menu')
TriggerEvent('chat:addSuggestion', '/testsubmenu', 'Test ESKUI submenu functionality')
TriggerEvent('chat:addSuggestion', '/notify', 'Show a test notification', {
    { name = "type", help = "Notification type (info, success, error, warning)" }
}) 