-- Client-side shop system for eskui
local CurrentShop = nil
local ShopBlips = {}
local nearbyShops = {}
local isInitialized = false

-- Wait for framework to initialize
Citizen.CreateThread(function()
    -- Wait for resource to fully start
    Citizen.Wait(1000)
    
    -- Initialize the shops module once the framework is ready
    Framework.WaitForInitialization(function()
        isInitialized = true
        
        -- Create shop blips
        CreateShopBlips()
        
        -- Start shop location checking
        CheckNearbyShops()
        
        if Config.Debug then
            print("^2[ESKUI] Shop system initialized after framework ready^7")
        end
    end)
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
    
    -- Verify Config.Shops exists to prevent nil error
    if Config.Shops == nil then
        print("^1[ESKUI] ERROR: Config.Shops is nil. Make sure cfg/shops.lua is loaded correctly in fxmanifest.lua^7")
        return
    end
    
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
            
            -- Skip processing if not initialized
            if not isInitialized then
                Citizen.Wait(1000)
                goto continue
            end
            
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local previousShopCount = #nearbyShops
            
            -- Clear the existing nearby shops
            nearbyShops = {}
            
            -- Verify Config.Shops exists to prevent nil error
            if Config.Shops == nil then
                if Config.Debug then
                    print("^1[ESKUI] ERROR: Config.Shops is nil in CheckNearbyShops^7")
                end
                Citizen.Wait(5000) -- Wait longer before checking again
                goto continue
            end
            
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
            
            -- Start marker drawing for nearby shops if there are shops and we're not already drawing
            if #nearbyShops > 0 and not DrawingMarkers then
                DrawShopMarkers()
            end
            
            -- If we went from having shops to having none, force reset the drawing state
            if previousShopCount > 0 and #nearbyShops == 0 then
                DrawingMarkers = false
            end
            
            ::continue::
        end
    end)
end

-- Draw markers for nearby shops
local DrawingMarkers = false
function DrawShopMarkers()
    -- If already drawing, don't start another thread
    if DrawingMarkers then 
        return
    end
    
    DrawingMarkers = true
    
    Citizen.CreateThread(function()
        local shopThreadId = GetGameTimer() -- Create a unique ID for this thread
        
        if Config.Debug then
            print("^2[ESKUI DEBUG] Starting marker thread: " .. shopThreadId .. "^7")
        end
        
        while DrawingMarkers and #nearbyShops > 0 do
            Citizen.Wait(0)
            
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearestShop = nil
            local nearestDistance = 999.0
            local tempNearbyShops = {}
            
            -- Copy the nearby shops to prevent race conditions with the checking thread
            for _, shopData in pairs(nearbyShops) do
                table.insert(tempNearbyShops, shopData)
            end
            
            if #tempNearbyShops == 0 then
                -- No nearby shops, stop drawing
                DrawingMarkers = false
                break
            end
            
            for _, shopData in ipairs(tempNearbyShops) do
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
            
            -- Check if we're too far from all shops
            if nearestDistance > 50.0 then
                if Config.Debug then
                    print("^2[ESKUI DEBUG] Player too far from shops, stopping marker thread: " .. shopThreadId .. "^7")
                end
                DrawingMarkers = false
            end
        end
        
        if Config.Debug then
            print("^2[ESKUI DEBUG] Marker thread ended: " .. shopThreadId .. "^7")
        end
        
        DrawingMarkers = false
    end)
end

-- Open a shop
function OpenShop(shop)
    -- Ensure framework is initialized
    if not Framework.IsInitialized() then
        Framework.ShowNotification("Shop system is not ready yet. Please try again in a moment.", "error")
        
        -- Try to initialize the framework and retry opening the shop
        Framework.WaitForInitialization(function()
            -- Retry opening the shop after framework is initialized
            OpenShop(shop)
        end)
        return
    end
    
    -- Set current shop
    CurrentShop = shop
    
    if Config.Debug then
        print("^2[ESKUI DEBUG] Opening shop: " .. shop.name .. "^7")
        print("^2[ESKUI DEBUG] Using framework: " .. Framework.GetFrameworkName() .. "^7")
    end
    
    -- Fetch shop items (using callback for ESX/QBCore or event for standalone)
    if Framework.GetFrameworkName() == 'esx' then
        if Config.Debug then
            print("^2[ESKUI DEBUG] Triggering ESX server callback for shop items^7")
        end
        
        if not ESX then
            print("^1[ESKUI ERROR] ESX object is nil, can't open shop^7")
            Framework.ShowNotification("Error: ESX framework not found", "error")
            return
        end
        
        ESX.TriggerServerCallback('eskui:getShopItems', function(shopData)
            if Config.Debug then
                print("^2[ESKUI DEBUG] ESX callback received: " .. tostring(shopData ~= nil) .. "^7")
            end
            
            if not shopData then
                print("^1[ESKUI ERROR] Shop data is nil from ESX callback^7")
                Framework.ShowNotification("This shop is currently unavailable", "error")
                return
            end
            
            if Config.Debug and shopData then
                print("^2[ESKUI DEBUG] Shop data received: " .. shopData.name .. "^7")
                print("^2[ESKUI DEBUG] Categories: " .. #shopData.categories .. "^7")
                print("^2[ESKUI DEBUG] Items: " .. #shopData.items .. "^7")
            end
            
            ShowShopUI(shopData)
        end, shop.name)
    elseif Framework.GetFrameworkName() == 'qbcore' then
        QBCore.Functions.TriggerCallback('eskui:getShopItems', function(shopData)
            if not shopData then
                Framework.ShowNotification("This shop is currently unavailable", "error")
                return
            end
            
            ShowShopUI(shopData)
        end, shop.name)
    else
        -- Standalone mode uses events
        if Config.Debug then
            print("^2[ESKUI DEBUG] Triggering standalone event for shop items^7")
        end
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
    if Config.Debug then
        print("^2[ESKUI DEBUG] Showing shop UI for: " .. shopData.name .. "^7")
        
        -- Debug: Check if items have inventory names
        for i, item in ipairs(shopData.items) do
            print("^2[ESKUI DEBUG] Shop item #" .. i .. ": " .. item.name .. "^7")
            print("^2[ESKUI DEBUG]   - Inventory name: " .. (item.inventoryName or "nil") .. "^7")
        end
    end
    
    -- Show shop UI using ESKUI
    exports['eskui']:ShowShop(shopData.name, shopData.categories, shopData.items, function(data)
        if not data then
            -- User cancelled - restore interaction prompt with a delay
            Citizen.SetTimeout(300, function()
                exports['eskui']:CheckForNearbyAndShow()
                if Config.Debug then
                    print("^2[ESKUI DEBUG] Shop cancelled, checking for interactions^7")
                end
            end)
            return
        end
        
        -- Debug the checkout data
        if Config.Debug then
            print("^2[ESKUI DEBUG] Checkout initiated with " .. #data.items .. " items^7")
            print("^2[ESKUI DEBUG] Total price: $" .. data.total .. "^7")
        end
        
        -- Ensure each cart item has the proper inventoryName from shopData
        for i, cartItem in ipairs(data.items) do
            -- Find the matching item in the shop catalog
            for _, shopItem in ipairs(shopData.items) do
                if shopItem.id == cartItem.id then
                    -- Copy the inventory name to the cart item
                    cartItem.name = shopItem.inventoryName
                    
                    if Config.Debug then
                        print("^2[ESKUI DEBUG] Set item #" .. i .. " (" .. cartItem.id .. ") inventory name to: " .. cartItem.name .. "^7")
                    end
                    break
                end
            end
        end
        
        -- Try to process the checkout
        local success, message = Framework.ProcessCheckout(data, Config.DefaultMoneyType)
        
        -- Handle result in the callback event
        
        -- Restore interaction prompt with a delay after checkout
        Citizen.SetTimeout(300, function()
            TriggerEvent('eskui:uiStateChanged', false) -- Explicitly notify UI state change
            exports['eskui']:CheckForNearbyAndShow()
            if Config.Debug then
                print("^2[ESKUI DEBUG] Shop checkout complete, checking for interactions^7")
            end
        end)
    end)
end

-- Register commands for testing
if Config.Debug then
    -- Command to open nearest shop
    RegisterCommand('openshop', function()
        -- Make sure framework is initialized first
        if not Framework.IsInitialized() then
            Framework.ShowNotification("Framework not initialized yet. Please wait a moment.", "warning")
            return
        end
        
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
        -- Make sure framework is initialized first
        if not Framework.IsInitialized() then
            Framework.ShowNotification("Framework not initialized yet. Please wait a moment.", "warning")
            return
        end
        
        -- Verify Config.Shops exists to prevent nil error
        if Config.Shops == nil then
            Framework.ShowNotification("Config.Shops is nil. Make sure cfg/shops.lua is loaded correctly.", "error")
            return
        end
        
        local shopIndex = tonumber(args[1] or 1)
        if Config.Shops[shopIndex] then
            OpenShop(Config.Shops[shopIndex])
        else
            Framework.ShowNotification("Shop index " .. shopIndex .. " does not exist", "error")
        end
    end, false)
    
    -- Debug command to check framework and shops status
    RegisterCommand('checkshops', function()
        -- Check framework initialization
        local frameworkStatus = Framework.IsInitialized() and "Initialized" or "Not initialized"
        print("^2[ESKUI DEBUG] Framework status: " .. frameworkStatus .. "^7")
        print("^2[ESKUI DEBUG] Current framework: " .. (Framework.GetFrameworkName() or "nil") .. "^7")
        
        -- Check Config.Shops
        if Config.Shops then
            print("^2[ESKUI DEBUG] Config.Shops loaded with " .. #Config.Shops .. " shops^7")
            
            -- Print shop locations
            for i, shop in ipairs(Config.Shops) do
                print("^2[ESKUI DEBUG] Shop #" .. i .. ": " .. shop.name .. " with " .. #shop.locations .. " locations^7")
                
                -- Print first location of each shop
                if #shop.locations > 0 then
                    local loc = shop.locations[1]
                    print("^2[ESKUI DEBUG]   - First location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z .. "^7")
                end
            end
            
            -- Print nearby shops
            print("^2[ESKUI DEBUG] Nearby shops: " .. #nearbyShops .. "^7")
            for i, shopData in ipairs(nearbyShops) do
                print("^2[ESKUI DEBUG]   - Nearby #" .. i .. ": " .. shopData.shop.name .. " (Distance: " .. math.floor(shopData.distance * 100) / 100 .. ")^7")
            end
            
            -- Print if DrawingMarkers is active
            print("^2[ESKUI DEBUG] Drawing markers: " .. (DrawingMarkers and "Yes" or "No") .. "^7")
        else
            print("^1[ESKUI DEBUG] Config.Shops is nil^7")
        end
    end, false)
    
    -- Network test command to verify server-client communication
    RegisterCommand('testnetwork', function()
        print("^2[ESKUI] Testing network communication with server...^7")
        
        -- Create a unique event name using timestamp to avoid conflicts
        local eventName = "eskui:networkTestResponse:" .. GetGameTimer()
        
        -- Register event with proper scope for the handler variable
        local testHandled = false
        RegisterNetEvent(eventName)
        local handler = AddEventHandler(eventName, function(serverTime)
            testHandled = true
            print("^2[ESKUI] Network test successful! Server time: " .. serverTime .. "^7")
            
            -- Only try to remove if handler is valid
            if handler then
                RemoveEventHandler(handler)
                handler = nil
            end
        end)
        
        -- Send test request to server with our unique event name
        TriggerServerEvent("eskui:networkTest", eventName)
        
        -- Set timeout to detect if response doesn't arrive
        SetTimeout(2000, function()
            if not testHandled and handler then
                print("^1[ESKUI] Network test failed: No response from server after 2 seconds^7")
                
                -- Only try to remove if handler is valid
                if handler then
                    RemoveEventHandler(handler)
                    handler = nil
                end
            end
        end)
    end, false)
    
    -- Force open General Store UI for debugging with better error handling
    RegisterCommand('opengeneral', function()
        -- Check if Config is loaded
        if not Config then
            print("^1[ESKUI DEBUG] Config is nil, can't open General Store^7")
            return
        end
        
        -- Check if Framework is initialized
        if not Framework.IsInitialized() then
            print("^1[ESKUI DEBUG] Framework not initialized yet, can't open General Store^7")
            Framework.ShowNotification("Framework not initialized yet, please try again in a moment", "error")
            return
        end
        
        -- Check if Config.Shops exists
        if not Config.Shops then
            print("^1[ESKUI DEBUG] Config.Shops is nil, can't open General Store^7")
            return
        end
        
        -- Find General Store by name with better debug info
        local generalStore = nil
        print("^2[ESKUI DEBUG] Searching for General Store among " .. #Config.Shops .. " shops^7")
        
        for i, shop in ipairs(Config.Shops) do
            print("^2[ESKUI DEBUG] Shop #" .. i .. ": " .. shop.name .. "^7")
            if shop.name == "General Store" then
                generalStore = shop
                break
            end
        end
        
        if generalStore then
            print("^2[ESKUI DEBUG] Found General Store, attempting to open UI^7")
            OpenShop(generalStore)
        else
            print("^1[ESKUI DEBUG] General Store not found in Config.Shops^7")
            Framework.ShowNotification("General Store not found in shops configuration", "error")
        end
    end, false)
    
    -- Test ESX shop callback directly
    RegisterCommand('testesxshop', function()
        if Framework.GetFrameworkName() ~= 'esx' then
            print("^3[ESKUI DEBUG] This command is only for ESX framework mode^7")
            return
        end
        
        if not ESX then
            print("^1[ESKUI ERROR] ESX object is nil, can't test shop callback^7")
            return
        end
        
        print("^2[ESKUI DEBUG] Testing ESX shop callback for General Store^7")
        ESX.TriggerServerCallback('eskui:getShopItems', function(shopData)
            print("^2[ESKUI DEBUG] ESX callback received: " .. tostring(shopData ~= nil) .. "^7")
            
            if not shopData then
                print("^1[ESKUI ERROR] Shop data is nil from ESX callback^7")
                return
            end
            
            print("^2[ESKUI DEBUG] Shop data received successfully:^7")
            print("^2[ESKUI DEBUG] - Name: " .. shopData.name .. "^7")
            print("^2[ESKUI DEBUG] - Categories: " .. #shopData.categories .. "^7")
            print("^2[ESKUI DEBUG] - Items: " .. #shopData.items .. "^7")
            
            -- List some items for verification
            if #shopData.items > 0 then
                print("^2[ESKUI DEBUG] First 3 items:^7")
                for i = 1, math.min(3, #shopData.items) do
                    local item = shopData.items[i]
                    print("^2[ESKUI DEBUG]   " .. i .. ": " .. item.name .. " - $" .. item.price .. " (ID: " .. item.id .. ", Inventory: " .. item.inventoryName .. ")^7")
                end
            end
        end, "General Store")
    end, false)
end 