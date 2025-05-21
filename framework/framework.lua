-- Framework integration for eskui shop system
Framework = {}
local PlayerData = {}
local FrameworkInitialized = false

-- Initialize the framework
Citizen.CreateThread(function()
    if Config.Framework == 'esx' then
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Citizen.Wait(0)
        end

        while ESX.GetPlayerData().job == nil do
            Citizen.Wait(10)
        end

        PlayerData = ESX.GetPlayerData()
        FrameworkInitialized = true
        if Config.Debug then
            print("[ESKUI] ESX Framework initialized")
        end
        
        -- Update player data when it changes
        RegisterNetEvent('esx:playerLoaded')
        AddEventHandler('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
        end)

        RegisterNetEvent('esx:setJob')
        AddEventHandler('esx:setJob', function(job)
            PlayerData.job = job
        end)
        
    elseif Config.Framework == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
        
        while not QBCore do
            Citizen.Wait(100)
        end
        
        PlayerData = QBCore.Functions.GetPlayerData()
        FrameworkInitialized = true
        if Config.Debug then
            print("[ESKUI] QBCore Framework initialized")
        end
        
        -- Update player data when it changes
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore.Functions.GetPlayerData()
        end)

        RegisterNetEvent('QBCore:Client:OnJobUpdate')
        AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
            PlayerData.job = job
        end)
        
    elseif Config.Framework == 'standalone' then
        -- Standalone mode doesn't require framework
        FrameworkInitialized = true
        if Config.Debug then
            print("[ESKUI] Standalone mode initialized")
        end
    else
        print("[ESKUI] ERROR: Invalid framework selected in config.lua")
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