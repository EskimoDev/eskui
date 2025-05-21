-- Server-side shop processing for eskui

local ESX = nil
local QBCore = nil

-- Initialize the framework
Citizen.CreateThread(function()
    -- Wait to make sure config is fully loaded
    Citizen.Wait(1000)
    
    -- Ensure Config table exists
    if Config == nil then
        print("^1[ESKUI] ERROR: Config is nil in server_shop.lua. Waiting for Config to be available...^7")
        
        -- Wait longer and try again
        local attempts = 0
        while Config == nil and attempts < 30 do
            Citizen.Wait(1000)
            attempts = attempts + 1
        end
        
        if Config == nil then
            print("^1[ESKUI] ERROR: Config is still nil after waiting 30 seconds. Please check your config.lua file.^7")
            return
        else
            print("[ESKUI] Config is now available after waiting")
        end
    end
    
    if Config.Framework == 'esx' then
        -- Modern ESX initialization using exports
        ESX = exports['es_extended']:getSharedObject()
        
        if ESX then
            if Config.Debug then
                print("[ESKUI] ESX Framework initialized on server")
            end
        else
            print("^1[ESKUI] ERROR: Failed to get ESX shared object, trying again in 5 seconds...^7")
            
            -- Try again after a delay
            Citizen.Wait(5000)
            ESX = exports['es_extended']:getSharedObject()
            
            if ESX then
                print("[ESKUI] ESX Framework initialized on server after retry")
            else
                print("^1[ESKUI] ERROR: Failed to get ESX shared object after retry^7")
            end
        end
        
    elseif Config.Framework == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
        
        if QBCore then
            if Config.Debug then
                print("[ESKUI] QBCore Framework initialized on server")
            end
        else
            print("^1[ESKUI] ERROR: Failed to get QBCore object, trying again in 5 seconds...^7")
            
            -- Try again after a delay
            Citizen.Wait(5000)
            QBCore = exports['qb-core']:GetCoreObject()
            
            if QBCore then
                print("[ESKUI] QBCore Framework initialized on server after retry")
            else
                print("^1[ESKUI] ERROR: Failed to get QBCore object after retry^7")
            end
        end
    elseif Config.Framework == 'standalone' then
        if Config.Debug then
            print("[ESKUI] Standalone mode initialized on server")
        end
    else
        print("^1[ESKUI] ERROR: Invalid framework selected in config.lua^7")
    end
end)

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

-- Get the shop items for a specific store
-- Fixed server callback registration to use framework-specific methods
if Config.Framework == 'esx' then
    if ESX then
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
    else
        print("^1[ESKUI] ERROR: ESX is not initialized yet, trying again in 5 seconds^7")
        -- Try to initialize ESX again after a delay
        Citizen.CreateThread(function()
            Citizen.Wait(5000)
            ESX = exports['es_extended']:getSharedObject()
            if ESX then
                print("[ESKUI] ESX successfully initialized after retry")
                
                -- Register the callback after successful initialization
                ESX.RegisterServerCallback('eskui:getShopItems', function(source, cb, shopName)
                    local shop = Config.GetShop(shopName)
                    
                    if not shop then
                        print("^1[ESKUI] ERROR: Shop not found: " .. (shopName or "nil") .. "^7")
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
                        
                        local inventoryName = item.inventory.esx or item.id
                        
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
            else
                print("^1[ESKUI] ERROR: ESX could not be initialized after retry^7")
            end
        end)
    end
elseif Config.Framework == 'qbcore' then
    if QBCore then
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
    else
        print("^1[ESKUI] ERROR: QBCore is not initialized yet, trying again in 5 seconds^7")
        -- Try to initialize QBCore again after a delay
        Citizen.CreateThread(function()
            Citizen.Wait(5000)
            QBCore = exports['qb-core']:GetCoreObject()
            if QBCore then
                print("[ESKUI] QBCore successfully initialized after retry")
            else
                print("^1[ESKUI] ERROR: QBCore could not be initialized after retry^7")
            end
        end)
    end
else
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
end 