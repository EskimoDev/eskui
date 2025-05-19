local isUIOpen = false

-- Show a list of options
function ShowList(title, options, callback)
    if isUIOpen then return end
    isUIOpen = true
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showList',
        title = title,
        options = options
    })

    -- Handle NUI callbacks
    RegisterNUICallback('select', function(data, cb)
        isUIOpen = false
        SetNuiFocus(false, false)
        if callback then
            callback(data)
        end
        cb('ok')
    end)

    RegisterNUICallback('cancel', function(data, cb)
        isUIOpen = false
        SetNuiFocus(false, false)
        if callback then
            callback(nil)
        end
        cb('ok')
    end)
end

-- Show amount selector
function ShowAmount(title, initialAmount, callback)
    if isUIOpen then return end
    isUIOpen = true
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showAmount',
        title = title,
        initialAmount = initialAmount or 1
    })

    -- Handle NUI callbacks
    RegisterNUICallback('amount', function(data, cb)
        isUIOpen = false
        SetNuiFocus(false, false)
        if callback then
            callback(data)
        end
        cb('ok')
    end)

    RegisterNUICallback('cancel', function(data, cb)
        isUIOpen = false
        SetNuiFocus(false, false)
        if callback then
            callback(nil)
        end
        cb('ok')
    end)
end

-- Hide UI
function HideUI()
    if not isUIOpen then return end
    isUIOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hide'
    })
end

-- Export functions for other resources
exports('ShowList', ShowList)
exports('ShowAmount', ShowAmount)
exports('HideUI', HideUI)

-- Example usage:
--[[
    -- Show a list
    exports['eskui']:ShowList('Select an option', {'Option 1', 'Option 2', 'Option 3'}, function(selected)
        if selected then
            print('Selected option:', selected)
        else
            print('Cancelled')
        end
    end)

    -- Show amount selector
    exports['eskui']:ShowAmount('Select amount', 1, function(amount)
        if amount then
            print('Selected amount:', amount)
        else
            print('Cancelled')
        end
    end)
]] 