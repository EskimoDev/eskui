-- Server-side shop processing for eskui

local ESX = nil
local QBCore = nil
local FrameworkInitialized = false
local FrameworkInitializationInProgress = false

-- Listen for client-side framework initialization
RegisterNetEvent('eskui:initializingFramework')
AddEventHandler('eskui:initializingFramework', function(frameworkName)
    -- This event is triggered by the client when it starts initializing a framework
    if Config.Debug then
        print("^3[ESKUI] Client is initializing " .. frameworkName .. " framework^7")
    end
end)

-- Initialize the framework with improved coordination
function InitializeFramework()
    -- Prevent multiple initialization attempts running simultaneously
    if FrameworkInitializationInProgress then
        return
    end
    
    FrameworkInitializationInProgress = true
    
    -- Wait to make sure config is fully loaded
    Citizen.Wait(500)
    
    -- Ensure Config table exists
    if Config == nil then
        print("^1[ESKUI] ERROR: Config is nil in server_shop.lua. Waiting for Config to be available...^7")
        
        -- Wait longer and try again with exponential backoff
        local waitTime = 500
        local maxWaitTime = 2000
        local attempts = 0
        local maxAttempts = 20
        
        while Config == nil and attempts < maxAttempts do
            waitTime = math.min(waitTime * 1.5, maxWaitTime)
            Citizen.Wait(waitTime)
            attempts = attempts + 1
            
            if attempts % 5 == 0 then
                print("^3[ESKUI] Still waiting for Config to be available... (Attempt " .. attempts .. "/" .. maxAttempts .. ")^7")
            end
        end
        
        if Config == nil then
            print("^1[ESKUI] ERROR: Config is still nil after multiple attempts. Please check your config.lua file.^7")
            FrameworkInitializationInProgress = false
            return false
        else
            print("^2[ESKUI] Config is now available after waiting^7")
        end
    end
    
    -- Check if framework is specified
    if not Config.Framework then
        print("^1[ESKUI] ERROR: Config.Framework is not specified in config.lua^7")
        FrameworkInitializationInProgress = false
        return false
    end
    
    if Config.Framework == 'esx' then
        -- Try to get ESX
        local esxSuccess, esxResult = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        
        if esxSuccess and esxResult then
            ESX = esxResult
            FrameworkInitialized = true
            FrameworkInitializationInProgress = false
            print("^2[ESKUI] ESX Framework initialized on server^7")
            
            -- Set up server callbacks
            SetupESXCallbacks()
            return true
        else
            print("^3[ESKUI] ESX shared object not available yet, will retry later^7")
            FrameworkInitializationInProgress = false
            return false
        end
    elseif Config.Framework == 'qbcore' then
        -- Try to get QBCore
        local qbSuccess, qbResult = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        
        if qbSuccess and qbResult then
            QBCore = qbResult
            FrameworkInitialized = true
            FrameworkInitializationInProgress = false
            print("^2[ESKUI] QBCore Framework initialized on server^7")
            
            -- Set up server callbacks
            SetupQBCoreCallbacks()
            return true
        else
            print("^3[ESKUI] QBCore object not available yet, will retry later^7")
            FrameworkInitializationInProgress = false
            return false
        end
    elseif Config.Framework == 'standalone' then
        FrameworkInitialized = true
        FrameworkInitializationInProgress = false
        print("^2[ESKUI] Standalone mode initialized on server^7")
        
        -- Set up standalone callbacks
        SetupStandaloneCallbacks()
        return true
    else
        print("^1[ESKUI] ERROR: Invalid framework '" .. Config.Framework .. "' selected in config.lua^7")
        FrameworkInitializationInProgress = false
        return false
    end
end

-- Set up ESX callbacks
function SetupESXCallbacks()
    if not ESX then
        print("^1[ESKUI] ERROR: Cannot set up ESX callbacks - ESX is nil^7")
        return
    end
    
    ESX.RegisterServerCallback('eskui:getShopItems', function(source, cb, shopName)
        local shop = Config.GetShop(shopName)
        
        if not shop then
            print("^1[ESKUI] ERROR: Shop not found: " .. (shopName or "nil") .. "^7")
            cb(false)
            return
        end
        
        if Config.Debug then
            print("^2[ESKUI DEBUG] Getting items for shop: " .. shopName .. ", found: " .. tostring(shop ~= nil) .. "^7")
            print("^2[ESKUI DEBUG] Shop has " .. #shop.items .. " items^7")
        end
        
        -- Format items based on framework
        local formattedItems = {}
        for i, item in ipairs(shop.items) do
            -- Add safety check for inventory property
            if not item.inventory then
                if Config.Debug then
                    print("^3[ESKUI WARNING] Item #" .. i .. " '" .. item.id .. "' is missing inventory property^7")
                end
                
                -- Create a default inventory property if missing
                item.inventory = {
                    esx = item.id,
                    qbcore = item.id
                }
            end
            
            local inventoryName = item.inventory.esx or item.id
            
            if Config.Debug then
                print("^2[ESKUI DEBUG] Adding item: " .. item.name .. " with inventory name: " .. inventoryName .. "^7")
            end
            
            -- Add item
            table.insert(formattedItems, {
                id = item.id,
                name = item.name,
                price = item.price,
                category = item.category,
                icon = item.icon,
                description = item.description,
                inventoryName = inventoryName,
                weapon = item.weapon or false
            })
        end
        
        if Config.Debug then
            print("^2[ESKUI DEBUG] Formatted " .. #formattedItems .. " items for shop: " .. shopName .. "^7")
        end
        
        cb({
            name = shop.name,
            categories = shop.categories,
            items = formattedItems
        })
    end)
    
    print("^2[ESKUI] ESX callbacks registered successfully^7")
end

-- Set up QBCore callbacks
function SetupQBCoreCallbacks()
    if not QBCore then
        print("^1[ESKUI] ERROR: Cannot set up QBCore callbacks - QBCore is nil^7")
        return
    end
    
    QBCore.Functions.CreateCallback('eskui:getShopItems', function(source, cb, shopName)
        local shop = Config.GetShop(shopName)
        
        if not shop then
            cb(false)
            return
        end
        
        -- Format items based on framework
        local formattedItems = {}
        for i, item in ipairs(shop.items) do
            -- Add safety check for inventory property
            if not item.inventory then
                if Config.Debug then
                    print("^3[ESKUI WARNING] Item #" .. i .. " '" .. item.id .. "' is missing inventory property^7")
                end
                
                -- Create a default inventory property if missing
                item.inventory = {
                    esx = item.id,
                    qbcore = item.id
                }
            end
            
            local inventoryName = item.inventory.qbcore or item.id
            
            -- Add item
            table.insert(formattedItems, {
                id = item.id,
                name = item.name,
                price = item.price,
                category = item.category,
                icon = item.icon,
                description = item.description,
                inventoryName = inventoryName,
                weapon = item.weapon or false
            })
        end
        
        cb({
            name = shop.name,
            categories = shop.categories,
            items = formattedItems
        })
    end)
    
    print("^2[ESKUI] QBCore callbacks registered successfully^7")
end

-- Set up standalone callbacks (using events)
function SetupStandaloneCallbacks()
    -- Standalone mode uses events instead of callbacks
    RegisterNetEvent('eskui:getShopItems')
    AddEventHandler('eskui:getShopItems', function(shopName)
        local source = source
        local shop = Config.GetShop(shopName)
        
        if not shop then
            TriggerClientEvent('eskui:receiveShopItems', source, false)
            return
        end
        
        -- Format items (standalone uses the item ID directly)
        local formattedItems = {}
        for i, item in ipairs(shop.items) do
            -- Add safety check for inventory property
            if not item.inventory then
                if Config.Debug then
                    print("^3[ESKUI WARNING] Item #" .. i .. " '" .. item.id .. "' is missing inventory property^7")
                end
                
                -- Create a default inventory property if missing
                item.inventory = {
                    esx = item.id,
                    qbcore = item.id
                }
            end
            
            table.insert(formattedItems, {
                id = item.id or "unknown_" .. i,
                name = item.name or "Unknown Item " .. i,
                price = item.price or 0,
                category = item.category or "misc",
                icon = item.icon or "📦",
                description = item.description or "No description available",
                inventoryName = item.id,
                weapon = item.weapon or false
            })
        end
        
        TriggerClientEvent('eskui:receiveShopItems', source, {
            name = shop.name,
            categories = shop.categories,
            items = formattedItems
        })
    end)
    
    print("^2[ESKUI] Standalone callbacks registered successfully^7")
end

-- Helper function to get item label for ESX
local function GetESXItemLabel(itemName)
    if not itemName then
        return "Unknown Item"
    end
    local item = ESX.GetItemLabel(itemName)
    return item or itemName
end

-- Helper function to get item label for QBCore
local function GetQBItemLabel(itemName)
    if not itemName then
        return "Unknown Item"
    end
    local item = QBCore.Shared.Items[itemName]
    if item then
        return item.label
    end
    return itemName
end

-- Helper function to get proper item name
local function GetItemLabel(itemName)
    if not itemName then
        return "Unknown Item"
    end
    
    if Config.Framework == 'esx' then
        return GetESXItemLabel(itemName)
    elseif Config.Framework == 'qbcore' then
        return GetQBItemLabel(itemName)
    else
        return itemName
    end
end

-- Process shop purchase
RegisterServerEvent('eskui:processShopPurchase')
AddEventHandler('eskui:processShopPurchase', function(items, totalPrice, paymentMethod)
    local source = source
    
    -- Make sure framework is initialized
    if not FrameworkInitialized then
        if not InitializeFramework() then
            TriggerClientEvent('eskui:purchaseResult', source, false, "Shop system is not ready yet. Please try again later.")
            return
        end
    end
    
    local xPlayer, Player
    
    -- Check framework
    if Config.Framework == 'esx' then
        xPlayer = ESX.GetPlayerFromId(source)
        
        if not xPlayer then
            TriggerClientEvent('eskui:purchaseResult', source, false, "Player not found")
            return
        end
        
        -- Check if player has enough money
        local playerMoney
        if paymentMethod == Config.MoneyTypes.cash then
            playerMoney = xPlayer.getMoney()
        else
            playerMoney = xPlayer.getAccount(paymentMethod).money
        end
        
        if playerMoney < totalPrice then
            TriggerClientEvent('eskui:purchaseResult', source, false, "You don't have enough money")
            return
        end
        
        -- Remove money
        if paymentMethod == Config.MoneyTypes.cash then
            xPlayer.removeMoney(totalPrice)
        else
            xPlayer.removeAccountMoney(paymentMethod, totalPrice)
        end
        
        -- Give items
        local purchasedItems = {}
        for _, item in ipairs(items) do
            -- Check if it's a weapon
            if item.name and (string.match(item.name, "WEAPON_") or string.match(item.name, "weapon_")) then
                if Config.Debug then
                    print("^2[ESKUI DEBUG] Adding weapon to player: " .. item.name .. "^7")
                end
                xPlayer.addWeapon(item.name, 0)
                table.insert(purchasedItems, {
                    name = GetItemLabel(item.name),
                    quantity = item.quantity
                })
            else
                if Config.Debug then
                    print("^2[ESKUI DEBUG] Adding item to player: " .. (item.name or "nil") .. " x" .. (item.quantity or 0) .. "^7")
                end
                
                -- Check if the item exists in ESX inventory before trying to add it
                local itemExists = false
                
                if ESX.Items then
                    -- ESX legacy has an Items table we can check
                    local esxItem = ESX.Items[item.name]
                    if esxItem then
                        itemExists = true
                    else
                        if Config.Debug then
                            print("^1[ESKUI ERROR] Item not found in ESX.Items: " .. (item.name or "nil") .. "^7")
                            
                            -- Show some available items for debugging
                            local count = 0
                            print("^3[ESKUI] Some available ESX items:^7")
                            for name, _ in pairs(ESX.Items) do
                                print("  - " .. name)
                                count = count + 1
                                if count >= 10 then break end -- Only show 10 items to avoid spam
                            end
                        end
                    end
                else
                    -- For older ESX versions, we'll try to add the item and see if it works
                    if Config.Debug then
                        print("^3[ESKUI WARNING] ESX.Items not available, will attempt to add item directly: " .. (item.name or "nil") .. "^7")
                    end
                    itemExists = true -- Assume it exists and try adding it
                end
                
                -- Add item to player inventory
                if itemExists or not ESX.Items then
                    xPlayer.addInventoryItem(item.name, item.quantity)
                    
                    if Config.Debug then
                        print("^2[ESKUI DEBUG] Added item: " .. item.name .. " x" .. item.quantity .. "^7")
                    end
                else
                    if Config.Debug then
                        print("^1[ESKUI ERROR] Failed to add non-existent item: " .. item.name .. "^7")
                    end
                end
                
                table.insert(purchasedItems, {
                    name = GetItemLabel(item.name),
                    quantity = item.quantity
                })
            end
        end
        
        -- Send success message
        TriggerClientEvent('eskui:purchaseResult', source, true, "Purchase successful", purchasedItems)
        
    elseif Config.Framework == 'qbcore' then
        Player = QBCore.Functions.GetPlayer(source)
        
        if not Player then
            TriggerClientEvent('eskui:purchaseResult', source, false, "Player not found")
            return
        end
        
        -- Check if player has enough money
        local playerMoney = Player.Functions.GetMoney(paymentMethod)
        
        if playerMoney < totalPrice then
            TriggerClientEvent('eskui:purchaseResult', source, false, "You don't have enough money")
            return
        end
        
        -- Remove money
        Player.Functions.RemoveMoney(paymentMethod, totalPrice)
        
        -- Give items
        local purchasedItems = {}
        for _, item in ipairs(items) do
            -- Check if it's a weapon
            if item.name and string.match(item.name, "weapon_") then
                Player.Functions.AddItem(item.name, 1)
                table.insert(purchasedItems, {
                    name = GetItemLabel(item.name),
                    quantity = 1
                })
            else
                Player.Functions.AddItem(item.name, item.quantity)
                table.insert(purchasedItems, {
                    name = GetItemLabel(item.name),
                    quantity = item.quantity
                })
            end
        end
        
        -- Send success message
        TriggerClientEvent('eskui:purchaseResult', source, true, "Purchase successful", purchasedItems)
        
    elseif Config.Framework == 'standalone' then
        -- In standalone mode, just simulate success
        local purchasedItems = {}
        for _, item in ipairs(items) do
            table.insert(purchasedItems, {
                name = item.name or "Unknown Item",
                quantity = item.quantity or 1
            })
        end
        
        -- Send success message
        TriggerClientEvent('eskui:purchaseResult', source, true, "Purchase successful (Standalone mode)", purchasedItems)
    end
end)

-- Start the initialization process
Citizen.CreateThread(function()
    -- Delay initialization slightly to ensure everything is loaded
    Citizen.Wait(1000)
    
    -- First initialization attempt
    if not InitializeFramework() then
        -- If first attempt fails, set up a retry mechanism with exponential backoff
        local initialWaitTime = 1000
        local maxWaitTime = 5000
        local waitTime = initialWaitTime
        local attempts = 1
        local maxAttempts = 10
        
        Citizen.CreateThread(function()
            while not FrameworkInitialized and attempts < maxAttempts do
                -- Wait with increasing delay between attempts
                Citizen.Wait(waitTime)
                
                -- Increase wait time (capped at maxWaitTime)
                waitTime = math.min(waitTime * 1.5, maxWaitTime)
                attempts = attempts + 1
                
                -- Try to initialize again
                if InitializeFramework() then
                    print("^2[ESKUI] Framework successfully initialized after " .. attempts .. " attempts^7")
                    break
                else
                    print("^3[ESKUI] Framework initialization attempt " .. attempts .. "/" .. maxAttempts .. " failed, trying again in " .. math.floor(waitTime/1000) .. " seconds^7")
                end
            end
            
            if not FrameworkInitialized then
                print("^1[ESKUI] WARNING: Framework could not be initialized after " .. maxAttempts .. " attempts. Some features may not work correctly.^7")
                print("^1[ESKUI] Please check if the required framework (" .. (Config and Config.Framework or "unknown") .. ") is running and properly configured.^7")
            end
        end)
    end
end)

-- Print startup message
print("^2[ESKUI] Server module initialized^7") 