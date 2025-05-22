// Menu System for ESKUI
// Handles list, submenu, dropdown, and amount input UIs

// These functions require access to the shared state and UI objects
// from script.js, so we're keeping the same variable names

// Menu-specific UI handlers
const menuHandlers = {
    showAmount(title) {
        state.currentUI = 'amount';
        ui.show('amount-ui');
        this.hideOtherUIs('amount-ui');
        
        document.querySelector('#amount-ui .titlebar-title').textContent = title;
        const input = document.getElementById('amount-input');
        input.value = '';
        input.focus();
        
        ui.addEscapeHandler(() => closeUI());
        
        // Notify that UI is now visible
        notifyUIVisibilityChange(true);
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
            // Notify that UI is now visible
            notifyUIVisibilityChange(true);
        }
        
        this.hideOtherUIs('list-ui');
        
        document.querySelector('#list-ui .titlebar-title').textContent = title;
        
        // Clear and populate list items
        const listContainer = document.getElementById('list-items');
        listContainer.innerHTML = '';
        
        // Reset selected item
        state.selectedListItem = null;
        
        // Clear any existing glow elements for a fresh start
        clearGlowEffects();
        
        // Setup periodic cleanup to prevent accumulation
        setupGlowEffectCleanup();
        
        // Ensure items is an array
        let itemsArray = this.validateListItems(items);
        
        // Add items
        itemsArray.forEach((item, index) => {
            const itemElement = this.createListItem(item, index, listContainer);
            listContainer.appendChild(itemElement);
            
            // Add divider after each item except the last one
            if (index < itemsArray.length - 1) {
                const divider = document.createElement('div');
                divider.className = 'list-divider';
                listContainer.appendChild(divider);
            }
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
    
    validateListItems(items) {
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
        return itemsArray;
    },
    
    createListItem(item, index, listContainer) {
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
                selectListItemUI(itemElement, listContainer, index, item);
            };
        }
        
        // Check if text is overflowing and add scroll animation
        this.setupScrollAnimation(itemElement, itemContent, item);
        
        return itemElement;
    },
    
    setupScrollAnimation(itemElement, itemContent, item) {
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
        
        // Notify that UI is now visible
        notifyUIVisibilityChange(true);
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

// UI action functions for menus
function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        ui.closeAndSendData('amount-ui', 'amountSubmit', {
            amount: amount
        });
    }
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

function submitListSelection() {
    console.log('submitListSelection called, selectedListItem:', state.selectedListItem);
    
    // Clean all glow effects before proceeding to prevent stacking
    clearGlowEffects();
    
    if (state.selectedListItem) {
        // Use the selectListItem function which handles all types of selections
        selectListItem(state.selectedListItem.index, state.selectedListItem.item);
    } else {
        // No selection, just close
        console.log('No item selected, closing UI');
        closeUI();
    }
}

// Helper function to handle list item selection
function selectListItemUI(itemElement, listContainer, index, item) {
    // Don't do anything if this item is already selected
    if (itemElement.classList.contains('selected')) {
        return;
    }
    
    // If there's a previously selected item, deselect it
    const previouslySelected = listContainer.querySelector('.list-item.selected');
    if (previouslySelected && previouslySelected !== itemElement) {
        // First deselect the previous item
        previouslySelected.classList.add('deselecting');
        previouslySelected.classList.remove('selected');
        
        // Fade out glow effects
        fadeOutGlowEffects(previouslySelected);
        
        // Remove deselecting class after animation completes
        setTimeout(() => {
            previouslySelected.classList.remove('deselecting');
        }, 300);
    }
    
    // Deselect all other items
    listContainer.querySelectorAll('.list-item').forEach(el => {
        if (el !== itemElement && el !== previouslySelected) {
            el.classList.remove('selected', 'deselecting');
            clearGlowEffects(el);
        }
    });
    
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
        
        // Add glow effects
        addGlowEffects(itemElement);
    }, 50);
    
    // Store the selected item and index
    state.selectedListItem = { index, item };
    
    // Find scroll content if this is a long text item
    const scrollContent = itemElement.querySelector('.list-item-content.scroll');
    if (scrollContent) {
        const textSpan = scrollContent.querySelector('span');
        if (textSpan && textSpan._animState) {
            // Mark as hovering to trigger scroll animation after selection
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
    
    // If it's a submenu or back button, automatically select it
    if (item.submenu || item.isBack) {
        console.log('Auto-selecting item (submenu or back):', item.label);
        submitListSelection();
    }
}

// Handle Enter key for amount input
document.addEventListener('DOMContentLoaded', function() {
    document.getElementById('amount-input').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            submitAmount();
        }
    });
});

// Export functionality to the global scope for script.js to access
window.menuHandlers = menuHandlers;
window.submitAmount = submitAmount;
window.submitListSelection = submitListSelection;
window.selectListItem = selectListItem;
window.selectListItemUI = selectListItemUI; 