let currentUI = null;
let currentUIId = null;
let cleanupHandlers = [];
let listMenuStack = [];
let darkMode = false;
let windowOpacity = 0.95; // Default window opacity 95%
let freeDrag = false; // Default drag disabled

// Helper functions for better code reuse
function resetUIState() {
    currentUI = null;
    currentUIId = null;
}

function animateUIClose(containerId, callback) {
    const container = document.getElementById(containerId);
    if (!container) return;
    const win = container.querySelector('.window');
    win.classList.remove('open');
    win.classList.add('close');
    setTimeout(() => {
        container.style.display = 'none';
        if (callback) callback();
    }, 300);
}

function sendNUIMessage(endpoint, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

function sendCloseMessage() {
    sendNUIMessage('close');
}

function addEscapeHandler(handler) {
    const escHandler = function(e) {
        if (e.key === 'Escape') {
            handler();
        }
    };
    document.addEventListener('keyup', escHandler);
    cleanupHandlers.push(() => document.removeEventListener('keyup', escHandler));
}

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        case 'showAmount':
            showAmountUI(data.title);
            break;
        case 'showList':
            showListUI(data.title, data.items, data.isSubmenu);
            break;
        case 'showSubMenu':
            showSubMenu(data.title, data.items);
            break;
        case 'showDropdown':
            showDropdownUI(data.title, data.options, data.selectedIndex);
            break;
        case 'showSettings':
            showSettingsUI();
            break;
        case 'toggleDarkMode':
            toggleDarkMode();
            break;
    }
});

function showUI(containerId) {
    closeCurrentUI();
    const container = document.getElementById(containerId);
    if (!container) return;
    container.style.display = 'flex';
    const win = container.querySelector('.window');
    win.classList.remove('close');
    win.classList.add('open');
    currentUIId = containerId;
}

function hideUI(containerId, cb) {
    animateUIClose(containerId, cb);
    if (currentUIId === containerId) currentUIId = null;
}

function closeCurrentUI() {
    if (currentUIId) {
        hideUI(currentUIId);
    }
    // Cleanup document-level handlers
    cleanupHandlers.forEach(fn => fn());
    cleanupHandlers = [];
}

function closeAndSendData(containerId, endpoint, data) {
    animateUIClose(containerId, () => {
        resetUIState();
        sendNUIMessage(endpoint, data);
    });
}

function showAmountUI(title) {
    currentUI = 'amount';
    showUI('amount-ui');
    document.getElementById('list-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    document.querySelector('#amount-ui .titlebar-title').textContent = title;
    document.getElementById('amount-input').value = '';
    document.getElementById('amount-input').focus();
    
    setupMouseReactiveEffects();
    addEscapeHandler(closeUI);
}

function showListUI(title, items, isSubmenu) {
    currentUI = 'list';
    showUI('list-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    document.querySelector('#list-ui .titlebar-title').textContent = title;
    
    // Clear list items
    const listContainer = document.getElementById('list-items');
    listContainer.innerHTML = '';
    
    // Add items
    items.forEach((item, index) => {
        const itemElement = document.createElement('div');
        itemElement.className = 'list-item';
        
        if (item.disabled) {
            itemElement.classList.add('disabled');
        }
        
        const itemContent = document.createElement('div');
        itemContent.className = 'list-item-content';
        
        let innerContent = '';
        if (item.icon) {
            innerContent += `<div class="list-item-icon">${item.icon}</div>`;
        }
        innerContent += `<span>${item.label}</span>`;
        itemContent.innerHTML = innerContent;
        
        itemElement.appendChild(itemContent);
        
        // Add description if exists
        if (item.description) {
            const descElement = document.createElement('div');
            descElement.className = 'list-item-desc';
            descElement.textContent = item.description;
            itemElement.appendChild(descElement);
        }
        
        // Add click handler
        if (!item.disabled) {
            itemElement.onclick = function() {
                selectListItem(index, item);
            };
        }
        
        listContainer.appendChild(itemElement);
        
        // Check if the text is overflowing and add scroll animation
        setTimeout(() => {
            if (itemContent.scrollWidth > itemContent.clientWidth) {
                itemContent.classList.add('scroll');
                const textSpan = itemContent.querySelector('span');
                
                // Only animate on hover
                itemElement.addEventListener('mouseenter', () => {
                    textSpan.classList.add('scroll-animate');
                });
                
                itemElement.addEventListener('mouseleave', () => {
                    textSpan.classList.remove('scroll-animate');
                });
            }
        }, 10);
    });
    
    setupMouseReactiveEffects();
    addEscapeHandler(() => {
        if (listMenuStack.length > 0 && !isSubmenu) {
            const prevMenu = listMenuStack.pop();
            showListUI(prevMenu.title, prevMenu.items, true);
        } else {
            closeUI();
        }
    });
}

function showSubMenu(title, items) {
    showListUI(title, items);
}

function showDropdownUI(title, options, selectedIndex = -1) {
    currentUI = 'dropdown';
    showUI('dropdown-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('list-ui').style.display = 'none';
    
    const titleEl = document.querySelector('#dropdown-ui .titlebar-title');
    titleEl.textContent = title;
    
    const label = document.getElementById('dropdown-label-text');
    const list = document.getElementById('dropdown-list');
    const dropdownLabel = document.getElementById('dropdown-label');
    const cancelBtn = document.getElementById('dropdown-cancel');
    const submitBtn = document.getElementById('dropdown-submit');
    
    // Clear previous dropdown items
    list.innerHTML = '';
    
    // Set default label
    label.textContent = selectedIndex >= 0 && selectedIndex < options.length 
        ? options[selectedIndex] 
        : 'Select an option';
    
    // Add dropdown options
    let currentSelected = selectedIndex;
    options.forEach((option, index) => {
        const item = document.createElement('div');
        item.className = 'dropdown-item';
        if (index === currentSelected) {
            item.classList.add('selected');
        }
        item.textContent = option;
        
        item.onclick = function() {
            // Unselect previous
            const previousSelected = list.querySelector('.selected');
            if (previousSelected) {
                previousSelected.classList.remove('selected');
            }
            
            // Select this item
            item.classList.add('selected');
            currentSelected = index;
            label.textContent = option;
            
            // Close dropdown list but not the whole UI
            list.classList.remove('open');
            dropdownLabel.classList.remove('open');
        };
        
        list.appendChild(item);
    });
    
    // Toggle dropdown on label click
    dropdownLabel.onclick = function() {
        dropdownLabel.classList.toggle('open');
        list.classList.toggle('open');
    };
    
    // Cancel button
    cancelBtn.onclick = function() {
        closeAndSendData('dropdown-ui', 'close');
    };
    
    // Submit button
    submitBtn.onclick = function() {
        if (currentSelected >= 0) {
            closeAndSendData('dropdown-ui', 'dropdownSelect', { 
                index: currentSelected, 
                value: options[currentSelected] 
            });
        } else {
            closeAndSendData('dropdown-ui', 'close');
        }
    };
    
    setupMouseReactiveEffects();
    addEscapeHandler(() => {
        // If dropdown list is open, just close it
        if (list.classList.contains('open')) {
            list.classList.remove('open');
            dropdownLabel.classList.remove('open');
        } else {
            // Otherwise close the whole UI
            closeUI();
        }
    });
}

function selectListItem(index, item) {
    closeAndSendData('list-ui', 'listSelect', {
        index: index,
        item: item
    });
}

function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        closeAndSendData('amount-ui', 'amountSubmit', {
            amount: amount
        });
    }
}

function closeUI() {
    // Check if we're in the middle of dragging
    if (currentUIId && $(`#${currentUIId}`).data('isDragging')) {
        return; // Don't close if dragging
    }
    
    // Hide all UIs
    ['amount-ui', 'list-ui', 'dropdown-ui', 'settings-ui'].forEach(id => {
        animateUIClose(id);
    });
    
    // Cleanup document-level handlers
    cleanupHandlers.forEach(fn => fn());
    cleanupHandlers = [];
    
    // Send close message
    resetUIState();
    sendCloseMessage();
}

// Handle Enter key for amount input
document.getElementById('amount-input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        submitAmount();
    }
});

// Mouse tracking for reactive header effects - disabled
function setupMouseReactiveEffects() {
    // Effects removed
}

// Cloud pattern functions - disabled
function createCloudPatterns() {
    // Function disabled
}

function createStaticCloudPattern() {
    // Function disabled
}

function createCloudPattern() {
    // Function disabled
}

// Function to enable/disable draggable functionality
function toggleDraggable(enable) {
    const windows = document.querySelectorAll('.window');
    windows.forEach(win => {
        if (enable) {
            win.classList.add('draggable');
            // Initialize jQuery UI draggable
            $(win).draggable({
                handle: '.titlebar',
                containment: 'window',
                start: function() {
                    // Prevent drag from closing UI
                    $(this).parent().data('isDragging', true);
                },
                stop: function() {
                    // Allow time for click events to process before resetting
                    setTimeout(() => {
                        $(this).parent().data('isDragging', false);
                    }, 100);
                }
            });
        } else {
            win.classList.remove('draggable');
            // Remove draggable functionality
            if ($(win).hasClass('ui-draggable')) {
                $(win).draggable('destroy');
            }
            // Reset position
            win.style.top = '';
            win.style.left = '';
        }
    });
}

// Apply free drag setting
function applyFreeDrag(enabled, shouldSave) {
    // Only update if the state is different or we're not saving
    if (enabled !== freeDrag || !shouldSave) {
        // Update the state
        freeDrag = enabled;
        
        // Apply draggable functionality
        toggleDraggable(enabled);
        
        // Save preference if requested
        if (shouldSave) {
            // Save preference to localStorage
            localStorage.setItem('eskui_freeDrag', freeDrag ? 'true' : 'false');
            
            // Notify client-side script of the change
            sendNUIMessage('freeDragChanged', { freeDrag });
        }
    }
}

// Show settings UI
function showSettingsUI() {
    currentUI = 'settings';
    showUI('settings-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('list-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    
    // Add specific close button handler for settings UI
    const settingsCloseBtn = document.querySelector('#settings-ui .close-button');
    if (settingsCloseBtn) {
        settingsCloseBtn.onclick = function() {
            closeUI();
        };
    }
    
    // Set the toggle to match current dark mode setting
    document.getElementById('dark-mode-toggle').checked = darkMode;
    
    // Set the opacity slider to current opacity value
    const opacitySlider = document.getElementById('opacity-slider');
    const opacityValue = document.getElementById('opacity-value');
    opacitySlider.value = Math.round(windowOpacity * 100);
    opacityValue.textContent = `${opacitySlider.value}%`;
    
    // Set the free drag toggle to current state
    document.getElementById('free-drag-toggle').checked = freeDrag;
    
    // Store original settings to restore if canceled
    const originalDarkMode = darkMode;
    const originalOpacity = windowOpacity;
    const originalFreeDrag = freeDrag;
    
    // Add event listeners for dark mode
    document.getElementById('dark-mode-toggle').addEventListener('change', function(e) {
        // Apply dark mode immediately for preview, but don't save to storage yet
        applyDarkMode(e.target.checked, false);
    });
    
    // Add event listener for opacity slider
    opacitySlider.addEventListener('input', function() {
        const value = parseInt(this.value);
        opacityValue.textContent = `${value}%`;
        applyOpacity(value / 100, false); // Preview opacity without saving
    });
    
    // Add event listener for free drag toggle
    document.getElementById('free-drag-toggle').addEventListener('change', function(e) {
        // Apply free drag immediately for preview, but don't save to storage yet
        applyFreeDrag(e.target.checked, false);
    });
    
    // Override standard close handler to restore original settings if not saved
    addEscapeHandler(() => {
        // Restore original settings if ESC is pressed without saving
        applyDarkMode(originalDarkMode, false);
        applyOpacity(originalOpacity, false);
        applyFreeDrag(originalFreeDrag, false);
        closeUI();
    });
    
    // Override cancel button to restore original settings
    const cancelButton = document.querySelector('#settings-ui .button.cancel');
    if (cancelButton) {
        cancelButton.onclick = () => {
            // Restore original settings if Cancel is pressed
            applyDarkMode(originalDarkMode, false);
            applyOpacity(originalOpacity, false);
            applyFreeDrag(originalFreeDrag, false);
            closeUI();
        };
    }
}

// Save settings from the settings UI
function saveSettings() {
    // Get toggle state
    const darkModeToggle = document.getElementById('dark-mode-toggle');
    const newDarkModeSetting = darkModeToggle.checked;
    
    // Get opacity value
    const opacitySlider = document.getElementById('opacity-slider');
    const newOpacity = parseInt(opacitySlider.value) / 100;
    
    // Get free drag state
    const freeDragToggle = document.getElementById('free-drag-toggle');
    const newFreeDrag = freeDragToggle.checked;
    
    // Apply and save all settings
    applyDarkMode(newDarkModeSetting, true);
    applyOpacity(newOpacity, true);
    applyFreeDrag(newFreeDrag, true);
    
    // Close the settings UI
    closeAndSendData('settings-ui', 'close');
}

// Apply opacity setting
function applyOpacity(opacity, shouldSave) {
    // Only update if the state is different or we're not saving
    if (opacity !== windowOpacity || !shouldSave) {
        // Update the state
        windowOpacity = opacity;
        
        // Apply to all window elements
        const windows = document.querySelectorAll('.window');
        windows.forEach(win => {
            win.style.backgroundColor = darkMode 
                ? `rgba(28, 28, 30, ${opacity})` 
                : `rgba(255, 255, 255, ${opacity})`;
        });
        
        // Save preference if requested
        if (shouldSave) {
            // Save preference to localStorage
            localStorage.setItem('eskui_windowOpacity', windowOpacity.toString());
            
            // Notify client-side script of the change
            sendNUIMessage('opacityChanged', { windowOpacity });
        }
    }
}

// Apply dark mode without toggling
function applyDarkMode(enabled, shouldSave) {
    // Only update if the state is different
    if (enabled !== darkMode || !shouldSave) {
        // Update the state
        darkMode = enabled;
        
        // Update the UI
        if (darkMode) {
            document.body.classList.add('dark-mode');
        } else {
            document.body.classList.remove('dark-mode');
        }
        
        // Update opacity color based on theme
        applyOpacity(windowOpacity, false);
        
        // Save preference if requested
        if (shouldSave) {
            // Save preference to localStorage
            localStorage.setItem('eskui_darkMode', darkMode ? 'true' : 'false');
            
            // Notify client-side script of the change
            sendNUIMessage('darkModeChanged', { darkMode: darkMode });
        }
    }
}

// Dark mode toggle function
function toggleDarkMode() {
    applyDarkMode(!darkMode, true);
}

// Initialize dark mode and opacity from saved preferences
function initializeSettings() {
    // Initialize dark mode
    const savedMode = localStorage.getItem('eskui_darkMode');
    if (savedMode === 'true') {
        applyDarkMode(true, false);
    }
    
    // Initialize opacity
    const savedOpacity = localStorage.getItem('eskui_windowOpacity');
    if (savedOpacity) {
        applyOpacity(parseFloat(savedOpacity), false);
    } else {
        // Default opacity
        applyOpacity(windowOpacity, false);
    }
    
    // Initialize free drag
    const savedFreeDrag = localStorage.getItem('eskui_freeDrag');
    if (savedFreeDrag === 'true') {
        applyFreeDrag(true, false);
    }
}

// Call initialization when the script loads
initializeSettings(); 