# ESKUI - Modern FiveM NUI UI Framework

A sleek, modern, and extensible UI framework for FiveM, designed for professional-quality user interfaces with vibrant, animated, and macOS-inspired aesthetics. ESKUI provides easy-to-use exports for common UI patterns including amount input, list selection, dropdown menus, shops, and interaction prompts.

---

## ✨ Features
- **Modern macOS-style UI**: Clean, vibrant, and animated.
- **Framework Integration**: Support for ESX, QBCore, and standalone modes.
- **Amount Input**: Prompt users for a numeric value.
- **List Selection**: Show a list of items, with support for long text and submenus.
- **Dropdown**: Modern dropdown with animated open/close, cancel/submit, and icon.
- **Shop System**: Complete shop interface with categories, items, and cart functionality.
- **Interaction Prompts**: Customizable interaction prompts for locations and objects.
- **Notifications**: Stylish, animated notifications with different types (info, success, error, warning).
- **Dark Mode**: Toggle between light and dark themes.
- **Keyboard and mouse support**: Enter, Escape, click, and more.
- **Extensible**: Add new UI types easily with shared animation and state management.
- **Robust event handling**: No event leaks, safe for repeated use.

---

## 📦 Installation
1. Place the `eskui` folder in your FiveM resources directory.
2. Add `ensure eskui` to your `server.cfg`.
3. (Optional) Add `eskui` as a dependency in your resource manifest if you use it from another resource.

---

## ⚙️ Configuration
ESKUI can be configured by editing the files in the `cfg` folder:

### Main Configuration (`config.lua`)
```lua
Config = {}

-- Framework settings
Config.Framework = 'esx' -- Options: 'esx', 'qbcore', 'standalone'

-- Debug mode
Config.Debug = false -- Set to true for development

-- Money settings
Config.MoneyTypes = {
    cash = "cash",
    bank = "bank"
}
Config.DefaultMoneyType = Config.MoneyTypes.cash -- Which account to use by default

-- Interaction Prompt settings
Config.Interaction = {
    key = 38, -- E key by default
    keyName = "E", -- Display name for key
    isMouse = false, -- Whether it's a mouse button or keyboard key
    position = "center", -- Options: "center", "bottom"
    showDistance = 2.0, -- Maximum distance to show prompt
    color = "#007AFF", -- Primary color for the prompt
    scale = 1.0 -- Size multiplier
}
```

### Shop Configuration (`shops.lua`)
Configure shops with locations, items, and categories.

---

## 🚀 Usage

### 1. Amount Input
Prompt the user for a number:
```lua
exports['eskui']:ShowAmount('Enter Amount', function(amount)
    if amount then
        print('User entered amount:', amount)
    end
end)
```

### 2. List Selection
Show a list of items for the user to choose from:
```lua
local items = {
    {label = 'Item 1', price = 100},
    {label = 'Item 2', price = 200},
    {label = 'A very long item name that will scroll on hover', price = 300},
    {label = 'Weapons', icon = '🔫', submenu = {
        {label = 'Pistol', event = 'buy:pistol', eventType = 'server'},
        {label = 'Rifle', event = 'buy:rifle', eventType = 'server'},
        {label = 'Back', isBack = true}
    }},
    {label = 'Settings', icon = '⚙️', submenu = function()
        return {
            {label = 'Toggle Music', event = 'toggle:music', eventType = 'client'},
            {label = 'Back', isBack = true}
        }
    end},
    {label = 'About', description = 'Information about this server.'},
    {label = 'Disabled Option', disabled = true}
}
exports['eskui']:ShowList('Select an Item', items, function(index, item)
    if index and item then
        print(('Selected: %s (index %d)'):format(item.label, index))
    end
end)
```

### 3. Dropdown
Show a dropdown menu with cancel/submit:
```lua
local options = {'Option 1', 'Option 2', 'Option 3'}
exports['eskui']:ShowDropdown('Select an Option', options, function(index, value)
    if index and value then
        print(('Dropdown selected: %s (index %d)'):format(value, index))
    else
        print('Dropdown cancelled or no selection made.')
    end
end)
```

### 4. Shop System
Display a shop interface with categories and items:
```lua
local categories = {
    {id = 'food', label = 'Food', icon = '🍔'},
    {id = 'drinks', label = 'Drinks', icon = '🥤'}
}

local items = {
    {id = 'burger', name = 'Burger', price = 10, category = 'food', icon = '🍔', description = 'Tasty burger'},
    {id = 'pizza', name = 'Pizza', price = 12, category = 'food', icon = '🍕', description = 'Delicious pizza'},
    {id = 'water', name = 'Water', price = 5, category = 'drinks', icon = '💧', description = 'Refreshing water'},
    {id = 'cola', name = 'Cola', price = 7, category = 'drinks', icon = '🥤', description = 'Fizzy cola'}
}

exports['eskui']:ShowShop('General Store', categories, items, function(data)
    if data then
        print('Checkout total: $' .. data.total)
        for i, item in ipairs(data.items) do
            print(item.id .. ' x' .. item.quantity)
        end
    end
end)
```

### 5. Interaction Prompts
Register an interaction point that shows a prompt when the player is nearby:
```lua
exports['eskui']:RegisterInteraction(
    "unique_id",
    vector3(123.4, 567.8, 12.3), -- coordinates
    2.0, -- distance
    {
        textLeft = "Press",
        textRight = "to open shop"
    },
    function()
        -- Code to execute when interaction is triggered
        OpenShop()
        return false -- Return true to remove the interaction after triggering
    }
)
```

### 6. Notifications
Show a notification:
```lua
exports['eskui']:ShowNotification({
    type = 'info', -- Options: 'info', 'success', 'error', 'warning'
    title = 'Information',
    message = 'This is an information notification',
    duration = 5000, -- milliseconds
    closable = true -- Whether user can close it
})
```

### 7. Dark Mode Toggle
Toggle dark mode:
```lua
exports['eskui']:ToggleDarkMode()
```

### 8. Settings Menu
Open the settings menu:
```lua
exports['eskui']:ShowSettings()
```

---

## 🛠️ Advanced Features

### List Item Fields
- `label` (string): Main text (required)
- `price` (number, optional): Price (optional, for store-like lists)
- `icon` (string, optional): Emoji or image URL
- `description` (string, optional): Secondary text
- `event` (string, optional): Event to trigger on select
- `eventType` (string, optional): 'client' or 'server' (default: client)
- `args` (table, optional): Arguments for the event
- `submenu` (array or function, optional): Submenu items or function returning items
- `isBack` (bool, optional): If true, acts as a back button in submenus
- `disabled` (bool, optional): If true, item is not selectable

### Framework Integration
ESKUI automatically integrates with ESX or QBCore frameworks:
- Player money management for shops
- Item validation and management
- Framework-specific notifications (if desired)
- Automatic inventory naming conversion

### Global Commands
- `/darkmode` - Toggle dark mode
- `/uisettings` - Open UI settings menu

---

## 🖌️ Customization
- Edit `html/styles.css` for colors, animations, and layout.
- UI is fully responsive and works with keyboard and mouse.
- Configure interaction prompts through the config.lua file.

---

## 🧑‍💻 Contributing
Pull requests and suggestions are welcome! Please open an issue or PR for bugs, features, or improvements.

---

## 📄 License
MIT 