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

-- Test shopping UI
RegisterCommand('testshop', function()
    local categories = {
        {id = 'weapons', label = 'Weapons', icon = '🔫'},
        {id = 'clothing', label = 'Clothing', icon = '👕'},
        {id = 'food', label = 'Food', icon = '🍔'},
        {id = 'drinks', label = 'Drinks', icon = '🥤'},
        {id = 'misc', label = 'Miscellaneous', icon = '📦'}
    }
    
    local items = {
        -- Weapons
        {id = 'pistol', name = 'Pistol', price = 1000, category = 'weapons', icon = '🔫', description = 'Standard issue pistol'},
        {id = 'rifle', name = 'Rifle', price = 5000, category = 'weapons', icon = '🔫', description = 'Military grade assault rifle'},
        {id = 'shotgun', name = 'Shotgun', price = 3500, category = 'weapons', icon = '🔫', description = 'Close range weapon'},
        
        -- Clothing
        {id = 'tshirt', name = 'T-Shirt', price = 50, category = 'clothing', icon = '👕', description = 'Basic cotton t-shirt'},
        {id = 'jeans', name = 'Jeans', price = 75, category = 'clothing', icon = '👖', description = 'Denim jeans'},
        {id = 'hat', name = 'Hat', price = 25, category = 'clothing', icon = '🧢', description = 'Baseball cap'},
        
        -- Food
        {id = 'burger', name = 'Burger', price = 10, category = 'food', icon = '🍔', description = 'Juicy beef burger'},
        {id = 'pizza', name = 'Pizza', price = 12, category = 'food', icon = '🍕', description = 'Pepperoni pizza slice'},
        {id = 'taco', name = 'Taco', price = 8, category = 'food', icon = '🌮', description = 'Crunchy beef taco'},
        
        -- Drinks
        {id = 'water', name = 'Water', price = 3, category = 'drinks', icon = '💧', description = 'Refreshing water bottle'},
        {id = 'cola', name = 'Cola', price = 5, category = 'drinks', icon = '🥤', description = 'Fizzy cola drink'},
        {id = 'coffee', name = 'Coffee', price = 6, category = 'drinks', icon = '☕', description = 'Hot coffee'},
        
        -- Misc
        {id = 'phone', name = 'Phone', price = 1000, category = 'misc', icon = '📱', description = 'Smartphone'},
        {id = 'laptop', name = 'Laptop', price = 3000, category = 'misc', icon = '💻', description = 'Portable computer'},
        {id = 'watch', name = 'Watch', price = 500, category = 'misc', icon = '⌚', description = 'Digital watch'}
    }
    
    exports['eskui']:ShowShop('General Store', categories, items, function(data)
        if data then
            print('Checkout completed:')
            print('Total: $' .. data.total)
            for i, item in ipairs(data.items) do
                print(('- %s x%d ($%d each)'):format(item.id, item.quantity, item.price))
            end
            
            -- Show a notification
            exports['eskui']:ShowNotification({
                type = 'success',
                title = 'Purchase Successful',
                message = ('You spent $%s on %d items'):format(data.total, #data.items),
                duration = 5000
            })
        end
    end)
end, false)

-- Test banking UI
RegisterCommand('testbanking', function()
    -- We'll use realistic banking data for testing
    local bankingData = {
        bankName = 'First National Bank',
        accountHolder = 'John Doe',
        accountNumber = '****-****-1234',
        cash = 1250.75,
        bank = 15420.50,
        transactions = {
            { type = 'deposit', amount = 2500.00, date = 'Today, 2:30 PM', description = 'Salary Deposit', category = 'income' },
            { type = 'withdraw', amount = 350.00, date = 'Today, 10:15 AM', description = 'ATM Withdrawal', category = 'cash' },
            { type = 'transfer', amount = 500.00, date = 'Yesterday, 6:45 PM', description = 'Transfer to John Smith', category = 'transfer' },
            { type = 'deposit', amount = 150.25, date = 'Yesterday, 2:20 PM', description = 'Refund - Store Purchase', category = 'refund' },
            { type = 'withdraw', amount = 75.50, date = '2 days ago, 8:30 AM', description = 'Coffee Shop Payment', category = 'food' },
            { type = 'deposit', amount = 1200.00, date = '3 days ago, 4:15 PM', description = 'Freelance Payment', category = 'income' },
            { type = 'withdraw', amount = 200.00, date = '4 days ago, 11:45 AM', description = 'Gas Station', category = 'transport' },
            { type = 'transfer', amount = 300.00, date = '5 days ago, 7:20 PM', description = 'Rent Payment', category = 'bills' }
        }
    }
    
    -- Open the banking UI
    SendNUIMessage({
        type = 'showBanking',
        data = bankingData
    })
    
    -- Set NUI focus
    SetNuiFocus(true, true)
    
    print("^2[ESKUI] Banking UI opened with test data^7")
end, false)

-- Register NUI callback for banking actions
RegisterNUICallback('bankingAction', function(data, cb)
    if data.action and data.amount then
        -- Log the banking action for testing
        print(string.format("Banking action: %s amount: $%s", data.action, data.amount))
        
        -- Show feedback in chat
        TriggerEvent('chat:addMessage', {
            color = {149, 107, 213},
            args = {"ESKUI Banking", string.format("%s: $%s", 
                data.action:gsub("^%l", string.upper), -- Capitalize first letter
                data.amount
            )}
        })
        
        -- In a real implementation, this would call server-side events to handle the banking action
        
        -- Respond to the callback
        cb({ success = true })
    else
        cb({ success = false, message = "Invalid banking action data" })
    end
end)

-- Register NUI callback for closing the banking UI
RegisterNUICallback('close', function(data, cb)
    -- Reset NUI focus when UI is closed
    SetNuiFocus(false, false)
    cb({})
end)

-- Test banking transfer UI
RegisterCommand('testtransfer', function()
    -- Hide banking UI if it's open
    SendNUIMessage({type = 'hide', containerId = 'banking-ui'})
    
    -- Wait a moment to ensure UI is properly hidden
    Citizen.Wait(100)
    
    -- Show the transfer UI directly
    SendNUIMessage({
        type = 'showBanking',
        data = {
            bankName = 'First National Bank',
            accountHolder = 'John Doe',
            accountNumber = '****-****-1234',
            cash = 1250.75,
            bank = 15420.50
        }
    })
    
    -- Set NUI focus
    SetNuiFocus(true, true)
    
    -- Wait a moment to ensure banking UI is shown
    Citizen.Wait(300)
    
    -- Directly trigger the transfer UI display
    SendNUIMessage({
        type = 'triggerTransfer'
    })
    
    print("^2[ESKUI] Banking Transfer UI opened with test data^7")
end, false)

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/testamount', 'Test ESKUI amount input')
TriggerEvent('chat:addSuggestion', '/testlist', 'Test ESKUI list selection')
TriggerEvent('chat:addSuggestion', '/testdropdown', 'Test ESKUI dropdown menu')
TriggerEvent('chat:addSuggestion', '/testsubmenu', 'Test ESKUI submenu functionality')
TriggerEvent('chat:addSuggestion', '/notify', 'Show a test notification', {
    { name = "type", help = "Notification type (info, success, error, warning)" }
})
TriggerEvent('chat:addSuggestion', '/testshop', 'Test ESKUI shop interface')
TriggerEvent('chat:addSuggestion', '/testbanking', 'Test ESKUI banking interface')
TriggerEvent('chat:addSuggestion', '/testtransfer', 'Test ESKUI banking transfer interface') 