// UI state management
const state = {
    currentUI: null,
    currentUIId: null,
    cleanupHandlers: [],
    darkMode: false,
    windowOpacity: 0.95,
    freeDrag: false,
    selectedListItem: null
};

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
        console.log(`Showing list: ${title}, isSubmenu: ${isSubmenu}, items:`, items);
        
        state.currentUI = 'list';
        
        // Don't close current UI if this is a submenu being shown
        if (isSubmenu) {
            console.log('Showing submenu without closing current UI');
            const container = document.getElementById('list-ui');
            if (container) {
                container.style.display = 'flex';
                const win = container.querySelector('.window');
                win.classList.remove('close');
                win.classList.add('open');
            }
        } else {
            ui.show('list-ui');
        }
        
        this.hideOtherUIs('list-ui');
        
        document.querySelector('#list-ui .titlebar-title').textContent = title;
        
        // Clear and populate list items
        const listContainer = document.getElementById('list-items');
        listContainer.innerHTML = '';
        
        // Reset selected item
        state.selectedListItem = null;
        
        // Ensure items is an array
        let itemsArray = [];
        if (Array.isArray(items)) {
            itemsArray = items;
        } else if (items && typeof items === 'object') {
            // Check if we received an object with an 'items' property
            if (Array.isArray(items.items)) {
                itemsArray = items.items;
                console.log('Using items.items instead:', itemsArray);
            } else {
                console.error('Items is an object but not an array:', items);
                // Add a single error item
                itemsArray = [{
                    label: 'Error: Invalid menu data',
                    description: 'Please report this issue',
                    disabled: true
                }];
            }
        } else {
            console.error('Invalid items data:', items);
            // Add a single error item
            itemsArray = [{
                label: 'Error: No menu items',
                description: 'Please report this issue',
                disabled: true
            }];
        }
        
        // Add items
        itemsArray.forEach((item, index) => {
            const itemElement = document.createElement('div');
            itemElement.className = 'list-item' + (item.disabled ? ' disabled' : '');
            
            const itemContent = document.createElement('div');
            itemContent.className = 'list-item-content';
            
            let innerContent = '';
            if (item.icon) {
                innerContent += `<div class="list-item-icon">${item.icon}</div>`;
            }
            innerContent += `<span>${item.label}</span>`;
            
            // Add submenu indicator if item has a submenu
            if (item.submenu) {
                innerContent += `<div class="submenu-arrow">›</div>`;
            }
            
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
                itemElement.onclick = () => {
                    console.log('Item clicked:', item.label, item);
                    
                    // Add selected class to this item and remove from others
                    listContainer.querySelectorAll('.list-item').forEach(el => {
                        el.classList.remove('selected');
                    });
                    itemElement.classList.add('selected');
                    
                    // Store the selected item and index
                    state.selectedListItem = { index, item };
                    
                    // If it's a submenu or back button, automatically select it without requiring Submit button
                    if (item.submenu || item.isBack) {
                        console.log('Auto-selecting item (submenu or back):', item.label);
                        submitListSelection();
                    }
                };
            }
            
            listContainer.appendChild(itemElement);
            
            // Add divider after each item except the last one
            if (index < itemsArray.length - 1) {
                const divider = document.createElement('div');
                divider.className = 'list-divider';
                listContainer.appendChild(divider);
            }
            
                                // Check if text is overflowing and add scroll animation
                    setTimeout(() => {
                        if (itemContent.scrollWidth > itemContent.clientWidth) {
                            itemContent.classList.add('scroll');
                            const textSpan = itemContent.querySelector('span');
                            
                            // State tracking for robust animation handling
                            const animState = {
                                isScrolling: false,
                                isFadingIn: false,
                                isHovering: false,
                                hoverTimer: null,
                                resetTimer: null,
                                pendingAnimation: null
                            };
                            
                            // Store animation state on the element to prevent race conditions
                            textSpan._animState = animState;
                            
                            // Clean reset function to ensure consistent state
                            const resetAnimationState = () => {
                                // Clear any pending timers
                                if (animState.hoverTimer) clearTimeout(animState.hoverTimer);
                                if (animState.resetTimer) clearTimeout(animState.resetTimer);
                                if (animState.pendingAnimation) cancelAnimationFrame(animState.pendingAnimation);
                                
                                // Remove animations first
                                textSpan.classList.remove('scroll-animate', 'scroll-fade-in');
                                
                                // Apply a clean state with no transition first
                                textSpan.style.transition = 'none';
                                textSpan.style.opacity = '1';
                                
                                // Force reflow before setting position
                                void textSpan.offsetWidth;
                                
                                // Set exact position to ensure consistency
                                textSpan.style.transform = 'translateX(0)';
                                
                                // Force another reflow to ensure position is applied
                                void textSpan.offsetWidth;
                                
                                // Clear any transition style after position is set
                                textSpan.style.transition = '';
                                
                                // Remove resetting class if it exists
                                itemContent.classList.remove('resetting');
                                
                                // Make sure the scroll class is maintained
                                if (!itemContent.classList.contains('scroll')) {
                                    itemContent.classList.add('scroll');
                                }
                                
                                // Reset state flags
                                animState.isScrolling = false;
                                animState.isFadingIn = false;
                            };
                            
                            // Start scrolling with debounce
                            const startScrolling = () => {
                                // Don't restart if already scrolling
                                if (animState.isScrolling) return;
                                
                                // Reset and prepare for scrolling
                                resetAnimationState();
                                
                                // Always ensure starting position is exactly at 0
                                textSpan.style.transform = 'translateX(0)';
                                
                                // Start scrolling with a small delay for stability
                                animState.pendingAnimation = requestAnimationFrame(() => {
                                    // Remove any transitions first
                                    textSpan.style.transition = 'none';
                                    void textSpan.offsetWidth; // Force reflow
                                    
                                    // Start the animation
                                    textSpan.classList.add('scroll-animate');
                                    animState.isScrolling = true;
                                    animState.pendingAnimation = null;
                                });
                            };
                            
                            // Improved mouseenter with debounce to prevent rapid toggling
                            itemElement.addEventListener('mouseenter', () => {
                                // Mark as hovering
                                animState.isHovering = true;
                                
                                // Debounce rapid hover in/out
                                if (animState.hoverTimer) clearTimeout(animState.hoverTimer);
                                
                                animState.hoverTimer = setTimeout(() => {
                                    // Only proceed if still hovering
                                    if (animState.isHovering) {
                                        startScrolling();
                                    }
                                }, 100);
                            });
                            
                            // Smooth transition to fade-in on mouseleave
                            itemElement.addEventListener('mouseleave', () => {
                                // Update hover state immediately
                                animState.isHovering = false;
                                
                                // Clear hover timer if it exists
                                if (animState.hoverTimer) {
                                    clearTimeout(animState.hoverTimer);
                                    animState.hoverTimer = null;
                                }
                                
                                // Only handle leaving if we were scrolling
                                if (animState.isScrolling) {
                                    // Get exact current position for smooth transition
                                    const computedStyle = window.getComputedStyle(textSpan);
                                    const matrix = new DOMMatrixReadOnly(computedStyle.transform);
                                    const currentX = matrix.m41; // Current X translation
                                    
                                    // Stop the scroll animation
                                    textSpan.classList.remove('scroll-animate');
                                    
                                    // Keep the left fade by adding a special class
                                    itemContent.classList.add('resetting');
                                    
                                    // First remove any transitions
                                    textSpan.style.transition = 'none';
                                    
                                    // Apply exact position first
                                    textSpan.style.transform = `translateX(${currentX}px)`;
                                    void textSpan.offsetWidth; // Force reflow
                                    
                                    // Apply smooth transition back to start using a more natural easing
                                    textSpan.style.transition = 'transform 0.5s cubic-bezier(0.215, 0.61, 0.355, 1)';
                                    textSpan.style.transform = 'translateX(0)';
                                    
                                    // Set fading in state
                                    animState.isScrolling = false;
                                    animState.isFadingIn = true;
                                    
                                    // Wait for the transition to complete
                                    animState.resetTimer = setTimeout(() => {
                                        // Remove resetting class first
                                        itemContent.classList.remove('resetting');
                                        
                                        // Full reset after transition finishes
                                        resetAnimationState();
                                    }, 500);
                                }
                            });
                            
                            // Handle end of scrolling animation
                            textSpan.addEventListener('animationend', (e) => {
                                if (e.animationName === 'scrollText' && animState.isScrolling) {
                                    // Stop current animation
                                    textSpan.classList.remove('scroll-animate');
                                    
                                    // If still hovering, restart animation with a clean transition
                                    if (animState.isHovering) {
                                        // Small delay before restarting for smooth loop
                                        animState.resetTimer = setTimeout(() => {
                                            // Reset position with a smooth fade
                                            textSpan.style.transition = 'opacity 0.3s ease';
                                            textSpan.style.opacity = '0';
                                            
                                            // Wait for fade out
                                            setTimeout(() => {
                                                // Reset position with no visible transition
                                                textSpan.style.transition = 'none';
                                                textSpan.style.transform = 'translateX(0)';
                                                void textSpan.offsetWidth; // Force reflow
                                                
                                                // Fade back in
                                                textSpan.style.transition = 'opacity 0.3s ease';
                                                textSpan.style.opacity = '1';
                                                
                                                // Wait for fade in before restarting scroll
                                                setTimeout(() => {
                                                    // Only restart if still hovering
                                                    if (animState.isHovering) {
                                                        textSpan.style.transition = '';
                                                        void textSpan.offsetWidth;
                                                        textSpan.classList.add('scroll-animate');
                                                    } else {
                                                        // Otherwise reset completely
                                                        resetAnimationState();
                                                    }
                                                }, 300);
                                            }, 300);
                                        }, 100);
                                    } else {
                                        // Not hovering, so reset fully
                                        resetAnimationState();
                                    }
                                }
                            });
                        }
                    }, 10);
        });
        
        // Add back button listener for Escape key
        ui.addEscapeHandler(() => {
            // If this is a submenu, we should trigger a "back" action rather than just closing
            if (isSubmenu) {
                console.log('Escape pressed in submenu, going back');
                const backItem = itemsArray.find(item => item.isBack);
                if (backItem) {
                    state.selectedListItem = { 
                        index: itemsArray.findIndex(item => item.isBack), 
                        item: backItem 
                    };
                    submitListSelection();
                    return;
                }
            }
            
            // Otherwise just close the UI
            console.log('Escape pressed, closing UI');
            closeUI();
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
        // When showing a submenu, don't hide the list-ui
        if (currentUI === 'list-ui' && state.currentUI === 'list') {
            // Only hide non-list UIs
            ['amount-ui', 'dropdown-ui', 'settings-ui']
                .forEach(id => document.getElementById(id).style.display = 'none');
            return;
        }
        
        // Default behavior for other UIs
        ['amount-ui', 'list-ui', 'dropdown-ui', 'settings-ui']
            .filter(id => id !== currentUI)
            .forEach(id => document.getElementById(id).style.display = 'none');
    }
};

// Notification system
const notifications = {
    counter: 0,
    active: {},
    
    create(data) {
        const id = `notification-${++this.counter}`;
        const container = document.getElementById('notifications-container');
        
        console.log('Creating notification with data:', data);
        console.log('Container element:', container);
        
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
        
        // Add to container
        container.appendChild(notification);
        
        // Apply current opacity setting
        notification.style.backgroundColor = state.darkMode 
            ? `rgba(28, 28, 30, ${state.windowOpacity})` 
            : `rgba(255, 255, 255, ${state.windowOpacity})`;
        
        // Animate progress bar
        const progressBar = notification.querySelector('.notification-progress');
        progressBar.animate([
            { transform: 'scaleX(1)', opacity: 1 },
            { transform: 'scaleX(0)', opacity: 0.7 }
        ], {
            duration: options.duration,
            easing: 'cubic-bezier(0.4, 0, 0.2, 1)', // Material Design standard easing
            fill: 'forwards'
        });
        
        // Set auto-close timer
        const timer = setTimeout(() => this.close(id), options.duration);
        
        // Store notification data
        this.active[id] = { element: notification, timer };
        
        console.log(`Created notification: ${id}`, options);
        return id;
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

// Event handlers
window.addEventListener('message', function(event) {
    const data = event.data;
    
    // Log received events for debugging
    console.log('Received NUI event:', data.type, data);
    
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
            toggleDarkMode: () => toggleDarkMode(),
            showNotification: () => {
                console.log('Processing showNotification event', data);
                console.log('Notification type:', data.notificationType);
                console.log('Notification title:', data.title);
                console.log('Notification message:', data.message);
                
                // Create the notification
                notifications.create(data);
            }
        };
        
        if (handlers[data.type]) {
            handlers[data.type]();
        } else {
            console.warn('Unknown message type:', data.type);
        }
    } catch (error) {
        console.error('Error handling message event:', error);
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
    console.log('selectListItem called with:', index, item);
    
    try {
        // Check if this is a submenu selection
        if (item && item.submenu) {
            console.log('This is a submenu item, sending submenuSelect event');
            // Send submenu event without closing UI
            fetch(`https://${GetParentResourceName()}/submenuSelect`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    index: index,
                    item: item
                })
            }).catch(error => {
                console.error('Error sending submenu select:', error);
            });
        } 
        // Check if this is a back button
        else if (item && item.isBack) {
            console.log('This is a back button, sending submenuBack event');
            // Send back navigation event
            fetch(`https://${GetParentResourceName()}/submenuBack`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(error => {
                console.error('Error sending submenu back:', error);
            });
        }
        // Regular item selection
        else {
            console.log('This is a regular item, closing UI and sending data');
            // Regular item selection, close UI and send data
            ui.closeAndSendData('list-ui', 'listSelect', {
                index: index,
                item: item
            });
        }
    } catch (error) {
        console.error('Exception in selectListItem:', error);
    }
}

function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        ui.closeAndSendData('amount-ui', 'amountSubmit', {
            amount: amount
        });
    }
}

function submitListSelection() {
    console.log('submitListSelection called, selectedListItem:', state.selectedListItem);
    
    if (state.selectedListItem) {
        // Use the selectListItem function which handles all types of selections
        selectListItem(state.selectedListItem.index, state.selectedListItem.item);
    } else {
        // No selection, just close
        console.log('No item selected, closing UI');
        closeUI();
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