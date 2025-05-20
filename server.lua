-- NUI relay from client
RegisterNUICallback('eskui_serverEvent', function(data, cb)
    local src = source
    if type(data.event) == 'string' then
        TriggerEvent(data.event, src, table.unpack(data.args or {}))
    end
    cb('ok')
end) 