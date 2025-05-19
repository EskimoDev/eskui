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
    display = false
    SetNuiFocus(false, false)
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
        callback(tonumber(amount))
    end)
end)

-- Export function for showing the list
exports('ShowList', function(title, items, callback)
    if display then return end
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "showList",
        title = title,
        items = items
    })
    
    RegisterNetEvent('eskui:listCallback')
    AddEventHandler('eskui:listCallback', function(index, item)
        RemoveEventHandler('eskui:listCallback')
        callback(index, item)
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
        {label = 'Item 3', price = 300},
        {label = 'Item 4', price = 400},
        {label = 'Item 5', price = 500}
    }
    
    exports['eskui']:ShowList('Select an Item', items, function(index, item)
        print('Selected item: ' .. item.label .. ' at index ' .. index)
    end)
end) 