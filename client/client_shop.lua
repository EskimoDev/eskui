-- Client-side shop system for eskui
local CurrentShop = nil
local ShopBlips = {}
local nearbyShops = {}
local isInitialized = false
local ShopCheckoutHandler = nil  -- Track the checkout event handler to prevent duplicates

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
        print("^3[ESKUI DEBUG] ========= SHOP UI OPENING =========^7")
        print("^3[ESKUI DEBUG] Showing shop UI for: " .. shopData.name .. "^7")
        print("^3[ESKUI DEBUG] ShopCheckoutHandler before clearing: " .. tostring(ShopCheckoutHandler) .. "^7")
    end
    
    -- Remove any existing checkout callback handlers to prevent duplicates
    if ShopCheckoutHandler then
        RemoveEventHandler(ShopCheckoutHandler)
        ShopCheckoutHandler = nil
        if Config.Debug then
            print("^3[ESKUI DEBUG] Removed existing shop checkout handler^7")
        end
    else
        if Config.Debug then
            print("^3[ESKUI DEBUG] No existing ShopCheckoutHandler to remove^7")
        end
    end
    
    -- Debug memory usage before UI opening
    if Config.Debug then
        collectgarbage("collect")
        print("^3[ESKUI DEBUG] Memory usage before UI show: " .. collectgarbage("count") .. " KB^7")
    end
    
    -- Show shop UI using ESKUI
    exports['eskui']:ShowShop(shopData.name, shopData.categories, shopData.items, function(data)
        if Config.Debug then
            print("^3[ESKUI DEBUG] ========= SHOP CALLBACK TRIGGERED =========^7")
            print("^3[ESKUI DEBUG] ShopCheckoutHandler in callback: " .. tostring(ShopCheckoutHandler) .. "^7")
        end
        
        if not data then
            -- User cancelled - restore interaction prompt with a delay
            if Config.Debug then
                print("^3[ESKUI DEBUG] Shop cancelled, no data returned^7")
            end
            
            Citizen.SetTimeout(300, function()
                exports['eskui']:CheckForNearbyAndShow()
                if Config.Debug then
                    print("^3[ESKUI DEBUG] Shop cancelled, checking for interactions^7")
                end
            end)
            return
        end
        
        -- Debug the checkout data
        if Config.Debug then
            print("^3[ESKUI DEBUG] Checkout initiated with " .. #data.items .. " items^7")
            print("^3[ESKUI DEBUG] Total price: $" .. data.total .. "^7")
            
            for i, item in ipairs(data.items) do
                print("^3[ESKUI DEBUG] Item #" .. i .. ": " .. item.id .. " x" .. item.quantity .. "^7")
            end
        end
        
        -- Ensure each cart item has the proper inventoryName from shopData
        for i, cartItem in ipairs(data.items) do
            -- Find the matching item in the shop catalog
            for _, shopItem in ipairs(shopData.items) do
                if shopItem.id == cartItem.id then
                    -- Copy the inventory name to the cart item
                    cartItem.name = shopItem.inventoryName
                    
                    if Config.Debug then
                        print("^3[ESKUI DEBUG] Set item #" .. i .. " (" .. cartItem.id .. ") inventory name to: " .. cartItem.name .. "^7")
                    end
                    break
                end
            end
        end
        
        -- Try to process the checkout
        if Config.Debug then
            print("^3[ESKUI DEBUG] Processing checkout with Framework.ProcessCheckout^7")
        end
        
        local success, message = Framework.ProcessCheckout(data, Config.DefaultMoneyType)
        
        if Config.Debug then
            print("^3[ESKUI DEBUG] Checkout process result: " .. tostring(success) .. ", " .. message .. "^7")
            print("^3[ESKUI DEBUG] ShopCheckoutHandler after checkout: " .. tostring(ShopCheckoutHandler) .. "^7")
            print("^3[ESKUI DEBUG] ========= SHOP CALLBACK COMPLETE =========^7")
        end
        
        -- Handle result in the callback event
        
        -- Restore interaction prompt with a delay after checkout
        Citizen.SetTimeout(300, function()
            TriggerEvent('eskui:uiStateChanged', false) -- Explicitly notify UI state change
            exports['eskui']:CheckForNearbyAndShow()
            if Config.Debug then
                print("^3[ESKUI DEBUG] Shop checkout complete, checking for interactions^7")
            end
        end)
    end)
    
    if Config.Debug then
        print("^3[ESKUI DEBUG] Shop UI opened, new ShopCheckoutHandler: " .. tostring(ShopCheckoutHandler) .. "^7")
        print("^3[ESKUI DEBUG] Memory usage after UI show: " .. collectgarbage("count") .. " KB^7")
        print("^3[ESKUI DEBUG] ========= SHOP UI OPENED =========^7")
    end
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

-- Modify the Framework.ProcessCheckout function to handle payment method
function Framework.ProcessCheckout(data, paymentMethod)
    if Config.Debug then
        print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT STARTED =========^7")
        print("^5[ESKUI DEBUG] Processing checkout in Framework.ProcessCheckout^7")
        print("^5[ESKUI DEBUG] Payment method from UI: " .. tostring(data.paymentMethod) .. "^7")
        print("^5[ESKUI DEBUG] Default payment method: " .. tostring(paymentMethod) .. "^7")
    end
    
    -- Use payment method from UI if provided
    if data.paymentMethod then
        paymentMethod = data.paymentMethod
        if Config.Debug then
            print("^5[ESKUI DEBUG] Using payment method from UI: " .. paymentMethod .. "^7")
        end
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
    
    -- Check if player can afford with the selected payment method
    if not Framework.CanPlayerAfford(totalPrice, paymentMethod) then
        if Config.Debug then
            print("^5[ESKUI DEBUG] Player cannot afford purchase of $" .. totalPrice .. " with " .. paymentMethod .. "^7")
            print("^5[ESKUI DEBUG] Player money: $" .. Framework.GetPlayerMoney(paymentMethod) .. "^7")
            print("^5[ESKUI DEBUG] ========= FRAMEWORK CHECKOUT ABORTED =========^7")
        end
        _G.purchaseLock = false
        return false, "You cannot afford this purchase with " .. paymentMethod
    end
    
    if Config.Debug then
        print("^5[ESKUI DEBUG] Player can afford purchase ($" .. totalPrice .. ") with " .. paymentMethod .. "^7")
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
    
    -- Send server event for processing with payment method
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

-- Handle shop checkout
local function handleShopCheckout(data)
    if Config.Debug then
        print("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK TRIGGERED =========^7")
        print("^6[ESKUI DEBUG] Data received from UI: " .. tostring(data ~= nil) .. "^7")
        print("^6[ESKUI DEBUG] Maintaining NUI focus during payment flow^7")
    end
    
    -- Prevent duplicate checkout processes
    if _G.checkoutInProgress then
        if Config.Debug then
            print("^6[ESKUI DEBUG] Checkout already in progress, ignoring duplicate callback^7")
            print("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK IGNORED =========^7")
        end
        return
    end
    
    -- Set checkout in progress flag
    _G.checkoutInProgress = true
    
    -- Clear the flag after timeout (consolidated to one place)
    Citizen.SetTimeout(5000, function()
        _G.checkoutInProgress = false
        if Config.Debug then
            print("^6[ESKUI DEBUG] Checkout in progress flag cleared after timeout^7")
        end
    end)
    
    print("Received shop checkout callback with total: $" .. data.total)
    
    -- Add debugging to check item data
    if Config.Debug then
        print("^6[ESKUI DEBUG] Processing shop checkout with " .. #data.items .. " items^7")
        print("^6[ESKUI DEBUG] Using payment method: " .. (data.paymentMethod or "default") .. "^7")
        
        for i, item in ipairs(data.items) do
            print("^6[ESKUI DEBUG] Item #" .. i .. ": " .. item.id .. " x" .. item.quantity .. "^7")
            
            -- Make sure the item has the inventoryName property for the framework
            if item.inventoryName then
                print("^6[ESKUI DEBUG]   - Using inventory name: " .. item.inventoryName .. "^7")
            else
                print("^6[ESKUI DEBUG] No inventory name available for item: " .. item.id .. "^7")
            end
        end
    end
    
    -- IMPORTANT: Keep UI open with NUI focus during the entire payment flow
    -- Do NOT reset focus or close the UI during payment processing
    
    -- Process the shop checkout
    if Config.Debug then
        print("^6[ESKUI DEBUG] Triggering eskui:shopCheckoutCallback event^7")
    end
    
    TriggerEvent('eskui:shopCheckoutCallback', data)
    
    if Config.Debug then
        print("^6[ESKUI DEBUG] Event triggered successfully^7")
        print("^6[ESKUI DEBUG] ========= SHOP CHECKOUT NUI CALLBACK COMPLETE =========^7")
    end
    
    -- Return a callback response to let the UI know we've processed the request
    -- This doesn't close the UI or reset NUI focus
    cb({success = true})
end

-- Register NUI callbacks
RegisterNUICallback('shopCheckout', handleShopCheckout)

-- Add this new function to fetch player balances
function GetPlayerBalances()
    if Config.Debug then
        print("^3[ESKUI DEBUG] Getting player balances from server^7")
    end
    
    -- We'll store the result in this variable
    local balances = {
        cash = 0,
        bank = 0
    }
    
    -- Use a promise to make this synchronous for the NUI callback
    local p = promise.new()
    
    -- Trigger server event to get fresh balances
    TriggerServerEvent('eskui:getPlayerBalances')
    
    -- Register a one-time event handler for the response
    local eventHandler = RegisterNetEvent('eskui:receivePlayerBalances')
    AddEventHandler('eskui:receivePlayerBalances', function(cashAmount, bankAmount)
        if Config.Debug then
            print("^3[ESKUI DEBUG] Received fresh balances from server:^7")
            print("^3[ESKUI DEBUG] Cash: $" .. cashAmount .. "^7")
            print("^3[ESKUI DEBUG] Bank: $" .. bankAmount .. "^7")
        end
        
        -- Update the balances
        balances.cash = cashAmount
        balances.bank = bankAmount
        
        -- Resolve the promise
        p:resolve(true)
        
        -- Remove the event handler
        RemoveEventHandler(eventHandler)
    end)
    
    -- Wait for the promise to be resolved (with a timeout)
    Citizen.SetTimeout(1000, function()
        if not p:isResolved() then
            if Config.Debug then
                print("^1[ESKUI DEBUG] Timeout waiting for server balances, using default values^7")
            end
            p:resolve(false)
        end
    end)
    
    -- Wait for the promise
    Citizen.Await(p)
    
    return balances
end

-- Add a new NUI callback to get balances
RegisterNUICallback('getPlayerBalances', function(data, cb)
    local balances = GetPlayerBalances()
    cb(balances)
end)

-- Add a new NUI callback for when the shop is ready for a new purchase
RegisterNUICallback('shopReadyForNewPurchase', function(data, cb)
    if Config.Debug then
        print("^3[ESKUI DEBUG] ========= SHOP READY FOR NEW PURCHASE =========^7")
    end
    
    -- Reset any flags or locks that might prevent a new purchase
    _G.purchaseLock = false
    _G.checkoutInProgress = false
    
    -- Clear any stale data
    if ShopCheckoutHandler then
        if Config.Debug then
            print("^3[ESKUI DEBUG] Removing existing ShopCheckoutHandler to prepare for new purchase^7")
        end
        RemoveEventHandler(ShopCheckoutHandler)
        ShopCheckoutHandler = nil
    end
    
    -- Let the current shop know it should reopen with fresh state
    if CurrentShop then
        if Config.Debug then
            print("^3[ESKUI DEBUG] Reopening shop with fresh state for: " .. CurrentShop.name .. "^7")
        end
        
        -- Use the direct ShowShopUI function without full OpenShop to maintain the current UI session
        -- We don't want to close and reopen the UI, just refresh the internal state
        OpenShop(CurrentShop)
    else
        if Config.Debug then
            print("^3[ESKUI DEBUG] Warning: No current shop to refresh!^7")
        end
    end
    
    if Config.Debug then
        print("^3[ESKUI DEBUG] Shop state reset successfully for new purchase^7")
        print("^3[ESKUI DEBUG] ========= SHOP READY COMPLETE =========^7")
    end
    
    -- Return a success response
    cb({success = true})
end) 