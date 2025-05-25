-- ATM Interaction
local atmModels = {
    prop_atm_01 = GetHashKey("prop_atm_01"),
    prop_atm_02 = GetHashKey("prop_atm_02"),
    prop_atm_03 = GetHashKey("prop_atm_03"),
    prop_fleeca_atm = GetHashKey("prop_fleeca_atm")
}

local nearbyATM = nil
local interactionDistance = 1.5
local atmInteractionRegistered = false

-- Function to check if player is near and aiming at an ATM
function IsLookingAtATM()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    
    -- Get entity player is looking at
    local inFrontOfPlayer = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        playerCoords.x, playerCoords.y, playerCoords.z,
        inFrontOfPlayer.x, inFrontOfPlayer.y, inFrontOfPlayer.z,
        16, -- Filter for props only
        ped,
        4
    )
    
    -- Get results of raycast
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    
    if hit and entityHit ~= 0 then
        local entityModel = GetEntityModel(entityHit)
        
        -- Check if the entity is an ATM
        for atmName, atmHash in pairs(atmModels) do
            if entityModel == atmHash then
                -- Check distance to ATM
                local atmCoords = GetEntityCoords(entityHit)
                local distance = #(playerCoords - atmCoords)
                
                if distance <= interactionDistance then
                    return true, entityHit, atmCoords
                end
            end
        end
    end
    
    return false, nil, nil
end

-- Function to use the ATM
function UseATM()
    -- For now, just show a notification (placeholder)
    -- Using eskUI's notification system directly
    exports['eskui']:ShowNotification({
        type = 'info',
        title = 'ATM',
        message = 'You have accessed the ATM. Balance: $' .. math.random(100, 5000),
        duration = 3000
    })
    
    -- Here you would typically trigger your ATM menu or other ATM functionality
    -- This is a placeholder
    
    -- Add a small delay to prevent immediate re-interaction
    Citizen.Wait(1000)
    
    return false -- Don't remove the interaction
end

-- Register ATM interactions with the system
Citizen.CreateThread(function()
    -- Wait for framework to initialize
    while not Framework or not Framework.IsInitialized() do
        Citizen.Wait(500)
    end
    
    -- Register ATM interactions only once
    if not atmInteractionRegistered then
        -- Start the detection thread
        StartATMDetectionThread()
        
        atmInteractionRegistered = true
        
        if Config.Debug then
            print("^2[ESKUI] ATM interaction system initialized^7")
        end
    end
end)

-- Thread to detect ATMs and create dynamic interaction zones
function StartATMDetectionThread()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500) -- Check every half second
            
            local isLookingAtATM, atmEntity, atmCoords = IsLookingAtATM()
            
            if isLookingAtATM and not nearbyATM then
                -- Create a temporary interaction for this specific ATM
                local atmId = "atm_" .. atmEntity
                
                -- Register the interaction with the system
                local atmConfig = {
                    textLeft = "Press",
                    textRight = "to use ATM"
                }
                
                -- Use the existing InteractionPrompt.Register function from client_interaction.lua
                exports.eskui:RegisterInteraction(
                    atmId,
                    atmCoords,
                    interactionDistance,
                    atmConfig,
                    UseATM
                )
                
                nearbyATM = atmEntity
                
                -- Manually check for nearby interactions to show the prompt immediately
                exports.eskui:CheckForNearbyAndShow()
                
                if Config.Debug then
                    print("^2[ESKUI] ATM interaction registered for entity: " .. atmEntity .. "^7")
                end
            elseif not isLookingAtATM and nearbyATM then
                -- Reset ATM state
                nearbyATM = nil
            end
        end
    end)
end

-- Debug command to test ATM detection
if Config.Debug then
    RegisterCommand('testatm', function()
        local isLookingAtATM, atmEntity, atmCoords = IsLookingAtATM()
        if isLookingAtATM then
            -- Using eskUI's notification system directly
            exports['eskui']:ShowNotification({
                type = 'success',
                title = 'ATM Detected',
                message = 'Found ATM entity: ' .. atmEntity,
                duration = 3000
            })
        else
            -- Using eskUI's notification system directly
            exports['eskui']:ShowNotification({
                type = 'error',
                title = 'No ATM Found',
                message = 'You are not looking at an ATM',
                duration = 3000
            })
        end
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/testatm', 'Test if you are looking at an ATM')
end 