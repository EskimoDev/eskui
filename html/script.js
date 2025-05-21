// UI state management
const state = {
    currentUI: null,
    currentUIId: null,
    cleanupHandlers: [],
    darkMode: false,
    windowOpacity: 0.95,
    freeDrag: false,
    selectedListItem: null,
    // Shopping cart state
    cart: [],
    currentCategory: null,
    shopItems: []
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
        
        // Clear any water shimmer elements that might be lingering
        document.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
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
        
        // Clear any existing glow elements for a fresh start
        document.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
        
        // Setup periodic cleanup to prevent accumulation
        setupGlowEffectCleanup();
        
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
                    
                    // Don't do anything if this item is already selected
                    if (itemElement.classList.contains('selected')) {
                        return;
                    }
                    
                    // If there's a previously selected item, add deselecting animation
                        const previouslySelected = listContainer.querySelector('.list-item.selected');
                        if (previouslySelected && previouslySelected !== itemElement) {
                            // First deselect the previous item
                            previouslySelected.classList.add('deselecting');
                            previouslySelected.classList.remove('selected');
                            
                            // Remove glow effects with a fade-out animation instead of instantly removing them
                            const prevGlowElements = previouslySelected.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left');
                            prevGlowElements.forEach(el => {
                                el.style.transition = 'opacity 0.25s ease';
                                el.style.opacity = '0';
                            });
                            
                            // Wait for deselection animation to complete before selecting new item
                            setTimeout(() => {
                                previouslySelected.classList.remove('deselecting');
                                // Remove the glow elements after fade-out
                                prevGlowElements.forEach(el => el.remove());
                            
                            // Now select the new item
                            itemElement.classList.add('selected');
                            
                            // Remove any existing glow elements before adding new ones
                            itemElement.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
                            
                            // Create and add individual glow segments for independent animation
                            const glowSegments = ['top', 'right', 'bottom', 'left'];
                            glowSegments.forEach(side => {
                                const glowElement = document.createElement('div');
                                glowElement.className = `glow-${side}`;
                                itemElement.appendChild(glowElement);
                            });
                            
                            // Create and add water shimmer element for the glow effect
                            const shimmer = document.createElement('div');
                            shimmer.className = 'water-shimmer';
                            itemElement.appendChild(shimmer);
                            
                            // Store the selected item and index
                            state.selectedListItem = { index, item };
                            
                            // Find scroll content if this is a long text item
                            const scrollContent = itemElement.querySelector('.list-item-content.scroll');
                            if (scrollContent) {
                                const textSpan = scrollContent.querySelector('span');
                                if (textSpan && textSpan._animState) {
                                    // Mark as hovering to trigger scroll animation after selection animation
                                    textSpan._animState.isHovering = true;
                                    
                                    // Wait for selection animation to complete before starting scroll
                                    setTimeout(() => {
                                        if (textSpan._animState && textSpan._animState.isHovering) {
                                            console.log('Auto-starting scroll animation after selection');
                                            if (typeof textSpan._animState.startScrolling === 'function') {
                                                textSpan._animState.startScrolling();
                                            }
                                        }
                                    }, 250); // Wait for selection animation to complete
                                }
                            }
                            
                            // If it's a submenu or back button, automatically select it without requiring Submit button
                            if (item.submenu || item.isBack) {
                                console.log('Auto-selecting item (submenu or back):', item.label);
                                submitListSelection();
                            }
                        }, 150); // Half the deselection animation time for a smoother feel
                    } else {
                        // Add deselecting animation to all items except the newly selected one
                        listContainer.querySelectorAll('.list-item').forEach(el => {
                            if (el !== itemElement) {
                                // If it was previously selected, add deselecting animation
                                if (el.classList.contains('selected')) {
                                    el.classList.add('deselecting');
                                    el.classList.remove('selected');
                                    
                                    // Fade out glow effects
                                    const glowElements = el.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left');
                                    glowElements.forEach(glowEl => {
                                        glowEl.style.transition = 'opacity 0.25s ease';
                                        glowEl.style.opacity = '0';
                                        
                                        // Remove after fade completes
                                        setTimeout(() => glowEl.remove(), 250);
                                    });
                                    
                                    // Remove deselecting class after animation completes
                                    setTimeout(() => el.classList.remove('deselecting'), 300);
                                } else {
                                    el.classList.remove('selected', 'deselecting');
                                    // Remove any existing glow elements
                                    el.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(glowEl => glowEl.remove());
                                }
                            }
                        });
                        
                                            // First create a fade-in effect
                    // Create a temporary element for the selection transition
                    const transitionOverlay = document.createElement('div');
                    transitionOverlay.className = 'selection-transition-overlay';
                    transitionOverlay.style.position = 'absolute';
                    transitionOverlay.style.top = '0';
                    transitionOverlay.style.left = '0';
                    transitionOverlay.style.right = '0';
                    transitionOverlay.style.bottom = '0';
                    transitionOverlay.style.borderRadius = '8px';
                    transitionOverlay.style.backgroundImage = 'var(--list-item-selected-bg)';
                    transitionOverlay.style.opacity = '0';
                    transitionOverlay.style.transition = 'opacity 0.4s ease';
                    transitionOverlay.style.zIndex = '0';
                    transitionOverlay.style.pointerEvents = 'none';
                    
                    // Add the transition overlay
                    itemElement.appendChild(transitionOverlay);
                    
                    // Trigger reflow to ensure the transition works
                    void transitionOverlay.offsetWidth;
                    
                    // Start the fade-in effect
                    transitionOverlay.style.opacity = '1';
                    
                    // Add the selected class after a slight delay to allow the fade to begin
                    setTimeout(() => {
                        // Add selected class
                        itemElement.classList.add('selected');
                        
                        // Remove the temporary transition overlay after the fade completes
                        setTimeout(() => {
                            if (transitionOverlay.parentNode) {
                                transitionOverlay.parentNode.removeChild(transitionOverlay);
                            }
                        }, 500);
                        
                        // Remove any existing glow elements before adding new ones
                        itemElement.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
                        
                        // Create and add individual glow segments for independent animation
                        const glowSegments = ['top', 'right', 'bottom', 'left'];
                        glowSegments.forEach(side => {
                            const glowElement = document.createElement('div');
                            glowElement.className = `glow-${side}`;
                            itemElement.appendChild(glowElement);
                        });
                        
                        // Create and add water shimmer element for the glow effect
                        const shimmer = document.createElement('div');
                        shimmer.className = 'water-shimmer';
                        itemElement.appendChild(shimmer);
                    }, 50);
                        
                        // Store the selected item and index
                        state.selectedListItem = { index, item };
                        
                        // Find scroll content if this is a long text item
                        const scrollContent = itemElement.querySelector('.list-item-content.scroll');
                        if (scrollContent) {
                            const textSpan = scrollContent.querySelector('span');
                            if (textSpan && textSpan._animState) {
                                // Mark as hovering to trigger scroll animation after selection animation
                                textSpan._animState.isHovering = true;
                                
                                // Wait for selection animation to complete before starting scroll
                                setTimeout(() => {
                                    if (textSpan._animState && textSpan._animState.isHovering) {
                                        console.log('Auto-starting scroll animation after selection');
                                        if (typeof textSpan._animState.startScrolling === 'function') {
                                            textSpan._animState.startScrolling();
                                        }
                                    }
                                }, 250); // Wait for selection animation to complete
                            }
                        }
                        
                        // If it's a submenu or back button, automatically select it without requiring Submit button
                        if (item.submenu || item.isBack) {
                            console.log('Auto-selecting item (submenu or back):', item.label);
                            submitListSelection();
                        }
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
                        textSpan.classList.remove('scroll-animate', 'scroll-fade-in', 'entering-from-left');
                        
                        // Apply a clean state with no transition first
                        textSpan.style.transition = 'none';
                        textSpan.style.opacity = '1';
                        textSpan.style.filter = 'blur(0px)';
                        textSpan.style.textShadow = 'none';
                        
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
                            
                            // Check if parent list item is selected
                            const isSelected = itemElement.classList.contains('selected');
                            
                            // Start the animation
                            textSpan.classList.add('scroll-animate');
                            
                            // If item is selected, we don't need additional delay - CSS handles it
                            if (isSelected) {
                                console.log('Item is selected, using CSS delay for scrolling');
                            }
                            
                            animState.isScrolling = true;
                            animState.pendingAnimation = null;
                        });
                    };
                    
                    // Enhanced fade-in animation after scrolling completes
                    const startFancyFadeIn = () => {
                        if (animState.isFadingIn) return;
                        
                        // Mark as fading in to prevent multiple triggers
                        animState.isFadingIn = true;
                        
                        // Get the text content
                        const originalText = textSpan.textContent;
                        
                        // Hide the text first
                        textSpan.style.opacity = '0';
                        textSpan.style.transform = 'translateX(0)';
                        textSpan.style.filter = 'blur(4px)';
                        
                        // Force reflow
                        void textSpan.offsetWidth;
                        
                        // Set a smoother transition for all properties
                        textSpan.style.transition = 'opacity 0.4s ease-out, transform 0.5s cubic-bezier(0.19, 1, 0.22, 1), filter 0.45s ease-out, text-shadow 0.45s ease-out';
                        
                        // Add subtle glow effect
                        textSpan.style.textShadow = '0 0 8px rgba(255,255,255,0.15)';
                        
                        // Start the fade in and slide animation
                        setTimeout(() => {
                            textSpan.style.opacity = '1';
                            textSpan.style.transform = 'translateX(0)';
                            textSpan.style.filter = 'blur(0px)';
                            
                            // Remove the glow after the animation
                            setTimeout(() => {
                                textSpan.style.textShadow = 'none';
                                animState.isFadingIn = false;
                                
                                // Only restart scrolling if still hovering
                                if (animState.isHovering && itemElement.classList.contains('selected')) {
                                    setTimeout(() => startScrolling(), 800);
                                } else {
                                    resetAnimationState();
                                }
                            }, 450);
                        }, 50);
                    };
                    
                    // Store the startScrolling function in the animation state
                    // so we can call it from outside this scope when needed
                    animState.startScrolling = startScrolling;
                    
                    // Improved mouseenter with debounce to prevent rapid toggling
                    itemElement.addEventListener('mouseenter', () => {
                        // Mark as hovering
                        animState.isHovering = true;
                        
                        // Debounce rapid hover in/out
                        if (animState.hoverTimer) clearTimeout(animState.hoverTimer);
                        
                        animState.hoverTimer = setTimeout(() => {
                            // Only proceed if still hovering AND the item is selected
                            if (animState.isHovering && itemElement.classList.contains('selected')) {
                                console.log('Item is both hovered and selected, starting scroll animation');
                                startScrolling();
                            }
                        }, 50);
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
                            // Stop the scroll animation immediately
                            textSpan.classList.remove('scroll-animate');
                            
                            // Keep the fade mask by adding the resetting class
                            itemContent.classList.add('resetting');
                            
                            // Clear any existing transitions
                            textSpan.style.transition = 'transform 0.3s cubic-bezier(0.19, 1, 0.22, 1)';
                            
                            // Reset position directly with transition instead of using animation class
                            textSpan.style.transform = 'translateX(0)';
                            
                            // Set states
                            animState.isScrolling = false;
                            
                            // Quick clean up to prevent jankiness
                            animState.resetTimer = setTimeout(() => {
                                // Remove resetting class first
                                itemContent.classList.remove('resetting');
                                
                                // Full reset
                                resetAnimationState();
                            }, 300); // Match the transition duration
                        }
                    });
                    
                    // Handle end of scrolling animation
                    textSpan.addEventListener('animationend', (e) => {
                        if (e.animationName === 'scrollText' && animState.isScrolling) {
                            // Stop current animation
                            textSpan.classList.remove('scroll-animate');
                            
                            // If still hovering AND item is selected, start fancy fade-in
                            if (animState.isHovering && itemElement.classList.contains('selected')) {
                                // Start the enhanced fade-in effect
                                startFancyFadeIn();
                            } else {
                                // Not hovering or not selected, so reset fully
                                resetAnimationState();
                            }
                        } else if (e.animationName === 'textEnterFromLeft') {
                            // When the entering-from-left animation completes, remove the class
                            textSpan.classList.remove('entering-from-left');
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
    
    showShop(title, categories, items) {
        console.log(`Showing shop: ${title}, items:`, items);
        
        state.currentUI = 'shop';
        ui.show('shopping-ui');
        this.hideOtherUIs('shopping-ui');
        
        document.querySelector('#shopping-ui .titlebar-title').textContent = title;
        
        // Set initial shop data
        state.shopItems = items || [];
        state.cart = [];
        
        // Populate categories
        const categoriesContainer = document.getElementById('shop-categories');
        categoriesContainer.innerHTML = '';
        
        if (categories && categories.length > 0) {
            categories.forEach((category, index) => {
                const categoryEl = document.createElement('div');
                categoryEl.className = 'shop-category' + (index === 0 ? ' active' : '');
                
                // Set initial category
                if (index === 0) {
                    state.currentCategory = category.id;
                }
                
                let categoryContent = '';
                if (category.icon) {
                    categoryContent += `<span class="shop-category-icon">${category.icon}</span>`;
                }
                categoryContent += category.label;
                
                categoryEl.innerHTML = categoryContent;
                
                categoryEl.onclick = () => {
                    // Deselect all categories
                    document.querySelectorAll('.shop-category').forEach(cat => {
                        cat.classList.remove('active');
                    });
                    
                    // Select this category
                    categoryEl.classList.add('active');
                    
                    // Update current category
                    state.currentCategory = category.id;
                    
                    // Update displayed items
                    renderShopItems();
                };
                
                categoriesContainer.appendChild(categoryEl);
            });
        }
        
        // Initial render of shop items
        renderShopItems();
        
        // Initial render of cart
        renderCart();
        
        // Add event listeners for cart buttons
        document.getElementById('shop-cart-clear').addEventListener('click', clearCart);
        document.getElementById('shop-checkout-btn').addEventListener('click', checkout);
        
        // Add escape handler
        ui.addEscapeHandler(() => closeUI());
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
            showShop: () => {
                console.log('Processing showShop event');
                uiHandlers.showShop(data.title, data.categories, data.items);
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
    
    // Ensure close message is sent to release NUI focus
    sendNUIMessage('close');
    
    // Remove any lingering shimmer and glow effects
    document.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
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
    
    // Clean all glow effects before proceeding to prevent stacking
    document.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
    
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
            // Count glow elements
            const glowTopElements = item.querySelectorAll('.glow-top');
            const glowRightElements = item.querySelectorAll('.glow-right');
            const glowBottomElements = item.querySelectorAll('.glow-bottom');
            const glowLeftElements = item.querySelectorAll('.glow-left');
            const shimmerElements = item.querySelectorAll('.water-shimmer');
            
            // Remove extras if there are more than one of each
            if (glowTopElements.length > 1) {
                for (let i = 1; i < glowTopElements.length; i++) {
                    glowTopElements[i].remove();
                }
            }
            
            if (glowRightElements.length > 1) {
                for (let i = 1; i < glowRightElements.length; i++) {
                    glowRightElements[i].remove();
                }
            }
            
            if (glowBottomElements.length > 1) {
                for (let i = 1; i < glowBottomElements.length; i++) {
                    glowBottomElements[i].remove();
                }
            }
            
            if (glowLeftElements.length > 1) {
                for (let i = 1; i < glowLeftElements.length; i++) {
                    glowLeftElements[i].remove();
                }
            }
            
            if (shimmerElements.length > 1) {
                for (let i = 1; i < shimmerElements.length; i++) {
                    shimmerElements[i].remove();
                }
            }
            
            // If item is not selected, remove all glow elements
            if (!item.classList.contains('selected')) {
                item.querySelectorAll('.water-shimmer, .glow-top, .glow-right, .glow-bottom, .glow-left').forEach(el => el.remove());
            }
        });
    }, 500);
    
    // Add the interval to cleanup handlers so it gets cleared when UI is closed
    state.cleanupHandlers.push(() => clearInterval(glowCleanupInterval));
}

// Shopping cart functions
function renderShopItems() {
    const shopItemsContainer = document.getElementById('shop-items');
    shopItemsContainer.innerHTML = '';
    
    // Filter items by current category
    const filteredItems = state.currentCategory 
        ? state.shopItems.filter(item => item.category === state.currentCategory)
        : state.shopItems;
    
    if (filteredItems.length === 0) {
        const emptyMessage = document.createElement('div');
        emptyMessage.className = 'shop-cart-empty';
        emptyMessage.innerHTML = `
            <div class="shop-cart-empty-icon">📦</div>
            <div class="shop-cart-empty-text">No items in this category</div>
        `;
        shopItemsContainer.appendChild(emptyMessage);
        return;
    }
    
    filteredItems.forEach(item => {
        const itemEl = document.createElement('div');
        itemEl.className = 'shop-item';
        
        let imageContent = '';
        if (item.image) {
            imageContent = `<img src="${item.image}" alt="${item.name}">`;
        } else {
            // Use emoji as fallback
            imageContent = item.icon || '🛒';
        }
        
        itemEl.innerHTML = `
            <div class="shop-item-image">${imageContent}</div>
            <div class="shop-item-name">${item.name}</div>
            ${item.description ? `<div class="shop-item-desc">${item.description}</div>` : ''}
            <div class="shop-item-price">$${item.price.toLocaleString()}</div>
            <div class="shop-item-add">+</div>
        `;
        
        // Add to cart when clicked
        itemEl.querySelector('.shop-item-add').addEventListener('click', (e) => {
            e.stopPropagation();
            addToCart(item);
        });
        
        // View item details when clicked
        itemEl.addEventListener('click', () => {
            // In future, show item details modal here
            console.log('View item details:', item);
        });
        
        shopItemsContainer.appendChild(itemEl);
    });
}

function renderCart() {
    const cartItemsContainer = document.getElementById('shop-cart-items');
    const totalElement = document.getElementById('shop-cart-total-amount');
    
    cartItemsContainer.innerHTML = '';
    
    if (state.cart.length === 0) {
        const emptyCart = document.createElement('div');
        emptyCart.className = 'shop-cart-empty';
        emptyCart.innerHTML = `
            <div class="shop-cart-empty-icon">🛒</div>
            <div class="shop-cart-empty-text">Your cart is empty</div>
        `;
        cartItemsContainer.appendChild(emptyCart);
        totalElement.textContent = '$0';
        return;
    }
    
    let total = 0;
    
    state.cart.forEach(cartItem => {
        const itemEl = document.createElement('div');
        itemEl.className = 'shop-cart-item';
        
        const subtotal = cartItem.item.price * cartItem.quantity;
        total += subtotal;
        
        itemEl.innerHTML = `
            <div class="shop-cart-item-icon">${cartItem.item.icon || '📦'}</div>
            <div class="shop-cart-item-details">
                <div class="shop-cart-item-name">${cartItem.item.name}</div>
                <div class="shop-cart-item-price">$${cartItem.item.price.toLocaleString()}</div>
            </div>
            <div class="shop-cart-item-quantity">
                <div class="shop-cart-item-quantity-btn dec">-</div>
                <div class="shop-cart-item-quantity-value">${cartItem.quantity}</div>
                <div class="shop-cart-item-quantity-btn inc">+</div>
            </div>
            <div class="shop-cart-item-remove">×</div>
        `;
        
        // Decrease quantity
        itemEl.querySelector('.shop-cart-item-quantity-btn.dec').addEventListener('click', () => {
            if (cartItem.quantity > 1) {
                cartItem.quantity--;
                renderCart();
            } else {
                removeFromCart(cartItem.item.id);
            }
        });
        
        // Increase quantity
        itemEl.querySelector('.shop-cart-item-quantity-btn.inc').addEventListener('click', () => {
            cartItem.quantity++;
            renderCart();
        });
        
        // Remove item completely
        itemEl.querySelector('.shop-cart-item-remove').addEventListener('click', () => {
            removeFromCart(cartItem.item.id);
        });
        
        cartItemsContainer.appendChild(itemEl);
    });
    
    totalElement.textContent = '$' + total.toLocaleString();
}

function addToCart(item) {
    // Check if item already in cart
    const existingItem = state.cart.find(cartItem => cartItem.item.id === item.id);
    
    if (existingItem) {
        existingItem.quantity++;
    } else {
        state.cart.push({
            item: item,
            quantity: 1
        });
    }
    
    // Show brief animation on cart
    const cartBtn = document.getElementById('shop-checkout-btn');
    cartBtn.classList.add('pulse');
    setTimeout(() => cartBtn.classList.remove('pulse'), 300);
    
    // Show notification
    notifications.create({
        type: 'success',
        title: 'Added to cart',
        message: `${item.name} has been added to your cart.`,
        duration: 2000
    });
    
    renderCart();
}

function removeFromCart(itemId) {
    state.cart = state.cart.filter(cartItem => cartItem.item.id !== itemId);
    renderCart();
}

function clearCart() {
    state.cart = [];
    renderCart();
    
    notifications.create({
        type: 'info',
        title: 'Cart cleared',
        message: 'All items have been removed from your cart.',
        duration: 2000
    });
}

function checkout() {
    if (state.cart.length === 0) {
        notifications.create({
            type: 'warning',
            title: 'Empty cart',
            message: 'Your cart is empty. Add some items first!',
            duration: 2000
        });
        return;
    }
    
    // Calculate total
    const total = state.cart.reduce((sum, item) => sum + (item.item.price * item.quantity), 0);
    
    // Send checkout data to server
    ui.closeAndSendData('shopping-ui', 'shopCheckout', {
        items: state.cart.map(item => ({
            id: item.item.id,
            quantity: item.quantity,
            price: item.item.price
        })),
        total: total
    });
    
    // Reset cart
    state.cart = [];
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
        
        // Pass interaction messages to the iframe
        if (data.type === 'showInteraction' || data.type === 'hideInteraction') {
            // Get the iframe window
            const iframeWindow = frame.contentWindow;
            if (iframeWindow) {
                // Forward the message to the iframe
                iframeWindow.postMessage(data, '*');
            }
        }
    });
}

// Initialize the interaction system when the page loads
document.addEventListener('DOMContentLoaded', function() {
    // Setup the interaction frame
    setupInteractionFrame();
}); 