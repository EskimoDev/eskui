-- Framework integration for eskui shop system
Framework = {}
local PlayerData = {}
local FrameworkInitialized = false

-- Initialize the framework
Citizen.CreateThread(function()
    -- Wait for the resource to fully start
    Citizen.Wait(1000)
    
    -- Check if config is loaded
    if not Config then
        print("^1[ESKUI] ERROR: Config not found. Make sure config.lua is loaded correctly.^7")
        return
    end
    
    -- Check framework setting
    if not Config.Framework then
        print("^1[ESKUI] ERROR: Config.Framework is nil. Check your config.lua file.^7")
        return
    end
    
    if Config.Framework == 'esx' then
        print("[ESKUI] Initializing ESX framework...")
        
        -- Try to initialize ESX with retries
        local attempts = 0
        local maxAttempts = 10
        
        local function initESX()
            -- Modern ESX initialization using exports
            local esxSuccess, esxError = pcall(function()
                ESX = exports['es_extended']:getSharedObject()
                return ESX ~= nil
            end)
            
            if not esxSuccess or not ESX then
                attempts = attempts + 1
                if attempts < maxAttempts then
                    print("^3[ESKUI] ESX not available yet, retrying in 2 seconds... (Attempt " .. attempts .. "/" .. maxAttempts .. ")^7")
                    SetTimeout(2000, initESX)
                else
                    print("^1[ESKUI] ERROR: Failed to get ESX after " .. maxAttempts .. " attempts. Is es_extended running?^7")
                end
                return
            end
            
            -- ESX is loaded, now wait for player to be loaded
            print("[ESKUI] ESX found, waiting for player data...")
            
            -- Register player loaded handler
            if ESX.GetPlayerData().identifier == nil then
                -- Set up player loaded event for first load
                RegisterNetEvent('esx:playerLoaded')
                AddEventHandler('esx:playerLoaded', function(xPlayer)
                    PlayerData = xPlayer
                    FrameworkInitialized = true
                    print("^2[ESKUI] ESX Framework fully initialized!^7")
                end)
                
                -- If we're already loaded but missed the event
                SetTimeout(3000, function()
                    if not FrameworkInitialized and ESX.GetPlayerData().identifier ~= nil then
                        PlayerData = ESX.GetPlayerData()
                        FrameworkInitialized = true
                        print("^2[ESKUI] ESX Framework initialized (late detection)^7")
                    end
                end)
            else
                -- Player is already loaded
                PlayerData = ESX.GetPlayerData()
                FrameworkInitialized = true
                print("^2[ESKUI] ESX Framework initialized^7")
            end
            
            -- Update player data when job changes
            RegisterNetEvent('esx:setJob')
            AddEventHandler('esx:setJob', function(job)
                if PlayerData then
                    PlayerData.job = job
                end
            end)
        end
        
        -- Start the initialization process
        initESX()
        
    elseif Config.Framework == 'qbcore' then
        -- QBCore implementation remains similar
        print("[ESKUI] Initializing QBCore framework...")
        
        local attempts = 0
        local maxAttempts = 10
        
        local function initQBCore()
            local qbSuccess, qbError = pcall(function()
                QBCore = exports['qb-core']:GetCoreObject()
                return QBCore ~= nil
            end)
            
            if not qbSuccess or not QBCore then
                attempts = attempts + 1
                if attempts < maxAttempts then
                    print("^3[ESKUI] QBCore not available yet, retrying in 2 seconds... (Attempt " .. attempts .. "/" .. maxAttempts .. ")^7")
                    SetTimeout(2000, initQBCore)
                else
                    print("^1[ESKUI] ERROR: Failed to get QBCore after " .. maxAttempts .. " attempts. Is qb-core running?^7")
                end
                return
            end
            
            -- QBCore is loaded
            print("^2[ESKUI] QBCore initialized^7")
            
            -- Register player loaded handlers
            RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
            AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
                PlayerData = QBCore.Functions.GetPlayerData()
                FrameworkInitialized = true
                print("^2[ESKUI] QBCore player data loaded^7")
            end)
            
            -- Try to get player data if already loaded
            PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData and PlayerData.citizenid then
                FrameworkInitialized = true
            end
            
            -- Job updates
            RegisterNetEvent('QBCore:Client:OnJobUpdate')
            AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
                if PlayerData then
                    PlayerData.job = job
                end
            end)
        end
        
        -- Start the initialization process
        initQBCore()
        
    elseif Config.Framework == 'standalone' then
        -- Standalone mode doesn't require framework
        FrameworkInitialized = true
        print("^2[ESKUI] Standalone mode initialized^7")
    else
        print("^1[ESKUI] ERROR: Invalid framework '" .. Config.Framework .. "' selected in config.lua^7")
    end
end)

-- Check if the framework is initialized
function Framework.IsInitialized()
    return FrameworkInitialized
end

-- Get player money
function Framework.GetPlayerMoney(account)
    if not FrameworkInitialized then
        return 0
    end
    
    account = account or Config.DefaultMoneyType
    
    if Config.Framework == 'esx' then
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
    elseif Config.Framework == 'qbcore' then
        if account == Config.MoneyTypes.cash then
            return PlayerData.money['cash']
        else
            return PlayerData.money[account]
        end
    elseif Config.Framework == 'standalone' then
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
    
    if Config.Framework == 'esx' then
        return item.inventory.esx
    elseif Config.Framework == 'qbcore' then
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
    paymentMethod = paymentMethod or Config.DefaultMoneyType
    
    -- Get total price
    local totalPrice = data.total or 0
    if totalPrice <= 0 then
        return false, "Invalid purchase amount"
    end
    
    -- Check if player can afford
    if not Framework.CanPlayerAfford(totalPrice, paymentMethod) then
        return false, "You cannot afford this purchase"
    end
    
    -- Send server event for processing
    TriggerServerEvent('eskui:processShopPurchase', data.items, totalPrice, paymentMethod)
    return true, "Purchase successful"
end

-- Get formatted player data
function Framework.GetPlayerData()
    if not FrameworkInitialized then
        return {}
    end
    
    if Config.Framework == 'esx' then
        return ESX.GetPlayerData()
    elseif Config.Framework == 'qbcore' then
        return QBCore.Functions.GetPlayerData()
    else
        return {}
    end
end

-- Notification system integration
function Framework.ShowNotification(message, type)
    type = type or 'info'
    
    if Config.Framework == 'esx' then
        ESX.ShowNotification(message)
    elseif Config.Framework == 'qbcore' then
        QBCore.Functions.Notify(message, type)
    else
        -- Use ESKUI's notification system
        exports['eskui']:ShowNotification({
            type = type,
            title = 'Shop System',
            message = message,
            duration = 3000
        })
    end
end 