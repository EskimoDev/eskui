-- Client-side shop system for eskui
local CurrentShop = nil
local ShopBlips = {}
local nearbyShops = {}

-- Wait for framework to initialize
Citizen.CreateThread(function()
    -- Wait for framework to initialize
    while not Framework.IsInitialized() do
        Citizen.Wait(100)
    end
    
    -- Create shop blips
    CreateShopBlips()
    
    -- Start shop location checking
    CheckNearbyShops()
end)

-- Result handler for shop purchases
RegisterNetEvent('eskui:purchaseResult')
AddEventHandler('eskui:purchaseResult', function(success, message, items)
    if success then
        local itemsText = ""
        if items and #items > 0 then
            for i, item in ipairs(items) do
                if i > 1 then
                    itemsText = itemsText .. ", "
                end
                itemsText = itemsText .. item.quantity .. "x " .. item.name
            end
        end
        
        local notificationMessage = message
        if itemsText ~= "" then
            notificationMessage = message .. "\nItems: " .. itemsText
        end
        
        Framework.ShowNotification(notificationMessage, "success")
    else
        Framework.ShowNotification(message, "error")
    end
end)

-- Create blips for all shop locations
function CreateShopBlips()
    -- Remove any existing blips
    for _, blip in pairs(ShopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    ShopBlips = {}
    
    -- Create new blips
    for _, shop in pairs(Config.Shops) do
        if shop.blip then
            for _, location in pairs(shop.locations) do
                local blip = AddBlipForCoord(location.x, location.y, location.z)
                SetBlipSprite(blip, shop.blip.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, shop.blip.scale or 0.7)
                SetBlipColour(blip, shop.blip.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(shop.blip.label or shop.name)
                EndTextCommandSetBlipName(blip)
                
                table.insert(ShopBlips, blip)
            end
        end
    end
    
    if Config.Debug then
        print("[ESKUI] Created " .. #ShopBlips .. " shop blips")
    end
end

-- Check for nearby shops continuously
function CheckNearbyShops()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000) -- Check every second
            
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            nearbyShops = {}
            
            for shopIndex, shop in ipairs(Config.Shops) do
                for _, location in ipairs(shop.locations) do
                    local distance = #(playerCoords - vector3(location.x, location.y, location.z))
                    
                    if distance < 50.0 then
                        table.insert(nearbyShops, {
                            shop = shop,
                            location = location,
                            distance = distance,
                            shopIndex = shopIndex
                        })
                    end
                end
            end
            
            -- Start marker drawing for nearby shops
            if #nearbyShops > 0 and not DrawingMarkers then
                DrawShopMarkers()
            end
        end
    end)
end

-- Draw markers for nearby shops
local DrawingMarkers = false
function DrawShopMarkers()
    DrawingMarkers = true
    
    Citizen.CreateThread(function()
        while DrawingMarkers and #nearbyShops > 0 do
            Citizen.Wait(0)
            
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearestShop = nil
            local nearestDistance = 999.0
            
            for _, shopData in ipairs(nearbyShops) do
                local shop = shopData.shop
                local location = shopData.location
                local distance = #(playerCoords - vector3(location.x, location.y, location.z))
                
                -- Update nearest shop
                if distance < nearestDistance then
                    nearestShop = shopData
                    nearestDistance = distance
                end
                
                -- Draw marker if close enough
                if distance < 15.0 then
                    DrawMarker(1, location.x, location.y, location.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 128, 255, 100, false, true, 2, nil, nil, false)
                end
            end
            
            -- Show help text if very close to a shop
            if nearestShop and nearestDistance < 1.5 then
                -- Display help text
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("Press ~INPUT_CONTEXT~ to open " .. nearestShop.shop.name)
                EndTextCommandDisplayHelp(0, false, true, -1)
                
                -- Open shop when key is pressed
                if IsControlJustPressed(0, 38) then -- E key
                    OpenShop(nearestShop.shop)
                end
            end
        end
        
        DrawingMarkers = false
    end)
end

-- Open a shop
function OpenShop(shop)
    -- Set current shop
    CurrentShop = shop
    
    -- Fetch shop items (using callback for ESX/QBCore or event for standalone)
    if Config.Framework == 'esx' then
        ESX.TriggerServerCallback('eskui:getShopItems', function(shopData)
            if not shopData then
                Framework.ShowNotification("This shop is currently unavailable", "error")
                return
            end
            
            ShowShopUI(shopData)
        end, shop.name)
    elseif Config.Framework == 'qbcore' then
        QBCore.Functions.TriggerCallback('eskui:getShopItems', function(shopData)
            if not shopData then
                Framework.ShowNotification("This shop is currently unavailable", "error")
                return
            end
            
            ShowShopUI(shopData)
        end, shop.name)
    else
        -- Standalone mode uses events
        TriggerServerEvent('eskui:getShopItems', shop.name)
    end
end

-- Receive shop items (for standalone mode)
RegisterNetEvent('eskui:receiveShopItems')
AddEventHandler('eskui:receiveShopItems', function(shopData)
    if not shopData then
        Framework.ShowNotification("This shop is currently unavailable", "error")
        return
    end
    
    ShowShopUI(shopData)
end)

-- Show the shop UI with formatted items
function ShowShopUI(shopData)
    -- Show shop UI using ESKUI
    exports['eskui']:ShowShop(shopData.name, shopData.categories, shopData.items, function(data)
        if not data then
            -- User cancelled
            return
        end
        
        -- Try to process the checkout
        local success, message = Framework.ProcessCheckout(data, Config.DefaultMoneyType)
        
        -- Handle result in the callback event
    end)
end

-- Register commands for testing
if Config.Debug then
    -- Command to open nearest shop
    RegisterCommand('openshop', function()
        if #nearbyShops > 0 then
            local nearestShop = nearbyShops[1]
            for _, shopData in ipairs(nearbyShops) do
                if shopData.distance < nearestShop.distance then
                    nearestShop = shopData
                end
            end
            
            OpenShop(nearestShop.shop)
        else
            Framework.ShowNotification("No shops nearby", "error")
        end
    end, false)
    
    -- Command to open a specific shop by index
    RegisterCommand('shop', function(source, args)
        local shopIndex = tonumber(args[1] or 1)
        if Config.Shops[shopIndex] then
            OpenShop(Config.Shops[shopIndex])
        else
            Framework.ShowNotification("Shop index " .. shopIndex .. " does not exist", "error")
        end
    end, false)
end 