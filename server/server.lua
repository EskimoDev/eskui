-- NUI relay from client
RegisterNetEvent('eskui_serverEvent')
AddEventHandler('eskui_serverEvent', function(data)
    local src = source
    if type(data.event) == 'string' then
        TriggerEvent(data.event, src, table.unpack(data.args or {}))
    end
end)

-- Network test handler
RegisterNetEvent('eskui:networkTest')
AddEventHandler('eskui:networkTest', function(responseEventName)
    local src = source
    local serverTime = os.date("%H:%M:%S - %d/%m/%Y")
    
    -- Use the provided custom event name if available, otherwise use the default
    local eventToTrigger = responseEventName or 'eskui:networkTestResponse'
    TriggerClientEvent(eventToTrigger, src, serverTime)
    
    -- Debug log
    if Config and Config.Debug then
        print("[ESKUI] Handled network test from client " .. src .. ", responding with event: " .. eventToTrigger)
    end
end)

-- Print startup message
print("^2[ESKUI] Server module initialized^7") 