// UI state management
const state = {
    currentUI: null,
    currentUIId: null,
    cleanupHandlers: [],
    darkMode: false,
    windowOpacity: 0.95,
    freeDrag: false,
    selectedListItem: null,
    // Shopping cart state (managed in shops.js)
    cart: [],
    currentCategory: null,
    shopItems: []
};

// Console log for debugging
console.log("ESKUI script initialized");

// Helper functions for UI management
const ui = {
    resetState() {
        state.currentUI = null;
        state.currentUIId = null;
        state.selectedListItem = null;
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
        // Only close current UI if it's different from the one we're showing
        // This preserves state when navigating between submenus
        if (state.currentUIId && state.currentUIId !== containerId) {
            this.hide(state.currentUIId);
        }
        
        const container = document.getElementById(containerId);
        if (!container) return;
        
        container.style.display = 'flex';
        this.animate(containerId, false);
        state.currentUIId = containerId;
        
        // Hide interaction prompt when any UI is shown
        notifyUIVisibilityChange(true);
    },
    
    hide(containerId, callback) {
        this.animate(containerId, true, callback);
        
        // If we're closing the UI completely
        if (state.currentUIId === containerId) {
            state.currentUIId = null;
            
            // If no other UIs are visible, can show interaction prompt
            setTimeout(() => {
                if (!state.currentUIId) {
                    notifyUIVisibilityChange(false);
                }
            }, 300); // Wait for animation to complete
        }
    },
    
    closeCurrentUI() {
        if (state.currentUIId) {
            this.hide(state.currentUIId);
        }
        // Cleanup document-level handlers
        state.cleanupHandlers.forEach(fn => fn());
        state.cleanupHandlers = [];
        
        // Clear any water shimmer elements that might be lingering
        clearGlowEffects();
        
        // Ensure NUI focus is reset
        sendNUIMessage('close');
    },
    
    closeAndSendData(containerId, endpoint, data) {
        this.animate(containerId, true, () => {
            this.resetState();
            sendNUIMessage(endpoint, data);
            
            // Always send a close message to ensure NUI focus is released
            if (endpoint !== 'close') {
                setTimeout(() => {
                    sendNUIMessage('close');
                }, 100);
            }
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
        ['amount-ui', 'list-ui', 'dropdown-ui', 'settings-ui', 'shopping-ui'].forEach(id => {
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

// Helper function to clear all glow effects
function clearGlowEffects(element) {
    const selector = '.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left';
    if (element) {
        element.querySelectorAll(selector).forEach(el => el.remove());
    } else {
        document.querySelectorAll(selector).forEach(el => el.remove());
    }
}

// Helper function to add glow effects to an element
function addGlowEffects(element) {
    // Clear existing glow effects first
    clearGlowEffects(element);
    
    // Create and add individual glow segments for independent animation
    const glowSegments = ['top', 'right', 'bottom', 'left'];
    glowSegments.forEach(side => {
        const glowElement = document.createElement('div');
        glowElement.className = `glow-${side}`;
        element.appendChild(glowElement);
    });
    
    // Create and add water shimmer element for the glow effect
    const shimmer = document.createElement('div');
    shimmer.className = 'water-shimmer';
    element.appendChild(shimmer);
}

// Helper function to fade out glow effects
function fadeOutGlowEffects(element) {
    const glowElements = element.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left');
    glowElements.forEach(el => {
        el.style.transition = 'opacity 0.25s ease';
        el.style.opacity = '0';
        
        // Remove after fade completes
        setTimeout(() => el.remove(), 250);
    });
}

// Communication functions
function sendNUIMessage(endpoint, data = {}) {
    console.log(`Sending NUI message to endpoint: ${endpoint}`, data);
    
    try {
        fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).catch(error => {
            console.error('Error sending NUI message:', error);
        });
    } catch (error) {
        console.error('Exception sending NUI message:', error);
    }
}

// UI type handlers
const uiHandlers = {
    // Menu UI handlers are now imported from menus.js
    showAmount: menuHandlers.showAmount.bind(menuHandlers),
    showList: menuHandlers.showList.bind(menuHandlers),
    showDropdown: menuHandlers.showDropdown.bind(menuHandlers),
    hideOtherUIs: menuHandlers.hideOtherUIs.bind(menuHandlers),
    
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
        
        // Notify that UI is now visible
        notifyUIVisibilityChange(true);
    }
    
    // Shop UI handlers moved to shops.js
};

// Notification system
const notifications = {
    counter: 0,
    active: {},
    
    create(data) {
        const id = `notification-${++this.counter}`;
        const container = document.getElementById('notifications-container');
        
        console.log('Creating notification with data:', data);
        
        // Set defaults
        const options = {
            type: data.notificationType || 'info',
            title: data.title || 'Notification',
            message: data.message || '',
            duration: data.duration || 5000,
            // Allow custom icon or use default based on type
            icon: data.icon || this.getIconForType(data.notificationType || 'info'),
            closable: data.closable !== false
        };
        
        // Create notification element and add to DOM
        const notification = this.createNotificationElement(id, options);
        container.appendChild(notification);
        
        // Animate progress bar
        this.animateProgressBar(notification, options.duration);
        
        // Set auto-close timer
        const timer = setTimeout(() => this.close(id), options.duration);
        
        // Store notification data
        this.active[id] = { element: notification, timer };
        
        console.log(`Created notification: ${id}`, options);
        return id;
    },
    
    createNotificationElement(id, options) {
        // Create notification element
        const notification = document.createElement('div');
        notification.id = id;
        notification.className = `notification ${options.type}`;
        
        // Create content
        notification.innerHTML = `
            <div class="notification-icon">${options.icon}</div>
            <div class="notification-content">
                <div class="notification-title">${options.title}</div>
                <div class="notification-message">${options.message}</div>
            </div>
            ${options.closable ? '<button class="notification-close">×</button>' : ''}
            <div class="notification-progress"></div>
        `;
        
        // Add close button handler
        if (options.closable) {
            const closeBtn = notification.querySelector('.notification-close');
            closeBtn.addEventListener('click', () => this.close(id));
        }
        
        // Apply current opacity setting
        notification.style.backgroundColor = state.darkMode 
            ? `rgba(28, 28, 30, ${state.windowOpacity})` 
            : `rgba(255, 255, 255, ${state.windowOpacity})`;
            
        return notification;
    },
    
    animateProgressBar(notification, duration) {
        const progressBar = notification.querySelector('.notification-progress');
        progressBar.animate([
            { transform: 'scaleX(1)', opacity: 1 },
            { transform: 'scaleX(0)', opacity: 0.7 }
        ], {
            duration: duration,
            easing: 'cubic-bezier(0.4, 0, 0.2, 1)', // Material Design standard easing
            fill: 'forwards'
        });
    },
    
    close(id) {
        const notification = this.active[id];
        if (!notification) return;
        
        // Clear timer to prevent multiple close calls
        clearTimeout(notification.timer);
        
        // Add exit animation
        notification.element.classList.add('exit');
        
        // Remove after animation completes
        setTimeout(() => {
            if (notification.element.parentNode) {
                notification.element.parentNode.removeChild(notification.element);
            }
            delete this.active[id];
        }, 350);
    },
    
    closeAll() {
        Object.keys(this.active).forEach(id => this.close(id));
    },
    
    getIconForType(type) {
        const icons = {
            success: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                <polyline points="22 4 12 14.01 9 11.01"></polyline>
            </svg>`,
            error: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="15" y1="9" x2="9" y2="15"></line>
                <line x1="9" y1="9" x2="15" y2="15"></line>
            </svg>`,
            warning: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
                <line x1="12" y1="9" x2="12" y2="13"></line>
                <line x1="12" y1="17" x2="12.01" y2="17"></line>
            </svg>`,
            info: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="16" x2="12" y2="12"></line>
                <line x1="12" y1="8" x2="12.01" y2="8"></line>
            </svg>`
        };
        return icons[type] || icons.info;
    }
};

// Event handler system
const eventHandlerSystem = {
    registerHandlers(handlers, data) {
        if (!handlers || !data || !data.type) return;
        
        const handler = handlers[data.type];
        if (handler) {
            try {
                handler(data);
            } catch (error) {
                console.error(`Error executing handler for ${data.type}:`, error);
            }
        } else {
            console.warn('Unknown message type:', data.type);
        }
    }
};

// Event handlers
window.addEventListener('message', function(event) {
    const data = event.data;
    
    // Log received events for debugging
    console.log('Received NUI event:', data?.type, data);
    
    // Extra safety check
    if (!data || !data.type) {
        console.error('Received invalid message event:', event);
        return;
    }
    
    try {
        const handlers = {
            showAmount: () => {
                console.log('Processing showAmount event');
                uiHandlers.showAmount(data.title);
            },
            showList: () => {
                console.log('Processing showList event, isSubmenu:', data.isSubmenu);
                // Important: For submenus, make sure we don't reset the UI state
                uiHandlers.showList(data.title, data.items, data.isSubmenu);
                
                // Set a timeout to verify the UI is still visible
                setTimeout(() => {
                    const container = document.getElementById('list-ui');
                    if (container && container.style.display !== 'flex') {
                        console.error('UI was hidden unexpectedly! Restoring visibility');
                        container.style.display = 'flex';
                    }
                }, 500);
            },
            showDropdown: () => {
                console.log('Processing showDropdown event');
                uiHandlers.showDropdown(data.title, data.options, data.selectedIndex);
            },
            showSettings: () => {
                console.log('Processing showSettings event');
                uiHandlers.showSettings();
            },
            // Shop UI handler moved to shops.js
            showShop: () => {
                console.log('Processing showShop event');
                shopEventHandlers.showShop(data);
            },
            toggleDarkMode: () => toggleDarkMode(),
            showNotification: () => {
                console.log('Processing showNotification event', data);
                // Create the notification
                notifications.create(data);
            }
        };
        
        eventHandlerSystem.registerHandlers(handlers, data);
    } catch (error) {
        console.error('Error handling message event:', error);
    }
});

// UI action functions
function closeUI() {
    console.log("closeUI function called");
    ui.closeCurrentUI();
    
    // Explicitly send close message to ensure NUI focus is reset
    sendNUIMessage('close');
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
        
        document.querySelectorAll('.window, .notification').forEach(element => {
            element.style.backgroundColor = state.darkMode 
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
        const bodyEl = document.body;
        
        if (enabled) {
            bodyEl.classList.add('dark-mode');
        } else {
            bodyEl.classList.remove('dark-mode');
        }
        
        // Apply opacity with dark mode in mind
        applyOpacity(state.windowOpacity, false);
        
        // Update interaction prompt to match dark mode setting
        updateInteractionDarkMode(enabled);
        
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

// Also add an interval-based cleanup to periodically check for and remove duplicate glow elements
function setupGlowEffectCleanup() {
    // Create a cleanup interval that runs every 500ms
    const glowCleanupInterval = setInterval(() => {
        if (!state.currentUIId) {
            clearInterval(glowCleanupInterval);
            return;
        }
        
        // For each list item, ensure it has at most one of each glow element
        document.querySelectorAll('.list-item').forEach(item => {
            // Get all glow elements
            const glowElements = {
                top: item.querySelectorAll('.glow-top'),
                right: item.querySelectorAll('.glow-right'),
                bottom: item.querySelectorAll('.glow-bottom'),
                left: item.querySelectorAll('.glow-left'),
                shimmer: item.querySelectorAll('.water-shimmer')
            };
            
            // Remove extras if there are more than one of each
            Object.values(glowElements).forEach(elements => {
                if (elements.length > 1) {
                    for (let i = 1; i < elements.length; i++) {
                        elements[i].remove();
                    }
                }
            });
            
            // If item is not selected, remove all glow elements
            if (!item.classList.contains('selected')) {
                clearGlowEffects(item);
            }
        });
    }, 500);
    
    // Add the interval to cleanup handlers so it gets cleared when UI is closed
    state.cleanupHandlers.push(() => clearInterval(glowCleanupInterval));
}

// Interaction System
// Show/hide the interaction iframe
function setupInteractionFrame() {
    const frame = document.getElementById('interaction-frame');
    
    // Show the iframe when it's needed
    frame.style.display = 'block';
    
    // Listen for messages from the parent (main UI) to the iframe
    window.addEventListener('message', function(event) {
        if (!event.data) return;
        
        const data = event.data;
        
        // Force hide interaction when any UI is shown
        if (data.type && data.type.startsWith('show') && data.type !== 'showInteraction') {
            // Hide any interaction prompt when a UI is shown
            const iframeWindow = frame.contentWindow;
            if (iframeWindow) {
                iframeWindow.postMessage({
                    type: 'hideInteraction'
                }, '*');
            }
        }
        
        // Pass interaction messages to the iframe
        if (data.type === 'showInteraction' || data.type === 'hideInteraction') {
            // Get the iframe window
            const iframeWindow = frame.contentWindow;
            if (iframeWindow) {
                // Check if any UI is currently visible
                if (data.type === 'showInteraction' && state.currentUIId) {
                    console.log('Not showing interaction prompt - UI is visible:', state.currentUIId);
                    return; // Don't show interaction if UI is visible
                }
                
                // Forward the message to the iframe
                iframeWindow.postMessage(data, '*');
            }
        }
    });
    
    // Also add a custom event listener for UI visibility changes
    document.addEventListener('ui-visibility-change', function(e) {
        const isVisible = e.detail.visible;
        const iframeWindow = frame.contentWindow;
        
        if (iframeWindow && !isVisible) {
            // When UI is hidden, check if we should show interaction prompt
            console.log('UI hidden, checking if interaction prompt should be shown');
            // Nothing to do here - game will handle showing interaction
        } else if (iframeWindow && isVisible) {
            // When UI is shown, hide interaction prompt
            console.log('UI shown, hiding interaction prompt');
            iframeWindow.postMessage({
                type: 'hideInteraction'
            }, '*');
        }
    });
}

// Function to dispatch UI visibility change events
function notifyUIVisibilityChange(visible) {
    // Create and dispatch a custom event
    const event = new CustomEvent('ui-visibility-change', {
        detail: { visible: visible }
    });
    document.dispatchEvent(event);
}

// Update interaction frame dark mode when main UI dark mode changes
function updateInteractionDarkMode(isDarkMode) {
    const frame = document.getElementById('interaction-frame');
    const iframeWindow = frame.contentWindow;
    
    if (iframeWindow) {
        // Send dark mode update to interaction iframe
        iframeWindow.postMessage({
            type: 'updateInteractionDarkMode',
            config: {
                darkMode: isDarkMode
            }
        }, '*');
    }
}

// Initialize the interaction system when the page loads
document.addEventListener('DOMContentLoaded', function() {
    // Setup the interaction frame
    setupInteractionFrame();
}); 