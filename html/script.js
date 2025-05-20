// UI state management
const state = {
    currentUI: null,
    currentUIId: null,
    cleanupHandlers: [],
    listMenuStack: [],
    darkMode: false,
    windowOpacity: 0.95,
    freeDrag: false
};

// Helper functions for UI management
const ui = {
    resetState() {
        state.currentUI = null;
        state.currentUIId = null;
    },
    
    animate(containerId, isClosing, callback) {
        const container = document.getElementById(containerId);
        if (!container) return;
        
        const win = container.querySelector('.window');
        win.classList.remove(isClosing ? 'open' : 'close');
        win.classList.add(isClosing ? 'close' : 'open');
        
        if (isClosing) {
            setTimeout(() => {
                container.style.display = 'none';
                if (callback) callback();
            }, 300);
        }
    },
    
    show(containerId) {
        this.closeCurrentUI();
        const container = document.getElementById(containerId);
        if (!container) return;
        
        container.style.display = 'flex';
        this.animate(containerId, false);
        state.currentUIId = containerId;
    },
    
    hide(containerId, callback) {
        this.animate(containerId, true, callback);
        if (state.currentUIId === containerId) state.currentUIId = null;
    },
    
    closeCurrentUI() {
        if (state.currentUIId) {
            this.hide(state.currentUIId);
        }
        // Cleanup document-level handlers
        state.cleanupHandlers.forEach(fn => fn());
        state.cleanupHandlers = [];
    },
    
    closeAndSendData(containerId, endpoint, data) {
        this.animate(containerId, true, () => {
            this.resetState();
            sendNUIMessage(endpoint, data);
        });
    },
    
    addEscapeHandler(handler) {
        const escHandler = e => e.key === 'Escape' && handler();
        document.addEventListener('keyup', escHandler);
        state.cleanupHandlers.push(() => document.removeEventListener('keyup', escHandler));
    },
    
    hideAllUIs() {
        // Check if we're in the middle of dragging
        if (state.currentUIId && $(`#${state.currentUIId}`).data('isDragging')) {
            return; // Don't close if dragging
        }
        
        // Hide all UIs
        ['amount-ui', 'list-ui', 'dropdown-ui', 'settings-ui'].forEach(id => {
            this.animate(id, true);
        });
        
        // Cleanup document-level handlers
        state.cleanupHandlers.forEach(fn => fn());
        state.cleanupHandlers = [];
        
        // Reset state and send close message
        this.resetState();
        sendNUIMessage('close');
    }
};

// Communication functions
function sendNUIMessage(endpoint, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

// UI type handlers
const uiHandlers = {
    showAmount(title) {
        state.currentUI = 'amount';
        ui.show('amount-ui');
        this.hideOtherUIs('amount-ui');
        
        document.querySelector('#amount-ui .titlebar-title').textContent = title;
        const input = document.getElementById('amount-input');
        input.value = '';
        input.focus();
        
        ui.addEscapeHandler(() => closeUI());
    },
    
    showList(title, items, isSubmenu) {
        state.currentUI = 'list';
        ui.show('list-ui');
        this.hideOtherUIs('list-ui');
        
        document.querySelector('#list-ui .titlebar-title').textContent = title;
        
        // Clear and populate list items
        const listContainer = document.getElementById('list-items');
        listContainer.innerHTML = '';
        
        // Add items
        items.forEach((item, index) => {
            const itemElement = document.createElement('div');
            itemElement.className = 'list-item' + (item.disabled ? ' disabled' : '');
            
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
            
            // Add click handler if not disabled
            if (!item.disabled) {
                itemElement.onclick = () => selectListItem(index, item);
            }
            
            listContainer.appendChild(itemElement);
            
            // Check if text is overflowing and add scroll animation
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
        
        ui.addEscapeHandler(() => {
            if (state.listMenuStack.length > 0 && !isSubmenu) {
                const prevMenu = state.listMenuStack.pop();
                this.showList(prevMenu.title, prevMenu.items, true);
            } else {
                closeUI();
            }
        });
    },
    
    showDropdown(title, options, selectedIndex = -1) {
        state.currentUI = 'dropdown';
        ui.show('dropdown-ui');
        this.hideOtherUIs('dropdown-ui');
        
        document.querySelector('#dropdown-ui .titlebar-title').textContent = title;
        
        const label = document.getElementById('dropdown-label-text');
        const list = document.getElementById('dropdown-list');
        const dropdownLabel = document.getElementById('dropdown-label');
        
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
            item.className = 'dropdown-item' + (index === currentSelected ? ' selected' : '');
            item.textContent = option;
            
            item.onclick = function() {
                // Unselect previous and select this item
                list.querySelector('.selected')?.classList.remove('selected');
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
        document.getElementById('dropdown-cancel').onclick = function() {
            ui.closeAndSendData('dropdown-ui', 'close');
        };
        
        // Submit button
        document.getElementById('dropdown-submit').onclick = function() {
            if (currentSelected >= 0) {
                ui.closeAndSendData('dropdown-ui', 'dropdownSelect', { 
                    index: currentSelected, 
                    value: options[currentSelected] 
                });
            } else {
                ui.closeAndSendData('dropdown-ui', 'close');
            }
        };
        
        ui.addEscapeHandler(() => {
            // If dropdown list is open, just close it
            if (list.classList.contains('open')) {
                list.classList.remove('open');
                dropdownLabel.classList.remove('open');
            } else {
                // Otherwise close the whole UI
                closeUI();
            }
        });
    },
    
    showSettings() {
        state.currentUI = 'settings';
        ui.show('settings-ui');
        this.hideOtherUIs('settings-ui');
        
        // Set current settings values
        document.getElementById('dark-mode-toggle').checked = state.darkMode;
        
        const opacitySlider = document.getElementById('opacity-slider');
        const opacityValue = document.getElementById('opacity-value');
        opacitySlider.value = Math.round(state.windowOpacity * 100);
        opacityValue.textContent = `${opacitySlider.value}%`;
        
        document.getElementById('free-drag-toggle').checked = state.freeDrag;
        
        // Store original settings to restore if canceled
        const originalSettings = {
            darkMode: state.darkMode,
            opacity: state.windowOpacity,
            freeDrag: state.freeDrag
        };
        
        // Add event listeners for interactive settings
        document.getElementById('dark-mode-toggle').addEventListener('change', e => {
            applyDarkMode(e.target.checked, false);
        });
        
        opacitySlider.addEventListener('input', function() {
            const value = parseInt(this.value);
            opacityValue.textContent = `${value}%`;
            applyOpacity(value / 100, false);
        });
        
        document.getElementById('free-drag-toggle').addEventListener('change', e => {
            applyFreeDrag(e.target.checked, false);
        });
        
        // Override standard close handler to restore original settings
        ui.addEscapeHandler(() => {
            restoreSettings(originalSettings);
            closeUI();
        });
        
        // Override cancel button to restore original settings
        document.querySelector('#settings-ui .button.cancel').onclick = () => {
            restoreSettings(originalSettings);
            closeUI();
        };
        
        // Add specific close button handler
        document.querySelector('#settings-ui .close-button').onclick = closeUI;
    },
    
    hideOtherUIs(currentUI) {
        ['amount-ui', 'list-ui', 'dropdown-ui', 'settings-ui']
            .filter(id => id !== currentUI)
            .forEach(id => document.getElementById(id).style.display = 'none');
    }
};

// Event handlers
window.addEventListener('message', function(event) {
    const data = event.data;
    const handlers = {
        showAmount: () => uiHandlers.showAmount(data.title),
        showList: () => uiHandlers.showList(data.title, data.items, data.isSubmenu),
        showSubMenu: () => uiHandlers.showList(data.title, data.items),
        showDropdown: () => uiHandlers.showDropdown(data.title, data.options, data.selectedIndex),
        showSettings: () => uiHandlers.showSettings(),
        toggleDarkMode: () => toggleDarkMode()
    };
    
    if (handlers[data.type]) {
        handlers[data.type]();
    }
});

// Handle Enter key for amount input
document.getElementById('amount-input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        submitAmount();
    }
});

// UI action functions
function closeUI() {
    ui.hideAllUIs();
}

function selectListItem(index, item) {
    ui.closeAndSendData('list-ui', 'listSelect', {
        index: index,
        item: item
    });
}

function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        ui.closeAndSendData('amount-ui', 'amountSubmit', {
            amount: amount
        });
    }
}

function saveSettings() {
    // Get current settings from UI
    const newSettings = {
        darkMode: document.getElementById('dark-mode-toggle').checked,
        opacity: parseInt(document.getElementById('opacity-slider').value) / 100,
        freeDrag: document.getElementById('free-drag-toggle').checked
    };
    
    // Apply and save all settings
    applyDarkMode(newSettings.darkMode, true);
    applyOpacity(newSettings.opacity, true);
    applyFreeDrag(newSettings.freeDrag, true);
    
    // Close the settings UI
    ui.closeAndSendData('settings-ui', 'close');
}

function restoreSettings(settings) {
    applyDarkMode(settings.darkMode, false);
    applyOpacity(settings.opacity, false);
    applyFreeDrag(settings.freeDrag, false);
}

// Settings management functions
function toggleDraggable(enable) {
    const windows = document.querySelectorAll('.window');
    windows.forEach(win => {
        if (enable) {
            win.classList.add('draggable');
            $(win).draggable({
                handle: '.titlebar',
                containment: 'window',
                start: function() {
                    $(this).parent().data('isDragging', true);
                },
                stop: function() {
                    setTimeout(() => {
                        $(this).parent().data('isDragging', false);
                    }, 100);
                }
            });
        } else {
            win.classList.remove('draggable');
            if ($(win).hasClass('ui-draggable')) {
                $(win).draggable('destroy');
            }
            win.style.top = '';
            win.style.left = '';
        }
    });
}

function applyFreeDrag(enabled, shouldSave) {
    if (enabled !== state.freeDrag || !shouldSave) {
        state.freeDrag = enabled;
        toggleDraggable(enabled);
        
        if (shouldSave) {
            localStorage.setItem('eskui_freeDrag', enabled ? 'true' : 'false');
            sendNUIMessage('freeDragChanged', { freeDrag: enabled });
        }
    }
}

function applyOpacity(opacity, shouldSave) {
    if (opacity !== state.windowOpacity || !shouldSave) {
        state.windowOpacity = opacity;
        
        document.querySelectorAll('.window').forEach(win => {
            win.style.backgroundColor = state.darkMode 
                ? `rgba(28, 28, 30, ${opacity})` 
                : `rgba(255, 255, 255, ${opacity})`;
        });
        
        if (shouldSave) {
            localStorage.setItem('eskui_windowOpacity', opacity.toString());
            sendNUIMessage('opacityChanged', { windowOpacity: opacity });
        }
    }
}

function applyDarkMode(enabled, shouldSave) {
    if (enabled !== state.darkMode || !shouldSave) {
        state.darkMode = enabled;
        
        if (enabled) {
            document.body.classList.add('dark-mode');
        } else {
            document.body.classList.remove('dark-mode');
        }
        
        applyOpacity(state.windowOpacity, false);
        
        if (shouldSave) {
            localStorage.setItem('eskui_darkMode', enabled ? 'true' : 'false');
            sendNUIMessage('darkModeChanged', { darkMode: enabled });
        }
    }
}

function toggleDarkMode() {
    applyDarkMode(!state.darkMode, true);
}

// Initialize settings from saved preferences
function initializeSettings() {
    // Dark mode
    if (localStorage.getItem('eskui_darkMode') === 'true') {
        applyDarkMode(true, false);
    }
    
    // Opacity
    const savedOpacity = localStorage.getItem('eskui_windowOpacity');
    applyOpacity(savedOpacity ? parseFloat(savedOpacity) : state.windowOpacity, false);
    
    // Free drag
    if (localStorage.getItem('eskui_freeDrag') === 'true') {
        applyFreeDrag(true, false);
    }
}

// Initialize when the script loads
initializeSettings(); 