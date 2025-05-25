-- Framework integration for eskui shop system
Framework = {}
local PlayerData = {}
local FrameworkInitialized = false
local FrameworkName = nil
local InitializationInProgress = false

-- Framework initialization event
RegisterNetEvent('eskui:frameworkReady')
AddEventHandler('eskui:frameworkReady', function()
    if not FrameworkInitialized then
        FrameworkInitialized = true
        print("^2[ESKUI] Framework initialized through event notification^7")
        
        -- Update player data when framework is ready
        if FrameworkName == 'esx' and ESX then
            PlayerData = ESX.GetPlayerData()
        elseif FrameworkName == 'qbcore' and QBCore then
            PlayerData = QBCore.Functions.GetPlayerData()
        end
    end
end)

-- Get framework name from config
function Framework.GetFrameworkName()
    if not Config then
        return nil
    end
    return Config.Framework
end

-- Initialize the framework
function Framework.Initialize(callback)
    -- Prevent multiple initialization attempts running simultaneously
    if InitializationInProgress then
        if callback then
            -- If there's already an initialization in progress and a callback was provided,
            -- wait until the framework is ready before executing the callback
            Citizen.CreateThread(function()
                while not FrameworkInitialized do
                    Citizen.Wait(100)
                end
                callback()
            end)
        end
        return
    end
    
    InitializationInProgress = true
    
    -- Check if config is loaded
    if not Config then
        print("^1[ESKUI] ERROR: Config not found. Make sure config.lua is loaded correctly.^7")
        InitializationInProgress = false
        return
    end
    
    -- Check framework setting
    if not Config.Framework then
        print("^1[ESKUI] ERROR: Config.Framework is nil. Check your config.lua file.^7")
        InitializationInProgress = false
        return
    end
    
    FrameworkName = Config.Framework
    
    if FrameworkName == 'esx' then
        print("[ESKUI] Initializing ESX framework...")
        
        -- Use TriggerEvent to let the server know we're trying to initialize
        TriggerEvent('eskui:initializingFramework', 'esx')
        
        -- Attempt to initialize ESX
        Citizen.CreateThread(function()
            -- Wait for ESX to be available using a more efficient waiting pattern
            local initialWaitTime = 100 -- Start with shorter waits
            local maxWaitTime = 2000 -- Max wait between attempts
            local waitTime = initialWaitTime
            local attempts = 0
            local maxAttempts = 30 -- About 30 seconds total with increasing waits
            
            while attempts < maxAttempts do
                -- Try to get ESX using exports
                local esxSuccess = pcall(function()
                    ESX = exports['es_extended']:getSharedObject()
                    return ESX ~= nil
                end)
                
                if esxSuccess and ESX then
                    print("^2[ESKUI] ESX framework found^7")
                    
                    -- Check if player is already loaded
                    if ESX.GetPlayerData().identifier ~= nil then
                        PlayerData = ESX.GetPlayerData()
                        FrameworkInitialized = true
                        print("^2[ESKUI] ESX Framework fully initialized with player data^7")
                        
                        -- Register job update event
                        RegisterNetEvent('esx:setJob')
                        AddEventHandler('esx:setJob', function(job)
                            if PlayerData then
                                PlayerData.job = job
                            end
                        end)
                        
                        InitializationInProgress = false
                        if callback then callback() end
                        TriggerEvent('eskui:frameworkReady')
                        return
                    else
                        -- Set up player loaded event for first load
                        RegisterNetEvent('esx:playerLoaded')
                        AddEventHandler('esx:playerLoaded', function(xPlayer)
                            PlayerData = xPlayer
                            FrameworkInitialized = true
                            print("^2[ESKUI] ESX Framework fully initialized on player loaded^7")
                            
                            InitializationInProgress = false
                            if callback then callback() end
                            TriggerEvent('eskui:frameworkReady')
                        end)
                        
                        -- Double check after a short delay (for cases where playerLoaded might have been missed)
                        Citizen.SetTimeout(3000, function()
                            if not FrameworkInitialized and ESX.GetPlayerData().identifier ~= nil then
                                PlayerData = ESX.GetPlayerData()
                                FrameworkInitialized = true
                                print("^2[ESKUI] ESX Framework initialized (late detection)^7")
                                
                                InitializationInProgress = false
                                if callback then callback() end
                                TriggerEvent('eskui:frameworkReady')
                            end
                        end)
                        
                        -- Register job update event
                        RegisterNetEvent('esx:setJob')
                        AddEventHandler('esx:setJob', function(job)
                            if PlayerData then
                                PlayerData.job = job
                            end
                        end)
                        
                        -- Exit the loop as we've registered the necessary handlers
                        break
                    end
                end
                
                -- Framework not found yet, wait and try again
                attempts = attempts + 1
                
                -- Increase wait time gradually (exponential backoff)
                waitTime = math.min(waitTime * 1.5, maxWaitTime)
                
                if attempts % 5 == 0 then -- Log every 5 attempts
                    print("^3[ESKUI] Waiting for ESX framework... (Attempt " .. attempts .. "/" .. maxAttempts .. ")^7")
                end
                
                Citizen.Wait(waitTime)
            end
            
            -- If we've reached the maximum attempts and still not initialized
            if not FrameworkInitialized and not ESX then
                print("^1[ESKUI] ERROR: Failed to initialize ESX after " .. maxAttempts .. " attempts^7")
                print("^1[ESKUI] Some functionality may be limited. Make sure es_extended is running.^7")
                InitializationInProgress = false
            end
        end)
        
    elseif FrameworkName == 'qbcore' then
        print("[ESKUI] Initializing QBCore framework...")
        
        -- Use TriggerEvent to let the server know we're trying to initialize
        TriggerEvent('eskui:initializingFramework', 'qbcore')
        
        -- Attempt to initialize QBCore
        Citizen.CreateThread(function()
            -- Wait for QBCore to be available using a more efficient waiting pattern
            local initialWaitTime = 100 -- Start with shorter waits
            local maxWaitTime = 2000 -- Max wait between attempts
            local waitTime = initialWaitTime
            local attempts = 0
            local maxAttempts = 30 -- About 30 seconds total with increasing waits
            
            while attempts < maxAttempts do
                -- Try to get QBCore using exports
                local qbSuccess = pcall(function()
                    QBCore = exports['qb-core']:GetCoreObject()
                    return QBCore ~= nil
                end)
                
                if qbSuccess and QBCore then
                    print("^2[ESKUI] QBCore framework found^7")
                    
                    -- Register player loaded handler
                    RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
                    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
                        PlayerData = QBCore.Functions.GetPlayerData()
                        FrameworkInitialized = true
                        print("^2[ESKUI] QBCore player data loaded^7")
                        
                        InitializationInProgress = false
                        if callback then callback() end
                        TriggerEvent('eskui:frameworkReady')
                    end)
                    
                    -- Try to get player data if already loaded
                    PlayerData = QBCore.Functions.GetPlayerData()
                    if PlayerData and PlayerData.citizenid then
                        FrameworkInitialized = true
                        print("^2[ESKUI] QBCore Framework initialized with existing player data^7")
                        
                        InitializationInProgress = false
                        if callback then callback() end
                        TriggerEvent('eskui:frameworkReady')
                    end
                    
                    -- Register job update handler
                    RegisterNetEvent('QBCore:Client:OnJobUpdate')
                    AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
                        if PlayerData then
                            PlayerData.job = job
                        end
                    end)
                    
                    -- Exit the loop as we've registered the necessary handlers
                    break
                end
                
                -- Framework not found yet, wait and try again
                attempts = attempts + 1
                
                -- Increase wait time gradually (exponential backoff)
                waitTime = math.min(waitTime * 1.5, maxWaitTime)
                
                if attempts % 5 == 0 then -- Log every 5 attempts
                    print("^3[ESKUI] Waiting for QBCore framework... (Attempt " .. attempts .. "/" .. maxAttempts .. ")^7")
                end
                
                Citizen.Wait(waitTime)
            end
            
            -- If we've reached the maximum attempts and still not initialized
            if not FrameworkInitialized and not QBCore then
                print("^1[ESKUI] ERROR: Failed to initialize QBCore after " .. maxAttempts .. " attempts^7")
                print("^1[ESKUI] Some functionality may be limited. Make sure qb-core is running.^7")
                InitializationInProgress = false
            end
        end)
        
    elseif FrameworkName == 'standalone' then
        -- Standalone mode doesn't require framework
        FrameworkInitialized = true
        InitializationInProgress = false
        print("^2[ESKUI] Standalone mode initialized^7")
        
        if callback then
            callback()
        end
        
        TriggerEvent('eskui:frameworkReady')
    else
        print("^1[ESKUI] ERROR: Invalid framework '" .. FrameworkName .. "' selected in config.lua^7")
        InitializationInProgress = false
    end
end

-- Check if the framework is initialized
function Framework.IsInitialized()
    return FrameworkInitialized
end

-- Wait for the framework to be initialized
function Framework.WaitForInitialization(callback)
    if FrameworkInitialized then
        -- Framework is already initialized, call the callback immediately
        if callback then
            callback()
        end
    else
        -- Framework not initialized yet, start the initialization process
        -- and provide the callback to be called when it's done
        Framework.Initialize(callback)
    end
end

-- Initialize on resource start
Citizen.CreateThread(function()
    -- Wait for the resource to fully start
    Citizen.Wait(1000)
    
    -- Start the framework initialization
    Framework.Initialize()
end)

-- Get player money
function Framework.GetPlayerMoney(account)
    if not FrameworkInitialized then
        return 0
    end
    
    account = account or Config.DefaultMoneyType
    
    if FrameworkName == 'esx' then
        if account == Config.MoneyTypes.cash then
            return ESX.GetPlayerData().money
        else
            local accounts = ESX.GetPlayerData().accounts
            for i = 1, #accounts do
                if accounts[i].name == account then
                    return accounts[i].money
                end
            end
        end
    elseif FrameworkName == 'qbcore' then
        if account == Config.MoneyTypes.cash then
            return PlayerData.money['cash']
        else
            return PlayerData.money[account]
        end
    elseif FrameworkName == 'standalone' then
        -- In standalone mode, simulate money (always return true)
        return 999999
    end
    
    return 0
end

-- Check if player can afford items
function Framework.CanPlayerAfford(amount, account)
    account = account or Config.DefaultMoneyType
    local playerMoney = Framework.GetPlayerMoney(account)
    return playerMoney >= amount
end

-- Format item name based on framework
function Framework.GetItemName(item)
    if not item.inventory then return item.id end
    
    if FrameworkName == 'esx' then
        return item.inventory.esx
    elseif FrameworkName == 'qbcore' then
        return item.inventory.qbcore
    else
        return item.id
    end
end

-- Process purchase (server side function, this is just a helper)
function Framework.BuyItems(items, account)
    local totalPrice = 0
    for _, item in ipairs(items) do
        totalPrice = totalPrice + (item.price * item.quantity)
    end
    
    -- Check if player can afford the purchase
    if not Framework.CanPlayerAfford(totalPrice, account) then
        return false, "You cannot afford this purchase"
    end
    
    -- Return formatted items for server processing
    local formattedItems = {}
    for _, item in ipairs(items) do
        local itemName = Framework.GetItemName(item)
        
        if Config.Debug then
            print("^2[ESKUI DEBUG] Formatting item for purchase: " .. item.id .. "^7")
            print("^2[ESKUI DEBUG]   - Display name: " .. item.name .. "^7")
            print("^2[ESKUI DEBUG]   - Inventory name: " .. (itemName or "nil") .. "^7")
            print("^2[ESKUI DEBUG]   - Quantity: " .. item.quantity .. "^7")
        end
        
        table.insert(formattedItems, {
            name = itemName,
            quantity = item.quantity,
            price = item.price,
            isWeapon = item.weapon or false
        })
    end
    
    return true, formattedItems, totalPrice
end

-- Process checkout
function Framework.ProcessCheckout(data, paymentMethod)
    if Config.Debug then
        print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT STARTED =========^7")
        print("^5[ESKUI DEBUG] Processing checkout in Framework.ProcessCheckout^7")
        print("^5[ESKUI DEBUG] Payment method: " .. tostring(paymentMethod) .. "^7")
    end
    
    -- Add a lock to prevent duplicate processing
    if _G.purchaseLock then
        if Config.Debug then
            print("^5[ESKUI DEBUG] Purchase already in progress, blocking duplicate checkout^7")
            print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT ABORTED (DUPLICATE) =========^7")
        end
        return false, "Purchase already in progress"
    end
    
    -- Set purchase lock
    _G.purchaseLock = true
    
    -- Clear lock after 5 seconds in case something goes wrong
    Citizen.SetTimeout(5000, function()
        _G.purchaseLock = false
        if Config.Debug then
            print("^5[ESKUI DEBUG] Purchase lock automatically cleared after timeout^7")
        end
    end)
    
    paymentMethod = paymentMethod or Config.DefaultMoneyType
    
    -- Get total price
    local totalPrice = data.total or 0
    if totalPrice <= 0 then
        if Config.Debug then
            print("^5[ESKUI DEBUG] Invalid purchase amount: " .. tostring(totalPrice) .. "^7")
            print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT ABORTED =========^7")
        end
        _G.purchaseLock = false
        return false, "Invalid purchase amount"
    end
    
    -- Check if player can afford
    if not Framework.CanPlayerAfford(totalPrice, paymentMethod) then
        if Config.Debug then
            print("^5[ESKUI DEBUG] Player cannot afford purchase of $" .. totalPrice .. "^7")
            print("^5[ESKUI DEBUG] Player money: $" .. Framework.GetPlayerMoney(paymentMethod) .. "^7")
            print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT ABORTED =========^7")
        end
        _G.purchaseLock = false
        return false, "You cannot afford this purchase"
    end
    
    if Config.Debug then
        print("^5[ESKUI DEBUG] Player can afford purchase ($" .. totalPrice .. ")^7")
        print("^5[ESKUI DEBUG] Player has $" .. Framework.GetPlayerMoney(paymentMethod) .. "^7")
        print("^5[ESKUI DEBUG] Triggering server event 'eskui:processShopPurchase'^7")
        print("^5[ESKUI DEBUG] Number of items: " .. #data.items .. "^7")
        
        for i, item in ipairs(data.items) do
            print("^5[ESKUI DEBUG] Item #" .. i .. ": " .. (item.id or "unknown") .. 
                  " x" .. (item.quantity or "unknown") .. 
                  " @ $" .. (item.price or "unknown") .. 
                  " = $" .. ((item.price or 0) * (item.quantity or 0)) .. "^7")
        end
    end
    
    -- Send server event for processing
    TriggerServerEvent('eskui:processShopPurchase', data.items, totalPrice, paymentMethod)
    
    if Config.Debug then
        print("^5[ESKUI DEBUG] Server event triggered successfully^7")
        print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT COMPLETED =========^7")
    end
    
    -- Register handler for purchase result to clear the lock
    local resultHandler = RegisterNetEvent('eskui:purchaseResult')
    AddEventHandler('eskui:purchaseResult', function()
        -- Clear purchase lock when result comes back
        _G.purchaseLock = false
        if Config.Debug then
            print("^5[ESKUI DEBUG] Purchase lock cleared after result received^7")
        end
        
        -- Remove this handler
        RemoveEventHandler(resultHandler)
    end)
    
    return true, "Purchase successful"
end

-- Get formatted player data
function Framework.GetPlayerData()
    if not FrameworkInitialized then
        return {}
    end
    
    if FrameworkName == 'esx' then
        return ESX.GetPlayerData()
    elseif FrameworkName == 'qbcore' then
        return QBCore.Functions.GetPlayerData()
    else
        return {}
    end
end

-- Notification system integration
function Framework.ShowNotification(message, type, title, duration)
    -- Set defaults
    type = type or 'info'
    title = title or 'Notification'
    duration = duration or 3000
    
    -- Check which notification system to use
    if not Config.NotificationSystem then
        Config.NotificationSystem = 'eskui' -- Default to eskui if not set
    end
    
    if Config.NotificationSystem == 'framework' then
        -- Use the framework's native notification system
        if FrameworkName == 'esx' and ESX then
            ESX.ShowNotification(message)
        elseif FrameworkName == 'qbcore' and QBCore then
            QBCore.Functions.Notify(message, type)
        else
            -- Fallback to eskui if framework not available
            exports['eskui']:ShowNotification({
                type = type,
                title = title,
                message = message,
                duration = duration
            })
        end
    elseif Config.NotificationSystem == 'eskui' then
        -- Use eskui's notification system
        exports['eskui']:ShowNotification({
            type = type,
            title = title,
            message = message,
            duration = duration
        })
    elseif Config.NotificationSystem == 'custom' and Config.CustomNotification then
        -- Use custom notification system from config
        if Config.CustomNotification.resource and Config.CustomNotification.func then
            local params = message
            
            -- If params function exists, use it to format parameters
            if Config.CustomNotification.params and type(Config.CustomNotification.params) == 'function' then
                params = Config.CustomNotification.params(type, title, message, duration)
            end
            
            -- Call the custom notification export
            exports[Config.CustomNotification.resource][Config.CustomNotification.func](params)
        else
            -- Fallback to eskui if custom config is incomplete
            print("^1[ESKUI] ERROR: Custom notification config incomplete, using eskui instead^7")
            exports['eskui']:ShowNotification({
                type = type,
                title = title,
                message = message,
                duration = duration
            })
        end
    else
        -- Fallback to eskui for any other value
        exports['eskui']:ShowNotification({
            type = type,
            title = title,
            message = message,
            duration = duration
        })
    end
end 