-- Ensure Config is initialized
if Config == nil then
    Config = {}
end

-- Shop settings
Config.Shops = {
    {
        name = "General Store",
        blip = {
            sprite = 59,
            color = 25,
            scale = 0.7,
            label = "General Store"
        },
        locations = {
            {x = 25.7, y = -1347.3, z = 29.49},
            {x = -707.41, y = -914.03, z = 19.21},
            {x = 1135.7, y = -982.78, z = 46.41},
            {x = -47.39, y = -1757.74, z = 29.42},
            {x = 373.59, y = 325.52, z = 103.56},
            {x = 1163.67, y = -323.92, z = 69.20},
            {x = 2557.44, y = 382.03, z = 108.62},
            {x = -3039.16, y = 585.71, z = 7.90},
            {x = -3242.24, y = 1001.4, z = 12.83},
            {x = 547.75, y = 2671.53, z = 42.15},
            {x = 1165.36, y = 2708.91, z = 38.15},
            {x = 2678.82, y = 3280.36, z = 55.24},
            {x = 1961.17, y = 3740.5, z = 32.34},
            {x = 1393.14, y = 3605.15, z = 34.98},
            {x = 1697.97, y = 4924.37, z = 42.06},
            {x = 1728.78, y = 6414.41, z = 35.03}
        },
        categories = {
            {id = 'food', label = 'Food', icon = '🍔'},
            {id = 'drinks', label = 'Drinks', icon = '🥤'},
            {id = 'misc', label = 'Miscellaneous', icon = '📦'}
        },
        items = {
            -- Food (using standard ESX items)
            {
                id = 'bread',
                name = 'Bread',
                price = 100000,
                category = 'food',
                icon = '🍞',
                description = 'Fresh baked bread',
                inventory = {
                    esx = 'bread',
                    qbcore = 'bread'
                }
            },
            {
                id = 'chocolate',
                name = 'Chocolate',
                price = 15,
                category = 'food',
                icon = '🍫',
                description = 'Delicious chocolate',
                inventory = {
                    esx = 'chocolate',
                    qbcore = 'chocolate'
                }
            },
            {
                id = 'sandwich',
                name = 'Sandwich',
                price = 20,
                category = 'food',
                icon = '🥪',
                description = 'Tasty sandwich',
                inventory = {
                    esx = 'sandwich',
                    qbcore = 'sandwich'
                }
            },
            
            -- Drinks (using standard ESX items)
            {
                id = 'water',
                name = 'Water',
                price = 7,
                category = 'drinks',
                icon = '💧',
                description = 'Refreshing water',
                inventory = {
                    esx = 'water',
                    qbcore = 'water_bottle'
                }
            },
            {
                id = 'cocacola',
                name = 'Coca Cola',
                price = 10,
                category = 'drinks',
                icon = '🥤',
                description = 'Ice cold cola',
                inventory = {
                    esx = 'cocacola',
                    qbcore = 'kurkakola'
                }
            },
            {
                id = 'icetea',
                name = 'Ice Tea',
                price = 8,
                category = 'drinks',
                icon = '🥤',
                description = 'Refreshing ice tea',
                inventory = {
                    esx = 'icetea',
                    qbcore = 'icetea'
                }
            },
            
            -- Misc (using standard ESX items)
            {
                id = 'phone',
                name = 'Phone',
                price = 750,
                category = 'misc',
                icon = '📱',
                description = 'Smartphone',
                inventory = {
                    esx = 'phone',
                    qbcore = 'phone'
                }
            },
            {
                id = 'bandage',
                name = 'Bandage',
                price = 50,
                category = 'misc',
                icon = '🩹',
                description = 'Medical bandage',
                inventory = {
                    esx = 'bandage',
                    qbcore = 'bandage'
                }
            },
            {
                id = 'medikit',
                name = 'Medical Kit',
                price = 250,
                category = 'misc',
                icon = '💊',
                description = 'First aid kit',
                inventory = {
                    esx = 'medikit',
                    qbcore = 'firstaid'
                }
            }
        }
    },
    {
        name = "Ammunition Store",
        blip = {
            sprite = 110,
            color = 1,
            scale = 0.7,
            label = "Ammunition"
        },
        locations = {
            {x = 22.5, y = -1106.9, z = 29.8},
            {x = 810.2, y = -2157.3, z = 29.6},
            {x = 1693.4, y = 3759.5, z = 34.7},
            {x = -330.2, y = 6083.8, z = 31.4},
            {x = 252.3, y = -50.0, z = 69.9},
            {x = -662.1, y = -935.3, z = 21.8}
        },
        categories = {
            {id = 'weapons', label = 'Weapons', icon = '🔫'},
            {id = 'ammo', label = 'Ammunition', icon = '🔹'}
        },
        items = {
            -- Weapons
            {
                id = 'pistol',
                name = 'Pistol',
                price = 5000,
                category = 'weapons',
                icon = '🔫',
                description = 'Standard pistol',
                inventory = {
                    esx = 'WEAPON_PISTOL',
                    qbcore = 'weapon_pistol'
                },
                weapon = true
            },
            {
                id = 'bat',
                name = 'Baseball Bat',
                price = 1500,
                category = 'weapons',
                icon = '🏏',
                description = 'Wooden baseball bat',
                inventory = {
                    esx = 'WEAPON_BAT',
                    qbcore = 'weapon_bat'
                },
                weapon = true
            },
            
            -- Ammo
            {
                id = 'pistol_ammo',
                name = 'Pistol Ammo',
                price = 150,
                category = 'ammo',
                icon = '🔹',
                description = 'Ammunition for pistols',
                inventory = {
                    esx = 'pistol_ammo',
                    qbcore = 'pistol_ammo'
                }
            }
        }
    }
}

-- Tax configuration
Config.Tax = {
    cash = "5", -- 5% tax for cash payments
    bank = false -- no tax for bank payments
}

-- Function to get shop configuration
function Config.GetShop(shopName)
    -- Make sure Config.Shops exists
    if Config.Shops == nil then
        print("^1[ESKUI] ERROR: Config.Shops is nil in GetShop function^7")
        return nil
    end
    
    -- Ensure shopName exists
    if shopName == nil then
        print("^1[ESKUI] ERROR: shopName is nil in GetShop function^7")
        return nil
    end
    
    -- Find the shop with matching name
    for _, shop in ipairs(Config.Shops) do
        if shop.name == shopName then
            return shop
        end
    end
    
    -- Shop not found
    if Config.Debug then
        print("[ESKUI] Shop not found: " .. shopName)
    end
    return nil
end

-- Print debug message to confirm shops are loaded
if Config.Debug then
    if Config.Shops then
        print("[ESKUI] Shops configuration loaded successfully with " .. #Config.Shops .. " shops")
    else
        print("^1[ESKUI] ERROR: Config.Shops is nil after shops.lua execution^7")
    end
end 