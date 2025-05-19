# ESKUI - Modern FiveM NUI UI Framework

A sleek, modern, and extensible UI framework for FiveM, designed for professional-quality user interfaces with vibrant, animated, and macOS-inspired aesthetics. ESKUI provides easy-to-use exports for common UI patterns: amount input, list selection, and dropdown menus.

---

## ✨ Features
- **Modern macOS-style UI**: Clean, vibrant, and animated.
- **Amount Input**: Prompt users for a numeric value.
- **List Selection**: Show a list of items, with support for long text and submenus.
- **Dropdown**: Modern dropdown with animated open/close, cancel/submit, and icon.
- **Keyboard and mouse support**: Enter, Escape, click, and more.
- **Extensible**: Add new UI types easily with shared animation and state management.
- **Robust event handling**: No event leaks, safe for repeated use.

---

## 📦 Installation
1. Place the `eskui` folder in your FiveM resources directory.
2. Add `ensure eskui` to your `server.cfg`.
3. (Optional) Add `eskui` as a dependency in your resource manifest if you use it from another resource.

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
Show a list of items and get the selected one:
```lua
local items = {
    {label = 'Item 1', price = 100},
    {label = 'Item 2', price = 200},
    {label = 'A very long item name that will scroll on hover', price = 300},
}
exports['eskui']:ShowList('Select an Item', items, function(index, item)
    if index and item then
        print(('Selected: %s (index %d)'):format(item.label, index))
    end
end)
```

#### With Submenus
```lua
exports['eskui']:ShowList('Select Category', categories, function(index, item)
    print('Final selection:', item.label)
end, function(index, item)
    if item.id == 'cat1' then
        return {
            title = 'Category 1 Items',
            items = {
                {label = 'Sub Item 1', price = 100},
                {label = 'Sub Item 2', price = 200}
            }
        }
    end
    return nil -- No submenu, close UI
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

---

## 🛠️ Advanced
- All UI types are animated and use a shared show/hide system for consistency.
- Only one UI can be open at a time.
- All event handlers are cleaned up automatically.
- You can add new UI types by following the pattern in `html/script.js` and `client.lua`.

---

## 🖌️ Customization
- Edit `html/styles.css` for colors, animations, and layout.
- UI is fully responsive and works with keyboard and mouse.

---

## 🧑‍💻 Contributing
Pull requests and suggestions are welcome! Please open an issue or PR for bugs, features, or improvements.

---

## 📄 License
MIT 