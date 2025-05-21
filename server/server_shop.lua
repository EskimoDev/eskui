-- Server-side shop processing for eskui

local ESX = nil
local QBCore = nil

-- Initialize the framework
Citizen.CreateThread(function()
    if Config.Framework == 'esx' then
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        
        if Config.Debug then
            print("[ESKUI] ESX Framework initialized on server")
        end
        
    elseif Config.Framework == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
        
        if Config.Debug then
            print("[ESKUI] QBCore Framework initialized on server")
        end
    elseif Config.Framework == 'standalone' then
        if Config.Debug then
            print("[ESKUI] Standalone mode initialized on server")
        end
    else
        print("[ESKUI] ERROR: Invalid framework selected in config.lua")
    end
end)

-- Helper function to get item label for ESX
local function GetESXItemLabel(itemName)
    local item = ESX.GetItemLabel(itemName)
    return item or itemName
end

-- Helper function to get item label for QBCore
local function GetQBItemLabel(itemName)
    local item = QBCore.Shared.Items[itemName]
    if item then
        return item.label
    end
    return itemName
end

-- Helper function to get proper item name
local function GetItemLabel(itemName)
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
            if string.match(item.name, "WEAPON_") or string.match(item.name, "weapon_") then
                xPlayer.addWeapon(item.name, 0)
                table.insert(purchasedItems, {
                    name = GetItemLabel(item.name),
                    quantity = item.quantity
                })
            else
                xPlayer.addInventoryItem(item.name, item.quantity)
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
            if string.match(item.name, "weapon_") then
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
                name = item.name,
                quantity = item.quantity
            })
        end
        
        -- Send success message
        TriggerClientEvent('eskui:purchaseResult', source, true, "Purchase successful (Standalone mode)", purchasedItems)
    end
end)

-- Get the shop items for a specific store
-- Fixed server callback registration to use framework-specific methods
if Config.Framework == 'esx' then
    ESX.RegisterServerCallback('eskui:getShopItems', function(source, cb, shopName)
        local shop = Config.GetShop(shopName)
        
        if not shop then
            cb(false)
            return
        end
        
        -- Format items based on framework
        local formattedItems = {}
        for _, item in ipairs(shop.items) do
            local inventoryName = item.inventory.esx
            
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
elseif Config.Framework == 'qbcore' then
    QBCore.Functions.CreateCallback('eskui:getShopItems', function(source, cb, shopName)
        local shop = Config.GetShop(shopName)
        
        if not shop then
            cb(false)
            return
        end
        
        -- Format items based on framework
        local formattedItems = {}
        for _, item in ipairs(shop.items) do
            local inventoryName = item.inventory.qbcore
            
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
        for _, item in ipairs(shop.items) do
            table.insert(formattedItems, {
                id = item.id,
                name = item.name,
                price = item.price,
                category = item.category,
                icon = item.icon,
                description = item.description,
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